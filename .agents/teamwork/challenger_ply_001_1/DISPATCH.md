## 2026-10-27T10:29:14Z

# DISPATCH — challenger_ply_001_1

Task: Adversarial Correctness Challenge for Milestone PLY-001 (Framerate Independence, Pitch Clamp Extremes & Movement Vector Math)
Status: Dispatched
Timestamp: 2026-10-27T10:28:30Z

## Identity & Paths
- Role: teamwork_challenger
- Working Directory: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\challenger_ply_001_1\
- Parent Conversation ID: 7fedeffb-6bbe-4514-a8d9-0d0093089682
- Mandatory Reference: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md (YOU MUST READ THIS FIRST)
- Level Design: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\docs\LEVEL_DESIGN.md
- Content: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\docs\CONTENT.md (§ 14)
- Test Plan: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\docs\TEST_PLAN.md (T18, T25, T26)

## Challenge Scope & Instructions
1. Execute the full test runner:
   `C:\Users\HP\.local\bin\godot_console.exe --headless --script res://tests/test_runner.gd`
   Verify exit code, assertion counts (expected >= 325), and zero failures.
2. Execute the headless smoke test on `scenes/main.tscn`:
   `C:\Users\HP\.local\bin\godot_console.exe --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 120`
   Verify it runs 120 frames without any errors, warnings, leaks, or crashes.
3. Challenge physics & controller edge cases:
   - Check diagonal movement normalization: WASD simultaneous presses must not exceed 3.0 m/s.
   - Check extreme mouse movements (e.g. +10,000 px, -10,000 px): pitch must never exceed [-85.0°, +85.0°] and never NaN.
   - Check framerate independence: delta-scaled movement at 30, 60, and 120 FPS must produce identical distance traveled per second.
4. Write `handoff.md` in your working directory with explicit verdict: `APPROVE` or `REJECT`.
5. Send completion message to parent via `send_message`.
