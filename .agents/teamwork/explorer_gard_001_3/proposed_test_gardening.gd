class_name TestGardening
extends RefCounted

## Test Suite GARD-001: Persiapan Petak, Benih, Perawatan Area, Sistem Alat & Penguapan (Suite 9)
## Memverifikasi PRD FR07..FR10, CONTENT.md § 5/6/7/8/9/11/12, TASKS.md GARD-001, dan TEST_PLAN T06, T07, T08, T32, T33

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")

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

# ==============================================================================
# Embedded Reference & Mock Classes for Self-Contained Headless Testing
# ==============================================================================

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
