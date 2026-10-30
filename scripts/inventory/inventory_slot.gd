class_name InventorySlot
extends RefCounted

## Representasi satu slot inventaris (RefCounted)
## Menjamin invarian kapasitas 0..20 dan integritas state murni

var item_id: String = "":
	set(val):
		item_id = val.strip_edges()
		if item_id.is_empty() and count != 0:
			count = 0

var count: int = 0:
	set(val):
		count = max(0, val)
		if count == 0 and not item_id.is_empty():
			item_id = ""

# Alias id property untuk fleksibilitas pemanggilan
var id: String:
	get:
		return item_id
	set(val):
		item_id = val

func _init(p_item_id: String = "", p_count: int = 0) -> void:
	if p_count > 0 and not p_item_id.strip_edges().is_empty():
		item_id = p_item_id.strip_edges()
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
	var space: int = get_available_space(max_stack)
	var to_add: int = mini(amount, space)
	count += to_add
	return amount - to_add # return sisa yang tidak muat

func remove(amount: int) -> int:
	if amount <= 0 or is_empty():
		return 0
	var to_remove: int = mini(amount, count)
	count -= to_remove
	return to_remove

func clear() -> void:
	item_id = ""
	count = 0

func set_item(p_item_id: String, p_count: int) -> void:
	item_id = p_item_id.strip_edges()
	count = max(0, p_count)

func duplicate_slot() -> RefCounted:
	var slot_script = load("res://scripts/inventory/inventory_slot.gd")
	return slot_script.new(item_id, count)

func to_dict() -> Dictionary:
	return {
		"item_id": item_id,
		"id": item_id,
		"count": count
	}

func from_dict(d: Dictionary) -> void:
	var id_val: String = str(d.get("item_id", d.get("id", ""))).strip_edges()
	var count_val: int = int(d.get("count", 0))
	if count_val > 0 and not id_val.is_empty():
		item_id = id_val
		count = count_val
	else:
		clear()

static func create_from_dict(d: Dictionary) -> RefCounted:
	var slot_script = load("res://scripts/inventory/inventory_slot.gd")
	var slot = slot_script.new()
	slot.from_dict(d)
	return slot
