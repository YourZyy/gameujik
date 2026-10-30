# Handoff Report — UI Prompt Scene & Headless Test Suite Design (INT-001)

**Agent:** `explorer_int_001_3`  
**Working Directory:** `.agents/teamwork/explorer_int_001_3/`  
**Date:** 27 Oktober 2026  
**Target Milestone:** `INT-001` (Object Interaction, UI Prompt, Occlusion & Input Context)  
**Parent Agent:** `bc3795f9-23c4-4352-8a9c-4322971bcc61`

---

## 1. Observation

### 1.1 Project Configuration & Physics Layer Mapping
From direct inspection of `project.godot`:
- **Viewport & Scaling (lines 16–20):**
  ```ini
  [display]
  window/size/viewport_width=1280
  window/size/viewport_height=720
  window/size/resizable=true
  window/stretch/mode="canvas_items"
  window/stretch/aspect="keep"
  ```
- **3D Physics Layer Registration (lines 27–32):**
  ```ini
  [layer_names]
  3d_physics/layer_1="environment"
  3d_physics/layer_2="player"
  3d_physics/layer_3="interactables"
  3d_physics/layer_4="triggers"
  ```
- **Input Map Actions (lines 60–79):**
  - Action `"interact"` mapped to physical keycode 69 (`Key.E`).
  - Action `"open_book"` mapped to keycode 66 (`Key.B`).
  - Action `"open_inventory"` mapped to keycode 4194306 (`Key.TAB`).
  - Action `"pause_menu"` mapped to keycode 4194305 (`Key.ESCAPE`).

### 1.2 Existing Interaction Scripts & Latent Compilation Blocker
- File `scripts/interaction/interactable.gd`:
  - Lines 1–17: `class_name Interactable extends Area3D`.
  - Lines 13–16:
    ```gdscript
    func _ready() -> void:
        collision_layer = 1
        collision_mask = 1
    ```
- File `scripts/interaction/interaction_detector.gd`:
  - Lines 1–23: `class_name InteractionDetector extends RayCast3D`.
  - Line 15: `var current_interactable: Interactable = null`
  - Line 22: `collision_mask = 1`
  - Lines 56, 64, 105: Functions return or take `Interactable`.
- **Verbatim Error Observed During Headless Load:**
  Running `C:\Users\HP\.local\bin\godot.exe --headless --path . -s .agents/teamwork/explorer_int_001_3/probe_load.gd` produced:
  ```
  SCRIPT ERROR: Parse Error: Could not find type "Interactable" in the current scope.
     at: GDScript::reload (res://scripts/interaction/interaction_detector.gd:15)
  ERROR: Failed to load script "res://scripts/interaction/interaction_detector.gd" with error "Parse error".
  ```
  - Direct inspection of `.godot/global_script_class_cache.cfg` shows only `Assertions` and `TestSetup` registered. Without `const InteractableClass = preload("res://scripts/interaction/interactable.gd")`, Godot's GDScript parser fails to compile `interaction_detector.gd`.

### 1.3 Player Scene Hierarchy & Input Gating Flags
- In `scenes/player/player.tscn` and `scripts/tools/build_player_scene.gd`:
  - Node hierarchy: `Player` (`CharacterBody3D`) -> `CollisionShape3D`, `Head` (`Node3D`, pos Y=1.6) -> `Camera3D` (`Camera3D`, current=true, fov=80).
  - There is currently no `InteractionDetector` node attached in `player.tscn`.
- In `scripts/player/player_controller.gd`:
  - Line 13: `@export var movement_enabled: bool = true`
  - Line 16: `@export var look_enabled: bool = true`
  - Lines 73–84: `capture_mouse()`, `release_mouse()`, `is_mouse_captured()` methods exist.
  - Line 86: `_unhandled_input(event)` handles left click capture, `pause_menu` release, and mouse motion. It does not yet connect to `interact` action.

### 1.4 Existing Test Runner & Suite Architecture
- Running existing test harness via `C:\Users\HP\.local\bin\godot.exe --headless --path . --script res://tests/test_runner.gd` produces:
  - 358 assertions passed, 0 failed, exit code 0.
  - Test suites: `test_setup.gd`, `test_level.gd`, `test_adversarial_level.gd`, `test_player.gd`, `test_adversarial_player.gd`.
  - Helper library: `tests/assertions.gd` (`assert_true`, `assert_false`, `assert_equal`, `assert_not_null`, `assert_null`, `assert_gt`, `assert_ne`, `assert_approx_equal`, `assert_vector3_approx_equal`).
  - No UI scenes exist under `scenes/ui/` yet.

### 1.5 Headless Physics RayCast Behavior
Direct empirical probe in SceneTree headless mode confirmed:
- Adding `RayCast3D` and `CollisionObject3D` directly to the `SceneTree.root` without awaiting frames causes:
  `ERROR: Condition "!is_inside_tree()" is true. at: force_update_transform`
  `ERROR: Condition "w3d.is_null()" is true. at: _update_raycast_state`
- After `await process_frame` and `await physics_frame` (2 frames), `PhysicsServer3D` space state is fully synchronized:
  `detector.update_target()` reliably detects `Interactable` colliders in headless execution.

---

## 2. Logic Chain

1. **Compilation Resolution (`preload` vs `class_name`):**
   - *Observation:* `interaction_detector.gd` failed to parse because `Interactable` was not in `.godot/global_script_class_cache.cfg`. Existing passing suites (`test_player.gd`, `test_level.gd`) all use explicit `const ... = preload(...)`.
   - *Inference:* `interaction_detector.gd` must define `const InteractableClass = preload("res://scripts/interaction/interactable.gd")` and use `InteractableClass` for variable and return typing, guaranteeing parse success in any fresh checkout or headless environment without relying on external class cache.

2. **Physics Layer & Occlusion Mechanism (T27):**
   - *Observation:* In `project.godot`, Layer 1 is `"environment"` and Layer 3 is `"interactables"`. Currently `interaction_detector.gd` has `collision_mask = 1`, and `interactable.gd` has `collision_layer = 1`.
   - *Inference:*
     - If `Interactable` is placed on Layer 3 (`collision_layer = 4`), `InteractionDetector` must include Layer 3 in its mask to detect it.
     - If an opaque wall on Layer 1 (`collision_layer = 1`) stands between the player camera and the interactable, the raycast will hit the wall first *only if* Layer 1 is in `collision_mask`.
     - Therefore, `InteractionDetector.collision_mask` MUST be `5` (binary `0101`: Layer 1 Environment + Layer 3 Interactables).
     - When a wall is present, RayCast3D stops at the wall; `get_collider()` returns the wall. `find_interactable(wall)` returns `null`, causing `current_interactable` to become `null` and the prompt to hide.
     - When no wall is present, the raycast reaches the interactable (Layer 3), `find_interactable(collider)` succeeds, and the prompt appears. This completely satisfies T27.

3. **UI Prompt Anchor & Responsive Scaling (`game-ui-ux` & `godot-ui-control`):**
   - *Observation:* Display settings are `1280x720` with stretch mode `canvas_items` and aspect `keep`. Design specifications in `docs/UI_UX.md` § 1, 2, 4, 5.1 require a center reticle (small neutral dot) and a single prompt box positioned "sedikit bawah tengah" (slightly below center).
   - *Inference:*
     - The root of `interaction_prompt.tscn` must be a `CanvasLayer` (decoupling from 3D camera transforms).
     - A full-screen `Control` wrapper with `anchors_preset = PRESET_FULL_RECT` and `mouse_filter = MOUSE_FILTER_IGNORE` ensures UI never consumes 3D world mouse clicks.
     - The reticle (`ColorRect`, 4x4 or 6x6 px) must use `anchors_preset = PRESET_CENTER` (anchors `(0.5, 0.5)` with offsets `-2` to `+2`), locking it to screen center `(640, 360)` at baseline.
     - The prompt panel (`PanelContainer`, dark translucent StyleBoxFlat, rounded corners) must use `anchors_preset = PRESET_CENTER` with `offset_top = +36.0` to `+40.0` px, positioning it directly underneath the reticle.
     - Under `canvas_items` stretch mode, this relative anchor positioning scales uniformly across 720p, 1080p, and 1440p without pixel clipping or manual repositioning.

4. **Input Context Mode Switching & Bleed-Through Prevention (T18, T28):**
   - *Observation:* `player_controller.gd` already provides `movement_enabled`, `look_enabled`, `capture_mouse()`, and `release_mouse()`.
   - *Inference:*
     - An `InputManager` (or Context Controller) must manage a stack of modes: `WORLD` (exploration), `BOOK`, `STORAGE`, `KITCHEN`, `DIALOGUE`, `PAUSE`.
     - In `WORLD`: mouse is captured, movement and look are active, interaction raycast is active.
     - In any MODAL mode: mouse is released (`Input.MOUSE_MODE_VISIBLE`), `player.movement_enabled = false`, `player.look_enabled = false`, interaction prompt is hidden.
     - When closing modal with Esc or key: the event is consumed via `get_viewport().set_input_as_handled()`, preventing key release/press events from bleeding into world actions.

5. **Headless Test Suite Design (`tests/suites/test_interaction.gd`):**
   - *Observation:* Tests must gate CI with deterministic exit codes. Unit-level math and tree-level signals can execute synchronously or via 2-frame awaits without hanging.
   - *Inference:*
     - Structure `test_interaction.gd` into modular tests:
       1. UI Hierarchy & Anchor scaling invariants
       2. T18 Target acquisition & 2.0m range threshold
       3. T18 Interaction signal emission & execution
       4. T27 Occlusion rejection behind static bodies
       5. T28 Input context mode switching & mouse state
       6. T28 Bleed-through prevention (movement/look gating & event consumption)
     - Register `TestInteraction` into `tests/test_runner.gd` with assertion counting via `Assertions`.

---

## 3. Caveats

1. **Autoload vs Standalone Node:** `InputManager` can either be registered in `project.godot` as an autoload or instanced inside `main.tscn`. For headless testing resilience, `InputManager` must be instantiable via `InputManager.new()` without requiring engine autoload initialization.
2. **DisplayServer Headless Mode:** In headless mode (`DisplayServer.get_name() == "headless"`), Godot does not trap the OS mouse cursor. `PlayerController` already tracks `_mouse_captured` boolean internally; `InputManager` should check both `is_mouse_captured()` and `Input.mouse_mode`.
3. **Tween Animation in Headless Testing:** UI fade-in/fade-out animations using `create_tween()` require scene tree process frames. The UI script should support immediate visibility toggling (`animate: bool = false`) or headless bypass to ensure test assertions evaluate deterministically without waiting.

---

## 4. Conclusion & Concrete Implementation Recommendations

The Worker agent should implement INT-001 following the blueprint below:

### 4.1 Script Fixes & Enhancements

#### A. Fix `scripts/interaction/interaction_detector.gd`
1. Add explicit preload at top:
   ```gdscript
   const InteractableClass = preload("res://scripts/interaction/interactable.gd")
   ```
2. Update typing:
   - `var current_interactable: InteractableClass = null`
   - `func _set_focused_target(new_target: InteractableClass) -> void:`
   - `func find_interactable(collider: Object) -> InteractableClass:`
   - `func get_focused_interactable() -> InteractableClass:`
3. Configure collision mask:
   ```gdscript
   # Layer 1 (Environment, bit 0 = 1) + Layer 3 (Interactables, bit 2 = 4) -> mask = 5
   collision_mask = 5
   collide_with_areas = true
   collide_with_bodies = true
   ```
4. Expose helper `set_max_distance(dist: float)` and ensure `target_position = Vector3(0.0, 0.0, -max_interaction_distance)`.

#### B. Update `scripts/interaction/interactable.gd`
1. Set default collision layer:
   ```gdscript
   @export var interaction_layer: int = 4 # Layer 3: interactables (1 << 2)
   
   func _ready() -> void:
       collision_layer = interaction_layer
       collision_mask = 1
   ```

#### C. Player Scene & Controller Integration
1. In `scripts/tools/build_player_scene.gd` and `scenes/player/player.tscn`:
   - Under `Head/Camera3D`, add child `InteractionDetector` (`RayCast3D` with script `res://scripts/interaction/interaction_detector.gd`).
   - Position: `Vector3.ZERO`, `target_position = Vector3(0.0, 0.0, -2.0)`.
2. In `scripts/player/player_controller.gd`:
   - Add reference:
     ```gdscript
     @onready var interaction_detector = find_child("InteractionDetector", true, false)
     ```
   - In `_unhandled_input(event: InputEvent)`:
     ```gdscript
     if event.is_action_pressed("interact") and movement_enabled:
         if interaction_detector and interaction_detector.has_method("interact_with_current"):
             if interaction_detector.interact_with_current(self):
                 get_viewport().set_input_as_handled()
     ```

### 4.2 UI Prompt Scene & Script Specifications

#### A. Scene Layout (`scenes/ui/interaction_prompt.tscn`)
- Root: `CanvasLayer` (Name: `InteractionPromptUI`, `layer = 1`, Script: `res://scripts/ui/interaction_prompt.gd`)
  - Child: `Control` (Name: `RootControl`, `anchors_preset = Control.PRESET_FULL_RECT`, `mouse_filter = Control.MOUSE_FILTER_IGNORE`)
    - Child: `ColorRect` (Name: `Reticle`, `anchors_preset = Control.PRESET_CENTER`, `offset_left = -2`, `offset_top = -2`, `offset_right = 2`, `offset_bottom = 2`, `color = Color(1.0, 1.0, 1.0, 0.85)`, `mouse_filter = Control.MOUSE_FILTER_IGNORE`)
    - Child: `PanelContainer` (Name: `PromptPanel`, `anchors_preset = Control.PRESET_CENTER`, `grow_horizontal = Control.GROW_DIRECTION_BOTH`, `offset_top = 36.0`, `offset_bottom = 72.0`, `mouse_filter = Control.MOUSE_FILTER_IGNORE`)
      - StyleBoxFlat: `bg_color = Color(0.08, 0.08, 0.08, 0.75)`, `corner_radius_* = 4`, `content_margin_left = 12`, `content_margin_right = 12`, `content_margin_top = 6`, `content_margin_bottom = 6`
      - Child: `Label` (Name: `PromptLabel`, text = `"[E] Interaksi"`, `horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER`, `vertical_alignment = VERTICAL_ALIGNMENT_CENTER`, font color = `Color(1.0, 0.96, 0.92, 1.0)`, `mouse_filter = Control.MOUSE_FILTER_IGNORE`)

#### B. Script API (`scripts/ui/interaction_prompt.gd`)
```gdscript
class_name InteractionPromptUI
extends CanvasLayer

@onready var prompt_panel: PanelContainer = find_child("PromptPanel", true, false)
@onready var prompt_label: Label = find_child("PromptLabel", true, false)
@onready var reticle: Control = find_child("Reticle", true, false)

var _is_visible: bool = false

func _ready() -> void:
    hide_prompt(false)

func show_prompt(text: String, animate: bool = true) -> void:
    if prompt_label:
        prompt_label.text = text
    _is_visible = true
    if prompt_panel:
        prompt_panel.visible = true
        prompt_panel.modulate.a = 1.0

func hide_prompt(animate: bool = true) -> void:
    _is_visible = false
    if prompt_panel:
        prompt_panel.visible = false
        prompt_panel.modulate.a = 0.0

func is_prompt_visible() -> bool:
    return _is_visible and prompt_panel != null and prompt_panel.visible

func get_prompt_text() -> String:
    return prompt_label.text if prompt_label else ""

func connect_detector(detector: Node) -> void:
    if detector.has_signal("target_focused"):
        detector.target_focused.connect(_on_target_focused)
    if detector.has_signal("target_unfocused"):
        detector.target_unfocused.connect(_on_target_unfocused)

func _on_target_focused(interactable: Object) -> void:
    var text := "[E] Interaksi"
    if interactable.has_method("get_prompt"):
        text = interactable.get_prompt()
    show_prompt(text)

func _on_target_unfocused() -> void:
    hide_prompt()
```

### 4.3 Input Context Controller (`scripts/core/input_manager.gd`)

```gdscript
class_name InputManager
extends Node

enum ContextMode {
    WORLD,
    BOOK,
    STORAGE,
    KITCHEN,
    DIALOGUE,
    PAUSE
}

signal context_changed(new_context: ContextMode, old_context: ContextMode)

var context_stack: Array[ContextMode] = [ContextMode.WORLD]
var player: PlayerController = null

func bind_player(p: PlayerController) -> void:
    player = p

func push_context(mode: ContextMode) -> void:
    var old_mode := get_current_context()
    context_stack.append(mode)
    _apply_context_state(mode, old_mode)

func pop_context() -> ContextMode:
    if context_stack.size() <= 1:
        return ContextMode.WORLD
    var old_mode := context_stack.pop_back()
    var new_mode := get_current_context()
    _apply_context_state(new_mode, old_mode)
    return old_mode

func get_current_context() -> ContextMode:
    return context_stack.back() if not context_stack.is_empty() else ContextMode.WORLD

func is_world() -> bool:
    return get_current_context() == ContextMode.WORLD

func _apply_context_state(new_mode: ContextMode, old_mode: ContextMode) -> void:
    if player:
        if new_mode == ContextMode.WORLD:
            player.movement_enabled = true
            player.look_enabled = true
            player.capture_mouse()
        else:
            player.movement_enabled = false
            player.look_enabled = false
            player.release_mouse()
    context_changed.emit(new_mode, old_mode)
```

### 4.4 Test Suite Blueprint (`tests/suites/test_interaction.gd`)

| Test Function | Verification Target | Expected Result |
|---|---|---|
| `test_ui_scene_hierarchy_and_anchors()` | `scenes/ui/interaction_prompt.tscn` | Root is CanvasLayer, Reticle at `PRESET_CENTER`, PromptPanel offset +36px below, mouse_filter = IGNORE. |
| `test_ui_prompt_visibility_and_text()` | `InteractionPromptUI` API | `show_prompt()` sets text and `visible=true`; `hide_prompt()` sets `visible=false`. |
| `test_t18_range_acquisition_and_signals()` | Distance detection at 1.5m vs 2.5m | Target at 1.5m emits `target_focused`, updates prompt; target at 2.5m is ignored (`current_interactable == null`). |
| `test_t18_interaction_execution()` | `interact_with_current(player)` | Focused target receives `interact(player)` and emits `interacted(player)`. Inactive target (`is_interactable = false`) returns `false`. |
| `test_t27_occlusion_rejection_behind_wall()` | Wall on Layer 1 between detector and target | Wall intercepts raycast; `find_interactable` returns `null`; target unfocused; prompt hidden. Wall removed restores detection. |
| `test_t28_input_context_mode_switching()` | Stack push/pop across WORLD, BOOK, PAUSE | Entering modal releases mouse and disables movement/look. Returning to WORLD restores movement/look and captures mouse. |
| `test_t28_bleed_through_prevention()` | Modal active during movement/look input | WASD velocity remains `Vector3.ZERO`, mouse motion ignored, interact [E] blocked, closing input marks event as handled. |

### 4.5 Registration into `tests/test_runner.gd`
Add Suite 6 cleanly into `test_runner.gd`:
```gdscript
const TestInteraction = preload("res://tests/suites/test_interaction.gd")

# Inside _initialize():
    # Suite 6: TestInteraction (T18, T27, T28 interaction, occlusion & input context)
    var suite_interaction := TestInteraction.new()
    if not suite_interaction.run_all():
        all_passed = false
```

---

## 5. Verification Method

To independently verify the recommendations:

1. **Verify Script Compilation:**
   ```powershell
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless --path . -s res://scripts/tools/build_player_scene.gd"
   ```
2. **Verify Headless Test Runner:**
   ```powershell
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless --path . --script res://tests/test_runner.gd > test_out.txt 2>&1" ; Get-Content test_out.txt ; Remove-Item test_out.txt
   ```
   *Expected:* All suites pass with exit code 0; zero script parse errors.
3. **Verify File Layout Compliance:**
   - Scene: `scenes/ui/interaction_prompt.tscn`
   - UI Script: `scripts/ui/interaction_prompt.gd`
   - Context Script: `scripts/core/input_manager.gd`
   - Test Suite: `tests/suites/test_interaction.gd`
   - Metadata files only under `.agents/teamwork/`
4. **Invalidation Conditions:**
   - If `collision_mask` is set to 4 only, occlusion test T27 will fail because walls on Layer 1 are ignored.
   - If `InteractableClass` is not preloaded, GDScript parse error occurs on headless execution.
   - If `mouse_filter` is not set to `MOUSE_FILTER_IGNORE` on UI prompt controls, viewport mouse clicks will be swallowed.
