from __future__ import annotations

import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REMOTE_BASE = "https://raw.githubusercontent.com/Denberg28/Waypoint-Cube-Odyssey/ai-development/runtime"


def _load_local(name: str, default):
    path = ROOT / "runtime" / name
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def _load_remote(name: str, default):
    try:
        req = urllib.request.Request(
            f"{REMOTE_BASE}/{name}",
            headers={
                "User-Agent": "Waypoint-Streamlit-State/1.0",
                "Cache-Control": "no-cache",
            },
        )
        with urllib.request.urlopen(req, timeout=6) as response:
            return json.loads(response.read().decode("utf-8"))
    except Exception:
        return default


def _load(name: str, default):
    # Streamlit is deployed from main, while autonomous AI state is committed to
    # ai-development. Read that branch first so the dashboard never shows stale
    # council/world data merely because main has not been synchronized.
    remote = _load_remote(name, None)
    if remote is not None:
        return remote
    return _load_local(name, default)


def load_world_state() -> dict:
    data = _load("ai_world_state.json", {})
    if isinstance(data, dict) and data:
        return data
    return {
        "featured_route": "moss",
        "difficulty_offset": 0,
        "headline": "Night Watch is waiting for its first cycle.",
        "challenge": {"title": "First Steps", "description": "Complete any route.", "target": 1},
        "experiment": {"kind": "none", "route": "moss", "value": 0, "reason": "No experiment active."},
        "adopted_feedback_ids": [],
    }


def load_beta_council() -> dict:
    data = _load("beta_council.json", {})
    return data if isinstance(data, dict) else {}
