# Buku Resep 2045 — Paket Dokumentasi Pengembangan

**Versi paket:** 0.3 · **Tanggal:** 30 Oktober 2026 · **Pemilik:** Muhammad Fauzi  
**Tahap saat ini:** P0 gameplay selesai (QA-001): proyek Godot, kode game GDScript, suite tes headless dan Git lokal sudah ada. Build mandiri dan installer belum dibuat, dan bukti kendali desktop manual (DEMO-001) masih menunggu. Tahap berikutnya P0.5 "Kampung Hidup" (PRD D26–D32) baru tahap dokumen: dokumen sumber sudah diperbarui (SCOPE-001), kode P0.5 belum dikerjakan. Keadaan pelaksanaan terbaru hanya di [PROJECT_STATUS](docs/PROJECT_STATUS.md). “Buku Resep 2045” adalah nama kerja, bukan judul rilis final. Format identitas event adalah **Nama Game: Nama Event**; Karhutla merupakan contoh judul event, bukan chapter atau nama utama.

## 1. Tujuan paket

Paket ini menjadi konteks bersama bagi pemilik proyek dan AI agent saat mengembangkan game PC 3D first person tentang buku resep keluarga, pencarian pangan, perawatan kebun, dan kehidupan kampung Indonesia dalam krisis fiktif tahun 2045. Dokumen ditulis agar pengembangan dapat dilanjutkan bergantian oleh AI tanpa mengandalkan riwayat chat.

Prototipe satu resep (P0) sudah diimplementasikan dan lulus uji otomatis yang tercatat di laporan task; kenyamanan dan kendali langsung masih memerlukan uji manual pemilik. Cakupan aktif berikutnya adalah P0.5 "Kampung Hidup": dunia sekitar 1 km² dengan chunk streaming, visual CC0 + generator kode, warga bergerak berjadwal, tiga resep warisan dan save v2. Kelengkapan dokumen berbeda dari kelengkapan implementasi.

## 2. Memasukkan paket ke VS Code

1. Ekstrak ZIP. Di dalamnya terdapat folder `Buku_Resep_2045_Dokumentasi_v0_2`.
2. Jika belum memiliki proyek, gunakan folder tersebut sebagai folder utama game. Namanya boleh diganti tanpa mengubah tautan relatif antarfile.
3. Jika sudah memiliki folder game, salin `README.md`, `PRD.md`, `AGENTS.md`, dan folder `docs/` ke root folder game. Jangan menimpa perubahan lokal tanpa membandingkannya terlebih dahulu.
4. Di VS Code, gunakan **File → Open Folder**, lalu pilih folder yang langsung berisi `README.md`, `PRD.md`, dan `AGENTS.md`.
5. Mulai dari dokumen ini. Buka Markdown Preview untuk membaca tabel dan tautan. SVG wireframe dapat dibuka dengan penampil gambar atau browser.
6. Saat sesi coding diotorisasi, AI mulai dari task yang ditunjuk pengguna (lihat PROJECT_STATUS dan TASKS), dengan membaca aturan agent terlebih dahulu. SETUP-001 dan seluruh task P0 sudah selesai.

Tidak ada perintah instalasi dependency yang perlu dijalankan untuk membaca dokumen. Jangan mencari `package.json`: proyek yang direncanakan menggunakan Godot, bukan aplikasi web.

## 3. Keputusan dasar

| Bagian | Keputusan |
| --- | --- |
| Bentuk game | PC desktop, 3D, first person |
| Engine | Godot 4.7.2-stable official win64 (`4.7.2.stable.official.ed1daf0bf`) |
| Renderer | `gl_compatibility` (OpenGL 3.3) untuk efisiensi GPU laptop dan pengujian headless |
| Bahasa | GDScript |
| Editor kode dan AI | VS Code |
| Riwayat sumber | Git lokal diinisialisasi; repository remote belum dipublikasikan |
| Visual | Stylized sederhana, referensi artistik Firewatch, identitas lingkungan Indonesia; P0.5 memakai aset CC0 terverifikasi dan generator kode, tanpa aset Firewatch |
| Prinsip UI | Sederhana, nyaman, kontekstual, mudah dipahami |
| Prototipe (P0) | Sayur Bening Bayam dan Jagung; bayam ditanam, jagung dipanen, temu kunci dicari |
| Cakupan aktif (P0.5) | Kumpulkan 3 resep warisan di dunia sekitar 1 km² yang dimuat per chunk; Pepes Ikan Nila dan Urap Pakis Kelapa menjadi resep 2 dan 3 (DEFAULT UJI); warga bergerak berjadwal; save v2 |
| Mode kerja P0 | Single-player offline sebagai default rancangan prototipe |
| Perawatan | Tanam per titik; pupuk dan air per petak |


## 4. Peta dokumen

| Dokumen | Dibaca untuk |
| --- | --- |
| [PRD.md](PRD.md) | Tujuan, keputusan produk, batas cakupan, persyaratan dan tahap rilis |
| [AGENTS.md](AGENTS.md) | Aturan kerja AI, verifikasi, handoff, dan kewajiban mencatat tugas |
| [PROTOTYPE.md](docs/PROTOTYPE.md) | Alur lengkap satu resep dan kontrak perilaku antarsistem |
| [ART_DIRECTION.md](docs/ART_DIRECTION.md) | Bentuk aset, warna, material, pencahayaan, audio dan batas produksi |
| [UI_UX.md](docs/UI_UX.md) | Kontrol, layout, wireframe, status layar dan aksesibilitas |
| [LEVEL_DESIGN.md](docs/LEVEL_DESIGN.md) | Denah awal, koordinat rancangan, rute, landmark dan spawn |
| [EVENT_DESIGN.md](docs/EVENT_DESIGN.md) | Kerangka event tematik, usulan Karhutla, sains sederhana dan hubungan ke map/resep/save |
| [CONTENT.md](docs/CONTENT.md) | ID item, jumlah, waktu, sumber bahan, teks, dialog dan aturan angka |
| [TASKS.md](docs/TASKS.md) | Urutan pekerjaan, dependensi dan kriteria selesai |
| [TEST_PLAN.md](docs/TEST_PLAN.md) | Prosedur uji, hasil yang diharapkan dan gerbang penerimaan |
| [CONSISTENCY_CHECK.md](docs/CONSISTENCY_CHECK.md) | Hasil pemeriksaan akhir hubungan, konsistensi dan paket |
| [PROJECT_STATUS.md](docs/PROJECT_STATUS.md) | Daftar pekerjaan yang benar-benar selesai dan keadaan terbaru |
| [Rencana induk P0.5](docs/plans/00-rencana-induk.md) | Rasional teknis dan urutan gelombang tahap P0.5; rencana [01 dunia](docs/plans/01-dunia-chunk-streaming.md), [02 visual](docs/plans/02-visual-aset-karakter-ui.md), [03 goal dan warga](docs/plans/03-goal-resep-npc-cerita.md) dan [04 dampak, uji, risiko](docs/plans/04-dampak-dokumen-task-uji-risiko.md). Keputusan yang berlaku ada di PRD dan dokumen domain, bukan di rencana |
| [Panduan arsip](docs/completed_tasks/README.md) | Tata cara menulis laporan task selesai |
| [Template laporan](docs/completed_tasks/TEMPLATE.md) | Struktur yang disalin agent untuk laporan berikutnya |
| [Wireframe SVG v0.2](docs/wireframes/wireframes-v0.2.svg) dan [pratinjau PNG](docs/wireframes/wireframes-v0.2.png) | Enam layar rancangan; SVG dapat diedit, PNG mudah dilihat; bukan screenshot implementasi |

## 5. Urutan membaca dan sumber acuan

AI pada sesi pertama membaca `AGENTS.md`, `PROJECT_STATUS.md`, `PRD.md`, lalu `TASKS.md`. Setelah memilih task, baca dokumen detail yang dirujuk dan laporan task terakhir. Pengguna dapat mulai dari PRD, prototipe dan UI/UX.

Urutan keputusan: instruksi terbaru pengguna → keputusan produk yang disetujui dalam PRD → aturan detail domain. `CONTENT.md` adalah acuan tunggal nilai numerik konten, dunia/chunk dan anggaran performa; `UI_UX.md` acuan perilaku antarmuka; `LEVEL_DESIGN.md` acuan tata ruang. Nilai yang ditampilkan di wireframe hanya contoh keadaan layar. Jika ada konflik, agent memperbaiki dokumen terkait sebelum memperluas pekerjaan, bukan memilih diam-diam.

## 6. Status yang harus dipahami sebelum bekerja

Paket v0.2 memperbarui PRD v0.1 dan wireframe v0.1 berdasarkan diskusi sampai 27 Oktober 2026; v0.3 (30 Oktober 2026) menerapkan arahan pemilik untuk P0.5 pada dokumen sumber. Paket lama tidak disertakan sebagai acuan aktif agar AI tidak membaca dua keputusan engine atau resep yang berbeda.

Versi Godot telah ditetapkan dan dikunci pada Godot 4.7.2-stable official win64 (`4.7.2.stable.official.ed1daf0bf`) dengan renderer `gl_compatibility`. Default target uji pertama adalah Windows desktop 64-bit. Main scene awal berada pada `res://scenes/main.tscn`. Struktur folder proyek dan test harness otomatis telah dibuat dan diverifikasi via headless runner.

Belum ada aset visual eksternal yang diimpor (folder `assets/` hanya memuat audio prosedural dan lognya); P0.5 hanya memakai aset CC0 terverifikasi dan generator kode, dengan manifes lisensi (ART_DIRECTION bagian 10). Wireframe merupakan gambar rancangan v0.2 dan belum memuat buku tiga halaman. Hasil pengujian otomatis tercatat di laporan task dan [TEST_PLAN](docs/TEST_PLAN.md) bagian 1; README ini tidak mengulang angkanya.

## 7. Struktur direktori proyek

Struktur direktori game diorganisasikan sebagai berikut:

| Path | Fungsi |
| --- | --- |
| `project.godot` | Konfigurasi engine Godot (nama game, renderer `gl_compatibility`, viewport 1280x720, input map) |
| `.gitignore` | Aturan pengabaian cache `.godot/`, build outputs, dan temporary logs |
| `scenes/` | Adegan game (`scenes/main.tscn` sebagai main scene 3D awal, dunia, pemain, dan UI) |
| `scripts/` | Logika GDScript (core, player, interaction, inventory, recipe, gardening, world, cooking, social, save) |
| `data/` | Kamus data runtime (definisi item, resep, dan parameter pertumbuhan) |
| `assets/` | Aset visual dan audio; saat ini baru audio. P0.5 merencanakan subfolder aset pihak ketiga dengan manifes lisensi dan material/shader bersama (lokasi final ditetapkan ASSET-001 dan VIS-001) |
| `scripts/` generator visual dan dunia (direncanakan) | P0.5 merencanakan generator visual prosedural, medan/chunk dan warga bergerak; folder dan nama berkas ditetapkan task yang mengerjakannya (WORLD-002 dan seterusnya) |
| `docs/plans/` | Rencana induk dan rencana 01–04 untuk P0.5 (rasional; bukan sumber keputusan) |
| `tests/` | Test harness otomatis (`assertions.gd`, `test_runner.gd`, dan `tests/suites/`) |
| `builds/` | Direktori lokal hasil build/ekspor mandiri (diabaikan oleh git) |

Lokasi save data runtime diarahkan ke profil pengguna OS: `%APPDATA%\Godot\app_userdata\Buku Resep 2045\` (`user://`).

## 8. Menjalankan game dan pengujian

### 8.1 Menjalankan Game (GUI / Desktop)

```bash
# Menjalankan main scene langsung
godot

# Menjalankan scene tertentu
godot scenes/main.tscn

# Membuka proyek di Godot Editor
godot -e
```

### 8.2 Menjalankan Pengujian Otomatis (Headless CLI)

```bash
# Menjalankan automated test harness (T23, T24, dan suite selanjutnya)
godot --headless --script res://tests/test_runner.gd

# Atau menggunakan konsol wrapper:
godot_console --headless --script res://tests/test_runner.gd

# Menjalankan smoke test 60 frame (memastikan scene memuat dan berjalan tanpa crash)
godot_console --headless --quit-after 60
```

## 9. Catatan kerja yang ringkas

`TASKS.md` memuat rencana, `PROJECT_STATUS.md` memuat kenyataan terbaru, dan satu laporan dalam `completed_tasks/` menjelaskan setiap task selesai. Deskripsi status terakhir diganti setiap ada perkembangan; detail historis berada di laporan, bukan ditambahkan terus ke status utama.

Sesi coding hanya dimulai atas permintaan pengguna dan dalam cakupan yang diotorisasi; dokumen ini tidak memberi izin otomatis untuk menginstal aplikasi, memublikasikan repository atau memulai implementasi P0.5. Task berikutnya dan urutannya dibaca dari [TASKS](docs/TASKS.md) dan PROJECT_STATUS.

## 10. Gagasan event terbaru

Satu map fiksi dapat menerima event berbeda yang terinspirasi kondisi Indonesia. Karhutla adalah judul event contoh dengan kebakaran yang memengaruhi akses bahan dan pemulihan, bukan nama game atau chapter. Sains diterapkan sederhana pada api, air dan kebun. Arah event dicatat sebagai keputusan desain terbaru; detail mekanik dan angka masih USULAN BARU untuk tahap sesudah P0. Tidak ada pengambilan berita otomatis atau jadwal event online pada rancangan default.

## 11. Riwayat perubahan

| Versi | Tanggal | Perubahan |
| --- | --- | --- |
| 0.2 | 27 Oktober 2026 | Paket dokumentasi awal |
| 0.3 | 30 Oktober 2026 | SCOPE-001: keadaan nyata (kode dan tes ada), cakupan aktif P0.5, peta dokumen memuat `docs/plans/`, direktori aset dan generator, batas klaim aset |
