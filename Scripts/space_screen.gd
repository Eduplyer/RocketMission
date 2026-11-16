extends Control

# Señales listas para conectar tus pantallas de Win / Game Over
signal mision_completada(resumen: Dictionary)
signal mision_fallida(motivo: String, resumen: Dictionary)

@export_group("Archivo JSON y Eventos")
@export_file("*.json") var ruta_json := "res://Assets/eventos_aleatorios.json"
@export var min_eventos := 5
@export var max_eventos := 9

@export_group("Ajustes de Vuelo")
@export var segundos_por_dia := 2.0
@export var margen_x_inicio := 42.0
@export var margen_x_fin := 278.0

@export_group("Modo Prueba (Ejecutar solo esta escena con F6)")
@export var nombre_mision_prueba := "Project Minerva II (Test)"
@export var dias_mision_prueba := 9

# Referencias exactas a los nodos de tu árbol
@onready var nave: Sprite2D = $NinePatchRect/Sprite2D
@onready var slider_progreso: HSlider = $NinePatchRect/ProgresoSlider
@onready var label_hud: Label = $NinePatchRect/LabelHUD
@onready var popup_evento: Panel = $NinePatchRect/PopUpEvento
@onready var titulo_alerta: Label = $NinePatchRect/PopUpEvento/VBoxContainer/Titulo
@onready var descripcion_evento: RichTextLabel = $NinePatchRect/PopUpEvento/VBoxContainer/Descripcion
@onready var botones_opcion: Array[Button] = [
	$NinePatchRect/PopUpEvento/VBoxContainer/Opcion1,
	$NinePatchRect/PopUpEvento/VBoxContainer/Opcion2,
	$NinePatchRect/PopUpEvento/VBoxContainer/Opcion3
]

# Variables internas del vuelo
var duracion_dias: int = 10
var velocidad_slider: float = 5.0
var integridad: int = 100
var fallos_cometidos: int = 0
var vuelo_activo: bool = false
var en_pausa_evento: bool = false
var tiempo_vuelo: float = 0.0
var y_base_nave: float = 90.0

var cola_eventos: Array[Dictionary] = []
var indice_evento_actual: int = 0

const OPCIONES_POR_EVENTO := {
	# --- RIESGOS TRIPULACIÓN (IDs 1 a 15) ---
	"tripulacion_1": [
		{"texto": "Execute anti-G straining & paced breathing", "dano": 0},
		{"texto": "Lean forward to reach manual switches", "dano": 15},
		{"texto": "Hold breath and tense neck muscles", "dano": 20}
	],
	"tripulacion_2": [
		{"texto": "Lock harness, tuck chin & brace for LES impact", "dano": 0},
		{"texto": "Attempt manual stage separation early", "dano": 40},
		{"texto": "Unbuckle harness to reach abort panel", "dano": 45}
	],
	"tripulacion_3": [
		{"texto": "Angle shielded hull & accelerate belt transit", "dano": 0},
		{"texto": "Throttle down to save fuel inside belt", "dano": 25},
		{"texto": "Open optical sensors for belt telemetry", "dano": 20}
	],
	"tripulacion_4": [
		{"texto": "Seal visor & apply emergency hull patch", "dano": 0},
		{"texto": "Search cabin for puncture point first", "dano": 50},
		{"texto": "Vent remaining cabin air to equalize", "dano": 60}
	],
	"tripulacion_5": [
		{"texto": "Start 100% pure O2 purge & repressurize", "dano": 0},
		{"texto": "Lower suit pressure to ease joint pain", "dano": 30},
		{"texto": "Continue EVA and check vitals later", "dano": 35}
	],
	"tripulacion_6": [
		{"texto": "Abort EVA immediately & enter storm core", "dano": 0},
		{"texto": "Finish external repair before airlock", "dano": 45},
		{"texto": "Take anti-nausea meds in outer module", "dano": 40}
	],
	"tripulacion_7": [
		{"texto": "Isolate shorted bus & run backup scrubbers", "dano": 0},
		{"texto": "Set cabin circulation fans to max speed", "dano": 25},
		{"texto": "Vent pure O2 reserves into cabin", "dano": 30}
	],
	"tripulacion_8": [
		{"texto": "Enforce resistive exercise & sleep schedule", "dano": 0},
		{"texto": "Skip workouts to conserve crew rations", "dano": 15},
		{"texto": "Administer heavy sedatives for sleep", "dano": 20}
	],
	"tripulacion_9": [
		{"texto": "Strap into crash couches & secure gear", "dano": 0},
		{"texto": "Override autopilot to cancel RCS burn", "dano": 35},
		{"texto": "Brace against metallic bulkhead rails", "dano": 30}
	],
	"tripulacion_10": [
		{"texto": "Use gyro horizon & trim pitch by 1.5 deg", "dano": 0},
		{"texto": "Wait for ground radio lock before trim", "dano": 50},
		{"texto": "Pitch nose steeply down for early entry", "dano": 55}
	],
	"tripulacion_11": [
		{"texto": "Recline seats, inflate G-suits & arm auto-chutes", "dano": 0},
		{"texto": "Sit upright to time chute release manually", "dano": 35},
		{"texto": "Delay drogue chute to reduce air drag", "dano": 40}
	],
	"tripulacion_12": [
		{"texto": "Divert power to shield & deploy backup chutes", "dano": 0},
		{"texto": "Jettison heat shield early to shed mass", "dano": 65},
		{"texto": "Cut main lines before backup inflates", "dano": 60}
	],
	"tripulacion_13": [
		{"texto": "Remain strapped in seat & await recovery team", "dano": 0},
		{"texto": "Stand up immediately to open main hatch", "dano": 20},
		{"texto": "Remove G-suit and exit capsule alone", "dano": 25}
	],
	"tripulacion_14": [
		{"texto": "Fix gaze on horizon & keep head still", "dano": 0},
		{"texto": "Walk around cabin to regain balance", "dano": 20},
		{"texto": "Make rapid head turns to reset inner ear", "dano": 25}
	],
	"tripulacion_15": [
		{"texto": "Keep hatch sealed, breathe O2 & ping beacon", "dano": 0},
		{"texto": "Open hatch immediately for fresh air", "dano": 45},
		{"texto": "Fire signal flares near fuel vent valves", "dano": 50}
	],

	# --- RIESGOS NAVE (IDs 1 a 6) ---
	"nave_1": [
		{"texto": "Move crew to water-wall armored core", "dano": 0},
		{"texto": "Boost exterior lights to deflect ions", "dano": 20},
		{"texto": "Ignore alert and continue nominal tasks", "dano": 25}
	],
	"nave_2": [
		{"texto": "Enter safe-mode & shield core avionics", "dano": 0},
		{"texto": "Maximize radio power to pierce static", "dano": 25},
		{"texto": "Reboot main flight computer mid-flare", "dano": 30}
	],
	"nave_3": [
		{"texto": "Power down non-essential buses before CME", "dano": 0},
		{"texto": "Keep all science & comms at full load", "dano": 35},
		{"texto": "Route surge current into battery banks", "dano": 40}
	],
	"nave_4": [
		{"texto": "Halt tasks & shelter in heaviest armored bay", "dano": 0},
		{"texto": "Stay in cockpit to manually steer course", "dano": 45},
		{"texto": "Depressurize airlock to lower conductivity", "dano": 35}
	],
	"nave_5": [
		{"texto": "Switch to inertial nav & burn RCS to hold", "dano": 0},
		{"texto": "Cut thrusters and drift until storm ends", "dano": 25},
		{"texto": "Rely solely on magnetic sensors & radio", "dano": 30}
	],
	"nave_6": [
		{"texto": "Pre-charge shields & stage storm protocols", "dano": 0},
		{"texto": "Extend solar arrays to harvest shockwave", "dano": 30},
		{"texto": "Dismiss precursor wave as sensor noise", "dano": 25}
	]
}


func _ready() -> void:
	add_to_group("pantalla_eventos")
	y_base_nave = nave.position.y
	_estilizar_ui_pixel_art()

	# Si ejecutamos esta escena sola con F6, arranca de inmediato; si está dentro de GUI, espera oculta
	if get_parent() == get_tree().root:
		iniciar_simulacion_vuelo()
	else:
		hide()


# Llamado por GameManager al despegar o al pulsar F8
func iniciar_simulacion_vuelo() -> void:
	show()
	_cargar_datos_mision()
	_preparar_eventos_desde_json()
	_iniciar_vuelo()


func _estilizar_ui_pixel_art() -> void:
	popup_evento.visible = false
	slider_progreso.min_value = 0.0
	slider_progreso.max_value = 100.0
	slider_progreso.step = 0.01
	slider_progreso.value = 0.0
	slider_progreso.editable = false
	slider_progreso.focus_mode = Control.FOCUS_NONE

	label_hud.add_theme_font_size_override("font_size", 6)
	titulo_alerta.add_theme_font_size_override("font_size", 6)
	titulo_alerta.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	titulo_alerta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	descripcion_evento.bbcode_enabled = true
	descripcion_evento.fit_content = true
	descripcion_evento.scroll_active = false
	descripcion_evento.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	descripcion_evento.add_theme_font_size_override("normal_font_size", 5)

	for btn in botones_opcion:
		btn.add_theme_font_size_override("font_size", 5)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _cargar_datos_mision() -> void:
	duracion_dias = dias_mision_prueba

	if GmatManager and not GmatManager.mision_actual.is_empty():
		var m: Dictionary = GmatManager.mision_actual
		if m.has("duracion_dias"):
			duracion_dias = int(m["duracion_dias"])
		else:
			var destino_str: String = m.get("destino", "")
			if "9" in destino_str:
				duracion_dias = 9
			elif "10" in destino_str:
				duracion_dias = 10
	else:
		print("[SpaceScreen] Ejecutando en modo prueba independiente (F6).")

	var duracion_total_seg: float = max(float(duracion_dias) * segundos_por_dia, 6.0)
	velocidad_slider = 100.0 / duracion_total_seg


func _preparar_eventos_desde_json() -> void:
	cola_eventos.clear()

	if not FileAccess.file_exists(ruta_json):
		push_error("No se encontró el archivo JSON en: " + ruta_json)
		return

	var archivo := FileAccess.open(ruta_json, FileAccess.READ)
	var datos = JSON.parse_string(archivo.get_as_text())
	if typeof(datos) != TYPE_DICTIONARY:
		push_error("Error al leer el formato de " + ruta_json)
		return

	var candidatos: Array[Dictionary] = []

	for clave_grupo in ["riesgos_tripulacion", "riesgos_nave"]:
		var prefijo := "tripulacion_" if clave_grupo == "riesgos_tripulacion" else "nave_"
		var lista: Array = datos.get(clave_grupo, [])

		for item in lista:
			var id_num := int(item.get("id", 0))
			var clave_opciones := prefijo + str(id_num)

			var prob_str: String = str(item.get("probabilidad_aparicion", "50%")).replace("%", "")
			var prob: float = clamp(float(prob_str) / 100.0, 0.05, 1.0)

			if randf() <= prob:
				var evento_preparado: Dictionary = item.duplicate(true)
				evento_preparado["clave_opciones"] = clave_opciones
				candidatos.append(evento_preparado)

	if candidatos.size() < min_eventos:
		for clave_grupo in ["riesgos_tripulacion", "riesgos_nave"]:
			var prefijo := "tripulacion_" if clave_grupo == "riesgos_tripulacion" else "nave_"
			for item in datos.get(clave_grupo, []):
				var ev: Dictionary = item.duplicate(true)
				ev["clave_opciones"] = prefijo + str(int(item.get("id", 0)))
				candidatos.append(ev)

	candidatos.shuffle()

	var cantidad := randi_range(min_eventos, min(max_eventos, candidatos.size()))
	var elegidos := candidatos.slice(0, cantidad)

	for ev in elegidos:
		var fase: String = str(ev.get("fase_mision", "Durante"))
		match fase:
			"Despegue":
				ev["porcentaje_disparo"] = randf_range(8.0, 22.0)
			"Aterrizaje":
				ev["porcentaje_disparo"] = randf_range(78.0, 94.0)
			_:
				ev["porcentaje_disparo"] = randf_range(28.0, 74.0)

	elegidos.sort_custom(func(a, b): return a["porcentaje_disparo"] < b["porcentaje_disparo"])

	for i in range(1, elegidos.size()):
		if elegidos[i]["porcentaje_disparo"] - elegidos[i - 1]["porcentaje_disparo"] < 10.0:
			elegidos[i]["porcentaje_disparo"] = min(96.0, elegidos[i - 1]["porcentaje_disparo"] + 10.0)

	cola_eventos = elegidos


func _iniciar_vuelo() -> void:
	integridad = GameManager.obtener_integridad_inicial()
	fallos_cometidos = 0
	indice_evento_actual = 0
	tiempo_vuelo = 0.0
	slider_progreso.value = 0.0
	vuelo_activo = true
	en_pausa_evento = false
	popup_evento.visible = false
	label_hud.add_theme_color_override("font_color", Color.WHITE)
	_actualizar_posicion_nave()
	_actualizar_hud()


func _process(delta: float) -> void:
	if not visible or not vuelo_activo or en_pausa_evento:
		return

	tiempo_vuelo += delta
	slider_progreso.value += velocidad_slider * delta
	_actualizar_posicion_nave()
	_actualizar_hud()

	if indice_evento_actual < cola_eventos.size():
		var siguiente_evento := cola_eventos[indice_evento_actual]
		if slider_progreso.value >= siguiente_evento["porcentaje_disparo"]:
			_mostrar_popup_evento(siguiente_evento)
			indice_evento_actual += 1

	if slider_progreso.value >= 100.0:
		_activar_win()


func _actualizar_posicion_nave() -> void:
	var factor := slider_progreso.value / 100.0
	nave.position.x = lerpf(margen_x_inicio, margen_x_fin, factor)
	nave.position.y = y_base_nave + sin(tiempo_vuelo * 4.0) * 1.5


func _actualizar_hud() -> void:
	var dia_actual := clampi(int((slider_progreso.value / 100.0) * duracion_dias) + 1, 1, duracion_dias)
	var nombre := nombre_mision_prueba
	if GmatManager and not GmatManager.mision_actual.is_empty():
		nombre = GmatManager.mision_actual.get("nombre", nombre)

	label_hud.text = "%s | DAY %d/%d | INTEGRITY: %d%%" % [nombre.to_upper(), dia_actual, duracion_dias, integridad]


func _mostrar_popup_evento(evento: Dictionary) -> void:
	en_pausa_evento = true

	titulo_alerta.text = evento.get("titulo_alerta", "WARNING! - Anomaly Detected")
	descripcion_evento.text = evento.get("descripcion", "")

	var opciones: Array = []
	if evento.has("opciones") and evento["opciones"] is Array and evento["opciones"].size() >= 3:
		opciones = evento["opciones"].duplicate(true)
	else:
		var clave: String = evento.get("clave_opciones", "tripulacion_1")
		opciones = OPCIONES_POR_EVENTO.get(clave, OPCIONES_POR_EVENTO["tripulacion_1"]).duplicate(true)

	opciones.shuffle()

	for i in range(botones_opcion.size()):
		var btn := botones_opcion[i]
		var op: Dictionary = opciones[i]
		btn.text = "%d. %s" % [i + 1, op["texto"]]

		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn["callable"])

		btn.pressed.connect(_on_opcion_elegida.bind(int(op["dano"])))

	popup_evento.visible = true


func _on_opcion_elegida(dano: int) -> void:
	popup_evento.visible = false
	en_pausa_evento = false

	if dano > 0:
		fallos_cometidos += 1
		integridad = max(0, integridad - dano)
		var tween := create_tween()
		nave.modulate = Color(1.0, 0.25, 0.25)
		tween.tween_property(nave, "modulate", Color.WHITE, 0.4)

	_actualizar_hud()

	if integridad <= 0:
		_activar_game_over("Hull & crew integrity depleted after critical anomalies.")


func _activar_game_over(motivo: String) -> void:
	vuelo_activo = false
	en_pausa_evento = false
	var resumen := {
		"exito": false,
		"integridad_final": integridad,
		"fallos": fallos_cometidos,
		"progreso": slider_progreso.value
	}
	
	# Guarda la causa del fallo y el progreso en GameManager para mostrarlos en GameOver.tscn
	if GameManager.has_method("registrar_resultado_final"):
		GameManager.registrar_resultado_final(false, motivo, resumen)
		
	mision_fallida.emit(motivo, resumen)
	print("[SpaceScreen] GAME OVER -> ", motivo, " | ", resumen)
	
	label_hud.text = "MISSION FAILED - INTEGRITY 0%"
	label_hud.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	
	# Pausa breve para que se lea el aviso rojo antes de cambiar de escena
	await get_tree().create_timer(1.5).timeout
	var err := get_tree().change_scene_to_file("res://Interactives/GameOver.tscn")
	if err != OK:
		push_error("No se pudo abrir res://Screens/GameOver.tscn. Revisa que el nombre y mayúsculas coincidan.")

func _activar_win() -> void:
	vuelo_activo = false
	en_pausa_evento = false
	var resumen := {
		"exito": true,
		"integridad_final": integridad,
		"fallos": fallos_cometidos,
		"progreso": 100.0
	}
	
	# Guarda el reporte en GameManager si ya agregaste esa función
	if GameManager.has_method("registrar_resultado_final"):
		GameManager.registrar_resultado_final(true, "", resumen)
		
	mision_completada.emit(resumen)
	print("[SpaceScreen] MISSION ACCOMPLISHED -> ", resumen)
	
	# 1. Primero muestra el texto en el HUD
	label_hud.text = "MISSION ACCOMPLISHED! INTEGRITY: %d%%" % integridad
	label_hud.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	
	# 2. Espera 1.5 segundos para que se lea y cambia a la escena Win
	await get_tree().create_timer(1.5).timeout
	var err := get_tree().change_scene_to_file("res://Screens/win.tscn")
	if err != OK:
		push_error("No se pudo abrir res://Screens/win.tscn. Verifica que la ruta y mayúsculas coincidan.")
