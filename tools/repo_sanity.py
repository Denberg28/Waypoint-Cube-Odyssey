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


def verify_all_runtime_resource_refs() -> None:
    runtime_files = []
    for pattern in [
        "project.godot",
        "main.tscn",
        "scripts/**/*.gd",
    ]:
        runtime_files.extend(ROOT.glob(pattern))

    seen = set()
    for path in sorted(runtime_files):
        if not path.is_file():
            continue
        rel = str(path.relative_to(ROOT)).replace("\\", "/")
        if rel in seen:
            continue
        seen.add(rel)
        text = path.read_text(encoding="utf-8")
        for ref in sorted(set(re.findall(r'res://[^"\s)]+', text))):
            clean = ref.rstrip('",]')
            relative = clean.removeprefix("res://")
            if not (ROOT / relative).exists():
                fail(f"{rel} references missing resource {clean}")


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


def verify_modular_catalogs() -> None:
    routes_json = json.loads(read("game_data/routes.json"))
    road = read("scripts/modules/road/road_catalog.gd")
    catalog = read("scripts/catalog.gd")

    for route_id, meta in routes_json.items():
        if f'"{route_id}":' not in road:
            fail(f"route missing from Godot road catalog: {route_id}")
        name = str(meta.get("name", ""))
        if name and name not in road:
            fail(f"route name drift between JSON and Godot catalog: {route_id} -> {name}")

    for route_id in routes_json:
        if f'"{route_id}":{{' not in road:
            fail(f"road catalog definition missing for {route_id}")

    for required in [
        "CoreCatalog.GEAR",
        "MarketplaceCatalog.COSMETICS",
        "PetCatalog.CAT_RANKS",
        "RoadCatalog.ROUTES",
        "EnemyCatalog.ENEMIES",
    ]:
        if required not in catalog:
            fail(f"catalog facade lost module export: {required}")

    marketplace = read("scripts/modules/marketplace/marketplace_catalog.gd")
    cosmetic_ids = re.findall(r'"id":"([^"]+)"', marketplace)
    if len(cosmetic_ids) != len(set(cosmetic_ids)):
        fail("duplicate cosmetic id in marketplace catalog")

    pet = read("scripts/modules/pets/pet_catalog.gd")
    rank_levels = [int(x) for x in re.findall(r'"min_level":(\d+)', pet)]
    if not rank_levels or rank_levels != sorted(set(rank_levels)) or rank_levels[0] != 1:
        fail("pet rank thresholds must be unique, sorted, and begin at level 1")

    enemy = read("scripts/modules/enemy/enemy_catalog.gd")
    for enemy_id in ["slime", "goblin", "kobold", "ogre"]:
        if f'"{enemy_id}":' not in enemy:
            fail(f"enemy catalog missing required enemy: {enemy_id}")


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
    if '"version":17' not in state:
        fail("current save schema is not v17")
    if "migrated.version = 17" not in state:
        fail("legacy save migration does not target v17")
    if 'value.get("version") not in [17, 17.0]' not in state:
        fail("save validator does not require v17")


def main() -> None:
    verify_resource_refs("project.godot")
    verify_resource_refs("main.tscn")
    verify_all_runtime_resource_refs()
    verify_json_tree("game_data")
    verify_json_tree("runtime")
    verify_routes()
    verify_modular_catalogs()
    verify_deleted_ui_stays_deleted()
    verify_save_schema()
    print("SANITY_OK")


if __name__ == "__main__":
    main()
