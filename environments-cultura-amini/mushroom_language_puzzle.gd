extends Node

@export var required_symbols: Array[String] = ["symbol_1", "symbol_2", "symbol_3", "symbol_4"]
@export var symbol_display_textures: Array[Texture2D] = []
@export var slot_fill_textures: Array[Texture2D] = []
@export var slot_bar_path: NodePath

var current_step: int = 0
var puzzle_complete: bool = false

@onready var _slot_bar: CanvasLayer = get_node_or_null(slot_bar_path)
@onready var _speech_box: Control = get_node_or_null("SpeechBox")
@onready var _bubble_display: TextureRect = get_node_or_null("SpeechBox/TextureRect")
@onready var _speech_point: Marker2D = get_node_or_null("SpeechPoint")
@onready var _area: Area2D = get_node_or_null("Area2D")


func _ready() -> void:
	if _area:
		_area.body_entered.connect(_on_player_entered)
		_area.body_exited.connect(_on_player_exited)
	if _slot_bar and _slot_bar.has_method("setup"):
		_slot_bar.setup(required_symbols, symbol_display_textures, slot_fill_textures, self)
	if _speech_box:
		_speech_box.hide()
	if _slot_bar:
		_slot_bar.hide()
	_try_play_music()


func _try_play_music() -> void:
	if has_node("bgMusic"):
		var bg := $bgMusic
		if not bg.playing:
			bg.play()


func _on_player_entered(body: Node) -> void:
	if body.is_in_group("player"):
		show_puzzle_ui()


func _on_player_exited(body: Node) -> void:
	if body.is_in_group("player"):
		hide_puzzle_ui()


func show_puzzle_ui() -> void:
	if puzzle_complete:
		return
	if _speech_box:
		_position_speech_box()
		_speech_box.show()
	_update_bubble()
	if _slot_bar:
		_slot_bar.show()


func hide_puzzle_ui() -> void:
	if _speech_box:
		_speech_box.hide()
	if _slot_bar:
		_slot_bar.hide()


func _position_speech_box() -> void:
	if _speech_point == null or _speech_box == null:
		return
	var screen_pos := get_viewport().get_canvas_transform() * _speech_point.global_position
	_speech_box.position = screen_pos


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
	if _bubble_display == null:
		return
	if current_step < symbol_display_textures.size():
		_bubble_display.texture = symbol_display_textures[current_step]
	else:
		_bubble_display.texture = null


func _on_puzzle_complete() -> void:
	puzzle_complete = true
	if _speech_box:
		_speech_box.hide()
	if _slot_bar:
		_slot_bar.hide()
	print("Puzzle complete!")
