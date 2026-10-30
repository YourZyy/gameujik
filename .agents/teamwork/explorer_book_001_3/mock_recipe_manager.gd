class_name MockRecipeManager
extends Node

signal recipe_tracked(recipe_id: String)
signal recipe_untracked(recipe_id: String)
signal recipe_updated(recipe_id: String)
signal recipe_completed(recipe_id: String)
signal note_unlocked(note_id: String, text: String)

const MockRecipeDataClass = preload("res://.agents/teamwork/explorer_book_001_3/mock_recipe_data.gd")

var _recipes: Dictionary = {}
var _notes: Dictionary = {}
var tracked_recipe_id: String = ""
var _inventory_override: Node = null

func _ready() -> void:
	_register_default_p0_recipes()
	_register_default_notes()

func set_inventory_manager(inv: Node) -> void:
	_inventory_override = inv
	if _inventory_override != null and _inventory_override.has_signal("inventory_updated"):
		if not _inventory_override.inventory_updated.is_connected(_on_inventory_updated):
			_inventory_override.inventory_updated.connect(_on_inventory_updated)

func _get_inventory() -> Node:
	if _inventory_override != null and is_instance_valid(_inventory_override):
		return _inventory_override
	if has_node("/root/InventoryManager"):
		return get_node("/root/InventoryManager")
	return null

func _on_inventory_updated() -> void:
	for r_id in _recipes:
		recipe_updated.emit(r_id)

func _register_default_p0_recipes() -> void:
	var r = MockRecipeDataClass.new(
		"recipe_sayur_bening_01",
		"Sayur Bening Bayam dan Jagung",
		"station_kitchen_home",
		{
			"ingredient_bayam": 3,
			"ingredient_jagung": 1,
			"ingredient_temu_kunci": 1
		},
		{
			"ingredient_bayam": "Benih ada di wadah dekat alat. Siapkan petak di pekarangan, lalu tanam.",
			"ingredient_jagung": "Cari sisa kebun keluarga di ujung jalan, dekat pagar miring.",
			"ingredient_temu_kunci": "Periksa tanaman di tepi rumpun bambu, dekat batu besar."
		},
		"Bayam paling enak dipetik dekat waktu memasak. Jagung di kebun ujung jalan mungkin masih bisa dipanen. Temu kunci tumbuh di tepi bambu, dekat batu besar.",
		"note_garden_01",
		"dish_sayur_bening",
		1
	)
	register_recipe(r)

func _register_default_notes() -> void:
	register_note(
		"recipe_note_sayur_bening",
		"Catatan Resep Keluarga",
		"Bayam paling enak dipetik dekat waktu memasak. Jagung di kebun ujung jalan mungkin masih bisa dipanen. Temu kunci tumbuh di tepi bambu, dekat batu besar.",
		true
	)
	register_note(
		"note_garden_01",
		"Catatan Kebun Ujung Jalan",
		"Pagar boleh miring. Jangan sampai lupa jalan pulang.",
		false
	)
	register_note(
		"sign_food_01",
		"Papan Program Pangan",
		"Kawasan Pangan Masa Depan — Tahap Pemeliharaan",
		false
	)

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

func is_recipe_tracked(recipe_id: String) -> bool:
	return tracked_recipe_id == recipe_id

func get_tracked_recipe() -> Resource:
	if tracked_recipe_id.is_empty():
		return null
	return get_recipe(tracked_recipe_id)

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

func record_recipe_cooked(recipe_id: String) -> void:
	var recipe = get_recipe(recipe_id)
	if recipe == null:
		return
	var prev_times: int = int(recipe.times_cooked)
	recipe.times_cooked = prev_times + 1
	if prev_times == 0:
		recipe_completed.emit(recipe_id)
	recipe_updated.emit(recipe_id)

func is_recipe_completed(recipe_id: String) -> bool:
	var recipe = get_recipe(recipe_id)
	if recipe != null:
		return int(recipe.times_cooked) > 0
	return false

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
		"recipes": recipes_data,
		"unlocked_notes": unlocked_notes_list
	}

func load_save_snapshot(data: Dictionary) -> bool:
	if not data is Dictionary or data.is_empty():
		return false
	tracked_recipe_id = str(data.get("tracked_recipe_id", ""))
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
