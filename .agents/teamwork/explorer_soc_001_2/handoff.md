# Handoff Report: Dialogue UI/UX & 3D World Integration (SOC-001)

**Agent:** `explorer_soc_001_2` (Dialogue UI/UX Explorer)  
**Parent Conversation ID:** `e0d1bd43-d851-4429-b584-da0f2b6c5816`  
**Working Directory:** `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_soc_001_2\`  
**Milestone:** SOC-001  
**Timestamp:** 2026-10-28T18:33:00Z  

---

## 1. Observation

1. **Existing Input Context & Mouse Gating Architecture:**
   - File `scripts/core/input_manager.gd`:
     - Line 11: `ContextMode.DIALOGUE` sudah terdaftar di `enum ContextMode`.
     - Line 58: `func is_simulation_paused() -> bool: return ctx in [ContextMode.BOOK, ContextMode.STORAGE, ContextMode.DIALOGUE, ContextMode.PAUSE]`.
     - Lines 72-73: `push_context()` memanggil `_sync_mouse_mode()` dan `_sync_player_gating()`.
     - Lines 87, 101, 116: Penutupan konteks mencatat `_last_closed_frame = Engine.get_process_frames()`.
     - Lines 124-129: `func can_interact_in_world() -> bool` memeriksa `Engine.get_process_frames() == _last_closed_frame`, menolak interaksi dunia pada frame penutupan modal.
     - Lines 150-157: `_sync_mouse_mode()` menyetel `Input.mouse_mode = Input.MOUSE_MODE_VISIBLE` saat dalam modal, dan `Input.MOUSE_MODE_CAPTURED` saat di dunia.
     - Lines 158-172: `_sync_player_gating()` menyetel `_player.movement_enabled = false` dan `_player.look_enabled = false` saat dalam modal.

2. **Existing 3D World Landmark & Collision:**
   - File `scenes/world/level_graybox.tscn` (baris 829–852):
     - Node `npc_neighbor_01` (`Node3D`) berada di koordinat `Vector3(-14, 0, 15)`.
     - Node anak `Bench` (`StaticBody3D`) di `Vector3(0, 0.4, 0)` dengan `CollisionShape3D` berbentuk box ukuran `Vector3(1.8, 0.8, 0.8)`.
     - Node anak `Interactable` (`Area3D`) di `Vector3(0, 0.4, 0)` dengan `collision_layer = 4` (Layer 3: interactables, bitmask 1 << 2 = 4), `monitoring = false`, `monitorable = true`, script `res://scripts/interaction/interactable.gd`, `interaction_id = "landmark_neighbor"`, `prompt_action = "Bicara"`.
     - `CollisionShape3D` anak `Interactable` berbentuk box ukuran `Vector3(1.8, 0.8, 0.8)`.
   - File `scripts/player/player_controller.gd` (baris 46, 164–180):
     - `InteractionDetector` adalah RayCast3D dengan `max_interaction_distance = 2.0` meter dan collision mask 5 (Layer 1 Environment + Layer 3 Interactables).
     - Menekan tombol `interact` ('E') memanggil `interaction_detector.try_interact(self)` dan mengonsumsi event via `get_viewport().set_input_as_handled()`.
   - File `scripts/interaction/interactable.gd` (baris 35–39):
     - `get_prompt_text()` menghasilkan `"[E] Bicara"` karena `target_name = ""` dan `prompt_action = "Bicara"`.

3. **Existing World Wiring Gap in Main:**
   - File `scenes/main.tscn` (baris 49–55): Memiliki instance `HUD`, `InventoryUI`, `BookUI`, `KitchenUI`, namun BELUM memiliki instance `DialogueUI`.
   - File `scripts/main.gd` (baris 18–105): Memiliki fungsi `_wire_inventory_and_landmarks()` yang menyambungkan 12 landmark (`container_starter`, `storage_home`, `book_family`, `note_garden_01`, `plot_home_01`, `resource_jagung_01`, `resource_temu_kunci_01`, `reserve_home`, `bed_home`, `station_kitchen_home`), namun BELUM menyambungkan landmark ke-13 `npc_neighbor_01`.

4. **UI/UX & Dialogue Specification Requirements:**
   - `docs/UI_UX.md` UI07:
     - Panel bawah, semi-transparan/solid latar belakang.
     - Nama tokoh ("Tetangga"), teks singkat (dapat dibaca langsung tanpa wajib animasi ketik), maksimal 3 pilihan terlihat sekaligus ditambah Tutup.
     - Teks dapat dibaca ulang.
     - Pilihan berbagi hanya aktif jika hidangan tersedia; teks menyebut jumlah dan sumber.
     - *"E yang memulai dialog tidak sekaligus memilih pilihan pertama."*
     - Popup konfirmasi berbagi hidangan modal di atas dialog: *"Bagikan 1 porsi hidangan ini?"* dengan [Ya, Bagikan] dan [Batal].
   - `docs/UI_UX.md` § 4:
     - Esc menutup konfirmasi terlebih dahulu sebelum menutup panel induk.
     - Mouse bebas saat modal terbuka, terkunci saat kembali ke dunia.
     - Dialog menjeda simulasi kebun dan dapur.
   - `docs/CONTENT.md` § 10 & § 11:
     - Berbagi mengonsumsi 1 hidangan di tas atau peti rumah melalui konfirmasi eksplisit.
     - Teks menyebut stok rumah bila relevan.
     - Mengaktifkan flag `meal_used = true`.
     - Teks penutup P0: *"Satu resep selesai. Kebun ini baru dimulai."*
     - Resep selesai saat output dibuat, penutup P0 terjadi saat `recipe_completed` dan `meal_used` sama-sama benar.

---

## 2. Logic Chain

1. **Dari Observasi 1 (InputManager) & Observasi 4 (UI_UX.md § 4):**
   - Karena `InputManager` telah memiliki `ContextMode.DIALOGUE` dan logika pembebasan mouse (`Input.MOUSE_MODE_VISIBLE`), pembekuan kendali pemain (`movement_enabled = false`, `look_enabled = false`), serta jeda waktu simulasi (`is_simulation_paused() = true`), maka pembukaan dan penutupan UI dialog cukup memanggil `InputManager.push_context(ContextMode.DIALOGUE)` dan `InputManager.consume_and_close(&"pause_menu")`.
   - Mekanisme anti-bleed-through closing frame sudah dijamin oleh `_last_closed_frame` dan `can_interact_in_world()`.

2. **Dari Observasi 2 (PlayerController & Interactable) & Observasi 4 (UI_UX.md UI07):**
   - Ketika pemain menekan 'E' pada landmark tetangga, event 'E' dikonsumsi di `player_controller.gd:179` via `set_input_as_handled()`.
   - Namun, jika tombol pilihan dialog pertama langsung menerima fokus pada frame yang sama, pemain yang menahan atau menekan 'E' berisiko memicu pilihan pertama secara instan.
   - Oleh karena itu, logika pembukaan dialog di `DialogueUI.open()` wajib memanggil `InputManager.suppress_action_until_released(&"interact")` dan menunda fokus awal ke tombol pertama menggunakan `call_deferred("_grab_initial_focus")`. Hal ini secara mutlak memenuhi aturan UI07: *"E yang memulai dialog tidak sekaligus memilih pilihan pertama."*

3. **Dari Observasi 2 (LevelGraybox) & Observasi 4 (LEVEL_DESIGN.md § 2):**
   - Node 3D `npc_neighbor_01` telah berada di posisi `Vector3(-14, 0, 15)` dengan collision shape static box `(1.8, 0.8, 0.8)` dan Area3D interaksi layer 3 dengan prompt `"[E] Bicara"`.
   - Landmark ini sudah diverifikasi oleh `test_level.gd`, `test_adversarial_level.gd`, dan `test_interaction.gd`.
   - Tidak ada modifikasi yang diperlukan pada layer atau posisi collider, sehingga resiko regresi adalah nol.

4. **Dari Observasi 3 (Main Scene & Main Script):**
   - Karena `scenes/main.tscn` belum memuat `DialogueUI` dan `scripts/main.gd` belum menyambungkan `npc_neighbor_01`, maka tugas implementasi adalah menambahkan instance `DialogueUI.tscn` ke `main.tscn` dan menambahkan fungsi callback `_on_neighbor_interacted` di `main.gd` yang memicu `InputManager.push_context(ContextMode.DIALOGUE)` dan `dialogue_ui.open()`.

5. **Dari Observasi 4 (Modal Konfirmasi Berbagi):**
   - Menghadirkan `ConfirmModal` sebagai kontrol anak di dalam `DialogueUI.tscn`.
   - Mengatur perutean tombol Esc di `DialogueUI._unhandled_input`: jika modal konfirmasi terlihat, Esc hanya menutup modal konfirmasi dan mengembalikan fokus keyboard ke tombol pilihan dialog sebelumnya, dengan `set_input_as_handled()`. Jika modal konfirmasi tidak aktif, Esc menutup dialog dan mengembalikan konteks ke dunia.

---

## 3. Caveats

1. **Logika Internal Pohon Dialog & Konsumsi Item:**
   - Logika internal data dictionary percakapan (`npc_intro`, `npc_hint_bayam`, `npc_hint_kunci`, `npc_waiting`, `npc_offer`, `npc_received`, `npc_repeat`), pengecekan ketersediaan stok hidangan di tas vs peti, serta transaksi atomik pemotongan hidangan dan pembaruan `meal_used` berada dalam domain `explorer_soc_001_1` (`DialogueManager`).
   - `DialogueUI` dirancang decoupled: UI berinteraksi dengan `DialogueManager` via sinyal dan metode kontrak publik (`start_dialogue`, `select_choice`, `share_dish`, `get_dish_source`).

2. **Pengujian Headless Sosial:**
   - Perancangan test suite otomatis `tests/suites/test_social.gd` (Suite 15) berada dalam domain `explorer_soc_001_3`.
   - UI dialog ini menyediakan antarmuka publik yang dapat diuji tanpa GUI aktif (`open()`, `display_node()`, `close()`, `_prompt_share_confirmation()`).

---

## 4. Conclusion

1. **Scene UI Dialog (`scenes/ui/dialogue_ui.tscn` & `scripts/ui/dialogue_ui.gd`):**
   - Menggunakan hirarki `CanvasLayer (layer=12)` dengan root Control, background dim semi-transparan `Color(0.04, 0.05, 0.08, 0.40)`, panel bawah berlatar solid `Color(0.12, 0.14, 0.18, 0.96)`, label nama pembicara, label teks dialog yang dapat dibaca langsung, container tombol pilihan (maks 3 pilihan + Tutup) dengan navigasi fokus keyboard/gamepad (`FOCUS_ALL`, `focus_neighbor_*`), serta popup modal konfirmasi berbagi hidangan.
2. **Integrasi Konteks Input (`InputManager`):**
   - Sepenuhnya memanfaatkan `ContextMode.DIALOGUE` yang sudah ada di `InputManager`.
   - Mouse bebas saat dialog terbuka, terkunci saat ditutup.
   - Pemain WASD dan rotasi kamera dibekukan saat berdialog.
   - Waktu simulasi pertumbuhan kebun dan memasak dijeda.
   - Bleed-through eliminasi tuntas: 'E' pembuka dialog disupresi via `suppress_action_until_released(&"interact")` dan fokus tombol ditunda; tombol penutup dialog dicegah berinteraksi ke dunia via `_last_closed_frame`.
   - Esc berlapis: Esc pada modal konfirmasi hanya membatalkan berbagi dan mengembalikan fokus ke pilihan dialog tanpa menutup dialog.
3. **Integrasi Scene 3D Dunia (`scenes/world/level_graybox.tscn` & `scripts/main.gd`):**
   - Node `npc_neighbor_01` telah valid dan terverifikasi di koordinat `Vector3(-14, 0, 15)` dengan prompt diegetik `"[E] Bicara"` dan jangkauan raycast 2.0m.
   - Implementasi hanya perlu menginstansiasi `DialogueUI` di `scenes/main.tscn` dan menyambungkan sinyal `interacted` di `scripts/main.gd` (landmark 13).

---

## 5. Verification Method

Langkah-langkah verifikasi independen:
1. **Pemeriksaan File Desain & Blueprint:**
   - Baca `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_soc_001_2\analysis.md` untuk rincian struktur node scene `.tscn` dan kode lengkap `dialogue_ui.gd`.
2. **Pemeriksaan Konsistensi InputManager:**
   - Periksa `scripts/core/input_manager.gd` baris 11, 58, 72, 87, 124–129, 150–172 untuk memastikan `ContextMode.DIALOGUE`, penanganan mouse mode, gating pemain, dan `_last_closed_frame` aktif.
3. **Pemeriksaan Landmark Spasial 3D:**
   - Periksa `scenes/world/level_graybox.tscn` baris 829–852 untuk memastikan node `npc_neighbor_01` berada di `(-14, 0, 15)` dengan `Interactable` layer 4 dan prompt `Bicara`.
4. **Verifikasi Runner Headless Existing:**
   - Jalankan `godot --headless -s tests/test_runner.gd`.
   - Pastikan seluruh 14 suite (Suite 1 hingga Suite 14) tetap lulus 100% tanpa regresi:
     `Assertions Passed: 2126+, Assertions Failed: 0, Exit Code: 0`.
5. **Kondisi Invalidasi:**
   - Jika 'E' pembuka dialog memicu pilihan pertama secara instan.
   - Jika menutup dialog dengan Esc membuka Pause Menu pada frame yang sama.
   - Jika menutup modal konfirmasi dengan Esc langsung menutup dialog utama ke dunia.
   - Jika landmark `npc_neighbor_01` dipindahkan dari `(-14, 0, 15)`.
