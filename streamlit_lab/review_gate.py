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
IMPLEMENTATION_REQUEST_PATH = "runtime/implementation_request.json"
FLAGGED_FEATURES_PATH = "runtime/flagged_features.json"
DECISIONS_PATH = "runtime/development_decisions.json"
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


def _read_json_api(path: str, token: str, default: Any) -> Any:
    payload = _github_contents(path, token)
    encoded = str(payload.get("content", "")).replace("\n", "")
    if not encoded:
        return default
    try:
        return json.loads(base64.b64decode(encoded).decode("utf-8"))
    except Exception:
        return default


def _branch_head(token: str) -> str:
    req = urllib.request.Request(
        f"{API_ROOT}/git/ref/heads/{BRANCH}",
        headers=_headers(token),
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise ReviewGateError(f"Unable to capture implementation checkpoint: HTTP {exc.code}") from exc
    sha = str(data.get("object", {}).get("sha", "")).strip()
    if not sha:
        raise ReviewGateError("Unable to capture implementation checkpoint SHA.")
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


def _feature_snapshot(item: dict) -> dict:
    return {
        "id": str(item.get("id", ""))[:200],
        "title": str(item.get("title", ""))[:160],
        "category": str(item.get("category", ""))[:80],
        "implementation_class": str(item.get("implementation_class", "review_required"))[:80],
    }


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
    selected = [
        fid for fid in selected_ids
        if fid in feature_map and not bool(feature_map[fid].get("locked", False))
    ]
    if decision == "accepted" and not selected:
        raise ReviewGateError("Select at least one available feature before accepting.")

    current = _read_json_api(GATE_PATH, token, {})
    same_bundle = isinstance(current, dict) and str(current.get("bundle_id", "")) == bundle_id
    existing_ids = set(current.get("selected_feature_ids", [])) if same_bundle and str(current.get("decision", "")) == "accepted" else set()

    if decision == "accepted":
        accepted_ids = sorted(existing_ids | set(selected))
        accepted_features = [_feature_snapshot(feature_map[fid]) for fid in accepted_ids if fid in feature_map]

        # Explicit owner re-acceptance is also the manual clearance path for a
        # previously rolled-back feature. This keeps rollback quarantine strict
        # until the owner deliberately selects the feature again.
        flags = _read_json_api(FLAGGED_FEATURES_PATH, token, {"schema": 1, "features": []})
        remaining_flags = [
            item for item in flags.get("features", [])
            if not (
                isinstance(item, dict)
                and str(item.get("id", "")) in set(selected)
                and bool(item.get("manual_clear_required", False))
            )
        ]
        if len(remaining_flags) != len(flags.get("features", [])):
            flags = {"schema": 1, "updated_utc": utc_now(), "features": remaining_flags}
            _write_json(FLAGGED_FEATURES_PATH, token, flags, f"gate: clear owner-reviewed rollback flags for {bundle_id}")

        gate = dict(current) if same_bundle else {}
        gate.update({
            "schema": 3,
            "bundle_id": bundle_id,
            "council_id": str(review.get("council_id", "")),
            "decision": "accepted",
            "selected_feature_ids": accepted_ids,
            "selected_features": accepted_features,
            "reviewed_utc": utc_now(),
            "reviewer": "owner",
            "implementation_authorized": True,
            "auto_merge_authorized": False,
            "implemented_feature_ids": list(gate.get("implemented_feature_ids", [])),
            "note": "Accepted features are moved to Accepted Updates. Unselected features remain pending in Development Review.",
        })
    else:
        # HOLD is intentionally non-destructive. It never erases already accepted
        # items; unselected features simply remain pending.
        gate = dict(current) if same_bundle else {
            "schema": 3,
            "bundle_id": bundle_id,
            "council_id": str(review.get("council_id", "")),
            "selected_feature_ids": [],
            "selected_features": [],
            "implemented_feature_ids": [],
        }
        gate["decision"] = "accepted" if gate.get("selected_feature_ids") else "hold"
        gate["reviewed_utc"] = utc_now()
        gate["reviewer"] = "owner"
        gate["implementation_authorized"] = bool(gate.get("selected_feature_ids"))
        gate["auto_merge_authorized"] = False
        gate["note"] = "Pending features were left on hold. Existing accepted features were preserved."

    _write_json(GATE_PATH, token, gate, f"gate: {decision} development features for {bundle_id}")

    history = _read_json_api(DECISIONS_PATH, token, {"schema": 1, "decisions": []})
    decisions = [
        item for item in history.get("decisions", [])
        if isinstance(item, dict) and str(item.get("bundle_id", "")) != bundle_id
    ]
    decisions.append({
        "bundle_id": bundle_id,
        "council_id": str(review.get("council_id", "")),
        "decision": str(gate.get("decision", decision)),
        "reviewed_utc": gate["reviewed_utc"],
        "selected_feature_ids": list(gate.get("selected_feature_ids", [])),
        "selected_features": list(gate.get("selected_features", [])),
        "auto_merge_authorized": False,
    })
    _write_json(
        DECISIONS_PATH,
        token,
        {"schema": 1, "updated_utc": utc_now(), "decisions": decisions[-50:]},
        f"gate: archive development decision for {bundle_id}",
    )
    return gate


def request_implementation(*, token: str, gate: dict, selected_ids: list[str]) -> dict:
    if not token:
        raise ReviewGateError("Missing GitHub contents token.")
    if str(gate.get("decision", "")) != "accepted" or not bool(gate.get("implementation_authorized", False)):
        raise ReviewGateError("This bundle is not accepted for implementation.")

    bundle_id = str(gate.get("bundle_id", "")).strip()
    if not bundle_id:
        raise ReviewGateError("Accepted bundle is missing its bundle ID.")

    accepted_map = {
        str(item.get("id", "")): item
        for item in gate.get("selected_features", [])
        if isinstance(item, dict)
    }
    implemented_ids = set(str(x) for x in gate.get("implemented_feature_ids", []))
    selected = [fid for fid in selected_ids if fid in accepted_map and fid not in implemented_ids]
    if not selected:
        raise ReviewGateError("Select at least one accepted, not-yet-implemented feature.")

    existing = _read_json_api(IMPLEMENTATION_REQUEST_PATH, token, {})
    if (
        str(existing.get("bundle_id", "")) == bundle_id
        and str(existing.get("status", "")) in {"requested", "in_progress"}
    ):
        raise ReviewGateError("An implementation batch is already active. Finish it before starting another.")

    checkpoint = _branch_head(token)
    selected_features = [accepted_map[fid] for fid in selected]

    request = {
        "schema": 2,
        "request_id": f"implement-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}",
        "bundle_id": bundle_id,
        "checkpoint_sha": checkpoint,
        "requested_utc": utc_now(),
        "requested_by": "owner",
        "status": "requested",
        "selected_feature_ids": selected,
        "selected_features": selected_features,
        "changed_files": [],
        "auto_merge_authorized": False,
        "policy": "Implement this selected batch only. Treat the batch atomically for rollback, record its exact changed-file manifest, and do not auto-merge.",
    }
    _write_json(IMPLEMENTATION_REQUEST_PATH, token, request, f"implement: request selected features for {bundle_id}")

    gate = dict(gate)
    gate.update({
        "schema": 3,
        "rollback_checkpoint_sha": checkpoint,
        "rollback_checkpoint_utc": utc_now(),
        "rollback_status": "armed",
        "implementation_changed_files": [],
        "implementation_request_id": request["request_id"],
        "implementation_requested_feature_ids": selected,
    })
    _write_json(GATE_PATH, token, gate, f"implement: arm rollback checkpoint for {bundle_id}")
    return request


def request_rollback(*, token: str, gate: dict, selected_ids: list[str], reason: str) -> dict:
    if not token:
        raise ReviewGateError("Missing GitHub contents token.")
    if str(gate.get("decision", "")) != "accepted":
        raise ReviewGateError("Only an accepted bundle can be rolled back.")

    bundle_id = str(gate.get("bundle_id", "")).strip()
    implementation = _read_json_api(IMPLEMENTATION_REQUEST_PATH, token, {})
    if (
        str(implementation.get("bundle_id", "")) != bundle_id
        or str(implementation.get("status", "")) != "completed"
    ):
        raise ReviewGateError("There is no completed implementation batch available for rollback.")

    batch_ids = [str(x) for x in implementation.get("selected_feature_ids", [])]
    selected = [str(x) for x in selected_ids]
    if set(selected) != set(batch_ids):
        raise ReviewGateError("Rollback is atomic for the latest implementation batch. Select all features from that implemented batch.")

    checkpoint = str(implementation.get("checkpoint_sha", "")).strip()
    changed_files = [str(x) for x in implementation.get("changed_files", [])]
    if not checkpoint or not changed_files:
        raise ReviewGateError("The completed implementation batch is missing rollback evidence.")

    reason = reason.strip()
    if len(reason) < 8:
        raise ReviewGateError("Provide a short rollback reason.")

    request = {
        "schema": 2,
        "request_id": f"rollback-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}",
        "bundle_id": bundle_id,
        "implementation_request_id": str(implementation.get("request_id", "")),
        "checkpoint_sha": checkpoint,
        "changed_files": changed_files,
        "requested_utc": utc_now(),
        "requested_by": "owner",
        "reason": reason[:800],
        "status": "requested",
        "selected_feature_ids": batch_ids,
        "selected_features": list(implementation.get("selected_features", [])),
        "policy": "Restore only this implementation batch's recorded files, preserve a backup branch, flag the rolled-back features, and return them to Development Review.",
    }
    _write_json(ROLLBACK_REQUEST_PATH, token, request, f"rollback: request implemented batch for {bundle_id}")
    return request
