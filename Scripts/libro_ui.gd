extends CanvasLayer

var libro: TextureRect
var pagina_izq: RichTextLabel
var pagina_der: RichTextLabel

# Componente, probabilidad de falla (%)
var fallas := [
	["Paracaídas (no se abre o se enreda)", "20-25"],
	["Ignición (no enciende)", "15-20"],
	["Aletas (mal alineadas / inestable)", "10-15"],
	["Motor (retardo incorrecto)", "8-12"],
	["Ojiva y acople (separación)", "5-8"],
	["Guías de lanzamiento (fricción)", "4-6"],
	["Compartimento del motor (mal sujeto)", "3-5"],
	["Fuselaje y carga útil", "2-4"],
	["Motor (explosión / CATO)", "1-2"],
]

func _ready() -> void:
	layer = 10

	# El libro (la imagen)
	libro = TextureRect.new()
	libro.texture = load("res://Interactives/libro.png")
	libro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	libro.stretch_mode = TextureRect.STRETCH_SCALE
	libro.size = Vector2(900, 500)
	var ventana: Vector2 = get_viewport().get_visible_rect().size
	libro.position = (ventana - libro.size) / 2.0
	libro.visible = false
	add_child(libro)

	# Página izquierda
	pagina_izq = _crear_pagina(Vector2(90, 55))
	libro.add_child(pagina_izq)

	# Página derecha
	pagina_der = _crear_pagina(Vector2(500, 55))
	libro.add_child(pagina_der)

	_llenar_paginas()

func _crear_pagina(pos: Vector2) -> RichTextLabel:
	var p := RichTextLabel.new()
	p.bbcode_enabled = true
	p.position = pos
	p.size = Vector2(360, 380)
	p.add_theme_color_override("default_color", Color.BLACK)
	p.add_theme_font_size_override("normal_font_size", 16)
	p.add_theme_font_size_override("bold_font_size", 16)
	return p

func _llenar_paginas() -> void:
	var izq := "[b]LIBRO DE FALLAS DEL COHETE[/b]\n\n"
	for i in range(0, 5):
		izq += "• %s: [b]%s %%[/b]\n\n" % [fallas[i][0], fallas[i][1]]
	pagina_izq.text = izq

	var der := ""
	for i in range(5, fallas.size()):
		der += "• %s: [b]%s %%[/b]\n\n" % [fallas[i][0], fallas[i][1]]
	der += "[i]Probabilidades estimadas para la simulación.[/i]"
	pagina_der.text = der

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			libro.visible = not libro.visible
