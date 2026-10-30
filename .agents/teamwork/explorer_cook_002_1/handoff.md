# Handoff Report: Eksplorasi Arsitektur Backend KitchenManager (Milestone COOK-002)

**Pelaksana:** explorer_cook_002_1 (Read-Only Explorer)  
**Tujuan Penerima:** Orchestrator (1d9704e2-e24b-4874-94a6-da7e19cbe1fd) / Implementer COOK-002  
**Tanggal:** 28 Oktober 2026  
**Tipe Handoff:** Hard (Task complete)  

---

## 1. Observation

1. **Struktur Enum `JobState` pada `scripts/cooking/kitchen_manager.gd` (baris 8–17):**
   ```gdscript
   enum JobState {
       IDLE = 0,
       RESERVED_PREPARING = 1,
       PREPARING = 1,
       READY_TO_HEAT = 2,
       COOKING = 3,
       PAUSED = 4,
       OUTPUT_READY = 5,
       REFUND_PENDING = 6
   }
   ```
   State `COOKING = 3`, `PAUSED = 4`, dan `OUTPUT_READY = 5` sudah dideklarasikan sejak COOK-001, namun logika transisi masuk, eksekusi timer, dan keluar dari ketiga status tersebut belum diimplementasikan.

2. **Gating Pembatalan Pra-Masak (`scripts/cooking/kitchen_manager.gd` baris 342):**
   ```gdscript
   if job_state != JobState.RESERVED_PREPARING and job_state != JobState.READY_TO_HEAT:
       return {"success": false, "reason": "Tidak ada persiapan yang dapat dibatalkan."}
   ```
   Fungsi pembatalan `cancel_preparation()` secara otomatis menolak pembatalan saat berada pada `COOKING`, `PAUSED`, atau `OUTPUT_READY`.

3. **Interlock Istirahat / Kasur Tidur (`scripts/cooking/kitchen_manager.gd` baris 118–119 & `scripts/world/world_resource_manager.gd` baris 242–246):**
   Pada `kitchen_manager.gd`:
   ```gdscript
   func is_job_active() -> bool:
       return job_state != JobState.IDLE and job_state != JobState.REFUND_PENDING
   ```
   Pada `world_resource_manager.gd`:
   ```gdscript
   if km != null and km.has_method("is_job_active") and km.is_job_active():
       return {"success": false, "reason": "Selesaikan atau batalkan proses memasak dahulu sebelum istirahat."}
   ```
   Namun, pada `docs/CONTENT.md` § 9 baris 164 tercatat:
   > *"Istirahat ditolak saat job dapur masih aktif; lanjutkan job atau batalkan bila masih di tahap persiapan. Output yang sudah selesai tidak menghalangi istirahat."*
   Saat `job_state == JobState.OUTPUT_READY`, `is_job_active()` saat ini masih mengembalikan `true`.

4. **Katalog Item & Definisi Hidangan (`scripts/inventory/items_data.gd` baris 125–134):**
   Item `dish_sayur_bening` sudah terdaftar secara resmi di `ItemsData` dengan nama *"Sayur Bening Bayam dan Jagung"*, batas tumpukan 20, dan kategori `"masakan"`.

5. **Pengendali Resep & Penghitungan Memasak (`scripts/recipe/recipe_manager.gd` baris 165–188):**
   `RecipeManager.record_recipe_cooked(recipe_id)` sudah mendukung penambahan `times_cooked` dan memancarkan `recipe_completed` hanya jika `prev_times == 0`. Method `set_cooking_state(state)` juga sudah mendukung status `"cooking"`, `"paused"`, dan `"output_ready"`.

6. **Status Pengujian Awal:**
   Perintah verifikasi headless:
   `& "C:\Users\HP\.local\bin\godot.exe" --headless --path . --script res://tests/test_runner.gd`
   menghasilkan: `Assertions Passed: 1695, Assertions Failed: 0, RESULT: ALL SUITES PASSED (Exit Code: 0)`.

---

## 2. Logic Chain

1. Dari Observasi 1 dan 5: Karena enum `JobState` dan `RecipeManager` sudah memiliki definisi status `COOKING`, `PAUSED`, dan `OUTPUT_READY`, penambahan alur memasak untuk COOK-002 tidak memerlukan perombakan arsitektur, melainkan implementasi transisi state:
   - `start_cooking()` berpindah dari `READY_TO_HEAT` ke `COOKING` dengan inisialisasi `current_heat_level = HeatLevel.LOW`.
   - `advance_cooking(delta)` mengakumulasi `cook_progress += delta * multiplier` hingga mencapai `COOK_DURATION = 30.0`.
   - `pause_cooking()` berpindah ke `PAUSED` saat panel UI ditutup, dan `resume_cooking()` kembali ke `COOKING`.
   - Saat mencapai 30.0s, sistem memanggil `_complete_cooking()`, berpindah ke `OUTPUT_READY`, mengisi `dish_output_slot`, mengonsumsi bahan reservasi, dan memanggil `RecipeManager.record_recipe_cooked()`.

2. Dari Observasi 1 dan dokumen `CONTENT.md` § 4:
   - Panas Rendah (`HEAT_LOW = 0`) membutuhkan multiplier `0.5`.
   - Panas Sedang (`HEAT_MEDIUM = 1`) membutuhkan multiplier `1.0`.
   - Panas Tinggi (`HEAT_HIGH = 2`) membutuhkan multiplier `0.0` (stall) dan memancarkan pesan `"Kecilkan panas ke Sedang."` tanpa merusak bahan.

3. Dari Observasi 3:
   - `is_job_active()` harus dimodifikasi menjadi:
     `return job_state != JobState.IDLE and job_state != JobState.REFUND_PENDING and job_state != JobState.OUTPUT_READY`
     agar pemain dapat tidur saat hidangan telah selesai dibuat namun belum diambil dari slot hasil.

4. Dari Observasi 4 dan dokumen `CONTENT.md` § 10 / `TEST_PLAN.md` T43:
   - Method `eat_dish()` di `KitchenManager` mengonsumsi 1 unit `dish_sayur_bening` dari tas pemain dan menetapkan `meal_used = true` serta mengembalikan pesan `"Hangat. Resep pertama berhasil dibuat."`.

5. Dari Observasi 2:
   - Gating `cancel_preparation()` yang sudah ada menjamin bahwa bahan tidak dapat ditarik kembali setelah memasak dimulai, menjaga kekekalan materi.

---

## 3. Caveats

1. **UI CanvasLayer Node Hierarchy:** Scene `kitchen_ui.tscn` saat ini belum memiliki node kontrol khusus untuk `CookingSection` (meteran masak, tombol panas, warning label) dan `OutputSection` (tombol ambil hidangan). File scene `.tscn` atau skrip kontroler `kitchen_ui.gd` perlu dilengkapi oleh agent implementer.
2. **Flag `meal_used` Global:** Saat ini flag `meal_used` belum dideklarasikan di Autoload lain seperti `WorldResourceManager`. Menempatkannya di `KitchenManager` (dan mengeksposnya ke save snapshot) mencukupi kebutuhan P0 milestone COOK-002 hingga nanti terintegrasi dengan `SAVE-001`.
3. **Pemberitahuan Reticle HUD:** Prompt reticle di `scripts/ui/hud.gd` (baris 458–467) sudah siap mendeteksi `has_ready_output()`, `is_cooking_active()`, dan `is_job_active()`, sehingga perubahan backend akan langsung tercermin di reticle tanpa perubahan drastis di HUD.

---

## 4. Conclusion

Arsitektur stasiun dapur saat ini siap 100% untuk dieksekusi pada milestone COOK-002. Rencana implementasi teknis telah dirumuskan secara terperinci di `.agents/teamwork/explorer_cook_002_1/analysis.md`, mencakup:
- Penambahan enum `HeatLevel` (`LOW`, `MEDIUM`, `HIGH`) dan pemetaan multiplier (`0.5`, `1.0`, `0.0`).
- Implementasi transisi `COOKING`, `PAUSED`, dan `OUTPUT_READY`.
- Penguncian timer saat UI ditutup (jeda simulasi anti-background cooking).
- Commit 1 masakan `dish_sayur_bening` ke `dish_output_slot` dan pemanggilan `RecipeManager.record_recipe_cooked()`.
- Penanganan kapasitas tas penuh saat pengambilan hidangan (retensi T15).
- Method konsumsi `eat_dish()` dengan penetapan `meal_used = true` (T43).
- Serialisasi snapshot envelope v1 lengkap dengan progres masak, panas, dan output slot.

---

## 5. Verification Method

Implementasi COOK-002 nantinya dapat diverifikasi secara mandiri melalui:

1. **Perintah Runner Otomatis Proyek:**
   ```powershell
   & "C:\Users\HP\.local\bin\godot.exe" --headless --path . --script res://tests/test_runner.gd; exit $LASTEXITCODE
   ```
2. **Kondisi Invalidasi (Kegagalan):**
   - Waktu kemajuan memasak pada panas Rendah tidak sama dengan 0.5x kecepatan nominal.
   - Waktu kemajuan memasak pada panas Tinggi bertambah (> 0.0x) atau bahan hangus/hancur.
   - Timer memasak terus bertambah saat panel dapur ditutup (`JobState.PAUSED`).
   - Persiapan baru dapat dimulai saat `dish_output_slot` masih terisi hidangan sebelumnya.
   - Mengambil hidangan saat tas penuh menghapus atau menghilangkan hidangan.
   - Memasak ulang resep (T19) memancarkan sinyal `recipe_completed` ganda.
   - Pemain tidak dapat tidur saat status adalah `OUTPUT_READY`.
