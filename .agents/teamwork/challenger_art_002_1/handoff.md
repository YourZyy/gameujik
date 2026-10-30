# Handoff Report: ART-001 Empirical Adversarial Challenge

**Author:** challenger_art_002_1 (Empirical Challenger & Adversarial Verifier)  
**Working Directory:** `.agents/teamwork/challenger_art_002_1/`  
**Milestone:** ART-001 Crop Geometry & Visual/Accessibility Verification  
**Date:** 2026-10-30  
**Verdict:** **REJECT** (3 Empirical Failures Found, Blocking Gate Closure)

---

## 1. Observation

### 1.1 Baseline Test Executions
1. **Full Test Runner (`tests/test_runner.gd`):**
   - Command: `& "C:\Users\HP\.local\bin\godot_console.exe" --headless --script tests/test_runner.gd`
   - Verbatim Output:
     ```
     ==================================================
     [TEST_RUNNER] SUMMARY:
       Assertions Passed: 8409
       Assertions Failed: 0
       RESULT: ALL SUITES PASSED (Exit Code: 0)
     ==================================================
     ```
2. **Standalone Adversarial Art Oracle (`tests/adversarial_art_oracle.gd`):**
   - Command: `& "C:\Users\HP\.local\bin\godot_console.exe" --headless --script tests/adversarial_art_oracle.gd`
   - Verbatim Output:
     ```
     ==================================================
     [ADVERSARIAL_ART_ORACLE] SUMMARY:
       Total Assertions Passed: 713
       Total Assertions Failed: 0
       RESULT: ALL ADVERSARIAL ORACLES PASSED (Exit Code: 0)
     ==================================================
     ```

### 1.2 Multi-Primitive Hierarchy Inspection (`scripts/main.gd`)
- Root node `CropMesh` (`Node3D`) scale is kept uniform at `Vector3(1, 1, 1)` (lines 273, 287).
- **Stage 0 (Benih, 0.04m, 2 primitives):** `BaseMound` (`CylinderMesh`, top_radius 0.05, bottom_radius 0.07, height 0.03) + `SeedDibble` (`CylinderMesh`, top_radius 0.012, bottom_radius 0.012, height 0.015, position Y=0.0325, peak Y=0.0400m). Total primitives: 2.
- **Stage 1 (Tunas, 0.14m, 3 primitives):** `Stem` (`CylinderMesh`, height 0.10) + `CotyledonLeft` (`BoxMesh`, size `Vector3(0.05, 0.008, 0.025)`, position `Vector3(-0.025, 0.115, 0)`, rotation `Vector3(0, 0, deg_to_rad(35))`) + `CotyledonRight` (`BoxMesh`, size `Vector3(0.05, 0.008, 0.025)`, position `Vector3(0.025, 0.115, 0)`, rotation `Vector3(0, 0, deg_to_rad(-35))`). Total primitives: 3.
- **Stage 2 (Tumbuh, 0.30m, 7 primitives):** `Stem` (`CylinderMesh`, height 0.24) + `Leaf_0`..`Leaf_5` (`BoxMesh`, 2 staggered tiers at 60° intervals). Total primitives: 7.
- **Stage 3 (Siap Panen, 0.50m, 10 primitives):** `MainStalk` (`CylinderMesh`, height 0.38) + `CanopyLeaf_0`..`CanopyLeaf_7` (`BoxMesh`) + `FloweringPlume` (`CylinderMesh`, height 0.12, position Y=0.44, peak Y=0.50m). Total primitives: 10.

### 1.3 Empirical Failure Observations

#### Observation 1: Inverted Cotyledon Orientation (Droop / Inverted V)
In `scripts/main.gd` lines 360 and 371:
```gdscript
cot_l.rotation = Vector3(0, 0, deg_to_rad(35))
...
cot_r.rotation = Vector3(0, 0, deg_to_rad(-35))
```
- `CotyledonLeft` has local box center at `x = -0.025, y = 0.115`. Its left tip in local box space is at `x = -0.025, y = 0.0`.
- Applying `rotation.z = +35°` around Z rotates the left vector `(-0.025, 0)` into:
  - `tip.x = -0.025 - 0.025 * cos(35°) = -0.0455m`
  - `tip.y = 0.115 - 0.025 * sin(35°) = 0.1007m`
  - While the stem attachment base is at `base.x = -0.0045m, base.y = 0.115 + 0.025 * sin(35°) = 0.1293m`.
- **Direct Measurement:** `tip.y (0.1007m) < base.y (0.1293m)`.
- The leaf angles **downward** toward the ground by -28.6mm, creating an inverted V / drooping tent shape (`/ \`), not an upward sprout V-silhouette (`\ /`).
- Suite 24 `test_art04` lines 397-398 only tested:
  ```gdscript
  Assertions.assert_true(abs(cot_l.rotation.z - deg_to_rad(35.0)) < 0.05, "CotyledonLeft roll harus +35 deg")
  ```
  This passed tautologically because it checked the number 35.0 without checking vector orientation.

#### Observation 2: Projection & Silhouette Area Inversion (Stage 0 > Stage 1)
In `scripts/main.gd`:
- Stage 0 3D bounding envelope: `Width X = 0.140m, Height Y = 0.040m, Depth Z = 0.140m` (BaseMound diameter = 0.14m).
- Stage 1 3D bounding envelope: `Width X = 0.096m, Height Y = 0.133m, Depth Z = 0.025m` (Stem diameter = 0.016m, Cotyledon thickness Z = 0.025m).
- Executing empirical projection sweep via `tests/empirical_art_challenger.gd` across 900 side-on and oblique camera poses (pitch 0° to -55°, distance 0.8m to 3.0m, yaw 0° to 330°, FOV 60° to 90°):
  - **Side-on View (Pitch 0°, Yaw 90° - side inspection):**
    - Stage 0: 2D Height = 31.5 px, Width = 82.1 px, AABB Area = **2,589 px²**, Hull Area = **1,897 px²**.
    - Stage 1: 2D Height = 78.8 px, Width = 15.3 px, AABB Area = **1,204 px²**, Hull Area = **1,094 px²**.
    - **Stage 0 silhouette area is 1.7x to 2.1x LARGER than Stage 1!**
  - **Oblique View (Pitch -30°, Yaw 0° - player looking down at plot from 1.6m eye height):**
    - Stage 0: AABB Area = **4,052 px²**, Hull Area = **2,810 px²**.
    - Stage 1: AABB Area = **3,677 px²**, Hull Area = **2,266 px²**.
    - **Stage 0 silhouette area is 1.24x LARGER than Stage 1!**
  - **Oblique View (Pitch -45°, Yaw 0° - standing player looking at near garden bed):**
    - Stage 0: 2D Height = **59.9 px**, AABB Area = **4,403 px²**, Hull Area = **3,095 px²**.
    - Stage 1: 2D Height = **56.6 px**, AABB Area = **3,022 px²**, Hull Area = **1,926 px²**.
    - **Stage 0 appears both TALLER (59.9 px vs 56.6 px) and LARGER IN AREA (4,403 px² vs 3,022 px²) than Stage 1!**
  - Overall 900-pose pass rates on real multi-primitive geometry:
    - Height Monotonicity: **630 / 900 (70.0% pass, 30.0% fail)**.
    - 2D Bounding Area Monotonicity: **276 / 900 (30.7% pass, 69.3% fail)**.
    - Convex Hull Silhouette Monotonicity: **198 / 900 (22.0% pass, 78.0% fail)**.

#### Observation 3: Synthetic / Disconnected Oracle in Suite 25 (`test_adv01`)
In `tests/suites/test_adversarial_art.gd` lines 41-46:
```gdscript
var stage_scales: Array[Vector3] = [
    Vector3(0.08, 0.04, 0.08), # Stage 0: Seed
    Vector3(0.14, 0.14, 0.14), # Stage 1: Sprout
    Vector3(0.30, 0.30, 0.30), # Stage 2: Growing
    Vector3(0.50, 0.50, 0.50)  # Stage 3: Harvestable
]
```
- `test_adv01` tested 8 corners of hypothetical cubes whose dimensions are hardcoded in a local variable.
- In this synthetic array, Stage 1 is artificially defined as `(0.14, 0.14, 0.14)` — larger than Stage 0 `(0.08, 0.04, 0.08)` in every single dimension.
- `test_adv01` never instantiated `scripts/main.gd` or `CropMesh`, never loaded any `CylinderMesh` or `BoxMesh` primitives, and never tested the actual game geometry.
- This masked the genuine geometric inversion observed in Observation 2.

---

## 2. Logic Chain

1. **Premise 1 (PRD FR21 & TEST_PLAN T55 Contract):** Visual growth progression across the 4 stages must be distinct, progressive, and monotonic in both physical dimensions and projected screen presence, allowing players to immediately differentiate seed mound vs sprout vs growing vs harvestable crops.
2. **Premise 2 (Geometric Orientation):** A "V-silhouette" for cotyledon leaves requires the leaves to diverge upward and outward from the stem (`tip.y > base.y`).
3. **Inference from Obs 1:** Assigning `+35°` to `CotyledonLeft` and `-35°` to `CotyledonRight` in Godot 3D (+Y up, +X right) rotates the outer tips downward toward -Y (`tip.y = 0.1007m < base.y = 0.1293m`), producing a downward drooping angle rather than an upward V-shape.
4. **Inference from Obs 2:** The circular soil mound in Stage 0 (`BaseMound`) has a 140mm diameter. In contrast, Stage 1 has a stem diameter of only 16mm and cotyledon depth of only 25mm. When viewed side-on or obliquely from standing player eye height, the projected 2D silhouette area of the Stage 0 mound is up to 2.1x larger than the Stage 1 sprout, and at Pitch -45° the mound appears 3.3 px taller than the sprout. This breaks visual monotonicity between Stage 0 and Stage 1 for the player.
5. **Inference from Obs 3:** The existing 2,268-pose oracle in `TestAdversarialArt.test_adv01` passed 100% solely because it evaluated an artificial array of bounding boxes (`Vector3(0.08, 0.04, 0.08)` vs `Vector3(0.14, 0.14, 0.14)`), rather than extracting and projecting the actual multi-primitive geometry of `CropMesh`.
6. **Conclusion:** Because the sprout silhouette is inverted and non-monotonic against Stage 0 across natural player viewing angles, and because Suite 25's oracle was disconnected from the actual implementation, milestone ART-001 fails adversarial verification.

---

## 3. Caveats

- **No Caveats on Geometry or Oracle Disconnection:** The mathematical coordinates, vertex extractions, and projection calculations were executed directly via Godot 4.7.2 headless console on the exact codebase.
- **Color Contrast & Node Budgets are Fully Compliant:** Chromatic contrast across all 4 stages is $\Delta C \ge 0.20$ (spec $\ge 0.15$), WCAG text contrast is $\ge 7.29:1$ AAA, and mesh/material counts are well within the 60 FPS budget.

---

## 4. Conclusion & Required Remediations

**Verdict: REJECT.**

To close milestone ART-001, Worker must apply the following concrete remediations:

### Remediation 1: Invert Cotyledon Roll Signs (`scripts/main.gd`)
In `_build_stage_1_sprout` (`scripts/main.gd` lines 360 & 371):
- Change `cot_l.rotation = Vector3(0, 0, deg_to_rad(35))` to `cot_l.rotation = Vector3(0, 0, deg_to_rad(-35))` (tip rises to Y=0.1293m > base Y=0.1007m).
- Change `cot_r.rotation = Vector3(0, 0, deg_to_rad(-35))` to `cot_r.rotation = Vector3(0, 0, deg_to_rad(35))` (tip rises to Y=0.1293m > base Y=0.1007m).
- Update unit test assertions in `tests/suites/test_art.gd` lines 397-398 to verify upward V-silhouette tip elevation (`tip.y > base.y`) and corresponding roll signs.

### Remediation 2: Adjust Stage 0 vs Stage 1 Footprint (`scripts/main.gd`)
To restore projection monotonicity:
- In `_build_stage_0_seed` (`scripts/main.gd` lines 311-312): Reduce `BaseMound` dimensions to a subtle seed dibble mound (e.g. `top_radius = 0.025m`, `bottom_radius = 0.035m`, diameter 0.07m, `height = 0.02m`).
- In `_build_stage_1_sprout` (`scripts/main.gd` lines 356 & 368): Increase cotyledon spread/length slightly (e.g., cotyledon box size `Vector3(0.065, 0.010, 0.035)`, offset `±0.03m`) and keep a small basal soil collar if needed.
- This ensures Stage 0 footprint ($\approx 0.07\text{m} \times 0.03\text{m} \times 0.07\text{m}$) is strictly smaller than Stage 1 footprint ($\approx 0.12\text{m} \times 0.14\text{m} \times 0.04\text{m}$) from all camera angles.

### Remediation 3: Wire Suite 25 Oracle to Real Multi-Primitive Geometry (`tests/suites/test_adversarial_art.gd`)
- Replace the synthetic `stage_scales` array in `test_adv01_crop_monotonic_scaling_under_camera_sweep` with actual vertex extraction from `main._rebuild_crop_stage(root, s)` (as demonstrated in `tests/empirical_art_challenger.gd`).
- Ensure all 2,268 poses pass on the real game geometry.

---

## 5. Verification Method

1. **Execute Empirical Art Challenger Harness:**
   ```powershell
   & "C:\Users\HP\.local\bin\godot_console.exe" --headless --script tests/empirical_art_challenger.gd
   ```
   *Current Result:* Exits with code 1, reporting 5 failures (Cotyledon downward droop and non-monotonic area/height across 900 camera poses).  
   *Post-Remediation Invalidation Condition:* Must exit with code 0 and output `VERDICT: ALL ADVERSARIAL STRESS TESTS PASSED (APPROVE)`.

2. **Execute Full Test Runner:**
   ```powershell
   & "C:\Users\HP\.local\bin\godot_console.exe" --headless --script tests/test_runner.gd
   ```
   *Expected Result:* 25 suites execute headlessly with 0 failures, exit code 0.

3. **Execute Standalone Adversarial Oracle:**
   ```powershell
   & "C:\Users\HP\.local\bin\godot_console.exe" --headless --script tests/adversarial_art_oracle.gd
   ```
   *Expected Result:* Exits with code 0, 0 failures.
