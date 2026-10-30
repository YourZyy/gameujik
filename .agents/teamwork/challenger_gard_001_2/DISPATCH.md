# Dispatch — challenger_gard_001_2

## Task Assignment
- Role: Area Thresholds, Evaporation & Spot Isolation Challenger (GARD-001 Gate)
- Objective: Empirically stress-test area thresholds, evaporation loop, multi-spot isolation, and zero-softlock starter inventory lifecycle:
  - Write and execute an adversarial stress test script (e.g. `stress_garden_invariants.gd`).
  - Threshold stress challenge: 100 rapid attempts to fertilize at nutrients >= 20 and water at moisture >= 60. Assert 100% rejection with 0 inventory/water loss.
  - Evaporation loop challenge: simulate 100s active vs paused time. Assert moisture decreases strictly at 0.1/s during active play, clamps at 0.0, and completely halts when `InputManager.is_simulation_paused() == true`.
  - Multi-spot isolation challenge: plant in `slot_01`, assert `slot_02`, `slot_03`, `slot_04` remain completely unmodified and unoccupied.
  - Zero-softlock starter inventory lifecycle: pickup `container_starter`, execute full garden preparation (hoe, compost, plant 4 seeds, fertilize, water), assert exact inventory conservation and no item duplication or deletion.
- Required reading (MUST READ FIRST):
  - `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
  - `.agents/teamwork/worker_gard_001/handoff.md`
  - `scripts/gardening/garden_manager.gd`
- Verification commands to run:
  - Execute custom adversarial stress script in headless Godot.
  - `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"`
- Output: Deliver empirical report with explicit verdict (CONFIRMED CORRECT or DEFECT DETECTED) to `.agents/teamwork/challenger_gard_001_2/handoff.md`.

## 2026-10-27T18:27:43Z
You are challenger_gard_001_2. Your working directory is `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\challenger_gard_001_2\`.
Read `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md` FIRST.
Read your dispatch assignment in `.agents/teamwork/challenger_gard_001_2/DISPATCH.md`.
Read worker handoff in `.agents/teamwork/worker_gard_001/handoff.md`.
Empirically stress-test area thresholds (<20 fertilize, <60 water), evaporation loop 0.1/s and simulation pause gating (T33), multi-spot isolation, and zero-softlock starter inventory lifecycle.
Write and run an adversarial stress test script (e.g. `stress_garden_invariants.gd`).
Run full tests: `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"`.
Deliver your handoff report with explicit verdict (CONFIRMED CORRECT or DEFECT DETECTED) to `.agents/teamwork/challenger_gard_001_2/handoff.md` and send a message to parent upon completion.
