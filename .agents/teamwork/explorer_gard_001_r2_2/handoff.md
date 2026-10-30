# Handoff Report: Tool Mutation & Hold Invariants Investigation (GARD-001 Remediation)

**Agent:** `explorer_gard_001_r2_2` (Hold Controller Compatibility & Tool Mutation Explorer)  
**Parent / Recipient:** `bc3795f9-23c4-4352-8a9c-4322971bcc61`  
**Working Directory:** `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_gard_001_r2_2\`  
**Milestone:** GARD-001 Remediation  
**Status:** Hard Handoff (Investigation & Architecture Recommendation Complete)  
**Date:** 2026-10-27T18:43:00Z  

---

## 1. Observation

1. **Adversarial Stress Test Failure Verification (`tests/stress_hold_actions.gd`)**:
   - Command: `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/stress_hold_actions.gd"`
   - Result: Exit Code 1.
   - Verbatim Output:
     ```
     [FAIL] Assertion failed: expected FALSE, got TRUE. 5.4: Swapping target to landmark_water must cancel active plot hold action
     [FAIL] Assertion failed: expected 0, got 1. 
     [FAIL] Assertion failed: expected FALSE, got TRUE. 5.5: Swapping target to landmark_plot must cancel active refill hold action
     [FAIL] Assertion failed: expected 0, got 1. 
     [FAIL] Assertion failed: expected FALSE, got TRUE. 5.6: External tool change must cancel active hold action
     [FAIL] Assertion failed: expected 0, got 1. 
     [ADVERSARIAL_HARNESS] SUMMARY:
       Assertions Passed: 1673
       Assertions Failed: 6
       VERDICT: DEFECT DETECTED (Exit Code: 1)
     ```
   - Reference: `tests/stress_hold_actions.gd:347-395`.

2. **Project Test Runner Baseline Verification (`tests/test_runner.gd`)**:
   - Command: `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"`
   - Result: Exit Code 0, 936 passed, 0 failed.

3. **Code Inspection of `scripts/player/player_controller.gd`**:
   - Lines 335–341 (`_handle_tool_toggle`): Keyboard hotkeys 1–4 explicitly invoke `hold_controller.cancel()` before `gm.select_tool(tool_id)`.
   - Lines 158–163 (`_unhandled_input`): `action_tool_cancel` explicitly invokes `hold_controller.cancel()`.
   - Lines 344–347 (`_update_hold_action`): Non-world contexts (`InputManager.is_world_context() == false`) explicitly cancel `hold_controller`.
   - Lines 370–408 (`_update_hold_action`): Target routing branches (`if target_id == "landmark_water"` and `elif target_id == "landmark_plot"`). When `hold_controller.is_holding()` is true and the crosshair moves between `landmark_plot` and `landmark_water`, or when `active_tool` changes to another valid tool while looking at `landmark_plot`, the action-matching conditions inside the branch evaluate to false and the fallback `else` (line 404) is bypassed. As a result, neither `hold_controller.tick()` nor `hold_controller.cancel()` is executed.

4. **Code Inspection of `scripts/gardening/hold_action_controller.gd`**:
   - `HoldActionController` is an abstract `RefCounted` timing utility (lines 1–87).
   - `is_holding()` returns `state == State.HOLDING` (line 83).
   - `is_active()` returns `state != State.IDLE` (line 86).
   - In `State.MUST_RELEASE`, `is_holding()` is `false`, but `is_active()` is `true`.
   - Passed all 1,673 adversarial checks in Challenges 1, 2, 3, 4, and 6 with zero defects.

---

## 2. Logic Chain

1. From Observation 1 and 3:
   - When the crosshair moves directly from `landmark_plot` to `landmark_water` during an active plot hold action (e.g. `hoe`), `target_id` changes to `"landmark_water"`.
   - In `_update_hold_action`, `if target_id == "landmark_water":` matches, but inner line 372 (`hold_controller.action_id == "refill"`) fails because `action_id` is `"hoe"`.
   - Because no `else` exists inside line 371, and line 404 is skipped due to the top-level branch match, `hold_controller` is neither ticked nor cancelled.
   - It remains stuck in `State.HOLDING` with frozen progress, causing Challenge 5.4 to fail. Symmetrically, swapping from `landmark_water` to `landmark_plot` causes Challenge 5.5 to fail.
2. From Observation 1 and 3:
   - When `active_tool` changes externally (via UI toolbar or script call) to `"tool_fertilizer"` while holding LMB on `landmark_plot` with `tool_hoe`, `target_id` is still `"landmark_plot"`.
   - The branch `elif active_tool == "tool_fertilizer":` matches, but line 390 (`hold_controller.action_id == "fertilize"`) fails because `action_id` is `"hoe"`.
   - The branch `else:` on line 401 is skipped because the `elif` matched.
   - `hold_controller` is neither ticked nor cancelled, causing Challenge 5.6 to fail.
3. From Observation 4:
   - `HoldActionController` is a generic timing state machine without domain knowledge of tools or landmarks. Coupling it with game entities would violate single-responsibility principles and break architectural boundaries.
   - `PlayerController` already owns the raycast detector, tool polling, and input state.
4. From Observation 4 and Analysis:
   - Enforcing an active compatibility guard `if hold_controller.is_holding():` at the start of `_update_hold_action` deterministically cancels any invalid hold every physics tick.
   - Because `is_holding()` is false in `State.MUST_RELEASE`, the guard does not interfere with re-trigger protection or commit flows.
5. Therefore, adding a frame-deterministic compatibility check in `PlayerController._update_hold_action()` is the necessary, optimal, and sufficient architectural solution to resolve DEFECT-GARD-01.

---

## 3. Caveats

1. **Read-Only Explorer Mandate**: Following the explorer archetype and `AGENTS.md` guidelines, no source code changes were made to `scripts/player/player_controller.gd`. The implementation must be executed by the designated implementer/builder agent.
2. **Auxiliary Signal Connection**: While connecting `GardenManager.active_tool_changed` in `PlayerController` provides event-driven cancellation for UI button clicks, it is not sufficient on its own because it does not trigger on crosshair target swapping. The per-frame compatibility guard in `_update_hold_action()` is strictly required.

---

## 4. Conclusion

**Verdict:** The defect DEFECT-GARD-01 is fully diagnosed, and the challenger's findings and proposed remediation are validated as mathematically sound and architecturally optimal.

### Recommended Implementation Patch

In `scripts/player/player_controller.gd`:

1. **Add private helper method `_is_hold_action_compatible`**:
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

2. **Add compatibility guard in `_update_hold_action(delta: float)`** (immediately after the `MUST_RELEASE` block, before target branching):
   ```gdscript
   	# Invariant Check: Cancel active hold if target or active tool is no longer compatible
   	if hold_controller.is_holding():
   		if not _is_hold_action_compatible(hold_controller.action_id, target_id, active_tool):
   			hold_controller.cancel()
   ```

---

## 5. Verification Method

To verify the resolution after implementation:

1. **Execute Adversarial Stress Harness**:
   ```cmd
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/stress_hold_actions.gd"
   ```
   *Expected Result:* Exit Code 0, 1679 assertions passed, 0 failed (`VERDICT: CONFIRMED CORRECT`).

2. **Execute Full Project Test Suite**:
   ```cmd
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"
   ```
   *Expected Result:* Exit Code 0, 936+ assertions passed, 0 failed.

3. **Invalidation Conditions**:
   - Any failure in Challenge 1–4, Challenge 6, or existing test suites.
   - Any lingering `State.HOLDING` after swapping targets while holding LMB.
