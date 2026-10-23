extends Area3D

# Кто-то въехал в куст
func _on_body_entered(body: Node3D) -> void:
	if body.has_method("enter_bush"):
		body.enter_bush()

# Кто-то выехал из куста
func _on_body_exited(body: Node3D) -> void:
	if body.has_method("exit_bush"):
		body.exit_bush()
