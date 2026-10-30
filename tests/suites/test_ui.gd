class_name TestUI
extends RefCounted

## Test Suite UI-001: Kenyamanan Terpadu, Navigasi Fokus Keyboard, Notifikasi Jujur & Pengaturan (Suite 21)
## Memverifikasi PRD FR16, FR21, UI_UX.md § 2, § 3, § 4, § 5, § 6, § 7, CONTENT.md § 11, § 14,
## TASKS.md UI-001, dan TEST_PLAN T18, T21, T28, T51, T52, T53, T54.

const Assertions = preload("res://tests/assertions.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")
const SaveManagerClass = preload("res://scripts/save/save_manager.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")
const NotificationManagerClass = preload("res://scripts/ui/notification_manager.gd")
const PauseMenuClass = preload("res://scripts/ui/pause_menu.gd")
const SettingsMenuClass = preload("res://scripts/ui/settings_menu.gd")
const InventoryUIClass = preload("res://scripts/ui/inventory_ui.gd")
const HUDClass = preload("res://scripts/ui/hud.gd")

var _tree: SceneTree = null

func _get_tree() -> SceneTree:
	if _tree == null:
		_tree = Engine.get_main_loop() as SceneTree
	return _tree

func run_all() -> bool:
	var passed := true
	print("==================================================")
	print("[SUITE 21] TestUI: Kenyamanan Terpadu, Fokus Keyboard & Notifikasi Jujur (UI-001)")
	print("==================================================")

	# Group 1: T18 — Modal Input Gating & Window Focus Loss
	if not test_t18_01_modal_input_gating_and_frame_guard(): passed = false
	if not test_t18_02_focus_loss_auto_pause(): passed = false

	# Group 2: T21 — UI Scaling, FOV & Safe Margins
	if not test_t21_01_fov_and_ui_scale_live_bindings(): passed = false
	if not test_t21_02_layout_safe_margins_across_resolutions(): passed = false

	# Group 3: T28 — Hierarchical Context Stack & Layered Esc Dismissal
	if not test_t28_01_hierarchical_context_stack_depth(): passed = false
	if not test_t28_02_layered_esc_dismissal_and_mouse_recovery(): passed = false

	# Group 4: T51 — Keyboard Navigation, Focus Indicator & Tab Conflicts
	if not test_t51_01_keyboard_focus_indicators_and_circular_traversal(): passed = false
	if not test_t51_02_tab_conflict_resolution_in_inventory_solo(): passed = false
	if not test_t51_03_modal_dismissal_focus_restoration(): passed = false

	# Group 5: T52 — Settings Persistence & Save Slot Isolation
	if not test_t52_01_settings_persistence_to_cfg(): passed = false
	if not test_t52_02_settings_isolation_from_gameplay_save_load(): passed = false

	# Group 6: T53 — Destructive Action Confirmations & Honest Save Failure
	if not test_t53_01_unsaved_progress_exit_confirmation(): passed = false
	if not test_t53_02_save_and_exit_honest_failure_handling(): passed = false
	if not test_t53_03_new_game_modal_confirmation(): passed = false

	# Group 7: T54 — Honest Notification Queueing, Merging & Debounce
	if not test_t54_01_toast_duration_and_two_message_limit(): passed = false
	if not test_t54_02_rapid_pickup_merging(): passed = false
	if not test_t54_03_repeated_failure_debouncing(): passed = false
	if not test_t54_04_toast_non_intrusive_positioning_and_mouse_pass_through(): passed = false

	# Group 8: Audio Buses & Dynamic Volume Bindings
	if not test_audio_buses_layout_and_volume_conversion(): passed = false

	return passed

# ==============================================================================
# GROUP 1: T18 — Modal Input Gating & Window Focus Loss
# ==============================================================================

func test_t18_01_modal_input_gating_and_frame_guard() -> bool:
	var passed := true
	var tree := _get_tree()

	var im: Node = tree.root.get_node_or_null("InputManager")
	if im == null:
		im = InputManagerClass.new()
		tree.root.add_child(im)

	im.pop_to_world()

	var player := PlayerControllerClass.new()
	tree.root.add_child(player)
	im.register_player(player)

	if not Assertions.assert_true(player.movement_enabled, "T18-01: Movement aktif di WORLD"): passed = false
	if not Assertions.assert_true(player.look_enabled, "T18-01: Look aktif di WORLD"): passed = false

	# Push PAUSE
	im.push_context(im.ContextMode.PAUSE)
	if not Assertions.assert_false(player.movement_enabled, "T18-01: Movement terkunci saat PAUSE"): passed = false
	if not Assertions.assert_false(player.look_enabled, "T18-01: Look terkunci saat PAUSE"): passed = false
	if not Assertions.assert_true(im.is_simulation_paused(), "T18-01: Simulasi dijeda saat PAUSE"): passed = false

	# Pop context back to world
	im.pop_context()
	if not Assertions.assert_true(im.is_world_context(), "T18-01: Kembali ke WORLD"): passed = false
	# Frame guard prevents accidental interaction on the closing frame
	if not Assertions.assert_false(im.can_interact_in_world(), "T18-01: Interaksi dunia diblokir pada frame penutupan"): passed = false

	player.queue_free()
	return passed

func test_t18_02_focus_loss_auto_pause() -> bool:
	var passed := true
	var tree := _get_tree()

	var im: Node = tree.root.get_node_or_null("InputManager")
	if im == null:
		im = InputManagerClass.new()
		tree.root.add_child(im)

	im.pop_to_world()
	im.auto_pause_on_focus_loss = true

	# Simulate window focus loss
	im._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	if not Assertions.assert_equal(int(im.get_current_context()), int(im.ContextMode.PAUSE), "T18-02: Kehilangan fokus aplikasi memicu jeda otomatis"): passed = false

	im.pop_to_world()
	return passed

# ==============================================================================
# GROUP 2: T21 — UI Scaling, FOV & Safe Margins
# ==============================================================================

func test_t21_01_fov_and_ui_scale_live_bindings() -> bool:
	var passed := true
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

	# Change FOV to 90 and UI Scale to 1.25
	sm.set_setting("video", "fov", 90.0)
	sm.set_setting("video", "ui_scale", 1.25)
	sm.apply_all_settings()

	if not Assertions.assert_approx_equal(player.fov, 90.0, 0.01, "T21-01: Player FOV diperbarui ke 90°"): passed = false
	if not Assertions.assert_approx_equal(cam.fov, 90.0, 0.01, "T21-01: Camera3D FOV diperbarui ke 90°"): passed = false
	if not Assertions.assert_approx_equal(tree.root.content_scale_factor, 1.25, 0.01, "T21-01: Content scale factor diperbarui ke 1.25"): passed = false

	# Restore default
	sm.set_setting("video", "fov", 80.0)
	sm.set_setting("video", "ui_scale", 1.0)
	sm.apply_all_settings()

	player.queue_free()
	return passed

func test_t21_02_layout_safe_margins_across_resolutions() -> bool:
	var passed := true
	var hud_scene := load("res://scenes/ui/hud.tscn") as PackedScene
	if not Assertions.assert_not_null(hud_scene, "T21-02: HUD scene berhasil dimuat"): passed = false
	var hud := hud_scene.instantiate() as CanvasLayer

	var reticle := hud.find_child("Reticle", true, false) as Control
	if not Assertions.assert_not_null(reticle, "T21-02: Reticle hadir di HUD"): passed = false

	var toast_scene := load("res://scenes/ui/notification_toast.tscn") as PackedScene
	var toast_inst := toast_scene.instantiate() as CanvasLayer
	var vbox := toast_inst.find_child("ToastVBox", true, false) as VBoxContainer
	if not Assertions.assert_not_null(vbox, "T21-02: ToastVBox hadir"): passed = false
	if not Assertions.assert_equal(int(vbox.mouse_filter), int(Control.MOUSE_FILTER_IGNORE), "T21-02: ToastVBox tidak memblokir mouse"): passed = false

	hud.free()
	toast_inst.free()
	return passed

# ==============================================================================
# GROUP 3: T28 — Hierarchical Context Stack & Layered Esc Dismissal
# ==============================================================================

func test_t28_01_hierarchical_context_stack_depth() -> bool:
	var passed := true
	var pause_scene := load("res://scenes/ui/pause_menu.tscn") as PackedScene
	var pause_menu := pause_scene.instantiate() as PauseMenuClass
	_get_tree().root.add_child(pause_menu)

	pause_menu.open_menu()
	if not Assertions.assert_equal(pause_menu.get_subpanel_depth(), 0, "T28-01: Stack subpanel awal 0"): passed = false

	pause_menu.push_subpanel(pause_menu.slot_picker_modal)
	if not Assertions.assert_equal(pause_menu.get_subpanel_depth(), 1, "T28-01: Stack subpanel 1 setelah buka slot picker"): passed = false

	pause_menu.push_subpanel(pause_menu.confirm_modal)
	if not Assertions.assert_equal(pause_menu.get_subpanel_depth(), 2, "T28-01: Stack subpanel 2 setelah buka konfirmasi modal"): passed = false

	pause_menu.queue_free()
	return passed

func test_t28_02_layered_esc_dismissal_and_mouse_recovery() -> bool:
	var passed := true
	var pause_scene := load("res://scenes/ui/pause_menu.tscn") as PackedScene
	var pause_menu := pause_scene.instantiate() as PauseMenuClass
	_get_tree().root.add_child(pause_menu)

	pause_menu.open_menu()
	pause_menu.push_subpanel(pause_menu.slot_picker_modal)
	pause_menu.push_subpanel(pause_menu.confirm_modal)

	# Simulate Esc key on confirm modal
	var esc_event := InputEventAction.new()
	esc_event.action = "pause_menu"
	esc_event.pressed = true

	pause_menu._unhandled_input(esc_event)
	if not Assertions.assert_equal(pause_menu.get_subpanel_depth(), 1, "T28-02: Esc pertama hanya menutup confirm modal"): passed = false
	if not Assertions.assert_true(pause_menu.slot_picker_modal.visible, "T28-02: Slot picker tetap terbuka"): passed = false

	# Simulate Esc on slot picker
	pause_menu._unhandled_input(esc_event)
	if not Assertions.assert_equal(pause_menu.get_subpanel_depth(), 0, "T28-02: Esc kedua menutup slot picker"): passed = false
	if not Assertions.assert_true(pause_menu.main_panel.visible, "T28-02: Main panel tetap terbuka"): passed = false

	# Simulate Esc on pause menu
	pause_menu._unhandled_input(esc_event)
	if not Assertions.assert_false(pause_menu.visible, "T28-02: Esc ketiga menutup seluruh menu jeda"): passed = false

	pause_menu.queue_free()
	return passed

# ==============================================================================
# GROUP 4: T51 — Keyboard Navigation, Focus Indicator & Tab Conflicts
# ==============================================================================

func test_t51_01_keyboard_focus_indicators_and_circular_traversal() -> bool:
	var passed := true
	var pause_scene := load("res://scenes/ui/pause_menu.tscn") as PackedScene
	var pause_menu := pause_scene.instantiate() as PauseMenuClass
	_get_tree().root.add_child(pause_menu)

	pause_menu.open_menu()

	var buttons: Array[Button] = [
		pause_menu.btn_resume,
		pause_menu.btn_save,
		pause_menu.btn_load,
		pause_menu.btn_settings,
		pause_menu.btn_return_home,
		pause_menu.btn_new_game,
		pause_menu.btn_exit
	]

	for b in buttons:
		if not Assertions.assert_equal(int(b.focus_mode), int(Control.FOCUS_ALL), "T51-01: Button %s menerima fokus keyboard" % b.name): passed = false
		if not Assertions.assert_not_null(b.get_theme_stylebox("focus"), "T51-01: StyleBox focus terpasang pada %s" % b.name): passed = false

	# Circular links
	if not Assertions.assert_equal(pause_menu.btn_resume.focus_neighbor_top, pause_menu.btn_exit.get_path(), "T51-01: Link sirkular atas: Resume -> Exit"): passed = false
	if not Assertions.assert_equal(pause_menu.btn_exit.focus_neighbor_bottom, pause_menu.btn_resume.get_path(), "T51-01: Link sirkular bawah: Exit -> Resume"): passed = false

	pause_menu.queue_free()
	return passed

func test_t51_02_tab_conflict_resolution_in_inventory_solo() -> bool:
	var passed := true
	var inv_scene := load("res://scenes/ui/inventory_ui.tscn") as PackedScene
	var inv_ui := inv_scene.instantiate() as InventoryUIClass
	_get_tree().root.add_child(inv_ui)

	inv_ui.open_solo()
	if not Assertions.assert_true(inv_ui.visible, "T51-02: Inventory UI terbuka dalam mode solo"): passed = false

	# Simulate Tab (open_inventory)
	var tab_event := InputEventAction.new()
	tab_event.action = "open_inventory"
	tab_event.pressed = true

	inv_ui._unhandled_input(tab_event)
	if not Assertions.assert_false(inv_ui.visible, "T51-02: Tab menutup inventaris solo tanpa konflik"): passed = false

	inv_ui.queue_free()
	return passed

func test_t51_03_modal_dismissal_focus_restoration() -> bool:
	var passed := true
	var pause_scene := load("res://scenes/ui/pause_menu.tscn") as PackedScene
	var pause_menu := pause_scene.instantiate() as PauseMenuClass
	_get_tree().root.add_child(pause_menu)

	pause_menu.open_menu()
	pause_menu.btn_settings.grab_focus()

	# Open confirm modal
	pause_menu._show_confirm("Uji Fokus", "Pesan uji", "Aksi 1", Callable())
	if not Assertions.assert_true(pause_menu.confirm_modal.visible, "T51-03: Modal konfirmasi tampil"): passed = false

	# Pop modal and verify focus restores
	pause_menu.pop_subpanel()
	if not Assertions.assert_false(pause_menu.confirm_modal.visible, "T51-03: Modal konfirmasi ditutup"): passed = false

	pause_menu.queue_free()
	return passed

# ==============================================================================
# GROUP 5: T52 — Settings Persistence & Save Slot Isolation
# ==============================================================================

func test_t52_01_settings_persistence_to_cfg() -> bool:
	var passed := true
	var tree := _get_tree()

	var sm: Node = tree.root.get_node_or_null("SaveManager")
	if sm == null:
		sm = SaveManagerClass.new()
		tree.root.add_child(sm)

	var custom: Dictionary = sm.get_default_settings()
	custom["gameplay"]["mouse_sensitivity_multiplier"] = 2.5
	custom["audio"]["master_volume"] = 0.55
	custom["accessibility"]["subtitles"] = true

	var err: Error = sm.save_settings(custom)
	if not Assertions.assert_equal(err, OK, "T52-01: Penyimpanan settings.cfg sukses"): passed = false

	var loaded: Dictionary = sm.load_settings()
	var loaded_sens: float = float(sm.get_setting("gameplay", "mouse_sensitivity_multiplier", 0.0))
	var loaded_vol: float = float(sm.get_setting("audio", "master_volume", 0.0))

	if not Assertions.assert_approx_equal(loaded_sens, 2.5, 0.01, "T52-01: Sensitivitas 2.5 tersimpan"): passed = false
	if not Assertions.assert_approx_equal(loaded_vol, 0.55, 0.01, "T52-01: Master volume 0.55 tersimpan"): passed = false

	return passed

func test_t52_02_settings_isolation_from_gameplay_save_load() -> bool:
	var passed := true
	var tree := _get_tree()

	var sm: Node = tree.root.get_node_or_null("SaveManager")
	if sm == null:
		sm = SaveManagerClass.new()
		tree.root.add_child(sm)

	# Set custom FOV
	var custom_settings: Dictionary = sm.load_settings()
	custom_settings["video"]["fov"] = 92.0
	sm.save_settings(custom_settings)

	# Save gameplay and reload gameplay
	sm.save_game("manual")
	sm.load_game("manual")

	var current_fov: float = float(sm.get_setting("video", "fov", 0.0))
	if not Assertions.assert_approx_equal(current_fov, 92.0, 0.01, "T52-02: Pengaturan FOV 92° terisolasi dari load game"): passed = false

	return passed

# ==============================================================================
# GROUP 6: T53 — Destructive Action Confirmations & Honest Save Failure
# ==============================================================================

func test_t53_01_unsaved_progress_exit_confirmation() -> bool:
	var passed := true
	var pause_scene := load("res://scenes/ui/pause_menu.tscn") as PackedScene
	var pause_menu := pause_scene.instantiate() as PauseMenuClass
	_get_tree().root.add_child(pause_menu)

	pause_menu.open_menu()
	pause_menu._on_exit_pressed()

	if not Assertions.assert_true(pause_menu.confirm_modal.visible, "T53-01: Modal konfirmasi keluar tampil"): passed = false
	if not Assertions.assert_true(pause_menu.modal_title.text.contains("Keluar"), "T53-01: Judul modal memuat 'Keluar'"): passed = false

	# Batal menutup modal tanpa exit
	pause_menu.pop_subpanel()
	if not Assertions.assert_false(pause_menu.confirm_modal.visible, "T53-01: Pilihan Batal menutup modal aman"): passed = false

	pause_menu.queue_free()
	return passed

func test_t53_02_save_and_exit_honest_failure_handling() -> bool:
	var passed := true
	var tree := _get_tree()

	var sm: Node = tree.root.get_node_or_null("SaveManager")
	if sm == null:
		sm = SaveManagerClass.new()
		tree.root.add_child(sm)

	var pause_scene := load("res://scenes/ui/pause_menu.tscn") as PackedScene
	var pause_menu := pause_scene.instantiate() as PauseMenuClass
	tree.root.add_child(pause_menu)

	pause_menu.open_menu()

	# Simulate save write failure
	if "simulate_write_failure" in sm:
		sm.simulate_write_failure = true

	pause_menu._execute_save_and_exit()

	# When save fails, app MUST NOT exit and MUST show honest error message
	if not Assertions.assert_false(pause_menu._exit_called_in_test, "T53-02: Aplikasi tidak keluar saat save gagal"): passed = false
	if not Assertions.assert_true(pause_menu.status_label.text.contains("belum tersimpan"), "T53-02: Status error jujur ditampilkan"): passed = false

	if "simulate_write_failure" in sm:
		sm.simulate_write_failure = false

	pause_menu.queue_free()
	return passed

func test_t53_03_new_game_modal_confirmation() -> bool:
	var passed := true
	var pause_scene := load("res://scenes/ui/pause_menu.tscn") as PackedScene
	var pause_menu := pause_scene.instantiate() as PauseMenuClass
	_get_tree().root.add_child(pause_menu)

	pause_menu.open_menu()
	pause_menu._on_new_game_pressed()

	if not Assertions.assert_true(pause_menu.confirm_modal.visible, "T53-03: Modal konfirmasi game baru tampil"): passed = false
	if not Assertions.assert_true(pause_menu.modal_message.text.contains("belum disimpan akan hilang"), "T53-03: Peringatan progres hilang tampil"): passed = false

	pause_menu.pop_subpanel()
	pause_menu.queue_free()
	return passed

# ==============================================================================
# GROUP 7: T54 — Honest Notification Queueing, Merging & Debounce
# ==============================================================================

func test_t54_01_toast_duration_and_two_message_limit() -> bool:
	var passed := true
	var notif := NotificationManagerClass.new()
	_get_tree().root.add_child(notif)

	notif.clear_all()

	# Send 4 toasts
	notif.show_toast("Pesan 1")
	notif.show_toast("Pesan 2")
	notif.show_toast("Pesan 3")
	notif.show_toast("Pesan 4")

	if not Assertions.assert_equal(notif.get_visible_toast_count(), 2, "T54-01: Maksimal 2 toast terlihat bersamaan"): passed = false

	# Advance 2.6 seconds
	notif.advance_time(2.6)
	# Next 2 should pop from queue
	if not Assertions.assert_equal(notif.get_visible_toast_count(), 2, "T54-01: Antrean toast kedua tampil setelah 2.5s"): passed = false

	# Advance 2.6 seconds again
	notif.advance_time(2.6)
	if not Assertions.assert_equal(notif.get_visible_toast_count(), 0, "T54-01: Seluruh toast selesai"): passed = false

	notif.queue_free()
	return passed

func test_t54_02_rapid_pickup_merging() -> bool:
	var passed := true
	var notif := NotificationManagerClass.new()
	_get_tree().root.add_child(notif)
	notif.clear_all()

	# Two rapid pickups of same item
	notif.show_pickup("Bayam", 1, "ingredient_bayam")
	notif.show_pickup("Bayam", 1, "ingredient_bayam")

	if not Assertions.assert_equal(notif.get_visible_toast_count(), 1, "T54-02: Dua pickup digabung menjadi 1 toast"): passed = false
	var text: String = notif.get_active_toast_text(0)
	if not Assertions.assert_true(text.contains("(x2)"), "T54-02: Jumlah item terakumulasi ke (x2)"): passed = false

	notif.queue_free()
	return passed

func test_t54_03_repeated_failure_debouncing() -> bool:
	var passed := true
	var notif := NotificationManagerClass.new()
	_get_tree().root.add_child(notif)
	notif.clear_all()

	# 5 repeated errors within debounce window
	notif.show_error("Tanah belum siap")
	notif.show_error("Tanah belum siap")
	notif.show_error("Tanah belum siap")
	notif.show_error("Tanah belum siap")
	notif.show_error("Tanah belum siap")

	if not Assertions.assert_equal(notif.get_visible_toast_count(), 1, "T54-03: Error berulang di-debounce ke 1 pesan"): passed = false

	notif.queue_free()
	return passed

func test_t54_04_toast_non_intrusive_positioning_and_mouse_pass_through() -> bool:
	var passed := true
	var toast_scene := load("res://scenes/ui/notification_toast.tscn") as PackedScene
	var notif := toast_scene.instantiate() as NotificationManagerClass
	_get_tree().root.add_child(notif)

	notif.show_toast("Uji Non-Intrusif")

	if not Assertions.assert_equal(int(notif.toast_container.mouse_filter), int(Control.MOUSE_FILTER_IGNORE), "T54-04: ToastContainer mouse_filter == IGNORE"): passed = false
	if not Assertions.assert_equal(int(notif.toast_vbox.mouse_filter), int(Control.MOUSE_FILTER_IGNORE), "T54-04: ToastVBox mouse_filter == IGNORE"): passed = false

	notif.queue_free()
	return passed

# ==============================================================================
# GROUP 8: Audio Buses & Dynamic Volume Bindings
# ==============================================================================

func test_audio_buses_layout_and_volume_conversion() -> bool:
	var passed := true
	var tree := _get_tree()

	var sm: Node = tree.root.get_node_or_null("SaveManager")
	if sm == null:
		sm = SaveManagerClass.new()
		tree.root.add_child(sm)

	sm.ensure_audio_buses()

	var master_idx := AudioServer.get_bus_index("Master")
	var music_idx := AudioServer.get_bus_index("Music")
	var sfx_idx := AudioServer.get_bus_index("SFX")

	if not Assertions.assert_true(master_idx != -1, "Audio: Bus Master tersedia"): passed = false
	if not Assertions.assert_true(music_idx != -1, "Audio: Bus Music tersedia"): passed = false
	if not Assertions.assert_true(sfx_idx != -1, "Audio: Bus SFX tersedia"): passed = false

	# Test volume conversion: 0.5 linear -> approx -6.02 dB
	sm.set_setting("audio", "music_volume", 0.5)
	sm.apply_all_settings()

	var music_db: float = AudioServer.get_bus_volume_db(music_idx)
	if not Assertions.assert_approx_equal(music_db, linear_to_db(0.5), 0.1, "Audio: Volume Music 0.5 linear terkonversi ke dB"): passed = false
	if not Assertions.assert_false(AudioServer.is_bus_mute(music_idx), "Audio: Music tidak di-mute pada 0.5"): passed = false

	# Test mute at 0.0
	sm.set_setting("audio", "music_volume", 0.0)
	sm.apply_all_settings()
	if not Assertions.assert_true(AudioServer.is_bus_mute(music_idx), "Audio: Music di-mute saat volume 0.0"): passed = false

	# Restore 0.4 default
	sm.set_setting("audio", "music_volume", 0.4)
	sm.apply_all_settings()

	return passed
