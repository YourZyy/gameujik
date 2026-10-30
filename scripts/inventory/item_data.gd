class_name ItemData
extends Resource

## Definisi data item statis (read-only template) untuk Buku Resep 2045
## Mengikuti spesifikasi docs/CONTENT.md § 2

@export var id: String = ""
@export var display_name: String = ""
@export var category: String = "" # "seed", "ingredient", "care", "dish", "resource"
@export var max_stack: int = 20
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var icon_color: Color = Color(0.5, 0.5, 0.5)

# Alias property untuk fleksibilitas akses
var name: String:
	get:
		return display_name
	set(val):
		display_name = val

func _init(
	p_id: String = "",
	p_name: String = "",
	p_category: String = "",
	p_max_stack: int = 20,
	p_desc: String = "",
	p_icon: Texture2D = null,
	p_color: Color = Color(0.5, 0.5, 0.5)
) -> void:
	id = p_id
	display_name = p_name
	category = p_category
	max_stack = p_max_stack
	description = p_desc
	icon = p_icon
	icon_color = p_color

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"display_name": display_name,
		"category": category,
		"max_stack": max_stack,
		"description": description,
		"icon_color": icon_color.to_html()
	}

static func from_dict(data: Dictionary) -> Resource:
	var col_str := str(data.get("icon_color", "808080"))
	var col := Color.from_string(col_str, Color(0.5, 0.5, 0.5))
	var name_val := str(data.get("display_name", data.get("name", "")))
	var script_res = load("res://scripts/inventory/item_data.gd")
	return script_res.new(
		str(data.get("id", "")),
		name_val,
		str(data.get("category", "")),
		int(data.get("max_stack", 20)),
		str(data.get("description", "")),
		null,
		col
	)
