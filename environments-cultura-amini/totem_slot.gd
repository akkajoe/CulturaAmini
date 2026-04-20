extends Area2D
class_name TotemSlot

@export var accepted_item_name: String = ""
@export var correct_item_name: String = "hidden_symbol"

@export var symbol_texture: Texture2D
@export var hidden_symbol_texture: Texture2D

@onready var default_symbol: Node = $DefaultSymbol

var current_symbol_name: String = ""
var default_symbol_key: String = ""

func _ready() -> void:
	input_pickable = true
	current_symbol_name = default_symbol_key

func _input(event: InputEvent) -> void:
	if not DragManager.is_dragging:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _is_mouse_over_slot():
				_try_accept_drag()

func _is_mouse_over_slot() -> bool:
	var world_pos := get_global_mouse_position()
	var space_state := get_world_2d().direct_space_state

	var params := PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collide_with_areas = true
	params.collide_with_bodies = false

	var results := space_state.intersect_point(params)

	for hit in results:
		if hit.collider == self:
			return true

	return false

func _try_accept_drag() -> void:
	var dragged_item := DragManager.dragged_item_name

	print("DROP:", dragged_item, "on", name)

	if dragged_item == "":
		DragManager.stop_drag()
		return

	# Empty accepted_item_name means accept anything
	if accepted_item_name != "" and dragged_item != accepted_item_name:
		print("Rejected:", dragged_item)
		DragManager.stop_drag()
		return

	place_symbol(dragged_item)

	var inventory_ui := get_tree().get_first_node_in_group("inventory_ui")
	if inventory_ui != null and inventory_ui.has_method("refresh_inventory_ui"):
		inventory_ui.refresh_inventory_ui()

	DragManager.stop_drag()

func place_symbol(item_name: String) -> void:
	current_symbol_name = item_name

	var tex := _get_texture_for_item(item_name)
	if tex == null:
		print("No texture for:", item_name)
		return

	if default_symbol is Sprite2D:
		var spr := default_symbol as Sprite2D
		spr.texture = tex
		spr.visible = true
	elif default_symbol is AnimatedSprite2D:
		var anim := default_symbol as AnimatedSprite2D
		anim.stop()
		_replace_animated_with_sprite(tex)
	else:
		print("DefaultSymbol must be Sprite2D or AnimatedSprite2D")
		return

	print("PLACED:", item_name, "on", name)

func _replace_animated_with_sprite(tex: Texture2D) -> void:
	var old_node := default_symbol
	var sprite := Sprite2D.new()

	sprite.name = "DefaultSymbol"
	sprite.texture = tex
	sprite.position = (old_node as Node2D).position if old_node is Node2D else Vector2.ZERO

	if old_node is Node2D:
		sprite.scale = (old_node as Node2D).scale
		sprite.rotation = (old_node as Node2D).rotation

	if old_node is CanvasItem:
		sprite.visible = true

	old_node.get_parent().add_child(sprite)
	sprite.owner = old_node.owner

	old_node.queue_free()
	default_symbol = sprite

func set_default_symbol(node: Node, expected_key: String) -> void:
	default_symbol = node
	default_symbol_key = expected_key
	current_symbol_name = expected_key

	if default_symbol != null and is_instance_valid(default_symbol):
		if default_symbol is CanvasItem:
			(default_symbol as CanvasItem).show()

func is_correct() -> bool:
	if correct_item_name == "":
		return false
	return current_symbol_name == correct_item_name

func _get_texture_for_item(item_name: String) -> Texture2D:
	match item_name:
		"symbol":
			return symbol_texture
		"hidden_symbol":
			return hidden_symbol_texture
		_:
			return null
