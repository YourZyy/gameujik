# Task Assignment: worker_cook_001 (COOK-001 Implementation)

## Mandatory Reading
- Original User Request: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
- Master Scope: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen6\PROJECT.md`
- Explorer Reports:
  - `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_cook_001_1\handoff.md`
  - `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_cook_001_2\handoff.md`
  - `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_cook_001_3\handoff.md`
- Relevant Skills:
  - `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\skills\godot-gdscript-headless-testing\SKILL.md`
  - `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\skills\godot-gdscript\SKILL.md`
  - `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\skills\godot-nodes-scenes\SKILL.md`
  - `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\skills\godot-ui-control\SKILL.md`

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Objectives
Implement milestone COOK-001 based on the synthesized recommendations from Explorers 1, 2, and 3:
1. **Autoload `KitchenManager` (`scripts/cooking/kitchen_manager.gd`)**:
   - Register in `project.godot`: `KitchenManager="*res://scripts/cooking/kitchen_manager.gd"`.
   - State machine: `IDLE`, `PREPARING`, `READY_TO_HEAT`, `COOKING`, `PAUSED`, `OUTPUT_READY`, `REFUND_PENDING`.
   - `can_start_preparation(recipe_id)`: Dry-run validates required ingredients (3 bayam, 1 jagung, 1 temu kunci) across `backpack` + `storage_home` free stock. Fails cleanly without mutating inventory if any ingredient is missing, returning missing items list.
   - `start_preparation(recipe_id)`: Generates stable `active_job_id` (e.g. `job_sayur_bening_1`). Physically withdraws ingredients from `backpack` first, then `storage_home` (lowest slot index first). Records `origin_records: Array[Dictionary]`. Anti-spam guard: if job is already active, returns current job idempotently without double deduction.
   - Preparation hold controller: 4.0s duration. Releasing button before 4.0s retains elapsed progress without losing items or state corruption. Reaching 4.0s transitions to `READY_TO_HEAT`.
   - `cancel_preparation()`: Cancels active job and restores ingredients:
     - Level 1: Return to origin container (`backpack` / `storage_home`).
     - Level 2: If origin container is full, return to alternate container.
     - Level 3: If alternate container is also full, deposit into `InventoryManager.kitchen_refund`.
     - Raw ingredients MUST NEVER be placed in `output_dish_slot`.
     - Emits `job_cancelled(job_id, refunded_items)` and clears active job.
   - Status query helpers: `is_job_active() -> bool`, `is_cooking_active() -> bool` (for `WorldResourceManager.can_sleep()` interlock).
   - Save snapshot helpers: `get_save_snapshot() -> Dictionary` and `load_save_snapshot(data: Dictionary) -> bool`.
2. **Kitchen UI (`scenes/ui/kitchen_ui.tscn` and `scripts/ui/kitchen_ui.gd`)**:
   - CanvasLayer with responsive layout: recipe summary, ingredients grid, prep progress bar & hold button, ready section, cancel button, feedback label, and refund notification/claim button if refund storage has items.
   - Connect to `KitchenManager` signals.
3. **World Integration (`scripts/main.gd` & `scripts/ui/hud.gd`)**:
   - In `main.gd`: Wire `station_kitchen_home` Interactable to open `KitchenUI` and push `InputManager.ContextMode.KITCHEN`.
   - In `hud.gd`: Format dynamic reticle prompt for `landmark_kitchen`: `[E] Masak`, `[E] Lanjutkan Dapur`, or `[E] Ambil Masakan`.
4. **Test Suite 11 (`tests/suites/test_cooking.gd`)**:
   - Implement comprehensive acceptance tests for:
     - **T10**: Recipe validation & gating (0-ingredient rejection, partial-ingredient rejection, honest Indonesian message).
     - **T11**: Ingredient reservation & origin mapping (backpack first, then storage; stable job ID; unreserved items untouched).
     - **T12**: 4.0s hold preparation & anti-spam (progress advancing, premature release retention, completion to `READY_TO_HEAT`, anti-spam click idempotency).
     - **T13**: Pre-cooking cancellation & exact origin return (100% item restoration, zero item loss, return to `IDLE`).
     - **T40**: Safe refund redirection & strict isolation (fixture fills origin and alternate containers -> items safely overflow to `kitchen_refund`; conservation of matter verified; output slot unpolluted).
     - **Interlock with WorldResourceManager**: Sleeping in bed rejected while kitchen job is active.
   - Register Suite 11 in `tests/test_runner.gd`.
5. **Headless Verification**:
   - Run `godot --headless --path . --script res://tests/test_runner.gd`.
   - Verify that all 11 test suites pass with 0 errors and exit code 0.

## Output
Write `handoff.md` in your working directory (`.agents/teamwork/worker_cook_001/`) detailing:
- Files modified/added
- Build and test commands executed with terminal logs
- Total assertions passed and status of Suites 1..11
- Confirmation of readiness for Reviewers, Challengers, and Auditor
- Send completion message to parent.


## 2026-10-28T14:19:52Z
You are worker_cook_001. Your working directory is `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_cook_001\`.
Read DISPATCH.md in your working directory and implement milestone COOK-001 (Autoload KitchenManager, KitchenUI scene & script, landmark wiring in main.gd, HUD dynamic prompt, TestCooking Suite 11 in tests/suites/test_cooking.gd, registered in tests/test_runner.gd).

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Run headless Godot test runner to verify Suites 1..11 pass cleanly with exit code 0. Deliver handoff.md and send completion message to parent.
