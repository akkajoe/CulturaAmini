extends Area2D

@export var seed_world_texture: Texture2D
@export var speech_box_path: NodePath
@export var guide_path: NodePath
@export var second_dialogue_lines: Array[String] = [
	"You have cursed the seed.",
	"Now it will never grow."
]

var seed_sprite: Sprite2D = null
var is_planted: bool = false


func _ready() -> void:
	add_to_group("seed_drop_targets")


func try_accept_drop(mouse_pos: Vector2) -> void:
	push_warning("try_accept_drop called - item: %s planted: %s" % [DragManager.dragged_item_name, is_planted])

	if DragManager.dragged_item_name == "seed" and not is_planted:
		var over := _mouse_is_over_area(mouse_pos)
		push_warning("Mouse over path area: %s" % over)
		if not over:
			return
		_place_seed(mouse_pos)
		var idx := GameProgress.inventory_items.find("seed")
		if idx != -1:
			GameProgress.inventory_items.remove_at(idx)
		for inv in get_tree().get_nodes_in_group("inventory_ui"):
			if inv.has_method("refresh_inventory_ui"):
				inv.refresh_inventory_ui()
		DragManager.accept_drop()
		push_warning("Seed placed!")
		return

	if DragManager.dragged_item_name == "death_symbol" and is_planted:
		var over := _mouse_is_over_seed(mouse_pos)
		push_warning("Mouse over seed: %s" % over)
		if not over:
			return
		var idx := GameProgress.inventory_items.find("death_symbol")
		if idx != -1:
			GameProgress.inventory_items.remove_at(idx)
		for inv in get_tree().get_nodes_in_group("inventory_ui"):
			if inv.has_method("refresh_inventory_ui"):
				inv.refresh_inventory_ui()
		DragManager.accept_drop()
		_trigger_second_dialogue()
		push_warning("Second dialogue triggered!")
		return


func _place_seed(mouse_pos: Vector2) -> void:
	is_planted = true
	var world_pos := get_canvas_transform().affine_inverse() * mouse_pos

	seed_sprite = Sprite2D.new()
	seed_sprite.texture = seed_world_texture
	seed_sprite.position = world_pos
	seed_sprite.scale = Vector2(0.4, 0.4)
	get_parent().add_child(seed_sprite)


func _trigger_second_dialogue() -> void:
	var speech_box := get_node_or_null(speech_box_path)
	if speech_box == null:
		push_warning("WorldSeedDrop: speech_box_path not set or not found.")
		return

	var guide := get_node_or_null(guide_path)
	if guide and guide.has_method("start_second_dialogue"):
		guide.start_second_dialogue(speech_box, second_dialogue_lines)
	elif speech_box.has_method("start_dialogue_lines"):
		speech_box.call("start_dialogue_lines", second_dialogue_lines)


func _mouse_is_over_seed(mouse_pos: Vector2) -> bool:
	if seed_sprite == null:
		return false
	var world_pos := get_canvas_transform().affine_inverse() * mouse_pos
	return world_pos.distance_to(seed_sprite.position) <= 48.0


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
