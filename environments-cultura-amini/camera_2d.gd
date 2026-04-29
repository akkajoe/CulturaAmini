extends Camera2D

signal dialogue_shot_entered

@export var target_path: NodePath
@export var follow_speed: float = 8.0
@export var default_zoom: Vector2 = Vector2(1.0, 1.0)
@export var zoom_lerp_speed: float = 8.0
@export var offset_lerp_speed: float = 8.0

var target: Node2D = null
var follow_position: Vector2 = Vector2.ZERO

var in_cutscene: bool = false
var cutscene_tween: Tween = null

var zoom_zone_active: bool = false
var zoom_zone_value: Vector2 = Vector2.ONE
var zoom_zone_offset: Vector2 = Vector2.ZERO

var current_offset: Vector2 = Vector2.ZERO
var _snap_lock_frames: int = 0
var _has_snapped: bool = false


func _ready() -> void:
	zoom = default_zoom
	current_offset = Vector2.ZERO
	_snap_lock_frames = 0
	_has_snapped = false


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_resolve_target()
		if target == null:
			return

	if in_cutscene:
		return

	# Snap on first physics frame
	if not _has_snapped:
		follow_position = target.global_position
		global_position = target.global_position
		_has_snapped = true
		return

	if _snap_lock_frames > 0:
		_snap_lock_frames -= 1
		follow_position = target.global_position
		global_position = target.global_position + current_offset
		return

	follow_position = follow_position.lerp(target.global_position, follow_speed * delta)

	var desired_zoom := default_zoom
	var desired_offset := Vector2.ZERO

	if zoom_zone_active:
		desired_zoom = zoom_zone_value
		desired_offset = zoom_zone_offset

	zoom = zoom.lerp(desired_zoom, zoom_lerp_speed * delta)
	current_offset = current_offset.lerp(desired_offset, offset_lerp_speed * delta)

	global_position = follow_position + current_offset

func _resolve_target() -> void:
	if target_path.is_empty():
		return

	var node_name := str(target_path).get_file()
	if node_name.is_empty():
		return

	var found: Node2D = null

	var parent := get_parent()
	if parent != null:
		found = parent.get_node_or_null(node_name) as Node2D

	if found == null:
		var scene_root := get_tree().current_scene
		if scene_root != null:
			found = scene_root.get_node_or_null(node_name) as Node2D

	if found != null and is_instance_valid(found):
		target = found


func snap_to_target_now(explicit_target: Node2D = null) -> void:
	push_warning("SNAP CALLED: target=%s pos=%s lock_before=%d" % [
		str(explicit_target),
		str(explicit_target.global_position if explicit_target else "NULL"),
		_snap_lock_frames
	])

	if explicit_target != null:
		target = explicit_target

	if target == null:
		_resolve_target()

	if target == null:
		push_warning("snap_to_target_now: no target found, snap was skipped")
		return

	follow_position = target.global_position
	global_position = target.global_position + current_offset
	_has_snapped = true
	_snap_lock_frames = 60

func set_zoom_zone(new_zoom: Vector2, new_offset: Vector2 = Vector2.ZERO) -> void:
	zoom_zone_active = true
	zoom_zone_value = new_zoom
	zoom_zone_offset = new_offset

func clear_zoom_zone() -> void:
	zoom_zone_active = false


func enter_dialogue_shot(focus_position: Vector2, target_zoom: Vector2, duration: float) -> void:
	if cutscene_tween:
		cutscene_tween.kill()

	in_cutscene = true

	cutscene_tween = create_tween()
	cutscene_tween.set_trans(Tween.TRANS_SINE)
	cutscene_tween.set_ease(Tween.EASE_IN_OUT)

	cutscene_tween.parallel().tween_property(self, "global_position", focus_position, duration)
	cutscene_tween.parallel().tween_property(self, "zoom", target_zoom, duration)

	cutscene_tween.finished.connect(func():
		follow_position = global_position - current_offset
		dialogue_shot_entered.emit()
	)


func exit_dialogue_shot(target_zoom: Vector2, duration: float) -> void:
	if cutscene_tween:
		cutscene_tween.kill()

	if target == null:
		in_cutscene = false
		return

	var desired_zoom := default_zoom
	var desired_offset := Vector2.ZERO

	if zoom_zone_active:
		desired_zoom = zoom_zone_value
		desired_offset = zoom_zone_offset

	var return_pos := target.global_position + desired_offset

	cutscene_tween = create_tween()
	cutscene_tween.set_trans(Tween.TRANS_SINE)
	cutscene_tween.set_ease(Tween.EASE_IN_OUT)

	cutscene_tween.parallel().tween_property(self, "global_position", return_pos, duration)
	cutscene_tween.parallel().tween_property(self, "zoom", desired_zoom, duration)

	cutscene_tween.finished.connect(func():
		in_cutscene = false
		if target != null:
			follow_position = target.global_position
			current_offset = desired_offset
			global_position = target.global_position + current_offset
		zoom = desired_zoom
	)
