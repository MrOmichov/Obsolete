extends Node2D
## One playable board connecting the original player/NPC/repair code to the phase cycle.

const NPC_SCENE = preload("res://zlobity/npc.tscn")
const OBJECT_SCENE = preload("res://zlobity/object.tscn")
const PLAYER_SCRIPT = preload("res://scripts/Player.gd")
const BOARD_SIZE = Vector2(1600, 960)
const HOME = Vector2(270, 690)
const DATA_POSITION = Vector2(1320, 310)
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
var player: CharacterBody2D
var gate_shape: CollisionShape2D
var power_object: StaticBody2D
var terminal_object: StaticBody2D
var data_sprite: Sprite2D
var threat_position = Vector2(1450, 800)
var threat_active: bool = false
var threat_grace: float = 8.0
var hit_cooldown: float = 0.0
var threat_distance: float = 9999.0
var _notice_time: float = 0.0
var _dialogue_panel: PanelContainer
var _dialogue_text: Label
var _phase_label: Label
var _inventory_label: Label
var _objective_label: Label
var _prompt_label: Label
var _notice_label: Label
var _danger_label: Label
var _gate_label: Label
var _data_label: Label
var _home_label: Label
var _restart_button: Button
var _pulse: float = 0.0

@onready var cycle: Node = $DayNightManager

func _ready() -> void:
	add_to_group("prototype")
	_ensure_input()
	_build_board()
	_build_player()
	_build_actors()
	_build_hud()
	cycle.phase_changed.connect(_on_phase_changed)
	cycle.dawn_started.connect(_on_dawn)
	_notify("Система просыпается. Найди резистора у блока питания.")

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

func _build_board() -> void:
	var floor_sprite = Sprite2D.new()
	floor_sprite.texture = load("res://assets/world/motherboard/row_01/panel_01.png")
	floor_sprite.centered = false
	floor_sprite.region_enabled = true
	floor_sprite.region_rect = Rect2(Vector2.ZERO, BOARD_SIZE)
	floor_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor_sprite.modulate = Color(0.47, 0.61, 0.56)
	floor_sprite.z_index = -10
	add_child(floor_sprite)
	_wall(Vector2(800, 105), Vector2(1480, 26))
	_wall(Vector2(800, 885), Vector2(1480, 26))
	_wall(Vector2(60, 495), Vector2(26, 800))
	_wall(Vector2(1540, 495), Vector2(26, 800))
	_wall(Vector2(900, 255), Vector2(32, 300))
	_wall(Vector2(900, 745), Vector2(32, 280))
	gate_shape = _wall(Vector2(900, 505), Vector2(24, 200))
	_gate_label = _world_label("ПИТАНИЕ ОТКЛЮЧЕНО", Vector2(780, 395), AMBER)
	_world_label("01 / СЕРВИСНЫЙ УЧАСТОК", Vector2(130, 145), CYAN)
	_world_label("02 / АРХИВ ПАМЯТИ", Vector2(1010, 145), CYAN)
	_world_label("БЛОК ПИТАНИЯ", Vector2(490, 230), AMBER)
	_world_label("ТЕРМИНАЛ ОХЛАЖДЕНИЯ", Vector2(1080, 620), AMBER)
	_home_label = _world_label("ТВОЁ МЕСТО / БЕЗОПАСНАЯ ЗОНА", HOME + Vector2(-150, 85), CYAN)
	_equipment("res://assets/world/hard_drive/row_02/panel_04.png", DATA_POSITION, Vector2(180, 130))
	_equipment("res://assets/world/floppy_drive/row_02/panel_01.png", Vector2(620, 745), Vector2(170, 110))
	_data_label = _world_label("АРХИВ НЕДОСТУПЕН ДО НОЧИ", DATA_POSITION + Vector2(-135, 90), AMBER)
	data_sprite = Sprite2D.new()
	data_sprite.texture = load("res://assets/characters/npc/floppy_disk/idle/frame_01.png")
	data_sprite.position = DATA_POSITION + Vector2(0, -10)
	data_sprite.scale = Vector2(0.42, 0.42)
	data_sprite.visible = false
	add_child(data_sprite)

func _wall(at: Vector2, size: Vector2) -> CollisionShape2D:
	var body = StaticBody2D.new()
	body.position = at
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return collision

func _equipment(path: String, at: Vector2, size: Vector2) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = load(path)
	sprite.scale = size / sprite.texture.get_size()
	sprite.position = at
	add_child(sprite)
	return sprite

func _world_label(text: String, at: Vector2, tint: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", Color("101c20"))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	return label

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.position = HOME
	player.speed = 205.0
	var camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(BOARD_SIZE.x)
	camera.limit_bottom = int(BOARD_SIZE.y)
	camera.zoom = Vector2(0.8, 0.8)
	player.add_child(camera)
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 13.0
	collision.shape = shape
	collision.position.y = 10.0
	player.add_child(collision)
	var visual = AnimatedSprite2D.new()
	visual.name = "Visual"
	visual.scale = Vector2(0.65, 0.65)
	visual.position.y = -24.0
	player.add_child(visual)
	add_child(player)

func _build_actors() -> void:
	_spawn_npc("resistor", "Резистор · наставник", Vector2(330, 330), true,
		["Системе не хватает питания. Возьми контакт и восстанови блок справа от меня.", "Почини питание, а ночью забери данные из архива за проходом. Не задерживайся в темноте."])
	_spawn_npc("diode", "Диод · проводник", Vector2(655, 535), false,
		["Проход на восток откроется после ремонта питания.", "Архив отдаёт данные только ночью. С ними восстанови терминал охлаждения. Твоё место внизу слева защищает от помех."])
	_spawn_npc("microchip", "Микросхема · диспетчер", Vector2(1150, 435), false,
		["В архиве сохранился адрес твоей ячейки.", "Восстанови терминал и вернись на своё место до рассвета. Ночью двигайся: помехи чувствуют остановки."])
	power_object = _spawn_object("power", Vector2(615, 325), "power_supply")
	power_object.repaired.connect(func():
		power_repaired = true
		gate_shape.set_deferred("disabled", true)
		_notify("Питание восстановлено. Восточный проход открыт. Ночью забери данные из архива.")
		queue_redraw())
	terminal_object = _spawn_object("terminal", Vector2(1220, 705), "cooling_system")
	terminal_object.repaired.connect(func():
		terminal_repaired = true
		_notify("Адрес восстановлен. Вернись в свою ячейку и дождись рассвета.")
		queue_redraw())

func _spawn_npc(id: String, title: String, at: Vector2, supplies: bool, lines: Array[String]) -> void:
	var npc = NPC_SCENE.instantiate()
	npc.npc_id = StringName(id)
	npc.display_name = title
	npc.asset_folder = "res://assets/characters/npc/" + id
	npc.gives_part = supplies
	npc.dialogue = lines
	npc.position = at
	npc.add_to_group("prototype_npcs")
	add_child(npc)
	npc.get_node("Visual").scale = Vector2.ONE * (0.29 if id == "resistor" else 0.85)
	npc.get_node("Visual").position.y = -18
	var body_shape: CollisionShape2D = npc.get_node("CollisionShape2D")
	body_shape.shape = body_shape.shape.duplicate()
	body_shape.shape.size = Vector2(45, 28)
	body_shape.position.y = 13
	var name_label = _world_label(title, at + Vector2(-85, 55), CYAN)
	name_label.reparent(npc)

func _spawn_object(id: String, at: Vector2, folder: String) -> StaticBody2D:
	var object = OBJECT_SCENE.instantiate()
	object.object_id = StringName(id)
	object.position = at
	object.start_broken = true
	object.auto_break_min = 0.0
	object.auto_break_max = 0.0
	var working_panel: int = 2 if id == "power" else 6
	var broken_panel: int = 1 if id == "power" else 5
	object.texture_working = load("res://assets/world/%s/row_03/panel_%02d.png" % [folder, working_panel])
	object.texture_broken = load("res://assets/world/%s/row_03/panel_%02d.png" % [folder, broken_panel])
	object.hint_text = "[E] Починить · 1 контакт"
	add_child(object)
	object.get_node("Sprite").scale = Vector2(170, 120) / object.texture_working.get_size()
	return object

func _panel(at: Vector2, size: Vector2) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.position = at
	panel.custom_minimum_size = size
	var style = StyleBoxFlat.new()
	style.bg_color = Color("111e24f5")
	style.border_color = Color("355350")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _label(text: String, size: int = 17, tint: Color = Color("d8e6df")) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	return label

func _build_hud() -> void:
	var hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	var top = _panel(Vector2(22, 18), Vector2(1236, 92))
	hud.add_child(top)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	top.add_child(row)
	var title = VBoxContainer.new()
	row.add_child(title)
	title.add_child(_label("OBSOLETE", 27, AMBER))
	title.add_child(_label("DUSTWARE / МАТЕРИНСКАЯ ПЛАТА", 12, CYAN))
	var status = VBoxContainer.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(status)
	_phase_label = _label("")
	_inventory_label = _label("", 15, CYAN)
	status.add_child(_phase_label)
	status.add_child(_inventory_label)
	var controls = VBoxContainer.new()
	row.add_child(controls)
	controls.add_child(_label("WASD / стрелки — движение    E — действие", 14))
	controls.add_child(_label("N — следующая фаза (демо)    R — новый цикл", 13, Color("90a7a1")))
	var objective = _panel(Vector2(22, 124), Vector2(430, 80))
	hud.add_child(objective)
	_objective_label = _label("", 16)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size.x = 394
	objective.add_child(_objective_label)
	_notice_label = _label("", 16, AMBER)
	_notice_label.position = Vector2(36, 636)
	_notice_label.custom_minimum_size = Vector2(520, 64)
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(_notice_label)
	_danger_label = _label("", 18, Color("f29a7d"))
	_danger_label.position = Vector2(760, 130)
	hud.add_child(_danger_label)
	var prompt = _panel(Vector2(290, 712), Vector2(700, 60))
	hud.add_child(prompt)
	_prompt_label = _label("", 17, CYAN)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_child(_prompt_label)
	_dialogue_panel = _panel(Vector2(180, 568), Vector2(920, 132))
	hud.add_child(_dialogue_panel)
	_dialogue_text = _label("", 19)
	_dialogue_text.custom_minimum_size = Vector2(880, 100)
	_dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_panel.add_child(_dialogue_text)
	_dialogue_panel.hide()
	_restart_button = Button.new()
	_restart_button.text = "Начать заново"
	_restart_button.position = Vector2(1010, 714)
	_restart_button.size = Vector2(220, 54)
	_restart_button.pressed.connect(restart_run)
	_restart_button.hide()
	hud.add_child(_restart_button)

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
	threat_position = Vector2(1460, 800)
	data_sprite.visible = threat_active and power_repaired and not data_collected
	if current == Global.Phase.NIGHT:
		_notify("Ночь. Компоненты замолчали. Помехи приближаются. Архив доступен на востоке.")
	elif current == Global.Phase.DAY:
		_notify("День. Подготовь питание и изучи путь к архиву.")
	queue_redraw()

func _on_dawn() -> void:
	if home_reached and terminal_repaired and player.position.distance_to(HOME) < 110:
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
		elif player.position.distance_to(DATA_POSITION) < 112:
			if not collect_data():
				_notify("Данные доступны ночью, после восстановления питания.")
			get_viewport().set_input_as_handled()
		elif player.position.distance_to(HOME) < 100:
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
	queue_redraw()

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
	elif player.position.distance_to(HOME) < 100:
		_prompt_label.text = "E — вернуться на своё место · безопасная зона"
	elif player.position.distance_to(DATA_POSITION) < 112:
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
	var safe: bool = player.position.distance_to(HOME) < 110
	if threat_grace <= 0 and not safe:
		threat_position = threat_position.move_toward(player.position, delta * 110)
	threat_distance = threat_position.distance_to(player.position)
	if safe:
		_danger_label.text = "ЯЧЕЙКА ЭКРАНИРОВАНА"
	elif threat_distance < 240:
		_danger_label.text = "ПОМЕХИ РЯДОМ · ДВИГАЙСЯ"
	else:
		_danger_label.text = "НЕСТАБИЛЬНЫЙ СИГНАЛ"
	if threat_distance < 34 and not safe and hit_cooldown <= 0 and threat_grace <= 0:
		player.position = HOME
		player.velocity = Vector2.ZERO
		hit_cooldown = 6.0
		threat_grace = 8.0
		threat_position = Vector2(1460, 800)
		_notify("Сбой выбросил тебя в свою ячейку. Ремонт и собранные данные сохранены.")

func _notify(text: String, seconds: float = 7.0) -> void:
	_notice_label.text = text
	_notice_time = seconds

func _draw() -> void:
	# Board traces and equipment sockets remain visible underneath the original textures.
	for x in range(100, 1540, 80):
		draw_line(Vector2(x, 120), Vector2(x, 870), Color(0.35, 0.65, 0.55, 0.065))
	for y in range(150, 870, 80):
		draw_line(Vector2(75, y), Vector2(1525, y), Color(0.35, 0.65, 0.55, 0.065))
	for y in [111, 879]:
		draw_line(Vector2(72, y), Vector2(1528, y), Color("82947b"), 7)
	for x in [66, 1534]:
		draw_line(Vector2(x, 111), Vector2(x, 879), Color("82947b"), 7)
	for point in [Vector2(95, 140), Vector2(1505, 140), Vector2(95, 850), Vector2(1505, 850)]:
		draw_circle(point, 13, Color("26352f"))
		draw_circle(point, 6, Color("7a8c75"))
	draw_line(Vector2(900, 120), Vector2(900, 402), Color("1b2827"), 28)
	draw_line(Vector2(900, 608), Vector2(900, 870), Color("1b2827"), 28)
	draw_line(Vector2(900, 120), Vector2(900, 400), CYAN.darkened(.6), 3)
	draw_line(Vector2(900, 610), Vector2(900, 870), CYAN.darkened(.6), 3)
	if not power_repaired:
		draw_line(Vector2(900, 408), Vector2(900, 602), AMBER, 7)
	else:
		draw_line(Vector2(855, 505), Vector2(945, 505), Color(CYAN, .55), 3)
	draw_circle(HOME, 76, Color(0.3, 0.7, 0.6, .12))
	draw_arc(HOME, 79, 0, TAU, 64, CYAN, 2)
	draw_rect(Rect2(HOME - Vector2(30, 22), Vector2(60, 44)), CYAN.darkened(.3), false, 3)
	for x in [-43, 43]:
		for y in [-15, 0, 15]:
			draw_line(HOME + Vector2(x, y), HOME + Vector2(sign(x) * 30, y), AMBER, 3)
	if threat_active and threat_grace <= 0 and threat_distance < 280:
		var intensity: float = clampf(1.0 - threat_distance / 280.0, 0, 1)
		draw_arc(threat_position, 34 + sin(_pulse * 7) * 8, _pulse, _pulse + PI, 24, Color(0.9, .4, .2, intensity * .3), 2)
