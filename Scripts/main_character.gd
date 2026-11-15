extends CharacterBody2D
const SPEED = 300.0 # Para pixel art de 16x16, prueba valores entre 80.0 y 120.0 si lo sientes muy rápido
var interactuable_actual: takelabel = null
var ultima_direccion := "down"

@onready var libro: CanvasLayer = $GUI/Book
@onready var anim: AnimatedSprite2D = $Sprite2D

func _physics_process(delta: float) -> void:
	get_input()
	move_and_slide()
	actualizar_animacion()

func get_input() -> void:
	var direccion := Input.get_vector("Left", "Right", "Up", "Down")
	velocity = SPEED * direccion

	if direccion != Vector2.ZERO:
		if abs(direccion.x) > abs(direccion.y):
			ultima_direccion = "right" if direccion.x > 0 else "left"
		else:
			ultima_direccion = "down" if direccion.y > 0 else "up"

func actualizar_animacion() -> void:
	var estado := "walk" if velocity != Vector2.ZERO else "idle"
	var nombre_anim := "%s_%s" % [estado, ultima_direccion]

	if anim.sprite_frames and anim.sprite_frames.has_animation(nombre_anim):
		if anim.animation != nombre_anim:
			anim.play(nombre_anim)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Take") and interactuable_actual != null:
		interactuable_actual.interact()
	if event.is_action_pressed("book"):
		libro.visible = not libro.visible
