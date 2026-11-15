extends Area2D
class_name takelabel
@onready var label: Control = $Control
var jugador: Node2D = null

func _ready() -> void:
	label.hide()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func interact() -> void:
	pass

func _on_body_entered(body: Node2D) -> void:
	if "interactuable_actual" in body:
		jugador = body
		body.interactuable_actual = self
		label.show()

func _on_body_exited(body: Node2D) -> void:
	if body == jugador:
		if body.interactuable_actual == self:
			body.interactuable_actual = null
		jugador = null
		label.hide()
