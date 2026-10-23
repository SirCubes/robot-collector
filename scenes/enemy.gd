extends Area3D

# @export — эти переменные видны в Inspector, у каждой копии врага свои
# Куда враг уезжает от стартовой точки
@export var move_offset := Vector3(6, 0, 0)
# Как быстро катается туда-обратно
@export var speed := 1.5

var start_position: Vector3
var time := 0.0

func _ready() -> void:
	start_position = position

func _process(delta: float) -> void:
	time += delta
	# Число t плавно ходит 0 → 1 → 0 → 1 ...
	var t := (1.0 - cos(time * speed)) / 2.0
	# Ставим врага в точку между стартом (t = 0) и концом пути (t = 1)
	position = start_position.lerp(start_position + move_offset, t)

# Кто-то врезался во врага
func _on_body_entered(body: Node3D) -> void:
	# Если это тело умеет получать удар — бьём его
	if body.has_method("take_hit"):
		body.take_hit(global_position)
