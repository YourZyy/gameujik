# Handoff Report — explorer_book_001_r2_2

## 1. Observation

### Empirical Defect Reproduction
Execution of the stress harness `.agents/teamwork/challenger_book_001_2/stress_hud_context.gd` via Godot 4.7.2 headless CLI (`cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s .agents/teamwork/challenger_book_001_2/stress_hud_context.gd"`):
- Total Assertions: 109
- Passed: 108
- Failed: 1 (Assertion 5.1)
- Verbatim Failure Output:
  ```text
  --- SUITE 5: Main Scene Input Dispatch Empirical Challenge ---
    [5.1] EMPIRICAL CHALLENGE: Dispatching 'open_book' (hotkey B) input event to main.tscn...
      Observed State after hotkey 'B': Context = 0 (expected 1/BOOK), BookUI.visible = false (expected true)
    [ASSERT FAIL] 5.1 Hotkey B opens and keeps BookUI visible in main.tscn -> DEFECT DETECTED: Book opened and closed on same frame (Context=0, BookUI.visible=false)
    [5.2] Testing Esc (pause_menu) close when book is open in main.tscn...
  ```

### Code Observations

1. **`scripts/main.gd` lines 60–70**:
   ```gdscript
   func _unhandled_input(event: InputEvent) -> void:
   	if event.is_action_pressed("open_book") and not event.is_echo():
   		var im = get_node_or_null("/root/InputManager")
   		if im != null:
   			if im.get_current_context() == im.ContextMode.BOOK:
   				if book_ui and book_ui.has_method("close_book"):
   					book_ui.close_book()
   			elif im.is_world_context():
   				if book_ui and book_ui.has_method("open_book"):
   					book_ui.open_book()
   ```
   Direct observation:
   - `_unhandled_input` intercepts `open_book`.
   - When in world context, it invokes `book_ui.open_book()`.
   - **Crucially missing**: It NEVER calls `get_viewport().set_input_as_handled()`.
   - Notice that `main.gd` has NO handler for `open_inventory` (Tab) or `pause_menu` (Esc); only `open_book` was added here.

2. **`scripts/main.gd` lines 99–105**:
   ```gdscript
   func _on_book_family_interacted(_player_node: Node3D) -> void:
   	var im = get_node_or_null("/root/InputManager")
   	if im and im.has_method("push_context"):
   		im.push_context(im.ContextMode.BOOK)
   	if book_ui and book_ui.has_method("open_book"):
   		book_ui.open_book()
   ```
   Direct observation:
   - Does NOT check `im.is_world_context()` before pushing `BOOK`.
   - Redundantly invokes both `im.push_context(im.ContextMode.BOOK)` AND `book_ui.open_book()`.
   - In `book_ui.gd:58-68`, `_on_context_changed` ALREADY calls `open_book()` when `new_context == ContextMode.BOOK`. Therefore, calling `book_ui.open_book()` in line 104 causes duplicate execution (refresh, focus grabbing).

3. **`scripts/core/input_manager.gd` lines 178–199**:
   ```gdscript
   func _unhandled_input(event: InputEvent) -> void:
   	if is_world_context():
   		if event.is_action_pressed("pause_menu") and not event.is_echo():
   			push_context(ContextMode.PAUSE)
   			get_viewport().set_input_as_handled()
   		elif event.is_action_pressed("open_book") and not event.is_echo():
   			push_context(ContextMode.BOOK)
   			get_viewport().set_input_as_handled()
   		elif event.is_action_pressed("open_inventory") and not event.is_echo():
   			push_context(ContextMode.STORAGE)
   			get_viewport().set_input_as_handled()
   	else:
   		if event.is_action_pressed("pause_menu") and not event.is_echo():
   			consume_and_close(&"pause_menu")
   			get_viewport().set_input_as_handled()
   		elif event.is_action_pressed("open_book") and get_current_context() == ContextMode.BOOK and not event.is_echo():
   			consume_and_close(&"open_book")
   			get_viewport().set_input_as_handled()
   		elif event.is_action_pressed("open_inventory") and get_current_context() == ContextMode.STORAGE and not event.is_echo():
   			consume_and_close(&"open_inventory")
   			get_viewport().set_input_as_handled()
   ```
   Direct observation:
   - `InputManager` is already designed as the centralized input context manager.
   - It handles `open_book` in both directions: pushing `BOOK` when in `WORLD`, and calling `consume_and_close(&"open_book")` when in `BOOK`.
   - Every branch calls `get_viewport().set_input_as_handled()`.

4. **`scripts/ui/book_ui.gd` lines 58–68, 79–100, 197–203**:
   ```gdscript
   func _on_context_changed(new_context: int, _prev_context: int) -> void:
   	var im := _get_input_manager()
   	if im == null:
   		return
   	if new_context == im.ContextMode.BOOK:
   		if not visible:
   			open_book()
   	else:
   		if visible:
   			visible = false
   ...
   func open_book() -> void:
   	visible = true
   	var im := _get_input_manager()
   	if im != null and im.has_method("push_context"):
   		if im.get_current_context() != im.ContextMode.BOOK:
   			im.push_context(im.ContextMode.BOOK)

   	refresh_ui()

   	if track_button != null and track_button.is_inside_tree():
   		track_button.grab_focus()

   func close_book() -> void:
   	visible = false
   	var im := _get_input_manager()
   	if im != null:
   		if im.get_current_context() == im.ContextMode.BOOK:
   			if im.has_method("consume_and_close"):
   				im.consume_and_close(&"open_book")
   			elif im.has_method("pop_context"):
   				im.pop_context()
   ...
   func _unhandled_input(event: InputEvent) -> void:
   	if not visible:
   		return
   	if event.is_action_pressed("open_book") or event.is_action_pressed("pause_menu"):
   		close_book()
   		get_viewport().set_input_as_handled()
   ```
   Direct observation:
   - `_unhandled_input` in `book_ui.gd` unconditionally checks `if event.is_action_pressed("open_book") or event.is_action_pressed("pause_menu")` whenever `visible` is true, without verifying if `im.get_current_context() == ContextMode.BOOK`.
   - If an overlay like `PAUSE` is open over `BOOK`, `book_ui.gd` would intercept Esc before `InputManager`, breaking modal hierarchy.

5. **`scripts/ui/inventory_ui.gd` (Reference Pattern)**:
   - Does NOT implement `_unhandled_input` at all.
   - Listens purely to `im.context_changed` in `_on_context_changed`.
   - Relies completely on `InputManager` for hotkey `open_inventory` (Tab) and `pause_menu` (Esc).
   - In `scripts/main.gd`, there is zero inventory code in `_unhandled_input`.
   - Result: 100% stable, 0 desync, 0 bounce across 100 rapid toggles and stress tests.

---

## 2. Logic Chain

1. **Input Propagation Order in Godot**:
   - In Godot 4, `_unhandled_input(event)` propagates through nodes in reverse tree order.
   - Autoload singletons (like `/root/InputManager`) are loaded as top-level children of `/root` *before* the active scene (`/root/Main`).
   - Consequently, in reverse order, `/root/Main` receives `_unhandled_input` *before* `/root/InputManager`.

2. **The "Instant Bounce" Double-Transition Mechanism (DEFECT-BOOK-01)**:
   - **Step A**: Player in WORLD context presses hotkey 'B' (`open_book`).
   - **Step B**: `/root/Main._unhandled_input` catches `open_book`. It sees `im.is_world_context() == true` and calls `book_ui.open_book()`.
   - **Step C**: `book_ui.open_book()` calls `im.push_context(ContextMode.BOOK)`.
   - **Step D**: `InputManager` appends `BOOK` to `_context_stack`. Current context is now `ContextMode.BOOK`. Signals `context_pushed` and `context_changed` are emitted.
   - **Step E**: `Main._unhandled_input` finishes execution, but **omitted `get_viewport().set_input_as_handled()`**.
   - **Step F**: Because the event was not consumed, the SAME input event propagates down the chain to `/root/InputManager._unhandled_input()`.
   - **Step G**: `InputManager` inspects the event. `is_world_context()` is now `false` (context became `BOOK` in Step D).
   - **Step H**: `InputManager` enters the `else:` branch:
     `elif event.is_action_pressed("open_book") and get_current_context() == ContextMode.BOOK and not event.is_echo():`
     This evaluates to **TRUE**!
   - **Step I**: `InputManager` immediately executes `consume_and_close(&"open_book")`.
   - **Step J**: `_context_stack` pops `BOOK` back to `WORLD`. `book_ui.visible` becomes `false`.
   - **Step K**: The book was pushed and popped in the exact same event loop on the exact same frame. The book appears to "bounce" shut instantly without ever staying visible.

3. **Landmark Interaction Redundancy & Exclusivity Risk**:
   - When player interacts with `book_family` on the house table, `_on_book_family_interacted` in `main.gd` executes:
     `im.push_context(im.ContextMode.BOOK)` followed by `book_ui.open_book()`.
   - `im.push_context` triggers `im.context_changed`, which invokes `BookUI._on_context_changed` -> `book_ui.open_book()`.
   - Then `main.gd` immediately calls `book_ui.open_book()` a second time.
   - Furthermore, `_on_book_family_interacted` does not check `im.is_world_context()`. According to PRD FR02 and UI_UX.md § 4 ("Satu panel aktivitas utama terbuka pada satu waktu"), interacting while in an active modal must not stack panels.

4. **Triplicate Handling Architectural Conflict**:
   - Currently, THREE separate scripts attempt to handle `open_book`:
     1. `scripts/main.gd`
     2. `scripts/ui/book_ui.gd`
     3. `scripts/core/input_manager.gd`
   - By contrast, `open_inventory` (Tab) and `pause_menu` (Esc) follow the single-source-of-truth pattern in `scripts/core/input_manager.gd`, with `InventoryUI` simply responding to `context_changed`.
   - Adopting the canonical centralized pattern for `BookUI` eliminates the conflict at the root.

---

## 3. Caveats

- **Scope constraint**: This report is produced under read-only investigation mandates. No source code modifications were performed in `scripts/`.
- **Alternative considered**: Adding `get_viewport().set_input_as_handled()` inside `scripts/main.gd:60-70`.
  - While this stops the bounce in `main.tscn`, it preserves architectural debt: `main.gd` remains tightly coupled to `open_book` (while ignoring `open_inventory`), and any scene instantiated without `main.gd` (e.g. standalone test harness or isolated level) would behave inconsistently.
  - The canonical solution (removing redundant handler in `main.gd` and letting `InputManager` route all modal shortcuts) is strictly superior and aligns with Godot and `game-ui-ux` skill standards.
- **Assumptions**: Assumes `InputManager` remains registered as an autoload singleton in `project.godot` (which is already configured at `*res://scripts/core/input_manager.gd`).

---

## 4. Conclusion & Recommendations

### Proposed Architecture: Centralized Context Lifecycle for BookUI

To guarantee that opening via hotkey B or table landmark `book_family` is **idempotent**, **modal-exclusive**, and **never bounces**:

#### 1. In `scripts/main.gd`:
- **Remove** lines 60–70 (`_unhandled_input` handler) entirely. `scripts/main.gd` should not intercept modal toggles.
- **Update** `_on_book_family_interacted` (lines 99–105) to check world context and eliminate the duplicate call:
  ```gdscript
  func _on_book_family_interacted(_player_node: Node3D) -> void:
  	var im = get_node_or_null("/root/InputManager")
  	if im != null and im.is_world_context():
  		im.push_context(im.ContextMode.BOOK)
  ```
  *(Pushing context automatically triggers `context_changed`, which opens `BookUI` idempotently without duplicate calls).*

#### 2. In `scripts/ui/book_ui.gd`:
- **Remove** redundant `_unhandled_input` (lines 197–203). Input routing is already fully handled by `InputManager._unhandled_input()`.
- **Make `open_book()` strictly idempotent**:
  ```gdscript
  func open_book() -> void:
  	if visible:
  		return
  	visible = true
  	var im := _get_input_manager()
  	if im != null and im.has_method("push_context"):
  		if im.get_current_context() != im.ContextMode.BOOK:
  			im.push_context(im.ContextMode.BOOK)

  	refresh_ui()

  	if track_button != null and track_button.is_inside_tree():
  		track_button.grab_focus()
  ```
- **Make `close_book()` strictly idempotent**:
  ```gdscript
  func close_book() -> void:
  	if not visible:
  		return
  	visible = false
  	var im := _get_input_manager()
  	if im != null and im.get_current_context() == im.ContextMode.BOOK:
  		if im.has_method("consume_and_close"):
  			im.consume_and_close(&"open_book")
  		elif im.has_method("pop_context"):
  			im.pop_context()
  ```

#### 3. Modal Exclusivity & Bounce Elimination Guarantee Matrix:
| Trigger | Context State | Resulting Behavior |
|---|---|---|
| Hotkey B in WORLD | `WORLD` | `InputManager` pushes `BOOK`, calls `set_input_as_handled()`. `BookUI` opens, simulation pauses, player locomotion gates. Zero bounce. |
| Hotkey B in BOOK | `BOOK` | `InputManager` calls `consume_and_close(&"open_book")`, calls `set_input_as_handled()`. Context pops to `WORLD`, frame guard active. Zero bounce. |
| Hotkey B in STORAGE / KITCHEN | `STORAGE` / `KITCHEN` | Ignored by `InputManager`. Modal exclusivity preserved; does not stack book on top. |
| Table Landmark E in WORLD | `WORLD` | `im.push_context(BOOK)` runs. `context_changed` opens `BookUI`. Zero bounce. |
| Table Landmark E in Modal | `!= WORLD` | Interaction detector is disabled / rejected by `can_interact_in_world()`. `_on_book_family_interacted` guarded by `is_world_context()`. Idempotent. |
| Esc (`pause_menu`) in BOOK | `BOOK` | `InputManager` calls `consume_and_close(&"pause_menu")`. Context pops to `WORLD`, `BookUI` closes. |
| CloseButton `[X]` in BOOK | `BOOK` | Calls `close_book()`, which invokes `im.consume_and_close(&"open_book")`. Context pops to `WORLD`. |

---

## 5. Verification Method

To verify the implementation of these recommendations:

1. **Run Challenger Stress Harness**:
   ```powershell
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s .agents/teamwork/challenger_book_001_2/stress_hud_context.gd"
   ```
   - **Expected Outcome**: All 109 assertions pass (109/109), 0 defects detected, exit code 0.
   - **Invalidation condition**: If Assertion 5.1 fails or context reverts to 0 on hotkey B, bounce defect persists.

2. **Run Full Test Suite Runner**:
   ```powershell
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"
   ```
   - **Expected Outcome**: All 749 assertions across 8 test suites pass with exit code 0.

3. **Inspect Target Files**:
   - `scripts/main.gd`: Confirm lines 60–70 are removed, and `_on_book_family_interacted` checks `im.is_world_context()` without duplicate `book_ui.open_book()`.
   - `scripts/ui/book_ui.gd`: Confirm idempotency guards in `open_book()` and `close_book()`, and removal of conflicting `_unhandled_input()`.
