# Task Assignment: auditor_cook_001 (Forensic Auditor for COOK-001)

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
Perform a forensic integrity audit on the COOK-001 implementation:
1. Static analysis: Check for hardcoded test values, mock returns in production scripts, dummy facade implementations, or bypassed checks.
2. Runtime tracing / test validation: Verify that `tests/suites/test_cooking.gd` genuinely exercises `KitchenManager`, `InventoryManager`, `RecipeManager`, and `KitchenUI` without stubbing out core production logic or circumventing real state transitions.
3. Verify that changes to `inventory_container.gd` (`get_used_slots_count`, `get_slots`) are genuine data helpers, not testing backdoors.
4. Verify that headless execution is authentic and exit code 0 is genuine.
5. Issue a formal audit verdict: `CLEAN` or `INTEGRITY VIOLATION`.

## Output
Write `handoff.md` in your working directory (`.agents/teamwork/auditor_cook_001/`) with comprehensive evidence chain and final verdict. Then send a completion message to parent.


## 2026-10-28T14:52:39Z
You are auditor_cook_001. Your working directory is `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\auditor_cook_001\`.
Read DISPATCH.md in your working directory and execute a forensic integrity audit on COOK-001 implementation. Verify that no cheats, dummy facades, hardcoded outputs, or mocked production logic exist. Deliver your handoff.md with verdict CLEAN or INTEGRITY VIOLATION and send a completion message to parent.
