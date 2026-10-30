## 2026-10-29T16:05:30Z

You are explorer_ui_001_2.
Your working directory is:
c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_ui_001_2\

Read the authoritative original request at:
c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md

Also read:
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen10\PROJECT.md`
- `docs/UI_UX.md` (specifically UI06 Settings Panel, §6 Feedback)
- `docs/CONTENT.md` §14
- `docs/TEST_PLAN.md` (cases T21, T51, T52)
- `scripts/save/save_manager.gd` (specifically `load_settings()`, `save_settings()`, `settings.cfg`)
- `scripts/player/player_controller.gd` (FOV, mouse sensitivity, head bob)

YOUR TASK:
Investigate and design the Settings Panel and live engine parameter bindings for UI-001:
1. Examine `SaveManager.load_settings()` and `save_settings()` in `scripts/save/save_manager.gd` to understand the exact structure of `settings.cfg`:
   - `gameplay`: mouse_sensitivity (default 1.0, range 0.1..5.0), head_bob (default false)
   - `video`: fov (default 80.0, range 60..100), ui_scale (default 1.0, range 0.8..1.5), window_mode ("windowed", "fullscreen")
   - `audio`: master_volume (default 1.0), music_volume (default 0.8), sfx_volume (default 0.8)
   - `accessibility`: subtitles (default true)
2. Detail how each setting binds dynamically to live engine systems:
   - FOV: how it updates `Camera3D.fov` in `PlayerController`.
   - Mouse sensitivity: how it scales camera rotation in `PlayerController._unhandled_input`.
   - Head bob: toggles bobbing calculations in `PlayerController`.
   - UI scale: how to scale root UI canvas or Control theme/scaling (T21).
   - Audio: how to convert linear volume (0.0..1.0) to decibels via `linear_to_db()` and set on `AudioServer.set_bus_volume_db` for buses "Master", "Music", "SFX" (ensure audio buses exist or default bus fallback).
3. Verify that settings load dynamically on startup and survive save/load and scene resets (T52).
4. Recommend implementation strategy, UI controls, signals, and interface contracts for the Worker.
5. Write your comprehensive report to `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_ui_001_2\handoff.md`.
6. Send a completion message back to the orchestrator.
