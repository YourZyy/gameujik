# Proposed Unit Test Methods for GARD-002: tests/suites/test_gardening.gd
# Designed by explorer_gard_002_3
# Implements deterministic, zero-waiting testing for T05, T34, T35, T36, multi-spot isolation, and SAVE-001

## -----------------------------------------------------------------------------
## T34 / T05: 4-Stage Crop Growth Cycle (30s Seed, 60s Sprout, 90s Growing, 180s Harvestable)
## -----------------------------------------------------------------------------
func test_t34_crop_growth_4_stages() -> bool:
	print("    [RUN] T34/T05: 4-Stage Crop Growth Cycle (0..30s Seed, 30..90s Sprout, 90..180s Growing, 180s Harvestable)")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var gm: Node = _create_clean_garden_manager(inv)

	# 1. Prepare plot with nutrients and moisture
	gm.hoe_plot("plot_home_01")
	inv.backpack.add_item("soil_compost", 1)
	gm.add_compost("plot_home_01")
	inv.backpack.add_item("fertilizer_basic", 1)
	gm.fertilize_plot("plot_home_01") # Nutrients = 100.0
	gm.refill_water()
	gm.water_plot("plot_home_01") # Moisture = 80.0

	# 2. Plant seed on slot_01
	inv.backpack.add_item("seed_bayam", 1)
	Assertions.assert_true(gm.plant_seed("plot_home_01", "slot_01", "seed_bayam"), "Plant seed succeeds")

	# Verify Stage 0 (Benih / Seed) at t = 0.0s
	var sp0: Dictionary = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_equal(int(sp0["crop_data"]["growth_stage"]), 0, "Stage at t=0s must be 0 (Seed)")
	Assertions.assert_approx_equal(float(sp0["crop_data"]["growth_time"]), 0.0, 0.001, "Growth time at t=0s is 0.0")
	Assertions.assert_false(bool(sp0["crop_data"]["is_ready_to_harvest"]), "Not harvestable at t=0s")

	# Boundary test: t = 29.9s -> Still Stage 0
	gm.simulate_process(29.9)
	var sp_29: Dictionary = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_equal(int(sp_29["crop_data"]["growth_stage"]), 0, "Stage at t=29.9s must still be 0 (Seed)")
	Assertions.assert_approx_equal(float(sp_29["crop_data"]["growth_time"]), 29.9, 0.01, "Growth time is 29.9s")

	# Boundary test: t = 30.0s -> Stage 1 (Tunas / Sprout)
	gm.simulate_process(0.1)
	var sp_30: Dictionary = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_equal(int(sp_30["crop_data"]["growth_stage"]), 1, "Stage at t=30.0s transitions to 1 (Sprout)")
	Assertions.assert_approx_equal(float(sp_30["crop_data"]["growth_time"]), 30.0, 0.01, "Growth time is 30.0s")
	Assertions.assert_false(bool(sp_30["crop_data"]["is_ready_to_harvest"]), "Not harvestable at t=30s")

	# Boundary test: t = 89.9s -> Still Stage 1
	gm.simulate_process(59.9)
	var sp_89: Dictionary = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_equal(int(sp_89["crop_data"]["growth_stage"]), 1, "Stage at t=89.9s must still be 1 (Sprout)")

	# Boundary test: t = 90.0s -> Stage 2 (Tumbuh / Growing)
	gm.simulate_process(0.1)
	var sp_90: Dictionary = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_equal(int(sp_90["crop_data"]["growth_stage"]), 2, "Stage at t=90.0s transitions to 2 (Growing)")
	Assertions.assert_approx_equal(float(sp_90["crop_data"]["growth_time"]), 90.0, 0.01, "Growth time is 90.0s")
	Assertions.assert_false(bool(sp_90["crop_data"]["is_ready_to_harvest"]), "Not harvestable at t=90s")

	# Boundary test: t = 179.9s -> Still Stage 2
	gm.simulate_process(89.9)
	var sp_179: Dictionary = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_equal(int(sp_179["crop_data"]["growth_stage"]), 2, "Stage at t=179.9s must still be 2 (Growing)")
	Assertions.assert_false(bool(sp_179["crop_data"]["is_ready_to_harvest"]), "Not harvestable at t=179.9s")

	# Boundary test: t = 180.0s -> Stage 3 (Siap Panen / Harvestable)
	gm.simulate_process(0.1)
	var sp_180: Dictionary = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_equal(int(sp_180["crop_data"]["growth_stage"]), 3, "Stage at t=180.0s transitions to 3 (Harvestable)")
	Assertions.assert_approx_equal(float(sp_180["crop_data"]["growth_time"]), 180.0, 0.01, "Growth time is 180.0s")
	Assertions.assert_true(bool(sp_180["crop_data"]["is_ready_to_harvest"]), "Must be ready to harvest at t>=180s")

	# Over-growth clamping: t = 250.0s -> Growth time strictly locked at 180.0s
	gm.simulate_process(70.0)
	var sp_clamped: Dictionary = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_equal(int(sp_clamped["crop_data"]["growth_stage"]), 3, "Stage remains 3")
	Assertions.assert_approx_equal(float(sp_clamped["crop_data"]["growth_time"]), 180.0, 0.001, "Growth time strictly clamped at 180.0s")
	Assertions.assert_true(bool(sp_clamped["crop_data"]["is_ready_to_harvest"]), "Still ready to harvest")

	if Assertions.current_suite_failed == initial_failures:
		print("    [PASS] T34/T05: 4-Stage Crop Growth Cycle verified.")
		return true
	return false

# Alias for dispatch numbering compatibility
func test_t05_crop_growth_4_stages() -> bool:
	return test_t34_crop_growth_4_stages()


## -----------------------------------------------------------------------------
## T35 / T34: Growth Stall Thresholds (Moisture < 30, Nutrients < 20, Zero Loss Resumption)
## -----------------------------------------------------------------------------
func test_t35_growth_stall_conditions() -> bool:
	print("    [RUN] T35/T34: Growth Stall Thresholds (Moisture < 30, Nutrients < 20, Non-Decay Invariance)")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var gm: Node = _create_clean_garden_manager(inv)

	# Prepare plot
	gm.hoe_plot("plot_home_01")
	inv.backpack.add_item("soil_compost", 1)
	gm.add_compost("plot_home_01")
	inv.backpack.add_item("seed_bayam", 1)
	gm.plant_seed("plot_home_01", "slot_01", "seed_bayam")

	# 1. Stall Case 1: Nutrients = 0 (< 20 threshold), Moisture = 80
	gm.get_plot("plot_home_01")["nutrients"] = 0.0
	gm.get_plot("plot_home_01")["moisture"] = 80.0

	gm.simulate_process(50.0)
	var sp_stall1: Dictionary = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_approx_equal(float(sp_stall1["crop_data"]["growth_time"]), 0.0, 0.001, "Growth time must not advance when nutrients < 20")
	Assertions.assert_equal(int(sp_stall1["crop_data"]["growth_stage"]), 0, "Stage remains 0")

	# 2. Stall Case 2: Nutrients = 100, Moisture = 25.0 (< 30 threshold)
	gm.get_plot("plot_home_01")["nutrients"] = 100.0
	gm.get_plot("plot_home_01")["moisture"] = 25.0

	gm.simulate_process(50.0)
	var sp_stall2: Dictionary = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_approx_equal(float(sp_stall2["crop_data"]["growth_time"]), 0.0, 0.001, "Growth time must not advance when moisture < 30")

	# 3. Stall Case 3: Boundary threshold testing (19.9 vs 20.0 nutrients, 29.9 vs 30.0 moisture)
	gm.get_plot("plot_home_01")["nutrients"] = 19.9
	gm.get_plot("plot_home_01")["moisture"] = 80.0
	gm.simulate_process(10.0)
	Assertions.assert_approx_equal(float(gm.get_spot("plot_home_01", "slot_01")["crop_data"]["growth_time"]), 0.0, 0.001, "Nutrients 19.9 stalls growth")

	gm.get_plot("plot_home_01")["nutrients"] = 20.0
	gm.get_plot("plot_home_01")["moisture"] = 29.9
	gm.simulate_process(10.0)
	Assertions.assert_approx_equal(float(gm.get_spot("plot_home_01", "slot_01")["crop_data"]["growth_time"]), 0.0, 0.001, "Moisture 29.9 stalls growth")

	# 4. Partial Growth then Stall & Zero-Loss Resumption
	# Fulfill both conditions: nutrients = 20.0, moisture = 50.0
	gm.get_plot("plot_home_01")["nutrients"] = 20.0
	gm.get_plot("plot_home_01")["moisture"] = 50.0

	gm.simulate_process(45.0) # Active growth for 45s -> reaches Stage 1 (Sprout)
	var sp_active: Dictionary = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_approx_equal(float(sp_active["crop_data"]["growth_time"]), 45.0, 0.01, "Growth advances to 45.0s")
	Assertions.assert_equal(int(sp_active["crop_data"]["growth_stage"]), 1, "Stage is 1 (Sprout)")

	# Now stall the plot: dry out moisture below 30
	gm.get_plot("plot_home_01")["moisture"] = 10.0
	gm.simulate_process(100.0) # 100s while stalled
	var sp_stalled: Dictionary = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_approx_equal(float(sp_stalled["crop_data"]["growth_time"]), 45.0, 0.001, "Growth time preserved without loss (45.0s)")
	Assertions.assert_equal(int(sp_stalled["crop_data"]["growth_stage"]), 1, "Stage remains 1 (No regression, plant does not die)")

	# Restore moisture: re-water to 80.0
	gm.get_plot("plot_home_01")["moisture"] = 80.0
	gm.simulate_process(45.0) # Advance another 45s -> total 90.0s -> Stage 2 (Growing)
	var sp_resumed: Dictionary = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_approx_equal(float(sp_resumed["crop_data"]["growth_time"]), 90.0, 0.01, "Growth resumes from 45.0s to 90.0s")
	Assertions.assert_equal(int(sp_resumed["crop_data"]["growth_stage"]), 2, "Stage transitions to 2 (Growing)")

	if Assertions.current_suite_failed == initial_failures:
		print("    [PASS] T35/T34: Growth Stall Thresholds verified.")
		return true
	return false

# Alias for dispatch numbering compatibility
func test_t34_growth_stall_conditions() -> bool:
	return test_t35_growth_stall_conditions()


## -----------------------------------------------------------------------------
## T36 / T35: Atomic Harvest Yield, Nutrition Deduction & Immediate Replanting
## -----------------------------------------------------------------------------
func test_t36_atomic_harvest_yield_and_replanting() -> bool:
	print("    [RUN] T36/T35: Atomic Harvest Yield (1 Spinach + 1 Seed), -5 Nutrients & Replanting")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var gm: Node = _create_clean_garden_manager(inv)

	# Prepare plot
	gm.hoe_plot("plot_home_01")
	inv.backpack.add_item("soil_compost", 1)
	gm.add_compost("plot_home_01")
	inv.backpack.add_item("fertilizer_basic", 1)
	gm.fertilize_plot("plot_home_01") # nutrients = 100.0
	gm.refill_water()
	gm.water_plot("plot_home_01") # moisture = 80.0

	# Plant slot_01
	inv.backpack.add_item("seed_bayam", 1)
	gm.plant_seed("plot_home_01", "slot_01", "seed_bayam")

	# 1. Harvest attempt before maturity (growth_time = 0.0s) -> REJECTED
	var early_check: Dictionary = gm.can_harvest_crop("plot_home_01", "slot_01")
	Assertions.assert_false(early_check["success"], "Harvesting immature crop must be rejected")
	Assertions.assert_false(gm.harvest_crop("plot_home_01", "slot_01"), "harvest_crop returns false for immature crop")

	# 2. Advance to full maturity (180.0s)
	gm.simulate_process(180.0)
	var sp_mature: Dictionary = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_true(bool(sp_mature["crop_data"]["is_ready_to_harvest"]), "Crop is ready to harvest")

	# 3. Successful Atomic Harvest
	var can_harvest: Dictionary = gm.can_harvest_crop("plot_home_01", "slot_01")
	Assertions.assert_true(can_harvest["success"], "can_harvest_crop must be true when mature with bag space")

	var initial_nutrients: float = float(gm.get_plot("plot_home_01")["nutrients"]) # 100.0
	var harvest_ok: bool = gm.harvest_crop("plot_home_01", "slot_01")
	Assertions.assert_true(harvest_ok, "harvest_crop must succeed")

	# Yield check: 1 Bayam + 1 Seed
	var bayam_count: int = inv.backpack.get_item_count("ingredient_bayam")
	if bayam_count == 0:
		bayam_count = inv.backpack.get_item_count("crop_bayam")
	Assertions.assert_equal(bayam_count, 1, "Backpack must receive exactly 1 Bayam (ingredient_bayam / crop_bayam)")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 1, "Backpack must receive exactly 1 Benih Bayam (seed_bayam)")

	# Nutrients deduction: exactly 5 points
	var new_nutrients: float = float(gm.get_plot("plot_home_01")["nutrients"])
	Assertions.assert_approx_equal(new_nutrients, initial_nutrients - 5.0, 0.001, "Plot nutrients must decrease by exactly 5.0 points (100 -> 95)")

	# Spot cleared
	var sp_harvested: Dictionary = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_false(bool(sp_harvested.get("is_occupied", false)), "Spot must become unoccupied after harvest")
	Assertions.assert_null(sp_harvested.get("crop_data", null), "Spot crop_data must be reset to null")

	# 4. Anti-Spam / Idempotency: Spamming harvest on empty spot
	for i in range(10):
		var spam_check = gm.can_harvest_crop("plot_home_01", "slot_01")
		Assertions.assert_false(spam_check["success"], "Spam harvest check rejected on empty spot")
		Assertions.assert_false(gm.harvest_crop("plot_home_01", "slot_01"), "Spam harvest execution rejected")

	# Assert no extra items or nutrients deducted during spam
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["nutrients"]), 95.0, 0.001, "Nutrients remain 95.0 after spam")
	var final_bayam: int = inv.backpack.get_item_count("ingredient_bayam")
	if final_bayam == 0:
		final_bayam = inv.backpack.get_item_count("crop_bayam")
	Assertions.assert_equal(final_bayam, 1, "Bayam count remains exactly 1")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 1, "Seed count remains exactly 1")

	# 5. Immediate Replanting on Cleared Spot (Without re-cangkul or re-compost)
	# Using the seed just harvested!
	Assertions.assert_true(gm.is_plot_ready_to_plant("plot_home_01"), "Plot remains ready to plant (is_hoed and has_compost persist)")
	var replant_ok: bool = gm.plant_seed("plot_home_01", "slot_01", "seed_bayam")
	Assertions.assert_true(replant_ok, "Spot can be replanted immediately with harvested seed")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 0, "Harvested seed consumed for replanting")
	var sp_replanted: Dictionary = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_true(bool(sp_replanted.get("is_occupied", false)), "Spot is occupied again")
	Assertions.assert_equal(int(sp_replanted["crop_data"]["growth_stage"]), 0, "Replanted crop begins at Stage 0")
	Assertions.assert_approx_equal(float(sp_replanted["crop_data"]["growth_time"]), 0.0, 0.001, "Replanted crop begins at 0.0s")

	if Assertions.current_suite_failed == initial_failures:
		print("    [PASS] T36/T35: Atomic Harvest Yield & Replanting verified.")
		return true
	return false

# Alias for dispatch numbering compatibility
func test_t35_atomic_harvest_yield() -> bool:
	return test_t36_atomic_harvest_yield_and_replanting()


## -----------------------------------------------------------------------------
## T05 / T36: Atomic Harvest Rejection Under Full Bag (Zero Loss Invariance)
## -----------------------------------------------------------------------------
func test_t05_harvest_capacity_atomic_rejection() -> bool:
	print("    [RUN] T05/T36: Atomic Harvest Rejection Under Full Bag (11/12 Slots, 12/12 Slots & Stack Merging)")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var gm: Node = _create_clean_garden_manager(inv)

	# Prepare plot & grow mature crop on slot_01
	gm.hoe_plot("plot_home_01")
	inv.backpack.add_item("soil_compost", 1)
	gm.add_compost("plot_home_01")
	inv.backpack.add_item("fertilizer_basic", 1)
	gm.fertilize_plot("plot_home_01")
	gm.refill_water()
	gm.water_plot("plot_home_01")

	inv.backpack.add_item("seed_bayam", 1)
	gm.plant_seed("plot_home_01", "slot_01", "seed_bayam")
	gm.simulate_process(180.0) # Fully mature

	# Clear backpack for precise capacity tests
	inv.backpack.clear()

	# --- TEST CASE A: 11 Occupied Slots (1 Free Slot) with 11 Unrelated Full Stacks ---
	# Needs 2 free slots because neither ingredient_bayam nor seed_bayam are in backpack
	for i in range(11):
		inv.backpack.add_item("ingredient_jagung", 20)
	Assertions.assert_equal(inv.backpack.get_empty_slot_count(), 1, "Backpack has exactly 1 empty slot")

	# Harvest must be REJECTED atomically (cannot accommodate 2 items)
	var can_harvest_1_slot = gm.can_harvest_crop("plot_home_01", "slot_01")
	Assertions.assert_false(can_harvest_1_slot["success"], "Harvest must be rejected when only 1 slot is free for 2 items")
	var harvest_1_slot_ok = gm.harvest_crop("plot_home_01", "slot_01")
	Assertions.assert_false(harvest_1_slot_ok, "harvest_crop must return false on insufficient slots")

	# Zero-Loss Invariants:
	Assertions.assert_equal(inv.backpack.get_empty_slot_count(), 1, "Backpack still has exactly 1 empty slot (0 items added)")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 0, "0 bayam added")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 0, "0 seed added")
	Assertions.assert_true(bool(gm.get_spot("plot_home_01", "slot_01")["is_occupied"]), "Crop remains on plot")
	Assertions.assert_true(bool(gm.get_spot("plot_home_01", "slot_01")["crop_data"]["is_ready_to_harvest"]), "Crop remains harvestable")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["nutrients"]), 100.0, 0.001, "Plot nutrients unchanged (no penalty)")

	# --- TEST CASE B: 12 Occupied Slots (0 Free Slots) ---
	inv.backpack.add_item("ingredient_temu_kunci", 20) # Fills 12th slot
	Assertions.assert_equal(inv.backpack.get_empty_slot_count(), 0, "Backpack is 100% full (0 empty slots)")

	var can_harvest_0_slots = gm.can_harvest_crop("plot_home_01", "slot_01")
	Assertions.assert_false(can_harvest_0_slots["success"], "Harvest rejected when backpack is 100% full")
	Assertions.assert_false(gm.harvest_crop("plot_home_01", "slot_01"), "harvest_crop returns false when 100% full")

	# --- TEST CASE C: 11 Occupied Slots (1 Free Slot) BUT seed_bayam exists with count < 20 ---
	# seed_bayam merges into existing stack, free slot takes ingredient_bayam -> BOTH FIT!
	inv.backpack.clear()
	inv.backpack.add_item("seed_bayam", 5) # Slot 0: 5 seeds (can take 15 more)
	for i in range(10): # Slots 1..10 filled
		inv.backpack.add_item("ingredient_jagung", 20)
	Assertions.assert_equal(inv.backpack.get_empty_slot_count(), 1, "Backpack has 1 empty slot and 1 seed stack with room")

	var can_harvest_stacking = gm.can_harvest_crop("plot_home_01", "slot_01")
	Assertions.assert_true(can_harvest_stacking["success"], "Harvest allowed when 1 item stacks and 1 item takes empty slot")
	var harvest_stack_ok = gm.harvest_crop("plot_home_01", "slot_01")
	Assertions.assert_true(harvest_stack_ok, "harvest_crop succeeds via stack merging")

	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 6, "Seed count incremented to 6 in existing stack")
	var bayam_cnt: int = inv.backpack.get_item_count("ingredient_bayam")
	if bayam_cnt == 0:
		bayam_cnt = inv.backpack.get_item_count("crop_bayam")
	Assertions.assert_equal(bayam_cnt, 1, "Bayam added to the 1 empty slot")
	Assertions.assert_false(bool(gm.get_spot("plot_home_01", "slot_01")["is_occupied"]), "Crop harvested successfully")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["nutrients"]), 95.0, 0.001, "Nutrients reduced to 95.0")

	if Assertions.current_suite_failed == initial_failures:
		print("    [PASS] T05/T36: Atomic Harvest Rejection Under Full Bag verified.")
		return true
	return false

# Alias for dispatch numbering compatibility
func test_t36_harvest_capacity_rejection() -> bool:
	return test_t05_harvest_capacity_atomic_rejection()


## -----------------------------------------------------------------------------
## Multi-Spot Staggered Growth and Harvest Isolation
## -----------------------------------------------------------------------------
func test_multi_spot_staggered_growth_and_harvest() -> bool:
	print("    [RUN] Multi-Spot Staggered Growth and Harvest Isolation (Independent Progression)")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var gm: Node = _create_clean_garden_manager(inv)

	# Prepare plot
	gm.hoe_plot("plot_home_01")
	inv.backpack.add_item("soil_compost", 1)
	gm.add_compost("plot_home_01")
	inv.backpack.add_item("fertilizer_basic", 1)
	gm.fertilize_plot("plot_home_01")
	gm.refill_water()
	gm.water_plot("plot_home_01")

	inv.backpack.add_item("seed_bayam", 4)

	# Timeline:
	# t = 0s: Plant slot_01
	gm.plant_seed("plot_home_01", "slot_01", "seed_bayam")

	# Advance 60s: slot_01 is now 60s (Stage 1 Sprout)
	gm.simulate_process(60.0)
	Assertions.assert_equal(int(gm.get_spot("plot_home_01", "slot_01")["crop_data"]["growth_stage"]), 1)

	# Plant slot_02
	gm.plant_seed("plot_home_01", "slot_02", "seed_bayam")
	Assertions.assert_equal(int(gm.get_spot("plot_home_01", "slot_02")["crop_data"]["growth_stage"]), 0)

	# Advance 60s:
	# slot_01 is now 120s (Stage 2 Growing)
	# slot_02 is now 60s (Stage 1 Sprout)
	gm.simulate_process(60.0)
	Assertions.assert_equal(int(gm.get_spot("plot_home_01", "slot_01")["crop_data"]["growth_stage"]), 2)
	Assertions.assert_equal(int(gm.get_spot("plot_home_01", "slot_02")["crop_data"]["growth_stage"]), 1)

	# Plant slot_03
	gm.plant_seed("plot_home_01", "slot_03", "seed_bayam")
	Assertions.assert_equal(int(gm.get_spot("plot_home_01", "slot_03")["crop_data"]["growth_stage"]), 0)

	# Advance 60s:
	# slot_01 is now 180s (Stage 3 Harvestable)
	# slot_02 is now 120s (Stage 2 Growing)
	# slot_03 is now 60s (Stage 1 Sprout)
	# slot_04 remains unoccupied
	gm.simulate_process(60.0)
	Assertions.assert_equal(int(gm.get_spot("plot_home_01", "slot_01")["crop_data"]["growth_stage"]), 3)
	Assertions.assert_true(bool(gm.get_spot("plot_home_01", "slot_01")["crop_data"]["is_ready_to_harvest"]))

	Assertions.assert_equal(int(gm.get_spot("plot_home_01", "slot_02")["crop_data"]["growth_stage"]), 2)
	Assertions.assert_false(bool(gm.get_spot("plot_home_01", "slot_02")["crop_data"]["is_ready_to_harvest"]))

	Assertions.assert_equal(int(gm.get_spot("plot_home_01", "slot_03")["crop_data"]["growth_stage"]), 1)
	Assertions.assert_false(bool(gm.get_spot("plot_home_01", "slot_03")["crop_data"]["is_ready_to_harvest"]))

	Assertions.assert_false(bool(gm.get_spot("plot_home_01", "slot_04")["is_occupied"]))

	# Harvest ONLY slot_01
	Assertions.assert_true(gm.harvest_crop("plot_home_01", "slot_01"), "Harvest slot_01 succeeds")
	Assertions.assert_false(bool(gm.get_spot("plot_home_01", "slot_01")["is_occupied"]), "slot_01 cleared")

	# Spots 2 and 3 must remain completely intact
	Assertions.assert_true(bool(gm.get_spot("plot_home_01", "slot_02")["is_occupied"]), "slot_02 untouched")
	Assertions.assert_equal(int(gm.get_spot("plot_home_01", "slot_02")["crop_data"]["growth_stage"]), 2)
	Assertions.assert_true(bool(gm.get_spot("plot_home_01", "slot_03")["is_occupied"]), "slot_03 untouched")
	Assertions.assert_equal(int(gm.get_spot("plot_home_01", "slot_03")["crop_data"]["growth_stage"]), 1)

	if Assertions.current_suite_failed == initial_failures:
		print("    [PASS] Multi-Spot Staggered Growth and Harvest Isolation verified.")
		return true
	return false


## -----------------------------------------------------------------------------
## GARD-002 Save/Load Persistence Roundtrip (SAVE-001 Contract)
## -----------------------------------------------------------------------------
func test_gard02_save_snapshot_growth_persistence() -> bool:
	print("    [RUN] GARD-002 Save/Load Persistence Roundtrip (Growth Stage & Timer Persistence)")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var gm: Node = _create_clean_garden_manager(inv)

	# Setup active plot with varied spot states
	gm.hoe_plot("plot_home_01")
	inv.backpack.add_item("soil_compost", 1)
	gm.add_compost("plot_home_01")
	inv.backpack.add_item("fertilizer_basic", 1)
	gm.fertilize_plot("plot_home_01")
	gm.refill_water()
	gm.water_plot("plot_home_01")

	inv.backpack.add_item("seed_bayam", 3)
	gm.plant_seed("plot_home_01", "slot_01", "seed_bayam")
	gm.simulate_process(60.0) # slot_01 at 60s (stage 1)

	gm.plant_seed("plot_home_01", "slot_02", "seed_bayam")
	gm.simulate_process(60.0) # slot_01 at 120s (stage 2), slot_02 at 60s (stage 1)

	gm.plant_seed("plot_home_01", "slot_03", "seed_bayam")
	gm.simulate_process(60.0) # slot_01 at 180s (stage 3, ready), slot_02 at 120s (stage 2), slot_03 at 60s (stage 1)

	# Take save snapshot
	var snapshot: Dictionary = gm.get_save_snapshot()
	Assertions.assert_true(snapshot.has("plots"), "Snapshot contains plots")

	# Reset manager
	gm.reset_to_defaults()
	Assertions.assert_false(gm.get_plot("plot_home_01")["is_hoed"], "Reset unhoes plot")
	Assertions.assert_false(gm.get_spot("plot_home_01", "slot_01")["is_occupied"], "Reset clears slot_01")

	# Restore snapshot
	Assertions.assert_true(gm.load_save_snapshot(snapshot), "load_save_snapshot succeeds")

	# Verify restored states
	var restored_sp1 = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_true(restored_sp1["is_occupied"])
	Assertions.assert_equal(int(restored_sp1["crop_data"]["growth_stage"]), 3)
	Assertions.assert_approx_equal(float(restored_sp1["crop_data"]["growth_time"]), 180.0, 0.001)
	Assertions.assert_true(bool(restored_sp1["crop_data"]["is_ready_to_harvest"]))

	var restored_sp2 = gm.get_spot("plot_home_01", "slot_02")
	Assertions.assert_true(restored_sp2["is_occupied"])
	Assertions.assert_equal(int(restored_sp2["crop_data"]["growth_stage"]), 2)
	Assertions.assert_approx_equal(float(restored_sp2["crop_data"]["growth_time"]), 120.0, 0.001)

	var restored_sp3 = gm.get_spot("plot_home_01", "slot_03")
	Assertions.assert_true(restored_sp3["is_occupied"])
	Assertions.assert_equal(int(restored_sp3["crop_data"]["growth_stage"]), 1)
	Assertions.assert_approx_equal(float(restored_sp3["crop_data"]["growth_time"]), 60.0, 0.001)

	var restored_sp4 = gm.get_spot("plot_home_01", "slot_04")
	Assertions.assert_false(restored_sp4["is_occupied"])

	if Assertions.current_suite_failed == initial_failures:
		print("    [PASS] GARD-002 Save/Load Persistence Roundtrip verified.")
		return true
	return false
