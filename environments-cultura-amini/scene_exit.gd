extends Area2D

@export_file("*.tscn") var next_scene_path: String
@export var next_marker_name: String = "spawn_from_left"
@export var player_name: String = "player"

@export var inside_time_required: float = 0.18
@export var spawn_grace_time: float = 0.60
@export var require_leave_after_spawn: bool = true

var _is_transitioning: bool = false
var _trigger_enabled: bool = false
var _player_inside: bool = false
var _armed_after_leave: bool = false
var _enter_timer_id: int = 0
var _enter_timer_running: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	_is_transitioning = false
	_trigger_enabled = false
	_player_inside = false
	_armed_after_leave = false
	_enter_timer_id = 0
	_enter_timer_running = false

	monitoring = true
	monitorable = true
	set_physics_process(true)

	await get_tree().physics_frame

	if spawn_grace_time > 0.0:
		await get_tree().create_timer(spawn_grace_time).timeout

	var player := _find_player_in_scene()
	if player != null:
		_player_inside = overlaps_body(player)

	if require_leave_after_spawn:
		_armed_after_leave = not _player_inside
	else:
		_armed_after_leave = true

	_trigger_enabled = true

	if _player_inside and _armed_after_leave:
		var p := _find_player_in_scene()
		if p != null and _can_attempt_transition(p):
			_start_enter_timer()


func _physics_process(_delta: float) -> void:
	if not _trigger_enabled:
		return
	if _is_transitioning:
		return

	var player := _find_player_in_scene()
	if player == null:
		return

	var inside_now := overlaps_body(player)

	if inside_now != _player_inside:
		_player_inside = inside_now
		if not inside_now:
			_cancel_enter_timer()
			if require_leave_after_spawn:
				_armed_after_leave = true

	if not inside_now:
		return
	if not _can_attempt_transition(player):
		return
	if not _enter_timer_running:
		_start_enter_timer()


func _on_body_entered(body: Node2D) -> void:
	if not _is_valid_player(body):
		return
	_player_inside = true
	if not _can_attempt_transition(body):
		return
	if not _enter_timer_running:
		_start_enter_timer()


func _on_body_exited(body: Node2D) -> void:
	if not _is_valid_player(body):
		return
	_player_inside = false
	_cancel_enter_timer()
	if require_leave_after_spawn:
		_armed_after_leave = true


func _can_attempt_transition(player: Node2D) -> bool:
	if not _trigger_enabled:
		return false
	if _is_transitioning:
		return false
	if require_leave_after_spawn and not _armed_after_leave:
		return false
	if player != null and player.has_method("is_scene_exit_blocked") and player.is_scene_exit_blocked():
		return false
	return true


func _start_enter_timer() -> void:
	_cancel_enter_timer()
	_enter_timer_id += 1
	var my_timer_id := _enter_timer_id
	_enter_timer_running = true

	if inside_time_required > 0.0:
		await get_tree().create_timer(inside_time_required).timeout

	if my_timer_id != _enter_timer_id:
		_enter_timer_running = false
		return

	_enter_timer_running = false

	if not _trigger_enabled or _is_transitioning or not _player_inside:
		return

	var player := _find_player_in_scene()
	if player == null:
		return
	if not _can_attempt_transition(player):
		return

	_is_transitioning = true
	_trigger_enabled = false
	_cancel_enter_timer()
	monitoring = false
	monitorable = false
	go_to_scene()


func _cancel_enter_timer() -> void:
	_enter_timer_id += 1
	_enter_timer_running = false


func _find_player_in_scene() -> Node2D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null(player_name) as Node2D


func _is_valid_player(body: Node2D) -> bool:
	return body != null and body.name == player_name


func go_to_scene() -> void:
	
	if next_scene_path == "":
		push_warning("scene_exit.gd: next_scene_path is empty.")
		_is_transitioning = false
		return

	GameProgress.next_spawn_marker = next_marker_name

	var old_scene := get_tree().current_scene
	
	if old_scene == null:
		_is_transitioning = false
		return

	if old_scene is CanvasItem:
		(old_scene as CanvasItem).visible = false
	old_scene.process_mode = Node.PROCESS_MODE_DISABLED

	var new_scene: Node = SceneCache.take_scene_instance(next_scene_path)
	if new_scene == null:
		push_warning("scene_exit.gd: no pre-warmed instance for %s, cold instantiate." % next_scene_path)
		var packed_scene: PackedScene = SceneCache.get_scene(next_scene_path)
		if packed_scene == null:
			push_warning("scene_exit.gd: Could not get scene from SceneCache: " + next_scene_path)
			_is_transitioning = false
			return
		new_scene = packed_scene.instantiate()
	else:
		push_warning("scene_exit.gd: using pre-warmed instance for %s ✓" % next_scene_path)

	if new_scene is CanvasItem:
		(new_scene as CanvasItem).visible = false

	if new_scene.get_parent() == null:
		get_tree().root.add_child(new_scene)
	elif new_scene.get_parent() != get_tree().root:
		new_scene.reparent(get_tree().root, false)

	get_tree().current_scene = new_scene
	new_scene.process_mode = Node.PROCESS_MODE_INHERIT

	# Re-init player so @onready vars resolve correctly after reparent
	var player := new_scene.get_node_or_null(player_name) as Node2D
	if player != null and player.has_method("on_scene_activated"):
		player.on_scene_activated()

	if new_scene.has_method("on_scene_activated"):
		new_scene.on_scene_activated()

	var marker := new_scene.get_node_or_null(next_marker_name) as Node2D
	
	if marker != null and player != null:
		player.global_position = marker.global_position
		if marker.is_in_group("off_route_spawn") and player.has_method("spawn_off_route_exact"):
			player.spawn_off_route_exact(marker.global_position)
		elif player.has_method("set_spawn_world_position"):
			player.set_spawn_world_position(marker.global_position)
	else:
		push_warning("scene_exit.gd: marker '%s' or player '%s' not found." % [next_marker_name, player_name])

	# Pass player directly — camera locks onto it for 60 frames
	var cam := new_scene.get_node_or_null("Camera2D")
	if cam is Camera2D:
		(cam as Camera2D).make_current()
	if cam != null and cam.has_method("snap_to_target_now"):
		cam.snap_to_target_now(player)

	if new_scene is CanvasItem:
		(new_scene as CanvasItem).visible = true

	await get_tree().physics_frame
	if cam is Camera2D:
		(cam as Camera2D).make_current()
	if cam != null and cam.has_method("snap_to_target_now"):
		cam.snap_to_target_now(player)

	#GameProgress.next_spawn_marker = ""
	#old_scene.call_deferred("queue_free")
	#push_warning("oLDDDd_scene visible=%s new_scene visible=%s" % [
	#str((old_scene as CanvasItem).visible),
	#str((new_scene as CanvasItem).visible)
#])
