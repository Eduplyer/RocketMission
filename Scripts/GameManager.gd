extends Node

const PENALIZACION_PARAMETRO_GMAT := 20.0
const RIESGO_BASE_MISION := 5.0

## Ponlo en false antes de exportar el juego final para desactivar F8
@export var debug_tecla_activa: bool = true
@export var requerir_astronauta: bool = false

var nave_lista: bool = false
var cohete_listo: bool = false
var astronauta_listo: bool = false

var riesgo_nave: float = 0.0
var riesgo_cohete: float = 0.0
var riesgo_astronauta: float = 0.0

var datos_nave: Dictionary = {}
var datos_cohete: Dictionary = {}
var astronauta_elegido: Dictionary = {}

var detalle_nave: String = "Sin avisos técnicos"
var detalle_cohete: String = "Sin avisos técnicos"

signal estado_actualizado(probabilidad_exito: float, riesgo_total: float)
signal lanzamiento_finalizado(resultado: Dictionary)


# --- ATAJO DE PRUEBA (TECLA F8) ---
func _unhandled_input(event: InputEvent) -> void:
	if not debug_tecla_activa:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			pass


func forzar_prueba_eventos() -> void:
	print("[GameManager DEBUG] Activando space screen desde GUI con F8...")
	
	if GmatManager.mision_actual.is_empty():
		GmatManager.mision_actual = {
			"nombre": "Project Minerva II (Debug)",
			"destino": "Lunar Flyby - 9 Days",
			"duracion_dias": 9,
			"pista": "Debug flight simulation."
		}
	if GmatManager.parametros_jugador.is_empty():
		GmatManager.parametros_jugador = {
			"altitud": 384000.0,
			"inclination": 28.5,
			"circularity": 5.0
		}
	GmatManager.mision_exitosa = true
	GmatManager.ultimo_resultado = {
		"exito": true,
		"altitud_ok": true,
		"inclinacion_ok": true,
		"circularidad_ok": true
	}
	
	nave_lista = true
	cohete_listo = true
	astronauta_listo = true
	riesgo_nave = 0.0
	riesgo_cohete = 0.0
	riesgo_astronauta = 0.0
	
	abrir_pantalla_eventos()


# --- ABRIR LA PANTALLA INSTANCIADA EN GUI ---
func abrir_pantalla_eventos() -> void:
	var pantalla := get_tree().get_first_node_in_group("pantalla_eventos")
	if pantalla and pantalla.has_method("iniciar_simulacion_vuelo"):
		pantalla.iniciar_simulacion_vuelo()
	else:
		push_error("No se encontró 'space screen' en el grupo 'pantalla_eventos' dentro de GUI.")


# --- REGISTRO DE ETAPAS ---
func registrar_nave(riesgo_calculado: float, descripcion_fallo: String = "", datos: Dictionary = {}) -> void:
	nave_lista = true
	datos_nave = datos.duplicate(true)
	riesgo_nave = clampf(riesgo_calculado, 0.0, 15.0)
	detalle_nave = descripcion_fallo if descripcion_fallo != "" else "Configuración nominal"
	cohete_listo = false
	_notificar_cambio()


func registrar_cohete(riesgo_calculado: float, descripcion_fallo: String = "", datos: Dictionary = {}) -> void:
	cohete_listo = true
	datos_cohete = datos.duplicate(true)
	riesgo_cohete = clampf(riesgo_calculado, 0.0, 25.0)
	detalle_cohete = descripcion_fallo if descripcion_fallo != "" else "Configuración nominal"
	_notificar_cambio()


func registrar_astronauta(datos_astro: Dictionary) -> void:
	astronauta_listo = true
	astronauta_elegido = datos_astro.duplicate(true)
	var idoneidad: float = clampf(datos_astro.get("idoneidad", 50.0), 0.0, 100.0)
	riesgo_astronauta = ((100.0 - idoneidad) / 100.0) * 15.0
	_notificar_cambio()


# --- CÁLCULO DE RIESGO ---
func obtener_riesgo_gmat() -> float:
	if GmatManager.ultimo_resultado.is_empty():
		return 60.0
	
	var res: Dictionary = GmatManager.ultimo_resultado
	var riesgo := 0.0
	if not res.get("altitud_ok", false):
		riesgo += PENALIZACION_PARAMETRO_GMAT
	if not res.get("inclinacion_ok", false):
		riesgo += PENALIZACION_PARAMETRO_GMAT
	if not res.get("circularidad_ok", false):
		riesgo += PENALIZACION_PARAMETRO_GMAT
	return riesgo


func calcular_riesgo_total() -> float:
	var total := RIESGO_BASE_MISION + obtener_riesgo_gmat() + riesgo_cohete + riesgo_nave + riesgo_astronauta
	return clampf(total, 1.0, 99.0)


func obtener_probabilidad_exito() -> float:
	return 100.0 - calcular_riesgo_total()


func _notificar_cambio() -> void:
	estado_actualizado.emit(obtener_probabilidad_exito(), calcular_riesgo_total())


# --- VERIFICACIÓN Y LANZAMIENTO ---
func verificar_requisitos_lanzamiento() -> Dictionary:
	var faltantes: Array[String] = []
	
	if GmatManager.mision_actual.is_empty():
		faltantes.append("Select and accept a Mission")
	if GmatManager.parametros_jugador.is_empty():
		faltantes.append("Calibrate orbital parameters in GMAT")
	if not nave_lista:
		faltantes.append("Build the Spacecraft")
	if not cohete_listo:
		faltantes.append("Assemble the Rocket")
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
			"causa_fallo": "Missing steps: " + ", ".join(chequeo["faltantes"])
		}

	var prob_exito := obtener_probabilidad_exito()
	var tirada := randf() * 100.0
	var exito := tirada <= prob_exito
	
	var causa_fallo := ""
	if not exito:
		causa_fallo = _determinar_causa_probable()
	
	var resultado := {
		"exito": exito,
		"probabilidad_exito": prob_exito,
		"tirada": tirada,
		"causa_fallo": causa_fallo,
		"desglose_riesgo": {
			"gmat": obtener_riesgo_gmat(),
			"cohete": riesgo_cohete,
			"nave": riesgo_nave,
			"astronauta": riesgo_astronauta
		}
	}
	
	lanzamiento_finalizado.emit(resultado)
	return resultado


func _determinar_causa_probable() -> String:
	var r_gmat := obtener_riesgo_gmat()
	
	if r_gmat >= riesgo_cohete and r_gmat >= riesgo_nave and r_gmat >= riesgo_astronauta and r_gmat > 0.0:
		return "Orbital trajectory error (GMAT parameters out of range)."
	elif riesgo_cohete >= riesgo_nave and riesgo_cohete >= riesgo_astronauta and riesgo_cohete > 0.0:
		return "Rocket propulsion or structural failure: " + detalle_cohete
	elif riesgo_nave >= riesgo_astronauta and riesgo_nave > 0.0:
		return "Spacecraft subsystem failure: " + detalle_nave
	elif riesgo_astronauta > 0.0:
		return "Crew piloting error during ascent burn."
	else:
		return "Unforeseen anomaly during liftoff."


func reiniciar_mision() -> void:
	nave_lista = false
	cohete_listo = false
	astronauta_listo = false
	riesgo_nave = 0.0
	riesgo_cohete = 0.0
	riesgo_astronauta = 0.0
	datos_nave.clear()
	datos_cohete.clear()
	astronauta_elegido.clear()
	GmatManager.mision_actual.clear()
	GmatManager.parametros_jugador.clear()
	GmatManager.ultimo_resultado.clear()
