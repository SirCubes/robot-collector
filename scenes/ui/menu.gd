extends CanvasLayer

# Меню игры. Одна сцена работает двумя способами:
#   главное меню (pause_mode выключен): «Играть», «Выход» и рекорды;
#   пауза по Esc (pause_mode включён): то же самое плюс «Продолжить»,
#   «Начать забег заново» и «Главное меню». Игра на это время замирает.

@export var pause_mode := false

# Автозагрузка Game (секундомер и рекорды)
@onready var game: Node = get_node("/root/Game")
@onready var dim: ColorRect = %Dim
@onready var center: CenterContainer = %Center
@onready var title: Label = %Title
@onready var subtitle: Label = %Subtitle
@onready var play_button: Button = %PlayButton
@onready var restart_button: Button = %RestartButton
@onready var menu_button: Button = %MenuButton
@onready var quit_button: Button = %QuitButton
@onready var best_run_label: Label = %BestRunLabel
@onready var levels_label: Label = %LevelsLabel
@onready var hint: Label = %Hint

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	restart_button.pressed.connect(game.start_run)
	menu_button.pressed.connect(game.go_to_menu)
	quit_button.pressed.connect(get_tree().quit)
	if pause_mode:
		# Меню паузы должно работать, когда всё остальное стоит
		process_mode = Node.PROCESS_MODE_ALWAYS
		title.text = "Пауза"
		subtitle.hide()
		play_button.text = "Продолжить"
		hide()
	else:
		# В главном меню панель слева, справа виден остров с роботом
		dim.hide()
		restart_button.hide()
		menu_button.hide()
		hint.hide()
		center.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		center.offset_right = 640
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		refresh()
		play_button.grab_focus()

func _process(_delta: float) -> void:
	if pause_mode and visible:
		hint.text = "Время забега: %s\nEsc — продолжить" % game.format_time(game.run_time)

# Показать меню паузы
func open() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()
	show()
	play_button.grab_focus()

# Спрятать меню паузы и продолжить игру
func close() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if pause_mode and visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func _on_play_pressed() -> void:
	if pause_mode:
		close()
	else:
		game.start_run()

# Обновить рекорды на экране
func refresh() -> void:
	best_run_label.text = game.format_time(game.best_run)
	levels_label.text = game.records_text()
