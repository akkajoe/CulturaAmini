extends Node

var _cache: Dictionary = {}

func get_scene(path: String) -> PackedScene:
	if path == "":
		return null

	if _cache.has(path):
		return _cache[path] as PackedScene

	var packed := load(path) as PackedScene
	if packed != null:
		_cache[path] = packed

	return packed


func has_scene(path: String) -> bool:
	return _cache.has(path)


func warm_scene(path: String) -> void:
	if path == "":
		return
	if _cache.has(path):
		return

	var packed := load(path) as PackedScene
	if packed != null:
		_cache[path] = packed


func clear_scene(path: String) -> void:
	if _cache.has(path):
		_cache.erase(path)


func clear_all() -> void:
	_cache.clear()
