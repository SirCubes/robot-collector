extends Area3D

# Сигнал: робот вошёл во включённый телепорт
signal player_entered

# Включён ли телепорт
var active := false

# Светящиеся части модели и лампа
@onready var glow: Node3D = $exit.find_child("Glow", true, false)
@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	# В начале уровня телепорт выключен
	set_active(false)

# Включить или выключить телепорт
func set_active(value: bool) -> void:
	active = value
	glow.visible = value
	light.visible = value
	# Робот уже стоит в телепорте в момент включения — сигнал «вошёл» не придёт сам
	if active:
		check_inside.call_deferred()

func check_inside() -> void:
	for body in get_overlapping_bodies():
		_on_body_entered(body)

# Кто-то вошёл в зону телепорта
func _on_body_entered(body: Node3D) -> void:
	if active and body.is_in_group("player"):
		player_entered.emit()
