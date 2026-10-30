## tests/tools/adversarial_qa_oracle.gd
## Empirical Adversarial Challenger & Invariants / Anti-Softlock Stress Oracle for QA-001
##
## Evaluates:
## 1. ADV-QA-01: Empirical Matter Conservation & Permutation Invariance Oracle (QA-04 Stress)
##    - Multi-container split (backpack + storage_home)
##    - Rapid 50x cancellation and restoration idempotency
##    - 3-tier safe refund to kitchen_refund storage on saturated inventory
##    - Output claim rejection on full backpack & zero-duplication on double claim
##    - Closed-system matter balance: 12 entered, 7 consumed, exactly 5 physical items remain
## 2. ADV-QA-02: Anti-Softlock & Input Context Stack Freedom Oracle (QA-05 Stress)
##    - 500 randomized modal pushes/pops across BOOK, STORAGE, KITCHEN, DIALOGUE, PAUSE
##    - Stack underflow immunity (50x pop at WORLD keeps depth=1 and movement enabled)
##    - 30-level corrupted/nested stack instant recovery via pop_to_world()
##    - Ghost/freed player resilience and input gating synchronization
## 3. ADV-QA-03: Abnormal Player Sequences & Edge Case Stress
##    - Day-lock foraging spam (25x consecutive harvests rejected on locked day)
##    - Sleep / day advance inhibition during active kitchen states (PREPARING, COOKING, PAUSED, OUTPUT_READY)
##    - Ripe crop harvesting rejection on 100% full backpack (zero crop loss guarantee)
##    - Invalid garden sequences (occupied spot, unhoed soil, uncomposted soil, 0 seeds)
##    - Boundary watering/fertilizing guards (empty can, full can, threshold limits)
##    - Meal sharing rejection with 0 dishes

extends SceneTree

const Assertions = preload("res://tests/assertions.gd")
const MainClass = preload("res://scripts/main.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const RecipeManagerClass = preload("res://scripts/recipe/recipe_manager.gd")
const GardenManagerClass = preload("res://scripts/gardening/garden_manager.gd")
const WorldResourceManagerClass = preload("res://scripts/world/world_resource_manager.gd")
const KitchenManagerClass = preload("res://scripts/cooking/kitchen_manager.gd")
const DialogueManagerClass = preload("res://scripts/social/dialogue_manager.gd")
const SaveManagerClass = preload("res://scripts/save/save_manager.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")

var _passed: int = 0
var _failed: int = 0

func _initialize() -> void:
	await process_frame
	print("\n==================================================")
	print("[ADVERSARIAL_QA_ORACLE] Invariants & Anti-Softlock Challenger (QA-001)")
	print("==================================================")

	var ok := true
	if not await test_adv_qa_01_matter_conservation_and_permutations():
		ok = false
	if not await test_adv_qa_02_anti_softlock_and_input_stack_freedom():
		ok = false
	if not await test_adv_qa_03_abnormal_player_sequences():
		ok = false

	print("\n==================================================")
	print("[ADVERSARIAL_QA_ORACLE] SUMMARY:")
	print("  Passed Assertions: %d" % _passed)
	print("  Failed Assertions: %d" % _failed)
	print("  Verdict: %s" % ("ALL TESTS PASSED" if (_failed == 0 and ok) else "TEST FAILURES DETECTED"))
	print("==================================================")

	quit(1 if _failed > 0 or not ok else 0)

# ==============================================================================
# ASSERTION HELPERS (Self-tracking)
# ==============================================================================

func _check(condition: bool, msg: String) -> bool:
	if condition:
		_passed += 1
		return true
	else:
		_failed += 1
		push_error("FAIL: %s" % msg)
		print("  [FAIL] %s" % msg)
		return false

func _check_eq(actual, expected, msg: String) -> bool:
	if actual == expected:
		_passed += 1
		return true
	else:
		_failed += 1
		var err := "FAIL %s: expected %s, got %s" % [msg, str(expected), str(actual)]
		push_error(err)
		print("  [FAIL] %s" % err)
		return false

func _check_approx(actual: float, expected: float, tol: float, msg: String) -> bool:
	if absf(actual - expected) <= tol:
		_passed += 1
		return true
	else:
		_failed += 1
		var err := "FAIL %s: expected %f (+/-%f), got %f" % [msg, expected, tol, actual]
		push_error(err)
		print("  [FAIL] %s" % err)
		return false

func _count_container_items(c) -> int:
	if c == null:
		return 0
	var sum := 0
	for s in c.slots:
		if s != null and not s.is_empty():
			sum += int(s.count)
	return sum

# ==============================================================================
# ENVIRONMENT SETUP & RESET HELPERS
# ==============================================================================

func _get_autoload(name: String) -> Node:
	if root != null and root.has_node(name):
		return root.get_node(name)
	return null

func _clean_root_orphans() -> void:
	var autoloads = [
		"InputManager", "InventoryManager", "RecipeManager",
		"GardenManager", "WorldResourceManager", "KitchenManager",
		"DialogueManager", "SaveManager", "AudioManager"
	]
	for child in root.get_children():
		if child != null and not child.name in autoloads and not child.name.begins_with("@"):
			root.remove_child(child)
			child.free()

func _reset_all_managers() -> void:
	_clean_root_orphans()

	var inv = _get_autoload("InventoryManager")
	if inv != null:
		inv.backpack.clear()
		inv.storage_home.clear()
		inv.kitchen_refund.clear()
		inv.starter_claimed = false
		inv._reservations.clear()
		inv.inventory_updated.emit()

	var rm = _get_autoload("RecipeManager")
	if rm != null:
		rm.untrack_recipe()
		rm.set_cooking_state("idle")
		for r in rm.get_all_recipes():
			r.is_tracked = false
			r.times_cooked = 0
		rm._notes.clear()
		rm._register_default_notes()
		if inv != null:
			rm.set_inventory_manager(inv)

	var gm = _get_autoload("GardenManager")
	if gm != null:
		gm.reset_to_defaults()
		gm.active_tool = gm.TOOL_NONE
		gm.watering_can_water = 0
		if inv != null:
			gm.set_inventory_manager(inv)

	var wrm = _get_autoload("WorldResourceManager")
	if wrm != null:
		wrm.current_day = 1
		wrm.day_active_time = 0.0
		wrm.meal_used = false
		wrm.last_harvested_day = {
			"resource_jagung_01": 0,
			"resource_temu_kunci_01": 0
		}
		wrm.foraging_nodes_refreshed.emit()
		if inv != null:
			wrm.set_inventory_manager(inv)

	var km = _get_autoload("KitchenManager")
	if km != null:
		km.active_job_id = ""
		km.active_recipe_id = ""
		km.job_state = km.JobState.IDLE
		km.current_heat_level = km.HeatLevel.LOW
		km.cook_progress = 0.0
		km.prep_progress = 0.0
		km.meal_used = false
		km.p0_completed = false
		km.reserved_ingredients.clear()
		km.origin_manifest.clear()
		km.dish_output_slot.clear()
		km.current_job.clear()
		if inv != null:
			km.set_inventory_manager(inv)

	var dm = _get_autoload("DialogueManager")
	var im = _get_autoload("InputManager")
	if dm != null:
		dm.reset_state()
		dm.close_dialogue()
		dm.bind_managers(inv, rm, wrm, km, im)

	if im != null:
		im.pop_to_world()

func _create_test_main() -> Node:
	var scene_res = ResourceLoader.load("res://scenes/main.tscn") as PackedScene
	if scene_res == null:
		return null
	var main = scene_res.instantiate()
	root.add_child(main)
	return main

func _free_test_main(main: Node) -> void:
	if main == null:
		return
	if main.get_parent() != null:
		main.get_parent().remove_child(main)
	main.free()

# ==============================================================================
# TEST 1: Matter Conservation & Permutation Invariance Oracle (QA-04 Stress)
# ==============================================================================

func test_adv_qa_01_matter_conservation_and_permutations() -> bool:
	print("\n--- [CHALLENGE 1] ADV-QA-01: Empirical Matter Conservation & Permutation Invariance Oracle ---")
	var start_fails = _failed

	_reset_all_managers()
	var inv = _get_autoload("InventoryManager") as InventoryManagerClass
	var rm = _get_autoload("RecipeManager") as RecipeManagerClass
	var gm = _get_autoload("GardenManager") as GardenManagerClass
	var wrm = _get_autoload("WorldResourceManager") as WorldResourceManagerClass
	var km = _get_autoload("KitchenManager") as KitchenManagerClass
	var dm = _get_autoload("DialogueManager") as DialogueManagerClass

	# STEP 1.1: Inflow Phase (Total 12 physical items enter closed system)
	# 1. Starter container pickup (+4 seeds, +1 compost, +1 fertilizer = 6 items)
	var starter_ok: bool = inv.pickup_starter_container()
	_check(starter_ok, "ADV-QA-01: Starter container claimed")
	_check_eq(inv.backpack.get_item_count("seed_bayam"), 4, "ADV-QA-01: Backpack has 4 seeds")
	_check_eq(inv.backpack.get_item_count("soil_compost"), 1, "ADV-QA-01: Backpack has 1 compost")
	_check_eq(inv.backpack.get_item_count("fertilizer_basic"), 1, "ADV-QA-01: Backpack has 1 fertilizer")

	# 2. Garden plot cultivation & 4-spot harvest
	# Apply compost & fertilizer (2 consumed into soil)
	gm.hoe_plot("plot_home_01")
	var comp_ok = gm.add_compost("plot_home_01")
	_check(comp_ok, "ADV-QA-01: Compost applied to plot")
	var fert_ok = gm.fertilize_plot("plot_home_01")
	_check(fert_ok, "ADV-QA-01: Fertilizer applied to plot")
	gm.refill_water()
	gm.water_plot("plot_home_01")

	# Plant 4 seeds
	for i in range(1, 5):
		var planted = gm.plant_seed("plot_home_01", "slot_%02d" % i, "seed_bayam")
		_check(planted, "ADV-QA-01: Seed planted in slot_%02d" % i)

	# Simulate growth to maturity (185s)
	gm._simulate_plot_growth("plot_home_01", 185.0)

	# Harvest all 4 spots (+4 spinach, +4 seeds)
	for i in range(1, 5):
		var harvested = gm.harvest_crop("plot_home_01", "slot_%02d" % i)
		_check(harvested, "ADV-QA-01: Crop harvested from slot_%02d" % i)

	# 3. Wild foraging (+1 corn, +1 temu kunci)
	var corn_ok = wrm.harvest_foraging("resource_jagung_01")
	_check(corn_ok, "ADV-QA-01: Corn foraged")
	var temu_ok = wrm.harvest_foraging("resource_temu_kunci_01")
	_check(temu_ok, "ADV-QA-01: Temu kunci foraged")

	# Net check: Inflow = 12, Consumed to soil = 2, In-hand items = 10
	var current_total: int = inv.backpack.get_item_count("ingredient_bayam") + \
		inv.backpack.get_item_count("seed_bayam") + \
		inv.backpack.get_item_count("ingredient_jagung") + \
		inv.backpack.get_item_count("ingredient_temu_kunci")
	_check_eq(current_total, 10, "ADV-QA-01: Current total physical items in-hand = 10")

	# --------------------------------------------------------------------------
	# SUB-TEST 1.2: Multi-Container Split & Cross-Container Reservation Permutation
	# --------------------------------------------------------------------------
	# Transfer 2 spinach and 1 corn into storage_home (peti rumah)
	var bayam_slot := -1
	var jagung_slot := -1
	for idx in range(inv.backpack.slots.size()):
		var s = inv.backpack.slots[idx]
		if s.item_id == "ingredient_bayam" and bayam_slot == -1:
			bayam_slot = idx
		elif s.item_id == "ingredient_jagung" and jagung_slot == -1:
			jagung_slot = idx

	var t1 = inv.transfer_item("backpack", "storage", bayam_slot, 2)
	_check(t1, "ADV-QA-01: Transferred 2 bayam to chest")
	var t2 = inv.transfer_item("backpack", "storage", jagung_slot, 1)
	_check(t2, "ADV-QA-01: Transferred 1 jagung to chest")

	# Verify split:
	# Backpack: 2 bayam, 0 jagung, 1 temu kunci, 4 seeds (7 items)
	# Storage: 2 bayam, 1 jagung (3 items)
	_check_eq(inv.backpack.get_item_count("ingredient_bayam"), 2, "ADV-QA-01: Backpack bayam = 2")
	_check_eq(inv.storage_home.get_item_count("ingredient_bayam"), 2, "ADV-QA-01: Storage bayam = 2")
	_check_eq(inv.storage_home.get_item_count("ingredient_jagung"), 1, "ADV-QA-01: Storage jagung = 1")
	_check_eq(inv.backpack.get_item_count("ingredient_temu_kunci"), 1, "ADV-QA-01: Backpack temu kunci = 1")

	# RecipeManager can see across containers
	_check(rm.can_cook_recipe("recipe_sayur_bening_01"), "ADV-QA-01: Can cook across containers")

	# Reserve ingredients (needs 3 bayam, 1 corn, 1 temu kunci)
	# Will draw 2 bayam from backpack + 1 bayam from storage, 1 corn from storage, 1 temu kunci from backpack
	var prep_res = km.start_preparation("recipe_sayur_bening_01")
	_check(prep_res.get("success", false), "ADV-QA-01: Cross-container start_preparation succeeded")

	# --------------------------------------------------------------------------
	# SUB-TEST 1.3: 50x Rapid Cancellation & Restoration Idempotency Stress
	# --------------------------------------------------------------------------
	for cancel_iter in range(50):
		var cancel_res = km.cancel_preparation()
		_check(cancel_res.get("success", false), "ADV-QA-01: Iter %d: cancel_preparation succeeded" % cancel_iter)

		# Verify total items across all containers still exactly 10
		var total_check: int = inv.backpack.get_item_count("ingredient_bayam") + \
			inv.storage_home.get_item_count("ingredient_bayam") + \
			inv.backpack.get_item_count("ingredient_jagung") + \
			inv.storage_home.get_item_count("ingredient_jagung") + \
			inv.backpack.get_item_count("ingredient_temu_kunci") + \
			inv.storage_home.get_item_count("ingredient_temu_kunci") + \
			inv.backpack.get_item_count("seed_bayam") + \
			_count_container_items(inv.kitchen_refund)
		_check_eq(total_check, 10, "ADV-QA-01: Iter %d: Matter strictly invariant at 10 items" % cancel_iter)

		# Re-reserve for next iteration
		if cancel_iter < 49:
			var re_prep = km.start_preparation("recipe_sayur_bening_01")
			_check(re_prep.get("success", false), "ADV-QA-01: Iter %d: re-preparation succeeded" % cancel_iter)

	# --------------------------------------------------------------------------
	# SUB-TEST 1.4: Saturated Inventory & 3-Tier Safe Refund Storage Spilling
	# --------------------------------------------------------------------------
	# Now start preparation again so 5 ingredients are reserved
	km.start_preparation("recipe_sayur_bening_01")
	_check_eq(km.job_state, km.JobState.RESERVED_PREPARING, "ADV-QA-01: Preparation active")

	# Save legitimate unreserved items currently in containers:
	var saved_unreserved_bayam_bp: int = int(inv.backpack.get_item_count("ingredient_bayam"))
	var saved_unreserved_bayam_st: int = int(inv.storage_home.get_item_count("ingredient_bayam"))
	var saved_unreserved_seeds: int = int(inv.backpack.get_item_count("seed_bayam"))

	# Completely saturate both backpack and storage_home with dummy distinct slots
	var bp_c = inv.backpack
	var st_c = inv.storage_home
	bp_c.clear()
	for i in range(12):
		bp_c.slots[i].set("item_id", "dummy_bp_%d" % i)
		bp_c.slots[i].set("count", 1)
	bp_c.contents_changed.emit()

	st_c.clear()
	for i in range(12):
		st_c.slots[i].set("item_id", "dummy_st_%d" % i)
		st_c.slots[i].set("count", 1)
	st_c.contents_changed.emit()

	_check_eq(bp_c.get_used_slots_count(), 12, "ADV-QA-01: Backpack is 100% full (12/12 slots)")
	_check_eq(st_c.get_used_slots_count(), 12, "ADV-QA-01: Storage is 100% full (12/12 slots)")

	# Now CANCEL preparation when neither backpack nor storage can accept the returned items!
	var saturated_cancel = km.cancel_preparation()
	_check(saturated_cancel.get("success", false), "ADV-QA-01: Cancellation succeeded despite saturated containers")
	_check(saturated_cancel.get("spilled_to_refund", false), "ADV-QA-01: Refund spilled to kitchen_refund storage")

	# Verify ALL 5 reserved ingredients were diverted into kitchen_refund without any loss!
	var refund_c = inv.kitchen_refund
	var refund_count: int = _count_container_items(refund_c)
	_check_eq(refund_count, 5, "ADV-QA-01: All 5 reserved ingredients safely preserved in kitchen_refund")

	# Clear out the dummy items and restore the unreserved items
	bp_c.clear()
	st_c.clear()
	bp_c.add_item("ingredient_bayam", saved_unreserved_bayam_bp)
	st_c.add_item("ingredient_bayam", saved_unreserved_bayam_st)
	bp_c.add_item("seed_bayam", saved_unreserved_seeds)

	# Claim refund back into backpack
	var claim_rf = km.claim_refund_items()
	_check(claim_rf.get("success", false), "ADV-QA-01: Successfully claimed refund back into backpack")
	_check_eq(_count_container_items(refund_c), 0, "ADV-QA-01: kitchen_refund is now empty")

	# Consolidate ingredients back into backpack
	inv.transfer_all("storage", "backpack")
	var consolidated_total: int = inv.backpack.get_item_count("ingredient_bayam") + \
		inv.backpack.get_item_count("ingredient_jagung") + \
		inv.backpack.get_item_count("ingredient_temu_kunci") + \
		inv.backpack.get_item_count("seed_bayam")
	_check_eq(consolidated_total, 10, "ADV-QA-01: Exactly 10 items in backpack after refund & consolidation")

	# --------------------------------------------------------------------------
	# SUB-TEST 1.5: Output Claim Rejection on Full Backpack & Double-Claim Anti-Duplication
	# --------------------------------------------------------------------------
	# Start preparation, advance 4s prep, cook 30s
	km.start_preparation("recipe_sayur_bening_01")
	km.advance_prep(4.0)
	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(30.0)
	_check_eq(km.job_state, km.JobState.OUTPUT_READY, "ADV-QA-01: Dish cooking complete -> OUTPUT_READY")

	# Save legitimate items in backpack (1 bayam, 4 seeds)
	var pre_claim_bayam: int = int(bp_c.get_item_count("ingredient_bayam"))
	var pre_claim_seeds: int = int(bp_c.get_item_count("seed_bayam"))

	# Saturate backpack to 12 slots with dummy items
	bp_c.clear()
	for i in range(12):
		bp_c.slots[i].set("item_id", "dummy_bp_%d" % i)
		bp_c.slots[i].set("count", 1)
	bp_c.contents_changed.emit()

	# Attempt to claim dish output with 100% full backpack
	var full_claim = km.claim_dish_output()
	_check_eq(full_claim.get("success", true), false, "ADV-QA-01: Claim output safely rejected when backpack full")
	_check_eq(km.job_state, km.JobState.OUTPUT_READY, "ADV-QA-01: Dish remains in output slot (not deleted)")
	_check_eq(km.has_ready_output(), true, "ADV-QA-01: Dish output slot still holds ready dish")

	# Clear backpack, restore legitimate items (1 bayam, 4 seeds), leaving 10 slots free
	bp_c.clear()
	bp_c.add_item("ingredient_bayam", pre_claim_bayam)
	bp_c.add_item("seed_bayam", pre_claim_seeds)

	# Claim output now succeeds
	var valid_claim = km.claim_dish_output()
	_check(valid_claim.get("success", false), "ADV-QA-01: Claim output succeeded after freeing slot")
	_check_eq(inv.backpack.get_item_count("dish_sayur_bening"), 1, "ADV-QA-01: Exactly 1 dish received")

	# ATTEMPT DOUBLE CLAIM (ANTI-DUPLICATION)
	var double_claim = km.claim_dish_output()
	_check_eq(double_claim.get("success", true), false, "ADV-QA-01: Second claim rejected (zero duplication)")
	_check_eq(inv.backpack.get_item_count("dish_sayur_bening"), 1, "ADV-QA-01: Dish count strictly remains 1")

	# --------------------------------------------------------------------------
	# SUB-TEST 1.6: Final P0 Meal Sharing & Closed-System Zero-Loss Invariant
	# --------------------------------------------------------------------------
	dm.start_dialogue("npc_neighbor_01")
	dm.select_choice("choice_share")
	var share_res = dm.select_choice("choice_share_confirm")
	_check(share_res.get("success", false), "ADV-QA-01: Meal shared with neighbor")
	dm.close_dialogue()

	# FINAL PHYSICAL MATTER BALANCE:
	# Bayam: 4 harvested - 3 cooked = exactly 1 remaining
	# Benih Bayam: 4 starter - 4 planted + 4 harvested = exactly 4 remaining
	# Jagung: 1 foraged - 1 cooked = exactly 0 remaining
	# Temu Kunci: 1 foraged - 1 cooked = exactly 0 remaining
	# Dish: 1 cooked - 1 shared = exactly 0 remaining
	# Total remaining items in physical containers = exactly 5 items
	_check_eq(inv.backpack.get_item_count("ingredient_bayam"), 1, "ADV-QA-01: Exactly 1 fresh bayam remains")
	_check_eq(inv.backpack.get_item_count("seed_bayam"), 4, "ADV-QA-01: Exactly 4 bayam seeds remain")
	_check_eq(inv.backpack.get_item_count("ingredient_jagung"), 0, "ADV-QA-01: Exactly 0 jagung remains")
	_check_eq(inv.backpack.get_item_count("ingredient_temu_kunci"), 0, "ADV-QA-01: Exactly 0 temu kunci remains")
	_check_eq(inv.backpack.get_item_count("dish_sayur_bening"), 0, "ADV-QA-01: Exactly 0 dish remains")
	_check_eq(_count_container_items(inv.storage_home), 0, "ADV-QA-01: Storage chest is empty")
	_check_eq(_count_container_items(inv.kitchen_refund), 0, "ADV-QA-01: Kitchen refund storage is empty")

	var final_matter_sum: int = _count_container_items(inv.backpack) + \
		_count_container_items(inv.storage_home) + \
		_count_container_items(inv.kitchen_refund)
	_check_eq(final_matter_sum, 5, "ADV-QA-01: Total physical matter = EXACTLY 5 (12 in - 7 consumed = 5)")

	var passed = (_failed == start_fails)
	if passed:
		print("  [PASS] ADV-QA-01: Matter Conservation & Permutation Invariance Oracle verified 100%.")
	return passed

# ==============================================================================
# TEST 2: Anti-Softlock & Input Context Stack Freedom Oracle (QA-05 Stress)
# ==============================================================================

func test_adv_qa_02_anti_softlock_and_input_stack_freedom() -> bool:
	print("\n--- [CHALLENGE 2] ADV-QA-02: Anti-Softlock & Input Context Stack Freedom Oracle ---")
	var start_fails = _failed

	_reset_all_managers()
	var main = _create_test_main()
	await process_frame

	var im = _get_autoload("InputManager") as InputManagerClass
	var player = main.get_node_or_null("Player") as CharacterBody3D
	_check(player != null, "ADV-QA-02: Player instance acquired")
	im.register_player(player)

	# --------------------------------------------------------------------------
	# SUB-TEST 2.1: Stack Underflow Immunity Stress
	# --------------------------------------------------------------------------
	_check_eq(im.get_current_context(), im.ContextMode.WORLD, "ADV-QA-02: Initial context is WORLD")
	_check_eq(im.get_stack_depth(), 1, "ADV-QA-02: Initial stack depth is 1")

	# Call pop_context() 50 times when already at WORLD
	for i in range(50):
		var pop_res = im.pop_context()
		_check_eq(pop_res, im.ContextMode.WORLD, "ADV-QA-02: Underflow pop %d returns WORLD" % i)

	_check_eq(im.get_stack_depth(), 1, "ADV-QA-02: Stack depth cannot underflow below 1")
	_check_eq(im.get_current_context(), im.ContextMode.WORLD, "ADV-QA-02: Context remains WORLD")
	_check(player.movement_enabled, "ADV-QA-02: Player movement enabled at WORLD")
	_check(player.look_enabled, "ADV-QA-02: Player look enabled at WORLD")

	# --------------------------------------------------------------------------
	# SUB-TEST 2.2: 500-Cycle Randomized Modal Push / Pop Stress
	# --------------------------------------------------------------------------
	var modal_list = [
		im.ContextMode.BOOK,
		im.ContextMode.STORAGE,
		im.ContextMode.KITCHEN,
		im.ContextMode.DIALOGUE,
		im.ContextMode.PAUSE
	]

	var pseudo_rand := 1337
	for step in range(500):
		pseudo_rand = (pseudo_rand * 1103515245 + 12345) & 0x7fffffff
		var do_push := (pseudo_rand % 2 == 0)

		if do_push:
			var target_idx := (pseudo_rand >> 16) % modal_list.size()
			var target_mode: int = modal_list[target_idx]
			im.push_context(target_mode)
		else:
			im.pop_context()

		var cur_ctx: int = im.get_current_context()
		var depth: int = im.get_stack_depth()
		_check(depth >= 1, "ADV-QA-02: Step %d: Stack depth >= 1" % step)

		if cur_ctx == im.ContextMode.WORLD:
			_check(player.movement_enabled, "ADV-QA-02: Step %d: WORLD movement enabled" % step)
			_check(player.look_enabled, "ADV-QA-02: Step %d: WORLD look enabled" % step)
		else:
			_check_eq(player.movement_enabled, false, "ADV-QA-02: Step %d: Modal movement locked" % step)
			_check_eq(player.look_enabled, false, "ADV-QA-02: Step %d: Modal look locked" % step)

	# --------------------------------------------------------------------------
	# SUB-TEST 2.3: 30-Level Deep Nested Stack Emergency Recovery via pop_to_world()
	# --------------------------------------------------------------------------
	# Push 30 modal contexts
	for i in range(30):
		var mode: int = modal_list[i % modal_list.size()]
		# push_context ignores duplicate if already top, so cycle modes
		im.push_context(mode)

	_check(im.get_stack_depth() > 10, "ADV-QA-02: Deep nested modal stack formed (depth: %d)" % im.get_stack_depth())
	_check_eq(player.movement_enabled, false, "ADV-QA-02: Player locked inside deep modal")

	# Instant recovery
	im.pop_to_world()
	_check_eq(im.get_stack_depth(), 1, "ADV-QA-02: pop_to_world() immediately resets stack depth to 1")
	_check_eq(im.get_current_context(), im.ContextMode.WORLD, "ADV-QA-02: Current context is WORLD")
	_check(player.movement_enabled, "ADV-QA-02: Player movement fully restored in WORLD")
	_check(player.look_enabled, "ADV-QA-02: Player camera look fully restored in WORLD")

	# --------------------------------------------------------------------------
	# SUB-TEST 2.4: Ghost / Freed Player Re-Registration Resilience
	# --------------------------------------------------------------------------
	# Unregister player by pushing modal when player is null or freed
	im.register_player(null)
	im.push_context(im.ContextMode.BOOK)
	_check_eq(im.get_current_context(), im.ContextMode.BOOK, "ADV-QA-02: Push modal works with null player")
	im.pop_to_world()
	_check_eq(im.get_current_context(), im.ContextMode.WORLD, "ADV-QA-02: pop_to_world works with null player")

	# Re-register player
	im.register_player(player)
	_check(player.movement_enabled, "ADV-QA-02: Re-registered player inherits WORLD movement enabled")
	_check(player.look_enabled, "ADV-QA-02: Re-registered player inherits WORLD look enabled")

	_free_test_main(main)
	await process_frame

	var passed = (_failed == start_fails)
	if passed:
		print("  [PASS] ADV-QA-02: Anti-Softlock & Input Context Stack Freedom Oracle verified 100%.")
	return passed

# ==============================================================================
# TEST 3: Abnormal Player Sequences & Edge Case Stress
# ==============================================================================

func test_adv_qa_03_abnormal_player_sequences() -> bool:
	print("\n--- [CHALLENGE 3] ADV-QA-03: Abnormal Player Sequences & Edge Case Stress ---")
	var start_fails = _failed

	_reset_all_managers()
	var inv = _get_autoload("InventoryManager") as InventoryManagerClass
	var gm = _get_autoload("GardenManager") as GardenManagerClass
	var wrm = _get_autoload("WorldResourceManager") as WorldResourceManagerClass
	var km = _get_autoload("KitchenManager") as KitchenManagerClass
	var dm = _get_autoload("DialogueManager") as DialogueManagerClass

	# --------------------------------------------------------------------------
	# SUB-TEST 3.1: Day-Lock Foraging Spam (25x consecutive rejected harvests)
	# --------------------------------------------------------------------------
	# Harvest corn on Day 1
	var c_first = wrm.harvest_foraging("resource_jagung_01")
	_check(c_first, "ADV-QA-03: Initial corn harvest succeeded")
	_check_eq(inv.backpack.get_item_count("ingredient_jagung"), 1, "ADV-QA-03: 1 corn in bag")

	# Attempt 25 rapid spam harvests on locked day
	for i in range(25):
		var spam_c = wrm.harvest_foraging("resource_jagung_01")
		_check_eq(spam_c, false, "ADV-QA-03: Spam harvest %d rejected" % i)

	_check_eq(inv.backpack.get_item_count("ingredient_jagung"), 1, "ADV-QA-03: Zero extra corn granted from 25 spam harvests")

	# --------------------------------------------------------------------------
	# SUB-TEST 3.2: Sleep / Day Advancement Inhibition during Active Kitchen Job
	# --------------------------------------------------------------------------
	# Give ingredients to start kitchen preparation
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	# State A: RESERVED_PREPARING
	km.start_preparation("recipe_sayur_bening_01")
	_check_eq(km.job_state, km.JobState.RESERVED_PREPARING, "ADV-QA-03: Kitchen in RESERVED_PREPARING")
	var sleep_a = wrm.can_sleep()
	_check_eq(sleep_a.get("success", true), false, "ADV-QA-03: Sleep inhibited during RESERVED_PREPARING")
	var sleep_act_a = wrm.sleep_and_advance_day()
	_check_eq(sleep_act_a, false, "ADV-QA-03: sleep_and_advance_day() returns false during prep")
	_check_eq(wrm.current_day, 1, "ADV-QA-03: Day remains 1")

	# State B: READY_TO_HEAT
	km.advance_prep(4.0)
	_check_eq(km.job_state, km.JobState.READY_TO_HEAT, "ADV-QA-03: Kitchen in READY_TO_HEAT")
	var sleep_b = wrm.can_sleep()
	_check_eq(sleep_b.get("success", true), false, "ADV-QA-03: Sleep inhibited during READY_TO_HEAT")

	# State C: COOKING
	km.start_cooking(km.HeatLevel.MEDIUM)
	_check_eq(km.job_state, km.JobState.COOKING, "ADV-QA-03: Kitchen in COOKING")
	var sleep_c = wrm.can_sleep()
	_check_eq(sleep_c.get("success", true), false, "ADV-QA-03: Sleep inhibited during COOKING")

	# State D: PAUSED
	km.pause_cooking()
	_check_eq(km.job_state, km.JobState.PAUSED, "ADV-QA-03: Kitchen in PAUSED")
	var sleep_d = wrm.can_sleep()
	_check_eq(sleep_d.get("success", true), false, "ADV-QA-03: Sleep inhibited during PAUSED")

	# Complete cooking -> OUTPUT_READY
	km.resume_cooking()
	km.advance_cooking(30.0)
	_check_eq(km.job_state, km.JobState.OUTPUT_READY, "ADV-QA-03: Kitchen in OUTPUT_READY")
	var sleep_e = wrm.can_sleep()
	# Per CONTENT.md § 9: Output ready tidak menghalangi istirahat kasur
	_check(sleep_e.get("success", false), "ADV-QA-03: Sleep permitted when dish is in output slot per CONTENT.md § 9")

	# Claim dish -> Kitchen returns to IDLE
	km.claim_dish_output()
	_check_eq(km.job_state, km.JobState.IDLE, "ADV-QA-03: Kitchen returned to IDLE")

	# Sleep and advance day
	var sleep_act_ok = wrm.sleep_and_advance_day()
	_check(sleep_act_ok, "ADV-QA-03: sleep_and_advance_day() succeeded")
	_check_eq(wrm.current_day, 2, "ADV-QA-03: Day successfully advanced to Day 2")

	# Verify wild corn node refreshed on Day 2!
	_check(wrm.is_foraging_node_available("resource_jagung_01"), "ADV-QA-03: Corn node refreshed on Day 2")

	# --------------------------------------------------------------------------
	# SUB-TEST 3.3: Ripe Crop Harvesting Rejection on 100% Full Backpack
	# --------------------------------------------------------------------------
	# Setup mature crop in garden plot
	gm.reset_to_defaults()
	inv.backpack.clear()
	inv.backpack.add_item("soil_compost", 1)
	inv.backpack.add_item("seed_bayam", 1)
	inv.backpack.add_item("fertilizer_basic", 1)
	gm.refill_water()
	gm.hoe_plot("plot_home_01")
	var c_res = gm.add_compost("plot_home_01")
	_check(c_res, "ADV-QA-03: Compost added for crop setup")
	var f_res = gm.fertilize_plot("plot_home_01")
	_check(f_res, "ADV-QA-03: Fertilizer added for crop setup")
	var w_res = gm.water_plot("plot_home_01")
	_check(w_res, "ADV-QA-03: Water added for crop setup")
	var p_res = gm.plant_seed("plot_home_01", "slot_01", "seed_bayam")
	_check(p_res, "ADV-QA-03: Seed planted for crop setup")
	gm._simulate_plot_growth("plot_home_01", 185.0)

	var sp1: Dictionary = gm.get_spot("plot_home_01", "slot_01")
	_check_eq(int(sp1["crop_data"]["growth_stage"]), 3, "ADV-QA-03: Crop is ripe at Stage 3")

	# Completely fill backpack (12/12 slots) with non-stackable tools
	var bp = inv.backpack
	bp.clear()
	for i in range(12):
		bp.slots[i].set("item_id", "tool_watering_can")
		bp.slots[i].set("count", 1)
	bp.contents_changed.emit()

	_check_eq(bp.get_used_slots_count(), 12, "ADV-QA-03: Backpack is 100% saturated")

	# Attempt to harvest ripe crop
	var harvest_check = gm.can_harvest_crop("plot_home_01", "slot_01")
	_check_eq(harvest_check.get("success", true), false, "ADV-QA-03: can_harvest_crop safely rejected when full")
	var harvest_act = gm.harvest_crop("plot_home_01", "slot_01")
	_check_eq(harvest_act, false, "ADV-QA-03: harvest_crop returns false when full")

	# VERIFY RIPE CROP IS NOT DESTROYED OR DELETED
	sp1 = gm.get_spot("plot_home_01", "slot_01")
	_check(sp1.get("is_occupied", false), "ADV-QA-03: Crop STILL OCCUPIES spot 1 (zero loss)")
	_check_eq(int(sp1["crop_data"]["growth_stage"]), 3, "ADV-QA-03: Crop is STILL at Stage 3")

	# Free 2 slots in backpack
	bp.slots[10].clear()
	bp.slots[11].clear()
	bp.contents_changed.emit()
	_check(bp.get_empty_slot_count() >= 2, "ADV-QA-03: 2 slots freed in backpack")

	# Now harvest succeeds
	var valid_harvest = gm.harvest_crop("plot_home_01", "slot_01")
	_check(valid_harvest, "ADV-QA-03: Harvest succeeds after freeing space")
	_check_eq(inv.backpack.get_item_count("ingredient_bayam"), 1, "ADV-QA-03: Received 1 fresh bayam")
	_check_eq(inv.backpack.get_item_count("seed_bayam"), 1, "ADV-QA-03: Received 1 returned seed")

	# --------------------------------------------------------------------------
	# SUB-TEST 3.4: Garden Planting & Cultivation Guard Invariants
	# --------------------------------------------------------------------------
	# Attempt to plant on an un-hoed plot
	gm.reset_to_defaults()
	var unhoed_plant = gm.can_plant_seed("plot_home_01", "slot_01", "seed_bayam")
	_check_eq(unhoed_plant.get("success", true), false, "ADV-QA-03: Planting on un-hoed soil rejected")

	# Hoe soil but don't add compost -> planting must still reject
	gm.hoe_plot("plot_home_01")
	var uncomposted_plant = gm.can_plant_seed("plot_home_01", "slot_01", "seed_bayam")
	_check_eq(uncomposted_plant.get("success", true), false, "ADV-QA-03: Planting without compost rejected")

	# Add compost, but have 0 seeds -> planting must reject
	bp.clear()
	bp.add_item("soil_compost", 1)
	gm.add_compost("plot_home_01")
	_check_eq(inv.backpack.get_item_count("seed_bayam"), 0, "ADV-QA-03: Backpack has 0 seeds")
	var no_seed_plant = gm.can_plant_seed("plot_home_01", "slot_01", "seed_bayam")
	_check_eq(no_seed_plant.get("success", true), false, "ADV-QA-03: Planting with 0 seeds rejected")

	# Plant with seed -> succeeds
	bp.add_item("seed_bayam", 1)
	var valid_plant = gm.plant_seed("plot_home_01", "slot_01", "seed_bayam")
	_check(valid_plant, "ADV-QA-03: Planting with prepared soil & seed succeeds")

	# Attempt to plant AGAIN on the same occupied spot -> must reject
	bp.add_item("seed_bayam", 1)
	var double_plant = gm.can_plant_seed("plot_home_01", "slot_01", "seed_bayam")
	_check_eq(double_plant.get("success", true), false, "ADV-QA-03: Double planting on occupied spot rejected")

	# --------------------------------------------------------------------------
	# SUB-TEST 3.5: Water & Fertilizer Boundary Limits
	# --------------------------------------------------------------------------
	# Water with 0 watering can water
	gm.watering_can_water = 0
	var empty_water = gm.can_water_plot("plot_home_01")
	_check_eq(empty_water.get("success", true), false, "ADV-QA-03: Watering with empty can rejected")

	# Refill can (10/10) and water
	gm.refill_water()
	_check_eq(gm.watering_can_water, 10, "ADV-QA-03: Can is 10/10")
	gm.water_plot("plot_home_01")
	_check_eq(gm.watering_can_water, 8, "ADV-QA-03: Can decreased by 2 (8/10)")

	# Attempt to water again when moisture is already optimal (80%)
	var full_moisture_water = gm.can_water_plot("plot_home_01")
	_check_eq(full_moisture_water.get("success", true), false, "ADV-QA-03: Watering plot already at >= 60 moisture rejected")

	# Attempt to fertilize when nutrients is already optimal (100)
	var full_nutrients_fert = gm.can_fertilize_plot("plot_home_01")
	_check_eq(full_nutrients_fert.get("success", true), false, "ADV-QA-03: Fertilizing plot already at >= 20 nutrients rejected")

	# --------------------------------------------------------------------------
	# SUB-TEST 3.6: Dialogue & Meal Sharing Edge Cases
	# --------------------------------------------------------------------------
	# Player has 0 dishes in backpack and storage
	bp.clear()
	inv.storage_home.clear()
	_check_eq(inv.backpack.get_item_count("dish_sayur_bening"), 0, "ADV-QA-03: 0 dishes in backpack")
	_check_eq(inv.storage_home.get_item_count("dish_sayur_bening"), 0, "ADV-QA-03: 0 dishes in storage")

	var share_zero = dm.share_dish("auto")
	_check_eq(share_zero.get("success", true), false, "ADV-QA-03: share_dish safely rejected when player has 0 dishes")
	_check_eq(dm.is_p0_completed(), false, "ADV-QA-03: P0 completion NOT triggered when sharing failed")

	var passed = (_failed == start_fails)
	if passed:
		print("  [PASS] ADV-QA-03: Abnormal Player Sequences & Edge Case Stress verified 100%.")
	return passed
