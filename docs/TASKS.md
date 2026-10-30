# Daftar Tugas dan Gerbang Penyelesaian

**Versi:** 0.2 · **Tanggal:** 27 Oktober 2026  
**Status nyata:** [PROJECT_STATUS](PROJECT_STATUS.md). **Aturan kerja:** [AGENTS](../AGENTS.md). **Pengujian:** [TEST_PLAN](TEST_PLAN.md).

## 1. Cara memakai daftar

Status: **BELUM DIMULAI**, **DIKERJAKAN**, **TERHAMBAT**, **SELESAI**, **BACKLOG**. SELESAI berarti kriteria task sudah dibuktikan dan arsip/status diperbarui. Kode ditulis tanpa diuji tidak memenuhi task gameplay. Saat sesi coding diotorisasi, mulai SETUP-001; jangan menganggap tabel ini sebagai perintah mengeksekusi seluruh coding sekarang.

Task berurutan berdasarkan dependensi, bukan estimasi hari. Pemeriksaan regresi lokal selalu dilakukan pada task terkait. Jika task perlu dipecah, beri ID turunan yang stabil, kriteria sendiri dan satu laporan tiap task selesai; jangan mengganti ID lama sehingga tautan rusak.

## 2. Register pelaksanaan

| ID | Pekerjaan | Dependensi | Status awal | Laporan |
| --- | --- | --- | --- | --- |
| DOC-001 | Paket dokumen v0.2, wireframe dan audit hubungan antarfile | Diskusi terbaru | SELESAI — dokumentasi saja | [001](completed_tasks/001-paket-dokumentasi-v0-2.md) |
| SETUP-001 | Setup Godot, versi, renderer, struktur dan checkpoint lokal | DOC-001; instruksi memulai coding | SELESAI | [002](completed_tasks/002-setup-proyek-godot.md) |
| LVL-001 | Graybox map, rumah, spawn dan recovery | SETUP-001 | SELESAI | [003](completed_tasks/003-graybox-map-rumah-spawn-recovery.md) |
| PLY-001 | Gerak/pandang first person dan collision | LVL-001 | SELESAI | [004](completed_tasks/004-kendali-first-person-player.md) |
| REBUILD-001 | Audit dan refinement fondasi SETUP-001, LVL-001, PLY-001 dengan skill gamedev | PLY-001; instruksi rebuild pengguna | SELESAI | [005](completed_tasks/005-rebuild-refinement-skills-setup-lvl-ply.md) |
| INT-001 | Target interaksi, prompt dan konteks input | PLY-001, REBUILD-001 | SELESAI | [006](completed_tasks/006-target-interaksi-prompt-konteks-input.md) |
| INV-001 | Definisi item, tas/peti dan transaksi | INT-001 | SELESAI | [007](completed_tasks/007-data-item-inventaris-tas-peti-transfer.md) |
| BOOK-001 | Buku, pelacakan dan hitungan bahan | INV-001 | SELESAI | [008](completed_tasks/008-buku-resep-tracker-hud-stok-bersama.md) |
| GARD-001 | Persiapan petak, benih dan perawatan area | INV-001, BOOK-001 | SELESAI | [009](completed_tasks/009-persiapan-petak-benih-perawatan-kebun.md) |
| GARD-002 | Pertumbuhan, tahap, panen dan benih kembali | GARD-001 | SELESAI | [010](completed_tasks/010-pertumbuhan-bayam-4-tahap-pemanenan-atomik.md) |
| WORLD-001 | Jagung/temu kunci, cadangan, kalender dan istirahat | GARD-002 | SELESAI | [011](completed_tasks/011-sumber-pemulihan-jagung-temu-kunci-air-cadangan-istirahat.md) |
| COOK-001 | Validasi, reservasi, persiapan dan pembatalan | WORLD-001, BOOK-001 | SELESAI | [012](completed_tasks/012-validasi-reservasi-persiapan-pembatalan-dapur.md) |
| COOK-002 | Panas, output, progres buku dan penggunaan hidangan | COOK-001 | SELESAI | [013](completed_tasks/013-kontrol-panas-output-makan-hidangan.md) |
| SOC-001 | Dialog tetangga, berbagi dan catatan lingkungan | COOK-002 | SELESAI | [014](completed_tasks/014-interaksi-sosial-warga-dialog-berbagi-hidangan.md) |
| SAVE-001 | Checkpoint manual/auto, recovery dan load lengkap | SOC-001 | SELESAI | [015](completed_tasks/015-persistensi-lengkap-save-load-slot-backup.md) |
| UI-001 | Pause, pengaturan, aksesibilitas dan alur error | SAVE-001 | SELESAI | [016](completed_tasks/016-kenyamanan-terpadu-menu-pause-pengaturan-aksesibilitas.md) |
| ART-001 | Visual/audio dasar yang konsisten | UI-001 | SELESAI | [017](completed_tasks/017-identitas-visual-audio-dasar-konsisten.md) |
| QA-001 | Playthrough, usability dan regresi P0 gameplay | ART-001 | SELESAI | [018](completed_tasks/018-playthrough-penerimaan-p0-gameplay-regresi-akhir.md) |
| PLAN-001 | Perencanaan upgrade visual, dunia chunk, NPC bergerak dan goal 3 resep (usulan; belum mengubah dokumen sumber) | QA-001 | SELESAI — perencanaan saja | [019](completed_tasks/019-perencanaan-upgrade-kampung-hidup.md) |
| DEMO-001 | Menjalankan game dan menelusuri demonstrasi playable P0 | QA-001 | DIKERJAKAN — harness lulus; kontrol desktop eksternal belum tervalidasi | Belum ada |
| DIST-001 | Ekspor desktop mandiri dan uji offline | QA-001 | BELUM DIMULAI | Belum ada |
| DIST-002 | Installer, uninstall, lisensi dan panduan distribusi | DIST-001 | BELUM DIMULAI | Belum ada |

Urutan SAVE-001 mengintegrasikan seluruh keadaan setelah tersedia. Sejak INV-001, state dan transaksi harus dirancang dapat disimpan; jangan baru memikirkan persistensi setelah semua fitur selesai. Pengaturan sementara juga harus benar-benar bekerja sebelum disebut tersedia; UI-001 mengintegrasikan dan menguji keseluruhannya.

## 3. Spesifikasi task P0

### SETUP-001 — Proyek yang dapat dibuka

Baca README, PRD, AGENTS. Verifikasi rilis stabil saat setup, kunci nomor versi persis, pastikan GDScript dan target desktop, pilih renderer berdasarkan uji pada perangkat yang tersedia. Catat spesifikasi bila sudah diketahui tanpa mengarang minimum. Buat struktur minimal, main scene awal dan aturan file yang masuk Git. Tidak perlu membuat GitHub/push jika belum diotorisasi.

Selesai bila proyek dapat dibuka dan dijalankan di engine tanpa error penghambat, versi/renderer/main scene/cara run tertulis pada README, dan checkpoint sumber tersedia sesuai kondisi. Uji T23 baseline dan T24 smoke run. Belum berarti build distribusi selesai.

### LVL-001 — Area dasar dan spawn

Bangun graybox rumah, pekarangan, jalan dan lokasi penting sesuai LEVEL_DESIGN; gunakan ID stabil. Pasang spawn, collision lingkungan dan recovery. Sediakan jalur calon bahan tanpa memasang gameplay penuh.

Selesai bila ruang/skala dapat diperiksa, spawn tidak berimpit collision, lokasi penting mempunyai ruang interaksi, jalur tidak membutuhkan lompat presisi, dan posisi aman valid. T24/T25; verifikasi gerak penuh diulang pada PLY-001.

### PLY-001 — Kendali first person

Implementasikan gerak, pandang, batas vertikal dan collision. Tidak perlu tubuh penuh/sprint/jongkok. Head bob default mati. Catat parameter gerak dalam konfigurasi yang mudah diubah.

Selesai bila rute dapat dijelajahi tanpa menembus rumah/pagar, framerate berbeda tidak mengubah jarak gerak secara salah, dan recovery tidak menggandakan progres. T18/T25/T26. Belum klaim nyaman untuk semua pemain.

### INT-001 — Interaksi dan konteks

Satu target arah pandang, jangkauan dan occlusion benar. E menampilkan/melakukan satu tindakan. Konteks dunia/panel/pause melepas mouse dan mencegah input bocor. Gunakan objek contoh yang tidak menghasilkan item sebelum sistem inventaris siap.

Selesai bila objek di balik dinding tidak terpilih, prompt hilang saat keluar jangkauan, panel dapat ditutup, dan input yang sama tidak mengambil/memakai alat ketika menu ditutup. T18/T27/T28.

### INV-001 — Data item dan inventaris

Bangun definisi CONTENT, tas/peti, pickup paket awal dan transfer utuh. Alat tetap di luar slot. Tambah tes bermakna untuk kapasitas, tumpukan dan batch multi-item.

Selesai bila angka awal cocok, pickup sekali, transfer tidak duplikasi/hilang, penuh memberi alasan, dan seluruh hasil panen dapat diperiksa kapasitasnya lewat fungsi yang sama. T04/T05/T29/T30. UI boleh sederhana tetapi nama/jumlah harus terlihat.

### BOOK-001 — Buku dan tracker

Satu resep tersedia, lacak/berhenti, petunjuk sumber, catatan dan progres yang terpisah. Tas + peti bebas menjadi sumber ketersediaan bersama dapur. Hilangkan kartu kosong.

Selesai bila bahan sebelum melacak dihitung, perpindahan tas–peti tidak mengubah total, cukup bahan bukan selesai, dan stop tracking tidak menghapus item. T01/T02/T03/T11/T31.

### GARD-001 — Persiapan dan perawatan area

Bangun gembur, pembenah, penanaman per titik, pemupukan/air per petak, akses alat dan isi ulang. Semua aksi tahan commit sekali dan batal tanpa biaya.

Selesai bila syarat dan biaya CONTENT benar, satu biaya memengaruhi seluruh petak, titik invalid ditolak, pemupukan/penyiraman berlebih tidak boros, dan seluruh prompt terbaca. T06/T07/T08/T32/T33.

### GARD-002 — Tumbuh dan panen

Kemajuan berbasis waktu simulasi, empat tahap, pause kekurangan, siap panen bertahan, hasil bayam+benih, nutrisi berkurang hanya panen berhasil.

Selesai bila tiga titik memenuhi resep, gagal muat tidak mengosongkan titik atau mengurangi nutrisi, dan panen berulang pada sumber yang sama aman. T05/T34/T35/T36.

### WORLD-001 — Sumber dan pemulihan

Pasang jagung, temu kunci, isi ulang air, cadangan dan istirahat. Terapkan kalender/resets tanpa mensimulasikan kerugian tanaman ketika melompat hari. Sumber inti tidak tergantung dialog.

Selesai bila tiap sumber memberi hasil benar sekali per hari, cadangan tidak dapat diambil saat stok masih ada, istirahat memulihkan sumber tanpa mengubah tanaman, dan reset tidak tampak mendadak di depan mata. T09/T37/T38/T39. Laporan [011](completed_tasks/011-sumber-pemulihan-jagung-temu-kunci-air-cadangan-istirahat.md).

### COOK-001 — Reservasi dan persiapan

Bangun satu job ID stabil, validasi bahan lintas tas/peti, tahan persiapan, pembatalan dan pengembalian aman. Slot hasil dan pengembalian berbeda.

Selesai bila bahan kurang tidak termutasi, spam mulai tidak menggandakan job, batal sebelum pemasakan mengembalikan tepat jumlah semula, termasuk ketika kontainer asal penuh. T10/T11/T12/T13/T40. Laporan [012](completed_tasks/012-validasi-reservasi-persiapan-pembatalan-dapur.md).

### COOK-002 — Masak dan penggunaan

Implementasikan kontrol panas, job dijeda saat panel ditutup, output sekali, centang dan jumlah dibuat, ambil hasil serta makan. Jangan menambahkan skor/kerusakan bahan.

Selesai bila tiga panas memberi efek CONTENT, job bisa dilanjutkan, slot hasil mempertahankan hidangan saat penuh, resep tidak centang sebelum output dan mengulang resep aman. T12/T15/T19/T41/T42. Laporan [013](completed_tasks/013-kontrol-panas-output-makan-hidangan.md).

### SOC-001 — Warga dan penutup

Pasang dialog, petunjuk, catatan berulang dan berbagi hidangan dengan konfirmasi. Dialog tidak mengunci sumber. Penutup P0 setelah cooked + meal_used.

Selesai bila makan/berbagi sama-sama menutup pengalaman, satu porsi dikonsumsi tepat sekali, pemain tetap bisa melanjutkan, dan catatan dapat dibaca lagi. T43/T44/T45. Laporan [014](completed_tasks/014-interaksi-sosial-warga-dialog-berbagi-hidangan.md).

### SAVE-001 — Persistensi lengkap

Integrasikan envelope/version, manual/auto/cadangan, seluruh state, job/reservasi/output/refund, validasi sebelum swap dunia, serta pengaturan terpisah. Tangani data rusak, gagal tulis, interrupted write dan posisi invalid.

Selesai bila tes T14/T16/T17/T22/T46/T47/T48/T49/T50 lulus dengan bukti. Jangan menutup task jika hanya posisi yang dipulihkan atau belum pernah menutup dan membuka aplikasi. Laporan [015](completed_tasks/015-persistensi-lengkap-save-load-slot-backup.md).

### UI-001 — Kenyamanan terpadu

Bangun menu awal/pause/pengaturan, teks error, konfirmasi keluar/baru, fokus, skala UI, subtitle dan notifikasi. Terapkan UI_UX secara menyeluruh; kontrol yang belum ada tidak ditampilkan seolah aktif.

Selesai bila T18/T21/T28/T51/T52/T53/T54 lulus, termasuk layar kecil dan skala besar. Pengaturan benar-benar mengubah perilaku yang ditunjuk dan tersimpan. Laporan [016](completed_tasks/016-kenyamanan-terpadu-menu-pause-pengaturan-aksesibilitas.md).

### ART-001 — Identitas visual/audio dasar

Ganti placeholder secukupnya agar tanaman/item/rumah terbaca, pencahayaan hangat, material konsisten dan bunyi aksi penting tersedia. Catat semua asal/lisensi aset. Tidak menambahkan efek berat demi meniru screenshot referensi.

Selesai bila sumber wajib dapat dikenali tanpa ikon saja, teks terbaca pada berbagai latar, tidak ada aset hilang, dan uji rute/performa awal dicatat. T55/T56; masalah performa yang belum terselesaikan harus tampak di status. Laporan [017](completed_tasks/017-identitas-visual-audio-dasar-konsisten.md).

### QA-001 — Penerimaan P0 gameplay

Jalankan seluruh tes P0 yang relevan pada build terkini dan satu playthrough baru serta lanjutan. Lakukan observasi pemain baru sesuai TEST_PLAN. Perbaiki penghambat sebelum menandai selesai.

Selesai bila tidak ada kehilangan/duplikasi, crash/softlock atau input menghalangi, loop lengkap berhasil, keterbatasan yang tersisa disampaikan dan hasil uji beridentitas. Ini gerbang gameplay, bukan instalasi/distribusi. Laporan [018](completed_tasks/018-playthrough-penerimaan-p0-gameplay-regresi-akhir.md).

### DIST-001 — Build desktop mandiri

Ekspor untuk target OS yang telah dikonfirmasi. Pastikan aset/dependency ikut dan save ke direktori data aplikasi, bukan folder sumber. Uji tanpa engine, offline, path yang mengandung spasi dan hak tulis terbatas pada folder instalasi.

Selesai bila T20/T57/T58 lulus dan README memberi langkah run/export aktual. Simpan source dan daftar dependency yang bisa mereproduksi build.

### DIST-002 — Installer dan penyerahan

Pilih kemasan installer sesuai target yang sudah disetujui, sertakan pemberitahuan lisensi, petunjuk instal/uninstall, versi build dan batas yang diketahui. Jangan menghapus save pengguna saat uninstall tanpa pilihan jelas.

Selesai bila T59/T60 lulus, instalasi dan pembukaan bersih berhasil, uninstall/upgrade sesuai kebijakan save, dan petunjuk tervalidasi. Ini gerbang distribusi P0.

## 4. Jalur event tematik sesudah P0

Ide event dan format judul sudah menjadi arah desain; rincian pada EVENT_DESIGN masih USULAN BARU. Seluruh task di bawah belum dimulai dan tidak bagian sesi dokumentasi sekarang. Tidak ada urutan chapter.

| ID | Tugas | Dependensi | Kriteria selesai | Status |
| --- | --- | --- | --- | --- |
| EV-001 | Review dan kunci rancangan Karhutla untuk implementasi | QA-001; instruksi melanjutkan event | Batas area, alur, angka, tujuan, sains dan perbedaan terhadap P0 tercatat | BACKLOG |
| EV-002 | State event, aktivasi dan perubahan map | EV-001, SAVE-001 | Aktivasi utuh, prasyarat benar, rumah aman, snapshot pra-event, akses sumber berubah | BACKLOG |
| EV-003 | Api nyata dan respons lokal | EV-002 | Titik api berubah, suplai dapat pulih, koridor terbuka setelah syarat; efek terbatas | BACKLOG |
| EV-004 | Perlindungan air dan pemulihan sederhana | EV-003 | Tindakan sebab-akibat jelas, lahan hangus tidak instan jadi sumber pangan | BACKLOG |
| EV-005 | Tracker, buku, resep dan save event | EV-004 | Satu objective dekat, progres event terpisah dari centang P0, load idempotent | BACKLOG |
| EV-QA-001 | Playthrough dan regresi event | EV-005 | EV-T01–EV-T12 lulus, loop P0 tidak rusak dan performa event dicatat | BACKLOG |

## 5. Backlog produk lain

| Ide | Manfaat yang perlu dibuktikan | Batas sebelum dikerjakan |
| --- | --- | --- |
| Resep kedua/ketiga | Menguji variasi perolehan dan penggunaan ulang sumber | Definisi bahan/sumber/tahap lengkap; setelah loop P0 |
| Memancing | Jalur bahan berbeda dari kebun | Tidak menjadi minigame kompleks sebelum kebutuhan resep jelas |
| Pasar dan warga tambahan | Menguatkan dunia dan cerita | Tidak otomatis membuka beli bahan untuk melewati loop |
| Pengairan/mulsa permanen | Mengurangi rutinitas | Uji dampak, UI dan sains sederhana dahulu |
| Event tema lain | Memperlihatkan perubahan pada map yang dikenal | Satu event pertama terbukti; riset tema dan kompatibilitas state |
| Akhir buku/jamuan | Memberi penutup tujuan panjang | Jumlah resep inti dan cerita ditetapkan setelah P1 |

## 6. Aturan pembaruan

Setelah task selesai, isi laporan bernomor, ubah status pada tabel, tautkan laporan dan perbarui PROJECT_STATUS. Jika terhambat, tulis alasan/bukti yang belum tersedia pada status terakhir tanpa memasukkannya ke daftar selesai. Laporan lama tidak dihapus saat ada regresi; buat task perbaikan yang merujuk asalnya.
