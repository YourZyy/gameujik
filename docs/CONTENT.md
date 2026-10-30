# Data dan Konten Permainan Awal

**Versi:** 0.2 · **Tanggal:** 27 Oktober 2026  
**Acuan:** [PRD](../PRD.md), [Prototipe](PROTOTYPE.md), [UI/UX](UI_UX.md).

## 1. Status dan kepemilikan data

Dokumen ini adalah sumber tunggal ID, jumlah, waktu, kapasitas dan nilai gameplay P0. Seluruh nilai numerik di sini berlabel **DEFAULT UJI**: konkret untuk implementasi awal, belum hasil balancing atau benchmark. Jumlah bahan bukan takaran kuliner dan durasi tanaman bukan waktu biologis nyata.

Nama dapat berubah tanpa mengubah ID. ID menggunakan huruf kecil `snake_case`. Jangan memakai teks terjemahan sebagai kunci save. Definisi data runtime nantinya mengikuti tabel ini; perubahan angka memperbarui tabel terlebih dahulu/bersamaan dan dicatat pada laporan task.

## 2. Kamus item

Semua item bertumpuk maksimum **20 unit per slot**, termasuk hidangan. Tidak ada berat, durability atau kualitas item P0.

| ID | Nama tampil | Kategori | Pemakaian | Sumber |
| --- | --- | --- | --- | --- |
| `seed_bayam` | Benih bayam | Benih | 1 per titik tanam | Wadah awal, hasil panen, cadangan |
| `soil_compost` | Pembenah tanah | Perawatan | 1 untuk menyiapkan seluruh petak sekali | Wadah awal/cadangan |
| `fertilizer_basic` | Pupuk | Perawatan | 1 untuk seluruh petak ketika perlu | Wadah awal/cadangan |
| `ingredient_bayam` | Bayam | Bahan resep | 3 per masakan | Panen tanaman |
| `ingredient_jagung` | Jagung | Bahan resep | 1 per masakan | Sisa kebun keluarga |
| `ingredient_temu_kunci` | Temu kunci | Bahan resep | 1 per masakan | Tepi rumpun bambu |
| `dish_sayur_bening` | Sayur Bening Bayam dan Jagung | Hidangan | 1 untuk dimakan/dibagikan | Dapur |

Buku, catatan, kunci fasilitas, alat dan isi penyiram bukan item tas bertumpuk. Catatan tersimpan sebagai flag buku; empat alat tetap berada pada akses alat. Air dapur dan bahan bakar merupakan fasilitas stasiun P0, bukan slot inventaris atau angka ekonomi.

Tidak ada tombol buang barang P0. Barang yang dibutuhkan tidak dapat terhapus lewat klik salah. Pemulihan kapasitas dilakukan melalui penyimpanan, memasak, makan dan berbagi. Ragam item hanya tujuh jenis; tas dan peti bersama memberi ruang jauh di atas satu loop. Uji kapasitas ekstrem menggunakan fixture pengujian, bukan membanjiri pengalaman awal.

## 3. Inventaris, ketersediaan dan transaksi

| Parameter | Nilai DEFAULT UJI |
| --- | --- |
| Tas | 12 slot |
| Penyimpanan rumah | 12 slot |
| Tumpukan maksimum | 20 unit per slot, kelebihan membuka slot lain |
| Alat | 4 akses tetap, tidak mengisi slot tas |
| Slot hasil dapur | 1 hidangan batch; tidak dapat mulai job baru sebelum diambil |
| Kontainer reservasi/refund | Internal dan persisten; hanya untuk job/pengembalian aman, bukan tas ekstra biasa |

Ketersediaan bahan bebas untuk buku dan dapur = jumlah di tas + jumlah di peti rumah. Reservasi job, barang di sumber dunia, bibit tertanam dan slot hasil tidak dihitung. Tracker boleh membatasi angka tampil sampai kebutuhan (misalnya 3/3) sementara halaman detail menunjukkan total sebenarnya.

Urutan pengambilan bahan: tas lebih dahulu, kemudian peti; konsumsi slot dengan indeks terkecil dahulu. Simpan asal setiap reservasi untuk pengembalian. Seluruh bahan harus lolos pemeriksaan sebelum satu unit pun diambil. Resep tidak memakai barang yang sudah dicadangkan proses lain.

Pickup dan panen memeriksa kapasitas **seluruh hasil** terlebih dahulu. Panen bayam menghasilkan dua jenis item, sehingga satu slot kosong belum tentu cukup. Jika tidak muat, sumber/tanaman tetap utuh. Transfer pilihan memindahkan seluruh tumpukan terpilih; transfer semua memindahkan seluruh isi hanya jika tujuan dapat menampungnya. Bila tidak muat, tidak ada perubahan dan UI memberi alasan. Tidak ada transfer parsial diam-diam pada P0.

## 4. Resep pertama

| Properti | Nilai |
| --- | --- |
| ID | `recipe_sayur_bening_01` |
| Nama | Sayur Bening Bayam dan Jagung |
| Ketersediaan | Tersedia sejak game baru |
| Bahan | Bayam 3, jagung 1, temu kunci 1 |
| Stasiun | `station_kitchen_home` |
| Air/bahan bakar | Fasilitas rumah, selalu cukup pada P0; tidak dikonsumsi sebagai item |
| Persiapan | Tahan tombol Siapkan selama 4 detik; dapat dihentikan sementara |
| Pemasakan | 30 detik kemajuan efektif pada panas Sedang |
| Panas Rendah | Kemajuan ×0,5 |
| Panas Sedang | Kemajuan ×1 |
| Panas Tinggi | Kemajuan ×0; pesan “Kecilkan panas ke Sedang”; bahan tidak hangus |
| Pilihan panas awal | Rendah, agar pemain melihat petunjuk dan memilih |
| Hasil | 1 `dish_sayur_bening` pada slot hasil |
| Status selesai | Saat output berhasil dibuat, sekali per job |
| Buat ulang | Diperbolehkan; jumlah masakan bertambah, centang tetap satu |

Pembatalan tersedia hanya sebelum tahap pemasakan dimulai. Menutup panel ketika persiapan belum selesai menjeda; tidak membatalkan otomatis. Tahan Siapkan yang terputus mempertahankan progress persiapan. Setelah persiapan penuh, tombol **Mulai memasak** melakukan transisi; jangan langsung mulai dari input tahan yang sama. Setelah memasak dimulai, Esc menjeda job dan menutup panel; tidak mengembalikan bahan.

Catatan resep untuk pemain:

> “Bayam paling enak dipetik dekat waktu memasak. Jagung di kebun ujung jalan mungkin masih bisa dipanen. Temu kunci tumbuh di tepi bambu, dekat batu besar.”

Petunjuk sumber pada buku:

| Bahan | Teks petunjuk |
| --- | --- |
| Bayam | “Benih ada di wadah dekat alat. Siapkan petak di pekarangan, lalu tanam.” |
| Jagung | “Cari sisa kebun keluarga di ujung jalan, dekat pagar miring.” |
| Temu kunci | “Periksa tanaman di tepi rumpun bambu, dekat batu besar.” |

## 5. Wadah awal dan fasilitas

| ID dunia | Lokasi | Isi/keadaan awal | Perilaku |
| --- | --- | --- | --- |
| `container_starter` | Pekarangan dekat alat | Benih 4, pembenah 1, pupuk 1 | E mengambil paket sekaligus jika seluruhnya muat; sekali per game |
| `storage_home` | Rumah | Kosong | Penyimpanan dua arah dan sumber bahan dapur |
| `water_home` | Pekarangan | Tersedia | Isi penyiram sampai kapasitas penuh |
| `reserve_home` | Dekat wadah awal | Cadangan kontekstual | Memberi suplai hanya bila syarat pemulihan terpenuhi |
| `book_family` | Meja rumah | Dapat dibaca | Membuka buku; tidak hilang dari meja |
| `station_kitchen_home` | Dapur | Idle, hasil kosong | Satu job, satu output |
| `bed_home` | Rumah | Siap digunakan | Istirahat sampai awal hari berikutnya untuk memulihkan sumber |

Pada game baru tas kosong. Alat sudah dapat dipilih. Penyiram mulai kosong agar sumber air diperkenalkan, namun suplai air tidak habis. Buku B juga dapat dibuka sejak awal; meja hanya orientasi diegetik, bukan syarat tersembunyi membuka fitur.

## 6. Alat dan aksi

| Akses | ID | Nama | Aksi dan syarat |
| --- | --- | --- | --- |
| 1 | `tool_hoe` | Alat tanah | Tahan klik kiri 2 detik untuk menggemburkan petak belum diolah |
| 2 | `tool_seed` | Tanam benih | Klik kiri pada titik valid; biaya benih 1 |
| 3 | `tool_fertilizer` | Pupuk | Tahan klik kiri 1 detik pada petak yang perlu; biaya pupuk 1 |
| 4 | `tool_watering_can` | Penyiram | Tahan klik kiri 2 detik; satu transaksi area, biaya air 2 |

Pembenah dipakai lewat prompt **E Tambah pembenah — 1** ketika tanah sudah gembur tetapi belum siap. Tidak membutuhkan alat kelima. E memeriksa petak jika tidak ada aksi pembenah/panen yang lebih relevan. Memilih alat tidak memunculkan panel penuh secara otomatis.

Progres aksi dunia yang dibatalkan sebelum selesai tidak mengonsumsi sumber daya dan direset; pengecualian adalah progres persiapan dapur yang disimpan per job. Tahan tombol bukan konsumsi per frame. Saat aksi selesai, tombol harus dilepas sebelum aksi berikutnya dapat dimulai.

## 7. Petak, nutrisi dan kelembapan

| Parameter | Nilai DEFAULT UJI |
| --- | --- |
| ID petak | `plot_home_01` |
| Luas | 2 × 2 meter |
| Titik | 4, ID `slot_01` hingga `slot_04` |
| Awal | Belum diolah; pembenah belum ditambahkan; nutrisi 0; kelembapan 0 |
| Siap tanam | Sudah gembur dan pembenah ditambahkan |
| Pembenah | Sekali untuk petak; tidak habis setelah panen |
| Nutrisi valid | 0–100, “Perlu pupuk” bila <20, “Cukup” bila ≥20 |
| Pemupukan | Jika nutrisi <20, 1 pupuk mengatur nutrisi ke 100 |
| Biaya panen nutrisi | 5 per tanaman berhasil dipanen; minimum nilai 0 |
| Kelembapan valid | 0–100; “Kering” bila <30; “Lembap” bila ≥30 |
| Penyiraman | Jika kelembapan <60, aksi memakai 2 air dan mengatur ke 80 |
| Tidak perlu siram | Kelembapan ≥60; aksi ditolak tanpa biaya |
| Penguapan | Turun 0,1 per detik simulasi aktif, minimum 0 |
| Syarat tumbuh | Siap tanam, nutrisi ≥20, kelembapan ≥30 |

Ambang 60 adalah ambang **aksi siram**, bukan ambang pertumbuhan. Petak kelembapan 40 masih tumbuh, tetapi boleh disiram. UI pada rentang 30–59 menyebut “Lembap — boleh disiram”; tidak menyebut “Kering”. Tidak ada status terlalu basah P0 karena tidak ada cara mencapai nilai di atas 80; jangan menampilkan status sistem yang belum tersedia.

Siram/pupuk memengaruhi seluruh petak termasuk titik kosong. Biaya tidak dikalikan jumlah tanaman. Pupuk tidak berkurang per detik; nutrisi turun ketika panen berhasil. Memupuk ketika cukup atau memakai pembenah kedua kali tidak menghabiskan item.

## 8. Tanaman bayam

| Parameter | Nilai DEFAULT UJI |
| --- | --- |
| Definisi | `crop_bayam` |
| Biaya tanam | 1 `seed_bayam` |
| Lama tumbuh efektif | 180 detik |
| Tahap benih | Kemajuan 0 hingga <30 detik |
| Tahap tunas | 30 hingga <90 detik |
| Tahap tumbuh | 90 hingga <180 detik |
| Siap panen | ≥180 detik; kemajuan dikunci pada 180 |
| Hasil per titik | Bayam 1 dan benih bayam 1 |
| Saat dipanen | Titik kosong; nutrisi petak berkurang 5 |
| Kekurangan kebutuhan | Kemajuan berhenti; tidak mundur, tidak mati |

Tiga titik cukup untuk resep; titik keempat adalah kelonggaran eksplorasi. Tutorial tidak mewajibkan menanam empat titik jika kebutuhan sudah terpenuhi. Tiap tanaman punya kemajuan sendiri, tetapi kondisi perawatan dibaca dari petak yang sama. Tanaman siap panen tidak kehilangan kesiapan karena petak mengering.

## 9. Air, sumber bahan dan pemulihan

| Parameter | Nilai DEFAULT UJI |
| --- | --- |
| Kapasitas penyiram | 10 unit abstrak |
| Isi awal | 0 |
| Isi ulang | Tahan E 2 detik di `water_home`, sampai 10; tidak menghabiskan stok dunia |
| Jagung | `resource_jagung_01`, hasil 1 per panen |
| Temu kunci | `resource_temu_kunci_01`, hasil 1 per panen |
| Reset sumber liar | Dapat dipanen sekali per hari simulasi; kembali setelah pergantian hari saat tidak dilihat |
| Hari awal | Indeks 1, waktu aktif 0 detik |
| Satu hari prototipe | 720 detik simulasi aktif |
| Istirahat | Di ranjang, konfirmasi “Istirahat sampai besok”; pindah indeks hari berikutnya dan reset waktu aktif 0 |

P0 memakai pencahayaan sore yang stabil; pergantian indeks hari untuk sumber tidak menuntut siklus matahari/malam lengkap. Saat indeks hari berganti, sumber yang sudah dipanen ditandai boleh pulih. Pembaruan model dilakukan ketika di luar pandangan; istirahat memakai transisi layar sehingga pemulihan aman. Bahan wajib tidak hilang karena menolak dialog.

Istirahat adalah lompatan kalender untuk memulihkan sumber, **tidak menyimulasikan 720 detik pertumbuhan/penguapan sekaligus**. Kondisi petak dan kemajuan tanaman dipertahankan. Istirahat ditolak saat job dapur masih aktif; lanjutkan job atau batalkan bila masih di tahap persiapan. Output yang sudah selesai tidak menghalangi istirahat.

Cadangan benih: jika benih di tas + peti + pengembalian aman = 0 dan tidak ada tanaman hidup/siap panen, E pada cadangan menawarkan paket 4 benih. Tidak diberikan otomatis tanpa interaksi, dan tidak diberikan jika masih ada tanaman yang nanti menghasilkan benih.

Cadangan pembenah: 1 tersedia jika petak gembur tetapi belum diberi pembenah dan stok bebas/pengembalian = 0. Cadangan pupuk: 1 tersedia jika nutrisi <20 dan stok bebas/pengembalian = 0. Semua paket memeriksa kapasitas; gagal muat tidak menghabiskan hak cadangan. Isi awal yang belum diambil tidak dihitung sebagai stok milik pemain, tetapi prompt mengarahkan mengambil wadah awal dahulu. Cadangan baru aktif setelah wadah awal diambil.

## 10. Hidangan, akhir prototipe dan dialog

Makan mengonsumsi 1 hidangan, menampilkan “Hangat. Resep pertama berhasil dibuat.” dan menetapkan flag `meal_used`. Tidak ada hunger meter atau buff statistik wajib. Berbagi mengonsumsi 1 hidangan di tas atau peti rumah melalui dialog eksplisit dengan konfirmasi jumlah, menetapkan flag yang sama dan memunculkan respons warga. Mengonsumsi dari peti untuk berbagi diperbolehkan sebagai kemudahan P0; teks menyebut stok rumah bila relevan.

Resep selesai saat output dibuat. Penutup pengalaman P0 terjadi saat `recipe_completed` dan `meal_used` sama-sama benar. Jika hidangan belum diambil, buku tetap centang; prompt berikutnya adalah ambil hidangan, bukan buat ulang.

| ID dialog | Pemicu | Teks |
| --- | --- | --- |
| `npc_intro` | Pertama bicara | “Masih menyimpan buku itu? Coba lihat kebun di ujung jalan. Jagungnya belum semua habis.” |
| `npc_hint_bayam` | Pilih “Bayamnya dari mana?” | “Ada benih di dekat alat. Petaknya memang lama tidak dipakai. Gemburkan dulu, baru tambah pembenah.” |
| `npc_hint_kunci` | Pilih “Temu kunci?” | “Di tepi bambu, dekat batu besar. Daunnya lebih rendah dari rumpunnya.” |
| `npc_waiting` | Belum ada hidangan | “Tidak perlu buru-buru. Yang penting tahu apa yang masih bisa ditanam.” |
| `npc_offer` | Hidangan tersedia | Pilihan “Bagikan 1 porsi” dan “Nanti dulu” |
| `npc_received` | Berbagi berhasil | “Masih ingat rasanya. Besok, sisakan tempat buat menanam lagi.” |
| `npc_repeat` | Bicara setelah berbagi | “Kebun kecil juga perlu diteruskan. Jangan berhenti di satu panci.” |

Dialog dapat dibuka ulang; memilih keluar tidak mengunci sumber. Teks naratif DEFAULT UJI ini dapat diganti tanpa mengubah mekanik.

Catatan di sisa kebun (`note_garden_01`): “Pagar boleh miring. Jangan sampai lupa jalan pulang.” Setelah diperiksa, teks masuk bagian catatan buku. Papan satir opsional dekat jalan (`sign_food_01`): “Kawasan Pangan Masa Depan — Tahap Pemeliharaan”. Kedua elemen tidak diperlukan untuk memperoleh bahan.

## 11. Teks UI inti

| Konteks | Teks |
| --- | --- |
| Belum melacak | “Buka buku [B] untuk memilih masakan.” |
| Bahan cukup | “Bahan lengkap. Kembali ke dapur.” |
| Info sumber | “Termasuk stok rumah.” |
| Tas penuh | “Tas tidak cukup. Kosongkan slot atau simpan barang di rumah.” |
| Tujuan penuh | “Penyimpanan tidak cukup. Tidak ada barang yang dipindahkan.” |
| Tanah belum siap | “Gemburkan tanah dan tambahkan pembenah dahulu.” |
| Benih kurang | “Benih belum tersedia. Periksa wadah dekat alat.” |
| Kering | “Pertumbuhan berhenti sementara. Siram petak.” |
| Nutrisi kurang | “Pertumbuhan berhenti sementara. Tambahkan pupuk.” |
| Kondisi cukup | “Petak sudah cukup. Tidak ada bahan yang digunakan.” |
| Bahan dapur kurang | “Bahan belum lengkap. Buka buku untuk melihat sumbernya.” |
| Hasil tertahan | “Ambil hidangan sebelumnya dahulu.” |
| Job dijeda | “Masakan dijeda. Buka dapur untuk melanjutkan.” |
| Save berhasil | “Progres tersimpan.” |
| Save gagal | “Progres belum tersimpan. Coba lagi atau gunakan lokasi simpan yang dapat ditulis.” |
| Save tidak cocok | “Data simpan tidak cocok dengan versi ini. Pilih cadangan yang tersedia.” |
| Penutup P0 | “Satu resep selesai. Kebun ini baru dimulai.” |

Pesan gagal menyatakan keadaan sebenarnya. Jangan menampilkan “Progres tersimpan” sebelum penulisan/validasi berhasil.

## 12. Bentuk data yang harus didukung implementasi

| Entitas | Field konseptual wajib |
| --- | --- |
| Definisi item | ID, nama, kategori, batas tumpukan, ikon/visual |
| Definisi resep | ID, daftar bahan/jumlah, stasiun, tahap, aturan panas, output |
| Definisi tanaman | ID, benih, durasi/tahap, syarat, output |
| Player | Posisi aman, rotasi, alat aktif, isi penyiram |
| Container | ID tetap, daftar slot ID/jumlah |
| Plot | ID, gembur, pembenah, nutrisi, kelembapan, daftar titik |
| Crop | ID instance stabil, ID definisi, ID titik, progress, siap panen |
| Resource | ID dunia, hari terakhir dipanen, status visual/pending reset |
| CookingJob | ID unik, resep, state, reservasi dan asal, progress tahap, panas, output_committed |
| RecipeProgress | Ditemukan, selesai, jumlah dibuat; tracked_recipe terpisah |
| World | Indeks hari, waktu aktif, wadah awal diambil, flag catatan, flag dialog, meal_used |
| Save envelope | Versi skema, revisi checkpoint, waktu simpan, payload tervalidasi |
| Settings | Sensitivitas, FOV, skala UI, audio, subtitle, tampilan; terpisah dari progres |

Tidak ada kode runtime dalam dokumen ini. Nama field adalah kontrak rancangan, bukan API Godot yang sudah dibuat.

## 13. Parameter event Karhutla — USULAN BARU, bukan P0

Bagian ini satu-satunya sumber nilai numerik event awal. Seluruh angka perlu ditinjau pada EV-001 dan diuji setelah P0. Bukan prosedur atau takaran untuk menangani kebakaran nyata.

| Parameter | Default rancangan event |
| --- | --- |
| ID event | `event_karhutla_01` |
| Judul event | Karhutla |
| Judul kerja lengkap | Buku Resep 2045: Karhutla |
| Event aktif bersamaan | Maksimum 1 |
| Titik api interaktif | 3, ID `fire_edge_01` hingga `fire_edge_03` |
| Intensitas tiap titik | 2 unit abstrak awal |
| Aksi selang | Tahan 3 detik, biaya suplai 1, intensitas turun 1; commit sekali |
| Suplai pos air | Kapasitas 8; awal 0; isi ulang 3 detik ke kapasitas, setelah suplai tersambung |
| Penyambungan suplai | Interaksi kontekstual 3 detik, sekali, tanpa item tas tambahan |
| Spread P1 pertama | Tidak ada spread acak; ketiga titik ditentukan sejak awal |
| Koridor terkendali | Ketiga titik interaktif intensitas 0; rute ke tanaman jagung yang tidak terbakar dibuka |
| Perlindungan air | 1 penutup penampung + 1 pengalih limpasan, masing-masing aksi 3 detik; material sudah di pos |
| Petak pemulihan | 1, `recovery_edge_01`, nonpangan; inspeksi dan penutup, lalu tunggu 120 detik aktif sebelum status awal pemulihan |
| Mulsa contoh | 1 pemasangan pada petak aman; laju penguapan ×0,5 dari nilai dasar; tidak mengubah nutrisi/keamanan pangan |
| Timer saat pause/menu/app tertutup | Berhenti; dapur aktif mengikuti PROTOTYPE |
| Batas kegagalan | Tidak ada kematian atau kehancuran rumah pada rancangan pertama |
| Akhir lokal | Koridor terkendali, dua perlindungan air, pemulihan awal, serta masak dan makan/berbagi setelah aktivasi |

Tidak ada item baru wajib pada tas untuk event pertama; material respons berada pada stasiun kontekstual. Air event terpisah dari penyiram kebun. Tidak ada drop acak atau pembelian untuk mengisi ulang.

Saat aktivasi, simpan baseline jumlah masakan dibuat dan reset flag penggunaan hidangan khusus event. Event mensyaratkan setidaknya satu commit masakan baru setelah aktivasi, lalu satu aksi makan/berbagi setelah commit tersebut. Flag `meal_used` P0 yang lama tidak menutup event secara otomatis. Tidak perlu provenance tiap tumpukan pada rancangan ini: yang dibuktikan adalah urutan tindakan masak baru lalu penggunaan hidangan, bukan asal fisik unit yang dipakai.

Mulsa hanya diterapkan pada petak aman, bukan disebar pada titik api aktif. Status pemulihan awal tidak membuka panen pangan di tanah hangus. Angka 120 detik adalah percepatan gameplay, bukan klaim pemulihan ekologis nyata.

## 14. Parameter gerak, kamera dan pengaturan P0 — DEFAULT UJI

| Parameter | Nilai awal / batas |
| --- | --- |
| Kecepatan jalan | 3 meter/detik; tidak ada sprint wajib P0 |
| Tinggi kamera | 1,6 meter dari posisi kaki; diuji terhadap collision |
| Kapsul pemain | Radius 0,3 meter, tinggi 1,8 meter; harus cocok pintu/jalur |
| Jangkauan interaksi | 2 meter dari kamera, target valid terdekat pada arah pandang, terhalang collision tidak valid |
| FOV | Awal 80°, rentang 60–100° |
| Sensitivitas | Pengali awal 1,0×, rentang 0,2–3,0×; dasar 0,1° rotasi per piksel mouse sebelum pengali |
| Batas pandang vertikal | −85° sampai +85°; tidak membalik kamera |
| Skala UI | Awal 100%, pilihan 100%/125%/150% |
| Master/efek | Awal 70%, rentang 0–100% |
| Musik | Awal 40%, rentang 0–100%; tidak harus terus berjalan |
| Head bob / motion blur | Mati; head bob boleh tetap tidak tersedia selama tidak ditampilkan seolah dapat diaktifkan |
| Subtitle/teks informasi penting | Aktif; informasi utama tetap dapat dibaca tanpa audio |
| Mode layar awal | Windowed; resolusi mengikuti layar tersedia, target rancangan 1920 × 1080 dan verifikasi minimum layout 1280 × 720 |

Angka ini ditinjau saat PLY-001/UI-001. Gravitasi dan pengaturan physics mengikuti konfigurasi engine yang dikunci pada SETUP-001, dengan nilai aktual dicatat saat implementasi; prototipe tidak memerlukan lompat. Skala teks dan safe margin layout tetap acuan UI_UX, bukan angka pertanian. Renderer/kualitas grafis belum dipilih sebelum pengujian perangkat.
