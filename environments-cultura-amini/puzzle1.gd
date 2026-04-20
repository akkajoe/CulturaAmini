extends Node2D

const NUM_STATES := 3
const NUM_SLOTS := 4

@export var main_slots_path: NodePath
@export var target_slots_path: NodePath

@export var scramble_min: int = 2
@export var scramble_max: int = 4
@export var solve_delay: float = 0.6

@export var time_limit: float = 60.0
@export_file("*.tscn") var timeout_scene_path: String = "res://code.tscn"

@onready var timer_label: Label = $TimerLabel
var time_left: float

@onready var main_parent: Node = get_node(main_slots_path)
@onready var target_parent: Node = get_node(target_slots_path)

var main_slots: Array = []
var target_slots: Array = []

# adjacency:
# 0 affects 1,3
# 1 affects 0,2
# 2 affects 1,3
# 3 affects 0,2
var adj: Array[PackedInt32Array] = [
	PackedInt32Array([1, 3]),
	PackedInt32Array([0, 2]),
	PackedInt32Array([1, 3]),
	PackedInt32Array([0, 2])
]

var state: PackedInt32Array
var target: PackedInt32Array

var solved: bool = false
var transitioning: bool = false
var history: Array[PackedInt32Array] = []

var last_target_key: String = ""

var _match_done_count: int = 0
var _match_waiting: bool = false
var _timer_expired: bool = false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	time_left = time_limit
	randomize()
	collect_slots()
	await generate_new_puzzle()
	$bgMusic.play()
	_start_timeout_timer()


func _process(delta: float) -> void:
	if solved or transitioning or _timer_expired:
		return

	time_left -= delta
	time_left = max(time_left, 0)

	var total_seconds = int(time_left)
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60

	timer_label.text = "%02d:%02d" % [minutes, seconds]


func _start_timeout_timer() -> void:
	_timer_expired = false
	await get_tree().create_timer(time_limit).timeout

	if _timer_expired:
		return

	if solved or transitioning:
		return

	_timer_expired = true
	transitioning = true

	if $bgMusic.playing:
		$bgMusic.stop()

	if not timeout_scene_path.is_empty():
		get_tree().change_scene_to_file(timeout_scene_path)
	else:
		push_warning("Timeout scene path is empty.")


func collect_slots() -> void:
	var main_children := main_parent.get_children()
	var target_children := target_parent.get_children()

	main_slots.clear()
	target_slots.clear()
	main_slots.resize(NUM_SLOTS)
	target_slots.resize(NUM_SLOTS)

	for s in main_children:
		if not ("index" in s):
			push_error("Main slot is missing exported 'index': " + s.name)
			continue

		if s.index < 0 or s.index >= NUM_SLOTS:
			push_error("Bad main slot index: " + str(s.index))
			continue

		main_slots[s.index] = s

		if s.has_signal("clicked") and not s.clicked.is_connected(_on_slot_clicked):
			s.clicked.connect(_on_slot_clicked)

		if s.has_signal("match_finished") and not s.match_finished.is_connected(_on_slot_match_finished):
			s.match_finished.connect(_on_slot_match_finished)

	for s in target_children:
		if not ("index" in s):
			push_error("Target slot is missing exported 'index': " + s.name)
			continue

		if s.index < 0 or s.index >= NUM_SLOTS:
			push_error("Bad target slot index: " + str(s.index))
			continue

		target_slots[s.index] = s

	for i in range(NUM_SLOTS):
		if main_slots[i] == null:
			push_error("MainSlots missing slot index " + str(i))
		if target_slots[i] == null:
			push_error("TargetSlots missing slot index " + str(i))


func _target_key(t: PackedInt32Array) -> String:
	var k := ""
	for i in range(t.size()):
		k += str(t[i])
	return k


func generate_new_puzzle() -> void:
	transitioning = true
	solved = false

	for s in target_slots:
		if s != null:
			s.play_target_fade_out(0.10)
	await get_tree().create_timer(0.10).timeout

	var attempts := 0
	while true:
		attempts += 1
		target = PackedInt32Array()
		target.resize(NUM_SLOTS)

		for i in range(NUM_SLOTS):
			target[i] = randi() % NUM_STATES

		var key := _target_key(target)
		if key != last_target_key or attempts > 10:
			last_target_key = key
			break

	var moves: int = scramble_min + (randi() % (scramble_max - scramble_min + 1))
	generate_solvable_start(moves)

	update_all_visuals()

	for s in target_slots:
		if s != null:
			s.play_target_fade_in(0.14)

	transitioning = false


func advance_node(i: int) -> void:
	state[i] = (state[i] + 1) % NUM_STATES


func apply_click(i: int) -> void:
	advance_node(i)
	for n in adj[i]:
		advance_node(n)


func generate_solvable_start(moves: int) -> void:
	state = target.duplicate()

	for _k in range(moves):
		apply_click(randi() % state.size())

	while is_solved():
		apply_click(randi() % state.size())

	history.clear()


func _on_slot_clicked(i: int) -> void:
	if solved or transitioning or _timer_expired:
		return

	history.append(state.duplicate())
	apply_click(i)
	update_all_visuals()

	if is_solved():
		$winChime.play()
		solved = true
		transitioning = true
		GameProgress.register_puzzle_solve()
		await _celebrate_and_advance()


func _celebrate_and_advance() -> void:
	_match_done_count = 0
	_match_waiting = true

	for s in main_slots:
		if s != null:
			s.play_match_anim()

	var start_ms := Time.get_ticks_msec()
	var timeout_ms := int(max(0.01, solve_delay) * 1000.0)

	while _match_done_count < NUM_SLOTS:
		await get_tree().process_frame
		if Time.get_ticks_msec() - start_ms >= timeout_ms:
			break

	_match_waiting = false

	await generate_new_puzzle()


func _on_slot_match_finished(_idx: int) -> void:
	if not _match_waiting:
		return
	_match_done_count += 1


func update_all_visuals() -> void:
	for i in range(state.size()):
		if main_slots[i] != null:
			main_slots[i].set_state(state[i])

	for i in range(target.size()):
		if target_slots[i] != null:
			target_slots[i].set_state(target[i])


func is_solved() -> bool:
	for i in range(state.size()):
		if state[i] != target[i]:
			return false
	return true


func reset_level() -> void:
	if transitioning or _timer_expired:
		return
	await generate_new_puzzle()


func undo() -> void:
	if solved or transitioning or _timer_expired:
		return
	if history.size() == 0:
		return

	state = history.pop_back()
	update_all_visuals()
