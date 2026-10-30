# Architectural Analysis: Tool Mutations and Active Hold Invariants (DEFECT-GARD-01)

**Investigator:** `explorer_gard_001_r2_2`  
**Milestone:** GARD-001 Remediation  
**Scope:** `scripts/player/player_controller.gd`, `scripts/gardening/garden_manager.gd`, `scripts/gardening/hold_action_controller.gd`  
**Date:** 2026-10-27T18:42:00Z  

---

## 1. Executive Summary

Empirical challenge by `challenger_gard_001_1` identified **DEFECT-GARD-01** during adversarial stress testing (`tests/stress_hold_actions.gd`), causing 6 assertion failures in Challenge 5. While core underlying systems (`HoldActionController`, `GardenManager`, and `InventoryManager`) passed 1,673 adversarial stress tests with zero defects, an input routing vulnerability in `PlayerController._update_hold_action()` causes `HoldActionController` to enter a zombie holding state (`State.HOLDING` with frozen progress) when:
1. The player swings their camera crosshair directly from one valid landmark to another (e.g. `landmark_plot` to `landmark_water`, or vice versa) while holding an action button (`interact` or `action_tool_use`).
2. An external system (UI toolbar click, script call, or automated test) mutates `GardenManager.active_tool` while the player is holding LMB on a garden plot.

This analysis evaluates the architectural invariants, traces all mutation pathways, compares three compatibility validation architectures, and provides a verified, non-intrusive remediation plan for the implementer agent.

---

## 2. In-Depth Root Cause & Pathway Analysis

### 2.1 State Flow in `PlayerController._update_hold_action()`

In `scripts/player/player_controller.gd` (lines 342–408), hold action updates are structured as follows:

```gdscript
	# 1. Refill watering can at water_home (2.0s hold E)
	if target_id == "landmark_water":
		if hold_controller.is_holding() and hold_controller.action_id == "refill":
			hold_controller.tick(delta, is_interact_pressed, target_id == "landmark_water")
		elif is_interact_just_pressed and not hold_controller.is_active():
			if gm != null and gm.can_refill_water()["success"]:
				hold_controller.start("refill", "water_home", 2.0, &"interact")

	# 2. Plot actions at plot_home_01 (tool hold or seed plant)
	elif target_id == "landmark_plot":
		if active_tool == "tool_seed":
			...
		elif active_tool == "tool_hoe":
			if hold_controller.is_holding() and hold_controller.action_id == "hoe":
				hold_controller.tick(delta, is_lmb_pressed, target_id == "landmark_plot")
			elif is_lmb_just_pressed and not hold_controller.is_active() and is_mouse_captured():
				...
		elif active_tool == "tool_fertilizer":
			if hold_controller.is_holding() and hold_controller.action_id == "fertilize":
				hold_controller.tick(delta, is_lmb_pressed, target_id == "landmark_plot")
			...
		elif active_tool == "tool_watering_can":
			if hold_controller.is_holding() and hold_controller.action_id == "water":
				hold_controller.tick(delta, is_lmb_pressed, target_id == "landmark_plot")
			...
		else:
			if hold_controller.is_holding():
				hold_controller.cancel()
	else:
		if hold_controller.is_holding():
			hold_controller.cancel()
```

### 2.2 Why Target Swapping Freezes the Hold Controller (Sub-tests 5.4 & 5.5)

Consider the scenario where the player is holding LMB with `tool_hoe` on `landmark_plot`:
- `hold_controller.state` = `State.HOLDING`
- `hold_controller.action_id` = `"hoe"`
- `hold_controller.target_id` = `"plot_home_01"`

When the camera rapidly moves so that the crosshair intersects `landmark_water`:
1. `target_id` becomes `"landmark_water"`.
2. The top-level `if target_id == "landmark_water":` matches (line 371).
3. Line 372 evaluates `hold_controller.action_id == "refill"`. This is `false` (`"hoe" != "refill"`).
4. Line 374 evaluates `not hold_controller.is_active()`. This is `false` (`hold_controller.is_active()` is `true`).
5. **No branch executes**. There is no `else` inside the `landmark_water` block.
6. The outer `else` on line 404 is skipped because line 371 was taken.
7. Consequently:
   - `hold_controller.tick(...)` is NOT called.
   - `hold_controller.cancel()` is NOT called.
   - `HoldActionController` remains in `State.HOLDING` with frozen timer.
   - The HUD progress bar remains visible and frozen.
   - Releasing LMB while looking at `landmark_water` does not register because `landmark_water` only checks `is_interact_pressed` (for E).
   - If the player aims back at `landmark_plot`, `hold_controller.is_active()` is still `true`, blocking any new action or resuming the previous action from a corrupt state.

Symmetrically, if refilling water at `landmark_water` (`action_id == "refill"`) and the crosshair moves onto `landmark_plot`, none of the plot tool branches match `"refill"`, bypassing cancellation completely (Sub-test 5.5).

### 2.3 Why External Tool Mutations Freeze the Hold Controller (Sub-test 5.6)

Consider the scenario where the player is aiming at `landmark_plot` with `tool_hoe` and holding LMB (`action_id == "hoe"`):
- An external caller invokes `GardenManager.select_tool("tool_fertilizer")` (e.g. via UI button click).
- On the next physics tick, `active_tool` is `"tool_fertilizer"`.
- `target_id` is still `"landmark_plot"`.
- Execution enters `elif active_tool == "tool_fertilizer":`.
- Line 390 evaluates `hold_controller.action_id == "fertilize"`. This is `false` (`"hoe" != "fertilize"`).
- Line 392 evaluates `not hold_controller.is_active()`. This is `false`.
- No branch matches.
- The `else:` on line 401 is NOT executed because `active_tool == "tool_fertilizer"` matched an existing `elif`.
- Result: `hold_controller` is neither ticked nor cancelled, freezing in `State.HOLDING` indefinitely.

---

## 3. Tool Mutation Pathways & Invariants

| Mutation Channel | Trigger Mechanism | Current Behavior | Defect? | Required Invariant |
|---|---|---|---|---|
| **Keyboard Hotkeys (1–4)** | `_unhandled_input` -> `_handle_tool_toggle(tool_id)` | Calls `hold_controller.cancel()` before `gm.select_tool()` | No (Safe) | Hold must abort immediately on tool toggle |
| **Tool Cancel Action** | `_unhandled_input` (`action_tool_cancel` / RMB) | Calls `hold_controller.cancel()` | No (Safe) | Hold must abort immediately on cancel |
| **UI Context Change** | `_update_hold_action` (`not im.is_world_context()`) | Calls `hold_controller.cancel()` | No (Safe) | Hold must abort when opening menus/inventory |
| **Looking into Void** | `_update_hold_action` (`target_id == ""`) | Outer `else` calls `hold_controller.cancel()` | No (Safe) | Hold must abort when looking away into empty space |
| **Target Swapping** | Crosshair moves `plot -> water` or `water -> plot` | Top-level branch matches new target, inner condition fails, fallthrough skipped | **YES (Softlock)** | **Hold must abort immediately if crosshair leaves current target** |
| **External Tool Change** | `GardenManager.select_tool()` via UI/script | Plot branch matches new tool, inner condition fails, `else` skipped | **YES (Softlock)** | **Hold must abort immediately if active tool is incompatible with active hold action** |

---

## 4. Architectural Evaluation of Compatibility Validation Strategies

We investigated three possible architectural approaches to enforce compatibility:

### Strategy A: Pure Signal-Driven Hook (`GardenManager.active_tool_changed`)
- **Concept:** In `PlayerController._ready()`, connect `gm.active_tool_changed` to `func(_tool): hold_controller.cancel()`.
- **Evaluation:**
  - Addresses tool mutation via `GardenManager`.
  - **Does NOT address target swapping** (Sub-tests 5.4 and 5.5), because camera movement does not change `active_tool`.
  - Fragile if `GardenManager` is instantiated/mocked dynamically in test harnesses after player initialization.
- **Verdict:** Insufficient as a standalone solution. Useful only as an auxiliary defensive measure.

### Strategy B: Internalizing Target/Tool Knowledge in `HoldActionController`
- **Concept:** Pass target IDs and tool requirements into `HoldActionController` and have it query singletons or hold entity references.
- **Evaluation:**
  - Strongly violates the Single Responsibility Principle (SRP).
  - Couples a pure, engine-neutral, `RefCounted` state machine to game-specific scene tree nodes (`GardenManager`, `landmark_water`, `landmark_plot`).
  - Degrades reusability of `HoldActionController` for future systems (e.g. cooking stirring in COOK-001 or wood-cutting in WORLD-001).
  - `HoldActionController` already provides a clean `tick(delta, is_button_pressed, is_target_valid)` contract.
- **Verdict:** Architectural Anti-pattern. Should NOT be adopted.

### Strategy C: Frame-Deterministic Compatibility Validation in `PlayerController`
- **Concept:** At the entry of `PlayerController._update_hold_action()`, evaluate whether the ongoing hold action matches the current `target_id` and `active_tool`. If incompatible, cancel immediately.
- **Evaluation:**
  - `PlayerController` is the exact owner of the interaction raycast (`interaction_detector`), the input state, and the active tool query.
  - Guarantees 100% deterministic validation every frame regardless of how the state changed (camera rotation, hotkey, UI click, script call, or network event).
  - Completely resolves Sub-tests 5.4, 5.5, and 5.6 in a single unified checkpoint.
  - Leaves `HoldActionController` completely pure and decoupled.
- **Verdict:** **Optimal Architectural Strategy**.

---

## 5. Evaluation of Challenger's Proposed Implementation

Challenger `challenger_gard_001_1` proposed the following guard:

```gdscript
	# Cancel active hold immediately if target or active tool is no longer compatible
	if hold_controller.is_holding():
		var is_compat := false
		if hold_controller.action_id == "refill":
			is_compat = (target_id == "landmark_water")
		elif target_id == "landmark_plot":
			match hold_controller.action_id:
				"hoe": is_compat = (active_tool == "tool_hoe")
				"fertilize": is_compat = (active_tool == "tool_fertilizer")
				"water": is_compat = (active_tool == "tool_watering_can")
		if not is_compat:
			hold_controller.cancel()
```

### 5.1 Verification Against All State Machine Invariants

1. **`State.MUST_RELEASE` Protection (Challenge 3)**:
   - Does this guard interfere with re-trigger protection?
   - In `HoldActionController`:
     - `is_holding()` is defined as `state == State.HOLDING`.
     - In `State.MUST_RELEASE`, `is_holding()` returns `false` (only `is_active()` returns `true`).
   - Therefore, when an action commits, the guard does NOT touch `MUST_RELEASE`. The player must still release the button to return to `IDLE`.
   - Continuous LMB press past commit remains strictly 1 commit with 0 duplicate triggers.

2. **Rapid Cancellation & Zero Resource Deduction (Challenge 2 & 4)**:
   - When the guard cancels via `hold_controller.cancel()`, `elapsed_time` is zeroed and `hold_cancelled` is emitted.
   - Neither `InventoryManager` nor `GardenManager` deducts seeds, compost, fertilizer, or water.

3. **Placement within `_update_hold_action()`**:
   - The guard must be placed **after** the `InputManager.is_world_context()` check and **after** retrieving `target_id` and `active_tool`, but **before** the target-specific branching logic.
   - Placing it immediately after lines 360–368 (the `MUST_RELEASE` handler) ensures `MUST_RELEASE` handles button release cleanly first.

### 5.2 Recommended Refactoring: Encapsulated Compatibility Helper

To enhance readability and ensure clean extensibility for future milestones (COOK-001 and WORLD-001), we recommend extracting the compatibility logic into a dedicated private helper function:

```gdscript
func _is_hold_action_compatible(action: String, target: String, tool: String) -> bool:
	match action:
		"refill":
			return target == "landmark_water"
		"hoe":
			return target == "landmark_plot" and tool == "tool_hoe"
		"fertilize":
			return target == "landmark_plot" and tool == "tool_fertilizer"
		"water":
			return target == "landmark_plot" and tool == "tool_watering_can"
		_:
			return false
```

In `_update_hold_action(delta: float)`:
```gdscript
	# Cancel active hold immediately if target or active tool is no longer compatible
	if hold_controller.is_holding():
		if not _is_hold_action_compatible(hold_controller.action_id, target_id, active_tool):
			hold_controller.cancel()
```

---

## 6. Proposed Code Changes for Implementer

### Target File: `scripts/player/player_controller.gd`

#### Change 1: Add Helper Function `_is_hold_action_compatible`
Add right before `_update_hold_action(delta: float)`:
```gdscript
func _is_hold_action_compatible(action: String, target: String, tool: String) -> bool:
	match action:
		"refill":
			return target == "landmark_water"
		"hoe":
			return target == "landmark_plot" and tool == "tool_hoe"
		"fertilize":
			return target == "landmark_plot" and tool == "tool_fertilizer"
		"water":
			return target == "landmark_plot" and tool == "tool_watering_can"
		_:
			return false
```

#### Change 2: Add Compatibility Check in `_update_hold_action`
In `_update_hold_action(delta: float)` (around line 369, right after the `MUST_RELEASE` block):
```gdscript
	if hold_controller.state == HoldActionControllerClass.State.MUST_RELEASE:
		var button_still_down := false
		if hold_controller.button_name == &"action_tool_use":
			button_still_down = is_lmb_pressed
		elif hold_controller.button_name == &"interact":
			button_still_down = is_interact_pressed
		hold_controller.tick(delta, button_still_down, true)
		_was_lmb_pressed = is_lmb_pressed
		return

	# Invariant Check: Cancel active hold if target or active tool is no longer compatible
	if hold_controller.is_holding():
		if not _is_hold_action_compatible(hold_controller.action_id, target_id, active_tool):
			hold_controller.cancel()
```

---

## 7. Verification Method

Once applied by the implementer:
1. **Adversarial Stress Test Suite**:
   ```cmd
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/stress_hold_actions.gd"
   ```
   **Expected Outcome:**
   - Exit code: `0`
   - Assertions Passed: `1679` (all 6 previously failing assertions in Challenge 5 pass)
   - Assertions Failed: `0`
   - Verdict: `CONFIRMED CORRECT`

2. **Main Project Test Runner**:
   ```cmd
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"
   ```
   **Expected Outcome:**
   - Exit code: `0`
   - All suites pass (at least 936 assertions passed, 0 failed).

3. **Invalidation Conditions**:
   - Any regression in Challenge 1–4, Challenge 6, or existing `test_runner.gd` suites.
   - Any scenario where swapping targets while holding LMB leaves `hold_controller.is_active() == true`.
