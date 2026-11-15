extends CanvasLayer

# 1. Nuevas páginas iniciales: Guía visual de las 5 órbitas de GMAT
var orbitas := [
	{
		"tipo": "orbita",
		"nombre": "Órbita Ecuatorial Baja (LEO)",
		"imagen": "res://Assets/Map1.png", # <-- Cambia por la ruta de tu imagen
		"patron": "Línea horizontal plana sobre el ecuador sin subir ni bajar hacia los polos.",
		"rangos": "• [b]Altitud:[/b] 400 – 600 km\n• [b]Inclinación:[/b] 0° – 5°\n• [b]Circularidad:[/b] 95% – 100%",
		"tip": "Si la traza no forma ondas y cruza el mapa rápido de izquierda a derecha, estás ante una órbita baja y ecuatorial."
	},
	{
		"tipo": "orbita",
		"nombre": "Órbita Inclinada (Tipo ISS)",
		"imagen": "res://Assets/Map2.png",
		"patron": "2 ondas suaves y simétricas que suben y bajan hasta la mitad de cada hemisferio.",
		"rangos": "• [b]Altitud:[/b] 380 – 450 km\n• [b]Inclinación:[/b] 50° – 55°\n• [b]Circularidad:[/b] 95% – 100%",
		"tip": "La altura máxima que alcanza la cresta de la onda en el mapa te indica directamente los grados de inclinación."
	},
	{
		"tipo": "orbita",
		"nombre": "Órbita Polar / Heliosíncrona",
		"imagen": "res://Assets/Map3.png",
		"patron": "3 ondas muy pronunciadas que llegan hasta los bordes superior e inferior del mapa.",
		"rangos": "• [b]Altitud:[/b] 700 – 900 km\n• [b]Inclinación:[/b] 90° – 100°\n• [b]Circularidad:[/b] 95% – 100%",
		"tip": "Cuando las curvas tocan ambos polos y ves varias pasadas juntas, es un satélite de observación terrestre."
	},
	{
		"tipo": "orbita",
		"nombre": "Órbita Geoestacionaria (GEO)",
		"imagen": "res://Assets/Map4.png",
		"patron": "Un único punto fijo (o un trazo diminuto) sobre el ecuador que no avanza por el mapa.",
		"rangos": "• [b]Altitud:[/b] 35,500 – 36,000 km\n• [b]Inclinación:[/b] 0° – 2°\n• [b]Circularidad:[/b] 98% – 100%",
		"tip": "Al estar tan alto, tarda 24 horas en dar una vuelta: gira al mismo ritmo que la Tierra y parece inmóvil."
	},
	{
		"tipo": "orbita",
		"nombre": "Órbita Muy Excéntrica (Molniya)",
		"imagen": "res://Assets/Map5.png",
		"patron": "Onda deformada y asimétrica que forma bucles cerrados en la parte norte del mapa.",
		"rangos": "• [b]Altitud media:[/b] 19,000 – 21,000 km\n• [b]Inclinación:[/b] 60° – 65°\n• [b]Circularidad:[/b] 20% – 30%",
		"tip": "Si la onda pierde su forma de 'S' limpia y hace rizos en un extremo, la circularidad es muy baja (órbita alargada)."
	}
]

# 2. Tus páginas originales de fallas
var fallas := [
	{
		"nombre": "Paracaídas",
		"prob": "20-25",
		"causa": "Mal doblado, cuerdas enredadas, ojiva atorada o protección térmica quemada.",
		"caso": "Soyuz 1 (1967): los paracaídas fallaron en el regreso.",
		"solucion": "Doblar bien el paracaídas, usar protección contra el calor, revisar que la ojiva salga libre y probar la separación en tierra antes de lanzar."
	},
	{
		"nombre": "Ignición",
		"prob": "15-20",
		"causa": "Contacto eléctrico suelto, batería débil o encendedor mal colocado.",
		"caso": "Transbordador STS-41-D (1984): se canceló el despegue a segundos de salir por un fallo en el encendido de un motor.",
		"solucion": "Revisar el cableado, usar batería cargada, colocar bien el encendedor dentro del motor y probar la continuidad antes de la cuenta regresiva."
	},
	{
		"nombre": "Aletas mal alineadas",
		"prob": "10-15",
		"causa": "Aletas torcidas, mal pegadas o centro de gravedad mal ubicado.",
		"caso": "Error muy común en cohetes a escala: el cohete gira o se inclina.",
		"solucion": "Alinear las aletas con una guía, pegarlas firmes y comprobar el centro de gravedad antes del vuelo."
	},
	{
		"nombre": "Retardo del motor incorrecto",
		"prob": "8-12",
		"causa": "El peso real del cohete no coincide con el motor elegido, y el paracaídas sale tarde o muy pronto.",
		"caso": "Luna 25 (2023): el motor encendió más tiempo del planeado y la sonda se estrelló.",
		"solucion": "Pesar el cohete antes de lanzar y elegir el motor y el tiempo de retardo adecuados para ese peso."
	},
	{
		"nombre": "Ojiva y acople",
		"prob": "5-8",
		"causa": "La ojiva queda muy floja y se suelta, o muy apretada y no se separa.",
		"caso": "Taurus XL (2009): la cubierta no se separó y se perdió la misión.",
		"solucion": "Ajustar la ojiva para que quede firme pero deslice libre, y revisar los orificios de ventilación del altímetro."
	},
	{
		"nombre": "Guías de lanzamiento",
		"prob": "4-6",
		"causa": "Guía sucia, chueca o con fricción, que frena y desvía el cohete al salir.",
		"caso": "Error típico de montaje en cohetes a escala.",
		"solucion": "Limpiar la guía, ponerla bien vertical y comprobar que el cohete se deslice sin atorarse."
	},
	{
		"nombre": "Motor mal sujeto",
		"prob": "3-5",
		"causa": "El motor no tiene tope o retenedor y se mueve o sale disparado hacia atrás.",
		"caso": "Falla de armado en el compartimento del motor.",
		"solucion": "Colocar el tope y el retenedor del motor y verificar que no se mueva antes de lanzar."
	},
	{
		"nombre": "Fuselaje y carga útil",
		"prob": "2-4",
		"causa": "Tubo dañado, mal pegado, o carga suelta que cambia el equilibrio.",
		"caso": "Apolo 6 (1968): fuertes vibraciones dañaron la estructura del cohete.",
		"solucion": "Reforzar las uniones, fijar bien la carga útil y revisar que no haya grietas."
	},
	{
		"nombre": "Explosión del motor (CATO)",
		"prob": "1-2",
		"causa": "Motor con grietas o defectos que revienta al encenderse.",
		"caso": "Antares (2014): explotó a los pocos segundos del despegue, con probable falla en una turbobomba.",
		"solucion": "Revisar el motor antes de usarlo, no usar motores dañados y mantener distancia de seguridad."
	},
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
		push_error("No encuentro Hoja_IZQ o Hoja_DER. Revisa los nombres.")
		return

	# Unimos primero las órbitas y luego las fallas en un solo libro
	paginas.append_array(orbitas)
	for f in fallas:
		f["tipo"] = "falla"
		paginas.append(f)

	texto_izq = _crear_texto(hoja_izq)
	texto_der = _crear_texto(hoja_der)
	imagen_izq = _crear_imagen(hoja_izq)
	
	btn_prev = _crear_boton(hoja_izq, "◀ Anterior", true)
	btn_next = _crear_boton(hoja_der, "Siguiente ▶", false)
	btn_prev.pressed.connect(_anterior)
	btn_next.pressed.connect(_siguiente)

	visible = false
	_mostrar_pagina()

func _crear_texto(padre: Control) -> RichTextLabel:
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.scroll_active = false
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_theme_color_override("default_color", Color.WHITE)
	t.add_theme_font_size_override("normal_font_size", 4)
	t.add_theme_font_size_override("bold_font_size", 6)
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
	# Deja espacio arriba para el título y abajo para el botón "Anterior"
	img.offset_left = 15
	img.offset_top = 60
	img.offset_right = -15
	img.offset_bottom = -24
	return img

func _crear_boton(padre: Control, texto: String, izquierda: bool) -> Button:
	var b := Button.new()
	b.text = texto
	b.add_theme_font_size_override("font_size", 8)
	
	# Quita el relleno gigante por defecto de los botones en Godot
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
	# Ancho de 64 px y alto de 16 px (usa 85 px de ancho y 20 px de alto en 480x270)
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

	if item["tipo"] == "orbita":
		# Hoja izquierda: Título + captura de GMAT
		var izq := "[i]Telemetría Orbital %d de %d[/i]\n" % [indice + 1, orbitas.size()]
		izq += "[b]%s[/b]" % item["nombre"]
		texto_izq.text = izq

		if ResourceLoader.exists(item["imagen"]):
			imagen_izq.texture = load(item["imagen"])
			imagen_izq.visible = true
		else:
			imagen_izq.visible = false
			texto_izq.text += "\n\n[i](Falta asignar imagen: %s)[/i]" % item["imagen"]

		# Hoja derecha: Interpretación y rangos amigables
		var der := "[b]¿Cómo se ve el gráfico?[/b]\n%s\n\n" % item["patron"]
		der += "[b]Rangos aproximados:[/b]\n%s\n\n" % item["rangos"]
		der += "[b]Clave de lectura:[/b]\n%s" % item["tip"]
		texto_der.text = der

	else:
		# Hoja izquierda y derecha: Tu formato original de fallas
		imagen_izq.visible = false
		var num_falla := indice - orbitas.size() + 1

		var izq := "[i]Problema %d de %d[/i]\n\n" % [num_falla, fallas.size()]
		izq += "[b]%s[/b]\n\n" % item["nombre"]
		izq += "[b]Probabilidad de falla:[/b] %s %%\n\n" % item["prob"]
		izq += "[b]¿Por qué pasa?[/b]\n%s\n\n" % item["causa"]
		izq += "[b]Caso real:[/b]\n%s" % item["caso"]
		texto_izq.text = izq

		var der := "[b]Cómo solucionarlo[/b]\n\n%s" % item["solucion"]
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
