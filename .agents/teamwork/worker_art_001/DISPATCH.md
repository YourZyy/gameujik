## 2026-10-29T17:21:26Z
You are worker_art_001, assigned to implement Milestone ART-001 (Identitas Visual & Audio Dasar yang Konsisten) for the project Buku Resep 2045.

Your working directory is:
c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_art_001\

MANDATORY FIRST ACTIONS:
1. Read `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md` before starting work.
2. Read the comprehensive investigation reports prepared by the 3 Explorers:
   - Visual Styling: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_art_001_1\handoff.md`
   - Audio Architecture: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_art_001_2\handoff.md`
   - Verification & Suite 24 Design: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_art_001_3\handoff.md`
3. Read relevant documentation: `docs/ART_DIRECTION.md`, `docs/TEST_PLAN.md` (T55, T56), and `AGENTS.md`.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

IMPLEMENTATION OBJECTIVES:
1. Visual Upgrade (Low-Poly Indonesian Stylized Identity):
   - Upgrade `scripts/tools/build_level_graybox.gd` and re-generate / update `scenes/world/level_graybox.tscn`:
     - House: Pitched terracotta genteng roof (`#AB6748`) with overhanging eaves, plaster walls (`#E4D6B5`), dark teak door frame (`#5C3D2E`) and paneled door (`#684735`), front porch (teras) with 2 rustic wooden pillars (`#795540`), stone/brick foundation plinth (`#5A4D41`).
     - Fences: Rustic bamboo perimeter fences along south boundary and around garden plot with upright poles and split rails.
     - Crop Models in `scripts/main.gd`: 4 distinct spinach growth stages (Seed 0.04m, Sprout 0.14m, Growing 0.30m, Harvestable 0.50m) with leaf geometry, strictly monotonically increasing silhouettes and volumes satisfying T55.
     - Foraging Nodes: Corn (`resource_jagung_01`) stalk persists and only detachable `CornEar` disappears on harvest; Temu kunci (`resource_temu_kunci_01`) distinct broad foliage cluster beside rock.
     - Soil Bed: Modulated roughness and albedo reflecting untilled (dry matte 0.95), tilled (0.85), composted dry (0.80), and composted moist (0.40 with specular highlight).
     - PRESERVE all 18 landmark names and coordinates exactly within 0.5m tolerance so existing Suite 2 (`test_level.gd`) and all other suites continue passing!

2. Audio Architecture:
   - Update `default_bus_layout.tres`: Master, Music, SFX buses. Add `AudioEffectLimiter` (ceiling: -0.5 dB) on Master bus.
   - Implement `scripts/audio/audio_synthesizer.gd`: procedural 16-bit 22.05kHz PCM generation for countryside ambiance loop, footsteps, tool sounds (hoe, water, fertilize), harvest, kitchen sizzle, cook done chime, heat stall warning, and UI clicks. Zero external untracked download dependencies. Also support drop-in CC0 audio files from `res://assets/audio/`.
   - Implement `scripts/audio/audio_manager.gd` Autoload singleton: bus routing, SFX pool, randomizer pitch jitter, auto-wiring to `GardenManager`, `KitchenManager`, `WorldResourceManager`, and `PlayerController` footstep distance accumulator (1.8m).
   - Register `AudioManager` in `project.godot`.

3. Verification:
   - Implement Suite 24 (`tests/suites/test_art.gd`) testing T55 (silhouettes, soil cues, WCAG text contrast, zero magenta fallback shaders, asset integrity) and T56 (7-checkpoint exploration route traversal, frame time budget <= 8.0ms, node budget < 300).
   - Register Suite 24 in `tests/test_runner.gd`.
   - Run the headless test runner:
     `& "C:\Users\HP\.local\bin\godot_console.exe" --headless --script tests/test_runner.gd`
     Ensure all 24 suites pass 100% with exit code 0!

4. Project Status & Documentation (AGENTS.md Compliance):
   - Publish `docs/completed_tasks/017-identitas-visual-audio-dasar-konsisten.md` following `docs/completed_tasks/TEMPLATE.md` with complete asset licensing log (§ 10).
   - Update `docs/PROJECT_STATUS.md` (150–300 words latest status description) and `docs/TASKS.md` (mark ART-001 as SELESAI).
   - Write comprehensive `handoff.md` in your working directory.
