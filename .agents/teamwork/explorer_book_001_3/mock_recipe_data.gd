class_name MockRecipeData
extends Resource

var id: String = ""
var display_name: String = ""
var station: String = "station_kitchen_home"
var ingredients: Dictionary = {}
var source_hints: Dictionary = {}
var family_note: String = ""
var note_id: String = ""
var output_dish_id: String = "dish_sayur_bening"
var output_count: int = 1
var prep_duration: float = 4.0
var cook_duration: float = 30.0
var default_heat: String = "low"

var is_tracked: bool = false
var times_cooked: int = 0

var is_completed: bool:
	get:
		return times_cooked > 0

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

func check_can_cook(inv: Node) -> bool:
	if inv == null:
		return false
	for it_id in ingredients:
		var req: int = int(ingredients[it_id])
		if inv.get_available_item_count(it_id) < req:
			return false
	return true

func get_ingredient_status(it_id: String, inv: Node) -> Dictionary:
	var req: int = int(ingredients.get(it_id, 0))
	var hint: String = str(source_hints.get(it_id, ""))
	var avail: int = 0
	if inv != null:
		avail = inv.get_available_item_count(it_id)
	return {
		"item_id": it_id,
		"required": req,
		"available": avail,
		"satisfied": avail >= req,
		"hint": hint
	}
