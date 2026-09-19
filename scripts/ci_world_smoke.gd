extends SceneTree

const State = preload("res://scripts/state.gd")
const World = preload("res://scripts/world.gd")

var finished: bool = false

func _init() -> void:
	# Watchdog is armed before touching World. If a GDScript runtime error aborts
	# the smoke body before quit(), the SceneTree still exits non-zero instead of
	# hanging the GitHub runner indefinitely.
	create_timer(8.0).timeout.connect(_watchdog_timeout)
	call_deferred("_run_smoke")

func _run_smoke() -> void:
	var game = State.new()
	game.data.mode = "choice"
	game.data.class_id = "merchant"
	game.data.route = "moss"
	game.data.stage = 0
	game.data.row = 0
	game.data.lane = 0

	var world = World.new()
	root.add_child(world)
	world.setup(game)

	if not is_instance_valid(world.scenery):
		_fail("scenery was not created", 2)
		return
	var scene_children: int = world.scenery.get_child_count()
	if scene_children < 20:
		_fail("expected populated scenery, got %d children" % scene_children, 3)
		return
	if not is_instance_valid(world.camera):
		_fail("camera missing", 4)
		return

	finished = true
	# Rebuild as Lantern Camp and ensure persistent hub services are physically
	# reachable from the 3D world, not only from menu code.
	game.data.mode = "camp"
	world.build()
	var market_board = world.scenery.get_node_or_null("CampMarketplace")
	var continue_board = world.scenery.get_node_or_null("CampContinueAdventure")
	if not is_instance_valid(market_board):
		_fail("Lantern Camp marketplace board missing", 5)
		return
	if not is_instance_valid(continue_board):
		_fail("Lantern Camp continue board missing", 6)
		return

	print("CROSSROADS_SMOKE_OK scenery_children=", scene_children, " camp_marketplace=present camera=", world.camera.position)
	quit(0)

func _fail(message: String, code: int) -> void:
	finished = true
	push_error("CROSSROADS_SMOKE: " + message)
	quit(code)

func _watchdog_timeout() -> void:
	if finished:
		return
	push_error("CROSSROADS_SMOKE_TIMEOUT: world build did not complete in 8 seconds; inspect the runtime error immediately above this line.")
	quit(9)
