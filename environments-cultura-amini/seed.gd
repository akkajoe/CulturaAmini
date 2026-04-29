extends Sprite2D


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse_pos := get_viewport().get_mouse_position()
			var local_pos := to_local(get_canvas_transform().affine_inverse() * mouse_pos)
			if texture and Rect2(-texture.get_size() * 0.5, texture.get_size()).has_point(local_pos):
				GameProgress.inventory_items.append("seed")

				for inv in get_tree().get_nodes_in_group("inventory_ui"):
					if inv.has_method("refresh_inventory_ui"):
						inv.refresh_inventory_ui()

				queue_free()
