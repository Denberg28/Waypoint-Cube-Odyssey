extends SceneTree

var finished: bool = false

func _init() -> void:
	create_timer(12.0).timeout.connect(_watchdog_timeout)
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	if packed == null:
		_fail("main.tscn failed to load", 2)
		return
	var scene = packed.instantiate()
	if scene == null:
		_fail("main scene failed to instantiate", 3)
		return
	root.add_child(scene)
	await process_frame
	await process_frame
	if not is_instance_valid(scene):
		_fail("main scene was freed during startup", 4)
		return
	var director = root.get_node_or_null("MusicDirector")
	if not is_instance_valid(director):
		_fail("MusicDirector autoload missing", 16)
		return
	var danger_music: Dictionary = director.call("context_config", "road_danger")
	if danger_music.is_empty() or not danger_music.has("tempo_scale"):
		_fail("MusicDirector Audio Profile v2 road_danger config missing", 17)
		return

	var ui = scene.get("ui")
	var world = scene.get("world")
	if not is_instance_valid(ui):
		_fail("main UI was not created", 5)
		return
	if not is_instance_valid(world):
		_fail("world was not created", 6)
		return

	# Exercise recently changed UI paths, not only construction.
	var game = scene.get("game")
	if game == null:
		_fail("game state object missing", 7)
		return
	scene.set("at_title", false)
	game.data.mode = "choice"
	scene.call("show_mode")
	scene.call("preview_route", "moss")
	var overlay = scene.get("overlay")
	var stack = scene.get("stack")
	if not is_instance_valid(overlay) or not bool(overlay.visible) or not is_instance_valid(stack):
		_fail("route preview modal did not render", 8)
		return

	game.data.mode = "camp"
	game.data.coins = 999
	scene.call("show_cat_market")
	if not bool(overlay.visible):
		_fail("cat marketplace modal did not render", 9)
		return
	if not game.adopt_cat():
		_fail("cat adoption failed during UI smoke", 10)
		return
	world.build()
	overlay.hide()
	world.cat_clicked.emit()
	await process_frame
	if not bool(overlay.visible):
		_fail("clicking the camp cat did not open companion status", 11)
		return
	var status_text: String = ""
	for child in stack.get_children():
		if child is Label:
			status_text += " " + str(child.text)
	if "BOND XP" not in status_text or "ACTIVE BUFF" not in status_text:
		_fail("cat status panel missing Bond XP or buff status", 12)
		return

	# Status rail must remain informative even when owned gear exists but the
	# explicit equipped mapping starts empty.
	game.data.mode = "camp"
	game.data.inventory = ["ember", "bark", "clover"]
	game.data.equipped = {"core":"", "shell":"", "charm":""}
	scene.call("update_hud")
	var side_equipment = scene.get("side_equipment")
	if not is_instance_valid(side_equipment):
		_fail("side equipment label missing", 13)
		return
	var equipment_text: String = str(side_equipment.text)
	if "BEST OWNED" not in equipment_text or "Ember core" not in equipment_text or "Bark shell" not in equipment_text or "Clover charm" not in equipment_text:
		_fail("status panel did not expose best-owned equipment fallback", 14)
		return
	scene.call("equip_best_quick")
	if game.sanitized_equipped_id("core") == "" or game.sanitized_equipped_id("shell") == "" or game.sanitized_equipped_id("charm") == "":
		_fail("status Equip Best did not fill all owned equipment slots", 15)
		return

	var fight_layer = scene.get("fight_layer")
	var fight_balance = scene.get("fight_balance")
	var fight_enemy_gear = scene.get("fight_enemy_gear")
	if not is_instance_valid(fight_layer) or not is_instance_valid(fight_balance) or not is_instance_valid(fight_enemy_gear):
		_fail("combat presentation controls missing", 12)
		return

	finished = true
	print("MAIN_SCENE_SMOKE_OK children=", scene.get_child_count(), " critical_ui=route+cat+combat")
	quit(0)

func _fail(message: String, code: int) -> void:
	finished = true
	push_error("MAIN_SCENE_SMOKE: " + message)
	quit(code)

func _watchdog_timeout() -> void:
	if finished:
		return
	push_error("MAIN_SCENE_SMOKE_TIMEOUT: startup did not complete in 12 seconds.")
	quit(9)
