extends Control

@export var separacion := 95.0
@export var escala_seleccionado := 1.0
@export var escala_inactivo := 0.7
@export var opacidad_inactivo := 0.45
@export var velocidad := 10.0

@export var tamano_letra := 8
@export var color_texto := Color.BLACK
@export var compacto := true

@onready var contenedor: Control = $Centro
@onready var texto_descripcion: RichTextLabel = $Descripcion

var indice := 0

var curriculums := [
	{
		"nombre": "Christina Hammock Koch",
		"cargo": "Mission Commander | NASA Astronaut",
		"perfil": "Engineer and scientist with experience in space instruments and extreme places. First woman to fly around the Moon.",
		"formacion": "BS in Electrical Engineering and Physics; MS in Electrical Engineering, NC State",
		"experiencia": [
			"NASA Astronaut since 2013",
			"Artemis II (2026): flew around the Moon",
			"ISS (2019 - 2020): 328 days in orbit"
		],
		"logros": [
			"Women's record: 328 days in one flight",
			"Took part in the first all-women spacewalks"
		]
	},
	{
		"nombre": "Victor J. Glover Jr.",
		"cargo": "Main Pilot | NASA Astronaut",
		"perfil": "Navy test pilot with about 4,000 flight hours. Piloted the first operational SpaceX Crew Dragon flight and Artemis II.",
		"formacion": "BS, Cal Poly; three master's degrees (flight test, systems, military art)",
		"experiencia": [
			"NASA Astronaut since 2013",
			"Pilot, Crew-1 to the ISS (2020 - 2021)",
			"Pilot, Artemis II (2026)"
		],
		"logros": [
			"4 spacewalks (26 h 7 min)",
			"First African American astronaut on a long ISS stay"
		]
	},
	{
		"nombre": "Jessica Watkins, Ph.D.",
		"cargo": "Planetary Science Specialist | NASA Astronaut",
		"perfil": "Planetary geologist from the Curiosity rover science team. Commanded SpaceX Crew-13 to the ISS.",
		"formacion": "PhD in Geology, UCLA; BS, Stanford University",
		"experiencia": [
			"NASA Astronaut since 2017",
			"Crew-4 (2022): 170 days on the ISS",
			"Commander, Crew-13 (2026)"
		],
		"logros": [
			"First Black woman on a long ISS mission",
			"Commanded an ISS mission on her second flight"
		]
	},
	{
		"nombre": "Michael Collins (1930 - 2021)",
		"cargo": "Orbital Operations Specialist | NASA Astronaut",
		"perfil": "Air Force test pilot, expert in orbit navigation and docking. Flew alone around the Moon during Apollo 11.",
		"formacion": "BS, U.S. Military Academy at West Point",
		"experiencia": [
			"NASA Astronaut (1963 - 1970)",
			"Gemini 10 (1966): two spacewalks and docking",
			"Apollo 11 (1969): Command Module pilot"
		],
		"logros": [
			"Key member of the first Moon landing",
			"Pioneer of spacewalks and docking"
		]
	}
]

func _ready() -> void:
	add_to_group("pantalla_curriculum")
	if contenedor.get_child_count() != curriculums.size():
		push_warning("Hay %d tarjetas y %d curriculums. Deben ser iguales." % [contenedor.get_child_count(), curriculums.size()])
	_configurar_letra()
	_actualizar_carrusel(1.0)
	_actualizar_ficha()

func _process(delta: float) -> void:
	_actualizar_carrusel(clamp(velocidad * delta, 0.0, 1.0))

func _configurar_letra() -> void:
	for nombre in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		texto_descripcion.add_theme_font_size_override(nombre, tamano_letra)
	texto_descripcion.add_theme_constant_override("line_separation", 0)
	texto_descripcion.add_theme_color_override("default_color", color_texto)

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
		_actualizar_ficha()

func _on_right_pressed() -> void:
	if contenedor.get_child_count() > 0:
		indice = wrapi(indice + 1, 0, contenedor.get_child_count())
		_actualizar_ficha()

func obtener_curriculum_seleccionado() -> Dictionary:
	if indice < curriculums.size():
		return curriculums[indice]
	return {}

func _actualizar_ficha() -> void:
	if texto_descripcion == null or indice >= curriculums.size():
		return
	texto_descripcion.text = _armar_texto(curriculums[indice])
	texto_descripcion.scroll_to_line(0)

func _armar_texto(c: Dictionary) -> String:
	var s := "\n" if compacto else "\n\n"
	var t := "[b]%s[/b]\n[i]%s[/i]%s" % [c["nombre"], c["cargo"], s]
	t += "[b]PROFILE[/b]\n%s%s" % [c["perfil"], s]
	t += "[b]EDUCATION[/b]\n%s%s" % [c["formacion"], s]
	t += "[b]EXPERIENCE[/b]\n%s%s" % [_lista(c["experiencia"]), s]
	t += "[b]ACHIEVEMENTS[/b]\n%s" % _lista(c["logros"])
	return t

func _lista(items: Array) -> String:
	var salida := ""
	for i in items:
		salida += "• %s\n" % i
	return salida.strip_edges()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		texto_descripcion.get_v_scroll_bar().value += 20
	elif event.is_action_pressed("ui_up"):
		texto_descripcion.get_v_scroll_bar().value -= 20
	elif event.is_action_pressed("ui_right"):
		_on_right_pressed()
	elif event.is_action_pressed("ui_left"):
		_on_left_pressed()
