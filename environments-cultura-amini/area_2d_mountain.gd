extends Area2D

@export var accepted_item_name: String = "mushroom"
@export var creature: AnimatedSprite2D
@export var player: Node2D
@export var open_mouth_animation: String = "openmouth"
@export var arc_height: float = 200.0
@export var throw_duration: float = 1.2
@export var symbol_scale: Vector2 = Vector2(0.15, 0.15)
@export var spin_speed: float = 180.0

var _already_fed: bool = false

func _ready() -> void:
	input_pickable = true
	monitoring = true
	monitorable = true
	push_warning("Area2D ready.")
	push_warning("creature: %s" % str(creature))
	push_warning("player: %s" % str(player))
	if GameProgress.should_restore_mountain_creature_openmouth():
		_already_fed = true
		_set_creature_fed_pose()

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or event.pressed:
		return
	push_warning("Mouse released - is_dragging: %s, already_fed: %s" % [
		str(DragManager.is_dragging),
		str(_already_fed)
	])
	if _already_fed:
		push_warning("Already fed, ignoring.")
		return
	if not DragManager.is_dragging:
		push_warning("Not dragging anything.")
		return
	push_warning("Dragging: %s" % DragManager.dragged_item_name)
	var mouse_world_pos := get_global_mouse_position()
	var params := PhysicsPointQueryParameters2D.new()
	params.position = mouse_world_pos
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = collision_mask
	var results := get_world_2d().direct_space_state.intersect_point(params)
	push_warning("Mouse world position: %s" % str(mouse_world_pos))
	push_warning("Physics results count: %d" % results.size())
	var hit := false
	for r in results:
		push_warning("Hit collider: %s" % str(r.collider))
		if r.collider == self:
			hit = true
			break
	if not hit:
		push_warning("Mouse not over this Area2D.")
		return
	push_warning("Hit this Area2D.")
	if DragManager.dragged_item_name != accepted_item_name:
		push_warning("Wrong item dropped: %s expected: %s" % [
			DragManager.dragged_item_name,
			accepted_item_name
		])
		return
	push_warning("Correct item! Starting throw.")
	var tex: Texture2D = DragManager.dragged_texture
	DragManager.accept_drop()
	GameProgress.remove_inventory_item(accepted_item_name)
	_already_fed = true
	GameProgress.mark_mountain_creature_fed()
	await _throw_arc(tex)
	if creature:
		creature.play(open_mouth_animation)

func _throw_arc(tex: Texture2D) -> void:
	if player == null or creature == null:
		push_warning("player or creature not assigned.")
		return
	if tex == null:
		push_warning("Dragged texture is null.")
		return
	var symbol := Sprite2D.new()
	symbol.texture = tex
	symbol.scale = symbol_scale
	symbol.global_position = player.global_position
	get_tree().current_scene.add_child(symbol)
	var elapsed := 0.0
	var start := player.global_position
	var end := creature.global_position
	while elapsed < throw_duration:
		elapsed += get_process_delta_time()
		var t := minf(elapsed / throw_duration, 1.0)
		var flat := start.lerp(end, t)
		var arc_y := -arc_height * 4.0 * t * (1.0 - t)
		symbol.global_position = Vector2(flat.x, flat.y + arc_y)
		symbol.rotation_degrees += spin_speed * get_process_delta_time()
		await get_tree().process_frame
	symbol.global_position = end
	symbol.queue_free()

func _set_creature_fed_pose() -> void:
	if creature == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	creature.play(open_mouth_animation)
	await get_tree().process_frame
	creature.pause()
	creature.frame = creature.sprite_frames.get_frame_count(open_mouth_animation) - 1
