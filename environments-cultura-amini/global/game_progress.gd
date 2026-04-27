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
# Mountain creature puzzle state
# =========================================================
var mountain_creature_visited: bool = false
var mountain_creature_guide_done: bool = false
var mountain_creature_symbol_thrown: bool = false
var mountain_creature_fed: bool = false
var mountain_creature_openmouth: bool = false

# =========================================================
# Toadstool puzzle state
# =========================================================
var toadstool_puzzle_complete: bool = false
var toadstool_slots_complete: bool = false
var toadstool_current_step: int = 0
var toadstool_filled_items: Array[String] = []

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
		"bad_mushroom":
			pass
		"creature_fed":
			mountain_creature_fed = true
			mountain_creature_openmouth = true
			mountain_creature_symbol_thrown = true
	print("Inventory now:", inventory_items)
	_refresh_inventory_ui()


func remove_inventory_item(item_name: String) -> void:
	if inventory_items.has(item_name):
		inventory_items.erase(item_name)
	match item_name:
		"symbol":
			has_symbol = inventory_items.has("symbol")
		"hidden_symbol":
			has_hidden_symbol = inventory_items.has("hidden_symbol")
		"mushroom", "bad_mushroom":
			mushroom_picked_up = inventory_items.has("mushroom") or inventory_items.has("bad_mushroom")
		"creature_fed":
			mountain_creature_fed = inventory_items.has("creature_fed")
			mountain_creature_openmouth = mountain_creature_fed
			mountain_creature_symbol_thrown = mountain_creature_fed
	print("Inventory after removal:", inventory_items)
	_refresh_inventory_ui()


func has_inventory_item(item_name: String) -> bool:
	return inventory_items.has(item_name)


func mark_mountain_creature_fed() -> void:
	mountain_creature_fed = true
	mountain_creature_openmouth = true
	mountain_creature_symbol_thrown = true
	if not inventory_items.has("creature_fed"):
		inventory_items.append("creature_fed")
	print("Mountain creature state saved: openmouth")


func should_restore_mountain_creature_openmouth() -> bool:
	return mountain_creature_openmouth or mountain_creature_fed or inventory_items.has("creature_fed")


func _refresh_inventory_ui() -> void:
	for node in get_tree().get_nodes_in_group("inventory_ui"):
		if node.has_method("refresh_inventory_ui"):
			node.refresh_inventory_ui()


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
	mountain_creature_visited = false
	mountain_creature_guide_done = false
	mountain_creature_symbol_thrown = false
	mountain_creature_fed = false
	mountain_creature_openmouth = false
	toadstool_puzzle_complete = false
	toadstool_slots_complete = false
	toadstool_current_step = 0
	toadstool_filled_items.clear()
	next_spawn_marker = ""
	print("Progress reset.")
	_refresh_inventory_ui()
