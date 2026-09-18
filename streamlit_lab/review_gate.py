from __future__ import annotations

import base64
import hmac
import json
import urllib.error
import urllib.request
from datetime import datetime, timezone
from typing import Any

REPOSITORY = "Denberg28/Waypoint-Cube-Odyssey"
BRANCH = "ai-development"
STATUS_PATH = "runtime/development_status.json"
API_ROOT = f"https://api.github.com/repos/{REPOSITORY}"


class ReviewGateError(RuntimeError):
    pass


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def fetch_remote_json(path: str, default: Any = None) -> Any:
    url = f"https://raw.githubusercontent.com/{REPOSITORY}/{BRANCH}/{path}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Waypoint-Review-Monitor/1.0"})
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
        "User-Agent": "Waypoint-Review-Monitor/1.0",
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


def _snapshot(item: dict, *, bundle_id: str, council_id: str) -> dict:
    return {
        "id": str(item.get("id", ""))[:200],
        "title": str(item.get("title", "Untitled recommendation"))[:160],
        "category": str(item.get("category", "feature"))[:80],
        "priority": str(item.get("priority", "P3"))[:20],
        "source": str(item.get("source", "beta_council"))[:80],
        "tester": str(item.get("tester", ""))[:120],
        "desired_outcome": str(item.get("desired_outcome", ""))[:1200],
        "reason": str(item.get("reason", ""))[:1200],
        "recommendation_key": str(item.get("recommendation_key", ""))[:100],
        "repeat_count": max(1, int(item.get("repeat_count", 1))),
        "first_seen_utc": str(item.get("first_seen_utc", ""))[:40],
        "last_seen_utc": str(item.get("last_seen_utc", ""))[:40],
        "bundle_id": bundle_id[:200],
        "council_id": council_id[:200],
    }


def persist_monitoring_status(*, token: str, review: dict, updates: dict[str, str]) -> dict:
    if not token:
        raise ReviewGateError("Missing GitHub contents token.")

    bundle_id = str(review.get("bundle_id", "")).strip()
    council_id = str(review.get("council_id", "")).strip()
    if not bundle_id:
        raise ReviewGateError("Development review is missing a bundle ID.")

    feature_map = {
        str(item.get("id", "")).strip(): item
        for item in review.get("features", [])
        if isinstance(item, dict) and str(item.get("id", "")).strip()
    }
    if not feature_map:
        raise ReviewGateError("Development review has no trackable recommendations.")

    normalized_updates: dict[str, str] = {}
    for fid, status in updates.items():
        fid = str(fid).strip()
        status = str(status).strip().lower()
        if fid not in feature_map:
            continue
        if status not in {"open", "pending", "close"}:
            raise ReviewGateError(f"Unsupported monitoring status: {status}")
        normalized_updates[fid] = status

    if not normalized_updates:
        raise ReviewGateError("No monitoring status changes were supplied.")

    book = _read_json_api(STATUS_PATH, token, {"schema": 1, "updated_utc": "", "entries": []})
    entries = [
        item for item in book.get("entries", [])
        if isinstance(item, dict) and str(item.get("id", "")).strip()
    ]
    by_id = {str(item.get("id", "")): dict(item) for item in entries}
    now = utc_now()

    # Refresh snapshots for every recommendation in the current bundle so the
    # archive retains the latest AI description even before it is closed.
    for fid, feature in feature_map.items():
        current = by_id.get(fid, {})
        snapshot = _snapshot(feature, bundle_id=bundle_id, council_id=council_id)
        snapshot["status"] = str(current.get("status", "open")).lower()
        if snapshot["status"] not in {"open", "pending", "close"}:
            snapshot["status"] = "open"
        snapshot["status_updated_utc"] = str(current.get("status_updated_utc", ""))
        snapshot["closed_utc"] = str(current.get("closed_utc", ""))
        by_id[fid] = snapshot

    for fid, status in normalized_updates.items():
        entry = by_id[fid]
        entry["status"] = status
        entry["status_updated_utc"] = now
        if status == "close":
            entry["closed_utc"] = entry.get("closed_utc") or now
        else:
            entry["closed_utc"] = ""

    result = {
        "schema": 1,
        "updated_utc": now,
        "entries": sorted(
            by_id.values(),
            key=lambda item: (
                str(item.get("status", "")) != "close",
                str(item.get("closed_utc", "")),
                str(item.get("title", "")),
            ),
        ),
    }
    _write_json(
        STATUS_PATH,
        token,
        result,
        f"review: update recommendation monitoring status for {bundle_id}",
    )
    return result
