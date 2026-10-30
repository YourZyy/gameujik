# Laporan Selesai: Sumber Daya Dunia, Foraging, Cadangan, Istirahat & Kalender (WORLD-001)

Dokumen ini mencatat penyelesaian implementasi milestone WORLD-001 sesuai aturan kerja `AGENTS.md` § 6.

## Identitas

- **ID task:** WORLD-001
- **Judul:** Sumber Daya Dunia, Foraging Liar, Stasiun Air, Benih Cadangan Kontekstual, Kalender Hari dan Istirahat Tidur
- **Tanggal selesai:** 28 Oktober 2026
- **Agent/pelaksana:** orchestrator_gen6 (Project Orchestrator Hierarchy: worker_world_001_v2, reviewer_world_001_1, reviewer_world_001_2, challenger_world_001_1, challenger_world_001_2, auditor_world_001)
- **Tahap produk:** P0 (Foraging harian jagung & temu kunci 1x/hari, pengisian air 10/10 aksi tahan 2.0s, cadangan darurat terkunci anti-eksploitasi, siklus hari 720s, tidur kasur memajukan hari dengan invarian non-decay tanaman, prompt kontekstual HUD, Suite 10 TestWorld T09/T37/T38/T39)
- **Status:** Selesai (Lulus 100% verifikasi headless: 1,233 asersi test runner + 478 asersi stress invariants + 174 asersi stress adversarial challenges, 0 gagal, exit code 0)
- **Versi sumber/build:** Git working tree lokal, Godot 4.7.2-stable official

## Tujuan dan pemicu

Sesuai spesifikasi `PRD.md` FR09 & FR10, `docs/TASKS.md` (bagian WORLD-001), `docs/CONTENT.md` § 5, § 6, § 9, § 11, § 12, `docs/PROTOTYPE.md` § 5.1, dan kasus uji `docs/TEST_PLAN.md` T09, T37, T38, T39:
1. Pemain membutuhkan sumber bahan baku liar di dunia untuk melengkapi resep Sayur Bening Bayam dan Jagung, yaitu tanaman jagung (`resource_jagung_01` $\rightarrow$ `ingredient_jagung`) dan tanaman herbal temu kunci (`resource_temu_kunci_01` $\rightarrow$ `ingredient_temu_kunci`). Keduanya wajib dibatasi kuota 1x pemetikan per hari kalender agar loop pencarian harian bermakna.
2. Pemain membutuhkan stasiun pengisian air sumur/dapur (`water_home`) yang mengisi ulang kapasitas alat penyiram (`watering_can_water`) dari 0 s/d 10 unit melalui interaksi tahan tombol selama 2.0 detik, dengan perlindungan pembatalan aman dan pencegahan spam tahan (`MUST_RELEASE`).
3. Pemain yang mengalami kebuntuan (*softlock*) akibat kehilangan benih/pupuk sebelum panen pertama membutuhkan kotak cadangan darurat pekarangan (`reserve_home`). Cadangan ini wajib memiliki sistem penguncian anti-eksploitasi yang ketat: terkunci hingga starter kit diambil, terkunci jika masih ada stok benih di tas/peti, terkunci jika ada tanaman hidup di petak pekarangan, dan menyalurkan bantuan bertingkat (benih bayam $\rightarrow$ kompos $\rightarrow$ pupuk) secara idempotent tanpa duplikasi.
4. Game membutuhkan sistem kalender siklus hari alami (720 detik per hari) dan tempat tidur rumah (`bed_home`) untuk beristirahat hingga pagi berikutnya. Tidur kasur memajukan kalender ke hari berikutnya dan mereset kuota foraging tanpa mendegradasi kelembapan tanah, nutrisi, atau timer pertumbuhan tanaman yang sedang berjalan (*agricultural non-decay invariance*).
5. Tidur kasur wajib menolak transisi istirahat jika proses memasak di dapur sedang aktif guna mencegah korupsi state memasak.
6. Seluruh landmark interaksi dunia wajib memiliki umpan balik prompt HUD dinamis diegetik dan respons visual 3D yang jujur dan konsisten.

## Ruang lingkup

Ruang lingkup yang diselesaikan dalam task ini:
- `scripts/world/world_resource_manager.gd`:
  - Autoload singleton `WorldResourceManager` yang mengelola kalender hari (`current_day`, `day_active_time`, konstanta `DAY_DURATION = 720.0s`).
  - Penanganan akumulasi waktu `_process(delta)` yang otomatis terhenti saat konteks modal aktif (`InputManager.is_simulation_paused()`).
  - Pemetaan sumber foraging: `resource_jagung_01` $\rightarrow$ `ingredient_jagung`, `resource_temu_kunci_01` $\rightarrow$ `ingredient_temu_kunci`.
  - Pelacakan kuota harian via kamus `last_harvested_day` dan verifikasi kapasitas inventaris atomik (`add_item` dengan sisa 0).
  - Logika cadangan darurat kontekstual bertingkat (`can_claim_emergency_reserve`, `claim_emergency_reserve`) dengan validasi peti, tas, dan kuadran petak.
  - Pengisian air sumur (`can_refill_water`, `refill_water`) yang terhubung langsung dengan `GardenManager.watering_can_water` berkapasitas 10 unit.
  - Transisi istirahat tidur kasur (`can_sleep`, `sleep_and_advance_day`) dengan penguncian aktivitas dapur dan emisi sinyal `day_advanced`, `rest_completed`, dan `foraging_nodes_refreshed`.
  - Serialisasi dan pemulihan snapshot envelope v1 (`get_save_snapshot`, `load_save_snapshot`).
- `scripts/inventory/inventory_slot.gd`:
  - Penambahan helper `set_item(p_item_id: String, p_count: int)` yang menjaga enkapsulasi setter slot.
- `scripts/inventory/items_data.gd`:
  - Penambahan helper `get_item_name(item_id: String) -> String` untuk resolusi alias dan teks notifikasi lokal bahasa Indonesia.
- `scripts/main.gd`:
  - Penyambungan landmark dunia: `resource_jagung_01`, `resource_temu_kunci_01`, `reserve_home`, `bed_home`, `water_home`.
  - Respons visual: penonaktifan dan pengaktifan mesh tanaman liar saat status foraging berubah (`foraging_state_changed`).
- `scripts/ui/hud.gd`:
  - Format teks prompt kontekstual reticle dinamis untuk seluruh landmark dunia (`[E] Petik Jagung`, `[E] Jagung (Sudah Dipanen)`, `[E] Petik Temu Kunci`, `[E] Temu Kunci (Sudah Dipanen)`, `[Tahan E 2s] Isi Air Penyiram (X/10)`, `[E] Air Penyiram Penuh (10/10)`, `[E] Periksa Cadangan`, `[E] Istirahat Sampai Besok`).
  - Penyambungan ke sinyal notifikasi `WorldResourceManager` (`action_failed`, `action_success`).
- `tests/suites/test_world.gd`:
  - Suite 10 komprehensif (25 metode pengujian, 886 baris) mencakup T09.1–T09.10 (Cadangan Darurat), T37.1–T37.4 (Stasiun Air & Hold Controller), T38.1–T38.4 (Foraging Harian), dan T39.1–T39.7 (Kalender, Tidur Kasur, Non-Decay Tanaman, Integrasi HUD & Graybox).
- `tests/stress_world_invariants.gd` & `tests/adversarial_world_001_stress.gd`:
  - Harness uji stres empiris adversarial mencakup 478 + 174 asersi tambahan untuk menguji saturasi kuota 100 panggilan, full bag boundary, fuzzed ID, lockout memasak, dan multi-day sleep zero-decay.

## Perubahan dan perilaku akhir

1. **Foraging Harian (T38):**
   - Pemain mendekati `resource_jagung_01` atau `resource_temu_kunci_01` dan menekan `[E]`.
   - Pemain menerima tepat 1x bahan baku terkait ke dalam tas.
   - Tanaman di dunia menyembunyikan mesh visualnya, dan prompt reticle berubah menjadi `[E] <Nama> (Sudah Dipanen)`.
   - Menekan `[E]` kembali pada hari yang sama menolak pemetikan dan menampilkan pesan umpan balik: *"Sumber ini sudah diambil hari ini. Tunggu besok."*
   - Jika tas penuh (12/12 slot), pemetikan ditolak secara atomik tanpa membuang kuota harian.
2. **Stasiun Pengisian Air (T37):**
   - Pemain mendekati `water_home` dan menahan tombol interaksi `[E]` selama 2.0 detik.
   - Reticle HUD menampilkan progres bar pengisian melingkar/horizontal.
   - Melepas tombol sebelum 2.0 detik membatalkan pengisian tanpa mengubah sisa air.
   - Pada detik ke-2.0, kapasitas air penyiram diisi penuh menjadi 10/10 unit (`GardenManager.watering_can_water = 10`), dan controller masuk status `MUST_RELEASE` untuk mencegah eksekusi ganda tanpa melepas tombol.
   - Jika air sudah 10/10, interaksi ditolak dengan pesan: *"Kondisi cukup. Air sudah penuh."*
3. **Cadangan Darurat Anti-Eksploitasi (T09):**
   - Pemain membidik `reserve_home` dan menekan `[E]`.
   - Jika starter kit belum diambil dari peti awal, klaim ditolak dengan pesan edukatif: *"Buka dan ambil perlengkapan di peti pekarangan terlebih dahulu."*
   - Jika pemain masih memiliki benih bayam di tas atau peti, atau masih ada tanaman bayam hidup di salah satu dari 4 kuadran petak, klaim ditolak dengan panduan jujur (misal: *"Tanaman di petak masih dapat tumbuh dan menghasilkan benih saat dipanen."*).
   - Saat benar-benar kehabisan benih dan tanaman, cadangan menyalurkan 4x `seed_bayam`.
   - Begitu benih tersedia namun tanah belum diberi pembenah dan kompos habis, cadangan menyalurkan 1x `soil_compost`.
   - Saat tanah siap namun nutrisi $< 20$ dan pupuk habis, cadangan menyalurkan 1x `fertilizer_basic`.
   - Klaim berulang setelah bantuan diserahkan langsung ditolak (idempotent).
4. **Kalender Hari dan Istirahat Tidur (T39):**
   - Kalender berjalan secara kontinu dengan laju 720 detik per hari in-game, terhenti saat membuka UI modal.
   - Pemain berinteraksi dengan kasur `bed_home` untuk istirahat.
   - Jika dapur sedang memasak, istirahat ditolak dengan pesan: *"Selesaikan atau batalkan proses memasak dahulu sebelum istirahat."*
   - Saat berhasil tidur, `current_day` bertambah 1, `day_active_time` kembali ke 0.0, sumber foraging kembali pulih dan mesh 3D muncul kembali.
   - **Invarian Pertanian Non-Decay:** Tidur kasur tidak mengeksekusi simulasi penguapan air atau penuaan petak, menjamin tanah dan tanaman pemain tidak membusuk, kering, atau rusak saat tidur.

## File yang ditambahkan atau diubah

| Path Relatif | Perubahan | Tujuan |
|---|---|---|
| `scripts/world/world_resource_manager.gd` | Ditambahkan (401 baris) | Autoload singleton pengelola kalender, foraging, air, cadangan, tidur, dan snapshot save |
| `scripts/inventory/inventory_slot.gd` | Diubah (+4 baris) | Penambahan helper `set_item(p_item_id, p_count)` untuk isolasi pengujian slot |
| `scripts/inventory/items_data.gd` | Diubah (+9 baris) | Penambahan helper `get_item_name(item_id)` untuk resolusi alias dan nama lokal |
| `scripts/main.gd` | Diubah (+40 baris) | Integrasi landmark dunia 3D, sinyal visual mesh foraging, dan event binding |
| `scripts/ui/hud.gd` | Diubah (+35 baris) | Format prompt kontekstual dinamis landmark dan binding sinyal feedback toast |
| `tests/suites/test_world.gd` | Ditambahkan (886 baris) | Suite 10 pengujian otomatis T09, T37, T38, T39 (25 kasus uji) |
| `tests/test_runner.gd` | Diubah (+4 baris) | Registrasi Suite 10 `TestWorld` ke test runner headless utama |
| `tests/stress_world_invariants.gd` | Ditambahkan (362 baris) | Harness adversarial challenger 2 (8 domain challenge, 478 asersi) |
| `tests/adversarial_world_001_stress.gd` | Ditambahkan (284 baris) | Harness adversarial challenger 1 (10 stress vectors, 174 asersi) |

## Verifikasi yang benar-benar dilakukan

| ID Pemeriksaan | Lingkungan / Input | Tindakan | Hasil Nyata | Status |
|---|---|---|---|---|
| `CHK-WLD-01` | Godot 4.7.2 Headless | `godot --headless --path . --script res://tests/test_runner.gd` | 1,233 asersi lulus, 0 gagal, 10 suite lulus, exit code 0 | LULUS |
| `CHK-WLD-02` | Godot 4.7.2 Headless | `godot --headless --path . --script res://tests/stress_world_invariants.gd` | 478 asersi lulus, 0 gagal, seluruh 8 domain challenge lulus, exit code 0 | LULUS |
| `CHK-WLD-03` | Godot 4.7.2 Headless | `godot --headless --path . --script res://tests/adversarial_world_001_stress.gd` | 174 asersi lulus, 0 gagal, seluruh 10 stress vectors lulus, exit code 0 | LULUS |
| `CHK-WLD-T09` | Suite 10 (T09.1–T09.10) | Uji prerequisite starter, penguncian benih/peti/tanaman, kuota 4 benih, kompos, pupuk, atomisitas tas penuh | 10 uji lulus, pesan feedback sesuai CONTENT § 11 | LULUS |
| `CHK-WLD-T37` | Suite 10 (T37.1–T37.4) | Uji isi air 10/10 tahan 2.0s, batal tengah jalan, tolak saat penuh, anti-spam MUST_RELEASE | 4 uji lulus, kapasitas terisi tepat ke 10 | LULUS |
| `CHK-WLD-T38` | Suite 10 (T38.1–T38.4) | Uji kuota harian jagung & temu kunci, tolak pemetikan kedua di hari sama, tolak saat tas penuh | 4 uji lulus, kuota bertahan saat gagal | LULUS |
| `CHK-WLD-T39` | Suite 10 (T39.1–T39.7) | Uji tidur kasur memajukan hari, pulihkan foraging, non-decay kebun, tolak saat masak aktif, 720s cycle, save roundtrip | 7 uji lulus, kelembapan/nutrisi 100% terjaga | LULUS |
| `AUDIT-WLD-01` | Forensic Integrity Audit | Static analysis AST, regex detection hardcoded strings/facades, dependency review | Tidak ditemukan kecurangan, stubs, atau bypass; verdict: CLEAN | LULUS |

## Kriteria selesai

- [x] **Tiap sumber memberi hasil benar sekali per hari:** Jagung menghasilkan 1 `ingredient_jagung` dan Temu Kunci menghasilkan 1 `ingredient_temu_kunci` sekali per hari. Pemetikan kedua ditolak hingga pergantian hari (T38).
- [x] **Cadangan tidak dapat diambil saat stok masih ada:** Gated oleh starter box, stok benih tas/peti, dan tanaman hidup pada kuadran petak. Menyalurkan benih/kompos/pupuk hanya saat benar-benar dibutuhkan tanpa duplikasi (T09).
- [x] **Istirahat memulihkan sumber tanpa mengubah tanaman:** Tidur kasur memajukan hari kalender dan mereset sumber foraging tanpa memicu penguapan air atau degradasi pertumbuhan tanaman di kebun pekarangan (T39).
- [x] **Reset tidak tampak mendadak di depan mata:** Pemulihan sumber hanya terjadi saat transisi hari (tidur kasur atau pergantian siklus 720s), dengan pembaruan visual mesh yang sinkron (T39).
- [x] **Pengisian air berfungsi dengan aksi tahan 2.0s:** Mengisi penuh kapasitas penyiram menjadi 10/10 dengan pengaman pembatalan dan pencegahan spam klik/tahan (T37).

## Dampak, kompatibilitas dan keterbatasan

- **Dampak Arsitektur & Autoload:** `WorldResourceManager` terpasang sebagai autoload mandiri di `project.godot`. Script tidak mendeklarasikan `class_name` untuk mencegah tabrakan namespace singleton pada Godot 4.7.
- **Kompatibilitas Save System:** Mendukung kontrak snapshot envelope v1 `SaveManager` (`get_save_snapshot` & `load_save_snapshot`), siap diintegrasikan pada milestone `SAVE-001`.
- **Keterbatasan yang diketahui:** Pada penutupan test runner headless, Godot mencatat warning ObjectDB instance leaks yang wajar karena instansiasi 10 suite pengujian akumulatif tanpa explicit destructor sebelum proses exit; ini tidak memengaruhi runtime game reguler.

## Tindak lanjut dan handoff

- **Task berikutnya:** `COOK-001` (Reservasi dan persiapan memasak di dapur `station_kitchen_home`).
- **Prasyarat yang telah terpenuhi:** Bahan baku bayam dari kebun (`GARD-002`), jagung dan temu kunci dari dunia (`WORLD-001`), serta inventaris tas/peti (`INV-001`) dan resep Sayur Bening Bayam dan Jagung (`BOOK-001`) telah tersedia lengkap.
- **Catatan untuk COOK-001:** `WorldResourceManager.can_sleep()` telah dilengkapi kontrak pengecekan status memasak (`KitchenManager.is_cooking_active()`, `is_job_active()`). Pastikan `KitchenManager` mengimplementasikan fungsi-fungsi tersebut secara konsisten.

## Penutupan catatan

Laporan ini ditautkan pada `docs/PROJECT_STATUS.md`, task ditandai `SELESAI` pada `docs/TASKS.md`, dan deskripsi status pekerjaan terakhir telah dimutakhirkan.
