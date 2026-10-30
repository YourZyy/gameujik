# Task Assignment: explorer_cook_001_2 (COOK-001 Kitchen Station & 4s Hold Preparation)

## Mandatory Reading
- Original User Request: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
- Master Scope: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen6\PROJECT.md`
- Core Documents:
  - `PRD.md` § FR11, FR12
  - `docs/CONTENT.md` § 4, § 5, § 6, § 11, § 12
  - `docs/PROTOTYPE.md` § 4, § 5, § 6.2
  - `docs/UI_UX.md` § UI05 (Kitchen UI)
  - `docs/TASKS.md` § COOK-001
  - `docs/TEST_PLAN.md` § T10, T12, T40
- Codebase Files:
  - `scripts/gardening/hold_action_controller.gd`
  - `scripts/core/input_manager.gd`
  - `scripts/ui/hud.gd`
  - `scenes/world/level_graybox.tscn` (find `station_kitchen_home`)
  - `scripts/main.gd`

## Objectives
1. Investigate the 3D landmark `station_kitchen_home` in `level_graybox.tscn` and interaction binding:
   - Player interaction detection (prompt: `[E] Masak` or `[E] Buka Dapur`).
   - Input context transition to `ContextMode.KITCHEN` (captures/frees mouse, freezes world simulation).
2. Investigate the preparation hold mechanic (4.0 seconds hold "Siapkan"):
   - Reusing or adapting `HoldActionController` for 4.0s preparation.
   - Premature release (< 4.0s) cancels preparation without mutating state or consuming items.
   - Successful 4.0s completion transitions job state to `ready_to_heat`.
   - Anti-spam guard: spamming start/hold must not create duplicate jobs or double reservations.
3. Investigate the Kitchen UI layout (`kitchen_ui.tscn` or embedded HUD panel):
   - Ingredient slots view, recipe details, "Siapkan" button / hold indicator, Cancel button.
4. Provide concrete GDScript architecture, scene node hierarchy, and interaction flow recommendations.

## Output
Write `handoff.md` in your working directory (`.agents/teamwork/explorer_cook_001_2/`) detailing Observation, Logic Chain, Recommendations, and Node Hierarchy. Then send a completion message to parent.


## 2026-10-28T14:07:17Z
You are explorer_cook_001_2. Your working directory is `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_cook_001_2\`.
Read DISPATCH.md in your working directory and investigate the 3D kitchen landmark, input context mode, UI layout, and 4.0s hold preparation controller for COOK-001. Deliver handoff.md and send a completion message to parent.
