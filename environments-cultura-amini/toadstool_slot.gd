extends CanvasLayer

@export var slot_nodes: Array[NodePath] = []

var _slots: Array[TextureRect] = []
var _required: Array[String] = []
var _filled: Array[bool] = []
var _puzzle: Node = null
var _setup_done: bool = false
var _symbol_textures: Array[Texture2D] = []
var _slot_fill_textures: Array[Texture2D] = []


func _ready() -> void:
	follow_viewport_enabled = false


func setup(required_symbols: Array[String], symbol_textures: Array[Texture2D], slot_fill_textures: Array[Texture2D], puzzle_node: Node) -> void:
	if _setup_done:
		return

	_setup_done = true
	_required = required_symbols
	_symbol_textures = symbol_textures
	_slot_fill_textures = slot_fill_textures
	_puzzle = puzzle_node

	_filled.resize(_required.size())
	_filled.fill(false)

	push_warning("ToadstoolSlotBar setup. Required symbols: %s" % str(_required))

	for i in range(slot_nodes.size()):
		var slot := get_node_or_null(slot_nodes[i]) as TextureRect
		if slot == null:
			push_warning("ToadstoolSlotBar: slot %d not found" % i)
			continue
		_slots.append(slot)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	call_deferred("_style_slots_then_restore")


func _style_slots_then_restore() -> void:
	_style_slots()
	_restore_filled_slots()


func _restore_filled_slots() -> void:
	var saved_step: int = GameProgress.toadstool_current_step

	if saved_step == 0:
		return

	for i in range(mini(saved_step, _slots.size())):
		_filled[i] = true
		_slots[i].visible = true
		if i < _slot_fill_textures.size() and _slot_fill_textures[i] != null:
			_slots[i].texture = _slot_fill_textures[i]
		elif i < _symbol_textures.size():
			_slots[i].texture = _symbol_textures[i]
			_slots[i].modulate = Color.WHITE
		else:
			_slots[i].modulate = Color(0.7, 0.85, 0.7, 1.0)

	push_warning("ToadstoolSlotBar restored %d filled slots." % saved_step)


func _input(event: InputEvent) -> void:
	if not DragManager.is_dragging:
		return
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or event.pressed:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var slot_index := _get_slot_under_mouse(mouse_pos)

	if slot_index == -1:
		push_warning("Drop released, but mouse is not over any slot. Mouse position: %s" % str(mouse_pos))
		return

	_try_drop_on_slot(slot_index)


func _get_slot_under_mouse(mouse_pos: Vector2) -> int:
	for i in range(_slots.size()):
		var slot := _slots[i]
		if slot == null:
			continue
		var rect := slot.get_global_rect()
		push_warning("Checking slot %d rect=%s mouse=%s" % [i + 1, str(rect), str(mouse_pos)])
		if rect.has_point(mouse_pos):
			push_warning("Mouse is over slot %d" % (i + 1))
			return i
	return -1


func _try_drop_on_slot(slot_index: int) -> void:
	push_warning("Trying drop on slot %d" % (slot_index + 1))

	if slot_index < 0 or slot_index >= _filled.size():
		push_warning("Invalid slot index: %d" % slot_index)
		return
	if _filled[slot_index]:
		push_warning("Slot %d is already filled." % (slot_index + 1))
		return
	if slot_index != _get_current_step():
		push_warning("Wrong slot order. Tried slot %d, but current step is slot %d." % [
			slot_index + 1,
			_get_current_step() + 1
		])
		return
	if slot_index >= _required.size():
		push_warning("Slot index is outside required symbols array.")
		return

	var dropped_name: String = DragManager.dragged_item_name
	var dropped_tex: Texture2D = DragManager.dragged_texture

	push_warning("Dropped: %s" % dropped_name)
	push_warning("Expected: %s" % _required[slot_index])
	push_warning("Dropped texture is null: %s" % str(dropped_tex == null))

	if dropped_name != _required[slot_index]:
		push_warning("Wrong item. Dropped '%s', expected '%s'." % [dropped_name, _required[slot_index]])
		return

	var accepted := true
	if _puzzle and _puzzle.has_method("on_symbol_dropped"):
		accepted = _puzzle.on_symbol_dropped(dropped_name)
		push_warning("Puzzle accepted drop: %s" % str(accepted))
	else:
		push_warning("Puzzle node missing or has no on_symbol_dropped method.")

	if not accepted:
		push_warning("Puzzle rejected item: " + dropped_name)
		return

	DragManager.accept_drop()

	var slot := _slots[slot_index]
	if slot_index < _slot_fill_textures.size() and _slot_fill_textures[slot_index] != null:
		slot.texture = _slot_fill_textures[slot_index]
	else:
		slot.texture = dropped_tex
	slot.visible = true
	slot.modulate = Color.WHITE

	push_warning("Slot texture set to: %s, slot size: %s, slot visible: %s" % [
		str(slot.texture), str(slot.size), str(slot.visible)
	])

	_filled[slot_index] = true

	push_warning("Slot %d filled with %s." % [slot_index + 1, dropped_name])

	for node in get_tree().get_nodes_in_group("inventory_ui"):
		if node.has_method("refresh_inventory_ui"):
			node.refresh_inventory_ui()


func _style_slots() -> void:
	var hbox := get_node_or_null("Panel/HBoxContainer") as HBoxContainer
	if hbox:
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 40)

	for slot in _slots:
		slot.custom_minimum_size = Vector2(120, 120)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL

		var panel := Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		slot.get_parent().add_child(panel)
		slot.get_parent().move_child(panel, slot.get_index())
		slot.reparent(panel)

		panel.custom_minimum_size = Vector2(120, 120)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.06, 0.04, 0.9)
		style.border_color = Color(0.03, 0.02, 0.01, 1.0)
		style.set_border_width_all(3)
		style.set_corner_radius_all(8)
		style.shadow_color = Color(0, 0, 0, 0.6)
		style.shadow_size = 6
		style.shadow_offset = Vector2(2, 3)

		panel.add_theme_stylebox_override("panel", style)

		slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _get_current_step() -> int:
	for i in range(_filled.size()):
		if not _filled[i]:
			return i
	return _filled.size()
