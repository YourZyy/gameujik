extends SceneTree

## Adversarial Stress Test Harness for Milestone GARD-001
## Empirically challenges:
## 1. Area thresholds (<20 fertilize, <60 water) under 100 rapid hammer attempts
## 2. Evaporation simulation loop (0.1/s) deterministic, micro-ticks, pause gating (T33), and zero clamping
## 3. Multi-spot isolation across 4 quadrants with deep mutation and aliasing
## 4. Zero-softlock starter inventory lifecycle (conservation of mass, out-of-order defense)
## 5. Split-container atomic consumption (backpack + storage_home)
## 6. HoldActionController state machine and anti-retrigger defense

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const GardenManagerClass = preload("res://scripts/gardening/garden_manager.gd")
const HoldActionControllerClass = preload("res://scripts/gardening/hold_action_controller.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")

var _frame: int = 0
var _all_passed: bool = true

func _process(delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		run_all_challenges()
		finish_and_quit()
		return true
	return false

func finish_and_quit() -> void:
	print("==================================================")
	print("[STRESS_GARDEN_INVARIANTS] SUMMARY:")
	print("  Assertions Passed: %d" % Assertions.current_suite_passed)
	print("  Assertions Failed: %d" % Assertions.current_suite_failed)

	if _all_passed and Assertions.current_suite_failed == 0:
		print("  FINAL VERDICT: CONFIRMED CORRECT")
		print("  All GARD-001 empirical invariants survived adversarial stress testing.")
		print("==================================================")
		quit(0)
	else:
		printerr("  FINAL VERDICT: DEFECT DETECTED")
		printerr("  Garden invariant failures encountered:")
		for msg in Assertions.failure_messages:
			printerr("    - ", msg)
		print("==================================================")
		quit(1)

func run_all_challenges() -> void:
	print("==================================================")
	print("[STRESS_GARDEN_INVARIANTS] Adversarial Empirical Verification")
	print("Milestone: GARD-001 (Thresholds, Evaporation, Spot Isolation, Lifecycle)")
	print("==================================================")

	Assertions.reset()

	# Challenge 1: Area Thresholds Rapid Stress (100 rapid attempts & boundary testing)
	if not challenge_01_area_thresholds_rapid_stress():
		_all_passed = false

	# Challenge 2: Evaporation Loop Precision, Pause Gating & Underflow (T33)
	if not challenge_02_evaporation_precision_and_pause_gating():
		_all_passed = false

	# Challenge 3: Multi-Spot Isolation, Mutation Isolation & Aliasing
	if not challenge_03_multi_spot_isolation_and_aliasing():
		_all_passed = false

	# Challenge 4: Zero-Softlock Starter Inventory Lifecycle & Mass Conservation
	if not challenge_04_zero_softlock_starter_lifecycle():
		_all_passed = false

	# Challenge 5: Split Inventory Consumption (Backpack + Storage_Home)
	if not challenge_05_split_inventory_consumption():
		_all_passed = false

	# Challenge 6: Hold Action Controller State Machine & Anti-Spam Retrigger
	if not challenge_06_hold_controller_state_machine_stress():
		_all_passed = false

	# Challenge 7: 4-Stage Crop Growth Precision, Monotonicity & Clamping (500 Random Deltas)
	if not challenge_07_growth_monotonicity_and_clamping_stress():
		_all_passed = false

	# Challenge 8: Stall Threshold Boundary Precision & Non-Decay Invariance
	if not challenge_08_stall_boundaries_and_non_decay_invariance():
		_all_passed = false

	# Challenge 9: Multi-Spot Permutation Stress & Replanting Invariance (100 Cycles)
	if not challenge_09_multi_spot_permutation_stress():
		_all_passed = false

	# Challenge 10: Atomic Harvest Capacity Stress & 100x Rapid Spam Protection
	if not challenge_10_atomic_harvest_capacity_and_spam_stress():
		_all_passed = false

# ==============================================================================
# CHALLENGE 1: Area Thresholds Rapid Stress
# ==============================================================================
func challenge_01_area_thresholds_rapid_stress() -> bool:
	print("\n  [CHALLENGE 1] Area Thresholds 100x Rapid Hammer Stress & Boundary Precision")
	var initial_failures = Assertions.current_suite_failed

	var inv: Node = InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.storage_home.clear()

	var gm: Node = GardenManagerClass.new()
	gm._ready()
	gm.set_inventory_manager(inv)

	# --- 1A: 100 rapid attempts to fertilize at nutrients >= 20 (nutrients = 20.0 boundary) ---
	inv.backpack.add_item("fertilizer_basic", 5)
	gm.get_plot("plot_home_01")["nutrients"] = 20.0

	var fert_fail_count := 0
	for i in range(100):
		var ok = gm.fertilize_plot("plot_home_01")
		if not ok:
			fert_fail_count += 1

	Assertions.assert_equal(fert_fail_count, 100, "100/100 rapid fertilize attempts rejected at nutrients = 20.0")
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 5, "0 fertilizer consumed across 100 failed attempts at nutrients = 20.0")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["nutrients"]), 20.0, 0.0001, "Nutrients remains exactly 20.0")

	# --- 1B: 100 rapid attempts to fertilize at nutrients = 100.0 ---
	gm.get_plot("plot_home_01")["nutrients"] = 100.0
	fert_fail_count = 0
	for i in range(100):
		var ok = gm.fertilize_plot("plot_home_01")
		if not ok:
			fert_fail_count += 1

	Assertions.assert_equal(fert_fail_count, 100, "100/100 rapid fertilize attempts rejected at nutrients = 100.0")
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 5, "0 fertilizer consumed at nutrients = 100.0")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["nutrients"]), 100.0, 0.0001, "Nutrients remains 100.0")

	# --- 1C: Boundary test for fertilizer threshold: 19.99 vs 20.00 vs 20.01 ---
	gm.get_plot("plot_home_01")["nutrients"] = 19.99
	var fert_check_below = gm.can_fertilize_plot("plot_home_01")
	Assertions.assert_true(fert_check_below["success"], "Fertilize allowed at 19.99 nutrients (< 20.0)")

	gm.get_plot("plot_home_01")["nutrients"] = 20.00
	var fert_check_exact = gm.can_fertilize_plot("plot_home_01")
	Assertions.assert_false(fert_check_exact["success"], "Fertilize rejected at exactly 20.00 nutrients (>= 20.0)")
	Assertions.assert_equal(fert_check_exact["reason"], "Kondisi cukup. Tidak ada bahan yang digunakan.")

	gm.get_plot("plot_home_01")["nutrients"] = 20.01
	var fert_check_above = gm.can_fertilize_plot("plot_home_01")
	Assertions.assert_false(fert_check_above["success"], "Fertilize rejected at 20.01 nutrients (>= 20.0)")

	# --- 1D: 100 rapid attempts to water at moisture >= 60 (moisture = 60.0 boundary) ---
	gm.watering_can_water = 10
	gm.get_plot("plot_home_01")["moisture"] = 60.0

	var water_fail_count := 0
	for i in range(100):
		var ok = gm.water_plot("plot_home_01")
		if not ok:
			water_fail_count += 1

	Assertions.assert_equal(water_fail_count, 100, "100/100 rapid water attempts rejected at moisture = 60.0")
	Assertions.assert_equal(gm.watering_can_water, 10, "0 water units consumed across 100 failed attempts at moisture = 60.0")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["moisture"]), 60.0, 0.0001, "Moisture remains exactly 60.0")

	# --- 1E: 100 rapid attempts to water at moisture = 80.0 ---
	gm.get_plot("plot_home_01")["moisture"] = 80.0
	water_fail_count = 0
	for i in range(100):
		var ok = gm.water_plot("plot_home_01")
		if not ok:
			water_fail_count += 1

	Assertions.assert_equal(water_fail_count, 100, "100/100 rapid water attempts rejected at moisture = 80.0")
	Assertions.assert_equal(gm.watering_can_water, 10, "0 water units consumed at moisture = 80.0")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["moisture"]), 80.0, 0.0001, "Moisture remains 80.0")

	# --- 1F: Boundary test for watering threshold: 59.99 vs 60.00 vs 60.01 ---
	gm.get_plot("plot_home_01")["moisture"] = 59.99
	var water_check_below = gm.can_water_plot("plot_home_01")
	Assertions.assert_true(water_check_below["success"], "Watering allowed at 59.99 moisture (< 60.0)")

	gm.get_plot("plot_home_01")["moisture"] = 60.00
	var water_check_exact = gm.can_water_plot("plot_home_01")
	Assertions.assert_false(water_check_exact["success"], "Watering rejected at exactly 60.00 moisture (>= 60.0)")
	Assertions.assert_equal(water_check_exact["reason"], "Petak sudah cukup. Tidak ada bahan yang digunakan.")

	gm.get_plot("plot_home_01")["moisture"] = 60.01
	var water_check_above = gm.can_water_plot("plot_home_01")
	Assertions.assert_false(water_check_above["success"], "Watering rejected at 60.01 moisture (>= 60.0)")

	# --- 1G: 100 rapid attempts to water with insufficient water (1 unit < 2 cost) ---
	gm.get_plot("plot_home_01")["moisture"] = 0.0
	gm.watering_can_water = 1

	var low_water_fails := 0
	for i in range(100):
		var ok = gm.water_plot("plot_home_01")
		if not ok:
			low_water_fails += 1

	Assertions.assert_equal(low_water_fails, 100, "100/100 water attempts rejected when watering_can has 1 unit (< 2 required)")
	Assertions.assert_equal(gm.watering_can_water, 1, "Water level remains exactly 1")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["moisture"]), 0.0, 0.0001, "Moisture remains 0.0")

	# --- 1H: 100 rapid attempts to refill when already at max capacity (10/10) ---
	gm.watering_can_water = 10
	var refill_fails := 0
	for i in range(100):
		var ok = gm.refill_water()
		if not ok:
			refill_fails += 1

	Assertions.assert_equal(refill_fails, 100, "100/100 refill attempts rejected when can is full (10/10)")
	Assertions.assert_equal(gm.watering_can_water, 10, "Water level remains 10")

	# Cleanup
	inv.free()
	gm.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 1: Area thresholds 100x rapid hammer & boundaries verified.")
	else:
		printerr("    [FAIL] Challenge 1: Area thresholds rapid hammer failed.")
	return ok

# ==============================================================================
# CHALLENGE 2: Evaporation Simulation Loop & Pause Gating
# ==============================================================================
func challenge_02_evaporation_precision_and_pause_gating() -> bool:
	print("\n  [CHALLENGE 2] Evaporation Simulation Loop Precision, Pause Gating & Underflow (T33)")
	var initial_failures = Assertions.current_suite_failed

	var gm: Node = GardenManagerClass.new()
	gm._ready()

	# --- 2A: 100 seconds active simulation (single tick) ---
	gm.get_plot("plot_home_01")["moisture"] = 80.0
	gm.simulate_process(100.0)
	var m2a = float(gm.get_plot("plot_home_01")["moisture"])
	# 80.0 - (0.1 * 100.0) = 70.0
	Assertions.assert_approx_equal(m2a, 70.0, 0.0001, "100s single active delta evaporates exactly 10.0 units (80 -> 70)")

	# --- 2B: 100 seconds active simulation via 1000 micro-ticks of 0.1s ---
	# From 70.0, 1000 * 0.1s = 100s -> 70.0 - 10.0 = 60.0
	for i in range(1000):
		gm.simulate_process(0.1)
	var m2b = float(gm.get_plot("plot_home_01")["moisture"])
	Assertions.assert_approx_equal(m2b, 60.0, 0.0001, "1000 micro-ticks of 0.1s evaporates exactly 10.0 units (70 -> 60) with no drift")

	# --- 2C: 100 seconds paused simulation via MockInputManager (1000 micro-ticks of 0.1s) ---
	var mock_im := MockInputManager.new(true) # simulation paused
	gm.set_input_manager(mock_im)
	gm.get_plot("plot_home_01")["moisture"] = 60.0
	var m_before_pause := float(gm.get_plot("plot_home_01")["moisture"])

	for i in range(1000):
		gm.simulate_process(0.1)
	var m2c = float(gm.get_plot("plot_home_01")["moisture"])
	Assertions.assert_equal(m2c, m_before_pause, "Moisture strictly halted at 60.0 across 1000 frames while InputManager is paused")

	# --- 2D: Single large delta of 100s while paused ---
	gm.simulate_process(100.0)
	var m2d = float(gm.get_plot("plot_home_01")["moisture"])
	Assertions.assert_equal(m2d, m_before_pause, "Moisture strictly halted at 60.0 after 100s single tick while InputManager is paused")

	# --- 2E: Interleaved active & paused cycles (50 cycles: 1s active, 1s paused) ---
	# Expected active time: 50 * 1.0s = 50s -> 5.0 units evaporated. 60.0 -> 55.0
	for i in range(50):
		mock_im.paused = false
		gm.simulate_process(1.0)
		mock_im.paused = true
		gm.simulate_process(1.0)

	var m2e = float(gm.get_plot("plot_home_01")["moisture"])
	Assertions.assert_approx_equal(m2e, 55.0, 0.0001, "Interleaved 50s active + 50s paused evaporates exactly 5.0 units (60 -> 55)")

	# --- 2F: Underflow and Clamping at 0.0 ---
	mock_im.paused = false
	gm.get_plot("plot_home_01")["moisture"] = 0.3
	# Evaporate for 100s (would be -9.7 if not clamped)
	gm.simulate_process(100.0)
	var m2f = float(gm.get_plot("plot_home_01")["moisture"])
	Assertions.assert_equal(m2f, 0.0, "Moisture strictly clamps at 0.0 and never drops negative")
	Assertions.assert_false(m2f < 0.0, "Moisture is not negative")

	# Additional 500s when already at 0.0
	gm.simulate_process(500.0)
	var m2f_re = float(gm.get_plot("plot_home_01")["moisture"])
	Assertions.assert_equal(m2f_re, 0.0, "Moisture remains 0.0 when further simulated from 0.0")

	# --- 2G: Extreme delta (1,000,000s) ---
	gm.simulate_process(1000000.0)
	var m2g = float(gm.get_plot("plot_home_01")["moisture"])
	Assertions.assert_equal(m2g, 0.0, "Extreme delta (1,000,000s) remains 0.0 without NaN or overflow")
	Assertions.assert_false(is_nan(m2g), "Moisture is not NaN")
	Assertions.assert_false(is_inf(m2g), "Moisture is not Inf")

	# Cleanup
	mock_im.free()
	gm.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 2: Evaporation precision, pause gating & zero clamping verified.")
	else:
		printerr("    [FAIL] Challenge 2: Evaporation precision and pause gating failed.")
	return ok

# ==============================================================================
# CHALLENGE 3: Multi-Spot Isolation, Mutation Isolation & Aliasing
# ==============================================================================
func challenge_03_multi_spot_isolation_and_aliasing() -> bool:
	print("\n  [CHALLENGE 3] Multi-Spot Isolation, Mutation Isolation & Aliasing Oracle")
	var initial_failures = Assertions.current_suite_failed

	var inv: Node = InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.storage_home.clear()

	var gm: Node = GardenManagerClass.new()
	gm._ready()
	gm.set_inventory_manager(inv)

	# Hoe and compost plot
	gm.hoe_plot("plot_home_01")
	inv.backpack.add_item("soil_compost", 1)
	gm.add_compost("plot_home_01")

	# Add 4 seeds
	inv.backpack.add_item("seed_bayam", 4)

	# --- 3A: Baseline 4 spots exist and unoccupied ---
	for i in range(1, 5):
		var s_id := "slot_%02d" % i
		var spot = gm.get_spot("plot_home_01", s_id)
		Assertions.assert_false(spot.is_empty(), "Spot %s must exist" % s_id)
		Assertions.assert_false(spot["is_occupied"], "Spot %s starts unoccupied" % s_id)
		Assertions.assert_null(spot["crop_data"], "Spot %s starts with null crop_data" % s_id)

	# --- 3B: Plant slot_01 only ---
	var plant_ok1 = gm.plant_seed("plot_home_01", "slot_01", "seed_bayam")
	Assertions.assert_true(plant_ok1, "Planting slot_01 succeeds")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 3, "1 seed consumed (3 left)")

	# Spot 1 is occupied
	var sp1 = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_true(sp1["is_occupied"], "slot_01 is occupied")
	Assertions.assert_not_null(sp1["crop_data"], "slot_01 crop_data exists")
	Assertions.assert_equal(sp1["crop_data"]["crop_id"], "crop_bayam", "slot_01 crop_id is crop_bayam")
	Assertions.assert_equal(sp1["crop_data"]["growth_stage"], 0, "slot_01 growth_stage is 0")

	# Spots 2, 3, 4 remain strictly unoccupied and unmodified
	for i in [2, 3, 4]:
		var s_id := "slot_%02d" % i
		var sp = gm.get_spot("plot_home_01", s_id)
		Assertions.assert_false(sp["is_occupied"], "Spot %s must remain unoccupied when slot_01 is planted" % s_id)
		Assertions.assert_null(sp["crop_data"], "Spot %s crop_data must remain null" % s_id)

	# --- 3C: Deep Mutation Isolation Test ---
	# Mutate slot_01's internal crop_data directly
	sp1["crop_data"]["growth_stage"] = 3
	sp1["crop_data"]["growth_time"] = 180.0
	sp1["crop_data"]["is_ready_to_harvest"] = true

	# Assert spots 2, 3, 4 did NOT inherit or reference any of slot_01's crop_data
	for i in [2, 3, 4]:
		var s_id := "slot_%02d" % i
		var sp = gm.get_spot("plot_home_01", s_id)
		Assertions.assert_null(sp["crop_data"], "Spot %s crop_data remains null after mutating slot_01" % s_id)

	# --- 3D: Plant slot_03 ---
	var plant_ok3 = gm.plant_seed("plot_home_01", "slot_03", "seed_bayam")
	Assertions.assert_true(plant_ok3, "Planting slot_03 succeeds")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 2, "1 seed consumed (2 left)")

	var sp3 = gm.get_spot("plot_home_01", "slot_03")
	Assertions.assert_true(sp3["is_occupied"], "slot_03 is occupied")
	Assertions.assert_equal(sp3["crop_data"]["growth_stage"], 0, "slot_03 growth_stage is fresh 0")

	# Verify slot_01 preserved its mutated stage 3
	Assertions.assert_equal(sp1["crop_data"]["growth_stage"], 3, "slot_01 preserves its independent stage 3")

	# Verify slot_02 and slot_04 remain empty
	Assertions.assert_false(gm.get_spot("plot_home_01", "slot_02")["is_occupied"], "slot_02 remains empty")
	Assertions.assert_false(gm.get_spot("plot_home_01", "slot_04")["is_occupied"], "slot_04 remains empty")

	# --- 3E: Plant slot_04 and slot_02 using spot_3 and spot_1 aliases ---
	var plant_ok4 = gm.plant_seed("plot_home_01", "spot_3", "seed_bayam") # spot_3 maps to slot_04
	Assertions.assert_true(plant_ok4, "Planting spot_3 alias succeeds")
	Assertions.assert_true(gm.get_spot("plot_home_01", "slot_04")["is_occupied"], "slot_04 is occupied via spot_3")

	var plant_ok2 = gm.plant_seed("plot_home_01", "spot_1", "seed_bayam") # spot_1 maps to slot_02
	Assertions.assert_true(plant_ok2, "Planting spot_1 alias succeeds")
	Assertions.assert_true(gm.get_spot("plot_home_01", "slot_02")["is_occupied"], "slot_02 is occupied via spot_1")

	# All 4 seeds consumed
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 0, "All 4 seeds consumed")

	# --- 3F: Symmetrical aliasing queries ---
	Assertions.assert_equal(gm.resolve_spot_id("spot_0"), "slot_01")
	Assertions.assert_equal(gm.resolve_spot_id("spot_1"), "slot_02")
	Assertions.assert_equal(gm.resolve_spot_id("spot_2"), "slot_03")
	Assertions.assert_equal(gm.resolve_spot_id("spot_3"), "slot_04")
	Assertions.assert_equal(gm.resolve_spot_id("0"), "slot_01")
	Assertions.assert_equal(gm.resolve_spot_id("1"), "slot_02")
	Assertions.assert_equal(gm.resolve_spot_id("2"), "slot_03")
	Assertions.assert_equal(gm.resolve_spot_id("3"), "slot_04")

	# --- 3G: Invalid spot ID rejection without crash or pollution ---
	inv.backpack.add_item("seed_bayam", 5)
	var invalid_spots := ["slot_00", "slot_05", "spot_4", "", "non_existent_spot", "undefined"]
	for bad_id in invalid_spots:
		var can_plant = gm.can_plant_seed("plot_home_01", bad_id, "seed_bayam")
		Assertions.assert_false(can_plant["success"], "Planting on invalid spot '%s' rejected" % bad_id)
		var did_plant = gm.plant_seed("plot_home_01", bad_id, "seed_bayam")
		Assertions.assert_false(did_plant, "plant_seed on '%s' returns false" % bad_id)

	# Assert 0 seeds lost from invalid spot attempts
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 5, "All 5 seeds preserved across invalid spot attempts")

	# Assert plot spots dictionary still contains exactly 4 slots
	var plot = gm.get_plot("plot_home_01")
	Assertions.assert_equal(plot["spots"].size(), 4, "Plot spots dictionary still contains exactly 4 slots (no pollution)")

	# Cleanup
	inv.free()
	gm.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 3: Multi-spot isolation, mutation isolation & aliasing verified.")
	else:
		printerr("    [FAIL] Challenge 3: Multi-spot isolation failed.")
	return ok

# ==============================================================================
# CHALLENGE 4: Zero-Softlock Starter Inventory Lifecycle & Mass Conservation
# ==============================================================================
func challenge_04_zero_softlock_starter_lifecycle() -> bool:
	print("\n  [CHALLENGE 4] Zero-Softlock Starter Inventory Lifecycle & Mass Conservation")
	var initial_failures = Assertions.current_suite_failed

	var inv: Node = InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.storage_home.clear()
	inv.starter_claimed = false

	var gm: Node = GardenManagerClass.new()
	gm._ready()
	gm.set_inventory_manager(inv)

	# --- 4A: Pre-claim Denial (Cannot advance garden without starter items) ---
	Assertions.assert_true(gm.hoe_plot("plot_home_01"), "Hoe plot succeeds (hands-free)")
	Assertions.assert_false(gm.add_compost("plot_home_01"), "Compost rejected with 0 items")
	Assertions.assert_false(gm.plant_seed("plot_home_01", "slot_01"), "Plant rejected without compost/seeds")
	Assertions.assert_false(gm.fertilize_plot("plot_home_01"), "Fertilize rejected with 0 fertilizer")
	Assertions.assert_false(gm.water_plot("plot_home_01"), "Water rejected with 0 water")

	# --- 4B: Claim Starter Container ---
	var claim_ok = inv.pickup_starter_container()
	Assertions.assert_true(claim_ok, "pickup_starter_container succeeds")
	Assertions.assert_true(inv.starter_claimed, "starter_claimed is true")

	# Exact contents received: 4 seed_bayam, 1 soil_compost, 1 fertilizer_basic
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "Starter provides 4 seed_bayam")
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 1, "Starter provides 1 soil_compost")
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 1, "Starter provides 1 fertilizer_basic")

	# Anti-Spam: Second pickup attempt rejected
	var re_claim = inv.pickup_starter_container()
	Assertions.assert_false(re_claim, "Second pickup_starter_container attempt rejected cleanly")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "No duplicate seeds")

	# --- 4C: Full Garden Preparation Lifecycle ---
	# 1. Add compost
	Assertions.assert_true(gm.add_compost("plot_home_01"), "Add compost succeeds")
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 0, "soil_compost consumed cleanly (0 left)")
	Assertions.assert_true(gm.get_plot("plot_home_01")["has_compost"], "has_compost is true")

	# Second compost attempt rejected
	Assertions.assert_false(gm.add_compost("plot_home_01"), "Second compost rejected")

	# 2. Plant all 4 seeds
	for i in range(1, 5):
		var s_id := "slot_%02d" % i
		Assertions.assert_true(gm.plant_seed("plot_home_01", s_id, "seed_bayam"), "Planting %s succeeds" % s_id)
		Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4 - i, "Seeds remaining matches %d" % (4 - i))

	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 0, "All 4 seeds planted cleanly (0 left)")

	# Attempt planting 5th seed (no seeds left)
	Assertions.assert_false(gm.plant_seed("plot_home_01", "slot_01", "seed_bayam"), "Planting on occupied slot with 0 seeds rejected")

	# 3. Fertilize plot
	Assertions.assert_true(gm.fertilize_plot("plot_home_01"), "Fertilize succeeds")
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 0, "fertilizer_basic consumed cleanly (0 left)")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["nutrients"]), 100.0, 0.0001, "Nutrients is 100.0")

	# Second fertilize attempt rejected
	Assertions.assert_false(gm.fertilize_plot("plot_home_01"), "Second fertilize rejected")

	# 4. Refill and Water
	Assertions.assert_true(gm.refill_water(), "Refill watering can succeeds")
	Assertions.assert_equal(gm.watering_can_water, 10, "Water level is 10/10")

	Assertions.assert_true(gm.water_plot("plot_home_01"), "Water plot succeeds")
	Assertions.assert_equal(gm.watering_can_water, 8, "Water level is 8/10 (2 consumed)")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["moisture"]), 80.0, 0.0001, "Moisture is 80.0")

	# Second water attempt rejected
	Assertions.assert_false(gm.water_plot("plot_home_01"), "Second water rejected")
	Assertions.assert_equal(gm.watering_can_water, 8, "Water level remains 8")

	# --- 4D: Strict Conservation of Mass Invariant ---
	# Inventory must be completely empty of consumable starter materials
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 0, "0 seed_bayam in backpack")
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 0, "0 soil_compost in backpack")
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 0, "0 fertilizer_basic in backpack")
	Assertions.assert_equal(inv.backpack.get_empty_slot_count(), 12, "Backpack has all 12 slots empty")

	# World state has exactly:
	# 4 planted spots
	for i in range(1, 5):
		var s_id := "slot_%02d" % i
		Assertions.assert_true(gm.get_spot("plot_home_01", s_id)["is_occupied"], "%s is occupied" % s_id)

	# 1 compost applied
	Assertions.assert_true(gm.get_plot("plot_home_01")["has_compost"], "Compost applied to plot")
	# 1 fertilizer applied (nutrients = 100)
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["nutrients"]), 100.0, 0.0001, "Fertilizer applied to plot")
	# 1 water applied (moisture = 80)
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["moisture"]), 80.0, 0.0001, "Water applied to plot")

	# --- 4E: Save/Load Roundtrip Integrity ---
	var snap_gm = gm.get_save_snapshot()
	var snap_inv = inv.get_save_snapshot()

	gm.reset_to_defaults()
	inv.backpack.clear()
	inv.starter_claimed = false

	# Restore
	Assertions.assert_true(gm.load_save_snapshot(snap_gm), "gm.load_save_snapshot succeeds")
	Assertions.assert_true(inv.load_save_snapshot(snap_inv), "inv.load_save_snapshot succeeds")

	# Verify post-load state matches 100%
	Assertions.assert_true(inv.starter_claimed, "Restored starter_claimed is true")
	Assertions.assert_equal(inv.backpack.get_empty_slot_count(), 12, "Restored backpack has all 12 slots empty")
	Assertions.assert_equal(gm.watering_can_water, 8, "Restored watering_can_water is 8")
	Assertions.assert_true(gm.get_plot("plot_home_01")["is_hoed"], "Restored plot is hoed")
	Assertions.assert_true(gm.get_plot("plot_home_01")["has_compost"], "Restored plot has compost")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["nutrients"]), 100.0, 0.0001, "Restored nutrients is 100.0")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["moisture"]), 80.0, 0.0001, "Restored moisture is 80.0")
	for i in range(1, 5):
		var s_id := "slot_%02d" % i
		Assertions.assert_true(gm.get_spot("plot_home_01", s_id)["is_occupied"], "Restored %s is occupied" % s_id)

	# Cleanup
	inv.free()
	gm.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 4: Zero-softlock starter inventory lifecycle verified.")
	else:
		printerr("    [FAIL] Challenge 4: Zero-softlock starter lifecycle failed.")
	return ok

# ==============================================================================
# CHALLENGE 5: Split Inventory Consumption (Backpack + Storage)
# ==============================================================================
func challenge_05_split_inventory_consumption() -> bool:
	print("\n  [CHALLENGE 5] Split Inventory Consumption (Backpack + Storage_Home)")
	var initial_failures = Assertions.current_suite_failed

	var inv: Node = InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.storage_home.clear()

	var gm: Node = GardenManagerClass.new()
	gm._ready()
	gm.set_inventory_manager(inv)

	# Prepare plot
	gm.hoe_plot("plot_home_01")

	# Distribute starter items:
	# Compost in storage_home
	inv.storage_home.add_item("soil_compost", 1)
	# Fertilizer in storage_home
	inv.storage_home.add_item("fertilizer_basic", 1)
	# 2 seeds in backpack, 2 seeds in storage_home
	inv.backpack.add_item("seed_bayam", 2)
	inv.storage_home.add_item("seed_bayam", 2)

	# Verify aggregate stock
	Assertions.assert_equal(inv.get_available_item_count("soil_compost"), 1)
	Assertions.assert_equal(inv.get_available_item_count("fertilizer_basic"), 1)
	Assertions.assert_equal(inv.get_available_item_count("seed_bayam"), 4)

	# 1. Add compost (drawn from storage_home)
	Assertions.assert_true(gm.add_compost("plot_home_01"), "Add compost from storage succeeds")
	Assertions.assert_equal(inv.storage_home.get_item_count("soil_compost"), 0, "Compost removed from storage")
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 0, "Backpack still 0")

	# 2. Plant seeds across both containers:
	# Spot 1: drawn from backpack (bp: 2 -> 1)
	Assertions.assert_true(gm.plant_seed("plot_home_01", "slot_01", "seed_bayam"))
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 1)
	Assertions.assert_equal(inv.storage_home.get_item_count("seed_bayam"), 2)

	# Spot 2: drawn from backpack (bp: 1 -> 0)
	Assertions.assert_true(gm.plant_seed("plot_home_01", "slot_02", "seed_bayam"))
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 0)
	Assertions.assert_equal(inv.storage_home.get_item_count("seed_bayam"), 2)

	# Spot 3: drawn from storage_home (storage: 2 -> 1)
	Assertions.assert_true(gm.plant_seed("plot_home_01", "slot_03", "seed_bayam"))
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 0)
	Assertions.assert_equal(inv.storage_home.get_item_count("seed_bayam"), 1)

	# Spot 4: drawn from storage_home (storage: 1 -> 0)
	Assertions.assert_true(gm.plant_seed("plot_home_01", "slot_04", "seed_bayam"))
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 0)
	Assertions.assert_equal(inv.storage_home.get_item_count("seed_bayam"), 0)

	# 3. Fertilize (drawn from storage_home)
	Assertions.assert_true(gm.fertilize_plot("plot_home_01"), "Fertilize from storage succeeds")
	Assertions.assert_equal(inv.storage_home.get_item_count("fertilizer_basic"), 0, "Fertilizer removed from storage")

	# Both containers completely empty
	Assertions.assert_equal(inv.get_available_item_count("seed_bayam"), 0)
	Assertions.assert_equal(inv.get_available_item_count("soil_compost"), 0)
	Assertions.assert_equal(inv.get_available_item_count("fertilizer_basic"), 0)

	# Cleanup
	inv.free()
	gm.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 5: Split inventory consumption verified.")
	else:
		printerr("    [FAIL] Challenge 5: Split inventory consumption failed.")
	return ok

# ==============================================================================
# CHALLENGE 6: Hold Action Controller State Machine Stress
# ==============================================================================
func challenge_06_hold_controller_state_machine_stress() -> bool:
	print("\n  [CHALLENGE 6] Hold Action Controller State Machine Stress & Anti-Spam Retrigger")
	var initial_failures = Assertions.current_suite_failed

	var ctrl := HoldActionControllerClass.new()

	# --- 6A: 50 rapid start & cancel cycles ---
	for i in range(50):
		ctrl.start("action_hoe", "plot_home_01", 2.0, &"action_tool_use")
		ctrl.tick(1.0, true, true) # 50% hold
		Assertions.assert_approx_equal(ctrl.get_progress(), 0.5, 0.01, "Progress at 50%")
		ctrl.cancel()
		Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.IDLE, "State is IDLE on cancel")
		Assertions.assert_equal(ctrl.get_progress(), 0.0, "Progress reset on cancel")

	# --- 6B: Completion and MUST_RELEASE Gating ---
	var signal_data := {"completed": false, "completed_action": ""}
	ctrl.hold_completed.connect(func(act: String):
		signal_data["completed"] = true
		signal_data["completed_action"] = act
	)

	ctrl.start("action_water", "plot_home_01", 2.0, &"action_tool_use")
	ctrl.tick(1.9, true, true)
	Assertions.assert_false(signal_data["completed"], "Not completed at 1.9s (< 2.0s)")
	Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.HOLDING)

	ctrl.tick(0.2, true, true) # elapsed = 2.1s >= 2.0s
	Assertions.assert_true(signal_data["completed"], "Completed when elapsed >= required_time")
	Assertions.assert_equal(signal_data["completed_action"], "action_water", "Completed action ID matches")
	Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.MUST_RELEASE, "Transitions to MUST_RELEASE")

	# While button is STILL pressed, calling start() is rejected
	ctrl.start("action_water", "plot_home_01", 2.0, &"action_tool_use")
	Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.MUST_RELEASE, "start() rejected while in MUST_RELEASE")

	# Tick while button is STILL held down -> stays in MUST_RELEASE
	ctrl.tick(0.1, true, true)
	Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.MUST_RELEASE, "Stays in MUST_RELEASE while button held")

	# Release button (is_button_pressed = false)
	ctrl.tick(0.1, false, true)
	Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.IDLE, "Transitions back to IDLE upon button release")

	# Now can start next action
	ctrl.start("action_fertilize", "plot_home_01", 1.0, &"action_tool_use")
	Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.HOLDING, "Can start new action after button release")
	ctrl.cancel()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 6: Hold action controller state machine stress verified.")
	else:
		printerr("    [FAIL] Challenge 6: Hold action controller state machine failed.")
	return ok

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

# Helper Mock InputManager
class MockInputManager:
	extends Node
	var paused: bool = false

	func _init(p: bool = false) -> void:
		paused = p

	func is_simulation_paused() -> bool:
		return paused
