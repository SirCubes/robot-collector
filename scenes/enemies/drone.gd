extends Area3D

# Дрон-охотник: висит у своего «гнезда», а заметив робота — летит за ним.
# Летает медленнее, чем ездит робот, поэтому от него можно убежать.
# После тарана отлетает домой и какое-то время «приходит в себя».

# На каком расстоянии дрон замечает робота
@export var detect_radius := 8.0
# На каком расстоянии теряет робота и возвращается домой
@export var lose_radius := 12.0
# Скорость полёта, метров в секунду (робот ездит 5)
@export var speed := 3.5
# Сколько секунд дрон не преследует после удара
@export var cooldown := 1.5

# Зона полёта: дрон охраняет только свой участок
# Дальше этого (по горизонтали) от гнезда не улетает
@export var leash_radius := 8.0
# Насколько может подняться или опуститься относительно гнезда
@export var height_range := 2.5
# Робота выше или ниже гнезда больше чем на столько — не замечает (другой этаж)
@export var floor_tolerance := 4.0

var home: Vector3
var chasing := false
var cooldown_timer := 0.0
var time := 0.0
var player: Node3D

@onready var model: Node3D = $drone
@onready var rotors: Array[Node] = [model.find_child("RotorL", true, false), model.find_child("RotorR", true, false)]

func _ready() -> void:
	home = global_position
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	time += delta
	# Винты крутятся, корпус слегка покачивается в воздухе
	for rotor in rotors:
		rotor.rotation.y = wrapf(rotor.rotation.y + 25.0 * delta, -PI, PI)
	model.position.y = sin(time * 3.0) * 0.12

	# Заметил или потерял робота (только если он на этом же этаже)
	if player:
		var distance := global_position.distance_to(player.global_position)
		var same_floor: bool = abs(player.global_position.y - home.y) < floor_tolerance
		if not chasing and same_floor and distance < detect_radius:
			chasing = true
			Sound.play_at("alert", global_position)
		elif chasing and (distance > lose_radius or not same_floor):
			chasing = false

	# Куда лететь: к роботу (на уровень его груди) или домой
	var target := home
	if cooldown_timer > 0:
		cooldown_timer -= delta
	elif chasing and player:
		target = clamp_to_zone(player.global_position + Vector3.UP * 1.2)

	global_position = global_position.move_toward(target, speed * delta)

	# Смотрим туда, куда летим
	var flat := Vector3(target.x, global_position.y, target.z)
	if global_position.distance_to(flat) > 0.1:
		look_at(flat, Vector3.UP)

# Не выпускаем точку за пределы зоны полёта вокруг гнезда
func clamp_to_zone(point: Vector3) -> Vector3:
	var offset := point - home
	var flat := Vector2(offset.x, offset.z).limit_length(leash_radius)
	return home + Vector3(flat.x, clamp(offset.y, -height_range, height_range), flat.y)

# Таран: бьём робота и отлетаем
func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_hit") and cooldown_timer <= 0:
		body.take_hit(global_position)
		cooldown_timer = cooldown
