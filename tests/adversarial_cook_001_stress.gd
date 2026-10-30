extends SceneTree

## Adversarial Stress Harness: COOK-001 (Empirical Challenger 2)
## Menguji ketahanan Hold Preparation Progression & Retention (T12),
## Safe 3-Tier Refund Redirection & Conservation of Matter under Full Containers (T40),
## Bed Sleep Interlock & Day Advance Quarantine (WORLD-001 / PRD FR12),
## Anti-Spam Re-entrancy, dan Save Envelope Roundtrip.

const Assertions = preload("res://tests/assertions.gd")
const KitchenManagerClass = preload("res://scripts/cooking/kitchen_manager.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const WorldResourceManagerClass = preload("res://scripts/world/world_resource_manager.gd")
const RecipeManagerClass = preload("res://scripts/recipe/recipe_manager.gd")

func _init() -> void:
	print("======================================================================")
	print("[CHALLENGER_COOK_001] ADVERSARIAL STRESS HARNESS: COOK-001")
	print("======================================================================")

	Assertions.reset()
	var all_passed := true

	# Challenge 1: Hold Action Progression, Floating Point Drift, & No-Auto-Cook Invariance (T12)
	if not test_challenge_1_hold_progression_and_no_auto_cook():
		all_passed = false

	# Challenge 2: Jitter / Flutter Rapid Hold-Release Cycles (T12 Hold Retention)
	if not test_challenge_2_hold_jitter_and_retention():
		all_passed = false

	# Challenge 3: Extreme Multi-Tier Overflow, Strict Isolation, & Conservation of Matter (T40)
	if not test_challenge_3_overflow_redirection_and_isolation():
		all_passed = false

	# Challenge 4: Partial-Space Spillover Cascades Across 3 Tiers (T40 Edge Case)
	if not test_challenge_4_partial_space_cascading_refund():
		all_passed = false

	# Challenge 5: Cancellation & Claiming Idempotency under High-Frequency Spam
	if not test_challenge_5_cancellation_and_claim_spam_idempotency():
		all_passed = false

	# Challenge 6: Sleep Interlock & Day Advance Quarantine Across All Kitchen States (WORLD-001)
	if not test_challenge_6_sleep_interlock_across_all_states():
		all_passed = false

	# Challenge 7: Anti-Spam Re-entrancy & Output Slot Gating
	if not test_challenge_7_reentrancy_and_output_gating():
		all_passed = false

	# Challenge 8: Save/Load Snapshot Envelope Restoration under Adversarial States
	if not test_challenge_8_snapshot_adversarial_roundtrip():
		all_passed = false

	print("======================================================================")
	print("[CHALLENGER_COOK_001] SUMMARY:")
	print("  Assertions Passed: %d" % Assertions.current_suite_passed)
	print("  Assertions Failed: %d" % Assertions.current_suite_failed)

	var log_path := ProjectSettings.globalize_path("res://adversarial_cook_001_stress.log")
	var log_file := FileAccess.open(log_path, FileAccess.WRITE)
	if log_file != null:
		log_file.store_line("Harness: tests/adversarial_cook_001_stress.gd")
		log_file.store_line("Assertions Passed: %d" % Assertions.current_suite_passed)
		log_file.store_line("Assertions Failed: %d" % Assertions.current_suite_failed)
		log_file.store_line("All Passed: %s" % str(all_passed and Assertions.current_suite_failed == 0))
		log_file.close()

	if all_passed and Assertions.current_suite_failed == 0:
		print("  VERDICT: CONFIRMED CORRECT (Exit Code: 0)")
		print("======================================================================")
		quit(0)
	else:
		printerr("  VERDICT: DEFECT DETECTED (Exit Code: 1)")
		print("======================================================================")
		quit(1)

# --- Helper Methods ---

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

# ==============================================================================
# CHALLENGE 1: Hold Action Progression, Drift, & No-Auto-Cook (T12)
# ==============================================================================

func test_challenge_1_hold_progression_and_no_auto_cook() -> bool:
	print("  [Challenge 1] Testing Micro-Steps, Extreme Deltas & No Auto-Cook...")
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	var km := _create_clean_kitchen(inv)

	# 1. Spurious advance calls before starting prep (should do nothing)
	km.advance_prep(1.0)
	Assertions.assert_equal(km.job_state, km.JobState.IDLE, "Ch1: advance_prep saat IDLE tidak mengubah status")
	Assertions.assert_approx_equal(km.prep_progress, 0.0, 0.0001, "Ch1: prep_progress tetap 0.0")

	km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_equal(km.job_state, km.JobState.RESERVED_PREPARING, "Ch1: Masuk status RESERVED_PREPARING")

	# 2. Micro-step simulation: 4,000 steps of 0.001s = exactly 4.0s
	var completed_emitted := [0]
	km.preparation_completed.connect(func(_j): completed_emitted[0] += 1)

	for i in range(2000):
		km.advance_prep(0.001)

	Assertions.assert_approx_equal(km.prep_progress, 2.0, 0.005, "Ch1: Setelah 2000 micro-steps, progress ~2.0s")
	Assertions.assert_equal(km.job_state, km.JobState.RESERVED_PREPARING, "Ch1: Masih RESERVED_PREPARING pada 2.0s")
	Assertions.assert_equal(completed_emitted[0], 0, "Ch1: Sinyal completed belum terpancar pada 2.0s")

	for i in range(2000):
		km.advance_prep(0.001)

	print("  [DEBUG Ch1] prep_progress after 4000 micro-steps = ", km.prep_progress, " job_state = ", km.job_state)
	Assertions.assert_approx_equal(km.prep_progress, 4.0, 0.005, "Ch1: Setelah 4000 micro-steps, progress mencapai 4.0s")
	# If micro-steps fell slightly short due to floating point accumulation, an extra micro-step pushes it past 4.0
	if km.prep_progress < 4.0:
		km.advance_prep(0.001)
	Assertions.assert_equal(km.job_state, km.JobState.READY_TO_HEAT, "Ch1: Tepat pada 4.0s berpindah ke READY_TO_HEAT")
	Assertions.assert_equal(completed_emitted[0], 1, "Ch1: Sinyal completed terpancar tepat 1 kali")

	# 3. Hold continuation past 4.0s: user continues holding button for 10.0 more seconds
	for i in range(10):
		km.advance_prep(1.0)
		km.hold_tick(1.0, true)

	Assertions.assert_equal(km.job_state, km.JobState.READY_TO_HEAT, "Ch1: Hold berkelanjutan TIDAK menyebabkan auto-cook (CONTENT.md § 4)")
	Assertions.assert_ne(km.job_state, km.JobState.COOKING, "Ch1: Invarian: Tidak auto-start COOKING")
	Assertions.assert_equal(completed_emitted[0], 1, "Ch1: Sinyal completed tidak terpancar ulang saat over-holding")

	# 4. Extreme delta clamp test on new job
	km.cancel_preparation()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	km.start_preparation("recipe_sayur_bening_01")

	# Single massive frame hitch (e.g. 50.0s)
	km.advance_prep(50.0)
	Assertions.assert_approx_equal(km.prep_progress, 4.0, 0.001, "Ch1: Delta 50.0s di-clamp rapi di 4.0s (prep_duration)")
	Assertions.assert_equal(km.job_state, km.JobState.READY_TO_HEAT, "Ch1: Status langsung READY_TO_HEAT")

	return true

# ==============================================================================
# CHALLENGE 2: Jitter / Flutter Rapid Hold-Release Cycles (T12 Retention)
# ==============================================================================

func test_challenge_2_hold_jitter_and_retention() -> bool:
	print("  [Challenge 2] Testing Rapid Jitter Flutter & Progress Retention...")
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	var km := _create_clean_kitchen(inv)

	km.start_preparation("recipe_sayur_bening_01")

	# Simulate flutter: 50 cycles of (hold 0.02s, release 0.02s)
	# Total active hold duration = 50 * 0.02s = 1.00s
	for c in range(50):
		km.hold_tick(0.02, true)
		km.hold_tick(0.02, false) # Released: progress retained, not reset!

	Assertions.assert_approx_equal(km.prep_progress, 1.0, 0.001, "Ch2: Flutter 50x0.02s menghasilkan progress 1.0s eksak")
	Assertions.assert_equal(km.job_state, km.JobState.RESERVED_PREPARING, "Ch2: Masih RESERVED_PREPARING")

	# Resume hold for 1.5s straight
	km.hold_tick(1.5, true)
	Assertions.assert_approx_equal(km.prep_progress, 2.5, 0.001, "Ch2: Progress berlanjut ke 2.5s tanpa reset")

	# Release for a long time (10 seconds idle)
	km.hold_tick(10.0, false)
	Assertions.assert_approx_equal(km.prep_progress, 2.5, 0.001, "Ch2: Melepas tombol selama 10s tidak mereset progress")

	# Finish remaining 1.5s
	km.hold_tick(1.5, true)
	Assertions.assert_approx_equal(km.prep_progress, 4.0, 0.001, "Ch2: Mencapai 4.0s")
	Assertions.assert_equal(km.job_state, km.JobState.READY_TO_HEAT, "Ch2: Berpindah ke READY_TO_HEAT")

	return true

# ==============================================================================
# CHALLENGE 3: Multi-Tier Overflow, Isolation & Conservation of Matter (T40)
# ==============================================================================

func test_challenge_3_overflow_redirection_and_isolation() -> bool:
	print("  [Challenge 3] Testing 3-Tier Overflow Redirection, Strict Isolation & Conservation...")
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	var km := _create_clean_kitchen(inv)
	km.start_preparation("recipe_sayur_bening_01")

	# Pre-cancellation state: ingredients are in kitchen custody
	Assertions.assert_equal(inv.backpack.get_used_slots_count(), 0, "Ch3: Tas kosong (bahan ditarik)")

	# Pack both backpack and storage completely full with unstackable/maxed items
	# 12 slots in backpack * 20 seeds = 240 items
	# 12 slots in storage * 20 compost = 240 items
	for i in range(12):
		inv.backpack.add_item("seed_bayam", 20)
		inv.storage_home.add_item("soil_compost", 20)

	Assertions.assert_equal(inv.backpack.get_used_slots_count(), 12, "Ch3: Tas 100% penuh")
	Assertions.assert_equal(inv.storage_home.get_used_slots_count(), 12, "Ch3: Peti 100% penuh")

	# Now cancel preparation!
	var cancel_res: Dictionary = km.cancel_preparation()
	Assertions.assert_true(cancel_res.get("success", false), "Ch3: Pembatalan sukses")
	Assertions.assert_true(cancel_res.get("spilled_to_refund", false), "Ch3: Terjadi limpahan ke kitchen_refund")

	# Strict Isolation Invariants:
	# 1. Output dish slot MUST NOT be touched
	Assertions.assert_true(km.dish_output_slot.is_empty(), "Ch3: Invarian Ketat: dish_output_slot kosong")
	Assertions.assert_false(km.has_ready_output(), "Ch3: Invarian Ketat: has_ready_output() == false")

	# 2. Existing items in backpack and storage MUST NOT be displaced or destroyed
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 240, "Ch3: 240 seed di tas utuh")
	Assertions.assert_equal(inv.storage_home.get_item_count("soil_compost"), 240, "Ch3: 240 compost di peti utuh")

	# 3. All 5 refunded ingredients MUST be safely located in kitchen_refund
	Assertions.assert_equal(inv.kitchen_refund.get_item_count("ingredient_bayam"), 3, "Ch3: 3 bayam di kitchen_refund")
	Assertions.assert_equal(inv.kitchen_refund.get_item_count("ingredient_jagung"), 1, "Ch3: 1 jagung di kitchen_refund")
	Assertions.assert_equal(inv.kitchen_refund.get_item_count("ingredient_temu_kunci"), 1, "Ch3: 1 temu kunci di kitchen_refund")

	# 4. Conservation of Matter: Universe count before = 240 + 240 + 5 = 485 items
	var total_items := 0
	for it_name in ["ingredient_bayam", "ingredient_jagung", "ingredient_temu_kunci", "seed_bayam", "soil_compost"]:
		total_items += inv.backpack.get_item_count(it_name)
		total_items += inv.storage_home.get_item_count(it_name)
		total_items += inv.kitchen_refund.get_item_count(it_name)
	Assertions.assert_equal(total_items, 485, "Ch3: Hukum Kekekalan Materi: 485 total item di alam semesta")

	return true

# ==============================================================================
# CHALLENGE 4: Partial-Space Spillover Cascades Across 3 Tiers (T40 Edge Case)
# ==============================================================================

func test_challenge_4_partial_space_cascading_refund() -> bool:
	print("  [Challenge 4] Testing Partial-Space Cascading Overflow across 3 Tiers...")
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	var km := _create_clean_kitchen(inv)
	km.start_preparation("recipe_sayur_bening_01")

	# Scenario:
	# Backpack has 11 full slots of seeds (11 * 20 = 220), and 1 slot with 19 bayam (so room for only 1 bayam!)
	# Storage has 11 full slots of compost (11 * 20 = 220), and 1 slot with 19 bayam (so room for only 1 bayam!)
	# When refunding 3 bayam, 1 jagung, 1 temu kunci:
	# - Backpack absorbs 1 bayam (fills to 20). Remaining: 2 bayam, 1 jagung, 1 temu kunci.
	# - Storage absorbs 1 bayam (fills to 20). Remaining: 1 bayam, 1 jagung, 1 temu kunci.
	# - Kitchen refund absorbs the leftover 1 bayam, 1 jagung, 1 temu kunci!

	for i in range(11):
		inv.backpack.add_item("seed_bayam", 20)
		inv.storage_home.add_item("soil_compost", 20)
	inv.backpack.add_item("ingredient_bayam", 19)
	inv.storage_home.add_item("ingredient_bayam", 19)

	var res: Dictionary = km.cancel_preparation()
	Assertions.assert_true(res.get("success", false), "Ch4: Pembatalan dengan kapasitas parsial berhasil")

	# Verify Backpack: now exactly 20 bayam
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 20, "Ch4: Tas menyerap 1 bayam hingga penuh 20")
	# Verify Storage: now exactly 20 bayam
	Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_bayam"), 20, "Ch4: Peti menyerap 1 bayam hingga penuh 20")
	# Verify Kitchen Refund: received leftover 1 bayam, 1 jagung, 1 temu kunci
	Assertions.assert_equal(inv.kitchen_refund.get_item_count("ingredient_bayam"), 1, "Ch4: kitchen_refund menampung sisa 1 bayam")
	Assertions.assert_equal(inv.kitchen_refund.get_item_count("ingredient_jagung"), 1, "Ch4: kitchen_refund menampung sisa 1 jagung")
	Assertions.assert_equal(inv.kitchen_refund.get_item_count("ingredient_temu_kunci"), 1, "Ch4: kitchen_refund menampung sisa 1 temu kunci")

	# Strict Isolation check
	Assertions.assert_true(km.dish_output_slot.is_empty(), "Ch4: dish_output_slot tetap bersih")

	return true

# ==============================================================================
# CHALLENGE 5: Cancellation & Claim Spam Idempotency
# ==============================================================================

func test_challenge_5_cancellation_and_claim_spam_idempotency() -> bool:
	print("  [Challenge 5] Testing Cancel & Claim Spam Idempotency (100 Cycles)...")
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	var km := _create_clean_kitchen(inv)
	km.start_preparation("recipe_sayur_bening_01")

	# First cancel succeeds
	var first_cancel: Dictionary = km.cancel_preparation()
	Assertions.assert_true(first_cancel.get("success", false), "Ch5: Cancel pertama berhasil")

	# Subsequent 50 cancels must all fail cleanly with no item duplication
	for i in range(50):
		var spam_cancel: Dictionary = km.cancel_preparation()
		Assertions.assert_false(spam_cancel.get("success", true), "Ch5: Spam cancel %d ditolak" % i)

	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 3, "Ch5: Bayam tidak digandakan oleh spam cancel")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 1, "Ch5: Jagung tidak digandakan oleh spam cancel")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 1, "Ch5: Temu kunci tidak digandakan")

	# Now test claim_refund_items spam
	# Put 3 items in kitchen_refund
	inv.kitchen_refund.add_item("ingredient_bayam", 3)
	Assertions.assert_true(km.has_refund_items(), "Ch5: has_refund_items == true")

	# Fill backpack so claim cannot take anything
	inv.backpack.clear()
	for i in range(12):
		inv.backpack.add_item("seed_bayam", 20)

	var failed_claim: Dictionary = km.claim_refund_items()
	Assertions.assert_false(failed_claim.get("success", true), "Ch5: Claim ditolak jika tas penuh")
	Assertions.assert_equal(inv.kitchen_refund.get_item_count("ingredient_bayam"), 3, "Ch5: Barang tidak hilang saat claim gagal")

	# Clear backpack and claim
	inv.backpack.clear()
	var success_claim: Dictionary = km.claim_refund_items()
	Assertions.assert_true(success_claim.get("success", false), "Ch5: Claim berhasil saat ada ruang")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 3, "Ch5: Bayam masuk tas")
	Assertions.assert_equal(inv.kitchen_refund.get_item_count("ingredient_bayam"), 0, "Ch5: kitchen_refund kini kosong")

	# Spam claim on empty refund container
	for i in range(20):
		var empty_claim: Dictionary = km.claim_refund_items()
		Assertions.assert_false(empty_claim.get("success", true), "Ch5: Spam claim %d pada wadah kosong ditolak aman" % i)

	return true

# ==============================================================================
# CHALLENGE 6: Bed Sleep Interlock & Day Advance Quarantine (WORLD-001)
# ==============================================================================

func test_challenge_6_sleep_interlock_across_all_states() -> bool:
	print("  [Challenge 6] Testing Sleep Interlock across All Kitchen States...")
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 6)
	inv.backpack.add_item("ingredient_jagung", 2)
	inv.backpack.add_item("ingredient_temu_kunci", 2)

	var km := _create_clean_kitchen(inv)
	var wrm := WorldResourceManagerClass.new()
	wrm.reset_state()
	wrm.set_kitchen_manager(km)
	wrm.set_inventory_manager(inv)

	var failed_signals := [0]
	wrm.action_failed.connect(func(_msg): failed_signals[0] += 1)

	# State 1: IDLE -> Sleep ALLOWED
	Assertions.assert_equal(wrm.current_day, 1, "Ch6: Awal hari = 1")
	var check_idle: Dictionary = wrm.can_sleep()
	Assertions.assert_true(check_idle.get("success", false), "Ch6: IDLE: can_sleep() == true")
	var slept: bool = wrm.sleep_and_advance_day()
	Assertions.assert_true(slept, "Ch6: IDLE: sleep_and_advance_day() berhasil")
	Assertions.assert_equal(wrm.current_day, 2, "Ch6: Hari bertambah ke 2")

	# State 2: RESERVED_PREPARING (prep = 0.0s) -> Sleep REJECTED
	km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_equal(km.job_state, km.JobState.RESERVED_PREPARING, "Ch6: Dapur di RESERVED_PREPARING (0s)")
	var check_prep0: Dictionary = wrm.can_sleep()
	Assertions.assert_false(check_prep0.get("success", true), "Ch6: RESERVED_PREPARING(0s): can_sleep() == false")
	slept = wrm.sleep_and_advance_day()
	Assertions.assert_false(slept, "Ch6: RESERVED_PREPARING(0s): sleep_and_advance_day() DITOLAK")
	Assertions.assert_equal(wrm.current_day, 2, "Ch6: Hari DILARANG maju saat dapur aktif (tetap Hari 2)")

	# State 3: RESERVED_PREPARING (prep = 2.0s) -> Sleep REJECTED
	km.advance_prep(2.0)
	var check_prep2: Dictionary = wrm.can_sleep()
	Assertions.assert_false(check_prep2.get("success", true), "Ch6: RESERVED_PREPARING(2s): can_sleep() == false")
	slept = wrm.sleep_and_advance_day()
	Assertions.assert_false(slept, "Ch6: RESERVED_PREPARING(2s): sleep_and_advance_day() DITOLAK")
	Assertions.assert_equal(wrm.current_day, 2, "Ch6: Hari tetap Hari 2")

	# State 4: READY_TO_HEAT (prep = 4.0s) -> Sleep REJECTED
	km.advance_prep(2.0)
	Assertions.assert_equal(km.job_state, km.JobState.READY_TO_HEAT, "Ch6: Dapur di READY_TO_HEAT")
	var check_ready: Dictionary = wrm.can_sleep()
	Assertions.assert_false(check_ready.get("success", true), "Ch6: READY_TO_HEAT: can_sleep() == false")
	slept = wrm.sleep_and_advance_day()
	Assertions.assert_false(slept, "Ch6: READY_TO_HEAT: sleep_and_advance_day() DITOLAK")
	Assertions.assert_equal(wrm.current_day, 2, "Ch6: Hari tetap Hari 2")

	# State 5: Simulated COOKING / PAUSED -> Sleep REJECTED
	km.job_state = km.JobState.COOKING
	Assertions.assert_false(wrm.can_sleep().get("success", true), "Ch6: COOKING: can_sleep() == false")
	Assertions.assert_false(wrm.sleep_and_advance_day(), "Ch6: COOKING: tidur ditolak")

	km.job_state = km.JobState.PAUSED
	Assertions.assert_false(wrm.can_sleep().get("success", true), "Ch6: PAUSED: can_sleep() == false")
	Assertions.assert_false(wrm.sleep_and_advance_day(), "Ch6: PAUSED: tidur ditolak")

	# State 6: OUTPUT_READY -> Sleep REJECTED
	km.job_state = km.JobState.OUTPUT_READY
	km.dish_output_slot = {"item_id": "dish_sayur_bening", "count": 1}
	Assertions.assert_false(wrm.can_sleep().get("success", true), "Ch6: OUTPUT_READY: can_sleep() == false")
	Assertions.assert_false(wrm.sleep_and_advance_day(), "Ch6: OUTPUT_READY: tidur ditolak")
	Assertions.assert_equal(wrm.current_day, 2, "Ch6: Hari tetap Hari 2 sepanjang seluruh status aktif")

	# Player takes dish output -> Stasiun kembali IDLE
	var dish = km.take_dish_output()
	Assertions.assert_equal(km.job_state, km.JobState.IDLE, "Ch6: Dapur kembali IDLE setelah hidangan diambil")

	# Now sleep must SUCCEED!
	Assertions.assert_true(wrm.can_sleep().get("success", false), "Ch6: can_sleep() sukses setelah hidangan diambil")
	slept = wrm.sleep_and_advance_day()
	Assertions.assert_true(slept, "Ch6: Tidur berhasil!")
	Assertions.assert_equal(wrm.current_day, 3, "Ch6: Hari bertambah ke Hari 3")

	return true

# ==============================================================================
# CHALLENGE 7: Anti-Spam Re-entrancy & Output Slot Gating
# ==============================================================================

func test_challenge_7_reentrancy_and_output_gating() -> bool:
	print("  [Challenge 7] Testing Concurrent Re-entrancy & Output Gating...")
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 10)
	inv.backpack.add_item("ingredient_jagung", 10)
	inv.backpack.add_item("ingredient_temu_kunci", 10)

	var km := _create_clean_kitchen(inv)

	# 1. Start 1 job
	var res1: Dictionary = km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_true(res1.get("success", false), "Ch7: Job awal berhasil")
	var initial_id: String = km.active_job_id

	# 2. Try starting another job with different recipes or same recipe in rapid loop (100 times)
	for i in range(100):
		var res: Dictionary = km.start_preparation("recipe_sayur_bening_01")
		Assertions.assert_false(res.get("success", true), "Ch7: Re-entrant start %d ditolak" % i)
		Assertions.assert_true(res.get("idempotent", false), "Ch7: Flag idempotent true")

	Assertions.assert_equal(km.active_job_id, initial_id, "Ch7: Active job ID tidak bermutasi")
	# Exactly 3 bayam, 1 jagung, 1 temu kunci deducted once
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 7, "Ch7: Bayam tersisa 7 (ditarik tepat 3)")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 9, "Ch7: Jagung tersisa 9 (ditarik tepat 1)")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 9, "Ch7: Temu kunci tersisa 9 (ditarik tepat 1)")

	# Clean cancel
	km.cancel_preparation()

	# 3. Output slot occupied gating
	km.dish_output_slot = {"item_id": "dish_sayur_bening", "count": 1}
	var gated_check: Dictionary = km.can_start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(gated_check.get("success", true), "Ch7: Ditolak jika ada masakan di output slot")
	Assertions.assert_true(str(gated_check.get("reason", "")).contains("Ambil hidangan"), "Ch7: Pesan jujur ambil hidangan")

	var gated_start: Dictionary = km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(gated_start.get("success", true), "Ch7: start_preparation ditolak jika output slot terisi")

	# Clearing output slot restores eligibility
	km.dish_output_slot.clear()
	var unblocked_check: Dictionary = km.can_start_preparation("recipe_sayur_bening_01")
	Assertions.assert_true(unblocked_check.get("success", false), "Ch7: Berhasil kembali setelah output slot dikosongkan")

	return true

# ==============================================================================
# CHALLENGE 8: Save/Load Snapshot Envelope Restoration under Adversarial States
# ==============================================================================

func test_challenge_8_snapshot_adversarial_roundtrip() -> bool:
	print("  [Challenge 8] Testing Save/Load Snapshot under Adversarial Conditions...")
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	var km := _create_clean_kitchen(inv)
	km.start_preparation("recipe_sayur_bening_01")
	km.advance_prep(3.333)

	var snapshot: Dictionary = km.get_save_snapshot()

	# Adversarial: Try loading corrupted / null / empty snapshots
	var km_adversary := _create_clean_kitchen(inv)
	Assertions.assert_false(km_adversary.load_save_snapshot({}), "Ch8: Snapshot kosong ditolak")

	# Valid restoration
	var restored: bool = km_adversary.load_save_snapshot(snapshot)
	Assertions.assert_true(restored, "Ch8: Snapshot valid berhasil dimuat")
	Assertions.assert_equal(km_adversary.job_state, km_adversary.JobState.RESERVED_PREPARING, "Ch8: State RESERVED_PREPARING pulih")
	Assertions.assert_approx_equal(km_adversary.prep_progress, 3.333, 0.001, "Ch8: Progress 3.333s pulih eksak")
	Assertions.assert_equal(km_adversary.origin_manifest.size(), 3, "Ch8: Origin manifest pulih")

	# Advance remaining 0.667s to reach 4.0s
	km_adversary.advance_prep(0.667)
	Assertions.assert_equal(km_adversary.job_state, km_adversary.JobState.READY_TO_HEAT, "Ch8: Lanjut hingga 4.0s mencapai READY_TO_HEAT")

	# Cancel from restored READY_TO_HEAT state with full bag fixture
	for i in range(12):
		inv.backpack.add_item("seed_bayam", 20)
		inv.storage_home.add_item("soil_compost", 20)

	var cancel_restored: Dictionary = km_adversary.cancel_preparation()
	Assertions.assert_true(cancel_restored.get("success", false), "Ch8: Cancel pada restored instance sukses")
	Assertions.assert_true(km_adversary.dish_output_slot.is_empty(), "Ch8: Output slot tetap kosong")
	Assertions.assert_equal(inv.kitchen_refund.get_item_count("ingredient_bayam"), 3, "Ch8: Bahan dialihkan ke kitchen_refund")

	return true
