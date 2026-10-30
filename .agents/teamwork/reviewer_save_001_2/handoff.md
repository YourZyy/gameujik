# Laporan Verifikasi & Review Independen: SAVE-001 (Persistensi Lengkap Save/Load, Checkpoint & Backup)

**Peninjau:** `reviewer_save_001_2` (Roles: Reviewer, Adversarial Critic)  
**Tanggal:** 29 Oktober 2026  
**Status Verdict:** **APPROVE**  
**Working Directory:** `.agents/teamwork/reviewer_save_001_2/`

---

## 1. Observation

### A. Eksekusi Independen Test Suite Headless Godot Engine
- **Perintah CLI:**
  ```powershell
  godot_console --headless --path . --script res://tests/test_runner.gd
  ```
- **Versi Engine:** `Godot Engine v4.7.2.stable.official.ed1daf0bf` (Windows 11 host).
- **Hasil Nyata (Verbatim Console Output):**
  ```
  ==================================================
  [TEST_RUNNER] Buku Resep 2045 — Headless Test Runner
  ==================================================
  ...
  ==================================================
  [SUITE 19] TestSave: Persistensi Lengkap, Validasi Envelope & Error Recovery (SAVE-001)
  ==================================================
  [SaveManager] Checkpoint utama rusak/hilang (user://test_save_sandbox/save_manual.json: INVALID_JSON). Mencoba .bak...
  [SaveManager] Checkpoint utama rusak/hilang (user://test_save_sandbox/save_manual.json: INVALID_JSON). Mencoba .bak...
  [SaveManager] Checkpoint utama rusak/hilang (user://test_save_sandbox/save_manual.json: EMPTY_FILE). Mencoba .bak...
  [PlayerController] Koordinat pemain out-of-bounds/NaN/Inf ([nan, 0.0, 8.0]). Dialihkan ke titik aman: (0.0, 0.0, 8.0)
  [PlayerController] Koordinat pemain out-of-bounds/NaN/Inf ([0.0, inf, 0.0]). Dialihkan ke titik aman: (0.0, 0.0, 8.0)
  [PlayerController] Koordinat pemain out-of-bounds/NaN/Inf ([0.0, -100.0, 0.0]). Dialihkan ke titik aman: (0.0, 0.0, 8.0)
  [PlayerController] Koordinat pemain out-of-bounds/NaN/Inf ([500.0, 0.0, 0.0]). Dialihkan ke titik aman: (0.0, 0.0, 8.0)
  ==================================================
  [TEST_RUNNER] SUMMARY:
    Assertions Passed: 6769
    Assertions Failed: 0
    RESULT: ALL SUITES PASSED (Exit Code: 0)
  ==================================================
  ```
- **Catatan Eksekusi:** Seluruh 19 test suite (`Suite 1` s/d `Suite 19`) aktif dieksekusi tanpa bypass. 6.769 asersi lulus dengan 0 kegagalan dan Exit Code 0.

### B. Pemeriksaan Integritas & Kode Sumber (Anti-Cheat & Integrity Audit)
1. **Tidak Ada Nilai Hardcoded / Dummy Implementations:**
   - `scripts/save/save_manager.gd`: Mengimplementasikan pembacaan dan penulisan berkas riil menggunakan `FileAccess`, manipulasi direktori `DirAccess`, parsing `JSON`, dan `ConfigFile` untuk pengaturan terpisah.
   - Perhitungan checksum SHA-256 menggunakan JSON kanonikal dengan kunci terurut leksikografis (`canonical_json()`, baris 429–453), bukan hash fiktif.
   - Pipeline penulisan atomik (`save_game()`, baris 88–155) menulis ke `.tmp`, memeriksa non-zero byte, merotasi berkas eksisting ke `.bak`, lalu merename `.tmp` menjadi target sasaran `.json`.
2. **Validasi Pra-Swap Dua Fase (*Two-Phase Commit*):**
   - Diperiksa pada `validate_save_payload()` (baris 258–320). Memeriksa seluruh 7 seksi wajib (`player`, `inventory`, `recipe`, `gardening`, `world`, `cooking`, `dialogue`).
   - Setiap slot tas (12) dan peti (12) divalidasi: kuantitas tumpukan harus `0 <= count <= 20` dan ID item wajib terdaftar di `ItemsDataClass.has_item()` (baris 273–293).
   - Singletons live hanya dimutasi setelah fase validasi lolos 100% (`apply_all_states()`, baris 375–406).
3. **Isolasi Pengaturan Pengguna:**
   - Pengaturan disimpan secara mandiri di `user://settings.cfg` via `ConfigFile` (`load_settings()`, baris 548–576; `save_settings()`, baris 577–593).
   - Pengaturan tidak tercampur dalam envelope save JSON dan terbukti tidak tertimpa saat memuat game lama atau saat reset dunia.
4. **Pencegahan Progres Memasak Offline (T14 / PROTOTYPE § 5):**
   - Pada `apply_all_states()`, baris 397–399:
     ```gdscript
     if int(kit.job_state) == 3: # COOKING
         kit.job_state = 4 # PAUSED
     ```
     Memastikan pekerjaan memasak aktif dipulihkan sebagai `PAUSED` sehingga tidak melompat selesai di latar belakang saat aplikasi ditutup.
5. **Sanitasi Koordinat & Pengalihan Titik Aman (T22):**
   - Diperiksa pada `scripts/player/player_controller.gd` (baris 521–534) dan fallback `SaveManagerClass._apply_player_snapshot()` (baris 416–427).
   - Nilai NaN, Inf, atau di luar batas level (X: [-42, 42], Z: [-37, 47], Y: [-5, 50]) secara deterministik dialihkan ke `SAFE_RETURN_POSITION` (0.0, 0.0, 8.0).

---

## 2. Logic Chain

1. **Premis 1 (Integritas Pengujian):** Pengujian unit tidak boleh menggunakan data tipuan, bypass, atau asersi palsu.
   - *Bukti:* Pemeriksaan pada `tests/suites/test_save.gd` (25 metode pengujian, 843 baris) membuktikan bahwa tes benar-benar memanipulasi disk riil di folder sandbox `user://test_save_sandbox/`, memverifikasi keberadaan fisik berkas `.tmp`, `.bak`, `.json`, serta memverifikasi mutasi dan isolasi state antar-manajer.
2. **Premis 2 (Ketahanan Terhadap Crash & Kerusakan Berkas):** Sistem penyimpanan tidak boleh merusak save eksisting jika proses simpan terputus di tengah jalan, dan wajib memulihkan data jika berkas utama rusak.
   - *Bukti:* Uji T47-02 membuktikan berkas lama tetap utuh ketika proses simpan gagal di tengah jalan (`simulate_write_failure = true`). Uji T17-01 membuktikan kegagalan parsing JSON pada berkas utama memicu fallback otomatis ke `.bak`, memancarkan sinyal `save_recovered_from_backup`, dan melakukan *self-healing* penulisan ulang berkas utama.
3. **Premis 3 (Integritas Status Permainan / Zero Half-Loaded World):** Jika berkas simpanan rusak sebagian (misalnya seksi hilang atau berisi item ilegal), status permainan yang sedang aktif di memori tidak boleh termutasi separuh jalan.
   - *Bukti:* Uji T16-03 membuktikan bahwa snapshot rusak ditolak saat *pre-flight validation* sebelum live singletons disentuh, sehingga inventaris dan kondisi dunia yang sedang aktif tetap 100% utuh (*all-or-nothing*).
4. **Premis 4 (Pemisahan Pengaturan):** Pengaturan kontrol/audio/video pengguna tidak boleh direset saat memuat checkpoint game atau memulai Game Baru.
   - *Bukti:* Uji T49-01 s/d T49-03 membuktikan preferensi FOV, sensitivitas, volume, dan subtitle tersimpan di `user://settings.cfg`, tidak terpengaruh oleh operasi save/load permainan, dan pulih ke default secara aman bila file config rusak tanpa merusak save game.
5. **Kesimpulan:** Arsitektur persistensi SAVE-001 memenuhi seluruh kriteria penerimaan PRD FR15, CONTENT.md § 11, 12, 14, PROTOTYPE.md § 5, 7, dan TEST_PLAN.md T14, T16, T17, T22, T46–T50.

---

## 3. Adversarial Stress-Test & Challenge Report

### Overall Risk Assessment: LOW

### Challenges & Findings

#### [Minor Finding] Rotasi Berkas Utama Korup ke `.bak` Saat *Self-Healing*
- **Asumsi yang Diuji:** Saat memulihkan dari `.bak` akibat berkas utama korup, `SaveManager.load_game()` memanggil `save_game(slot_type)` untuk menyembuhkan berkas utama.
- **Skenario Serangan:** Di dalam `save_game()`, langkah 5 memeriksa apakah target utama lama ada. Jika berkas utama lama yang rusak masih ada di disk, kode menghapus `.bak` lama yang valid lalu merename berkas utama yang rusak menjadi `.bak`, sebelum merename `.tmp` baru menjadi berkas utama.
- **Dampak (Blast Radius):** Berkas utama yang baru tertulis valid 100%. Namun, salinan `.bak` untuk sementara menjadi berkas korup lama sampai pemain melakukan penyimpanan manual/otomatis berikutnya. Jika crash listrik terjadi tepat saat berkas utama baru rusak kembali sebelum save berikutnya, `.bak` yang tersisa adalah berkas korup tersebut.
- **Saran Mitigasi (Peningkatan Mendatang pada UI-001 / QA-001):** Pada fungsi `save_game()`, periksa keabsahan berkas lama sebelum merotasinya ke `.bak`, atau hindari menimpa `.bak` yang valid jika berkas target lama diketahui tidak valid (misal pada fase pemulihan *self-healing*).
- **Status:** Diterima untuk P0 saat ini (tidak memblokir kelulusan karena self-healing berhasil memulihkan target utama).

#### [Stress Test] Fuzzing Ekstrem & Invariant Checks (Suite 17, 18, 19)
- **Fuzzing Koordinat Pemain (NaN / Inf / OOB):** 4 kasus uji (NaN, Inf, Y = -100, X = 500) seluruhnya berhasil dialihkan ke pekarangan rumah (0.0, 0.0, 8.0) tanpa crash (LULUS).
- **Fuzzing Item Ilegal & Tumpukan > 20:** Item tidak dikenal (`laser_gun_99`) atau jumlah slot negatif / 99 ditolak pada fase validasi tanpa modifikasi memori (LULUS).
- **Berkas 0-byte:** Berkas kosong langsung ditolak sebagai `EMPTY_FILE` dan dialihkan ke backup tanpa exception JSON (LULUS).
- **Idempotensi Multi-Siklus:** 3 siklus save-load berturut-turut menghasilkan representasi JSON snapshot yang identik dengan nol pergeseran nilai (LULUS).

---

## 4. Caveats

1. **Pengujian Pemutusan Daya Fisik (Hard Power Cut):** Pengujian dijalankan di lingkungan proses OS Windows 11 host. Sistem operasi modern melakukan penulisan berkas bertahap melalui filesystem cache; pengujian memverifikasi pemanggilan `file.flush()` dan `file.close()`, namun pemutusan daya fisik perangkat keras (*power-plug pull*) pada milidetik saat operasi `DirAccess.rename_absolute` berlangsung tidak disimulasikan secara fisik.
2. **Antarmuka Grafis Pengguna (UI):** Dialog grafis pemilih slot, layar jeda (Pause Menu), dan konfirmasi penimpaan save game dijadwalkan untuk diimplementasikan pada milestone `UI-001`. Autoload `SaveManager` saat ini menyediakan seluruh API backend yang siap digunakan oleh UI tersebut.

---

## 5. Conclusion & Verdict

**VERDICT: APPROVE**

Implementasi `SAVE-001` (`scripts/save/save_manager.gd`, `tests/suites/test_save.gd`, serta seluruh kontrak snapshot subsistem) dinyatakan **LULUS PENUH**:
1. Tidak ditemukan pelanggaran integritas (*zero integrity violations*), tidak ada facade/mocked data.
2. Seluruh 19 test suite (`6.769/6.769 asersi`) lulus tanpa error (Exit Code 0).
3. Penulisan atomik `.tmp` -> `.bak` -> `.json` melindungi integritas data disk dari kegagalan tulis.
4. *Two-phase commit* menjamin *zero half-loaded world*.
5. Pengaturan pengguna terisolasi bersih pada `user://settings.cfg`.
6. Dokumentasi penyelesaian pada `docs/completed_tasks/015-persistensi-lengkap-save-load-slot-backup.md`, `docs/PROJECT_STATUS.md`, dan `docs/TASKS.md` telah lengkap, konsisten, dan memenuhi aturan kerja `AGENTS.md`.

Pekerjaan siap dilanjutkan ke milestone berikutnya: **UI-001** (Kenyamanan Terpadu: Menu Awal, Pause, Pengaturan, Aksesibilitas, Navigasi Fokus Keyboard, dan Alur Error).

---

## 6. Verification Method

Untuk memverifikasi secara independen kesimpulan laporan ini:
1. Jalankan runner headless Godot melalui PowerShell:
   ```powershell
   godot_console --headless --path . --script res://tests/test_runner.gd
   ```
2. Pastikan keluaran akhir mencatat:
   - `Assertions Passed: 6769`
   - `Assertions Failed: 0`
   - `RESULT: ALL SUITES PASSED (Exit Code: 0)`
3. Periksa berkas implementasi dan arsip:
   - `scripts/save/save_manager.gd`
   - `tests/suites/test_save.gd`
   - `docs/completed_tasks/015-persistensi-lengkap-save-load-slot-backup.md`
