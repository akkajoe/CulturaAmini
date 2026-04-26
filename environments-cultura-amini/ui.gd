extends CanvasLayer

@onready var bag_button: TextureButton = $bagButton
@onready var inventory_popup: Control = $inventoryPopup
@onready var close_button: Button = $inventoryPopup/CloseButton

@onready var slots: Array[TextureRect] = [
	get_node_or_null("inventoryPopup/Slot1") as TextureRect,
	get_node_or_null("inventoryPopup/Slot2") as TextureRect,
	get_node_or_null("inventoryPopup/Slot3") as TextureRect,
	get_node_or_null("inventoryPopup/Slot4") as TextureRect
]

@export var symbol_texture: Texture2D
@export var hidden_symbol_texture: Texture2D
@export var mushroom: Texture2D
@export var creature1: Texture2D
@export var creature2: Texture2D
@export var creature3: Texture2D
@export var death_symbol: Texture2D

var _is_hovered: bool = false


func _ready() -> void:
	add_to_group("inventory_ui")
	add_to_group("ui_hoverable")

	inventory_popup.hide()

	bag_button.pressed.connect(_on_bag_button_pressed)
	close_button.pressed.connect(_on_close_pressed)

	bag_button.mouse_entered.connect(func() -> void: _is_hovered = true)
	bag_button.mouse_exited.connect(func() -> void: _is_hovered = false)

	close_button.mouse_entered.connect(func() -> void: _is_hovered = true)
	close_button.mouse_exited.connect(func() -> void: _is_hovered = false)

	inventory_popup.mouse_entered.connect(func() -> void: _is_hovered = true)
	inventory_popup.mouse_exited.connect(func() -> void: _is_hovered = false)

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


func _on_bag_button_pressed() -> void:
	inventory_popup.visible = not inventory_popup.visible

	if inventory_popup.visible:
		_refresh_inventory()


func _on_close_pressed() -> void:
	inventory_popup.hide()
	_is_hovered = false


func _refresh_inventory() -> void:
	for slot in slots:
		if slot == null:
			continue

		slot.texture = null
		slot.visible = false
		slot.scale = Vector2.ONE

	for i in range(min(GameProgress.inventory_items.size(), slots.size())):
		var slot := slots[i]
		if slot == null:
			continue

		var item_name: String = GameProgress.inventory_items[i]
		var tex := _get_texture_for_item(item_name)

		if tex != null:
			slot.texture = tex
			slot.visible = true
			slot.scale = Vector2.ONE
		else:
			push_warning("No inventory texture found for item: " + item_name)


func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= GameProgress.inventory_items.size():
		return

	if slots[slot_index] == null or slots[slot_index].texture == null:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var item_name: String = GameProgress.inventory_items[slot_index]
			var tex := _get_texture_for_item(item_name)

			if tex == null:
				push_warning("Cannot drag item because texture is missing: " + item_name)
				return

			DragManager.start_drag(item_name, tex, slot_index)


func _get_texture_for_item(item_name: String) -> Texture2D:
	match item_name:
		"symbol":
			return symbol_texture
		"hidden_symbol":
			return hidden_symbol_texture
		"mushroom":
			return mushroom
		"creature1":
			return creature1
		"creature2":
			return creature2
		"creature3":
			return creature3
		"death_symbol":
			return death_symbol
		_:
			return null

func refresh_inventory_ui() -> void:
	_refresh_inventory()
