# Handoff Report: Investigation of INT-001 (Interaction Detector & Interactable Component)

**Agent:** explorer_int_001_1 (teamwork_explorer)  
**Date:** 2026-10-27T12:05:00Z  
**Target Milestone:** INT-001 (Target interaksi, prompt dan konteks input)  
**Recipient:** Orchestrator / Worker (`bc3795f9-23c4-4352-8a9c-4322971bcc61`)

---

## 1. Observation

Direct observations from examining the codebase, project configuration, and specification documents:

### 1.1 Project Settings & Collision Layers
- In `project.godot` (lines 27–33):
  ```ini
  [layer_names]
  3d_physics/layer_1="environment"
  3d_physics/layer_2="player"
  3d_physics/layer_3="interactables"
  3d_physics/layer_4="triggers"
  ```
- In `scripts/player/player_config.gd` (lines 30–35):
  ```gdscript
  const LAYER_ENVIRONMENT: int = 1 << 0  # 1
  const LAYER_PLAYER: int = 1 << 1       # 2
  const LAYER_INTERACTABLES: int = 1 << 2 # 4
  const LAYER_TRIGGERS: int = 1 << 3     # 8
  const DEFAULT_PLAYER_COLLISION_MASK: int = LAYER_ENVIRONMENT | LAYER_INTERACTABLES | LAYER_TRIGGERS # 13
  ```
- Input action for interaction is already registered in `project.godot` (lines 60–64):
  `interact` mapped to key `E` (physical keycode 69).

### 1.2 Current State of Player Scene & Controller
- In `scenes/player/player.tscn` (lines 9–27):
  ```
  Player (CharacterBody3D, collision_layer = 2, collision_mask = 13)
  ├── CollisionShape3D (CapsuleShape3D, radius 0.4, height 1.8, Y = 0.9)
  └── Head (Node3D, transform Y = 1.6)
      └── Camera3D (Camera3D, current = true, fov = 80.0)
  ```
  Currently, `scenes/player/player.tscn` does NOT have an `InteractionDetector` child node attached to `Camera3D`.
- In `scripts/player/player_controller.gd`:
  - Camera pitch is applied to `Head.rotation.x` (clamped to `[-85.0°, +85.0°]`).
  - Player yaw is applied to `Player.rotation.y`.
  - Camera shake and head bob offsets are applied to `Camera3D.position` and `Camera3D.rotation.z` (lines 201–205).
  - Input gating flags `movement_enabled` and `look_enabled` are already implemented (lines 13, 16, 102, 161).
  - Handling of the `interact` action is currently not connected to any detector.

### 1.3 Analysis of Prototype Scripts (`interactable.gd` & `interaction_detector.gd`)
- In `scripts/interaction/interactable.gd` (lines 13–16):
  ```gdscript
  func _ready() -> void:
      # Pastikan collision layer terkonfigurasi untuk deteksi raycast
      collision_layer = 1
      collision_mask = 1
  ```
  **Critical Defect Found:** `interactable.gd` hardcodes `collision_layer = 1` and `collision_mask = 1`. Layer 1 is `environment`, NOT `interactables`! If left on Layer 1, interactables mix with solid walls and ground geometry.
- In `scripts/interaction/interaction_detector.gd` (lines 17–23):
  ```gdscript
  func _ready() -> void:
      add_to_group("interaction_detector")
      target_position = Vector3(0.0, 0.0, -max_interaction_distance)
      collide_with_areas = true
      collide_with_bodies = true
      collision_mask = 1
      enabled = true
  ```
  **Critical Defect Found:** `interaction_detector.gd` hardcodes `collision_mask = 1`. If `collision_mask = 1`, it only collides with Layer 1 (`environment`). If interactables are moved to Layer 3 (`interactables` = 4), the raycast with mask 1 will completely fail to detect any interactable!
  The raycast mask MUST be `1 | 4 = 5` (Layer 1 Environment + Layer 3 Interactables).

### 1.4 Level Landmarks & Graybox Setup
- In `scenes/world/level_graybox.tscn` and `scripts/world/level_graybox.gd`:
  - 18 landmarks are present.
  - In `scripts/tools/build_level_graybox.gd`, all solid bodies (e.g. house walls, tables, counters, basins) are created via `create_box_static_body` which sets `collision_layer = 1` (`environment`) and `collision_mask = 1`.
  - Currently, NONE of the 18 landmarks have an `Interactable` node attached.
- Coordinates of interactive landmarks:
  1. `book_family`: `Vector3(-1, 0, -2)`
  2. `station_kitchen_home`: `Vector3(2, 0, -4)`
  3. `storage_home`: `Vector3(-2, 0, -4)`
  4. `bed_home`: `Vector3(-2, 0, 0)`
  5. `plot_home_01`: `Vector3(8, 0, 7)`
  6. `water_home`: `Vector3(4, 0, 9)`
  7. `container_starter`: `Vector3(6, 0, 4)`
  8. `reserve_home`: `Vector3(7, 0, 4)`
  9. `resource_jagung_01`: `Vector3(22, 0, 28)`
  10. `note_garden_01`: `Vector3(19, 0, 27)`
  11. `resource_temu_kunci_01`: `Vector3(-20, 0, 30)`
  12. `npc_neighbor_01`: `Vector3(-14, 0, 15)`
- Wall geometry:
  - House exterior walls: `WallNorth` at `Z = -6`, `WallWest` at `X = -4`, `WallEast` at `X = 4`, `WallSouthLeft` / `WallSouthRight` at `Z = 4`.
  - All house interior interactive objects (`book_family`, `station_kitchen_home`, `storage_home`, `bed_home`) have >= 1.5m to 2.0m clearance from the nearest exterior walls.

### 1.5 Verification Suite Baseline
- `tests/test_runner.gd` executed via `godot --headless -s tests/test_runner.gd`:
  - 5 test suites (TestSetup, TestLevel, TestAdversarialLevel, TestPlayer, TestAdversarialPlayer).
  - 358 assertions passed, 0 failures, exit code 0.
- Reference check via `python .agents/skills/godot-nodes-scenes/scripts/check_godot_project.py .`:
  - 0 errors, 0 warnings across 28 checked files.

---

## 2. Logic Chain

From the direct observations above, the design and implementation logic flows as follows:

1. **Raycast Attachment & Orientation:**
   - From Observation 1.2, `PlayerController` pitches `Head` (around X) and yaws `Player` (around Y).
   - In Godot 3D, a camera's forward optical direction is local `-Z`.
   - By attaching `InteractionDetector` (`RayCast3D`) as a direct child of `Camera3D` at local position `(0, 0, 0)` with `target_position = Vector3(0.0, 0.0, -2.0)`:
     - The raycast length is exactly 2.0 meters, fulfilling `CONTENT.md § 14` ("Jangkauan interaksi: 2 meter dari kamera") and `PRD FR02`.
     - The raycast automatically rotates with both yaw and pitch, perfectly coinciding with the center crosshair on screen.
     - When procedural trauma shake or head bob adjusts `Camera3D`, the raycast follows the visual view frustum without desync.

2. **Collision Layer & Mask Decoupling:**
   - From Observation 1.1:
     - Layer 1 = `environment` (bitmask value `1`, `1 << 0`)
     - Layer 2 = `player` (bitmask value `2`, `1 << 1`)
     - Layer 3 = `interactables` (bitmask value `4`, `1 << 2`)
     - Layer 4 = `triggers` (bitmask value `8`, `1 << 3`)
   - To make `Interactable` detectible by the detector without obstructing the player's physical locomotion:
     - `Interactable` MUST extend `Area3D` (not `StaticBody3D`).
     - `Interactable.collision_layer` MUST be `4` (Layer 3: `interactables`).
     - `Interactable.collision_mask` MUST be `0`, with `monitoring = false` and `monitorable = true`.
   - To detect interactables AND enforce wall occlusion:
     - `InteractionDetector.collision_mask` MUST be `1 | 4 = 5` (Layer 1: `environment` + Layer 3: `interactables`).
     - `InteractionDetector.collide_with_areas = true` (to intersect `Interactable` Area3D).
     - `InteractionDetector.collide_with_bodies = true` (to intersect `Environment` walls and landmark StaticBody3D).

3. **Wall Occlusion Mechanism (T27 Guarantee):**
   - Godot's `RayCast3D` stops at the FIRST collision surface intersected along its ray from origin to `target_position`.
   - Scenario A (Direct Line of Sight): The raycast intersects the `Interactable`'s Area3D on Layer 3 before reaching any other surface. `get_collider()` returns the `Interactable`. The detector registers `target_focused`.
   - Scenario B (Wall Occlusion): A solid wall (`StaticBody3D` on Layer 1) is located between the camera and the `Interactable`.
     Because Layer 1 is in the raycast's collision mask (`mask = 5`), the raycast hits the wall FIRST.
     `get_collider()` returns the `Wall` `StaticBody3D`.
     The detector evaluates `find_interactable(collider)`.
     Because the wall is an environmental structure with parent `HouseStructure` (no Interactable component), `find_interactable` returns `null`.
     Consequently, `current_interactable` is cleared to `null`.
     No prompt is displayed, and pressing E does not interact with the object behind the wall.
   - Scenario C (Out of Range): If an interactable is at distance > 2.0m, the 2.0m raycast does not reach it (`is_colliding() == false`). Focus is cleared.

4. **Landmark Composition Architecture:**
   - In `scenes/world/level_graybox.tscn`, landmarks represent both visual/physical objects and interactive entities.
   - To follow Godot's composition paradigm (`godot-nodes-scenes/SKILL.md`):
     - Keep the landmark's physical body (`StaticBody3D` on Layer 1) for player collision (e.g. so player cannot walk through tables or chests).
     - Attach a child node named `Interactable` (`Area3D` with script `res://scripts/interaction/interactable.gd`) on Layer 3.
     - Give `Interactable` a child `CollisionShape3D` (BoxShape3D) sized to envelope the interactive surface.
   - For 12 key landmarks, attach `Interactable` with appropriate Indonesian prompts per `CONTENT.md` and `UI_UX.md`.

5. **Input Context Management (T18 & T28 Guarantee):**
   - When a modal UI panel (Book, Storage, Kitchen, Pause) opens:
     - `interaction_detector.interaction_enabled = false`
     - `interaction_detector.clear_target()`
     - `player.movement_enabled = false`
     - `player.look_enabled = false`
     - `player.release_mouse()`
   - When the modal UI panel closes:
     - `interaction_detector.interaction_enabled = true`
     - `player.movement_enabled = true`
     - `player.look_enabled = true`
     - `player.capture_mouse()`
   - In `interaction_detector.interact()`, input is consumed via `get_viewport().set_input_as_handled()`, preventing input bleed-through into tool actions or other systems.

---

## 3. Caveats

- **Crop Spot Sub-Interactions (GARD-001/002):** In `plot_home_01`, the top-level landmark has an inspection prompt `[E] Periksa Petak`. In future milestones `GARD-001` and `GARD-002`, individual spots (`spot_0` .. `spot_3`) will require specific planting and harvesting interactions. For `INT-001`, attaching the plot-level inspection interactable satisfies T24 and INT-001 baseline without preempting GARD-001 logic.
- **Hold Interactions (GARD-001 & COOK-001):** The `Interactable` component includes `@export var hold_time: float = 0.0`. Instant interactions (E press) have `hold_time = 0.0`. Actions requiring 2s hold (hoeing, watering) or 4s hold (cooking prep) can use `hold_time > 0.0` or tool input handlers in their respective milestones.
- **UI HUD Prompt Display:** `INT-001` focuses on target acquisition, prompt text provision, and occlusion. A basic prompt label / HUD hook must be wired so the player sees `[E] <Action>` when focused, or HUD can listen to `target_focused(interactable)` and `target_unfocused()`.

---

## 4. Conclusion & Concrete Implementation Recommendations

The Worker agent can implement `INT-001` cleanly with zero architectural regressions by following these concrete steps:

### Recommendation 1: Fix `scripts/interaction/interactable.gd`
Replace existing prototype code with typed, robust implementation:
```gdscript
class_name Interactable
extends Area3D

## Komponen Interaksi Dunia untuk 'Buku Resep 2045'
## Memenuhi spesifikasi PRD FR02, UI_UX.md § 3/4, dan CONTENT.md § 14

signal focused()
signal unfocused()
signal interacted(player: Node3D)

@export var interaction_id: String = ""
@export var prompt_text: String = "[E] Interaksi"
@export var is_interactable: bool = true
@export var hold_time: float = 0.0

func _ready() -> void:
	# Layer 3: interactables (bitmask 1 << 2 = 4)
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true

func interact(player: Node3D) -> bool:
	if not is_interactable:
		return false
	interacted.emit(player)
	return true

func get_prompt() -> String:
	return prompt_text

func set_prompt(new_prompt: String) -> void:
	prompt_text = new_prompt

func set_interactable(val: bool) -> void:
	is_interactable = val

func on_focused() -> void:
	focused.emit()

func on_unfocused() -> void:
	unfocused.emit()
```

### Recommendation 2: Fix `scripts/interaction/interaction_detector.gd`
Update detector raycast logic:
- `max_interaction_distance = 2.0`
- `target_position = Vector3(0.0, 0.0, -max_interaction_distance)`
- `collide_with_areas = true`
- `collide_with_bodies = true`
- `collision_mask = 5` (`PlayerConfig.LAYER_ENVIRONMENT | PlayerConfig.LAYER_INTERACTABLES`)
- In `find_interactable(col)`:
  - Check if `col is Interactable`: return `col`
  - Check if `col is Node`:
    - If `col.has_node("Interactable")`: return `col.get_node("Interactable")`
    - Check parent: `var p = col.get_parent()`
      - If `p == null` or `p.name == "HouseStructure"` or `p.name == "Environment"` or `p.name == "LevelGraybox"`: stop traversal (prevent false environment matches).
      - If `p is Interactable`: return `p`
      - If `p.has_node("Interactable")`: return `p.get_node("Interactable")`
- Add `interaction_enabled: bool = true` flag. When false, clear target and do not update.
- Provide `interact(player: Node3D = null) -> bool` that invokes `current_interactable.interact(player)` and emits `interaction_performed`.

### Recommendation 3: Attach `InteractionDetector` in `player.tscn`
Update `scripts/tools/build_player_scene.gd` and `scenes/player/player.tscn`:
- Attach `InteractionDetector` (`RayCast3D`) as a child of `Player/Head/Camera3D`.
- Set script to `res://scripts/interaction/interaction_detector.gd`.
- In `player_controller.gd`:
  - Add `@onready var interaction_detector: InteractionDetector = find_child("InteractionDetector", true, false) as InteractionDetector`.
  - In `_unhandled_input(event)`:
    ```gdscript
    if event.is_action_pressed("interact"):
        if interaction_detector and interaction_detector.has_focused_target():
            var success = interaction_detector.interact(self)
            if success:
                get_viewport().set_input_as_handled()
    ```

### Recommendation 4: Update `level_graybox.tscn` with 12 Landmark Interactables
Update `scripts/tools/build_level_graybox.gd` to add an `Interactable` Area3D child to each of the 12 landmarks:
| Landmark ID | Interaction ID | Prompt Text (Indonesian) | BoxShape3D Size (W, H, D) | Local Offset |
|---|---|---|---|---|
| `book_family` | `book_family` | `[E] Buka Buku Resep` | `(1.2, 0.8, 0.8)` | `Vector3(0, 0.5, 0)` |
| `storage_home` | `storage_home` | `[E] Buka Peti Rumah` | `(1.2, 0.8, 0.8)` | `Vector3(0, 0.4, 0)` |
| `station_kitchen_home` | `station_kitchen_home` | `[E] Gunakan Dapur` | `(2.0, 0.9, 1.0)` | `Vector3(0, 0.45, 0)` |
| `bed_home` | `bed_home` | `[E] Istirahat` | `(1.8, 0.3, 2.0)` | `Vector3(0, 0.2, 0)` |
| `plot_home_01` | `plot_home_01` | `[E] Periksa Petak` | `(2.0, 0.3, 2.0)` | `Vector3(0, 0.1, 0)` |
| `water_home` | `water_home` | `[E] Ambil Air` | `(0.8, 1.0, 0.8)` | `Vector3(0, 0.5, 0)` |
| `container_starter` | `container_starter` | `[E] Ambil Paket Awal` | `(0.8, 0.6, 0.8)` | `Vector3(0, 0.3, 0)` |
| `reserve_home` | `reserve_home` | `[E] Periksa Cadangan` | `(0.8, 0.6, 0.8)` | `Vector3(0, 0.3, 0)` |
| `resource_jagung_01` | `resource_jagung_01` | `[E] Periksa Jagung` | `(1.5, 1.8, 1.5)` | `Vector3(0, 0.9, 0)` |
| `note_garden_01` | `note_garden_01` | `[E] Baca Catatan` | `(0.4, 1.0, 0.4)` | `Vector3(0, 0.5, 0)` |
| `resource_temu_kunci_01` | `resource_temu_kunci_01` | `[E] Periksa Temu Kunci` | `(1.6, 1.0, 1.4)` | `Vector3(0, 0.5, 0)` |
| `npc_neighbor_01` | `npc_neighbor_01` | `[E] Bicara dengan Tetangga` | `(1.8, 0.8, 0.8)` | `Vector3(0, 0.4, 0)` |

Re-run `godot --headless -s scripts/tools/build_level_graybox.gd` to bake into `scenes/world/level_graybox.tscn`.

### Recommendation 5: Simple HUD Prompt Display
Create or attach a basic HUD Control (`scenes/ui/hud.tscn` or directly in `scenes/main.tscn`) containing:
- Crosshair (`TextureRect` or small `Label` `"+"`)
- Prompt Label (`Label` centered below crosshair)
- Connecting to `interaction_detector.target_focused` -> sets `prompt_label.text = interactable.get_prompt()` and `visible = true`.
- Connecting to `interaction_detector.target_unfocused` -> sets `visible = false`.

### Recommendation 6: Comprehensive Unit Test Suite (`tests/suites/test_interaction.gd`)
Create test suite covering:
1. **T27.1:** Raycast parameters verification (length = 2.0m, mask = 5, areas/bodies = true).
2. **T27.2:** Direct target acquisition within range (<= 2.0m).
3. **T27.3:** Out of range rejection (> 2.0m).
4. **T27.4:** Wall occlusion verification (target at 1.8m, wall on Layer 1 at 0.9m -> candidate is null, prompt not shown, interact returns false).
5. **T27.5:** Single closest target guarantee (2 targets aligned, only closest acquired).
6. **T27.6:** 12 landmark interactable verification in `level_graybox.tscn`.
7. **T18.1:** Input context gating (`interaction_enabled = false` blocks target acquisition and "E" interaction).
8. **T28.1:** Signal transition idempotence (focused and unfocused emit once per transition).

Register in `tests/test_runner.gd` so headless runner executes all tests in CI.

---

## 5. Verification Method

To verify the investigation and subsequent worker implementation:

1. **Static Reference Verification:**
   ```powershell
   python ".agents/skills/godot-nodes-scenes/scripts/check_godot_project.py" .
   ```
   *Expected:* 0 errors, 0 warnings.

2. **Automated Headless Test Suite:**
   ```powershell
   powershell -Command "& 'C:\Users\HP\.local\bin\godot.exe' --headless -s tests/test_runner.gd | Out-Default"
   ```
   *Expected:* Exit code 0, all suites pass including new `TestInteraction` suite.

3. **Wall Occlusion Invalidation Conditions:**
   - If an interactable behind a solid wall (Layer 1) triggers `target_focused` or responds to `interact()`, the implementation is INVALID.
   - If an interactable at distance > 2.0m triggers `target_focused`, the implementation is INVALID.
   - If pressing "E" when a UI modal is active triggers an interaction in the world, the implementation is INVALID.
   - If any landmark in `level_graybox.tscn` is missing its `Interactable` node or has an empty prompt, the implementation is INVALID.

---
*Report prepared by explorer_int_001_1. Read-only investigation complete.*
