extends Control
## Pantalla de ensamblaje de la NAVE (casillas fijas + pestañas + tooltip al pasar el mouse).
## Incluye: bloqueo de piezas incompatibles, presupuesto, límites reales según cohete.json,
## barras de métricas y guardado de la nave en un JSON para la etapa del cohete.
## Conserva lo elegido en el autoload GameState: si vienes "atrás" desde el cohete, todo sigue cargado.
## Tú acomodas los botones en el editor; el script les pone datos, estilo y comportamiento.

# Se emite al pulsar "Construir", con el mismo diccionario que se guardó en RUTA_NAVE.
signal nave_construida(datos: Dictionary)

const RUTA_JSON := "res://data/"   # clic derecho en tu carpeta > Copiar ruta
const ARCHIVOS := ["potencia", "actitud", "comunicaciones", "control_termico", "soporte_vital", "carga_util"]
const ARCHIVO_COHETE := "cohete"   # res://data/cohete.json: de aquí salen los límites de masa y espacios
# Respaldo en disco (por si GameState no está registrado). user:// es la única carpeta donde un juego exportado puede escribir.
const RUTA_NAVE := "user://nave.json"

# Orden de las pestañas: el 1.er botón de $Pestanas muestra la 1.ª categoría, y así sucesivamente.
const CATEGORIAS := ["potencia", "control_actitud", "comunicaciones", "control_termico", "soporte_vital", "carga_util"]
const COLUMNAS := 4
const TAM_CASILLA := Vector2(23, 23)
const TAM_PESTANA := Vector2(5, 10)

# true = el script pone colores y bordes a casillas y pestañas. false = usa el estilo que hiciste en el editor.
const ESTILO_POR_CODIGO := true
var colores_pestana := [Color("d8b8a8"), Color("b0bcd8"), Color("b0d8d0"), Color("d8a8c8"), Color("d8d0b0"), Color("a8d0e8")]

# ---------- Presupuesto y métricas ----------

# Presupuesto TOTAL de la misión (nave + cohete). Son valores de prueba: cuando tengas missions.json,
# pásalo como 3.er parámetro de configurar_mision().
const PRESUPUESTO_MISION := {"robotica": 40000000.0, "humana": 60000000.0}

# true = el presupuesto de la nave ya descuenta el cohete más barato que la puede lanzar.
const RESERVAR_COHETE_EN_PRESUPUESTO := true
# true = una pieza que ya no cabe en el presupuesto se bloquea (no se puede elegir).
# false = se puede elegir y solo aparece el error en el resumen.
const BLOQUEAR_SI_EXCEDE_PRESUPUESTO := true

# Nombres de los nodos ProgressBar en tu escena (clave de métrica -> nombre del nodo).
const NOMBRES_BARRAS := {
	"masa": "BarMasa", "energia": "BarEnergia",
	"presupuesto": "BarPresupuesto", "combustible": "BarCombustible",
}
const COLOR_OK := Color("6bbf8a")      # menos de 80 %
const COLOR_CERCA := Color("e0b84c")   # 80 % o más
const COLOR_MAL := Color("d9645a")     # se pasó del límite

# Idioma de los textos de la interfaz ("en" o "es"). Los textos de las piezas salen del JSON que uses.
var idioma := "en"
const TXT := {
	"es": {"pieces": "Piezas", "mass": "Masa", "power": "Energía", "slots": "Espacios", "cost": "Costo",
		"err": "ERROR", "warn": "AVISO", "rocket": "Cohete mínimo",
		"req": "%s requiere %s", "req_one": "%s requiere al menos uno de: %s",
		"incomp": "%s es incompatible con %s", "neg_power": "Balance de energía negativo (%d W)",
		"over_budget": "Presupuesto excedido (%s / %s)",
		"no_rocket": "Ningún cohete puede lanzar esta nave (masa o espacios)",
		"blk_incomp": "Incompatible con %s", "blk_budget": "Sin presupuesto (faltan %s)",
		"blk_rocket": "Ningún cohete puede cargarla (masa o espacios)"},
	"en": {"pieces": "Parts", "mass": "Mass", "power": "Power", "slots": "Slots", "cost": "Cost",
		"err": "ERROR", "warn": "WARNING", "rocket": "Min. rocket",
		"req": "%s requires %s", "req_one": "%s requires at least one of: %s",
		"incomp": "%s is incompatible with %s", "neg_power": "Negative power balance (%d W)",
		"over_budget": "Budget exceeded (%s / %s)",
		"no_rocket": "No rocket can launch this ship (mass or slots)",
		"blk_incomp": "Incompatible with %s", "blk_budget": "Over budget (short by %s)",
		"blk_rocket": "No rocket can carry it (mass or slots)"},
}
const NOMBRES_CATEGORIA := {
	"potencia": "Power", "control_actitud": "Attitude", "comunicaciones": "Comms",
	"control_termico": "Thermal", "soporte_vital": "Life support", "carga_util": "Payload",
}

# Rutas según tu árbol de escena. Si moviste algo: clic derecho en el nodo > Copiar ruta del nodo.
@onready var grid_piezas: GridContainer = get_node_or_null("PanelPersonaliza/GridPiezas")
@onready var pestanas: VBoxContainer = get_node_or_null("Pestanas")
# LabelResumen se busca por nombre, esté donde esté en el árbol.
@onready var label_resumen: Label = find_child("LabelResumen", true, false) as Label

# Vendrán de la pantalla de misión (por ahora, valores de prueba).
var tipo_mision := "humana"   # "humana" o "robotica"
var aterrizaje := false
var presupuesto := 0.0        # presupuesto total de la misión actual

var estado = null                # el autoload GameState (null si no está registrado)
var piezas := {}                 # id -> datos de la pieza (todos los JSON de la nave juntos)
var cohete := {}                 # id -> datos de las piezas del cohete (cohete.json)
var combos_cohete := []          # todos los cohetes armables: {ids, nombre, cap, costo, extra, slots}
var unidad_masa := 1.0           # kg por unidad de masa (meta.unidad_masa_kg de los JSON)
var seleccionadas := []          # ids de las piezas elegidas para la nave
var slots: Array[Button] = []    # las casillas que acomodaste en el editor
var ids_en_slots := []           # qué pieza muestra cada casilla ahora mismo
var barras := {}                 # clave de métrica -> {"barra", "relleno", "texto"}
var boton_construir: Button

var tooltip: PanelContainer
var tt_titulo: Label
var tt_resumen: Label
var tt_stats: Label
var tt_aviso: Label              # motivo por el que una pieza está bloqueada


func _ready() -> void:
	if not _nodos_ok():
		return
	estado = get_node_or_null("/root/GameState")
	if estado == null:
		push_warning("El autoload 'GameState' no está registrado (Proyecto > Configuración > Autoload): la nave no se conservará al cambiar de escena.")
	cargar_datos_json()
	_crear_tooltip()
	grid_piezas.columns = COLUMNAS
	if label_resumen:
		label_resumen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label_resumen.custom_minimum_size = Vector2(200, 0)
		label_resumen.add_theme_font_size_override("font_size", 14)
	preparar_casillas()
	preparar_pestanas()
	preparar_barras()
	preparar_boton_construir()
	# Si el jugador ya había elegido piezas (y volvió "atrás"), se recuperan; si no, empieza de cero.
	if not _restaurar_borrador():
		configurar_mision(tipo_mision, aterrizaje)
	print("Ensamblaje listo -> piezas: %d | elegidas: %d | cohetes posibles: %d | casillas: %d | pestañas: %d" % [piezas.size(), seleccionadas.size(), combos_cohete.size(), slots.size(), pestanas.get_child_count()])


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
		push_warning("Falta un Label llamado 'LabelResumen': no se mostrarán los errores y avisos.")
	return ok


# Llamar desde la pantalla de misión para EMPEZAR una misión nueva: define el presupuesto,
# vacía la selección y borra lo guardado de la partida anterior.
# presupuesto_total <= 0 usa el valor de prueba de PRESUPUESTO_MISION.
func configurar_mision(tipo: String, aterriza: bool, presupuesto_total: float = -1.0) -> void:
	tipo_mision = tipo
	aterrizaje = aterriza
	if presupuesto_total > 0.0:
		presupuesto = presupuesto_total
	else:
		presupuesto = float(PRESUPUESTO_MISION.get(tipo, 40000000.0))
	seleccionadas.clear()
	if estado:
		estado.reiniciar()
	_guardar_borrador()
	_refrescar_interfaz()


# Repinta pestañas, casillas, barras y resumen con lo que haya en `seleccionadas`.
func _refrescar_interfaz() -> void:
	# Sin tripulación no hay soporte vital: se oculta su pestaña (la 5.ª).
	if pestanas.get_child_count() > 4:
		pestanas.get_child(4).visible = (tipo_mision == "humana")
	var primera := pestanas.get_child(0) as Button
	if primera:
		primera.set_pressed_no_signal(true)
	mostrar_categoria(CATEGORIAS[0])
	actualizar_resumen()


# ---------- Conservar lo elegido entre escenas ----------

# Guarda en GameState lo que el jugador lleva elegido (se llama en cada cambio).
func _guardar_borrador() -> void:
	if estado:
		estado.guardar_borrador_nave(tipo_mision, aterrizaje, presupuesto, seleccionadas)


# Si GameState tiene un borrador, lo vuelve a poner. Devuelve false si no había nada que recuperar.
func _restaurar_borrador() -> bool:
	if estado == null or not estado.tiene_borrador_nave():
		return false
	var b: Dictionary = estado.borrador_nave
	tipo_mision = String(b.get("tipo_mision", tipo_mision))
	aterrizaje = bool(b.get("aterrizaje", aterrizaje))
	presupuesto = float(b.get("presupuesto", PRESUPUESTO_MISION.get(tipo_mision, 40000000.0)))
	seleccionadas.clear()
	for id in b.get("piezas", []):
		if piezas.has(id):          # ignora piezas que ya no existan en los JSON
			seleccionadas.append(id)
	_refrescar_interfaz()
	print("Nave recuperada: %d piezas" % seleccionadas.size())
	return true


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
		if datos.has("meta"):
			unidad_masa = float(datos["meta"].get("unidad_masa_kg", unidad_masa))
		for id in datos["partes"]:
			piezas[id] = datos["partes"][id]
	if piezas.is_empty():
		push_error("No se cargó ninguna pieza. Revisa RUTA_JSON: " + RUTA_JSON)

	var ruta_cohete: String = RUTA_JSON + ARCHIVO_COHETE + ".json"
	if FileAccess.file_exists(ruta_cohete):
		var dc = JSON.parse_string(FileAccess.get_file_as_string(ruta_cohete))
		if typeof(dc) == TYPE_DICTIONARY and dc.has("partes"):
			cohete = dc["partes"]
	if cohete.is_empty():
		push_error("No se cargó cohete.json: no se pueden calcular los límites de masa y espacios. Revisa " + ruta_cohete)
	_preparar_cohetes()


# ---------- Cohete: qué se puede lanzar ----------
# Reglas (de cohete.json): 1 cofia + 1 motor + el tanque que ese motor requiere + 1 computadora.
# Los boosters son opcionales. Se bloquea el lanzamiento si la carga pesa más que la capacidad
# o si los espacios usados superan los de la cofia.

func _ids_cohete(sub: String) -> Array:
	var r := []
	for id in cohete:
		if cohete[id].get("subcategoria", "") == sub:
			r.append(id)
	return r


func _nombre_corto(id: String) -> String:
	return String(cohete[id]["nombre"]).split(" (")[0]


# Arma una sola vez todas las combinaciones de cohete posibles y calcula su capacidad y costo.
func _preparar_cohetes() -> void:
	combos_cohete.clear()
	if cohete.is_empty():
		return
	var computadora := ""   # se usa la más barata; la elección real se hace en la etapa del cohete
	for id in _ids_cohete("avionica"):
		if computadora == "" or cohete[id]["precio_juego"] < cohete[computadora]["precio_juego"]:
			computadora = id
	var boosters := [""] + _ids_cohete("booster")   # "" = sin boosters
	for f in _ids_cohete("cofia"):
		for m in _ids_cohete("motor"):
			for b in boosters:
				var ids := [f, m]
				ids.append_array(cohete[m].get("requiere", []))   # el tanque del motor
				var nombre := "%s + %s" % [_nombre_corto(f), _nombre_corto(m)]
				if b != "":
					ids.append(b)
					nombre += " + " + _nombre_corto(b)
				if computadora != "":
					ids.append(computadora)
				var cap := 0.0     # capacidad de carga (motores + boosters + ajuste de la cofia)
				var costo := 0.0
				var extra := 0.0   # masa del propio cohete que cuenta como carga (cofia, amortiguadores)
				for id in ids:
					var q: Dictionary = cohete[id]
					cap += float(q.get("aporta_capacidad_masa", 0.0)) + float(q.get("ajuste_capacidad_masa", 0.0))
					costo += float(q["precio_juego"])
					if q.get("masa_cuenta_como_carga", true):
						extra += float(q["masa"])
				combos_cohete.append({"ids": ids, "nombre": nombre, "cap": cap, "costo": costo, "extra": extra,
					"slots": float(cohete[f].get("capacidad_slots", 0.0))})


# Masa, espacios y precio de una lista de piezas, y qué piezas del cohete exigen (ej. cofia_expandida).
func _carga_de(ids: Array) -> Dictionary:
	var c := {"masa": 0.0, "slots": 0.0, "precio": 0.0, "req_cohete": []}
	for id in ids:
		var p: Dictionary = piezas[id]
		c["masa"] += float(p["masa"])
		c["slots"] += float(p["slots"])
		c["precio"] += float(p["precio_juego"])
		for r in p.get("requiere", []):
			if cohete.has(r) and not c["req_cohete"].has(r):
				c["req_cohete"].append(r)
	return c


# Cohete más barato que puede lanzar esa carga.
# Devuelve {"ok", "costo", "cap", "carga", "nombre", "ids", "max_masa"}; max_masa = lo más pesada que
# podría ser la nave con el cohete más potente que respeta sus espacios y requisitos (-1 si no hay ninguno).
func _mejor_cohete(carga: Dictionary) -> Dictionary:
	if combos_cohete.is_empty():
		return {"ok": true, "costo": 0.0, "cap": 0.0, "carga": carga["masa"], "nombre": "—", "ids": [], "max_masa": 0.0}
	var mejor := {}
	var max_masa := -1.0
	for c in combos_cohete:
		if carga["slots"] > c["slots"]:
			continue
		var falta_req := false
		for r in carga["req_cohete"]:
			if not c["ids"].has(r):
				falta_req = true
		if falta_req:
			continue
		max_masa = maxf(max_masa, c["cap"] - c["extra"])
		var total: float = carga["masa"] + c["extra"]
		if total > c["cap"]:
			continue
		if mejor.is_empty() or c["costo"] < mejor["costo"]:
			mejor = {"ok": true, "costo": c["costo"], "cap": c["cap"], "carga": total, "nombre": c["nombre"], "ids": c["ids"]}
	if mejor.is_empty():
		mejor = {"ok": false, "costo": 0.0, "cap": 0.0, "carga": carga["masa"], "nombre": "—", "ids": []}
	mejor["max_masa"] = max_masa
	return mejor


func _kg(unidades: float) -> int:
	return roundi(unidades * unidad_masa)


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


# Busca los 4 ProgressBar por nombre y les pone un relleno de color + un texto "usado / máximo".
func preparar_barras() -> void:
	for clave in NOMBRES_BARRAS:
		var nombre_nodo: String = NOMBRES_BARRAS[clave]
		var barra := find_child(nombre_nodo, true, false) as ProgressBar
		if barra == null:
			push_warning("Falta un ProgressBar llamado '%s' (métrica: %s)." % [nombre_nodo, clave])
			continue
		barra.min_value = 0.0
		barra.max_value = 100.0
		barra.value = 0.0
		barra.show_percentage = false      # el texto lo ponemos nosotros (usado / máximo)

		var relleno := StyleBoxFlat.new()
		relleno.bg_color = COLOR_OK
		relleno.set_corner_radius_all(8)
		barra.add_theme_stylebox_override("fill", relleno)

		var texto := Label.new()
		barra.add_child(texto)
		texto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Mismo tipo de letra y color que ya tenía el porcentaje de tu barra.
		texto.add_theme_font_override("font", barra.get_theme_font("font"))
		texto.add_theme_font_size_override("font_size", barra.get_theme_font_size("font_size"))
		texto.add_theme_color_override("font_color", barra.get_theme_color("font_color"))
		texto.add_theme_color_override("font_outline_color", Color("2e2220"))
		texto.add_theme_constant_override("outline_size", 1)

		barras[clave] = {"barra": barra, "relleno": relleno, "texto": texto}


func preparar_boton_construir() -> void:
	boton_construir = find_child("BotonSiguiente", true, false) as Button
	if boton_construir == null:
		push_warning("Falta el nodo 'BotonSiguiente' para poder avanzar.")
		return
	
	boton_construir.pressed.connect(_on_siguiente)
	
	# Usar tu tooltip actual (el oscuro) al pasar el ratón por el botón
	boton_construir.mouse_entered.connect(_on_boton_siguiente_hover)
	boton_construir.mouse_exited.connect(func(): tooltip.hide())


# Esta función se ejecuta cuando el jugador HACE CLIC en "Siguiente"
func _on_siguiente() -> void:
	var datos := guardar_nave()
	if datos.is_empty():
		return
	nave_construida.emit(datos)
	
	var ruta_cohete := "res://Screens/ensamblaje_cohete.tscn"
	var err := get_tree().change_scene_to_file(ruta_cohete)
	if err != OK:
		push_error("No se pudo cargar la escena del cohete en: " + ruta_cohete)


# Esta función se ejecuta al PASAR EL RATÓN sobre el botón "Siguiente"
func _on_boton_siguiente_hover() -> void:
	var r := validar(seleccionadas)
	var hay_errores = seleccionadas.is_empty() or r["errores"].size() > 0
	
	tt_titulo.text = "Launch Validation"
	tt_resumen.visible = false
	tt_stats.visible = false
	tt_aviso.visible = true
	
	if hay_errores:
		# Usa el color rojizo de alerta que ya tienes definido para tt_aviso
		tt_aviso.add_theme_color_override("font_color", Color("ff9d8a")) 
		if seleccionadas.is_empty():
			tt_aviso.text = "You must select at least one part."
		else:
			tt_aviso.text = "Cannot proceed due to:\n- " + "\n- ".join(r["errores"])
	else:
		# Usa el color azulado/verdoso si todo está bien
		tt_aviso.add_theme_color_override("font_color", Color("9fd8d8")) 
		tt_aviso.text = "All systems go!\nClick to proceed to rocket assembly."
		
	tooltip.reset_size()
	_posicionar_tooltip()
	tooltip.show()
# Guarda la nave en GameState y en RUTA_NAVE, y devuelve lo guardado ({} si falló).
func guardar_nave() -> Dictionary:
	var tot := calcular_totales(seleccionadas)
	var cm: Dictionary = tot["cohete"]
	var datos := {
		"version": 1,
		"tipo_mision": tipo_mision,
		"aterrizaje": aterrizaje,
		"piezas": seleccionadas.duplicate(),
		"totales": {
			"masa": tot["masa"],                      # unidades del juego
			"masa_kg": tot["masa"] * unidad_masa,
			"slots": tot["slots"],                    # espacios que ocupa dentro de la cofia
			"precio": tot["precio"],
			"generacion_w": tot["gen"],
			"consumo_w": tot["cons"],
			"balance_w": tot["watts"],
			"capacidad_wh": tot["wh"],
		},
		"presupuesto_total": presupuesto,
		"presupuesto_restante": presupuesto - tot["precio"],   # lo que queda para construir el cohete
		"requiere_cohete": tot["req_cohete"],                  # ej. ["cofia_expandida"]
		"cohete_minimo": {"nombre": cm["nombre"], "costo": cm["costo"], "capacidad": cm["cap"], "ids": cm["ids"]},
	}
	_guardar_borrador()
	if estado:
		estado.guardar_nave(datos)       # memoria compartida entre escenas
	var archivo := FileAccess.open(RUTA_NAVE, FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo guardar la nave en %s (error %d)." % [RUTA_NAVE, FileAccess.get_open_error()])
		return {}
	archivo.store_string(JSON.stringify(datos, "\t"))
	archivo.close()
	print("Nave guardada en: ", ProjectSettings.globalize_path(RUTA_NAVE))
	return datos


# Para quien necesite la nave sin pasar por GameState:  var nave := load("res://Screens/build_rocket.gd").cargar_nave()
static func cargar_nave() -> Dictionary:
	if not FileAccess.file_exists(RUTA_NAVE):
		return {}
	var datos = JSON.parse_string(FileAccess.get_file_as_string(RUTA_NAVE))
	if typeof(datos) == TYPE_DICTIONARY:
		return datos
	return {}


# ---------- Estilos (solo si ESTILO_POR_CODIGO = true) ----------

# Casillas blancas con borde, como tu borrador; la elegida se pone verdosa.
func _estilo_casilla(boton: Button) -> void:
	var fondos := {"normal": Color("f4fdff"), "hover": Color("dff4f4"), "pressed": Color("9fd8d8"),
		"hover_pressed": Color("8cc9c9"), "disabled": Color("e6eef0")}
	for estado_boton in fondos:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fondos[estado_boton]
		sb.set_border_width_all(1)
		sb.border_color = Color("5b4a45") if estado_boton.contains("pressed") else Color("a38f8f")
		sb.set_corner_radius_all(2)
		boton.add_theme_stylebox_override(estado_boton, sb)
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
	for estado_boton in fondos:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fondos[estado_boton]
		sb.set_border_width_all(1)
		sb.border_color = Color("4a3b38") if estado_boton.contains("pressed") else Color("a38f8f")
		sb.corner_radius_top_left = 2
		sb.corner_radius_bottom_left = 2
		boton.add_theme_stylebox_override(estado_boton, sb)
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
	_refrescar_casillas()


# Oculta piezas que no corresponden a esta misión.
func _aplica(info: Dictionary) -> bool:
	var solo: String = info.get("solo_mision", "")
	if solo != "" and solo != tipo_mision:
		return false
	if info.get("requiere_aterrizaje", false) and not aterrizaje:
		return false
	return true


# ---------- Bloqueo de piezas (incompatibilidad, cohete y presupuesto) ----------

# Devuelve "" si la pieza se puede elegir; si no, el motivo del bloqueo.
func _razon_bloqueo(id: String) -> String:
	if seleccionadas.has(id):
		return ""   # una pieza ya elegida siempre se puede quitar
	var p: Dictionary = piezas[id]
	# 1) Incompatible en cualquier dirección: A lista a B, o B lista a A (el RTG lista los paneles, pero no al revés).
	for s in seleccionadas:
		if p.get("incompatible", []).has(s) or piezas[s].get("incompatible", []).has(id):
			return _s("blk_incomp") % piezas[s]["nombre"]
	# 2) Con esta pieza, ¿existe algún cohete que pueda lanzar la nave?
	var hipotetica: Array = seleccionadas.duplicate()
	hipotetica.append(id)
	var carga := _carga_de(hipotetica)
	var cohete_min := _mejor_cohete(carga)
	if not cohete_min["ok"]:
		return _s("blk_rocket")
	# 3) Presupuesto (nave + cohete más barato que la lanza).
	if BLOQUEAR_SI_EXCEDE_PRESUPUESTO:
		var total: float = carga["precio"]
		if RESERVAR_COHETE_EN_PRESUPUESTO:
			total += cohete_min["costo"]
		var falta := total - presupuesto
		if falta > 0.0:
			return _s("blk_budget") % _dinero(falta)
	return ""


# Recalcula qué casillas están bloqueadas y cuáles están elegidas.
func _refrescar_casillas() -> void:
	for i in slots.size():
		var boton := slots[i]
		if i < ids_en_slots.size():
			var id: String = ids_en_slots[i]
			boton.disabled = _razon_bloqueo(id) != ""
			boton.set_pressed_no_signal(seleccionadas.has(id))
		else:
			boton.disabled = true
			boton.set_pressed_no_signal(false)


# ---------- Selección y hover ----------

func _on_casilla_presionada(i: int) -> void:
	if i >= ids_en_slots.size():
		return
	var id: String = ids_en_slots[i]
	if slots[i].button_pressed:
		if _razon_bloqueo(id) != "":
			slots[i].set_pressed_no_signal(false)
			return
		if not seleccionadas.has(id):
			seleccionadas.append(id)
	else:
		seleccionadas.erase(id)
	_guardar_borrador()        # así, si el jugador sale de la pantalla, no pierde lo elegido
	_refrescar_casillas()
	actualizar_resumen()


func _on_casilla_hover(i: int) -> void:
	if i < ids_en_slots.size():
		_mostrar_tooltip(ids_en_slots[i])
		if not slots[i].disabled:
			_animar(slots[i], 1.08)   # una pieza bloqueada no "salta"


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
	tt_aviso = _nueva_etiqueta(Color("ff9d8a"), 3)
	caja.add_child(tt_titulo)
	caja.add_child(tt_resumen)
	caja.add_child(tt_stats)
	caja.add_child(tt_aviso)

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
	var s := "%s | %s %d kg | %+d W | %s %d" % [_dinero(p["precio_juego"]), _s("mass"), _kg(p["masa"]), int(p["watts"]), _s("slots"), int(p["slots"])]
	if p["capacidad_wh"] > 0:
		s += " | %d Wh" % int(p["capacidad_wh"])
	tt_stats.text = s
	tt_aviso.text = _razon_bloqueo(id)            # vacío si la pieza se puede elegir
	tt_aviso.visible = tt_aviso.text != ""
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
	if v >= 1000.0:
		return "%dk cr" % int(v / 1000.0)
	return "%d cr" % int(v)


func nombres(ids: Array) -> PackedStringArray:
	var r := PackedStringArray()
	for i in ids:
		r.append(piezas[i]["nombre"] if piezas.has(i) else str(i))
	return r


# ---------- Totales, barras y reglas ----------

# Todo lo que necesitan las barras y el JSON de la nave (masa y precio en unidades del juego).
func calcular_totales(ids: Array) -> Dictionary:
	var tot := _carga_de(ids)
	tot["gen"] = 0.0     # watts positivos = genera
	tot["cons"] = 0.0    # watts negativos = consume
	tot["wh"] = 0.0      # capacidad de baterías
	for id in ids:
		var p: Dictionary = piezas[id]
		var w := float(p["watts"])
		if w >= 0.0:
			tot["gen"] += w
		else:
			tot["cons"] += -w
		tot["wh"] += float(p["capacidad_wh"])
	tot["watts"] = tot["gen"] - tot["cons"]
	tot["cohete"] = _mejor_cohete(tot)
	return tot


# Llena una barra: usado / máximo, con color verde, amarillo (>= 80 %) o rojo (se pasó).
func _actualizar_barra(clave: String, usado: float, maximo: float, texto: String) -> void:
	if not barras.has(clave):
		return
	var b: Dictionary = barras[clave]
	var pct := 0.0
	if maximo > 0.0:
		pct = usado / maximo * 100.0
	elif usado > 0.0:
		pct = 101.0                  # hay carga pero no hay de dónde sacarla
	var barra: ProgressBar = b["barra"]
	barra.value = minf(pct, 100.0)
	var relleno: StyleBoxFlat = b["relleno"]
	if pct > 100.0:
		relleno.bg_color = COLOR_MAL
	elif pct >= 80.0:
		relleno.bg_color = COLOR_CERCA
	else:
		relleno.bg_color = COLOR_OK
	var etiqueta: Label = b["texto"]
	etiqueta.text = texto


func actualizar_resumen() -> void:
	var tot := calcular_totales(seleccionadas)
	var cm: Dictionary = tot["cohete"]
	var gasto: float = tot["precio"]
	if RESERVAR_COHETE_EN_PRESUPUESTO:
		gasto += cm["costo"]

	# Masa: la nave contra lo más pesado que puede levantar el cohete más potente que le sirve.
	_actualizar_barra("masa", tot["masa"], cm["max_masa"],
		"%d / %d kg" % [_kg(tot["masa"]), _kg(maxf(cm["max_masa"], 0.0))])
	# Energía: consumo / generación.
	_actualizar_barra("energia", tot["cons"], tot["gen"],
		"%d / %d W" % [int(tot["cons"]), int(tot["gen"])])
	# Presupuesto: nave + cohete más barato que la lanza, contra el total de la misión.
	_actualizar_barra("presupuesto", gasto, presupuesto,
		"%s / %s" % [_dinero(gasto), _dinero(presupuesto)])
	# Combustible/empuje: qué tan lleno va el cohete más barato que la lanza (carga / capacidad).
	_actualizar_barra("combustible", cm["carga"], cm["cap"],
		"%d / %d kg" % [_kg(cm["carga"]), _kg(cm["cap"])])

	# Errores y avisos
	var txt := "%s: %d | %s: %d\n" % [_s("pieces"), seleccionadas.size(), _s("slots"), int(tot["slots"])]
	if cm["ok"] and not combos_cohete.is_empty():
		txt += "%s: %s (%s)\n" % [_s("rocket"), cm["nombre"], _dinero(cm["costo"])]
	var r := validar(seleccionadas)
	if tot["watts"] < 0:
		r["errores"].append(_s("neg_power") % int(tot["watts"]))
	if not cm["ok"]:
		r["errores"].append(_s("no_rocket"))
	if gasto > presupuesto:
		r["errores"].append(_s("over_budget") % [_dinero(gasto), _dinero(presupuesto)])
	for e in r["errores"]:
		txt += _s("err") + ": " + e + "\n"
	for a in r["avisos"]:
		txt += _s("warn") + ": " + a + "\n"
	if label_resumen:
		label_resumen.text = txt
		
	if boton_construir:
		var hay_errores = seleccionadas.is_empty() or r["errores"].size() > 0
		boton_construir.disabled = hay_errores
		
# Devuelve {"errores": [...], "avisos": [...]}.
# Los ids que no están en los JSON de la nave (ej. cofia_expandida) los resuelve el cohete mínimo.
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
