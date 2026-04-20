extends Node2D
class_name TraversalMarker

enum MarkerType { SEAM, JUMP }

@export var route_a_path: NodePath
@export var route_b_path: NodePath
@export var marker_type: MarkerType = MarkerType.SEAM

@export var debug_enabled: bool = true

var route_a: TraversalRoute = null
var route_b: TraversalRoute = null


func _ready() -> void:
	var a := get_node_or_null(route_a_path)
	if a is TraversalRoute:
		route_a = a

	var b := get_node_or_null(route_b_path)
	if b is TraversalRoute:
		route_b = b

	if debug_enabled:
		print(
			"[MARKER DEBUG] ", name,
			" route_a_path=", route_a_path,
			" resolved_a=", route_a,
			" route_b_path=", route_b_path,
			" resolved_b=", route_b,
			" global_pos=", global_position
		)


func has_route(route: TraversalRoute) -> bool:
	return route == route_a or route == route_b


func get_other_route(current_route: TraversalRoute) -> TraversalRoute:
	if current_route == route_a:
		return route_b
	if current_route == route_b:
		return route_a
	return null
