extends Node

signal phase_changed(previous_phase: int, current_phase: int)
signal dawn_started

var current_phase: int = Global.Phase.DAWN
var remaining_seconds: float = Global.DAWN_DURATION_SECONDS

var _dialogue_paused: bool = false


func _ready() -> void:
	add_to_group("day_night")


func _process(delta: float) -> void:
	if _dialogue_paused:
		return

	var time_to_advance: float = delta
	while time_to_advance >= remaining_seconds:
		time_to_advance -= remaining_seconds
		_enter_phase(_next_phase(current_phase))

	remaining_seconds -= time_to_advance


func set_dialogue_paused(paused: bool) -> void:
	_dialogue_paused = paused


func is_dialogue_paused() -> bool:
	return _dialogue_paused


func _enter_phase(next_phase: int) -> void:
	var previous_phase: int = current_phase
	current_phase = next_phase
	remaining_seconds = Global.phase_duration_seconds(current_phase)
	phase_changed.emit(previous_phase, current_phase)

	if current_phase == Global.Phase.DAWN:
		dawn_started.emit()


func _next_phase(phase: int) -> int:
	match phase:
		Global.Phase.DAWN:
			return Global.Phase.DAY
		Global.Phase.DAY:
			return Global.Phase.NIGHT
		Global.Phase.NIGHT:
			return Global.Phase.DAWN
		_:
			push_error("Unknown day/night phase: %s" % phase)
			return Global.Phase.DAWN
