extends takelabel

func interact() -> void:
	var gmat: Control = get_tree().get_first_node_in_group("pantalla_gmat")
	if gmat:
		gmat.visible = not gmat.visible
		label.visible = not gmat.visible
