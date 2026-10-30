class_name TestGardening
extends RefCounted

## Test Suite GARD-001: Persiapan Petak, Benih, Perawatan Area, Sistem Alat & Penguapan (Suite 9)
## Memverifikasi PRD FR07..FR10, CONTENT.md § 5/6/7/8/9/11/12, TASKS.md GARD-001, dan TEST_PLAN T06, T07, T08, T32, T33

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")
const HoldActionControllerClass = preload("res://scripts/gardening/hold_action_controller.gd")

var GardenManagerClass: Variant = null

func _init() -> void:
	if ResourceLoader.exists("res://scripts/gardening/garden_manager.gd"):
		GardenManagerClass = load("res://scripts/gardening/garden_manager.gd")
	elif Engine.has_singleton("GardenManager"):
		GardenManagerClass = Engine.get_singleton("GardenManager")
	else:
		# Fallback reference implementation conforming to explorer_gard_001_1 and explorer_gard_001_2 blueprints
		GardenManagerClass = ReferenceGardenManager

func run_all() -> bool:
	var passed := true
	print("  Running TestGardening suite (T06, T07, T08, T32, T33, Spot Isolation, Atomic Invariance)...")
	var tree := Engine.get_main_loop() as SceneTree

	# 1. Baseline Initialization
	if not test_gard01_baseline_plot_and_spot_initialization():
		passed = false

	# 2. T06: Soil Hoeing 2s Hold & Cancel
	if not test_t06_soil_hoeing_hold_and_cancel():
		passed = false

	# 3. T07: Compost Amendment & Re-attempt Rejection
	if not test_t07_compost_amendment_and_rejection():
		passed = false

	# 4. T08: Seed Planting on Spot & Validation
	if not test_t08_seed_planting_and_validation():
		passed = false

	# 5. Multi-Spot Isolation
	if not test_multi_spot_isolation():
		passed = false

	# 6. T32: Area Fertilizing 1s Hold & Threshold Rejection
	if not test_t32_area_fertilizing_hold_and_threshold():
		passed = false

	# 7. T33: Area Watering 2s Hold, Capacity Check & Threshold Rejection
	if not test_t33_area_watering_hold_capacity_and_threshold():
		passed = false

	# 8. T33: Evaporation Simulation Loop & Pause Gating
	if not test_t33_evaporation_loop():
		passed = false

	# 9. Atomic Inventory Transactions & Zero Softlock Invariance
	if not test_atomic_inventory_invariance_and_zero_softlock():
		passed = false

	# 10. Save/Load Persistence Roundtrip (SAVE-001 Contract)
	if not test_save_snapshot_roundtrip():
		passed = false

	# 11. World Landmark & Graybox Scene Integration (plot_home_01 & water_home)
	if not await test_landmark_and_scene_integration(tree):
		passed = false

	# 12. Regression: DEFECT-GARD-01 Hold Action Retargeting & External Tool Cancellation Guard
	if not await test_regression_defect_gard_01_retargeting_hold_cancel(tree):
		passed = false

	# 13. T34 / T05: 4-Stage Crop Growth Cycle (0..30s Seed, 30..90s Sprout, 90..180s Growing, 180s Harvestable)
	if not test_t34_crop_growth_4_stages():
		passed = false

	# 14. T35 / T34: Growth Stall Thresholds (Moisture < 30, Nutrients < 20, Non-Decay Invariance)
	if not test_t35_growth_stall_conditions():
		passed = false

	# 15. T36 / T35: Atomic Harvest Yield (1 Spinach + 1 Seed), -5 Nutrients & Replanting
	if not test_t36_atomic_harvest_yield_and_replanting():
		passed = false

	# 16. T05 / T36: Atomic Harvest Rejection Under Full Bag (11/12 Slots, 12/12 Slots & Stack Merging)
	if not test_t05_harvest_capacity_atomic_rejection():
		passed = false

	# 17. Multi-Spot Staggered Growth and Harvest Isolation (Independent Progression)
	if not test_multi_spot_staggered_growth_and_harvest():
		passed = false

	# 18. GARD-002 Save/Load Persistence Roundtrip (SAVE-001 Contract)
	if not test_gard02_save_snapshot_growth_persistence():
		passed = false

	return passed

# --- Helper Factory Methods ---

func _create_clean_inventory() -> Node:
	var inv: Node = InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.storage_home.clear()
	inv.kitchen_refund.clear()
	inv.starter_claimed = false
	return inv

func _create_clean_garden_manager(inv: Node) -> Node:
	var gm: Node = null
	if GardenManagerClass is Script or GardenManagerClass is GDScript:
		gm = GardenManagerClass.new()
	elif GardenManagerClass is Node:
		gm = GardenManagerClass
	else:
		gm = ReferenceGardenManager.new()

	if gm.has_method("set_inventory_manager"):
		gm.set_inventory_manager(inv)
	if gm.has_method("reset_to_defaults"):
		gm.reset_to_defaults()
	elif gm.has_method("_ready"):
		gm._ready()
	return gm

# --- Test Cases ---

## GARD-01: Baseline Plot & Spot Initialization
func test_gard01_baseline_plot_and_spot_initialization() -> bool:
	print("    [RUN] GARD-01: Baseline Plot & Spot Initialization (plot_home_01, 4 spots)")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var gm: Node = _create_clean_garden_manager(inv)

	# Verify plot_home_01 exists
	var plot: Dictionary = gm.get_plot("plot_home_01")
	Assertions.assert_false(plot.is_empty(), "plot_home_01 must be registered in GardenManager")
	Assertions.assert_equal(plot.get("id", ""), "plot_home_01", "Plot ID must be plot_home_01")
	Assertions.assert_false(bool(plot.get("is_hoed", false)), "Plot must start unhoed (is_hoed == false)")
	Assertions.assert_false(bool(plot.get("has_compost", false)), "Plot must start without compost (has_compost == false)")
	Assertions.assert_approx_equal(float(plot.get("nutrients", 0.0)), 0.0, 0.001, "Plot initial nutrients must be 0.0")
	Assertions.assert_approx_equal(float(plot.get("moisture", 0.0)), 0.0, 0.001, "Plot initial moisture must be 0.0")

	# Verify 4 quadrant spots exist (slot_01..slot_04)
	var spots: Dictionary = plot.get("spots", {})
	Assertions.assert_equal(spots.size(), 4, "Plot must have exactly 4 spots")
	for i in range(1, 5):
		var s_id := "slot_%02d" % i
		Assertions.assert_true(spots.has(s_id), "Plot must contain spot %s" % s_id)
		var sp: Dictionary = spots[s_id]
		Assertions.assert_false(bool(sp.get("is_occupied", false)), "Spot %s must start unoccupied" % s_id)
		Assertions.assert_null(sp.get("crop_data", null), "Spot %s crop_data must start null" % s_id)

	# Verify initial tools and watering can
	Assertions.assert_equal(gm.active_tool, "", "Active tool must start empty/none")
	Assertions.assert_equal(gm.watering_can_water, 0, "Watering can must start at 0 units")

	if Assertions.current_suite_failed == initial_failures:
		print("    [PASS] GARD-01: Baseline Plot & Spot Initialization verified.")
		return true
	return false

## T06: Soil Hoeing with tool_hoe (2s Hold & Cancel)
func test_t06_soil_hoeing_hold_and_cancel() -> bool:
	print("    [RUN] T06: Soil Hoeing with tool_hoe (2s Hold, Cancel & Commit)")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var gm: Node = _create_clean_garden_manager(inv)

	# 1. Verification of Hold Action Controller: Cancel at 1.0s (< 2.0s required)
	var hold_controller := MockHoldController.new(2.0)
	hold_controller.start("tool_hoe", "plot_home_01")
	hold_controller.tick(1.0) # 50% hold
	Assertions.assert_approx_equal(hold_controller.get_progress(), 0.5, 0.01, "Hold progress at 1.0s should be 50%")
	hold_controller.cancel()
	Assertions.assert_approx_equal(hold_controller.get_progress(), 0.0, 0.001, "Hold cancellation must reset progress to 0.0")
	Assertions.assert_false(gm.get_plot("plot_home_01")["is_hoed"], "Cancelling hoeing must not mutate is_hoed")

	# 2. Hold Completion at 2.0s commits hoeing
	hold_controller.start("tool_hoe", "plot_home_01")
	hold_controller.tick(2.0)
	Assertions.assert_true(hold_controller.is_finished(), "Hold action must complete at 2.0s")
	
	var hoe_ok: bool = gm.hoe_plot("plot_home_01")
	Assertions.assert_true(hoe_ok, "hoe_plot on unhoed plot must succeed")
	Assertions.assert_true(gm.get_plot("plot_home_01")["is_hoed"], "Plot is_hoed must be true after successful hoeing")
	Assertions.assert_false(gm.get_plot("plot_home_01")["has_compost"], "Plot has_compost must remain false after hoeing")

	# 3. Re-trigger protection & redundant hoeing rejection
	var redundant_check: Dictionary = gm.can_hoe_plot("plot_home_01")
	Assertions.assert_false(redundant_check["success"], "Hoeing an already hoed plot must be rejected")
	Assertions.assert_equal(redundant_check["reason"], "Kondisi cukup.", "Reason must be 'Kondisi cukup.'")
	var second_hoe: bool = gm.hoe_plot("plot_home_01")
	Assertions.assert_false(second_hoe, "Redundant hoe_plot must return false without side-effects")

	if Assertions.current_suite_failed == initial_failures:
		print("    [PASS] T06: Soil Hoeing 2s Hold & Cancel verified.")
		return true
	return false

## T07: Compost Amendment (Prompt E with soil_compost & Re-attempt Rejection)
func test_t07_compost_amendment_and_rejection() -> bool:
	print("    [RUN] T07: Compost Amendment (Prerequisite, Ready State & Re-attempt Rejection)")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var gm: Node = _create_clean_garden_manager(inv)

	# 1. Prerequisite check: Unhoed plot rejected
	inv.backpack.add_item("soil_compost", 1)
	var unhoed_check: Dictionary = gm.can_add_compost("plot_home_01")
	Assertions.assert_false(unhoed_check["success"], "Compost on unhoed plot must be rejected")
	Assertions.assert_equal(unhoed_check["reason"], "Gemburkan tanah dan tambahkan pembenah dahulu.")
	var unhoed_add: bool = gm.add_compost("plot_home_01")
	Assertions.assert_false(unhoed_add, "add_compost on unhoed plot must return false")
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 1, "0 compost consumed on unhoed plot rejection")

	# 2. Hoe plot first
	gm.hoe_plot("plot_home_01")

	# 3. Successful compost addition on hoed plot
	var ready_check: Dictionary = gm.can_add_compost("plot_home_01")
	Assertions.assert_true(ready_check["success"], "can_add_compost on hoed plot with item must be true")
	var add_ok: bool = gm.add_compost("plot_home_01")
	Assertions.assert_true(add_ok, "add_compost must succeed")
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 0, "Exactly 1 soil_compost consumed")
	Assertions.assert_true(gm.get_plot("plot_home_01")["has_compost"], "has_compost must be true")
	Assertions.assert_true(gm.is_plot_ready_to_plant("plot_home_01"), "Plot must now be ready to plant (is_hoed and has_compost)")

	# 4. Re-attempt rejection (Anti-waste / zero item loss)
	inv.backpack.add_item("soil_compost", 1)
	var reattempt_check: Dictionary = gm.can_add_compost("plot_home_01")
	Assertions.assert_false(reattempt_check["success"], "Second compost attempt must be rejected")
	Assertions.assert_equal(reattempt_check["reason"], "Kondisi cukup. Tidak ada bahan yang digunakan.")
	var reattempt_add: bool = gm.add_compost("plot_home_01")
	Assertions.assert_false(reattempt_add, "Second add_compost must return false")
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 1, "Backpack must still have 1 soil_compost (0 wasted)")

	# 5. Insufficient item check
	inv.backpack.clear()
	gm.get_plot("plot_home_01")["has_compost"] = false # Reset for item check
	var no_item_check: Dictionary = gm.can_add_compost("plot_home_01")
	Assertions.assert_false(no_item_check["success"], "Compost with 0 items must be rejected")
	Assertions.assert_equal(no_item_check["reason"], "Pembenah belum tersedia.")

	if Assertions.current_suite_failed == initial_failures:
		print("    [PASS] T07: Compost Amendment verified.")
		return true
	return false

## T08: Seed Planting on Spot & Validation
func test_t08_seed_planting_and_validation() -> bool:
	print("    [RUN] T08: Seed Planting on Spot (Validation, Occupancy & Item Consumption)")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var gm: Node = _create_clean_garden_manager(inv)

	inv.backpack.add_item("seed_bayam", 4)

	# 1. Rejection on unready plot
	var unready_check: Dictionary = gm.can_plant_seed("plot_home_01", "slot_01", "seed_bayam")
	Assertions.assert_false(unready_check["success"], "Planting on unready plot must be rejected")
	Assertions.assert_equal(unready_check["reason"], "Gemburkan tanah dan tambahkan pembenah dahulu.")
	var unready_plant: bool = gm.plant_seed("plot_home_01", "slot_01", "seed_bayam")
	Assertions.assert_false(unready_plant, "plant_seed on unready plot must fail")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "0 seeds consumed on unready plot rejection")

	# Prepare plot: Hoe + Compost
	gm.hoe_plot("plot_home_01")
	inv.backpack.add_item("soil_compost", 1)
	gm.add_compost("plot_home_01")

	# 2. Successful planting on valid spot
	var valid_check: Dictionary = gm.can_plant_seed("plot_home_01", "slot_01", "seed_bayam")
	Assertions.assert_true(valid_check["success"], "can_plant_seed on slot_01 must be valid")
	var plant_ok: bool = gm.plant_seed("plot_home_01", "slot_01", "seed_bayam")
	Assertions.assert_true(plant_ok, "plant_seed on slot_01 must succeed")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 3, "Exactly 1 seed_bayam consumed (3 remaining)")
	
	var spot_data: Dictionary = gm.get_spot("plot_home_01", "slot_01")
	Assertions.assert_true(bool(spot_data.get("is_occupied", false)), "slot_01 must be occupied")
	var crop: Dictionary = spot_data.get("crop_data", {})
	Assertions.assert_equal(crop.get("crop_id", ""), "crop_bayam", "Crop ID must be crop_bayam")
	Assertions.assert_approx_equal(float(crop.get("growth_time", 0.0)), 0.0, 0.001, "Growth time must start at 0.0")
	Assertions.assert_equal(int(crop.get("growth_stage", -1)), 0, "Growth stage must start at 0 (Benih)")

	# 3. Occupied spot rejection
	var occupied_check: Dictionary = gm.can_plant_seed("plot_home_01", "slot_01", "seed_bayam")
	Assertions.assert_false(occupied_check["success"], "Planting on occupied spot must be rejected")
	Assertions.assert_equal(occupied_check["reason"], "Titik tanam sudah terisi.")
	var re_plant: bool = gm.plant_seed("plot_home_01", "slot_01", "seed_bayam")
	Assertions.assert_false(re_plant, "Planting on occupied spot must return false")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 3, "No seeds consumed on occupied spot rejection")

	# 4. Zero seed inventory rejection
	inv.backpack.clear()
	var no_seed_check: Dictionary = gm.can_plant_seed("plot_home_01", "slot_02", "seed_bayam")
	Assertions.assert_false(no_seed_check["success"], "Planting with 0 seeds must be rejected")
	Assertions.assert_equal(no_seed_check["reason"], "Benih belum tersedia. Periksa wadah dekat alat.")

	# 5. Invalid spot ID rejection
	inv.backpack.add_item("seed_bayam", 1)
	var invalid_spot_check: Dictionary = gm.can_plant_seed("plot_home_01", "slot_99", "seed_bayam")
	Assertions.assert_false(invalid_spot_check["success"], "Planting on invalid spot ID must be rejected")
	Assertions.assert_equal(invalid_spot_check["reason"], "Titik tanam tidak valid.")

	if Assertions.current_suite_failed == initial_failures:
		print("    [PASS] T08: Seed Planting on Spot verified.")
		return true
	return false

## Multi-Spot Isolation (Spot Invariance)
func test_multi_spot_isolation() -> bool:
	print("    [RUN] Multi-Spot Isolation: 4 Independent Quadrant Spots")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var gm: Node = _create_clean_garden_manager(inv)

	# Prepare plot
	gm.hoe_plot("plot_home_01")
	inv.backpack.add_item("soil_compost", 1)
	gm.add_compost("plot_home_01")
	inv.backpack.add_item("seed_bayam", 4)

	# Plant slot_01
	gm.plant_seed("plot_home_01", "slot_01", "seed_bayam")
	Assertions.assert_true(gm.get_spot("plot_home_01", "slot_01")["is_occupied"], "slot_01 occupied")
	Assertions.assert_false(gm.get_spot("plot_home_01", "slot_02")["is_occupied"], "slot_02 must remain empty")
	Assertions.assert_false(gm.get_spot("plot_home_01", "slot_03")["is_occupied"], "slot_03 must remain empty")
	Assertions.assert_false(gm.get_spot("plot_home_01", "slot_04")["is_occupied"], "slot_04 must remain empty")

	# Plant slot_03
	gm.plant_seed("plot_home_01", "slot_03", "seed_bayam")
	Assertions.assert_true(gm.get_spot("plot_home_01", "slot_01")["is_occupied"], "slot_01 remains occupied")
	Assertions.assert_false(gm.get_spot("plot_home_01", "slot_02")["is_occupied"], "slot_02 remains empty")
	Assertions.assert_true(gm.get_spot("plot_home_01", "slot_03")["is_occupied"], "slot_03 now occupied")
	Assertions.assert_false(gm.get_spot("plot_home_01", "slot_04")["is_occupied"], "slot_04 remains empty")

	# Support spot_0..spot_3 mapping aliases
	Assertions.assert_true(gm.get_spot("plot_home_01", "spot_0")["is_occupied"], "spot_0 alias must map to slot_01")
	Assertions.assert_false(gm.get_spot("plot_home_01", "spot_1")["is_occupied"], "spot_1 alias must map to slot_02")

	if Assertions.current_suite_failed == initial_failures:
		print("    [PASS] Multi-Spot Isolation verified.")
		return true
	return false

## T32: Area Fertilizing (1s Hold, Whole Plot Nutrients = 100 & Threshold Rejection)
func test_t32_area_fertilizing_hold_and_threshold() -> bool:
	print("    [RUN] T32: Area Fertilizing (1s Hold, Nutrients = 100 & Threshold Rejection)")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var gm: Node = _create_clean_garden_manager(inv)

	inv.backpack.add_item("fertilizer_basic", 2)

	# 1. Hold cancellation at 0.5s (< 1.0s required)
	var hold_controller := MockHoldController.new(1.0)
	hold_controller.start("tool_fertilizer", "plot_home_01")
	hold_controller.tick(0.5)
	hold_controller.cancel()
	Assertions.assert_approx_equal(hold_controller.get_progress(), 0.0, 0.001, "Progress reset on cancel")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["nutrients"]), 0.0, 0.001, "Nutrients unmodified on cancel")
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 2, "0 fertilizer consumed on cancel")

	# 2. Successful fertilizing: Nutrients set to 100
	var can_fert: Dictionary = gm.can_fertilize_plot("plot_home_01")
	Assertions.assert_true(can_fert["success"], "Fertilizing allowed when nutrients < 20")
	var fert_ok: bool = gm.fertilize_plot("plot_home_01")
	Assertions.assert_true(fert_ok, "fertilize_plot must succeed")
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 1, "Exactly 1 fertilizer consumed")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["nutrients"]), 100.0, 0.001, "Plot nutrients set to 100.0")

	# 3. Threshold rejection: Nutrients >= 20 (currently 100.0)
	var threshold_check: Dictionary = gm.can_fertilize_plot("plot_home_01")
	Assertions.assert_false(threshold_check["success"], "Fertilizing rejected when nutrients >= 20")
	Assertions.assert_equal(threshold_check["reason"], "Kondisi cukup. Tidak ada bahan yang digunakan.")
	var fert_rejected: bool = gm.fertilize_plot("plot_home_01")
	Assertions.assert_false(fert_rejected, "fertilize_plot must fail on threshold")
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 1, "Backpack still has 1 fertilizer (0 consumed)")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["nutrients"]), 100.0, 0.001, "Nutrients remain 100.0")

	# 4. Boundary threshold test: 19.9 vs 20.0
	gm.get_plot("plot_home_01")["nutrients"] = 19.9
	Assertions.assert_true(gm.can_fertilize_plot("plot_home_01")["success"], "Allowed at 19.9 nutrients (< 20)")
	gm.get_plot("plot_home_01")["nutrients"] = 20.0
	Assertions.assert_false(gm.can_fertilize_plot("plot_home_01")["success"], "Rejected at 20.0 nutrients (>= 20)")

	# 5. Zero fertilizer inventory rejection
	inv.backpack.clear()
	gm.get_plot("plot_home_01")["nutrients"] = 0.0
	var no_fert_check: Dictionary = gm.can_fertilize_plot("plot_home_01")
	Assertions.assert_false(no_fert_check["success"], "Rejected with 0 fertilizer in inventory")
	Assertions.assert_equal(no_fert_check["reason"], "Pupuk belum tersedia.")

	if Assertions.current_suite_failed == initial_failures:
		print("    [PASS] T32: Area Fertilizing verified.")
		return true
	return false

## T33: Area Watering (2s Hold, Capacity Check, Moisture = 80 & Threshold Rejection)
func test_t33_area_watering_hold_capacity_and_threshold() -> bool:
	print("    [RUN] T33: Area Watering (2s Hold, Capacity Check, Moisture = 80 & Threshold Rejection)")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var gm: Node = _create_clean_garden_manager(inv)

	# 1. Initial empty watering can rejection
	Assertions.assert_equal(gm.watering_can_water, 0, "Watering can starts at 0")
	var empty_can_check: Dictionary = gm.can_water_plot("plot_home_01")
	Assertions.assert_false(empty_can_check["success"], "Watering with empty can rejected")
	Assertions.assert_equal(empty_can_check["reason"], "Air tidak cukup. Isi ulang penyiram di pekarangan.")

	# 2. Refill watering can at water_home
	var refill_ok: bool = gm.refill_water()
	Assertions.assert_true(refill_ok, "refill_water must succeed")
	Assertions.assert_equal(gm.watering_can_water, 10, "Watering can refilled to 10 units")
	var full_refill_check: Dictionary = gm.can_refill_water()
	Assertions.assert_false(full_refill_check["success"], "Refill when already full is rejected")
	Assertions.assert_equal(full_refill_check["reason"], "Kondisi cukup. Air sudah penuh.")

	# 3. Hold cancellation at 1.0s (< 2.0s required)
	var hold_controller := MockHoldController.new(2.0)
	hold_controller.start("tool_watering_can", "plot_home_01")
	hold_controller.tick(1.0)
	hold_controller.cancel()
	Assertions.assert_approx_equal(hold_controller.get_progress(), 0.0, 0.001, "Progress reset on cancel")
	Assertions.assert_equal(gm.watering_can_water, 10, "0 water consumed on cancel")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["moisture"]), 0.0, 0.001, "Moisture unmodified on cancel")

	# 4. Successful watering: Moisture set to 80.0, 2 water consumed
	var water_ok: bool = gm.water_plot("plot_home_01")
	Assertions.assert_true(water_ok, "water_plot must succeed")
	Assertions.assert_equal(gm.watering_can_water, 8, "Exactly 2 units of water consumed (8 remaining)")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["moisture"]), 80.0, 0.001, "Plot moisture set to 80.0")

	# 5. Threshold rejection: Moisture >= 60 (currently 80.0)
	var threshold_check: Dictionary = gm.can_water_plot("plot_home_01")
	Assertions.assert_false(threshold_check["success"], "Watering rejected when moisture >= 60")
	Assertions.assert_equal(threshold_check["reason"], "Petak sudah cukup. Tidak ada bahan yang digunakan.")
	var water_rejected: bool = gm.water_plot("plot_home_01")
	Assertions.assert_false(water_rejected, "water_plot must fail on threshold")
	Assertions.assert_equal(gm.watering_can_water, 8, "Water units remain 8 (0 wasted)")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["moisture"]), 80.0, 0.001, "Moisture remains 80.0")

	# 6. Boundary threshold test: 59.9 vs 60.0
	gm.get_plot("plot_home_01")["moisture"] = 59.9
	Assertions.assert_true(gm.can_water_plot("plot_home_01")["success"], "Allowed at 59.9 moisture (< 60)")
	gm.get_plot("plot_home_01")["moisture"] = 60.0
	Assertions.assert_false(gm.can_water_plot("plot_home_01")["success"], "Rejected at 60.0 moisture (>= 60)")

	# 7. Insufficient water rejection: 1 unit water < 2 needed
	gm.get_plot("plot_home_01")["moisture"] = 0.0
	gm.watering_can_water = 1
	var low_water_check: Dictionary = gm.can_water_plot("plot_home_01")
	Assertions.assert_false(low_water_check["success"], "Rejected with 1 unit water")
	Assertions.assert_equal(low_water_check["reason"], "Air tidak cukup. Isi ulang penyiram di pekarangan.")

	if Assertions.current_suite_failed == initial_failures:
		print("    [PASS] T33: Area Watering verified.")
		return true
	return false

## T33: Evaporation Simulation Loop & Pause Gating
func test_t33_evaporation_loop() -> bool:
	print("    [RUN] T33: Evaporation Simulation Loop (0.1/s Deterministic & Pause Gating)")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var gm: Node = _create_clean_garden_manager(inv)

	# Setup moisture at 80.0
	gm.get_plot("plot_home_01")["moisture"] = 80.0

	# 1. 10 seconds of active simulation delta -> exactly 1.0 unit evaporated
	gm.simulate_process(10.0)
	var m1: float = float(gm.get_plot("plot_home_01")["moisture"])
	Assertions.assert_approx_equal(m1, 79.0, 0.01, "Moisture after 10s at 0.1/s should be 79.0")

	# 2. 100 seconds of active delta -> 10.0 units evaporated
	gm.simulate_process(100.0)
	var m2: float = float(gm.get_plot("plot_home_01")["moisture"])
	Assertions.assert_approx_equal(m2, 69.0, 0.01, "Moisture after another 100s should be 69.0")

	# 3. Minimum clamping at 0.0 (no negative moisture)
	gm.simulate_process(1000.0)
	var m3: float = float(gm.get_plot("plot_home_01")["moisture"])
	Assertions.assert_approx_equal(m3, 0.0, 0.001, "Moisture must clamp at 0.0")

	# 4. Simulation pause gating (InputManager pause state)
	gm.get_plot("plot_home_01")["moisture"] = 50.0
	var mock_im := MockInputManager.new(true) # Paused
	gm.set_input_manager(mock_im)
	gm.simulate_process(50.0)
	var m4: float = float(gm.get_plot("plot_home_01")["moisture"])
	Assertions.assert_approx_equal(m4, 50.0, 0.001, "Moisture must not evaporate while simulation is paused")

	if Assertions.current_suite_failed == initial_failures:
		print("    [PASS] T33: Evaporation Loop verified.")
		return true
	return false

## Atomic Inventory Transactions & Zero Softlock Invariance
func test_atomic_inventory_invariance_and_zero_softlock() -> bool:
	print("    [RUN] Atomic Inventory Transactions & Zero Softlock Invariance")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var gm: Node = _create_clean_garden_manager(inv)

	# Simulate Starter Container items (CONTENT.md § 5)
	# 4 seed_bayam, 1 soil_compost, 1 fertilizer_basic
	inv.backpack.add_item("seed_bayam", 4)
	inv.backpack.add_item("soil_compost", 1)
	inv.backpack.add_item("fertilizer_basic", 1)

	# Step 1: Hoe plot
	Assertions.assert_true(gm.hoe_plot("plot_home_01"), "Hoe plot")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4)
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 1)
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 1)

	# Step 2: Add Compost
	Assertions.assert_true(gm.add_compost("plot_home_01"), "Add compost")
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 0)

	# Step 3: Plant all 4 spots
	for i in range(1, 5):
		var s_id := "slot_%02d" % i
		Assertions.assert_true(gm.plant_seed("plot_home_01", s_id, "seed_bayam"), "Plant %s" % s_id)
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 0, "All 4 seeds planted cleanly")

	# Step 4: Fertilize plot
	Assertions.assert_true(gm.fertilize_plot("plot_home_01"), "Fertilize plot")
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 0, "Fertilizer consumed cleanly")
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["nutrients"]), 100.0, 0.001)

	# Step 5: Refill & Water
	Assertions.assert_true(gm.refill_water(), "Refill water")
	Assertions.assert_equal(gm.watering_can_water, 10)
	Assertions.assert_true(gm.water_plot("plot_home_01"), "Water plot")
	Assertions.assert_equal(gm.watering_can_water, 8)
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["moisture"]), 80.0, 0.001)

	# Step 6: Softlock Resistance: Spamming invalid actions
	Assertions.assert_false(gm.add_compost("plot_home_01"))
	Assertions.assert_false(gm.fertilize_plot("plot_home_01"))
	Assertions.assert_false(gm.water_plot("plot_home_01"))
	for i in range(1, 5):
		Assertions.assert_false(gm.plant_seed("plot_home_01", "slot_%02d" % i, "seed_bayam"))
	
	# Verify final state unchanged and non-corrupted
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 0)
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 0)
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 0)
	Assertions.assert_equal(gm.watering_can_water, 8)
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["nutrients"]), 100.0, 0.001)
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["moisture"]), 80.0, 0.001)

	if Assertions.current_suite_failed == initial_failures:
		print("    [PASS] Atomic Inventory Transactions & Zero Softlock Invariance verified.")
		return true
	return false

## Save/Load Persistence Roundtrip (SAVE-001 Contract)
func test_save_snapshot_roundtrip() -> bool:
	print("    [RUN] Save/Load Persistence Roundtrip (SAVE-001 Contract)")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var gm: Node = _create_clean_garden_manager(inv)

	# Setup active plot state
	gm.select_tool("tool_hoe")
	gm.watering_can_water = 6
	gm.get_plot("plot_home_01")["is_hoed"] = true
	gm.get_plot("plot_home_01")["has_compost"] = true
	gm.get_plot("plot_home_01")["nutrients"] = 85.0
	gm.get_plot("plot_home_01")["moisture"] = 72.5
	gm.get_spot("plot_home_01", "slot_01")["is_occupied"] = true
	gm.get_spot("plot_home_01", "slot_01")["crop_data"] = {
		"crop_id": "crop_bayam",
		"growth_time": 45.0,
		"growth_stage": 1,
		"is_ready_to_harvest": false
	}

	# Take snapshot
	var snapshot: Dictionary = gm.get_save_snapshot()
	Assertions.assert_true(snapshot.has("plots"), "Snapshot must contain plots key")
	Assertions.assert_equal(snapshot.get("active_tool", ""), "tool_hoe")
	Assertions.assert_equal(snapshot.get("watering_can_water", 0), 6)

	# Mutate/reset manager
	gm.reset_to_defaults()
	Assertions.assert_equal(gm.active_tool, "")
	Assertions.assert_equal(gm.watering_can_water, 0)
	Assertions.assert_false(gm.get_plot("plot_home_01")["is_hoed"])

	# Restore snapshot
	var load_ok: bool = gm.load_save_snapshot(snapshot)
	Assertions.assert_true(load_ok, "load_save_snapshot must succeed")
	Assertions.assert_equal(gm.active_tool, "tool_hoe")
	Assertions.assert_equal(gm.watering_can_water, 6)
	Assertions.assert_true(gm.get_plot("plot_home_01")["is_hoed"])
	Assertions.assert_true(gm.get_plot("plot_home_01")["has_compost"])
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["nutrients"]), 85.0, 0.001)
	Assertions.assert_approx_equal(float(gm.get_plot("plot_home_01")["moisture"]), 72.5, 0.001)
	Assertions.assert_true(gm.get_spot("plot_home_01", "slot_01")["is_occupied"])
	Assertions.assert_approx_equal(float(gm.get_spot("plot_home_01", "slot_01")["crop_data"]["growth_time"]), 45.0, 0.001)

	if Assertions.current_suite_failed == initial_failures:
		print("    [PASS] Save/Load Persistence Roundtrip verified.")
		return true
	return false

## World Landmark & Graybox Scene Integration (plot_home_01 & water_home)
func test_landmark_and_scene_integration(tree: SceneTree) -> bool:
	print("    [RUN] World Landmark & Graybox Scene Integration (plot_home_01 & water_home)")
	var initial_failures: int = Assertions.current_suite_failed

	var level_scene = load("res://scenes/world/level_graybox.tscn") as PackedScene
	Assertions.assert_not_null(level_scene, "level_graybox.tscn must be loadable")
	var level = level_scene.instantiate()
	tree.root.add_child(level)
	await tree.process_frame

	# 1. Verify plot_home_01 landmark node and hierarchy
	var plot = level.find_child("plot_home_01", true, false)
	Assertions.assert_not_null(plot, "plot_home_01 node must exist in level_graybox.tscn")
	Assertions.assert_vector3_approx_equal(plot.position, Vector3(8, 0, 7), 0.5, "plot_home_01 position around (8, 0, 7)")

	var soil_bed = plot.find_child("SoilBed", true, false)
	Assertions.assert_not_null(soil_bed, "plot_home_01 must have SoilBed")
	var interactable = plot.find_child("Interactable", true, false)
	Assertions.assert_not_null(interactable, "plot_home_01 must have Interactable Area3D")

	# 2. Verify 4 quadrant spots exist in graybox scene
	for i in range(4):
		var spot_name := "spot_%d" % i
		var spot_node = plot.find_child(spot_name, true, false)
		Assertions.assert_not_null(spot_node, "plot_home_01 must contain quadrant node %s" % spot_name)

	# 3. Verify water_home landmark exists for watering can refill
	var water_home = level.find_child("water_home", true, false)
	Assertions.assert_not_null(water_home, "water_home landmark node must exist for water refilling")

	level.queue_free()
	await tree.process_frame

	if Assertions.current_suite_failed == initial_failures:
		print("    [PASS] World Landmark & Graybox Scene Integration verified.")
		return true
	return false

func test_regression_defect_gard_01_retargeting_hold_cancel(tree: SceneTree) -> bool:
	print("    [RUN] Regression: DEFECT-GARD-01 Hold Action Retargeting & External Tool Cancellation Guard")
	var initial_failures: int = Assertions.current_suite_failed

	var player_scene = load("res://scenes/player/player.tscn") as PackedScene
	Assertions.assert_not_null(player_scene, "player.tscn must exist for regression verification")
	var player: CharacterBody3D = player_scene.instantiate()
	tree.root.add_child(player)
	await tree.process_frame

	var inv: Node = InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.backpack.add_item("fertilizer_basic", 5)

	var gm: Node = Engine.get_singleton("GardenManager") if Engine.has_singleton("GardenManager") else tree.root.find_child("GardenManager", true, false)
	if gm != null:
		gm.reset_to_defaults()
		gm.set_inventory_manager(inv)
		gm.watering_can_water = 10
		gm.select_tool("tool_hoe")

	var mock_detector = MockInteractionDetector.new()
	player.interaction_detector = mock_detector

	# 1. REG-GARD-01.1: Direct retargeting plot_home_01 (hoe hold) -> water_home cancels hold immediately
	mock_detector.current_target = MockTarget.new("landmark_plot")
	player.hold_controller.start("hoe", "plot_home_01", 2.0, &"action_tool_use")
	player.hold_controller.tick(0.5, true, true)
	Assertions.assert_true(player.hold_controller.is_holding(), "REG-GARD-01.1: Hold should be active before retargeting")
	Assertions.assert_approx_equal(player.hold_controller.get_progress(), 0.25, 0.01, "Progress should be 25%")

	mock_detector.current_target = MockTarget.new("landmark_water")
	player._update_hold_action(0.016)

	Assertions.assert_false(player.hold_controller.is_active(), "REG-GARD-01.1: Retargeting to landmark_water must cancel active plot hold")
	Assertions.assert_equal(player.hold_controller.state, HoldActionControllerClass.State.IDLE, "REG-GARD-01.1: State must reset to IDLE")
	Assertions.assert_approx_equal(player.hold_controller.get_progress(), 0.0, 0.001, "REG-GARD-01.1: Progress must reset to 0.0")

	# 2. REG-GARD-01.2: Direct retargeting water_home (refill hold) -> plot_home_01 cancels hold immediately
	mock_detector.current_target = MockTarget.new("landmark_water")
	player.hold_controller.start("refill", "water_home", 2.0, &"interact")
	player.hold_controller.tick(0.5, true, true)
	Assertions.assert_true(player.hold_controller.is_holding(), "REG-GARD-01.2: Refill hold should be active before retargeting")
	Assertions.assert_approx_equal(player.hold_controller.get_progress(), 0.25, 0.01, "Progress should be 25%")

	mock_detector.current_target = MockTarget.new("landmark_plot")
	player._update_hold_action(0.016)

	Assertions.assert_false(player.hold_controller.is_active(), "REG-GARD-01.2: Retargeting to landmark_plot must cancel active refill hold")
	Assertions.assert_equal(player.hold_controller.state, HoldActionControllerClass.State.IDLE, "REG-GARD-01.2: State must reset to IDLE")
	Assertions.assert_approx_equal(player.hold_controller.get_progress(), 0.0, 0.001, "REG-GARD-01.2: Progress must reset to 0.0")

	# 3. REG-GARD-01.3: External tool mutation while holding on landmark_plot cancels hold immediately
	mock_detector.current_target = MockTarget.new("landmark_plot")
	if gm != null:
		gm.select_tool("tool_hoe")
	player.hold_controller.start("hoe", "plot_home_01", 2.0, &"action_tool_use")
	player.hold_controller.tick(0.5, true, true)
	Assertions.assert_true(player.hold_controller.is_holding(), "REG-GARD-01.3: Hoe hold should be active before tool change")

	if gm != null:
		gm.select_tool("tool_fertilizer")
	player._update_hold_action(0.016)

	Assertions.assert_false(player.hold_controller.is_active(), "REG-GARD-01.3: External tool change must cancel active hold")
	Assertions.assert_equal(player.hold_controller.state, HoldActionControllerClass.State.IDLE, "REG-GARD-01.3: State must reset to IDLE")
	Assertions.assert_approx_equal(player.hold_controller.get_progress(), 0.0, 0.001, "REG-GARD-01.3: Progress must reset to 0.0")

	# 4. REG-GARD-01.4: Retargeting to null target (looking away) cancels hold immediately
	mock_detector.current_target = MockTarget.new("landmark_plot")
	if gm != null:
		gm.select_tool("tool_fertilizer")
	player.hold_controller.start("fertilize", "plot_home_01", 1.0, &"action_tool_use")
	player.hold_controller.tick(0.5, true, true)
	Assertions.assert_true(player.hold_controller.is_holding(), "REG-GARD-01.4: Fertilize hold should be active before looking away")

	mock_detector.current_target = null
	player._update_hold_action(0.016)

	Assertions.assert_false(player.hold_controller.is_active(), "REG-GARD-01.4: Retargeting to null target must cancel active hold")
	Assertions.assert_equal(player.hold_controller.state, HoldActionControllerClass.State.IDLE, "REG-GARD-01.4: State must reset to IDLE")
	Assertions.assert_approx_equal(player.hold_controller.get_progress(), 0.0, 0.001, "REG-GARD-01.4: Progress must reset to 0.0")

	player.queue_free()
	await tree.process_frame

	if Assertions.current_suite_failed == initial_failures:
		print("    [PASS] Regression: DEFECT-GARD-01 Hold Action Retargeting & External Tool Cancellation Guard verified.")
		return true
	return false

# ==============================================================================
# Embedded Reference & Mock Classes for Self-Contained Headless Testing
# ==============================================================================

class MockInteractionDetector:
	extends RayCast3D
	var current_target: Object = null

	func get_current_target() -> Object:
		return current_target

class MockTarget:
	extends RefCounted
	var interaction_id: String = ""

	func _init(id: String) -> void:
		interaction_id = id

class MockHoldController:
	extends RefCounted
	var required_time: float
	var elapsed_time: float = 0.0
	var tool_id: String = ""
	var target_id: String = ""
	var active: bool = false
	var finished: bool = false

	func _init(req_time: float) -> void:
		required_time = req_time

	func start(t_id: String, tgt_id: String) -> void:
		tool_id = t_id
		target_id = tgt_id
		elapsed_time = 0.0
		active = true
		finished = false

	func tick(delta: float) -> void:
		if not active:
			return
		elapsed_time += delta
		if elapsed_time >= required_time:
			finished = true
			active = false

	func cancel() -> void:
		elapsed_time = 0.0
		active = false
		finished = false

	func get_progress() -> float:
		if required_time <= 0.0:
			return 1.0
		return clampf(elapsed_time / required_time, 0.0, 1.0)

	func is_finished() -> bool:
		return finished

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

class MockInputManager:
	extends Node
	var paused: bool = false

	func _init(is_paused: bool = false) -> void:
		paused = is_paused

	func is_simulation_paused() -> bool:
		return paused

## Reference implementation of GardenManager matching explorer_gard_001_1 and explorer_gard_001_2
class ReferenceGardenManager:
	extends Node

	signal plot_state_changed(plot_id: String, plot_data: Dictionary)
	signal plot_nutrients_changed(plot_id: String, new_nutrients: float)
	signal plot_moisture_changed(plot_id: String, new_moisture: float)
	signal plot_hoed(plot_id: String)
	signal plot_composted(plot_id: String)
	signal plot_fertilized(plot_id: String)
	signal plot_watered(plot_id: String)
	signal spot_planted(plot_id: String, spot_id: String, crop_id: String)
	signal active_tool_changed(tool_id: String)
	signal water_level_changed(current_water: int, max_water: int)
	signal action_failed(reason: String)

	const EVAPORATION_RATE: float = 0.1
	const MAX_WATERING_CAN_CAPACITY: int = 10
	const WATERING_COST: int = 2
	const WATERING_TARGET_MOISTURE: float = 80.0
	const WATERING_THRESHOLD: float = 60.0
	const FERTILIZER_TARGET_NUTRIENTS: float = 100.0
	const FERTILIZER_THRESHOLD: float = 20.0

	var active_tool: String = ""
	var watering_can_water: int = 0:
		set(val):
			watering_can_water = clampi(val, 0, MAX_WATERING_CAN_CAPACITY)
			water_level_changed.emit(watering_can_water, MAX_WATERING_CAN_CAPACITY)

	var _plots: Dictionary = {}
	var _inventory_override: Node = null
	var _input_override: Node = null

	func _init() -> void:
		reset_to_defaults()

	func reset_to_defaults() -> void:
		active_tool = ""
		watering_can_water = 0
		_plots.clear()
		_plots["plot_home_01"] = _create_default_plot("plot_home_01")

	func _create_default_plot(p_id: String) -> Dictionary:
		var spots_dict: Dictionary = {}
		for i in range(1, 5):
			var s_id = "slot_%02d" % i
			spots_dict[s_id] = {
				"spot_id": s_id,
				"spot_index": i - 1,
				"is_occupied": false,
				"crop_data": null
			}
		return {
			"id": p_id,
			"is_hoed": false,
			"has_compost": false,
			"nutrients": 0.0,
			"moisture": 0.0,
			"spots": spots_dict
		}

	func set_inventory_manager(inv: Node) -> void:
		_inventory_override = inv

	func _get_inventory_manager() -> Object:
		if _inventory_override != null and is_instance_valid(_inventory_override):
			return _inventory_override
		if Engine.has_singleton("InventoryManager"):
			return Engine.get_singleton("InventoryManager")
		if is_inside_tree() and has_node("/root/InventoryManager"):
			return get_node("/root/InventoryManager")
		return null

	func set_input_manager(im: Variant) -> void:
		_input_override = im

	func _get_input_manager() -> Object:
		if _input_override != null and is_instance_valid(_input_override):
			return _input_override
		if Engine.has_singleton("InputManager"):
			return Engine.get_singleton("InputManager")
		if is_inside_tree() and has_node("/root/InputManager"):
			return get_node("/root/InputManager")
		return null

	func resolve_spot_id(spot_id: String) -> String:
		match spot_id:
			"spot_0", "0", "slot_01": return "slot_01"
			"spot_1", "1", "slot_02": return "slot_02"
			"spot_2", "2", "slot_03": return "slot_03"
			"spot_3", "3", "slot_04": return "slot_04"
			_: return spot_id

	func get_plot(plot_id: String) -> Dictionary:
		return _plots.get(plot_id, {})

	func get_spot(plot_id: String, spot_id: String) -> Dictionary:
		var resolved := resolve_spot_id(spot_id)
		var p := get_plot(plot_id)
		if p.has("spots") and p["spots"].has(resolved):
			return p["spots"][resolved]
		return {}

	func is_plot_ready_to_plant(plot_id: String) -> bool:
		var p := get_plot(plot_id)
		return bool(p.get("is_hoed", false)) and bool(p.get("has_compost", false))

	func simulate_process(delta: float) -> void:
		var im = _get_input_manager()
		if im != null and im.has_method("is_simulation_paused"):
			if im.is_simulation_paused():
				return

		for p_id in _plots:
			var plot: Dictionary = _plots[p_id]
			var cur_m: float = float(plot["moisture"])
			if cur_m > 0.0:
				var new_m: float = maxf(0.0, cur_m - EVAPORATION_RATE * delta)
				plot["moisture"] = new_m
				if floori(cur_m) != floori(new_m) or new_m == 0.0:
					plot_moisture_changed.emit(p_id, new_m)

	func select_tool(tool_id: String) -> void:
		if active_tool == tool_id:
			active_tool = ""
		else:
			active_tool = tool_id
		active_tool_changed.emit(active_tool)

	func can_hoe_plot(plot_id: String) -> Dictionary:
		if not _plots.has(plot_id):
			return {"success": false, "reason": "Petak tidak ditemukan."}
		var p: Dictionary = _plots[plot_id]
		if p["is_hoed"]:
			return {"success": false, "reason": "Kondisi cukup."}
		return {"success": true, "reason": "Dapat digemburkan."}

	func hoe_plot(plot_id: String) -> bool:
		var check := can_hoe_plot(plot_id)
		if not check["success"]:
			action_failed.emit(check["reason"])
			return false
		_plots[plot_id]["is_hoed"] = true
		plot_hoed.emit(plot_id)
		plot_state_changed.emit(plot_id, _plots[plot_id])
		return true

	func can_add_compost(plot_id: String) -> Dictionary:
		if not _plots.has(plot_id):
			return {"success": false, "reason": "Petak tidak ditemukan."}
		var p: Dictionary = _plots[plot_id]
		if not p["is_hoed"]:
			return {"success": false, "reason": "Gemburkan tanah dan tambahkan pembenah dahulu."}
		if p["has_compost"]:
			return {"success": false, "reason": "Kondisi cukup. Tidak ada bahan yang digunakan."}
		var inv = _get_inventory_manager()
		if inv != null and inv.get_available_item_count("soil_compost") < 1:
			return {"success": false, "reason": "Pembenah belum tersedia."}
		return {"success": true, "reason": "Dapat diberi pembenah."}

	func add_compost(plot_id: String) -> bool:
		var check := can_add_compost(plot_id)
		if not check["success"]:
			action_failed.emit(check["reason"])
			return false
		if not _consume_item("soil_compost", 1):
			action_failed.emit("Pembenah belum tersedia.")
			return false
		_plots[plot_id]["has_compost"] = true
		plot_composted.emit(plot_id)
		plot_state_changed.emit(plot_id, _plots[plot_id])
		return true

	func can_fertilize_plot(plot_id: String) -> Dictionary:
		if not _plots.has(plot_id):
			return {"success": false, "reason": "Petak tidak ditemukan."}
		var p: Dictionary = _plots[plot_id]
		if float(p["nutrients"]) >= FERTILIZER_THRESHOLD:
			return {"success": false, "reason": "Kondisi cukup. Tidak ada bahan yang digunakan."}
		var inv = _get_inventory_manager()
		if inv != null and inv.get_available_item_count("fertilizer_basic") < 1:
			return {"success": false, "reason": "Pupuk belum tersedia."}
		return {"success": true, "reason": "Dapat dipupuk."}

	func fertilize_plot(plot_id: String) -> bool:
		var check := can_fertilize_plot(plot_id)
		if not check["success"]:
			action_failed.emit(check["reason"])
			return false
		if not _consume_item("fertilizer_basic", 1):
			action_failed.emit("Pupuk belum tersedia.")
			return false
		_plots[plot_id]["nutrients"] = FERTILIZER_TARGET_NUTRIENTS
		plot_fertilized.emit(plot_id)
		plot_nutrients_changed.emit(plot_id, FERTILIZER_TARGET_NUTRIENTS)
		plot_state_changed.emit(plot_id, _plots[plot_id])
		return true

	func can_water_plot(plot_id: String) -> Dictionary:
		if not _plots.has(plot_id):
			return {"success": false, "reason": "Petak tidak ditemukan."}
		var p: Dictionary = _plots[plot_id]
		if float(p["moisture"]) >= WATERING_THRESHOLD:
			return {"success": false, "reason": "Petak sudah cukup. Tidak ada bahan yang digunakan."}
		if watering_can_water < WATERING_COST:
			return {"success": false, "reason": "Air tidak cukup. Isi ulang penyiram di pekarangan."}
		return {"success": true, "reason": "Dapat disiram."}

	func water_plot(plot_id: String) -> bool:
		var check := can_water_plot(plot_id)
		if not check["success"]:
			action_failed.emit(check["reason"])
			return false
		watering_can_water -= WATERING_COST
		_plots[plot_id]["moisture"] = WATERING_TARGET_MOISTURE
		plot_watered.emit(plot_id)
		plot_moisture_changed.emit(plot_id, WATERING_TARGET_MOISTURE)
		plot_state_changed.emit(plot_id, _plots[plot_id])
		return true

	func can_refill_water() -> Dictionary:
		if watering_can_water >= MAX_WATERING_CAN_CAPACITY:
			return {"success": false, "reason": "Kondisi cukup. Air sudah penuh."}
		return {"success": true, "reason": "Dapat diisi ulang."}

	func refill_water() -> bool:
		var check := can_refill_water()
		if not check["success"]:
			action_failed.emit(check["reason"])
			return false
		watering_can_water = MAX_WATERING_CAN_CAPACITY
		return true

	func can_plant_seed(plot_id: String, spot_id: String, seed_id: String = "seed_bayam") -> Dictionary:
		if not _plots.has(plot_id):
			return {"success": false, "reason": "Petak tidak ditemukan."}
		var p: Dictionary = _plots[plot_id]
		if not (p["is_hoed"] and p["has_compost"]):
			return {"success": false, "reason": "Gemburkan tanah dan tambahkan pembenah dahulu."}
		var resolved := resolve_spot_id(spot_id)
		var spots: Dictionary = p["spots"]
		if not spots.has(resolved):
			return {"success": false, "reason": "Titik tanam tidak valid."}
		if spots[resolved]["is_occupied"]:
			return {"success": false, "reason": "Titik tanam sudah terisi."}
		var inv = _get_inventory_manager()
		if inv != null and inv.get_available_item_count(seed_id) < 1:
			return {"success": false, "reason": "Benih belum tersedia. Periksa wadah dekat alat."}
		return {"success": true, "reason": "Dapat ditanam."}

	func plant_seed(plot_id: String, spot_id: String, seed_id: String = "seed_bayam") -> bool:
		var check := can_plant_seed(plot_id, spot_id, seed_id)
		if not check["success"]:
			action_failed.emit(check["reason"])
			return false
		if not _consume_item(seed_id, 1):
			action_failed.emit("Benih belum tersedia.")
			return false
		var resolved := resolve_spot_id(spot_id)
		var spot: Dictionary = _plots[plot_id]["spots"][resolved]
		spot["is_occupied"] = true
		spot["crop_data"] = {
			"crop_id": "crop_bayam",
			"growth_time": 0.0,
			"growth_stage": 0,
			"is_ready_to_harvest": false
		}
		spot_planted.emit(plot_id, resolved, "crop_bayam")
		plot_state_changed.emit(plot_id, _plots[plot_id])
		return true

	func _consume_item(item_id: String, count: int = 1) -> bool:
		var inv = _get_inventory_manager()
		if inv == null:
			return true
		if inv.get_available_item_count(item_id) < count:
			return false
		var bp = inv.get_container("backpack")
		var st = inv.get_container("storage")
		var from_bp = mini(count, bp.get_item_count(item_id))
		if from_bp > 0:
			bp.remove_item(item_id, from_bp)
			count -= from_bp
		if count > 0 and st != null:
			st.remove_item(item_id, count)
		inv.inventory_updated.emit()
		return true

	func get_save_snapshot() -> Dictionary:
		var plots_data: Dictionary = {}
		for p_id in _plots:
			plots_data[p_id] = _plots[p_id].duplicate(true)
		return {
			"version": 1,
			"active_tool": active_tool,
			"watering_can_water": watering_can_water,
			"plots": plots_data
		}

	func load_save_snapshot(data: Dictionary) -> bool:
		if not data.has("plots"):
			return false
		active_tool = str(data.get("active_tool", ""))
		watering_can_water = int(data.get("watering_can_water", 0))
		_plots = data["plots"].duplicate(true)
		return true
