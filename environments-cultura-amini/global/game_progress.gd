extends Node

# =========================================================
# Inventory / puzzle progress
# =========================================================
var puzzle_solve_count: int = 0
var has_symbol: bool = false
var has_hidden_symbol: bool = false
var inventory_items: Array[String] = []

# =========================================================
# Crash site state
# =========================================================
var crash_site_visited: bool = false
var guide_dialogue_done: bool = false
var code_scene_seen: bool = false

# =========================================================
# Garden puzzle state
# =========================================================
var garden_puzzle_visited: bool = false
var garden_intro_done: bool = false
var mushroom_picked_up: bool = false

# =========================================================
# Pending spawn marker
# =========================================================
var next_spawn_marker: String = ""

func register_puzzle_solve() -> void:
	if has_symbol:
		return
	puzzle_solve_count += 1
	print("Puzzle solves:", puzzle_solve_count)
	if puzzle_solve_count >= 3:
		add_inventory_item("symbol")
		print("Added puzzle reward symbol to inventory after 3 solves.")

func add_inventory_item(item_name: String) -> void:
	if inventory_items.has(item_name):
		print("Item already in inventory:", item_name)
		return
	inventory_items.append(item_name)
	match item_name:
		"symbol":
			has_symbol = true
		"hidden_symbol":
			has_hidden_symbol = true
		"mushroom":
			mushroom_picked_up = true
	print("Inventory now:", inventory_items)

func remove_inventory_item(item_name: String) -> void:
	if inventory_items.has(item_name):
		inventory_items.erase(item_name)
	match item_name:
		"symbol":
			has_symbol = inventory_items.has("symbol")
		"hidden_symbol":
			has_hidden_symbol = inventory_items.has("hidden_symbol")
		"mushroom":
			mushroom_picked_up = inventory_items.has("mushroom")
	print("Inventory after removal:", inventory_items)

func has_inventory_item(item_name: String) -> bool:
	return inventory_items.has(item_name)

func reset_progress() -> void:
	puzzle_solve_count = 0
	has_symbol = false
	has_hidden_symbol = false
	inventory_items.clear()
	crash_site_visited = false
	guide_dialogue_done = false
	code_scene_seen = false
	garden_puzzle_visited = false
	garden_intro_done = false
	mushroom_picked_up = false
	next_spawn_marker = ""
	print("Progress reset.")
