# Task Assignment: challenger_cook_001_1 (Challenger 1 for COOK-001)

## Mandatory Reading
- Original User Request: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
- Master Scope: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen6\PROJECT.md`
- Worker Handoff: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_cook_001\handoff.md`
- Codebase Files:
  - `scripts/cooking/kitchen_manager.gd`
  - `scripts/inventory/inventory_manager.gd`
  - `tests/suites/test_cooking.gd`
  - `tests/test_runner.gd`

## Objectives
1. Empirically verify and stress-test the ingredient validation, reservation, and cancellation invariants:
   - Gating invariant: missing 1 bayam, 1 corn, or 1 temu kunci MUST completely reject preparation without deducting any items or creating any jobs (T10).
   - Atomic reservation: pulling from split containers (backpack + chest) deducts exact amounts in proper priority order without double reservation (T11).
   - Anti-duplication stress: rapid spam calls (100x) to `start_preparation()` must yield exactly 1 active job ID, 1 batch of reserved items, and 0 duplicates (T12/T40).
   - Cancellation exact return: cancelling before cooking restores 100% of items to their original containers (T13).
   - Conservation of matter: initial item total == final item total across all cancellation and reservation tests.
2. Run headless test runner or custom stress script to confirm these invariants.
3. Issue a formal verdict: `APPROVE` or `REQUEST_CHANGES`.

## Output
Write `handoff.md` in your working directory (`.agents/teamwork/challenger_cook_001_1/`) with empirical findings and verdict. Then send a completion message to parent.

## 2026-10-28T14:52:22Z
You are challenger_cook_001_1. Your working directory is `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\challenger_cook_001_1\`.
Read DISPATCH.md in your working directory and execute empirical challenge testing on COOK-001 (gating invariant T10, atomic reservation T11, anti-duplication & spam stress T12, exact cancellation return T13, and conservation of matter). Run headless tests / empirical harness, deliver handoff.md with verdict APPROVE or REQUEST_CHANGES, and send completion message to parent.
