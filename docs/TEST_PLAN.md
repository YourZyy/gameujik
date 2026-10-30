# Rencana Pengujian dan Bukti Penerimaan

**Versi:** 0.2 · **Tanggal:** 27 Oktober 2026  
**Acuan:** [PRD](../PRD.md), [CONTENT](CONTENT.md), [PROTOTYPE](PROTOTYPE.md), [TASKS](TASKS.md).

## 1. Keadaan saat paket diserahkan dan pembaruan verifikasi

Pada saat paket dokumentasi diserahkan, semua tes **gameplay, build, performa, instalasi dan event di bawah BELUM DIJALANKAN**, karena kode game belum dibuat. Sejak itu, implementasi dan QA-001 telah menambahkan bukti otomatis. Pada 30 Oktober 2026, `godot_console.exe --headless --path "C:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia" --script res://tests/test_runner.gd` dijalankan dengan hasil 8.854 asersi lulus, 0 gagal, exit code 0. Main scene juga berhasil dirender pada Godot 4.7.2 GUI.

Bukti otomatis tersebut tidak menggantikan playtest manual. Pada sesi DEMO-001, input keyboard/mouse dari otomasi desktop eksternal tidak diterima oleh window game; karena itu gerak, bidikan, interaksi target, navigasi panel dan keterbacaan saat dikendalikan pemain masih terbuka. Runner juga melaporkan 5.026 ObjectDB instance dan 14 resource masih digunakan saat exit; warning ini dicatat untuk investigasi, bukan diubah menjadi klaim lulus.

Rencana tes bukan bukti lulus. Setiap hasil pelaksanaan nanti harus memuat tanggal, task, versi engine/renderer, versi/commit build, perangkat/OS, data awal, langkah, hasil nyata, status dan lampiran bila perlu. Jangan mengubah tabel expected menjadi hasil faktual tanpa menjalankan tes.

## 2. Jenis verifikasi dan tingkat masalah

- **Otomatis:** hitungan, kapasitas, transaksi, state, timer deterministik dan persistensi. Dibuat saat sistem tersedia; tidak ada skrip tes game pada paket dokumentasi ini.
- **Integrasi langsung:** interaksi objek, UI, collision, alur dapur, save dalam aplikasi dan error yang terlihat.
- **Playtest:** pemahaman tujuan, kenyamanan kamera, navigasi, ritme dan rasa kegiatan.
- **Distribusi:** build tanpa editor, offline, installer, hak akses dan lokasi save.

Masalah kritis: progres/item hilang atau duplikat, tidak bisa menyelesaikan resep, save tidak bisa pulih, crash, input mengunci pemain. Masalah besar: tujuan sulit dipahami, UI terpotong, aksi area salah atau kontrol tidak konsisten. Masalah kecil: dekorasi/typo yang tidak mengubah perilaku. Tidak menutup gerbang gameplay/distribusi jika ada masalah kritis belum selesai.

## 3. Data awal uji

Gunakan profil bersih sesuai CONTENT untuk alur utama. Fixture tes terpisah menyediakan: tas hampir penuh, tas/peti penuh, bahan terbagi, tanaman hampir siap, petak kering, nutrisi kurang, job pada tiap tahap, output/refund tertahan dan checkpoint rusak. Fixture tidak masuk sebagai cheat tersembunyi pada build rilis.

Sebelum uji yang merusak save, salin profil pengujian; jangan menggunakan save pribadi pemain. Catat seed/setup bila ada pengacakan tambahan nanti. P0 sendiri tidak membutuhkan RNG untuk sumber wajib.

## 4. Kasus uji P0

Kolom langkah mencakup kondisi awal dan tindakan inti. Hasil expected adalah kontrak penerimaan, bukan hasil yang sudah diamati.

| ID | Kondisi dan langkah | Hasil yang diharapkan |
| --- | --- | --- |
| T01 | Game baru; buka buku; tekan Lacak; tutup | Tracker atas menunjukkan resep dan tiga kebutuhan, tanpa centang selesai |
| T02 | Ambil jagung sebelum melacak; lalu lacak | Jagung yang sudah dimiliki langsung dihitung; tidak perlu mengambil ulang |
| T03 | Lacak lalu berhenti melacak; buka lagi | Item/progres tetap; hanya tracker berubah |
| T04 | Spam E pada paket awal/sumber yang sama | Hasil diberikan sekali; sumber berubah sekali; tidak ada duplikasi |
| T05 | Tas tidak cukup menampung seluruh hasil bayam+benih; panen | Panen ditolak; tanaman siap dan nutrisi tidak berubah |
| T06 | Isi empat titik; pupuk petak satu kali | Satu pupuk digunakan, nutrisi petak diperbarui dan berlaku untuk semua titik |
| T07 | Siram petak yang kelembapannya sudah ≥ambang tidak perlu siram | Tidak menghabiskan air; pesan kondisi cukup; tidak spam transaksi |
| T08 | Tanam pada titik terisi/tanah belum siap | Ditolak dengan alasan; benih tidak berkurang |
| T09 | Fixture: benih habis, tidak ada tanaman, wadah awal sudah diambil; periksa cadangan | Paket cadangan tersedia jika muat; mengambil sekali menghilangkan syarat pengambilan berikutnya |
| T10 | Bahan resep kurang satu; tekan Siapkan | Tidak ada reservasi/job/mutasi; bahan yang kurang disebut |
| T11 | Bahan dibagi tas dan peti; cek buku lalu dapur | Kedua panel memakai total sama; reservasi mengambil urutan CONTENT |
| T12 | Klik Siapkan/Mulai berulang saat proses dimulai | Satu ID job, satu reservasi, satu output; tidak ada konsumsi ganda |
| T13 | Reservasi bahan; batalkan sebelum memasak | Jumlah total bebas+refund sama dengan sebelum mulai; tidak ada bahan hilang/bertambah |
| T14 | Simpan saat tanaman tumbuh dan job dijeda; keluar/load | Kemajuan tanaman/job, reservasi dan alat/air pulih persis; tidak berjalan offline |
| T15 | Siapkan job dengan tas penuh saat selesai | Output tetap di dapur dan resep selesai; bisa diambil setelah kapasitas tersedia |
| T16 | Main sampai setelah berbagi; simpan; tutup/buka; Lanjutkan | Buku, meal_used, sumber, hari, petak, kontainer dan posisi aman konsisten |
| T17 | Rusakkan checkpoint utama fixture; coba Muat | Tidak memuat setengah dunia; menawarkan checkpoint/cadangan valid dengan pesan |
| T18 | Tahan gerak/klik, buka/tutup panel dan ubah fokus aplikasi | Dunia berhenti saat modal; input penutup tidak bocor; fokus hilang mem-pause |
| T19 | Buat resep yang sudah selesai sekali lagi | Jumlah dibuat bertambah satu; centang tidak dihapus/diulang sebagai hadiah ganda |
| T20 | Jalankan build tanpa engine dan tanpa jaringan | Aset lengkap, loop dapat selesai, tidak ada permintaan login/runtime internet |
| T21 | Ubah FOV dan skala UI pada layar kecil/besar | Tombol/prompt tetap terlihat; kamera berubah sesuai pengaturan tanpa memotong UI |
| T22 | Hentikan proses saat fase penulisan save terkontrol | Setidaknya checkpoint valid sebelumnya/cadangan dapat dipulihkan; tidak mengaku save baru sukses |
| T23 | Buka proyek pada versi Godot yang dikunci, baca README | Versi/renderer/main scene cocok dan proyek bisa diimpor/dibuka |
| T24 | Jalankan main scene awal dan inspeksi spawn/map | Tidak ada error penghambat, spawn di ruang valid, ID lokasi penting tersedia |
| T25 | Berjalan seluruh rute, sudut pintu, petak dan batas; gunakan recovery | Tidak menembus/terjebak; recovery hanya posisi/rotasi, item tetap |
| T26 | Bandingkan gerak dan aksi pada batas FPS berbeda | Jarak/progres berbasis waktu konsisten, bukan dikalikan frame |
| T27 | Bidik objek valid, di luar jangkauan dan di balik dinding | Hanya satu prompt target yang dapat diakses; objek terhalang tidak dapat dipakai |
| T28 | Buka buku/tas/dialog/dapur/pause berturut; Esc dan konfirmasi | Satu panel utama; satu lapisan ditutup; mouse/fokus pulih; tidak ada aksi dunia tak sengaja |
| T29 | Isi tumpukan mendekati 20 lalu tambah melebihi batas | Kelebihan membuka slot sesuai kapasitas; seluruh transaksi ditolak jika tidak cukup |
| T30 | Transfer tumpukan/semua isi ke tujuan tidak cukup | Tidak ada transfer parsial diam-diam; jumlah total tetap dan alasan jelas |
| T31 | Kumpulkan bahan lengkap tanpa memasak; periksa buku | Status siap dimasak, belum selesai; bahan dipindah tas–peti tidak mengubah total |
| T32 | Tahan aksi gembur/pupuk/siram lalu batal sebelum penuh | Tidak ada biaya/mutasi; progres dunia reset; harus melepas sebelum aksi baru |
| T33 | Pakai pembenah/pupuk saat tidak perlu; ulangi isi air penuh | Tidak boros resource; kapasitas tidak lewat maksimum; alasan benar |
| T34 | Tanam, penuhi syarat, ukur kemajuan efektif sampai tiap tahap | Tahap/timing mengikuti CONTENT; seluruh tanaman memakai kondisi petak |
| T35 | Keringkan/kurangi nutrisi; tunggu; pulihkan | Kemajuan berhenti tanpa mundur/mati; lanjut dari nilai sebelumnya setelah syarat cukup |
| T36 | Panen berhasil lalu spam E; tanam ulang | Satu bayam+benih sesuai CONTENT; nutrisi turun sekali; titik kembali dapat ditanam |
| T37 | Ambil jagung/temu kunci; ulang sebelum pergantian hari; istirahat | Tidak ada hasil kedua hari sama; sumber pulih hari berikutnya secara terjelaskan |
| T38 | Masih ada benih di peti/tanaman hidup; minta cadangan | Tidak memberi benih cadangan; lokasi stok/kemungkinan panen dijelaskan |
| T39 | Catat petak, waktu/hari dan sumber; istirahat; ulang saat job aktif | Hari maju dan sumber pulih, petak tidak ditick satu hari sekaligus; istirahat ditolak bila job aktif |
| T40 | Reservasi, tutup panel, penuhi kontainer asal via fixture, lalu batalkan | Bahan kembali tepat sekali melalui sumber alternatif/refund persisten; tidak ditumpuk pada slot hasil |
| T41 | Jalankan panas Rendah/Sedang/Tinggi pada interval terukur | Kemajuan mengikuti multiplier CONTENT; Tinggi menahan tanpa memusnahkan bahan |
| T42 | Tutup dapur saat memasak; tunggu di dunia; buka lagi | Job tidak maju saat tertutup; tracker menyebut dijeda; dapat melanjutkan |
| T43 | Selesaikan output lalu makan satu porsi | Jumlah turun sekali, meal_used benar, centang tetap, penutup muncul sekali |
| T44 | Bagikan hidangan dari tas/peti, batalkan konfirmasi dan spam konfirmasi | Batal tidak mengonsumsi; berhasil memakai satu; tidak ada duplikasi respons/hadiah |
| T45 | Lewati NPC/catatan, panen; kemudian baca catatan/dialog ulang | Sumber tidak terkunci; isi/petunjuk tetap dapat diakses dan tercatat |
| T46 | Bandingkan snapshot lengkap sebelum save dan sesudah load | Semua entitas dinamis CONTENT terpulihkan, termasuk output/refund/flag, bukan posisi saja |
| T47 | Fixture save versi tidak cocok/ID item tak dikenal; coba load | Validasi menolak atau migrasi yang tertulis berjalan; dunia lama belum diganti sampai valid |
| T48 | Buat manual, lanjutkan hingga autosave lebih baru; Lanjutkan lalu pilih manual | Lanjutkan memilih revisi valid terbaru; manual lama tetap dapat dipilih secara eksplisit |
| T49 | Simulasikan gagal tulis/ruang tidak cukup; pilih Simpan dan Keluar | Pesan gagal; aplikasi tidak keluar seolah berhasil; checkpoint lama valid |
| T50 | Load snapshot job selesai/output_ready berulang, ambil output sekali | Tidak re-commit output atau menambah jumlah dibuat lagi; slot hasil tetap tunggal |
| T51 | Navigasi seluruh panel hanya keyboard dan kembali dari konfirmasi | Fokus terlihat, urutan logis, semua aksi inti dapat diakses, konflik Tab tidak mengunci |
| T52 | Ubah sensitivitas/FOV/audio/skala; restart dan load save lama | Pengaturan tetap yang terbaru, tidak ditimpa progres lama; slider benar-benar bekerja |
| T53 | Buka menu keluar/Game Baru dengan progres belum disimpan; uji semua pilihan | Batal mempertahankan keadaan; penghapusan/penimpaan hanya sesudah pilihan eksplisit |
| T54 | Ambil cepat beberapa item dan tahan aksi gagal | Notifikasi tergabung/terbatas, pesan tidak menutup prompt atau merebut kamera |
| T55 | Lihat tanaman, bahan, alat dan sumber pada jarak interaksi/beragam latar | Siluet berbeda, teks/ikon terbaca, status bukan warna saja; tidak ada aset hilang |
| T56 | Jalankan rute standar dan area terpadat pada perangkat tercatat | Catatan performa/frame time tersedia; hasil tidak digeneralisasi ke perangkat lain |
| T57 | Jalankan build pada akun/lingkungan tanpa editor di path mengandung spasi | Game dan aset ditemukan, save di direktori aplikasi yang dapat ditulis |
| T58 | Folder instalasi read-only; game baru/save/load di lokasi data pengguna | Tidak mencoba menyimpan ke folder sumber/instalasi; gagal data pengguna ditangani jelas |
| T59 | Instal, buka, simpan, uninstall dan instal ulang sesuai kebijakan | Shortcut/path benar; kebijakan penyimpanan save jelas dan tidak terhapus tanpa pilihan |
| T60 | Periksa paket distribusi dan atribusi terhadap daftar aset/dependency | Versi, README, lisensi dan sumber yang diperlukan lengkap; tidak ada secret/cache/save pribadi |

## 5. Matriks persyaratan → pengujian

| Persyaratan PRD | Kasus utama |
| --- | --- |
| FR01–FR02 gerak/interaksi | T18, T24–T28 |
| FR03–FR04 buku/quest | T01–T03, T11, T31 |
| FR05–FR06 pickup/inventaris | T04–T05, T29–T30 |
| FR07–FR10 persiapan/tanam/pupuk/air | T06–T08, T32–T33 |
| FR11 tumbuh/panen | T05, T34–T36 |
| FR12 memasak | T10–T15, T40–T42, T50 |
| FR13 penyelesaian/pemakaian | T19, T43–T44 |
| FR14 dialog/catatan | T28, T45 |
| FR15 save/load | T14, T16–T17, T22, T46–T50 |
| FR16 pause/pengaturan | T18, T21, T28, T51–T53 |
| FR17 pemulihan | T09, T37–T40 |
| FR18 tekanan event | EV-T01–EV-T12, setelah P0 |
| FR19 manfaat lintas resep | Uji khusus setelah resep P1 ditetapkan; bukan klaim P0 |
| FR20 akhir buku | Uji khusus setelah jumlah resep/ending P2 ditetapkan; bukan klaim P0 |
| FR21 UI nyaman | T21, T51–T55, playtest |
| FR22 distribusi | T20, T57–T60 |
| FR23 error jujur | T05, T10, T17, T30, T47, T49 |
| FR24 pelaporan agent | DOC-T01–DOC-T08 dan audit arsip setiap task |

FR19/FR20 tidak menjadi tes kosong: sebelum implementasi tahap terkait, task desain harus menetapkan data resep/ending dan expected hasil. Tidak mengarang konten final sekarang untuk menampilkan tanda lengkap palsu.

## 6. Playtest satu perjalanan

Instruksi awal penguji: “Buat satu masakan dari buku. Gunakan petunjuk di dalam game. Setelah jadi, makan atau bagikan, lalu simpan dan lanjutkan lagi.” Berikan kontrol dasar, lalu amati tanpa membimbing kecuali penguji benar-benar terhambat.

Catat urutan lokasi, lama tiap tahap, jumlah bantuan, titik salah paham, menu yang dibuka tanpa perlu, kejadian salah tombol, waktu menunggu tanaman dan rasa nyaman kamera. Tanyakan apa tujuan utama, kenapa tanaman berhenti bila terjadi, dari mana bahan diperoleh dan kapan resep dinyatakan selesai.

Sasaran awal durasi 10–15 menit. Jika terlalu cepat/lama, identifikasi penyebab sebelum mengubah timer. Jika kebingungan berasal dari UI/rute, perbaiki itu; jangan menyelesaikan dengan menambah panel tutorial panjang. Lakukan lagi setelah perubahan yang relevan, bukan mengulang tes tanpa alasan.

Jalankan satu playthrough dari profil bersih dan satu dari checkpoint tengah. P0 gameplay diterima jika seluruh tes kritis lulus, loop selesai, dan tidak ada kebutuhan bantuan berulang untuk tindakan dasar. Jumlah penguji dan temuan dilaporkan apa adanya.

## 7. Pengujian event Karhutla — sesudah P0

Rincian mekanik dan angka bersifat USULAN BARU sampai EV-001. Semua kasus berikut juga BELUM DIJALANKAN.

| ID | Langkah | Expected |
| --- | --- | --- |
| EV-T01 | Aktifkan tanpa prasyarat/lalu dengan prasyarat lengkap | Ditolak jelas atau diterapkan utuh; checkpoint pra-event valid |
| EV-T02 | Lihat judul, buku dan HUD ketika mulai | Format nama game + judul event; bukan chapter; tracker tetap ringkas |
| EV-T03 | Pergi ke jalur kebun terdampak | Api benar-benar aktif, akses berubah, rute pos air tersedia |
| EV-T04 | Respons titik api lewat stasiun; spam/putus aksi | Biaya/intensitas commit sekali, aksi batal tidak menciptakan suplai |
| EV-T05 | Kosongkan suplai event | Isi ulang deterministik dapat dijangkau; penyiram P0 tidak berubah jadi alat universal |
| EV-T06 | Biarkan perkembangan lokal berjalan | Tidak melewati batas desain/rumah aman; jalur recovery tetap ada |
| EV-T07 | Pause/buku/tas/dialog/hilang fokus saat event | Seluruh timer event berhenti; dapur aktif mengikuti aturan waktu yang tertulis |
| EV-T08 | Save/load pada warning, active, contained dan recovery | Fase, api, suplai, akses dan intervensi pulih; tidak mengulang aktivasi/reward |
| EV-T09 | Lakukan perlindungan air/mulsa | Akibat sesuai angka CONTENT; tidak menyatakan air/biomassa tercemar otomatis aman |
| EV-T10 | Buka koridor, panen tanaman yang tersisa, masak dan berbagi setelah aktivasi | Event memakai pencapaian pascaaktivasi, tidak otomatis selesai dari centang P0 lama |
| EV-T11 | Selesaikan event, muat lagi dan buka calon event berikut | Jejak map tetap, idempotensi terjaga, event tidak tumpang tindih tanpa aturan |
| EV-T12 | Bandingkan performa/visibility dan loop dasar sebelum/sesudah event | Api terbaca dan efek terkendali; rumah, petak, save dan kontrol P0 tidak rusak |

## 8. Audit dokumentasi sebelum penyerahan

| ID | Pemeriksaan | Expected |
| --- | --- | --- |
| DOC-T01 | Daftar file terhadap README/struktur | Seluruh file yang dijanjikan ada, tidak ada rujukan aktif ke file lama yang tidak disertakan |
| DOC-T02 | Resolusi tautan relatif Markdown dan SVG | Semua target ada dan berada di paket; tidak memakai path scratch absolut |
| DOC-T03 | Identitas dan keputusan | Godot/GDScript/VS Code/GitHub, first person, visual, resep dan status no-code konsisten |
| DOC-T04 | Data/kontrak | ID, bahan, petak, kontrol, waktu, memasak dan save saling cocok; default dipisah dari keputusan final |
| DOC-T05 | Tugas–persyaratan–tes | Task punya dependensi/kriteria; FR tercakup, kasus T/EV-T yang dirujuk benar-benar didefinisikan |
| DOC-T06 | Status–arsip | Daftar selesai benar, laporan ada, status terakhir singkat, tidak mengklaim gameplay diuji |
| DOC-T07 | Isi/format | Tidak ada bagian sengaja kosong, elipsis pemotongan, pagar kode tidak seimbang, nama file berbahaya atau tautan rusak |
| DOC-T08 | Paket ZIP dan wireframe | ZIP dapat dibaca/diekstrak, byte file cocok, SVG valid dan layout diperiksa secara visual |

Hasil nyata audit berada pada [CONSISTENCY_CHECK](CONSISTENCY_CHECK.md), dengan penjabaran task di [laporan DOC-001](completed_tasks/001-paket-dokumentasi-v0-2.md).

## 9. Pencatatan hasil dan penutupan

Gunakan laporan task selesai sebagai tempat hasil tes yang terkait. Untuk batch QA besar, lampiran hasil dapat dibuat dan ditautkan dari laporan. Catat tiap kasus: LULUS/GAGAL/BELUM DIJALANKAN/TIDAK BERLAKU disertai alasan; jangan memakai TIDAK BERLAKU untuk menutupi fitur wajib yang belum ada.

Setelah masalah diperbaiki, jalankan reproduksi dan tes pada sistem yang berhubungan. Tes lebih luas dijalankan jika perubahan baru menimbulkan risiko lintas sistem. PROJECT_STATUS hanya menyimpan kesimpulan terakhir dan tautan laporan, bukan seluruh log 60 kasus.
