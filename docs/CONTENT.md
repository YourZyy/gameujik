# Data dan Konten Permainan Awal

**Versi:** 0.3 · **Tanggal:** 30 Oktober 2026 (SCOPE-001; bagian 1–14 = konten P0 yang tidak berubah, bagian 15–20 = konten P0.5 "Kampung Hidup")  
**Acuan:** [PRD](../PRD.md), [Prototipe](PROTOTYPE.md), [UI/UX](UI_UX.md), [Level](LEVEL_DESIGN.md), [Seni](ART_DIRECTION.md).

## 1. Status dan kepemilikan data

Dokumen ini adalah sumber tunggal ID, jumlah, waktu, kapasitas dan nilai gameplay P0 dan P0.5 (D26–D32 di PRD). Bagian 1–14 adalah kontrak P0 dan tidak diubah oleh P0.5; bagian 15–20 menambah item, resep, warga, jadwal, parameter dunia/chunk dan ambang performa. Dokumen lain merujuk angka dunia, chunk, anggaran dan ambang uji ke sini dan tidak menyalinnya. Seluruh nilai numerik di sini berlabel **DEFAULT UJI** (atau **TARGET/TERBUKA** bila dinyatakan): konkret untuk implementasi awal, belum hasil balancing atau benchmark; tidak ada angka dunia atau performa P0.5 yang sudah diukur. Jumlah bahan bukan takaran kuliner dan durasi tanaman bukan waktu biologis nyata.

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

Tidak ada tombol buang barang P0. Barang yang dibutuhkan tidak dapat terhapus lewat klik salah. Pemulihan kapasitas dilakukan melalui penyimpanan, memasak, makan dan berbagi. Pada P0 ragam item hanya tujuh jenis; P0.5 menambah delapan item di bagian 16 dengan aturan bagian ini tanpa perubahan. Tas dan peti bersama memberi ruang jauh di atas satu loop. Uji kapasitas ekstrem menggunakan fixture pengujian, bukan membanjiri pengalaman awal.

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
| Penerima (P0.5) | `npc_neighbor_01` (Bu Tarni) sebagai `delivery_npc_id`; lihat bagian 16 |
| Sumber durasi | Persiapan 4 detik dan pemasakan 30 detik di tabel ini adalah satu-satunya sumber; kode membaca definisi resep (FIX-001) |

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
| Satu hari prototipe | 720 detik simulasi aktif; jam dalam game diturunkan dari waktu aktif (bagian 17), tanpa jam di HUD |
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

Dialog dapat dibuka ulang; memilih keluar tidak mengunci sumber. Teks naratif DEFAULT UJI ini dapat diganti tanpa mengubah mekanik. Pada P0.5 tujuh dialog ini menjadi pohon `npc_neighbor_01` dengan ID dan teks yang sama (bagian 18) agar regresi SOC-001 tetap berlaku.

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
| Penutup P0 | “Satu resep selesai. Kebun ini baru dimulai.” (pada P0.5 menjadi penutup Tahap 1; penutup buku lengkap ada di bagian 18) |

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
| RecipeProgress | Ditemukan, selesai, jumlah dibuat; tracked_recipe terpisah. P0.5 menambah `delivered_to` (kosong atau ID warga) dan `stamped` per resep |
| World | Indeks hari, waktu aktif, wadah awal diambil, flag catatan, flag dialog, meal_used |
| Save envelope | Versi skema, revisi checkpoint, waktu simpan, payload tervalidasi |
| Settings | Sensitivitas, FOV, skala UI, audio, subtitle, tampilan; terpisah dari progres |
| NpcData (P0.5) | ID, nama, peran, area rumah, kecepatan jalan, jadwal, ID dialog, ID hidangan yang diterima, ID visual |
| NpcSchedule, ScheduleBlock (P0.5) | Daftar blok terurut: jam mulai, aktivitas (kerja/bicara/duduk/tidur), ID waypoint, ID rute |
| NpcRoute, Waypoint (P0.5) | Rute = poliline titik antar-waypoint; waypoint = ID, posisi, arah hadap; tanpa navmesh |
| DialogueTree (P0.5) | Aturan masuk berurutan, simpul (ID, teks, pilihan), kondisi dan aksi bernama |
| Buku dan relasi (P0.5) | `pages_revealed`, `book_completed_shown`; per warga `met`, `relation_level`, `dialogue_flags`, `dishes_received` |
| Dunia (P0.5) | Seed dunia, `worldgen_version`, `extent`, daftar objek dihapus per chunk (jarang); tidak menyimpan tinggi, mesh, pohon, sungai atau posisi warga |
| Save envelope v2 (P0.5) | Versi skema 2 dengan seksi `worldgen`; kebijakan migrasi di PROTOTYPE bagian 7 |

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

Saat aktivasi, simpan baseline jumlah masakan dibuat **per resep** (P0.5 memiliki tiga resep) dan reset flag penggunaan hidangan khusus event. Default rancangan event tetap memakai resep pertama; pilihan resep untuk event diputuskan pada EV-001. Event mensyaratkan setidaknya satu commit masakan baru setelah aktivasi, lalu satu aksi makan/berbagi setelah commit tersebut. Flag `meal_used` P0 yang lama tidak menutup event secara otomatis. Tidak perlu provenance tiap tumpukan pada rancangan ini: yang dibuktikan adalah urutan tindakan masak baru lalu penggunaan hidangan, bukan asal fisik unit yang dipakai.

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

Angka ini ditinjau saat PLY-001/UI-001. Gravitasi dan pengaturan physics mengikuti konfigurasi engine yang dikunci pada SETUP-001, dengan nilai aktual dicatat saat implementasi; prototipe tidak memerlukan lompat. Skala teks dan safe margin layout tetap acuan UI_UX, bukan angka pertanian. Renderer dikunci `gl_compatibility` pada SETUP-001; preset kualitas grafis belum ditetapkan sebelum pengujian perangkat.

## 15. Cakupan konten P0.5 "Kampung Hidup" — DEFAULT UJI

Bagian 15–20 menambah konten untuk tahap P0.5 (PRD D26–D32) dan **tidak mengubah** bagian 1–14. Label: **DISETUJUI** hanya untuk keputusan pemilik tertulis pada PRD §3 (mis. tiga resep warisan, tepi dunia gunung, sungai bukan sumber air); semua angka, ID baru dan teks di bawah adalah **DEFAULT UJI** dan belum pernah dijalankan; hal yang belum ada ditulis **TERBUKA** dengan default. Satu petak/empat titik dan dua tahap memasak (D32) tetap. Bayam tetap satu-satunya tanaman yang ditanam; bahan baru berasal dari node liar.

| Hal | Nilai |
| --- | --- |
| Tujuan | Mengumpulkan 3 resep warisan: setiap halaman buku distempel setelah hidangannya dimasak lalu diserahkan kepada penerimanya |
| Resep dilacak bersamaan | Satu (D17) |
| Target tempo sesi pertama | 45–75 menit; target pengamatan, belum diuji |
| Waktu tempuh ke tiap area bahan | 1–2 menit berjalan kaki pada 3 m/s (bagian 14); target pengamatan |
| Pembelian/barter | Tidak ada; warga memberi petunjuk, bukan barang wajib |

## 16. Item dan tiga resep warisan — DEFAULT UJI

### 16.1 Item baru

Tumpukan maksimum 20 per slot; aturan bagian 2 dan 3 berlaku.

| ID | Nama tampil | Kategori | Sumber |
| --- | --- | --- | --- |
| `ingredient_ikan_nila` | Ikan nila | Bahan resep | `resource_ikan_nila_01`, `resource_ikan_nila_02` (titik pancing sungai), 1 per panen |
| `ingredient_daun_pisang` | Daun pisang | Bahan resep | `resource_daun_pisang_01` (rumpun tepi sungai), 2 per panen |
| `ingredient_serai` | Serai | Bahan resep | `resource_serai_01` (pekarangan Bu Sri), 1 per panen |
| `ingredient_pakis` | Pucuk pakis | Bahan resep | `resource_pakis_01` (hutan desa), 3 per panen |
| `ingredient_kelapa` | Kelapa | Bahan resep | `resource_kelapa_01` (kebun Pak Darmo), 1 per panen |
| `ingredient_cabai_rawit` | Cabai rawit | Bahan resep | `resource_cabai_rawit_01` (kebun Pak Darmo), 1 per panen |
| `dish_pepes_nila` | Pepes Ikan Nila | Hidangan | Dapur, resep 2 |
| `dish_urap_pakis` | Urap Pakis Kelapa | Hidangan | Dapur, resep 3 |

Stempel halaman adalah state resep dan titip hidangan adalah aksi dialog; keduanya bukan item. Bumbu dasar lain (garam, bawang) dianggap persediaan dapur dan bukan item.

### 16.2 Resep

| | Resep 1 (tidak berubah) | Resep 2 | Resep 3 |
| --- | --- | --- | --- |
| ID | `recipe_sayur_bening_01` | `recipe_pepes_nila_01` | `recipe_urap_pakis_01` |
| Nama | Sayur Bening Bayam dan Jagung | Pepes Ikan Nila | Urap Pakis Kelapa |
| Bahan | bayam 3, jagung 1, temu kunci 1 | ikan nila 1, daun pisang 2, serai 1 | pakis 3, kelapa 1, cabai rawit 1 |
| Area | `area_rumah`, `area_ujung_jalan` | `area_sungai`, pekarangan Bu Sri | `area_hutan`, `area_kebun_warga` |
| Persiapan | 4 detik (bagian 4) | 6 detik | 5 detik |
| Memasak (panas Sedang) | 30 detik (bagian 4) | 40 detik | 35 detik |
| Hasil | `dish_sayur_bening` ×1 | `dish_pepes_nila` ×1 | `dish_urap_pakis` ×1 |
| `delivery_npc_id` | `npc_neighbor_01` (ID lama dipertahankan) | `npc_mbah_wiji` | `npc_mas_bayu` |
| Catatan resep | catatan bagian 4 | `recipe_note_pepes_nila` | `recipe_note_urap_pakis` |

Stasiun semua resep: `station_kitchen_home`. Aturan panas, pembatalan, reservasi, slot hasil tunggal dan pengali panas bagian 4 berlaku identik; pengali panas tetap satu tabel bersama. Urutan rekomendasi 1, 2, 3 hanya tersirat dalam petunjuk Bu Tarni; ketiganya tidak memiliki prasyarat teknis dan boleh dikerjakan paralel.

Kelayakan kuliner (bukan klaim keamanan pangan): pepes ikan berbumbu dalam bungkus daun pisang dan urap sayur berkelapa parut lazim di masakan Jawa/Sunda. Hasil panen node liar ikut aturan bagian 9: satu panen per node per hari simulasi dan pulih saat pergantian hari. Membuat ulang sebuah resep bergantung pada pulihnya node bahannya; dampak pada tempo diamati saat uji.

### 16.3 Node bahan liar

| Node | Perilaku | Catatan |
| --- | --- | --- |
| `resource_ikan_nila_01`, `_02` | Tahan E 5 detik; hasil pasti 1 ikan | Titik pancing tetap; tanpa joran, umpan, minigame atau acak. Sistem memancing penuh tetap P3 |
| `resource_daun_pisang_01`, `resource_serai_01`, `resource_pakis_01`, `resource_kelapa_01`, `resource_cabai_rawit_01` | Pola node liar bagian 9 | Menanam serai atau cabai ditunda; tidak menambah cakupan kebun |

Lokasi tepat node (koordinat) **TERBUKA**; default: ditetapkan pada WORLD-004 di dalam `area_sungai`, `area_kebun_warga` dan `area_hutan` (LEVEL_DESIGN bagian 2.1) dengan waktu tempuh bagian 15, dan dicatat kembali di LEVEL_DESIGN. ID node di atas stabil. Foraging prosedural lain di luar ID di bagian 16.1 tidak ada sampai CONTENT menambahkannya (jawaban default pemilik).

### 16.4 Petunjuk bahan per baris

Teks petunjuk tiap bahan ditulis pada data resep oleh GOAL-001a. Contoh yang ditetapkan: ikan — “Titik pancing di pinggir sungai, dekat batu datar.” Teks lain **TERBUKA**; default: satu kalimat lokasi seperti pola bagian 4. Batas isi: petunjuk menyebut tempat, bukan ciri identifikasi, tingkat kematangan, cara memilah atau klaim keamanan konsumsi bahan hutan apa pun (termasuk pakis). Teks ilmiah tambahan divalidasi dahulu (PRD §14).

## 17. Warga, jadwal dan waktu dalam game — DEFAULT UJI

### 17.1 Daftar warga

| ID | Nama, peran | Rumah (teras) | Pekerjaan / titik siang | Peran cerita |
| --- | --- | --- | --- | --- |
| `npc_neighbor_01` | Bu Tarni, tetangga | sebelah rumah (teras P0, LEVEL_DESIGN bagian 2) | pagar dan jalan depan | Penerima resep 1; pemberi lembar halaman |
| `npc_pak_darmo` | Pak Darmo, petani | `area_kebun_warga` | kebun singkong | Petunjuk kelapa dan cabai; satir benih |
| `npc_bu_sri` | Bu Sri, warung kosong | rumah desa | warung (rak ditata, kosong) | Petunjuk serai; satir rak kosong |
| `npc_mbah_wiji` | Mbah Wiji, lansia | dekat sungai | teras; sore ke tepi sungai | Penerima resep 2 |
| `npc_pak_joko` | Pak Joko, penjaga pintu air | pos sungai | pintu air dan titik pancing | Petunjuk ikan |
| `npc_mas_bayu` | Mas Bayu, penjaga hutan desa | pos hutan | jalur hutan | Penerima resep 3 |
| `npc_pak_harjo` | Pak Harjo, petugas desa | balai desa | balai, papan program | Satir lembaga |
| `npc_dik_rini` | Dik Rini, kurir remaja | dekat jalan | keliling desa | Mengarahkan ke warga lain |

Jumlah delapan warga adalah DEFAULT UJI. Koordinat rumah, titik kerja dan waypoint **TERBUKA**; default: ID waypoint `wp_<npc>_rumah`, `wp_<npc>_kerja`, `wp_<npc>_temu`, `wp_<npc>_istirahat` (Dik Rini: `wp_rini_a` hingga `wp_rini_d`), koordinat diisi bersama peta dunia pada WORLD-004 dan WORLD-005 dan dicatat di LEVEL_DESIGN bagian 2.1. Bu Tarni memakai lokasi teras tetangga P0 yang sudah ada.

### 17.2 Jam dalam game

`jam = 6 + (waktu_aktif_hari / durasi_hari) × 24`, modulo 24, dengan durasi hari dari bagian 9 (720 detik = 24 jam, jadi 1 jam = 30 detik). Hari mulai pukul 06.00. Tidak ada jam di HUD; isyarat waktu berupa posisi warga, petunjuk Dik Rini dan arah matahari. Pencahayaan Senja tetap (ART_DIRECTION bagian 5).

### 17.3 Jadwal

Berlaku untuk semua warga kecuali Dik Rini.

| Blok | Aktivitas | Titik |
| --- | --- | --- |
| 06.00–10.00 | bekerja | `_kerja` |
| 10.00–14.00 | **titik temu pasti**: berdiri atau duduk dan dapat diajak bicara | `_temu` |
| 14.00–18.00 | bekerja atau berjalan | `_kerja` (Mbah Wiji: tepi sungai) |
| 18.00–21.00 | di teras | `_rumah` |
| 21.00–06.00 | tidur di dalam; mengetuk pintu memberi dialog "sudah tidur" tanpa efek | `_istirahat` |

Dik Rini: 06.00–10.00 berjalan `wp_rini_a` ke `wp_rini_b`; 10.00–14.00 di `_temu` dekat jalan rumah; 14.00–20.00 berkeliling `wp_rini_c` ke `wp_rini_d`.

Batas jalur: tiap perpindahan satu warga paling jauh 150 m pada 1,5 m/s (paling lama 100 detik = 3,3 jam); Dik Rini paling jauh 400 m pada 2,5 m/s. Rumah dan titik kerja satu warga berdekatan. Setiap warga memiliki tepat satu blok bicara pada 10.00–14.00. Aturan ini diperiksa oleh tes validasi data (TEST_PLAN T68).

### 17.4 Relasi dan penyerahan

Relasi 0 belum kenal; 1 sudah bicara (`sapa` selesai); 2 sudah menerima hidangan (penerima) atau tiga percakapan (lainnya). Relasi hanya mengubah dialog atau petunjuk, tidak menjadi gerbang dan tidak memberi item. Penerima menampilkan “Serahkan [nama] — 1” bila hidangan ada di tas atau peti; penyerahan memotong 1 hidangan secara atomik, menandai `delivered_to` dan stempel, dan idempoten sekali per resep. Hidangan yang bukan untuk warga itu ditolak tanpa efek: “Sepertinya itu bukan buat saya.” Bila penerima tidak ditemui, ketuk pintu teras menawarkan “titip hidangan” pada hari berikutnya; hidangan tetap di tas atau peti dan tidak kedaluwarsa.

## 18. Dialog warga, buku tiga halaman dan penutup — DEFAULT UJI

Struktur ringkas per warga (paling banyak lima simpul): `sapa` (kenalan, relasi 0 ke 1), `petunjuk` (1–2 pilihan), `menunggu` (bila belum ada hidangan), `terima` (hanya penerima; aksi serah), `ulang`. Tujuh simpul `npc_neighbor_01` bagian 10 dipertahankan dengan ID dan teks yang sama.

| Warga | Kalimat kunci |
| --- | --- |
| Bu Tarni | (lama) dan setelah resep 1: “Ini lembar yang terselip di buku Ibumu. Ke sungai, ke hutan, terserah mana dulu.” (membuka halaman 2 dan 3) |
| Pak Darmo | “Kelapa jatuh dan cabai yang merah, ambil saja. Benih bersertifikat dari program? Kotaknya masih kosong.” |
| Bu Sri | “Serai di belakang, silakan. Rak depan memang rapi, tinggal barangnya.” |
| Mbah Wiji | Terima: “Ibumu dulu membungkusnya begini. Duduklah sebentar.” |
| Pak Joko | “Pancing saja di batu datar. Pintu air itu tidak pernah selesai diperbaiki, sama seperti janjinya.” |
| Mas Bayu | Terima: “Pakis dari hutan sendiri, rasanya memang lain. Hutan ini masih mau diurus.” |
| Pak Harjo | “Kawasan Pangan Masa Depan itu program tahap pemeliharaan. Tahap pemeliharaannya sudah lima tahun.” |
| Dik Rini | “Mbah Wiji siang di teras, sore ke sungai. Mas Bayu pagi di jalur hutan.” |

Buku tiga halaman: awal hanya halaman 1, sampul “Halaman distempel 0/3” dan kalimat “Dua lembar lain terselip di buku ini”. Halaman 2 dan 3 terbuka penuh (nama, bahan, petunjuk sumber, catatan, penerima, contoh “Untuk Mbah Wiji, dekat sungai”) setelah dialog pertama Bu Tarni; urutan memasak bebas. Tiap halaman memuat empat centang (Ditemukan, Bahan, Dimasak, Diserahkan) yang membaca aturan ketersediaan yang sama dengan tracker. Tidak ada persen, bar atau skor.

Layar penutup muncul satu kali setelah stempel ketiga (flag `book_completed_shown`): tiga stempel, nama tiga penerima, satu kalimat dari masing-masing, dan “Buku ini lengkap. Kebun ini baru dimulai.” dengan tombol Lanjutkan. Tidak ada skor, bintang atau waktu; permainan berlanjut.

Satir lingkungan (tokoh dan lembaga fiktif, tanpa ceramah): papan “Sungai Percontohan Bersih” dengan sampah plastik dekoratif; papan “Hutan Produksi Terpadu” dengan tunggul lama; kotak benih bersertifikat kosong di kebun warga. Tidak ada mekanik bersih-bersih.

## 19. Parameter dunia dan chunk — DEFAULT UJI / TARGET

Bagian ini satu-satunya sumber angka dunia, chunk dan streaming. Nilai adalah TARGET atau hipotesis; Godot tidak dipakai saat menyusunnya dan belum ada yang diukur. Perubahan formula yang menggeser tata letak menaikkan `worldgen_version` dan memperbarui uji hash emas.

| Parameter | Nilai | Status |
| --- | --- | --- |
| Ukuran chunk | 28 × 28 m; `cx = floor((x+14)/28)`, `cz = floor((z+9)/28)` | DEFAULT UJI |
| Zona inti | Blok 3 × 3 chunk (`cx, cz` dari −1 sampai 1) memuat seluruh area P0; selalu tingkat A (pinned) | DEFAULT UJI |
| Luas dunia awal | `cx, cz` dari −18 sampai 18: 37 × 37 = 1.369 chunk ≈ 1,07 km²; `extent` disimpan di save | DEFAULT UJI |
| Radius muat / buang | Muat bila `d ≤ 6` (169 chunk), buang bila `d > 7` dan sudah di luar paling sedikit 2 detik; `d` = jarak Chebyshev dalam chunk | DEFAULT UJI; angka akhir mengikuti pengukuran di perangkat pemilik (default 6) |
| Tingkat A, B1, B2 | A `d ≤ 2` (25 chunk: mesh 1 m, collider medan, objek interaktif); B1 `d` 3–4 (56: mesh 2 m, tanpa collider); B2 `d` 5–6 (88: mesh 4 m); naik ke A pada `d ≤ 2`, turun ke B1 hanya pada `d ≥ 4` | DEFAULT UJI |
| Collider batang pohon | Hanya `d ≤ 1`; paling banyak 400 bentuk | TARGET |
| Anggaran komit per frame | Satu chunk per frame, paling lama 1.500 µs di thread utama; buang paling banyak 1 chunk per frame | TARGET |
| Generasi latar | Paling banyak 3 job bersamaan; paling lama 8 ms per chunk; mode sinkron cadangan | TARGET |
| Seed | Bilangan bulat < 2³¹; `DEFAULT_WORLD_SEED` **TERBUKA**, default: dipilih dan dicatat di WORLD-002 (bukan keputusan produk) | DEFAULT UJI |
| Tinggi ruang jelajah | −3 sampai +30 m; zona inti datar tepat 0 m; medan naik bertahap sepanjang 40 m dari tepi zona inti | DEFAULT UJI |
| Tepi dunia | Punggungan gunung tak terdaki mulai 380 m dan penuh 480 m dari rumah; di luar ruang jelajah | DISETUJUI (jawaban default pemilik); jarak DEFAULT UJI |
| Pohon dan batu | Kandidat pada grid terjitter 3,5 m (sekitar 64 per chunk) | DEFAULT UJI |
| Dusun | Wilayah 4 × 4 chunk; peluang ada 0,3; 3–8 rumah dari beberapa prefab | DEFAULT UJI |
| Sungai | Dapat diseberangi, kedalaman paling besar 1,2 m, bukan sumber air (`water_home` tetap satu-satunya); kecepatan jalan di air ×0,7 (usul, uji rasa); tanpa mati atau renang | Sifat DISETUJUI; angka DEFAULT UJI |
| Kabut | Menyamarkan batas muat; contoh awal linear mulai 45 m, penuh 135 m (jarak terdekat sisi chunk terjauh 141 m). Jenis dan nilai akhir ditetapkan VIS-001 dari verifikasi di renderer yang dikunci | DEFAULT UJI |
| Jarak bayangan directional | **TERBUKA**; default 40 m, dinilai VIS-001 lewat pengukuran | DEFAULT UJI |
| Jarak tampak pohon | Model sampai 70 m, versi silang mulai 60 m | DEFAULT UJI |
| Presisi | Koordinat sampai ±600 m aman; *origin rebasing* dicatat untuk dunia lebih dari ±4 km, tidak dikerjakan | Catatan |

Polilin sungai awal ada di LEVEL_DESIGN bagian 2.1 (tata ruang), bukan di sini.

## 20. Anggaran visual dan ambang performa — TARGET, belum diukur

Semua nilai HIPOTESIS/TARGET sampai diukur di perangkat pemilik (Windows, Godot 4.7.2, `gl_compatibility`); jangan dikutip sebagai hasil. Tabel ini satu-satunya sumber angka anggaran dan ambang; PRD, PROTOTYPE, ART_DIRECTION dan TEST_PLAN merujuknya.

| Anggaran (1920 × 1080) | Target |
| --- | --- |
| Draw call terlihat | paling banyak sekitar 800 |
| Segitiga terlihat | paling banyak sekitar 400 ribu |
| Material unik | paling banyak sekitar 25 |
| Node per chunk | paling banyak 12 |
| Cahaya | satu directional dengan bayangan (2 split, resolusi 2048, turun ke 1024 bila lambat); satu omni dapur tanpa bayangan |
| Rumput dan semak (MultiMesh) | paling banyak sekitar 20 ribu kartu, jarak tampak sekitar 40 m |
| Pohon dekat penuh | paling banyak sekitar 150 instans; yang jauh memakai LOD atau versi silang |
| Memori statis tambahan akibat dunia | paling banyak sekitar 15 MB; pertumbuhan paling banyak 10% setelah mengelilingi dunia |
| Memori tekstur | paling banyak sekitar 256 MB |
| Waktu muat adegan utama | paling lama sekitar 5 detik |
| Urutan pengurangan bila meleset | resolusi bayangan, jarak rumput, glow, MSAA, kepadatan pohon |

| Ambang gerbang P0.5 (PROTOTYPE bagian 10.2) | Nilai |
| --- | --- |
| Target visual rute standar | rata-rata paling rendah 60 FPS dan tidak turun di bawah 45 FPS di titik terberat |
| Gerbang rute tepi ke tepi (1080p kualitas rendah) | rata-rata paling rendah 60 FPS dan 1% terendah paling rendah 30 FPS; fallback sah: rata-rata paling rendah 30 FPS dengan catatan jujur dan keputusan pemilik |
| Lintasan batas chunk | tidak ada frame lebih dari 100 ms pada paling sedikit 95% dari 20 lintasan; maksimum dilaporkan |
| Memori 30 menit | pertumbuhan setelah pemanasan kurang dari 10%; jumlah ObjectDB saat exit tidak lebih buruk dari baseline P0 (TEST_PLAN bagian 1) |
| Perangkat uji | dicatat pada tiap laporan; hasil tidak digeneralisasi ke perangkat lain |

## 21. Riwayat perubahan

| Versi | Tanggal | Perubahan |
| --- | --- | --- |
| 0.2 | 27 Oktober 2026 | Konten P0 bagian 1–14 |
| 0.3 | 30 Oktober 2026 | SCOPE-001: tambah bagian 15–20 (item, tiga resep warisan, warga dan jadwal, dialog dan buku, parameter dunia/chunk, anggaran dan ambang performa); bagian 4, 9, 10, 12, 13 dan 14 disesuaikan tanpa mengubah nilai P0 |
