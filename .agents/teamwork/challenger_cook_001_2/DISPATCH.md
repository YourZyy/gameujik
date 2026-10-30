# Task Assignment: challenger_cook_001_2 (Challenger 2 for COOK-001)

## Mandatory Reading
- Original User Request: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
- Master Scope: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen6\PROJECT.md`
- Worker Handoff: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_cook_001\handoff.md`
- Codebase Files:
  - `scripts/cooking/kitchen_manager.gd`
  - `scripts/inventory/inventory_manager.gd`
  - `scripts/world/world_resource_manager.gd`
  - `tests/suites/test_cooking.gd`
  - `tests/test_runner.gd`

## Objectives
1. Empirically verify and stress-test the hold preparation, overflow refund, and sleep interlock invariants:
   - Hold action progress: premature release (< 4.0s) retains elapsed time without losing items or transitioning state prematurely (T12).
   - Reaching 4.0s transitions to `READY_TO_HEAT` and does NOT auto-trigger cooking (T12).
   - Safe refund overflow (T40): when origin and alternate containers are filled via fixture during preparation, cancelling safely spills items to `kitchen_refund` storage without losing items or polluting `dish_output_slot`.
   - Sleep interlock: calling `WorldResourceManager.sleep_and_advance_day()` while `KitchenManager.is_job_active()` MUST be rejected with clear message.
2. Run headless test runner or empirical stress script to confirm these invariants.
3. Issue a formal verdict: `APPROVE` or `REQUEST_CHANGES`.

## Output
Write `handoff.md` in your working directory (`.agents/teamwork/challenger_cook_001_2/`) with empirical findings and verdict. Then send a completion message to parent.


## 2026-10-28T14:52:32Z
You are challenger_cook_001_2. Your working directory is `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\challenger_cook_001_2\`.
Read DISPATCH.md in your working directory and execute empirical challenge testing on COOK-001 (hold preparation progression & retention, transition to READY_TO_HEAT without auto-cook, T40 safe refund overflow to kitchen_refund, and WorldResourceManager sleep rejection during active kitchen job). Run headless tests / empirical harness, deliver handoff.md with verdict APPROVE or REQUEST_CHANGES, and send completion message to parent.
