extends SceneTree
const State = preload("res://scripts/state.gd")
const Catalog = preload("res://scripts/catalog.gd")
var failures: int = 0
var checks: int = 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + text)
func _initialize() -> void:
	call_deferred("run")
func buttons(main) -> Array:
	return main.stack.get_children().filter(func(n): return n is Button)
func run() -> void:
	for id in Catalog.CLASS_IDS:
		var s = State.new()
		s.begin(id)
		check(s.data.class_id == id, "class assigned")
		check(s.max_hp() == int(Catalog.CLASSES[id].hp), "class health")
		check(s.attack() == int(Catalog.CLASSES[id].attack), "class attack")
		check(s.data.hp == s.max_hp(), "new class starts at full health")
		check(s.stat("coins") == int(Catalog.CLASSES[id].coins), "coin bonus")
		check(s.enemy_damage(2) == (1 if id == "knight" else 2), "armor")
		s.make_room("moss")
		s.data.cells = [{"row":1,"lane":0,"kind":"coin","cleared":false}]
		s.hop(0)
		check(s.data.bag == (4 if id == "merchant" else 2), "coin perk applied")
		check(s.data.popup.is_empty(), "pickup does not create blocking popup")
		s.data.hp = 2
		s.finish_room()
		check(s.data.hp == (3 if id == "adventurer" else 2), "trail healing perk applied")
	check(int(Catalog.CLASSES.merchant.trade_cost) == 12, "merchant trade discount")
	# Upgrade an authentic v1-shaped save without losing existing progress.
	var old = State.new()
	old.save_path = "user://waypoint_UPDATE_MIGRATION.json"
	old.begin()
	old.make_room("forge")
	old.data.version = 1
	old.data.erase("class_id")
	old.data.erase("popup")
	old.data.coins = 67
	old.data.inventory = ["ember", "stone"]
	old.data.equipped.core = "ember"
	old.data.row = 2
	var file = FileAccess.open(old.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old.data))
	file.close()
	var migrated = State.new()
	migrated.save_path = old.save_path
	check(migrated.load_game(), "legacy save loads")
	check(int(migrated.data.version) == 9 and migrated.data.class_id == "adventurer", "legacy migration assigns default class")
	check(int(migrated.data.row) == 2 and int(migrated.data.coins) == 67 and migrated.data.equipped.core == "ember", "legacy progress preserved")
	check(migrated.data.cells == JSON.parse_string(JSON.stringify(old.data.cells)), "legacy room preserved")
	var bad: Dictionary = migrated.data.duplicate(true)
	bad.class_id = "invalid"
	check(not migrated.valid_save(bad), "reject unknown class")
	bad = migrated.data.duplicate(true)
	bad.popup = {"tag":5}
	check(not migrated.valid_save(bad), "reject malformed popup")
	# Real menu and animation flow.
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.game.save_path = "user://waypoint_UPDATE_SCENE.json"
	main.settings_path = "user://waypoint_UPDATE_SETTINGS.cfg"
	main.game.reset()
	main.has_save = false
	main.show_title()
	check(main.at_title and main.overlay.visible, "opens on title")
	check(buttons(main)[1].disabled, "continue disabled without save")
	var unchanged: String = JSON.stringify(main.game.data)
	main.show_selector()
	check(main.spinning, "selector animates")
	await create_timer(2.2).timeout
	check(not main.spinning and main.selected_class in Catalog.CLASS_IDS, "selector finishes on valid class")
	check(JSON.stringify(main.game.data) == unchanged, "preview leaves save unchanged")
	check(not buttons(main)[0].disabled, "confirm enabled after spin")
	main.show_title()
	check(JSON.stringify(main.game.data) == unchanged, "cancel selector leaves save unchanged")
	main.show_selector()
	await create_timer(2.2).timeout
	main.selected_class = "magician"
	main.confirm_character()
	check(not main.at_title and main.game.data.mode == "choice", "confirmation starts game")
	check(main.has_save and main.game.data.class_id == "magician" and main.game.data.hp == 5, "confirmed class saved")
	main.set_side_panel_minimized(true)
	check(main.side_panel_minimized and main.side_compact_body.visible and not main.side_full_body.visible, "status rail minimizes to compact quick actions")
	check(main.compact_message.text != "", "compact status shows latest message")
	main.set_side_panel_minimized(false)
	check(not main.side_panel_minimized and main.side_full_body.visible and not main.side_compact_body.visible, "status rail expands to full details")
	main.game.make_room("moss")
	main.game.cell_at(1, 0).kind = "coin"
	main.commit()
	main.do_hop(0)
	await create_timer(0.6).timeout
	check(not main.overlay.visible and main.game.data.popup.is_empty(), "coin arrival stays in live gameplay")
	var bag: int = int(main.game.data.bag)
	check(main.event_history.size() > 0, "pickup result enters message feed")
	var resumed = State.new()
	resumed.save_path = main.game.save_path
	check(resumed.load_game(), "live-state save reloads")
	check(int(resumed.data.bag) == bag, "reward saved once")
	main.game.cell_at(2, 0).kind = "slime"
	var turn: int = int(main.game.data.turn)
	main.do_hop(0)
	await create_timer(1.3).timeout
	check(int(main.game.data.row) == 2 and int(main.game.data.turn) == turn + 1, "enemy encounter resolves without preview pause")
	check(not main.overlay.visible and main.game.data.popup.is_empty() and not main.fight_layer.visible, "enemy fight animation resolves back to live play")
	check(main.world.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "perspective camera")
	var forward: Vector3 = -main.world.camera.global_transform.basis.z
	check(absf(forward.x) < 0.001 and forward.z < -0.8, "camera faces forward without sideways yaw")
	check(main.world.camera.position.z > main.world.actor.position.z, "camera behind cube")
	main.show_settings()
	var before: bool = main.muted
	buttons(main)[0].pressed.emit()
	var settings = ConfigFile.new()
	check(settings.load(main.settings_path) == OK and bool(settings.get_value("audio", "muted")) != before, "settings persist")
	for base in [old.save_path, main.game.save_path, main.settings_path]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(base + suffix):
				DirAccess.remove_absolute(base + suffix)
	main.queue_free()
	await process_frame
	print("UPDATE TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
