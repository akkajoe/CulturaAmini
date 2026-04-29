extends Node

@export var start_delay: float = 10.0

@onready var bg_music: AudioStreamPlayer = $bgMusic
@onready var light_sprite = $light

func _ready() -> void:
	light_sprite.stop_blinking()
	
	# Load all scenes in the background
	SceneCache.warm_all_async([
		"res://cut_scene_1.tscn",
		"res://crash_site.tscn",
		"res://garden_puzzle.tscn",
	])
	
	await get_tree().create_timer(start_delay).timeout
	bg_music.play()
	light_sprite.start_blinking()
