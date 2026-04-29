extends Area2D
# For guide in final scene, no walking after speechbox finishes
func _ready() -> void:
	add_to_group("seed_drop_targets")

func try_accept_drop(mouse_pos: Vector2) -> void:
	if DragManager.dragged_item_name != "seed":
		return
	if not _mouse_is_over_area(mouse_pos):
		return
	var idx := GameProgress.inventory_items.find("seed")
	if idx != -1:
		GameProgress.inventory_items.remove_at(idx)
	for inv in get_tree().get_nodes_in_group("inventory_ui"):
		if inv.has_method("refresh_inventory_ui"):
			inv.refresh_inventory_ui()
	DragManager.accept_drop()
	var guide := get_parent()
	if guide and guide.has_method("on_seed_received"):
		guide.on_seed_received()

func _mouse_is_over_area(mouse_pos: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = get_canvas_transform().affine_inverse() * mouse_pos
	params.collision_mask = collision_layer
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var results := space.intersect_point(params)
	for r in results:
		if r["collider"] == self:
			return true
	return false
