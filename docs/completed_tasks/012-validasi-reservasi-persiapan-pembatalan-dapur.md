# Laporan Selesai: Validasi Bahan Resep, Reservasi Atomik, Aksi Tahan Persiapan 4s, Pembatalan Aman & Wadah Refund (COOK-001)

Dokumen ini mencatat penyelesaian implementasi milestone COOK-001 sesuai aturan kerja `AGENTS.md` § 6.

## Identitas

- **ID task:** COOK-001
- **Judul:** Validasi Bahan Resep, Reservasi Atomik, Aksi Tahan Persiapan 4s, Pembatalan Aman Pra-Masak dan Wadah Refund
- **Tanggal selesai:** 28 Oktober 2026
- **Agent/pelaksana:** orchestrator_gen6 (Project Orchestrator Hierarchy: worker_cook_001, reviewer_cook_001_1, reviewer_cook_001_2, challenger_cook_001_1, challenger_cook_001_2, auditor_cook_001)
- **Tahap produk:** P0 (Stasiun Dapur Rumah, Validasi Stok Bebas Lintas Tas & Peti, Reservasi Atomik dengan ID Stabil dan Origin Manifest, Akumulasi Tahan Persiapan 4.0s dengan Retensi Interupsi, Pembatalan Aman Berjenjang 3-Tingkat, Wadah Pengembalian Persisten `kitchen_refund`, Interlock Kasur Tidur, Suite 11 TestCooking T10/T11/T12/T13/T40 dan Suite 12 TestAdversarialCooking)
- **Status:** Selesai (Lulus 100% verifikasi headless: 1,695 asersi test runner + 364 asersi stress harness, 0 gagal, exit code 0)
- **Versi sumber/build:** Git working tree lokal, Godot 4.7.2-stable official

## Tujuan dan pemicu

Sesuai spesifikasi `PRD.md` FR12, `docs/TASKS.md` (bagian COOK-001), `docs/CONTENT.md` § 2, § 3, § 4, § 11, § 12, `docs/PROTOTYPE.md` § 4, § 5, § 6.2, § 6.3, dan kasus uji `docs/TEST_PLAN.md` T10, T11, T12, T13, T40:
1. Pemain membutuhkan stasiun dapur rumah (`station_kitchen_home`) untuk mempersiapkan resep P0 (Sayur Bening Bayam dan Jagung: 3 bayam, 1 jagung, 1 temu kunci).
2. Sistem dapur wajib memvalidasi stok bahan baku bebas secara menyeluruh lintas tas pemain (`backpack`) dan peti penyimpanan rumah (`storage_home`). Jika salah satu bahan kurang, persiapan dilarang dimulai dan wajib memberikan pesan jujur Indonesia serta kamus bahan yang kurang tanpa memutasi stok.
3. Transaksi penarikan bahan wajib atomik: bahan ditarik secara fisik dari tas terlebih dahulu (indeks slot terkecil), lalu sisa kekurangannya ditarik dari peti rumah, dengan mencatat wadah asal pada `origin_manifest`.
4. Persiapan fisik membutuhkan aksi tahan tombol persiapan selama 4.0 detik. Jika input dilepas di tengah jalan (< 4.0s), kemajuan waktu persiapan dipertahankan (*retained on interrupt*) tanpa membatalkan reservasi. Saat mencapai 4.0 detik, stasiun bertransisi ke status `READY_TO_HEAT`. Menahan terus tombol tidak boleh memicu proses memasak secara otomatis (*no auto-cook invariant* per `CONTENT.md` § 4).
5. Pemain dapat membatalkan persiapan pra-masak kapan saja. Pembatalan menerapkan pengembalian berjenjang 3-tingkat:
   - **Tingkat 1:** Kembalikan ke kontainer asal berdasarkan `origin_manifest`.
   - **Tingkat 2:** Jika kontainer asal penuh (diisi item lain saat persiapan), alihkan ke kontainer alternatif (tas $\leftrightarrow$ peti).
   - **Tingkat 3:** Jika kedua kontainer penuh (12/12), alihkan ke wadah persisten `inv.kitchen_refund`.
   - **Invarian Isolasi Output:** Bahan mentah yang dibatalkan dilarang keras mencemari slot hasil masakan (`dish_output_slot`).
6. Interlock kasur tidur: Pemain dilarang tidur saat persiapan dapur sedang aktif (`RESERVED_PREPARING` atau `READY_TO_HEAT`) guna mencegah korupsi state memasak.
7. Semua state dapur harus mendukung serialisasi envelope snapshot v1 untuk integrasi save/load.

## Ruang lingkup

Ruang lingkup yang diselesaikan dalam task ini:
- `scripts/cooking/kitchen_manager.gd`:
  - Autoload singleton `KitchenManager` terdaftar di `project.godot` (menggunakan `extends Node` tanpa `class_name` shadowing).
  - State machine dapur: enum `JobState` (`IDLE = 0`, `RESERVED_PREPARING = 1`, `READY_TO_HEAT = 2`, `COOKING = 3`, `PAUSED = 4`, `OUTPUT_READY = 5`, `REFUND_PENDING = 6`).
  - Validasi bahan kering (`can_start_preparation`) memeriksa stok bebas lintas kontainer dan memastikan `dish_output_slot` kosong.
  - Reservasi atomik (`start_preparation`) dengan penarikan slot fisik, penomoran job unik (`job_sayur_bening_01_X`), pencatatan `origin_manifest`, dan respon idempotent anti-spam.
  - Controller tahan persiapan (`advance_prep`, `hold_tick`) dengan clamp 4.0s dan transisi ke `READY_TO_HEAT`.
  - Pembatalan aman berjenjang 3-tingkat (`cancel_preparation`) dan pengambilan refund (`claim_refund_items`).
  - Serialisasi snapshot envelope v1 (`get_save_snapshot`, `load_save_snapshot`).
- `scenes/ui/kitchen_ui.tscn` & `scripts/ui/kitchen_ui.gd`:
  - CanvasLayer responsif (layer 10) dengan antarmuka dapur lengkap: panel kartu resep, daftar bahan dengan indikator ketersediaan terpadu (tas + peti), bilah meteran persiapan, tombol interaktif, dan panel peringatan wadah refund.
  - Penanganan unhandled input Esc / pembatalan modal context.
- `scripts/main.gd`:
  - Registrasi landmark `station_kitchen_home` ke `interaction_id = "landmark_kitchen"`.
  - Penanganan transisi konteks input `InputManager.ContextMode.KITCHEN` saat antarmuka dapur dibuka dan pemulihannya ke `WORLD` saat ditutup.
- `scripts/ui/hud.gd`:
  - Prompt reticle kontekstual dinamis: `[E] Masak`, `[E] Lanjutkan Dapur`, `[E] Buka Dapur (Sedang Memasak)`, `[E] Ambil Masakan`.
- `scripts/world/world_resource_manager.gd`:
  - Penambahan interlock tidur pada `can_sleep()` dan `sleep_and_advance_day()` yang memeriksa `KitchenManager.is_job_active()`.
- `scripts/inventory/inventory_container.gd`:
  - Helper `get_used_slots_count()` dan `get_slots()` untuk inspeksi slot aman.
- `tests/suites/test_cooking.gd`:
  - Suite 11 (26 metode uji acceptance terperinci untuk T10, T11, T12, T13, T40, interlock tidur, snapshot envelope v1).
- `tests/suites/test_adversarial_cooking.gd`:
  - Suite 12 (8 metode uji stres empiris untuk gating, split atomik, 100x spam start/cancel, re-entrancy 50 siklus, hold clamping, limpahan 3-tingkat, dan kekekalan materi).
- `tests/adversarial_cook_001_stress.gd`:
  - Standalone empirical stress test harness (364 asersi) yang memverifikasi micro-step floating point drift, jitter input, pelimpahan parsial bertingkat, dan isolasi slot output.

## Perubahan dan perilaku akhir

1. **Validasi Bahan Bebas (T10):**
   - Ketika bahan Sayur Bening Bayam dan Jagung (3 bayam, 1 jagung, 1 temu kunci) belum lengkap di tas maupun di peti, tombol Mulai Persiapan dinonaktifkan di UI dan `can_start_preparation()` mengembalikan `success: false` dengan rincian kekurangan bahan.
   - Jika slot output masakan masih terisi hidangan sebelumnya, persiapan resep baru diblokir hingga hidangan diambil (`"Ambil hidangan sebelumnya dahulu."`).
2. **Reservasi Atomik & Penarikan Fisik (T11):**
   - Saat persiapan dimulai, bahan ditarik secara fisik dari tas terlebih dahulu (indeks slot terkecil), lalu kekurangannya ditarik dari peti penyimpanan rumah.
   - `origin_manifest` mencatat asal setiap unit bahan yang ditarik.
   - Stok bebas di `InventoryManager` langsung berkurang sehingga tidak dapat digunakan untuk aksi lain.
3. **Aksi Tahan Persiapan 4.0s (T12):**
   - Menahan tombol persiapan mengakumulasi waktu hingga 4.0 detik.
   - Melepas tombol sebelum 4.0s mempertahankan kemajuan waktu persiapan (*retained on interrupt*).
   - Tepat pada 4.0 detik, status stasiun bertransisi ke `READY_TO_HEAT` dan memancarkan sinyal `preparation_completed`.
   - Menahan tombol melampaui 4.0 detik tidak memicu `COOKING` secara otomatis (*no auto-cook invariant*). Memasak membutuhkan aksi diskrit terpisah pada tahap berikutnya.
4. **Pembatalan Aman 3-Tingkat & Kekekalan Materi (T13 & T40):**
   - Pembatalan persiapan mengembalikan bahan ke kontainer asal.
   - Jika kontainer asal penuh, bahan dialihkan ke kontainer alternatif.
   - Jika kedua kontainer penuh (12/12 slot), bahan dialihkan ke wadah persisten `inv.kitchen_refund`.
   - Slot hasil masakan (`dish_output_slot`) terisolasi 100% dan tidak pernah menerima bahan mentah yang dibatalkan.
   - Total unit materi di seluruh dunia terbukti konstan dan kekal tanpa kebocoran (*item sink*) maupun penggandaan (*duplication exploit*).
5. **Karantina Tidur Kasur:**
   - Memanggil `sleep_and_advance_day()` saat persiapan atau masakan di dapur sedang aktif ditolak secara bersih dengan pesan *"Selesaikan atau batalkan proses memasak dahulu sebelum istirahat."*, melindungi siklus hari kalender dari korupsi status memasak.

## File yang ditambahkan atau diubah

| Path Relatif | Perubahan | Tujuan |
|---|---|---|
| `scripts/cooking/kitchen_manager.gd` | Ditambahkan (Baru) | Autoload singleton stasiun dapur, state machine, validasi, reservasi, hold, pembatalan 3-tingkat, dan snapshot |
| `scenes/ui/kitchen_ui.tscn` | Ditambahkan (Baru) | Adegan UI antarmuka dapur responsif Godot 4 (CanvasLayer layer 10) |
| `scripts/ui/kitchen_ui.gd` | Ditambahkan (Baru) | Kontroler UI dapur, deteksi tahan 4s, integrasi tombol, pembatalan, dan klaim refund |
| `scripts/main.gd` | Diubah | Penyambungan landmark `station_kitchen_home` dan penanganan konteks input `ContextMode.KITCHEN` |
| `scripts/ui/hud.gd` | Diubah | Prompt reticle kontekstual dinamis untuk landmark dapur |
| `scripts/world/world_resource_manager.gd` | Diubah | Interlock tidur kasur menolak tidur saat dapur aktif |
| `scripts/inventory/inventory_container.gd` | Diubah | Penambahan helper `get_used_slots_count()` dan `get_slots()` |
| `project.godot` | Diubah | Pendaftaran autoload `KitchenManager="*res://scripts/cooking/kitchen_manager.gd"` |
| `tests/suites/test_cooking.gd` | Ditambahkan (Baru) | Suite 11 (26 metode uji acceptance COOK-001) |
| `tests/suites/test_adversarial_cooking.gd` | Ditambahkan (Baru) | Suite 12 (8 metode uji stres empiris COOK-001) |
| `tests/adversarial_cook_001_stress.gd` | Ditambahkan (Baru) | Standalone empirical stress test harness (364 asersi) |
| `tests/run_adversarial_cooking.gd` | Ditambahkan (Baru) | Runner mandiri untuk Suite 12 |
| `tests/test_runner.gd` | Diubah | Pendaftaran Suite 11 dan Suite 12 ke runner otomatis utama proyek |

## Verifikasi yang benar-benar dilakukan

| ID Pemeriksaan | Lingkungan / Input | Tindakan | Hasil Nyata | Status |
|---|---|---|---|---|
| VERIF-COOK-01 | Headless CLI / `test_cooking.gd` | Eksekusi 26 metode uji acceptance Suite 11 (T10, T11, T12, T13, T40, interlock tidur, save snapshot envelope v1) | 153 asersi lulus, 0 gagal, exit code 0 | **LULUS** |
| VERIF-COOK-02 | Headless CLI / `test_adversarial_cooking.gd` | Eksekusi 8 metode uji stres Suite 12 (gating batas, split atomik, 100x spam start/cancel, re-entrancy 50 siklus, hold clamping, limpahan 3-tingkat, kekekalan materi) | 309 asersi lulus, 0 gagal, exit code 0 | **LULUS** |
| VERIF-COOK-03 | Headless CLI / `adversarial_cook_001_stress.gd` | Eksekusi 8 skenario stres empiris (micro-step drift 4,000 steps, jitter flutter 50 siklus, cascading limpahan parsial, isolasi slot output, spam claim refund) | 364 asersi lulus, 0 gagal, exit code 0 | **LULUS** |
| VERIF-COOK-04 | Headless CLI / `test_runner.gd` | Eksekusi lengkap seluruh 12 test suite proyek (Suite 1 hingga Suite 12) | 1,695 asersi lulus, 0 gagal, exit code 0 | **LULUS** |
| VERIF-COOK-05 | Pemeriksaan Integritas Auditor | Audit statis dan analisis jejak eksekusi runtime pada seluruh modul dapur baru | CLEAN, zero integrity violation, nol bypass dummy/hardcode | **LULUS** |

Perintah eksekusi verifikasi aktual yang dijalankan:
```powershell
& "C:\Users\HP\.local\bin\godot.exe" --headless --path . --script res://tests/test_runner.gd; exit $LASTEXITCODE
& "C:\Users\HP\.local\bin\godot.exe" --headless --path . --script res://tests/adversarial_cook_001_stress.gd; exit $LASTEXITCODE
```

## Kriteria selesai

1. **Validasi bahan bebas terpadu (T10):** Terpenuhi. Pemeriksaan ketersediaan bahan memeriksa gabungan tas dan peti rumah secara atomik.
2. **Reservasi atomik dengan ID stabil & origin manifest (T11):** Terpenuhi. Penarikan slot fisik mencatat kontainer asal pada `origin_manifest` dan mengunci bahan dari penggunaan lain.
3. **Aksi tahan persiapan 4.0s dengan retensi interupsi (T12):** Terpenuhi. Waktu persiapan tertahan saat tombol dilepas, mencapai 4.0s bertransisi ke `READY_TO_HEAT`, dan tidak auto-cook.
4. **Pembatalan aman 3-tingkat & kekekalan materi (T13 & T40):** Terpenuhi. Bahan batal dialihkan ke asal $\rightarrow$ alternatif $\rightarrow$ `kitchen_refund`. Total materi 485 unit terbukti 100% konstan.
5. **Isolasi slot hasil masakan:** Terpenuhi. `dish_output_slot` tidak pernah terkontaminasi bahan batal.
6. **Interlock kasur tidur:** Terpenuhi. Tidur kasur ditolak selama status dapur aktif (`RESERVED_PREPARING` atau `READY_TO_HEAT`).
7. **Suite pengujian lengkap & bebas regresi:** Terpenuhi. 1,695 asersi lulus pada 12 test suite dengan exit code 0.

## Dampak, kompatibilitas dan keterbatasan

- **Pengaruh terhadap UI:** `KitchenUI` terdaftar sebagai antarmuka modal pada layer 10 yang terintegrasi dengan sistem context input `ContextMode.KITCHEN`.
- **Pengaruh terhadap Save/Load:** Autoload `KitchenManager` mengimplementasikan `get_save_snapshot()` dan `load_save_snapshot()` versi 1 yang siap diintegrasikan secara utuh pada `SAVE-001`.
- **Keterbatasan Milestone:** Kontrol tingkat panas (Rendah $\times 0.5$, Sedang $\times 1.0$, Tinggi $\times 0.0$ stall), timer memasak 30s, pembuatan hidangan `dish_sayur_bening`, dan aksi makan hidangan sengaja dibatasi untuk diimplementasikan pada milestone berikutnya (`COOK-002`).

## Tindak lanjut dan handoff

- **Task berikutnya:** `COOK-002` (Kontrol Panas Rendah/Sedang/Tinggi, Timer Memasak 30 Detik, Jeda Simulasi saat Tutup Panel, Slot Hasil Masakan `dish_sayur_bening`, Centang Buku Resep, dan Aksi Makan Hidangan).
- **Prasyarat:** `COOK-001` selesai 100% (terpenuhi).
- **Sumber data wajib baca:** `docs/CONTENT.md` § 2, 4, 11, `docs/PROTOTYPE.md` § 4, `docs/TEST_PLAN.md` T12, T15, T19, T41, T42.

## Penutupan catatan

Laporan ini ditautkan pada `docs/PROJECT_STATUS.md`, task `COOK-001` ditandai SELESAI di `docs/TASKS.md`, dan deskripsi status pekerjaan terakhir dimutakhirkan.
