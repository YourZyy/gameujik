class_name TestWorld
extends RefCounted

## Test Suite WORLD-001: Sumber Daya Dunia, Foraging, Cadangan, Istirahat & Kalender (Suite 10)
## Memverifikasi PRD FR09..FR10, CONTENT.md § 5/6/9/11/12, PROTOTYPE.md § 5.1, TASKS.md WORLD-001, dan TEST_PLAN T09, T37, T38, T39

const Assertions = preload("res://tests/assertions.gd")
const HoldActionControllerClass = preload("res://scripts/gardening/hold_action_controller.gd")
const HUDClass = preload("res://scripts/ui/hud.gd")

class MockKitchenManager extends Node:
	var active: bool = true
	func is_cooking_active() -> bool:
		return active
	func is_job_active() -> bool:
		return active

func run_all() -> bool:
	var passed := true
	print("  Running TestWorld suite (T09, T37, T38, T39, World Landmarks & Invariants)...")

	# Group 1: T09 — Emergency Reserves
	if not test_t09_starter_prerequisite():
		passed = false
	if not test_t09_rejection_when_seeds_in_backpack():
		passed = false
	if not test_t09_rejection_when_seeds_in_storage():
		passed = false
	if not test_t09_rejection_when_living_plants_on_plot():
		passed = false
	if not test_t09_emergency_seeds_delivery():
		passed = false
	if not test_t09_emergency_seeds_idempotency():
		passed = false
	if not test_t09_emergency_seeds_full_bag_atomic_rejection():
		passed = false
	if not test_t09_emergency_compost_delivery():
		passed = false
	if not test_t09_emergency_fertilizer_delivery():
		passed = false
	if not test_t09_no_emergency_rejection():
		passed = false

	# Group 2: T37 — Water Station Refill & Hold Controller Invariants
	if not test_t37_water_refill_commit():
		passed = false
	if not test_t37_water_refill_cancellation_invariant():
		passed = false
	if not test_t37_water_refill_full_rejection():
		passed = false
	if not test_t37_hold_controller_must_release_guard():
		passed = false

	# Group 3: T38 — Daily Wild Foraging Nodes
	if not test_t38_initial_foraging_harvest():
		passed = false
	if not test_t38_same_day_quota_rejection():
		passed = false
	if not test_t38_node_independence():
		passed = false
	if not test_t38_full_bag_atomic_rejection():
		passed = false

	# Group 4: T39 — Bed Sleep, Day Cycle, & Agricultural Non-Decay Invariance
	if not test_t39_sleep_advances_day_and_resets_time():
		passed = false
	if not test_t39_sleep_restores_foraging_nodes():
		passed = false
	if not test_t39_agricultural_non_decay_invariance():
		passed = false
	if not test_t39_sleep_rejection_when_kitchen_active():
		passed = false
	if not test_t39_continuous_day_cycle_720s():
		passed = false
	if not test_t39_save_snapshot_roundtrip():
		passed = false
	if not test_t39_graybox_scene_landmarks_integration():
		passed = false

	return passed

func _get_wrm() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null("WorldResourceManager")
	return null

func _get_inv() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null("InventoryManager")
	return null

func _get_gm() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null("GardenManager")
	return null

# ==============================================================================
# GROUP 1: T09 — TITIK CADANGAN DARURAT (reserve_home)
# ==============================================================================

func test_t09_starter_prerequisite() -> bool:
	print("    [RUN] T09.1: Gate Prerequisite — Starter Container Required Before Emergency Reserve")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	var inv = _get_inv()
	Assertions.assert_not_null(wrm, "WorldResourceManager must be present")
	Assertions.assert_not_null(inv, "InventoryManager must be present")

	wrm.reset_state()
	inv.starter_claimed = false
	inv.backpack.clear()
	inv.storage_home.clear()

	var check: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_false(check.get("success", true), "Reserve claim rejected when starter not collected")
	Assertions.assert_equal(check.get("reason", ""), "Ambil wadah awal dekat alat terlebih dahulu.", "Reason points to starter crate")

	var claimed: bool = wrm.claim_emergency_reserve()
	Assertions.assert_false(claimed, "claim_emergency_reserve must return false")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 0, "No items given")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T09.1: Gate Prerequisite verified.")
	return ok

func test_t09_rejection_when_seeds_in_backpack() -> bool:
	print("    [RUN] T09.2: Rejection When Seeds Exist in Backpack (T38 Invariant)")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	var inv = _get_inv()
	wrm.reset_state()
	inv.starter_claimed = true
	inv.backpack.clear()
	inv.storage_home.clear()

	inv.backpack.add_item("seed_bayam", 2)
	var check: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_false(check.get("success", true), "Reserve claim rejected when seeds in backpack")
	Assertions.assert_true(str(check.get("reason", "")).contains("tas atau peti"), "Reason mentions bag/chest location")

	var claimed: bool = wrm.claim_emergency_reserve()
	Assertions.assert_false(claimed, "Claim must return false")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 2, "Backpack seed count unchanged")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T09.2: Rejection When Seeds in Backpack verified.")
	return ok

func test_t09_rejection_when_seeds_in_storage() -> bool:
	print("    [RUN] T09.3: Rejection When Seeds Exist in Storage Chest")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	var inv = _get_inv()
	wrm.reset_state()
	inv.starter_claimed = true
	inv.backpack.clear()
	inv.storage_home.clear()

	inv.storage_home.add_item("seed_bayam", 1)
	var check: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_false(check.get("success", true), "Reserve claim rejected when seeds in storage")
	Assertions.assert_true(str(check.get("reason", "")).contains("tas atau peti"), "Reason mentions storage location")

	var claimed: bool = wrm.claim_emergency_reserve()
	Assertions.assert_false(claimed, "Claim must return false")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T09.3: Rejection When Seeds in Storage verified.")
	return ok

func test_t09_rejection_when_living_plants_on_plot() -> bool:
	print("    [RUN] T09.4: Rejection When Living Plants Occupy Plot Spots (T38 Invariant)")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	var inv = _get_inv()
	var gm = _get_gm()
	wrm.reset_state()
	inv.starter_claimed = true
	inv.backpack.clear()
	inv.storage_home.clear()
	gm.reset_to_defaults()

	# Prepare plot and plant on slot_01
	var plot: Dictionary = gm.get_plot("plot_home_01")
	plot["is_hoed"] = true
	plot["has_compost"] = true
	plot["spots"]["slot_01"]["is_occupied"] = true
	plot["spots"]["slot_01"]["crop_data"] = {
		"crop_id": "crop_bayam",
		"growth_stage": 1,
		"growth_time": 40.0,
		"is_ready_to_harvest": false
	}

	var check: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_false(check.get("success", true), "Reserve rejected while plants are growing")
	Assertions.assert_true(str(check.get("reason", "")).contains("sedang tumbuh"), "Reason explains living plants will yield seeds")

	var claimed: bool = wrm.claim_emergency_reserve()
	Assertions.assert_false(claimed, "Claim rejected")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T09.4: Rejection When Living Plants on Plot verified.")
	return ok

func test_t09_emergency_seeds_delivery() -> bool:
	print("    [RUN] T09.5: Emergency Seeds Delivery on Total Depletion (4 Seeds Pack)")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	var inv = _get_inv()
	var gm = _get_gm()
	wrm.reset_state()
	inv.starter_claimed = true
	inv.backpack.clear()
	inv.storage_home.clear()
	gm.reset_to_defaults()

	# Ensure 0 seeds, 0 plants
	Assertions.assert_equal(inv.get_available_item_count("seed_bayam"), 0, "0 seeds initially")
	var check: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_true(check.get("success", false), "Emergency reserve ready to claim")
	Assertions.assert_equal(check.get("type", ""), "seed", "Reserve type is seed")
	Assertions.assert_equal(check.get("item_id", ""), "seed_bayam", "Item ID is seed_bayam")
	Assertions.assert_equal(check.get("count", 0), 4, "Count is 4 seeds")

	var claimed: bool = wrm.claim_emergency_reserve()
	Assertions.assert_true(claimed, "Emergency seeds successfully claimed")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "Backpack now contains exactly 4 seed_bayam")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T09.5: Emergency Seeds Delivery verified.")
	return ok

func test_t09_emergency_seeds_idempotency() -> bool:
	print("    [RUN] T09.6: Idempotency & Immediate Re-attempt Rejection")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	var inv = _get_inv()

	# Player already has 4 seeds from previous test
	Assertions.assert_gt(inv.get_available_item_count("seed_bayam"), 0, "Player already has seeds")
	var check: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_false(check.get("success", true), "Immediate second claim rejected")

	var claimed: bool = wrm.claim_emergency_reserve()
	Assertions.assert_false(claimed, "Duplicate claim prevented")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "Seed count not duplicated")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T09.6: Idempotency verified.")
	return ok

func test_t09_emergency_seeds_full_bag_atomic_rejection() -> bool:
	print("    [RUN] T09.7: Full Bag Atomic Rejection (Preserves Reserve Entitlement)")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	var inv = _get_inv()
	var gm = _get_gm()
	wrm.reset_state()
	inv.starter_claimed = true
	inv.backpack.clear()
	inv.storage_home.clear()
	gm.reset_to_defaults()

	# Fill all 12 slots with 20x fertilizer
	for i in range(12):
		inv.backpack.slots[i].set_item("fertilizer_basic", 20)
	inv.backpack.contents_changed.emit()

	var check: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_false(check.get("success", true), "Rejected when backpack has no room")
	Assertions.assert_true(str(check.get("reason", "")).contains("Tas tidak cukup"), "Reason explains full bag")

	var claimed: bool = wrm.claim_emergency_reserve()
	Assertions.assert_false(claimed, "Claim fails atomically")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 0, "No seeds added")

	# Free 1 slot in backpack
	inv.backpack.slots[0].clear()
	inv.backpack.contents_changed.emit()

	# Now claim must succeed
	var check_after: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_true(check_after.get("success", false), "Claim valid after freeing 1 slot")
	var claimed_after: bool = wrm.claim_emergency_reserve()
	Assertions.assert_true(claimed_after, "Reserve successfully claimed")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "4 seeds added into freed slot")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T09.7: Full Bag Atomic Rejection verified.")
	return ok

func test_t09_emergency_compost_delivery() -> bool:
	print("    [RUN] T09.8: Emergency Soil Compost Delivery (Hoed, Uncomposted, 0 Stock)")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	var inv = _get_inv()
	var gm = _get_gm()
	wrm.reset_state()
	inv.starter_claimed = true
	inv.backpack.clear()
	inv.storage_home.clear()
	gm.reset_to_defaults()

	# Player has seeds (so seed check does not trigger)
	inv.backpack.add_item("seed_bayam", 1)
	# Plot is hoed but not composted
	var plot: Dictionary = gm.get_plot("plot_home_01")
	plot["is_hoed"] = true
	plot["has_compost"] = false

	var check: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_true(check.get("success", false), "Emergency compost available")
	Assertions.assert_equal(check.get("type", ""), "compost", "Type is compost")
	Assertions.assert_equal(check.get("item_id", ""), "soil_compost", "Item is soil_compost")
	Assertions.assert_equal(check.get("count", 0), 1, "Count is 1")

	var claimed: bool = wrm.claim_emergency_reserve()
	Assertions.assert_true(claimed, "Compost claimed")
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 1, "Backpack received 1 soil_compost")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T09.8: Emergency Soil Compost Delivery verified.")
	return ok

func test_t09_emergency_fertilizer_delivery() -> bool:
	print("    [RUN] T09.9: Emergency Fertilizer Delivery (Nutrients < 20, 0 Stock)")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	var inv = _get_inv()
	var gm = _get_gm()
	wrm.reset_state()
	inv.starter_claimed = true
	inv.backpack.clear()
	inv.storage_home.clear()
	gm.reset_to_defaults()

	# Player has seeds and compost, but plot nutrients < 20
	inv.backpack.add_item("seed_bayam", 1)
	var plot: Dictionary = gm.get_plot("plot_home_01")
	plot["is_hoed"] = true
	plot["has_compost"] = true
	plot["nutrients"] = 15.0

	var check: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_true(check.get("success", false), "Emergency fertilizer available")
	Assertions.assert_equal(check.get("type", ""), "fertilizer", "Type is fertilizer")
	Assertions.assert_equal(check.get("item_id", ""), "fertilizer_basic", "Item is fertilizer_basic")
	Assertions.assert_equal(check.get("count", 0), 1, "Count is 1")

	var claimed: bool = wrm.claim_emergency_reserve()
	Assertions.assert_true(claimed, "Fertilizer claimed")
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 1, "Backpack received 1 fertilizer_basic")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T09.9: Emergency Fertilizer Delivery verified.")
	return ok

func test_t09_no_emergency_rejection() -> bool:
	print("    [RUN] T09.10: Honest Rejection When Conditions Not Depleted")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	var inv = _get_inv()
	var gm = _get_gm()
	wrm.reset_state()
	inv.starter_claimed = true
	inv.backpack.clear()
	inv.storage_home.clear()
	gm.reset_to_defaults()

	# Healthy condition: seeds exist, plot is prepared with nutrients
	inv.backpack.add_item("seed_bayam", 2)
	inv.backpack.add_item("soil_compost", 1)
	inv.backpack.add_item("fertilizer_basic", 1)
	var plot: Dictionary = gm.get_plot("plot_home_01")
	plot["is_hoed"] = true
	plot["has_compost"] = true
	plot["nutrients"] = 80.0

	var check: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_false(check.get("success", true), "Claim rejected when conditions healthy")
	Assertions.assert_true(str(check.get("reason", "")).contains("tas atau peti"), "Reason clarifies seeds available")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T09.10: Honest Rejection verified.")
	return ok

# ==============================================================================
# GROUP 2: T37 — STASIUN AIR PEKARANGAN (water_home) & HOLD ACTION
# ==============================================================================

func test_t37_water_refill_commit() -> bool:
	print("    [RUN] T37.1: Water Station Refill Hold 2.0s Full Commit (10/10)")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	var gm = _get_gm()
	gm.watering_can_water = 0

	var controller := HoldActionControllerClass.new()
	var completed := [false]
	controller.hold_completed.connect(func(act_id):
		if act_id == "refill":
			completed[0] = true
			wrm.refill_water()
	)

	controller.start("refill", "water_home", 2.0, &"interact")
	Assertions.assert_true(controller.is_active(), "Hold controller active")
	controller.tick(1.0, true, true)
	Assertions.assert_false(completed[0], "Not completed at 1.0s")
	Assertions.assert_equal(gm.watering_can_water, 0, "Water unchanged before commit")

	controller.tick(1.0, true, true)
	Assertions.assert_true(completed[0], "Completed after 2.0s")
	Assertions.assert_equal(gm.watering_can_water, 10, "Water filled to capacity 10/10")
	Assertions.assert_equal(gm.get_watering_can_charges(), 10, "charges getter matches 10")
	Assertions.assert_equal(gm.get_max_watering_can_charges(), 10, "max charges getter matches 10")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T37.1: Water Refill Commit verified.")
	return ok

func test_t37_water_refill_cancellation_invariant() -> bool:
	print("    [RUN] T37.2: Refill Cancellation < 2.0s Invariant (0 Changes / Zero Cost)")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	var gm = _get_gm()
	gm.watering_can_water = 3

	var controller := HoldActionControllerClass.new()
	var cancelled := [false]
	controller.hold_cancelled.connect(func(_act): cancelled[0] = true)

	controller.start("refill", "water_home", 2.0, &"interact")
	controller.tick(1.4, true, true)
	Assertions.assert_gt(controller.get_progress(), 0.5, "Progress reached ~70%")
	Assertions.assert_equal(gm.watering_can_water, 3, "Water remains 3 during hold")

	# Player releases button at 1.4s
	controller.tick(0.016, false, true)
	Assertions.assert_true(cancelled[0], "Cancelled signal emitted")
	Assertions.assert_false(controller.is_active(), "Controller reset to IDLE")
	Assertions.assert_equal(controller.get_progress(), 0.0, "Progress reset to 0.0")
	Assertions.assert_equal(gm.watering_can_water, 3, "Water exactly preserved at 3 (zero gain)")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T37.2: Refill Cancellation Invariant verified.")
	return ok

func test_t37_water_refill_full_rejection() -> bool:
	print("    [RUN] T37.3: Water Refill Full Capacity (10/10) Rejection")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	var gm = _get_gm()
	gm.watering_can_water = 10

	var check: Dictionary = wrm.can_refill_water()
	Assertions.assert_false(check.get("success", true), "Refill rejected when water is 10/10")
	Assertions.assert_equal(check.get("reason", ""), "Kondisi cukup. Air sudah penuh.", "Reason matches CONTENT §11")

	var refilled: bool = wrm.refill_water()
	Assertions.assert_false(refilled, "refill_water must return false")
	Assertions.assert_equal(gm.watering_can_water, 10, "Water level capped at 10")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T37.3: Full Water Rejection verified.")
	return ok

func test_t37_hold_controller_must_release_guard() -> bool:
	print("    [RUN] T37.4: HoldActionController MUST_RELEASE Anti-Spam Guard")
	var initial_failures := Assertions.current_suite_failed
	var controller := HoldActionControllerClass.new()
	var commit_count := [0]
	controller.hold_completed.connect(func(_a): commit_count[0] += 1)

	controller.start("refill", "water_home", 2.0, &"interact")
	controller.tick(2.0, true, true)
	Assertions.assert_equal(commit_count[0], 1, "Committed once at 2.0s")
	Assertions.assert_equal(controller.state, controller.State.MUST_RELEASE, "State transitioned to MUST_RELEASE")

	# Continue ticking with button held for another 3.0s
	controller.tick(1.0, true, true)
	controller.tick(1.0, true, true)
	controller.tick(1.0, true, true)
	Assertions.assert_equal(commit_count[0], 1, "Did not re-commit while button continuously held")
	Assertions.assert_equal(controller.state, controller.State.MUST_RELEASE, "Remains in MUST_RELEASE")

	# Release button
	controller.tick(0.016, false, true)
	Assertions.assert_equal(controller.state, controller.State.IDLE, "Returns to IDLE upon button release")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T37.4: MUST_RELEASE Anti-Spam Guard verified.")
	return ok

# ==============================================================================
# GROUP 3: T38 — FORAGING HARIAN LIAR (resource_jagung_01, resource_temu_kunci_01)
# ==============================================================================

func test_t38_initial_foraging_harvest() -> bool:
	print("    [RUN] T38.1: Daily Foraging Harvest — 1 Corn & 1 Temu Kunci Yield")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	var inv = _get_inv()
	wrm.reset_state()
	inv.backpack.clear()

	Assertions.assert_true(wrm.is_foraging_node_available("resource_jagung_01"), "Corn node available on Day 1")
	Assertions.assert_true(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Temu kunci node available on Day 1")

	var check_jagung: Dictionary = wrm.can_harvest_foraging("resource_jagung_01")
	Assertions.assert_true(check_jagung.get("success", false), "Can harvest corn")
	var ok_jagung: bool = wrm.harvest_foraging("resource_jagung_01")
	Assertions.assert_true(ok_jagung, "Corn harvest succeeded")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 1, "Backpack has 1 ingredient_jagung")
	Assertions.assert_false(wrm.is_foraging_node_available("resource_jagung_01"), "Corn node now marked harvested")

	var check_temu: Dictionary = wrm.can_harvest_foraging("resource_temu_kunci_01")
	Assertions.assert_true(check_temu.get("success", false), "Can harvest temu kunci")
	var ok_temu: bool = wrm.harvest_foraging("resource_temu_kunci_01")
	Assertions.assert_true(ok_temu, "Temu kunci harvest succeeded")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 1, "Backpack has 1 ingredient_temu_kunci")
	Assertions.assert_false(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Temu kunci now marked harvested")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T38.1: Initial Foraging Harvest verified.")
	return ok

func test_t38_same_day_quota_rejection() -> bool:
	print("    [RUN] T38.2: Same Day Second Harvest Rejection (Daily Quota 1x)")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	var inv = _get_inv()

	# Nodes already harvested on Day 1 in previous test
	var check_jagung: Dictionary = wrm.can_harvest_foraging("resource_jagung_01")
	Assertions.assert_false(check_jagung.get("success", true), "Second corn harvest on Day 1 rejected")
	Assertions.assert_equal(check_jagung.get("reason", ""), "Sumber daya sudah diambil hari ini. Tunggu besok.", "Rejection reason accurate")

	var ok_jagung: bool = wrm.harvest_foraging("resource_jagung_01")
	Assertions.assert_false(ok_jagung, "harvest_foraging returns false")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 1, "Corn count unchanged")

	var check_temu: Dictionary = wrm.can_harvest_foraging("resource_temu_kunci_01")
	Assertions.assert_false(check_temu.get("success", true), "Second temu kunci harvest on Day 1 rejected")
	var ok_temu: bool = wrm.harvest_foraging("resource_temu_kunci_01")
	Assertions.assert_false(ok_temu, "harvest_foraging returns false")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 1, "Temu count unchanged")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T38.2: Same Day Quota Rejection verified.")
	return ok

func test_t38_node_independence() -> bool:
	print("    [RUN] T38.3: Independent Foraging Node Quotas")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	wrm.reset_state()
	wrm.last_harvested_day["resource_jagung_01"] = 1
	wrm.last_harvested_day["resource_temu_kunci_01"] = 0

	Assertions.assert_false(wrm.is_foraging_node_available("resource_jagung_01"), "Corn node depleted")
	Assertions.assert_true(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Temu kunci node still available")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T38.3: Independent Node Quotas verified.")
	return ok

func test_t38_full_bag_atomic_rejection() -> bool:
	print("    [RUN] T38.4: Full Bag Atomic Rejection (Preserves Daily Harvest Quota)")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	var inv = _get_inv()
	wrm.reset_state()
	inv.backpack.clear()

	# Fill all 12 slots with fertilizer
	for i in range(12):
		inv.backpack.slots[i].set_item("fertilizer_basic", 20)
	inv.backpack.contents_changed.emit()

	var check: Dictionary = wrm.can_harvest_foraging("resource_jagung_01")
	Assertions.assert_false(check.get("success", true), "Foraging rejected when backpack full")
	Assertions.assert_true(str(check.get("reason", "")).contains("Tas tidak cukup"), "Reason explains full bag")

	var harvested: bool = wrm.harvest_foraging("resource_jagung_01")
	Assertions.assert_false(harvested, "Harvest failed")
	Assertions.assert_true(wrm.is_foraging_node_available("resource_jagung_01"), "Corn node remains harvestable (quota NOT lost)")

	# Free 1 slot
	inv.backpack.slots[0].clear()
	inv.backpack.contents_changed.emit()

	# Now harvest succeeds
	var harvested_after: bool = wrm.harvest_foraging("resource_jagung_01")
	Assertions.assert_true(harvested_after, "Harvest succeeds after slot freed")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 1, "Corn added to bag")
	Assertions.assert_false(wrm.is_foraging_node_available("resource_jagung_01"), "Quota consumed only upon success")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T38.4: Full Bag Atomic Rejection verified.")
	return ok

# ==============================================================================
# GROUP 4: T39 — KASUR ISTIRAHAT, SIKLUS HARI, & INVARIAN NON-DECAY
# ==============================================================================

func test_t39_sleep_advances_day_and_resets_time() -> bool:
	print("    [RUN] T39.1: Bed Sleep Advances Day & Resets Active Simulation Time")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	wrm.reset_state()
	wrm.current_day = 1
	wrm.day_active_time = 420.0

	var rested: bool = wrm.sleep_and_advance_day()
	Assertions.assert_true(rested, "Sleep action succeeded")
	Assertions.assert_equal(wrm.current_day, 2, "current_day advanced to 2")
	Assertions.assert_equal(wrm.day_active_time, 0.0, "day_active_time reset to 0.0")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T39.1: Bed Sleep Advances Day verified.")
	return ok

func test_t39_sleep_restores_foraging_nodes() -> bool:
	print("    [RUN] T39.2: Bed Sleep Restores Daily Foraging Nodes (Corn & Temu Kunci)")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	var inv = _get_inv()
	wrm.reset_state()
	inv.backpack.clear()

	# Harvest Day 1
	wrm.harvest_foraging("resource_jagung_01")
	wrm.harvest_foraging("resource_temu_kunci_01")
	Assertions.assert_false(wrm.is_foraging_node_available("resource_jagung_01"), "Corn depleted Day 1")
	Assertions.assert_false(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Temu depleted Day 1")

	# Sleep to Day 2
	wrm.sleep_and_advance_day()
	Assertions.assert_equal(wrm.current_day, 2, "Advanced to Day 2")
	Assertions.assert_true(wrm.is_foraging_node_available("resource_jagung_01"), "Corn restored Day 2")
	Assertions.assert_true(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Temu restored Day 2")

	# Harvest Day 2
	var ok_j: bool = wrm.harvest_foraging("resource_jagung_01")
	var ok_t: bool = wrm.harvest_foraging("resource_temu_kunci_01")
	Assertions.assert_true(ok_j, "Harvested corn Day 2")
	Assertions.assert_true(ok_t, "Harvested temu Day 2")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 2, "Total 2 corn in backpack")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 2, "Total 2 temu in backpack")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T39.2: Sleep Restores Foraging Nodes verified.")
	return ok

func test_t39_agricultural_non_decay_invariance() -> bool:
	print("    [RUN] T39.3: CRITICAL INVARIANT — Agricultural Non-Decay on Sleep (Zero Plot Loss)")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	var gm = _get_gm()
	wrm.reset_state()
	gm.reset_to_defaults()

	# Setup specific plot moisture, nutrients and growing plants
	var plot: Dictionary = gm.get_plot("plot_home_01")
	plot["is_hoed"] = true
	plot["has_compost"] = true
	plot["moisture"] = 55.5
	plot["nutrients"] = 77.7

	var spots: Dictionary = plot["spots"]
	spots["slot_01"]["is_occupied"] = true
	spots["slot_01"]["crop_data"] = {
		"crop_id": "crop_bayam",
		"growth_stage": 1,
		"growth_time": 45.0,
		"is_ready_to_harvest": false,
		"is_stalled": false
	}

	spots["slot_02"]["is_occupied"] = true
	spots["slot_02"]["crop_data"] = {
		"crop_id": "crop_bayam",
		"growth_stage": 2,
		"growth_time": 120.0,
		"is_ready_to_harvest": false,
		"is_stalled": false
	}

	# Execute sleep to Day 2
	wrm.sleep_and_advance_day()
	Assertions.assert_equal(wrm.current_day, 2, "New day reached")

	# Verify plot and crop data are 100% PRESERVED WITHOUT DECAY
	var plot_after: Dictionary = gm.get_plot("plot_home_01")
	Assertions.assert_approx_equal(float(plot_after["moisture"]), 55.5, 0.001, "Moisture perfectly preserved (NO 72.0 evaporation!)")
	Assertions.assert_approx_equal(float(plot_after["nutrients"]), 77.7, 0.001, "Nutrients perfectly preserved")

	var s1 = plot_after["spots"]["slot_01"]["crop_data"]
	Assertions.assert_equal(int(s1["growth_stage"]), 1, "Slot 1 stage unchanged")
	Assertions.assert_approx_equal(float(s1["growth_time"]), 45.0, 0.001, "Slot 1 growth time unchanged")

	var s2 = plot_after["spots"]["slot_02"]["crop_data"]
	Assertions.assert_equal(int(s2["growth_stage"]), 2, "Slot 2 stage unchanged")
	Assertions.assert_approx_equal(float(s2["growth_time"]), 120.0, 0.001, "Slot 2 growth time unchanged")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T39.3: Agricultural Non-Decay Invariance verified.")
	return ok

func test_t39_sleep_rejection_when_kitchen_active() -> bool:
	print("    [RUN] T39.4: Sleep Rejection When Kitchen Cooking Active")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	wrm.reset_state()

	var mock_km := MockKitchenManager.new()
	mock_km.active = true
	wrm.set_kitchen_manager(mock_km)

	var check: Dictionary = wrm.can_sleep()
	Assertions.assert_false(check.get("success", true), "Sleep rejected while kitchen active")
	Assertions.assert_true(str(check.get("reason", "")).contains("memasak"), "Reason indicates active cooking process")

	var rested: bool = wrm.sleep_and_advance_day()
	Assertions.assert_false(rested, "sleep_and_advance_day returns false")
	Assertions.assert_equal(wrm.current_day, 1, "Day remains 1")

	# Kitchen job completes/idle
	mock_km.active = false
	var check_after: Dictionary = wrm.can_sleep()
	Assertions.assert_true(check_after.get("success", false), "Sleep allowed when kitchen idle")
	var rested_after: bool = wrm.sleep_and_advance_day()
	Assertions.assert_true(rested_after, "Sleep succeeds")
	Assertions.assert_equal(wrm.current_day, 2, "Day advances to 2")

	wrm.set_kitchen_manager(null)
	mock_km.free()

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T39.4: Sleep Rejection When Kitchen Active verified.")
	return ok

func test_t39_continuous_day_cycle_720s() -> bool:
	print("    [RUN] T39.5: Continuous 720.0s Natural Day Cycle Progression")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	wrm.reset_state()
	wrm.current_day = 1
	wrm.day_active_time = 719.5

	# Process 0.6 seconds to cross 720.0s threshold
	wrm._process(0.6)
	Assertions.assert_equal(wrm.current_day, 2, "Day naturally advanced from 1 to 2")
	Assertions.assert_equal(wrm.day_active_time, 0.0, "Active time reset to 0.0")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T39.5: Continuous Day Cycle Progression verified.")
	return ok

func test_t39_save_snapshot_roundtrip() -> bool:
	print("    [RUN] T39.6: Save Snapshot Round-Trip Persistence (SAVE-001 Contract)")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	wrm.reset_state()

	wrm.current_day = 4
	wrm.day_active_time = 185.5
	wrm.last_harvested_day["resource_jagung_01"] = 4
	wrm.last_harvested_day["resource_temu_kunci_01"] = 3

	var snapshot: Dictionary = wrm.get_save_snapshot()
	Assertions.assert_equal(int(snapshot["version"]), 1, "Snapshot version is 1")
	Assertions.assert_equal(int(snapshot["current_day"]), 4, "Snapshot day is 4")
	Assertions.assert_approx_equal(float(snapshot["day_active_time"]), 185.5, 0.001, "Snapshot time is 185.5")

	# Reset and load back
	wrm.reset_state()
	Assertions.assert_equal(wrm.current_day, 1, "Reset day is 1")

	var loaded: bool = wrm.load_save_snapshot(snapshot)
	Assertions.assert_true(loaded, "Snapshot loaded successfully")
	Assertions.assert_equal(wrm.current_day, 4, "Restored day is 4")
	Assertions.assert_approx_equal(wrm.day_active_time, 185.5, 0.001, "Restored time is 185.5")
	Assertions.assert_false(wrm.is_foraging_node_available("resource_jagung_01"), "Corn node preserved as depleted")
	Assertions.assert_true(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Temu node preserved as available")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T39.6: Save Snapshot Roundtrip verified.")
	return ok

func test_t39_graybox_scene_landmarks_integration() -> bool:
	print("    [RUN] T39.7: World Graybox Landmarks & HUD Contextual Prompts Integration")
	var initial_failures := Assertions.current_suite_failed
	var wrm := _get_wrm()
	wrm.reset_state()

	var scene_res := load("res://scenes/world/level_graybox.tscn") as PackedScene
	Assertions.assert_not_null(scene_res, "level_graybox.tscn must load")
	var level = scene_res.instantiate() as Node3D
	Assertions.assert_not_null(level, "level instance valid")

	var hud_res := load("res://scenes/ui/hud.tscn") as PackedScene
	var hud_node: Node = null
	if hud_res != null:
		hud_node = hud_res.instantiate()
	else:
		hud_node = HUDClass.new()

	var landmarks: Array[String] = [
		"resource_jagung_01",
		"resource_temu_kunci_01",
		"reserve_home",
		"bed_home",
		"water_home"
	]

	for lm_name in landmarks:
		var lm = level.find_child(lm_name, true, false) as Node3D
		Assertions.assert_not_null(lm, "Landmark '%s' exists in level_graybox" % lm_name)
		var interactable = lm.find_child("Interactable", true, false) if lm != null else null
		Assertions.assert_not_null(interactable, "Landmark '%s' has Interactable Area3D" % lm_name)
		if interactable != null:
			Assertions.assert_equal(interactable.collision_layer, 4, "Interactable on layer 3")

	# Test HUD Prompt formatting
	var corn_node = level.find_child("resource_jagung_01", true, false)
	var corn_interactable = corn_node.find_child("Interactable", true, false)
	var prompt_avail = hud_node.format_contextual_prompt(corn_interactable)
	Assertions.assert_equal(prompt_avail, "[E] Petik Jagung", "Corn prompt when available")

	wrm.last_harvested_day["resource_jagung_01"] = 1
	var prompt_depleted = hud_node.format_contextual_prompt(corn_interactable)
	Assertions.assert_equal(prompt_depleted, "[E] Jagung (Sudah Dipanen)", "Corn prompt when depleted")

	var temu_node = level.find_child("resource_temu_kunci_01", true, false)
	var temu_interactable = temu_node.find_child("Interactable", true, false)
	var prompt_temu = hud_node.format_contextual_prompt(temu_interactable)
	Assertions.assert_equal(prompt_temu, "[E] Petik Temu Kunci", "Temu prompt when available")

	var bed_node = level.find_child("bed_home", true, false)
	var bed_interactable = bed_node.find_child("Interactable", true, false)
	var prompt_bed = hud_node.format_contextual_prompt(bed_interactable)
	Assertions.assert_equal(prompt_bed, "[E] Istirahat Sampai Besok", "Bed prompt accurate")

	var reserve_node = level.find_child("reserve_home", true, false)
	var reserve_interactable = reserve_node.find_child("Interactable", true, false)
	var prompt_reserve = hud_node.format_contextual_prompt(reserve_interactable)
	Assertions.assert_equal(prompt_reserve, "[E] Periksa Cadangan", "Reserve prompt accurate")

	level.free()
	hud_node.free()

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T39.7: World Graybox Landmarks & HUD Integration verified.")
	return ok
