# Handoff Report: Investigasi dan Rancangan Arsitektur Pause Menu, Navigasi Fokus, dan Dialog Konfirmasi Modal (UI-001)

## 1. Observation

### 1.1 Kondisi Existing UI dan Scene Tree
1. **Scene Utama (`scenes/main.tscn` & `scripts/main.gd`)**:
   - `scenes/main.tscn` memuat hierarki:
     ```
     Main (Node3D)
     ├── DirectionalLight3D
     ├── WorldEnvironment
     ├── LevelGraybox
     ├── Player
     ├── HUD (CanvasLayer)
     ├── InventoryUI (CanvasLayer)
     ├── BookUI (CanvasLayer)
     ├── KitchenUI (CanvasLayer)
     └── DialogueUI (CanvasLayer)
     ```
   - Belum terdapat `PauseMenu` (`scenes/ui/pause_menu.tscn`) maupun `SettingsMenu` (`scenes/ui/settings_menu.tscn`).
   - Seluruh UI panel gameplay diturunkan dari `CanvasLayer` dengan root anak berupa `RootControl` (`Control`) ber-preset `PRESET_FULL_RECT`.
   - File `scripts/core/game_manager.gd` belum ada di workspace (hanya tercantum sebagai usulan arsitektur dalam `PROJECT.md`). Seluruh koordinasi runtime saat ini ditangani oleh autoload singletons: `InputManager`, `InventoryManager`, `RecipeManager`, `GardenManager`, `WorldResourceManager`, `KitchenManager`, `DialogueManager`, dan `SaveManager`.

2. **Karakteristik Autoload `InputManager` (`scripts/core/input_manager.gd`)**:
   - Mendefinisikan enum `ContextMode` (baris 6–13):
     ```gdscript
     enum ContextMode {
         WORLD,
         BOOK,
         STORAGE,
         KITCHEN,
         DIALOGUE,
         PAUSE
     }
     ```
   - Mengelola tumpukan konteks `_context_stack: Array[ContextMode] = [ContextMode.WORLD]`.
   - Metode `is_simulation_paused()` (baris 56–59):
     ```gdscript
     func is_simulation_paused() -> bool:
         var ctx := get_current_context()
         return ctx in [ContextMode.BOOK, ContextMode.STORAGE, ContextMode.DIALOGUE, ContextMode.PAUSE]
     ```
     `ContextMode.PAUSE` secara otomatis membekukan simulasi (waktu pertumbuhan kebun dan kalender dunia).
   - Penanganan tombol jeda pada `_unhandled_input` (baris 178–199):
     ```gdscript
     func _unhandled_input(event: InputEvent) -> void:
         if is_world_context():
             if event.is_action_pressed("pause_menu") and not event.is_echo():
                 push_context(ContextMode.PAUSE)
                 get_viewport().set_input_as_handled()
             ...
         else:
             if event.is_action_pressed("pause_menu") and not event.is_echo():
                 consume_and_close(&"pause_menu")
                 get_viewport().set_input_as_handled()
     ```
   - Penanganan kehilangan fokus jendela aplikasi (baris 173–177):
     ```gdscript
     func _notification(what: int) -> void:
         if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
             if auto_pause_on_focus_loss and is_world_context():
                 push_context(ContextMode.PAUSE)
     ```
     *Catatan*: Baris 175 saat ini membatasi auto-pause hanya saat `is_world_context()`. Jika pemain sedang membuka panel dapur aktif (`ContextMode.KITCHEN`), kehilangan fokus jendela belum memicu jeda simulasi kompor.

3. **Karakteristik Autoload `SaveManager` (`scripts/save/save_manager.gd`)**:
   - Memiliki metode publik yang sudah teruji 100% pada SAVE-001 (Laporan 015):
     - `save_game(slot_type: String = "manual") -> Dictionary`: penulisan atomik `.tmp` -> `.bak` -> `.json`, checksum SHA-256. Mengembalikan `{"success": bool, "path": String, "revision": int, "error": int, "message": String}`.
     - `load_game(slot_type: String = "manual") -> Dictionary`: two-phase commit pre-flight validation, fallback `.bak`, self-healing. Mengembalikan `{"success": bool, "slot_type": String, "recovered_from_backup": bool, "error": int, "message": String}`.
     - `get_slot_metadata(slot_type: String) -> Dictionary`: mengembalikan `{"valid": bool, "slot_type": String, "revision": int, "timestamp": int, "timestamp_iso": String, "recovered_from_backup": bool}`.
     - `has_valid_save(slot_type: String) -> bool` dan `has_any_valid_save() -> bool`.
     - `get_continue_slot() -> String`: memilih slot valid dengan revisi monotonik tertinggi.
     - `load_settings() -> Dictionary` dan `save_settings(new_settings: Dictionary) -> Error`: persistensi mandiri terisolasi di `user://settings.cfg`.
     - `get_default_settings() -> Dictionary`:
       - `gameplay`: `mouse_sensitivity_multiplier: 1.0`, `head_bob: false`.
       - `video`: `fov: 80.0`, `ui_scale: 1.0`, `window_mode: 0`.
       - `audio`: `master_volume: 0.7`, `music_volume: 0.4`, `sfx_volume: 0.7`.
       - `accessibility`: `subtitles: true`.

4. **Spesifikasi Dokumen Desain & Rencana Pengujian**:
   - `docs/UI_UX.md` § 5 UI06:
     - Pause: Lanjutkan, Simpan, Muat, Pengaturan, Kembali ke posisi aman, Menu utama, Keluar.
     - Pengaturan ditempatkan pada halaman tersendiri, bukan seluruh slider pada layar pause pertama.
     - Keluar jika keadaan berubah sejak checkpoint terakhir: Simpan dan Keluar / Keluar tanpa Simpan / Batal. Jika save gagal, tetap di menu dan jelaskan.
     - Muat memperingatkan kehilangan perubahan yang belum disimpan.
     - Tombol kembali ke posisi aman tidak mereset dunia.
     - Head bob mati default; tanpa motion blur.
   - `docs/TEST_PLAN.md`:
     - **T18**: Dunia berhenti saat modal; input penutup tidak bocor; fokus hilang mem-pause.
     - **T21**: Ubah FOV dan skala UI pada layar kecil/besar; tombol/prompt tetap terlihat; kamera berubah sesuai pengaturan tanpa memotong UI.
     - **T28**: Buka buku/tas/dialog/dapur/pause berturut; Esc dan konfirmasi; satu panel utama; satu lapisan ditutup; mouse/fokus pulih; tidak ada aksi dunia tak sengaja.
     - **T51**: Navigasi seluruh panel hanya keyboard dan kembali dari konfirmasi; fokus terlihat, urutan logis, semua aksi inti dapat diakses, konflik Tab tidak mengunci.
     - **T52**: Ubah sensitivitas/FOV/audio/skala; restart dan load save lama; pengaturan tetap yang terbaru, tidak ditimpa progres lama; slider benar-benar bekerja.
     - **T53**: Buka menu keluar/Game Baru dengan progres belum disimpan; uji semua pilihan; Batal mempertahankan keadaan; penghapusan/penimpaan hanya sesudah pilihan eksplisit.
     - **T54**: Notifikasi tergabung/terbatas, pesan tidak menutup prompt atau merebut kamera.

---

## 2. Logic Chain

1. **Koordinasi State Jeda**:
   - Ketika pemain menekan tombol Escape (`pause_menu`) di dunia 3D, `InputManager._unhandled_input` menangkap event tersebut dan memanggil `push_context(ContextMode.PAUSE)`.
   - `push_context` memancarkan sinyal `context_changed(PAUSE, WORLD)` dan `simulation_state_changed(true)`.
   - `_sync_mouse_mode()` membebaskan kursor mouse (`Input.mouse_mode = Input.MOUSE_MODE_VISIBLE`), dan `_sync_player_gating()` mematikan `movement_enabled` dan `look_enabled` pada pemain.
   - Scene `PauseMenu` yang mendengarkan sinyal `context_changed` mendeteksi konteks `PAUSE`, menampilkan dirinya (`visible = true`), dan segera memberikan fokus keyboard ke tombol pertama (`ResumeButton.grab_focus()`).

2. **Dukungan Kehilangan Fokus Jendela (T18 Auto-Pause)**:
   - Sesuai observasi 1.2, `InputManager._notification` menangani `NOTIFICATION_APPLICATION_FOCUS_OUT` dan `NOTIFICATION_WM_WINDOW_FOCUS_OUT`.
   - Pengecekan saat ini `is_world_context()` harus diperluas menjadi `get_current_context() != ContextMode.PAUSE`.
   - Dengan perluasan ini, jika pemain sedang memasak di dapur (`ContextMode.KITCHEN`) atau menjelajah di dunia (`ContextMode.WORLD`) lalu melakukan Alt-Tab, konteks `PAUSE` otomatis didorong ke atas tumpukan stack (`[WORLD, KITCHEN, PAUSE]`), waktu kompor langsung membeku, dan `PauseMenu` tampil. Ketika pemain kembali dan menekan Lanjutkan, context `PAUSE` di-pop dan pemain kembali tepat ke stasiun dapur yang sedang dijeda.

3. **Hierarki Penutupan Berlapis (Modal Layering & Esc Behavior - T18, T28)**:
   - Di dalam `PauseMenu`, pemain dapat membuka:
     a. `SettingsPanel` (Halaman Pengaturan mandiri).
     b. `SlotPickerModal` (Pemilih Slot Muat).
     c. `ConfirmationModal` (Konfirmasi Timpa Simpanan, Peringatan Data Belum Disimpan, Konfirmasi Keluar).
   - Di Godot 4, event `_unhandled_input` dipropagasikan dari node daun terbawah ke atas (reverse tree order). Karena `PauseMenu` berada di dalam scene aktif `Main`, `PauseMenu._unhandled_input` dieksekusi **sebelum** autoload `InputManager`.
   - `PauseMenu` mengelola tumpukan sub-panel lokal (`_subpanel_stack: Array[Control]`).
   - Jika `_subpanel_stack` tidak kosong (misalnya `ConfirmationModal` sedang aktif di atas `SlotPickerModal`):
     - Penekanan Esc mengeksekusi penutupan lapisan teratas saja (`ConfirmationModal.hide()`).
     - Mengembalikan fokus keyboard ke elemen pemanggilnya di `SlotPickerModal`.
     - Memanggil `get_viewport().set_input_as_handled()`.
     - Autoload `InputManager` tidak menerima event Esc tersebut, sehingga `ContextMode.PAUSE` tetap aktif tanpa menutup Pause Menu secara prematur.
   - Jika `_subpanel_stack` kosong (hanya tombol utama Pause Menu yang tampil):
     - Penekanan Esc atau klik tombol "Lanjutkan" memanggil `InputManager.consume_and_close(&"pause_menu")`.
     - Konteks kembali ke konteks sebelumnya (`WORLD`), `_last_closed_frame` dicatat, mouse dikunci kembali, dan `can_interact_in_world()` mencegah kebocoran klik/interaksi pada frame yang sama (T18 & T28 anti-bleed-through).

4. **Alur Dialog Konfirmasi Modal (T53 & Overwrite Warning)**:
   - **Kasus 1: Simpan Permainan (Manual Checkpoint)**
     - Memeriksa `SaveManager.has_valid_save("manual")`.
     - Jika sudah ada: memunculkan `ConfirmationModal` bertajuk *"Konfirmasi Timpa Simpanan"* dengan pesan *"Slot simpanan manual sudah berisi data (Revisi %d, %s). Apakah Anda yakin ingin menimpa data ini?"*.
     - Opsi: `[Ya, Timpa]` (menjalankan `SaveManager.save_game("manual")`) dan `[Batal]` (menutup modal, fokus kembali ke tombol Simpan).
     - Jika belum ada simpanan: langsung mengeksekusi simpan tanpa hambatan.
     - Feedback: Menampilkan label status jujur (T49): jika berhasil *"Progres berhasil disimpan ke slot manual (Rev %d)"*; jika gagal *"Progres belum tersimpan. Coba lagi atau gunakan lokasi simpan yang dapat ditulis."*.
   - **Kasus 2: Muat Permainan (Modal Slot Picker)**
     - Membuka `SlotPickerModal` yang membaca metadata via `SaveManager.get_slot_metadata("manual")` dan `SaveManager.get_slot_metadata("autosave")`.
     - Menampilkan tanggal/jam ISO, nomor revisi, dan status slot (misal: "Siap Dimuat" atau "Kosong").
     - Saat pemain memilih slot yang valid, sistem menampilkan `ConfirmationModal`: *"Perubahan sejak simpanan terakhir akan hilang. Muat simpanan ini?"* (Peringatan data belum disimpan / T53).
     - Opsi: `[Muat]` (menjalankan `SaveManager.load_game(slot)` -> menutup semua menu -> kembali ke dunia) dan `[Batal]` (kembali ke pemilih slot).
     - Jika pembacaan berkas gagal (T17/T47), error ditampilkan di menu tanpa menutup aplikasi atau merusak state live.
   - **Kasus 3: Keluar Permainan / Game Baru (T53)**
     - Pemain mengklik "Keluar ke Desktop" atau "Menu Utama":
     - Menampilkan dialog 3 pilihan (UI_UX UI06):
       - `[Simpan dan Keluar]`: Memanggil `SaveManager.save_game("manual")`. Jika sukses, aplikasi keluar via `get_tree().quit()`. Jika gagal (misal simulasi disk write error), aplikasi **tidak keluar**, modal ditutup, dan error jujur ditampilkan di layar jeda agar pemain tidak kehilangan data secara diam-diam.
       - `[Keluar Tanpa Simpan]`: Langsung memanggil `get_tree().quit()`.
       - `[Batal]`: Menutup modal konfirmasi, fokus kembali ke tombol Keluar, tidak ada aksi yang dieksekusi.

5. **Pengaturan Terisolasi dan Integrasi Runtime (T21, T52)**:
   - Sesuai `SaveManagerClass`, konfigurasi disimpan di `user://settings.cfg`.
   - Nilai pengaturan diaplikasikan langsung ke runtime:
     - `mouse_sensitivity_multiplier`: dikalikan dengan `PlayerConfig.DEFAULT_MOUSE_SENSITIVITY` pada `PlayerController`.
     - `fov`: langsung memperbarui `player.fov` (yang otomatis membatasi rentang 60°–100° dan menggeser `camera.fov`).
     - `head_bob`: mengaktifkan/menonaktifkan goyangan kamera first person.
     - `ui_scale`: mengatur `get_tree().root.content_scale_factor = ui_scale` (rentang 0.8 s/d 1.5).
     - `master_volume`, `music_volume`, `sfx_volume`: mengonversi linear 0.0–1.0 ke desibel via `linear_to_db` pada bus `AudioServer`.
     - `subtitles`: disimpan untuk kebutuhan teks dialog warga.
   - Pemanggilan `load_game()` tidak menimpa pengaturan karena `settings.cfg` terpisah dari snapshot save game (T52).

6. **Kembali ke Posisi Aman (Safe Return Home)**:
   - Sesuai LVL-001 dan PRD FR17, opsi *"Kembali ke Pekarangan (Posisi Aman)"* memanggil pemindahan koordinat pemain ke `Vector3(0.0, 0.0, 8.0)` dengan kecepatan nol (`velocity = Vector3.ZERO`).
   - Tidak mereset inventaris, kondisi tanaman, atau progres kompor.
   - Menu jeda ditutup, mouse dikunci kembali, dan toast HUD menampilkan *"Pemain dipindahkan ke posisi aman pekarangan rumah."*.

---

## 3. Caveats

1. **Status Autoload GameManager**:
   Meskipun dokumen `PROJECT.md` menyebutkan `scripts/core/game_manager.gd`, file tersebut saat ini belum ada dan tidak terdaftar di `project.godot`. Seluruh alur jeda, input, dan penyimpanan sudah diorkestrasi secara mandiri dan elegan oleh `InputManager` dan `SaveManager`. Memaksakan autoload baru yang redundant tidak dianjurkan; cukup integrasikan `PauseMenu` langsung dengan `InputManager` dan `SaveManager`.
2. **Audio Buses**:
   Jika bus audio `Music` dan `SFX` belum ditambahkan di default audio bus layout Godot (`default_bus_layout.tres`), `AudioServer` saat ini hanya memiliki bus `Master` (index 0). Implementer harus memastikan penyesuaian volume musik/SFX melakukan fallback ke bus yang tersedia atau mendaftarkan bus layout standar agar tidak terjadi error index out of bounds.
3. **Kompatibilitas Layar Headless**:
   Di lingkungan pengujian headless CLI (`godot --headless`), fungsi `DisplayServer.window_set_mode` dan visual rendering tidak memiliki jendela fisik OS. Oleh karena itu, verifikasi otomatis harus menguji nilai konfigurasi dan logika state, sementara pengujian visual UI scale dilakukan saat playtest GUI.

---

## 4. Conclusion & Rekomendasi Arsitektur untuk Worker

Worker dapat langsung mengimplementasikan milestone UI-001 berdasarkan cetak biru berikut:

### 4.1 Struktur Scene dan Node Hierarchy (`scenes/ui/pause_menu.tscn`)

```
PauseMenu (CanvasLayer, layer = 15, process_mode = PROCESS_MODE_ALWAYS)
└── RootControl (Control, anchors_preset = PRESET_FULL_RECT)
    ├── BackgroundDimmer (ColorRect, color = Color(0.08, 0.08, 0.10, 0.80))
    │
    ├── MainPanel (PanelContainer, anchors_preset = PRESET_CENTER, custom_minimum_size = (480, 540))
    │   └── MarginContainer (margin = 24)
    │       └── VBoxContainer
    │           ├── TitleLabel (Label, text = "MENU JEDA", font_size = 32, horizontal_alignment = CENTER)
    │           ├── SubtitleLabel (Label, text = "Buku Resep 2045", font_size = 18, font_color = muted)
    │           ├── HSeparator
    │           ├── ButtonsVBox (VBoxContainer, separation = 10)
    │           │   ├── ResumeButton (Button, text = "Lanjutkan")
    │           │   ├── SaveButton (Button, text = "Simpan Permainan")
    │           │   ├── LoadButton (Button, text = "Muat Permainan")
    │           │   ├── SettingsButton (Button, text = "Pengaturan")
    │           │   ├── ReturnHomeButton (Button, text = "Kembali ke Pekarangan (Posisi Aman)")
    │           │   └── ExitButton (Button, text = "Keluar ke Desktop")
    │           ├── HSeparator
    │           └── StatusLabel (Label, text = "", horizontal_alignment = CENTER, autowrap_mode = WORD)
    │
    ├── SettingsPanel (PanelContainer, visible = false, anchors_preset = PRESET_CENTER, custom_minimum_size = (720, 560))
    │   └── MarginContainer (margin = 24)
    │       └── VBoxContainer
    │           ├── SettingsTitle (Label, text = "PENGATURAN", font_size = 28, horizontal_alignment = CENTER)
    │           ├── TabContainer
    │           │   ├── TabKendali (VBoxContainer, name = "Kendali")
    │           │   │   ├── HBoxSens (Label "Sensitivitas Mouse", HSlider 0.1..3.0, ValueLabel)
    │           │   │   └── CheckHeadBob (CheckButton "Goyangan Kepala (Head Bob)")
    │           │   ├── TabTampilan (VBoxContainer, name = "Tampilan")
    │           │   │   ├── HBoxFOV (Label "Sudut Pandang (FOV)", HSlider 60..100, ValueLabel)
    │           │   │   ├── HBoxUIScale (Label "Skala Antarmuka (UI Scale)", HSlider 0.8..1.5, ValueLabel)
    │           │   │   └── HBoxWindowMode (Label "Mode Layar", OptionButton [Jendela, Layar Penuh])
    │           │   ├── TabAudio (VBoxContainer, name = "Audio")
    │           │   │   ├── HBoxMaster (Label "Volume Utama", HSlider 0..100%, ValueLabel)
    │           │   │   ├── HBoxMusic (Label "Volume Musik", HSlider 0..100%, ValueLabel)
    │           │   │   └── HBoxSFX (Label "Volume Efek Suara", HSlider 0..100%, ValueLabel)
    │           │   ├── TabKenyamanan (VBoxContainer, name = "Aksesibilitas")
    │           │   │   └── CheckSubtitles (CheckButton "Tampilkan Subtitle & Teks Informasi")
    │           │   └── TabBantuan (VBoxContainer, name = "Bantuan Kontrol")
    │           │       └── ControlsGrid (GridContainer 2 kolom: daftar tombol WASD, E, LMB, B, Tab, Esc)
    │           ├── HSeparator
    │           └── SettingsButtonsHBox (HBoxContainer, alignment = END)
    │               ├── ResetDefaultsButton (Button, text = "Kembalikan Default")
    │               ├── ApplySettingsButton (Button, text = "Simpan Pengaturan")
    │               └── BackSettingsButton (Button, text = "Kembali")
    │
    ├── SlotPickerModal (PanelContainer, visible = false, anchors_preset = PRESET_CENTER, custom_minimum_size = (540, 360))
    │   └── MarginContainer (margin = 20)
    │       └── VBoxContainer
    │           ├── SlotPickerTitle (Label, text = "PILIH SIMPANAN UNTUK DIMUAT", font_size = 22, horizontal_alignment = CENTER)
    │           ├── HSeparator
    │           ├── SlotManualButton (Button, text = "Slot Manual — Memuat...", custom_minimum_size = (0, 60))
    │           ├── SlotAutosaveButton (Button, text = "Slot Otomatis — Memuat...", custom_minimum_size = (0, 60))
    │           ├── HSeparator
    │           └── CloseSlotPickerButton (Button, text = "Kembali")
    │
    └── ConfirmModal (PanelContainer, visible = false, anchors_preset = PRESET_CENTER, custom_minimum_size = (480, 240))
        └── MarginContainer (margin = 20)
            └── VBoxContainer
                ├── ModalTitle (Label, text = "KONFIRMASI", font_size = 22, horizontal_alignment = CENTER)
                ├── ModalMessage (Label, text = "Pesan konfirmasi di sini...", autowrap_mode = WORD, horizontal_alignment = CENTER)
                ├── HSeparator
                └── ModalButtonsHBox (HBoxContainer, alignment = CENTER, separation = 16)
                    ├── ModalBtn1 (Button, text = "Ya")
                    ├── ModalBtn2 (Button, text = "Pilihan 2")
                    └── ModalBtnCancel (Button, text = "Batal")
```

### 4.2 Kontrak Kode Skrip `scripts/ui/pause_menu.gd`

```gdscript
class_name PauseMenu
extends CanvasLayer

## PauseMenu — Pengelola Antarmuka Menu Jeda dan Navigasi Modal untuk 'Buku Resep 2045'
## Memenuhi UI_UX.md UI06, § 3, § 4, PRD FR16, FR21, dan TEST_PLAN T18, T21, T28, T51–T54

@onready var root_control: Control = $RootControl
@onready var main_panel: PanelContainer = find_child("MainPanel", true, false)
@onready var resume_button: Button = find_child("ResumeButton", true, false)
@onready var save_button: Button = find_child("SaveButton", true, false)
@onready var load_button: Button = find_child("LoadButton", true, false)
@onready var settings_button: Button = find_child("SettingsButton", true, false)
@onready var return_home_button: Button = find_child("ReturnHomeButton", true, false)
@onready var exit_button: Button = find_child("ExitButton", true, false)
@onready var status_label: Label = find_child("StatusLabel", true, false)

# Sub-panels
@onready var settings_panel: PanelContainer = find_child("SettingsPanel", true, false)
@onready var slot_picker_modal: PanelContainer = find_child("SlotPickerModal", true, false)
@onready var confirm_modal: PanelContainer = find_child("ConfirmModal", true, false)

# Modal Elements
@onready var modal_title: Label = find_child("ModalTitle", true, false)
@onready var modal_message: Label = find_child("ModalMessage", true, false)
@onready var modal_btn_1: Button = find_child("ModalBtn1", true, false)
@onready var modal_btn_2: Button = find_child("ModalBtn2", true, false)
@onready var modal_btn_cancel: Button = find_child("ModalBtnCancel", true, false)

# Slot Picker Elements
@onready var slot_manual_btn: Button = find_child("SlotManualButton", true, false)
@onready var slot_auto_btn: Button = find_child("SlotAutosaveButton", true, false)
@onready var close_slot_picker_btn: Button = find_child("CloseSlotPickerButton", true, false)

var _subpanel_stack: Array[Control] = []
var _last_focused_control: Control = null
var _current_modal_action: Callable = Callable()

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false
    _connect_signals()
    _connect_input_manager()

func _connect_signals() -> void:
    if resume_button: resume_button.pressed.connect(resume_game)
    if save_button: save_button.pressed.connect(_on_save_pressed)
    if load_button: load_button.pressed.connect(_on_load_pressed)
    if settings_button: settings_button.pressed.connect(_on_settings_pressed)
    if return_home_button: return_home_button.pressed.connect(_on_return_home_pressed)
    if exit_button: exit_button.pressed.connect(_on_exit_pressed)

    if slot_manual_btn: slot_manual_btn.pressed.connect(func(): _on_slot_selected("manual"))
    if slot_auto_btn: slot_auto_btn.pressed.connect(func(): _on_slot_selected("autosave"))
    if close_slot_picker_btn: close_slot_picker_btn.pressed.connect(pop_subpanel)

    if modal_btn_cancel: modal_btn_cancel.pressed.connect(pop_subpanel)

func _connect_input_manager() -> void:
    var im := _get_input_manager()
    if im and im.has_signal("context_changed"):
        im.context_changed.connect(_on_context_changed)

func _on_context_changed(new_context: int, _old_context: int) -> void:
    var im := _get_input_manager()
    if im == null: return
    if new_context == im.ContextMode.PAUSE:
        open_menu()
    elif visible:
        close_menu_silent()

func open_menu() -> void:
    visible = true
    _subpanel_stack.clear()
    if main_panel: main_panel.visible = true
    if settings_panel: settings_panel.visible = false
    if slot_picker_modal: slot_picker_modal.visible = false
    if confirm_modal: confirm_modal.visible = false
    if status_label: status_label.text = ""
    call_deferred("_focus_resume")

func _focus_resume() -> void:
    if resume_button and resume_button.is_visible_in_tree():
        resume_button.grab_focus()

func resume_game() -> void:
    var im := _get_input_manager()
    if im:
        im.consume_and_close(&"pause_menu")
    else:
        visible = false

func close_menu_silent() -> void:
    visible = false
    _subpanel_stack.clear()

# ==============================================================================
# SUBPANEL & MODAL STACK (T18, T28, T51)
# ==============================================================================

func push_subpanel(panel: Control, initial_focus: Control = null) -> void:
    _last_focused_control = get_viewport().gui_get_focus_owner()
    _subpanel_stack.append(panel)
    panel.visible = true
    if initial_focus and initial_focus.is_visible_in_tree():
        initial_focus.grab_focus()

func pop_subpanel() -> void:
    if _subpanel_stack.is_empty():
        return
    var top := _subpanel_stack.pop_back() as Control
    if top: top.visible = false
    if _last_focused_control and is_instance_valid(_last_focused_control) and _last_focused_control.is_visible_in_tree():
        _last_focused_control.grab_focus()
    elif resume_button:
        resume_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    if event.is_action_pressed("pause_menu") and not event.is_echo():
        if not _subpanel_stack.is_empty():
            pop_subpanel()
            get_viewport().set_input_as_handled()
        else:
            resume_game()
            get_viewport().set_input_as_handled()

# ==============================================================================
# ACTIONS & CONFIRMATIONS (T53, Overwrite, Safe Return)
# ==============================================================================

func _on_save_pressed() -> void:
    var sm := _get_save_manager()
    if sm == null: return
    if sm.has_valid_save("manual"):
        var meta := sm.get_slot_metadata("manual")
        var date_str: String = meta.get("timestamp_iso", "")
        _show_confirm(
            "Konfirmasi Timpa Simpanan",
            "Slot manual sudah berisi data (Revisi %d, %s).\nApakah Anda ingin menimpa data ini?" % [meta.get("revision", 1), date_str],
            "Ya, Timpa",
            func(): _execute_save("manual"),
            "",
            Callable()
        )
    else:
        _execute_save("manual")

func _execute_save(slot_type: String) -> void:
    var sm := _get_save_manager()
    if sm == null: return
    var res := sm.save_game(slot_type)
    if res.get("success", false):
        _show_status("Progres berhasil disimpan ke slot manual (Rev %d)." % res.get("revision", 0), false)
    else:
        _show_status(str(res.get("message", "Gagal menyimpan progres.")), true)

func _on_load_pressed() -> void:
    _refresh_slot_picker()
    push_subpanel(slot_picker_modal, slot_manual_btn)

func _refresh_slot_picker() -> void:
    var sm := _get_save_manager()
    if sm == null: return
    var manual_meta := sm.get_slot_metadata("manual")
    if manual_meta.get("valid", false):
        slot_manual_btn.text = "Slot Manual — Rev %d (%s)" % [manual_meta.get("revision", 1), manual_meta.get("timestamp_iso", "")]
        slot_manual_btn.disabled = false
    else:
        slot_manual_btn.text = "Slot Manual — [Kosong]"
        slot_manual_btn.disabled = true

    var auto_meta := sm.get_slot_metadata("autosave")
    if auto_meta.get("valid", false):
        slot_auto_btn.text = "Slot Otomatis — Rev %d (%s)" % [auto_meta.get("revision", 1), auto_meta.get("timestamp_iso", "")]
        slot_auto_btn.disabled = false
    else:
        slot_auto_btn.text = "Slot Otomatis — [Kosong]"
        slot_auto_btn.disabled = true

func _on_slot_selected(slot_type: String) -> void:
    _show_confirm(
        "Peringatan Muat Simpanan",
        "Perubahan sejak simpanan terakhir akan hilang.\nApakah Anda yakin ingin memuat slot '%s'?" % slot_type,
        "Ya, Muat",
        func(): _execute_load(slot_type),
        "",
        Callable()
    )

func _execute_load(slot_type: String) -> void:
    var sm := _get_save_manager()
    if sm == null: return
    var res := sm.load_game(slot_type)
    if res.get("success", false):
        _show_status("Simpanan '%s' berhasil dimuat." % slot_type, false)
        pop_subpanel() # pop confirm
        pop_subpanel() # pop picker
        resume_game()  # return to live world
    else:
        _show_status(str(res.get("message", "Gagal memuat simpanan.")), true)

func _on_return_home_pressed() -> void:
    _show_confirm(
        "Kembali ke Posisi Aman",
        "Pindahkan posisi pemain kembali ke pekarangan rumah?\n(Kondisi inventaris, kebun, dan masakan tetap utuh).",
        "Pindahkan",
        _execute_return_home,
        "",
        Callable()
    )

func _execute_return_home() -> void:
    var tree := Engine.get_main_loop() as SceneTree
    if tree and tree.root:
        var player = tree.root.find_child("Player", true, false)
        if player:
            player.global_position = Vector3(0.0, 0.0, 8.0)
            if "velocity" in player: player.velocity = Vector3.ZERO
    resume_game()

func _on_settings_pressed() -> void:
    push_subpanel(settings_panel)

func _on_exit_pressed() -> void:
    _show_confirm(
        "Peringatan Keluar Permainan",
        "Kemajuan permainan belum tentu tersimpan ke checkpoint.\nPilih tindakan sebelum keluar:",
        "Simpan & Keluar",
        _execute_save_and_exit,
        "Keluar Tanpa Simpan",
        func(): get_tree().quit()
    )

func _execute_save_and_exit() -> void:
    var sm := _get_save_manager()
    if sm:
        var res := sm.save_game("manual")
        if not res.get("success", false):
            # T49: Jangan keluar jika save gagal, tetap di menu dan jelaskan!
            pop_subpanel()
            _show_status(str(res.get("message", "Progres belum tersimpan. Coba lagi atau gunakan lokasi simpan yang dapat ditulis.")), true)
            return
    get_tree().quit()

func _show_confirm(title: String, msg: String, btn1_text: String, btn1_action: Callable, btn2_text: String = "", btn2_action: Callable = Callable()) -> void:
    if modal_title: modal_title.text = title
    if modal_message: modal_message.text = msg
    if modal_btn_1:
        modal_btn_1.text = btn1_text
        modal_btn_1.visible = true
        for conn in modal_btn_1.pressed.get_connections(): modal_btn_1.pressed.disconnect(conn.callable)
        modal_btn_1.pressed.connect(func():
            pop_subpanel()
            btn1_action.call()
        )
    if modal_btn_2:
        if btn2_text.is_empty():
            modal_btn_2.visible = false
        else:
            modal_btn_2.text = btn2_text
            modal_btn_2.visible = true
            for conn in modal_btn_2.pressed.get_connections(): modal_btn_2.pressed.disconnect(conn.callable)
            modal_btn_2.pressed.connect(func():
                pop_subpanel()
                btn2_action.call()
            )
    push_subpanel(confirm_modal, modal_btn_cancel) # Default focus to cancel for safety

func _show_status(msg: String, is_error: bool) -> void:
    if status_label:
        status_label.text = msg
        status_label.modulate = Color(1.0, 0.4, 0.4) if is_error else Color(0.4, 1.0, 0.4)

func _get_input_manager() -> Node:
    if Engine.has_singleton("InputManager"): return Engine.get_singleton("InputManager")
    var tree := Engine.get_main_loop() as SceneTree
    if tree and tree.root and tree.root.has_node("InputManager"): return tree.root.get_node("InputManager")
    return null

func _get_save_manager() -> Node:
    if Engine.has_singleton("SaveManager"): return Engine.get_singleton("SaveManager")
    var tree := Engine.get_main_loop() as SceneTree
    if tree and tree.root and tree.root.has_node("SaveManager"): return tree.root.get_node("SaveManager")
    return null
```

### 4.3 Penyempurnaan `scripts/core/input_manager.gd` untuk Auto-Pause

Ubah baris 174–176 di `scripts/core/input_manager.gd`:
```gdscript
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if auto_pause_on_focus_loss and get_current_context() != ContextMode.PAUSE:
			push_context(ContextMode.PAUSE)
```

### 4.4 Integrasi Scene `scenes/main.tscn`

Tambahkan instansiasi scene jeda di bawah hierarki UI `scenes/main.tscn`:
```
[ext_resource type="PackedScene" path="res://scenes/ui/pause_menu.tscn" id="9_pause"]
...
[node name="PauseMenu" parent="." instance=ExtResource("9_pause")]
```

---

## 5. Verification Method

Untuk memverifikasi secara independen bahwa rancangan ini memenuhi kriteria penerimaan P0 (T18, T21, T28, T51, T52, T53, T54):

1. **Pemeriksaan File & Struktur**:
   - `scenes/ui/pause_menu.tscn` dan `scripts/ui/pause_menu.gd` dibuat sesuai hierarki di atas.
   - `scenes/main.tscn` memuat node `PauseMenu`.

2. **Perintah Eksekusi Uji Otomatis Headless**:
   Jalankan test suite baru `TestUI` via CLI runner:
   ```powershell
   & "C:\Users\HP\.local\bin\godot_console.exe" --headless --path "c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia" --script res://tests/test_runner.gd
   ```

3. **Kasus Uji Wajib yang Diverifikasi di `tests/suites/test_ui.gd`**:
   - **T18.PAUSE**:
     - Membuka menu jeda -> verifikasi `InputManager.get_current_context() == ContextMode.PAUSE`.
     - Verifikasi `InputManager.is_simulation_paused() == true`.
     - Menutup menu jeda -> verifikasi `InputManager.can_interact_in_world() == false` pada frame penutupan (anti-leak).
     - Simulasi `NOTIFICATION_APPLICATION_FOCUS_OUT` -> verifikasi konteks beralih ke `PAUSE`.
   - **T21.VIDEO**:
     - Ubah slider FOV ke 60° dan 100° -> verifikasi `PlayerController.fov` dan `Camera3D.fov` bernilai 60 dan 100.
     - Ubah UI scale ke 1.25 -> verifikasi konten scale terapkan tanpa error.
   - **T28.ESC_STACK**:
     - Buka Pause Menu -> buka SlotPicker -> buka ConfirmModal.
     - Tekan Esc -> hanya ConfirmModal tertutup, SlotPicker tetap terbuka.
     - Tekan Esc -> SlotPicker tertutup, Pause Menu tetap terbuka.
     - Tekan Esc -> Pause Menu tertutup, konteks kembali ke `WORLD`.
   - **T51.KEYBOARD_FOCUS**:
     - Buka menu jeda -> verifikasi `ResumeButton.has_focus() == true`.
     - Buka konfirmasi modal -> verifikasi `ModalBtnCancel.has_focus() == true` (default aman).
   - **T52.SETTINGS_PERSISTENCE**:
     - Ubah pengaturan di menu, panggil `save_settings`.
     - Muat snapshot save lama via `SaveManager.load_game`.
     - Verifikasi pengaturan di `user://settings.cfg` tidak tertimpa snapshot lama.
   - **T53.UNSAVED_PROGRESS_EXIT**:
     - Buka konfirmasi keluar -> pilih "Simpan dan Keluar".
     - Simulasikan `SaveManager.simulate_write_failure = true`.
     - Verifikasi aplikasi tidak memanggil quit, modal ditutup, dan label status menampilkan pesan error jujur.
     - Pilih "Batal" -> verifikasi menu tetap terbuka tanpa perubahan state.

4. **Kondisi Invalidasi**:
   - Jika Esc menutup seluruh menu jeda sekaligus saat dialog konfirmasi aktif -> GAGAL T28.
   - Jika klik tombol "Lanjutkan" memicu interaksi atau klik alat di dunia 3D pada frame yang sama -> GAGAL T18.
   - Jika pengaturan audio/video tertimpa saat memuat checkpoint lama -> GAGAL T52.
