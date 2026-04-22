extends Node

@export_file("*.tscn") var next_scene_path: String = "res://crash_site.tscn"
@export var minimum_display_time: float = 1.0

func _ready() -> void:
	var rect := $ColorRect
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(0, 0, 0, 1)
	rect.visible = true
	rect.z_index = 100
	ResourceLoader.load_threaded_request(next_scene_path)
	ResourceLoader.load_threaded_request("res://garden_puzzle.tscn")
	ResourceLoader.load_threaded_request("res://mushroom_language_puzzle.tscn")
	await _play_cutscene()
	await _wait_for_load()
	await _ensure_garden_warmed()
	await _ensure_mushroom_warmed()
	GameProgress.code_scene_seen = true
	await _go_to_next_scene()

func _play_cutscene() -> void:
	await get_tree().create_timer(minimum_display_time).timeout

func _wait_for_load() -> void:
	var paths := [next_scene_path, "res://mushroom_language_puzzle.tscn"]
	while true:
		var all_done := true
		for path in paths:
			var status := ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				all_done = false
			elif status == ResourceLoader.THREAD_LOAD_FAILED:
				push_warning("cut_scene1.gd: async load FAILED: " + path)
		if all_done:
			return
		await get_tree().process_frame

func _ensure_garden_warmed() -> void:
	const GARDEN_PATH := "res://garden_puzzle.tscn"
	if SceneCache.has_scene_instance(GARDEN_PATH):
		push_warning("[CUTSCENE1] garden already pre-instantiated ✓")
		return
	var max_wait_frames := 120
	var waited := 0
	while waited < max_wait_frames:
		var status := ResourceLoader.load_threaded_get_status(GARDEN_PATH)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			push_warning("[CUTSCENE1] garden async load FAILED — transition will be cold")
			return
		await get_tree().process_frame
		waited += 1
	var packed := ResourceLoader.load_threaded_get(GARDEN_PATH) as PackedScene
	if packed == null:
		push_warning("[CUTSCENE1] garden packed scene is null — transition will be cold")
		return
	SceneCache._packed_cache[GARDEN_PATH] = packed
	SceneCache.warm_scene_instance(GARDEN_PATH)
	push_warning("[CUTSCENE1] garden pre-instantiated ✓  has_instance=%s" \
		% str(SceneCache.has_scene_instance(GARDEN_PATH)))

func _ensure_mushroom_warmed() -> void:
	const MUSHROOM_PATH := "res://mushroom_language_puzzle.tscn"
	if SceneCache.has_scene_instance(MUSHROOM_PATH):
		push_warning("[CUTSCENE1] mushroom already pre-instantiated ✓")
		return
	var max_wait_frames := 120
	var waited := 0
	while waited < max_wait_frames:
		var status := ResourceLoader.load_threaded_get_status(MUSHROOM_PATH)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			push_warning("[CUTSCENE1] mushroom async load FAILED — transition will be cold")
			return
		await get_tree().process_frame
		waited += 1
	var packed := ResourceLoader.load_threaded_get(MUSHROOM_PATH) as PackedScene
	if packed == null:
		push_warning("[CUTSCENE1] mushroom packed scene is null — transition will be cold")
		return
	SceneCache._packed_cache[MUSHROOM_PATH] = packed
	SceneCache.warm_scene_instance(MUSHROOM_PATH)
	push_warning("[CUTSCENE1] mushroom pre-instantiated ✓  has_instance=%s" \
		% str(SceneCache.has_scene_instance(MUSHROOM_PATH)))

func _go_to_next_scene() -> void:
	var packed := ResourceLoader.load_threaded_get(next_scene_path) as PackedScene
	if packed == null:
		packed = load(next_scene_path) as PackedScene
	if packed == null:
		push_warning("cut_scene1.gd: could not load: " + next_scene_path)
		return
	SceneCache._packed_cache[next_scene_path] = packed
	var old_scene := get_tree().current_scene
	var new_scene := packed.instantiate()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	if new_scene.has_method("on_scene_activated"):
		new_scene.on_scene_activated()
	var cam := new_scene.get_node_or_null("Camera2D")
	if cam is Camera2D and cam.is_inside_tree():
		(cam as Camera2D).make_current()
		if cam.has_method("snap_to_target_now"):
			cam.snap_to_target_now()
	await get_tree().process_frame
	$ColorRect.visible = false
	if old_scene != null:
		old_scene.call_deferred("queue_free")
