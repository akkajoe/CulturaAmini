extends CanvasLayer

var is_dragging: bool = false
var dragged_item_name: String = ""
var dragged_texture: Texture2D = null
var dragged_from_slot: int = -1
var preview: TextureRect = null
var drop_was_accepted: bool = false


func _ready() -> void:
	layer = 100
	_create_preview()


func _process(_delta: float) -> void:
	if is_dragging and preview != null:
		preview.global_position = get_viewport().get_mouse_position() - preview.size * 0.5


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		push_warning("MOUSE RELEASED is_dragginganfoishf: %s item: %s group: %s" % [is_dragging, dragged_item_name, str(get_tree().get_nodes_in_group("seed_drop_targets"))])
	
	if not is_dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var mouse_pos := get_viewport().get_mouse_position()
		get_tree().call_group("seed_drop_targets", "try_accept_drop", mouse_pos)
		if not drop_was_accepted:
			stop_drag()
		drop_was_accepted = false


func _create_preview() -> void:
	preview = TextureRect.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.visible = false
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(128, 128)
	add_child(preview)


func start_drag(item_name: String, tex: Texture2D, from_slot: int = -1) -> void:
	if item_name == "" or tex == null:
		return
	is_dragging = true
	dragged_item_name = item_name
	dragged_texture = tex
	dragged_from_slot = from_slot
	drop_was_accepted = false
	if preview != null:
		preview.texture = tex
		preview.visible = true
		preview.global_position = get_viewport().get_mouse_position() - preview.size * 0.5
	print("DRAG STARTED:", item_name)


func stop_drag() -> void:
	is_dragging = false
	dragged_item_name = ""
	dragged_texture = null
	dragged_from_slot = -1
	if preview != null:
		preview.texture = null
		preview.visible = false
	print("DRAG STOPPED")


func accept_drop() -> void:
	drop_was_accepted = true
	stop_drag()
