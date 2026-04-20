extends Area2D

@export var landing_marker: NodePath
@export var jump_duration: float = 0.6

@onready var landing_node: Node2D = get_node_or_null(landing_marker)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("start_jump_to") and landing_node:
		body.start_jump_to(landing_node.global_position, jump_duration)

func contains_global_point(p: Vector2) -> bool:
	var shape_owner_count := get_shape_owners().size()
	for owner_id in get_shape_owners():
		for i in range(shape_owner_get_shape_count(owner_id)):
			var shape: Shape2D = shape_owner_get_shape(owner_id, i)
			var xform: Transform2D = global_transform * shape_owner_get_transform(owner_id)
			if shape.collide(xform, CircleShape2D.new(), Transform2D(0.0, p)):
				return true
	return false

func get_landing_global() -> Vector2:
	if landing_node:
		return landing_node.global_position
	return global_position
