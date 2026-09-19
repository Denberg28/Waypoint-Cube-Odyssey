#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    raise SystemExit("SANITY_FAIL: " + message)


def read(path: str) -> str:
    p = ROOT / path
    if not p.exists():
        fail(f"missing required file: {path}")
    return p.read_text(encoding="utf-8")


def verify_resource_refs(path: str) -> None:
    text = read(path)
    for ref in sorted(set(re.findall(r'res://[^"\s)]+', text))):
        clean = ref.rstrip('",]')
        relative = clean.removeprefix("res://")
        if not (ROOT / relative).exists():
            fail(f"{path} references missing resource {clean}")


def verify_json_tree(folder: str) -> None:
    base = ROOT / folder
    for path in sorted(base.glob("*.json")):
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            fail(f"invalid JSON {path.relative_to(ROOT)}: {exc}")


def verify_routes() -> None:
    routes = json.loads(read("game_data/routes.json"))
    expected = set(routes)
    if not expected:
        fail("route catalog is empty")

    world_map = json.loads(read("runtime/world_map.json"))
    active = {
        str(node.get("id"))
        for node in world_map.get("nodes", [])
        if isinstance(node, dict) and node.get("status") == "active" and node.get("playable") is True
    }
    missing_map = expected - active
    if missing_map:
        fail(f"playable routes missing from active world map: {sorted(missing_map)}")

    contracts = read("ai_lab/contracts.py")
    nightly = read("ai_gamemaster/nightly_gamemaster.py")
    bridge = read("scripts/ai_gamemaster_bridge.gd")
    if "game_data" not in contracts or "routes.json" not in contracts:
        fail("AI contracts no longer derive routes from game_data/routes.json")
    if "game_data" not in nightly or "routes.json" not in nightly:
        fail("Night Watch no longer derives routes from game_data/routes.json")
    if "Catalog.ROUTES" not in bridge:
        fail("Godot AI bridge no longer validates against Catalog.ROUTES")


def verify_deleted_ui_stays_deleted() -> None:
    main = read("scripts/main.gd")
    refinement = read("scripts/ui_refinement.gd")
    stale = ["route_panel", "route_box", "show_routes()", "WINDOW_ROUTE_WIDTH"]
    for token in stale:
        if token in main or token in refinement:
            fail(f"stale Crossroads fallback API returned: {token}")

    for removed in [
        "scripts/ui_shell.gd",
        "scripts/header_drawer.gd",
        "scripts/ui_icon_fallback.gd",
    ]:
        if (ROOT / removed).exists():
            fail(f"retired legacy UI script returned: {removed}")


def verify_save_schema() -> None:
    state = read("scripts/state.gd")
    if '"version":16' not in state:
        fail("current save schema is not v16")
    if "migrated.version = 16" not in state:
        fail("legacy save migration does not target v16")
    if 'value.get("version") not in [16, 16.0]' not in state:
        fail("save validator does not require v16")


def main() -> None:
    verify_resource_refs("project.godot")
    verify_resource_refs("main.tscn")
    verify_json_tree("game_data")
    verify_json_tree("runtime")
    verify_routes()
    verify_deleted_ui_stays_deleted()
    verify_save_schema()
    print("SANITY_OK")


if __name__ == "__main__":
    main()
