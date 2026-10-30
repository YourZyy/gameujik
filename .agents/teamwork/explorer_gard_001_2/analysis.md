# Analisis Arsitektur & Desain Teknis Sistem Alat, Mekanik Tahan & Interaksi Pemain (GARD-001)

**Penulis:** `explorer_gard_001_2`  
**Peran:** Tool System & Player Action Interaction Explorer  
**Task:** `GARD-001` (Persiapan petak, benih, dan perawatan area)  
**Dokumen Acuan:** `PRD.md` (FR01, FR02), `docs/CONTENT.md` (§ 6, § 7, § 9, § 11), `docs/UI_UX.md` (§ 3, § 4, § 5), `docs/TEST_PLAN.md` (T06, T07, T08, T32, T33)  
**Tanggal:** 27 Oktober 2026

---

## 1. Ringkasan Eksekutif & Batas Cakupan

Task `GARD-001` mencakup implementasi persiapan petak kebun (`plot_home_01`), sistem alat (Keys 1–4), penanaman per titik (`slot_01`..`slot_04`), pemupukan dan penyiraman area, kapasitas alat penyiram (10 unit abstrak), serta isi ulang air di `water_home`.

Laporan analisis ini secara spesifik membedah dan merancang subsistem:
1. **Sistem Akses & Pemilihan Alat (Keys 1–4)**:
   - 4 akses tetap: Cangkul (`tool_hoe`), Benih (`tool_seed`), Pupuk (`tool_fertilizer`), Penyiram (`tool_watering_can`).
   - Sifat toggleable kembali ke tangan kosong (`TOOL_NONE`).
   - Tidak mengisi slot inventaris tas (CONTENT.md § 2 & § 3).
2. **Kapasitas & Isi Ulang Alat Penyiram**:
   - Kapasitas 10 unit abstrak, kondisi game baru bernilai 0 (CONTENT.md § 5 & § 9).
   - Isi ulang di `water_home` dengan aksi tahan E selama 2.0 detik.
3. **Mekanik Tahan (Hold Actions), Durasi & Keamanan**:
   - Cangkul: Tahan LMB 2.0 detik pada petak -> `is_hoed = true`.
   - Pupuk: Tahan LMB 1.0 detik pada petak -> `nutrients = 100`, konsumsi 1 `fertilizer_basic` (hanya bila `nutrients < 20`).
   - Penyiram: Tahan LMB 2.0 detik pada petak -> `moisture = 80`, konsumsi 2 unit air (hanya bila `moisture < 60` dan air >= 2).
   - Isi ulang air: Tahan E 2.0 detik pada `water_home` -> `water_units = 10`.
   - Pembatalan tanpa biaya (cancellation without cost): pelepasan tombol sebelum durasi selesai mereset progres seketika tanpa konsumsi resource.
   - Proteksi pemicuan ulang (re-trigger protection): aksi commit tepat 1 kali; tombol harus dilepas dan ditekan ulang sebelum aksi berikutnya dapat dimulai.
4. **Interaksi Kontekstual E untuk Pembenah Tanah (`soil_compost`)**:
   - Bukan alat ke-5; diakses lewat prompt `[E] Tambah pembenah — 1` ketika tanah sudah gembur namun belum siap (CONTENT.md § 6).
   - Prioritas interaksi petak: Panen siap -> Tambah pembenah -> Inspeksi.
5. **Bidikan Titik Tanam (Spot Targeting untuk `tool_seed`)**:
   - Resolusi kuadran 4 titik (`slot_01`..`slot_04`) pada petak 2x2 meter.
   - Klik kiri menanam 1 `seed_bayam` pada titik valid yang kosong.
   - Penolakan bersih tanpa konsumsi item bila petak belum siap atau titik sudah terisi.
6. **Integrasi Sistem**:
   - `PlayerController` (`scripts/player/player_controller.gd`).
   - `InteractionDetector` (`scripts/interaction/interaction_detector.gd`).
   - `InputManager` (`scripts/core/input_manager.gd`).
   - `InventoryManager` (`scripts/inventory/inventory_manager.gd`).
   - `HUD` (`scripts/ui/hud.gd`).

---

## 2. Sistem Akses & Pemilihan Alat (Keys 1–4)

### 2.1 Definisi Alat dan Data
Sesuai `CONTENT.md` § 2 dan § 6:
> "Empat alat tetap berada pada akses alat ... 4 akses tetap, tidak mengisi slot tas ... Memilih alat tidak memunculkan panel penuh secara otomatis."

| Akses | ID Alat | Nama Tampil | Syarat / Konsumsi | Perilaku Saat Digunakan |
|---|---|---|---|---|
| 0 / Kosong | `tool_none` / `""` | Tangan Kosong | Tidak ada | Tidak ada aksi alat (hanya interaksi umum E) |
| 1 | `tool_hoe` | Alat tanah (Cangkul) | Gratis / Permanen | Tahan LMB 2 detik pada petak untuk menggemburkan |
| 2 | `tool_seed` | Tanam benih | Butuh `seed_bayam` di tas | Klik LMB pada titik kosong di petak siap |
| 3 | `tool_fertilizer` | Pupuk | Butuh `fertilizer_basic` di tas | Tahan LMB 1 detik pada petak bila nutrisi < 20 |
| 4 | `tool_watering_can` | Penyiram | Butuh air di penyiram (min. 2 unit) | Tahan LMB 2 detik pada petak bila kelembapan < 60 |

### 2.2 Input Mapping & Hotkeys
Pada `project.godot`, tambahkan pemetaan aksi input baru berikut:
- `tool_1`: Physical Keycode 49 (Key `1`)
- `tool_2`: Physical Keycode 50 (Key `2`)
- `tool_3`: Physical Keycode 51 (Key `3`)
- `tool_4`: Physical Keycode 52 (Key `4`)
- `action_tool_use`: Mouse Button Left (`MOUSE_BUTTON_LEFT`) — aksi pemakaian alat
- `action_tool_cancel`: Mouse Button Right (`MOUSE_BUTTON_RIGHT`) — batalkan bidikan / aksi tahan

### 2.3 Logika Toggle & Siklus Alat
1. **Toggle Mandiri (Self-Toggle)**:
   - Jika pemain sedang memegang `tool_hoe` (Alat 1), menekan Key `1` kembali akan **menonaktifkan** cangkul, mengembalikan tangan ke `tool_none` (tangan kosong).
   - Pola ini berlaku konsisten untuk keys 1, 2, 3, dan 4.
2. **Perpindahan Langsung**:
   - Menekan tombol alat lain (misal dari 1 langsung ke 4) langsung beralih ke alat tujuan.
3. **Pemberhentian Aksi Berjalan Saat Berganti Alat**:
   - Jika ada aksi tahan yang sedang berlangsung saat pemain menekan tombol ganti alat, aksi tersebut langsung dibatalkan (reset 0) tanpa biaya.
4. **Gating Konteks Input**:
   - Sesuai `UI_UX.md` § 3: *"Tidak mengubah alat ketika mengetik/menavigasi menu."*
   - Pemilihan alat hanya diproses saat `InputManager.is_world_context()` bernilai `true`. Jika context adalah `BOOK`, `STORAGE`, `KITCHEN`, `DIALOGUE`, atau `PAUSE`, input alat diabaikan.

---

## 3. Kapasitas & Isi Ulang Alat Penyiram (`water_home`)

### 3.1 Spesifikasi Teknis Kapasitas
- **Kapasitas Maksimum (`MAX_WATER_UNITS`)**: 10 unit abstrak (`CONTENT.md` § 9).
- **Nilai Awal Game Baru**: 0 unit (`CONTENT.md` § 5: *"Penyiram mulai kosong agar sumber air diperkenalkan, namun suplai air tidak habis"*).
- **Konsumsi per Penyiraman**: 2 unit air per aksi siram petak (`CONTENT.md` § 6 & § 7).
- **Batas Toleransi**: Nilai air harus selalu berada pada rentang bulat `0 <= water_units <= 10`.

### 3.2 Interaksi Isi Ulang di `water_home`
- **Landmark Dunia**: Node `water_home` pada koordinat `(4, 0, 9)` di `scenes/world/level_graybox.tscn`.
- **Mekanik Input**: Tahan tombol `E` selama 2.0 detik (`CONTENT.md` § 9: *"Tahan E 2 detik di water_home, sampai 10; tidak menghabiskan stok dunia"*).
- **Kondisi Validitas**:
  - Pemain mengarahkan pandangan ke `water_home` (terdeteksi oleh `InteractionDetector`).
  - Unit air saat ini < 10 (`water_units < 10`).
- **Prompt UI Dinamis**:
  - Jika `water_units < 10`: `[Tahan E 2s] Isi Air (Air: %d/10)`
  - Jika `water_units == 10`: `[E] Air Penuh (10/10)` — interaksi tahan tidak dijalankan; jika E ditekan, muncul notifikasi singkat *"Penyiram sudah penuh (10/10)."* (TEST_PLAN T33).
- **Siklus Aksi Tahan Isi Ulang**:
  1. Pemain menekan dan menahan `E`.
  2. Timer bertambah dari `0.0s` menuju `2.0s`. HUD menampilkan lingkaran/indikator progres di sekitar reticle.
  3. Jika `E` dilepas pada `t < 2.0s`, progres kembali ke `0.0s`, `water_units` tidak bertambah.
  4. Jika mencapai `2.0s`:
     - `water_units` diatur ke `10`.
     - Signal `watering_can_updated(10, 10)` dipancarkan.
     - HUD notifikasi: *"Penyiram terisi penuh (10/10)."*
     - Re-trigger protection aktif: pemain harus melepas `E` terlebih dahulu sebelum bisa berinteraksi lagi.

---

## 4. Sistem Mekanik Tahan (Hold Actions), Durasi & Keamanan Transaksi

### 4.1 Tabel Parameter Aksi Tahan

| Aksi | Alat Aktif | Target | Tombol | Durasi | Syarat Aksi | Efek Saat Selesai | Biaya Transaksi |
|---|---|---|---|---|---|---|---|
| **Gemburkan Tanah** | `tool_hoe` | `plot_home_01` | Tahan LMB | **2.0 dtk** | Petak belum diolah (`!is_hoed`) | `is_hoed = true` | 0 (Alat permanen) |
| **Pemupukan Area** | `tool_fertilizer` | `plot_home_01` | Tahan LMB | **1.0 dtk** | Nutrisi < 20 & ada 1 `fertilizer_basic` di tas | `nutrients = 100` pada seluruh petak | 1 `fertilizer_basic` dari tas |
| **Penyiraman Area** | `tool_watering_can` | `plot_home_01` | Tahan LMB | **2.0 dtk** | Kelembapan < 60 & air penyiram >= 2 | `moisture = 80` pada seluruh petak | 2 unit air dari penyiram |
| **Isi Ulang Air** | Bebas / Apa saja | `water_home` | Tahan E | **2.0 dtk** | Air penyiram < 10 | `water_units = 10` | 0 (Sumber tak terbatas) |

### 4.2 State Machine Aksi Tahan
Sistem aksi tahan diimplementasikan menggunakan State Machine yang deterministik:

```
      [ IDLE ]
         │
         │ Input ditekan & Validasi syarat lolos
         ▼
     [ HOLDING ] ◄── Delta akumulasi per frame
      ├── Tombol dilepas SEBELUM durasi / Target hilang / Context berubah
      │        │
      │        ▼
      │   [ CANCELLED ] ──► Reset elapsed = 0.0, Biaya = 0 ──► [ IDLE ]
      │
      └── Timer >= Durasi
               │
               ▼
         [ COMMITTED ] ──► Mutasi State & Potong Biaya Sekali (Atomic)
               │
               │ Tombol MASIH ditahan (Re-trigger Guard: Diam, no repeat)
               │
               └── Tombol dilepas (is_action_just_released)
                        │
                        ▼
                     [ IDLE ]
```

### 4.3 Aturan Pembatalan Tanpa Biaya (Cancellation Without Cost)
Sesuai `CONTENT.md` § 6:
> "Progres aksi dunia yang dibatalkan sebelum selesai tidak mengonsumsi sumber daya dan direset ... Tahan tombol bukan konsumsi per frame."

1. Pembatalan terjadi seketika jika salah satu kondisi berikut terpenuhi pada frame apa pun saat state `HOLDING`:
   - Tombol dilepas (`!Input.is_action_pressed(...)`).
   - Tombol kanan mouse ditekan (`Input.is_action_just_pressed("action_tool_cancel")`).
   - Arah pandangan pemain bergeser sehingga raycast tidak lagi membidik target valid (`InteractionDetector.get_current_target() != target`).
   - Jarak pemain ke objek melebihi batas interaksi (2.0 meter).
   - Terjadi perpindahan konteks input dari dunia (misal membuka Menu Pause, Buku, atau Inventaris).
   - Window kehilangan fokus OS (`NOTIFICATION_APPLICATION_FOCUS_OUT`).
2. Konsekuensi pembatalan:
   - Progres tahan direset seketika ke `0.0`.
   - Tidak ada inventaris tas (`fertilizer_basic`, `seed_bayam`) yang terpotong.
   - Tidak ada unit air penyiram yang terpotong.
   - Status petak (gembur, nutrisi, kelembapan) sama sekali tidak berubah.
   - UI progress bar/circle langsung hilang tanpa residu.

### 4.4 Aturan Proteksi Pemicuan Ulang (Re-Trigger Protection)
Sesuai `CONTENT.md` § 6:
> "Saat aksi selesai, tombol harus dilepas sebelum aksi berikutnya dapat dimulai."

1. Pada saat timer hold mencapai durasi penuh (misal 2.0s):
   - Aksi dieksekusi tepat **satu kali**.
   - State berpindah ke `COMMITTED`.
   - Timer hold berhenti (di-clamp pada durasi maksimal).
   - Selama tombol fisik masih terus ditekan oleh pemain:
     - Tidak ada perhitungan progres baru.
     - Tidak ada pemotongan biaya kedua.
     - State tetap `COMMITTED`.
2. Untuk memulai aksi tahan berikutnya:
   - Pemain wajib melepaskan tombol secara tuntas (`Input.is_action_just_released`).
   - State berpindah kembali ke `IDLE`.
   - Hanya tekanan tombol baru (`is_action_just_pressed`) yang dapat memulai siklus `HOLDING` berikutnya.

---

## 5. Interaksi Pembenah Tanah (`soil_compost`)

### 5.1 Karakteristik Unik Pembenah Tanah
1. **Bukan Alat Akses 1–4**:
   - `CONTENT.md` § 6 secara eksplisit menegaskan: *"Pembenah dipakai lewat prompt E Tambah pembenah — 1 ketika tanah sudah gembur tetapi belum siap. Tidak membutuhkan alat kelima."*
   - Pembenah tidak dipilih menggunakan hotkey angka atau ditempatkan di tangan.
2. **Prioritas Interaksi E pada Petak**:
   - Berdasarkan `UI_UX.md` § 4:
     > "Urutan prioritas petak: panen pada tanaman siap yang dituju -> tambah pembenah bila relevan -> inspeksi. Alat aktif dapat menawarkan klik kiri untuk aksi lain tanpa menggantikan prompt E."
3. **Pohon Logika Prompt E pada Petak `plot_home_01`**:
   - **Kondisi 1: Ada tanaman siap panen di titik yang dibidik**:
     - Prompt: `[E] Panen Bayam`
   - **Kondisi 2: Tanah sudah gembur (`is_hoed == true`) DAN belum diberi pembenah (`has_compost == false`)**:
     - Jika tas memiliki `soil_compost >= 1`:
       - Prompt: `[E] Tambah pembenah — 1`
       - Ketika E ditekan:
         - Potong 1 `soil_compost` dari tas secara atomik (`InventoryManager.backpack.remove_item("soil_compost", 1)`).
         - Ubah status petak: `GardenManager.add_compost("plot_home_01")` -> `has_compost = true`.
         - Petak kini berstatus **Siap Tanam** (`is_ready_to_plant == true`).
         - Notifikasi: *"Pembenah tanah ditambahkan. Petak siap ditanami."*
     - Jika tas TIDAK memiliki `soil_compost` (jumlah 0):
       - Prompt: `[E] Periksa Petak`
       - Ketika E ditekan: tampilkan pesan inspeksi *"Tanah sudah gembur. Tambahkan pembenah tanah sebelum menanam."*
   - **Kondisi 3: Tanah belum gembur (`is_hoed == false`)**:
     - Prompt: `[E] Periksa Petak`
     - Pesan inspeksi: *"Tanah belum diolah. Gemburkan dengan cangkul [1]."*
   - **Kondisi 4: Tanah sudah gembur dan sudah diberi pembenah (`has_compost == true`)**:
     - Prompt: `[E] Periksa Petak`
     - Pembenah tidak dapat dipakai ulang (TEST_PLAN T33).
     - Pesan inspeksi: *"Petak siap tanam | Nutrisi: %d/100 | Kelembapan: %d/100"*

---

## 6. Bidikan Titik Tanam (Spot Targeting untuk `tool_seed`)

### 6.1 Struktur Fisik Petak dan Kuadran Titik
Petak `plot_home_01` berukuran 2.0 × 2.0 meter dengan 4 titik tanam kuadran (`scenes/world/level_graybox.tscn`):
- `spot_0` (`slot_01`): Kuadran Barat Laut (NW) `Vector3(-0.5, 0.1, -0.5)`
- `spot_1` (`slot_02`): Kuadran Timur Laut (NE) `Vector3(0.5, 0.1, -0.5)`
- `spot_2` (`slot_03`): Kuadran Barat Daya (SW) `Vector3(-0.5, 0.1, 0.5)`
- `spot_3` (`slot_04`): Kuadran Tenggara (SE) `Vector3(0.5, 0.1, 0.5)`

### 6.2 Algoritma Deteksi Bidikan Titik
`InteractionDetector` (RayCast3D) memancarkan sinar dari kamera pemain ke dunia. Ketika raycast mengenai `plot_home_01` (baik `SoilBed` maupun area petak):
1. Dapatkan titik tabrakan global: `var hit_pt: Vector3 = detector.get_collision_point()`.
2. Transformasikan titik ke koordinat lokal petak: `var local_pt: Vector3 = plot_node.to_local(hit_pt)`.
3. Tentukan kuadran berdasarkan tanda sumbu X dan Z:
   ```gdscript
   func get_targeted_spot_id(local_pt: Vector3) -> String:
       if local_pt.x < 0.0:
           return "slot_01" if local_pt.z < 0.0 else "slot_03"
       else:
           return "slot_02" if local_pt.z < 0.0 else "slot_04"
   ```
4. Verifikasi jarak titik kontak ke pusat kuadran tidak melenceng keluar petak (`abs(local_pt.x) <= 1.0 and abs(local_pt.z) <= 1.0`).

### 6.3 Validasi & Transaksi Penanaman (`tool_seed`)
Ketika pemain mengarahkan `tool_seed` ke titik tertentu dan menekan tombol klik kiri:
1. **Pemeriksaan Kesiapan Petak**:
   - Apakah petak sudah gembur dan sudah diberi pembenah? (`is_hoed and has_compost`).
   - Jika **TIDAK**: Tolak aksi! Biaya 0. Tampilkan notifikasi:
     *"Gemburkan tanah dan tambahkan pembenah dahulu."* (`CONTENT.md` § 11, TEST_PLAN T08).
2. **Pemeriksaan Titik Terisi**:
   - Apakah titik sasaran (`slot_01`..`slot_04`) sudah terisi tanaman? (`is_occupied`).
   - Jika **YA**: Tolak aksi! Biaya 0. Tampilkan notifikasi:
     *"Titik tanam sudah terisi."* (TEST_PLAN T08).
3. **Pemeriksaan Ketersediaan Benih**:
   - Apakah tas memiliki minimal 1 `seed_bayam`? (`InventoryManager.backpack.get_item_count("seed_bayam") >= 1`).
   - Jika **TIDAK**: Tolak aksi! Tampilkan notifikasi:
     *"Benih belum tersedia. Periksa wadah dekat alat."* (`CONTENT.md` § 11).
4. **Eksekusi Penanaman Atomik**:
   - Kurangi 1 `seed_bayam` dari tas: `InventoryManager.backpack.remove_item("seed_bayam", 1)`.
   - Daftarkan tanaman pada titik: `GardenManager.plant_crop("plot_home_01", spot_id, "crop_bayam")`.
   - Update visual marker pada titik tersebut (muncul gundukan tanah benih).
   - Notifikasi sukses: *"Benih bayam berhasil ditanam."*
5. **Isolasi Multi-Titik**:
   - Penanaman pada `slot_01` tidak boleh mengubah status titik `slot_02`, `slot_03`, atau `slot_04`. Masing-masing titik mempertahankan isolasi state independen.

---

## 7. Arsitektur Komponen & Kontrak Antarmuka

Untuk menjaga modularitas, decoupling, dan kemudahan pengujian headless, sistem alat dan interaksi dibagi menjadi:
1. **`ToolManager` (`scripts/tools/tool_manager.gd`)**:
   - Mengelola state alat aktif (`active_tool`), kapasitas air (`water_units`), batas kapasitas (10), dan helper ketersediaan alat.
   - Diposisikan sebagai autoload terdaftar atau modul terpadu.
2. **`PlayerActionController` (atau ekstensi di `PlayerController`)**:
   - Mengontrol siklus frame aksi tahan (`_physics_process`), deteksi hold/release, pengecekan kontekstual, pemancaran progres ke HUD, dan re-trigger guard.
3. **`InteractionDetector` (`scripts/interaction/interaction_detector.gd`)**:
   - Mendeteksi objek di depan crosshair (jarak maks 2.0 meter), mendeteksi petak dan titik kuadran aktif, serta menyuplai data ke HUD prompt.
4. **`HUD` (`scripts/ui/hud.gd`)**:
   - Menampilkan prompt E kontekstual.
   - Menampilkan prompt alat LMB bila ada alat aktif yang relevan.
   - Menampilkan bilah status alat di bawah tengah (`Nama Alat + Resource`).
   - Menampilkan indikator progres lingkaran/bar di sekitar reticle saat aksi tahan berlangsung.

### 7.1 Spesifikasi Kontrak Sinyal
- **ToolManager**:
  ```gdscript
  signal tool_selected(tool_id: String, display_name: String)
  signal tool_deselected()
  signal water_units_changed(current_water: int, max_water: int)
  signal watering_can_refilled(amount: int)
  ```
- **PlayerActionController / Hold System**:
  ```gdscript
  signal hold_action_started(action_id: String, duration: float)
  signal hold_action_progress(action_id: String, progress: float, elapsed: float, duration: float)
  signal hold_action_completed(action_id: String)
  signal hold_action_cancelled(action_id: String)
  ```

---

## 8. Desain Implementasi GDScript

### 8.1 Rancangan `ToolManager` (`scripts/tools/tool_manager.gd`)
```gdscript
class_name ToolManager
extends Node

## Pengelola Alat dan Kapasitas Air untuk 'Buku Resep 2045'
## Memenuhi spesifikasi CONTENT.md § 2, § 6, § 9, UI_UX.md UI01, dan TEST_PLAN T06, T07, T32, T33

signal tool_selected(tool_id: String, display_name: String)
signal tool_deselected()
signal water_units_changed(current_water: int, max_water: int)
signal watering_can_refilled(amount: int)

const MAX_WATER_CAPACITY: int = 10
const TOOL_NONE: String = ""
const TOOL_HOE: String = "tool_hoe"
const TOOL_SEED: String = "tool_seed"
const TOOL_FERTILIZER: String = "tool_fertilizer"
const TOOL_WATERING_CAN: String = "tool_watering_can"

const TOOL_NAMES: Dictionary = {
	TOOL_HOE: "Alat tanah",
	TOOL_SEED: "Tanam benih",
	TOOL_FERTILIZER: "Pupuk",
	TOOL_WATERING_CAN: "Penyiram"
}

var active_tool: String = TOOL_NONE
var water_units: int = 0: # Mulai 0 pada game baru (CONTENT.md § 5 & § 9)
	set(val):
		water_units = clampi(val, 0, MAX_WATER_CAPACITY)
		water_units_changed.emit(water_units, MAX_WATER_CAPACITY)

func _ready() -> void:
	active_tool = TOOL_NONE

func select_tool(slot: int) -> void:
	var target_tool: String = TOOL_NONE
	match slot:
		1: target_tool = TOOL_HOE
		2: target_tool = TOOL_SEED
		3: target_tool = TOOL_FERTILIZER
		4: target_tool = TOOL_WATERING_CAN
		_: target_tool = TOOL_NONE
	
	# Pola toggle: jika alat yang sama dipilih lagi, kembali ke tangan kosong
	if active_tool == target_tool and target_tool != TOOL_NONE:
		deselect_tool()
	else:
		active_tool = target_tool
		if active_tool != TOOL_NONE:
			tool_selected.emit(active_tool, TOOL_NAMES.get(active_tool, ""))
		else:
			tool_deselected.emit()

func select_tool_by_id(tool_id: String) -> void:
	if active_tool == tool_id and tool_id != TOOL_NONE:
		deselect_tool()
	else:
		active_tool = tool_id
		if active_tool != TOOL_NONE:
			tool_selected.emit(active_tool, TOOL_NAMES.get(active_tool, ""))
		else:
			tool_deselected.emit()

func deselect_tool() -> void:
	active_tool = TOOL_NONE
	tool_deselected.emit()

func get_active_tool() -> String:
	return active_tool

func is_tool_active(tool_id: String) -> bool:
	return active_tool == tool_id

func has_any_tool() -> bool:
	return active_tool != TOOL_NONE

func refill_water() -> bool:
	if water_units >= MAX_WATER_CAPACITY:
		return false
	water_units = MAX_WATER_CAPACITY
	watering_can_refilled.emit(MAX_WATER_CAPACITY)
	return true

func can_consume_water(amount: int = 2) -> bool:
	return water_units >= amount

func consume_water(amount: int = 2) -> bool:
	if water_units >= amount:
		water_units -= amount
		return true
	return false
```

### 8.2 Rancangan State Machine Aksi Tahan di `PlayerController`
```gdscript
# Enumerasi state aksi tahan
enum HoldState {
	IDLE,
	HOLDING,
	COMMITTED
}

var _hold_state: HoldState = HoldState.IDLE
var _hold_action_id: String = ""
var _hold_duration: float = 0.0
var _hold_elapsed: float = 0.0
var _hold_target: Object = null
var _hold_input_action: StringName = &""

func _process_hold_action(delta: float) -> void:
	if _hold_state == HoldState.IDLE:
		return

	# 1. Jika state COMMITTED, tunggu sampai pemain melepas tombol fisik (re-trigger guard)
	if _hold_state == HoldState.COMMITTED:
		if not Input.is_action_pressed(_hold_input_action):
			_hold_state = HoldState.IDLE
			_hold_action_id = ""
			_hold_target = null
		return

	# 2. State HOLDING: Verifikasi pembatalan frame-by-frame
	var cancel: bool = false

	# Batal jika tombol dilepas atau tombol cancel (RMB) ditekan
	if not Input.is_action_pressed(_hold_input_action) or Input.is_action_just_pressed("action_tool_cancel"):
		cancel = true
	
	# Batal jika context bukan WORLD
	var im: Node = get_node_or_null("/root/InputManager")
	if im != null and not im.is_world_context():
		cancel = true

	# Batal jika target berubah atau hilang dari jangkauan
	if interaction_detector == null or not is_instance_valid(_hold_target):
		cancel = true
	else:
		var current_tgt = interaction_detector.get_current_target()
		if current_tgt != _hold_target and interaction_detector.get_collider() != _hold_target:
			cancel = true

	if cancel:
		_cancel_hold_action()
		return

	# 3. Akumulasi timer
	_hold_elapsed += delta
	var progress: float = clampf(_hold_elapsed / _hold_duration, 0.0, 1.0)
	hold_action_progress.emit(_hold_action_id, progress, _hold_elapsed, _hold_duration)

	# 4. Commit saat durasi tercapai
	if _hold_elapsed >= _hold_duration:
		_commit_hold_action()

func _cancel_hold_action() -> void:
	var action_id := _hold_action_id
	_hold_state = HoldState.IDLE
	_hold_action_id = ""
	_hold_elapsed = 0.0
	_hold_duration = 0.0
	_hold_target = null
	hold_action_cancelled.emit(action_id)

func _commit_hold_action() -> void:
	_hold_state = HoldState.COMMITTED
	var action_id := _hold_action_id
	
	# Eksekusi payload sesuai jenis aksi
	match action_id:
		"hoe":
			GardenManager.hoe_plot("plot_home_01")
		"fertilizer":
			InventoryManager.backpack.remove_item("fertilizer_basic", 1)
			GardenManager.fertilize_plot("plot_home_01")
		"water":
			ToolManager.consume_water(2)
			GardenManager.water_plot("plot_home_01")
		"refill_water":
			ToolManager.refill_water()

	hold_action_completed.emit(action_id)
```

---

## 9. Matriks Kasus Uji Penerimaan & Pengujian Headless

Sesuai dengan `docs/TEST_PLAN.md`, berikut adalah kasus uji yang wajib dipenuhi dan divalidasi pada pengujian headless `test_gardening.gd`:

| ID Tes | Kondisi Awal | Langkah Tindakan | Hasil yang Diharapkan (Expected Contract) |
|---|---|---|---|
| **T06** | Petak `plot_home_01` terisi / belum dipupuk (`nutrients < 20`), tas memiliki 1 `fertilizer_basic` | Tahan LMB 1.0s dengan `tool_fertilizer` | Tepat 1 pupuk terpotong, `nutrients` petak menjadi 100, berlaku untuk seluruh 4 kuadran petak. |
| **T07** | Petak `plot_home_01` dengan kelembapan >= 60 (`moisture = 70`) | Arahkan `tool_watering_can`, coba tahan LMB | Aksi ditolak tanpa biaya, unit air penyiram tetap utuh, kelembapan tidak berubah, muncul alasan *"Petak sudah cukup."* |
| **T08** | Titik `slot_01` terisi tanaman ATAU tanah belum gembur/belum ada pembenah | Klik LMB dengan `tool_seed` pada titik | Ditolak dengan alasan yang jelas, benih di tas tidak berkurang, tidak ada mutasi titik. |
| **T32** | Mulai aksi cangkul/pupuk/siram | Lepas tombol pada progres 50% (misal 1.0s pada cangkul) | Tidak ada konsumsi item/air, progres kembali ke 0, state petak tidak termutasi. Tombol harus dilepas sebelum aksi baru. |
| **T33** | Coba tambah pembenah pada petak yang sudah dibenahi ATAU pupuk saat nutrisi >= 20 ATAU isi air saat sudah 10 | Eksekusi interaksi / tahan | Tidak boros resource (compost/fertilizer/water tidak terpotong), kapasitas tidak tembus >10, pesan penolakan benar. |
| **SPOT-ISO** | 4 titik pada petak yang siap tanam | Tanam benih hanya pada `slot_01` | Hanya `slot_01` yang menjadi `occupied`, titik `slot_02`, `slot_03`, `slot_04` tetap kosong dan siap ditanami. |
| **REFILL-01** | Game baru, penyiram memiliki 0 air | Tahan E 2.0s pada `water_home` | Air penyiram terisi menjadi 10. Jika dicoba isi ulang lagi, interaksi tahan ditolak (air penuh). |

---

## 10. Kesimpulan Desain & Rencana Eksekusi Implementasi

1. **Struktur Bersih & Terpisah**:
   Logika alat dan kapasitas air (`ToolManager`) dipisahkan dari logika simulasi pertumbuhan petak (`GardenManager`), sehingga masing-masing komponen memiliki Single Responsibility yang jelas.
2. **Kepatuhan Mutlak Terhadap PRD & Dokumen Acuan**:
   - 4 alat tetap (Keys 1–4), toggle tangan kosong.
   - Pembenah tanah diakses eksklusif via tombol kontekstual `E`.
   - Kapasitas penyiram 10 unit abstrak, mulai 0, isi ulang tahan E 2s di `water_home`.
   - Mekanik tahan dengan re-trigger guard dan pembatalan tanpa biaya.
   - Penanaman titik kuadran terisolasi.
3. **Kesiapan Verifikasi**:
   Arsitektur ini didesain agar kompatibel 100% dengan runner headless Godot (`tests/test_runner.gd`), harness deterministik, dan dapat diverifikasi tanpa intervensi manual.
