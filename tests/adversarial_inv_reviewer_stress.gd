extends SceneTree

## Reviewer Adversarial Stress Test Suite for INV-001
## Tests invariants, edge cases, corruption recovery, and atomicity

const ItemDataClass = preload("res://scripts/inventory/item_data.gd")
const ItemsDataClass = preload("res://scripts/inventory/items_data.gd")
const InventorySlotClass = preload("res://scripts/inventory/inventory_slot.gd")
const InventoryContainerClass = preload("res://scripts/inventory/inventory_container.gd")
const InventoryManagerScript = preload("res://scripts/inventory/inventory_manager.gd")

var total_asserts := 0
var passed_asserts := 0
var failed_asserts := 0

func _initialize() -> void:
	print("==================================================")
	print("[REVIEWER_ADVERSARIAL] Running INV-001 Invariant & Integrity Suite...")
	print("==================================================")

	test_item_data_serialization_and_tampering()
	test_inventory_slot_invariants_and_recursion()
	test_inventory_container_invariants_12_slots_20_stack()
	test_atomic_transfer_two_phase_integrity()
	test_split_cooking_reservation_and_consumption()
	test_save_snapshot_roundtrip_and_corruption_recovery()
	test_starter_pickup_atomic_and_idempotence()

	print("==================================================")
	print("[REVIEWER_ADVERSARIAL] SUMMARY:")
	print("  Total Assertions:  %d" % total_asserts)
	print("  Passed Assertions: %d" % passed_asserts)
	print("  Failed Assertions: %d" % failed_asserts)
	if failed_asserts == 0:
		print("  VERDICT: ALL ADVERSARIAL REVIEWER TESTS PASSED (Exit Code: 0)")
	else:
		print("  VERDICT: ADVERSARIAL FAILURES ENCOUNTERED (Exit Code: 1)")
	print("==================================================")

	quit(1 if failed_asserts > 0 else 0)

func check(cond: bool, msg: String) -> void:
	total_asserts += 1
	if cond:
		passed_asserts += 1
	else:
		failed_asserts += 1
		printerr("  [FAIL] ", msg)

func test_item_data_serialization_and_tampering() -> void:
	print("\n--- Test 1: ItemData Serialization & Deserialization ---")
	var item = ItemDataClass.new(
		"ingredient_bayam",
		"Sayur Bayam",
		"bahan",
		20,
		"Daun bayam segar.",
		null,
		Color(0.2, 0.7, 0.2)
	)

	var d: Dictionary = item.to_dict()
	check(d["id"] == "ingredient_bayam", "ItemData dict id match")
	check(d["max_stack"] == 20, "ItemData dict max_stack match")
	check(d["name"] == "Sayur Bayam", "ItemData dict name match")

	# Roundtrip
	var restored = ItemDataClass.from_dict(d)
	check(restored != null, "from_dict restored resource")
	check(restored.id == item.id, "Restored id matches")
	check(restored.display_name == item.display_name, "Restored display_name matches")
	check(restored.name == item.name, "Restored name property matches")
	check(restored.category == item.category, "Restored category matches")
	check(restored.max_stack == 20, "Restored max_stack matches")
	check(restored.description == item.description, "Restored description matches")
	print("DEBUG: Orig Color: ", item.icon_color, " Hex: ", d.get("icon_color"), " Restored: ", restored.icon_color)
	var col_diff: float = abs(restored.icon_color.r - item.icon_color.r) + abs(restored.icon_color.g - item.icon_color.g) + abs(restored.icon_color.b - item.icon_color.b)
	check(col_diff < 0.01, "Restored icon_color matches within 8-bit quantization tolerance")

	# Missing / corrupted dictionary keys
	var empty_dict: Dictionary = {}
	var fallback_item = ItemDataClass.from_dict(empty_dict)
	check(fallback_item != null, "from_dict with empty dict survives")
	check(fallback_item.id == "", "Empty dict yields empty id")
	check(fallback_item.max_stack == 20, "Empty dict defaults to max_stack 20")

	# JSON-like float numbers (as happens in Godot JSON parser)
	var json_dict: Dictionary = {
		"id": "seed_bayam",
		"name": "Benih Bayam",
		"max_stack": 20.0, # Float representation in JSON
		"category": "benih"
	}
	var from_json = ItemDataClass.from_dict(json_dict)
	check(from_json.max_stack == 20, "Float max_stack properly cast to int 20")

func test_inventory_slot_invariants_and_recursion() -> void:
	print("\n--- Test 2: InventorySlot Invariants & Setter Anti-Recursion ---")
	var slot = InventorySlotClass.new()
	check(slot.is_empty(), "Fresh slot is empty")
	check(slot.count == 0, "Fresh slot count is 0")
	check(slot.item_id == "", "Fresh slot item_id is empty")

	# Setting item_id to allocate slot for seed_bayam
	slot.item_id = "seed_bayam"
	check(slot.is_empty(), "Slot with count 0 is still empty even if item_id set")

	# Adding items
	var overflow = slot.add(15, 20)
	check(overflow == 0, "Adding 15 into empty slot (max 20) has 0 overflow")
	check(slot.count == 15, "Slot count is 15")
	check(not slot.is_empty(), "Slot is not empty")

	# Adding more up to and beyond 20
	overflow = slot.add(10, 20)
	check(overflow == 5, "Adding 10 when 5 space left gives 5 overflow")
	check(slot.count == 20, "Slot count is capped at 20")

	# Available space calculation
	check(slot.get_available_space(20) == 0, "Full slot has 0 available space")

	# Removing items
	var removed = slot.remove(7)
	check(removed == 7, "Removed 7 items")
	check(slot.count == 13, "Slot has 13 remaining")
	check(slot.get_available_space(20) == 7, "7 space now available")

	# Removing all items -> auto clears item_id
	slot.remove(13)
	check(slot.count == 0, "Count is 0 after removing all")
	check(slot.item_id == "", "item_id auto-cleared when count reaches 0")
	check(slot.is_empty(), "Slot is now empty")

	# Setter recursion guard test
	slot.item_id = "test_item"
	slot.count = 5
	slot.item_id = "" # should reset count to 0 without stack overflow
	check(slot.count == 0, "Setting item_id to empty resets count to 0")

	slot.item_id = "test_item"
	slot.count = 0 # should reset item_id to empty without stack overflow
	check(slot.item_id == "", "Setting count to 0 resets item_id to empty")

	# Dictionary serialization round-trip
	slot.item_id = "soil_compost"
	slot.count = 8
	var slot_dict = slot.to_dict()
	check(slot_dict["item_id"] == "soil_compost", "to_dict item_id matches")
	check(slot_dict["count"] == 8, "to_dict count matches")

	var slot2 = InventorySlotClass.create_from_dict(slot_dict)
	check(slot2.item_id == "soil_compost", "create_from_dict item_id matches")
	check(slot2.count == 8, "create_from_dict count matches")

func test_inventory_container_invariants_12_slots_20_stack() -> void:
	print("\n--- Test 3: InventoryContainer Invariants (12 Slots, 20 Max Stack) ---")
	var container = InventoryContainerClass.new(12, 20)
	check(container.max_slots == 12, "Container max_slots strictly 12")
	check(container.default_stack_limit == 20, "Container default_stack_limit strictly 20")
	check(container.slots.size() == 12, "Container slots array size strictly 12")
	check(container.get_empty_slot_count() == 12, "All 12 slots initially empty")
	check(not container.is_full(), "Container initially not full")

	# Fill container with 12 distinct items x 20
	for i in range(12):
		var it := "item_%02d" % i
		var rem: int = container.add_item(it, 20)
		check(rem == 0, "Item %s added with 0 remainder" % it)

	check(container.is_full(), "Container is full with 12x20 items")
	check(container.get_empty_slot_count() == 0, "0 empty slots remaining")

	# Attempt to add any additional item
	var over: int = container.add_item("item_extra", 1)
	check(over == 1, "Adding to full container returns 1 remainder (rejected)")
	check(not container.can_add("item_extra", 1), "can_add returns false for 13th item")

	# Attempt to add batch to full container
	var batch_ok: bool = container.add_batch([{"item_id": "seed_bayam", "count": 1}])
	check(not batch_ok, "add_batch returns false on full container")

	# Verify slot bounds: get_slot(-1) and get_slot(12) return null safely
	check(container.get_slot(-1) == null, "get_slot(-1) is null")
	check(container.get_slot(12) == null, "get_slot(12) is null")

	# from_array with larger array (e.g. 15 items) must be truncated to 12
	var big_data: Array = []
	for i in range(15):
		big_data.append({"item_id": "big_%d" % i, "count": 5})
	container.from_array(big_data)
	check(container.slots.size() == 12, "from_array caps slots array strictly to 12")
	check(container.get_item_count("big_11") == 5, "Slot 11 loaded")
	check(container.get_item_count("big_12") == 0, "Slot 12+ discarded")

func test_atomic_transfer_two_phase_integrity() -> void:
	print("\n--- Test 4: Two-Phase Atomic Transfer Integrity (T03, T30) ---")
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# Scenario: Target container has partial room (e.g. room for 2 items)
	# Transferring 5 items MUST reject 100%, without moving 2 and leaving 3
	inv.storage_home.clear()
	inv.storage_home.add_item("ingredient_jagung", 18) # slot 0 has 18 jagung, space for 2
	for i in range(1, 12):
		inv.storage_home.add_item("other_%d" % i, 20) # slots 1..11 completely full

	check(inv.storage_home.get_empty_slot_count() == 0, "Storage has 0 empty slots")
	check(inv.storage_home.get_item_count("ingredient_jagung") == 18, "Storage has 18 jagung")

	# Put 5 jagung in backpack
	inv.backpack.clear()
	inv.backpack.add_item("ingredient_jagung", 5)
	check(inv.backpack.get_item_count("ingredient_jagung") == 5, "Backpack has 5 jagung")

	# 1. transfer_item for 5 units (space is only 2)
	var ok_transfer: bool = inv.transfer_item("backpack", "storage", 0, 5)
	check(not ok_transfer, "transfer_item for 5 units rejected when space is 2")
	check(inv.backpack.get_item_count("ingredient_jagung") == 5, "Backpack jagung unchanged at 5")
	check(inv.storage_home.get_item_count("ingredient_jagung") == 18, "Storage jagung unchanged at 18")

	# 2. transfer_slot (which has 5 units)
	var res_slot: Dictionary = inv.transfer_slot("backpack", "storage", 0)
	check(not res_slot.get("success", false), "transfer_slot rejected when space is 2")
	check(inv.backpack.get_item_count("ingredient_jagung") == 5, "Backpack jagung unchanged at 5")
	check(inv.storage_home.get_item_count("ingredient_jagung") == 18, "Storage jagung unchanged at 18")

	# 3. transfer_all
	var res_all: Dictionary = inv.transfer_all("backpack", "storage")
	check(not res_all.get("success", false), "transfer_all rejected when space is 2")
	check(inv.backpack.get_item_count("ingredient_jagung") == 5, "Backpack jagung unchanged at 5")
	check(inv.storage_home.get_item_count("ingredient_jagung") == 18, "Storage jagung unchanged at 18")

	# 4. Now transfer EXACTLY 2 units (which fits)
	var ok_fit: bool = inv.transfer_item("backpack", "storage", 0, 2)
	check(ok_fit, "transfer_item for exactly 2 units succeeds")
	check(inv.backpack.get_item_count("ingredient_jagung") == 3, "Backpack has 3 jagung remaining")
	check(inv.storage_home.get_item_count("ingredient_jagung") == 20, "Storage slot 0 is now full (20)")

	# Now storage is 100% full, transfer of 1 unit must fail
	var ok_full: bool = inv.transfer_item("backpack", "storage", 0, 1)
	check(not ok_full, "Transfer of 1 unit to 100% full storage rejected")
	check(inv.backpack.get_item_count("ingredient_jagung") == 3, "Backpack jagung unchanged at 3")

	inv.free()

func test_split_cooking_reservation_and_consumption() -> void:
	print("\n--- Test 5: Split Cooking Reservation & Multi-Container Consumption ---")
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# Recipe: 3 bayam, 1 jagung, 1 temu kunci
	# Setup split inventory:
	# Bayam: 2 in backpack, 1 in storage (total 3)
	# Jagung: 1 in storage
	# Temu kunci: 1 in backpack
	inv.backpack.clear()
	inv.storage_home.clear()

	inv.backpack.add_item("ingredient_bayam", 2)
	inv.storage_home.add_item("ingredient_bayam", 1)
	inv.storage_home.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	# Verify aggregated free stock
	check(inv.get_available_item_count("ingredient_bayam") == 3, "Split bayam aggregated to 3")
	check(inv.get_available_item_count("ingredient_jagung") == 1, "Storage jagung aggregated to 1")
	check(inv.get_available_item_count("ingredient_temu_kunci") == 1, "Backpack temu kunci aggregated to 1")

	# Reserve ingredients
	var recipe_req: Array[Dictionary] = [
		{"item_id": "ingredient_bayam", "count": 3},
		{"item_id": "ingredient_jagung", "count": 1},
		{"item_id": "ingredient_temu_kunci", "count": 1}
	]
	var res: Dictionary = inv.reserve_ingredients("cook_job_split", recipe_req)
	check(res.get("success", false), "Split ingredient reservation succeeded")

	# Free counts are now 0
	check(inv.get_available_item_count("ingredient_bayam") == 0, "Bayam free count is 0 under reservation")
	check(inv.get_available_item_count("ingredient_jagung") == 0, "Jagung free count is 0 under reservation")
	check(inv.get_available_item_count("ingredient_temu_kunci") == 0, "Temu kunci free count is 0 under reservation")

	# Commit consumption: should consume 2 bayam from backpack, 1 bayam from storage, 1 jagung from storage, 1 temu from backpack
	inv.commit_consumption("cook_job_split")
	check(inv.backpack.get_item_count("ingredient_bayam") == 0, "Backpack bayam consumed to 0")
	check(inv.storage_home.get_item_count("ingredient_bayam") == 0, "Storage bayam consumed to 0")
	check(inv.storage_home.get_item_count("ingredient_jagung") == 0, "Storage jagung consumed to 0")
	check(inv.backpack.get_item_count("ingredient_temu_kunci") == 0, "Backpack temu kunci consumed to 0")
	check(inv.get_available_item_count("ingredient_bayam") == 0, "Bayam available count remains 0 after consumption")

	inv.free()

func test_save_snapshot_roundtrip_and_corruption_recovery() -> void:
	print("\n--- Test 6: Save Snapshot Roundtrip & Corruption Recovery (SAVE-001) ---")
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	inv.backpack.clear()
	inv.storage_home.clear()
	inv.backpack.add_item("seed_bayam", 7)
	inv.storage_home.add_item("dish_sayur_bening", 2)
	inv.starter_claimed = true

	var snap: Dictionary = inv.get_save_snapshot()
	check(snap.has("backpack"), "Snapshot has backpack")
	check(snap.has("storage_home"), "Snapshot has storage_home")
	check(snap.has("starter_claimed"), "Snapshot has starter_claimed")
	check(snap["starter_claimed"] == true, "starter_claimed is true in snapshot")

	# Reset and reload
	var inv2: Node = InventoryManagerScript.new()
	inv2._ready()
	var ok_load: bool = inv2.load_save_snapshot(snap)
	check(ok_load, "load_save_snapshot returns true")
	check(inv2.backpack.get_item_count("seed_bayam") == 7, "Loaded backpack has 7 seeds")
	check(inv2.storage_home.get_item_count("dish_sayur_bening") == 2, "Loaded storage has 2 dishes")
	check(inv2.is_starter_collected() == true, "Loaded starter_collected flag is true")

	# Corrupted data handling
	var bad_data: Dictionary = {"some_other_key": 123}
	var fail_load: bool = inv2.load_save_snapshot(bad_data)
	check(not fail_load, "load_save_snapshot gracefully returns false on missing keys")

	inv.free()
	inv2.free()

func test_starter_pickup_atomic_and_idempotence() -> void:
	print("\n--- Test 7: Starter Pickup Atomicity and Idempotence ---")
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# 1. Successful pickup
	var ok: bool = inv.pickup_starter_container()
	check(ok, "Initial starter pickup succeeds")
	check(inv.is_starter_collected(), "Starter flag is true")

	# 2. Second pickup attempt (spam)
	var ok_repeat: bool = inv.pickup_starter_container()
	check(not ok_repeat, "Repeat starter pickup rejected cleanly")

	# 3. Third pickup attempt via claim_starter_container()
	var res_claim: Dictionary = inv.claim_starter_container()
	check(not res_claim.get("success", false), "claim_starter_container rejected")
	check(res_claim.get("reason", "").contains("sudah pernah"), "Honest error reason provided")

	inv.free()
