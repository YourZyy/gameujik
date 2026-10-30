# Dispatch for explorer_cook_002_3

## Objective
Lakukan eksplorasi teknis mengenai integrasi RecipeManager, verifikasi acceptance, dan arsitektur pengujian otomatis Test Suite 13 untuk milestone `COOK-002`:
1. Integrasi Buku Resep & RecipeManager (`scripts/recipe/recipe_manager.gd`):
   - Mekanisme penandaan resep selesai (`is_cooked = true` / `completed = true`) hanya setelah hidangan selesai dimasak (100%).
   - Peningkatan counter `times_cooked += 1`.
   - Update HUD tracker (tas, peti, dan status selesai).
2. Desain Test Suite 13 (misal: `tests/suites/test_cooking_heat.gd` atau integrasi di `test_cooking.gd`):
   - Memetakan kasus uji untuk kriteria penerimaan:
     - T12: Transisi diskrit ke COOKING, jeda saat panel ditutup, resume saat dibuka tanpa kehilangan progres.
     - T15: Output masakan tunggal di `dish_output_slot`, penolakan start masak baru sebelum output diambil.
     - T19: Centang buku resep tidak boleh aktif prematur; aktif tepat saat selesai; counter bertambah.
     - T41: Validasi empiris 3 tingkat panas (Rendah 0.5x, Sedang 1.0x, Tinggi 0.0x stall warning).
     - T42: Aksi makan hidangan dari tas (`action_eat`), pengurangan item, bendera `meal_used = true`.
3. Pendaftaran di `tests/test_runner.gd` dan kompatibilitas headless test runner.

## Scope Boundaries
- Read-only exploration. JANGAN mengubah kode sumber secara langsung.
- Pastikan desain tes independen, deterministik, dan dapat dijalankan via CLI headless Godot.

## Mandatory Reading
- Original Request: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
- Master Project: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen7\PROJECT.md`
- Test Plan: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\docs\TEST_PLAN.md` (T12, T15, T19, T41, T42)
- Existing test runner & assertions: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\tests\test_runner.gd` & `tests\assertions.gd`
- Existing recipe manager: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\scripts\recipe\recipe_manager.gd`

## Output Requirements
Tulis laporan analisis lengkap di `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_cook_002_3\analysis.md` dan ringkasannya via `send_message` ke orchestrator.


## 2026-10-28T15:16:49Z
Received dispatch from parent orchestrator (1d9704e2-e24b-4874-94a6-da7e19cbe1fd):
Task: explorer_cook_002_3 (Read-Only Explorer) untuk milestone COOK-002.
Eksplorasi teknis integrasi RecipeManager dan desain otomatis Test Suite 13 (T12, T15, T19, T41, T42).
