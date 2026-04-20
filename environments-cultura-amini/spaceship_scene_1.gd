extends Node

@export var start_delay: float = 10.0

@onready var bg_music: AudioStreamPlayer = $bgMusic
@onready var light_sprite = $light

func _ready() -> void:
	light_sprite.stop_blinking()
	await get_tree().create_timer(start_delay).timeout
	bg_music.play()
	light_sprite.start_blinking()
