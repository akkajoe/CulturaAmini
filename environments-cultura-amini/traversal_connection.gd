extends Node2D
class_name TraversalConnection

enum ConnectionType { SEAM, JUMP }

@export var target_route_path: NodePath
@export var target_connection_path: NodePath
@export var connection_type: ConnectionType = ConnectionType.SEAM

var target_route: TraversalRoute = null
var target_connection: TraversalConnection = null


func _ready() -> void:
	var route_node := get_node_or_null(target_route_path)
	if route_node is TraversalRoute:
		target_route = route_node

	var connection_node := get_node_or_null(target_connection_path)
	if connection_node is TraversalConnection:
		target_connection = connection_node
