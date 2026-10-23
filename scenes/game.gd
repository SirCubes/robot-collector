extends Node

# Секундомер забега и рекорды.
# Это автозагрузка (Project → Project Settings → Globals → Autoload, имя Game):
# живёт всю игру, поэтому время не сбрасывается, когда уровни меняются.
#
# «Забег» — прохождение всей игры с первого уровня (кнопка «Играть» в меню).
# Время идёт и во время перезапусков после проигрыша — как в настоящем спидране.
# Рекорд забега записывается, только если игру начали с меню и не включали читы.
# У каждого уровня есть и свой рекорд — лучшее время одной попытки.

# Уровни по порядку: путь к сцене и название для таблицы рекордов
const LEVELS := [
	["res://scenes/main.tscn", "Уровень 1 — Остров"],
	["res://scenes/level_2.tscn", "Уровень 2 — Башня"],
]
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

# Файл с рекордами (user:// — папка игры в AppData, она переживает обновления игры)
var save_path := "user://records.cfg"
# Тестовый бот выключает запись, чтобы не ставить «нечестных» рекордов
var save_records := true

var run_time := 0.0       # время всего забега
var level_time := 0.0     # время текущей попытки уровня
var timing := false       # идёт ли сейчас отсчёт
var run_active := false   # забег начат с меню (иначе — уровень запущен из редактора)
var run_valid := true     # в забеге не было читов
var level_valid := true   # в этой попытке уровня не было читов
# Чит F3: бесконечный заряд. Хранится здесь, поэтому действует на всех уровнях
var infinite_energy := false

var best_run := 0.0       # 0 — рекорда ещё нет
var best_levels := {}     # путь к уровню → лучшее время

func _ready() -> void:
	load_records()

func _process(delta: float) -> void:
	if timing:
		run_time += delta
		level_time += delta

# Кнопка «Играть»: новый забег с первого уровня
func start_run() -> void:
	run_time = 0.0
	run_active = true
	# Если чит так и остался включённым — забег сразу не засчитывается
	run_valid = not infinite_energy
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVELS[0][0])

# Вызывает уровень при старте (и при перезапуске после проигрыша)
func level_started() -> void:
	level_time = 0.0
	level_valid = not infinite_energy
	timing = true

# Включили чит — этот забег и эта попытка в рекорды не попадут
func cheat_used() -> void:
	run_valid = false
	level_valid = false

# Уровень пройден. Возвращает true, если это новый рекорд уровня
func level_completed(level_path: String) -> bool:
	timing = false
	if not level_valid:
		return false
	var best: float = best_levels.get(level_path, 0.0)
	if best == 0.0 or level_time < best:
		best_levels[level_path] = level_time
		save()
		return true
	return false

# Пройдена вся игра. Возвращает true, если это новый рекорд забега
func run_completed() -> bool:
	timing = false
	if not (run_active and run_valid):
		return false
	run_active = false
	if best_run == 0.0 or run_time < best_run:
		best_run = run_time
		save()
		return true
	return false

func go_to_menu() -> void:
	timing = false
	run_active = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)

# Красивая запись времени: 1:05.42
static func format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "—"
	var minutes := floori(seconds / 60.0)
	return "%d:%05.2f" % [minutes, seconds - minutes * 60]

# Текст для меню: рекорд забега и рекорды уровней
func records_text() -> String:
	var lines: PackedStringArray = []
	for level in LEVELS:
		lines.append("%s:  %s" % [level[1], format_time(best_levels.get(level[0], 0.0))])
	return "\n".join(lines)

func save() -> void:
	if not save_records:
		return
	var file := ConfigFile.new()
	file.set_value("records", "best_run", best_run)
	file.set_value("records", "best_levels", best_levels)
	file.save(save_path)

func load_records() -> void:
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	best_run = file.get_value("records", "best_run", 0.0)
	best_levels = file.get_value("records", "best_levels", {})
