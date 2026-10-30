class_name PauseMenu
extends CanvasLayer

## PauseMenu — Pengelola Antarmuka Menu Jeda dan Navigasi Modal untuk 'Buku Resep 2045'
## Memenuhi spesifikasi UI_UX.md § 3, § 4, § 5 (UI06), PRD FR16, FR21, dan TEST_PLAN T18, T21, T28, T51, T52, T53, T54

signal resumed()
signal save_requested(slot_type: String)
signal load_requested(slot_type: String)
signal new_game_requested()
signal exit_requested()

@onready var root_control: Control = $RootControl if has_node("RootControl") else null
@onready var background_dimmer: ColorRect = find_child("BackgroundDimmer", true, false) as ColorRect
@onready var main_panel: PanelContainer = find_child("MainPanel", true, false) as PanelContainer

# Action Buttons
@onready var btn_resume: Button = find_child("BtnResume", true, false) as Button
@onready var btn_save: Button = find_child("BtnSave", true, false) as Button
@onready var btn_load: Button = find_child("BtnLoad", true, false) as Button
@onready var btn_settings: Button = find_child("BtnSettings", true, false) as Button
@onready var btn_return_home: Button = find_child("BtnReturnHome", true, false) as Button
@onready var btn_new_game: Button = find_child("BtnNewGame", true, false) as Button
@onready var btn_exit: Button = find_child("BtnExit", true, false) as Button
@onready var status_label: Label = find_child("StatusLabel", true, false) as Label

# Subpanels
@onready var settings_panel: Control = find_child("SettingsMenu", true, false) as Control
@onready var slot_picker_modal: PanelContainer = find_child("SlotPickerModal", true, false) as PanelContainer
@onready var confirm_modal: PanelContainer = find_child("ConfirmModal", true, false) as PanelContainer

# Slot Picker Elements
@onready var slot_manual_btn: Button = find_child("SlotManualButton", true, false) as Button
@onready var slot_auto_btn: Button = find_child("SlotAutosaveButton", true, false) as Button
@onready var btn_close_slot_picker: Button = find_child("CloseSlotPickerButton", true, false) as Button

# Confirm Modal Elements
@onready var modal_title: Label = find_child("ModalTitle", true, false) as Label
@onready var modal_message: Label = find_child("ModalMessage", true, false) as Label
@onready var modal_btn_1: Button = find_child("ModalBtn1", true, false) as Button
@onready var modal_btn_2: Button = find_child("ModalBtn2", true, false) as Button
@onready var modal_btn_cancel: Button = find_child("ModalBtnCancel", true, false) as Button

var _subpanel_stack: Array[Control] = []
var _last_focused_control: Control = null
var _focus_style: StyleBoxFlat = null
var _exit_called_in_test: bool = false # flag for test interception

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 14
	visible = false

	_create_focus_style()
	_connect_button_signals()
	_setup_focus_navigation()
	_connect_input_manager()
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("hook_control_tree") and root_control:
		am.hook_control_tree(root_control)

func _create_focus_style() -> void:
	_focus_style = StyleBoxFlat.new()
	_focus_style.draw_center = false
	_focus_style.border_width_left = 2
	_focus_style.border_width_top = 2
	_focus_style.border_width_right = 2
	_focus_style.border_width_bottom = 2
	_focus_style.border_color = Color(1.0, 0.85, 0.3, 1.0)
	_focus_style.set_corner_radius_all(4)

func _connect_button_signals() -> void:
	if btn_resume: btn_resume.pressed.connect(resume_game)
	if btn_save: btn_save.pressed.connect(_on_save_pressed)
	if btn_load: btn_load.pressed.connect(_on_load_pressed)
	if btn_settings: btn_settings.pressed.connect(_on_settings_pressed)
	if btn_return_home: btn_return_home.pressed.connect(_on_return_home_pressed)
	if btn_new_game: btn_new_game.pressed.connect(_on_new_game_pressed)
	if btn_exit: btn_exit.pressed.connect(_on_exit_pressed)

	if slot_manual_btn: slot_manual_btn.pressed.connect(func(): _on_slot_selected("manual"))
	if slot_auto_btn: slot_auto_btn.pressed.connect(func(): _on_slot_selected("autosave"))
	if btn_close_slot_picker: btn_close_slot_picker.pressed.connect(pop_subpanel)

	if modal_btn_cancel: modal_btn_cancel.pressed.connect(pop_subpanel)

	if settings_panel:
		settings_panel.closed.connect(pop_subpanel)

func _setup_focus_navigation() -> void:
	var buttons: Array[Button] = [
		btn_resume,
		btn_save,
		btn_load,
		btn_settings,
		btn_return_home,
		btn_new_game,
		btn_exit
	]

	var valid_buttons: Array[Button] = []
	for b in buttons:
		if b != null:
			b.focus_mode = Control.FOCUS_ALL
			b.add_theme_stylebox_override("focus", _focus_style)
			valid_buttons.append(b)

	# Circular focus linking (T51)
	if valid_buttons.size() > 1:
		for i in range(valid_buttons.size()):
			var cur := valid_buttons[i]
			var prev := valid_buttons[(i - 1 + valid_buttons.size()) % valid_buttons.size()]
			var next := valid_buttons[(i + 1) % valid_buttons.size()]
			cur.focus_neighbor_top = prev.get_path()
			cur.focus_neighbor_bottom = next.get_path()

	# Also style modal buttons
	var modal_buttons: Array[Button] = [
		slot_manual_btn,
		slot_auto_btn,
		btn_close_slot_picker,
		modal_btn_1,
		modal_btn_2,
		modal_btn_cancel
	]
	for mb in modal_buttons:
		if mb != null:
			mb.focus_mode = Control.FOCUS_ALL
			mb.add_theme_stylebox_override("focus", _focus_style)

func _connect_input_manager() -> void:
	var im := _get_input_manager()
	if im and im.has_signal("context_changed"):
		im.context_changed.connect(_on_context_changed)

func _on_context_changed(new_context: int, _old_context: int) -> void:
	var im := _get_input_manager()
	if im == null:
		return
	if new_context == im.ContextMode.PAUSE:
		open_menu()
	elif visible:
		close_menu_silent()

func open_menu() -> void:
	visible = true
	_subpanel_stack.clear()
	if main_panel: main_panel.visible = true
	if settings_panel: settings_panel.visible = false
	if slot_picker_modal: slot_picker_modal.visible = false
	if confirm_modal: confirm_modal.visible = false
	if status_label: status_label.text = ""

	call_deferred("_focus_resume")

func _focus_resume() -> void:
	if btn_resume and btn_resume.is_visible_in_tree():
		btn_resume.grab_focus()

func resume_game() -> void:
	visible = false
	_subpanel_stack.clear()
	var im := _get_input_manager()
	if im != null:
		if im.get_current_context() == im.ContextMode.PAUSE:
			im.consume_and_close(&"pause_menu")
	resumed.emit()

func close_menu_silent() -> void:
	visible = false
	_subpanel_stack.clear()

# ==============================================================================
# SUBPANEL & MODAL STACK (T18, T28, T51)
# ==============================================================================

func push_subpanel(panel: Control, initial_focus: Control = null) -> void:
	_last_focused_control = get_viewport().gui_get_focus_owner() if get_viewport() else null
	_subpanel_stack.append(panel)
	panel.visible = true
	if initial_focus and initial_focus.is_visible_in_tree():
		initial_focus.grab_focus()

func pop_subpanel() -> void:
	if _subpanel_stack.is_empty():
		return
	var top := _subpanel_stack.pop_back() as Control
	if top:
		top.visible = false
	if _last_focused_control and is_instance_valid(_last_focused_control) and _last_focused_control.is_visible_in_tree():
		_last_focused_control.grab_focus()
	elif btn_resume and btn_resume.is_visible_in_tree():
		btn_resume.grab_focus()

func get_subpanel_depth() -> int:
	return _subpanel_stack.size()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause_menu") and not event.is_echo():
		if not _subpanel_stack.is_empty():
			pop_subpanel()
			get_viewport().set_input_as_handled()
		else:
			resume_game()
			get_viewport().set_input_as_handled()

# ==============================================================================
# ACTIONS & CONFIRMATIONS (T53, Overwrite, Safe Return)
# ==============================================================================

func _on_save_pressed() -> void:
	var sm := _get_save_manager()
	if sm == null:
		return
	if sm.has_valid_save("manual"):
		var meta: Dictionary = sm.get_slot_metadata("manual")
		var date_str: String = meta.get("timestamp_iso", "")
		_show_confirm(
			"Konfirmasi Timpa Simpanan",
			"Slot simpanan manual sudah berisi data (Revisi %d, %s).\nApakah Anda yakin ingin menimpa data ini?" % [meta.get("revision", 1), date_str],
			"Ya, Timpa",
			func(): _execute_save("manual"),
			"",
			Callable()
		)
	else:
		_execute_save("manual")

func _execute_save(slot_type: String) -> void:
	var sm := _get_save_manager()
	if sm == null:
		return
	var res: Dictionary = sm.save_game(slot_type)
	if res.get("success", false):
		_show_status("Progres berhasil disimpan ke slot manual (Rev %d)." % res.get("revision", 0), false)
		save_requested.emit(slot_type)
	else:
		_show_status(str(res.get("message", "Progres belum tersimpan. Coba lagi atau gunakan lokasi simpan yang dapat ditulis.")), true)

func _on_load_pressed() -> void:
	_refresh_slot_picker()
	push_subpanel(slot_picker_modal, slot_manual_btn if not slot_manual_btn.disabled else btn_close_slot_picker)

func _refresh_slot_picker() -> void:
	var sm := _get_save_manager()
	if sm == null:
		return
	var manual_meta: Dictionary = sm.get_slot_metadata("manual")
	if manual_meta.get("valid", false):
		slot_manual_btn.text = "Slot Manual — Rev %d (%s)" % [manual_meta.get("revision", 1), manual_meta.get("timestamp_iso", "")]
		slot_manual_btn.disabled = false
	else:
		slot_manual_btn.text = "Slot Manual — [Kosong]"
		slot_manual_btn.disabled = true

	var auto_meta: Dictionary = sm.get_slot_metadata("autosave")
	if auto_meta.get("valid", false):
		slot_auto_btn.text = "Slot Otomatis — Rev %d (%s)" % [auto_meta.get("revision", 1), auto_meta.get("timestamp_iso", "")]
		slot_auto_btn.disabled = false
	else:
		slot_auto_btn.text = "Slot Otomatis — [Kosong]"
		slot_auto_btn.disabled = true

func _on_slot_selected(slot_type: String) -> void:
	_show_confirm(
		"Peringatan Muat Simpanan",
		"Perubahan sejak simpanan terakhir akan hilang.\nApakah Anda yakin ingin memuat slot '%s'?" % slot_type,
		"Ya, Muat",
		func(): _execute_load(slot_type),
		"",
		Callable()
	)

func _execute_load(slot_type: String) -> void:
	var sm := _get_save_manager()
	if sm == null:
		return
	var res: Dictionary = sm.load_game(slot_type)
	if res.get("success", false):
		_show_status("Simpanan '%s' berhasil dimuat." % slot_type, false)
		load_requested.emit(slot_type)
		pop_subpanel() # pop confirm
		pop_subpanel() # pop picker
		resume_game()  # return to live world
	else:
		_show_status(str(res.get("message", "Gagal memuat simpanan.")), true)

func _on_return_home_pressed() -> void:
	_show_confirm(
		"Kembali ke Posisi Aman",
		"Pindahkan posisi pemain kembali ke pekarangan rumah?\n(Kondisi inventaris, kebun, dan masakan tetap utuh).",
		"Pindahkan",
		_execute_return_home,
		"",
		Callable()
	)

func _execute_return_home() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var p = tree.root.find_child("Player", true, false)
		if p:
			p.global_position = Vector3(0.0, 0.0, 8.0)
			if "velocity" in p:
				p.velocity = Vector3.ZERO
	resume_game()

func _on_new_game_pressed() -> void:
	_show_confirm(
		"Mulai Game Baru?",
		"Progres yang belum disimpan akan hilang.\nMulai permainan baru dari awal?",
		"Mulai Baru",
		_execute_new_game,
		"",
		Callable()
	)

func _execute_new_game() -> void:
	new_game_requested.emit()
	resume_game()

func _on_settings_pressed() -> void:
	if settings_panel:
		settings_panel.load_current_settings()
		push_subpanel(settings_panel)
		settings_panel.grab_initial_focus()

func _on_exit_pressed() -> void:
	_show_confirm(
		"Peringatan Keluar Permainan",
		"Kemajuan permainan belum tentu tersimpan ke checkpoint.\nPilih tindakan sebelum keluar:",
		"Simpan & Keluar",
		_execute_save_and_exit,
		"Keluar Tanpa Simpan",
		_execute_exit_without_saving
	)

func _execute_save_and_exit() -> void:
	var sm := _get_save_manager()
	if sm:
		var res: Dictionary = sm.save_game("manual")
		if not res.get("success", false):
			# T49, T53: Jangan keluar jika save gagal, tetap di menu dan jelaskan!
			_show_status(str(res.get("message", "Progres belum tersimpan. Coba lagi atau gunakan lokasi simpan yang dapat ditulis.")), true)
			return
	_execute_exit_without_saving()

func _execute_exit_without_saving() -> void:
	exit_requested.emit()
	_exit_called_in_test = true
	var tree := get_tree()
	if tree != null:
		tree.quit()

func _show_confirm(title: String, msg: String, btn1_text: String, btn1_action: Callable, btn2_text: String = "", btn2_action: Callable = Callable()) -> void:
	if modal_title: modal_title.text = title
	if modal_message: modal_message.text = msg

	if modal_btn_1:
		modal_btn_1.text = btn1_text
		modal_btn_1.visible = true
		for conn in modal_btn_1.pressed.get_connections():
			modal_btn_1.pressed.disconnect(conn.callable)
		modal_btn_1.pressed.connect(func():
			pop_subpanel()
			btn1_action.call()
		)

	if modal_btn_2:
		if btn2_text.is_empty():
			modal_btn_2.visible = false
		else:
			modal_btn_2.text = btn2_text
			modal_btn_2.visible = true
			for conn in modal_btn_2.pressed.get_connections():
				modal_btn_2.pressed.disconnect(conn.callable)
			modal_btn_2.pressed.connect(func():
				pop_subpanel()
				btn2_action.call()
			)

	# Safe focus default: modal_btn_cancel
	push_subpanel(confirm_modal, modal_btn_cancel)

func _show_status(msg: String, is_error: bool) -> void:
	if status_label:
		status_label.text = msg
		status_label.modulate = Color(1.0, 0.4, 0.4) if is_error else Color(0.4, 1.0, 0.4)

func _get_input_manager() -> Node:
	if Engine.has_singleton("InputManager"):
		return Engine.get_singleton("InputManager")
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("InputManager"):
		return tree.root.get_node("InputManager")
	return null

func _get_save_manager() -> Node:
	if Engine.has_singleton("SaveManager"):
		return Engine.get_singleton("SaveManager")
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("SaveManager"):
		return tree.root.get_node("SaveManager")
	return null
