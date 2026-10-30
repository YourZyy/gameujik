extends Node

## Autoload Singleton InventoryManager untuk Buku Resep 2045
## Mengelola Tas (12 slot), Peti Rumah (12 slot), Registri Item, Transaksi Atomik, dan Paket Wadah Awal
## Memenuhi spesifikasi PRD FR05/FR06, CONTENT.md § 2/3/5, PROTOTYPE.md § 6.1, UI_UX.md UI04, dan TEST_PLAN T02..T05, T29..T33

const ItemRegistryClass = preload("res://scripts/inventory/items_data.gd")
const InventoryContainerClass = preload("res://scripts/inventory/inventory_container.gd")
const ItemDataClass = preload("res://scripts/inventory/item_data.gd")

const CONTAINER_BACKPACK: String = "backpack"
const CONTAINER_STORAGE: String = "storage"
const CONTAINER_REFUND: String = "kitchen_refund"
const BACKPACK_SLOTS: int = 12
const STORAGE_SLOTS: int = 12
const MAX_STACK_SIZE: int = 20

signal inventory_changed(container_type: String)
signal inventory_updated()
signal item_transferred(item_id: String, count: int, from_container: String, to_container: String)
signal transaction_failed(reason: String)
signal item_added(item_id: String, count: int, container_type: String)
signal item_removed(item_id: String, count: int, container_type: String)
signal starter_collected(items: Array)
signal starter_claimed_changed(claimed: bool)

var item_registry: RefCounted = null
var backpack: RefCounted = null
var storage_home: RefCounted = null
var kitchen_refund: RefCounted = null

var starter_claimed: bool = false:
	set(val):
		starter_claimed = val
		starter_claimed_changed.emit(starter_claimed)

var storage: RefCounted:
	get:
		return storage_home

var _backpack: Array[Dictionary]:
	get:
		return backpack.to_array() if backpack != null else []

var _storage: Array[Dictionary]:
	get:
		return storage_home.to_array() if storage_home != null else []

var _reservations: Dictionary = {} # job_id -> Array[Dictionary]

func _ready() -> void:
	_init_containers()

func _init_containers() -> void:
	if item_registry == null:
		item_registry = ItemRegistryClass.new()
	backpack = InventoryContainerClass.new(BACKPACK_SLOTS, MAX_STACK_SIZE)
	storage_home = InventoryContainerClass.new(STORAGE_SLOTS, MAX_STACK_SIZE)
	kitchen_refund = InventoryContainerClass.new(STORAGE_SLOTS, MAX_STACK_SIZE)

	backpack.contents_changed.connect(func(): _on_container_contents_changed(CONTAINER_BACKPACK))
	storage_home.contents_changed.connect(func(): _on_container_contents_changed(CONTAINER_STORAGE))
	kitchen_refund.contents_changed.connect(func(): _on_container_contents_changed(CONTAINER_REFUND))

	backpack.item_added.connect(func(id: String, cnt: int): item_added.emit(id, cnt, CONTAINER_BACKPACK))
	backpack.item_removed.connect(func(id: String, cnt: int): item_removed.emit(id, cnt, CONTAINER_BACKPACK))
	storage_home.item_added.connect(func(id: String, cnt: int): item_added.emit(id, cnt, CONTAINER_STORAGE))
	storage_home.item_removed.connect(func(id: String, cnt: int): item_removed.emit(id, cnt, CONTAINER_STORAGE))

func _on_container_contents_changed(container_name: String) -> void:
	inventory_changed.emit(container_name)
	inventory_updated.emit()

func get_container(container_name: String) -> RefCounted:
	match container_name:
		"backpack", "tas":
			return backpack
		"storage", "storage_home", "peti":
			return storage_home
		"kitchen_refund", "refund":
			return kitchen_refund
		_:
			return null

func _resolve_container(c: Variant) -> RefCounted:
	if c is RefCounted:
		return c as RefCounted
	if c is String:
		return get_container(str(c))
	return null

func _resolve_container_name(c: Variant) -> String:
	if c is String:
		return str(c)
	if c == backpack:
		return CONTAINER_BACKPACK
	if c == storage_home:
		return CONTAINER_STORAGE
	if c == kitchen_refund:
		return CONTAINER_REFUND
	return "unknown"

func get_container_slots(container_name: String) -> Array[Dictionary]:
	var c := get_container(container_name)
	if c != null and c.has_method("to_array"):
		return c.to_array()
	return []

func get_item_data(item_id: String) -> Resource:
	if item_registry != null and item_registry.has_method("get_item"):
		return item_registry.get_item(item_id)
	return null

func resolve_id(item_id: String) -> String:
	if item_registry != null and item_registry.has_method("resolve_id"):
		return item_registry.resolve_id(item_id)
	return item_id

## Memeriksa apakah kontainer dapat menampung batch item
func can_accept_items(container_name: String, items: Variant) -> bool:
	var c := get_container(container_name)
	if c != null and c.has_method("can_add_batch"):
		return c.can_add_batch(items)
	return false

## Menambahkan batch item secara atomik ke kontainer
func add_items(container_name: String, items: Variant) -> bool:
	var c := get_container(container_name)
	if c == null or not c.has_method("add_batch"):
		return false
	var ok: bool = c.add_batch(items)
	if not ok:
		transaction_failed.emit("Kapasitas penyimpanan tidak cukup.")
	return ok

## Menghapus batch item secara atomik dari kontainer
func remove_items(container_name: String, items: Variant) -> bool:
	var c := get_container(container_name)
	if c == null or not c.has_method("remove_batch"):
		return false
	var ok: bool = c.remove_batch(items)
	if not ok:
		transaction_failed.emit("Item tidak mencukupi untuk dihapus.")
	return ok

## Transfer 1 jenis item sejumlah count dari slot spesifik (atomik 2-arah, T03)
func transfer_item(from_c: Variant, to_c: Variant, slot_idx: int, count: int) -> bool:
	var src := _resolve_container(from_c)
	var dst := _resolve_container(to_c)
	if src == null or dst == null:
		transaction_failed.emit("Kontainer tidak valid.")
		return false

	var slot = src.get_slot(slot_idx)
	if slot == null or slot.is_empty():
		transaction_failed.emit("Slot asal kosong.")
		return false

	var item_id: String = slot.item_id
	var available: int = slot.count
	var to_transfer: int = mini(count, available)
	if to_transfer <= 0:
		return false

	# Periksa apakah tujuan muat seluruh unit yang ingin dipindahkan
	if not dst.can_add(item_id, to_transfer):
		var msg := "Penyimpanan tidak cukup. Tidak ada barang yang dipindahkan."
		transaction_failed.emit(msg)
		return false

	# Eksekusi atomik
	var removed: int = slot.remove(to_transfer)
	dst.add_item(item_id, removed)
	src.contents_changed.emit()

	var from_name := _resolve_container_name(from_c)
	var to_name := _resolve_container_name(to_c)
	item_transferred.emit(item_id, removed, from_name, to_name)
	return true

## Transfer 1 stack penuh dari slot (T30: ditolak utuh jika tidak muat seluruhnya)
func transfer_slot(from_c: Variant, to_c: Variant, slot_idx: int) -> Dictionary:
	var src := _resolve_container(from_c)
	var dst := _resolve_container(to_c)
	if src == null or dst == null:
		return {"success": false, "reason": "Kontainer tidak valid."}

	var slot = src.get_slot(slot_idx)
	if slot == null or slot.is_empty():
		return {"success": false, "reason": "Slot kosong."}

	var item_id: String = slot.item_id
	var count: int = slot.count

	if not dst.can_add(item_id, count):
		var msg := "Penyimpanan tidak cukup. Tidak ada barang yang dipindahkan."
		transaction_failed.emit(msg)
		return {"success": false, "reason": msg}

	# Eksekusi atomik: kosongkan slot asal dan tambahkan ke tujuan
	slot.clear()
	src.contents_changed.emit()
	dst.add_item(item_id, count)

	var from_name := _resolve_container_name(from_c)
	var to_name := _resolve_container_name(to_c)
	item_transferred.emit(item_id, count, from_name, to_name)
	return {"success": true, "reason": "Barang berhasil dipindahkan."}

## Transfer seluruh isi kontainer asal ke kontainer tujuan (T30)
func transfer_all(from_c: Variant, to_c: Variant, filter_item_id: String = "") -> Dictionary:
	var src := _resolve_container(from_c)
	var dst := _resolve_container(to_c)
	if src == null or dst == null:
		return {"success": false, "reason": "Kontainer tidak valid."}

	var batch: Array[Dictionary] = []
	for s in src.slots:
		if not s.is_empty():
			if filter_item_id.is_empty() or s.item_id == filter_item_id:
				batch.append({"item_id": s.item_id, "id": s.item_id, "count": s.count})

	if batch.is_empty():
		return {"success": false, "reason": "Kontainer asal kosong."}

	# Periksa kapasitas tujuan untuk seluruh batch (dry-run)
	if not dst.can_add_batch(batch):
		var msg := "Penyimpanan tidak cukup. Tidak ada barang yang dipindahkan."
		transaction_failed.emit(msg)
		return {"success": false, "reason": msg}

	# Eksekusi atomik pemindahan seluruh batch
	for it in batch:
		var it_id: String = str(it["item_id"])
		var it_cnt: int = int(it["count"])
		src.remove_item(it_id, it_cnt)
		dst.add_item(it_id, it_cnt)

	var from_name := _resolve_container_name(from_c)
	var to_name := _resolve_container_name(to_c)
	item_transferred.emit(filter_item_id if not filter_item_id.is_empty() else "all", batch.size(), from_name, to_name)
	return {"success": true, "reason": "Semua barang berhasil dipindahkan."}

## Pengambilan Wadah Awal di Pekarangan (T04: 4 Benih, 1 Pembenah, 1 Pupuk)
func pickup_starter_container() -> bool:
	if starter_claimed:
		transaction_failed.emit("Wadah starter sudah pernah diambil.")
		return false

	var starter_items: Array[Dictionary] = [
		{"item_id": "seed_bayam", "id": "seed_bayam", "count": 4},
		{"item_id": "soil_compost", "id": "soil_compost", "count": 1},
		{"item_id": "fertilizer_basic", "id": "fertilizer_basic", "count": 1}
	]

	# Periksa kapasitas tas (T31: jika tas kekurangan ruang, tolak bersih)
	if not backpack.can_add_batch(starter_items):
		var msg := "Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."
		transaction_failed.emit(msg)
		return false

	# Commit atomik
	backpack.add_batch(starter_items)
	starter_claimed = true
	starter_collected.emit(starter_items)
	return true

func claim_starter_container() -> Dictionary:
	var ok: bool = pickup_starter_container()
	if ok:
		return {"success": true, "reason": "Paket starter berhasil diambil."}
	return {"success": false, "reason": "Wadah starter sudah pernah diambil." if starter_claimed else "Tas tidak cukup."}

func collect_starter_container() -> bool:
	return pickup_starter_container()

func is_starter_collected() -> bool:
	return starter_claimed

## Agregat stok bahan bebas (Tas + Peti Rumah dikurangi reservasi memasak) untuk RecipeManager (T02, T31)
func get_available_item_count(item_id: String) -> int:
	var canonical_id := resolve_id(item_id)
	var total: int = backpack.get_item_count(canonical_id) + storage_home.get_item_count(canonical_id)

	# Kurangi reservasi memasak yang sedang berlangsung
	for job_id in _reservations:
		var res_list: Array = _reservations[job_id]
		for r_item in res_list:
			if r_item is Dictionary:
				var r_id: String = resolve_id(str(r_item.get("item_id", r_item.get("id", ""))))
				if r_id == canonical_id:
					total -= int(r_item.get("count", 0))

	return max(0, total)

## Validator kapasitas panen (T05: mengecek apakah tas muat hasil panen, default 1 bayam + 1 benih)
func can_harvest(crop_items: Variant = null) -> bool:
	if crop_items == null:
		var default_harvest: Array[Dictionary] = [
			{"item_id": "ingredient_bayam", "id": "ingredient_bayam", "count": 1},
			{"item_id": "seed_bayam", "id": "seed_bayam", "count": 1}
		]
		return backpack.can_add_batch(default_harvest)
	return backpack.can_add_batch(crop_items)

## Kontrak Reservasi Dapur (COOK-001)
func reserve_ingredients(job_id: String, items: Array[Dictionary]) -> Dictionary:
	if _reservations.has(job_id):
		return {"success": false, "reason": "Job ID sudah aktif."}

	# Periksa apakah total stok bebas cukup
	for it in items:
		var it_id: String = resolve_id(str(it.get("item_id", it.get("id", ""))))
		var count_needed: int = int(it.get("count", 0))
		if get_available_item_count(it_id) < count_needed:
			return {"success": false, "reason": "Bahan tidak mencukupi untuk reservasi."}

	_reservations[job_id] = items.duplicate(true)
	inventory_updated.emit()
	return {"success": true, "reason": "Bahan berhasil direservasi."}

func cancel_reservation(job_id: String) -> bool:
	if not _reservations.has(job_id):
		return false
	_reservations.erase(job_id)
	inventory_updated.emit()
	return true

func commit_consumption(job_id: String) -> void:
	if not _reservations.has(job_id):
		return
	var items: Array = _reservations[job_id]
	for it in items:
		if it is Dictionary:
			var it_id: String = resolve_id(str(it.get("item_id", it.get("id", ""))))
			var count_to_consume: int = int(it.get("count", 0))
			# Konsumsi dari tas dahulu, sisanya dari peti
			var from_bp: int = mini(count_to_consume, backpack.get_item_count(it_id))
			if from_bp > 0:
				backpack.remove_item(it_id, from_bp)
				count_to_consume -= from_bp
			if count_to_consume > 0:
				storage_home.remove_item(it_id, count_to_consume)
	_reservations.erase(job_id)
	inventory_updated.emit()

## Serialisasi Snapshot untuk SaveManager (SAVE-001)
func get_save_snapshot() -> Dictionary:
	return {
		"backpack": backpack.to_array(),
		"storage_home": storage_home.to_array(),
		"kitchen_refund": kitchen_refund.to_array(),
		"starter_claimed": starter_claimed,
		"starter_collected": starter_claimed
	}

## Deserialisasi Snapshot dari SaveManager (SAVE-001)
func load_save_snapshot(data: Dictionary) -> bool:
	if not data.has("backpack") or not data.has("storage_home"):
		return false
	backpack.from_array(data.get("backpack", []))
	storage_home.from_array(data.get("storage_home", []))
	if data.has("kitchen_refund"):
		kitchen_refund.from_array(data.get("kitchen_refund", []))
	starter_claimed = bool(data.get("starter_claimed", data.get("starter_collected", false)))
	inventory_updated.emit()
	return true
