extends Area2D

signal clicked(index: int)
signal match_finished(index: int)

@export var index: int = 0
@export var clickable: bool = true

@export var tex0: Texture2D
@export var tex1: Texture2D
@export var tex2: Texture2D

@export var use_target_sizes: bool = false

@export var diameter_state0: float = 80.0
@export var diameter_state1: float = 80.0
@export var diameter_state2: float = 80.0

@export var offset_state0: Vector2 = Vector2.ZERO
@export var offset_state1: Vector2 = Vector2.ZERO
@export var offset_state2: Vector2 = Vector2.ZERO

@export var target_diameter_state0: float = 55.0
@export var target_diameter_state1: float = 55.0
@export var target_diameter_state2: float = 55.0

@export var target_offset_state0: Vector2 = Vector2.ZERO
@export var target_offset_state1: Vector2 = Vector2.ZERO
@export var target_offset_state2: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

var _current_state: int = 0
var _in_match: bool = false

var _rest_modulate: Color = Color(1, 1, 1, 1)
var _fade_tween: Tween
var _pop_tween: Tween


func _ready() -> void:
	input_pickable = true

	if sprite != null:
		sprite.centered = true
	if anim != null:
		anim.centered = true

	if anim != null and not anim.animation_finished.is_connected(_on_anim_finished):
		anim.animation_finished.connect(_on_anim_finished)

	_refresh_visual_mode()

	var v := _get_visual_any()
	if v != null:
		_rest_modulate = v.modulate
		_rest_modulate.a = 1.0


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not clickable:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(index)


func set_state(s: int) -> void:
	_current_state = s
	_refresh_visual_mode()

	if _in_match:
		_apply_visibility_and_fit(s)
		return

	_apply_state_visual(s)
	_apply_visibility_and_fit(s)


func play_match_anim() -> void:
	if _in_match:
		return

	_refresh_visual_mode()

	var v := _get_visual_any()
	if v == null:
		_in_match = false
		match_finished.emit(index)
		return

	if _can_use_anim() and anim.sprite_frames != null and anim.sprite_frames.has_animation("match"):
		_in_match = true
		anim.play("match")
		return

	_in_match = true

	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()

	var base_scale: Vector2 = (v as Node2D).scale
	var base_mod: Color = v.modulate

	_pop_tween = create_tween()
	_pop_tween.set_trans(Tween.TRANS_BACK)
	_pop_tween.set_ease(Tween.EASE_OUT)

	_pop_tween.tween_property(v, "scale", base_scale * 1.18, 0.12)
	_pop_tween.parallel().tween_property(v, "modulate", Color(1.2, 1.2, 1.2, base_mod.a), 0.10)
	_pop_tween.tween_property(v, "scale", base_scale, 0.14)
	_pop_tween.parallel().tween_property(v, "modulate", base_mod, 0.16)

	_pop_tween.finished.connect(func():
		_in_match = false
		set_state(_current_state)
		match_finished.emit(index)
	, CONNECT_ONE_SHOT)


func play_target_fade_out(dur: float = 0.12) -> void:
	var v := _get_visual_any()
	if v == null:
		return

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_SINE)
	_fade_tween.set_ease(Tween.EASE_IN_OUT)

	var c: Color = v.modulate
	_fade_tween.tween_property(v, "modulate", Color(c.r, c.g, c.b, 0.0), dur)


func play_target_fade_in(dur: float = 0.16) -> void:
	var v := _get_visual_any()
	if v == null:
		return

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	v.modulate = Color(_rest_modulate.r, _rest_modulate.g, _rest_modulate.b, 0.0)

	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_SINE)
	_fade_tween.set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_property(v, "modulate", _rest_modulate, dur)


func _on_anim_finished() -> void:
	if anim == null:
		return

	if anim.animation != "match":
		return

	_in_match = false
	set_state(_current_state)
	match_finished.emit(index)


func _refresh_visual_mode() -> void:
	if _can_use_anim():
		if anim != null:
			anim.visible = true
		if sprite != null:
			sprite.visible = false
	else:
		if sprite != null:
			sprite.visible = true
		if anim != null:
			anim.visible = false


func _can_use_anim() -> bool:
	if anim == null:
		return false
	if anim.sprite_frames == null:
		return false

	return anim.sprite_frames.has_animation("idle_0") \
		and anim.sprite_frames.has_animation("idle_1") \
		and anim.sprite_frames.has_animation("idle_2")


func _get_visual_any() -> CanvasItem:
	if _can_use_anim():
		return anim
	return sprite


func _apply_state_visual(s: int) -> void:
	if _can_use_anim():
		_play_idle_for_state(s)
	else:
		if sprite == null:
			return
		match s:
			0:
				sprite.texture = tex0
			1:
				sprite.texture = tex1
			2:
				sprite.texture = tex2
			_:
				sprite.texture = null


func _play_idle_for_state(s: int) -> void:
	if anim == null:
		return

	match s:
		0:
			anim.play("idle_0")
		1:
			anim.play("idle_1")
		2:
			anim.play("idle_2")
		_:
			anim.stop()


func _apply_visibility_and_fit(s: int) -> void:
	var v := _get_visual_any()
	if v == null:
		return

	if s < 0 or s > 2:
		v.visible = false
		return

	v.visible = true
	_apply_size_and_offset(s)


func _apply_size_and_offset(s: int) -> void:
	var v := _get_visual_any()
	if v == null:
		return

	var diameter: float = _get_diameter_for_state(s)
	var offs: Vector2 = _get_offset_for_state(s)

	_fit_visual(diameter)
	(v as Node2D).position = offs
	(v as Node2D).rotation = -rotation

	_rest_modulate = v.modulate
	_rest_modulate.a = 1.0


func _get_diameter_for_state(s: int) -> float:
	if use_target_sizes:
		if s == 0:
			return target_diameter_state0
		if s == 1:
			return target_diameter_state1
		if s == 2:
			return target_diameter_state2
		return target_diameter_state0
	else:
		if s == 0:
			return diameter_state0
		if s == 1:
			return diameter_state1
		if s == 2:
			return diameter_state2
		return diameter_state0


func _get_offset_for_state(s: int) -> Vector2:
	if use_target_sizes:
		if s == 0:
			return target_offset_state0
		if s == 1:
			return target_offset_state1
		if s == 2:
			return target_offset_state2
		return target_offset_state0
	else:
		if s == 0:
			return offset_state0
		if s == 1:
			return offset_state1
		if s == 2:
			return offset_state2
		return offset_state0


func _fit_visual(diameter: float) -> void:
	var v := _get_visual_any()
	if v == null:
		return

	var w: float = 0.0
	var h: float = 0.0

	if v is Sprite2D:
		var sp := v as Sprite2D
		if sp.texture == null:
			return
		w = float(sp.texture.get_width())
		h = float(sp.texture.get_height())
	else:
		var an := v as AnimatedSprite2D
		var tex := an.sprite_frames.get_frame_texture(an.animation, an.frame) \
			if (an.sprite_frames != null and an.sprite_frames.has_animation(an.animation)) else null
		if tex == null:
			return
		w = float(tex.get_width())
		h = float(tex.get_height())

	if w <= 0.0 or h <= 0.0:
		return

	var scale_factor: float = (diameter * 0.8) / max(w, h)
	(v as Node2D).scale = Vector2(scale_factor, scale_factor)
