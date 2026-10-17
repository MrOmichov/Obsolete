extends SceneTree
## Capture the actual rendered scene, then exit without leaving a game running.

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene = load("res://scenes/prototype.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://prototype_preview.png")
	var mentor = get_first_node_in_group("prototype_npcs")
	scene.interact_npc(mentor)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://prototype_dialogue_preview.png")
	scene.end_dialogue()
	scene.get_node("DayNightManager")._enter_phase(Global.Phase.NIGHT)
	await create_timer(1.1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://prototype_night_preview.png")
	quit()
