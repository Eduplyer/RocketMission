extends Control

## Selecciona en el Inspector tu escena principal (ej. space_center.tscn)
@export_file("*.tscn") var escena_volver := ""

@onready var label_info: Label = $TextureRect/Label
@onready var boton_back: Button = $TextureRect/Back


func _ready() -> void:
	label_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mostrar_reporte_fallo()


func _mostrar_reporte_fallo() -> void:
	var datos: Dictionary = GameManager.reporte_final
	if datos.is_empty():
		label_info.text = "MISSION FAILED\nCritical failure during flight."
		return

	var mision: String = str(datos.get("mision", "Unknown")).to_upper()
	var progreso: int = int(datos.get("progreso", 0))
	var motivo: String = str(datos.get("motivo", "Hull integrity depleted."))
	var fallos: int = int(datos.get("fallos", 0))

	label_info.text = (
		"MISSION: %s\n" % mision +
		"FLIGHT PROGRESS: %d%% (Errors: %d)\n" % [progreso, fallos] +
		"CAUSE: %s" % motivo
	)


func _on_back_pressed() -> void:
	GameManager.reiniciar_mision()
	if escena_volver != "":
		get_tree().change_scene_to_file(escena_volver)
	else:
		push_error("Asigna tu escena principal (space_center.tscn) en 'Escena Volver' en el Inspector de Gameover.")
