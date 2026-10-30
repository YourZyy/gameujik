# Aturan Kerja AI Agent — Buku Resep 2045

**Berlaku:** seluruh proyek dan turunannya. **Versi:** 0.2, 27 Oktober 2026.  
**Keadaan awal:** dokumentasi persiapan selesai; sesi coding belum dimulai.

## 1. Mandat dan batas sesi

Pahami permintaan pengguna yang sedang aktif. Jika tugasnya dokumentasi, kerjakan dokumen. Jangan menganggap adanya rencana implementasi sebagai perintah untuk memasang Godot, menulis kode game, membuat repository, mengubah layanan eksternal atau merilis build. Jika pengguna kemudian meminta implementasi, lanjutkan dalam cakupan yang diotorisasi tanpa meminta konfirmasi ulang untuk langkah rutin yang diperlukan.

Tujuan agent adalah menghasilkan bagian yang benar-benar dapat diperiksa, mempertahankan keputusan game, dan meninggalkan konteks yang cukup untuk agent berikutnya. Jangan meminta pemilik proyek mengisi logika, menulis ulang bagian yang sengaja dikosongkan atau menggabungkan potongan keluaran secara manual.

## 2. Wajib dibaca sebelum task

1. [PROJECT_STATUS.md](docs/PROJECT_STATUS.md): kenyataan terbaru dan task aktif.
2. [PRD.md](PRD.md): keputusan disetujui, cakupan dan prioritas.
3. [TASKS.md](docs/TASKS.md): task, dependensi dan kriteria selesai.
4. Dokumen domain yang relevan: [PROTOTYPE.md](docs/PROTOTYPE.md), [CONTENT.md](docs/CONTENT.md), [UI_UX.md](docs/UI_UX.md), [LEVEL_DESIGN.md](docs/LEVEL_DESIGN.md), [ART_DIRECTION.md](docs/ART_DIRECTION.md), [EVENT_DESIGN.md](docs/EVENT_DESIGN.md) bila menyangkut event.
5. Laporan selesai terakhir yang relevan dalam [completed_tasks/](docs/completed_tasks/README.md).
6. [TEST_PLAN.md](docs/TEST_PLAN.md) sebelum menentukan verifikasi.

Jangan menganggap seluruh status lama benar tanpa memeriksa file kerja. Jika kode/dokumen berbeda dari laporan, catat perbedaannya dan perbaiki status. Jangan mengklaim sudah membaca file yang tidak tersedia. Konteks chat bukan pengganti dokumen yang mutakhir.

## 3. Prioritas keputusan

Instruksi terbaru pengguna mengungguli dokumen. PRD mengatur keputusan produk; CONTENT mengatur ID dan angka; UI_UX mengatur kontrol serta antarmuka; LEVEL_DESIGN mengatur ruang. Status bukan sumber spesifikasi fitur. Wireframe tidak menimpa aturan perilaku tertulis.

Label **DISETUJUI** tidak boleh diturunkan atau diganti diam-diam. **DEFAULT UJI** boleh diubah untuk memenuhi kriteria penerimaan bila ada alasan dan catatan dampak. **TERBUKA** bukan izin mengarang keputusan final; gunakan default yang sudah dinyatakan. Keputusan terbuka yang tidak memengaruhi task tidak perlu menghambat pekerjaan.

Jika perubahan pengguna mengubah cakupan, perbarui dokumen sumber dan rujukannya, bukan menambah catatan kontradiktif di akhir. Hindari menyalin tabel angka ke beberapa file. Dokumentasikan perubahan kontrak atau migrasi save bila diperlukan.

## 4. Keputusan yang harus dijaga

- Godot rilis stabil, GDScript, VS Code, Git/GitHub. Jangan pindah engine/bahasa tanpa keputusan pengguna.
- 3D first person untuk desktop. Jangan mengganti proyek menjadi web, 2D atau kamera orang ketiga.
- Dunia Indonesia 2045 fiktif; tujuan buku resep, pencarian bahan mandiri dan hubungan lokal.
- Visual stylized sederhana terinspirasi Firewatch dengan identitas Indonesia; tidak mengimpor aset game referensi.
- UI nyaman, sederhana dan bertahap. Tidak menambah panel statistik, hunger bar, minimap, currency atau crafting menu yang tidak termasuk P0.
- Satu petak dengan empat titik tanam. Tanam per titik; pemupukan dan penyiraman per petak.
- Satu map fiksi; format nama utama + judul event. Karhutla adalah event, bukan chapter atau nama game utama. Detail event baru dibangun setelah loop dasar dan cakupannya diotorisasi.
- Sains sederhana dapat muncul pada beberapa aspek; jangan membuat simulasi rumit atau klaim keselamatan pangan tanpa validasi.
- Satu resep P0: Sayur Bening Bayam dan Jagung. Temu kunci tetap bahan wajib.
- Tidak menambah pembelian bahan, barter wajib, combat, multiplayer, backend, login, telemetri atau AI runtime sebagai jalan pintas implementasi.

## 5. Siklus kerja setiap task

1. Pilih satu task konkret; sebut ID, tujuan, dependensi dan hasil yang dapat diperiksa.
2. Periksa kondisi sumber, checkpoint Git jika sudah ada, dan jangan menimpa kerja pengguna yang belum disimpan.
3. Ubah bagian yang diperlukan sampai perilaku yang diminta selesai. Hindari refactor besar, dependency tambahan dan perubahan visual menyeluruh di luar kebutuhan.
4. Jalankan pemeriksaan yang sesuai. Untuk perubahan gameplay, verifikasi perilaku di engine/build bila tersedia; tes unit tidak membuktikan kenyamanan visual.
5. Periksa diff, error dan regresi pada sistem yang terhubung. Perbarui panduan jika cara menjalankan atau format data berubah.
6. Tentukan status dengan jujur. “Sudah ditulis” berbeda dari “sudah dijalankan” dan “sudah lolos uji”.
7. Tulis arsip penyelesaian dan perbarui TASKS serta PROJECT_STATUS sesuai aturan wajib di bawah.
8. Beri ringkasan kepada pengguna: hasil, verifikasi yang benar-benar dilakukan, keterbatasan material dan langkah terdekat.

Kerjakan dependensi secara berurutan. Jangan menjalankan beberapa agent yang mengubah file sama tanpa pembagian kerja eksplisit. Jangan menjalankan reset, penghapusan massal, force push atau menimpa save pengguna untuk mempermudah pekerjaan.

## 6. Kewajiban pencatatan — setelah SETIAP task selesai

**AI agent WAJIB memperbarui `docs/PROJECT_STATUS.md` dan membuat satu laporan terperinci dalam `docs/completed_tasks/` setiap selesai melakukan sebuah task. Task belum dianggap ditutup sampai kedua catatan tersebut selesai.** Kewajiban berlaku untuk task dokumentasi, implementasi, perbaikan bug, pengujian dan distribusi.

Urutan penutupan:

1. Tentukan nomor arsip berikutnya dengan memeriksa semua laporan bernomor; gunakan nomor terbesar + 1, minimal tiga digit. Jangan memakai ulang nomor yang pernah digunakan.
2. Buat `NNN-nama-task-dengan-huruf-kecil.md`. Judul di dalamnya memakai bahasa manusia. Gunakan [TEMPLATE.md](docs/completed_tasks/TEMPLATE.md) dan isi seluruh bagian relevan.
3. Di `PROJECT_STATUS.md`, tambahkan satu bullet singkat pada **Pekerjaan yang Sudah Selesai**, dengan tautan ke laporan. Urutkan dari pekerjaan awal ke terbaru.
4. Ganti isi **Deskripsi Status Pekerjaan Terakhir** dengan kondisi terkini. Jangan menambahkan banyak sublaporan historis.
5. Di `TASKS.md`, tandai task terkait SELESAI dan tautkan laporan. Jangan menyelesaikan seluruh milestone jika baru satu task yang lulus.
6. Pastikan ID task, judul dan tautan konsisten pada tiga tempat tersebut. Catat pemeriksaan yang dijalankan; jangan menulis hasil “lulus” tanpa pelaksanaan.

Untuk task yang belum selesai/terhambat: tandai DIKERJAKAN atau TERHAMBAT di TASKS, ganti status terakhir dengan kemajuan nyata, file terdampak, alasan dan langkah berikutnya. Jangan memasukkannya ke daftar selesai atau menerbitkan laporan selesai palsu. Jika sesi terputus, status harus memungkinkan agent lain melanjutkan tanpa menebak.

Satu laporan untuk satu task yang koheren, bukan untuk setiap klik atau setiap file. Bug baru pada task lama dibuat sebagai task perbaikan baru dan laporan baru; jangan menghapus bukti lama. Koreksi faktual pada laporan boleh dilakukan dengan catatan koreksi bertanggal. TEMPLATE dan README arsip bukan task selesai.

## 7. Batas panjang status utama

Status utama berisi daftar judul bertautan dan satu deskripsi terbaru, bukan riwayat percakapan, dump log atau diff. Target deskripsi terakhir 150–300 kata. Cantumkan tanggal, task terakhir, keadaan fitur, verifikasi, kendala dan langkah berikutnya secara ringkas. Detail lengkap hanya di arsip.

Jangan memindahkan daftar selesai ke tempat lain atau menghapus bullet tanpa persetujuan pemilik proyek. Pertumbuhan daftar judul memang diharapkan; yang dicegah adalah penumpukan penjabaran tugas di halaman utama.

## 8. Aturan implementasi saat sesi coding tersedia

Gunakan komponen dan adegan yang dapat digunakan ulang; pisahkan logika inventaris, pertumbuhan, memasak dan save dari tampilan. Nama file konsisten `snake_case`; ID data stabil dan tidak diterjemahkan. Bahasa tampilan Indonesia.

Semua nilai item/resep/tanaman berasal dari definisi data yang mengikuti CONTENT. UI, tracker dan dapur membaca aturan ketersediaan yang sama. Jangan memberi angka hard-coded berbeda pada tiap panel.

Transaksi item harus utuh: kapasitas dan prasyarat diperiksa dulu, lalu sumber/tujuan berubah bersama. Klik berulang, muat ulang dan perbedaan frame rate tidak boleh menggandakan hasil. Reservasi memasak adalah milik job, bukan barang bebas yang dihitung lagi oleh tracker.

Satu pengendali konteks input membedakan dunia, buku, inventaris, dialog, dapur dan pause. Input penutup panel tidak boleh diteruskan menjadi aksi dunia. Simulasi pause mengikuti PROTOTYPE; jangan memakai waktu nyata komputer untuk menghukum tanaman ketika aplikasi ditutup.

Save mempunyai versi skema, validasi, cadangan dan jalur kegagalan yang jelas. Jangan mengubah skema lama tanpa kebijakan pemulihan/migrasi tertulis. Jangan menganggap serialisasi satu posisi pemain sudah memenuhi save/load.

Hindari plugin/add-on sebelum ada kebutuhan konkret. Pemilihan renderer dan penguncian versi dilakukan saat setup menggunakan perangkat yang tersedia; jangan mengisi nomor versi dari ingatan atau klaim “latest” tanpa verifikasi saat itu.

## 9. Pengujian dan bukti

Jalankan pengujian relevan dalam TEST_PLAN. Prioritaskan tes otomatis untuk kapasitas, transfer item, idempotensi hasil, reservasi memasak dan round trip save. Uji langsung diperlukan untuk gerak, kamera, prompt, keterbacaan, rasa memasak dan navigasi.

Jika engine, GUI atau perangkat uji tidak tersedia, jelaskan batasnya dan biarkan task yang membutuhkan bukti tersebut berstatus belum selesai. Boleh menutup task dokumentasi setelah pemeriksaan dokumen, tanpa menyatakan implementasi game selesai. Jangan membuat screenshot, benchmark atau commit hash fiktif.

Untuk bug, catat reproduksi, penyebab, perbaikan, uji regresi dan sistem yang mungkin terpengaruh. Tes gagal harus dilaporkan atau diperbaiki; jangan dihapus hanya agar laporan tampak lulus.

## 10. Git, aset dan penyerahan

Sebelum repository tersedia, jangan mengarang branch, commit atau PR. Setelah tersedia, gunakan checkpoint yang sesuai, jangan memasukkan secret, cache engine, save pribadi atau build besar tanpa alasan. Jangan push/publish sebagai bagian task lokal jika tidak termasuk instruksi pengguna.

Setiap aset eksternal harus memiliki asal, pembuat, lisensi, tanggal perolehan, perubahan dan kewajiban atribusi yang dapat diverifikasi. Aset referensi Firewatch bukan aset yang otomatis boleh dipakai. Placeholder harus ditandai pada laporan; visual akhir tidak boleh diklaim dari graybox.

Pada handoff, sebut task berikutnya dengan ID, prasyarat, serta bukti yang masih diperlukan. Semua file hasil harus berada dalam proyek dengan tautan relatif yang benar. Tugas agent adalah menyelesaikan pekerjaan dalam cakupan, bukan mengembalikan daftar bagian yang harus dilengkapi sendiri oleh pengguna.

## 11. Protokol Pause (Jeda) dan Auto-Resume Prompt (Berlaku untuk Semua Model AI)

Setiap kali pengguna meminta **pause / jeda / tunda** pengerjaan (baik saat eksekusi tunggal maupun `/teamwork`), AI agent (tanpa memandang model AI yang sedang digunakan) **WAJIB** melakukan langkah berikut secara otomatis tanpa menunggu diminta lagi:

1. **Hentikan Eksekusi di Titik Aman (Clean Boundary):** Pastikan tidak ada file yang setengah tertulis atau rusak. Matikan seluruh subagent dan jadwal background timer/cron yang sedang berjalan agar sesi benar-benar diam (*quiescent*).
2. **Perbarui Status Proyek Sesuai Bagian 6:**
   - Pastikan task yang sudah lulus verifikasi penuh tercatat `SELESAI` beserta laporan bernomornya di `docs/completed_tasks/`.
   - Tandai task yang sedang berjalan saat dijeda sebagai `DIKERJAKAN` di `docs/TASKS.md` dan perbarui **Deskripsi Status Pekerjaan Terakhir** di `docs/PROJECT_STATUS.md` dengan kemajuan nyata, file yang sudah dibuat/terdampak, dan titik lanjut berikutnya.
3. **Kirimkan Blok Prompt Siap Pakai (Copy-Paste) untuk Melanjutkan:** Di bagian akhir balasan konfirmasi *pause*, AI **WAJIB langsung menyertakan blok kode prompt `/teamwork [skip-interview]`** yang mutakhir untuk melanjutkan dari titik terakhir (mencantumkan daftar task yang sudah `SELESAI`, status task yang sedang `DIKERJAKAN` beserta file yang sudah siap, serta daftar sisa task hingga target akhir) agar pengguna tinggal menyalin dan menempelkannya pada sesi berikutnya.
