extends Area2D

@export var camera_path: NodePath = ^"../Camera2D"
@export var zoom_in_value: Vector2 = Vector2(1.65, 1.65)
@export var zoom_zone_offset: Vector2 = Vector2(0, -170)
@export var exit_delay: float = 0.15
@export var recheck_delay: float = 0.25

var _camera: Camera2D
var _exit_request_id: int = 0


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera2D

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	_exit_request_id += 1
	_apply_zoom()


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	_exit_request_id += 1
	var my_request_id: int = _exit_request_id

	await get_tree().create_timer(exit_delay).timeout

	if my_request_id != _exit_request_id:
		return

	if _player_is_still_inside():
		return

	_clear_zoom()


func _apply_zoom() -> void:
	if _camera and _camera.has_method("set_zoom_zone"):
		_camera.set_zoom_zone(zoom_in_value, zoom_zone_offset)


func _clear_zoom() -> void:
	if _camera and _camera.has_method("clear_zoom_zone"):
		_camera.clear_zoom_zone()


func _player_is_still_inside() -> bool:
	for overlapping_body in get_overlapping_bodies():
		if overlapping_body.is_in_group("player"):
			return true
	return false


func refresh_if_player_inside() -> void:
	if _player_is_still_inside():
		_apply_zoom()


func refresh_if_player_inside_delayed() -> void:
	await get_tree().create_timer(recheck_delay).timeout
	refresh_if_player_inside()
