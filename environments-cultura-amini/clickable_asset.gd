extends Node2D

@export var gives_item: bool = true
@export var item_name: String = "creature1"

@export var popup_texture: Texture2D
@export var popup_offset: Vector2 = Vector2(0, -60)
@export var popup_start_scale: Vector2 = Vector2(0.35, 0.35)
@export var popup_peak_scale: Vector2 = Vector2(0.55, 0.55)
@export var popup_rise_amount: float = 40.0
@export var popup_duration: float = 0.6
@export var popup_z_index: int = 20

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area: Area2D = $Area2D

var collected: bool = false
var is_animating: bool = false


func _ready() -> void:
	add_to_group("clickable_asset")
	area.add_to_group("clickable_asset")

	if not anim_sprite.animation_finished.is_connected(_on_animation_finished):
		anim_sprite.animation_finished.connect(_on_animation_finished)

	if not area.input_event.is_connected(_on_click):
		area.input_event.connect(_on_click)

	anim_sprite.play("default")


func _on_click(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if collected:
		return

	if is_animating:
		return

	if not (event is InputEventMouseButton):
		return

	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	is_animating = true
	anim_sprite.play("clicked")


func _on_animation_finished() -> void:
	if anim_sprite.animation != "clicked":
		return

	anim_sprite.play("default")

	if gives_item and not collected and item_name != "":
		_collect_item_with_popup()
	else:
		is_animating = false


func _collect_item_with_popup() -> void:
	collected = true

	if popup_texture == null:
		GameProgress.add_inventory_item(item_name)
		print("Collected:", item_name)
		is_animating = false
		return

	var popup := Sprite2D.new()
	popup.texture = popup_texture
	popup.position = anim_sprite.position + popup_offset
	popup.scale = popup_start_scale
	popup.modulate = Color(1.2, 1.2, 1.2, 0.0)
	popup.z_index = popup_z_index
	add_child(popup)

	var start_pos := popup.position
	var end_pos := start_pos + Vector2(0, -popup_rise_amount)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(popup, "modulate:a", 1.0, popup_duration * 0.2)
	tween.tween_property(popup, "scale", popup_peak_scale, popup_duration * 0.45)
	tween.tween_property(popup, "position", end_pos, popup_duration)
	tween.tween_property(popup, "modulate:a", 0.0, popup_duration * 0.8).set_delay(popup_duration * 0.2)

	await tween.finished

	popup.queue_free()

	GameProgress.add_inventory_item(item_name)
	print("Collected:", item_name)

	is_animating = false
