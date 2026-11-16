extends Node
## AUTOLOAD "GameState": la memoria del juego entre escenas.
## Guarda la nave y el cohete mientras el jugador va y viene entre pantallas, y deja la misión
## ya armada (nave + cohete validados) para la etapa de simulación.
##
## Cómo registrarlo (una sola vez):
##   Proyecto > Configuración del proyecto > pestaña Autoload (Carga automática)
##   Ruta: la de este archivo   |   Nombre: GameState   |   Añadir

# Se emite cuando el cohete se construyó y validó bien. La etapa siguiente puede escucharla.
signal mision_lista(datos: Dictionary)

const RUTA_GUARDADO := "user://mision_actual.json"

# Borradores: lo que el jugador lleva elegido (aunque no haya pulsado "Siguiente" o "Crear").
var borrador_nave := {}      # {tipo_mision, aterrizaje, presupuesto, piezas}
var borrador_cohete := {}    # {firma_nave, piezas}

# Resultados finales, ya validados.
var nave := {}               # lo que guarda la pantalla de la nave al pulsar "Siguiente"
var cohete := {}             # lo que guarda la pantalla del cohete al pulsar "Crear" (sin repetir la nave)
var mision := {}             # nave + cohete juntos: es lo que lee la simulación


# Empezar una misión nueva: borra todo lo anterior. Llámalo desde la pantalla de misión.
func reiniciar() -> void:
	borrador_nave = {}
	borrador_cohete = {}
	nave = {}
	cohete = {}
	mision = {}


# ---------- Nave ----------

func guardar_borrador_nave(tipo: String, aterriza: bool, presupuesto: float, piezas: Array) -> void:
	borrador_nave = {"tipo_mision": tipo, "aterrizaje": aterriza, "presupuesto": presupuesto, "piezas": piezas.duplicate()}


func tiene_borrador_nave() -> bool:
	return not borrador_nave.is_empty()


func guardar_nave(datos: Dictionary) -> void:
	nave = datos.duplicate(true)
	# Si la nave cambió, el cohete y la misión armados antes ya no le corresponden.
	cohete = {}
	mision = {}


# ---------- Cohete ----------

# La firma es la lista de piezas de la nave: si la nave cambia, el borrador del cohete se descarta.
func guardar_borrador_cohete(firma_nave: String, piezas: Array) -> void:
	borrador_cohete = {"firma_nave": firma_nave, "piezas": piezas.duplicate()}


func cohete_borrador_para(firma_nave: String) -> Array:
	if borrador_cohete.get("firma_nave", "") == firma_nave:
		return borrador_cohete.get("piezas", []).duplicate()
	return []


# Se llama al pulsar "Crear", cuando todo ya pasó la validación.
func registrar_cohete(datos: Dictionary) -> void:
	if nave.is_empty() and datos.has("nave"):
		nave = datos["nave"].duplicate(true)
	cohete = datos.duplicate(true)
	cohete.erase("nave")                      # la nave ya vive en `nave`
	mision = {
		"version": 1,
		"tipo_mision": nave.get("tipo_mision", ""),
		"aterrizaje": nave.get("aterrizaje", false),
		"destino": datos.get("destino", ""),
		"nave": nave,
		"cohete": cohete,
		"presupuesto_restante": datos.get("presupuesto_restante", 0.0),
		"fiabilidad_lanzamiento": datos.get("fiabilidad", 1.0),
		"eventos_lanzamiento": datos.get("eventos_lanzamiento", []),
		"mitiga": datos.get("mitiga", []),
	}
	guardar_en_disco()
	mision_lista.emit(mision)


# ---------- Consultas rápidas para el resto del juego ----------

func hay_mision_lista() -> bool:
	return not mision.is_empty()


func piezas_nave() -> Array:
	return nave.get("piezas", [])


func piezas_cohete() -> Array:
	return cohete.get("piezas", [])


func tiene_pieza(id: String) -> bool:
	return piezas_nave().has(id) or piezas_cohete().has(id)


func es_humana() -> bool:
	return String(nave.get("tipo_mision", "")) == "humana"


# ---------- Disco (para "Continuar partida") ----------

func guardar_en_disco() -> bool:
	var archivo := FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo guardar la misión en %s (error %d)." % [RUTA_GUARDADO, FileAccess.get_open_error()])
		return false
	archivo.store_string(JSON.stringify(mision, "\t"))
	archivo.close()
	return true


func cargar_de_disco() -> bool:
	if not FileAccess.file_exists(RUTA_GUARDADO):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(RUTA_GUARDADO))
	if typeof(d) != TYPE_DICTIONARY:
		return false
	mision = d
	nave = d.get("nave", {})
	cohete = d.get("cohete", {})
	# Deja los borradores listos para seguir editando.
	borrador_nave = {
		"tipo_mision": nave.get("tipo_mision", "robotica"),
		"aterrizaje": nave.get("aterrizaje", false),
		"presupuesto": nave.get("presupuesto_total", 0.0),
		"piezas": nave.get("piezas", []),
	}
	return true
