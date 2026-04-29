extends Node2D

func _ready() -> void:
	_try_play_music()
	
func _try_play_music() -> void:
	if has_node("bgMusic"):
		var bg := $bgMusic
		if not bg.playing:
			bg.play()
