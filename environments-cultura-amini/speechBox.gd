extends Control
class_name SpeechBox

signal dialogue_finished
signal line_started(line_text: String)

@onready var background: TextureRect = $TextureRect
@onready var next_button: TextureButton = $Button
@onready var text_label: RichTextLabel = $RichTextLabel
@onready var timer: Timer = $Timer

@onready var type_sounds: Array[AudioStreamPlayer] = [
	$TypeSound1,
	$TypeSound2,
	$TypeSound3
]

@export var typing_speed: float = 0.08
@export var pre_typing_delay: float = 1.0
@export var world_screen_offset: Vector2 = Vector2(-120, -70)

@export var guide_path: NodePath
@export var player_path: NodePath
@export var player_freeze_time: float = 6.0

@export_multiline var dialogue_text: String = "Greetings."
@export var dialogue_lines: Array[String] = [
	"Greetings",
	"You are not the first to land here.",
	"I can help you escape."
]

var lines: Array[String] = []
var current_line_index: int = 0
var full_text: String = ""
var char_index: int = 0
var is_typing: bool = false
var is_waiting_to_start: bool = false

var sentence_pitch_min: float = 0.92
var sentence_pitch_max: float = 1.08
var sentence_volume_min: float = -2.0
var sentence_volume_max: float = 1.0
var chars_per_sound: int = 2

var sentence_typing_speed: float = 0.08
var sentence_pre_delay: float = 1.0
var sentence_voice_duration: float = 1.0


func _ready() -> void:
	hide()
	next_button.hide()
	next_button.pressed.connect(_on_next_pressed)
	timer.timeout.connect(_on_timer_timeout)
	timer.one_shot = false
	randomize()

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_button.mouse_filter = Control.MOUSE_FILTER_STOP


func start_dialogue(_body: Node = null, _trigger: Node = null) -> void:
	if dialogue_lines.is_empty():
		lines = [dialogue_text]
	else:
		lines = dialogue_lines.duplicate()

	current_line_index = 0
	_start_current_line()


func start_dialogue_text(text: String) -> void:
	lines = [text]
	current_line_index = 0
	_start_current_line()


func start_dialogue_lines(new_lines: Array[String]) -> void:
	lines.clear()
	for line in new_lines:
		lines.append(str(line))

	current_line_index = 0
	_start_current_line()


func _start_current_line() -> void:
	if lines.is_empty():
		_finish_dialogue()
		return

	_stop_all_type_sounds()

	full_text = lines[current_line_index]
	line_started.emit(full_text)

	char_index = 0
	is_typing = false
	is_waiting_to_start = true

	_randomize_sentence_voice_profile()
	_randomize_sentence_timing()

	text_label.text = ""
	show()
	next_button.show()

	timer.stop()
	_begin_typing_after_delay()


func _begin_typing_after_delay() -> void:
	var line_id := current_line_index

	if full_text.length() > 0 and full_text.length() > 3:
		_play_random_type_sound()

	if sentence_pre_delay > 0.0:
		await get_tree().create_timer(sentence_pre_delay).timeout

	if not visible:
		return

	if not is_waiting_to_start:
		return

	if current_line_index != line_id:
		return

	is_waiting_to_start = false
	is_typing = true
	timer.wait_time = sentence_typing_speed
	timer.start()

	_cut_off_speech_later(line_id)


func _randomize_sentence_voice_profile() -> void:
	var base_pitch := randf_range(0.90, 1.08)

	sentence_pitch_min = max(0.5, base_pitch - randf_range(0.02, 0.05))
	sentence_pitch_max = min(2.0, base_pitch + randf_range(0.02, 0.06))

	sentence_volume_min = randf_range(-4.0, -1.5)
	sentence_volume_max = randf_range(-0.5, 1.5)


func _randomize_sentence_timing() -> void:
	var char_count := full_text.length()

	sentence_typing_speed = typing_speed

	if char_count <= 3:
		sentence_pre_delay = 0.02
	elif char_count < 10:
		sentence_pre_delay = randf_range(0.05, 0.12)
	elif char_count < 30:
		sentence_pre_delay = randf_range(0.12, 0.25)
	else:
		sentence_pre_delay = randf_range(0.2, 0.4)

	if char_count <= 3:
		chars_per_sound = 99
	elif char_count < 40:
		chars_per_sound = 2
	else:
		chars_per_sound = 3

	sentence_voice_duration = 0.35 + (char_count * 0.045)
	sentence_voice_duration = clamp(sentence_voice_duration, 0.35, 2.2)


func place_at_world_position(world_pos: Vector2) -> void:
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
	position = screen_pos + world_screen_offset


func _on_timer_timeout() -> void:
	if char_index < full_text.length():
		var next_char := full_text[char_index]

		if next_char != " " and char_index % chars_per_sound == 0:
			_play_random_type_sound()

		char_index += 1
		text_label.text = full_text.substr(0, char_index)
	else:
		timer.stop()
		is_typing = false
		_stop_all_type_sounds()


func _play_random_type_sound() -> void:
	if type_sounds.is_empty():
		return

	var player := type_sounds[randi() % type_sounds.size()]
	player.pitch_scale = randf_range(sentence_pitch_min, sentence_pitch_max)
	player.volume_db = randf_range(sentence_volume_min, sentence_volume_max)
	player.stop()
	player.play()


func _stop_all_type_sounds() -> void:
	for player in type_sounds:
		if player != null:
			player.stop()


func _cut_off_speech_later(line_id: int) -> void:
	await get_tree().create_timer(sentence_voice_duration).timeout

	if current_line_index != line_id:
		return

	_stop_all_type_sounds()


func _on_next_pressed() -> void:
	if is_waiting_to_start:
		is_waiting_to_start = false
		is_typing = true
		timer.stop()
		timer.wait_time = sentence_typing_speed
		timer.start()
		_cut_off_speech_later(current_line_index)
		return

	if is_typing:
		timer.stop()
		text_label.text = full_text
		is_typing = false
		_stop_all_type_sounds()
		return

	if current_line_index < lines.size() - 1:
		current_line_index += 1
		_start_current_line()
	else:
		_finish_dialogue()


func _finish_dialogue() -> void:
	timer.stop()
	_stop_all_type_sounds()
	hide()
	next_button.hide()

	var guide := get_node_or_null(guide_path)
	if guide != null and guide.has_method("start_exit"):
		guide.start_exit()

	var player := get_node_or_null(player_path)
	if player != null and player.has_method("set_movement_enabled"):
		player.set_movement_enabled(false)
		_reenable_player_after_delay(player)

	dialogue_finished.emit()


func _reenable_player_after_delay(player: Node) -> void:
	await get_tree().create_timer(player_freeze_time).timeout

	if player != null and is_instance_valid(player) and player.has_method("set_movement_enabled"):
		player.set_movement_enabled(true)
