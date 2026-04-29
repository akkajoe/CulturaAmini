extends Node

@export var display_time: float = 10.0
@export_file("*.tscn") var next_scene_path: String = "res://cutscene1.tscn"

func _ready() -> void:
	if next_scene_path != "":
		ResourceLoader.load_threaded_request(next_scene_path)
	await get_tree().create_timer(display_time).timeout
	GameProgress.code_scene_seen = true
	await _go_to_next_scene()

func _go_to_next_scene() -> void:
	if next_scene_path.is_empty():
		push_warning("CodeScene.gd: next_scene_path is empty.")
		return
	push_warning(next_scene_path)

	var old_scene := get_tree().current_scene
	if old_scene == null:
		push_warning("CodeScene.gd: current scene is null.")
		return

	var new_scene: Node = SceneCache.take_scene_instance(next_scene_path)

	if new_scene == null:
		var max_frames := 120
		var waited := 0
		while waited < max_frames:
			var status := ResourceLoader.load_threaded_get_status(next_scene_path)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				var packed := ResourceLoader.load_threaded_get(next_scene_path) as PackedScene
				if packed != null:
					new_scene = packed.instantiate()
				break
			elif status == ResourceLoader.THREAD_LOAD_FAILED:
				push_warning("CodeScene.gd: async load failed: " + next_scene_path)
				return
			await get_tree().process_frame
			waited += 1

		if new_scene == null:
			var packed := load(next_scene_path) as PackedScene
			if packed == null:
				push_warning("CodeScene.gd: failed to load next scene: " + next_scene_path)
				return
			new_scene = packed.instantiate()

	if new_scene == null:
		push_warning("CodeScene.gd: failed to instantiate next scene.")
		return

	old_scene.set("visible", false)
	old_scene.process_mode = Node.PROCESS_MODE_DISABLED

	if new_scene.get_parent() == null:
		get_tree().root.add_child(new_scene)
	elif new_scene.get_parent() != get_tree().root:
		new_scene.reparent(get_tree().root, false)

	get_tree().current_scene = new_scene
	new_scene.process_mode = Node.PROCESS_MODE_INHERIT
	new_scene.set("visible", true)

	if new_scene.has_method("on_scene_activated"):
		new_scene.on_scene_activated()

	var cam := new_scene.get_node_or_null("Camera2D")
	if cam is Camera2D and cam.is_inside_tree():
		(cam as Camera2D).make_current()
		if cam.has_method("snap_to_target_now"):
			cam.snap_to_target_now()

	old_scene.call_deferred("queue_free")
