extends SceneTree
## Developer visual check. Saves PNG files only when an actual renderer exists.
func _initialize() -> void:
	call_deferred("run")
func shot(name: String) -> void:
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + name + ".png")
func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.game.save_path = "user://waypoint_PREVIEW_ONLY.json"
	main.game.reset()
	main.show_title()
	await shot("01-title")
	main.enter_game()
	main.commit()
	await shot("01-camp")
	main.game.begin()
	main.game.rng.seed = 29
	main.game.make_room("moss")
	main.commit()
	await shot("02-forest")
	main.game.start_boss()
	main.commit()
	await shot("03-guardian")
	main.game.return_camp()
	main.game.data.inventory = ["moss", "ember", "stone"]
	main.show_inventory()
	await shot("04-equipment")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(main.game.save_path + suffix):
			DirAccess.remove_absolute(main.game.save_path + suffix)
	quit()
