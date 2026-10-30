# Independent Review & Adversarial Challenge Report — Milestone PLY-001

**Reviewer Identity:** `reviewer_ply_001_1` (Roles: reviewer, critic)  
**Task Under Review:** `PLY-001` (Player Controller Architecture, Scene Hierarchy & Physics)  
**Parent Conversation ID:** `7fedeffb-6bbe-4514-a8d9-0d0093089682`  
**Timestamp:** 2026-10-27T10:33:30Z  
**Verdict:** `APPROVE`

---

## 1. Observation

### 1.1 Direct Inspection of Implementation Artifacts
- **`scripts/player/player_config.gd`**:
  - Line 6: `const DEFAULT_MOVE_SPEED: float = 3.0` (matching `CONTENT.md` § 14 line 268: `3 meter/detik`).
  - Line 7: `const DEFAULT_EYE_HEIGHT: float = 1.6` (matching `CONTENT.md` § 14 line 269: `1,6 meter dari posisi kaki`).
  - Lines 8–10: `DEFAULT_CAPSULE_RADIUS = 0.4`, `DEFAULT_CAPSULE_HEIGHT = 1.8`, `DEFAULT_COLLISION_CENTER_Y = 0.9` (matching dispatch requirement and door width allowance in `LEVEL_DESIGN.md` § 3 line 47).
  - Line 12: `const DEFAULT_FOV: float = 80.0` (matching `CONTENT.md` § 14 line 272).
  - Lines 21–24: `MIN_PITCH_DEG = -85.0`, `MAX_PITCH_DEG = 85.0`, `MIN_PITCH_RAD = -1.4835298641951802`, `MAX_PITCH_RAD = 1.4835298641951802` (matching `CONTENT.md` § 14 line 274).
  - Lines 26–28: `FALL_RECOVERY_Y_THRESHOLD = -5.0`, `DEFAULT_SAFE_RETURN_POSITION = Vector3(0.0, 0.0, 8.0)`, `DEFAULT_SPAWN_POSITION = Vector3(0.0, 0.0, 1.0)`.

- **`scripts/player/player_controller.gd`**:
  - Class Declaration (lines 1–2): `class_name PlayerController extends CharacterBody3D`.
  - Node Bindings (lines 32–34):
    - `head: Node3D = $Head ...`
    - `camera: Camera3D = find_child("Camera3D", true, false) as Camera3D`
    - `collision_shape: CollisionShape3D = find_child("CollisionShape3D", true, false) as CollisionShape3D`
  - Mouse Look & Vertical Clamping (lines 74–85):
    - `rotate_y(-relative_motion.x * mouse_sensitivity)`: applies horizontal yaw to player body.
    - `camera_pitch = clampf(camera_pitch - relative_motion.y * mouse_sensitivity, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))`: applies pitch strictly clamped to [-85.0°, +85.0°] to `head.rotation.x`.
  - Movement Vector Normalization & Physics (lines 105–123):
    - `local_dir := Vector3(input_dir.x, 0.0, input_dir.y).normalized()`
    - `direction = (transform.basis * local_dir).normalized()`
    - Horizontal velocities: `target_x = direction.x * move_speed`, `target_z = direction.z * move_speed`.
    - Air gravity: `target_y -= gravity * delta` when `not on_floor`.
    - `_physics_process(delta)` (lines 124–133): applies `velocity = calculate_movement_velocity(...)` and `move_and_slide()`.
  - Fall Recovery & Teleportation (lines 126–128, 134–160):
    - If `cur_y < fall_recovery_threshold` (-5.0), automatically triggers `trigger_recovery()`.
    - Resolves `target_pos` via parent/`LevelGraybox.get_safe_return_position()` or defaults to `(0, 0, 8)`.
    - `teleport_to()` sets `global_position`, zeroes `velocity = Vector3.ZERO`, aligns `rotation.y`, resets `camera_pitch = 0.0`, and resets `head.rotation.x = 0.0`.

- **`scenes/player/player.tscn`**:
  - Root node: `Player` (`CharacterBody3D`, script `res://scripts/player/player_controller.gd`).
  - Child 1: `CollisionShape3D` at `transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)`, shape `CapsuleShape3D(radius = 0.4, height = 1.8)`. Bottom edge rests at Y = 0.0.
  - Child 2: `Head` (`Node3D`) at `transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.6, 0)`.
  - Child of Head: `Camera3D` (`current = true`, `fov = 80.0`).

- **`scenes/main.tscn`**:
  - Instantiates `Player` (`res://scenes/player/player.tscn`) at `transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1)`.
  - Verified position matches `spawn_home` (0.0, 0.0, 1.0) and identity orientation faces North (-Z).

- **`docs/PROJECT_STATUS.md` & `docs/TASKS.md`**:
  - `docs/PROJECT_STATUS.md` lists task 004 under "Pekerjaan yang Sudah Selesai" with link to `completed_tasks/004-kendali-first-person-player.md` and contains a concise 270-word status summary.
  - `docs/TASKS.md` marks `PLY-001` as `SELESAI` linking to `[004]`.
  - Report `004-kendali-first-person-player.md` fully follows `TEMPLATE.md`.

### 1.2 Tool Execution Results
1. **Headless Test Suite**:
   Command: `C:\Users\HP\.local\bin\godot_console.exe --headless --script res://tests/test_runner.gd`
   Result:
   ```
   ==================================================
   [TEST_RUNNER] SUMMARY:
     Assertions Passed: 325
     Assertions Failed: 0
     RESULT: ALL SUITES PASSED (Exit Code: 0)
   ==================================================
   ```
   All 5 test suites (`TestSetup`, `TestLevel`, `TestAdversarialLevel`, `TestPlayer`, `TestAdversarialPlayer`) passed with 0 failures and exit code 0.

2. **Main Scene 60-Frame Smoke Run**:
   Command: `C:\Users\HP\.local\bin\godot_console.exe --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 60`
   Result:
   Exit code 0. Zero crashes, warnings, or errors.

### 1.3 Adversarial Integrity Inspection
- Grep search for `"test"` across `scripts/player/` returned 0 matches: no test bypasses, no conditional mocks or facades.
- Vector math in `calculate_movement_velocity` and pitch clamping in `handle_mouse_look` are genuine calculations with no dummy shortcuts.
- No third-party dependencies, network calls, or unauthorized plugins were introduced.

---

## 2. Logic Chain

1. **Hierarchy & Dimensions**:
   - Observations show `CollisionShape3D` centered at Y = 0.9m with height 1.8m and radius 0.4m.
   - The capsule geometry spans vertically from Y = 0.9 - 0.9 = 0.0m to Y = 0.9 + 0.9 = 1.8m. Thus, the player's feet rest squarely on the ground plane (Y = 0.0) without clipping or floating.
   - The `Camera3D` is nested under `Head` at Y = 1.6m, placing the first-person perspective exactly at 1.6m eye height relative to the ground.
2. **Speed & Diagonal Normalization**:
   - Observation of `calculate_movement_velocity` shows that `local_dir` is explicitly normalized prior to basis transformation (`Vector3(input_dir.x, 0.0, input_dir.y).normalized()`).
   - Diagonal inputs (e.g. forward + right) yield a planar vector of length 1.0, which scales by `move_speed` (3.0 m/s) to produce exactly 3.0 m/s, preventing the classic $\sqrt{2}$ diagonal speed exploit.
3. **Framerate Independence**:
   - In Godot 4, `CharacterBody3D.move_and_slide()` integrates velocity internally using physics process delta.
   - Independent verification across 30, 60, and 120 FPS demonstrated that 1.0 full second of simulated movement produces exactly 3.0000 meters in all configurations with a maximum discrepancy < 0.0001m.
4. **Mouse Look & Pitch Clamp**:
   - Horizontal mouse delta rotates `Player` on the global/local Y axis (yaw).
   - Vertical mouse delta adjusts `camera_pitch` and rotates only `Head` on the X axis.
   - Pitch is strictly clamped between `deg_to_rad(-85.0)` and `deg_to_rad(85.0)` (`[-1.4835, 1.4835]` rad).
   - Adversarial stress tests with extreme mouse movements ($\pm 10,000,000$ pixels) confirmed clamping remains intact, preventing camera inversion or gimbal locks.
5. **Safe Recovery & Integration**:
   - When the player falls below Y = -5.0, `trigger_recovery()` teleports the player back to `safe_return_home` (0, 0, 8) and zeroes linear velocity.
   - In `scenes/main.tscn`, `Player` is instantiated at `spawn_home` (0, 0, 1) facing North (-Z), fully fulfilling LVL-001 and PLY-001 integration criteria.

---

## 3. Caveats

1. **Capsule Radius (0.4m vs 0.3m)**:
   `CONTENT.md` § 14 drafted an initial 0.3m radius for the player capsule. Task dispatch and implementation use 0.4m radius. Because `LEVEL_DESIGN.md` § 3 specifies door widths at 1.2m, a 0.4m radius (0.8m diameter) maintains a clean 0.2m margin on each side, eliminating wall-clipping without obstructing navigation. As noted in `CONTENT.md` line 282, motion parameters are tuned upon PLY-001 implementation.
2. **Interactive Raycast & UI**:
   Raycast targeting (2.0m interaction range), occlusion culling, and HUD prompt display are explicitly scoped for `INT-001`.
3. **Micro-Optimization Note**:
   In `player_controller.gd:handle_mouse_look`, `deg_to_rad()` is called dynamically rather than using `PlayerConfig.MIN_PITCH_RAD` and `PlayerConfig.MAX_PITCH_RAD`. While negligible for performance, referencing the precomputed constants is recommended during future cleanup.

---

## 4. Conclusion

Milestone `PLY-001` is implemented thoroughly, robustly, and with complete engineering integrity. All criteria specified in `PRD.md`, `CONTENT.md` § 14, `LEVEL_DESIGN.md`, and `TASKS.md` are satisfied.

- **Integrity Check:** Passed (0 integrity violations; genuine vector math and independent tests).
- **Quality & Correctness:** Passed (hierarchy, dimensions, movement normalization, pitch clamping, safe recovery, main scene integration).
- **Adversarial Resilience:** Passed (opposing input cancellation, multi-turn 360° yaw stability, extreme mouse spike immunity, terminal velocity nullification).

**Final Verdict: `APPROVE`**

---

## 5. Verification Method

To independently reproduce and verify this review:

1. **Run Full Test Suite via CLI**:
   ```powershell
   & "C:\Users\HP\.local\bin\godot_console.exe" --headless --script res://tests/test_runner.gd
   ```
   *Expected Result:* 325 passed assertions, 0 failed assertions, Exit Code 0.

2. **Run Main Scene Smoke Run**:
   ```powershell
   & "C:\Users\HP\.local\bin\godot_console.exe" --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 60
   ```
   *Expected Result:* Clean execution for 60 frames, Exit Code 0.

3. **Inspect Key Source Files**:
   - `scenes/player/player.tscn` (CharacterBody3D, Capsule 0.4x1.8m at Y=0.9, Head at Y=1.6, Camera3D FOV 80)
   - `scripts/player/player_controller.gd` (WASD normalization, pitch clamp [-85°, +85°], safe recovery)
   - `scripts/player/player_config.gd` (Constants matching CONTENT.md § 14)
   - `scenes/main.tscn` (Player instantiated at spawn_home (0, 0, 1) facing -Z)
   - `docs/completed_tasks/004-kendali-first-person-player.md`
