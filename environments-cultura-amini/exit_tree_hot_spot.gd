extends Area2D

@export var path_a: Path2D
@export var path_b: Path2D
@export var anchor_a_path: NodePath
@export var anchor_b_path: NodePath

@export var fade_rect_path: NodePath
@export var fade_time: float = 0.18

@export var min_rearm_time: float = 0.35  # small wait even after exit
var _busy: bool = false
var _armed: bool = true

@onready var anchor_a: Marker2D = get_node(anchor_a_path) as Marker2D
@onready var anchor_b: Marker2D = get_node(anchor_b_path) as Marker2D
@onready var fade_rect: ColorRect = get_node(fade_rect_path) as ColorRect

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if fade_rect != null:
		fade_rect.visible = true
		var c: Color = fade_rect.modulate
		c.a = 0.0
		fade_rect.modulate = c

func _on_body_entered(body: Node) -> void:
	if not _armed:
		return
	if _busy:
		return

	if path_a == null or path_b == null or anchor_a == null or anchor_b == null or fade_rect == null:
		push_error("Hotspot: assign paths/anchors/fade_rect_path.")
		return

	if not (body.has_method("get_current_path")
		and body.has_method("lock_controls")
		and body.has_method("unlock_controls")
		and body.has_method("switch_path_at_anchor")):
		return

	var cur_path: Path2D = body.get_current_path()
	if cur_path != path_a and cur_path != path_b:
		return

	_busy = true
	_armed = false
	set_deferred("monitoring", false) 


	var lock_ms: int = int((fade_time * 2.0) * 1000.0) + 150
	body.lock_controls(lock_ms)

	await _fade_to(1.0)

	if cur_path == path_a:
		body.switch_path_at_anchor(path_b, anchor_b.global_position)
	else:
		body.switch_path_at_anchor(path_a, anchor_a.global_position)

	await _fade_to(0.0)

	body.unlock_controls()
	_busy = false


func _on_body_exited(body: Node) -> void:
	# once the player physically leaves the hotspot, we can arm it again
	if _armed:
		return
	_rearm_deferred()


func _rearm_deferred() -> void:
	# small delay to not instantly retrigger on edge jitter
	# (especially if player snaps near boundary)
	await get_tree().create_timer(min_rearm_time).timeout
	set_deferred("monitoring", true)
	_armed = true


func _fade_to(alpha: float) -> void:
	var t: Tween = create_tween()
	t.tween_property(fade_rect, "modulate:a", alpha, fade_time)
	await t.finished
