extends CharacterBody2D

enum ProgressFlag {
	NONE,
	CRASH_SITE_GUIDE_DONE,
	GARDEN_INTRO_DONE,
	MOUNTAIN_CREATURE_GUIDE_DONE
}

@export var move_speed: float = 100.0
@export var offscreen_margin: float = 80.0
@export var min_exit_time: float = 5.0
@export var sprite_path: NodePath = ^"AnimatedSprite2D"
@export var camera_path: NodePath = ^"../Camera2D"
@export var progress_flag: ProgressFlag = ProgressFlag.NONE

var is_exiting: bool = false
var exit_start_time: float = 0.0

@onready var sprite: Node = get_node_or_null(sprite_path)
@onready var camera: Camera2D = get_node_or_null(camera_path) as Camera2D


func _ready() -> void:
	if sprite is AnimatedSprite2D:
		(sprite as AnimatedSprite2D).play("idle")
	if _is_progress_done():
		hide()
		set_collision_layer(0)
		set_collision_mask(0)


func _is_progress_done() -> bool:
	match progress_flag:
		ProgressFlag.CRASH_SITE_GUIDE_DONE:
			return GameProgress.guide_dialogue_done
		ProgressFlag.GARDEN_INTRO_DONE:
			return GameProgress.garden_intro_done
		ProgressFlag.MOUNTAIN_CREATURE_GUIDE_DONE:
			return GameProgress.mountain_creature_guide_done
		ProgressFlag.NONE:
			return false
	return false


func _physics_process(_delta: float) -> void:
	if not is_exiting:
		velocity = Vector2.ZERO
		return
	velocity = Vector2(move_speed, 0.0)
	move_and_slide()
	var elapsed := (Time.get_ticks_msec() / 1000.0) - exit_start_time
	if elapsed >= min_exit_time and _is_outside_camera_view():
		hide()
		velocity = Vector2.ZERO
		is_exiting = false


func on_seed_received() -> void:
	if sprite is AnimatedSprite2D:
		(sprite as AnimatedSprite2D).play("idle")


func start_second_dialogue(speech_box: Node, lines: Array[String]) -> void:
	if sprite is AnimatedSprite2D:
		(sprite as AnimatedSprite2D).play("idle")
	if speech_box.has_method("start_dialogue_lines"):
		speech_box.call("start_dialogue_lines", lines)


func start_exit() -> void:
	if is_exiting:
		return
	_mark_progress_done()
	is_exiting = true
	exit_start_time = Time.get_ticks_msec() / 1000.0
	set_collision_layer(0)
	set_collision_mask(0)
	if sprite is AnimatedSprite2D:
		var s := sprite as AnimatedSprite2D
		s.flip_h = true
		s.play("walk")
	elif sprite is Sprite2D:
		var s2 := sprite as Sprite2D
		s2.flip_h = true


func _mark_progress_done() -> void:
	match progress_flag:
		ProgressFlag.CRASH_SITE_GUIDE_DONE:
			GameProgress.guide_dialogue_done = true
		ProgressFlag.GARDEN_INTRO_DONE:
			GameProgress.garden_intro_done = true
		ProgressFlag.MOUNTAIN_CREATURE_GUIDE_DONE:
			GameProgress.mountain_creature_guide_done = true
		ProgressFlag.NONE:
			pass


func _is_outside_camera_view() -> bool:
	if camera == null:
		return false
	var visible_rect := _get_camera_world_rect()
	var guide_rect := _get_guide_world_rect()
	return not visible_rect.intersects(guide_rect)


func _get_camera_world_rect() -> Rect2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var visible_size := viewport_size * camera.zoom
	var top_left := camera.get_screen_center_position() - (visible_size * 0.5)
	return Rect2(
		top_left - Vector2(offscreen_margin, offscreen_margin),
		visible_size + Vector2(offscreen_margin * 2.0, offscreen_margin * 2.0)
	)


func _get_guide_world_rect() -> Rect2:
	if sprite is AnimatedSprite2D:
		var s := sprite as AnimatedSprite2D
		var frames := s.sprite_frames
		if frames != null and frames.has_animation(s.animation):
			var tex := frames.get_frame_texture(s.animation, s.frame)
			if tex != null:
				var size := tex.get_size() * s.scale
				return Rect2(s.global_position - size * 0.5, size)
	elif sprite is Sprite2D:
		var s2 := sprite as Sprite2D
		if s2.texture != null:
			var size := s2.texture.get_size() * s2.scale
			return Rect2(s2.global_position - size * 0.5, size)
	return Rect2(global_position - Vector2(16, 16), Vector2(32, 32))
