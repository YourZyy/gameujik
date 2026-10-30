class_name InventoryUI
extends CanvasLayer

## Kontroler Antarmuka Inventaris (Tas & Peti) untuk Buku Resep 2045
## Mengikuti spesifikasi UI_UX.md UI04, PROTOTYPE.md § 5/6, dan skill game-ui-ux / godot-ui-control

enum ViewMode {
	SOLO,   # Hanya tas (saat dibuka via tombol Tab)
	DUAL    # Tas dan Peti penyimpanan (saat E pada storage_home)
}

@onready var root_control: Control = $RootControl
@onready var main_panel: PanelContainer = $RootControl/CenterContainer/MainPanel
@onready var backpack_grid: GridContainer = $RootControl/CenterContainer/MainPanel/Margin/VBox/ContentHBox/BackpackSection/BackpackGrid
@onready var storage_section: VBoxContainer = $RootControl/CenterContainer/MainPanel/Margin/VBox/ContentHBox/StorageSection
@onready var storage_grid: GridContainer = $RootControl/CenterContainer/MainPanel/Margin/VBox/ContentHBox/StorageSection/StorageGrid
@onready var backpack_capacity_label: Label = $RootControl/CenterContainer/MainPanel/Margin/VBox/ContentHBox/BackpackSection/SectionHeader/BackpackCapacityLabel
@onready var storage_capacity_label: Label = $RootControl/CenterContainer/MainPanel/Margin/VBox/ContentHBox/StorageSection/SectionHeader/StorageCapacityLabel
@onready var detail_name_label: Label = $RootControl/CenterContainer/MainPanel/Margin/VBox/DetailPanel/DetailMargin/DetailHBox/DetailTextVBox/DetailNameLabel
@onready var detail_desc_label: Label = $RootControl/CenterContainer/MainPanel/Margin/VBox/DetailPanel/DetailMargin/DetailHBox/DetailTextVBox/DetailDescLabel
@onready var detail_icon: Control = $RootControl/CenterContainer/MainPanel/Margin/VBox/DetailPanel/DetailMargin/DetailHBox/DetailIcon
@onready var status_label: Label = $RootControl/CenterContainer/MainPanel/Margin/VBox/StatusLabel
@onready var close_button: Button = $RootControl/CenterContainer/MainPanel/Margin/VBox/HeaderHBox/CloseButton

# Tombol Aksi Transfer & Konsumsi
@onready var btn_transfer_sel_to_storage: Button = $RootControl/CenterContainer/MainPanel/Margin/VBox/ContentHBox/BackpackSection/BackpackActions/BtnTransferSelectedToStorage
@onready var btn_transfer_all_to_storage: Button = $RootControl/CenterContainer/MainPanel/Margin/VBox/ContentHBox/BackpackSection/BackpackActions/BtnTransferAllToStorage
@onready var btn_transfer_sel_to_backpack: Button = $RootControl/CenterContainer/MainPanel/Margin/VBox/ContentHBox/StorageSection/StorageActions/BtnTransferSelectedToBackpack
@onready var btn_transfer_all_to_backpack: Button = $RootControl/CenterContainer/MainPanel/Margin/VBox/ContentHBox/StorageSection/StorageActions/BtnTransferAllToBackpack
@onready var btn_eat_dish: Button = find_child("BtnEatDish", true, false) as Button

var current_mode: ViewMode = ViewMode.SOLO
var selected_container: String = "backpack"
var selected_slot_index: int = -1
var _confirming_eat: bool = false

var backpack_slot_nodes: Array[Button] = []
var storage_slot_nodes: Array[Button] = []

func _ready() -> void:
	visible = false
	_create_or_bind_slots()
	_connect_signals()

	# Hubungkan dengan InputManager jika ada di SceneTree
	var im := _get_input_manager()
	if im != null:
		if im.has_signal("context_changed"):
			im.context_changed.connect(_on_context_changed)

func _create_or_bind_slots() -> void:
	backpack_slot_nodes.clear()
	storage_slot_nodes.clear()

	if backpack_grid:
		for child in backpack_grid.get_children():
			if child is Button:
				var idx := backpack_slot_nodes.size()
				backpack_slot_nodes.append(child)
				child.pressed.connect(func(): _on_slot_clicked("backpack", idx))
				child.focus_entered.connect(func(): _on_slot_clicked("backpack", idx))

	if storage_grid:
		for child in storage_grid.get_children():
			if child is Button:
				var idx := storage_slot_nodes.size()
				storage_slot_nodes.append(child)
				child.pressed.connect(func(): _on_slot_clicked("storage", idx))
				child.focus_entered.connect(func(): _on_slot_clicked("storage", idx))

func _connect_signals() -> void:
	if close_button and not close_button.pressed.is_connected(close_ui):
		close_button.pressed.connect(close_ui)

	if btn_transfer_sel_to_storage:
		btn_transfer_sel_to_storage.pressed.connect(func(): _transfer_selected("backpack", "storage"))
	if btn_transfer_all_to_storage:
		btn_transfer_all_to_storage.pressed.connect(func(): _transfer_all("backpack", "storage"))
	if btn_transfer_sel_to_backpack:
		btn_transfer_sel_to_backpack.pressed.connect(func(): _transfer_selected("storage", "backpack"))
	if btn_transfer_all_to_backpack:
		btn_transfer_all_to_backpack.pressed.connect(func(): _transfer_all("storage", "backpack"))
	if btn_eat_dish and not btn_eat_dish.pressed.is_connected(_on_eat_dish_pressed):
		btn_eat_dish.pressed.connect(_on_eat_dish_pressed)

	var inv := _get_inventory_manager()
	if inv != null:
		if inv.has_signal("inventory_updated"):
			inv.inventory_updated.connect(refresh_ui)
		elif inv.has_signal("inventory_changed"):
			inv.inventory_changed.connect(func(_c): refresh_ui())
		if inv.has_signal("transaction_failed"):
			inv.transaction_failed.connect(func(reason): _show_status(reason))

func open_solo() -> void:
	current_mode = ViewMode.SOLO
	if storage_section:
		storage_section.visible = false
	visible = true
	_show_status("")
	refresh_ui()
	_select_default_slot()

func open_dual() -> void:
	current_mode = ViewMode.DUAL
	if storage_section:
		storage_section.visible = true
	visible = true
	_show_status("")
	refresh_ui()
	_select_default_slot()

func close_ui() -> void:
	visible = false
	_show_status("")
	var im := _get_input_manager()
	if im != null:
		if im.has_method("get_current_context") and im.get_current_context() == im.ContextMode.STORAGE:
			im.consume_and_close(&"open_inventory")

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if current_mode == ViewMode.SOLO and event.is_action_pressed("open_inventory") and not event.is_echo():
		close_ui()
		get_viewport().set_input_as_handled()

func _on_context_changed(new_context: int, _old_context: int) -> void:
	# ContextMode.STORAGE = 2
	if new_context == 2:
		if not visible:
			open_solo()
	else:
		if visible:
			visible = false

func refresh_ui() -> void:
	if not is_inside_tree() or not visible:
		return

	var inv := _get_inventory_manager()
	if inv == null:
		return

	_update_container_grid("backpack", backpack_slot_nodes, backpack_capacity_label)
	if current_mode == ViewMode.DUAL:
		_update_container_grid("storage", storage_slot_nodes, storage_capacity_label)

	_update_detail_panel()

func _update_container_grid(container_name: String, slot_nodes: Array[Button], cap_label: Label) -> void:
	var inv := _get_inventory_manager()
	var slots_data: Array = _get_slots_from_manager(inv, container_name)
	var used_slots := 0

	for i in range(slot_nodes.size()):
		var slot_btn := slot_nodes[i]
		if i < slots_data.size():
			var s_data: Dictionary = slots_data[i]
			var item_id: String = s_data.get("item_id", s_data.get("id", ""))
			var count: int = int(s_data.get("count", 0))

			if slot_btn.has_method("set_slot_data"):
				slot_btn.set_slot_data(item_id, count, _get_item_def(inv, item_id))
			else:
				if count > 0 and not item_id.is_empty():
					slot_btn.text = "%s\nx%d" % [_get_item_name(inv, item_id), count]
				else:
					slot_btn.text = "-"

			if count > 0 and not item_id.is_empty():
				used_slots += 1
		else:
			slot_btn.text = "-"

	if cap_label != null:
		cap_label.text = "%d/12 slot" % used_slots

func _on_slot_clicked(container: String, index: int) -> void:
	selected_container = container
	selected_slot_index = index
	_confirming_eat = false
	if btn_eat_dish != null:
		btn_eat_dish.text = "Makan [1 Porsi]"
	_update_detail_panel()

func _update_detail_panel() -> void:
	if detail_name_label == null or detail_desc_label == null:
		return

	var inv := _get_inventory_manager()
	if inv == null or selected_slot_index < 0:
		detail_name_label.text = "Pilih item untuk melihat detail"
		detail_desc_label.text = "Gunakan tombol panah atau klik mouse untuk memilih slot."
		if btn_eat_dish != null:
			btn_eat_dish.visible = false
		return

	var slots_data := _get_slots_from_manager(inv, selected_container)
	if selected_slot_index >= slots_data.size():
		if btn_eat_dish != null:
			btn_eat_dish.visible = false
		return

	var s_data: Dictionary = slots_data[selected_slot_index]
	var item_id: String = s_data.get("item_id", s_data.get("id", ""))
	var count: int = int(s_data.get("count", 0))

	if count <= 0 or item_id.is_empty():
		detail_name_label.text = "Slot Kosong"
		detail_desc_label.text = "Slot ini siap digunakan untuk menampung barang baru."
		if detail_icon is ColorRect:
			(detail_icon as ColorRect).color = Color(0.2, 0.2, 0.2, 0.5)
		if btn_eat_dish != null:
			btn_eat_dish.visible = false
	else:
		var name_str := _get_item_name(inv, item_id)
		var desc_str := _get_item_desc(inv, item_id)
		detail_name_label.text = "%s (x%d)" % [name_str, count]
		detail_desc_label.text = desc_str
		if detail_icon is ColorRect:
			(detail_icon as ColorRect).color = _get_category_color(item_id)

		if btn_eat_dish != null:
			var is_dish: bool = (selected_container == "backpack" and item_id == "dish_sayur_bening" and count > 0)
			btn_eat_dish.visible = is_dish
			if not is_dish:
				_confirming_eat = false
				btn_eat_dish.text = "Makan [1 Porsi]"

func _on_eat_dish_pressed() -> void:
	if not _confirming_eat:
		_confirming_eat = true
		if btn_eat_dish != null:
			btn_eat_dish.text = "Makan 1 porsi? [Konfirmasi]"
		return

	_confirming_eat = false
	if btn_eat_dish != null:
		btn_eat_dish.text = "Makan [1 Porsi]"

	var tree := Engine.get_main_loop() as SceneTree
	var km: Node = null
	if tree != null and tree.root != null and tree.root.has_node("KitchenManager"):
		km = tree.root.get_node("KitchenManager")
	elif Engine.has_singleton("KitchenManager"):
		km = Engine.get_singleton("KitchenManager")

	var res: Dictionary = {}
	if km != null and km.has_method("eat_dish"):
		res = km.eat_dish("dish_sayur_bening")
	else:
		var inv := _get_inventory_manager()
		if inv != null:
			var bp = inv.backpack if "backpack" in inv else null
			if bp != null and bp.has_method("remove_item"):
				bp.remove_item("dish_sayur_bening", 1)
				res = {"success": true, "message": "Hangat. Resep pertama berhasil dibuat."}

	if res.get("success", false):
		var msg: String = str(res.get("message", res.get("reason", "Hangat. Resep pertama berhasil dibuat.")))
		_show_status(msg)
		if tree != null and tree.root != null:
			var hud = tree.root.find_child("HUD", true, false)
			if hud != null and hud.has_method("show_feedback"):
				hud.show_feedback(msg, 3.0)
	else:
		_show_status(res.get("reason", "Gagal memakan hidangan."))

	refresh_ui()

func _transfer_selected(from_c: String, to_c: String) -> void:
	var inv := _get_inventory_manager()
	if inv == null: return
	if selected_container != from_c or selected_slot_index < 0:
		_show_status("Pilih slot di kontainer asal terlebih dahulu!")
		return

	var res: Dictionary = {}
	if inv.has_method("transfer_slot"):
		res = inv.transfer_slot(from_c, to_c, selected_slot_index)
	elif inv.has_method("transfer_item"):
		var slots_data := _get_slots_from_manager(inv, from_c)
		var item_id: String = slots_data[selected_slot_index].get("item_id", slots_data[selected_slot_index].get("id", ""))
		var count: int = int(slots_data[selected_slot_index].get("count", 0))
		var ok: bool = inv.transfer_item(from_c, to_c, selected_slot_index, count)
		res = {"success": ok, "reason": "" if ok else "Penyimpanan tujuan tidak mencukupi."}

	if res.get("success", false):
		_show_status("Berhasil memindahkan barang.")
	else:
		_show_status(res.get("reason", "Pemindahan ditolak."))
	refresh_ui()

func _transfer_all(from_c: String, to_c: String) -> void:
	var inv := _get_inventory_manager()
	if inv == null: return
	if inv.has_method("transfer_all"):
		var res: Dictionary = inv.transfer_all(from_c, to_c)
		if res.get("success", false):
			_show_status("Semua barang berhasil dipindahkan.")
		else:
			_show_status(res.get("reason", "Pemindahan ditolak."))
	refresh_ui()

func _select_default_slot() -> void:
	selected_container = "backpack"
	selected_slot_index = 0
	if backpack_slot_nodes.size() > 0:
		backpack_slot_nodes[0].grab_focus()
	_update_detail_panel()

func _show_status(msg: String) -> void:
	if status_label != null:
		status_label.text = msg

func _get_inventory_manager() -> Node:
	if Engine.has_singleton("InventoryManager"):
		return Engine.get_singleton("InventoryManager")
	if has_node("/root/InventoryManager"):
		return get_node("/root/InventoryManager")
	return null

func _get_input_manager() -> Node:
	if Engine.has_singleton("InputManager"):
		return Engine.get_singleton("InputManager")
	if has_node("/root/InputManager"):
		return get_node("/root/InputManager")
	return null

func _get_slots_from_manager(inv: Node, container_name: String) -> Array:
	if inv == null: return []
	if container_name == "backpack":
		if "backpack" in inv:
			var bp = inv.backpack
			if bp is Array: return bp
			if bp.has_method("to_array"): return bp.to_array()
			if "slots" in bp: return bp.slots
		if inv.has_method("get_container_slots"):
			return inv.get_container_slots("backpack")
	else:
		if "storage_home" in inv:
			var st = inv.storage_home
			if st is Array: return st
			if st.has_method("to_array"): return st.to_array()
			if "slots" in st: return st.slots
		elif "_storage" in inv:
			return inv._storage
		if inv.has_method("get_container_slots"):
			return inv.get_container_slots("storage")
	return []

func _get_item_name(inv: Node, item_id: String) -> String:
	var item = _get_item_def(inv, item_id)
	if item != null:
		if "display_name" in item:
			return item.display_name
		elif "name" in item:
			return item.name
	return item_id.capitalize()

func _get_item_desc(inv: Node, item_id: String) -> String:
	var item = _get_item_def(inv, item_id)
	if item != null and "description" in item:
		return item.description
	return "Item keperluan petak dan memasak."

func _get_item_def(inv: Node, item_id: String) -> Variant:
	if inv == null: return null
	if "item_registry" in inv and inv.item_registry != null:
		return inv.item_registry.get_item(item_id)
	if inv.has_method("get_item_data"):
		return inv.get_item_data(item_id)
	return null

func _get_category_color(item_id: String) -> Color:
	match item_id:
		"seed_bayam": return Color(0.4, 0.8, 0.3)
		"ingredient_bayam", "crop_bayam": return Color(0.2, 0.7, 0.2)
		"ingredient_jagung": return Color(0.95, 0.8, 0.2)
		"ingredient_temu_kunci": return Color(0.8, 0.5, 0.25)
		"fertilizer_basic", "tool_fertilizer": return Color(0.5, 0.35, 0.2)
		"soil_compost": return Color(0.35, 0.25, 0.15)
		"water_fresh": return Color(0.3, 0.6, 0.9)
		"dish_sayur_bening": return Color(0.85, 0.45, 0.25)
		_: return Color(0.5, 0.5, 0.5)
