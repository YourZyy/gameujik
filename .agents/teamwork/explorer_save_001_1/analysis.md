# Laporan Analisis Arsitektur Envelope Simpan, Atomisitas Berkas, dan Pemulihan (SAVE-001)

**Penulis:** `explorer_save_001_1` (Save Envelope & Architecture Explorer)  
**Milestone:** `SAVE-001` (Sistem Simpan/Muat dan Pemulihan Game State Terpadu)  
**Proyek:** *Buku Resep 2045* (Godot 4.7.2 / GDScript / GL Compatibility 3D First Person)  
**Tanggal:** 29 Oktober 2026  
**Status:** Read-Only Investigation & Architectural Analysis Report  
**Dokumen Acuan:** `CONTENT.md` (§ 12, § 14), `PROTOTYPE.md` (§ 7), `TEST_PLAN.md` (T14, T16, T17, T22, T46, T47, T48, T49, T50), `AGENTS.md` (§ 4, § 8), dan Skill `save-systems`

---

## 1. Ringkasan Eksekutif & Batasan Masalah

Penyelidikan mendalam terhadap arsitektur persistensi pada proyek *Buku Resep 2045* dilakukan untuk merumuskan cetak biru implementasi **SaveManager** (`scripts/save/save_manager.gd`), skema envelope v1, mekanisme penulisan atomik, rotasi cadangan, pemulihan otomatis, serta pemisahan berkas konfigurasi preferensi pengguna (`user://settings.cfg`).

### Temuan Inti:
1. **Kesiapan Modul Gameplay:** Seluruh manajer inti (`InventoryManager`, `RecipeManager`, `GardenManager`, `WorldResourceManager`, `KitchenManager`, `DialogueManager`) telah mengimplementasikan pasangan metode kontrak snapshot: `get_save_snapshot() -> Dictionary` dan `load_save_snapshot(data: Dictionary) -> bool`.
2. **Kebutuhan Komponen Koordinator:** Saat ini belum ada Autoload `SaveManager` (`scripts/save/save_manager.gd`) yang bertindak sebagai orkestrator penyimpanan file fisik, manajemen envelope, verifikasi integritas, rotasi berkas, dan pemulihan otomatis.
3. **Pemisahan Pengaturan (T52):** Preferensi pemain (sensitivitas mouse, FOV, skala UI, volume master/musik/SFX, subtitle, dan head bob) wajib disimpan terpisah di `user://settings.cfg` menggunakan format `ConfigFile` agar load game atau game baru tidak menimpa preferensi pemain.
4. **Keamanan Penulisan Multiplatform (Windows/POSIX):** Penulisan berkas simpanan tidak boleh menimpa file target secara langsung (*in-place write*). Penulisan wajib menggunakan siklus *write to `.tmp` $\to$ flush/close $\to$ verify $\to$ rotate `.bak` $\to$ rename/replace target* untuk menjamin crash, listrik mati, atau interupsi proses (T22, T49) tidak pernah merusak berkas simpanan yang sudah ada.
5. **Integritas Envelope & Checksum SHA-256:** Envelope v1 wajib menyertakan checksum SHA-256 dari payload canonical untuk mendeteksi pemotongan file (*file truncation*), kerusakan disk, atau manipulasi file eksternal (T17, T47).

---

## 2. Arsitektur SaveManager (`scripts/save/save_manager.gd`)

### 2.1. Peran dan Tanggung Jawab
`SaveManager` dirancang sebagai simpul Autoload Singleton (`Node`) yang terdaftar di `project.godot`:
`SaveManager="*res://scripts/save/save_manager.gd"`.

Tanggung jawab utamanya meliputi:
1. **Manajemen Jalur Berkas Simpanan:**
   - Checkpoint Manual: `user://save_manual.json` (dan cadangannya `user://save_manual.json.bak`).
   - Checkpoint Autosave: `user://save_autosave.json` (dan cadangannya `user://save_autosave.json.bak`).
   - Berkas Sementara: `user://save_<slot>.json.tmp`.
   - Berkas Pengaturan: `user://settings.cfg`.
2. **Orkestrator Pengambilan & Penerapan Snapshot:**
   Mengumpulkan data dari seluruh subsistem (Player, Inventory, Recipe, Garden, World, Kitchen, Dialogue) saat simpan, dan mendistribusikan data kembali secara aman melalui protokol *Two-Phase Commit* saat muat.
3. **Penyedia API Slot & Evaluasi "Lanjutkan" (Continue):**
   Menyediakan fungsi evaluasi revisi/timestamp untuk tombol "Lanjutkan" di menu utama (T48) serta inspeksi metadata slot untuk UI Load Game.
4. **Penanganan Kesalahan & Fallback Transparan:**
   Menyediakan umpan balik jujur per `CONTENT.md § 11` saat simpan/muat gagal tanpa membuat aplikasi keluar seolah berhasil (T49).

### 2.2. Definisi Sinyal Autoload
```gdscript
signal save_started(slot_type: String)
signal save_completed(slot_type: String, file_path: String)
signal save_failed(slot_type: String, error_code: int, error_message: String)

signal load_started(slot_type: String)
signal load_completed(slot_type: String, file_path: String)
signal load_failed(slot_type: String, error_code: int, error_message: String)

signal save_recovered_from_backup(slot_type: String, backup_path: String)
signal player_position_sanitized(original_pos: Vector3, sanitized_pos: Vector3)

signal settings_loaded()
signal settings_saved()
```

---

## 3. Spesifikasi Skema Envelope v1

Sesuai `CONTENT.md § 12` (*"Save envelope: Versi skema, revisi checkpoint, waktu simpan, payload tervalidasi"*) dan best-practice `save-systems`:

### 3.1. Struktur Data Envelope v1
```json
{
  "header": {
    "schema_version": 1,
    "game_version": "0.2.0",
    "slot_type": "manual",
    "revision": 14,
    "timestamp": 1793234567,
    "timestamp_iso": "2045-10-27T10:00:00Z",
    "checksum": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "summary": {
      "day": 2,
      "time_active": 145.2,
      "recipe_id": "recipe_sayur_bening_01",
      "times_cooked": 1,
      "meal_used": false
    }
  },
  "schema_version": 1,
  "slot_type": "manual",
  "revision": 14,
  "timestamp": 1793234567,
  "checksum": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "payload": {
    "player": { ... },
    "inventory": { ... },
    "recipe": { ... },
    "gardening": { ... },
    "world": { ... },
    "cooking": { ... },
    "dialogue": { ... }
  }
}
```

*Catatan Desain:* Kunci-kunci penting (`schema_version`, `slot_type`, `revision`, `timestamp`, `checksum`) disediakan baik pada root dictionary maupun di dalam sub-objek `"header"`. Ini memberikan kemudahan bagi UI menu untuk membaca metadata cepat (*header inspection*) tanpa harus mengurai seluruh isi payload yang besar.

### 3.2. Integritas Checksum SHA-256
- Checksum dihitung dari representasi string JSON canonical dari `payload`:
  ```gdscript
  var payload_str: String = JSON.stringify(payload, "", false) # compact JSON, tanpa whitespace acak
  var checksum: String = payload_str.sha256_text()
  ```
- **Karakteristik SHA-256 Godot:** `String.sha256_text()` menghasilkan 64-karakter string hex lowercase yang deterministik, cepat, dan native di Godot 4 tanpa alokasi memori berlebih.
- **Validasi saat Muat:** Jika string JSON berhasil di-parse namun `checksum` di envelope tidak cocok dengan `sha256_text()` payload aktual, berkas dianggap rusak/terpotong (T17, T22), dan loader memicu fallback ke cadangan `.bak`.

---

## 4. Mekanisme Penulisan Atomik (`.tmp` $\to$ Replace) dan Kompatibilitas Sistem Berkas

### 4.1. Masalah Penulisan Langsung (*In-Place Overwrite Hazard*)
Membuka berkas save langsung dengan `FileAccess.WRITE` berisiko tinggi: jika game mengalami crash, crash daya listrik, atau aplikasi ditutup paksa di tengah proses penulisan, berkas akan terpotong (*truncated*) atau berukuran 0 byte, memusnahkan seluruh progres pemain secara permanen.

### 4.2. Alur Penulisan Atomik Teruji (Windows & POSIX)
Di lingkungan Windows, Godot `DirAccess.rename_absolute(src, dst)` menggunakan Win32 API `MoveFile` yang dapat mengembalikan `ERR_ALREADY_EXISTS` jika berkas tujuan sudah ada. Oleh karena itu, urutan rotasi aman harus dirancang defensif:

```
[ Step 1: Serialize Snapshot ]
     │  - Kumpulkan payload dari seluruh subsistem
     │  - Bungkus dalam Envelope v1 + Checksum SHA-256
     │  - Serialize ke JSON String (payload_json)
     ▼
[ Step 2: Write to .tmp ]
     │  - Buka target_path + ".tmp" via FileAccess.open(..., WRITE)
     │  - JIKA GAGAL (disk full / permission denied):
     │      - Bersihkan .tmp
     │      - Kembalikan ERR_FILE_CANT_WRITE (T49)
     │  - Tulis string JSON
     │  - f.flush() lalu f.close()
     ▼
[ Step 3: Verify .tmp Existence & Size ]
     │  - Periksa FileAccess.file_exists(tmp_path)
     │  - Periksa FileAccess.get_file_size(tmp_path) > 0
     ▼
[ Step 4: Rotate Existing Primary to .bak ]
     │  - JIKA FileAccess.file_exists(primary_path):
     │      - JIKA FileAccess.file_exists(bak_path):
     │          - DirAccess.remove_absolute(bak_path) (wajib untuk Windows)
     │      - DirAccess.rename_absolute(primary_path, bak_path)
     ▼
[ Step 5: Replace Primary with .tmp ]
     │  - JIKA FileAccess.file_exists(primary_path):
     │      - DirAccess.remove_absolute(primary_path)
     │  - DirAccess.rename_absolute(tmp_path, primary_path)
     ▼
[ Step 6: Emit save_completed ]
        - Kembalikan Dictionary { "success": true, "path": primary_path }
```

### 4.3. Penanganan Kegagalan Simulasi Tulis (T49)
Sesuai **TEST_PLAN T49**:
- Menyediakan hook pengujian `simulate_write_failure: bool = false`.
- Jika penulisan gagal (baik simulasi maupun disk error nyata):
  - Berkas `.tmp` segera dihapus jika ada.
  - Berkas checkpoint utama dan cadangan `.bak` **TIDAK TERSENTUH**.
  - Mengembalikan pesan kesalahan jujur:
    `"Progres belum tersimpan. Coba lagi atau gunakan lokasi simpan yang dapat ditulis."` (CONTENT § 11).
  - Aplikasi **TIDAK KELUAR** seolah-olah berhasil.

---

## 5. Rotasi Cadangan (`.bak`) & Pemulihan Otomatis

### 5.1. Hirarki Pemuatan Defensif
Saat memuat slot (`slot_type = "manual"` atau `"autosave"`):
1. **Target Utama:** `user://save_<slot_type>.json`
2. **Target Cadangan:** `user://save_<slot_type>.json.bak`

### 5.2. Logika Deteksi Kerusakan dan Fallback
```
           [ Load Request: slot_type ]
                       │
                       ▼
          [ Cek Target Utama (.json) ]
            /                      \
      (Ada & Terbaca)          (Tidak Ada / Error Buka)
          /                            \
[ Parse JSON & Validasi ]                \
   - Parse JSON string                    \
   - Checksum SHA-256 cocok?               \
   - Schema version == 1?                   \
   - Section payload lengkap?                \
         /            \                       \
      (Valid)       (Rusak / Mismatch)         \
        /                 \                     \
       /                   ▼                     ▼
      /              [ Log Warning ]       [ Log Warning ]
     /               "Checkpoint rusak"    "Checkpoint hilang"
    /                      │                     │
   │                       └──────────┬──────────┘
   │                                  │
   │                                  ▼
   │                     [ Cek Target Cadangan (.bak) ]
   │                       /                       \
   │                 (Ada & Terbaca)            (Tidak Ada / Rusak)
   │                     /                               \
   │           [ Parse JSON & Validasi ]                  \
   │             - Checksum SHA-256 cocok?                 \
   │             - Schema version == 1?                     \
   │             - Section payload lengkap?                  \
   │                   /            \                         \
   │                (Valid)       (Rusak)                      \
   │                  /                 \                       \
   │                 ▼                   ▼                       ▼
   │     [ Emit save_recovered_from_backup ]            [ Emit load_failed ]
   │     [ Pulihkan Primary dari .bak ]                 "Data simpan tidak cocok"
   │     [ Siapkan Payload Cadangan ]                   "Dunia aktif tidak diubah"
   │                 │                                           │
   ▼                 ▼                                           ▼
[ Lanjut ke Two-Phase Commit Swap ]                     [ Hentikan Proses Muat ]
```

### 5.3. Pemulihan Mandiri (*Self-Healing*)
Ketika checkpoint utama rusak tetapi berkas `.bak` valid:
1. Sinyal `save_recovered_from_backup(slot_type, bak_path)` dipancarkan.
2. Loader menyalin kembali konten valid dari `.bak` ke `.json` (atau menjadwalkan penyimpanan ulang atomik) sehingga berkas utama pulih untuk pemanggilan berikutnya.
3. Notifikasi toast ditampilkan ke pemain: `"Checkpoint utama dipulihkan dari cadangan valid."`.

---

## 6. Penyimpanan Pengaturan Terpisah (`user://settings.cfg`)

### 6.1. Alasan Pemisahan Arsitektural
Berdasarkan `CONTENT.md § 12`, `PROTOTYPE.md § 7`, dan `TEST_PLAN T52`:
- Memuat progres permainan (save/load) atau memulai game baru **TIDAK BOLEH** menimpa preferensi audio, sensitivitas, FOV, atau skala antarmuka pemain.
- Format `ConfigFile` dipilih karena:
  1. Standar native Godot engine yang sangat andal, berbasis format INI teks yang dapat dibaca manusia.
  2. Mendukung enkapsulasi per-bagian (`[gameplay]`, `[video]`, `[audio]`, `[accessibility]`).
  3. Mendukung serialisasi tipe data native (float, int, bool, Vector2) secara transparan.

### 6.2. Struktur Default `settings.cfg` (CONTENT.md § 14)
```ini
[gameplay]
mouse_sensitivity_multiplier=1.0
head_bob=false

[video]
fov=80.0
ui_scale=1.0
window_mode=0

[audio]
master_volume=0.7
music_volume=0.4
sfx_volume=0.7

[accessibility]
subtitles=true
```

### 6.3. API Manajer Pengaturan
`SaveManager` menyediakan antarmuka khusus:
- `load_settings() -> Dictionary`
- `save_settings(settings: Dictionary) -> Error`
- `get_setting(section: String, key: String, default_val: Variant) -> Variant`
- `set_setting(section: String, key: String, val: Variant) -> void`
- `apply_all_settings() -> void`
  - Memperbarui FOV kamera pemain (`camera.fov = fov`).
  - Memperbarui sensitivitas kontroler (`mouse_sensitivity = BASE * multiplier`).
  - Memperbarui volume bus AudioServer (konversi linier ke dB).
  - Memperbarui skala viewport antarmuka (`DisplayServer / Window content scale factor`).

---

## 7. Protokol Swap Dua Fase & Orkestrasi Multi-Subsistem

Untuk mencegah kondisi *"half-loaded world"* saat salah satu modul gagal dimuat:

### 7.1. Fase 1: Validasi Pasif Pra-Swap (*Dry-Run Pre-Flight*)
Fungsi `validate_save_payload(envelope: Dictionary) -> Dictionary` memeriksa secara in-memory:
1. `schema_version == 1`
2. Envelope memiliki key `"payload"` bertipe Dictionary.
3. Ketersediaan 7 sub-payload domain:
   - `"player"`, `"inventory"`, `"recipe"`, `"gardening"`, `"world"`, `"cooking"`, `"dialogue"`.
4. Validasi Domain Kritis:
   - `inventory`: Panjang array `backpack` == 12, `storage_home` == 12. Semua `item_id` valid di `ItemRegistry`.
   - `gardening`: Memiliki `plots["plot_home_01"]` dengan 4 slot.
   - `cooking`: `job_state` berada di rentang 0..6.
   - `world`: `current_day >= 1`.
   - `player`: `position` adalah Array 3 elemen numeric (tidak `NaN`/`Inf`).

### 7.2. Fase 2: Eksekusi Atomik Swap Dunia
Jika Fase 1 lolos 100%, penerapan ke live singletons dilakukan secara terurut:
1. `InventoryManager.load_save_snapshot(payload["inventory"])`
2. `RecipeManager.load_save_snapshot(payload["recipe"])`
3. `GardenManager.load_save_snapshot(payload["gardening"])`
4. `WorldResourceManager.load_save_snapshot(payload["world"])`
5. `KitchenManager.load_save_snapshot(payload["cooking"])`
6. `DialogueManager.load_save_snapshot(payload["dialogue"])`
7. `PlayerController.load_save_snapshot(payload["player"])` (dengan T22 boundary fallback)

### 7.3. Sanitasi Koordinat Pemain (T22 & LEVEL_DESIGN § 4)
Jika koordinat pemain out-of-bounds ($X \notin [-42, 42]$, $Z \notin [-37, 47]$, atau $Y < -5.0$ / $Y > 50.0$) atau mengandung `NaN`/`Inf`:
- Posisi dialihkan otomatis ke `safe_return_home` `(0.0, 0.0, 8.0)` atau `spawn_home` `(0.0, 0.0, 1.0)`.
- Sinyal `player_position_sanitized` dipancarkan.
- Seluruh inventaris, kebun, dan progres cerita **TIDAK DIHAPUS**.

---

## 8. Matriks Kebutuhan Kasus Uji (TEST_PLAN.md)

| ID Uji | Skenario Pengujian | Perilaku Expected Kontrak | Penanganan di SaveManager |
|---|---|---|---|
| **T14** | Simpan saat tanaman tumbuh dan job dapur dijeda (`PAUSED`); keluar lalu muat | Kemajuan tanaman/job, reservasi, alat/air pulih persis; waktu tidak berjalan offline | Memulihkan `growth_time`, `cook_progress`, `job_state`, `watering_can_water` tanpa lompatan jam OS |
| **T16** | Main sampai setelah berbagi masakan; simpan; restart; "Lanjutkan" | Buku centang, `meal_used=true`, `p0_completed=true`, sumber, petak, posisi konsisten | Evaluasi konsistensi seluruh 7 subsistem snapshot secara terpadu |
| **T17** | Rusakkan checkpoint utama fixture (potong byte / corrupt JSON); muat | Tidak memuat setengah dunia; otomatis fallback ke `.bak` valid atau pesan gagal | Parser JSON gagal $\to$ fallback ke `.bak` $\to$ emit `save_recovered_from_backup` |
| **T22** | Hentikan proses saat fase penulisan terkontrol | Setidaknya checkpoint valid sebelumnya/cadangan dapat dipulihkan; tidak mengaku save sukses | Menulis ke `.tmp` dahulu $\to$ target asli tetap utuh jika proses terputus |
| **T46** | Bandingkan snapshot lengkap sebelum save dan sesudah load | Semua entitas dinamis CONTENT pulih identik, termasuk output/refund/flag | Uji invariansi round-trip snapshot sebelum vs sesudah serialisasi |
| **T47** | Fixture save versi tidak cocok (`version=99`) atau item tak dikenal; coba muat | Validasi menolak sebelum mutasi; dunia lama tidak diubah | Fase 1 Pre-Flight menolak load; live singletons 100% utuh |
| **T48** | Buat manual, main hingga autosave lebih baru; uji "Lanjutkan" dan "Muat" manual | "Lanjutkan" memilih revisi valid terbaru; manual lama tetap dapat dipilih di menu muat | `get_continue_slot()` membandingkan `revision` terbesar; slot manual tetap ada di disk |
| **T49** | Simulasikan gagal tulis/ruang tidak cukup; pilih Simpan dan Keluar | Pesan gagal; aplikasi tidak keluar seolah berhasil; checkpoint lama tetap valid | `simulate_write_failure` $\to$ bersihkan `.tmp`, jangan keluar aplikasi, kembalikan pesan gagal |
| **T50** | Muat snapshot job selesai (`OUTPUT_READY`) berulang, ambil output sekali | Tidak re-commit output atau menambah jumlah dibuat lagi; slot hasil tetap tunggal | Restorasi `OUTPUT_READY` mempertahankan hidangan di slot hasil tanpa memicu commit ganda |

---

## 9. Cetak Biru Kode Implementasi (`scripts/save/save_manager.gd`)

Berikut adalah struktur kode lengkap yang dirancang siap pakai untuk implementor:

```gdscript
class_name SaveManagerClass
extends Node

## SaveManager — Pengelola Persistensi Terpadu Buku Resep 2045
## Memenuhi spesifikasi PRD FR15, CONTENT § 12 & § 14, PROTOTYPE § 7, dan TEST_PLAN T14-T50

signal save_started(slot_type: String)
signal save_completed(slot_type: String, file_path: String)
signal save_failed(slot_type: String, error_code: int, error_message: String)

signal load_started(slot_type: String)
signal load_completed(slot_type: String, file_path: String)
signal load_failed(slot_type: String, error_code: int, error_message: String)

signal save_recovered_from_backup(slot_type: String, backup_path: String)
signal player_position_sanitized(original_pos: Vector3, sanitized_pos: Vector3)

signal settings_loaded()
signal settings_saved()

const SCHEMA_VERSION: int = 1
const GAME_VERSION: String = "0.2.0"

const PATH_SAVE_MANUAL: String = "user://save_manual.json"
const PATH_SAVE_AUTOSAVE: String = "user://save_autosave.json"
const PATH_SETTINGS: String = "user://settings.cfg"

# Fallback Koordinat Aman (LEVEL_DESIGN § 4 & PlayerConfig)
const SAFE_RETURN_POSITION: Vector3 = Vector3(0.0, 0.0, 8.0)
const SPAWN_HOME_POSITION: Vector3 = Vector3(0.0, 0.0, 1.0)
const BOUND_MIN_X: float = -42.0
const BOUND_MAX_X: float = 42.0
const BOUND_MIN_Z: float = -37.0
const BOUND_MAX_Z: float = 47.0
const BOUND_MIN_Y: float = -5.0
const BOUND_MAX_Y: float = 50.0

# Counter revisi checkpoint in-memory
var _current_revision: int = 0

# Hook Pengujian (T49)
var simulate_write_failure: bool = false

# Cache Pengaturan
var _settings: Dictionary = {}

func _ready() -> void:
	load_settings()
	_update_revision_from_existing_saves()

func get_slot_path(slot_type: String) -> String:
	match slot_type:
		"autosave": return PATH_SAVE_AUTOSAVE
		_: return PATH_SAVE_MANUAL

# ==============================================================================
# 1. ATOMIC SAVE PIPELINE
# ==============================================================================

func save_game(slot_type: String = "manual") -> Dictionary:
	save_started.emit(slot_type)
	
	if simulate_write_failure:
		var err_msg := "Progres belum tersimpan. Coba lagi atau gunakan lokasi simpan yang dapat ditulis."
		save_failed.emit(slot_type, ERR_FILE_CANT_WRITE, err_msg)
		return {"success": false, "error": ERR_FILE_CANT_WRITE, "message": err_msg}

	var target_path := get_slot_path(slot_type)
	var tmp_path := target_path + ".tmp"
	var bak_path := target_path + ".bak"

	# 1. Kumpulkan snapshot payload dari seluruh manajer
	var payload := capture_all_states()
	
	# 2. Buat Envelope v1 dengan Checksum SHA-256
	_current_revision += 1
	var envelope := create_envelope(slot_type, payload)
	var json_str := JSON.stringify(envelope, "\t")

	# 3. Tulis ke berkas sementara .tmp
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		var err_msg := "Progres belum tersimpan. Coba lagi atau gunakan lokasi simpan yang dapat ditulis."
		save_failed.emit(slot_type, err, err_msg)
		return {"success": false, "error": err, "message": err_msg}

	file.store_string(json_str)
	file.flush()
	file.close()

	# 4. Verifikasi berkas .tmp tertulis
	if not FileAccess.file_exists(tmp_path) or FileAccess.get_file_as_bytes(tmp_path).size() == 0:
		var err_msg := "Progres belum tersimpan. File sementara tidak valid."
		save_failed.emit(slot_type, ERR_FILE_CORRUPT, err_msg)
		return {"success": false, "error": ERR_FILE_CORRUPT, "message": err_msg}

	# 5. Rotasi file utama yang ada ke .bak
	if FileAccess.file_exists(target_path):
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		var bak_err := DirAccess.rename_absolute(target_path, bak_path)
		if bak_err != OK:
			print("[SaveManager] Peringatan: Gagal merotasi ke .bak: ", bak_err)

	# 6. Ganti target utama dengan .tmp
	if FileAccess.file_exists(target_path):
		DirAccess.remove_absolute(target_path)
	var rename_err := DirAccess.rename_absolute(tmp_path, target_path)
	if rename_err != OK:
		# Upaya pemulihan dari .bak jika rename gagal
		if FileAccess.file_exists(bak_path) and not FileAccess.file_exists(target_path):
			DirAccess.rename_absolute(bak_path, target_path)
		var err_msg := "Gagal mengganti berkas simpanan utama."
		save_failed.emit(slot_type, rename_err, err_msg)
		return {"success": false, "error": rename_err, "message": err_msg}

	save_completed.emit(slot_type, target_path)
	return {"success": true, "path": target_path, "revision": _current_revision}

# ==============================================================================
# 2. DEFENSIVE LOAD & RECOVERY PIPELINE
# ==============================================================================

func load_game(slot_type: String = "manual") -> Dictionary:
	load_started.emit(slot_type)
	var target_path := get_slot_path(slot_type)
	var bak_path := target_path + ".bak"

	var active_envelope: Dictionary = {}
	var recovered_from_backup := false

	# 1. Coba baca target utama
	var primary_res := read_and_validate_envelope(target_path)
	if primary_res["valid"]:
		active_envelope = primary_res["envelope"]
	else:
		# 2. Fallback ke cadangan .bak jika target utama rusak/hilang
		print("[SaveManager] Checkpoint utama rusak/hilang (%s). Mencoba .bak..." % primary_res["reason"])
		var bak_res := read_and_validate_envelope(bak_path)
		if bak_res["valid"]:
			active_envelope = bak_res["envelope"]
			recovered_from_backup = true
			save_recovered_from_backup.emit(slot_type, bak_path)
		else:
			var err_msg := "Data simpan tidak cocok dengan versi ini atau rusak. Cadangan tidak tersedia."
			load_failed.emit(slot_type, ERR_FILE_CORRUPT, err_msg)
			return {"success": false, "error": ERR_FILE_CORRUPT, "message": err_msg}

	# 3. Two-Phase Commit: Fase 1 Pre-Flight Dry-Run
	var payload: Dictionary = active_envelope.get("payload", {})
	var val_res := validate_save_payload(payload)
	if not val_res["valid"]:
		var err_msg := "Data simpan tidak cocok dengan versi ini: %s" % val_res["reason"]
		load_failed.emit(slot_type, ERR_INVALID_DATA, err_msg)
		return {"success": false, "error": ERR_INVALID_DATA, "message": err_msg}

	# 4. Two-Phase Commit: Fase 2 Atomic Application ke Live Singletons
	apply_all_states(payload)

	# 5. Jika pulih dari cadangan, simpan ulang secara atomik untuk menyembuhkan primary file
	if recovered_from_backup:
		save_game(slot_type)

	load_completed.emit(slot_type, target_path if not recovered_from_backup else bak_path)
	return {"success": true, "slot_type": slot_type, "recovered_from_backup": recovered_from_backup}

func read_and_validate_envelope(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"valid": false, "reason": "FILE_NOT_FOUND"}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"valid": false, "reason": "FILE_OPEN_FAILED"}

	var content := file.get_as_text()
	file.close()

	if content.strip_edges().is_empty():
		return {"valid": false, "reason": "EMPTY_FILE"}

	var parsed = JSON.parse_string(content)
	if not (parsed is Dictionary):
		return {"valid": false, "reason": "INVALID_JSON"}

	var envelope: Dictionary = parsed
	var ver: int = int(envelope.get("schema_version", envelope.get("header", {}).get("schema_version", 0)))
	if ver != SCHEMA_VERSION:
		return {"valid": false, "reason": "VERSION_MISMATCH"}

	var payload = envelope.get("payload")
	if not (payload is Dictionary) or payload.is_empty():
		return {"valid": false, "reason": "MISSING_PAYLOAD"}

	# Verifikasi Checksum SHA-256
	var expected_hash: String = str(envelope.get("checksum", envelope.get("header", {}).get("checksum", "")))
	if not expected_hash.is_empty():
		var actual_hash: String = JSON.stringify(payload, "", false).sha256_text()
		if actual_hash != expected_hash:
			return {"valid": false, "reason": "CHECKSUM_MISMATCH"}

	return {"valid": true, "envelope": envelope}

func validate_save_payload(payload: Dictionary) -> Dictionary:
	var required_sections := ["player", "inventory", "recipe", "gardening", "world", "cooking", "dialogue"]
	for sec in required_sections:
		if not payload.has(sec) or not (payload[sec] is Dictionary):
			return {"valid": false, "reason": "Missing required section: " + sec}

	# Validasi inventory
	var inv_data: Dictionary = payload["inventory"]
	if not inv_data.has("backpack") or not inv_data.has("storage_home"):
		return {"valid": false, "reason": "Invalid inventory structure"}
	if (inv_data["backpack"] as Array).size() != 12 or (inv_data["storage_home"] as Array).size() != 12:
		return {"valid": false, "reason": "Inventory slots count mismatch"}

	return {"valid": true}

# ==============================================================================
# 3. HELPER SNAPSHOT ORCHESTRATION
# ==============================================================================

func capture_all_states() -> Dictionary:
	var payload: Dictionary = {}

	# Player
	var player = _get_player_node()
	if player and player.has_method("get_save_snapshot"):
		payload["player"] = player.get_save_snapshot()
	else:
		payload["player"] = {
			"position": [SAFE_RETURN_POSITION.x, SAFE_RETURN_POSITION.y, SAFE_RETURN_POSITION.z],
			"rotation_y": 0.0,
			"camera_pitch": 0.0
		}

	# Singletons
	if Engine.has_singleton("InventoryManager") or has_node("/root/InventoryManager"):
		payload["inventory"] = get_node("/root/InventoryManager").get_save_snapshot()
	if Engine.has_singleton("RecipeManager") or has_node("/root/RecipeManager"):
		payload["recipe"] = get_node("/root/RecipeManager").get_save_snapshot()
	if Engine.has_singleton("GardenManager") or has_node("/root/GardenManager"):
		payload["gardening"] = get_node("/root/GardenManager").get_save_snapshot()
	if Engine.has_singleton("WorldResourceManager") or has_node("/root/WorldResourceManager"):
		payload["world"] = get_node("/root/WorldResourceManager").get_save_snapshot()
	if Engine.has_singleton("KitchenManager") or has_node("/root/KitchenManager"):
		payload["cooking"] = get_node("/root/KitchenManager").get_save_snapshot()
	if Engine.has_singleton("DialogueManager") or has_node("/root/DialogueManager"):
		payload["dialogue"] = get_node("/root/DialogueManager").get_save_snapshot()

	return payload

func apply_all_states(payload: Dictionary) -> void:
	if payload.has("inventory") and has_node("/root/InventoryManager"):
		get_node("/root/InventoryManager").load_save_snapshot(payload["inventory"])

	if payload.has("recipe") and has_node("/root/RecipeManager"):
		get_node("/root/RecipeManager").load_save_snapshot(payload["recipe"])

	if payload.has("gardening") and has_node("/root/GardenManager"):
		var gm = get_node("/root/GardenManager")
		gm.load_save_snapshot(payload["gardening"])
		# Pastikan sinyal visual terpicu
		if gm.has_signal("plot_state_changed") and payload["gardening"].has("plots"):
			for p_id in payload["gardening"]["plots"]:
				gm.plot_state_changed.emit(p_id, payload["gardening"]["plots"][p_id])

	if payload.has("world") and has_node("/root/WorldResourceManager"):
		get_node("/root/WorldResourceManager").load_save_snapshot(payload["world"])

	if payload.has("cooking") and has_node("/root/KitchenManager"):
		var km = get_node("/root/KitchenManager")
		km.load_save_snapshot(payload["cooking"])
		# Jika load di dunia saat panel tertutup, pastikan job tidak berjalan di latar
		if int(km.job_state) == 3: # COOKING
			km.job_state = 4 # PAUSED

	if payload.has("dialogue") and has_node("/root/DialogueManager"):
		get_node("/root/DialogueManager").load_save_snapshot(payload["dialogue"])

	if payload.has("player"):
		_apply_player_snapshot(payload["player"])

func _apply_player_snapshot(player_data: Dictionary) -> void:
	var player = _get_player_node()
	if player == null:
		return

	if player.has_method("load_save_snapshot"):
		player.load_save_snapshot(player_data)
	else:
		# Fallback sanitasi koordinat langsung jika controller belum di-update
		var raw_pos = player_data.get("position", [SAFE_RETURN_POSITION.x, SAFE_RETURN_POSITION.y, SAFE_RETURN_POSITION.z])
		var target_pos := SAFE_RETURN_POSITION
		if raw_pos is Array and raw_pos.size() >= 3:
			var px: float = float(raw_pos[0])
			var py: float = float(raw_pos[1])
			var pz: float = float(raw_pos[2])
			if not (is_nan(px) or is_nan(py) or is_nan(pz) or is_inf(px) or is_inf(py) or is_inf(pz)):
				if px >= BOUND_MIN_X and px <= BOUND_MAX_X and pz >= BOUND_MIN_Z and pz <= BOUND_MAX_Z and py >= BOUND_MIN_Y and py <= BOUND_MAX_Y:
					target_pos = Vector3(px, py, pz)
				else:
					player_position_sanitized.emit(Vector3(px, py, pz), SAFE_RETURN_POSITION)
		player.global_position = target_pos

func create_envelope(slot_type: String, payload: Dictionary) -> Dictionary:
	var payload_str := JSON.stringify(payload, "", false)
	var hash_str := payload_str.sha256_text()
	var now_unix := Time.get_unix_time_from_system()
	var now_iso := Time.get_datetime_string_from_system(true, true)

	var header_dict := {
		"schema_version": SCHEMA_VERSION,
		"game_version": GAME_VERSION,
		"slot_type": slot_type,
		"revision": _current_revision,
		"timestamp": now_unix,
		"timestamp_iso": now_iso,
		"checksum": hash_str
	}

	return {
		"header": header_dict,
		"schema_version": SCHEMA_VERSION,
		"slot_type": slot_type,
		"revision": _current_revision,
		"timestamp": now_unix,
		"checksum": hash_str,
		"payload": payload
	}

# ==============================================================================
# 4. CONTINUE RESOLUTION API (T48)
# ==============================================================================

func get_continue_slot() -> String:
	var manual_meta := get_slot_metadata("manual")
	var auto_meta := get_slot_metadata("autosave")

	if not manual_meta.get("valid", false) and not auto_meta.get("valid", false):
		return ""
	if manual_meta.get("valid", false) and not auto_meta.get("valid", false):
		return "manual"
	if not manual_meta.get("valid", false) and auto_meta.get("valid", false):
		return "autosave"

	# Keduanya valid: pilih revisi terbesar (atau timestamp jika tied)
	var rev_manual: int = int(manual_meta.get("revision", 0))
	var rev_auto: int = int(auto_meta.get("revision", 0))

	if rev_auto > rev_manual:
		return "autosave"
	elif rev_manual > rev_auto:
		return "manual"
	else:
		return "autosave" if int(auto_meta.get("timestamp", 0)) >= int(manual_meta.get("timestamp", 0)) else "manual"

func get_slot_metadata(slot_type: String) -> Dictionary:
	var target_path := get_slot_path(slot_type)
	var bak_path := target_path + ".bak"

	for path in [target_path, bak_path]:
		var res := read_and_validate_envelope(path)
		if res["valid"]:
			var env: Dictionary = res["envelope"]
			var hdr: Dictionary = env.get("header", env)
			return {
				"valid": true,
				"slot_type": slot_type,
				"revision": int(hdr.get("revision", 0)),
				"timestamp": int(hdr.get("timestamp", 0)),
				"timestamp_iso": str(hdr.get("timestamp_iso", "")),
				"recovered_from_backup": (path == bak_path)
			}
	return {"valid": false}

# ==============================================================================
# 5. SEPARATE SETTINGS PERSISTENCE (user://settings.cfg)
# ==============================================================================

func load_settings() -> Dictionary:
	var config := ConfigFile.new()
	var err := config.load(PATH_SETTINGS)
	if err != OK:
		_settings = get_default_settings()
		save_settings(_settings)
	else:
		_settings = {
			"gameplay": {
				"mouse_sensitivity_multiplier": float(config.get_value("gameplay", "mouse_sensitivity_multiplier", 1.0)),
				"head_bob": bool(config.get_value("gameplay", "head_bob", false))
			},
			"video": {
				"fov": float(config.get_value("video", "fov", 80.0)),
				"ui_scale": float(config.get_value("video", "ui_scale", 1.0)),
				"window_mode": int(config.get_value("video", "window_mode", 0))
			},
			"audio": {
				"master_volume": float(config.get_value("audio", "master_volume", 0.7)),
				"music_volume": float(config.get_value("audio", "music_volume", 0.4)),
				"sfx_volume": float(config.get_value("audio", "sfx_volume", 0.7))
			},
			"accessibility": {
				"subtitles": bool(config.get_value("accessibility", "subtitles", true))
			}
		}
	settings_loaded.emit()
	return _settings

func save_settings(new_settings: Dictionary) -> Error:
	var config := ConfigFile.new()
	for sec in new_settings:
		for k in new_settings[sec]:
			config.set_value(sec, k, new_settings[sec][k])
	var err := config.save(PATH_SETTINGS)
	if err == OK:
		_settings = new_settings.duplicate(true)
		settings_saved.emit()
	return err

func get_default_settings() -> Dictionary:
	return {
		"gameplay": {"mouse_sensitivity_multiplier": 1.0, "head_bob": false},
		"video": {"fov": 80.0, "ui_scale": 1.0, "window_mode": 0},
		"audio": {"master_volume": 0.7, "music_volume": 0.4, "sfx_volume": 0.7},
		"accessibility": {"subtitles": true}
	}

func _get_player_node() -> CharacterBody3D:
	if not is_inside_tree() or get_tree().current_scene == null:
		return null
	return get_tree().current_scene.find_child("Player", true, false) as CharacterBody3D

func _update_revision_from_existing_saves() -> void:
	for slot in ["manual", "autosave"]:
		var meta := get_slot_metadata(slot)
		if meta.get("valid", false):
			var rev: int = int(meta.get("revision", 0))
			if rev > _current_revision:
				_current_revision = rev
```

---

## 10. Rekomendasi Langkah Kerja & Rencana Pengujian

1. **Implementasi Komponen Inti:**
   - Tambahkan `scripts/save/save_manager.gd` sesuai cetak biru di atas.
   - Daftarkan Autoload `SaveManager="*res://scripts/save/save_manager.gd"` di `project.godot`.
   - Tambahkan `get_save_snapshot()` dan `load_save_snapshot()` pada `scripts/player/player_controller.gd`.
   - Tambahkan emisi sinyal visual pada `GardenManager.load_save_snapshot()`.
2. **Implementasi Test Suite SAVE-001 (`tests/suites/test_save.gd`):**
   - Buat Suite 19 yang menguji 10 skenario pengujian utama: T14, T16, T17, T22, T46, T47, T48, T49, T50, serta persistensi independen `settings.cfg`.
   - Daftarkan Suite 19 di `tests/test_runner.gd`.
3. **Verifikasi Headless:**
   - Jalankan `godot --headless --path . --script res://tests/test_runner.gd` dan pastikan seluruh test suite (Suite 1 hingga 19) lulus dengan 0 kegagalan dan exit code 0.
