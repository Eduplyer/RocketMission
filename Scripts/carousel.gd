extends Control

@export var separacion := 150.0
@export var escala_seleccionado := 1.0
@export var escala_inactivo := 0.7
@export var opacidad_inactivo := 0.45
@export var velocidad := 10.0


@export_group("Imágenes")
## Tamaño de letra adecuado para un RichTextLabel de 68x130 px
@export var tamano_fuente := 6
## Arrastra aquí tu imagen atlas de 96x32 con los 3 parches
@export var atlas_parches: Texture2D
## Arrastra aquí las 3 capturas individuales de GMAT en orden (0: Atlas, 1: Minerva, 2: Expedition)
@export var imagenes_gmat: Array[Texture2D] = []

@onready var contenedor: Control = $Centro
@onready var texto_descripcion: RichTextLabel = $Descripcion
@onready var visor_gmat: TextureRect = $imagenGmat

var indice := 0

var misiones := [
	{
		"nombre": "Project Atlas VII",
		"destino": "LEO - 10 Days",
		"pista": "Life support test before deep space.\n[b]Clues:[/b] Very low altitude, near-circular path. Look for fast, symmetrical waves peaking near the tropics (low tilt).",
		"objetivo_altitud": 255.0,
		"tolerancia_altitud": 120.0,
		"objetivo_inclinacion": 30.0,
		"tolerancia_inclinacion": 12.0,
		"objetivo_circularidad": 98.0,
		"tolerancia_circularidad": 20.0
	},
	{
		"nombre": "Project Minerva II",
		"destino": "Lunar Flyby - 9 Days",
		"pista": "Crewed loop around the Moon and back.\n[b]Clues:[/b] Extreme lunar distance apogee. Needs a heavily stretched, non-circular arc with moderate inclination.",
		"objetivo_altitud": 384000.0,
		"tolerancia_altitud": 70000.0,
		"objetivo_inclinacion": 28.5,
		"tolerancia_inclinacion": 15.0,
		"objetivo_circularidad": 5.0,
		"tolerancia_circularidad": 25.0
	},
	{
		"nombre": "Expedition I",
		"destino": "ISS Docking - 10 Days",
		"pista": "Crew transfer to the Space Station.\n[b]Clues:[/b] Match the ISS profile in the manual: low-mid altitude, 100% circular, with 2 wide waves covering mid-high latitudes.",
		"objetivo_altitud": 408.0,
		"tolerancia_altitud": 120.0,
		"objetivo_inclinacion": 51.6,
		"tolerancia_inclinacion": 12.0,
		"objetivo_circularidad": 100.0,
		"tolerancia_circularidad": 20.0
	}
]

func _ready() -> void:
	add_to_group("pantalla_missionselect")
	_configurar_ui()
	_configurar_parches_atlas()
	_actualizar_carrusel(1.0)
	_actualizar_info_mision()

func _configurar_ui() -> void:
	if texto_descripcion:
		texto_descripcion.bbcode_enabled = true
		texto_descripcion.scroll_active = true
		texto_descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto_descripcion.add_theme_font_size_override("normal_font_size", tamano_fuente)
		texto_descripcion.add_theme_font_size_override("bold_font_size", tamano_fuente)
		texto_descripcion.add_theme_font_size_override("italics_font_size", tamano_fuente)
		texto_descripcion.add_theme_font_size_override("bold_italics_font_size", tamano_fuente)
		texto_descripcion.add_theme_constant_override("line_separation", 1)
	
	if visor_gmat:
		visor_gmat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		visor_gmat.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if visor_gmat.size.x <= 1 or visor_gmat.size.y <= 1:
			push_warning("imagenGmat tiene tamaño 0x0. Dale un tamaño (ej. 64x36) en Transform -> Size.")
	
func _configurar_parches_atlas() -> void:
	if not atlas_parches:
		return
	var total := contenedor.get_child_count()
	for i in range(total):
		var tarjeta := contenedor.get_child(i)
		var icono := tarjeta.get_node_or_null("Icono") as TextureRect
		if icono:
			var atlas := AtlasTexture.new()
			atlas.atlas = atlas_parches
			atlas.region = Rect2(i * 32, 0, 32, 32)
			icono.texture = atlas

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
		var destino_x := (distancia * separacion) - (tarjeta.size.x / 2.0)
		var destino_y := -tarjeta.size.y / 2.0
		tarjeta.position = tarjeta.position.lerp(Vector2(destino_x, destino_y), peso)
		var es_actual := (i == indice)
		var escala_obj := escala_seleccionado if es_actual else escala_inactivo
		var alfa_obj := 1.0 if es_actual else opacidad_inactivo

		tarjeta.scale = tarjeta.scale.lerp(Vector2.ONE * escala_obj, peso)
		tarjeta.modulate.a = lerpf(tarjeta.modulate.a, alfa_obj, peso)
		tarjeta.z_index = 10 - abs(distancia)

func _on_left_pressed() -> void:
	if contenedor.get_child_count() > 0:
		indice = wrapi(indice - 1, 0, contenedor.get_child_count())
		_actualizar_info_mision()

func _on_right_pressed() -> void:
	if contenedor.get_child_count() > 0:
		indice = wrapi(indice + 1, 0, contenedor.get_child_count())
		_actualizar_info_mision()

func obtener_mapa_seleccionado() -> Control:
	if contenedor.get_child_count() == 0:
		return null
	return contenedor.get_child(indice)

func obtener_mision_seleccionada() -> Dictionary:
	if indice < misiones.size():
		return misiones[indice]
	return {}

func _actualizar_info_mision() -> void:
	if texto_descripcion and indice < misiones.size():
		var m: Dictionary = misiones[indice]
		texto_descripcion.text = "[b]%s[/b]\n[i]%s[/i]\n%s" % [m["nombre"], m["destino"], m["pista"]]
	
	if visor_gmat:
		if indice < imagenes_gmat.size() and imagenes_gmat[indice] != null:
			visor_gmat.texture = imagenes_gmat[indice]
			visor_gmat.show()
		else:
			visor_gmat.hide()

func _on_button_pressed() -> void:
	var elegida := obtener_mision_seleccionada()
	if not elegida.is_empty():
		if indice < imagenes_gmat.size() and imagenes_gmat[indice] != null:
			elegida["imagen_gmat"] = imagenes_gmat[indice]
		GmatManager.aceptar_mision(elegida)
		hide()
