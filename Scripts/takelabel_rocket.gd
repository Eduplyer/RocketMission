extends takelabel

func interact() -> void:
	var cohete: Control = get_tree().get_first_node_in_group("pantalla_coheteselect")
	if cohete:
		cohete.visible = not cohete.visible
		label.visible = not cohete.visible
