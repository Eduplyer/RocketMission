extends Node


var mision_actual: Dictionary = {}
var parametros_jugador: Dictionary = {}

var mision_exitosa: bool = false
var ultimo_resultado: Dictionary = {}

signal mision_aceptada(mision: Dictionary)
signal calculo_evaluado(resultado: Dictionary)

# 1. Llama a esta función desde el botón "Aceptar" del carrusel
func aceptar_mision(datos_mision: Dictionary) -> void:
	mision_actual = datos_mision.duplicate(true)
	parametros_jugador.clear()
	mision_exitosa = false
	ultimo_resultado.clear()
	mision_aceptada.emit(mision_actual)
	print("Misión guardada en GmatManager: ", mision_actual.get("nombre", "Sin nombre"))

# 2. Llama a esta función desde gmat.gd al confirmar los parámetros
func registrar_y_evaluar(datos_gmat: Dictionary) -> Dictionary:
	parametros_jugador = datos_gmat.duplicate(true)
	
	if mision_actual.is_empty():
		push_warning("Se guardaron datos en GMAT, pero aún no hay ninguna misión aceptada.")
		return {"exito": false, "motivo": "Sin misión activa"}
	
	# Comparamos cada parámetro con márgenes amplios (tolerancias generosas)
	var diff_alt: float = abs(datos_gmat["altitud"] - mision_actual["objetivo_altitud"])
	var diff_inc: float = abs(datos_gmat["inclination"] - mision_actual["objetivo_inclinacion"])
	var diff_cir: float = abs(datos_gmat["circularity"] - mision_actual["objetivo_circularidad"])
	
	var alt_ok: bool = diff_alt <= mision_actual["tolerancia_altitud"]
	var inc_ok: bool = diff_inc <= mision_actual["tolerancia_inclinacion"]
	var cir_ok: bool = diff_cir <= mision_actual["tolerancia_circularidad"]
	
	mision_exitosa = alt_ok and inc_ok and cir_ok
	
	ultimo_resultado = {
		"exito": mision_exitosa,
		"altitud_ok": alt_ok,
		"inclinacion_ok": inc_ok,
		"circularidad_ok": cir_ok
	}
	
	calculo_evaluado.emit(ultimo_resultado)
	print("Resultado GMAT (", mision_actual["nombre"], "): ", ultimo_resultado)
	return ultimo_resultado
