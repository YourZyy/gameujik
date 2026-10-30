# Task Assignment: reviewer_cook_001_2 (Reviewer 2 for COOK-001)

## Mandatory Reading
- Original User Request: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
- Master Scope: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen6\PROJECT.md`
- Worker Handoff: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_cook_001\handoff.md`
- Codebase Files:
  - `scripts/cooking/kitchen_manager.gd`
  - `scenes/ui/kitchen_ui.tscn`
  - `scripts/ui/kitchen_ui.gd`
  - `scripts/main.gd`
  - `scripts/ui/hud.gd`
  - `tests/suites/test_cooking.gd`
  - `tests/test_runner.gd`
  - `project.godot`

## Objectives
1. Independently review the interface contracts and UI/world integration for COOK-001:
   - `KitchenManager` Autoload singleton configuration and namespace safety in Godot 4.7.
   - `KitchenUI` responsive layout and signal bindings (`cooking_state_changed`, `prep_progress`, `job_cancelled`, etc.).
   - Landmark `station_kitchen_home` raycast interaction detection and dynamic prompt text in `hud.gd`.
   - `InputManager` context switching to `ContextMode.KITCHEN` (mouse freed, player gated, world unpaused).
   - Save snapshot envelope v1 roundtrip persistence.
2. Execute the headless test runner (`cmd /c "C:\Users\HP\.local\bin\godot.exe --headless --path . --script res://tests/test_runner.gd"`) and confirm that all 11 test suites pass with exit code 0.
3. Issue a formal verdict: `APPROVE` or `REQUEST_CHANGES`.

## Output

## 2026-10-28T14:52:12Z
You are reviewer_cook_001_2. Your working directory is `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\reviewer_cook_001_2\`.
Read DISPATCH.md in your working directory and execute the independent review of COOK-001 (interface contracts, UI layout, world landmark interaction, InputManager context switching, save snapshot persistence). Run tests via headless Godot, deliver handoff.md with verdict APPROVE or REQUEST_CHANGES, and send completion message to parent.
