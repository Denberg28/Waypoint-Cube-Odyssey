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

	if world.actor.position.y > 0.30:
		_fail("Lantern Camp actor is still positioned above bench height", 7)
		return
	var actor_start: Vector3 = world.actor.position
	var cat_root = world.scenery.get_node_or_null("CampCatCompanion")
	var cat_start: Vector3 = cat_root.position if is_instance_valid(cat_root) else Vector3.ZERO
	# The player should idle much more than the cat. Over the first 3 seconds,
	# the cat may move while the player should still be in the long rest window.
	for _i in range(180):
		world._process(1.0 / 60.0)
	if world.actor.position.distance_to(actor_start) > 0.08:
		_fail("Lantern Camp actor is too active during intended idle window", 8)
		return
	if is_instance_valid(cat_root) and cat_root.position.distance_to(cat_start) < 0.10:
		_fail("Lantern Camp cat did not roam from spawn", 9)
		return

	# Advance enough time for the player's occasional walk and at least one cat
	# bonfire rest opportunity.
	var actor_before_long: Vector3 = world.actor.position
	var cat_saw_fire_rest: bool = false
	for _i in range(1200):
		world._process(1.0 / 60.0)
		if bool(world.camp_cat_resting_by_fire):
			cat_saw_fire_rest = true
	if world.actor.position.distance_to(actor_before_long) < 0.10:
		_fail("Lantern Camp actor never performed an occasional reposition", 10)
		return
	if is_instance_valid(cat_root) and not cat_saw_fire_rest:
		_fail("Lantern Camp cat never entered bonfire rest state", 11)
		return

	print("CROSSROADS_SMOKE_OK scenery_children=", scene_children, " camp_marketplace=present calm_actor=verified cat_fire_rest=verified camera=", world.camera.position)
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
