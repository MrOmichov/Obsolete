extends CanvasModulate

@export_node_path("Node") var day_night_manager_path: NodePath = NodePath("../DayNightManager")

var _day_night_manager: Node
var _light_tween: Tween


func _ready() -> void:
	_day_night_manager = get_node_or_null(day_night_manager_path)
	if _day_night_manager == null:
		push_error("WorldLightController requires a DayNightManager node.")
		return

	color = Global.phase_light_color(_day_night_manager.current_phase)
	_day_night_manager.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(_previous_phase: int, current_phase: int) -> void:
	if _light_tween != null and _light_tween.is_running():
		_light_tween.kill()

	_light_tween = create_tween()
	_light_tween.tween_property(
		self,
		"color",
		Global.phase_light_color(current_phase),
		Global.LIGHT_TRANSITION_DURATION_SECONDS
	)
