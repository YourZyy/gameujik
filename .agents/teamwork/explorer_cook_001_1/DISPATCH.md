# Task Assignment: explorer_cook_001_1 (COOK-001 Ingredient Validation & Reservation)

## Mandatory Reading
- Original User Request: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
- Master Scope: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen6\PROJECT.md`
- Core Documents:
  - `PRD.md` § FR11, FR12
  - `docs/CONTENT.md` § 2, § 3, § 4, § 5, § 11, § 12
  - `docs/PROTOTYPE.md` § 4, § 6.2
  - `docs/TASKS.md` § COOK-001
  - `docs/TEST_PLAN.md` § T10, T11, T12, T13, T40
- Codebase Files:
  - `scripts/inventory/inventory_manager.gd`
  - `scripts/inventory/inventory_container.gd`
  - `scripts/recipe/recipe_manager.gd`
  - `scripts/world/world_resource_manager.gd`
  - `scripts/cooking/kitchen_manager.gd` (if exists, or see where kitchen logic should reside)

## Objectives
1. Investigate ingredient validation across backpack (`inv.backpack`) and storage chest (`inv.storage`).
   - Recipe requirement: 3 `ingredient_bayam`, 1 `ingredient_jagung`, 1 `ingredient_temu_kunci`.
   - Unified free stock calculation (excluding currently reserved ingredients).
2. Investigate atomic ingredient reservation mechanism with a stable job ID (e.g. `job_cooking_01`):
   - Reservation mapping: tracking exactly how many items were taken from backpack vs storage chest.
   - Insufficient ingredient rejection: atomic rollback without mutating inventories if any required ingredient is missing.
3. Investigate pre-cooking cancellation & safe refund:
   - Returning items exactly to origin containers (backpack / storage).
   - Handling container full conditions: if backpack/storage is filled after reservation, spill unreturned items into persistent `kitchen_refund_storage`.
4. Provide concrete GDScript architecture, interface contracts, and fix recommendations.

## Output
Write `handoff.md` in your working directory (`.agents/teamwork/explorer_cook_001_1/`) detailing Observation, Logic Chain, Recommendations, and Interface Signatures. Then send a completion message to parent.


## 2026-10-28T14:07:09Z
You are explorer_cook_001_1. Your working directory is `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_cook_001_1\`.
Read DISPATCH.md in your working directory and investigate ingredient validation, atomic reservation, origin mapping, and pre-cooking cancellation with refund storage for COOK-001. Deliver handoff.md and send a completion message to parent.
