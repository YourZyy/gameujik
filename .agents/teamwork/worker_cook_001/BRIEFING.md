# BRIEFING — 2026-10-28T14:48:00Z

## Mission
Implement milestone COOK-001 (Autoload KitchenManager, KitchenUI scene & script, landmark wiring in main.gd, HUD dynamic prompt, TestCooking Suite 11 in tests/suites/test_cooking.gd, registered in tests/test_runner.gd) and ensure all 11 test suites pass headless with exit code 0.

## 🔒 My Identity
- Archetype: worker / implementer
- Roles: implementer, qa, specialist
- Working directory: c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_cook_001\
- Original parent: 9ce6da24-fd14-4dbb-be3b-c55e3808c4cc
- Milestone: COOK-001

## 🔒 Key Constraints
- Genuine implementation only; no dummy/facade implementations, no hardcoded test results.
- Godot 4.7.2 GDScript, gl_compatibility renderer.
- Preserve backward compatibility for InventoryManager, RecipeManager, and existing test suites (Suites 1..10 must remain 100% green).
- P0 Sayur Bening Bayam dan Jagung (3 bayam, 1 jagung, 1 temu kunci).
- Physical withdrawal on reservation (backpack first, then storage_home).
- Safe cancellation & refund: origin container -> alternate container -> kitchen_refund. Raw ingredients must NEVER enter output_dish_slot.
- 4.0s hold prep duration. Releasing retains progress or resets cleanly; completion transitions to ready_to_heat; cooking does NOT start automatically from hold.
- Anti-spam guard: rapid clicks return current job idempotently without double deduction.
- Interlock: WorldResourceManager.can_sleep() rejects sleep while kitchen job is active.

## Current Parent
- Conversation ID: 9ce6da24-fd14-4dbb-be3b-c55e3808c4cc
- Updated: not yet

## Task Summary
- **What to build**: KitchenManager Autoload (`scripts/cooking/kitchen_manager.gd`), KitchenUI scene & script (`scenes/ui/kitchen_ui.tscn`, `scripts/ui/kitchen_ui.gd`), main.gd wiring for `station_kitchen_home`, dynamic HUD prompt in `scripts/ui/hud.gd`, Suite 11 `tests/suites/test_cooking.gd`, and register in `tests/test_runner.gd`.
- **Success criteria**: All acceptance criteria T10, T11, T12, T13, T40, interlocks and snapshots passing in Suite 11; Suites 1..11 passing headless with 0 errors and exit code 0.
- **Interface contracts**: PROJECT.md § Interface Contracts, CONTENT.md § 2, 3, 4, 11, 12, PROTOTYPE.md § 4, 5, 6.2, 6.3.
- **Code layout**: scripts/cooking/kitchen_manager.gd, scenes/ui/kitchen_ui.tscn, scripts/ui/kitchen_ui.gd, tests/suites/test_cooking.gd.

## Key Decisions Made
- Autoload `scripts/cooking/kitchen_manager.gd` without `class_name` to prevent Godot 4 "Class hides autoload singleton" error.
- Implemented state enum `JobState` (`IDLE`, `RESERVED_PREPARING`, `READY_TO_HEAT`, `COOKING`, `PAUSED`, `OUTPUT_READY`, `REFUND_PENDING`) with `CookingState` alias for backward and cross-script compatibility.
- Implemented dry-run validation in `can_start_preparation()` and physical deduction in `start_preparation()` (backpack first, then storage_home).
- Retained prep hold elapsed progress on interruption (CONTENT § 4), transitioning to `READY_TO_HEAT` upon reaching 4.0s without auto-starting cooking.
- 3-tier refund in `cancel_preparation()` (origin -> alternate -> `kitchen_refund`) with strict isolation from `dish_output_slot`.
- Added `get_used_slots_count()` and `get_slots()` to `InventoryContainer` for safe slot inspection and refund claiming.

## Artifact Index
- `scripts/cooking/kitchen_manager.gd` — Autoload singleton for cooking state & inventory reservation
- `scenes/ui/kitchen_ui.tscn` — Responsive kitchen interface CanvasLayer
- `scripts/ui/kitchen_ui.gd` — Kitchen UI controller
- `tests/suites/test_cooking.gd` — Suite 11 acceptance tests (26 test methods covering T10, T11, T12, T13, T40, interlocks, snapshots)
- `tests/test_runner.gd` — Headless test runner updated with Suite 11
- `scripts/main.gd` — Station kitchen landmark interaction wiring
- `scripts/ui/hud.gd` — Dynamic reticle prompt for kitchen landmark
- `project.godot` — Autoload registration for KitchenManager
- `scripts/inventory/inventory_container.gd` — `get_used_slots_count()` and `get_slots()` helpers

## Change Tracker
- **Files modified**:
  - `project.godot`: Added KitchenManager autoload singleton
  - `scenes/main.tscn`: Instanced KitchenUI CanvasLayer
  - `scripts/main.gd`: Wired station_kitchen_home landmark interaction and KitchenUI open
  - `scripts/ui/hud.gd`: Added dynamic contextual prompt for landmark_kitchen
  - `scripts/inventory/inventory_container.gd`: Added get_used_slots_count() and get_slots() methods
  - `tests/test_runner.gd`: Registered Suite 11 (TestCooking)
- **Files created**:
  - `scripts/cooking/kitchen_manager.gd`: Autoload singleton for cooking state and inventory reservation
  - `scenes/ui/kitchen_ui.tscn`: Responsive Kitchen UI scene
  - `scripts/ui/kitchen_ui.gd`: Kitchen UI script controller
  - `tests/suites/test_cooking.gd`: Suite 11 acceptance tests
- **Build status**: PASS (1,386 assertions passed, 0 failed, exit code 0 across Suites 1..11)
- **Pending issues**: None

## Quality Status
- **Build/test result**: 100% PASS across Suites 1..11 (1,386 assertions passed, 0 failed)
- **Lint status**: 0 violations, clean compilation in `godot --check-only`
- **Tests added/modified**: Added Suite 11 (`tests/suites/test_cooking.gd`) with 26 test methods (153 new assertions)

## Loaded Skills
- **Source**: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\skills\godot-gdscript-headless-testing\SKILL.md`
  - **Local copy**: None (listed in system prompt)
  - **Core methodology**: Headless CLI runner exiting non-zero on test failures
- **Source**: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\skills\godot-gdscript\SKILL.md`
  - **Local copy**: None (listed in system prompt)
  - **Core methodology**: Idiomatic GDScript 2.0 static typing, lifecycle, signals
- **Source**: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\skills\godot-nodes-scenes\SKILL.md`
  - **Local copy**: None (listed in system prompt)
  - **Core methodology**: Reusable scenes, clean node composition, safe tree navigation
- **Source**: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\skills\godot-ui-control\SKILL.md`
  - **Local copy**: None (listed in system prompt)
  - **Core methodology**: Responsive UI layout using Containers, anchors, presets, and theme styling
