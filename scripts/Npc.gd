extends StaticBody2D

@export var dialogue: Array[String] = [
	"Привет, путник!",
	"Осторожнее в лесу, там неспокойно.",
	"Удачи тебе!"
]
@export var only_during_day: bool = true   # true: днём есть, ночью пропадает; false: наоборот
@export var fade_time: float = 1.0         # длительность плавного исчезновения

@onready var hint: Label = $Hint
@onready var zone: Area2D = $InteractionZone
@onready var panel: Panel = $Panel
@onready var text_label: Label = $Panel/VBoxContainer/Label
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var fade_tween: Tween


var player_in_range := false
var is_talking := false
var line_index := 0
func _on_phase_changed(is_day: bool) -> void:
	_set_present(is_day == only_during_day, true)

func _set_present(present: bool, animate: bool) -> void:
	if not present:
		# закрываем диалог и подсказку, пока NPC ещё "существует"
		_end_dialogue()
		player_in_range = false
		hint.hide()

	# отключаем физику и зону взаимодействия
	body_shape.set_deferred("disabled", not present)
	zone.set_deferred("monitoring", not present == false)

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
	panel.hide()

	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)
	var day_night := get_tree().get_first_node_in_group("day_night")
	if day_night:
		day_night.phase_changed.connect(_on_phase_changed)
		await get_tree().process_frame
		_set_present(day_night.is_day == only_during_day, false)

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
	line_index = 0
	hint.hide()
	panel.show()
	text_label.text = dialogue[line_index]

func _next_line() -> void:
	line_index += 1
	if line_index >= dialogue.size():
		_end_dialogue()
		if player_in_range:
			hint.show()
	else:
		text_label.text = dialogue[line_index]

func _end_dialogue() -> void:
	is_talking = false
	panel.hide()
