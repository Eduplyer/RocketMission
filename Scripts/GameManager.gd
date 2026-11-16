extends Node

const PENALIZACION_PARAMETRO_GMAT := 20.0 # 3 parámetros x 20% = 60% máx.
const RIESGO_BASE_MISION := 5.0           # Siempre existe un mínimo de incertidumbre espacial

var riesgo_nave: float = 0.0
var riesgo_cohete: float = 0.0
var riesgo_astronauta: float = 0.0

var astronauta_elegido: Dictionary = {}
var detalle_cohete: String = "Sin fallos detectados"
var detalle_nave: String = "Configuración estándar"

signal estado_actualizado(probabilidad_exito: float, riesgo_total: float)
signal lanzamiento_finalizado(resultado: Dictionary)


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


func registrar_astronauta(datos_astro: Dictionary) -> void:
	astronauta_elegido = datos_astro.duplicate(true)
	# Si el astronauta tiene ej. 90% de idoneidad, aporta muy poco riesgo (10% * 0.15 = 1.5%)
	# Si tiene 30% de idoneidad, aporta hasta ~10.5% de riesgo
	var idoneidad: float = clamp(datos_astro.get("idoneidad", 50.0), 0.0, 100.0)
	riesgo_astronauta = ((100.0 - idoneidad) / 100.0) * 15.0
	_notificar_cambio()


func registrar_cohete(riesgo_calculado: float, descripcion_fallo: String = "") -> void:
	riesgo_cohete = clamp(riesgo_calculado, 0.0, 25.0)
	if descripcion_fallo != "":
		detalle_cohete = descripcion_fallo
	_notificar_cambio()


func registrar_nave(riesgo_calculado: float, descripcion_fallo: String = "") -> void:
	riesgo_nave = clamp(riesgo_calculado, 0.0, 15.0)
	if descripcion_fallo != "":
		detalle_nave = descripcion_fallo
	_notificar_cambio()


func calcular_riesgo_total() -> float:
	var total := RIESGO_BASE_MISION + obtener_riesgo_gmat() + riesgo_cohete + riesgo_nave + riesgo_astronauta
	return clamp(total, 1.0, 99.0)


func obtener_probabilidad_exito() -> float:
	return 100.0 - calcular_riesgo_total()


func _notificar_cambio() -> void:
	estado_actualizado.emit(obtener_probabilidad_exito(), calcular_riesgo_total())


# --- 4. EJECUCIÓN DEL LANZAMIENTO ---
func puede_lanzar() -> bool:
	return not GmatManager.mision_actual.is_empty() and not GmatManager.parametros_jugador.is_empty()


func ejecutar_lanzamiento() -> Dictionary:
	var prob_exito := obtener_probabilidad_exito()
	var tirada := randf() * 100.0 # Número aleatorio entre 0.0 y 100.0
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


# Elige qué falló según qué etapa acumuló más riesgo (ideal para conectar con tu Libro)
func _determinar_causa_probable() -> String:
	var r_gmat := obtener_riesgo_gmat()
	
	if r_gmat >= riesgo_cohete and r_gmat >= riesgo_nave and r_gmat >= riesgo_astronauta and r_gmat > 0:
		return "Trayectoria orbital errónea (Parámetros GMAT fuera de rango)."
	elif riesgo_cohete >= riesgo_nave and riesgo_cohete >= riesgo_astronauta and riesgo_cohete > 0:
		return "Fallo estructural o de propulsión en el cohete: " + detalle_cohete
	elif riesgo_nave >= riesgo_astronauta and riesgo_nave > 0:
		return "Fallo en los sistemas de la nave: " + detalle_nave
	elif riesgo_astronauta > 0:
		return "Error de pilotaje durante la maniobra crítica."
	else:
		return "Anomalía imprevista durante el ascenso."


# Llama a esto al empezar una nueva partida o reiniciar ciclo
func reiniciar_mision() -> void:
	riesgo_nave = 0.0
	riesgo_cohete = 0.0
	riesgo_astronauta = 0.0
	astronauta_elegido.clear()
	GmatManager.mision_actual.clear()
	GmatManager.parametros_jugador.clear()
	GmatManager.ultimo_resultado.clear()
