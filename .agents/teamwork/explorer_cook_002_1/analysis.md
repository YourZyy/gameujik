# Laporan Analisis Teknis: Backend KitchenManager untuk Milestone COOK-002
**Proyek:** Buku Resep 2045  
**Milestone:** COOK-002 (Kontrol Panas, Timer Memasak, Jeda Simulasi saat Panel Ditutup, Slot Output Tunggal, dan Konsumsi Hidangan)  
**Agent:** explorer_cook_002_1 (Read-Only Explorer)  
**Tanggal:** 28 Oktober 2026  
**Status Investigasi:** Selesai (100% Read-Only, Terverifikasi terhadap Codebase & Dokumen Acuan)  

---

## 1. Ringkasan Eksekutif & Batasan Masalah

Milestone `COOK-002` melanjutkan fondasi yang telah dibangun pada `COOK-001` (laporan `012-validasi-reservasi-persiapan-pembatalan-dapur.md`). Pada `COOK-001`, sistem telah menyelesaikan validasi bahan terpadu lintas tas dan peti, reservasi atomik dengan `origin_manifest`, aksi tahan persiapan 4.0s dengan retensi interupsi, dan pembatalan aman 3-tingkat.

Fokus teknis backend `KitchenManager` (`scripts/cooking/kitchen_manager.gd`) pada `COOK-002` meliputi:
1. **Kontrol Tingkat Panas (Heat Levels):** Tiga tingkat panas diskrit:
   - **Rendah (`HEAT_LOW`):** Pengali kemajuan $\times 0.5$.
   - **Sedang (`HEAT_MEDIUM`):** Pengali kemajuan $\times 1.0$ (kondisi nominal).
   - **Tinggi (`HEAT_HIGH`):** Pengali kemajuan $\times 0.0$ (*heat stall* / kemajuan berhenti sementara) disertai pesan peringatan *"Kecilkan panas ke Sedang."*, dengan invarian bahwa bahan **tidak hangus atau rusak**.
   - **Pilihan Panas Awal:** Rendah (`HEAT_LOW`), agar pemain membaca petunjuk dan memilih tingkat panas secara sadar (per `CONTENT.md` § 4).
2. **Timer Memasak (Nominal 30.0 Detik):** Durasi nominal 30.0 detik pada panas Sedang (`COOK_DURATION = 30.0`). Akumulasi waktu efektif dihitung melalui `delta * multiplier`.
3. **Jeda Simulasi (*Simulation Pause*):** Ketika antarmuka dapur ditutup (`Esc` atau tombol tutup), status job bertransisi ke `JobState.PAUSED` atau berhenti berproses. Di dunia luar, waktu memasak **tidak boleh maju diam-diam di latar belakang** (*no stealth background cooking* per `PROTOTYPE.md` § 6.2). Saat panel dibuka kembali, proses dapat dilanjutkan (*resume*).
4. **Slot Output Masakan Tunggal (`dish_output_slot`):** Ketika progres memasak mencapai 100% (30.0s efektif), sistem melakukan commit 1 unit `dish_sayur_bening` ke `dish_output_slot`, mengonsumsi reservasi bahan secara permanen, memicu `RecipeManager.record_recipe_cooked(active_recipe_id)` (centang resep pertama kali & penambahan `times_cooked`), dan menolak persiapan baru jika slot output belum diambil.
5. **Pengambilan Hasil & Retensi Kapasitas Penuh (T15):** Pemain dapat mengambil masakan ke dalam tas. Jika tas penuh (12/12), hidangan tetap tertahan di `dish_output_slot` tanpa membatalkan status selesai masakan.
6. **Aksi Konsumsi Hidangan (`eat_dish` / T43):** Memakan 1 porsi hidangan dari tas pemain mengonsumsi 1 unit `dish_sayur_bening`, menampilkan pesan jujur *"Hangat. Resep pertama berhasil dibuat."*, dan mengaktifkan flag `meal_used = true`.
7. **Pengulangan Resep (*Remake Recipe* / T19):** Memasak ulang diperbolehkan; menambah `times_cooked`, tetapi centang resep tetap satu tanpa emisi sinyal ganda yang memicu exploit.
8. **Interlock Kasur Tidur:** `WorldResourceManager.can_sleep()` menolak tidur jika memasak sedang aktif (`COOKING` atau `PAUSED`), namun **diizinkan jika masakan sudah selesai (`OUTPUT_READY`)** sesuai `CONTENT.md` § 9.
9. **Kompatibilitas Save Snapshot Envelope v1 (SAVE-001):** Menyimpan dan memulihkan seluruh variabel progres masak, tingkat panas, slot output, status job, dan flag `meal_used`.

---

## 2. Analisis Kondisi Codebase Saat Ini (Baseline Analysis)

### 2.1. File `scripts/cooking/kitchen_manager.gd` (527 baris)
- **Enum `JobState` (baris 8–17):**
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
  *Observasi:* Nilai enum `COOKING = 3`, `PAUSED = 4`, dan `OUTPUT_READY = 5` sudah dideklarasikan sejak COOK-001, namun logika transisi masuk dan keluar untuk ketiga status ini belum diimplementasikan.
- **Sinyal Dapur (baris 22–35):**
  Sinyal persiapan dan pembatalan sudah lengkap (`prep_started`, `prep_progress_updated`, `prep_completed`, `prep_cancelled`, `job_cancelled`, dll.).
  *Kekurangan:* Belum ada sinyal khusus untuk fase memasak:
  - `cooking_started(job_id: String, duration: float)`
  - `cooking_progress_updated(job_id: String, progress_ratio: float, elapsed: float, duration: float)`
  - `cook_progress_changed(progress: float, duration: float)`
  - `cooking_paused(job_id: String)`
  - `cooking_resumed(job_id: String)`
  - `cooking_completed(job_id: String, output: Dictionary)`
  - `heat_level_changed(new_heat: int, old_heat: int)`
  - `heat_stall_warning(message: String)`
  - `dish_collected(item_id: String, count: int)`
  - `dish_consumed(item_id: String)`
- **Variabel State:**
  - `dish_output_slot` sudah ada (baris 74), getter `get_dish_output()` dan helper dasar `take_dish_output()` sudah ada (baris 463–474).
  *Kekurangan:*
  - Belum ada konstanta/variabel `COOK_DURATION = 30.0`
  - Belum ada `cook_progress: float = 0.0`
  - Belum ada enum/konstanta `HeatLevel` (`LOW = 0`, `MEDIUM = 1`, `HIGH = 2`)
  - Belum ada `current_heat_level: int = HeatLevel.LOW`
  - Belum ada flag `meal_used: bool = false`
- **Method `advance_prep(delta)` (baris 308–328):**
  Telah selesai memvalidasi hold 4.0s dan bertransisi ke `READY_TO_HEAT`.
  *Kekurangan:* Belum ada method `start_cooking()`, `advance_cooking(delta)`, `pause_cooking()`, `resume_cooking()`, `set_heat_level()`, dan `claim_dish_output()`.
- **Method `cancel_preparation()` (baris 341–425):**
  Sudah memiliki penjaga:
  `if job_state != JobState.RESERVED_PREPARING and job_state != JobState.READY_TO_HEAT: return {"success": false, ...}`
  *Observasi:* Penjaga ini secara otomatis mengunci pembatalan begitu job berpindah ke `JobState.COOKING`, `PAUSED`, atau `OUTPUT_READY`, memenuhi spesifikasi *no cancel after cooking starts*.
- **Helper `is_job_active()` (baris 118–119):**
  ```gdscript
  func is_job_active() -> bool:
      return job_state != JobState.IDLE and job_state != JobState.REFUND_PENDING
  ```
  *Observasi Penting:* Jika `job_state == JobState.OUTPUT_READY`, `is_job_active()` saat ini bernilai `true`. Hal ini menyebabkan `WorldResourceManager.can_sleep()` menolak tidur. Padahal `CONTENT.md` § 9 baris 164 menyatakan *"Output yang sudah selesai tidak menghalangi istirahat"*. Oleh karena itu, kondisi `is_job_active()` perlu mengecualikan `OUTPUT_READY`.
- **Snapshot `get_save_snapshot()` & `load_save_snapshot()` (baris 478–527):**
  Snapshot v1 saat ini sudah menyimpan `dish_output_slot` dan `job_state`. Namun belum memuat `cook_progress`, `cook_duration`, `heat_level`, dan `meal_used`.

### 2.2. File `scripts/recipe/recipe_manager.gd`
- Method `record_recipe_cooked(recipe_id: String)` (baris 165–175):
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
  *Observasi:* Sangat ideal! Ketika pertama kali dimasak (`prev_times == 0`), sinyal `recipe_completed` dipancarkan satu kali. Pada pembuatan ulang berikutnya (`prev_times > 0`), `times_cooked` bertambah tetapi `recipe_completed` tidak dipancarkan ulang, memenuhi syarat T19.
- Method `set_cooking_state(state: String)` (baris 182–188):
  Mendukung string `"idle"`, `"preparing"`, `"ready_to_heat"`, `"cooking"`, `"paused"`, dan `"output_ready"`.

### 2.3. File `scripts/ui/kitchen_ui.gd` & `scenes/ui/kitchen_ui.tscn`
- Scene `kitchen_ui.tscn` telah memiliki `ReadySection` dengan tombol `StartCookingButton`.
- Callback `_on_start_cooking_pressed()` di `kitchen_ui.gd` (baris 227–228) saat ini masih berstatus placeholder:
  `set_feedback("Tahap memasak aktif pada milestone COOK-002.")`.
- UI membutuhkan penambahan kontainer antarmuka memasak (`CookingSection` dan `OutputSection`):
  - Meteran progres memasak (`CookProgressBar`, 0–30.0s)
  - Label waktu memasak (`CookTimeLabel`)
  - 3 Tombol pemilih panas (Rendah 0.5x, Sedang 1.0x, Tinggi 0.0x)
  - Label peringatan panas stall (*"Kecilkan panas ke Sedang."*)
  - Tombol ambil hidangan masakan (`ClaimOutputButton`)

---

## 3. Rincian Desain Arsitektur & Rekomendasi Teknis COOK-002

### 3.1. Spesifikasi Enum & Konstanta Panas (`HeatLevel`)
Tambahkan enum dan pemetaan pengali panas pada `scripts/cooking/kitchen_manager.gd`:

```gdscript
enum HeatLevel {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2
}

const HEAT_MULTIPLIERS: Dictionary = {
	HeatLevel.LOW: 0.5,
	HeatLevel.MEDIUM: 1.0,
	HeatLevel.HIGH: 0.0
}

const HEAT_NAMES: Dictionary = {
	HeatLevel.LOW: "Rendah",
	HeatLevel.MEDIUM: "Sedang",
	HeatLevel.HIGH: "Tinggi"
}

const COOK_DURATION: float = 30.0
const STALL_WARNING_HIGH_HEAT: String = "Kecilkan panas ke Sedang."
const DEFAULT_HEAT_LEVEL: HeatLevel = HeatLevel.LOW
const DISH_ITEM_ID: String = "dish_sayur_bening"
```

### 3.2. State Machine Transisi Status Job (`JobState`)
Berikut matriks transisi state lengkap yang direkomendasikan untuk `KitchenManager`:

| Dari Status | Peristiwa / Aksi | Menuju Status | Efek Samping |
|---|---|---|---|
| `IDLE` | `start_preparation()` | `RESERVED_PREPARING` | Bahan ditarik fisik, job ID terbit, `prep_progress = 0.0` |
| `RESERVED_PREPARING` | `advance_prep(delta)` mencapai 4.0s | `READY_TO_HEAT` | Persiapan selesai, siap masuk tahap pemanasan |
| `RESERVED_PREPARING` | `cancel_preparation()` | `IDLE` | Refund bahan 3-tingkat, reset job |
| `READY_TO_HEAT` | `cancel_preparation()` | `IDLE` | Refund bahan 3-tingkat, reset job |
| `READY_TO_HEAT` | `start_cooking()` | `COOKING` | Mulai memasak, `current_heat_level = HeatLevel.LOW`, `cook_progress = 0.0` |
| `COOKING` | `advance_cooking(delta)` | `COOKING` (atau `OUTPUT_READY`) | Tambah `delta * multiplier`. Jika $\ge 30.0$, masuk `OUTPUT_READY` |
| `COOKING` | Panel tutup / `pause_cooking()` | `PAUSED` | Hentikan pemrosesan timer, emisi sinyal `cooking_paused` |
| `PAUSED` | Panel buka / `resume_cooking()` | `COOKING` | Lanjutkan pemrosesan timer dengan progres utuh |
| `COOKING` | Mencapai 30.0s progres efektif | `OUTPUT_READY` | Commit 1 `dish_sayur_bening` ke `dish_output_slot`, konsumsi permanen bahan reservasi, `record_recipe_cooked()` |
| `OUTPUT_READY` | `claim_dish_output()` (Tas muat) | `IDLE` | Pindahkan hidangan ke tas pemain, kosongkan `dish_output_slot`, `active_job_id = ""` |
| `OUTPUT_READY` | `claim_dish_output()` (Tas penuh) | `OUTPUT_READY` | Tolak transfer dengan pesan jujur, pertahankan hidangan di slot hasil |

### 3.3. Penanganan Jeda Simulasi (*Simulation Pause*) & Anti-Background Cooking
Sesuai aturan `PROTOTYPE.md` § 6.2: *"Tidak ada job yang terus memasak diam-diam di latar P0"*.
- **Pemicu Jeda:**
  Ketika `KitchenUI` ditutup (`close()`), jika status dapur saat itu adalah `COOKING`, panggil `km.pause_cooking()`.
- **Perilaku di `_process(delta)`:**
  `KitchenManager._process(delta)` hanya boleh memajukan timer jika `job_state == JobState.COOKING` DAN panel dapur sedang aktif/terbuka.
  Ketika status berada pada `JobState.PAUSED` (karena panel ditutup), pemanggilan `advance_cooking(delta)` tidak akan menambah waktu sama sekali (`guard: if job_state != JobState.COOKING: return`).
- **Penyambungan Kembali (*Resume*):**
  Saat pemain berinteraksi kembali dengan stasiun dapur dan membuka antarmuka, tombol *"Lanjutkan Memasak"* tersedia (atau dapat dipanggil `resume_cooking()`). Status kembali menjadi `JobState.COOKING` dan hitungan mundur 30.0s melanjutkan dari titik terakhir tanpa reset.

### 3.4. Logika Pembuatan & Pengambilan Output Masakan
1. **Commit Masakan (`_complete_cooking`):**
   ```gdscript
   func _complete_cooking() -> void:
       job_state = JobState.OUTPUT_READY
       cook_progress = cook_duration
       dish_output_slot = {
           "item_id": DISH_ITEM_ID,
           "count": 1
       }
       # Konsumsi permanen bahan reservasi (matter transformation)
       reserved_ingredients.clear()
       origin_manifest.clear()
       if not current_job.is_empty():
           current_job["output_committed"] = true
           current_job["completed"] = true
           current_job["cook_progress"] = cook_duration

       var rm := _get_recipe_manager()
       if rm != null:
           if rm.has_method("record_recipe_cooked"):
               rm.record_recipe_cooked(active_recipe_id)
           if rm.has_method("set_cooking_state"):
               rm.set_cooking_state("output_ready")

       cooking_completed.emit(active_job_id, dish_output_slot.duplicate(true))
       cook_completed.emit(active_job_id, dish_output_slot.duplicate(true))
   ```
2. **Klaim Output (`claim_dish_output`):**
   ```gdscript
   func claim_dish_output() -> Dictionary:
       if not has_ready_output():
           return {"success": false, "reason": "Tidak ada masakan yang siap diambil."}

       var inv := _get_inventory()
       if inv == null:
           return {"success": false, "reason": "InventoryManager tidak tersedia."}

       var bp_c = inv.get_container("backpack") if inv.has_method("get_container") else inv.get("backpack")
       if bp_c == null:
           return {"success": false, "reason": "Tas tidak ditemukan."}

       var it_id: String = str(dish_output_slot.get("item_id", DISH_ITEM_ID))
       var cnt: int = int(dish_output_slot.get("count", 1))

       # Periksa kapasitas tas
       if bp_c.has_method("can_add_item"):
           if not bp_c.can_add_item(it_id, cnt):
               return {
                   "success": false,
                   "reason": "Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."
               }

       var rem: int = bp_c.add_item(it_id, cnt)
       if rem > 0:
           return {
               "success": false,
               "reason": "Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."
           }

       var collected_dish := dish_output_slot.duplicate(true)
       dish_output_slot.clear()
       active_job_id = ""
       active_recipe_id = ""
       current_job.clear()
       cook_progress = 0.0
       prep_progress = 0.0
       job_state = JobState.IDLE

       var rm := _get_recipe_manager()
       if rm != null and rm.has_method("set_cooking_state"):
           rm.set_cooking_state("idle")

       dish_collected.emit(it_id, cnt)
       if inv.has_signal("inventory_updated"):
           inv.inventory_updated.emit()

       return {
           "success": true,
           "reason": "Hidangan berhasil diambil ke dalam tas.",
           "dish": collected_dish
       }
   ```

### 3.5. Aksi Makan Hidangan (`eat_dish` / T43)
Sesuai spesifikasi `CONTENT.md` § 10 & `TEST_PLAN.md` T43:
```gdscript
var meal_used: bool = false

func eat_dish(item_id: String = DISH_ITEM_ID) -> Dictionary:
    var inv := _get_inventory()
    if inv == null:
        return {"success": false, "reason": "InventoryManager tidak tersedia."}

    var bp_c = inv.get_container("backpack") if inv.has_method("get_container") else inv.get("backpack")
    if bp_c == null:
        return {"success": false, "reason": "Tas tidak ditemukan."}

    var count: int = bp_c.get_item_count(item_id) if bp_c.has_method("get_item_count") else 0
    if count <= 0:
        return {
            "success": false,
            "reason": "Tidak ada hidangan di tas untuk dimakan.",
            "meal_used": meal_used
        }

    bp_c.remove_item(item_id, 1)
    meal_used = true

    dish_consumed.emit(item_id)
    if inv.has_signal("inventory_updated"):
        inv.inventory_updated.emit()

    return {
        "success": true,
        "message": "Hangat. Resep pertama berhasil dibuat.",
        "meal_used": true
    }
```

### 3.6. Interlock Kasur Tidur (`is_job_active()`)
Pada `kitchen_manager.gd`:
```gdscript
func is_job_active() -> bool:
    # Output ready tidak boleh menghalangi istirahat (CONTENT.md § 9 baris 164)
    return job_state != JobState.IDLE and job_state != JobState.REFUND_PENDING and job_state != JobState.OUTPUT_READY
```
Dengan perbaikan ini, pemain yang telah menyelesaikan proses memasak dan hidangannya masih menunggu di slot hasil **tetap dapat tidur di kasur**, tanpa melanggar perlindungan terhadap job persiapan/memasak aktif.

### 3.7. Serialisasi Save Snapshot Envelope v1
Tambahkan variabel baru ke dalam payload snapshot pada `kitchen_manager.gd`:
```gdscript
func get_save_snapshot() -> Dictionary:
    return {
        "version": 1,
        "job_state": int(job_state),
        "active_job_id": active_job_id,
        "active_recipe_id": active_recipe_id,
        "prep_progress": prep_progress,
        "prep_duration": prep_duration,
        "cook_progress": cook_progress,
        "cook_duration": cook_duration,
        "heat_level": int(current_heat_level),
        "meal_used": meal_used,
        "reserved_ingredients": reserved_ingredients.duplicate(true),
        "origin_manifest": origin_manifest.duplicate(true),
        "origin_records": origin_manifest.duplicate(true),
        "dish_output_slot": dish_output_slot.duplicate(true),
        "current_job": current_job.duplicate(true)
    }

func load_save_snapshot(data: Dictionary) -> bool:
    # ... validasi dictionary ...
    cook_progress = float(data.get("cook_progress", 0.0))
    cook_duration = float(data.get("cook_duration", COOK_DURATION))
    current_heat_level = int(data.get("heat_level", data.get("current_heat_level", HeatLevel.LOW))) as HeatLevel
    meal_used = bool(data.get("meal_used", false))
    # ... sinkronisasi match job_state dengan RecipeManager ...
```

---

## 4. Matriks Sinyal dan Method Baru / Modifikasi

| Identitas | Tipe | Komponen | Deskripsi & Kontrak |
|---|---|---|---|
| `HeatLevel` | Enum | `KitchenManager` | `LOW = 0`, `MEDIUM = 1`, `HIGH = 2` |
| `current_heat_level` | Variable | `KitchenManager` | Tingkat panas aktif (default `LOW`) |
| `cook_progress` | Variable | `KitchenManager` | Kemajuan waktu efektif memasak (0.0–30.0s) |
| `meal_used` | Variable | `KitchenManager` | Flag konsumsi masakan P0 (default `false`) |
| `set_heat_level(level)` | Method | `KitchenManager` | Mengubah tingkat panas & emisi sinyal |
| `get_heat_multiplier()` | Method | `KitchenManager` | Mengembalikan 0.5 (Low), 1.0 (Med), atau 0.0 (High) |
| `is_heat_stalled()` | Method | `KitchenManager` | True jika sedang `COOKING` dan panas `HIGH` |
| `start_cooking()` | Method | `KitchenManager` | Transisi dari `READY_TO_HEAT` ke `COOKING` |
| `advance_cooking(delta)` | Method | `KitchenManager` | Menambah progres efektif = `delta * multiplier` |
| `pause_cooking()` | Method | `KitchenManager` | Transisi dari `COOKING` ke `PAUSED` |
| `resume_cooking()` | Method | `KitchenManager` | Transisi dari `PAUSED` ke `COOKING` |
| `claim_dish_output()` | Method | `KitchenManager` | Memindahkan hidangan ke tas jika muat |
| `eat_dish(item_id)` | Method | `KitchenManager` | Makan hidangan, konsumsi 1 porsi, set `meal_used` |
| `is_job_active()` | Method | `KitchenManager` | Modifikasi: exclude `OUTPUT_READY` |
| `cooking_started` | Signal | `KitchenManager` | Emisi saat fase memasak dimulai |
| `cooking_progress_updated`| Signal | `KitchenManager` | Emisi tiap tick waktu memasak bertambah |
| `cooking_paused` | Signal | `KitchenManager` | Emisi saat proses dijeda |
| `cooking_resumed` | Signal | `KitchenManager` | Emisi saat proses dilanjutkan |
| `cooking_completed` | Signal | `KitchenManager` | Emisi saat output masakan siap |
| `heat_stall_warning` | Signal | `KitchenManager` | Emisi saat panas tinggi menghambat kemajuan |
| `dish_collected` | Signal | `KitchenManager` | Emisi saat hidangan diambil ke tas |
| `dish_consumed` | Signal | `KitchenManager` | Emisi saat hidangan dimakan pemain |

---

## 5. Rencana Pengujian Penerimaan COOK-002 (Test Matrix)

Untuk membuktikan kriteria selesai task COOK-002 sesuai `docs/TEST_PLAN.md`, berikut 6 grup kasus uji yang dirancang:

1. **Uji T41 — Validasi Kontrol Panas & Multiplier Terukur:**
   - Panas Rendah (`HEAT_LOW`): Jalankan 10.0 detik delta -> kemajuan tepat $5.0$ detik ($0.5\times$).
   - Panas Sedang (`HEAT_MEDIUM`): Jalankan 10.0 detik delta -> kemajuan tepat $10.0$ detik ($1.0\times$).
   - Panas Tinggi (`HEAT_HIGH`): Jalankan 10.0 detik delta -> kemajuan tepat $0.0$ detik ($0.0\times$ stall), sinyal/status stall warning *"Kecilkan panas ke Sedang."* aktif, bahan tetap utuh tanpa rusak/hangus.
   - Pilihan awal: `start_cooking()` memastikan panas bermula dari `HEAT_LOW`.
2. **Uji T42 — Jeda Simulasi saat Panel Ditutup & Resume:**
   - Masak berjalan hingga 12.0s -> panggil `pause_cooking()` -> job_state bertransisi ke `PAUSED`.
   - Jalankan `advance_cooking(10.0)` saat `PAUSED` -> progres tetap 12.0s (tidak maju di latar belakang).
   - `RecipeManager.get_cooking_state()` melaporkan `"paused"`.
   - Panggil `resume_cooking()` -> kembali ke `COOKING` -> lanjutkan tick hingga selesai.
3. **Uji T15 — Commit Output Tunggal & Retensi Kapasitas Penuh:**
   - Saat progres mencapai 30.0s: bertransisi ke `OUTPUT_READY`, slot output terisi tepat 1 `dish_sayur_bening`.
   - Bahan mentah yang direservasi terhapus permanen (`reserved_ingredients.size() == 0`).
   - Fixture tas penuh (12 slot terisi): panggil `claim_dish_output()` -> ditolak bersih dengan pesan *"Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."*, hidangan tetap tersimpan di `dish_output_slot`.
   - Kosongkan 1 slot tas -> panggil `claim_dish_output()` -> hidangan berpindah ke tas, `dish_output_slot` kosong, stasiun kembali ke `IDLE`.
4. **Uji T19 — Pengulangan Resep (*Remake*):**
   - Masak resep hingga selesai pertama kali -> `RecipeManager.is_recipe_completed()` bernilai true, `times_cooked == 1`.
   - Ambil masakan -> siapkan bahan baru (3 bayam, 1 jagung, 1 temu kunci).
   - Masak resep kedua kali hingga selesai -> `times_cooked == 2`.
   - Asersi bahwa `recipe_completed` tidak dipancarkan ulang untuk kali kedua (centang tetap satu).
5. **Uji T43 — Aksi Makan Hidangan (`eat_dish`):**
   - Ambil masakan ke tas (tas memiliki 1 `dish_sayur_bening`).
   - Panggil `eat_dish()` -> jumlah hidangan berkurang menjadi 0, pesan balasan *"Hangat. Resep pertama berhasil dibuat."*, `meal_used == true`.
   - Panggil `eat_dish()` lagi saat tas kosong -> ditolak dengan alasan tidak ada hidangan.
6. **Uji Ekstra — Interlock Kasur Tidur & Snapshot Save/Load:**
   - Kasur menolak tidur saat status `COOKING` atau `PAUSED`.
   - Kasur **mengizinkan tidur saat status `OUTPUT_READY`** (hidangan belum diambil).
   - Snapshot save/load memulihkan `cook_progress`, `current_heat_level`, `dish_output_slot`, dan `meal_used` secara 100% presisi.

---

## 6. Kesimpulan Investigasi

Backend `KitchenManager` telah memiliki struktur yang sangat kokoh dari `COOK-001`. Implementasi milestone `COOK-002` tidak memerlukan perombakan arsitektur besar (*no architectural overhaul*), melainkan pengisian logika transisi state machine pada `JobState.COOKING`, `PAUSED`, dan `OUTPUT_READY`, penambahan sistem pengali tingkat panas 3-level, penanganan jeda simulasi panel UI, pemindahan hasil masakan atomik, dan helper makan hidangan untuk mengaktifkan flag `meal_used`.
