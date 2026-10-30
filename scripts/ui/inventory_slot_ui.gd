class_name InventorySlotUI
extends Button

## Komponen tombol slot inventaris
## Menampilkan ikon/warna, nama, dan jumlah tumpukan secara dinamis

var slot_index: int = -1
var container_type: String = "backpack"
var current_item_id: String = ""
var current_count: int = 0

@onready var color_fallback: ColorRect = get_node_or_null("ColorFallback")
@onready var icon_rect: TextureRect = get_node_or_null("IconRect")
@onready var count_label: Label = get_node_or_null("CountLabel")

func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	focus_mode = Control.FOCUS_ALL
	_ensure_child_nodes()

func _ensure_child_nodes() -> void:
	if color_fallback == null:
		color_fallback = ColorRect.new()
		color_fallback.name = "ColorFallback"
		color_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		color_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		color_fallback.offset_left = 8
		color_fallback.offset_top = 8
		color_fallback.offset_right = -8
		color_fallback.offset_bottom = -8
		color_fallback.visible = false
		add_child(color_fallback)

	if icon_rect == null:
		icon_rect = TextureRect.new()
		icon_rect.name = "IconRect"
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.offset_left = 6
		icon_rect.offset_top = 6
		icon_rect.offset_right = -6
		icon_rect.offset_bottom = -6
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.visible = false
		add_child(icon_rect)

	if count_label == null:
		count_label = Label.new()
		count_label.name = "CountLabel"
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count_label.offset_left = -30
		count_label.offset_top = -22
		count_label.offset_right = -4
		count_label.offset_bottom = -2
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_label.add_theme_font_size_override("font_size", 14)
		count_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		count_label.add_theme_constant_override("outline_size", 3)
		count_label.visible = false
		add_child(count_label)

func set_slot_data(item_id: String, count: int, item_data: Variant = null) -> void:
	_ensure_child_nodes()
	current_item_id = item_id
	current_count = count

	if count <= 0 or item_id.is_empty():
		text = ""
		tooltip_text = "Slot Kosong"
		if color_fallback:
			color_fallback.visible = false
		if icon_rect:
			icon_rect.visible = false
		if count_label:
			count_label.visible = false
		return

	var display_name := item_id
	var col := Color(0.5, 0.5, 0.5)
	var tex: Texture2D = null

	if item_data != null:
		if "display_name" in item_data:
			display_name = item_data.display_name
		elif "name" in item_data:
			display_name = item_data.name
		if "icon_color" in item_data and item_data.icon_color is Color:
			col = item_data.icon_color
		if "icon" in item_data and item_data.icon is Texture2D:
			tex = item_data.icon

	tooltip_text = "%s (x%d)" % [display_name, count]

	if tex != null:
		if icon_rect:
			icon_rect.texture = tex
			icon_rect.visible = true
		if color_fallback:
			color_fallback.visible = false
		text = ""
	else:
		if icon_rect:
			icon_rect.visible = false
		if color_fallback:
			color_fallback.color = col
			color_fallback.visible = true
		# Fallback text in button
		text = display_name.substr(0, 4)

	if count_label:
		count_label.text = str(count)
		count_label.visible = (count > 1)
