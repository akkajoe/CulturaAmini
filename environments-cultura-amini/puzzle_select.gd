extends Area2D

@export_file("*.tscn") var target_scene_path: String = "res://puzzle1.tscn"
@export var walk_target_path: NodePath = ^"WalkTarget"
@export var player_path: NodePath = ^"../player"
@export var arrive_threshold: float = 40.0
@export var debug_enabled: bool = true

@onready var walk_target: Marker2D = get_node_or_null(walk_target_path) as Marker2D
@onready var player: Node2D = get_node_or_null(player_path) as Node2D

var _waiting_for_player: bool = false
var _last_logged_dist: float = -1.0


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	_debug_log("=== PUZZLE SELECT READY ===")
	_debug_log("self = %s" % name)
	_debug_log("target_scene_path = %s" % target_scene_path)
	_debug_log("walk_target = %s" % str(walk_target))
	_debug_log("player = %s" % str(player))
	_debug_log("arrive_threshold = %s" % str(arrive_threshold))


func _process(_delta: float) -> void:
	if not _waiting_for_player:
		return

	if player == null:
		_debug_log("waiting cancelled: player is null")
		_waiting_for_player = false
		return

	if walk_target == null:
		_debug_log("waiting cancelled: walk_target is null")
		_waiting_for_player = false
		return

	var dist := player.global_position.distance_to(walk_target.global_position)

	if _last_logged_dist < 0.0 or absf(dist - _last_logged_dist) > 2.0:
		_debug_log("waiting... player_pos=%s target_pos=%s dist=%s threshold=%s" % [
			str(player.global_position),
			str(walk_target.global_position),
			str(dist),
			str(arrive_threshold)
		])
		_last_logged_dist = dist

	if player.has_method("debug_hotspot_status"):
		player.debug_hotspot_status(walk_target.global_position, arrive_threshold)

	var arrived := false

	if player.has_method("is_at_world_position"):
		arrived = player.is_at_world_position(walk_target.global_position, arrive_threshold)
	else:
		arrived = dist <= arrive_threshold

	if arrived:
		_debug_log("ARRIVED at puzzle hotspot")
		_waiting_for_player = false

		if target_scene_path.is_empty():
			push_warning("PuzzleSelect: target_scene_path is empty.")
			return

		if player is CharacterBody2D:
			var p := player as CharacterBody2D
			if p.has_node("AnimatedSprite2D"):
				var spr := p.get_node("AnimatedSprite2D") as AnimatedSprite2D
				if spr != null and spr.animation != "idle":
					spr.play("idle")

		_debug_log("Pausing briefly before scene change...")
		await get_tree().create_timer(0.25).timeout

		_debug_log("Changing scene to: %s" % target_scene_path)
		get_tree().change_scene_to_file(target_scene_path)


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return

		if _waiting_for_player:
			return

		_debug_log("")
		_debug_log("=== PUZZLE HOTSPOT CLICKED ===")
		_debug_log("click accepted on %s" % name)

		if player == null:
			push_warning("PuzzleSelect: player not found.")
			_debug_log("FAILED: player is null")
			return

		if walk_target == null:
			push_warning("PuzzleSelect: walk target not found.")
			_debug_log("FAILED: walk_target is null")
			return

		_debug_log("player_pos = %s" % str(player.global_position))
		_debug_log("walk_target_pos = %s" % str(walk_target.global_position))
		_debug_log("target_scene_path = %s" % target_scene_path)

		if player.has_method("walk_to_position"):
			player.walk_to_position(walk_target.global_position)
			_waiting_for_player = true
			_last_logged_dist = -1.0
			_debug_log("Player told to walk to puzzle target")
		else:
			push_warning("Player does not have walk_to_position(global_pos).")
			_debug_log("FAILED: player missing walk_to_position")


func _on_mouse_entered() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	_debug_log("mouse entered hotspot")


func _on_mouse_exited() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_debug_log("mouse exited hotspot")


func _debug_log(msg: String) -> void:
	if debug_enabled:
		print("[PUZZLE SELECT DEBUG] ", msg)
