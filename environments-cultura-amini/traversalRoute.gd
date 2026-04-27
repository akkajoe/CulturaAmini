extends Node2D
class_name TraversalRoute

@export var ground_path_node: NodePath = ^"groundPath"
@export var enabled: bool = true

@onready var ground_path: Path2D = get_node_or_null(ground_path_node) as Path2D


func has_ground_path() -> bool:
	if not enabled:
		return false
	return ground_path != null and ground_path.curve != null


func get_closest_offset_to_global(global_pos: Vector2) -> float:
	if not has_ground_path():
		return 0.0
	var local_pos := ground_path.to_local(global_pos)
	return ground_path.curve.get_closest_offset(local_pos)


func get_global_point_at_offset(offset: float) -> Vector2:
	if not has_ground_path():
		return global_position
	var curve := ground_path.curve
	var safe_offset := clampf(offset, 0.0, curve.get_baked_length())
	var local_point := curve.sample_baked(safe_offset)
	return ground_path.to_global(local_point)
