# Laporan Selesai: Persiapan Petak, Benih, Perawatan Area, Akses Alat dan Isi Ulang (GARD-001)

Dokumen ini mencatat penyelesaian implementasi milestone GARD-001 sesuai aturan kerja `AGENTS.md` § 6.

## Identitas

- **ID task:** GARD-001
- **Judul:** Persiapan Petak, Benih, Perawatan Area, Akses Alat dan Isi Ulang
- **Tanggal selesai:** 27 Oktober 2026
- **Agent/pelaksana:** worker_gard_001 & worker_gard_001_r2 (teamwork_worker)
- **Tahap produk:** P0 (GardenManager Autoload, Plot & Spot Data, Tool Toggle, Hold Action Controller, Evaporation Loop, Save Snapshot, Suite 9 TestGardening, DEFECT-GARD-01 Remediation)
- **Status:** Selesai (Lulus 100% verifikasi headless: 955 asersi test runner + 1,679 asersi stress hold + 340 asersi stress invariants lulus, 0 gagal, exit code 0, linter 0 error / 0 warning pada 58 file)
- **Versi sumber/build:** Git working tree lokal, Godot 4.7.2-stable official

## Tujuan dan pemicu

Sesuai spesifikasi `PRD.md` FR07..FR10, `docs/TASKS.md` (bagian GARD-001), `docs/CONTENT.md` § 5, § 6, § 7, § 8, § 9, § 11, § 12, `docs/UI_UX.md` UI01/UI02, dan kasus uji `docs/TEST_PLAN.md` T06, T07, T08, T32, T33:
1. Pemain membutuhkan siklus pengolahan tanah dan perawatan kebun pekarangan (`plot_home_01`, 2 × 2 m) dengan 4 titik tanam kuadran (`slot_01`..`slot_04` / `spot_0`..`spot_3`) untuk menanam benih bayam (`seed_bayam`) guna memenuhi resep sayur bening P0.
2. Pemain memerlukan akses cepat ke 4 alat tetap (`tool_hoe`, `tool_seed`, `tool_fertilizer`, `tool_watering_can`) via hotkeys 1–4 dengan perilaku toggle mandiri (memilih alat aktif yang sama kembali ke tangan kosong / hands-free) tanpa memakan kapasitas 12 slot tas inventaris.
3. Operasi perawatan area (cangkul, pupuk, siram) adalah transaksi satu petak utuh yang memengaruhi seluruh petak (termasuk titik kosong) dengan satu biaya bahan/air, bukan dikalikan jumlah tanaman (T06, T07).
4. Pemupukan memiliki ambang batas ketat: hanya diperbolehkan jika nutrisi < 20 (mengatur nutrisi petak ke 100). Percobaan memupuk saat nutrisi $\ge 20$ wajib ditolak dengan pesan informatif tanpa mengonsumsi pupuk (T06, T33).
5. Penyiraman memiliki ambang batas ketat: hanya diperbolehkan jika kelembapan < 60 dan air penyiram $\ge 2$ unit (mengatur kelembapan petak ke 80 dan mengonsumsi 2 air). Percobaan menyiram saat kelembapan $\ge 60$ wajib ditolak tanpa memotong air (T07, T33).
6. Pembenah tanah (`soil_compost`) diaplikasikan melalui prompt interaksi `[E] Tambah pembenah — 1` ketika petak sudah digemburkan namun belum siap tanam. Pembenah hanya diberikan sekali seumur hidup kebun; percobaan kedua ditolak tanpa mengonsumsi item (T07, T33).
7. Penanaman benih adalah transaksi per titik (kuadran). Penanaman pada petak yang belum siap (belum cangkul atau belum pembenah), pada titik yang sudah terisi tanaman, atau tanpa benih di tas wajib ditolak secara bersih dengan alasan yang tepat tanpa memotong benih (T08). Masing-masing kuadran memiliki isolasi independen (menanam di satu titik tidak memengaruhi titik lain).
8. Mekanik aksi tahan (cangkul 2s LMB, pupuk 1s LMB, siram 2s LMB, isi air 2s E) harus memiliki jaminan pembatalan tanpa biaya (cancel without cost): melepas tombol atau memalingkan pandangan sebelum durasi selesai mereset progres ke 0.0 tanpa pemotongan sumber daya apa pun (T32).
9. Proteksi re-trigger: ketika aksi tahan mencapai 100%, sistem mengeksekusi commit tepat satu kali dan mewajibkan pemain melepas tombol fisik sebelum aksi berikutnya dapat dimulai (tidak ada pengulangan otomatis).
10. Loop penguapan air tanah berjalan secara deterministik pada laju 0.1 unit per detik simulasi aktif (menjepit di 0.0), dan berhenti total saat simulasi dijeda (`InputManager.is_simulation_paused()`). Istirahat ranjang (`bed_home`) tidak mensimulasikan penguapan 720 detik sekaligus.
11. Alat penyiram memiliki kapasitas maksimum 10 unit abstrak, dimulai dari 0 unit pada permainan baru, dan dapat diisi ulang penuh (10 unit) di landmark `water_home` dengan menahan E selama 2 detik (T33).

## Ruang lingkup

Ruang lingkup yang diselesaikan dalam task ini:
- `scripts/gardening/garden_manager.gd`: Autoload singleton (`GardenManager`) pengelola data petak `plot_home_01`, 4 titik kuadran (`slot_01`..`slot_04` dengan pemetaan bidireksional ke `spot_0`..`spot_3`), kapasitas dan unit air penyiram (maks 10, awal 0), status alat aktif, validasi transaksi dan mutasi atomik (`hoe_plot`, `add_compost`, `fertilize_plot`, `water_plot`, `refill_water`, `plant_seed`), loop penguapan deterministik 0.1/s dengan gating pause `InputManager`, pemancar sinyal UI/dunia, serta kontrak persistensi snapshot SAVE-001 (`get_save_snapshot`, `load_save_snapshot`).
- `scripts/gardening/hold_action_controller.gd`: Pengendali aksi tahan mandiri berbasis State Machine 4-state (`IDLE`, `HOLDING`, `COMMITTED`, `MUST_RELEASE`) dengan jaminan pembatalan tanpa biaya, pelacakan progres frame-independent, dan proteksi re-trigger.
- `project.godot`: Pendaftaran autoload singleton `GardenManager="*res://scripts/gardening/garden_manager.gd"` dan penambahan aksi input `tool_1` (Key 1), `tool_2` (Key 2), `tool_3` (Key 3), `tool_4` (Key 4), `action_tool_use` (Mouse Left Click), serta `action_tool_cancel` (Mouse Right Click).
- `scripts/player/player_controller.gd`: Integrasi kendali alat, pemilihan hotkey 1–4 toggle hands-free, eksekusi aksi tahan LMB pada petak dan E pada sumber air, penanaman benih raycast kuadran, pembatalan aksi tahan saat tombol dilepas / klik kanan / target hilang / konteks modal dibuka, serta penerusan progres aksi tahan ke HUD.
- `scenes/ui/hud.tscn` & `scripts/ui/hud.gd`: Pembaruan Exploration HUD terpadu dengan penambahan `HoldPanel` + `HoldProgressBar` untuk progres visual aksi tahan, `ToolPanel` + `ToolLabel` untuk indikator status alat aktif dan air penyiram, serta pemformatan kontekstual prompt interaksi petak (`landmark_plot`) dan sumber air (`landmark_water`).
- `scripts/main.gd`: Penautan diegetik interaksi `plot_home_01` untuk penambahan pembenah tanah `[E] Tambah pembenah — 1`, penyambungan sinyal `plot_state_changed` ke pembaruan material visual tanah gembur/kering/lembap/terisi pada `level_graybox.tscn`.
- `tests/suites/test_gardening.gd` & `tests/test_runner.gd`: Pendaftaran Suite 9 (`TestGardening`) yang mencakup 11 kasus uji komprehensif (GARD-01, T06, T07, T08, Multi-Spot Isolation, T32, T33 area watering, T33 evaporation loop, atomic inventory invariance, SAVE-01 roundtrip, dan landmark scene integration).

Batas cakupan: Kemajuan pertumbuhan multi-tahap (benih -> tunas -> tumbuh -> panen) dan pemanenan bayam+benih dialokasikan pada milestone `GARD-002`.

## Perubahan dan perilaku akhir

- **Inisialisasi Petak dan 4 Titik Kuadran (GARD-01):** Pada permainan baru, petak `plot_home_01` terdaftar dengan `is_hoed = false`, `has_compost = false`, `nutrients = 0.0`, `moisture = 0.0`, dan 4 titik tanam kuadran (`slot_01`..`slot_04`) berstatus kosong (`is_occupied = false`, `crop_data = null`). Penyiram dimulai kosong (`watering_can_water = 0`) dan tangan pemain dalam status bebas (`active_tool = ""`).
- **Aksi Cangkul dan Penggemburan Tanah (T06):** Pemain memilih cangkul dengan menekan Key 1 (`tool_hoe`). Mengarahkan reticle ke petak menampilkan prompt `[Tahan LMB 2s] Gemburkan Petak`. Menahan klik kiri mengakumulasi timer selama 2.0 detik dengan indikator progres HUD. Jika tombol dilepas pada detik 1.0, progres langsung kembali ke 0.0 tanpa perubahan state petak (T32). Jika ditahan penuh 2.0s, aksi commit sekali: `is_hoed = true`, material visual tanah berubah menjadi cokelat gembur, dan HUD menampilkan status gembur. Percobaan mencangkul ulang ditolak dengan status "Kondisi cukup."
- **Pemberian Pembenah Tanah Kontekstual (T07):** Pembenah tanah (`soil_compost`) bukan alat ke-5. Saat tanah telah gembur namun belum diberi pembenah, mendekati petak menampilkan prompt kontekstual `[E] Tambah pembenah — 1`. Menekan E memotong 1 `soil_compost` dari tas secara atomik dan mengubah `has_compost = true` (petak kini siap tanam). Percobaan kedua ditolak ("Kondisi cukup. Tidak ada bahan yang digunakan.") dan 0 pembenah terbuang (T33).
- **Penanaman Benih Bayam per Kuadran (T08 & Isolasi Multi-Titik):** Pemain memilih `tool_seed` (Key 2). Jika petak belum siap (belum cangkul atau belum pembenah), klik kiri ditolak dengan pesan *"Gemburkan tanah dan tambahkan pembenah dahulu."* tanpa memotong benih. Pada petak siap, raycast menghitung kuadran kontak (`slot_01`..`slot_04`). Klik kiri pada kuadran kosong memotong 1 `seed_bayam` dari tas dan mengisi kuadran tersebut dengan tanaman baru (`crop_bayam`, `growth_time = 0.0`, `growth_stage = 0`). Titik kuadran lainnya tetap kosong (isolasi multi-titik terbukti). Percobaan menanam pada kuadran terisi ditolak *"Titik tanam sudah terisi."* tanpa pemotongan benih.
- **Pemupukan Area dan Ambang Nutrisi (T32 & T06):** Pemain memilih `tool_fertilizer` (Key 3). Menahan LMB selama 1.0s pada petak dengan nutrisi < 20 memotong 1 `fertilizer_basic` dan mengatur nutrisi seluruh petak ke 100.0. Jika nutrisi $\ge 20$ (termasuk pada ambang batas 20.0), aksi pemupukan ditolak seketika (*"Kondisi cukup. Tidak ada bahan yang digunakan."*) tanpa memotong pupuk dari inventaris tas.
- **Penyiraman Area, Ambang Kelembapan dan Kapasitas Air (T33 & T07):** Pemain memilih `tool_watering_can` (Key 4). Pada awal permainan dengan air 0, penyiraman ditolak *"Air tidak cukup. Isi ulang penyiram di pekarangan."*. Di `water_home`, menahan E selama 2.0 detik mengisi air penuh ke 10 unit. Menahan LMB 2.0s pada petak dengan kelembapan < 60 dan air $\ge 2$ memotong 2 air penyiram dan mengatur kelembapan petak ke 80.0. Jika kelembapan $\ge 60$ (termasuk batas 60.0), penyiraman ditolak (*"Petak sudah cukup. Tidak ada bahan yang digunakan."*) tanpa mengurangi air penyiram.
- **Loop Penguapan Deterministik (T33):** Kelembapan petak menguap pada laju tepat 0.1 unit/detik saat simulasi aktif. Menjalankan simulasi 10 detik mengurangi kelembapan dari 80.0 ke 79.0. Kelembapan dijepit pada batas minimum 0.0 (tidak pernah bernilai negatif). Saat simulasi dijeda (`InputManager.push_context(ContextMode.BOOK)` atau pause), penguapan berhenti total.
- **Persistensi Snapshot SAVE-001:** `GardenManager.get_save_snapshot()` menghasilkan snapshot terstruktur berversi skema (`version: 1`, `active_tool`, `watering_can_water`, `plots` lengkap dengan seluruh kuadran dan state tanaman). `load_save_snapshot()` memulihkan seluruh data secara konsisten.
- **Remediasi DEFECT-GARD-01 (Invariant Retargeting & Tool Cancellation Guard):** Ditambahkan invariant compatibility guard pada awal `_update_hold_action()` di `scripts/player/player_controller.gd`. Guard memverifikasi kesesuaian target landmark (`landmark_plot` vs `landmark_water`) dan alat aktif (`tool_hoe`, `tool_fertilizer`, `tool_watering_can`) terhadap `action_id` aksi tahan aktif di setiap frame. Jika pemain menyapu kamera secara cepat dari petak ke sumber air atau sebaliknya, atau terjadi pergantian alat eksternal saat sedang menahan tombol aksi, atau pandangan beralih ke objek lain/hampa (`null`), aksi tahan langsung dibatalkan (`hold_controller.cancel()`), timer/progress bar direset ke 0.0, dan status kembali ke `IDLE` tanpa menimbulkan zombie hold softlock.

## File yang ditambahkan atau diubah

| Path Relatif | Jenis Perubahan | Tujuan |
|---|---|---|
| `scripts/gardening/garden_manager.gd` | Ditambahkan | Autoload singleton pengelola petak, kuadran, alat, air penyiram, penguapan deterministik, dan transaksi kebun |
| `scripts/gardening/hold_action_controller.gd` | Ditambahkan | Pengendali state machine aksi tahan (cangkul, pupuk, siram, isi air) dengan pembatalan tanpa biaya dan proteksi re-trigger |
| `project.godot` | Diubah | Pendaftaran autoload `GardenManager` dan input actions `tool_1`..`tool_4`, `action_tool_use`, `action_tool_cancel` |
| `scripts/player/player_controller.gd` | Diubah | Integrasi hotkey alat 1–4 toggle, penanaman raycast kuadran, aksi tahan LMB/E, pembatalan tahan, update progres ke HUD, serta remedi DEFECT-GARD-01 invariant compatibility guard |
| `scenes/ui/hud.tscn` | Diubah | Penambahan node `HoldPanel`, `HoldProgressBar`, `ToolPanel`, dan `ToolLabel` |
| `scripts/ui/hud.gd` | Diubah | Penanganan sinyal `GardenManager`, tampilan bilah alat, progress bar aksi tahan, dan format prompt kontekstual |
| `scripts/main.gd` | Diubah | Penautan landmark `plot_home_01` untuk interaksi pembenah tanah dan pembaruan material visual tanah gembur/lembap |
| `tests/suites/test_gardening.gd` | Ditambahkan & Diubah | Suite 9 pengujian otomatis (12 test case) mencakup GARD-01, T06, T07, T08, T32, T33, isolasi titik, SAVE-01, dan regresi DEFECT-GARD-01 |
| `tests/test_runner.gd` | Diubah | Pendaftaran dan eksekusi Suite 9 (`TestGardening`) dalam harness headless utama |
| `tests/stress_hold_actions.gd` | Ditambahkan | Adversarial stress testing harness untuk controller aksi tahan, re-trigger protection, timing bounds, dan invariant target/tool retargeting |
| `tests/stress_garden_invariants.gd` | Ditambahkan | Adversarial stress testing harness untuk batas nutrisi/kelembapan, determinisme penguapan, isolasi kuadran, dan siklus inventaris |

## Verifikasi yang benar-benar dilakukan

| ID Pemeriksaan | Lingkungan / Input | Tindakan | Hasil Nyata | Status |
|---|---|---|---|---|
| VERIF-SUITE9 | Headless CLI: `godot --headless -s tests/test_runner.gd` | Eksekusi seluruh 9 suite pengujian otomatis proyek | 955 asersi lulus, 0 asersi gagal, exit code 0 | LULUS |
| VERIF-STRESS-HOLD | Headless CLI: `godot --headless -s tests/stress_hold_actions.gd` | Eksekusi 6 tantangan adversarial stress timing aksi tahan & tool retargeting | 1,679 asersi lulus, 0 asersi gagal, exit code 0 | LULUS |
| VERIF-STRESS-INV | Headless CLI: `godot --headless -s tests/stress_garden_invariants.gd` | Eksekusi 6 tantangan empirical invariants kebun, ambang batas, dan isolasi | 340 asersi lulus, 0 asersi gagal, exit code 0 | LULUS |
| VERIF-LINT | Python CLI: `python check_godot_project.py .` | Pemeriksaan konsistensi UID, scene structure, dan referensi script | Summary: 0 errors, 0 warnings across 58 files checked | LULUS |
| VERIF-SMOKE | Headless CLI: `godot --headless --path . scenes/main.tscn --fixed-fps 60 --quit-after 60` | Smoke run 60 frame adegan utama terintegrasi penuh | Eksekusi bersih tanpa error atau warning, exit code 0 | LULUS |
| VERIF-T06 | Test Suite 9 (test_t06_soil_hoeing_hold_and_cancel) | Uji pembatalan tahan 1.0s/2.0s, progres reset 0.0, commit tepat 1 kali pada 2.0s, is_hoed = true | Lulus, tidak ada mutasi saat batal, mutasi tepat saat penuh | LULUS |
| VERIF-T07 | Test Suite 9 (test_t07_compost_amendment_and_rejection) | Uji syarat gembur, pemotongan 1 pembenah, penolakan percobaan kedua tanpa pemborosan item | Lulus, pembenah terpakai tepat 1 kali, percobaan kedua ditolak bersih | LULUS |
| VERIF-T08 | Test Suite 9 (test_t08_seed_planting_and_validation) | Uji penolakan tanah belum siap, penanaman kuadran valid, penolakan kuadran terisi, dan stok 0 benih | Lulus, 1 benih terpotong saat sukses, 0 benih terbuang saat ditolak | LULUS |
| VERIF-T32 | Test Suite 9 (test_t32_area_fertilizing_hold_and_threshold) | Uji batal tahan 0.5s/1.0s, nutrisi diset ke 100, penolakan saat nutrisi $\ge 20$ (termasuk 19.9 vs 20.0) | Lulus, biaya 0 saat batal, 1 pupuk dipakai saat sukses, ditolak saat $\ge 20$ | LULUS |
| VERIF-T33-A | Test Suite 9 (test_t33_area_watering_hold_capacity_and_threshold) | Uji penyiram awal 0, isi ulang penuh 10 di pekarangan, biaya 2 air diset ke 80, penolakan saat kelembapan $\ge 60$ | Lulus, kapasitas 10 unit, air berkurang 2, penolakan saat $\ge 60$ | LULUS |
| VERIF-T33-B | Test Suite 9 (test_t33_evaporation_loop) | Uji penguapan deterministik 0.1/s, clamping 0.0, dan pembekuan penguapan saat simulasi dijeda | Lulus, penguapan akurat 1.0 unit per 10s aktif, tidak bergerak saat paused | LULUS |
| VERIF-ISO | Test Suite 9 (test_multi_spot_isolation) | Uji penanaman terisolasi pada kuadran slot_01 dan slot_03 tanpa memengaruhi kuadran tetangga | Lulus, kuadran tidak saling tumpang tindih | LULUS |
| VERIF-SAVE | Test Suite 9 (test_save_snapshot_roundtrip) | Uji serialisasi round-trip snapshot kebun dan pemulihan penuh | Lulus, snapshot version 1 terpulihkan 100% identik | LULUS |
| VERIF-REG-GARD-01 | Test Suite 9 (test_regression_defect_gard_01_retargeting_hold_cancel) | Uji regresi retargeting plot <-> water, mutasi tool eksternal, dan retargeting ke void | Lulus (4/4 skenario REG-GARD-01.1..REG-GARD-01.4 berhasil membatalkan hold secara instan) | LULUS |

## Kriteria selesai

- [x] Syarat dan biaya CONTENT benar: cangkul gratis permanen, pembenah 1 item, pupuk 1 item, air 2 unit, benih 1 item. (Terpenuhi via `garden_manager.gd`).
- [x] Satu biaya memengaruhi seluruh petak: pemupukan mengatur nutrisi petak ke 100, penyiraman mengatur kelembapan petak ke 80, berlaku untuk seluruh 4 titik di dalamnya. (Terpenuhi dan teruji dalam T06, T32, T33).
- [x] Titik invalid dan titik terisi ditolak tanpa memotong benih. (Terpenuhi dan teruji dalam T08).
- [x] Pemupukan dan penyiraman berlebih tidak boros: penolakan tanpa biaya saat nutrisi $\ge 20$ atau kelembapan $\ge 60$. (Terpenuhi dan teruji dalam T06, T07, T32, T33).
- [x] Seluruh prompt terbaca jelas di HUD dan reticle, mendukung aksi tahan dan toggle alat 1–4. (Terpenuhi via `hud.tscn` dan `hud.gd`).
- [x] Semua aksi tahan commit sekali dan batal tanpa biaya (T32) dengan proteksi re-trigger. (Terpenuhi via `hold_action_controller.gd` dan `player_controller.gd`).
- [x] Penguapan deterministik 0.1/s dengan pause gating dan kapasitas penyiram 10 unit mulai dari 0. (Terpenuhi via `garden_manager.gd`).
- [x] Remedi DEFECT-GARD-01 tuntas: Invariant compatibility guard aktif di `player_controller.gd` dan terlindungi secara permanen oleh pengujian regresi Suite 9 serta adversarial harness.
- [x] Seluruh suite pengujian otomatis proyek lulus 100% tanpa regresi. (Terpenuhi: 955 asersi `test_runner.gd` + 1,679 asersi `stress_hold_actions.gd` + 340 asersi `stress_garden_invariants.gd` lulus, 0 gagal, exit code 0).

## Dampak, kompatibilitas dan keterbatasan

- **Dampak Arsitektur & Kontrak Modul:** `GardenManager` menyediakan API yang terisolasi dan modular untuk persiapan lahan, status nutrisi/kelembapan, dan penempatan benih. Modul berikutnya (`GARD-002`) dapat langsung memanfaatkan struktur `crop_data` pada titik tanam untuk menghitung pertambahan waktu tumbuh (`growth_time`) dan transisi 4 tahap pertumbuhan tanpa mengubah struktur data dasar.
- **Kompatibilitas Save/Load (SAVE-001):** Fungsi `get_save_snapshot()` dan `load_save_snapshot()` pada `GardenManager` menghasilkan payload skema versi 1 yang siap digabungkan ke pipeline save game terpadu saat milestone `SAVE-001` dikerjakan.
- **Keterbatasan Saat Ini:** Pada milestone `GARD-001`, tanaman pada titik kuadran diinisialisasi pada tahap benih (`growth_stage = 0`). Akumulasi waktu tumbuh multi-tahap (benih $\to$ tunas $\to$ tumbuh $\to$ siap panen selama 180 detik efektif) dan panen hasil bayam+benih dialokasikan untuk milestone `GARD-002`.

## Tindak lanjut dan handoff

- **Task berikutnya:** `GARD-002` (Pertumbuhan tanaman, transisi 4 tahap, dan pemanenan bayam + benih kembali).
- **Alasan urutan:** Setelah lahan petak dapat digemburkan, diberi pembenah, dipupuk, disiram, dan ditanami benih, pemain membutuhkan simulasi kemajuan pertumbuhan berbasis waktu aktif dan pemanenan 3 bayam segar untuk memenuhi resep sayur bening.
- **Prasyarat & Rujukan Data:** `GARD-002` membaca data laju tumbuh bayam dari `docs/CONTENT.md` § 8 (180 detik efektif, 4 tahap: Benih 0..30s, Tunas 30..90s, Tumbuh 90..180s, Siap Panen $\ge 180$s), aturan pause pertumbuhan saat kekurangan nutrisi (< 20) atau kekurangan air (< 30), dan pemanenan hasil bayam 1 + benih 1–2 per titik panen.

## Penutupan catatan

Laporan ini telah ditautkan pada `docs/PROJECT_STATUS.md` di bawah daftar Pekerjaan yang Sudah Selesai, status task `GARD-001` ditandai `SELESAI` di `docs/TASKS.md`, dan deskripsi status pekerjaan terakhir diperbarui sesuai ketentuan `AGENTS.md` § 6 dan § 7.
