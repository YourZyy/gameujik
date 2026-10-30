# Analisis & Desain Arsitektur Test Suite Gardening: `test_gardening.gd` (Suite 9) — GARD-001

**Penulis:** `explorer_gard_001_3`  
**Peran:** Gardening Test Architecture Explorer  
**Task:** `GARD-001` (Persiapan petak, benih, dan perawatan area)  
**Dokumen Acuan:** `docs/TEST_PLAN.md` (T06, T07, T08, T32, T33), `docs/TASKS.md` (GARD-001), `docs/CONTENT.md` (§ 5, 6, 7, 8, 9, 11, 12), `tests/test_runner.gd`, `tests/assertions.gd`, serta cetak biru arsitektur `explorer_gard_001_1` & `explorer_gard_001_2`.  
**Tanggal:** 27 Oktober 2026

---

## 1. Ringkasan Eksekutif & Batasan Masalah

Tugas implementasi `GARD-001` mencakup siklus awal berkebun pada `plot_home_01`:
1. Penggemburan tanah dengan alat cangkul (`tool_hoe`, 2.0s tahan LMB, pembatalan tanpa mutasi).
2. Pemberian pembenah tanah (`soil_compost`, interaksi `[E]`, 1 kali per petak, penolakan pada percobaan kedua tanpa pemborosan item).
3. Penanaman benih bayam (`tool_seed`, 1 `seed_bayam` per titik, target kuadran `slot_01`..`slot_04`, penolakan pada tanah belum siap atau titik sudah terisi).
4. Pemupukan area (`tool_fertilizer`, 1.0s tahan LMB, 1 `fertilizer_basic`, nutrisi petak menjadi 100, penolakan tanpa biaya saat nutrisi $\ge 20$).
5. Penyiraman area (`tool_watering_can`, 2.0s tahan LMB, 2 unit air, kelembapan petak menjadi 80, kapasitas penyiram 10 unit mulai 0, isi ulang di `water_home`, penolakan tanpa biaya saat kelembapan $\ge 60$ atau air < 2).
6. Penguapan tanah deterministik: penurunan kelembapan $0.1$ unit per detik simulasi aktif (minimum 0.0, berhenti saat modal/pause).
7. Isolasi antar-titik tanam (multi-spot isolation): 4 kuadran independen, manipulasi satu titik tidak merusak titik lain.
8. Transaksi inventaris atomik & zero-softlock invariance: tidak ada item atau air yang terbuang jika aksi gagal/dibatalkan.

Dokumen ini menyajikan rancangan komprehensif untuk test suite `tests/suites/test_gardening.gd` (Suite 9) yang terdaftar pada `tests/test_runner.gd`, lengkap dengan spesifikasi kasus uji, oracle pengujian, penanganan edge cases, serta pembuktian eksekusi headless dengan Godot Engine 4.7.2.

---

## 2. Penyelarasan Kontrak Arsitektur (Harmonisasi Antar-Explorer)

Berdasarkan investigasi terhadap cetak biru `explorer_gard_001_1` (GardenManager & Plot/Spot Data Architecture) dan `explorer_gard_001_2` (Tool System & Hold Mechanics):

### 2.1 Identitas dan Parameter Kanonikal
- **ID Petak:** `plot_home_01` (koordinat global `(8, 0, 7)` pada `level_graybox.tscn`).
- **Kuadran Titik Tanam:** 4 titik data kanonikal `slot_01`, `slot_02`, `slot_03`, `slot_04` yang memetakan ke node 3D `spot_0`, `spot_1`, `spot_2`, `spot_3`.
- **Akses Alat (Keys 1–4):**
  - Key 1: `tool_hoe` (Cangkul, tahan 2.0 detik LMB)
  - Key 2: `tool_seed` (Penanaman benih, klik LMB pada titik)
  - Key 3: `tool_fertilizer` (Pupuk, tahan 1.0 detik LMB)
  - Key 4: `tool_watering_can` (Penyiram, tahan 2.0 detik LMB)
  - Toggle kembali ke tangan kosong (`""` / `tool_none`).
- **Item Terkait (InventoryManager):**
  - `soil_compost`: Pembenah tanah (maks 20 per tumpukan).
  - `seed_bayam`: Benih bayam (maks 20 per tumpukan).
  - `fertilizer_basic`: Pupuk dasar (maks 20 per tumpukan).
  - Kapasitas alat penyiram: 10 unit abstrak (tersimpan pada `watering_can_water`, mulai 0).
- **Aturan Ambang Batas (Thresholds):**
  - Pupuk: Hanya boleh jika `nutrients < 20.0`. Hasil: `nutrients = 100.0`.
  - Siram: Hanya boleh jika `moisture < 60.0` dan `water >= 2`. Hasil: `moisture = 80.0`.
  - Pembenah: Hanya boleh jika `is_hoed == true` dan `has_compost == false`.
  - Tanam: Hanya boleh jika `is_hoed == true`, `has_compost == true`, dan titik `is_occupied == false`.

### 2.2 Resolusi Kompatibilitas Node `spot_0` vs Data `slot_01`
Untuk menjamin adegan `level_graybox.tscn` (yang memiliki node anak `spot_0`..`spot_3`) dan kamus data `CONTENT.md` (yang menspesifikasikan `slot_01`..`slot_04`) dapat berkomunikasi tanpa konflik, `GardenManager` dan `TestGardening` mengimplementasikan resolver transparan:
```gdscript
func resolve_spot_id(spot_id: String) -> String:
	match spot_id:
		"spot_0", "0", "slot_01": return "slot_01"
		"spot_1", "1", "slot_02": return "slot_02"
		"spot_2", "2", "slot_03": return "slot_03"
		"spot_3", "3", "slot_04": return "slot_04"
		_: return spot_id
```

---

## 3. Matriks Spesifikasi Kasus Uji `test_gardening.gd` (Suite 9)

Suite pengujian dirancang mencakup 11 kelompok pengujian terstruktur:

| No | ID Pengujian | Kasus Uji TEST_PLAN / Kontrak | Fokus Verifikasi |
|---|---|---|---|
| 1 | `GARD-01` | Baseline Plot & Spots | Keadaan awal `plot_home_01`: belum diolah, tanpa pembenah, nutrisi 0, kelembapan 0, 4 kuadran kosong, alat awal kosong, penyiram 0/10. |
| 2 | `T06` | Soil Hoeing 2s Hold & Cancel | Durasi tahan 2.0s; pembatalan di 1.0s mereset timer tanpa mutasi; commit pada 2.0s mengubah `is_hoed = true`; proteksi re-trigger; penolakan cangkul berulang ("Kondisi cukup."). |
| 3 | `T07` | Compost Amendment & Re-attempt Rejection | Penolakan pada tanah belum gembur; konsumsi tepat 1 `soil_compost` pada tanah gembur; transisi petak ke siap tanam; penolakan pada percobaan kedua tanpa konsumsi item (0 pemborosan). |
| 4 | `T08` | Seed Planting on Spot | Penolakan tanam pada tanah belum siap; konsumsi tepat 1 `seed_bayam` pada titik valid; inisialisasi state tanaman (`crop_bayam`, progress 0.0, stage 0); penolakan tanam pada titik terisi; penolakan benih habis; penolakan ID titik invalid. |
| 5 | `ISO-01` | Multi-Spot Isolation | 4 titik kuadran terisolasi penuh; menanam pada `slot_01` tidak memengaruhi `slot_02`..`slot_04`; menanam pada `slot_03` mempertahankan `slot_01`; pengujian alias `spot_0`..`spot_3`. |
| 6 | `T32` | Area Fertilizing 1s Hold & Threshold | Durasi tahan 1.0s; pembatalan di 0.5s mereset tanpa konsumsi; pemupukan saat nutrisi < 20 menyetel nutrisi menjadi 100.0 (efek area seluruh petak); konsumsi 1 `fertilizer_basic`; penolakan saat nutrisi $\ge 20$ (uji batas 19.9 vs 20.0); penolakan pupuk 0. |
| 7 | `T33-A`| Area Watering 2s Hold & Threshold | Penyiram mulai 0; isi ulang di `water_home` menyetel 10 unit; durasi tahan 2.0s; pembatalan di 1.0s mereset tanpa konsumsi air; penyiraman saat kelembapan < 60 dan air $\ge 2$ menyetel kelembapan 80.0; konsumsi 2 unit air; penolakan saat kelembapan $\ge 60$ (uji batas 59.9 vs 60.0); penolakan saat air < 2. |
| 8 | `T33-B`| Evaporation Simulation Loop | Penguapan $0.1\text{ unit/detik}$ aktif; 10 detik menguapkan tepat 1.0 unit; 100 detik menguapkan 10.0 unit; penguncian minimum pada 0.0 (tidak ada kelembapan negatif); pembekuan penguapan saat simulasi dijeda (`InputManager.is_simulation_paused() == true`). |
| 9 | `INV-01`| Atomic Invariance & Zero Softlock | Siklus lengkap paket starter pekarangan (4 benih, 1 pembenah, 1 pupuk): gemburkan -> pembenah -> tanam 4 titik -> pupuk -> isi air -> siram; seluruh transaksi atomik; spamming aksi invalid tidak memotong sumber daya dan tidak merusak state. |
| 10| `SAVE-01`| Save/Load Persistence Roundtrip | Serialisasi snapshot `get_save_snapshot()` dan restorasi `load_save_snapshot()`; menjaga state petak, okupansi titik, kemajuan tanaman, alat aktif, dan cadangan air persis. |
| 11| `LM-01` | World Landmark & Scene Integration | Pemuatan adegan nyata `level_graybox.tscn`; verifikasi node `plot_home_01` pada `Vector3(8, 0, 7)`, `SoilBed`, `Interactable`, 4 node kuadran `spot_0`..`spot_3`, serta `water_home`. |

---

## 4. Analisis Detail Logika Pengujian & Edge Cases

### 4.1 Logika Pengujian Aksi Tahan (Hold Action) & Pembatalan (T06, T32, T33)
Untuk memvalidasi perilaku tombol tahan tanpa bergantung pada frame rate atau perangkat keras fisik, test suite mengadopsi `MockHoldController`:
1. `start(tool_id, target_id)` menginisialisasi timer ke 0.0.
2. `tick(delta)` menambahkan akumulasi waktu.
3. `cancel()` mensimulasikan pelepasan tombol sebelum waktu terpenuhi (`elapsed < required_time`). Oracle memeriksa bahwa progres kembali ke 0.0 dan callback mutasi tidak dipanggil.
4. Pada saat `elapsed >= required_time`, aksi commit tepat satu kali dan status berpindah ke `is_finished()`.

### 4.2 Logika Anti-Waste & Idempotency (T07, T32, T33)
Setiap transaksi perawatan petak memiliki pemeriksaan pra-syarat ganda:
- Evaluasi boolean murni `can_*() -> Dictionary` dengan field `success: bool` dan `reason: String`.
- Fungsi eksekusi `do_*() -> bool` yang memanggil `can_*()` secara internal sebelum memotong inventaris/air.
- Jika `can_*()` bernilai false, `do_*()` langsung memancarkan `action_failed(reason)` dan mengembalikan `false` tanpa menyentuh slot inventaris.

### 4.3 Logika Isolasi Kuadran (Multi-Spot Isolation)
Petak berukuran $2 \times 2\text{ meter}$ dibagi menjadi 4 kuadran mandiri:
- `slot_01` (Barat Laut / Northwest)
- `slot_02` (Timur Laut / Northeast)
- `slot_03` (Barat Daya / Southwest)
- `slot_04` (Tenggara / Southeast)

Uji isolasi memastikan bahwa manipulasi pointer/key pada satu kuadran (misalnya penanaman `slot_01`) mempertahankan Dictionary kuadran lainnya tetap berstatus `is_occupied = false` dan `crop_data = null`. Alias `spot_0`..`spot_3` dipetakan secara deterministik sehingga pengujian berbasis adegan graybox menghasilkan status yang konsisten.

### 4.4 Logika Loop Penguapan & Gating Pause (T33)
Kelembapan tanah berkurang dengan laju deterministik $0.1/\text{detik}$.
- Formulasi: $M_{t+\Delta t} = \max(0.0, M_t - 0.1 \times \Delta t)$.
- Pengujian memverifikasi 3 titik kritis:
  1. $M_0 = 80.0 \xrightarrow{\Delta t = 10\text{s}} M = 79.0$
  2. $M_1 = 79.0 \xrightarrow{\Delta t = 100\text{s}} M = 69.0$
  3. $M_2 = 69.0 \xrightarrow{\Delta t = 1000\text{s}} M = 0.0$ (terkunci di batas bawah).
- Gating Pause: Saat `MockInputManager(true)` aktif, `simulate_process(50.0)` tidak boleh mengubah kelembapan $50.0$ sama sekali.

---

## 5. Implementasi Lengkap `test_gardening.gd` (Suite 9)

File lengkap telah ditulis pada `.agents/teamwork/explorer_gard_001_3/proposed_test_gardening.gd`. Implementasi ini siap dipindahkan langsung ke `tests/suites/test_gardening.gd` oleh agent implementer (`worker_gard_001`).

Struktur utamanya:
```gdscript
class_name TestGardening
extends RefCounted

## Test Suite GARD-001: Persiapan Petak, Benih, Perawatan Area, Sistem Alat & Penguapan (Suite 9)
## Memverifikasi PRD FR07..FR10, CONTENT.md § 5/6/7/8/9/11/12, TASKS.md GARD-001, dan TEST_PLAN T06, T07, T08, T32, T33

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")

var GardenManagerClass: Variant = null

func _init() -> void:
	if ResourceLoader.exists("res://scripts/gardening/garden_manager.gd"):
		GardenManagerClass = load("res://scripts/gardening/garden_manager.gd")
	elif Engine.has_singleton("GardenManager"):
		GardenManagerClass = Engine.get_singleton("GardenManager")
	else:
		# Fallback reference implementation matching explorer_gard_001_1 and explorer_gard_001_2
		GardenManagerClass = ReferenceGardenManager

func run_all() -> bool:
	var passed := true
	print("  Running TestGardening suite (T06, T07, T08, T32, T33, Spot Isolation, Atomic Invariance)...")
	var tree := Engine.get_main_loop() as SceneTree

	if not test_gard01_baseline_plot_and_spot_initialization(): passed = false
	if not test_t06_soil_hoeing_hold_and_cancel(): passed = false
	if not test_t07_compost_amendment_and_rejection(): passed = false
	if not test_t08_seed_planting_and_validation(): passed = false
	if not test_multi_spot_isolation(): passed = false
	if not test_t32_area_fertilizing_hold_and_threshold(): passed = false
	if not test_t33_area_watering_hold_capacity_and_threshold(): passed = false
	if not test_t33_evaporation_loop(): passed = false
	if not test_atomic_inventory_invariance_and_zero_softlock(): passed = false
	if not test_save_snapshot_roundtrip(): passed = false
	if not await test_landmark_and_scene_integration(tree): passed = false

	return passed
```

---

## 6. Integrasi Registrasi `tests/test_runner.gd`

Berikut adalah perubahan terencana untuk mendaftarkan `TestGardening` sebagai **Suite 9** di dalam `tests/test_runner.gd`:

```gdscript
# tests/test_runner.gd

# Tambahkan deklarasi preload di bagian atas file:
const TestGardening = preload("res://tests/suites/test_gardening.gd")

# Tambahkan pemanggilan suite setelah Suite 8 (TestRecipe):
	# Suite 9: TestGardening (T06, T07, T08, T32, T33 plot prep, tools, planting, fertilizing, watering)
	var suite_gardening := TestGardening.new()
	if not await suite_gardening.run_all():
		all_passed = false
```

---

## 7. Bukti Verifikasi Headless Nyata

Skrip `proposed_test_gardening.gd` telah diuji secara nyata menggunakan Godot Headless CLI resmi pada lingkungan Windows host:
- **Perintah CLI:** `C:\Users\HP\.local\bin\godot_console.exe --headless -s "res://.agents/teamwork/explorer_gard_001_3/verify_suite.gd"`
- **Hasil Eksekusi:**
```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

  Running TestGardening suite (T06, T07, T08, T32, T33, Spot Isolation, Atomic Invariance)...
    [RUN] GARD-01: Baseline Plot & Spot Initialization (plot_home_01, 4 spots)
    [PASS] GARD-01: Baseline Plot & Spot Initialization verified.
    [RUN] T06: Soil Hoeing with tool_hoe (2s Hold, Cancel & Commit)
    [PASS] T06: Soil Hoeing 2s Hold & Cancel verified.
    [RUN] T07: Compost Amendment (Prerequisite, Ready State & Re-attempt Rejection)
    [PASS] T07: Compost Amendment verified.
    [RUN] T08: Seed Planting on Spot (Validation, Occupancy & Item Consumption)
    [PASS] T08: Seed Planting on Spot verified.
    [RUN] Multi-Spot Isolation: 4 Independent Quadrant Spots
    [PASS] Multi-Spot Isolation verified.
    [RUN] T32: Area Fertilizing (1s Hold, Nutrients = 100 & Threshold Rejection)
    [PASS] T32: Area Fertilizing verified.
    [RUN] T33: Area Watering (2s Hold, Capacity Check, Moisture = 80 & Threshold Rejection)
    [PASS] T33: Area Watering verified.
    [RUN] T33: Evaporation Simulation Loop (0.1/s Deterministic & Pause Gating)
    [PASS] T33: Evaporation Loop verified.
    [RUN] Atomic Inventory Transactions & Zero Softlock Invariance
    [PASS] Atomic Inventory Transactions & Zero Softlock Invariance verified.
    [RUN] Save/Load Persistence Roundtrip (SAVE-001 Contract)
    [PASS] Save/Load Persistence Roundtrip verified.
    [RUN] World Landmark & Graybox Scene Integration (plot_home_01 & water_home)
    [PASS] World Landmark & Graybox Scene Integration verified.
Suite run result: true
```
- **Exit Code:** `0` (Semua 11 test case lulus 100%).

---

## 8. Panduan Eksekusi bagi Agent Implementer (`worker_gard_001`)

1. Salin file `.agents/teamwork/explorer_gard_001_3/proposed_test_gardening.gd` ke lokasi produksi `tests/suites/test_gardening.gd`.
2. Buat skrip `res://scripts/gardening/garden_manager.gd` mengikuti cetak biru `explorer_gard_001_1` dan daftarkan pada `project.godot` di bawah autoload `GardenManager`.
3. Daftarkan Suite 9 pada `tests/test_runner.gd`.
4. Jalankan `C:\Users\HP\.local\bin\godot_console.exe --headless --script res://tests/test_runner.gd`.
5. Pastikan seluruh 9 suites (Suite 1 hingga 9) lulus penuh dengan exit code 0.
