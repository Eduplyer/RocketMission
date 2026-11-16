extends Control
## Pantalla de ensamblaje del COHETE. Duplica la escena de la nave (mismos nombres de nodo:
## PanelPersonaliza/GridPiezas, Pestanas, barras, LabelResumen, BotonConstruir) y ponle ESTE script.
## Lee la nave del autoload GameState (o de user://nave.json si abres la escena sola) y calcula contra ella:
## sustentación, espacios de la cofia, presupuesto restante y combustible (delta-v) hacia el destino.
## Al pulsar "Crear": valida que todo sea compatible, registra la misión en GameState y muestra un mensaje de éxito.
## Si vuelves "atrás" y regresas, el cohete que habías elegido sigue ahí (mientras la nave no cambie).
##
## PARTE EDUCATIVA (nueva):
##  - Al pasar el mouse sobre una pieza se ve el EFECTO en sustentación, delta-v, costo y fiabilidad antes de elegirla.
##  - Lista "ROCKET CHECK": un renglón por requisito ([x] listo, [ ] falta, [!] error, [-] opcional) y un punto de color por pestaña.
##  - Los errores dicen qué hacer para arreglarlos.
##  - Cada barra tiene un tooltip que explica qué mide (la del combustible explica la ecuación del cohete) y su desglose.
##  - Un consejo corto por pestaña (TIP) explica el concepto de ingeniería.
##  - Si no hay cohete elegido, arranca con el más barato que sirve para la nave (así puedes probar la escena sola).
## Nodos opcionales: "LabelChecklist" (el checklist) y "LabelConsejo" (el TIP). Si no existen, todo sale en LabelResumen.

# Se emite al pulsar el botón de crear, con el mismo diccionario que se guardó en RUTA_LANZAMIENTO.
signal cohete_construido(datos: Dictionary)

# Se eligen en el Inspector (sin escribir rutas a mano en el código).
@export_file("*.tscn") var escena_nave := ""         # a dónde vuelve "BotonAtras"
@export_file("*.tscn") var escena_siguiente := ""    # a dónde va después del mensaje de éxito

const RUTA_JSON := "res://data/"
const ARCHIVOS_NAVE := ["potencia", "actitud", "comunicaciones", "control_termico", "soporte_vital", "carga_util"]
const ARCHIVO_COHETE := "cohete"
const RUTA_NAVE := "user://nave.json"
const RUTA_LANZAMIENTO := "user://lanzamiento.json"
# Si la nave no trae "destino", se usa este (clave de meta.destinos_delta_v_ms).
const DESTINO_PRUEBA := "marte_orbita"
const DURACION_MENSAJE := 2.2     # segundos que se ve el mensaje de éxito antes de pasar a la escena siguiente

# Una pestaña por subcategoría de cohete.json. El 1.er botón de $Pestanas muestra la 1.ª, etc.
# Sobran botones de pestaña (tienes 6 y aquí hay 5): el script oculta los que no se usan.
const CATEGORIAS := ["cofia", "motor", "booster", "avionica", "proteccion"]
# Estas se eligen como "una sola" (al elegir otra se cambia). Boosters y amortiguador se activan/desactivan.
# El tanque no se elige: lo trae el motor (su campo "requiere").
const UNICAS := ["cofia", "motor", "avionica"]
# Renglones del checklist (en este orden). Los tres últimos no son piezas: son límites que se cumplen o no.
const FILAS := ["cofia", "motor", "avionica", "booster", "proteccion", "carga", "combustible", "presupuesto"]
# A qué pestaña pertenece el problema de cada renglón (para el punto de color de la pestaña).
const PESTANA_DE_FILA := {"cofia": "cofia", "motor": "motor", "avionica": "avionica", "booster": "booster",
	"proteccion": "proteccion", "carga": "motor", "combustible": "motor"}

const COLUMNAS := 4
const TAM_CASILLA := Vector2(23, 23)
const TAM_PESTANA := Vector2(5, 10)
const TAM_INDICADOR := Vector2(3, 3)   # punto de estado en cada pestaña
const ESTILO_POR_CODIGO := true
var colores_pestana := [Color("d8b8a8"), Color("b0bcd8"), Color("b0d8d0"), Color("d8a8c8"), Color("d8d0b0"), Color("a8d0e8")]

# true = una pieza que ya no cabe en el presupuesto restante se bloquea.
const BLOQUEAR_SI_EXCEDE_PRESUPUESTO := true

# Clave de métrica -> nombre del nodo ProgressBar. Reutiliza los de la nave (solo cambia las etiquetas en el editor):
#   carga       = masa de la carga / sustentación del cohete     (antes "BarMasa")
#   espacios    = espacios que usa la nave / espacios de la cofia (antes "BarEnergia")
#   presupuesto = costo del cohete / presupuesto que dejó la nave
#   combustible = combustible necesario / capacidad del tanque
const NOMBRES_BARRAS := {
	"carga": "BarMasa", "espacios": "BarEnergia",
	"presupuesto": "BarPresupuesto", "combustible": "BarCombustible",
}
const COLOR_OK := Color("6bbf8a")
const COLOR_CERCA := Color("e0b84c")
const COLOR_MAL := Color("d9645a")
const COLOR_OPCIONAL := Color("9aa5a8")

var idioma := "en"
const TXT := {
	"es": {"rocket": "Cohete", "err": "ERROR", "warn": "AVISO", "dest": "Destino: %s",
		"dv": "Delta-v: %d / %d m/s", "reliab": "Fiabilidad: %d%%",
		"missing": "Falta: %s. Elige uno en su pestaña.",
		"overweight": "Carga demasiado pesada: %d kg contra %d kg de sustentación. Elige un motor más fuerte, agrega boosters o aligera la nave.",
		"no_slots": "La nave necesita %d espacios y la cofia tiene %d. Elige una cofia más grande.",
		"needs": "La nave requiere: %s. Elígelo en su pestaña.",
		"no_fuel": "Combustible insuficiente: el viaje necesita %d kg y el tanque guarda %d kg. Usa un motor más eficiente o una nave más ligera.",
		"over_budget": "Presupuesto excedido (%s / %s). Elige piezas más baratas.",
		"vuln": "%s es vulnerable a %s (evento del lanzamiento). Agrega una pieza que lo mitigue.",
		"req": "%s necesita %s para funcionar.", "req_one": "%s necesita al menos uno de: %s.",
		"incomp": "%s no se puede combinar con %s. Quita uno de los dos.",
		"blk_slots": "Muy chica: la nave necesita %d espacios", "blk_needs": "La nave requiere: %s",
		"blk_engine": "Primero elige un motor", "blk_budget": "Sin presupuesto (faltan %s)",
		"built_title": "¡Cohete construido con éxito!", "built_ready": "Nave y cohete guardados. Listos para el lanzamiento.",
		"budget_left": "Presupuesto restante: %s", "build_fail": "No se pudo construir",
		"save_fail": "No se pudo guardar el cohete.",
		"check": "REVISIÓN DEL COHETE", "add_one": "falta elegir", "more_errs": " (+%d más)", "tip": "CONSEJO",
		"optional": "opcional", "need_engine": "primero elige un motor",
		"boost_detail": "+%d kg de sustentación, sin combustible extra",
		"prot_hint": "hay piezas de la nave vulnerables al lanzamiento",
		"fairing_detail": "%d / %d espacios", "engine_detail": "Isp %d s | tanque %d kg",
		"row_carga": "Sustentación", "row_combustible": "Combustible", "row_presupuesto": "Presupuesto",
		"d_add": "Si la eliges:", "d_remove": "Si la quitas:",
		"d_lift": "Sustentación libre %+d -> %+d kg", "d_dv": "Delta-v %d -> %d m/s (hacen falta %d)",
		"d_cost": "Costo %s -> %s", "d_rel": "Fiabilidad %d%% -> %d%%",
		"ship_kg": "Nave: %d kg", "lift_line": "%s: %+d kg de sustentación", "mass_line": "%s: %d kg",
		"slots_need": "La nave ocupa %d espacios", "slots_have": "La cofia tiene %d espacios",
		"to_dest": "Para llegar a %s hacen falta %d m/s", "isp_line": "Isp del motor: %d s",
		"fuel_line": "Combustible necesario %d kg; el tanque guarda %d kg", "dv_line": "Con este tanque: %d m/s",
		"tip_bar_carga": "Lo que el cohete debe levantar (nave + cofia + amortiguadores) contra la sustentación de motores y boosters.",
		"tip_bar_espacios": "Espacios que ocupa la nave contra los que tiene la cofia. Una cofia más grande cuesta más y pesa más.",
		"tip_bar_presupuesto": "Costo del cohete contra el presupuesto que dejó la nave.",
		"tip_bar_combustible": "Combustible que necesita el viaje contra lo que guarda el tanque. Delta-v = Isp x g0 x ln(m_inicial / m_final): cada kilo extra de nave pide mucho más combustible.",
		"tip_cofia": "La cofia es la cáscara que protege la nave durante el ascenso. Todas las piezas deben caber dentro y su propio peso también hay que levantarlo.",
		"tip_motor": "El motor trae su propio tanque. El Isp (impulso específico) es el empuje por kilo de combustible: con Isp mayor hace falta menos combustible para el mismo viaje.",
		"tip_booster": "Los boosters dan sustentación para que despeguen naves más pesadas, pero se agotan durante el ascenso y no agregan combustible para el viaje.",
		"tip_avionica": "La computadora de vuelo guía el cohete. Su fiabilidad multiplica la probabilidad de un buen lanzamiento; las endurecidas contra radiación también resisten el clima espacial.",
		"tip_proteccion": "El lanzamiento sacude todo. Un amortiguador reduce la vibración que puede dañar las piezas frágiles de tu nave."},
	"en": {"rocket": "Rocket", "err": "ERROR", "warn": "WARNING", "dest": "Destination: %s",
		"dv": "Delta-v: %d / %d m/s", "reliab": "Reliability: %d%%",
		"missing": "Missing: %s. Pick one in its tab.",
		"overweight": "Payload too heavy: %d kg against %d kg of lift. Choose a stronger engine, add boosters or lighten the ship.",
		"no_slots": "The ship needs %d slots but the fairing has %d. Choose a bigger fairing.",
		"needs": "The ship requires: %s. Pick it in its tab.",
		"no_fuel": "Not enough fuel: the trip needs %d kg and the tank holds %d kg. Use a more efficient engine or a lighter ship.",
		"over_budget": "Budget exceeded (%s / %s). Choose cheaper parts.",
		"vuln": "%s is vulnerable to %s (a launch event). Add a part that mitigates it.",
		"req": "%s needs %s to work.", "req_one": "%s needs at least one of: %s.",
		"incomp": "%s cannot be combined with %s. Remove one of them.",
		"blk_slots": "Too small: ship needs %d slots", "blk_needs": "The ship requires: %s",
		"blk_engine": "Needs an engine first", "blk_budget": "Over budget (short by %s)",
		"built_title": "Rocket built successfully!", "built_ready": "Ship and rocket saved. Ready for launch.",
		"budget_left": "Budget left: %s", "build_fail": "Could not build",
		"save_fail": "The rocket could not be saved.",
		"check": "ROCKET CHECK", "add_one": "still to pick", "more_errs": " (+%d more)", "tip": "TIP",
		"optional": "optional", "need_engine": "pick an engine first",
		"boost_detail": "+%d kg of lift, no extra fuel",
		"prot_hint": "some ship parts are vulnerable to launch events",
		"fairing_detail": "%d / %d slots", "engine_detail": "Isp %d s | tank %d kg",
		"row_carga": "Lift", "row_combustible": "Fuel", "row_presupuesto": "Budget",
		"d_add": "If you pick it:", "d_remove": "If you remove it:",
		"d_lift": "Spare lift %+d -> %+d kg", "d_dv": "Delta-v %d -> %d m/s (needs %d)",
		"d_cost": "Cost %s -> %s", "d_rel": "Reliability %d%% -> %d%%",
		"ship_kg": "Ship: %d kg", "lift_line": "%s: %+d kg of lift", "mass_line": "%s: %d kg",
		"slots_need": "The ship takes %d slots", "slots_have": "The fairing has %d slots",
		"to_dest": "Reaching %s takes %d m/s", "isp_line": "Engine Isp: %d s",
		"fuel_line": "Fuel needed %d kg; the tank holds %d kg", "dv_line": "With this tank: %d m/s",
		"tip_bar_carga": "What the rocket must lift (ship + fairing + dampers) against the lift of the engines and boosters.",
		"tip_bar_espacios": "Slots the ship takes against the slots inside the fairing. A bigger fairing costs more and weighs more.",
		"tip_bar_presupuesto": "Cost of the rocket against the budget the ship left over.",
		"tip_bar_combustible": "Fuel the trip needs against what the tank holds. Delta-v = Isp x g0 x ln(m_start / m_end): every extra kilogram of ship needs far more fuel.",
		"tip_cofia": "The fairing is the nose shell that protects the ship during ascent. Every ship part must fit inside it, and its own weight also has to be lifted.",
		"tip_motor": "The engine brings its own tank. Isp (specific impulse) is the push per kilogram of fuel: a higher Isp needs less fuel for the same trip.",
		"tip_booster": "Boosters add lift so heavier ships can leave the ground, but they burn out during ascent and add no fuel for the trip.",
		"tip_avionica": "The flight computer guides the rocket. Its reliability multiplies into the odds of a good launch; radiation-hardened ones also survive space weather.",
		"tip_proteccion": "Launch shakes everything. A damper reduces the vibration that can damage fragile parts of your ship."},
}
# Nombre visible de cada pestaña (tooltip de la pestaña y checklist).
const NOMBRES_SUB := {
	"es": {"cofia": "Cofia", "motor": "Motor", "booster": "Boosters", "avionica": "Computadora de vuelo", "proteccion": "Protección"},
	"en": {"cofia": "Fairing", "motor": "Engine", "booster": "Boosters", "avionica": "Flight computer", "proteccion": "Protection"},
}

@onready var grid_piezas: GridContainer = get_node_or_null("PanelPersonaliza/GridPiezas")
@onready var pestanas: VBoxContainer = get_node_or_null("Pestanas")
@onready var label_resumen: Label = find_child("LabelResumen", true, false) as Label
@onready var label_checklist: Label = find_child("LabelChecklist", true, false) as Label   # opcional
@onready var label_consejo: Label = find_child("LabelConsejo", true, false) as Label       # opcional

# ---------- Datos ----------
var estado = null             # el autoload GameState (null si no está registrado)
var cohete := {}              # id -> pieza (cohete.json)
var unidad_masa := 5.0        # kg por unidad de masa
var unidad_comb := 5.0        # kg por unidad de combustible
var g0 := 9.80665
var destinos := {}            # meta.destinos_delta_v_ms
var nave := {}                # lo guardado por la pantalla de la nave
var piezas_nave := {}         # id -> pieza, solo las que lleva la nave (para avisos de vulnerabilidad)
var destino := DESTINO_PRUEBA
var nave_masa := 0.0          # unidades del juego
var nave_slots := 0.0
var restante := 0.0           # presupuesto que dejó la nave
var requiere_nave: Array = [] # ids de cohete que la nave exige (ej. cofia_expandida)

# ---------- Estado de la pantalla ----------
var seleccion := []           # ids elegidos (sin tanques: el tanque lo agrega _ids_efectivos)
var slots: Array[Button] = []
var ids_en_slots := []
var barras := {}
var indicadores := {}         # subcategoría -> punto de color de su pestaña
var categoria_actual := 0     # índice de la pestaña visible
var boton_construir: Button
var boton_atras: Button
var construyendo := false     # evita pulsar "Crear" dos veces mientras se muestra el mensaje

var tooltip: PanelContainer
var tt_titulo: Label
var tt_resumen: Label
var tt_stats: Label
var tt_delta: Label           # efecto de elegir (o quitar) la pieza
var tt_aviso: Label

# Mensaje flotante (éxito / error al pulsar "Crear")
var mensaje: PanelContainer
var msg_estilo: StyleBoxFlat
var msg_titulo: Label
var msg_texto: Label
var msg_id := 0               # para que un mensaje viejo no oculte uno nuevo


func _ready() -> void:
	if not _nodos_ok():
		return
	estado = get_node_or_null("/root/GameState")
	if estado == null:
		push_warning("El autoload 'GameState' no está registrado (Proyecto > Configuración > Autoload): la misión no se conservará entre escenas.")
	_cargar_datos()
	_crear_tooltip()
	_crear_mensaje()
	grid_piezas.columns = COLUMNAS
	for l in [label_resumen, label_checklist, label_consejo]:
		if l:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(200, 0)
			l.add_theme_font_size_override("font_size", 14)
	preparar_casillas()
	preparar_pestanas()
	preparar_barras()
	preparar_botones()
	_seleccion_inicial()
	mostrar_categoria(0)
	actualizar_resumen()
	print("Cohete listo -> piezas: %d | nave: %d u, %d espacios, %s restantes | destino: %s" % [
		cohete.size(), int(nave_masa), int(nave_slots), _dinero(restante), destino])


func _process(_delta: float) -> void:
	if tooltip and tooltip.visible:
		_posicionar_tooltip()
	if mensaje and mensaje.visible:
		_centrar_mensaje()


func _s(clave: String) -> String:
	return String(TXT[idioma].get(clave, clave))


func _nombre_sub(sub: String) -> String:
	return String(NOMBRES_SUB[idioma].get(sub, sub))


func _nodos_ok() -> bool:
	var ok := true
	if grid_piezas == null:
		push_error("Falta el nodo 'PanelPersonaliza/GridPiezas' (GridContainer).")
		ok = false
	if pestanas == null:
		push_error("Falta el nodo 'Pestanas' (VBoxContainer).")
		ok = false
	if label_resumen == null:
		push_warning("Falta un Label llamado 'LabelResumen': no se mostrarán los errores y avisos.")
	return ok


# ---------- Carga de datos ----------

func _leer_json(ruta: String) -> Dictionary:
	if not FileAccess.file_exists(ruta):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	if typeof(d) == TYPE_DICTIONARY:
		return d
	return {}


func _cargar_datos() -> void:
	var dc := _leer_json(RUTA_JSON + ARCHIVO_COHETE + ".json")
	if dc.is_empty() or not dc.has("partes"):
		push_error("No se pudo cargar cohete.json en " + RUTA_JSON)
		return
	cohete = dc["partes"]
	var meta: Dictionary = dc.get("meta", {})
	unidad_masa = float(meta.get("unidad_masa_kg", 5.0))
	unidad_comb = float(meta.get("unidad_combustible_kg", unidad_masa))
	g0 = float(meta.get("g0_ms2", 9.80665))
	destinos = meta.get("destinos_delta_v_ms", {})
	if destinos.is_empty():
		push_warning("cohete.json no tiene meta.destinos_delta_v_ms: usa la versión con combustible.")

	# La nave sale primero de GameState (memoria); si no hay, del archivo en disco; si tampoco, una de prueba.
	nave = {}
	if estado != null and not estado.nave.is_empty():
		nave = estado.nave
	else:
		nave = _leer_json(RUTA_NAVE)
	if nave.is_empty():
		push_warning("No hay nave guardada: se usa una nave de prueba.")
		nave = {
			"tipo_mision": "robotica", "piezas": [],
			"totales": {"masa": 11.0, "slots": 4.0},
			"presupuesto_restante": 26000000.0,
			"requiere_cohete": [], "cohete_minimo": {"ids": []},
		}
	var tot: Dictionary = nave.get("totales", {})
	nave_masa = float(tot.get("masa", 0.0))
	nave_slots = float(tot.get("slots", 0.0))
	restante = float(nave.get("presupuesto_restante", 0.0))
	requiere_nave = nave.get("requiere_cohete", [])
	destino = String(nave.get("destino", DESTINO_PRUEBA))

	# Piezas de la nave (solo para avisar qué es vulnerable a los eventos del lanzamiento).
	var ids_nave: Array = nave.get("piezas", [])
	for nombre in ARCHIVOS_NAVE:
		var d := _leer_json(RUTA_JSON + nombre + ".json")
		for id in d.get("partes", {}):
			if ids_nave.has(id):
				piezas_nave[id] = d["partes"][id]


# Identifica a la nave por sus piezas: si cambia, el borrador del cohete deja de servir.
func _firma_nave() -> String:
	var ids: Array = nave.get("piezas", []).duplicate()
	ids.sort()
	return ",".join(PackedStringArray(ids))


func _guardar_borrador() -> void:
	if estado:
		estado.guardar_borrador_cohete(_firma_nave(), seleccion)


# Si el jugador ya había elegido un cohete para ESTA nave, se recupera; si no, arranca con el mínimo
# que calculó la pantalla de la nave (sin tanques: se agregan solos). Lo que falte se completa con lo más barato que sirva.
func _seleccion_inicial() -> void:
	seleccion.clear()
	var recuperada := false
	if estado:
		var guardada: Array = estado.cohete_borrador_para(_firma_nave())
		for id in guardada:
			if cohete.has(id) and cohete[id].get("subcategoria", "") != "tanque":
				seleccion.append(id)
		if not seleccion.is_empty():
			print("Cohete recuperado: %d piezas" % seleccion.size())
			recuperada = true
	if not recuperada:
		var minimo: Dictionary = nave.get("cohete_minimo", {})
		for id in minimo.get("ids", []):
			if cohete.has(id) and cohete[id].get("subcategoria", "") != "tanque":
				seleccion.append(id)
	_completar_seleccion()


# Para cada pieza "única" que falte (cofia, motor, computadora) elige la más barata que se pueda usar.
# En el motor prefiere uno que levante la carga y tenga combustible. Así la escena arranca con un cohete válido
# aunque la abras sola (sin pasar por la nave).
func _completar_seleccion() -> void:
	for sub in UNICAS:
		var ya := false
		for id in seleccion:
			if cohete[id].get("subcategoria", "") == sub:
				ya = true
		if ya:
			continue
		var mejor := ""
		var mejor_mal := true
		var mejor_precio := 0.0
		for id in cohete:
			if cohete[id].get("subcategoria", "") != sub or _razon_bloqueo(id) != "":
				continue
			var sim: Array = seleccion.duplicate()
			_aplicar_en(sim, id)
			var t := calcular(sim)
			var mal: bool = sub == "motor" and (t["carga"] > t["cap"] or t["necesario"] > t["cap_comb"])
			var precio := float(cohete[id]["precio_juego"])
			var gana := false
			if mejor == "":
				gana = true
			elif mejor_mal and not mal:
				gana = true
			elif mal == mejor_mal and precio < mejor_precio:
				gana = true
			if gana:
				mejor = id
				mejor_mal = mal
				mejor_precio = precio
		if mejor != "":
			seleccion.append(mejor)


# ---------- Reglas de selección ----------

func _nombre_corto(id: String) -> String:
	return String(cohete[id]["nombre"]).split(" (")[0]


func _nombres_cortos(ids: Array) -> PackedStringArray:
	var r := PackedStringArray()
	for i in ids:
		r.append(_nombre_corto(i) if cohete.has(i) else str(i))
	return r


func _kg(unidades: float) -> int:
	return roundi(unidades * unidad_masa)


func _kgc(unidades: float) -> int:
	return roundi(unidades * unidad_comb)


# Elegidas + el tanque que exige el motor.
func _ids_efectivos(sel: Array) -> Array:
	var r: Array = sel.duplicate()
	for id in sel:
		if cohete[id].get("subcategoria", "") == "motor":
			for t in cohete[id].get("requiere", []):
				if cohete.has(t) and not r.has(t):
					r.append(t)
	return r


# Agrega id a la lista sel; si es de las "únicas", quita la que había de esa subcategoría.
func _aplicar_en(sel: Array, id: String) -> void:
	var sub: String = cohete[id].get("subcategoria", "")
	if UNICAS.has(sub):
		for otro in sel.duplicate():
			if cohete[otro].get("subcategoria", "") == sub:
				sel.erase(otro)
	if not sel.has(id):
		sel.append(id)


func _dv_requerido() -> float:
	var d: Dictionary = destinos.get(destino, {})
	return float(d.get("cohete", 0.0))


# Todo lo que usan las barras, el resumen y el archivo guardado.
func calcular(sel: Array) -> Dictionary:
	var ids := _ids_efectivos(sel)
	var t := {"ids": ids, "cap": 0.0, "costo": 0.0, "extra": 0.0, "cap_slots": 0.0, "isp": 0.0,
		"cap_comb": 0.0, "fiab": 1.0, "subs": {}, "eventos": [], "mitiga": []}
	for id in ids:
		var q: Dictionary = cohete[id]
		var sub: String = q.get("subcategoria", "")
		t["subs"][sub] = id
		t["cap"] += float(q.get("aporta_capacidad_masa", 0.0)) + float(q.get("ajuste_capacidad_masa", 0.0))
		t["costo"] += float(q["precio_juego"])
		if q.get("masa_cuenta_como_carga", true):
			t["extra"] += float(q["masa"])         # cofia, amortiguador: su masa también hay que levantarla
		t["cap_comb"] += float(q.get("capacidad_combustible", 0.0))
		if sub == "cofia":
			t["cap_slots"] = float(q.get("capacidad_slots", 0.0))
		if sub == "motor":
			t["isp"] = float(q.get("isp_vacio_real_s", 0.0))
		if q.has("fiabilidad"):
			t["fiab"] *= float(q["fiabilidad"])
		if q.has("genera_evento"):
			t["eventos"].append(String(q["genera_evento"]))
		for e in q.get("mitiga", []):
			if not t["mitiga"].has(e):
				t["mitiga"].append(e)

	t["carga"] = nave_masa + t["extra"]
	# Combustible: m_final * (e^(dv / (isp*g0)) - 1). m_final = la nave (la cofia ya se soltó).
	var isp: float = t["isp"]
	var dv_req := _dv_requerido()
	t["dv_req"] = dv_req
	t["necesario"] = 0.0
	t["dv_disp"] = 0.0
	if isp > 0.0 and nave_masa > 0.0:
		t["necesario"] = nave_masa * (exp(dv_req / (isp * g0)) - 1.0)
		t["dv_disp"] = isp * g0 * log((nave_masa + float(t["cap_comb"])) / nave_masa)
	return t


# ---------- Bloqueo de piezas ----------

# "" si la pieza se puede elegir; si no, el motivo.
func _razon_bloqueo(id: String) -> String:
	if seleccion.has(id):
		return ""
	var q: Dictionary = cohete[id]
	var sub: String = q.get("subcategoria", "")
	if sub == "cofia":
		for r in requiere_nave:
			if cohete.has(r) and cohete[r].get("subcategoria", "") == "cofia" and r != id:
				return _s("blk_needs") % cohete[r]["nombre"]
		if nave_slots > float(q.get("capacidad_slots", 0.0)):
			return _s("blk_slots") % int(nave_slots)
	var alguno: Array = q.get("requiere_alguno_de", [])
	if alguno.size() > 0:
		var hay := false
		for r in alguno:
			if seleccion.has(r):
				hay = true
		if not hay:
			return _s("blk_engine")
	if BLOQUEAR_SI_EXCEDE_PRESUPUESTO:
		var sim: Array = seleccion.duplicate()
		_aplicar_en(sim, id)
		var costo := 0.0
		for x in _ids_efectivos(sim):
			costo += float(cohete[x]["precio_juego"])
		var falta := costo - restante
		if falta > 0.0:
			return _s("blk_budget") % _dinero(falta)
	return ""


func _refrescar_casillas() -> void:
	for i in slots.size():
		var boton := slots[i]
		if i < ids_en_slots.size():
			var id: String = ids_en_slots[i]
			boton.disabled = _razon_bloqueo(id) != ""
			boton.set_pressed_no_signal(seleccion.has(id))
		else:
			boton.disabled = true
			boton.set_pressed_no_signal(false)


func _on_casilla_presionada(i: int) -> void:
	if i >= ids_en_slots.size():
		return
	var id: String = ids_en_slots[i]
	var sub: String = cohete[id].get("subcategoria", "")
	if slots[i].button_pressed:
		if _razon_bloqueo(id) != "":
			slots[i].set_pressed_no_signal(false)
			return
		_aplicar_en(seleccion, id)
	else:
		if UNICAS.has(sub):
			slots[i].set_pressed_no_signal(true)   # una "única" no se puede dejar vacía: se cambia por otra
			return
		seleccion.erase(id)
	_guardar_borrador()        # así, si el jugador vuelve "atrás", no pierde lo elegido
	_refrescar_casillas()
	actualizar_resumen()


# ---------- Conexión con los botones que acomodaste ----------

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
		boton.custom_minimum_size = TAM_CASILLA
		boton.pivot_offset = TAM_CASILLA / 2.0
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
	var grupo := ButtonGroup.new()
	var i := 0
	for hijo in pestanas.get_children():
		var boton := hijo as Button
		if boton == null:
			continue
		if i >= CATEGORIAS.size():
			boton.visible = false          # pestaña sobrante
			continue
		boton.toggle_mode = true
		boton.button_group = grupo
		boton.button_pressed = (i == 0)
		boton.focus_mode = Control.FOCUS_NONE
		boton.custom_minimum_size = TAM_PESTANA
		boton.tooltip_text = _nombre_sub(CATEGORIAS[i])
		_ignorar_mouse_en_hijos(boton)
		if ESTILO_POR_CODIGO:
			_estilo_pestana(boton, colores_pestana[i])
		_crear_indicador(boton, CATEGORIAS[i])      # después del estilo, que oculta los ColorRect hijos
		boton.pressed.connect(mostrar_categoria.bind(i))
		i += 1


# Punto de color en la esquina de la pestaña: verde = listo, amarillo = falta o aviso, rojo = error, gris = opcional.
func _crear_indicador(boton: Button, sub: String) -> void:
	var punto := ColorRect.new()
	punto.custom_minimum_size = TAM_INDICADOR
	punto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	punto.color = COLOR_OPCIONAL
	boton.add_child(punto)
	punto.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	indicadores[sub] = punto


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
		barra.show_percentage = false
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
		texto.add_theme_font_override("font", barra.get_theme_font("font"))
		texto.add_theme_font_size_override("font_size", barra.get_theme_font_size("font_size"))
		texto.add_theme_color_override("font_color", barra.get_theme_color("font_color"))
		texto.add_theme_color_override("font_outline_color", Color("2e2220"))
		texto.add_theme_constant_override("outline_size", 1)

		barras[clave] = {"barra": barra, "relleno": relleno, "texto": texto}


# "BotonConstruir" crea el cohete. "BotonAtras" es opcional.
func preparar_botones() -> void:
	boton_construir = find_child("BotonConstruir", true, false) as Button
	if boton_construir:
		boton_construir.pressed.connect(_on_lanzar)
	else:
		push_warning("Nombra 'BotonConstruir' al botón de avanzar.")
	boton_atras = find_child("BotonAtras", true, false) as Button
	if boton_atras:
		boton_atras.pressed.connect(_on_atras)


# Volver a la nave: lo elegido (nave y cohete) queda guardado en GameState.
func _on_atras() -> void:
	_guardar_borrador()
	var ruta_nave := escena_nave if escena_nave != "" else "res://Screens/build_rocket.tscn"
	var err := get_tree().change_scene_to_file(ruta_nave)
	if err != OK:
		push_error("Error al volver a la nave. Revisa que la ruta exista: " + ruta_nave)


# ---------- Crear el cohete ----------
func _on_lanzar() -> void:
	if construyendo:
		return
	# Se valida OTRA VEZ al pulsar: no nos fiamos solo de que el botón estuviera habilitado.
	var t := calcular(seleccion)
	var ev := evaluar(t)
	if ev["errores"].size() > 0:
		_mostrar_mensaje(_s("build_fail"), ev["errores"][0], false, DURACION_MENSAJE)
		return
	var datos := guardar_cohete()
	if datos.is_empty():
		_mostrar_mensaje(_s("build_fail"), _s("save_fail"), false, DURACION_MENSAJE)
		return
	construyendo = true
	if boton_construir:
		boton_construir.disabled = true
	cohete_construido.emit(datos)
	_mostrar_mensaje(_s("built_title"), _texto_exito(t), true, 0.0)
	await get_tree().create_timer(DURACION_MENSAJE).timeout
	mensaje.hide()
	construyendo = false
	actualizar_resumen()

	# Deja programado el teletransporte de main_character a (845, 160)
	GameManager.solicitar_teletransporte_player(Vector2(845, 160))

	# Si space_center sigue cargado detrás (en GUI), solo oculta el panel;
	# si se descargó al cambiar de escena, vuelve a cargar space_center.tscn.
	var escena_actual := get_tree().current_scene
	var player_en_escena := escena_actual != null and (
		escena_actual.find_child("main_character", true, false) != null or
		escena_actual.find_child("MainCharacter", true, false) != null or
		get_tree().get_first_node_in_group("player") != null
	)

	if player_en_escena:
		hide()
	elif escena_siguiente != "":
		get_tree().change_scene_to_file(escena_siguiente)
	else:
		push_error("Asigna 'space_center.tscn' en la propiedad 'Escena Siguiente' del Inspector.")


# Guarda el lanzamiento (con la nave adentro, para que la etapa siguiente solo lea este archivo)
# y lo registra en GameState como la misión lista.
func guardar_cohete() -> Dictionary:
	var t := calcular(seleccion)
	var datos := {
		"version": 1,
		"destino": destino,
		"piezas": t["ids"],
		"motor": t["subs"].get("motor", ""),
		"tanque": t["subs"].get("tanque", ""),
		"totales": {
			"capacidad_masa": t["cap"],       # unidades del juego
			"carga": t["carga"],
			"costo": t["costo"],
			"espacios_cofia": t["cap_slots"],
		},
		"combustible": {
			"isp_s": t["isp"],
			"capacidad_kg": t["cap_comb"] * unidad_comb,
			"necesario_kg": t["necesario"] * unidad_comb,
			"dv_disponible_ms": t["dv_disp"],
			"dv_requerido_ms": t["dv_req"],
		},
		"presupuesto_restante": restante - t["costo"],
		"fiabilidad": t["fiab"],
		"eventos_lanzamiento": t["eventos"],   # ej. ["vibracion_lanzamiento"]
		"mitiga": t["mitiga"],                 # eventos que el cohete ya neutraliza
		"nave": nave,
	}
	var archivo := FileAccess.open(RUTA_LANZAMIENTO, FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo guardar el cohete en %s (error %d)." % [RUTA_LANZAMIENTO, FileAccess.get_open_error()])
		return {}
	archivo.store_string(JSON.stringify(datos, "\t"))
	archivo.close()
	print("Cohete guardado en: ", ProjectSettings.globalize_path(RUTA_LANZAMIENTO))
	if estado:
		estado.registrar_cohete(datos)     # la misión (nave + cohete) queda en el autoload
	# --- Registrar cohete, fiabilidad y vulnerabilidades en GameManager ---
	var avisos_cohete: Array = evaluar(t)["avisos"]
	var riesgo_por_fiabilidad := (1.0 - float(t["fiab"])) * 100.0
	var riesgo_total_cohete := riesgo_por_fiabilidad + (float(avisos_cohete.size()) * 5.0)
	var texto_avisos := ", ".join(PackedStringArray(avisos_cohete))
	GameManager.registrar_cohete(riesgo_total_cohete, texto_avisos, datos)
	# ----------------------------------------------------------------------------
	return datos


# ---------- Mensaje flotante (éxito / error) ----------

func _crear_mensaje() -> void:
	mensaje = PanelContainer.new()
	mensaje.top_level = true
	mensaje.z_index = 60
	mensaje.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mensaje.custom_minimum_size = Vector2(110, 0)
	msg_estilo = StyleBoxFlat.new()
	msg_estilo.bg_color = Color("2e2220")
	msg_estilo.border_color = COLOR_OK
	msg_estilo.set_border_width_all(2)
	msg_estilo.set_content_margin_all(4)
	mensaje.add_theme_stylebox_override("panel", msg_estilo)
	var caja := VBoxContainer.new()
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mensaje.add_child(caja)
	msg_titulo = _nueva_etiqueta(Color("b7f0c4"), 5)
	msg_titulo.custom_minimum_size.x = 100   # ancho fijo: el autowrap ya no empieza en 0
	msg_texto = _nueva_etiqueta(Color("f2e6d8"), 3)
	msg_texto.custom_minimum_size.x = 100
	caja.add_child(msg_titulo)
	caja.add_child(msg_texto)
	mensaje.hide()
	add_child(mensaje)


# segundos > 0: se oculta solo (para errores). segundos = 0: se queda hasta que se oculte por código.
func _mostrar_mensaje(titulo: String, texto: String, exito: bool, segundos: float) -> void:
	msg_id += 1
	var mi_id := msg_id
	msg_titulo.text = titulo
	msg_texto.text = texto
	msg_texto.visible = texto != ""
	msg_estilo.border_color = COLOR_OK if exito else COLOR_MAL
	msg_titulo.add_theme_color_override("font_color", Color("b7f0c4") if exito else Color("ff9d8a"))
	mensaje.modulate.a = 0.0
	mensaje.show()
	await get_tree().process_frame      # el layout se calcula con el ancho real
	await get_tree().process_frame
	if mi_id != msg_id:
		return                          # llegó otro mensaje mientras esperábamos
	mensaje.reset_size()
	_centrar_mensaje()
	create_tween().tween_property(mensaje, "modulate:a", 1.0, 0.15)
	if segundos > 0.0:
		get_tree().create_timer(segundos).timeout.connect(_ocultar_mensaje_si.bind(mi_id))


func _ocultar_mensaje_si(id: int) -> void:
	if id == msg_id:
		mensaje.hide()


func _centrar_mensaje() -> void:
	var pantalla := get_viewport_rect().size
	mensaje.global_position = ((pantalla - mensaje.size) / 2.0).floor()


func _texto_exito(t: Dictionary) -> String:
	var s := _s("built_ready") + "\n"
	s += _s("dv") % [int(t["dv_disp"]), int(t["dv_req"])] + "\n"
	s += _s("reliab") % int(round(float(t["fiab"]) * 100.0)) + "\n"
	s += _s("budget_left") % _dinero(restante - t["costo"])
	return s


# ---------- Estilos ----------

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


func _estilo_pestana(boton: Button, color: Color) -> void:
	for hijo in boton.get_children():
		if hijo is ColorRect:
			hijo.visible = false
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


# ---------- Casillas por pestaña ----------

func mostrar_categoria(indice: int) -> void:
	tooltip.hide()
	categoria_actual = indice
	var sub: String = CATEGORIAS[indice]
	ids_en_slots.clear()
	for id in cohete:
		if cohete[id].get("subcategoria", "") == sub:
			ids_en_slots.append(id)
	if ids_en_slots.size() > slots.size():
		push_warning("'%s' tiene %d piezas pero solo hay %d casillas." % [sub, ids_en_slots.size(), slots.size()])
	for i in slots.size():
		var boton := slots[i]
		boton.scale = Vector2.ONE
		if i < ids_en_slots.size():
			var id: String = ids_en_slots[i]
			var ruta_icono := "res://icons/%s.png" % id
			if ResourceLoader.exists(ruta_icono):
				boton.icon = load(ruta_icono)
				boton.text = ""
			else:
				boton.icon = null
				boton.text = _nombre_corto(id)
		else:
			boton.text = ""
			boton.icon = null
	_refrescar_casillas()
	actualizar_resumen()      # el consejo (TIP) cambia con la pestaña


# ---------- Hover y tooltip ----------

func _on_casilla_hover(i: int) -> void:
	if i < ids_en_slots.size():
		_mostrar_tooltip(ids_en_slots[i])
		if not slots[i].disabled:
			_animar(slots[i], 1.08)


func _on_casilla_salida(i: int) -> void:
	tooltip.hide()
	_animar(slots[i], 1.0)


func _animar(boton: Control, escala: float) -> void:
	var tw := create_tween()
	tw.tween_property(boton, "scale", Vector2(escala, escala), 0.08)


func _crear_tooltip() -> void:
	tooltip = PanelContainer.new()
	tooltip.top_level = true
	tooltip.z_index = 22
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.custom_minimum_size = Vector2(40, 40)
	var estilo := StyleBoxFlat.new()
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


# Una línea con lo que importa de cada pieza del cohete.
func _stats_pieza(id: String) -> String:
	var q: Dictionary = cohete[id]
	var partes := PackedStringArray()
	partes.append(_dinero(q["precio_juego"]))
	var lift := float(q.get("aporta_capacidad_masa", 0.0)) + float(q.get("ajuste_capacidad_masa", 0.0))
	if lift != 0.0:
		partes.append("Lift %+d kg" % _kg(lift))
	if q.has("capacidad_slots"):
		partes.append("Slots %d" % int(q["capacidad_slots"]))
	if q.has("isp_vacio_real_s"):
		partes.append("Isp %d s" % int(q["isp_vacio_real_s"]))
	for r in q.get("requiere", []):       # el motor muestra el combustible de su tanque
		if cohete.has(r) and cohete[r].has("capacidad_combustible"):
			partes.append("Fuel %d kg" % _kgc(float(cohete[r]["capacidad_combustible"])))
	if q.get("masa_cuenta_como_carga", true) and float(q["masa"]) > 0.0:
		partes.append("Mass %d kg" % _kg(float(q["masa"])))
	return " | ".join(partes)


func _mostrar_tooltip(id: String) -> void:
	var q: Dictionary = cohete[id]
	tt_titulo.text = q["nombre"]
	tt_resumen.text = q.get("resumen", "")
	tt_resumen.visible = tt_resumen.text != ""
	tt_stats.text = _stats_pieza(id)
	tt_delta.text = _delta_texto(id)
	tt_delta.visible = tt_delta.text != ""
	tt_aviso.text = _razon_bloqueo(id)
	tt_aviso.visible = tt_aviso.text != ""
	tooltip.reset_size()
	tooltip.show()
	_posicionar_tooltip()


# EFECTO de elegir la pieza (o de quitarla, si es opcional y ya está elegida): sustentación libre, delta-v, costo y fiabilidad.
# Muestra los compromisos del diseño: un motor mejor sube el costo, un booster suma sustentación pero no combustible, etc.
func _delta_texto(id: String) -> String:
	var sub: String = cohete[id].get("subcategoria", "")
	var quitando := seleccion.has(id)
	if quitando and UNICAS.has(sub):
		return ""     # ya está elegida y las "únicas" no se pueden dejar vacías
	var antes := calcular(seleccion)
	var sim: Array = seleccion.duplicate()
	if quitando:
		sim.erase(id)
	else:
		_aplicar_en(sim, id)
	var despues := calcular(sim)
	var s := _s("d_remove") if quitando else _s("d_add")
	s += "\n" + _s("d_lift") % [_kg(antes["cap"] - antes["carga"]), _kg(despues["cap"] - despues["carga"])]
	s += " | " + _s("d_dv") % [int(antes["dv_disp"]), int(despues["dv_disp"]), int(despues["dv_req"])]
	s += "\n" + _s("d_cost") % [_dinero(antes["costo"]), _dinero(despues["costo"])]
	s += " | " + _s("d_rel") % [roundi(float(antes["fiab"]) * 100.0), roundi(float(despues["fiab"]) * 100.0)]
	return s


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


# ---------- Validación, barras y resumen ----------

# Registra un error. clave = renglón del checklist al que pertenece ("" = no pertenece a ninguno).
func _anotar(res: Dictionary, clave: String, msg: String) -> void:
	res["errores"].append(msg)
	if clave == "":
		res["globales"].append(msg)
		return
	if not res["por_clave"].has(clave):
		res["por_clave"][clave] = []
	res["por_clave"][clave].append(msg)


# Revisa TODO lo que debe cumplir el cohete. Devuelve:
#   errores   = todos (impiden crear el cohete)
#   avisos    = solo informan
#   globales  = errores que no pertenecen a un renglón del checklist
#   por_clave = renglón del checklist -> errores de ese renglón
#   vuln      = cuántas piezas de la nave son vulnerables a un evento que el cohete no mitiga
func evaluar(t: Dictionary) -> Dictionary:
	var subs: Dictionary = t["subs"]
	var res := {"errores": [], "avisos": [], "globales": [], "por_clave": {}, "vuln": 0}

	# 1) Piezas obligatorias
	for sub in UNICAS:
		if not subs.has(sub):
			_anotar(res, sub, _s("missing") % _nombre_sub(sub).to_lower())

	# 2) Límites físicos contra la nave
	if subs.has("motor"):
		if t["carga"] > t["cap"]:
			_anotar(res, "carga", _s("overweight") % [_kg(t["carga"]), _kg(t["cap"])])
		if t["necesario"] > t["cap_comb"]:
			_anotar(res, "combustible", _s("no_fuel") % [_kgc(t["necesario"]), _kgc(t["cap_comb"])])
	if subs.has("cofia") and nave_slots > t["cap_slots"]:
		_anotar(res, "cofia", _s("no_slots") % [int(nave_slots), int(t["cap_slots"])])
	for r in requiere_nave:
		if cohete.has(r) and not t["ids"].has(r):
			_anotar(res, String(cohete[r].get("subcategoria", "")), _s("needs") % cohete[r]["nombre"])
	if t["costo"] > restante:
		_anotar(res, "presupuesto", _s("over_budget") % [_dinero(t["costo"]), _dinero(restante)])

	# 3) Compatibilidad entre las piezas del cohete (requiere / requiere_alguno_de / incompatible)
	for id in t["ids"]:
		var q: Dictionary = cohete[id]
		var sub_q: String = q.get("subcategoria", "")
		for r in q.get("requiere", []):
			if cohete.has(r) and not t["ids"].has(r):
				_anotar(res, sub_q, _s("req") % [_nombre_corto(id), _nombre_corto(r)])
		var alguno: Array = q.get("requiere_alguno_de", [])
		if alguno.size() > 0:
			var hay := false
			for r in alguno:
				if t["ids"].has(r):
					hay = true
			if not hay:
				_anotar(res, sub_q, _s("req_one") % [_nombre_corto(id), ", ".join(_nombres_cortos(alguno))])
		for inc in q.get("incompatible", []):
			if t["ids"].has(inc):
				_anotar(res, sub_q, _s("incomp") % [_nombre_corto(id), _nombre_corto(inc)])

	# 4) Avisos: penalizaciones del cohete (mirando también las piezas de la nave) y piezas vulnerables.
	var todos: Array = t["ids"].duplicate()
	todos.append_array(nave.get("piezas", []))
	for id in t["ids"]:
		for pe in cohete[id].get("penalizaciones", []):
			if String(pe.get("efecto", "")).begins_with("danio_a_piezas"):
				continue     # ese caso se avisa abajo, nombrando la pieza afectada
			var falta := false
			if pe.has("si_falta"):
				falta = not todos.has(pe["si_falta"])
			elif pe.has("si_falta_ninguno_de"):
				falta = true
				for x in pe["si_falta_ninguno_de"]:
					if todos.has(x):
						falta = false
			if falta:
				res["avisos"].append("%s: %s" % [_nombre_corto(id), String(pe["efecto"]).replace("_", " ")])
	for ev in t["eventos"]:
		if t["mitiga"].has(ev):
			continue
		for pid in piezas_nave:
			if piezas_nave[pid].get("vulnerable_a", []).has(ev):
				res["avisos"].append(_s("vuln") % [piezas_nave[pid]["nombre"], String(ev).replace("_", " ")])
				res["vuln"] += 1
	return res


# Un renglón por requisito: [x] listo, [ ] falta, [!] error, [~] aviso, [-] opcional sin elegir.
# Devuelve [{"clave", "nombre", "estado", "detalle"}, ...] en el orden de FILAS.
func _filas_checklist(t: Dictionary, ev: Dictionary) -> Array:
	var subs: Dictionary = t["subs"]
	var por: Dictionary = ev["por_clave"]
	var filas := []
	for clave in FILAS:
		var nombre := ""
		if CATEGORIAS.has(clave):
			nombre = _nombre_sub(clave)
		else:
			nombre = _s("row_" + clave)
		var st := "ok"
		var detalle := ""
		match clave:
			"cofia":
				if not subs.has("cofia"):
					st = "falta"
				else:
					detalle = _s("fairing_detail") % [int(nave_slots), int(t["cap_slots"])]
			"motor":
				if not subs.has("motor"):
					st = "falta"
				else:
					detalle = _s("engine_detail") % [int(t["isp"]), _kgc(t["cap_comb"])]
			"avionica":
				if not subs.has("avionica"):
					st = "falta"
				else:
					detalle = _nombre_corto(subs["avionica"])
			"booster":
				if subs.has("booster"):
					var b: Dictionary = cohete[subs["booster"]]
					detalle = _s("boost_detail") % _kg(float(b.get("aporta_capacidad_masa", 0.0)))
				else:
					st = "opcional"
					detalle = _s("optional")
			"proteccion":
				if subs.has("proteccion"):
					detalle = _nombre_corto(subs["proteccion"])
				elif int(ev["vuln"]) > 0:
					st = "aviso"
					detalle = _s("prot_hint")
				else:
					st = "opcional"
					detalle = _s("optional")
			"carga":
				if not subs.has("motor"):
					st = "falta"
					detalle = _s("need_engine")
				else:
					detalle = "%d / %d kg" % [_kg(t["carga"]), _kg(t["cap"])]
			"combustible":
				if not subs.has("motor"):
					st = "falta"
					detalle = _s("need_engine")
				else:
					detalle = _s("dv") % [int(t["dv_disp"]), int(t["dv_req"])]
			"presupuesto":
				detalle = _s("budget_left") % _dinero(restante - t["costo"])
		if st != "falta" and por.has(clave):
			st = "error"
			var msgs: Array = por[clave]
			detalle = String(msgs[0])
			if msgs.size() > 1:
				detalle += _s("more_errs") % (msgs.size() - 1)
		if st == "falta" and detalle == "":
			detalle = _s("add_one")
		filas.append({"clave": clave, "nombre": nombre, "estado": st, "detalle": detalle})
	return filas


func _texto_checklist(filas: Array) -> String:
	var marcas := {"ok": "[x]", "falta": "[ ]", "error": "[!]", "aviso": "[~]", "opcional": "[-]"}
	var txt := _s("check") + "\n"
	for f in filas:
		txt += "%s %s: %s\n" % [marcas[f["estado"]], f["nombre"], f["detalle"]]
	return txt


# Punto de color de cada pestaña = el peor estado de los renglones que le tocan.
func _actualizar_indicadores(filas: Array) -> void:
	var rango := {"opcional": 0, "ok": 1, "aviso": 2, "falta": 3, "error": 4}
	var peor := {}
	for f in filas:
		var tab: String = PESTANA_DE_FILA.get(f["clave"], "")
		if tab == "":
			continue
		if not peor.has(tab) or rango[f["estado"]] > rango[peor[tab]]:
			peor[tab] = f["estado"]
	for sub in indicadores:
		var punto: ColorRect = indicadores[sub]
		match String(peor.get(sub, "ok")):
			"error":
				punto.color = COLOR_MAL
			"falta", "aviso":
				punto.color = COLOR_CERCA
			"opcional":
				punto.color = COLOR_OPCIONAL
			_:
				punto.color = COLOR_OK


func _actualizar_barra(clave: String, usado: float, maximo: float, texto: String) -> void:
	if not barras.has(clave):
		return
	var b: Dictionary = barras[clave]
	var pct := 0.0
	if maximo > 0.0:
		pct = usado / maximo * 100.0
	elif usado > 0.0:
		pct = 101.0
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


# Tooltip de la barra: qué mide + el desglose de dónde sale cada número.
func _tooltip_barra(clave: String, detalle: String) -> void:
	if not barras.has(clave):
		return
	var barra: ProgressBar = barras[clave]["barra"]
	var base := _s("tip_bar_" + clave)
	barra.tooltip_text = base if detalle == "" else base + "\n\n" + detalle


func _desglose(clave: String, t: Dictionary) -> String:
	var lineas := PackedStringArray()
	match clave:
		"carga":
			lineas.append(_s("ship_kg") % _kg(nave_masa))
			for id in t["ids"]:
				var q: Dictionary = cohete[id]
				if q.get("masa_cuenta_como_carga", true) and float(q["masa"]) > 0.0:
					lineas.append(_s("mass_line") % [_nombre_corto(id), _kg(float(q["masa"]))])
			for id in t["ids"]:
				var q: Dictionary = cohete[id]
				var lift := float(q.get("aporta_capacidad_masa", 0.0)) + float(q.get("ajuste_capacidad_masa", 0.0))
				if lift != 0.0:
					lineas.append(_s("lift_line") % [_nombre_corto(id), _kg(lift)])
		"espacios":
			lineas.append(_s("slots_need") % int(nave_slots))
			lineas.append(_s("slots_have") % int(t["cap_slots"]))
		"presupuesto":
			for id in t["ids"]:
				lineas.append("%s: %s" % [_nombre_corto(id), _dinero(cohete[id]["precio_juego"])])
		"combustible":
			lineas.append(_s("to_dest") % [destino.replace("_", " "), int(t["dv_req"])])
			if float(t["isp"]) > 0.0:
				lineas.append(_s("isp_line") % int(t["isp"]))
			lineas.append(_s("fuel_line") % [_kgc(t["necesario"]), _kgc(t["cap_comb"])])
			lineas.append(_s("dv_line") % int(t["dv_disp"]))
	return "\n".join(lineas)


func actualizar_resumen() -> void:
	var t := calcular(seleccion)

	_actualizar_barra("carga", t["carga"], t["cap"],
		"%d / %d kg" % [_kg(t["carga"]), _kg(t["cap"])])
	_actualizar_barra("espacios", nave_slots, t["cap_slots"],
		"%d / %d" % [int(nave_slots), int(t["cap_slots"])])
	_actualizar_barra("presupuesto", t["costo"], restante,
		"%s / %s" % [_dinero(t["costo"]), _dinero(restante)])
	_actualizar_barra("combustible", t["necesario"], t["cap_comb"],
		"%d / %d kg" % [_kgc(t["necesario"]), _kgc(t["cap_comb"])])
	for clave in NOMBRES_BARRAS:
		_tooltip_barra(clave, _desglose(clave, t))

	var ev := evaluar(t)
	var filas := _filas_checklist(t, ev)
	_actualizar_indicadores(filas)

	var ns := PackedStringArray()
	for id in t["ids"]:
		ns.append(_nombre_corto(id))
	var txt := "%s: %s\n" % [_s("rocket"), ", ".join(ns)]
	txt += _s("dest") % destino.replace("_", " ") + "\n"
	txt += _s("dv") % [int(t["dv_disp"]), int(t["dv_req"])] + "\n"
	txt += _s("reliab") % int(round(float(t["fiab"]) * 100.0)) + "\n"
	var lista := _texto_checklist(filas)
	if label_checklist:
		label_checklist.text = lista
	else:
		txt += "\n" + lista
	for e in ev["globales"]:
		txt += _s("err") + ": " + e + "\n"
	for a in ev["avisos"]:
		txt += _s("warn") + ": " + a + "\n"
	var consejo := _s("tip_" + String(CATEGORIAS[categoria_actual]))
	if label_consejo:
		label_consejo.text = consejo
	else:
		txt += "\n" + _s("tip") + ": " + consejo
	if label_resumen:
		label_resumen.text = txt
	if boton_construir:
		boton_construir.disabled = ev["errores"].size() > 0 or construyendo
