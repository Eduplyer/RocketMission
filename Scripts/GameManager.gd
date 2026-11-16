extends Node

## Ponlo en false antes de exportar el juego final para desactivar teclas de prueba
@export var debug_tecla_activa: bool = true
@export var requerir_astronauta: bool = false

# Estado de completado de cada etapa
var nave_lista: bool = false
var cohete_listo: bool = false
var astronauta_listo: bool = false

# Penalizaciones acumuladas por malas decisiones de ingeniería (se restan a la integridad inicial en el espacio)
var penalizacion_integridad_nave: int = 0
var penalizacion_integridad_cohete: int = 0
var riesgo_astronauta: float = 0.0

var datos_nave: Dictionary = {}
var datos_cohete: Dictionary = {}
var astronauta_elegido: Dictionary = {}
var reporte_final: Dictionary = {}

var detalle_nave: String = "Nominal"
var detalle_cohete: String = "Nominal"

signal estado_actualizado(integridad_inicial: int)
signal lanzamiento_finalizado(resultado: Dictionary)

# Teletransporte de main_character tras salir del ensamblaje
var teletransporte_pendiente: bool = false
var posicion_destino_player: Vector2 = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not debug_tecla_activa:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			forzar_prueba_eventos()


func _process(_delta: float) -> void:
	if teletransporte_pendiente:
		_intentar_teletransportar_player()


func solicitar_teletransporte_player(pos: Vector2) -> void:
	posicion_destino_player = pos
	teletransporte_pendiente = true
	_intentar_teletransportar_player()


func _intentar_teletransportar_player() -> void:
	var escena := get_tree().current_scene
	if escena == null:
		return
	var player: Node2D = escena.find_child("main_character", true, false) as Node2D
	if player == null:
		player = escena.find_child("MainCharacter", true, false) as Node2D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player:
		player.global_position = posicion_destino_player
		teletransporte_pendiente = false


# --- REGISTRO DE ETAPAS ---

func registrar_nave(riesgo_calculado: float, descripcion_fallo: String = "", datos: Dictionary = {}) -> void:
	nave_lista = true
	datos_nave = datos.duplicate(true)
	# Cada aviso técnico de la nave resta integridad inicial al despegar (máx -25%)
	penalizacion_integridad_nave = clampi(int(round(riesgo_calculado)), 0, 25)
	detalle_nave = descripcion_fallo if descripcion_fallo != "" else "Nominal"
	cohete_listo = false
	_notificar_cambio()


func registrar_cohete(riesgo_calculado: float, descripcion_fallo: String = "", datos: Dictionary = {}) -> void:
	cohete_listo = true
	datos_cohete = datos.duplicate(true)
	# Baja fiabilidad o vulnerabilidades del cohete restan integridad inicial (máx -35%)
	penalizacion_integridad_cohete = clampi(int(round(riesgo_calculado)), 0, 35)
	detalle_cohete = descripcion_fallo if descripcion_fallo != "" else "Nominal"
	_notificar_cambio()


func registrar_astronauta(datos_astro: Dictionary) -> void:
	astronauta_listo = true
	astronauta_elegido = datos_astro.duplicate(true)
	var idoneidad: float = clampf(datos_astro.get("idoneidad", 50.0), 0.0, 100.0)
	riesgo_astronauta = ((100.0 - idoneidad) / 100.0) * 15.0
	_notificar_cambio()


# Calcula con cuánta integridad (40% a 100%) empezará la nave en space_screen
func obtener_integridad_inicial() -> int:
	var dano_previo := penalizacion_integridad_nave + penalizacion_integridad_cohete + int(round(riesgo_astronauta))
	return clampi(100 - dano_previo, 40, 100)


func _notificar_cambio() -> void:
	estado_actualizado.emit(obtener_integridad_inicial())


# --- VERIFICACIÓN ESTRICTA DE SECUENCIA ---

func verificar_requisitos_lanzamiento() -> Dictionary:
	var faltantes: Array[String] = []
	
	# 1. Misión aceptada
	if GmatManager.mision_actual.is_empty():
		faltantes.append("Select and accept a Mission")
	
	# 2. GMAT calibrado Y dentro de los rangos correctos de la misión
	if GmatManager.parametros_jugador.is_empty():
		faltantes.append("Calibrate orbital parameters in GMAT")
	elif not GmatManager.mision_exitosa:
		var res: Dictionary = GmatManager.ultimo_resultado
		var errores_gmat: Array[String] = []
		if not res.get("altitud_ok", false):
			errores_gmat.append("Altitude")
		if not res.get("inclinacion_ok", false):
			errores_gmat.append("Inclination")
		if not res.get("circularidad_ok", false):
			errores_gmat.append("Circularity")
		faltantes.append("Fix GMAT orbit (%s out of range)" % ", ".join(errores_gmat))
	
	# 3. Nave armada
	if not nave_lista:
		faltantes.append("Build a valid Spacecraft")
	
	# 4. Cohete armado
	if not cohete_listo:
		faltantes.append("Assemble a compatible Rocket")
	
	# 5. Astronauta (si está activado)
	if requerir_astronauta and not astronauta_listo:
		faltantes.append("Assign an Astronaut")
		
	return {
		"ok": faltantes.is_empty(),
		"faltantes": faltantes
	}


func puede_lanzar() -> bool:
	return verificar_requisitos_lanzamiento()["ok"]


func ejecutar_lanzamiento() -> Dictionary:
	var chequeo := verificar_requisitos_lanzamiento()
	if not chequeo["ok"]:
		return {
			"exito": false,
			"probabilidad_exito": 0.0,
			"causa_fallo": "Missing steps:\n• " + "\n• ".join(chequeo["faltantes"])
		}

	var integridad_salida := obtener_integridad_inicial()
	var resultado := {
		"exito": true,
		"probabilidad_exito": float(integridad_salida),
		"integridad_inicial": integridad_salida,
		"causa_fallo": ""
	}
	
	lanzamiento_finalizado.emit(resultado)
	return resultado


func abrir_pantalla_eventos() -> void:
	var pantalla := get_tree().get_first_node_in_group("pantalla_eventos")
	if pantalla and pantalla.has_method("iniciar_simulacion_vuelo"):
		pantalla.iniciar_simulacion_vuelo()
	else:
		push_error("No se encontró 'space screen' en el grupo 'pantalla_eventos' dentro de GUI.")


func registrar_resultado_final(exito: bool, motivo: String = "", resumen_vuelo: Dictionary = {}) -> void:
	reporte_final = {
		"exito": exito,
		"mision": GmatManager.mision_actual.get("nombre", "Unknown Mission"),
		"destino": GmatManager.mision_actual.get("destino", "Unknown"),
		"motivo": motivo,
		"integridad": resumen_vuelo.get("integridad_final", 0),
		"fallos": resumen_vuelo.get("fallos", 0),
		"progreso": resumen_vuelo.get("progreso", 0.0)
	}


func reiniciar_mision() -> void:
	nave_lista = false
	cohete_listo = false
	astronauta_listo = false
	penalizacion_integridad_nave = 0
	penalizacion_integridad_cohete = 0
	riesgo_astronauta = 0.0
	datos_nave.clear()
	datos_cohete.clear()
	astronauta_elegido.clear()
	GmatManager.mision_actual.clear()
	GmatManager.parametros_jugador.clear()
	GmatManager.ultimo_resultado.clear()
	GmatManager.mision_exitosa = false


# --- ATAJO DE PRUEBA (TECLA 1) ---
func forzar_prueba_eventos() -> void:
	print("[GameManager DEBUG] Activando space screen desde GUI con tecla 1...")
	if GmatManager.mision_actual.is_empty():
		GmatManager.mision_actual = {
			"nombre": "Project Minerva II (Debug)",
			"destino": "Lunar Flyby - 9 Days",
			"duracion_dias": 9,
			"pista": "Debug flight simulation."
		}
	if GmatManager.parametros_jugador.is_empty():
		GmatManager.parametros_jugador = {"altitud": 384000.0, "inclination": 28.5, "circularity": 5.0}
	GmatManager.mision_exitosa = true
	GmatManager.ultimo_resultado = {"exito": true, "altitud_ok": true, "inclinacion_ok": true, "circularidad_ok": true}
	
	nave_lista = true
	cohete_listo = true
	astronauta_listo = true
	penalizacion_integridad_nave = 0
	penalizacion_integridad_cohete = 0
	riesgo_astronauta = 0.0
	abrir_pantalla_eventos()
