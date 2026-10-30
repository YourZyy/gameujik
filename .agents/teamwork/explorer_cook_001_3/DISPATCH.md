# Task Assignment: explorer_cook_001_3 (COOK-001 Test Architecture & Invariant Specifications)

## Mandatory Reading
- Original User Request: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
- Master Scope: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen6\PROJECT.md`
- Core Documents:
  - `PRD.md` § FR11, FR12
  - `docs/CONTENT.md` § 4, § 11, § 12
  - `docs/TASKS.md` § COOK-001
  - `docs/TEST_PLAN.md` § T10, T11, T12, T13, T40
- Codebase Files:
  - `tests/test_runner.gd`
  - `tests/assertions.gd`
  - `tests/suites/test_recipe.gd`
  - `tests/suites/test_inventory.gd`

## Objectives
1. Map out all acceptance test cases for COOK-001 in `TEST_PLAN.md`:
   - **T10**: Recipe Validation & Gating (verifying recipe can only start if all ingredients 3 spinach, 1 corn, 1 temu kunci are present; insufficient ingredients fails with honest error message).
   - **T11**: Ingredient Reservation from Backpack & Storage (exact item count deducted from available stock, mapped to job ID, unreserved items untouched).
   - **T12**: Preparation Hold State (4.0s hold completes to `ready_to_heat`; cancellation before 4.0s restores idle without item loss).
   - **T13**: Safe Pre-Cooking Cancellation (cancelling before heating returns items 100% to source containers; if container filled in interim, redirects to `kitchen_refund_storage`).
   - **T40**: Anti-Duplication & Multi-Job Protection (single active job ID, rapid spam clicks do not duplicate jobs or double-reserve ingredients).
2. Design the test suite structure for Suite 11 (`tests/suites/test_cooking.gd`) to be registered in `tests/test_runner.gd`.
3. Specify all required test assertions, edge case assertions, and anti-cheat checks.

## Output
Write `handoff.md` in your working directory (`.agents/teamwork/explorer_cook_001_3/`) detailing Observation, Logic Chain, Test Method Design, and Assertion Matrix. Then send a completion message to parent.


## 2026-10-28T14:07:28Z
Received dispatch from parent `9ce6da24-fd14-4dbb-be3b-c55e3808c4cc`:
"You are explorer_cook_001_3. Your working directory is `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_cook_001_3\`.
Read DISPATCH.md in your working directory and investigate the test architecture, Suite 11 design, and invariant test matrix for COOK-001 (T10, T11, T12, T13, T40). Deliver handoff.md and send a completion message to parent."
