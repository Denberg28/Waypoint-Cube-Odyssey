#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GATE = ROOT / "runtime" / "development_gate.json"
REQUEST = ROOT / "runtime" / "implementation_request.json"

SAFE_PREFIXES = ("scripts/", "game_data/", "assets/", "tests/", "tests_ai_lab/", "streamlit_lab/")
SAFE_EXACT = {"project.godot", "main.tscn", "export_presets.cfg", "streamlit_app.py"}
DENY_PREFIXES = ("runtime/", "reports/", "codex_backlog/", ".github/")


def load(path: Path, default):
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else default
    except Exception:
        return default


def save(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False), encoding="utf-8")


def allowed(path: str) -> bool:
    path = path.replace("\\", "/").strip()
    return bool(path) and not path.startswith(DENY_PREFIXES) and (path in SAFE_EXACT or path.startswith(SAFE_PREFIXES))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()

    gate = load(GATE, {})
    request = load(REQUEST, {})
    if str(gate.get("decision", "")) != "accepted" or not bool(gate.get("implementation_authorized", False)):
        raise SystemExit("Current bundle is not accepted for implementation.")
    if str(request.get("bundle_id", "")) != str(gate.get("bundle_id", "")):
        raise SystemExit("Implementation request does not match the accepted bundle.")
    if str(request.get("status", "")) not in {"requested", "in_progress"}:
        raise SystemExit("No active implementation request is ready to record.")

    paths = sorted({p.replace("\\", "/") for p in args.paths if allowed(p)})
    if not paths:
        raise SystemExit("No rollback-eligible implementation paths supplied.")

    request["changed_files"] = paths
    request["status"] = "completed"

    implemented = set(str(x) for x in gate.get("implemented_feature_ids", []))
    implemented.update(str(x) for x in request.get("selected_feature_ids", []))
    gate["implemented_feature_ids"] = sorted(implemented)
    gate["implementation_changed_files"] = paths
    gate["rollback_status"] = "armed_with_manifest"
    gate["implementation_request_id"] = str(request.get("request_id", ""))

    save(REQUEST, request)
    save(GATE, gate)
    print(json.dumps({
        "ok": True,
        "bundle_id": gate.get("bundle_id"),
        "implemented_feature_ids": gate["implemented_feature_ids"],
        "implementation_changed_files": paths,
    }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
