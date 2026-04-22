extends Node2D

signal puzzle_solved
signal spores_finished

@export var speech_box_path: NodePath
@export var spores_path: NodePath

@onready var slot_top: TotemSlot = $Slots/SlotTop
@onready var slot_middle: TotemSlot = $Slots/SlotMiddle
@onready var slot_bottom: TotemSlot = $Slots/SlotBottom
@onready var speech_box: SpeechBox = get_node_or_null(speech_box_path) as SpeechBox
@onready var spores: AnimatedSprite2D = get_node_or_null(spores_path) as AnimatedSprite2D

func _ready() -> void:
	slot_top.set_default_symbol($Slots/SlotTop/DefaultSymbol, "default_top")
	slot_middle.set_default_symbol($Slots/SlotMiddle/DefaultSymbol, "default_middle")
	slot_bottom.set_default_symbol($Slots/SlotBottom/DefaultSymbol, "default_bottom")
	_stop_default_symbol_animations()
	slot_top.slot_changed.connect(_on_any_slot_changed)
	slot_middle.slot_changed.connect(_on_any_slot_changed)
	slot_bottom.slot_changed.connect(_on_any_slot_changed)
	if spores != null:
		spores.visible = false
	if speech_box != null and speech_box.has_signal("line_started"):
		speech_box.line_started.connect(_on_speech_line_started)

func _on_any_slot_changed() -> void:
	if is_puzzle_solved():
		_play_spores()
		puzzle_solved.emit()

func _play_spores() -> void:
	if spores == null:
		push_warning("TotemPuzzle: spores node not assigned.")
		return
	spores.modulate.a = 0.0
	spores.visible = true
	spores.play()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(spores, "modulate:a", 1.0, 1.2)
	tween.tween_interval(2.0)
	tween.tween_property(spores, "modulate:a", 1.0, 1.2)
	tween.tween_callback(func():
		spores.visible = false
		spores_finished.emit()
	)

func _on_speech_line_started(line_text: String) -> void:
	var clean_line := line_text.strip_edges().to_lower()
	clean_line = clean_line.trim_suffix(".")
	clean_line = clean_line.trim_suffix("!")
	clean_line = clean_line.trim_suffix("?")
	if clean_line == "you are not the first to land here":
		_play_default_symbol_animations()
	else:
		_stop_default_symbol_animations()

func _play_default_symbol_animations() -> void:
	_play_if_default_present(slot_top)
	_play_if_default_present(slot_middle)
	_play_if_default_present(slot_bottom)

func _stop_default_symbol_animations() -> void:
	_stop_if_default_present(slot_top)
	_stop_if_default_present(slot_middle)
	_stop_if_default_present(slot_bottom)

func _play_if_default_present(slot: TotemSlot) -> void:
	if slot == null:
		return
	if slot.default_symbol != null and is_instance_valid(slot.default_symbol):
		if slot.default_symbol is AnimatedSprite2D:
			(slot.default_symbol as AnimatedSprite2D).play()

func _stop_if_default_present(slot: TotemSlot) -> void:
	if slot == null:
		return
	if slot.default_symbol != null and is_instance_valid(slot.default_symbol):
		if slot.default_symbol is AnimatedSprite2D:
			(slot.default_symbol as AnimatedSprite2D).stop()

func is_puzzle_solved() -> bool:
	return (
		slot_top.is_correct()
		and slot_middle.is_correct()
		and slot_bottom.is_correct()
	)
