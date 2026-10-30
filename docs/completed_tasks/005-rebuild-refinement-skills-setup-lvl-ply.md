# 005 — Audit dan Refinement Berbasis Skill Gamedev untuk SETUP-001, LVL-001, dan PLY-001

## Identitas

- **ID task:** REBUILD-001.
- **Judul:** Audit, Refinement, dan Rebuild Berbasis Praktik Terbaik Skill Gamedev untuk Fondasi SETUP-001, LVL-001, dan PLY-001.
- **Tanggal selesai:** 27 Oktober 2026.
- **Agent/pelaksana:** worker_rebuild_001 (Teamwork Worker).
- **Tahap produk:** P0 (Arsitektur Engine, Level Graybox, dan Kontrol Pemain).
- **Status:** Selesai.
- **Versi sumber/build:** Godot Engine v4.7.2.stable.official.ed1daf0bf (win64 official release); Git lokal.

## Tujuan dan pemicu

Sesuai instruksi pembaruan pengguna tanggal 27 Oktober 2026 ("lanjutkan progres game, tapi sebelum lanjut coba lakukan rebuild progres yang sudah jadi dengan menggunakan skill yang baru aku pasang..."), tim melakukan audit teknis dan penyelarasan menyeluruh terhadap tiga milestone yang telah selesai (`SETUP-001`, `LVL-001`, `PLY-001`). 

Pemasangan pustaka skill spesialis gamedev (`godot-gdscript`, `godot-nodes-scenes`, `godot-gdscript-headless-testing`, `godot-3d-essentials`, `godot-physics`, `physics-tuning`, `camera-systems`, `input-systems`, dan `game-feel`) mengungkap sejumlah peluang peningkatan penting:
1. `project.godot` belum mendefinisikan nama layer collision 3D fisik dan belum mengaktifkan interpolasi fisika rendering (`physics_interpolation`).
2. `tests/assertions.gd` dan `tests/test_runner.gd` belum terintegrasi dengan pelacak kesalahan mesin (`push_error`), masih menggunakan siklus Object `_init()` yang membatasi kemampuan coroutine (`await`), serta belum menyediakan asersi aproksimasi floating-point / Vector3.
3. `scenes/main.tscn` memiliki node `WorldEnvironment` kosong tanpa resource `Environment`, pencahayaan matahari putih polos tanpa palet hangat sore hari Nusantara (`ART_DIRECTION.md`), serta node root tanpa script pengelola (`Main`).
4. `level_graybox.tscn` dan `player.tscn` masih berjalan pada layer fisik default 1 tanpa pemisahan peran collision yang terstruktur, dan belum memanggil `reset_physics_interpolation()` saat pemindahan posisi (teleportasi/recovery).
5. `player_controller.gd` masih menggunakan `event.relative` yang sensitif terhadap perbesaran viewport pada mode stretch `canvas_items`, belum menerapkan properti snapping lereng (`floor_constant_speed`, `floor_snap_length`), belum memiliki bendera pembatas konteks input (`movement_enabled`, `look_enabled`), serta belum memiliki hook camera shake dan head bob yang rapi.

## Ruang lingkup

Ruang lingkup pekerjaan yang dikerjakan mencakup:
1. **Konfigurasi Project Settings (`project.godot`):**
   - Mendefinisikan penamaan 3D physics layers: Layer 1 `environment`, Layer 2 `player`, Layer 3 `interactables`, Layer 4 `triggers`.
   - Mengaktifkan `physics/common/physics_interpolation=true` untuk eliminasi jitter visual render tick vs physics tick.
2. **Harness & Pustaka Asersi Pengujian (`tests/assertions.gd`, `tests/test_runner.gd`):**
   - Menambahkan perutean `push_error(err_msg)` pada seluruh cabang kegagalan asersi agar terdaftar pada panel debugger engine dan CI stderr.
   - Menambahkan metode asersi aditif: `assert_ne()`, `assert_approx_equal()`, dan `assert_vector3_approx_equal()` tanpa mengubah tanda tangan asersi lama.
   - Memperbarui entri `test_runner.gd` dari `_init()` menjadi `func _initialize() -> void:` pada `SceneTree` dengan anotasi tipe statis (`:=`).
3. **Penyempurnaan Lingkungan Visual & Adegan Utama (`scenes/main.tscn`, `scripts/main.gd`):**
   - Membuat dan menempelkan `scripts/main.gd` (`class_name Main extends Node3D`) pada root node `Main`.
   - Menambahkan sub-resource `Environment` pada `WorldEnvironment` dengan `ProceduralSkyMaterial` (palet langit sore hari), `ambient_light_source = SKY`, kontribusi langit 0.85, energi 0.85, dan `tonemap_mode = TONE_MAPPER_FILMIC` (2).
   - Menyetel `DirectionalLight3D` ke warna matahari sore hangat `#E7B476` (`Color(0.906, 0.706, 0.463)`), energi 1.2, bayangan aktif dengan filter halus dan bias normal terkalibrasi.
   - Mempertahankan seluruh node penting: `Main`, `DirectionalLight3D`, `WorldEnvironment`, `LevelGraybox`, `Player` (beserta `Camera3D` dan `GroundPlaceholder`).
4. **Penyelarasan Graybox Level (`scenes/world/level_graybox.tscn`, `scripts/world/level_graybox.gd`, `scripts/tools/build_level_graybox.gd`):**
   - Menetapkan static bodies lingkungan pada layer 1 (`environment`).
   - Menetapkan `FallRecoveryArea` pada layer 4 (`triggers`, bitmask 8) dengan mask 2 (`player`, bitmask 2).
   - Memperbarui palet warna dan kekasaran PBR material graybox agar selaras dengan `ART_DIRECTION.md` § 4.
   - Menambahkan pemanggilan `reset_physics_interpolation()` saat level dimuat (`_ready`) dan saat entitas dipulihkan (`recover_entity`).
   - Menjaga seluruh 18 landmark ID, koordinat, 4 spot tanaman, dan collision name tetap 100% invarian.
5. **Penyempurnaan Pengontrol Pemain (`scenes/player/player.tscn`, `scripts/player/player_controller.gd`, `scripts/player/player_config.gd`, `scripts/tools/build_player_scene.gd`):**
   - Menggunakan `event.screen_relative` (dengan fallback aman ke `event.relative`) pada `_unhandled_input` untuk isolasi resolusi stretch window.
   - Mengonfigurasi stabilitas lereng `CharacterBody3D`: `floor_constant_speed = true`, `floor_snap_length = 0.2`, `floor_stop_on_slope = true`.
   - Menetapkan collision layer pemain ke layer 2 (`player`) dan mask ke 13 (`environment` [1] | `interactables` [4] | `triggers` [8]).
   - Menyediakan bendera kontrol konteks input: `movement_enabled: bool = true` dan `look_enabled: bool = true`.
   - Membangun hook camera shake berbasis trauma (`add_trauma`, peluruhan kuadratik pada `_process`) dan hook prosedural head bob (tetap nonaktif secara default sesuai PRD §9.5).
   - Menambahkan pemanggilan `reset_physics_interpolation()` dan pembersihan nilai trauma kamera di dalam `teleport_to`.
   - Menjaga invarian inti: kecepatan gerak tepat 3.0 m/s, tinggi mata istirahat 1.6 m, batas pitch vertikal [-85.0°, +85.0°].
6. **Ekspansi Suite Pengujian (`tests/suites/test_setup.gd`, `tests/suites/test_player.gd`):**
   - Menambahkan verifikasi nama layer 3D fisik, interpolasi, dan resource `WorldEnvironment` di `test_setup.gd`.
   - Menambahkan kasus uji snapping lereng, layer fisik, bendera gating input, trauma shake, dan stabilitas head bob di `test_player.gd`.

## Perubahan dan perilaku akhir

- **Stabilitas Sudut Pandang Mouse:** Gerakan kamera first-person kini menggunakan koordinat piksel mentah layar (`screen_relative`), sehingga sensitivitas mouse tidak lagi terdistorsi ketika jendela game diubah ukurannya atau dijalankan pada monitor resolusi berbeda.
- **Kenyamanan Traversal & Snapping Lereng:** Pemain menuruni lereng atau permukaan bersudut tanpa mengalami jitter "melayang/lepas kontak" berkat `floor_snap_length = 0.2` dan kecepatan konstan 3.0 m/s di semua kemiringan yang diizinkan (`floor_constant_speed = true`).
- **Pemisahan Layer Fisika Terstruktur:** Dunia, pemain, objek interaktif, dan pemicu area kini beroperasi pada layer eksplisit terdokumentasi (1, 2, 3, 4). `FallRecoveryArea` hanya memindai pemain pada mask 2, mencegah pemicuan salah oleh partikel atau benda statis.
- **Suasana Visual Indonesia 2045:** Adegan utama kini menampilkan langit sore hari dengan tone mapping Filmic yang lembut, bayangan matahari hangat terarah, dan pencahayaan ambient yang menyinari teras selatan rumah, menggantikan pemandangan abu-abu gelap bawaan engine.
- **Ketahanan Teleportasi & Interpolasi Fisika:** Pemain yang dipulihkan ke titik aman `safe_return_home` (0, 0, 8) tidak lagi mengalami efek "smearing" atau tarikan kamera karena `reset_physics_interpolation()` mereset buffer interpolasi visual seketika.
- **Kesiapan Konteks Input untuk INT-001:** Penambahan bendera `movement_enabled` dan `look_enabled` memungkinkan sistem dialog, buku resep, dan inventaris yang akan dibangun pada task berikutnya untuk membekukan gerak dan pandang pemain tanpa perlu merusak status controller.
- **Peningkatan Diagnostik Test Runner:** Seluruh asersi pengujian kini menghasilkan laporan engine native `push_error` jika terjadi kegagalan, dan asersi floating point / vector dievaluasi menggunakan toleransi presisi tinggi.

## File yang ditambahkan atau diubah

| Path Relatif | Jenis Perubahan | Tujuan |
| --- | --- | --- |
| `project.godot` | Diubah | Mendaftarkan 3D layer names (environment, player, interactables, triggers) dan mengaktifkan physics_interpolation |
| `scripts/main.gd` | Baru | Skrip pengendali root adegan utama (class_name Main extends Node3D) |
| `scenes/main.tscn` | Diubah | Menautkan scripts/main.gd, menambahkan Environment filmic & sky ambient, menyetel DirectionalLight3D hangat |
| `scripts/tools/build_level_graybox.gd` | Diubah | Menyetel layer 1 pada static bodies, layer 4/mask 2 pada FallRecoveryArea, memperbarui palet PBR |
| `scenes/world/level_graybox.tscn` | Diperbarui | Adegan level graybox ter-generate ulang dengan layer fisika dan material PBR selaras ART_DIRECTION.md |
| `scripts/world/level_graybox.gd` | Diubah | Menambahkan pemanggilan reset_physics_interpolation pada _ready dan recover_entity |
| `scripts/player/player_config.gd` | Diubah | Menambahkan konstanta layer fisika (1, 2, 4, 8) dan parameter game feel (trauma decay, shake, bob) |
| `scripts/tools/build_player_scene.gd` | Diubah | Menyetel collision_layer = 2, collision_mask = 13, floor_constant_speed, floor_snap_length pada adegan pemain |
| `scenes/player/player.tscn` | Diperbarui | Adegan pemain ter-generate ulang dengan layer 2, mask 13, dan konfigurasi snapping lereng |
| `scripts/player/player_controller.gd` | Diubah | Menerapkan screen_relative, slope properties, input gating, trauma shake hook, head bob hook, dan reset interpolasi |
| `tests/assertions.gd` | Diubah | Menambahkan push_error pada kegagalan dan metode pembantu assert_ne, assert_approx_equal, assert_vector3_approx_equal |
| `tests/test_runner.gd` | Diubah | Transisi ke _initialize() pada SceneTree dengan tipe statis inferensi (:=) |
| `tests/suites/test_setup.gd` | Diubah | Menambahkan asersi layer fisika 3D, interpolasi, DirectionalLight3D palet sore, dan WorldEnvironment |
| `tests/suites/test_player.gd` | Diubah | Menambahkan test_skills_slope_and_collision_layers, test_skills_input_gating_flags, test_skills_camera_shake_and_head_bob |

## Verifikasi yang benar-benar dilakukan

| ID Uji | Lingkungan / Perintah | Tindakan | Hasil Nyata | Status |
| --- | --- | --- | --- | --- |
| UJI-RUN-01 | `godot_console --headless --script res://tests/test_runner.gd` | Menjalankan seluruh test suite otomatis (Setup, Level, Adv Level, Player, Adv Player) | 358 asersi lulus, 0 gagal, exit code 0 | LULUS |
| UJI-ADV-01 | `godot_console --headless --script res://tests/adversarial_level_challenge.gd` | Menjalankan 5 tantangan ketahanan level (clearance, doorway, bounds, recovery, 18 landmark) | 95 asersi lulus, 0 gagal, exit code 0 | LULUS |
| UJI-CHL-01 | `godot_console --headless --script res://tests/challenger_lvl_001_runner.gd` | Menjalankan harness stress level LVL-001 | 107 asersi lulus, 0 gagal, exit code 0 | LULUS |
| UJI-CHP-01 | `godot_console --headless --script res://tests/challenger_ply_001_runner.gd` | Menjalankan 7 tantangan empiris kontrol pemain PLY-001 | 62 asersi lulus, 0 gagal, verdict APPROVE, exit code 0 | LULUS |
| UJI-CHK-01 | `python ".agents/skills/godot-nodes-scenes/scripts/check_godot_project.py" .` | Memeriksa integritas referensi adegan, skrip, dan node | 0 errors, 0 warnings pada 28 file yang diperiksa | LULUS |
| UJI-SMK-01 | `godot_console --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 60` | Menjalankan adegan utama selama 60 frame headless | 60 frame tereksekusi bersih tanpa error/warning, exit code 0 | LULUS |

## Kriteria selesai

- [x] 1. `project.godot`: Layer names 3D physics (environment, player, interactables, triggers) terdaftar dan `physics/common/physics_interpolation=true` aktif.
- [x] 2. `tests/assertions.gd`: Seluruh pesan kegagalan asersi dialirkan ke `push_error(err_msg)` dan metode aditif `assert_ne`, `assert_approx_equal`, `assert_vector3_approx_equal` berfungsi penuh tanpa mengubah tanda tangan metode lama.
- [x] 3. `tests/test_runner.gd`: Beralih ke `func _initialize() -> void:` pada `SceneTree` dengan dukungan `await`/async dan tetap mempertahankan semantik kode keluar `quit(0)` saat semua lulus dan `quit(1)` saat ada kegagalan.
- [x] 4. `tests/suites/test_setup.gd`: Menambahkan asersi layer fisika dan konfigurasi `WorldEnvironment` serta `DirectionalLight3D`.
- [x] 5. `scenes/main.tscn` & `scripts/main.gd`: Terpasang skrip root `Main`, `WorldEnvironment` terkonfigurasi dengan `ProceduralSkyMaterial` dan tonemapper Filmic, matahari disetel hangat `#E7B476`, dan seluruh node hierarki lama terjaga utuh.
- [x] 6. `scenes/world/level_graybox.tscn` & `scripts/world/level_graybox.gd`: Collision layer static body teratur pada layer 1, `FallRecoveryArea` pada layer 4 dengan mask 2, seluruh 18 landmark invarian, dan `reset_physics_interpolation()` dipanggil pada load dan recovery.
- [x] 7. `scenes/player/player.tscn` & `scripts/player/player_controller.gd`: Menggunakan `screen_relative`, properti lereng aktif, collision layer 2 dan mask 13, bendera gating `movement_enabled`/`look_enabled`, camera shake trauma hook, head bob hook, dan pemanggilan `reset_physics_interpolation()` saat teleportasi, dengan kecepatan 3.0 m/s dan tinggi mata 1.6 m terjaga mutlak.
- [x] 8. Seluruh perintah verifikasi headless, adversarial challenge, linter script, dan smoke run lulus 100% tanpa regresi.

## Dampak, kompatibilitas dan keterbatasan

- **Kompatibilitas Penuh (Zero Regression):** Seluruh 325 asersi baseline tidak hanya tetap lulus, tetapi total asersi yang divalidasi meningkat menjadi 358 pada `test_runner.gd`, ditambah 264 asersi pada suite challenger/adversarial independen.
- **Pencegahan Masalah di Milestone Berikutnya:** Pemasangan layer fisika 3D dan bendera gating input secara langsung mengantisipasi kebutuhan `INT-001` (Raycast Interaction Detector & Context Manager), sehingga `INT-001` dapat langsung menargetkan layer 3 (`interactables`) dan memblokir pergerakan saat menu/dialog terbuka tanpa memerlukan refactoring fondasi.
- **Keterbatasan:** Detail visual akhir (mesh poligon tinggi dedaunan, shader angin, audio footprint) tetap berada pada cakupan milestone `ART-001`. Material graybox saat ini merupakan graybox prototype berbasis standar PBR.

## Tindak lanjut dan handoff

- **Task Berikutnya:** `INT-001` (Target interaksi objek, prompt, occlusion, dan pengontrol konteks input).
- **Prasyarat:** Fondasi fisik, layer 3D, kendali kamera screen-relative, dan bendera input gating telah siap 100%.
- **Dokumen Acuan:** `docs/UI_UX.md`, `docs/CONTENT.md` § 14, dan `docs/TASKS.md` (bagian INT-001).

## Penutupan catatan

Laporan ini menandai penutupan resmi milestone `REBUILD-001`. Catatan ringkasan telah ditambahkan pada `docs/PROJECT_STATUS.md` dan `docs/TASKS.md` diperbarui sesuai aturan kerja `AGENTS.md` § 6.
