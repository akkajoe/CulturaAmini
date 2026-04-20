extends Area2D

@export var zoom_value: Vector2 = Vector2(1.4, 1.4)
@export var frame_offset: Vector2 = Vector2(0, 0)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "player":
		var cam = get_viewport().get_camera_2d()
		if cam and cam.has_method("set_camera_zoom"):
			cam.set_camera_zoom(zoom_value)
		if cam and cam.has_method("set_camera_frame_offset"):
			cam.set_camera_frame_offset(frame_offset)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "player":
		var cam = get_viewport().get_camera_2d()
		if cam and cam.has_method("reset_camera_zoom"):
			cam.reset_camera_zoom()
		if cam and cam.has_method("reset_camera_frame_offset"):
			cam.reset_camera_frame_offset()
