extends Area3D

# Снаряд турели: летит по прямой, бьёт робота, исчезает при ударе о что угодно.

# Скорость и направление (задаёт турель при выстреле)
var velocity := Vector3.ZERO
# Кто выстрелил — в него снаряд не попадает
var shooter: Node = null
# Через сколько секунд снаряд исчезает сам
@export var lifetime := 4.0

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body == shooter:
		return
	if body.has_method("take_hit"):
		# Толкаем робота по направлению полёта снаряда
		body.take_hit(global_position - velocity.normalized())
	queue_free()
