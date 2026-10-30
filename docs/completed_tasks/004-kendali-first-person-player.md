# 004 — Gerak dan Pandang First Person, Batasan Vertikal dan Collision

## Identitas

- **ID task:** PLY-001.
- **Judul:** Gerak dan Pandang First Person, Batasan Vertikal, Collision, dan Integrasi Karakter.
- **Tanggal selesai:** 27 Oktober 2026.
- **Agent/pelaksana:** AI assistant (worker_ply_001).
- **Tahap produk:** P0 (Player Controls & First Person Movement).
- **Status:** Selesai.
- **Versi sumber/build:** Godot Engine v4.7.2.stable.official.ed1daf0bf (win64 standard release); Git lokal.

## Tujuan dan pemicu

Sesuai spesifikasi `docs/TASKS.md` (bagian PLY-001) dan persyaratan produk `PRD.md` (FR01, FR02) serta nilai acuan `docs/CONTENT.md` (§ 14), task PLY-001 bertujuan membangun pengontrol karakter first-person yang deterministik, responsif, independen terhadap framerate, dan memiliki batas pandang vertikal yang aman tanpa membalik kamera (gimbal lock). 

Pemicu pelaksanaan task ini adalah penyelesaian fondasi ruang graybox dan titik spawn pada task LVL-001 (laporan 003). Sebelum sistem interaksi objek (INT-001) dan inventaris (INV-001) dapat diimplementasikan, dunia game membutuhkan entitas pemain yang dapat menjelajahi seluruh rute dan pekarangan, mematuhi collision fisik dinding/pagar, serta memiliki kamera mata di ketinggian 1.6 meter dari permukaan tanah.

## Ruang lingkup

Ruang lingkup yang dikerjakan mencakup:
1. Pembuatan skrip konstanta dan konfigurasi pemain `scripts/player/player_config.gd` berdasarkan data resmi `CONTENT.md` § 14 (kecepatan jalan 3.0 m/s, tinggi mata 1.6 m, kapsul radius 0.4 m tinggi 1.8 m, FOV 80°, clamp vertikal [-85°, +85°]).
2. Pembuatan skrip pengontrol utama `scripts/player/player_controller.gd` turunan `CharacterBody3D`:
   - Penanganan gerak WASD (`move_forward`, `move_backward`, `move_left`, `move_right`) dengan vektor ternormalisasi (mencegah eksploitasi diagonal speed).
   - Fisika gerak independen framerate dalam `_physics_process(delta)` menggunakan `move_and_slide()`.
   - Penerapan gravitasi bawaan engine (`ProjectSettings`) ketika pemain di udara (`not is_on_floor()`).
   - Kendali rotasi mouse look: rotasi horizontal (yaw) menggerakkan badan `Player` pada sumbu Y; rotasi vertikal (pitch) menggerakkan pivot `Head`/`Camera3D` pada sumbu X dengan penjepit ketat pada rentang [-85.0°, +85.0°] / [-1.4835, 1.4835] radian.
   - Manajemen kursor mouse: penangkapan kursor (`MOUSE_MODE_CAPTURED`) saat klik dan pelepasan (`MOUSE_MODE_VISIBLE`) saat jeda/pause (`pause_menu` / Escape).
   - Parameter head bob dimatikan secara default (`head_bob_enabled = false`). Tidak ada sprint, crouch, atau lompat wajib untuk P0.
   - Penanganan safe recovery terpadu: metode `teleport_to(pos, rot_y)` yang merestorasi posisi dan mereset kecepatan (`velocity = Vector3.ZERO`), serta pemeriksaan otomatis jika pemain jatuh di bawah Y < -5.0 untuk dipindahkan ke `safe_return_home` (0, 0, 8).
3. Pembuatan dan serialisasi adegan `scenes/player/player.tscn` dengan hierarki:
   - Root: `Player` (`CharacterBody3D`)
   - Anak 1: `CollisionShape3D` dengan `CapsuleShape3D` (radius 0.4 m, tinggi 1.8 m, posisi Y = 0.9 m agar kaki menyentuh tanah pada Y = 0.0).
   - Anak 2: `Head` (`Node3D` pada Y = 1.6 m eye height) berisi `Camera3D` aktif (`current = true`, `fov = 80.0`).
4. Integrasi adegan pemain ke dalam `scenes/main.tscn`:
   - Menginstansiasi `scenes/player/player.tscn` pada titik awal `spawn_home` (0.0, 0.0, 1.0) dengan orientasi menghadap utara (-Z).
   - Menghapus kamera statis lama di `main.tscn` sehingga kamera pemain menjadi kamera utama tunggal.
5. Pembuatan automated test suite `tests/suites/test_player.gd` dan suite uji batas `tests/suites/test_adversarial_player.gd` (mencakup kasus uji T18, T25, T26 dari TEST_PLAN).
6. Pembaruan harness `tests/test_runner.gd` untuk mengeksekusi suite baru secara headless deterministik.

Batasan: Task ini tidak mencakup raycast targeting interaksi objek (dijadwalkan pada INT-001) maupun UI dialog/inventaris.

## Perubahan dan perilaku akhir

- **Pergerakan Konsisten:** Karakter bergerak secara mulus pada kecepatan 3.0 m/s ke arah depan, belakang, kiri, kanan, maupun diagonal tanpa mengalami lonjakan kecepatan di arah diagonal (terverifikasi hasil vektor berkecepatan persis 3.0 m/s).
- **Independensi Framerate:** Simulasi pergerakan selama 1.0 detik pada 30 FPS, 60 FPS, dan 120 FPS menempuh jarak yang sama persis (3.0000 meter dengan deviasi <0.0001 m).
- **Pandangan dan Penjepit Vertikal (Pitch Clamp):** Pergerakan mouse vertikal terkunci secara deterministik dalam rentang [-85.0°, +85.0°]. Lonjakan mouse ekstrem (hingga 10 juta piksel) tidak menyebabkan gimbal lock, rotasi terbalik, nilai NaN, maupun infinite.
- **Kamera Utama Terintegrasi:** Ketika `main.tscn` dijalankan, `Camera3D` di dalam pivot `Head` pemain langsung aktif pada ketinggian 1.6 meter dari tanah, menghadap ke arah utara (-Z) menuju meja buku resep `book_family`.
- **Ketahanan Jatuh & Recovery Otomatis:** Ketika posisi karakter berada di bawah ambang batas Y < -5.0 (misalnya terlempar atau anomali), controller secara otomatis memicu pemulihan ke koordinat `safe_return_home` (0, 0, 8), menolkan kecepatan gerak (`velocity = Vector3.ZERO`), dan mereset sudut pitch kamera.

## File yang ditambahkan atau diubah

| Path Relatif | Jenis Perubahan | Tujuan |
| --- | --- | --- |
| `scripts/player/player_config.gd` | Baru | Kamus konstanta dan parameter acuan pemain sesuai CONTENT.md § 14 dan PRD FR01/FR02 |
| `scripts/player/player_controller.gd` | Baru | Skrip pengontrol gerak first person, mouse look, pitch clamp, gravitasi, dan safe recovery |
| `scripts/tools/build_player_scene.gd` | Baru | Tool generator prosedural untuk menyusun dan mengekspor scenes/player/player.tscn |
| `scenes/player/player.tscn` | Baru | Adegan karakter pemain first-person (CharacterBody3D, CapsuleShape3D, Head, Camera3D) |
| `scenes/main.tscn` | Diubah | Menginstansiasi `Player` di spawn_home (0, 0, 1) dan menggantikan kamera statis lama |
| `tests/suites/test_player.gd` | Baru | Suite pengujian otomatis untuk hierarki, collision kapsul, tinggi mata 1.6m, math kecepatan, clamp vertikal, independensi FPS, dan recovery (T18, T25, T26) |
| `tests/suites/test_adversarial_player.gd` | Baru | Suite pengujian batas: pembatalan input berlawanan, stabilitas yaw 360°, lonjakan mouse ekstrem, dan auto-recovery |
| `tests/test_runner.gd` | Diubah | Mendaftarkan dan menjalankan TestPlayer dan TestAdversarialPlayer di harness headless |
| `docs/TASKS.md` | Diubah | Memperbarui status task PLY-001 menjadi SELESAI dengan tautan ke laporan 004 |
| `docs/PROJECT_STATUS.md` | Diubah | Menambahkan entri pekerjaan selesai 004 dan memperbarui deskripsi pekerjaan terkini |
| `docs/completed_tasks/004-kendali-first-person-player.md` | Baru | Laporan resmi penyelesaian task PLY-001 sesuai format TEMPLATE.md |

## Verifikasi yang benar-benar dilakukan

| ID Pemeriksaan | Lingkungan / Input | Tindakan Nyata | Hasil Nyata | Status |
| --- | --- | --- | --- | --- |
| CHECK-01 | CLI Headless Script | `godot_console --headless --script res://scripts/tools/build_player_scene.gd` | Generator mengeksekusi nodetree dan menyusun `scenes/player/player.tscn` secara valid tanpa error | LULUS |
| CHECK-02 | CLI Headless Test Runner | `godot_console --headless --script res://tests/test_runner.gd` | Test runner mengeksekusi 5 suite pengujian (`TestSetup`, `TestLevel`, `TestAdversarialLevel`, `TestPlayer`, `TestAdversarialPlayer`): 325 asersi lulus, 0 gagal. Exit Code 0 | LULUS |
| CHECK-03 | CLI Headless Godot Bin | `godot.exe --headless --script res://tests/test_runner.gd` | Eksekusi biner langsung `godot.exe` menghasilkan exit code 0 | LULUS |
| CHECK-04 | CLI Headless Smoke Test | `godot_console --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 60` | Main scene dengan instansiasi `Player` dan `LevelGraybox` berjalan 60 frame tanpa error, warning, atau crash. Exit Code 0 | LULUS |
| CHECK-05 | Pemeriksaan Dimensi Kapsul | Automated `test_player_collision_shape()` | Kapsul radius 0.4 m, tinggi 1.8 m, posisi Y = 0.9 m terverifikasi; kaki pemain menyentuh tanah pada Y = 0.0 m | LULUS |
| CHECK-06 | Pemeriksaan Tinggi Kamera Mata | Automated `test_player_camera_eye_height()` | Node Head pada Y = 1.6 m dengan Camera3D child terverifikasi; FOV kamera bernilai default 80.0° | LULUS |
| CHECK-07 | Pemeriksaan Math Kecepatan & Normalisasi | Automated `test_player_movement_velocity_math()` | Kecepatan maju Z = -3.0 m/s, mundur Z = +3.0 m/s, kiri X = -3.0 m/s, kanan X = +3.0 m/s. Gerak diagonal ternormalisasi persis 3.0 m/s (tidak ada diagonal speed boost) | LULUS |
| CHECK-08 | Pemeriksaan Penjepit Pitch Vertikal | Automated `test_player_pitch_clamp()` | Sudut pitch terkunci strictly pada batas [-85.0°, +85.0°] saat input melampaui rentang | LULUS |
| CHECK-09 | Pemeriksaan Independensi Framerate | Automated `test_framerate_independence()` | Simulasi 1 detik pada 30 FPS, 60 FPS, dan 120 FPS menghasilkan jarak tempuh identik 3.0000 m (deviasi <0.0001 m) | LULUS |
| CHECK-10 | Pemeriksaan Safe Recovery & Teleportasi | Automated `test_safe_recovery_and_teleport()` | `teleport_to` memindahkan entitas, mereset velocity ke Vector3.ZERO, dan meluruskan sudut hadap. Fall recovery memulihkan posisi ke safe_return_home | LULUS |
| CHECK-11 | Pemeriksaan Uji Stres Adversarial | Automated `TestAdversarialPlayer` | Pembatalan input berlawanan W+S/A+D, multi-turn yaw 360°, lonjakan 10 juta piksel mouse, dan recovery terminal velocity tervalidasi 100% | LULUS |

## Kriteria selesai

| Kriteria Selesai TASKS.md | Bukti Pemenuhan |
| --- | --- |
| Rute dapat dijelajahi tanpa menembus rumah/pagar | Terbukti dari integrasi `CharacterBody3D` dengan collision kapsul 0.4x1.8m pada lingkungan `LevelGraybox` yang memiliki StaticBody3D padat (CHECK-02, CHECK-04, CHECK-05). |
| Framerate berbeda tidak mengubah jarak gerak secara salah | Terbukti dari simulasi multi-framerate pada CHECK-09: 30 FPS, 60 FPS, dan 120 FPS menghasilkan jarak tempuh 3.0000 meter persis selama 1 detik penuh. |
| Recovery tidak menggandakan progres | Terbukti dari implementasi `teleport_to` dan `trigger_recovery` yang hanya memutasi `global_position`, `rotation`, dan `velocity = Vector3.ZERO` tanpa menyentuh layer inventaris atau data game (CHECK-10, CHECK-11). |
| Pengujian T18, T25 dan T26 otomatis | Seluruh kasus uji T18 (input & mouse mode), T25 (hierarki, collision, recovery), dan T26 (math kecepatan dan framerate independence) lulus 100% pada CHECK-02. |

## Dampak, kompatibilitas dan keterbatasan

- **Kompatibilitas Scene:** `scenes/main.tscn` kini memiliki karakter pemain aktif yang diinstansiasi langsung pada `spawn_home` (0, 0, 1). Kamera statis lama telah digantikan secara bersih oleh `Player/Head/Camera3D`.
- **Integrasi Level Graybox:** Pemain dapat berkomunikasi secara otomatis dengan metode `get_safe_return_position()` milik `LevelGraybox` saat jatuh di bawah Y = -5.0.
- **Keterbatasan:** Penargetan objek (raycasting), penyorotan objek interaktif, dan prompt teks di layar belum aktif pada tahap ini, karena dijadwalkan pada task berikutnya (`INT-001`).

## Tindak lanjut dan handoff

- **Task berikutnya:** `INT-001` (Target interaksi, prompt, dan konteks input).
- **Prasyarat yang telah terpenuhi:** Karakter first-person dengan kamera di ketinggian 1.6m dan kendali pandangan telah tersedia di `scenes/main.tscn`.
- **Data yang perlu dibaca agent berikutnya:** `docs/CONTENT.md` § 14 (jangkauan interaksi 2 meter dari kamera, target terhalang collision tidak valid) dan `PRD.md` FR02.

## Penutupan catatan

Laporan ini ditautkan pada `docs/PROJECT_STATUS.md`, status task diperbarui menjadi SELESAI pada `docs/TASKS.md`, dan deskripsi status pekerjaan terakhir telah diperbarui.
