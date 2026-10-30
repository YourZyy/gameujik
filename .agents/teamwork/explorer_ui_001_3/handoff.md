# Handoff Report — Explorer UI-001 (Notification, Focus Navigation & Test Suite UI)

**Agent:** explorer_ui_001_3  
**Working Directory:** `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_ui_001_3\`  
**Milestone:** UI-001 (Kenyamanan Terpadu, Notifikasi Jujur, Navigasi Fokus Keyboard, & Test Suite 21)  
**Target Recipient:** Orchestrator (`d75c8496-f8db-4740-9f21-bce808aa2500`) and Worker UI-001  

---

## 1. Observation

### 1.1 Existing HUD & Feedback Limitations
- **Current Prompt Overwrite in `scripts/ui/hud.gd` (lines 364–373):**
  ```gdscript
  func show_feedback(message: String, duration: float = 2.5) -> void:
      if prompt_label != null:
          prompt_label.text = message
      _is_prompt_visible = true
      if prompt_panel != null:
          prompt_panel.visible = true
          prompt_panel.modulate.a = 1.0
      _feedback_timer = duration
      _feedback_active = true
  ```
  *Observed defect against UI_UX UI01 & T54:* When an action fails or succeeds, `show_feedback` overwrites the reticle interaction prompt (`prompt_label.text`). If a player holds down an action that fails (e.g. hoeing unhoed soil or full bag harvest), the interaction prompt disappears completely and stays overwritten indefinitely. Furthermore, rapid successive messages clobber each other instantly with zero queueing, zero item merging, and no cap of 2 visible toasts.

- **UI Layout Specification in `docs/UI_UX.md` § 5 (UI01 — HUD Eksplorasi):**
  - **Tengah:** Crosshair kecil (tidak hilang hanya karena objek tidak dapat dipakai).
  - **Sedikit bawah tengah:** Satu prompt E dan bila relevan satu prompt alat (tidak menumpuk beberapa target).
  - **Bawah tengah:** Nama alat aktif + ikon kecil + resource relevan.
  - **Bawah samping:** Notifikasi satu pesan (tidak menutup prompt atau mengambil fokus).

- **UI Feedback Rules in `docs/UI_UX.md` § 6:**
  - "Notifikasi pickup singkat sekitar 2,5 detik, maksimum dua terlihat; pesan berulang digabung berdasarkan item."
  - "Pesan gagal yang sama diberi jeda agar menahan tombol tidak membanjiri layar."
  - "Kesalahan yang perlu tindakan penting tetap terbaca sampai dipahami atau panel ditutup."
  - "Sukses memakai bunyi halus dan perubahan keadaan; tidak mengunci kamera. Error tidak hanya berbunyi: alasan tertulis harus tersedia."

- **System & Error Messages in `docs/CONTENT.md` § 11:**
  - Tas penuh: *"Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."*
  - Tujuan penuh: *"Penyimpanan tidak cukup. Tidak ada barang yang dipindahkan."*
  - Tanah belum siap: *"Gemburkan tanah dan tambahkan pembenah dahulu."*
  - Benih kurang: *"Benih belum tersedia. Periksa wadah dekat alat."*
  - Kering: *"Pertumbuhan berhenti sementara. Siram petak."*
  - Nutrisi kurang: *"Pertumbuhan berhenti sementara. Tambahkan pupuk."*
  - Kondisi cukup: *"Petak sudah cukup. Tidak ada bahan yang digunakan."*
  - Bahan dapur kurang: *"Bahan belum lengkap. Buka buku untuk melihat sumbernya."*
  - Hasil tertahan: *"Ambil hidangan sebelumnya dahulu."*
  - Job dijeda: *"Masakan dijeda. Buka dapur untuk melanjutkan."*
  - Save berhasil: *"Progres tersimpan."*
  - Save gagal: *"Progres belum tersimpan. Coba lagi atau gunakan lokasi simpan yang dapat ditulis."*
  - Save tidak cocok: *"Data simpan tidak cocok dengan versi ini. Pilih cadangan yang tersedia."*
  - Penutup P0: *"Satu resep selesai. Kebun ini baru dimulai."*

### 1.2 Keyboard Accessibility & Input Context Observations
- **Input Gating in `scripts/core/input_manager.gd` (lines 173–199):**
  - Auto-pause on focus loss is partially present:
    ```gdscript
    func _notification(what: int) -> void:
        if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
            if auto_pause_on_focus_loss and is_world_context():
                push_context(ContextMode.PAUSE)
    ```
  - Input context stack supports `push_context`, `pop_context`, `pop_to_world`, and frame-bleed suppression (`_last_closed_frame = Engine.get_process_frames()`).
  - Gating on PlayerController locks `movement_enabled` and `look_enabled` when modal depth > 1.
- **Tab Key Conflict Resolution in `docs/UI_UX.md` § 3:**
  - "Untuk menghindari konflik Tab, di panel tas Tab adalah tutup; panah atas/bawah memilih item, panah kiri/kanan berpindah kontainer, Enter memfokuskan aksi item, dan Esc kembali ke daftar atau menutup panel. Pada panel lain Tab/Shift+Tab menggerakkan fokus."
- **Keyboard Focus Visuals in `docs/UI_UX.md` § 2:**
  - "Warna tidak menjadi satu-satunya pembeda: tambahkan teks, ikon dan bentuk. Fokus keyboard terlihat."

### 1.3 Test Runner & Existing Suite Landscape
- **Test Runner in `tests/test_runner.gd` (lines 124–132):**
  - Currently runs Suites 1 through 20 (up to `TestAdversarialSave`).
  - Suite 21 is slated for `TestUI` (`tests/suites/test_ui.gd`) to cover acceptance cases T18, T21, T28, T51, T52, T53, T54.
- **Existing Assertions Harness in `tests/assertions.gd`:**
  - Static methods: `assert_true`, `assert_false`, `assert_equal`, `assert_not_null`, `assert_null`, `assert_almost_equal`, `assert_gt`, `assert_lt`.
  - Maintains `current_suite_passed`, `current_suite_failed`, and `failure_messages`.

---

## 2. Logic Chain

1. **Separation of Toasts from Interaction Prompts (UI_UX § 5, UI_UX § 6, T54):**
   - *Observation:* Overwriting `prompt_label.text` in `hud.gd` violates the spatial layout of UI01 (prompts must be center-bottom; notifications must be bottom-side) and disrupts gameplay when spamming actions.
   - *Reasoning:* A dedicated `NotificationToast` component / `ToastContainer` must be added to the HUD canvas (or as a sibling CanvasLayer). It must be placed at the bottom-side (e.g. bottom-right with 4% safe margin) and configured with `mouse_filter = MOUSE_FILTER_IGNORE` so it never intercepts mouse look or clicks.

2. **Toast Capacity, Lifecycle, and Debounce Rules (CONTENT § 11, UI_UX § 6, T54):**
   - *Observation:* T54 explicitly requires: *"Ambil cepat beberapa item dan tahan aksi gagal -> Notifikasi tergabung/terbatas, pesan tidak menutup prompt atau merebut kamera"*.
   - *Reasoning:* 
     - **Capacity:** At most 2 toasts can be visible simultaneously (`active_toasts.size() <= 2`). If a 3rd message arrives, it queues or gracefully replaces the oldest non-critical toast.
     - **Duration:** Default 2.5 seconds per toast. After 2.5s, the toast smoothly fades out and is freed.
     - **Item Merging:** Rapid collection of the same item (e.g., harvesting multiple bayam in quick succession) merges into a single toast: `"Memetik Bayam (x2)"`, refreshing its 2.5s timer.
     - **Failure Debouncing:** Repeated identical errors (e.g., player holding LMB with a hoe on unhoed soil or clicking with full bag) have a 1.2s cooldown debounce window. Subsequent identical triggers within that window do not spawn new toasts or reset the queue, preventing screen flooding.

3. **Accessible Keyboard Navigation & Circular Traversal (UI_UX § 2, § 3, § 7, T51):**
   - *Observation:* T51 requires: *"Navigasi seluruh panel hanya keyboard dan kembali dari konfirmasi -> Fokus terlihat, urutan logis, semua aksi inti dapat diakses, konflik Tab tidak mengunci"*.
   - *Reasoning:*
     - **Visual Indicator:** Every interactive button, slider, and checkbox must have a distinct, high-contrast focus outline (`StyleBoxFlat` with 2px accent border `Color(1.0, 0.85, 0.3)` or `Color(0.95, 0.95, 0.95)`).
     - **Circular Traversal:** On the Pause Menu and Settings Menu, the first item's `focus_neighbor_top` wraps to the last item, and the last item's `focus_neighbor_bottom` wraps to the first item. Arrow keys (Up/Down) and Tab/Shift+Tab cycle seamlessly without softlocking.
     - **Tab Hotkey Gating:** In `InventoryUI` (solo mode), Tab is intercepted to execute `close_ui()`. In all other menus (Pause, Settings, Dialogue, Kitchen), Tab advances focus.
     - **Modal Focus Recovery:** When a confirmation modal opens (e.g., "Simpan sebelum keluar?"), it stores `_previous_focus_owner = get_viewport().gui_get_focus_owner()`, grabs focus on "Batal" (safe default), and on dismissal (Esc or Batal), immediately calls `_previous_focus_owner.grab_focus()`.

4. **Multi-layer Modal Dismissal & Zero Bleed-through (UI_UX § 4, TEST_PLAN T18, T28):**
   - *Observation:* T18 and T28 require that opening modals halts player movement/look, Esc closes the topmost sub-modal first (e.g., ConfirmDialog -> SettingsMenu -> PauseMenu -> World), and input on the close frame does not trigger world actions.
   - *Reasoning:* The existing `InputManager._last_closed_frame` check guarantees that `can_interact_in_world()` returns false on the closing frame. Esc hotkey must pop the topmost modal layer from `_context_stack`. When depth reaches 1 (WORLD), `Input.mouse_mode` is restored to `MOUSE_MODE_CAPTURED`.

5. **Test Suite 21 Structure & Headless Compatibility:**
   - *Observation:* Headless Godot (`godot --headless`) does not instantiate an OS window manager, so tests must programmatically exercise UI components, signal emissions, focus states, and timer expirations without relying on physical OS input devices.
   - *Reasoning:* `tests/suites/test_ui.gd` will instantiate instances of `HUD`, `PauseMenu`, `SettingsMenu`, and `NotificationToast`, wire them to `InputManager` and `SaveManager`, and evaluate exact assertions via `tests/assertions.gd`.

---

## 3. Caveats

- **Audio Bus Hardware Emulation in Headless:** In headless mode, `AudioServer.set_bus_volume_db` executes correctly, but actual audio playback is muted. Test assertions must verify bus volume db values and conversion math (`linear_to_db`), rather than physical audio output.
- **DisplayServer Headless Mouse Capture:** In `DisplayServer.get_name() == "headless"`, `Input.mouse_mode = Input.MOUSE_MODE_CAPTURED` is a virtual state; `InputManager._mouse_captured_state` tracks the logical captured status accurately.
- **Settings Screen Layout:** Explorer 1 focuses on the Pause Menu and Explorer 2 focuses on Settings bindings. This report coordinates with both to ensure the focus chain between PauseMenu and SettingsMenu is seamless and testable.

---

## 4. Conclusion & Recommended Architecture

### 4.1 Notification / Toast System Architecture (`res://scripts/ui/notification_manager.gd` & `res://scenes/ui/notification_toast.tscn`)

#### Scene Hierarchy (`notification_toast.tscn`):
```
NotificationToast (CanvasLayer, layer = 15)
└── ToastContainer (Control, Anchors: Preset Bottom-Right or Custom Margin 4%)
    └── ToastVBox (VBoxContainer, alignment = END, mouse_filter = IGNORE)
        ├── ToastItem1 (PanelContainer, mouse_filter = IGNORE, visible = false)
        │   └── MarginContainer
        │       └── HBoxContainer
        │           ├── TypeBar (ColorRect, custom_minimum_size = (4, 24))
        │           └── MessageLabel (Label, text, autowrap = true, font_size ~ 22px)
        └── ToastItem2 (PanelContainer, mouse_filter = IGNORE, visible = false)
            └── MarginContainer
                └── HBoxContainer
                    ├── TypeBar (ColorRect)
                    └── MessageLabel (Label)
```

#### Core Script Contracts (`scripts/ui/notification_manager.gd`):
```gdscript
class_name NotificationManager
extends CanvasLayer

signal toast_displayed(message: String, type: String)
signal toast_dismissed(message: String)

const MAX_VISIBLE_TOASTS: int = 2
const DEFAULT_DURATION: float = 2.5
const ERROR_DEBOUNCE_TIME: float = 1.2

var _active_toasts: Array[Dictionary] = []
var _pending_queue: Array[Dictionary] = []
var _error_timestamps: Dictionary = {}

func show_toast(message: String, type: String = "info", duration: float = DEFAULT_DURATION, item_id: String = "") -> void
func show_pickup(item_name: String, quantity: int = 1, item_id: String = "") -> void
func show_error(reason: String, debounce_sec: float = ERROR_DEBOUNCE_TIME) -> void
func show_honest_message(context_key: String) -> void
func get_visible_toast_count() -> int
func clear_all() -> void
```

#### Merging & Debounce Logic:
1. **Pickup Merging:** When `show_pickup("Bayam", 1, "ingredient_bayam")` is called:
   - Check if an active toast exists with matching `item_id`.
   - If found, increment its `quantity += 1`, update label text to `"%s (x%d)" % [item_name, quantity]`, and reset its `timer = DEFAULT_DURATION`.
   - If not found, spawn a new toast (or queue if count >= 2).
2. **Error Debouncing:** When `show_error(reason)` is called:
   - Compare current game time with `_error_timestamps.get(reason, -100.0)`.
   - If `current_time - last_time < ERROR_DEBOUNCE_TIME`, drop the call silently (prevents hold-action flood).
   - Otherwise, record `_error_timestamps[reason] = current_time` and display the toast with amber/red accent.
3. **Non-Intrusiveness Guarantee:**
   - Root container and all children have `mouse_filter = Control.MOUSE_FILTER_IGNORE`.
   - Anchored at bottom-right (`margin_right = -48`, `margin_bottom = -48`), completely clear of the central crosshair and bottom-center interaction prompt.
   - Does not affect `player.look_enabled` or camera rotation.

---

### 4.2 Keyboard Navigation & Focus Accessibility Architecture

#### Visual Focus Theme StyleBox:
```gdscript
static func create_focus_stylebox() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.draw_center = false
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.border_color = Color(1.0, 0.85, 0.3, 1.0) # Warm golden accent
    style.set_corner_radius_all(4)
    return style
```

#### Pause Menu Navigation Chain:
- **Buttons Order:**
  1. `BtnResume` ("Lanjutkan")
  2. `BtnSave` ("Simpan Progres")
  3. `BtnLoad` ("Muat Progres")
  4. `BtnSettings` ("Pengaturan")
  5. `BtnSafeSpawn` ("Kembali ke Rumah")
  6. `BtnMainMenu` ("Menu Utama")
  7. `BtnExit` ("Keluar ke Desktop")
- **Circular Neighbors:**
  - `BtnResume.focus_neighbor_top = BtnExit.get_path()`
  - `BtnExit.focus_neighbor_bottom = BtnResume.get_path()`
  - Down Arrow / Tab moves down; Up Arrow / Shift+Tab moves up.
- **Initial Focus:** When Pause Menu opens, `BtnResume.grab_focus()` is called automatically.

#### Modal Confirmation Focus Restoration:
```gdscript
var _previous_focused_control: Control = null

func show_confirm_dialog(title: String, prompt: String, on_confirm: Callable, on_cancel: Callable = Callable()) -> void:
    _previous_focused_control = get_viewport().gui_get_focus_owner()
    confirm_panel.visible = true
    # Focus safe default
    btn_cancel.grab_focus()

func close_confirm_dialog() -> void:
    confirm_panel.visible = false
    if is_instance_valid(_previous_focused_control):
        _previous_focused_control.grab_focus()
```

---

### 4.3 Acceptance Test Suite Design (`tests/suites/test_ui.gd` / Suite 21)

Here is the exact design of `tests/suites/test_ui.gd` covering all 7 acceptance cases across 14 comprehensive test methods:

```gdscript
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
const HUDClass = preload("res://scripts/ui/hud.gd")

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

    # Group 7: T54 — Honest Notification Queueing, Merging & Debounce
    if not test_t54_01_toast_duration_and_two_message_limit(): passed = false
    if not test_t54_02_rapid_pickup_merging(): passed = false
    if not test_t54_03_repeated_failure_debouncing(): passed = false
    if not test_t54_04_toast_non_intrusive_positioning_and_mouse_pass_through(): passed = false

    return passed
```

#### Detailed Test Method Specifications:

1. **`test_t18_01_modal_input_gating_and_frame_guard()`**
   - Instantiates `InputManager` and dummy `PlayerController`.
   - Verifies `movement_enabled == true`, `look_enabled == true` in `WORLD`.
   - Pushes `ContextMode.PAUSE`; verifies `movement_enabled == false`, `look_enabled == false`, `is_simulation_paused() == true`.
   - Calls `pop_context()`; verifies `can_interact_in_world() == false` on the same frame, and true on next frame.
   - Assertions:
     - `Assertions.assert_false(player.movement_enabled, "Player movement disabled during pause")`
     - `Assertions.assert_false(player.look_enabled, "Player camera look disabled during pause")`
     - `Assertions.assert_false(im.can_interact_in_world(), "Interaction suppressed on modal close frame")`

2. **`test_t18_02_focus_loss_auto_pause()`**
   - In `WORLD` context with `auto_pause_on_focus_loss = true`, emits `NOTIFICATION_APPLICATION_FOCUS_OUT`.
   - Assertions:
     - `Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.PAUSE, "Window focus loss auto-pauses to PAUSE context")`
     - `Assertions.assert_true(im.is_modal_active(), "Modal is active after focus loss")`

3. **`test_t21_01_fov_and_ui_scale_live_bindings()`**
   - Updates FOV to 90.0° and UI scale to 1.25.
   - Verifies settings manager saves values to `settings.cfg`.
   - Verifies player camera updates `camera.fov = 90.0`.
   - Assertions:
     - `Assertions.assert_equal(camera.fov, 90.0, "Camera3D FOV dynamically updated")`
     - `Assertions.assert_equal(SaveManager.get_setting("video", "fov"), 90.0, "FOV persisted in settings")`

4. **`test_t21_02_layout_safe_margins_across_resolutions()`**
   - Evaluates HUD layout anchors at 1920x1080 and 1280x720.
   - Verifies QuestTracker top-left margin >= 4% viewport width/height.
   - Verifies prompt panel stays above tool panel and reticle remains centered.
   - Assertions:
     - `Assertions.assert_true(tracker.position.x >= 0, "Tracker within left bounds")`
     - `Assertions.assert_true(tool_panel.position.y + tool_panel.size.y <= viewport_height, "Tool panel within bottom bounds")`

5. **`test_t28_01_hierarchical_context_stack_depth()`**
   - Pushes `PAUSE`, then pushes sub-context (e.g. `SETTINGS`), then sub-dialog (`CONFIRM`).
   - Verifies stack depth is 4.
   - Assertions:
     - `Assertions.assert_equal(im.get_stack_depth(), 4, "Context stack depth matches 4 layers")`

6. **`test_t28_02_layered_esc_dismissal_and_mouse_recovery()`**
   - Pops each context one by one via `pop_context()`.
   - Verifies depth decreases from 4 -> 3 -> 2 -> 1 (WORLD).
   - Verifies mouse mode is restored to `MOUSE_MODE_CAPTURED` when reaching depth 1.
   - Assertions:
     - `Assertions.assert_true(im.is_world_context(), "Final context is WORLD")`
     - `Assertions.assert_false(im.is_simulation_paused(), "Simulation unpaused upon returning to WORLD")`

7. **`test_t51_01_keyboard_focus_indicators_and_circular_traversal()`**
   - Instantiates `PauseMenu`.
   - Verifies all menu buttons have `focus_mode == Control.FOCUS_ALL`.
   - Verifies visual stylebox override exists for `focus` state on all buttons.
   - Verifies circular link: `btn_resume.focus_neighbor_top == btn_exit.get_path()` and `btn_exit.focus_neighbor_bottom == btn_resume.get_path()`.
   - Assertions:
     - `Assertions.assert_true(btn.focus_mode == Control.FOCUS_ALL, "Button accepts focus")`
     - `Assertions.assert_not_null(btn.get_theme_stylebox("focus"), "Visual focus stylebox present")`
     - `Assertions.assert_equal(btn_resume.focus_neighbor_top, btn_exit.get_path(), "Circular top-to-bottom link exists")`

8. **`test_t51_02_tab_conflict_resolution_in_inventory_solo()`**
   - Opens `InventoryUI` in `SOLO` mode.
   - Simulates `open_inventory` (Tab) action press.
   - Verifies `InventoryUI` closes instead of cycling focus off-screen.
   - Assertions:
     - `Assertions.assert_false(inv_ui.visible, "Tab closes solo inventory without key conflict")`

9. **`test_t51_03_modal_dismissal_focus_restoration()`**
   - Sets focus on `BtnSettings`.
   - Triggers confirmation dialog -> focus moves to `btn_cancel`.
   - Cancels dialog -> verifies focus returns to `BtnSettings`.
   - Assertions:
     - `Assertions.assert_equal(get_viewport().gui_get_focus_owner(), btn_settings, "Focus restored to originating button")`

10. **`test_t52_01_settings_persistence_to_cfg()`**
    - Writes custom settings: `mouse_sens = 2.5`, `master = 0.5`, `subtitles = true`.
    - Reloads `SaveManager.load_settings()`.
    - Assertions:
      - `Assertions.assert_equal(SaveManager.get_setting("gameplay", "mouse_sensitivity_multiplier"), 2.5, "Sensitivity persisted in settings.cfg")`
      - `Assertions.assert_equal(SaveManager.get_setting("audio", "master_volume"), 0.5, "Audio volume persisted in settings.cfg")`

11. **`test_t52_02_settings_isolation_from_gameplay_save_load()`**
    - Saves custom settings.
    - Loads an existing gameplay save snapshot (`save_manual.json`).
    - Verifies settings remain custom and are not reset or overridden by the world save state.
    - Assertions:
      - `Assertions.assert_equal(SaveManager.get_setting("gameplay", "mouse_sensitivity_multiplier"), 2.5, "Settings isolated from gameplay save/load")`

12. **`test_t53_01_unsaved_progress_exit_confirmation()`**
    - Marks dirty state (unsaved progress).
    - Clicks "Keluar" on PauseMenu.
    - Verifies confirmation dialog opens with options: "Simpan dan Keluar", "Keluar Tanpa Simpan", "Batal".
    - Clicking "Batal" closes modal with zero state loss and no exit.
    - Assertions:
      - `Assertions.assert_true(confirm_panel.visible, "Unsaved progress modal displayed")`
      - `Assertions.assert_false(exit_called, "Selecting Batal cancels application exit")`

13. **`test_t53_02_save_and_exit_honest_failure_handling()`**
    - Sets `SaveManager.simulate_write_failure = true`.
    - Selects "Simpan dan Keluar".
    - Verifies application does NOT exit, remains in menu, and displays honest error message matching `CONTENT.md` § 11 (*"Progres belum tersimpan. Coba lagi atau gunakan lokasi simpan yang dapat ditulis."*).
    - Assertions:
      - `Assertions.assert_false(exit_called, "App must not exit on save failure")`
      - `Assertions.assert_equal(toast_msg, "Progres belum tersimpan. Coba lagi atau gunakan lokasi simpan yang dapat ditulis.", "Honest failure error displayed")`

14. **`test_t54_01_toast_duration_and_two_message_limit()`**
    - Triggers 4 toasts in quick succession.
    - Verifies visible toasts count is exactly 2.
    - Simulates timer advance past 2.5s; verifies toasts are dismissed.
    - Assertions:
      - `Assertions.assert_true(notif.get_visible_toast_count() <= 2, "At most 2 toasts visible simultaneously")`
      - `Assertions.assert_equal(notif.get_visible_toast_count(), 0, "Toasts auto-dismiss after 2.5s")`

15. **`test_t54_02_rapid_pickup_merging()`**
    - Triggers `show_pickup("Bayam", 1, "ingredient_bayam")` twice within 0.2s.
    - Verifies single toast is active with text containing `"(x2)"`.
    - Assertions:
      - `Assertions.assert_equal(notif.get_visible_toast_count(), 1, "Pickups merged into single toast")`
      - `Assertions.assert_true(notif.get_active_toast_text(0).contains("(x2)"), "Pickup quantity incremented")`

16. **`test_t54_03_repeated_failure_debouncing()`**
    - Triggers `show_error("Tanah belum siap")` 5 times in 0.3s.
    - Verifies only 1 toast is displayed, debouncing the subsequent 4 triggers.
    - Assertions:
      - `Assertions.assert_equal(notif.get_visible_toast_count(), 1, "Repeated failures debounced to 1 toast")`

17. **`test_t54_04_toast_non_intrusive_positioning_and_mouse_pass_through()`**
    - Inspects `ToastContainer` and children.
    - Verifies `mouse_filter == Control.MOUSE_FILTER_IGNORE`.
    - Verifies `prompt_label` in HUD is NOT overwritten or hidden when a toast appears.
    - Assertions:
      - `Assertions.assert_equal(toast_container.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Toast container passes mouse clicks through")`
      - `Assertions.assert_true(hud.prompt_label.visible, "Interaction prompt remains visible while toast is active")`

---

## 5. Verification Method

To independently verify this design once implemented by the Worker:

1. **Headless Test Suite Execution:**
   Run Godot headless test runner:
   ```powershell
   & "C:\Users\HP\.local\bin\godot.exe" --headless -s tests/test_runner.gd
   ```
   - **Expected Result:** Suite 21 (`TestUI`) executes after Suite 20 (`TestAdversarialSave`), passing all assertions for T18, T21, T28, T51, T52, T53, and T54 with exit code 0.
   - **Log Verification:** `test_summary.log` must record `All Passed: true` with 0 failures.

2. **Source Code & Scene Verification:**
   - Verify `res://scenes/ui/notification_toast.tscn` exists and contains non-blocking bottom-side containers.
   - Verify `res://scripts/ui/notification_manager.gd` implements queueing, merging, 1.2s error debouncing, and 2.5s duration.
   - Verify `res://scripts/ui/pause_menu.gd` and `settings_menu.gd` implement circular focus neighbors, visual stylebox focus outlines, and modal focus restoration.
   - Verify `hud.gd` delegates notifications to `NotificationManager` instead of overwriting `prompt_label.text`.

3. **Invalidation Conditions:**
   - Any test failure in Suite 21 invalidates the UI-001 completion.
   - Any regression in Suites 1..20 invalidates backward compatibility.
   - Any toast obscuring the reticle, stealing mouse clicks, or locking camera invalidates T54 compliance.
