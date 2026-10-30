## 2026-10-27T10:16:29Z
# DISPATCH — worker_ply_001

Task: PLY-001 Implementation & Verification (First-Person Player Controller, Look Controls, Pitch Clamp & Collision)
Status: Dispatched
Timestamp: 2026-10-27T10:16:00Z

## Identity & Paths
- Role: teamwork_worker
- Your Working Directory: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_ply_001\
- Parent Conversation ID: 7fedeffb-6bbe-4514-a8d9-0d0093089682
- Mandatory Reference: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md (YOU MUST READ THIS FIRST)
- Level Design Specification: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\docs\LEVEL_DESIGN.md
- Content & Player Speeds: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\docs\CONTENT.md (§ 14)
- PRD: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\PRD.md (FR01, FR02)
- Test Plan: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\docs\TEST_PLAN.md (T18, T25, T26)
- Rules to Follow: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\AGENTS.md
- Preceding Completed Task: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\docs\completed_tasks\003-graybox-map-rumah-spawn-recovery.md
- Template: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\docs\completed_tasks\TEMPLATE.md

## MANDATORY INTEGRITY WARNING
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Objective & Detailed Requirements
You are assigned to implement Milestone PLY-001 for 'Buku Resep 2045' in Godot 4.7.2.
Godot executable is at: `C:\Users\HP\.local\bin\godot_console.exe` and `C:\Users\HP\.local\bin\godot.exe`.

1. **Read References**: Read `ORIGINAL_REQUEST.md`, `AGENTS.md`, `docs/CONTENT.md` § 14, `PRD.md` FR01-FR02, `docs/LEVEL_DESIGN.md`, and `docs/completed_tasks/TEMPLATE.md`.

2. **Implement Player Scene (`scenes/player/player.tscn`) & Script (`scripts/player/player_controller.gd`)**:
   - Root node: `CharacterBody3D` named `Player`.
   - Collision: `CollisionShape3D` with `CapsuleShape3D` (radius: 0.4 m, height: 1.8 m, centered so feet touch ground at Y = 0).
   - Camera Pivot: `Head` or `CameraPivot` (Node3D at Y = 1.6 m eye height), containing `Camera3D` as child.
   - Script `scripts/player/player_controller.gd`:
     - Movement: WASD using input actions `move_forward`, `move_backward`, `move_left`, `move_right`.
     - Move Speed: 3.0 m/s (`CONTENT.md` § 14 DEFAULT UJI).
     - Physics: Framerate-independent movement via `delta` in `_physics_process(delta)` utilizing `move_and_slide()`.
     - Gravity: Apply default gravity from ProjectSettings when `not is_on_floor()`.
     - Mouse Look: Horizontal mouse movement rotates `Player` around Y (yaw); vertical mouse movement rotates `Head`/`Camera` around X (pitch), clamped strictly to [-85.0°, +85.0°] (degrees) / [-1.4835, 1.4835] (radians).
     - Mouse mode: Capture mouse on click/start (`Input.MOUSE_MODE_CAPTURED`), release on UI/pause request.
     - Head bob: Default disabled (`head_bob_enabled = false`). No sprint, no crouch, no jump required for P0.
     - Parameters: Cleanly expose parameters (move_speed, mouse_sensitivity, fov, vertical_pitch_clamp, head_bob_enabled) via exported variables or `scripts/player/player_config.gd` for easy tuning.
     - Recovery integration: Implement `teleport_to(pos: Vector3, rot_y: float = 0.0)` that updates global_position, resets `velocity = Vector3.ZERO`, and aligns facing. If player Y < -5.0, automatically trigger recovery to `safe_return_home` (0, 0, 8).

3. **Integrate into `scenes/main.tscn`**:
   - Instance `scenes/player/player.tscn` in `scenes/main.tscn`.
   - Position the player at `spawn_home` (0.0, 0.0, 1.0) facing north (rotation Y = 0.0, facing -Z).
   - Remove or deactivate old standalone camera in `main.tscn` so Player's Camera3D is the active main camera.

4. **Automated Test Suite (`tests/suites/test_player.gd`)**:
   - Create `tests/suites/test_player.gd` (using `Assertions` from `res://tests/assertions.gd`) implementing tests for T18, T25, T26:
     - Test player scene loads and instantiates as `CharacterBody3D`.
     - Test `CollisionShape3D` exists with capsule shape (radius ~0.4m, height ~1.8m).
     - Test camera exists at eye height Y = 1.6m (+/- 0.05m).
     - Test movement velocity math: moving forward produces velocity of 3.0 m/s along direction vector.
     - Test pitch clamp: simulated mouse movement exceeding +/- 90 degrees is strictly clamped to [-85°, +85°].
     - Test framerate independence: movement distance calculated with delta does not distort at 30, 60, or 120 FPS.
     - Test safe recovery / teleport: calling `teleport_to()` updates position and resets velocity to Vector3.ZERO.
   - Update `tests/test_runner.gd` to run `TestSetup`, `TestLevel`, and `TestPlayer`.

5. **Run Verification Commands**:
   - Run headless test runner:
     `C:\Users\HP\.local\bin\godot_console.exe --headless --script res://tests/test_runner.gd`
     Verify: 100% assertions pass with exit code 0.
   - Run 60-frame headless smoke test on main scene:
     `C:\Users\HP\.local\bin\godot_console.exe --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 60`
     Verify: terminates without error or crash.

6. **Documentation & Task Closing per AGENTS.md**:
   - Create `docs/completed_tasks/004-kendali-first-person-player.md` strictly following `docs/completed_tasks/TEMPLATE.md`. Fill all sections thoroughly with real verification evidence.
   - Update `docs/PROJECT_STATUS.md`:
     - Add bullet to "Pekerjaan yang Sudah Selesai":
       `- [PLY-001 — Gerak dan pandang first person, batasan vertikal dan collision](completed_tasks/004-kendali-first-person-player.md).`
     - Update "Deskripsi Status Pekerjaan Terakhir" (150-300 words) reflecting current state, verification, and next active task (`INT-001`).
   - Update `docs/TASKS.md`:
     - Mark `PLY-001` as `SELESAI` with link to `[004](completed_tasks/004-kendali-first-person-player.md)`.
   - Write `handoff.md` in `C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_ply_001\handoff.md`.
   - Send completion message to parent via `send_message`.
