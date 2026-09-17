from __future__ import annotations
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def _load(name: str, default):
    path = ROOT / "runtime" / name
    if not path.exists(): return default
    try:
        data=json.loads(path.read_text(encoding="utf-8"))
        return data
    except Exception: return default

def load_world_state() -> dict:
    data=_load("ai_world_state.json",{})
    if isinstance(data,dict) and data: return data
    return {"featured_route":"moss","difficulty_offset":0,"headline":"Night Watch is waiting for its first cycle.","challenge":{"title":"First Steps","description":"Complete any route.","target":1},"experiment":{"kind":"none","route":"moss","value":0,"reason":"No experiment active."},"adopted_feedback_ids":[]}

def load_beta_council() -> dict:
    data=_load("beta_council.json",{})
    return data if isinstance(data,dict) else {}
