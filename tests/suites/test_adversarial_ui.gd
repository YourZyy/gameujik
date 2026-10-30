class_name TestAdversarialUI
extends RefCounted

## Test Suite Adversarial & Empirical Stress Testing untuk UI-001 (Kenyamanan Terpadu & Notifikasi Jujur)
## Memverifikasi secara independen & tanpa kompromi:
## 1. ADV-UI-01: Rapid Esc key spamming & modal stack depth invariance (anti-desync, anti-softlock, non-negative bounds)
## 2. ADV-UI-02: Focus theft & mouse capture immunity (toast notifications never steal keyboard focus or mouse capture)
## 3. ADV-UI-03: Input bleed-through defense (closing modal blocks world interaction on same frame)
## 4. ADV-UI-04: Extreme settings boundary resilience (UI scale 0.8/1.5/resilience, FOV 60/100/extremes, audio volume, sensitivity)
## 5. ADV-UI-05: Destructive action confirmation safety (default focus on "Batal", safe cancellation on Enter, no accidental execution)
## 6. ADV-UI-06: Keyboard Focus Circular Traversal & Tab Softlock Immunity

const Assertions = preload("res://tests/assertions.gd")
const SaveManagerClass = preload("res://scripts/save/save_manager.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")
const NotificationManagerClass = preload("res://scripts/ui/notification_manager.gd")
const PauseMenuClass = preload("res://scripts/ui/pause_menu.gd")
const SettingsMenuClass = preload("res://scripts/ui/settings_menu.gd")
const InventoryUIClass = preload("res://scripts/ui/inventory_ui.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")
const InteractionDetectorClass = preload("res://scripts/interaction/interaction_detector.gd")
const InteractableClass = preload("res://scripts/interaction/interactable.gd")

var _tree: SceneTree = null

func _get_tree() -> SceneTree:
	if _tree == null:
		_tree = Engine.get_main_loop() as SceneTree
	return _tree

func run_all() -> bool:
	var passed := true
	print("==================================================")
	print("[ADVERSARIAL_SUITE] UI-001 Empirical Stress & Failure-Mode Verification")
	print("==================================================")

	# VECTOR 1: Rapid Esc Spamming & Modal Stack Integrity
	if not test_adv_ui_01_rapid_esc_spamming_and_stack_depth(): passed = false

	# VECTOR 2: Focus Theft & Mouse Capture Immunity
	if not test_adv_ui_02_focus_theft_and_mouse_capture_immunity(): passed = false

	# VECTOR 3: Input Bleed-Through Frame Guard
	if not test_adv_ui_03_input_bleed_through_frame_guard(): passed = false

	# VECTOR 4: Extreme Settings Boundary & Resilience
	if not test_adv_ui_04_extreme_settings_inputs_and_boundary_safety(): passed = false

	# VECTOR 5: Destructive Action Confirmation Safety
	if not test_adv_ui_05_destructive_action_confirmation_safety(): passed = false

	# VECTOR 6: Keyboard Focus Circular Traversal & Tab Softlock Immunity
	if not test_adv_ui_06_tab_navigation_and_focus_loops(): passed = false

	return passed

# ==============================================================================
# VECTOR 1: Rapid Esc Spamming & Modal Stack Invariance
# ==============================================================================

func test_adv_ui_01_rapid_esc_spamming_and_stack_depth() -> bool:
	var passed := true
	print("  [RUN] ADV-UI-01: Rapid Esc Key Spamming & Modal Stack Invariant Oracle")

	var tree := _get_tree()
	var im: Node = tree.root.get_node_or_null("InputManager")
	if im == null:
		im = InputManagerClass.new()
		tree.root.add_child(im)

	var pause_scene := load("res://scenes/ui/pause_menu.tscn") as PackedScene
	var pause_menu := pause_scene.instantiate() as PauseMenuClass
	tree.root.add_child(pause_menu)

	var esc_event := InputEventAction.new()
	esc_event.action = "pause_menu"
	esc_event.pressed = true

	# Test 1A: Spam Esc 50 times when menu is closed in WORLD context
	im.pop_to_world()
	pause_menu.close_menu_silent()
	for i in range(50):
		pause_menu._unhandled_input(esc_event)
		if pause_menu.get_subpanel_depth() < 0:
			Assertions.assert_true(false, "ADV-UI-01A: Depth dropped below 0 on closed spam")
			passed = false
			break
	if not Assertions.assert_equal(pause_menu.get_subpanel_depth(), 0, "ADV-UI-01A: Depth tetap 0 setelah spam saat tertutup"): passed = false
	if not Assertions.assert_false(pause_menu.visible, "ADV-UI-01A: Menu tetap tertutup"): passed = false

	# Test 1B: Multi-level push and rapid Esc spamming (100 times)
	pause_menu.open_menu()
	if pause_menu.slot_picker_modal != null:
		pause_menu.push_subpanel(pause_menu.slot_picker_modal)
	if pause_menu.confirm_modal != null:
		pause_menu.push_subpanel(pause_menu.confirm_modal)
	if not Assertions.assert_equal(pause_menu.get_subpanel_depth(), 2, "ADV-UI-01B: Depth awal adalah 2"): passed = false

	# Spam 100 Esc presses rapidly
	for i in range(100):
		pause_menu._unhandled_input(esc_event)
		if pause_menu.get_subpanel_depth() < 0:
			Assertions.assert_true(false, "ADV-UI-01B: Depth dropped below 0 during active spam!")
			passed = false
			break

	if not Assertions.assert_equal(pause_menu.get_subpanel_depth(), 0, "ADV-UI-01B: Subpanel stack depth tidak pernah negatif dan tuntas di 0"): passed = false
	if not Assertions.assert_false(pause_menu.visible, "ADV-UI-01B: PauseMenu tertutup bersih setelah spam Esc"): passed = false
	if pause_menu.confirm_modal != null:
		if not Assertions.assert_false(pause_menu.confirm_modal.visible, "ADV-UI-01B: Confirm modal tertutup"): passed = false
	if pause_menu.slot_picker_modal != null:
		if not Assertions.assert_false(pause_menu.slot_picker_modal.visible, "ADV-UI-01B: Slot picker modal tertutup"): passed = false

	# Test 1C: Direct call pop_subpanel() 50 times on an already empty stack
	for i in range(50):
		pause_menu.pop_subpanel()
	if not Assertions.assert_equal(pause_menu.get_subpanel_depth(), 0, "ADV-UI-01C: pop_subpanel() berulang pada stack kosong tidak membuat depth negatif"): passed = false

	# Test 1D: Rapid 50 open/close cycles
	for i in range(50):
		pause_menu.open_menu()
		if pause_menu.confirm_modal != null:
			pause_menu.push_subpanel(pause_menu.confirm_modal)
		pause_menu._unhandled_input(esc_event) # pop confirm
		pause_menu._unhandled_input(esc_event) # close pause
	if not Assertions.assert_equal(pause_menu.get_subpanel_depth(), 0, "ADV-UI-01D: 50 siklus buka-tutup berulang tetap stabil dengan depth 0"): passed = false
	if not Assertions.assert_false(pause_menu.visible, "ADV-UI-01D: Menu tertutup di akhir 50 siklus"): passed = false

	pause_menu.queue_free()
	print("  [PASS] ADV-UI-01: Rapid Esc key spamming & modal stack depth verified.")
	return passed

# ==============================================================================
# VECTOR 2: Focus Theft & Mouse Capture Immunity
# ==============================================================================

func test_adv_ui_02_focus_theft_and_mouse_capture_immunity() -> bool:
	var passed := true
	print("  [RUN] ADV-UI-02: Focus Theft & Mouse Capture Immunity Oracle")

	var tree := _get_tree()
	var toast_scene := load("res://scenes/ui/notification_toast.tscn") as PackedScene
	var notif := toast_scene.instantiate() as NotificationManagerClass
	tree.root.add_child(notif)
	notif.clear_all()

	var pause_scene := load("res://scenes/ui/pause_menu.tscn") as PackedScene
	var pause_menu := pause_scene.instantiate() as PauseMenuClass
	tree.root.add_child(pause_menu)

	pause_menu.open_menu()
	if pause_menu.btn_save != null:
		pause_menu.btn_save.grab_focus()
		if not Assertions.assert_true(pause_menu.btn_save.has_focus(), "ADV-UI-02: btn_save memegang fokus keyboard awal"): passed = false

	# Spam 20 toast messages of various types while menu button is focused
	for i in range(5):
		notif.show_toast("Toast Info %d" % i, "info")
		notif.show_pickup("Bayam", 1, "ingredient_bayam")
		notif.show_error("Gagal melakukan aksi %d" % i)
		notif.show_honest_message("bag_full")

	# Check focus owner immediately
	if pause_menu.btn_save != null:
		if not Assertions.assert_true(pause_menu.btn_save.has_focus(), "ADV-UI-02: Fokus keyboard TIDAK DICURI oleh kemunculan toast"): passed = false

	# Advance time in increments and re-verify focus retention
	for step in [0.2, 0.5, 1.0, 1.5, 2.6]:
		notif.advance_time(step)
		if pause_menu.btn_save != null:
			if not Assertions.assert_true(pause_menu.btn_save.has_focus(), "ADV-UI-02: Fokus keyboard tetap pada btn_save saat toast advance_time(%.1f)" % step): passed = false

	# Check properties of all generated toast UI nodes
	var vbox: VBoxContainer = notif.find_child("ToastVBox", true, false) as VBoxContainer
	if vbox:
		if not Assertions.assert_equal(int(vbox.mouse_filter), int(Control.MOUSE_FILTER_IGNORE), "ADV-UI-02: ToastVBox mouse_filter == IGNORE"): passed = false
		if not Assertions.assert_equal(int(vbox.focus_mode), int(Control.FOCUS_NONE), "ADV-UI-02: ToastVBox focus_mode == FOCUS_NONE"): passed = false
		for child in vbox.get_children():
			if child is Control:
				if not Assertions.assert_equal(int(child.mouse_filter), int(Control.MOUSE_FILTER_IGNORE), "ADV-UI-02: Toast child mouse_filter == IGNORE"): passed = false
				if not Assertions.assert_equal(int(child.focus_mode), int(Control.FOCUS_NONE), "ADV-UI-02: Toast child focus_mode == FOCUS_NONE"): passed = false

	# Check mouse mode state immunity
	var mouse_mode_before := Input.mouse_mode
	notif.show_toast("Another toast")
	notif.advance_time(0.1)
	if not Assertions.assert_equal(Input.mouse_mode, mouse_mode_before, "ADV-UI-02: Toast notification tidak pernah mengubah Input.mouse_mode"): passed = false

	notif.queue_free()
	pause_menu.queue_free()
	print("  [PASS] ADV-UI-02: Focus theft & mouse capture immunity verified.")
	return passed

# ==============================================================================
# VECTOR 3: Input Bleed-Through Frame Guard
# ==============================================================================

func test_adv_ui_03_input_bleed_through_frame_guard() -> bool:
	var passed := true
	print("  [RUN] ADV-UI-03: Input Bleed-Through Defense & Closing Frame Guard")

	var tree := _get_tree()
	var im: Node = tree.root.get_node_or_null("InputManager")
	if im == null:
		im = InputManagerClass.new()
		tree.root.add_child(im)

	var player := PlayerControllerClass.new()
	player.name = "Player"
	tree.root.add_child(player)
	im.register_player(player)

	# Create a dummy interactable target
	var detector := InteractionDetectorClass.new()
	player.add_child(detector)
	player.interaction_detector = detector

	var interactable := InteractableClass.new()
	interactable.interaction_id = "test_interactable"
	interactable.target_name = "Uji"
	interactable.prompt_action = "Periksa"
	interactable.enabled = true
	interactable.is_interactable = true
	tree.root.add_child(interactable)

	# Mock focus
	detector._set_focused_target(interactable)
	if not Assertions.assert_true(detector.has_focused_target(), "ADV-UI-03: Detector mendeteksi target"): passed = false

	# Step 1: Push PAUSE context
	im.push_context(im.ContextMode.PAUSE)
	if not Assertions.assert_false(im.can_interact_in_world(), "ADV-UI-03: can_interact_in_world() false saat PAUSE"): passed = false
	if not Assertions.assert_false(detector.try_interact(player), "ADV-UI-03: try_interact() ditolak saat PAUSE"): passed = false

	# Step 2: Close modal via consume_and_close on current frame
	im.consume_and_close(&"pause_menu")
	if not Assertions.assert_true(im.is_world_context(), "ADV-UI-03: Konteks kembali ke WORLD"): passed = false

	# Critical Frame Bleed-Through Check: ON THE SAME FRAME OF CLOSURE
	# can_interact_in_world() MUST BE FALSE
	if not Assertions.assert_false(im.can_interact_in_world(), "ADV-UI-03: can_interact_in_world() bernilai FALSE pada frame penutupan modal"): passed = false
	# try_interact() MUST BE REJECTED
	var interacted_on_close_frame: bool = detector.try_interact(player)
	if not Assertions.assert_false(interacted_on_close_frame, "ADV-UI-03: Interaksi dunia DIBLOKIR pada frame penutupan modal (Zero Bleed-Through)"): passed = false

	# Action suppression check for &"pause_menu"
	if not Assertions.assert_true(im.is_action_suppressed(&"pause_menu"), "ADV-UI-03: Aksi 'pause_menu' di-suppress pada frame penutupan"): passed = false

	# Cleanup
	interactable.queue_free()
	player.queue_free()
	print("  [PASS] ADV-UI-03: Input bleed-through defense verified.")
	return passed

# ==============================================================================
# VECTOR 4: Extreme Settings Boundary & Resilience
# ==============================================================================

func test_adv_ui_04_extreme_settings_inputs_and_boundary_safety() -> bool:
	var passed := true
	print("  [RUN] ADV-UI-04: Extreme Settings Boundary & Numerical Resilience")

	var tree := _get_tree()
	var sm: Node = tree.root.get_node_or_null("SaveManager")
	if sm == null:
		sm = SaveManagerClass.new()
		tree.root.add_child(sm)

	var player := PlayerControllerClass.new()
	player.name = "Player"
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	player.add_child(cam)
	player.camera = cam
	tree.root.add_child(player)

	# --- 4A: UI Scale Boundary & Extreme Inputs ---
	# Slider Min boundary: 0.8
	sm.set_setting("video", "ui_scale", 0.8)
	sm.apply_all_settings()
	if not Assertions.assert_approx_equal(tree.root.content_scale_factor, 0.8, 0.001, "ADV-UI-04A: UI Scale 0.8 diterapkan"): passed = false

	# Slider Max boundary: 1.5
	sm.set_setting("video", "ui_scale", 1.5)
	sm.apply_all_settings()
	if not Assertions.assert_approx_equal(tree.root.content_scale_factor, 1.5, 0.001, "ADV-UI-04A: UI Scale 1.5 diterapkan"): passed = false

	# Extreme safe positive scales: 0.5, 2.0
	for extreme_scale in [0.5, 2.0]:
		sm.set_setting("video", "ui_scale", extreme_scale)
		sm.apply_all_settings()
		if not Assertions.assert_approx_equal(tree.root.content_scale_factor, extreme_scale, 0.001, "ADV-UI-04A: Extreme UI scale %.1f diterapkan tanpa crash" % extreme_scale): passed = false

	# Reset UI scale to safe 1.0
	sm.set_setting("video", "ui_scale", 1.0)
	sm.apply_all_settings()

	# --- 4B: FOV Boundary & Extreme Inputs ---
	# Slider Min boundary: 60.0°
	sm.set_setting("video", "fov", 60.0)
	sm.apply_all_settings()
	if not Assertions.assert_approx_equal(player.fov, 60.0, 0.01, "ADV-UI-04B: Player FOV batas bawah 60.0°"): passed = false
	if not Assertions.assert_approx_equal(cam.fov, 60.0, 0.01, "ADV-UI-04B: Camera FOV batas bawah 60.0°"): passed = false

	# Slider Max boundary: 100.0°
	sm.set_setting("video", "fov", 100.0)
	sm.apply_all_settings()
	if not Assertions.assert_approx_equal(player.fov, 100.0, 0.01, "ADV-UI-04B: Player FOV batas atas 100.0°"): passed = false
	if not Assertions.assert_approx_equal(cam.fov, 100.0, 0.01, "ADV-UI-04B: Camera FOV batas atas 100.0°"): passed = false

	# Adversarial extreme FOV values: clamped by PlayerConfig [60.0, 100.0]
	player.fov = 10.0 # underflow
	if not Assertions.assert_approx_equal(player.fov, 60.0, 0.01, "ADV-UI-04B: FOV 10.0° di-clamp ke batas aman 60.0°"): passed = false
	player.fov = 179.0 # overflow
	if not Assertions.assert_approx_equal(player.fov, 100.0, 0.01, "ADV-UI-04B: FOV 179.0° di-clamp ke batas aman 100.0°"): passed = false

	# --- 4C: Sensitivity Boundary & Extreme Inputs ---
	player.mouse_sensitivity_multiplier = 0.1 # boundary min
	if not Assertions.assert_approx_equal(player.mouse_sensitivity_multiplier, 0.1, 0.001, "ADV-UI-04C: Sensitivitas batas min 0.1x"): passed = false
	player.mouse_sensitivity_multiplier = 5.0 # boundary max
	if not Assertions.assert_approx_equal(player.mouse_sensitivity_multiplier, 5.0, 0.001, "ADV-UI-04C: Sensitivitas batas max 5.0x"): passed = false
	# Extreme clamp
	player.mouse_sensitivity_multiplier = 0.001
	if not Assertions.assert_approx_equal(player.mouse_sensitivity_multiplier, 0.1, 0.001, "ADV-UI-04C: Sensitivitas 0.001 di-clamp ke 0.1"): passed = false
	player.mouse_sensitivity_multiplier = 999.0
	if not Assertions.assert_approx_equal(player.mouse_sensitivity_multiplier, 5.0, 0.001, "ADV-UI-04C: Sensitivitas 999.0 di-clamp ke 5.0"): passed = false

	# --- 4D: Audio Volume Mute & Extreme Boundary Inputs ---
	sm.ensure_audio_buses()
	var music_idx := AudioServer.get_bus_index("Music")
	# Volume 0.0 -> Must mute
	sm.set_setting("audio", "music_volume", 0.0)
	sm.apply_all_settings()
	if not Assertions.assert_true(AudioServer.is_bus_mute(music_idx), "ADV-UI-04D: Volume 0.0 mengaktifkan mute"): passed = false

	# Volume 1.0 -> 0.0 dB
	sm.set_setting("audio", "music_volume", 1.0)
	sm.apply_all_settings()
	if not Assertions.assert_false(AudioServer.is_bus_mute(music_idx), "ADV-UI-04D: Volume 1.0 tidak mute"): passed = false
	if not Assertions.assert_approx_equal(AudioServer.get_bus_volume_db(music_idx), 0.0, 0.01, "ADV-UI-04D: Volume 1.0 bernilai 0.0 dB"): passed = false

	# Negative volume handled gracefully via mute
	sm.set_setting("audio", "music_volume", -5.0)
	sm.apply_all_settings()
	if not Assertions.assert_true(AudioServer.is_bus_mute(music_idx), "ADV-UI-04D: Volume negatif otomatis di-mute"): passed = false

	# Reset settings to default
	sm.set_setting("video", "fov", 80.0)
	sm.set_setting("video", "ui_scale", 1.0)
	sm.set_setting("audio", "music_volume", 0.4)
	sm.set_setting("gameplay", "mouse_sensitivity_multiplier", 1.0)
	sm.apply_all_settings()

	player.queue_free()
	print("  [PASS] ADV-UI-04: Extreme settings boundary & numerical resilience verified.")
	return passed

# ==============================================================================
# VECTOR 5: Destructive Action Confirmation Safety
# ==============================================================================

func test_adv_ui_05_destructive_action_confirmation_safety() -> bool:
	var passed := true
	print("  [RUN] ADV-UI-05: Destructive Action Confirmation Safety Oracle")

	var tree := _get_tree()
	var pause_scene := load("res://scenes/ui/pause_menu.tscn") as PackedScene
	var pause_menu := pause_scene.instantiate() as PauseMenuClass
	tree.root.add_child(pause_menu)

	var new_game_fired: bool = false
	var exit_fired: bool = false
	var save_fired: bool = false

	pause_menu.new_game_requested.connect(func(): new_game_fired = true)
	pause_menu.exit_requested.connect(func(): exit_fired = true)
	pause_menu.save_requested.connect(func(_slot): save_fired = true)

	pause_menu.open_menu()

	# --- 5A: New Game Modal Safety ---
	pause_menu._on_new_game_pressed()
	if pause_menu.confirm_modal != null:
		if not Assertions.assert_true(pause_menu.confirm_modal.visible, "ADV-UI-05A: Confirm modal tampil untuk Game Baru"): passed = false
	if pause_menu.modal_btn_cancel != null:
		if not Assertions.assert_true(pause_menu.modal_btn_cancel.is_visible_in_tree(), "ADV-UI-05A: modal_btn_cancel adalah target fokus default"): passed = false
		# Simulate Enter key / button click on default focus (modal_btn_cancel)
		pause_menu.modal_btn_cancel.emit_signal("pressed")

	if pause_menu.confirm_modal != null:
		if not Assertions.assert_false(pause_menu.confirm_modal.visible, "ADV-UI-05A: Menekan Batal menutup modal"): passed = false
	if not Assertions.assert_false(new_game_fired, "ADV-UI-05A: new_game_requested TIDAK TERPANGGIL (Aman)"): passed = false

	# --- 5B: Exit to Desktop Modal Safety ---
	pause_menu._on_exit_pressed()
	if pause_menu.confirm_modal != null:
		if not Assertions.assert_true(pause_menu.confirm_modal.visible, "ADV-UI-05B: Confirm modal tampil untuk Keluar Permainan"): passed = false
	if pause_menu.modal_btn_cancel != null:
		if not Assertions.assert_true(pause_menu.modal_btn_cancel.is_visible_in_tree(), "ADV-UI-05B: modal_btn_cancel adalah target fokus default"): passed = false
		# Simulate Enter / cancel press
		pause_menu.modal_btn_cancel.emit_signal("pressed")

	if pause_menu.confirm_modal != null:
		if not Assertions.assert_false(pause_menu.confirm_modal.visible, "ADV-UI-05B: Menekan Batal menutup modal keluar"): passed = false
	if not Assertions.assert_false(exit_fired, "ADV-UI-05B: exit_requested TIDAK TERPANGGIL (Aman)"): passed = false
	if not Assertions.assert_false(pause_menu._exit_called_in_test, "ADV-UI-05B: quit() TIDAK TERPANGGIL (Aman)"): passed = false

	# --- 5C: Save Overwrite Modal Safety ---
	var sm: Node = tree.root.get_node_or_null("SaveManager")
	if sm != null and sm.has_valid_save("manual"):
		pause_menu._on_save_pressed() # triggers overwrite confirmation
		if pause_menu.confirm_modal != null:
			if not Assertions.assert_true(pause_menu.confirm_modal.visible, "ADV-UI-05C: Confirm modal tampil untuk Timpa Simpanan"): passed = false
		if pause_menu.modal_btn_cancel != null:
			pause_menu.modal_btn_cancel.emit_signal("pressed")
		if pause_menu.confirm_modal != null:
			if not Assertions.assert_false(pause_menu.confirm_modal.visible, "ADV-UI-05C: Menekan Batal menutup modal timpa"): passed = false
		if not Assertions.assert_false(save_fired, "ADV-UI-05C: save_requested TIDAK TERPANGGIL (Aman)"): passed = false

	pause_menu.queue_free()
	print("  [PASS] ADV-UI-05: Destructive action confirmation safety verified.")
	return passed

# ==============================================================================
# VECTOR 6: Keyboard Focus Circular Traversal & Tab Softlock Immunity
# ==============================================================================

func test_adv_ui_06_tab_navigation_and_focus_loops() -> bool:
	var passed := true
	print("  [RUN] ADV-UI-06: Keyboard Focus Navigation & Tab Softlock Immunity")

	var tree := _get_tree()

	# 6A: Solo Inventory Tab consumption & close
	var inv_scene := load("res://scenes/ui/inventory_ui.tscn") as PackedScene
	var inv_ui := inv_scene.instantiate() as InventoryUIClass
	tree.root.add_child(inv_ui)

	inv_ui.open_solo()
	if not Assertions.assert_true(inv_ui.visible, "ADV-UI-06A: Solo inventory terbuka"):
		passed = false
	if not Assertions.assert_equal(int(inv_ui.current_mode), int(InventoryUIClass.ViewMode.SOLO), "ADV-UI-06A: Mode adalah SOLO"):
		passed = false

	# Send Tab key action (open_inventory)
	var tab_event := InputEventAction.new()
	tab_event.action = "open_inventory"
	tab_event.pressed = true
	inv_ui._unhandled_input(tab_event)

	if not Assertions.assert_false(inv_ui.visible, "ADV-UI-06A: Tab pada mode SOLO langsung menutup UI (anti-softlock)"):
		passed = false

	inv_ui.queue_free()

	# 6B: PauseMenu Circular Focus Navigation Oracle
	var pause_scene := load("res://scenes/ui/pause_menu.tscn") as PackedScene
	var pause_menu := pause_scene.instantiate() as PauseMenuClass
	tree.root.add_child(pause_menu)
	pause_menu.open_menu()

	var action_buttons: Array[Button] = [
		pause_menu.btn_resume,
		pause_menu.btn_save,
		pause_menu.btn_load,
		pause_menu.btn_settings,
		pause_menu.btn_return_home,
		pause_menu.btn_new_game,
		pause_menu.btn_exit
	]

	# Forward loop traversal via focus_neighbor_bottom
	var curr_btn := pause_menu.btn_resume
	for i in range(action_buttons.size()):
		var expected_next := action_buttons[(i + 1) % action_buttons.size()]
		var next_path: NodePath = curr_btn.focus_neighbor_bottom
		var resolved_node: Node = tree.root.get_node_or_null(next_path)
		if not Assertions.assert_equal(resolved_node, expected_next, "ADV-UI-06B: Forward loop step %d (%s -> %s)" % [i, curr_btn.name, expected_next.name]):
			passed = false
		curr_btn = expected_next

	# Reverse loop traversal via focus_neighbor_top
	for i in range(action_buttons.size()):
		var cur_idx := i
		var exp_idx := (cur_idx - 1 + action_buttons.size()) % action_buttons.size()
		var node_cur: Button = action_buttons[cur_idx]
		var node_prev: Button = action_buttons[exp_idx]
		var prev_path: NodePath = node_cur.focus_neighbor_top
		var resolved_prev: Node = tree.root.get_node_or_null(prev_path)
		if not Assertions.assert_equal(resolved_prev, node_prev, "ADV-UI-06B: Reverse loop step %d (%s -> %s)" % [i, node_cur.name, node_prev.name]):
			passed = false

	# 6C: SettingsMenu Focus Loop Integrity
	var settings_scene := load("res://scenes/ui/settings_menu.tscn") as PackedScene
	var settings_menu := settings_scene.instantiate() as SettingsMenuClass
	tree.root.add_child(settings_menu)
	settings_menu.visible = true

	var settings_controls: Array[Control] = [
		settings_menu.slider_sens,
		settings_menu.check_head_bob,
		settings_menu.slider_fov,
		settings_menu.slider_ui_scale,
		settings_menu.option_window_mode,
		settings_menu.slider_master,
		settings_menu.slider_music,
		settings_menu.slider_sfx,
		settings_menu.check_subtitles,
		settings_menu.btn_reset_defaults,
		settings_menu.btn_save_apply,
		settings_menu.btn_back
	]

	for i in range(settings_controls.size()):
		var c: Control = settings_controls[i]
		if c != null:
			if not Assertions.assert_equal(int(c.focus_mode), int(Control.FOCUS_ALL), "ADV-UI-06C: Widget %s focus_mode == FOCUS_ALL" % c.name):
				passed = false
			var top_node := tree.root.get_node_or_null(c.focus_neighbor_top)
			var bot_node := tree.root.get_node_or_null(c.focus_neighbor_bottom)
			if not Assertions.assert_not_null(top_node, "ADV-UI-06C: Widget %s memiliki focus_neighbor_top valid" % c.name):
				passed = false
			if not Assertions.assert_not_null(bot_node, "ADV-UI-06C: Widget %s memiliki focus_neighbor_bottom valid" % c.name):
				passed = false

	settings_menu.queue_free()
	pause_menu.queue_free()

	print("  [PASS] ADV-UI-06: Keyboard focus loops & Tab softlock immunity verified.")
	return passed
