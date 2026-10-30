## 2026-10-27T16:23:10Z
[Message] timestamp=2026-10-27T16:23:10Z sender=bc3795f9-23c4-4352-8a9c-4322971bcc61 priority=MESSAGE_PRIORITY_HIGH content=You are worker_book_001, assigned to implement Milestone BOOK-001 (Buku Resep dan Tracker: Recipe Data Model, RecipeManager Autoload Singleton, Book UI, HUD Quest Tracker, World Landmark Wiring, and Test Suite 8).

Working directory: c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_book_001\

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

MANDATORY INSTRUCTIONS:
1. You MUST read ORIGINAL_REQUEST.md at c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md before writing any code.
2. Carefully read the handoff reports from all 3 explorers:
   - c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_book_001_1\handoff.md
   - c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_book_001_2\handoff.md
   - c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_book_001_3\handoff.md
3. Read relevant docs:
   - docs/CONTENT.md § 4, § 5
   - docs/UI_UX.md § UI01, UI02
   - docs/TEST_PLAN.md (T01, T02, T03, T11, T31)
   - AGENTS.md § 4, § 6, § 8, § 9
4. Implement the following:
   a. Recipe Data Model:
      - `scripts/recipe/recipe_data.gd` (`class_name RecipeData extends Resource`): recipe ID, display name, station ID, required ingredients dictionary, source hints dictionary, player notes, cooking parameters, and status helper methods.
      - `scripts/recipe/recipes_data.gd`: registry defining `recipe_sayur_bening_01` ("Sayur Bening Bayam dan Jagung", 3 spinach, 1 corn, 1 temu kunci).
   b. Recipe Manager Autoload Singleton:
      - `scripts/recipe/recipe_manager.gd`: manages catalog, tracking status, times cooked, completed checkmark, notes registry (`note_garden_01`, `recipe_note_sayur_bening`), signals (`recipe_tracked`, `recipe_untracked`, `recipe_updated`, `recipe_completed`, `note_unlocked`), save/load snapshot API (`get_save_snapshot()`, `load_save_snapshot()`), and unified free stock query hooked to `InventoryManager.get_available_item_count()`.
      - Register `RecipeManager="*res://scripts/recipe/recipe_manager.gd"` under `[autoload]` in `project.godot`.
      - Ensure action `open_book` (`B`) is properly mapped in `project.godot` input map.
   c. Book UI:
      - `scenes/ui/book_ui.tscn` and `scripts/ui/book_ui.gd`:
        - Responsive CanvasLayer layout (1280x720 base, CenterContainer + PanelContainer 880x540) with no empty sidebars.
        - Title at top: "Buku Resep Keluarga" / "Sayur Bening Bayam dan Jagung".
        - Left column: notes / descriptive text and cooking station.
        - Right column: 3 ingredient rows (Bayam 0/3, Jagung 0/1, Temu Kunci 0/1) with expandable/visible source hints per row.
        - Bottom bar: "Lacak Masakan" / "Berhenti Melacak" button (toggles tracking), status badge ("Siap dimasak" when ingredients complete, "Selesai (X kali dimasak)" when cooked).
        - Keyboard / focus navigation: Arrow keys, Enter/Space, Tab traversal, Esc / B close.
        - Integration with `InputManager.ContextMode.BOOK`: pauses simulation, frees mouse cursor, and engages frame guard on close.
   d. HUD Quest Tracker:
      - `scenes/ui/hud.tscn` and `scripts/ui/hud.gd`:
        - Top-left quest tracker container (max ~30% width).
        - Untracked: "Buka buku [B] untuk memilih masakan."
        - Tracked: Recipe title + 3 ingredient lines with live counters (e.g. "Bayam: 0/3", "Jagung: 0/1", "Temu Kunci: 0/1").
        - Ready: "Bahan lengkap. Siap dimasak di dapur."
        - Cooking active: "Masakan dijeda" / "Sedang memasak".
        - Integrated with crosshair reticle and interaction prompt.
   e. World Landmark Wiring:
      - In `scripts/main.gd`:
        - Wire `book_family` landmark on house table so pressing E opens `BookUI`.
        - Wire global hotkey `B` to toggle `BookUI`.
        - Wire `note_garden_01` landmark so pressing E unlocks the note in `RecipeManager`.
   f. Comprehensive Test Suite 8:
      - `tests/suites/test_recipe.gd`: implement all test methods designed by explorer 3 (T01, T02, T03, T11, T31, Notes registry, Save snapshot, Context switching & frame guard).
      - Add Suite 8 to `tests/test_runner.gd`.
5. Execute Verification Commands (Worker MUST run builds and tests):
   - Run full test runner: `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"` (Ensure ALL suites 1..8 pass, 0 failed, exit code 0).
   - Run adversarial challenge: `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/adversarial_level_challenge.gd"`.
   - Run project linter: `python ".agents/skills/godot-nodes-scenes/scripts/check_godot_project.py" .` (Ensure 0 errors, 0 warnings).
   - Run smoke test: `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 60"` (Ensure exit code 0).
6. Documentation & Reporting (Strict compliance with AGENTS.md § 6 & § 7):
   - Create detailed completed task report: `docs/completed_tasks/008-buku-resep-tracker-hud-stok-bersama.md` using `docs/completed_tasks/TEMPLATE.md`.
   - Update `docs/PROJECT_STATUS.md`:
     - Add 1 chronological bullet in "Pekerjaan yang Sudah Selesai" linking to report 008.
     - Replace "Deskripsi Status Pekerjaan Terakhir" with updated status (~150-300 words).
   - Update `docs/TASKS.md`: Mark `BOOK-001` as `SELESAI` linking to report 008.
7. Write `handoff.md` in your working directory following the Handoff Protocol (Observation, Logic Chain, Caveats, Conclusion, Verification Method).
8. Once finished, message the caller with your completion report.
