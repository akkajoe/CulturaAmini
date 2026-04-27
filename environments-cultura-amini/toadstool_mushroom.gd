extends Node2D

@export var required_symbols: Array[String] = ["creature1", "creature2", "creature3", "creature4"]
@export var symbol_display_textures: Array[Texture2D] = []
@export var final_symbol_texture: Texture2D
@export var slot_bar: CanvasLayer
@export var speech_canvas: CanvasLayer
@export var speech_box: Control
@export var bubble_display: TextureRect
@export var speech_point: Marker2D
@export var area: Area2D
@export var solved_speech_canvas: CanvasLayer
@export var solved_speech_box: Control
@export var solved_speech_point: Marker2D

# Throw exports
@export var throw_symbol_texture: Texture2D
@export var throw_from_point: Marker2D
@export var throw_to_point: Marker2D
@export var arc_height: float = 200.0
@export var throw_duration: float = 1.2
@export var spin_speed: float = 180.0
@export var symbol_scale: Vector2 = Vector2(0.1, 0.1)
@export var thrown_item_name: String = "toadstool_symbol"
@export var drop_radius: float = 64.0

var current_step: int = 0
var slots_complete: bool = false
var puzzle_complete: bool = false
var _player_in_zone: bool = false


func _ready() -> void:
	puzzle_complete = GameProgress.toadstool_puzzle_complete
	current_step = GameProgress.toadstool_current_step
	slots_complete = GameProgress.toadstool_slots_complete

	if area:
		area.body_entered.connect(_on_player_entered)
		area.body_exited.connect(_on_player_exited)

	if slot_bar and slot_bar.has_method("setup"):
		slot_bar.setup(required_symbols, symbol_display_textures, self)

	if speech_canvas:
		speech_canvas.visible = false
	if solved_speech_canvas:
		solved_speech_canvas.visible = false
	if slot_bar:
		slot_bar.visible = false
		slot_bar.offset = Vector2.ZERO

	if puzzle_complete:
		_apply_solved_state()
	else:
		_update_bubble()


func _apply_solved_state() -> void:
	if speech_canvas:
		speech_canvas.visible = false
	if slot_bar:
		slot_bar.visible = false
	if bubble_display:
		bubble_display.texture = null


func _process(_delta: float) -> void:
	if puzzle_complete:
		return
	if speech_canvas and speech_canvas.visible and speech_point:
		var screen_pos := get_viewport().get_canvas_transform() * speech_point.global_position
		speech_canvas.offset = Vector2i(int(screen_pos.x), int(screen_pos.y))


func _get_name_for_texture(tex: Texture2D) -> String:
	for node in get_tree().get_nodes_in_group("inventory_ui"):
		if node.has_method("get_item_name_for_texture"):
			return node.get_item_name_for_texture(tex)
	push_warning("Could not resolve texture to item name — no inventory_ui node found.")
	return ""


func _input(event: InputEvent) -> void:
	if puzzle_complete or not slots_complete or not _player_in_zone:
		return
	if not DragManager.is_dragging:
		return
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or event.pressed:
		return

	var dropped_name: String = DragManager.dragged_item_name
	var expected_name := _get_name_for_texture(final_symbol_texture)

	if expected_name == "":
		push_warning("final_symbol_texture not assigned or not recognised in inventory.")
		return

	if dropped_name != expected_name:
		push_warning("Dropped '%s' but need '%s'." % [dropped_name, expected_name])
		return

	var mouse_pos := get_viewport().get_mouse_position()
	if not _mouse_over_player(mouse_pos):
		push_warning("Correct item but not dropped on player — ignoring.")
		return

	push_warning("Final symbol '%s' dropped on player — puzzle complete." % dropped_name)
	DragManager.accept_drop()
	#GameProgress.inventory_items.erase(dropped_name)
	for node in get_tree().get_nodes_in_group("inventory_ui"):
		if node.has_method("refresh_inventory_ui"):
			node.refresh_inventory_ui()

	_on_puzzle_complete()


func _mouse_over_player(mouse_pos: Vector2) -> bool:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		push_warning("No node in group 'player' found.")
		return false

	var player := players[0]
	if not player is Node2D:
		push_warning("Player node is not a Node2D — cannot check position.")
		return false

	var screen_pos := get_viewport().get_canvas_transform() * (player as Node2D).global_position
	return mouse_pos.distance_to(screen_pos) <= drop_radius


func _on_player_entered(body: Node) -> void:
	if body.is_in_group("player") and not puzzle_complete:
		_player_in_zone = true
		if speech_canvas:
			speech_canvas.visible = true
		if slot_bar and not slots_complete:
			slot_bar.visible = true
			slot_bar.offset = Vector2.ZERO


func _on_player_exited(body: Node) -> void:
	if body.is_in_group("player") and not puzzle_complete:
		_player_in_zone = false
		if speech_canvas:
			speech_canvas.visible = false
		if slot_bar:
			slot_bar.visible = false


func on_symbol_dropped(symbol_name: String) -> bool:
	if puzzle_complete or slots_complete:
		return false
	if current_step >= required_symbols.size():
		return false
	if symbol_name != required_symbols[current_step]:
		return false

	current_step += 1
	GameProgress.toadstool_current_step = current_step
	GameProgress.toadstool_filled_items.append(symbol_name)

	_update_bubble()

	if current_step >= required_symbols.size():
		_on_slots_complete()

	return true


func _update_bubble() -> void:
	if bubble_display == null:
		return
	if current_step < symbol_display_textures.size():
		bubble_display.texture = symbol_display_textures[current_step]
	else:
		bubble_display.texture = null


func _on_slots_complete() -> void:
	slots_complete = true
	GameProgress.toadstool_slots_complete = true

	if slot_bar:
		slot_bar.visible = false

	_update_bubble()

	push_warning("All slots filled. Waiting for player to drag final symbol onto themselves.")


func _on_puzzle_complete() -> void:
	puzzle_complete = true
	GameProgress.toadstool_puzzle_complete = true

	if speech_canvas:
		speech_canvas.visible = false
	if slot_bar:
		slot_bar.visible = false
	if bubble_display:
		bubble_display.texture = null

	_show_solved_speech()
	print("Toadstool puzzle complete!")


func _show_solved_speech() -> void:
	if solved_speech_point == null:
		push_warning("Solved speech point not assigned.")
		return
	if solved_speech_canvas:
		solved_speech_canvas.visible = true
	if solved_speech_box:
		if solved_speech_box.has_method("place_at_world_position"):
			solved_speech_box.place_at_world_position(solved_speech_point.global_position)
		if solved_speech_box.has_method("start_dialogue"):
			solved_speech_box.start_dialogue()
		if solved_speech_box.has_signal("dialogue_finished"):
			if not solved_speech_box.dialogue_finished.is_connected(_on_solved_dialogue_finished):
				solved_speech_box.dialogue_finished.connect(_on_solved_dialogue_finished)


func _on_solved_dialogue_finished() -> void:
	if solved_speech_canvas:
		solved_speech_canvas.visible = false
	await get_tree().create_timer(0.3).timeout
	await _throw_to_player()


func _throw_to_player() -> void:
	if throw_symbol_texture == null:
		push_warning("throw_symbol_texture not assigned.")
		return
	if throw_from_point == null or throw_to_point == null:
		push_warning("throw_from_point or throw_to_point not assigned.")
		return

	var symbol := Sprite2D.new()
	symbol.texture = throw_symbol_texture
	symbol.scale = symbol_scale
	symbol.global_position = throw_from_point.global_position
	get_tree().current_scene.add_child(symbol)

	await _animate_arc(symbol, throw_from_point.global_position, throw_to_point.global_position)
	symbol.queue_free()

	if thrown_item_name != "":
		GameProgress.inventory_items.append(thrown_item_name)
		for node in get_tree().get_nodes_in_group("inventory_ui"):
			if node.has_method("refresh_inventory_ui"):
				node.refresh_inventory_ui()
		push_warning("Added %s to inventory" % thrown_item_name)


func _animate_arc(sprite: Sprite2D, start: Vector2, end: Vector2) -> void:
	var elapsed := 0.0
	while elapsed < throw_duration:
		elapsed += get_process_delta_time()
		var t := minf(elapsed / throw_duration, 1.0)
		var flat := start.lerp(end, t)
		var arc_y := -arc_height * 4.0 * t * (1.0 - t)
		sprite.global_position = Vector2(flat.x, flat.y + arc_y)
		sprite.rotation_degrees += spin_speed * get_process_delta_time()
		await get_tree().process_frame
	sprite.global_position = end
	sprite.rotation_degrees = 0.0
