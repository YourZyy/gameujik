# Handoff Report: Player Controller (PLY-001) Skills Alignment, Gaps, and Rebuild Plan

## 1. Observation

### 1.1 Existing Implementation Details
1. **Scene Hierarchy (`scenes/player/player.tscn`)**:
   - Root: `Player` (`CharacterBody3D`, script `res://scripts/player/player_controller.gd`).
   - Child 1: `CollisionShape3D` at `position = Vector3(0.0, 0.9, 0.0)` with `CapsuleShape3D` (`radius = 0.4`, `height = 1.8`).
   - Child 2: `Head` (`Node3D` at `position = Vector3(0.0, 1.6, 0.0)`).
   - Grandchild: `Camera3D` under `Head` at `position = Vector3.ZERO` (`fov = 80.0`, `current = true`).
   - Neither `collision_layer` nor `collision_mask` is set explicitly, defaulting in Godot to `layer = 1`, `mask = 1`.

2. **Controller Logic (`scripts/player/player_controller.gd`)**:
   - Lines 71–73:
     ```gdscript
     if event is InputEventMouseMotion and (is_mouse_captured() or DisplayServer.get_name() == "headless"):
         handle_mouse_look(event.relative)
     ```
     Uses `event.relative` for mouse aiming.
   - Lines 74–85 (`handle_mouse_look`):
     ```gdscript
     func handle_mouse_look(relative_motion: Vector2) -> void:
         rotate_y(-relative_motion.x * mouse_sensitivity)
         camera_pitch -= relative_motion.y * mouse_sensitivity
         var min_rad := deg_to_rad(min_pitch_deg)
         var max_rad := deg_to_rad(max_pitch_deg)
         camera_pitch = clampf(camera_pitch, min_rad, max_rad)
         if head:
             head.rotation.x = camera_pitch
     ```
   - Lines 105–122 (`calculate_movement_velocity`):
     ```gdscript
     func calculate_movement_velocity(input_dir: Vector2, current_vel: Vector3, delta: float, on_floor: bool = true) -> Vector3:
         var direction := Vector3.ZERO
         if input_dir != Vector2.ZERO:
             var local_dir := Vector3(input_dir.x, 0.0, input_dir.y).normalized()
             direction = (transform.basis * local_dir).normalized()
         var target_x := direction.x * move_speed
         var target_z := direction.z * move_speed
         var target_y := current_vel.y
         if not on_floor:
             var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
             target_y -= gravity * delta
         else:
             if target_y < 0.0:
                 target_y = 0.0
         return Vector3(target_x, target_y, target_z)
     ```
   - Lines 124–133 (`_physics_process`):
     ```gdscript
     func _physics_process(delta: float) -> void:
         var cur_y := global_position.y if is_inside_tree() else position.y
         if cur_y < fall_recovery_threshold:
             trigger_recovery()
             return
         var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
         velocity = calculate_movement_velocity(input_dir, velocity, delta, is_on_floor())
         move_and_slide()
     ```
   - Lines 134–146 (`teleport_to`):
     ```gdscript
     func teleport_to(target_position: Vector3, rot_y_rad: float = 0.0) -> void:
         if is_inside_tree():
             global_position = target_position
         else:
             position = target_position
         velocity = Vector3.ZERO
         rotation.y = rot_y_rad
         camera_pitch = 0.0
         if head:
             head.rotation.x = 0.0
         recovered_to_safe_position.emit(target_position)
     ```

3. **Engine Project Settings (`project.godot`)**:
   - `window/stretch/mode="canvas_items"` and `window/stretch/aspect="keep"`.
   - Actions mapped: `move_forward` (W, physical 87), `move_backward` (S, physical 83), `move_left` (A, physical 65), `move_right` (D, physical 68), `interact` (E, physical 69), `open_book` (B, physical 66), `open_inventory` (Tab, physical 4194306), `pause_menu` (Esc, physical 4194305).
   - No named physics 3D collision layers exist in `project.godot`.

4. **Test Baseline Execution**:
   - Tool Command: `C:\Users\HP\.local\bin\godot_console.exe --headless --script res://tests/test_runner.gd`
   - Result: Exit code 0, 325 assertions passed, 0 failed across 5 suites (`TestSetup`, `TestLevel`, `TestAdversarialLevel`, `TestPlayer`, `TestAdversarialPlayer`).

---

## 2. Logic Chain

### 2.1 Skill Alignment & Gap Analysis

#### A. Input Action Mapping & Decoupling (`input-systems`)
- **Observation**:
  - `project.godot` binds `physical_keycode` (87, 83, 65, 68), and `player_controller.gd:130` queries `Input.get_vector("move_left", "move_right", "move_forward", "move_backward")`.
  - `input-systems/SKILL.md:68` states: `"Two axes (stick or WASD): get_vector applies a circular deadzone, rescales past it and caps the length at 1, so diagonals are not faster."`
  - In `player_controller.gd:61`, mouse click capture is hardcoded to `MOUSE_BUTTON_LEFT`.
- **Reasoning**:
  - Movement axis querying is already idiomatic and decouples keys from movement physics.
  - However, in preparation for the upcoming `INT-001` (Interaction Detector & Context/Input Manager with modes World, Book, Storage, Kitchen, Dialogue, Pause), the player controller lacks a direct gate flag such as `movement_enabled: bool = true` and `look_enabled: bool = true`. Adding these properties ensures external menus or dialogs can pause player look and movement without tearing down the controller.
  - Adding gamepad analog stick look support in `_physics_process` (or input processing) via actions or joypad axis with radial deadzone aligns with multi-device input guidance.

#### B. Camera Look Smoothing vs. Responsiveness & Stretch Independence (`camera-systems`)
- **Observation**:
  - `player_controller.gd:73` calls `handle_mouse_look(event.relative)`.
  - `project.godot` specifies `window/stretch/mode="canvas_items"`.
  - `camera-systems/SKILL.md:104-106` states:
    ```gdscript
    # screen_relative is unscaled; `relative` is scaled by the stretch settings, so
    # sensitivity would change with window size. The docs recommend screen_relative
    # for captured-mouse aiming.
    _yaw -= e.screen_relative.x * sensitivity
    ```
- **Reasoning**:
  - Because `canvas_items` stretch mode is active, `event.relative` scales dynamically if the window resolution or viewport scales, causing mouse sensitivity to change when the user resizes the window or runs in different resolutions.
  - Godot 4 provides `event.screen_relative` on `InputEventMouseMotion`, which represents raw screen pixel displacement and is completely invariant under stretch settings.
  - Therefore, `_unhandled_input` should read `event.screen_relative` (with fallback to `event.relative` if zero) before passing to `handle_mouse_look(motion)`.
  - For camera smoothing: First-person games require crisp 1:1 input responsiveness to prevent nausea and allow precise targeting. However, an optional configurable exponential smoothing parameter (`1.0 - exp(-rate * dt)`) can be supported while defaulting to instant/raw 1:1 look to preserve deterministic test assertions.

#### C. Physics Feel: Slope Handling, Snapping, and Floor Stability (`godot-physics`, `physics-tuning`)
- **Observation**:
  - `player_controller.gd` calls plain `move_and_slide()` without configuring Godot 4 slope/floor snapping properties.
  - `physics-tuning/SKILL.md` notes that physics stability on uneven terrain requires proper floor snapping, constant slope speed, and wall blocking.
- **Reasoning**:
  - Godot 4 `CharacterBody3D` provides built-in properties:
    1. `floor_constant_speed = true`: Prevents the character from slowing down uphill or rocketing downhill, keeping the 3.0 m/s invariant stable across all terrain slopes up to 45°.
    2. `floor_snap_length = 0.2` (or 0.3): Eliminates jitter and prevents the player from unintentionally becoming airborne when descending ramps or walking over subtle level geometry irregularities.
    3. `floor_stop_on_slope = true`: Prevents slipping downward when standing on angled surfaces.
    4. `floor_block_on_wall = true`: Ensures clean collision stop on contact with walls.
  - Adding these properties in `_ready()` or scene setup immediately improves traversal feel on future non-flat terrain while remaining 100% compatible with flat graybox tests.
- **Velocity Invariant Preservation**:
  - In `test_player.gd:133-157` and `test_player.gd:228-237`, unit tests call `calculate_movement_velocity(input_dir, Vector3.ZERO, delta, true)` and assert that the returned velocity magnitude is **exactly 3.0 m/s on the first step**.
  - If gradual acceleration/deceleration (`lerp` or `move_toward`) were introduced unconditionally without instant response, distance in 1.0 second would drop below 3.000m and break tests T26.PLY1 and T26.PLY2.
  - Therefore, instant response (`acceleration = INF` or instant snap) must remain the default behavior. If acceleration is added, it should be an opt-in or configurable parameter with `INF` as default.

#### D. Collision Layer Architecture (`godot-physics`, `physics-tuning`)
- **Observation**:
  - Currently, `player.tscn` and `level_graybox.tscn` use default layer 1 and mask 1.
  - `godot-physics/SKILL.md:45-47` and `physics-tuning/SKILL.md:108-119` require structured layers:
    `Layer = "what I am"`, `Mask = "what I look for"`.
- **Reasoning**:
  - The project layer architecture should be formalized:
    - Layer 1: `World` (ground, buildings, static obstacles, fences)
    - Layer 2: `Player` (the player character body)
    - Layer 3: `Interactables` (foraging nodes, chest, well, kitchen, book, neighbor NPC)
    - Layer 4: `Triggers` (FallRecoveryArea, zone triggers)
  - For backward compatibility with existing level bodies and tests:
    - Player must be on Layer 2 (`collision_layer = 2`), but also have bit 1 set or keep Layer 1 (`collision_layer = (1 << 0) | (1 << 1) = 3`) during the transition phase, and `collision_mask = 1` (World) so it collides with all static geometry.
    - When `INT-001` introduces `InteractionDetector` (RayCast3D), its mask will be Layer 1 (for line-of-sight occlusion) and Layer 3 (for interactable targets).

#### E. Game Feel Polish: Procedural Head Bob & Trauma Camera Shake (`game-feel`, `camera-systems`)
- **Observation**:
  - In `PRD.md` §9.5 and `CONTENT.md` §14, head bob is required to be OFF by default:
    `"Head bob / motion blur: Mati; head bob boleh tetap tidak tersedia selama tidak ditampilkan seolah dapat diaktifkan"`.
  - However, the task specifically requires: `"Game feel polish: subtle head bob hook, camera shake hook capability"`.
  - Currently, `player_controller.gd` has `@export var head_bob_enabled: bool = false`, but no implementation exists behind it.
  - There is no trauma or shake hook on `PlayerController` or `Camera3D`.
- **Reasoning**:
  - Implementing an extensible, decoupled game-feel hook system:
    1. **Trauma-Based Camera Shake Hook (`game-feel/SKILL.md:65-86`)**:
       - Add `add_trauma(amount: float)` to `PlayerController` (clamps `trauma` between 0.0 and 1.0).
       - In `_process(delta)`, decay `trauma` at `decay_rate` (e.g. 1.5/s).
       - Calculate shake intensity: `shake = trauma * trauma` (quadratic curve: subtle low, punchy high).
       - Apply smooth harmonic displacement `_shake_offset` and roll `_shake_roll` to the camera transform:
         `camera.position = _camera_base_pos + _bob_offset + _shake_offset`
         `camera.rotation.z = _shake_roll`
       - This is completely additive and decoupled from player physics position; it does not cause aim drift or physics jitter.
    2. **Procedural Head Bob Hook**:
       - When `head_bob_enabled == true` and the player is moving on floor (`is_on_floor() and velocity.length() > 0.1`):
         Accumulate distance: `_bob_timer += velocity.length() * delta * bob_frequency`.
         Compute vertical displacement: `sin(_bob_timer * 2.0) * bob_amplitude_v`.
         Compute horizontal displacement: `cos(_bob_timer) * bob_amplitude_h`.
       - When stationary or `head_bob_enabled == false`, smoothly ease `_bob_offset` back to `Vector3.ZERO` via `lerp(..., 1.0 - exp(-10.0 * delta))`.
       - Eye height at rest remains strictly 1.6m (`effective_eye_height = 1.6m`).
    3. **Teleportation Interpolation Reset (`physics-tuning/SKILL.md:143`)**:
       - In `teleport_to(...)`, call `reset_physics_interpolation()` so that Godot's physics interpolation does not smear the player camera across the level on recovery.
    4. **Step & Landing Signals**:
       - Track `_was_on_floor`. When transitioning from in-air to floor, emit `landed(impact_velocity: float)`.
       - When `_bob_timer` crosses a step threshold, emit `step_taken()`.
       - These signals provide immediate hooks for `ART-001` audio footsteps and thud effects without tight coupling.

---

## 3. Caveats

1. **Head Bob Default Must Remain False**:
   - `PRD.md` §9.5 and `CONTENT.md` §14 explicitly dictate that `head_bob_enabled` defaults to `false`. The hook must be present and fully functional when enabled, but disabled by default.
2. **Velocity Math Invariance**:
   - `calculate_movement_velocity` must continue to return 3.0 m/s immediately on frame 1 when input is full magnitude. Any future momentum/acceleration feature must default to instant/infinite to avoid breaking `TestPlayer` and `TestAdversarialPlayer`.
3. **Collision Layer Transition**:
   - If `level_graybox.tscn` colliders remain on Layer 1, Player must include Layer 1 in its `collision_mask`. To ensure `FallRecoveryArea` detects the player, Player's `collision_layer` should either include Layer 1 or `FallRecoveryArea`'s mask must scan Layer 2.
4. **Read-Only Scope**:
   - As an explorer agent, no codebase files have been modified. All proposed code changes below are prepared for Worker execution.

---

## 4. Conclusion & Concrete Rebuild Plan

The current player controller is mathematically sound, robust against adversarial inputs, and passes all 325 test assertions. By applying the 5 new skills, we refine it from a bare functional script into an industry-standard, extensible first-person controller.

### Step-by-Step Rebuild / Refinement Plan for the Worker

#### Step 1: Update `scripts/player/player_config.gd`
Add configuration constants for screen-relative mouse look, collision layer masks, head bob tuning, and camera shake trauma:
```gdscript
# Collision Layers
const LAYER_WORLD: int = 1 << 0        # 1
const LAYER_PLAYER: int = 1 << 1       # 2
const LAYER_INTERACTABLE: int = 1 << 2 # 4
const LAYER_TRIGGER: int = 1 << 3      # 8

# Game Feel: Camera Shake & Head Bob
const DEFAULT_TRAUMA_DECAY: float = 1.5
const MAX_SHAKE_OFFSET: Vector3 = Vector3(0.05, 0.05, 0.0)
const MAX_SHAKE_ROLL_RAD: float = 0.035 # ~2.0 degrees

const DEFAULT_BOB_FREQUENCY: float = 2.4 # cycles per meter of movement
const DEFAULT_BOB_AMPLITUDE_V: float = 0.03 # 3cm vertical bob
const DEFAULT_BOB_AMPLITUDE_H: float = 0.015 # 1.5cm horizontal sway
```

#### Step 2: Refine `scripts/player/player_controller.gd`
Apply the following specific changes:
1. **Screen-Relative Mouse Motion**:
   In `_unhandled_input`:
   ```gdscript
   if event is InputEventMouseMotion and (is_mouse_captured() or DisplayServer.get_name() == "headless"):
       var motion: Vector2 = event.screen_relative if event.screen_relative != Vector2.ZERO else event.relative
       handle_mouse_look(motion)
   ```
2. **CharacterBody3D Floor and Slope Properties**:
   In `_ready()`:
   ```gdscript
   floor_constant_speed = true
   floor_snap_length = 0.2
   floor_stop_on_slope = true
   floor_block_on_wall = true
   floor_max_angle = deg_to_rad(45.0)
   ```
3. **Collision Layer Setup**:
   In `_ready()`:
   ```gdscript
   collision_layer = PlayerConfig.LAYER_PLAYER | PlayerConfig.LAYER_WORLD
   collision_mask = PlayerConfig.LAYER_WORLD
   ```
4. **Teleportation Smoothing Reset**:
   In `teleport_to(...)`:
   ```gdscript
   if has_method("reset_physics_interpolation"):
       reset_physics_interpolation()
   ```
5. **Trauma Shake and Head Bob Hooks**:
   Add signals:
   ```gdscript
   signal landed(fall_speed: float)
   signal step_taken()
   ```
   Add exports & state:
   ```gdscript
   @export_group("Game Feel")
   @export var bob_frequency: float = PlayerConfig.DEFAULT_BOB_FREQUENCY
   @export var bob_amplitude_v: float = PlayerConfig.DEFAULT_BOB_AMPLITUDE_V
   @export var bob_amplitude_h: float = PlayerConfig.DEFAULT_BOB_AMPLITUDE_H
   @export var trauma_decay: float = PlayerConfig.DEFAULT_TRAUMA_DECAY
   
   var trauma: float = 0.0
   var _shake_timer: float = 0.0
   var _bob_timer: float = 0.0
   var _bob_offset: Vector3 = Vector3.ZERO
   var _was_on_floor: bool = true
   var _camera_base_pos: Vector3 = Vector3.ZERO
   ```
   Add helper methods:
   ```gdscript
   func add_trauma(amount: float) -> void:
       trauma = clampf(trauma + amount, 0.0, 1.0)

   func _process(delta: float) -> void:
       _update_camera_shake(delta)
       _update_head_bob(delta)
       _apply_camera_offsets()
   ```
   Implement `_update_camera_shake`, `_update_head_bob`, and `_apply_camera_offsets`:
   - `_update_camera_shake`: smooth sine sampling with quadratic trauma attenuation.
   - `_update_head_bob`: only modifies `_bob_offset` if `head_bob_enabled == true`; otherwise smoothly returns to `Vector3.ZERO`.
   - `_apply_camera_offsets`: sets `camera.position = _camera_base_pos + _bob_offset + shake_pos_offset` and `camera.rotation.z = shake_roll`.
6. **Input Context Gate Flags**:
   Add `@export var movement_enabled: bool = true` and `@export var look_enabled: bool = true`.
   In `_physics_process`: if `not movement_enabled`, set `input_dir = Vector2.ZERO`.
   In `handle_mouse_look`: if `not look_enabled`, return early.

#### Step 3: Update `scripts/tools/build_player_scene.gd` & Rebuild `scenes/player/player.tscn`
Update generator to assign collision layers (`collision_layer = 3`, `collision_mask = 1`) and run:
`godot_console --headless --script res://scripts/tools/build_player_scene.gd`

#### Step 4: Expand `tests/suites/test_player.gd`
Add new automated test cases to verify the new skills features:
- `test_player_floor_and_slope_settings()`: verifies `floor_constant_speed`, `floor_snap_length`, `floor_stop_on_slope`.
- `test_player_collision_layers()`: verifies `collision_layer` and `collision_mask`.
- `test_player_trauma_shake_hook()`: verifies `add_trauma`, trauma decay over time, and camera offset return to zero.
- `test_player_head_bob_hook()`: verifies head bob stays zero when disabled, responds when enabled, and preserves 1.6m eye height at rest.

#### Step 5: Execute Test Runner & Smoke Test
Run full test harness to verify 100% pass rate:
`godot_console.exe --headless --script res://tests/test_runner.gd`
`godot_console.exe --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 60`

#### Step 6: Documentation & Task Closing
Update `docs/completed_tasks/` or record the rebuild milestone in accordance with `AGENTS.md`.

---

## 5. Verification Method

### 5.1 Test Execution Command
Execute the headless test runner via PowerShell/cmd:
```powershell
C:\Users\HP\.local\bin\godot_console.exe --headless --script res://tests/test_runner.gd
```
- **Expected Result**: All suites pass with Exit Code 0, and total assertions >= 325 (plus new assertions for slope settings, trauma shake, and head bob).

### 5.2 Smoke Run Command
Execute the integrated main scene:
```powershell
C:\Users\HP\.local\bin\godot_console.exe --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 60
```
- **Expected Result**: Clean 60-frame run, Exit Code 0, zero errors or warnings.

### 5.3 Files to Inspect
1. `scripts/player/player_config.gd` — confirms layer constants and game-feel parameters.
2. `scripts/player/player_controller.gd` — confirms screen_relative, slope properties, trauma shake, head bob hook, and interpolation reset.
3. `scenes/player/player.tscn` — confirms node tree integrity and collision layer configuration.
4. `tests/suites/test_player.gd` — confirms new test assertions validate skills compliance without regression.

### 5.4 Invalidation Conditions
- Any change that alters `calculate_movement_velocity` output for standard WASD inputs away from exactly 3.0 m/s.
- Any change that alters the resting camera eye height away from 1.6m ± 0.05m.
- Any change that alters vertical pitch clamp away from `[-85.0°, +85.0°]`.
- Any change to `teleport_to` that fails to clear velocity to `Vector3.ZERO` or fails to recover to `safe_return_home` on Y < -5.0.
- Any test failure in `TestSetup`, `TestLevel`, `TestAdversarialLevel`, `TestPlayer`, or `TestAdversarialPlayer`.
