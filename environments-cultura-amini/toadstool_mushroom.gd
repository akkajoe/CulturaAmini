extends Node2D

@export var required_symbols: Array[String] = ["creature1", "creature2", "creature3"]
@export var symbol_display_textures: Array[Texture2D] = []
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
#@export var symbol_scale: Vector2 = Vector2(1.0, 1.0)
@export var spin_speed: float = 180.0
@export var symbol_scale: Vector2 = Vector2(0.1, 0.1)

var current_step: int = 0
var puzzle_complete: bool = false

func _ready() -> void:
	if area:
		area.body_entered.connect(_on_player_entered)
		area.body_exited.connect(_on_player_exited)
	if slot_bar and slot_bar.has_method("setup"):
		slot_bar.setup(required_symbols, self)
	if speech_canvas:
		speech_canvas.visible = false
	if solved_speech_canvas:
		solved_speech_canvas.visible = false
	if slot_bar:
		slot_bar.visible = false
		slot_bar.offset = Vector2.ZERO
	_update_bubble()

func _process(_delta: float) -> void:
	if puzzle_complete:
		return
	if speech_canvas and speech_canvas.visible and speech_point:
		var screen_pos := get_viewport().get_canvas_transform() * speech_point.global_position
		speech_canvas.offset = Vector2i(int(screen_pos.x), int(screen_pos.y))

func _on_player_entered(body: Node) -> void:
	if body.is_in_group("player") and not puzzle_complete:
		if speech_canvas:
			speech_canvas.visible = true
		if slot_bar:
			slot_bar.visible = true
			slot_bar.offset = Vector2.ZERO

func _on_player_exited(body: Node) -> void:
	if body.is_in_group("player") and not puzzle_complete:
		if speech_canvas:
			speech_canvas.visible = false
		if slot_bar:
			slot_bar.visible = false

func on_symbol_dropped(symbol_name: String) -> bool:
	if puzzle_complete:
		return false
	if current_step >= required_symbols.size():
		return false
	if symbol_name != required_symbols[current_step]:
		return false
	current_step += 1
	_update_bubble()
	if current_step >= required_symbols.size():
		_on_puzzle_complete()
	return true

func _update_bubble() -> void:
	if bubble_display == null:
		return
	if current_step < symbol_display_textures.size():
		bubble_display.texture = symbol_display_textures[current_step]
	else:
		bubble_display.texture = null

func _on_puzzle_complete() -> void:
	puzzle_complete = true
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
		# Connect to dialogue finished to trigger throw
		if solved_speech_box.has_signal("dialogue_finished"):
			if not solved_speech_box.dialogue_finished.is_connected(_on_solved_dialogue_finished):
				solved_speech_box.dialogue_finished.connect(_on_solved_dialogue_finished)

func _on_solved_dialogue_finished() -> void:
	if solved_speech_canvas:
		solved_speech_canvas.visible = false
	await get_tree().create_timer(0.3).timeout
	await _throw_to_player()

@export var thrown_item_name: String = "toadstool_symbol"

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
	# Add to inventory after throw lands
	if thrown_item_name != "":
		push_warning("Before add: %s" % str(GameProgress.inventory_items))
		GameProgress.inventory_items.append(thrown_item_name)
		push_warning("After add: %s" % str(GameProgress.inventory_items))
		for node in get_tree().get_nodes_in_group("inventory_ui"):
			push_warning("Found inventory_ui node: %s" % node.name)
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
