extends Node

# Звуки и музыка всей игры.
# Это «автозагрузка» (Project → Project Settings → Globals → Autoload): Godot создаёт
# этот узел сам при запуске игры, и он живёт, пока игра открыта — даже когда уровни
# меняются. Поэтому из любого скрипта можно написать:
#   Sound.play("jump")                    — звук «в ушах» игрока
#   Sound.play_at("shoot", позиция)       — звук в точке мира (тише издалека)
#   Sound.play_music(трек)                — включить музыку (тот же трек не перезапускается)

const SOUNDS := {
	"jump": preload("res://audio/sfx/jump.wav"),
	"battery": preload("res://audio/sfx/battery.wav"),
	"hit": preload("res://audio/sfx/hit.wav"),
	"fall": preload("res://audio/sfx/fall.wav"),
	"launch": preload("res://audio/sfx/launch.wav"),
	"shoot": preload("res://audio/sfx/shoot.wav"),
	"crumble": preload("res://audio/sfx/crumble.wav"),
	"spikes": preload("res://audio/sfx/spikes.wav"),
	"alert": preload("res://audio/sfx/alert.wav"),
	"all_collected": preload("res://audio/sfx/all_collected.wav"),
	"level_complete": preload("res://audio/sfx/level_complete.wav"),
	"game_over": preload("res://audio/sfx/game_over.wav"),
	"boost_small": preload("res://audio/sfx/boost_small.wav"),
	"boost_big": preload("res://audio/sfx/boost_big.wav"),
	"debuff": preload("res://audio/sfx/debuff.wav"),
	"effect_end": preload("res://audio/sfx/effect_end.wav"),
}

# Громкость (в децибелах): 0 — как есть, минус — тише
@export var sfx_volume_db := -6.0
@export var music_volume_db := -14.0

# Сколько раз какой звук играл (удобно для проверки)
var played := {}

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	# Музыка продолжает играть и на паузе, и при смене уровня
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = music_volume_db
	add_child(music_player)
	# Трек закончился — начинаем заново (бесконечный повтор)
	music_player.finished.connect(music_player.play)
	# Несколько «динамиков», чтобы звуки не обрывали друг друга
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = sfx_volume_db
		add_child(p)
		sfx_players.append(p)

# base_pitch: 1 — как записано, больше — выше и «бодрее», меньше — ниже
func play(sound_name: String, pitch_variation := 0.05, base_pitch := 1.0) -> void:
	if not SOUNDS.has(sound_name):
		push_warning("Нет такого звука: " + sound_name)
		return
	played[sound_name] = played.get(sound_name, 0) + 1
	# Берём свободный динамик (или самый первый, если все заняты)
	var player: AudioStreamPlayer = sfx_players[0]
	for p in sfx_players:
		if not p.playing:
			player = p
			break
	player.stream = SOUNDS[sound_name]
	# Чуть-чуть меняем высоту — повторяющиеся звуки не звучат «как робот»
	player.pitch_scale = base_pitch * randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	player.play()

func play_at(sound_name: String, where: Vector3, max_distance := 20.0) -> void:
	if not SOUNDS.has(sound_name):
		push_warning("Нет такого звука: " + sound_name)
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	played[sound_name] = played.get(sound_name, 0) + 1
	# Временный 3D-динамик в нужной точке: удаляется сам, когда доиграет
	var p := AudioStreamPlayer3D.new()
	p.stream = SOUNDS[sound_name]
	p.volume_db = sfx_volume_db
	p.max_distance = max_distance
	p.pitch_scale = randf_range(0.95, 1.05)
	scene.add_child(p)
	p.global_position = where
	p.finished.connect(p.queue_free)
	p.play()

func play_music(track: AudioStream) -> void:
	if track == null:
		music_player.stop()
		return
	if music_player.stream == track and music_player.playing:
		return
	music_player.stream = track
	music_player.play()
