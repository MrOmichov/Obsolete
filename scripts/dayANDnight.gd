extends CanvasModulate

signal phase_changed(is_day: bool)

@export var phase_duration: float = 15  
@export var transition_time: float = 10.0   
@export var day_color: Color = Color(1, 1, 1)
@export var night_color: Color = Color(0.25, 0.3, 0.55)
@export var start_as_day: bool = true

@onready var label: Label = $CanvasLayer/Timer

var is_day: bool
var time_left: float

func _ready() -> void:
	add_to_group("day_night")
	is_day = start_as_day
	time_left = phase_duration
	color = day_color if is_day else night_color
	_update_label()

func _process(delta: float) -> void:
	time_left -= delta

	if time_left <= 0.0:
		is_day = not is_day
		time_left += phase_duration
		phase_changed.emit(is_day)

	_update_color()
	_update_label()

func _update_color() -> void:
	var current := day_color if is_day else night_color
	var next := night_color if is_day else day_color

	if time_left < transition_time:
		var t := 1.0 - time_left / transition_time
		color = current.lerp(next, t)
	else:
		color = current

func _update_label() -> void:
	var seconds_total := ceili(time_left)
	var minutes := seconds_total / 60
	var seconds := seconds_total % 60

	var phase_name := "День" if is_day else "Ночь"
	var next_name := "ночи" if is_day else "дня"
	label.text = "%s. До %s: %d:%02d" % [phase_name, next_name, minutes, seconds]
