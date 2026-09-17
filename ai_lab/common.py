from __future__ import annotations

import json
import math
import os
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

API_URL = "https://generativelanguage.googleapis.com/v1beta/interactions"
DEFAULT_MODEL = "gemini-3.5-flash-lite"

# Published model ceilings. We intentionally operate far below these limits.
MODEL_INPUT_TOKEN_LIMIT = 1_048_576
MODEL_OUTPUT_TOKEN_LIMIT = 65_536
DEFAULT_SAFE_INPUT_TOKENS = 32_000
DEFAULT_SAFE_OUTPUT_TOKENS = 8_192
DEFAULT_SAFE_RPM = 1
DEFAULT_MAX_RETRIES = 1
DEFAULT_MAX_REQUESTS_PER_RUN = 16


class GeminiBudgetError(RuntimeError):
    pass


def _env_int(name: str, default: int, minimum: int, maximum: int) -> int:
    try:
        value = int(os.environ.get(name, str(default)))
    except (TypeError, ValueError):
        value = default
    return max(minimum, min(maximum, value))


def estimate_tokens(*parts: str) -> int:
    """Conservative preflight estimate without spending an API request.

    English JSON commonly averages well above two UTF-8 bytes per token, so
    bytes/2 intentionally overestimates normal Waypoint prompts. A small fixed
    overhead covers request framing and structured-output metadata.
    """
    byte_count = sum(len(str(part).encode("utf-8")) for part in parts)
    return int(math.ceil(byte_count / 2.0)) + 512


def request_budget(
    prompt: str,
    schema: dict[str, Any],
    system_instruction: str,
    requested_output_tokens: int,
) -> dict[str, int]:
    safe_input = _env_int(
        "GEMINI_SAFE_INPUT_TOKENS",
        DEFAULT_SAFE_INPUT_TOKENS,
        1_024,
        MODEL_INPUT_TOKEN_LIMIT,
    )
    safe_output = _env_int(
        "GEMINI_SAFE_OUTPUT_TOKENS",
        DEFAULT_SAFE_OUTPUT_TOKENS,
        256,
        MODEL_OUTPUT_TOKEN_LIMIT,
    )
    output_tokens = max(256, min(int(requested_output_tokens), safe_output, MODEL_OUTPUT_TOKEN_LIMIT))
    schema_text = json.dumps(schema, ensure_ascii=False, separators=(",", ":"))
    estimated_input = estimate_tokens(prompt, system_instruction, schema_text)
    if estimated_input > safe_input:
        raise GeminiBudgetError(
            f"Gemini prompt blocked before network call: estimated {estimated_input} input tokens "
            f"exceeds configured safe cap {safe_input}."
        )
    if estimated_input > MODEL_INPUT_TOKEN_LIMIT:
        raise GeminiBudgetError("Gemini prompt exceeds the model input-token limit.")
    return {
        "estimated_input_tokens": estimated_input,
        "max_output_tokens": output_tokens,
        "safe_input_tokens": safe_input,
        "safe_output_tokens": safe_output,
    }


def _usage_path() -> Path:
    explicit = os.environ.get("GEMINI_USAGE_FILE", "").strip()
    if explicit:
        return Path(explicit)
    base = Path(os.environ.get("RUNNER_TEMP", tempfile.gettempdir()))
    return base / "waypoint-gemini-run-usage.json"


def _run_key() -> str:
    return os.environ.get("GITHUB_RUN_ID", "").strip() or f"local-{os.getpid()}"


def _load_usage() -> dict[str, Any]:
    path = _usage_path()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        data = {}
    if data.get("run_key") != _run_key():
        data = {"run_key": _run_key(), "attempts": 0, "last_attempt_epoch": 0.0}
    return data


def _save_usage(data: dict[str, Any]) -> None:
    path = _usage_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(data, indent=2), encoding="utf-8")
    temp.replace(path)


def _reserve_request_attempt() -> dict[str, Any]:
    rpm = _env_int("GEMINI_SAFE_RPM", DEFAULT_SAFE_RPM, 1, 60)
    max_requests = _env_int(
        "GEMINI_MAX_REQUESTS_PER_RUN",
        DEFAULT_MAX_REQUESTS_PER_RUN,
        1,
        10_000,
    )
    usage = _load_usage()
    if int(usage.get("attempts", 0)) >= max_requests:
        raise GeminiBudgetError(
            f"Gemini run request cap reached ({max_requests}); refusing additional API calls."
        )

    minimum_spacing = 60.0 / float(rpm)
    last = float(usage.get("last_attempt_epoch", 0.0) or 0.0)
    wait = minimum_spacing - (time.time() - last)
    if wait > 0:
        print(f"[gemini-budget] pacing request for {wait:.1f}s to stay at <= {rpm} RPM")
        time.sleep(wait)

    usage["attempts"] = int(usage.get("attempts", 0)) + 1
    usage["last_attempt_epoch"] = time.time()
    _save_usage(usage)
    return usage


def extract_output_text(payload: dict[str, Any]) -> str:
    for step in reversed(payload.get("steps", [])):
        if step.get("type") == "model_output":
            for content in step.get("content", []):
                if content.get("type") == "text" and isinstance(content.get("text"), str):
                    return content["text"]
    raise ValueError("Gemini response contained no model text output")


def call_gemini(
    prompt: str,
    schema: dict[str, Any],
    system_instruction: str,
    model: str | None = None,
    *,
    max_output_tokens: int = 2_200,
    temperature: float = 0.45,
) -> dict[str, Any]:
    key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not key:
        raise RuntimeError("GEMINI_API_KEY is not set")

    budget = request_budget(prompt, schema, system_instruction, max_output_tokens)
    print(
        "[gemini-budget] "
        f"estimated_input={budget['estimated_input_tokens']} "
        f"max_output={budget['max_output_tokens']} "
        f"safe_input_cap={budget['safe_input_tokens']}"
    )

    body = {
        "model": model or os.environ.get("GEMINI_MODEL", DEFAULT_MODEL),
        "input": prompt,
        "system_instruction": system_instruction,
        "store": False,
        "generation_config": {
            "max_output_tokens": budget["max_output_tokens"],
            "temperature": max(0.0, min(1.0, float(temperature))),
        },
        "response_format": {
            "type": "text",
            "mime_type": "application/json",
            "schema": schema,
        },
    }

    payload = json.dumps(body, ensure_ascii=False).encode("utf-8")
    retries = _env_int("GEMINI_MAX_RETRIES", DEFAULT_MAX_RETRIES, 0, 5)
    timeout = _env_int("GEMINI_TIMEOUT_SECONDS", 120, 30, 300)

    for retry_index in range(retries + 1):
        _reserve_request_attempt()
        request = urllib.request.Request(
            API_URL,
            data=payload,
            method="POST",
            headers={"Content-Type": "application/json", "x-goog-api-key": key},
        )
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                raw = json.loads(response.read().decode("utf-8"))
            return json.loads(extract_output_text(raw))
        except urllib.error.HTTPError as exc:
            if exc.code not in {429, 500, 502, 503, 504} or retry_index >= retries:
                raise
            retry_after = exc.headers.get("Retry-After") if exc.headers else None
            try:
                wait = max(60.0, float(retry_after)) if retry_after else 60.0 * (retry_index + 1)
            except (TypeError, ValueError):
                wait = 60.0 * (retry_index + 1)
            print(f"[gemini-budget] HTTP {exc.code}; backing off {wait:.0f}s before one bounded retry")
            time.sleep(wait)

    raise RuntimeError("Gemini request failed after bounded retries")
