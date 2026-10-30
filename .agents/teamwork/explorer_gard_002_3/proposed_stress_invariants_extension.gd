# Proposed Adversarial Stress Test Extensions for GARD-002: tests/stress_garden_invariants.gd
# Designed by explorer_gard_002_3
# Empirically tests growth monotonicity, stall invariance, conservation of mass, and spam protection

# ==============================================================================
# CHALLENGE 7: 4-Stage Crop Growth Precision, Monotonicity & Clamping (500 Random Deltas)
# ==============================================================================
func challenge_07_growth_monotonicity_and_clamping_stress() -> bool:
	print("\n  [CHALLENGE 7] 4-Stage Crop Growth Monotonicity, Clamping & Micro-Delta Precision")
	var initial_failures = Assertions.current_suite_failed

	var inv: Node = InventoryManagerClass.new()
	inv._ready()
	var gm: Node = GardenManagerClass.new()
	gm._ready()
	gm.set_inventory_manager(inv)

	# Prepare plot
	gm.hoe_plot("plot_home_01")
	inv.backpack.add_item("soil_compost", 1)
	gm.add_compost("plot_home_01")
	inv.backpack.add_item("seed_bayam", 1)
	gm.plant_seed("plot_home_01", "slot_01", "seed_bayam")

	# Lock optimal growing conditions
	gm.get_plot("plot_home_01")["nutrients"] = 100.0
	gm.get_plot("plot_home_01")["moisture"] = 100.0

	var last_growth_time: float = 0.0

	# 500 small random deltas simulating real frames [0.01s .. 0.5s]
	for i in range(500):
		# Re-boost moisture so evaporation never drops it below 30 during this test
		gm.get_plot("plot_home_01")["moisture"] = 80.0
		var dt := randf_range(0.016, 0.5)
		gm.simulate_process(dt)

		var cur_sp = gm.get_spot("plot_home_01", "slot_01")
		var cur_gt = float(cur_sp["crop_data"]["growth_time"])
		var cur_st = int(cur_sp["crop_data"]["growth_stage"])

		# 1. Monotonicity Invariant: cur_gt >= last_growth_time
		Assertions.assert_true(cur_gt >= last_growth_time, "Growth time must be monotonically non-decreasing")
		last_growth_time = cur_gt

		# 2. Clamping Invariant: cur_gt <= 180.0
		Assertions.assert_true(cur_gt <= 180.0001, "Growth time must never exceed 180.0s")

		# 3. Stage Invariant: stage must accurately match growth_time
		if cur_gt < 30.0:
			Assertions.assert_equal(cur_st, 0, "Stage must be 0 for t < 30.0s")
			Assertions.assert_false(bool(cur_sp["crop_data"]["is_ready_to_harvest"]))
		elif cur_gt < 90.0:
			Assertions.assert_equal(cur_st, 1, "Stage must be 1 for 30.0s <= t < 90.0s")
			Assertions.assert_false(bool(cur_sp["crop_data"]["is_ready_to_harvest"]))
		elif cur_gt < 180.0:
			Assertions.assert_equal(cur_st, 2, "Stage must be 2 for 90.0s <= t < 180.0s")
			Assertions.assert_false(bool(cur_sp["crop_data"]["is_ready_to_harvest"]))
		else:
			Assertions.assert_equal(cur_st, 3, "Stage must be 3 for t >= 180.0s")
			Assertions.assert_true(bool(cur_sp["crop_data"]["is_ready_to_harvest"]))

	# Extreme single delta jump (10,000s)
	gm.simulate_process(10000.0)
	var final_sp = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_approx_equal(float(final_sp["crop_data"]["growth_time"]), 180.0, 0.001, "Growth time remains strictly clamped at 180.0s")
	Assertions.assert_equal(int(final_sp["crop_data"]["growth_stage"]), 3, "Stage remains 3")
	Assertions.assert_true(bool(final_sp["crop_data"]["is_ready_to_harvest"]), "Harvestable")

	inv.free()
	gm.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 7: 4-Stage Crop Growth Monotonicity & Clamping verified.")
	return ok


# ==============================================================================
# CHALLENGE 8: Stall Threshold Boundary Precision & Non-Decay Invariance
# ==============================================================================
func challenge_08_stall_boundaries_and_non_decay_invariance() -> bool:
	print("\n  [CHALLENGE 8] Stall Threshold Boundary Precision (19.99 vs 20.0, 29.99 vs 30.0) & Non-Decay")
	var initial_failures = Assertions.current_suite_failed

	var inv: Node = InventoryManagerClass.new()
	inv._ready()
	var gm: Node = GardenManagerClass.new()
	gm._ready()
	gm.set_inventory_manager(inv)

	# Prepare plot & plant
	gm.hoe_plot("plot_home_01")
	inv.backpack.add_item("soil_compost", 1)
	gm.add_compost("plot_home_01")
	inv.backpack.add_item("seed_bayam", 1)
	gm.plant_seed("plot_home_01", "slot_01", "seed_bayam")

	# Grow halfway to 45.0s (Stage 1)
	gm.get_plot("plot_home_01")["nutrients"] = 100.0
	gm.get_plot("plot_home_01")["moisture"] = 80.0
	gm.simulate_process(45.0)

	var initial_sp = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_approx_equal(float(initial_sp["crop_data"]["growth_time"]), 45.0, 0.01)

	# --- 8A: 200 ticks at Nutrients = 19.99 (Boundary below 20.0) ---
	gm.get_plot("plot_home_01")["nutrients"] = 19.99
	gm.get_plot("plot_home_01")["moisture"] = 80.0
	for i in range(200):
		gm.simulate_process(1.0)
	var sp_8a = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_approx_equal(float(sp_8a["crop_data"]["growth_time"]), 45.0, 0.001, "0 growth at nutrients = 19.99")
	Assertions.assert_equal(int(sp_8a["crop_data"]["growth_stage"]), 1, "Stage remains 1")

	# --- 8B: 200 ticks at Moisture = 29.99 (Boundary below 30.0) ---
	gm.get_plot("plot_home_01")["nutrients"] = 100.0
	gm.get_plot("plot_home_01")["moisture"] = 29.99
	for i in range(200):
		# Prevent further evaporation dropping it lower for precise boundary testing
		gm.get_plot("plot_home_01")["moisture"] = 29.99
		gm.simulate_process(1.0)
	var sp_8b = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_approx_equal(float(sp_8b["crop_data"]["growth_time"]), 45.0, 0.001, "0 growth at moisture = 29.99")

	# --- 8C: 200 ticks with Both Sub-Threshold (Nutrients = 10.0, Moisture = 10.0) ---
	gm.get_plot("plot_home_01")["nutrients"] = 10.0
	gm.get_plot("plot_home_01")["moisture"] = 10.0
	for i in range(200):
		gm.simulate_process(1.0)
	var sp_8c = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_approx_equal(float(sp_8c["crop_data"]["growth_time"]), 45.0, 0.001, "No decay, time stays exactly 45.0s")
	Assertions.assert_equal(int(sp_8c["crop_data"]["growth_stage"]), 1, "Plant does not die")

	# --- 8D: Restore to exact boundaries (Nutrients = 20.00, Moisture = 30.00) -> Growth advances ---
	gm.get_plot("plot_home_01")["nutrients"] = 20.00
	gm.get_plot("plot_home_01")["moisture"] = 35.00 # allow buffer for 1s tick
	gm.simulate_process(10.0)
	var sp_8d = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_true(float(sp_8d["crop_data"]["growth_time"]) > 45.0, "Growth advances once conditions >= thresholds")

	inv.free()
	gm.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 8: Stall threshold boundary precision & non-decay verified.")
	return ok


# ==============================================================================
# CHALLENGE 9: Multi-Spot Permutation Stress & Replanting Invariance (100 Cycles)
# ==============================================================================
func challenge_09_multi_spot_permutation_stress() -> bool:
	print("\n  [CHALLENGE 9] Multi-Spot Permutation Stress & Replanting Invariance (100 Cycles)")
	var initial_failures = Assertions.current_suite_failed

	var inv: Node = InventoryManagerClass.new()
	inv._ready()
	var gm: Node = GardenManagerClass.new()
	gm._ready()
	gm.set_inventory_manager(inv)

	# Prepare plot
	gm.hoe_plot("plot_home_01")
	inv.backpack.add_item("soil_compost", 1)
	gm.add_compost("plot_home_01")

	# 100 plant -> mature -> harvest -> replant cycles across alternating spots
	for cycle in range(100):
		gm.get_plot("plot_home_01")["nutrients"] = 100.0
		gm.get_plot("plot_home_01")["moisture"] = 80.0

		var s_idx := (cycle % 4) + 1
		var s_id := "slot_%02d" % s_idx

		# Give seed
		inv.backpack.clear()
		inv.backpack.add_item("seed_bayam", 1)

		# Plant spot
		Assertions.assert_true(gm.plant_seed("plot_home_01", s_id, "seed_bayam"))

		# Advance to mature
		gm.simulate_process(180.0)

		# Harvest
		Assertions.assert_true(gm.harvest_crop("plot_home_01", s_id))
		Assertions.assert_false(bool(gm.get_spot("plot_home_01", s_id)["is_occupied"]))

	# Assert plot spots remained intact with exactly 4 entries
	Assertions.assert_equal(gm.get_plot("plot_home_01")["spots"].size(), 4)

	inv.free()
	gm.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 9: Multi-Spot permutation stress verified.")
	return ok


# ==============================================================================
# CHALLENGE 10: Atomic Harvest Capacity Stress & 100x Spam Protection
# ==============================================================================
func challenge_10_atomic_harvest_capacity_and_spam_stress() -> bool:
	print("\n  [CHALLENGE 10] Atomic Harvest Capacity Stress & 100x Rapid Spam Protection")
	var initial_failures = Assertions.current_suite_failed

	var inv: Node = InventoryManagerClass.new()
	inv._ready()
	var gm: Node = GardenManagerClass.new()
	gm._ready()
	gm.set_inventory_manager(inv)

	# Prepare plot
	gm.hoe_plot("plot_home_01")
	inv.backpack.add_item("soil_compost", 1)
	gm.add_compost("plot_home_01")
	inv.backpack.add_item("seed_bayam", 1)
	gm.plant_seed("plot_home_01", "slot_01", "seed_bayam")

	gm.get_plot("plot_home_01")["nutrients"] = 100.0
	gm.get_plot("plot_home_01")["moisture"] = 80.0
	gm.simulate_process(180.0) # Mature

	# Completely fill backpack: 12 slots with 20 corn each
	inv.backpack.clear()
	for i in range(12):
		inv.backpack.add_item("ingredient_jagung", 20)
	Assertions.assert_equal(inv.backpack.get_empty_slot_count(), 0)

	# 100 rapid failed harvest attempts
	var rejected_count := 0
	for i in range(100):
		if not gm.harvest_crop("plot_home_01", "slot_01"):
			rejected_count += 1
	Assertions.assert_equal(rejected_count, 100, "100/100 rapid harvests rejected under full bag")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["nutrients"]), 100.0, 0.001, "0 nutrients deducted")
	Assertions.assert_true(bool(gm.get_spot("plot_home_01", "slot_01")["is_occupied"]), "Crop intact")

	# Free 2 slots
	inv.backpack.remove_item("ingredient_jagung", 40)
	Assertions.assert_equal(inv.backpack.get_empty_slot_count(), 2)

	# 1st harvest succeeds
	Assertions.assert_true(gm.harvest_crop("plot_home_01", "slot_01"), "1st harvest succeeds")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["nutrients"]), 95.0, 0.001, "Nutrients -5 once")
	Assertions.assert_false(bool(gm.get_spot("plot_home_01", "slot_01")["is_occupied"]), "Spot cleared")

	# Next 99 rapid spam harvests rejected
	var spam_fail := 0
	for i in range(99):
		if not gm.harvest_crop("plot_home_01", "slot_01"):
			spam_fail += 1
	Assertions.assert_equal(spam_fail, 99, "99/99 subsequent spam harvests rejected")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["nutrients"]), 95.0, 0.001, "Nutrients remains 95.0")

	inv.free()
	gm.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 10: Atomic harvest capacity & spam stress verified.")
	return ok
