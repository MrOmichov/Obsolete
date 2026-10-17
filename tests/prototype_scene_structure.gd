extends SceneTree
## Verify the editor gets a complete level without running any gameplay scripts.

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/prototype.tscn").instantiate()
	var before = scene.find_children("*", "", true, false).size()
	_check(before > 100, "level nodes exist before _ready")
	for path in ["Board/Floor", "Board/Walls/Gate/CollisionShape2D", "Board/Home/SafeZone",
		"Board/Archive/DataPickup", "Actors/Player/Visual", "Actors/Resistor/Visual",
		"Actors/Diode/Visual", "Actors/Microchip/Visual", "Actors/PowerSupply/Sprite",
		"Actors/CoolingTerminal/Sprite", "HUD/Dialogue/Text", "HUD/Restart", "Threat/Trace"]:
		_check(scene.has_node(path), "saved node: " + path)
	for actor in ["Player", "Resistor", "Diode", "Microchip"]:
		var visual: AnimatedSprite2D = scene.get_node("Actors/" + actor + "/Visual")
		_check(visual.sprite_frames != null and visual.sprite_frames.get_frame_count("idle") == 6,
			actor + " has editor-visible animation frames")
	for actor in ["Resistor", "Diode", "Microchip"]:
		_check(scene.get_node("Actors/" + actor).is_in_group("prototype_npcs"), actor + " group is saved")
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	_check(scene.find_children("*", "", true, false).size() == before + 2,
		"ready adds only two repair timers, with no duplicate level or HUD")
	# Moving editor markers must update their gameplay zones, not just the drawing.
	var home: Marker2D = scene.get_node("Board/Home")
	home.position += Vector2(100, 0)
	scene.player.global_position = home.global_position
	scene.threat_active = true
	scene.threat_grace = 0
	scene.hit_cooldown = 0
	scene.threat_position = home.global_position
	scene._update_threat(0)
	_check(scene.hit_cooldown == 0, "safe zone follows the editable home marker")
	var archive: Marker2D = scene.get_node("Board/Archive")
	archive.position += Vector2(0, 80)
	scene.player.global_position = archive.global_position
	scene._update_prompt()
	_check(scene.get_node("HUD/PromptPanel/Text").text == "E — прочитать ночной архив",
		"archive interaction follows the editable marker")
	if failures == 0:
		print("Editable scene structure passed")
	quit(0 if failures == 0 else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
