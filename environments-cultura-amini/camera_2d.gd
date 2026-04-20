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

# Zoom-area state
var zoom_zone_active: bool = false
var zoom_zone_value: Vector2 = Vector2.ONE
var zoom_zone_offset: Vector2 = Vector2.ZERO

# Current runtime state
var current_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	target = get_node_or_null(target_path) as Node2D
	if target == null:
		push_warning("Camera2D.gd: target not found.")
		return

	follow_position = target.global_position
	global_position = target.global_position
	zoom = default_zoom
	current_offset = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if target == null:
		return

	if in_cutscene:
		return

	var target_pos: Vector2 = target.global_position
	follow_position = follow_position.lerp(target_pos, follow_speed * delta)

	var desired_zoom: Vector2 = default_zoom
	var desired_offset: Vector2 = Vector2.ZERO

	if zoom_zone_active:
		desired_zoom = zoom_zone_value
		desired_offset = zoom_zone_offset

	zoom = zoom.lerp(desired_zoom, zoom_lerp_speed * delta)
	current_offset = current_offset.lerp(desired_offset, offset_lerp_speed * delta)

	global_position = follow_position + current_offset


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

	var desired_zoom: Vector2 = default_zoom
	var desired_offset: Vector2 = Vector2.ZERO

	if zoom_zone_active:
		desired_zoom = zoom_zone_value
		desired_offset = zoom_zone_offset

	var return_pos: Vector2 = target.global_position + desired_offset

	cutscene_tween = create_tween()
	cutscene_tween.set_trans(Tween.TRANS_SINE)
	cutscene_tween.set_ease(Tween.EASE_IN_OUT)

	cutscene_tween.parallel().tween_property(self, "global_position", return_pos, duration)
	cutscene_tween.parallel().tween_property(self, "zoom", desired_zoom, duration)

	cutscene_tween.finished.connect(func():
		in_cutscene = false
		follow_position = target.global_position
		current_offset = desired_offset
		global_position = target.global_position + current_offset
		zoom = desired_zoom
	)
