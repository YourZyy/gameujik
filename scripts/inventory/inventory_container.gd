class_name InventoryContainer
extends RefCounted

## Kontainer Penyimpanan Berkapasitas Tetap (12 slot untuk Tas & Peti)
## Menjamin atomisitas transaksi, pencegahan mutasi parsial, dan pelaporan error jujur

const InventorySlotClass = preload("res://scripts/inventory/inventory_slot.gd")

signal contents_changed()
signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)

var max_slots: int = 12
var default_stack_limit: int = 20
var slots: Array[RefCounted] = []

func _init(p_max_slots: int = 12, p_stack_limit: int = 20) -> void:
	max_slots = p_max_slots
	default_stack_limit = p_stack_limit
	clear()

func clear() -> void:
	slots.clear()
	for i in range(max_slots):
		slots.append(InventorySlotClass.new())
	contents_changed.emit()

func get_slot(index: int) -> RefCounted:
	if index >= 0 and index < slots.size():
		return slots[index]
	return null

func get_item_count(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if slot.get("item_id") == item_id:
			total += int(slot.get("count"))
	return total

func has_item(item_id: String, count: int = 1) -> bool:
	return get_item_count(item_id) >= count

func get_empty_slot_count() -> int:
	var empty := 0
	for slot in slots:
		if slot.has_method("is_empty") and slot.is_empty():
			empty += 1
	return empty

func get_used_slots_count() -> int:
	return max_slots - get_empty_slot_count()

func get_occupied_slot_count() -> int:
	return get_used_slots_count()

func get_slots() -> Array:
	return slots

func is_full() -> bool:
	for slot in slots:
		if slot.has_method("is_empty") and slot.is_empty():
			return false
		if int(slot.get("count")) < default_stack_limit:
			return false
	return true

## Normalisasi input items (baik berupa Array of Dictionary atau Dictionary {id: count})
func _normalize_items_input(items: Variant) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	if items is Array:
		for it in items:
			if it is Dictionary:
				var id_val: String = str(it.get("item_id", it.get("id", ""))).strip_edges()
				var cnt_val: int = int(it.get("count", 0))
				if not id_val.is_empty() and cnt_val > 0:
					normalized.append({"item_id": id_val, "id": id_val, "count": cnt_val})
	elif items is Dictionary:
		for k in items:
			var id_val: String = str(k).strip_edges()
			var cnt_val: int = int(items[k])
			if not id_val.is_empty() and cnt_val > 0:
				normalized.append({"item_id": id_val, "id": id_val, "count": cnt_val})
	return normalized

## Simulasi alokasi ruang untuk 1 jenis item
func can_add(item_id: String, amount: int) -> bool:
	return can_add_batch([{"item_id": item_id, "count": amount}])

## Simulasi alokasi ruang untuk banyak item sekaligus (Panen Bayam & Paket Starter)
## Menjamin kepastian T04 dan T05 sebelum mutasi
func can_add_batch(items: Variant) -> bool:
	var batch := _normalize_items_input(items)
	if batch.is_empty():
		return true

	# Salin state slot secara virtual untuk simulasi tanpa mutasi nyata
	var sim_slots: Array[Dictionary] = []
	for s in slots:
		sim_slots.append({"item_id": str(s.get("item_id")), "count": int(s.get("count"))})

	for item in batch:
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
	var id_clean := item_id.strip_edges()
	if amount <= 0 or id_clean.is_empty():
		return amount
	var remaining: int = amount

	# 1. Isi stack yang ada dahulu (indeks terkecil)
	for slot in slots:
		if slot.get("item_id") == id_clean and int(slot.get("count")) < default_stack_limit:
			remaining = slot.add(remaining, default_stack_limit)
			if remaining == 0:
				break

	# 2. Buka slot kosong baru
	if remaining > 0:
		for slot in slots:
			if slot.has_method("is_empty") and slot.is_empty():
				slot.set("item_id", id_clean)
				remaining = slot.add(remaining, default_stack_limit)
				if remaining == 0:
					break

	var added: int = amount - remaining
	if added > 0:
		item_added.emit(id_clean, added)
		contents_changed.emit()
	return remaining

## Menambahkan batch item secara atomik (semua masuk atau tidak ada perubahan)
func add_batch(items: Variant) -> bool:
	if not can_add_batch(items):
		return false
	var batch := _normalize_items_input(items)
	for it in batch:
		var id_val: String = it.get("item_id", "")
		var count_val: int = int(it.get("count", 0))
		add_item(id_val, count_val)
	return true

## Memeriksa ketersediaan penghapusan item tunggal
func can_remove(item_id: String, count: int) -> bool:
	return get_item_count(item_id) >= count

## Memeriksa ketersediaan penghapusan batch
func can_remove_batch(items: Variant) -> bool:
	var batch := _normalize_items_input(items)
	var req: Dictionary = {}
	for it in batch:
		var id_val: String = it.get("item_id", "")
		var count_val: int = int(it.get("count", 0))
		req[id_val] = req.get(id_val, 0) + count_val
	for id_val in req:
		if get_item_count(id_val) < req[id_val]:
			return false
	return true

## Menghapus item dari slot berindeks terkecil
func remove_item(item_id: String, amount: int) -> int:
	var id_clean := item_id.strip_edges()
	if amount <= 0 or id_clean.is_empty():
		return 0
	var remaining: int = amount
	for slot in slots:
		if slot.get("item_id") == id_clean:
			var removed: int = slot.remove(remaining)
			remaining -= removed
			if remaining == 0:
				break
	var total_removed: int = amount - remaining
	if total_removed > 0:
		item_removed.emit(id_clean, total_removed)
		contents_changed.emit()
	return total_removed

## Menghapus batch item secara atomik
func remove_batch(items: Variant) -> bool:
	if not can_remove_batch(items):
		return false
	var batch := _normalize_items_input(items)
	for it in batch:
		remove_item(it.get("item_id", ""), int(it.get("count", 0)))
	return true

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
			slots[i].from_dict(d)
	contents_changed.emit()
