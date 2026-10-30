# UI, UX, Kontrol dan Wireframe

**Versi:** 0.3 · **Tanggal:** 30 Oktober 2026  
**Prinsip wajib:** sederhana, nyaman, mudah dipahami. **Rujukan:** [PRD](../PRD.md), [CONTENT](CONTENT.md), [PROTOTYPE](PROTOTYPE.md).

## 1. Sasaran pengalaman

Pemain selalu memahami tujuan dekat, objek yang sedang dihadapi, dan tindakan yang bisa dilakukan. Informasi baru muncul ketika dibutuhkan. Kompleksitas keadaan internal tidak menjadi kewajiban membaca panel statistik.

Pada layar bermain normal, tampilkan hanya tracker atas kiri, crosshair, satu prompt, satu alat aktif dan notifikasi singkat bila ada. Jangan menambah health/hunger bar, uang, minimap, panel seluruh tugas, jam besar, empat meter tanah atau daftar shortcut permanen. Waktu hanya ditampilkan saat istirahat/muat jika berguna. Aturan ini tetap pada P0.5: dunia luas, warga bergerak dan tiga resep tidak menambah panel, jam, kompas atau minimap pada layar bermain.

## 2. Aturan tata letak dan keterbacaan

Angka layout/tipografi berikut adalah DEFAULT UJI desain antarmuka, bukan angka konten simulasi. Baseline rancangan 1920 × 1080, dengan pengujian juga pada 1280 × 720 dan skala 100%, 125%, 150%. Layout mengikuti anchor dan kontainer, bukan posisi piksel kaku. Safe margin sekitar 4% sisi layar. Target teks isi sekitar 22–26 px pada baseline, judul 30–40 px; ini DEFAULT UJI tipografi, diperbaiki bila penguji sulit membaca.

Panel memakai latar solid/nyaris solid agar teks terbaca di depan kebun, langit atau api. Warna tidak menjadi satu-satunya pembeda: tambahkan teks, ikon dan bentuk. Fokus keyboard terlihat. Tombol cukup besar untuk diklik tanpa ketelitian tinggi. Lebih baik memperpanjang panel/scroll daripada mengecilkan teks demi menampung semua informasi.

P0.5: gaya UI disatukan dalam satu Theme (VIS-004) sehingga warna, bentuk tombol, panel kertas dan font tidak tersebar sebagai override per layar; status tidak lagi dibedakan hanya oleh warna modulasi, tetapi juga oleh teks atau ikon centang. Nama node yang dicari tes dipertahankan saat refaktor.

Bahasa antarmuka Indonesia. Nama/jumlah tidak disembunyikan di tooltip. Hindari singkatan teknis, raw ID atau kategori angka tanah pada HUD. Teks panjang dapat dibaca langsung; animasi ketik tidak wajib.

## 3. Kontrol P0

| Input | Dunia | Panel/menu |
| --- | --- | --- |
| WASD | Bergerak | Tidak menggerakkan pemain |
| Mouse | Mengubah pandangan | Menggerakkan kursor |
| E | Satu interaksi kontekstual | Aktifkan aksi utama yang fokus jika aman; bukan meneruskan input ke dunia |
| Klik kiri/tahan | Pakai alat terpilih sesuai prompt | Klik tombol/tahan Siapkan |
| Klik kanan | Batalkan preview/aksi alat | Tidak wajib sebagai navigasi; Esc tersedia |
| 1–4 / roda mouse | Pilih alat tanah, benih, pupuk, penyiram | Tidak mengubah alat ketika mengetik/menavigasi menu |
| B | Buka buku | Tutup buku bila buku paling atas; tidak membuka panel bertumpuk |
| Tab | Buka tas | Tutup tas bila tas paling atas; pada panel lain mengikuti navigasi fokus |
| Esc | Buka pause | Tutup satu lapisan/konfirmasi; kembali ke panel induk dahulu |
| Tab/Shift+Tab | Tidak digunakan sebagai navigasi fokus dunia | Navigasi fokus pada panel selain tas; tas memakai tombol arah |
| Enter/Space | Tidak ada aksi dunia tambahan | Aktifkan tombol fokus, kecuali aksi berbahaya yang perlu konfirmasi |

Untuk menghindari konflik Tab, di panel tas Tab adalah tutup; panah atas/bawah memilih item, panah kiri/kanan berpindah kontainer, Enter memfokuskan aksi item, dan Esc kembali ke daftar atau menutup panel. Pada panel lain Tab/Shift+Tab menggerakkan fokus. Pola ditampilkan pada bantuan dan diuji konsisten. Rebinding penuh kandidat P1, bukan fitur yang pura-pura aktif P0.

Tidak ada sprint, jongkok atau lompat wajib P0. Navigasi level tidak memerlukan ketiganya. Tombol E tidak menggantikan klik kiri untuk semua alat; prompt selalu menjelaskan perbedaannya. Pemain tidak perlu memilih alat untuk membaca buku, mengambil bahan atau memanen.

## 4. Konteks input dan fokus

Satu panel aktivitas utama terbuka pada satu waktu. Konfirmasi berada di atas panel tersebut, lalu Esc menutup konfirmasi dulu. Saat panel terbuka, gerak/pandang/alat dunia berhenti dan mouse bebas. Saat kembali, kunci mouse setelah input penutup dilepas. Fokus kembali ke tombol yang terakhir dipilih, bukan hilang di luar layar.

Pause dapat dibuka dari dapur tanpa memulai proses kedua. Dapur aktif menjalankan pertumbuhan dan waktu memasak sesuai PROTOTYPE; buku/tas/dialog/pause menjeda. Label “Dijeda” muncul bila job masih aktif ketika panel dapur ditutup.

E pada objek memilih satu target valid sesuai arah pandang, jangkauan dan collision. Objek di balik dinding tidak dapat dipilih. Prompt menampilkan nama aksi, bukan daftar semua kemampuan. Urutan prioritas petak: panen pada tanaman siap yang dituju → tambah pembenah bila relevan → inspeksi. Alat aktif dapat menawarkan klik kiri untuk aksi lain tanpa menggantikan prompt E.

## 5. Wireframe konseptual dan sumber visual

[Wireframe SVG v0.2](wireframes/wireframes-v0.2.svg) dan [pratinjau PNG](wireframes/wireframes-v0.2.png) memuat enam layar: HUD, buku, kebun, tas/peti, dapur, pause/pengaturan. Ini layout rancangan, bukan aset game atau bukti implementasi. SVG berisi contoh keadaan, bukan salinan definisi angka runtime.

Tabel berikut menjelaskan hubungan ruang dan keadaan yang wajib dibangun. P0 hanya menampilkan kontrol yang benar-benar tersedia.

### UI01 — HUD eksplorasi

| Wilayah | Isi | Perilaku |
| --- | --- | --- |
| Atas kiri, lebar maksimal sekitar 30% | Nama resep + maksimal tiga kebutuhan | Angka membaca tas + stok rumah; label sumber ringkas |
| Tengah | Crosshair kecil | Tidak hilang hanya karena objek tidak dapat dipakai |
| Sedikit bawah tengah | Satu prompt E dan bila relevan satu prompt alat | Tidak menumpuk beberapa target |
| Bawah tengah | Nama alat aktif + ikon kecil + resource relevan | Alat lain muncul sementara ketika berganti, lalu diringkas |
| Bawah samping | Notifikasi satu pesan | Tidak menutup prompt atau mengambil fokus |

Pada P0.5 tracker tetap memuat satu resep yang dilacak; progres halaman distempel hanya ada di buku (UI09). Tanpa resep: “Buka buku [B] untuk memilih masakan.” Bahan lengkap: “Bahan lengkap. Kembali ke dapur.” Saat job aktif: nama resep dan “Masakan dijeda”/“Sedang memasak”, bukan bahan yang mendadak nol. Resep selesai: centang dan aksi ambil/gunakan hasil; menutup pelacakan diperbolehkan.

### UI02 — Buku resep

P0 menggunakan satu halaman utama tanpa sidebar kosong: judul di atas, ilustrasi/catatan pendek di kiri, tiga bahan dan petunjuk sumber di kanan, tombol Lacak di bawah. Daftar resep baru dibutuhkan ketika ada lebih dari satu resep yang benar-benar tersedia. Pada P0.5 ketiga resep warisan benar-benar tersedia: buku memuat satu halaman per resep dengan pemilih halaman sederhana, tetap satu resep dilacak (D17) dan tidak ada kartu kosong. Halaman 2 dan 3 hanya tampil penuh setelah ditemukan (UI09); layout tab atau tombol halaman perlu penyesuaian dari satu halaman P0.

| Keadaan | Tampilan/aksi |
| --- | --- |
| Tersedia belum dilacak | Tombol Lacak; bahan dihitung dari keadaan nyata |
| Sedang dilacak | Tombol Berhenti melacak; tidak menghapus progres |
| Bahan cukup | Label “Siap dimasak”, bukan “Selesai” |
| Sudah dimasak | Centang Selesai dan jumlah dibuat; boleh masak ulang |
| Catatan ditemukan | Tombol Catatan membuka teks yang dapat dibaca ulang |
| Sudah diserahkan (P0.5) | Stempel pada halaman; hidangan yang sama tidak dapat diserahkan dua kali |

Petunjuk sumber dapat diperluas pada baris bahan yang dipilih. Pemain tidak diwajibkan berpindah ke tiga halaman berbeda untuk mengetahui lokasi bahan. Detail angka tanah tidak berada di buku resep.

### UI03 — Kebun dan perawatan

Di dunia, sorot batas petak hanya saat inspeksi/alat relevan. Panel kecil menampilkan dua kebutuhan paling relevan terlebih dahulu; detail tambahan tersedia lewat E Periksa. Tidak perlu panel permanen empat meter.

| Keadaan | Prioritas informasi |
| --- | --- |
| Tanah awal | “Belum diolah” + alat tanah |
| Gembur belum dibenahi | “Tambah pembenah — 1” |
| Siap tanam | “Pilih benih dan titik kosong” |
| Kurang pupuk/air | “Perlu pupuk” atau “Kering”; jika keduanya kurang, tampil dua baris |
| Tumbuh sehat | “Tumbuh” dengan tahap visual; progress rinci opsional di inspeksi |
| Siap panen | “Siap panen — E”; seluruh hasil pada informasi ringkas |

Preview titik memakai tanda valid/tidak valid dan teks alasannya. Pupuk dan air menyebut “Seluruh petak” serta satu biaya sebelum aksi. Tidak ada empat konfirmasi terpisah per tanaman. Cukup kelembapan bukan berarti nutrisi otomatis cukup.

### UI04 — Tas dan penyimpanan

Saat Tab: tas dan detail item. Saat E pada peti: tas kiri, peti kanan; tombol Pindahkan pilihan dan Pindahkan semua di bawah. Setiap slot memperlihatkan nama pendek dan jumlah; memilih memperlihatkan nama lengkap serta kegunaan.

Teks kapasitas “3/12 slot” adalah jumlah slot terpakai, bukan jumlah unit. Arah transfer jelas lewat judul kontainer sumber/tujuan. Jika seluruh pilihan tidak muat, transaksi dibatalkan dan dijelaskan. Drag-and-drop boleh ditambahkan kelak, tidak dibutuhkan untuk P0.

Hidangan di tas memiliki tombol Makan dengan konfirmasi “Makan 1 porsi?”. Benih tidak memiliki tombol Gunakan yang memunculkan aksi tanpa target; pengguna diarahkan memilih alat benih di dunia. Alat tetap tidak muncul sebagai item buang.

### UI05 — Dapur

| Tahap | Konten utama | Aksi |
| --- | --- | --- |
| Idle | Nama resep, bahan bebas dan stasiun tersedia | Siapkan bila lengkap; alasan bila kurang |
| Preparing | Satu indikator tahan Siapkan | Siapkan, Batal, Tutup/jeda |
| Ready to heat | Ringkasan bahan sudah dicadangkan | Mulai memasak atau Batal |
| Cooking | Satu progress dan tiga pilihan panas | Rendah/Sedang/Tinggi; petunjuk Sedang jelas |
| Paused | Progress tersimpan dan status dijeda | Lanjutkan; tidak ada tombol mulai job baru |
| Output ready | Hidangan pada slot hasil + status buku selesai | Ambil; tas penuh tidak menghapus output |
| Refund pending | Daftar bahan pengembalian aman | Ambil ke tas/peti; tidak tercampur slot hasil |

Tidak ada QTE cepat, skor sempurna atau resep tersembunyi yang harus ditebak. Petunjuk panas bersebelahan dengan kendali. Saat bahan reserved, label menjadi “Bahan disiapkan”, bukan menampilkan kekurangan palsu. Menutup panel tidak mengulang tahap dari awal.

### UI06 — Pause, pengaturan dan menu awal

Menu utama: Game Baru, Lanjutkan (hanya jika checkpoint valid), Muat, Pengaturan, Keluar. Jika tidak ada save, Lanjutkan tidak tampak aktif. Game Baru yang menimpa profil memunculkan konfirmasi.

Pause: Lanjutkan, Simpan, Muat, Pengaturan, Kembali ke posisi aman, Menu utama, Keluar. Pengaturan ditempatkan pada halaman tersendiri, bukan seluruh slider pada layar pause pertama.

| Kelompok pengaturan | Isi P0 | Aturan |
| --- | --- | --- |
| Kendali | Sensitivitas mouse, FOV | Batas aman diuji; nilai tersimpan terpisah dari progres |
| Tampilan | Mode layar, resolusi, kualitas dasar, skala UI | Preview bisa dibatalkan; tidak mengklaim preset bekerja sebelum implementasi |
| Audio | Master, musik, efek | Preview bunyi singkat tanpa menutup menu |
| Kenyamanan | Subtitle/teks informasi, head bob | Head bob mati default; tanpa motion blur wajib |
| Bantuan | Tabel kontrol dan penjelasan simbol | Sesuai input yang benar-benar dibangun |

Keluar jika keadaan berubah sejak checkpoint terakhir: Simpan dan Keluar / Keluar tanpa Simpan / Batal. Jika save gagal, tetap di menu dan jelaskan. Muat memperingatkan kehilangan perubahan yang belum disimpan. Tombol kembali ke posisi aman tidak mereset dunia.

### UI07 — Dialog dan catatan

Panel bawah, nama tokoh, teks singkat, maksimal tiga pilihan terlihat sekaligus ditambah Tutup. Teks dapat dibaca ulang. Pilihan berbagi hanya aktif jika hidangan tersedia; teks menyebut jumlah dan sumber. E yang memulai dialog tidak sekaligus memilih pilihan pertama.

P0.5: dialog bersumber dari data per warga dengan struktur yang sama (CONTENT bagian 18) sehingga delapan warga memakai panel yang sama; tujuh dialog tetangga P0 tetap identik. Pada penerima dengan hidangan yang sesuai di tas atau peti muncul “Serahkan [nama] — 1” (jumlah dan sumber disebut); hidangan yang bukan untuk warga itu tidak dikonsumsi dan mendapat jawaban penolakan halus. Warga yang sedang tidur menjawab “sudah tidur” tanpa efek, dengan tawaran titip hidangan bila relevan. Lawan bicara menghadap pemain selama dialog.

Catatan lingkungan memakai panel sederhana dengan judul, isi dan Tutup; otomatis tercatat dalam buku setelah benar-benar diperiksa. Tidak ada cutscene yang memindahkan kamera secara paksa untuk catatan kecil.

### UI08 — Event tematik, usulan sesudah P0

Format identitas: **Nama Game: Karhutla**. Nama kerja tetap Buku Resep 2045; Karhutla adalah nama event, bukan nama utama atau chapter. Pada pengalaman bermain, label event muncul singkat ketika aktivasi, kemudian informasi menyatu dengan tracker resep.

Tracker hanya menampilkan satu kebutuhan situasional terdekat, misalnya “Akses kebun tertutup — periksa pos air”, dengan detail di buku. Jangan menambah dashboard bencana, feed berita langsung atau tiga meter sains. Event diperkenalkan pada satu panel konfirmasi dengan tujuan, perubahan wilayah dan kemampuan melanjutkan save. Rincian desain pada EVENT_DESIGN; seluruh UI event belum bagian implementasi P0.

### UI09 — Progres warisan dan layar penutup (P0.5, USULAN BARU)

Seluruhnya berada di buku dan tidak menambah HUD. Rincian teks ada di CONTENT bagian 18; perilaku di PROTOTYPE bagian 11.

| Elemen | Isi dan aturan |
| --- | --- |
| Sampul | “Halaman distempel n/3”; awalnya 0/3 dengan kalimat nyata bahwa dua lembar lain terselip di buku. Tidak ada persen, bar atau penghitung lain |
| Per halaman | Nama, bahan dengan angka dari aturan stok bebas yang sama dengan tracker, petunjuk sumber, catatan, penerima, tombol Lacak dan empat baris centang: Ditemukan, Bahan, Dimasak, Diserahkan |
| Stempel | Muncul setelah hidangan diserahkan kepada penerima |
| Layar penutup | Overlay modal satu kali setelah stempel ketiga: tiga stempel, tiga penerima, satu kalimat dari masing-masing, tombol Lanjutkan; tanpa skor, bintang atau waktu. Fokus kembali ke dunia dan input penutup tidak diteruskan sebagai aksi dunia |
| Wireframe | Wireframe v0.2 hanya memuat buku satu halaman; tampilan tiga halaman belum bergambar dan mengikuti teks ini, tidak sebaliknya |

### Navigasi dunia luas tanpa minimap (P0.5, USULAN)

Tidak ada minimap, kompas atau panah arah di HUD (D32). Pemain menemukan sumber dari petunjuk sumber di halaman buku (deskripsi arah dan landmark), dari petunjuk warga (mis. Dik Rini) dan dari isyarat lingkungan: jalan, pagar, papan, siluet gunung dan sungai. Pemuatan chunk berlangsung di latar tanpa indikator; teks singkat hanya muncul bila penahan muat (load, pemulihan) benar-benar terlihat oleh pemain dan hilang sendiri. Default ini dipertahankan sampai playtest T83 menunjukkan perlunya perubahan; perubahan itu keputusan pemilik.

## 6. Notifikasi, feedback dan bantuan

Notifikasi pickup singkat sekitar 2,5 detik, maksimum dua terlihat; pesan berulang digabung berdasarkan item. Pesan gagal yang sama diberi jeda agar menahan tombol tidak membanjiri layar. Kesalahan yang perlu tindakan penting tetap terbaca sampai dipahami atau panel ditutup.

Sukses memakai bunyi halus dan perubahan keadaan; tidak mengunci kamera. Error tidak hanya berbunyi: alasan tertulis harus tersedia. Pengingat tidak muncul setiap beberapa detik bila pemain sengaja menjelajah. Bantuan bertahap muncul pada penggunaan fitur pertama; dapat dibaca lagi di buku/bantuan.

Arah suara dan musik membantu suasana, tetapi informasi wajib tidak hanya disampaikan lewat audio. Api event juga tidak boleh hanya dibedakan melalui warna merah/hijau; ada label status dan bentuk efek.

## 7. Pengujian kenyamanan

Penguji baru diberi tujuan “Buat satu masakan dari buku” dan kontrol dasar, kemudian diamati. Catat apakah ia menemukan buku, memahami sumber, menyiapkan petak, memilih alat, mengenali kebutuhan, memasak dan menggunakan hasil. Catat bantuan lisan yang terpaksa diberikan, bukan menutupinya sebagai keberhasilan mandiri.

Pada P0.5 amati juga apakah pemain menemukan tiga sumber warisan tanpa minimap, apakah ia menemukan penerima pada titik temu, dan apakah halaman buku serta tombol Serahkan dipahami tanpa arahan (T83–T85). Jika bingung, perbaiki kata/penempatan/feedback terlebih dahulu sebelum menambah panel baru. Verifikasi teks panjang, skala besar, layar kecil, input keyboard, fokus setelah Esc, tas penuh dan save gagal. Nomor tes dan hasil yang diharapkan ada pada TEST_PLAN.

## 8. Riwayat perubahan

| Versi | Tanggal | Perubahan |
| --- | --- | --- |
| 0.2 | 27 Oktober 2026 | UI, kontrol dan wireframe P0 |
| 0.3 | 30 Oktober 2026 | SCOPE-001: Theme tunggal, buku tiga halaman, UI09 progres warisan dan layar penutup, dialog dan penyerahan warga, navigasi tanpa minimap, pengamatan P0.5; "tidak ada minimap" dan HUD ringkas tetap |
