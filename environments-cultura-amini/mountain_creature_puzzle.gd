extends Node2D
class_name SymbolThrow

signal symbol_landed

@export var symbol_texture: Texture2D
@export var throw_from_path: NodePath
@export var throw_to_path: NodePath
@export var creature_path: NodePath
@export var land_animation: String = "default"
@export var restore_animation: String = "default"
@export var arc_height: float = 200.0
@export var throw_duration: float = 1.2
@export var symbol_scale: Vector2 = Vector2(0.15, 0.15)
@export var spin_speed: float = 180.0
@export var guide_path: NodePath = ^"guide"
@export var guide_trigger_path: NodePath = ^"guide/GuideTrigger"

@export var speech_box: Control
@export var route_a2_path: NodePath = ^"traversalRoutes/route_a2"

var _symbol: Sprite2D = null


func _ready() -> void:
	GameProgress.mountain_creature_visited = true
	push_warning("guide_done: %s" % str(GameProgress.mountain_creature_guide_done))
	push_warning("symbol_thrown: %s" % str(GameProgress.mountain_creature_symbol_thrown))
	push_warning("creature_fed: %s" % str(GameProgress.mountain_creature_fed))
	push_warning("speech_box: %s" % str(speech_box))
	_restore_state()
	_connect_dialogue()


func on_scene_activated() -> void:
	GameProgress.mountain_creature_visited = true
	_restore_state()
	_connect_dialogue()


func _restore_state() -> void:
	if GameProgress.mountain_creature_guide_done:
		var guide := get_node_or_null(guide_path)
		if guide != null:
			guide.hide()
		var trigger := get_node_or_null(guide_trigger_path)
		if trigger != null:
			trigger.queue_free()
	if GameProgress.mountain_creature_symbol_thrown and not GameProgress.mountain_creature_fed:
		_play_restore_animation()
	_update_route_a2()


func _update_route_a2() -> void:
	var route := get_node_or_null(route_a2_path)
	if route == null:
		push_warning("SymbolThrow: route_a2 not found at path: %s" % str(route_a2_path))
		return
	if route is TraversalRoute:
		route.enabled = GameProgress.mountain_creature_fed
	else:
		push_warning("SymbolThrow: route_a2 is not a TraversalRoute")

func _play_restore_animation() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var creature := get_node_or_null(creature_path)
	if creature == null:
		return
	if creature is AnimatedSprite2D:
		var s := creature as AnimatedSprite2D
		s.play(restore_animation)
		await get_tree().process_frame
		s.pause()
		s.frame = s.sprite_frames.get_frame_count(restore_animation) - 1


func _connect_dialogue() -> void:
	if GameProgress.mountain_creature_guide_done:
		push_warning("guide already done, skipping connection")
		return
	if GameProgress.mountain_creature_symbol_thrown:
		push_warning("symbol already thrown, skipping connection")
		return
	if speech_box == null:
		push_warning("SymbolThrow: speech_box is null - drag it in the Inspector!")
		return
	push_warning("Connecting to dialogue_finished on: %s" % str(speech_box))
	if speech_box.has_signal("dialogue_finished"):
		if not speech_box.dialogue_finished.is_connected(_on_dialogue_finished):
			speech_box.dialogue_finished.connect(_on_dialogue_finished)
	else:
		push_warning("speech_box has no dialogue_finished signal!")


func _on_dialogue_finished() -> void:
	push_warning("dialogue finished - throwing symbol now!")
	GameProgress.mountain_creature_guide_done = true
	throw_symbol()


func throw_symbol() -> void:
	if symbol_texture == null:
		push_warning("SymbolThrow: no texture assigned.")
		return
	var from := get_node_or_null(throw_from_path) as Marker2D
	var to   := get_node_or_null(throw_to_path) as Marker2D
	if from == null or to == null:
		push_warning("SymbolThrow: throw_from_path or throw_to_path not set.")
		return
	if _symbol != null and is_instance_valid(_symbol):
		_symbol.queue_free()
	_symbol = Sprite2D.new()
	_symbol.texture = symbol_texture
	_symbol.scale = symbol_scale
	_symbol.global_position = from.global_position
	get_tree().current_scene.add_child(_symbol)
	await _animate_arc(_symbol, from.global_position, to.global_position)
	_symbol.hide()
	GameProgress.mountain_creature_symbol_thrown = true
	symbol_landed.emit()
	push_warning("symbol throw complete")


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


func unlock_route_a2() -> void:
	_update_route_a2()
