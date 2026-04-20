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


func _ready() -> void:
	add_to_group("inventory_ui")

	inventory_popup.hide()

	bag_button.pressed.connect(_on_bag_button_pressed)
	close_button.pressed.connect(_on_close_pressed)

	for i in range(slots.size()):
		if slots[i] == null:
			push_warning("Inventory slot %d is missing or is not a TextureRect." % (i + 1))
			continue

		slots[i].texture = null
		slots[i].visible = false
		slots[i].mouse_filter = Control.MOUSE_FILTER_STOP
		slots[i].gui_input.connect(_on_slot_gui_input.bind(i))

	_refresh_inventory()


func _on_bag_button_pressed() -> void:
	inventory_popup.visible = not inventory_popup.visible
	if inventory_popup.visible:
		_refresh_inventory()


func _on_close_pressed() -> void:
	inventory_popup.hide()


func _refresh_inventory() -> void:
	for slot in slots:
		if slot == null:
			continue
		slot.texture = null
		slot.visible = false

	for i in range(min(GameProgress.inventory_items.size(), slots.size())):
		var slot := slots[i]
		if slot == null:
			continue

		var item_name := GameProgress.inventory_items[i]
		var tex := _get_texture_for_item(item_name)

		if tex != null:
			slot.texture = tex
			slot.visible = true


func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= GameProgress.inventory_items.size():
		return

	if slots[slot_index] == null or slots[slot_index].texture == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var item_name := GameProgress.inventory_items[slot_index]
		var tex := _get_texture_for_item(item_name)
		DragManager.start_drag(item_name, tex, slot_index)

func _get_texture_for_item(item_name: String) -> Texture2D:
	match item_name:
		"symbol":
			return symbol_texture
		"hidden_symbol":
			return hidden_symbol_texture
		_:
			return null


func refresh_inventory_ui() -> void:
	_refresh_inventory()
