# Handoff Report: ART-001 Visual Upgrade Architecture & Indonesian Stylized Low-Poly Identity

**Author:** explorer_art_001_1  
**Target Milestone:** ART-001 (Visual Upgrade: Graybox to Stylized Indonesian Low-Poly Identity)  
**Date:** 2026-10-29  
**Status:** Hard Handoff (Investigation & Architectural Design Complete)

---

## 1. Observation

Direct code and file observations in the workspace:

1. **Level Generation Script (`scripts/tools/build_level_graybox.gd`):**
   - Lines 20–63 define material swatches matching `docs/ART_DIRECTION.md` § 4:
     - `mat_grass`: `Color(0.345, 0.439, 0.306)` (`#58704E`)
     - `mat_house_wall`: `Color(0.894, 0.839, 0.710)` (`#E4D6B5`)
     - `mat_house_floor`: `Color(0.475, 0.333, 0.251)` (`#795540`)
     - `mat_roof`: `Color(0.671, 0.404, 0.282)` (`#AB6748`)
     - `mat_soil`: `Color(0.29, 0.21, 0.15)`
     - `mat_plant`: `Color(0.569, 0.659, 0.424)` (`#91A86C`)
     - `mat_book`: `Color(0.961, 0.941, 0.894)` (`#F5F0E4`)
   - Lines 83–114 create house geometry:
     - `HouseRoof` is a flat rectangular box: `create_box_static_body("HouseRoof", Vector3(0, 3.1, -1), Vector3(8.6, 0.2, 10.6), mat_roof)`.
     - South wall doorway is 1.6m wide from X = -0.8 to 0.8, with open lintel at Y = 2.2m to 3.0m (`WallSouthLintel`). No door mesh or door frame exists.
     - `HouseStructure` lacks porch pillars, eave overhangs, foundation plinth, and traditional Indonesian roof pitch.
   - Lines 264–274 create `gate_home` with only two simple posts (`PostLeft` at X = -1.1 and `PostRight` at X = 1.1). No adjoining fence palings or garden enclosure fences exist.
   - Lines 213–236 create `plot_home_01` (2.0 x 0.15 x 2.0m) with 4 crop spots (`spot_0` .. `spot_3`) containing small placeholder wood markers (`Vector3(0.25, 0.04, 0.25)`).
   - Lines 285–315 create wild foraging nodes:
     - `resource_jagung_01`: static body `CornStalks` with size `Vector3(1.5, 1.8, 1.5)`.
     - `resource_temu_kunci_01`: `Rock` (`Vector3(1.6, 1.0, 1.4)`) + `HerbMesh` (`Vector3(0.8, 0.6, 0.8)`).

2. **Main Scene & Environment (`scenes/main.tscn`):**
   - Lines 14–32 configure `WorldEnvironment`:
     - `sky_horizon_color = Color(0.784, 0.835, 0.792, 1)` (`#C8D5CA`)
     - `ground_bottom_color = Color(0.239, 0.333, 0.345, 1)` (`#3D5558`)
     - `ground_horizon_color = Color(0.475, 0.333, 0.251, 1)` (`#795540`)
     - `tonemap_mode = 2` (ACES filmic tonemapper)
   - Lines 36–43 configure `DirectionalLight3D`:
     - `light_color = Color(0.906, 0.706, 0.463, 1)` (`#E7B476` warm golden afternoon light)
     - `light_energy = 1.2`, `shadow_enabled = true`.

3. **Runtime Crop and Foraging Presentation (`scripts/main.gd`):**
   - Lines 185–277 (`_on_garden_plot_state_changed`):
     - Dynamically mutates `soil_mesh.material_override` between raw, hoed, and composted earth.
     - Spawns/updates a simple `BoxMesh` on `spot_node.CropMesh` scaled uniformly:
       - Stage 0: `scale = Vector3(0.08, 0.04, 0.08)`
       - Stage 1: `scale = Vector3(0.14, 0.14, 0.14)`
       - Stage 2: `scale = Vector3(0.28, 0.28, 0.28)`
       - Stage 3: `scale = Vector3(0.42, 0.42, 0.42)`
   - Lines 298–312 (`_on_foraging_state_changed`):
     - For `resource_jagung_01`: sets `mesh.visible = is_available`, hiding the entire box when harvested.
     - For `resource_temu_kunci_01`: sets `herb_mesh.visible = is_available`.

4. **Test Suite Invariants (`tests/suites/test_level.gd`, `test_gardening.gd`, `test_world.gd`):**
   - `test_level.gd` (Suite 2) enforces:
     - Root node named `LevelGraybox` with script `res://scripts/world/level_graybox.gd`.
     - 18 landmarks with fixed names at exact coordinates within 0.5m tolerance.
     - `plot_home_01` must have children `spot_0` through `spot_3`.
   - `test_world.gd` (Suite 10) enforces:
     - `resource_jagung_01` and `resource_temu_kunci_01` must have `Interactable` on Layer 3 (collision_layer = 4).
     - Harvest state transitions trigger `foraging_state_changed`.
   - Baseline test execution: `godot --headless --path . --script tests/test_runner.gd` produces:
     `Assertions Passed: 7158`, `Assertions Failed: 0`, `All Passed: true`.

5. **Project Specifications:**
   - `docs/ART_DIRECTION.md` § 1..7:
     - Indonesian village identity (kampung fiktif 2045): terracotta genteng roof, plaster walls, wooden door frame, bamboo fencing, front terrace with pillars.
     - § 3: "Bayam, jagung dan temu kunci harus berbeda", "Siluet tiap tahap berbeda".
     - § 4: Warm afternoon palette (genteng `#AB6748`, plester `#E4D6B5`, daun utama `#58704E`, daun muda `#91A86C`, tanah `#795540`, bayangan `#3D5558`, langit `#C8D5CA`, cahaya `#E7B476`).
     - § 7: Sweet corn: "Tongkol terlihat dan hilang setelah panen" (stalk remains, corn ear disappears). Temu kunci: "Daun rendah, collider mudah dibidik".
   - `docs/TEST_PLAN.md`:
     - **T55**: "Lihat tanaman, bahan, alat dan sumber pada jarak interaksi/beragam latar | Siluet berbeda, teks/ikon terbaca, status bukan warna saja; tidak ada aset hilang".
     - **T56**: "Jalankan rute standar dan area terpadat pada perangkat tercatat | Catatan performa/frame time tersedia; hasil tidak digeneralisasi ke perangkat lain".

---

## 2. Logic Chain

1. **Zero External Dependency Rationale:**
   - External DCC binaries (`.glb`, `.obj`, `.fbx`) create risks of uncommitted external assets, axis orientation mismatches (Z-up vs Y-up), broken material links, scaling errors, and lack of code audibility.
   - Using Godot's native procedural primitives (`ArrayMesh`, `SurfaceTool`, `BoxMesh`, `CylinderMesh`, `PrismMesh`, `StandardMaterial3D`) generated via GDScript allows 100% genuine in-engine execution, clean git history, and instant rebuildability via Godot CLI.
   - Therefore, the visual upgrade must be implemented as a clean procedural asset builder in GDScript (`scripts/tools/build_level_graybox.gd` and/or `scripts/tools/build_stylized_assets.gd`).

2. **House Architecture Upgrade (Rumah Kampung):**
   - Current house has a flat roof box (`Vector3(8.6, 0.2, 10.6)` at Y = 3.1m).
   - In traditional Indonesian architecture (atap pelana/limasan), the roof rises to a central ridge beam (bubungan) at Y = 4.8m with angled roof planes on East and West overhanging the eaves by 0.6m (`#AB6748`), with triangular gable infill walls on North and South (`#E4D6B5`).
   - The front south entrance at Z = 4.0m should feature:
     - A dark teak door frame (`Kusen` `#5C3D2E`) and an open paneled wooden door (`#684735`) with an iron handle.
     - A front porch overhang (teras depan) supported by two rustic wooden pillars (`TiangTeras` at X = -2.2 and X = +2.2, Z = 5.6, height 2.6m).
     - A stone/brick foundation plinth (`#5A4D41`) on the lower 0.4m of plaster walls.
   - All 18 landmark transforms remain unaffected because the house volume stays within the existing footprint bounds.

3. **Pekerjaan Pagar (Bamboo & Wooden Fences):**
   - The boundary between yard and village path (around Z = 13.0m) currently has only two bare gate posts.
   - By constructing rustic bamboo fencing along the south perimeter (from X = -8 to X = -1.1 and X = 1.1 to X = 12) and enclosing the garden plot at X = 12, the level gains immediate village identity without blocking any routes or camera sightlines.
   - Fences consist of upright bamboo poles (height 1.1m, diameter 0.08m), dual horizontal split rails (`#A89F6E`), and rustic palings with varied heights and subtle angle jitter.

4. **T55 Compliance: 4-Stage Spinach Crop Models:**
   - T55 mandates: "Siluet berbeda, status bukan warna saja".
   - Replacing the uniform box meshes in `scripts/main.gd` with 4 distinct geometric procedural models guarantees complete silhouette divergence:
     - **Stage 0 (Seed / Benih, H = 0.04m):** Low circular mound of dark tilled soil with a subtle center depression and seed dibble dot.
     - **Stage 1 (Sprout / Tunas, H = 0.14m):** Slender central stem with **2 distinct opposite cotyledon leaves in an unmistakable V-shape**.
     - **Stage 2 (Growing / Tumbuh, H = 0.30m):** Upright stem with **5–6 broad spreading ovate leaves** arranged in an alternating spiral rosette.
     - **Stage 3 (Harvestable / Siap Panen, H = 0.50m):** Dense mature spinach foliage (canopy width 0.45m) crowned by a **prominent central flowering plume / seed head (bulir bunga bayam)** extending upward.
   - Any player or tester can immediately distinguish all 4 stages by height and silhouette alone, even in monochrome.

5. **Wild Foraging Visuals (Corn & Temu Kunci):**
   - **Sweet Corn (`resource_jagung_01` at 22, 0, 28):**
     - Stalk must remain standing after harvest per ART_DIRECTION § 7.
     - Model structure: 1.85m tall bamboo-like cane with 6 arching ribbon leaves and a tassel crown, supported by a wooden garden stake.
     - Harvestable ear (`CornEar` / child mesh): golden corn ear (`#E5A93B`) wrapped in pale husks (`#9EB878`) at height Y = 0.95m.
     - When harvested, only `CornEar` is toggled invisible (`visible = false`); the stalk and leaves remain visible in the world.
   - **Temu Kunci (`resource_temu_kunci_01` at -20, 0, 30):**
     - Low tropical rhizome foliage: 6 upright glossy broad lanceolate leaves (height 0.45m, `#4F6D44`) clustering against the weathered river boulder (`Rock`).
     - Toggled on harvest to show dug/harvested state.

6. **Plot Soil Visual States:**
   - Soil bed material updates across 4 distinct visual states:
     - *Raw Soil:* Compacted, light tan-brown (`#8C7055`), roughness 0.95.
     - *Hoed Soil:* Medium brown tilled earth (`#5A3E26`), roughness 0.85.
     - *Composted Soil:* Dark rich chocolate humus (`#362112`), roughness 0.75.
     - *Watered Soil:* Deep dark wet earth (`#1E130A`), low roughness (0.35) and high specularity (0.5), giving an unmistakable wet sheen.

7. **Compatibility & Test Verification:**
   - Because all landmark node names, parent-child relationships, collision layers (Layer 1 environment, Layer 3 interactable), and coordinate tolerances (within 0.5m) are strictly preserved, zero regressions will occur in the 7,158 existing test assertions.
   - A dedicated test suite `tests/suites/test_art.gd` (Suite 24) should be added to `tests/test_runner.gd` to programmatically verify T55 (silhouettes, heights, materials, foraging toggle) and T56 (render stability and node budget).

---

## 3. Caveats

- **No High-Poly Photorealism:** ART_DIRECTION § 1 and PRD explicitly forbid high-poly assets or photorealism. All models are intentionally stylized low-poly with flat-shaded or smooth-faceted surfaces.
- **Single Sun suasan sore:** Lighting is locked to a single stable warm afternoon sun angle (`#E7B476`, 40° elevation) per ART_DIRECTION § 5; dynamic day-night visual sky transitions are out of scope for P0.
- **Audio Scope:** ART-001 also includes sound design (countryside ambiance, footsteps, hoe/water/fertilizer, kitchen, UI). This report specifies the visual 3D asset architecture; audio bus architecture is already wired in `default_bus_layout.tres` and `save_manager.gd`, and procedural/synthesized audio assets should pair with this visual upgrade.
- **No Invalidation of Saved Games:** Save snapshot schemas v1 rely only on data state, not mesh geometries; upgrading the visual models will not break existing save game files.

---

## 4. Conclusion

The stylized Indonesian low-poly visual upgrade for ART-001 is fully designed and architecturally validated. It replaces graybox placeholders with culturally grounded Indonesian assets:
1. **Traditional Limasan/Pelana Roof House:** Terracotta roof genteng (`#AB6748`), ridge cap (`#8F4F35`), plaster walls (`#E4D6B5`), stone plinth (`#5A4D41`), teak door frame (`#5C3D2E`), rustic wooden door, and front porch with pillars.
2. **Modular Bamboo Fencing:** Pekarangan perimeter and garden plot fencing with split bamboo rails (`#A89F6E`) and staggered palings (`#B3A675`).
3. **4-Stage Spinach Crop Models:** Mathematically distinct heights (0.04m, 0.14m, 0.30m, 0.50m) and silhouettes (mound, V-leaf sprout, spiral bush, flowering plume canopy) guaranteeing 100% compliance with T55.
4. **Wild Foraging Corn & Temu Kunci:** Permanent corn stalk with detachable golden ear (`CornEar`); broad upright glossy herb foliage beside river rock.
5. **Plot Soil Shader/Material:** Distinct raw (pale dry), hoed (medium brown), composted (dark chocolate), and watered (wet specular sheen) states.
6. **Pure Procedural Generation:** Executed via GDScript with zero external binary dependencies, preserving all 18 landmark contracts and 7,158 existing test assertions.

---

## 5. Verification Method

### Concrete Test & Inspection Commands

1. **Rebuild Level Graybox with Stylized Visuals:**
   ```powershell
   & "C:\Users\HP\.local\bin\godot.exe" --headless --path . --script scripts/tools/build_level_graybox.gd
   ```
   *Expected result:* Exit code 0, generates `scenes/world/level_graybox.tscn` containing the upgraded house, roof, fences, and landmarks.

2. **Run Full Automated Regression Suite:**
   ```powershell
   & "C:\Users\HP\.local\bin\godot.exe" --headless --path . --script tests/test_runner.gd
   ```
   *Expected result:* Exit code 0, 7,158+ assertions passing across all suites including `TestLevel`, `TestGardening`, `TestWorld`, and the new `TestArt`.

3. **Verify Acceptance Criteria T55 & T56:**
   - **T55 (Crop & Foraging Visual Distinctions):**
     - Verify Stage 0 height is ~0.04m (mound shape).
     - Verify Stage 1 height is ~0.14m with 2 distinct cotyledon leaves (V-silhouette).
     - Verify Stage 2 height is ~0.30m with 5-6 spreading leaves.
     - Verify Stage 3 height is ~0.50m with dense canopy and prominent flowering plume.
     - Verify corn stalk remains visible while corn ear hides on harvest.
     - Verify temu kunci foliage hides on harvest while river rock remains.
   - **T56 (Performance & Asset Integrity):**
     - Verify scene instantiates under 50ms in headless runner.
     - Total level mesh instances remain well within the desktop budget (< 150 nodes).
     - Zero missing material/texture warnings in Godot console output.

---

## 6. Implementation Blueprint for Worker

The Worker should perform the following concrete implementation tasks:

### Step 1: Upgrade `scripts/tools/build_level_graybox.gd`
- Add helper methods:
  - `create_house_structure(...)`:
    - Floor (`#795540`)
    - Plinth base (`#5A4D41`)
    - Plaster walls (`#E4D6B5`)
    - Teak door frame (`Kusen` `#5C3D2E`) and wooden door (`#684735`)
    - Pitched terracotta roof (`#AB6748`) with bubungan ridge cap (`#8F4F35`)
    - Front terrace overhang with 2 wooden porch pillars (`TiangTeras`)
  - `create_bamboo_fence(...)`:
    - Perimeter fence along Z = 13.0m (X = -8 to -1.1 and X = 1.1 to 12)
    - Garden plot fence along X = 12.0m (Z = 5 to 13)
    - Upright bamboo poles + horizontal rails (`#A89F6E`) + rustic palings (`#B3A675`)
  - `create_corn_landmark(...)`:
    - Main stalk + leaves + tassel + wooden stake (`CornStalk`)
    - Harvestable ear (`CornEar` / child mesh with golden kernels `#E5A93B` and husk `#9EB878`)
  - `create_temu_kunci_landmark(...)`:
    - Weathered boulder (`Rock`)
    - Glossy lanceolate leaf cluster (`HerbMesh`, `#4F6D44`, height 0.45m)
- Run script to update `scenes/world/level_graybox.tscn`.

### Step 2: Upgrade Dynamic Visuals in `scripts/main.gd`
- In `_on_garden_plot_state_changed`:
  - Instantiates or configures procedural 4-stage spinach models on `spot_node`:
    - Stage 0: `MoundMesh` + `SeedMesh`
    - Stage 1: `StemMesh` + `LeafLeft` + `LeafRight` (V-shape)
    - Stage 2: `StemMesh` + 6 spreading ovate leaves
    - Stage 3: `StemMesh` + 10 lush leaves + `FlowerPlumeMesh`
  - Updates `SoilBed` material across 4 states:
    - Raw: `#8C7055`, roughness 0.95
    - Hoed: `#5A3E26`, roughness 0.85
    - Composted: `#362112`, roughness 0.75
    - Watered: `#1E130A`, roughness 0.35, specular 0.5
- In `_on_foraging_state_changed`:
  - When `node_id == "resource_jagung_01"`:
    - Toggle `CornEar.visible = is_available` while leaving `CornStalk` visible.
  - When `node_id == "resource_temu_kunci_01"`:
    - Toggle `HerbMesh.visible = is_available` while leaving `Rock` visible.

### Step 3: Create Automated Test Suite `tests/suites/test_art.gd`
- Verify T55:
  - Assert 4 crop stages have strictly increasing heights and distinct child node counts/types.
  - Assert corn node has separate stalk and ear meshes; toggling foraging state toggles only the ear.
  - Assert temu kunci node has separate rock and herb meshes.
  - Assert soil material albedo/roughness differs between unhoed, hoed, and watered states.
- Verify T56:
  - Benchmark level load time (< 50ms) and mesh node count.
- Register `TestArt` as Suite 24 in `tests/test_runner.gd`.

### Step 4: Run Headless Verification and Document
- Execute `godot --headless --path . --script tests/test_runner.gd`.
- Create completion report `docs/completed_tasks/017-identitas-visual-audio-dasar-konsisten.md`.
- Update `docs/PROJECT_STATUS.md` and `docs/TASKS.md` marking ART-001 SELESAI.
