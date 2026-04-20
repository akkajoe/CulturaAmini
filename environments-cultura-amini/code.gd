extends Node

@export var display_time: float = 10.0
@export_file("*.tscn") var next_scene_path: String = "res://crash_site.tscn"
@export var next_marker_name: String = "spawn_from_right"

func _ready() -> void:
	await get_tree().create_timer(display_time).timeout

	GameProgress.code_scene_seen = true
	GameProgress.next_spawn_marker = next_marker_name

	if not next_scene_path.is_empty():
		get_tree().change_scene_to_file(next_scene_path)
	else:
		push_warning("Next scene path is empty.")
