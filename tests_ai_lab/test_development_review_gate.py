from __future__ import annotations

from ai_lab.development_review import recommendation_similarity, update_recommendation_tally
from streamlit_lab.review_gate import pin_matches


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
    from pathlib import Path

    catalog = Path("scripts/catalog.gd").read_text(encoding="utf-8")
    state = Path("scripts/state.gd").read_text(encoding="utf-8")
    world = Path("scripts/world.gd").read_text(encoding="utf-8")

    assert "const ELITE_BEHAVIORS" in catalog
    for profile in ["ambusher", "skirmisher", "bulwark", "crusher"]:
        assert f'"id":"{profile}"' in catalog
    assert "if danger_level() < 3" in state
    assert "func elite_behavior" in state
    assert "place_elite_encounter" in state
    assert '"elite_behavior":elite_behavior_id' in Path("scripts/main.gd").read_text(encoding="utf-8")
    assert 'telegraph = "%s  •  ELITE"' in world


def test_level_star_progression_and_rpg_encounter_sequence_present():
    from pathlib import Path

    state = Path("scripts/state.gd").read_text(encoding="utf-8")
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
    assert 'fight_status.text = "CLASH!"' in main
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

    state = Path("scripts/state.gd").read_text(encoding="utf-8")

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
    assert 'compact_best = button("Best"' in main
    assert 'compact_heal = button("Heal"' in main
    assert 'compact_mana = button("Mana"' in main
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

    state = Path("scripts/state.gd").read_text(encoding="utf-8")
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

    state = Path("scripts/state.gd").read_text(encoding="utf-8")
    main = Path("scripts/main.gd").read_text(encoding="utf-8")

    prepare = state.split("func prepare_new_expedition() -> void:", 1)[1].split("func begin(class_id: String = \"\") -> void:", 1)[0]
    leave = state.split("func leave_camp_for_crossroads() -> void:", 1)[1].split("func equip(id: String) -> void:", 1)[0]
    revive = state.split("func revive_at_camp() -> bool:", 1)[1].split("func leave_camp_for_crossroads() -> void:", 1)[0]

    # Expedition turnover resets route state but never HP/mana.
    assert "data.hp" not in prepare
    assert "data.mana" not in prepare
    assert "prepare_new_expedition()" in leave
    # Match executable calls only; comments may legitimately mention begin().
    assert re.search(r"^\\s*begin\\(", leave, re.MULTILINE) is None

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
    assert "func apply_idle_animation() -> void:" in world
    assert 'str(state.data.mode) != "camp"' in world
    assert "apply_camp_idle()" in world
    assert "actor.position = idle_anchor_position" in world
    assert "left_arm.rotation.x" in world
    assert "right_arm.rotation.x" in world
    assert "left_foot.rotation.x" in world
    assert "right_foot.rotation.x" in world
    assert 'elif not hopping and str(state.data.mode) == "camp":' in world
    assert "apply_idle_animation()" in world


def test_new_save_starts_with_zero_stars_and_zero_xp():
    from pathlib import Path

    state = Path("scripts/state.gd").read_text(encoding="utf-8")
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

    state = Path("scripts/state.gd").read_text(encoding="utf-8")
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

    catalog = Path("scripts/catalog.gd").read_text(encoding="utf-8")
    state = Path("scripts/state.gd").read_text(encoding="utf-8")

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

    state = Path("scripts/state.gd").read_text(encoding="utf-8")
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
    assert '"version":12' in state


def test_v11_pending_xp_is_migrated_into_credited_xp():
    from pathlib import Path

    state = Path("scripts/state.gd").read_text(encoding="utf-8")

    assert 'migrated.has("pending_xp")' in state
    assert 'migrated.erase("pending_xp")' in state
    assert "carry_xp" in state
    assert "migrated.resolve = 0" in state
    assert "migrated.version = 12" in state
    assert "11, 11.0" in state
