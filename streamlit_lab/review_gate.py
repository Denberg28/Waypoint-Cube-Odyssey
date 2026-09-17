from __future__ import annotations

import base64
import hmac
import json
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPOSITORY = "Denberg28/Waypoint-Cube-Odyssey"
BRANCH = "ai-development"
GATE_PATH = "runtime/development_gate.json"
REVIEW_PATH = "runtime/development_review.json"
API_ROOT = f"https://api.github.com/repos/{REPOSITORY}"


class ReviewGateError(RuntimeError):
    pass


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_local_json(path: Path, default: Any) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def fetch_remote_json(path: str, default: Any = None) -> Any:
    url = f"https://raw.githubusercontent.com/{REPOSITORY}/{BRANCH}/{path}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Waypoint-Review-Gate/1.0"})
        with urllib.request.urlopen(req, timeout=8) as response:
            return json.loads(response.read().decode("utf-8"))
    except Exception:
        return default


def pin_matches(provided: str, expected: str) -> bool:
    if not provided or not expected:
        return False
    return hmac.compare_digest(provided.encode("utf-8"), expected.encode("utf-8"))


def _github_contents(path: str, token: str) -> dict:
    req = urllib.request.Request(
        f"{API_ROOT}/contents/{path}?ref={BRANCH}",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "Waypoint-Review-Gate/1.0",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return {}
        raise ReviewGateError(f"GitHub read failed with HTTP {exc.code}") from exc


def persist_decision(
    *,
    token: str,
    review: dict,
    decision: str,
    selected_ids: list[str],
) -> dict:
    if decision not in {"accepted", "hold"}:
        raise ReviewGateError("Unsupported development review decision.")
    if not token:
        raise ReviewGateError("Missing GitHub contents token.")
    bundle_id = str(review.get("bundle_id", "")).strip()
    if not bundle_id:
        raise ReviewGateError("Prepared update is missing a bundle ID.")

    known = {
        str(item.get("id", "")).strip()
        for item in review.get("features", [])
        if isinstance(item, dict)
    }
    selected = [item for item in selected_ids if item in known]
    if decision == "accepted" and not selected:
        raise ReviewGateError("Select at least one feature before accepting.")

    gate = {
        "schema": 1,
        "bundle_id": bundle_id,
        "council_id": str(review.get("council_id", "")),
        "decision": decision,
        "selected_feature_ids": selected if decision == "accepted" else [],
        "reviewed_utc": utc_now(),
        "reviewer": "owner",
        "implementation_authorized": decision == "accepted",
        "auto_merge_authorized": False,
        "note": (
            "Selected prepared features are authorized for staged implementation and validation. "
            "Source changes still require the repository's tests, milestone locks, autonomy guard, and no-auto-merge policy."
            if decision == "accepted"
            else "Prepared update is held. Autonomous source implementation must not proceed for this bundle."
        ),
    }

    current = _github_contents(GATE_PATH, token)
    payload = {
        "message": f"gate: {decision} development bundle {bundle_id}",
        "content": base64.b64encode(
            json.dumps(gate, indent=2, ensure_ascii=False).encode("utf-8")
        ).decode("ascii"),
        "branch": BRANCH,
    }
    if current.get("sha"):
        payload["sha"] = current["sha"]

    req = urllib.request.Request(
        f"{API_ROOT}/contents/{GATE_PATH}",
        data=json.dumps(payload).encode("utf-8"),
        method="PUT",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "Waypoint-Review-Gate/1.0",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise ReviewGateError(f"GitHub write failed with HTTP {exc.code}") from exc
    return gate
