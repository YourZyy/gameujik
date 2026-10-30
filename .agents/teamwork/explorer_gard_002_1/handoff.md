# Laporan Handoff: Crop Growth & Stage State Machine Architecture (GARD-002)

Dokumen investigasi dan cetak biru arsitektur untuk milestone **GARD-002** (Simulasi Pertumbuhan Tanaman Bayam, State Machine 4 Tahap, Kondisi Stall, Gating Jeda Simulasi, dan Representasi Visual 3D Petak).

---

## 1. Observation

Berdasarkan pemeriksaan langsung terhadap dokumen spesifikasi dan kode proyek yang sedang berjalan:

### 1.1 Spesifikasi Kontrak Pertumbuhan Bayam (`docs/CONTENT.md` § 8)
- File: `docs/CONTENT.md`, Baris 131–146:
  ```markdown
  ## 8. Tanaman bayam

  | Parameter | Nilai DEFAULT UJI |
  | --- | --- |
  | Definisi | `crop_bayam` |
  | Biaya tanam | 1 `seed_bayam` |
  | Lama tumbuh efektif | 180 detik |
  | Tahap benih | Kemajuan 0 hingga <30 detik |
  | Tahap tunas | 30 hingga <90 detik |
  | Tahap tumbuh | 90 hingga <180 detik |
  | Siap panen | ≥180 detik; kemajuan dikunci pada 180 |
  | Hasil per titik | Bayam 1 dan benih bayam 1 |
  | Saat dipanen | Titik kosong; nutrisi petak berkurang 5 |
  | Kekurangan kebutuhan | Kemajuan berhenti; tidak mundur, tidak mati |

  Tiga titik cukup untuk resep; titik keempat adalah kelonggaran eksplorasi. Tutorial tidak mewajibkan menanam empat titik jika kebutuhan sudah terpenuhi. Tiap tanaman punya kemajuan sendiri, tetapi kondisi perawatan dibaca dari petak yang sama. Tanaman siap panen tidak kehilangan kesiapan karena petak mengering.
  ```

### 1.2 Syarat Tumbuh dan Kondisi Petak (`docs/CONTENT.md` § 7)
- File: `docs/CONTENT.md`, Baris 110–130:
  ```markdown
  | ID petak | `plot_home_01` |
  | Luas | 2 × 2 meter |
  | Titik | 4, ID `slot_01` hingga `slot_04` |
  | Awal | Belum diolah; pembenah belum ditambahkan; nutrisi 0; kelembapan 0 |
  | Siap tanam | Sudah gembur dan pembenah ditambahkan |
  | Pembenah | Sekali untuk petak; tidak habis setelah panen |
  | Nutrisi valid | 0–100, “Perlu pupuk” bila <20, “Cukup” bila ≥20 |
  | Pemupukan | Jika nutrisi <20, 1 pupuk mengatur nutrisi ke 100 |
  | Biaya panen nutrisi | 5 per tanaman berhasil dipanen; minimum nilai 0 |
  | Kelembapan valid | 0–100; “Kering” bila <30; “Lembap” bila ≥30 |
  | Penyiraman | Jika kelembapan <60, aksi memakai 2 air dan mengatur ke 80 |
  | Penguapan | Turun 0,1 per detik simulasi aktif, minimum 0 |
  | Syarat tumbuh | Siap tanam, nutrisi ≥20, kelembapan ≥30 |
  ```
  - Ambang pertumbuhan adalah: `nutrisi >= 20.0` DAN `kelembapan >= 30.0` pada petak yang sudah `is_hoed == true` dan `has_compost == true`.
  - Ambang 60.0 adalah ambang izin aksi penyiraman, bukan ambang pertumbuhan. Petak pada kelembapan 40.0 tetap bertumbuh secara normal.

### 1.3 Kontrak Jeda Waktu & Input (`docs/PROTOTYPE.md` § 5)
- File: `docs/PROTOTYPE.md`, Baris 53–68 & 163–165:
  - Pertumbuhan tanaman, penguapan air, dan kemajuan hari hanya berjalan pada konteks aktif **Dunia** dan **Dapur aktif**.
  - Saat modal terbuka (Buku, Tas, Peti, Dialog, Pause, Pengaturan, atau window unfocus/kehilangan fokus aplikasi), seluruh simulasi waktu pertumbuhan **berhenti** (`InputManager.is_simulation_paused() == true` atau `get_tree().paused == true`).
  - Istirahat ranjang (`bed_home`) adalah transisi kalender untuk pemulihan sumber liar, dan **TIDAK** menyimulasikan 720 detik pertumbuhan tanaman atau penguapan sekaligus. Kondisi petak dan kemajuan tanaman dipertahankan.

### 1.4 Implementasi Eksisting di `scripts/gardening/garden_manager.gd`
- File: `scripts/gardening/garden_manager.gd`:
  - Struktur data petak awal (baris 63–80):
    ```gdscript
    func _create_default_plot(p_id: String) -> Dictionary:
        var spots_dict: Dictionary = {}
        for i in range(1, 5):
            var s_id := "slot_%02d" % i
            spots_dict[s_id] = {
                "spot_id": s_id,
                "spot_index": i - 1,
                "is_occupied": false,
                "crop_data": null
            }
        return {
            "id": p_id,
            "is_hoed": false,
            "has_compost": false,
            "nutrients": 0.0,
            "moisture": 0.0,
            "spots": spots_dict
        }
    ```
  - Struktur data penanaman benih saat ini (baris 325–331):
    ```gdscript
    spot["is_occupied"] = true
    spot["crop_data"] = {
        "crop_id": "crop_bayam",
        "growth_time": 0.0,
        "growth_stage": 0,
        "is_ready_to_harvest": false
    }
    ```
  - Loop simulasi saat ini (baris 361–384):
    Saat ini `_process(delta)` hanya mengeksekusi `simulate_process(delta)` untuk penguapan kelembapan (`EVAPORATION_RATE = 0.1`). Belum ada iterasi pertumbuhan titik tanam (`growth_time`) atau transisi tahap tanaman.
  - Persistensi snapshot SAVE-001 (baris 387–406):
    `get_save_snapshot()` menduplikasi `_plots` secara rekursif (`duplicate(true)`), dan `load_save_snapshot()` memulihkan seluruh dictionary `_plots`. Penambahan field di dalam `crop_data` langsung kompatibel dengan sistem save tanpa mengubah skema penyimpanan utama.

### 1.5 Observasi Scene & Visualisasi Petak
- `scenes/world/plot.tscn` **tidak ditemukan** sebagai file terpisah pada filesystem proyek.
- Sub-tree petak pekarangan didefinisikan langsung di dalam `scenes/world/level_graybox.tscn` (baris 585–636) di bawah node `plot_home_01`:
  - `SoilBed` (`StaticBody3D` dengan box collision 2.0 × 0.15 × 2.0 dan `MeshInstance3D`)
  - `Interactable` (`Area3D`, layer 4, `interaction_id = "landmark_plot"`)
  - 4 node titik kuadran:
    - `spot_0` pada posisi lokal `(-0.5, 0.1, -0.5)` dengan anak `Marker` (`MeshInstance3D`, 0.25 × 0.04 × 0.25 m)
    - `spot_1` pada posisi lokal `(0.5, 0.1, -0.5)` dengan anak `Marker`
    - `spot_2` pada posisi lokal `(-0.5, 0.1, 0.5)` dengan anak `Marker`
    - `spot_3` pada posisi lokal `(0.5, 0.1, 0.5)` dengan anak `Marker`
- File `scripts/main.gd` (baris 121–176) menangani sinyal `GardenManager.plot_state_changed`:
  - Memperbarui material `SoilBed/Mesh` berdasarkan `is_hoed`, `has_compost`, dan `moisture`.
  - Memperbarui warna `Marker` pada tiap titik: hijau terang (`Color(0.25, 0.85, 0.30)`) jika terisi benih (`is_occupied == true`), atau abu-abu (`Color(0.6, 0.6, 0.6)`) jika kosong.
  - Belum ada representasi visual untuk transisi bentuk/skala 4 tahap bayam.

---

## 2. Logic Chain

Penalaran terstruktur dari observasi menuju rekomendasi arsitektur implementasi:

1. **State Machine 4 Tahap Berbasis Waktu Efektif Deterministik:**
   - Observasi § 1.1 menyatakan bayam membutuhkan total 180 detik waktu tumbuh aktif dengan 4 tahap diskret.
   - Karena itu, kita mendefinisikan enum dan konstanta durasi tahap yang konsisten:
     ```gdscript
     enum CropStage {
         SEED = 0,        # 0.0 <= t < 30.0s  (Tahap Benih)
         SPROUT = 1,      # 30.0 <= t < 90.0s (Tahap Tunas, durasi 60s)
         GROWING = 2,     # 90.0 <= t < 180.0s (Tahap Tumbuh, durasi 90s)
         HARVESTABLE = 3  # t >= 180.0s        (Siap Panen, dikunci di 180.0s)
     }
     ```
   - Setiap titik tanam (`spot`) mengakumulasi `growth_time` independen saat kondisi terpenuhi.
   - Ketika `growth_time >= 180.0`, nilai dikunci (`crop["growth_time"] = 180.0`), `crop["growth_stage"] = CropStage.HARVESTABLE`, dan flag `crop["is_ready_to_harvest"] = true`.

2. **Kondisi Pertumbuhan & Perilaku Stall (Terhenti Sementara):**
   - Berdasarkan observasi § 1.2, pertumbuhan aktif hanya terjadi jika:
     `is_hoed == true && has_compost == true && nutrients >= 20.0 && moisture >= 30.0`.
   - Jika kelembapan turun di bawah 30.0 (misalnya karena penguapan 0.1/s) ATAU nutrisi di bawah 20.0 (setelah pemanenan sebelumnya belum dipupuk):
     - `growth_time` **TIDAK bertambah** (`delta` diabaikan).
     - `growth_time` **TIDAK mundur** (kemajuan tersimpan).
     - Tanaman **TIDAK layu/mati** (tidak ada penalti kematian tanaman pada P0).
     - Tanaman yang sudah siap panen (`growth_stage == CropStage.HARVESTABLE`) **tetap siap panen** dan tidak kehilangan statusnya.
     - Begitu pemain menyiram (kelembapan diatur ke 80.0) atau memupuk (nutrisi diatur ke 100.0), kondisi terpenuhi kembali dan kemajuan pertumbuhan langsung melanjutkan dari detik terakhir.

3. **Pemisahan Metode Simulasi untuk Testability Headless:**
   - Loop `_process(delta)` memanggil `simulate_process(delta)`.
   - `simulate_process(delta)` menjalankan dua fase:
     1. `simulate_evaporation(delta)` (penguapan 0.1 unit/detik)
     2. `simulate_growth(delta)` (akumulasi `growth_time` dan transisi tahap)
   - Dengan mengekspos `simulate_growth(delta: float)` secara publik, harness pengujian headless (`test_gardening.gd`) dapat menyimulasikan lompatan waktu delta (misal `simulate_growth(30.0)`, `simulate_growth(60.0)`, `simulate_growth(90.0)`) secara instan dan deterministik dalam 1 frame tanpa harus menunggu 180 detik waktu nyata.

4. **Isolasi Multi-Spot Independen:**
   - Titik `slot_01`..`slot_04` (`spot_0`..`spot_3`) memiliki objek `crop_data` masing-masing di dalam dictionary `spots`.
   - Jika pemain menanam titik 1 pada detik 0 dan titik 2 pada detik 60, pada detik 180 titik 1 mencapai `HARVESTABLE` (180s) sedangkan titik 2 berada di `GROWING` (120s).
   - Kondisi stall berlaku global pada petak, sehingga jika petak kering, semua tanaman yang belum siap panen berhenti tumbuh bersamaan, namun tetap menyimpan progres masing-masing secara terpisah.

5. **Arsitektur Representasi Visual 3D Petak:**
   - Mengingat `plot_home_01` berada di dalam `level_graybox.tscn` dan `main.gd` telah memiliki listener `_on_garden_plot_state_changed()`, strategi visual terbaik yang tidak merusak scene serialization adalah:
     - Membuat sub-node `CropMesh` (atau memperbarui `Marker`) di bawah masing-masing node `spot_0`..`spot_3`.
     - Ketika tahap berubah (`crop_stage_changed`), `CropMesh` diperbarui skala geometri dan warnanya:
       - **Stage 0 (Benih):** Mesh kecil di permukaan tanah, skala `Vector3(0.08, 0.04, 0.08)`, warna cokelat benih/tanah (`Color(0.35, 0.25, 0.15)`).
       - **Stage 1 (Tunas):** Tunas hijau muda mungil, skala `Vector3(0.14, 0.14, 0.14)`, warna hijau muda segar (`Color(0.55, 0.85, 0.25)`).
       - **Stage 2 (Tumbuh):** Tanaman bayam rimbun sedang, skala `Vector3(0.28, 0.28, 0.28)`, warna hijau daun bayam (`Color(0.22, 0.68, 0.20)`).
       - **Stage 3 (Siap Panen):** Rumpun bayam dewasa siap petik, skala `Vector3(0.42, 0.42, 0.42)`, warna hijau matang pekat (`Color(0.14, 0.58, 0.18)`) dengan aksen kilau siap panen.
       - **Kosong / Setelah Panen:** `CropMesh.visible = false`, marker kembali abu-abu netral.
   - Pendekatan mesh prosedural/skala ini mematuhi gaya stylized low-poly proyek, sangat ringan (zero external assets), dan transisinya dapat diberi animasi `Tween` halus (game-feel juice).

---

## 3. Caveats

1. **Pemanenan Atomik dan Kapasitas Tas:**
   - Logika verifikasi 2 slot tas kosong dan commit 1x `ingredient_bayam` + 1x `seed_bayam` diinvestigasi secara mendalam oleh `explorer_gard_002_2`.
   - State machine pertumbuhan bertanggung jawab penuh atas flag `is_ready_to_harvest = true`, menyediakan method `can_harvest_crop(plot_id, spot_id)`, serta mengosongkan titik tanam (`is_occupied = false`, `crop_data = null`) dan mengurangi 5 nutrisi petak saat aksi panen di-commit oleh controller.
2. **Ketiadaan `scenes/world/plot.tscn` Mandiri:**
   - Dokumen dispatch menyebutkan `scenes/world/plot.tscn`. Namun secara faktual, petak diimplementasikan sebagai sub-tree `plot_home_01` di dalam `level_graybox.tscn`.
   - Merefaktor `plot_home_01` menjadi scene instanced eksternal (`plot.tscn`) berpotensi merusak referensi node di `test_runner.gd` dan tes graybox jika path berubah. Oleh karena itu, rekomendasi kami adalah mempertahankan node hierarki `plot_home_01` di `level_graybox.tscn` dan/atau menyediakan file pendamping `scripts/world/plot.gd` jika ingin memisahkan logika visual dari `main.gd`.
3. **Ketergantungan terhadap `InputManager`:**
   - Simulasi pertumbuhan bergantung pada `InputManager.is_simulation_paused()`. Pada pengujian headless di mana `InputManager` mungkin berupa mock atau null, `GardenManager` harus tetap memiliki fallback aman (`if im != null and im.has_method("is_simulation_paused")...`) agar tidak crash di mode isolated runner.

---

## 4. Conclusion

### 4.1 Cetak Biru Perubahan Data & Method di `scripts/gardening/garden_manager.gd`

#### A. Deklarasi Sinyal Baru:
```gdscript
signal crop_stage_changed(plot_id: String, spot_id: String, old_stage: int, new_stage: int, crop_id: String)
signal crop_ready_to_harvest(plot_id: String, spot_id: String, crop_id: String)
signal crop_stalled(plot_id: String, spot_id: String, reason: String)
signal crop_resumed(plot_id: String, spot_id: String)
signal spot_harvested(plot_id: String, spot_id: String, crop_id: String)
```

#### B. Konstanta Tahap & Waktu Tumbuh:
```gdscript
enum CropStage {
	SEED = 0,
	SPROUT = 1,
	GROWING = 2,
	HARVESTABLE = 3
}

const CROP_STAGE_NAMES: Dictionary = {
	CropStage.SEED: "Benih",
	CropStage.SPROUT: "Tunas",
	CropStage.GROWING: "Tumbuh",
	CropStage.HARVESTABLE: "Siap Panen"
}

const BAYAM_TOTAL_GROWTH_TIME: float = 180.0
const STAGE_SPROUT_THRESHOLD: float = 30.0
const STAGE_GROWING_THRESHOLD: float = 90.0
const STAGE_HARVESTABLE_THRESHOLD: float = 180.0

const CROP_MOISTURE_GROWTH_THRESHOLD: float = 30.0
const CROP_NUTRIENTS_GROWTH_THRESHOLD: float = 20.0
const HARVEST_NUTRIENT_COST: float = 5.0
```

#### C. Method Evaluasi Syarat Tumbuh & Stall:
```gdscript
func can_crop_grow_on_plot(plot_id: String = DEFAULT_PLOT_ID) -> bool:
	var p: Dictionary = get_plot(plot_id)
	if p.is_empty():
		return false
	if not (bool(p.get("is_hoed", false)) and bool(p.get("has_compost", false))):
		return false
	var n: float = float(p.get("nutrients", 0.0))
	var m: float = float(p.get("moisture", 0.0))
	return n >= CROP_NUTRIENTS_GROWTH_THRESHOLD and m >= CROP_MOISTURE_GROWTH_THRESHOLD

func get_plot_growth_stall_reason(plot_id: String = DEFAULT_PLOT_ID) -> String:
	var p: Dictionary = get_plot(plot_id)
	if p.is_empty():
		return "Petak tidak ditemukan."
	if not (bool(p.get("is_hoed", false)) and bool(p.get("has_compost", false))):
		return "Tanah belum siap ditanami."
	var n: float = float(p.get("nutrients", 0.0))
	var m: float = float(p.get("moisture", 0.0))
	if n < CROP_NUTRIENTS_GROWTH_THRESHOLD and m < CROP_MOISTURE_GROWTH_THRESHOLD:
		return "Kurang nutrisi dan air."
	elif n < CROP_NUTRIENTS_GROWTH_THRESHOLD:
		return "Kurang nutrisi (perlu pupuk)."
	elif m < CROP_MOISTURE_GROWTH_THRESHOLD:
		return "Kurang air (perlu disiram)."
	return ""

func calculate_crop_stage(growth_time: float) -> int:
	if growth_time < STAGE_SPROUT_THRESHOLD:
		return CropStage.SEED
	elif growth_time < STAGE_GROWING_THRESHOLD:
		return CropStage.SPROUT
	elif growth_time < STAGE_HARVESTABLE_THRESHOLD:
		return CropStage.GROWING
	else:
		return CropStage.HARVESTABLE
```

#### D. Loop Simulasi Pertumbuhan:
```gdscript
func simulate_growth(delta: float) -> void:
	var im = _get_input_manager()
	if im != null and im.has_method("is_simulation_paused"):
		if im.is_simulation_paused():
			return

	if is_inside_tree() and get_tree().paused:
		return

	for p_id in _plots:
		_simulate_plot_growth(p_id, delta)

func _simulate_plot_growth(plot_id: String, delta: float) -> void:
	var plot: Dictionary = _plots.get(plot_id, {})
	if plot.is_empty():
		return

	var can_grow := can_crop_grow_on_plot(plot_id)
	var spots: Dictionary = plot.get("spots", {})

	for spot_id in spots:
		var spot: Dictionary = spots[spot_id]
		if not spot.get("is_occupied", false) or spot.get("crop_data") == null:
			continue

		var crop: Dictionary = spot["crop_data"]
		if crop.get("is_ready_to_harvest", false):
			continue

		if not can_grow:
			if not crop.get("is_stalled", false):
				crop["is_stalled"] = true
				var reason := get_plot_growth_stall_reason(plot_id)
				crop["stall_reason"] = reason
				crop_stalled.emit(plot_id, spot_id, reason)
			continue

		# Reset status stall jika kondisi kembali terpenuhi
		if crop.get("is_stalled", false):
			crop["is_stalled"] = false
			crop["stall_reason"] = ""
			crop_resumed.emit(plot_id, spot_id)

		var old_stage: int = int(crop.get("growth_stage", 0))
		var old_time: float = float(crop.get("growth_time", 0.0))
		var new_time: float = minf(BAYAM_TOTAL_GROWTH_TIME, old_time + delta)
		crop["growth_time"] = new_time

		var new_stage: int = calculate_crop_stage(new_time)
		crop["growth_stage"] = new_stage

		if new_time >= BAYAM_TOTAL_GROWTH_TIME:
			crop["is_ready_to_harvest"] = true
			crop_ready_to_harvest.emit(plot_id, spot_id, str(crop.get("crop_id", "crop_bayam")))

		if old_stage != new_stage:
			crop_stage_changed.emit(plot_id, spot_id, old_stage, new_stage, str(crop.get("crop_id", "crop_bayam")))
			plot_state_changed.emit(plot_id, plot)

func simulate_process(delta: float) -> void:
	# 1. Evaporation
	simulate_evaporation(delta)
	# 2. Growth
	simulate_growth(delta)
```

#### E. Method Transaksi Pemanenan (Menghubungkan State Machine Kembali ke Kosong):
```gdscript
func can_harvest_crop(plot_id: String, spot_id: String) -> Dictionary:
	if not _plots.has(plot_id):
		return {"success": false, "reason": "Petak tidak ditemukan."}
	var resolved := resolve_spot_id(spot_id)
	var spot: Dictionary = get_spot(plot_id, resolved)
	if spot.is_empty() or not spot.get("is_occupied", false) or spot.get("crop_data") == null:
		return {"success": false, "reason": "Tidak ada tanaman di titik ini."}
	var crop: Dictionary = spot["crop_data"]
	if not crop.get("is_ready_to_harvest", false):
		return {"success": false, "reason": "Tanaman belum siap dipanen."}
	
	# Verifikasi kapasitas tas (2 item: 1 ingredient_bayam + 1 seed_bayam)
	var inv = _get_inventory_manager()
	if inv != null:
		var bp = inv.get_container("backpack")
		if bp != null:
			if not bp.can_add_item("ingredient_bayam", 1) or not bp.can_add_item("seed_bayam", 1):
				# Cek jika kedua item memerlukan 2 slot baru atau dapat ditumpuk
				if not _can_backpack_fit_harvest(bp, "ingredient_bayam", 1, "seed_bayam", 1):
					return {"success": false, "reason": "Tas penuh! Butuh ruang untuk bayam dan benih."}
	return {"success": true, "reason": "Dapat dipanen."}

func harvest_crop(plot_id: String, spot_id: String) -> bool:
	var check := can_harvest_crop(plot_id, spot_id)
	if not check["success"]:
		action_failed.emit(check["reason"])
		return false
	
	var resolved := resolve_spot_id(spot_id)
	var inv = _get_inventory_manager()
	if inv != null:
		var bp = inv.get_container("backpack")
		if bp != null:
			bp.add_item("ingredient_bayam", 1)
			bp.add_item("seed_bayam", 1)
	
	# Deduksi nutrisi petak sebesar 5 poin (minimum 0.0)
	var p: Dictionary = _plots[plot_id]
	var cur_n: float = float(p.get("nutrients", 0.0))
	var new_n: float = maxf(0.0, cur_n - HARVEST_NUTRIENT_COST)
	p["nutrients"] = new_n
	
	# Reset titik tanam ke status kosong
	var spot: Dictionary = p["spots"][resolved]
	spot["is_occupied"] = false
	spot["crop_data"] = null
	
	spot_harvested.emit(plot_id, resolved, "crop_bayam")
	plot_nutrients_changed.emit(plot_id, new_n)
	plot_state_changed.emit(plot_id, p)
	action_success.emit("harvest", "Bayam berhasil dipanen! Mendapatkan 1 Bayam dan 1 Benih.")
	return true
```

### 4.2 Cetak Biru Pembaruan Visual di `scripts/main.gd`
Dalam fungsi `_on_garden_plot_state_changed(plot_id, plot_data)` di `scripts/main.gd`:
```gdscript
		var spot_node = plot_node.get_node_or_null(spot_node_name)
		if spot_node != null:
			var crop_mesh = spot_node.get_node_or_null("CropMesh") as MeshInstance3D
			if bool(spot_info.get("is_occupied", false)):
				if crop_mesh == null:
					crop_mesh = MeshInstance3D.new()
					crop_mesh.name = "CropMesh"
					crop_mesh.mesh = BoxMesh.new()
					spot_node.add_child(crop_mesh)
				crop_mesh.visible = true
				
				var crop_data: Dictionary = spot_info.get("crop_data", {})
				var stage: int = int(crop_data.get("growth_stage", 0))
				var mat: StandardMaterial3D = crop_mesh.material_override as StandardMaterial3D
				if mat == null:
					mat = StandardMaterial3D.new()
					crop_mesh.material_override = mat
				
				match stage:
					0: # Seed
						crop_mesh.scale = Vector3(0.08, 0.04, 0.08)
						crop_mesh.position = Vector3(0, 0.02, 0)
						mat.albedo_color = Color(0.35, 0.25, 0.15)
					1: # Sprout
						crop_mesh.scale = Vector3(0.14, 0.14, 0.14)
						crop_mesh.position = Vector3(0, 0.07, 0)
						mat.albedo_color = Color(0.55, 0.85, 0.25)
					2: # Growing
						crop_mesh.scale = Vector3(0.28, 0.28, 0.28)
						crop_mesh.position = Vector3(0, 0.14, 0)
						mat.albedo_color = Color(0.22, 0.68, 0.20)
					3: # Harvestable
						crop_mesh.scale = Vector3(0.42, 0.42, 0.42)
						crop_mesh.position = Vector3(0, 0.21, 0)
						mat.albedo_color = Color(0.14, 0.58, 0.18)
			else:
				if crop_mesh != null:
					crop_mesh.visible = false
```

---

## 5. Verification Method

Implementasi arsitektur di atas dapat diverifikasi secara mandiri melalui langkah-langkah berikut:

### 5.1 Perintah Eksekusi Pengujian Otomatis Headless
1. **Seluruh Test Suite Proyek:**
   ```powershell
   & "C:\Users\HP\.local\bin\godot.exe" --headless -s tests/test_runner.gd
   ```
   *Ekspektasi:* Seluruh test suite (Suite 1–9 dan suite baru untuk GARD-002) lulus 100% dengan exit code 0.
2. **Stress Test Invarian Kebun:**
   ```powershell
   & "C:\Users\HP\.local\bin\godot.exe" --headless -s tests/stress_garden_invariants.gd
   ```
   *Ekspektasi:* Seluruh asersi determinisme penguapan, isolasi kuadran, dan invarian pertumbuhan lulus tanpa error.

### 5.2 Rencana Test Case Baru untuk GARD-002
1. **Test T05 & T34 (4 Tahap & Timing):**
   - Tanam benih di `slot_01`. Beri nutrisi 100 dan kelembapan 80.
   - Panggil `gm.simulate_growth(29.9)` -> Verifikasi `growth_stage == 0` (Seed).
   - Panggil `gm.simulate_growth(0.2)` (total 30.1s) -> Verifikasi `growth_stage == 1` (Sprout).
   - Panggil `gm.simulate_growth(60.0)` (total 90.1s) -> Verifikasi `growth_stage == 2` (Growing).
   - Panggil `gm.simulate_growth(90.0)` (total 180.1s) -> Verifikasi `growth_stage == 3` (Harvestable), `is_ready_to_harvest == true`, dan `growth_time == 180.0` (terkunci).
2. **Test T35 (Stall Invariants):**
   - Atur kelembapan ke 25.0 (< 30.0). Panggil `gm.simulate_growth(50.0)`.
   - Verifikasi `growth_time` tidak bertambah sama sekali, tanaman tidak mati, tahap tidak berubah.
   - Siram petak (kelembapan = 80.0). Panggil `gm.simulate_growth(10.0)`.
   - Verifikasi `growth_time` langsung bertambah 10.0 dari titik henti sebelumnya.
3. **Test Gating Pause Simulasi:**
   - Atur `InputManager.push_context(ContextMode.BOOK)`.
   - Panggil `gm.simulate_process(50.0)`.
   - Verifikasi baik kelembapan (penguapan) maupun `growth_time` tidak mengalami mutasi saat simulasi paused.
4. **Test Multi-Spot Asynchronous Growth:**
   - Tanam di `slot_01` pada t=0s.
   - Simulasikan 60s.
   - Tanam di `slot_02` pada t=60s.
   - Simulasikan 60s lagi (total t=120s).
   - Verifikasi `slot_01` berada di Stage 2 (Growing, 120s), sedangkan `slot_02` berada di Stage 1 (Sprout, 60s). Kedua titik beroperasi secara independen sempurna.
5. **Test Pemanenan & Penurunan Nutrisi:**
   - Panen tanaman siap di `slot_01`.
   - Verifikasi nutrisi petak berkurang tepat 5.0 poin (`nutrients == 95.0`).
   - Verifikasi `slot_01` kembali kosong (`is_occupied == false`).
   - Tanam kembali benih di `slot_01` tanpa perlu cangkul ulang.

### 5.3 Kondisi Pembatalan (Invalidation Conditions)
- Jika `growth_time` bertambah saat kelembapan < 30.0 atau nutrisi < 20.0.
- Jika tanaman layu atau progres di-reset ke 0 saat terjadi stall.
- Jika tanaman siap panen kehilangan kesiapan ketika tanah mengering.
- Jika simulasi pertumbuhan berjalan saat menu pause atau modal terbuka.
