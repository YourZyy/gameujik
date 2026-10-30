# Handoff Report: Investigasi Arsitektur InventoryManager, Transaksi Atomik, dan Paket Awal (INV-001)

Dokumen ini adalah laporan investigasi arsitektur dan rancangan teknis untuk implementasi task **INV-001** (Data item, inventaris tas & peti, transfer dua arah, dan paket awal) sesuai aturan kerja `AGENTS.md` § 6 & § 8, `CONTENT.md` § 2, 3, 5, `PROTOTYPE.md` § 6.1, serta kasus uji `TEST_PLAN.md` T02, T03, T04, T05, T29, T30, dan T31.

---

## 1. Observation

Berdasarkan pembacaan kode sumber proyek, dokumen spesifikasi, dan test harness yang ada:

1. **Konfigurasi Autoload Saat Ini (`project.godot`):**
   - Pada baris 14–17 `project.godot`:
     ```ini
     [autoload]
     InputManager="*res://scripts/core/input_manager.gd"
     ```
     Saat ini baru terdapat satu autoload singleton (`InputManager`).
   - Pada `orchestrator_gen4/PROJECT.md` baris 8 dan baris 138:
     `InventoryManager` secara eksplisit dirancang sebagai Autoload singleton di `res://scripts/inventory/inventory_manager.gd`:
     > "InventoryManager (res://scripts/inventory/inventory_manager.gd): Item registry, backpack (12 slots, stack max 20), storage chest (12 slots), atomic multi-item transfer."

2. **Kamus Item dan Batasan Kapasitas (`docs/CONTENT.md` § 2 & § 3):**
   - Terdapat **tepat 7 item P0** dengan batasan tumpukan maksimum **20 unit per slot** (tidak ada berat, durability, atau kualitas):
     1. `seed_bayam`: Benih bayam (Benih, 1 per titik tanam)
     2. `soil_compost`: Pembenah tanah (Perawatan, 1 untuk petak)
     3. `fertilizer_basic`: Pupuk (Perawatan, 1 untuk petak saat nutrisi < 20)
     4. `ingredient_bayam`: Bayam (Bahan resep, 3 per masakan)
     5. `ingredient_jagung`: Jagung (Bahan resep, 1 per masakan)
     6. `ingredient_temu_kunci`: Temu kunci (Bahan resep, 1 per masakan)
     7. `dish_sayur_bening`: Sayur Bening Bayam dan Jagung (Hidangan, 1 untuk dimakan/dibagikan)
   - Batasan slot:
     - **Tas (Backpack):** 12 slot tetap (indeks 0..11).
     - **Penyimpanan Rumah (Peti / Storage):** 12 slot tetap (indeks 0..11).
     - **Alat:** 4 akses tetap (`tool_hoe`, `tool_seed`, `tool_fertilizer`, `tool_watering_can`), **di luar slot tas** (tidak memakan slot inventaris).
     - **Kondisi awal game baru:** Tas kosong (12 slot kosong), Peti kosong (12 slot kosong).

3. **Aturan Transaksi Atomik dan Larangan Transfer Parsial (`AGENTS.md` § 8 & `CONTENT.md` § 3):**
   - `AGENTS.md` § 8:
     > "Transaksi item harus utuh: kapasitas dan prasyarat diperiksa dulu, lalu sumber/tujuan berubah bersama. Klik berulang, muat ulang dan perbedaan frame rate tidak boleh menggandakan hasil."
   - `CONTENT.md` § 3:
     > "Pickup dan panen memeriksa kapasitas **seluruh hasil** terlebih dahulu. Panen bayam menghasilkan dua jenis item, sehingga satu slot kosong belum tentu cukup. Jika tidak muat, sumber/tanaman tetap utuh. Transfer pilihan memindahkan seluruh tumpukan terpilih; transfer semua memindahkan seluruh isi hanya jika tujuan dapat menampungnya. Bila tidak muat, tidak ada perubahan dan UI memberi alasan. **Tidak ada transfer parsial diam-diam pada P0.**"
   - `PROTOTYPE.md` § 6.1:
     > "Periksa target, keadaan, jangkauan, sumber daya dan seluruh kapasitas. Jika satu prasyarat gagal, tidak ada mutasi. Jika lolos, mutasi dilakukan sebagai satu transaksi; baru setelahnya UI dan audio diperbarui. Sumber dengan ID yang sama tidak bisa dipanen dua kali oleh dua input pada frame berdekatan."

4. **Spesifikasi Paket Wadah Awal (`container_starter`):**
   - `CONTENT.md` § 5:
     > `container_starter`: Pekarangan dekat alat | Benih 4, pembenah 1, pupuk 1 | E mengambil paket sekaligus jika seluruhnya muat; sekali per game
   - Landmark di level graybox:
     Node3D `container_starter` pada posisi `(6, 0, 4)` dengan komponen `Interactable` Area3D (`interaction_id = "landmark_starter"`, `prompt_action = "Ambil"`, `target_name = "Wadah Starter"`).
   - Kasus uji T04 (`TEST_PLAN.md`):
     > "Spam E pada paket awal/sumber yang sama -> Hasil diberikan sekali; sumber berubah sekali; tidak ada duplikasi"

5. **Konteks Input dan Tampilan UI Terkait:**
   - `InputManager` (`scripts/core/input_manager.gd`) telah mengimplementasikan mode `ContextMode.STORAGE`.
   - Menekan tombol Tab (`open_inventory`) memicu transisi ke `ContextMode.STORAGE` dan membebaskan mouse (`MOUSE_MODE_VISIBLE`).
   - Landmark `storage_home` pada level graybox memiliki interactable `landmark_storage` ("Buka Peti").

---

## 2. Logic Chain

Dari observasi di atas, alur penalaran arsitektur dan algoritma dirumuskan sebagai berikut:

### 2.1 Alasan Kuat InventoryManager sebagai Autoload Singleton
- **Observasi:** Sistem inventaris dipanggil dari berbagai sistem independen sepanjang siklus hidup game:
  - `Interactable` / Player saat mengambil starter container, memanen jagung/temu kunci di world.
  - `RecipeManager` (BOOK-001) saat menghitung total stok bebas (`get_available_item_count`).
  - `KitchenManager` (COOK-001) saat reservasi bahan dan refund jika dibatalkan.
  - `GardenManager` (GARD-002) saat memvalidasi apakah tas muat 2 item panen bayam + benih sebelum memotong tanaman.
  - `SaveManager` (SAVE-001) saat mengambil snapshot serialisasi dan memulihkan kondisi inventaris.
  - UI Inventaris & Storage Chest saat pemain menekan Tab atau berinteraksi dengan peti.
- **Kesimpulan:** `InventoryManager` **wajib didaftarkan sebagai Autoload singleton** (`res://scripts/inventory/inventory_manager.gd`) di `project.godot`. Pendekatan ini menghilangkan coupling antar-node, menjamin persistensi state saat transisi level, dan menyediakan event bus sinyal inventaris terpusat.

### 2.2 Model Struktur Data Kontainer (Tas dan Peti)
- Tas dan Peti memiliki perilaku kapasitas yang identik (12 slot tetap, batas tumpukan 20 per slot).
- Setiap slot direpresentasikan sebagai `Dictionary` dengan struktur konsisten:
  ```gdscript
  { "id": String, "count": int }
  ```
  Slot kosong direpresentasikan sebagai `{ "id": "", "count": 0 }` (atau dict kosong `{}`) untuk menghindari `null pointer dereference` saat diakses UI, namun tetap serializable ke JSON secara bersih.
- Tiga identifier kontainer standar didefinisikan sebagai konstanta:
  ```gdscript
  const CONTAINER_BACKPACK: String = "backpack"
  const CONTAINER_STORAGE: String = "storage"
  const CONTAINER_REFUND: String = "kitchen_refund"
  const BACKPACK_SLOTS: int = 12
  const STORAGE_SLOTS: int = 12
  const MAX_STACK_SIZE: int = 20
  ```

### 2.3 Algoritma Transaksi Atomik Dua Fase (Dry-Run & Commit)
Aturan "kapasitas dan prasyarat diperiksa dulu, sumber/tujuan berubah bersama, tidak ada transfer parsial diam-diam":
- **Fase 1 (Simulasi / Dry-Run):**
  Sebelum melakukan mutasi fisik pada kontainer sumber atau tujuan, sistem membuat salinan virtual dari slot tujuan (`virtual_slots = target_slots.duplicate(true)`).
  Algoritma simulasi melakukan kalkulasi:
  1. Mengisi tumpukan parsial yang sudah ada dengan ID yang sama (dari indeks 0 hingga 11) hingga `MAX_STACK_SIZE` (20).
  2. Jika masih ada sisa, mencari slot kosong (`id == ""` atau `count == 0`) dan mengalokasikannya hingga maksimal 20 per slot baru.
  3. Jika setelah seluruh slot diperiksa masih ada sisa item yang belum tertampung:
     - Simulasi **GAGAL**.
     - Fungsi mengembalikan `false`.
     - Emit sinyal `transaction_failed(reason)`.
     - **Tidak ada slot yang termutasi sama sekali.**
- **Fase 2 (Commit Atomik):**
  Hanya jika seluruh item berhasil dialokasikan dalam simulasi:
  - Terapkan perubahan pada kontainer tujuan.
  - Kurangi / kosongkan item dari kontainer sumber secara serentak.
  - Emit sinyal `item_transferred`, `inventory_changed(from)`, dan `inventory_changed(to)`.

### 2.4 Logika Pengambilan Wadah Awal (`container_starter`)
- Paket starter terdiri dari 3 entri item:
  1. `seed_bayam`: 4
  2. `soil_compost`: 1
  3. `fertilizer_basic`: 1
- Mekanisme Idempotensi & Proteksi Spam (T04):
  - Variabel internal boolean: `var _starter_collected: bool = false`.
  - Saat E ditekan pada `container_starter`:
    1. Cek: `if _starter_collected: return false` (Menolak langsung pemanggilan kedua dan seterusnya).
    2. Cek: `if not can_add_items(CONTAINER_BACKPACK, starter_items): return false` (Jika tas tidak muat 3 item tersebut, tolak transaksi, emit `transaction_failed("Kapasitas tas tidak mencukupi untuk mengambil paket awal.")`, `_starter_collected` tetap `false`).
    3. Commit: Tambahkan ketiga item ke tas secara atomik.
    4. Kunci: `_starter_collected = true`.
    5. Nonaktifkan interactable atau ubah prompt ke `[E] Wadah Kosong`.
    6. Emit `starter_collected(starter_items)` dan `inventory_changed(CONTAINER_BACKPACK)`.
- Hasil: Jika pemain spam E 100 kali dalam frame yang sama atau berurutan, hanya eksekusi pertama yang mengeksekusi commit; 99 pemanggilan berikutnya tertahan pada guard condition pertama.

### 2.5 Logika Perhitungan Stok Bebas Bersama (`get_available_item_count`)
- Memenuhi prasyarat BOOK-001 (T02, T31):
  ```gdscript
  func get_available_item_count(item_id: String) -> int:
      var total := 0
      total += get_container_item_count(CONTAINER_BACKPACK, item_id)
      total += get_container_item_count(CONTAINER_STORAGE, item_id)
      total -= get_reserved_item_count(item_id) # Reservasi memasak
      return maxi(0, total)
  ```
  Perpindahan barang antara tas dan peti tidak pernah mengubah nilai return fungsi ini (T31).
  Mengambil jagung sebelum melacak resep langsung tercermin pada fungsi ini (T02).

### 2.6 Logika Cek Panen Dua Item (`can_harvest` untuk T05)
- Panen tanaman bayam menghasilkan 1x `ingredient_bayam` dan 1x `seed_bayam`.
- Fungsi `can_accept_items(CONTAINER_BACKPACK, [{"id": "ingredient_bayam", "count": 1}, {"id": "seed_bayam", "count": 1}])` mengeksekusi dry-run multi-item:
  - Jika tas memiliki 0 slot kosong dan belum memiliki stack bayam/benih: tolak.
  - Jika tas memiliki 1 slot kosong dan belum memiliki bayam maupun benih: tolak (karena butuh 2 slot terpisah).
  - Jika tas memiliki 1 slot kosong dan sudah memiliki stack bayam berukuran < 20: lolos (bayam masuk tumpukan lama, benih mengisi 1 slot kosong).
  Ini persis memenuhi kontrak penerimaan T05.

### 2.7 Desain Sinyal (Event-Driven Observer Pattern)
Mengikuti pedoman `godot-signals-groups`:
```gdscript
signal inventory_changed(container_type: String)
signal item_transferred(item_id: String, count: int, from_container: String, to_container: String)
signal transaction_failed(reason: String)
signal item_added(item_id: String, count: int, container_type: String)
signal item_removed(item_id: String, count: int, container_type: String)
signal starter_collected(items: Array)
```
Argumen ber-tipe data statis mencegah ketidakcocokan argumen saat runtime.

---

## 3. Caveats

1. **ID Item Pupuk (`tool_fertilizer` vs `fertilizer_basic`):**
   - Di pesan dispatch tertulis: `4x seed_bayam, 1x soil_compost, 1x tool_fertilizer`.
   - Namun di `CONTENT.md` § 2 tabel item kamus resmi baris 20 tertulis:
     `fertilizer_basic` (Pupuk, Perawatan). Sementara `tool_fertilizer` adalah ID akses alat (CONTENT.md § 6).
   - **Rekomendasi Rujukan:** Jadikan `fertilizer_basic` sebagai ID kanonik resmi sesuai `CONTENT.md` § 2. Namun di `items_data.gd` dan `InventoryManager`, tambahkan penanganan alias: jika kode atau event mengirim ID `"tool_fertilizer"`, arahkan/alias-kan ke `"fertilizer_basic"` agar kompatibel tanpa menimbulkan ambiguitas atau kegagalan asersi.
2. **Kebutuhan UI pada INV-001:**
   - Kriteria `TASKS.md` menyebut: *"UI boleh sederhana tetapi nama/jumlah harus terlihat."*
   - Tidak diperlukan animasi kompleks atau visual stylized akhir pada tahap INV-001 (visual akhir ada di ART-001/UI-001).
   - Sebuah scene UI `scenes/ui/inventory_ui.tscn` (CanvasLayer) dengan dua panel GridContainer (12 slot Tas di sebelah kiri, 12 slot Peti di sebelah kanan, tombol/klik transfer, dan label nama + jumlah barang) sudah sangat memadai dan sepenuhnya memenuhi acceptance criteria.
3. **Persistensi / Save Data:**
   - Menyediakan metode `get_save_snapshot() -> Dictionary` dan `load_save_snapshot(data: Dictionary) -> bool` sekarang akan mempercepat implementasi `SAVE-001` nantinya tanpa refaktor besar.

---

## 4. Conclusion & Rekomendasi Implementasi untuk Worker

Berikut adalah rancangan file dan algoritma konkret yang direkomendasikan untuk dieksekusi oleh Worker:

### 4.1 Struktur File Baru
1. `scripts/inventory/items_data.gd`:
   Kamus data item statis (7 item P0) dengan nama bahasa Indonesia, kategori, deskripsi, dan `max_stack = 20`.
2. `scripts/inventory/inventory_manager.gd`:
   Autoload singleton pengelola kontainer tas (12), peti (12), refund (12), fungsi transaksi atomik, simulasi kapasitas, dan penarikan wadah awal.
3. `scenes/ui/inventory_ui.tscn` & `scripts/ui/inventory_ui.gd`:
   Antarmuka CanvasLayer untuk menampilkan slot tas & peti, terhubung dengan sinyal `inventory_changed` dan terintegrasi dengan `InputManager.ContextMode.STORAGE`.
4. `tests/suites/test_inventory.gd`:
   Suite pengujian otomatis unit & integrasi untuk T02, T03, T04, T05, T29, T30, dan T31.
5. Pendaftaran di `project.godot`:
   Mendaftarkan `InventoryManager="*res://scripts/inventory/inventory_manager.gd"`.
6. Pendaftaran di `tests/test_runner.gd`:
   Mendaftarkan `Suite 7: TestInventory`.

### 4.2 Pseudocode Inti `InventoryManager`

```gdscript
class_name InventoryManager
extends Node

const CONTAINER_BACKPACK := "backpack"
const CONTAINER_STORAGE := "storage"
const CONTAINER_REFUND := "kitchen_refund"
const BACKPACK_SLOTS := 12
const STORAGE_SLOTS := 12
const MAX_STACK_SIZE := 20

signal inventory_changed(container_type: String)
signal item_transferred(item_id: String, count: int, from_container: String, to_container: String)
signal transaction_failed(reason: String)
signal item_added(item_id: String, count: int, container_type: String)
signal item_removed(item_id: String, count: int, container_type: String)
signal starter_collected(items: Array)

var _backpack: Array[Dictionary] = []
var _storage: Array[Dictionary] = []
var _refund: Array[Dictionary] = []
var _reservations: Dictionary = {} # job_id -> Array[Dictionary]
var _starter_collected: bool = false

func _ready() -> void:
    _init_containers()

func _init_containers() -> void:
    _backpack.clear()
    for i in range(BACKPACK_SLOTS):
        _backpack.append({"id": "", "count": 0})
    _storage.clear()
    for i in range(STORAGE_SLOTS):
        _storage.append({"id": "", "count": 0})
    _refund.clear()
    for i in range(STORAGE_SLOTS):
        _refund.append({"id": "", "count": 0})

# 1. DRY-RUN CAPACITY CHECK
func can_accept_items(container_type: String, items_to_add: Array) -> bool:
    var slots_copy: Array = _get_container_slots(container_type).duplicate(true)
    for item in items_to_add:
        var id: String = item.get("id", "")
        var count: int = item.get("count", 0)
        if count <= 0 or id == "": continue
        
        # 1a. Fill existing matching stacks
        for slot in slots_copy:
            if slot["id"] == id and slot["count"] < MAX_STACK_SIZE:
                var take = mini(count, MAX_STACK_SIZE - slot["count"])
                slot["count"] += take
                count -= take
                if count == 0: break
                
        # 1b. Fill empty slots
        if count > 0:
            for slot in slots_copy:
                if slot["id"] == "" or slot["count"] == 0:
                    var take = mini(count, MAX_STACK_SIZE)
                    slot["id"] = id
                    slot["count"] = take
                    count -= take
                    if count == 0: break
                    
        # If remaining count > 0, it doesn't fit!
        if count > 0:
            return false
    return true

# 2. ATOMIC ADD ITEMS
func add_items(container_type: String, items_to_add: Array) -> bool:
    if not can_accept_items(container_type, items_to_add):
        transaction_failed.emit("Kapasitas penyimpanan tidak cukup.")
        return false
        
    var slots := _get_container_slots(container_type)
    for item in items_to_add:
        var id: String = item.get("id", "")
        var count: int = item.get("count", 0)
        if count <= 0 or id == "": continue
        
        for slot in slots:
            if slot["id"] == id and slot["count"] < MAX_STACK_SIZE:
                var take = mini(count, MAX_STACK_SIZE - slot["count"])
                slot["count"] += take
                count -= take
                if count == 0: break
                
        if count > 0:
            for slot in slots:
                if slot["id"] == "" or slot["count"] == 0:
                    var take = mini(count, MAX_STACK_SIZE)
                    slot["id"] = id
                    slot["count"] = take
                    count -= take
                    if count == 0: break
                    
        item_added.emit(id, item.get("count", 0), container_type)
        
    inventory_changed.emit(container_type)
    return true

# 3. ATOMIC TWO-WAY TRANSFER (NO PARTIAL TRANSFER)
func transfer_slot(from_container: String, slot_index: int, to_container: String) -> bool:
    var from_slots := _get_container_slots(from_container)
    if slot_index < 0 or slot_index >= from_slots.size():
        return false
    var src_slot: Dictionary = from_slots[slot_index]
    if src_slot["id"] == "" or src_slot["count"] <= 0:
        return false
        
    var item_id: String = src_slot["id"]
    var count: int = src_slot["count"]
    
    # Check if target can hold the ENTIRE stack
    if not can_accept_items(to_container, [{"id": item_id, "count": count}]):
        transaction_failed.emit("Kapasitas tujuan tidak cukup untuk memindahkan tumpukan.")
        return false
        
    # Atomic execution
    from_slots[slot_index] = {"id": "", "count": 0}
    add_items(to_container, [{"id": item_id, "count": count}])
    item_transferred.emit(item_id, count, from_container, to_container)
    inventory_changed.emit(from_container)
    return true

# 4. STARTER CONTAINER PICKUP
func collect_starter_container() -> bool:
    if _starter_collected:
        transaction_failed.emit("Wadah starter sudah pernah diambil.")
        return false
        
    var starter_items = [
        {"id": "seed_bayam", "count": 4},
        {"id": "soil_compost", "count": 1},
        {"id": "fertilizer_basic", "count": 1}
    ]
    
    if not can_accept_items(CONTAINER_BACKPACK, starter_items):
        transaction_failed.emit("Tas penuh. Butuh ruang untuk paket awal.")
        return false
        
    _starter_collected = true
    add_items(CONTAINER_BACKPACK, starter_items)
    starter_collected.emit(starter_items)
    return true

# 5. AGGREGATED FREE STOCK (T02, T31)
func get_available_item_count(item_id: String) -> int:
    var total := 0
    for slot in _backpack:
        if slot["id"] == item_id: total += slot["count"]
    for slot in _storage:
        if slot["id"] == item_id: total += slot["count"]
    # Subtract reservations
    for job_id in _reservations:
        for r_item in _reservations[job_id]:
            if r_item.get("id", "") == item_id:
                total -= r_item.get("count", 0)
    return maxi(0, total)
```

---

## 5. Verification Method

Untuk memverifikasi kebenaran implementasi saat Worker selesai:

1. **Eksekusi Test Runner Headless:**
   ```powershell
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"
   ```
   *Expected:* Seluruh suite lama (Suite 1..6) dan Suite 7 (`TestInventory`) lulus 100% tanpa kegagalan (exit code 0).
2. **Kasus Uji yang Wajib Diverifikasi dalam Suite 7:**
   - `T29`: Tumpukan bertambah hingga 20; penambahan melebihi batas membuka slot baru jika ada; transaksi ditolak penuh jika slot tidak cukup.
   - `T30`: Transfer stack/all ke kontainer yang tidak cukup ruang ditolak mutlak tanpa transfer parsial, state awal utuh 100%.
   - `T04`: Pengambilan starter crate memberikan 4 benih, 1 pembenah, 1 pupuk; spam pemanggilan berikutnya ditolak bersih tanpa duplikasi.
   - `T05`: Simulasi panen bayam (1 bayam + 1 benih) pada tas dengan 0 slot kosong (atau 1 slot kosong tanpa tumpukan bayam) ditolak.
   - `T02/T31`: Perpindahan bahan tas–peti mempertahankan nilai `get_available_item_count()`.
3. **Audit Konsistensi Proyek:**
   ```powershell
   python ".agents/skills/godot-nodes-scenes/scripts/check_godot_project.py" .
   ```
   *Expected:* 0 errors, 0 warnings pada seluruh file proyek.
4. **Smoke Test Adegan Utama:**
   ```powershell
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 60"
   ```
   *Expected:* Eksekusi bersih tanpa error/warning.
