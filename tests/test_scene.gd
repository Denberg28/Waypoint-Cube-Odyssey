extends SceneTree
## Engine integration: every screen, movement animation, and resume rendering.
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	# Never write or alter the player's normal save during tests.
	main.game.save_path = "user://waypoint_SCENE_TEST_ONLY.json"
	main.game.reset()
	main.enter_game()
	for mode in ["camp", "choice", "reward", "shrine", "traveler", "rest", "boss_intro", "victory", "defeat"]:
		main.game.data.mode = mode
		main.commit()
		await process_frame
		if not main.overlay.visible or main.stack.get_child_count() < 3:
			failures += 1
	main.game.return_camp()
	main.show_inventory()
	main.show_help()
	main.show_pause()
	main.game.begin()
	main.game.make_room("forge")
	main.commit()
	await process_frame
	main.do_hop(0, true)
	await create_timer(1.3).timeout
	if main.busy or int(main.game.data.row) != 1:
		failures += 1
	main.game.data.popup = {}
	main.game.start_boss()
	main.commit()
	main.do_hop(-1)
	await create_timer(0.6).timeout
	if main.busy or int(main.game.data.boss_hp) != 11:
		failures += 1
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(main.game.save_path + suffix):
			DirAccess.remove_absolute(main.game.save_path + suffix)
	print("SCENE TESTS: all screens + trail hop + boss hop; %d failures" % failures)
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)
