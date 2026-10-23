extends Area3D

# Каждый кадр немного поворачиваемся вокруг вертикальной оси.
# Меняем угол, а не вызываем rotate_y(): rotate_y() за несколько минут копит
# погрешность, и батарейка «сплющивается» — физика начинает ругаться.
func _process(delta: float) -> void:
	rotation.y = wrapf(rotation.y + 2.0 * delta, -PI, PI)

# Сюда приходит сигнал: в зону вошло какое-то тело
func _on_body_entered(body: Node3D) -> void:
	# Если это тело умеет собирать батарейки — отдаём ему батарейку
	if body.has_method("collect_battery"):
		body.collect_battery()
		queue_free()
