extends CharacterBody2D

const SPEED = 300.0
var interactuable_actual: takelabel = null
@onready var libro: CanvasLayer = $GUI/Book
func _physics_process(delta: float) -> void:
	get_input()
	move_and_slide()

func get_input():
	var direccion=Input.get_vector("Left","Right","Up","Down")
	if direccion != Vector2.ZERO:
		rotation = direccion.angle()
	velocity=SPEED*direccion
	

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Take") and interactuable_actual != null:
		interactuable_actual.interact()
	if event.is_action_pressed("book"):
		libro.visible=not libro.visible
