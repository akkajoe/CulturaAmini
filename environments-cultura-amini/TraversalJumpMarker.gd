extends Marker2D
class_name TraversalJumpMarker

@export var next_marker_path: NodePath
@export var click_radius: float = 95.0


func get_next_marker() -> TraversalJumpMarker:
	var node := get_node_or_null(next_marker_path)
	if node is TraversalJumpMarker:
		return node
	return null


func get_route() -> TraversalRoute:
	var p: Node = get_parent()

	while p != null:
		if p is TraversalRoute:
			return p
		p = p.get_parent()

	return null
