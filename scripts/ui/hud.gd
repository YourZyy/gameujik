class_name HUD
extends CanvasLayer

const NotificationManagerClass = preload("res://scripts/ui/notification_manager.gd")

## Exploration HUD terpadu: Reticle, Interaction Prompt, dan Quest Tracker
## Memenuhi spesifikasi UI_UX.md UI01, TEST_PLAN T01..T03, T11, T31, dan PRD FR04

@onready var quest_tracker_container: Control = find_child("QuestTrackerContainer", true, false) as Control
@onready var untracked_container: Control = find_child("UntrackedContainer", true, false) as Control
@onready var tracked_container: Control = find_child("TrackedContainer", true, false) as Control
@onready var untracked_label: Label = find_child("UntrackedLabel", true, false) as Label
@onready var recipe_title_label: Label = find_child("RecipeTitleLabel", true, false) as Label
@onready var bayam_row: Label = find_child("BayamRow", true, false) as Label
@onready var jagung_row: Label = find_child("JagungRow", true, false) as Label
@onready var temu_kunci_row: Label = find_child("TemuKunciRow", true, false) as Label
@onready var tracker_status_label: Label = find_child("TrackerStatusLabel", true, false) as Label

@onready var reticle: Control = find_child("Reticle", true, false) as Control
@onready var prompt_panel: PanelContainer = find_child("PromptPanel", true, false) as PanelContainer
@onready var prompt_label: Label = find_child("PromptLabel", true, false) as Label
@onready var hold_panel: PanelContainer = find_child("HoldPanel", true, false) as PanelContainer
@onready var hold_progress_bar: ProgressBar = find_child("HoldProgressBar", true, false) as ProgressBar
@onready var tool_panel: PanelContainer = find_child("ToolPanel", true, false) as PanelContainer
@onready var tool_label: Label = find_child("ToolLabel", true, false) as Label

var _is_prompt_visible: bool = false
var _recipe_manager_override: Node = null
var _garden_manager_override: Node = null
var _kitchen_manager_override: Node = null
var _focused_interactable: Object = null
var _detector: Node = null
var _feedback_timer: float = 0.0
var _feedback_active: bool = false

func _ready() -> void:
	hide_prompt()
	hide_hold_progress()
	_connect_recipe_manager_signals()
	_connect_garden_manager_signals()
	_connect_world_resource_manager_signals()
	_connect_kitchen_manager_signals()
	_connect_dialogue_manager_signals()
	refresh_tracker()
	refresh_tool_display()

func _process(delta: float) -> void:
	if _feedback_active:
		_feedback_timer -= delta
		if _feedback_timer <= 0.0:
			_feedback_active = false
			refresh_prompt()
	elif _focused_interactable != null and str(_focused_interactable.get("interaction_id")) == "landmark_plot":
		refresh_prompt()

func set_recipe_manager(rm: Node) -> void:
	_recipe_manager_override = rm
	_connect_recipe_manager_signals()
	refresh_tracker()

func _get_recipe_manager() -> Node:
	if _recipe_manager_override != null and is_instance_valid(_recipe_manager_override):
		return _recipe_manager_override
	if Engine.has_singleton("RecipeManager"):
		return Engine.get_singleton("RecipeManager")
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var node = tree.root.get_node_or_null("RecipeManager")
		if node != null:
			return node
	if is_inside_tree() and has_node("/root/RecipeManager"):
		return get_node("/root/RecipeManager")
	return null

func _connect_recipe_manager_signals() -> void:
	var rm := _get_recipe_manager()
	if rm != null:
		if rm.has_signal("recipe_tracked") and not rm.recipe_tracked.is_connected(func(_r): refresh_tracker()):
			rm.recipe_tracked.connect(func(_r): refresh_tracker())
		if rm.has_signal("recipe_untracked") and not rm.recipe_untracked.is_connected(func(_r): refresh_tracker()):
			rm.recipe_untracked.connect(func(_r): refresh_tracker())
		if rm.has_signal("recipe_updated") and not rm.recipe_updated.is_connected(func(_r): refresh_tracker()):
			rm.recipe_updated.connect(func(_r): refresh_tracker())
		if rm.has_signal("recipe_completed") and not rm.recipe_completed.is_connected(func(_r): refresh_tracker()):
			rm.recipe_completed.connect(func(_r): refresh_tracker())
		if rm.has_signal("cooking_state_changed") and not rm.cooking_state_changed.is_connected(func(_s): refresh_tracker()):
			rm.cooking_state_changed.connect(func(_s): refresh_tracker())

func refresh_tracker() -> void:
	var rm := _get_recipe_manager()
	if rm == null:
		if untracked_container != null:
			untracked_container.visible = true
		if tracked_container != null:
			tracked_container.visible = false
		return

	var tracked_id: String = str(rm.get("tracked_recipe_id"))
	if tracked_id.is_empty():
		if untracked_container != null:
			untracked_container.visible = true
		if tracked_container != null:
			tracked_container.visible = false
		return

	var recipe = rm.get_recipe(tracked_id) if rm.has_method("get_recipe") else null
	if recipe == null:
		if untracked_container != null:
			untracked_container.visible = true
		if tracked_container != null:
			tracked_container.visible = false
		return

	if untracked_container != null:
		untracked_container.visible = false
	if tracked_container != null:
		tracked_container.visible = true

	if recipe_title_label != null:
		recipe_title_label.text = str(recipe.get("display_name"))

	# Update ingredient lines with live stock
	var bayam_avail: int = rm.get_available_ingredient_count("ingredient_bayam") if rm.has_method("get_available_ingredient_count") else 0
	var jagung_avail: int = rm.get_available_ingredient_count("ingredient_jagung") if rm.has_method("get_available_ingredient_count") else 0
	var temu_kunci_avail: int = rm.get_available_ingredient_count("ingredient_temu_kunci") if rm.has_method("get_available_ingredient_count") else 0

	if bayam_row != null:
		bayam_row.text = "• Bayam: %d/3" % bayam_avail
		bayam_row.modulate = Color(0.4, 0.95, 0.4) if bayam_avail >= 3 else Color(0.9, 0.9, 0.9)

	if jagung_row != null:
		jagung_row.text = "• Jagung: %d/1" % jagung_avail
		jagung_row.modulate = Color(0.4, 0.95, 0.4) if jagung_avail >= 1 else Color(0.9, 0.9, 0.9)

	if temu_kunci_row != null:
		temu_kunci_row.text = "• Temu Kunci: %d/1" % temu_kunci_avail
		temu_kunci_row.modulate = Color(0.4, 0.95, 0.4) if temu_kunci_avail >= 1 else Color(0.9, 0.9, 0.9)

	# Cooking state & Ready status
	var cooking_state: String = str(rm.get("cooking_state")) if "cooking_state" in rm else "idle"
	var is_ready: bool = rm.can_cook_recipe(tracked_id) if rm.has_method("can_cook_recipe") else false
	var is_completed: bool = rm.is_recipe_completed(tracked_id) if rm.has_method("is_recipe_completed") else false

	if tracker_status_label != null:
		if cooking_state == "cooking":
			tracker_status_label.text = "Sedang memasak..."
			tracker_status_label.modulate = Color(1.0, 0.8, 0.3)
			tracker_status_label.visible = true
		elif cooking_state == "paused":
			tracker_status_label.text = "Masakan dijeda"
			tracker_status_label.modulate = Color(1.0, 0.6, 0.3)
			tracker_status_label.visible = true
		elif is_ready:
			tracker_status_label.text = "Bahan lengkap. Siap dimasak di dapur."
			tracker_status_label.modulate = Color(0.4, 0.95, 0.45)
			tracker_status_label.visible = true
		elif is_completed:
			tracker_status_label.text = "Resep selesai. Boleh dimasak ulang."
			tracker_status_label.modulate = Color(0.5, 0.9, 0.6)
			tracker_status_label.visible = true
		else:
			tracker_status_label.text = ""
			tracker_status_label.visible = false

# --- Gardening & Tool UI Integration ---

func set_garden_manager(gm: Node) -> void:
	_garden_manager_override = gm
	_connect_garden_manager_signals()
	refresh_tool_display()
	refresh_prompt()

func _get_garden_manager() -> Node:
	if _garden_manager_override != null and is_instance_valid(_garden_manager_override):
		return _garden_manager_override
	if Engine.has_singleton("GardenManager"):
		return Engine.get_singleton("GardenManager")
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var node = tree.root.get_node_or_null("GardenManager")
		if node != null:
			return node
	if is_inside_tree() and has_node("/root/GardenManager"):
		return get_node("/root/GardenManager")
	return null

func _connect_garden_manager_signals() -> void:
	var gm := _get_garden_manager()
	if gm != null:
		if gm.has_signal("active_tool_changed") and not gm.active_tool_changed.is_connected(_on_active_tool_changed):
			gm.active_tool_changed.connect(_on_active_tool_changed)
		if gm.has_signal("water_level_changed") and not gm.water_level_changed.is_connected(_on_water_level_changed):
			gm.water_level_changed.connect(_on_water_level_changed)
		if gm.has_signal("plot_state_changed") and not gm.plot_state_changed.is_connected(_on_plot_state_changed):
			gm.plot_state_changed.connect(_on_plot_state_changed)
		if gm.has_signal("action_failed") and not gm.action_failed.is_connected(_on_garden_action_failed):
			gm.action_failed.connect(_on_garden_action_failed)

func _on_garden_action_failed(reason: String) -> void:
	show_feedback(reason, 2.5)

func _get_world_resource_manager() -> Node:
	if Engine.has_singleton("WorldResourceManager"):
		return Engine.get_singleton("WorldResourceManager")
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var node = tree.root.get_node_or_null("WorldResourceManager")
		if node != null:
			return node
	if is_inside_tree() and has_node("/root/WorldResourceManager"):
		return get_node("/root/WorldResourceManager")
	return null

func _connect_world_resource_manager_signals() -> void:
	var wrm := _get_world_resource_manager()
	if wrm != null:
		if wrm.has_signal("action_failed") and not wrm.action_failed.is_connected(_on_world_action_failed):
			wrm.action_failed.connect(_on_world_action_failed)
		if wrm.has_signal("action_success") and not wrm.action_success.is_connected(_on_world_action_success):
			wrm.action_success.connect(_on_world_action_success)
		if wrm.has_signal("foraging_state_changed") and not wrm.foraging_state_changed.is_connected(_on_foraging_state_changed):
			wrm.foraging_state_changed.connect(_on_foraging_state_changed)
		if wrm.has_signal("day_advanced") and not wrm.day_advanced.is_connected(_on_world_day_advanced):
			wrm.day_advanced.connect(_on_world_day_advanced)

func _on_world_action_failed(reason: String) -> void:
	show_feedback(reason, 2.5)

func _on_world_action_success(_action_name: String, message: String) -> void:
	show_feedback(message, 2.5)

func _on_foraging_state_changed(_node_id: String, _is_available: bool) -> void:
	refresh_prompt()

func _on_world_day_advanced(_day: int) -> void:
	refresh_prompt()

func set_kitchen_manager(km: Node) -> void:
	_kitchen_manager_override = km
	_connect_kitchen_manager_signals()
	refresh_prompt()

func _get_kitchen_manager() -> Node:
	if _kitchen_manager_override != null and is_instance_valid(_kitchen_manager_override):
		return _kitchen_manager_override
	if Engine.has_singleton("KitchenManager"):
		return Engine.get_singleton("KitchenManager")
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var node = tree.root.get_node_or_null("KitchenManager")
		if node != null:
			return node
	if is_inside_tree() and has_node("/root/KitchenManager"):
		return get_node("/root/KitchenManager")
	return null

func _connect_kitchen_manager_signals() -> void:
	var km := _get_kitchen_manager()
	if km != null:
		if km.has_signal("state_changed") and not km.state_changed.is_connected(func(_n, _o): refresh_prompt()):
			km.state_changed.connect(func(_n, _o): refresh_prompt())
		if km.has_signal("job_cancelled") and not km.job_cancelled.is_connected(func(_j, _i): refresh_prompt()):
			km.job_cancelled.connect(func(_j, _i): refresh_prompt())
		if km.has_signal("prep_completed") and not km.prep_completed.is_connected(func(_j): refresh_prompt()):
			km.prep_completed.connect(func(_j): refresh_prompt())

func _get_dialogue_manager() -> Node:
	if Engine.has_singleton("DialogueManager"):
		return Engine.get_singleton("DialogueManager")
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var node = tree.root.get_node_or_null("DialogueManager")
		if node != null:
			return node
	if is_inside_tree() and has_node("/root/DialogueManager"):
		return get_node("/root/DialogueManager")
	return null

func _connect_dialogue_manager_signals() -> void:
	var dm := _get_dialogue_manager()
	if dm != null:
		if dm.has_signal("p0_experience_completed") and not dm.p0_experience_completed.is_connected(_on_p0_experience_completed):
			dm.p0_experience_completed.connect(_on_p0_experience_completed)

func _on_p0_experience_completed(msg: String) -> void:
	show_feedback(msg, 4.0)

func _on_active_tool_changed(_tool_id: String) -> void:
	refresh_tool_display()
	refresh_prompt()

func _on_water_level_changed(_cur: int, _max: int) -> void:
	refresh_tool_display()
	refresh_prompt()

func _on_plot_state_changed(_plot_id: String, _data: Dictionary) -> void:
	refresh_prompt()

func refresh_tool_display() -> void:
	if tool_label == null:
		return
	var gm := _get_garden_manager()
	if gm == null:
		tool_label.text = "[1] Cangkul  [2] Benih  [3] Pupuk  [4] Penyiram"
		return

	var active_tool: String = str(gm.get("active_tool"))
	var water: int = int(gm.get("watering_can_water"))
	match active_tool:
		"tool_hoe":
			tool_label.text = "Alat Aktif: [1] Cangkul (Tahan LMB 2s)"
		"tool_seed":
			tool_label.text = "Alat Aktif: [2] Tanam Benih (Klik LMB pada Titik)"
		"tool_fertilizer":
			tool_label.text = "Alat Aktif: [3] Pupuk (Tahan LMB 1s)"
		"tool_watering_can":
			tool_label.text = "Alat Aktif: [4] Penyiram — Air: %d/10 (Tahan LMB 2s)" % water
		_:
			tool_label.text = "[1] Cangkul  [2] Benih  [3] Pupuk  [4] Penyiram (Air: %d/10)" % water

func show_hold_progress(_action_id: String, progress: float, _elapsed: float, _duration: float) -> void:
	if hold_panel != null:
		hold_panel.visible = true
	if hold_progress_bar != null:
		hold_progress_bar.value = clampf(progress, 0.0, 1.0)

func hide_hold_progress() -> void:
	if hold_panel != null:
		hold_panel.visible = false
	if hold_progress_bar != null:
		hold_progress_bar.value = 0.0

# --- Interaction Prompt API Compatibility ---

func show_prompt(text: String) -> void:
	if prompt_label != null:
		prompt_label.text = text
	_is_prompt_visible = true
	if prompt_panel != null:
		prompt_panel.visible = true
		prompt_panel.modulate.a = 1.0

func hide_prompt() -> void:
	_is_prompt_visible = false
	if prompt_panel != null:
		prompt_panel.visible = false
		prompt_panel.modulate.a = 0.0

func is_prompt_visible() -> bool:
	return _is_prompt_visible and prompt_panel != null and prompt_panel.visible

func get_prompt_text() -> String:
	return prompt_label.text if prompt_label != null else ""

func connect_detector(detector: Node) -> void:
	if detector == null:
		return
	_detector = detector
	if detector.has_signal("target_focused"):
		if not detector.target_focused.is_connected(_on_target_focused):
			detector.target_focused.connect(_on_target_focused)
	if detector.has_signal("target_unfocused"):
		if not detector.target_unfocused.is_connected(_on_target_unfocused):
			detector.target_unfocused.connect(_on_target_unfocused)

func show_feedback(message: String, duration: float = 2.5) -> void:
	if prompt_label != null:
		prompt_label.text = message
	_is_prompt_visible = true
	if prompt_panel != null:
		prompt_panel.visible = true
		prompt_panel.modulate.a = 1.0
	_feedback_timer = duration
	_feedback_active = true
	if NotificationManagerClass.instance != null:
		NotificationManagerClass.instance.show_toast(message, "info", duration)

func show_toast(message: String, type: String = "info", duration: float = 2.5) -> void:
	if NotificationManagerClass.instance != null:
		NotificationManagerClass.instance.show_toast(message, type, duration)

func show_pickup(item_name: String, quantity: int = 1, item_id: String = "") -> void:
	if NotificationManagerClass.instance != null:
		NotificationManagerClass.instance.show_pickup(item_name, quantity, item_id)

func show_error(reason: String) -> void:
	if NotificationManagerClass.instance != null:
		NotificationManagerClass.instance.show_error(reason)

func _on_target_focused(interactable: Object) -> void:
	_focused_interactable = interactable
	refresh_prompt()

func _on_target_unfocused() -> void:
	_focused_interactable = null
	hide_prompt()

func refresh_prompt() -> void:
	if _feedback_active:
		return
	if _focused_interactable == null:
		return
	var text := format_contextual_prompt(_focused_interactable)
	show_prompt(text)

func format_contextual_prompt(interactable: Object) -> String:
	if interactable == null:
		return ""
	var i_id: String = str(interactable.get("interaction_id"))
	var gm := _get_garden_manager()

	if i_id == "landmark_plot" and gm != null:
		var active_tool: String = str(gm.get("active_tool"))
		match active_tool:
			"tool_hoe":
				var check: Dictionary = gm.can_hoe_plot("plot_home_01")
				if check.get("success", false):
					return "[Tahan LMB 2s] Gemburkan Petak"
				else:
					return "[LMB] Petak Sudah Gembur"
			"tool_fertilizer":
				var check: Dictionary = gm.can_fertilize_plot("plot_home_01")
				if check.get("success", false):
					return "[Tahan LMB 1s] Pupuk Petak"
				else:
					return "[LMB] Nutrisi Cukup (%s)" % gm.get_nutrient_status_text("plot_home_01")
			"tool_watering_can":
				var check: Dictionary = gm.can_water_plot("plot_home_01")
				if check.get("success", false):
					return "[Tahan LMB 2s] Siram Petak (Air: %d/10)" % int(gm.get("watering_can_water"))
				else:
					return "[LMB] Kelembapan Cukup (%s)" % gm.get_moisture_status_text("plot_home_01")
			"tool_seed":
				var plot: Dictionary = gm.get_plot("plot_home_01")
				if not (plot.get("is_hoed", false) and plot.get("has_compost", false)):
					return "[LMB] Tanah Belum Siap Ditanami"
				return "[LMB] Tanam Benih Bayam"
			_:
				# Periksa apakah reticle membidik titik dengan tanaman siap panen
				if _detector != null and _detector.has_method("get_collision_point") and _focused_interactable is Node:
					var hit_pt: Vector3 = _detector.get_collision_point()
					var plot_node: Node3D = _focused_interactable.get_parent() as Node3D
					if plot_node != null:
						var local_pt: Vector3 = plot_node.to_local(hit_pt)
						var spot_id: String = gm.get_spot_id_from_local_coords(local_pt) if gm.has_method("get_spot_id_from_local_coords") else "slot_01"
						var spot: Dictionary = gm.get_spot("plot_home_01", spot_id) if gm.has_method("get_spot") else {}
						if bool(spot.get("is_occupied", false)) and spot.get("crop_data") != null:
							var crop: Dictionary = spot["crop_data"]
							if bool(crop.get("is_ready_to_harvest", false)):
								return "[E] Panen Bayam"
							else:
								var st: int = int(crop.get("growth_stage", 0))
								var st_name: String = str(gm.CROP_STAGE_NAMES.get(st, "Tumbuh")) if "CROP_STAGE_NAMES" in gm else "Tumbuh"
								return "[E] Periksa Petak (Bayam %s)" % st_name

				var plot: Dictionary = gm.get_plot("plot_home_01")
				if plot.get("is_hoed", false) and not plot.get("has_compost", false):
					var inv = get_node_or_null("/root/InventoryManager")
					if inv != null and inv.get_available_item_count("soil_compost") >= 1:
						return "[E] Tambah pembenah — 1"
					else:
						return "[E] Periksa Petak (Butuh Pembenah)"
				elif not plot.get("is_hoed", false):
					return "[E] Periksa Petak (Belum Digemburkan)"
				else:
					return "[E] Periksa Petak (%s | %s)" % [
						gm.get_nutrient_status_text("plot_home_01"),
						gm.get_moisture_status_text("plot_home_01")
					]

	elif i_id == "landmark_water" and gm != null:
		var cur_w: int = int(gm.get("watering_can_water"))
		if cur_w < 10:
			return "[Tahan E 2s] Isi Air Penyiram (%d/10)" % cur_w
		else:
			return "[E] Air Penyiram Penuh (10/10)"

	elif i_id == "landmark_jagung":
		var wrm := _get_world_resource_manager()
		if wrm != null and not wrm.is_foraging_node_available("resource_jagung_01"):
			return "[E] Jagung (Sudah Dipanen)"
		return "[E] Petik Jagung"

	elif i_id == "landmark_temu_kunci":
		var wrm := _get_world_resource_manager()
		if wrm != null and not wrm.is_foraging_node_available("resource_temu_kunci_01"):
			return "[E] Temu Kunci (Sudah Dipanen)"
		return "[E] Petik Temu Kunci"

	elif i_id == "landmark_reserve":
		return "[E] Periksa Cadangan"

	elif i_id == "landmark_bed":
		return "[E] Istirahat Sampai Besok"

	elif i_id == "landmark_kitchen":
		var km := _get_kitchen_manager()
		if km != null:
			if km.has_method("has_ready_output") and km.has_ready_output():
				return "[E] Ambil Masakan"
			elif km.has_method("is_cooking_active") and km.is_cooking_active():
				return "[E] Buka Dapur (Sedang Memasak)"
			elif km.has_method("is_job_active") and km.is_job_active():
				return "[E] Lanjutkan Dapur"
		return "[E] Masak"

	elif i_id == "landmark_neighbor":
		return "[E] Bicara"

	if interactable.has_method("get_prompt_text"):
		return interactable.get_prompt_text()
	elif interactable.has_method("get_prompt"):
		return interactable.get_prompt()
	return "[E] Interaksi"
