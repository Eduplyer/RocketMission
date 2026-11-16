extends Control
## Pantalla de ensamblaje de la NAVE (casillas fijas + pestañas + tooltip al pasar el mouse).
## Incluye: bloqueo de piezas incompatibles, presupuesto, límites reales según cohete.json (masa, espacios Y combustible),
## barras de métricas y guardado de la nave en un JSON para la etapa del cohete.
## Conserva lo elegido en el autoload GameState: si vienes "atrás" desde el cohete, todo sigue cargado.
## Tú acomodas los botones en el editor; el script les pone datos, estilo y comportamiento.
##
## PARTE EDUCATIVA (nueva):
##  - Al pasar el mouse sobre una pieza se ve el EFECTO en masa, energía, costo y cohete antes de elegirla.
##  - Lista "SYSTEMS CHECK": un renglón por subsistema ([x] listo, [ ] falta, [!] error) y un punto de color en cada pestaña.
##  - Los errores dicen qué hacer para arreglarlos, no solo qué está mal.
##  - Cada barra tiene un tooltip que explica qué mide y el desglose pieza por pieza.
##  - Un consejo corto por categoría (TIP) explica el concepto de ingeniería.
## Nodos opcionales: "LabelChecklist" (el checklist) y "LabelConsejo" (el TIP). Si no existen, todo sale en LabelResumen.

# Se emite al pulsar "Construir", con el mismo diccionario que se guardó en RUTA_NAVE.
signal nave_construida(datos: Dictionary)

const RUTA_JSON := "res://data/"   # clic derecho en tu carpeta > Copiar ruta
const ARCHIVOS := ["potencia", "actitud", "comunicaciones", "control_termico", "soporte_vital", "carga_util"]
const ARCHIVO_COHETE := "cohete"   # res://data/cohete.json: de aquí salen los límites de masa, espacios y combustible
# Respaldo en disco (por si GameState no está registrado). user:// es la única carpeta donde un juego exportado puede escribir.
const RUTA_NAVE := "user://nave.json"

# Orden de las pestañas: el 1.er botón de $Pestanas muestra la 1.ª categoría, y así sucesivamente.
const CATEGORIAS := ["potencia", "control_actitud", "comunicaciones", "control_termico", "soporte_vital", "carga_util"]
const COLUMNAS := 4
const TAM_CASILLA := Vector2(23, 23)
const TAM_PESTANA := Vector2(5, 10)
const TAM_INDICADOR := Vector2(3, 3)   # punto de estado en cada pestaña

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

# true = el cohete mínimo también tiene que tener combustible para llegar al destino (ecuación del cohete).
# Así una nave no pasa esta pantalla para luego no tener cohete que la lleve.
const CONSIDERAR_COMBUSTIBLE := true
# Destino mientras la pantalla de misión no lo mande (clave de meta.destinos_delta_v_ms en cohete.json).
# La pantalla de misión puede cambiarlo: configurar_mision(..., "luna_orbita") o `destino = "..."` antes de abrir esta escena.
const DESTINO_PRUEBA := "marte_orbita"

# true = la nave necesita al menos UNA pieza de cada sistema (energía, actitud, comunicaciones, térmico, carga útil y,
# en misión humana, soporte vital). Mientras falte alguno, el botón Siguiente queda apagado y el tooltip dice cuál.
# false = un sistema vacío solo se marca "[ ]" en el checklist y la nave se puede construir igual.
const EXIGIR_SUBSISTEMAS := true

# Nombres de los nodos ProgressBar en tu escena (clave de métrica -> nombre del nodo).
#   masa        = masa de la nave / nave más pesada que algún cohete compatible puede llevar (sustentación y combustible)
#   energia     = consumo / generación
#   presupuesto = nave + cohete más barato / presupuesto de la misión
#   combustible = combustible que necesita el cohete más barato / lo que cabe en su tanque
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
		"err": "ERROR", "warn": "AVISO", "rocket": "Cohete mínimo", "dest": "Destino: %s",
		"req": "%s necesita %s para funcionar. Agrégalo en la pestaña %s.",
		"req_one": "%s necesita al menos uno de: %s.",
		"incomp": "%s no se puede combinar con %s. Quita uno de los dos.",
		"neg_power": "Tus piezas consumen %d W pero solo generas %d W. Agrega una fuente de energía o quita un consumidor.",
		"over_budget": "Presupuesto excedido (%s / %s). Quita piezas o elige otras más baratas.",
		"no_rocket": "Ningún cohete puede lanzar esta nave: pesa demasiado, ocupa demasiados espacios o necesita demasiado combustible. Quita piezas.",
		"sys_missing": "Falta el sistema de %s: agrega al menos una pieza en esa pestaña.",
		"blk_incomp": "Incompatible con %s", "blk_budget": "Sin presupuesto (faltan %s)",
		"blk_rocket": "Ningún cohete puede cargarla (masa, espacios o combustible)",
		"check": "REVISIÓN DE SISTEMAS", "n_parts": "%d pieza(s)", "add_one": "aún nada, agrega al menos una", "more_errs": " (+%d más)",
		"tip": "CONSEJO",
		"d_add": "Si la agregas:", "d_remove": "Si la quitas:",
		"d_mass": "Masa %d -> %d kg", "d_power": "Energía %+d -> %+d W", "d_cost": "Costo total %s -> %s",
		"d_rocket": "Cohete: %s -> %s", "d_no_rocket": "¡Ningún cohete podría lanzar la nave!",
		"val_title": "Validación de lanzamiento", "val_none": "Una nave necesita al menos una pieza de cada sistema (mira la revisión de sistemas).",
		"val_blocked": "No puedes avanzar porque:\n- %s", "val_ok": "¡Todo listo!\nHaz clic para armar el cohete.",
		"load": "Carga del cohete (nave + cofia): %d kg de %d kg de sustentación",
		"need_fuel": "Combustible necesario %d kg; el tanque guarda %d kg",
		"to_dest": "Para llegar a %s hacen falta %d m/s",
		"tip_bar_masa": "Masa de la nave contra la nave más pesada que algún cohete compatible puede llevar. Cada kilo extra obliga a un cohete más grande y más caro.",
		"tip_bar_energia": "Consumo contra generación. Lo que generas debe ser al menos lo que consumen tus piezas.",
		"tip_bar_presupuesto": "Costo de la nave más el cohete más barato que la puede lanzar, contra el presupuesto de la misión.",
		"tip_bar_combustible": "Combustible que necesita el cohete más barato para llegar al destino, contra lo que cabe en su tanque. Una nave más pesada necesita mucho más combustible (ecuación del cohete).",
		"tip_potencia": "Cada pieza consume watts. Lo que generas debe superar lo que consumes; las baterías cubren los periodos de sombra (eclipse).",
		"tip_control_actitud": "El control de actitud mantiene antenas, paneles e instrumentos apuntando donde deben. Sin él, la nave da vueltas sin control.",
		"tip_comunicaciones": "Sin enlace de radio no hay ciencia: los datos tienen que llegar a la Tierra. Más lejos significa antenas más fuertes y más energía.",
		"tip_control_termico": "El espacio oscila entre calor y frío extremos. La electrónica necesita calentadores o radiadores para mantenerse en su rango.",
		"tip_soporte_vital": "Una tripulación necesita aire, agua y una temperatura habitable. Pesa mucho y consume mucha energía.",
		"tip_carga_util": "La carga útil es la razón de la misión. Todo lo demás existe para que funcione y llegue hasta allá."},
	"en": {"pieces": "Parts", "mass": "Mass", "power": "Power", "slots": "Slots", "cost": "Cost",
		"err": "ERROR", "warn": "WARNING", "rocket": "Min. rocket", "dest": "Destination: %s",
		"req": "%s needs %s to work. Add it in the %s tab.",
		"req_one": "%s needs at least one of: %s.",
		"incomp": "%s cannot be combined with %s. Remove one of them.",
		"neg_power": "Your parts use %d W but generate only %d W. Add a power source or remove a consumer.",
		"over_budget": "Budget exceeded (%s / %s). Remove parts or choose cheaper ones.",
		"no_rocket": "No rocket can launch this ship: it is too heavy, needs too many slots or too much fuel. Remove some parts.",
		"sys_missing": "The ship has no %s system: add at least one part in that tab.",
		"blk_incomp": "Incompatible with %s", "blk_budget": "Over budget (short by %s)",
		"blk_rocket": "No rocket can carry it (mass, slots or fuel)",
		"check": "SYSTEMS CHECK", "n_parts": "%d part(s)", "add_one": "nothing yet, add at least one", "more_errs": " (+%d more)",
		"tip": "TIP",
		"d_add": "If you add it:", "d_remove": "If you remove it:",
		"d_mass": "Mass %d -> %d kg", "d_power": "Power %+d -> %+d W", "d_cost": "Total cost %s -> %s",
		"d_rocket": "Rocket: %s -> %s", "d_no_rocket": "No rocket could launch the ship!",
		"val_title": "Launch Validation", "val_none": "A ship needs at least one part from every system (see the systems check).",
		"val_blocked": "Cannot proceed due to:\n- %s", "val_ok": "All systems go!\nClick to proceed to rocket assembly.",
		"load": "Rocket load (ship + fairing): %d kg of %d kg lift",
		"need_fuel": "Fuel needed %d kg, tank holds %d kg",
		"to_dest": "Reaching %s takes %d m/s",
		"tip_bar_masa": "Ship mass against the heaviest ship any compatible rocket can carry. Every extra kilogram means a bigger, costlier rocket.",
		"tip_bar_energia": "Power use against generation. What you generate must be at least what your parts consume.",
		"tip_bar_presupuesto": "Ship cost plus the cheapest rocket that can launch it, against the mission budget.",
		"tip_bar_combustible": "Fuel the cheapest rocket needs to reach the destination, against what its tank holds. A heavier ship needs far more fuel (the rocket equation).",
		"tip_potencia": "Every part draws watts. Generation must exceed consumption; batteries cover the dark (eclipse) periods.",
		"tip_control_actitud": "Attitude control keeps antennas, panels and instruments pointed where they must be. Without it the ship tumbles.",
		"tip_comunicaciones": "No radio link, no science: the data must reach Earth. Farther targets need stronger antennas and more power.",
		"tip_control_termico": "Space swings between extreme heat and cold. Electronics need heaters or radiators to stay in their range.",
		"tip_soporte_vital": "A crew needs air, water and a livable temperature. It is heavy and power-hungry.",
		"tip_carga_util": "The payload is the reason for the mission. Everything else exists to keep it working and get it there."},
}
# Nombre visible de cada categoría (pestañas y checklist).
const NOMBRES_CAT := {
	"es": {"potencia": "Energía", "control_actitud": "Actitud", "comunicaciones": "Comunicaciones",
		"control_termico": "Térmico", "soporte_vital": "Soporte vital", "carga_util": "Carga útil"},
	"en": {"potencia": "Power", "control_actitud": "Attitude", "comunicaciones": "Comms",
		"control_termico": "Thermal", "soporte_vital": "Life support", "carga_util": "Payload"},
}

# Rutas según tu árbol de escena. Si moviste algo: clic derecho en el nodo > Copiar ruta del nodo.
@onready var grid_piezas: GridContainer = get_node_or_null("PanelPersonaliza/GridPiezas")
@onready var pestanas: VBoxContainer = get_node_or_null("Pestanas")
# Estos se buscan por nombre, estén donde estén en el árbol.
@onready var label_resumen: Label = find_child("LabelResumen", true, false) as Label
@onready var label_checklist: Label = find_child("LabelChecklist", true, false) as Label   # opcional
@onready var label_consejo: Label = find_child("LabelConsejo", true, false) as Label       # opcional

# Vendrán de la pantalla de misión (por ahora, valores de prueba).
var tipo_mision := "humana"   # "humana" o "robotica"
var aterrizaje := false
var presupuesto := 0.0        # presupuesto total de la misión actual
var destino := DESTINO_PRUEBA # a dónde va la misión (decide cuánto combustible hace falta)

var estado = null                # el autoload GameState (null si no está registrado)
var piezas := {}                 # id -> datos de la pieza (todos los JSON de la nave juntos)
var cohete := {}                 # id -> datos de las piezas del cohete (cohete.json)
var combos_cohete := []          # todos los cohetes armables: {ids, nombre, cap, costo, extra, slots, cap_comb, isp}
var unidad_masa := 1.0           # kg por unidad de masa (meta.unidad_masa_kg de los JSON)
var unidad_comb := 5.0           # kg por unidad de combustible (meta.unidad_combustible_kg de cohete.json)
var g0 := 9.80665
var destinos_dv := {}            # meta.destinos_delta_v_ms de cohete.json
var seleccionadas := []          # ids de las piezas elegidas para la nave
var slots: Array[Button] = []    # las casillas que acomodaste en el editor
var ids_en_slots := []           # qué pieza muestra cada casilla ahora mismo
var barras := {}                 # clave de métrica -> {"barra", "relleno", "texto"}
var indicadores := {}            # categoría -> punto de color de su pestaña
var categoria_actual: String = "potencia"
var boton_construir: Button

var tooltip: PanelContainer
var tt_titulo: Label
var tt_resumen: Label
var tt_stats: Label
var tt_delta: Label              # efecto de elegir (o quitar) la pieza
var tt_aviso: Label              # motivo por el que una pieza está bloqueada


func _ready() -> void:
	add_to_group("pantalla_coheteselect")
	if not _nodos_ok():
		return
	estado = get_node_or_null("/root/GameState")
	if estado == null:
		push_warning("El autoload 'GameState' no está registrado (Proyecto > Configuración > Autoload): la nave no se conservará al cambiar de escena.")
	cargar_datos_json()
	_crear_tooltip()
	grid_piezas.columns = COLUMNAS
	for l in [label_resumen, label_checklist, label_consejo]:
		if l:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(200, 0)
			l.add_theme_font_size_override("font_size", 14)
	preparar_casillas()
	preparar_pestanas()
	preparar_barras()
	preparar_boton_construir()
	# Si el jugador ya había elegido piezas (y volvió "atrás"), se recuperan; si no, empieza de cero.
	if not _restaurar_borrador():
		configurar_mision(tipo_mision, aterrizaje)
	print("Ensamblaje listo -> piezas: %d | elegidas: %d | cohetes posibles: %d | casillas: %d | pestañas: %d | destino: %s" % [piezas.size(), seleccionadas.size(), combos_cohete.size(), slots.size(), pestanas.get_child_count(), destino])


func _process(_delta: float) -> void:
	if tooltip and tooltip.visible:
		_posicionar_tooltip()


func _s(clave: String) -> String:
	return String(TXT[idioma].get(clave, clave))


func _nombre_cat(cat: String) -> String:
	return String(NOMBRES_CAT[idioma].get(cat, cat))


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
# presupuesto_total <= 0 usa el valor de prueba de PRESUPUESTO_MISION. destino_mision "" deja el destino que ya había.
func configurar_mision(tipo: String, aterriza: bool, presupuesto_total: float = -1.0, destino_mision: String = "") -> void:
	tipo_mision = tipo
	aterrizaje = aterriza
	if destino_mision != "":
		destino = destino_mision
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
			var meta: Dictionary = dc.get("meta", {})
			unidad_comb = float(meta.get("unidad_combustible_kg", unidad_masa))
			g0 = float(meta.get("g0_ms2", g0))
			destinos_dv = meta.get("destinos_delta_v_ms", {})
	if cohete.is_empty():
		push_error("No se cargó cohete.json: no se pueden calcular los límites de masa y espacios. Revisa " + ruta_cohete)
	if CONSIDERAR_COMBUSTIBLE and destinos_dv.is_empty():
		push_warning("cohete.json no tiene meta.destinos_delta_v_ms: no se revisa el combustible. Usa la versión con combustible.")
	_preparar_cohetes()


# ---------- Cohete: qué se puede lanzar ----------
# Reglas (de cohete.json): 1 cofia + 1 motor + el tanque que ese motor requiere + 1 computadora.
# Los boosters son opcionales. Se bloquea el lanzamiento si la carga pesa más que la capacidad,
# si los espacios usados superan los de la cofia o si el tanque no alcanza para llegar al destino.

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
				var cap_comb := 0.0   # combustible que caben los tanques (unidades de combustible)
				for id in ids:
					var q: Dictionary = cohete[id]
					cap += float(q.get("aporta_capacidad_masa", 0.0)) + float(q.get("ajuste_capacidad_masa", 0.0))
					costo += float(q["precio_juego"])
					cap_comb += float(q.get("capacidad_combustible", 0.0))
					if q.get("masa_cuenta_como_carga", true):
						extra += float(q["masa"])
				combos_cohete.append({"ids": ids, "nombre": nombre, "cap": cap, "costo": costo, "extra": extra,
					"slots": float(cohete[f].get("capacidad_slots", 0.0)),
					"cap_comb": cap_comb, "isp": float(cohete[m].get("isp_vacio_real_s", 0.0))})


# Δv que pide el destino (m/s). 0 si no se conoce o si no se revisa el combustible.
func _dv_destino() -> float:
	if not CONSIDERAR_COMBUSTIBLE:
		return 0.0
	var d: Dictionary = destinos_dv.get(destino, {})
	return float(d.get("cohete", 0.0))


# Ecuación del cohete: propelente = m_final * (e^(Δv / (Isp * g0)) - 1). Unidades de combustible.
func _combustible_necesario(masa_nave: float, c: Dictionary) -> float:
	var dv := _dv_destino()
	var isp: float = c["isp"]
	if dv <= 0.0 or isp <= 0.0:
		return 0.0
	return masa_nave * (exp(dv / (isp * g0)) - 1.0)


# La nave más pesada que ese cohete puede llevar al destino con su tanque.
func _masa_max_por_combustible(c: Dictionary) -> float:
	var dv := _dv_destino()
	var isp: float = c["isp"]
	if dv <= 0.0 or isp <= 0.0:
		return INF
	return float(c["cap_comb"]) / (exp(dv / (isp * g0)) - 1.0)


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


# Cohete más barato que puede lanzar esa carga y llevarla al destino.
# Devuelve {"ok", "costo", "cap", "carga", "nombre", "ids", "necesario", "cap_comb", "max_masa"};
# max_masa = lo más pesada que podría ser la nave con el cohete más potente que respeta sus espacios y requisitos
# (limitada por sustentación y por combustible; -1 si no hay ninguno).
func _mejor_cohete(carga: Dictionary) -> Dictionary:
	if combos_cohete.is_empty():
		return {"ok": true, "costo": 0.0, "cap": 0.0, "carga": carga["masa"], "nombre": "—", "ids": [],
			"necesario": 0.0, "cap_comb": 0.0, "max_masa": 0.0}
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
		var lim_comb := _masa_max_por_combustible(c)
		max_masa = maxf(max_masa, minf(c["cap"] - c["extra"], lim_comb))
		var total: float = carga["masa"] + c["extra"]
		if total > c["cap"]:
			continue
		if carga["masa"] > lim_comb:
			continue
		if mejor.is_empty() or c["costo"] < mejor["costo"]:
			mejor = {"ok": true, "costo": c["costo"], "cap": c["cap"], "carga": total, "nombre": c["nombre"], "ids": c["ids"],
				"necesario": _combustible_necesario(carga["masa"], c), "cap_comb": c["cap_comb"]}
	if mejor.is_empty():
		mejor = {"ok": false, "costo": 0.0, "cap": 0.0, "carga": carga["masa"], "nombre": "—", "ids": [],
			"necesario": 0.0, "cap_comb": 0.0}
	mejor["max_masa"] = max_masa
	return mejor


func _kg(unidades: float) -> int:
	return roundi(unidades * unidad_masa)


func _kgc(unidades: float) -> int:
	return roundi(unidades * unidad_comb)


# Costo que cuenta contra el presupuesto: la nave y, si está activado, el cohete más barato que la lanza.
func _gasto(tot: Dictionary) -> float:
	var g: float = tot["precio"]
	if RESERVAR_COHETE_EN_PRESUPUESTO:
		g += float(tot["cohete"]["costo"])
	return g


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
		boton.tooltip_text = _nombre_cat(CATEGORIAS[i])
		_ignorar_mouse_en_hijos(boton)
		if ESTILO_POR_CODIGO:
			_estilo_pestana(boton, colores_pestana[i])
		_crear_indicador(boton, CATEGORIAS[i])      # después del estilo, que oculta los ColorRect hijos
		boton.pressed.connect(mostrar_categoria.bind(CATEGORIAS[i]))
		i += 1


# Punto de color en la esquina de la pestaña: verde = listo, amarillo = falta, rojo = error.
func _crear_indicador(boton: Button, cat: String) -> void:
	var punto := ColorRect.new()
	punto.custom_minimum_size = TAM_INDICADOR
	punto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	punto.color = COLOR_CERCA
	boton.add_child(punto)
	punto.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	indicadores[cat] = punto


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
		barra.tooltip_text = _s("tip_bar_" + clave)   # explica qué mide (se completa con el desglose al actualizar)

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
	var tot := calcular_totales(seleccionadas)
	var r := evaluar_nave(tot)
	var hay_errores: bool = seleccionadas.is_empty() or r["errores"].size() > 0

	tt_titulo.text = _s("val_title")
	tt_resumen.visible = false
	tt_stats.visible = false
	tt_delta.visible = false
	tt_aviso.visible = true

	if hay_errores:
		# Usa el color rojizo de alerta que ya tienes definido para tt_aviso
		tt_aviso.add_theme_color_override("font_color", Color("ff9d8a"))
		if seleccionadas.is_empty():
			tt_aviso.text = _s("val_none")
		else:
			tt_aviso.text = _s("val_blocked") % "\n- ".join(PackedStringArray(r["errores"]))
	else:
		# Usa el color azulado/verdoso si todo está bien
		tt_aviso.add_theme_color_override("font_color", Color("9fd8d8"))
		tt_aviso.text = _s("val_ok")

	tooltip.reset_size()
	_posicionar_tooltip()
	tooltip.show()


# ---------- Guardar y cargar la nave ----------

# Guarda la nave en GameState y en RUTA_NAVE, y devuelve lo guardado ({} si falló).
func guardar_nave() -> Dictionary:
	var tot := calcular_totales(seleccionadas)
	var cm: Dictionary = tot["cohete"]
	var datos := {
		"version": 1,
		"tipo_mision": tipo_mision,
		"aterrizaje": aterrizaje,
		"destino": destino,                                   # el cohete usa este destino para calcular el combustible
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
	# --- Registrar nave y sus avisos de riesgo en GameManager (si no existe o no tiene el método, solo avisa) ---
	var avisos_nave: Array = validar(seleccionadas)["avisos"]
	var riesgo_calc := float(avisos_nave.size()) * 5.0
	var texto_avisos := ", ".join(PackedStringArray(avisos_nave))
	var gm = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("registrar_nave"):
		gm.call("registrar_nave", riesgo_calc, texto_avisos, datos)
	else:
		push_warning("GameManager.registrar_nave no existe: el riesgo de la nave no se registró.")
	# ------------------------------------------------------------------
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
	categoria_actual = cat
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
	actualizar_resumen()      # el consejo (TIP) cambia con la pestaña


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
	# 2) Con esta pieza, ¿existe algún cohete que pueda lanzar la nave (masa, espacios y combustible)?
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
	tt_delta = _nueva_etiqueta(Color("c8e6a0"), 3)
	tt_aviso = _nueva_etiqueta(Color("ff9d8a"), 3)
	caja.add_child(tt_titulo)
	caja.add_child(tt_resumen)
	caja.add_child(tt_stats)
	caja.add_child(tt_delta)
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
	tt_stats.visible = true                       # el tooltip del botón Siguiente lo oculta; aquí se vuelve a mostrar
	tt_delta.text = _delta_texto(id)              # lo que le pasaría a la nave si la elige (o la quita)
	tt_delta.visible = tt_delta.text != ""
	tt_aviso.add_theme_color_override("font_color", Color("ff9d8a"))
	tt_aviso.text = _razon_bloqueo(id)            # vacío si la pieza se puede elegir
	tt_aviso.visible = tt_aviso.text != ""
	tooltip.reset_size()
	tooltip.show()
	_posicionar_tooltip()


# EFECTO de elegir la pieza (o de quitarla si ya está elegida): masa, energía, costo total y cohete mínimo.
# Es la parte que enseña los compromisos de ingeniería: nada es gratis, cada decisión mueve todo lo demás.
func _delta_texto(id: String) -> String:
	var antes := calcular_totales(seleccionadas)
	var hip: Array = seleccionadas.duplicate()
	var quitando := hip.has(id)
	if quitando:
		hip.erase(id)
	else:
		hip.append(id)
	var despues := calcular_totales(hip)
	var s := _s("d_remove") if quitando else _s("d_add")
	s += "\n" + _s("d_mass") % [_kg(antes["masa"]), _kg(despues["masa"])]
	s += " | " + _s("d_power") % [int(antes["watts"]), int(despues["watts"])]
	s += "\n" + _s("d_cost") % [_dinero(_gasto(antes)), _dinero(_gasto(despues))]
	var ca: Dictionary = antes["cohete"]
	var cd: Dictionary = despues["cohete"]
	if not cd["ok"]:
		s += "\n" + _s("d_no_rocket")
	elif ca["ok"] and ca["nombre"] != cd["nombre"]:
		s += "\n" + _s("d_rocket") % [ca["nombre"], cd["nombre"]]
	return s


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


# Tooltip de la barra: qué mide + el desglose pieza por pieza.
func _tooltip_barra(clave: String, detalle: String) -> void:
	if not barras.has(clave):
		return
	var barra: ProgressBar = barras[clave]["barra"]
	var base := _s("tip_bar_" + clave)
	barra.tooltip_text = base if detalle == "" else base + "\n\n" + detalle


# De dónde sale cada número de la barra (qué pieza aporta cuánto).
func _desglose(clave: String, tot: Dictionary) -> String:
	var cm: Dictionary = tot["cohete"]
	var lineas := PackedStringArray()
	match clave:
		"masa":
			for id in seleccionadas:
				lineas.append("%s: %d kg" % [piezas[id]["nombre"], _kg(piezas[id]["masa"])])
			lineas.append(_s("load") % [_kg(cm["carga"]), _kg(cm["cap"])])
		"energia":
			for id in seleccionadas:
				lineas.append("%s: %+d W" % [piezas[id]["nombre"], int(piezas[id]["watts"])])
		"presupuesto":
			for id in seleccionadas:
				lineas.append("%s: %s" % [piezas[id]["nombre"], _dinero(piezas[id]["precio_juego"])])
			if RESERVAR_COHETE_EN_PRESUPUESTO and cm["ok"]:
				lineas.append("%s: %s" % [_s("rocket"), _dinero(cm["costo"])])
		"combustible":
			var dv := _dv_destino()
			if dv > 0.0:
				lineas.append(_s("to_dest") % [destino.replace("_", " "), int(dv)])
			lineas.append(_s("need_fuel") % [_kgc(cm["necesario"]), _kgc(cm["cap_comb"])])
	return "\n".join(lineas)


func actualizar_resumen() -> void:
	var tot := calcular_totales(seleccionadas)
	var cm: Dictionary = tot["cohete"]
	var gasto := _gasto(tot)

	# Masa: la nave contra lo más pesado que puede llevar el cohete más potente que le sirve (sustentación y combustible).
	_actualizar_barra("masa", tot["masa"], cm["max_masa"],
		"%d / %d kg" % [_kg(tot["masa"]), _kg(maxf(cm["max_masa"], 0.0))])
	# Energía: consumo / generación.
	_actualizar_barra("energia", tot["cons"], tot["gen"],
		"%d / %d W" % [int(tot["cons"]), int(tot["gen"])])
	# Presupuesto: nave + cohete más barato que la lanza, contra el total de la misión.
	_actualizar_barra("presupuesto", gasto, presupuesto,
		"%s / %s" % [_dinero(gasto), _dinero(presupuesto)])
	# Combustible: lo que necesita el cohete más barato para llegar al destino / lo que cabe en su tanque.
	_actualizar_barra("combustible", cm["necesario"], cm["cap_comb"],
		"%d / %d kg" % [_kgc(cm["necesario"]), _kgc(cm["cap_comb"])])
	for clave in NOMBRES_BARRAS:
		_tooltip_barra(clave, _desglose(clave, tot))

	var r := evaluar_nave(tot)
	var subs: Dictionary = r["subs"]
	_actualizar_indicadores(subs)

	# Texto del resumen: datos, checklist, errores (los que no son de un subsistema), avisos y consejo.
	var txt := "%s: %d | %s: %d\n" % [_s("pieces"), seleccionadas.size(), _s("slots"), int(tot["slots"])]
	if cm["ok"] and not combos_cohete.is_empty():
		txt += "%s: %s (%s)\n" % [_s("rocket"), cm["nombre"], _dinero(cm["costo"])]
	txt += _s("dest") % destino.replace("_", " ") + "\n"
	var lista := _texto_checklist(subs)
	if label_checklist:
		label_checklist.text = lista
	else:
		txt += "\n" + lista
	for e in r["globales"]:
		txt += _s("err") + ": " + e + "\n"
	for a in r["avisos"]:
		txt += _s("warn") + ": " + a + "\n"
	var consejo := _s("tip_" + categoria_actual)
	if label_consejo:
		label_consejo.text = consejo
	else:
		txt += "\n" + _s("tip") + ": " + consejo
	if label_resumen:
		label_resumen.text = txt
	if boton_construir:
		boton_construir.disabled = seleccionadas.is_empty() or r["errores"].size() > 0


# Todo lo que está mal o falta en la nave. Devuelve:
#   errores      = todos (si hay alguno, el botón Siguiente se apaga)
#   globales     = los errores que no pertenecen a un subsistema (presupuesto, cohete)
#   avisos       = penalizaciones (no bloquean)
#   por_categoria= categoría -> errores de esa categoría
#   subs         = categoría -> {"estado": "ok" | "falta" | "error", "n": piezas, "msgs": [...]}
func evaluar_nave(tot: Dictionary) -> Dictionary:
	var r := validar(seleccionadas)
	var cm: Dictionary = tot["cohete"]
	if tot["watts"] < 0:
		_anotar(r, "potencia", _s("neg_power") % [int(tot["cons"]), int(tot["gen"])])
	if not cm["ok"]:
		_anotar(r, "", _s("no_rocket"))
	var gasto := _gasto(tot)
	if gasto > presupuesto:
		_anotar(r, "", _s("over_budget") % [_dinero(gasto), _dinero(presupuesto)])

	var cuentas := {}
	for id in seleccionadas:
		var cat: String = piezas[id]["categoria"]
		cuentas[cat] = int(cuentas.get(cat, 0)) + 1
	var subs := {}
	for cat in _categorias_activas():
		var n: int = cuentas.get(cat, 0)
		if EXIGIR_SUBSISTEMAS and n == 0:
			# Bloquea el botón y sale en el tooltip de Siguiente; en el checklist se ve como "[ ]" (falta), no como error.
			r["errores"].append(_s("sys_missing") % _nombre_cat(cat).to_lower())
		var msgs: Array = r["por_categoria"].get(cat, [])
		var st := "ok"
		if msgs.size() > 0:
			st = "error"
		elif n == 0:
			st = "falta"
		subs[cat] = {"estado": st, "n": n, "msgs": msgs}
	r["subs"] = subs
	return r


# Pestañas que se usan en esta misión (sin tripulación no hay soporte vital).
func _categorias_activas() -> Array:
	var r := []
	for cat in CATEGORIAS:
		if cat == "soporte_vital" and tipo_mision != "humana":
			continue
		r.append(cat)
	return r


# Un renglón por subsistema: [x] listo, [ ] falta, [!] error (con lo que hay que arreglar).
func _texto_checklist(subs: Dictionary) -> String:
	var t := _s("check") + "\n"
	for cat in subs:
		var e: Dictionary = subs[cat]
		var marca := "[x]"
		var detalle: String = _s("n_parts") % int(e["n"])
		if e["estado"] == "error":
			marca = "[!]"
			var msgs: Array = e["msgs"]
			detalle = String(msgs[0])
			if msgs.size() > 1:
				detalle += _s("more_errs") % (msgs.size() - 1)
		elif e["estado"] == "falta":
			marca = "[ ]"
			detalle = _s("add_one")
		t += "%s %s: %s\n" % [marca, _nombre_cat(cat), detalle]
	return t


# Pinta el punto de cada pestaña: verde = listo, amarillo = falta, rojo = error.
func _actualizar_indicadores(subs: Dictionary) -> void:
	for cat in indicadores:
		var punto: ColorRect = indicadores[cat]
		if not subs.has(cat):
			punto.visible = false
			continue
		punto.visible = true
		var e: Dictionary = subs[cat]
		if e["estado"] == "error":
			punto.color = COLOR_MAL
		elif e["estado"] == "falta":
			punto.color = COLOR_CERCA
		else:
			punto.color = COLOR_OK


# Registra un error. cat = "" para errores que no son de un subsistema (presupuesto, cohete).
func _anotar(res: Dictionary, cat: String, msg: String) -> void:
	res["errores"].append(msg)
	if cat == "":
		res["globales"].append(msg)
		return
	if not res["por_categoria"].has(cat):
		res["por_categoria"][cat] = []
	res["por_categoria"][cat].append(msg)


# Devuelve {"errores", "avisos", "globales", "por_categoria"}. (GameManager usa ["avisos"].)
# Los ids que no están en los JSON de la nave (ej. cofia_expandida) los resuelve el cohete mínimo.
func validar(ids: Array) -> Dictionary:
	var res := {"errores": [], "avisos": [], "globales": [], "por_categoria": {}}
	for id in ids:
		var p: Dictionary = piezas[id]
		var cat: String = p["categoria"]
		for r in p["requiere"]:
			if piezas.has(r) and not ids.has(r):
				_anotar(res, cat, _s("req") % [p["nombre"], piezas[r]["nombre"], _nombre_cat(piezas[r]["categoria"])])
		if p["requiere_alguno_de"].size() > 0:
			var ok := false
			for a in p["requiere_alguno_de"]:
				if ids.has(a):
					ok = true
			if not ok:
				_anotar(res, cat, _s("req_one") % [p["nombre"], ", ".join(nombres(p["requiere_alguno_de"]))])
		for i in p["incompatible"]:
			if ids.has(i):
				_anotar(res, cat, _s("incomp") % [p["nombre"], piezas[i]["nombre"]])
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
				res["avisos"].append("%s: %s" % [p["nombre"], String(pe["efecto"]).replace("_", " ")])
	return res
