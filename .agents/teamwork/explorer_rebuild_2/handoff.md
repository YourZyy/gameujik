# Handoff Report: LVL-001 Level Graybox Skills-Aligned Audit & Refinement Plan

**Author:** `explorer_rebuild_2` (Teamwork Explorer)  
**Date:** 2026-10-27  
**Scope:** Rebuild & Refinement Analysis for Milestone LVL-001 against installed gamedev skills (`level-design`, `godot-3d-essentials`, `godot-physics`, `physics-tuning`)  
**Target Recipient:** Orchestrator (`bc3795f9-23c4-4352-8a9c-4322971bcc61`) and downstream Worker  

---

## 1. Observation

### 1.1 Direct File Observations

#### A. Level Architecture & Scene Layout
- **`scenes/world/level_graybox.tscn` & `scripts/tools/build_level_graybox.gd`:**
  - Root node: `LevelGraybox` (`Node3D`), script `res://scripts/world/level_graybox.gd` (lines 1–2).
  - Child groups:
    - `Environment` (`Node3D`, lines 54–56):
      - `Ground`: `StaticBody3D` at `Vector3(0, -0.1, 5)`, `BoxShape3D` size `(80, 0.2, 80)` (lines 58–60).
      - `GroundPlaceholder`: child `Node3D` under `Ground` (line 64).
      - `HouseStructure`: `Node3D` containing `HouseFloor` (size 8x0.1x10), `WallNorth` (size 8.2x3x0.2), `WallWest` (0.2x3x10.2), `WallEast` (0.2x3x10.2), `WallSouthLeft` (3.2x3x0.2), `WallSouthRight` (3.2x3x0.2), `WallSouthLintel` (1.6x0.8x0.2), and `HouseRoof` (8.6x0.2x10.6) (lines 68–103).
      - `PerimeterBoundaries`: `BoundaryNorth`, `BoundarySouth`, `BoundaryWest`, `BoundaryEast` (`StaticBody3D`, height 4.0m, thickness 1.0m) (lines 105–117).
      - `Paths`: `MeshInstance3D` segments `Path_HouseToGate`, `Path_GateToJunction`, `Path_JunctionToEast`, `Path_JunctionToWest`, `Path_SouthLoop`, `Path_EastConnector`, `Path_WestConnector` (lines 120–137).
    - 18 Landmarks (direct children of `LevelGraybox`, lines 139–306):
      - `zone_home` `(0, 0, -1)`
      - `spawn_home` `(0, 0, 1)` (facing north `-Z`)
      - `book_family` `(-1, 0, -2)` (`Table` StaticBody3D + `BookMesh` at Y=0.825)
      - `station_kitchen_home` `(2, 0, -4)` (`Counter` StaticBody3D)
      - `storage_home` `(-2, 0, -4)` (`Chest` StaticBody3D)
      - `bed_home` `(-2, 0, 0)` (`BedMat` StaticBody3D)
      - `zone_yard` `(5, 0, 7)`
      - `plot_home_01` `(8, 0, 7)` (`SoilBed` StaticBody3D + 4 spots: `spot_0`, `spot_1`, `spot_2`, `spot_3`)
      - `water_home` `(4, 0, 9)` (`WaterBasin` StaticBody3D)
      - `container_starter` `(6, 0, 4)` (`StarterCrate` StaticBody3D)
      - `reserve_home` `(7, 0, 4)` (`ReserveCrate` StaticBody3D)
      - `gate_home` `(0, 0, 13)` (`PostLeft`, `PostRight` StaticBody3Ds, 2.2m clearance)
      - `junction_path` `(0, 0, 21)` (`SignPost` StaticBody3D, `SignBoard` MeshInstance3D)
      - `resource_jagung_01` `(22, 0, 28)` (`CornStalks` StaticBody3D)
      - `note_garden_01` `(19, 0, 27)` (`NotePost` StaticBody3D, `NotePaper` MeshInstance3D)
      - `resource_temu_kunci_01` `(-20, 0, 30)` (`Rock` StaticBody3D, `HerbMesh` MeshInstance3D)
      - `npc_neighbor_01` `(-14, 0, 15)` (`Bench` StaticBody3D)
      - `safe_return_home` `(0, 0, 8)` (facing north `-Z`)
    - `Recovery` (`Node3D`, lines 309–323):
      - `FallRecoveryArea`: `Area3D` at `Vector3(0, -6.0, 5)` with `FallAreaCollision` (`BoxShape3D` size `(200, 2, 200)`).

#### B. Lighting and Environment Configuration
- **`scenes/main.tscn` (lines 8–13):**
  ```tscn
  [node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
  transform = Transform3D(0.866025, -0.353553, 0.353553, 0, 0.707107, 0.707107, -0.5, -0.612372, 0.612372, 0, 10, 0)
  shadow_enabled = true

  [node name="WorldEnvironment" type="WorldEnvironment" parent="."]
  ```
  - `DirectionalLight3D` currently uses default white light (`light_color = Color(1, 1, 1)`), default energy (1.0), and arbitrary rotation angles.
  - `WorldEnvironment` is an empty node with **no `environment` resource attached**. The engine runs with the fallback gray environment.
  - In `scenes/world/level_graybox.tscn`, there is no embedded environment or sun.
  - `docs/ART_DIRECTION.md` § 4 & § 5 specifies:
    - Afternoon sky palette: `#C8D5CA` (light soft afternoon sky)
    - Warm sunlight: `#E7B476` (warm golden hour, directed to illuminate south terrace and home path)
    - Deep shadow: `#3D5558` (tinted cool shadows)
    - Terracotta genteng: `#AB6748`, Rich earth: `#795540`, Plaster/Paper: `#E4D6B5`.

#### C. Collision Layers and Physics Settings
- **`scripts/tools/build_level_graybox.gd` (lines 344–366):**
  - All `StaticBody3D` instances are created without setting `collision_layer` or `collision_mask`, thereby defaulting to `layer = 1` and `mask = 1`.
  - `FallRecoveryArea` is created without setting layers/masks, defaulting to `layer = 1` and `mask = 1`.
  - No `PhysicsMaterial` or friction/bounce override is assigned.
- **`project.godot` (lines 1–69):**
  - `3d_physics/layer_*` names are currently **not configured**.
  - `physics/common/physics_interpolation` is currently **not configured** (defaults to `false`).
- **`scripts/interaction/interactable.gd` (lines 13–16):**
  - Sets `collision_layer = 1` and `collision_mask = 1`.
- **`scripts/interaction/interaction_detector.gd` (lines 17–23):**
  - Sets `collide_with_areas = true`, `collide_with_bodies = true`, `collision_mask = 1`.

#### D. Existing Automated Test Baseline
- Command: `godot_console.exe --headless --script res://tests/test_runner.gd`
  - Output: `Assertions Passed: 325, Assertions Failed: 0, RESULT: ALL SUITES PASSED (Exit Code: 0)`.
- Command: `godot_console.exe --headless --script res://tests/adversarial_level_challenge.gd`
  - Output: `Total Assertions: 95, Passed Assertions: 95, Failed Assertions: 0, VERDICT: ALL ADVERSARIAL CHALLENGES PASSED (Exit Code: 0)`.
- Key hardcoded assertions across test suites:
  - `test_setup.gd`: checks existence of `DirectionalLight3D`, `Camera3D`, and `GroundPlaceholder`.
  - `test_level.gd`: checks root name `"LevelGraybox"`, script `LevelGraybox`, exact 18 landmark IDs with distance tolerance `<= 0.5m`, 4 crop spots (`spot_0`..`spot_3`) with distance `> 0.4m` within `abs(x)<=1.0` and `abs(z)<=1.0`, spawn facing north (`forward_dot > 0.5`), wall clearance `> 1.5m`, safe return clearance `> 2.0m`, StaticBody3Ds: `Ground`, `WallNorth`, `WallWest`, `WallEast`, `WallSouthLeft`, `WallSouthRight`, `BoundaryNorth`, `BoundarySouth`, `BoundaryWest`, `BoundaryEast`.
  - `test_adversarial_level.gd` & `adversarial_level_challenge.gd`: checks `FallRecoveryArea` Y `<= -5.0`, box size `>= 100x2x100`, safe return at `(0, 0, 8)` with zero obstacle collisions, doorway clearance along Z from 1 to 6 (specifically ignoring `Ground` and `HouseFloor`), path names (`Path_HouseToGate`, etc.), and out-of-bounds recovery for entities falling below Y=-5.0 or exceeding `[-42..42]` on X and `[-37..47]` on Z.

---

## 2. Logic Chain

### 2.1 Skill Alignment Analysis

#### A. Skill `godot-3d-essentials`
1. **Transform & Scaling Discipline:**
   - Skill rule: *"Scaling physics/lights: Non-uniform scale on a Node3D distorts child collisions and lights; prefer scaling the mesh asset or using uniform scale."*
   - Observation: In `build_level_graybox.gd`, all shapes use `BoxShape3D.size` and `BoxMesh.size`, leaving the `Transform3D` scale as identity `(1, 1, 1)`.
   - Inference: Current node transforms adhere strictly to 3D essentials.
2. **Environment & Sun Lighting:**
   - Skill rule: *"Add a WorldEnvironment with an Environment resource: background (sky/color), ambient light, tonemap, and post (glow, SSAO, fog, adjustments)... Without lights and ambient, surfaces render black."*
   - Observation: `scenes/main.tscn` contains an empty `WorldEnvironment` without an attached `Environment` resource and a generic white `DirectionalLight3D`.
   - Inference: The game currently lacks the intentional Indonesian afternoon mood described in `ART_DIRECTION.md`. Equipping `WorldEnvironment` with a procedural sky, warm sky ambient, and filmic tonemapping directly fulfills both `godot-3d-essentials` and `ART_DIRECTION.md` without introducing shader complexity or performance overhead.

#### B. Skills `godot-physics` & `physics-tuning`
1. **Collision Shape Primitives:**
   - Skill rule: Analytical box colliders eliminate tunneling and mesh boundary penetration compared to trimesh colliders.
   - Observation: All walls, boundaries, floors, and props use `BoxShape3D`. Walls are 0.2m thick (4x thicker than maximum single-step movement of 0.05m at 3m/s / 60Hz).
   - Inference: Level collision geometry is already optimal for stability.
2. **Layer/Mask Architecture:**
   - Skill rule: *"Layer = 'what I am'; mask = 'what I look for'... Name layers in Project Settings > Layer Names for clarity."*
   - Observation: All objects currently sit on default layer 1.
   - Inference:
     - In `project.godot`, registering layer names (Layer 1: `world`, Layer 2: `interactables`, Layer 3: `player`, Layer 4: `triggers`) introduces project clarity without altering underlying bitmask values.
     - Keeping static bodies and ground on Layer 1 preserves 100% compatibility with all existing test queries.
3. **Physics Interpolation & Teleportation:**
   - Skill rule: *"Visible jitter usually means no render interpolation... Enable interpolation... Teleports smear across the screen with interpolation on: call reset_physics_interpolation() after moving the node."*
   - Observation: `physics/common/physics_interpolation` is currently disabled in `project.godot`. `recover_entity()` in `level_graybox.gd` teleports entities to `(0, 0, 8)` without calling `reset_physics_interpolation()`.
   - Inference: Enabling physics interpolation in `project.godot` and calling `entity.reset_physics_interpolation()` in `recover_entity()` eliminates frame-rate jitter and camera smearing during recovery.

#### C. Skill `level-design`
1. **Player Movement Metrics & Clearances:**
   - Walking speed = 3.0 m/s; Player capsule radius = 0.4m (width = 0.8m), height = 1.8m.
   - Doorway width = 1.6m (200% of player diameter, providing comfortable unconstrained passage).
   - Gate opening = 2.2m (275% of player diameter).
   - Spawn clearance = > 3.0m in all directions.
   - Safe return clearance = > 3.0m from house wall, > 5.0m from crop plot.
2. **Pacing and Encounter Timeline:**
   - Chore Loop: House to Plot (2.8s) + Plot to Water (1.5s) + Water to Crate (1.8s) = ~6.1s.
   - Exploration Loop: House to East Jagung (7.7s) + South Connector to West Temu Kunci (13.0s) + Neighbor back to Gate (10.5s) = ~37s.
   - Pacing Agreement: In `GARD-002`, spinach crop growth cycle is 180 seconds. A full circular foraging run takes ~45–60s including foraging pauses, giving the player purposeful activity during crop growth stages.
   - Landmark Silhouettes: The elevated terracotta roof at Y=3.1m provides a continuous navigational anchor across the map, matching `level-design` guidance on landmark visibility.

---

## 3. Caveats

1. **Aesthetic Material Upgrades:** The level is a functional graybox prototype. Detailed high-poly meshes, foliage shaders, and particle systems belong to milestone `ART-001`. Material refinements during this rebuild should remain within standard PBR properties (albedo, roughness, specular) using shared materials.
2. **Dynamic Terrain Contours:** Current ground elevation is planar at Y=0 (with house floor at Y=0.05). Adding uneven hills or steps at this stage would invalidate the 0.5m coordinate tolerance and clearance queries in `test_level.gd`.
3. **Raycast Interaction Layering:** While named collision layers will be defined in `project.godot`, `StaticBody3D` nodes must remain on layer 1 so existing tests (`test_adversarial_level.gd`, `test_player.gd`) and `interaction_detector.gd` continue to function without requiring cross-system rewrites.

---

## 4. Conclusion

The existing graybox level (`scenes/world/level_graybox.tscn` and `scripts/world/level_graybox.gd`) has exceptionally strong structural fundamentals:
1. All 18 landmarks, 4 crop spots, and 7 pathway segments strictly conform to `LEVEL_DESIGN.md` and pass 420 automated assertions.
2. The primary areas requiring skills-aligned refinement are:
   - **Atmospheric Environment & Sunlight:** Replacing the blank `WorldEnvironment` and default white sun with a procedural sky, ambient lighting, filmic tonemapping, and warm golden afternoon lighting (`#E7B476`) per `godot-3d-essentials` and `ART_DIRECTION.md`.
   - **Physics Settings & Interpolation:** Registering named 3D collision layers in `project.godot`, enabling `physics_interpolation`, and adding `reset_physics_interpolation()` to `level_graybox.gd` per `godot-physics` and `physics-tuning`.
   - **Material Roughness & PBR Tuning:** Refining graybox material palettes in `build_level_graybox.gd` to match `ART_DIRECTION.md` § 4 swatches (terracotta, rich soil, timber, leafy greens).

### Step-by-Step Rebuild / Refinement Plan for Worker

```
┌────────────────────────────────────────────────────────────────────────┐
│                        REBUILD EXECUTION PIPELINE                      │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Project Configuration Update (project.godot)                       │
│    - Register 3D layer names (world, interactables, player, triggers)  │
│    - Enable physics/common/physics_interpolation = true               │
│                                                                        │
│ 2. Level Script Polish (scripts/world/level_graybox.gd)                │
│    - Add entity.reset_physics_interpolation() to recover_entity()      │
│                                                                        │
│ 3. Material & Scene Generator Refinement (build_level_graybox.gd)     │
│    - Update standard materials with ART_DIRECTION § 4 hex swatches     │
│    - Tune roughness (grass: 0.9, soil: 0.95, roof: 0.65, wood: 0.75)   │
│    - Attach PhysicsMaterial (friction=0.8, bounce=0.0) to ground/floor │
│    - Execute script to regenerate scenes/world/level_graybox.tscn      │
│                                                                        │
│ 4. Main Scene Environment Configuration (scenes/main.tscn)             │
│    - Configure DirectionalLight3D: color #E7B476, energy 1.2,          │
│      rotation (-32°, -45°, 0), shadow_bias 0.04, normal_bias 1.2      │
│    - Configure WorldEnvironment: Environment resource with             │
│      ProceduralSkyMaterial (sky #C8D5CA, ground #3D5558),              │
│      ambient_light_source = SKY, ambient_energy = 0.85,                │
│      tonemap_mode = TONE_MAPPER_FILMIC                                │
│                                                                        │
│ 5. Full Automated Verification Gate                                    │
│    - Run tests/test_runner.gd (325 assertions)                         │
│    - Run tests/adversarial_level_challenge.gd (95 assertions)          │
│    - Run smoke test (scenes/main.tscn 60 frames)                       │
└────────────────────────────────────────────────────────────────────────┘
```

#### Detailed Worker Actions:

1. **Step 1: Update `project.godot`**
   - Under `[layer_names]`:
     ```ini
     3d_physics/layer_1="world"
     3d_physics/layer_2="interactables"
     3d_physics/layer_3="player"
     3d_physics/layer_4="triggers"
     ```
   - Under `[physics]`:
     ```ini
     common/physics_interpolation=true
     ```

2. **Step 2: Polish `scripts/world/level_graybox.gd`**
   - In `recover_entity(entity: Node3D) -> void`:
     Add interpolation reset immediately after setting transform:
     ```gdscript
     if entity.has_method("reset_physics_interpolation"):
         entity.reset_physics_interpolation()
     ```

3. **Step 3: Update `scripts/tools/build_level_graybox.gd` and Regenerate Scene**
   - Update material definitions with exact hex colors and roughness from `ART_DIRECTION.md` § 4:
     - `mat_grass.albedo_color = Color(0.345, 0.439, 0.306)` (`#58704E`), `roughness = 0.9`
     - `mat_path.albedo_color = Color(0.71, 0.62, 0.49)`, `roughness = 0.9`
     - `mat_house_wall.albedo_color = Color(0.894, 0.839, 0.710)` (`#E4D6B5`), `roughness = 0.8`
     - `mat_house_floor.albedo_color = Color(0.475, 0.333, 0.251)` (`#795540`), `roughness = 0.75`
     - `mat_roof.albedo_color = Color(0.671, 0.404, 0.282)` (`#AB6748`), `roughness = 0.65`
     - `mat_soil.albedo_color = Color(0.29, 0.21, 0.15)`, `roughness = 0.95`
     - `mat_water.albedo_color = Color(0.29, 0.48, 0.62)`, `roughness = 0.25`
     - `mat_wood.albedo_color = Color(0.475, 0.333, 0.251)` (`#795540`), `roughness = 0.8`
     - `mat_stone.albedo_color = Color(0.43, 0.44, 0.45)`, `roughness = 0.85`
     - `mat_plant.albedo_color = Color(0.569, 0.659, 0.424)` (`#91A86C`), `roughness = 0.7`
     - `mat_book.albedo_color = Color(0.961, 0.941, 0.894)` (`#F5F0E4`), `roughness = 0.7`
   - In `create_box_static_body()`, optionally assign a default `PhysicsMaterial` with `friction = 0.8` and `bounce = 0.0`.
   - Execute:
     ```powershell
     powershell -Command "& 'C:\Users\HP\.local\bin\godot_console.exe' --headless --script res://scripts/tools/build_level_graybox.gd"
     ```

4. **Step 4: Update `scenes/main.tscn`**
   - Configure `DirectionalLight3D`:
     ```tscn
     [node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
     transform = Transform3D(0.707107, -0.353553, 0.612372, 0, 0.866025, 0.5, -0.707107, -0.353553, 0.612372, 0, 10, 0)
     light_color = Color(0.906, 0.706, 0.463, 1)
     light_energy = 1.2
     shadow_enabled = true
     shadow_bias = 0.04
     shadow_normal_bias = 1.2
     ```
   - Configure `WorldEnvironment` with sub-resources:
     ```tscn
     [sub_resource type="ProceduralSkyMaterial" id="ProceduralSkyMaterial_pm1"]
     sky_top_color = Color(0.38, 0.52, 0.65, 1)
     sky_horizon_color = Color(0.784, 0.835, 0.792, 1)
     ground_bottom_color = Color(0.239, 0.333, 0.345, 1)
     ground_horizon_color = Color(0.475, 0.333, 0.251, 1)

     [sub_resource type="Sky" id="Sky_env01"]
     sky_material = SubResource("ProceduralSkyMaterial_pm1")

     [sub_resource type="Environment" id="Environment_main"]
     background_mode = 2
     sky = SubResource("Sky_env01")
     ambient_light_source = 3
     ambient_light_color = Color(0.784, 0.835, 0.792, 1)
     ambient_light_sky_contribution = 0.85
     ambient_light_energy = 0.85
     tonemap_mode = 3
     tonemap_exposure = 1.0

     [node name="WorldEnvironment" type="WorldEnvironment" parent="."]
     environment = SubResource("Environment_main")
     ```

5. **Step 5: Verification Gate**
   - Run test runner:
     ```powershell
     powershell -Command "& 'C:\Users\HP\.local\bin\godot_console.exe' --headless --script res://tests/test_runner.gd"
     ```
   - Run adversarial challenge:
     ```powershell
     powershell -Command "& 'C:\Users\HP\.local\bin\godot_console.exe' --headless --script res://tests/adversarial_level_challenge.gd"
     ```
   - Run smoke run:
     ```powershell
     powershell -Command "& 'C:\Users\HP\.local\bin\godot_console.exe' --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 60"
     ```

---

## 5. Verification Method

### 5.1 Independent Verification Commands

1. **Verify Test Runner (All Suites):**
   ```powershell
   powershell -Command "& 'C:\Users\HP\.local\bin\godot_console.exe' --headless --script res://tests/test_runner.gd"
   ```
   *Expected result:* 325 passed assertions, 0 failed, exit code 0.

2. **Verify Adversarial Level Stress Harness:**
   ```powershell
   powershell -Command "& 'C:\Users\HP\.local\bin\godot_console.exe' --headless --script res://tests/adversarial_level_challenge.gd"
   ```
   *Expected result:* 95 passed assertions, 0 failed, exit code 0.

3. **Verify Main Scene Smoke Execution:**
   ```powershell
   powershell -Command "& 'C:\Users\HP\.local\bin\godot_console.exe' --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 60"
   ```
   *Expected result:* 60 frames executed smoothly, exit code 0.

4. **Files to Inspect for Invariants:**
   - `scenes/world/level_graybox.tscn` — Verify all 18 landmarks, 4 crop spots, and StaticBody3D colliders remain intact.
   - `scripts/world/level_graybox.gd` — Verify `LANDMARK_IDS`, `recover_entity()`, and `check_and_recover_entity()` signatures.
   - `scenes/main.tscn` — Verify presence of `DirectionalLight3D`, `Camera3D` (inside Player), and `GroundPlaceholder`.

### 5.2 Invalidation Conditions
- Any renaming or repositioning (> 0.5m) of the 18 landmark nodes.
- Removing or renaming `Ground`, `HouseFloor`, `WallNorth`, `WallWest`, `WallEast`, `WallSouthLeft`, `WallSouthRight`, `PerimeterBoundaries`, or `FallRecoveryArea`.
- Breaking child count or offset boundaries for the 4 crop spots on `plot_home_01`.
- Removing `GroundPlaceholder` from `Ground` or `Camera3D` from `Player`.
- Changing collision layers in a way that causes `CharacterBody3D` or `Area3D` queries in `test_adversarial_level.gd` to miss.
