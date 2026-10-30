# HANDOFF — Atomic Harvesting & Inventory Interaction Explorer (GARD-002)

**Tanggal**: 2026-10-27T19:18:00Z  
**Agent**: `explorer_gard_002_2` (`teamwork_explorer`)  
**Tujuan**: Menyerahkan hasil investigasi arsitektur pemanenan atomik bayam, validasi kapasitas tas 2-slot, deduksi nutrisi petak (-5), kesiapan tanam ulang spot, dan pemetaan interaksi raycast player untuk task `GARD-002`.

---

## 1. Observation

Berdasarkan inspeksi langsung terhadap dokumen spesifikasi dan kode proyek yang ada:

### 1.1 Persyaratan Pemanenan & Hasil Produk (CONTENT.md & PRD.md)
- `docs/CONTENT.md` § 8 (Baris 137–144):
  > `| Lama tumbuh efektif | 180 detik |`  
  > `| Tahap benih | Kemajuan 0 hingga <30 detik |`  
  > `| Tahap tunas | 30 hingga <90 detik |`  
  > `| Tahap tumbuh | 90 hingga <180 detik |`  
  > `| Siap panen | ≥180 detik; kemajuan dikunci pada 180 |`  
  > `| Hasil per titik | Bayam 1 dan benih bayam 1 |`  
  > `| Saat dipanen | Titik kosong; nutrisi petak berkurang 5 |`  
  > `| Kekurangan kebutuhan | Kemajuan berhenti; tidak mundur, tidak mati |`
- `docs/CONTENT.md` § 7 (Baris 117–120):
  > `| Pembenah | Sekali untuk petak; tidak habis setelah panen |`  
  > `| Biaya panen nutrisi | 5 per tanaman berhasil dipanen; minimum nilai 0 |`
- `docs/CONTENT.md` § 3 (Baris 45):
  > `Pickup dan panen memeriksa kapasitas seluruh hasil terlebih dahulu. Panen bayam menghasilkan dua jenis item, sehingga satu slot kosong belum tentu cukup. Jika tidak muat, sumber/tanaman tetap utuh. Transfer pilihan memindahkan seluruh tumpukan terpilih; transfer semua memindahkan seluruh isi hanya jika tujuan dapat menampungnya. Bila tidak muat, tidak ada perubahan dan UI memberi alasan. Tidak ada transfer parsial diam-diam pada P0.`
- `docs/CONTENT.md` § 11 (Baris 197):
  > `| Tas penuh | “Tas tidak cukup. Kosongkan slot atau simpan barang di rumah.” |`
- `PRD.md` (Baris 127):
  > `| FR11 | P0 | Tumbuh dan panen bayam | Kekurangan menahan pertumbuhan; panen satu kali dan titik dapat ditanam ulang |`
- `docs/TEST_PLAN.md` (Baris 37 & 68):
  > `| T05 | Tas tidak cukup menampung seluruh hasil bayam+benih; panen | Panen ditolak; tanaman siap dan nutrisi tidak berubah |`  
  > `| T36 | Panen berhasil lalu spam E; tanam ulang | Satu bayam+benih sesuai CONTENT; nutrisi turun sekali; titik kembali dapat ditanam |`

### 1.2 Registri Item & Alias Transparan (items_data.gd)
- `scripts/inventory/items_data.gd` (Baris 47–91):
  - `seed_bayam` didaftarkan sebagai ID kanonikal benih bayam (baris 48).
  - `ingredient_bayam` didaftarkan sebagai ID kanonikal sayur bayam hasil panen (baris 82).
  - `crop_bayam` didaftarkan sebagai alias untuk `ingredient_bayam` (baris 90).
  - Belum ada alias untuk `crop_spinach` dan `seed_spinach`.

### 1.3 Sistem Inventaris & Validator Kapasitas Panen (inventory_manager.gd & inventory_container.gd)
- `scripts/inventory/inventory_manager.gd` (Baris 297–304):
  ```gdscript
  ## Validator kapasitas panen (T05: mengecek apakah tas muat hasil panen, default 1 bayam + 1 benih)
  func can_harvest(crop_items: Variant = null) -> bool:
      if crop_items == null:
          var default_harvest: Array[Dictionary] = [
              {"item_id": "ingredient_bayam", "id": "ingredient_bayam", "count": 1},
              {"item_id": "seed_bayam", "id": "seed_bayam", "count": 1}
          ]
          return backpack.can_add_batch(default_harvest)
      return backpack.can_add_batch(crop_items)
  ```
- `scripts/inventory/inventory_container.gd` (Baris 82–123):
  - `can_add_batch(items)` melakukan dry-run alokasi virtual slot pada salinan sementara `sim_slots`.
  - Simulasi mencoba mengisi tumpukan parsial yang sudah ada terlebih dahulu (`count < default_stack_limit`), baru kemudian mengisi slot kosong baru. Jika sisa `remaining > 0` setelah memeriksa seluruh slot, mengembalikan `false` tanpa melakukan mutasi nyata apapun.

### 1.4 State Plot & Titik Tanam Saat Ini (garden_manager.gd)
- `scripts/gardening/garden_manager.gd` (Baris 63–80):
  - Titik tanam diinisialisasi dalam dictionary `spots` (`slot_01` hingga `slot_04`).
  - Masing-masing spot memiliki struktur:
    ```gdscript
    {
        "spot_id": s_id,
        "spot_index": i - 1,
        "is_occupied": false,
        "crop_data": null
    }
    ```
  - Saat ditanami (`plant_seed`, baris 326–331):
    ```gdscript
    spot["crop_data"] = {
        "crop_id": "crop_bayam",
        "growth_time": 0.0,
        "growth_stage": 0,
        "is_ready_to_harvest": false
    }
    ```
  - Belum ada method `can_harvest_crop(plot_id, spot_id)` maupun `harvest_crop(plot_id, spot_id)` di `garden_manager.gd`.

### 1.5 Geometri Pekarangan & Raycast Interaksi (level_graybox.gd & player_controller.gd)
- `scripts/tools/build_level_graybox.gd` (Baris 212–236):
  - Plot `plot_home_01` berukuran 2.0 × 0.15 × 2.0 m, memiliki satu `Interactable` area (`landmark_plot`) di tengah (baris 220).
  - 4 titik tanam diletakkan pada kuadran:
    - `spot_0` (`slot_01`): `Vector3(-0.5, 0.1, -0.5)` (NW)
    - `spot_1` (`slot_02`): `Vector3(0.5, 0.1, -0.5)` (NE)
    - `spot_2` (`slot_03`): `Vector3(-0.5, 0.1, 0.5)` (SW)
    - `spot_3` (`slot_04`): `Vector3(0.5, 0.1, 0.5)` (SE)
- `scripts/player/player_controller.gd` (Baris 437–463):
  - Pemain mendeteksi titik kuadran saat menanam benih menggunakan konversi titik kontak raycast ke koordinat lokal `plot_node`:
    ```gdscript
    var local_pt: Vector3 = plot_node.to_local(hit_pt)
    var spot_id: String = ""
    if local_pt.x < 0.0:
        spot_id = "slot_01" if local_pt.z < 0.0 else "slot_03"
    else:
        spot_id = "slot_02" if local_pt.z < 0.0 else "slot_04"
    ```
- `scripts/ui/hud.gd` (Baris 266–306):
  - Saat reticle membidik `landmark_plot`, jika alat aktif adalah tangan kosong (`TOOL_NONE`), prompt saat ini menampilkan status nutrisi dan kelembapan, belum menampilkan status panen per titik.
- `scripts/main.gd` (Baris 113–120):
  - `_on_plot_interacted` saat ini hanya memeriksa pemberian pembenah tanah (`if is_hoed and not has_compost: gm.add_compost()`), belum memeriksa pemanenan pada titik yang dibidik.

---

## 2. Logic Chain

1. **Hasil Pemanenan & Kebutuhan Ruang Tas (Observation 1.1, 1.2, 1.3):**
   - Berdasarkan `CONTENT.md` § 8, panen 1 titik bayam menghasilkan tepat 2 unit barang: 1x sayur bayam (`ingredient_bayam`) + 1x benih bayam (`seed_bayam`).
   - Berdasarkan `CONTENT.md` § 3 dan `TEST_PLAN.md` T05, panen wajib memeriksa kapasitas seluruh hasil sebelum satu item pun ditransfer.
   - Karena menghasilkan 2 jenis item yang berbeda:
     - Jika tas kosong atau memiliki ≥2 slot kosong, panen selalu muat.
     - Jika tas memiliki 1 slot kosong:
       - Bila salah satu item (misal `seed_bayam`) sudah ada di tas dalam tumpukan parsial (`count < 20`), maka benih masuk menumpuk di slot lama dan bayam mengambil 1 slot kosong baru -> panen BERHASIL.
       - Bila tas tidak memiliki tumpukan parsial untuk kedua item tersebut, maka dibutuhkan 2 slot kosong baru; dengan hanya 1 slot kosong, panen DITOLAK secara atomik.
     - Jika tas memiliki 0 slot kosong (12 slot penuh):
       - Bila kedua item sudah memiliki tumpukan parsial masing-masing yang belum penuh, keduanya menumpuk -> panen BERHASIL.
       - Bila salah satu atau kedua item tidak memiliki ruang tumpukan -> panen DITOLAK secara atomik.
   - Seluruh logika alokasi virtual ini sudah diimplementasikan secara akurat di `InventoryContainer.can_add_batch()` dan dibungkus oleh `InventoryManager.can_harvest()`.

2. **Protokol 2-Phase Commit Pemanenan Atomik (Observation 1.1, 1.3, 1.4):**
   - **Phase 1: Validation (Dry-Run)**:
     - Periksa validitas `plot_id` dan `spot_id`.
     - Periksa keberadaan tanaman di spot (`spot["is_occupied"] == true` dan `spot["crop_data"] != null`).
     - Periksa kematangan tanaman: harus berada di tahap panen (`growth_stage == 3` atau `growth_time >= 180.0` atau `is_ready_to_harvest == true`).
     - Periksa kapasitas inventaris pemain: panggil `inv.can_harvest()`.
     - *Invarian atomik*: Jika salah satu validasi di atas gagal, fungsi mengembalikan `false` (dengan pesan error spesifik dari CONTENT.md § 11: `"Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."`), memancarkan sinyal `action_failed`, dan sama sekali TIDAK mengubah state tanaman, nutrisi petak, atau inventaris tas.
   - **Phase 2: Commit (Mutasi State)**:
     - Tambahkan batch item hasil panen ke tas pemain:
       `inv.backpack.add_batch([{"item_id": "ingredient_bayam", "count": 1}, {"item_id": "seed_bayam", "count": 1}])`.
     - Kurangi nutrisi petak sebanyak 5 poin secara atomik:
       `plot["nutrients"] = maxf(0.0, float(plot["nutrients"]) - 5.0)`.
     - Reset state titik tanam:
       `spot["is_occupied"] = false` dan `spot["crop_data"] = null`.
     - Pancarkan sinyal:
       `spot_harvested.emit(plot_id, resolved_spot_id, items)`,
       `plot_nutrients_changed.emit(plot_id, plot["nutrients"])`,
       `plot_state_changed.emit(plot_id, _plots[plot_id])`,
       `action_success.emit("harvest", "Bayam berhasil dipanen.")`.

3. **Kesiapan Tanam Ulang Titik Tanam (Observation 1.1, 1.4):**
   - Berdasarkan `CONTENT.md` § 7: "Pembenah: Sekali untuk petak; tidak habis setelah panen" dan `PRD.md` FR11: "titik dapat ditanam ulang".
   - Setelah pemanenan, status petak `is_hoed` tetap `true` dan `has_compost` tetap `true`.
   - Titik tanam (`spot`) kembali kosong (`is_occupied = false`, `crop_data = null`).
   - Oleh karena itu, pemain dapat langsung memilih `tool_seed` (tombol 2) dan menanam benih bayam baru di titik tersebut tanpa perlu mencangkul ulang atau memberi pembenah ulang.
   - Catatan invarian: Jika pemanenan menyebabkan nutrisi petak turun di bawah ambang batas kesuburan (`nutrients < 20.0`), benih baru tetap dapat ditanam, namun kemajuan pertumbuhannya akan tertahan (stall) sampai pemain memupuk petak dengan `tool_fertilizer` (kembali ke 100.0).

4. **Integrasi Raycast Reticle Pemain dan Seleksi Kuadran (Observation 1.5):**
   - Petak pekarangan `plot_home_01` memiliki satu collider fisik `SoilBed` dan satu interactable `landmark_plot`.
   - Mengganti interactable menjadi 4 collider terpisah berisiko mematahkan tes yang sudah lulus (`test_interaction.gd`, `stress_hold_actions.gd`, dan pemeriksaan retargeting).
   - Solusi arsitektural yang konsisten adalah mempertahankan `landmark_plot` sebagai interactable utama, dan menggunakan perhitungan kuadran lokal `local_pt` (seperti yang telah terbukti di `PlayerController._handle_plant_seed_on_plot()`) untuk mendeteksi spot spesifik yang dibidik reticle.
   - Saat pemain membidik petak dengan tangan kosong / aksi interact:
     - `InteractionDetector` mendeteksi `landmark_plot`.
     - Reticle mengarahkan raycast ke titik tabrakan `hit_pt`.
     - Mengubah `hit_pt` ke `plot_node.to_local(hit_pt)` menghasilkan kuadran yang tepat (`slot_01`..`slot_04`).
     - HUD memformat prompt kontekstual:
       - Jika spot yang dibidik memiliki tanaman matang: `"[E] Panen Bayam"`.
       - Jika spot yang dibidik memiliki tanaman sedang tumbuh: `"[E] Periksa Petak (Bayam Tumbuh)"`.
       - Jika tanah belum siap: `"[E] Periksa Petak (Belum Digemburkan / Butuh Pembenah)"`.
       - Jika tanah siap dan kosong: `"[E] Periksa Petak (%s | %s)"`.
     - Saat tombol E ditekan, handler interaksi memanggil:
       - Jika tanaman matang di spot tersebut: `gm.harvest_crop("plot_home_01", spot_id)`.
       - Jika plot belum diberi pembenah: `gm.add_compost("plot_home_01")`.
       - Jika tidak ada aksi: membuka dialog/inspeksi petak.
     - Ini mematuhi aturan eksplisit `CONTENT.md` § 6: *"E memeriksa petak jika tidak ada aksi pembenah/panen yang lebih relevan."*

---

## 3. Caveats

1. **Pemisahan Modul**: Investigasi ini berfokus khusus pada mekanisme pemanenan atomik dan interaksi inventaris/player. Logika state machine pertumbuhan bayam (durasi 30s/60s/90s/180s, stall kelembapan/nutrisi) diinvestigasi oleh `explorer_gard_002_1`, sedangkan harness pengujian dan akselerasi waktu simulasi diinvestigasi oleh `explorer_gard_002_3`.
2. **Representasi Visual**: Transformasi mesh visual tanaman (dari benih -> tunas -> tanaman -> siap panen -> hilang setelah dipanen) dikelola melalui sinyal `plot_state_changed` dan `spot_harvested` di `level_graybox.gd` / `main.gd`.
3. **Alias ID Bahasa**: `CONTENT.md` menggunakan istilah `crop_bayam` dan `seed_bayam`, sedangkan prompt / user requests kadang menggunakan istilah bahasa Inggris `crop_spinach` dan `seed_spinach`. Pendaftaran alias di `items_data.gd` menjamin interoperabilitas total tanpa regresi.

---

## 4. Conclusion

1. **Spesifikasi Kontrak Pemanenan pada `GardenManager`**:
   - Tambahkan sinyal baru:
     ```gdscript
     signal spot_harvested(plot_id: String, spot_id: String, harvest_items: Array)
     ```
   - Tambahkan method pemeriksaan kapasitas & kesiapan:
     ```gdscript
     func can_harvest_crop(plot_id: String, spot_id: String) -> Dictionary
     ```
     Memeriksa: plot ada, spot ada, spot terisi, `crop_data` memiliki `growth_stage == 3` (atau `is_ready_to_harvest == true`), dan `inv.can_harvest() == true`. Mengembalikan `{"success": bool, "reason": String}`.
   - Tambahkan method eksekusi atomik (2-phase commit):
     ```gdscript
     func harvest_crop(plot_id: String, spot_id: String) -> bool
     ```
     - Jika `can_harvest_crop` gagal: panggil `action_failed.emit(check["reason"])` dan return `false`.
     - Jika berhasil:
       - Tambahkan 1 `ingredient_bayam` dan 1 `seed_bayam` ke tas pemain.
       - Potong nutrisi: `plot["nutrients"] = maxf(0.0, float(plot["nutrients"]) - 5.0)`.
       - Reset spot: `spot["is_occupied"] = false`, `spot["crop_data"] = null`.
       - Pancarkan `spot_harvested`, `plot_nutrients_changed`, `plot_state_changed`, dan `action_success`.
       - Return `true`.
   - Tambahkan alias fungsi:
     ```gdscript
     func harvest_spot(plot_id: String, spot_id: String) -> bool:
         return harvest_crop(plot_id, spot_id)
     ```

2. **Kesiapan Tanam Ulang (Replanting)**:
   - Titik tanam yang telah dipanen langsung berada dalam kondisi `is_occupied = false` dengan petak yang tetap `is_hoed = true` dan `has_compost = true`.
   - Pemain dapat langsung menanam benih kembali via `plant_seed()` tanpa perlu mengulang aksi cangkul atau pembenah.

3. **Integrasi Player Raycast & HUD Prompt**:
   - Di `GardenManager`, tambahkan helper pemetaan koordinat:
     ```gdscript
     func get_spot_id_from_local_coords(local_pt: Vector3) -> String:
         if local_pt.x < 0.0:
             return "slot_01" if local_pt.z < 0.0 else "slot_03"
         else:
             return "slot_02" if local_pt.z < 0.0 else "slot_04"
     ```
   - Di `main.gd`, mutakhirkan `_on_plot_interacted(player_node)`:
     - Ambil `hit_pt` dari `player_node.interaction_detector.get_collision_point()`.
     - Konversi ke `local_pt` pada `plot_node`.
     - Dapatkan `spot_id`.
     - Jika spot tersebut memiliki tanaman matang (`crop_data != null and crop_data.is_ready_to_harvest`):
       - Eksekusi `gm.harvest_crop("plot_home_01", spot_id)`.
     - Jika tidak, dan tanah butuh pembenah (`is_hoed and not has_compost`):
       - Eksekusi `gm.add_compost("plot_home_01")`.
   - Di `hud.gd`, perbarui `format_contextual_prompt` agar saat membidik kuadran dengan tanaman matang, prompt menampilkan `"[E] Panen Bayam"`.

4. **Pendaftaran Alias pada `items_data.gd`**:
   - Tambahkan pendaftaran alias:
     ```gdscript
     register_alias("crop_spinach", "ingredient_bayam")
     register_alias("seed_spinach", "seed_bayam")
     ```

---

## 5. Verification Method

Langkah-langkah pengujian independen untuk memverifikasi fungsionalitas pemanenan atomik:

1. **Uji Headless Test Runner Proyek**:
   ```powershell
   & "C:\Users\HP\.local\bin\godot.exe" --headless --path "c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia" -s tests/test_runner.gd
   ```
   *Kriteria lolos*: Seluruh 9 suite yang ada saat ini tetap lulus 100% tanpa regresi.

2. **Verifikasi Kasus Uji T05 (Penolakan Panen Saat Tas Penuh)**:
   - Siapkan petak dengan 1 tanaman bayam matang pada `slot_01` (`is_ready_to_harvest = true`, `nutrients = 100.0`).
   - Isi tas pemain (`backpack`) dengan 12 slot penuh (atau 11 slot penuh item lain tanpa tumpukan bayam/benih).
   - Panggil `gm.harvest_crop("plot_home_01", "slot_01")`.
   - *Verifikasi*:
     - Fungsi mengembalikan `false`.
     - Sinyal `action_failed` terpancar dengan pesan `"Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."`.
     - Tas tetap tidak bertambah item (0 item bayam/benih masuk).
     - Tanaman di `slot_01` tetap ada (`is_occupied == true`, `crop_data != null`).
     - Nutrisi petak tetap 100.0 (tidak berkurang 5).

3. **Verifikasi Kasus Uji T36 (Pemanenan Berhasil & Idempotensi Spam E)**:
   - Kosongkan tas pemain (12 slot kosong).
   - Panggil `gm.harvest_crop("plot_home_01", "slot_01")`.
   - *Verifikasi Pemanenan*:
     - Fungsi mengembalikan `true`.
     - Tas bertambah tepat 1 `ingredient_bayam` dan 1 `seed_bayam`.
     - Nutrisi petak berkurang dari 100.0 menjadi 95.0.
     - `slot_01` menjadi kosong (`is_occupied == false`, `crop_data == null`).
   - Panggil `gm.harvest_crop("plot_home_01", "slot_01")` untuk kedua kalinya (simulasi spam klik E):
     - Fungsi mengembalikan `false` ("Tidak ada tanaman di titik ini.").
     - Tas tidak bertambah lagi (tetap 1 bayam dan 1 benih).
     - Nutrisi petak tetap 95.0 (tidak berkurang lagi).
   - Tanam benih baru di `slot_01` via `gm.plant_seed("plot_home_01", "slot_01", "seed_bayam")`:
     - Fungsi mengembalikan `true`.
     - Benih baru berhasil tertanam tanpa memerlukan pencangkulan ulang (`is_hoed` sudah `true`).

4. **Kondisi Invalidasi (Invalidation Conditions)**:
   - Jika panen memutasi inventaris tas parsial (misal bayam masuk tapi benih gagal/hilang).
   - Jika panen mengurangi nutrisi petak saat inventaris tas penuh.
   - Jika spam E menghasilkan duplikasi item hasil panen.
   - Jika titik tanam yang baru dipanen menuntut pemain mencangkul ulang (`tool_hoe`) sebelum dapat ditanami benih baru.
