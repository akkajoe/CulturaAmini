extends Area2D
class_name GuideTrigger

@export var trigger_enabled: bool = true
@export var trigger_once: bool = true
@export var require_player_group: bool = true
@export var player_group_name: String = "player"

@export var lock_player: bool = true
@export var stop_player_on_trigger: bool = true

@export var use_zoom: bool = true
@export var zoom_value: Vector2 = Vector2(1.3, 1.3)
@export var zoom_time: float = 0.4
@export var zoom_out_time: float = 0.4
@export var normal_zoom: Vector2 = Vector2(1.0, 1.0)
@export var camera_path: NodePath

@export var focus_offset: Vector2 = Vector2(0, -110)

@export var show_popup: bool = true
@export var popup_path: NodePath
@export var speech_point_path: NodePath = ^"../SpeechPoint"
@export var popup_delay: float = 0.0

var _triggered: bool = false
var _dialogue_started: bool = false
var _release_called: bool = false

var _player_ref: Node = null
var _camera_ref: Camera2D = null
var _popup_ref: CanvasItem = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_trigger_enabled(trigger_enabled)

	if popup_path != NodePath():
		_popup_ref = get_node_or_null(popup_path) as CanvasItem

	if _popup_ref:
		_try_connect_popup_close_signals(_popup_ref)
	elif show_popup:
		push_warning("GuideTrigger: popup_path is assigned incorrectly or popup node was not found.")


func set_trigger_enabled(enabled: bool) -> void:
	trigger_enabled = enabled
	monitoring = enabled
	monitorable = enabled

	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.disabled = not enabled


func _on_body_entered(body: Node) -> void:
	if not trigger_enabled:
		return

	if trigger_once and _triggered:
		return

	if require_player_group and not body.is_in_group(player_group_name):
		return

	_triggered = true
	_dialogue_started = false
	_release_called = false
	_player_ref = body
	_camera_ref = _resolve_camera(body)

	if stop_player_on_trigger and body.has_method("stop_now"):
		body.stop_now()

	if lock_player:
		_set_player_locked(body, true)

	if use_zoom and _camera_ref:
		_play_cutscene_focus(body, _camera_ref)

		if _camera_ref.has_signal("dialogue_shot_entered"):
			await _camera_ref.dialogue_shot_entered

	if popup_delay > 0.0:
		await get_tree().create_timer(popup_delay).timeout

	if not show_popup:
		return

	if _popup_ref == null:
		push_warning("GuideTrigger: show_popup is true, but no popup was found.")
		return

	var speech_point := get_node_or_null(speech_point_path) as Marker2D
	if speech_point and _popup_ref.has_method("place_at_world_position"):
		_popup_ref.call("place_at_world_position", speech_point.global_position)

	await get_tree().process_frame

	_dialogue_started = true

	if _popup_ref.has_method("start_dialogue"):
		_popup_ref.call("start_dialogue", body, self)
	else:
		_popup_ref.show()


func release_player() -> void:
	if _release_called:
		return

	_release_called = true
	_dialogue_started = false

	if _player_ref and lock_player:
		_set_player_locked(_player_ref, false)

	if use_zoom and _camera_ref:
		_release_cutscene_focus(_camera_ref)

	# Important: after the guide shot ends, let any overlapping zoom areas re-apply themselves
	_refresh_overlapping_zoom_areas()


func _release_cutscene_focus(cam: Camera2D) -> void:
	if cam and cam.has_method("exit_dialogue_shot"):
		cam.exit_dialogue_shot(normal_zoom, zoom_out_time)


func _play_cutscene_focus(player: Node, cam: Camera2D) -> void:
	if cam == null:
		return

	var focus_pos := _compute_focus_position(player, cam)

	if cam.has_method("enter_dialogue_shot"):
		cam.enter_dialogue_shot(focus_pos, zoom_value, zoom_time)


func _compute_focus_position(player: Node, cam: Camera2D) -> Vector2:
	var player_node := player as Node2D
	var guide_node := get_parent() as Node2D

	if player_node == null or guide_node == null:
		return cam.global_position

	var midpoint := (player_node.global_position + guide_node.global_position) * 0.5
	return midpoint + focus_offset


func _set_player_locked(player: Node, locked: bool) -> void:
	if player and player.has_method("set_movement_enabled"):
		player.set_movement_enabled(not locked)


func _resolve_camera(player: Node) -> Camera2D:
	if camera_path != NodePath():
		var explicit := get_node_or_null(camera_path) as Camera2D
		if explicit:
			return explicit

	var player_cam := player.get_node_or_null("Camera2D") as Camera2D
	if player_cam:
		return player_cam

	return get_viewport().get_camera_2d()


func _try_connect_popup_close_signals(popup: CanvasItem) -> void:
	if popup.has_signal("dialogue_finished"):
		if not popup.dialogue_finished.is_connected(_on_popup_closed):
			popup.dialogue_finished.connect(_on_popup_closed)
	else:
		push_warning("GuideTrigger: popup does not have a dialogue_finished signal.")


func _on_popup_closed() -> void:
	if not _dialogue_started:
		return

	release_player()


func _refresh_overlapping_zoom_areas() -> void:
	if _player_ref == null:
		return

	# Let transforms/collision states settle first
	_call_refresh_zoom_areas_deferred()


func _call_refresh_zoom_areas_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var world := get_viewport().world_2d
	if world == null:
		return

	for area in get_tree().get_nodes_in_group("zoom_areas"):
		if area != null and area.has_method("refresh_if_player_inside_delayed"):
			area.refresh_if_player_inside_delayed()
