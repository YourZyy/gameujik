# Task Assignment: worker_world_001_v2 (WORLD-001 Verification & Finalization)

## Mandatory Reading
- Original User Request: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
- Master Scope: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen6\PROJECT.md`
- Codebase files:
  - `scripts/world/world_resource_manager.gd`
  - `tests/suites/test_world.gd`
  - `scripts/main.gd`
  - `scripts/ui/hud.gd`
  - `project.godot`
  - `tests/test_runner.gd`
- Skills:
  - `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\skills\godot-gdscript-headless-testing\SKILL.md`
  - `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\skills\godot-gdscript\SKILL.md`

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Objective
Run headless test runner (`godot --headless --script tests/test_runner.gd` or `C:\Users\HP\.local\bin\godot.exe --headless --script tests/test_runner.gd`) to verify all 10 test suites, especially Suite 10 (`test_world.gd`) validating T09, T37, T38, T39.
If any assertion or runtime issue arises, fix it cleanly and accurately in `scripts/world/world_resource_manager.gd`, `scripts/main.gd`, `scripts/ui/hud.gd`, or `tests/suites/test_world.gd`.
Ensure 100% of tests pass without errors or regressions.

## Output
Write `handoff.md` in your working directory (`.agents/teamwork/worker_world_001_v2/`) with:
1. Exact execution command used and terminal output log.
2. Assertion counts and status of Suites 1..10.
3. Verification that files adhere to `PROJECT.md` Code Layout.
4. Send completion message back to parent.


## 2026-10-28T13:22:58Z
You are worker_world_001_v2. Your working directory is `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_world_001_v2\`.
Please read:
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_world_001_v2\DISPATCH.md`
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen6\PROJECT.md`
- Skill: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\skills\godot-gdscript-headless-testing\SKILL.md`

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Execute the instructions in DISPATCH.md:
1. Run headless test runner with godot CLI (`C:\Users\HP\.local\bin\godot.exe --headless --script tests/test_runner.gd` or `godot --headless --script tests/test_runner.gd`).
2. Verify all test suites (Suites 1..10) pass, particularly Suite 10 (test_world.gd) covering T09, T37, T38, T39.
3. If any assertion or script issue is encountered, resolve it cleanly.
4. Write `handoff.md` in your working directory with test execution output, assertions count, and status.
5. Send completion message to parent when done.


## 2026-10-28T13:44:34Z
**Context**: WORLD-001 headless test runner execution
**Content**: Status check. Have the headless test suites 1..10 completed running? Please report progress or complete handoff.md.
**Action**: Report current status and test output immediately.
