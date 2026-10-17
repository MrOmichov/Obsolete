extends StaticBody2D

@export var dialogue: Array[String] = [
	"Привет, путник!",
	"Осторожнее в лесу, там неспокойно.",
	"Удачи тебе!"
]
@export var only_during_day: bool = true   # true: днём есть, ночью пропадает; false: наоборот
@export var fade_time: float = 1.0         # длительность плавного исчезновения
@export var npc_id: StringName = &"resistor"
@export var display_name: String = "Резистор"
@export_dir var asset_folder: String = "res://assets/characters/npc/resistor"
@export var gives_part: bool = true

@onready var hint: Label = $Hint
@onready var zone: Area2D = $InteractionZone
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: AnimatedSprite2D = $Visual

var fade_tween: Tween


var player_in_range := false
var is_talking := false
var line_index := 0
var _day_night: Node

func _on_phase_changed(_previous_phase: int, current_phase: int) -> void:
	var is_day := current_phase != Global.Phase.NIGHT
	_set_present(is_day == only_during_day, true)

func _set_present(present: bool, animate: bool) -> void:
	if not present:
		# закрываем диалог и подсказку, пока NPC ещё "существует"
		_end_dialogue()
		player_in_range = false
		hint.hide()

	# отключаем физику и зону взаимодействия
	body_shape.set_deferred("disabled", not present)
	zone.set_deferred("monitoring", present)

	if fade_tween:
		fade_tween.kill()

	if present:
		visible = true

	var target_alpha := 1.0 if present else 0.0

	if animate:
		fade_tween = create_tween()
		fade_tween.tween_property(self, "modulate:a", target_alpha, fade_time)
		if not present:
			fade_tween.tween_callback(func(): visible = false)
	else:
		modulate.a = target_alpha
		visible = present
		
func _ready() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var event := InputEventKey.new()
		event.physical_keycode = KEY_E
		InputMap.action_add_event("interact", event)

	hint.hide()
	visual.sprite_frames = _load_sprite_frames(asset_folder)
	visual.play("idle")
	visual.animation_finished.connect(_on_visual_animation_finished)

	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)
	_day_night = get_tree().get_first_node_in_group("day_night")
	if _day_night:
		_day_night.connect("phase_changed", Callable(self, "_on_phase_changed"))
		await get_tree().process_frame
		var is_day: bool = int(_day_night.get("current_phase")) != Global.Phase.NIGHT
		_set_present(is_day == only_during_day, false)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		hint.show()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		hint.hide()
		_end_dialogue()  # если игрок ушёл, закрываем диалог

func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if is_talking:
			_next_line()
		else:
			_start_dialogue()

func _start_dialogue() -> void:
	if dialogue.is_empty():
		return
	is_talking = true
	hint.hide()
	visual.play("interact")
	var prototype := get_tree().get_first_node_in_group("prototype")
	if prototype:
		prototype.call("interact_npc", self)

func _next_line() -> void:
	var prototype := get_tree().get_first_node_in_group("prototype")
	if prototype:
		prototype.call("interact_npc", self)

func _end_dialogue() -> void:
	if not is_talking:
		return
	is_talking = false
	var prototype := get_tree().get_first_node_in_group("prototype")
	if prototype and bool(prototype.call("is_dialogue_open")):
		prototype.call("end_dialogue")
	if player_in_range:
		hint.show()

func _load_sprite_frames(folder: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	for animation_name in ["idle", "interact"]:
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, 6.0)
		frames.set_animation_loop(animation_name, animation_name == "idle")
		for frame_number in range(1, 7):
			var frame_path := "%s/%s/frame_%02d.png" % [folder, animation_name, frame_number]
			var frame := load(frame_path) as Texture2D
			if frame:
				frames.add_frame(animation_name, frame)
	return frames

func _on_visual_animation_finished() -> void:
	if visual.animation == "interact" and visible:
		visual.play("idle")
