# Laporan Selesai: Pertumbuhan 4 Tahap Bayam dan Pemanenan Atomik (GARD-002)

Dokumen ini mencatat penyelesaian implementasi milestone GARD-002 sesuai aturan kerja `AGENTS.md` § 6.

## Identitas

- **ID task:** GARD-002
- **Judul:** Pertumbuhan 4 Tahap Bayam dan Pemanenan Atomik
- **Tanggal selesai:** 28 Oktober 2026
- **Agent/pelaksana:** worker_gard_002 (teamwork_worker)
- **Tahap produk:** P0 (Simulasi Pertumbuhan 4 Tahap Bayam, Invarian Stall Non-Decay, Pemanenan Atomik 2-Slot 1 Bayam + 1 Benih, Pengurangan Nutrisi -5, Preservasi Kondisi Olah Petak, Prompt Reticle HUD [E] Panen Bayam, Feedback 2.5s Tas Penuh, Visualisasi 3D CropMesh 4 Tahap, Suite 9 TestGardening T34/T35/T36/T05, Adversarial Stress Challenges 7–10)
- **Status:** Selesai (Lulus 100% verifikasi headless: 1,078 asersi test runner + 2,661 asersi stress garden invariants + 1,679 asersi stress hold actions + main scene smoke test 60 frame, 0 gagal, exit code 0)
- **Versi sumber/build:** Git working tree lokal, Godot 4.7.2-stable official

## Tujuan dan pemicu

Sesuai spesifikasi `PRD.md` FR08 & FR10, `docs/TASKS.md` (bagian GARD-002), `docs/CONTENT.md` § 5, § 7, § 9, § 11, § 12, `docs/UI_UX.md` UI01/UI02, dan kasus uji `docs/TEST_PLAN.md` T34, T35, T36, T05:
1. Pemain membutuhkan siklus pertumbuhan tanaman bayam (`crop_bayam`) di petak pekarangan (`plot_home_01`) melalui 4 tahap visual dan fungsional terpisah (Benih 0..<30s, Tunas 30..<90s, Tumbuh 90..<180s, Siap Panen $\ge$ 180s) hingga durasi total 180 detik terpenuhi untuk memanen bahan utama resep Sayur Bening Bayam dan Jagung.
2. Pertumbuhan tanaman harus tunduk pada kondisi lingkungan tanah: jika kelembapan tanah $< 30.0$ ATAU nutrisi $< 20.0$, pertumbuhan tanaman terhenti seketika (*growth stall*).
3. Tanaman yang mengalami stall tidak boleh layu, membusuk, mati, atau mengalami kemunduran timer (*non-decay invariance*). Begitu ambang batas lingkungan dipulihkan kembali (kelembapan $\ge 30.0$ dan nutrisi $\ge 20.0$), timer pertumbuhan melanjutkan dari titik detik terakhir secara kontinu.
4. Simulasi pertumbuhan harus berhenti saat modal/pause aktif (`InputManager.is_simulation_paused()`), memastikan tidak ada pertumbuhan di luar kendali pemain saat membuka buku resep, berdialog, atau menjeda game.
5. Pemain membutuhkan interaksi pemanenan diegetik pada titik tanaman matang melalui tombol interaksi `[E]` dengan prompt reticle `[E] Panen Bayam` saat reticle membidik titik tanaman yang matang.
6. Pemanenan harus merupakan transaksi atomik 2-slot tanpa celah duplikasi atau kehilangan item:
   - Hasil panen memberikan tepat 1x bayam segar (`ingredient_bayam`) dan 1x benih bayam (`seed_bayam`) untuk siklus penanaman ulang berkelanjutan.
   - Nutrisi petak berkurang tepat 5.0 unit per pemanenan.
   - Titik kuadran kembali kosong (`is_occupied = false`, `crop_data = null`).
   - Petak tetap dalam kondisi siap tanam (`is_hoed = true`, `has_compost = true`), sehingga pemain dapat langsung menanam benih berikutnya tanpa mencangkul atau memberi pembenah ulang.
   - Pemanenan wajib ditolak secara utuh jika ruang inventaris tas tidak mencukupi untuk menampung kedua item hasil panen (misalnya saat 11/12 slot terisi penuh barang tak sejenis sehingga hanya tersisa 1 slot kosong, atau 12/12 penuh). Saat ditolak, 0 nutrisi terpotong, 0 item terbuang, tanaman tetap di petak, dan pemain menerima umpan balik visual di HUD selama 2.5 detik: *"Tas penuh. Kosongkan ruang di inventaris."*
7. Representasi visual tanaman di dunia 3D (`level_graybox.tscn`) harus menampilkan model dan skala yang berubah secara bertahap pada setiap pergantian tahap pertumbuhan, dan menghilang bersih saat dipanen.

## Ruang lingkup

Ruang lingkup yang diselesaikan dalam task ini:
- `scripts/inventory/items_data.gd`: Pendaftaran alias item `seed_spinach` $\rightarrow$ `seed_bayam` dan `crop_spinach` $\rightarrow$ `ingredient_bayam` untuk menjamin kompatibilitas referensi silang data PRD dan Content.
- `scripts/gardening/garden_manager.gd`: 
  - Penambahan enum `CropStage` (`SEED = 0`, `SPROUT = 1`, `GROWING = 2`, `HARVESTABLE = 3`).
  - Konstanta batas pertumbuhan dan ambang batas lingkungan (`BAYAM_TOTAL_GROWTH_TIME = 180.0`, `STAGE_SPROUT_TIME = 30.0`, `STAGE_GROWING_TIME = 90.0`, `STAGE_HARVEST_TIME = 180.0`, `MOISTURE_GROWTH_THRESHOLD = 30.0`, `NUTRIENT_GROWTH_THRESHOLD = 20.0`, `HARVEST_NUTRIENT_COST = 5.0`).
  - Sinyal-sinyal baru: `crop_stage_changed(plot_id, spot_id, stage)`, `crop_ready_to_harvest(plot_id, spot_id, crop_id)`, `crop_stalled(plot_id, spot_id, reason)`, `crop_resumed(plot_id, spot_id)`, `crop_harvested(plot_id, spot_id, crop_id, yield_items)`, `spot_harvested(plot_id, spot_id)`.
  - Fungsi kalkulasi kuadran: `get_spot_id_from_local_coords(local_pos: Vector3) -> String`.
  - Fungsi validasi kondisi lingkungan: `can_crop_grow_on_plot(plot_id: String) -> bool` dan `get_plot_growth_stall_reason(plot_id: String) -> String`.
  - Fungsi kalkulasi tahap: `calculate_crop_stage(growth_time: float) -> int`.
  - Pengecekan kapasitas dan kesiapan panen: `can_harvest_crop(plot_id, spot_id) -> Dictionary` dan `can_harvest(plot_id, spot_id) -> Dictionary`.
  - Transaksi pemanenan atomik: `harvest_crop(plot_id, spot_id) -> bool` dan `harvest_spot(plot_id, spot_id) -> Dictionary`.
  - Loop simulasi pertumbuhan multi-plot dan multi-spot terisolasi: `simulate_growth(delta: float)` dan `_simulate_plot_growth(plot_id, delta)` yang terintegrasi di dalam `simulate_process(delta)`.
- `scripts/player/player_controller.gd`:
  - Penanganan interaksi panen `[E]` via `_handle_plot_harvest_on_plot()` saat membidik kuadran dengan tanaman matang.
  - Prioritas interaksi diegetik antara panen, pembenah, dan aksi tahan.
- `scripts/ui/hud.gd`:
  - Penyambungan ke sinyal `action_failed` untuk menampilkan banner umpan balik sementara (*feedback toast*) berdurasi 2.5 detik via `show_feedback(message, duration)`.
  - Format teks prompt kontekstual reticle `[E] Panen Bayam` saat reticle mendeteksi kuadran siap panen.
- `scripts/main.gd`:
  - Penambahan hierarki `CropMesh` dinamis berbasis `BoxMesh` dan `StandardMaterial3D` pada masing-masing titik kuadran (`Spot_01`..`Spot_04`) di dalam `plot_home_01`.
  - Pembaruan bentuk, skala, dan warna visual tanaman di setiap emisi sinyal `plot_state_changed`:
    - Tahap 0 (Seed): gundukan kecil cokelat/kuning (skala 0.08 × 0.05 × 0.08, posisi Y = 0.05)
    - Tahap 1 (Sprout): tunas kecil hijau muda (skala 0.15 × 0.18 × 0.15, posisi Y = 0.10)
    - Tahap 2 (Growing): tanaman sedang hijau rimbun (skala 0.28 × 0.35 × 0.28, posisi Y = 0.18)
    - Tahap 3 (Harvestable): rimbun matang hijau tua berujung benih keemasan (skala 0.38 × 0.48 × 0.38, posisi Y = 0.25)
    - Kosong / Terpanen: mesh disembunyikan (`visible = false`).
- `tests/suites/test_gardening.gd`:
  - Penambahan 10 kasus uji komprehensif Suite 9: `test_t34_crop_growth_4_stages`, `test_t05_crop_growth_4_stages`, `test_t35_growth_stall_conditions`, `test_t34_growth_stall_conditions`, `test_t36_atomic_harvest_yield_and_replanting`, `test_t35_atomic_harvest_yield`, `test_t05_harvest_capacity_atomic_rejection`, `test_t36_harvest_capacity_rejection`, `test_multi_spot_staggered_growth_and_harvest`, `test_gard02_save_snapshot_growth_persistence`.
- `tests/stress_garden_invariants.gd`:
  - Penambahan 4 skenario uji ketahanan adverserial ekstrem (Challenges 7–10) yang menguji monotonicitas pertumbuhan, clamping mikro-delta 500 frame, batas presisi float 19.99 vs 20.0 dan 29.99 vs 30.0, permutasi 100 siklus tanam-panen multi-spot, serta proteksi spam klik 100x pemanenan atomik.

## Perubahan dan perilaku akhir

- **Simulasi Pertumbuhan 4 Tahap Bayam (T34 / T05):**
  - Tanaman bayam yang ditanam pada `plot_home_01` bertambah waktu pertumbuhannya secara kontinu setiap tick simulasi aktif.
  - Pada $t \in [0, 30)$ detik: tahap `CropStage.SEED` (0), visual gundukan benih.
  - Pada $t \in [30, 90)$ detik: tahap `CropStage.SPROUT` (1), visual tunas hijau muda.
  - Pada $t \in [90, 180)$ detik: tahap `CropStage.GROWING` (2), visual tanaman berkembang.
  - Pada $t \ge 180$ detik: tahap `CropStage.HARVESTABLE` (3), `is_ready_to_harvest = true`, waktu dijepit pada 180.0s (tidak tumbuh berlebih tanpa batas). Sinyal `crop_ready_to_harvest` diemisikan.
- **Kondisi Stall dan Invarian Non-Decay (T35 / T34):**
  - Jika kelembapan petak $< 30.0$ (misalnya akibat penguapan kontinu) atau nutrisi petak $< 20.0$, tanaman beralih ke status `is_stalled = true` dan mengemisikan `crop_stalled`.
  - Selama masa stall, waktu pertumbuhan dan tahap tanaman tetap membeku pada nilai tepat saat stall terjadi. Tanaman tidak mengalami layu, kemunduran waktu (*no regression*), atau kematian (*non-decay*).
  - Ketika kelembapan dan nutrisi kembali dipenuhi (misalnya melalui penyiraman ke 80 atau pemupukan ke 100), tanaman beralih ke `is_stalled = false`, mengemisikan `crop_resumed`, dan melanjutkan akumulasi waktu pertumbuhan dari detik terakhir secara mulus.
  - Saat `InputManager.is_simulation_paused()` bernilai true (buku dibuka atau menu aktif), loop simulasi berhenti total tanpa ada pertambahan waktu pertumbuhan.
- **Pemanenan Atomik 2-Slot dan Preservasi Petak (T36 / T35):**
  - Pemain mendekati tanaman matang dan melihat prompt reticle `[E] Panen Bayam`.
  - Menekan `E` memicu transaksi atomik:
    1. Tas inventaris menerima tepat 1 unit `ingredient_bayam` dan 1 unit `seed_bayam`.
    2. Nutrisi petak berkurang sebesar 5.0 unit (misal 100.0 $\rightarrow$ 95.0).
    3. Titik kuadran dibersihkan (`is_occupied = false`, `crop_data = null`).
    4. Sinyal `crop_harvested` dan `spot_harvested` diemisikan; `CropMesh` di dunia 3D langsung disembunyikan.
    5. Petak mempertahankan status olah tanah (`is_hoed = true`, `has_compost = true`), memungkinkan pemain langsung menanam benih berikutnya seketika tanpa harus mencangkul atau memberi pembenah ulang.
- **Penolakan Atomik saat Tas Penuh (T05 / T36):**
  - Jika inventaris tas tidak memiliki kapasitas untuk menampung kedua item hasil panen (diperiksa melalui alokasi virtual pra-eksekusi), panen ditolak secara menyeluruh.
  - Tidak ada mutasi parsial: 0 bayam masuk tas, 0 benih masuk tas, 0 nutrisi terpotong, dan tanaman tetap matang di titiknya.
  - Sinyal `action_failed` diemisikan dengan alasan *"Tas penuh. Kosongkan ruang di inventaris."*, memicu banner umpan balik teks di HUD selama 2.5 detik.
- **Visualisasi Diegetik 3D CropMesh:**
  - `main.gd` memperbarui bentuk, ketinggian, dan material visual tanaman secara otomatis di dunia 3D setiap kali `plot_state_changed` diterima, memberikan respons visual yang jelas kepada pemain tanpa bergantung pada teks UI saja.

## File yang ditambahkan atau diubah

| Path Relatif | Jenis Perubahan | Tujuan |
|---|---|---|
| `scripts/inventory/items_data.gd` | Diubah | Pendaftaran alias `seed_spinach` $\rightarrow$ `seed_bayam` dan `crop_spinach` $\rightarrow$ `ingredient_bayam` |
| `scripts/gardening/garden_manager.gd` | Diubah | Penambahan logika simulasi 4 tahap pertumbuhan, kondisi stall non-decay, dan transaksi pemanenan atomik 2-slot |
| `scripts/player/player_controller.gd` | Diubah | Integrasi interaksi reticle `[E]` untuk pemanenan tanaman matang pada petak |
| `scripts/ui/hud.gd` | Diubah | Banner umpan balik `show_feedback(2.5s)` untuk tas penuh dan format prompt reticle `[E] Panen Bayam` |
| `scripts/main.gd` | Diubah | Integrasi visualisasi dinamis 3D `CropMesh` (4 tahap pertumbuhan dan pembersihan panen) |
| `tests/suites/test_gardening.gd` | Diubah | Penambahan 10 unit test Suite 9 mencakup T34, T35, T36, T05, multi-spot staggered, dan SAVE-001 |
| `tests/stress_garden_invariants.gd` | Diubah | Penambahan Challenges 7–10 untuk verifikasi adverserial ketahanan matematis dan atomisitas |

## Verifikasi yang benar-benar dilakukan

| ID Pemeriksaan | Lingkungan / Perintah | Tindakan | Hasil Nyata | Status |
|---|---|---|---|---|
| VERIF-TEST-RUNNER | Headless Godot: `godot_console.exe --headless -s tests/test_runner.gd` | Menjalankan seluruh test runner proyek (Suite 1–9) | 1,078 asersi lulus, 0 gagal, Exit code 0 | Lulus |
| VERIF-STRESS-INV | Headless Godot: `godot_console.exe --headless -s tests/stress_garden_invariants.gd` | Menjalankan 10 tantangan adverserial ketahanan kebun | 2,661 asersi lulus, 0 gagal, Exit code 0 | Lulus |
| VERIF-STRESS-HOLD | Headless Godot: `godot_console.exe --headless -s tests/stress_hold_actions.gd` | Menjalankan uji ketahanan pengendali aksi tahan | 1,679 asersi lulus, 0 gagal, Exit code 0 | Lulus |
| VERIF-SMOKE-MAIN | Headless Godot: `godot_console.exe --headless --quit-after 60 scenes/main.tscn` | Menjalankan adegan utama selama 60 frame | Adegan utama terinisialisasi bersih, Exit code 0 | Lulus |
| T34-GROWTH-CYCLE | TestGardening: `test_t34_crop_growth_4_stages` | Simulasi pertumbuhan $t=0, 30, 90, 180, 250$ detik | Tahap 0 $\rightarrow$ 1 $\rightarrow$ 2 $\rightarrow$ 3 diverifikasi presisi; waktu terpotong tepat pada 180.0s | Lulus |
| T35-GROWTH-STALL | TestGardening: `test_t35_growth_stall_conditions` | Uji ambang batas kelembapan $< 30$ dan nutrisi $< 20$ | Pertumbuhan membeku seketika tanpa decay, melanjutkan kontinu setelah dipulihkan | Lulus |
| T36-HARVEST-YIELD | TestGardening: `test_t36_atomic_harvest_yield_and_replanting` | Panen tanaman matang di kuadran | 1x `ingredient_bayam` + 1x `seed_bayam` didapat, nutrisi -5.0, petak tetap gembur dan berpembenah | Lulus |
| T05-HARVEST-CAPACITY | TestGardening: `test_t05_harvest_capacity_atomic_rejection` | Uji panen saat tas penuh (11/12 dan 12/12) | Transaksi ditolak 100% tanpa mutasi parsial, pesan error tepat dihasilkan | Lulus |
| STAGGERED-GROWTH | TestGardening: `test_multi_spot_staggered_growth_and_harvest` | Tanam di `slot_01` dan `slot_02` pada waktu berbeda | Titik tumbuh independen, panen titik satu tidak mengganggu titik dua | Lulus |
| SAVE-PERSISTENCE | TestGardening: `test_gard02_save_snapshot_growth_persistence` | Ambil snapshot saat tanaman tumbuh lalu pulihkan | Nilai `growth_time`, `growth_stage`, dan `is_ready_to_harvest` pulih 100% identik | Lulus |

## Kriteria selesai

- [x] **Pertumbuhan 4 Tahap Terimplementasi:** Tahap 0 (Seed, 0..<30s), Tahap 1 (Sprout, 30..<90s), Tahap 2 (Growing, 90..<180s), Tahap 3 (Harvestable, $\ge$ 180s, dijepit di 180.0s).
- [x] **Invarian Stall Non-Decay Terpenuhi:** Pertumbuhan terhenti saat kelembapan $< 30.0$ atau nutrisi $< 20.0$, tanpa kemunduran timer atau kematian tanaman.
- [x] **Pemanenan Atomik 2-Slot Berfungsi:** Panen memberikan 1x `ingredient_bayam` + 1x `seed_bayam`, memotong 5.0 nutrisi, membersihkan kuadran, dan menjaga status siap tanam petak (`is_hoed = true`, `has_compost = true`).
- [x] **Penolakan Atomik Tas Penuh:** Verifikasi pra-alokasi mencegah pemanenan jika ruang inventaris tidak cukup menampung 2 slot hasil panen; tidak ada pemotongan nutrisi atau hilangnya hasil panen.
- [x] **Prompt Reticle dan Umpan Balik HUD:** Reticle menampilkan `[E] Panen Bayam` saat tanaman matang; banner 2.5s muncul saat aksi ditolak.
- [x] **Visualisasi 3D Terintegrasi:** `CropMesh` berubah bentuk dan ukuran sesuai 4 tahap pertumbuhan di dunia graybox.
- [x] **Suite Uji dan Stress Runner Lulus 100%:** Seluruh 1,078 asersi `test_runner.gd`, 2,661 asersi `stress_garden_invariants.gd`, dan 1,679 asersi `stress_hold_actions.gd` lulus tanpa error.

## Dampak, kompatibilitas dan keterbatasan

- **Ketersediaan Bahan Resep P0:** Milestone ini melengkapi rantai produksi bahan pertama untuk resep P0 Sayur Bening Bayam dan Jagung. Pemain kini dapat menanam benih, merawat petak, dan memanen bayam segar ke dalam inventaris tas.
- **Kompatibilitas Save Snapshot:** Format snapshot `SAVE-001` mempertahankan skema `plots` dengan rincian `crop_data` (`crop_id`, `growth_time`, `growth_stage`, `is_ready_to_harvest`, `is_stalled`, `stall_reason`), menjamin kompatibilitas maju dan mundur terhadap data simpanan.
- **Keterbatasan Visual Aset:** Visual tanaman saat ini menggunakan primitive procedural `BoxMesh` dan `StandardMaterial3D` bergradasi warna yang proporsional sesuai estetika graybox P0; penggantian dengan model 3D stylized akhir dialokasikan pada fase polishing visual.

## Tindak lanjut dan handoff

- **Task Berikutnya:** `COOK-001` (Sistem Memasak P0: Meja Dapur, Reservasi Bahan & Pembuatan Sayur Bening Bayam dan Jagung).
- **Prasyarat yang Terpenuhi:** `GARD-001` dan `GARD-002` telah rampung sepenuhnya, memungkinkan pemain mengumpulkan `ingredient_bayam` dari kebun dan menggabungkannya dengan bahan lain di inventaris untuk memasak resep P0.
- **Sumber Data Acuan:** `docs/CONTENT.md` § 2 (Resep Sayur Bening Bayam dan Jagung), `docs/CONTENT.md` § 10 (Interaksi Stasiun Memasak), dan `docs/TASKS.md` bagian COOK-001.

## Penutupan catatan

Laporan ini ditautkan pada `docs/PROJECT_STATUS.md` nomor 10 dan status task `GARD-002` pada `docs/TASKS.md` diperbarui menjadi SELESAI.
