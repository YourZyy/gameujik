# Handoff Report — SAVE-001 Save Acceptance Test Suite Specification

**Agent:** `explorer_save_001_3` (Save Acceptance Test Explorer)  
**Parent / Recipient:** Orchestrator (`e0d1bd43-d851-4429-b584-da0f2b6c5816`)  
**Target Milestone:** `SAVE-001`  
**Working Directory:** `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_save_001_3\`  
**Date:** 2026-10-29  

---

## 1. Observation

1. **Test Plan & Tasks Requirements:**
   - In `docs/TEST_PLAN.md` (lines 46–82) and `docs/TASKS.md` (lines 113–117):
     - Milestone `SAVE-001` requires verifying tests:
       - **T14:** *"Simpan saat tanaman tumbuh dan job dijeda; keluar/load: Kemajuan tanaman/job, reservasi dan alat/air pulih persis; tidak berjalan offline"*
       - **T16:** *"Main sampai setelah berbagi; simpan; tutup/buka; Lanjutkan: Buku, meal_used, sumber, hari, petak, kontainer dan posisi aman konsisten"*
       - **T17:** *"Rusakkan checkpoint utama fixture; coba Muat: Tidak memuat setengah dunia; menawarkan checkpoint/cadangan valid dengan pesan"*
       - **T22:** *"Hentikan proses saat fase penulisan save terkontrol: Setidaknya checkpoint valid sebelumnya/cadangan dapat dipulihkan; tidak mengaku save baru sukses"*, with position validator redirecting NaN/Inf/out-of-bounds to safe spawn.
       - **T46:** *"Bandingkan snapshot lengkap sebelum save dan sesudah load: Semua entitas dinamis CONTENT terpulihkan, termasuk output/refund/flag, bukan posisi saja"*
       - **T47:** *"Fixture save versi tidak cocok/ID item tak dikenal; coba load: Validasi menolak atau migrasi yang tertulis berjalan; dunia lama belum diganti sampai valid"*, testing atomic write crash resistance via `.tmp`.
       - **T48:** *"Buat manual, lanjutkan hingga autosave lebih baru; Lanjutkan lalu pilih manual: Lanjutkan memilih revisi valid terbaru; manual lama tetap dapat dipilih secara eksplisit"*
       - **T49:** *"Simulasikan gagal tulis/ruang tidak cukup; pilih Simpan dan Keluar: Pesan gagal; aplikasi tidak keluar seolah berhasil; checkpoint lama valid"*, isolating `settings.cfg` from game saves.
       - **T50:** *"Load snapshot job selesai/output_ready berulang, ambil output sekali: Tidak re-commit output atau menambah jumlah dibuat lagi; slot hasil tetap tunggal"*, testing 100% identical roundtrip.
     - Mandate: *"Selesai bila tes T14/T16/T17/T22/T46/T47/T48/T49/T50 lulus dengan bukti. Jangan menutup task jika hanya posisi yang dipulihkan atau belum pernah menutup dan membuka aplikasi."*

2. **Existing Domain Snapshots in Codebase:**
   - `scripts/inventory/inventory_manager.gd:348-367`:
     `get_save_snapshot() -> Dictionary` returns `backpack`, `storage_home`, `kitchen_refund`, `starter_claimed`.
     `load_save_snapshot(data: Dictionary) -> bool` restores them.
   - `scripts/recipe/recipe_manager.gd:240-285`:
     `get_save_snapshot() -> Dictionary` returns `version`, `tracked_recipe_id`, `cooking_state`, `recipes`, `unlocked_notes`.
     `load_save_snapshot(data: Dictionary) -> bool` restores them.
   - `scripts/gardening/garden_manager.gd:633-652`:
     `get_save_snapshot() -> Dictionary` returns `version`, `active_tool`, `watering_can_water`, `plots`.
     `load_save_snapshot(data: Dictionary) -> bool` restores them.
   - `scripts/world/world_resource_manager.gd:311-341`:
     `get_save_snapshot() -> Dictionary` returns `version`, `current_day`, `day_active_time`, `meal_used`, `last_harvested_day`.
     `load_save_snapshot(data: Dictionary) -> bool` restores them.
   - `scripts/cooking/kitchen_manager.gd:834-880`:
     `get_save_snapshot() -> Dictionary` returns `version`, `job_state`, `active_job_id`, `active_recipe_id`, `prep_progress`, `cook_progress`, `heat_level`, `reserved_ingredients`, `origin_manifest`, `dish_output_slot`.
     `load_save_snapshot(data: Dictionary) -> bool` restores them.
   - `scripts/social/dialogue_manager.gd:472-520`:
     `get_save_snapshot() -> Dictionary` returns `version`, `has_spoken_intro`, `has_shared_meal`, `meal_used`, `p0_completed`, `dialogue_flags`.
     `load_save_snapshot(data: Dictionary) -> bool` restores them.

3. **Level Coordinates and Safe Spawn Points:**
   - In `scripts/player/player_config.gd:27-28`:
     `DEFAULT_SAFE_RETURN_POSITION = Vector3(0.0, 0.0, 8.0)` (`safe_return_home`)
     `DEFAULT_SPAWN_POSITION = Vector3(0.0, 0.0, 1.0)` (`spawn_home`)
   - In `scripts/world/level_graybox.gd:93-104`:
     Outer boundary envelope check: `X in [-42.0, 42.0]`, `Z in [-37.0, 47.0]`, `Y >= -5.0`. Below or outside redirects to `safe_return_home`.

4. **Test Harness Architecture:**
   - In `tests/test_runner.gd:1-143`: 18 test suites currently registered (Suite 1 to Suite 18), accumulating assertions in `tests/assertions.gd` and exiting non-zero if `Assertions.current_suite_failed > 0`.
   - Engine binary located at `C:\Users\HP\.local\bin\godot.exe` executing headless tests without window creation.

---

## 2. Logic Chain

1. **From Observation 1 & 2:** The project's acceptance criteria require complete, automated, end-to-end verification of save/load mechanics before `SAVE-001` can be closed. While each domain manager implements snapshot serialization, there is currently no standalone `tests/suites/test_save.gd` verifying filesystem persistence, error recovery, file corruption fallback, and atomic swaps.
2. **From Observation 2 & 3:** To test T22, the test suite must test the player position validator against non-finite floats (`is_nan()`, `is_inf()`) and out-of-bounds coordinates, ensuring the player is safely teleported to `Vector3(0, 0, 8)` without mutating items or quest progress.
3. **From Observation 1 & 4:** To test T16, T17, T47, T48, and T49 without polluting or destroying real user data on disk (`user://saves/` and `user://settings.cfg`), the test suite must operate within a clean, isolated sandbox (`user://test_save_sandbox/`).
4. **From Observation 1:** Atomic write safety requires testing the `.tmp` staging, `.bak` rotation, and verifying that partial write failures do not corrupt the existing primary save file.
5. **From Observation 4:** Integrating `TestSave` as Suite 19 in `tests/test_runner.gd` allows the automated CLI test runner to execute all save acceptance tests headlessly and fail CI with exit code 1 if any assertion breaks.

---

## 3. Caveats

1. **SaveManager Implementation Pending:** `scripts/save/save_manager.gd` has not yet been authored by the implementation worker. The test suite blueprint provides the exact contracts (`set_save_directory`, `set_settings_path`, `save_game`, `load_game`, `get_latest_save_info`) that the worker must satisfy.
2. **Async vs Sync I/O:** Godot `FileAccess` and `DirAccess` operate synchronously on desktop, which is ideal for headless CLI execution. If the implementer decides to use threaded I/O later, assertions will need `await` signals. Current design uses synchronous atomic file operations matching `save-systems` skill Pattern #2.
3. **No Caveats on PRD Alignment:** All test fixtures strictly adhere to CONTENT.md item IDs, maximum stack sizes (20), and 12-slot inventory capacities.

---

## 4. Conclusion

The specification for `tests/suites/test_save.gd` is fully designed and documented in `analysis.md`. It covers:
- **T14:** 2 test methods (backpack/storage preservation + paused job & agricultural timers).
- **T16:** 3 test methods (missing sections rejection + invalid item ID rejection + atomic all-or-nothing staging).
- **T17:** 3 test methods (fallback to `.bak` on primary corruption + clean failure on total corruption + 0-byte file resilience).
- **T22:** 3 test methods (NaN/Inf redirection + out-of-bounds redirection + valid coordinate preservation).
- **T46:** 2 test methods (garden plot/crop restoration + kitchen job/reservations/refund restoration).
- **T47:** 3 test methods (atomic `.tmp` creation + existing save unharmed during write failure + temporary file cleanup).
- **T48:** 4 test methods (slot isolation + "Lanjutkan" newest revision selection + explicit manual selection + backup creation).
- **T49:** 3 test methods (standalone `settings.cfg` format + settings preservation on game load/new game + corruption isolation).
- **T50:** 2 test methods (full P0 7-manager roundtrip + idempotent multi-cycle roundtrip).
- **Runner Registration:** Blueprint to register as Suite 19 in `tests/test_runner.gd`.

---

## 5. Verification Method

1. **Inspection of Specifications:**
   - Inspect `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_save_001_3\analysis.md`.
2. **Headless Execution Verification (Post-Implementation):**
   - Once the worker implements `scripts/save/save_manager.gd` and `tests/suites/test_save.gd`, verify using:
     ```powershell
     & "C:\Users\HP\.local\bin\godot.exe" --headless --path . --script res://tests/test_runner.gd
     ```
   - Check process exit code equals `0`.
   - Inspect `test_summary.log` to confirm all suites passed with 0 failures.
3. **Invalidation Conditions:**
   - Any test using live user save paths instead of `user://test_save_sandbox/`.
   - Modifying live world state when a corrupted snapshot is passed (violating T16).
   - Teleporting player without preserving items/progress during recovery (violating T22).
