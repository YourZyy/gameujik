# Dispatch for worker_cook_002

## Objective
Implementasikan seluruh fungsionalitas milestone `COOK-002` (Kontrol Panas, Timer Memasak 30s, Jeda Simulasi saat Panel Ditutup, Slot Output Tunggal, Penanganan Tas Penuh, Centang Buku Resep, Aksi Makan Hidangan dari Tas, dan Test Suite 13):

1. **Backend `scripts/cooking/kitchen_manager.gd`**:
   - `enum HeatLevel { LOW = 0, MEDIUM = 1, HIGH = 2 }`
   - Pengali panas: `LOW = 0.5`, `MEDIUM = 1.0`, `HIGH = 0.0`
   - Nilai default panas saat awal: `HeatLevel.LOW`
   - Warning pada `HIGH`: pemicu peringatan stall ("Kecilkan panas ke Sedang.") tanpa membakar/merusak bahan.
   - Konstanta durasi `COOK_DURATION = 30.0`. Variabel `cook_progress: float = 0.0`.
   - Method `start_cooking(initial_heat: int = HeatLevel.LOW) -> Dictionary`
   - Method `advance_cooking(delta: float) -> Dictionary` (menambah progres efektif = delta * multiplier)
   - Method `pause_cooking() -> Dictionary` (transisi `COOKING` -> `PAUSED`, update status di RecipeManager)
   - Method `resume_cooking() -> Dictionary` (transisi `PAUSED` -> `COOKING`, update status di RecipeManager)
   - Method `set_heat_level(level: int) -> bool`
   - Sinyal: `cooking_started`, `cooking_progress_updated`, `cooking_paused`, `cooking_resumed`, `cooking_completed`, `heat_level_changed`, `heat_stall_warning`, `dish_collected`, `dish_consumed`.
   - Output Masakan: Saat 100%, commit 1 unit `dish_sayur_bening` ke `dish_output_slot`, konsumsi permanen reservasi, panggil `RecipeManager.record_recipe_cooked(active_recipe_id)`.
   - Tolak mulai persiapan baru jika `dish_output_slot` belum kosong.
   - Method `claim_dish_output() -> Dictionary` / `take_dish_output()`: cek kapasitas tas. Jika tas penuh (12/12), hidangan tetap bertahan di `dish_output_slot` stasiun dapur tanpa rusak/hilang (T15). Jika ada ruang, pindahkan ke tas.
   - Method `eat_dish() -> Dictionary`: konsumsi 1 `dish_sayur_bening` dari tas secara atomik, set flag `meal_used = true`, beri pesan jujur `"Hangat. Resep pertama berhasil dibuat."` tanpa hunger bar.
   - Interlock kasur tidur: modifikasi `is_job_active()` agar mengecualikan `OUTPUT_READY` (pemain boleh tidur jika hidangan sudah matang).
   - Save snapshot envelope v1: pastikan `cook_progress`, `cook_duration`, `heat_level`, dan `meal_used` tersimpan dan dapat dipulihkan.

2. **Antarmuka Dapur (`scenes/ui/kitchen_ui.tscn` & `scripts/ui/kitchen_ui.gd`)**:
   - Tambahkan `CookingSection`: 3 tombol level panas (Rendah, Sedang, Tinggi), visual status aktif, ProgressBar & teks timer (`X.Xs / 30.0s`), panel peringatan visual saat Tinggi (*Heat Stall Warning*), dan tombol resume jika dalam keadaan `PAUSED`.
   - Tambahkan `OutputSection`: kartu hidangan selesai dan tombol *"Ambil Masakan"*.
   - Saat panel ditutup (`close()` / `_close_ui()`): jika stasiun sedang `COOKING`, panggil `pause_cooking()` agar tidak ada proses diam-diam di luar panel. Saat dibuka kembali, tampilkan status jeda dengan progres utuh.

3. **Tas / Inventaris (`scenes/ui/inventory_ui.tscn` & `scripts/ui/inventory_ui.gd`)**:
   - Sediakan aksi / tombol *"Makan"* pada DetailPanel saat item `dish_sayur_bening` di tas dipilih.
   - Menjalankan aksi makan, mengurangi 1 hidangan, menetapkan `meal_used = true`, dan menampilkan notifikasi umpan balik jujur `"Hangat. Resep pertama berhasil dibuat."`.

4. **WorldResourceManager / State (`scripts/world/world_resource_manager.gd`)**:
   - Simpan dan sinkronkan flag `meal_used: bool` (default `false`), getter/setter `set_meal_used(val: bool)` dan `is_meal_used() -> bool`, serta serialisasi snapshot v1.

5. **Test Suite 13 (`tests/suites/test_cooking_heat.gd`) & `tests/test_runner.gd`**:
   - Bangun Suite 13 komprehensif menguji T12, T41, T42 (jeda panel), T15 (output slot & tas penuh), T19 (buku resep tidak centang prematur, aktivasi tepat saat 100%, increment `times_cooked`, masak ulang), dan T43 (aksi makan, `meal_used = true`, tanpa hunger bar).
   - Daftarkan Suite 13 di `tests/test_runner.gd`.
   - Pastikan SELURUH 13 suite lulus 100% via headless test runner:
     `& "C:\Users\HP\.local\bin\godot.exe" --headless --path . --script res://tests/test_runner.gd; exit $LASTEXITCODE`

## Mandatory Reading & Input Information
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen7\PROJECT.md`
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_cook_002_1\analysis.md`
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_cook_002_2\analysis.md`
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_cook_002_3\analysis.md`

## File Ownership
- `scripts/cooking/kitchen_manager.gd`
- `scenes/ui/kitchen_ui.tscn`
- `scripts/ui/kitchen_ui.gd`
- `scenes/ui/inventory_ui.tscn`
- `scripts/ui/inventory_ui.gd`
- `scripts/world/world_resource_manager.gd`
- `tests/suites/test_cooking_heat.gd`
- `tests/test_runner.gd`

## MANDATORY INTEGRITY WARNING
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Completion Criteria
1. Seluruh fitur COOK-002 berfungsi penuh, stabil, dan terintegrasi.
2. Suite 13 berhasil dibuat dan lulus 100%.
3. Seluruh 13 suite di `test_runner.gd` lulus dengan exit code 0 tanpa regresi pada suite sebelumnya.
4. Tulis handoff report di `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_cook_002\handoff.md` dan kirim ringkasan via `send_message`.


## 2026-10-28T15:28:41Z
Kamu bertugas sebagai worker_cook_002 (Implementation Worker) untuk milestone COOK-002 pada proyek Buku Resep 2045.

Working directory kamu: c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_cook_002\

BACA TERLEBIH DAHULU:
1. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md
2. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen7\PROJECT.md
3. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_cook_002\DISPATCH.md
4. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_cook_002_1\analysis.md
5. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_cook_002_2\analysis.md
6. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_cook_002_3\analysis.md
