extends Node2D

@export var textures: Array[Texture2D] = []
@export var toggle_mode: bool = true

@export var gives_item: bool = false
@export var item_name: String = ""

@export var popup_texture: Texture2D
@export var popup_offset: Vector2 = Vector2(0, -60)
@export var popup_start_scale: Vector2 = Vector2(0.35, 0.35)
@export var popup_peak_scale: Vector2 = Vector2(0.55, 0.55)
@export var popup_rise_amount: float = 40.0
@export var popup_duration: float = 0.6
@export var popup_z_index: int = 20

@onready var sprite: Sprite2D = $Sprite2D
@onready var area: Area2D = $Area2D

var current_index: int = 0
var collected: bool = false
var is_animating_collect: bool = false

func _ready() -> void:
	if textures.size() > 0:
		sprite.texture = textures[0]

	area.input_event.connect(_on_click)

func _on_click(_viewport, event, _shape_idx) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	if is_animating_collect:
		return

	if textures.size() == 0 and not gives_item:
		return

	# If this object gives an item, move it to its clicked/revealed state first,
	# then show the popup symbol, and keep the clicked state.
	if gives_item and not collected and item_name != "":
		_apply_clicked_state()
		_collect_hidden_symbol_popup()
		return

	# Normal toggle / cycle visuals for non-collectible cases
	if textures.size() == 0:
		return

	if toggle_mode:
		current_index = 1 if current_index == 0 else 0
	else:
		current_index = (current_index + 1) % textures.size()

	sprite.texture = textures[current_index]

func _apply_clicked_state() -> void:
	if textures.size() == 0:
		return

	# For collectible objects, use texture[1] as the clicked/revealed state when available.
	if textures.size() > 1:
		current_index = 1
	else:
		current_index = 0

	sprite.texture = textures[current_index]

func _collect_hidden_symbol_popup() -> void:
	collected = true
	is_animating_collect = true

	var tex := popup_texture
	if tex == null:
		if textures.size() > 1:
			tex = textures[1]
		elif textures.size() > 0:
			tex = textures[0]

	if tex == null:
		push_warning("No popup texture assigned for collectible symbol.")
		GameProgress.add_inventory_item(item_name)
		is_animating_collect = false
		return

	var popup := Sprite2D.new()
	popup.texture = tex
	popup.position = sprite.position + popup_offset
	popup.scale = popup_start_scale
	popup.modulate = Color(1.2, 1.2, 1.2, 0.0)
	popup.z_index = popup_z_index
	add_child(popup)

	var start_pos := popup.position
	var end_pos := start_pos + Vector2(0, -popup_rise_amount)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		popup,
		"modulate:a",
		1.0,
		popup_duration * 0.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		popup,
		"scale",
		popup_peak_scale,
		popup_duration * 0.45
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		popup,
		"position",
		end_pos,
		popup_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		popup,
		"modulate:a",
		0.0,
		popup_duration * 0.8
	).set_delay(popup_duration * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await tween.finished

	popup.queue_free()
	GameProgress.add_inventory_item(item_name)
	print("Collected:", item_name)

	is_animating_collect = false
