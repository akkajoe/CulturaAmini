extends Node

@export var player_path: NodePath = ^"player"
@export var default_spawn_path: NodePath = ^"defaultSpawn"

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	#push_warning("GARDEN ROOT READY HIT")
	#push_warning("[GARDEN READY] start")
	if get_tree().current_scene == self:
		if has_node("bgMusic") and not $bgMusic.playing:
			$bgMusic.play()

	SceneCache.warm_scene("res://crash_site.tscn")
	SceneCache.warm_scene("res://mushroom_language_puzzle.tscn")
	SceneCache.warm_scene("res://mountain_creature_puzzle.tscn")
	var first_time_here := not GameProgress.garden_puzzle_visited
	if GameProgress.garden_puzzle_visited:
		_restore_state()
	else:
		GameProgress.garden_puzzle_visited = true
	if GameProgress.next_spawn_marker != "":
		push_warning("[GARDEN READY] transition entry = true, skipping default spawn")
		push_warning("[GARDEN READY] TOTAL _ready ms: ", Time.get_ticks_msec() - t0)
		return
	await get_tree().process_frame
	_apply_spawn(first_time_here)
	push_warning("[GARDEN READY] TOTAL _ready ms: ", Time.get_ticks_msec() - t0)

func _restore_state() -> void:
	var t0 := Time.get_ticks_msec()
	if GameProgress.garden_intro_done:
		if has_node("guide"):
			$guide.hide()
		if has_node("guide/GuideTrigger"):
			$guide/GuideTrigger.queue_free()
	push_warning("[GARDEN READY] _restore_state ms: ", Time.get_ticks_msec() - t0)

func _apply_spawn(first_time_here: bool) -> void:
	var t0 := Time.get_ticks_msec()
	var player: CharacterBody2D = get_node_or_null(player_path)
	if player == null:
		push_warning("GardenPuzzle.gd: player not found.")
		return
	var spawn_node: Node2D = get_node_or_null(default_spawn_path)
	if spawn_node == null:
		push_warning("GardenPuzzle.gd: no spawn node found.")
		return
	if player.has_method("set_spawn_world_position"):
		player.set_spawn_world_position(spawn_node.global_position)
	else:
		player.global_position = spawn_node.global_position
	push_warning("[GARDEN READY] _apply_spawn ms: ", Time.get_ticks_msec() - t0)
