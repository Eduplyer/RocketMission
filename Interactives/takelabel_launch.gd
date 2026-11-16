extends takelabel

var capa_aviso: CanvasLayer
var panel_aviso: PanelContainer
var label_aviso: RichTextLabel


func _ready() -> void:
	super._ready()
	_crear_ui_aviso()


func interact() -> void:
	var chequeo := GameManager.verificar_requisitos_lanzamiento()
	
	# 1. Si falta algún paso de la secuencia, avisa qué falta y no despega
	if not chequeo["ok"]:
		var lista_faltantes := "\n• ".join(chequeo["faltantes"])
		_mostrar_alerta("[b][color=#ff9d8a]LAUNCH SEQUENCE INCOMPLETE[/color][/b]\nComplete these steps first:\n• " + lista_faltantes, 4.0)
		return

	# 2. Si todo está armado, GameManager evalúa la probabilidad de éxito
	var resultado := GameManager.ejecutar_lanzamiento()
	
	if resultado["exito"]:
		_mostrar_alerta("[b][color=#6bbf8a]LIFTOFF CONFIRMED![/color][/b]\nSuccess odds: %d%%. Entering flight telemetry..." % int(resultado["probabilidad_exito"]), 1.8)
		await get_tree().create_timer(1.8).timeout
		# Activa directamente el nodo "space screen" que ya tienes dentro de GUI
		GameManager.abrir_pantalla_eventos()
	else:
		# 3. Si falla en el despegue por exceso de riesgo, muestra la causa exacta
		_mostrar_alerta(
			"[b][color=#d9645a]LAUNCH ABORTED / FAILURE[/color][/b]\n" +
			"Success odds were: %d%%\n" % int(resultado["probabilidad_exito"]) +
			"[b]Cause:[/b] %s" % resultado["causa_fallo"],
			5.0
		)


func _crear_ui_aviso() -> void:
	capa_aviso = CanvasLayer.new()
	capa_aviso.layer = 25
	add_child(capa_aviso)

	panel_aviso = PanelContainer.new()
	panel_aviso.visible = false
	panel_aviso.position = Vector2(40, 45)
	panel_aviso.size = Vector2(240, 90)
	capa_aviso.add_child(panel_aviso)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	estilo.border_color = Color(0.85, 0.7, 0.4)
	estilo.set_border_width_all(2)
	estilo.set_content_margin_all(8)
	panel_aviso.add_theme_stylebox_override("panel", estilo)

	label_aviso = RichTextLabel.new()
	label_aviso.bbcode_enabled = true
	label_aviso.fit_content = true
	label_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_aviso.add_theme_font_size_override("normal_font_size", 6)
	label_aviso.add_theme_font_size_override("bold_font_size", 6)
	panel_aviso.add_child(label_aviso)


func _mostrar_alerta(texto_bbcode: String, duracion: float) -> void:
	label_aviso.text = texto_bbcode
	panel_aviso.visible = true
	await get_tree().create_timer(duracion).timeout
	if is_instance_valid(panel_aviso):
		panel_aviso.visible = false
