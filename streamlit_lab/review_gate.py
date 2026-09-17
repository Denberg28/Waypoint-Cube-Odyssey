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
ROLLBACK_REQUEST_PATH = "runtime/rollback_request.json"
FLAGGED_FEATURES_PATH = "runtime/flagged_features.json"
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


def _headers(token: str) -> dict:
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "Waypoint-Review-Gate/1.0",
    }


def _github_contents(path: str, token: str) -> dict:
    req = urllib.request.Request(
        f"{API_ROOT}/contents/{path}?ref={BRANCH}",
        headers=_headers(token),
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return {}
        raise ReviewGateError(f"GitHub read failed with HTTP {exc.code}") from exc


def _branch_head(token: str) -> str:
    req = urllib.request.Request(
        f"{API_ROOT}/git/ref/heads/{BRANCH}",
        headers=_headers(token),
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise ReviewGateError(f"Unable to capture rollback checkpoint: HTTP {exc.code}") from exc
    sha = str(data.get("object", {}).get("sha", "")).strip()
    if not sha:
        raise ReviewGateError("Unable to capture rollback checkpoint SHA.")
    return sha


def _write_json(path: str, token: str, value: dict, message: str) -> None:
    current = _github_contents(path, token)
    payload = {
        "message": message,
        "content": base64.b64encode(
            json.dumps(value, indent=2, ensure_ascii=False).encode("utf-8")
        ).decode("ascii"),
        "branch": BRANCH,
    }
    if current.get("sha"):
        payload["sha"] = current["sha"]
    req = urllib.request.Request(
        f"{API_ROOT}/contents/{path}",
        data=json.dumps(payload).encode("utf-8"),
        method="PUT",
        headers={**_headers(token), "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise ReviewGateError(f"GitHub write failed with HTTP {exc.code}") from exc


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

    feature_map = {
        str(item.get("id", "")).strip(): item
        for item in review.get("features", [])
        if isinstance(item, dict) and str(item.get("id", "")).strip()
    }
    flagged = fetch_remote_json(FLAGGED_FEATURES_PATH, {"features": []}) or {"features": []}
    flagged_ids = {
        str(item.get("id", "")).strip()
        for item in flagged.get("features", [])
        if isinstance(item, dict) and bool(item.get("manual_clear_required", False))
    }
    selected = [
        item for item in selected_ids
        if item in feature_map
        and not bool(feature_map[item].get("locked", False))
        and item not in flagged_ids
    ]
    if decision == "accepted" and not selected:
        raise ReviewGateError("Select at least one non-locked feature before accepting.")

    checkpoint = _branch_head(token) if decision == "accepted" else ""
    selected_features = [
        {
            "id": feature_id,
            "title": str(feature_map[feature_id].get("title", ""))[:160],
            "category": str(feature_map[feature_id].get("category", ""))[:80],
            "implementation_class": str(feature_map[feature_id].get("implementation_class", "review_required"))[:80],
        }
        for feature_id in selected
    ]

    gate = {
        "schema": 2,
        "bundle_id": bundle_id,
        "council_id": str(review.get("council_id", "")),
        "decision": decision,
        "selected_feature_ids": selected if decision == "accepted" else [],
        "selected_features": selected_features if decision == "accepted" else [],
        "reviewed_utc": utc_now(),
        "reviewer": "owner",
        "implementation_authorized": decision == "accepted",
        "auto_merge_authorized": False,
        "rollback_checkpoint_sha": checkpoint,
        "rollback_checkpoint_utc": utc_now() if checkpoint else "",
        "rollback_status": "armed" if checkpoint else "not_armed",
        "implementation_changed_files": [],
        "note": (
            "Selected prepared features are authorized for staged implementation and validation. "
            "A pre-implementation rollback checkpoint has been captured. Source changes still require tests, "
            "milestone locks, autonomy guard, and no-auto-merge policy."
            if decision == "accepted"
            else "Prepared update is held. Autonomous source implementation must not proceed for this bundle."
        ),
    }
    _write_json(GATE_PATH, token, gate, f"gate: {decision} development bundle {bundle_id}")
    return gate


def request_rollback(*, token: str, gate: dict, reason: str) -> dict:
    if not token:
        raise ReviewGateError("Missing GitHub contents token.")
    if str(gate.get("decision", "")) != "accepted":
        raise ReviewGateError("Only an accepted development bundle can be rolled back.")
    if not bool(gate.get("implementation_authorized", False)):
        raise ReviewGateError("This development bundle is not currently implementation-authorized.")
    checkpoint = str(gate.get("rollback_checkpoint_sha", "")).strip()
    if not checkpoint:
        raise ReviewGateError("Accepted bundle has no rollback checkpoint.")
    bundle_id = str(gate.get("bundle_id", "")).strip()
    if not bundle_id:
        raise ReviewGateError("Accepted bundle is missing its bundle ID.")
    reason = reason.strip()
    if len(reason) < 8:
        raise ReviewGateError("Provide a short rollback reason so the feature can be flagged with useful evidence.")

    request = {
        "schema": 1,
        "request_id": f"rollback-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}",
        "bundle_id": bundle_id,
        "checkpoint_sha": checkpoint,
        "requested_utc": utc_now(),
        "requested_by": "owner",
        "reason": reason[:800],
        "status": "requested",
        "selected_feature_ids": list(gate.get("selected_feature_ids", [])),
        "selected_features": list(gate.get("selected_features", [])),
        "policy": "Restore implementation-sensitive files to the captured pre-implementation checkpoint by forward commit, preserve a backup branch, then block/flag rolled-back features from autonomous reintroduction.",
    }
    _write_json(
        ROLLBACK_REQUEST_PATH,
        token,
        request,
        f"rollback: request bundle {bundle_id}",
    )
    return request
