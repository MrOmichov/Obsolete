extends SceneTree

const PROTOTYPE_PATH := "res://scenes/prototype.tscn"

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(PROTOTYPE_PATH) as PackedScene
	_check(packed != null, "prototype scene loads")
	if packed == null:
		quit(1)
		return

	var game: Node = packed.instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame

	var music := game.get_node("Music") as AudioStreamPlayer
	_check(music.stream is AudioStreamMP3 and music.playing, "location soundtrack starts")
	_check(music.stream.loop, "soundtrack loops")
	await _tap_key(KEY_M)
	_check(music.stream_paused, "M mutes music")
	await _tap_key(KEY_M)
	_check(not music.stream_paused, "M resumes music")
	var cycle: Node = game.get_node("DayNightManager")
	var player: CharacterBody2D = game.get("player")
	_check(cycle.get("current_phase") == Global.Phase.DAWN, "run starts at dawn")
	_check(player != null, "player is built")
	if player == null:
		quit(1)
		return

	var visual := player.get_node("Visual") as AnimatedSprite2D
	_check(visual != null and visual.animation == "idle", "player idle animation is loaded")
	var start_position := player.position
	Input.action_press("move_right")
	await create_timer(0.25).timeout
	Input.action_release("move_right")
	_check(player.position.x > start_position.x, "player moves from input")
	_check(visual.animation == "run", "movement switches to run animation")

	var npcs: Array = game.get_tree().get_nodes_in_group("prototype_npcs")
	var mentor: Node = null
	for npc in npcs:
		if npc.get("npc_id") == &"resistor":
			mentor = npc
	_check(mentor != null, "resistor NPC is present")
	if mentor == null:
		quit(1)
		return

	player.position = mentor.global_position + Vector2(0, 90)
	player.velocity = Vector2.ZERO
	await create_timer(0.1).timeout
	_check(mentor.get("player_in_range"), "player enters the mentor interaction zone")
	await _tap_key(KEY_E)
	_check(game.get("parts") == 1, "first mentor interaction grants one part")
	_check(game.call("is_dialogue_open"), "mentor interaction opens dialogue")
	_check(cycle.call("is_dialogue_paused"), "dialogue pauses the phase timer")
	var paused_seconds: float = cycle.get("remaining_seconds")
	await create_timer(0.1).timeout
	_check(is_equal_approx(cycle.get("remaining_seconds"), paused_seconds), "phase timer stays paused during dialogue")
	await _tap_key(KEY_E)
	await _tap_key(KEY_E)
	_check(not game.call("is_dialogue_open"), "dialogue closes after its lines")
	_check(game.get("parts") == 1, "repeat interaction does not grant another part")
	_check(not cycle.call("is_dialogue_paused"), "closing dialogue resumes the phase timer")

	var terminal: StaticBody2D = game.get("terminal_object")
	var power: StaticBody2D = game.get("power_object")
	_check(not game.call("try_repair", terminal), "terminal repair is rejected before archive data")
	_check(game.get("parts") == 1, "rejected terminal repair does not consume a part")
	player.position = Vector2(1445, 863)
	player.velocity = Vector2.ZERO
	await create_timer(0.1).timeout
	Input.action_press("move_right")
	await create_timer(0.65).timeout
	Input.action_release("move_right")
	_check(player.position.x < 1490, "closed gate collision blocks horizontal movement")

	player.position = power.global_position + Vector2(0, 90)
	player.velocity = Vector2.ZERO
	await create_timer(0.1).timeout
	_check(power.get("player_in_range"), "player enters the power repair zone")
	await _tap_key(KEY_E)
	await process_frame
	_check(game.get("power_repaired"), "power repair flag is set")
	_check(game.get("parts") == 0, "power repair consumes the part")
	_check(game.get("gate_shape").disabled, "power repair opens the gate collision")
	_check(not game.call("collect_data"), "archive data is unavailable outside night")
	player.position = Vector2(1445, 863)
	player.velocity = Vector2.ZERO
	await create_timer(0.1).timeout
	Input.action_press("move_right")
	await create_timer(0.65).timeout
	Input.action_release("move_right")
	_check(player.position.x > 1515, "open gate allows horizontal movement through the passage")

	cycle.call("_enter_phase", Global.Phase.DAY)
	cycle.call("_enter_phase", Global.Phase.NIGHT)
	await process_frame
	await process_frame
	var npc_shape := mentor.get_node("CollisionShape2D") as CollisionShape2D
	var npc_zone := mentor.get_node("InteractionZone") as Area2D
	_check(npc_shape.disabled, "NPC collision is disabled at night")
	_check(not npc_zone.monitoring, "NPC interaction zone is disabled at night")
	await create_timer(1.1).timeout
	_check(not mentor.visible, "daytime NPC fades out at night")
	_check(game.call("collect_data"), "archive data can be collected at night after power repair")
	_check(game.get("data_collected"), "data collection flag is set")
	_check(game.get("parts") == 1, "archive grants the second repair part")
	_check(terminal.call("repair"), "terminal repair succeeds after data collection")
	_check(game.get("terminal_repaired"), "terminal repair flag is set")
	_check(game.get("parts") == 0, "terminal repair consumes the second part")

	player.position = Vector2(1050, 420)
	player.velocity = Vector2.ZERO
	game.set("threat_grace", 0.0)
	game.set("hit_cooldown", 0.0)
	game.set("threat_position", player.position)
	await create_timer(0.1).timeout
	_check(player.position == Vector2(270, 690), "a threat hit returns the player to HOME")
	var safe_position := Vector2(310, 690)
	player.position = safe_position
	player.velocity = Vector2.ZERO
	game.set("threat_grace", 0.0)
	game.set("hit_cooldown", 0.0)
	game.set("threat_position", safe_position)
	await create_timer(0.1).timeout
	_check(player.position == safe_position, "the HOME safe zone prevents a threat catch")

	player.position = Vector2(270, 690)
	_check(game.call("return_home"), "home accepts a player after terminal repair")
	_check(game.get("home_reached"), "home visit is recorded")
	_check(game.call("return_home"), "second home interaction rests until dawn")
	_check(cycle.get("current_phase") == Global.Phase.DAWN, "rest reaches dawn")
	_check(game.get_node("HUD/Ending").visible, "chapter ending is shown")
	_check(cycle.call("is_dialogue_paused"), "ending freezes the phase clock")
	_check(game.get("completed"), "returning home through dawn completes the run")
	await process_frame
	await create_timer(0.1).timeout
	_check(mentor.visible, "NPC returns at dawn")
	_check(not mentor.get_node("CollisionShape2D").disabled, "NPC collision returns at dawn")
	_check(mentor.get_node("InteractionZone").monitoring, "NPC interaction zone returns at dawn")

	game.call("restart_run")
	await process_frame
	await process_frame
	game = current_scene
	_check(game != null, "restart reloads the prototype scene")
	if game != null:
		_check(game.get("parts") == 0, "restart clears the part count")
		_check(not game.get("power_repaired"), "restart clears power repair")
		_check(not game.get("data_collected"), "restart clears archive data")
		_check(not game.get("terminal_repaired"), "restart clears terminal repair")
		_check(not game.get("completed"), "restart clears completion state")
		_check(game.get_node("DayNightManager").get("current_phase") == Global.Phase.DAWN, "restart resets the phase to dawn")

	await process_frame
	await process_frame
	current_scene.free()
	await process_frame
	await create_timer(0.15).timeout
	if failures == 0:
		print("Prototype smoke passed")
		quit(0)
	else:
		push_error("Prototype smoke failed with %d assertion(s)" % failures)
		quit(1)


func _check(condition: bool, description: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: " + description)


func _tap_key(keycode: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.physical_keycode = keycode
	pressed.pressed = true
	Input.parse_input_event(pressed)
	var released := InputEventKey.new()
	released.physical_keycode = keycode
	released.pressed = false
	Input.parse_input_event(released)
	await process_frame
	await process_frame
