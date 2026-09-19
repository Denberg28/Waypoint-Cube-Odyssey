from __future__ import annotations

import json
from pathlib import Path

from ai_lab.contracts import ALLOWED_ROUTES
from streamlit_lab.core import ROUTES


def test_gloomwood_is_promoted_and_playable_everywhere():
    catalog = Path("scripts/catalog.gd").read_text(encoding="utf-8")
    state = Path("scripts/state.gd").read_text(encoding="utf-8")
    world = Path("scripts/world.gd").read_text(encoding="utf-8")
    main = Path("scripts/main.gd").read_text(encoding="utf-8")
    bridge = Path("scripts/ai_gamemaster_bridge.gd").read_text(encoding="utf-8")
    nightly = Path("ai_gamemaster/nightly_gamemaster.py").read_text(encoding="utf-8")
    world_map = json.loads(Path("runtime/world_map.json").read_text(encoding="utf-8"))

    node = next(x for x in world_map["nodes"] if x["id"] == "gloomwood")
    assert node["status"] == "active"
    assert node["playable"] is True
    assert node["implementation"] == "procedural_route_v1"
    assert "gloomwood" in ROUTES
    assert "gloomwood" in ALLOWED_ROUTES
    assert '"gloomwood":{"name":"Gloomwood Hollow"' in catalog
    assert '["moss", "forge", "gloomwood"]' in state
    assert "State.route_options_for_stage_index" in world
    assert "State.route_options_for_stage_index" in main
    assert "Catalog.ROUTES" in bridge
    assert "game_data" in nightly and "routes.json" in nightly


def test_gloomwood_has_distinct_biome_hazard_landmark_and_collectible():
    state = Path("scripts/state.gd").read_text(encoding="utf-8")
    world = Path("scripts/world.gd").read_text(encoding="utf-8")
    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    assert 'route == "gloomwood"' in state
    assert '"gloomcap"' in state
    assert "func collect_gloomcap() -> String:" in state
    assert "data.gloomcaps += 1" in state
    assert "add_resolve(3)" in state
    assert "int(data.gloomcaps) % 3 == 0" in state
    assert "Collector milestone: +1 gem!" in state
    assert "func theme_for_route(route_id: String, base_theme: Dictionary) -> Dictionary:" in world
    assert "func gloomwood_landmark(finish_z: float) -> void:" in world
    assert "WHISPERING HOLLOW ROOT" in world
    assert "JUMP  •  BRIARS" in world
    assert "GLOOMCAP" in world
    assert "PEARLS %d   •   EMBERS %d   •   SKYFEATHERS %d" in main


def test_gloomwood_save_schema_migrates_existing_players():
    state = Path("scripts/state.gd").read_text(encoding="utf-8")
    assert '"version":17' in state
    assert '"gloomcaps":0' in state
    assert 'if not migrated.has("gloomcaps"):' in state
    assert "migrated.gloomcaps = 0" in state
    assert "12, 12.0" in state
    assert "migrated.version = 17" in state


def test_all_playable_routes_share_one_catalog_across_ai_layers():
    import ai_gamemaster.nightly_gamemaster as nightly
    from ai_lab.contracts import ALLOWED_ROUTES

    route_data = json.loads(Path("game_data/routes.json").read_text(encoding="utf-8"))
    expected = set(route_data)

    assert set(ROUTES) == expected
    assert ALLOWED_ROUTES == expected
    assert nightly.ROUTES == expected
    assert {"sunken_grotto", "cinder_caldera", "galecrest_spire"} <= expected
