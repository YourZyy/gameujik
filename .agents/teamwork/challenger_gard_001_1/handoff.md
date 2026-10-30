# Handoff Report: Empirical Challenge of Hold Actions & Timing (GARD-001 Gate)

**Author:** challenger_gard_001_1 (Empirical Challenger)  
**Recipient:** Orchestrator (`bc3795f9-23c4-4352-8a9c-4322971bcc61`)  
**Verdict:** **DEFECT DETECTED**  
**Date:** 2026-10-27T18:35:00Z  

---

## 1. Observation

1. **Adversarial Stress Harness Execution (`tests/stress_hold_actions.gd`)**:
   - Command: `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/stress_hold_actions.gd"`
   - Output:
     ```
     ==================================================
     [ADVERSARIAL_HARNESS] Stress Test: Hold Action Controller & Tool Timing
     ==================================================
       [RUN] Challenge 1: HoldActionController State Machine & Invariant Oracles
       [PASS] Challenge 1: State machine & invariant oracles verified.
       [RUN] Challenge 2: Rapid Cancellation 100 Cycles (0.05s to 1.95s cancellation)
       [PASS] Challenge 2: 100 rapid cancellation cycles passed with 0 leaks/mutations.
       [RUN] Challenge 3: Re-Trigger Protection Oracle (Holding LMB across and past Commit)
       [PASS] Challenge 3: Re-trigger protection oracle verified.
       [RUN] Challenge 4: GardenManager & Inventory Atomic Invariance under 100 Interrupted Cycles
       [PASS] Challenge 4: GardenManager + inventory atomic invariance verified under stress.
       [RUN] Challenge 5: Tool Switching and Target Swapping under Active Hold
       [FAIL] Assertion failed: expected FALSE, got TRUE. 5.4: Swapping target to landmark_water must cancel active plot hold action
       [FAIL] Assertion failed: expected 0, got 1. 
       [FAIL] Assertion failed: expected FALSE, got TRUE. 5.5: Swapping target to landmark_plot must cancel active refill hold action
       [FAIL] Assertion failed: expected 0, got 1. 
       [FAIL] Assertion failed: expected FALSE, got TRUE. 5.6: External tool change must cancel active hold action
       [FAIL] Assertion failed: expected 0, got 1. 
       [RUN] Challenge 6: Numerical Boundaries, Zero Duration & Extreme Deltas
       [PASS] Challenge 6: Numerical boundaries and extreme deltas verified.
     ==================================================
     [ADVERSARIAL_HARNESS] SUMMARY:
       Assertions Passed: 1673
       Assertions Failed: 6
       VERDICT: DEFECT DETECTED (Exit Code: 1)
     ==================================================
     ```

2. **Full Project Test Runner Baseline (`tests/test_runner.gd`)**:
   - Command: `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"`
   - Output:
     ```
     [TEST_RUNNER] SUMMARY:
       Assertions Passed: 936
       Assertions Failed: 0
       RESULT: ALL SUITES PASSED (Exit Code: 0)
     ```
   - *Analysis:* Existing Suite 9 (`TestGardening`) verified baseline hold action happy path and single-target cancellation, but did not test retargeting across valid landmarks or external tool mutations during active hold.

3. **Defect Location in `scripts/player/player_controller.gd` (lines 342–408)**:
   - In `_update_hold_action(delta: float)`:
     ```gdscript
     371:	if target_id == "landmark_water":
     372:		if hold_controller.is_holding() and hold_controller.action_id == "refill":
     373:			hold_controller.tick(delta, is_interact_pressed, target_id == "landmark_water")
     374:		elif is_interact_just_pressed and not hold_controller.is_active():
     375:			if gm != null and gm.can_refill_water()["success"]:
     376:				hold_controller.start("refill", "water_home", 2.0, &"interact")
     377:
     378:	# 2. Plot actions at plot_home_01 (tool hold or seed plant)
     379:	elif target_id == "landmark_plot":
     380:		if active_tool == "tool_seed":
     381:			if is_lmb_just_pressed and is_mouse_captured():
     382:				_handle_plant_seed_on_plot()
     383:		elif active_tool == "tool_hoe":
     384:			if hold_controller.is_holding() and hold_controller.action_id == "hoe":
     385:				hold_controller.tick(delta, is_lmb_pressed, target_id == "landmark_plot")
     ...
     404:	else:
     405:		if hold_controller.is_holding():
     406:			hold_controller.cancel()
     ```
   - When a hold action is active for `plot_home_01` (e.g. `hoe`, `fertilize`, `water`) and the player's crosshair moves to `landmark_water`:
     - Line 371 matches (`target_id == "landmark_water"`).
     - Line 372 evaluates to `false` because `hold_controller.action_id` is `"hoe"` (not `"refill"`).
     - Line 374 evaluates to `false` because `hold_controller.is_active()` is `true`.
     - There is no `else` inside `if target_id == "landmark_water"`.
     - The outer `else` (line 404) is skipped because the top-level `if` matched.
     - As a consequence, `hold_controller` is neither ticked nor cancelled. It remains in `State.HOLDING` with frozen progress.
   - Symmetrically, if refilling at `landmark_water` and the crosshair moves to `landmark_plot`, none of the plot tool branches match `"refill"`, skipping cancellation.
   - Furthermore, if `active_tool` is changed externally while aiming at `landmark_plot`, the hold controller is not cancelled and gets stuck.

---

## 2. Logic Chain

1. From Observation 1 (Challenge 1, 2, 3, 4, 6):
   - The standalone `HoldActionControllerClass` state machine is robust:
     - 100 rapid cancellation cycles with fractional holds (0.05s to 1.95s) across 4 cancellation vectors produced 0 state leaks, 0 resource loss in `InventoryManager`, 0 water deduction, and 100% timer reset to 0.0 (T32 satisfied).
     - Re-trigger protection functions properly in isolation: holding LMB continuously past commit maintains `State.MUST_RELEASE` for 200+ frames with strictly 1 commit and 0 duplicate actions until released.
     - Numerical boundaries (0.0s clamped to 0.01s, negative duration clamped, 1000s extreme delta, micro-delta accumulation) execute safely.
2. From Observation 1 (Challenge 5, sub-tests 5.4, 5.5, 5.6) and Observation 3:
   - In `PlayerController._update_hold_action`, the branching model assumes that moving away from a target results in `target_id == ""` (which falls through to line 404).
   - In a spatial game world with multiple nearby landmarks (`landmark_plot` and `landmark_water` are both situated in the front yard), swinging the camera can directly transition raycast collision from one landmark to another without an intermediate empty frame.
   - When this occurs, the top-level `if/elif` branch matches the new landmark, but the inner logic does not validate that `hold_controller.action_id` corresponds to the new landmark.
   - Because `hold_controller` is not cancelled, it enters a zombie state:
     - The HUD hold progress bar remains visible and frozen.
     - If the player releases LMB while looking at `landmark_water`, the release is not passed to `hold_controller`.
     - When the player looks back at `landmark_plot`, `hold_controller.is_active()` is still true, which prevents initiating new actions or can resume an unintended action from stale progress.
3. Therefore, a concrete defect exists in `PlayerController._update_hold_action`: **DEFECT-GARD-01**.

---

## 3. Caveats

1. **Scope of Defect**: `DEFECT-GARD-01` is strictly located in the input routing in `scripts/player/player_controller.gd`. The underlying core classes (`HoldActionController`, `GardenManager`, `InventoryManager`) are completely defect-free and passed all 1,673 adversarial stress tests.
2. **Player Hotkeys vs Retargeting**: Hotkeys 1–4 explicitly invoke `_handle_tool_toggle()` which calls `hold_controller.cancel()`. Thus, manual hotkey pressing already cancels hold correctly. The bug is triggered specifically by:
   - Camera retargeting directly between landmarks during hold.
   - External tool changes (e.g. via UI click or script `GardenManager.select_tool`).
3. **Review-Only Constraint**: Following the challenger identity constraint, no modification has been made to `scripts/player/player_controller.gd`. A clean, minimal mitigation patch is provided below.

---

## 4. Conclusion

**Verdict: DEFECT DETECTED**

### Defect Specification: `DEFECT-GARD-01`
- **Component**: `scripts/player/player_controller.gd` (`_update_hold_action()`)
- **Severity**: MEDIUM-HIGH (Gameplay softlock / stuck hold state when looking between garden plot and water well)
- **Root Cause**: Missing target/tool compatibility validation when `hold_controller.is_holding()` is true.
- **Recommended Remediation**:
  Add an active hold validation guard at the top of `_update_hold_action(delta: float)` in `scripts/player/player_controller.gd`:
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

---

## 5. Verification Method

To independently verify the defect reproduction:

1. **Execute Custom Adversarial Stress Script**:
   ```cmd
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/stress_hold_actions.gd"
   ```
   *Expected Result:* Exit code 1, 6 failed assertions in Challenge 5 (5.4, 5.5, 5.6) demonstrating stuck `State.HOLDING` after target swapping.

2. **Verify Baseline Test Runner Still Passes**:
   ```cmd
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"
   ```
   *Expected Result:* Exit code 0, 936 passed, 0 failed.

3. **Invalidation Conditions**:
   - The defect will be invalidated (resolved) once `_update_hold_action` cancels the active hold whenever the target landmark or active tool changes, allowing `tests/stress_hold_actions.gd` to exit with code 0 (1,679 assertions passed).
