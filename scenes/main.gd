extends Node3D

# Баланс уровня. Это @export: у каждого уровня свои числа — кликни корневой
# узел уровня и меняй их в Inspector, код трогать не нужно.
# Сколько единиц заряда в начале (это же и максимум)
@export var max_energy := 100.0
# Сколько единиц заряда уходит каждую секунду
@export var drain_rate := 8.0
# Сколько единиц добавляет одна батарейка
@export var battery_energy := 40.0
# Сколько единиц отнимает удар врага
@export var hit_damage := 45.0
# Сколько единиц отнимает падение с острова
@export var fall_damage := 15.0

# Следующий уровень. Пусто — это последний уровень игры
@export_file("*.tscn") var next_level := ""
# Музыка этого уровня (файл из audio/music)
@export var music: AudioStream

var energy := 0.0         # текущий заряд (полный — в _ready)
var collected := 0         # сколько собрано
var total := 0             # сколько всего на уровне
var game_over := false     # закончилась ли игра
var victory := false       # пройдена вся игра
var finished_run := false  # и это был забег с первого уровня (тогда R начинает забег заново)

# Меню паузы (по Esc) — та же сцена, что и главное меню
const MENU := preload("res://scenes/ui/menu.tscn")

# Автозагрузка Game (секундомер и рекорды). Берём её по пути в дереве —
# так скрипт не зависит от того, успел ли редактор узнать имя Game
@onready var game: Node = get_node("/root/Game")
# Ссылки на узлы интерфейса. $ — «найди узел по этому пути в дереве»
@onready var battery_label: Label = $HUD/BatteryLabel
@onready var energy_bar: ProgressBar = $HUD/EnergyBar
@onready var message_label: Label = $HUD/MessageLabel
# Телепорт-выход (на уровне его может и не быть — тогда победа сразу после батареек)
@onready var exit_portal: Node = get_node_or_null("Exit")
# Строка с эффектом батарейки под полоской заряда (создаётся в _ready)
var effect_label: Label
# Секундомер и рекорд справа вверху (создаются в _ready)
var timer_label: Label
var record_label: Label
var pause_menu: CanvasLayer

func _ready() -> void:
	# Числа из Inspector уже применены — начинаем с полного заряда
	energy = max_energy
	Sound.play_music(music)
	# Считаем, сколько узлов с ярлыком "batteries" есть на уровне
	total = get_tree().get_nodes_in_group("batteries").size()
	energy_bar.max_value = max_energy
	message_label.text = ""
	update_hud()
	# Строка эффекта батарейки — создаём кодом, чтобы не править каждый уровень
	effect_label = Label.new()
	effect_label.position = Vector2(20, 108)
	effect_label.add_theme_font_size_override("font_size", 24)
	effect_label.add_theme_color_override("font_outline_color", Color.BLACK)
	effect_label.add_theme_constant_override("outline_size", 6)
	$HUD.add_child(effect_label)
	$Player.effects.changed.connect(_on_effect_changed)
	# Секундомер: время забега (или попытки, если уровень запущен из редактора)
	timer_label = make_corner_label(32, 16)
	record_label = make_corner_label(18, 58)
	game.level_started()
	update_timer()
	# Меню паузы: создаём кодом, чтобы не добавлять его в каждый уровень вручную
	pause_menu = MENU.instantiate()
	pause_menu.pause_mode = true
	add_child(pause_menu)
	# Чит включили на прошлом уровне — напоминаем, что он всё ещё работает
	if game.infinite_energy:
		show_message("Чит: бесконечный заряд ВКЛ (F3 — выключить)", 2.0)
	# Уровень без батареек — телепорт открыт сразу
	if total == 0 and exit_portal:
		exit_portal.set_active(true)

func _process(delta: float) -> void:
	update_timer()
	if game_over:
		# Игра закончена — ждём нажатия R
		if Input.is_action_just_pressed("restart"):
			if finished_run:
				game.start_run()
			else:
				get_tree().reload_current_scene()
		return

	# Заряд тает: каждую секунду минус drain_rate
	energy -= drain_rate * delta
	if game.infinite_energy:
		energy = max_energy
	energy_bar.value = energy
	if energy <= 0:
		Sound.play("game_over")
		end_game("Заряд кончился!\nНажми R, чтобы начать заново")

# Esc — меню паузы.
# Читы для тестов (с ними рекорд не засчитывается):
#   F2 — сразу перейти на следующий уровень
#   F3 — бесконечный заряд (включить / выключить)
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		pause_menu.open()
	elif event.keycode == KEY_F2 and next_level != "":
		game.cheat_used()
		get_tree().change_scene_to_file(next_level)
	elif event.keycode == KEY_F3:
		game.infinite_energy = not game.infinite_energy
		game.cheat_used()
		show_message("Чит: бесконечный заряд " + ("ВКЛ" if game.infinite_energy else "ВЫКЛ") + "\nРекорд не засчитается", 2.0)

# Сюда придёт сигнал от игрока
func _on_player_battery_collected() -> void:
	collected += 1
	# Подзаряжаемся, но не больше максимума
	energy = min(energy + battery_energy, max_energy)
	update_hud()
	if collected == total:
		if exit_portal == null:
			Sound.play("level_complete")
			end_game("Победа! Все батарейки собраны!\nНажми R, чтобы сыграть ещё")
			return
		# Все собраны — полный заряд на финальный рывок и включаем телепорт
		energy = max_energy
		update_hud()
		Sound.play("all_collected")
		exit_portal.set_active(true)
		show_message("Все батарейки собраны!\nБеги к телепорту!", 3.0)

# Сюда придёт сигнал от телепорта
func _on_exit_player_entered() -> void:
	if game_over:
		return
	Sound.play("level_complete")
	var level_record: bool = game.level_completed(scene_file_path)
	var level_line: String = "Время уровня: " + game.format_time(game.level_time)
	if level_record:
		level_line += " — рекорд уровня!"
	if next_level == "":
		victory = true
		var text: String = "Ты прошёл всю игру!\n" + level_line
		if game.run_active:
			finished_run = true
			var fair: bool = game.run_valid
			var run_record: bool = game.run_completed()
			text += "\nВремя всей игры: " + game.format_time(game.run_time)
			if run_record:
				text += " — НОВЫЙ РЕКОРД!"
			elif not fair:
				text += " (с читами рекорд не засчитывается)"
		end_game(text + "\nR — сыграть ещё раз, Esc — меню")
		return
	end_game("Уровень пройден!\n" + level_line)
	# Даём игроку порадоваться 2 секунды и грузим следующий уровень.
	# Таймер подключаем к функции, а не ждём через await: если игрок за эти
	# 2 секунды перезапустит уровень, старая сцена удалится вместе с подпиской.
	# false — пока открыто меню паузы, таймер стоит
	get_tree().create_timer(2.0, false).timeout.connect(_go_to_next_level)

func _go_to_next_level() -> void:
	get_tree().change_scene_to_file(next_level)

# Показать сообщение на несколько секунд
func show_message(text: String, seconds: float) -> void:
	message_label.text = text
	get_tree().create_timer(seconds).timeout.connect(_hide_message.bind(text))

# Убрать сообщение, если на экране всё ещё оно (а не, например, «Уровень пройден!»)
func _hide_message(text: String) -> void:
	if not game_over and message_label.text == text:
		message_label.text = ""

# Эффект батарейки изменился: показать множители и сколько секунд осталось
func _on_effect_changed(speed_mult: float, jump_mult: float, time_left: float) -> void:
	if time_left <= 0:
		effect_label.text = ""
		return
	effect_label.text = "Скорость ×%.2f    Прыжок ×%.2f    %d с" % [speed_mult, jump_mult, ceili(time_left)]
	effect_label.modulate = $Player.effects.color()

# Надпись в правом верхнем углу (секундомер и рекорд)
func make_corner_label(font_size: int, top: float) -> Label:
	var label := Label.new()
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.offset_left = -360
	label.offset_right = -20
	label.offset_top = top
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	$HUD.add_child(label)
	return label

# Секундомер: в забеге — общее время и рекорд игры, иначе — время уровня и его рекорд
func update_timer() -> void:
	if game.run_active or finished_run:
		timer_label.text = game.format_time(game.run_time)
		record_label.text = "Рекорд игры: " + game.format_time(game.best_run)
	else:
		timer_label.text = game.format_time(game.level_time)
		record_label.text = "Рекорд уровня: " + game.format_time(game.best_levels.get(scene_file_path, 0.0))

# Обновить надписи на экране
func update_hud() -> void:
	battery_label.text = "Батарейки: %d / %d" % [collected, total]
	energy_bar.value = energy

# Конец игры: показать сообщение и остановить игрока
func end_game(text: String) -> void:
	game_over = true
	message_label.text = text
	$Player.set_physics_process(false)

# Сюда придёт сигнал «игрока ударили»
func _on_player_hit() -> void:
	if game_over:
		return
	energy -= hit_damage
	update_hud()

# Сюда придёт сигнал «игрок упал»
func _on_player_fell() -> void:
	if game_over:
		return
	energy -= fall_damage
	update_hud()
