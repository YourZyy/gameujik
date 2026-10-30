# Analisis Teknis UI/UX Dialog Warga dan Integrasi Scene Dunia 3D (SOC-001)

**Milestone:** SOC-001 (Dialog Warga, Catatan Lingkungan, Berbagi Hidangan, dan Penutup P0)  
**Penyusun:** `explorer_soc_001_2` (Dialogue UI/UX Explorer)  
**Dokumen Acuan:** `PRD.md`, `docs/UI_UX.md` (UI07, § 3, § 4), `docs/LEVEL_DESIGN.md` (§ 2, § 3), `docs/CONTENT.md` (§ 10, § 11), `docs/TEST_PLAN.md` (T43, T44, T45), `scripts/core/input_manager.gd`, `scenes/world/level_graybox.tscn`, `scripts/main.gd`.

---

## 1. Executive Summary

Milestone `SOC-001` merealisasikan pengalaman sosial pertama pemain dalam Buku Resep 2045: berinteraksi dengan warga tetangga (`npc_neighbor_01`) di teras pinggir jalan desa, menelusuri percakapan petunjuk resep dan kondisi lingkungan, serta menawarkan opsi berbagi hidangan (*Sayur Bening Bayam dan Jagung*) yang mengonsumsi tepat 1 porsi hidangan dari tas atau peti rumah secara atomik dengan konfirmasi eksplisit, sehingga memicu penutup pengalaman P0 (*"Satu resep selesai. Kebun ini baru dimulai."*).

Analisis ini membedah tiga domain krusial integrasi visual dan gameplay:
1. **Desain Antarmuka Dialog (`scenes/ui/dialogue_ui.tscn` & `scripts/ui/dialogue_ui.gd`):** Layout kartu dialog bawah semi-transparan per `UI_UX.md` UI07, header nama pembicara, teks dialog langsung yang dapat dibaca ulang, daftar tombol pilihan (maksimal 3 pilihan + opsi Tutup/Keluar) dengan navigasi fokus keyboard/gamepad yang nyaman, serta popup modal konfirmasi berbagi hidangan.
2. **Integrasi Konteks Input (`InputManager`):** Aktivasi `ContextMode.DIALOGUE`, pembebasan kursor mouse (`Input.MOUSE_MODE_VISIBLE`), pembekuan kendali gerak (WASD) dan kamera first-person (`movement_enabled = false`, `look_enabled = false`), jeda simulasi pertumbuhan kebun, serta eliminasi total terhadap *input bleed-through* (mencegah 'E' pembuka dialog langsung memicu pilihan pertama, dan mencegah tombol penutup memicu aksi dunia pada frame yang sama).
3. **Integrasi Spasial 3D Warga (`npc_neighbor_01`):** Penempatan node di `Vector3(-14, 0, 15)` sesuai `LEVEL_DESIGN.md` § 2 line 36, konfigurasi `CollisionShape3D` teras/bangku (Layer 1 Environment), `Area3D` interaksi (Layer 3 Interactables), radius interaksi raycast 2.0m, prompt diegetik `"[E] Bicara"`, serta penambahan instance ke `scenes/main.tscn` dan penyambungan sinyal di `scripts/main.gd`.

---

## 2. Desain Scene UI Dialog (`scenes/ui/dialogue_ui.tscn` & `scripts/ui/dialogue_ui.gd`)

### 2.1. Spesifikasi Tata Letak & Hirarki Visual (UI07)
Sesuai `UI_UX.md` UI07, UI dialog ditempatkan pada bagian bawah layar (*bottom-anchored panel*), tidak menutupi seluruh pandangan dunia 3D sehingga pemain tetap merasakan kehadiran tetangga dan suasana pedesaan sore hari, namun memiliki kontras latar yang cukup solid agar teks mudah terbaca di depan objek apa pun.

- **Baseline Resolusi:** 1280 × 720 (skalabel responsif ke 1920 × 1080 via Godot `canvas_items` stretch mode, aspect `keep`).
- **CanvasLayer Layer:** `layer = 12` (berada di atas HUD exploration `layer = 1`, setara dengan modal gameplay lainnya seperti `KitchenUI` `layer = 10` atau `InventoryUI`).
- **Dim Background:** `ColorRect` dengan warna `Color(0.04, 0.05, 0.08, 0.40)`. Tingkat kepekatan 40% memberi pemisahan visual fokus tanpa menghilangkan konteks spasial tetangga. `mouse_filter = MOUSE_FILTER_STOP` agar klik di luar dialog tidak mengklik objek 3D.
- **Dialogue Panel Container:**
  - Anchors: `PRESET_BOTTOM_WIDE` dengan safe margin 4% (`offset_left = 64`, `offset_right = -64`, `offset_bottom = -28`, `offset_top = -260`).
  - Latar panel: `StyleBoxFlat` bernuansa hangat pedesaan firewatch (`Color(0.12, 0.14, 0.18, 0.96)`), radius sudut 6px, garis tepi tipis `Color(0.28, 0.32, 0.40, 0.80)`.
  - Margin dalam: `margin_left = 24`, `margin_right = 24`, `margin_top = 18`, `margin_bottom = 18`.

```
DialogueUI (CanvasLayer, layer=12)
└── RootControl (Control, anchors_preset=PRESET_FULL_RECT)
    ├── DimBackground (ColorRect, color=Color(0.04, 0.05, 0.08, 0.4), mouse_filter=STOP)
    ├── DialoguePanel (PanelContainer, bottom-anchored, custom_minimum_size=(800, 220))
    │   └── MarginContainer (margins: 24, 18, 24, 18)
    │       └── VBoxContainer (separation=10)
    │           ├── HeaderHBox (HBoxContainer)
    │           │   ├── SpeakerNameLabel (Label, font_size=22, text="Tetangga", color=#F5E6C8)
    │           │   ├── Spacer (Control, size_flags_horizontal=SIZE_EXPAND_FILL)
    │           │   └── CloseButton (Button, text="Tutup [Esc]", custom_minimum_size=(100, 30))
    │           ├── ContentHBox (HBoxContainer, separation=16)
    │           │   ├── SpeakerBadge (ColorRect/Panel, custom_minimum_size=(4, 0), accent_color=#D48B47)
    │           │   └── DialogueTextLabel (Label, text="...", autowrap=WORD_SMART, font_size=20, size_flags_horizontal=EXPAND_FILL)
    │           └── ChoicesContainer (VBoxContainer, separation=6)
    │               ├── ChoiceButton1 (Button, custom_minimum_size=(0, 36), focus_mode=FOCUS_ALL)
    │               ├── ChoiceButton2 (Button, custom_minimum_size=(0, 36), focus_mode=FOCUS_ALL)
    │               └── ChoiceButton3 (Button, custom_minimum_size=(0, 36), focus_mode=FOCUS_ALL)
    └── ConfirmModal (Control, visible=false, anchors_preset=PRESET_FULL_RECT)
        ├── ModalDim (ColorRect, color=Color(0, 0, 0, 0.65), mouse_filter=STOP)
        └── ModalCenter (CenterContainer, anchors_preset=PRESET_FULL_RECT)
            └── ModalPanel (PanelContainer, custom_minimum_size=(520, 200))
                └── ModalMargin (MarginContainer, margins: 20)
                    └── ModalVBox (VBoxContainer, separation=14)
                        ├── ModalTitle (Label, text="Konfirmasi Berbagi Hidangan", font_size=20)
                        ├── ModalMessage (Label, text="Bagikan 1 porsi hidangan ini?\n(1 porsi Sayur Bening Bayam dan Jagung dari Tas)", autowrap=WORD_SMART, font_size=16)
                        └── ModalButtonsHBox (HBoxContainer, separation=16, alignment=ALIGNMENT_CENTER)
                            ├── ConfirmYesButton (Button, text="Ya, Bagikan [Enter]", custom_minimum_size=(160, 38))
                            └── ConfirmNoButton (Button, text="Batal [Esc]", custom_minimum_size=(140, 38))
```

### 2.2. Penampil Teks & Tipografi
- **Nama Tokoh (`SpeakerNameLabel`):** Ukuran 22px, warna krem hangat `Color(0.96, 0.88, 0.76)`.
- **Isi Teks (`DialogueTextLabel`):** Ukuran 20px, warna putih bersih `Color(0.92, 0.94, 0.96)`, jarak baris nyaman (`line_spacing = 4`), pembungkusan kata otomatis `autowrap_mode = TextServer.AUTOWRAP_WORD_SMART`.
- **Perilaku Teks (Direct vs Typewriter):**
  - Sesuai `UI_UX.md` § 2: *"Teks panjang dapat dibaca langsung; animasi ketik tidak wajib."* dan UI07: *"Teks singkat... Teks dapat dibaca ulang."*
  - **Keputusan Desain:** Teks ditampilkan secara instan penuh tanpa animasi ketik yang menghambat pemain. Jika ada transisi fade-in singkat, durasi maksimal 0.15 detik atau dapat dilewati instan saat klik / Space / Enter. Tidak ada lock waktu yang memaksa pemain menunggu teks selesai diketik.

### 2.3. Daftar Pilihan & Navigasi Fokus Keyboard/Gamepad
- **Kapasitas Pilihan:** Maksimal 3 pilihan kontekstual aktif terlihat sekaligus ditambah tombol Tutup per UI07.
- **Pewarnaan & Visual Pilihan:**
  - Tombol normal: `StyleBoxFlat` abu-abu gelap dengan border fokus berwarna aksen emas/oranye hangat saat dipilih (`focus` stylebox).
  - Teks pilihan: Diawali nomor/bullet indeks (misal `"1. Bayamnya dari mana?"`, `"2. Temu kunci?"`, `"3. Bagikan 1 porsi hidangan"`).
- **Aturan Akses Tombol Berbagi:**
  - Opsi `"Bagikan 1 porsi hidangan"` hanya aktif (atau hanya muncul) jika ada minimal 1 unit `dish_sayur_bening` di inventaris tas atau peti rumah.
  - Jika tidak ada hidangan, opsi tidak ditampilkan atau berstatus nonaktif (disabled) dengan petunjuk bahwa hidangan belum siap.
- **Navigasi Fokus (Keyboard & Gamepad Focus Traversal):**
  - Seluruh tombol pilihan memiliki `focus_mode = Control.FOCUS_ALL`.
  - Tombol pilihan atas memiliki `focus_neighbor_top` mengarah ke tombol terakhir atau `CloseButton`.
  - Tombol pilihan bawah memiliki `focus_neighbor_bottom` mengarah ke tombol berikutnya.
  - Panah Atas / Bawah (`ui_up` / `ui_down`) dan Tab / Shift+Tab berpindah fokus antar pilihan secara mulus.
  - Enter / Spasi (`ui_accept`) mengaktifkan pilihan yang sedang berfokus.
  - Tombol Esc (`pause_menu` / `ui_cancel`) menutup dialog ke dunia.

### 2.4. Modal Konfirmasi Berbagi Hidangan (`ConfirmModal`)
- **Pemicu:** Ketika pemain memilih opsi berbagi hidangan (`choice_share`).
- **Tampilan:**
  - Panel konfirmasi pop-up modal muncul di tengah layar (`ConfirmModal.visible = true`).
  - Judul: *"Konfirmasi Berbagi Hidangan"*.
  - Pesan teks: *"Bagikan 1 porsi hidangan ini?"* dilengkapi keterangan sumber:
    - Jika hidangan ada di Tas: `"(1 porsi Sayur Bening Bayam dan Jagung dari Tas)"`.
    - Jika hidangan ada di Peti Rumah: `"(1 porsi Sayur Bening Bayam dan Jagung dari Peti Rumah)"` (sesuai `CONTENT.md` § 10: *"Mengonsumsi dari peti untuk berbagi diperbolehkan sebagai kemudahan P0; teks menyebut stok rumah bila relevan"*).
  - Dua tombol aksi:
    - `ConfirmYesButton` (*"Ya, Bagikan [Enter]"*): Berfokus awal (`grab_focus()`). Menekan Enter mengeksekusi `DialogueManager.share_dish()`, menutup modal, memotong item, dan memajukan dialog ke node `npc_received`.
    - `ConfirmNoButton` (*"Batal [Esc]"*): Menekan Esc atau Batal menutup `ConfirmModal`, **tidak memotong item**, dan mengembalikan fokus keyboard ke tombol pilihan dialog sebelumnya di `DialoguePanel`!

---

## 3. Integrasi Konteks Input & Anti-Bleed-Through (`InputManager`)

### 3.1. Siklus Hidup Konteks `ContextMode.DIALOGUE`
File `scripts/core/input_manager.gd` telah memiliki definisi `ContextMode.DIALOGUE` (baris 11). Integrasi dialog memanfaatkan stack konteks tersebut secara menyeluruh:

| Parameter | Keadaan Dunia (`WORLD`) | Keadaan Dialog (`DIALOGUE`) | Saat Dialog Ditutup |
|---|---|---|---|
| **Konteks Aktif** | `ContextMode.WORLD` | `ContextMode.DIALOGUE` | Kembali ke `ContextMode.WORLD` |
| **Kursor Mouse** | `Input.MOUSE_MODE_CAPTURED` | `Input.MOUSE_MODE_VISIBLE` | Dikunci kembali ke `MOUSE_MODE_CAPTURED` |
| **Gerak Pemain (WASD)** | `player.movement_enabled = true` | `player.movement_enabled = false` | Dipulihkan `player.movement_enabled = true` |
| **Kamera Pandang (Look)** | `player.look_enabled = true` | `player.look_enabled = false` | Dipulihkan `player.look_enabled = true` |
| **Simulasi Waktu Kebun** | `is_simulation_paused() = false` | `is_simulation_paused() = true` | Dipulihkan `false` |
| **Interaksi Dunia (Raycast)** | `can_interact_in_world() = true` | `can_interact_in_world() = false` | Ditahan pada frame penutup |

### 3.2. Pencegahan Input Bleed-Through (Anti-Bleed-Through Invariants)

#### Invarian 1: Mencegah 'E' Pembuka Dialog Memilih Pilihan Pertama
- **Permasalahan:** Tombol `interact` (fisik tombol 'E', physical keycode 69) ditekan oleh pemain untuk berbicara dengan warga. Jika dialog langsung terbuka dan pilihan pertama langsung menerima input 'E' pada frame yang sama, pilihan pertama dapat terpilih secara tidak sengaja (*accidental selection*). Hal ini secara eksplisit dilarang oleh `UI_UX.md` UI07:
  > *"E yang memulai dialog tidak sekaligus memilih pilihan pertama."*
- **Solusi Rekayasa:**
  1. Pada saat interaksi terjadi di `player_controller.gd:178`, `get_viewport().set_input_as_handled()` dipanggil, sehingga event tidak lolos ke handler lain.
  2. Di `DialogueUI.open()`, pemberian fokus tombol pertama ditunda hingga frame berikutnya menggunakan `call_deferred("grab_focus")` atau `await get_tree().process_frame`.
  3. Tombol pilihan dalam dialog dioperasikan secara eksklusif menggunakan aksi `ui_accept` (Enter / Space) dan klik mouse, atau jika 'E' dipetakan sebagai tombol navigasi menu, maka tombol 'E' wajib disupresi via `InputManager.suppress_action_until_released(&"interact")` hingga tombol 'E' benar-benar dilepas (*released*) oleh pemain sebelum dapat memicu aksi pilihan menu.

#### Invarian 2: Mencegah Tombol Penutup Dialog Lolos ke Aksi Dunia (Closing Bleed-Through)
- **Permasalahan:** Ketika pemain menekan Esc atau tombol selesai untuk menutup dialog, jika event Esc atau klik mouse bocor ke dunia, pemain bisa secara tidak sengaja membuka Pause Menu atau memicu alat di dunia.
- **Solusi Rekayasa:**
  1. `InputManager.consume_and_close(&"pause_menu")` memanggil `suppress_action_until_released(&"pause_menu")` dan mencatat `_last_closed_frame = Engine.get_process_frames()` (`input_manager.gd:87`).
  2. Metode `can_interact_in_world()` di `input_manager.gd:124` memeriksa:
     ```gdscript
     func can_interact_in_world() -> bool:
         if not is_world_context():
             return false
         if Engine.get_process_frames() == _last_closed_frame:
             return false
         return true
     ```
  3. `InteractionDetector.try_interact()` memeriksa `can_interact_in_world()` dan `is_action_suppressed(&"interact")` (`interaction_detector.gd:127`). Jika frame saat ini sama dengan `_last_closed_frame`, interaksi dunia ditolak secara deterministik.

#### Invarian 3: Perutean Tombol Esc Berlapis (Modal Layering Routing)
- **Permasalahan:** Jika `ConfirmModal` sedang terbuka di atas dialog dan pemain menekan tombol Esc, dialog utama tidak boleh langsung tertutup. Hanya `ConfirmModal` yang harus ditutup terlebih dahulu.
- **Solusi Rekayasa:**
  - `DialogueUI` menangani event input tombol Esc dalam fungsi `_unhandled_input` lokal:
    ```gdscript
    func _unhandled_input(event: InputEvent) -> void:
        if not visible:
            return
        if event.is_action_pressed("pause_menu") and not event.is_echo():
            if confirm_modal != null and confirm_modal.visible:
                # Tutup hanya modal konfirmasi
                _on_cancel_share_pressed()
                get_viewport().set_input_as_handled()
            else:
                # Tutup dialog utama ke dunia
                close()
                get_viewport().set_input_as_handled()
    ```
  - Dengan memanggil `set_input_as_handled()`, `InputManager` tidak akan menerima event Esc tersebut, sehingga stack konteks `DIALOGUE` tetap terjaga saat menutup modal konfirmasi, dan fokus dikembalikan ke pilihan dialog sebelumnya.

---

## 4. Integrasi Spasial 3D Warga (`npc_neighbor_01`) di Scene Dunia

### 4.1. Verifikasi Lokasi & Landmark Sesuai `LEVEL_DESIGN.md`
Sesuai `LEVEL_DESIGN.md` § 2 tabel baris 36 dan § 3:
- **ID Node:** `npc_neighbor_01`
- **Koordinat Default Uji:** `Vector3(-14, 0, 15)`
- **Fungsi / Deskripsi:** Teras tetangga, bangku dan kain peneduh.
- **Rute Spasial:** Berada pada percabangan jalan barat (`junction_path` di `(0, 0, 21)` berbelok ke arah barat laut) menuju area bambu liar dan temu kunci (`resource_temu_kunci_01` di `(-20, 0, 30)`). Jarak tempuh dari spawn rumah adalah ~20.5 meter (6–7 detik berjalan normal).

### 4.2. Struktur Node & Collision yang Sudah Ada di `scenes/world/level_graybox.tscn`
Pemeriksaan pada `scenes/world/level_graybox.tscn` (baris 829–852) membuktikan bahwa node `npc_neighbor_01` telah terdefinisi dengan struktur:
```tscn
[node name="npc_neighbor_01" type="Node3D" parent="." unique_id=1703206431]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -14, 0, 15)

[node name="Bench" type="StaticBody3D" parent="npc_neighbor_01" unique_id=689412373]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.4, 0)

[node name="Collision" type="CollisionShape3D" parent="npc_neighbor_01/Bench" unique_id=1105175031]
shape = SubResource("BoxShape3D_p8lyj") ; size = Vector3(1.8, 0.8, 0.8)

[node name="Mesh" type="MeshInstance3D" parent="npc_neighbor_01/Bench" unique_id=632129687]
mesh = SubResource("BoxMesh_ionxg") ; size = Vector3(1.8, 0.8, 0.8)

[node name="Interactable" type="Area3D" parent="npc_neighbor_01" unique_id=2088535916]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.4, 0)
collision_layer = 4 ; Layer 3: interactables (bitmask 1 << 2 = 4)
collision_mask = 0
monitoring = false
monitorable = true
script = ExtResource("2_t2kf2") ; res://scripts/interaction/interactable.gd
interaction_id = "landmark_neighbor"
prompt_action = "Bicara"

[node name="Collision" type="CollisionShape3D" parent="npc_neighbor_01/Interactable" unique_id=154347467]
shape = SubResource("BoxShape3D_pd2bg") ; size = Vector3(1.8, 0.8, 0.8)
```

### 4.3. Karakteristik Interaksi & Radius Deteksi (2.0m)
1. **Target Collision Layer:**
   - `Bench` (Layer 1: Environment) mencegah pemain menabrak/menembus teras.
   - `Interactable` (Layer 3: Interactables, bitmask 4) merespons raycast `InteractionDetector` pemain (mask 5: layer 1 + layer 3).
2. **Radius Deteksi Raycast 2.0m:**
   - `InteractionDetector.max_interaction_distance = 2.0` meter.
   - Ketika crosshair pemain mengarah ke `npc_neighbor_01` dari jarak ≤ 2.0m, raycast mendeteksi `Interactable`.
   - `Interactable.get_prompt_text()` mengevaluasi `prompt_action = "Bicara"` dan `target_name = ""`, menghasilkan teks prompt resmi:
     `"[E] Bicara"`
   - Prompt dikirimkan ke HUD eksplorasi dan ditampilkan tepat di bawah crosshair (`UI_UX.md` UI01).
3. **Penyempurnaan Visual Stylized (Rekomendasi Graybox):**
   - Saat ini landmark hanya berisi mesh bangku (`Bench`).
   - Sesuai `LEVEL_DESIGN.md` § 2 line 36 (*"Bangku dan kain peneduh"*) dan `ART_DIRECTION.md`: Disarankan menambahkan node visual peneduh (`ShadeCanopy` kain krem/terakota di atas bangku, tinggi 2.2m) serta siluet graybox karakter warga (`NeighborSilhouette` kapsul/silinder 1.4m warna indigo/terakota hangat) agar dari kejauhan pemain dapat langsung mengenali bahwa ada figur warga di teras tersebut tanpa mengubah ukuran collider `BoxShape3D` yang sudah diuji oleh `test_level.gd` dan `test_interaction.gd`.

---

## 5. Rencana Integrasi Kode (`main.tscn` & `main.gd`)

### 5.1. Pemasangan Node di `scenes/main.tscn`
Tambahkan instance `DialogueUI` pada root `Main`:
```tscn
[ext_resource type="PackedScene" path="res://scenes/ui/dialogue_ui.tscn" id="8_dialogue"]

...
[node name="DialogueUI" parent="." instance=ExtResource("8_dialogue")]
```

### 5.2. Penyambungan Sinyal Landmark di `scripts/main.gd`
Tambahkan referensi dan wiring landmark pada `scripts/main.gd`:
```gdscript
@onready var dialogue_ui: CanvasLayer = $DialogueUI if has_node("DialogueUI") else null

func _wire_inventory_and_landmarks() -> void:
    ...
    # 13. Wire npc_neighbor_01 landmark
    var neighbor_node = level.get_node_or_null("npc_neighbor_01")
    if neighbor_node:
        var interactable = neighbor_node.get_node_or_null("Interactable")
        if interactable and interactable.has_signal("interacted"):
            interactable.interacted.connect(_on_neighbor_interacted)

func _on_neighbor_interacted(_player_node: Node3D) -> void:
    var im = get_node_or_null("/root/InputManager")
    if im != null and im.is_world_context():
        im.push_context(im.ContextMode.DIALOGUE)
    if dialogue_ui != null and dialogue_ui.has_method("open"):
        dialogue_ui.open()
```

---

## 6. Blueprint Implementasi GDScript (`scripts/ui/dialogue_ui.gd`)

Berikut adalah cetak biru arsitektur lengkap untuk `scripts/ui/dialogue_ui.gd` yang memenuhi seluruh kriteria UI07, § 3, § 4, dan integrasi `DialogueManager`:

```gdscript
class_name DialogueUI
extends CanvasLayer

## Antarmuka Dialog Warga untuk 'Buku Resep 2045'
## Memenuhi spesifikasi PRD FR02, UI_UX.md UI07, § 3, § 4, dan TEST_PLAN T43..T45

@onready var root_control: Control = $RootControl if has_node("RootControl") else (find_child("RootControl", true, false) as Control)
@onready var dialogue_panel: PanelContainer = find_child("DialoguePanel", true, false) as PanelContainer
@onready var speaker_name_label: Label = find_child("SpeakerNameLabel", true, false) as Label
@onready var dialogue_text_label: Label = find_child("DialogueTextLabel", true, false) as Label
@onready var close_button: Button = find_child("CloseButton", true, false) as Button
@onready var choices_container: VBoxContainer = find_child("ChoicesContainer", true, false) as VBoxContainer

# Modal Konfirmasi Berbagi
@onready var confirm_modal: Control = find_child("ConfirmModal", true, false) as Control
@onready var confirm_message: Label = find_child("ModalMessage", true, false) as Label
@onready var confirm_yes_button: Button = find_child("ConfirmYesButton", true, false) as Button
@onready var confirm_no_button: Button = find_child("ConfirmNoButton", true, false) as Button

var _dialogue_manager_override: Node = null
var _input_manager_override: Node = null
var _last_focused_choice: Control = null
var _pending_share_source: String = "backpack"

func _ready() -> void:
    visible = false
    if confirm_modal != null:
        confirm_modal.visible = false

    if close_button != null:
        close_button.pressed.connect(close)
    if confirm_yes_button != null:
        confirm_yes_button.pressed.connect(_on_confirm_share_yes)
    if confirm_no_button != null:
        confirm_no_button.pressed.connect(_on_cancel_share_pressed)

    _connect_manager_signals()

func _connect_manager_signals() -> void:
    var im := _get_input_manager()
    if im != null and im.has_signal("context_changed"):
        if not im.context_changed.is_connected(_on_context_changed):
            im.context_changed.connect(_on_context_changed)

    var dm := _get_dialogue_manager()
    if dm != null:
        if dm.has_signal("node_changed") and not dm.node_changed.is_connected(_on_dialogue_node_changed):
            dm.node_changed.connect(_on_dialogue_node_changed)
        if dm.has_signal("dialogue_ended") and not dm.dialogue_ended.is_connected(close):
            dm.dialogue_ended.connect(close)

func _on_context_changed(new_ctx: int, _old_ctx: int) -> void:
    var im := _get_input_manager()
    if im == null:
        return
    if new_ctx == im.ContextMode.DIALOGUE:
        if not visible:
            open()
    elif visible:
        visible = false
        if confirm_modal != null:
            confirm_modal.visible = false

func open(initial_node_id: String = "") -> void:
    visible = true
    if confirm_modal != null:
        confirm_modal.visible = false

    var dm := _get_dialogue_manager()
    if dm != null and dm.has_method("start_dialogue"):
        dm.start_dialogue(initial_node_id)
    else:
        # Fallback dummy display jika manager belum dipasang
        display_node({
            "speaker": "Tetangga",
            "text": "Masih menyimpan buku itu? Coba lihat kebun di ujung jalan. Jagungnya belum semua habis.",
            "choices": [
                {"id": "hint_bayam", "text": "Bayamnya dari mana?"},
                {"id": "hint_kunci", "text": "Temu kunci?"},
                {"id": "close", "text": "Nanti dulu"}
            ]
        })

    # Cegah 'E' pembuka dialog memicu pilihan pertama secara instan
    var im := _get_input_manager()
    if im != null and im.has_method("suppress_action_until_released"):
        im.suppress_action_until_released(&"interact")

    # Berikan fokus pada tombol pilihan pertama secara ter-defer
    call_deferred("_grab_initial_focus")

func _grab_initial_focus() -> void:
    if choices_container != null and choices_container.get_child_count() > 0:
        var btn = choices_container.get_child(0) as Control
        if btn != null and btn.is_visible_in_tree():
            btn.grab_focus()
            return
    if close_button != null:
        close_button.grab_focus()

func close() -> void:
    visible = false
    if confirm_modal != null:
        confirm_modal.visible = false

    var dm := _get_dialogue_manager()
    if dm != null and dm.has_method("end_dialogue"):
        dm.end_dialogue()

    var im := _get_input_manager()
    if im != null and im.has_method("get_current_context"):
        if im.get_current_context() == im.ContextMode.DIALOGUE:
            im.consume_and_close(&"pause_menu")

func display_node(node_data: Dictionary) -> void:
    if speaker_name_label != null:
        speaker_name_label.text = str(node_data.get("speaker", "Tetangga"))
    if dialogue_text_label != null:
        dialogue_text_label.text = str(node_data.get("text", ""))

    # Kosongkan tombol lama
    for child in choices_container.get_children():
        child.queue_free()

    var choices: Array = node_data.get("choices", [])
    var btn_index := 0
    var previous_btn: Button = null

    for choice in choices:
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(0, 36)
        btn.focus_mode = Control.FOCUS_ALL
        btn.text = "%d. %s" % [btn_index + 1, str(choice.get("text", ""))]
        var choice_id: String = str(choice.get("id", ""))
        btn.pressed.connect(func(): _on_choice_pressed(choice_id))

        choices_container.add_child(btn)

        # Kaitkan tetangga fokus Up/Down
        if previous_btn != null:
            previous_btn.focus_neighbor_bottom = btn.get_path()
            btn.focus_neighbor_top = previous_btn.get_path()
        previous_btn = btn
        btn_index += 1

    if previous_btn != null and close_button != null:
        previous_btn.focus_neighbor_bottom = close_button.get_path()
        close_button.focus_neighbor_top = previous_btn.get_path()

    call_deferred("_grab_initial_focus")

func _on_choice_pressed(choice_id: String) -> void:
    if choice_id == "close" or choice_id == "later":
        close()
        return

    if choice_id == "share_dish":
        _prompt_share_confirmation()
        return

    var dm := _get_dialogue_manager()
    if dm != null and dm.has_method("select_choice"):
        dm.select_choice(choice_id)

func _prompt_share_confirmation() -> void:
    _last_focused_choice = get_viewport().gui_get_focus_owner()
    var dm := _get_dialogue_manager()
    _pending_share_source = "backpack"
    if dm != null and dm.has_method("get_dish_source"):
        _pending_share_source = dm.get_dish_source() # "backpack" atau "storage"

    if confirm_message != null:
        var src_text := "dari Tas" if _pending_share_source == "backpack" else "dari Peti Rumah"
        confirm_message.text = "Bagikan 1 porsi hidangan ini?\n(1 porsi Sayur Bening Bayam dan Jagung %s)" % src_text

    if confirm_modal != null:
        confirm_modal.visible = true
        if confirm_yes_button != null:
            confirm_yes_button.grab_focus()

func _on_confirm_share_yes() -> void:
    if confirm_modal != null:
        confirm_modal.visible = false

    var dm := _get_dialogue_manager()
    if dm != null and dm.has_method("share_dish"):
        dm.share_dish(_pending_share_source)

func _on_cancel_share_pressed() -> void:
    if confirm_modal != null:
        confirm_modal.visible = false
    # Kembalikan fokus ke pilihan sebelumnya
    if _last_focused_choice != null and is_instance_valid(_last_focused_choice):
        _last_focused_choice.grab_focus()
    else:
        call_deferred("_grab_initial_focus")

func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    if event.is_action_pressed("pause_menu") and not event.is_echo():
        if confirm_modal != null and confirm_modal.visible:
            _on_cancel_share_pressed()
            get_viewport().set_input_as_handled()
        else:
            close()
            get_viewport().set_input_as_handled()

func _get_dialogue_manager() -> Node:
    if _dialogue_manager_override != null and is_instance_valid(_dialogue_manager_override):
        return _dialogue_manager_override
    if Engine.has_singleton("DialogueManager"):
        return Engine.get_singleton("DialogueManager")
    if is_inside_tree() and has_node("/root/DialogueManager"):
        return get_node("/root/DialogueManager")
    return null

func _get_input_manager() -> Node:
    if _input_manager_override != null and is_instance_valid(_input_manager_override):
        return _input_manager_override
    if Engine.has_singleton("InputManager"):
        return Engine.get_singleton("InputManager")
    if is_inside_tree() and has_node("/root/InputManager"):
        return get_node("/root/InputManager")
    return null
```

---

## 7. Pemetaan Kriteria Penerimaan Uji (T43, T44, T45)

| ID Uji | Skenario Uji | Verifikasi UI/UX & Spasial | Ekspektasi Hasil |
|---|---|---|---|
| **T43** | Penutup P0 setelah konsumsi/berbagi | Dialogue UI memunculkan respons `npc_received`, notifikasi penutup P0 (*"Satu resep selesai. Kebun ini baru dimulai."*) muncul 2.5s tanpa menutup paksa game. | Flag `meal_used = true`, `p0_completed = true`, pemain tetap bebas bergerak di dunia. |
| **T44** | Konfirmasi berbagi hidangan (Tas/Peti) | Tombol konfirmasi berbagi memunculkan `ConfirmModal`. Menekan Batal/Esc menutup modal tanpa memotong hidangan. Menekan Ya memotong tepat 1 hidangan. | Batal tidak mengonsumsi; berhasil memakai satu; tiada duplikasi respons. |
| **T45** | Invarian bebas penguncian (Loop mandiri) | Pemain melewati tetangga, memanen bayam/jagung/temu kunci, memasak hidangan, lalu baru berbicara dengan tetangga. Dialog dapat dibuka ulang berkali-kali. | Sumber tidak terkunci; dialog dapat diakses dan diulang kapan saja tanpa regresi state. |

---

## 8. Rekomendasi Langkah Implementasi untuk Tim

1. **Buat Scene UI:** Buat `scenes/ui/dialogue_ui.tscn` dan `scripts/ui/dialogue_ui.gd` sesuai blueprint hirarki Control node di atas.
2. **Instance ke Main:** Pasang `DialogueUI` di `scenes/main.tscn` dan sambungkan sinyal `interacted` dari `npc_neighbor_01/Interactable` di `scripts/main.gd`.
3. **Penyempurnaan Visual Graybox Warga:** Tambahkan mesh siluet peneduh dan figur warga di `npc_neighbor_01` (`scenes/world/level_graybox.tscn` / `build_level_graybox.gd`) untuk memperkuat keterbacaan siluet teras tanpa mengubah collision yang ada.
4. **Verifikasi Headless:** Jalankan test runner `godot --headless -s tests/test_runner.gd` untuk memastikan 14 suite yang ada tetap 100% lulus dan siap menerima Suite 15 (`test_social.gd`).
