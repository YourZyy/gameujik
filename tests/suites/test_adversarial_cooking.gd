class_name TestAdversarialCooking
extends RefCounted

## Adversarial & Stress Testing Harness untuk Milestone COOK-001 (Stasiun Dapur & Reservasi Bahan)
## Memverifikasi secara empiris Invarian T10 (Gating), T11 (Reservasi Atomik), T12 (Anti-Spam 100x), T13 (Exact Return), T40 (Refund Spillover) dan Hukum Kekekalan Materi.

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const RecipeManagerClass = preload("res://scripts/recipe/recipe_manager.gd")
const KitchenManagerClass = preload("res://scripts/cooking/kitchen_manager.gd")
const WorldResourceManagerClass = preload("res://scripts/world/world_resource_manager.gd")

func run_all() -> bool:
	var passed := true
	print("==================================================")
	print("[ADVERSARIAL_SUITE] COOK-001 Empirical Stress & Invariant Verification")
	print("==================================================")

	if not test_adv01_strict_gating_missing_ingredients_and_zero_mutation():
		passed = false
	if not test_adv02_atomic_reservation_split_and_fragmented_slots():
		passed = false
	if not test_adv03_anti_duplication_100x_start_spam_stress():
		passed = false
	if not test_adv04_anti_duplication_100x_cancel_spam_stress():
		passed = false
	if not test_adv05_rapid_reentrancy_start_cancel_50_cycles():
		passed = false
	if not test_adv06_prep_hold_clamping_and_no_auto_cook():
		passed = false
	if not test_adv07_three_tier_overflow_and_matter_conservation():
		passed = false
	if not test_adv08_sleep_and_rest_interlock_invariance():
		passed = false

	return passed

# --- Helpers ---

func _create_clean_inventory() -> Node:
	var inv: Node = InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.storage_home.clear()
	inv.kitchen_refund.clear()
	inv.starter_claimed = false
	inv._reservations.clear()
	return inv

func _create_clean_kitchen(inv: Node, rm: Node = null) -> Node:
	var km: Node = KitchenManagerClass.new()
	km.set_inventory_manager(inv)
	if rm != null:
		km.set_recipe_manager(rm)
	km._ready()
	return km

func _count_universe_items(inv: Node, km: Node) -> int:
	var total := 0
	# Hitung seluruh item di tas, peti, dan kitchen_refund
	for container in [inv.backpack, inv.storage_home, inv.kitchen_refund]:
		if container != null and container.has_method("get_slots"):
			var slots: Array = container.get_slots()
			for s in slots:
				if s != null and not s.is_empty():
					total += int(s.count)

	# Hitung item yang sedang direservasi di dapur
	if km != null:
		for res_it in km.reserved_ingredients:
			total += int(res_it.get("count", 0))

		# Hitung output slot
		if not km.dish_output_slot.is_empty():
			total += int(km.dish_output_slot.get("count", 0))

	return total

# ==============================================================================
# CHALLENGE 1: ADV-01 Strict Gating & Zero-Mutation Boundary Stress
# ==============================================================================

func test_adv01_strict_gating_missing_ingredients_and_zero_mutation() -> bool:
	print("  [RUN] ADV.COOK-01: Strict Gating & Zero-Mutation Boundary Stress (T10)")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	var km := _create_clean_kitchen(inv)

	# 1. Zero ingredients in containers
	var check0: Dictionary = km.can_start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(check0.get("success", true), "ADV-01: Zero ingredients must reject validation")
	var missing0: Dictionary = check0.get("missing", {})
	Assertions.assert_equal(missing0.get("ingredient_bayam"), 3, "ADV-01: Reports missing 3 bayam")
	Assertions.assert_equal(missing0.get("ingredient_jagung"), 1, "ADV-01: Reports missing 1 corn")
	Assertions.assert_equal(missing0.get("ingredient_temu_kunci"), 1, "ADV-01: Reports missing 1 temu kunci")

	var start0: Dictionary = km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(start0.get("success", true), "ADV-01: start_preparation must fail cleanly")
	Assertions.assert_equal(km.job_state, km.JobState.IDLE, "ADV-01: Station remains IDLE")
	Assertions.assert_equal(km.active_job_id, "", "ADV-01: No job created")

	# 2. Missing exactly 1 bayam (has 2 bayam, 1 corn, 1 temu kunci)
	inv.backpack.add_item("ingredient_bayam", 2)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	var check_b1: Dictionary = km.can_start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(check_b1.get("success", true), "ADV-01: Missing 1 bayam must reject")
	Assertions.assert_equal(check_b1.get("missing", {}).get("ingredient_bayam"), 1, "ADV-01: Missing count is 1 bayam")
	var start_b1: Dictionary = km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(start_b1.get("success", true), "ADV-01: start_prep rejected")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 2, "ADV-01: Zero mutation on bayam (still 2)")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 1, "ADV-01: Zero mutation on corn")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 1, "ADV-01: Zero mutation on temu")

	# 3. Missing exactly 1 corn (has 3 bayam, 0 corn, 1 temu kunci)
	inv.backpack.clear()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	var check_c1: Dictionary = km.can_start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(check_c1.get("success", true), "ADV-01: Missing 1 corn must reject")
	Assertions.assert_equal(check_c1.get("missing", {}).get("ingredient_jagung"), 1, "ADV-01: Missing count is 1 corn")
	var start_c1: Dictionary = km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(start_c1.get("success", true), "ADV-01: start_prep rejected")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 3, "ADV-01: Zero mutation on bayam (still 3)")

	# 4. Missing exactly 1 temu kunci (has 3 bayam, 1 corn, 0 temu kunci)
	inv.backpack.clear()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	var check_t1: Dictionary = km.can_start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(check_t1.get("success", true), "ADV-01: Missing 1 temu must reject")
	Assertions.assert_equal(check_t1.get("missing", {}).get("ingredient_temu_kunci"), 1, "ADV-01: Missing count is 1 temu")
	var start_t1: Dictionary = km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(start_t1.get("success", true), "ADV-01: start_prep rejected")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 3, "ADV-01: Zero mutation on bayam (still 3)")

	# 5. Dish output slot occupied (blocking new prep even if ingredients are available)
	inv.backpack.clear()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	km.dish_output_slot = {"item_id": "dish_sayur_bening", "count": 1}
	var check_out: Dictionary = km.can_start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(check_out.get("success", true), "ADV-01: Occupied output slot blocks preparation")
	var start_out: Dictionary = km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(start_out.get("success", true), "ADV-01: start_prep blocked when output occupied")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 3, "ADV-01: Zero mutation when blocked by output")

	# 6. Unknown recipe ID
	km.dish_output_slot.clear()
	var check_unk: Dictionary = km.can_start_preparation("recipe_unknown_xyz")
	Assertions.assert_false(check_unk.get("success", true), "ADV-01: Unknown recipe ID rejected")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-01: Strict gating and zero-mutation verified.")
	else:
		printerr("  [FAIL] ADV.COOK-01: Strict gating failed.")
	return ok

# ==============================================================================
# CHALLENGE 2: ADV-02 Atomic Reservation Across Disjoint & Multi-Slot Containers
# ==============================================================================

func test_adv02_atomic_reservation_split_and_fragmented_slots() -> bool:
	print("  [RUN] ADV.COOK-02: Atomic Split Reservation & Slot Fragmentation Stress (T11)")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	var km := _create_clean_kitchen(inv)

	# Setup disjoint items in both containers
	inv.backpack.add_item("seed_bayam", 10)
	inv.backpack.add_item("soil_compost", 5)
	inv.storage_home.add_item("soil_compost", 20)
	inv.storage_home.add_item("tool_fertilizer", 1)

	# Fragment bayam across multiple slots in backpack:
	# Slot 2 has 1 bayam, Slot 3 has 1 bayam, Slot 4 has 2 bayam (total 4 bayam in BP)
	inv.backpack.slots[2].set("item_id", "ingredient_bayam")
	inv.backpack.slots[2].set("count", 1)
	inv.backpack.slots[3].set("item_id", "ingredient_bayam")
	inv.backpack.slots[3].set("count", 1)
	inv.backpack.slots[4].set("item_id", "ingredient_bayam")
	inv.backpack.slots[4].set("count", 2)

	# Put 1 corn in storage, 1 temu kunci in backpack slot 5
	inv.storage_home.add_item("ingredient_jagung", 1)
	inv.backpack.slots[5].set("item_id", "ingredient_temu_kunci")
	inv.backpack.slots[5].set("count", 1)

	var initial_matter = _count_universe_items(inv, km)

	# Start preparation
	var res: Dictionary = km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_true(res.get("success", false), "ADV-02: Split and fragmented reservation succeeds")

	# Check reservation deductions:
	# 3 bayam needed: backpack had 4 bayam across slots 2, 3, 4.
	# Should pull 1 from slot 2, 1 from slot 3, 1 from slot 4.
	# Slot 4 should still retain 1 bayam!
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 1, "ADV-02: Exactly 1 bayam remains in backpack")
	Assertions.assert_equal(inv.backpack.slots[2].get("count"), 0, "ADV-02: Slot 2 bayam fully consumed")
	Assertions.assert_equal(inv.backpack.slots[3].get("count"), 0, "ADV-02: Slot 3 bayam fully consumed")
	Assertions.assert_equal(inv.backpack.slots[4].get("count"), 1, "ADV-02: Slot 4 retains 1 bayam")

	# Corn was in storage -> storage corn consumed
	Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_jagung"), 0, "ADV-02: Storage corn fully consumed")

	# Temu kunci was in backpack -> consumed
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 0, "ADV-02: Backpack temu kunci fully consumed")

	# Disjoint items untouched
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 10, "ADV-02: Seed bayam untouched")
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 5, "ADV-02: Backpack compost untouched")
	Assertions.assert_equal(inv.storage_home.get_item_count("soil_compost"), 20, "ADV-02: Storage compost untouched")
	Assertions.assert_equal(inv.storage_home.get_item_count("tool_fertilizer"), 1, "ADV-02: Storage fertilizer untouched")

	# Verify universe matter conservation during active reservation
	var current_matter = _count_universe_items(inv, km)
	Assertions.assert_equal(current_matter, initial_matter, "ADV-02: Conservation of matter holds during active reservation")

	# Cancel preparation and verify return
	var cancel_res: Dictionary = km.cancel_preparation()
	Assertions.assert_true(cancel_res.get("success", false), "ADV-02: Cancel preparation succeeds")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 4, "ADV-02: All 4 bayam restored to backpack")
	Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_jagung"), 1, "ADV-02: Corn restored to storage")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 1, "ADV-02: Temu kunci restored to backpack")

	var final_matter = _count_universe_items(inv, km)
	Assertions.assert_equal(final_matter, initial_matter, "ADV-02: Conservation of matter holds after cancellation")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-02: Atomic split reservation & fragmentation verified.")
	else:
		printerr("  [FAIL] ADV.COOK-02: Split reservation failed.")
	return ok

# ==============================================================================
# CHALLENGE 3: ADV-03 100x Rapid-Fire Spam Stress on start_preparation()
# ==============================================================================

func test_adv03_anti_duplication_100x_start_spam_stress() -> bool:
	print("  [RUN] ADV.COOK-03: 100x Rapid-Fire Spam Stress on start_preparation() (T12)")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	var km := _create_clean_kitchen(inv)

	var initial_matter = _count_universe_items(inv, km)
	Assertions.assert_equal(initial_matter, 5, "ADV-03: Initial matter is 5")

	var first_res: Dictionary = km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_true(first_res.get("success", false), "ADV-03: Initial call 0 succeeds")
	var stable_job_id: String = km.active_job_id
	Assertions.assert_true(stable_job_id.length() > 0, "ADV-03: Job ID assigned")

	var spam_rejected_count := 0
	var spam_idempotent_count := 0

	# 100 rapid spam calls
	for i in range(100):
		var res: Dictionary = km.start_preparation("recipe_sayur_bening_01")
		if not res.get("success", true):
			spam_rejected_count += 1
		if res.get("idempotent", false):
			spam_idempotent_count += 1

	Assertions.assert_equal(spam_rejected_count, 100, "ADV-03: All 100 spam calls rejected")
	Assertions.assert_equal(spam_idempotent_count, 100, "ADV-03: All 100 spam calls flagged idempotent")
	Assertions.assert_equal(km.active_job_id, stable_job_id, "ADV-03: Job ID unchanged after 100 spams")
	Assertions.assert_equal(km.reserved_ingredients.size(), 3, "ADV-03: Exactly 3 ingredient types reserved")

	# Check no duplicate deductions or negative inventory
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 0, "ADV-03: Bayam in backpack is 0 (not negative)")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 0, "ADV-03: Corn in backpack is 0")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 0, "ADV-03: Temu in backpack is 0")

	var current_matter = _count_universe_items(inv, km)
	Assertions.assert_equal(current_matter, initial_matter, "ADV-03: Exactly 5 items in universe (no duplication exploit)")

	km.cancel_preparation()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-03: 100x start spam stress verified.")
	else:
		printerr("  [FAIL] ADV.COOK-03: Start spam stress failed.")
	return ok

# ==============================================================================
# CHALLENGE 4: ADV-04 100x Rapid-Fire Spam Stress on cancel_preparation()
# ==============================================================================

func test_adv04_anti_duplication_100x_cancel_spam_stress() -> bool:
	print("  [RUN] ADV.COOK-04: 100x Rapid-Fire Spam Stress on cancel_preparation() (T13)")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	var km := _create_clean_kitchen(inv)

	var initial_matter = _count_universe_items(inv, km)

	# Start prep
	km.start_preparation("recipe_sayur_bening_01")

	# First cancel call
	var first_cancel: Dictionary = km.cancel_preparation()
	Assertions.assert_true(first_cancel.get("success", false), "ADV-04: First cancel succeeds")
	Assertions.assert_equal(km.job_state, km.JobState.IDLE, "ADV-04: Station returned to IDLE")

	var cancel_rejected_count := 0

	# 100 rapid spam cancel calls on IDLE station
	for i in range(100):
		var res: Dictionary = km.cancel_preparation()
		if not res.get("success", true):
			cancel_rejected_count += 1

	Assertions.assert_equal(cancel_rejected_count, 100, "ADV-04: All 100 spam cancels rejected cleanly")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 3, "ADV-04: Bayam count exactly 3 (NO DUPLICATION)")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 1, "ADV-04: Corn count exactly 1 (NO DUPLICATION)")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 1, "ADV-04: Temu count exactly 1 (NO DUPLICATION)")

	var final_matter = _count_universe_items(inv, km)
	Assertions.assert_equal(final_matter, initial_matter, "ADV-04: Matter strictly conserved across 100 spam cancellations")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-04: 100x cancel spam stress verified.")
	else:
		printerr("  [FAIL] ADV.COOK-04: Cancel spam stress failed.")
	return ok

# ==============================================================================
# CHALLENGE 5: ADV-05 Rapid Re-Entrancy Start-Cancel Loop (50 Cycles)
# ==============================================================================

func test_adv05_rapid_reentrancy_start_cancel_50_cycles() -> bool:
	print("  [RUN] ADV.COOK-05: Rapid Re-Entrancy Start-Cancel Loop (50 Cycles)")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	var km := _create_clean_kitchen(inv)

	var initial_matter = _count_universe_items(inv, km)

	for cycle in range(50):
		var start_res: Dictionary = km.start_preparation("recipe_sayur_bening_01")
		Assertions.assert_true(start_res.get("success", false), "ADV-05 Cycle %d: Start succeeds" % cycle)
		Assertions.assert_equal(km.job_state, km.JobState.RESERVED_PREPARING, "ADV-05 Cycle %d: State is RESERVED_PREPARING" % cycle)

		# Random partial hold progress between 0.1s and 3.5s
		var partial_advance: float = (cycle % 7) * 0.5
		km.advance_prep(partial_advance)

		var cancel_res: Dictionary = km.cancel_preparation()
		Assertions.assert_true(cancel_res.get("success", false), "ADV-05 Cycle %d: Cancel succeeds" % cycle)
		Assertions.assert_equal(km.job_state, km.JobState.IDLE, "ADV-05 Cycle %d: State reset to IDLE" % cycle)

		var cycle_matter = _count_universe_items(inv, km)
		if cycle_matter != initial_matter:
			Assertions.assert_equal(cycle_matter, initial_matter, "ADV-05 Cycle %d: Matter corrupted!" % cycle)
			break

	Assertions.assert_equal(_count_universe_items(inv, km), initial_matter, "ADV-05: Matter strictly conserved across 50 full start-cancel cycles")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-05: 50 cycles rapid re-entrancy verified.")
	else:
		printerr("  [FAIL] ADV.COOK-05: Re-entrancy cycles failed.")
	return ok

# ==============================================================================
# CHALLENGE 6: ADV-06 4.0s Hold Clamping & No Auto-Cook Invariant
# ==============================================================================

func test_adv06_prep_hold_clamping_and_no_auto_cook() -> bool:
	print("  [RUN] ADV.COOK-06: 4.0s Hold Clamping & Strict No-Auto-Cook Invariant (T12)")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	var km := _create_clean_kitchen(inv)

	km.start_preparation("recipe_sayur_bening_01")

	# 1. Partial advance
	km.advance_prep(1.5)
	Assertions.assert_approx_equal(km.prep_progress, 1.5, 0.01, "ADV-06: Progress at 1.5s")
	Assertions.assert_equal(km.job_state, km.JobState.RESERVED_PREPARING, "ADV-06: Still RESERVED_PREPARING")

	# 2. Release button: progress retained
	km.hold_tick(1.0, false)
	Assertions.assert_approx_equal(km.prep_progress, 1.5, 0.01, "ADV-06: Progress retained on button release")

	# 3. Advance to 4.0s exactly
	km.advance_prep(2.5)
	Assertions.assert_approx_equal(km.prep_progress, 4.0, 0.01, "ADV-06: Progress reaches 4.0s")
	Assertions.assert_equal(km.job_state, km.JobState.READY_TO_HEAT, "ADV-06: State transitions to READY_TO_HEAT")

	# 4. Over-hold stress: user holds button for an extra 15 seconds
	km.advance_prep(15.0)
	Assertions.assert_approx_equal(km.prep_progress, 4.0, 0.01, "ADV-06: Progress clamped at 4.0s")
	Assertions.assert_equal(km.job_state, km.JobState.READY_TO_HEAT, "ADV-06: State remains READY_TO_HEAT")
	Assertions.assert_ne(km.job_state, km.JobState.COOKING, "ADV-06: Strict requirement: MUST NOT auto-transition to COOKING")

	# 5. Cancel at READY_TO_HEAT
	var cancel_res: Dictionary = km.cancel_preparation()
	Assertions.assert_true(cancel_res.get("success", false), "ADV-06: Cancel at READY_TO_HEAT succeeds")
	Assertions.assert_equal(km.job_state, km.JobState.IDLE, "ADV-06: Reset to IDLE")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 3, "ADV-06: 3 bayam restored")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 1, "ADV-06: 1 corn restored")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 1, "ADV-06: 1 temu restored")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-06: Hold clamping & no auto-cook verified.")
	else:
		printerr("  [FAIL] ADV.COOK-06: Hold clamping failed.")
	return ok

# ==============================================================================
# CHALLENGE 7: ADV-07 Three-Tier Overflow & Conservation of Matter (T40)
# ==============================================================================

func test_adv07_three_tier_overflow_and_matter_conservation() -> bool:
	print("  [RUN] ADV.COOK-07: Three-Tier Safe Refund Overflow & Matter Conservation (T40)")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	var km := _create_clean_kitchen(inv)

	# --- Skenario A: Tas diisi penuh selama persiapan -> tumpah ke peti (Tier 2) ---
	km.start_preparation("recipe_sayur_bening_01")
	# Penuhi seluruh 12 slot tas dengan benih
	for i in range(12):
		inv.backpack.add_item("seed_bayam", 20)
	Assertions.assert_equal(inv.backpack.get_used_slots_count(), 12, "ADV-07-A: Backpack 100% full (12/12)")

	var res_a: Dictionary = km.cancel_preparation()
	Assertions.assert_true(res_a.get("success", false), "ADV-07-A: Cancel succeeds when backpack full")
	Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_bayam"), 3, "ADV-07-A: 3 bayam spilled to storage")
	Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_jagung"), 1, "ADV-07-A: 1 corn spilled to storage")
	Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_temu_kunci"), 1, "ADV-07-A: 1 temu spilled to storage")
	Assertions.assert_true(km.dish_output_slot.is_empty(), "ADV-07-A: dish_output_slot strictly empty")

	var matter_a = _count_universe_items(inv, km)
	Assertions.assert_equal(matter_a, 245, "ADV-07-A: 240 seeds + 5 ingredients = 245 total matter")

	# --- Skenario B: Tas DAN Peti penuh -> tumpah ke kitchen_refund (Tier 3) ---
	# Bersihkan tas dan peti untuk fixture B
	inv.backpack.clear()
	inv.storage_home.clear()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	km.start_preparation("recipe_sayur_bening_01")

	# Penuhi kedua kontainer
	for i in range(12):
		inv.backpack.add_item("seed_bayam", 20)
		inv.storage_home.add_item("soil_compost", 20)

	Assertions.assert_equal(inv.backpack.get_used_slots_count(), 12, "ADV-07-B: Backpack 100% full (12/12)")
	Assertions.assert_equal(inv.storage_home.get_used_slots_count(), 12, "ADV-07-B: Storage 100% full (12/12)")

	var res_b: Dictionary = km.cancel_preparation()
	Assertions.assert_true(res_b.get("success", false), "ADV-07-B: Cancel succeeds when both containers full")
	Assertions.assert_true(res_b.get("spilled_to_refund", false), "ADV-07-B: Flag spilled_to_refund is true")
	Assertions.assert_equal(inv.kitchen_refund.get_item_count("ingredient_bayam"), 3, "ADV-07-B: 3 bayam in kitchen_refund")
	Assertions.assert_equal(inv.kitchen_refund.get_item_count("ingredient_jagung"), 1, "ADV-07-B: 1 corn in kitchen_refund")
	Assertions.assert_equal(inv.kitchen_refund.get_item_count("ingredient_temu_kunci"), 1, "ADV-07-B: 1 temu in kitchen_refund")
	Assertions.assert_true(km.has_refund_items(), "ADV-07-B: has_refund_items returns true")
	Assertions.assert_true(km.dish_output_slot.is_empty(), "ADV-07-B: STRICT ISOLATION: dish_output_slot strictly empty")

	var matter_b = _count_universe_items(inv, km)
	Assertions.assert_equal(matter_b, 485, "ADV-07-B: 240 seeds + 240 compost + 5 ingredients = 485 total matter")

	# --- Skenario C: Ambil refund items (claim_refund_items) ---
	# Kosongkan tas agar muat
	inv.backpack.clear()
	var claim_res: Dictionary = km.claim_refund_items()
	Assertions.assert_true(claim_res.get("success", false), "ADV-07-C: Claim refund succeeds into cleared backpack")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 3, "ADV-07-C: 3 bayam moved to backpack")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 1, "ADV-07-C: 1 corn moved to backpack")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 1, "ADV-07-C: 1 temu moved to backpack")
	Assertions.assert_false(km.has_refund_items(), "ADV-07-C: kitchen_refund now empty")

	var matter_c = _count_universe_items(inv, km)
	Assertions.assert_equal(matter_c, 245, "ADV-07-C: 240 compost + 5 ingredients = 245 total matter")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-07: Three-tier refund & matter conservation verified.")
	else:
		printerr("  [FAIL] ADV.COOK-07: Three-tier refund failed.")
	return ok

# ==============================================================================
# CHALLENGE 8: ADV-08 Sleep & Rest Interlock Invariance
# ==============================================================================

func test_adv08_sleep_and_rest_interlock_invariance() -> bool:
	print("  [RUN] ADV.COOK-08: Sleep & Rest Bed Interlock Invariance")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	var km := _create_clean_kitchen(inv)

	var wrm := WorldResourceManagerClass.new()
	wrm.set_kitchen_manager(km)
	wrm.current_day = 1

	# 1. State IDLE -> can sleep
	var sleep_idle: Dictionary = wrm.can_sleep()
	Assertions.assert_true(sleep_idle.get("success", false), "ADV-08: Can sleep when kitchen IDLE")

	# 2. State RESERVED_PREPARING -> cannot sleep
	km.start_preparation("recipe_sayur_bening_01")
	var sleep_prep: Dictionary = wrm.can_sleep()
	Assertions.assert_false(sleep_prep.get("success", true), "ADV-08: Sleep blocked during RESERVED_PREPARING")

	var advance_attempt_1: bool = wrm.sleep_and_advance_day()
	Assertions.assert_false(advance_attempt_1, "ADV-08: sleep_and_advance_day returns false during prep")
	Assertions.assert_equal(wrm.current_day, 1, "ADV-08: Day does NOT advance")

	# 3. State READY_TO_HEAT -> cannot sleep
	km.advance_prep(4.0)
	Assertions.assert_equal(km.job_state, km.JobState.READY_TO_HEAT, "ADV-08: Kitchen is READY_TO_HEAT")
	var sleep_ready: Dictionary = wrm.can_sleep()
	Assertions.assert_false(sleep_ready.get("success", true), "ADV-08: Sleep blocked during READY_TO_HEAT")

	var advance_attempt_2: bool = wrm.sleep_and_advance_day()
	Assertions.assert_false(advance_attempt_2, "ADV-08: sleep_and_advance_day returns false during READY_TO_HEAT")
	Assertions.assert_equal(wrm.current_day, 1, "ADV-08: Day still does NOT advance")

	# 4. After cancellation back to IDLE -> can sleep and advance day
	km.cancel_preparation()
	Assertions.assert_equal(km.job_state, km.JobState.IDLE, "ADV-08: Kitchen returned to IDLE")
	var sleep_after: Dictionary = wrm.can_sleep()
	Assertions.assert_true(sleep_after.get("success", false), "ADV-08: Sleep allowed after cancel")

	var advance_success: bool = wrm.sleep_and_advance_day()
	Assertions.assert_true(advance_success, "ADV-08: sleep_and_advance_day succeeds after cancellation")
	Assertions.assert_equal(wrm.current_day, 2, "ADV-08: Day advanced to Day 2")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-08: Sleep & rest interlock invariance verified.")
	else:
		printerr("  [FAIL] ADV.COOK-08: Sleep interlock failed.")
	return ok
