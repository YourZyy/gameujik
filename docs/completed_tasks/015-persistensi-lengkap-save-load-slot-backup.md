# Laporan Task Selesai: SAVE-001 — Persistensi Lengkap Save/Load, Checkpoint, Validasi Envelope, Snapshot Swap, dan Error Recovery

Dokumen ini mencatat penyelesaian milestone SAVE-001 sesuai dengan standar pelaporan AGENTS.md dan TEMPLATE.md.

## Identitas

- **ID task:** SAVE-001
- **Judul:** Checkpoint manual/auto, validasi envelope v1, backup fallback, atomic temp write, dan pemulihan posisi aman
- **Tanggal selesai:** 29 Oktober 2026
- **Agent/pelaksana:** worker_save_001_gen10 (implementer, qa, specialist)
- **Tahap produk:** P0
- **Status:** Selesai
- **Versi sumber/build:** Godot Engine v4.7.2.stable.official.ed1daf0bf, branch `main` / commit lokal (working tree)

## Tujuan dan pemicu

Pemain memerlukan sistem persistensi permainan yang andal, aman dari kerusakan berkas, serta mampu memulihkan seluruh keadaan dinamis dunia (posisi pemain, orientasi kamera, inventaris tas, peti penyimpanan rumah, status petak kebun 4-tahap, kalender dan siklus foraging dunia, status persiapan/pemasakan dapur, buku resep, dan progres dialog warga) secara 100% konsisten antar-sesi bermain. Sesuai PRD FR15, PROTOTYPE.md § 5 & § 7, CONTENT.md § 11, § 12, § 14, dan TEST_PLAN.md (T14, T16, T17, T22, T46–T50), sistem penyimpanan tidak boleh memulihkan hanya posisi pemain, tidak boleh membiarkan proses memasak/pertumbuhan melompat saat aplikasi mati (offline progress), wajib mencegah duplikasi materi/output hasil panen/masakan, wajib melindungi berkas dari kegagalan tulis atau crash listrik (atomic write `.tmp` -> `.json`), serta memisahkan pengaturan pengguna (`settings.cfg`) dari data save game agar tidak tertimpa saat memuat checkpoint lama atau memulai Game Baru.

Kondisi awal sebelum task ini: Tiap manajer subsistem (InventoryManager, GardenManager, WorldResourceManager, KitchenManager, RecipeManager, DialogueManager, dan PlayerController) telah memiliki metode snapshot internal `get_save_snapshot()` dan `load_save_snapshot()`, namun belum terdapat autoload terpadu yang mengoordinasikan penulisan berkas fisik disk, kalkulasi integritas checksum SHA-256, rotasi berkas cadangan (`.bak`), validasi envelope skema v1 pra-swap dua fase (*two-phase commit*), resolusi tombol Lanjutkan (*Continue*), dan isolasi berkas konfigurasi pengaturan.

## Ruang lingkup

Pekerjaan yang diselesaikan dalam cakupan SAVE-001 mencakup:
1. **Autoload Singleton `SaveManagerClass` (`scripts/save/save_manager.gd`):**
   - Registrasi sebagai Autoload singleton `SaveManager` di `project.godot`.
   - Pipeline penulisan atomik disk via `.tmp` -> rotasi `.bak` -> penggantian target utama `.json` untuk mencegah berkas terpotong/rusak saat crash (*crash-resilient write*).
   - Envelope v1 dengan header metadata terstruktur: `schema_version` (1), `game_version` ("0.2.0"), `slot_type`, `revision` (penghitung sekuensial monotonik), `timestamp`, `timestamp_iso`, dan `checksum` SHA-256 dari representasi JSON kanonikal payload.
   - *Two-Phase Commit Save/Load Pipeline*: Fase 1 *pre-flight validation* memeriksa kelengkapan seksi wajib, validitas ID item terhadap registri resmi `ItemsData`, batasan tumpukan slot (0..20), struktur petak kebun, rentang state dapur, nilai hari dunia, dan koordinat pemain sebelum satu pun status *live singleton* dimutasi (*zero half-loaded world*).
   - Mekanisme *Fail-Safe Backup Fallback* (.bak): Jika berkas utama `save_manual.json` atau `save_autosave.json` hilang, 0-byte, atau korup (JSON parsing error / checksum mismatch), SaveManager secara otomatis beralih memuat berkas `.bak`, memancarkan sinyal `save_recovered_from_backup`, dan melakukan penyembuhan otomatis (*self-healing*) dengan menulis ulang berkas utama yang valid.
   - Sanitasi Koordinat & Pengalihan Posisi Aman (T22): Jika posisi pemain pada snapshot bernilai NaN, Inf, atau berada di luar batas level fiksi (X: [-42, 42], Z: [-37, 47], Y: [-5, 50]), koordinat secara otomatis dialihkan ke titik aman `SAFE_RETURN_POSITION` (0.0, 0.0, 8.0) di pekarangan rumah dengan emisi sinyal `player_position_sanitized`.
   - Pencegahan Kemajuan Offline Memasak (T14): Jika permainan disimpan saat pekerjaan dapur berada pada status `COOKING` (3), saat dimuat di dunia 3D status secara deterministik diubah menjadi `PAUSED` (4) dengan sisa durasi yang identik, mencegah masakan selesai sendiri di latar belakang tanpa kehadiran pemain.
   - Resolusi Slot Lanjutkan (*Continue Resolution* / T48): API `get_continue_slot()` membandingkan metadata revisi monotonik dan timestamp antara slot `manual` dan `autosave`, memilih revisi valid terbaru, sekaligus mengizinkan pemilihan slot manual secara eksplisit.
   - Isolasi Pengaturan Pengguna (`user://settings.cfg` / T49, T52): Menggunakan Godot `ConfigFile` terpisah untuk menyimpan sensitivitas mouse, head bob, FOV (default 80°), skala UI (default 1.0), window mode, volume audio (master, musik, SFX), dan subtitle; nilai pengaturan tetap utuh saat game dimuat, Game Baru dimulai, atau bahkan jika berkas save korup.
2. **Pengujian Komprehensif Headless (Suite 19 `tests/suites/test_save.gd`):**
   - 25 metode pengujian terstruktur dalam 9 grup kasus uji yang memverifikasi T14, T16, T17, T22, T46, T47, T48, T49, dan T50.

Batas task: Antarmuka grafis layar jeda (Pause Menu), menu Pengaturan grafis, dan pemilih slot UI akan diintegrasikan pada milestone UI-001.

## Perubahan dan perilaku akhir

1. **Pipeline Penulisan Atomik & Integritas Checksum:**
   - Saat `SaveManager.save_game(slot_type)` dipanggil:
     a. Payload dikumpulkan dari seluruh manajer subsistem dan pemain.
     b. Canonical JSON dihasilkan dengan kunci terurut secara leksikografis dan format angka deterministik, lalu dihitung hash SHA-256-nya.
     c. Data ditulis ke berkas sementara `<slot>.json.tmp` dan di-flush ke disk.
     d. Berkas sementara diverifikasi ada dan tidak 0-byte.
     e. Berkas sasaran lama (jika ada) dirotasi menjadi `<slot>.json.bak`.
     f. Berkas `.tmp` di-rename menjadi sasaran utama `<slot>.json`.
     g. Jika penulisan disimulasikan gagal (`simulate_write_failure = true`), berkas sasaran utama yang lama tetap utuh dan pesan error jujur ditampilkan tanpa crash.
2. **Pertahanan Muat Data & Pemulihan Cadangan:**
   - Saat `SaveManager.load_game(slot_type)` dipanggil:
     a. Mencoba membaca dan memvalidasi envelope dari sasaran utama.
     b. Jika sasaran utama rusak (JSON terpotong, byte korup, 0-byte, atau checksum tidak cocok), sistem mencoba membaca `<slot>.json.bak`.
     c. Jika `.bak` valid, muat data berhasil, sinyal `save_recovered_from_backup` dipancarkan, dan berkas utama langsung ditulis ulang secara atomik (*self-healing*).
     d. Jika berkas utama dan `.bak` sama-sama rusak, sistem menolak muat secara bersih dengan pesan error yang jujur dan menjaga state permainan saat ini tanpa mutasi parsial.
3. **Two-Phase Commit Pra-Swap Dunia:**
   - Validasi payload mengevaluasi seksi `player`, `inventory`, `gardening`, `world`, `cooking`, `recipe`, dan `dialogue`.
   - Menguji keabsahan setiap slot tas dan peti: jumlah item harus 0..20 dan ID item wajib terdaftar pada registri `ItemsDataClass` (misal item ilegal `laser_gun_99` atau stack 99 ditolak).
   - Bila ada ketidakcocokan, transaksi muat dibatalkan sebelum singleton memodifikasi memori.
4. **Isolasi Pengaturan `settings.cfg`:**
   - Pengaturan disimpan di `user://settings.cfg` dengan seksi `gameplay`, `video`, `audio`, dan `accessibility`.
   - Pemanggilan `load_game()` atau reset state dunia tidak menyentuh memori pengaturan.

## File yang ditambahkan atau diubah

| Path Relatif | Perubahan | Tujuan |
|---|---|---|
| `scripts/save/save_manager.gd` | Ditambahkan | Autoload singleton pengelola persistensi terpadu, pipeline atomik `.tmp` -> `.json`, rotasi `.bak`, checksum SHA-256, validasi envelope v1, sanitasi koordinat, resolusi slot, dan isolasi `settings.cfg`. |
| `tests/suites/test_save.gd` | Ditambahkan | Rangkaian pengujian komprehensif Suite 19 (25 metode uji dalam 9 grup) untuk T14, T16, T17, T22, T46, T47, T48, T49, T50. |
| `project.godot` | Diubah | Pendaftaran autoload singleton `SaveManager="*res://scripts/save/save_manager.gd"`. |
| `scripts/player/player_controller.gd` | Diubah | Penambahan metode `get_save_snapshot()` dan `load_save_snapshot()` dengan sanitasi batas wilayah fiksi X/Z/Y serta fallback ke titik aman `default_safe_return_position`. |
| `scripts/gardening/garden_manager.gd` | Diubah | Penyelarasan kontrak snapshot petak, tahap tumbuh 4-fase, dan nutrisi/kelembapan kebun. |
| `scripts/cooking/kitchen_manager.gd` | Diubah | Penyelarasan kontrak snapshot status dapur, origin manifest reservasi, wadah refund, dan penjaminan status jeda (PAUSED) saat dimuat dari disk. |
| `tests/test_runner.gd` | Diubah | Pendaftaran dan eksekusi Suite 19 (`TestSave`) pada test runner headless engine. |

## Verifikasi yang benar-benar dilakukan

Eksekusi verifikasi dijalankan langsung melalui CLI konsol Godot engine versi 4.7.2 headless (`godot_console.exe --headless --path . --script res://tests/test_runner.gd`) di lingkungan Windows 11 host.

| ID Pemeriksaan | Lingkungan / Input | Tindakan | Hasil Nyata | Status |
|---|---|---|---|---|
| `T14.SAVE-01` | Headless CLI Godot | Jalankan `test_t14_01_backpack_storage_and_tools_preservation` | 12 slot tas, 12 slot peti, kuantitas tumpukan, slot kosong, dan kepemilikan alat pulih 100% identik tanpa kehilangan atau duplikasi | LULUS |
| `T14.SAVE-02` | Headless CLI Godot | Jalankan `test_t14_02_paused_job_and_crop_growth_preservation_no_offline_progress` | Job memasak aktif dipulihkan sebagai status PAUSED (4), durasi masak bertahan di 12.5s, dan pertumbuhan tanaman tidak melompat secara offline | LULUS |
| `T16.SAVE-01` | Headless CLI Godot | Jalankan `test_t16_01_reject_snapshot_with_missing_mandatory_sections` | Snapshot tanpa salah satu seksi wajib (`inventory`, `gardening`, `world`, `cooking`, `recipe`, `dialogue`, `player`) ditolak pada fase validasi pra-swap | LULUS |
| `T16.SAVE-02` | Headless CLI Godot | Jalankan `test_t16_02_reject_snapshot_with_unknown_item_ids_and_illegal_counts` | Snapshot dengan ID item asing (`laser_gun_99`), stack melebihi batas (>20), atau hitungan negatif ditolak secara bersih | LULUS |
| `T16.SAVE-03` | Headless CLI Godot | Jalankan `test_t16_03_atomic_world_swap_all_or_nothing` | Validasi pra-swap yang gagal mempertahankan 100% state dunia live saat itu tanpa termutasi sebagian (*zero half-loaded world*) | LULUS |
| `T17.SAVE-01` | Headless CLI Godot | Jalankan `test_t17_01_fallback_to_bak_when_primary_save_file_corrupted` | Berkas utama yang korup secara otomatis memicu pemulihan dari berkas cadangan `.bak`, memancarkan sinyal pemulihan, dan melakukan *self-healing* berkas utama | LULUS |
| `T17.SAVE-02` | Headless CLI Godot | Jalankan `test_t17_02_clean_failure_when_both_primary_and_bak_are_corrupted` | Jika berkas utama dan `.bak` korup, sistem mengembalikan kegagalan bersih `ERR_FILE_CORRUPT` dengan pesan jujur tanpa crash | LULUS |
| `T17.SAVE-03` | Headless CLI Godot | Jalankan `test_t17_03_zero_byte_file_resilience` | Berkas 0-byte ditolak sebagai `EMPTY_FILE` dan dialihkan ke `.bak` cadangan secara mulus | LULUS |
| `T22.SAVE-01` | Headless CLI Godot | Jalankan `test_t22_01_redirect_nan_and_inf_coordinates_to_safe_spawn` | Koordinat pemain bernilai NaN atau Inf dialihkan secara deterministik ke `SAFE_RETURN_POSITION` (0.0, 0.0, 8.0) | LULUS |
| `T22.SAVE-02` | Headless CLI Godot | Jalankan `test_t22_02_redirect_out_of_bounds_coordinates_to_safe_spawn` | Koordinat di luar batas wilayah level (Y = -100 atau X = 500) dialihkan ke posisi aman pekarangan rumah | LULUS |
| `T22.SAVE-03` | Headless CLI Godot | Jalankan `test_t22_03_valid_coordinates_preserved_without_redirection` | Koordinat pemain yang sah dipertahankan persis tanpa pengalihan | LULUS |
| `T46.SAVE-01` | Headless CLI Godot | Jalankan `test_t46_01_garden_plot_and_crop_stages_restoration` | Struktur petak, kondisi cangkul/kompos, kelembapan/nutrisi, serta tahap tumbuh tanaman pulih akurat | LULUS |
| `T46.SAVE-02` | Headless CLI Godot | Jalankan `test_t46_02_kitchen_job_reservation_origin_and_refund_restoration` | Reservasi bahan masak, origin manifest, wadah refund, dan progres kompor pulih sempurna | LULUS |
| `T47.SAVE-01` | Headless CLI Godot | Jalankan `test_t47_01_atomic_write_creates_tmp_before_target` | Penulisan atomik menghasilkan berkas sementara `.tmp` sebelum menggantikan target sasaran | LULUS |
| `T47.SAVE-02` | Headless CLI Godot | Jalankan `test_t47_02_existing_save_unharmed_if_write_fails_midway` | Simulasi kegagalan tulis di tengah proses mempertahankan integritas berkas simpanan sebelumnya tanpa terpotong | LULUS |
| `T47.SAVE-03` | Headless CLI Godot | Jalankan `test_t47_03_temp_file_cleanup_on_failure` | Berkas sementara `.tmp` yang tidak valid langsung dibersihkan agar tidak meninggalkan residu sampah disk | LULUS |
| `T48.SAVE-01` | Headless CLI Godot | Jalankan `test_t48_01_separate_manual_and_autosave_slot_isolation` | Slot manual dan autosave terisolasi secara independen di berkas fisik disk yang terpisah | LULUS |
| `T48.SAVE-02` | Headless CLI Godot | Jalankan `test_t48_02_continue_selects_newest_revision_across_slots` | Resolusi Lanjutkan memilih slot dengan revisi sekuensial tertinggi antar-slot secara deterministik | LULUS |
| `T48.SAVE-03` | Headless CLI Godot | Jalankan `test_t48_03_explicit_manual_slot_selection_when_autosave_is_newer` | Pemilihan slot manual secara eksplisit tetap memuat data manual meskipun autosave memiliki revisi lebih baru | LULUS |
| `T48.SAVE-04` | Headless CLI Godot | Jalankan `test_t48_04_backup_creation_on_every_successful_overwrite` | Setiap operasi penimpaan simpanan sukses menghasilkan salinan cadangan `.bak` dari versi sebelumnya | LULUS |
| `T49.SAVE-01` | Headless CLI Godot | Jalankan `test_t49_01_settings_stored_in_standalone_config_file` | Pengaturan disimpan pada berkas ConfigFile mandiri `user://settings.cfg`, terpisah total dari save JSON | LULUS |
| `T49.SAVE-02` | Headless CLI Godot | Jalankan `test_t49_02_game_load_and_new_game_preserves_settings` | Operasi muat simpanan lama dan inisialisasi game baru tidak mengubah nilai pengaturan pengguna | LULUS |
| `T49.SAVE-03` | Headless CLI Godot | Jalankan `test_t49_03_settings_corruption_does_not_affect_save_game` | Kerusakan pada berkas pengaturan tidak memengaruhi validitas berkas save game dan fallback ke nilai default | LULUS |
| `T50.SAVE-01` | Headless CLI Godot | Jalankan `test_t50_01_comprehensive_p0_game_state_roundtrip` | Uji round-trip penuh seluruh state P0: simpan -> modifikasi memori -> muat menghasilkan state yang 100% identik | LULUS |
| `T50.SAVE-02` | Headless CLI Godot | Jalankan `test_t50_02_idempotent_multi_roundtrip` | Tiga siklus save-load berturut-turut mempertahankan konsistensi data secara idempotent tanpa penyimpangan floating point | LULUS |
| `REG.FULL` | Headless Godot CLI | `godot_console.exe --headless --path . --script res://tests/test_runner.gd` | **6.769 asersi lulus, 0 gagal, Exit Code 0** (seluruh 19 test suite aktif lolos 100%) | LULUS |

## Kriteria selesai

- [x] **Envelope dan versi skema v1:** Struktur envelope menyimpan `schema_version` (1), `game_version`, `revision`, `timestamp`, `checksum` SHA-256, dan payload terstruktur (T47).
- [x] **Slot manual, autosave, dan rotasi cadangan (.bak):** Dukungan slot terpisah dengan rotasi `.bak` otomatis saat penimpaan berkas (T48).
- [x] **Penulisan atomik tahan crash via berkas sementara (.tmp):** Operasi simpan menulis ke `.tmp` terlebih dahulu, memverifikasi integritas, baru merotasi dan mengganti target sasaran (T22, T47).
- [x] **Validasi pra-swap dua fase (*two-phase commit*):** Evaluasi integritas data lengkap dijalankan sebelum status dunia hidup digantikan, mencegah kondisi muat separuh (*half-loaded world*) (T16).
- [x] **Ketahanan data rusak dan pemulihan cadangan otomatis:** Fallback deterministik ke `.bak` jika berkas utama korup, disertai *self-healing* penyimpanan ulang (T17).
- [x] **Sanitasi posisi pemain dan pengalihan ke titik aman:** Koordinat NaN, Inf, atau out-of-bounds dialihkan secara aman ke `SAFE_RETURN_POSITION` pekarangan rumah (T22).
- [x] **Pemulihan seluruh entitas dinamis P0:** Seluruh state tas, peti, petak kebun, durasi dan jeda masak, origin manifest, wadah refund, kalender, sumber foraging, buku resep, dan dialog pulih 100% tanpa kemajuan offline (T14, T46, T50).
- [x] **Isolasi pengaturan pengguna (`settings.cfg`):** Preferensi gameplay, audio, video, dan aksesibilitas tersimpan di file terpisah dan terlindung dari siklus save/load (T49).

## Dampak, kompatibilitas dan keterbatasan

1. **Dampak Gameplay & Arsitektur:** Pemain kini dapat menyimpan progres secara manual maupun otomatis, keluar dari game, dan melanjutkannya kembali kapan saja dengan integritas data penuh. Tidak ada risiko kehilangan data akibat crash mendadak saat penulisan berkat mekanisme penulisan atomik `.tmp` dan rotasi cadangan `.bak`.
2. **Kompatibilitas Save:** Skema envelope dirancang dengan `schema_version = 1`. Jika di masa mendatang struktur save diperluas (misalnya penambahan resep baru atau event Karhutla), `SaveManager` memiliki gerbang versi yang siap menampung migrasi skema tanpa merusak save lama.
3. **Keterbatasan:** Tombol antarmuka grafis (UI) untuk memilih slot save/load dan dialog konfirmasi penimpaan akan dibangun pada milestone berikutnya (`UI-001`). Autoload `SaveManager` saat ini telah menyediakan seluruh backend API yang dibutuhkan oleh UI tersebut (`has_valid_save()`, `get_slot_metadata()`, `get_continue_slot()`, `save_game()`, `load_game()`, `load_settings()`, `save_settings()`).

## Tindak lanjut dan handoff

- **Task berikutnya:** `UI-001` (Kenyamanan Terpadu: Menu Awal, Pause, Pengaturan, Aksesibilitas, Navigasi Fokus Keyboard, dan Alur Error).
- **Prasyarat yang telah terpenuhi:** Seluruh backend persistensi permainan dan berkas konfigurasi mandiri (`settings.cfg`) telah siap dan teruji penuh pada SAVE-001.
- **Rujukan data:** `docs/TASKS.md` § UI-001, `docs/TEST_PLAN.md` (T18, T21, T28, T51–T54), dan `docs/UI_UX.md`.

## Penutupan catatan

Laporan ini telah ditautkan pada `docs/PROJECT_STATUS.md`, status task `SAVE-001` diperbarui menjadi `SELESAI` pada `docs/TASKS.md`, dan deskripsi status pekerjaan terakhir telah dimutakhirkan.
