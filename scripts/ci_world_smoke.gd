extends SceneTree

const State = preload("res://scripts/state.gd")
const World = preload("res://scripts/world.gd")

func _init() -> void:
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
		push_error("CROSSROADS_SMOKE: scenery was not created")
		quit(2)
		return
	var scene_children: int = world.scenery.get_child_count()
	if scene_children < 20:
		push_error("CROSSROADS_SMOKE: expected populated scenery, got %d children" % scene_children)
		quit(3)
		return
	if not is_instance_valid(world.camera):
		push_error("CROSSROADS_SMOKE: camera missing")
		quit(4)
		return

	print("CROSSROADS_SMOKE_OK scenery_children=", scene_children, " camera=", world.camera.position)
	quit(0)
