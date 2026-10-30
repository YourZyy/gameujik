extends SceneTree

# ==============================================================================
# EMPIRICAL STRESS TEST HARNESS: INV-001 INVENTORY ATOMICITY & INVARIANTS
# ==============================================================================
# Agent: challenger_inv_001_1 (teamwork_challenger)
# Target: Two-way atomic transfer mechanics, container limits (12 slots),
#         stack invariants (max 20), conservation of items, and anti-spam.
# Executed via: godot_console --headless --script res://.agents/teamwork/challenger_inv_001_1/stress_transfer.gd
# ==============================================================================

const InventoryManagerScript = preload("res://scripts/inventory/inventory_manager.gd")
const InventoryContainerClass = preload("res://scripts/inventory/inventory_container.gd")
const InventorySlotClass = preload("res://scripts/inventory/inventory_slot.gd")
const ItemsDataClass = preload("res://scripts/inventory/items_data.gd")

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var failure_log: Array[String] = []

func _init() -> void:
	print("==================================================================")
	print("[EMPIRICAL_CHALLENGER] Starting INV-001 Inventory Stress Harness...")
	print("==================================================================")
	call_deferred("_run_harness")

func assert_true(condition: bool, description: String) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
	else:
		failed_assertions += 1
		var msg = "  [FAIL] %s" % description
		failure_log.append(msg)
		printerr(msg)

func assert_false(condition: bool, description: String) -> void:
	assert_true(not condition, description)

func assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	total_assertions += 1
	if actual == expected:
		passed_assertions += 1
	else:
		failed_assertions += 1
		var msg = "  [FAIL] %s (Expected: %s, Got: %s)" % [description, str(expected), str(actual)]
		failure_log.append(msg)
		printerr(msg)

func assert_not_null(val: Variant, description: String) -> void:
	assert_true(val != null, description)

func _run_harness() -> void:
	print("\n--- SECTION 1: Atomic All-or-Nothing Transfer Stress ---")
	test_atomic_all_or_nothing()

	print("\n--- SECTION 2: Slot Capacity Invariant (<= 12 Slots) ---")
	test_slot_capacity_invariant()

	print("\n--- SECTION 3: Stack Maximum Invariant (<= 20 Units per Slot) ---")
	test_stack_max_invariant()

	print("\n--- SECTION 4: Rapid Two-Way Stress (300 Iterations Conservation) ---")
	test_rapid_two_way_stress(300)

	print("\n--- SECTION 5: Heterogeneous Multi-Item Batch Atomicity ---")
	test_multi_item_batch_atomicity()

	print("\n--- SECTION 6: Edge Cases, Boundary Inputs & Self-Transfer ---")
	test_edge_cases_and_boundaries()

	print("\n--- SECTION 7: Starter Crate Capacity & Anti-Spam Invariants ---")
	test_starter_crate_invariants()

	print("\n--- SECTION 8: Maximum Dual Saturation Stress (240 + 240 = 480 Units) ---")
	test_maximum_dual_saturation_stress()

	print("\n--- SECTION 9: Kitchen Reservation Decoupling & Transfer Stress ---")
	test_kitchen_reservation_interaction()

	print("\n--- SECTION 10: Snapshot Round-Trip Restoration Oracle ---")
	test_snapshot_roundtrip_oracle()

	_print_summary()

# ==============================================================================
# SECTION 1: Atomic All-or-Nothing Transfer
# ==============================================================================
# Specification: Fill chest with 11 full stacks (20 items each) and 1 partial
# stack (19 items). Attempt to transfer 2 items from backpack to chest.
# Verify transfer is 100% REJECTED; backpack keeps 2 items, chest keeps 19 items
# (zero items transferred, zero items lost, zero items duplicated).
# ==============================================================================
func test_atomic_all_or_nothing() -> void:
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# Fill chest with 11 full stacks of unique items (20 each = 220 items)
	for i in range(11):
		var filler_id := "chest_filler_%02d" % i
		inv.add_items("storage", [{"item_id": filler_id, "count": 20}])

	# Add 1 partial stack of 19 seed_bayam to chest (slot 11)
	inv.add_items("storage", [{"item_id": "seed_bayam", "count": 19}])

	# Verify chest state: 11 full stacks (20) + 1 partial stack (19) = 239 items total
	assert_equal(inv.storage_home.slots.size(), 12, "Chest must have exactly 12 slots")
	assert_equal(inv.storage_home.get_empty_slot_count(), 0, "Chest must have 0 empty slots")
	assert_equal(inv.storage_home.get_item_count("seed_bayam"), 19, "Chest must have exactly 19 seed_bayam")
	var chest_total_initial: int = 0
	for s in inv.storage_home.slots:
		chest_total_initial += int(s.count)
	assert_equal(chest_total_initial, 239, "Chest initial item total must be 239 (11*20 + 19)")

	# Fill backpack slot 0 with 2 seed_bayam
	inv.add_items("backpack", [{"item_id": "seed_bayam", "count": 2}])
	assert_equal(inv.backpack.get_item_count("seed_bayam"), 2, "Backpack must have exactly 2 seed_bayam")
	assert_equal(inv.get_available_item_count("seed_bayam"), 21, "Combined available seed_bayam = 19 + 2 = 21")

	# ATTEMPT 1: transfer_item(from=backpack, to=storage, slot_idx=0, count=2)
	# Target can only accept 1 unit (19 -> 20). It cannot accept 2 units.
	# Must be 100% REJECTED!
	var transfer_ok: bool = inv.transfer_item("backpack", "storage", 0, 2)
	assert_false(transfer_ok, "transfer_item of 2 units into chest with only 1 unit space must fail")
	assert_equal(inv.backpack.get_item_count("seed_bayam"), 2, "Backpack MUST retain all 2 seed_bayam (no partial transfer)")
	assert_equal(inv.storage_home.get_item_count("seed_bayam"), 19, "Chest MUST retain 19 seed_bayam (no partial mutation)")
	assert_equal(inv.get_available_item_count("seed_bayam"), 21, "Combined available seed_bayam must strictly remain 21")

	# ATTEMPT 2: transfer_slot(from=backpack, to=storage, slot_idx=0)
	var transfer_slot_res: Dictionary = inv.transfer_slot("backpack", "storage", 0)
	assert_false(transfer_slot_res.get("success", false), "transfer_slot must return success: false")
	assert_equal(inv.backpack.get_item_count("seed_bayam"), 2, "Backpack retains 2 items after transfer_slot rejection")
	assert_equal(inv.storage_home.get_item_count("seed_bayam"), 19, "Chest retains 19 items after transfer_slot rejection")

	# ATTEMPT 3: transfer_all(from=backpack, to=storage)
	var transfer_all_res: Dictionary = inv.transfer_all("backpack", "storage")
	assert_false(transfer_all_res.get("success", false), "transfer_all must return success: false")
	assert_equal(inv.backpack.get_item_count("seed_bayam"), 2, "Backpack retains 2 items after transfer_all rejection")
	assert_equal(inv.storage_home.get_item_count("seed_bayam"), 19, "Chest retains 19 items after transfer_all rejection")

	# ATTEMPT 4: Transfer exactly 1 unit (which fits in the partial stack) -> MUST SUCCEED
	var transfer_1_ok: bool = inv.transfer_item("backpack", "storage", 0, 1)
	assert_true(transfer_1_ok, "transfer_item of 1 unit fitting remaining space must succeed")
	assert_equal(inv.backpack.get_item_count("seed_bayam"), 1, "Backpack now has 1 seed_bayam left")
	assert_equal(inv.storage_home.get_item_count("seed_bayam"), 20, "Chest partial stack is now maxed out at 20")
	assert_equal(inv.get_available_item_count("seed_bayam"), 21, "Combined available items strictly conserved at 21")
	assert_true(inv.storage_home.is_full(), "Chest is now 100% full (12 x 20 = 240 items)")

	# ATTEMPT 5: Now attempt to transfer the remaining 1 item to the full chest -> MUST FAIL
	var transfer_overflow_ok: bool = inv.transfer_item("backpack", "storage", 0, 1)
	assert_false(transfer_overflow_ok, "transfer_item to completely full chest must fail")
	assert_equal(inv.backpack.get_item_count("seed_bayam"), 1, "Backpack still has 1 seed_bayam")
	assert_equal(inv.storage_home.get_item_count("seed_bayam"), 20, "Chest still has 20 seed_bayam")

	inv.free()
	print("  [PASS] Section 1: Atomic all-or-nothing transfer verified.")

# ==============================================================================
# SECTION 2: Slot Capacity Invariant (Neither container exceeds 12 slots)
# ==============================================================================
func test_slot_capacity_invariant() -> void:
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# 1. Direct inspection of slot arrays
	assert_equal(inv.backpack.slots.size(), 12, "Backpack slots size must be 12")
	assert_equal(inv.storage_home.slots.size(), 12, "Storage slots size must be 12")
	assert_equal(inv.kitchen_refund.slots.size(), 12, "Kitchen refund slots size must be 12")

	# 2. Fill container to capacity with 12 distinct items
	for i in range(12):
		inv.add_items("backpack", [{"item_id": "seed_%d" % i, "count": 20}])
	assert_equal(inv.backpack.slots.size(), 12, "Backpack slots size remains 12 after filling")

	# 3. Attempt to add a 13th distinct item
	var add_13th: bool = inv.add_items("backpack", [{"item_id": "item_thirteen", "count": 1}])
	assert_false(add_13th, "Adding 13th item must fail")
	assert_equal(inv.backpack.slots.size(), 12, "Backpack slots size never exceeds 12")

	# 4. Attempt to add massive quantity (999 items)
	var add_massive: bool = inv.add_items("backpack", [{"item_id": "seed_0", "count": 999}])
	assert_false(add_massive, "Adding to full stack must fail")
	assert_equal(inv.backpack.slots.size(), 12, "Backpack slots size remains 12 under massive add")

	# 5. Deserialization invariant: from_array with oversized array (20 entries)
	var corrupt_array: Array[Dictionary] = []
	for i in range(25):
		corrupt_array.append({"item_id": "corrupt_item", "id": "corrupt_item", "count": 10})
	inv.backpack.from_array(corrupt_array)
	assert_equal(inv.backpack.slots.size(), 12, "Deserializing oversized array must clamp to 12 slots")

	# 6. Deserialization invariant: from_array with undersized array (3 entries)
	var small_array: Array[Dictionary] = [
		{"item_id": "seed_bayam", "id": "seed_bayam", "count": 5},
		{"item_id": "soil_compost", "id": "soil_compost", "count": 3}
	]
	inv.backpack.from_array(small_array)
	assert_equal(inv.backpack.slots.size(), 12, "Deserializing undersized array must maintain 12 slots")
	assert_equal(inv.backpack.get_empty_slot_count(), 10, "10 remaining slots must be empty")

	# 7. Slot bounds access
	assert_not_null(inv.backpack.get_slot(0), "Slot 0 must be accessible")
	assert_not_null(inv.backpack.get_slot(11), "Slot 11 must be accessible")
	assert_equal(inv.backpack.get_slot(-1), null, "Slot -1 must return null")
	assert_equal(inv.backpack.get_slot(12), null, "Slot 12 must return null")
	assert_equal(inv.backpack.get_slot(999), null, "Slot 999 must return null")

	inv.free()
	print("  [PASS] Section 2: Slot capacity invariant (12 slots) verified.")

# ==============================================================================
# SECTION 3: Stack Maximum Invariant (No slot ever holds > 20 items)
# ==============================================================================
func test_stack_max_invariant() -> void:
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# 1. Add 45 items into empty backpack -> Should create two stacks of 20, one stack of 5
	inv.add_items("backpack", [{"item_id": "ingredient_jagung", "count": 45}])
	assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 45, "Total items added = 45")
	for i in range(12):
		var slot = inv.backpack.get_slot(i)
		assert_true(int(slot.count) <= 20, "Slot %d count (%d) must not exceed 20" % [i, int(slot.count)])
	assert_equal(int(inv.backpack.get_slot(0).count), 20, "Slot 0 count must be 20")
	assert_equal(int(inv.backpack.get_slot(1).count), 20, "Slot 1 count must be 20")
	assert_equal(int(inv.backpack.get_slot(2).count), 5, "Slot 2 count must be 5")
	assert_equal(int(inv.backpack.get_slot(3).count), 0, "Slot 3 count must be 0")

	# 2. Low-level InventorySlot add() API with huge count
	var test_slot = InventorySlotClass.new("seed_bayam", 15)
	var leftover: int = test_slot.add(100, 20)
	assert_equal(int(test_slot.count), 20, "Slot add() must not exceed max_stack 20")
	assert_equal(leftover, 95, "Slot add() must return remainder (100 - 5 = 95)")

	# 3. Stack merging via add_item: partial slot (18) + 10 units
	inv.backpack.clear()
	inv.add_items("backpack", [{"item_id": "seed_bayam", "count": 18}])
	inv.add_items("backpack", [{"item_id": "seed_bayam", "count": 10}])
	assert_equal(inv.backpack.get_item_count("seed_bayam"), 28, "Total seed_bayam = 28")
	assert_equal(int(inv.backpack.get_slot(0).count), 20, "First slot topped off to exactly 20")
	assert_equal(int(inv.backpack.get_slot(1).count), 8, "Second slot holds remaining 8")
	for i in range(12):
		var s = inv.backpack.get_slot(i)
		assert_true(int(s.count) <= 20, "Slot %d count <= 20" % i)

	# 4. Invariant under transfer: transfer 15 units into target container with 15 units
	# Should fill target slot to 20 and open new slot with 10 units
	inv.add_items("storage", [{"item_id": "ingredient_bayam", "count": 15}])
	inv.add_items("backpack", [{"item_id": "ingredient_bayam", "count": 15}])
	var xfer_ok: bool = inv.transfer_item("backpack", "storage", 2, 15)
	assert_true(xfer_ok, "Transfer of 15 bayam to storage should succeed")
	assert_equal(inv.storage_home.get_item_count("ingredient_bayam"), 30, "Storage has 30 bayam")
	assert_equal(int(inv.storage_home.get_slot(0).count), 20, "Storage slot 0 capped at 20")
	assert_equal(int(inv.storage_home.get_slot(1).count), 10, "Storage slot 1 holds 10")
	for i in range(12):
		assert_true(int(inv.storage_home.get_slot(i).count) <= 20, "Storage slot %d <= 20" % i)

	inv.free()
	print("  [PASS] Section 3: Stack maximum invariant (<= 20) verified.")

# ==============================================================================
# SECTION 4: Rapid Two-Way Stress (Alternating Transfers & Item Conservation)
# ==============================================================================
# Specification: 200+ rapid alternating transfer operations between backpack
# and chest; verify total item sum across both containers remains perfectly
# constant at every single iteration.
# ==============================================================================
func test_rapid_two_way_stress(iterations: int = 300) -> void:
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# Baseline population: distributed across backpack and storage
	var test_items: Array[String] = [
		"seed_bayam",
		"soil_compost",
		"fertilizer_basic",
		"ingredient_bayam",
		"ingredient_jagung",
		"ingredient_temu_kunci",
		"dish_sayur_bening",
		"water_fresh"
	]

	# Seed predictable PRNG
	var rng := RandomNumberGenerator.new()
	rng.seed = 20451027

	# Populate backpack
	inv.add_items("backpack", [
		{"item_id": "seed_bayam", "count": 15},
		{"item_id": "soil_compost", "count": 8},
		{"item_id": "fertilizer_basic", "count": 12},
		{"item_id": "ingredient_bayam", "count": 10}
	])

	# Populate storage
	inv.add_items("storage", [
		{"item_id": "seed_bayam", "count": 5},
		{"item_id": "ingredient_jagung", "count": 18},
		{"item_id": "ingredient_temu_kunci", "count": 7},
		{"item_id": "dish_sayur_bening", "count": 3},
		{"item_id": "water_fresh", "count": 14}
	])

	# Record baseline distribution
	var baseline_counts: Dictionary = {}
	var grand_total_baseline: int = 0
	for it in test_items:
		var cnt: int = inv.backpack.get_item_count(it) + inv.storage_home.get_item_count(it)
		baseline_counts[it] = cnt
		grand_total_baseline += cnt

	print("    [RAPID_STRESS] Baseline total items: %d across %d item types." % [grand_total_baseline, test_items.size()])
	print("    [RAPID_STRESS] Running %d alternating transfer operations..." % iterations)

	var success_count: int = 0
	var rejection_count: int = 0

	for i in range(iterations):
		var direction: String = "bp_to_storage" if (i % 2 == 0) else "storage_to_bp"
		var src_c := "backpack" if direction == "bp_to_storage" else "storage"
		var dst_c := "storage" if direction == "bp_to_storage" else "backpack"

		var op_type: int = rng.randi_range(0, 3)

		match op_type:
			0:
				# Single item transfer from random slot with random count
				var slot_idx: int = rng.randi_range(0, 11)
				var count_to_xfer: int = rng.randi_range(1, 25)
				var ok: bool = inv.transfer_item(src_c, dst_c, slot_idx, count_to_xfer)
				if ok:
					success_count += 1
				else:
					rejection_count += 1
			1:
				# Full slot transfer from random slot
				var slot_idx: int = rng.randi_range(0, 11)
				var res_slot: Dictionary = inv.transfer_slot(src_c, dst_c, slot_idx)
				if res_slot.get("success", false):
					success_count += 1
				else:
					rejection_count += 1
			2:
				# Transfer all with a random item filter
				var filter_id: String = test_items[rng.randi_range(0, test_items.size() - 1)]
				var res_filter: Dictionary = inv.transfer_all(src_c, dst_c, filter_id)
				if res_filter.get("success", false):
					success_count += 1
				else:
					rejection_count += 1
			3:
				# Transfer all items unfiltered
				var res_all: Dictionary = inv.transfer_all(src_c, dst_c)
				if res_all.get("success", false):
					success_count += 1
				else:
					rejection_count += 1

		# ======================================================================
		# INVARIANTS CHECKED AT EVERY ITERATION
		# ======================================================================
		# 1. Total count per item must strictly equal baseline
		var current_grand_total: int = 0
		for it in test_items:
			var current_cnt: int = inv.backpack.get_item_count(it) + inv.storage_home.get_item_count(it)
			current_grand_total += current_cnt
			if current_cnt != baseline_counts[it]:
				assert_equal(current_cnt, baseline_counts[it], "Iteration %d: Conservation violated for %s" % [i, it])

		# 2. Grand total items across both containers
		if current_grand_total != grand_total_baseline:
			assert_equal(current_grand_total, grand_total_baseline, "Iteration %d: Grand total item conservation violated" % i)

		# 3. get_available_item_count must match baseline
		for it in test_items:
			var avail: int = inv.get_available_item_count(it)
			if avail != baseline_counts[it]:
				assert_equal(avail, baseline_counts[it], "Iteration %d: Available item count violated for %s" % [i, it])

		# 4. Slot count invariant: exactly 12 slots each
		if inv.backpack.slots.size() != 12:
			assert_equal(inv.backpack.slots.size(), 12, "Iteration %d: Backpack slot count changed" % i)
		if inv.storage_home.slots.size() != 12:
			assert_equal(inv.storage_home.slots.size(), 12, "Iteration %d: Storage slot count changed" % i)

		# 5. Stack limits invariant (0 <= count <= 20) and clean slot state
		for s_idx in range(12):
			var bp_slot = inv.backpack.get_slot(s_idx)
			var bp_cnt: int = int(bp_slot.count)
			if bp_cnt < 0 or bp_cnt > 20:
				assert_true(bp_cnt >= 0 and bp_cnt <= 20, "Iteration %d: Backpack slot %d count out of bounds (%d)" % [i, s_idx, bp_cnt])
			if bp_cnt == 0 and not str(bp_slot.item_id).is_empty():
				assert_true(false, "Iteration %d: Backpack slot %d count is 0 but item_id is '%s'" % [i, s_idx, str(bp_slot.item_id)])

			var st_slot = inv.storage_home.get_slot(s_idx)
			var st_cnt: int = int(st_slot.count)
			if st_cnt < 0 or st_cnt > 20:
				assert_true(st_cnt >= 0 and st_cnt <= 20, "Iteration %d: Storage slot %d count out of bounds (%d)" % [i, s_idx, st_cnt])
		# Checkpoint assertion every 20 iterations
		if i % 20 == 0:
			assert_equal(current_grand_total, grand_total_baseline, "Checkpoint at iteration %d: Grand total item conservation verified" % i)
			assert_equal(inv.backpack.slots.size(), 12, "Checkpoint at iteration %d: Backpack slot size is 12" % i)
			assert_equal(inv.storage_home.slots.size(), 12, "Checkpoint at iteration %d: Storage slot size is 12" % i)

	# Final post-loop conservation checks
	var final_grand_total: int = 0
	for it in test_items:
		var final_cnt: int = inv.backpack.get_item_count(it) + inv.storage_home.get_item_count(it)
		final_grand_total += final_cnt
		assert_equal(final_cnt, baseline_counts[it], "Final post-stress count for %s must match baseline" % it)
	assert_equal(final_grand_total, grand_total_baseline, "Final post-stress grand total must match baseline exactly")

	print("    [RAPID_STRESS] Completed %d iterations. Successful: %d, Rejected (capacity/empty): %d." % [
		iterations, success_count, rejection_count
	])
	assert_true(success_count > 0, "Rapid stress must execute at least some successful transfers")
	assert_true(rejection_count > 0, "Rapid stress must exercise rejection boundaries")

	inv.free()
	print("  [PASS] Section 4: Rapid two-way stress & item conservation verified across %d iterations." % iterations)

# ==============================================================================
# SECTION 5: Heterogeneous Multi-Item Batch Atomicity
# ==============================================================================
func test_multi_item_batch_atomicity() -> void:
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# Fill chest so only 2 empty slots remain
	for i in range(10):
		inv.add_items("storage", [{"item_id": "filler_%d" % i, "count": 20}])
	assert_equal(inv.storage_home.get_empty_slot_count(), 2, "Storage must have exactly 2 empty slots")

	# Prepare a batch in backpack of 3 distinct items (requiring 3 separate slots)
	inv.add_items("backpack", [
		{"item_id": "seed_bayam", "count": 5},
		{"item_id": "soil_compost", "count": 3},
		{"item_id": "fertilizer_basic", "count": 4}
	])
	assert_equal(inv.backpack.get_item_count("seed_bayam"), 5, "Backpack has 5 seeds")
	assert_equal(inv.backpack.get_item_count("soil_compost"), 3, "Backpack has 3 compost")
	assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 4, "Backpack has 4 fertilizer")

	# Attempt transfer_all: chest only has 2 slots, batch requires 3 slots!
	var res_all: Dictionary = inv.transfer_all("backpack", "storage")
	assert_false(res_all.get("success", false), "transfer_all requiring 3 slots into 2-slot chest must fail")

	# Verify ZERO partial transfer occurred
	assert_equal(inv.backpack.get_item_count("seed_bayam"), 5, "Backpack seeds untouched")
	assert_equal(inv.backpack.get_item_count("soil_compost"), 3, "Backpack compost untouched")
	assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 4, "Backpack fertilizer untouched")
	assert_equal(inv.storage_home.get_empty_slot_count(), 2, "Storage still has 2 empty slots untouched")

	# Direct add_batch failure test
	var batch_too_big: Array[Dictionary] = [
		{"item_id": "item_x", "count": 1},
		{"item_id": "item_y", "count": 1},
		{"item_id": "item_z", "count": 1}
	]
	var ok_batch: bool = inv.storage_home.add_batch(batch_too_big)
	assert_false(ok_batch, "add_batch requiring 3 slots into 2 slots must fail")
	assert_equal(inv.storage_home.get_item_count("item_x"), 0, "item_x not added")
	assert_equal(inv.storage_home.get_item_count("item_y"), 0, "item_y not added")
	assert_equal(inv.storage_home.get_item_count("item_z"), 0, "item_z not added")
	assert_equal(inv.storage_home.get_empty_slot_count(), 2, "Storage slots strictly unchanged")

	inv.free()
	print("  [PASS] Section 5: Heterogeneous multi-item batch atomicity verified.")

# ==============================================================================
# SECTION 6: Edge Cases, Boundary Inputs & Self-Transfer
# ==============================================================================
func test_edge_cases_and_boundaries() -> void:
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	inv.add_items("backpack", [{"item_id": "seed_bayam", "count": 10}])

	# 1. Transfer 0 items
	var xfer_zero: bool = inv.transfer_item("backpack", "storage", 0, 0)
	assert_false(xfer_zero, "Transfer 0 items must fail/noop")
	assert_equal(inv.backpack.get_item_count("seed_bayam"), 10, "Backpack retains 10 items")
	assert_equal(inv.storage_home.get_item_count("seed_bayam"), 0, "Storage retains 0 items")

	# 2. Transfer negative items (-5)
	var xfer_neg: bool = inv.transfer_item("backpack", "storage", 0, -5)
	assert_false(xfer_neg, "Transfer negative items must fail")
	assert_equal(inv.backpack.get_item_count("seed_bayam"), 10, "Backpack retains 10 items")

	# 3. Transfer from out-of-bounds slot index (-1, 12, 100)
	var xfer_oob1: bool = inv.transfer_item("backpack", "storage", -1, 5)
	assert_false(xfer_oob1, "Transfer from slot -1 must fail")
	var xfer_oob2: bool = inv.transfer_item("backpack", "storage", 12, 5)
	assert_false(xfer_oob2, "Transfer from slot 12 must fail")

	# 4. Transfer from empty slot
	var xfer_empty: bool = inv.transfer_item("backpack", "storage", 1, 5)
	assert_false(xfer_empty, "Transfer from empty slot must fail")

	# 5. Transfer to invalid container name
	var xfer_inv_c: bool = inv.transfer_item("backpack", "nonexistent_chest", 0, 5)
	assert_false(xfer_inv_c, "Transfer to invalid container name must fail")

	# 6. Self-transfer: transfer_item from backpack to backpack
	# Should conserve items without crashing
	var count_before: int = inv.backpack.get_item_count("seed_bayam")
	inv.transfer_item("backpack", "backpack", 0, 5)
	var count_after: int = inv.backpack.get_item_count("seed_bayam")
	assert_equal(count_after, count_before, "Self-transfer must conserve total item count")

	# 7. Over-transfer: requested count exceeds available in slot (request 25, slot has 10)
	# Should transfer available 10 if target has room, or fail cleanly
	var xfer_over: bool = inv.transfer_item("backpack", "storage", 0, 25)
	assert_true(xfer_over, "Over-transfer should transfer up to available amount (10)")
	assert_equal(inv.backpack.get_item_count("seed_bayam"), 0, "Backpack slot drained cleanly")
	assert_equal(inv.storage_home.get_item_count("seed_bayam"), 10, "Storage received exactly 10")
	assert_equal(inv.get_available_item_count("seed_bayam"), 10, "Total available remains 10")

	inv.free()
	print("  [PASS] Section 6: Edge cases, boundary inputs & self-transfer verified.")

# ==============================================================================
# SECTION 7: Starter Crate Capacity & Anti-Spam Invariants
# ==============================================================================
func test_starter_crate_invariants() -> void:
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# Scenario A: Starter requires 3 distinct slots
	# Fill backpack with 10 filler items (only 2 slots free)
	for i in range(10):
		inv.add_items("backpack", [{"item_id": "fill_%d" % i, "count": 1}])
	assert_equal(inv.backpack.get_empty_slot_count(), 2, "Backpack has 2 free slots")

	# Pickup starter -> Must fail cleanly
	var claim_fail: bool = inv.pickup_starter_container()
	assert_false(claim_fail, "Claim starter must fail with only 2 free slots")
	assert_false(inv.is_starter_collected(), "Starter flag remains false on failure")
	assert_equal(inv.backpack.get_item_count("seed_bayam"), 0, "Zero seeds granted")
	assert_equal(inv.backpack.get_item_count("soil_compost"), 0, "Zero compost granted")
	assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 0, "Zero fertilizer granted")

	# Free 1 more slot (now 3 free slots)
	inv.remove_items("backpack", [{"item_id": "fill_0", "count": 1}])
	assert_equal(inv.backpack.get_empty_slot_count(), 3, "Backpack has 3 free slots")

	# Pickup starter -> Must succeed
	var claim_ok: bool = inv.pickup_starter_container()
	assert_true(claim_ok, "Claim starter succeeds with 3 free slots")
	assert_true(inv.is_starter_collected(), "Starter flag is now true")
	assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "4 seeds granted")
	assert_equal(inv.backpack.get_item_count("soil_compost"), 1, "1 compost granted")
	assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 1, "1 fertilizer granted")
	assert_equal(inv.backpack.get_empty_slot_count(), 0, "Backpack is now exactly full (12 slots)")

	# Anti-Spam: 5 rapid spam pickup attempts
	for i in range(5):
		var spam_res: bool = inv.pickup_starter_container()
		assert_false(spam_res, "Spam pickup attempt %d must be rejected" % i)

	# Verify counts never duplicated
	assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "Seeds strictly not duplicated under spam")
	assert_equal(inv.backpack.get_item_count("soil_compost"), 1, "Compost strictly not duplicated under spam")
	assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 1, "Fertilizer strictly not duplicated under spam")

	inv.free()
	print("  [PASS] Section 7: Starter crate capacity & anti-spam invariants verified.")

# ==============================================================================
# SECTION 8: Maximum Dual Saturation Stress (240 + 240 = 480 Units)
# ==============================================================================
func test_maximum_dual_saturation_stress() -> void:
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# Fill backpack with 12 stacks of 20 = 240 units
	for i in range(12):
		inv.add_items("backpack", [{"item_id": "bp_item_%02d" % i, "count": 20}])
	assert_true(inv.backpack.is_full(), "Backpack must be 100% full (240 units)")

	# Fill storage with 12 stacks of 20 = 240 units
	for i in range(12):
		inv.add_items("storage", [{"item_id": "st_item_%02d" % i, "count": 20}])
	assert_true(inv.storage_home.is_full(), "Storage must be 100% full (240 units)")

	# Baseline sum
	var total_initial: int = 0
	for s in inv.backpack.slots:
		total_initial += int(s.count)
	for s in inv.storage_home.slots:
		total_initial += int(s.count)
	assert_equal(total_initial, 480, "Initial combined total must be exactly 480 units")

	# Transfer attempts from backpack to storage (MUST ALL FAIL)
	var xfer_item_fail: bool = inv.transfer_item("backpack", "storage", 0, 5)
	assert_false(xfer_item_fail, "transfer_item into 100% full saturated storage must fail")

	var xfer_slot_fail: Dictionary = inv.transfer_slot("backpack", "storage", 0)
	assert_false(xfer_slot_fail.get("success", false), "transfer_slot into 100% full saturated storage must fail")

	var xfer_all_fail: Dictionary = inv.transfer_all("backpack", "storage")
	assert_false(xfer_all_fail.get("success", false), "transfer_all into 100% full saturated storage must fail")

	# Transfer attempts from storage to backpack (MUST ALL FAIL)
	var xfer_rev_item: bool = inv.transfer_item("storage", "backpack", 0, 5)
	assert_false(xfer_rev_item, "transfer_item into 100% full saturated backpack must fail")

	var xfer_rev_slot: Dictionary = inv.transfer_slot("storage", "backpack", 0)
	assert_false(xfer_rev_slot.get("success", false), "transfer_slot into 100% full saturated backpack must fail")

	var xfer_rev_all: Dictionary = inv.transfer_all("storage", "backpack")
	assert_false(xfer_rev_all.get("success", false), "transfer_all into 100% full saturated backpack must fail")

	# Verify absolute 480 item conservation
	var total_post: int = 0
	for s in inv.backpack.slots:
		total_post += int(s.count)
	for s in inv.storage_home.slots:
		total_post += int(s.count)
	assert_equal(total_post, 480, "Post-saturation transfer attempts: 480 units strictly conserved")

	inv.free()
	print("  [PASS] Section 8: Maximum dual saturation stress (480 units) verified.")

# ==============================================================================
# SECTION 9: Kitchen Reservation Decoupling & Transfer Stress
# ==============================================================================
func test_kitchen_reservation_interaction() -> void:
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# 10 bayam in backpack, 10 bayam in storage -> 20 total
	inv.add_items("backpack", [{"item_id": "ingredient_bayam", "count": 10}])
	inv.add_items("storage", [{"item_id": "ingredient_bayam", "count": 10}])
	assert_equal(inv.get_available_item_count("ingredient_bayam"), 20, "Total available bayam = 20")

	# Reserve 15 bayam for job "cooking_job_01"
	var res_items1: Array[Dictionary] = [
		{"item_id": "ingredient_bayam", "count": 15}
	]
	var res_reserve: Dictionary = inv.reserve_ingredients("cooking_job_01", res_items1)
	assert_true(res_reserve.get("success", false), "Reserving 15 bayam must succeed")
	assert_equal(inv.get_available_item_count("ingredient_bayam"), 5, "Available bayam reduced to 5 (20 - 15)")

	# While reserved: transfer 5 bayam from storage to backpack
	var xfer_ok: bool = inv.transfer_item("storage", "backpack", 0, 5)
	assert_true(xfer_ok, "Physical item transfer between containers while reserved must succeed")
	assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 15, "Backpack now has 15 bayam")
	assert_equal(inv.storage_home.get_item_count("ingredient_bayam"), 5, "Storage now has 5 bayam")
	assert_equal(inv.get_available_item_count("ingredient_bayam"), 5, "Available stock strictly remains 5 during transfer")

	# Commit consumption of cooking job: consumes 15 bayam total
	# Implementation consumes from backpack first (15), leaving 0 in backpack, 5 in storage
	inv.commit_consumption("cooking_job_01")
	assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 0, "Backpack bayam drained by commitment")
	assert_equal(inv.storage_home.get_item_count("ingredient_bayam"), 5, "Storage retains remaining 5 bayam")
	assert_equal(inv.get_available_item_count("ingredient_bayam"), 5, "Available bayam now reflects remaining 5")

	# Test cancellation flow
	var res_items2: Array[Dictionary] = [
		{"item_id": "ingredient_bayam", "count": 5}
	]
	var res_reserve2: Dictionary = inv.reserve_ingredients("cooking_job_02", res_items2)
	assert_true(res_reserve2.get("success", false), "Reserve remaining 5 bayam")
	assert_equal(inv.get_available_item_count("ingredient_bayam"), 0, "Available bayam becomes 0")
	var cancel_ok: bool = inv.cancel_reservation("cooking_job_02")
	assert_true(cancel_ok, "Cancel reservation must succeed")
	assert_equal(inv.get_available_item_count("ingredient_bayam"), 5, "Available bayam restored to 5 on cancellation")

	inv.free()
	print("  [PASS] Section 9: Kitchen reservation decoupling & transfer stress verified.")

# ==============================================================================
# SECTION 10: Snapshot Round-Trip Restoration Oracle
# ==============================================================================
func test_snapshot_roundtrip_oracle() -> void:
	var inv_src: Node = InventoryManagerScript.new()
	inv_src._ready()

	# Populate source manager with complex state
	inv_src.add_items("backpack", [
		{"item_id": "seed_bayam", "count": 17},
		{"item_id": "soil_compost", "count": 6},
		{"item_id": "fertilizer_basic", "count": 19}
	])
	inv_src.add_items("storage", [
		{"item_id": "ingredient_jagung", "count": 20},
		{"item_id": "ingredient_temu_kunci", "count": 14},
		{"item_id": "dish_sayur_bening", "count": 8}
	])
	inv_src.starter_claimed = true

	# Export snapshot
	var snapshot: Dictionary = inv_src.get_save_snapshot()
	assert_true(snapshot.has("backpack"), "Snapshot has backpack key")
	assert_true(snapshot.has("storage_home"), "Snapshot has storage_home key")
	assert_true(snapshot.has("starter_claimed"), "Snapshot has starter_claimed key")

	# Create destination manager and restore snapshot
	var inv_dst: Node = InventoryManagerScript.new()
	inv_dst._ready()
	var load_ok: bool = inv_dst.load_save_snapshot(snapshot)
	assert_true(load_ok, "load_save_snapshot must return true")

	# Verify 100% state fidelity across all slots and fields
	assert_equal(inv_dst.starter_claimed, true, "starter_claimed restored")
	assert_equal(inv_dst.is_starter_collected(), true, "is_starter_collected restored")

	for i in range(12):
		var s_src = inv_src.backpack.get_slot(i)
		var s_dst = inv_dst.backpack.get_slot(i)
		assert_equal(str(s_dst.item_id), str(s_src.item_id), "Backpack slot %d item_id matches" % i)
		assert_equal(int(s_dst.count), int(s_src.count), "Backpack slot %d count matches" % i)

	for i in range(12):
		var s_src = inv_src.storage_home.get_slot(i)
		var s_dst = inv_dst.storage_home.get_slot(i)
		assert_equal(str(s_dst.item_id), str(s_src.item_id), "Storage slot %d item_id matches" % i)
		assert_equal(int(s_dst.count), int(s_src.count), "Storage slot %d count matches" % i)

	inv_src.free()
	inv_dst.free()
	print("  [PASS] Section 10: Snapshot round-trip restoration oracle verified.")

# ==============================================================================
# SUMMARY & EXIT
# ==============================================================================
func _print_summary() -> void:
	print("==================================================================")
	print("[EMPIRICAL_CHALLENGER] INV-001 STRESS HARNESS SUMMARY:")
	print("  Total Assertions:  %d" % total_assertions)
	print("  Passed Assertions: %d" % passed_assertions)
	print("  Failed Assertions: %d" % failed_assertions)

	if failed_assertions == 0:
		print("  VERDICT: ALL EMPIRICAL CHALLENGES PASSED (Exit Code: 0)")
		print("==================================================================")
		quit(0)
	else:
		printerr("  VERDICT: ISSUES DETECTED (%d failures)" % failed_assertions)
		for log_msg in failure_log:
			printerr(log_msg)
		print("==================================================================")
		quit(1)
