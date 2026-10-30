# PRD — Buku Resep 2045

**Versi:** 0.3 · **Tanggal:** 30 Oktober 2026 · **Pemilik produk:** Muhammad Fauzi  
**Status:** P0 gameplay selesai (QA-001) dan diimplementasikan di Godot; tahap berikutnya P0.5 "Kampung Hidup" (D26–D32) sedang disiapkan lewat SCOPE-001. Keadaan pelaksanaan, bukti uji dan kendala hanya dilaporkan di [PROJECT_STATUS](docs/PROJECT_STATUS.md); dokumen ini adalah spesifikasi.  
**Nama kerja:** Buku Resep 2045. Judul rilis final belum dipilih. Format event: **Nama Game: Nama Event**, contohnya **Buku Resep 2045: Karhutla**. Karhutla adalah judul event, bukan chapter atau nama utama.

## 1. Tujuan dan cara membaca

Game membawa pemain menjalani kehidupan lokal di Indonesia tahun 2045 dalam krisis pangan dan ekonomi global yang fiktif. Sebuah buku resep keluarga menjadi alasan untuk menjelajah, menemukan bahan, memperbaiki tanah, menanam, memasak dan mengenal warga. Tujuan utama adalah menuntaskan seluruh masakan pada buku, bukan mengalahkan musuh atau menyelesaikan angka ekonomi.

Versi ini menggantikan PRD v0.1 sebagai acuan aktif; v0.3 menambah tahap P0.5 berdasarkan arahan pemilik 30 Oktober 2026 ([rencana induk](docs/plans/00-rencana-induk.md) beserta rencana 01–04 sebagai rasional teknis). Detail sistem dipisahkan ke dokumen khusus agar angka, kontrol dan aturan tidak ditulis berulang. Klaim hasil uji hanya yang tercatat di laporan task dan [TEST_PLAN](docs/TEST_PLAN.md) bagian 1; tidak ada klaim kompatibilitas perangkat atau benchmark di luar itu, dan semua angka performa P0.5 adalah target yang belum diukur.

Label keputusan:

- **DISETUJUI:** keputusan eksplisit atau rancangan yang sudah disetujui dalam diskusi.
- **DEFAULT UJI:** pilihan operasional konkret agar prototipe dapat dikerjakan; dapat disesuaikan berdasarkan pengujian tanpa mengubah pilar produk.
- **TERBUKA:** sengaja belum dikunci; ada batas waktu keputusan dan default jika dibutuhkan.

Persetujuan arah prototipe tidak berarti seluruh angka balancing telah disetujui sebagai final. CONTENT adalah acuan angka DEFAULT UJI. Instruksi terbaru pengguna mengungguli dokumen.

## 2. Ringkasan pengalaman

| Aspek | Rancangan |
| --- | --- |
| Platform | PC, aplikasi desktop yang nantinya dapat diinstal; first person 3D |
| Genre kerja | Eksplorasi, berkebun dan memasak dengan cerita lingkungan |
| Ritme | Santai saat merawat/memasak; menekan melalui keterbatasan dan kondisi dunia |
| Tujuan panjang | Seluruh resep inti buku selesai |
| Tujuan P0 | Satu perjalanan membuat Sayur Bening Bayam dan Jagung sampai hidangan dimakan atau dibagikan |
| Tujuan P0.5 | Mengumpulkan 3 resep warisan: tiap halaman buku distempel setelah hidangannya dimasak dan diserahkan kepada warga penerimanya (D30) |
| Sumber bahan | Usaha pemain: tanam, panen, mencari dan kelak aktivitas lain; tidak dibeli untuk melewati proses resep |
| Tempat | Kampung fiktif Indonesia, inspirasi awal Jawa Tengah; satu map fiksi, zona inti P0 yang diperluas menjadi dunia sekitar 1 km² pada P0.5 (D27) |
| Cara bermain awal | Keyboard dan mouse, single-player offline sebagai default P0 |
| Arah visual | Stylized sederhana dengan referensi artistik Firewatch; P0.5 memakai aset CC0 terverifikasi dan generator kode (D28) |
| Pengembangan | Godot, GDScript, VS Code, Git/GitHub, dikerjakan bertahap dengan bantuan AI |

Janji pengalaman: bahan yang awalnya terasa sulit ditemukan perlahan menjadi sesuatu yang dapat dirawat, dipahami dan dibagikan. Pemain melihat perubahan melalui petak yang hidup, masakan nyata di dapur dan hubungan dengan warga.

## 3. Register keputusan produk

| ID | Keputusan | Status |
| --- | --- | --- |
| D01 | Tahun 2045 adalah latar; perayaan tahun tersebut bukan pusat konflik | DISETUJUI |
| D02 | Krisis global dilihat melalui pengalaman lokal Indonesia; masyarakat/institusi masih berfungsi | DISETUJUI |
| D03 | Buku keluarga dan penyelesaian seluruh resep adalah tujuan utama | DISETUJUI |
| D04 | Game 3D first person untuk PC desktop | DISETUJUI |
| D05 | Ritme bergantian santai dan menekan | DISETUJUI |
| D06 | Bahan resep diperoleh melalui usaha pemain; pembelian bahan bukan jalur penyelesaian | DISETUJUI |
| D07 | Kebun mencakup perbaikan tanah, penanaman, pupuk dan air | DISETUJUI |
| D08 | Pemupukan dan penyiraman bekerja per area/petak, bukan setiap tanaman | DISETUJUI |
| D09 | Memilih resep untuk dilacak menampilkan quest ringkas di atas layar | DISETUJUI |
| D10 | Godot rilis stabil, GDScript, VS Code, GitHub | DISETUJUI |
| D11 | Nomor versi Godot spesifik dikunci saat setup; spesifikasi komputer dibahas nanti | DISETUJUI |
| D12 | Visual stylized sederhana mendekati Firewatch, identitas Indonesia sendiri | DISETUJUI; dilengkapi D28 sejak 30 Okt 2026 |
| D13 | P0 satu resep: Sayur Bening Bayam dan Jagung; bayam ditanam, jagung dipanen, temu kunci dicari | DISETUJUI. Berlaku untuk P0; dilengkapi D30 sejak 30 Okt 2026 (resep ini tetap salah satu dari tiga) |
| D14 | P0 mencakup rumah/dapur, pekarangan, jalan, sisa kebun, rumpun bambu dan teras tetangga | DISETUJUI. Berlaku untuk P0; dilengkapi D27 sejak 30 Okt 2026 (menjadi zona inti dunia yang lebih luas) |
| D15 | UI harus sederhana, nyaman, mudah dipahami; detail muncul bertahap | DISETUJUI |
| D16 | Status utama ringkas; tiap task selesai wajib diarsipkan secara terperinci oleh AI | DISETUJUI |
| D17 | Satu resep aktif; tidak menghalangi pengumpulan bahan lain | DISETUJUI untuk P0 |
| D18 | Tanaman P0 yang kurang terawat berhenti tumbuh sementara, bukan mati | DISETUJUI untuk P0 |
| D19 | Satu petak empat titik, satu NPC, dua tahap memasak | DISETUJUI sebagai cakupan P0. Berlaku untuk P0; "satu NPC" digantikan D29 untuk P0.5, sisanya dipertahankan D32; dilengkapi D27/D29/D30 sejak 30 Okt 2026 |
| D20 | Single-player offline, tanpa combat/hunger mematikan pada P0 | DEFAULT UJI |
| D21 | Windows desktop 64-bit sebagai target ekspor uji pertama | DEFAULT UJI; konfirmasi saat setup |
| D22 | Nama final, biografi tokoh, lokasi administratif dan jumlah resep akhir | TERBUKA; tidak menghalangi P0. Sejak 30 Okt 2026: jumlah resep P0.5 = 3 (D30); jumlah akhir tetap TERBUKA |
| D23 | Satu map fiksi dengan referensi Indonesia; event bertema kondisi Indonesia mengubah tantangan bahan | ARAH DISETUJUI; detail mekanik USULAN BARU |
| D24 | Format nama game utama + judul event; Karhutla contoh judul event, bukan chapter | DISETUJUI |
| D25 | Sains sederhana muncul pada beberapa aspek, tidak hanya tanah | ARAH DISETUJUI; rincian dan angka USULAN BARU |
| D26 | Tahap baru **P0.5 "Kampung Hidup"** di antara P0 dan P1; P0 tetap tercatat SELESAI sebagai riwayat | DISETUJUI oleh pemilik pada 30 Okt 2026; gerbang angka DEFAULT UJI |
| D27 | Satu map fiksi diperluas menjadi sekitar 1 km² dengan chunk streaming; area awal P0 menjadi zona inti; ID lokasi P0 tidak berubah. Melengkapi D14 | DISETUJUI oleh pemilik pada 30 Okt 2026; ukuran chunk/radius DEFAULT UJI (CONTENT bagian 19) |
| D28 | Visual stylized terinspirasi Firewatch memakai aset CC0 yang terverifikasi + generator kode; tanpa aset Firewatch; semua aset masuk manifes lisensi. Melengkapi D12 | DISETUJUI oleh pemilik pada 30 Okt 2026 |
| D29 | NPC bergerak dengan jadwal sederhana berbasis waktu simulasi, lebih dari satu warga. Menggantikan "satu NPC" pada D19 untuk P0.5 | DISETUJUI oleh pemilik pada 30 Okt 2026; jumlah NPC/jadwal DEFAULT UJI (CONTENT bagian 17) |
| D30 | Tujuan P0.5: mengumpulkan **3 resep warisan**; Sayur Bening Bayam dan Jagung (D13) tetap salah satunya. Satu resep aktif (D17) tetap. Mengisi sebagian D22; jumlah akhir 8–12 (P2) tetap TERBUKA | DISETUJUI oleh pemilik pada 30 Okt 2026; pilihan dua resep lain DEFAULT UJI (CONTENT bagian 16) |
| D31 | Save berpindah ke skema v2 dengan migrasi v1→v2 tertulis, cadangan v1 dipertahankan | DEFAULT UJI (kebijakan AGENTS §8); dikunci pada SAVE-002 |
| D32 | Dalam P0.5 tetap tanpa combat, multiplayer, backend, login, telemetri, AI runtime, pembelian bahan, hunger bar, minimap wajib. Satu petak/empat titik dan dua tahap memasak (sisa D19) tetap sampai GOAL-001 membuktikan perlu berubah | DISETUJUI (mempertahankan D06/D15/D20) |

## 4. Dunia, tokoh dan batas cerita

Krisis telah berlangsung cukup lama untuk meninggalkan jejak pada pasokan, bangunan, kebun dan hubungan sosial. Pasar tetap ada, komunikasi masih berlangsung, dan warga tetap bekerja. Kelangkaan dirasakan tidak merata: sebagian orang dapat mengakses barang yang bagi orang lain sudah sulit ditemukan.

Pemain tinggal atau kembali ke rumah keluarga. Alasan kepulangan, umur, pekerjaan dan siapa pemilik awal buku belum dikunci. P0 cukup memakai buku dengan catatan tangan serta satu warga berlabel “Tetangga”. Prototipe tidak memerlukan cutscene kematian keluarga atau biografi panjang.

Satir hadir melalui ketidaksesuaian klaim dan kondisi: papan program pangan yang usang di dekat lahan terbengkalai, rak kosong yang ditata rapi, atau catatan warga tentang akses benih. Tokoh dan lembaga fiktif. Hindari ceramah panjang dan jangan mengharuskan pemain membaca seluruh dokumen untuk memahami tindakan inti.

Rumah adalah tempat jeda. Dunia sulit tidak berarti semua tempat gelap, hancur atau bermusuhan. Ada warna, kesibukan, tanaman sehat dan kesempatan menikmati hasil. Krisis global tidak harus selesai karena satu kebun berhasil dipulihkan.

## 5. Pemain sasaran dan prinsip desain

Sasaran awal adalah pemain yang menyukai eksplorasi, berkebun, memasak dan cerita lingkungan, termasuk orang yang tidak berpengalaman dengan simulasi kompleks. Pemain tidak perlu memahami agronomi atau menghafal banyak tombol.

1. **Masakan memberi arah:** setiap bahan berhubungan dengan tempat, proses atau seseorang.
2. **Perubahan terlihat:** perawatan memberi perubahan visual dan akses bahan, bukan hanya angka.
3. **Pengetahuan adalah kemajuan:** petunjuk dan teknik membuka kemungkinan baru.
4. **Rutinitas makin efisien:** perawatan area dan peningkatan alat mengurangi pekerjaan berulang.
5. **Kendali ada pada pemain:** resep bukan tenggat paksa; rute dapat dipilih sendiri.
6. **UI menjelaskan tindakan terdekat:** detail sistem tidak harus tampil sepanjang waktu.
7. **Kegagalan dapat dipulihkan:** eksperimen awal tidak menghapus jalan menuju resep.

## 6. Tahapan produk dan cakupan

| Tahap | Tujuan | Isi | Gerbang penerimaan |
| --- | --- | --- | --- |
| Dokumentasi v0.2 | Landasan bersama | Seluruh dokumen, wireframe, tugas dan aturan agent | Konsistensi, tautan dan paket diperiksa; tidak berarti game teruji |
| P0 — prototipe | Membuktikan loop satu resep | Satu area, satu petak, satu resep, satu warga, save/load, audio dasar | Loop baru dan lanjutan selesai; uji kritis lulus |
| P0.5 — Kampung Hidup | Membuktikan dunia hidup dengan tujuan jelas (D26) | Dunia sekitar 1 km² dengan chunk streaming, visual CC0 + generator kode, warga bergerak berjadwal, tiga resep warisan, save v2. Bukan isi: event Karhutla (tetap P1), pasar, sistem memancing penuh (hanya titik pancing tetap), installer | Enam gerbang di [PROTOTYPE](docs/PROTOTYPE.md) bagian 10.2; ambang angka di [CONTENT](docs/CONTENT.md) bagian 20 |
| P0 — distribusi | Membuktikan penggunaan desktop mandiri | Build mandiri dan paket instalasi awal; dijadwalkan setelah QA-002 (gerbang P0.5) | Berjalan tanpa editor/akses jaringan dan jalur save benar |
| P1 — vertical slice | Mewakili kualitas akhir | Prioritas usulan: satu event Karhutla dengan resep dasar, cerita lokal dan visual/audio representatif; resep tambahan di luar tiga resep warisan tetap kandidat sesudahnya | Playtest, save event dan performa pada perangkat yang ditetapkan |
| P2 — cerita inti | Membuktikan tujuan buku lengkap | Kandidat 8–12 resep, beberapa subarea dan warga, akhir lokal | Jumlah konten diputuskan setelah P1 |
| P3 — perluasan | Memperdalam sistem yang terbukti berguna | Memancing, pengairan, pemulihan habitat, variasi resep dan alat | Keputusan terpisah, bukan janji rilis P0 |

Sistem memancing penuh (joran, umpan, minigame), pasar dan interaksi warga yang lebih dalam tetap bagian arah dunia/roadmap. P0 menguji tiga sumber bahan dahulu; P0.5 menambah bahan dari node liar dan titik pancing tetap tanpa minigame (CONTENT bagian 16). Pasar belum menjadi level aktif; tidak ada sistem beli bahan untuk menyelesaikan resep. Peta Indonesia luas, multiplayer, kendaraan, combat, ekonomi dinamis, akun/cloud, konstruksi bebas, simulasi pencemaran kompleks dan AI generatif runtime berada di luar P0 dan P0.5; dunia P0.5 tetap satu map fiksi, bukan peta Indonesia.

P0 tidak menampilkan kartu resep palsu hanya untuk membuat buku tampak penuh. Satu resep aktif cukup; daftar tambahan baru muncul jika kontennya benar-benar tersedia, sehingga pada P0.5 daftar tiga halaman muncul karena dua resep baru memang ada dan satu resep tetap dilacak (D17). Ini penyesuaian terhadap dua kartu placeholder v0.1 demi UI sederhana.

## 7. Siklus inti

Buka buku → pilih/lacak resep → pahami bahan dan petunjuk → peroleh benih serta bahan perawatan → siapkan petak dan tanam → cari jagung/temu kunci saat bayam tumbuh → panen → siapkan dan masak → hidangan dihasilkan → buku menandai selesai → makan atau berbagi → simpan dan lanjutkan.

Pemain boleh menjelajah, mengumpulkan bahan dan menanam sebelum melacak resep. Quest membaca keadaan permainan; quest tidak menciptakan bahan, mengunci panen atau menghapus inventaris saat pilihan berubah. Memiliki semua bahan belum menyelesaikan resep; memasak berhasil adalah pemicu penyelesaian.

## 8. Persyaratan fungsional

ID FR01–FR20 mempertahankan hubungan dengan PRD lama. FR21–FR24 menambahkan kenyamanan, penyerahan dan aturan status. FR25–FR30 (v0.3) menambah kebutuhan tahap P0.5. Rincian tes berada di TEST_PLAN.

| ID | Tahap | Kebutuhan | Bukti penerimaan |
| --- | --- | --- | --- |
| FR01 | P0 | Gerak dan pandang first person | Bisa menavigasi rute, berhenti di collision, tidak terjebak spawn |
| FR02 | P0 | Satu prompt interaksi sesuai arah pandang | Target valid, jangkauan dan alasan penolakan konsisten |
| FR03 | P0 | Buku resep dapat dibuka, dilacak dan dibaca ulang | Bahan, sumber, progres dan status selesai benar |
| FR04 | P0 | Tracker ringkas di atas layar | Hitungan mengikuti tas + stok rumah yang bebas, termasuk bahan diperoleh sebelum melacak |
| FR05 | P0 | Pickup/panen sumber deterministik | Sumber dan inventaris berubah tepat sekali |
| FR06 | P0 | Tas dan penyimpanan rumah | Transfer tidak menghilangkan/menambah barang; kapasitas dijelaskan |
| FR07 | P0 | Persiapan tanah | Petak digemburkan dan diberi pembenah sebelum tanam |
| FR08 | P0 | Tanam per titik | Titik kosong dan benih diperiksa; batal tidak mengonsumsi |
| FR09 | P0 | Pupuk per petak | Satu biaya untuk seluruh petak; aksi berlebih tidak menghabiskan |
| FR10 | P0 | Siram per petak | Air/progres aksi konsisten; isi ulang tersedia; cukup air tidak boros |
| FR11 | P0 | Tumbuh dan panen bayam | Kekurangan menahan pertumbuhan; panen satu kali dan titik dapat ditanam ulang |
| FR12 | P0 | Persiapan dan pemasakan | Satu job aktif; reservasi utuh; panas sederhana dan toleransi kesalahan |
| FR13 | P0 | Progres buku dan penggunaan hasil | Selesai saat hidangan dihasilkan; makan/berbagi tidak menghapus centang |
| FR14 | P0 | Dialog dan catatan | Petunjuk dapat dibaca ulang; tidak menjadi satu-satunya kunci bahan |
| FR15 | P0 | Save/load lokal | Dunia, item, petak, job, progres dan posisi aman pulih dengan benar |
| FR16 | P0 | Pause dan pengaturan | Input menu/dunia terpisah; simulasi berhenti pada menu sesuai kontrak |
| FR17 | P0 | Pemulihan jalan buntu | Benih cadangan dan sumber berulang tersedia tanpa duplikasi |
| FR18 | P1 | Event lingkungan tematik | Perubahan dunia nyata dalam game, akses bahan terdampak, sains sederhana, peringatan dan pemulihan; rancangan EVENT_DESIGN |
| FR19 | P1 lanjutan setelah event | Perawatan bermanfaat untuk lebih dari satu tujuan | Sumber pangan membantu resep/kebutuhan berikutnya ketika konten tambahannya tersedia |
| FR20 | P2+ | Akhir buku | Penyelesaian seluruh resep inti membuka penutup dan save dapat dilanjutkan |
| FR21 | P0 | UI nyaman dan aksesibilitas dasar | Teks terbaca, nama/jumlah jelas, FOV/sensitivitas/skala dapat diatur |
| FR22 | P0 | Build dan instalasi mandiri | Berjalan tanpa engine, tanpa internet, dengan aset lengkap |
| FR23 | P0 | Pelaporan keadaan proses | Error save, item penuh dan penolakan aksi tidak mengaku berhasil |
| FR24 | Semua tahap | Handoff AI setiap task | Arsip, daftar selesai, status terakhir dan task saling konsisten |
| FR25 | P0.5 | Dunia sekitar 1 km² dimuat per chunk di sekitar pemain dengan rumus deterministik; zona inti dan ID lokasi P0 tidak berubah | Pemetaan chunk deterministik, status sumber/petak bertahan saat chunk dibongkar dan dimuat, pemain tidak jatuh menembus atau keluar tepi, tanpa node yatim |
| FR26 | P0.5 | Visual memakai aset CC0 terverifikasi dan generator kode | Setiap aset punya entri manifes lisensi; sumber wajib tetap dapat dikenali; atribusi sesuai manifes |
| FR27 | P0.5 | Warga bergerak berjadwal berbasis waktu simulasi | Posisi deterministik terhadap hari dan jam; berhenti saat simulasi berhenti; penerima dapat ditemui pada titik temu; tidak mengunci sumber |
| FR28 | P0.5 | Tiga resep warisan dengan progres, penyerahan dan penutup | Tiap resep tercatat sekali; urutan bebas; satu resep dilacak; penutup sekali; tanpa minimap pemain menemukan ketiga sumber |
| FR29 | P0.5 | Save v2 dengan migrasi v1 ke v2 | Save v1 termigrasi tanpa kehilangan, berkas v1 tidak ditimpa; save rusak atau lebih baru ditolak dengan alasan |
| FR30 | P0.5 | Performa dan memori dunia luas | Ambang CONTENT bagian 20 pada perangkat tercatat; hasil dilaporkan jujur, tanpa generalisasi |

## 9. Kontrak sistem penting

### 9.1 Buku, bahan dan rumah

Satu resep dilacak pada P0 dan P0.5 (D17). Status dilacak terpisah dari selesai; pada P0.5 tiap resep juga memiliki status ditemukan, dimasak dan diserahkan dengan stempel halaman. Tas dan satu penyimpanan rumah adalah sumber bahan yang dapat digunakan dapur rumah; semua sumber lain tidak dihitung. Bahan yang sudah dicadangkan job tidak lagi bebas dipakai. Saat job aktif, tracker menampilkan tahap memasak, bukan seolah-olah bahan hilang secara misterius. Rumus dan urutan pengambilan ditetapkan dalam CONTENT.

### 9.2 Kebun

Tanah memiliki status persiapan, bahan organik, nutrisi dan kelembapan. UI menampilkan kategori “Belum diolah”, “Perlu pupuk”, “Kering” dan “Siap panen”. Penanaman per titik, pupuk/air per petak. Tidak ada simulasi tanah tercemar, kematian tanaman atau kerugian saat aplikasi ditutup di P0. Waktu tumbuh dipercepat khusus pengujian.

### 9.3 Dapur

Dua tahap: persiapan dengan tahan tombol, lalu pemasakan dengan pilihan panas rendah/sedang/tinggi. Satu job aktif dan satu slot hasil. Panas yang kurang tepat memperlambat/menahan, bukan memusnahkan bahan penting. Bahan berpindah ke reservasi hanya setelah prasyarat lengkap. Batal sebelum pemasakan mengembalikan bahan secara aman. Setelah pemasakan dimulai, menutup panel menjeda job; pemain dapat kembali melanjutkan. Hasil tetap di dapur jika tas penuh.

### 9.4 Save dan kegagalan

Satu profil permainan menyimpan checkpoint manual dan autosave terpisah, masing-masing dengan cadangan. P0.5 memakai skema v2 dengan migrasi v1 ke v2 yang tertulis dan cadangan v1 dipertahankan (D31; kebijakan di PROTOTYPE bagian 7). Menyimpan manual tidak diam-diam mengganti arti slot autosave. Save baru tidak menimpa progres lama tanpa konfirmasi. Validasi versi/skema sebelum mengganti keadaan dunia. Bila data rusak, tawarkan checkpoint valid berikutnya; jangan membuat dunia setengah termuat. Detail transaksi dan pemulihan dalam PROTOTYPE.

### 9.5 Waktu dan kenyamanan

Tidak ada deadline resep atau kerugian offline. Menu umum menghentikan simulasi. Dapur menjalankan waktu hanya saat panel pemasakan aktif dan tidak sedang di-pause; penjelasan lengkap pada PROTOTYPE mencegah dua sistem timer yang bertentangan. Tidak ada head bob/motion blur default atau guncangan interaksi rutin. Sprint/lompat tidak diperlukan untuk menyelesaikan P0.

## 10. Dunia awal dan pengarahan visual

Event tematik memakai map yang sama dan identitas **Nama Game: Nama Event**. Karhutla memberi kebakaran lokal yang benar-benar mengubah akses bahan; respons, perlindungan air dan pemulihan memakai sains sederhana. Aktivasi, angka, state dan uji adalah USULAN BARU pada [EVENT_DESIGN](docs/EVENT_DESIGN.md), bukan perluasan otomatis P0. Inspirasi kondisi Indonesia tidak berarti sinkronisasi berita langsung atau event terbatas tanggal nyata.

Zona inti (`zone_core`, area awal P0) adalah area kecil terhubung: rumah/dapur, pekarangan dengan kebun dan air, jalan kampung, sisa kebun keluarga, tepi rumpun bambu, teras tetangga. Rute membentuk putaran pendek dan rumah dikenali sebagai pusat kembali. Pada P0.5 zona inti menjadi pusat dunia sekitar 1 km² (D27) dengan sungai, hutan desa, kebun warga dan dusun yang dimuat per chunk; ID lokasi P0 tidak berubah. Tidak ada minimap wajib atau lompatan presisi pada kedua tahap. LEVEL_DESIGN menentukan denah, zona dan titik aman.

Firewatch dipakai sebagai referensi penyederhanaan bentuk, palet terarah, siluet dan suasana cahaya. Hasil tetap kampung Indonesia dengan genteng, teras, bambu, peralatan dan tanaman yang masuk akal. Bukan penyalinan aset, peta atau identitas game referensi. Graybox sah sebagai langkah awal, namun belum memenuhi target visual akhir; P0.5 menaikkan mutu visual lewat aset CC0 terverifikasi dan generator kode (D28) dengan renderer yang sama, dan tidak menyatakan visual akhir tercapai sebelum dinilai pemilik.

Keinginan “ringan tetapi grafis tetap oke” dijawab melalui lingkungan terkendali, material terbatas, vegetasi selektif dan pengujian. Tidak ada janji FPS untuk perangkat lain; ambang P0.5 di CONTENT bagian 20 adalah gerbang penerimaan pada perangkat uji pemilik yang dicatat.

## 11. UI/UX wajib

HUD hanya tracker ringkas di atas, crosshair kecil, satu prompt dan alat aktif. Informasi kondisi hanya muncul ketika relevan. Buku menampung detail sumber dan resep; kebun menampilkan aksi terdekat; tas menunjukkan nama/jumlah serta tombol transfer. Tidak mengandalkan drag-and-drop atau warna saja.

Satu tombol interaksi utama E. Klik kiri untuk alat yang sedang aktif; kontrol lain dirinci pada UI_UX. Sistem dapat mendalam tanpa membebani pemain dengan menu teknis, statistik mentah atau semua instruksi sekaligus. Ukuran UI, sensitivitas dan FOV disediakan pada P0. Penguji baru harus dapat memahami tindakan berikutnya tanpa arahan lisan terus-menerus.

## 12. Kebutuhan nonfungsional dan pengukuran

| Bidang | Target rancangan | Cara memverifikasi |
| --- | --- | --- |
| Stabilitas | Loop baru dan lanjutan tanpa crash/softlock | Playthrough dan uji transaksi ekstrem |
| Performa | Sasaran uji 60 FPS pada 1080p kualitas rendah di perangkat yang nanti ditetapkan; evaluasi 30 FPS bila diperlukan. P0.5: ambang dunia luas dan memori di CONTENT bagian 20 | Catat perangkat, renderer, build, rute, FPS/frame time dan hitch; bukan jaminan |
| Offline | Seluruh P0 tanpa jaringan/akun | Jalankan build dengan jaringan nonaktif |
| Persistensi | Tidak hilang/duplikat saat save/load atau kegagalan penulisan; save v1 termigrasi ke v2 tanpa kehilangan (P0.5) | Round trip, data rusak, ruang simpan gagal, interrupted write, fixture v1 |
| Kenyamanan | Tidak mengandalkan gerak kamera agresif atau teks kecil | Uji FOV/skala UI dan observasi pemain |
| Distribusi | Aset/dependency lengkap, installer jelas | Komputer/lingkungan tanpa engine dan hak akses terbatas |
| Privasi | Tidak menambah login, telemetri atau layanan runtime P0 | Tinjau dependency dan akses jaringan |
| Pemeliharaan | Satu definisi konten dan laporan tiap task | Audit sumber serta tautan laporan |

Spesifikasi minimum, ukuran unduhan, RAM dan waktu muat ditetapkan sesudah pengukuran. Tidak menahan dokumentasi untuk menunggu spesifikasi komputer pengguna.

## 13. Produksi teknis, konten dan kepemilikan

Godot/GDScript adalah keputusan final tahap ini; versi persis dan renderer adalah hasil setup, bukan pertanyaan pemilihan engine ulang. Simpan versi dan alasannya di README serta laporan SETUP-001. Struktur modul sederhana: pemain/interaksi, item, buku/quest, kebun, dapur, dialog, waktu, save, UI dan audio. Tidak perlu framework besar sebelum loop terbukti.

Semua definisi item, resep dan angka mengikuti CONTENT. Implementasi data runtime nanti bukan menyalin Markdown langsung menjadi kode tanpa pemeriksaan. Save hanya menyimpan keadaan dinamis dan ID definisi yang valid.

Gunakan aset buatan sendiri atau yang lisensinya dapat diverifikasi. Pada P0.5 (D28) sumber yang sah hanya aset CC0 yang terverifikasi pada halaman resmi dan keluaran generator kode proyek; semuanya tercatat di manifes lisensi (ART_DIRECTION bagian 10) dan aset berstatus belum terverifikasi tidak dipakai. Catat atribusi sebelum distribusi. Tidak ada aset game Firewatch yang menjadi bagian paket. Tidak ada kebutuhan backend atau layanan berlangganan untuk P0 maupun P0.5.

## 14. Sains terapan dan batas representasi

Bioremediasi, fitoremediasi dan pemulihan lingkungan adalah arah eksplorasi lanjutan, bukan sistem otomatis P0. P0 hanya menunjukkan perbaikan struktur tanah dan perawatan sederhana pada lahan yang tidak didefinisikan sebagai tercemar.

Sebelum menambah mikroorganisme, spesies penyerap pencemar, pH, biochar, penguraian plastik atau keamanan pangan, lakukan validasi sumber ilmiah primer yang relevan dan dokumentasikan batas penyederhanaannya. Jangan menulis resep pengolahan pangan dari biomassa remediasi, atau menganggap satu bahan mampu menyembuhkan semua tanah. Animasi petak menghijau adalah umpan balik gameplay, bukan bukti keselamatan pangan. Durasi pertumbuhan dan takaran prototipe adalah unit permainan.

Bahan baru P0.5 mengikuti batas yang sama. Teks pakis, tanaman hutan, ikan dan resep tidak menyebut ciri identifikasi, tingkat kematangan, cara memilah, pengolahan aman atau klaim keamanan konsumsi; nama bahan dan lokasi cukup. Kelayakan kuliner (pepes, urap) hanya menyatakan masakan itu lazim, bukan bahwa bahan aman. Tambahan teks ilmiah apa pun (mis. kebiasaan tumbuh pakis) divalidasi sumbernya lebih dahulu.

## 15. Roadmap, penerimaan dan risiko

TASKS adalah daftar pelaksanaan, bukan jadwal janji. Urutan logis P0: setup → graybox/spawn → gerak/interaksi → inventaris/buku → kebun/sumber → dapur → save/load → narasi/UI/audio → pengujian utuh. Urutan P0.5 (SCOPE-001, aset dan perbaikan dasar, fondasi dunia, tujuan tiga resep, streaming, save v2, isi dunia, visual, warga bergerak, QA-002) dan gelombang kerjanya ada di [rencana induk](docs/plans/00-rencana-induk.md) bagian 3 dan akan tercatat di TASKS; distribusi mengikuti setelah QA-002. Pengujian lokal dilakukan sejak tiap sistem tersedia; tidak ditunda sampai akhir.

P0 gameplay selesai jika pemain baru dapat membuat hidangan, mencatat buku, memakai/membagikan hasil, menyimpan dan melanjutkan tanpa bantuan berulang atau masalah kritis. P0 distribusi selesai jika build mandiri dan installer juga lulus. TASKS dan TEST_PLAN memisahkan dua gerbang tersebut agar prototipe editor tidak diklaim siap dibagikan. P0.5 selesai jika enam gerbang di PROTOTYPE bagian 10.2 lulus dengan bukti run nyata pada perangkat pemilik; kode yang ditulis tetapi belum dijalankan bukan penyelesaian.

| Risiko | Respons |
| --- | --- |
| Cakupan membesar sebelum loop hidup | Kunci satu resep; ide baru masuk backlog dengan alasan |
| UI menjadi dashboard penuh statistik | Tampilkan satu tindakan terdekat dan detail di buku |
| Kebun menjadi klik berulang | Perawatan per petak, tidak memaksa semua titik ditanam |
| Bahan wajib habis atau tas penuh | Sumber deterministik, pemulihan, transaksi utuh |
| Save/masak menggandakan barang | Reservasi ber-ID, job idempotent, pengujian persistensi |
| Visual menarik tetapi berat | Uji rute, material/vegetasi terbatas, pilih renderer berdasarkan pengukuran |
| Sains dipresentasikan berlebihan | Pisahkan aturan gameplay dari klaim ilmiah; validasi sebelum menambah sistem |
| Agent berikutnya kehilangan konteks | Status ringkas, arsip lengkap dan task ID yang konsisten |
| Sesi agent berbasis cloud tidak dapat menjalankan Godot (P0.5) | Setiap laporan memisahkan "ditulis" dari "dijalankan"; task gameplay baru SELESAI dengan log run pemilik; tes headless ditulis lebih dahulu |
| Cakupan P0.5 meluas (dunia, resep, warga sekaligus) | D32, gerbang bertahap, ide baru masuk backlog; dunia dibuat jarang lebih dahulu |
| Performa chunk streaming di renderer Compatibility | Anggaran per frame, mode sinkron cadangan, pengukuran rute sebelum menambah visual (CONTENT bagian 19–20) |
| Aset CC0 tidak terunduh atau lisensi tidak terverifikasi | Generator kode sebagai jalur cadangan; manifes lisensi wajib; unduhan oleh pemilik bila sesi cloud tidak dapat |
| Migrasi save v1 ke v2 menghilangkan atau menggandakan progres | Fixture v1 dari alur QA-001, migrasi tidak mengubah berkas asli, cadangan v1, uji pemulihan |
| Bug warga bergerak (macet, menembus, jalan saat pause) | Jalur poliline sederhana, posisi sebagai fungsi murni waktu, tes validasi jadwal dan pause |

## 16. Keputusan yang sengaja ditunda

| Hal | Default kerja | Waktu penetapan |
| --- | --- | --- |
| Judul rilis dan identitas visual final | Nama kerja Buku Resep 2045 | Sebelum publikasi merek |
| Identitas tokoh dan pemilik buku | Pemain tanpa nama; satu tokoh “Tetangga” | Sebelum penulisan cerita P1 |
| Lokasi administratif | Kampung fiktif, inspirasi Jawa Tengah | Sebelum produksi lokasi representatif |
| Nomor versi Godot dan renderer | Rilis stabil yang diverifikasi saat setup | SETUP-001 |
| Spesifikasi komputer/OS akhir | Windows desktop 64-bit sebagai default uji | Setup dan sebelum klaim performa |
| Resep tambahan serta ending lengkap | P0 satu resep; P0.5 tiga resep warisan dengan layar penutup buku (D30); jamuan 3D sebagai kandidat akhir buku | Setelah P1 dan keputusan cakupan |
| Simulasi cuaca/ekologi lanjutan | Tidak aktif P0 | Sesudah loop dan kebutuhan terbukti |

Tidak satu pun keputusan tersebut memerlukan bagian dokumen kosong. Default P0 sudah diberikan untuk pekerjaan yang relevan.

Gerbang event Karhutla pada P1 tidak otomatis membuktikan variasi beberapa resep pada FR19. Perluasan resep adalah pekerjaan lanjutan tersendiri setelah event pertama terbukti; jangan mengklaim seluruh roadmap P1 selesai hanya karena satu event sudah dapat dimainkan.

## 17. Riwayat perubahan

| Versi | Tanggal | Perubahan |
| --- | --- | --- |
| 0.1 | 26 Oktober 2026 | Fondasi dunia, buku, mekanik kebun, UI awal dan kriteria uji |
| 0.2 | 27 Oktober 2026 | Mengunci Godot/GDScript/VS Code/GitHub dan arah Firewatch; menetapkan prototipe bayam-jagung; mempertegas UI sederhana; memecah detail ke dokumen khusus; menghapus kartu kosong; menambahkan tata status dan arsip task; memasukkan arah event tematik, format nama game + event dan sains sederhana lintas aspek |

Perubahan v0.2 adalah pembaruan dokumentasi berdasarkan diskusi; ia ditulis sebelum ada kode. Perubahan v0.3 menerapkan arahan pemilik 30 Oktober 2026 pada dokumen sumber dan tidak mengklaim implementasi P0.5. [README](README.md) menjadi pintu masuk paket dan [PROJECT_STATUS](docs/PROJECT_STATUS.md) menjadi sumber keadaan pelaksanaan.
| 0.3 | 30 Oktober 2026 | SCOPE-001: tambah D26–D32 (tahap P0.5, dunia sekitar 1 km², aset CC0 + generator, warga bergerak, tiga resep warisan, save v2, batas lingkup); D12/D13/D14/D19/D22 dilengkapi bertanggal tanpa dihapus; tabel tahap §6, FR25–FR30, §2, §9–§16 dan risiko disesuaikan; baris status awal diperbarui sesuai kenyataan |
