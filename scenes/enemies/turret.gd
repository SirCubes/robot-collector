extends StaticBody3D

# Турель: стоит на месте, поворачивает голову к роботу и стреляет,
# когда видит его (между ними нет стен) и он достаточно близко.
# Снаряды летят медленно — от них можно увернуться или спрятаться за укрытием.

# На каком расстоянии турель стреляет
@export var fire_range := 12.0
# Секунд между выстрелами
@export var fire_interval := 2.0
# Как быстро голова поворачивается к роботу
@export var turn_speed := 3.0
# Скорость снаряда, метров в секунду
@export var projectile_speed := 7.0
# Упреждение: 0 — стреляет туда, где робот сейчас; 1 — туда, где он окажется,
# если не свернёт. Меньше 1 — от выстрела можно увернуться, резко сменив направление
@export var lead := 0.8

const PROJECTILE := preload("res://scenes/enemies/projectile.tscn")

var player: Node3D
var reload_timer := 0.0

@onready var head: Node3D = $turret.find_child("TurretHead", true, false)

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	reload_timer = fire_interval

func _physics_process(delta: float) -> void:
	if player == null:
		return
	reload_timer -= delta
	# Целимся в середину робота
	var aim_point := player.global_position + Vector3.UP * 1.0
	var to_player := aim_point - head.global_position
	if to_player.length() > fire_range or not can_see(aim_point):
		return

	# Целимся с упреждением: куда робот успеет доехать, пока летит снаряд
	var flight_time := to_player.length() / projectile_speed
	var player_velocity: Vector3 = player.velocity if "velocity" in player else Vector3.ZERO
	aim_point += Vector3(player_velocity.x, 0, player_velocity.z) * flight_time * lead
	to_player = aim_point - head.global_position

	# Плавно поворачиваем голову (вперёд у неё смотрит ось -Z)
	var target_yaw := atan2(-to_player.x, -to_player.z)
	head.rotation.y = lerp_angle(head.rotation.y, target_yaw - global_rotation.y, turn_speed * delta)

	# Стреляем, когда перезарядились и почти навелись
	if reload_timer <= 0 and abs(angle_difference(head.global_rotation.y, target_yaw)) < 0.3:
		reload_timer = fire_interval
		shoot(aim_point)

func shoot(aim_point: Vector3) -> void:
	var muzzle: Vector3 = head.global_transform * Vector3(0, 0, -0.95)
	var projectile := PROJECTILE.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = muzzle
	projectile.velocity = (aim_point - muzzle).normalized() * projectile_speed
	projectile.shooter = self
	Sound.play_at("shoot", muzzle)

# Видит ли турель точку: луч от головы не упирается ни во что, кроме робота
func can_see(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(head.global_position, point, collision_mask, [get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.collider == player
