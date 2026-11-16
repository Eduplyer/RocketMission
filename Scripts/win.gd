extends CanvasLayer

## Selecciona en el Inspector la escena principal (ej. space_center.tscn)
@export_file("*.tscn") var escena_volver := ""

@onready var label_resumen: Control = $Panel/RichTextLabel
@onready var boton_continuar: Button = $Panel/return


func _ready() -> void:
	if boton_continuar == null:
		boton_continuar = _buscar_primer_boton(self)
	
	if boton_continuar:
		boton_continuar.pressed.connect(_on_continuar_pressed)
	else:
		push_warning("No se encontró ningún Button en win.tscn.")

	_mostrar_resumen_mision()


func _mostrar_resumen_mision() -> void:
	if label_resumen == null:
		push_warning("Falta un nodo llamado 'LabelResumen' en win.tscn.")
		return
	
	var d: Dictionary = GameManager.reporte_final
	if d.is_empty():
		label_resumen.text = "MISSION ACCOMPLISHED!\nTelemetry nominal."
		return

	var presupuesto_txt := _formatear_dinero(float(d.get("presupuesto_restante", 0.0)))
	var integridad_final := int(d.get("integridad", 100))
	var fallos := int(d.get("fallos", 0))

	var texto := (
		"MISSION: %s\n" % str(d.get("mision", "Unknown")).to_upper() +
		"TARGET: %s\n" % str(d.get("destino", "Unknown")) +
		"CREW: %s\n" % str(d.get("astronauta", "Standard Crew")) +
		"FINAL INTEGRITY: %d%% (Errors: %d)\n" % [integridad_final, fallos] +
		"BUDGET SAVED: %s" % presupuesto_txt
	)

	label_resumen.text = texto


func _formatear_dinero(v: float) -> String:
	if v >= 1000000.0:
		return "%.1fM cr" % (v / 1000000.0)
	if v >= 1000.0:
		return "%dk cr" % int(v / 1000.0)
	return "%d cr" % int(v)


func _on_continuar_pressed() -> void:
	GameManager.reiniciar_mision()
	if escena_volver != "":
		get_tree().change_scene_to_file(escena_volver)
	else:
		push_error("Asigna 'Escena Volver' en el Inspector de win.tscn.")


func _buscar_primer_boton(nodo: Node) -> Button:
	for hijo in nodo.get_children():
		if hijo is Button:
			return hijo
		var encontrado := _buscar_primer_boton(hijo)
		if encontrado != null:
			return encontrado
	return null
