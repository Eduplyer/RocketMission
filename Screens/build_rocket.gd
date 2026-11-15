extends Control
## Pantalla de ensamblaje de la NAVE (casillas fijas + pestañas + tooltip al pasar el mouse).
## Tú acomodas los botones en el editor; el script les pone datos, estilo y comportamiento.

const RUTA_JSON := "res://data/"   # clic derecho en tu carpeta > Copiar ruta
const ARCHIVOS := ["potencia", "actitud", "comunicaciones", "control_termico", "soporte_vital", "carga_util"]
# Orden de las pestañas: el 1.er botón de $Pestanas muestra la 1.ª categoría, y así sucesivamente.
const CATEGORIAS := ["potencia", "control_actitud", "comunicaciones", "control_termico", "soporte_vital", "carga_util"]
const COLUMNAS := 4
const TAM_CASILLA := Vector2(23, 23)
const TAM_PESTANA := Vector2(5, 10)

# true = el script pone colores y bordes a casillas y pestañas. false = usa el estilo que hiciste en el editor.
const ESTILO_POR_CODIGO := true
var colores_pestana := [Color("d8b8a8"), Color("b0bcd8"), Color("b0d8d0"), Color("d8a8c8"), Color("d8d0b0"), Color("a8d0e8")]

# Idioma de los textos de la interfaz ("en" o "es"). Los textos de las piezas salen del JSON que uses.
var idioma := "en"
const TXT := {
	"es": {"pieces": "Piezas", "mass": "Masa", "power": "Energía", "slots": "Espacios", "cost": "Costo",
		"err": "ERROR", "warn": "AVISO",
		"req": "%s requiere %s", "req_one": "%s requiere al menos uno de: %s",
		"incomp": "%s es incompatible con %s", "neg_power": "Balance de energía negativo (%d W)"},
	"en": {"pieces": "Parts", "mass": "Mass", "power": "Power", "slots": "Slots", "cost": "Cost",
		"err": "ERROR", "warn": "WARNING",
		"req": "%s requires %s", "req_one": "%s requires at least one of: %s",
		"incomp": "%s is incompatible with %s", "neg_power": "Negative power balance (%d W)"},
}
const NOMBRES_CATEGORIA := {
	"potencia": "Power", "control_actitud": "Attitude", "comunicaciones": "Comms",
	"control_termico": "Thermal", "soporte_vital": "Life support", "carga_util": "Payload",
}

# Rutas según tu árbol de escena. Si moviste algo: clic derecho en el nodo > Copiar ruta del nodo.
@onready var grid_piezas: GridContainer = get_node_or_null("PanelPersonaliza/GridPiezas")
@onready var pestanas: VBoxContainer = get_node_or_null("Pestanas")
@onready var label_resumen: Label = get_node_or_null("VBoxContainer/LabelResumen")

# Vendrán de la pantalla de misión (por ahora, valores de prueba).
var tipo_mision := "humana"   # "humana" o "robotica"
var aterrizaje := false

var piezas := {}                 # id -> datos de la pieza (todos los JSON juntos)
var seleccionadas := []          # ids de las piezas elegidas para la nave
var slots: Array[Button] = []    # las casillas que acomodaste en el editor
var ids_en_slots := []           # qué pieza muestra cada casilla ahora mismo

var tooltip: PanelContainer
var tt_titulo: Label
var tt_resumen: Label
var tt_stats: Label


func _ready() -> void:
	if not _nodos_ok():
		return
	cargar_datos_json()
	_crear_tooltip()
	grid_piezas.columns = COLUMNAS
	if label_resumen:
		label_resumen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label_resumen.custom_minimum_size = Vector2(200, 0)
		label_resumen.add_theme_font_size_override("font_size", 14)
	preparar_casillas()
	preparar_pestanas()
	mostrar_categoria(CATEGORIAS[0])
	actualizar_resumen()
	print("Ensamblaje listo -> piezas: %d | casillas: %d | pestañas: %d" % [piezas.size(), slots.size(), pestanas.get_child_count()])


func _process(_delta: float) -> void:
	if tooltip and tooltip.visible:
		_posicionar_tooltip()


func _s(clave: String) -> String:
	return TXT[idioma][clave]


# Avisa EXACTAMENTE qué nodo falta (antes un nodo faltante detenía todo en silencio).
func _nodos_ok() -> bool:
	var ok := true
	if grid_piezas == null:
		push_error("Falta el nodo 'PanelPersonaliza/GridPiezas' (GridContainer) dentro de UI_Ensamblaje.")
		ok = false
	if pestanas == null:
		push_error("Falta el nodo 'Pestanas' (VBoxContainer) dentro de UI_Ensamblaje.")
		ok = false
	if label_resumen == null:
		push_warning("Falta 'VBoxContainer/LabelResumen' (Label): no se mostrarán los totales.")
	return ok


# ---------- Carga de datos ----------

func cargar_datos_json() -> void:
	for nombre in ARCHIVOS:
		var ruta: String = RUTA_JSON + nombre + ".json"
		if not FileAccess.file_exists(ruta):
			push_warning("No se encontró el archivo: " + ruta)
			continue
		var datos = JSON.parse_string(FileAccess.get_file_as_string(ruta))
		if typeof(datos) != TYPE_DICTIONARY or not datos.has("partes"):
			push_warning("JSON inválido: " + ruta)
			continue
		for id in datos["partes"]:
			piezas[id] = datos["partes"][id]
	if piezas.is_empty():
		push_error("No se cargó ninguna pieza. Revisa RUTA_JSON: " + RUTA_JSON)


# ---------- Conexión con los botones que acomodaste ----------

# Un ColorRect/TextureRect hijo de un botón se come los clics (por defecto detiene el mouse).
# Aquí lo hacemos "transparente" al mouse para que el botón sí reciba el clic.
func _ignorar_mouse_en_hijos(boton: Button) -> void:
	for hijo in boton.get_children():
		if hijo is Control:
			hijo.mouse_filter = Control.MOUSE_FILTER_IGNORE


func preparar_casillas() -> void:
	for hijo in grid_piezas.get_children():
		var boton := hijo as Button
		if boton == null:
			continue
		boton.toggle_mode = true
		boton.focus_mode = Control.FOCUS_NONE
		boton.custom_minimum_size = TAM_CASILLA     # evita que el botón crezca con el texto
		boton.pivot_offset = TAM_CASILLA / 2.0      # para la animación al pasar el mouse
		boton.clip_text = true
		boton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		boton.expand_icon = true
		boton.add_theme_font_size_override("font_size", 3)
		_ignorar_mouse_en_hijos(boton)
		if ESTILO_POR_CODIGO:
			_estilo_casilla(boton)
		var i := slots.size()
		boton.pressed.connect(_on_casilla_presionada.bind(i))
		boton.mouse_entered.connect(_on_casilla_hover.bind(i))
		boton.mouse_exited.connect(_on_casilla_salida.bind(i))
		slots.append(boton)
	if slots.is_empty():
		push_error("GridPiezas no tiene botones (Button) como hijos.")


func preparar_pestanas() -> void:
	var grupo := ButtonGroup.new()   # la pestaña elegida queda resaltada
	var i := 0
	for hijo in pestanas.get_children():
		var boton := hijo as Button
		if boton == null or i >= CATEGORIAS.size():
			continue
		boton.toggle_mode = true
		boton.button_group = grupo
		boton.button_pressed = (i == 0)
		boton.focus_mode = Control.FOCUS_NONE
		boton.custom_minimum_size = TAM_PESTANA     # sin esto las pestañas se ven como rayitas
		boton.tooltip_text = NOMBRES_CATEGORIA[CATEGORIAS[i]]
		_ignorar_mouse_en_hijos(boton)
		if ESTILO_POR_CODIGO:
			_estilo_pestana(boton, colores_pestana[i])
		boton.pressed.connect(mostrar_categoria.bind(CATEGORIAS[i]))
		i += 1
	# Sin tripulación no hay soporte vital: se oculta su pestaña (la 5.ª).
	if pestanas.get_child_count() > 4:
		pestanas.get_child(4).visible = (tipo_mision == "humana")


# ---------- Estilos (solo si ESTILO_POR_CODIGO = true) ----------

# Casillas blancas con borde, como tu borrador; la elegida se pone verdosa.
func _estilo_casilla(boton: Button) -> void:
	var fondos := {"normal": Color("f4fdff"), "hover": Color("dff4f4"), "pressed": Color("9fd8d8"),
		"hover_pressed": Color("8cc9c9"), "disabled": Color("e6eef0")}
	for estado in fondos:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fondos[estado]
		sb.set_border_width_all(1)
		sb.border_color = Color("5b4a45") if estado.contains("pressed") else Color("a38f8f")
		sb.set_corner_radius_all(2)
		boton.add_theme_stylebox_override(estado, sb)
	boton.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		boton.add_theme_color_override(c, Color("2e2220"))
	boton.add_theme_color_override("font_disabled_color", Color("a8b4b6"))


# Pestañas de color, con borde grueso oscuro cuando están activas.
func _estilo_pestana(boton: Button, color: Color) -> void:
	for hijo in boton.get_children():
		if hijo is ColorRect:
			hijo.visible = false   # el color ahora lo pone el estilo del botón
	var fondos := {"normal": color, "hover": color.lightened(0.15), "pressed": color.lightened(0.3), "hover_pressed": color.lightened(0.3)}
	for estado in fondos:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fondos[estado]
		sb.set_border_width_all(1)
		sb.border_color = Color("4a3b38") if estado.contains("pressed") else Color("a38f8f")
		sb.corner_radius_top_left = 2
		sb.corner_radius_bottom_left = 2
		boton.add_theme_stylebox_override(estado, sb)
	boton.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


# Llena las casillas con las piezas de la categoría. Las sobrantes quedan vacías.
func mostrar_categoria(cat: String) -> void:
	tooltip.hide()
	ids_en_slots.clear()
	for id in piezas:
		var info: Dictionary = piezas[id]
		if info["categoria"] == cat and _aplica(info):
			ids_en_slots.append(id)
	if ids_en_slots.size() > slots.size():
		push_warning("'%s' tiene %d piezas pero solo hay %d casillas." % [cat, ids_en_slots.size(), slots.size()])

	for i in slots.size():
		var boton := slots[i]
		boton.scale = Vector2.ONE
		if i < ids_en_slots.size():
			var id: String = ids_en_slots[i]
			boton.disabled = false
			boton.set_pressed_no_signal(seleccionadas.has(id))
			var ruta_icono := "res://icons/%s.png" % id   # opcional: icono con el nombre del id
			if ResourceLoader.exists(ruta_icono):
				boton.icon = load(ruta_icono)
				boton.text = ""
			else:
				boton.icon = null
				boton.text = piezas[id]["nombre"]
		else:
			boton.text = ""
			boton.icon = null
			boton.disabled = true
			boton.set_pressed_no_signal(false)


# Oculta piezas que no corresponden a esta misión.
func _aplica(info: Dictionary) -> bool:
	var solo: String = info.get("solo_mision", "")
	if solo != "" and solo != tipo_mision:
		return false
	if info.get("requiere_aterrizaje", false) and not aterrizaje:
		return false
	return true


# ---------- Selección y hover ----------

func _on_casilla_presionada(i: int) -> void:
	if i >= ids_en_slots.size():
		return
	var id: String = ids_en_slots[i]
	if slots[i].button_pressed:
		if not seleccionadas.has(id):
			seleccionadas.append(id)
	else:
		seleccionadas.erase(id)
	actualizar_resumen()


func _on_casilla_hover(i: int) -> void:
	if i < ids_en_slots.size():
		_mostrar_tooltip(ids_en_slots[i])
		_animar(slots[i], 1.08)


func _on_casilla_salida(i: int) -> void:
	tooltip.hide()
	_animar(slots[i], 1.0)


# Pequeño "salto" visual al pasar el mouse.
func _animar(boton: Control, escala: float) -> void:
	var tw := create_tween()
	tw.tween_property(boton, "scale", Vector2(escala, escala), 0.08)


# ---------- Tooltip (se crea por código: no hay que armarlo en el editor) ----------

func _crear_tooltip() -> void:
	tooltip = PanelContainer.new()
	tooltip.top_level = true                      # flota por encima de todo, sin importar el contenedor
	tooltip.z_index = 22
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE   # que no robe el mouse y parpadee
	tooltip.custom_minimum_size = Vector2(40, 40)

	var estilo := StyleBoxFlat.new()              # marrón oscuro con borde claro
	estilo.bg_color = Color("2e2220")
	estilo.border_color = Color("d9b58a")
	estilo.set_border_width_all(2)
	estilo.set_content_margin_all(3)
	tooltip.add_theme_stylebox_override("panel", estilo)

	var caja := VBoxContainer.new()
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_child(caja)
	tt_titulo = _nueva_etiqueta(Color("ffe9b8"), 3)
	tt_resumen = _nueva_etiqueta(Color("f2e6d8"), 3)
	tt_stats = _nueva_etiqueta(Color("9fd8d8"), 3)
	caja.add_child(tt_titulo)
	caja.add_child(tt_resumen)
	caja.add_child(tt_stats)

	tooltip.hide()
	add_child(tooltip)


func _nueva_etiqueta(color: Color, tam: int) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", tam)
	return l


func _mostrar_tooltip(id: String) -> void:
	var p: Dictionary = piezas[id]
	tt_titulo.text = p["nombre"]
	tt_resumen.text = p.get("resumen", "")        # texto corto del JSON
	tt_resumen.visible = tt_resumen.text != ""
	var s := "%s | %s %d | %+d W | %s %d" % [_dinero(p["precio_juego"]), _s("mass"), int(p["masa"]), int(p["watts"]), _s("slots"), int(p["slots"])]
	if p["capacidad_wh"] > 0:
		s += " | %d Wh" % int(p["capacidad_wh"])
	tt_stats.text = s
	tooltip.reset_size()
	tooltip.show()
	_posicionar_tooltip()


# Junto al mouse, sin salirse de la pantalla.
func _posicionar_tooltip() -> void:
	var pantalla := get_viewport_rect().size
	var pos := get_global_mouse_position() + Vector2(16, 16)
	pos.x = clampf(pos.x, 0.0, maxf(0.0, pantalla.x - tooltip.size.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, pantalla.y - tooltip.size.y))
	tooltip.global_position = pos


func _dinero(v: float) -> String:
	if v >= 1000000.0:
		return "%.1fM cr" % (v / 1000000.0)
	return "%dk cr" % int(v / 1000.0)


func nombres(ids: Array) -> PackedStringArray:
	var r := PackedStringArray()
	for i in ids:
		r.append(piezas[i]["nombre"] if piezas.has(i) else str(i))
	return r


# ---------- Totales y reglas ----------

func actualizar_resumen() -> void:
	var masa := 0.0
	var watts := 0.0
	var slots_cofia := 0.0
	var precio := 0.0
	for id in seleccionadas:
		var p: Dictionary = piezas[id]
		masa += p["masa"]
		watts += p["watts"]
		slots_cofia += p["slots"]
		precio += p["precio_juego"]

	var t := "%s: %d | %s: %d | %s: %+d W | %s: %d | %s: %s\n" % [_s("pieces"), seleccionadas.size(), _s("mass"), int(masa), _s("power"), int(watts), _s("slots"), int(slots_cofia), _s("cost"), _dinero(precio)]
	var r := validar(seleccionadas)
	if watts < 0:
		r["errores"].append(_s("neg_power") % int(watts))
	for e in r["errores"]:
		t += _s("err") + ": " + e + "\n"
	for a in r["avisos"]:
		t += _s("warn") + ": " + a + "\n"
	if label_resumen:
		label_resumen.text = t


# Devuelve {"errores": [...], "avisos": [...]}.
# Los ids que no están en los JSON de la nave (ej. cofia_expandida) se validan en la etapa del cohete.
func validar(ids: Array) -> Dictionary:
	var errores := []
	var avisos := []
	for id in ids:
		var p: Dictionary = piezas[id]
		for r in p["requiere"]:
			if piezas.has(r) and not ids.has(r):
				errores.append(_s("req") % [p["nombre"], piezas[r]["nombre"]])
		if p["requiere_alguno_de"].size() > 0:
			var ok := false
			for a in p["requiere_alguno_de"]:
				if ids.has(a):
					ok = true
			if not ok:
				errores.append(_s("req_one") % [p["nombre"], ", ".join(nombres(p["requiere_alguno_de"]))])
		for i in p["incompatible"]:
			if ids.has(i):
				errores.append(_s("incomp") % [p["nombre"], piezas[i]["nombre"]])
		for pe in p["penalizaciones"]:
			var falta := false
			if pe.has("si_falta"):
				falta = not ids.has(pe["si_falta"])
			elif pe.has("si_falta_ninguno_de"):
				falta = true
				for x in pe["si_falta_ninguno_de"]:
					if ids.has(x):
						falta = false
			if falta:
				avisos.append("%s: %s" % [p["nombre"], String(pe["efecto"]).replace("_", " ")])
	return {"errores": errores, "avisos": avisos}
