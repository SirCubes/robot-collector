extends Area3D

# Батут: подбрасывает робота высоко вверх.
# Высота подлёта ≈ launch_speed² / 20: 12 — около 7 м, 14 — около 10 м.

@export var launch_speed := 12.0

@onready var top: Node3D = $jump_pad.find_child("PadTop", true, false)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("launch"):
		body.launch(launch_speed)
		# Пружинка: сплющилась и отскочила обратно
		var tween := create_tween()
		tween.tween_property(top, "scale", Vector3(1.2, 0.3, 1.2), 0.06)
		tween.tween_property(top, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
