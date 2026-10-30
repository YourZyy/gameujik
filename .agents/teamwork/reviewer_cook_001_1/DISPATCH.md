# Task Assignment: reviewer_cook_001_1 (Reviewer 1 for COOK-001)

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
1. Objectively and adversarially review the implementation of COOK-001:
   - Ingredient validation across backpack and storage chest (dry-run check; missing items reporting; output slot gating).
   - Atomic reservation with stable job ID and physical withdrawal (backpack first, then storage).
   - 4.0s hold preparation controller, progress retention on interrupt, and transition to `READY_TO_HEAT`.
   - Pre-cooking cancellation with 3-tier safe refund (origin -> alternate -> `kitchen_refund`).
   - Anti-duplication and anti-spam protection (single job ID, idempotency).
   - Sleep interlock with `WorldResourceManager`.
2. Execute the headless test runner (`cmd /c "C:\Users\HP\.local\bin\godot.exe --headless --path . --script res://tests/test_runner.gd"`) and confirm that all 11 test suites pass with exit code 0.
3. Issue a formal verdict: `APPROVE` or `REQUEST_CHANGES`.

## Output
Write `handoff.md` in your working directory (`.agents/teamwork/reviewer_cook_001_1/`) with Observation, Logic Chain, Caveats, Conclusion (Verdict: APPROVE / REQUEST_CHANGES), and Verification Method. Then send a completion message to parent.


## 2026-10-28T14:52:01Z
You are reviewer_cook_001_1. Your working directory is `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\reviewer_cook_001_1\`.
Read DISPATCH.md in your working directory and execute the objective and adversarial review of COOK-001. Run tests via headless Godot, analyze correctness, completeness, and interface conformance. Deliver your handoff.md with verdict APPROVE or REQUEST_CHANGES and send a completion message to parent.
