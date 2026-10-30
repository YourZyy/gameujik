# Handoff Report: Context & Input Mode Manager Architecture (INT-001)

## 1. Observation

Direct observations from the codebase, project settings, specification documents, and gamedev skills:

1. **Input Actions in `project.godot`:**
   Lines 38–79 of `project.godot` define the core input map:
   - `move_forward`: Key W (physical_keycode 87)
   - `move_backward`: Key S (physical_keycode 83)
   - `move_left`: Key A (physical_keycode 65)
   - `move_right`: Key D (physical_keycode 68)
   - `interact`: Key E (physical_keycode 69)
   - `open_book`: Key B (physical_keycode 66)
   - `open_inventory`: Key Tab (physical_keycode 4194306)
   - `pause_menu`: Key Escape (physical_keycode 4194305)
   Currently, there are **no Autoloads** configured in `project.godot` under `[autoload]`.

2. **Existing Player Input Gating in `scripts/player/player_controller.gd`:**
   - Lines 13 & 16: `@export var movement_enabled: bool = true` and `@export var look_enabled: bool = true`.
   - Lines 73–85: `capture_mouse()`, `release_mouse()`, and `is_mouse_captured() -> bool` (with headless detection via `DisplayServer.get_name() == "headless"`).
   - Lines 86–96 in `_unhandled_input(event: InputEvent)`:
     ```gdscript
     if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
         if not is_mouse_captured():
             capture_mouse()
             get_viewport().set_input_as_handled()
             return
     if event.is_action_pressed("pause_menu"):
         release_mouse()
         return
     ```
     *Critical vulnerability observed*: When not captured, any left-click automatically recaptures the mouse. If a modal UI is open and the player clicks a UI element, an unhandled click could inadvertently recapture the mouse into the 3D world unless guarded by an active context check. Furthermore, `pause_menu` simply calls `release_mouse()` without pushing a pause context or consuming the event.
   - Lines 102–103: `if not look_enabled: return` suppresses mouse look yaw and pitch.
   - Lines 161–163: `if movement_enabled:` calculates WASD velocity; otherwise defaults to `Vector2.ZERO`.

3. **Domain Specifications (`docs/PROTOTYPE.md` § 5 & `docs/UI_UX.md` § 3–4):**
   - `PROTOTYPE.md` § 5 ("Kontrak waktu dan input"):
     - `Dunia` (WORLD): Player moves = Yes, Growth/Day = Running, Cooking Job = Not running when panel closed, Mouse = Captured.
     - `Buku, tas, peti, dialog, inspeksi penuh` (BOOK, STORAGE, DIALOGUE): Player moves = No, Simulation = Paused, Cooking Job = Paused, Mouse = Visible.
     - `Dapur aktif` (KITCHEN): Player moves = No, Simulation = Running, Cooking Job = Running (cooking stage), Mouse = Visible.
     - `Pause/pengaturan` (PAUSE): Player moves = No, Simulation = Paused, Cooking Job = Paused, Mouse = Visible.
     - Line 68: *"Tombol penutup menu dan tombol aksi harus dilepas sebelum dapat memicu dunia. Memegang klik ketika berpindah alat/menu tidak langsung memakai sumber daya."*
   - `UI_UX.md` § 4 ("Konteks input dan fokus"):
     - *"Satu panel aktivitas utama terbuka pada satu waktu. Konfirmasi berada di atas panel tersebut, lalu Esc menutup konfirmasi dulu."*
     - *"Saat panel terbuka, gerak/pandang/alat dunia berhenti dan mouse bebas. Saat kembali, kunci mouse setelah input penutup dilepas."*
     - *"Pause dapat dibuka dari dapur tanpa memulai proses kedua."*
   - `TASKS.md` (INT-001):
     - *"Konteks dunia/panel/pause melepas mouse dan mencegah input bocor... Selesai bila panel dapat ditutup, dan input yang sama tidak mengambil/memakai alat ketika menu ditutup. T18/T27/T28."*

4. **Skills Best Practices (`input-systems`, `godot-signals-groups`, `godot-gdscript`):**
   - Actions over raw keys; discrete edge detection vs continuous level detection.
   - Decouple systems via typed signals (`signal context_changed(new_context: Context, old_context: Context)`).
   - Use `get_viewport().set_input_as_handled()` to prevent downstream event propagation.

---

## 2. Logic Chain

1. **Why Stack-Based Context Transitions Are Necessary:**
   - As observed in `UI_UX.md` § 4, modal panels can be nested (e.g., Player opens Kitchen modal -> presses Esc to open Pause menu or Settings -> presses Esc to close Pause and resume Kitchen).
   - A single state variable (e.g., `current_mode = WORLD`) loses the previous modal state when closing a nested child modal.
   - A stack `_context_stack: Array[Context] = [Context.WORLD]` models this hierarchy natively:
     - Root is permanently `[Context.WORLD]` (stack depth 1).
     - Opening Kitchen pushes `Context.KITCHEN` -> `[WORLD, KITCHEN]` (depth 2).
     - Opening Pause pushes `Context.PAUSE` -> `[WORLD, KITCHEN, PAUSE]` (depth 3).
     - Esc or clicking "Resume" pops `Context.PAUSE` -> stack returns to `[WORLD, KITCHEN]`. Active context is correctly `KITCHEN`, mouse remains visible, player movement remains disabled.
     - Closing Kitchen pops `Context.KITCHEN` -> stack returns to `[WORLD]` (depth 1). Only now does the active context return to `WORLD`, mouse recaptures, and player movement/look re-engages.

2. **Why Action Bleed-Through Occurs and How to Eliminate It:**
   - **Root Cause**: When a player presses `E` or `Esc` to close a modal menu, if the menu immediately closes in that frame and returns control to the 3D world:
     a. If the event is not consumed via `set_input_as_handled()`, Godot continues dispatching the `InputEventKey` to subsequent nodes in `_unhandled_input` (such as `InteractionDetector`).
     b. If any world interaction logic polls `Input.is_action_just_pressed("interact")`, the raw OS key state remains `true` for the entire process tick, causing an immediate world interaction on the exact frame the modal closed.
     c. If the player holds `E` or clicks a close button, holding the key down could trigger an interaction on frame 2.
   - **Multi-Layer Solution**:
     - *Layer 1 (Event Consumption)*: Every modal close event must call `get_viewport().set_input_as_handled()`.
     - *Layer 2 (Frame Guard)*: `InputManager` records `_last_closed_frame = Engine.get_process_frames()` upon popping back to `WORLD`. `InputManager.can_interact_in_world()` returns `false` during that frame.
     - *Layer 3 (Release Suppression)*: `InputManager.suppress_action_until_released(action_name)`. The closed action (e.g., `&"interact"`) is registered in `_suppressed_actions` and remains blocked until `Input.is_action_just_released(action_name)` or `not Input.is_action_pressed(action_name)`.

3. **Why `InputManager` Should Be Registered as an Autoload in `project.godot`:**
   - `InputManager` is a cross-cutting subsystem required by `PlayerController`, `InteractionDetector`, `HUD`, `BookUI`, `StorageUI`, `KitchenUI`, `DialogueUI`, and `PauseMenu`.
   - If managed inside a temporary node or inside `GameManager` (which has not yet been built), every caller would need fragile `get_parent()` or tree-search queries.
   - Registering `InputManager="*res://scripts/core/input_manager.gd"` as an Autoload singleton in `project.godot`:
     - Creates `/root/InputManager` at startup with global accessibility.
     - Preserves state across scene reloads.
     - Enables `process_mode = Node.PROCESS_MODE_ALWAYS` so context switching and pause handling function even when `get_tree().paused = true`.
     - Maintains Single Responsibility Principle (SRP): `InputManager` handles input modes and mouse state; `GameManager` (in later tasks) handles high-level quest/day cycle flow.

4. **Integration with `PlayerController`:**
   - `PlayerController` connects to `InputManager.context_changed` or can be registered via `InputManager.register_player(self)`.
   - When entering modal: `movement_enabled = false`, `look_enabled = false`, mouse unlocked (`Input.mouse_mode = Input.MOUSE_MODE_VISIBLE`).
   - When returning to `WORLD`: `movement_enabled = true`, `look_enabled = true`, mouse captured (`Input.mouse_mode = Input.MOUSE_MODE_CAPTURED`).
   - Fix in `PlayerController._unhandled_input`: Guard the LMB click-to-capture block: only capture mouse if `InputManager.is_world_context()` is `true`.

---

## 3. Caveats

1. **Headless Execution Compatibility:**
   - In automated test runners (`godot --headless`), OS mouse capture (`Input.MOUSE_MODE_CAPTURED`) is not physically applied by the display server. All mouse mode setters and assertions must inspect `DisplayServer.get_name() != "headless"` or query internal state flags (as already established in `player_controller.gd`).
2. **Tree Pause vs. Selective Simulation Pause:**
   - `PROTOTYPE.md` § 5 explicitly dictates that `KITCHEN` runs cooking and gardening simulation while player movement is halted, whereas `BOOK`, `STORAGE`, `DIALOGUE`, and `PAUSE` pause simulation.
   - If `get_tree().paused = true` is invoked indiscriminately, all nodes stop processing unless configured with `PROCESS_MODE_ALWAYS`.
   - Recommendation: `InputManager` provides `is_simulation_paused() -> bool` and emits `simulation_state_changed(is_paused: bool)`. For INT-001, simulation systems (coming in GARD-001 and COOK-001) will subscribe to this signal or check `InputManager.is_simulation_paused()`.
3. **Modal UI Scenes in Subsequent Milestones:**
   - Full UI scenes (`book_ui.tscn`, `kitchen_ui.tscn`, `inventory_ui.tscn`, `dialogue_ui.tscn`) will be constructed in INV-001, BOOK-001, COOK-001, etc.
   - In INT-001, `InputManager` must be fully implemented and tested with mock transitions, shortcuts (`B`, `Tab`, `Esc`), and a baseline pause toggle so all subsequent milestones simply plug into `InputManager.push_context()` / `InputManager.pop_context()`.

---

## 4. Conclusion & Architecture Specifications

### A. Context Mode Matrix

| Mode Enum | `is_world_context()` | `movement_enabled` | `look_enabled` | Mouse Mode | `is_simulation_paused()` | Allowed Actions |
|---|---|---|---|---|---|---|
| `WORLD` | `true` | `true` | `true` | `MOUSE_MODE_CAPTURED` | `false` | WASD, Look, E (interact), B (open book), Tab (open bag), Esc (pause) |
| `BOOK` | `false` | `false` | `false` | `MOUSE_MODE_VISIBLE` | `true` | UI focus navigation, B or Esc (close book) |
| `STORAGE` | `false` | `false` | `false` | `MOUSE_MODE_VISIBLE` | `true` | UI item transfer, Tab or Esc (close storage) |
| `KITCHEN` | `false` | `false` | `false` | `MOUSE_MODE_VISIBLE` | `false` | UI heat slider, prep hold, Esc (close/pause job) |
| `DIALOGUE` | `false` | `false` | `false` | `MOUSE_MODE_VISIBLE` | `true` | Dialogue option click, Esc or choice (close) |
| `PAUSE` | `false` | `false` | `false` | `MOUSE_MODE_VISIBLE` | `true` | Menu buttons (Resume, Save, Settings), Esc (resume) |

### B. `InputManager` Component Design (`scripts/core/input_manager.gd`)

```gdscript
class_name InputManager
extends Node

enum Context {
	WORLD,
	BOOK,
	STORAGE,
	KITCHEN,
	DIALOGUE,
	PAUSE
}

signal context_changed(new_context: Context, old_context: Context)
signal context_pushed(pushed_context: Context)
signal context_popped(popped_context: Context)
signal simulation_state_changed(is_paused: bool)

var _context_stack: Array[Context] = [Context.WORLD]
var _player: PlayerController = null
var _suppressed_actions: Dictionary = {} # StringName -> bool
var _last_closed_frame: int = -1
var _mouse_captured_state: bool = true

@export var auto_pause_on_focus_loss: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sync_mouse_mode()

func register_player(player: PlayerController) -> void:
	_player = player
	_sync_player_gating()

func get_current_context() -> Context:
	if _context_stack.is_empty():
		return Context.WORLD
	return _context_stack.back()

func is_world_context() -> bool:
	return get_current_context() == Context.WORLD

func is_modal_active() -> bool:
	return not is_world_context()

func is_simulation_paused() -> bool:
	var ctx := get_current_context()
	return ctx in [Context.BOOK, Context.STORAGE, Context.DIALOGUE, Context.PAUSE]

func get_stack_depth() -> int:
	return _context_stack.size()

func push_context(mode: Context) -> void:
	if mode == Context.WORLD:
		return
	if get_current_context() == mode:
		return # Avoid duplicate modal push
	
	var old_mode := get_current_context()
	_context_stack.append(mode)
	
	_sync_mouse_mode()
	_sync_player_gating()
	
	context_pushed.emit(mode)
	context_changed.emit(mode, old_mode)
	simulation_state_changed.emit(is_simulation_paused())

func pop_context() -> Context:
	if _context_stack.size() <= 1:
		return Context.WORLD
	
	var popped := _context_stack.pop_back() as Context
	var new_mode := get_current_context()
	
	if new_mode == Context.WORLD:
		_last_closed_frame = Engine.get_process_frames()
	
	_sync_mouse_mode()
	_sync_player_gating()
	
	context_popped.emit(popped)
	context_changed.emit(new_mode, popped)
	simulation_state_changed.emit(is_simulation_paused())
	return popped

func pop_to_world() -> void:
	if _context_stack.size() <= 1:
		return
	while _context_stack.size() > 1:
		_context_stack.pop_back()
	_last_closed_frame = Engine.get_process_frames()
	_sync_mouse_mode()
	_sync_player_gating()
	context_changed.emit(Context.WORLD, Context.PAUSE)
	simulation_state_changed.emit(false)

func can_interact_in_world() -> bool:
	if not is_world_context():
		return false
	if Engine.get_process_frames() == _last_closed_frame:
		return false
	return true

func suppress_action_until_released(action: StringName) -> void:
	_suppressed_actions[action] = true

func is_action_suppressed(action: StringName) -> bool:
	if _suppressed_actions.has(action):
		if Input.is_action_just_released(action) or not Input.is_action_pressed(action):
			_suppressed_actions.erase(action)
			return false
		return true
	return false

func consume_and_close(action: StringName = &"") -> void:
	if action != &"":
		suppress_action_until_released(action)
	pop_context()

func _sync_mouse_mode() -> void:
	var in_world := is_world_context()
	_mouse_captured_state = in_world
	if DisplayServer.get_name() != "headless":
		if in_world:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _sync_player_gating() -> void:
	if not is_instance_valid(_player):
		return
	var in_world := is_world_context()
	_player.movement_enabled = in_world
	_player.look_enabled = in_world
	if in_world:
		_player.capture_mouse()
	else:
		_player.release_mouse()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if auto_pause_on_focus_loss and is_world_context():
			push_context(Context.PAUSE)

func _unhandled_input(event: InputEvent) -> void:
	if is_world_context():
		if event.is_action_pressed("pause_menu") and not event.is_echo():
			push_context(Context.PAUSE)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("open_book") and not event.is_echo():
			push_context(Context.BOOK)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("open_inventory") and not event.is_echo():
			push_context(Context.STORAGE)
			get_viewport().set_input_as_handled()
	else:
		if event.is_action_pressed("pause_menu") and not event.is_echo():
			consume_and_close(&"pause_menu")
			get_viewport().set_input_as_handled()
```

### C. Updates to `PlayerController` (`scripts/player/player_controller.gd`)

1. In `_ready()`: Connect to `InputManager` autoload if available:
   ```gdscript
   var im = get_node_or_null("/root/InputManager")
   if im and im.has_method("register_player"):
       im.register_player(self)
   ```
2. In `_unhandled_input(event)`: Guard the left-click mouse capture:
   ```gdscript
   if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
       var im = get_node_or_null("/root/InputManager")
       if im and not im.is_world_context():
           return # Do NOT recapture mouse while modal is active!
       if not is_mouse_captured():
           capture_mouse()
           get_viewport().set_input_as_handled()
           return
   ```
   Remove the standalone `if event.is_action_pressed("pause_menu"): release_mouse()` since `InputManager` coordinates this globally.

### D. Updates to `InteractionDetector` (`scripts/interaction/interaction_detector.gd`)

Add interaction execution trigger with bleed-through suppression:
```gdscript
func try_interact(player: Node3D) -> bool:
    var im = get_node_or_null("/root/InputManager")
    if im:
        if not im.can_interact_in_world():
            return false
        if im.is_action_suppressed(&"interact"):
            return false
    return interact_with_current(player)
```

---

## 5. Verification Method

### Concrete Test Cases for `tests/suites/test_interaction.gd` (T28 & T18):

1. **Stack Hierarchy & Push/Pop Order Test:**
   - Instantiate `InputManager.new()`.
   - Assert initial context is `Context.WORLD`, stack depth == 1.
   - Pop context -> Assert stack depth remains 1, context remains `Context.WORLD` (stack underflow protected).
   - Push `Context.KITCHEN` -> Assert context == `Context.KITCHEN`, stack depth == 2.
   - Push `Context.PAUSE` -> Assert context == `Context.PAUSE`, stack depth == 3.
   - Pop context -> Assert context returns to `Context.KITCHEN`, stack depth == 2.
   - Pop context -> Assert context returns to `Context.WORLD`, stack depth == 1.

2. **Simulation Pausing Rule Test:**
   - `WORLD` -> `is_simulation_paused() == false`.
   - `BOOK` -> `is_simulation_paused() == true`.
   - `STORAGE` -> `is_simulation_paused() == true`.
   - `KITCHEN` -> `is_simulation_paused() == false` (per PROTOTYPE § 5).
   - `DIALOGUE` -> `is_simulation_paused() == true`.
   - `PAUSE` -> `is_simulation_paused() == true`.

3. **Player Gating & Mouse Mode Synchronization Test:**
   - Attach mock/instantiated `PlayerController` to `InputManager.register_player(player)`.
   - In `WORLD`: `player.movement_enabled == true`, `player.look_enabled == true`.
   - Push `Context.BOOK`: `player.movement_enabled == false`, `player.look_enabled == false`, `_mouse_captured_state == false`.
   - Pop to `WORLD`: `player.movement_enabled == true`, `player.look_enabled == true`, `_mouse_captured_state == true`.

4. **Action Bleed-Through Prevention Test:**
   - Push `Context.BOOK`.
   - Simulate closing with `E`: call `consume_and_close(&"interact")`.
   - On the same frame: verify `can_interact_in_world() == false` (frame guard).
   - Verify `is_action_suppressed(&"interact") == true` (release suppression).
   - Simulate key release -> verify `is_action_suppressed(&"interact") == false`.

5. **Headless Project Verification Command:**
   Run from workspace root:
   ```powershell
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless --script res://tests/test_runner.gd"
   ```
   **Pass Condition:** All suites exit with code 0 and 0 failures.
