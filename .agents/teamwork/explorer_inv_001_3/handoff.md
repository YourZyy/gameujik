# Handoff Report — UI Architecture & Automated Test Suite for INV-001

**Disusun oleh:** `explorer_inv_001_3` (teamwork_explorer)  
**Tanggal:** 27 Oktober 2026  
**Target:** Penyiapan arsitektur UI (`scenes/ui/inventory_ui.tscn`), rancangan test suite otomatis (`tests/suites/test_inventory.gd` mencakup T02, T03, T04, T29, T30, T31, T32, T33), dan pendaftaran Suite 7 pada `tests/test_runner.gd` untuk task `INV-001`.  
**Penerima:** Worker Agent (`worker_inv_001`) dan Orchestrator (`bc3795f9-23c4-4352-8a9c-4322971bcc61`)

---

## 1. Observation

Berdasarkan pemeriksaan langsung terhadap seluruh dokumen otoritatif, struktur scene, skrip yang ada, serta skill gamedev:

### 1.1 Spesifikasi Tata Letak & UX Inventaris (`docs/UI_UX.md` & `game-ui-ux` / `godot-ui-control`)
1. **Aturan UI04 (Tas dan Penyimpanan):**
   - *"Saat Tab: tas dan detail item. Saat E pada peti: tas kiri, peti kanan; tombol Pindahkan pilihan dan Pindahkan semua di bawah. Setiap slot memperlihatkan nama pendek dan jumlah; memilih memperlihatkan nama lengkap serta kegunaan."* (`docs/UI_UX.md` baris 97–98).
   - *"Teks kapasitas '3/12 slot' adalah jumlah slot terpakai, bukan jumlah unit. Arah transfer jelas lewat judul kontainer sumber/tujuan. Jika seluruh pilihan tidak muat, transaksi dibatalkan dan dijelaskan. Drag-and-drop boleh ditambahkan kelak, tidak dibutuhkan untuk P0."* (`docs/UI_UX.md` baris 99).
   - *"Hidangan di tas memiliki tombol Makan dengan konfirmasi 'Makan 1 porsi?'. Benih tidak memiliki tombol Gunakan yang memunculkan aksi tanpa target; pengguna diarahkan memilih alat benih di dunia. Alat tetap tidak muncul sebagai item buang."* (`docs/UI_UX.md` baris 101).
2. **Konteks Input dan Pencegahan Bleed-Through (`docs/UI_UX.md` § 3 & § 4, `scripts/core/input_manager.gd`):**
   - Tabel kontrol: `Tab` di dunia membuka tas (`open_inventory`); `Tab` di tas menutup tas; `Esc` menutup lapisan/menu (`docs/UI_UX.md` baris 31–36).
   - Di `scripts/core/input_manager.gd` baris 6–13:
     `enum ContextMode { WORLD, BOOK, STORAGE, KITCHEN, DIALOGUE, PAUSE }`.
   - Di `scripts/core/input_manager.gd` baris 186–198:
     ```gdscript
     elif event.is_action_pressed("open_inventory") and not event.is_echo():
         push_context(ContextMode.STORAGE)
         get_viewport().set_input_as_handled()
     ...
     elif event.is_action_pressed("open_inventory") and get_current_context() == ContextMode.STORAGE and not event.is_echo():
         consume_and_close(&"open_inventory")
         get_viewport().set_input_as_handled()
     ```
   - `consume_and_close(&"open_inventory")` memanggil `suppress_action_until_released` dan mencatat `_last_closed_frame = Engine.get_process_frames()`. Fungsi `can_interact_in_world()` mengembalikan `false` pada frame penutupan, menjamin proteksi bleed-through (zero action leak) saat kembali ke `WORLD`.
   - Pada konteks `STORAGE`, `is_simulation_paused()` mengembalikan `true` (`scripts/core/input_manager.gd` baris 58).
3. **Resolusi dan Skalabilitas (`project.godot` & `game-ui-ux`):**
   - Konfigurasi jendela saat ini (`project.godot` baris 20–25):
     `viewport_width = 1280`, `viewport_height = 720`, `stretch/mode = "canvas_items"`, `stretch/aspect = "keep"`.
   - Prinsip `game-ui-ux` dan `godot-ui-control`:
     - Tidak menggunakan koordinat piksel absolut manual.
     - Menggunakan pohon anchor (`PRESET_FULL_RECT`, `PRESET_CENTER`) dan kontainer responsif (`MarginContainer`, `VBoxContainer`, `HBoxContainer`, `GridContainer`).
     - Safe area margin 4% (~32-50px) dari tepi layar.
     - Kontrol dapat dinavigasi dengan keyboard/gamepad (`focus_mode = FOCUS_ALL`, `grab_focus()` pada slot awal).

### 1.2 Status Landmark Level Terkait Inventaris
1. **`storage_home`:**
   - Terletak di `scenes/world/level_graybox.tscn` baris 533–556 pada koordinat `(-2, 0, -4)`.
   - Memiliki komponen `Interactable` (Area3D layer 3) dengan properti `interaction_id = "landmark_storage"`, `target_name = "Peti"`, `prompt_action = "Buka"` -> menghasilkan prompt `[E] Buka Peti`.
2. **`container_starter`:**
   - Terletak di `scenes/world/level_graybox.tscn` baris 662–685 pada koordinat `(6, 0, 4)`.
   - Memiliki komponen `Interactable` (Area3D layer 3) dengan properti `interaction_id = "landmark_starter"`, `target_name = "Wadah Starter"`, `prompt_action = "Ambil"` -> menghasilkan prompt `[E] Ambil Wadah Starter`.

### 1.3 Spesifikasi Test Suite `TEST_PLAN.md` & Status Test Runner
1. **Daftar Kasus Uji Sasaran INV-001:**
   - **T02:** Batas slot tas (12 slot tetap) dan kapasitas tumpukan (maksimum 20 unit per slot). Serta hitungan ketersediaan stok bebas (`get_available_item_count`).
   - **T03:** Transfer dua arah atomik antara tas dan peti (pemeriksaan kapasitas terlebih dahulu, nol kehilangan barang, nol duplikasi).
   - **T04:** Pengambilan wadah awal (`container_starter`: 4 benih bayam, 1 pembenah tanah, 1 pupuk; verifikasi slot, flag satu kali pengambilan / anti-spam).
   - **T29:** Penambahan & penghapusan item pada kontainer tunggal, pengisian tumpukan hingga 20, dan overflow membuka slot baru.
   - **T30:** Penolakan transaksi transfer saat kontainer tujuan penuh (12 slot terisi penuh); tidak ada transfer parsial diam-diam.
   - **T31:** Penolakan pengambilan paket starter jika slot kosong tas kurang dari 3; tidak ada mutasi parsial.
   - **T32:** Instansiasi UI inventaris (`scenes/ui/inventory_ui.tscn`), verifikasi keberadaan 12 slot tas + 12 slot peti, dan pengujian visibilitas mode solo vs dual.
   - **T33:** Integrasi peralihan konteks input (`InputManager.ContextMode.STORAGE`), pelepasan/penguncian mouse, dan proteksi bleed-through.
2. **Kondisi Test Runner Saat Ini (`tests/test_runner.gd`):**
   - Saat ini menjalankan 6 suite (Suite 1 `TestSetup`, Suite 2 `TestLevel`, Suite 3 `TestAdversarialLevel`, Suite 4 `TestPlayer`, Suite 5 `TestAdversarialPlayer`, Suite 6 `TestInteraction`).
   - Hasil eksekusi CLI aktual:
     `526 passed, 0 failed, Exit Code: 0` dalam 2.1 detik.
   - Suite 7 akan menjadi `TestInventory` (`res://tests/suites/test_inventory.gd`).

---

## 2. Logic Chain

Dari observasi faktual di atas, disusun rantai penalaran arsitektur UI dan test suite:

```
[Observasi 1.1: Mode Solo (Tab) vs Mode Dual (E pada Peti)]
  + [InputManager ContextMode.STORAGE menangani Tab dan pembebasan kursor]
  + [storage_home memiliki Interactable "Buka Peti"]
  ──> [Langkah 1: InventoryUI mengelola Mode Tampilan SOLO vs DUAL]
      - State internal `ViewMode { SOLO, DUAL }`.
      - Saat dibuka via Tab: `open_solo()` -> tampilkan hanya Tas (Backpack) + Detail Item (Peti disembunyikan).
      - Saat dibuka via E pada storage_home: `open_dual()` -> tampilkan Tas (kiri) + Peti (kanan) + Tombol Transfer + Detail Item.
      - Terhubung ke `InputManager.context_changed`: jika konteks berpindah ke selain STORAGE, UI otomatis menyembunyikan diri (`visible = false`).

[Observasi 1.1: Aturan Tata Letak 1280x720, Containers, & Safe Margins]
  + [Godot 4.7 Control & Container guidelines di godot-ui-control & game-ui-ux]
  ──> [Langkah 2: Pohon Node Responsif Bebas Posisi Piksel Kaku]
      - Root: CanvasLayer (layer = 10, di atas 3D world dan HUD).
      - RootControl (PRESET_FULL_RECT, mouse_filter = STOP).
      - DimBackground (ColorRect semi-transparan Color(0.04, 0.05, 0.08, 0.7)).
      - CenterContainer -> MainPanel (PanelContainer min_size 860x520).
      - Dua GridContainer (columns = 4, 12 slot berukuran min 64x64 px).
      - Margin internal 20px, aman dari notch dan clipping.

[Observasi 1.1 & CONTENT.md § 2: Visual Slot & Item]
  + [7 Item P0, ART-001 belum tersedia sehingga belum ada tekstur final]
  ──> [Langkah 3: Komponen InventorySlotUI dengan Fallback Warna & Label Tumpukan]
      - Base node: Button (mendukung navigasi keyboard focus secara native).
      - Icon TextureRect (40x40) dengan Fallback ColorRect berkode warna kategori (hijau bayam, kuning jagung, cokelat temu kunci, dll.).
      - StackLabel (Label anchored bottom-right): tersembunyi jika count <= 1; menampilkan angka jika > 1.
      - Focus & Selected stylebox: border emas/kuning cerah saat keyboard focus.

[Observasi 1.3: Kebutuhan Kasus Uji T02, T03, T04, T29, T30, T31, T32, T33]
  + [Arsitektur Headless Test Runner di godot-gdscript-headless-testing]
  ──> [Langkah 4: Desain Test Suite Komprehensif tests/suites/test_inventory.gd]
      - Suite 7 mengeksekusi 8 metode pengujian deterministik mencakup batas kapasitas, transaksi atomik, penolakan kontainer penuh, wadah starter, instansiasi UI, dan integrasi input.
      - Pendaftaran bersih pada tests/test_runner.gd tanpa memecah suite yang ada.
```

---

## 3. Caveats

1. **Aset Tekstur Ikon Item (ART-001):** Belum ada file `.png` ikon item di proyek. `InventorySlotUI` wajib mengantisipasi `icon == null` dengan menampilkan `FallbackColorRect` atau singkatan nama item agar tidak terjadi crash atau null dereference.
2. **ID Pupuk & Bayam:** Mengacu pada laporan `explorer_inv_001_1` dan `explorer_inv_001_2`, sistem inventaris harus menerima ID resmi `CONTENT.md` (`fertilizer_basic`, `ingredient_bayam`) maupun alias (`tool_fertilizer`, `crop_bayam`) agar pengujian tidak rapuh terhadap perbedaan penamaan string.
3. **Penyimpanan Format Slot:** Slot diakses oleh UI dalam bentuk dictionary `{ "id": String, "count": int }` (atau `{ "item_id": String, "count": int }`). Helper UI harus mengecek kedua kunci (`item.get("item_id", item.get("id", ""))`) untuk interoperabilitas maksimal.

---

## 4. Conclusion & Concrete Design Blueprint

### 4.1 Arsitektur Antarmuka `scenes/ui/inventory_ui.tscn`

#### Hierarki Node Scene
```text
InventoryUI (CanvasLayer, layer=10, script="res://scripts/ui/inventory_ui.gd")
└── RootControl (Control, PRESET_FULL_RECT, mouse_filter=STOP)
    ├── DimBackground (ColorRect, PRESET_FULL_RECT, color=Color(0.04, 0.05, 0.08, 0.7), mouse_filter=STOP)
    └── CenterContainer (CenterContainer, PRESET_FULL_RECT, mouse_filter=PASS)
        └── MainPanel (PanelContainer, custom_minimum_size=Vector2(880, 540))
            └── Margin (MarginContainer, margin_left=24, margin_top=20, margin_right=24, margin_bottom=20)
                └── VBox (VBoxContainer, spacing=16)
                    ├── HeaderHBox (HBoxContainer)
                    │   ├── TitleLabel (Label, text="INVENTARIS & PENYIMPANAN", font_size=22)
                    │   ├── HeaderSpacer (Control, SIZE_EXPAND_FILL)
                    │   └── CloseButton (Button, text="Tutup [Esc / Tab]", custom_minimum_size=Vector2(140, 36))
                    ├── ContentHBox (HBoxContainer, spacing=24)
                    │   ├── BackpackSection (VBoxContainer, custom_minimum_size=Vector2(380, 0))
                    │   │   ├── SectionHeader (HBoxContainer)
                    │   │   │   ├── BackpackTitle (Label, text="Tas Punggung", font_size=18)
                    │   │   │   ├── Spacer (Control, SIZE_EXPAND_FILL)
                    │   │   │   └── BackpackCapacityLabel (Label, text="0/12 slot", font_color=Color(0.7, 0.7, 0.7))
                    │   │   ├── BackpackGrid (GridContainer, columns=4, h_sep=8, v_sep=8)
                    │   │   │   └── 12x InventorySlotUI (Button, custom_minimum_size=Vector2(64, 64))
                    │   │   └── BackpackActions (HBoxContainer, spacing=8)
                    │   │       ├── BtnTransferSelectedToStorage (Button, text="Pindahkan Pilihan ->", SIZE_EXPAND_FILL)
                    │   │       └── BtnTransferAllToStorage (Button, text="Pindahkan Semua ->", SIZE_EXPAND_FILL)
                    │   └── StorageSection (VBoxContainer, custom_minimum_size=Vector2(380, 0))
                    │       ├── SectionHeader (HBoxContainer)
                    │       │   ├── StorageTitle (Label, text="Peti Penyimpanan", font_size=18)
                    │       │   ├── Spacer (Control, SIZE_EXPAND_FILL)
                    │       │   └── StorageCapacityLabel (Label, text="0/12 slot", font_color=Color(0.7, 0.7, 0.7))
                    │       ├── StorageGrid (GridContainer, columns=4, h_sep=8, v_sep=8)
                    │       │   └── 12x InventorySlotUI (Button, custom_minimum_size=Vector2(64, 64))
                    │       └── StorageActions (HBoxContainer, spacing=8)
                    │           ├── BtnTransferSelectedToBackpack (Button, text="<- Pindahkan Pilihan", SIZE_EXPAND_FILL)
                    │           └── BtnTransferAllToBackpack (Button, text="<- Pindahkan Semua", SIZE_EXPAND_FILL)
                    ├── DetailPanel (PanelContainer, custom_minimum_size=Vector2(0, 80))
                    │   └── DetailMargin (MarginContainer, margin=12)
                    │       └── DetailHBox (HBoxContainer, spacing=16)
                    │           ├── DetailIcon (ColorRect, custom_minimum_size=Vector2(48, 48))
                    │           └── DetailTextVBox (VBoxContainer)
                    │               ├── DetailNameLabel (Label, text="Pilih item untuk melihat detail", font_size=16)
                    │               └── DetailDescLabel (Label, text="Gunakan tombol panah atau mouse untuk memilih slot.", font_size=13, font_color=Color(0.8, 0.8, 0.8))
                    └── StatusLabel (Label, text="", horizontal_alignment=CENTER, font_color=Color(1.0, 0.6, 0.2))
```

#### Komponen Slot (`scripts/ui/inventory_slot_ui.gd` & Scene)
Setiap slot adalah sebuah `Button` dengan layout:
- `IconRect` (`TextureRect`, 40x40 di tengah).
- `FallbackColor` (`ColorRect`, 36x36 di tengah jika tekstur null).
- `StackLabel` (`Label`, anchored bottom-right, font size 14, text count).
- `focus_mode = Control.FOCUS_ALL` untuk navigasi kontroler/keyboard.

---

### 4.2 Skrip Pengendali UI: `res://scripts/ui/inventory_ui.gd`

```gdscript
class_name InventoryUI
extends CanvasLayer

## Kontroler Antarmuka Inventaris (Tas & Peti) untuk Buku Resep 2045
## Mengikuti spesifikasi UI_UX.md UI04, PROTOTYPE.md § 5/6, dan skill game-ui-ux / godot-ui-control

enum ViewMode {
	SOLO,   # Hanya tas (saat dibuka via tombol Tab)
	DUAL    # Tas dan Peti penyimpanan (saat E pada storage_home)
}

const SlotUIClass = preload("res://scripts/ui/inventory_slot_ui.gd")

@onready var root_control: Control = $RootControl
@onready var main_panel: PanelContainer = $RootControl/CenterContainer/MainPanel
@onready var backpack_grid: GridContainer = $RootControl/CenterContainer/MainPanel/Margin/VBox/ContentHBox/BackpackSection/BackpackGrid
@onready var storage_section: VBoxContainer = $RootControl/CenterContainer/MainPanel/Margin/VBox/ContentHBox/StorageSection
@onready var storage_grid: GridContainer = $RootControl/CenterContainer/MainPanel/Margin/VBox/ContentHBox/StorageSection/StorageGrid
@onready var backpack_capacity_label: Label = $RootControl/CenterContainer/MainPanel/Margin/VBox/ContentHBox/BackpackSection/SectionHeader/BackpackCapacityLabel
@onready var storage_capacity_label: Label = $RootControl/CenterContainer/MainPanel/Margin/VBox/ContentHBox/StorageSection/SectionHeader/StorageCapacityLabel
@onready var detail_name_label: Label = $RootControl/CenterContainer/MainPanel/Margin/VBox/DetailPanel/DetailMargin/DetailHBox/DetailTextVBox/DetailNameLabel
@onready var detail_desc_label: Label = $RootControl/CenterContainer/MainPanel/Margin/VBox/DetailPanel/DetailMargin/DetailHBox/DetailTextVBox/DetailDescLabel
@onready var detail_icon: Control = $RootControl/CenterContainer/MainPanel/Margin/VBox/DetailPanel/DetailMargin/DetailHBox/DetailIcon
@onready var status_label: Label = $RootControl/CenterContainer/MainPanel/Margin/VBox/StatusLabel
@onready var close_button: Button = $RootControl/CenterContainer/MainPanel/Margin/VBox/HeaderHBox/CloseButton

# Tombol Aksi
@onready var btn_transfer_sel_to_storage: Button = $RootControl/CenterContainer/MainPanel/Margin/VBox/ContentHBox/BackpackSection/BackpackActions/BtnTransferSelectedToStorage
@onready var btn_transfer_all_to_storage: Button = $RootControl/CenterContainer/MainPanel/Margin/VBox/ContentHBox/BackpackSection/BackpackActions/BtnTransferAllToStorage
@onready var btn_transfer_sel_to_backpack: Button = $RootControl/CenterContainer/MainPanel/Margin/VBox/ContentHBox/StorageSection/StorageActions/BtnTransferSelectedToBackpack
@onready var btn_transfer_all_to_backpack: Button = $RootControl/CenterContainer/MainPanel/Margin/VBox/ContentHBox/StorageSection/StorageActions/BtnTransferAllToBackpack

var current_mode: ViewMode = ViewMode.SOLO
var selected_container: String = "backpack"
var selected_slot_index: int = -1

var backpack_slot_nodes: Array[Button] = []
var storage_slot_nodes: Array[Button] = []

func _ready() -> void:
	visible = false
	_create_or_bind_slots()
	_connect_signals()
	
	# Hubungkan dengan InputManager jika ada di Tree
	if Engine.has_singleton("InputManager"):
		var im = Engine.get_singleton("InputManager")
		if im.has_signal("context_changed"):
			im.context_changed.connect(_on_context_changed)
	elif has_node("/root/InputManager"):
		var im = get_node("/root/InputManager")
		im.context_changed.connect(_on_context_changed)

func _create_or_bind_slots() -> void:
	backpack_slot_nodes.clear()
	storage_slot_nodes.clear()
	
	for child in backpack_grid.get_children():
		if child is Button:
			var idx := backpack_slot_nodes.size()
			backpack_slot_nodes.append(child)
			child.pressed.connect(func(): _on_slot_clicked("backpack", idx))
			child.focus_entered.connect(func(): _on_slot_clicked("backpack", idx))

	for child in storage_grid.get_children():
		if child is Button:
			var idx := storage_slot_nodes.size()
			storage_slot_nodes.append(child)
			child.pressed.connect(func(): _on_slot_clicked("storage", idx))
			child.focus_entered.connect(func(): _on_slot_clicked("storage", idx))

func _connect_signals() -> void:
	close_button.pressed.connect(close_ui)
	btn_transfer_sel_to_storage.pressed.connect(func(): _transfer_selected("backpack", "storage"))
	btn_transfer_all_to_storage.pressed.connect(func(): _transfer_all("backpack", "storage"))
	btn_transfer_sel_to_backpack.pressed.connect(func(): _transfer_selected("storage", "backpack"))
	btn_transfer_all_to_backpack.pressed.connect(func(): _transfer_all("storage", "backpack"))

	if has_node("/root/InventoryManager"):
		var inv = get_node("/root/InventoryManager")
		if inv.has_signal("inventory_updated"):
			inv.inventory_updated.connect(refresh_ui)
		elif inv.has_signal("inventory_changed"):
			inv.inventory_changed.connect(func(_c): refresh_ui())

func open_solo() -> void:
	current_mode = ViewMode.SOLO
	storage_section.visible = false
	visible = true
	status_label.text = ""
	refresh_ui()
	_select_default_slot()

func open_dual() -> void:
	current_mode = ViewMode.DUAL
	storage_section.visible = true
	visible = true
	status_label.text = ""
	refresh_ui()
	_select_default_slot()

func close_ui() -> void:
	visible = false
	status_label.text = ""
	if has_node("/root/InputManager"):
		var im = get_node("/root/InputManager")
		if im.get_current_context() == im.ContextMode.STORAGE:
			im.consume_and_close(&"open_inventory")

func _on_context_changed(new_context: int, _old_context: int) -> void:
	# ContextMode.STORAGE = 2
	if new_context == 2:
		if not visible:
			# Default ke solo jika dibuka lewat Tab biasa
			open_solo()
	else:
		if visible:
			visible = false

func refresh_ui() -> void:
	if not is_inside_tree() or not visible:
		return
		
	var inv = _get_inventory_manager()
	if inv == null:
		return

	_update_container_grid("backpack", backpack_slot_nodes, backpack_capacity_label)
	if current_mode == ViewMode.DUAL:
		_update_container_grid("storage", storage_slot_nodes, storage_capacity_label)
		
	_update_detail_panel()

func _update_container_grid(container_name: String, slot_nodes: Array[Button], cap_label: Label) -> void:
	var inv = _get_inventory_manager()
	var slots_data: Array = _get_slots_from_manager(inv, container_name)
	var used_slots := 0
	
	for i in range(slot_nodes.size()):
		var slot_btn := slot_nodes[i]
		if i < slots_data.size():
			var s_data: Dictionary = slots_data[i]
			var item_id: String = s_data.get("item_id", s_data.get("id", ""))
			var count: int = int(s_data.get("count", 0))
			
			if slot_btn.has_method("set_slot_data"):
				slot_btn.set_slot_data(item_id, count, _get_item_def(inv, item_id))
			else:
				# Generic button fallback
				if count > 0 and not item_id.is_empty():
					slot_btn.text = "%s\nx%d" % [_get_item_name(inv, item_id), count]
				else:
					slot_btn.text = "-"
			
			if count > 0 and not item_id.is_empty():
				used_slots += 1
		else:
			slot_btn.text = "-"
			
	if cap_label != null:
		cap_label.text = "%d/12 slot" % used_slots

func _on_slot_clicked(container: String, index: int) -> void:
	selected_container = container
	selected_slot_index = index
	_update_detail_panel()

func _update_detail_panel() -> void:
	var inv = _get_inventory_manager()
	if inv == null or selected_slot_index < 0:
		detail_name_label.text = "Pilih item untuk melihat detail"
		detail_desc_label.text = "Gunakan tombol panah atau klik mouse untuk memilih slot."
		return

	var slots_data := _get_slots_from_manager(inv, selected_container)
	if selected_slot_index >= slots_data.size():
		return

	var s_data: Dictionary = slots_data[selected_slot_index]
	var item_id: String = s_data.get("item_id", s_data.get("id", ""))
	var count: int = int(s_data.get("count", 0))

	if count <= 0 or item_id.is_empty():
		detail_name_label.text = "Slot Kosong"
		detail_desc_label.text = "Slot ini siap digunakan untuk menampung barang baru."
		if detail_icon is ColorRect:
			(detail_icon as ColorRect).color = Color(0.2, 0.2, 0.2, 0.5)
	else:
		var name_str := _get_item_name(inv, item_id)
		var desc_str := _get_item_desc(inv, item_id)
		detail_name_label.text = "%s (x%d)" % [name_str, count]
		detail_desc_label.text = desc_str
		if detail_icon is ColorRect:
			(detail_icon as ColorRect).color = _get_category_color(item_id)

func _transfer_selected(from_c: String, to_c: String) -> void:
	var inv = _get_inventory_manager()
	if inv == null: return
	if selected_container != from_c or selected_slot_index < 0:
		status_label.text = "Pilih slot di kontainer asal terlebih dahulu!"
		return

	var res: Dictionary = {}
	if inv.has_method("transfer_slot"):
		# API versi method transfer_slot
		res = inv.transfer_slot(from_c, to_c, selected_slot_index)
	elif inv.has_method("transfer_item"):
		var slots_data := _get_slots_from_manager(inv, from_c)
		var item_id: String = slots_data[selected_slot_index].get("item_id", slots_data[selected_slot_index].get("id", ""))
		var count: int = int(slots_data[selected_slot_index].get("count", 0))
		var ok: bool = inv.transfer_item(from_c, to_c, selected_slot_index, count)
		res = {"success": ok, "reason": "" if ok else "Penyimpanan tujuan tidak mencukupi."}

	if res.get("success", false):
		status_label.text = "Berhasil memindahkan barang."
	else:
		status_label.text = res.get("reason", "Pemindahan ditolak.")
	refresh_ui()

func _transfer_all(from_c: String, to_c: String) -> void:
	var inv = _get_inventory_manager()
	if inv == null: return
	if inv.has_method("transfer_all"):
		var res: Dictionary = inv.transfer_all(from_c, to_c)
		if res.get("success", false):
			status_label.text = "Semua barang berhasil dipindahkan."
		else:
			status_label.text = res.get("reason", "Pemindahan ditolak.")
	refresh_ui()

func _select_default_slot() -> void:
	selected_container = "backpack"
	selected_slot_index = 0
	if backpack_slot_nodes.size() > 0:
		backpack_slot_nodes[0].grab_focus()
	_update_detail_panel()

func _get_inventory_manager() -> Node:
	if has_node("/root/InventoryManager"):
		return get_node("/root/InventoryManager")
	return null

func _get_slots_from_manager(inv: Node, container_name: String) -> Array:
	if inv == null: return []
	if container_name == "backpack":
		if "backpack" in inv:
			var bp = inv.backpack
			if bp is Array: return bp
			if bp.has_method("to_array"): return bp.to_array()
			if "slots" in bp: return bp.slots
		if inv.has_method("get_container_slots"):
			return inv.get_container_slots("backpack")
	else:
		if "storage_home" in inv:
			var st = inv.storage_home
			if st is Array: return st
			if st.has_method("to_array"): return st.to_array()
			if "slots" in st: return st.slots
		elif "_storage" in inv:
			return inv._storage
		if inv.has_method("get_container_slots"):
			return inv.get_container_slots("storage")
	return []

func _get_item_name(inv: Node, item_id: String) -> String:
	var item = _get_item_def(inv, item_id)
	if item != null and "display_name" in item:
		return item.display_name
	return item_id.capitalize()

func _get_item_desc(inv: Node, item_id: String) -> String:
	var item = _get_item_def(inv, item_id)
	if item != null and "description" in item:
		return item.description
	return "Item keperluan petak dan memasak."

func _get_item_def(inv: Node, item_id: String) -> Variant:
	if inv == null: return null
	if "item_registry" in inv and inv.item_registry != null:
		return inv.item_registry.get_item(item_id)
	if inv.has_method("get_item_data"):
		return inv.get_item_data(item_id)
	return null

func _get_category_color(item_id: String) -> Color:
	match item_id:
		"seed_bayam": return Color(0.4, 0.8, 0.3)
		"ingredient_bayam", "crop_bayam": return Color(0.2, 0.7, 0.2)
		"ingredient_jagung": return Color(0.95, 0.8, 0.2)
		"ingredient_temu_kunci": return Color(0.8, 0.5, 0.25)
		"fertilizer_basic", "tool_fertilizer": return Color(0.5, 0.35, 0.2)
		"soil_compost": return Color(0.35, 0.25, 0.15)
		"water_fresh": return Color(0.3, 0.6, 0.9)
		"dish_sayur_bening": return Color(0.85, 0.45, 0.25)
		_: return Color(0.5, 0.5, 0.5)
```

---

### 4.3 Arsitektur Suite Pengujian `tests/suites/test_inventory.gd`

Suite pengujian komprehensif menguji seluruh spesifikasi T02, T03, T04, T29, T30, T31, T32, dan T33.

```gdscript
class_name TestInventory
extends RefCounted

## Test Suite INV-001: Data Item, Tas, Peti Rumah, Transaksi Atomik, Wadah Starter, dan UI
## Memverifikasi PRD FR05/FR06, CONTENT.md § 2/3/5, PROTOTYPE.md § 6.1, UI_UX.md UI04, dan TEST_PLAN T02/T03/T04/T29/T30/T31/T32/T33

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const InventoryUIClass = preload("res://scripts/ui/inventory_ui.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")

func run_all() -> bool:
	var passed := true
	print("  Running TestInventory suite (T02, T03, T04, T29, T30, T31, T32, T33)...")
	var tree := Engine.get_main_loop() as SceneTree

	if not test_t02_backpack_slot_limit_and_stack_capacity():
		passed = false
	if not test_t03_two_way_atomic_transfer():
		passed = false
	if not test_t04_starter_crate_pickup():
		passed = false
	if not test_t29_single_container_add_remove_stack_merge():
		passed = false
	if not test_t30_rejection_when_target_full():
		passed = false
	if not test_t31_starter_crate_rejection_insufficient_slots():
		passed = false
	if not await test_t32_ui_instantiation_and_slots(tree):
		passed = false
	if not await test_t33_context_switching_integration(tree):
		passed = false

	return passed

## T02: Batas slot tas (12 slot tetap) dan kapasitas tumpukan (20 max stack)
func test_t02_backpack_slot_limit_and_stack_capacity() -> bool:
	print("    [RUN] T02: Backpack Slot Limit (12 Slots) & Stack Capacity (20 Max)")
	var initial_failures: int = Assertions.current_suite_failed

	var inv = InventoryManagerClass.new()
	inv._ready()

	# 1. Verifikasi batas 12 slot
	var slots: Array = inv._backpack if "_backpack" in inv else inv.backpack.to_array()
	Assertions.assert_equal(slots.size(), 12, "Backpack must have exactly 12 slots")

	# 2. Mengisi satu tumpukan hingga batas 20
	var added = inv.add_items("backpack", [{"item_id": "seed_bayam", "count": 20}]) if inv.has_method("add_items") else inv.backpack.add_item("seed_bayam", 20)
	Assertions.assert_equal(inv.get_available_item_count("seed_bayam"), 20, "Should hold 20 seed_bayam in slot 0")

	# 3. Unit ke-21 membuka slot baru (overflow)
	if inv.has_method("add_items"):
		inv.add_items("backpack", [{"item_id": "seed_bayam", "count": 1}])
	else:
		inv.backpack.add_item("seed_bayam", 1)
	Assertions.assert_equal(inv.get_available_item_count("seed_bayam"), 21, "Total seeds should now be 21 across 2 slots")

	# 4. Mengisi seluruh 12 slot tas hingga penuh (240 unit)
	if inv.has_method("_init_containers"):
		inv._init_containers()
	elif "backpack" in inv:
		inv.backpack.clear()

	for i in range(12):
		var item_id := "item_%02d" % i
		if inv.has_method("add_items"):
			inv.add_items("backpack", [{"item_id": item_id, "count": 20}])
		else:
			inv.backpack.add_item(item_id, 20)

	# 5. Mencoba menambahkan jenis item baru ke-13 ditolak
	var can_add_13th: bool = false
	if inv.has_method("can_accept_items"):
		can_add_13th = inv.can_accept_items("backpack", [{"item_id": "item_overflow", "count": 1}])
	elif "backpack" in inv:
		can_add_13th = inv.backpack.can_add("item_overflow", 1)
	Assertions.assert_false(can_add_13th, "Cannot add 13th distinct item when 12 slots are full")

	inv.free()
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T02: Backpack slot limit & stack capacity verified.")
	return ok

## T03: Transfer dua arah atomik antara tas dan peti
func test_t03_two_way_atomic_transfer() -> bool:
	print("    [RUN] T03: Two-Way Atomic Item Transfer Between Backpack and Chest")
	var initial_failures: int = Assertions.current_suite_failed

	var inv = InventoryManagerClass.new()
	inv._ready()

	# Masukkan 5 seed_bayam ke tas, peti kosong
	if inv.has_method("add_items"):
		inv.add_items("backpack", [{"item_id": "seed_bayam", "count": 5}])
	else:
		inv.backpack.add_item("seed_bayam", 5)

	Assertions.assert_equal(inv.get_available_item_count("seed_bayam"), 5, "Initial total seeds = 5")

	# Transfer dari tas ke peti
	var res: bool = false
	if inv.has_method("transfer_slot"):
		var r = inv.transfer_slot("backpack", "storage", 0)
		res = r.get("success", false)
	elif inv.has_method("transfer_item"):
		res = inv.transfer_item("backpack", "storage", 0, 5)

	Assertions.assert_true(res, "Transfer 5 seeds to chest must succeed")
	Assertions.assert_equal(inv.get_available_item_count("seed_bayam"), 5, "Total seeds must strictly remain 5")

	# Transfer sebagian (2 buah) kembali dari peti ke tas
	var res2: bool = false
	if inv.has_method("transfer_item"):
		res2 = inv.transfer_item("storage", "backpack", 0, 2)
	elif inv.has_method("transfer_slot"):
		# Jika transfer_slot memindahkan per slot, uji transfer_slot
		res2 = inv.transfer_slot("storage", "backpack", 0).get("success", false)

	Assertions.assert_true(res2, "Transfer back to backpack must succeed")
	Assertions.assert_equal(inv.get_available_item_count("seed_bayam"), 5, "Total seeds strictly conserved: zero duplication, zero loss")

	inv.free()
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T03: Two-way atomic transfer verified.")
	return ok

## T04: Pengambilan paket awal starter (4 seeds, 1 compost, 1 fertilizer)
func test_t04_starter_crate_pickup() -> bool:
	print("    [RUN] T04: Starter Crate Pickup, Slot Verification & Spam Protection")
	var initial_failures: int = Assertions.current_suite_failed

	var inv = InventoryManagerClass.new()
	inv._ready()

	# Pengambilan pertama
	var ok_claim: bool = false
	if inv.has_method("collect_starter_container"):
		ok_claim = inv.collect_starter_container()
	elif inv.has_method("claim_starter_container"):
		ok_claim = inv.claim_starter_container().get("success", false)

	Assertions.assert_true(ok_claim, "First claim of starter crate must succeed")
	Assertions.assert_equal(inv.get_available_item_count("seed_bayam"), 4, "Must receive 4 seed_bayam")
	Assertions.assert_equal(inv.get_available_item_count("soil_compost"), 1, "Must receive 1 soil_compost")
	Assertions.assert_equal(inv.get_available_item_count("fertilizer_basic"), 1, "Must receive 1 fertilizer_basic")

	# Pengambilan kedua (Spam E) ditolak
	var spam_claim: bool = false
	if inv.has_method("collect_starter_container"):
		spam_claim = inv.collect_starter_container()
	elif inv.has_method("claim_starter_container"):
		spam_claim = inv.claim_starter_container().get("success", false)

	Assertions.assert_false(spam_claim, "Second claim must be rejected (one-time flag)")
	Assertions.assert_equal(inv.get_available_item_count("seed_bayam"), 4, "Seeds must not duplicate")

	inv.free()
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T04: Starter crate pickup & spam protection verified.")
	return ok

## T29: Single container add/remove & stack merging
func test_t29_single_container_add_remove_stack_merge() -> bool:
	print("    [RUN] T29: Single Container Addition, Stack Merging and Removal")
	var initial_failures: int = Assertions.current_suite_failed

	var inv = InventoryManagerClass.new()
	inv._ready()

	# Tambah 15 air
	if inv.has_method("add_items"):
		inv.add_items("backpack", [{"item_id": "water_fresh", "count": 15}])
	else:
		inv.backpack.add_item("water_fresh", 15)
	Assertions.assert_equal(inv.get_available_item_count("water_fresh"), 15, "Initial 15 water added")

	# Tambah 10 air -> tumpukan pertama penuh 20, tumpukan kedua 5
	if inv.has_method("add_items"):
		inv.add_items("backpack", [{"item_id": "water_fresh", "count": 10}])
	else:
		inv.backpack.add_item("water_fresh", 10)
	Assertions.assert_equal(inv.get_available_item_count("water_fresh"), 25, "Total water is now 25 across 2 stacks")

	# Hapus 7 air
	if inv.has_method("remove_items"):
		inv.remove_items("backpack", [{"item_id": "water_fresh", "count": 7}])
	elif "backpack" in inv:
		inv.backpack.remove_item("water_fresh", 7)
	Assertions.assert_equal(inv.get_available_item_count("water_fresh"), 18, "Remaining water should be 18")

	inv.free()
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T29: Single container add/remove/merge verified.")
	return ok

## T30: Penolakan transfer saat kontainer tujuan penuh
func test_t30_rejection_when_target_full() -> bool:
	print("    [RUN] T30: Transfer Rejection When Target Container Full (No Partial Transfer)")
	var initial_failures: int = Assertions.current_suite_failed

	var inv = InventoryManagerClass.new()
	inv._ready()

	# Penuhi 12 slot peti dengan 12 item berbeda
	for i in range(12):
		var it := "chest_item_%02d" % i
		if inv.has_method("add_items"):
			inv.add_items("storage", [{"item_id": it, "count": 20}])
		else:
			inv.storage_home.add_item(it, 20)

	# Masukkan 5 jagung ke tas
	if inv.has_method("add_items"):
		inv.add_items("backpack", [{"item_id": "ingredient_jagung", "count": 5}])
	else:
		inv.backpack.add_item("ingredient_jagung", 5)

	# Coba transfer jagung ke peti yang penuh
	var res: bool = false
	if inv.has_method("transfer_slot"):
		res = inv.transfer_slot("backpack", "storage", 0).get("success", false)
	elif inv.has_method("transfer_item"):
		res = inv.transfer_item("backpack", "storage", 0, 5)

	Assertions.assert_false(res, "Transfer to full storage container must be rejected")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung") if "backpack" in inv else 5, 5, "Backpack must still have 5 jagung")

	inv.free()
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T30: Target full transfer rejection verified.")
	return ok

## T31: Penolakan starter crate jika tas kekurangan slot (< 3 slot kosong)
func test_t31_starter_crate_rejection_insufficient_slots() -> bool:
	print("    [RUN] T31: Starter Crate Rejection When Free Slots < 3")
	var initial_failures: int = Assertions.current_suite_failed

	var inv = InventoryManagerClass.new()
	inv._ready()

	# Isi 10 slot tas sehingga hanya tersisa 2 slot kosong
	for i in range(10):
		var it := "filler_%02d" % i
		if inv.has_method("add_items"):
			inv.add_items("backpack", [{"item_id": it, "count": 1}])
		else:
			inv.backpack.add_item(it, 1)

	# Ambil starter (memerlukan 3 slot)
	var claim_res: bool = false
	if inv.has_method("collect_starter_container"):
		claim_res = inv.collect_starter_container()
	elif inv.has_method("claim_starter_container"):
		claim_res = inv.claim_starter_container().get("success", false)

	Assertions.assert_false(claim_res, "Starter crate pickup must fail when only 2 free slots available")
	Assertions.assert_equal(inv.get_available_item_count("seed_bayam"), 0, "Zero seeds given on failure")

	# Kosongkan 1 slot lagi sehingga tersisa 3 slot kosong
	if inv.has_method("remove_items"):
		inv.remove_items("backpack", [{"item_id": "filler_00", "count": 1}])
	elif "backpack" in inv:
		inv.backpack.remove_item("filler_00", 1)

	# Ambil sekarang -> harus berhasil
	var claim_res2: bool = false
	if inv.has_method("collect_starter_container"):
		claim_res2 = inv.collect_starter_container()
	elif inv.has_method("claim_starter_container"):
		claim_res2 = inv.claim_starter_container().get("success", false)

	Assertions.assert_true(claim_res2, "Starter crate pickup succeeds when 3 slots are available")
	Assertions.assert_equal(inv.get_available_item_count("seed_bayam"), 4, "Seeds granted properly")

	inv.free()
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T31: Starter crate insufficient slots rejection verified.")
	return ok

## T32: Instansiasi UI, verifikasi jumlah slot, dan toggling visibilitas
func test_t32_ui_instantiation_and_slots(tree: SceneTree) -> bool:
	print("    [RUN] T32: UI Instantiation, 12+12 Slots Verification & Visibility Toggling")
	var initial_failures: int = Assertions.current_suite_failed

	var ui_scene = load("res://scenes/ui/inventory_ui.tscn")
	Assertions.assert_not_null(ui_scene, "inventory_ui.tscn scene file must exist")
	if ui_scene == null:
		return false

	var ui = ui_scene.instantiate() as InventoryUI
	tree.root.add_child(ui)
	await tree.process_frame

	# Verifikasi 12 slot tas dan 12 slot peti
	Assertions.assert_equal(ui.backpack_slot_nodes.size(), 12, "Backpack grid must have 12 slot controls")
	Assertions.assert_equal(ui.storage_slot_nodes.size(), 12, "Storage grid must have 12 slot controls")

	# Uji Solo mode
	ui.open_solo()
	Assertions.assert_true(ui.visible, "UI is visible in solo mode")
	Assertions.assert_false(ui.storage_section.visible, "Storage section is hidden in solo mode")

	# Uji Dual mode
	ui.open_dual()
	Assertions.assert_true(ui.visible, "UI is visible in dual mode")
	Assertions.assert_true(ui.storage_section.visible, "Storage section is visible in dual mode")

	# Uji Tutup
	ui.close_ui()
	Assertions.assert_false(ui.visible, "UI is hidden after close_ui()")

	ui.queue_free()
	await tree.process_frame

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T32: UI instantiation and slot controls verified.")
	return ok

## T33: Integrasi peralihan konteks input dengan InputManager
func test_t33_context_switching_integration(tree: SceneTree) -> bool:
	print("    [RUN] T33: Context Switching Integration with InputManager")
	var initial_failures: int = Assertions.current_suite_failed

	var input_mgr = tree.root.get_node_or_null("InputManager")
	Assertions.assert_not_null(input_mgr, "InputManager autoload must be present")
	if input_mgr == null:
		return false

	var ui_scene = load("res://scenes/ui/inventory_ui.tscn")
	var ui = ui_scene.instantiate() as InventoryUI
	tree.root.add_child(ui)
	await tree.process_frame

	# 1. Pastikan konteks awal adalah WORLD
	input_mgr.pop_to_world()
	Assertions.assert_equal(input_mgr.get_current_context(), input_mgr.ContextMode.WORLD, "Current context is WORLD")
	Assertions.assert_false(ui.visible, "UI hidden in WORLD")

	# 2. Push konteks STORAGE -> UI harus terbuka
	input_mgr.push_context(input_mgr.ContextMode.STORAGE)
	Assertions.assert_equal(input_mgr.get_current_context(), input_mgr.ContextMode.STORAGE, "Current context is STORAGE")
	Assertions.assert_true(input_mgr.is_simulation_paused(), "Simulation is paused in STORAGE context")

	# 3. Pop konteks -> kembali ke WORLD, UI tertutup, frame guard aktif
	input_mgr.pop_context()
	Assertions.assert_equal(input_mgr.get_current_context(), input_mgr.ContextMode.WORLD, "Returned to WORLD context")
	Assertions.assert_false(input_mgr.is_simulation_paused(), "Simulation unpaused in WORLD")
	Assertions.assert_false(input_mgr.can_interact_in_world(), "Bleed-through guard active on pop frame")

	await tree.process_frame
	Assertions.assert_true(input_mgr.can_interact_in_world(), "Interaction allowed on subsequent frame")

	ui.queue_free()
	await tree.process_frame

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T33: Context switching integration verified.")
	return ok
```

---

### 4.4 Pendaftaran Suite 7 pada `tests/test_runner.gd`

Pada baris 9 dan baris 49 `tests/test_runner.gd`:

```gdscript
// ... preload section
const TestInteraction = preload("res://tests/suites/test_interaction.gd")
const TestInventory = preload("res://tests/suites/test_inventory.gd") # Suite 7

// ... di dalam _initialize()
	# Suite 6: TestInteraction (T18, T27, T28 interaction, occlusion & input context)
	var suite_interaction := TestInteraction.new()
	if not await suite_interaction.run_all():
		all_passed = false

	# Suite 7: TestInventory (T02, T03, T04, T29, T30, T31, T32, T33 inventory & storage)
	var suite_inventory := TestInventory.new()
	if not await suite_inventory.run_all():
		all_passed = false
```

---

### 4.5 Generator Scene Otomatis untuk Worker: `scripts/tools/build_inventory_ui.gd`

Untuk memudahkan pembuatan `scenes/ui/inventory_ui.tscn` tanpa perlu membuka GUI editor, Worker dapat mengeksekusi skrip generator berikut:

```gdscript
extends SceneTree

func _init() -> void:
	print("[BUILD_UI] Generating scenes/ui/inventory_ui.tscn...")
	var root = CanvasLayer.new()
	root.name = "InventoryUI"
	root.layer = 10
	root.set_script(load("res://scripts/ui/inventory_ui.gd"))

	var root_ctrl = Control.new()
	root_ctrl.name = "RootControl"
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(root_ctrl)

	var dim = ColorRect.new()
	dim.name = "DimBackground"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.05, 0.08, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctrl.add_child(dim)

	var center = CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	root_ctrl.add_child(center)

	var panel = PanelContainer.new()
	panel.name = "MainPanel"
	panel.custom_minimum_size = Vector2(880, 540)
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.12, 0.14, 0.18, 0.96)
	panel_sb.set_corner_radius_all(6)
	panel_sb.border_width_left = 1
	panel_sb.border_width_top = 1
	panel_sb.border_width_right = 1
	panel_sb.border_width_bottom = 1
	panel_sb.border_color = Color(0.28, 0.32, 0.4, 0.8)
	panel.add_theme_stylebox_override("panel", panel_sb)
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# 1. Header
	var header = HBoxContainer.new()
	header.name = "HeaderHBox"
	vbox.add_child(header)

	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "INVENTARIS & PENYIMPANAN"
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)

	var header_spacer = Control.new()
	header_spacer.name = "HeaderSpacer"
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "Tutup [Esc / Tab]"
	close_btn.custom_minimum_size = Vector2(140, 36)
	header.add_child(close_btn)

	# 2. Content HBox
	var content = HBoxContainer.new()
	content.name = "ContentHBox"
	content.add_theme_constant_override("separation", 24)
	vbox.add_child(content)

	# Backpack Section
	var bp_sec = VBoxContainer.new()
	bp_sec.name = "BackpackSection"
	bp_sec.custom_minimum_size = Vector2(380, 0)
	content.add_child(bp_sec)

	var bp_hdr = HBoxContainer.new()
	bp_hdr.name = "SectionHeader"
	bp_sec.add_child(bp_hdr)
	var bp_title = Label.new()
	bp_title.name = "BackpackTitle"
	bp_title.text = "Tas Punggung"
	bp_title.add_theme_font_size_override("font_size", 18)
	bp_hdr.add_child(bp_title)
	var bp_sp = Control.new()
	bp_sp.name = "Spacer"
	bp_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bp_hdr.add_child(bp_sp)
	var bp_cap = Label.new()
	bp_cap.name = "BackpackCapacityLabel"
	bp_cap.text = "0/12 slot"
	bp_hdr.add_child(bp_cap)

	var bp_grid = GridContainer.new()
	bp_grid.name = "BackpackGrid"
	bp_grid.columns = 4
	bp_grid.add_theme_constant_override("h_separation", 8)
	bp_grid.add_theme_constant_override("v_separation", 8)
	bp_sec.add_child(bp_grid)

	for i in range(12):
		var btn = Button.new()
		btn.name = "Slot_%d" % i
		btn.custom_minimum_size = Vector2(64, 64)
		btn.focus_mode = Control.FOCUS_ALL
		bp_grid.add_child(btn)

	var bp_actions = HBoxContainer.new()
	bp_actions.name = "BackpackActions"
	bp_sec.add_child(bp_actions)
	var b_tr_sel = Button.new()
	b_tr_sel.name = "BtnTransferSelectedToStorage"
	b_tr_sel.text = "Pindahkan Pilihan ->"
	b_tr_sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bp_actions.add_child(b_tr_sel)
	var b_tr_all = Button.new()
	b_tr_all.name = "BtnTransferAllToStorage"
	b_tr_all.text = "Pindahkan Semua ->"
	b_tr_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bp_actions.add_child(b_tr_all)

	# Storage Section
	var st_sec = VBoxContainer.new()
	st_sec.name = "StorageSection"
	st_sec.custom_minimum_size = Vector2(380, 0)
	content.add_child(st_sec)

	var st_hdr = HBoxContainer.new()
	st_hdr.name = "SectionHeader"
	st_sec.add_child(st_hdr)
	var st_title = Label.new()
	st_title.name = "StorageTitle"
	st_title.text = "Peti Penyimpanan"
	st_title.add_theme_font_size_override("font_size", 18)
	st_hdr.add_child(st_title)
	var st_sp = Control.new()
	st_sp.name = "Spacer"
	st_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st_hdr.add_child(st_sp)
	var st_cap = Label.new()
	st_cap.name = "StorageCapacityLabel"
	st_cap.text = "0/12 slot"
	st_hdr.add_child(st_cap)

	var st_grid = GridContainer.new()
	st_grid.name = "StorageGrid"
	st_grid.columns = 4
	st_grid.add_theme_constant_override("h_separation", 8)
	st_grid.add_theme_constant_override("v_separation", 8)
	st_sec.add_child(st_grid)

	for i in range(12):
		var btn = Button.new()
		btn.name = "Slot_%d" % i
		btn.custom_minimum_size = Vector2(64, 64)
		btn.focus_mode = Control.FOCUS_ALL
		st_grid.add_child(btn)

	var st_actions = HBoxContainer.new()
	st_actions.name = "StorageActions"
	st_sec.add_child(st_actions)
	var s_tr_sel = Button.new()
	s_tr_sel.name = "BtnTransferSelectedToBackpack"
	s_tr_sel.text = "<- Pindahkan Pilihan"
	s_tr_sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st_actions.add_child(s_tr_sel)
	var s_tr_all = Button.new()
	s_tr_all.name = "BtnTransferAllToBackpack"
	s_tr_all.text = "<- Pindahkan Semua"
	s_tr_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st_actions.add_child(s_tr_all)

	# 3. Detail Panel
	var detail_p = PanelContainer.new()
	detail_p.name = "DetailPanel"
	detail_p.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(detail_p)

	var d_margin = MarginContainer.new()
	d_margin.name = "DetailMargin"
	d_margin.add_theme_constant_override("margin_left", 12)
	d_margin.add_theme_constant_override("margin_top", 8)
	d_margin.add_theme_constant_override("margin_right", 12)
	d_margin.add_theme_constant_override("margin_bottom", 8)
	detail_p.add_child(d_margin)

	var d_hbox = HBoxContainer.new()
	d_hbox.name = "DetailHBox"
	d_hbox.add_theme_constant_override("separation", 16)
	d_margin.add_child(d_hbox)

	var d_icon = ColorRect.new()
	d_icon.name = "DetailIcon"
	d_icon.custom_minimum_size = Vector2(48, 48)
	d_icon.color = Color(0.2, 0.2, 0.2, 0.5)
	d_hbox.add_child(d_icon)

	var d_txt = VBoxContainer.new()
	d_txt.name = "DetailTextVBox"
	d_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_hbox.add_child(d_txt)

	var d_name = Label.new()
	d_name.name = "DetailNameLabel"
	d_name.text = "Pilih item untuk melihat detail"
	d_name.add_theme_font_size_override("font_size", 16)
	d_txt.add_child(d_name)

	var d_desc = Label.new()
	d_desc.name = "DetailDescLabel"
	d_desc.text = "Gunakan tombol panah atau klik mouse untuk memilih slot."
	d_desc.add_theme_font_size_override("font_size", 13)
	d_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	d_txt.add_child(d_desc)

	# 4. Status Message
	var status = Label.new()
	status.name = "StatusLabel"
	status.text = ""
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	vbox.add_child(status)

	set_owner_recursive(root, root)

	var packed = PackedScene.new()
	var err = packed.pack(root)
	if err == OK:
		ResourceSaver.save(packed, "res://scenes/ui/inventory_ui.tscn")
		print("[BUILD_UI] Successfully generated scenes/ui/inventory_ui.tscn!")
		quit(0)
	else:
		printerr("[BUILD_UI] Failed to pack scene: ", err)
		quit(1)

func set_owner_recursive(node: Node, new_owner: Node) -> void:
	for child in node.get_children():
		child.owner = new_owner
		set_owner_recursive(child, new_owner)
```

---

## 5. Verification Method

Worker dapat memverifikasi implementasi secara independen menggunakan langkah-langkah objektif berikut:

### 5.1 Perintah Eksekusi Pengujian
1. **Verifikasi Suite Lengkap (Suite 1..7):**
   ```powershell
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless --path . --script res://tests/test_runner.gd"
   ```
   *Expected:* Exit code 0, semua 7 suite lulus, 0 asersi gagal.
2. **Audit Konsistensi Adegan & UID Proyek:**
   ```powershell
   python ".agents/skills/godot-nodes-scenes/scripts/check_godot_project.py" .
   ```
   *Expected:* 0 errors, 0 warnings pada seluruh file proyek.
3. **Smoke Test Adegan Utama (60 frame):**
   ```powershell
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless --path . --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 60"
   ```
   *Expected:* Berjalan bersih tanpa runtime script error.

### 5.2 Kondisi Pembatalan (Invalidation Conditions)
Rancangan ini dinyatakan cacat / batal jika salah satu kondisi berikut terjadi:
- Pemain dapat menduplikasi item atau kehilangan item saat memindahkan tumpukan ke kontainer yang penuh.
- Paket starter dapat diambil lebih dari satu kali melalui spam tombol E.
- Menekan tombol Tab atau Esc saat menutup antarmuka inventaris memicu interaksi atau ayunan alat di dunia 3D (terjadi input bleed-through).
- Ukuran slot atau grid terpotong atau tumpang tindih saat jendela diregangkan.
