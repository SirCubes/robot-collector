extends AnimatableBody3D

# Куда платформа уезжает от стартовой точки
@export var move_offset := Vector3(0, 0, -6)
# Сколько секунд занимает путь в одну сторону
@export var travel_time := 1.5
# Через сколько секунд после того, как робот встал, платформа трогается
@export var departure_delay := 0.3
# Если робот стоит ближе этого к пустой остановке — платформа едет за ним
@export var call_radius := 4.0

var start_position: Vector3
# Где платформа: 0 — у старта, 1 — у конца, между ними — в пути
var progress := 0.0
# Куда едем: 0 или 1
var target := 0.0
# Сколько секунд робот уже стоит на платформе
var wait_timer := 0.0
# Робот приехал на платформе и ещё не сошёл — обратно его не катаем
var arrived_with_rider := false
# Робот (ищем по группе "player")
var player: CharacterBody3D

func _ready() -> void:
	start_position = position
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if progress == target:
		wait_at_stop(delta)
	else:
		# Едем: progress ровно движется к цели
		progress = move_toward(progress, target, delta / travel_time)
		# smoothstep — плавный разгон в начале и торможение в конце
		position = start_position.lerp(start_position + move_offset, smoothstep(0.0, 1.0, progress))
		if progress == target:
			# Только что приехали на остановку
			arrived_with_rider = has_rider()
			wait_timer = 0.0

# Стоим на остановке и решаем, ехать ли
func wait_at_stop(delta: float) -> void:
	if not has_rider():
		arrived_with_rider = false
		wait_timer = 0.0
		# Робот ждёт у другой остановки — едем за ним
		if player_near(other_stop()):
			target = 1.0 - target
		return
	# Робот ещё не сошёл после поездки — ждём
	if arrived_with_rider:
		return
	# Робот только что встал — немного ждём и едем
	wait_timer += delta
	if wait_timer >= departure_delay:
		target = 1.0 - target

# Стоит ли робот на платформе
func has_rider() -> bool:
	if player == null or not player.is_on_floor():
		return false
	# Положение робота относительно центра платформы
	var local := to_local(player.global_position)
	return abs(local.x) < 1.6 and abs(local.z) < 1.6 and local.y > 0.0 and local.y < 1.0

# Противоположная остановка (там, где платформы сейчас нет)
func other_stop() -> Vector3:
	if target == 1.0:
		return start_position
	return start_position + move_offset

# Стоит ли робот на земле рядом с точкой
func player_near(point: Vector3) -> bool:
	if player == null or not player.is_on_floor():
		return false
	var world_point: Vector3 = get_parent().to_global(point)
	var offset := player.global_position - world_point
	return abs(offset.y) < 2.0 and Vector2(offset.x, offset.z).length() < call_radius
