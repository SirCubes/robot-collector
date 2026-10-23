extends Node3D

# Вертушка: длинная полосатая балка крутится вокруг столба на высоте колена.
# Через балку надо перепрыгивать в нужный момент.

# Скорость вращения в градусах в секунду (минус — в другую сторону)
@export var turn_speed := 90.0

@onready var pivot: Node3D = $Pivot

func _physics_process(delta: float) -> void:
	# Меняем угол, а не вызываем rotate_y() — так не копится погрешность
	pivot.rotation.y = wrapf(pivot.rotation.y + deg_to_rad(turn_speed) * delta, -PI, PI)

# Балка задела робота — отбрасываем его от центра
func _on_arm_body_entered(body: Node3D) -> void:
	if body.has_method("take_hit"):
		body.take_hit(pivot.global_position)
