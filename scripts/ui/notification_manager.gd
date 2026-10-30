class_name NotificationManager
extends CanvasLayer

## NotificationManager — Sistem Notifikasi Toast Jujur (Honest Notifications)
## Memenuhi spesifikasi UI_UX.md § 5, § 6, CONTENT.md § 11, PRD FR16, FR21, dan TEST_PLAN T54

signal toast_displayed(message: String, type: String)
signal toast_dismissed(message: String)

const MAX_VISIBLE_TOASTS: int = 2
const DEFAULT_DURATION: float = 2.5
const ERROR_DEBOUNCE_TIME: float = 1.2

static var instance: NotificationManager = null

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

@onready var toast_container: Control = $ToastContainer if has_node("ToastContainer") else null
@onready var toast_vbox: VBoxContainer = find_child("ToastVBox", true, false) as VBoxContainer

# Data model for active and queued toasts
# Each entry: {
#   "message": String,
#   "type": String, # "info", "success", "error", "pickup"
#   "duration": float,
#   "time_left": float,
#   "item_id": String,
#   "quantity": int,
#   "panel": PanelContainer,
#   "label": Label
# }
var _active_toasts: Array[Dictionary] = []
var _pending_queue: Array[Dictionary] = []
var _error_timestamps: Dictionary = {}
var _game_time: float = 0.0

func _ready() -> void:
	layer = 15
	if toast_container != null:
		toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if toast_vbox != null:
		toast_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Bersihkan placeholder statis jika ada
		for child in toast_vbox.get_children():
			child.queue_free()

func _process(delta: float) -> void:
	_game_time += delta
	advance_time(delta)

func advance_time(delta: float) -> void:
	var to_remove: Array[int] = []
	for i in range(_active_toasts.size()):
		var toast: Dictionary = _active_toasts[i]
		toast["time_left"] -= delta
		var panel: PanelContainer = toast.get("panel", null)
		if panel != null and is_instance_valid(panel):
			# Smooth fadeout in the last 0.4 seconds
			if toast["time_left"] <= 0.4:
				panel.modulate.a = clampf(toast["time_left"] / 0.4, 0.0, 1.0)
			else:
				panel.modulate.a = 1.0

		if toast["time_left"] <= 0.0:
			to_remove.append(i)

	# Remove from back to front
	to_remove.reverse()
	for idx in to_remove:
		_dismiss_toast_at(idx)

	# Pop from queue if slots are available
	while _active_toasts.size() < MAX_VISIBLE_TOASTS and not _pending_queue.is_empty():
		var next_toast: Dictionary = _pending_queue.pop_front()
		_spawn_toast_node(next_toast)

func show_toast(message: String, type: String = "info", duration: float = DEFAULT_DURATION, item_id: String = "") -> void:
	var entry: Dictionary = {
		"message": message,
		"type": type,
		"duration": duration,
		"time_left": duration,
		"item_id": item_id,
		"quantity": 1,
		"panel": null,
		"label": null
	}

	if _active_toasts.size() >= MAX_VISIBLE_TOASTS:
		_pending_queue.append(entry)
	else:
		_spawn_toast_node(entry)

func show_pickup(item_name: String, quantity: int = 1, item_id: String = "") -> void:
	var target_id: String = item_id if not item_id.is_empty() else item_name

	# Check for rapid pickup merging
	for toast in _active_toasts:
		if toast["type"] == "pickup" and toast["item_id"] == target_id:
			toast["quantity"] += quantity
			toast["time_left"] = DEFAULT_DURATION
			toast["message"] = "Memetik %s (x%d)" % [item_name, toast["quantity"]]
			var label: Label = toast.get("label", null)
			if label != null and is_instance_valid(label):
				label.text = toast["message"]
			var panel: PanelContainer = toast.get("panel", null)
			if panel != null and is_instance_valid(panel):
				panel.modulate.a = 1.0
			return

	# Also check pending queue if it's there
	for toast in _pending_queue:
		if toast["type"] == "pickup" and toast["item_id"] == target_id:
			toast["quantity"] += quantity
			toast["message"] = "Memetik %s (x%d)" % [item_name, toast["quantity"]]
			return

	# Otherwise spawn new pickup toast
	var msg: String = "Memetik %s" % item_name if quantity == 1 else "Memetik %s (x%d)" % [item_name, quantity]
	var entry: Dictionary = {
		"message": msg,
		"type": "pickup",
		"duration": DEFAULT_DURATION,
		"time_left": DEFAULT_DURATION,
		"item_id": target_id,
		"quantity": quantity,
		"panel": null,
		"label": null
	}

	if _active_toasts.size() >= MAX_VISIBLE_TOASTS:
		_pending_queue.append(entry)
	else:
		_spawn_toast_node(entry)

func show_error(reason: String, debounce_sec: float = ERROR_DEBOUNCE_TIME) -> void:
	var last_time: float = float(_error_timestamps.get(reason, -100.0))
	if _game_time - last_time < debounce_sec:
		# Silent debounce to prevent spamming
		return

	_error_timestamps[reason] = _game_time
	show_toast(reason, "error", DEFAULT_DURATION, "")

func show_honest_message(context_key: String) -> void:
	match context_key:
		"bag_full":
			show_error("Tas tidak cukup. Kosongkan slot atau simpan barang di rumah.")
		"storage_full":
			show_error("Penyimpanan tidak cukup. Tidak ada barang yang dipindahkan.")
		"soil_not_ready":
			show_error("Gemburkan tanah dan tambahkan pembenah dahulu.")
		"seeds_empty":
			show_error("Benih belum tersedia. Periksa wadah dekat alat.")
		"soil_dry":
			show_toast("Pertumbuhan berhenti sementara. Siram petak.", "info")
		"soil_nutrient_low":
			show_toast("Pertumbuhan berhenti sementara. Tambahkan pupuk.", "info")
		"plot_optimal":
			show_toast("Petak sudah cukup. Tidak ada bahan yang digunakan.", "info")
		"kitchen_ingredients_missing":
			show_error("Bahan belum lengkap. Buka buku untuk melihat sumbernya.")
		"kitchen_output_occupied":
			show_error("Ambil hidangan sebelumnya dahulu.")
		"kitchen_paused":
			show_toast("Masakan dijeda. Buka dapur untuk melanjutkan.", "info")
		"save_success":
			show_toast("Progres tersimpan.", "success")
		"save_failed":
			show_error("Progres belum tersimpan. Coba lagi atau gunakan lokasi simpan yang dapat ditulis.")
		"save_incompatible":
			show_error("Data simpan tidak cocok dengan versi ini. Pilih cadangan yang tersedia.")
		"p0_completed":
			show_toast("Satu resep selesai. Kebun ini baru dimulai.", "success", 4.0)
		_:
			show_toast(context_key, "info")

func _spawn_toast_node(toast_data: Dictionary) -> void:
	_active_toasts.append(toast_data)

	if toast_vbox != null:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.custom_minimum_size = Vector2(280, 44)

		# Styling
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.14, 0.18, 0.92)
		style.set_corner_radius_all(6)
		style.border_width_left = 4
		style.content_margin_left = 12
		style.content_margin_top = 8
		style.content_margin_right = 12
		style.content_margin_bottom = 8

		match toast_data["type"]:
			"error":
				style.border_color = Color(0.95, 0.35, 0.25, 1.0) # Amber / Red
			"success":
				style.border_color = Color(0.35, 0.85, 0.35, 1.0) # Green
			"pickup":
				style.border_color = Color(0.40, 0.75, 1.0, 1.0) # Soft blue
			_:
				style.border_color = Color(0.85, 0.75, 0.35, 1.0) # Warm gold

		panel.add_theme_stylebox_override("panel", style)

		var lbl := Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.text = toast_data["message"]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size = Vector2(256, 0)
		lbl.add_theme_font_size_override("font_size", 16)
		panel.add_child(lbl)

		toast_data["panel"] = panel
		toast_data["label"] = lbl

		toast_vbox.add_child(panel)

	toast_displayed.emit(toast_data["message"], toast_data["type"])

func _dismiss_toast_at(index: int) -> void:
	if index < 0 or index >= _active_toasts.size():
		return
	var toast: Dictionary = _active_toasts[index]
	_active_toasts.remove_at(index)

	var panel: PanelContainer = toast.get("panel", null)
	if panel != null and is_instance_valid(panel):
		panel.queue_free()

	toast_dismissed.emit(toast["message"])

func get_visible_toast_count() -> int:
	return _active_toasts.size()

func get_active_toast_text(index: int) -> String:
	if index >= 0 and index < _active_toasts.size():
		return _active_toasts[index]["message"]
	return ""

func clear_all() -> void:
	for toast in _active_toasts:
		var panel: PanelContainer = toast.get("panel", null)
		if panel != null and is_instance_valid(panel):
			panel.queue_free()
	_active_toasts.clear()
	_pending_queue.clear()
