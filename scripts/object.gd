extends StaticBody2D

signal repaired
signal broken

@export var texture_working: Texture2D
@export var texture_broken: Texture2D
@export var start_broken: bool = false
@export var hint_text: String = "[E]"
@export var object_id: StringName = &"generator"
@export var required_parts: int = 1

# Если нужно, чтобы объект ломался сам: интервал в секундах (0 = не ломается сам)
@export var auto_break_min: float = 30.0
@export var auto_break_max: float = 60.0

@onready var sprite: Sprite2D = $Sprite
@onready var zone: Area2D = $Area2D
@onready var hint: Label = $CanvasLayer/Label

var is_broken := false
var player_in_range := false
var break_timer: Timer

func _ready() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var event := InputEventKey.new()
		event.physical_keycode = KEY_E
		InputMap.action_add_event("interact", event)

	hint.text = hint_text
	hint.hide()

	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)

	break_timer = Timer.new()
	break_timer.one_shot = true
	break_timer.timeout.connect(break_down)
	add_child(break_timer)

	_set_broken(start_broken)
	if not start_broken:
		_schedule_break()

func _process(_delta: float) -> void:
	if hint.visible:
		var screen_pos := get_global_transform_with_canvas().origin
		hint.position = screen_pos + Vector2(-hint.size.x / 2.0, -60.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		hint.visible = is_broken

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		hint.hide()

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and is_broken and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		repair()

func repair() -> bool:
	if not is_broken:
		return false
	var prototype := get_tree().get_first_node_in_group("prototype")
	if prototype and not bool(prototype.call("try_repair", self)):
		return false
	_set_broken(false)
	repaired.emit()
	_schedule_break()
	return true

func break_down() -> void:
	_set_broken(true)
	broken.emit()

func _set_broken(value: bool) -> void:
	is_broken = value
	sprite.texture = texture_broken if is_broken else texture_working
	hint.visible = is_broken and player_in_range

func _schedule_break() -> void:
	if auto_break_max > 0.0:
		break_timer.start(randf_range(auto_break_min, auto_break_max))
