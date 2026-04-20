extends Marker2D
class_name TraversalJumpPoint

@export var chain_ids: Array[String] = []
@export var order: int = 0
@export var click_radius: float = 42.0
@export var entry_from_route_path: NodePath
@export var exit_to_route_path: NodePath

var entry_from_route: TraversalRoute = null
var exit_to_route: TraversalRoute = null


func _ready() -> void:
	_resolve_routes()


func _resolve_routes() -> void:
	entry_from_route = null
	exit_to_route = null

	if entry_from_route_path != NodePath():
		var a: Node = get_node_or_null(entry_from_route_path)
		if a is TraversalRoute:
			entry_from_route = a as TraversalRoute

	if exit_to_route_path != NodePath():
		var b: Node = get_node_or_null(exit_to_route_path)
		if b is TraversalRoute:
			exit_to_route = b as TraversalRoute


func can_enter_from(route: TraversalRoute) -> bool:
	if entry_from_route == null:
		return true
	return route == entry_from_route


func can_exit_to(route: TraversalRoute) -> bool:
	if exit_to_route == null:
		return true
	return route == exit_to_route


func connects_to_route(route: TraversalRoute) -> bool:
	if route == null:
		return false
	return entry_from_route == route or exit_to_route == route


func is_entry_for_route(route: TraversalRoute) -> bool:
	if route == null:
		return false
	return entry_from_route == route


func is_exit_for_route(route: TraversalRoute) -> bool:
	if route == null:
		return false
	return exit_to_route == route


func is_click_near(world_pos: Vector2) -> bool:
	return global_position.distance_to(world_pos) <= click_radius


func get_order_value() -> int:
	return order


func has_chain(chain_id: String) -> bool:
	return chain_id in chain_ids


func shares_any_chain_with(other: TraversalJumpPoint) -> bool:
	if other == null:
		return false

	for id in chain_ids:
		if id in other.chain_ids:
			return true

	return false


func get_shared_chain_ids(other: TraversalJumpPoint) -> Array[String]:
	var result: Array[String] = []

	if other == null:
		return result

	for id in chain_ids:
		if id in other.chain_ids:
			result.append(id)

	return result


func get_next_point_on_chain(chain_id: String) -> TraversalJumpPoint:
	if get_parent() == null:
		return null
	if not has_chain(chain_id):
		return null

	var best: TraversalJumpPoint = null
	var best_order: int = 999999
	var my_order: int = get_order_value()

	for child: Node in get_parent().get_children():
		if child == self:
			continue
		if child is TraversalJumpPoint:
			var jp: TraversalJumpPoint = child as TraversalJumpPoint

			if not jp.has_chain(chain_id):
				continue

			var jp_order: int = jp.get_order_value()
			if jp_order > my_order and jp_order < best_order:
				best_order = jp_order
				best = jp

	return best


func get_prev_point_on_chain(chain_id: String) -> TraversalJumpPoint:
	if get_parent() == null:
		return null
	if not has_chain(chain_id):
		return null

	var best: TraversalJumpPoint = null
	var best_order: int = -999999
	var my_order: int = get_order_value()

	for child: Node in get_parent().get_children():
		if child == self:
			continue
		if child is TraversalJumpPoint:
			var jp: TraversalJumpPoint = child as TraversalJumpPoint

			if not jp.has_chain(chain_id):
				continue

			var jp_order: int = jp.get_order_value()
			if jp_order < my_order and jp_order > best_order:
				best_order = jp_order
				best = jp

	return best


func get_next_point() -> TraversalJumpPoint:
	if chain_ids.is_empty():
		return null
	return get_next_point_on_chain(chain_ids[0])


func get_prev_point() -> TraversalJumpPoint:
	if chain_ids.is_empty():
		return null
	return get_prev_point_on_chain(chain_ids[0])


func get_first_point_in_chain(chain_id: String = "") -> TraversalJumpPoint:
	var resolved_chain: String = chain_id
	if resolved_chain == "":
		if chain_ids.is_empty():
			return self
		resolved_chain = chain_ids[0]

	var cur: TraversalJumpPoint = self
	var guard: int = 0

	while cur != null and cur.get_prev_point_on_chain(resolved_chain) != null and guard < 256:
		cur = cur.get_prev_point_on_chain(resolved_chain)
		guard += 1

	return cur


func get_last_point_in_chain(chain_id: String = "") -> TraversalJumpPoint:
	var resolved_chain: String = chain_id
	if resolved_chain == "":
		if chain_ids.is_empty():
			return self
		resolved_chain = chain_ids[0]

	var cur: TraversalJumpPoint = self
	var guard: int = 0

	while cur != null and cur.get_next_point_on_chain(resolved_chain) != null and guard < 256:
		cur = cur.get_next_point_on_chain(resolved_chain)
		guard += 1

	return cur
