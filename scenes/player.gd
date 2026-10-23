extends CharacterBody3D

# Наш собственный сигнал: «я подобрал батарейку»
signal battery_collected
# Сигнал: «меня ударили»
signal hit
# Сигнал: «я упал с острова»
signal fell

# Скорость ходьбы (метров в секунду)
const SPEED = 5.0
# Сила прыжка: чем больше, тем выше прыжок
const JUMP_VELOCITY = 8.0
# С какой силой нас отбрасывает враг
const KNOCKBACK = 8.0
# Сколько секунд длится отбрасывание (в это время клавиши не работают)
const KNOCKBACK_TIME = 0.4
# Сколько секунд после удара робот неуязвим (и мигает) — чтобы не получать удары очередью
const INVULNERABLE_TIME = 1.2
# Какая доля скорости остаётся в кустах (0.4 = 40%)
const BUSH_SLOWDOWN = 0.4

# Чувствительность мыши
const MOUSE_SENSITIVITY = 0.003
# Пределы наклона камеры в градусах: -75 — почти сверху, -5 — почти сбоку
const CAMERA_PITCH_MIN = -75.0
const CAMERA_PITCH_MAX = -5.0
# Пределы приближения колёсиком (метры) и шаг одного щелчка
const CAMERA_ZOOM_MIN = 5.0
const CAMERA_ZOOM_MAX = 20.0
const CAMERA_ZOOM_STEP = 1.0

# Ниже этой высоты робот считается упавшим (на высоких уровнях можно опустить)
@export var fall_limit := -10.0

# Последняя точка, где робот уверенно стоял на земле — сюда возвращаемся после падения
var safe_position: Vector3
# Таймер отбрасывания: пока больше нуля — летим от врага
var knockback_timer := 0.0
# В скольких кустах сейчас стоим (кусты могут перекрываться)
var bushes_inside := 0
# Таймер неуязвимости после удара
var invulnerable_timer := 0.0

# Модель робота (узел robot внутри Player)
@onready var model: Node3D = $robot
# «Пружина» с камерой: вращаем её — камера летает вокруг робота
@onready var camera_arm: SpringArm3D = $CameraArm
# Случайные эффекты батареек (скорость и прыжок), создаётся в _ready
var effects: Node3D

# Вызывается один раз при старте
func _ready() -> void:
	safe_position = global_position
	effects = preload("res://scenes/battery_effects.gd").new()
	effects.name = "BatteryEffects"
	add_child(effects)
	# Пружина не должна «упираться» в самого робота
	camera_arm.add_excluded_object(get_rid())
	# Прячем курсор и захватываем мышь
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# Вызывается на каждое событие: движение мыши, клик, нажатие клавиши
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Мышь влево-вправо — камера по кругу, вверх-вниз — наклон
		camera_arm.rotation.y -= event.relative.x * MOUSE_SENSITIVITY
		camera_arm.rotation.x -= event.relative.y * MOUSE_SENSITIVITY
		camera_arm.rotation.x = clamp(camera_arm.rotation.x, deg_to_rad(CAMERA_PITCH_MIN), deg_to_rad(CAMERA_PITCH_MAX))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Колёсико вперёд — приближаем
			camera_arm.spring_length = max(camera_arm.spring_length - CAMERA_ZOOM_STEP, CAMERA_ZOOM_MIN)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Колёсико назад — отдаляем
			camera_arm.spring_length = min(camera_arm.spring_length + CAMERA_ZOOM_STEP, CAMERA_ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			# Клик по окну — снова захватываем мышь
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Esc открывает меню паузы (см. main.gd), а оно показывает курсор

# Вызывается 60 раз в секунду
func _physics_process(delta: float) -> void:
	# Если не стоим на полу — падаем вниз
	if not is_on_floor():
		velocity += get_gravity() * delta

	# После удара робот мигает, пока неуязвим
	if invulnerable_timer > 0:
		invulnerable_timer -= delta
		model.visible = invulnerable_timer <= 0 or fmod(invulnerable_timer, 0.2) > 0.1

	if knockback_timer > 0:
		# Нас отбрасывает: не слушаем клавиши, просто отсчитываем время
		knockback_timer -= delta
	else:
		# Прыжок: только если нажали пробел И стоим на земле
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY * effects.jump_mult
			Sound.play("jump")

		# Читаем клавиши ходьбы
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		# Поворачиваем направление вместе с камерой: W — всегда «от камеры»
		var direction := Vector3(input.x, 0, input.y).rotated(Vector3.UP, camera_arm.rotation.y)
		# Обычная скорость с учётом эффекта батарейки, а в кустах — медленнее
		var speed: float = SPEED * effects.speed_mult
		if bushes_inside > 0:
			speed *= BUSH_SLOWDOWN
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		# Поворачиваем робота лицом туда, куда едем
		if direction.length() > 0:
			var target_angle := atan2(direction.x, direction.z)
			model.rotation.y = lerp_angle(model.rotation.y, target_angle, 10.0 * delta)

	move_and_slide()

	# Стоим на твёрдой земле целиком — запоминаем точку
	if is_on_floor() and is_on_solid_ground():
		safe_position = global_position

	# Упали ниже острова — возвращаемся на последнюю безопасную точку
	if global_position.y < fall_limit:
		respawn()

# Вернуть игрока на последнюю безопасную точку
func respawn() -> void:
	global_position = safe_position
	velocity = Vector3.ZERO
	Sound.play("fall")
	fell.emit()

# Вызывается батарейкой, когда мы её подбираем
func collect_battery() -> void:
	# Звук и эффект батарейки выбирает battery_effects.gd
	effects.apply_random()
	battery_collected.emit()

# Вызывается врагом. from_position — где стоит враг
func take_hit(from_position: Vector3) -> void:
	# Пока летим от прошлого удара или мигаем после него — новые не считаются
	if knockback_timer > 0 or invulnerable_timer > 0:
		return
	invulnerable_timer = INVULNERABLE_TIME
	# Направление «от врага к нам», только по горизонтали
	var direction := global_position - from_position
	direction.y = 0
	# Удар пришёл точно снизу или сверху (шипы под ногами) — отталкиваем назад
	if direction.length() < 0.01:
		direction = -model.global_basis.z
		direction.y = 0
	direction = direction.normalized()
	# Толкаем в сторону от врага и чуть вверх
	velocity = direction * KNOCKBACK
	velocity.y = 5.0
	knockback_timer = KNOCKBACK_TIME
	Sound.play("hit")
	hit.emit()

# Вызывается батутом: подбросить робота вверх
func launch(speed: float) -> void:
	velocity.y = speed
	knockback_timer = 0.0
	Sound.play("launch")

# Вызываются кустом
func enter_bush() -> void:
	bushes_inside += 1

func exit_bush() -> void:
	bushes_inside -= 1

# Есть ли твёрдая земля под роботом со всех сторон (а не только под серединой)
func is_on_solid_ground() -> bool:
	var space := get_world_3d().direct_space_state
	var offsets := [Vector3(0.6, 0, 0), Vector3(-0.6, 0, 0), Vector3(0, 0, 0.6), Vector3(0, 0, -0.6)]
	for offset in offsets:
		# Луч сверху вниз: от чуть выше ног до чуть ниже ног
		var from: Vector3 = global_position + offset + Vector3.UP * 0.5
		var to: Vector3 = from + Vector3.DOWN * 1.0
		var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
		var result := space.intersect_ray(query)
		# Под этим краем пусто или там движущаяся платформа — точка ненадёжная
		if result.is_empty() or result.collider is AnimatableBody3D:
			return false
	return true
