# Laporan Selesai: Target Interaksi Objek, Prompt UI, Occlusion dan Pengendali Konteks Input (INT-001)

Dokumen ini mencatat penyelesaian implementasi task INT-001 sesuai aturan kerja `AGENTS.md` § 6.

## Identitas

- **ID task:** INT-001
- **Judul:** Target interaksi objek, prompt, occlusion, dan pengontrol konteks input
- **Tanggal selesai:** 27 Oktober 2026
- **Agent/pelaksana:** worker_int_001 (teamwork_worker)
- **Tahap produk:** P0 (Core Interaction, Physics Occlusion & Input Context Management)
- **Status:** Selesai (Lulus 100% verifikasi headless, 526 asersi lulus, 0 gagal, exit code 0)
- **Versi sumber/build:** Git working tree lokal, Godot 4.7.2-stable official

## Tujuan dan pemicu

Sesuai spesifikasi `PRD.md` FR02, `docs/TASKS.md` (bagian INT-001), `docs/CONTENT.md` § 14, `docs/UI_UX.md` § 3/4, dan `docs/PROTOTYPE.md` § 5, game memerlukan subsistem interaksi yang andal:
1. Pemain dapat membidik objek interaktif di dunia first person dalam jangkauan maksimal 2.0 meter dari kamera pandang.
2. Raycast pendeteksi wajib terhenti oleh penghalang solid di Layer 1 (Environment) sehingga objek di balik dinding tidak terbidik atau terinteraksi (occlusion check matematis, T27).
3. Tampilan reticle netral (titik kecil tengah layar) dan prompt interaksi kontekstual `[E] <Aksi> <Nama>` muncul di bawah reticle (+36px) tanpa merebut atau mengganggu klik mouse 3D (mouse filter ignore).
4. Pengendali konteks input (`InputManager`) bertingkat (stack-based context) mengelola transisi mode `WORLD`, `BOOK`, `STORAGE`, `KITCHEN`, `DIALOGUE`, dan `PAUSE`. Saat panel terbuka, mouse dibebaskan (`MOUSE_MODE_VISIBLE`), gerak dan pandang pemain dinonaktifkan (`movement_enabled = false`, `look_enabled = false`).
5. Proteksi kebocoran input (bleed-through prevention) diterapkan via event consumption (`get_viewport().set_input_as_handled()`) dan frame guard/action release suppression agar tombol penutup panel (E/Esc/Tab/B) tidak memicu aksi dunia pada tick yang sama (T28).
6. 12 landmark utama pada graybox level dipasangi komponen `Interactable` dengan prompt berbahasa Indonesia yang konsisten dengan desain naratif dan konten.

## Ruang lingkup

Ruang lingkup yang diselesaikan dalam task ini:
- `scripts/interaction/interactable.gd`: Komponen `Interactable` (`Area3D`) pada Layer 3 (`interactables` = 4), mask 0, monitoring false, monitorable true, properti ekspor (`interaction_id`, `target_name`, `prompt_action`, `enabled`, `is_interactable`), sinyal `interacted`, `focused`, `unfocused`, serta metode `get_prompt_text()` dan `interact(player)`.
- `scripts/interaction/interaction_detector.gd`: Raycast detector 2.0m (`target_position = Vector3(0, 0, -2.0)`) dengan `collision_mask = 5` (Layer 1 + Layer 3), `collide_with_areas = true`, `collide_with_bodies = true`. Memindai collider terdekat, memvalidasi kandidat `Interactable`, dan menolak target di balik dinding (`wall occlusion`). Dilengkapi metode `try_interact(player)` yang terintegrasi dengan validasi `InputManager`.
- `scenes/ui/interaction_prompt.tscn` & `scripts/ui/interaction_prompt.gd`: Scene UI berbasis `CanvasLayer` dengan `RootControl` (`mouse_filter = MOUSE_FILTER_IGNORE`), `Reticle` (ColorRect 4x4 tengah layar), dan `PromptPanel` (PanelContainer +36px di bawah reticle) dengan `PromptLabel` teks prompt kontras tinggi.
- `scripts/core/input_manager.gd`: Autoload singleton (`*res://scripts/core/input_manager.gd`) yang mengelola stack mode `ContextMode { WORLD, BOOK, STORAGE, KITCHEN, DIALOGUE, PAUSE }`, sinkronisasi mouse capture/release, gating player controller, pencegahan bleed-through (`can_interact_in_world()`, `suppress_action_until_released()`), dan aturan jeda simulasi per `PROTOTYPE.md` § 5 (KITCHEN tetap menjalankan simulasi, sedangkan BOOK/STORAGE/DIALOGUE/PAUSE menjeda).
- Pemasangan `Interactable` pada 12 landmark di `scripts/tools/build_level_graybox.gd` dan `scenes/world/level_graybox.tscn`:
  1. `book_family`: "Periksa Meja Resep" (`landmark_book`)
  2. `storage_home`: "Buka Peti" (`landmark_storage`)
  3. `station_kitchen_home`: "Periksa Dapur" (`landmark_kitchen`)
  4. `water_home`: "Ambil Air" (`landmark_water`)
  5. `container_starter`: "Ambil Wadah Starter" (`landmark_starter`)
  6. `reserve_home`: "Periksa Cadangan" (`landmark_reserve`)
  7. `resource_jagung_01`: "Periksa Jagung" (`landmark_jagung`)
  8. `resource_temu_kunci_01`: "Periksa Temu Kunci" (`landmark_temu_kunci`)
  9. `npc_neighbor_01`: "Bicara" (`landmark_neighbor`)
  10. `note_garden_01`: "Baca Catatan Kebun" (`landmark_note`)
  11. `plot_home_01`: "Periksa Petak" (`landmark_plot`)
  12. `bed_home`: "Istirahat" (`landmark_bed`)
- Integrasi Controller: `build_player_scene.gd` dan `scenes/player/player.tscn` memasang `InteractionDetector` di bawah `Head/Camera3D`. `scripts/player/player_controller.gd` mengikat aksi input "interact" (E) dan menghubungkan detector dengan prompt UI.
- Test Suite: `tests/suites/test_interaction.gd` dan registrasi Suite 6 pada `tests/test_runner.gd`, memverifikasi secara menyeluruh kasus uji T18, T27, dan T28.

Batas cakupan: Logika inventaris tas/peti dibangun pada `INV-001`, antarmuka resep pada `BOOK-001`, mekanik kebun pada `GARD-001/002`, dan alur masak pada `COOK-001/002`.

## Perubahan dan perilaku akhir

- **Akuisisi Target Presisi (T18):** `InteractionDetector` menembakkan raycast sepanjang 2.0 meter lurus ke arah pandang kamera (`Vector3(0, 0, -2.0)`). Ketika target interaktif berada dalam jarak <= 2.0m, target terfokus, sinyal `target_focused` dipancarkan, dan prompt teks ditampilkan. Target pada jarak > 2.0m diabaikan (`has_focused_target() == false`).
- **Oklusi Dinding Mutlak (T27):** Karena `collision_mask = 5` (Layer 1 Environment + Layer 3 Interactables), raycast menabrak permukaan dinding statis terlebih dahulu saat ada dinding antara kamera dan objek interaktif. Fungsi `find_interactable()` mendeteksi bahwa collider adalah dinding lingkungan (bukan interactable), sehingga target menjadi `null` dan prompt tidak muncul. Menekan tombol E di depan dinding tidak pernah menembus objek di belakangnya.
- **Hierarki Konteks Input (T28):** `InputManager` mengimplementasikan tumpukan konteks:
  - Mode `WORLD`: mouse terkunci ke tengah (`MOUSE_MODE_CAPTURED`), pergerakan WASD dan pandangan mouse aktif, detektor interaksi aktif.
  - Mode Modal (`BOOK`, `STORAGE`, `KITCHEN`, `DIALOGUE`, `PAUSE`): mouse bebas (`MOUSE_MODE_VISIBLE`), pergerakan dan pandangan dibekukan (`movement_enabled = false`, `look_enabled = false`), interaksi dunia diblokir.
  - Menutup panel dengan Esc/E memulihkan mode sebelumnya dari tumpukan secara LIFO (misal menutup PAUSE dari KITCHEN mengembalikan ke KITCHEN, bukan langsung ke WORLD).
- **Pencegahan Aksi Bocor (Bleed-Through Guard):** Saat modal ditutup, `Engine.get_process_frames()` dicatat sebagai `_last_closed_frame`. `can_interact_in_world()` mengembalikan `false` pada frame penutupan tersebut, dan aksi ditahan (`suppress_action_until_released`) sampai tombol dilepas, mencegah klik/tekan tombol penutup memicu interaksi dunia tanpa sengaja.
- **UI Responsif dan Non-Intrusif:** Reticle dan prompt panel menggunakan anchor relatif layar (`PRESET_CENTER`) dengan mouse filter `MOUSE_FILTER_IGNORE`, memastikan input klik mouse tetap lolos ke viewport 3D ketika bermain normal.

## File yang ditambahkan atau diubah

| Path Relatif | Jenis Perubahan | Tujuan |
|---|---|---|
| `scripts/interaction/interactable.gd` | Diubah | Komponen `Interactable` Area3D Layer 3, export target_name/prompt_action, sinyal interacted/focused/unfocused |
| `scripts/interaction/interaction_detector.gd` | Diubah | Raycast detector 2.0m mask 5, oklusi Layer 1, integrasi InputManager bleed-through guard |
| `scripts/ui/interaction_prompt.gd` | Baru | Skrip pengendali UI prompt dan reticle, koneksi sinyal detektor |
| `scenes/ui/interaction_prompt.tscn` | Baru | Scene CanvasLayer reticle dan panel prompt dengan anchor responsif |
| `scripts/core/input_manager.gd` | Baru | Autoload singleton pengelola konteks input (stack mode, player gating, bleed guard, simulasi pause) |
| `project.godot` | Diubah | Mendaftarkan autoload `InputManager="*res://scripts/core/input_manager.gd"` |
| `scripts/tools/build_level_graybox.gd` | Diubah | Menambahkan helper create_interactable dan memasang 12 interactable pada landmark |
| `scenes/world/level_graybox.tscn` | Diperbarui | Level graybox di-generate ulang dengan 12 Interactable Area3D Layer 3 |
| `scripts/tools/build_player_scene.gd` | Diubah | Memasang InteractionDetector RayCast3D (mask 5, 2.0m) di bawah Camera3D |
| `scenes/player/player.tscn` | Diperbarui | Adegan pemain di-generate ulang dengan InteractionDetector terpasang |
| `scripts/player/player_controller.gd` | Diubah | Menautkan aksi "interact", registrasi InputManager, dan pengikatan prompt UI |
| `scenes/main.tscn` | Diubah | Menginstansiasi InteractionPrompt UI pada adegan utama |
| `tests/suites/test_interaction.gd` | Baru | Suite pengujian otomatis komprehensif INT-001 (13 pengujian T18, T27, T28) |
| `tests/test_runner.gd` | Diubah | Mendaftarkan Suite 6: TestInteraction ke dalam harness runner utama |

## Verifikasi yang benar-benar dilakukan

| ID Uji | Lingkungan / Perintah | Tindakan | Hasil Nyata | Status |
|---|---|---|---|---|
| UJI-RUN-INT | `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"` | Menjalankan seluruh test runner otomatis (Suite 1..6) | 526 asersi lulus, 0 gagal, exit code 0 | LULUS |
| UJI-ADV-LVL | `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/adversarial_level_challenge.gd"` | Menjalankan 5 tantangan ketahanan level dan 18 landmark | 95 asersi lulus, 0 gagal, exit code 0 | LULUS |
| UJI-CHK-PRJ | `python ".agents/skills/godot-nodes-scenes/scripts/check_godot_project.py" .` | Validasi konsistensi struktur node, scene, skrip, dan UID | 0 errors, 0 warnings pada 33 file | LULUS |
| UJI-SMK-60F | `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 60"` | Smoke run 60 frame main.tscn dengan interaksi, player, graybox, UI | 60 frame dieksekusi bersih tanpa error/warning | LULUS |

## Kriteria selesai

- [x] 1. Satu target arah pandang, jangkauan 2.0m, dan oklusi dinding berfungsi benar (T18, T27).
- [x] 2. Tombol E menampilkan/melakukan aksi interaksi kontekstual dan memancarkan sinyal `interacted` (T18).
- [x] 3. Objek di balik dinding lingkungan (Layer 1) tidak terpilih dan tidak dapat diinteraksi (T27).
- [x] 4. Prompt interaksi hilang ketika target keluar dari jangkauan 2.0m (T18, T27).
- [x] 5. Seluruh 12 landmark utama pada graybox memiliki komponen `Interactable` dengan teks prompt berbahasa Indonesia yang valid (T27).
- [x] 6. Konteks dunia/panel/pause mengelola kebebasan mouse dan membekukan pergerakan/pandangan pemain (T28).
- [x] 7. Pencegahan kebocoran input (bleed-through prevention) menjamin input yang sama tidak memicu aksi dunia ketika panel ditutup (T28).
- [x] 8. Seluruh suite pengujian otomatis (`tests/test_runner.gd`) lulus 100% tanpa error penghambat (526 asersi lulus, exit code 0).

## Dampak, kompatibilitas dan keterbatasan

- **Kompatibilitas Sistem Lanjutan:** Fondasi `Interactable` dan `InputManager` dirancang langsung siap digunakan oleh task `INV-001` (buka peti, ambil starter), `BOOK-001` (meja resep), `GARD-001/002` (periksa petak), `WORLD-001` (ambil jagung, temu kunci, air), `COOK-001` (dapur), dan `SOC-001` (bicara tetangga).
- **Aturan Jeda Simulasi PROTOTYPE § 5:** `InputManager.is_simulation_paused()` secara akurat membedakan mode `KITCHEN` (simulasi memasak dan tanaman tetap berjalan) dari mode `BOOK`, `STORAGE`, `DIALOGUE`, dan `PAUSE` (simulasi dijeda).
- **Keterbatasan:** Transisi animasi fade pada prompt UI saat ini dijalankan instan dalam mode pengujian headless agar asersi pengujian deterministik tanpa jeda waktu.

## Tindak lanjut dan handoff

- **Task Berikutnya:** `INV-001` (Data item dan inventaris tas & peti, transfer item dua arah, dan pengambilan paket awal).
- **Prasyarat yang Dipenuhi:** Objek `storage_home` dan `container_starter` telah memiliki komponen `Interactable` yang siap menerima interaksi inventaris; sistem input konteks `STORAGE` telah siap di `InputManager`.
- **Rujukan Dokumen:** `docs/CONTENT.md` § 2, § 3, § 5, `docs/UI_UX.md` UI04, dan `docs/TASKS.md` (bagian INV-001).

## Penutupan catatan

Laporan ini menandai penutupan resmi milestone `INT-001`. Catatan pekerjaan selesai ditambahkan pada `docs/PROJECT_STATUS.md` dan status task diperbarui menjadi SELESAI di `docs/TASKS.md` sesuai aturan `AGENTS.md` § 6.
