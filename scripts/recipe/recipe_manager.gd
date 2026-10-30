extends Node

## Autoload Singleton RecipeManager untuk Buku Resep 2045
## Mengelola Katalog Resep, Status Pelacakan Tracker HUD, Registri Catatan, dan Snapshot Simpan
## Memenuhi spesifikasi PRD FR03/FR04, CONTENT.md § 4, § 10, § 12, dan TEST_PLAN T01..T03, T11, T31

signal recipe_tracked(recipe_id: String)
signal recipe_untracked(recipe_id: String)
signal recipe_updated(recipe_id: String)
signal recipe_completed(recipe_id: String)
signal note_unlocked(note_id: String, text: String)
signal cooking_state_changed(new_state: String)

const RecipeDataClass = preload("res://scripts/recipe/recipe_data.gd")
const RecipesDataClass = preload("res://scripts/recipe/recipes_data.gd")

var _recipes: Dictionary = {} # recipe_id: String -> RecipeData
var _notes: Dictionary = {} # note_id: String -> Dictionary
var tracked_recipe_id: String = ""
var cooking_state: String = "idle" # idle, preparing, cooking, paused, output_ready

var _inventory_override: Node = null

func _ready() -> void:
	_register_default_p0_recipes()
	_register_default_notes()
	_connect_inventory_signals()

func set_inventory_manager(inv: Node) -> void:
	_inventory_override = inv
	if _inventory_override != null and _inventory_override.has_signal("inventory_updated"):
		if not _inventory_override.inventory_updated.is_connected(_on_inventory_updated):
			_inventory_override.inventory_updated.connect(_on_inventory_updated)

func _get_inventory() -> Node:
	if _inventory_override != null and is_instance_valid(_inventory_override):
		return _inventory_override
	if Engine.has_singleton("InventoryManager"):
		return Engine.get_singleton("InventoryManager")
	if has_node("/root/InventoryManager"):
		return get_node("/root/InventoryManager")
	return null

func _connect_inventory_signals() -> void:
	var inv := _get_inventory()
	if inv != null and inv.has_signal("inventory_updated"):
		if not inv.inventory_updated.is_connected(_on_inventory_updated):
			inv.inventory_updated.connect(_on_inventory_updated)

func _on_inventory_updated() -> void:
	for r_id in _recipes:
		recipe_updated.emit(r_id)

func _register_default_p0_recipes() -> void:
	var r_sayur_bening = RecipesDataClass.create_sayur_bening_recipe()
	register_recipe(r_sayur_bening)

func _register_default_notes() -> void:
	var default_notes := RecipesDataClass.get_default_notes()
	for note_dict in default_notes:
		register_note(
			str(note_dict.get("id", "")),
			str(note_dict.get("title", "")),
			str(note_dict.get("text", "")),
			bool(note_dict.get("default_unlocked", false))
		)

# --- Catalog API ---

func register_recipe(recipe: Resource) -> void:
	if recipe == null:
		return
	var r_id: String = str(recipe.get("id"))
	if r_id.is_empty():
		return
	_recipes[r_id] = recipe

func get_recipe(recipe_id: String) -> Resource:
	if _recipes.has(recipe_id):
		return _recipes[recipe_id]
	return null

func has_recipe(recipe_id: String) -> bool:
	return _recipes.has(recipe_id)

func get_all_recipes() -> Array:
	var list: Array = []
	for k in _recipes:
		list.append(_recipes[k])
	return list

# --- Tracking API ---

func track_recipe(recipe_id: String) -> bool:
	if not _recipes.has(recipe_id):
		return false
	
	var old_tracked := tracked_recipe_id
	if old_tracked == recipe_id:
		return true

	if not old_tracked.is_empty() and _recipes.has(old_tracked):
		_recipes[old_tracked].is_tracked = false
		recipe_untracked.emit(old_tracked)

	tracked_recipe_id = recipe_id
	_recipes[recipe_id].is_tracked = true
	recipe_tracked.emit(recipe_id)
	recipe_updated.emit(recipe_id)
	return true

func untrack_recipe(recipe_id: String = "") -> bool:
	var target_id := recipe_id if not recipe_id.is_empty() else tracked_recipe_id
	if target_id.is_empty():
		return false
	
	if target_id == tracked_recipe_id:
		tracked_recipe_id = ""
	
	if _recipes.has(target_id):
		_recipes[target_id].is_tracked = false
		recipe_untracked.emit(target_id)
		recipe_updated.emit(target_id)
		return true
	return false

func toggle_tracking(recipe_id: String) -> bool:
	if is_recipe_tracked(recipe_id):
		untrack_recipe(recipe_id)
		return false
	else:
		track_recipe(recipe_id)
		return true

func is_recipe_tracked(recipe_id: String) -> bool:
	return tracked_recipe_id == recipe_id and not recipe_id.is_empty()

func get_tracked_recipe() -> Resource:
	if tracked_recipe_id.is_empty():
		return null
	return get_recipe(tracked_recipe_id)

# --- Inventory & Cooking Queries ---

func get_available_ingredient_count(item_id: String) -> int:
	var inv := _get_inventory()
	if inv != null and inv.has_method("get_available_item_count"):
		return inv.get_available_item_count(item_id)
	return 0

func can_cook_recipe(recipe_id: String) -> bool:
	var recipe = get_recipe(recipe_id)
	if recipe == null:
		return false
	if recipe.has_method("check_can_cook"):
		return recipe.check_can_cook(_get_inventory())
	return false

func are_ingredients_complete(recipe_id: String = "") -> bool:
	var target_id := recipe_id if not recipe_id.is_empty() else tracked_recipe_id
	if target_id.is_empty():
		target_id = RecipesDataClass.ID_RECIPE_SAYUR_BENING
	return can_cook_recipe(target_id)

func record_recipe_cooked(recipe_id: String) -> void:
	var recipe = get_recipe(recipe_id)
	if recipe == null:
		return
	
	var prev_times: int = int(recipe.times_cooked)
	recipe.times_cooked = prev_times + 1
	if prev_times == 0:
		recipe_completed.emit(recipe_id)
	recipe_updated.emit(recipe_id)

func mark_recipe_completed(recipe_id: String) -> void:
	record_recipe_cooked(recipe_id)

func is_recipe_completed(recipe_id: String) -> bool:
	var recipe = get_recipe(recipe_id)
	if recipe != null:
		return int(recipe.times_cooked) > 0
	return false

func set_cooking_state(state: String) -> void:
	if cooking_state != state:
		cooking_state = state
		cooking_state_changed.emit(cooking_state)
		if not tracked_recipe_id.is_empty():
			recipe_updated.emit(tracked_recipe_id)

func get_cooking_state() -> String:
	return cooking_state

# --- Notes Registry API ---

func register_note(note_id: String, title: String, text: String, unlocked_by_default: bool = false) -> void:
	_notes[note_id] = {
		"id": note_id,
		"title": title,
		"text": text,
		"is_unlocked": unlocked_by_default,
		"default_unlocked": unlocked_by_default
	}

func unlock_note(note_id: String) -> bool:
	if not _notes.has(note_id):
		return false
	if _notes[note_id]["is_unlocked"]:
		return false
	_notes[note_id]["is_unlocked"] = true
	note_unlocked.emit(note_id, _notes[note_id]["text"])
	return true

func is_note_unlocked(note_id: String) -> bool:
	if _notes.has(note_id):
		return _notes[note_id].get("is_unlocked", false)
	return false

func get_note(note_id: String) -> Dictionary:
	if _notes.has(note_id):
		return _notes[note_id].duplicate(true)
	return {}

func get_unlocked_notes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for note_id in _notes:
		if _notes[note_id].get("is_unlocked", false):
			result.append(_notes[note_id].duplicate(true))
	return result

func get_all_notes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for note_id in _notes:
		result.append(_notes[note_id].duplicate(true))
	return result

# --- Persistence Snapshot API (SAVE-001) ---

func get_save_snapshot() -> Dictionary:
	var recipes_data: Dictionary = {}
	for r_id in _recipes:
		var r = _recipes[r_id]
		recipes_data[r_id] = {
			"times_cooked": int(r.get("times_cooked")),
			"is_tracked": bool(r.get("is_tracked")),
			"discovered": true
		}

	var unlocked_notes_list: Array[String] = []
	for n_id in _notes:
		if _notes[n_id].get("is_unlocked", false):
			unlocked_notes_list.append(n_id)

	return {
		"version": 1,
		"tracked_recipe_id": tracked_recipe_id,
		"cooking_state": cooking_state,
		"recipes": recipes_data,
		"unlocked_notes": unlocked_notes_list
	}

func load_save_snapshot(data: Dictionary) -> bool:
	if not data is Dictionary or data.is_empty():
		return false
	if not data.has("version") and not data.has("recipes"):
		return false

	tracked_recipe_id = str(data.get("tracked_recipe_id", ""))
	cooking_state = str(data.get("cooking_state", "idle"))

	var recipes_data: Dictionary = data.get("recipes", {})
	for r_id in recipes_data:
		var r_save: Dictionary = recipes_data[r_id]
		if _recipes.has(r_id):
			var r = _recipes[r_id]
			r.set("times_cooked", int(r_save.get("times_cooked", 0)))
			r.set("is_tracked", (r_id == tracked_recipe_id))

	var unlocked_list: Array = data.get("unlocked_notes", [])
	for n_id in _notes:
		if n_id in unlocked_list:
			_notes[n_id]["is_unlocked"] = true
		elif not _notes[n_id].get("default_unlocked", false):
			_notes[n_id]["is_unlocked"] = false

	for r_id in _recipes:
		recipe_updated.emit(r_id)
	if not tracked_recipe_id.is_empty():
		recipe_tracked.emit(tracked_recipe_id)
	else:
		recipe_untracked.emit("")

	return true
