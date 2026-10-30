# Analisis & Spesifikasi Rancang Bangun Test Suite Penerimaan SAVE-001 (`tests/suites/test_save.gd`)

**Versi Dokumen:** 1.0  
**Tanggal:** 29 Oktober 2026  
**Pelaksana:** Explorer Agent (`explorer_save_001_3` - Save Acceptance Test Explorer)  
**Milestone:** `SAVE-001` (Persistensi Lengkap Save/Load, Checkpoint, Validasi Envelope, Snapshot Swap, dan Error Recovery)  
**Target File Suite:** `res://tests/suites/test_save.gd`  
**Target Runner:** `res://tests/test_runner.gd` (Pendaftaran sebagai Suite 19)  
**Mode Investigasi:** Read-Only Analysis & Test Architecture Design  

---

## 1. Ringkasan Eksekutif & Batasan Masalah

Sistem persistensi pada game *Buku Resep 2045* merupakan pilar keandalan lintas sesi (PRD FR15, CONTENT.md § 12, PROTOTYPE.md § 7, dan TASKS.md § SAVE-001). Berdasarkan mandat pengujian penerimaan sistem save/load, test suite otomatis `tests/suites/test_save.gd` dirancang untuk memverifikasi 9 kasus uji inti:
1. **T14:** Preservasi tas (12 slot), peti (12 slot), cadangan kontekstual, alat, dan job memasak dijeda tanpa progress offline.
2. **T16:** Validasi pra-swap dunia (menolak snapshot rusak, malformed, atau parsial tanpa menyentuh status dunia aktif).
3. **T17:** Ketahanan berkas korup (fallback otomatis ke cadangan `.bak` jika berkas utama korup, penolakan bersih bila keduanya korup).
4. **T22:** Validasi posisi pemain (deteksi koordinat non-finite `NaN`/`Inf` atau out-of-bounds, redirect aman ke `safe_return_home` `(0, 0, 8)` atau `spawn_home` `(0, 0, 1)` tanpa menghilangkan progres/item).
5. **T46:** Pemulihan status dinamis kebun (4 tahap bayam, kelembapan, nutrisi) dan dapur (job ID, reservasi, origin manifest, kontainer refund, output slot).
6. **T47:** Uji ketahanan crash penulisan atomik via `.tmp` -> `.bak` -> final file replacement.
7. **T48:** Manajemen slot manual, autosave, cadangan per slot, dan evaluasi tombol "Lanjutkan" berbasis revisi/timestamp terbaru.
8. **T49:** Isolasi total `user://settings.cfg` dari data save game (pengaturan sensitivitas/FOV/audio tidak ditimpa oleh load game atau new game).
9. **T50:** Pengujian round-trip 100% identik (invarian konservasi data, idempotensi muat ulang multi-siklus).

Dokumen ini menyajikan arsitektur lengkap, rancangan isolasi sandbox, blueprint kode GDScript komprehensif siap pakai untuk `tests/suites/test_save.gd`, serta rencana pendaftarannya di `tests/test_runner.gd`.

---

## 2. Arsitektur Suite & Strategi Sandboxing Uji

### 2.1 Identitas dan Struktur Kelas
- **Nama File:** `res://tests/suites/test_save.gd`
- **Class Name:** `class_name TestSave`
- **Turunan:** `extends RefCounted`
- **Dependensi Utama:**
  - `Assertions` (`res://tests/assertions.gd`)
  - `SaveManagerClass` (`res://scripts/save/save_manager.gd`)
  - `InventoryManagerClass` (`res://scripts/inventory/inventory_manager.gd`)
  - `RecipeManagerClass` (`res://scripts/recipe/recipe_manager.gd`)
  - `GardenManagerClass` (`res://scripts/gardening/garden_manager.gd`)
  - `WorldResourceManagerClass` (`res://scripts/world/world_resource_manager.gd`)
  - `KitchenManagerClass` (`res://scripts/cooking/kitchen_manager.gd`)
  - `DialogueManagerClass` (`res://scripts/social/dialogue_manager.gd`)
  - `PlayerControllerClass` (`res://scripts/player/player_controller.gd`)
  - `PlayerConfigClass` (`res://scripts/player/player_config.gd`)
  - `LevelGrayboxClass` (`res://scripts/world/level_graybox.gd`)

### 2.2 Isolasi Sandbox Lingkungan Uji (`user://test_save_sandbox/`)
Agar pelaksanaan suite uji tidak merusak data simpan riil pemain di `user://saves/` atau pengaturan riil di `user://settings.cfg`, test suite wajib beroperasi dalam direktori sandbox terisolasi:
- **Sandbox Root:** `user://test_save_sandbox/`
- **Sandbox Saves:** `user://test_save_sandbox/saves/`
- **Sandbox Settings:** `user://test_save_sandbox/settings.cfg`

```gdscript
const SANDBOX_DIR: String = "user://test_save_sandbox/"
const SANDBOX_SAVES_DIR: String = "user://test_save_sandbox/saves/"
const SANDBOX_SETTINGS_PATH: String = "user://test_save_sandbox/settings.cfg"
```

### 2.3 Siklus Hidup Sandbox (Setup & Teardown)
Setiap awal dan akhir suite uji, sandbox dibersihkan secara rekursif:
1. `_clean_directory(dir_path: String)`: Menghapus seluruh file `.tmp`, `.json`, `.bak`, `.cfg`.
2. `_ensure_directory(dir_path: String)`: Memastikan direktori target tersedia melalui `DirAccess.make_dir_recursive_absolute()`.
3. Injeksi path sandbox ke instance `SaveManager` selama pengujian menggunakan setter `sm.set_save_directory(SANDBOX_SAVES_DIR)` dan `sm.set_settings_path(SANDBOX_SETTINGS_PATH)`.

---

## 3. Spesifikasi Rinci Kasus Uji Penerimaan

Berikut adalah spesifikasi per kasus uji yang dirancang untuk diimplementasikan ke dalam `tests/suites/test_save.gd`.

### 3.1 Grup 1: T14 — Preservasi Tas, Peti, Alat, dan Job Dijeda (Tanpa Progress Offline)

#### Kasus Uji `test_t14_01_backpack_storage_and_tools_preservation()`
- **Tujuan:** Memverifikasi seluruh isi 12 slot tas, 12 slot peti penyimpanan rumah, status wadah awal (`starter_claimed`), dan level alat (penyiram air) tersimpan dan pulih secara presisi.
- **Fixture Setup:**
  - Tas terisi 4 slot: `seed_bayam` (x3), `soil_compost` (x1), `fertilizer_basic` (x2), `ingredient_jagung` (x1).
  - Peti terisi 2 slot: `ingredient_temu_kunci` (x1), `ingredient_bayam` (x6).
  - Kontainer refund terisi: `seed_bayam` (x1).
  - Status `starter_claimed = true`.
  - Alat aktif `tool_watering_can`, isi air `watering_can_water = 7` (dari kapasitas 10).
- **Aksi:**
  1. Serialisasi save manual snapshot.
  2. Reset seluruh manajer ke kondisi awal kosong.
  3. Deserialisasi/muat snapshot.
- **Asersi Expected:**
  - Jumlah item dan indeks slot tas identik 100%.
  - Jumlah item dan indeks slot peti identik 100%.
  - Refund container berisi tepat `seed_bayam` x1.
  - `starter_claimed == true`.
  - `watering_can_water == 7` dan `active_tool == "tool_watering_can"`.

#### Kasus Uji `test_t14_02_paused_job_and_crop_growth_preservation_no_offline_progress()`
- **Tujuan:** Memverifikasi bahwa tanaman yang sedang tumbuh dan job memasak aktif disimpan sebagai `PAUSED` dan tidak bertambah waktu saat game ditutup (PROTOTYPE § 5, § 7).
- **Fixture Setup:**
  - Petak pekarangan: `gembur = true`, `pembenah = true`, `moisture = 65.0`, `nutrients = 80.0`.
  - Spot tanam 1: `seed_bayam`, `growth_timer = 45.0` detik (tahap kecambah).
  - Dapur aktif: job ID `"job_t14_test"`, recipe `"recipe_sayur_bening_01"`, `job_state = COOKING`, `cook_progress = 12.5` detik, `current_heat_level = 2` (Sedang).
  - Bahan tereservasi: 3 bayam, 1 jagung, 1 temu kunci tercatat di `origin_manifest`.
- **Aksi:**
  1. Buat save game. Simulasikan penundaan waktu sistem nyata (misal `OS.delay_msec(200)` atau modifikasi clock simulasi).
  2. Muat kembali game dari save.
- **Asersi Expected:**
  - Status job memasak terpulihkan sebagai `job_state == JobState.PAUSED` (bukan advancing).
  - `cook_progress` tetap tepat `12.5` detik (+/- 0.001 tolerance), tidak maju offline.
  - `growth_timer` spot 1 tetap tepat `45.0` detik, `moisture` tetap `65.0`, tidak terjadi penguapan atau pertumbuhan offline.
  - Reservasi bahan dan origin manifest utuh.

---

### 3.2 Grup 2: T16 — Validasi Sebelum Swap Dunia & Penolakan Snapshot Rusak

#### Kasus Uji `test_t16_01_reject_snapshot_with_missing_mandatory_sections()`
- **Tujuan:** Memverifikasi bahwa SaveManager memvalidasi kelengkapan seluruh seksi payload (`player`, `inventory`, `garden`, `kitchen`, `world`, `recipe`, `dialogue`) sebelum melakukan mutasi terhadap state aktif manajer manapun.
- **Fixture Setup:**
  - Snapshot envelope v1 valid diubah dengan menghapus salah satu kunci wajib secara bergantian:
    - Kunci hilang: `version`
    - Kunci hilang: `inventory`
    - Kunci hilang: `garden`
    - Kunci hilang: `kitchen`
    - Kunci hilang: `world`
    - Kunci hilang: `player`
- **Aksi:**
  1. Catat state manajer live saat ini (baseline).
  2. Panggil `sm.load_save_data(broken_snapshot)`.
- **Asersi Expected:**
  - `load_save_data()` mengembalikan `false`.
  - Log peringatan/error terekam.
  - State live manajer TIDAK BERUBAH sedikit pun (invarian zero-side-effect).

#### Kasus Uji `test_t16_02_reject_snapshot_with_unknown_item_ids_and_illegal_counts()`
- **Tujuan:** Menolak snapshot yang mengandung ID item fiktif/tidak terdaftar atau kuantitas ilegal (negatif, atau melebihi batas 20 per slot per CONTENT § 2).
- **Skenario Uji:**
  1. Item ID `"item_super_laser"` pada slot tas.
  2. Kuantitas `-5` pada slot bayam.
  3. Kuantitas `99` (melebihi `MAX_STACK_SIZE = 20`) pada slot jagung.
- **Asersi Expected:**
  - Validasi schema menolak muat sebelum menyentuh `InventoryManager`.
  - Inventaris live tetap pada kondisi sebelum pemanggilan.

#### Kasus Uji `test_t16_03_atomic_world_swap_all_or_nothing()`
- **Tujuan:** Memastikan penukaran dunia bersifat atomik *all-or-nothing*. Jika manajer terakhir (misal `dialogue`) gagal dalam deserialisasi, pembaruan manajer-manajer sebelumnya (`inventory`, `garden`) tidak boleh diterapkan ke live game.
- **Aksi:**
  1. Siapkan snapshot yang valid untuk Inventory, Garden, Kitchen, World, Recipe, tetapi bagian `dialogue` dirusak tipe datanya sehingga `load_save_snapshot` internal gagal.
  2. Lakukan proses muat.
- **Asersi Expected:**
  - Proses muat mengembalikan `false`.
  - Live inventory dan live garden tidak termutasi (menggunakan pementasan data / staging sebelum swap).

---

### 3.3 Grup 3: T17 — Ketahanan Berkas Korup & Fallback Cadangan (.bak)

#### Kasus Uji `test_t17_01_fallback_to_bak_when_primary_save_file_corrupted()`
- **Tujuan:** Memverifikasi ketahanan terhadap berkas utama yang terpotong/rusak, dengan pemulihan otomatis dari berkas `.bak` yang valid (TEST_PLAN T17, PROTOTYPE § 7).
- **Langkah & Setup:**
  1. Simpan checkpoint valid revisi 1 ke berkas cadangan `slot_manual.json.bak` dengan data progres (misal `current_day = 2`, `meal_used = true`).
  2. Tulis byte korup ke berkas utama `slot_manual.json` (misal string terpotong `{"version": 1, "payload": {"inventory": { broken json...`).
  3. Panggil `sm.load_game("slot_manual")`.
- **Asersi Expected:**
  - Fungsi muat berhasil (`true`).
  - Data yang dipulihkan berasal dari `slot_manual.json.bak` (`current_day == 2`, `meal_used == true`).
  - Sistem mencatat log peringatan bahwa berkas utama korup dan fallback ke cadangan berhasil dilakukan.

#### Kasus Uji `test_t17_02_clean_failure_when_both_primary_and_bak_are_corrupted()`
- **Tujuan:** Menangani kondisi ekstrem ketika berkas utama dan berkas `.bak` sama-sama rusak.
- **Langkah & Setup:**
  1. Tulis string sampah biner/karakter rusak ke `slot_manual.json` dan `slot_manual.json.bak`.
  2. Panggil `sm.load_game("slot_manual")`.
- **Asersi Expected:**
  - Fungsi muat mengembalikan `false` secara bersih tanpa crash engine.
  - Pesan error jujur tersedia: *"Data simpan tidak cocok dengan versi ini. Pilih cadangan yang tersedia."* (CONTENT § 11).
  - Tidak ada data parsial atau "setengah dunia" yang dimuat (PROTOTYPE § 7).

#### Kasus Uji `test_t17_03_zero_byte_file_resilience()`
- **Tujuan:** Memverifikasi bahwa berkas 0-byte (akibat pemutusan daya instan sebelum OS flush) ditolak dengan aman tanpa menyebabkan exception atau hang pada parser JSON.
- **Asersi Expected:**
  - Berkas 0-byte memicu fallback ke `.bak` atau ditolak bersih bila `.bak` tidak ada.

---

### 3.4 Grup 4: T22 — Validasi Posisi Pemain & Safe Spawn Redirection

#### Kasus Uji `test_t22_01_redirect_nan_and_inf_coordinates_to_safe_spawn()`
- **Tujuan:** Memverifikasi bahwa koordinat posisi pemain yang bernilai `NaN` (Not a Number), `Infinity`, atau `-Infinity` dideteksi oleh validator posisi dan diarahkan kembali ke titik pemulihan aman tanpa menghilangkan progres/item pemain.
- **Fixture Setup:**
  - Snapshot valid dengan posisi pemain diubah:
    - Varian A: `Vector3(NAN, 0.0, 1.0)`
    - Varian B: `Vector3(0.0, INF, 0.0)`
    - Varian C: `Vector3(0.0, 0.0, -INF)`
- **Aksi:**
  1. Muat snapshot dengan data koordinat non-finite tersebut.
- **Asersi Expected:**
  - Fungsi muat berhasil (`true`).
  - Posisi pemain diarahkan ke `PlayerConfig.DEFAULT_SAFE_RETURN_POSITION` (`Vector3(0, 0, 8)`) atau `DEFAULT_SPAWN_POSITION` (`Vector3(0, 0, 1)`).
  - Kecepatan pemain di-reset ke `Vector3.ZERO`.
  - Rotasi pitch di-reset ke `0.0`.
  - Seluruh item inventaris dan progres game tetap utuh 100%.

#### Kasus Uji `test_t22_02_redirect_out_of_bounds_coordinates_to_safe_spawn()`
- **Tujuan:** Memverifikasi penanganan posisi di luar batas amplop level (`X [-42..42]`, `Z [-37..47]`, atau `Y < -5.0` per LEVEL_DESIGN § 2 & `level_graybox.gd`).
- **Fixture Setup:**
  - Posisi pemain di-set ke:
    - Di bawah jurang: `Vector3(0.0, -100.0, 0.0)`
    - Di luar batas timur/utara: `Vector3(300.0, 0.0, 500.0)`
- **Aksi:**
  1. Muat snapshot.
- **Asersi Expected:**
  - Posisi pemain terdeteksi *out-of-bounds*.
  - Posisi dipulihkan ke `safe_return_home` `(Vector3(0, 0, 8))`.
  - Item dan resep tidak berkurang.

#### Kasus Uji `test_t22_03_valid_coordinates_preserved_without_redirection()`
- **Tujuan:** Memastikan koordinat valid di dalam batas level tidak salah dideteksi sebagai out-of-bounds.
- **Fixture:** Posisi `Vector3(8.0, 0.0, 7.0)` (di dekat petak kebun).
- **Asersi Expected:**
  - Posisi pemain tetap persis `Vector3(8.0, 0.0, 7.0)` (+/- 0.01 tolerance), tidak terjadi teleportasi/redirection.

---

### 3.5 Grup 5: T46 — Pemulihan Status Dinamis Kebun dan Dapur

#### Kasus Uji `test_t46_01_garden_plot_and_crop_stages_restoration()`
- **Tujuan:** Memverifikasi pemulihan komprehensif struktur petak pekarangan dan keempat titik tanam yang berada pada fase berbeda-beda.
- **Fixture Setup:**
  - Plot: `gembur = true`, `pembenah = true`, `moisture = 52.3`, `nutrients = 77.8`.
  - Spot 0: Kosong (`plant_id = ""`, `growth_stage = 0`).
  - Spot 1: Benih bayam tahap 0 (`growth_timer = 15.0`).
  - Spot 2: Kecambah bayam tahap 1 (`growth_timer = 50.0`).
  - Spot 3: Tanaman siap panen tahap 3 (`growth_timer = 180.0`, `ready_for_harvest = true`).
- **Aksi:**
  1. Serialisasi save -> Reset kebun -> Deserialisasi save.
- **Asersi Expected:**
  - Status petak (`gembur`, `pembenah`, `moisture`, `nutrients`) pulih identik.
  - Spot 0, 1, 2, dan 3 mempertahankan tahap dan timer masing-masing. Spot 3 dapat dipanen seketika pasca-load.

#### Kasus Uji `test_t46_02_kitchen_job_reservation_origin_and_refund_restoration()`
- **Tujuan:** Memverifikasi pemulihan status dapur aktif: reservasi bahan, mapping slot asal (`origin_manifest`), progress masak, tingkat panas, slot hasil masakan, dan kontainer pengembalian aman (`kitchen_refund`).
- **Fixture Setup:**
  - `job_state = JobState.COOKING` (disimpan menjadi `PAUSED`).
  - `active_job_id = "job_save_acceptance_001"`.
  - `active_recipe_id = "recipe_sayur_bening_01"`.
  - `cook_progress = 22.4`, `current_heat_level = 2` (Sedang).
  - `reserved_ingredients = [{"item_id": "ingredient_bayam", "count": 3}, ...]`
  - `origin_manifest = [{"source": "backpack", "slot_index": 0, "count": 3}, ...]`
  - `dish_output_slot = {"item_id": "dish_sayur_bening", "count": 1}`
  - `kitchen_refund = [{"item_id": "ingredient_jagung", "count": 1}]`
- **Aksi:**
  1. Serialisasi save -> Reset dapur -> Deserialisasi save.
- **Asersi Expected:**
  - Status dapur pulih 100%.
  - `dish_output_slot` mempertahankan 1 porsi hidangan.
  - `kitchen_refund` mempertahankan 1 jagung.
  - Reservasi bahan dan origin manifest utuh untuk pembatalan/pengembalian aman.

---

### 3.6 Grup 6: T47 — Uji Ketahanan Crash Penulisan Atomik via `.tmp`

#### Kasus Uji `test_t47_01_atomic_write_creates_tmp_before_target()`
- **Tujuan:** Memverifikasi bahwa SaveManager menulis ke berkas sementara `.tmp` terlebih dahulu, memanggil flush/close, baru melakukan replace/rename ke berkas target utama (skills/save-systems Pattern #2).
- **Langkah & Setup:**
  1. Pantau sistem berkas sebelum dan sesudah `sm.save_game("slot_manual")`.
  2. Verifikasi urutan operasi:
     - Berkas `.tmp` dibuat saat penulisan.
     - Setelah sukses, berkas `.tmp` telah di-rename menjadi target akhir.
     - Berkas sebelumnya dirotasi menjadi `.bak`.

#### Kasus Uji `test_t47_02_existing_save_unharmed_if_write_fails_midway()`
- **Tujuan:** Memverifikasi bahwa jika penulisan terhenti di tengah jalan (misal disk penuh, pembatalan IO, atau error penulisan), berkas save sebelumnya tetap utuh dan tidak korup.
- **Langkah & Setup:**
  1. Buat berkas simpan awal yang valid `slot_manual.json` (revisi 1).
  2. Simulasikan kegagalan penulisan saat menyimpan revisi 2 (misal injeksi stream error atau file `.tmp` tidak dapat diselesaikan).
- **Asersi Expected:**
  - `sm.save_game()` mengembalikan kode error kegagalan.
  - Berkas `slot_manual.json` lama tetap utuh, valid, dan dapat dimuat kembali (revisi 1 tidak rusak).
  - Pesan error jujur ditampilkan: *"Progres belum tersimpan. Coba lagi atau gunakan lokasi simpan yang dapat ditulis."* (CONTENT § 11).

#### Kasus Uji `test_t47_03_temp_file_cleanup_on_failure()`
- **Tujuan:** Berkas sisa `.tmp` yang gagal ditulis dibersihkan atau diabaikan, tidak dianggap sebagai berkas save valid.

---

### 3.7 Grup 7: T48 — Manajemen Slot Manual, Autosave, dan Cadangan

#### Kasus Uji `test_t48_01_separate_manual_and_autosave_slot_isolation()`
- **Tujuan:** Memverifikasi pemisahan mutlak antara berkas simpan manual (`slot_manual.json`) dan berkas simpan otomatis (`autosave.json`). Autosave tidak boleh menimpa slot manual (PROTOTYPE § 7, TEST_PLAN T48).
- **Langkah & Setup:**
  1. Simpan manual: `sm.save_game("manual")` dengan data Hari 1.
  2. Simulasikan pemicu autosave: `sm.save_game("autosave")` dengan data Hari 2.
- **Asersi Expected:**
  - File `slot_manual.json` tetap menyimpan Hari 1.
  - File `autosave.json` menyimpan Hari 2.
  - Masing-masing memiliki slot cadangan sendiri: `slot_manual.json.bak` dan `autosave.json.bak`.

#### Kasus Uji `test_t48_02_continue_selects_newest_revision_across_slots()`
- **Tujuan:** Memverifikasi logika tombol "Lanjutkan" (`continue_game()` / `get_latest_save_info()`) yang memilih revisi valid tertinggi antara slot manual dan autosave.
- **Langkah & Setup:**
  1. Simpan manual revisi 1 (timestamp T1).
  2. Lakukan autosave revisi 2 (timestamp T2, T2 > T1).
  3. Periksa slot target "Lanjutkan": harus menunjuk ke `autosave`.
  4. Lakukan simpan manual revisi 3 (timestamp T3, T3 > T2).
  5. Periksa slot target "Lanjutkan": harus beralih menunjuk ke `manual`.
- **Asersi Expected:**
  - Evaluasi slot terbaru selalu deterministik berdasarkan nomor revisi dan timestamp.

#### Kasus Uji `test_t48_03_explicit_manual_slot_selection_when_autosave_is_newer()`
- **Tujuan:** Memastikan bahwa pemain dapat secara sadar membuka menu Muat dan memilih slot manual lama, meskipun ada autosave yang lebih baru (PROTOTYPE § 7).
- **Asersi Expected:**
  - Pemanggilan `sm.load_game("manual")` memuat slot manual lama, bukan memaksa muat autosave.

#### Kasus Uji `test_t48_04_backup_creation_on_every_successful_overwrite()`
- **Tujuan:** Setiap kali slot manual atau autosave ditimpa, berkas versi sebelumnya dipindahkan menjadi `.bak`.

---

### 3.8 Grup 8: T49 — Isolasi Pengaturan (`settings.cfg`) dari Save Game

#### Kasus Uji `test_t49_01_settings_stored_in_standalone_config_file()`
- **Tujuan:** Memverifikasi bahwa preferensi pengguna (FOV, sensitivitas mouse, volume audio, subtitle, UI scale per CONTENT § 14) disimpan di `user://settings.cfg` menggunakan format `ConfigFile` Godot, terpisah dari berkas save progres JSON.
- **Asersi Expected:**
  - `user://settings.cfg` ada dan dapat dibaca via `ConfigFile.new()`.
  - Berisi seksi `[controls]`, `[display]`, `[audio]`.
  - Tidak berisi informasi inventaris, hari, atau tanaman.

#### Kasus Uji `test_t49_02_game_load_and_new_game_preserves_settings()`
- **Tujuan:** Memverifikasi bahwa aksi memuat save game lama atau memulai Game Baru TIDAK menimpa atau mereset pengaturan pengguna yang sudah dikustomisasi (TEST_PLAN T49, PROTOTYPE § 7).
- **Langkah & Setup:**
  1. Ubah pengaturan: `fov = 95.0`, `mouse_sensitivity = 0.0035`, `master_volume = 0.5`. Simpan pengaturan.
  2. Muat save game lama yang dibuat saat setting masih default (`fov = 80.0`).
  3. Lakukan Game Baru (`start_new_game()`).
- **Asersi Expected:**
  - Nilai FOV live tetap `95.0`.
  - Nilai sensitivitas mouse live tetap `0.0035`.
  - Nilai master volume live tetap `0.5`.
  - Berkas `settings.cfg` tidak tersentuh oleh mutasi save game.

#### Kasus Uji `test_t49_03_settings_corruption_does_not_affect_save_game()`
- **Tujuan:** Kerusakan pada berkas `settings.cfg` (misal teks invalid) tidak merusak save game dan hanya mengembalikan pengaturan ke default aman.

---

### 3.9 Grup 9: T50 — Round-Trip Save/Load 100% Identik & Idempotensi

#### Kasus Uji `test_t50_01_comprehensive_p0_game_state_roundtrip()`
- **Tujuan:** Memverifikasi integritas siklus penuh save-load (*round-trip persistence*) atas seluruh kondisi game P0 vertikal secara bersamaan (PRD FR15, CONTENT § 12).
- **Komponen State yang Diserialisasi:**
  1. **Player:** Posisi `(12.5, 0.0, 14.2)`, pitch `0.25`, yaw `-1.1`, alat aktif `tool_hoe`, isi air `8/10`.
  2. **Inventory:** 5 slot tas terisi, 4 slot peti terisi, 1 slot refund terisi, `starter_claimed = true`.
  3. **Garden:** Petak gembur, pembenah, kelembapan `58.2`, nutrisi `84.0`, 4 spot dengan 4 fase berbeda.
  4. **World:** Hari ke-3, waktu aktif `450.0s`, `meal_used = true`, log panen jagung & temu kunci.
  5. **Kitchen:** Job dijeda, 3 bahan tereservasi, origin manifest, 1 hidangan di slot hasil.
  6. **Recipe:** Resep dilacak, `times_cooked = 1`, resep selesai, catatan kebun `note_garden_01` unlocked.
  7. **Dialogue:** `has_spoken_intro = true`, `has_shared_meal = true`, `p0_completed = true`.
- **Aksi:**
  1. Ambil snapshot komprehensif A.
  2. Simpan ke berkas disk.
  3. Reset seluruh manajer ke status kosong/default.
  4. Muat kembali dari berkas disk -> Dapatkan snapshot komprehensif B.
- **Asersi Expected:**
  - Snapshot A dan Snapshot B identik 100% pada setiap nilai field, dictionary, dan array.
  - Selisih float berada dalam batas toleransi `<= 0.001`.

#### Kasus Uji `test_t50_02_idempotent_multi_roundtrip()`
- **Tujuan:** Memastikan bahwa siklus berulang Save -> Load -> Save -> Load menghasilkan representasi biner dan struktur data yang stabil tanpa degradasi, kehilangan, atau kebocoran data (*zero drift*).
- **Asersi Expected:**
  - Byte berkas dan dictionary hasil muat siklus 1 dan siklus 2 sama persis.

---

## 4. Blueprint Kode Lengkap Suite Pengujian (`test_save.gd`)

Berikut adalah struktur kode GDScript lengkap untuk `tests/suites/test_save.gd` yang siap diintegrasikan oleh worker implementasi:

```gdscript
class_name TestSave
extends RefCounted

## Test Suite SAVE-001: Persistensi Lengkap, Checkpoint, Validasi Envelope, dan Error Recovery (Suite 19)
## Memverifikasi PRD FR15, CONTENT.md § 11, § 12, § 14, PROTOTYPE.md § 5, § 7,
## TASKS.md SAVE-001, dan TEST_PLAN T14, T16, T17, T22, T46, T47, T48, T49, T50.

const Assertions = preload("res://tests/assertions.gd")
const SaveManagerClass = preload("res://scripts/save/save_manager.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const RecipeManagerClass = preload("res://scripts/recipe/recipe_manager.gd")
const GardenManagerClass = preload("res://scripts/gardening/garden_manager.gd")
const WorldResourceManagerClass = preload("res://scripts/world/world_resource_manager.gd")
const KitchenManagerClass = preload("res://scripts/cooking/kitchen_manager.gd")
const DialogueManagerClass = preload("res://scripts/social/dialogue_manager.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")
const PlayerConfigClass = preload("res://scripts/player/player_config.gd")

const SANDBOX_DIR: String = "user://test_save_sandbox/"
const SANDBOX_SAVES_DIR: String = "user://test_save_sandbox/saves/"
const SANDBOX_SETTINGS_PATH: String = "user://test_save_sandbox/settings.cfg"

func run_all() -> bool:
	var passed := true
	print("  Running TestSave suite (T14, T16, T17, T22, T46, T47, T48, T49, T50 Full Save/Load Acceptance)...")
	
	_setup_sandbox()

	# Grup 1: T14 — Preservasi Tas, Peti, Alat & Job Dijeda
	if not test_t14_01_backpack_storage_and_tools_preservation(): passed = false
	if not test_t14_02_paused_job_and_crop_growth_preservation_no_offline_progress(): passed = false

	# Grup 2: T16 — Validasi Pra-Swap Dunia & Penolakan Snapshot Rusak
	if not test_t16_01_reject_snapshot_with_missing_mandatory_sections(): passed = false
	if not test_t16_02_reject_snapshot_with_unknown_item_ids_and_illegal_counts(): passed = false
	if not test_t16_03_atomic_world_swap_all_or_nothing(): passed = false

	# Grup 3: T17 — Ketahanan Berkas Korup & Fallback Cadangan (.bak)
	if not test_t17_01_fallback_to_bak_when_primary_save_file_corrupted(): passed = false
	if not test_t17_02_clean_failure_when_both_primary_and_bak_are_corrupted(): passed = false
	if not test_t17_03_zero_byte_file_resilience(): passed = false

	# Grup 4: T22 — Validasi Posisi Pemain & Safe Spawn Redirection
	if not test_t22_01_redirect_nan_and_inf_coordinates_to_safe_spawn(): passed = false
	if not test_t22_02_redirect_out_of_bounds_coordinates_to_safe_spawn(): passed = false
	if not test_t22_03_valid_coordinates_preserved_without_redirection(): passed = false

	# Grup 5: T46 — Pemulihan Status Dinamis Kebun dan Dapur
	if not test_t46_01_garden_plot_and_crop_stages_restoration(): passed = false
	if not test_t46_02_kitchen_job_reservation_origin_and_refund_restoration(): passed = false

	# Grup 6: T47 — Uji Ketahanan Crash Penulisan Atomik via .tmp
	if not test_t47_01_atomic_write_creates_tmp_before_target(): passed = false
	if not test_t47_02_existing_save_unharmed_if_write_fails_midway(): passed = false
	if not test_t47_03_temp_file_cleanup_on_failure(): passed = false

	# Grup 7: T48 — Manajemen Slot Manual, Autosave, dan Cadangan
	if not test_t48_01_separate_manual_and_autosave_slot_isolation(): passed = false
	if not test_t48_02_continue_selects_newest_revision_across_slots(): passed = false
	if not test_t48_03_explicit_manual_slot_selection_when_autosave_is_newer(): passed = false
	if not test_t48_04_backup_creation_on_every_successful_overwrite(): passed = false

	# Grup 8: T49 — Isolasi Pengaturan (settings.cfg) dari Save Game
	if not test_t49_01_settings_stored_in_standalone_config_file(): passed = false
	if not test_t49_02_game_load_and_new_game_preserves_settings(): passed = false
	if not test_t49_03_settings_corruption_does_not_affect_save_game(): passed = false

	# Grup 9: T50 — Round-Trip Save/Load 100% Identik & Idempotensi
	if not test_t50_01_comprehensive_p0_game_state_roundtrip(): passed = false
	if not test_t50_02_idempotent_multi_roundtrip(): passed = false

	_teardown_sandbox()
	return passed

# ==============================================================================
# Sandbox Helpers
# ==============================================================================

func _setup_sandbox() -> void:
	_clean_sandbox()
	DirAccess.make_dir_recursive_absolute(SANDBOX_SAVES_DIR)

func _teardown_sandbox() -> void:
	_clean_sandbox()

func _clean_sandbox() -> void:
	if DirAccess.dir_exists_absolute(SANDBOX_SAVES_DIR):
		var dir := DirAccess.open(SANDBOX_SAVES_DIR)
		if dir:
			dir.list_dir_begin()
			var fn := dir.get_next()
			while fn != "":
				if not dir.current_is_dir():
					dir.remove(fn)
				fn = dir.get_next()
			dir.list_dir_end()
	if FileAccess.file_exists(SANDBOX_SETTINGS_PATH):
		DirAccess.remove_absolute(SANDBOX_SETTINGS_PATH)

func _create_test_save_manager() -> RefCounted:
	var sm = SaveManagerClass.new()
	if sm.has_method("set_save_directory"):
		sm.set_save_directory(SANDBOX_SAVES_DIR)
	if sm.has_method("set_settings_path"):
		sm.set_settings_path(SANDBOX_SETTINGS_PATH)
	return sm
```

---

## 5. Rencana Pendaftaran pada `tests/test_runner.gd` & Eksekusi CLI

### 5.1 Perubahan pada `tests/test_runner.gd`

Pada baris import suites:
```gdscript
const TestSave = preload("res://tests/suites/test_save.gd")
```

Pada blok eksekusi `_initialize()`:
```gdscript
	# Suite 19: TestSave (T14, T16, T17, T22, T46, T47, T48, T49, T50 Full Save/Load Acceptance)
	var suite_save := TestSave.new()
	if not suite_save.run_all():
		all_passed = false
```

### 5.2 Perintah Eksekusi Headless CLI

Sesuai dengan lingkungan Windows host dan binari Godot yang terpasang pada `C:\Users\HP\.local\bin\godot.exe`, runner dijalankan melalui terminal:

```powershell
& "C:\Users\HP\.local\bin\godot.exe" --headless --path . --script res://tests/test_runner.gd
```

### 5.3 Validasi Exit Code dan Ringkasan Log
- **Exit Code 0:** Seluruh asersi lulus (`all_passed == true` dan `Assertions.current_suite_failed == 0`).
- **Exit Code 1:** Jika ada asersi gagal, test runner keluar dengan kode 1 dan CI/pipeline memblokir merge.
- Log hasil diekspor otomatis ke `res://test_summary.log`.

---

## 6. Matriks Ketertelusuran Persyaratan (Traceability Matrix)

| Kode Uji | Metode Uji Utama | Acuan Spesifikasi | Aspek Kritis yang Diverifikasi |
|---|---|---|---|
| **T14** | `test_t14_01_backpack_storage_and_tools_preservation`<br>`test_t14_02_paused_job_and_crop_growth_preservation_no_offline_progress` | PRD FR05/FR15<br>CONTENT § 3, § 5, § 7<br>TEST_PLAN T14 | Konservasi 24 slot tas & peti, air penyiram, refund container; job & tanaman dijeda saat keluar game (zero offline progress). |
| **T16** | `test_t16_01_reject_snapshot_with_missing_mandatory_sections`<br>`test_t16_02_reject_snapshot_with_unknown_item_ids_and_illegal_counts`<br>`test_t16_03_atomic_world_swap_all_or_nothing` | PRD FR15/FR23<br>PROTOTYPE § 7<br>TEST_PLAN T16 | Validasi schema/tipe data sebelum menyentuh dunia aktif; penolakan snapshot rusak secara atomik tanpa mutasi parsial. |
| **T17** | `test_t17_01_fallback_to_bak_when_primary_save_file_corrupted`<br>`test_t17_02_clean_failure_when_both_primary_and_bak_are_corrupted`<br>`test_t17_03_zero_byte_file_resilience` | PRD FR15/FR23<br>CONTENT § 11<br>TEST_PLAN T17 | Fallback transparan ke berkas cadangan `.bak` saat berkas utama korup/terpotong/0-byte; pesan error jujur. |
| **T22** | `test_t22_01_redirect_nan_and_inf_coordinates_to_safe_spawn`<br>`test_t22_02_redirect_out_of_bounds_coordinates_to_safe_spawn`<br>`test_t22_03_valid_coordinates_preserved_without_redirection` | PRD FR01/FR15<br>LEVEL_DESIGN § 4<br>TEST_PLAN T22 | Redirection koordinat `NaN`, `Inf`, dan out-of-bounds ke `safe_return_home` `(0, 0, 8)` atau `spawn_home` `(0, 0, 1)` tanpa merusak barang/progres. |
| **T46** | `test_t46_01_garden_plot_and_crop_stages_restoration`<br>`test_t46_02_kitchen_job_reservation_origin_and_refund_restoration` | CONTENT § 4, § 7<br>PROTOTYPE § 6, § 7<br>TEST_PLAN T46 | Pemulihan 4 spot tumbuh bayam, kelembapan/nutrisi petak, reservasi dapur, mapping origin slot, dan dish output slot. |
| **T47** | `test_t47_01_atomic_write_creates_tmp_before_target`<br>`test_t47_02_existing_save_unharmed_if_write_fails_midway`<br>`test_t47_03_temp_file_cleanup_on_failure` | PRD FR15/FR23<br>PROTOTYPE § 7<br>TEST_PLAN T47 | Penulisan atomik via `.tmp` -> `.bak` -> final file replacement; berkas lama tetap utuh saat penulisan gagal. |
| **T48** | `test_t48_01_separate_manual_and_autosave_slot_isolation`<br>`test_t48_02_continue_selects_newest_revision_across_slots`<br>`test_t48_03_explicit_manual_slot_selection_when_autosave_is_newer`<br>`test_t48_04_backup_creation_on_every_successful_overwrite` | PRD FR15<br>PROTOTYPE § 7<br>TEST_PLAN T48 | Isolasi slot manual dan autosave; evaluasi "Lanjutkan" berbasis revisi/timestamp; pilihan manual eksplisit. |
| **T49** | `test_t49_01_settings_stored_in_standalone_config_file`<br>`test_t49_02_game_load_and_new_game_preserves_settings`<br>`test_t49_03_settings_corruption_does_not_affect_save_game` | PRD FR16<br>CONTENT § 14<br>PROTOTYPE § 7<br>TEST_PLAN T49 | Format terpisah `settings.cfg`; pengaturan FOV/sensitivitas/audio tidak tertimpa oleh load game atau new game. |
| **T50** | `test_t50_01_comprehensive_p0_game_state_roundtrip`<br>`test_t50_02_idempotent_multi_roundtrip` | PRD FR15<br>CONTENT § 12<br>PROTOTYPE § 7<br>TEST_PLAN T50 | Round-trip 100% identik atas seluruh state 7 manajer; zero drift pada siklus simpan-muat multi-iterasi. |

---

## 7. Rekomendasi untuk Worker Implementasi

1. **Parameterisasi Jalur Direktori Save:** Pastikan kelas `SaveManager` (`scripts/save/save_manager.gd`) mengekspos metode konfigurasi jalur penyimpanan, misalnya `set_save_directory(path: String)` dan `set_settings_path(path: String)`, dengan nilai default masing-masing `user://saves/` dan `user://settings.cfg`. Hal ini esensial agar suite uji dapat berjalan 100% dalam sandbox tanpa efek samping.
2. **Validator Koordinat Pemain:** Implementasikan fungsi pembantu `_validate_player_transform(pos: Vector3, pitch: float, yaw: float) -> Dictionary` di dalam `SaveManager` yang secara eksplisit memeriksa `is_nan(pos.x)`, `is_inf(pos.x)`, dan amplop batas level `X in [-42.0, 42.0]`, `Z in [-37.0, 47.0]`, `Y >= -5.0`.
3. **Pementasan Data Pra-Swap (Staging):** Saat `load_game` dijalankan, muat seluruh data ke dalam objek/dictionary sementara terlebih dahulu. Hanya jika seluruh 7 manajer berhasil memvalidasi payload mereka, sinyal swap dipancarkan dan manajer live di-update.
4. **Eksekusi Headless:** Pastikan seluruh operasi file menggunakan `FileAccess` dan `DirAccess` standar Godot 4.7 tanpa memanggil API OS yang memblokir GUI thread.
