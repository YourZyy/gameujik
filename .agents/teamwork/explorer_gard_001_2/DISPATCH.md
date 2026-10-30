# Dispatch — explorer_gard_001_2

## Task Assignment
- Role: Tool System & Player Action Interaction Explorer (GARD-001)
- Objective: Investigate and design tool selection, hold mechanics, and player interaction:
  - Tool system: keys 1 (`tool_hoe`), 2 (`tool_seed`), 3 (`tool_fertilizer`), 4 (`tool_watering_can`). None active / hand free default or toggleable.
  - Watering can capacity: 10 abstract units, starts at 0. Refills at `water_home` (2s hold E).
  - Hold mechanic:
    - 2s hold LMB with `tool_hoe` on plot -> gembur = true.
    - 1s hold LMB with `tool_fertilizer` on plot -> nutrients = 100, consumes 1 `fertilizer_basic`.
    - 2s hold LMB with `tool_watering_can` on plot -> moisture = 80, consumes 2 water units.
    - 2s hold E on `water_home` -> refills watering can to 10 units.
  - Cancellation: releasing button before hold completes resets progress cleanly without cost.
  - Re-trigger protection: hold commits once upon completion; player must release and repress before starting a new action.
  - Prompt E for compost: "E Tambah pembenah — 1" when pointing at hoed plot with `soil_compost` in backpack.
  - Spot targeting for planting: pointing at specific spot (`slot_01`..`slot_04`) with `tool_seed` -> left click consumes 1 `seed_bayam`, plants seed.
  - Integration with `InteractionDetector`, `InputManager` (WORLD mode), and `Player` node.
- Required reading:
  - `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md` (MUST READ FIRST)
  - `docs/CONTENT.md` § 6, § 7, § 9, § 11
  - `docs/UI_UX.md` § 4, § 5
  - `scripts/player/player.gd` and `scripts/interaction/interaction_detector.gd`
- Output: Deliver structured report to `.agents/teamwork/explorer_gard_001_2/analysis.md` and `handoff.md`.

## 2026-10-27T17:46:41Z
You are explorer_gard_001_2. Your working directory is `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_gard_001_2\`.
Read `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md` FIRST.
Read your dispatch assignment in `.agents/teamwork/explorer_gard_001_2/DISPATCH.md`.
Read `docs/CONTENT.md` § 6, § 7, § 9, § 11 and `docs/UI_UX.md` § 4, § 5.
Investigate `scripts/player/player.gd` and `scripts/interaction/interaction_detector.gd`.
Design the tool selection system (keys 1-4 for hoe, seed, fertilizer, watering can), watering can capacity (10 units, starts at 0, refilled at water_home), hold action timings (2s hoe, 1s fertilizer, 2s watering, 2s water_home refill), cancellation without cost, re-trigger protection, E prompt for compost, and spot targeting.
Write your analysis to `analysis.md` and complete handoff to `handoff.md`, then send a completion message to parent.
