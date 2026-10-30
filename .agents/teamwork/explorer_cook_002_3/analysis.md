# Laporan Analisis Teknis: Integrasi RecipeManager dan Arsitektur Test Suite 13 (COOK-002)

**Explorer:** `explorer_cook_002_3` (Read-Only Systems & Test Architect)  
**Milestone:** COOK-002 (Kontrol Panas, Timer Memasak, Jeda Panel, Output Tunggal, Centang Buku & Aksi Makan)  
**Tanggal:** 28 Oktober 2026  
**Dokumen Acuan:** `PRD.md`, `docs/CONTENT.md` § 4/10/11/12, `docs/PROTOTYPE.md` § 4/5/6.2/6.3, `docs/TEST_PLAN.md` (T12, T15, T19, T41, T42, T43), `AGENTS.md`  

---

## 1. Ringkasan Eksekutif

Milestone COOK-002 merupakan kelanjutan langsung dari COOK-001 (Validasi Bahan, Reservasi Atomik, Tahan Persiapan 4s, Pembatalan Aman, dan Wadah Refund). Fokus investigasi `explorer_cook_002_3` adalah:
1. **Integritas Buku Resep (`RecipeManager`):** Memastikan penandaan resep selesai (`is_completed = true` / `times_cooked > 0`) tidak pernah terjadi secara prematur pada tahap persiapan, pemanasan awal, jeda, maupun pembatalan; centang selesai dan increment counter `times_cooked += 1` terjadi tepat saat hidangan 100% selesai dimasak (pada transisi ke `OUTPUT_READY`). Pada siklus masak ulang (remake), centang tetap dipertahankan dan counter bertambah menjadi 2 tanpa memancarkan sinyal `recipe_completed` ganda (T19).
2. **Arsitektur Test Suite 13 (`tests/suites/test_cooking_heat.gd`):** Merancang test suite penerimaan formal berstandar headless CLI Godot 4.7.2 yang mencakup seluruh kriteria penerimaan inti:
   - **T12:** Transisi diskrit dari `READY_TO_HEAT` ke `COOKING` melalui tombol/aksi mulai masak, perlindungan anti-spam klik berulang tanpa duplikasi job atau mutasi ganda.
   - **T41:** Validasi empiris 3 tingkat panas (Rendah 0.5x, Sedang 1.0x, Tinggi 0.0x stall warning + proteksi kekekalan bahan).
   - **T42 (Cooking Pause):** Jeda job saat panel dapur ditutup (`PAUSED`), penghentian tick memasak di dunia luar, dan resume utuh saat panel dibuka kembali tanpa kehilangan progres.
   - **T15:** Output masakan tunggal di `dish_output_slot`, penolakan mulai persiapan baru selama slot output belum diambil, dan transfer hidangan ke tas pemain dengan verifikasi kapasitas.
   - **T19:** Invarian buku resep tidak centang prematur, aktivasi tepat saat 100%, increment `times_cooked`, dan penanganan masak ulang.
   - **T42/T43 (Makan Hidangan):** Aksi makan hidangan dari tas (`action_eat`), pengurangan 1 unit secara atomik, penetapan flag progres `meal_used = true`, umpan balik jujur `"Hangat. Resep pertama berhasil dibuat."`, evaluasi penutup P0 (`is_completed and meal_used`), tanpa sistem hunger meter/buff statistik.
3. **Pendaftaran Runner:** Mendaftarkan Suite 13 pada `tests/test_runner.gd` sebagai suite ke-13 yang sepenuhnya deterministik, bebas flakiness, dan terintegrasi dengan pipeline CLI `--headless`.

---

## 2. Analisis Integrasi RecipeManager & Buku Resep

### 2.1 Siklus Hidup Resep (Recipe Lifecycle) & Invarian Centang

Berdasarkan `CONTENT.md` § 4, `PRD.md` FR03/FR04, dan `scripts/recipe/recipe_data.gd`, resep Sayur Bening Bayam dan Jagung (`recipe_sayur_bening_01`) memiliki siklus status sebagai berikut:

```
[Bahan Kurang] (can_cook = false, is_completed = false, times_cooked = 0)
       │
       ▼ (Kumpulkan 3 bayam, 1 jagung, 1 temu kunci)
[Siap Dimasak] (can_cook = true, is_completed = false, times_cooked = 0)
       │
       ▼ (start_preparation di station_kitchen_home)
[RESERVED_PREPARING (0.0s - 4.0s)] (times_cooked = 0, is_completed = false)
       │
       ▼ (advance_prep mencapai 4.0s)
[READY_TO_HEAT] (times_cooked = 0, is_completed = false)
       │
       ▼ (start_cooking: Rendah / Sedang / Tinggi)
[COOKING (0.0s - 29.9s)] (times_cooked = 0, is_completed = false)
       │ ├── (Panel Ditutup) ──► [PAUSED] (times_cooked = 0, is_completed = false)
       │ └── (Panel Dibuka)   ──► [COOKING] (melanjutkan progres)
       │
       ▼ (cook_progress >= 30.0s efektif)
[OUTPUT_READY] (dish_output_slot terisi 1 dish_sayur_bening)
       │  ===> EKSEKUSI: rm.record_recipe_cooked("recipe_sayur_bening_01")
       │  ===> times_cooked = 1, is_completed = true, signal recipe_completed
       │
       ▼ (take_dish_output -> hidangan masuk tas)
[IDLE (Selesai)] (times_cooked = 1, is_completed = true)
       │
       ▼ (Masak Ulang: Kumpulkan bahan lagi -> Persiapan -> Memasak ke-2)
[COOKING #2 (0.0s - 29.9s)] (times_cooked = 1, is_completed = true [centang tetap aktif])
       │
       ▼ (cook_progress >= 30.0s)
[OUTPUT_READY #2]
       │  ===> EKSEKUSI: rm.record_recipe_cooked("recipe_sayur_bening_01")
       │  ===> times_cooked = 2, is_completed = true (sinyal recipe_completed TIDAK diulang)
```

### 2.2 Pencegahan Centang Prematur (No Premature Checkmark Invariant)

Dalam `scripts/recipe/recipe_data.gd` (baris 24-27):
```gdscript
var is_completed: bool:
	get:
		return times_cooked > 0
```
Status `is_completed` dan centang `✓` di `BookUI` maupun tracker `HUD` sepenuhnya ditentukan oleh `times_cooked > 0`.

**Aturan Invarian Centang:**
1. Sebelum hidangan mencapai 100% matang, nilai `times_cooked` **WAJIB TETAP 0**.
2. Di state `IDLE`, `RESERVED_PREPARING`, `READY_TO_HEAT`, `COOKING`, dan `PAUSED`:
   - `rm.is_recipe_completed("recipe_sayur_bening_01")` harus bernilai `false`.
   - `BookUI.bottom_status_badge` tidak boleh memunculkan simbol `✓` atau teks `"telah diselesaikan"`. Badge harus menampilkan `"Status: Belum dimasak"` atau `"Status: Siap dimasak"` (jika bahan di tas/peti cukup).
   - Tracker `HUD` tidak boleh menampilkan `"Resep selesai. Boleh dimasak ulang."`.
3. Pembatalan pada tahap persiapan (`cancel_preparation`) dilarang memengaruhi status resep (tetap `times_cooked = 0`).
4. **Pemicu Tunggal Selesai:** Satu-satunya baris kode dalam seluruh arsitektur game yang diizinkan memanggil `rm.record_recipe_cooked("recipe_sayur_bening_01")` adalah saat transisi dari `COOKING` ke `OUTPUT_READY` di dalam `KitchenManager._finish_cooking()`.

### 2.3 Mekanisme Peningkatan Counter `times_cooked += 1` dan Idempotensi Sinyal

Dalam `scripts/recipe/recipe_manager.gd` (baris 165-175):
```gdscript
func record_recipe_cooked(recipe_id: String) -> void:
	var recipe = get_recipe(recipe_id)
	if recipe == null:
		return
	
	var prev_times: int = int(recipe.times_cooked)
	recipe.times_cooked = prev_times + 1
	if prev_times == 0:
		recipe_completed.emit(recipe_id)
	recipe_updated.emit(recipe_id)
```

**Analisis Perilaku:**
- **Masakan Pertama (times_cooked: 0 $\to$ 1):**
  - `prev_times == 0` terpenuhi.
  - Sinyal `recipe_completed.emit("recipe_sayur_bening_01")` terpancar untuk pertama dan satu-satunya kali.
  - Sinyal `recipe_updated.emit("recipe_sayur_bening_01")` memicu pembaruan UI.
  - Di `BookUI`: Badge status berubah menjadi `"✓ Resep telah diselesaikan (1 kali dimasak). Boleh dimasak ulang."`
- **Masakan Kedua / Remake (times_cooked: 1 $\to$ 2 per T19):**
  - `prev_times == 1` ($> 0$).
  - `recipe.times_cooked` bertambah menjadi 2.
  - Sinyal `recipe_completed` **TIDAK DIPANCARKAN LAGI** (`prev_times == 0` bernilai false). Hal ini menjamin kontrak T19: *"centang tidak dihapus/diulang sebagai hadiah ganda"*.
  - Sinyal `recipe_updated` terpancar.
  - Di `BookUI`: Badge status diperbarui menjadi `"✓ Resep telah diselesaikan (2 kali dimasak). Boleh dimasak ulang."`

### 2.4 Sinkronisasi HUD Tracker & Book UI

1. **Sinkronisasi Cooking State (`cooking_state`):**
   - Di `KitchenManager`, saat bertransisi ke state baru, singleton wajib memanggil `rm.set_cooking_state(state_name)`:
     - `RESERVED_PREPARING` $\to$ `rm.set_cooking_state("preparing")`
     - `READY_TO_HEAT` $\to$ `rm.set_cooking_state("ready_to_heat")`
     - `COOKING` $\to$ `rm.set_cooking_state("cooking")`
     - `PAUSED` $\to$ `rm.set_cooking_state("paused")`
     - `OUTPUT_READY` $\to$ `rm.set_cooking_state("output_ready")`
     - `IDLE` $\to$ `rm.set_cooking_state("idle")`
2. **Respon HUD Tracker (`scripts/ui/hud.gd` lines 141-161):**
   - Saat `cooking_state == "cooking"`: `tracker_status_label.text = "Sedang memasak..."` (kuning-emas).
   - Saat `cooking_state == "paused"`: `tracker_status_label.text = "Masakan dijeda"` (oranye per `CONTENT.md` § 11).
   - Saat `cooking_state == "output_ready"`: Menampilkan `"Hidangan matang! Ambil di dapur."` atau beralih ke status selesai.
   - Saat `is_completed == true` dan tidak sedang memasak: `tracker_status_label.text = "Resep selesai. Boleh dimasak ulang."` (hijau).
3. **Stok Bahan Bebas Terpadu Saat Memasak:**
   - Karena bahan telah ditarik secara fisik dari tas/peti saat `start_preparation()` (COOK-001), `InventoryManager.get_available_item_count()` secara akurat merefleksikan pengurangan bahan tersebut.
   - Angka bahan pada HUD dan Book UI langsung menunjukkan jumlah yang tersisa di tas + peti tanpa double deduction.

### 2.5 Serialisasi Status Resep pada Envelope Snapshot v1

Dalam `scripts/recipe/recipe_manager.gd` (baris 237-291), `get_save_snapshot()` dan `load_save_snapshot()` telah mendukung:
```json
{
  "version": 1,
  "tracked_recipe_id": "recipe_sayur_bening_01",
  "cooking_state": "cooking",
  "recipes": {
    "recipe_sayur_bening_01": {
      "times_cooked": 1,
      "is_tracked": true,
      "discovered": true
    }
  },
  "unlocked_notes": ["note_garden_01"]
}
```
Ketika save/load dilakukan pada COOK-002, nilai `times_cooked`, status centang, dan `cooking_state` terpulihkan secara deterministik.

---

## 3. Arsitektur & Desain Test Suite 13 (`tests/suites/test_cooking_heat.gd`)

### 3.1 Pemetaan Kasus Uji Penerimaan

Berdasarkan `docs/TEST_PLAN.md` dan mandat DISPATCH:

| Kode Uji | Deskripsi Skenario Pengujian | Kriteria Keberhasilan Acceptance |
|---|---|---|
| **T12** | Transisi diskrit ke `COOKING`, jeda saat panel ditutup, resume saat dibuka tanpa kehilangan progres | Klik tombol Mulai Memasak bertransisi ke `COOKING`. Tombol tahan 4s tidak otomatis memicu `COOKING`. Klik berulang ditolak secara idempotent tanpa reset timer. |
| **T41** | Validasi empiris 3 tingkat panas (Rendah 0.5x, Sedang 1.0x, Tinggi 0.0x stall warning) | Rendah: $\Delta t = 10\text{s} \to +5\text{s}$ progres (total 60s). Sedang: $\Delta t = 10\text{s} \to +10\text{s}$ progres (total 30s). Tinggi: $\Delta t = 10\text{s} \to +0\text{s}$ progres, warning aktif, bahan tidak hangus/hilang. Dynamic switching mulus. |
| **T42** | Jeda simulasi saat panel dapur ditutup (`PAUSED`) dan resume saat dibuka kembali | Menutup dapur saat `COOKING` mengubah status ke `PAUSED`. Simulasi waktu dunia tidak memajukan progres masak tertutup. Membuka dapur kembali melanjutkan dari posisi waktu sebelum jeda. Tracker HUD menampilkan `"Masakan dijeda"`. |
| **T15** | Slot output hidangan tunggal di `dish_output_slot` & blocking persiapan baru | Progres 100% menghasilkan 1 `dish_sayur_bening` di `dish_output_slot`. Persiapan masakan baru ditolak selama slot belum kosong (`"Ambil hidangan sebelumnya dahulu."`). Pengambilan hidangan memeriksa kapasitas tas (ditolak jika tas penuh tanpa kehilangan hidangan). |
| **T19** | Centang buku resep tidak boleh prematur; aktif tepat saat selesai 100%; counter bertambah pada siklus masak ulang | Di state 0% s/d 99.9%, `times_cooked == 0`, `is_completed == false`, tidak ada centang di buku/HUD. Pada 100%, `times_cooked = 1`, centang muncul, sinyal `recipe_completed` terpancar. Pada masak ulang, centang tetap aktif, `times_cooked = 2`, sinyal `recipe_completed` tidak dipancarkan ulang. |
| **T42 / T43** | Aksi makan hidangan dari tas (`action_eat` / `eat_dish`), pengurangan item atomik, dan evaluasi penutup P0 | Memakan hidangan mengurangi 1 unit `dish_sayur_bening` dari tas, memancarkan feedback jujur `"Hangat. Resep pertama berhasil dibuat."`, menetapkan `meal_used = true`. Evaluasi penutup P0 terpenuhi jika `is_completed and meal_used`. Tidak ada hunger bar / statistik buff. |

---

### 3.2 Desain Spesifikasi Uji Rinci (8 Grup Pengujian Komprehensif)

Test Suite 13 dirancang independen, menguji unit logika backend `KitchenManager`, integrasi `RecipeManager`, integrasi `InventoryManager`, interaksi `KitchenUI`, dan `HUD`.

#### Group 1: T41 — Empirical Heat Multipliers & Stall Warning Validation
- **`test_t41_heat_low_progression_half_speed()`**
  - Setup: Job pada state `READY_TO_HEAT`.
  - Atur tingkat panas ke `"low"` (`KitchenManager.set_heat_level("low")`).
  - Verifikasi multiplier = 0.5.
  - Panggil `KitchenManager.start_cooking("low")`.
  - Majukan waktu $\Delta t = 10.0$ detik melalui `advance_cooking(10.0)`.
  - Asersi: `cook_progress` bertambah tepat $5.0$ detik (`assert_approx_equal(km.cook_progress, 5.0, 0.05)`).
  - Majukan waktu $50.0$ detik lagi (total 60.0s).
  - Asersi: Tepat pada 60.0s, progres mencapai 30.0s (100%) dan bertransisi ke `OUTPUT_READY`.
- **`test_t41_heat_medium_progression_nominal_speed()`**
  - Setup: Job pada state `READY_TO_HEAT`.
  - Atur tingkat panas ke `"medium"`.
  - Verifikasi multiplier = 1.0.
  - Panggil `KitchenManager.start_cooking("medium")`.
  - Majukan waktu $\Delta t = 10.0$ detik.
  - Asersi: `cook_progress` bertambah tepat $10.0$ detik.
  - Majukan waktu $20.0$ detik lagi (total 30.0s).
  - Asersi: Tepat pada 30.0s, progres mencapai 30.0s (100%) dan bertransisi ke `OUTPUT_READY`.
- **`test_t41_heat_high_stall_and_matter_conservation()`**
  - Setup: Job `COOKING` pada panas `"high"`.
  - Verifikasi multiplier = 0.0.
  - Majukan waktu $\Delta t = 15.0$ detik.
  - Asersi: `cook_progress` tetap $0.0$ detik (tidak maju sama sekali).
  - Asersi: `km.is_heat_stalled()` mengembalikan `true`.
  - Asersi: Bahan masakan yang direservasi TIDAK hilang, TIDAK berkurang, dan tidak rusak (*matter conservation invariant*).
- **`test_t41_dynamic_heat_switching_mid_cook()`**
  - Mulai pada `"low"` selama 10.0s ($\to 5.0$s progres).
  - Ganti ke `"high"` selama 8.0s ($\to$ progres tetap $5.0$s, status stall).
  - Ganti ke `"medium"` selama 25.0s ($\to$ progres bertambah $25.0$s $\to$ mencapai $30.0$s).
  - Asersi: Transisi ke `OUTPUT_READY` sukses pada total waktu fisik $43.0$s.

#### Group 2: T12 — Discrete Cooking Transition & Anti-Spam Start
- **`test_t12_discrete_transition_from_ready_to_heat()`**
  - Dari `READY_TO_HEAT`, panggil `start_cooking()`.
  - Asersi: State berubah menjadi `JobState.COOKING`.
  - Asersi: `RecipeManager.cooking_state` menjadi `"cooking"`.
  - Asersi: Default panas awal adalah `"low"` per `CONTENT.md` § 4.
- **`test_t12_no_auto_cook_transition_from_prep()`**
  - Jalankan tahan persiapan dari 0 hingga 4.0s.
  - Saat mencapai 4.0s, stasiun berada pada `READY_TO_HEAT`.
  - Majukan waktu simulasi tanpa menekan Mulai Memasak.
  - Asersi: Stasiun TETAP di `READY_TO_HEAT` dan TIDAK otomatis masuk ke `COOKING`.
- **`test_t12_anti_spam_repeated_start_cooking_clicks()`**
  - Saat sedang `COOKING` pada `cook_progress = 12.0`s, panggil `start_cooking()` sebanyak 30 kali secara berturut-turut.
  - Asersi: Semua panggilan mengembalikan hasil idempotent (`success: false` atau `idempotent: true`).
  - Asersi: `cook_progress` tidak ter-reset kembali ke 0.
  - Asersi: `active_job_id` tidak berubah.
  - Asersi: Tidak ada pemotongan bahan tambahan dari inventaris.

#### Group 3: T42 — Cooking Pause on UI Close & World Simulation Invariance
- **`test_t42_panel_close_pauses_cooking_state()`**
  - Saat `COOKING` pada `cook_progress = 14.0`s, simulasikan penutupan panel dapur (`KitchenManager.pause_cooking()` atau `kitchen_ui.close()`).
  - Asersi: State bertransisi ke `JobState.PAUSED`.
  - Asersi: `RecipeManager.cooking_state` menjadi `"paused"`.
- **`test_t42_time_in_world_does_not_advance_paused_cooking()`**
  - Dalam kondisi `PAUSED`, jalankan simulasi tick dunia luar sebanyak 60 detik.
  - Asersi: `km.cook_progress` tetap tepat pada $14.0$ detik.
  - Asersi: Job tidak selesai di latar belakang.
- **`test_t42_panel_reopen_resumes_cooking_intact()`**
  - Simulasikan pembukaan kembali panel dapur (`KitchenManager.resume_cooking()` atau `kitchen_ui.open()`).
  - Asersi: State kembali ke `JobState.COOKING`.
  - Asersi: `cook_progress` mulai persis dari $14.0$s.
  - Majukan waktu $16.0$s pada panas `"medium"`.
  - Asersi: Hidangan matang tepat pada progres 30.0s.
- **`test_t42_hud_tracker_displays_paused_status()`**
  - Resep `recipe_sayur_bening_01` dilacak di `HUD`.
  - Saat dijeda, asersi label tracker HUD menampilkan teks `"Masakan dijeda"`.

#### Group 4: T15 — Single Dish Output Slot & Occupation Gating
- **`test_t15_100_percent_progress_yields_single_dish_in_output()`**
  - Progres mencapai 30.0s.
  - Asersi: `km.job_state == JobState.OUTPUT_READY`.
  - Asersi: `km.dish_output_slot` bernilai `{"item_id": "dish_sayur_bening", "count": 1}`.
  - Asersi: Bahan yang tadinya direservasi telah dikonsumsi penuh dari inventaris.
- **`test_t15_occupied_output_blocks_new_preparation()`**
  - Dalam kondisi `dish_output_slot` masih terisi:
  - Berikan bahan baru yang lengkap ke tas pemain (3 bayam, 1 jagung, 1 temu kunci).
  - Panggil `km.can_start_preparation()`.
  - Asersi: Mengembalikan `success: false` dengan alasan `"Ambil hidangan sebelumnya dahulu."`.
  - Panggil `km.start_preparation()`.
  - Asersi: Ditolak bersih, tidak ada job baru, tidak ada bahan ditarik.
- **`test_t15_take_output_rejected_when_backpack_full()`**
  - Penuhi seluruh 12 slot tas pemain dengan barang lain.
  - Panggil `km.take_dish_output()`.
  - Asersi: Mengembalikan `success: false` dengan alasan `"Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."`.
  - Asersi: `dish_output_slot` tetap utuh berisi 1 `dish_sayur_bening`.
- **`test_t15_take_output_success_clears_slot_and_returns_station_to_idle()`**
  - Kosongkan minimal 1 slot di tas pemain.
  - Panggil `km.take_dish_output()`.
  - Asersi: Mengembalikan `success: true`.
  - Asersi: Tas pemain kini memiliki 1 `dish_sayur_bening`.
  - Asersi: `km.dish_output_slot` kosong (`{}`).
  - Asersi: `km.job_state == JobState.IDLE`.
  - Asersi: Persiapan masakan baru kini diizinkan.

#### Group 5: T19 — Recipe Book Checkmark & Remake Count Invariant
- **`test_t19_no_premature_checkmark_before_100_percent()`**
  - Periksa status resep pada:
    1. Game baru / `IDLE`: `times_cooked == 0`, `is_completed == false`.
    2. Saat persiapan 2.0s: `times_cooked == 0`, `is_completed == false`.
    3. Saat `READY_TO_HEAT`: `times_cooked == 0`, `is_completed == false`.
    4. Saat `COOKING` 10.0s: `times_cooked == 0`, `is_completed == false`.
    5. Saat `COOKING` 29.9s: `times_cooked == 0`, `is_completed == false`.
    6. Saat `PAUSED`: `times_cooked == 0`, `is_completed == false`.
    7. Saat `cancel_preparation`: `times_cooked == 0`, `is_completed == false`.
  - Asersi: Di seluruh titik tersebut, `BookUI` badge tidak pernah menampilkan centang `✓` atau status Selesai.
- **`test_t19_completion_at_exact_100_percent_and_signal_emission()`**
  - Tepat saat progres mencapai 30.0s (transisi ke `OUTPUT_READY`):
  - Pantau sinyal `recipe_completed` pada `RecipeManager`.
  - Asersi: Sinyal `recipe_completed` terpancar tepat 1 kali.
  - Asersi: `recipe.times_cooked == 1`.
  - Asersi: `recipe.is_completed == true`.
  - Asersi: `BookUI` badge menampilkan `"✓ Resep telah diselesaikan (1 kali dimasak). Boleh dimasak ulang."`.
  - Asersi: HUD tracker menampilkan `"Resep selesai. Boleh dimasak ulang."`.
- **`test_t19_remake_cycle_increments_counter_and_preserves_checkmark()`**
  - Mulai memasak ulang untuk kedua kalinya.
  - Saat proses kedua sedang berjalan (15.0s):
    - Asersi: `times_cooked` tetap 1.
    - Asersi: Centang `✓` tetap aktif di buku (tidak direset atau dihapus).
  - Saat proses kedua mencapai 100%:
    - Asersi: `times_cooked` bertambah menjadi 2.
    - Asersi: Sinyal `recipe_completed` TIDAK terpancar lagi (mencegah double reward per T19).
    - Asersi: `BookUI` badge menampilkan `"✓ Resep telah diselesaikan (2 kali dimasak). Boleh dimasak ulang."`.

#### Group 6: T42/T43 — Dish Consumption (Makan Hidangan) & P0 Experience Closing
- **`test_t42_action_eat_consumes_one_portion_atomically()`**
  - Tambahkan 2 porsi `dish_sayur_bening` ke tas pemain.
  - Panggil aksi makan hidangan (`km.eat_dish()` atau method konsumsi tas).
  - Asersi: Jumlah hidangan di tas berkurang tepat 1 porsi (dari 2 menjadi 1).
  - Asersi: Flag `meal_used == true` di sistem permainan.
  - Asersi: Mengembalikan pesan umpan balik `"Hangat. Resep pertama berhasil dibuat."`.
- **`test_t42_action_eat_rejected_when_no_dish_in_backpack()`**
  - Pastikan tas tidak memiliki `dish_sayur_bening`.
  - Panggil aksi makan hidangan.
  - Asersi: Aksi ditolak (`success: false`).
  - Asersi: Mengembalikan pesan jujur Indonesia bahwa tidak ada masakan di tas.
- **`test_t42_p0_ending_flag_evaluation()`**
  - Kondisi 1: `is_completed == true` dan `meal_used == false` $\to$ P0 belum selesai (masih perlu makan atau berbagi).
  - Kondisi 2: `is_completed == true` dan `meal_used == true` $\to$ P0 selesai terpenuhi!
  - Asersi: Muncul notifikasi penutup P0: `"Satu resep selesai. Kebun ini baru dimulai."`.
- **`test_t42_action_eat_idempotency_and_no_hunger_bar()`**
  - Verifikasi bahwa makan hidangan tidak menambahkan statistik hunger meter atau buff numerik (mematuhi PRD § 4 dan batasan P0).

#### Group 7: Integrasi UI & HUD Feedback
- **`test_extra_kitchen_ui_heat_controls_wiring(tree)`**
  - Instance `KitchenUI` dari `.tscn`.
  - Verifikasi tombol Rendah, Sedang, Tinggi terhubung ke `KitchenManager.set_heat_level()`.
  - Verifikasi tampilan label stall warning saat panas Tinggi aktif.
  - Verifikasi tombol Ambil Masakan visible saat `job_state == OUTPUT_READY`.
- **`test_extra_hud_status_transitions_during_cooking()`**
  - Verifikasi perubahan label HUD saat state berubah dari `cooking` $\to$ `paused` $\to$ `output_ready` $\to$ `completed`.

#### Group 8: Save/Load Snapshot Envelope v1 Roundtrip
- **`test_extra_save_snapshot_preserves_heat_and_cooking_progress()`**
  - Simpan snapshot saat memasak dijeda pada 18.5s dengan panas `"low"`.
  - Muat snapshot pada instance baru.
  - Asersi: `job_state == PAUSED`, `current_heat == "low"`, `cook_progress == 18.5`.
  - Lanjutkan memasak dan verifikasi hidangan selesai normal.
- **`test_extra_save_snapshot_preserves_output_slot_and_completion()`**
  - Simpan snapshot saat hidangan siap di slot output.
  - Muat snapshot pada instance baru.
  - Asersi: `dish_output_slot` terpulihkan utuh, `times_cooked` terpulihkan utuh, slot output terkunci hingga diambil.

---

### 3.3 Struktur Kode Blueprint untuk `tests/suites/test_cooking_heat.gd`

Berikut adalah cetak biru struktur kelas dan metode untuk Suite 13:

```gdscript
class_name TestCookingHeat
extends RefCounted

## Test Suite COOK-002: Kontrol Panas, Timer Memasak 30s, Jeda Panel, Slot Output Tunggal,
## Centang Buku Resep, dan Aksi Makan Hidangan (Suite 13)
## Memverifikasi PRD FR12/FR13, CONTENT.md § 4, § 10, § 11, § 12, PROTOTYPE.md § 4, § 5, § 6.2, § 6.3,
## TASKS.md COOK-002, dan TEST_PLAN T12, T15, T19, T41, T42.

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const RecipeManagerClass = preload("res://scripts/recipe/recipe_manager.gd")
const KitchenManagerClass = preload("res://scripts/cooking/kitchen_manager.gd")
const KitchenUIClass = preload("res://scripts/ui/kitchen_ui.gd")
const HUDClass = preload("res://scripts/ui/hud.gd")

func run_all() -> bool:
	var passed := true
	print("  Running TestCookingHeat suite (T12, T15, T19, T41, T42, Heat Control & Dish Consumption)...")
	var tree := Engine.get_main_loop() as SceneTree

	# Group 1: T41 — Empirical Heat Multipliers & Stall Warning Validation
	if not test_t41_heat_low_progression_half_speed(): passed = false
	if not test_t41_heat_medium_progression_nominal_speed(): passed = false
	if not test_t41_heat_high_stall_and_matter_conservation(): passed = false
	if not test_t41_dynamic_heat_switching_mid_cook(): passed = false

	# Group 2: T12 — Discrete Cooking Transition & Anti-Spam Start
	if not test_t12_discrete_transition_from_ready_to_heat(): passed = false
	if not test_t12_no_auto_cook_transition_from_prep(): passed = false
	if not test_t12_anti_spam_repeated_start_cooking_clicks(): passed = false

	# Group 3: T42 — Cooking Pause on UI Close & World Simulation Invariance
	if not test_t42_panel_close_pauses_cooking_state(): passed = false
	if not test_t42_time_in_world_does_not_advance_paused_cooking(): passed = false
	if not test_t42_panel_reopen_resumes_cooking_intact(): passed = false
	if not test_t42_hud_tracker_displays_paused_status(): passed = false

	# Group 4: T15 — Single Dish Output Slot & Occupation Gating
	if not test_t15_100_percent_progress_yields_single_dish_in_output(): passed = false
	if not test_t15_occupied_output_blocks_new_preparation(): passed = false
	if not test_t15_take_output_rejected_when_backpack_full(): passed = false
	if not test_t15_take_output_success_clears_slot_and_returns_station_to_idle(): passed = false

	# Group 5: T19 — Recipe Book Checkmark & Remake Count Invariant
	if not test_t19_no_premature_checkmark_before_100_percent(): passed = false
	if not test_t19_completion_at_exact_100_percent_and_signal_emission(): passed = false
	if not test_t19_remake_cycle_increments_counter_and_preserves_checkmark(): passed = false

	# Group 6: T42/T43 — Dish Consumption (Makan Hidangan) & P0 Experience Closing
	if not test_t42_action_eat_consumes_one_portion_atomically(): passed = false
	if not test_t42_action_eat_rejected_when_no_dish_in_backpack(): passed = false
	if not test_t42_p0_ending_flag_evaluation(): passed = false
	if not test_t42_action_eat_idempotency_and_no_hunger_bar(): passed = false

	# Group 7 & 8: UI & Save Snapshot Roundtrip
	if not await test_extra_kitchen_ui_heat_controls_wiring(tree): passed = false
	if not test_extra_save_snapshot_preserves_heat_and_cooking_progress(): passed = false
	if not test_extra_save_snapshot_preserves_output_slot_and_completion(): passed = false

	return passed
```

---

## 4. Pendaftaran di Test Runner & Kompatibilitas Headless

### 4.1 Modifikasi `tests/test_runner.gd` (Suite 13 Registration)

Di `tests/test_runner.gd`:
1. Tambahkan preload skrip suite baru di header:
   ```gdscript
   const TestCookingHeat = preload("res://tests/suites/test_cooking_heat.gd")
   ```
2. Tambahkan pemanggilan suite setelah Suite 12 (`TestAdversarialCooking`):
   ```gdscript
   	# Suite 13: TestCookingHeat (T12, T15, T19, T41, T42 cooking heat control, pause, output & eating)
   	var suite_cooking_heat := TestCookingHeat.new()
   	if not await suite_cooking_heat.run_all():
   		all_passed = false
   ```

### 4.2 Kepatuhan Skill `godot-gdscript-headless-testing`

Sesuai instruksi pada skill `godot-gdscript-headless-testing`:
1. **SceneTree Script & Exit Code:** `test_runner.gd` mengeksekusi suite melalui `SceneTree` dan memanggil `quit(0)` jika `all_passed and Assertions.current_suite_failed == 0`, atau `quit(1)` jika ada kegagalan.
2. **Tidak Menggunakan Bare `assert()`:** Seluruh asersi pengujian menggunakan helper statis `Assertions.assert_equal()`, `assert_true()`, `assert_false()`, dan `assert_approx_equal()`. Helper ini menghitung jumlah `passed`/`failed` dan mencatat error ke `printerr`/`push_error` tanpa menghentikan runner di tengah jalan.
3. **Penanganan Asynchronous:** Metode uji yang melibatkan siklus frame UI dideklarasikan sebagai `async` dengan `await tree.process_frame`, dan pemanggilannya di `run_all()` diawali dengan `await`.
4. **Isolasi State Antar Tes:** Setiap metode uji menginisialisasi instance bersih `InventoryManagerClass.new()`, `RecipeManagerClass.new()`, dan `KitchenManagerClass.new()`, menyambungkan dependency override (`set_inventory_manager`, `set_recipe_manager`), dan membebaskannya (`free()`) setelah selesai agar tidak terjadi kebocoran state atau cross-test contamination.

---

## 5. Rekomendasi Teknis untuk Implementer (Worker) & Reviewer/Auditor

### 5.1 Kontrak Antarmuka Tambahan di `KitchenManager`

Untuk memenuhi seluruh kasus uji Suite 13, `KitchenManager` perlu dilengkapi dengan:

```gdscript
# Heat Control Constants & Properties
const HEAT_LOW: String = "low"
const HEAT_MEDIUM: String = "medium"
const HEAT_HIGH: String = "high"
const COOK_DURATION: float = 30.0

var current_heat: String = HEAT_LOW
var cook_progress: float = 0.0
var cook_duration: float = COOK_DURATION

signal heat_changed(new_heat: String)
signal cooking_started(job_id: String, duration: float)
signal cook_progress_updated(job_id: String, fraction: float, elapsed: float, duration: float)
signal cooking_completed(job_id: String, output_item: Dictionary)
signal cooking_paused(job_id: String)
signal cooking_resumed(job_id: String)
signal heat_stalled(warning_message: String)

func set_heat_level(level: String) -> void:
    match level.to_lower():
        "low", "rendah": current_heat = HEAT_LOW
        "medium", "sedang": current_heat = HEAT_MEDIUM
        "high", "tinggi":
            current_heat = HEAT_HIGH
            heat_stalled.emit("Kecilkan panas ke Sedang")
    heat_changed.emit(current_heat)

func get_heat_multiplier() -> float:
    match current_heat:
        HEAT_LOW: return 0.5
        HEAT_MEDIUM: return 1.0
        HEAT_HIGH: return 0.0
        _: return 1.0

func is_heat_stalled() -> bool:
    return current_heat == HEAT_HIGH

func start_cooking(initial_heat: String = HEAT_LOW) -> Dictionary:
    if job_state == JobState.COOKING:
        return {"success": false, "reason": "Sedang memasak.", "idempotent": true}
    if job_state != JobState.READY_TO_HEAT and job_state != JobState.PAUSED:
        return {"success": false, "reason": "Persiapan belum selesai."}
    
    set_heat_level(initial_heat)
    job_state = JobState.COOKING
    var rm := _get_recipe_manager()
    if rm != null and rm.has_method("set_cooking_state"):
        rm.set_cooking_state("cooking")
    cooking_started.emit(active_job_id, cook_duration)
    return {"success": true, "job_id": active_job_id}

func advance_cooking(delta: float) -> void:
    if job_state != JobState.COOKING:
        return
    var mult := get_heat_multiplier()
    if mult > 0.0:
        cook_progress = clampf(cook_progress + (delta * mult), 0.0, cook_duration)
        var frac := cook_progress / cook_duration
        cook_progress_updated.emit(active_job_id, frac, cook_progress, cook_duration)
        if cook_progress >= cook_duration:
            _finish_cooking()

func pause_cooking() -> void:
    if job_state == JobState.COOKING:
        job_state = JobState.PAUSED
        var rm := _get_recipe_manager()
        if rm != null and rm.has_method("set_cooking_state"):
            rm.set_cooking_state("paused")
        cooking_paused.emit(active_job_id)

func resume_cooking() -> void:
    if job_state == JobState.PAUSED:
        job_state = JobState.COOKING
        var rm := _get_recipe_manager()
        if rm != null and rm.has_method("set_cooking_state"):
            rm.set_cooking_state("cooking")
        cooking_resumed.emit(active_job_id)

func _finish_cooking() -> void:
    job_state = JobState.OUTPUT_READY
    dish_output_slot = {
        "item_id": "dish_sayur_bening",
        "count": 1
    }
    reserved_ingredients.clear()
    origin_manifest.clear()
    
    var rm := _get_recipe_manager()
    if rm != null:
        if rm.has_method("set_cooking_state"):
            rm.set_cooking_state("output_ready")
        if rm.has_method("record_recipe_cooked"):
            rm.record_recipe_cooked(active_recipe_id)
            
    cooking_completed.emit(active_job_id, dish_output_slot)
```

### 5.2 Kontrak Aksi Konsumsi Hidangan (`eat_dish` / `action_eat`)

Untuk memenuhi T42/T43:
```gdscript
var meal_used: bool = false
signal meal_consumed(item_id: String)
signal p0_experience_completed()

func eat_dish(item_id: String = "dish_sayur_bening") -> Dictionary:
    var inv := _get_inventory()
    if inv == null:
        return {"success": false, "reason": "InventoryManager tidak tersedia."}
    
    var bp_c = inv.get_container("backpack") if inv.has_method("get_container") else inv.get("backpack")
    if bp_c == null or bp_c.get_item_count(item_id) < 1:
        return {"success": false, "reason": "Tidak ada hidangan di tas."}
    
    bp_c.remove_item(item_id, 1)
    meal_used = true
    meal_consumed.emit(item_id)
    
    var rm := _get_recipe_manager()
    var is_recipe_done := rm != null and rm.is_recipe_completed("recipe_sayur_bening_01")
    if is_recipe_done and meal_used:
        p0_experience_completed.emit()
        
    return {
        "success": true,
        "message": "Hangat. Resep pertama berhasil dibuat.",
        "meal_used": true,
        "p0_completed": is_recipe_done and meal_used
    }
```

### 5.3 Checklist Verifikasi Sebelum Penutupan Task
- [ ] 22+ metode uji baru di `tests/suites/test_cooking_heat.gd` lulus 100%.
- [ ] Pendaftaran Suite 13 di `tests/test_runner.gd` berjalan bersih via `godot --headless`.
- [ ] Zero failure pada seluruh suite (Suite 1 hingga Suite 13).
- [ ] Laporan bernomor `013-kontrol-panas-jeda-output-makan-hidangan.md` diterbitkan di `docs/completed_tasks/`.
- [ ] `PROJECT_STATUS.md` dan `TASKS.md` diperbarui sesuai aturan `AGENTS.md` § 6.
