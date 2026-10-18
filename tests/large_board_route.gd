extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/prototype.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await physics_frame
	game.cycle.set_dialogue_paused(true)
	game.player.set_physics_process(false)
	game._on_power_repaired()
	await process_frame
	await physics_frame
	var destinations: Array[Vector2] = [game.archive.global_position, game.terminal_object.global_position, game.home.global_position]
	for destination in destinations:
		var steps := 0
		while game.player.global_position.distance_to(destination) > 90 and steps < 3000:
			var next: Vector2 = game._route_target(destination)
			var motion: Vector2 = game.player.global_position.direction_to(next) * 8.0
			game.player.move_and_collide(motion)
			steps += 1
		if steps >= 3000:
			push_error("Route blocked at %s en route to %s" % [game.player.global_position, destination])
			quit(1)
			return
	print("Full board route passed: home -> east archive -> west terminal -> home")
	game.free()
	await create_timer(0.15).timeout
	quit()
