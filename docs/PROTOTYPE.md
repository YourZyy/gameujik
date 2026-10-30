# Prototipe Pertama — Satu Resep sampai Tersaji

**Versi:** 0.3 · **Tanggal:** 30 Oktober 2026  
**Keputusan produk:** [PRD](../PRD.md). **Angka dan ID:** [CONTENT](CONTENT.md). **Uji:** [TEST_PLAN](TEST_PLAN.md).

> **Kontrak P0, ditambah P0.5.** Bagian 1–9 adalah kontrak perilaku P0 (satu resep) yang tetap berlaku sebagai regresi. Tambahan P0.5 "Kampung Hidup" (PRD D26–D32) berada di bagian 2 (hasil akhir), 5 (waktu NPC dan streaming), 7 (save v2), 10.2 (gerbang) dan 11 (tujuan tiga resep warisan).

## 1. Pertanyaan yang ingin dijawab

Apakah membuka buku, menanam sebagian bahan, mencari sisanya, kembali memasak dan menikmati hasil terasa jelas serta menyenangkan? Apakah pemain memahami apa yang harus dilakukan tanpa banyak menu atau arahan lisan?

P0 membuktikan loop tersebut dahulu. Durasi sasaran awal 10–15 menit adalah target pengamatan, bukan janji. P0.5 menanyakan hal lanjutannya: apakah tujuan tiga resep warisan di dunia yang lebih luas dengan warga bergerak tetap jelas, tidak melelahkan dan dapat diselesaikan tanpa minimap (target tempo sesi di CONTENT bagian 15). Jangan menambahkan kebakaran sebelum jalur ini dapat diselesaikan dan disimpan. Gagasan event kebakaran didokumentasikan terpisah di [EVENT_DESIGN](EVENT_DESIGN.md) sebagai USULAN BARU tahap sesudah loop dasar.

## 2. Hasil akhir yang harus tersedia

Hasil akhir P0 (sudah dikerjakan sebagai regresi): satu map kecil tersambung, satu rumah, dapur, peti, satu petak empat titik, sumber air, jagung, temu kunci, satu tetangga, satu resep tersedia, kontrol first person, buku/quest, inventaris, dua tahap memasak, save/load, pause, pengaturan kenyamanan dan audio dasar.

Tambahan P0.5: area P0 menjadi zona inti dunia sekitar 1 km² yang dimuat per chunk di sekitar pemain; delapan warga bergerak berjadwal; tiga resep warisan dengan penyerahan hidangan kepada penerima, buku tiga halaman dan layar penutup; save v2. Angka dan ID ada di CONTENT bagian 15–20; satu petak empat titik dan dua tahap memasak tidak berubah (D32).

Hasil akhir P0 gameplay adalah hidangan dihasilkan, buku ditandai selesai, lalu hidangan dimakan atau dibagikan. Pemain bisa menyimpan, keluar, memuat dan mendapati keadaan konsisten. Build mandiri dan installer merupakan gerbang distribusi P0 berikutnya, bukan klaim otomatis ketika alur sudah bekerja di editor.

Tidak ada pembelian bahan, mata uang, hunger bar, crafting bercabang, combat, sistem cuaca, malam wajib atau kebakaran aktif pada P0 maupun P0.5; NPC berjalan terjadwal tidak ada pada P0 dan ditambahkan pada P0.5 (D29). Tidak ada resep tambahan kosong pada UI.

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

### 5.1 Tambahan P0.5: warga bergerak dan streaming chunk

Warga tidak memiliki timer sendiri: posisinya fungsi murni dari hari dan jam dalam game (CONTENT bagian 17.2), yang diturunkan dari waktu aktif yang sudah dipakai sistem lain. Karena itu warga berhenti otomatis pada setiap konteks yang menghentikan simulasi. Streaming chunk mengikuti posisi pemain, sehingga konteks yang menghentikan gerak pemain tidak menghasilkan muat atau bongkar baru.

| Konteks aktif | Warga bergerak | Streaming chunk |
| --- | --- | --- |
| Dunia | Ya | Berjalan mengikuti posisi pemain |
| Buku, tas, peti, dialog, inspeksi penuh | Tidak; lawan bicara menghadap pemain dan tidak dapat pergi di tengah kalimat | Tidak ada perubahan; pemain diam |
| Dapur aktif | Ya (mengikuti waktu simulasi) | Tidak ada perubahan; pemain diam |
| Pause/pengaturan/menu utama | Tidak | Berhenti; tidak ada muat atau bongkar baru |
| Load, teleport, pemulihan, transisi istirahat | Tidak | Penghalang muat: kendali pemain tertahan sampai chunk di sekitar pemain memiliki collider; istirahat melompat ke hari berikutnya dengan layar gelap sehingga tidak ada pop-in warga |
| Aplikasi ditutup/tidak fokus | Tidak | Berhenti |

Kolisi warga tidak menghalangi pemain (hanya area interaksi) agar tidak ada jalan buntu. Chunk yang berisi objek interaktif yang sedang difokuskan atau dipakai panel tidak dibongkar. Simulasi data (tanaman, node liar, job dapur) tidak bergantung pada chunk dimuat atau tidak; tanaman tetap tumbuh saat pemain menjelajah dan chunk hanya menyajikan visual.

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

Satu profil menyediakan **checkpoint manual** dan **checkpoint autosave** terpisah, dengan cadangan valid masing-masing. Menu Lanjutkan memilih checkpoint valid dengan revisi terbaru, tidak hanya waktu sistem. Menu Muat menampilkan jenis checkpoint dan ringkasan agar pemain dapat memilih manual yang lebih lama secara sadar.

Snapshot meliputi posisi aman, arah pandang, kontainer, alat/air, petak/tanaman, sumber, hari/waktu, resep dilacak/selesai, catatan/dialog, meal_used, job/reservasi/progres/output/pengembalian. Pengaturan disimpan terpisah agar load progres tidak mengembalikan sensitivitas atau volume lama.

Tulisan aman: ambil snapshot setelah transaksi lengkap → serialisasi ke file sementara → validasi → pertahankan cadangan valid sebelumnya → ganti checkpoint utama secara aman sesuai kemampuan platform. Kegagalan di langkah mana pun mempertahankan checkpoint valid sebelumnya dan menampilkan gagal. Save tidak boleh mengklaim sukses hanya karena fungsi dipanggil.

Autosave setelah paket awal diambil, panen berhasil, output masak commit, makan/berbagi, istirahat dan perubahan kebun penting; gabungkan permintaan berdekatan setelah transaksi stabil agar tidak menulis berulang setiap frame. Manual save tersedia ketika tidak sedang transisi/load/commit. Saat memasak, Save dari pause menyimpan job sebagai paused, bukan menolak tanpa alasan.

Load: validasi envelope dan seluruh referensi dahulu → bangun keadaan sementara → baru ganti dunia. Jika tidak cocok/rusak, tampilkan checkpoint valid lain. Jangan memuat setengah data lalu mengisi sisanya dengan game baru tanpa penjelasan. Posisi yang tidak aman dipulihkan ke titik spawn aman LEVEL_DESIGN, tanpa mengubah item/progres.

Tidak ada pertumbuhan/penguapan/penyebaran bahaya ketika game ditutup. Waktu dunia tidak memakai selisih jam sistem setelah load. Game Baru yang menimpa profil memerlukan konfirmasi dan hanya menghapus progres yang disetujui; pengaturan tetap dipertahankan.

### 7.1 Skema save v2 dan migrasi dari v1 (P0.5, D31)

Skema v2 menambah seksi wajib `worldgen` (versi generator, seed, `extent`, daftar objek dihapus per chunk yang jarang, ruang cadangan untuk warga) dan state P0.5: per resep `discovered`, `delivered_to`, `stamped`; buku `pages_revealed`, `book_completed_shown`; per warga `met`, `relation_level`, `dialogue_flags`, `dishes_received`. Posisi warga tidak disimpan karena dihitung dari hari dan waktu aktif. Tinggi, mesh, pohon, sungai dan collider tidak disimpan. Bidang dialog lama dimigrasikan ke warga `npc_neighbor_01`. Angka `extent` dan seed ada di CONTENT bagian 19. Kebijakan:

| Kebijakan | Isi |
| --- | --- |
| Baca | Envelope versi 1 dan 2 diterima; checksum divalidasi terhadap payload aslinya sebelum migrasi |
| Migrasi | Fungsi murni menambah default v2; seksi lain tidak disentuh; tidak mengubah berkas asli |
| Validasi | Payload hasil migrasi lulus validasi v2 sebelum state dipasang; gagal berarti tidak ada keadaan terpasang. `delivered_to` harus ID warga yang ada dan cocok dengan `delivery_npc_id` resep; ID tidak dikenal ditolak dengan cadangan, bukan dibuang diam-diam |
| Tulis | Penyimpanan pertama setelah migrasi menyalin berkas v1 menjadi `<slot>.v1.bak` satu kali dan tidak pernah menimpanya, lalu jalur atomik biasa |
| Pemulihan | Primer gagal: coba cadangan dengan migrasi yang sama; gagal: pesan “Data simpan tidak cocok…” dan checkpoint lain ditawarkan; berkas v1 tidak dihapus |
| Lebih baru | Versi skema yang lebih tinggi dari yang dikenal game ditolak dengan pesan dibuat versi game lebih baru; tidak ditimpa |
| Posisi | Posisi di luar `extent` atau di bawah tanah dipulihkan ke tanah di titik itu atau ke posisi aman rumah; satu sumber batas dunia |
| Konservasi | Tidak ada hidangan hilang: jumlah hidangan di tas/peti ditambah `times_cooked` tetap konsisten |

Kebijakan ini dikunci pada SAVE-002; state per warga ditambahkan pada SAVE-003. Sampai SAVE-002 selesai, skema v1 yang dijelaskan di awal bagian 7 adalah satu-satunya yang berlaku.

## 8. Pemulihan tanpa jalan buntu

Benih cadangan hanya aktif setelah persediaan awal diambil dan syarat CONTENT terpenuhi. Panen mengembalikan benih, sehingga menanam ulang tidak mengandalkan keberuntungan. Jagung dan temu kunci pulih lewat hari/istirahat, bukan drop acak. Tanaman yang kurang perawatan berhenti tumbuh dan dapat diteruskan.

Dialog tidak menjadi izin wajib mengambil bahan. Bahan tidak rusak atau kedaluwarsa P0. Tas penuh tidak menghabiskan sumber. Uji pemulihan juga mencakup pengembalian reservasi ketika tas dan peti penuh.

Pemain yang tersangkut dapat memakai **Kembali ke posisi aman** dari pause; tidak mereset kebun atau menggandakan barang. Aksi tidak tersedia ketika load/commit berjalan. Tidak perlu sistem checkpoint kematian karena tidak ada kematian P0.

## 9. Panduan rasa permainan

Awal cukup satu tujuan. Perkenalkan tanah lewat petak, bukan layar tutorial panjang. Pertumbuhan memberi waktu mengunjungi dua lokasi dan berbicara. Jika pemain harus menunggu diam, pendekkan waktu atau perbaiki rute berdasarkan observasi.

Memasak harus terasa sebagai tindakan, namun tidak menuntut refleks cepat. Panas sedang jelas dan kesalahan dapat diperbaiki. Penutup memperlihatkan masakan dan centang buku tanpa layar skor penuh. Pemain masih dapat kembali ke kebun atau mengulang resep setelah penutup.

## 10. Gerbang penerimaan

### 10.1 P0

P0 gameplay diterima setelah seluruh FR P0 selain distribusi terpenuhi, tes transaksi/save kritis lulus, rute baru dan lanjutan selesai, dan playtest pemain baru tidak memerlukan bantuan berulang untuk tindakan dasar. Laporkan observasi nyata, termasuk durasi, titik bingung dan bantuan yang diberikan.

P0 distribusi memerlukan task ekspor/installer dan pengujian mandiri tambahan. Tidak ada status “selesai” berdasarkan dokumen atau kode yang belum dijalankan. Rincian tugas ada di [TASKS](TASKS.md); daftar bukti ada di [TEST_PLAN](TEST_PLAN.md).

### 10.2 P0.5 "Kampung Hidup" (DEFAULT UJI)

Gerbang dapat disesuaikan dengan alasan dan catatan dampak (AGENTS §3). Angka ambang ada di CONTENT bagian 20; kasus uji di TEST_PLAN bagian 10.

1. Semua tes otomatis kritis P0.5 (T61–T77) lulus, termasuk seluruh suite P0 lama; jumlah asersi tidak berkurang tanpa alasan tertulis.
2. Perangkat uji pemilik dicatat; rute standar tepi ke tepi memenuhi ambang FPS di CONTENT bagian 20, atau fallback sah dengan catatan jujur dan keputusan pemilik.
3. Lintasan batas chunk memenuhi ambang hitch di CONTENT bagian 20; maksimum dilaporkan.
4. Memori 30 menit dan jumlah ObjectDB saat exit memenuhi ambang CONTENT bagian 20 terhadap baseline P0.
5. Pemain baru menyelesaikan tiga resep warisan dari profil bersih dan dari save tengah, tanpa minimap; bantuan yang diberikan dicatat.
6. Nol masalah kritis (TEST_PLAN bagian 2); nol aset tanpa entri manifes lisensi; save v1 pemilik termigrasi tanpa kehilangan.

Regresi P0 (T01–T60) menjadi syarat tetap. Kode yang ditulis tetapi belum dijalankan bukan bukti; task tetap DIKERJAKAN sampai bukti run ada.

## 11. Kontrak tujuan tiga resep warisan (P0.5)

**Tujuan utama:** melengkapi buku resep keluarga, yaitu tiga halaman yang masing-masing distempel setelah hidangannya dimasak lalu diserahkan kepada penerimanya (D30). Tujuan antara per halaman: halaman ditemukan, bahan terkumpul dari areanya, dimasak di dapur rumah, diserahkan. Angka, ID dan teks ada di CONTENT bagian 16–18.

- **Progres tanpa panel baru:** sampul buku menampilkan jumlah halaman distempel dan tiap halaman memuat empat centang yang membaca aturan ketersediaan yang sama dengan tracker. HUD tetap satu tracker dan satu resep dilacak (D17).
- **Akhir:** stempel ketiga memunculkan layar penutup satu kali; permainan berlanjut. Input penutup tidak diteruskan ke aksi dunia.
- **Tidak mengunci jalan:** urutan resep bebas; tidak ada tenggat, kematian atau barang buangan; sumber liar pulih tiap hari; penerima selalu berada di titik temu pada blok jam yang dijamin (CONTENT bagian 17.3) dan ketuk pintu menawarkan titip hidangan; hidangan salah alamat tidak terkonsumsi; hubungan hanya mengubah dialog atau petunjuk.
- **Penyerahan:** memotong satu hidangan dari tas atau peti secara atomik, menandai penerima dan stempel, idempoten sekali per resep; klik berulang atau muat ulang tidak menggandakan hidangan atau stempel.
- **Reservasi dan pelacakan:** tiga resep memakai aturan ketersediaan bagian 6 yang sama; bahan tumpang tindih antar-resep tidak dihitung ganda dan reservasi tetap milik job.

## 12. Riwayat perubahan

| Versi | Tanggal | Perubahan |
| --- | --- | --- |
| 0.2 | 27 Oktober 2026 | Kontrak P0 |
| 0.3 | 30 Oktober 2026 | SCOPE-001: banner kontrak P0 + P0.5; hasil akhir dan batas P0.5 (bagian 1–2); matriks waktu warga dan streaming (5.1); skema save v2 dan migrasi (7.1); gerbang P0 dan P0.5 (10); kontrak tujuan tiga resep (11) |

