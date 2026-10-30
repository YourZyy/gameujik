# Laporan Task Selesai: 013 — Kontrol Panas, Timer Memasak, Jeda Panel, Slot Output Tunggal, dan Aksi Makan Hidangan

Dokumen ini mencatat penyelesaian milestone `COOK-002` sesuai dengan panduan kerja AI Agent Buku Resep 2045 dan spesifikasi PRD / CONTENT / UI_UX / TEST_PLAN.

## Identitas

- **ID task:** `COOK-002`
- **Judul:** Kontrol Panas, Timer Memasak, Jeda Panel Dapur, Slot Output Tunggal, Retensi Tas Penuh, Centang Buku Resep, dan Aksi Makan Hidangan
- **Tanggal selesai:** 28 Oktober 2026
- **Agent/pelaksana:** Orchestrator Generation 7 (`orchestrator_gen7`) bersama multi-agent consensus gate (3 Explorer, 1 Worker, 2 Reviewer, 2 Challenger, 1 Forensic Auditor)
- **Tahap produk:** P0 (Vertical Slice Loop Utama)
- **Status:** Selesai (Lulus Penuh Gerbang Konsensus, 2.126 asersi lulus 100%, Exit Code 0)
- **Versi sumber/build:** Godot 4.7.2-stable, headless engine CLI, branch lokal aktif

## Tujuan dan pemicu

Penyelesaian milestone `COOK-001` sebelumnya telah membangun validasi bahan terpadu (3 bayam, 1 jagung, 1 temu kunci), reservasi atomik lintas tas dan peti dengan origin manifest, aksi tahan persiapan 4 detik, dan pembatalan aman ke wadah refund. Namun, stasiun dapur belum dapat mengeksekusi proses memasak aktif, mengendalikan tingkat panas, menghitung mundur waktu memasak 30 detik, menjeda simulasi saat panel ditutup, memproduksi hidangan jadi ke slot output tunggal, menandai centang buku resep, maupun memungkinkan pemain memakan hidangan dari tas.

Milestone `COOK-002` diinisialisasi untuk merealisasikan seluruh siklus memasak aktif hingga konsumsi hidangan sesuai dengan `PRD.md` (FR03, FR04, FR13), `docs/CONTENT.md` § 4 & § 10, `docs/PROTOTYPE.md` § 5 & § 6.2/6.3, serta `docs/TEST_PLAN.md` (T12, T15, T19, T41, T42, T43).

## Ruang lingkup

Pekerjaan yang diselesaikan meliputi:
1. **Kontrol Tingkat Panas (T41 & CONTENT § 4):**
   - Tiga tingkat panas diskrit:
     - Rendah (`HEAT_LOW`): Pengali kemajuan $\times 0.5$ (kecepatan lambat tapi stabil).
     - Sedang (`HEAT_MEDIUM`): Pengali kemajuan $\times 1.0$ (kondisi nominal, durasi 30 detik).
     - Tinggi (`HEAT_HIGH`): Pengali kemajuan $\times 0.0$ (*heat stall* / kemajuan berhenti sementara) disertai pesan peringatan *"Kecilkan panas ke Sedang."*, dengan invarian bahwa bahan **tidak hangus atau rusak**.
   - Pilihan panas awal otomatis dimulai dari Rendah agar pemain membaca petunjuk secara sadar.
2. **Timer Memasak 30 Detik Nominal (T12, T41):**
   - Durasi dasar memasak: 30.0 detik waktu simulasi efektif (`COOK_DURATION = 30.0`).
   - Akumulasi waktu: `cook_progress += delta * multiplier`.
3. **Jeda Simulasi (*Simulation Pause* / T42, PROTOTYPE § 5):**
   - Ketika antarmuka dapur ditutup (`Esc` atau tombol tutup), status job bertransisi ke `JobState.PAUSED` sehingga waktu memasak **tidak maju diam-diam di latar belakang** (*no stealth background cooking*).
   - Saat panel dibuka kembali, status dapat dilanjutkan (*resume*) dari detik kemajuan yang sama persis tanpa kehilangan waktu atau bahan.
4. **Slot Output Masakan Tunggal (`dish_output_slot` / T15):**
   - Saat mencapai 30.0s, stasiun menghasilkan 1 unit `dish_sayur_bening` di `dish_output_slot` dan bertransisi ke `JobState.OUTPUT_READY`.
   - Hanya ada 1 slot output masakan. Selama slot ini belum diambil, pemain dilarang memulai persiapan baru.
5. **Retensi Kapasitas Tas Penuh (T15):**
   - Tombol *"Ambil Masakan"* memindahkan hidangan ke tas pemain. Jika tas penuh (12/12), transaksi ditolak secara bersih dengan pesan jujur *"Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."*, dan hidangan tetap aman di `dish_output_slot` tanpa risiko hilang atau terduplikasi.
6. **Centang Buku Resep & Peningkatan Counter (T19):**
   - Resep Sayur Bening Bayam dan Jagung (`recipe_sayur_bening_01`) ditandai selesai (`times_cooked = 1`, `is_completed = true`) tepat saat masakan mencapai 100%. Centang tidak pernah aktif prematur pada fase persiapan, pemanasan, atau jeda.
   - Pada siklus masak ulang (remake), counter `times_cooked` bertambah (menjadi 2, 3, dst.), namun sinyal `recipe_completed` tidak dipancarkan ulang untuk mencegah eksploitasi ganda.
7. **Pengecualian Interlock Kasur Tidur:**
   - Helper `is_job_active()` mengecualikan `OUTPUT_READY`, sehingga pemain diperbolehkan tidur di ranjang rumah ketika hidangan yang sudah matang masih menunggu di slot dapur (per `CONTENT.md` § 9 baris 164).
8. **Aksi Konsumsi Hidangan dari Tas (`action_eat` / T43):**
   - Pemain dapat mengonsumsi `dish_sayur_bening` dari tas melalui tombol *"Makan [1 Porsi]"* pada detail panel dengan konfirmasi inline.
   - Mengonsumsi hidangan mengurangi 1 unit secara atomik, menyetel flag global `meal_used = true` di `KitchenManager` dan `WorldResourceManager`, memancarkan umpan balik jujur *"Hangat. Resep pertama berhasil dibuat."*, tanpa menambah hunger bar atau buff statistik fiktif.
9. **Persistensi Save Snapshot Envelope v1:**
   - Variabel `current_heat_level`, `cook_progress`, `cook_duration`, `dish_output_slot`, dan `meal_used` tersimpan dan dipulihkan secara atomik.

Batas task: Interaksi dialog tetangga dan berbagi hidangan (`action_share`) dialokasikan pada milestone berikutnya (`SOC-001`).

## Perubahan dan perilaku akhir

1. **Backend `scripts/cooking/kitchen_manager.gd`**:
   - Menambahkan enum `HeatLevel`, konstanta multiplier, `COOK_DURATION = 30.0`, dan stall warning message.
   - Mengimplementasikan `start_cooking()`, `advance_cooking(delta)`, `pause_cooking()`, `resume_cooking()`, `set_heat_level()`, `claim_dish_output()`, dan `eat_dish()`.
   - Menyambungkan commit 100% matang ke `RecipeManager.record_recipe_cooked()`.
   - Mengubah `is_job_active()` agar tidak memblokir kasur tidur saat berstatus `OUTPUT_READY`.
2. **State Global `scripts/world/world_resource_manager.gd`**:
   - Menambahkan `var meal_used: bool = false`, `set_meal_used()`, `is_meal_used()`, signal `meal_consumed`, dan serialisasi save snapshot envelope v1.
3. **Antarmuka Dapur `scenes/ui/kitchen_ui.tscn` & `scripts/ui/kitchen_ui.gd`**:
   - Menambahkan `CookingSection`: 3 tombol panas (Rendah, Sedang, Tinggi), banner visual *Heat Stall Warning*, progress bar durasi memasak, label timer hitung mundur, dan banner jeda (PAUSED).
   - Menambahkan `OutputSection`: Kartu hidangan selesai dan tombol *"Ambil Masakan"*.
   - Otomatis memicu `pause_cooking()` saat dialog dapur ditutup melalui `close()`.
4. **Antarmuka Tas `scenes/ui/inventory_ui.tscn` & `scripts/ui/inventory_ui.gd`**:
   - Menambahkan tombol `BtnEatDish` pada `DetailPanel` tas dengan inline konfirmasi 2 langkah ("Makan [1 Porsi]" -> "Makan 1 porsi? [Konfirmasi]") saat `dish_sayur_bening` dipilih.
   - Menghubungkan klik konfirmasi ke `kitchen_manager.eat_dish()`.
5. **Rangkaian Uji Otomatis**:
   - `tests/suites/test_cooking_heat.gd` (Suite 13): 13 metode uji penerimaan formal untuk T12, T15, T19, T41, T42, T43, interlock tidur, dan save roundtrip.
   - `tests/suites/test_adversarial_cooking_heat.gd` (Suite 14): 12 metode uji adversarial (15 batas sub-detik centang buku resep, 3 siklus masak ulang, underflow proteksi tas kosong, 4 snapshot mid-cooking, dan 100x rapid heat switching).
   - `tests/test_runner.gd`: Pendaftaran Suite 13 dan 14.

## File yang ditambahkan atau diubah

| Path Relatif | Jenis Perubahan | Tujuan |
|---|---|---|
| `scripts/cooking/kitchen_manager.gd` | Modifikasi | Logika kontrol panas, timer 30s, jeda simulasi, output slot, makan hidangan, save snapshot |
| `scripts/world/world_resource_manager.gd` | Modifikasi | Flag `meal_used`, sinyal konsumsi, interlock kasur tidur, save snapshot v1 |
| `scenes/ui/kitchen_ui.tscn` | Modifikasi | Node visual CookingSection, HeatButtons, WarningPanel, ProgressBar, TimerLabel, OutputSection |
| `scripts/ui/kitchen_ui.gd` | Modifikasi | Pengendali UI dapur, pemilihan panas, auto-pause saat tutup, klaim output ke tas |
| `scenes/ui/inventory_ui.tscn` | Modifikasi | Penambahan tombol `BtnEatDish` pada DetailPanel tas |
| `scripts/ui/inventory_ui.gd` | Modifikasi | Logika inline konfirmasi makan hidangan dan toast feedback jujur |
| `tests/suites/test_cooking_heat.gd` | Ditambahkan | Test Suite 13 formal acceptance (13 metode uji, 190 asersi) |
| `tests/suites/test_adversarial_cooking_heat.gd` | Ditambahkan | Test Suite 14 adversarial stress & invariants (12 metode uji, 241 asersi) |
| `tests/test_runner.gd` | Modifikasi | Pendaftaran dan eksekusi Suite 13 & 14 |
| `docs/completed_tasks/013-kontrol-panas-output-makan-hidangan.md` | Ditambahkan | Dokumen laporan penyelesaian resmi milestone COOK-002 |

## Verifikasi yang benar-benar dilakukan

| ID Pemeriksaan | Lingkungan / Input | Tindakan | Hasil Nyata | Status |
|---|---|---|---|---|
| UJI-T41-HEAT | Godot 4.7.2 Headless | Uji tingkat panas Rendah (0.5x), Sedang (1.0x), dan Tinggi (0.0x stall warning) | Progres berjalan sesuai pengali; pada Tinggi kemajuan berhenti 100% tanpa merusak bahan | LULUS |
| UJI-T12-PAUSE | Godot 4.7.2 Headless | Buka stasiun dapur, mulai masak, tutup UI (Esc), cek tick di luar, buka kembali | Memasak berstatus `PAUSED`, progres tidak bertambah di latar belakang, resume utuh | LULUS |
| UJI-T15-OUTPUT | Godot 4.7.2 Headless | Memasak hingga 30.0s, verifikasi 1 `dish_sayur_bening` di output, coba masak resep baru | Transisi ke `OUTPUT_READY`, masakan baru ditolak keras selama output belum diambil | LULUS |
| UJI-T15-FULLBAG | Godot 4.7.2 Headless | Isi tas 12/12 slot, coba klaim hidangan dari output dapur | Klaim ditolak ("Tas tidak cukup"), hidangan tetap aman di slot dapur tanpa hilang/ganda | LULUS |
| UJI-T19-CHECKMARK | Godot 4.7.2 Headless | Periksa status resep pada progres 0.0s hingga 29.99s, lalu saat 30.0s | Resep tidak centang sebelum 30.0s; centang tepat saat 100%; `times_cooked` bertambah | LULUS |
| UJI-T19-REMAKE | Godot 4.7.2 Headless | Masak resep ke-2 dan ke-3 kali | `times_cooked` bertambah (1 -> 2 -> 3), sinyal `recipe_completed` tidak dipancarkan ganda | LULUS |
| UJI-T43-EAT | Godot 4.7.2 Headless | Eksekusi `eat_dish` dari tas | 1 hidangan terpotong atomik, `meal_used = true`, pesan "Hangat...", tanpa hunger bar | LULUS |
| UJI-BED-INTERLOCK | Godot 4.7.2 Headless | Cek kasur tidur saat memasak aktif vs saat output masakan siap | Tidur ditolak saat memasak aktif; tidur diizinkan saat masakan sudah matang di output | LULUS |
| UJI-SAVE-MIDCOOK | Godot 4.7.2 Headless | Simpan snapshot di tengah memasak (15s, Sedang), muat ulang snapshot | Seluruh state pulih presisi, timer melanjutkan sisa 15 detik tanpa korupsi data | LULUS |
| UJI-RUNNER-FULL | CLI Godot Headless | Eksekusi seluruh 14 test suite di `tests/test_runner.gd` | 2.126 asersi lulus 100%, 0 gagal, Exit Code 0 | LULUS |
| AUDIT-FORENSIK | Reviewer & Auditor | Analisis statis anti-cheat, anti-facade, verifikasi keaslian logika | Verdict CLEAN mutlak, zero integrity violation | LULUS |

## Kriteria selesai

1. Kontrol Panas T41 (Rendah 0.5x, Sedang 1.0x, Tinggi 0.0x stall warning) berfungsi penuh: **Terpenuhi & Terverifikasi**.
2. Timer 30 detik nominal berjalan akurat dengan pengali panas aktif: **Terpenuhi & Terverifikasi**.
3. Jeda simulasi saat panel dapur ditutup tanpa kebocoran memasak di latar belakang: **Terpenuhi & Terverifikasi**.
4. Slot output tunggal, penolakan masakan baru saat terisi, dan proteksi tas penuh (T15): **Terpenuhi & Terverifikasi**.
5. Centang buku resep anti-prematur, increment `times_cooked`, dan penanganan siklus masak ulang (T19): **Terpenuhi & Terverifikasi**.
6. Aksi makan hidangan dari tas, potongan atomik 1 unit, flag `meal_used = true`, feedback jujur tanpa hunger bar (T43): **Terpenuhi & Terverifikasi**.
7. Suite 13 dan Suite 14 terdaftar di `test_runner.gd` dengan kelulusan 100%: **Terpenuhi & Terverifikasi (2.126 asersi lulus)**.
8. Evaluasi gerbang konsensus multi-agent (Reviewer 1 APPROVE, Reviewer 2 APPROVE, Challenger 1 APPROVE, Challenger 2 APPROVE, Auditor CLEAN): **Terpenuhi & Terverifikasi**.

## Dampak, kompatibilitas dan keterbatasan

- **Konten:** Siklus resep Sayur Bening Bayam dan Jagung kini dapat diselesaikan dari bahan mentah hingga hidangan matang dan dikonsumsi.
- **UI:** Panel dapur memiliki visual kontrol panas yang intuitif dan aman; panel tas memiliki tombol aksi makan dengan konfirmasi inline.
- **Save:** Skema save envelope v1 mempertahankan kompatibilitas penuh dan menambahkan state memasak aktif serta flag `meal_used`.
- **Keterbatasan:** Interaksi dialog dan berbagi hidangan dengan tetangga (`npc_neighbor_01`) tidak termasuk dalam milestone ini dan merupakan fokus utama milestone berikutnya (`SOC-001`).

## Tindak lanjut dan handoff

Milestone berikutnya yang harus dikerjakan adalah **`SOC-001` (Interaksi Sosial, Dialog Tetangga, Berbagi Hidangan, dan Penutup P0)**:
- Prasyarat: `COOK-002` telah selesai penuh dan flag `meal_used` serta ketersediaan `dish_sayur_bening` sudah terpasang.
- Ruang lingkup `SOC-001`: Dialog dengan tetangga (`npc_neighbor_01`), opsi berbagi makanan (`action_share`), evaluasi kriteria penutup P0 (*"Satu resep selesai. Kebun ini baru dimulai."*), dan pemicu ending P0 saat hidangan dibagikan atau dimakan.

## Penutupan catatan

Laporan ini telah ditautkan di `docs/PROJECT_STATUS.md` pada daftar pekerjaan selesai, status task `COOK-002` telah dimutakhirkan menjadi `SELESAI` di `docs/TASKS.md`, dan deskripsi status pekerjaan terakhir telah diganti dengan ringkasan mutakhir kondisi proyek.
