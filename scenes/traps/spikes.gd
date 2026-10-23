extends Area3D

# Шипы размером с клетку GridMap (2 x 2 м). Могут торчать всегда, а могут
# прятаться и выскакивать по таймеру. Перед тем как выскочить, они чуть
# «выглядывают» — игрок успевает заметить опасность.

# 0 — шипы торчат всегда; больше 0 — столько секунд торчат и столько же спрятаны
@export var interval := 0.0
# Сдвиг по времени: дай соседним шипам 0, 0.5, 1.0 — и они сработают «волной»
@export var time_offset := 0.0

# За сколько секунд до появления шипы начинают выглядывать
const WARNING_TIME := 0.5
const UP_Y := 0.0
const WARN_Y := -0.32
const DOWN_Y := -0.5

var time := 0.0
var up := true
var target_y := UP_Y

@onready var points: Node3D = $spikes.find_child("SpikesPoints", true, false)

func _physics_process(delta: float) -> void:
	if interval > 0:
		time += delta
		var phase := fmod(time + time_offset, interval * 2.0)
		var was_up := up
		up = phase < interval
		if up and not was_up:
			Sound.play_at("spikes", global_position, 14.0)
		var new_y := UP_Y if up else DOWN_Y
		if not up and phase > interval * 2.0 - WARNING_TIME:
			new_y = WARN_Y
		if new_y != target_y:
			target_y = new_y
			create_tween().tween_property(points, "position:y", target_y, 0.1)

	# Пока шипы торчат — ранят всех, кто на них стоит
	if up:
		for body in get_overlapping_bodies():
			if body.has_method("take_hit"):
				body.take_hit(global_position)
