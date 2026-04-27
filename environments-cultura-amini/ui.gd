extends CanvasLayer

@onready var inventory_popup: Control = $inventoryPopup
@onready var left_button: Button = $inventoryPopup/LeftButton
@onready var right_button: Button = $inventoryPopup/RightButton
@onready var slots: Array[TextureRect] = [
	get_node_or_null("inventoryPopup/Slot1") as TextureRect,
	get_node_or_null("inventoryPopup/Slot2") as TextureRect,
	get_node_or_null("inventoryPopup/Slot3") as TextureRect,
	get_node_or_null("inventoryPopup/Slot4") as TextureRect
]

@export var symbol_texture: Texture2D
@export var hidden_symbol_texture: Texture2D
@export var mushroom: Texture2D
@export var bad_mushroom: Texture2D
@export var creature1: Texture2D
@export var creature2: Texture2D
@export var creature3: Texture2D
@export var creature4: Texture2D
@export var death_symbol: Texture2D

var _is_hovered: bool = false
var scroll_offset: int = 0


func _ready() -> void:
	add_to_group("inventory_ui")
	add_to_group("ui_hoverable")
	inventory_popup.hide()
	inventory_popup.mouse_entered.connect(func() -> void: _is_hovered = true)
	inventory_popup.mouse_exited.connect(func() -> void: _is_hovered = false)
	left_button.pressed.connect(_on_left_pressed)
	right_button.pressed.connect(_on_right_pressed)
	left_button.mouse_entered.connect(func() -> void: _is_hovered = true)
	left_button.mouse_exited.connect(func() -> void: _is_hovered = false)
	right_button.mouse_entered.connect(func() -> void: _is_hovered = true)
	right_button.mouse_exited.connect(func() -> void: _is_hovered = false)
	for i in range(slots.size()):
		var slot := slots[i]
		if slot == null:
			push_warning("Inventory slot %d is missing or is not a TextureRect." % (i + 1))
			continue
		slot.texture = null
		slot.visible = false
		slot.scale = Vector2.ONE
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		if not slot.gui_input.is_connected(_on_slot_gui_input):
			slot.gui_input.connect(_on_slot_gui_input.bind(i))
		slot.mouse_entered.connect(func() -> void: _is_hovered = true)
		slot.mouse_exited.connect(func() -> void: _is_hovered = false)
	_refresh_inventory()


func is_mouse_hovering() -> bool:
	return _is_hovered


func toggle_inventory() -> void:
	if inventory_popup.visible:
		inventory_popup.hide()
		_is_hovered = false
	else:
		inventory_popup.show()
		_refresh_inventory()


func _on_left_pressed() -> void:
	scroll_offset = max(0, scroll_offset - 1)
	_refresh_inventory()


func _on_right_pressed() -> void:
	var max_offset: int = max(0, GameProgress.inventory_items.size() - slots.size())
	scroll_offset = min(max_offset, scroll_offset + 1)
	_refresh_inventory()


func _refresh_inventory() -> void:
	var max_scroll: int = max(0, GameProgress.inventory_items.size() - slots.size())
	left_button.disabled = scroll_offset <= 0
	right_button.disabled = scroll_offset >= max_scroll

	for slot in slots:
		if slot == null:
			continue
		slot.texture = null
		slot.visible = false
		slot.scale = Vector2.ONE

	for i in range(slots.size()):
		var inventory_index: int = scroll_offset + i
		if inventory_index >= GameProgress.inventory_items.size():
			break
		var slot := slots[i]
		if slot == null:
			continue
		var item_name: String = GameProgress.inventory_items[inventory_index]
		var tex := _get_texture_for_item(item_name)
		if tex != null:
			slot.texture = tex
			slot.visible = true
			slot.scale = Vector2.ONE
		else:
			push_warning("No inventory texture found for item: " + item_name)


func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	var inventory_index: int = scroll_offset + slot_index
	if inventory_index < 0 or inventory_index >= GameProgress.inventory_items.size():
		return
	if slots[slot_index] == null or slots[slot_index].texture == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var item_name: String = GameProgress.inventory_items[inventory_index]
			var tex := _get_texture_for_item(item_name)
			if tex == null:
				push_warning("Cannot drag item because texture is missing: " + item_name)
				return
			DragManager.start_drag(item_name, tex, inventory_index)


func _get_texture_for_item(item_name: String) -> Texture2D:
	match item_name:
		"symbol":
			return symbol_texture
		"hidden_symbol":
			return hidden_symbol_texture
		"mushroom":
			return mushroom
		"bad_mushroom":
			return bad_mushroom
		"creature1":
			return creature1
		"creature2":
			return creature2
		"creature3":
			return creature3
		"creature4":
			return creature4
		"death_symbol":
			return death_symbol
		_:
			return null


func get_item_name_for_texture(tex: Texture2D) -> String:
	if tex == symbol_texture: return "symbol"
	if tex == hidden_symbol_texture: return "hidden_symbol"
	if tex == mushroom: return "mushroom"
	if tex == bad_mushroom: return "bad_mushroom"
	if tex == creature1: return "creature1"
	if tex == creature2: return "creature2"
	if tex == creature3: return "creature3"
	if tex == creature4: return "creature4"
	if tex == death_symbol: return "death_symbol"
	return ""


func refresh_inventory_ui() -> void:
	_refresh_inventory()
