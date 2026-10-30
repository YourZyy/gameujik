# Handoff Report — worker_ply_001 (Task PLY-001)

## 1. Observation

- **Engine and Platform**: Godot Engine v4.7.2.stable.official.ed1daf0bf (win64 standard release) located at `C:\Users\HP\.local\bin\godot_console.exe` and `C:\Users\HP\.local\bin\godot.exe`.
- **References Inspected**:
  - `docs/CONTENT.md` § 14 line 268: `| Kecepatan jalan | 3 meter/detik; tidak ada sprint wajib P0 |`
  - `docs/CONTENT.md` § 14 line 269: `| Tinggi kamera | 1,6 meter dari posisi kaki; diuji terhadap collision |`
  - `docs/CONTENT.md` § 14 line 274: `| Batas pandang vertikal | −85° sampai +85°; tidak membalik kamera |`
  - `PRD.md` lines 117-118: FR01 (Gerak dan pandang first person), FR02 (Satu prompt interaksi).
  - `docs/completed_tasks/003-graybox-map-rumah-spawn-recovery.md`: Preceding task establishing `scenes/world/level_graybox.tscn`, `spawn_home` at (0, 0, 1), and `safe_return_home` at (0, 0, 8).
- **Files Created and Modified**:
  - `scripts/player/player_config.gd` (Created): Holds constants matching `CONTENT.md` § 14.
  - `scripts/player/player_controller.gd` (Created): `CharacterBody3D` controller implementing WASD movement with diagonal vector normalization, mouse look (yaw on player, pitch on head clamped to [-85°, +85°]), gravity, mouse capture/release, and safe recovery integration.
  - `scripts/tools/build_player_scene.gd` (Created): Procedural scene generator.
  - `scenes/player/player.tscn` (Created): PackedScene containing root `Player` (`CharacterBody3D`), child `CollisionShape3D` (`CapsuleShape3D`, radius 0.4m, height 1.8m, centered at Y = 0.9m), and child `Head` (`Node3D`, Y = 1.6m) containing `Camera3D` (`fov = 80.0`, `current = true`).
  - `scenes/main.tscn` (Modified): Replaced standalone camera with `scenes/player/player.tscn` positioned at `spawn_home` (0.0, 0.0, 1.0) facing north (`transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1)`).
  - `tests/suites/test_player.gd` (Created): Automated unit test suite implementing T18, T25, T26.
  - `tests/suites/test_adversarial_player.gd` (Created): Adversarial test suite validating opposing inputs, 360° multi-turn yaw stability, boundary pitch clamp precision, 10M pixel mouse spikes, and terminal velocity recovery.
  - `tests/test_runner.gd` (Modified): Registered `TestPlayer` and `TestAdversarialPlayer`.
  - `docs/completed_tasks/004-kendali-first-person-player.md` (Created): Formal task completion record adhering to `TEMPLATE.md`.
  - `docs/PROJECT_STATUS.md` (Modified): Added task 004 to completed list and updated description with 270-word summary.
  - `docs/TASKS.md` (Modified): Updated task `PLY-001` status to `SELESAI` linking to `[004]`.
- **Test Executions**:
  - `C:\Users\HP\.local\bin\godot_console.exe --headless --script res://tests/test_runner.gd`:
    ```
    ==================================================
    [TEST_RUNNER] SUMMARY:
      Assertions Passed: 325
      Assertions Failed: 0
      RESULT: ALL SUITES PASSED (Exit Code: 0)
    ==================================================
    ```
  - `C:\Users\HP\.local\bin\godot.exe --headless --script res://tests/test_runner.gd`: Exit code 0.
  - `C:\Users\HP\.local\bin\godot_console.exe --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 60`: Exit code 0, 60 frames rendered without error or crash.

## 2. Logic Chain

1. From `CONTENT.md` § 14 and PRD FR01, the player character requires a walking speed of 3.0 m/s without sprint for P0, eye height of 1.6 m, capsule collision (radius 0.4m, height 1.8m), and mouse look pitch clamp strictly within [-85.0°, +85.0°].
2. Setting `CollisionShape3D` position at Y = 0.9m ensures the bottom of the 1.8m height capsule sits exactly at Y = 0.0m, making the player's feet touch the ground plane without sinking or floating.
3. Placing the `Camera3D` inside `Head` at Y = 1.6m guarantees that camera raycasts and visual perspective originate precisely at the specified eye height.
4. Normalizing the input direction in `calculate_movement_velocity()` ensures that diagonal movement speed remains exactly 3.0 m/s rather than multiplying by $\sqrt{2}$ (~4.24 m/s).
5. Calculating movement delta via `_physics_process(delta)` guarantees framerate independence, as proven by the 1-second simulation test at 30, 60, and 120 FPS which all measured exactly 3.0000 meters.
6. The pitch angle is clamped via `clampf(camera_pitch, min_rad, max_rad)` before being assigned to `head.rotation.x`, preventing any gimbal inversion or camera flip.
7. If the player's Y position drops below -5.0m, `trigger_recovery()` calls `teleport_to()` towards `safe_return_home` (0, 0, 8), resets linear velocity to `Vector3.ZERO`, and aligns player orientation.
8. By replacing the old static `Camera3D` in `scenes/main.tscn` with the Player instance, the Player's camera becomes the sole and active camera in the main scene, preserving all baseline hierarchy requirements checked in `test_setup.gd`.
9. All 5 test suites pass cleanly with 325 assertions and exit code 0, and the main scene runs 60 headless frames without warnings or crashes.

## 3. Caveats

- Interactive object raycasting, distance checking (2.0 meters), occlusion checks, and on-screen prompt displays (e.g., "[E] Baca Buku") are scheduled for the subsequent task `INT-001`.
- Head bob is disabled by default (`head_bob_enabled = false`) per P0 specification.

## 4. Conclusion

Milestone PLY-001 has been fully implemented, verified, and documented in strict compliance with AGENTS.md, PRD.md, and CONTENT.md § 14. All acceptance criteria for PLY-001 are met:
- Player scene and controller function deterministically with 3.0 m/s speed.
- Collision shape is verified (radius 0.4m, height 1.8m, feet touch ground at Y = 0).
- Eye height is verified at 1.6m.
- Pitch is strictly clamped to [-85.0°, +85.0°].
- Framerate independence verified across 30, 60, and 120 FPS.
- Safe recovery to `safe_return_home` (0, 0, 8) and velocity nullification verified.
- 100% pass on all 325 test assertions; 60-frame smoke test clean.
- Completed task report `docs/completed_tasks/004-kendali-first-person-player.md`, `docs/PROJECT_STATUS.md`, and `docs/TASKS.md` updated.

## 5. Verification Method

To independently verify the implementation:
1. Run the full headless test runner:
   `C:\Users\HP\.local\bin\godot_console.exe --headless --script res://tests/test_runner.gd`
   Expected result: 325 assertions pass, 0 failures, Exit Code 0.
2. Run the main scene smoke test:
   `C:\Users\HP\.local\bin\godot_console.exe --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 60`
   Expected result: Runs 60 frames smoothly and exits with code 0.
3. Inspect files:
   - `scenes/player/player.tscn`
   - `scripts/player/player_controller.gd`
   - `scripts/player/player_config.gd`
   - `scenes/main.tscn`
   - `docs/completed_tasks/004-kendali-first-person-player.md`
   - `docs/PROJECT_STATUS.md`
   - `docs/TASKS.md`
