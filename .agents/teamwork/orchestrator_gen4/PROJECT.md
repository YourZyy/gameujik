# Project: Buku Resep 2045 (Godot 4.7.2 / GDScript / Compatibility 3D First Person)

## Architecture
- **Engine & Renderer:** Godot 4.7.2-stable, renderer `gl_compatibility` (OpenGL 3.3 desktop compatibility mode for Intel UHD / MX130 stability).
- **Presentation Layer:** 3D First-person camera (CharacterBody3D, 1.6m eye height, pitch clamped -85° to +85°), UI HUD & modal dialogs (CanvasLayer).
- **Core Modules & Autoloads:**
  - `GameManager` (res://scripts/core/game_manager.gd): Core state, pause coordinator, scene transitions, active modal tracker.
  - `InventoryManager` (res://scripts/inventory/inventory_manager.gd): Item registry, backpack (12 slots, stack max 20), storage chest (12 slots), atomic multi-item transfer.
  - `RecipeManager` (res://scripts/recipe/recipe_manager.gd): Recipe definitions (Sayur Bening Bayam dan Jagung), pin/track HUD status, free stock calculation.
  - `GardenManager` (res://scripts/gardening/garden_manager.gd): Plot status (2x2m, hoeing, compost, moisture, nutrients, evaporation), 4 crop spots, 4-stage spinach growth (180s) & stall rules.
  - `WorldResourceManager` (res://scripts/world/world_resource_manager.gd): Corn & temu kunci foraging nodes, well water refill (10/10), calendar/day index (720s), sleep recovery, emergency reserves.
  - `KitchenManager` (res://scripts/cooking/kitchen_manager.gd): Ingredient reservation, 4s hold prep, pre-cooking safe cancel & refund container, heat control (Low 0.5x, Med 1.0x, High 0x stall), 30s cook time, dish output.
  - `DialogueManager` (res://scripts/social/dialogue_manager.gd): Neighbor NPC dialogue, recipe hints, meal sharing confirmation, P0 ending trigger (`meal_used = true`).
  - `SaveManager` (res://scripts/save/save_manager.gd): Atomic write envelope v1 (manual, autosave, .bak fallback), schema validation, recovery point redirection, standalone settings config (`settings.cfg`).
  - `InputManager` / Context Controller: World, Book, Storage, Kitchen, Dialogue, Pause modes; locks/frees mouse, prevents action bleed-through.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 0 | Skills-Aligned Audit & Rebuild | Rebuild & refine SETUP-001, LVL-001, PLY-001 using installed gamedev skills | REBUILD-001 | User instruction 2026-10-27T10:59:01Z |
| 1 | Godot Project Structure & Config | Setup project.godot, compatibility renderer, standard dirs, main scene | SETUP-001 | PRD §3, TASKS §3 |
| 2 | Headless Test Runner Architecture | tests/test_runner.gd & assertions.gd for automated acceptance tests | SETUP-001 | TEST_PLAN, TASKS §3 |
| 3 | Graybox Map & Environmental Collision | Yard, house, village road, corn field, bamboo grove, fence collision | LVL-001 | LEVEL_DESIGN §2 |
| 4 | Safe Return & Recovery Point | Safe return home (0,0,8) and spawn home (0,0,1) | LVL-001 | LEVEL_DESIGN §4 |
| 5 | First-Person Movement & Look | CharacterBody3D, WASD 3m/s, mouse look, vertical pitch clamp | PLY-001 | PRD FR01, CONTENT §14 |
| 6 | Raycast Target Detection & Occlusion | 2.0m interaction raycast, single target, wall occlusion check | INT-001 | UI_UX §4, CONTENT §14 |
| 7 | Context & Input Mode Manager | World, Book, Storage, Kitchen, Dialogue, Pause mode switching & mouse capture | INT-001 | PROTOTYPE §5, UI_UX §3 |
| 8 | Item Dictionary & Definitions | 7 P0 items data dictionary, 20 max stack | INV-001 | CONTENT §2 |
| 9 | Backpack (Tas) Management | 12 slots, stack max 20, atomic add/remove | INV-001 | CONTENT §3, UI_UX UI04 |
| 10 | House Storage (Peti Rumah) | 12 slots persistent storage, atomic add/remove | INV-001 | CONTENT §3, §5 |
| 11 | Two-Way Item Transfer | Atomic transfer between backpack and chest, full container rejection | INV-001 | CONTENT §3, PROTOTYPE §6.1 |
| 12 | Starter Container Pickup | container_starter: 4 seeds, 1 compost, 1 fertilizer atomic pickup | INV-001 | CONTENT §5, TEST_PLAN T04 |
| 13 | Recipe Book UI & Detail View | Family recipe book UI, 3 ingredients, source hints | BOOK-001 | PRD FR03, UI_UX UI02 |
| 14 | Recipe Tracking & HUD Quest Tracker | Track/untrack recipe, HUD display (tas + peti counts) | BOOK-001 | PRD FR04, UI_UX UI01 |
| 15 | Unified Free Stock Calculation | Aggregates unreserved backpack + chest items | BOOK-001 | CONTENT §3, PROTOTYPE §4 |
| 16 | Notes Registry in Book | Environmental note collection (note_garden_01) in book | BOOK-001 | CONTENT §10, UI_UX UI02 |
| 17 | Plot & Spot State Architecture | 1 plot (2x2m), 4 spots, hoed, compost, moisture, nutrients | GARD-001 | CONTENT §7 |
| 18 | Soil Hoeing (Gemburkan Tanah) | 2s hold LMB with tool_hoe to set gembur = true | GARD-001 | CONTENT §6, §7 |
| 19 | Soil Amendment (Tambah Pembenah) | E prompt with soil_compost to set pembenah = true | GARD-001 | CONTENT §6, §7 |
| 20 | Seed Planting per Spot | Plant seed_bayam on spot, consume seed, start seed stage | GARD-001 | CONTENT §6, §8 |
| 21 | Area Fertilizing (Pupuk Petak) | 1s hold LMB tool_fertilizer when nutrients < 20, sets nutrients=100 | GARD-001 | CONTENT §6, §7 |
| 22 | Area Watering (Siram Petak) | 2s hold LMB tool_watering_can when moisture < 60, sets moisture=80 | GARD-001 | CONTENT §6, §7 |
| 23 | Moisture Evaporation Simulation | 0.1 moisture loss per active simulation second | GARD-001 | CONTENT §7, PROTOTYPE §5 |
| 24 | 4-Stage Crop Growth & Stalling | 180s effective time (Seed 30s, Sprout 60s, Growing 90s, Harvestable); freeze if moisture<30 or nutrients<20 | GARD-002 | CONTENT §7, §8 |
| 25 | Crop Harvesting & Replanting | E prompt: yield 1 spinach + 1 seed, -5 nutrients; reject if backpack lacks 2 slots | GARD-002 | CONTENT §8, TEST_PLAN T05 |
| 26 | Corn Foraging Node | resource_jagung_01 yields 1 ingredient_jagung once per day | WORLD-001 | CONTENT §9 |
| 27 | Temu Kunci Foraging Node | resource_temu_kunci_01 yields 1 ingredient_temu_kunci once per day | WORLD-001 | CONTENT §9 |
| 28 | Well / Water Refill Station | water_home 2s hold refills watering can to 10/10 | WORLD-001 | CONTENT §5, §9 |
| 29 | Day Calendar & Sleep Recovery | 720s/day, sleep at bed_home advances day, restores foraged nodes | WORLD-001 | CONTENT §9, PROTOTYPE §5 |
| 30 | Emergency Contextual Reserves | reserve_home provides seeds/fertilizer when stuck | WORLD-001 | CONTENT §9, TEST_PLAN T09 |
| 31 | Ingredient Validation & Reservation | Dapur validates 3 spinach, 1 corn, 1 temu kunci and reserves them | COOK-001 | CONTENT §4, PROTOTYPE §6.2 |
| 32 | Preparation Hold & State Transition | 4s hold "Siapkan" to reach ready_to_heat | COOK-001 | CONTENT §4, PROTOTYPE §6.2 |
| 33 | Pre-Cooking Cancellation & Refund | Cancel restores reserved items to origin or kitchen_refund_storage | COOK-001 | CONTENT §3, PROTOTYPE §6.2 |
| 34 | Heat Stage Control & Cooking Progress | 30s cook time; Low (0.5x), Med (1.0x), High (0x stall warning) | COOK-002 | CONTENT §4, TEST_PLAN T41 |
| 35 | Cooking Pause & Window Closure | Esc or closing panel pauses cook job; resume intact | COOK-002 | PROTOTYPE §5, §6.2 |
| 36 | Dish Output & Recipe Completion | Yield 1 dish_sayur_bening in output slot, mark recipe complete | COOK-002 | CONTENT §4, PROTOTYPE §6.3 |
| 37 | Dish Consumption (Makan Hidangan) | Eat dish from backpack, sets meal_used = true | COOK-002 | CONTENT §10, TEST_PLAN T43 |
| 38 | Neighbor Dialogue System | Neighbor NPC dialogue, recipe hints | SOC-001 | CONTENT §10, UI_UX UI07 |
| 39 | Share Meal Option & P0 Ending | Share 1 dish with neighbor, sets meal_used = true, triggers P0 completion | SOC-001 | CONTENT §10, TEST_PLAN T44 |
| 40 | Unified Game State Serialization | Serialize player, inv, plot/crop, world nodes, cooking, recipe, flags | SAVE-001 | CONTENT §12, PROTOTYPE §7 |
| 41 | Checkpoint Management (Manual & Auto) | Separate manual and autosave slots with .bak backups | SAVE-001 | PROTOTYPE §7, TEST_PLAN T48 |
| 42 | Error Recovery & Schema Validation | Envelope v1, backup fallback, atomic temp write, safe spawn redirect | SAVE-001 | PROTOTYPE §7, TEST_PLAN T17 |
| 43 | Pause Menu & Game State Control | Esc menu: Resume, Save, Load, Settings, Return Home, Main Menu, Exit | UI-001 | UI_UX UI06 |
| 44 | Settings Manager | Mouse sens, FOV, UI scale, Audio master/music/SFX, Subtitle, Head bob | UI-001 | CONTENT §14, UI_UX UI06 |
| 45 | Honest Notification & Error System | Clear 2.5s feedback messages for full bag, missing items, unhoed soil | UI-001 | CONTENT §11, UI_UX §6 |
| 46 | Low-Poly Stylized Indonesian Aesthetic | Warm afternoon palette, terracotta tiles, bamboo fence, distinctive foliage | ART-001 | ART_DIRECTION §1..§7 |
| 47 | Core Audio Ambiance & SFX | Countryside ambiance, footsteps, hoe/water/fertilizer, kitchen, UI | ART-001 | ART_DIRECTION §8 |
| 48 | End-to-End P0 Acceptance Playthrough | Full playthrough from setup to cooking & sharing; verify T01-T60 | QA-001 | TEST_PLAN, TASKS |
| 49 | Standalone Desktop Build & Offline Run | Godot standalone Windows export, offline run, appdata save path | DIST-001 | PRD FR22, TEST_PLAN T20 |
| 50 | Installer Packaging & Licensing Notices | Portable installer, uninstaller, engine & asset license attribution | DIST-002 | TASKS, TEST_PLAN T59 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 0 | REBUILD-001 | Rebuild, audit & refine SETUP-001, LVL-001, PLY-001 with new skills (godot-3d-essentials, level-design, camera-systems, input-systems, godot-physics, physics-tuning, game-feel) | none | DONE |
| 1 | SETUP-001 | Godot engine CLI verification, project.godot, renderer gl_compatibility, directory structure, main scene, headless test runner, baseline T23/T24, README update, completed_tasks/002 | none | DONE |
| 2 | LVL-001 | Graybox 3D level, house, yard, plot area, collision boundaries, safe recovery points (safe_return_home, spawn_home) | SETUP-001 | DONE |
| 3 | PLY-001 | First-person player controller (WASD 3m/s, mouse look, vertical clamp -85° to +85°, camera 1.6m, collision capsule), framerate independence | LVL-001 | DONE |
| 4 | INT-001 | Raycast interaction detector (2.0m max, line-of-sight occlusion check), Context & Input Controller (World, Book, Storage, Kitchen, Dialogue, Pause) | PLY-001, REBUILD-001 | DONE |
| 5 | INV-001 | Item definitions, Backpack (12 slots), House storage chest (12 slots), atomic two-way transfer, starter container pickup | INT-001 | DONE |
| 6 | BOOK-001 | Recipe book UI, Sayur Bening Bayam dan Jagung recipe, pin/unpin tracking HUD, unified free stock calculation, notes registry | INV-001 | DONE |
| 7 | GARD-001 | Gardening plot architecture (2x2m, 4 spots), hoeing (2s hold), compost amendment, seed planting, fertilizing (1s hold), watering (2s hold), moisture evaporation | INV-001, BOOK-001 | DONE |
| 8 | GARD-002 | 4-stage spinach growth (180s effective), growth stalling under dry/depleted soil, harvesting (yield spinach + seed, -5 nutrients, atomic 2-slot check) | GARD-001 | IN_PROGRESS |
| 9 | WORLD-001 | Wild foraging nodes (corn & temu kunci 1/day), well water refill (10/10), 720s day cycle & bed sleep recovery, emergency reserves | GARD-002 | PLANNED |
| 10 | COOK-001 | Kitchen station UI, ingredient reservation across backpack/chest, 4s hold preparation, pre-cooking cancellation & safe refund storage | WORLD-001, BOOK-001 | PLANNED |
| 11 | COOK-002 | Heat stage control (Low, Med, High stall), 30s cook time, window close pause, dish output creation (1 dish_sayur_bening), dish consumption | COOK-001 | PLANNED |
| 12 | SOC-001 | Neighbor NPC dialogue, recipe guidance, meal sharing confirmation, P0 ending completion trigger | COOK-002 | PLANNED |
| 13 | SAVE-001 | Unified save system envelope v1 (manual, autosave, .bak), atomic temp file write, schema validation, safe recovery redirect, separate settings.cfg | SOC-001 | PLANNED |
| 14 | UI-001 | Integrated pause menu, settings UI (FOV, sensitivity, audio, subtitles), honest feedback notifications, error handling | SAVE-001 | PLANNED |
| 15 | ART-001 | Stylized Indonesian Firewatch-inspired visuals, low-poly assets, lighting, sound effects & ambience audio | UI-001 | PLANNED |
| 16 | QA-001 | Full P0 acceptance playthrough, T01-T60 test verification, zero softlock/duplication guarantee, final report | ART-001 | PLANNED |

## Interface Contracts
### InventoryManager ↔ KitchenManager
- `reserve_ingredients(recipe_id: String) -> Dictionary` (status: OK/ERR, reserved_items: Array, origin_map: Dictionary)
- `cancel_reservation(job_id: String) -> bool` (returns items to origin containers; if full, dumps to `kitchen_refund_storage`)
- `commit_consumption(job_id: String) -> void` (permanently consumes reserved items)

### InventoryManager ↔ RecipeManager
- `get_available_item_count(item_id: String) -> int` (aggregates backpack + house chest, excluding cooking reservations)

### GardenManager ↔ InventoryManager
- `can_harvest(spot_id: String) -> bool` (checks if backpack has room for 2 distinct items: spinach + seed)
- `harvest_crop(spot_id: String) -> Dictionary` (yields items directly into backpack, deducts plot nutrients)

### SaveManager ↔ All Autoload Managers
- `get_save_snapshot() -> Dictionary` (returns state dictionary matching envelope v1 schema)
- `load_save_snapshot(data: Dictionary) -> bool` (restores state, returns true on success, fallback on failure)

## Code Layout
```
res://
├── project.godot
├── scenes/
│   ├── main.tscn
│   ├── world/
│   │   ├── level_graybox.tscn
│   │   ├── plot.tscn
│   │   └── foraging_node.tscn
│   ├── player/
│   │   └── player.tscn
│   └── ui/
│       ├── hud.tscn
│       ├── book_ui.tscn
│       ├── inventory_ui.tscn
│       ├── kitchen_ui.tscn
│       ├── dialogue_ui.tscn
│       └── pause_menu.tscn
├── scripts/
│   ├── core/
│   │   ├── game_manager.gd
│   │   └── input_manager.gd
│   ├── player/
│   │   └── player_controller.gd
│   ├── interaction/
│   │   └── interaction_detector.gd
│   ├── inventory/
│   │   └── inventory_manager.gd
│   ├── recipe/
│   │   └── recipe_manager.gd
│   ├── gardening/
│   │   └── garden_manager.gd
│   ├── world/
│   │   └── world_resource_manager.gd
│   ├── cooking/
│   │   └── kitchen_manager.gd
│   ├── social/
│   │   └── dialogue_manager.gd
│   └── save/
│       └── save_manager.gd
├── data/
│   ├── items.json (or items_data.gd)
│   └── recipes.json (or recipes_data.gd)
└── tests/
    ├── test_runner.gd
    ├── assertions.gd
    └── suites/
        ├── test_setup.gd
        ├── test_level.gd
        ├── test_inventory.gd
        ├── test_gardening.gd
        ├── test_cooking.gd
        ├── test_save.gd
        └── test_acceptance_p0.gd
```
