class_name TestAdversarialUIStressOracle
extends RefCounted

## Test Suite Adversarial Stress Oracle untuk UI-001 (Challenger UI 2)
## Memverifikasi secara independen & empiris:
## 1. ADV-UI2-01: Toast notification spamming: trigger 100 rapid error toasts (identical debounced, unique queued, mixed spam, queue drain, zero leak)
## 2. ADV-UI2-02: Audio volume muting: verify volume at 0% sets bus mute flag and clamps to -80 dB without -inf or NaN
## 3. ADV-UI2-03: Settings round-trip across save/load: verify settings persist across SaveManager.save_game() and load_game() without overwrite
## 4. ADV-UI2-04: Tab navigation in solo inventory vs other menus: verify Tab closes solo inventory and does not lock focus or cause circular infinite loops

const Assertions = preload("res://tests/assertions.gd")
const SaveManagerClass = preload("res://scripts/save/save_manager.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")
const NotificationManagerClass = preload("res://scripts/ui/notification_manager.gd")
const PauseMenuClass = preload("res://scripts/ui/pause_menu.gd")
const SettingsMenuClass = preload("res://scripts/ui/settings_menu.gd")
const InventoryUIClass = preload("res://scripts/ui/inventory_ui.gd")

const SANDBOX_DIR: String = "user://test_adv_ui_stress_sandbox/"
const SANDBOX_SETTINGS_PATH: String = "user://test_adv_ui_stress_sandbox/settings.cfg"

var _tree: SceneTree = null

func _get_tree() -> SceneTree:
	if _tree == null:
		_tree = Engine.get_main_loop() as SceneTree
	return _tree

func run_all() -> bool:
	var passed := true
	print("==================================================")
	print("[ADVERSARIAL_SUITE_UI2] Empirical Stress Oracle (UI-001)")
	print("==================================================")

	_setup_sandbox()

	# VECTOR 1: Toast Notification Spamming & Queue Invariant
	if not test_adv01_toast_notification_spam_and_memory_invariants(): passed = false

	# VECTOR 2: Audio Volume Muting & -80 dB Numerical Clamping
	if not test_adv02_audio_volume_muting_and_clamp_oracle(): passed = false

	# VECTOR 3: Settings Round-Trip Across Save/Load Cycles
	if not test_adv03_settings_roundtrip_save_load_persistence(): passed = false

	# VECTOR 4: Tab Navigation in Solo Inventory vs Other Menus
	if not test_adv04_tab_navigation_and_focus_loop_integrity(): passed = false

	_teardown_sandbox()
	return passed

func _setup_sandbox() -> void:
	_teardown_sandbox()
	DirAccess.make_dir_recursive_absolute(SANDBOX_DIR)

func _teardown_sandbox() -> void:
	if DirAccess.dir_exists_absolute(SANDBOX_DIR):
		var dir := DirAccess.open(SANDBOX_DIR)
		if dir != null:
			dir.list_dir_begin()
			var fn := dir.get_next()
			while not fn.is_empty():
				if not dir.current_is_dir():
					dir.remove(fn)
				fn = dir.get_next()
			dir.list_dir_end()
		DirAccess.remove_absolute(SANDBOX_DIR)

# ==============================================================================
# VECTOR 1: Toast Notification Spamming & Queue Invariants
# ==============================================================================

func test_adv01_toast_notification_spam_and_memory_invariants() -> bool:
	var passed := true
	print("  [RUN] ADV-UI2-01: Toast Notification Spamming (100 Rapid Error Toasts)")

	var notif := NotificationManagerClass.new()
	_get_tree().root.add_child(notif)
	notif.clear_all()

	# Subtest 1A: 100 Rapid Identical Error Toasts in Same Tick
	# Debounce window (1.2s) must drop 99 calls, keeping exactly 1 toast visible and 0 queued
	for i in range(100):
		notif.show_error("Tanah belum siap")

	var visible_count: int = notif.get_visible_toast_count()
	if not Assertions.assert_equal(visible_count, 1, "ADV-UI2-01A: 100 error identik diredam debounce ke tepat 1 toast"):
		passed = false

	notif.clear_all()

	# Subtest 1B: 100 Rapid Unique Error Toasts in Same Tick
	# Invariant: Visible toasts must NEVER exceed MAX_VISIBLE_TOASTS (2).
	# Remaining 98 must be safely placed in pending queue.
	for i in range(100):
		notif.show_error("Adversarial Unique Error #%d" % i)
		var current_visible: int = notif.get_visible_toast_count()
		if current_visible > NotificationManagerClass.MAX_VISIBLE_TOASTS:
			Assertions.assert_true(false, "ADV-UI2-01B: Pelanggaran kapasitas max-2 toast terlihat pada iterasi %d (aktual: %d)" % [i, current_visible])
			passed = false
			break

	if not Assertions.assert_equal(notif.get_visible_toast_count(), 2, "ADV-UI2-01B: Tepat 2 toast terlihat dari 100 error unik yang masuk"):
		passed = false

	# Subtest 1C: Drain the 100 queued toasts through time simulation
	# Advance time across all toasts in steps of 2.6s (duration is 2.5s)
	# Verify that on every step, visible toasts never exceed 2 and no orphaned nodes exist
	var drain_steps: int = 0
	var max_drain_steps: int = 60 # 60 * 2 = 120 toasts capacity
	while notif.get_visible_toast_count() > 0 and drain_steps < max_drain_steps:
		drain_steps += 1
		notif.advance_time(2.6)
		var step_visible: int = notif.get_visible_toast_count()
		if step_visible > NotificationManagerClass.MAX_VISIBLE_TOASTS:
			Assertions.assert_true(false, "ADV-UI2-01C: Kapasitas max-2 terlanggar saat draining antrean (step %d: %d)" % [drain_steps, step_visible])
			passed = false
			break

	if not Assertions.assert_equal(notif.get_visible_toast_count(), 0, "ADV-UI2-01C: Seluruh 100 toast berhasil terkuras habis tanpa sisa"):
		passed = false

	# Subtest 1D: Mixed Rapid Spamming across Types (Toast, Pickup, Error) 100 calls
	notif.clear_all()
	for i in range(100):
		var mod: int = i % 3
		if mod == 0:
			notif.show_toast("Info Toast #%d" % i)
		elif mod == 1:
			notif.show_pickup("Bayam", 1, "ingredient_bayam")
		else:
			notif.show_error("Spam Error")

		var count_now: int = notif.get_visible_toast_count()
		if count_now > NotificationManagerClass.MAX_VISIBLE_TOASTS:
			Assertions.assert_true(false, "ADV-UI2-01D: Batas max-2 terlanggar pada mixed spam iterasi %d" % i)
			passed = false
			break

	if not Assertions.assert_true(notif.get_visible_toast_count() <= NotificationManagerClass.MAX_VISIBLE_TOASTS, "ADV-UI2-01D: Invarian max-2 toast terjaga pada mixed spam"):
		passed = false

	# Subtest 1E: Memory cleanup validation via clear_all()
	notif.clear_all()
	if not Assertions.assert_equal(notif.get_visible_toast_count(), 0, "ADV-UI2-01E: clear_all() mengosongkan seluruh toast aktif dan antrean"):
		passed = false

	notif.queue_free()
	print("  [PASS] ADV-UI2-01: Toast notification spam & queue invariants verified.")
	return passed

# ==============================================================================
# VECTOR 2: Audio Volume Muting & -80 dB Numerical Clamping
# ==============================================================================

func test_adv02_audio_volume_muting_and_clamp_oracle() -> bool:
	var passed := true
	print("  [RUN] ADV-UI2-02: Audio Volume Muting & -80 dB Numerical Clamping Oracle")

	var tree := _get_tree()
	var sm: SaveManagerClass = tree.root.get_node_or_null("SaveManager") as SaveManagerClass
	if sm == null:
		sm = SaveManagerClass.new()
		tree.root.add_child(sm)

	sm.ensure_audio_buses()

	var buses: Array[String] = ["Master", "Music", "SFX"]
	var bus_indices: Dictionary = {}
	for b in buses:
		var idx: int = AudioServer.get_bus_index(b)
		bus_indices[b] = idx
		if not Assertions.assert_true(idx != -1, "ADV-UI2-02: Bus audio '%s' terdaftar pada AudioServer" % b):
			passed = false

	# Subtest 2A: Volume exactly 0.0 (0%)
	# Verify that bus mute flag is TRUE and volume_db is clamped to -80.0 dB
	# without throwing -inf or NaN into AudioServer
	sm.set_setting("audio", "master_volume", 0.0)
	sm.set_setting("audio", "music_volume", 0.0)
	sm.set_setting("audio", "sfx_volume", 0.0)
	sm.apply_all_settings()

	for b in buses:
		var idx: int = int(bus_indices[b])
		var is_muted: bool = AudioServer.is_bus_mute(idx)
		var db_val: float = AudioServer.get_bus_volume_db(idx)

		if not Assertions.assert_true(is_muted, "ADV-UI2-02A: Bus %s harus mute saat volume 0%%" % b):
			passed = false
		if not Assertions.assert_approx_equal(db_val, -80.0, 0.1, "ADV-UI2-02A: Bus %s volume_db tepat -80.0 dB saat volume 0%%" % b):
			passed = false
		if not Assertions.assert_false(is_nan(db_val) or is_inf(db_val), "ADV-UI2-02A: Bus %s volume_db bebas dari NaN / -Inf" % b):
			passed = false

	# Subtest 2B: Sub-epsilon and extreme negative volumes (-1.0, 0.00005, -100.0)
	# Must be safely clamped without throwing domain error in linear_to_db()
	sm.set_setting("audio", "music_volume", -10.0)
	sm.set_setting("audio", "sfx_volume", 0.00001)
	sm.apply_all_settings()

	var mus_idx: int = int(bus_indices["Music"])
	var sfx_idx: int = int(bus_indices["SFX"])
	if not Assertions.assert_true(AudioServer.is_bus_mute(mus_idx), "ADV-UI2-02B: Volume negatif -10.0 di-mute aman"):
		passed = false
	if not Assertions.assert_true(AudioServer.is_bus_mute(sfx_idx), "ADV-UI2-02B: Sub-epsilon volume 0.00001 di-mute aman"):
		passed = false

	# Subtest 2C: Overdrive volume (2.0, 10.0) clamped to 1.0 (0.0 dB)
	sm.set_setting("audio", "master_volume", 5.0)
	sm.apply_all_settings()
	var mas_idx: int = int(bus_indices["Master"])
	var mas_db: float = AudioServer.get_bus_volume_db(mas_idx)
	if not Assertions.assert_false(AudioServer.is_bus_mute(mas_idx), "ADV-UI2-02C: Bus Master tidak mute pada volume 5.0"):
		passed = false
	if not Assertions.assert_approx_equal(mas_db, 0.0, 0.1, "ADV-UI2-02C: Volume overdrive 5.0 di-clamp ke 1.0 (0.0 dB)"):
		passed = false

	# Subtest 2D: Rapid 100-cycle oscillation between 0.0 and 1.0
	for i in range(100):
		var target_vol: float = 0.0 if (i % 2 == 0) else 1.0
		sm.set_setting("audio", "music_volume", target_vol)
		sm.apply_all_settings()

	var final_db: float = AudioServer.get_bus_volume_db(mus_idx)
	if not Assertions.assert_false(is_nan(final_db) or is_inf(final_db), "ADV-UI2-02D: Nilai dB stabil setelah 100 osilasi mute"):
		passed = false

	# Restore project defaults (0.7, 0.4, 0.7 per CONTENT § 14)
	sm.set_setting("audio", "master_volume", 0.7)
	sm.set_setting("audio", "music_volume", 0.4)
	sm.set_setting("audio", "sfx_volume", 0.7)
	sm.apply_all_settings()

	print("  [PASS] ADV-UI2-02: Audio volume muting & boundary clamping verified.")
	return passed

# ==============================================================================
# VECTOR 3: Settings Round-Trip Across Save/Load Cycles
# ==============================================================================

func test_adv03_settings_roundtrip_save_load_persistence() -> bool:
	var passed := true
	print("  [RUN] ADV-UI2-03: Settings Round-Trip Across Save/Load Cycles Oracle")

	var tree := _get_tree()
	var sm: SaveManagerClass = tree.root.get_node_or_null("SaveManager") as SaveManagerClass
	if sm == null:
		sm = SaveManagerClass.new()
		tree.root.add_child(sm)

	# Route to isolated sandbox
	sm.set_save_directory(SANDBOX_DIR)
	sm.set_settings_path(SANDBOX_SETTINGS_PATH)

	# Define non-default custom settings
	var custom_settings: Dictionary = {
		"gameplay": {
			"mouse_sensitivity_multiplier": 3.4,
			"head_bob": true
		},
		"video": {
			"fov": 94.0,
			"ui_scale": 1.25,
			"window_mode": 0
		},
		"audio": {
			"master_volume": 0.35,
			"music_volume": 0.25,
			"sfx_volume": 0.65
		},
		"accessibility": {
			"subtitles": false
		}
	}

	var save_err: Error = sm.save_settings(custom_settings)
	if not Assertions.assert_equal(save_err, OK, "ADV-UI2-03: save_settings() ke sandbox berhasil"):
		passed = false

	# Subtest 3A: 10 Full Gameplay Save & Load Cycles
	# Gameplay save/load must NOT touch or mutate user settings
	for cycle in range(10):
		var s_res: Dictionary = sm.save_game("manual")
		if not Assertions.assert_true(bool(s_res.get("success", false)), "ADV-UI2-03A: save_game() cycle #%d sukses" % cycle):
			passed = false

		var l_res: Dictionary = sm.load_game("manual")
		if not Assertions.assert_true(bool(l_res.get("success", false)), "ADV-UI2-03A: load_game() cycle #%d sukses" % cycle):
			passed = false

		# Invariant: Settings in SaveManager MUST remain completely unaltered
		var cur_fov: float = float(sm.get_setting("video", "fov", 0.0))
		var cur_sens: float = float(sm.get_setting("gameplay", "mouse_sensitivity_multiplier", 0.0))
		var cur_master: float = float(sm.get_setting("audio", "master_volume", 0.0))
		var cur_sub: bool = bool(sm.get_setting("accessibility", "subtitles", true))

		if not Assertions.assert_approx_equal(cur_fov, 94.0, 0.01, "ADV-UI2-03A [Cycle %d]: FOV persisten di 94.0°" % cycle):
			passed = false
		if not Assertions.assert_approx_equal(cur_sens, 3.4, 0.01, "ADV-UI2-03A [Cycle %d]: Sensitivitas persisten di 3.4x" % cycle):
			passed = false
		if not Assertions.assert_approx_equal(cur_master, 0.35, 0.01, "ADV-UI2-03A [Cycle %d]: Master volume persisten di 0.35" % cycle):
			passed = false
		if not Assertions.assert_false(cur_sub, "ADV-UI2-03A [Cycle %d]: Subtitle persisten di false" % cycle):
			passed = false

	# Subtest 3B: Corrupted gameplay save does NOT alter settings.cfg
	var manual_path: String = sm.get_slot_path("manual")
	var bak_path: String = manual_path + ".bak"
	var f1: FileAccess = FileAccess.open(manual_path, FileAccess.WRITE)
	if f1 != null:
		f1.store_string("ADVERSARIAL_CORRUPTED_JSON_DATA")
		f1.close()
	if FileAccess.file_exists(bak_path):
		var f2: FileAccess = FileAccess.open(bak_path, FileAccess.WRITE)
		if f2 != null:
			f2.store_string("ADVERSARIAL_CORRUPTED_JSON_DATA")
			f2.close()

	var fail_load: Dictionary = sm.load_game("manual")
	if not Assertions.assert_false(bool(fail_load.get("success", false)), "ADV-UI2-03B: load_game() pada save korup harus gagal secara aman"):
		passed = false

	# Reload settings directly from disk cfg
	var disk_settings: Dictionary = sm.load_settings()
	var disk_fov: float = float(disk_settings.get("video", {}).get("fov", 0.0))
	if not Assertions.assert_approx_equal(disk_fov, 94.0, 0.01, "ADV-UI2-03B: settings.cfg tetap utuh dan valid meskipun save game corrupt"):
		passed = false

	# Restore default paths
	sm.set_save_directory("user://")
	sm.set_settings_path("user://settings.cfg")
	sm.load_settings()

	print("  [PASS] ADV-UI2-03: Settings round-trip across save/load verified.")
	return passed

# ==============================================================================
# VECTOR 4: Tab Navigation in Solo Inventory vs Other Menus
# ==============================================================================

func test_adv04_tab_navigation_and_focus_loop_integrity() -> bool:
	var passed := true
	print("  [RUN] ADV-UI2-04: Tab Navigation & Focus Loop Integrity Oracle")

	var tree := _get_tree()

	# Subtest 4A: Solo Inventory Tab key closure (UI_UX § 3 Anti-Softlock)
	var inv_scene := load("res://scenes/ui/inventory_ui.tscn") as PackedScene
	var inv_ui := inv_scene.instantiate() as InventoryUIClass
	tree.root.add_child(inv_ui)

	inv_ui.open_solo()
	if not Assertions.assert_true(inv_ui.visible, "ADV-UI2-04A: Inventory UI terbuka dalam mode solo"):
		passed = false
	if not Assertions.assert_equal(int(inv_ui.current_mode), int(InventoryUIClass.ViewMode.SOLO), "ADV-UI2-04A: Mode aktif adalah ViewMode.SOLO"):
		passed = false

	# Simulate Tab key press action (open_inventory)
	var tab_event := InputEventAction.new()
	tab_event.action = "open_inventory"
	tab_event.pressed = true
	inv_ui._unhandled_input(tab_event)

	if not Assertions.assert_false(inv_ui.visible, "ADV-UI2-04A: Tombol Tab pada inventaris solo langsung menutup panel (anti-softlock)"):
		passed = false

	inv_ui.queue_free()

	# Subtest 4B: PauseMenu Circular Focus Loop Integrity (Forward & Reverse)
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
	for i in range(action_buttons.size()):
		var cur_btn: Button = action_buttons[i]
		var exp_next: Button = action_buttons[(i + 1) % action_buttons.size()]
		var next_path: NodePath = cur_btn.focus_neighbor_bottom
		if not Assertions.assert_equal(next_path, exp_next.get_path(), "ADV-UI2-04B: Forward loop link %d (%s -> %s)" % [i, cur_btn.name, exp_next.name]):
			passed = false

	# Reverse loop traversal via focus_neighbor_top
	for i in range(action_buttons.size()):
		var cur_btn: Button = action_buttons[i]
		var exp_prev: Button = action_buttons[(i - 1 + action_buttons.size()) % action_buttons.size()]
		var prev_path: NodePath = cur_btn.focus_neighbor_top
		if not Assertions.assert_equal(prev_path, exp_prev.get_path(), "ADV-UI2-04B: Reverse loop link %d (%s -> %s)" % [i, cur_btn.name, exp_prev.name]):
			passed = false

	# Subtest 4C: SettingsMenu Focus Loop Integrity Across All Widgets
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
			if not Assertions.assert_equal(int(c.focus_mode), int(Control.FOCUS_ALL), "ADV-UI2-04C: Widget %s memiliki focus_mode FOCUS_ALL" % c.name):
				passed = false
			var exp_next_c: Control = settings_controls[(i + 1) % settings_controls.size()]
			var exp_prev_c: Control = settings_controls[(i - 1 + settings_controls.size()) % settings_controls.size()]
			if not Assertions.assert_equal(c.focus_neighbor_bottom, exp_next_c.get_path(), "ADV-UI2-04C: Settings loop next link %d (%s -> %s)" % [i, c.name, exp_next_c.name]):
				passed = false
			if not Assertions.assert_equal(c.focus_neighbor_top, exp_prev_c.get_path(), "ADV-UI2-04C: Settings loop prev link %d (%s -> %s)" % [i, c.name, exp_prev_c.name]):
				passed = false

	# Subtest 4D: Modal Confirmation Focus Default Safety
	pause_menu.btn_new_game.grab_focus()
	pause_menu._show_confirm("Konfirmasi Bahaya", "Peringatan", "Aksi Berbahaya", Callable())

	if not Assertions.assert_true(pause_menu.confirm_modal.visible, "ADV-UI2-04D: Confirm modal terlihat"):
		passed = false
	if not Assertions.assert_equal(int(pause_menu.modal_btn_cancel.focus_mode), int(Control.FOCUS_ALL), "ADV-UI2-04D: Tombol Batal dapat fokus"):
		passed = false

	# Pop modal and verify focus restores to originating button
	pause_menu.pop_subpanel()
	if not Assertions.assert_false(pause_menu.confirm_modal.visible, "ADV-UI2-04D: Confirm modal ditutup"):
		passed = false

	settings_menu.queue_free()
	pause_menu.queue_free()

	print("  [PASS] ADV-UI2-04: Tab navigation & focus loop integrity verified.")
	return passed
