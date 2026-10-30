# Task Assignment: challenger_world_001_1 (Challenger 1 for WORLD-001)

## Mandatory Reading
- Original User Request: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
- Master Scope: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen6\PROJECT.md`
- Worker Handoff: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_world_001_v2\handoff.md`
- Codebase Files:
  - `scripts/world/world_resource_manager.gd`
  - `scripts/inventory/inventory_manager.gd`
  - `scripts/gardening/garden_manager.gd`
  - `tests/suites/test_world.gd`
  - `tests/test_runner.gd`

## Objectives
1. Empirically verify and stress-test the invariants of WORLD-001:
   - Foraging quota: exact 1 yield per calendar day for jagung and temu kunci; harvesting again on the same day MUST fail/yield 0.
   - Emergency reserve: strictly locked while player has seeds in backpack, in chest, or growing on plot; unlocked ONLY when completely out of seeds/crops; idempotent delivery; atomic backpack capacity check.
   - Well water refill: 2.0s hold refills watering can to 10/10 charges; cancel returns to previous charges; full watering can cannot be refilled.
2. Run headless test runner or empirical harness to verify these conditions.
3. Issue a formal verdict: `APPROVE` or `REQUEST_CHANGES`.

## Output
Write `handoff.md` in your working directory (`.agents/teamwork/challenger_world_001_1/`) with empirical findings and verdict. Then send a completion message to parent.


## 2026-10-28T13:48:01Z
You are challenger_world_001_1. Your working directory is `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\challenger_world_001_1\`.
Read DISPATCH.md in your working directory and execute empirical challenge testing on WORLD-001 (foraging quota, emergency reserves anti-exploit lock, well water refill). Deliver your handoff.md with verdict APPROVE or REQUEST_CHANGES and send a completion message to parent.
