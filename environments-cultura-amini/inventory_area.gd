extends Area2D

@onready var _anim: AnimatedSprite2D = get_parent() as AnimatedSprite2D
var _is_open: bool = false

func _ready() -> void:
	input_pickable = true
	if _anim:
		_anim.play("close")
	input_event.connect(_on_input_event)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var ui := get_tree().get_first_node_in_group("inventory_ui")
			if ui:
				ui.toggle_inventory()
			_is_open = !_is_open
			if _anim:
				_anim.play("open" if _is_open else "close")
			get_viewport().set_input_as_handled()
