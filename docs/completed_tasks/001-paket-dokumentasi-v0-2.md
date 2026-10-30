# 001 — Penyusunan Paket Dokumentasi v0.2

## Identitas

- **ID task:** DOC-001.
- **Tanggal:** 27 Oktober 2026.
- **Pelaksana:** AI assistant pada sesi penyusunan dokumen.
- **Tahap:** persiapan pengembangan, belum sesi coding game.
- **Status:** Selesai sebagai paket dokumentasi.
- **Versi sumber/build:** dokumen v0.2; tidak ada repository, commit game atau build yang dibuat pada task ini.

## Tujuan dan pemicu

Pengguna meminta seluruh dokumen Markdown yang siap dimasukkan ke root folder game di VS Code, lengkap, mendalam dan tanpa bagian implementasi yang sengaja diserahkan untuk dilengkapi sendiri. Pengguna juga meminta pemeriksaan akhir agar semua file saling terhubung dan tidak menimbulkan miskonsepsi.

Dasar kerja adalah PRD dan wireframe v0.1 serta diskusi terbaru: Godot/GDScript, VS Code, GitHub, visual stylized referensi Firewatch, prototipe Sayur Bening Bayam dan Jagung, UI sederhana dan status proyek ringkas dengan arsip per task. Saat pengerjaan, pengguna menambahkan ide satu map fiksi dengan event tematik, lalu memperjelas format nama game utama + judul event “Karhutla”, bukan chapter.

## Ruang lingkup

Menyusun paket aktif v0.2, memperbarui keputusan lama, memisahkan detail domain, memberi nilai awal pengujian, merancang wireframe baru, menulis aturan agent dan mengemas ZIP. Tidak menulis kode game, menginstal engine, membuat scene Godot/repository, mengimplementasikan event atau mengklaim tes gameplay lulus.

Arah event dimasukkan, sedangkan rincian mekanik baru dan angka ditandai USULAN BARU. Prototipe dasar tetap satu resep; event masuk jalur produksi sesudah loop dasar agar paket tidak mengubah cakupan implementasi secara diam-diam.

## Perubahan dan hasil akhir

PRD kini menjadi sumber keputusan produk, CONTENT menjadi sumber ID dan angka, PROTOTYPE menjelaskan transaksi serta waktu, UI_UX mengatur kontrol/layout, LEVEL_DESIGN mengatur ruang dan ART_DIRECTION mengarahkan produksi. TASKS dan TEST_PLAN menghubungkan implementasi dengan kriteria uji. EVENT_DESIGN memperjelas event sebagai perubahan keadaan map, akses bahan, sains sederhana dan save.

AGENTS mewajibkan setiap AI menulis satu laporan task selesai, menautkannya pada daftar selesai, mengganti deskripsi status terbaru dan menandai task yang sama di TASKS. Task terhambat tidak dimasukkan sebagai selesai. README arsip dan TEMPLATE menghindari laporan yang tidak lengkap atau status utama yang dipenuhi log.

Wireframe v0.2 menampilkan HUD, buku, kebun, tas/peti, dapur serta pause/pengaturan. Detail gambar memakai keadaan contoh, bukan definisi angka terpisah. SVG dan PNG disertakan; keduanya bukan screenshot game.

## File yang ditambahkan

| Path | Hasil |
| --- | --- |
| [README.md](../../README.md) | Pintu masuk, cara memasukkan paket ke VS Code dan peta dokumen |
| [PRD.md](../../PRD.md) | Visi, keputusan, cakupan, FR dan roadmap |
| [AGENTS.md](../../AGENTS.md) | Siklus kerja AI, batas sesi, pengujian dan arsip wajib |
| [docs/PROTOTYPE.md](../PROTOTYPE.md) | Alur satu resep, waktu, transaksi, save dan pemulihan |
| [docs/ART_DIRECTION.md](../ART_DIRECTION.md) | Bentuk, warna, material, audio, aset dan arahan event |
| [docs/UI_UX.md](../UI_UX.md) | Kontrol, fokus, delapan konteks layar dan aksesibilitas |
| [docs/LEVEL_DESIGN.md](../LEVEL_DESIGN.md) | Lokasi, koordinat graybox, rute, spawn dan area event |
| [docs/CONTENT.md](../CONTENT.md) | Item, resep, parameter, sumber, dialog dan angka event usulan |
| [docs/EVENT_DESIGN.md](../EVENT_DESIGN.md) | Format identitas event, Karhutla, sains, state dan persistensi |
| [docs/TASKS.md](../TASKS.md) | 25 task dengan dependensi, status dan kriteria |
| [docs/TEST_PLAN.md](../TEST_PLAN.md) | 60 kasus P0, 12 kasus event, matriks FR dan audit dokumen |
| [docs/PROJECT_STATUS.md](../PROJECT_STATUS.md) | Satu pekerjaan selesai dan deskripsi keadaan terbaru |
| [docs/CONSISTENCY_CHECK.md](../CONSISTENCY_CHECK.md) | Hasil pembacaan silang, pemeriksaan dan koreksi |
| [docs/completed_tasks/README.md](README.md) | Panduan nomor, penulisan, koreksi dan batas arsip |
| [docs/completed_tasks/TEMPLATE.md](TEMPLATE.md) | Struktur laporan berikutnya beserta petunjuk lengkap |
| Laporan ini | Bukti dan handoff DOC-001 |
| [docs/wireframes/wireframes-v0.2.svg](../wireframes/wireframes-v0.2.svg) | Gambar rancangan vektor enam layar |
| [docs/wireframes/wireframes-v0.2.png](../wireframes/wireframes-v0.2.png) | Pratinjau hasil render SVG |

PRD/wireframe lama tidak ditimpa dan tidak ikut sebagai sumber aktif dalam ZIP baru. Hal ini mempertahankan sumber lama sekaligus menghindari dua acuan yang bertentangan.

## Verifikasi yang dilakukan

| Pemeriksaan | Tindakan dan hasil nyata | Status |
| --- | --- | --- |
| DOC-T01 kelengkapan | Cocokkan struktur paket dengan README dan daftar deliverable; 16 MD + SVG + PNG tersedia | Lulus |
| DOC-T02 tautan | Resolusi tautan relatif terhadap direktori setiap dokumen; seluruh target final ada dalam paket | Lulus |
| DOC-T03 keputusan | Baca silang engine, kamera, gaya, resep, format event dan no-code pada dokumen terkait | Lulus sebagai audit dokumen |
| DOC-T04 kontrak | Periksa jumlah/sumber bahan, unit petak/titik, waktu, reservasi, save dan progres event; koreksi konflik yang ditemukan | Lulus sebagai audit rancangan |
| DOC-T05 keterlacakan | Periksa FR01–FR24, ID T01–T60/EV-T01–EV-T12, task terdefinisi dan grafik dependensi tanpa siklus | Lulus |
| DOC-T06 status/arsip | Hanya DOC-001 selesai; laporan dan tautan tersedia, dua bagian status utama tetap ringkas | Lulus |
| DOC-T07 format | Baca UTF-8, periksa file kosong, pagar kode, penanda pemotongan dan path internal yang tidak boleh bocor | Lulus |
| DOC-T08 visual/paket | Parse SVG, render Inkscape, lihat PNG, perbaiki overflow HUD, periksa integritas dan byte hasil ekstraksi ZIP | Lulus |

Pemeriksaan awal menemukan tautan menuju dua laporan akhir yang belum ditulis pada saat audit pertama. Keduanya diselesaikan, lalu seluruh pemeriksaan diulang pada paket final. Pemeriksaan semantik juga memperjelas konflik Tab, aturan waktu dapur, checkpoint pra-event dan pemisahan progres event. Rincian hasil pada CONSISTENCY_CHECK.

Tidak ada tes gameplay, uji engine, benchmark, uji save runtime, tes event atau installer yang dijalankan. Verifikasi aritmetika hanya mengecek kecukupan bahan/air di rancangan, bukan perilaku aplikasi.

## Kriteria selesai dan bukti

Seluruh dokumen yang dijanjikan tersedia dalam susunan root + docs yang dapat dibuka melalui VS Code. Keputusan terbaru pengguna sudah terwakili. Tidak ada bagian final yang meminta pengguna menulis kelengkapan sendiri. Keputusan yang sengaja ditunda mempunyai default dan waktu penetapan.

Hubungan dokumen sudah diperiksa, wireframe tersedia dan ZIP dapat diekstrak dengan isi cocok sumber. Status mencerminkan dokumentasi selesai, tidak mengklaim produk game selesai. Dengan batas tersebut, DOC-001 memenuhi cakupan.

## Dampak dan keterbatasan

Paket memberikan spesifikasi siap dipakai untuk task setup/implementasi berikutnya. Tidak ada perubahan pada sistem pengguna, save, layanan hosting atau repository. Angka prototipe masih DEFAULT UJI; mekanik event baru belum diuji dan belum seluruhnya diputuskan sebagai desain final. Kebutuhan hardware, renderer dan versi engine persis tetap ditetapkan saat setup.

Sumber sains mendukung konsep umum yang terbatas, bukan metode menangani bencana atau bukti angka simulasi. Performa dan kenyamanan tetap membutuhkan implementasi serta playtest nyata.

## Handoff dan penutupan

Task berikutnya **SETUP-001**, hanya setelah pengguna meminta sesi coding. Baca AGENTS, PROJECT_STATUS, PRD dan TASKS; jangan memilih ulang engine. Kunci versi/renderer aktual, buat proyek minimal dan ubah README dengan langkah yang benar-benar diuji.

DOC-001 ditautkan dari PROJECT_STATUS dan TASKS. Deskripsi status terakhir sudah diganti dengan keadaan penyerahan. Tidak ada task gameplay lain yang ditandai selesai. Agent berikutnya mengambil nomor arsip 002 untuk task selesai berikutnya, setelah memeriksa apakah ada laporan baru dari pekerjaan lain.
