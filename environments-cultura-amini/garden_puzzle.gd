extends Node

@export var player_path: NodePath = ^"player"
@export var default_spawn_path: NodePath = ^"defaultSpawn"

func _ready() -> void:
	SceneCache.warm_scene("res://crash_site.tscn")
	SceneCache.warm_scene("res://mushroom_language_puzzle.tscn")
	SceneCache.warm_scene("res://mountain_creature_puzzle.tscn")
	var t0 := Time.get_ticks_msec()
	push_warning("GARDEN ROOT READY HIT")
	push_warning("[GARDEN READY] start")

	var t_music_0 := Time.get_ticks_msec()
	if has_node("bgMusic") and not $bgMusic.playing:
		$bgMusic.play()
	var t_music_1 := Time.get_ticks_msec()
	push_warning("[GARDEN READY] bgMusic ms: ", t_music_1 - t_music_0)

	var t_flag_0 := Time.get_ticks_msec()
	var first_time_here := not GameProgress.garden_puzzle_visited

	if GameProgress.garden_puzzle_visited:
		_restore_state()
	else:
		GameProgress.garden_puzzle_visited = true
	var t_flag_1 := Time.get_ticks_msec()
	push_warning("[GARDEN READY] restore/visit ms: ", t_flag_1 - t_flag_0)

	# If we arrived through a scene transition, the transition system
	# already placed the player exactly where it should be.
	if GameProgress.next_spawn_marker != "":
		GameProgress.next_spawn_marker = ""
		push_warning("[GARDEN READY] transition entry = true")
		push_warning("[GARDEN READY] TOTAL _ready ms: ", Time.get_ticks_msec() - t0)
		return

	# Only do local/default spawn placement when this scene was not
	# entered through the transition handoff.
	var t_wait_0 := Time.get_ticks_msec()
	await get_tree().process_frame
	var t_wait_1 := Time.get_ticks_msec()
	print("[GARDEN READY] wait frame ms: ", t_wait_1 - t_wait_0)

	var t_spawn_0 := Time.get_ticks_msec()
	_apply_spawn(first_time_here)
	var t_spawn_1 := Time.get_ticks_msec()
	push_warning("[GARDEN READY] _apply_spawn ms: ", t_spawn_1 - t_spawn_0)

	push_warning("[GARDEN READY] transition entry = false")
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

	push_warning("[GARDEN READY] _apply_spawn internal ms: ", Time.get_ticks_msec() - t0)
