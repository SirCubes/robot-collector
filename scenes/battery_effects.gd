extends Node3D

# Случайные эффекты батареек.
# Каждая батарейка на несколько секунд меняет скорость и силу прыжка робота.
# Чаще это бонус (зелёный — маленький, золотой — большой), изредка — помеха (красный).
# Этот узел создаёт сам робот (player.gd), ставить его на сцены не нужно.

# Сообщает интерфейсу: текущие множители и сколько секунд осталось (0 — эффект кончился)
signal changed(speed_mult: float, jump_mult: float, time_left: float)

# Сколько секунд держится эффект: карта маленькая, поэтому эффект — короткий рывок
@export var duration := 3.0
# Помеха проходит быстрее, чем бонус
@export var debuff_duration := 2.0
# Пределы множителей: x — самое слабое значение, y — самое сильное
@export var speed_range := Vector2(0.8, 1.45)
@export var jump_range := Vector2(0.95, 1.3)
# Шанс, что батарейка окажется помехой
@export var debuff_chance := 0.2

const COLOR_BIG := Color(1.0, 0.8, 0.15)
const COLOR_SMALL := Color(0.35, 1.0, 0.45)
const COLOR_DEBUFF := Color(1.0, 0.25, 0.2)

var speed_mult := 1.0
var jump_mult := 1.0
var time_left := 0.0
var kind := ""

var aura: CPUParticles3D
var camera: Camera3D
var base_fov := 75.0
var model: Node3D

func _ready() -> void:
	var player := get_parent()
	model = player.get_node("robot")
	camera = player.get_node("CameraArm/Camera3D")
	base_fov = camera.fov
	# Шлейф частиц, который тянется за роботом, пока действует эффект
	aura = make_particles(28, 0.9, false)
	aura.emitting = false
	add_child(aura)

func _process(delta: float) -> void:
	if time_left > 0:
		time_left -= delta
		if time_left <= 0:
			finish()
		else:
			changed.emit(speed_mult, jump_mult, time_left)
	# При ускорении камера чуть «расширяет взгляд» — так скорость ощущается сильнее
	var target_fov := base_fov + (speed_mult - 1.0) * 30.0
	camera.fov = lerpf(camera.fov, target_fov, 4.0 * delta)

# Бросаем «кубики»: какой эффект даст эта батарейка
func apply_random() -> void:
	var is_debuff := randf() < debuff_chance
	if is_debuff:
		speed_mult = snappedf(randf_range(speed_range.x, 0.95), 0.05)
		jump_mult = snappedf(randf_range(jump_range.x, 1.0), 0.05)
	else:
		# pow(..., 1.6): маленькие бонусы выпадают часто, большие — редко
		speed_mult = snappedf(lerpf(1.0, speed_range.y, pow(randf(), 1.6)), 0.05)
		jump_mult = snappedf(lerpf(1.0, jump_range.y, pow(randf(), 1.6)), 0.05)
		# Бонус должен ощущаться: хотя бы что-то заметно выросло
		if speed_mult < 1.1 and jump_mult < 1.1:
			if randf() < 0.5:
				speed_mult = 1.1
			else:
				jump_mult = 1.1
	time_left = debuff_duration if is_debuff else duration
	var score := power()
	if is_debuff:
		kind = "debuff"
	elif score >= 0.45:
		kind = "big"
	else:
		kind = "small"
	feedback(score)
	changed.emit(speed_mult, jump_mult, time_left)

# Насколько эффект «сильный»: больше нуля — бонус, меньше — помеха
func power() -> float:
	return (speed_mult - 1.0) + (jump_mult - 1.0) * 1.5

func color() -> Color:
	match kind:
		"big":
			return COLOR_BIG
		"debuff":
			return COLOR_DEBUFF
	return COLOR_SMALL

# Звук, частицы, «подпрыгивание» модели и надпись над роботом
func feedback(score: float) -> void:
	# Звук батарейки: чем сильнее бонус, тем выше тон
	Sound.play("battery", 0.02, clampf(1.0 + score * 0.5, 0.75, 1.35))
	match kind:
		"big":
			Sound.play("boost_big")
		"small":
			Sound.play("boost_small")
		"debuff":
			Sound.play("debuff")

	# Вспышка частиц
	var burst := make_particles(70 if kind == "big" else 36, 0.7, true)
	burst.color = color()
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(1.5).timeout.connect(burst.queue_free)

	# Шлейф на время эффекта
	aura.color = color()
	aura.amount = 40 if kind == "big" else 24
	aura.emitting = true

	# Модель «подпрыгивает» (бонус) или «сплющивается» (помеха)
	var tween := create_tween()
	if kind == "debuff":
		tween.tween_property(model, "scale", Vector3(1.15, 0.75, 1.15), 0.08)
	else:
		tween.tween_property(model, "scale", Vector3.ONE * (1.3 if kind == "big" else 1.15), 0.08)
	tween.tween_property(model, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Всплывающая надпись над роботом
	var label := Label3D.new()
	label.text = "Скорость ×%.2f\nПрыжок ×%.2f" % [speed_mult, jump_mult]
	label.modulate = color()
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.font_size = 56
	label.outline_size = 14
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0, 2.6, 0)
	add_child(label)
	var float_up := create_tween().set_parallel()
	float_up.tween_property(label, "position:y", 3.8, 1.4)
	float_up.tween_property(label, "modulate:a", 0.0, 1.4).set_delay(0.4)
	float_up.chain().tween_callback(label.queue_free)

# Эффект закончился — всё обратно как было
func finish() -> void:
	time_left = 0.0
	speed_mult = 1.0
	jump_mult = 1.0
	kind = ""
	aura.emitting = false
	Sound.play("effect_end")
	changed.emit(speed_mult, jump_mult, 0.0)

# Частицы-«искорки»: маленькие светящиеся квадратики, повёрнутые к камере
func make_particles(count: int, life: float, burst: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = count
	p.lifetime = life
	p.one_shot = burst
	p.explosiveness = 1.0 if burst else 0.0
	# Частицы остаются в мире, а не едут вместе с роботом — получается шлейф
	p.local_coords = false
	p.position = Vector3(0, 1.0, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.direction = Vector3.UP
	p.spread = 180.0 if burst else 35.0
	p.initial_velocity_min = 2.5 if burst else 0.3
	p.initial_velocity_max = 5.0 if burst else 1.0
	p.gravity = Vector3(0, -3.0, 0) if burst else Vector3(0, 0.6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.15, 0.15)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.mesh = mesh
	return p
