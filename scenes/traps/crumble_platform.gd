extends AnimatableBody3D

# Рассыпающаяся платформа: робот встал — она дрожит, потом падает,
# а через несколько секунд появляется на прежнем месте.

# Сколько секунд платформа дрожит перед падением
@export var shake_time := 0.7
# Через сколько секунд после падения она возвращается
@export var respawn_time := 3.0

enum State { IDLE, SHAKING, FALLING, GONE }

var state := State.IDLE
var timer := 0.0
var fall_speed := 0.0
var start_position: Vector3
var player: CharacterBody3D

@onready var model: Node3D = $crumble_platform
@onready var shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	start_position = position
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			if has_rider():
				state = State.SHAKING
				timer = shake_time
				Sound.play_at("crumble", global_position)
		State.SHAKING:
			# Дрожим: трясём только картинку, форма стоит на месте
			timer -= delta
			model.position = Vector3(randf_range(-0.05, 0.05), 0, randf_range(-0.05, 0.05))
			if timer <= 0:
				model.position = Vector3.ZERO
				state = State.FALLING
				timer = 1.5
				fall_speed = 0.0
		State.FALLING:
			# Падаем быстрее робота — он отрывается от платформы и летит сам
			fall_speed += 20.0 * delta
			position.y -= fall_speed * delta
			timer -= delta
			if timer <= 0:
				state = State.GONE
				timer = respawn_time
				visible = false
				shape.set_deferred("disabled", true)
		State.GONE:
			timer -= delta
			# Не появляемся прямо внутри робота — ждём, пока он отойдёт
			if timer <= 0 and not player_in_spot():
				position = start_position
				visible = true
				shape.set_deferred("disabled", false)
				state = State.IDLE
				model.scale = Vector3.ONE * 0.1
				create_tween().tween_property(model, "scale", Vector3.ONE, 0.3)

# Стоит ли робот на платформе
func has_rider() -> bool:
	if player == null or not player.is_on_floor():
		return false
	var local := to_local(player.global_position)
	return abs(local.x) < 1.6 and abs(local.z) < 1.6 and local.y > 0.0 and local.y < 1.0

# Находится ли робот там, где появится платформа
func player_in_spot() -> bool:
	if player == null:
		return false
	var spot: Vector3 = get_parent().to_global(start_position)
	var offset := player.global_position - spot
	return abs(offset.x) < 2.0 and abs(offset.z) < 2.0 and offset.y > -2.2 and offset.y < 0.5
