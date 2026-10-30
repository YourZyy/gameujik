# Laporan Analisis Teknis Antarmuka Dapur dan Aksi Makan Hidangan (COOK-002)

**Explorer ID:** `explorer_cook_002_2`  
**Milestone:** `COOK-002` (Kontrol Panas, Timer 30s, Jeda Panel, Output Hidangan, dan Aksi Makan)  
**Dokumen Acuan:** `PRD.md` (FR12, FR13), `docs/CONTENT.md` (§ 2, § 3, § 4, § 10, § 11, § 12), `docs/UI_UX.md` (§ 1, § 2, § 3, § 4, UI01, UI04, UI05), `docs/TEST_PLAN.md` (T12, T15, T19, T41, T42, T43), `AGENTS.md`.  
**Tanggal:** 28 Oktober 2026.

---

## 1. Ringkasan Eksekutif

Eksplorasi ini berfokus pada dua pilar interaksi pemain untuk milestone `COOK-002`:
1. **Antarmuka Dapur (`kitchen_ui.gd` & `kitchen_ui.tscn`)**:
   - Menambahkan kontrol pemilihan 3 tingkat panas (**Rendah** 0.5x, **Sedang** 1.0x [Optimal], **Tinggi** 0.0x [Tertahan]), dengan default awal seleksi pada **Rendah** per `CONTENT.md § 4`.
   - Menambahkan indikator peringatan visual saat **Tinggi** (*heat stall warning*): *"⚠️ Panas terlalu tinggi! Proses memasak tertahan. Kecilkan panas ke Sedang."* tanpa merusak/menghanguskan bahan.
   - Menampilkan meteran kemajuan memasak (*progress bar* & timer durasi 30.0 detik nominal).
   - Penanganan status jeda (*pause*) saat panel dapur ditutup (Esc / tombol Tutup), transisi ke `JobState.PAUSED`, sinkronisasi HUD tracker *"Masakan dijeda"*, serta tombol *"Lanjutkan Memasak"* saat dibuka kembali.
   - Penampilan slot output masakan tunggal dan tombol *"Ambil Masakan [Ke Tas]"*, dengan penolakan aman jika tas penuh tanpa menghilangkan atau menduplikasi hidangan (Uji T15).
2. **Aksi Makan Hidangan (`action_eat`)**:
   - Pemain mengonsumsi hidangan `dish_sayur_bening` langsung dari Tas (`InventoryUI`) melalui tombol *"Makan [1 Porsi]"* dengan konfirmasi jelas per `UI_UX.md UI04`.
   - Pengurangan item dilakukan secara atomik (tepat 1 unit berkurang dari tumpukan/slot di tas).
   - Penetapan bendera `meal_used = true` pada entitas World (`WorldResourceManager` per `CONTENT.md § 12`) yang persisten dalam snapshot save.
   - Umpan balik jujur (*honest feedback notification*): *"Hangat. Resep pertama berhasil dibuat."* tanpa bar lapar (*hunger bar*), tanpa poin pengalaman/buff fiktif per prinsip PRD.

---

## 2. Analisis Teknis Antarmuka Dapur (`KitchenUI`)

### 2.1. Hirarki Adegan (`kitchen_ui.tscn`)
Struktur adegan saat ini di `scenes/ui/kitchen_ui.tscn` baru memiliki `IngredientsSection`, `PreparationSection` (tahan 4s), `ReadySection` (tombol Mulai Memasak), dan `RefundSection`.

Untuk memenuhi `COOK-002`, adegan perlu dilengkapi dengan dua seksi baru di bawah `ReadySection`:
1. **`CookingSection` (VBoxContainer, default `visible = false`)**:
   - `CookingTitleLabel`: Label font size 16pt, teks: `"Tahap 2: Memasak di Atas Tungku"`
   - `CookingStatusLabel`: Label status dinamis (`"Sedang Memasak"`, `"Dijeda"`, `"Tertahan"`).
   - `CookingProgressBar`: ProgressBar, `custom_minimum_size = Vector2(0, 24)`, `max_value = 30.0`, `show_percentage = false`.
   - `CookingTimeLabel`: Label, teks: `"Progres Memasak: 0.0s / 30.0s (Sedang — 1.0x)"`.
   - `HeatControlHBox`: HBoxContainer (separation 12px):
     - `HeatTitleLabel`: Label `"Tingkat Panas:"`
     - `HeatLowButton`: Button `"Rendah (0.5x)"`
     - `HeatMedButton`: Button `"Sedang (1.0x) [Optimal]"`
     - `HeatHighButton`: Button `"Tinggi (0.0x) [Tertahan]"`
   - `HeatWarningPanel`: PanelContainer dengan style alert amber/orange:
     - `HeatWarningLabel`: `"⚠️ Panas terlalu tinggi! Proses memasak tertahan. Kecilkan panas ke Sedang."`
   - `PausedPanel`: PanelContainer (visible saat state `PAUSED`):
     - `PausedLabel`: `"Masakan dijeda saat pintu dapur ditutup."`
     - `ResumeCookingButton`: Button `"Lanjutkan Memasak"`
2. **`OutputSection` (VBoxContainer, default `visible = false`)**:
   - `OutputTitleLabel`: Label `"Tahap 3: Hidangan Siap Diambil"`
   - `OutputDishPanel`: PanelContainer inset:
     - `DishNameLabel`: `"Sayur Bening Bayam dan Jagung"`
     - `DishCountLabel`: `"1 porsi siap disajikan"`
     - `DishDescLabel`: `"Sayur bening hangat dengan daun bayam segar, pipilan jagung manis, dan aroma temu kunci."`
   - `TakeDishButton`: Button `"Ambil Masakan [Ke Tas]"`

### 2.2. Kontrol Pemilihan Panas (Rendah, Sedang, Tinggi)
- **Aturan CONTENT.md § 4**:
  - `Panas Rendah`: Kecepatan progres $\times 0.5$ (butuh 60s jika terus Rendah).
  - `Panas Sedang`: Kecepatan progres $\times 1.0$ (optimal, 30s nominal).
  - `Panas Tinggi`: Kecepatan progres $\times 0.0$ (tertahan, 0s kemajuan per detik).
  - **Pilihan Panas Awal:** Dimulai dari **Rendah**, agar pemain membaca petunjuk dan secara sadar memilih panas Sedang.
- **Implementasi Visual di UI**:
  - Tiga tombol horizontal (`HeatLowButton`, `HeatMedButton`, `HeatHighButton`).
  - Tombol yang sedang aktif diberi visual feedback tegas (misal text prefix `[Aktif]` atau warna highlight tombol), sehingga pemain tidak perlu menebak level panas aktif.
  - Sesuai prinsip aksesibilitas `UI_UX.md § 2`: Tidak hanya mengandalkan warna hijau/merah, tetapi teks menyebut nama dan pengali laju secara eksplisit.

### 2.3. Indikator Visual Peringatan Heat Stall (Tinggi)
- Ketika level panas diatur ke `Tinggi`:
  - `HeatWarningPanel` otomatis menjadi `visible = true`.
  - Teks pesan: `"⚠️ Panas terlalu tinggi! Proses memasak tertahan. Kecilkan panas ke Sedang."`
  - Timer kemajuan berhenti bertambah (`delta * 0.0`).
  - Bahan makanan **TIDAK hangus atau hilang** (Invarian PRD FR12: no burn / matter destruction).
  - Jika pemain menekan tombol `Sedang`, peringatan langsung tertutup (`visible = false`) dan proses memasak kembali melaju pada $1.0\times$.

### 2.4. Meteran Kemajuan & Timer (30.0s Nominal)
- `CookingProgressBar`:
  - `max_value = 30.0`.
  - `value` diperbarui setiap frame dari `km.cook_progress`.
- `CookingTimeLabel`:
  - Format teks: `"Progres Memasak: %.1fs / 30.0s (%s — %.1fx)" % [km.cook_progress, heat_name, heat_multiplier]`.
  - Saat dijeda: `"Progres Memasak: %.1fs / 30.0s (DIJEDA)"`.
  - Saat stall: `"Progres Memasak: %.1fs / 30.0s (TERTAHAN)"`.

### 2.5. Penanganan Jeda saat Panel Ditutup / Dibuka (Pause Handling)
- **Skenario Penutupan Panel saat Sedang Memasak (`COOKING`)**:
  1. Pemain menekan `Esc` atau tombol `CloseButton`.
  2. `kitchen_ui.close()` mendeteksi bahwa status adalah `COOKING`.
  3. `KitchenUI` memanggil `km.pause_cooking()`.
  4. `km.job_state` beralih ke `JobState.PAUSED`.
  5. `RecipeManager.set_cooking_state("paused")` dipanggil.
  6. Di HUD eksplorasi (`hud.gd`), tracker atas langsung menampilkan: `"Masakan dijeda"` (modulate oranye/amber).
  7. Di dunia 3D, prompt interaksi pada stasiun dapur menampilkan: `"[E] Lanjutkan Dapur"`.
  8. Waktu memasak berhenti bertambah di latar belakang (tidak ada auto-cooking di luar layar per `TEST_PLAN.md T42`).
- **Skenario Pembukaan Kembali saat Dijeda (`PAUSED`)**:
  1. Pemain menekan `E` di stasiun dapur.
  2. `KitchenUI.open()` dibuka kembali.
  3. UI mendeteksi `km.job_state == JobState.PAUSED`.
  4. Seksi `CookingSection` langsung ditampilkan dengan nilai progres yang utuh (misal `14.2s / 30.0s`).
  5. Ditampilkan `PausedPanel` dan tombol `ResumeCookingButton` (*"Lanjutkan Memasak"*).
  6. Ketika tombol ditekan, `km.resume_cooking()` dipanggil, status beralih kembali ke `COOKING`, dan timer melanjutkan dari detik 14.2.

### 2.6. Slot Output Masakan & Tombol "Ambil Masakan"
- **Penyelesaian Memasak (Progres $\ge 30.0$s)**:
  - `km.job_state` beralih ke `JobState.OUTPUT_READY`.
  - Slot output `dish_output_slot` terisi 1 unit `dish_sayur_bening`.
  - `RecipeManager.record_recipe_cooked("recipe_sayur_bening_01")` dipanggil:
    - Counter `times_cooked` bertambah $+1$.
    - Resep ditandai selesai (`is_recipe_completed = true`).
  - `RecipeManager.set_cooking_state("output_ready")`.
- **Interaksi Pengambilan Hidangan (`TakeDishButton`)**:
  - Pemain menekan tombol *"Ambil Masakan [Ke Tas]"*.
  - `KitchenUI` memeriksa kapasitas tas: `inv.backpack.can_add("dish_sayur_bening", 1)`.
  - **Kasus 1: Tas Memiliki Ruang Kosong**:
    - `inv.backpack.add_item("dish_sayur_bening", 1)`.
    - `km.take_dish_output()` mengosongkan slot hasil dan mengembalikan stasiun ke status `IDLE`.
    - `inv.inventory_updated.emit()`.
    - Notifikasi feedback: `"Berhasil mengambil 1 Sayur Bening Bayam dan Jagung ke tas."`
    - UI beralih kembali ke tampilan `IDLE` (siap jika ingin memasak ulang).
  - **Kasus 2: Tas Penuh (Uji T15)**:
    - Transaksi ditolak secara bersih.
    - Hidangan tetap berada di dalam `dish_output_slot`.
    - Status tetap `OUTPUT_READY`.
    - Tidak ada hidangan yang hilang atau tercecer.
    - Notifikasi feedback jujur per `CONTENT.md § 11`: `"Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."`

---

## 3. Analisis Teknis Aksi Makan Hidangan (`action_eat`)

### 3.1. Alur Penggunaan dari Tas (`InventoryUI`)
Per `UI_UX.md UI04`:
> *"Hidangan di tas memiliki tombol Makan dengan konfirmasi 'Makan 1 porsi?'. Benih tidak memiliki tombol Gunakan yang memunculkan aksi tanpa target; pengguna diarahkan memilih alat benih di dunia. Alat tetap tidak muncul sebagai item buang."*

1. **Titik Pemicu**:
   - Pemain membuka tas dengan tombol `Tab` (atau tombol interaksi peti `storage_home`).
   - Pemain memilih slot tas yang berisi `dish_sayur_bening`.
   - `InventoryUI._update_detail_panel()` memeriksa apakah item terpilih adalah hidangan:
     ```gdscript
     var is_dish: bool = (selected_container == "backpack" and item_id == "dish_sayur_bening" and count > 0)
     btn_eat_dish.visible = is_dish
     ```
2. **Mekanisme Konfirmasi**:
   - Menghindari kecelakaan konsumsi yang tidak disengaja.
   - Pilihan implementasi terbaik: **Inline Confirmation Button** pada DetailPanel:
     - Klik 1: Tombol berubah menjadi `"Makan 1 porsi? [Klik Konfirmasi]"` dengan modulate highlight.
     - Klik 2: Mengeksekusi konsumsi hidangan.
     - Jika pemain berpindah slot atau menekan `Esc`, status konfirmasi kembali ke normal `"Makan [1 Porsi]"`.
   - Pola ini tidak memblokir antarmuka dengan modal dialog bertumpuk dan sangat nyaman untuk navigasi keyboard maupun mouse.

### 3.2. Pengurangan Item Atomik
- Fungsi eksekusi konsumsi dapat ditempatkan di `InventoryManager`:
  ```gdscript
  func eat_dish(container_name: String = "backpack") -> Dictionary:
      var c := get_container(container_name)
      if c == null:
          return {"success": false, "reason": "Kontainer tidak ditemukan."}
      
      if c.get_item_count("dish_sayur_bening") <= 0:
          return {"success": false, "reason": "Tidak ada hidangan untuk dimakan."}
      
      var removed: int = c.remove_item("dish_sayur_bening", 1)
      if removed <= 0:
          return {"success": false, "reason": "Gagal mengonsumsi hidangan."}
      
      # Tetapkan bendera meal_used pada WorldResourceManager
      var wrm = _get_world_resource_manager()
      if wrm != null and wrm.has_method("set_meal_used"):
          wrm.set_meal_used(true)
      elif wrm != null and "meal_used" in wrm:
          wrm.meal_used = true
      
      inventory_updated.emit()
      return {
          "success": true,
          "reason": "Hangat. Resep pertama berhasil dibuat.",
          "item_id": "dish_sayur_bening",
          "count": 1
      }
  ```
- **Invarian Hukum Kekekalan Materi**:
  - Unit `dish_sayur_bening` di tas berkurang tepat 1 unit.
  - Jika tumpukan berjumlah 1, slot tas menjadi kosong (`-`) dan kapasitas terpakai berkurang 1 slot.
  - Jika tumpukan berjumlah $>1$, slot tetap terisi dengan sisa unit yang tepat.

### 3.3. Penetapan Bendera `meal_used = true`
- **Lokasi State**:
  - `CONTENT.md § 12` mendefinisikan entitas `World` sebagai pemilik resmi field:
    `Indeks hari, waktu aktif, wadah awal diambil, flag catatan, flag dialog, meal_used`.
  - Di arsitektur Godot saat ini, `WorldResourceManager` (`scripts/world/world_resource_manager.gd`) adalah Autoload singleton pengelola entitas World.
  - Tambahkan properti di `WorldResourceManager`:
    ```gdscript
    var meal_used: bool = false
    signal meal_consumed(item_id: String, count: int)
    
    func set_meal_used(val: bool) -> void:
        meal_used = val
        if val:
            meal_consumed.emit("dish_sayur_bening", 1)
    
    func is_meal_used() -> bool:
        return meal_used
    ```
  - Masukkan `meal_used` ke dalam serialisasi snapshot (`get_save_snapshot()` / `load_save_snapshot()`) agar tidak hilang saat reload game.

### 3.4. Umpan Balik Jujur (*Honest Feedback*) Tanpa Bar Lapar
- **Aturan PRD & CONTENT**:
  - DILARANG menambah panel statistik, hunger bar, meteran kenyang, stamina meter, buff attack/defense, atau mata uang.
  - Pesan teks jujur per `CONTENT.md § 10`:
    `"Hangat. Resep pertama berhasil dibuat."`
- **Penyampaian di UI**:
  - Di `InventoryUI`: Label status di bawah menampilkan teks tersebut selama panel tas terbuka.
  - Di HUD Eksplorasi: Memanggil `HUD.show_feedback("Hangat. Resep pertama berhasil dibuat.", 3.0)` sehingga saat tas ditutup, pemain langsung melihat pesan hangat tersebut di tengah layar bawah sebelum memudar secara halus setelah 3 detik.

---

## 4. Pencegahan Masalah Interaksi (*Bleed-Through*) & Aksesibilitas UI

1. **Isolasi Konteks Input (`InputManager`)**:
   - Selama `KitchenUI` atau `InventoryUI` terbuka, konteks berada pada `ContextMode.KITCHEN` atau `ContextMode.STORAGE`.
   - Kursor mouse berada dalam mode `MOUSE_MODE_VISIBLE`.
   - Rotasi kamera pemain, pergerakan WASD, dan klik alat dunia dinonaktifkan secara penuh.
   - Penutupan panel via `Esc` atau tombol `Tutup` memanggil `InputManager.consume_and_close()`, mencegah aksi `Esc` membuka menu Pause secara bersamaan.
2. **Navigasi Keyboard / Gamepad (Fokus)**:
   - Sesuai skill `game-ui-ux` dan `godot-ui-control`:
   - Saat `KitchenUI` terbuka pada status `COOKING`, fokus otomatis diarahkan ke `HeatMedButton` atau `ResumeCookingButton` (jika paused).
   - Saat terbuka pada status `OUTPUT_READY`, fokus otomatis diarahkan ke `TakeDishButton`.
   - Di `InventoryUI`, tombol `BtnEatDish` memiliki `focus_mode = FOCUS_ALL`, dan dapat diakses menggunakan navigasi tombol panah/Enter.

---

## 5. Pemetaan Kasus Uji Penerimaan (*Test Matrix*)

| ID Uji | Kondisi Pengujian | Perilaku UI & Interaksi yang Diharapkan |
|---|---|---|
| **T12** | Klik "Mulai Memasak" berulang kali | Idempotent, tidak memicu double cook timer, tidak menggandakan reservasi bahan. |
| **T15** | Memasak selesai saat tas pemain penuh (12/12) | Hidangan tetap aman di `dish_output_slot`, status tetap `OUTPUT_READY`, tombol "Ambil Masakan" memberi pesan `"Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."`, nol kehilangan barang. |
| **T19** | Memasak resep yang sudah pernah selesai | Progres memasak berjalan normal, saat selesai `times_cooked` bertambah menjadi 2, centang resep di buku/HUD tetap terpasang tanpa reset. |
| **T41** | Uji 3 level panas (Rendah, Sedang, Tinggi) | Rendah melaju $0.5\times$, Sedang melaju $1.0\times$ (30s), Tinggi melaju $0.0\times$ dengan panel peringatan stall aktif tanpa merusak bahan. |
| **T42** | Tutup panel dapur saat memasak, tunggu, buka lagi | Timer berhenti saat panel ditutup, tracker HUD menampilkan `"Masakan dijeda"`, saat dibuka kembali progres tetap pada detik terakhir dan dapat dilanjutkan via tombol "Lanjutkan Memasak". |
| **T43** | Konsumsi hidangan dari tas (`action_eat`) | 1 unit `dish_sayur_bening` berkurang atomik dari tas, `meal_used` menjadi `true`, pesan `"Hangat. Resep pertama berhasil dibuat."` muncul tanpa hunger bar. |

---

## 6. Rekomendasi Kode untuk Worker Implementasi

### A. Rencana Perubahan `kitchen_ui.gd`
```gdscript
# Tambahan node references
@onready var cooking_section: VBoxContainer = find_child("CookingSection", true, false)
@onready var cooking_progress_bar: ProgressBar = find_child("CookingProgressBar", true, false)
@onready var cooking_time_label: Label = find_child("CookingTimeLabel", true, false)
@onready var heat_low_button: Button = find_child("HeatLowButton", true, false)
@onready var heat_med_button: Button = find_child("HeatMedButton", true, false)
@onready var heat_high_button: Button = find_child("HeatHighButton", true, false)
@onready var heat_warning_panel: PanelContainer = find_child("HeatWarningPanel", true, false)
@onready var paused_panel: PanelContainer = find_child("PausedPanel", true, false)
@onready var resume_cooking_button: Button = find_child("ResumeCookingButton", true, false)
@onready var output_section: VBoxContainer = find_child("OutputSection", true, false)
@onready var take_dish_button: Button = find_child("TakeDishButton", true, false)

func close() -> void:
    var km := _get_kitchen_manager()
    if km != null and km.job_state == km.JobState.COOKING:
        km.pause_cooking()
    visible = false
    _is_holding = false
    var im := _get_input_manager()
    if im != null and im.get_current_context() == im.ContextMode.KITCHEN:
        im.consume_and_close(&"pause_menu")

func _on_take_dish_pressed() -> void:
    var km := _get_kitchen_manager()
    var inv := _get_inventory_manager()
    if km == null or inv == null: return
    
    if not inv.backpack.can_add("dish_sayur_bening", 1):
        set_feedback("Tas tidak cukup. Kosongkan slot atau simpan barang di rumah.")
        return
    
    var dish = km.take_dish_output()
    if not dish.is_empty():
        inv.backpack.add_item("dish_sayur_bening", int(dish.get("count", 1)))
        inv.inventory_updated.emit()
        set_feedback("Berhasil mengambil 1 Sayur Bening Bayam dan Jagung ke tas.")
        refresh_ui()
```

### B. Rencana Perubahan `inventory_ui.gd`
```gdscript
# Tambahan node reference di DetailPanel
@onready var btn_eat_dish: Button = find_child("BtnEatDish", true, false)

func _ready() -> void:
    ...
    if btn_eat_dish != null:
        btn_eat_dish.pressed.connect(_on_eat_dish_pressed)

func _update_detail_panel() -> void:
    ...
    # Tampilkan tombol makan hanya jika hidangan sayur bening di tas terpilih
    if btn_eat_dish != null:
        var is_dish: bool = (selected_container == "backpack" and item_id == "dish_sayur_bening" and count > 0)
        btn_eat_dish.visible = is_dish
        if not is_dish:
            _confirming_eat = false
            btn_eat_dish.text = "Makan [1 Porsi]"

func _on_eat_dish_pressed() -> void:
    if not _confirming_eat:
        _confirming_eat = true
        btn_eat_dish.text = "Makan 1 porsi? [Konfirmasi]"
        return
    
    _confirming_eat = false
    btn_eat_dish.text = "Makan [1 Porsi]"
    
    var inv := _get_inventory_manager()
    if inv == null: return
    
    var res: Dictionary = inv.eat_dish("backpack")
    if res.get("success", false):
        _show_status(res.get("reason", "Hangat. Resep pertama berhasil dibuat."))
        # Kirim notifikasi ke HUD
        var tree := get_tree()
        if tree != null and tree.root != null:
            var hud = tree.root.find_child("HUD", true, false)
            if hud != null and hud.has_method("show_feedback"):
                hud.show_feedback(res.get("reason", ""), 3.0)
    else:
        _show_status(res.get("reason", "Gagal memakan hidangan."))
    refresh_ui()
```

---
*Laporan ini siap dijadikan cetak biru implementasi oleh Tim Worker COOK-002.*
