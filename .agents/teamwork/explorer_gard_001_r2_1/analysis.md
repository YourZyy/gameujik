# Technical Investigation & Architectural Recommendation: PlayerController Retargeting & Hold Lifecycle (DEFECT-GARD-01)

**Investigator:** explorer_gard_001_r2_1 (PlayerController Retargeting & Hold Lifecycle Explorer)  
**Date:** 2026-10-27T18:45:00Z  
**Context:** Milestone GARD-001 Remediation / Gate R2  
**Target File:** `scripts/player/player_controller.gd` (`_update_hold_action()`, lines 342–408)  
**Supporting Files:** `scripts/gardening/hold_action_controller.gd`, `tests/stress_hold_actions.gd`  

---

## 1. Executive Summary

During adversarial challenge of Milestone GARD-001 by `challenger_gard_001_1`, an empirical defect **DEFECT-GARD-01** was detected in `scripts/player/player_controller.gd`. Specifically, while the standalone `HoldActionController` state machine and `GardenManager` transactional logic passed all stress tests, `PlayerController._update_hold_action` failed 6 assertions in Challenge 5 (5.4, 5.5, and 5.6) of `tests/stress_hold_actions.gd`.

The failure occurs when an active hold action (e.g. hoeing at `landmark_plot` or refilling water at `landmark_water`) is held while the player's crosshair transitions directly to another valid interactive landmark, or when the active tool is changed externally. Because `_update_hold_action` is structured as a top-level `if/elif` dispatcher based on `target_id`, the branch for the new landmark matches, but the inner logic fails to tick or cancel the hold because the `action_id` does not match the new target. Consequently, the outer fallback `else` (line 404) is skipped, stranding `hold_controller` in a perpetual `State.HOLDING` zombie state with frozen progress and active HUD elements.

This investigation analyzes the mechanical root cause, evaluates the spatial and architectural context, and formulates two concrete architectural recommendations:
1. **Option 1 (Recommended Immediate Patch - Surgical Invariant Guard):** An active hold compatibility check placed immediately prior to target dispatch.
2. **Option 2 (Architectural Target State - Decoupled Lifecycle State Machine):** A clean 3-phase separation of Context/Input Gathering, Active Hold Servicing (Tick/Cancel), and Action Initiation (Start).

---

## 2. Empirical Defect Reproduction

### 2.1 Adversarial Harness Execution
- **Command:** `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/stress_hold_actions.gd"`
- **Result:** Exited with code `1`.
- **Failures Recorded:**
  ```text
  [RUN] Challenge 5: Tool Switching and Target Swapping under Active Hold
  [FAIL] Assertion failed: expected FALSE, got TRUE. 5.4: Swapping target to landmark_water must cancel active plot hold action
  [FAIL] Assertion failed: expected 0, got 1. 
  [FAIL] Assertion failed: expected FALSE, got TRUE. 5.5: Swapping target to landmark_plot must cancel active refill hold action
  [FAIL] Assertion failed: expected 0, got 1. 
  [FAIL] Assertion failed: expected FALSE, got TRUE. 5.6: External tool change must cancel active hold action
  [FAIL] Assertion failed: expected 0, got 1. 
  ==================================================
  [ADVERSARIAL_HARNESS] SUMMARY:
    Assertions Passed: 1673
    Assertions Failed: 6
    VERDICT: DEFECT DETECTED (Exit Code: 1)
  ==================================================
  ```

### 2.2 Baseline Regression Status
- **Command:** `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"`
  - **Result:** Exit code `0` (936 assertions passed across all 9 suites).
- **Command:** `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/stress_garden_invariants.gd"`
  - **Result:** Exit code `0` (340 assertions passed).

This confirms that the defect is not an underlying failure in `HoldActionController`, `GardenManager`, or `InventoryManager`, but strictly an input routing and lifecycle gating defect within `PlayerController._update_hold_action`.

---

## 3. Deep Architectural Root Cause Analysis

### 3.1 Code Structure Under Examination
In `scripts/player/player_controller.gd`:
```gdscript
342: func _update_hold_action(delta: float) -> void:
...
360: 	if hold_controller.state == HoldActionControllerClass.State.MUST_RELEASE:
361: 		var button_still_down := false
362: 		if hold_controller.button_name == &"action_tool_use":
363: 			button_still_down = is_lmb_pressed
364: 		elif hold_controller.button_name == &"interact":
365: 			button_still_down = is_interact_pressed
366: 		hold_controller.tick(delta, button_still_down, true)
367: 		_was_lmb_pressed = is_lmb_pressed
368: 		return
369: 
370: 	# 1. Refill watering can at water_home (2.0s hold E)
371: 	if target_id == "landmark_water":
372: 		if hold_controller.is_holding() and hold_controller.action_id == "refill":
373: 			hold_controller.tick(delta, is_interact_pressed, target_id == "landmark_water")
374: 		elif is_interact_just_pressed and not hold_controller.is_active():
375: 			if gm != null and gm.can_refill_water()["success"]:
376: 				hold_controller.start("refill", "water_home", 2.0, &"interact")
377: 
378: 	# 2. Plot actions at plot_home_01 (tool hold or seed plant)
379: 	elif target_id == "landmark_plot":
380: 		if active_tool == "tool_seed":
381: 			if is_lmb_just_pressed and is_mouse_captured():
382: 				_handle_plant_seed_on_plot()
383: 		elif active_tool == "tool_hoe":
384: 			if hold_controller.is_holding() and hold_controller.action_id == "hoe":
385: 				hold_controller.tick(delta, is_lmb_pressed, target_id == "landmark_plot")
386: 			elif is_lmb_just_pressed and not hold_controller.is_active() and is_mouse_captured():
387: 				if gm != null and gm.can_hoe_plot("plot_home_01")["success"]:
388: 					hold_controller.start("hoe", "plot_home_01", 2.0, &"action_tool_use")
389: 		elif active_tool == "tool_fertilizer":
390: 			if hold_controller.is_holding() and hold_controller.action_id == "fertilize":
391: 				hold_controller.tick(delta, is_lmb_pressed, target_id == "landmark_plot")
392: 			elif is_lmb_just_pressed and not hold_controller.is_active() and is_mouse_captured():
393: 				if gm != null and gm.can_fertilize_plot("plot_home_01")["success"]:
394: 					hold_controller.start("fertilize", "plot_home_01", 1.0, &"action_tool_use")
395: 		elif active_tool == "tool_watering_can":
396: 			if hold_controller.is_holding() and hold_controller.action_id == "water":
397: 				hold_controller.tick(delta, is_lmb_pressed, target_id == "landmark_plot")
398: 			elif is_lmb_just_pressed and not hold_controller.is_active() and is_mouse_captured():
399: 				if gm != null and gm.can_water_plot("plot_home_01")["success"]:
400: 					hold_controller.start("water", "plot_home_01", 2.0, &"action_tool_use")
401: 		else:
402: 			if hold_controller.is_holding():
403: 				hold_controller.cancel()
404: 	else:
405: 		if hold_controller.is_holding():
406: 			hold_controller.cancel()
```

### 3.2 Root Cause Breakdown

#### Mechanism 1: The "Branching-by-Target" Anti-Pattern for Stateful Input
The method `_update_hold_action` attempts to handle two fundamentally orthogonal responsibilities within a single nested conditional tree:
1. **Action Initiation (Transient Trigger):** "Is the player currently pointing at an interactable landmark and pressing an initiation key?"
2. **Action Maintenance / Progression (Continuous State):** "Is an action currently in progress, and are its ongoing validity invariants still satisfied?"

By making current spatial target (`target_id`) the top-level dispatch selector, the method implicitly presumes that moving away from a target will always transition through an unselected state (`target_id == ""`), which would hit line 404 (`else: if hold_controller.is_holding(): hold_controller.cancel()`).

#### Mechanism 2: Direct Spatial Transitions Across Adjacent Landmarks
In `scenes/world/level_graybox.tscn`, the garden plot `plot_home_01` is positioned at `(8, 0, 7)` and the water well `water_home` is at `(4, 0, 9)`. Both interactable collision areas occupy significant volume in the front yard.
When the player turns the first-person camera:
- In frame $N$: Raycast collides with `landmark_plot`. Hold action `"hoe"` starts.
- In frame $N+1$: Raycast swings directly onto `landmark_water` collision shape without any intermediate frame of empty ground.
- Top-level `if target_id == "landmark_water"` evaluates to `true`.
- Line 372 evaluates `hold_controller.action_id == "refill"`, which is `false` (it is `"hoe"`).
- Line 374 evaluates `not hold_controller.is_active()`, which is `false`.
- **Result:** Neither `tick()` nor `cancel()` is called. Outer `else` is completely bypassed.
- Symmetrically, refilling at `landmark_water` and swinging to `landmark_plot` enters `elif target_id == "landmark_plot"`, where none of the plot tool branches match `"refill"`, producing the exact same zombie state.

#### Mechanism 3: Unmonitored External Tool Changes
While manual number hotkeys (1–4) trigger `_handle_tool_toggle()`, which calls `hold_controller.cancel()`, external tool changes (e.g. via HUD UI click, inventory shortcut, or script call to `GardenManager.select_tool()`) do not invoke `_handle_tool_toggle()`.
When `active_tool` changes while aiming at `landmark_plot`:
- Raycast still hits `landmark_plot`.
- `_update_hold_action` enters the branch of the *new* tool (e.g. `tool_fertilizer`).
- Line 390 checks `hold_controller.action_id == "fertilize"`, which is `false` (it is `"hoe"`).
- The action is neither ticked nor cancelled, stranding `hold_controller`.

#### Mechanism 4: Asymmetric Handling of `MUST_RELEASE` vs `HOLDING`
Notice lines 360–368:
The `State.MUST_RELEASE` state was already implemented as an independent, centralized check at the top of the function. It does not care what landmark the player is pointing at; it only monitors whether the bound button has been released.
In contrast, `State.HOLDING` was scattered across 4 nested branches (`landmark_water`, `tool_hoe`, `tool_fertilizer`, `tool_watering_can`). This asymmetry created the vulnerability.

---

## 4. Architectural Recommendations

We propose two solutions: Option 1 is the minimal surgical patch ideal for immediate remediation with zero blast radius; Option 2 is the refactored architectural target state providing complete separation of concerns.

### 4.1 Option 1: Invariant Guard Pattern (Recommended Immediate Patch)

#### Architectural Description
Inject a centralized compatibility guard at line 370, immediately before the target dispatch tree. If `hold_controller.is_holding()` is `true`, evaluate whether the current `target_id` and `active_tool` match the ongoing `action_id`. If they do not, immediately invoke `hold_controller.cancel()`.

#### Code Specification
```gdscript
	# Invariant Guard: Cancel active hold immediately if target or active tool is no longer compatible
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

#### Placement in `scripts/player/player_controller.gd`
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

	# --- INSERT GUARD HERE (Lines 370+) ---
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

	# 1. Refill watering can at water_home (2.0s hold E)
	if target_id == "landmark_water":
...
```

#### Behavioral Trace with Guard:
1. **Case 5.4 (Plot -> Water):** `action_id` is `"hoe"`. Target becomes `"landmark_water"`. `is_compat` evaluates to `false`. Guard calls `hold_controller.cancel()`. `is_holding()` becomes `false`. Water branch does not match holding. Retargeting cancels cleanly.
2. **Case 5.5 (Water -> Plot):** `action_id` is `"refill"`. Target becomes `"landmark_plot"`. `is_compat` evaluates to `false`. Guard calls `hold_controller.cancel()`. Retargeting cancels cleanly.
3. **Case 5.6 (Tool change on plot):** `action_id` is `"hoe"`. Tool becomes `"tool_fertilizer"`. Target is `"landmark_plot"`. Match evaluates `"hoe"` against `active_tool == "tool_hoe"`, which is `false`. Guard calls `hold_controller.cancel()`. External tool change cancels cleanly.

---

### 4.2 Option 2: Decoupled Lifecycle State Machine (Refactored Target State)

#### Architectural Description
Restructure `_update_hold_action` into three distinct architectural phases:
- **Phase 1: Input & Context Gathering**: Validate world context, read detector target, read inputs.
- **Phase 2: Active Hold Lifecycle Servicing (Tick/Cancel)**:
  - If `MUST_RELEASE`: track button release.
  - If `HOLDING`: validate target, tool, and button down. If valid, tick; if invalid, cancel. Once serviced, return immediately.
- **Phase 3: Action Initiation (Start)**:
  - Reached only if controller is `IDLE`.
  - Check `just_pressed` triggers on compatible targets and start new actions.

#### Code Specification
```gdscript
func _update_hold_action(delta: float) -> void:
	# --- PHASE 1: Context & Input Gathering ---
	var im: Node = get_node_or_null("/root/InputManager") if is_inside_tree() else null
	if im != null and not im.is_world_context():
		if hold_controller.is_active():
			hold_controller.cancel()
		return

	var target_node = interaction_detector.get_current_target() if (interaction_detector != null and interaction_detector.has_method("get_current_target")) else null
	var target_id := str(target_node.get("interaction_id")) if target_node != null else ""

	var gm = Engine.get_singleton("GardenManager") if Engine.has_singleton("GardenManager") else (get_node_or_null("/root/GardenManager") if is_inside_tree() else null)
	var active_tool: String = str(gm.get("active_tool")) if gm != null else ""

	var is_lmb_pressed: bool = Input.is_action_pressed("action_tool_use") or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and is_mouse_captured())
	var is_lmb_just_pressed: bool = Input.is_action_just_pressed("action_tool_use") or (is_lmb_pressed and not _was_lmb_pressed)
	var is_interact_pressed: bool = Input.is_action_pressed("interact")
	var is_interact_just_pressed: bool = Input.is_action_just_pressed("interact")

	# --- PHASE 2A: Re-Trigger Protection Resolution (MUST_RELEASE) ---
	if hold_controller.state == HoldActionControllerClass.State.MUST_RELEASE:
		var button_still_down := false
		if hold_controller.button_name == &"action_tool_use":
			button_still_down = is_lmb_pressed
		elif hold_controller.button_name == &"interact":
			button_still_down = is_interact_pressed
		hold_controller.tick(delta, button_still_down, true)
		_was_lmb_pressed = is_lmb_pressed
		return

	# --- PHASE 2B: Active Hold Servicing (HOLDING) ---
	if hold_controller.is_holding():
		var is_compat := false
		var is_btn_down := false
		if hold_controller.action_id == "refill":
			is_compat = (target_id == "landmark_water")
			is_btn_down = is_interact_pressed
		elif target_id == "landmark_plot":
			is_btn_down = is_lmb_pressed
			match hold_controller.action_id:
				"hoe": is_compat = (active_tool == "tool_hoe")
				"fertilize": is_compat = (active_tool == "tool_fertilizer")
				"water": is_compat = (active_tool == "tool_watering_can")

		if is_compat and is_btn_down:
			hold_controller.tick(delta, true, true)
		else:
			hold_controller.cancel()
		_was_lmb_pressed = is_lmb_pressed
		return

	# --- PHASE 3: Action Initiation (IDLE Only) ---
	if target_id == "landmark_water":
		if is_interact_just_pressed and not hold_controller.is_active():
			if gm != null and gm.can_refill_water()["success"]:
				hold_controller.start("refill", "water_home", 2.0, &"interact")

	elif target_id == "landmark_plot":
		if active_tool == "tool_seed":
			if is_lmb_just_pressed and is_mouse_captured():
				_handle_plant_seed_on_plot()
		elif is_lmb_just_pressed and not hold_controller.is_active() and is_mouse_captured():
			match active_tool:
				"tool_hoe":
					if gm != null and gm.can_hoe_plot("plot_home_01")["success"]:
						hold_controller.start("hoe", "plot_home_01", 2.0, &"action_tool_use")
				"tool_fertilizer":
					if gm != null and gm.can_fertilize_plot("plot_home_01")["success"]:
						hold_controller.start("fertilize", "plot_home_01", 1.0, &"action_tool_use")
				"tool_watering_can":
					if gm != null and gm.can_water_plot("plot_home_01")["success"]:
						hold_controller.start("water", "plot_home_01", 2.0, &"action_tool_use")

	_was_lmb_pressed = is_lmb_pressed
```

---

## 5. Comparative Trade-Off Analysis

| Dimension | Option 1: Surgical Invariant Guard | Option 2: Decoupled State Machine |
| :--- | :--- | :--- |
| **Code Churn** | **Minimal** (+12 lines inserted, 0 lines modified) | **Moderate** (~45 lines refactored) |
| **Regression Risk** | **Virtually Zero** (leaves existing initiation tree intact) | **Low** (requires verifying all input branches) |
| **Separation of Concerns** | Good (adds pre-validation layer) | **Excellent** (strict pipeline: input -> lifecycle -> initiation) |
| **Scalability (Future Milestones)** | Requires expanding guard match | Requires expanding compatibility & initiation match |
| **Passes Challenge 5 (5.4, 5.5, 5.6)** | **Yes (100%)** | **Yes (100%)** |
| **Recommendation for Worker** | **Recommended for immediate R2 fix** | **Recommended for long-term codebase health** |

Because Option 1 fixes DEFECT-GARD-01 completely without modifying existing initiation logic, it is the safest and most reliable implementation for the worker to apply immediately in GARD-001 Remediation.

---

## 6. Implementation Patch (for Worker Agent)

The worker agent can apply this exact patch to `scripts/player/player_controller.gd`:

```diff
--- a/scripts/player/player_controller.gd
+++ b/scripts/player/player_controller.gd
@@ -368,6 +368,17 @@ func _update_hold_action(delta: float) -> void:
 		_was_lmb_pressed = is_lmb_pressed
 		return
 
+	# Cancel active hold immediately if target or active tool is no longer compatible
+	if hold_controller.is_holding():
+		var is_compat := false
+		if hold_controller.action_id == "refill":
+			is_compat = (target_id == "landmark_water")
+		elif target_id == "landmark_plot":
+			match hold_controller.action_id:
+				"hoe": is_compat = (active_tool == "tool_hoe")
+				"fertilize": is_compat = (active_tool == "tool_fertilizer")
+				"water": is_compat = (active_tool == "tool_watering_can")
+		if not is_compat:
+			hold_controller.cancel()
+
 	# 1. Refill watering can at water_home (2.0s hold E)
 	if target_id == "landmark_water":
 		if hold_controller.is_holding() and hold_controller.action_id == "refill":
```

---

## 7. Verification Method & Success Criteria

1. **Adversarial Verification:**
   Execute:
   ```cmd
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/stress_hold_actions.gd"
   ```
   **Expected Outcome:** Exit code `0`. All 1,679 assertions pass (including 5.4, 5.5, and 5.6).

2. **Full Regression Test Suite:**
   Execute:
   ```cmd
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"
   ```
   **Expected Outcome:** Exit code `0`. All 936 baseline assertions pass with 0 failures across Suites 1–9.

3. **Garden Invariant Stress Suite:**
   Execute:
   ```cmd
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/stress_garden_invariants.gd"
   ```
   **Expected Outcome:** Exit code `0`. All 340 assertions pass.
