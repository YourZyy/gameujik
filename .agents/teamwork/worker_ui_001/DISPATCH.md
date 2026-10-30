## 2026-10-29T16:31:01Z
You are worker_ui_001.
Your working directory is:
c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_ui_001\

Read your dispatch assignment below and the authoritative original request at:
c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md

Also read the synthesis and handoffs from the 3 Explorers:
- c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_ui_001_1\handoff.md (Pause Menu, Modal Dialogs, Input Context & Esc handling)
- c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_ui_001_2\handoff.md (Settings Panel, Live Engine Bindings: FOV, sens, UI scale, AudioServer buses)
- c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_ui_001_3\handoff.md (Toast Notifications, Keyboard Accessibility/Focus, Suite 21 test design)

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

YOUR MISSION:
Implement Milestone UI-001 (Kenyamanan Terpadu: Menu Awal, Pause, Pengaturan, Aksesibilitas, Navigasi Fokus Keyboard, dan Alur Error):
1. **Audio Bus Layout**:
   Ensure AudioServer has buses "Master", "Music", and "SFX" (create `default_bus_layout.tres` and register in `project.godot` or ensure runtime creation so audio sliders work smoothly).
2. **Settings Menu (`scenes/ui/settings_menu.tscn`, `scripts/ui/settings_menu.gd`)**:
   - FOV slider (60..100, step 1, default 80), updates `PlayerController.fov` and `Camera3D.fov`.
   - Mouse sensitivity slider (0.1..5.0, step 0.1, default 1.0), updates `PlayerController.mouse_sensitivity`.
   - Head bob toggle (CheckBox, default false), updates `PlayerController.head_bob_enabled`.
   - UI scale slider (0.8..1.5, step 0.05, default 1.0), updates `get_tree().root.content_scale_factor` (T21).
   - Window mode OptionButton ("Jendela" 0, "Layar Penuh" 3 or 4) via `DisplayServer.window_set_mode()`.
   - Master, Music, SFX volume sliders (0%..100%, defaults 70%, 40%, 70% in line with `CONTENT.md` §14 and Suite 19 assertions), updates `AudioServer.set_bus_volume_db` using `linear_to_db()` and mute on volume <= 0.0001.
   - Subtitle toggle (CheckBox, default true).
   - Action buttons: "Simpan & Terapkan", "Kembalikan Default", "Kembali".
   - Seamless integration with `SaveManager.load_settings()` and `save_settings()` (`user://settings.cfg`).
3. **Pause Menu (`scenes/ui/pause_menu.tscn`, `scripts/ui/pause_menu.gd`)**:
   - Buttons: "Lanjutkan", "Simpan Progres", "Muat Checkpoint", "Pengaturan", "Kembali ke Pekarangan", "Game Baru", "Keluar ke Desktop".
   - Modal confirmation dialogs for:
     - "Mulai Game Baru? Progres yang belum disimpan akan hilang." ("Batal" vs "Mulai Baru") (T53).
     - "Keluar ke Desktop? Pastikan progres telah disimpan." ("Batal" vs "Keluar") (T53).
   - Esc key behavior: closes confirmation modal if open; if settings open, returns to pause; if on pause, resumes game (T18, T28).
   - Integrates with `InputManager` (pushes/pops `ContextMode.PAUSE`, respects `auto_pause_on_focus_loss`).
4. **Honest Notifications (Toast System)**:
   - Dedicated notification toast container positioned at bottom-right ("bawah samping"), not overlapping reticle or interaction prompt (T54, UI_UX §6).
   - Maximum 2 visible toasts simultaneously.
   - Duration 2.5s with smooth fadeout.
   - Rapid item pickup merging (e.g. "Memetik Bayam (x2)" refreshing duration).
   - Repeated error debounce (1.2s window so holding down an invalid action does not flood the screen).
   - `mouse_filter = MOUSE_FILTER_IGNORE` so mouse look and clicks are never blocked.
5. **Keyboard Focus Navigation (T51)**:
   - High-contrast visual focus styling (`StyleBoxFlat` with distinct 2px accent border).
   - Circular, non-softlocking focus loops for all menus (Up/Down arrow keys, Tab/Shift+Tab).
   - Tab conflict resolution: Tab in solo inventory closes panel; Tab in other menus navigates focus.
   - Focus restoration: closing modal restores focus to the invoking button.
6. **Main Scene Integration**:
   - Add `PauseMenu` and `NotificationManager` / toast container to `scenes/main.tscn` or root UI layer.
7. **Acceptance Test Suite `tests/suites/test_ui.gd` (Suite 21)**:
   - Implement comprehensive tests covering T18, T21, T28, T51, T52, T53, T54 per Explorer 3's test design.
   - Register Suite 21 in `tests/test_runner.gd`.
   - Run headless test runner:
     & "C:\Users\HP\Fauzi\Private Working\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --headless --script tests/test_runner.gd
     Ensure all 21 suites pass with 0 failures and record the assertion count.
8. **Documentation & Task Register Updates (AGENTS.md compliance)**:
   - Create `docs/completed_tasks/016-kenyamanan-terpadu-menu-pause-pengaturan-aksesibilitas.md` following `TEMPLATE.md`.
   - Update `docs/PROJECT_STATUS.md`: add bullet for 016, update latest description (150-300 words).
   - Update `docs/TASKS.md`: mark UI-001 as `SELESAI` with link `[016]`.
   - Write handoff report in your working directory and notify the orchestrator.
