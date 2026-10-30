# Task Assignment: challenger_world_001_2 (Challenger 2 for WORLD-001)

## Mandatory Reading
- Original User Request: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
- Master Scope: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen6\PROJECT.md`
- Worker Handoff: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_world_001_v2\handoff.md`
- Codebase Files:
  - `scripts/world/world_resource_manager.gd`
  - `scripts/gardening/garden_manager.gd`
  - `tests/suites/test_world.gd`
  - `tests/test_runner.gd`

## Objectives
1. Empirically verify and stress-test the Day Cycle and Bed Rest invariants:
   - Day duration: 720.0s natural day progression; pauses during modal contexts.
   - Sleep / Bed Rest: Sleeping advances day by 1, resets foraging nodes for the new day.
   - Non-decay agricultural preservation: Sleeping or jumping days MUST NOT degrade crop stages, soil moisture, or nutrients abnormally (PROTOTYPE § 5.1 & TASKS § 3 WORLD-001).
   - Cooking safety during sleep: Sleep must be prohibited if an active cooking job is running.
2. Run headless test runner or custom verification script to confirm invariants.
3. Issue a formal verdict: `APPROVE` or `REQUEST_CHANGES`.

## Output
Write `handoff.md` in your working directory (`.agents/teamwork/challenger_world_001_2/`) with empirical findings and verdict. Then send a completion message to parent.


## 2026-10-28T13:48:08Z
[Message] timestamp=2026-10-28T13:48:08Z sender=9ce6da24-fd14-4dbb-be3b-c55e3808c4cc priority=MESSAGE_PRIORITY_HIGH content=You are challenger_world_001_2. Your working directory is `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\challenger_world_001_2\`.
Read DISPATCH.md in your working directory and execute empirical challenge testing on WORLD-001 (day calendar 720s, modal pause, bed resting, non-decay agriculture, cooking safety during sleep). Deliver your handoff.md with verdict APPROVE or REQUEST_CHANGES and send a completion message to parent.
