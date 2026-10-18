extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene = load("res://scenes/prototype.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://location_preview.png")
	var camera: Camera2D = scene.player.get_node("Camera2D")
	camera.position_smoothing_enabled = false
	camera.global_position = Vector2(996, 739)
	camera.zoom = Vector2(0.32, 0.32)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://large_board_overview.png")
	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE
	scene.power_repaired = true
	scene.data_collected = true
	scene.terminal_repaired = true
	scene.return_home()
	scene.return_home()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://location_ending_preview.png")
	scene.free()
	quit()
