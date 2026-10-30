# Dispatch — worker_gard_001

## Task Assignment
- Role: Gardening Implementation Worker (GARD-001)
- Objective: Implement the complete plot, spot, tool, hold action, and area care systems for milestone GARD-001 per specifications in `docs/CONTENT.md` § 5, § 6, § 7, § 8, § 9, § 11, § 12, `docs/TASKS.md` (GARD-001), and `docs/TEST_PLAN.md` (T06, T07, T08, T32, T33).
- Required reading (MUST READ FIRST):
  - `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
  - `.agents/teamwork/explorer_gard_001_1/handoff.md` and `analysis.md`
  - `.agents/teamwork/explorer_gard_001_2/handoff.md` and `analysis.md`
  - `.agents/teamwork/explorer_gard_001_3/handoff.md` and `analysis.md`
  - `docs/completed_tasks/TEMPLATE.md`
- Scope of Implementation:
  1. `GardenManager` autoload singleton in `res://scripts/gardening/garden_manager.gd`:
     - Registered in `project.godot` as Autoload.
     - Manages `plot_home_01` state: `is_hoed` (false), `has_compost` (false), `nutrients` (0.0), `moisture` (0.0).
     - Manages 4 spots: `slot_01`..`slot_04` (with bidirectional mapping to 3D nodes `spot_0`..`spot_3`).
     - Manages watering can: capacity 10 units, starting water 0.
     - Area operations:
       - `hoe_plot() -> bool`: sets `is_hoed = true`.
       - `apply_compost() -> bool`: requires `is_hoed and not has_compost`, consumes 1 `soil_compost`, sets `has_compost = true`.
       - `fertilize_plot() -> bool`: requires `nutrients < 20.0`, consumes 1 `fertilizer_basic`, sets `nutrients = 100.0`.
       - `water_plot() -> bool`: requires `moisture < 60.0` and `watering_can_water >= 2`, consumes 2 water, sets `moisture = 80.0`.
       - `refill_watering_can() -> bool`: requires `water_home`, sets water to 10.
       - `plant_seed(spot_id: String) -> bool`: requires ready plot (`is_hoed and has_compost`), unoccupied spot, and 1 `seed_bayam` in inventory. Sets spot occupied with `crop_bayam`.
     - Evaporation loop: 0.1 moisture loss per active second in `_process()`, gated by `not InputManager.is_simulation_paused()`.
     - Snapshot functions: `get_save_snapshot()` and `load_save_snapshot()`.
  2. Input actions & Tool Selection:
     - Add `tool_1` (Key 1), `tool_2` (Key 2), `tool_3` (Key 3), `tool_4` (Key 4) in `project.godot`.
     - Tool toggle: pressing active tool key returns to hands-free (`tool_none`).
  3. Hold Action & Cancellation Mechanics (T32):
     - 2.0s hold LMB with `tool_hoe` on plot -> hoe plot.
     - 1.0s hold LMB with `tool_fertilizer` on plot -> fertilize plot.
     - 2.0s hold LMB with `tool_watering_can` on plot -> water plot.
     - 2.0s hold E on `water_home` -> refill watering can.
     - Releasing button before duration resets progress to 0.0 with ZERO resource deduction.
     - Action commits exactly once; requires button release before next action can start.
     - Compost prompt: `[E] Tambah pembenah — 1` on hoed plot.
  4. Test Suite Deployment:
     - Deploy `tests/suites/test_gardening.gd` (based on `explorer_gard_001_3/proposed_test_gardening.gd`).
     - Register Suite 9 in `tests/test_runner.gd`.
     - Run `test_runner.gd` — all 9 suites must pass with exit code 0.
  5. Governance & Documentation (AGENTS.md § 6 & § 7):
     - Create report `docs/completed_tasks/009-persiapan-petak-benih-perawatan-kebun.md` using `TEMPLATE.md`.
     - Update `docs/PROJECT_STATUS.md` (add chronological link in completed tasks, update latest status in 150-300 words).
     - Update `docs/TASKS.md` (mark GARD-001 as SELESAI).
- Output: Deliver hard handoff report to `.agents/teamwork/worker_gard_001/handoff.md`.
