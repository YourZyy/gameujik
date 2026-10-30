# Buku Resep 2045 — Paket Dokumentasi Pengembangan

**Versi paket:** 0.2 · **Tanggal:** 27 Oktober 2026 · **Pemilik:** Muhammad Fauzi  
**Tahap saat diserahkan:** persiapan pengembangan. Kode game, proyek Godot, build, instalasi, dan repository belum dibuat dalam paket ini. “Buku Resep 2045” adalah nama kerja, bukan judul rilis final. Format identitas event adalah **Nama Game: Nama Event**; Karhutla merupakan contoh judul event, bukan chapter atau nama utama.

## 1. Tujuan paket

Paket ini menjadi konteks bersama bagi pemilik proyek dan AI agent saat mengembangkan game PC 3D first person tentang buku resep keluarga, pencarian pangan, perawatan kebun, dan kehidupan kampung Indonesia dalam krisis fiktif tahun 2045. Dokumen ditulis agar pengembangan dapat dilanjutkan bergantian oleh AI tanpa mengandalkan riwayat chat.

Hasil yang dipersiapkan adalah prototipe satu resep yang dapat dimainkan dari awal hingga akhir. Paket dokumentasi ini sudah dapat dibaca dan digunakan untuk merencanakan tugas; game belum dapat dijalankan. Kelengkapan dokumen berbeda dari kelengkapan implementasi.

## 2. Memasukkan paket ke VS Code

1. Ekstrak ZIP. Di dalamnya terdapat folder `Buku_Resep_2045_Dokumentasi_v0_2`.
2. Jika belum memiliki proyek, gunakan folder tersebut sebagai folder utama game. Namanya boleh diganti tanpa mengubah tautan relatif antarfile.
3. Jika sudah memiliki folder game, salin `README.md`, `PRD.md`, `AGENTS.md`, dan folder `docs/` ke root folder game. Jangan menimpa perubahan lokal tanpa membandingkannya terlebih dahulu.
4. Di VS Code, gunakan **File → Open Folder**, lalu pilih folder yang langsung berisi `README.md`, `PRD.md`, dan `AGENTS.md`.
5. Mulai dari dokumen ini. Buka Markdown Preview untuk membaca tabel dan tautan. SVG wireframe dapat dibuka dengan penampil gambar atau browser.
6. Saat sesi coding nanti diotorisasi, AI mulai dari task `SETUP-001` di daftar tugas, dengan membaca aturan agent terlebih dahulu.

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
| Visual | Stylized sederhana, referensi artistik Firewatch, identitas lingkungan Indonesia |
| Prinsip UI | Sederhana, nyaman, kontekstual, mudah dipahami |
| Prototipe | Sayur Bening Bayam dan Jagung; bayam ditanam, jagung dipanen, temu kunci dicari |
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
| [Panduan arsip](docs/completed_tasks/README.md) | Tata cara menulis laporan task selesai |
| [Template laporan](docs/completed_tasks/TEMPLATE.md) | Struktur yang disalin agent untuk laporan berikutnya |
| [Wireframe SVG v0.2](docs/wireframes/wireframes-v0.2.svg) dan [pratinjau PNG](docs/wireframes/wireframes-v0.2.png) | Enam layar rancangan; SVG dapat diedit, PNG mudah dilihat; bukan screenshot implementasi |

## 5. Urutan membaca dan sumber acuan

AI pada sesi pertama membaca `AGENTS.md`, `PROJECT_STATUS.md`, `PRD.md`, lalu `TASKS.md`. Setelah memilih task, baca dokumen detail yang dirujuk dan laporan task terakhir. Pengguna dapat mulai dari PRD, prototipe dan UI/UX.

Urutan keputusan: instruksi terbaru pengguna → keputusan produk yang disetujui dalam PRD → aturan detail domain. `CONTENT.md` adalah acuan tunggal nilai numerik konten; `UI_UX.md` acuan perilaku antarmuka; `LEVEL_DESIGN.md` acuan tata ruang. Nilai yang ditampilkan di wireframe hanya contoh keadaan layar. Jika ada konflik, agent memperbaiki dokumen terkait sebelum memperluas pekerjaan, bukan memilih diam-diam.

## 6. Status yang harus dipahami sebelum bekerja

Paket v0.2 memperbarui PRD v0.1 dan wireframe v0.1 berdasarkan diskusi sampai 27 Oktober 2026. Paket lama tidak disertakan sebagai acuan aktif agar AI tidak membaca dua keputusan engine atau resep yang berbeda.

Versi Godot telah ditetapkan dan dikunci pada Godot 4.7.2-stable official win64 (`4.7.2.stable.official.ed1daf0bf`) dengan renderer `gl_compatibility`. Default target uji pertama adalah Windows desktop 64-bit. Main scene awal berada pada `res://scenes/main.tscn`. Struktur folder proyek dan test harness otomatis telah dibuat dan diverifikasi via headless runner.

Belum ada aset eksternal komersial yang diimpor. Wireframe merupakan gambar rancangan v0.2. Pengujian otomatis baseline T23 dan T24 telah diverifikasi lolos 100% pada tahap SETUP-001.

## 7. Struktur direktori proyek

Struktur direktori game diorganisasikan sebagai berikut:

| Path | Fungsi |
| --- | --- |
| `project.godot` | Konfigurasi engine Godot (nama game, renderer `gl_compatibility`, viewport 1280x720, input map) |
| `.gitignore` | Aturan pengabaian cache `.godot/`, build outputs, dan temporary logs |
| `scenes/` | Adegan game (`scenes/main.tscn` sebagai main scene 3D awal, dunia, pemain, dan UI) |
| `scripts/` | Logika GDScript (core, player, interaction, inventory, recipe, gardening, world, cooking, social, save) |
| `data/` | Kamus data runtime (definisi item, resep, dan parameter pertumbuhan) |
| `assets/` | Aset visual dan audio (model, material, tekstur, font, SFX) |
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

Keputusan pengembangan berikutnya adalah memulai setup hanya setelah pengguna meminta sesi coding. Paket ini tidak memberi izin otomatis untuk menginstal aplikasi, membuat repository atau memublikasikan sesuatu.

## 10. Gagasan event terbaru

Satu map fiksi dapat menerima event berbeda yang terinspirasi kondisi Indonesia. Karhutla adalah judul event contoh dengan kebakaran yang memengaruhi akses bahan dan pemulihan, bukan nama game atau chapter. Sains diterapkan sederhana pada api, air dan kebun. Arah event dicatat sebagai keputusan desain terbaru; detail mekanik dan angka masih USULAN BARU untuk tahap sesudah P0. Tidak ada pengambilan berita otomatis atau jadwal event online pada rancangan default.
