extends Node3D

# Главное меню. На фоне камера медленно облетает островок с роботом,
# батарейки крутятся и покачиваются. Кнопки и рекорды — в сцене Menu.

@export var music: AudioStream
# Скорость облёта камеры (радиан в секунду)
@export var orbit_speed := 0.12

@onready var pivot: Node3D = $CameraPivot
@onready var batteries: Node3D = $Batteries

var time := 0.0
# Исходная высота каждой батарейки — вокруг неё они покачиваются
var base_heights: Array[float] = []

func _ready() -> void:
	get_tree().paused = false
	Sound.play_music(music)
	for battery in batteries.get_children():
		base_heights.append(battery.position.y)

func _process(delta: float) -> void:
	time += delta
	pivot.rotation.y = wrapf(pivot.rotation.y + orbit_speed * delta, -PI, PI)
	for i in batteries.get_child_count():
		var battery: Node3D = batteries.get_child(i)
		battery.rotation.y = wrapf(battery.rotation.y + 2.0 * delta, -PI, PI)
		battery.position.y = base_heights[i] + sin(time * 2.0 + i) * 0.15
