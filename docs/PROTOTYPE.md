# Prototipe Pertama — Satu Resep sampai Tersaji

**Versi:** 0.2 · **Tanggal:** 27 Oktober 2026  
**Keputusan produk:** [PRD](../PRD.md). **Angka dan ID:** [CONTENT](CONTENT.md). **Uji:** [TEST_PLAN](TEST_PLAN.md).

## 1. Pertanyaan yang ingin dijawab

Apakah membuka buku, menanam sebagian bahan, mencari sisanya, kembali memasak dan menikmati hasil terasa jelas serta menyenangkan? Apakah pemain memahami apa yang harus dilakukan tanpa banyak menu atau arahan lisan?

P0 membuktikan loop tersebut dahulu. Durasi sasaran awal 10–15 menit adalah target pengamatan, bukan janji. Jangan menambahkan kebakaran sebelum jalur ini dapat diselesaikan dan disimpan. Gagasan event kebakaran didokumentasikan terpisah di [EVENT_DESIGN](EVENT_DESIGN.md) sebagai USULAN BARU tahap sesudah loop dasar.

## 2. Hasil akhir yang harus tersedia

Satu map kecil tersambung, satu rumah, dapur, peti, satu petak empat titik, sumber air, jagung, temu kunci, satu tetangga, satu resep tersedia, kontrol first person, buku/quest, inventaris, dua tahap memasak, save/load, pause, pengaturan kenyamanan dan audio dasar.

Hasil akhir P0 gameplay adalah hidangan dihasilkan, buku ditandai selesai, lalu hidangan dimakan atau dibagikan. Pemain bisa menyimpan, keluar, memuat dan mendapati keadaan konsisten. Build mandiri dan installer merupakan gerbang distribusi P0 berikutnya, bukan klaim otomatis ketika alur sudah bekerja di editor.

Tidak ada pembelian bahan, mata uang, hunger bar, crafting bercabang, combat, sistem cuaca, malam wajib, NPC berjalan terjadwal atau kebakaran aktif pada P0. Tidak ada resep tambahan kosong pada UI.

## 3. Perjalanan utama

| Tahap | Tindakan | Informasi yang muncul | Bukti berhasil |
| --- | --- | --- | --- |
| Masuk rumah | Melihat meja buku dan pintu pekarangan | Satu petunjuk membuka buku | Pemain dapat bergerak dan tahu tujuan dekat |
| Pilih resep | Buka B/E pada buku, tekan Lacak | Nama, tiga bahan dan sumber | Tracker tampil; kamera kembali ke dunia |
| Ambil persediaan | Periksa wadah dekat alat | Nama/jumlah paket awal | Barang masuk tepat sekali |
| Periksa petak | E pada tanah | “Belum diolah” dan aksi yang dibutuhkan | Tidak muncul seluruh tutorial sekaligus |
| Perbaiki | Pilih alat tanah, gemburkan, tambah pembenah | Perubahan bentuk/warna dan kesiapan | Benih sekarang dapat ditanam |
| Tanam | Pilih benih, klik titik kosong | Jumlah benih dan status titik | Setiap titik mengonsumsi satu benih |
| Rawat | Pupuk area, isi penyiram, siram petak | Satu batas area dan satu biaya | Semua titik membaca kondisi petak yang sama |
| Jelajah | Pergi ke kebun dan rumpun bambu | Landmark, prompt bahan, catatan opsional | Jagung/temu kunci bertambah tanpa dialog wajib |
| Kembali | Periksa bayam | Tumbuh/tertahan/siap panen | Pemain memahami alasan bila tertahan |
| Panen | E pada tanaman siap | Nama dan seluruh hasil | Bayam dan benih masuk; titik kosong |
| Dapur | Periksa, siapkan dan atur panas | Satu tahap aktif, petunjuk panas | Output dibuat tepat sekali |
| Gunakan hasil | Ambil dan makan atau bagikan | Centang buku dan respons | Flag penutup pengalaman ditetapkan |
| Lanjutkan | Save, tutup, load | Checkpoint valid dan keadaan yang benar | Tidak ada duplikasi atau kehilangan |

Ini rute pengenalan, bukan urutan quest yang mengunci dunia. Eksplorasi sebelum membuka buku dan merawat sebelum melacak harus tetap valid.

## 4. Model keadaan lintas sistem

| Sistem | Keadaan konseptual | Aturan transisi |
| --- | --- | --- |
| Buku | Tersedia / selesai, dilacak terpisah | Selesai hanya oleh job memasak yang commit output |
| Petak | Belum diolah → gembur → siap tanam | Pembenah hanya setelah gembur; pupuk/air bukan pengganti persiapan |
| Titik tanam | Kosong → ditanam → tumbuh → siap → kosong | Panen harus muat seluruh hasil sebelum titik dikosongkan |
| Sumber liar | Tersedia → dipanen → menunggu hari → tersedia | ID tetap dan hari panen tersimpan |
| Dapur | Idle → reserved/preparing → ready_to_heat → cooking ↔ paused → output_ready → idle | Satu job; output belum diambil memblokir job berikutnya |
| Resep pengalaman | Belum selesai → cooked → used/shared | cooked adalah progres buku; used/shared adalah penutup P0 |

Kemajuan pertumbuhan memakai detik simulasi efektif. Tidak ada penghitung terpisah berbasis jumlah frame. Memuat save tidak memicu ulang transisi sekali jalan seperti hadiah panen atau keluaran masak.

## 5. Kontrak waktu dan input

| Konteks aktif | Pemain bergerak | Pertumbuhan/penguapan/hari | Job memasak | Mouse |
| --- | --- | --- | --- | --- |
| Dunia | Ya | Berjalan | Tidak berjalan bila panel dapur tertutup | Terkunci untuk pandang |
| Buku, tas, peti, dialog, inspeksi penuh | Tidak | Berhenti | Berhenti | Bebas untuk UI |
| Dapur aktif | Tidak | Berjalan | Berjalan pada tahap cooking; persiapan dari tahan tombol | Bebas untuk UI |
| Pause/pengaturan/menu utama | Tidak | Berhenti | Berhenti | Bebas untuk UI |
| Load/save blocking atau transisi istirahat | Tidak | Berhenti | Berhenti | Dikendalikan UI |
| Aplikasi ditutup/tidak fokus | Tidak | Berhenti | Berhenti | Tidak menangkap input |

Prompt inspeksi ringkas di dunia bukan modal, sehingga tidak menjeda. Saat E membuka panel inspeksi detail, konteks berpindah ke menu. Fokus aplikasi hilang memicu pause agar tanaman atau job tidak bergerak tanpa kendali pemain. Penulisan save biasa mengambil snapshot setelah transaksi dan tidak menambah waktu simulasi.

Semua sistem membaca pengendali waktu yang sama. Dapur adalah pengecualian eksplisit terhadap menu umum karena pemain memang sedang menjalankan aktivitas memasak; jangan membuat buku tetap menumbuhkan tanaman sementara tas menjedakannya. Saat Esc menutup dapur, job disimpan dalam state paused dan tracker menjelaskan cara melanjutkan.

Tombol penutup menu dan tombol aksi harus dilepas sebelum dapat memicu dunia. Memegang klik ketika berpindah alat/menu tidak langsung memakai sumber daya.

## 6. Transaksi item dan memasak

### 6.1 Pickup, tanam dan panen

Periksa target, keadaan, jangkauan, sumber daya dan seluruh kapasitas. Jika satu prasyarat gagal, tidak ada mutasi. Jika lolos, mutasi dilakukan sebagai satu transaksi; baru setelahnya UI dan audio diperbarui. Sumber dengan ID yang sama tidak bisa dipanen dua kali oleh dua input pada frame berdekatan.

Penanaman hanya mengonsumsi benih saat titik berhasil diisi. Menggemburkan tidak memakai pembenah; aksi tambah pembenah adalah transaksi terpisah yang jelas. Pupuk/air selesai satu kali per tahan tombol dan bekerja per petak.

### 6.2 Reservasi dan pembatalan

Menekan Siapkan memeriksa resep, bahan bebas tas/peti, stasiun idle dan slot hasil kosong. Setelah lengkap, buat ID job dan pindahkan bahan ke reservasi beserta sumber asalnya. Tombol berulang mengarah ke job yang sama, bukan job kedua.

Pada tahap persiapan, Batal mengembalikan bahan ke kontainer asal jika muat, lalu tas/peti lain bila perlu. Sisa yang tidak muat masuk kontainer pengembalian aman milik dapur yang persisten. Pesan menyebut tempat mengambilnya. Job ditutup hanya setelah seluruh reservasi berpindah tepat sekali. Kontainer pengembalian dapat dibuka dari panel dapur; tidak menghilang karena panel ditutup.

Setelah Mulai memasak, pembatalan tidak tersedia. Menutup panel atau pause menjeda dan pemain bisa melanjutkan. Panas salah tidak merusak bahan. Tidak ada job yang terus memasak diam-diam di latar P0.

### 6.3 Output dan progres

Ketika kemajuan selesai, commit satu output ke slot hasil, konsumsi reservasi dan perbarui jumlah dibuat + flag selesai secara atomik. `output_committed` dan ID job mencegah commit kedua setelah load. Jika tas penuh, output tetap di slot hasil; jangan membatalkan status selesai. Menekan Ambil berulang memindahkan hasil sekali.

Dapur tidak menjalankan resep berikutnya bila hasil belum diambil. Pengembalian aman dan slot hasil adalah kontainer berbeda agar pembatalan tidak memakan tempat hidangan. Semua kontainer tersebut termasuk dalam save.

## 7. Save/load dan recovery

Satu profil P0 menyediakan **checkpoint manual** dan **checkpoint autosave** terpisah, dengan cadangan valid masing-masing. Menu Lanjutkan memilih checkpoint valid dengan revisi terbaru, tidak hanya waktu sistem. Menu Muat menampilkan jenis checkpoint dan ringkasan agar pemain dapat memilih manual yang lebih lama secara sadar.

Snapshot meliputi posisi aman, arah pandang, kontainer, alat/air, petak/tanaman, sumber, hari/waktu, resep dilacak/selesai, catatan/dialog, meal_used, job/reservasi/progres/output/pengembalian. Pengaturan disimpan terpisah agar load progres tidak mengembalikan sensitivitas atau volume lama.

Tulisan aman: ambil snapshot setelah transaksi lengkap → serialisasi ke file sementara → validasi → pertahankan cadangan valid sebelumnya → ganti checkpoint utama secara aman sesuai kemampuan platform. Kegagalan di langkah mana pun mempertahankan checkpoint valid sebelumnya dan menampilkan gagal. Save tidak boleh mengklaim sukses hanya karena fungsi dipanggil.

Autosave setelah paket awal diambil, panen berhasil, output masak commit, makan/berbagi, istirahat dan perubahan kebun penting; gabungkan permintaan berdekatan setelah transaksi stabil agar tidak menulis berulang setiap frame. Manual save tersedia ketika tidak sedang transisi/load/commit. Saat memasak, Save dari pause menyimpan job sebagai paused, bukan menolak tanpa alasan.

Load: validasi envelope dan seluruh referensi dahulu → bangun keadaan sementara → baru ganti dunia. Jika tidak cocok/rusak, tampilkan checkpoint valid lain. Jangan memuat setengah data lalu mengisi sisanya dengan game baru tanpa penjelasan. Posisi yang tidak aman dipulihkan ke titik spawn aman LEVEL_DESIGN, tanpa mengubah item/progres.

Tidak ada pertumbuhan/penguapan/penyebaran bahaya ketika game ditutup. Waktu dunia tidak memakai selisih jam sistem setelah load. Game Baru yang menimpa profil memerlukan konfirmasi dan hanya menghapus progres yang disetujui; pengaturan tetap dipertahankan.

## 8. Pemulihan tanpa jalan buntu

Benih cadangan hanya aktif setelah persediaan awal diambil dan syarat CONTENT terpenuhi. Panen mengembalikan benih, sehingga menanam ulang tidak mengandalkan keberuntungan. Jagung dan temu kunci pulih lewat hari/istirahat, bukan drop acak. Tanaman yang kurang perawatan berhenti tumbuh dan dapat diteruskan.

Dialog tidak menjadi izin wajib mengambil bahan. Bahan tidak rusak atau kedaluwarsa P0. Tas penuh tidak menghabiskan sumber. Uji pemulihan juga mencakup pengembalian reservasi ketika tas dan peti penuh.

Pemain yang tersangkut dapat memakai **Kembali ke posisi aman** dari pause; tidak mereset kebun atau menggandakan barang. Aksi tidak tersedia ketika load/commit berjalan. Tidak perlu sistem checkpoint kematian karena tidak ada kematian P0.

## 9. Panduan rasa permainan

Awal cukup satu tujuan. Perkenalkan tanah lewat petak, bukan layar tutorial panjang. Pertumbuhan memberi waktu mengunjungi dua lokasi dan berbicara. Jika pemain harus menunggu diam, pendekkan waktu atau perbaiki rute berdasarkan observasi.

Memasak harus terasa sebagai tindakan, namun tidak menuntut refleks cepat. Panas sedang jelas dan kesalahan dapat diperbaiki. Penutup memperlihatkan masakan dan centang buku tanpa layar skor penuh. Pemain masih dapat kembali ke kebun atau mengulang resep setelah penutup.

## 10. Gerbang penerimaan

P0 gameplay diterima setelah seluruh FR P0 selain distribusi terpenuhi, tes transaksi/save kritis lulus, rute baru dan lanjutan selesai, dan playtest pemain baru tidak memerlukan bantuan berulang untuk tindakan dasar. Laporkan observasi nyata, termasuk durasi, titik bingung dan bantuan yang diberikan.

P0 distribusi memerlukan task ekspor/installer dan pengujian mandiri tambahan. Tidak ada status “selesai” berdasarkan dokumen atau kode yang belum dijalankan. Rincian tugas ada di [TASKS](TASKS.md); daftar bukti ada di [TEST_PLAN](TEST_PLAN.md).
