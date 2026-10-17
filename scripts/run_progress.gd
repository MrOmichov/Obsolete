extends Node

enum Outcome {
	COMPLETED,
	MISSED,
}

signal task_outcome_recorded(task_id: StringName, outcome: int)
signal run_progress_reset

var _task_outcomes: Dictionary = {}
var _missed_task_count: int = 0

var missed_task_count: int:
	get:
		return _missed_task_count


func record_completed_task(task_id: StringName) -> bool:
	return _record_task_outcome(task_id, Outcome.COMPLETED)


func record_missed_task(task_id: StringName) -> bool:
	return _record_task_outcome(task_id, Outcome.MISSED)


func has_task_outcome(task_id: StringName) -> bool:
	return _task_outcomes.has(task_id)


func task_outcome_for(task_id: StringName) -> int:
	if not has_task_outcome(task_id):
		return -1
	return _task_outcomes[task_id]


func reset_for_new_run() -> void:
	_task_outcomes.clear()
	_missed_task_count = 0
	run_progress_reset.emit()


func _record_task_outcome(task_id: StringName, outcome: int) -> bool:
	if String(task_id).strip_edges().is_empty():
		push_error("Task outcome requires a non-empty task ID.")
		return false

	if _task_outcomes.has(task_id):
		return false

	_task_outcomes[task_id] = outcome
	if outcome == Outcome.MISSED:
		_missed_task_count += 1
	task_outcome_recorded.emit(task_id, outcome)
	return true
