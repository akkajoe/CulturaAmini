extends Area2D
class_name MushroomPickup

@export var mushroom_item_name: String = "mushroom"
@onready var sprite: AnimatedSprite2D = $psych

func _ready() -> void:
	add_to_group("clickable_asset")
	input_pickable = true
	if GameProgress.mushroom_picked_up:
		queue_free()

func grow() -> void:
	sprite.play("default")

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick_up()

func _pick_up() -> void:
	GameProgress.add_inventory_item(mushroom_item_name)
	var inventory_ui := get_tree().get_first_node_in_group("inventory_ui")
	if inventory_ui != null and inventory_ui.has_method("refresh_inventory_ui"):
		inventory_ui.refresh_inventory_ui()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): queue_free())
