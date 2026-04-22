extends Node2D

func _ready() -> void:
	SceneCache.warm_scene("res://garden_puzzle.tscn")
	SceneCache.warm_scene_instance("res://garden_puzzle.tscn")
	push_warning("IN MUSHROMMMMMM")
