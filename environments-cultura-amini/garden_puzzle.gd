extends Node

@export var player_path: NodePath = ^"player"
@export var default_spawn_path: NodePath = ^"defaultSpawn"

func _ready() -> void:
	if has_node("bgMusic") and not $bgMusic.playing:
		$bgMusic.play()

	var first_time_here := not GameProgress.garden_puzzle_visited

	if GameProgress.garden_puzzle_visited:
		_restore_state()
	else:
		GameProgress.garden_puzzle_visited = true

	# If we arrived through a scene transition, the transition system
	# already placed the player exactly where it should be.
	if GameProgress.next_spawn_marker != "":
		GameProgress.next_spawn_marker = ""
		return

	# Only do local/default spawn placement when this scene was not
	# entered through the transition handoff.
	await get_tree().process_frame
	_apply_spawn(first_time_here)


func _restore_state() -> void:
	if GameProgress.garden_intro_done:
		if has_node("guide"):
			$guide.hide()

		if has_node("guide/GuideTrigger"):
			$guide/GuideTrigger.queue_free()


func _apply_spawn(first_time_here: bool) -> void:
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
