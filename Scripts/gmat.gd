extends Control
@onready var value_altitude: SpinBox = $Panel/VBoxContainer/ValueAltitude
@onready var value_inclination: HSlider = $Panel/VBoxContainer/ValueInclination
@onready var value_circularity: HSlider = $Panel/VBoxContainer/ValueCircularity

@onready var label_inclination: Label = $Panel/VBoxContainer/LabelInclination
@onready var label_circularity: Label = $Panel/VBoxContainer/LabelCircularity

var altitude_saved: float = 0.0
var inclination_saved: float = 0.0
var circularity_saved: float = 0.0
var player_data: Dictionary = {}
signal send_data(datos: Dictionary)

func _ready() -> void:
	add_to_group("pantalla_gmat")
	hide()
	value_altitude.value_changed.connect(_on_valor_modificado)
	value_inclination.value_changed.connect(_on_valor_modificado)
	value_circularity.value_changed.connect(_on_valor_modificado)
	save_data()

func _on_valor_modificado(_nuevo_valor: float) -> void:
	save_data()

func save_data() -> void:
	altitude_saved = value_altitude.value
	inclination_saved = value_inclination.value
	circularity_saved = value_circularity.value
	player_data = {
		"altitud": altitude_saved,
		"inclination": inclination_saved,
		"circularity": circularity_saved
	}
	label_inclination.text = "Inclinación: %.1f°" % inclination_saved
	label_circularity.text = "Circularidad: %d%%" % int(circularity_saved)

func obtener_datos_para_calculo() -> Dictionary:
	save_data()
	send_data.emit(player_data)
	return player_data


func _on_button_pressed() -> void:
	var datos:=obtener_datos_para_calculo()
	GmatManager.registrar_y_evaluar(datos)
	hide()
	

func _on_close_pressed() -> void:
	hide()
