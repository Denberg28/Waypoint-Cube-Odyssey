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
	finished = true
	print("MAIN_SCENE_SMOKE_OK children=", scene.get_child_count())
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
