class_name RecipeData
extends Resource

## Definisi Data Resep Statis & Status Progres untuk Buku Resep 2045
## Mengikuti spesifikasi resmi docs/CONTENT.md § 4, PRD FR03/FR04, dan TEST_PLAN T01..T03, T11, T31

@export var id: String = ""
@export var display_name: String = ""
@export var station: String = "station_kitchen_home"
@export var ingredients: Dictionary = {} # item_id: String -> count: int
@export var source_hints: Dictionary = {} # item_id: String -> hint_text: String
@export var family_note: String = ""
@export var note_id: String = ""
@export var output_dish_id: String = "dish_sayur_bening"
@export var output_count: int = 1
@export var prep_duration: float = 4.0
@export var cook_duration: float = 30.0
@export var default_heat: String = "low"

# Dynamic runtime progress properties
var is_tracked: bool = false
var times_cooked: int = 0

var is_completed: bool:
	get:
		return times_cooked > 0

var can_cook: bool:
	get:
		return check_can_cook()

var name: String:
	get:
		return display_name
	set(val):
		display_name = val

func _init(
	p_id: String = "",
	p_name: String = "",
	p_station: String = "station_kitchen_home",
	p_ingredients: Dictionary = {},
	p_hints: Dictionary = {},
	p_note: String = "",
	p_note_id: String = "",
	p_output_id: String = "dish_sayur_bening",
	p_output_count: int = 1
) -> void:
	id = p_id
	display_name = p_name
	station = p_station
	ingredients = p_ingredients.duplicate(true)
	source_hints = p_hints.duplicate(true)
	family_note = p_note
	note_id = p_note_id
	output_dish_id = p_output_id
	output_count = p_output_count
	is_tracked = false
	times_cooked = 0

func check_can_cook(inventory_mgr: Node = null) -> bool:
	var inv = inventory_mgr
	if inv == null:
		if Engine.has_singleton("InventoryManager"):
			inv = Engine.get_singleton("InventoryManager")
		elif Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root != null:
			inv = Engine.get_main_loop().root.get_node_or_null("InventoryManager")

	if inv == null:
		return false

	for item_id in ingredients:
		var req_count: int = int(ingredients[item_id])
		var available: int = 0
		if inv.has_method("get_available_item_count"):
			available = inv.get_available_item_count(item_id)
		if available < req_count:
			return false
	return true

func get_ingredient_status(item_id: String, inventory_mgr: Node = null) -> Dictionary:
	var req_count: int = int(ingredients.get(item_id, 0))
	var hint: String = str(source_hints.get(item_id, ""))
	var available: int = 0

	var inv = inventory_mgr
	if inv == null and Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root != null:
		inv = Engine.get_main_loop().root.get_node_or_null("InventoryManager")

	if inv != null and inv.has_method("get_available_item_count"):
		available = inv.get_available_item_count(item_id)

	return {
		"item_id": item_id,
		"required": req_count,
		"available": available,
		"satisfied": available >= req_count,
		"hint": hint
	}

func get_all_ingredients_status(inventory_mgr: Node = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in ingredients:
		result.append(get_ingredient_status(item_id, inventory_mgr))
	return result
