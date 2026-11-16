extends CanvasLayer

# 1. Orbital telemetry guides (Translated to English)
var orbitas := [
	{
		"tipo": "orbita",
		"nombre": "Low Equatorial Orbit (LEO)",
		"imagen": "res://Assets/Map1.png",
		"patron": "Flat horizontal line along the equator without rising or dipping toward the poles.",
		"rangos": "• [b]Altitude:[/b] 400 – 600 km\n• [b]Inclination:[/b] 0° – 5°\n• [b]Circularity:[/b] 95% – 100%",
		"tip": "If the ground track forms no waves and crosses the map quickly from left to right, it is a low equatorial orbit."
	},
	{
		"tipo": "orbita",
		"nombre": "Inclined Orbit (ISS Type)",
		"imagen": "res://Assets/Map2.png",
		"patron": "2 smooth, symmetrical waves rising and dipping halfway into each hemisphere.",
		"rangos": "• [b]Altitude:[/b] 380 – 450 km\n• [b]Inclination:[/b] 50° – 55°\n• [b]Circularity:[/b] 95% – 100%",
		"tip": "The maximum latitude reached by the wave's peak directly indicates the inclination angle in degrees."
	},
	{
		"tipo": "orbita",
		"nombre": "Polar / Sun-Synchronous Orbit",
		"imagen": "res://Assets/Map3.png",
		"patron": "3 steep waves reaching all the way to the top and bottom edges of the map.",
		"rangos": "• [b]Altitude:[/b] 700 – 900 km\n• [b]Inclination:[/b] 90° – 100°\n• [b]Circularity:[/b] 95% – 100%",
		"tip": "When curves touch both poles with multiple closely spaced passes, it is an Earth observation satellite."
	},
	{
		"tipo": "orbita",
		"nombre": "Geostationary Orbit (GEO)",
		"imagen": "res://Assets/Map4.png",
		"patron": "A single fixed dot (or tiny figure-eight) over the equator that does not move across the map.",
		"rangos": "• [b]Altitude:[/b] 35,500 – 36,000 km\n• [b]Inclination:[/b] 0° – 2°\n• [b]Circularity:[/b] 98% – 100%",
		"tip": "At this extreme height, one orbit takes 24 hours: it matches Earth's rotation and appears stationary."
	},
	{
		"tipo": "orbita",
		"nombre": "Highly Eccentric Orbit (Molniya / Transfer)",
		"imagen": "res://Assets/Map5.png",
		"patron": "Distorted, asymmetrical wave forming tight loops or a single elongated arc across the map.",
		"rangos": "• [b]Mean Altitude:[/b] 19,000 – 21,000 km\n• [b]Inclination:[/b] 60° – 65°\n• [b]Circularity:[/b] 5% – 30%",
		"tip": "If the wave loses its clean 'S' shape or stretches into a massive single arc, circularity is very low (elongated ellipse)."
	}
]

# 2. Rocket & mission failure guides (Translated to English)
var fallas := [
	{
		"nombre": "Parachute",
		"prob": "20-25",
		"causa": "Improper folding, tangled shroud lines, stuck nose cone, or burned thermal wadding.",
		"caso": "Soyuz 1 (1967): Parachutes failed to deploy properly during reentry.",
		"solucion": "Pack the parachute neatly, use heat-resistant wadding, ensure a loose nose cone fit, and ground-test deployment before launch."
	},
	{
		"nombre": "Ignition",
		"prob": "15-20",
		"causa": "Loose electrical contact, weak battery, or improperly seated igniter.",
		"caso": "Space Shuttle STS-41-D (1984): Launch aborted seconds before liftoff due to an engine ignition failure.",
		"solucion": "Inspect wiring, use a fully charged battery, seat the igniter deep inside the motor, and run a continuity check before countdown."
	},
	{
		"nombre": "Misaligned Fins",
		"prob": "10-15",
		"causa": "Warped fins, weak glue joints, or poorly balanced center of gravity.",
		"caso": "Common scale-rocketry failure: the vehicle spins or pitches off course.",
		"solucion": "Align fins using an alignment jig, reinforce fillets, and verify the center of gravity before flight."
	},
	{
		"nombre": "Wrong Motor Delay",
		"prob": "8-12",
		"causa": "Actual rocket mass does not match the selected motor, deploying the parachute too early or too late.",
		"caso": "Luna 25 (2023): Engine burned longer than planned, causing the probe to crash.",
		"solucion": "Weigh the fully assembled rocket before launch and select a motor with the proper ejection delay for that mass."
	},
	{
		"nombre": "Nose Cone & Coupling",
		"prob": "5-8",
		"causa": "Nose cone is either too loose (separates early) or too tight (fails to eject).",
		"caso": "Taurus XL (2009): Payload fairing failed to separate, resulting in mission loss.",
		"solucion": "Sand or tape the shoulder so it slides smoothly without wobble, and check altimeter vent holes."
	},
	{
		"nombre": "Launch Guides",
		"prob": "4-6",
		"causa": "Dirty, bent, or high-friction launch rod/rail that slows and deflects the rocket at liftoff.",
		"caso": "Typical launch-pad setup error in scale rocketry.",
		"solucion": "Clean the launch rail, verify vertical alignment, and check that lugs slide freely without binding."
	},
	{
		"nombre": "Loose Motor Mount",
		"prob": "3-5",
		"causa": "Missing thrust ring or retainer clip, allowing the motor to shift or eject out the back.",
		"caso": "Structural assembly failure inside the motor compartment.",
		"solucion": "Install a proper thrust block and positive motor retainer, confirming zero play before launch."
	},
	{
		"nombre": "Airframe & Payload",
		"prob": "2-4",
		"causa": "Damaged body tube, weak joints, or loose payload shifting the vehicle's balance.",
		"caso": "Apollo 6 (1968): Severe pogo oscillations damaged structural adapters.",
		"solucion": "Reinforce airframe couplers, secure all internal payloads, and inspect tubes for creases or cracks."
	},
	{
		"nombre": "Motor Explosion (CATO)",
		"prob": "1-2",
		"causa": "Cracked propellant grain or casing defect causing the motor to rupture upon ignition.",
		"caso": "Antares (2014): Exploded seconds after liftoff due to a suspected turbopump failure.",
		"solucion": "Inspect motors for cracks or moisture damage before use, discard defective units, and keep a safe distance."
	}
]

var paginas: Array = []
var indice := 0
var hoja_izq: Control
var hoja_der: Control
var texto_izq: RichTextLabel
var texto_der: RichTextLabel
var imagen_izq: TextureRect
var btn_prev: Button
var btn_next: Button

func _ready() -> void:
	layer = 10
	hoja_izq = find_child("Hoja_IZQ", true, false)
	hoja_der = find_child("Hoja_DER", true, false)
	if hoja_izq == null or hoja_der == null:
		push_error("Cannot find Hoja_IZQ or Hoja_DER. Check node names.")
		return

	# Page 0 is ALWAYS the active mission summary
	paginas.append({"tipo": "mision"})
	paginas.append_array(orbitas)
	for f in fallas:
		f["tipo"] = "falla"
		paginas.append(f)

	texto_izq = _crear_texto(hoja_izq)
	texto_der = _crear_texto(hoja_der)
	imagen_izq = _crear_imagen(hoja_izq)
	
	btn_prev = _crear_boton(hoja_izq, "◀ Prev", true)
	btn_next = _crear_boton(hoja_der, "Next ▶", false)
	btn_prev.pressed.connect(_anterior)
	btn_next.pressed.connect(_siguiente)

	# Refresh mission info every time the book is opened with Tab or a mission is accepted
	visibility_changed.connect(_on_visibility_changed)
	if GmatManager.has_signal("mision_aceptada"):
		GmatManager.mision_aceptada.connect(_on_mision_aceptada)

	visible = false
	_mostrar_pagina()

func _on_visibility_changed() -> void:
	if visible:
		_mostrar_pagina()

func _on_mision_aceptada(_mision: Dictionary) -> void:
	indice = 0
	_mostrar_pagina()

func _crear_texto(padre: Control) -> RichTextLabel:
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.scroll_active = false
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_theme_color_override("default_color", Color.WHITE)
	t.add_theme_font_size_override("normal_font_size", 4)
	t.add_theme_font_size_override("bold_font_size", 6)
	t.add_theme_font_size_override("italics_font_size", 4)
	t.add_theme_font_size_override("bold_italics_font_size", 6)
	padre.add_child(t)
	t.anchor_left = 0
	t.anchor_top = 0
	t.anchor_right = 1
	t.anchor_bottom = 1
	t.offset_left = 6
	t.offset_top = 6
	t.offset_right = -6
	t.offset_bottom = -24
	return t

func _crear_imagen(padre: Control) -> TextureRect:
	var img := TextureRect.new()
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(img)
	img.anchor_left = 0
	img.anchor_top = 0
	img.anchor_right = 1
	img.anchor_bottom = 1
	img.offset_left = 15
	img.offset_top = 60
	img.offset_right = -15
	img.offset_bottom = -24
	return img

func _crear_boton(padre: Control, texto: String, izquierda: bool) -> Button:
	var b := Button.new()
	b.text = texto
	b.add_theme_font_size_override("font_size", 8)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.15, 0.15, 0.2, 0.85)
	estilo.content_margin_left = 4
	estilo.content_margin_right = 4
	estilo.content_margin_top = 2
	estilo.content_margin_bottom = 2
	b.add_theme_stylebox_override("normal", estilo)
	
	padre.add_child(b)
	b.anchor_top = 1
	b.anchor_bottom = 1
	if izquierda:
		b.anchor_left = 0
		b.anchor_right = 0
		b.offset_left = 6
		b.offset_right = 70
	else:
		b.anchor_left = 1
		b.anchor_right = 1
		b.offset_left = -70
		b.offset_right = -6
	b.offset_top = -20
	b.offset_bottom = -4
	return b

func _mostrar_pagina() -> void:
	var item: Dictionary = paginas[indice]
	
	if item["tipo"] == "mision":
		var m: Dictionary = GmatManager.mision_actual
		
		if m.is_empty():
			imagen_izq.visible = false
			texto_izq.text = "[i]Flight Manual - Page 1[/i]\n\n[b]No Active Mission[/b]\n\nVisit the Mission Control terminal to select and accept an assignment."
			texto_der.text = "[b]Flight Checklist[/b]\n\n1. Accept a Mission\n2. Calibrate GMAT Orbit\n3. Build Vessel & Rocket\n4. Assign Crew\n5. Launch"
		else:
			# Hoja izquierda: Título y la imagen de la misión elegida
			var izq := "[i]Active Mission Briefing[/i]\n"
			izq += "[b]%s[/b]\n" % m.get("nombre", "Unknown Mission")
			izq += "[i]Target: %s[/i]" % m.get("destino", "Unknown")
			texto_izq.text = izq
			
			var tex_mision: Texture2D = m.get("imagen_gmat", null)
			if tex_mision != null:
				imagen_izq.texture = tex_mision
				imagen_izq.visible = true
			else:
				imagen_izq.visible = false
			
			# Hoja derecha: Pistas de la misión y telemetría actual
			var p: Dictionary = GmatManager.parametros_jugador
			var der := "%s\n\n" % m.get("pista", "")
			der += "[b]Current GMAT Telemetry[/b]\n"
			if p.is_empty():
				der += "Not calibrated yet. Compare the ground track on the left with the next pages."
			else:
				der += "• [b]Altitude:[/b] %.0f km\n" % p.get("altitud", 0.0)
				der += "• [b]Inclination:[/b] %.1f°\n" % p.get("inclination", 0.0)
				der += "• [b]Circularity:[/b] %d%%" % int(p.get("circularity", 0))
			texto_der.text = der

	elif item["tipo"] == "orbita":
		var num_orbita := indice
		var izq := "[i]Orbital Telemetry %d of %d[/i]\n" % [num_orbita, orbitas.size()]
		izq += "[b]%s[/b]" % item["nombre"]
		texto_izq.text = izq

		if ResourceLoader.exists(item["imagen"]):
			imagen_izq.texture = load(item["imagen"])
			imagen_izq.visible = true
		else:
			imagen_izq.visible = false
			texto_izq.text += "\n\n[i](Missing image: %s)[/i]" % item["imagen"]
			
		var der := "[b]Ground Track Pattern[/b]\n%s\n\n" % item["patron"]
		der += "[b]Approximate Ranges:[/b]\n%s\n\n" % item["rangos"]
		der += "[b]Reading Key:[/b]\n%s" % item["tip"]
		texto_der.text = der

	else:
		imagen_izq.visible = false
		var num_falla := indice - orbitas.size()
		var izq := "[i]Failure Guide %d of %d[/i]\n\n" % [num_falla, fallas.size()]
		izq += "[b]%s[/b]\n\n" % item["nombre"]
		izq += "[b]Failure Risk:[/b] %s %%\n\n" % item["prob"]
		izq += "[b]Root Cause:[/b]\n%s\n\n" % item["causa"]
		izq += "[b]Historical Case:[/b]\n%s" % item["caso"]
		texto_izq.text = izq
		
		var der := "[b]How to Prevent It[/b]\n\n%s" % item["solucion"]
		texto_der.text = der

	btn_prev.disabled = (indice == 0)
	btn_next.disabled = (indice == paginas.size() - 1)

func _siguiente() -> void:
	if indice < paginas.size() - 1:
		indice += 1
		_mostrar_pagina()

func _anterior() -> void:
	if indice > 0:
		indice -= 1
		_mostrar_pagina()
