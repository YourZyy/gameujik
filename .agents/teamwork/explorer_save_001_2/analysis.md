# Laporan Analisis Kontrak Serialisasi State Dinamis (SAVE-001)

**Penulis:** `explorer_save_001_2` (Dynamic State Serialization Explorer)  
**Milestone:** `SAVE-001` (Sistem Simpan/Muat dan Pemulihan Game State Terpadu)  
**Proyek:** *Buku Resep 2045* (Godot 4.7.2 / GDScript / GL Compatibility 3D First Person)  
**Tanggal:** 29 Oktober 2026  
**Status:** Read-Only Investigation & Architectural Contract Review  
**Dokumen Acuan:** `CONTENT.md` (§ 12), `PROTOTYPE.md` (§ 7), `TEST_PLAN.md` (T14, T16, T17, T22, T46–T50), `AGENTS.md` (§ 4, § 8)

---

## 1. Ringkasan Eksekutif

Pemeriksaan komprehensif terhadap seluruh modul gameplay dan manajer (`scripts/core/`, `scripts/player/`, `scripts/inventory/`, `scripts/recipe/`, `scripts/gardening/`, `scripts/world/`, `scripts/cooking/`, `scripts/social/`) mengonfirmasi bahwa arsitektur persistensi pada proyek *Buku Resep 2045* telah dirancang modular dengan sebagian besar manajer Autoload telah mengimplementasikan pasangan metode `get_save_snapshot() -> Dictionary` dan `load_save_snapshot(data: Dictionary) -> bool`.

Namun, untuk mencapai kepatuhan penuh terhadap kriteria penerimaan **SAVE-001** (khususnya kasus uji **T14, T16, T17, T22, T46, T47, T48, T49, T50**), terdapat area kritis yang memerlukan standarisasi kontrak dan mekanisme pelindung sebelum implementor menulis `scripts/save/save_manager.gd`:
1. **PlayerController:** Belum memiliki `get_save_snapshot()` dan `load_save_snapshot()`. Kontrak posisi, rotasi yaw, sudut pitch kamera, serta validasi koordinat aman (T22: pencegahan `NaN`, `Inf`, dan out-of-bounds dengan fallback aman ke `safe_return_home` `(0, 0, 8)`) harus diformalkan.
2. **Pre-Flight Validation Sebelum World Swap (T16, T17, T47):** Kegagalan atau kerusakan pada salah satu bagian snapshot tidak boleh menyebabkan mutasi sebagian ("half-loaded world"). Diperlukan protokol *Two-Phase Commit*: validasi skema dan seluruh ID data secara pasif terlebih dahulu, baru menerapkan mutasi ke live singletons jika 100% valid.
3. **Sinkronisasi Sinyal Visual Pasca-Muat:** Restorasi state pada `GardenManager` dan `WorldResourceManager` harus memancarkan sinyal pembaruan tampilan (`plot_state_changed`, `foraging_state_changed`, `water_level_changed`) agar representasi grafis di dunia 3D langsung cocok dengan snapshot tanpa memerlukan interaksi baru dari pemain.
4. **Pencegahan Background Cooking Pasca-Muat:** Jika snapshot disimpan saat job memasak berada dalam status aktif (`COOKING`), saat dimuat ke dunia (di mana panel dapur tertutup), status harus dipulihkan sebagai `PAUSED` sesuai kontrak `PROTOTYPE.md § 5` & `§ 7`.

---

## 2. Inventaris Kontrak Manajer & Entitas

Tabel ringkasan status implementasi saat ini di seluruh sistem:

| Sub-Sistem / Manajer | Status Saat Ini | Method Serialisasi | Method Deserialisasi | Validasi & Ketahanan |
|---|---|---|---|---|
| **PlayerController** | Belum Ada | Belum Ada | Belum Ada | Memerlukan implementasi kontrak posisi/rotasi + T22 boundary fallback |
| **InventoryManager** | Lengkap | `get_save_snapshot()` | `load_save_snapshot()` | Plain data 12 slot, penanganan alias starter, memerlukan filter ID item asing (T47) |
| **RecipeManager** | Lengkap | `get_save_snapshot()` | `load_save_snapshot()` | Versi 1, pelacakan resep, times_cooked, status catatan, emisi sinyal lengkap |
| **GardenManager** | Lengkap | `get_save_snapshot()` | `load_save_snapshot()` | Versi 1, petak 2x2m, 4 spot tanam, 4-tahap bayam, perlu emisi `plot_state_changed` |
| **WorldResourceManager** | Lengkap | `get_save_snapshot()` | `load_save_snapshot()` | Versi 1, kalender 720s, foraging 1x/hari, meal_used, cadangan darurat dinamis |
| **KitchenManager** | Lengkap | `get_save_snapshot()` | `load_save_snapshot()` | Versi 1, job memasak, reservasi bahan, asal wadah (origin), output_slot, 3-tier refund |
| **DialogueManager** | Lengkap | `get_save_snapshot()` | `load_save_snapshot()` | Versi 1, sanitasi tipe boolean via `_parse_bool_safe`, status intro/berbagi, meal_used |

---

## 3. Analisis Mendalam Per Sub-Sistem

### 3.1. Player Subsystem (`scripts/player/player_controller.gd`)

#### 3.1.1. Observasi Kondisi Kode
- File `scripts/player/player_controller.gd` mengelola pergerakan first-person CharacterBody3D, kamera pitch, dan interaksi.
- Belum memiliki fungsi `get_save_snapshot()` maupun `load_save_snapshot()`.
- Properti dinamis esensial:
  - `global_position: Vector3` (posisi kaki pemain di dunia 3D).
  - `rotation.y: float` (rotasi badan horizontal / yaw dalam radian).
  - `camera_pitch: float` (rotasi vertikal kepala/kamera dalam radian, dibatasi $-85^\circ$ hingga $+85^\circ$).
- Batas dunia dan titik pemulihan pada `scripts/world/level_graybox.gd` dan `PlayerConfig`:
  - `FALL_RECOVERY_Y_THRESHOLD = -5.0`
  - Batas luar envelope level graybox: $X \in [-42.0, 42.0]$, $Z \in [-37.0, 47.0]$.
  - Titik spawn awal: `spawn_home` pada `Vector3(0.0, 0.0, 1.0)`.
  - Titik aman pemulihan: `safe_return_home` pada `Vector3(0.0, 0.0, 8.0)`.

#### 3.1.2. Spesifikasi Kontrak Serialisasi
```gdscript
func get_save_snapshot() -> Dictionary:
    var pos := global_position if is_inside_tree() else position
    return {
        "position": [pos.x, pos.y, pos.z],
        "rotation_y": rotation.y,
        "camera_pitch": camera_pitch
    }
```

#### 3.1.3. Spesifikasi Kontrak Pemulihan & Validasi Koordinat Aman (T22)
Sesuai `PROTOTYPE.md § 7` dan `TEST_PLAN.md T22`: "Posisi yang tidak aman dipulihkan ke titik spawn aman LEVEL_DESIGN, tanpa mengubah item/progres."
Aturan validasi matematis:
1. Koordinat harus berupa angka (`float` atau `int`).
2. Tidak boleh mengandung `NaN` (`@GlobalScope.is_nan()`) atau `Inf` (`@GlobalScope.is_inf()`).
3. Berada di dalam batas aman:
   - $X \in [-42.0, 42.0]$
   - $Z \in [-37.0, 47.0]$
   - $Y \in [-5.0, 50.0]$
4. Jika salah satu kondisi di atas dilanggar:
   - Posisi dialihkan secara otomatis ke `default_safe_return_position` (`Vector3(0.0, 0.0, 8.0)`).
   - Rotasi Y dialihkan ke `0.0`, camera pitch dialihkan ke `0.0`.
   - Proses muat **TIDAK GAGAL** dan inventaris/progres pemain **TIDAK RUSAK**.
   - Sistem mengeluarkan log peringatan: `"[SaveManager] Koordinat pemain tidak valid/berbahaya (%s). Dialihkan ke titik aman (0, 0, 8)."`

```gdscript
func load_save_snapshot(data: Dictionary) -> bool:
    if not (data is Dictionary) or data.is_empty():
        return false

    var raw_pos = data.get("position", [0.0, 0.0, 8.0])
    var target_pos := default_safe_return_position
    var is_coord_valid := false

    if raw_pos is Array and raw_pos.size() >= 3:
        var px: float = float(raw_pos[0])
        var py: float = float(raw_pos[1])
        var pz: float = float(raw_pos[2])
        if not (is_nan(px) or is_nan(py) or is_nan(pz) or is_inf(px) or is_inf(py) or is_inf(pz)):
            if px >= -42.0 and px <= 42.0 and pz >= -37.0 and pz <= 47.0 and py >= -5.0 and py <= 50.0:
                target_pos = Vector3(px, py, pz)
                is_coord_valid = true

    if not is_coord_valid:
        print("[PlayerController] Koordinat pemain out-of-bounds/NaN/Inf. Fallback ke safe return: ", default_safe_return_position)
        target_pos = default_safe_return_position

    var rot_y: float = float(data.get("rotation_y", 0.0))
    if is_nan(rot_y) or is_inf(rot_y):
        rot_y = 0.0

    var pitch: float = float(data.get("camera_pitch", 0.0))
    if is_nan(pitch) or is_inf(pitch):
        pitch = 0.0

    teleport_to(target_pos, rot_y)
    camera_pitch = clampf(pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
    if head:
        head.rotation.x = camera_pitch

    return true
```

---

### 3.2. InventoryManager Subsystem (`scripts/inventory/inventory_manager.gd`)

#### 3.2.1. Observasi Kondisi Kode
- Mengelola tiga kontainer bertipe `InventoryContainer`:
  1. `backpack` (12 slot)
  2. `storage_home` (12 slot)
  3. `kitchen_refund` (12 slot)
- Mengelola flag wadah awal: `starter_claimed` (dengan sinyal `starter_claimed_changed`).
- Mengimplementasikan `to_array()` pada `InventoryContainer` yang mengonversi setiap slot ke bentuk Dictionary: `{"item_id": String, "id": String, "count": int}`.

#### 3.2.2. Struktur Snapshot
```json
{
  "backpack": [
    {"item_id": "seed_bayam", "id": "seed_bayam", "count": 4},
    {"item_id": "soil_compost", "id": "soil_compost", "count": 1},
    {"item_id": "", "id": "", "count": 0}
  ],
  "storage_home": [
    {"item_id": "", "id": "", "count": 0}
  ],
  "kitchen_refund": [
    {"item_id": "", "id": "", "count": 0}
  ],
  "starter_claimed": true,
  "starter_collected": true
}
```

#### 3.2.3. Analisis Invarian & Validasi Pra-Swap (T47)
- **Kapasitas Tetap:** Slot wajib berjumlah tepat 12 untuk masing-masing kontainer.
- **Batas Stack (Maksimum 20):** `count` harus bernilai antara 0 hingga 20. Jika `count <= 0`, `item_id` wajib dibersihkan menjadi `""`.
- **Integritas Kamus Item (T47):** Jika berkas simpanan memuat `item_id` yang tidak terdaftar dalam `ItemRegistry` (misalnya modifikasi ilegal atau inkonsistensi versi), validasi pra-swap harus menolak snapshot tersebut sebelum dunia dimutasi.
- **Dukungan Tipe Float JSON:** Godot mendeserialisasi angka JSON sebagai `float`. `from_dict` pada `InventorySlot` menggunakan `int(d.get("count", 0))` sehingga konversi float $\to$ int berjalan aman.

---

### 3.3. RecipeManager Subsystem (`scripts/recipe/recipe_manager.gd`)

#### 3.3.1. Observasi Kondisi Kode
- Mengelola registri resep (`_recipes`) dan catatan lingkungan (`_notes`).
- Autoload melacak `tracked_recipe_id` dan `cooking_state`.
- Method `get_save_snapshot()` menghasilkan snapshot terstruktur:
  ```json
  {
    "version": 1,
    "tracked_recipe_id": "recipe_sayur_bening_01",
    "cooking_state": "idle",
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
- Method `load_save_snapshot()` memulihkan data, mempertahankan catatan default (`default_unlocked`), dan memancarkan sinyal `recipe_updated`, `recipe_tracked`, atau `recipe_untracked`.

#### 3.3.2. Evaluasi Invarian
- `times_cooked` harus integer non-negatif ($\ge 0$).
- Di P0, resep `recipe_sayur_bening_01` selalu berstatus ditemukan sejak game baru.
- Tidak ada kebocoran status memasak saat load; sinkronisasi status ke UI berjalan lewat emisi sinyal.

---

### 3.4. GardenManager Subsystem (`scripts/gardening/garden_manager.gd`)

#### 3.4.1. Observasi Kondisi Kode
- Mengelola data petak `plot_home_01`, 4 kuadran (`slot_01` hingga `slot_04`), kelembapan ($0..100$), nutrisi ($0..100$), alat aktif (`active_tool`), dan kapasitas air penyiram (`watering_can_water`, maks 10).
- Tiap slot memiliki data tanaman (`crop_data`):
  - `crop_id`: `"crop_bayam"`
  - `growth_time`: float ($0.0 \le t \le 180.0$)
  - `growth_stage`: int ($0, 1, 2, 3$)
  - `is_ready_to_harvest`: bool
  - `is_stalled`: bool
  - `stall_reason`: String

#### 3.4.2. Struktur Snapshot
```json
{
  "version": 1,
  "active_tool": "tool_watering_can",
  "watering_can_water": 8,
  "plots": {
    "plot_home_01": {
      "id": "plot_home_01",
      "is_hoed": true,
      "has_compost": true,
      "nutrients": 95.0,
      "moisture": 72.4,
      "spots": {
        "slot_01": {
          "spot_id": "slot_01",
          "spot_index": 0,
          "is_occupied": true,
          "crop_data": {
            "crop_id": "crop_bayam",
            "growth_time": 95.2,
            "growth_stage": 2,
            "is_ready_to_harvest": false,
            "is_stalled": false,
            "stall_reason": ""
          }
        },
        "slot_02": {"spot_id": "slot_02", "spot_index": 1, "is_occupied": false, "crop_data": null},
        "slot_03": {"spot_id": "slot_03", "spot_index": 2, "is_occupied": false, "crop_data": null},
        "slot_04": {"spot_id": "slot_04", "spot_index": 3, "is_occupied": false, "crop_data": null}
      }
    }
  }
}
```

#### 3.4.3. Rekomendasi Peningkatan Pasca-Muat
Pada implementasi saat ini di baris 650:
```gdscript
active_tool = str(data.get("active_tool", TOOL_NONE))
watering_can_water = int(data.get("watering_can_water", 0))
_plots = data["plots"].duplicate(true)
active_tool_changed.emit(active_tool)
```
Terdapat temuan observasi: `plot_state_changed` dan `water_level_changed` belum dipancarkan saat pemulihan snapshot selesai. Jika adegan 3D sedang aktif, material tanah (gembur/pembenah/basah) dan visibilitas mesh tanaman di `Main._on_garden_plot_state_changed` perlu diperbarui.
**Rekomendasi Kontrak:** Tambahkan emisi sinyal berikut di akhir `load_save_snapshot`:
```gdscript
water_level_changed.emit(watering_can_water, MAX_WATERING_CAN_CAPACITY)
for p_id in _plots:
    plot_state_changed.emit(p_id, _plots[p_id])
```

---

### 3.5. WorldResourceManager Subsystem (`scripts/world/world_resource_manager.gd`)

#### 3.5.1. Observasi Kondisi Kode
- Mengelola kalender hari (`current_day`, durasi 720s/hari), waktu aktif (`day_active_time`), status pemakaian masakan (`meal_used`), dan status foraging harian (`last_harvested_day`).
- Struktur snapshot:
  ```json
  {
    "version": 1,
    "current_day": 2,
    "day_active_time": 145.5,
    "meal_used": false,
    "last_harvested_day": {
      "resource_jagung_01": 1,
      "resource_temu_kunci_01": 2
    }
  }
  ```
- Method `load_save_snapshot()`:
  - Memeriksa `version == 1`.
  - Memulihkan hari, waktu aktif, `meal_used`, dan pemetaan `last_harvested_day`.
  - Memancarkan `day_advanced(current_day)`.
  - Memancarkan `foraging_state_changed(node_id, is_available)` untuk seluruh node jagung dan temu kunci sehingga prompt interaksi di dunia langsung menyesuaikan.

#### 3.5.2. Evaluasi Invarian
- **Hukum Waktu Non-Realtime:** Simulasi hari tidak menggunakan jam komputer asli saat aplikasi ditutup (`PROTOTYPE.md § 7`). Waktu pulih tepat di `day_active_time`.
- **Cadangan Darurat (`reserve_home`):** Dievaluasi secara dinamis murni dari status stok inventaris dan petak, sehingga tidak membutuhkan state terpisah.

---

### 3.6. KitchenManager Subsystem (`scripts/cooking/kitchen_manager.gd`)

#### 3.6.1. Observasi Kondisi Kode
- Mengelola state mesin job memasak: `IDLE (0)`, `RESERVED_PREPARING (1)`, `READY_TO_HEAT (2)`, `COOKING (3)`, `PAUSED (4)`, `OUTPUT_READY (5)`, `REFUND_PENDING (6)`.
- Mengelola reservasi bahan atomik: bahan ditarik secara fisik dari tas dan peti, lalu disimpan dalam `reserved_ingredients` dengan riwayat kontainer asal di `origin_manifest`.
- Mengelola kontrol panas (`current_heat_level`: Low 0.5x, Medium 1.0x, High 0.0x stall warning), waktu persiapan (4.0s), dan waktu masak (30.0s).
- Mengelola slot hasil (`dish_output_slot`) dan sistem pengembalian 3-tingkat (`kitchen_refund`).

#### 3.6.2. Struktur Snapshot
```json
{
  "version": 1,
  "job_state": 4,
  "active_job_id": "job_sayur_bening_01_1",
  "active_recipe_id": "recipe_sayur_bening_01",
  "prep_progress": 4.0,
  "prep_duration": 4.0,
  "cook_progress": 15.0,
  "cook_duration": 30.0,
  "heat_level": 1,
  "current_heat": "medium",
  "meal_used": false,
  "p0_completed": false,
  "reserved_ingredients": [
    {"item_id": "ingredient_bayam", "count": 3},
    {"item_id": "ingredient_jagung", "count": 1},
    {"item_id": "ingredient_temu_kunci", "count": 1}
  ],
  "origin_manifest": [
    {"container": "backpack", "source": "backpack", "item_id": "ingredient_bayam", "count": 3},
    {"container": "backpack", "source": "backpack", "item_id": "ingredient_jagung", "count": 1},
    {"container": "storage", "source": "storage", "item_id": "ingredient_temu_kunci", "count": 1}
  ],
  "dish_output_slot": {},
  "current_job": {
    "job_id": "job_sayur_bening_01_1",
    "recipe_id": "recipe_sayur_bening_01",
    "prep_progress": 4.0,
    "cook_progress": 15.0
  }
}
```

#### 3.6.3. Analisis Invarian Kritis
1. **Hukum Kekekalan Materi (Matter Conservation):**
   - Saat bahan direservasi, bahan tersebut keluar dari inventaris biasa. Snapshot menyimpan `reserved_ingredients` dan `origin_manifest`.
   - Jika pemain memuat save lalu membatalkan persiapan, bahan kembali ke kontainer asal (tas/peti) atau dialihkan ke `kitchen_refund` tanpa kehilangan atau duplikasi unit (Uji T13, T40).
2. **Idempotensi Slot Hasil (T50):**
   - Jika job berada pada `OUTPUT_READY`, `dish_output_slot` terisi 1 hidangan dan `current_job["output_committed"] = true`.
   - Memuat save berulang kali tidak pernah menggandakan masakan atau mencatat `times_cooked` ganda.
3. **Pemberhentian Memasak di Latar Belakang (PROTOTYPE.md § 5):**
   - Saat save dimuat, pemain berada di dunia 3D (panel dapur tertutup). Jika state tersimpan adalah `COOKING`, deserialisasi harus memulihkannya sebagai `PAUSED` agar progress tidak berjalan diam-diam di latar belakang.

---

### 3.7. DialogueManager Subsystem (`scripts/social/dialogue_manager.gd`)

#### 3.7.1. Observasi Kondisi Kode
- Mengelola alur percakapan warga tetangga (`npc_neighbor_01`), pemenuhan penutup pengalaman P0, konsumsi porsi hidangan lewat opsi berbagi, dan flag naratif.
- Mengimplementasikan sanitasi boolean canggih:
  ```gdscript
  static func _parse_bool_safe(val: Variant, default_val: bool = false) -> bool
  ```
  yang mampu menangani input string `"true"`, `"1"`, `"yes"`, `"on"`, integer `0`/`1`, maupun boolean murni tanpa melempar error.
- Snapshot mencakup: `has_spoken_intro`, `has_shared_meal`, `meal_used`, `p0_completed`, dan `dialogue_flags`.
- Telah teruji 100% pada suite adversarial `tests/suites/test_adversarial_challenger_snapshot_signals.gd`.

---

## 4. Mekanisme Validasi Kelengkapan Snapshot Sebelum Swap Dunia (T16, T17, T47)

### 4.1. Masalah "Half-Loaded World"
Dalam engine Godot, memuat state game langsung ke instance singleton secara berurutan tanpa validasi awal membawa risiko fatal:
- Jika `InventoryManager` sudah berhasil memuat data baru, namun saat membaca data `KitchenManager` terjadi korupsi (misalnya JSON parsing error atau data field hilang), proses muat terhenti di tengah jalan.
- Akibatnya, pemain berada dalam kondisi *state inkonsisten*: tas telah berubah, namun petak kebun dan stasiun dapur masih memakai memori lama.
- Hal ini melanggar secara eksplisit aturan `PROTOTYPE.md § 7`:  
  > *"Load: validasi envelope dan seluruh referensi dahulu $\to$ bangun keadaan sementara $\to$ baru ganti dunia. Jika tidak cocok/rusak, tampilkan checkpoint valid lain. Jangan memuat setengah data lalu mengisi sisanya dengan game baru tanpa penjelasan."*

### 4.2. Protokol Dua Fase (Two-Phase Commit Protocol)

Untuk menjamin kepatuhan penuh terhadap **T16, T17, dan T47**, arsitektur `SaveManager` harus mengadopsi protokol dua fase:

```
[ Berkas Simpanan .json ]
         │
         ▼
[ Fase 1: Validasi Pasif Pra-Swap (Dry-Run Inspection) ]
   ├── Validasi Envelope (version == 1, slot_type, timestamp, checksum)
   ├── Validasi Kelengkapan Section (player, inventory, recipe, gardening, world, cooking, dialogue)
   ├── Validasi Domain Data & Tipe (12 slot inv, ID item terdaftar, range koordinat, batas stack)
   └── Validasi Skema & Versi Kompatibel (T47)
         │
         ├───[ Validasi GAGAL ]───► [ TOLAK LOAD ]
         │                            ├── Dunia yang sedang berjalan 100% UTUH
         │                            ├── Tampilkan pesan jujur UI: "Data simpan tidak cocok/rusak"
         │                            └── Tawarkan checkpoint cadangan .bak yang valid (T17)
         │
         ▼ [ Validasi 100% SUKSES ]
[ Fase 2: Eksekusi Swap State Dunia (Atomic Application) ]
   ├── 1. InventoryManager.load_save_snapshot(payload["inventory"])
   ├── 2. RecipeManager.load_save_snapshot(payload["recipe"])
   ├── 3. GardenManager.load_save_snapshot(payload["gardening"])
   ├── 4. WorldResourceManager.load_save_snapshot(payload["world"])
   ├── 5. KitchenManager.load_save_snapshot(payload["cooking"])
   ├── 6. DialogueManager.load_save_snapshot(payload["dialogue"])
   └── 7. PlayerController.load_save_snapshot(payload["player"]) (dengan T22 boundary fallback)
         │
         ▼
[ Pemancaran Sinyal Pembaruan Visual & UI ]
```

### 4.3. Checklist Validasi Pra-Swap

Fungsi validator `SaveManager.validate_save_payload(envelope: Dictionary) -> Dictionary` harus memverifikasi:

1. **Header Envelope:**
   - Memiliki key: `"version"`, `"timestamp"`, `"slot_type"`, `"payload"`.
   - `int(envelope["version"]) == 1`.
2. **Kelengkapan Section Domain:**
   - `payload.has("player")`
   - `payload.has("inventory")`
   - `payload.has("recipe")`
   - `payload.has("gardening")`
   - `payload.has("world")`
   - `payload.has("cooking")`
   - `payload.has("dialogue")`
3. **Pemeriksaan Isi Section:**
   - `inventory`: Memiliki `backpack` dan `storage_home` berupa Array dengan panjang tepat 12. Semua `item_id` harus valid di `ItemRegistry.ITEMS` (atau string kosong).
   - `recipe`: Memiliki `recipes` (Dictionary) yang mencakup `recipe_sayur_bening_01`.
   - `gardening`: Memiliki `plots` (Dictionary) yang mencakup `plot_home_01` dengan 4 spot.
   - `world`: `current_day` integer $\ge 1$.
   - `cooking`: `job_state` integer antara 0 s/d 6.
   - `player`: `position` Array 3 elemen numeric (tidak `NaN`/`Inf`).

---

## 5. Ringkasan Rekomendasi untuk Tim Implementasi

1. **Tambahkan API Snapshot pada `PlayerController`:**
   Terapkan `get_save_snapshot()` dan `load_save_snapshot()` dengan logika validasi out-of-bounds/NaN/Inf fallback ke `Vector3(0, 0, 8)`.
2. **Terapkan `validate_save_payload()` pada `SaveManager`:**
   Jadikan fungsi validasi ini sebagai gerbang wajib sebelum fungsi apa pun menyentuh singleton aktif saat proses `load_game()`.
3. **Tambahkan Emisi Sinyal Visual pada `GardenManager.load_save_snapshot()`:**
   Pancarkan `plot_state_changed` dan `water_level_changed` agar perubahan tekstur tanah dan tanaman langsung tampak setelah proses muat.
4. **Patuhi Pemisahan `settings.cfg`:**
   Pastikan FOV, sensitivitas mouse, volume audio, dan preferensi tidak dimasukkan ke dalam payload save game, melainkan tersimpan di `user://settings.cfg` agar pengaturan pemain tidak tertimpa saat memuat save lama (T52).

---
*Laporan ini disusun sebagai referensi arsitektur terpadu bagi `implementer_save_001` dan perancang test suite `explorer_save_001_3`.*
