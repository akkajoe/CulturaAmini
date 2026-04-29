extends CharacterBody2D

@export var routes_parent_path: NodePath = ^"../traversalRoutes"
@export var markers_parent_path: NodePath = ^"../traversalMarkers"
@export var jump_points_parent_path: NodePath = ^"../traversalJumpPoints"
@export var start_route_path: NodePath
@export var cursor_default_path: NodePath
@export var cursor_interact_path: NodePath

@onready var cursor_default: AnimatedSprite2D = get_node_or_null(cursor_default_path) as AnimatedSprite2D
@onready var cursor_interact: AnimatedSprite2D = get_node_or_null(cursor_interact_path) as AnimatedSprite2D

@export var scene_exit_block_after_spawn: float = 1.0
@export var scene_exit_block_after_jump: float = 1.0
var _scene_exit_block_until_msec: int = 0

@export var speed: float = 200.0
@export var jump_duration: float = 0.7
@export var jump_height: float = 80.0
@export var route_click_radius: float = 20.0
@export var marker_click_radius: float = 45.0
@export var connected_route_click_radius: float = 55.0
@export var tangent_sample: float = 8.0

@export var jump_point_entry_radius: float = 90.0
@export var jump_point_target_radius: float = 70.0
@export var jump_point_route_snap_radius: float = 65.0
@export var jump_point_arrive_threshold: float = 10.0

@export var cursor_path: NodePath = ^"../cursor/AnimatedSprite2D"

@export var allow_cross_chain_bridge: bool = true
@export var cross_chain_bridge_radius: float = 170.0
@export var cross_chain_bridge_limit_per_point: int = 2

@onready var routes_parent: Node = get_node_or_null(routes_parent_path)
@onready var markers_parent: Node = get_node_or_null(markers_parent_path)
@onready var jump_points_parent: Node = get_node_or_null(jump_points_parent_path)
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var cursor: AnimatedSprite2D = get_node_or_null(cursor_path)

var can_move: bool = true

enum Mode { GROUND, JUMP }
enum AfterRoutePlanAction { NONE, START_JUMP_CHAIN, WALK_TO_OFFSET }

var mode: int = Mode.GROUND

var routes: Array[TraversalRoute] = []
var markers: Array[TraversalMarker] = []
var jump_points: Array[TraversalJumpPoint] = []

var active_route: TraversalRoute = null

var current_offset: float = 0.0
var target_offset: float = 0.0

var pending_marker: TraversalMarker = null
var pending_target_route: TraversalRoute = null
var pending_target_offset: float = 0.0

var is_jumping: bool = false
var jump_start: Vector2 = Vector2.ZERO
var jump_end: Vector2 = Vector2.ZERO
var jump_t: float = 0.0

var jump_chain_positions: Array[Vector2] = []
var jump_chain_active: bool = false
var jump_chain_attach_to_route: bool = false
var jump_chain_needs_ground_jump: bool = false

var _hover_is_valid: bool = false

var route_plan_markers: Array[TraversalMarker] = []
var route_plan_active: bool = false
var route_plan_goal_route: TraversalRoute = null
var after_route_plan_action: int = AfterRoutePlanAction.NONE
var after_route_plan_walk_offset: float = 0.0
var after_route_plan_jump_positions: Array[Vector2] = []

var post_jump_route_target: TraversalRoute = null
var post_jump_route_offset: float = 0.0

var current_jump_point: TraversalJumpPoint = null


func _ready() -> void:
	_load_routes()
	_load_markers()
	_load_jump_points()

	var entering_from_transition := GameProgress.next_spawn_marker != ""

	if not entering_from_transition:
		_set_start_route()
		_snap_to_active_route(global_position)
	else:
		active_route = null
		current_offset = 0.0
		target_offset = 0.0
		current_jump_point = null

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	if sprite.animation != "idle":
		sprite.play("idle")

	if cursor != null:
		cursor.visible = false
	if cursor_default != null:
		cursor_default.visible = false
	if cursor_interact != null:
		cursor_interact.visible = false

	if not entering_from_transition:
		_apply_idle_tangent_tilt()

	_update_hover_cursor()


func _process(_delta: float) -> void:
	var screen_pos: Vector2 = get_viewport().get_mouse_position()

	if cursor != null:
		cursor.position = screen_pos
	if cursor_default != null:
		cursor_default.position = screen_pos
	if cursor_interact != null:
		cursor_interact.position = screen_pos

	_update_hover_cursor()

func _input(event: InputEvent) -> void:
	if not can_move:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return

		if mode == Mode.JUMP:
			return

		var click_pos: Vector2 = get_global_mouse_position()

		if _is_hovering_ui():
			return

		if _is_hovering_clickable_asset(click_pos):
			return

		if _try_click_jump_points(click_pos):
			return

		if _try_click_best_route(click_pos):
			return

		if _try_click_marker(click_pos):
			return


func _physics_process(delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		move_and_slide()

		if mode == Mode.GROUND:
			if sprite.animation != "idle":
				sprite.play("idle")
			_apply_idle_tangent_tilt()
		elif mode == Mode.JUMP:
			if sprite.animation != "idle":
				sprite.play("idle")
			sprite.rotation = lerp_angle(sprite.rotation, 0.0, 0.2)

		return

	if mode == Mode.GROUND:
		_update_ground(delta)
	else:
		_update_jump(delta)


func _load_routes() -> void:
	routes.clear()
	if routes_parent == null:
		return
	for child: Node in routes_parent.get_children():
		if child is TraversalRoute:
			routes.append(child as TraversalRoute)


func _load_markers() -> void:
	markers.clear()
	if markers_parent == null:
		return
	for child: Node in markers_parent.get_children():
		if child is TraversalMarker:
			markers.append(child as TraversalMarker)


func _load_jump_points() -> void:
	jump_points.clear()
	if jump_points_parent == null:
		return
	for child: Node in jump_points_parent.get_children():
		if child is TraversalJumpPoint:
			jump_points.append(child as TraversalJumpPoint)

	jump_points.sort_custom(func(a: TraversalJumpPoint, b: TraversalJumpPoint) -> bool:
		if a == null or b == null:
			return false
		var a_key: String = _get_jump_point_sort_key(a)
		var b_key: String = _get_jump_point_sort_key(b)
		if a_key == b_key:
			if a.order == b.order:
				return a.name < b.name
			return a.order < b.order
		return a_key < b_key
	)


func _get_jump_point_sort_key(point: TraversalJumpPoint) -> String:
	if point == null or point.chain_ids.is_empty():
		return ""
	var ids: Array[String] = point.chain_ids.duplicate()
	ids.sort()
	return ids[0]


func _set_start_route() -> void:
	if start_route_path != NodePath():
		var node: Node = get_node_or_null(start_route_path)
		if node is TraversalRoute:
			active_route = node as TraversalRoute
			return
	active_route = _get_closest_route(global_position)


func _get_closest_route(pos: Vector2) -> TraversalRoute:
	var best_route: TraversalRoute = null
	var best_dist: float = INF
	for route: TraversalRoute in routes:
		if route == null or not route.has_ground_path():
			continue
		var route_offset: float = route.get_closest_offset_to_global(pos)
		var route_point: Vector2 = route.get_global_point_at_offset(route_offset)
		var d: float = route_point.distance_to(pos)
		if d < best_dist:
			best_dist = d
			best_route = route
	return best_route


func _snap_to_active_route(pos: Vector2) -> void:
	if active_route == null or not active_route.has_ground_path():
		return
	current_offset = active_route.get_closest_offset_to_global(pos)
	target_offset = current_offset
	global_position = active_route.get_global_point_at_offset(current_offset)
	current_jump_point = null


func _is_near_route(route: TraversalRoute, click_pos: Vector2, radius: float) -> bool:
	if route == null or not route.has_ground_path():
		return false
	var off: float = route.get_closest_offset_to_global(click_pos)
	var point: Vector2 = route.get_global_point_at_offset(off)
	return point.distance_to(click_pos) <= radius


func _clear_all_pending() -> void:
	pending_marker = null
	pending_target_route = null
	pending_target_offset = 0.0
	jump_chain_positions.clear()
	jump_chain_active = false
	jump_chain_attach_to_route = false
	jump_chain_needs_ground_jump = false
	route_plan_markers.clear()
	route_plan_active = false
	route_plan_goal_route = null
	after_route_plan_action = AfterRoutePlanAction.NONE
	after_route_plan_walk_offset = 0.0
	after_route_plan_jump_positions.clear()
	post_jump_route_target = null
	post_jump_route_offset = 0.0


func _try_click_best_route(click_pos: Vector2) -> bool:
	var route: TraversalRoute = _get_best_reachable_route(click_pos)
	if route == null:
		return false

	if active_route == null or not active_route.has_ground_path():
		var clicked_offset: float = route.get_closest_offset_to_global(click_pos)
		if _try_return_to_route_via_jump_chain(route, clicked_offset):
			return true

	var landing_offset: float = route.get_closest_offset_to_global(click_pos)

	if active_route == null:
		active_route = route
		current_offset = landing_offset
		target_offset = landing_offset
		global_position = active_route.get_global_point_at_offset(current_offset)
		current_jump_point = null
		_apply_idle_tangent_tilt()
		return true

	_clear_all_pending()

	if active_route == route:
		target_offset = landing_offset
		return true

	return _start_route_plan(route, AfterRoutePlanAction.WALK_TO_OFFSET, landing_offset, [])


func _get_best_reachable_route(click_pos: Vector2) -> TraversalRoute:
	var best_route: TraversalRoute = null
	var best_dist: float = INF

	for route: TraversalRoute in routes:
		if route == null or not route.has_ground_path():
			continue
		if active_route != null and route != active_route:
			if not _routes_are_connected_any_path(active_route, route):
				continue
		var radius: float = route_click_radius if route == active_route else connected_route_click_radius
		var off: float = route.get_closest_offset_to_global(click_pos)
		var point: Vector2 = route.get_global_point_at_offset(off)
		var d: float = point.distance_to(click_pos)
		if d <= radius and d < best_dist:
			best_dist = d
			best_route = route

	return best_route


func _start_route_plan(
	target_route: TraversalRoute,
	action_after: int,
	final_walk_offset: float,
	jump_positions_after: Array[Vector2]
) -> bool:
	if active_route == null or target_route == null:
		return false

	route_plan_goal_route = target_route
	after_route_plan_action = action_after
	after_route_plan_walk_offset = final_walk_offset
	after_route_plan_jump_positions = jump_positions_after.duplicate()

	if active_route == target_route:
		_finalize_route_plan()
		return true

	route_plan_markers = _build_route_marker_path(active_route, target_route)
	if route_plan_markers.size() == 0:
		return false

	route_plan_active = true
	_begin_next_route_plan_step()
	return true


func _try_click_marker(click_pos: Vector2) -> bool:
	var marker: TraversalMarker = _get_clicked_marker(click_pos)
	if marker == null:
		return false

	var other_route: TraversalRoute = marker.get_other_route(active_route)
	if other_route == null or not other_route.has_ground_path():
		return false

	_clear_all_pending()
	pending_marker = marker
	pending_target_route = other_route
	pending_target_offset = other_route.get_closest_offset_to_global(marker.global_position)
	target_offset = active_route.get_closest_offset_to_global(marker.global_position)
	return true


func _get_clicked_marker(click_pos: Vector2) -> TraversalMarker:
	if active_route == null:
		return null

	var best_marker: TraversalMarker = null
	var best_dist: float = INF

	for marker: TraversalMarker in markers:
		if marker == null:
			continue
		if not marker.has_route(active_route):
			continue
		var other_route: TraversalRoute = marker.get_other_route(active_route)
		if other_route == null:
			continue
		var d: float = marker.global_position.distance_to(click_pos)
		if d <= marker_click_radius and d < best_dist:
			best_dist = d
			best_marker = marker

	return best_marker


func _routes_are_connected_any_path(route_a: TraversalRoute, route_b: TraversalRoute) -> bool:
	return _build_route_marker_path(route_a, route_b).size() > 0


func _build_route_marker_path(from_route: TraversalRoute, to_route: TraversalRoute) -> Array[TraversalMarker]:
	var result: Array[TraversalMarker] = []

	if from_route == null or to_route == null or from_route == to_route:
		return result

	var queue: Array[TraversalRoute] = [from_route]
	var visited: Dictionary = {}
	var prev_route: Dictionary = {}
	var prev_marker: Dictionary = {}

	visited[from_route] = true

	while queue.size() > 0:
		var route: TraversalRoute = queue.pop_front()
		if route == to_route:
			break

		var candidates: Array = []
		for marker: TraversalMarker in markers:
			if marker == null or not marker.has_route(route):
				continue
			var next_route: TraversalRoute = marker.get_other_route(route)
			if next_route == null or visited.has(next_route):
				continue
			candidates.append({ "marker": marker, "route": next_route })

		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var da: float = (a["marker"] as TraversalMarker).global_position.distance_to(global_position)
			var db: float = (b["marker"] as TraversalMarker).global_position.distance_to(global_position)
			return da < db
		)

		for entry: Dictionary in candidates:
			var next_route: TraversalRoute = entry["route"] as TraversalRoute
			var marker: TraversalMarker = entry["marker"] as TraversalMarker
			if visited.has(next_route):
				continue
			visited[next_route] = true
			prev_route[next_route] = route
			prev_marker[next_route] = marker
			queue.append(next_route)

	if not visited.has(to_route):
		return result

	var cur: TraversalRoute = to_route
	while cur != from_route:
		var m: TraversalMarker = prev_marker[cur] as TraversalMarker
		result.push_front(m)
		cur = prev_route[cur] as TraversalRoute

	return result


func _begin_next_route_plan_step() -> void:
	if not route_plan_active:
		return
	if route_plan_markers.is_empty():
		_finalize_route_plan()
		return

	var marker: TraversalMarker = route_plan_markers.pop_front()
	var next_route: TraversalRoute = marker.get_other_route(active_route)
	if next_route == null:
		route_plan_active = false
		return

	pending_marker = marker
	pending_target_route = next_route
	pending_target_offset = next_route.get_closest_offset_to_global(marker.global_position)
	target_offset = active_route.get_closest_offset_to_global(marker.global_position)


func _finalize_route_plan() -> void:
	route_plan_active = false

	match after_route_plan_action:
		AfterRoutePlanAction.WALK_TO_OFFSET:
			target_offset = after_route_plan_walk_offset

		AfterRoutePlanAction.START_JUMP_CHAIN:
			if after_route_plan_jump_positions.is_empty():
				return
			jump_chain_positions = after_route_plan_jump_positions.duplicate()
			jump_chain_active = true
			jump_chain_attach_to_route = false
			target_offset = active_route.get_closest_offset_to_global(jump_chain_positions[0])

		AfterRoutePlanAction.NONE:
			pass

	after_route_plan_action = AfterRoutePlanAction.NONE
	after_route_plan_walk_offset = 0.0
	after_route_plan_jump_positions.clear()


func _update_ground(delta: float) -> void:
	if active_route == null or not active_route.has_ground_path():
		if sprite.animation != "idle":
			sprite.play("idle")
		return

	var diff: float = target_offset - current_offset

	if absf(diff) < 2.0:
		current_offset = target_offset
		global_position = active_route.get_global_point_at_offset(current_offset)

		if pending_marker != null:
			_execute_marker_transfer()
			return

		if jump_chain_active and jump_chain_positions.size() > 0:
			_start_jump_to_position(jump_chain_positions.pop_front())
			return

		if sprite.animation != "idle":
			sprite.play("idle")
		_apply_idle_tangent_tilt()
		return

	var dir_sign: float = signf(diff)
	current_offset += dir_sign * speed * delta
	current_offset = clampf(current_offset, 0.0, active_route.ground_path.curve.get_baked_length())
	global_position = active_route.get_global_point_at_offset(current_offset)

	if sprite.animation != "run":
		sprite.play("run")
	_update_ground_facing_and_tilt(dir_sign)


func _execute_marker_transfer() -> void:
	if pending_marker == null or pending_target_route == null:
		pending_marker = null
		pending_target_route = null
		return

	match pending_marker.marker_type:
		TraversalMarker.MarkerType.SEAM:
			_do_seam_transfer()
		TraversalMarker.MarkerType.JUMP:
			_start_jump_transfer()


func _do_seam_transfer() -> void:
	active_route = pending_target_route
	current_offset = pending_target_offset
	target_offset = pending_target_offset
	global_position = active_route.get_global_point_at_offset(current_offset)
	current_jump_point = null
	pending_marker = null
	pending_target_route = null

	if route_plan_active:
		_begin_next_route_plan_step()
		return

	if sprite.animation != "run":
		sprite.play("run")


func _start_jump_transfer() -> void:
	jump_chain_positions.clear()
	jump_chain_active = false
	jump_chain_attach_to_route = false
	jump_chain_needs_ground_jump = false
	_start_jump_to_position(pending_target_route.get_global_point_at_offset(pending_target_offset))


func _start_jump_to_position(dest: Vector2) -> void:
	mode = Mode.JUMP
	is_jumping = true
	jump_t = 0.0
	jump_start = global_position
	jump_end = dest

	var dx: float = jump_end.x - jump_start.x
	if dx > 0.0:
		sprite.flip_h = true
	elif dx < 0.0:
		sprite.flip_h = false

	if has_node("jumpSound"):
		$jumpSound.stop()
		$jumpSound.play()

	if sprite.animation != "jump":
		sprite.play("jump")

	sprite.rotation = lerp_angle(sprite.rotation, 0.0, 0.25)


func _update_jump(delta: float) -> void:
	if not is_jumping:
		return

	jump_t += delta / jump_duration

	if jump_t >= 1.0:
		jump_t = 1.0
		is_jumping = false
		global_position = jump_end
		_block_scene_exits_for(scene_exit_block_after_jump)

		var landed_point: TraversalJumpPoint = _get_jump_point_at_world_position(global_position, jump_point_arrive_threshold)
		if landed_point != null:
			current_jump_point = landed_point

		if jump_chain_active:
			if jump_chain_positions.size() > 0:
				_start_jump_to_position(jump_chain_positions.pop_front())
				return
			else:
				jump_chain_active = false

				if jump_chain_needs_ground_jump and pending_target_route != null:
					jump_chain_needs_ground_jump = false
					jump_chain_attach_to_route = true
					_start_jump_to_position(pending_target_route.get_global_point_at_offset(pending_target_offset))
					return

				if jump_chain_attach_to_route and pending_target_route != null:
					_land_on_route()
					return

				_finish_jump_chain()
				return

		if jump_chain_attach_to_route and pending_target_route != null:
			_land_on_route()
			return

		if pending_target_route != null:
			active_route = pending_target_route
			current_offset = pending_target_offset
			target_offset = pending_target_offset
			global_position = active_route.get_global_point_at_offset(current_offset)
			current_jump_point = null

		mode = Mode.GROUND
		pending_marker = null
		pending_target_route = null
		jump_chain_attach_to_route = false
		jump_chain_needs_ground_jump = false

		if route_plan_active:
			_begin_next_route_plan_step()
			return

		if active_route != null and absf(target_offset - current_offset) < 2.0:
			_snap_to_active_route(global_position)
			if sprite.animation != "idle":
				sprite.play("idle")
			_apply_idle_tangent_tilt()
		else:
			if sprite.animation != "run":
				sprite.play("run")
		return

	var pos: Vector2 = jump_start.lerp(jump_end, jump_t)
	pos.y -= sin(jump_t * PI) * jump_height
	global_position = pos

	if sprite.animation != "jump":
		sprite.play("jump")

	var dx2: float = jump_end.x - jump_start.x
	if dx2 > 0.0:
		sprite.flip_h = true
	elif dx2 < 0.0:
		sprite.flip_h = false

	sprite.rotation = lerp_angle(sprite.rotation, 0.0, 0.25)


func _land_on_route() -> void:
	active_route = pending_target_route
	current_offset = pending_target_offset
	target_offset = pending_target_offset
	global_position = active_route.get_global_point_at_offset(current_offset)
	current_jump_point = null

	mode = Mode.GROUND
	jump_chain_attach_to_route = false
	jump_chain_needs_ground_jump = false
	pending_marker = null
	pending_target_route = null

	if post_jump_route_target != null:
		var target_route_ref: TraversalRoute = post_jump_route_target
		var target_offset_ref: float = post_jump_route_offset
		post_jump_route_target = null
		post_jump_route_offset = 0.0

		if active_route == target_route_ref:
			target_offset = target_offset_ref
		else:
			_start_route_plan(target_route_ref, AfterRoutePlanAction.WALK_TO_OFFSET, target_offset_ref, [])
		return

	if sprite.animation != "idle":
		sprite.play("idle")
	_apply_idle_tangent_tilt()


func _finish_jump_chain() -> void:
	mode = Mode.GROUND
	pending_marker = null
	pending_target_route = null
	jump_chain_active = false
	jump_chain_attach_to_route = false
	jump_chain_needs_ground_jump = false
	active_route = null
	current_offset = 0.0
	target_offset = 0.0
	current_jump_point = _get_jump_point_at_world_position(global_position, jump_point_arrive_threshold)

	if sprite.animation != "idle":
		sprite.play("idle")
	sprite.rotation = lerp_angle(sprite.rotation, 0.0, 0.2)


func _update_ground_facing_and_tilt(dir_sign: float) -> void:
	if active_route == null or not active_route.has_ground_path():
		return

	var curve: Curve2D = active_route.ground_path.curve
	var max_off: float = curve.get_baked_length()

	var a_off: float = current_offset
	var b_off: float = clampf(current_offset + dir_sign * tangent_sample, 0.0, max_off)

	if absf(b_off - a_off) < 0.001:
		b_off = clampf(current_offset - dir_sign * tangent_sample, 0.0, max_off)

	var a_global: Vector2 = active_route.ground_path.to_global(curve.sample_baked(a_off))
	var b_global: Vector2 = active_route.ground_path.to_global(curve.sample_baked(b_off))
	var tangent: Vector2 = b_global - a_global

	if tangent.length() < 0.001:
		return

	var dir: Vector2 = tangent.normalized()

	if dir.x > 0.0:
		sprite.flip_h = true
	elif dir.x < 0.0:
		sprite.flip_h = false

	var slope_tilt: float = atan2(dir.y, absf(dir.x))
	var target_tilt: float = slope_tilt if dir.x >= 0.0 else -slope_tilt
	target_tilt = clampf(target_tilt * 0.45, deg_to_rad(-16.0), deg_to_rad(16.0))
	sprite.rotation = lerp_angle(sprite.rotation, target_tilt, 0.2)


func _apply_idle_tangent_tilt() -> void:
	if active_route == null or not active_route.has_ground_path():
		return

	var curve: Curve2D = active_route.ground_path.curve
	var max_off: float = curve.get_baked_length()

	var a_off: float = clampf(current_offset - tangent_sample, 0.0, max_off)
	var b_off: float = clampf(current_offset + tangent_sample, 0.0, max_off)

	if absf(b_off - a_off) < 0.001:
		return

	var a_global: Vector2 = active_route.ground_path.to_global(curve.sample_baked(a_off))
	var b_global: Vector2 = active_route.ground_path.to_global(curve.sample_baked(b_off))
	var tangent: Vector2 = b_global - a_global

	if tangent.length() < 0.001:
		return

	var dir: Vector2 = tangent.normalized()

	if dir.x > 0.0:
		sprite.flip_h = true
	elif dir.x < 0.0:
		sprite.flip_h = false

	var slope_tilt: float = atan2(dir.y, absf(dir.x))
	var target_tilt: float = slope_tilt if dir.x >= 0.0 else -slope_tilt
	target_tilt = clampf(target_tilt * 0.45, deg_to_rad(-16.0), deg_to_rad(16.0))
	sprite.rotation = lerp_angle(sprite.rotation, target_tilt, 0.2)


func _is_hovering_ui() -> bool:
	for node in get_tree().get_nodes_in_group("ui_hoverable"):
		if node.has_method("is_mouse_hovering") and node.is_mouse_hovering():
			return true
	return false
 # Cursor stuff

func _update_hover_cursor() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()

	# Hide everything first
	if cursor != null:
		cursor.visible = false
	if cursor_default != null:
		cursor_default.visible = false
	if cursor_interact != null:
		cursor_interact.visible = false

	if _is_hovering_ui() or _is_hovering_clickable_asset(mouse_pos):
		if cursor_interact != null:
			cursor_interact.visible = true
			if not cursor_interact.is_playing():
				cursor_interact.play("default")
		return

	if _is_hover_valid(mouse_pos):
		if cursor != null:
			cursor.visible = true
			if not cursor.is_playing():
				cursor.play("hover_path")
		return

	if cursor_default != null:
		cursor_default.visible = true
		if not cursor_default.is_playing():
			cursor_default.play("default")

func _is_hover_valid(mouse_pos: Vector2) -> bool:
	if mode == Mode.JUMP:
		return false
	if _get_clicked_jump_point(mouse_pos) != null:
		return true
	if _get_best_reachable_route(mouse_pos) != null:
		return true
	if _get_clicked_marker(mouse_pos) != null:
		return true
	return false

func _is_hovering_clickable_asset(mouse_pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	query.collide_with_areas = true
	query.collide_with_bodies = true

	for hit in space_state.intersect_point(query):
		var collider = hit.collider
		if collider == null:
			continue
		if collider.is_in_group("clickable_asset"):
			return true
		var parent: Node = collider.get_parent()
		if parent != null and parent.is_in_group("clickable_asset"):
			return true

	return false


func _get_clicked_jump_point(click_pos: Vector2) -> TraversalJumpPoint:
	if jump_points.is_empty():
		return null

	var best_point: TraversalJumpPoint = null
	var best_dist: float = INF

	for p: TraversalJumpPoint in jump_points:
		if p == null:
			continue
		var d: float = p.global_position.distance_to(click_pos)
		if d <= p.click_radius and d < best_dist:
			best_dist = d
			best_point = p

	return best_point


func _get_nearest_jump_point_to_pos(pos: Vector2, max_dist: float = INF) -> TraversalJumpPoint:
	if jump_points.is_empty():
		return null

	var best_point: TraversalJumpPoint = null
	var best_dist: float = INF

	for p: TraversalJumpPoint in jump_points:
		if p == null:
			continue
		var d: float = p.global_position.distance_to(pos)
		if d <= max_dist and d < best_dist:
			best_dist = d
			best_point = p

	return best_point


func _get_jump_point_at_world_position(pos: Vector2, threshold: float = 10.0) -> TraversalJumpPoint:
	var best_point: TraversalJumpPoint = null
	var best_dist: float = threshold

	for p: TraversalJumpPoint in jump_points:
		if p == null:
			continue
		var d: float = p.global_position.distance_to(pos)
		if d <= best_dist:
			best_dist = d
			best_point = p

	return best_point


func _get_chain_key_for_point(point: TraversalJumpPoint) -> String:
	if point == null or point.chain_ids.is_empty():
		return ""
	var ids: Array[String] = point.chain_ids.duplicate()
	ids.sort()
	return ids[0]


func _add_unique_neighbor(list: Array[TraversalJumpPoint], point: TraversalJumpPoint) -> void:
	if point == null or point in list:
		return
	list.append(point)


func _get_same_chain_neighbors(point: TraversalJumpPoint) -> Array[TraversalJumpPoint]:
	var result: Array[TraversalJumpPoint] = []
	if point == null:
		return result
	for chain_id: String in point.chain_ids:
		_add_unique_neighbor(result, point.get_prev_point_on_chain(chain_id))
		_add_unique_neighbor(result, point.get_next_point_on_chain(chain_id))
	return result


func _get_bridge_neighbors(point: TraversalJumpPoint) -> Array[TraversalJumpPoint]:
	var result: Array[TraversalJumpPoint] = []
	if point == null or not allow_cross_chain_bridge:
		return result

	var own_chain_ids: Dictionary = {}
	for id: String in point.chain_ids:
		own_chain_ids[id] = true

	var candidates: Array[Dictionary] = []
	for other: TraversalJumpPoint in jump_points:
		if other == null or other == point:
			continue
		var shares_chain := false
		for id: String in other.chain_ids:
			if own_chain_ids.has(id):
				shares_chain = true
				break
		if shares_chain:
			continue
		var d: float = point.global_position.distance_to(other.global_position)
		if d > cross_chain_bridge_radius:
			continue
		candidates.append({ "point": other, "dist": d, "chain_key": _get_chain_key_for_point(other) })

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["dist"]) < float(b["dist"])
	)

	var used_chain_keys: Dictionary = {}
	for entry: Dictionary in candidates:
		var other_point: TraversalJumpPoint = entry["point"] as TraversalJumpPoint
		var chain_key: String = entry["chain_key"] as String
		if chain_key != "" and used_chain_keys.has(chain_key):
			continue
		_add_unique_neighbor(result, other_point)
		if chain_key != "":
			used_chain_keys[chain_key] = true
		if result.size() >= cross_chain_bridge_limit_per_point:
			break

	return result


func _get_graph_neighbors(point: TraversalJumpPoint) -> Array[TraversalJumpPoint]:
	var result: Array[TraversalJumpPoint] = []
	for p in _get_same_chain_neighbors(point):
		_add_unique_neighbor(result, p)
	for p in _get_bridge_neighbors(point):
		_add_unique_neighbor(result, p)
	return result


func _reconstruct_jump_graph_path(
	came_from: Dictionary,
	start_point: TraversalJumpPoint,
	target_point: TraversalJumpPoint
) -> Array[TraversalJumpPoint]:
	var result: Array[TraversalJumpPoint] = []
	if start_point == null or target_point == null:
		return result

	var cur: TraversalJumpPoint = target_point
	var guard: int = 0
	while cur != null and guard < 512:
		result.push_front(cur)
		if cur == start_point:
			return result
		if not came_from.has(cur):
			return []
		cur = came_from[cur] as TraversalJumpPoint
		guard += 1

	return []


func _find_jump_graph_path(
	start_point: TraversalJumpPoint,
	target_point: TraversalJumpPoint
) -> Array[TraversalJumpPoint]:
	if start_point == null or target_point == null:
		return []
	if start_point == target_point:
		return [start_point]

	var frontier: Array[TraversalJumpPoint] = [start_point]
	var visited: Dictionary = {}
	var came_from: Dictionary = {}
	visited[start_point] = true

	while frontier.size() > 0:
		var cur: TraversalJumpPoint = frontier.pop_front()
		if cur == target_point:
			return _reconstruct_jump_graph_path(came_from, start_point, target_point)

		var neighbors: Array[TraversalJumpPoint] = _get_graph_neighbors(cur)
		neighbors.sort_custom(func(a: TraversalJumpPoint, b: TraversalJumpPoint) -> bool:
			return a.global_position.distance_to(target_point.global_position) < b.global_position.distance_to(target_point.global_position)
		)

		for next_point: TraversalJumpPoint in neighbors:
			if next_point == null or visited.has(next_point):
				continue
			visited[next_point] = true
			came_from[next_point] = cur
			frontier.append(next_point)

	return []


func _get_chain_entry_point(point: TraversalJumpPoint) -> TraversalJumpPoint:
	if point == null:
		return null
	var cur: TraversalJumpPoint = point
	var guard: int = 0
	while cur.get_prev_point() != null and guard < 256:
		cur = cur.get_prev_point()
		guard += 1
	return cur


func _get_jump_chain_entry_route(entry_point: TraversalJumpPoint) -> TraversalRoute:
	if entry_point == null:
		return null
	if entry_point.entry_from_route != null:
		return entry_point.entry_from_route
	return _get_closest_route(entry_point.global_position)


func _build_jump_chain(start_point: TraversalJumpPoint, target_point: TraversalJumpPoint) -> Array[TraversalJumpPoint]:
	var result: Array[TraversalJumpPoint] = []
	if start_point == null or target_point == null:
		return result

	var shared_ids: Array[String] = start_point.get_shared_chain_ids(target_point)
	if shared_ids.is_empty():
		return result

	var chosen_chain: String = ""
	for id in target_point.chain_ids:
		if id in shared_ids:
			chosen_chain = id
			break
	if chosen_chain == "":
		chosen_chain = shared_ids[0]

	if start_point == target_point:
		return [target_point]

	if start_point.order < target_point.order:
		var cur: TraversalJumpPoint = start_point
		var guard: int = 0
		while cur != null and guard < 256:
			result.append(cur)
			if cur == target_point:
				return result
			cur = cur.get_next_point_on_chain(chosen_chain)
			guard += 1
		return []

	var cur: TraversalJumpPoint = start_point
	var guard: int = 0
	while cur != null and guard < 256:
		result.append(cur)
		if cur == target_point:
			return result
		cur = cur.get_prev_point_on_chain(chosen_chain)
		guard += 1

	return []


func _try_click_jump_points(click_pos: Vector2) -> bool:
	if jump_points.is_empty():
		return false

	var target_point: TraversalJumpPoint = _get_clicked_jump_point(click_pos)
	if target_point == null:
		return false

	var chain_entry: TraversalJumpPoint = _get_chain_entry_point(target_point)
	if chain_entry == null:
		return false

	var entry_route: TraversalRoute = _get_jump_chain_entry_route(chain_entry)
	if entry_route == null:
		return false

	if active_route != null and active_route.has_ground_path():
		var chain: Array[TraversalJumpPoint] = _build_jump_chain(chain_entry, target_point)
		if chain.is_empty():
			return false

		var jump_positions: Array[Vector2] = []
		for p: TraversalJumpPoint in chain:
			if p != null:
				jump_positions.append(p.global_position)

		_clear_all_pending()

		if target_point == chain_entry and active_route == entry_route:
			return _jump_between_route_and_entry_point(chain_entry, entry_route, false)

		if active_route == entry_route:
			jump_chain_positions = jump_positions.duplicate()
			jump_chain_active = true
			jump_chain_attach_to_route = false
			target_offset = active_route.get_closest_offset_to_global(jump_chain_positions[0])
			return true

		return _start_route_plan(entry_route, AfterRoutePlanAction.START_JUMP_CHAIN, 0.0, jump_positions)

	var start_point: TraversalJumpPoint = current_jump_point
	if start_point == null:
		start_point = _get_jump_point_at_world_position(global_position, jump_point_arrive_threshold)
	if start_point == null:
		start_point = _get_nearest_jump_point_to_pos(global_position, jump_point_entry_radius)
	if start_point == null:
		return false

	var graph_path: Array[TraversalJumpPoint] = _find_jump_graph_path(start_point, target_point)
	if graph_path.is_empty():
		return false

	_start_jump_chain_from_points(graph_path)
	return true


func _start_jump_chain_from_points(chain: Array[TraversalJumpPoint]) -> void:
	jump_chain_positions.clear()
	jump_chain_active = true
	jump_chain_attach_to_route = false
	jump_chain_needs_ground_jump = false
	pending_marker = null
	pending_target_route = null
	pending_target_offset = 0.0

	for i: int in range(chain.size()):
		var p: TraversalJumpPoint = chain[i]
		if p == null:
			continue
		if i == 0 and global_position.distance_to(p.global_position) <= jump_point_arrive_threshold:
			continue
		jump_chain_positions.append(p.global_position)

	if jump_chain_positions.is_empty():
		jump_chain_active = false
		return

	_start_jump_to_position(jump_chain_positions.pop_front())


func _try_world_position_jump_chain(world_pos: Vector2) -> bool:
	if jump_points.is_empty():
		return false
	var target_point: TraversalJumpPoint = _get_nearest_jump_point_to_pos(world_pos, jump_point_target_radius)
	if target_point == null:
		return false
	return _try_click_jump_points(target_point.global_position)


func walk_to_position(world_pos: Vector2) -> void:
	if mode == Mode.JUMP:
		return
	if _is_hovering_clickable_asset(world_pos):
		return
	if _try_world_position_jump_chain(world_pos):
		return

	if active_route == null or not active_route.has_ground_path():
		active_route = _get_closest_route(world_pos)
		if active_route == null or not active_route.has_ground_path():
			return
		current_offset = active_route.get_closest_offset_to_global(global_position)
		target_offset = current_offset
		current_jump_point = null

	var best_route: TraversalRoute = _get_best_reachable_route(world_pos)
	if best_route != null and best_route != active_route:
		_clear_all_pending()
		_start_route_plan(best_route, AfterRoutePlanAction.WALK_TO_OFFSET, best_route.get_closest_offset_to_global(world_pos), [])
		return

	_clear_all_pending()
	target_offset = active_route.get_closest_offset_to_global(world_pos)


func is_at_world_position(world_pos: Vector2, threshold: float = 20.0) -> bool:
	return global_position.distance_to(world_pos) <= threshold


func debug_hotspot_status(world_pos: Vector2, threshold: float = 20.0) -> void:
	print("[PLAYER HOTSPOT DEBUG] player=", global_position, " target=", world_pos,
		" dist=", global_position.distance_to(world_pos), " threshold=", threshold)


func _try_return_to_route_via_jump_chain(clicked_route: TraversalRoute, clicked_offset: float) -> bool:
	if clicked_route == null:
		return false
	if active_route != null and active_route.has_ground_path():
		return false

	var current_point: TraversalJumpPoint = current_jump_point
	if current_point == null:
		current_point = _get_jump_point_at_world_position(global_position, jump_point_arrive_threshold)
	if current_point == null:
		current_point = _get_nearest_jump_point_to_pos(global_position, jump_point_entry_radius)
	if current_point == null:
		return false

	var first_point: TraversalJumpPoint = current_point.get_first_point_in_chain()
	var last_point: TraversalJumpPoint = current_point.get_last_point_in_chain()

	if first_point != null and first_point.entry_from_route == clicked_route:
		if current_point == first_point:
			var ok: bool = _jump_between_route_and_entry_point(first_point, clicked_route, true)
			if not ok:
				return false
			post_jump_route_target = clicked_route
			post_jump_route_offset = clicked_offset
			return true

		var back_chain: Array[TraversalJumpPoint] = _build_jump_chain(current_point, first_point)
		if back_chain.is_empty():
			return false
		_start_jump_chain_from_points(back_chain)
		pending_target_route = clicked_route
		pending_target_offset = clicked_route.get_closest_offset_to_global(first_point.global_position)
		jump_chain_needs_ground_jump = true
		post_jump_route_target = clicked_route
		post_jump_route_offset = clicked_offset
		return true

	if last_point != null and last_point.exit_to_route == clicked_route:
		var fwd_chain: Array[TraversalJumpPoint] = _build_jump_chain(current_point, last_point)
		if fwd_chain.is_empty():
			return false
		_start_jump_chain_from_points(fwd_chain)
		pending_target_route = clicked_route
		pending_target_offset = clicked_route.get_closest_offset_to_global(last_point.global_position)
		jump_chain_needs_ground_jump = true
		post_jump_route_target = clicked_route
		post_jump_route_offset = clicked_offset
		return true

	return false


func _jump_between_route_and_entry_point(entry_point: TraversalJumpPoint, entry_route: TraversalRoute, to_route: bool) -> bool:
	if entry_point == null or entry_route == null:
		return false

	var route_offset: float = entry_route.get_closest_offset_to_global(entry_point.global_position)
	var route_point: Vector2 = entry_route.get_global_point_at_offset(route_offset)
	_clear_all_pending()

	if to_route:
		jump_chain_active = false
		jump_chain_attach_to_route = true
		jump_chain_needs_ground_jump = false
		pending_target_route = entry_route
		pending_target_offset = route_offset
		_start_jump_to_position(route_point)
		return true

	jump_chain_active = true
	jump_chain_attach_to_route = false
	jump_chain_needs_ground_jump = false
	jump_chain_positions.clear()
	jump_chain_positions.append(entry_point.global_position)
	target_offset = route_offset
	return true


func set_movement_enabled(enabled: bool) -> void:
	can_move = enabled
	if not enabled:
		velocity = Vector2.ZERO
		if active_route != null and active_route.has_ground_path():
			target_offset = current_offset
		if sprite != null:
			if sprite.animation != "idle":
				sprite.play("idle")
			sprite.rotation = lerp_angle(sprite.rotation, 0.0, 0.2)


func set_spawn_world_position(world_pos: Vector2) -> void:
	_clear_all_pending()
	can_move = false
	mode = Mode.GROUND
	is_jumping = false
	jump_t = 0.0
	jump_start = world_pos
	jump_end = world_pos
	jump_chain_active = false
	jump_chain_attach_to_route = false
	jump_chain_needs_ground_jump = false
	pending_marker = null
	pending_target_route = null
	pending_target_offset = 0.0
	post_jump_route_target = null
	post_jump_route_offset = 0.0
	current_jump_point = null
	velocity = Vector2.ZERO

	var spawn_route: TraversalRoute = _get_closest_route(world_pos)
	if spawn_route != null and spawn_route.has_ground_path():
		active_route = spawn_route
		var spawn_offset := active_route.get_closest_offset_to_global(world_pos)
		current_offset = spawn_offset
		target_offset = spawn_offset
		global_position = active_route.get_global_point_at_offset(spawn_offset)
	else:
		active_route = null
		current_offset = 0.0
		target_offset = 0.0
		global_position = world_pos

	if sprite != null:
		if sprite.animation != "idle":
			sprite.play("idle")
		sprite.rotation = 0.0
		if active_route != null and active_route.has_ground_path():
			_apply_idle_tangent_tilt()

	_block_scene_exits_for(scene_exit_block_after_spawn)
	can_move = true


func force_spawn_world_position(world_pos: Vector2) -> void:
	set_spawn_world_position(world_pos)


func spawn_off_route_exact(world_pos: Vector2) -> void:
	_clear_all_pending()
	can_move = false
	mode = Mode.GROUND
	is_jumping = false
	jump_t = 0.0
	jump_start = world_pos
	jump_end = world_pos
	jump_chain_active = false
	jump_chain_attach_to_route = false
	jump_chain_needs_ground_jump = false
	pending_marker = null
	pending_target_route = null
	pending_target_offset = 0.0
	post_jump_route_target = null
	post_jump_route_offset = 0.0
	active_route = null
	current_offset = 0.0
	target_offset = 0.0

	current_jump_point = _get_jump_point_at_world_position(world_pos, jump_point_arrive_threshold)
	if current_jump_point == null:
		current_jump_point = _get_nearest_jump_point_to_pos(world_pos, jump_point_entry_radius)

	global_position = world_pos
	velocity = Vector2.ZERO

	if sprite != null:
		if sprite.animation != "idle":
			sprite.play("idle")
		sprite.rotation = 0.0

	_block_scene_exits_for(scene_exit_block_after_spawn)
	can_move = true


func _block_scene_exits_for(seconds: float) -> void:
	var ms := int(seconds * 1000.0)
	_scene_exit_block_until_msec = max(_scene_exit_block_until_msec, Time.get_ticks_msec() + ms)


func _scene_exit_cooldown_active() -> bool:
	return Time.get_ticks_msec() < _scene_exit_block_until_msec


func is_scene_exit_blocked() -> bool:
	if not can_move:
		return true
	if _scene_exit_cooldown_active():
		return true
	if mode == Mode.JUMP:
		return true
	if is_jumping:
		return true
	if jump_chain_active:
		return true
	if jump_chain_attach_to_route:
		return true
	if jump_chain_needs_ground_jump:
		return true
	if pending_marker != null:
		return true
	if pending_target_route != null:
		return true
	if route_plan_active:
		return true
	return false


func on_scene_activated() -> void:
	routes_parent = get_node_or_null(routes_parent_path)
	markers_parent = get_node_or_null(markers_parent_path)
	jump_points_parent = get_node_or_null(jump_points_parent_path)
	sprite = get_node_or_null(^"AnimatedSprite2D") as AnimatedSprite2D
	cursor = get_node_or_null(cursor_path) as AnimatedSprite2D
	cursor_default = get_node_or_null(cursor_default_path) as AnimatedSprite2D
	cursor_interact = get_node_or_null(cursor_interact_path) as AnimatedSprite2D
	_load_routes()
	_load_markers()
	_load_jump_points()
	push_warning("[PLAYER] on_scene_activated: routes=%d markers=%d jumps=%d" % [
		routes.size(), markers.size(), jump_points.size()
	])
