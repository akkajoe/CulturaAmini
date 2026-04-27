extends Area2D

func _ready() -> void:
	input_pickable = true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var local_pos := to_local(get_global_mouse_position())
			if _is_mouse_over():
				var ui = get_tree().get_first_node_in_group("inventory_ui")
				if ui:
					ui.toggle_inventory()
				get_viewport().set_input_as_handled()


func _is_mouse_over() -> bool:
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var results := space.intersect_point(params)
	for r in results:
		if r.collider == self:
			return true
	return false
