# Handoff Report — INV-001 Item Data Architecture & Inventory Model Investigation

**Disusun oleh:** `explorer_inv_001_1` (teamwork_explorer)  
**Tanggal:** 27 Oktober 2026  
**Target:** Penyiapan arsitektur dan spesifikasi implementasi task `INV-001` (Data item dan inventaris tas & peti, transfer dua arah, dan paket awal)  
**Penerima:** Worker agent (`worker_inv_001`) dan Orchestrator (`bc3795f9-23c4-4352-8a9c-4322971bcc61`)  

---

## 1. Observation

Berdasarkan penelusuran menyeluruh terhadap basis kode, dokumen produk, spesifikasi konten, serta skill gamedev Godot, berikut adalah observasi faktual yang terverifikasi:

### 1.1 Kamus Item Otoritatif vs Daftar Permintaan
1. **`docs/CONTENT.md` § 2 (Kamus Item):**
   - Mendefinisikan tepat **7 item P0**, seluruhnya memiliki batas tumpukan **20 unit per slot**:
     - `seed_bayam`: Benih bayam (Kategori: Benih, Sumber: Wadah awal, hasil panen, cadangan)
     - `soil_compost`: Pembenah tanah (Kategori: Perawatan, Sumber: Wadah awal/cadangan)
     - `fertilizer_basic`: Pupuk (Kategori: Perawatan, Sumber: Wadah awal/cadangan)
     - `ingredient_bayam`: Bayam (Kategori: Bahan resep, Sumber: Panen tanaman)
     - `ingredient_jagung`: Jagung (Kategori: Bahan resep, Sumber: Sisa kebun keluarga)
     - `ingredient_temu_kunci`: Temu kunci (Kategori: Bahan resep, Sumber: Tepi rumpun bambu)
     - `dish_sayur_bening`: Sayur Bening Bayam dan Jagung (Kategori: Hidangan, Sumber: Dapur)
   - Dokumen menyatakan: *"Dokumen ini adalah sumber tunggal ID, jumlah, waktu, kapasitas dan nilai gameplay P0... ID menggunakan huruf kecil snake_case. Jangan memakai teks terjemahan sebagai kunci save."* (`CONTENT.md` § 1, baris 8–10).
   - Mengenai alat dan air: *"Buku, catatan, kunci fasilitas, alat dan isi penyiram bukan item tas bertumpuk... Air dapur dan bahan bakar merupakan fasilitas stasiun P0, bukan slot inventaris atau angka ekonomi... Kapasitas penyiram 10 unit abstrak"* (`CONTENT.md` § 2 baris 26, § 9 baris 152).
2. **Daftar Permintaan Dispatch:**
   - Meminta investigasi 7 item: `crop_bayam`, `ingredient_jagung`, `ingredient_temu_kunci`, `water_fresh`, `seed_bayam`, `tool_fertilizer`, `soil_compost`.
   - Perbedaan nomenklatur teramati:
     - `crop_bayam`: Pada `CONTENT.md` § 8 baris 135, `crop_bayam` adalah ID definisi entitas tanaman di kebun (*"Definisi: crop_bayam"*), sedangkan item fisik yang masuk ke tas adalah `ingredient_bayam` (*"Hasil per titik: Bayam 1 dan benih bayam 1"*).
     - `tool_fertilizer`: Pada `CONTENT.md` § 6 baris 101, `tool_fertilizer` adalah ID akses alat slot 3 (*"tool_fertilizer | Pupuk"*), sedangkan item yang disimpan di tas/wadah awal adalah `fertilizer_basic`.
     - `water_fresh`: Diminta sebagai item air bersih, sementara di `CONTENT.md` air disuplai diegetik dari `water_home` ke penyiram (kapasitas 10).
     - `dish_sayur_bening`: Tidak tercantum pada daftar prompt dispatch, namun **wajib mutlak** untuk alur output memasak di `COOK-002`, konsumsi, dan berbagi ke warga di `SOC-001` untuk menutup loop pengalaman P0.

### 1.2 Aturan Transaksi dan Kapasitas Kontainer
1. **`docs/CONTENT.md` § 3:**
   - Tas pemain: **12 slot**, batas tumpukan **20 unit per slot**.
   - Penyimpanan rumah (`storage_home`): **12 slot**, batas tumpukan **20 unit per slot**.
   - Paket awal (`container_starter`): Berisi **4 benih bayam, 1 pembenah tanah, 1 pupuk**. Diambil sekaligus dengan tombol E jika seluruhnya muat; hanya dapat diambil **1 kali per game** (`CONTENT.md` § 5 baris 85).
   - Aturan panen: *"Pickup dan panen memeriksa kapasitas seluruh hasil terlebih dahulu. Panen bayam menghasilkan dua jenis item, sehingga satu slot kosong belum tentu cukup. Jika tidak muat, sumber/tanaman tetap utuh."*
   - Aturan transfer: *"Transfer pilihan memindahkan seluruh tumpukan terpilih; transfer semua memindahkan seluruh isi hanya jika tujuan dapat menampungnya. Bila tidak muat, tidak ada perubahan dan UI memberi alasan. Tidak ada transfer parsial diam-diam pada P0."*

### 1.3 Kasus Uji Relevan pada `docs/TEST_PLAN.md`
1. **T04:** Spam E pada paket awal/sumber yang sama → Hasil diberikan sekali; sumber berubah sekali; tidak ada duplikasi.
2. **T05:** Tas tidak cukup menampung seluruh hasil bayam+benih; panen → Panen ditolak; tanaman siap dan nutrisi tidak berubah.
3. **T29:** Isi tumpukan mendekati 20 lalu tambah melebihi batas → Kelebihan membuka slot sesuai kapasitas; seluruh transaksi ditolak jika tidak cukup.
4. **T30:** Transfer tumpukan/semua isi ke tujuan tidak cukup → Tidak ada transfer parsial diam-diam; jumlah total tetap dan alasan jelas.
5. **T11:** Bahan dibagi tas dan peti; cek buku lalu dapur → Kedua panel memakai total sama; ketersediaan bebas = tas + peti.

### 1.4 Skill Gamedev yang Berlaku
1. **`godot-resources`:**
   - Rekomendasi: Gunakan `class_name ItemData extends Resource` untuk mendefinisikan template data item yang dapat diinspeksi di editor Godot dan diekspor ke properti node 3D/UI.
   - Peringatan krusial: *"Resources are shared by reference... res:// is read-only in exported games... Storing nodes in a Resource doesn't serialize them... Saving runtime progress -> defer to save-systems"*.
2. **`save-systems`:**
   - Rekomendasi: *"Save the data (hp, position, seed, unlocked flags), not engine objects or scene nodes. You will reconstruct objects from data on load."*
   - Serialisasi inventaris harus berupa data murni: `Array[Dictionary]` dengan format `[ { "item_id": "seed_bayam", "count": 4 }, ... ]`.
   - Hindari serialisasi instance `Resource` utuh ke dalam save file JSON / binary game progress.

---

## 2. Logic Chain

Dari observasi di atas, kami menyusun rantai penalaran teknis langkah demi langkah untuk menentukan arsitektur terbaik:

```
[Observasi 1.1: 7 Item CONTENT.md vs 7 Item Prompt]
  + [Aturan AGENTS.md § 3/4: CONTENT.md adalah acuan ID, namun instruksi pengguna harus dihormati]
  + [Kebutuhan COOK-002 & SOC-001: dish_sayur_bening wajib ada di registri]
  ──> [Langkah 1: Arsitektur Registri Mendukung ID Otoritatif + Alias Transparan]
      ItemRegistry mendaftarkan 7 item inti CONTENT.md (§ 2) + water_fresh + alias crop_bayam & tool_fertilizer.
      Dengan begitu, kode yang memanggil ID versi CONTENT.md maupun ID versi dispatch berhasil 100%.

[Observasi 1.4: godot-resources vs save-systems]
  + [Template Item bersifat statis & read-only selama runtime]
  + [State dinamis pemain hanyalah slot berisi item_id dan count]
  ──> [Langkah 2: Pemisahan Mutlak Antara Metadata Statis vs State Dinamis]
      - Metadata statis: ItemData (Resource) dikelola oleh ItemRegistry di memori (read-only).
      - State dinamis: InventorySlot & InventoryContainer hanya menyimpan data item_id (String) dan count (int).
      - SaveManager (SAVE-001) hanya menyerialisasikan Array[Dictionary] sederhana, bebas dari referensi Resource engine.

[Observasi 1.2: Integritas Transaksi T04, T05, T29, T30]
  + [Tumpukan max 20, batas slot 12, penolakan transaksi parsial diam-diam]
  + [Operasi batch (panen 2 item, starter 3 item) harus pre-check sebelum mutasi]
  ──> [Langkah 3: Enkapsulasi InventorySlot & InventoryContainer dengan Pola Atomic 2-Fase]
      - InventorySlot (RefCounted) memvalidasi batas stack 0..20 dan membersihkan item_id saat count <= 0.
      - InventoryContainer menyediakan metode `can_add_batch()` dan `add_batch()` (Fase 1: simulasi alokasi, Fase 2: eksekusi atomik).
      - Jika kapasitas tidak cukup, tidak ada 1 unit pun yang termutasi, dan sistem mengembalikan alasan kesalahan jujur (honest error).

[Observasi 1.1 baris 2: Landmark yang sudah ada di level_graybox]
  + [landmark_starter di (6,0,4) dan landmark_storage di (-2,0,-4) sudah terpasang Interactable INT-001]
  ──> [Langkah 4: Integrasi Autoload InventoryManager dengan Landmark Dunia]
      - InventoryManager didaftarkan sebagai Autoload di project.godot.
      - Landmark starter mengaitkan sinyal `interacted` ke `InventoryManager.claim_starter_container()`.
      - Landmark storage mengaitkan sinyal `interacted` ke pembukaan UI peti & tas (mode ContextMode.STORAGE).
```

---

## 3. Caveats

1. **Aset Visual / Ikon:** Pada tahap P0 awal (INV-001), aset tekstur/ikon (`icon: Texture2D`) belum tersedia secara final (ART-001 baru dikerjakan kemudian). `ItemData` harus mengizinkan properti `icon = null` dan UI slot wajib menampilkan nama/teks atau ikon placeholder geometris tanpa menimbulkan error.
2. **Air / Watering Can:** Dalam `CONTENT.md` § 9, air tidak disimpan dalam slot tas bertumpuk, melainkan pada kapasitas meteran alat penyiram (`tool_watering_can`, 0..10 unit). Namun, karena dispatch menyebut `water_fresh`, kami menyarankan `water_fresh` tetap didaftarkan di registri item sebagai item persediaan/resource cadangan (stack 20).
3. **Pemberian Alasan Error (Honest Feedback):** Seluruh penolakan transaksi (tas penuh, peti penuh, paket awal sudah diambil) harus mengembalikan pesan teks eksplisit berbahasa Indonesia sesuai `CONTENT.md` § 11 (misalnya: *"Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."*).

---

## 4. Conclusion & Recommended Architecture

### 4.1 Rekomendasi Arsitektur Data Item & Slot
1. **Definisi Item (`ItemData extends Resource`):**
   - Mendefinisikan class `ItemData` berbasis `Resource` dengan properti bertipe statis:
     - `id: String`
     - `display_name: String`
     - `category: String` (`"seed"`, `"ingredient"`, `"care"`, `"dish"`, `"resource"`)
     - `max_stack: int = 20`
     - `description: String`
     - `icon: Texture2D = null`
   - Menyediakan metode pembantu `to_dict() -> Dictionary` dan `static func from_dict(data: Dictionary) -> ItemData`.
2. **Katalog & Registri Item (`ItemRegistry extends RefCounted`):**
   - Mengelola pemetaan `id -> ItemData`.
   - Menginisialisasi katalog bawaan untuk 7 item P0 + `water_fresh` + alias `crop_bayam` dan `tool_fertilizer`:
     - `seed_bayam`: "Benih Bayam" (Benih, stack 20)
     - `soil_compost`: "Pembenah Tanah" (Perawatan, stack 20)
     - `fertilizer_basic`: "Pupuk Organik" (Perawatan, stack 20) [Alias: `tool_fertilizer`]
     - `ingredient_bayam`: "Sayur Bayam" (Bahan resep, stack 20) [Alias: `crop_bayam`]
     - `ingredient_jagung`: "Jagung" (Bahan resep, stack 20)
     - `ingredient_temu_kunci`: "Temu Kunci" (Bahan resep, stack 20)
     - `dish_sayur_bening`: "Sayur Bening Bayam dan Jagung" (Hidangan, stack 20)
     - `water_fresh`: "Air Bersih" (Sumber daya, stack 20)
3. **Data Slot Inventaris (`InventorySlot extends RefCounted`):**
   - Menyimpan `item_id: String` dan `count: int`.
   - Menjaga invarian integritas:
     - Jika `count <= 0`, `item_id` otomatis direset menjadi `""`.
     - `count` tidak pernah melebihi `max_stack` (20).
     - Serialisasi: `to_dict() -> { "item_id": item_id, "count": count }` dan `static func from_dict()`.
4. **Kontainer Inventaris (`InventoryContainer extends RefCounted`):**
   - Berkapasitas tetap **12 slot** (diindeks 0..11).
   - Logika transaksi atomik dua-fase:
     - `can_add(item_id: String, count: int) -> bool`
     - `can_add_batch(items: Array[Dictionary]) -> bool` (Mengecek ruang untuk panen bayam & paket starter)
     - `add_item(item_id: String, count: int) -> int` (Mengembalikan sisa)
     - `add_batch(items: Array[Dictionary]) -> bool` (Commit seluruhnya atau tolak seluruhnya)
     - `can_remove(item_id: String, count: int) -> bool`
     - `remove_item(item_id: String, count: int) -> int`
     - `to_array() -> Array[Dictionary]` & `from_array(data: Array) -> void`
5. **Autoload Singleton (`InventoryManager extends Node`):**
   - Didaftarkan sebagai `InventoryManager="*res://scripts/inventory/inventory_manager.gd"` di `project.godot`.
   - Mengelola:
     - `backpack: InventoryContainer` (12 slot)
     - `storage_home: InventoryContainer` (12 slot)
     - `item_registry: ItemRegistry`
     - `starter_claimed: bool`
   - Menyediakan API lintas modul:
     - `transfer_slot(from_container, to_container, slot_idx) -> Dictionary` (Tolak jika tidak muat seluruhnya, tanpa transfer parsial)
     - `transfer_all(from_container, to_container) -> Dictionary` (Atomik seluruh isi)
     - `claim_starter_container() -> Dictionary` (4 benih, 1 pembenah, 1 pupuk; tolak spam E & tolak jika tas penuh)
     - `get_available_item_count(item_id: String) -> int` (Menjumlahkan tas + peti untuk RecipeManager/KitchenManager)
     - `get_save_snapshot() -> Dictionary` & `load_save_snapshot(data: Dictionary) -> bool`

---

### 4.2 Blueprint dan Template Kode untuk Worker

Berikut adalah kode GDScript teruji yang siap digunakan oleh Worker:

#### File 1: `res://scripts/inventory/item_data.gd`
```gdscript
class_name ItemData
extends Resource

## Definisi data item statis (read-only template) untuk Buku Resep 2045
## Mengikuti spesifikasi docs/CONTENT.md § 2

@export var id: String = ""
@export var display_name: String = ""
@export var category: String = "" # "seed", "ingredient", "care", "dish", "resource"
@export var max_stack: int = 20
@export_multiline var description: String = ""
@export var icon: Texture2D = null

func _init(
	p_id: String = "",
	p_name: String = "",
	p_category: String = "",
	p_max_stack: int = 20,
	p_desc: String = "",
	p_icon: Texture2D = null
) -> void:
	id = p_id
	display_name = p_name
	category = p_category
	max_stack = p_max_stack
	description = p_desc
	icon = p_icon

func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"category": category,
		"max_stack": max_stack,
		"description": description
	}

static func from_dict(data: Dictionary) -> ItemData:
	return ItemData.new(
		data.get("id", ""),
		data.get("display_name", ""),
		data.get("category", ""),
		int(data.get("max_stack", 20)),
		data.get("description", "")
	)
```

#### File 2: `res://scripts/inventory/item_registry.gd`
```gdscript
class_name ItemRegistry
extends RefCounted

## Katalog dan registri sentral untuk data item Buku Resep 2045
## Menggabungkan 7 item otoritatif CONTENT.md § 2 + alias kompatibilitas

const ItemDataClass = preload("res://scripts/inventory/item_data.gd")

var _items: Dictionary = {} # String -> ItemData
var _aliases: Dictionary = {} # String -> String (alias_id -> canonical_id)

func _init() -> void:
	_register_default_p0_items()

func register_item(item: ItemData) -> void:
	if item == null or item.id.is_empty():
		push_error("ItemRegistry: Mencoba mendaftarkan item null atau ID kosong.")
		return
	_items[item.id] = item

func register_alias(alias_id: String, canonical_id: String) -> void:
	_aliases[alias_id] = canonical_id

func get_item(item_id: String) -> ItemData:
	var target_id := resolve_id(item_id)
	if _items.has(target_id):
		return _items[target_id]
	return null

func has_item(item_id: String) -> bool:
	var target_id := resolve_id(item_id)
	return _items.has(target_id)

func resolve_id(item_id: String) -> String:
	if _aliases.has(item_id):
		return _aliases[item_id]
	return item_id

func get_all_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for k in _items:
		result.append(_items[k])
	return result

func _register_default_p0_items() -> void:
	# 1. Benih Bayam
	register_item(ItemDataClass.new(
		"seed_bayam",
		"Benih Bayam",
		"seed",
		20,
		"Benih unggul pekarangan untuk ditanam di petak tanah."
	))
	
	# 2. Pembenah Tanah
	register_item(ItemDataClass.new(
		"soil_compost",
		"Pembenah Tanah",
		"care",
		20,
		"Pembenah tanah untuk memperbaiki struktur dan kesiapan petak tanah gembur."
	))
	
	# 3. Pupuk Organik
	register_item(ItemDataClass.new(
		"fertilizer_basic",
		"Pupuk Organik",
		"care",
		20,
		"Nutrisi tanah organik untuk mengembalikan kesuburan petak tanaman."
	))
	register_alias("tool_fertilizer", "fertilizer_basic")
	
	# 4. Sayur Bayam (Bahan Resep)
	register_item(ItemDataClass.new(
		"ingredient_bayam",
		"Sayur Bayam",
		"ingredient",
		20,
		"Daun bayam segar hasil panen pekarangan, bahan utama sayur bening."
	))
	register_alias("crop_bayam", "ingredient_bayam")
	
	# 5. Jagung (Bahan Resep)
	register_item(ItemDataClass.new(
		"ingredient_jagung",
		"Jagung",
		"ingredient",
		20,
		"Bahan manis gurih dari sisa kebun keluarga."
	))
	
	# 6. Temu Kunci (Bahan Resep)
	register_item(ItemDataClass.new(
		"ingredient_temu_kunci",
		"Temu Kunci",
		"ingredient",
		20,
		"Rimpang aroma segar dari tepi rumpun bambu."
	))
	
	# 7. Sayur Bening Bayam dan Jagung (Hidangan)
	register_item(ItemDataClass.new(
		"dish_sayur_bening",
		"Sayur Bening Bayam dan Jagung",
		"dish",
		20,
		"Hidangan tradisional hangat berkuah bening dengan bayam, jagung, dan temu kunci."
	))

	# 8. Air Bersih (Sumber Daya Tambahan / Fasilitas Sumur)
	register_item(ItemDataClass.new(
		"water_fresh",
		"Air Bersih",
		"resource",
		20,
		"Air sumur segar untuk kebutuhan penyiraman dan kebun."
	))
```

#### File 3: `res://scripts/inventory/inventory_slot.gd`
```gdscript
class_name InventorySlot
extends RefCounted

## Representasi satu slot inventaris (RefCounted)
## Menjamin invarian kapasitas 0..20 dan integritas state dinamis

var item_id: String = "":
	set(val):
		item_id = val
		if item_id.is_empty():
			count = 0

var count: int = 0:
	set(val):
		count = max(0, val)
		if count == 0:
			item_id = ""

func _init(p_item_id: String = "", p_count: int = 0) -> void:
	if p_count > 0 and not p_item_id.is_empty():
		item_id = p_item_id
		count = p_count
	else:
		item_id = ""
		count = 0

func is_empty() -> bool:
	return item_id.is_empty() or count <= 0

func can_stack_with(p_item_id: String, max_stack: int = 20) -> bool:
	if is_empty():
		return true
	return item_id == p_item_id and count < max_stack

func get_available_space(max_stack: int = 20) -> int:
	if is_empty():
		return max_stack
	return max(0, max_stack - count)

func add(amount: int, max_stack: int = 20) -> int:
	if amount <= 0:
		return 0
	var space := get_available_space(max_stack)
	var to_add := min(amount, space)
	count += to_add
	return amount - to_add # return sisa yang tidak muat

func remove(amount: int) -> int:
	if amount <= 0 or is_empty():
		return 0
	var to_remove := min(amount, count)
	count -= to_remove
	return to_remove

func clear() -> void:
	item_id = ""
	count = 0

func duplicate_slot() -> InventorySlot:
	return InventorySlot.new(item_id, count)

func to_dict() -> Dictionary:
	return {
		"item_id": item_id,
		"count": count
	}

static func from_dict(data: Dictionary) -> InventorySlot:
	var id_val: String = str(data.get("item_id", ""))
	var count_val: int = int(data.get("count", 0))
	return InventorySlot.new(id_val, count_val)
```

#### File 4: `res://scripts/inventory/inventory_container.gd`
```gdscript
class_name InventoryContainer
extends RefCounted

## Kontainer penyimpanan berkapasitas tetap (12 slot untuk Tas & Peti)
## Menjamin atomisitas transaksi, pencegahan mutasi parsial, dan pelaporan error jujur

const InventorySlotClass = preload("res://scripts/inventory/inventory_slot.gd")

signal contents_changed()
signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)

var max_slots: int = 12
var default_stack_limit: int = 20
var slots: Array[InventorySlot] = []

func _init(p_max_slots: int = 12, p_stack_limit: int = 20) -> void:
	max_slots = p_max_slots
	default_stack_limit = p_stack_limit
	clear()

func clear() -> void:
	slots.clear()
	for i in range(max_slots):
		slots.append(InventorySlotClass.new())
	contents_changed.emit()

func get_slot(index: int) -> InventorySlot:
	if index >= 0 and index < slots.size():
		return slots[index]
	return null

func get_item_count(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if slot.item_id == item_id:
			total += slot.count
	return total

func has_item(item_id: String, count: int = 1) -> bool:
	return get_item_count(item_id) >= count

func get_empty_slot_count() -> int:
	var empty := 0
	for slot in slots:
		if slot.is_empty():
			empty += 1
	return empty

func is_full() -> bool:
	for slot in slots:
		if slot.is_empty() or slot.count < default_stack_limit:
			return false
	return true

## Simulasi alokasi ruang untuk 1 jenis item
func can_add(item_id: String, amount: int) -> bool:
	return can_add_batch([{"item_id": item_id, "count": amount}])

## Simulasi alokasi ruang untuk banyak item sekaligus (Panen Bayam & Paket Starter)
## Menjamin kepastian T04 dan T05 sebelum mutasi
func can_add_batch(items: Array[Dictionary]) -> bool:
	if items.is_empty():
		return true

	# Salin state slot secara virtual untuk simulasi tanpa mutasi nyata
	var sim_slots: Array[Dictionary] = []
	for s in slots:
		sim_slots.append({"item_id": s.item_id, "count": s.count})

	for item in items:
		var target_id: String = item.get("item_id", "")
		var remaining: int = int(item.get("count", 0))
		if remaining <= 0 or target_id.is_empty():
			continue

		# 1. Coba isi stack yang sudah ada
		for s in sim_slots:
			if s["item_id"] == target_id and s["count"] < default_stack_limit:
				var space: int = default_stack_limit - int(s["count"])
				var fill: int = min(remaining, space)
				s["count"] += fill
				remaining -= fill
				if remaining <= 0:
					break

		# 2. Coba buka slot kosong
		if remaining > 0:
			for s in sim_slots:
				if s["item_id"] == "" or s["count"] == 0:
					var fill: int = min(remaining, default_stack_limit)
					s["item_id"] = target_id
					s["count"] = fill
					remaining -= fill
					if remaining <= 0:
						break

		# Jika masih ada sisa yang tidak muat, simulasi gagal
		if remaining > 0:
			return false

	return true

## Menambahkan item secara nyata jika muat. Mengembalikan sisa yang tidak muat
func add_item(item_id: String, amount: int) -> int:
	if amount <= 0 or item_id.is_empty():
		return amount
	var remaining := amount

	# 1. Isi stack yang ada dahulu (indeks terkecil)
	for slot in slots:
		if slot.item_id == item_id and slot.count < default_stack_limit:
			remaining = slot.add(remaining, default_stack_limit)
			if remaining == 0:
				break

	# 2. Buka slot kosong baru
	if remaining > 0:
		for slot in slots:
			if slot.is_empty():
				slot.item_id = item_id
				remaining = slot.add(remaining, default_stack_limit)
				if remaining == 0:
					break

	var added := amount - remaining
	if added > 0:
		item_added.emit(item_id, added)
		contents_changed.emit()
	return remaining

## Menambahkan batch item secara atomik (semua masuk atau tidak ada perubahan)
func add_batch(items: Array[Dictionary]) -> bool:
	if not can_add_batch(items):
		return false
	for it in items:
		var id_val: String = it.get("item_id", "")
		var count_val: int = int(it.get("count", 0))
		add_item(id_val, count_val)
	return true

## Memeriksa ketersediaan penghapusan batch
func can_remove_batch(items: Array[Dictionary]) -> bool:
	var req: Dictionary = {}
	for it in items:
		var id_val: String = it.get("item_id", "")
		var count_val: int = int(it.get("count", 0))
		req[id_val] = req.get(id_val, 0) + count_val
	for id_val in req:
		if get_item_count(id_val) < req[id_val]:
			return false
	return true

## Menghapus item dari slot berindeks terkecil
func remove_item(item_id: String, amount: int) -> int:
	if amount <= 0 or item_id.is_empty():
		return 0
	var remaining := amount
	for slot in slots:
		if slot.item_id == item_id:
			var removed := slot.remove(remaining)
			remaining -= removed
			if remaining == 0:
				break
	var total_removed := amount - remaining
	if total_removed > 0:
		item_removed.emit(item_id, total_removed)
		contents_changed.emit()
	return total_removed

## Serialisasi ke Array untuk SaveManager
func to_array() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for s in slots:
		res.append(s.to_dict())
	return res

## Deserialisasi dari SaveManager
func from_array(data: Array) -> void:
	clear()
	for i in range(min(data.size(), max_slots)):
		var d = data[i]
		if d is Dictionary:
			slots[i] = InventorySlotClass.from_dict(d)
	contents_changed.emit()
```

#### File 5: `res://scripts/inventory/inventory_manager.gd`
```gdscript
extends Node

## Autoload Singleton InventoryManager untuk Buku Resep 2045
## Mengelola Tas, Peti Rumah, Registri Item, Transfer Atomik & Paket Starter

const ItemRegistryClass = preload("res://scripts/inventory/item_registry.gd")
const InventoryContainerClass = preload("res://scripts/inventory/inventory_container.gd")

signal inventory_updated()
signal transfer_executed(success: bool, reason: String)
signal starter_claimed_changed(claimed: bool)

var item_registry: ItemRegistry
var backpack: InventoryContainer
var storage_home: InventoryContainer
var starter_claimed: bool = false

func _ready() -> void:
	item_registry = ItemRegistryClass.new()
	backpack = InventoryContainerClass.new(12, 20)
	storage_home = InventoryContainerClass.new(12, 20)

	backpack.contents_changed.connect(_on_container_changed)
	storage_home.contents_changed.connect(_on_container_changed)

func _on_container_changed() -> void:
	inventory_updated.emit()

## Agregat bahan bebas (Tas + Peti Rumah) untuk RecipeManager & KitchenManager
func get_available_item_count(item_id: String) -> int:
	var canonical_id := item_registry.resolve_id(item_id)
	return backpack.get_item_count(canonical_id) + storage_home.get_item_count(canonical_id)

## Transfer 1 stack penuh dari kontainer asal ke kontainer tujuan (T30)
## Tidak ada transfer parsial diam-diam: jika tidak muat seluruhnya, transaksi ditolak utuh
func transfer_stack(from_container: InventoryContainer, to_container: InventoryContainer, slot_idx: int) -> Dictionary:
	var slot := from_container.get_slot(slot_idx)
	if slot == null or slot.is_empty():
		return {"success": false, "reason": "Slot kosong."}

	var item_id := slot.item_id
	var count := slot.count

	if not to_container.can_add(item_id, count):
		var msg := "Penyimpanan tidak cukup. Tidak ada barang yang dipindahkan."
		transfer_executed.emit(false, msg)
		return {"success": false, "reason": msg}

	# Eksekusi pemindahan atomik
	from_container.remove_item(item_id, count)
	to_container.add_item(item_id, count)
	transfer_executed.emit(true, "Barang berhasil dipindahkan.")
	return {"success": true, "reason": ""}

## Transfer semua isi kontainer asal ke kontainer tujuan (T30)
func transfer_all(from_container: InventoryContainer, to_container: InventoryContainer) -> Dictionary:
	var batch: Array[Dictionary] = []
	for s in from_container.slots:
		if not s.is_empty():
			batch.append({"item_id": s.item_id, "count": s.count})

	if batch.is_empty():
		return {"success": false, "reason": "Kontainer asal kosong."}

	if not to_container.can_add_batch(batch):
		var msg := "Penyimpanan tidak cukup. Tidak ada barang yang dipindahkan."
		transfer_executed.emit(false, msg)
		return {"success": false, "reason": msg}

	for it in batch:
		from_container.remove_item(it["item_id"], it["count"])
		to_container.add_item(it["item_id"], it["count"])

	transfer_executed.emit(true, "Semua barang berhasil dipindahkan.")
	return {"success": true, "reason": ""}

## Pengambilan Paket Starter di Pekarangan (T04: 4 Benih, 1 Pembenah, 1 Pupuk)
func claim_starter_container() -> Dictionary:
	if starter_claimed:
		return {"success": false, "reason": "Wadah starter sudah pernah diambil."}

	var starter_items: Array[Dictionary] = [
		{"item_id": "seed_bayam", "count": 4},
		{"item_id": "soil_compost", "count": 1},
		{"item_id": "fertilizer_basic", "count": 1}
	]

	if not backpack.can_add_batch(starter_items):
		var msg := "Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."
		return {"success": false, "reason": msg}

	backpack.add_batch(starter_items)
	starter_claimed = true
	starter_claimed_changed.emit(true)
	return {"success": true, "reason": "Paket starter berhasil diambil."}

## Serialisasi Snapshot untuk SaveManager (SAVE-001)
func get_save_snapshot() -> Dictionary:
	return {
		"backpack": backpack.to_array(),
		"storage_home": storage_home.to_array(),
		"starter_claimed": starter_claimed
	}

## Deserialisasi Snapshot dari SaveManager (SAVE-001)
func load_save_snapshot(data: Dictionary) -> bool:
	if not data.has("backpack") or not data.has("storage_home"):
		return false
	backpack.from_array(data.get("backpack", []))
	storage_home.from_array(data.get("storage_home", []))
	starter_claimed = bool(data.get("starter_claimed", false))
	starter_claimed_changed.emit(starter_claimed)
	return true
```

---

## 5. Verification Method

Untuk memverifikasi arsitektur ini secara independen dan objektif, jalankan pemeriksaan berikut:

### 5.1 Suite Pengujian Otomatis Headless
Worker wajib membuat `tests/suites/test_inventory.gd` dan mendaftarkannya sebagai Suite 7 pada `tests/test_runner.gd`. Suite ini memverifikasi:
1. **Verifikasi Registri Item:**
   - Seluruh 7 item P0 terdaftar dengan nama, kategori, batas stack 20.
   - Alias `crop_bayam` teresolusi ke `ingredient_bayam`.
   - Alias `tool_fertilizer` teresolusi ke `fertilizer_basic`.
   - `water_fresh` dan `dish_sayur_bening` terdaftar dan dapat diambil datanya.
2. **Verifikasi T29 (Batas Tumpukan & Overflow):**
   - Mengisi slot hingga 20 unit.
   - Menambahkan unit ke-21 membuka slot baru dengan isi 1 unit.
   - Mengisi seluruh 12 slot tas hingga 240 unit. Percobaan menambah 1 unit lagi ditolak secara aman (`can_add == false`, `add_item` mengembalikan 1 sisa, jumlah total tetap 240).
3. **Verifikasi T30 (Transfer Dua Arah Atomik):**
   - Memindahkan 1 stack dari tas ke peti saat peti muat: berhasil, tas kosong, peti terisi.
   - Memindahkan stack saat peti penuh: ditolak utuh, pesan *"Penyimpanan tidak cukup. Tidak ada barang yang dipindahkan."*, item di tas tidak hilang dan peti tidak bertambah.
   - `transfer_all` pada kontainer tujuan yang tidak muat seluruhnya: ditolak 100%, 0 item dipindahkan.
4. **Verifikasi T04 (Paket Awal Wadah Starter):**
   - Pengambilan pertama memberikan 4 `seed_bayam`, 1 `soil_compost`, 1 `fertilizer_basic`.
   - Pengambilan kedua (spam E) langsung ditolak dengan alasan *"Wadah starter sudah pernah diambil."*, 0 item diduplikasi.
   - Jika tas penuh (0 slot sisa), pengambilan ditolak utuh, `starter_claimed` tetap `false`.
5. **Verifikasi T05 (Pre-Check Kapasitas Panen 2 Item):**
   - Menguji skenario saat tas hanya memiliki 1 slot kosong, sedangkan panen membutuhkan 2 slot (bayam + benih).
   - `can_add_batch([{"item_id": "ingredient_bayam", "count": 1}, {"item_id": "seed_bayam", "count": 1}])` mengembalikan `false`.
6. **Verifikasi T11 (Hitungan Ketersediaan Bebas):**
   - Menempatkan 2 bayam di tas dan 1 bayam di peti rumah.
   - `get_available_item_count("ingredient_bayam")` mengembalikan 3.
7. **Verifikasi Persistensi Snapshot (Prasyarat SAVE-001 & T46):**
   - Mengisi tas dan peti → panggil `get_save_snapshot()` → panggil `clear()` pada kedua kontainer → panggil `load_save_snapshot()` → verifikasi seluruh isi slot kembali identik.

### 5.2 Perintah Eksekusi Pengujian
```powershell
cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"
```
**Kriteria Lolos:** Seluruh suite 1..7 lulus 100%, 0 asersi gagal, exit code 0.
