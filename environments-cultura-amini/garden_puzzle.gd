extends Node

@export var player_path: NodePath = ^"player"
@export var default_spawn_path: NodePath = ^"defaultSpawn"
@export var totem_path: NodePath = ^"totem"

func _ready() -> void:
	SceneCache.warm_scene("res://crash_site.tscn")
	SceneCache.warm_scene("res://mushroom_language_puzzle.tscn")
	SceneCache.warm_scene("res://mountain_creature_puzzle.tscn")

	# Hide mushroom by default — only shows after spores
	var mushroom := get_node_or_null("psychMushroom")
	if mushroom != null:
		if GameProgress.mushroom_picked_up:
			mushroom.queue_free()
		else:
			mushroom.visible = false

	# Connect to totem's spores_finished signal
	var totem := get_node_or_null(totem_path)
	if totem != null and totem.has_signal("spores_finished"):
		totem.spores_finished.connect(_on_spores_finished)

	var first_time_here := not GameProgress.garden_puzzle_visited
	if GameProgress.garden_puzzle_visited:
		_restore_state()
	else:
		GameProgress.garden_puzzle_visited = true

	if GameProgress.next_spawn_marker != "":
		return
	await get_tree().process_frame
	_apply_spawn(first_time_here)

func _on_spores_finished() -> void:
	var mushroom := get_node_or_null("psychMushroom")
	if mushroom != null and is_instance_valid(mushroom):
		mushroom.visible = true
		if mushroom.has_method("grow"):
			mushroom.grow()

func on_scene_activated() -> void:
	if has_node("bgMusic") and not $bgMusic.playing:
		$bgMusic.play()

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
