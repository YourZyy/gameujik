# DISPATCH — worker_setup_001

Task: SETUP-001 Implementation & Verification
Status: Dispatched
Timestamp: 2026-10-27T09:36:00Z

## 2026-10-27T09:34:50Z
You are assigned to execute Milestone SETUP-001 for game 'Buku Resep 2045'.

## Identity & Paths
- Role: teamwork_worker
- Your Working Directory: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_setup_001\
- Parent Conversation ID: 31ed778a-a8ce-4413-885a-a9254d7c2b8d
- Mandatory Reference: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md (YOU MUST READ THIS FIRST)
- Environment Survey: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_survey_3\env_survey_report.md
- Test Harness Survey: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\spec_miner_survey_2\test_survey_report.md
- Project Scope: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen2\PROJECT.md
- Rules to Follow: C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\AGENTS.md

## MANDATORY INTEGRITY WARNING
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Objective & Tasks
1. Read ORIGINAL_REQUEST.md, AGENTS.md, and the survey reports above.
2. Ensure Godot engine binary is available at C:\Users\HP\.local\bin\godot.exe (download official Godot 4.7.2-stable win64 zip and extract to C:\Users\HP\.local\bin\godot.exe per env_survey_report.md §2.3 if not already present). Verify with `godot --version`.
3. Create `project.godot` at project root with:
   - config/name="Buku Resep 2045"
   - rendering/renderer/rendering_method="gl_compatibility"
   - rendering/renderer/rendering_method.mobile="gl_compatibility"
   - run/main_scene="res://scenes/main.tscn"
   - standard desktop window resolution (e.g., 1280x720, stretch mode canvas_items)
4. Create directory structure: `scenes/`, `scripts/`, `data/`, `assets/`, `tests/`, `tests/suites/`.
5. Create `.gitignore` ignoring `.godot/`, editor cache, etc.
6. Create initial main scene `scenes/main.tscn` (basic 3D Node3D scene with directional light, camera, world placeholder).
7. Create test harness:
   - `tests/assertions.gd` (assertion library: assert_true, assert_equal, assert_not_null, etc.)
   - `tests/test_runner.gd` (headless test runner supporting CLI execution: `godot --headless --script res://tests/test_runner.gd`)
   - `tests/suites/test_setup.gd` implementing tests T23 (engine headless boot) and T24 (main scene smoke run).
8. Run the headless test suite: `godot --headless --script res://tests/test_runner.gd` and verify exit code 0.
9. Update `README.md` with engine version, renderer, directory layout, and execution instructions for running game and tests.
10. Write completed task report: `docs/completed_tasks/002-setup-proyek-godot.md` adhering strictly to `docs/completed_tasks/TEMPLATE.md`.
11. Update `docs/TASKS.md` marking SETUP-001 as SELESAI with link to `002-setup-proyek-godot.md`.
12. Update `docs/PROJECT_STATUS.md` adding `002-setup-proyek-godot.md` to "Pekerjaan yang Sudah Selesai", and update "Deskripsi Status Pekerjaan Terakhir" (150-300 words).
13. Write `handoff.md` in your working directory (`.agents/teamwork/worker_setup_001/handoff.md`) with observation, logic chain, caveats, conclusion, and verification commands/results.
14. Send completion message to parent via send_message.
