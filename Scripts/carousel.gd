extends Control

@export var separacion := 95.0
@export var escala_seleccionado := 1.0
@export var escala_inactivo := 0.7
@export var opacidad_inactivo := 0.45
@export var velocidad := 10.0

@onready var contenedor: Control = $Centro
var indice := 0

func _ready() -> void:
	_actualizar_carrusel(1.0)

func _process(delta: float) -> void:
	_actualizar_carrusel(clamp(velocidad * delta, 0.0, 1.0))

func _actualizar_carrusel(peso: float) -> void:
	var total := contenedor.get_child_count()
	if total == 0:
		return

	for i in range(total):
		var tarjeta := contenedor.get_child(i) as Control
		if not tarjeta:
			continue

		var distancia := i - indice
		tarjeta.pivot_offset = tarjeta.size / 2.0

		# Posiciona cada tarjeta respecto al centro
		var destino_x := (distancia * separacion) - (tarjeta.size.x / 2.0)
		var destino_y := -tarjeta.size.y / 2.0
		tarjeta.position = tarjeta.position.lerp(Vector2(destino_x, destino_y), peso)

		# Escala y transparencia
		var es_actual := (i == indice)
		var escala_obj := escala_seleccionado if es_actual else escala_inactivo
		var alfa_obj := 1.0 if es_actual else opacidad_inactivo

		tarjeta.scale = tarjeta.scale.lerp(Vector2.ONE * escala_obj, peso)
		tarjeta.modulate.a = lerpf(tarjeta.modulate.a, alfa_obj, peso)
		tarjeta.z_index = 10 - abs(distancia)

func _on_left_pressed() -> void:
	if contenedor.get_child_count() > 0:
		indice = wrapi(indice - 1, 0, contenedor.get_child_count())

func _on_right_pressed() -> void:
	if contenedor.get_child_count() > 0:
		indice = wrapi(indice + 1, 0, contenedor.get_child_count())

func obtener_mapa_seleccionado() -> Control:
	if contenedor.get_child_count() == 0:
		return null
	return contenedor.get_child(indice)
