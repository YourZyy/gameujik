extends SceneTree

## Adversarial Stress Test Suite for WORLD-001 (Challenger 1)
## Empirically challenges:
## 1. Daily foraging quota saturation & anti-exploit
## 2. Emergency reserves anti-exploit lock & priority order
## 3. Well water refill & hold controller anti-spam
## 4. Multi-day sleep agricultural non-decay absolute invariant
## 5. Save/load snapshot robustness & corruption resistance
## 6. Simulation pause time-dilation gating

const HoldActionControllerClass = preload("res://scripts/gardening/hold_action_controller.gd")

var _frame: int = 0
var total_asserts: int = 0
var passed_asserts: int = 0
var failed_asserts: int = 0
var failure_details: Array[String] = []

class MockKitchen extends Node:
	var cooking: bool = false
	var job: bool = false
	func is_cooking_active() -> bool:
		return cooking
	func is_job_active() -> bool:
		return job

class MockInputManager extends Node:
	var paused: bool = false
	func is_simulation_paused() -> bool:
		return paused

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		run_all_tests()
		finish_and_quit()
		return true
	return false

func finish_and_quit() -> void:
	print("\n==================================================")
	print("[CHALLENGER_WORLD_001] SUMMARY:")
	print("  Total Assertions:  %d" % total_asserts)
	print("  Passed Assertions: %d" % passed_asserts)
	print("  Failed Assertions: %d" % failed_asserts)

	if failed_asserts == 0:
		print("  VERDICT: APPROVE — ALL ADVERSARIAL CHALLENGES PASSED (Exit Code: 0)")
		print("==================================================")
		quit(0)
	else:
		printerr("  VERDICT: REQUEST_CHANGES — %d ADVERSARIAL FAILURES (Exit Code: 1)" % failed_asserts)
		for f in failure_details:
			printerr("    - ", f)
		print("==================================================")
		quit(1)

func run_all_tests() -> void:
	print("==================================================")
	print("[CHALLENGER_WORLD_001] Running Adversarial Stress Suite...")
	print("==================================================")

	var wrm = _get_wrm()
	var inv = _get_inv()
	var gm = _get_gm()

	if wrm == null or inv == null or gm == null:
		printerr("[FATAL] Core Autoloads missing: WRM=", wrm, " INV=", inv, " GM=", gm)
		quit(1)
		return

	# Explicitly wire references to ensure isolation
	wrm.set_inventory_manager(inv)
	wrm.set_garden_manager(gm)

	test_foraging_quota_saturation(wrm, inv)
	test_foraging_full_bag_and_stack_limits(wrm, inv)
	test_foraging_fuzzing_and_invalid_nodes(wrm)
	test_emergency_reserve_gates_and_living_plants(wrm, inv, gm)
	test_emergency_reserve_full_bag_and_priority_chain(wrm, inv, gm)
	test_well_water_refill_and_hold_invariants(wrm, gm)
	test_agricultural_zero_decay_multi_day_sleep(wrm, gm)
	test_sleep_kitchen_active_lockout(wrm)
	test_save_snapshot_corruption_and_fidelity(wrm)
	test_simulation_pause_time_dilation_gate(wrm)

func check(condition: bool, label: String) -> void:
	total_asserts += 1
	if condition:
		passed_asserts += 1
	else:
		failed_asserts += 1
		var err := "FAIL: " + label
		failure_details.append(err)
		printerr("  [FAIL] ", label)

func _get_wrm() -> Node:
	return root.get_node_or_null("WorldResourceManager")

func _get_inv() -> Node:
	return root.get_node_or_null("InventoryManager")

func _get_gm() -> Node:
	return root.get_node_or_null("GardenManager")

# ==============================================================================
# TEST 1: Foraging Quota Saturation Attack (100 rapid multi-calls)
# ==============================================================================
func test_foraging_quota_saturation(wrm: Node, inv: Node) -> void:
	print("\n--- Test 1: Foraging Quota Saturation Attack (100 rapid multi-calls) ---")
	wrm.reset_state()
	inv.backpack.clear()

	check(wrm.is_foraging_node_available("resource_jagung_01"), "Corn available initially")
	check(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Temu kunci available initially")

	# Spam 100 harvests on corn
	var corn_success_count := 0
	for i in range(100):
		if wrm.harvest_foraging("resource_jagung_01"):
			corn_success_count += 1

	check(corn_success_count == 1, "Exactly 1 of 100 rapid corn harvests succeeded (quota strictly enforced)")
	check(inv.backpack.get_item_count("ingredient_jagung") == 1, "Backpack contains exactly 1 corn")
	check(not wrm.is_foraging_node_available("resource_jagung_01"), "Corn marked unavailable after harvest")

	# Check temu kunci is still available (independent quota)
	check(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Temu kunci quota remains unaffected by corn harvest")

	# Spam 100 harvests on temu kunci
	var temu_success_count := 0
	for i in range(100):
		if wrm.harvest_foraging("resource_temu_kunci_01"):
			temu_success_count += 1

	check(temu_success_count == 1, "Exactly 1 of 100 rapid temu kunci harvests succeeded")
	check(inv.backpack.get_item_count("ingredient_temu_kunci") == 1, "Backpack contains exactly 1 temu kunci")
	check(not wrm.is_foraging_node_available("resource_temu_kunci_01"), "Temu kunci marked unavailable")

# ==============================================================================
# TEST 2: Foraging Full Bag & Stack Limit Atomicity
# ==============================================================================
func test_foraging_full_bag_and_stack_limits(wrm: Node, inv: Node) -> void:
	print("\n--- Test 2: Foraging Full Bag & Stack Limits Atomicity ---")
	wrm.reset_state()
	inv.backpack.clear()

	# Fill all 12 slots with 20x fertilizer each
	for i in range(12):
		inv.backpack.slots[i].set_item("fertilizer_basic", 20)
	inv.backpack.contents_changed.emit()

	# Full bag rejection
	var check_res: Dictionary = wrm.can_harvest_foraging("resource_jagung_01")
	check(not check_res.get("success", true), "Harvest rejected when backpack completely full")
	check(str(check_res.get("reason", "")).contains("Tas tidak cukup"), "Rejection reason mentions full bag")

	var ok_harvest: bool = wrm.harvest_foraging("resource_jagung_01")
	check(not ok_harvest, "harvest_foraging returns false on full bag")
	check(wrm.is_foraging_node_available("resource_jagung_01"), "Corn node remains available; quota NOT consumed on rejected harvest")

	# Free slot 0 and place 19 corn in it (max stack is 20)
	inv.backpack.slots[0].set_item("ingredient_jagung", 19)
	inv.backpack.contents_changed.emit()

	# Day 1 harvest should now succeed and top up the stack to 20
	ok_harvest = wrm.harvest_foraging("resource_jagung_01")
	check(ok_harvest, "Harvest succeeds when stack has capacity 19 -> 20")
	check(inv.backpack.get_item_count("ingredient_jagung") == 20, "Corn stack is now exactly 20/20")
	check(not wrm.is_foraging_node_available("resource_jagung_01"), "Corn node now consumed for Day 1")

	# Advance to Day 2
	wrm.advance_day()
	check(wrm.current_day == 2, "Advanced to Day 2")
	check(wrm.is_foraging_node_available("resource_jagung_01"), "Corn node refreshed on Day 2")

	# Now slot 0 is 20/20 (full stack), and slots 1-11 are full with fertilizer. No room for more corn!
	check_res = wrm.can_harvest_foraging("resource_jagung_01")
	check(not check_res.get("success", true), "Harvest rejected on Day 2 when existing stack is 20/20 and no empty slots")
	ok_harvest = wrm.harvest_foraging("resource_jagung_01")
	check(not ok_harvest, "Harvest fails atomically on 20/20 stack overflow")
	check(wrm.is_foraging_node_available("resource_jagung_01"), "Day 2 quota preserved despite failed attempt")

	# Take 1 corn out (now 19/20)
	inv.backpack.slots[0].count = 19
	inv.backpack.contents_changed.emit()

	# Now Day 2 harvest must succeed
	ok_harvest = wrm.harvest_foraging("resource_jagung_01")
	check(ok_harvest, "Harvest succeeds after space made in stack")
	check(inv.backpack.get_item_count("ingredient_jagung") == 20, "Corn back at 20")

# ==============================================================================
# TEST 3: Foraging Input Fuzzing & Malicious IDs
# ==============================================================================
func test_foraging_fuzzing_and_invalid_nodes(wrm: Node) -> void:
	print("\n--- Test 3: Foraging Input Fuzzing & Invalid Node IDs ---")
	var malicious_ids: Array = [
		"",
		"   ",
		"resource_jagung",
		"resource_jagung_02",
		"resource_temu_kunci",
		"ingredient_jagung",
		"plot_home_01",
		"reserve_home",
		"../secrets.txt",
		"null"
	]

	for node_id in malicious_ids:
		check(not wrm.is_foraging_node_available(node_id), "is_foraging_node_available false for invalid ID: '%s'" % node_id)
		var c: Dictionary = wrm.can_harvest_foraging(node_id)
		check(not c.get("success", true), "can_harvest_foraging rejected for invalid ID: '%s'" % node_id)
		check(c.get("reason", "") == "Sumber daya liar tidak dikenal.", "Correct rejection reason for '%s'" % node_id)
		var h: bool = wrm.harvest_foraging(node_id)
		check(not h, "harvest_foraging returns false for invalid ID: '%s'" % node_id)

# ==============================================================================
# TEST 4: Emergency Reserve Gates & Living Plant Anti-Exploit
# ==============================================================================
func test_emergency_reserve_gates_and_living_plants(wrm: Node, inv: Node, gm: Node) -> void:
	print("\n--- Test 4: Emergency Reserve Gates & Living Plant Anti-Exploit ---")
	wrm.reset_state()
	inv.backpack.clear()
	inv.storage_home.clear()
	gm.reset_to_defaults()

	# Sub-test 4.1: Gate Prerequisite — Starter must be collected first
	inv.starter_claimed = false
	var check_res: Dictionary = wrm.can_claim_emergency_reserve()
	check(not check_res.get("success", true), "Reserve claim rejected when starter_claimed is false")
	check(check_res.get("reason", "") == "Ambil wadah awal dekat alat terlebih dahulu.", "Reason points to starter crate")
	check(not wrm.claim_emergency_reserve(), "claim_emergency_reserve fails when starter not collected")

	# Enable starter
	inv.starter_claimed = true

	# Sub-test 4.2: Seed in backpack rejects
	inv.backpack.add_item("seed_bayam", 1)
	check_res = wrm.can_claim_emergency_reserve()
	check(not check_res.get("success", true), "Rejected when 1 seed in backpack")
	check(str(check_res.get("reason", "")).contains("tas atau peti"), "Mentions bag/chest location")
	check(not wrm.claim_emergency_reserve(), "Claim rejected when seed in backpack")
	inv.backpack.clear()

	# Sub-test 4.3: Seed in storage chest rejects
	inv.storage_home.add_item("seed_bayam", 1)
	check_res = wrm.can_claim_emergency_reserve()
	check(not check_res.get("success", true), "Rejected when 1 seed in storage chest")
	check(not wrm.claim_emergency_reserve(), "Claim rejected when seed in chest")
	inv.storage_home.clear()

	# Sub-test 4.4: Living plants on ANY of the 4 plot spots rejects
	var plot: Dictionary = gm.get_plot("plot_home_01")
	plot["is_hoed"] = true
	plot["has_compost"] = true

	for s_idx in range(1, 5):
		var s_id := "slot_%02d" % s_idx
		# Place living plant in s_id
		plot["spots"][s_id]["is_occupied"] = true
		plot["spots"][s_id]["crop_data"] = {
			"crop_id": "crop_bayam",
			"growth_stage": s_idx - 1,
			"growth_time": 20.0 * s_idx,
			"is_ready_to_harvest": false
		}

		check_res = wrm.can_claim_emergency_reserve()
		check(not check_res.get("success", true), "Reserve rejected when %s has living plant" % s_id)
		check(str(check_res.get("reason", "")).contains("sedang tumbuh"), "Reason explains living plants will yield seeds")
		check(not wrm.claim_emergency_reserve(), "Claim fails when %s occupied" % s_id)

		# Clear spot
		plot["spots"][s_id]["is_occupied"] = false
		plot["spots"][s_id]["crop_data"] = null

	# Sub-test 4.5: Depleted state -> receives 4 seeds
	gm.reset_to_defaults()
	check_res = wrm.can_claim_emergency_reserve()
	check(check_res.get("success", false), "Reserve claim available when 0 seeds and 0 plants")
	check(check_res.get("type", "") == "seed", "Reserve type is seed")
	check(check_res.get("count", 0) == 4, "Delivers exactly 4 seeds")

	var ok_claim: bool = wrm.claim_emergency_reserve()
	check(ok_claim, "Emergency seed claim succeeded")
	check(inv.backpack.get_item_count("seed_bayam") == 4, "Backpack received 4 seeds")

	# Sub-test 4.6: Immediate re-attempt rejected (idempotency)
	check_res = wrm.can_claim_emergency_reserve()
	check(not check_res.get("success", true), "Second claim immediately rejected")
	check(not wrm.claim_emergency_reserve(), "Duplicate claim prevented")
	check(inv.backpack.get_item_count("seed_bayam") == 4, "Seed count remained 4")

# ==============================================================================
# TEST 5: Emergency Reserve Capacity & Priority Chain
# ==============================================================================
func test_emergency_reserve_full_bag_and_priority_chain(wrm: Node, inv: Node, gm: Node) -> void:
	print("\n--- Test 5: Emergency Reserve Capacity & Priority Chain ---")
	wrm.reset_state()
	inv.backpack.clear()
	inv.storage_home.clear()
	gm.reset_to_defaults()
	inv.starter_claimed = true

	# Completely fill backpack with 12x 20 fertilizer
	for i in range(12):
		inv.backpack.slots[i].set_item("fertilizer_basic", 20)
	inv.backpack.contents_changed.emit()

	# Needs seeds, but backpack full
	var check_res: Dictionary = wrm.can_claim_emergency_reserve()
	check(not check_res.get("success", true), "Reserve claim rejected when backpack is 12/12 full")
	check(str(check_res.get("reason", "")).contains("Tas tidak cukup"), "Reason explains full backpack")
	check(not wrm.claim_emergency_reserve(), "Claim rejected atomically on full bag")
	check(inv.backpack.get_item_count("seed_bayam") == 0, "No seeds given into full backpack")

	# Free 1 slot in backpack
	inv.backpack.slots[0].clear()
	inv.backpack.contents_changed.emit()

	# Now seeds can be claimed into the single freed slot
	check(wrm.claim_emergency_reserve(), "Claim succeeds into freed slot")
	check(inv.backpack.get_item_count("seed_bayam") == 4, "Slot 0 now has 4 seeds")

	# Now slot 0 has 4 seeds, slots 1-11 have fertilizer.
	# Next priority: Compost!
	var plot: Dictionary = gm.get_plot("plot_home_01")
	plot["is_hoed"] = true
	plot["has_compost"] = false

	# Backpack has NO empty slots (1 slot seeds, 11 slots fertilizer)
	# Trying to claim compost should fail due to no room!
	check_res = wrm.can_claim_emergency_reserve()
	check(not check_res.get("success", true), "Compost claim rejected when no room in backpack")
	check(not wrm.claim_emergency_reserve(), "Compost claim fails atomically on full bag")

	# Free slot 1
	inv.backpack.slots[1].clear()
	inv.backpack.contents_changed.emit()

	# Now compost claim should succeed
	check_res = wrm.can_claim_emergency_reserve()
	check(check_res.get("success", false), "Compost available after freeing slot")
	check(check_res.get("type", "") == "compost", "Type is compost")
	check(check_res.get("count", 0) == 1, "Delivers 1 compost")
	check(wrm.claim_emergency_reserve(), "Compost claimed successfully")
	check(inv.backpack.get_item_count("soil_compost") == 1, "Backpack has 1 compost")

	# Next priority: Fertilizer
	# Apply compost to plot
	plot["has_compost"] = true
	plot["nutrients"] = 15.0 # Nutrients < 20

	# But player currently has fertilizer in backpack! Slots 2..11 have fertilizer!
	check_res = wrm.can_claim_emergency_reserve()
	check(not check_res.get("success", true), "Fertilizer reserve rejected because player already has fertilizer in backpack")

	# Clear all fertilizer from backpack and chest
	for i in range(2, 12):
		inv.backpack.slots[i].clear()
	inv.backpack.contents_changed.emit()
	inv.storage_home.clear()
	check(inv.get_available_item_count("fertilizer_basic") == 0, "Fertilizer count is now 0")

	# Now fertilizer reserve should be available!
	check_res = wrm.can_claim_emergency_reserve()
	check(check_res.get("success", false), "Fertilizer reserve available when nutrients < 20 and 0 stock")
	check(check_res.get("type", "") == "fertilizer", "Type is fertilizer")
	check(check_res.get("count", 0) == 1, "Delivers 1 fertilizer")
	check(wrm.claim_emergency_reserve(), "Fertilizer claimed successfully")
	check(inv.backpack.get_item_count("fertilizer_basic") == 1, "Backpack received 1 fertilizer")

	# Now all needs met:
	# - Has seeds (4)
	# - Plot is hoed and composted
	# - Has fertilizer (1)
	check_res = wrm.can_claim_emergency_reserve()
	check(not check_res.get("success", true), "All reserve claims rejected once conditions are satisfied")

# ==============================================================================
# TEST 6: Well Water Refill & Hold Controller Anti-Spam
# ==============================================================================
func test_well_water_refill_and_hold_invariants(wrm: Node, gm: Node) -> void:
	print("\n--- Test 6: Well Water Refill & Hold Controller Invariants ---")
	gm.watering_can_water = 10

	# When at 10/10, refill MUST be rejected
	var check_res: Dictionary = wrm.can_refill_water()
	check(not check_res.get("success", true), "Refill rejected when watering can is full (10/10)")
	check(check_res.get("reason", "") == "Kondisi cukup. Air sudah penuh.", "Reason matches CONTENT §11")
	check(not wrm.refill_water(), "refill_water returns false when full")
	check(gm.watering_can_water == 10, "Water remains 10")

	# Set water to 5
	gm.watering_can_water = 5
	check_res = wrm.can_refill_water()
	check(check_res.get("success", false), "Refill allowed when water is 5/10")

	# Test Hold Action Controller
	var controller := HoldActionControllerClass.new()
	var completions: Array[int] = [0]
	var cancellations: Array[int] = [0]

	controller.hold_completed.connect(func(act_id):
		if act_id == "refill":
			completions[0] += 1
			wrm.refill_water()
	)
	controller.hold_cancelled.connect(func(_act_id):
		cancellations[0] += 1
	)

	# Start hold, tick to 1.95s, release -> cancel
	controller.start("refill", "water_home", 2.0, &"interact")
	check(controller.is_active(), "Controller active during hold")
	controller.tick(1.95, true, true)
	check(completions[0] == 0, "No completion before 2.0s")
	check(gm.watering_can_water == 5, "Water level unmodified during hold")

	# Release at 1.95s
	controller.tick(0.016, false, true)
	check(cancellations[0] == 1, "Cancelled emitted on button release before 2.0s")
	check(not controller.is_active(), "Controller reset to IDLE after cancel")
	check(gm.watering_can_water == 5, "Water level unmodified after cancel")

	# Start hold, tick 2.0s -> commit once
	controller.start("refill", "water_home", 2.0, &"interact")
	controller.tick(2.0, true, true)
	check(completions[0] == 1, "Completed emitted exactly once at 2.0s")
	check(gm.watering_can_water == 10, "Water filled to 10/10")
	check(controller.state == controller.State.MUST_RELEASE, "Controller entered MUST_RELEASE state")

	# Keep holding for 50 more ticks -> MUST NOT re-trigger
	for i in range(50):
		controller.tick(0.1, true, true)
	check(completions[0] == 1, "Zero duplicate completions while button held in MUST_RELEASE")
	check(gm.watering_can_water == 10, "Water level capped at 10")

	# Release button
	controller.tick(0.016, false, true)
	check(controller.state == controller.State.IDLE, "Controller returns to IDLE upon button release")

	# Target invalidation mid-hold: start hold, then target becomes invalid
	gm.watering_can_water = 0
	controller.start("refill", "water_home", 2.0, &"interact")
	controller.tick(0.5, true, false) # is_target_valid = false
	check(cancellations[0] == 2, "Cancellation emitted immediately when target becomes invalid")
	check(gm.watering_can_water == 0, "Water remains 0 after invalid target cancel")

# ==============================================================================
# TEST 7: Multi-Day Sleep & Agricultural Zero-Decay Absolute Invariant
# ==============================================================================
func test_agricultural_zero_decay_multi_day_sleep(wrm: Node, gm: Node) -> void:
	print("\n--- Test 7: Multi-Day Sleep & Agricultural Zero-Decay Invariant ---")
	wrm.reset_state()
	gm.reset_to_defaults()

	var plot: Dictionary = gm.get_plot("plot_home_01")
	plot["is_hoed"] = true
	plot["has_compost"] = true
	plot["moisture"] = 35.5
	plot["nutrients"] = 42.2

	# Populate all 4 spots with different stages
	plot["spots"]["slot_01"]["is_occupied"] = true
	plot["spots"]["slot_01"]["crop_data"] = {
		"crop_id": "crop_bayam",
		"growth_stage": 0,
		"growth_time": 15.0,
		"is_ready_to_harvest": false
	}
	plot["spots"]["slot_02"]["is_occupied"] = true
	plot["spots"]["slot_02"]["crop_data"] = {
		"crop_id": "crop_bayam",
		"growth_stage": 1,
		"growth_time": 45.0,
		"is_ready_to_harvest": false
	}
	plot["spots"]["slot_03"]["is_occupied"] = true
	plot["spots"]["slot_03"]["crop_data"] = {
		"crop_id": "crop_bayam",
		"growth_stage": 2,
		"growth_time": 110.0,
		"is_ready_to_harvest": false
	}
	plot["spots"]["slot_04"]["is_occupied"] = true
	plot["spots"]["slot_04"]["crop_data"] = {
		"crop_id": "crop_bayam",
		"growth_stage": 3,
		"growth_time": 180.0,
		"is_ready_to_harvest": true
	}

	# Sleep 7 times in a row (Days 1 -> 8)
	for d in range(1, 8):
		check(wrm.sleep_and_advance_day(), "Sleep succeeded on Day %d" % d)
	check(wrm.current_day == 8, "Current day is now 8")
	check(wrm.day_active_time == 0.0, "day_active_time reset to 0.0")

	# CRITICAL ORACLE: Verify plot status and spots are 100% UNCHANGED
	var plot_after: Dictionary = gm.get_plot("plot_home_01")
	check(abs(float(plot_after["moisture"]) - 35.5) < 0.001, "Moisture perfectly preserved at 35.5 (NO decay/evaporation!)")
	check(abs(float(plot_after["nutrients"]) - 42.2) < 0.001, "Nutrients perfectly preserved at 42.2")

	var s1 = plot_after["spots"]["slot_01"]["crop_data"]
	check(int(s1["growth_stage"]) == 0 and abs(float(s1["growth_time"]) - 15.0) < 0.001, "Spot 1 stage/time preserved")

	var s2 = plot_after["spots"]["slot_02"]["crop_data"]
	check(int(s2["growth_stage"]) == 1 and abs(float(s2["growth_time"]) - 45.0) < 0.001, "Spot 2 stage/time preserved")

	var s3 = plot_after["spots"]["slot_03"]["crop_data"]
	check(int(s3["growth_stage"]) == 2 and abs(float(s3["growth_time"]) - 110.0) < 0.001, "Spot 3 stage/time preserved")

	var s4 = plot_after["spots"]["slot_04"]["crop_data"]
	check(int(s4["growth_stage"]) == 3 and bool(s4["is_ready_to_harvest"]), "Spot 4 ready-to-harvest preserved")

# ==============================================================================
# TEST 8: Sleep Kitchen Active Lockout
# ==============================================================================
func test_sleep_kitchen_active_lockout(wrm: Node) -> void:
	print("\n--- Test 8: Sleep Kitchen Active Lockout ---")
	wrm.reset_state()

	var mock_km := MockKitchen.new()
	wrm.set_kitchen_manager(mock_km)

	# Case 1: is_cooking_active = true
	mock_km.cooking = true
	mock_km.job = false
	var check_res: Dictionary = wrm.can_sleep()
	check(not check_res.get("success", true), "Sleep rejected when cooking is active")
	check(not wrm.sleep_and_advance_day(), "sleep_and_advance_day returns false when cooking active")
	check(wrm.current_day == 1, "Day remains 1")

	# Case 2: is_job_active = true
	mock_km.cooking = false
	mock_km.job = true
	check_res = wrm.can_sleep()
	check(not check_res.get("success", true), "Sleep rejected when kitchen job is active")
	check(not wrm.sleep_and_advance_day(), "sleep_and_advance_day returns false when job active")
	check(wrm.current_day == 1, "Day remains 1")

	# Case 3: Both inactive
	mock_km.cooking = false
	mock_km.job = false
	check_res = wrm.can_sleep()
	check(check_res.get("success", false), "Sleep allowed when kitchen is idle")
	check(wrm.sleep_and_advance_day(), "sleep_and_advance_day succeeds when kitchen idle")
	check(wrm.current_day == 2, "Day advanced to 2")

	wrm.set_kitchen_manager(null)
	mock_km.free()

# ==============================================================================
# TEST 9: Save Snapshot Corruption & High-Fidelity Roundtrip
# ==============================================================================
func test_save_snapshot_corruption_and_fidelity(wrm: Node) -> void:
	print("\n--- Test 9: Save Snapshot Corruption & High-Fidelity Roundtrip ---")
	wrm.reset_state()

	# Corrupted snapshots
	check(not wrm.load_save_snapshot({}), "Empty dictionary snapshot rejected")
	check(not wrm.load_save_snapshot({"version": 2}), "Unsupported version 2 rejected")
	check(not wrm.load_save_snapshot({"version": 0}), "Version 0 rejected")
	check(not wrm.load_save_snapshot({"version": -1}), "Negative version rejected")

	# High-fidelity state snapshot
	wrm.current_day = 99
	wrm.day_active_time = 654.321
	wrm.last_harvested_day["resource_jagung_01"] = 99
	wrm.last_harvested_day["resource_temu_kunci_01"] = 98

	var snap: Dictionary = wrm.get_save_snapshot()
	check(int(snap.get("version", 0)) == 1, "Snapshot envelope version is 1")
	check(int(snap.get("current_day", 0)) == 99, "Snapshot current_day is 99")
	check(abs(float(snap.get("day_active_time", 0.0)) - 654.321) < 0.001, "Snapshot day_active_time is 654.321")

	# Reset state
	wrm.reset_state()
	check(wrm.current_day == 1, "Reset day is 1")
	check(wrm.day_active_time == 0.0, "Reset time is 0.0")

	# Load back
	check(wrm.load_save_snapshot(snap), "Valid snapshot loaded successfully")
	check(wrm.current_day == 99, "Restored day is 99")
	check(abs(wrm.day_active_time - 654.321) < 0.001, "Restored time is 654.321")
	check(not wrm.is_foraging_node_available("resource_jagung_01"), "Corn marked depleted on Day 99")
	check(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Temu kunci marked available on Day 99 (harvested Day 98 < 99)")

# ==============================================================================
# TEST 10: Simulation Pause Time-Dilation Gate
# ==============================================================================
func test_simulation_pause_time_dilation_gate(wrm: Node) -> void:
	print("\n--- Test 10: Simulation Pause Time-Dilation Gate ---")
	wrm.reset_state()
	wrm.current_day = 1
	wrm.day_active_time = 100.0

	var mock_im := MockInputManager.new()
	wrm.set_input_manager(mock_im)

	# When paused: time must NOT advance
	mock_im.paused = true
	wrm._process(50.0)
	check(abs(wrm.day_active_time - 100.0) < 0.001, "Time did NOT advance while simulation paused")
	check(wrm.current_day == 1, "Day did not advance while paused")

	# When unpaused: time advances normally
	mock_im.paused = false
	wrm._process(50.0)
	check(abs(wrm.day_active_time - 150.0) < 0.001, "Time advanced by 50.0s when unpaused")

	# Advance across 720.0s threshold
	wrm._process(570.0) # 150 + 570 = 720.0
	check(wrm.current_day == 2, "Day advanced to 2 when threshold crossed")
	check(wrm.day_active_time == 0.0, "day_active_time reset to 0.0 upon day advance")

	wrm.set_input_manager(null)
	mock_im.free()
