class_name BookUI
extends CanvasLayer

## UI Buku Resep Keluarga untuk Buku Resep 2045
## Memenuhi spesifikasi UI_UX.md UI02, CONTENT.md § 4, PRD FR03/FR04, dan TEST_PLAN T01..T03, T11, T31

@onready var root_control: Control = $RootControl if has_node("RootControl") else (find_child("RootControl", true, false) as Control)
@onready var main_panel: PanelContainer = find_child("MainPanel", true, false) as PanelContainer
@onready var title_label: Label = find_child("TitleLabel", true, false) as Label
@onready var track_button: Button = find_child("TrackButton", true, false) as Button
@onready var close_button: Button = find_child("CloseButton", true, false) as Button
@onready var notes_label: Label = find_child("NotesLabel", true, false) as Label
@onready var station_label: Label = find_child("StationLabel", true, false) as Label
@onready var cook_count_label: Label = find_child("CookCountLabel", true, false) as Label
@onready var status_badge_label: Label = find_child("StatusBadgeLabel", true, false) as Label
@onready var bottom_status_badge: Label = find_child("BottomStatusBadge", true, false) as Label

@onready var bayam_count_label: Label = find_child("BayamCountLabel", true, false) as Label
@onready var jagung_count_label: Label = find_child("JagungCountLabel", true, false) as Label
@onready var temu_kunci_count_label: Label = find_child("TemuKunciCountLabel", true, false) as Label

@onready var bayam_hint_label: Label = find_child("BayamHintLabel", true, false) as Label
@onready var jagung_hint_label: Label = find_child("JagungHintLabel", true, false) as Label
@onready var temu_kunci_hint_label: Label = find_child("TemuKunciHintLabel", true, false) as Label

const RECIPE_ID: String = "recipe_sayur_bening_01"

func _ready() -> void:
	visible = false
	if close_button != null:
		close_button.pressed.connect(close_book)
	if track_button != null:
		track_button.pressed.connect(_on_track_pressed)

	_connect_recipe_manager_signals()
	_connect_input_manager_signals()

func _connect_recipe_manager_signals() -> void:
	var rm := _get_recipe_manager()
	if rm != null:
		if rm.has_signal("recipe_updated") and not rm.recipe_updated.is_connected(_on_recipe_data_updated):
			rm.recipe_updated.connect(_on_recipe_data_updated)
		if rm.has_signal("recipe_tracked") and not rm.recipe_tracked.is_connected(_on_recipe_data_updated):
			rm.recipe_tracked.connect(_on_recipe_data_updated)
		if rm.has_signal("recipe_untracked") and not rm.recipe_untracked.is_connected(_on_recipe_data_updated):
			rm.recipe_untracked.connect(_on_recipe_data_updated)
		if rm.has_signal("recipe_completed") and not rm.recipe_completed.is_connected(_on_recipe_data_updated):
			rm.recipe_completed.connect(_on_recipe_data_updated)
		if rm.has_signal("note_unlocked") and not rm.note_unlocked.is_connected(func(_id, _txt): refresh_ui()):
			rm.note_unlocked.connect(func(_id, _txt): refresh_ui())

func _connect_input_manager_signals() -> void:
	var im := _get_input_manager()
	if im != null and im.has_signal("context_changed"):
		if not im.context_changed.is_connected(_on_context_changed):
			im.context_changed.connect(_on_context_changed)

func _on_context_changed(new_context: int, _prev_context: int) -> void:
	var im := _get_input_manager()
	if im == null:
		return
	if new_context == im.ContextMode.BOOK:
		if not visible:
			open_book()
	else:
		if visible:
			visible = false

func _on_recipe_data_updated(_r_id: String = "") -> void:
	if visible:
		refresh_ui()

func open() -> void:
	open_book()

func close() -> void:
	close_book()

func open_book() -> void:
	if visible:
		return
	visible = true
	var im := _get_input_manager()
	if im != null and im.has_method("push_context"):
		if im.get_current_context() != im.ContextMode.BOOK:
			im.push_context(im.ContextMode.BOOK)

	refresh_ui()

	if track_button != null and track_button.is_inside_tree():
		track_button.grab_focus()

func close_book() -> void:
	if not visible:
		return
	visible = false
	var im := _get_input_manager()
	if im != null:
		if im.get_current_context() == im.ContextMode.BOOK:
			if im.has_method("consume_and_close"):
				im.consume_and_close(&"open_book")
			elif im.has_method("pop_context"):
				im.pop_context()

func _on_track_pressed() -> void:
	var rm := _get_recipe_manager()
	if rm != null and rm.has_method("toggle_tracking"):
		rm.toggle_tracking(RECIPE_ID)
	refresh_ui()

func refresh_ui() -> void:
	var rm := _get_recipe_manager()
	if rm == null:
		return

	var recipe = rm.get_recipe(RECIPE_ID)
	if recipe == null:
		return

	# Title
	if title_label != null:
		title_label.text = str(recipe.get("display_name"))

	# Family note + unlocked notes
	if notes_label != null:
		var notes_text: String = str(recipe.get("family_note"))
		if rm.has_method("is_note_unlocked") and rm.is_note_unlocked("note_garden_01"):
			var garden_note: Dictionary = rm.get_note("note_garden_01")
			notes_text += "\n\n[Catatan Kebun Ujung Jalan]:\n\"" + str(garden_note.get("text", "")) + "\""
		notes_label.text = notes_text

	# Station & History
	if station_label != null:
		station_label.text = "Tempat Memasak: Dapur Rumah"

	var times_cooked: int = int(recipe.get("times_cooked"))
	if cook_count_label != null:
		if times_cooked > 0:
			cook_count_label.text = "Riwayat Masak: %d kali dimasak" % times_cooked
		else:
			cook_count_label.text = "Riwayat Masak: Belum pernah dimasak"

	# Ingredient counts
	var bayam_avail: int = rm.get_available_ingredient_count("ingredient_bayam") if rm.has_method("get_available_ingredient_count") else 0
	var jagung_avail: int = rm.get_available_ingredient_count("ingredient_jagung") if rm.has_method("get_available_ingredient_count") else 0
	var temu_kunci_avail: int = rm.get_available_ingredient_count("ingredient_temu_kunci") if rm.has_method("get_available_ingredient_count") else 0

	if bayam_count_label != null:
		bayam_count_label.text = "%d / 3" % bayam_avail
		bayam_count_label.modulate = Color(0.4, 0.9, 0.4) if bayam_avail >= 3 else Color(1, 0.9, 0.7)
	if jagung_count_label != null:
		jagung_count_label.text = "%d / 1" % jagung_avail
		jagung_count_label.modulate = Color(0.4, 0.9, 0.4) if jagung_avail >= 1 else Color(1, 0.9, 0.7)
	if temu_kunci_count_label != null:
		temu_kunci_count_label.text = "%d / 1" % temu_kunci_avail
		temu_kunci_count_label.modulate = Color(0.4, 0.9, 0.4) if temu_kunci_avail >= 1 else Color(1, 0.9, 0.7)

	# Hints
	var hints: Dictionary = recipe.get("source_hints")
	if bayam_hint_label != null:
		bayam_hint_label.text = str(hints.get("ingredient_bayam", ""))
	if jagung_hint_label != null:
		jagung_hint_label.text = str(hints.get("ingredient_jagung", ""))
	if temu_kunci_hint_label != null:
		temu_kunci_hint_label.text = str(hints.get("ingredient_temu_kunci", ""))

	# Status badges
	var is_ready: bool = rm.can_cook_recipe(RECIPE_ID) if rm.has_method("can_cook_recipe") else false
	var is_completed: bool = rm.is_recipe_completed(RECIPE_ID) if rm.has_method("is_recipe_completed") else false

	if status_badge_label != null:
		if is_completed:
			status_badge_label.text = "Status: Selesai (%d kali dimasak)" % times_cooked
			status_badge_label.modulate = Color(0.3, 0.85, 0.4)
		elif is_ready:
			status_badge_label.text = "Status: Siap dimasak"
			status_badge_label.modulate = Color(0.3, 0.9, 0.5)
		else:
			status_badge_label.text = "Status: Belum dimasak"
			status_badge_label.modulate = Color(0.85, 0.85, 0.85)

	if bottom_status_badge != null:
		if is_completed:
			bottom_status_badge.text = "✓ Resep telah diselesaikan (%d kali dimasak). Boleh dimasak ulang." % times_cooked
			bottom_status_badge.modulate = Color(0.4, 0.9, 0.4)
		elif is_ready:
			bottom_status_badge.text = "★ Bahan lengkap. Siap dimasak di dapur."
			bottom_status_badge.modulate = Color(0.4, 0.95, 0.45)
		else:
			bottom_status_badge.text = "Bahan belum lengkap. Ikuti petunjuk untuk mengumpulkan bahan."
			bottom_status_badge.modulate = Color(0.85, 0.85, 0.7)

	# Track button
	if track_button != null:
		var is_tracked: bool = rm.is_recipe_tracked(RECIPE_ID) if rm.has_method("is_recipe_tracked") else false
		if is_tracked:
			track_button.text = "Berhenti Melacak"
		else:
			track_button.text = "Lacak Masakan"

func _get_recipe_manager() -> Node:
	if Engine.has_singleton("RecipeManager"):
		return Engine.get_singleton("RecipeManager")
	if has_node("/root/RecipeManager"):
		return get_node("/root/RecipeManager")
	return null

func _get_input_manager() -> Node:
	if Engine.has_singleton("InputManager"):
		return Engine.get_singleton("InputManager")
	if has_node("/root/InputManager"):
		return get_node("/root/InputManager")
	return null
