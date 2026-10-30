## 2026-10-27T10:05:21Z

# DISPATCH — challenger_lvl_001_1

Task: Adversarial Correctness Challenge for Milestone LVL-001 (CLI Execution, Smoke Test & Physics Collision)
Status: Dispatched
Timestamp: 2026-10-27T10:05:00Z

## Identity & Paths
- Role: teamwork_challenger
- Working Directory: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\challenger_lvl_001_1\
- Parent Conversation ID: 7fedeffb-6bbe-4514-a8d9-0d0093089682
- Mandatory Reference: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md (YOU MUST READ THIS FIRST)
- Level Design: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\docs\LEVEL_DESIGN.md
- Test Plan: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\docs\TEST_PLAN.md

## Challenge Scope & Instructions
1. Execute the full test runner:
   `C:\Users\HP\.local\bin\godot_console.exe --headless --script res://tests/test_runner.gd`
   Verify exit code, assertion counts, and zero failures.
2. Execute the headless smoke test on `scenes/main.tscn`:
   `C:\Users\HP\.local\bin\godot_console.exe --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 120`
   Verify it runs 120 frames without any errors, warnings, leaks, or crashes.
3. Challenge physical geometry and collision:
   - Check if house walls have collision shapes on all 4 directions with door opening only in south teras.
   - Check if `spawn_home` at (0, 0, 1) has proper clearance (player capsule radius 0.4m, height 1.8m) from all walls and obstacles.
   - Check if ground collision covers the full [-40..40] x [-35..45] playable area.
4. Write `handoff.md` in your working directory with explicit verdict: `APPROVE` or `REJECT`.
5. Send completion message to parent via `send_message`.
