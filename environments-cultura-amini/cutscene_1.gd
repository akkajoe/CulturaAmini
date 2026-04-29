extends Node

@export_file("*.tscn") var next_scene_path: String = "res://cut_scene_1.tscn"

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer

func _ready() -> void:
	call_deferred("_start_video")

func _start_video() -> void:
	if video_player == null:
		push_warning("VideoScene: VideoStreamPlayer node not found!")
		return
	if video_player.stream == null:
		push_warning("VideoScene: No stream assigned to VideoStreamPlayer!!!!!!!!!!")
		return

	video_player.finished.connect(_on_video_finished)
	video_player.play()

func _on_video_finished() -> void:
	if next_scene_path.is_empty():
		push_warning("VideoScene: next_scene_path is empty.")
		return
	get_tree().change_scene_to_file(next_scene_path)
