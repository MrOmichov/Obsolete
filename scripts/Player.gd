extends CharacterBody2D

@export var speed: float = 200.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0

@onready var camera: Camera2D = $Camera2D
@onready var visual: AnimatedSprite2D = get_node_or_null("Visual") as AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	if visual:
		visual.sprite_frames = _load_sprite_frames("res://assets/characters/player")
		visual.play("idle")

func _physics_process(delta: float) -> void:
	var prototype := get_tree().get_first_node_in_group("prototype")
	if prototype and (prototype.completed or prototype.is_dialogue_open()):
		velocity = Vector2.ZERO
		if visual and visual.animation != "interact":
			visual.play("interact")
		move_and_slide()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	if visual:
		if input_dir.x != 0.0:
			visual.flip_h = input_dir.x < 0.0
		var target_animation := "run" if input_dir != Vector2.ZERO else "idle"
		if visual.animation != target_animation:
			visual.play(target_animation)

	move_and_slide()

func _load_sprite_frames(character_folder: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	for animation_name in ["idle", "run", "interact"]:
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, 8.0)
		frames.set_animation_loop(animation_name, animation_name != "interact")
		for frame_number in range(1, 7):
			var frame_path := "%s/%s/frame_%02d.png" % [character_folder, animation_name, frame_number]
			var frame := load(frame_path) as Texture2D
			if frame:
				frames.add_frame(animation_name, frame)
	return frames
