class_name TestAdversarialCookingHeat
extends RefCounted

## Adversarial & Stress Testing Harness untuk Milestone COOK-002
## Memverifikasi secara empiris:
## - Invarian Centang Buku Resep (T19) pada progres 0.0s s/d 29.99s
## - Siklus Remake (Masak ke-2 dan ke-3): Counter times_cooked tepat, sinyal recipe_completed tidak terpancar ganda
## - Aksi Makan Hidangan (eat_dish): Tas kosong vs isi, pengurangan atomik 1 unit, meal_used = true, honest toast tanpa hunger bar
## - Save/Load Snapshot Envelope v1 saat proses memasak berjalan (mid-cooking active, paused, stalled, output_ready)
## - Gating Klaim Output & Penolakan Pembatalan Mid-Cook

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const RecipeManagerClass = preload("res://scripts/recipe/recipe_manager.gd")
const KitchenManagerClass = preload("res://scripts/cooking/kitchen_manager.gd")
const WorldResourceManagerClass = preload("res://scripts/world/world_resource_manager.gd")

func run_all() -> bool:
	var passed := true
	print("==================================================")
	print("[ADVERSARIAL_SUITE] COOK-002 Empirical Stress & Invariant Verification")
	print("==================================================")

	# Invariant 1: T19 Checkmark Invariant (0.0s to 29.99s)
	if not test_adv01_t19_recipe_checkmark_invariant_granular_subsecond():
		passed = false

	# Invariant 2: T19 Remake Cycles & Signal Deduplication
	if not test_adv02_t19_remake_cycle_2nd_and_3rd_cooking_and_signal_dedup():
		passed = false

	# Invariant 3: T43 Action Eat Dish (Empty vs Populated & Atomic Decrement)
	if not test_adv03_t43_action_eat_dish_empty_single_and_multiple():
		passed = false

	# Invariant 4: T43 Honest Feedback & No Hunger/Stat Bars
	if not test_adv04_t43_no_hunger_bar_and_honest_toast_contract():
		passed = false

	# Invariant 5: Save/Load Mid-Cooking Active (Medium Heat)
	if not test_adv05_save_load_mid_cooking_active_medium_heat():
		passed = false

	# Invariant 6: Save/Load Mid-Cooking Paused (Low Heat)
	if not test_adv06_save_load_mid_cooking_paused_low_heat():
		passed = false

	# Invariant 7: Save/Load Mid-Cooking Stalled (High Heat)
	if not test_adv07_save_load_mid_cooking_stalled_high_heat():
		passed = false

	# Invariant 8: Save/Load Output Ready & Meal Used Persistence
	if not test_adv08_save_load_output_ready_and_meal_used_persistence():
		passed = false

	# Invariant 9: 100x Rapid Dynamic Heat Switching Stress
	if not test_adv09_rapid_heat_switching_stress_100x():
		passed = false

	# Invariant 10: Output Claim Gating, Full Backpack Recovery & No Double-Claim
	if not test_adv10_output_claim_gating_and_full_backpack_recovery():
		passed = false

	# Invariant 11: Mid-Cook Cancellation Lockout Invariant
	if not test_adv11_cooking_cancellation_lockout_invariant():
		passed = false

	# Invariant 12: Malformed Save Snapshot Resilience
	if not test_adv12_malformed_save_snapshot_resilience():
		passed = false

	# Invariant 13: Dynamic Heat Switching Sequence (Low -> High -> Med -> High) & Time Accumulation
	if not test_adv13_dynamic_heat_switching_sequence_low_high_med_high():
		passed = false

	# Invariant 14: High Heat Stall (0.0x) Zero-Drift & Matter Conservation
	if not test_adv14_high_heat_stall_matter_conservation_and_zero_drift():
		passed = false

	# Invariant 15: 100x Rapid Toggle Pause/Resume Stress & Zero Drift Invariance
	if not test_adv15_rapid_toggle_pause_resume_100x_stress():
		passed = false

	# Invariant 16: Occupied Output Slot Blocks All Prep & Cook Attempts
	if not test_adv16_occupied_output_blocks_all_prep_and_cook_attempts():
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

func _create_clean_recipe(inv: Node = null) -> Node:
	var rm: Node = RecipeManagerClass.new()
	if inv != null:
		rm.set_inventory_manager(inv)
	rm._ready()
	return rm

func _create_clean_kitchen(inv: Node, rm: Node = null) -> Node:
	var km: Node = KitchenManagerClass.new()
	km.set_inventory_manager(inv)
	if rm != null:
		km.set_recipe_manager(rm)
	km._ready()
	return km

func _setup_ready_to_heat(inv: Node, km: Node) -> void:
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	km.start_preparation("recipe_sayur_bening_01")
	km.advance_prep(4.0)

# ==============================================================================
# CHALLENGE 1: T19 Recipe Checkmark Granular Subsecond Invariant (0.0s - 29.99s)
# ==============================================================================

func test_adv01_t19_recipe_checkmark_invariant_granular_subsecond() -> bool:
	print("  [RUN] ADV.COOK-01: T19 Recipe Checkmark Granular Subsecond Invariant (0.0s - 29.99s)")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	var completion_signals: Array[String] = []
	rm.recipe_completed.connect(func(r_id): completion_signals.append(r_id))

	km.start_cooking(km.HeatLevel.MEDIUM)

	# Uji titik-titik waktu sub-detik secara ketat
	var test_checkpoints: Array[float] = [
		0.0, 0.01, 0.5, 1.0, 5.0, 10.0, 15.0, 20.0, 25.0, 28.0, 29.0, 29.5, 29.9, 29.95, 29.99
	]

	var prev_time: float = 0.0
	for cp in test_checkpoints:
		var delta = cp - prev_time
		if delta > 0.0:
			km.advance_cooking(delta)
			prev_time = cp

		Assertions.assert_approx_equal(km.cook_progress, cp, 0.005, "ADV-01 Checkpoint %.2fs reached" % cp)
		Assertions.assert_false(rm.is_recipe_completed("recipe_sayur_bening_01"), "ADV-01: Must NOT be completed at %.2fs" % cp)
		var recipe = rm.get_recipe("recipe_sayur_bening_01")
		Assertions.assert_equal(recipe.times_cooked, 0, "ADV-01: times_cooked strictly 0 at %.2fs" % cp)
		Assertions.assert_equal(completion_signals.size(), 0, "ADV-01: Zero recipe_completed signals at %.2fs" % cp)
		Assertions.assert_ne(km.job_state, km.JobState.OUTPUT_READY, "ADV-01: Not OUTPUT_READY at %.2fs" % cp)

	# Sekarang majukan sisa 0.01s hingga tepat 30.0s
	km.advance_cooking(0.01)
	Assertions.assert_approx_equal(km.cook_progress, 30.0, 0.01, "ADV-01: Reached exact 30.0s")
	Assertions.assert_true(rm.is_recipe_completed("recipe_sayur_bening_01"), "ADV-01: Completed at exactly 30.0s")
	var rec_done = rm.get_recipe("recipe_sayur_bening_01")
	Assertions.assert_equal(rec_done.times_cooked, 1, "ADV-01: times_cooked is exactly 1 at 30.0s")
	Assertions.assert_equal(completion_signals.size(), 1, "ADV-01: recipe_completed signal emitted exactly once at 30.0s")
	Assertions.assert_equal(km.job_state, km.JobState.OUTPUT_READY, "ADV-01: State is OUTPUT_READY at 30.0s")

	inv.free()
	rm.free()
	km.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-01: T19 checkmark invariant verified.")
	else:
		printerr("  [FAIL] ADV.COOK-01: T19 checkmark invariant failed.")
	return ok

# ==============================================================================
# CHALLENGE 2: T19 Remake Cycles (2nd and 3rd Cook) & Signal Deduplication
# ==============================================================================

func test_adv02_t19_remake_cycle_2nd_and_3rd_cooking_and_signal_dedup() -> bool:
	print("  [RUN] ADV.COOK-02: T19 Remake Cycles (2nd & 3rd) & Signal Deduplication")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)

	var completion_signals: Array[String] = []
	rm.recipe_completed.connect(func(r_id): completion_signals.append(r_id))

	var recipe = rm.get_recipe("recipe_sayur_bening_01")
	Assertions.assert_equal(recipe.times_cooked, 0, "ADV-02: Initial times_cooked = 0")

	# --- CYCLE 1: Masak ke-1 ---
	_setup_ready_to_heat(inv, km)
	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(30.0)
	Assertions.assert_equal(recipe.times_cooked, 1, "ADV-02 Cycle 1: times_cooked = 1")
	Assertions.assert_equal(completion_signals.size(), 1, "ADV-02 Cycle 1: 1st signal emitted")
	Assertions.assert_true(rm.is_recipe_completed("recipe_sayur_bening_01"), "ADV-02 Cycle 1: Checkmark active")

	# Klaim masakan ke-1
	var claim1: Dictionary = km.claim_dish_output()
	Assertions.assert_true(claim1.get("success", false), "ADV-02 Cycle 1: Claim succeeds")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 1, "ADV-02 Cycle 1: 1 dish in bag")

	# --- CYCLE 2: Masak ke-2 (Remake #1) ---
	_setup_ready_to_heat(inv, km)
	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(30.0)
	Assertions.assert_equal(recipe.times_cooked, 2, "ADV-02 Cycle 2: times_cooked strictly increments to 2")
	Assertions.assert_equal(completion_signals.size(), 1, "ADV-02 Cycle 2: NO duplicate signal emitted on remake (count remains 1)")
	Assertions.assert_true(rm.is_recipe_completed("recipe_sayur_bening_01"), "ADV-02 Cycle 2: Checkmark remains active")

	# Klaim masakan ke-2
	var claim2: Dictionary = km.claim_dish_output()
	Assertions.assert_true(claim2.get("success", false), "ADV-02 Cycle 2: Claim succeeds")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 2, "ADV-02 Cycle 2: 2 dishes in bag")

	# --- CYCLE 3: Masak ke-3 (Remake #2) ---
	_setup_ready_to_heat(inv, km)
	km.start_cooking(km.HeatLevel.LOW)
	km.advance_cooking(60.0) # 60s di Low = 30s progres
	Assertions.assert_equal(recipe.times_cooked, 3, "ADV-02 Cycle 3: times_cooked strictly increments to 3")
	Assertions.assert_equal(completion_signals.size(), 1, "ADV-02 Cycle 3: NO duplicate signal emitted on 3rd cook (count still 1)")
	Assertions.assert_true(rm.is_recipe_completed("recipe_sayur_bening_01"), "ADV-02 Cycle 3: Checkmark remains active")

	# Klaim masakan ke-3
	var claim3: Dictionary = km.claim_dish_output()
	Assertions.assert_true(claim3.get("success", false), "ADV-02 Cycle 3: Claim succeeds")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 3, "ADV-02 Cycle 3: 3 dishes in bag")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-02: Remake cycles & signal dedup verified.")
	else:
		printerr("  [FAIL] ADV.COOK-02: Remake cycles failed.")
	return ok

# ==============================================================================
# CHALLENGE 3: T43 Action Eat Dish (Empty vs Populated & Atomic Decrement)
# ==============================================================================

func test_adv03_t43_action_eat_dish_empty_single_and_multiple() -> bool:
	print("  [RUN] ADV.COOK-03: T43 Action Eat Dish (Empty vs Populated & Atomic Decrement)")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)

	# 1. Percobaan makan saat tas kosong
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 0, "ADV-03: Bag empty of dishes")
	Assertions.assert_false(km.meal_used, "ADV-03: meal_used initial false")

	var eat_empty = km.eat_dish("dish_sayur_bening")
	Assertions.assert_false(eat_empty.get("success", true), "ADV-03: eat_dish rejected when bag empty")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 0, "ADV-03: Count remains 0 (no negative)")
	Assertions.assert_false(km.meal_used, "ADV-03: meal_used remains false after failed eat")

	# 2. Percobaan makan saat tas memiliki 1 porsi
	inv.backpack.add_item("dish_sayur_bening", 1)
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 1, "ADV-03: 1 dish in bag")

	var eat_one = km.eat_dish("dish_sayur_bening")
	Assertions.assert_true(eat_one.get("success", false), "ADV-03: eat_dish succeeds with 1 dish")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 0, "ADV-03: Exactly 1 dish deducted (count now 0)")
	Assertions.assert_true(km.meal_used, "ADV-03: meal_used is now true")

	# 3. Panggilan berulang setelah hidangan habis (Anti-underflow spam 20x)
	for i in range(20):
		var eat_spam = km.eat_dish("dish_sayur_bening")
		Assertions.assert_false(eat_spam.get("success", true), "ADV-03: Spam eat #%d rejected" % i)
		Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 0, "ADV-03: No underflow, count remains 0")
		Assertions.assert_true(km.meal_used, "ADV-03: meal_used remains true (does not toggle back)")

	# 4. Percobaan makan saat tas memiliki 5 porsi (Multi-portion atomic decrement)
	inv.backpack.add_item("dish_sayur_bening", 5)
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 5, "ADV-03: 5 dishes in bag")

	var eat_multi = km.eat_dish("dish_sayur_bening")
	Assertions.assert_true(eat_multi.get("success", false), "ADV-03: eat_dish succeeds with 5 dishes")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 4, "ADV-03: Exactly 1 dish deducted, 4 remain")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-03: Action eat dish verified.")
	else:
		printerr("  [FAIL] ADV.COOK-03: Action eat dish failed.")
	return ok

# ==============================================================================
# CHALLENGE 4: T43 Honest Feedback & No Hunger/Stat Bars
# ==============================================================================

func test_adv04_t43_no_hunger_bar_and_honest_toast_contract() -> bool:
	print("  [RUN] ADV.COOK-04: T43 Honest Feedback & Strict No-Hunger/Stat Invariant")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)

	inv.backpack.add_item("dish_sayur_bening", 1)
	var eat_res = km.eat_dish("dish_sayur_bening")
	Assertions.assert_true(eat_res.get("success", false), "ADV-04: Eat dish succeeds")

	# 1. Verifikasi teks umpan balik jujur (Honest feedback)
	var msg: String = str(eat_res.get("message", eat_res.get("reason", "")))
	Assertions.assert_true(msg.contains("Hangat. Resep pertama berhasil dibuat."), "ADV-04: Honest feedback contains 'Hangat. Resep pertama berhasil dibuat.'")

	# 2. Verifikasi TIDAK ADA stat hunger/stamina/buff pada sistem sesuai AGENTS.md § 4
	Assertions.assert_false("hunger" in km, "ADV-04: No hunger property in KitchenManager")
	Assertions.assert_false("stamina" in km, "ADV-04: No stamina property in KitchenManager")
	Assertions.assert_false("health_boost" in km, "ADV-04: No health boost in KitchenManager")
	Assertions.assert_false("hunger_level" in inv, "ADV-04: No hunger level in InventoryManager")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-04: Honest feedback & no-hunger invariant verified.")
	else:
		printerr("  [FAIL] ADV.COOK-04: Honest feedback failed.")
	return ok

# ==============================================================================
# CHALLENGE 5: Save/Load Mid-Cooking Active (Medium Heat)
# ==============================================================================

func test_adv05_save_load_mid_cooking_active_medium_heat() -> bool:
	print("  [RUN] ADV.COOK-05: Save/Load Mid-Cooking Active at 15.0s (Medium Heat)")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	var rm1 := _create_clean_recipe(inv)
	var km1 := _create_clean_kitchen(inv, rm1)
	_setup_ready_to_heat(inv, km1)

	km1.start_cooking(km1.HeatLevel.MEDIUM)
	km1.advance_cooking(15.0)
	Assertions.assert_approx_equal(km1.cook_progress, 15.0, 0.05, "ADV-05: Progress 15.0s")
	Assertions.assert_equal(km1.job_state, km1.JobState.COOKING, "ADV-05: State COOKING")

	# Snapshot
	var snapshot: Dictionary = km1.get_save_snapshot()
	Assertions.assert_equal(snapshot.get("version"), 1, "ADV-05: Version 1")
	Assertions.assert_equal(snapshot.get("job_state"), int(km1.JobState.COOKING), "ADV-05: Saved state COOKING")
	Assertions.assert_approx_equal(float(snapshot.get("cook_progress")), 15.0, 0.05, "ADV-05: Saved progress 15.0s")
	Assertions.assert_equal(int(snapshot.get("heat_level")), int(km1.HeatLevel.MEDIUM), "ADV-05: Saved heat MEDIUM")

	# Instance baru km2
	var rm2 := _create_clean_recipe(inv)
	var km2 := _create_clean_kitchen(inv, rm2)
	var load_ok: bool = km2.load_save_snapshot(snapshot)
	Assertions.assert_true(load_ok, "ADV-05: Load snapshot succeeds")
	Assertions.assert_equal(km2.job_state, km2.JobState.COOKING, "ADV-05: Restored state COOKING")
	Assertions.assert_approx_equal(km2.cook_progress, 15.0, 0.05, "ADV-05: Restored progress 15.0s")
	Assertions.assert_equal(km2.current_heat_level, km2.HeatLevel.MEDIUM, "ADV-05: Restored heat MEDIUM")

	# Lanjutkan memasak sisa 15.0s
	var adv_res: Dictionary = km2.advance_cooking(15.0)
	Assertions.assert_true(adv_res.get("completed", false), "ADV-05: Cooking completes cleanly after reload")
	Assertions.assert_approx_equal(km2.cook_progress, 30.0, 0.05, "ADV-05: Progress reaches 30.0s")
	Assertions.assert_equal(km2.job_state, km2.JobState.OUTPUT_READY, "ADV-05: State is OUTPUT_READY")
	Assertions.assert_equal(km2.dish_output_slot.get("item_id"), "dish_sayur_bening", "ADV-05: Output dish present")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-05: Save/load mid-cooking active verified.")
	else:
		printerr("  [FAIL] ADV.COOK-05: Save/load mid-cooking active failed.")
	return ok

# ==============================================================================
# CHALLENGE 6: Save/Load Mid-Cooking Paused (Low Heat)
# ==============================================================================

func test_adv06_save_load_mid_cooking_paused_low_heat() -> bool:
	print("  [RUN] ADV.COOK-06: Save/Load Mid-Cooking Paused at 10.0s Progress (Low Heat)")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	var rm1 := _create_clean_recipe(inv)
	var km1 := _create_clean_kitchen(inv, rm1)
	_setup_ready_to_heat(inv, km1)

	km1.start_cooking(km1.HeatLevel.LOW)
	# Majukan 20s pada Rendah (0.5x) -> 10.0s progres
	km1.advance_cooking(20.0)
	km1.pause_cooking()

	Assertions.assert_approx_equal(km1.cook_progress, 10.0, 0.05, "ADV-06: Progress 10.0s")
	Assertions.assert_equal(km1.job_state, km1.JobState.PAUSED, "ADV-06: State PAUSED")

	var snapshot: Dictionary = km1.get_save_snapshot()
	Assertions.assert_equal(snapshot.get("job_state"), int(km1.JobState.PAUSED), "ADV-06: Saved state PAUSED")

	# Instance baru km2
	var rm2 := _create_clean_recipe(inv)
	var km2 := _create_clean_kitchen(inv, rm2)
	var load_ok: bool = km2.load_save_snapshot(snapshot)
	Assertions.assert_true(load_ok, "ADV-06: Load succeeds")
	Assertions.assert_equal(km2.job_state, km2.JobState.PAUSED, "ADV-06: State restored to PAUSED")
	Assertions.assert_approx_equal(km2.cook_progress, 10.0, 0.05, "ADV-06: Progress restored to 10.0s")
	Assertions.assert_equal(km2.current_heat_level, km2.HeatLevel.LOW, "ADV-06: Heat restored to LOW")

	# Lanjutkan setelah jeda
	var resume_res = km2.resume_cooking()
	Assertions.assert_true(resume_res.get("success", false), "ADV-06: Resume succeeds")
	Assertions.assert_equal(km2.job_state, km2.JobState.COOKING, "ADV-06: State is COOKING")

	# Majukan 40s pada Rendah (0.5x) -> +20.0s progres -> total 30.0s
	km2.advance_cooking(40.0)
	Assertions.assert_approx_equal(km2.cook_progress, 30.0, 0.05, "ADV-06: Total progress reaches 30.0s")
	Assertions.assert_equal(km2.job_state, km2.JobState.OUTPUT_READY, "ADV-06: Transitions to OUTPUT_READY")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-06: Save/load mid-cooking paused verified.")
	else:
		printerr("  [FAIL] ADV.COOK-06: Save/load mid-cooking paused failed.")
	return ok

# ==============================================================================
# CHALLENGE 7: Save/Load Mid-Cooking Stalled (High Heat)
# ==============================================================================

func test_adv07_save_load_mid_cooking_stalled_high_heat() -> bool:
	print("  [RUN] ADV.COOK-07: Save/Load Mid-Cooking Stalled (High Heat)")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	var rm1 := _create_clean_recipe(inv)
	var km1 := _create_clean_kitchen(inv, rm1)
	_setup_ready_to_heat(inv, km1)

	km1.start_cooking(km1.HeatLevel.MEDIUM)
	km1.advance_cooking(8.0)
	km1.set_heat_level(km1.HeatLevel.HIGH)

	Assertions.assert_true(km1.is_heat_stalled(), "ADV-07: Stalled on HIGH")
	Assertions.assert_approx_equal(km1.cook_progress, 8.0, 0.05, "ADV-07: Progress 8.0s")

	var snapshot: Dictionary = km1.get_save_snapshot()
	Assertions.assert_equal(int(snapshot.get("heat_level")), int(km1.HeatLevel.HIGH), "ADV-07: Saved HIGH heat")

	var rm2 := _create_clean_recipe(inv)
	var km2 := _create_clean_kitchen(inv, rm2)
	var load_ok: bool = km2.load_save_snapshot(snapshot)
	Assertions.assert_true(load_ok, "ADV-07: Load succeeds")
	Assertions.assert_equal(km2.current_heat_level, km2.HeatLevel.HIGH, "ADV-07: Restored HIGH heat")
	Assertions.assert_true(km2.is_heat_stalled(), "ADV-07: Still stalled")

	# Majukan 10s saat stall -> progres tidak bertambah
	km2.advance_cooking(10.0)
	Assertions.assert_approx_equal(km2.cook_progress, 8.0, 0.05, "ADV-07: Progress still 8.0s after stall time")

	# Turunkan ke Sedang dan selesaikan sisa 22.0s
	km2.set_heat_level(km2.HeatLevel.MEDIUM)
	km2.advance_cooking(22.0)
	Assertions.assert_approx_equal(km2.cook_progress, 30.0, 0.05, "ADV-07: Completed to 30.0s")
	Assertions.assert_equal(km2.job_state, km2.JobState.OUTPUT_READY, "ADV-07: State is OUTPUT_READY")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-07: Save/load mid-cooking stalled verified.")
	else:
		printerr("  [FAIL] ADV.COOK-07: Save/load mid-cooking stalled failed.")
	return ok

# ==============================================================================
# CHALLENGE 8: Save/Load Output Ready & Meal Used Persistence
# ==============================================================================

func test_adv08_save_load_output_ready_and_meal_used_persistence() -> bool:
	print("  [RUN] ADV.COOK-08: Save/Load Output Ready & Meal Used Persistence")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	var rm1 := _create_clean_recipe(inv)
	var km1 := _create_clean_kitchen(inv, rm1)
	_setup_ready_to_heat(inv, km1)

	km1.start_cooking(km1.HeatLevel.MEDIUM)
	km1.advance_cooking(30.0)
	km1.meal_used = true

	var snapshot: Dictionary = km1.get_save_snapshot()
	Assertions.assert_equal(snapshot.get("job_state"), int(km1.JobState.OUTPUT_READY), "ADV-08: State OUTPUT_READY")
	Assertions.assert_true(snapshot.get("meal_used"), "ADV-08: meal_used saved true")
	Assertions.assert_equal(snapshot.get("dish_output_slot", {}).get("item_id"), "dish_sayur_bening", "ADV-08: Dish saved")

	var rm2 := _create_clean_recipe(inv)
	var km2 := _create_clean_kitchen(inv, rm2)
	var load_ok: bool = km2.load_save_snapshot(snapshot)
	Assertions.assert_true(load_ok, "ADV-08: Load succeeds")
	Assertions.assert_equal(km2.job_state, km2.JobState.OUTPUT_READY, "ADV-08: Restored state OUTPUT_READY")
	Assertions.assert_true(km2.meal_used, "ADV-08: Restored meal_used true")
	Assertions.assert_equal(km2.dish_output_slot.get("item_id"), "dish_sayur_bening", "ADV-08: Restored dish in slot")

	# Klaim masakan pada instance km2
	var claim_res = km2.claim_dish_output()
	Assertions.assert_true(claim_res.get("success", false), "ADV-08: Claim succeeds on restored instance")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 1, "ADV-08: Bag received dish")
	Assertions.assert_equal(km2.job_state, km2.JobState.IDLE, "ADV-08: Reset to IDLE")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-08: Save/load output ready & meal used verified.")
	else:
		printerr("  [FAIL] ADV.COOK-08: Save/load output ready failed.")
	return ok

# ==============================================================================
# CHALLENGE 9: 100x Rapid Dynamic Heat Switching Stress
# ==============================================================================

func test_adv09_rapid_heat_switching_stress_100x() -> bool:
	print("  [RUN] ADV.COOK-09: 100x Rapid Dynamic Heat Switching Stress")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	km.start_cooking(km.HeatLevel.LOW)

	# Lakukan 100 pergantian panas acak terprediksi dengan delta 0.1s
	# 40 langkah di Medium (0.1s * 1.0 = 4.0s)
	# 30 langkah di Low (0.1s * 0.5 = 1.5s)
	# 30 langkah di High (0.1s * 0.0 = 0.0s)
	# Total ekspektasi progres tambahan: 5.5s
	for i in range(100):
		var mod := i % 3
		if mod == 0:
			km.set_heat_level(km.HeatLevel.MEDIUM)
		elif mod == 1:
			km.set_heat_level(km.HeatLevel.LOW)
		else:
			km.set_heat_level(km.HeatLevel.HIGH)

		km.advance_cooking(0.1)

	var expected_prog: float = (34 * 0.1 * 1.0) + (33 * 0.1 * 0.5) + (33 * 0.1 * 0.0)
	Assertions.assert_approx_equal(km.cook_progress, expected_prog, 0.05, "ADV-09: Accumulated progress exactly matches theoretical model (%.2fs)" % expected_prog)

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-09: 100x rapid heat switching verified.")
	else:
		printerr("  [FAIL] ADV.COOK-09: Heat switching stress failed.")
	return ok

# ==============================================================================
# CHALLENGE 10: Output Claim Gating, Full Backpack Recovery & No Double-Claim
# ==============================================================================

func test_adv10_output_claim_gating_and_full_backpack_recovery() -> bool:
	print("  [RUN] ADV.COOK-10: Output Claim Gating, Full Backpack Recovery & Double-Claim Rejection")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)

	# 1. Klaim saat slot kosong
	var claim_empty = km.claim_dish_output()
	Assertions.assert_false(claim_empty.get("success", true), "ADV-10: Claim empty rejected")

	# Masak sampai matang
	_setup_ready_to_heat(inv, km)
	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(30.0)
	Assertions.assert_true(km.has_ready_output(), "ADV-10: Output ready")

	# Penuhi tas dengan 12 item berbeda agar 12 slot terisi penuh
	for i in range(12):
		inv.backpack.add_item("junk_item_%d" % i, 1)
	Assertions.assert_equal(inv.backpack.get_used_slots_count(), 12, "ADV-10: Backpack 12/12 full")

	# 2. Klaim saat tas penuh -> ditolak, masakan tetap di slot
	var claim_full = km.claim_dish_output()
	Assertions.assert_false(claim_full.get("success", true), "ADV-10: Claim full rejected")
	Assertions.assert_true(km.has_ready_output(), "ADV-10: Dish still in kitchen output slot")
	Assertions.assert_equal(km.dish_output_slot.get("count"), 1, "ADV-10: Dish count still 1")

	# 3. Kosongkan 1 slot di tas -> klaim sukses
	inv.backpack.remove_item("junk_item_0", 1)
	Assertions.assert_equal(inv.backpack.get_used_slots_count(), 11, "ADV-10: Backpack now 11/12")

	var claim_ok = km.claim_dish_output()
	Assertions.assert_true(claim_ok.get("success", false), "ADV-10: Claim succeeds into freed slot")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 1, "ADV-10: Dish added to backpack")
	Assertions.assert_false(km.has_ready_output(), "ADV-10: Slot cleared")
	Assertions.assert_equal(km.job_state, km.JobState.IDLE, "ADV-10: Kitchen IDLE")

	# 4. Klaim kedua kali langsung (Anti double-claim) -> harus ditolak
	var claim_double = km.claim_dish_output()
	Assertions.assert_false(claim_double.get("success", true), "ADV-10: Double claim cleanly rejected")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 1, "ADV-10: Dish count in backpack strictly 1 (NO DUPLICATION)")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-10: Output claim gating verified.")
	else:
		printerr("  [FAIL] ADV.COOK-10: Output claim gating failed.")
	return ok

# ==============================================================================
# CHALLENGE 11: Mid-Cook Cancellation Lockout Invariant
# ==============================================================================

func test_adv11_cooking_cancellation_lockout_invariant() -> bool:
	print("  [RUN] ADV.COOK-11: Mid-Cook Cancellation Lockout Invariant")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(10.0)
	Assertions.assert_equal(km.job_state, km.JobState.COOKING, "ADV-11: State is COOKING")

	# Coba batalkan persiapan saat sedang memasak aktif
	var cancel_active = km.cancel_preparation()
	Assertions.assert_false(cancel_active.get("success", true), "ADV-11: cancel_preparation must be rejected during COOKING")
	Assertions.assert_equal(km.job_state, km.JobState.COOKING, "ADV-11: State remains COOKING")
	Assertions.assert_approx_equal(km.cook_progress, 10.0, 0.05, "ADV-11: Progress intact at 10.0s")

	# Coba batalkan saat PAUSED
	km.pause_cooking()
	Assertions.assert_equal(km.job_state, km.JobState.PAUSED, "ADV-11: State is PAUSED")
	var cancel_paused = km.cancel_preparation()
	Assertions.assert_false(cancel_paused.get("success", true), "ADV-11: cancel_preparation must be rejected during PAUSED")
	Assertions.assert_equal(km.job_state, km.JobState.PAUSED, "ADV-11: State remains PAUSED")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-11: Mid-cook cancellation lockout verified.")
	else:
		printerr("  [FAIL] ADV.COOK-11: Mid-cook cancellation lockout failed.")
	return ok

# ==============================================================================
# CHALLENGE 12: Malformed Save Snapshot Resilience
# ==============================================================================

func test_adv12_malformed_save_snapshot_resilience() -> bool:
	print("  [RUN] ADV.COOK-12: Malformed Save Snapshot Resilience")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	var km := _create_clean_kitchen(inv)

	# 1. Empty dictionary
	var load_empty: bool = km.load_save_snapshot({})
	Assertions.assert_false(load_empty, "ADV-12: Empty dictionary rejected")

	# 2. Corrupted field types
	var corrupt_snapshot = {
		"version": "not_an_int",
		"job_state": "invalid_state_string",
		"cook_progress": "corrupted_float",
		"reserved_ingredients": "not_an_array"
	}
	# load_save_snapshot harus menangani konversi tanpa crash
	var load_corrupt: bool = km.load_save_snapshot(corrupt_snapshot)
	# Apapun hasil load, engine tidak boleh crash dan state dapur harus stabil
	Assertions.assert_true(km.job_state in [km.JobState.IDLE, km.JobState.COOKING, km.JobState.PAUSED, km.JobState.OUTPUT_READY, km.JobState.RESERVED_PREPARING, km.JobState.READY_TO_HEAT, km.JobState.REFUND_PENDING], "ADV-12: State remains within valid enum range")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-12: Malformed snapshot resilience verified.")
	else:
		printerr("  [FAIL] ADV.COOK-12: Malformed snapshot resilience failed.")
	return ok

# ==============================================================================
# CHALLENGE 13: ADV.COOK-13 Dynamic Heat Switching Sequence (Low -> High -> Med -> High)
# ==============================================================================

func test_adv13_dynamic_heat_switching_sequence_low_high_med_high() -> bool:
	print("  [RUN] ADV.COOK-13: Dynamic Heat Switching Sequence (Low -> High -> Med -> High) (T41)")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	# 1. Mulai di Low (0.5x)
	var start_res: Dictionary = km.start_cooking(km.HeatLevel.LOW)
	Assertions.assert_true(start_res.get("success", false), "ADV-13: start_cooking succeeds")
	Assertions.assert_equal(km.job_state, km.JobState.COOKING, "ADV-13: In COOKING state")
	Assertions.assert_equal(km.current_heat_level, km.HeatLevel.LOW, "ADV-13: Current heat is LOW")
	Assertions.assert_approx_equal(km.get_heat_multiplier(), 0.5, 0.001, "ADV-13: Low multiplier is 0.5x")

	# Jalankan 10.0s pada Low -> +5.0s progres
	km.advance_cooking(10.0)
	Assertions.assert_approx_equal(km.cook_progress, 5.0, 0.01, "ADV-13: Low 10s physical -> 5.0s progress")

	# 2. Beralih ke High (0.0x / stall)
	km.set_heat_level(km.HeatLevel.HIGH)
	Assertions.assert_equal(km.current_heat_level, km.HeatLevel.HIGH, "ADV-13: Current heat is HIGH")
	Assertions.assert_approx_equal(km.get_heat_multiplier(), 0.0, 0.001, "ADV-13: High multiplier is 0.0x")
	Assertions.assert_true(km.is_heat_stalled(), "ADV-13: is_heat_stalled is true")

	# Jalankan 15.0s pada High -> +0.0s progres (tetap 5.0s)
	km.advance_cooking(15.0)
	Assertions.assert_approx_equal(km.cook_progress, 5.0, 0.001, "ADV-13: High 15s physical -> progress holds at 5.0s")

	# 3. Beralih ke Med (1.0x / nominal)
	km.set_heat_level(km.HeatLevel.MEDIUM)
	Assertions.assert_equal(km.current_heat_level, km.HeatLevel.MEDIUM, "ADV-13: Current heat is MEDIUM")
	Assertions.assert_approx_equal(km.get_heat_multiplier(), 1.0, 0.001, "ADV-13: Med multiplier is 1.0x")
	Assertions.assert_false(km.is_heat_stalled(), "ADV-13: is_heat_stalled is false")

	# Jalankan 10.0s pada Med -> +10.0s progres (total 15.0s)
	km.advance_cooking(10.0)
	Assertions.assert_approx_equal(km.cook_progress, 15.0, 0.01, "ADV-13: Med 10s physical -> progress is 15.0s")

	# 4. Beralih kembali ke High (0.0x / stall)
	km.set_heat_level(km.HeatLevel.HIGH)
	Assertions.assert_true(km.is_heat_stalled(), "ADV-13: is_heat_stalled is true again")

	# Jalankan 20.0s pada High -> +0.0s progres (tetap 15.0s)
	km.advance_cooking(20.0)
	Assertions.assert_approx_equal(km.cook_progress, 15.0, 0.001, "ADV-13: High 20s physical -> progress holds at 15.0s")

	# 5. Selesaikan memasak: Beralih ke Med selama 15.0s -> progres mencapai 30.0s (OUTPUT_READY)
	km.set_heat_level(km.HeatLevel.MEDIUM)
	var final_adv: Dictionary = km.advance_cooking(15.0)
	Assertions.assert_true(final_adv.get("completed", false), "ADV-13: Cook completed")
	Assertions.assert_approx_equal(km.cook_progress, 30.0, 0.01, "ADV-13: Cook progress reaches 30.0s")
	Assertions.assert_equal(km.job_state, km.JobState.OUTPUT_READY, "ADV-13: Transitioned to OUTPUT_READY")

	# Verifikasi total waktu fisik simulasi: 10 + 15 + 10 + 20 + 15 = 70.0s
	# Total akumulasi progres memasak: (10*0.5) + (15*0.0) + (10*1.0) + (20*0.0) + (15*1.0) = 5 + 0 + 10 + 0 + 15 = 30.0s

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-13: Dynamic heat switching sequence (Low -> High -> Med -> High) verified.")
	else:
		printerr("  [FAIL] ADV.COOK-13: Dynamic heat switching sequence failed.")
	return ok

# ==============================================================================
# CHALLENGE 14: ADV.COOK-14 High Heat Stall (0.0x) Zero-Drift & Matter Conservation
# ==============================================================================

func test_adv14_high_heat_stall_matter_conservation_and_zero_drift() -> bool:
	print("  [RUN] ADV.COOK-14: High Heat Stall (0.0x) Zero-Drift & Matter Conservation (T41)")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(7.5) # Mulai dengan 7.5s progres
	var baseline_progress: float = km.cook_progress
	Assertions.assert_approx_equal(baseline_progress, 7.5, 0.001, "ADV-14: Baseline established at 7.5s")

	# Pasang listener sinyal stall warning
	var stall_warnings: Array[String] = []
	km.heat_stall_warning.connect(func(msg): stall_warnings.append(msg))

	km.set_heat_level(km.HeatLevel.HIGH)
	Assertions.assert_true(km.is_heat_stalled(), "ADV-14: is_heat_stalled is true")
	Assertions.assert_true(stall_warnings.size() >= 1, "ADV-14: Stall warning fired on switch to High")
	Assertions.assert_true(stall_warnings[0].contains("Kecilkan panas ke Sedang"), "ADV-14: Warning text matches expected honest advice")

	# Uji ketahanan terhadap ribuan delta ticks sub-detik (delta 0.016, 60fps)
	for i in range(1000):
		var tick_res: Dictionary = km.advance_cooking(0.016)
		Assertions.assert_true(tick_res.get("stalled", false), "ADV-14 Tick %d: Reports stalled" % i)

	Assertions.assert_approx_equal(km.cook_progress, baseline_progress, 0.0001, "ADV-14: Zero drift across 1000 subsecond ticks")

	# Uji delta besar (3600s = 1 jam)
	var big_tick: Dictionary = km.advance_cooking(3600.0)
	Assertions.assert_true(big_tick.get("stalled", false), "ADV-14: 1-hour tick reports stalled")
	Assertions.assert_approx_equal(km.cook_progress, baseline_progress, 0.0001, "ADV-14: Zero drift across 1-hour massive tick")

	# Hukum Kekekalan Materi (Matter Conservation):
	# Bahan TIDAK boleh hangus, hilang, atau dikurangi saat stall
	Assertions.assert_equal(km.reserved_ingredients.size(), 3, "ADV-14: All 3 reserved ingredient types present")
	var counts: Dictionary = {}
	for it in km.reserved_ingredients:
		counts[str(it.get("item_id"))] = int(it.get("count"))
	Assertions.assert_equal(counts.get("ingredient_bayam"), 3, "ADV-14: 3 bayam strictly conserved")
	Assertions.assert_equal(counts.get("ingredient_jagung"), 1, "ADV-14: 1 corn strictly conserved")
	Assertions.assert_equal(counts.get("ingredient_temu_kunci"), 1, "ADV-14: 1 temu kunci strictly conserved")

	# Kembalikan ke Medium dan selesaikan
	km.set_heat_level(km.HeatLevel.MEDIUM)
	km.advance_cooking(22.5) # 7.5 + 22.5 = 30.0s
	Assertions.assert_equal(km.job_state, km.JobState.OUTPUT_READY, "ADV-14: Transitions cleanly to OUTPUT_READY")
	Assertions.assert_equal(km.dish_output_slot.get("item_id"), "dish_sayur_bening", "ADV-14: Dish produced cleanly")
	Assertions.assert_equal(km.dish_output_slot.get("count"), 1, "ADV-14: Exactly 1 dish produced")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-14: High heat stall zero-drift and matter conservation verified.")
	else:
		printerr("  [FAIL] ADV.COOK-14: High heat stall failed.")
	return ok

# ==============================================================================
# CHALLENGE 15: ADV.COOK-15 100x Rapid Toggle Pause/Resume Stress & Zero Drift
# ==============================================================================

func test_adv15_rapid_toggle_pause_resume_100x_stress() -> bool:
	print("  [RUN] ADV.COOK-15: 100x Rapid Toggle Pause/Resume Stress & Zero Drift Invariance (T42)")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(11.22)
	var fixed_progress: float = km.cook_progress
	var fixed_job_id: String = km.active_job_id
	Assertions.assert_approx_equal(fixed_progress, 11.22, 0.001, "ADV-15: Baseline progress 11.22s")

	# 100 siklus toggle pause dan resume secara bertubi-tubi
	for i in range(100):
		var p_res: Dictionary = km.pause_cooking()
		Assertions.assert_true(p_res.get("success", false), "ADV-15 Cycle %d: pause succeeds" % i)
		Assertions.assert_equal(km.job_state, km.JobState.PAUSED, "ADV-15 Cycle %d: state is PAUSED" % i)

		# Panggilan ganda pause saat sudah PAUSED harus ditolak bersih
		var p_dup: Dictionary = km.pause_cooking()
		Assertions.assert_false(p_dup.get("success", true), "ADV-15 Cycle %d: duplicate pause rejected" % i)

		# advance_cooking saat PAUSED harus ditolak dan tidak memajukan progres
		var adv_paused: Dictionary = km.advance_cooking(2.5)
		Assertions.assert_false(adv_paused.get("success", true), "ADV-15 Cycle %d: advance while paused rejected" % i)
		Assertions.assert_approx_equal(km.cook_progress, fixed_progress, 0.0001, "ADV-15 Cycle %d: Progress unchanged" % i)

		var r_res: Dictionary = km.resume_cooking()
		Assertions.assert_true(r_res.get("success", false), "ADV-15 Cycle %d: resume succeeds" % i)
		Assertions.assert_equal(km.job_state, km.JobState.COOKING, "ADV-15 Cycle %d: state is COOKING" % i)

		# Panggilan ganda resume saat sudah COOKING harus ditolak bersih
		var r_dup: Dictionary = km.resume_cooking()
		Assertions.assert_false(r_dup.get("success", true), "ADV-15 Cycle %d: duplicate resume rejected" % i)

	# Pastikan progres TIDAK mengalami drift sekecil apapun
	Assertions.assert_approx_equal(km.cook_progress, fixed_progress, 0.0001, "ADV-15: Zero drift after 100 rapid pause/resume cycles")
	Assertions.assert_equal(km.active_job_id, fixed_job_id, "ADV-15: Job ID remains intact")
	Assertions.assert_equal(km.job_state, km.JobState.COOKING, "ADV-15: Final state is COOKING")

	# Selesaikan sisa memasak
	var remaining_needed: float = km.cook_duration - km.cook_progress
	km.advance_cooking(remaining_needed)
	Assertions.assert_equal(km.job_state, km.JobState.OUTPUT_READY, "ADV-15: Completes to OUTPUT_READY after stress")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-15: 100x rapid toggle pause/resume verified.")
	else:
		printerr("  [FAIL] ADV.COOK-15: Rapid toggle pause/resume failed.")
	return ok

# ==============================================================================
# CHALLENGE 16: ADV.COOK-16 Occupied Output Blocks Preparation & Cooking
# ==============================================================================

func test_adv16_occupied_output_blocks_all_prep_and_cook_attempts() -> bool:
	print("  [RUN] ADV.COOK-16: Occupied Output Slot Blocks All Prep & Cook Attempts (T15)")
	var initial_failures = Assertions.current_suite_failed

	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	# Masak sampai matang (OUTPUT_READY)
	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(30.0)
	Assertions.assert_equal(km.job_state, km.JobState.OUTPUT_READY, "ADV-16: OUTPUT_READY established")
	Assertions.assert_true(km.has_ready_output(), "ADV-16: Output slot has dish")

	# Beri bahan melimpah di tas pemain
	inv.backpack.add_item("ingredient_bayam", 10)
	inv.backpack.add_item("ingredient_jagung", 5)
	inv.backpack.add_item("ingredient_temu_kunci", 5)

	# 1. can_start_preparation harus ditolak
	var check_res: Dictionary = km.can_start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(check_res.get("success", true), "ADV-16: can_start_preparation returns false")
	Assertions.assert_true(str(check_res.get("reason", "")).contains("Ambil hidangan sebelumnya"), "ADV-16: Honest reason provided")

	# 2. start_preparation 50x spam harus ditolak tanpa mutasi inventaris
	for i in range(50):
		var start_prep: Dictionary = km.start_preparation("recipe_sayur_bening_01")
		Assertions.assert_false(start_prep.get("success", true), "ADV-16 Prep Spam %d: Rejected" % i)

	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 10, "ADV-16: Bayam count strictly preserved (10)")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 5, "ADV-16: Corn count strictly preserved (5)")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 5, "ADV-16: Temu kunci count strictly preserved (5)")

	# 3. start_cooking langsung saat OUTPUT_READY harus ditolak
	var start_cook: Dictionary = km.start_cooking(km.HeatLevel.LOW)
	Assertions.assert_false(start_cook.get("success", true), "ADV-16: start_cooking rejected while OUTPUT_READY")

	# 4. State stasiun dan hidangan di output slot tetap utuh
	Assertions.assert_equal(km.job_state, km.JobState.OUTPUT_READY, "ADV-16: JobState remains OUTPUT_READY")
	Assertions.assert_equal(km.dish_output_slot.get("count"), 1, "ADV-16: Dish count in slot strictly 1")
	Assertions.assert_equal(km.dish_output_slot.get("item_id"), "dish_sayur_bening", "ADV-16: Dish ID intact")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.COOK-16: Occupied output slot blocks all prep & cook attempts verified.")
	else:
		printerr("  [FAIL] ADV.COOK-16: Occupied output slot gating failed.")
	return ok
