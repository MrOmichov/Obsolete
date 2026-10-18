extends Node

enum Phase {
	DAWN,
	DAY,
	NIGHT,
}

const DAWN_DURATION_SECONDS: float = 30.0
const DAY_DURATION_SECONDS: float = 60.0
const NIGHT_DURATION_SECONDS: float = 180.0

const LIGHT_TRANSITION_DURATION_SECONDS: float = 3.0
const DAWN_LIGHT_COLOR: Color = Color(0.86, 0.78, 0.64)
const DAY_LIGHT_COLOR: Color = Color(1.0, 1.0, 1.0)
const NIGHT_LIGHT_COLOR: Color = Color(0.38, 0.45, 0.62)


func phase_duration_seconds(phase: int) -> float:
	match phase:
		Phase.DAWN:
			return DAWN_DURATION_SECONDS
		Phase.DAY:
			return DAY_DURATION_SECONDS
		Phase.NIGHT:
			return NIGHT_DURATION_SECONDS
		_:
			push_error("Unknown day/night phase: %s" % phase)
			return 0.0


func phase_light_color(phase: int) -> Color:
	match phase:
		Phase.DAWN:
			return DAWN_LIGHT_COLOR
		Phase.DAY:
			return DAY_LIGHT_COLOR
		Phase.NIGHT:
			return NIGHT_LIGHT_COLOR
		_:
			push_error("Unknown day/night phase: %s" % phase)
			return DAY_LIGHT_COLOR
