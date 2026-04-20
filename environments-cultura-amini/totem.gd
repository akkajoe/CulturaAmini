extends Area2D

signal turned

@export var symbols: Array[String] = ["sym1", "sym2", "sym3"]
@export var current_index: int = 0

@onready var sprite = $Sprite2D

func _ready():
	update_visual()

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		turn()

func turn():
	current_index = (current_index + 1) % symbols.size()
	update_visual()
	emit_signal("turned")

func get_current_symbol() -> String:
	return symbols[current_index]

func update_visual():
	# Replace this with your actual textures/frames logic
	# Example if using one texture per symbol:
	match symbols[current_index]:
		"sym1":
			sprite.frame = 0
		"sym2":
			sprite.frame = 1
		"sym3":
			sprite.frame = 2
