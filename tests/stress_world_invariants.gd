extends SceneTree

## Adversarial Empirical Challenge Suite for Milestone WORLD-001
## Empirically challenges and stress-tests:
## 1. 720.0s Day Cycle Boundary & Modal Pause Immunity (BOOK, STORAGE, DIALOGUE, PAUSE)
## 2. Bed Sleep Recovery & Multi-Sleep Loop
## 3. Agricultural Non-Decay Invariance Under Sleep & Time Progression (Zero Plot Loss)
## 4. Cooking Safety During Sleep (Prohibition While Cooking Active)
## 5. Foraging Nodes Daily Quota, Independence, and Atomic Full-Bag Rejection
## 6. Emergency Contextual Reserve Gating, Priority Hierarchy, and Anti-Exploit
## 7. Water Station Capacity Invariants & Boundary Guards
## 8. SAVE-001 Snapshot Serialization Round-Trip & Fuzzing/Corruption Defense

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const GardenManagerClass = preload("res://scripts/gardening/garden_manager.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")
const WorldResourceManagerClass = preload("res://scripts/world/world_resource_manager.gd")

# Mock Kitchen Manager with configurable states
class MockKitchen extends Node:
	var cooking_active: bool = false
	var job_active: bool = false
	var is_active: Variant = false

	func is_cooking_active() -> bool:
		return cooking_active

	func is_job_active() -> bool:
		return job_active

var _all_passed: bool = true

func _init() -> void:
	print("==================================================")
	print("[CHALLENGER_WORLD_001] Empirical Adversarial Verification")
	print("Target: Milestone WORLD-001 (720s Cycle, Pause, Bed Sleep, Non-Decay, Cooking Safety)")
	print("==================================================")

	Assertions.reset()

	run_all_challenges()
	finish_and_quit()

func finish_and_quit() -> void:
	print("==================================================")
	print("[CHALLENGER_WORLD_001] SUMMARY:")
	print("  Assertions Passed: %d" % Assertions.current_suite_passed)
	print("  Assertions Failed: %d" % Assertions.current_suite_failed)

	if _all_passed and Assertions.current_suite_failed == 0:
		print("  FINAL VERDICT: APPROVE")
		print("  All WORLD-001 empirical invariants survived adversarial challenge testing.")
		print("==================================================")
		quit(0)
	else:
		printerr("  FINAL VERDICT: REQUEST_CHANGES")
		printerr("  World-001 invariant failures encountered:")
		for msg in Assertions.failure_messages:
			printerr("    - ", msg)
		print("==================================================")
		quit(1)

func run_all_challenges() -> void:
	# Challenge 1: Day Cycle 720.0s Boundary & Modal Pause Immunity
	if not challenge_01_day_cycle_and_modal_pause():
		_all_passed = false

	# Challenge 2: Sleep & Bed Rest Consecutive Loop Stress
	if not challenge_02_bed_sleep_consecutive_loop():
		_all_passed = false

	# Challenge 3: Agricultural Non-Decay Invariance Under Sleep & Time Skips
	if not challenge_03_agricultural_non_decay_invariance():
		_all_passed = false

	# Challenge 4: Cooking Safety During Sleep (Prohibition While Kitchen Active)
	if not challenge_04_cooking_safety_during_sleep():
		_all_passed = false

	# Challenge 5: Foraging Nodes Quotas, Independence & Atomic Capacity
	if not challenge_05_foraging_quotas_and_atomic_capacity():
		_all_passed = false

	# Challenge 6: Emergency Contextual Reserve Hierarchy & Gating
	if not challenge_06_emergency_reserve_hierarchy_and_gating():
		_all_passed = false

	# Challenge 7: Water Station Capacity & Boundary Guards
	if not challenge_07_water_station_boundary_guards():
		_all_passed = false

	# Challenge 8: Persistence Roundtrip & Fuzzing/Corruption Resistance
	if not challenge_08_persistence_roundtrip_and_fuzzing():
		_all_passed = false

# ==============================================================================
# Helper Factory Methods
# ==============================================================================

func _setup_isolated_world() -> Dictionary:
	var inv := InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.storage_home.clear()
	inv.kitchen_refund.clear()
	inv.starter_claimed = true

	var gm := GardenManagerClass.new()
	gm.set_inventory_manager(inv)
	gm._ready()

	var im := InputManagerClass.new()
	im._ready()

	var wrm := WorldResourceManagerClass.new()
	wrm.set_inventory_manager(inv)
	wrm.set_garden_manager(gm)
	wrm.set_input_manager(im)
	wrm._ready()

	return {
		"inv": inv,
		"gm": gm,
		"im": im,
		"wrm": wrm
	}

func _cleanup_world(env: Dictionary) -> void:
	if env.has("wrm") and is_instance_valid(env["wrm"]):
		env["wrm"].free()
	if env.has("gm") and is_instance_valid(env["gm"]):
		env["gm"].free()
	if env.has("im") and is_instance_valid(env["im"]):
		env["im"].free()
	if env.has("inv") and is_instance_valid(env["inv"]):
		env["inv"].free()

# ==============================================================================
# CHALLENGE 1: Day Cycle 720.0s Boundary & Modal Pause Immunity
# ==============================================================================

func challenge_01_day_cycle_and_modal_pause() -> bool:
	print("  [CHALLENGE 1] Day Cycle 720.0s Boundary & Modal Pause Immunity...")
	var initial_failures: int = Assertions.current_suite_failed
	var env := _setup_isolated_world()
	var wrm = env["wrm"]
	var im = env["im"]

	# 1.1 Micro-tick accumulation
	wrm.day_active_time = 0.0
	wrm.current_day = 1
	var ticked_days: Array[int] = []
	var ticked_times: Array[float] = []
	wrm.calendar_ticked.connect(func(d: int, t: float):
		ticked_days.append(d)
		ticked_times.append(t)
	)

	for _i in range(60):
		wrm._process(1.0 / 60.0)

	Assertions.assert_approx_equal(wrm.day_active_time, 1.0, 0.01, "60 frames of 1/60s accumulates ~1.0s")
	Assertions.assert_equal(wrm.current_day, 1, "Day remains 1")
	Assertions.assert_equal(ticked_days.size(), 60, "calendar_ticked emitted 60 times")

	# 1.2 Boundary crossing at 720.0s
	wrm.day_active_time = 719.95
	var day_advanced_called: Array = [false]
	var new_day_val: Array = [0]
	wrm.day_advanced.connect(func(d: int):
		day_advanced_called[0] = true
		new_day_val[0] = d
	)

	# Advance by 0.04s -> 719.99s (under threshold)
	wrm._process(0.04)
	Assertions.assert_equal(wrm.current_day, 1, "At 719.99s, day is still 1")
	Assertions.assert_false(day_advanced_called[0], "day_advanced not called before 720s")

	# Advance by 0.02s -> 720.01s (crosses threshold)
	wrm._process(0.02)
	Assertions.assert_equal(wrm.current_day, 2, "Crossed 720s: day advanced to 2")
	Assertions.assert_equal(wrm.day_active_time, 0.0, "Active time reset to 0.0 on new day")
	Assertions.assert_true(day_advanced_called[0], "day_advanced emitted on threshold cross")
	Assertions.assert_equal(new_day_val[0], 2, "day_advanced reported day 2")

	# 1.3 Modal Pause Immunity across all contexts
	var modal_contexts := [
		InputManagerClass.ContextMode.BOOK,
		InputManagerClass.ContextMode.STORAGE,
		InputManagerClass.ContextMode.DIALOGUE,
		InputManagerClass.ContextMode.PAUSE
	]

	for ctx in modal_contexts:
		im.push_context(ctx)
		Assertions.assert_true(im.is_simulation_paused(), "Context %s reports simulation paused" % ctx)

		var time_before: float = wrm.day_active_time
		var day_before: int = wrm.current_day

		# Attempt 100 process ticks with delta=1.0s while paused
		for _j in range(100):
			wrm._process(1.0)

		Assertions.assert_equal(wrm.day_active_time, time_before, "Time frozen during modal context %s" % ctx)
		Assertions.assert_equal(wrm.current_day, day_before, "Day unchanged during modal context %s" % ctx)

		# Pop context back
		im.pop_context()

	# Verify time resumes after modal pop
	Assertions.assert_true(im.is_world_context(), "Returned to WORLD context")
	Assertions.assert_false(im.is_simulation_paused(), "Simulation unpaused in WORLD")
	wrm._process(5.5)
	Assertions.assert_approx_equal(wrm.day_active_time, 5.5, 0.001, "Time resumes ticking in WORLD context")

	_cleanup_world(env)
	var ok := (Assertions.current_suite_failed == initial_failures)
	print("  [CHALLENGE 1] Result: %s" % ("PASS" if ok else "FAIL"))
	return ok

# ==============================================================================
# CHALLENGE 2: Sleep & Bed Rest Consecutive Loop Stress
# ==============================================================================

func challenge_02_bed_sleep_consecutive_loop() -> bool:
	print("  [CHALLENGE 2] Bed Sleep Consecutive Loop Stress (100 Days)...")
	var initial_failures: int = Assertions.current_suite_failed
	var env := _setup_isolated_world()
	var wrm = env["wrm"]

	wrm.current_day = 1
	wrm.day_active_time = 500.0

	var rest_completed_events: Array[int] = []
	wrm.rest_completed.connect(func(d: int):
		rest_completed_events.append(d)
	)

	# Perform 100 consecutive sleeps
	for expected_day in range(2, 102):
		var rested: bool = wrm.sleep_and_advance_day()
		Assertions.assert_true(rested, "Sleep %d succeeded" % expected_day)
		Assertions.assert_equal(wrm.current_day, expected_day, "current_day matches %d" % expected_day)
		Assertions.assert_equal(wrm.day_active_time, 0.0, "day_active_time reset to 0.0 at day %d" % expected_day)

	Assertions.assert_equal(rest_completed_events.size(), 100, "rest_completed fired exactly 100 times")
	Assertions.assert_equal(rest_completed_events[0], 2, "First rest completed at Day 2")
	Assertions.assert_equal(rest_completed_events[99], 101, "Last rest completed at Day 101")

	_cleanup_world(env)
	var ok := (Assertions.current_suite_failed == initial_failures)
	print("  [CHALLENGE 2] Result: %s" % ("PASS" if ok else "FAIL"))
	return ok

# ==============================================================================
# CHALLENGE 3: Agricultural Non-Decay Invariance Under Sleep & Time Skips
# ==============================================================================

func challenge_03_agricultural_non_decay_invariance() -> bool:
	print("  [CHALLENGE 3] Agricultural Non-Decay Invariance Under Sleep (Zero Plot Loss)...")
	var initial_failures: int = Assertions.current_suite_failed
	var env := _setup_isolated_world()
	var wrm = env["wrm"]
	var gm = env["gm"]

	# Setup complex plot with all 4 quadrants at different stages
	var plot: Dictionary = gm.get_plot("plot_home_01")
	plot["is_hoed"] = true
	plot["has_compost"] = true
	plot["moisture"] = 62.45
	plot["nutrients"] = 88.35

	var spots: Dictionary = plot["spots"]
	# Slot 1: Seed stage (18s)
	spots["slot_01"]["is_occupied"] = true
	spots["slot_01"]["crop_data"] = {
		"crop_id": "crop_bayam",
		"growth_stage": 0,
		"growth_time": 18.0,
		"is_ready_to_harvest": false,
		"is_stalled": false,
		"stall_reason": ""
	}
	# Slot 2: Sprout stage (55s)
	spots["slot_02"]["is_occupied"] = true
	spots["slot_02"]["crop_data"] = {
		"crop_id": "crop_bayam",
		"growth_stage": 1,
		"growth_time": 55.0,
		"is_ready_to_harvest": false,
		"is_stalled": false,
		"stall_reason": ""
	}
	# Slot 3: Growing stage (130s)
	spots["slot_03"]["is_occupied"] = true
	spots["slot_03"]["crop_data"] = {
		"crop_id": "crop_bayam",
		"growth_stage": 2,
		"growth_time": 130.0,
		"is_ready_to_harvest": false,
		"is_stalled": false,
		"stall_reason": ""
	}
	# Slot 4: Harvestable stage (180s)
	spots["slot_04"]["is_occupied"] = true
	spots["slot_04"]["crop_data"] = {
		"crop_id": "crop_bayam",
		"growth_stage": 3,
		"growth_time": 180.0,
		"is_ready_to_harvest": true,
		"is_stalled": false,
		"stall_reason": ""
	}

	# Execute 50 consecutive bed rests (simulating 50 in-game days of sleep)
	for _i in range(50):
		var rested: bool = wrm.sleep_and_advance_day()
		Assertions.assert_true(rested, "Sleep step succeeded")

	# VERIFY INVARIANTS: Plot and all 4 spots MUST HAVE ZERO DECAY
	var p_after: Dictionary = gm.get_plot("plot_home_01")
	Assertions.assert_approx_equal(float(p_after["moisture"]), 62.45, 0.0001, "Moisture 100% preserved (NO EVAPORATION during sleep)")
	Assertions.assert_approx_equal(float(p_after["nutrients"]), 88.35, 0.0001, "Nutrients 100% preserved (NO NUTRIENT LOSS during sleep)")
	Assertions.assert_true(bool(p_after["is_hoed"]), "is_hoed preserved")
	Assertions.assert_true(bool(p_after["has_compost"]), "has_compost preserved")

	var s1 = p_after["spots"]["slot_01"]["crop_data"]
	Assertions.assert_equal(int(s1["growth_stage"]), 0, "Slot 1 stage unchanged (0)")
	Assertions.assert_approx_equal(float(s1["growth_time"]), 18.0, 0.0001, "Slot 1 growth time unchanged (18.0s)")

	var s2 = p_after["spots"]["slot_02"]["crop_data"]
	Assertions.assert_equal(int(s2["growth_stage"]), 1, "Slot 2 stage unchanged (1)")
	Assertions.assert_approx_equal(float(s2["growth_time"]), 55.0, 0.0001, "Slot 2 growth time unchanged (55.0s)")

	var s3 = p_after["spots"]["slot_03"]["crop_data"]
	Assertions.assert_equal(int(s3["growth_stage"]), 2, "Slot 3 stage unchanged (2)")
	Assertions.assert_approx_equal(float(s3["growth_time"]), 130.0, 0.0001, "Slot 3 growth time unchanged (130.0s)")

	var s4 = p_after["spots"]["slot_04"]["crop_data"]
	Assertions.assert_equal(int(s4["growth_stage"]), 3, "Slot 4 stage unchanged (3)")
	Assertions.assert_approx_equal(float(s4["growth_time"]), 180.0, 0.0001, "Slot 4 growth time unchanged (180.0s)")
	Assertions.assert_true(bool(s4["is_ready_to_harvest"]), "Slot 4 remains harvestable (NOT ROTTED)")

	_cleanup_world(env)
	var ok := (Assertions.current_suite_failed == initial_failures)
	print("  [CHALLENGE 3] Result: %s" % ("PASS" if ok else "FAIL"))
	return ok

# ==============================================================================
# CHALLENGE 4: Cooking Safety During Sleep (Prohibition While Kitchen Active)
# ==============================================================================

func challenge_04_cooking_safety_during_sleep() -> bool:
	print("  [CHALLENGE 4] Cooking Safety During Sleep (Sleep Prohibition)...")
	var initial_failures: int = Assertions.current_suite_failed
	var env := _setup_isolated_world()
	var wrm = env["wrm"]

	var mock_km := MockKitchen.new()
	wrm.set_kitchen_manager(mock_km)

	# 4.1 Rejection when is_cooking_active() == true
	mock_km.cooking_active = true
	mock_km.job_active = false
	mock_km.is_active = false

	var check1: Dictionary = wrm.can_sleep()
	Assertions.assert_false(check1.get("success", true), "Sleep prohibited when cooking_active is true")
	Assertions.assert_true(str(check1.get("reason", "")).contains("memasak"), "Reason cites cooking process")

	var rested1: bool = wrm.sleep_and_advance_day()
	Assertions.assert_false(rested1, "sleep_and_advance_day returns false")
	Assertions.assert_equal(wrm.current_day, 1, "Day remains 1 on rejected sleep")

	# 4.2 Rejection when is_job_active() == true
	mock_km.cooking_active = false
	mock_km.job_active = true
	mock_km.is_active = false

	var check2: Dictionary = wrm.can_sleep()
	Assertions.assert_false(check2.get("success", true), "Sleep prohibited when job_active is true")
	var rested2: bool = wrm.sleep_and_advance_day()
	Assertions.assert_false(rested2, "sleep_and_advance_day rejected")
	Assertions.assert_equal(wrm.current_day, 1, "Day remains 1")

	# 4.3 Rejection when is_active == true
	mock_km.cooking_active = false
	mock_km.job_active = false
	mock_km.is_active = true

	var check3: Dictionary = wrm.can_sleep()
	Assertions.assert_false(check3.get("success", true), "Sleep prohibited when is_active is true")
	var rested3: bool = wrm.sleep_and_advance_day()
	Assertions.assert_false(rested3, "sleep_and_advance_day rejected")
	Assertions.assert_equal(wrm.current_day, 1, "Day remains 1")

	# 4.4 Allowed when kitchen is idle/null
	mock_km.cooking_active = false
	mock_km.job_active = false
	mock_km.is_active = false

	var check4: Dictionary = wrm.can_sleep()
	Assertions.assert_true(check4.get("success", false), "Sleep allowed when kitchen idle")
	var rested4: bool = wrm.sleep_and_advance_day()
	Assertions.assert_true(rested4, "sleep_and_advance_day succeeds")
	Assertions.assert_equal(wrm.current_day, 2, "Day advances to 2")

	# 4.5 Robustness against null is_active value
	mock_km.is_active = null
	var check5: Dictionary = wrm.can_sleep()
	Assertions.assert_true(check5.get("success", false), "Safe against null is_active value")

	wrm.set_kitchen_manager(null)
	mock_km.free()
	_cleanup_world(env)
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	print("  [CHALLENGE 4] Result: %s" % ("PASS" if ok else "FAIL"))
	return ok

# ==============================================================================
# CHALLENGE 5: Foraging Nodes Quotas, Independence & Atomic Capacity
# ==============================================================================

func challenge_05_foraging_quotas_and_atomic_capacity() -> bool:
	print("  [CHALLENGE 5] Foraging Nodes Quotas, Independence & Atomic Capacity...")
	var initial_failures: int = Assertions.current_suite_failed
	var env: Dictionary = _setup_isolated_world()
	var wrm = env["wrm"]
	var inv = env["inv"]

	# 5.1 Day 1: Harvest both nodes
	Assertions.assert_true(wrm.is_foraging_node_available("resource_jagung_01"), "Corn available Day 1")
	Assertions.assert_true(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Temu available Day 1")

	var h_j1: bool = wrm.harvest_foraging("resource_jagung_01")
	Assertions.assert_true(h_j1, "Corn harvest Day 1 succeeded")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 1, "Backpack has 1 corn")

	# Node quota depletion
	Assertions.assert_false(wrm.is_foraging_node_available("resource_jagung_01"), "Corn depleted after harvest")
	var h_j1_repeat: bool = wrm.harvest_foraging("resource_jagung_01")
	Assertions.assert_false(h_j1_repeat, "Repeat corn harvest Day 1 rejected")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 1, "Corn count still 1")

	# Temu Kunci independence
	Assertions.assert_true(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Temu Kunci still available independently")
	var h_t1: bool = wrm.harvest_foraging("resource_temu_kunci_01")
	Assertions.assert_true(h_t1, "Temu Kunci harvest succeeded")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 1, "Backpack has 1 temu kunci")
	Assertions.assert_false(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Temu Kunci depleted")

	# 5.2 Multi-day skip: sleep to Day 5 without harvesting on Days 2, 3, 4
	for _d in range(4):
		wrm.sleep_and_advance_day()
	Assertions.assert_equal(wrm.current_day, 5, "Advanced to Day 5")
	Assertions.assert_true(wrm.is_foraging_node_available("resource_jagung_01"), "Corn available on Day 5")
	Assertions.assert_true(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Temu available on Day 5")

	# Harvest Day 5 yields EXACTLY 1 item (no unharvested accumulation)
	wrm.harvest_foraging("resource_jagung_01")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 2, "Backpack has exactly 2 corn total (1 from Day 1 + 1 from Day 5)")

	# 5.3 Full bag atomic rejection & quota preservation
	inv.backpack.clear()
	# Fill all 12 slots with 20 bayam each
	for s_idx in range(12):
		inv.backpack.slots[s_idx].set_item("crop_bayam", 20)
	Assertions.assert_true(inv.backpack.is_full(), "Backpack is 100% full")
	Assertions.assert_false(inv.backpack.can_add("ingredient_temu_kunci", 1), "Cannot add temu kunci")

	# Attempt harvest with full bag
	var can_h: Dictionary = wrm.can_harvest_foraging("resource_temu_kunci_01")
	Assertions.assert_false(can_h.get("success", true), "Harvest rejected when bag is full")
	Assertions.assert_true(str(can_h.get("reason", "")).contains("Tas tidak cukup"), "Reason specifies full bag")

	var h_full: bool = wrm.harvest_foraging("resource_temu_kunci_01")
	Assertions.assert_false(h_full, "harvest_foraging returned false")

	# Crucial: daily quota MUST NOT be consumed on rejection
	Assertions.assert_true(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Node quota preserved on full bag rejection")

	# Free 1 slot and harvest
	inv.backpack.slots[0].clear()
	var h_free: bool = wrm.harvest_foraging("resource_temu_kunci_01")
	Assertions.assert_true(h_free, "Harvest succeeds after freeing slot")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 1, "Temu kunci added to freed slot")
	Assertions.assert_false(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Node depleted after successful harvest")

	_cleanup_world(env)
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	print("  [CHALLENGE 5] Result: %s" % ("PASS" if ok else "FAIL"))
	return ok

# ==============================================================================
# CHALLENGE 6: Emergency Contextual Reserve Hierarchy & Gating
# ==============================================================================

func challenge_06_emergency_reserve_hierarchy_and_gating() -> bool:
	print("  [CHALLENGE 6] Emergency Contextual Reserve Hierarchy & Gating...")
	var initial_failures: int = Assertions.current_suite_failed
	var env: Dictionary = _setup_isolated_world()
	var wrm = env["wrm"]
	var inv = env["inv"]
	var gm = env["gm"]

	# 6.1 Gate Prerequisite: Starter container not claimed
	inv.starter_claimed = false
	var check_gate: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_false(check_gate.get("success", true), "Reserve rejected before starter container claimed")
	Assertions.assert_true(str(check_gate.get("reason", "")).contains("wadah awal"), "Reason cites starter container")

	# Claim starter
	inv.starter_claimed = true

	# 6.2 Seeds in storage chest prevents emergency seed claim
	inv.backpack.clear()
	inv.storage_home.clear()
	inv.storage_home.add_item("seed_bayam", 2)
	var check_storage: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_false(check_storage.get("success", true), "Reserve rejected when seeds exist in storage chest")
	Assertions.assert_true(str(check_storage.get("reason", "")).contains("peti rumah"), "Reason cites storage chest")

	# 6.3 Living plants on plot prevents emergency seed claim
	inv.storage_home.clear()
	var plot: Dictionary = gm.get_plot("plot_home_01")
	plot["spots"]["slot_03"]["is_occupied"] = true
	plot["spots"]["slot_03"]["crop_data"] = {
		"crop_id": "crop_bayam",
		"growth_stage": 1,
		"growth_time": 40.0,
		"is_ready_to_harvest": false
	}
	var check_living: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_false(check_living.get("success", true), "Reserve rejected when living plants are growing")
	Assertions.assert_true(str(check_living.get("reason", "")).contains("sedang tumbuh"), "Reason cites growing plants")

	# 6.4 Total Seed Depletion -> 4 Seeds Emergency Delivery
	plot["spots"]["slot_03"]["is_occupied"] = false
	plot["spots"]["slot_03"]["crop_data"] = null
	var check_deliver: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_true(check_deliver.get("success", false), "Emergency reserve eligible for seeds")
	Assertions.assert_equal(str(check_deliver.get("type", "")), "seed", "Reserve type is seed")
	Assertions.assert_equal(int(check_deliver.get("count", 0)), 4, "Delivers 4 seeds")

	var claimed: bool = wrm.claim_emergency_reserve()
	Assertions.assert_true(claimed, "Claiming emergency seeds succeeded")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "Backpack received 4 seeds")

	# Idempotency: second claim immediate rejection
	var check_repeat: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_false(check_repeat.get("success", true), "Immediate repeat claim rejected (stock restored)")

	# 6.5 Emergency Compost Delivery
	inv.backpack.clear()
	plot["is_hoed"] = true
	plot["has_compost"] = false
	# Ensure no compost anywhere
	Assertions.assert_equal(inv.get_available_item_count("soil_compost"), 0, "0 compost available")
	# Add 1 seed so seed check doesn't trigger
	inv.backpack.add_item("seed_bayam", 1)

	var check_compost: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_true(check_compost.get("success", false), "Eligible for compost reserve")
	Assertions.assert_equal(str(check_compost.get("type", "")), "compost", "Type is compost")
	Assertions.assert_equal(int(check_compost.get("count", 0)), 1, "Delivers 1 compost")

	var claimed_c: bool = wrm.claim_emergency_reserve()
	Assertions.assert_true(claimed_c, "Claimed emergency compost")
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 1, "Backpack has 1 compost")

	# 6.6 Emergency Fertilizer Delivery
	inv.backpack.clear()
	inv.backpack.add_item("seed_bayam", 1)
	plot["has_compost"] = true
	plot["nutrients"] = 10.0 # < 20.0
	Assertions.assert_equal(inv.get_available_item_count("fertilizer_basic"), 0, "0 fertilizer available")

	var check_fert: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_true(check_fert.get("success", false), "Eligible for fertilizer reserve")
	Assertions.assert_equal(str(check_fert.get("type", "")), "fertilizer", "Type is fertilizer")
	Assertions.assert_equal(int(check_fert.get("count", 0)), 1, "Delivers 1 fertilizer")

	var claimed_f: bool = wrm.claim_emergency_reserve()
	Assertions.assert_true(claimed_f, "Claimed emergency fertilizer")
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 1, "Backpack has 1 fertilizer")

	# 6.7 Full Bag Atomic Defense (Preserves Reserve Entitlement)
	inv.backpack.clear()
	inv.storage_home.clear()
	plot["spots"]["slot_03"]["is_occupied"] = false
	plot["spots"]["slot_03"]["crop_data"] = null
	# Fill all 12 slots with 20 bayam each
	for s_idx in range(12):
		inv.backpack.slots[s_idx].set_item("crop_bayam", 20)
	Assertions.assert_true(inv.backpack.is_full(), "Backpack full")
	var check_full_bag: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_false(check_full_bag.get("success", true), "Reserve rejected when bag is full")
	Assertions.assert_true(str(check_full_bag.get("reason", "")).contains("Tas tidak cukup"), "Reason specifies full bag")
	var claimed_full: bool = wrm.claim_emergency_reserve()
	Assertions.assert_false(claimed_full, "claim_emergency_reserve returns false when bag full")
	# Free 1 slot and verify entitlement still preserved and delivers
	inv.backpack.slots[0].clear()
	var check_freed: Dictionary = wrm.can_claim_emergency_reserve()
	Assertions.assert_true(check_freed.get("success", false), "Reserve claim succeeds after freeing bag space")
	var claimed_freed: bool = wrm.claim_emergency_reserve()
	Assertions.assert_true(claimed_freed, "Emergency seeds delivered into freed slot")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "Backpack has 4 seeds")

	_cleanup_world(env)
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	print("  [CHALLENGE 6] Result: %s" % ("PASS" if ok else "FAIL"))
	return ok

# ==============================================================================
# CHALLENGE 7: Water Station Capacity & Boundary Guards
# ==============================================================================

func challenge_07_water_station_boundary_guards() -> bool:
	print("  [CHALLENGE 7] Water Station Capacity & Boundary Guards...")
	var initial_failures: int = Assertions.current_suite_failed
	var env: Dictionary = _setup_isolated_world()
	var wrm = env["wrm"]
	var gm = env["gm"]

	gm.watering_can_water = 0
	var check0: Dictionary = wrm.can_refill_water()
	Assertions.assert_true(check0.get("success", false), "Can refill at 0/10")

	var refilled: bool = wrm.refill_water()
	Assertions.assert_true(refilled, "refill_water succeeded")
	Assertions.assert_equal(gm.watering_can_water, 10, "Water level now 10/10")

	# Rejection when full
	var check_full: Dictionary = wrm.can_refill_water()
	Assertions.assert_false(check_full.get("success", true), "Refill rejected when full (10/10)")
	Assertions.assert_true(str(check_full.get("reason", "")).contains("Air sudah penuh"), "Reason indicates full")

	var refilled_again: bool = wrm.refill_water()
	Assertions.assert_false(refilled_again, "refill_water returns false when full")
	Assertions.assert_equal(gm.watering_can_water, 10, "Water level remains 10")

	_cleanup_world(env)
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	print("  [CHALLENGE 7] Result: %s" % ("PASS" if ok else "FAIL"))
	return ok

# ==============================================================================
# CHALLENGE 8: Persistence Roundtrip & Fuzzing/Corruption Resistance
# ==============================================================================

func challenge_08_persistence_roundtrip_and_fuzzing() -> bool:
	print("  [CHALLENGE 8] Persistence Roundtrip & Fuzzing/Corruption Resistance...")
	var initial_failures: int = Assertions.current_suite_failed
	var env := _setup_isolated_world()
	var wrm = env["wrm"]

	# 8.1 Snapshot roundtrip
	wrm.current_day = 14
	wrm.day_active_time = 612.35
	wrm.last_harvested_day["resource_jagung_01"] = 14
	wrm.last_harvested_day["resource_temu_kunci_01"] = 12

	var snapshot: Dictionary = wrm.get_save_snapshot()
	Assertions.assert_equal(int(snapshot["version"]), 1, "Snapshot version is 1")
	Assertions.assert_equal(int(snapshot["current_day"]), 14, "current_day is 14")
	Assertions.assert_approx_equal(float(snapshot["day_active_time"]), 612.35, 0.001, "day_active_time is 612.35")

	# Wipe state
	wrm.reset_state()
	Assertions.assert_equal(wrm.current_day, 1, "State reset to day 1")

	# Restore snapshot
	var loaded: bool = wrm.load_save_snapshot(snapshot)
	Assertions.assert_true(loaded, "load_save_snapshot succeeded")
	Assertions.assert_equal(wrm.current_day, 14, "current_day restored to 14")
	Assertions.assert_approx_equal(wrm.day_active_time, 612.35, 0.001, "day_active_time restored")
	Assertions.assert_false(wrm.is_foraging_node_available("resource_jagung_01"), "Corn node correctly depleted on Day 14")
	Assertions.assert_true(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Temu node available (last Day 12 < Day 14)")

	# 8.2 Fuzzing & Malformed data resistance
	Assertions.assert_false(wrm.load_save_snapshot({}), "Empty dictionary rejected")
	Assertions.assert_false(wrm.load_save_snapshot({"version": 2}), "Incompatible version rejected")
	Assertions.assert_false(wrm.load_save_snapshot({"version": 0}), "Version 0 rejected")

	_cleanup_world(env)
	var ok := (Assertions.current_suite_failed == initial_failures)
	print("  [CHALLENGE 8] Result: %s" % ("PASS" if ok else "FAIL"))
	return ok
