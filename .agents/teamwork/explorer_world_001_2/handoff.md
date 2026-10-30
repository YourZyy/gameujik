# Laporan Investigasi Explorer 2 — Stasiun Pengisian Air (water_home) & Mekanik Hold Action (WORLD-001)

## 1. Observation

### 1.1 Lokasi dan Setup Node `water_home` di Graybox Level
- **File Scene**: `scenes/world/level_graybox.tscn` (baris 637–661) dan `scripts/tools/build_level_graybox.gd` (baris 237–244, 369–392, 409–432).
- **Hirarki dan Transform**:
  ```
  LevelGraybox (Node3D)
  └── water_home (Node3D, position = Vector3(4, 0, 9))
      ├── WaterBasin (StaticBody3D, position = Vector3(0, 0.5, 0))
      │   ├── Collision (CollisionShape3D, BoxShape3D size = Vector3(0.8, 1.0, 0.8))
      │   └── Mesh (MeshInstance3D, BoxMesh size = Vector3(0.8, 1.0, 0.8), mat_water)
      └── Interactable (Area3D, position = Vector3(0, 0.5, 0), script = res://scripts/interaction/interactable.gd)
          └── Collision (CollisionShape3D, BoxShape3D size = Vector3(0.8, 1.0, 0.8))
  ```
- **Konfigurasi Fisika & Layer**:
  - `WaterBasin.collision_layer = 1` (Layer 1: environment), `collision_mask = 1`.
  - `Interactable.collision_layer = 4` (Layer 3: interactables, bitmask `1 << 2 = 4`), `collision_mask = 0`.
  - `Interactable.monitoring = false`, `Interactable.monitorable = true`.
  - Properti Interactable: `interaction_id = "landmark_water"`, `target_name = "Air"`, `prompt_action = "Ambil"`.
- **Deteksi Interaksi**:
  - `scripts/interaction/interaction_detector.gd` (baris 13–28): RayCast3D dengan `max_interaction_distance = 2.0`, `collision_mask = 5` (Layer 1 environment + Layer 3 interactables). Raycast dipasang pada kamera pemain (tinggi mata 1.6m). Jika terhalang dinding/rintangan Layer 1, interaksi terocclusion (T27).

### 1.2 Durasi Aksi Tahan & Pemetaan Input (Hold Action 2.0 Detik)
- **Dokumentasi Kontrak**:
  - `docs/CONTENT.md` § 5 (baris 87): `water_home | Pekarangan | Tersedia | Isi penyiram sampai kapasitas penuh`.
  - `docs/CONTENT.md` § 6 (baris 106–107): *"Progres aksi dunia yang dibatalkan sebelum selesai tidak mengonsumsi sumber daya dan direset... Tahan tombol bukan konsumsi per frame. Saat aksi selesai, tombol harus dilepas sebelum aksi berikutnya dapat dimulai."*
  - `docs/CONTENT.md` § 9 (baris 150–154):
    - Kapasitas penyiram: 10 unit abstrak.
    - Isi awal: 0 unit.
    - Isi ulang: *"Tahan E 2 detik di `water_home`, sampai 10; tidak menghabiskan stok dunia"*.
- **Implementasi PlayerController Eksisting**:
  - `scripts/player/player_controller.gd` (baris 168–172):
    ```gdscript
    var cur_t = interaction_detector.get_current_target()
    if cur_t != null and str(cur_t.get("interaction_id")) == "landmark_water":
        # water_home is a 2s hold action, do not trigger instant interact
        get_viewport().set_input_as_handled()
        return
    ```
  - `scripts/player/player_controller.gd` (baris 387–394):
    ```gdscript
    # 1. Refill watering can at water_home (2.0s hold E)
    if target_id == "landmark_water":
        if hold_controller.is_holding() and hold_controller.action_id == "refill":
            hold_controller.tick(delta, is_interact_pressed, target_id == "landmark_water")
        elif is_interact_just_pressed and not hold_controller.is_active():
            if gm != null and gm.can_refill_water()["success"]:
                hold_controller.start("refill", "water_home", 2.0, &"interact")
    ```
  - Input aksi adalah `&"interact"` (Key `E`). Tombol klik kiri (`action_tool_use` / LMB) digunakan untuk alat kebun pada `landmark_plot`, sedangkan landmark dunia menggunakan tombol interaksi `interact` (Key `E`).

### 1.3 State Machine & Invarian Pembatalan (HoldActionController)
- **File Pengendali**: `scripts/gardening/hold_action_controller.gd` (baris 7–87).
- **State Machine**:
  - `State.IDLE`: Tidak ada aksi berlangsung.
  - `State.HOLDING`: Tombol ditahan, timer bertambah per delta frame (`elapsed_time += delta`), memancarkan sinyal `hold_progress(action_id, progress, elapsed, duration)`.
  - `State.COMMITTED`: Dicapai HANYA saat `elapsed_time >= required_time` (2.0 detik penuh). Memancarkan `hold_completed(action_id)` lalu bertransisi ke `State.MUST_RELEASE`.
  - `State.MUST_RELEASE`: Pemain masih menahan tombol setelah commit; mencegah re-trigger loop berulang. State kembali ke `IDLE` hanya setelah tombol dilepas (`not is_button_pressed`).
- **Invarian Pembatalan**:
  - Pada baris 41–43: `if not is_button_pressed or not is_target_valid: cancel()`.
  - Saat dibatalkan (misal dilepas pada t = 1.5 detik):
    - `state = State.IDLE`
    - `elapsed_time = 0.0`
    - `hold_cancelled.emit(cancelled_action)`
    - `hold_completed` **TIDAK PERNAH** dipancarkan.
    - `_on_hold_action_completed("refill")` tidak dipanggil.
    - Air penyiram tidak bertambah sama sekali (0 charges added, zero side-effect).
  - Pemicu pembatalan tambahan yang sudah terpasang:
    1. Retargeting (reticle meleset dari `landmark_water`) -> `cancel()`.
    2. Jarak > 2.0 meter atau occlusion raycast -> `cancel()`.
    3. Pergantian konteks UI / Pause / Buka Tas / Buku -> `_update_hold_action` memeriksa `not im.is_world_context()` -> `cancel()`.
    4. Klik kanan mouse (`action_tool_cancel`) -> `cancel()`.

### 1.4 Kondisi Penuh (Kapasitas 10/10) & Umpan Balik UI
- **Pemeriksaan Kapasitas di GardenManager**:
  - `scripts/gardening/garden_manager.gd` (baris 357–370):
    ```gdscript
    func can_refill_water() -> Dictionary:
        if watering_can_water >= MAX_WATERING_CAN_CAPACITY:
            return {"success": false, "reason": "Kondisi cukup. Air sudah penuh."}
        return {"success": true, "reason": "Dapat diisi ulang."}

    func refill_water() -> bool:
        var check := can_refill_water()
        if not check["success"]:
            action_failed.emit(check["reason"])
            return false
        watering_can_water = MAX_WATERING_CAN_CAPACITY
        action_success.emit("refill", "Penyiram terisi penuh (10/10).")
        return true
    ```
- **Tampilan Prompt Kontekstual di HUD**:
  - `scripts/ui/hud.gd` (baris 355–360):
    ```gdscript
    elif i_id == "landmark_water" and gm != null:
        var cur_w: int = int(gm.get("watering_can_water"))
        if cur_w < 10:
            return "[Tahan E 2s] Isi Air Penyiram (%d/10)" % cur_w
        else:
            return "[E] Air Penyiram Penuh (10/10)"
    ```
- **Celah Umpan Balik Eksisting**:
  - Di `player_controller.gd` baris 392, jika `gm.can_refill_water()["success"]` bernilai `false` (saat air sudah 10/10), `hold_controller.start` tidak dipanggil dan tidak ada pesan feedback yang dipicu, sehingga penekanan tombol E saat penuh menjadi hening (silent reject).
  - `HUD` sudah memiliki handler `_on_garden_action_failed(reason: String)` yang memanggil `show_feedback(reason, 2.5)`.

### 1.5 Lokasi Penyimpanan Status Muatan Air
- **Penyimpanan Eksisting**:
  - `GardenManager.watering_can_water: int = 0` (default 0 saat permainan baru, clampi 0 s/d 10).
  - Setter memancarkan sinyal `water_level_changed(current_water, max_water)` dan `watering_can_updated(current_water, max_water)`.
  - Serialisasi di `GardenManager.get_save_snapshot()`:
    ```gdscript
    return {
        "version": 1,
        "active_tool": active_tool,
        "watering_can_water": watering_can_water,
        "plots": plots_data
    }
    ```
- **Kepatuhan Aturan Item (CONTENT.md § 2, § 3, § 12)**:
  - CONTENT.md § 2 (baris 26): *"Buku, catatan, kunci fasilitas, alat dan isi penyiram bukan item tas bertumpuk. Catatan tersimpan sebagai flag buku; empat alat tetap berada pada akses alat. Air dapur dan bahan bakar merupakan fasilitas stasiun P0, bukan slot inventaris atau angka ekonomi."*
  - CONTENT.md § 3 (baris 37): *"Alat: 4 akses tetap, tidak mengisi slot tas."*
  - CONTENT.md § 12 (baris 221): *"Player: Posisi aman, rotasi, alat aktif, isi penyiram."*
  - Item data `ItemsData` (`scripts/inventory/items_data.gd`) hanya berisi item inventaris (7 item P0 + 1 bahan air dapur `water_fresh`). Alat dan muatan gembor TIDAK disimpan di tas maupun item slot inventaris.

---

## 2. Logic Chain

1. **Dari Observasi 1.1**: Lokasi `water_home` di (4, 0, 9) telah sesuai dengan `docs/LEVEL_DESIGN.md` § 2 dan `scenes/world/level_graybox.tscn`. Struktur node memiliki StaticBody3D pada Layer 1 untuk batas fisik dan Area3D pada Layer 3 (bitmask 4) untuk target interaksi. Jangkauan interaksi kamera pemain dibatasi tepat 2.0 meter oleh `InteractionDetector`.
2. **Dari Observasi 1.2**: Durasi aksi tahan adalah 2.0 detik sesuai `CONTENT.md` § 9. Aksi tahan dipetakan pada input `interact` (Key `E`) karena `water_home` adalah landmark dunia pekarangan (bukan petak tanah). `player_controller.gd` mencegah trigger instan `interact` dan mendelegasikan ke `hold_controller.start("refill", "water_home", 2.0, &"interact")`.
3. **Dari Observasi 1.3**: State machine `HoldActionController` menjamin invarian nol-biaya (zero-cost cancellation): jika tombol dilepas sebelum 2.0 detik penuh (misal 1.5 detik), state segera direset ke `IDLE`, progress kembali ke 0.0, `hold_cancelled` dipancarkan, dan `hold_completed` tidak pernah dipancarkan. Fungsi mutasi `gm.refill_water()` tidak pernah dipanggil, sehingga 0 muatan air terisi dan tidak ada efek samping.
4. **Dari Observasi 1.4**: Saat muatan air mencapai 10/10, `GardenManager.can_refill_water()` mengembalikan `{"success": false, "reason": "Kondisi cukup. Air sudah penuh."}`. `HUD` telah menampilkan status jujur `[E] Air Penyiram Penuh (10/10)`. Namun, penekanan tombol E saat penuh perlu mengekspresikan penolakan aktif via `action_failed.emit(check["reason"])` agar `HUD.show_feedback()` memunculkan pesan pop-up 2.5 detik sesuai TEST_PLAN T33 dan AGENTS.md § 11.
5. **Dari Observasi 1.5**: Muatan air gembor secara desain bukan item inventaris (CONTENT.md § 2). Penyimpanan authoritative berada di `GardenManager.watering_can_water`. Untuk kompatibilitas terminology, penambahan alias property `watering_can_charges` pada `GardenManager` serta metode delegasi di `WorldResourceManager` menyatukan seluruh antarmuka tanpa merusak kode atau save snapshot yang sudah ada.

---

## 3. Caveats

1. **Input LMB vs E**: CONTENT.md § 6 menyebut aksi tahan alat kebun menggunakan klik kiri (LMB), sedangkan CONTENT.md § 9 secara spesifik menyatakan *"Tahan E 2 detik di water_home, sampai 10"*. Arsitektur saat ini telah mengikuti CONTENT.md § 9 (tombol `E`). Jika ada ekspektasi pemain menggunakan LMB saat memegang `tool_watering_can`, Worker dapat menambahkan opsi toleransi LMB, namun `E` tetap merupakan input utama yang didokumentasikan dan diuji.
2. **Ketiadaan Animasi 3D Karakter**: Sesuai PRD dan AGENTS.md, tidak ada model karakter 3D first-person atau animasi tangan gembor pada fase graybox P0. Seluruh umpan balik pengisian disampaikan secara visual melalui reticle, progress bar HUD (`HoldProgressBar`), perubahan teks prompt, dan label status alat (`ToolLabel`).
3. **WorldResourceManager Autoload Baru**: `scripts/world/world_resource_manager.gd` belum dibuat. Milestone WORLD-001 bertugas mengimplementasikan file ini untuk siklus kalender dan foraging. `WorldResourceManager` tidak boleh membuat variabel muatan air terpisah yang menduplikasi `GardenManager.watering_can_water`.

---

## 4. Conclusion & Rekomendasi Arsitektur untuk Worker

### 4.1 Ringkasan Keputusan Desain
1. **Source of Truth Muatan Air**: Tetap berada di `GardenManager` (`watering_can_water: int = 0`, max 10).
2. **Alias Terminology**: Tambahkan property alias `watering_can_charges` dan helper getter/setter pada `GardenManager`.
3. **Mekanik Hold Action**: Menggunakan `HoldActionController` dengan durasi 2.0 detik pada aksi `interact` (Key `E`).
4. **Invarian Pembatalan**: Pelepasan tombol < 2.0s mereset timer ke 0.0 tanpa penambahan air; re-trigger protection via `State.MUST_RELEASE`.
5. **Umpan Balik Kondisi Penuh**: Prompt menampilkan `[E] Air Penyiram Penuh (10/10)`; penekanan E saat penuh memicu sinyal `action_failed` ("Kondisi cukup. Air sudah penuh.") dengan notifikasi 2.5 detik pada HUD.

### 4.2 Blueprint Perubahan Kode untuk Worker

#### A. Modifikasi `scripts/gardening/garden_manager.gd`
Tambahkan alias property dan helper method agar fleksibel terhadap kontrak `charges` maupun `water`:
```gdscript
# Property alias untuk kompatibilitas muatan gembor
var watering_can_charges: int:
	get: return watering_can_water
	set(val): watering_can_water = val

func get_watering_can_charges() -> int:
	return watering_can_water

func get_max_watering_can_charges() -> int:
	return MAX_WATERING_CAN_CAPACITY
```

#### B. Modifikasi `scripts/player/player_controller.gd`
Perbaiki penanganan penolakan jujur saat air penuh pada `_update_hold_action()`:
```gdscript
	# 1. Refill watering can at water_home (2.0s hold E)
	if target_id == "landmark_water":
		if hold_controller.is_holding() and hold_controller.action_id == "refill":
			hold_controller.tick(delta, is_interact_pressed, target_id == "landmark_water")
		elif is_interact_just_pressed and not hold_controller.is_active():
			if gm != null:
				var check: Dictionary = gm.can_refill_water()
				if check.get("success", false):
					hold_controller.start("refill", "water_home", 2.0, &"interact")
				else:
					gm.action_failed.emit(check.get("reason", "Kondisi cukup. Air sudah penuh."))
```

#### C. Desain `scripts/world/world_resource_manager.gd` (File Baru)
Buat modul pengelola sumber daya dunia dan kalender yang mendelegasikan pengisian air ke `GardenManager`:
```gdscript
class_name WorldResourceManager
extends Node

## Pengelola Sumber Daya Dunia, Kalender Hari (720s), dan Titik Temuan untuk Buku Resep 2045
## Memenuhi PRD FR09/FR10, CONTENT.md § 5/9, TASKS.md WORLD-001, dan TEST_PLAN T09, T37, T38, T39

signal day_advanced(day_index: int)
signal resource_foraged(resource_id: String, item_id: String, count: int)
signal bed_rest_performed(day_index: int)

const DAY_DURATION_SECONDS: float = 720.0
const WATER_STATION_LANDMARK: String = "water_home"

func can_refill_water_station() -> Dictionary:
	var gm = _get_garden_manager()
	if gm != null and gm.has_method("can_refill_water"):
		return gm.can_refill_water()
	return {"success": true, "reason": "Dapat diisi ulang."}

func refill_watering_can() -> bool:
	var gm = _get_garden_manager()
	if gm != null and gm.has_method("refill_water"):
		return gm.refill_water()
	return false
```

#### D. Desain Test Suite Baru: `tests/suites/test_world.gd`
Tambahkan pengujian otomatis untuk water refill & invariants:
1. `test_water_station_refill_hold_commit()`: Verifikasi 2.0 detik hold commit mengisi 10 unit air ke gembor.
2. `test_water_station_refill_cancellation_invariant()`: Verifikasi pelepasan tombol pada 1.5s mengembalikan state ke IDLE, 0 unit air terisi.
3. `test_water_station_full_capacity_rejection()`: Verifikasi penolakan saat muatan 10/10 memunculkan alasan jujur *"Kondisi cukup. Air sudah penuh."* tanpa memutasi data.
4. `test_water_station_infinite_availability()`: Verifikasi pergantian hari / istirahat ranjang tidak merusak ketersediaan `water_home`.

---

## 5. Verification Method

### 5.1 Perintah Pengujian Mandiri Headless
Jalankan suite pengujian menggunakan binary Godot stabil:
```powershell
# 1. Jalankan runner utama
& "C:\Users\HP\.local\bin\godot.exe" --headless --path "c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia" -s res://tests/test_runner.gd

# 2. Jalankan adversarial harness hold action
& "C:\Users\HP\.local\bin\godot.exe" --headless --path "c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia" -s res://tests/stress_hold_actions.gd

# 3. Jalankan suite baru WORLD-001 (setelah dibuat oleh Worker)
& "C:\Users\HP\.local\bin\godot.exe" --headless --path "c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia" -s res://tests/suites/test_world.gd
```

### 5.2 Kasus Uji Verifikasi Spesifik (Acceptance Criteria)
1. **Kasus Uji Kapasitas Awal & Pengisian Penuh**:
   - Kondisi awal: `GardenManager.watering_can_water == 0`.
   - Aksi: Hold E pada `water_home` selama 2.0 detik.
   - Hasil: `GardenManager.watering_can_water == 10`, `hold_progress` mencapai 1.0, prompt berubah menjadi `[E] Air Penyiram Penuh (10/10)`.
2. **Kasus Uji Invarian Pembatalan 1.5 Detik**:
   - Kondisi awal: `GardenManager.watering_can_water == 0`.
   - Aksi: Hold E pada `water_home` selama 1.5 detik lalu lepas tombol.
   - Hasil: `hold_controller.is_active() == false`, `hold_controller.get_progress() == 0.0`, `GardenManager.watering_can_water == 0` (0 charge bertambah).
3. **Kasus Uji Penolakan Saat Penuh (10/10)**:
   - Kondisi awal: `GardenManager.watering_can_water == 10`.
   - Aksi: Tekan E pada `water_home`.
   - Hasil: `can_refill_water()["success"] == false`, `reason == "Kondisi cukup. Air sudah penuh."`, `action_failed` dipancarkan, `watering_can_water` tetap 10.
4. **Kasus Uji Retargeting & Pembatalan Occlusion**:
   - Kondisi: Sedang menahan E pada `water_home`, arah pandang diputar menjauh atau pemain melangkah mundur > 2.0m.
   - Hasil: Hold langsung batal otomatis (`hold_cancelled`), progress bar hilang, muatan air tidak berubah.

### 5.3 Kondisi Kegagalan (Invalidation Conditions)
Laporan ini dinyatakan tidak valid (invalidated) jika:
- Ditemukan bahwa muatan air disimpan di slot inventaris `backpack` atau `storage_home` alih-alih `GardenManager`.
- Pembatalan pada detik ke-1.5 menambah muatan air parsial (> 0 unit).
- Penekanan tombol saat kapasitas 10/10 menghasilkan pengisian melebihi 10 unit atau tidak memberikan alasan penolakan.
