class_name DialogueUI
extends CanvasLayer

## Antarmuka Dialog Warga untuk 'Buku Resep 2045'
## Memenuhi spesifikasi PRD FR02, UI_UX.md UI07, § 3, § 4, dan TEST_PLAN T43..T45

@onready var root_control: Control = $RootControl if has_node("RootControl") else (find_child("RootControl", true, false) as Control)
@onready var dialogue_panel: PanelContainer = find_child("DialoguePanel", true, false) as PanelContainer
@onready var speaker_name_label: Label = find_child("SpeakerNameLabel", true, false) as Label
@onready var dialogue_text_label: Label = find_child("DialogueTextLabel", true, false) as Label
@onready var close_button: Button = find_child("CloseButton", true, false) as Button
@onready var choices_container: VBoxContainer = find_child("ChoicesContainer", true, false) as VBoxContainer

# Modal Konfirmasi Berbagi Hidangan
@onready var confirm_modal: Control = find_child("ConfirmModal", true, false) as Control
@onready var confirm_message: Label = find_child("ModalMessage", true, false) as Label
@onready var confirm_yes_button: Button = find_child("ConfirmYesButton", true, false) as Button
@onready var confirm_no_button: Button = find_child("ConfirmNoButton", true, false) as Button

var _dialogue_manager_override: Node = null
var _input_manager_override: Node = null
var _last_focused_choice: Control = null
var _pending_share_source: String = "backpack"

func _ready() -> void:
	visible = false
	if confirm_modal != null:
		confirm_modal.visible = false

	if close_button != null:
		close_button.pressed.connect(close)
	if confirm_yes_button != null:
		confirm_yes_button.pressed.connect(_on_confirm_share_yes)
	if confirm_no_button != null:
		confirm_no_button.pressed.connect(_on_cancel_share_pressed)

	_connect_manager_signals()

func _connect_manager_signals() -> void:
	var im := _get_input_manager()
	if im != null and im.has_signal("context_changed"):
		if not im.context_changed.is_connected(_on_context_changed):
			im.context_changed.connect(_on_context_changed)

	var dm := _get_dialogue_manager()
	if dm != null:
		if dm.has_signal("dialogue_node_changed") and not dm.dialogue_node_changed.is_connected(_on_dialogue_node_changed):
			dm.dialogue_node_changed.connect(_on_dialogue_node_changed)
		if dm.has_signal("dialogue_ended") and not dm.dialogue_ended.is_connected(_on_dialogue_ended):
			dm.dialogue_ended.connect(_on_dialogue_ended)

func _on_context_changed(new_ctx: int, _old_ctx: int) -> void:
	var im := _get_input_manager()
	if im == null:
		return
	if new_ctx == im.ContextMode.DIALOGUE:
		if not visible:
			open()
	elif visible:
		visible = false
		if confirm_modal != null:
			confirm_modal.visible = false

func _on_dialogue_node_changed(_node_id: String, node_data: Dictionary) -> void:
	display_node(node_data)

func open(initial_node_id: String = "") -> void:
	visible = true
	if confirm_modal != null:
		confirm_modal.visible = false

	# Pasang context DIALOGUE jika belum aktif
	var im := _get_input_manager()
	if im != null and im.has_method("is_world_context") and im.is_world_context():
		im.push_context(im.ContextMode.DIALOGUE)

	# Cegah tombol 'E' pembuka dialog memicu pilihan pertama pada frame yang sama
	if im != null and im.has_method("suppress_action_until_released"):
		im.suppress_action_until_released(&"interact")

	var dm := _get_dialogue_manager()
	if dm != null and dm.has_method("start_dialogue"):
		var node_data: Dictionary = dm.start_dialogue("npc_neighbor_01", initial_node_id)
		display_node(node_data)
	else:
		# Fallback display jika manager belum dipasang
		display_node({
			"speaker": "Tetangga",
			"text": "Masih menyimpan buku itu? Coba lihat kebun di ujung jalan. Jagungnya belum semua habis.",
			"choices": [
				{"id": "choice_hint_bayam", "text": "Bayamnya dari mana?"},
				{"id": "choice_hint_kunci", "text": "Temu kunci?"},
				{"id": "choice_close", "text": "Tutup"}
			]
		})

	call_deferred("_grab_initial_focus")

func _grab_initial_focus() -> void:
	if not visible:
		return
	if confirm_modal != null and confirm_modal.visible:
		if confirm_yes_button != null:
			confirm_yes_button.grab_focus()
		return

	if choices_container != null and choices_container.get_child_count() > 0:
		var btn = choices_container.get_child(0) as Control
		if btn != null and btn.is_visible_in_tree() and btn.focus_mode != Control.FOCUS_NONE:
			btn.grab_focus()
			return
	if close_button != null and close_button.is_visible_in_tree():
		close_button.grab_focus()

func close() -> void:
	if not visible:
		return
	visible = false
	if confirm_modal != null:
		confirm_modal.visible = false

	var dm := _get_dialogue_manager()
	if dm != null and dm.has_method("is_dialogue_active") and dm.is_dialogue_active():
		if dm.has_method("end_dialogue"):
			dm.end_dialogue()

	var im := _get_input_manager()
	if im != null and im.has_method("get_current_context"):
		if im.get_current_context() == im.ContextMode.DIALOGUE:
			im.consume_and_close(&"interact")

func _on_dialogue_ended() -> void:
	if not visible:
		return
	visible = false
	if confirm_modal != null:
		confirm_modal.visible = false

	var im := _get_input_manager()
	if im != null and im.has_method("get_current_context"):
		if im.get_current_context() == im.ContextMode.DIALOGUE:
			im.consume_and_close(&"interact")

func display_node(node_data: Dictionary) -> void:
	if speaker_name_label != null:
		speaker_name_label.text = str(node_data.get("speaker", "Tetangga"))
	if dialogue_text_label != null:
		dialogue_text_label.text = str(node_data.get("text", ""))

	if choices_container == null:
		return

	# Kosongkan tombol pilihan lama
	for child in choices_container.get_children():
		child.queue_free()

	var choices: Array = node_data.get("choices", [])
	var btn_index: int = 0
	var previous_btn: Button = null

	for choice in choices:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 36)
		btn.focus_mode = Control.FOCUS_ALL
		var choice_text: String = str(choice.get("text", ""))
		btn.text = "%d. %s" % [btn_index + 1, choice_text]
		var choice_id: String = str(choice.get("id", ""))
		btn.pressed.connect(func(): _on_choice_pressed(choice_id))

		choices_container.add_child(btn)

		# Hubungkan tetangga fokus Atas / Bawah untuk keyboard & gamepad
		if previous_btn != null:
			previous_btn.focus_neighbor_bottom = btn.get_path()
			btn.focus_neighbor_top = previous_btn.get_path()
		previous_btn = btn
		btn_index += 1

	if previous_btn != null and close_button != null:
		previous_btn.focus_neighbor_bottom = close_button.get_path()
		close_button.focus_neighbor_top = previous_btn.get_path()

	call_deferred("_grab_initial_focus")

func _on_choice_pressed(choice_id: String) -> void:
	if choice_id == "choice_close" or choice_id == "close":
		close()
		return

	if choice_id == "choice_share_confirm" or choice_id == "action_share":
		_prompt_share_confirmation()
		return

	var dm := _get_dialogue_manager()
	if dm != null and dm.has_method("select_choice"):
		var res: Dictionary = dm.select_choice(choice_id)
		if res.has("node"):
			display_node(res["node"])
		elif dm.has_method("get_current_node_data"):
			display_node(dm.get_current_node_data())

func _prompt_share_confirmation() -> void:
	_last_focused_choice = get_viewport().gui_get_focus_owner()
	var dm := _get_dialogue_manager()
	_pending_share_source = "backpack"
	if dm != null and dm.has_method("get_dish_source"):
		_pending_share_source = dm.get_dish_source()
		if _pending_share_source.is_empty():
			_pending_share_source = "backpack"

	if confirm_message != null:
		var src_text := "dari Tas" if _pending_share_source == "backpack" else "dari Peti Rumah"
		confirm_message.text = "Bagikan 1 porsi hidangan ini?\n(1 porsi Sayur Bening Bayam dan Jagung %s)" % src_text

	if confirm_modal != null:
		confirm_modal.visible = true
		if confirm_yes_button != null:
			confirm_yes_button.grab_focus()

func _on_confirm_share_yes() -> void:
	if confirm_modal != null:
		confirm_modal.visible = false

	var dm := _get_dialogue_manager()
	if dm != null and dm.has_method("share_dish"):
		var res: Dictionary = dm.share_dish(_pending_share_source)
		if dm.has_method("get_current_node_data"):
			display_node(dm.get_current_node_data())
		if res.get("p0_completed", false) and res.get("newly_completed_p0", false):
			_show_ending_toast(str(res.get("message", "Satu resep selesai. Kebun ini baru dimulai.")))

func _on_cancel_share_pressed() -> void:
	if confirm_modal != null:
		confirm_modal.visible = false

	# Kembalikan fokus ke pilihan sebelumnya
	if _last_focused_choice != null and is_instance_valid(_last_focused_choice):
		_last_focused_choice.grab_focus()
	else:
		call_deferred("_grab_initial_focus")

func _show_ending_toast(msg: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var hud = tree.root.find_child("HUD", true, false)
		if hud != null and hud.has_method("show_feedback"):
			hud.show_feedback(msg, 4.0)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause_menu") and not event.is_echo():
		if confirm_modal != null and confirm_modal.visible:
			_on_cancel_share_pressed()
			get_viewport().set_input_as_handled()
		else:
			close()
			get_viewport().set_input_as_handled()

func _get_dialogue_manager() -> Node:
	if _dialogue_manager_override != null and is_instance_valid(_dialogue_manager_override):
		return _dialogue_manager_override
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

func _get_input_manager() -> Node:
	if _input_manager_override != null and is_instance_valid(_input_manager_override):
		return _input_manager_override
	if Engine.has_singleton("InputManager"):
		return Engine.get_singleton("InputManager")
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var node = tree.root.get_node_or_null("InputManager")
		if node != null:
			return node
	if is_inside_tree() and has_node("/root/InputManager"):
		return get_node("/root/InputManager")
	return null
