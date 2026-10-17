extends Node2D
## Gameplay controller. All level geometry, actors and HUD live in prototype.tscn.

const AMBER = Color("e7b86b")
const CYAN = Color("80d5c4")

var parts: int = 0
var power_repaired: bool = false
var data_collected: bool = false
var terminal_repaired: bool = false
var completed: bool = false
var home_reached: bool = false
var mentor_supplied: bool = false
var dialogue_owner: Node
var dialogue_lines: Array[String] = []
var dialogue_index: int = 0
var threat_active: bool = false
var threat_grace: float = 8.0
var hit_cooldown: float = 0.0
var threat_distance: float = 9999.0
var _notice_time: float = 0.0
var _pulse: float = 0.0

@onready var player: CharacterBody2D = $Actors/Player
@onready var gate_shape: CollisionShape2D = $Board/Walls/Gate/CollisionShape2D
@onready var power_object: StaticBody2D = $Actors/PowerSupply
@onready var terminal_object: StaticBody2D = $Actors/CoolingTerminal
@onready var data_sprite: Sprite2D = $Board/Archive/DataPickup
@onready var home: Marker2D = $Board/Home
@onready var archive: Marker2D = $Board/Archive
@onready var threat_spawn: Marker2D = $ThreatSpawn
@onready var threat_position: Vector2 = threat_spawn.global_position
@onready var cycle: Node = $DayNightManager
@onready var _dialogue_panel: PanelContainer = $HUD/Dialogue
@onready var _dialogue_text: Label = $HUD/Dialogue/Text
@onready var _phase_label: Label = $HUD/StatusPanel/Columns/Status/Phase
@onready var _inventory_label: Label = $HUD/StatusPanel/Columns/Status/Inventory
@onready var _objective_label: Label = $HUD/ObjectivePanel/Text
@onready var _prompt_label: Label = $HUD/PromptPanel/Text
@onready var _notice_label: Label = $HUD/Notice
@onready var _danger_label: Label = $HUD/Danger
@onready var _gate_label: Label = $Board/Walls/Gate/Status
@onready var _data_label: Label = $Board/Archive/Status
@onready var _restart_button: Button = $HUD/Restart
@onready var _closed_beam: Line2D = $Board/Walls/Gate/ClosedBeam
@onready var _open_signal: Line2D = $Board/Walls/Gate/OpenSignal
@onready var _threat_trace: Line2D = $Threat/Trace

func _ready() -> void:
	add_to_group("prototype")
	_ensure_input()
	cycle.phase_changed.connect(_on_phase_changed)
	cycle.dawn_started.connect(_on_dawn)
	power_object.repaired.connect(_on_power_repaired)
	terminal_object.repaired.connect(_on_terminal_repaired)
	_restart_button.pressed.connect(restart_run)
	_notify("Система просыпается. Найди резистора у блока питания.")

func _on_power_repaired() -> void:
	power_repaired = true
	gate_shape.set_deferred("disabled", true)
	_closed_beam.hide()
	_open_signal.show()
	_notify("Питание восстановлено. Восточный проход открыт. Ночью забери данные из архива.")

func _on_terminal_repaired() -> void:
	terminal_repaired = true
	_notify("Адрес восстановлен. Вернись в свою ячейку и дождись рассвета.")

func _ensure_input() -> void:
	for action in {"interact": KEY_E, "demo_phase": KEY_N, "restart_run": KEY_R}:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key = InputEventKey.new()
			key.physical_keycode = {"interact": KEY_E, "demo_phase": KEY_N, "restart_run": KEY_R}[action]
			InputMap.action_add_event(action, key)
	for action in {"move_left": KEY_LEFT, "move_right": KEY_RIGHT, "move_up": KEY_UP, "move_down": KEY_DOWN}:
		var key = InputEventKey.new()
		key.physical_keycode = {"move_left": KEY_LEFT, "move_right": KEY_RIGHT, "move_up": KEY_UP, "move_down": KEY_DOWN}[action]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_add_event(action, key)

func interact_npc(npc: Node) -> void:
	if completed or cycle.current_phase == Global.Phase.NIGHT:
		return
	if is_dialogue_open():
		advance_dialogue()
		return
	if npc.gives_part and not mentor_supplied:
		parts += 1
		mentor_supplied = true
		_notify("Получен контакт для ремонта: +1.")
	begin_dialogue(npc, npc.dialogue)

func begin_dialogue(npc: Node, lines: Array[String]) -> void:
	if lines.is_empty():
		return
	dialogue_owner = npc
	dialogue_lines = lines.duplicate()
	dialogue_index = 0
	cycle.set_dialogue_paused(true)
	_dialogue_panel.show()
	_show_dialogue_line()

func _show_dialogue_line() -> void:
	_dialogue_text.text = "%s\n%s\n[E] Дальше" % [dialogue_owner.display_name, dialogue_lines[dialogue_index]]

func advance_dialogue() -> void:
	dialogue_index += 1
	if dialogue_index >= dialogue_lines.size():
		end_dialogue()
	else:
		_show_dialogue_line()

func end_dialogue() -> void:
	if is_instance_valid(dialogue_owner):
		dialogue_owner.is_talking = false
		dialogue_owner.get_node("Visual").play("idle")
		dialogue_owner.get_node("Hint").visible = dialogue_owner.player_in_range
	dialogue_owner = null
	dialogue_lines.clear()
	_dialogue_panel.hide()
	cycle.set_dialogue_paused(false)

func is_dialogue_open() -> bool:
	return dialogue_owner != null

func try_repair(object: Node) -> bool:
	if completed or is_dialogue_open():
		return false
	if not object.is_broken:
		return false
	if object.object_id == &"terminal" and not data_collected:
		_notify("Терминалу нужны данные из архива. Они доступны ночью за восточным проходом.")
		return false
	if parts < object.required_parts:
		_notify("Нужен контакт. Первый выдаёт резистор; второй лежит в ночном архиве.")
		return false
	parts -= object.required_parts
	RunProgress.record_completed_task(object.object_id)
	return true

func collect_data() -> bool:
	if not power_repaired or data_collected or cycle.current_phase != Global.Phase.NIGHT:
		return false
	data_collected = true
	parts += 1
	data_sprite.hide()
	_notify("Архив прочитан: адрес ячейки и контакт +1. Восстанови терминал охлаждения внизу справа.")
	return true

func return_home() -> bool:
	if not terminal_repaired:
		_notify("Это твоё место. Здесь помехи не достают. Сначала восстанови терминал.")
		return false
	home_reached = true
	_notify("Адрес подтверждён. Оставайся в своей ячейке до рассвета.")
	if cycle.current_phase == Global.Phase.DAWN:
		_finish()
	return true

func _finish() -> void:
	completed = true
	threat_active = false
	cycle.set_dialogue_paused(true)
	player.velocity = Vector2.ZERO
	RunProgress.record_completed_task(&"return_home")
	_notify("РАССВЕТ. Ты вернулся на своё место. Система стабильна. Прототип пройден.", 60.0)
	_restart_button.show()

func restart_run() -> void:
	RunProgress.reset_for_new_run()
	get_tree().reload_current_scene()

func _on_phase_changed(_previous: int, current: int) -> void:
	if is_dialogue_open():
		end_dialogue()
	threat_active = current == Global.Phase.NIGHT and not completed
	threat_grace = 8.0
	threat_position = threat_spawn.global_position
	data_sprite.visible = threat_active and power_repaired and not data_collected
	if current == Global.Phase.NIGHT:
		_notify("Ночь. Компоненты замолчали. Помехи приближаются. Архив доступен на востоке.")
	elif current == Global.Phase.DAY:
		_notify("День. Подготовь питание и изучи путь к архиву.")
	_update_threat_visual()

func _on_dawn() -> void:
	if home_reached and terminal_repaired and player.global_position.distance_to(home.global_position) < 110:
		_finish()
	else:
		_notify("Рассвет. Помехи ушли, NPC вернулись. Выполненные ремонты сохранены.")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_run"):
		restart_run()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("demo_phase") and not completed and not is_dialogue_open():
		cycle._enter_phase(cycle._next_phase(cycle.current_phase))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		if is_dialogue_open():
			advance_dialogue()
			get_viewport().set_input_as_handled()
		elif player.global_position.distance_to(archive.global_position) < 112:
			if not collect_data():
				_notify("Данные доступны ночью, после восстановления питания.")
			get_viewport().set_input_as_handled()
		elif player.global_position.distance_to(home.global_position) < 100:
			return_home()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_pulse += delta
	_notice_time = maxf(0, _notice_time - delta)
	_notice_label.visible = _notice_time > 0 and not is_dialogue_open()
	_phase_label.text = "%s · %02d:%02d" % [["РАССВЕТ", "ДЕНЬ", "НОЧЬ"][cycle.current_phase], int(ceil(cycle.remaining_seconds)) / 60, int(ceil(cycle.remaining_seconds)) % 60]
	_inventory_label.text = "Контакты: %d    Архив: %s    Ремонт: %d/2" % [parts, "прочитан" if data_collected else "нет данных", int(power_repaired) + int(terminal_repaired)]
	_objective_label.text = _objective()
	_gate_label.text = "ПРОХОД ОТКРЫТ" if power_repaired else "ПИТАНИЕ ОТКЛЮЧЕНО"
	_gate_label.modulate = CYAN if power_repaired else AMBER
	_data_label.text = "ДАННЫЕ ПОЛУЧЕНЫ" if data_collected else ("[E] ПРОЧИТАТЬ АРХИВ" if cycle.current_phase == Global.Phase.NIGHT else "АРХИВ НЕДОСТУПЕН ДО НОЧИ")
	_update_prompt()
	_update_threat(delta)
	_update_threat_visual()

func _objective() -> String:
	if completed:
		return "ЦИКЛ ЗАВЕРШЁН\nТы снова часть системы. R — начать заново."
	if not mentor_supplied:
		return "01 / ПОДГОТОВКА\nПоговори с резистором у блока питания."
	if not power_repaired:
		return "02 / ПИТАНИЕ\nПочини блок справа от резистора: E рядом."
	if not data_collected:
		return "03 / АРХИВ\nНочью забери данные в восточном секторе."
	if not terminal_repaired:
		return "04 / ВОССТАНОВЛЕНИЕ\nПочини терминал охлаждения внизу справа."
	return "05 / ВОЗВРАЩЕНИЕ\nE в своей ячейке слева внизу. Дождись рассвета."

func _update_prompt() -> void:
	_prompt_label.text = "Исследуй плату. Следуй текущей задаче."
	if completed:
		_prompt_label.text = "СИСТЕМА СТАБИЛЬНА · R — новый запуск"
	elif is_dialogue_open():
		_prompt_label.text = "E — продолжить разговор · время приостановлено"
	elif player.global_position.distance_to(home.global_position) < 100:
		_prompt_label.text = "E — вернуться на своё место · безопасная зона"
	elif player.global_position.distance_to(archive.global_position) < 112:
		_prompt_label.text = "E — прочитать ночной архив"
	else:
		for npc in get_tree().get_nodes_in_group("prototype_npcs"):
			if npc.visible and npc.player_in_range:
				_prompt_label.text = "E — поговорить: " + npc.display_name
		for object in [power_object, terminal_object]:
			if object.is_broken and object.player_in_range:
				_prompt_label.text = "E — ремонт · нужен 1 контакт"

func _update_threat(delta: float) -> void:
	hit_cooldown = maxf(0, hit_cooldown - delta)
	_danger_label.text = ""
	if not threat_active or is_dialogue_open() or completed:
		return
	threat_grace = maxf(0, threat_grace - delta)
	var safe: bool = player.global_position.distance_to(home.global_position) < 110
	if threat_grace <= 0 and not safe:
		threat_position = threat_position.move_toward(player.global_position, delta * 110)
	threat_distance = threat_position.distance_to(player.global_position)
	if safe:
		_danger_label.text = "ЯЧЕЙКА ЭКРАНИРОВАНА"
	elif threat_distance < 240:
		_danger_label.text = "ПОМЕХИ РЯДОМ · ДВИГАЙСЯ"
	else:
		_danger_label.text = "НЕСТАБИЛЬНЫЙ СИГНАЛ"
	if threat_distance < 34 and not safe and hit_cooldown <= 0 and threat_grace <= 0:
		player.global_position = home.global_position
		player.velocity = Vector2.ZERO
		hit_cooldown = 6.0
		threat_grace = 8.0
		threat_position = threat_spawn.global_position
		_notify("Сбой выбросил тебя в свою ячейку. Ремонт и собранные данные сохранены.")

func _notify(text: String, seconds: float = 7.0) -> void:
	_notice_label.text = text
	_notice_time = seconds

func _update_threat_visual() -> void:
	_threat_trace.visible = threat_active and threat_grace <= 0 and threat_distance < 280
	if not _threat_trace.visible:
		return
	var intensity: float = clampf(1.0 - threat_distance / 280.0, 0, 1)
	_threat_trace.global_position = threat_position
	_threat_trace.default_color = Color(.9, .4, .2, intensity * .3)
	var radius: float = 34 + sin(_pulse * 7) * 8
	var points = PackedVector2Array()
	for i in range(25):
		points.append(Vector2.from_angle(_pulse + PI * i / 24) * radius)
	_threat_trace.points = points
