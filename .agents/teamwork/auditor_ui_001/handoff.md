# Forensic Audit Report: Milestone UI-001

**Work Product**: UI-001 Implementation, Test Suite 21, and Task Report 016
**Profile**: General Project (Integrity Mode: Development per `ORIGINAL_REQUEST.md`)
**Verdict**: **CLEAN**

---

### Phase Results
- **Hardcoded test results**: **PASS** — Zero hardcoded assertion outcomes or fake passes. Every assertion in `tests/suites/test_ui.gd` verifies dynamic runtime objects, scenes, singletons, and properties.
- **Facade detection**: **PASS** — All settings changes directly mutate live engine state (`Camera3D.fov`, `PlayerController.mouse_sensitivity_multiplier`, `AudioServer.set_bus_volume_db` / `set_bus_mute`, `Window.content_scale_factor`, and `DisplayServer.window_set_mode`). No stub or mock facade implementations exist.
- **Pre-populated artifact detection**: **PASS** — Test logs and results are generated live during the audit execution run. No fabricated attestations detected.
- **Behavioral verification (Headless Test Suite)**: **PASS** — Executed `& "C:\Users\HP\.local\bin\godot_console.exe" --headless --script tests/test_runner.gd`. All 21 suites executed to completion: **6,895 assertions passed, 0 failed (Exit Code: 0)**.
- **Confirmation dialog flow & intent preservation**: **PASS** — Destructive operations (Overwrite Save, Unsaved Data Loss on Load, New Game, Exit to Desktop) are protected by modal confirmation with initial keyboard focus safely routed to "Batal" (Cancel). Save failure on exit cleanly aborts `quit()` and presents honest feedback (`status_label`).
- **Notification queueing, debouncing & merging**: **PASS** — Hard limit of 2 visible toasts, FIFO queueing for subsequent messages, rapid pickup aggregation (`(x2)` with timer refresh), 1.2s error debounce window, and full mouse passthrough (`mouse_filter = Control.MOUSE_FILTER_IGNORE`).

---

## 1. Observation

1. **Implementation Files Inspected:**
   - `scripts/ui/pause_menu.gd` (404 lines): Real subpanel stack (`_subpanel_stack`), circular focus links (`_setup_focus_navigation`), modal confirmation dialogs (`_show_confirm`), safe return home repositioning to `(0.0, 0.0, 8.0)` with `velocity = Vector3.ZERO`, and save failure guard before exit.
   - `scenes/ui/pause_menu.tscn`: CanvasLayer layer 14, BackgroundDimmer, MainPanel, SlotPickerModal, ConfirmModal, and embedded SettingsMenu instance.
   - `scripts/ui/settings_menu.gd` (297 lines): Real widget bindings for FOV (60°..100°), Sensitivity (0.1..5.0x), Head Bob (CheckBox), UI Scale (0.8..1.5), Window Mode (Windowed / Fullscreen), Audio Buses (Master, Music, SFX), and Subtitles.
   - `scenes/ui/settings_menu.tscn`: PanelContainer with TabContainer and style overrides (`_focus_style` warm gold border).
   - `scripts/ui/notification_manager.gd` (255 lines): Layer 15, `MAX_VISIBLE_TOASTS = 2`, `DEFAULT_DURATION = 2.5`, `ERROR_DEBOUNCE_TIME = 1.2`, dynamic PanelContainer styling by type (error/success/pickup/info), alpha fadeout in last 0.4s.
   - `scenes/ui/notification_toast.tscn`: Control root with `mouse_filter = 2` (IGNORE), VBoxContainer with `mouse_filter = 2` (IGNORE) anchored to bottom-right (`offset_left = -340, offset_top = -160, offset_right = -40, offset_bottom = -40`).
   - `default_bus_layout.tres`: AudioBusLayout with `Music` (idx 1, send Master) and `SFX` (idx 2, send Master).
   - `project.godot`: Line 27 registers `audio/buses/default_bus_layout="res://default_bus_layout.tres"`.
   - `scripts/save/save_manager.gd`: Lines 635-691 define `ensure_audio_buses()`, `apply_all_settings()`, and `_apply_bus_volume()`. Live mutations:
     - `tree.root.content_scale_factor = ui_scale_val`
     - `AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear_vol, 0.0001, 1.0)))`
     - `p.fov = fov_val` which triggers `PlayerController` setter -> `camera.fov = fov`.
     - `p.mouse_sensitivity_multiplier = sens_mult` which triggers `PlayerController` setter -> `mouse_sensitivity = DEFAULT_MOUSE_SENSITIVITY * mouse_sensitivity_multiplier`.

2. **Test Suite Verification (`tests/suites/test_ui.gd`):**
   - 551 lines, 17 test methods across 8 groups.
   - 56 `Assertions.assert_` statements, plus circular traversal button loops and multi-step queue steps, generating 126 assertions executed in Suite 21.
   - No hardcoded boolean literals (no `assert_true(true)`).

3. **Execution Tool Output:**
   - Command: `& "C:\Users\HP\.local\bin\godot_console.exe" --headless --script tests/test_runner.gd`
   - Output snippet:
     ```
     ==================================================
     [SUITE 21] TestUI: Kenyamanan Terpadu, Fokus Keyboard & Notifikasi Jujur (UI-001)
     ==================================================
     ==================================================
     [TEST_RUNNER] SUMMARY:
       Assertions Passed: 6895
       Assertions Failed: 0
       RESULT: ALL SUITES PASSED (Exit Code: 0)
     ==================================================
     ```

---

## 2. Logic Chain

1. **Integrity Mode Alignment:**
   - Under `ORIGINAL_REQUEST.md`, the integrity mode is `development`.
   - Development mode prohibits hardcoded test outputs, facade implementations, and fabricated logs.
   - Direct code inspection reveals that all settings controls bind directly to live engine parameters and disk configuration (`user://settings.cfg`). No stubs or dummy facades are present.

2. **Empirical Mutation Verification:**
   - Camera3D FOV: `PlayerController.fov` has an `@export` setter directly assigning `camera.fov = fov`. In `test_t21_01_fov_and_ui_scale_live_bindings`, setting FOV to 90.0° mutates both `player.fov` and `cam.fov` to exactly 90.0°.
   - Window Scaling: `SaveManager.apply_all_settings()` mutates `tree.root.content_scale_factor`. Verified at 1.25 in test.
   - Audio Bus Volumes: `AudioServer.get_bus_volume_db()` verifies that setting volume to 0.5 linear applies `-6.02 dB` via `linear_to_db()`, and setting 0.0 activates `AudioServer.is_bus_mute()`.
   - Player Sensitivity: Setting multiplier adjusts `player.mouse_sensitivity` proportionally to base sensitivity.
   - Therefore, the settings pipeline performs authentic, non-facade mutations.

3. **User Intent Protection & Safety:**
   - In `pause_menu.gd`, destructive actions cannot bypass user intent:
     - The confirmation modal is displayed with `push_subpanel(confirm_modal, modal_btn_cancel)`, giving safe initial focus to Cancel.
     - In `_execute_save_and_exit()`, if `sm.save_game("manual")` fails (tested via `simulate_write_failure = true`), the function logs honest feedback to `status_label` and executes `return`, preventing `tree.quit()`.
     - Esc key handling pops subpanels hierarchically, ensuring nested modals are dismissed before the pause menu itself can close.

4. **Honest Notification Semantics:**
   - The notification system restricts visible toasts to 2, queues surplus messages, automatically pops queued items upon duration expiry, merges duplicate pickups by incrementing quantity and resetting duration, and silences rapid error spam within 1.2s.
   - Crucially, mouse events pass completely through all notification components via `Control.MOUSE_FILTER_IGNORE`, ensuring no game input disruption.

---

## 3. Caveats

1. **Headless Execution Environment:**
   - In `--headless` mode, physical monitor resolution switching, GPU hardware vsync, and audio speaker output are routed to Godot's dummy null drivers. However, internal engine representations (`DisplayServer`, `AudioServer`, and `Window` scale factor) were directly inspected and verified.
2. **Subjective Ergonomics:**
   - Visual color palette and UI aesthetic feel require interactive playtesting during the subsequent `ART-001` and `QA-001` milestones.

---

## 4. Conclusion

The work product for milestone **UI-001** fulfills all requirements of `PRD.md` (FR16, FR21), `UI_UX.md` (§ 2–§ 7), `CONTENT.md` (§ 11, § 14), `TASKS.md` (UI-001), and `TEST_PLAN.md` (T18, T21, T28, T51, T52, T53, T54). All tests run genuinely without hardcoding or facades.

**Final Verdict**: **CLEAN**. The work product is certified for acceptance.

---

## 5. Verification Method

To independently reproduce and verify this audit verdict:

1. Open PowerShell in the project root:
   ```powershell
   & "C:\Users\HP\.local\bin\godot_console.exe" --headless --script tests/test_runner.gd
   ```
2. Inspect the console summary output:
   - Expected: `Assertions Passed: 6895`, `Assertions Failed: 0`, `RESULT: ALL SUITES PASSED (Exit Code: 0)`.
3. Invalidation condition:
   - If any test in Suite 21 fails, or if any settings mutation in `scripts/save/save_manager.gd` or `scripts/player/player_controller.gd` is decoupled from the live engine nodes, this verdict is invalidated.
