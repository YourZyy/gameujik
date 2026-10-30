# Handoff Report: Investigasi WORLD-001 — Kasur Tidur, Siklus Hari, Test Suite (T09, T37, T38, T39) & Arsitektur Manager

**Milestone:** WORLD-001  
**Agent:** Explorer 3 (`explorer_world_001_3`)  
**Status:** SELESAI (Investigation & Blueprint Complete)  
**Target File:** `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_world_001_3\handoff.md`

---

## 1. Observation

### 1.1 Lokasi & Setup Landmark `bed_home` dan Fasilitas Dunia di `level_graybox.tscn`
1. Berdasarkan pemeriksaan `scripts/world/level_graybox.gd` (baris 6–25) dan `scripts/tools/build_level_graybox.gd` (baris 198–205):
   - Landmark `bed_home` ditempatkan pada posisi koordinat dunia `Vector3(-2.0, 0.0, 0.0)` di dalam struktur rumah (`HouseStructure`).
   - Objek fisik: `BedMat` berupa `StaticBody3D` pada posisi lokal `Vector3(0.0, 0.15, 0.0)` dengan ukuran `Vector3(1.8, 0.3, 2.0)`.
   - Objek interaksi: `Interactable` berupa `Area3D` pada posisi lokal `Vector3(0.0, 0.2, 0.0)` dengan `BoxShape3D` ukuran `Vector3(1.8, 0.3, 2.0)`.
   - Konfigurasi layer fisika: `collision_layer = 4` (Physics Layer 3: `interactables`, bitmask `1 << 2`), `collision_mask = 0`, `monitoring = false`, `monitorable = true`.
   - Komponen skrip: `res://scripts/interaction/interactable.gd`.
   - Metadata prompt: `interaction_id = "landmark_bed"`, `prompt_action = "Istirahat"`, `target_name = ""` -> menghasilkan prompt teks `"[E] Istirahat"`.
   - Landmark ini telah diverifikasi keberadaannya dan sifat interactable-nya pada `tests/suites/test_interaction.gd` baris 256–270.

2. Setup Landmark Dunia Terkait lainnya di `level_graybox.tscn`:
   - `water_home` (`build_level_graybox.gd:238–244`): Posisi `Vector3(4.0, 0.0, 9.0)`, `interaction_id = "landmark_water"`, prompt `"[E] Ambil Air"`.
   - `container_starter` (`build_level_graybox.gd:247–253`): Posisi `Vector3(6.0, 0.0, 4.0)`, `interaction_id = "landmark_starter"`, prompt `"[E] Ambil Wadah Starter"`.
   - `reserve_home` (`build_level_graybox.gd:256–262`): Posisi `Vector3(7.0, 0.0, 4.0)`, `interaction_id = "landmark_reserve"`, prompt `"[E] Periksa Cadangan"`.
   - `resource_jagung_01` (`build_level_graybox.gd:286–292`): Posisi `Vector3(22.0, 0.0, 28.0)`, `interaction_id = "landmark_jagung"`, prompt `"[E] Periksa Jagung"`.
   - `resource_temu_kunci_01` (`build_level_graybox.gd:306–314`): Posisi `Vector3(-20.0, 0.0, 30.0)`, `interaction_id = "landmark_temu_kunci"`, prompt `"[E] Periksa Temu Kunci"`.

### 1.2 Aturan Istirahat, Siklus Hari & Invarian Tanaman
1. **Aturan Istirahat (`docs/CONTENT.md` § 9 baris 158–165, `docs/PROTOTYPE.md` § 5.1):**
   - Hari awal bernilai `day_index = 1` dengan waktu aktif hari `day_active_time = 0.0`.
   - Satu hari prototipe setara dengan `720.0` detik simulasi aktif (`DAY_DURATION = 720.0`).
   - Aksi tidur di kasur (`bed_home`) memajukan kalender: `day_index += 1`, dan mereset waktu aktif hari `day_active_time = 0.0`.
   - Sumber liar (`resource_jagung_01` dan `resource_temu_kunci_01`) dipanen 1x per hari simulasi (`last_harvested_day < current_day` menandakan node pulih dan dapat dipanen kembali).
   - Penolakan istirahat: Istirahat DITOLAK bila terdapat job memasak dapur yang sedang aktif/berjalan (`CONTENT.md` § 9 baris 164: *"Istirahat ditolak saat job dapur masih aktif; lanjutkan job atau batalkan bila masih di tahap persiapan. Output yang sudah selesai tidak menghalangi istirahat"*).

2. **Invarian Kritis Perlindungan Tanaman (`AGENTS.md` § 4, `docs/TASKS.md` § WORLD-001, `docs/CONTENT.md` § 9 baris 164):**
   - Teks otoritatif `CONTENT.md` § 9:
     > *"Istirahat adalah lompatan kalender untuk memulihkan sumber, **tidak menyimulasikan 720 detik pertumbuhan/penguapan sekaligus**. Kondisi petak dan kemajuan tanaman dipertahankan."*
   - Teks otoritatif `AGENTS.md` § 4 & `TASKS.md` § WORLD-001:
     > *"istirahat memulihkan sumber tanpa mengubah tanaman", "tanpa mensimulasikan kerugian tanaman ketika melompat hari".*
   - Pada `scripts/gardening/garden_manager.gd` baris 56–63 dan baris 553–561:
     - Laju penguapan adalah `EVAPORATION_RATE = 0.1` per detik. Jika disimulasikan 720 detik, kelembapan akan anjlok sebesar `72.0` poin, menyebabkan petak mengering seketika dan menghentikan seluruh pertumbuhan tanaman.
     - Oleh karena itu, simulasi kebun (`simulate_process`, `simulate_growth`, `simulate_evaporation`) **TIDAK BOLEH** dipanggil atau dimajukan saat aksi tidur/istirahat berlangsung.

### 1.3 Keadaan Eksekusi Test Runner & Suite Pengujian Eksisting
1. Hasil eksekusi pengujian headless saat ini:
   - Perintah: `& "C:\Users\HP\.local\bin\godot.exe" --headless --script tests/test_runner.gd`
   - Hasil faktual: **1.078 Assertions Passed, 0 Failed, Exit Code 0**.
   - Suite yang terdaftar saat ini (1..9):
     1. `TestSetup` (T23, T24 baseline)
     2. `TestLevel` (T24, T25 graybox level & recovery)
     3. `TestAdversarialLevel` (LVL-001 Stress & Recovery Challenge)
     4. `TestPlayer` (T18, T25, T26 first-person controls & physics)
     5. `TestAdversarialPlayer` (PLY-001 Stress & Edge-Case Verification)
     6. `TestInteraction` (T18, T27, T28 interaction, occlusion & input context)
     7. `TestInventory` (T02, T03, T04, T29, T30, T31, T32, T33 inventory & storage)
     8. `TestRecipe` (T01, T02, T03, T11, T31, notes registry, save snapshot, input context)
     9. `TestGardening` (T06, T07, T08, T32, T33, plot prep, tools, planting, fertilizing, watering)
2. `tests/test_runner.gd` siap menerima pendaftaran Suite 10: `TestWorld` (`tests/suites/test_world.gd`).

### 1.4 Status Autoload Proyek di `project.godot`
- Autoload terdaftar saat ini (`project.godot` baris 14–20):
  ```ini
  [autoload]

  InputManager="*res://scripts/core/input_manager.gd"
  InventoryManager="*res://scripts/inventory/inventory_manager.gd"
  RecipeManager="*res://scripts/recipe/recipe_manager.gd"
  GardenManager="*res://scripts/gardening/garden_manager.gd"
  ```
- Catatan: `GameManager` belum terdaftar di `project.godot` dan belum memiliki implementasi fisik di `scripts/core/game_manager.gd`.

---

## 2. Logic Chain

### 2.1 Mekanisme Interaksi `bed_home` dan Siklus Hari
1. **Langkah 1 (Deteksi Interaksi):**  
   Pemain mengarahkan pandangan ke `bed_home` (jarak <= 2.0m, layer 3 terdeteksi oleh `InteractionDetector`). Prompt `[E] Istirahat` muncul di HUD.
2. **Langkah 2 (Validasi Pra-Istirahat / Guard Check):**  
   Sistem memeriksa apakah dapur sedang menjalankan proses memasak aktif (`KitchenManager.is_cooking_active()` atau state internal job memasak != IDLE/OUTPUT_READY).
   - Jika job aktif: Aksi ditolak dengan umpan balik jujur `"Selesaikan atau batalkan proses memasak dahulu sebelum istirahat."` Hari tidak berganti.
   - Jika job tidak aktif (atau hidangan siap diambil): Lolos validasi.
3. **Langkah 3 (Eksekusi Transisi Hari):**  
   - Indeks hari bertambah: `current_day += 1`.
   - Timer hari aktif direset: `day_active_time = 0.0`.
   - Kuota harian node liar (`resource_jagung_01`, `resource_temu_kunci_01`) dipulihkan secara otomatis karena `last_harvested_day < current_day`.
   - Sinyal dipancarkan: `day_changed(current_day)`, `rest_completed(current_day)`, `foraging_nodes_refreshed()`.
4. **Langkah 4 (Invarian Perlindungan Kebun & Tanaman):**  
   - Fungsi `GardenManager.simulate_process(delta)` **TIDAK** dipanggil selama lompatan istirahat.
   - Kelembapan tanah (`moisture`), nutrisi tanah (`nutrients`), kemajuan pertumbuhan tanaman bayam (`growth_time`, `growth_stage`), dan status macet (`is_stalled`) tetap berada pada angka persis sebelum tidur.
   - Terhindar dari desikasi tanah (kelembapan -72.0) atau kematian tanaman secara instan.
5. **Langkah 5 (Timer Kontinu 720 Detik vs Aksi Tidur):**  
   - Saat pemain aktif menjelajah di dunia (`ContextMode.WORLD` dan `not InputManager.is_simulation_paused()`), timer berjalan: `day_active_time += delta`.
   - Jika pemain tidak tidur dan `day_active_time >= 720.0`:
     - Hari berganti secara alami: `current_day += 1`, `day_active_time -= 720.0`.
     - Pergantian alami ini juga memulihkan kuota panen node liar untuk hari berikutnya.
   - Jika pemain menekan `[E] Istirahat` di kasur pada sembarang waktu (misal detik 250):
     - Timer hari langsung dilompati ke detik 0.0 pada hari berikutnya (`current_day += 1`, `day_active_time = 0.0`).
     - Pemain memulai hari baru di titik awal siklus.

---

### 2.2 Desain Arsitektur Test Suite WORLD-001 (`tests/suites/test_world.gd`)
Sesuai mandat pengujian pada `docs/TEST_PLAN.md` (T09, T37, T38, T39) dan arahan dispatch, `TestWorld` dirancang dengan 4 kelompok pengujian komprehensif:

#### A. Kelompok Pengujian T09: Cadangan Darurat (`reserve_home` / Contextual Emergency Reserves)
- **Kasus Uji T09.1 — Prasyarat Wadah Awal (`container_starter`):**
  Interaksi dengan `reserve_home` sebelum wadah awal diambil ditolak dengan pesan: `"Periksa wadah dekat alat dahulu."` Tidak ada item yang diberikan.
- **Kasus Uji T09.2 — Penolakan Bila Masih Ada Benih di Tas / Peti:**
  Jika pemain memiliki `>= 1 seed_bayam` di tas atau peti rumah, permintaan benih cadangan ditolak: `"Benih masih tersedia di tas/peti."`
- **Kasus Uji T09.3 — Penolakan Bila Masih Ada Tanaman Hidup di Kebun (Invarian T38):**
  Jika pemain memiliki 0 benih di tas dan peti, TETAPI terdapat 1 atau lebih titik tanam di `plot_home_01` yang terisi (`is_occupied == true`, sedang tumbuh atau siap panen), permintaan benih cadangan ditolak. Penjelasan: Tanaman yang sedang hidup akan menghasilkan benih saat dipanen.
- **Kasus Uji T09.4 — Pemberian Benih Cadangan Saat Kondisi Macet Total (True Softlock):**
  Wadah awal sudah diambil, 0 benih di tas/peti/refund, 0 tanaman hidup di kebun. Pemain menekan interaksi pada `reserve_home`. Paket darurat 4 `seed_bayam` diberikan dan dimasukkan ke tas pemain.
- **Kasus Uji T09.5 — Idempotensi & Pencegahan Duplikasi Cadangan:**
  Interaksi kedua secara langsung setelah menerima cadangan langsung ditolak karena tas kini telah memiliki 4 benih.
- **Kasus Uji T09.6 — Penolakan Transaksi Saat Tas Penuh (Atomic Capacity Guard):**
  Pemain berada pada kondisi macet total, namun ke-12 slot tas pemain penuh dengan item lain. Interaksi ditolak: `"Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."` Hak cadangan tidak hangus dan dapat diambil setelah slot dikosongkan.
- **Kasus Uji T09.7 — Cadangan Kontekstual Pembenah Tanah & Pupuk:**
  - Pembenah tanah (1 `soil_compost`): Diberikan jika petak sudah digemburkan (`is_hoed == true`), belum diberi pembenah (`has_compost == false`), dan stok pembenah bebas = 0.
  - Pupuk (1 `fertilizer_basic`): Diberikan jika nutrisi petak `< 20`, dan stok pupuk bebas = 0.

#### B. Kelompok Pengujian T37: Isi Ulang Air Sumur (`water_home` / Well Water Refill)
- **Kasus Uji T37.1 — Komitmen Pengisian Penuh dengan Tahan 2.0 Detik:**
  Mulai dengan air penyiram = 0 (atau 4). Jalankan aksi tahan pada `water_home` selama 2.0 detik menggunakan `HoldActionController`. Setelah 2.0 detik tercapai, sinyal `hold_completed` memicu pengisian: air penyiram terisi penuh ke kapasitas maksimum `10/10`.
- **Kasus Uji T37.2 — Pembatalan Sebelum 2.0 Detik Tanpa Biaya/Perubahan:**
  Mulai dengan air penyiram = 4. Jalankan aksi tahan selama 1.2 detik, lalu lepaskan tombol (batal). Air penyiram tetap berada pada 4 unit. Tidak ada air yang terbuang atau bertambah sebagian.
- **Kasus Uji T37.3 — Penolakan Saat Air Sudah Penuh (10/10):**
  Ketika air penyiram sudah `10/10`, aksi isi ulang ditolak dengan pesan jujur: `"Kondisi cukup. Air sudah penuh."` (CONTENT.md § 11).
- **Kasus Uji T37.4 — Pencegahan Spam Tombol & Anti-Looping:**
  Menahan tombol terus menerus setelah komitmen dicegah oleh status `State.MUST_RELEASE`, pemain wajib melepas tombol sebelum memulai aksi baru.

#### C. Kelompok Pengujian T38: Interaksi Foraging Harian Liar (`resource_jagung_01` & `resource_temu_kunci_01`)
- **Kasus Uji T38.1 — Panen Perdana Sukses (1 Hasil per Node):**
  Pada Hari 1, interaksi dengan `resource_jagung_01` menghasilkan 1 `ingredient_jagung` masuk ke tas pemain. Interaksi dengan `resource_temu_kunci_01` menghasilkan 1 `ingredient_temu_kunci` masuk ke tas.
- **Kasus Uji T38.2 — Penolakan Panen Kedua pada Hari yang Sama (Kuota Harian 1x):**
  Interaksi kedua pada hari yang sama pada `resource_jagung_01` ditolak: `"Jagung sudah dipanen hari ini. Tunggu esok hari."` Tidak ada item tambahan. Interaksi kedua pada `resource_temu_kunci_01` juga ditolak.
- **Kasus Uji T38.3 — Penolakan Atomik Saat Tas Penuh:**
  Pada hari baru (node siap panen), jika seluruh 12 slot tas penuh tanpa slot/tumpukan muat, interaksi panen ditolak dengan pesan tas penuh. Node tetap berstatus belum dipanen (`last_harvested_day` tidak termutasi). Setelah 1 slot tas dikosongkan, panen berhasil.
- **Kasus Uji T38.4 — Independensi Status Antar-Node Liar:**
  Memanen jagung tidak mengunci temu kunci. Masing-masing node melacak hari panennya sendiri secara independen.

#### D. Kelompok Pengujian T39: Istirahat di Kasur (`bed_home`) & Invarian Pertanian
- **Kasus Uji T39.1 — Kemajuan Hari dan Reset Timer Harian:**
  Mulai pada `current_day = 1`, `day_active_time = 360.0`. Lakukan aksi istirahat di `bed_home`. `current_day` bertambah menjadi 2, `day_active_time` tereset menjadi `0.0`.
- **Kasus Uji T39.2 — Pemulihan Kuota Node Liar Setelah Istirahat:**
  Node jagung dan temu kunci yang telah dipanen pada Hari 1 dapat dipanen kembali secara normal pada Hari 2 setelah istirahat.
- **Kasus Uji T39.3 — Invarian Kritis: Pelestarian Petak & Tanaman Tanpa Penalti:**
  Sebelum istirahat, petak memiliki kelembapan 55.0, nutrisi 75.0, dan tanaman pada tahap Tunas (45s) dan Tumbuh (120s). Setelah istirahat ke Hari 2:
  - Kelembapan petak TETAP 55.0 (toleransi 0.001, tidak terjadi penguapan 72.0 poin).
  - Nutrisi petak TETAP 75.0.
  - Kemajuan waktu dan tahap pertumbuhan tanaman TETAP persis sama (tidak ada tanaman mati, layu, atau macet mendadak).
- **Kasus Uji T39.4 — Penolakan Istirahat Saat Job Dapur Sedang Aktif:**
  Ketika dapur sedang menjalankan job memasak aktif, aksi istirahat ditolak dengan pesan peringatan. Hari tidak bertambah.
- **Kasus Uji T39.5 — Siklus Hari Kontinu (Pergantian Alami 720 Detik):**
  Memajukan waktu aktif sebesar 720.0 detik melalui `simulate_process(720.0)` memajukan hari secara alami dari 1 ke 2 dan mereset timer aktif ke sisa modulo. Kuota node liar ikut pulih.
- **Kasus Uji T39.6 — Serialisasi & Deserialisasi Snapshot State Dunia (SAVE-001 Contract):**
  Snapshot state dunia (`current_day`, `day_active_time`, `foraging_nodes`, `reserve_state`) tersimpan dalam format kamus JSON-safe dan dapat dipulihkan secara identik tanpa data korup.
- **Kasus Uji T39.7 — Integrasi Objek Nyata dalam Scene `level_graybox.tscn`:**
  Memuat `scenes/world/level_graybox.tscn`, memverifikasi bahwa node `bed_home`, `water_home`, `reserve_home`, `resource_jagung_01`, dan `resource_temu_kunci_01` terhubung ke handler interaksi dengan benar.

---

### 2.3 Rekomendasi Arsitektur Autoload / Manager
Terdapat dua opsi arsitektur:
- **Opsi A: Autoload Baru `WorldResourceManager` (`res://scripts/world/world_resource_manager.gd`)**
- **Opsi B: Perluasan `GameManager` (`res://scripts/core/game_manager.gd`)**

**Evaluasi Arsitektural Mendalam:**
1. **Prinsip Tanggung Jawab Tunggal (Single Responsibility Principle - SRP):**
   - Pola proyek Buku Resep 2045 yang telah berhasil diterapkan pada `INV-001`, `BOOK-001`, dan `GARD-001` adalah memecah domain gameplay ke dalam Autoload spesialis:
     - `InventoryManager`: Khusus mengelola item, tumpukan, tas, peti, dan transfer atomik.
     - `RecipeManager`: Khusus mengelola definisi resep, buku resep, status pelacakan, dan agregasi stok bebas.
     - `GardenManager`: Khusus mengelola petak, kelembapan, nutrisi, titik tanam, pertumbuhan bayam, alat, dan kapasitas air penyiram.
   - Domain sumber dunia (wild foraging jagung & temu kunci, sumur air, cadangan darurat, kalender hari, pemulihan istirahat) adalah satu kesatuan fungsional yang sangat koheren. Menempatkannya pada `WorldResourceManager` menjaga SRP secara murni.
2. **Menghindari Anti-Pattern "God Object" pada `GameManager`:**
   - Sesuai cetak biru arsitektur `PROJECT.md` baris 7, `GameManager` dirancang sebagai koordinator siklus hidup aplikasi tingkat tinggi (scene transition, modal menu stack, pause state, game over/ending P0).
   - Memasukkan logika detail seperti pelacakan kuota jagung, formula cadangan benih darurat, dan timer 720 detik ke dalam `GameManager` akan mencemari `GameManager` menjadi objek monolitik raksasa yang sulit diuji dan rentan terhadap regresi saat task `UI-001` atau `SAVE-001`.
3. **Kepatuhan Terhadap Kontrak Save/Load (`SAVE-001` & `CONTENT.md` § 12):**
   - `CONTENT.md` § 12 membagi snapshot ke dalam entitas terpisah:
     - `World`: `Indeks hari, waktu aktif, wadah awal diambil, flag catatan, flag dialog, meal_used`
     - `Resource`: `ID dunia, hari terakhir dipanen, status visual/pending reset`
   - Dengan `WorldResourceManager`, method `get_save_snapshot()` dan `load_save_snapshot(data: Dictionary)` dapat langsung menghasilkan dan memulihkan segmen `"world"` dan `"resources"` secara mandiri dan modular.
4. **Isolasi Pengujian Headless (Testability):**
   - `test_world.gd` dapat menguji `WorldResourceManager` secara murni tanpa perlu menginisialisasi sistem UI kompleks atau transisi scene Godot.

**Kesimpulan Arsitektur:**  
Direkomendasikan secara definitif untuk membuat **Autoload baru `WorldResourceManager`** (`res://scripts/world/world_resource_manager.gd`) dan mendaftarkannya pada `project.godot` di bawah `[autoload]`.

---

## 3. Caveats

1. **Implementasi `KitchenManager` Belum Tersedia (Pra-COOK-001):**
   Pada milestone `WORLD-001`, modul memasak dapur (`KitchenManager`) belum diimplementasikan (berada pada milestone `COOK-001`). Oleh karena itu, pengecekan guard `"istirahat ditolak saat job dapur aktif"` pada `WorldResourceManager` harus dirancang dengan antarmuka defensif:
   - Jika `KitchenManager` tidak ada di SceneTree (atau bernilai null), anggap tidak ada job memasak aktif (izinkan istirahat).
   - Menyediakan hook atau dependency injection `set_kitchen_manager()` agar test suite dapat menyuntikkan mock kitchen manager untuk memvalidasi penolakan saat job dapur aktif (T39.4).
2. **Pencahayaan Statis pada P0:**
   Sesuai `CONTENT.md` § 9 baris 162, visual pencahayaan P0 menggunakan pencahayaan sore stabil terinspirasi Firewatch. Pergantian hari aktif tidak memerlukan simulasi pergerakan matahari 24 jam realistis atau sistem malam gelap gulita, melainkan cukup transisi fade visual atau notifikasi hari baru yang jujur.
3. **Koordinasi Kapasitas Penyiram dengan `GardenManager`:**
   `GardenManager` sudah memiliki properti `watering_can_water: int` dan method `refill_water()`. Aksi isi ulang sumur pada `water_home` harus memanggil `GardenManager.refill_water()` agar tidak terjadi duplikasi state volume air antar-manager.

---

## 4. Conclusion

1. **Kasur Tidur (`bed_home`)**:
   - Berada di posisi `(-2, 0, 0)` di dalam rumah dengan Area3D interaksi Layer 3 (bitmask 4) ber-prompt `[E] Istirahat`.
   - Interaksi tidur memajukan kalender (`day_index += 1`), mereset waktu aktif harian (`day_active_time = 0.0`), dan memulihkan kuota panen harian node jagung dan temu kunci.
   - **Invarian mutlak:** Istirahat sama sekali **tidak mengeksekusi simulasi kebun 720 detik**, sehingga kelembapan tanah, nutrisi, dan pertumbuhan tanaman bayam dipertahankan 100% tanpa pengurangan atau risiko kematian tanaman.
2. **Arsitektur Test Suite `tests/suites/test_world.gd` (Suite 10)**:
   - Terstruktur ke dalam 4 kelompok pengujian:
     - `T09`: Cadangan darurat (syarat wadah awal, penolakan jika ada benih di tas/peti, penolakan jika ada tanaman hidup di kebun, pemberian 4 benih saat macet total, proteksi tas penuh).
     - `T37`: Isi ulang air sumur (tahan 2.0s komitmen penuh 10/10, lepas < 2.0s batal tanpa biaya, penolakan saat air sudah 10/10, proteksi spam).
     - `T38`: Foraging harian (1 jagung/temu kunci per hari, penolakan panen kedua di hari yang sama, penolakan tas penuh, independensi node).
     - `T39`: Tidur & siklus hari (kemajuan hari, reset waktu, pemulihan sumber, invarian nol penalti tanaman, penolakan saat memasak aktif, siklus alami 720s, roundtrip save snapshot, integrasi scene graybox).
   - Terintegrasi penuh ke `tests/test_runner.gd` sebagai Suite 10 dengan target 0 failure.
3. **Rekomendasi Arsitektur Manager**:
   - Dibuat sebagai **Autoload terpisah `WorldResourceManager`** (`res://scripts/world/world_resource_manager.gd`) yang didaftarkan di `project.godot`.
   - Menjaga prinsip SRP, mencegah bloating pada `GameManager`, mematuhi kontrak save envelope `SAVE-001`, dan memudahkan penulisan tes unit terisolasi.

---

## 5. Verification Method

Untuk memverifikasi secara independen seluruh temuan dan cetak biru arsitektur ini:

1. **Pemeriksaan Keberadaan & Properti Landmark di Scene Graybox:**
   - Buka `scripts/tools/build_level_graybox.gd` baris 198–205 (`bed_home`), 238–244 (`water_home`), 256–262 (`reserve_home`), 286–292 (`resource_jagung_01`), 306–314 (`resource_temu_kunci_01`).
   - Periksa `tests/suites/test_interaction.gd` baris 244–270 untuk membuktikan bahwa 12 landmark (termasuk `bed_home`) telah diverifikasi oleh test suite eksisting.
2. **Pemeriksaan Status Test Suite Eksisting (Baseline Regression Check):**
   - Jalankan perintah CLI headless:
     ```powershell
     & "C:\Users\HP\.local\bin\godot.exe" --headless --script tests/test_runner.gd
     ```
   - Hasil harus menampilkan `Assertions Passed: 1078`, `Assertions Failed: 0`, `Exit Code: 0`.
3. **Pemeriksaan Kontrak Otoritatif Invarian Istirahat:**
   - Periksa `docs/CONTENT.md` § 9 baris 164.
   - Periksa `docs/TASKS.md` § 3 baris 91–93 (`WORLD-001`).
   - Periksa `AGENTS.md` § 4.
4. **Kondisi Invalidasi (Invalidation Conditions):**
   - Temuan ini tidak valid jika implementasi tidur di masa mendatang memanggil `GardenManager.simulate_process(720.0)` sehingga kelembapan kebun berkurang saat tidur.
   - Temuan ini tidak valid jika `WorldResourceManager` digabungkan ke `GameManager` dan menyebabkan tes unit `test_world.gd` membutuhkan dependensi scene/UI yang tidak terkait.
