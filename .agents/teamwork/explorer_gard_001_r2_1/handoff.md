# Handoff Report: PlayerController Retargeting & Hold Lifecycle Root Cause (DEFECT-GARD-01)

**Author:** explorer_gard_001_r2_1 (PlayerController Retargeting & Hold Lifecycle Explorer)  
**Recipient:** Orchestrator (`bc3795f9-23c4-4352-8a9c-4322971bcc61`)  
**Verdict:** Root Cause Fully Diagnosed & Architectural Fix Formulated  
**Date:** 2026-10-27T18:47:00Z  

---

## 1. Observation

1. **Reproduction Command & Adversarial Test Failure**:
   - Command: `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/stress_hold_actions.gd"`
   - Output verbatim:
     ```text
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

2. **Baseline Test Runner Verification**:
   - Command: `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"`
   - Output: Exit code `0`, 936 assertions passed across all 9 suites.
   - Command: `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/stress_garden_invariants.gd"`
   - Output: Exit code `0`, 340 assertions passed.

3. **Defective Code Path in `scripts/player/player_controller.gd` (lines 370–408)**:
   ```gdscript
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
   ...
   404: 	else:
   405: 		if hold_controller.is_holding():
   406: 			hold_controller.cancel()
   ```

4. **World Landmark Layout Context in `scenes/world/level_graybox.tscn`**:
   - `plot_home_01` is at `(8, 0, 7)`.
   - `water_home` is at `(4, 0, 9)`.
   - Both landmarks are located in the yard in close spatial proximity. A single camera rotation swings the raycast directly from `landmark_plot` to `landmark_water` (and vice-versa) in a single physics frame without an intermediate empty hit.

---

## 2. Logic Chain

1. From Observation 1, Challenge 5 fails in three specific sub-tests:
   - 5.4: While holding LMB for a plot action (`action_id == "hoe"`), camera target swings to `landmark_water`.
   - 5.5: While holding E for a refill action (`action_id == "refill"`), camera target swings to `landmark_plot`.
   - 5.6: While holding LMB for `"hoe"` on `landmark_plot`, `GardenManager.active_tool` changes to `"tool_fertilizer"` externally.
2. From Observation 3, `_update_hold_action` routes execution through an `if (target_id == "landmark_water") ... elif (target_id == "landmark_plot") ... else ...` construct.
3. In Case 5.4:
   - Line 371 matches (`target_id == "landmark_water"`).
   - Line 372 is evaluated: `hold_controller.is_holding()` is true, but `hold_controller.action_id == "refill"` is false (`action_id` is `"hoe"`).
   - Line 374 is evaluated: `hold_controller.is_active()` is true, so `not hold_controller.is_active()` is false.
   - There is no `else` inside the `if target_id == "landmark_water"` block.
   - The outer `else` (line 404) is skipped because the top-level `if` matched.
   - Therefore, `hold_controller` is neither ticked nor cancelled. It remains in `State.HOLDING` with frozen progress.
4. Symmetrically, in Case 5.5, line 379 matches (`target_id == "landmark_plot"`). Within the plot tool sub-branches, none match `action_id == "refill"`. The outer `else` is skipped, stranding `hold_controller`.
5. In Case 5.6, changing `active_tool` externally routes into the branch of the new tool (e.g. line 390 for `"fertilize"`), which fails to match `action_id == "hoe"`. The action is neither ticked nor cancelled.
6. Therefore, the direct root cause is the absence of an active hold compatibility check before target-based input dispatching.

---

## 3. Caveats

1. **Read-Only Explorer Constraint:** In accordance with the Teamwork Explorer identity and instructions, no edits were made to `scripts/player/player_controller.gd`. Implementation must be performed by the worker agent.
2. **Tool Switching Via Hotkeys:** Manual hotkey presses (1–4) already explicitly cancel `hold_controller` via `_handle_tool_toggle()`. The defect occurs when tools change without invoking `_handle_tool_toggle()` (e.g. via direct singleton calls or future UI buttons).
3. **Other World Landmarks:** Looking at other landmarks in the world (e.g. bed, starter container) falls into the outer `else` (line 404) and cancels correctly. The bug is exclusive to transitions between landmarks that have hold action branches (`landmark_plot` and `landmark_water`).

---

## 4. Conclusion

### Defect Specification: `DEFECT-GARD-01`
- **Location:** `scripts/player/player_controller.gd` (`_update_hold_action()`, line 370)
- **Severity:** Medium-High (softlocks player hold interaction upon quick camera retargeting between yard landmarks)
- **Classification:** Stateful Input Retargeting / Lifecycle Desynchronization

### Recommended Architectural Solution (Option 1 - Invariant Guard)
Add a pre-dispatch compatibility guard at line 370 of `scripts/player/player_controller.gd`:

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

### Alternative Architectural Target (Option 2 - Decoupled Lifecycle)
For future refactoring across subsequent milestones, adopt the 3-phase lifecycle state machine detailed in `.agents/teamwork/explorer_gard_001_r2_1/analysis.md` § 4.2.

---

## 5. Verification Method

To verify the resolution of DEFECT-GARD-01 once implemented by the worker:

1. **Run Adversarial Stress Test Harness:**
   ```cmd
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/stress_hold_actions.gd"
   ```
   - **Pass Criterion:** Exit code `0`. All 1,679 assertions pass with 0 failures.

2. **Run Full Test Runner Suite:**
   ```cmd
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"
   ```
   - **Pass Criterion:** Exit code `0`. All 936 baseline assertions pass across Suites 1–9.

3. **Run Garden Invariant Stress Suite:**
   ```cmd
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/stress_garden_invariants.gd"
   ```
   - **Pass Criterion:** Exit code `0`. All 340 assertions pass.

4. **Invalidation Conditions:**
   - Any failure in Challenge 5 (5.4, 5.5, 5.6) indicates the compatibility check was omitted or incomplete.
   - Any failure in happy-path hold actions (T06, T32, T33 in `test_gardening.gd`) indicates overzealous cancellation.
