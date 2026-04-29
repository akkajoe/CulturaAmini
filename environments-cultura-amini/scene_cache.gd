extends Node

var _packed_cache: Dictionary = {}
var _instance_cache: Dictionary = {}


func get_scene(path: String) -> PackedScene:
	if path == "":
		return null
	if _packed_cache.has(path):
		return _packed_cache[path] as PackedScene
	var packed := load(path) as PackedScene
	if packed != null:
		_packed_cache[path] = packed
	return packed


func has_scene(path: String) -> bool:
	return _packed_cache.has(path)


func warm_scene(path: String) -> void:
	if path == "":
		return
	if _packed_cache.has(path):
		return
	var packed := load(path) as PackedScene
	if packed != null:
		_packed_cache[path] = packed


func warm_scene_instance(path: String) -> void:
	if path == "":
		return
	if _instance_cache.has(path):
		return
	var packed := get_scene(path)
	if packed == null:
		return
	var inst := packed.instantiate()
	if inst == null:
		return
	# Store it WITHOUT adding to the scene tree
	_instance_cache[path] = inst


func has_scene_instance(path: String) -> bool:
	return _instance_cache.has(path)


func take_scene_instance(path: String) -> Node:
	if not _instance_cache.has(path):
		return null
	var inst: Node = _instance_cache[path]
	_instance_cache.erase(path)
	return inst


func _reset_process_mode_recursive(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_INHERIT
	for child in node.get_children():
		_reset_process_mode_recursive(child)


func clear_scene(path: String) -> void:
	if _packed_cache.has(path):
		_packed_cache.erase(path)
	if _instance_cache.has(path):
		var inst: Node = _instance_cache[path]
		_instance_cache.erase(path)
		if is_instance_valid(inst):
			inst.queue_free()


func clear_all() -> void:
	for path in _instance_cache.keys():
		var inst: Node = _instance_cache[path]
		if is_instance_valid(inst):
			inst.queue_free()
	_instance_cache.clear()
	_packed_cache.clear()


func warm_scene_async(path: String) -> void:
	if path == "" or _packed_cache.has(path):
		return
	ResourceLoader.load_threaded_request(path)


var _pending_async: Array = []


func warm_all_async(paths: Array) -> void:
	for path in paths:
		if path == "" or _packed_cache.has(path):
			continue
		if not _pending_async.has(path):
			_pending_async.append(path)
			ResourceLoader.load_threaded_request(path)


func _process(_delta: float) -> void:
	for path in _pending_async.duplicate():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(path) as PackedScene
			if packed != null:
				_packed_cache[path] = packed
				push_warning("[SceneCache] async load done: " + path)
			_pending_async.erase(path)
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			push_warning("[SceneCache] async load FAILED: " + path)
			_pending_async.erase(path)
