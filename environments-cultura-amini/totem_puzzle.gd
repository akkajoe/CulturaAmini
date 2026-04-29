extends Node2D

signal puzzle_solved
signal spores_finished

@export var spores_path: NodePath

@onready var slot_top: TotemSlot = $Slots/SlotTop
@onready var slot_middle: TotemSlot = $Slots/SlotMiddle
@onready var slot_bottom: TotemSlot = $Slots/SlotBottom
@onready var speech_box: Control = get_node("../CanvasLayer/SpeechBox")
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

	if speech_box == null:
		push_warning("TotemPuzzle: speech_box is NULL — hardcoded path failed.")
	else:
		push_warning("TotemPuzzle: speech_box found OK: " + speech_box.name)
		if speech_box.has_signal("line_started"):
			speech_box.line_started.connect(_on_speech_line_started)
		if speech_box.has_signal("dialogue_finished"):
			speech_box.dialogue_finished.connect(_on_dialogue_finished)
			push_warning("TotemPuzzle: connected to dialogue_finished OK.")
		else:
			push_warning("TotemPuzzle: dialogue_finished signal NOT found on speech_box.")


func _on_any_slot_changed() -> void:
	if is_puzzle_solved():
		_play_spores()
		puzzle_solved.emit()


func _play_spores() -> void:
	if spores == null:
		push_warning("TotemPuzzle: spores node not assigned.")
		return
	$spores2.play()
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
		_switch_mushroom_to_default()
		spores_finished.emit()
	)

func _switch_mushroom_to_default() -> void:
	var mushroom_root := get_parent().get_node_or_null("psychMushroom")
	if mushroom_root == null or not is_instance_valid(mushroom_root):
		push_warning("TotemPuzzle: psychMushroom not found for default switch.")
		return
	mushroom_root.visible = true
	mushroom_root.modulate.a = 1.0
	var mushroom_sprite := get_parent().get_node_or_null("psychMushroom/psych")
	if mushroom_sprite == null or not is_instance_valid(mushroom_sprite):
		push_warning("TotemPuzzle: psychMushroom/psych not found for default switch.")
		return
	if mushroom_sprite is AnimatedSprite2D:
		push_warning("TotemPuzzle: switching mushroom to default animation.")
		(mushroom_sprite as AnimatedSprite2D).modulate.a = 1.0
		(mushroom_sprite as AnimatedSprite2D).play("default")

func _on_dialogue_finished() -> void:
	if GameProgress.mushroom_picked_up:
		push_warning("TotemPuzzle: mushroom already picked up, skipping.")
		return

	var mushroom_root := get_parent().get_node_or_null("psychMushroom")
	if mushroom_root == null or not is_instance_valid(mushroom_root):
		push_warning("TotemPuzzle: could not find psychMushroom under parent: " + get_parent().name)
		return
	mushroom_root.visible = true
	push_warning("TotemPuzzle: psychMushroom root made visible.")

	var mushroom_sprite := get_parent().get_node_or_null("psychMushroom/psych")
	if mushroom_sprite == null or not is_instance_valid(mushroom_sprite):
		push_warning("TotemPuzzle: could not find psychMushroom/psych.")
		return
	if not mushroom_sprite is AnimatedSprite2D:
		push_warning("TotemPuzzle: psychMushroom/psych is not an AnimatedSprite2D, it is: " + mushroom_sprite.get_class())
		return

	push_warning("TotemPuzzle: playing bad_mushroom animation.")
	(mushroom_sprite as AnimatedSprite2D).play("bad_mushroom")


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
