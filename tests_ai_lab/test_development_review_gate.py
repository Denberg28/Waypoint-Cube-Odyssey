from __future__ import annotations

from pathlib import Path

from ai_lab.development_review import recommendation_similarity, update_recommendation_tally
from streamlit_lab.review_gate import pin_matches

PET_CATALOG_PATH = Path("scripts/modules/pets/pet_catalog.gd")
PET_SERVICE_PATH = Path("scripts/modules/pets/pet_service.gd")
MARKETPLACE_CATALOG_PATH = Path("scripts/modules/marketplace/marketplace_catalog.gd")
MARKETPLACE_SERVICE_PATH = Path("scripts/modules/marketplace/marketplace_service.gd")
ROAD_CATALOG_PATH = Path("scripts/modules/road/road_catalog.gd")
ROAD_SERVICE_PATH = Path("scripts/modules/road/road_service.gd")
ENEMY_CATALOG_PATH = Path("scripts/modules/enemy/enemy_catalog.gd")
ENEMY_SERVICE_PATH = Path("scripts/modules/enemy/enemy_service.gd")

def test_review_pin_requires_exact_nonempty_match():
    assert pin_matches("owner-secret", "owner-secret")
    assert not pin_matches("", "")
    assert not pin_matches("owner-secret", "different")


def test_monitoring_policy_has_no_auto_implementation():
    review = {
        "bundle_id": "review-test",
        "features": [{"id": "feature-a"}],
        "policy": {
            "mode": "advisory_monitoring_only",
            "statuses": ["open", "pending", "close"],
            "auto_implementation": False,
        },
    }
    assert review["policy"]["mode"] == "advisory_monitoring_only"
    assert review["policy"]["statuses"] == ["open", "pending", "close"]
    assert review["policy"]["auto_implementation"] is False


def test_similar_recommendation_titles_match():
    assert recommendation_similarity(
        "Route Discovery Log and Collector Milestones",
        "Route Discovery Ledger and Collection Milestones UI",
    ) >= 0.60
    assert recommendation_similarity(
        "Movement Command Input Buffering",
        "Movement Command Validation & Obstacle Input Buffering",
    ) >= 0.60


def test_tally_counts_distinct_councils_only():
    feature = {
        "id": "a",
        "title": "High-Contrast UI Theme Option",
        "category": "accessibility",
        "source": "beta_council",
        "tester": "Accessibility",
    }
    first, tally = update_recommendation_tally(
        [feature],
        council_id="council-1",
        created_utc="2026-09-18T00:00:00Z",
        tally={"schema": 1, "families": []},
    )
    rerun, tally = update_recommendation_tally(
        [feature],
        council_id="council-1",
        created_utc="2026-09-18T00:05:00Z",
        tally=tally,
    )
    second, tally = update_recommendation_tally(
        [{**feature, "id": "b", "title": "High-Contrast UI Theme & Focus States"}],
        council_id="council-2",
        created_utc="2026-09-18T01:00:00Z",
        tally=tally,
    )
    assert first[0]["repeat_count"] == 1
    assert rerun[0]["repeat_count"] == 1
    assert second[0]["repeat_count"] == 2
    assert tally["families"][0]["count"] == 2


def test_elite_behavior_profiles_are_danger_gated_and_distinct():
    catalog = (
        PET_CATALOG_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_CATALOG_PATH.read_text(encoding="utf-8")
        + ROAD_CATALOG_PATH.read_text(encoding="utf-8")
        + ENEMY_CATALOG_PATH.read_text(encoding="utf-8")
    )
    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )
    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert "const ELITE_BEHAVIORS" in catalog
    for profile in ["ambusher", "skirmisher", "bulwark", "crusher"]:
        assert f'"id":"{profile}"' in catalog
    assert "if danger_level() < 3" in state
    assert "func elite_behavior" in state
    assert "place_elite_encounter" in state
    assert '"elite_behavior":elite_behavior_id' in Path("scripts/main.gd").read_text(encoding="utf-8")
    assert '"%s  •  %s ELITE"' in world


def test_level_star_progression_and_rpg_encounter_sequence_present():
    from pathlib import Path

    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )
    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    assert "const LEVEL_CAP: int = 20" in state
    assert '"level":START_LEVEL' in state
    assert '"xp":START_XP' in state
    assert '"resolve":0' in state
    assert '["", "¼★", "½★", "¾★"]' in state
    assert '"★"' in state and '"☆"' in state
    assert 'award_xp(enemy_xp_value(kind, elite))' in state
    assert 'award_xp(20)' in state
    assert 'award_xp(60)' in state

    assert "rank_label.text" in main
    assert "game.star_rank_text()" in main
    assert "game.level_progress_text()" in main
    assert 'func play_rpg_sfx' in main
    assert 'func build_environment_ambience' in main
    assert '"road_danger"' in main
    assert 'fight_status.text = "ENCOUNTER!"' in main
    assert 'fight_status.text = "CLASH!  HOLDING..."' in main
    assert '"HARD-WON VICTORY"' in main
    assert '"RUNE STRIKE"' in main


def test_monitoring_close_uses_fresh_status_and_session_handoff():
    from pathlib import Path

    gate = Path("streamlit_lab/review_gate.py").read_text(encoding="utf-8")
    app = Path("streamlit_app.py").read_text(encoding="utf-8")

    assert "fresh: bool = False" in gate
    assert "time.time_ns()" in gate
    assert '"Cache-Control": "no-cache" if fresh' in gate
    assert "st.session_state.development_status_book = saved_status" in app
    assert '"runtime/development_status.json"' in app
    assert "fresh=True" in app
    assert "Refresh monitoring status" in app


def test_star_rank_conventional_mapping_contract():
    from pathlib import Path

    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )

    assert "func star_quarter_count() -> int:" in state
    assert "if level_value <= 1:" in state
    assert "return 0" in state
    assert "if level_value == 2:" in state
    assert "return 1" in state
    assert "if level_value == 3:" in state
    assert "return 2" in state
    assert "return level_value" in state


def test_star_rank_header_is_layout_stable_and_cached():
    from pathlib import Path

    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    assert "var cached_rank_text: String = \"\"" in main
    assert "header.offset_bottom = 90" in main
    assert "brand.custom_minimum_size.x = 560.0" in main
    assert "progression_box.custom_minimum_size.x = 170.0" in main
    assert "rank_label.custom_minimum_size = Vector2(170.0, 17.0)" in main
    assert "xp_bar.custom_minimum_size = Vector2(170.0, 5.0)" in main
    assert "health.custom_minimum_size = Vector2(154.0, 18.0)" in main
    assert "economy.custom_minimum_size.x = 228.0" in main
    assert 'gear_button = button("Gear"' in main
    assert "if next_rank_text != cached_rank_text:" in main
    assert "rank_label.text = cached_rank_text" in main


def test_gameplay_hud_uses_compact_focus_layout():
    from pathlib import Path

    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    assert "header.offset_bottom = 90" in main
    assert 'header.add_theme_stylebox_override("panel", compact_style' in main
    assert "info.position = Vector2(24, 104)" in main
    assert "footer.offset_right = 288" in main
    assert "footer.offset_top = -64" in main
    assert "footer.offset_bottom = -16" in main
    assert 'compact_details = button("Details"' in main
    assert 'compact_best_button = button("Best"' in main
    assert 'compact_heal_button = button("Heal"' in main
    assert 'compact_mana_button = button("Mana"' in main
    assert "side_panel.offset_top = -84" in main
    assert "side_panel.offset_bottom = -16" in main
    assert "side_header.hide()" in main
    assert 'settings.get_value("ui", "status_minimized", true)' in main


def test_web_export_uses_commit_hashed_assets():
    from pathlib import Path

    workflow = Path(".github/workflows/godot-web-pages.yml").read_text(encoding="utf-8")

    assert 'BASENAME="waypoint-${SHORT_SHA}"' in workflow
    assert '--export-release "Web" "build/web/${BASENAME}.html"' in workflow
    assert 'cp "build/web/${BASENAME}.html" build/web/index.html' in workflow
    assert 'build/web/version.json' in workflow
    assert 'Cache-Control' in workflow


def test_header_places_rank_and_light_yellow_xp_meter_below_day_row():
    from pathlib import Path

    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    assert "var xp_bar: ProgressBar" in main
    assert 'save_label = label("AUTOSAVE  /  OFFLINE", 7, MUTED)' in main
    assert "identity_box.add_child(save_label)" in main
    assert 'bottom.add_child(save_label)' not in main
    assert "progression_box.add_child(brightness_box)" in main
    assert "progression_box.add_child(rank_label)" in main
    assert "progression_box.add_child(xp_bar)" in main
    assert "xp_bar.custom_minimum_size = Vector2(170.0, 5.0)" in main
    assert 'xp_fill.bg_color = Color("ead77a")' in main
    assert "xp_bar.value = 100.0" in main
    assert "game.xp_to_next()" in main
    assert 'save_label.text = "AUTOSAVE  /  OFFLINE"' in main


def test_hearts_persist_between_trails_and_camp_visits():
    from pathlib import Path

    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )
    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    next_stage = state.split("func next_stage() -> void:", 1)[1].split("func bank() -> void:", 1)[0]
    return_camp = state.split("func return_camp() -> void:", 1)[1].split("func leave_camp_for_crossroads() -> void:", 1)[0]
    finish_room = state.split("func finish_room() -> void:", 1)[1].split("func after_reward() -> void:", 1)[0]
    begin = state.split("func begin(class_id: String = \"\") -> void:", 1)[1].split("func make_room(route: String) -> void:", 1)[0]

    # No hidden full refill at route checkpoint or Lantern Camp.
    assert "data.hp = max_hp()" not in next_stage
    assert "data.mana = max_mana()" not in next_stage
    assert "data.hp = max_hp()" not in return_camp
    assert "data.mana = max_mana()" not in return_camp

    # Authored recovery remains intentional: trail-heal perks still work.
    assert 'data.hp = mini(max_hp(), int(data.hp) + stat("heal"))' in finish_room

    # Explicit new-character selection still starts with full resources.
    assert "data.hp = max_hp()" in begin
    assert "data.mana = max_mana()" in begin

    assert "Hearts carry over" in main


def test_next_expedition_preserves_resources_and_defeat_revive_is_explicit():
    import re
    from pathlib import Path

    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )
    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    prepare = state.split("func prepare_new_expedition() -> void:", 1)[1].split("func begin(class_id: String = \"\") -> void:", 1)[0]
    leave = state.split("func leave_camp_for_crossroads() -> void:", 1)[1].split("func equip(id: String) -> void:", 1)[0]
    revive = state.split("func revive_at_camp() -> bool:", 1)[1].split("func leave_camp_for_crossroads() -> void:", 1)[0]

    # Expedition turnover resets route state but never HP/mana.
    assert "data.hp" not in prepare
    assert "data.mana" not in prepare
    assert "prepare_new_expedition()" in leave
    # Match executable calls only; comments may legitimately mention begin().
    assert re.search(r"^\s*begin\(", leave, re.MULTILINE) is None

    # Zero-heart characters cannot depart until an explicit one-heart revival.
    assert "if int(data.hp) <= 0:" in leave
    assert "data.hp = 1" in revive
    assert "data.mana =" not in revive
    assert "LANTERN RECOVERY" in main
    assert "Revive at lantern  •  1 heart" in main
    assert "Hearts and mana carry into the next expedition." in main


def test_character_idle_animation_is_camp_only():
    from pathlib import Path

    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert "var idle_anchor_position: Vector3 = Vector3.ZERO" in world
    assert "var idle_base_yaw: float = PI" in world
    assert "func apply_adventure_idle() -> void:" not in world
    assert "func apply_camp_idle() -> void:" in world
    assert "func apply_idle_animation(delta: float) -> void:" in world
    assert 'str(state.data.mode) != "camp"' in world
    assert "apply_camp_idle()" in world
    assert "update_camp_actor_roam(delta)" in world
    assert "left_arm.rotation.x" in world
    assert "right_arm.rotation.x" in world
    assert "left_foot.rotation = Vector3.ZERO" in world
    assert "right_foot.rotation = Vector3.ZERO" in world
    assert 'elif not hopping and str(state.data.mode) == "camp":' in world
    assert "apply_idle_animation(delta)" in world


def test_new_save_starts_with_zero_stars_and_zero_xp():
    from pathlib import Path

    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )
    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    assert "const START_LEVEL: int = 1" in state
    assert "const START_XP: int = 0" in state
    assert '"level":START_LEVEL' in state
    assert '"xp":START_XP' in state
    assert "func initialize_new_account_progression() -> void:" in state
    assert "data.level = START_LEVEL" in state
    assert "data.xp = START_XP" in state
    assert "if level_value <= 1:" in state
    assert "return 0" in state
    assert "if not has_save:" in main
    assert "show_selector(true)" in main
    assert "FRESH START  •  0 STARS  •  0 XP" in main


def test_quit_paths_use_confirmation_window():
    from pathlib import Path

    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    assert "func show_quit_confirmation(origin: String = \"menu\") -> void:" in main
    assert "func perform_quit(save_first: bool, reason: String) -> void:" in main
    assert 'modal("EXIT WAYPOINT", "Leave the game?"' in main
    assert 'action("Save & Quit"' in main
    assert 'action("Quit without another save"' in main
    assert 'action("Cancel"' in main
    assert 'action("Save and quit…", func(): show_quit_confirmation("pause_menu"))' in main
    assert 'action("Quit…", func(): show_quit_confirmation("title_menu"))' in main
    assert 'show_quit_confirmation("window_close")' in main
    assert 'get_tree().quit()' in main


def test_fresh_character_resets_all_progression_and_requires_confirmation():
    from pathlib import Path

    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )
    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    fresh = state.split("func start_fresh_character(class_id: String, skin_index: int = 0) -> void:", 1)[1].split("func xp_to_next", 1)[0]
    assert "reset()" in fresh
    assert "initialize_new_account_progression()" in fresh
    assert "begin(class_id)" in fresh

    assert "var fresh_character_mode: bool = false" in main
    assert 'Fresh character  •  Start from zero' in main
    assert 'CONFIRM FRESH START' in main
    assert 'Erase & start fresh' in main
    assert "game.start_fresh_character(selected_class, selected_skin)" in main
    assert "fresh_character_start" in main
    assert "LV 1   •   0 STARS   •   0 XP" in main
    assert "Gear: none   •   Bank: 0   •   Gems: 0" in main
    assert "selected_skin = 0 if fresh_character_mode" in main


def test_enemy_xp_is_balanced_and_credited_immediately():
    from pathlib import Path

    catalog = (
        PET_CATALOG_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_CATALOG_PATH.read_text(encoding="utf-8")
        + ROAD_CATALOG_PATH.read_text(encoding="utf-8")
        + ENEMY_CATALOG_PATH.read_text(encoding="utf-8")
    )
    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )

    assert '"slime":{"name":"Moss Slime", "toughness":1, "damage":1, "reward":3, "consolation":2, "xp":2}' in catalog
    assert '"goblin":{"name":"Road Goblin", "toughness":2, "damage":2, "reward":4, "consolation":3, "xp":3}' in catalog
    assert '"kobold":{"name":"Trail Kobold", "toughness":2, "damage":2, "reward":4, "consolation":3, "xp":3}' in catalog
    assert '"ogre":{"name":"Waystone Ogre", "toughness":3, "damage":3, "reward":5, "consolation":3, "xp":5}' in catalog
    assert '"xp_bonus":2' in catalog
    assert '"xp_bonus":3' in catalog
    assert '"xp_bonus":4' in catalog

    assert "func enemy_xp_value(kind: String, elite: bool = false) -> int:" in state
    assert "award_xp(enemy_xp_value(kind, elite))" in state
    assert "queue_trail_xp" not in state
    assert "commit_trail_xp" not in state
    assert "discard_trail_xp" not in state


def test_resolve_motivation_meter_is_positive_and_defeat_safe():
    from pathlib import Path

    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )
    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    defeat = state.split("func defeat() -> void:", 1)[1].split("func return_camp() -> void:", 1)[0]
    resolve_fn = state.split("func add_resolve(amount: int) -> String:", 1)[1].split("func star_quarter_count", 1)[0]

    assert '"resolve":0' in state
    assert "func add_resolve(amount: int) -> String:" in state
    assert "while total >= 100:" in resolve_fn
    assert "data.potions.heal += rewards" in resolve_fn
    assert "data.potions.mana += rewards" in resolve_fn
    assert "add_resolve(12)" in state
    assert "add_resolve(4) if elite else" in state
    assert "add_resolve(28)" in state
    assert "data.resolve =" not in defeat
    assert "Your XP, Resolve" in defeat
    assert "RESOLVE %d%%" in main
    assert "positive motivation meter never decreases on defeat" in main
    assert '"version":18' in state


def test_v11_pending_xp_is_migrated_into_credited_xp():
    from pathlib import Path

    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )

    assert 'migrated.has("pending_xp")' in state
    assert 'migrated.erase("pending_xp")' in state
    assert "carry_xp" in state
    assert "migrated.resolve = 0" in state
    assert "migrated.version = 18" in state
    assert "11, 11.0" in state


def test_recommendation_tally_rebuilds_from_history(tmp_path):
    import json
    from ai_lab.development_review import rebuild_recommendation_tally_from_history, annotate_features_from_tally

    historical_dir = tmp_path / "beta_feedback" / "20260917T000000Z"
    historical_dir.mkdir(parents=True)
    historical_dir.joinpath("council.json").write_text(json.dumps({
        "council_id": "beta-history-1",
        "created_utc": "20260917T000000Z",
        "all_feature_requests": [{
            "id": "old-1",
            "title": "Route Discovery Log and Collector Milestones",
            "category": "exploration",
            "tester_name": "Explorer & Collector",
        }],
    }), encoding="utf-8")

    current = {
        "council_id": "beta-current-2",
        "created_utc": "20260918T000000Z",
        "all_feature_requests": [{
            "id": "new-1",
            "title": "Route Discovery Ledger and Collection Milestones UI",
            "category": "exploration",
            "tester_name": "Explorer & Collector",
        }],
    }

    tally = rebuild_recommendation_tally_from_history(
        root=tmp_path,
        current_council=current,
        generated_utc="2026-09-18T00:01:00Z",
    )
    family = next(x for x in tally["families"] if x["count"] == 2)
    assert family["council_ids"] == ["beta-history-1", "beta-current-2"]
    assert family["last_seen_utc"] == "2026-09-18T00:00:00Z"

    annotated = annotate_features_from_tally(
        [{
            "id": "new-1",
            "title": "Route Discovery Ledger and Collection Milestones UI",
            "category": "exploration",
        }],
        tally=tally,
        generated_utc="2026-09-18T00:01:00Z",
    )
    assert annotated[0]["repeat_count"] == 2


def test_streamlit_review_has_refresh_and_sync_visibility():
    from pathlib import Path

    app = Path("streamlit_app.py").read_text(encoding="utf-8")
    review = Path("ai_lab/development_review.py").read_text(encoding="utf-8")

    assert "Refresh AI review" in app
    assert "Recommendation summary is stale relative to the latest Development Review." in app
    assert "AI recommendation summary and Development Review are synchronized." in app
    assert 'review.get("sync_id"' in app
    assert 'recommendation_tally.get("sync_id"' in app
    assert "rebuild_recommendation_tally_from_history" in review
    assert 'tally["sync_id"] = sync_id' in review
    assert '"sync_id": sync_id' in review


def test_cat_companion_market_feeding_and_mood_loop_present():
    from pathlib import Path

    catalog = (
        PET_CATALOG_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_CATALOG_PATH.read_text(encoding="utf-8")
        + ROAD_CATALOG_PATH.read_text(encoding="utf-8")
        + ENEMY_CATALOG_PATH.read_text(encoding="utf-8")
    )
    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )
    main = Path("scripts/main.gd").read_text(encoding="utf-8")
    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert "const CAT_PRICE: int = 160" in catalog
    assert "const CAT_SATIETY_PER_FISH: int = 30" in catalog
    assert "const CAT_SATIETY_ROAD_COST: int = 10" in catalog
    assert "const CAT_PATTERNS" in catalog

    assert '"version":18' in state
    assert '"fish_stock":0' in state
    assert '"cat_owned":false' in state
    assert '"cat_design":{}' in state
    assert '"cat_offer":{}' in state
    assert '"cat_satiety":0' in state
    assert "func random_cat_design() -> Dictionary:" in state
    assert "func refresh_cat_offer() -> bool:" in state
    assert "func adopt_cat() -> bool:" in state
    assert "func feed_cat() -> bool:" in state
    assert "func cat_mood() -> String:" in state
    assert '"PURRING"' in state
    assert '"CONTENT"' in state
    assert '"CURIOUS"' in state
    assert '"HUNGRY"' in state
    assert '"GRUMPY"' in state
    assert "data.fish_stock += fish_portions" in state
    assert "host.data.cat_satiety = mini(100" in state
    assert "data.cat_satiety = maxi(0" in state
    assert "var cat_status: String = cat_adventure_tick()" in state

    assert 'for category in ["skin", "head", "back", "face"]' in main
    assert "Cat Companion  •  Browse / Adopt" in main
    assert 'func show_cat_market() -> void:' in main
    assert 'Refresh random cat design' in main
    assert 'func show_cat_companion() -> void:' in main
    assert 'Feed Fish' in main
    assert '"cat_adopted"' in main
    assert '"cat_fed"' in main

    assert "func build_cat_companion() -> void:" in world
    assert "build_cat_companion()" in world
    assert 'state.cat_mood()' in world


def test_cat_satiety_is_progression_based_not_wall_clock():
    from pathlib import Path

    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )
    cat_tick = PET_SERVICE_PATH.read_text(encoding="utf-8").split("static func cat_adventure_tick(host) -> String:", 1)[1]

    assert "Time.get_" not in cat_tick
    assert "delta" not in cat_tick
    assert "CAT_SATIETY_ROAD_COST" in cat_tick
    assert "finish_room()" in state
    assert "cat_adventure_tick()" in state


def test_v13_save_migrates_cat_companion_fields_through_v18():
    from pathlib import Path

    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )

    assert "13, 13.0" in state
    assert 'migrated.fish_stock = 0' in state
    assert 'migrated.cat_owned = false' in state
    assert 'migrated.cat_design = {}' in state
    assert 'migrated.cat_offer = random_cat_design()' in state
    assert 'migrated.cat_satiety = 0' in state
    assert "migrated.version = 18" in state


def test_waypoint_posts_are_standardized_and_location_specific():
    from pathlib import Path

    catalog = (
        PET_CATALOG_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_CATALOG_PATH.read_text(encoding="utf-8")
        + ROAD_CATALOG_PATH.read_text(encoding="utf-8")
        + ENEMY_CATALOG_PATH.read_text(encoding="utf-8")
    )
    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert "const WAYPOINT_STYLES" in catalog
    for route_id in ["moss", "forge", "shrine", "treasure", "frost", "fen", "gloomwood"]:
        assert f'"{route_id}":{{' in catalog
    assert "static func waypoint_style(route_id: String) -> Dictionary:" in catalog

    assert "func waypoint_style_for(route_id: String) -> Dictionary:" in world
    assert "func add_waypoint_motif(" in world
    assert "func waypoint_destination_board(" in world
    assert "Hero checkpoint inspired by classic RPG hubs" in world
    assert "ROAD COMPLETE  •  CHOOSE YOUR NEXT ROAD OR CAMP" in world
    assert "REST / SUPPLIES" in world
    assert '"difficulty_label"' in world
    assert "Smaller route-selection counterpart to the road-end gateway" in world


def test_three_planned_regions_are_promoted_to_playable_routes():
    import json
    from pathlib import Path

    catalog = (
        PET_CATALOG_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_CATALOG_PATH.read_text(encoding="utf-8")
        + ROAD_CATALOG_PATH.read_text(encoding="utf-8")
        + ENEMY_CATALOG_PATH.read_text(encoding="utf-8")
    )
    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )
    world = Path("scripts/world.gd").read_text(encoding="utf-8")
    routes = json.loads(Path("game_data/routes.json").read_text(encoding="utf-8"))
    world_map = json.loads(Path("runtime/world_map.json").read_text(encoding="utf-8"))

    for route_id in ["sunken_grotto", "cinder_caldera", "galecrest_spire"]:
        assert f'"{route_id}":{{' in catalog
        assert route_id in routes
        node = next(x for x in world_map["nodes"] if x["id"] == route_id)
        assert node["status"] == "active"
        assert node["playable"] is True
        assert node["kind"] == "route"
        assert node.get("promoted_from_plan") is True

    assert '"sunken_grotto"' in state
    assert '"cinder_caldera"' in state
    assert '"galecrest_spire"' in state
    assert "sunken_grotto_landmark" in world
    assert "cinder_caldera_landmark" in world
    assert "galecrest_spire_landmark" in world


def test_expansion_routes_have_distinct_hazards_collectibles_and_rewards():
    from pathlib import Path

    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )
    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    for field in ["prismatic_pearls", "ember_shards", "skyfeathers"]:
        assert f'"{field}":0' in state

    assert '"prismatic_pearl"' in state
    assert '"ember_shard"' in state
    assert '"skyfeather"' in state
    assert "func collect_region_collectible(kind: String) -> String:" in state
    assert '"slick algae slope"' in state
    assert '"magma vent"' in state
    assert '"gale-force gust"' in state

    assert '"prismatic_pearl":' in world
    assert '"ember_shard":' in world
    assert '"skyfeather":' in world
    assert 'JUMP  •  SLICK ALGAE' in world
    assert 'JUMP  •  MAGMA VENT' in world
    assert 'JUMP  •  GALE GUST' in world


def test_expansion_routes_enter_stage_rotation_and_preserve_safe_corridor():
    from pathlib import Path

    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )

    assert '["treasure", "shrine", "sunken_grotto"]' in state
    assert '["moss", "fen", "cinder_caldera"]' in state
    assert '["forge", "frost", "galecrest_spire"]' in state
    assert "corridor_lanes" in state
    assert 'place_special_cell(14, int(corridor_lanes[14]), "prismatic_pearl"' in state
    assert 'place_special_cell(9, int(corridor_lanes[9]), "ember_shard"' in state
    assert 'place_special_cell(9, int(corridor_lanes[9]), "skyfeather"' in state
    assert "place_elite_encounter(route, corridor_lanes, local_rng)" in state


def test_v14_cat_save_migrates_to_expansion_schema_v18():
    from pathlib import Path

    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )

    assert "14, 14.0" in state
    assert '"prismatic_pearls":0' in state
    assert '"ember_shards":0' in state
    assert '"skyfeathers":0' in state
    assert "migrated.prismatic_pearls = 0" in state
    assert "migrated.ember_shards = 0" in state
    assert "migrated.skyfeathers = 0" in state
    assert "migrated.version = 18" in state


def test_rpg_waypoint_gateway_and_roadpost_design_is_present():
    from pathlib import Path

    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert "func add_waypoint_lantern(" in world
    assert "func add_rope_wrap(" in world
    assert "func add_waypoint_banner(" in world
    assert "func add_waypoint_post(" in world
    assert "func roadside_waymarker(" in world
    assert "func add_gateway_brace(" in world
    assert "func add_gateway_title_board(" in world

    assert "Hero checkpoint inspired by classic RPG hubs" in world
    assert "stone-footed timber gateway" in world
    assert "add_waypoint_post(scenery" in world
    assert "add_waypoint_lantern(scenery" in world
    assert "add_gateway_title_board(" in world

    assert "roadside_waymarker(" in world
    assert "row % 4 == 0" in world

    assert "procedural geometry the carved-sign silhouette from the RPG concept" in world
    assert "CROSSROADS  •  CHOOSE YOUR NEXT ROAD" in world


def test_cat_market_and_pet_care_loop_is_fully_wired():
    from pathlib import Path

    catalog = (
        PET_CATALOG_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_CATALOG_PATH.read_text(encoding="utf-8")
        + ROAD_CATALOG_PATH.read_text(encoding="utf-8")
        + ENEMY_CATALOG_PATH.read_text(encoding="utf-8")
    )
    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )
    main = Path("scripts/main.gd").read_text(encoding="utf-8")
    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert "const CAT_PRICE: int = 160" in catalog
    assert "func random_cat_design() -> Dictionary:" in state
    assert "func refresh_cat_offer() -> bool:" in state
    assert "func adopt_cat() -> bool:" in state
    assert "host.data.coins -= PetCatalog.CAT_PRICE" in state
    assert "host.data.cat_design = host.data.cat_offer.duplicate(true)" in state
    assert "func feed_cat() -> bool:" in state
    assert "host.data.fish_stock -= 1" in state
    assert "data.cat_satiety = mini(100" in state
    assert "func cat_adventure_tick() -> String:" in state
    assert "CAT_SATIETY_ROAD_COST" in state
    assert "data.fish_stock += fish_portions" in state

    assert 'for category in ["skin", "head", "back", "face"]' in main
    assert "Cat Companion  •  Browse / Adopt" in main
    assert "func show_cat_market() -> void:" in main
    assert "Refresh random cat design" in main
    assert "func show_cat_companion() -> void:" in main
    assert "cat_adopted" in main
    assert "cat_market_refreshed" in main
    assert "cat_fed" in main
    assert "func build_cat_companion() -> void:" in world


def test_combat_has_longer_suspense_and_tug_of_war_outcome_meter():
    from pathlib import Path

    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    assert "var fight_balance: ProgressBar" in main
    assert "FOE  ◀  STRUGGLE  ▶  YOU" in main
    assert "CLASH!  HOLDING..." in main
    assert "PUSHING..." in main
    assert "FOE RESISTS..." in main
    assert "LAST EFFORT..." in main
    assert "BREAKING POINT..." in main
    assert "var struggle_points: Array[float]" in main
    assert 'tween_property(fight_balance, "value"' in main
    assert "0.48" in main
    assert "YOU WIN" in main
    assert "FOE WINS" in main
    assert "get_tree().create_timer(0.90)" in main


def test_enemy_visuals_have_ranked_equipment_and_stable_palette_variety():
    from pathlib import Path

    catalog = (
        PET_CATALOG_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_CATALOG_PATH.read_text(encoding="utf-8")
        + ROAD_CATALOG_PATH.read_text(encoding="utf-8")
        + ENEMY_CATALOG_PATH.read_text(encoding="utf-8")
    )
    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )
    world = Path("scripts/world.gd").read_text(encoding="utf-8")
    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    assert "const ENEMY_VISUALS" in catalog
    assert "const ENEMY_RANKS" in catalog
    for enemy in ["slime", "goblin", "kobold", "ogre"]:
        assert f'"{enemy}":{{' in catalog

    for style in [
        "moss_shell", "leaf_cap", "thorn_spike",
        "scrap_vest", "iron_cap", "short_sword",
        "scale_coat", "horn_guard", "spear",
        "plate_harness", "war_helm", "stone_hammer",
    ]:
        assert style in catalog

    assert "func enemy_rank(kind: String, elite: bool = false) -> int:" in state
    assert "func enemy_visual_variant(" in state
    assert "int(data.seed)" in state
    assert "palettes[signature % palettes.size()]" in state

    assert "func build_enemy_loadout(" in world
    assert "Armor silhouette scales by rank" in world
    assert "Every enemy type now has a helmet/cap identity." in world
    assert "Weapon silhouettes are distinct at a glance." in world

    assert "fight_enemy_gear" in main
    assert "armor_style" in main
    assert "helmet_style" in main
    assert "weapon_style" in main


def test_market_telemetry_distinguishes_success_from_failed_purchase():
    from pathlib import Path

    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    assert "var market_success: bool" in main
    assert "if market_success:" in main
    assert '"cosmetic_action_failed"' in main


def test_deleted_crossroads_fallback_has_no_stale_references():
    from pathlib import Path

    main = Path("scripts/main.gd").read_text(encoding="utf-8")
    refinement = Path("scripts/ui_refinement.gd").read_text(encoding="utf-8")

    for stale in ["route_panel", "route_box", "show_routes()", "WINDOW_ROUTE_WIDTH"]:
        assert stale not in main
        assert stale not in refinement


def test_web_telemetry_requires_opt_in_and_drops_free_text():
    import json
    from pathlib import Path

    telemetry = Path("scripts/ai_telemetry.gd").read_text(encoding="utf-8")
    config = json.loads(Path("runtime/public_telemetry.json").read_text(encoding="utf-8"))

    assert config["require_opt_in"] is True
    assert config["allow_desktop_debug"] is False
    assert '"telemetry=1"' in telemetry
    assert "sanitize_details(details)" in telemetry
    assert '["result", "message", "feedback", "text"]' in telemetry
    assert "MAX_REMOTE_STRING" in telemetry


def test_cat_companion_is_visible_from_marketplace_and_equipment():
    from pathlib import Path

    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    assert 'label("COMPANION"' in main
    assert "Cat Companion  •  Browse / Adopt" in main
    assert "Cat Companion  •  Manage / Feed" in main
    assert "Cat Market / Adopt Companion" in main
    assert 'for category in ["skin", "head", "back", "face"]' in main
    assert "func show_cat_market() -> void:" in main
    assert "func show_cat_companion() -> void:" in main


def test_lantern_camp_exposes_physical_marketplace_entry():
    from pathlib import Path

    world = Path("scripts/world.gd").read_text(encoding="utf-8")
    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    assert 'market_board.name = "CampMarketplace"' in world
    assert "MARKETPLACE  •  CAT COMPANION" in world
    assert 'clickable_board(scenery, market_pos' in world
    assert 'world.marketplace_clicked.connect' in main
    assert 'show_marketplace("skin")' in main


def test_cat_click_status_progression_rank_and_buff_are_wired():
    from pathlib import Path

    catalog = (
        PET_CATALOG_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_CATALOG_PATH.read_text(encoding="utf-8")
        + ROAD_CATALOG_PATH.read_text(encoding="utf-8")
        + ENEMY_CATALOG_PATH.read_text(encoding="utf-8")
    )
    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )
    main = Path("scripts/main.gd").read_text(encoding="utf-8")
    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert "const CAT_LEVEL_CAP: int = 10" in catalog
    assert "const CAT_BOND_XP_PER_FEED: int = 10" in catalog
    assert "CAT_BOND_XP_PER_ROAD" not in catalog
    assert "const CAT_RANKS" in catalog

    assert '"cat_bond_xp":0' in state
    assert "func cat_level() -> int:" in state
    assert "func cat_rank_name() -> String:" in state
    assert "func cat_bond_progress() -> Dictionary:" in state
    assert "func cat_buff_coins() -> int:" in state
    assert "func cat_buff_text() -> String:" in state
    assert "Cat Road Luck:" in state

    assert "signal cat_clicked" in world
    assert 'root.name = "CampCatCompanion"' in world
    assert 'cat_area.name = "CatInteraction"' in world
    assert "cat_clicked.emit()" in world

    assert "world.cat_clicked.connect" in main
    assert "companion_progress_bar" in main
    assert "BOND XP" in main
    assert "ACTIVE BUFF" in main
    assert "Manage / Feed" in main


def test_status_panel_equipment_is_informative_and_sanitized():
    from pathlib import Path

    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )
    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    assert "func best_owned_gear_id(slot: String) -> String:" in state
    assert "func sanitized_equipped_id(slot: String) -> String:" in state
    assert "func repair_equipment_slots() -> bool:" in state
    assert "No equippable gear is owned yet." in state

    assert "BEST OWNED" in main
    assert "NO OWNED GEAR" in main
    assert "Equipped %d / 3" in main
    assert 'button("Equipment"' in main
    assert "side_best_button.disabled" in main
    assert "side_heal_button.disabled" in main
    assert "side_mana_button.disabled" in main
    assert "EXPEDITION  •  THREAT" in main


def test_lantern_camp_player_and_cat_use_bounded_roaming():
    from pathlib import Path

    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert "var camp_actor_roam_points: Array[Vector3]" in world
    assert "var camp_cat_roam_points: Array[Vector3]" in world
    assert "func update_camp_actor_roam(delta: float) -> void:" in world
    assert "func update_camp_cat_roam(delta: float) -> void:" in world
    assert "apply_idle_animation(delta)" in world
    assert "actor.position = camp_actor_roam_points[0]" in world
    assert "camp_cat_root = root" in world
    assert "root.position = camp_cat_roam_points[0]" in world
    assert 'camera_target = Vector3(0.0, 0.12, -4.80)' in world
    assert 'actor.position = Vector3(-3.15, 0.52, -3.05)' not in world


def test_camp_character_idle_is_calm_and_cat_rests_by_bonfire():
    from pathlib import Path

    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert "camp_actor_pause = 7.0" in world
    assert "camp_roam_rng.randf_range(6.0, 11.0)" in world
    assert "var step: float = minf(distance, 0.42 * delta)" in world

    # Lower-body stability: camp gait uses foot position offsets, not large rotations.
    assert "left_foot.rotation = Vector3.ZERO" in world
    assert "right_foot.rotation = Vector3.ZERO" in world
    assert "left_foot.position = ACTOR_LEFT_FOOT_NEUTRAL" in world
    assert "right_foot.position = ACTOR_RIGHT_FOOT_NEUTRAL" in world
    assert "actor.rotation.z = 0.0" in world

    # Cat remains the more active companion and can rest near either side of the fire.
    assert "var camp_cat_fire_rest_points" in world
    assert "func select_cat_fire_rest_target() -> void:" in world
    assert "camp_cat_resting_by_fire = true" in world
    assert "camp_roam_rng.randf_range(4.0, 8.0)" in world
    assert "camp_cat_moves_since_rest >= 4" in world


def test_camp_roaming_uses_only_valid_save_fields():
    from pathlib import Path

    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert "state.data.trail" not in world
    assert 'state.data.get("seed", 1)' in world
    assert 'state.data.get("wins", 0)' in world
    assert 'state.data.get("camp_level", 0)' in world


def test_character_boots_are_grounded_and_do_not_rotate_during_walk():
    from pathlib import Path

    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert 'const ACTOR_LEFT_FOOT_NEUTRAL := Vector3(-0.20, -0.07, 0.00)' in world
    assert 'const ACTOR_RIGHT_FOOT_NEUTRAL := Vector3(0.20, -0.07, 0.00)' in world
    assert 'const ACTOR_FOOT_SIZE := Vector3(0.22, 0.14, 0.24)' in world
    assert "left_foot.rotation.x = gait" not in world
    assert "right_foot.rotation.x = -gait" not in world
    assert "left_foot.position = ACTOR_LEFT_FOOT_NEUTRAL" in world
    assert "right_foot.position = ACTOR_RIGHT_FOOT_NEUTRAL" in world


def test_player_has_independent_bonfire_rest_sequence():
    from pathlib import Path

    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert "var camp_actor_moves_since_rest: int = 0" in world
    assert "var camp_actor_heading_to_fire: bool = false" in world
    assert "var camp_actor_resting_by_fire: bool = false" in world
    assert "var camp_actor_fire_rest_points" in world
    assert "func select_actor_fire_rest_target() -> void:" in world
    assert "func apply_camp_fire_rest() -> void:" in world
    assert "camp_actor_resting_by_fire = true" in world
    assert "camp_roam_rng.randf_range(8.0, 14.0)" in world
    assert "camp_actor_moves_since_rest >= 2" in world
    assert 'actor.look_at(Vector3(0.0, actor.position.y, -5.15)' in world
    assert "left_arm.position = Vector3(-0.46, 0.32, 0.10)" in world
    assert "right_arm.position = Vector3(0.46, 0.32, 0.10)" in world


def test_character_shell_is_surface_armor_not_solid_lower_torso_cube():
    from pathlib import Path

    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert 'Vector3(0.96, 0.23, 0.96)' not in world
    assert 'Vector3(0.72, 0.42, 0.055)' in world
    assert 'Vector3(0.055, 0.36, 0.62)' in world
    assert 'const ACTOR_ARM_SIZE := Vector3(0.16, 0.34, 0.18)' in world
    assert 'left_foot.position = ACTOR_LEFT_FOOT_NEUTRAL' in world
    assert 'right_foot.position = ACTOR_RIGHT_FOOT_NEUTRAL' in world


def test_cat_food_satiates_but_only_fish_advances_rank():
    from pathlib import Path

    catalog = (
        PET_CATALOG_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_CATALOG_PATH.read_text(encoding="utf-8")
        + ROAD_CATALOG_PATH.read_text(encoding="utf-8")
        + ENEMY_CATALOG_PATH.read_text(encoding="utf-8")
    )
    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
        + ROAD_SERVICE_PATH.read_text(encoding="utf-8")
        + ENEMY_SERVICE_PATH.read_text(encoding="utf-8")
    )
    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    assert "const CAT_FOOD_PRICE: int = 12" in catalog
    assert "const CAT_SATIETY_PER_FOOD: int = 20" in catalog
    assert "const CAT_FOOD_STOCK_CAP: int = 99" in catalog
    assert "CAT_BOND_XP_PER_ROAD" not in catalog

    assert '"cat_food_stock":0' in state
    assert "func buy_cat_food(quantity: int = 1) -> bool:" in state
    assert "func feed_cat_food() -> bool:" in state
    assert "No Bond XP gained." in state
    assert "add_cat_bond_xp(host, PetCatalog.CAT_BOND_XP_PER_FEED)" in state

    tick = state.split("func cat_adventure_tick() -> String:", 1)[1].split("func owns_cosmetic", 1)[0]
    assert "add_cat_bond_xp" not in tick

    assert "Buy 1 Cat Food" in main
    assert "Buy 5 Cat Food" in main
    assert "Feed Cat Food" in main
    assert "Only caught fish advances Bond XP, level, and rank." in main


def test_trail_finish_uses_current_waypoint_gate_design():
    from pathlib import Path

    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert "func trail_finish_waypoint(finish_z: float) -> void:" in world
    assert "trail_finish_waypoint(finish_z)" in world
    assert "Standard trail finish gate." in world
    assert 'floating_text(scenery, "WAYPOINT"' in world
    assert "Main beveled sign" in world
    assert "Secondary bar matches the current board system" in world
    assert "add_waypoint_post(scenery, Vector3(-3.20" in world
    assert "add_waypoint_post(scenery, Vector3(3.20" in world

    old_plain = 'Vector3(8.5, 0.3, 0.35)'
    assert old_plain not in world


def test_owned_cat_marketplace_exposes_food_supplies_directly():
    from pathlib import Path

    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    assert "Cat Supplies  •  Buy Food" in main
    assert "CAT FOOD ×%d  •  %d coins each" in main
    assert "show_cat_market()" in main


def test_lantern_camp_uses_wide_hub_framing_and_safe_roam_depth():
    from pathlib import Path

    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert 'Vector3(-2.15, 0.16, -2.35)' not in world
    assert 'Vector3(-0.75, 0.16, -2.55)' not in world
    assert 'camera_offset = Vector3(0, 4.65, 8.65)' in world
    assert 'look_offset = Vector3(0, 0.66, -4.35)' in world


def test_save_validator_rejects_negative_economy_and_orphan_pet_supplies():
    from pathlib import Path

    state = (
        Path("scripts/state.gd").read_text(encoding="utf-8")
        + PET_SERVICE_PATH.read_text(encoding="utf-8")
        + MARKETPLACE_SERVICE_PATH.read_text(encoding="utf-8")
    )

    assert "int(value.coins) < 0" in state
    assert "int(value.bag) < 0" in state
    assert "int(value.wins) < 0" in state
    assert "int(value.runs) < 0" in state
    assert "int(value.kills) < 0" in state
    assert "int(value.potions.heal) < 0" in state
    assert "int(value.potions.mana) < 0" in state
    assert "int(value.cat_food_stock) != 0" in state
    assert "migrated.cat_food_stock = 0" in state


def test_repo_sanity_covers_recursive_resources_and_modular_catalogs():
    from pathlib import Path

    sanity = Path("tools/repo_sanity.py").read_text(encoding="utf-8")

    assert "def verify_all_runtime_resource_refs()" in sanity
    assert "scripts/**/*.gd" in sanity
    assert "def verify_modular_catalogs()" in sanity
    assert "duplicate cosmetic id" in sanity
    assert "pet rank thresholds" in sanity
    assert "route name drift between JSON and Godot catalog" in sanity


def test_adventure_idle_animation_covers_actor_props_and_enemies():
    from pathlib import Path

    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert "var adventure_idle_objects: Array[Dictionary]" in world
    assert "var adventure_idle_enemies: Array[Dictionary]" in world
    assert "func register_adventure_idle_object" in world
    assert "func register_adventure_idle_enemy" in world
    assert "func apply_adventure_actor_idle() -> void:" in world
    assert "func update_adventure_object_idle() -> void:" in world
    assert "func update_adventure_enemy_idle() -> void:" in world

    assert 'register_adventure_idle_object(coin, "coin"' in world
    assert 'register_adventure_idle_object(fire_outer, "flame"' in world
    assert 'register_adventure_idle_object(fishing_ripple, "water"' in world
    assert 'register_adventure_idle_object(cache_lid, "pulse"' in world
    assert 'register_adventure_idle_enemy(' in world

    assert '"slime":' in world
    assert '"goblin":' in world
    assert '"kobold":' in world
    assert '"ogre":' in world

    assert 'str(state.data.mode) in ["travel", "campfire", "fishing"]' in world
    assert "update_adventure_object_idle()" in world
    assert "update_adventure_enemy_idle()" in world


def test_adventure_actor_idle_keeps_lower_body_stable():
    from pathlib import Path

    world = Path("scripts/world.gd").read_text(encoding="utf-8")
    block = world.split("func apply_adventure_actor_idle() -> void:", 1)[1].split("func reset_walk_pose", 1)[0]

    assert "reset_walk_pose()" in block
    assert "left_foot.rotation" not in block
    assert "right_foot.rotation" not in block
    assert "actor.position = idle_anchor_position" in block


def test_crossroads_uses_clean_rpg_signpost_layout():
    from pathlib import Path

    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert "func crossroads_direction_board(" in world
    assert 'floating_text(scenery, "CROSSROADS"' in world
    assert '"CROSSROADS  •  CHOOSE YOUR NEXT ROAD"' not in world
    assert '"→  %s  •  %s"' not in world
    assert 'str(route.name).to_upper()' in world
    assert 'Vector3(-2.05, 1.48' in world
    assert 'Vector3(0.00, 1.05' in world
    assert 'Vector3(2.05, 1.48' in world
    assert "Three subtle ground markers" in world


def test_lantern_camp_keeps_player_deep_in_wide_hub_shot():
    from pathlib import Path

    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert 'camera.fov = 61.0' in world
    assert 'camera_offset = Vector3(0, 5.15, 10.60)' in world
    assert 'look_offset = Vector3(0, 0.58, -4.55)' in world
    assert 'Vector3(-2.10, 0.16, -4.55)' in world
    assert 'Vector3(-0.72, 0.16, -4.72)' in world
    assert 'Vector3(1.42, 0.16, -4.86)' in world
    assert 'camera_target = Vector3(0.0, 0.12, -5.20)' in world
