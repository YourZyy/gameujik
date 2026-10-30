# Laporan Investigasi Handoff: WORLD-001 (Foraging Nodes & Emergency Reserves)

**Tanggal:** 28 Oktober 2026  
**Penulis:** Explorer 1 (`explorer_world_001_1`)  
**Target Pembaca:** Orchestrator Gen 5 & Worker WORLD-001  
**Topik:** Analisis Node Foraging (`resource_jagung_01`, `resource_temu_kunci_01`), Titik Cadangan Darurat (`reserve_home` / `backup_seed_source`), Kalender & Istirahat (`bed_home`), serta Arsitektur Data `WorldResourceManager`.

---

## 1. Observation (Observasi Nyata)

Berdasarkan pemeriksaan langsung pada file proyek dan dokumen spesifikasi:

### A. Setup Node Foraging & Cadangan di `scenes/world/level_graybox.tscn`
1. **Jagung (`resource_jagung_01`)** — baris 748–771:
   - Posisi transform: `Vector3(22, 0, 28)`.
   - Child `CornStalks` (`StaticBody3D`): transform `(0, 0.9, 0)`, `BoxShape3D` ukuran `(1.5, 1.8, 1.5)` (Collision Layer 1 — Environment).
   - Child `Interactable` (`Area3D`): transform `(0, 0.9, 0)`, `BoxShape3D` ukuran `(1.5, 1.8, 1.5)`, Layer 3 (`collision_layer = 4`, `collision_mask = 0`), `monitoring = false`, `monitorable = true`.
   - Script interactable: `res://scripts/interaction/interactable.gd`.
   - Properti default: `interaction_id = "landmark_jagung"`, `target_name = "Jagung"`, `prompt_action = "Periksa"` (menghasilkan prompt `"[E] Periksa Jagung"` sesuai verifikasi `tests/suites/test_interaction.gd:251`).
2. **Temu Kunci (`resource_temu_kunci_01`)** — baris 801–828:
   - Posisi transform: `Vector3(-20, 0, 30)`.
   - Child `Rock` (`StaticBody3D`): transform `(0, 0.5, 0)`, `BoxShape3D` ukuran `(1.6, 1.0, 1.4)` (Layer 1).
   - Child `HerbMesh` (`MeshInstance3D`): transform `(0.6, 0.3, 0.5)`.
   - Child `Interactable` (`Area3D`): transform `(0, 0.5, 0)`, `BoxShape3D` ukuran `(1.6, 1.0, 1.4)`, Layer 3 (`collision_layer = 4`, `collision_mask = 0`).
   - Script interactable: `res://scripts/interaction/interactable.gd`.
   - Properti default: `interaction_id = "landmark_temu_kunci"`, `target_name = "Temu Kunci"`, `prompt_action = "Periksa"` (menghasilkan prompt `"[E] Periksa Temu Kunci"` sesuai `tests/suites/test_interaction.gd:252`).
3. **Cadangan Darurat (`reserve_home`)** — baris 687–710:
   - Posisi transform: `Vector3(7, 0, 4)` (dekat `container_starter` di `(6, 0, 4)`).
   - Child `ReserveCrate` (`StaticBody3D`): transform `(0, 0.3, 0)`, `BoxShape3D` ukuran `(0.8, 0.6, 0.8)`.
   - Child `Interactable` (`Area3D`): transform `(0, 0.3, 0)`, `BoxShape3D` ukuran `(0.8, 0.6, 0.8)`, Layer 3 (`collision_layer = 4`, `collision_mask = 0`).
   - Properti default: `interaction_id = "landmark_reserve"`, `target_name = "Cadangan"`, `prompt_action = "Periksa"` (menghasilkan prompt `"[E] Periksa Cadangan"`).
4. **Tempat Tidur (`bed_home`)** — baris 558–581:
   - Posisi transform: `Vector3(-2, 0, 0)`.
   - Child `Interactable` (`Area3D`): `interaction_id = "landmark_bed"`, `prompt_action = "Istirahat"` (prompt `"[E] Istirahat"`).
5. **Sumber Air (`water_home`)** — baris 637–661:
   - Posisi transform: `Vector3(4, 0, 9)`.
   - Child `Interactable` (`Area3D`): `interaction_id = "landmark_water"`, `target_name = "Air"`, `prompt_action = "Ambil"`.
   - Logika hold 2s dan refill sudah terpasang di `GardenManager:356-373` (`refill_water()`) dan `player_controller.gd:388-394`.

### B. Aturan Kontrak Dokumen (`CONTENT.md`, `TASKS.md`, `TEST_PLAN.md`)
1. **`docs/CONTENT.md` § 9 (Air, sumber bahan dan pemulihan):**
   - Jagung: `resource_jagung_01`, hasil 1 `ingredient_jagung` per panen.
   - Temu kunci: `resource_temu_kunci_01`, hasil 1 `ingredient_temu_kunci` per panen.
   - Reset sumber liar: *"Dapat dipanen sekali per hari simulasi; kembali setelah pergantian hari saat tidak dilihat."*
   - Kalender: Hari awal indeks 1, waktu aktif 0 detik. Satu hari prototipe = 720 detik simulasi aktif.
   - Istirahat: Di ranjang (`bed_home`), konfirmasi "Istirahat sampai besok"; pindah indeks hari berikutnya dan reset waktu aktif 0.
   - Invarian Istirahat: *"Istirahat adalah lompatan kalender untuk memulihkan sumber, TIDAK menyimulasikan 720 detik pertumbuhan/penguapan sekaligus. Kondisi petak dan kemajuan tanaman dipertahankan. Istirahat ditolak saat job dapur masih aktif."*
   - Cadangan benih: *"jika benih di tas + peti + pengembalian aman = 0 dan tidak ada tanaman hidup/siap panen, E pada cadangan menawarkan paket 4 benih. Tidak diberikan otomatis tanpa interaksi, dan tidak diberikan jika masih ada tanaman yang nanti menghasilkan benih."*
   - Cadangan pembenah: *"1 tersedia jika petak gembur tetapi belum diberi pembenah dan stok bebas/pengembalian = 0."*
   - Cadangan pupuk: *"1 tersedia jika nutrisi <20 dan stok bebas/pengembalian = 0."*
   - Gate cadangan: *"Isi awal yang belum diambil tidak dihitung sebagai stok milik pemain, tetapi prompt mengarahkan mengambil wadah awal dahulu. Cadangan baru aktif setelah wadah awal diambil."*
2. **`docs/TEST_PLAN.md`:**
   - **T09**: *"Fixture: benih habis, tidak ada tanaman, wadah awal sudah diambil; periksa cadangan -> Paket cadangan tersedia jika muat; mengambil sekali menghilangkan syarat pengambilan berikutnya."*
   - **T37**: *"Ambil jagung/temu kunci; ulang sebelum pergantian hari; istirahat -> Tidak ada hasil kedua hari sama; sumber pulih hari berikutnya secara terjelaskan."*
   - **T38**: *"Masih ada benih di peti/tanaman hidup; minta cadangan -> Tidak memberi benih cadangan; lokasi stok/kemungkinan panen dijelaskan."*
   - **T39**: *"Catat petak, waktu/hari dan sumber; istirahat; ulang saat job aktif -> Hari maju dan sumber pulih, petak tidak ditick satu hari sekaligus; istirahat ditolak bila job aktif."*
3. **`docs/CONTENT.md` § 11 (Pesan Umpan Balik):**
   - Tas penuh: `"Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."`

### C. Keadaan Kode Eksisting
1. **Autoload di `project.godot`:**
   - Saat ini terdaftar: `InputManager`, `InventoryManager`, `RecipeManager`, `GardenManager`.
   - `WorldResourceManager` belum dibuat dan belum didaftarkan di autoload.
2. **`scripts/inventory/inventory_manager.gd`:**
   - Menyediakan `backpack` (12 slot), `storage_home` (12 slot), `kitchen_refund` (12 slot).
   - `get_available_item_count(item_id: String) -> int` menghitung stok bebas di tas + peti dikurangi reservasi memasak.
   - `starter_claimed` (boolean) melacak apakah wadah starter telah diambil (`is_starter_collected() -> bool`).
   - `can_accept_items("backpack", batch)` dan `backpack.can_add(item_id, count)` memvalidasi kapasitas tanpa mutasi parsial.
3. **`scripts/gardening/garden_manager.gd`:**
   - Menyediakan `get_plot(plot_id: String) -> Dictionary`.
   - Struktur spot di petak: `spots["slot_01".."slot_04"]` dengan field `is_occupied: bool` dan `crop_data: Dictionary`.
   - Menyediakan status `nutrients` dan `has_compost`, serta `refill_water()`.
4. **`scripts/ui/hud.gd`:**
   - Fungsi `show_feedback(message: String, duration: float = 2.5)` menampilkan banner umpan balik 2.5s di prompt panel saat terjadi kegagalan aksi (baris 264–273).
   - Terkoneksi ke `GardenManager.action_failed`.
5. **`scripts/main.gd`:**
   - Titik sentral wiring landmark di dunia graybox (`_wire_inventory_and_landmarks()`).
   - Saat ini sudah menghubungkan `container_starter`, `storage_home`, `book_family`, `note_garden_01`, dan `plot_home_01`.

---

## 2. Logic Chain (Rantai Penalaran)

1. **Foraging Node Mechanics:**
   - Dari observasi A.1 & A.2, node `resource_jagung_01` dan `resource_temu_kunci_01` sudah memiliki collision fisik (Layer 1) dan Area3D interactable (Layer 3) dengan ID landmark yang stabil.
   - Dari observasi B.1 & B.2 (T37), setiap node menghasilkan tepat 1 unit item per hari. Agar pemain tidak bisa mengambil berulang pada hari yang sama, sistem membutuhkan pencatatan state `last_harvested_day` per node ID.
   - Jika `last_harvested_day == current_day`, percobaan interaksi harus ditolak secara jujur dengan pesan: `"Sumber daya sudah diambil hari ini. Tunggu besok."`
   - Transaksi atomik: Sebelum item ditambahkan ke tas dan sebelum `last_harvested_day` dimutasi, `InventoryManager.backpack.can_add(item_id, 1)` harus diperiksa. Jika tas penuh (12 slot terisi dan tumpukan item terkait sudah penuh/tidak ada slot kosong), transaksi dibatalkan sepenuhnya: item tidak diberikan, jatah hari tidak berkurang, dan umpan balik `"Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."` ditampilkan.

2. **Emergency Reserve Mechanics (`reserve_home`):**
   - Dari observasi A.3 dan B.1 (CONTENT § 9), `reserve_home` adalah peti cadangan kontekstual yang baru aktif jika `starter_claimed == true`.
   - Jika `starter_claimed == false`, pemain belum mengambil paket starter di dekat alat. Maka interaksi harus ditolak dengan pesan: `"Ambil wadah awal dekat alat terlebih dahulu."`
   - Jika `starter_claimed == true`, evaluasi kebutuhan darurat dijalankan:
     - **Pemeriksaan Benih:** Cek `InventoryManager.get_available_item_count("seed_bayam")`. Jika > 0, tolak dan jelaskan lokasinya (di tas atau di peti rumah). Cek juga seluruh 4 spot pada `plot_home_01` via `GardenManager.get_plot()`. Jika ada spot yang `is_occupied == true`, pemain masih memiliki tanaman bayam yang akan menghasilkan benih saat dipanen; tolak dengan pesan `"Tanaman bayam sedang tumbuh di petak. Panen saat matang untuk mendapatkan benih."`
     - Jika benih = 0 dan tidak ada tanaman di petak, syarat cadangan benih terpenuhi! Periksa kapasitas tas untuk 4 `seed_bayam`. Jika muat, berikan 4 benih.
     - **Pemeriksaan Pembenah:** Jika tanah sudah digemburkan (`is_hoed == true`) tetapi belum berkompos (`has_compost == false`), dan stok `soil_compost` di tas + peti = 0, berikan 1 `soil_compost`.
     - **Pemeriksaan Pupuk:** Jika nutrisi petak `< 20.0` dan stok `fertilizer_basic` di tas + peti = 0, berikan 1 `fertilizer_basic`.
     - Jika semua stok/kebutuhan pemain aman (tidak ada kondisi darurat), tolak interaksi dengan pesan jujur: `"Kondisi cadangan belum terpenuhi. Pasokan darurat hanya tersedia jika kehabisan bahan."`

3. **Calendar & Sleep Mechanics (`bed_home`):**
   - Dari observasi B.1 & B.2 (T39), siklus harian berjalan 720.0 detik simulasi aktif.
   - Tidur di `bed_home` memajukan hari: `current_day += 1`, `day_time_seconds = 0.0`.
   - Saat hari berganti, seluruh node foraging otomatis pulih karena perbandingan `last_harvested_day < current_day` bernilai `true`.
   - **Invarian Kritis Pertumbuhan Tanaman:** Berdasarkan CONTENT § 9, istirahat adalah lompatan kalender untuk memulihkan sumber daya liar, dan **TIDAK BOLEH** mensimulasikan 720 detik pertumbuhan tanaman atau penguapan air petak! Kelembapan, nutrisi, dan timer pertumbuhan tanaman di `GardenManager` harus dipertahankan tanpa perubahan.
   - **Invarian Dapur:** Jika job memasak di dapur sedang aktif, istirahat harus ditolak: `"Tidak bisa istirahat saat memasak sedang berlangsung."`

4. **Arsitektur Pemisahan Tanggung Jawab:**
   - Dibuat autoload singleton baru: `WorldResourceManager` (`scripts/world/world_resource_manager.gd`).
   - Autoload ini mengisolasi state dunia (hari, timer kalender, foraging nodes, cadangan darurat) sehingga tidak mencemari `InventoryManager` atau `GardenManager`.
   - `scripts/main.gd` menghubungkan sinyal `interacted` dari masing-masing landmark ke `WorldResourceManager`.
   - Sinyal `action_failed` dan `action_success` dari `WorldResourceManager` disambungkan ke `hud.show_feedback()` untuk menampilkan notifikasi 2.5 detik.

---

## 3. Caveats (Batasan & Asumsi)

1. **Visual Model Foraging Saat Dipanen:**
   - Graybox saat ini menggunakan primitive mesh (`BoxMesh`). Saat panen, mesh jagung/temu kunci dapat disembunyikan (`visible = false`) atau diganti materialnya menjadi redup. Saat hari berganti, mesh ditampilkan kembali.
2. **Pilihan Panen Cadangan Ganda:**
   - Jika pemain mengalami kondisi kehabisan benih sekaligus kehabisan pupuk, sistem memprioritaskan paket yang paling mendesak (misal benih terlebih dahulu) atau memberikan item yang dibutuhkan sesuai kapasitas tas.
3. **Konfirmasi Tidur (Dialog vs Aksi Langsung):**
   - Pada P0 tanpa sistem dialog kompleks untuk kasur, menekan `E` pada `bed_home` langsung mengeksekusi istirahat (dengan efek transisi visual/layar singkat atau instan untuk uji headless), kecuali jika job dapur sedang aktif.

---

## 4. Conclusion (Kesimpulan & Rekomendasi Arsitektur)

Untuk menyelesaikan milestone **WORLD-001**, Worker direkomendasikan mengimplementasikan arsitektur berikut:

### A. Modul Baru yang Dibuat
1. **`scripts/world/world_resource_manager.gd` (Autoload `WorldResourceManager`):**
   - **State Fields:**
     - `current_day: int = 1`
     - `day_time_seconds: float = 0.0`
     - `DAY_DURATION_SECONDS: float = 720.0`
     - `foraging_nodes: Dictionary = { "resource_jagung_01": {"item_id": "ingredient_jagung", "last_harvested_day": 0}, "resource_temu_kunci_01": {"item_id": "ingredient_temu_kunci", "last_harvested_day": 0} }`
   - **Sinyal-Sinyal:**
     - `day_advanced(new_day: int)`
     - `calendar_ticked(current_day: int, day_time_seconds: float)`
     - `foraging_node_harvested(node_id: String, item_id: String, count: int)`
     - `foraging_state_changed(node_id: String, is_available: bool)`
     - `emergency_reserve_claimed(reserve_type: String, items: Array)`
     - `action_failed(reason: String)`
     - `action_success(action_name: String, message: String)`
   - **Method Publik:**
     - `can_harvest_foraging_node(node_id: String) -> Dictionary`
     - `harvest_foraging_node(node_id: String) -> bool`
     - `is_foraging_node_available(node_id: String) -> bool`
     - `can_claim_emergency_reserve() -> Dictionary`
     - `claim_emergency_reserve() -> bool`
     - `can_sleep() -> Dictionary`
     - `sleep_and_advance_day() -> bool`
     - `advance_day() -> void`
     - `get_save_snapshot() -> Dictionary` & `load_save_snapshot(data: Dictionary) -> bool`

### B. Modifikasi File Eksisting
1. **`project.godot`:**
   - Daftarkan autoload: `WorldResourceManager="*res://scripts/world/world_resource_manager.gd"`.
2. **`scripts/main.gd`:**
   - Di `_wire_inventory_and_landmarks()`:
     - Hubungkan `resource_jagung_01/Interactable.interacted` ke `WorldResourceManager.harvest_foraging_node("resource_jagung_01")`.
     - Hubungkan `resource_temu_kunci_01/Interactable.interacted` ke `WorldResourceManager.harvest_foraging_node("resource_temu_kunci_01")`.
     - Hubungkan `reserve_home/Interactable.interacted` ke `WorldResourceManager.claim_emergency_reserve()`.
     - Hubungkan `bed_home/Interactable.interacted` ke `WorldResourceManager.sleep_and_advance_day()`.
     - Hubungkan sinyal `foraging_state_changed` untuk memperbarui visual mesh node di dunia.
     - Hubungkan `WorldResourceManager.action_failed` dan `action_success` ke `hud.show_feedback()`.
3. **`scripts/ui/hud.gd`:**
   - Tambahkan pemformatan prompt kontekstual reticle di `format_contextual_prompt()`:
     - `landmark_jagung`: Menampilkan `[E] Petik Jagung` jika tersedia, atau `[E] Jagung (Sudah Dipanen)` jika sudah diambil hari ini.
     - `landmark_temu_kunci`: Menampilkan `[E] Petik Temu Kunci` jika tersedia, atau `[E] Temu Kunci (Sudah Dipanen)` jika sudah diambil hari ini.
     - `landmark_reserve`: Menampilkan `[E] Periksa Cadangan`.
     - `landmark_bed`: Menampilkan `[E] Istirahat Sampai Besok`.
4. **`tests/test_runner.gd` & `tests/suites/test_world_resources.gd`:**
   - Buat test suite baru `TestWorldResources` yang memverifikasi kasus uji T09, T37, T38, dan T39 secara komprehensif.

---

## 5. Verification Method (Metode Verifikasi Mandiri)

Langkah pengujian independen untuk memvalidasi keberhasilan implementasi WORLD-001:

1. **Uji Suite Otomatis via Headless Godot:**
   ```powershell
   godot_console.exe --headless -s tests/test_runner.gd
   ```
   *Ekspektasi:* Seluruh test setup, level, player, interaction, inventory, recipe, gardening, serta test suite baru `TestWorldResources` lulus 100% dengan exit code 0.

2. **Verifikasi Kasus Uji Spesifik:**
   - **T37 (Panen Jagung & Temu Kunci 1x/Hari):**
     1. Ambil jagung -> verifikasi tas mendapat 1 `ingredient_jagung`.
     2. Coba ambil lagi pada hari yang sama -> ditolak, tidak ada jagung kedua.
     3. Istirahat di `bed_home` (hari 1 -> hari 2) -> node jagung pulih dan dapat dipetik kembali tepat 1 unit.
   - **T05/Atomisitas (Penolakan Tas Penuh):**
     1. Penuhi tas (12 slot penuh dengan barang selain jagung).
     2. Coba petik jagung -> ditolak dengan pesan `"Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."`
     3. Jatah panen harian tetap utuh (`is_available == true`). Kosongkan 1 slot -> panen berhasil.
   - **T38 (Penolakan Cadangan saat Masih Ada Stok/Tanaman):**
     1. Coba ambil cadangan saat ada benih di peti -> ditolak dengan penjelasan lokasi stok.
     2. Coba ambil cadangan saat ada tanaman tumbuh di petak -> ditolak dengan pesan tanaman sedang tumbuh.
   - **T09 (Ketersediaan Cadangan Darurat):**
     1. Kosongkan benih di tas, peti, refund, dan pastikan tidak ada tanaman hidup di petak. Wadah starter sudah diambil.
     2. Periksa cadangan -> paket 4 benih bayam berhasil diberikan.
     3. Percobaan kedua langsung ditolak karena pemain kini memiliki 4 benih.
   - **T39 (Invarian Istirahat & Kalender):**
     1. Catat kelembapan petak (misal 50.0) dan waktu pertumbuhan tanaman (misal 45.0 detik).
     2. Istirahat di `bed_home` -> hari bertambah menjadi 2.
     3. Verifikasi kelembapan petak tetap 50.0 dan pertumbuhan tanaman tetap 45.0 detik (tidak melompat 720 detik).

3. **Kondisi Invalidasi (Kegagalan Kriteria):**
   - Sumber daya liar dapat dipetik lebih dari 1 kali pada hari yang sama.
   - Cadangan darurat dapat diambil padahal pemain masih memiliki benih atau tanaman hidup.
   - Istirahat mempercepat penguapan petak atau pertumbuhan tanaman sebesar 720 detik.
   - Transaksi panen mengonsumsi jatah harian saat tas pemain penuh.
