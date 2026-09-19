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
	scene.call("show_cat_companion")
	if not bool(overlay.visible):
		_fail("cat companion modal did not render", 11)
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
