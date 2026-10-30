# Desain Level — Kampung Fiksi dan Area Awal

**Versi:** 0.3 · **Tanggal:** 30 Oktober 2026  
**Acuan produk:** [PRD](../PRD.md). **Angka konten dan dunia/chunk:** [CONTENT](CONTENT.md). **Visual:** [ART_DIRECTION](ART_DIRECTION.md).

## 1. Prinsip dunia

Gunakan satu map fiksi dengan banyak referensi kehidupan Indonesia. Tidak perlu meniru satu desa nyata atau membangun seluruh Indonesia. Detail seperti genteng, teras, pagar bambu, wadah air, kebun keluarga dan papan program membuat tempat terbaca. Tidak semua referensi harus dijelaskan lewat teks.

Map menjadi tempat yang dikenal dan berubah melalui event tematik. “Karhutla” adalah nama event; ia bukan peta Indonesia luas atau chapter yang mewajibkan pindah level. P0 membangun area dasar yang dapat dipakai kembali, dan P0.5 (PRD D27) menjadikannya zona inti sebuah dunia fiksi sekitar 1 km² yang tetap satu map: sungai, hutan desa, kebun warga dan dusun dimuat per chunk di sekitar pemain, sementara ID lokasi P0 tidak berubah. Aktivasi event sesudah P0.5 mengikuti EVENT_DESIGN dan tidak otomatis merusak kebun pemain.

## 2. Skala dan orientasi rancangan

Seluruh ukuran/koordinat di sini **DEFAULT UJI graybox**, bukan survei geografis. Gunakan satu unit dunia sebagai satu meter. Sumbu X ke timur, Z ke selatan, Y ke atas. Utara adalah Z negatif. Origin berada di sekitar rumah.

### 2.0 Zona inti `zone_core`

`zone_core` adalah area awal P0 beserta seluruh ID lokasi pada tabel di bawah; koordinatnya dipertahankan persis dan ID tidak berubah. Amplop graybox P0 berada sekitar X −40 hingga +40 dan Z −35 hingga +45; tidak seluruh amplop diisi objek atau dapat dijelajahi, sebagian menjadi backdrop dan batas alami. Pada P0.5 `zone_core` menjadi blok chunk yang selalu aktif di pusat dunia (ukuran dan grid di CONTENT bagian 19), sehingga amplop 80 × 80 m tidak lagi menjadi tepi dunia, hanya tepi isi graybox lama. Tanah zona inti rata; medan di luarnya naik bertahap dan posisi Y mengikuti permukaan. Setiap perubahan kontur menguji ulang spawn dan recovery.

| ID lokasi | Pusat rencana (X, Y, Z), meter | Fungsi/ukuran | Landmark |
| --- | --- | --- | --- |
| `zone_home` | (0, 0, −1) | Rumah sekitar 8 × 10 m; footprint X −4..4, Z −6..4 | Genteng hangat, teras selatan |
| `spawn_home` | (0, 0, 1) | Titik kaki pemain; kamera dari tinggi karakter | Buku di utara, pintu pekarangan di selatan |
| `book_family` | (−1, 0, −2) | Meja dan buku; Y aktual di permukaan meja | Sampul krem di meja gelap |
| `station_kitchen_home` | (2, 0, −4) | Dapur di bagian utara/timur rumah | Panci dan dinding berbekas pakai |
| `storage_home` | (−2, 0, −4) | Peti dekat dapur | Tutup kayu dan kain pembeda |
| `bed_home` | (−2, 0, 0) | Titik istirahat | Tikar/tempat tidur sederhana |
| `zone_yard` | (5, 0, 7) | Pekarangan sekitar 16 × 12 m | Petak terlihat dari teras |
| `plot_home_01` | (8, 0, 7) | Petak 2 × 2 m; ruang mengelilingi | Tanah berbeda dari jalur |
| `water_home` | (4, 0, 9) | Sumber isi ulang | Wadah air biru kusam |
| `container_starter` | (6, 0, 4) | Paket awal dan alat | Peti kecil di bawah peneduh |
| `reserve_home` | (7, 0, 4) | Cadangan kontekstual | Wadah berlabel Cadangan |
| `gate_home` | (0, 0, 13) | Keluar pekarangan | Pagar bambu terbuka |
| `junction_path` | (0, 0, 21) | Percabangan jalan pendek | Papan lama dan pohon satu batang miring |
| `resource_jagung_01` | (22, 0, 28) | Sisa kebun keluarga | Pagar miring dan batang jagung |
| `note_garden_01` | (19, 0, 27) | Catatan opsional | Kaleng/kayu dengan kertas |
| `resource_temu_kunci_01` | (−20, 0, 30) | Tepi bambu | Batu besar, daun bumbu lebih rendah |
| `npc_neighbor_01` | (−14, 0, 15) | Teras tetangga | Bangku dan kain peneduh |
| `safe_return_home` | (0, 0, 8) | Recovery di depan rumah | Area terbuka, tidak berimpit petak |

Y nol di tabel objek adalah referensi tanah, bukan pusat mesh final. Seluruh baris tabel ini milik `zone_core`. Buku, panci, UI anchor dan sumber kecil memakai offset agar berada di atas permukaan yang benar. Jangan menanam mesh setengah tenggelam hanya karena tabel menggunakan nol.

### 2.1 Dunia P0.5 di luar zona inti

Dunia sekitar 1 km² mengelilingi `zone_core` (luas dan chunk di CONTENT bagian 19). Zona berikut adalah ID area untuk bahan tiga resep warisan (CONTENT bagian 16). Koordinat zona, jalan antar-zona dan node baru **TERBUKA**; default: ditetapkan WORLD-004 sesuai batas di bawah, lalu dicatat kembali di tabel ini oleh task yang menetapkannya (bukan dibiarkan hanya di kode).

| ID area | Isi | Posisi | Koordinat |
| --- | --- | --- | --- |
| `area_rumah` | Rumah, pekarangan, petak, air; dasar resep 1 (bayam) | `zone_core` | tabel bagian 2 |
| `area_ujung_jalan` | Sisa kebun (jagung), tepi bambu (temu kunci), teras tetangga; dasar resep 1 | `zone_core` | tabel bagian 2 |
| `area_sungai` | Sungai dapat diseberangi, titik pancing, rumpun daun pisang, pos sungai dan pintu air, rumah Mbah Wiji | Luar inti, sisi barat | TERBUKA; sungai memakai polilin di bawah |
| `area_kebun_warga` | Kebun Pak Darmo (kelapa, cabai rawit, kebun singkong) | Luar inti | TERBUKA |
| `area_hutan` | Hutan desa (pakis), pos hutan, jalur Mas Bayu; tepi menyisakan ruang yang kelak dapat menjadi koridor event tanpa dibangun sekarang | Luar inti; terjauh | TERBUKA |

Rumah Bu Sri (serai), balai desa dan titik temu Dik Rini berada di dusun di luar inti; **TERBUKA**, default: satu dusun yang ditetapkan WORLD-004 (peluang dan ukuran dusun di CONTENT bagian 19), dengan ID area tambahan dicatat di CONTENT bila dibutuhkan. Koordinat waypoint warga (`wp_<npc>_…`, CONTENT bagian 17) **TERBUKA**, default: diisi bersama WORLD-004 dan WORLD-005; titik temu harus terjangkau dan tidak berada di collision.

Batas penempatan (DEFAULT UJI): waktu tempuh dari rumah ke tiap area bahan sesuai CONTENT bagian 15; hutan adalah area terjauh; kebun warga dan dusun tidak menghalangi rute ke sungai; jalan antar-zona berupa jejak tanah dan pagar yang terbaca dari percabangan `junction_path`, bukan minimap. Polilin kontrol sungai awal (contoh DEFAULT UJI, dikunci WORLD-004; jarak ke blok rumah sedikitnya 90 m), pada (X, Z): (−150, −500), (−110, −200), (−130, 0), (−170, 200), (−140, 500). Sungai tidak menjadi sumber air; `water_home` tetap satu-satunya.

## 3. Hubungan ruang dan rute

Dari rumah keluar melalui teras selatan ke pekarangan. Petak dan air berada di sisi timur dan terlihat tanpa berputar jauh. Gerbang menuju percabangan. Cabang timur menuju jagung; cabang barat melalui teras tetangga menuju bambu. Hubungkan dua cabang dengan jalur tanah di sisi selatan sehingga eksplorasi bisa berupa putaran pendek, bukan selalu bolak-balik pada lorong yang sama.

Rumah harus terlihat dari sebagian jalur dan dikenali lewat siluet atap. Pada bagian tertutup vegetasi, arah pulang dibantu pagar yang konsisten dan landmark percabangan. Tidak perlu minimap. Petunjuk sumber pada buku harus cocok dengan landmark yang benar-benar dipasang.

Rute antar-zona P0.5: dari `junction_path` jalan bercabang ke zona baru dan menyambung kembali ke putaran inti, sehingga pemain tetap dapat pulang melalui landmark rumah. Ketiga sumber warisan (sungai, hutan, kebun warga) harus terhubung oleh jalan yang dapat dilalui tanpa lompatan presisi.

Usulan lebar jalur utama 2–3 m, pintu bersih sekitar 1,2 m, ruang di depan objek interaksi minimal 1,5 m. Semua DEFAULT UJI kenyamanan, disesuaikan dengan kapsul pemain. Tidak ada lompatan presisi, celah sempit atau pijakan tersembunyi untuk mengambil bahan.

## 4. Spawn, gerak dan pandangan awal

Spawn menghadap utara ke arah meja buku, dengan pintu pekarangan masih mudah ditemukan ketika berbalik. Kamera tidak menempel dinding, furnitur atau atap. Pastikan posisi kaki dan capsule tidak berimpit collision. Tinggi kamera/karakter mengikuti parameter gerak yang akan diuji; bukan ukuran mesh tanaman.

Recovery `safe_return_home` dipakai bila posisi save tidak valid atau pemain memilih kembali ke posisi aman. Jika posisi tersebut juga terhalang setelah perubahan level, gunakan spawn rumah yang tervalidasi. Recovery hanya mengubah posisi/rotasi; tidak memberikan barang atau memundurkan progres.

## 5. Penempatan petak dan titik tanam

Petak berada di pekarangan, bukan jalur pulang. Empat titik pada kuadran petak dengan jarak yang jelas; ID titik stabil dan tidak bergantung urutan mesh di scene. Sisakan ruang untuk berdiri pada semua sisi. Batas sorot perawatan selalu sama dengan luas petak yang menerima aksi.

Air dan paket awal dekat, sehingga pemain memahami fungsi keduanya tanpa berjalan jauh. Jangan menaruh pupuk di belakang UI atau benih di dalam objek yang tidak memiliki prompt. Tanaman bayam harus dapat dibidik tanpa harus jongkok; pertimbangkan collider/proxy interaksi yang lebih mudah dikenali, tetap sesuai visual.

## 6. Sumber, pemulihan dan narasi lingkungan

Jagung dan temu kunci bersifat deterministik. Tampilannya berubah setelah panen dan hasil tidak kembali saat pemain masih menatap sumber. Menunggu hari atau istirahat memulihkan sumber sesuai CONTENT. Catatan opsional di jagung tidak menjadi syarat panen.

Teras tetangga berada di rute yang wajar, tetapi pemain boleh melewatinya. Pada P0 warga dapat terlihat melakukan aktivitas sederhana tanpa jadwal; pada P0.5 delapan warga bergerak berjadwal dengan jalur poliline antar-waypoint tanpa navmesh (CONTENT bagian 17). Bu Tarni tetap `npc_neighbor_01`; profesi warga lain mengikuti CONTENT. Dialog memberi petunjuk yang sama dengan buku, bukan informasi kontradiktif.

Krisis diperlihatkan lewat pagar miring, tembok ditambal, bekas kebun, rak yang tidak penuh dan papan program lama. Hindari tumpukan sampah dekoratif yang menutupi sumber bahan. Jangan menjadikan semua lokasi rusak identik; beri variasi agar orientasi mudah.

## 7. Batas dunia dan collision

Gunakan pagar, lereng, vegetasi rapat dan backdrop untuk batas. Pada P0.5 tepi dunia sekitar 1 km² adalah punggungan gunung yang tidak dapat didaki (DISETUJUI; jarak di CONTENT bagian 19), dengan satu sumber batas dunia untuk kode. Batas jelas sebelum pemain mencapainya; tidak ada lubang collision atau dinding tak terlihat pada jalan yang tampak dapat dipakai. Ke luar amplop map memicu pemulihan posisi aman, bukan kematian atau reset inventaris.

Collision dipusatkan pada volume penting: lantai, dinding, pagar dan objek besar. Detail kecil tidak perlu menjegal pemain. Batang/daun dekoratif tidak boleh mengunci akses panen. Uji tersangkut di sudut pintu, tepi petak, belakang peti, teras dan percabangan.

## 8. Persiapan event tanpa memperbesar P0

Reserve area tepi timur kebun sebagai kandidat `zone_event_edge`; tidak perlu membuat api atau stasiun baru saat P0 maupun P0.5 (event tetap P1, setelah QA-002). Route bahan inti tetap terbuka pada keadaan dasar. ID lokasi/sumber/petak tetap stabil agar save dan event bisa merujuknya.

Untuk event Karhutla, usulkan satu jalur kebun terganggu dan rute alternatif melalui pos air, sementara rumah, titik aman dan petak awal tetap terlindungi. Area terbakar yang dipulihkan terpisah dari sumber jagung yang masih tersisa. Jangan mengganti tanaman hangus menjadi jagung siap panen setelah satu aksi. Perubahan final berada pada task EV-002 setelah desain event disepakati/diotorisasi implementasinya.

Event mengubah subset objek/lokasi melalui state, bukan membuat salinan seluruh map dengan ID berbeda. Batas zona bahaya harus terbaca dari jarak yang memberi pemain kesempatan berhenti. Tidak ada tujuan memaksa masuk api besar. Sumber wajib tetap mempunyai jalur pemulihan deterministik.

## 9. Urutan pembuatan level nanti

1. Tanah, rumah sederhana, spawn dan collision.
2. Jalur, gerbang, percabangan dan recovery.
3. Placeholder dapur, buku, peti, air dan petak.
4. Lokasi bahan dan tetangga beserta ID stabil.
5. Uji rute dengan kontrol pemain dan waktu tumbuh CONTENT.
6. Perbaiki skala/jarak berdasarkan playthrough.
7. Tambahkan material, vegetasi selektif, ambience dan narasi lingkungan.
8. Uji performa serta keterbacaan; baru sesudah P0 pertimbangkan zona event.

Urutan tambahan P0.5: (a) fondasi grid, batas dunia dan medan deterministik dengan blok `zone_core` tetap apa adanya (WORLD-002); (b) streaming medan, collision dan kabut (WORLD-003); (c) sungai, hutan, ladang, dusun, backdrop dan titik tiga sumber warisan (WORLD-004); (d) warga bergerak dan waypoint (WORLD-005). Tiap langkah menguji ulang rute P0 dan recovery sebelum menambah isi.

## 10. Kriteria penerimaan level

Penguji dapat menemukan buku, petak, air, jagung, temu kunci, dapur dan tetangga dengan petunjuk yang ada. Tidak perlu bantuan minimap atau lompatan. Perjalanan memberi kegiatan saat tanaman tumbuh dan tidak menuntut menunggu diam terlalu lama. Semua prompt terjangkau, rumah mudah dikenali, dan kembali ke posisi aman tidak mengubah progres.

Kriteria tambahan P0.5: setiap sumber resep warisan dapat ditemukan dari petunjuk buku dan lingkungan tanpa minimap; ketiganya terhubung oleh jalan dan dapat dicapai dari rumah dalam waktu tempuh yang dinyatakan di CONTENT bagian 15; titik temu penerima terjangkau dan tidak berada di collision; tepi dunia terbaca sebelum dicapai dan recovery di tepi tidak mengubah item; ID dan koordinat zona inti tidak bergeser.

Peta bukan selesai hanya karena seluruh bangunan ada: skala, navigasi, collision, sightline, pemulihan dan performa harus diuji. Checklist pelaksanaan ada di TEST_PLAN dan TASKS.

## 11. Riwayat perubahan

| Versi | Tanggal | Perubahan |
| --- | --- | --- |
| 0.2 | 27 Oktober 2026 | Denah dan koordinat area awal P0 |
| 0.3 | 30 Oktober 2026 | SCOPE-001: `zone_core` (koordinat P0 dipertahankan), dunia P0.5 sekitar 1 km² dan ID area bahan warisan (koordinat TERBUKA), tepi dunia, rute antar-zona, urutan dan kriteria tambahan |
