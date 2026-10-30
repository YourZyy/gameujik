class_name KitchenUI
extends CanvasLayer

## Kontroler Antarmuka Stasiun Dapur untuk Buku Resep 2045
## Mengelola UI Dapur, tampilan kebutuhan bahan, tombol aksi tahan 4s persiapan,
## tombol pembatalan pra-masak, serta wadah pengembalian persisten (kitchen_refund).
## Memenuhi spesifikasi UI_UX.md UI05, PROTOTYPE.md § 4, § 5, § 6.2, dan TASKS.md COOK-001.

@onready var root_control: Control = $RootControl if has_node("RootControl") else (find_child("RootControl", true, false) as Control)
@onready var main_panel: PanelContainer = find_child("MainPanel", true, false) as PanelContainer
@onready var title_label: Label = find_child("TitleLabel", true, false) as Label
@onready var close_button: Button = find_child("CloseButton", true, false) as Button

# Recipe Summary
@onready var recipe_title_label: Label = find_child("RecipeTitleLabel", true, false) as Label
@onready var station_desc_label: Label = find_child("StationDescLabel", true, false) as Label

# Ingredients Section
@onready var ingredients_section: VBoxContainer = find_child("IngredientsSection", true, false) as VBoxContainer
@onready var bayam_label: Label = find_child("BayamLabel", true, false) as Label
@onready var jagung_label: Label = find_child("JagungLabel", true, false) as Label
@onready var temu_kunci_label: Label = find_child("TemuKunciLabel", true, false) as Label
@onready var ingredients_status_label: Label = find_child("IngredientsStatusLabel", true, false) as Label

# Preparation Section
@onready var prep_section: VBoxContainer = find_child("PreparationSection", true, false) as VBoxContainer
@onready var prep_progress_bar: ProgressBar = find_child("PrepProgressBar", true, false) as ProgressBar
@onready var prep_time_label: Label = find_child("PrepTimeLabel", true, false) as Label
@onready var hold_prep_button: Button = find_child("HoldPrepButton", true, false) as Button

# Ready Section
@onready var ready_section: VBoxContainer = find_child("ReadySection", true, false) as VBoxContainer
@onready var ready_status_label: Label = find_child("ReadyStatusLabel", true, false) as Label
@onready var start_cooking_button: Button = find_child("StartCookingButton", true, false) as Button

# Cooking Section (COOK-002)
@onready var cooking_section: VBoxContainer = find_child("CookingSection", true, false) as VBoxContainer
@onready var cooking_status_label: Label = find_child("CookingStatusLabel", true, false) as Label
@onready var cooking_progress_bar: ProgressBar = find_child("CookingProgressBar", true, false) as ProgressBar
@onready var cooking_time_label: Label = find_child("CookingTimeLabel", true, false) as Label
@onready var heat_low_button: Button = find_child("HeatLowButton", true, false) as Button
@onready var heat_med_button: Button = find_child("HeatMedButton", true, false) as Button
@onready var heat_high_button: Button = find_child("HeatHighButton", true, false) as Button
@onready var heat_warning_panel: PanelContainer = find_child("HeatWarningPanel", true, false) as PanelContainer
@onready var paused_panel: PanelContainer = find_child("PausedPanel", true, false) as PanelContainer
@onready var resume_cooking_button: Button = find_child("ResumeCookingButton", true, false) as Button

# Output Section (COOK-002)
@onready var output_section: VBoxContainer = find_child("OutputSection", true, false) as VBoxContainer
@onready var take_dish_button: Button = find_child("TakeDishButton", true, false) as Button

# Refund Section
@onready var refund_section: VBoxContainer = find_child("RefundSection", true, false) as VBoxContainer
@onready var refund_status_label: Label = find_child("RefundStatusLabel", true, false) as Label
@onready var claim_refund_button: Button = find_child("ClaimRefundButton", true, false) as Button

# Actions Footer
@onready var start_prep_button: Button = find_child("StartPrepButton", true, false) as Button
@onready var cancel_button: Button = find_child("CancelButton", true, false) as Button
@onready var feedback_label: Label = find_child("FeedbackLabel", true, false) as Label

var _is_holding: bool = false
var _kitchen_manager_override: Node = null
var _inventory_manager_override: Node = null
var _recipe_manager_override: Node = null
var _input_manager_override: Node = null

func _ready() -> void:
	visible = false

	if close_button != null:
		close_button.pressed.connect(close)
	if start_prep_button != null:
		start_prep_button.pressed.connect(_on_start_prep_pressed)
	if cancel_button != null:
		cancel_button.pressed.connect(_on_cancel_pressed)
	if claim_refund_button != null:
		claim_refund_button.pressed.connect(_on_claim_refund_pressed)
	if start_cooking_button != null:
		start_cooking_button.pressed.connect(_on_start_cooking_pressed)

	if heat_low_button != null:
		heat_low_button.pressed.connect(func(): _on_heat_button_pressed(0))
	if heat_med_button != null:
		heat_med_button.pressed.connect(func(): _on_heat_button_pressed(1))
	if heat_high_button != null:
		heat_high_button.pressed.connect(func(): _on_heat_button_pressed(2))
	if resume_cooking_button != null:
		resume_cooking_button.pressed.connect(_on_resume_cooking_pressed)
	if take_dish_button != null:
		take_dish_button.pressed.connect(_on_take_dish_pressed)

	if hold_prep_button != null:
		hold_prep_button.button_down.connect(_on_hold_button_down)
		hold_prep_button.button_up.connect(_on_hold_button_up)

	_connect_manager_signals()

func _process(delta: float) -> void:
	if not visible:
		return

	var km := _get_kitchen_manager()
	if km == null:
		return

	if _is_holding and km.has_method("advance_prep"):
		km.advance_prep(delta)
		_update_prep_display()

	if km.job_state == km.JobState.COOKING and km.has_method("advance_cooking"):
		km.advance_cooking(delta)
		_update_cooking_display()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause_menu"):
		close()
		get_viewport().set_input_as_handled()

# --- Dependency Overrides ---

func set_kitchen_manager(km: Node) -> void:
	_kitchen_manager_override = km
	_connect_manager_signals()
	refresh_ui()

func set_inventory_manager(inv: Node) -> void:
	_inventory_manager_override = inv
	refresh_ui()

func set_recipe_manager(rm: Node) -> void:
	_recipe_manager_override = rm
	refresh_ui()

func set_input_manager(im: Node) -> void:
	_input_manager_override = im
	_connect_manager_signals()

func _get_kitchen_manager() -> Node:
	if _kitchen_manager_override != null and is_instance_valid(_kitchen_manager_override):
		return _kitchen_manager_override
	if Engine.has_singleton("KitchenManager"):
		return Engine.get_singleton("KitchenManager")
	if is_inside_tree() and has_node("/root/KitchenManager"):
		return get_node("/root/KitchenManager")
	return null

func _get_inventory_manager() -> Node:
	if _inventory_manager_override != null and is_instance_valid(_inventory_manager_override):
		return _inventory_manager_override
	if Engine.has_singleton("InventoryManager"):
		return Engine.get_singleton("InventoryManager")
	if is_inside_tree() and has_node("/root/InventoryManager"):
		return get_node("/root/InventoryManager")
	return null

func _get_recipe_manager() -> Node:
	if _recipe_manager_override != null and is_instance_valid(_recipe_manager_override):
		return _recipe_manager_override
	if Engine.has_singleton("RecipeManager"):
		return Engine.get_singleton("RecipeManager")
	if is_inside_tree() and has_node("/root/RecipeManager"):
		return get_node("/root/RecipeManager")
	return null

func _get_input_manager() -> Node:
	if _input_manager_override != null and is_instance_valid(_input_override_valid()):
		return _input_manager_override
	if Engine.has_singleton("InputManager"):
		return Engine.get_singleton("InputManager")
	if is_inside_tree() and has_node("/root/InputManager"):
		return get_node("/root/InputManager")
	return null

func _input_override_valid() -> bool:
	return _input_manager_override != null and is_instance_valid(_input_manager_override)

func _connect_manager_signals() -> void:
	var km := _get_kitchen_manager()
	if km != null:
		if km.has_signal("state_changed") and not km.state_changed.is_connected(_on_kitchen_state_changed):
			km.state_changed.connect(_on_kitchen_state_changed)
		if km.has_signal("prep_completed") and not km.prep_completed.is_connected(func(_job): refresh_ui()):
			km.prep_completed.connect(func(_job): refresh_ui())
		if km.has_signal("job_cancelled") and not km.job_cancelled.is_connected(func(_job, _items): refresh_ui()):
			km.job_cancelled.connect(func(_job, _items): refresh_ui())
		if km.has_signal("refund_storage_updated") and not km.refund_storage_updated.is_connected(refresh_ui):
			km.refund_storage_updated.connect(refresh_ui)

	var inv := _get_inventory_manager()
	if inv != null and inv.has_signal("inventory_updated"):
		if not inv.inventory_updated.is_connected(refresh_ui):
			inv.inventory_updated.connect(refresh_ui)

	var im := _get_input_manager()
	if im != null and im.has_signal("context_changed"):
		if not im.context_changed.is_connected(_on_context_changed):
			im.context_changed.connect(_on_context_changed)

func _on_context_changed(new_ctx: int, _old_ctx: int) -> void:
	var im := _get_input_manager()
	if im == null:
		return
	if new_ctx == im.ContextMode.KITCHEN:
		open()
	elif visible:
		visible = false
		_is_holding = false

# --- Open / Close Controls ---

func open() -> void:
	visible = true
	_is_holding = false
	refresh_ui()
	if start_prep_button != null and start_prep_button.is_visible_in_tree() and not start_prep_button.disabled:
		start_prep_button.grab_focus()
	elif hold_prep_button != null and hold_prep_button.is_visible_in_tree():
		hold_prep_button.grab_focus()
	elif close_button != null:
		close_button.grab_focus()

func close() -> void:
	var km := _get_kitchen_manager()
	if km != null and km.job_state == km.JobState.COOKING:
		km.pause_cooking()
	visible = false
	_is_holding = false
	var im := _get_input_manager()
	if im != null and im.has_method("get_current_context"):
		if im.get_current_context() == im.ContextMode.KITCHEN:
			im.consume_and_close(&"pause_menu")

# --- Button Callbacks ---

func _on_start_prep_pressed() -> void:
	var km := _get_kitchen_manager()
	if km == null:
		return
	var res: Dictionary = km.start_preparation()
	if not res.get("success", false):
		set_feedback(res.get("reason", "Gagal memulai persiapan."))
	else:
		set_feedback("Bahan telah direservasi. Tahan tombol Siapkan selama 4 detik.")
	refresh_ui()

func _on_cancel_pressed() -> void:
	var km := _get_kitchen_manager()
	if km == null:
		return
	var res: Dictionary = km.cancel_preparation()
	if res.get("success", false):
		set_feedback("Persiapan dibatalkan. Bahan telah dikembalikan dengan aman.")
	else:
		set_feedback(res.get("reason", "Tidak dapat membatalkan persiapan."))
	refresh_ui()

func _on_claim_refund_pressed() -> void:
	var km := _get_kitchen_manager()
	if km == null:
		return
	var res: Dictionary = km.claim_refund_items()
	set_feedback(res.get("reason", ""))
	refresh_ui()

func _on_start_cooking_pressed() -> void:
	var km := _get_kitchen_manager()
	if km == null:
		return
	var res: Dictionary = km.start_cooking(km.HeatLevel.LOW)
	if res.get("success", false):
		set_feedback("Memasak dimulai dengan panas Rendah. Atur tingkat panas sesuai kebutuhan.")
	else:
		set_feedback(res.get("reason", "Gagal memulai memasak."))
	refresh_ui()

func _on_heat_button_pressed(level: int) -> void:
	var km := _get_kitchen_manager()
	if km != null:
		km.set_heat_level(level)
		_update_cooking_display()

func _on_resume_cooking_pressed() -> void:
	var km := _get_kitchen_manager()
	if km != null:
		km.resume_cooking()
		refresh_ui()

func _on_take_dish_pressed() -> void:
	var km := _get_kitchen_manager()
	if km == null:
		return
	var res: Dictionary = km.claim_dish_output()
	if res.get("success", false):
		set_feedback(res.get("reason", "Hidangan berhasil diambil ke dalam tas."))
	else:
		set_feedback(res.get("reason", "Tas tidak cukup."))
	refresh_ui()

func _on_hold_button_down() -> void:
	_is_holding = true

func _on_hold_button_up() -> void:
	_is_holding = false

func _on_kitchen_state_changed(_new_state, _old_state) -> void:
	refresh_ui()

# --- Refresh UI Presentation ---

func refresh_ui() -> void:
	var km := _get_kitchen_manager()
	var inv := _get_inventory_manager()
	if km == null or inv == null:
		return

	# 1. Update Bahan
	var bayam_avail: int = inv.get_available_item_count("ingredient_bayam") if inv.has_method("get_available_item_count") else 0
	var jagung_avail: int = inv.get_available_item_count("ingredient_jagung") if inv.has_method("get_available_item_count") else 0
	var temu_avail: int = inv.get_available_item_count("ingredient_temu_kunci") if inv.has_method("get_available_item_count") else 0

	var st_val: int = int(km.get("job_state"))
	var is_preparing: bool = (st_val == km.JobState.RESERVED_PREPARING)
	var is_ready: bool = (st_val == km.JobState.READY_TO_HEAT)
	var is_cooking: bool = (st_val == km.JobState.COOKING)
	var is_paused: bool = (st_val == km.JobState.PAUSED)
	var is_output_ready: bool = (st_val == km.JobState.OUTPUT_READY)

	if bayam_label != null:
		if is_preparing or is_ready:
			bayam_label.text = "Bayam: 3 / 3 (Direservasi di Dapur)"
		else:
			bayam_label.text = "Bayam: %d / 3" % bayam_avail

	if jagung_label != null:
		if is_preparing or is_ready:
			jagung_label.text = "Jagung: 1 / 1 (Direservasi di Dapur)"
		else:
			jagung_label.text = "Jagung: %d / 1" % jagung_avail

	if temu_kunci_label != null:
		if is_preparing or is_ready:
			temu_kunci_label.text = "Temu Kunci: 1 / 1 (Direservasi di Dapur)"
		else:
			temu_kunci_label.text = "Temu Kunci: %d / 1" % temu_avail

	# 2. Update status sections
	if is_cooking or is_paused:
		if ingredients_section != null:
			ingredients_section.visible = false
		if prep_section != null:
			prep_section.visible = false
		if ready_section != null:
			ready_section.visible = false
		if cooking_section != null:
			cooking_section.visible = true
		if output_section != null:
			output_section.visible = false
		if start_prep_button != null:
			start_prep_button.visible = false
		if cancel_button != null:
			cancel_button.visible = false
		_update_cooking_display()

	elif is_output_ready:
		if ingredients_section != null:
			ingredients_section.visible = false
		if prep_section != null:
			prep_section.visible = false
		if ready_section != null:
			ready_section.visible = false
		if cooking_section != null:
			cooking_section.visible = false
		if output_section != null:
			output_section.visible = true
		if start_prep_button != null:
			start_prep_button.visible = false
		if cancel_button != null:
			cancel_button.visible = false

	elif is_preparing:
		if ingredients_section != null:
			ingredients_section.visible = true
		if prep_section != null:
			prep_section.visible = true
		if ready_section != null:
			ready_section.visible = false
		if cooking_section != null:
			cooking_section.visible = false
		if output_section != null:
			output_section.visible = false
		if start_prep_button != null:
			start_prep_button.visible = false
		if cancel_button != null:
			cancel_button.visible = true
		_update_prep_display()

	elif is_ready:
		if ingredients_section != null:
			ingredients_section.visible = false
		if prep_section != null:
			prep_section.visible = false
		if ready_section != null:
			ready_section.visible = true
		if cooking_section != null:
			cooking_section.visible = false
		if output_section != null:
			output_section.visible = false
		if start_prep_button != null:
			start_prep_button.visible = false
		if cancel_button != null:
			cancel_button.visible = true

	else: # IDLE or other
		if ingredients_section != null:
			ingredients_section.visible = true
		if prep_section != null:
			prep_section.visible = false
		if ready_section != null:
			ready_section.visible = false
		if cooking_section != null:
			cooking_section.visible = false
		if output_section != null:
			output_section.visible = false
		if start_prep_button != null:
			start_prep_button.visible = true
			var can_prep: Dictionary = km.can_start_preparation()
			start_prep_button.disabled = not bool(can_prep.get("success", false))
			if ingredients_status_label != null:
				ingredients_status_label.text = can_prep.get("reason", "")
		if cancel_button != null:
			cancel_button.visible = false

	# 3. Update refund section
	if km.has_refund_items():
		if refund_section != null:
			refund_section.visible = true
	else:
		if refund_section != null:
			refund_section.visible = false

func _update_prep_display() -> void:
	var km := _get_kitchen_manager()
	if km == null:
		return
	if prep_progress_bar != null:
		prep_progress_bar.max_value = km.prep_duration
		prep_progress_bar.value = km.prep_progress
	if prep_time_label != null:
		prep_time_label.text = "Tahan Siapkan: %.1fs / %.1fs" % [km.prep_progress, km.prep_duration]

func _update_cooking_display() -> void:
	var km := _get_kitchen_manager()
	if km == null:
		return

	if cooking_progress_bar != null:
		cooking_progress_bar.max_value = km.cook_duration
		cooking_progress_bar.value = km.cook_progress

	var heat_name := "Rendah"
	var mult: float = km.get_heat_multiplier()
	match int(km.current_heat_level):
		0: heat_name = "Rendah"
		1: heat_name = "Sedang"
		2: heat_name = "Tinggi"

	if km.job_state == km.JobState.PAUSED:
		if cooking_status_label != null:
			cooking_status_label.text = "Status: Dijeda"
		if cooking_time_label != null:
			cooking_time_label.text = "Progres Memasak: %.1fs / %.1fs (DIJEDA)" % [km.cook_progress, km.cook_duration]
	elif km.is_heat_stalled():
		if cooking_status_label != null:
			cooking_status_label.text = "Status: Tertahan (Panas Terlalu Tinggi)"
		if cooking_time_label != null:
			cooking_time_label.text = "Progres Memasak: %.1fs / %.1fs (TERTAHAN — 0.0x)" % [km.cook_progress, km.cook_duration]
	else:
		if cooking_status_label != null:
			cooking_status_label.text = "Status: Sedang Memasak"
		if cooking_time_label != null:
			cooking_time_label.text = "Progres Memasak: %.1fs / %.1fs (%s — %.1fx)" % [km.cook_progress, km.cook_duration, heat_name, mult]

	if heat_warning_panel != null:
		heat_warning_panel.visible = km.is_heat_stalled()

	if paused_panel != null:
		paused_panel.visible = (km.job_state == km.JobState.PAUSED)

	# Update heat button text for active feedback
	if heat_low_button != null:
		heat_low_button.text = "[Aktif] Rendah (0.5x)" if km.current_heat_level == km.HeatLevel.LOW else "Rendah (0.5x)"
	if heat_med_button != null:
		heat_med_button.text = "[Aktif] Sedang (1.0x)" if km.current_heat_level == km.HeatLevel.MEDIUM else "Sedang (1.0x) [Optimal]"
	if heat_high_button != null:
		heat_high_button.text = "[Aktif] Tinggi (0.0x)" if km.current_heat_level == km.HeatLevel.HIGH else "Tinggi (0.0x) [Tertahan]"

func set_feedback(msg: String) -> void:
	if feedback_label != null:
		feedback_label.text = msg
