#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GATE = ROOT / "runtime" / "development_gate.json"

SAFE_PREFIXES = ("scripts/", "game_data/", "assets/", "tests/", "tests_ai_lab/", "streamlit_lab/")
SAFE_EXACT = {"project.godot", "main.tscn", "export_presets.cfg", "streamlit_app.py"}
DENY_PREFIXES = ("runtime/", "reports/", "codex_backlog/", ".github/")


def load(path: Path, default):
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else default
    except Exception:
        return default


def allowed(path: str) -> bool:
    path = path.replace("\\", "/").strip()
    return bool(path) and not path.startswith(DENY_PREFIXES) and (path in SAFE_EXACT or path.startswith(SAFE_PREFIXES))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()

    gate = load(GATE, {})
    if str(gate.get("decision", "")) != "accepted" or not bool(gate.get("implementation_authorized", False)):
        raise SystemExit("Current bundle is not accepted for implementation.")
    paths = sorted({p.replace("\\", "/") for p in args.paths if allowed(p)})
    if not paths:
        raise SystemExit("No rollback-eligible implementation paths supplied.")
    gate["implementation_changed_files"] = paths
    gate["rollback_status"] = "armed_with_manifest"
    GATE.write_text(json.dumps(gate, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps({"ok": True, "bundle_id": gate.get("bundle_id"), "implementation_changed_files": paths}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
