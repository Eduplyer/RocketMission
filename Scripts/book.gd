extends CanvasLayer

# Cada problema: nombre, probabilidad, causa, caso real y solución
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

var indice := 0
var hoja_izq: Control
var hoja_der: Control
var texto_izq: RichTextLabel
var texto_der: RichTextLabel
var btn_prev: Button
var btn_next: Button

func _ready() -> void:
	layer = 10
	hoja_izq = find_child("Hoja_IZQ", true, false)
	hoja_der = find_child("Hoja_DER", true, false)
	if hoja_izq == null or hoja_der == null:
		push_error("No encuentro Hoja_IZQ o Hoja_DER. Revisa los nombres.")
		return

	texto_izq = _crear_texto(hoja_izq)
	texto_der = _crear_texto(hoja_der)
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
	t.add_theme_font_size_override("normal_font_size", 18)
	t.add_theme_font_size_override("bold_font_size", 18)
	padre.add_child(t)
	t.anchor_left = 0
	t.anchor_top = 0
	t.anchor_right = 1
	t.anchor_bottom = 1
	t.offset_left = 15
	t.offset_top = 15
	t.offset_right = -15
	t.offset_bottom = -70
	return t

func _crear_boton(padre: Control, texto: String, izquierda: bool) -> Button:
	var b := Button.new()
	b.text = texto
	padre.add_child(b)
	b.anchor_top = 1
	b.anchor_bottom = 1
	if izquierda:
		b.anchor_left = 0
		b.anchor_right = 0
		b.offset_left = 15
		b.offset_right = 155
	else:
		b.anchor_left = 1
		b.anchor_right = 1
		b.offset_left = -155
		b.offset_right = -15
	b.offset_top = -50
	b.offset_bottom = -15
	return b

func _mostrar_pagina() -> void:
	var f: Dictionary = fallas[indice]

	var izq := "[i]Problema %d de %d[/i]\n\n" % [indice + 1, fallas.size()]
	izq += "[b]%s[/b]\n\n" % f["nombre"]
	izq += "[b]Probabilidad de falla:[/b] %s %%\n\n" % f["prob"]
	izq += "[b]¿Por qué pasa?[/b]\n%s\n\n" % f["causa"]
	izq += "[b]Caso real:[/b]\n%s" % f["caso"]
	texto_izq.text = izq

	var der := "[b]Cómo solucionarlo[/b]\n\n%s" % f["solucion"]
	texto_der.text = der

	btn_prev.disabled = (indice == 0)
	btn_next.disabled = (indice == fallas.size() - 1)

func _siguiente() -> void:
	if indice < fallas.size() - 1:
		indice += 1
		_mostrar_pagina()

func _anterior() -> void:
	if indice > 0:
		indice -= 1
		_mostrar_pagina()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			visible = not visible
		elif visible and event.keycode == KEY_RIGHT:
			_siguiente()
		elif visible and event.keycode == KEY_LEFT:
			_anterior()
