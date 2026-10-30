# 003 — Graybox Map, Rumah, Pekarangan, Collision, Spawn dan Recovery

## Identitas

- **ID task:** LVL-001.
- **Judul:** Graybox Map, Rumah, Pekarangan, Collision, Titik Spawn dan Recovery.
- **Tanggal selesai:** 27 Oktober 2026.
- **Agent/pelaksana:** AI assistant (worker_lvl_001).
- **Tahap produk:** P0 (Level Design & World Prototyping).
- **Status:** Selesai.
- **Versi sumber/build:** Godot Engine v4.7.2.stable.official.ed1daf0bf (win64 standard release); Git lokal.

## Tujuan dan pemicu

Sesuai spesifikasi `docs/TASKS.md` dan acuan desain `docs/LEVEL_DESIGN.md`, task LVL-001 bertujuan membangun geometri 3D graybox tingkat pertama untuk dunia kampung fiksi *Buku Resep 2045*. Area ini mencakup amplop lantai tanah playable, struktur arsitektur rumah sederhana, pekarangan berkebun, 18 landmark dengan ID dan koordinat stabil, collision fisik pada seluruh batas dan dinding, titik spawn awal pemain, serta mekanisme recovery otomatis ke titik aman saat pemain jatuh di bawah batas dunia.

Pemicu pelaksanaan adalah penyelesaian task pondasi teknis SETUP-001 (laporan 002) dan instruksi untuk mewujudkan ruang 3D yang valid dan dapat diuji sebelum kendali karakter first-person diimplementasikan pada task PLY-001.

## Ruang lingkup

Ruang lingkup yang dikerjakan mencakup:
1. Pembuatan adegan level graybox `scenes/world/level_graybox.tscn` dengan root node `LevelGraybox` bertipe `Node3D` dan skrip pengontrol `scripts/world/level_graybox.gd`.
2. Konstruksi lantai tanah utama (`Ground`) berukuran 80x80 meter yang mencakup koordinat X [-40..40] dan Z [-35..45] dilengkapi `StaticBody3D` dan `CollisionShape3D` padat.
3. Pembangunan struktur rumah (`HouseStructure` pada `zone_home` di (0, 0, -1), footprint X [-4..4], Z [-6..4]) dengan lantai kayu, dinding utara, barat, timur, teras selatan berbukaan pintu 1.6 m, lintel atas, serta atap genteng bersudut hangat yang seluruhnya memiliki collision fisik.
4. Pemasangan dan penempatan 18 landmark utama dengan node ID stabil dan toleransi koordinat < 0.5 m sesuai `LEVEL_DESIGN.md`:
   - `zone_home` (0, 0, -1): pusat rumah keluarga.
   - `spawn_home` (0, 0, 1): titik spawn awal pemain menghadap utara (-Z).
   - `book_family` (-1, 0, -2): meja kayu dan placeholder buku resep keluarga pada ketinggian meja (Y=0.825).
   - `station_kitchen_home` (2, 0, -4): meja counter kompor/dapur.
   - `storage_home` (-2, 0, -4): peti penyimpanan bahan/peralatan.
   - `bed_home` (-2, 0, 0): tikar/tempat tidur sederhana.
   - `zone_yard` (5, 0, 7): pusat pekarangan luar.
   - `plot_home_01` (8, 0, 7): petak kebun 2x2 meter tanah subur dengan 4 kuadran titik tanam.
   - `water_home` (4, 0, 9): wadah penampungan air untuk isi ulang.
   - `container_starter` (6, 0, 4): peti paket awal bibit dan alat.
   - `reserve_home` (7, 0, 4): peti cadangan kontekstual darurat.
   - `gate_home` (0, 0, 13): gerbang bambu keluar pekarangan selebar 2.2 meter.
   - `junction_path` (0, 0, 21): persimpangan jalan desa dengan tiang penunjuk arah.
   - `resource_jagung_01` (22, 0, 28): sisa kebun jagung keluarga di cabang timur.
   - `note_garden_01` (19, 0, 27): tiang catatan informasi kebun di dekat jagung.
   - `resource_temu_kunci_01` (-20, 0, 30): rumpun temu kunci di tepi rumpun bambu dan batu besar di cabang barat.
   - `npc_neighbor_01` (-14, 0, 15): bangku teras tetangga di rute barat.
   - `safe_return_home` (0, 0, 8): titik pemulihan posisi aman di depan rumah menghadap utara.
5. Pembagian petak kebun `plot_home_01` menjadi 4 kuadran titik tanam independen (`spot_0`, `spot_1`, `spot_2`, `spot_3`) dengan jarak antar-titik terverifikasi > 0.4 m.
6. Pemasangan jalur visual tanah (`Paths`) dari rumah ke gerbang, gerbang ke persimpangan, cabang timur, cabang barat, serta jalur lingkar selatan yang menghubungkan kedua cabang sehingga membentuk loop eksplorasi tanpa jalan buntu.
7. Pemasangan dinding pembatas perimeter (`PerimeterBoundaries`) pada keempat sisi terluar map (X=-40, X=40, Z=-35, Z=45) dengan `StaticBody3D` setinggi 4 meter.
8. Pembangunan volume recovery `FallRecoveryArea` (Area3D dengan BoxShape3D berukuran 200x2x200 m pada Y = -6.0) dan metode `recover_entity()` / `check_and_recover_entity()` untuk merestorasi entitas yang jatuh di bawah Y = -5.0 atau ke luar amplop ke `safe_return_home`.
9. Integrasi `scenes/world/level_graybox.tscn` ke dalam `scenes/main.tscn` menggantikan `GroundPlaceholder` lama.
10. Pembuatan automated test suite `tests/suites/test_level.gd` (kasus T24 & T25) serta pembaruan `tests/test_runner.gd` yang menguji integritas seluruh komponen level secara headless.

Batasan: Task ini tidak mengimplementasikan pengontrol first person (dijadwalkan pada PLY-001), interaksi raycast prompt (INT-001), maupun transaksi inventaris (INV-001).

## Perubahan dan perilaku akhir

- **Struktur Adegan 3D:** Berkas `scenes/world/level_graybox.tscn` menyediakan hierarki lengkap yang dapat dibuka dan diinstansiasi secara deterministik oleh engine Godot 4.7.2. Root node `LevelGraybox` memiliki skrip pembantu untuk akses landmark dan logika recovery.
- **Navigasi & Aksesibilitas:** Bukaan pintu teras selatan selebar 1.6 meter dan bukaan gerbang pekarangan selebar 2.2 meter menjamin pemain tidak membutuhkan navigasi presisi tinggi untuk bergerak keluar masuk rumah dan pekarangan.
- **Kenyamanan Spasial Spawn:** Titik `spawn_home` berada di dalam rumah pada (0, 0, 1), memiliki clearance luas terhadap seluruh dinding (minimal 3.0 meter ke pintu, 4.0 meter ke dinding barat/timur, 7.0 meter ke dinding utara) dan menghadap utara langsung ke arah meja buku resep `book_family`.
- **Rute Eksplorasi Sirkular:** Dari persimpangan `junction_path`, pemain dapat berjalan ke timur (jagung) atau barat (tetangga & temu kunci) lalu kembali melalui jalur lingkar selatan (Z=35) tanpa harus berbalik arah di lorong sempit.
- **Ketahanan Fisika & Safe Recovery:** Seluruh dinding, pembatas peta, meja, peti, dan lantai memiliki body collision. Jika terjadi anomali fisika atau entitas terjatuh di bawah level tanah (Y < -5.0) atau keluar batas amplop, sistem recovery secara instan memulihkan posisi entitas ke `safe_return_home` (0, 0, 8) dengan mereset kecepatan (`velocity = Vector3.ZERO`).

## File yang ditambahkan atau diubah

| Path Relatif | Jenis Perubahan | Tujuan |
| --- | --- | --- |
| `scripts/world/level_graybox.gd` | Baru | Skrip pengontrol level graybox: pemetaan landmark, akses titik tanam, dan penanganan recovery fisik |
| `scenes/world/level_graybox.tscn` | Baru | Adegan 3D graybox level lengkap (tanah, rumah, 18 landmark, 4 crop spot, jalur visual, collision, fall area) |
| `scripts/tools/build_level_graybox.gd` | Baru | Skrip generator scene prosedural Godot untuk merekonstruksi level_graybox.tscn secara deterministik |
| `scenes/main.tscn` | Diubah | Menginstansiasi `scenes/world/level_graybox.tscn` sebagai anak langsung menggantikan placeholder lama |
| `tests/suites/test_level.gd` | Baru | Suite pengujian otomatis untuk verifikasi pemuatan adegan, 18 landmark, 4 titik tanam, clearance spawn, collision, dan recovery (T24 & T25) |
| `tests/test_runner.gd` | Diubah | Menambahkan pendaftaran dan eksekusi suite `TestLevel` setelah `TestSetup` |
| `docs/TASKS.md` | Diubah | Memperbarui status task LVL-001 menjadi SELESAI dengan tautan laporan 003 |
| `docs/PROJECT_STATUS.md` | Diubah | Menambahkan entri pekerjaan selesai 003 dan memperbarui deskripsi pekerjaan terkini |
| `docs/completed_tasks/003-graybox-map-rumah-spawn-recovery.md` | Baru | Laporan resmi penyelesaian task LVL-001 sesuai format TEMPLATE.md |

## Verifikasi yang benar-benar dilakukan

| ID Pemeriksaan | Lingkungan / Input | Tindakan Nyata | Hasil Nyata | Status |
| --- | --- | --- | --- | --- |
| CHECK-01 | CLI Headless Script | `godot_console --headless --script res://scripts/tools/build_level_graybox.gd` | Generator mengeksekusi pembuatan nodetree dan serialisasi PackedScene ke `scenes/world/level_graybox.tscn` dengan status OK | LULUS |
| CHECK-02 | CLI Headless Test Runner | `godot_console --headless --script res://tests/test_runner.gd` | Test runner mengeksekusi `TestSetup` (T23, T24) dan `TestLevel` (T24.1, T24.2, T24.3, T25.1, T25.2, T25.3): 150 asersi lulus, 0 asersi gagal. Exit Code 0 | LULUS |
| CHECK-03 | CLI Headless Godot Bin | `godot.exe --headless --script res://tests/test_runner.gd` | Eksekusi langsung via biner `godot.exe` menghasilkan exit code 0 | LULUS |
| CHECK-04 | CLI Headless Smoke Test | `godot_console --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 60` | Main scene dengan instansiasi `LevelGraybox` berjalan penuh 60 frame tanpa error, warning, atau crash, keluar bersih dengan exit code 0 | LULUS |
| CHECK-05 | Pemeriksaan Integritas Landmark | Automated `test_landmarks_exist_and_coordinates()` | Seluruh 18 landmark terverifikasi ada di pohon scene dengan jarak terhadap koordinat acuan LEVEL_DESIGN <= 0.5 m dan Y >= 0 | LULUS |
| CHECK-06 | Pemeriksaan Titik Tanam Kuadran | Automated `test_plot_crop_spots()` | `plot_home_01` memiliki tepat 4 anak (`spot_0`..`spot_3`) dengan posisi berbeda pada masing-masing kuadran petak 2x2 m | LULUS |
| CHECK-07 | Pemeriksaan Clearance & Orientasi | Automated `test_spawn_and_safe_return_transforms_and_clearance()` | `spawn_home` menghadap utara (-Z) dengan jarak dinding > 3 m; `safe_return_home` berada di area terbuka depan rumah | LULUS |
| CHECK-08 | Pemeriksaan Collision Fisik | Automated `test_environmental_collisions()` | Objek lantai, 5 segmen dinding rumah, dan 4 batas perimeter terbukti memiliki StaticBody3D dengan CollisionShape3D valid | LULUS |
| CHECK-09 | Pemeriksaan Safe Recovery | Automated `test_recovery_mechanism()` | Karakter dummy yang dijatuhkan pada Y = -8.0 berhasil dipulihkan secara instan ke koordinat `safe_return_home` dan kecepatannya dinolkan | LULUS |

## Kriteria selesai

| Kriteria Selesai TASKS.md | Bukti Pemenuhan |
| --- | --- |
| Ruang dan skala dapat diperiksa | Terbukti dari dimensi amplop 80x80 m, rumah 8x10 m, pekarangan 16x12 m, dan petak 2x2 m yang telah dibuat dan terverifikasi pada CHECK-02 dan CHECK-05. |
| Spawn tidak berimpit collision | `spawn_home` berada di (0, 0, 1) dengan jarak minimum ke dinding terdekat sebesar 3.0 m (pintu selatan) dan 4.0 m (dinding timur/barat), terverifikasi pada CHECK-07. |
| Lokasi penting mempunyai ruang interaksi | Semua 18 landmark ditempatkan dengan ruang bebas di sekelilingnya (pintu 1.6 m, gerbang 2.2 m, petak terisolasi di pekarangan, jalan selebar 2.5–3.0 m). |
| Jalur tidak membutuhkan lompat presisi | Kontur tanah utama rata pada Y = 0 dengan permukaan lantai rumah pada Y = 0.05 m; bukaan jalan lebar tanpa celah atau rintangan lompatan. |
| Posisi aman valid | `safe_return_home` pada (0, 0, 8) berada di area terbuka pekarangan depan, terverifikasi bebas collision dan berfungsi sebagai target pemulihan jatuh pada CHECK-09. |
| Pengujian T24 dan T25 otomatis | Seluruh kasus uji T24 (arsitektur scene & landmark) dan T25 (clearance, collision, recovery) terimplementasi di `tests/suites/test_level.gd` dan lulus 100% pada CHECK-02. |

## Dampak, kompatibilitas dan keterbatasan

- **Kinerja:** Seluruh geometri disusun menggunakan node 3D standar (`StaticBody3D`, `BoxMesh`, `BoxShape3D`) dengan shared standard material, menjamin beban draw call dan render yang sangat ringan pada profil GPU host OpenGL 3.3.
- **Kompatibilitas:** Struktur node dan koordinat mengikuti ketat kamus lokasi pada `docs/LEVEL_DESIGN.md`. Penamaan node ID yang stabil memungkinkan task PLY-001 (karakter), INT-001 (interaksi), dan GARD-001 (berkebun) langsung mengaitkan logika tanpa refaktor nama node.
- **Keterbatasan:** Tahap graybox menggunakan bentuk geometris primitif berskala (kotak dan silinder) dengan warna pembeda sederhana sesuai prinsip graybox prototyping. Aset mesh stylized detail tinggi dan audio lingkungan akan ditambahkan pada milestone ART-001.

## Tindak lanjut dan handoff

- **Task berikutnya:** `PLY-001` — Gerak dan pandang first person serta collision pemain.
- **Prasyarat:** `scenes/world/level_graybox.tscn` siap pakai, `spawn_home` tervalidasi pada (0, 0, 1), `safe_return_home` pada (0, 0, 8), dan collision dinding aktif.
- **Acuan desain:** `docs/LEVEL_DESIGN.md` § 4 (tinggi kamera, orientasi pandang awal ke arah utara meja buku), `docs/UI_UX.md` (mapping aksi WASD, mouse look, invert Y default false, FOV default 75), dan `docs/TEST_PLAN.md` (T18, T25, T26).

## Penutupan catatan

Laporan ini menandai penutupan resmi task `LVL-001`. Dokumen `docs/PROJECT_STATUS.md` dan `docs/TASKS.md` telah diperbarui selaras dengan penerbitan laporan ini.
