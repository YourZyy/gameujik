extends SceneTree

# Empirical Challenge Stress Harness for INV-001
# Tests:
# 1. Starter Crate Spam Protection (100 rapid calls, reentrancy attacks, zero duplicates, retry on freed space, snapshot persistence)
# 2. Starter Crate Slot Gating (0, 1, 2, 3 slots, partial stack merging, overflow rejection, triple stack merging with 0 empty slots)
# 3. Multi-item Harvest Check (can_harvest capacity gating: 0, 1, 2 slots, partial merging, full stack overflow, dictionary syntax, multi-stack yields)
# 4. UI Context Integration (Tab & Chest, STORAGE mode, mouse unlock, bleed-through frame guard, 10-cycle rapid toggle, Esc close)

const InventoryManagerScript = preload("res://scripts/inventory/inventory_manager.gd")
const InventoryUIScript = preload("res://scripts/ui/inventory_ui.gd")
const InputManagerScript = preload("res://scripts/core/input_manager.gd")
const InventoryContainerClass = preload("res://scripts/inventory/inventory_container.gd")

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0

func _init() -> void:
	print("==================================================")
	print("[EMPIRICAL_CHALLENGER] Starting INV-001 Stress Harness...")
	print("==================================================")
	call_deferred("_run_harness")

func assert_true(condition: bool, msg: String) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
	else:
		failed_assertions += 1
		printerr("  [FAIL] ", msg)

func assert_false(condition: bool, msg: String) -> void:
	assert_true(not condition, msg)

func assert_equal(actual: Variant, expected: Variant, msg: String) -> void:
	var matches: bool = (actual == expected)
	if not matches and typeof(actual) == typeof(expected) and actual is float:
		matches = is_equal_approx(actual, expected)
	assert_true(matches, "%s | Expected: %s, Got: %s" % [msg, str(expected), str(actual)])

func _run_harness() -> void:
	var all_ok: bool = await run_all_challenges()

	print("==================================================")
	print("[EMPIRICAL_CHALLENGER] SUMMARY:")
	print("  Total Assertions:  ", total_assertions)
	print("  Passed Assertions: ", passed_assertions)
	print("  Failed Assertions: ", failed_assertions)

	if all_ok and failed_assertions == 0:
		print("  VERDICT: CONFIRMED CORRECT (Exit Code: 0)")
		print("==================================================")
		quit(0)
	else:
		printerr("  VERDICT: ISSUE DETECTED (Exit Code: 1)")
		print("==================================================")
		quit(1)

func run_all_challenges() -> bool:
	print("\n--- Challenge 1: Starter Crate Spam Protection (100 Rapid Calls, Reentrancy & Persistence) ---")
	test_starter_spam_protection()

	print("\n--- Challenge 2: Starter Crate Slot Gating (0, 1, 2, 3 Slots & Complex Stack Merging) ---")
	test_starter_slot_gating()

	print("\n--- Challenge 3: Multi-item Harvest Check (can_harvest Capacity Gating & Overflows) ---")
	test_multi_item_harvest_check()

	print("\n--- Challenge 4: UI Context Integration & Bleed-through Prevention ---")
	await test_ui_context_integration()

	return failed_assertions == 0

# ==============================================================================
# Challenge 1: Starter Crate Spam Protection
# ==============================================================================
func test_starter_spam_protection() -> void:
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	assert_false(inv.is_starter_collected(), "Initial starter_claimed must be false")
	assert_false(inv.starter_claimed, "Direct property starter_claimed must be false")

	# Subtest 1.1: 100 Rapid sequential calls + Re-entrancy attack
	var reentrant_stats := {"calls": 0, "successes": 0}
	var on_collected = func(_items: Array):
		reentrant_stats["calls"] += 1
		var re_ok: bool = inv.pickup_starter_container()
		if re_ok:
			reentrant_stats["successes"] += 1

	inv.starter_collected.connect(on_collected)

	var successes: int = 0
	var failures: int = 0

	for i in range(100):
		var ok: bool = inv.pickup_starter_container()
		if ok:
			successes += 1
		else:
			failures += 1

	print("  Subtest 1.1: 100 Rapid calls -> %d successes, %d failures" % [successes, failures])
	assert_equal(successes, 1, "Exactly 1 call out of 100 must succeed")
	assert_equal(failures, 99, "Exactly 99 calls out of 100 must fail")

	# Verify re-entrancy attack was blocked
	assert_equal(reentrant_stats["calls"], 1, "Signal listener must have fired once")
	assert_equal(reentrant_stats["successes"], 0, "Re-entrant call inside signal emission must fail (0 successes)")

	# Verify backpack received EXACT amounts
	var seeds: int = inv.backpack.get_item_count("seed_bayam")
	var compost: int = inv.backpack.get_item_count("soil_compost")
	var fertilizer: int = inv.backpack.get_item_count("fertilizer_basic")

	assert_equal(seeds, 4, "Backpack must receive exactly 4 seed_bayam")
	assert_equal(compost, 1, "Backpack must receive exactly 1 soil_compost")
	assert_equal(fertilizer, 1, "Backpack must receive exactly 1 fertilizer_basic")

	# Verify total items in backpack = 6 units across exactly 3 occupied slots
	var total_items: int = 0
	var occupied_slots: int = 0
	for slot in inv.backpack.slots:
		if not slot.is_empty():
			occupied_slots += 1
			total_items += int(slot.count)

	assert_equal(occupied_slots, 3, "Exactly 3 slots must be occupied in backpack")
	assert_equal(total_items, 6, "Total units in backpack must be exactly 6 (4 seeds + 1 compost + 1 fertilizer)")
	assert_equal(inv.backpack.get_empty_slot_count(), 9, "Remaining 9 slots must be strictly empty")

	# Stress alternative accessors: claim_starter_container() and collect_starter_container()
	var claim_dict = inv.claim_starter_container()
	assert_false(claim_dict.get("success", true), "claim_starter_container() must report failure after being collected")
	assert_equal(claim_dict.get("reason", ""), "Wadah starter sudah pernah diambil.", "Reason must state already claimed")

	var collect_bool = inv.collect_starter_container()
	assert_false(collect_bool, "collect_starter_container() must return false after being collected")

	# Subtest 1.2: Failed pickup does NOT consume flag; subsequent retry succeeds when space freed
	var inv_retry: Node = InventoryManagerScript.new()
	inv_retry._ready()
	for i in range(12):
		inv_retry.backpack.get_slot(i).set("item_id", "blocker_%02d" % i)
		inv_retry.backpack.get_slot(i).set("count", 1)

	var fail_claim: bool = inv_retry.pickup_starter_container()
	assert_false(fail_claim, "Pickup on full backpack must fail")
	assert_false(inv_retry.is_starter_collected(), "Failed pickup must NOT set starter_claimed to true")

	# Free 3 slots and retry
	inv_retry.backpack.get_slot(0).clear()
	inv_retry.backpack.get_slot(1).clear()
	inv_retry.backpack.get_slot(2).clear()
	assert_equal(inv_retry.backpack.get_empty_slot_count(), 3, "3 slots freed")

	var retry_ok: bool = inv_retry.pickup_starter_container()
	assert_true(retry_ok, "Retry after clearing slots MUST succeed")
	assert_true(inv_retry.is_starter_collected(), "starter_claimed is now true after successful retry")
	assert_equal(inv_retry.backpack.get_item_count("seed_bayam"), 4, "Seeds granted on retry")
	assert_equal(inv_retry.backpack.get_item_count("soil_compost"), 1, "Compost granted on retry")
	assert_equal(inv_retry.backpack.get_item_count("fertilizer_basic"), 1, "Fertilizer granted on retry")

	# Subtest 1.3: Save/load snapshot persistence
	var snapshot: Dictionary = inv_retry.get_save_snapshot()
	assert_true(snapshot.has("starter_claimed"), "Snapshot must contain starter_claimed")
	assert_true(snapshot["starter_claimed"], "Snapshot starter_claimed must be true")

	var inv_loaded: Node = InventoryManagerScript.new()
	inv_loaded._ready()
	assert_false(inv_loaded.is_starter_collected(), "Fresh manager has false starter_claimed")
	inv_loaded.load_save_snapshot(snapshot)
	assert_true(inv_loaded.is_starter_collected(), "Loaded manager restores true starter_claimed")

	# Subsequent pickup on loaded manager must fail
	var loaded_pickup: bool = inv_loaded.pickup_starter_container()
	assert_false(loaded_pickup, "Pickup on restored saved game with claimed starter must fail")

	inv.free()
	inv_retry.free()
	inv_loaded.free()

# ==============================================================================
# Challenge 2: Starter Crate Slot Gating
# ==============================================================================
func test_starter_slot_gating() -> void:
	# Subtest 2.1: Test with exactly 0, 1, 2, and 3 available slots
	for available_slots: int in [0, 1, 2, 3]:
		var inv: Node = InventoryManagerScript.new()
		inv._ready()

		var filler_count: int = 12 - available_slots
		for i in range(filler_count):
			inv.backpack.get_slot(i).set("item_id", "dummy_%02d" % i)
			inv.backpack.get_slot(i).set("count", 1)

		assert_equal(inv.backpack.get_empty_slot_count(), available_slots,
			"Backpack setup: available slots must be %d" % available_slots)

		var slots_before: Array[Dictionary] = inv.backpack.to_array()
		var pickup_success: bool = inv.pickup_starter_container()

		if available_slots < 3:
			assert_false(pickup_success,
				"Pickup must be REJECTED when available slots = %d (needs 3)" % available_slots)
			assert_false(inv.is_starter_collected(),
				"starter_claimed must remain false when available slots = %d" % available_slots)

			var slots_after: Array[Dictionary] = inv.backpack.to_array()
			assert_equal(slots_after, slots_before,
				"Backpack slots must be 100%% identical and untouched on rejection (slots = %d)" % available_slots)

			assert_equal(inv.backpack.get_item_count("seed_bayam"), 0, "No seeds granted when rejected")
			assert_equal(inv.backpack.get_item_count("soil_compost"), 0, "No compost granted when rejected")
			assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 0, "No fertilizer granted when rejected")
		else:
			assert_true(pickup_success,
				"Pickup must SUCCEED when available slots = 3")
			assert_true(inv.is_starter_collected(),
				"starter_claimed must be true after successful pickup")

			assert_equal(inv.backpack.get_empty_slot_count(), 0, "All 12 slots should now be occupied")
			assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "Must have 4 seeds")
			assert_equal(inv.backpack.get_item_count("soil_compost"), 1, "Must have 1 compost")
			assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 1, "Must have 1 fertilizer")

		inv.free()

	# Subtest 2.2: Partial stack merging with 2 empty slots
	# 1 partial seed stack (16/20) + 9 dummy items + 2 empty slots
	var inv_merge: Node = InventoryManagerScript.new()
	inv_merge._ready()
	inv_merge.backpack.get_slot(0).set("item_id", "seed_bayam")
	inv_merge.backpack.get_slot(0).set("count", 16)
	for i in range(1, 10):
		inv_merge.backpack.get_slot(i).set("item_id", "dummy_%02d" % i)
		inv_merge.backpack.get_slot(i).set("count", 1)

	assert_equal(inv_merge.backpack.get_empty_slot_count(), 2, "Backpack has 2 empty slots + 1 partial seed stack (16/20)")
	var merge_ok: bool = inv_merge.pickup_starter_container()
	assert_true(merge_ok, "Pickup must succeed when existing partial stack absorbs seeds and 2 empty slots absorb compost & fertilizer")
	assert_equal(inv_merge.backpack.get_item_count("seed_bayam"), 20, "Seeds should merge to max stack 20")
	assert_equal(inv_merge.backpack.get_item_count("soil_compost"), 1, "Compost added")
	assert_equal(inv_merge.backpack.get_item_count("fertilizer_basic"), 1, "Fertilizer added")
	inv_merge.free()

	# Subtest 2.3: Stack overflow rejection with 2 empty slots
	# 1 partial seed stack with 17 units (17 + 4 = 21 > 20) -> requires overflow slot! Needs 3 slots total, only 2 free.
	var inv_overflow: Node = InventoryManagerScript.new()
	inv_overflow._ready()
	inv_overflow.backpack.get_slot(0).set("item_id", "seed_bayam")
	inv_overflow.backpack.get_slot(0).set("count", 17)
	for i in range(1, 10):
		inv_overflow.backpack.get_slot(i).set("item_id", "dummy_%02d" % i)
		inv_overflow.backpack.get_slot(i).set("count", 1)

	assert_equal(inv_overflow.backpack.get_empty_slot_count(), 2, "Backpack has 2 empty slots + seed stack (17/20)")
	var overflow_ok: bool = inv_overflow.pickup_starter_container()
	assert_false(overflow_ok, "Pickup must be rejected when 17+4=21 seeds requires an overflow slot, needing 3 slots total with only 2 free")
	assert_false(inv_overflow.is_starter_collected(), "starter_claimed remains false on stack overflow rejection")
	assert_equal(inv_overflow.backpack.get_item_count("seed_bayam"), 17, "Seed count untouched at 17")
	inv_overflow.free()

	# Subtest 2.4: Triple Stack Merge with ZERO Empty Slots
	# Backpack has 0 empty slots (all 12 filled), but contains:
	# slot 0: seed_bayam (16/20) -> can take 4 seeds
	# slot 1: soil_compost (19/20) -> can take 1 compost
	# slot 2: fertilizer_basic (19/20) -> can take 1 fertilizer
	# slots 3..11: dummy items
	var inv_triple: Node = InventoryManagerScript.new()
	inv_triple._ready()
	inv_triple.backpack.get_slot(0).set("item_id", "seed_bayam")
	inv_triple.backpack.get_slot(0).set("count", 16)
	inv_triple.backpack.get_slot(1).set("item_id", "soil_compost")
	inv_triple.backpack.get_slot(1).set("count", 19)
	inv_triple.backpack.get_slot(2).set("item_id", "fertilizer_basic")
	inv_triple.backpack.get_slot(2).set("count", 19)
	for i in range(3, 12):
		inv_triple.backpack.get_slot(i).set("item_id", "dummy_%02d" % i)
		inv_triple.backpack.get_slot(i).set("count", 20)

	assert_equal(inv_triple.backpack.get_empty_slot_count(), 0, "Zero empty slots in backpack")
	var triple_ok: bool = inv_triple.pickup_starter_container()
	assert_true(triple_ok, "Pickup with 0 empty slots must SUCCEED when all 3 items merge perfectly into existing stacks")
	assert_equal(inv_triple.backpack.get_item_count("seed_bayam"), 20, "Seeds merged to 20")
	assert_equal(inv_triple.backpack.get_item_count("soil_compost"), 20, "Compost merged to 20")
	assert_equal(inv_triple.backpack.get_item_count("fertilizer_basic"), 20, "Fertilizer merged to 20")
	inv_triple.free()

	# Subtest 2.5: Zero Empty Slots where ONE item is full (soil_compost is at 20/20)
	# Seed (16) fits, Fertilizer (19) fits, but Compost (20) cannot fit and 0 empty slots available.
	# Must be 100% REJECTED, with ZERO units added to seeds or fertilizer!
	var inv_triple_fail: Node = InventoryManagerScript.new()
	inv_triple_fail._ready()
	inv_triple_fail.backpack.get_slot(0).set("item_id", "seed_bayam")
	inv_triple_fail.backpack.get_slot(0).set("count", 16)
	inv_triple_fail.backpack.get_slot(1).set("item_id", "soil_compost")
	inv_triple_fail.backpack.get_slot(1).set("count", 20)
	inv_triple_fail.backpack.get_slot(2).set("item_id", "fertilizer_basic")
	inv_triple_fail.backpack.get_slot(2).set("count", 19)
	for i in range(3, 12):
		inv_triple_fail.backpack.get_slot(i).set("item_id", "dummy_%02d" % i)
		inv_triple_fail.backpack.get_slot(i).set("count", 20)

	var triple_fail_ok: bool = inv_triple_fail.pickup_starter_container()
	assert_false(triple_fail_ok, "Pickup with full compost stack and 0 free slots must be rejected utuh")
	assert_false(inv_triple_fail.is_starter_collected(), "starter_claimed remains false")
	assert_equal(inv_triple_fail.backpack.get_item_count("seed_bayam"), 16, "Seeds must not be partially added")
	assert_equal(inv_triple_fail.backpack.get_item_count("soil_compost"), 20, "Compost remains 20")
	assert_equal(inv_triple_fail.backpack.get_item_count("fertilizer_basic"), 19, "Fertilizer must not be partially added")
	inv_triple_fail.free()

# ==============================================================================
# Challenge 3: Multi-item Harvest Check (can_harvest)
# ==============================================================================
func test_multi_item_harvest_check() -> void:
	# Subtest 3.1: 0, 1, 2, 3 empty slots against default 2-item harvest (1 bayam, 1 seed)
	for available_slots: int in [0, 1, 2, 3]:
		var inv: Node = InventoryManagerScript.new()
		inv._ready()

		var filler_count: int = 12 - available_slots
		for i in range(filler_count):
			inv.backpack.get_slot(i).set("item_id", "unrelated_filler_%02d" % i)
			inv.backpack.get_slot(i).set("count", 1)

		assert_equal(inv.backpack.get_empty_slot_count(), available_slots, "Setup empty slots = %d" % available_slots)
		var can_h: bool = inv.can_harvest()

		if available_slots < 2:
			assert_false(can_h, "can_harvest() must return FALSE when available slots = %d (needs 2)" % available_slots)
		else:
			assert_true(can_h, "can_harvest() must return TRUE when available slots = %d (capacity >= 2)" % available_slots)

		inv.free()

	# Subtest 3.2: Stack Merging in Harvest: Both items merge with 0 empty slots
	var inv_harvest_merge: Node = InventoryManagerScript.new()
	inv_harvest_merge._ready()
	inv_harvest_merge.backpack.get_slot(0).set("item_id", "ingredient_bayam")
	inv_harvest_merge.backpack.get_slot(0).set("count", 5)
	inv_harvest_merge.backpack.get_slot(1).set("item_id", "seed_bayam")
	inv_harvest_merge.backpack.get_slot(1).set("count", 5)
	for i in range(2, 12):
		inv_harvest_merge.backpack.get_slot(i).set("item_id", "filler_%02d" % i)
		inv_harvest_merge.backpack.get_slot(i).set("count", 1)

	assert_equal(inv_harvest_merge.backpack.get_empty_slot_count(), 0, "0 empty slots, but both harvest items present with room")
	assert_true(inv_harvest_merge.can_harvest(), "can_harvest() must return TRUE when 0 empty slots but both items merge into existing stacks")
	inv_harvest_merge.free()

	# Subtest 3.3: Partial Merge in Harvest: Only bayam merges, seed needs slot -> 0 empty slots fails
	var inv_harvest_partial: Node = InventoryManagerScript.new()
	inv_harvest_partial._ready()
	inv_harvest_partial.backpack.get_slot(0).set("item_id", "ingredient_bayam")
	inv_harvest_partial.backpack.get_slot(0).set("count", 5)
	for i in range(1, 12):
		inv_harvest_partial.backpack.get_slot(i).set("item_id", "filler_%02d" % i)
		inv_harvest_partial.backpack.get_slot(i).set("count", 1)

	assert_equal(inv_harvest_partial.backpack.get_empty_slot_count(), 0, "0 empty slots, only bayam has stack room, seed has none")
	assert_false(inv_harvest_partial.can_harvest(), "can_harvest() must return FALSE when seed cannot fit, preventing partial harvest")
	inv_harvest_partial.free()

	# Subtest 3.4: Full stack overflow in Harvest: Bayam full at 20, 1 empty slot -> fails (needs 2 slots)
	var inv_harvest_max_stack: Node = InventoryManagerScript.new()
	inv_harvest_max_stack._ready()
	inv_harvest_max_stack.backpack.get_slot(0).set("item_id", "ingredient_bayam")
	inv_harvest_max_stack.backpack.get_slot(0).set("count", 20)
	for i in range(1, 11):
		inv_harvest_max_stack.backpack.get_slot(i).set("item_id", "filler_%02d" % i)
		inv_harvest_max_stack.backpack.get_slot(i).set("count", 1)

	assert_equal(inv_harvest_max_stack.backpack.get_empty_slot_count(), 1, "1 empty slot, but bayam stack is full at 20")
	assert_false(inv_harvest_max_stack.can_harvest(), "can_harvest() must return FALSE because full bayam stack requires overflow slot, needing 2 slots total")
	inv_harvest_max_stack.free()

	# Subtest 3.5: Custom yield Dictionary syntax & multi-stack harvest
	# 25 bayam (needs 2 slots) + 1 seed (needs 1 slot) = 3 slots needed!
	var inv_dict: Node = InventoryManagerScript.new()
	inv_dict._ready()
	for i in range(10):
		inv_dict.backpack.get_slot(i).set("item_id", "filler_%02d" % i)
		inv_dict.backpack.get_slot(i).set("count", 1)
	assert_equal(inv_dict.backpack.get_empty_slot_count(), 2, "2 empty slots available")

	var dict_yield: Dictionary = {
		"ingredient_bayam": 25,
		"seed_bayam": 1
	}
	assert_false(inv_dict.can_harvest(dict_yield), "can_harvest(25 bayam + 1 seed) requires 3 slots, must return FALSE with 2 free slots")

	inv_dict.backpack.get_slot(9).clear()
	assert_equal(inv_dict.backpack.get_empty_slot_count(), 3, "3 empty slots available")
	assert_true(inv_dict.can_harvest(dict_yield), "can_harvest(25 bayam + 1 seed) must return TRUE with 3 free slots")
	inv_dict.free()

# ==============================================================================
# Challenge 4: UI Context Integration & Bleed-through Prevention
# ==============================================================================
func test_ui_context_integration() -> void:
	var im: Node = root.get_node_or_null("InputManager")
	assert_true(im != null, "InputManager singleton must exist in SceneTree")
	if im == null:
		return

	var ui_scene = load("res://scenes/ui/inventory_ui.tscn")
	assert_true(ui_scene != null, "inventory_ui.tscn must load")
	if ui_scene == null:
		return

	var ui: CanvasLayer = ui_scene.instantiate() as CanvasLayer
	root.add_child(ui)
	await process_frame

	# Ensure initial state in WORLD
	im.pop_to_world()
	assert_equal(im.get_current_context(), im.ContextMode.WORLD, "Initial context must be WORLD")
	assert_false(im.is_simulation_paused(), "Simulation must NOT be paused in WORLD")
	assert_true(im._mouse_captured_state, "Mouse must be captured in WORLD")
	assert_false(ui.visible, "Inventory UI must be hidden in WORLD")

	# Subtest 4.1: Tab Open Solo Mode & Context Transition
	print("  Subtest 4.1: Tab Open Solo Mode & Context Transition")
	im.push_context(im.ContextMode.STORAGE)
	assert_equal(im.get_current_context(), im.ContextMode.STORAGE, "Context must be STORAGE after Tab/push")
	assert_true(im.is_simulation_paused(), "Simulation must be paused in STORAGE context")
	assert_false(im._mouse_captured_state, "Mouse must be UNLOCKED (visible) in STORAGE context")
	assert_true(ui.visible, "InventoryUI must become visible when STORAGE context entered")
	assert_equal(ui.current_mode, ui.ViewMode.SOLO, "Default opening mode must be SOLO")
	assert_false(ui.storage_section.visible, "Storage section must be hidden in SOLO mode")

	# Subtest 4.2: Chest Open Dual Mode
	print("  Subtest 4.2: Chest Open Dual Mode")
	ui.open_dual()
	assert_true(ui.visible, "InventoryUI must be visible in DUAL mode")
	assert_equal(ui.current_mode, ui.ViewMode.DUAL, "Current mode must be DUAL")
	assert_true(ui.storage_section.visible, "Storage section must be visible in DUAL mode")

	# Subtest 4.3: Action Bleed-Through Prevention on Close
	print("  Subtest 4.3: Action Bleed-Through Prevention on Close")
	ui.close_ui()

	# Context popped back to WORLD
	assert_equal(im.get_current_context(), im.ContextMode.WORLD, "Context must return to WORLD on close")
	assert_false(im.is_simulation_paused(), "Simulation must resume in WORLD")
	assert_true(im._mouse_captured_state, "Mouse must be locked (captured) back in WORLD")
	assert_false(ui.visible, "InventoryUI must be hidden after close_ui()")

	# Bleed-through frame guard assertions:
	assert_false(im.can_interact_in_world(), "can_interact_in_world() MUST be FALSE on the exact frame of closing")
	assert_true(im.is_action_suppressed(&"open_inventory"), "open_inventory action MUST be suppressed until released")

	await process_frame
	assert_true(im.can_interact_in_world(), "can_interact_in_world() MUST be TRUE on subsequent frame")

	# Subtest 4.4: 10 Rapid Open/Close Toggle Cycles (Zero Stack Leak)
	print("  Subtest 4.4: 10 Rapid Open/Close Toggle Cycles (Zero Stack Leak)")
	for cycle in range(10):
		im.push_context(im.ContextMode.STORAGE)
		assert_equal(im.get_current_context(), im.ContextMode.STORAGE, "Cycle %d: STORAGE" % cycle)
		assert_true(im.is_simulation_paused(), "Cycle %d: Paused" % cycle)
		im.consume_and_close(&"open_inventory")
		assert_equal(im.get_current_context(), im.ContextMode.WORLD, "Cycle %d: WORLD" % cycle)
		assert_false(im.is_simulation_paused(), "Cycle %d: Unpaused" % cycle)
		await process_frame

	assert_equal(im.get_stack_depth(), 1, "Context stack depth must remain strictly 1 after 10 toggle cycles")

	# Subtest 4.5: Esc Key Closing via consume_and_close(&"pause_menu")
	print("  Subtest 4.5: Modal Close via Esc Key")
	im.push_context(im.ContextMode.STORAGE)
	assert_equal(im.get_current_context(), im.ContextMode.STORAGE, "Context is STORAGE")
	im.consume_and_close(&"pause_menu")
	assert_equal(im.get_current_context(), im.ContextMode.WORLD, "Context returns to WORLD via Esc")
	assert_false(im.can_interact_in_world(), "Frame guard active on Esc close")
	await process_frame
	assert_true(im.can_interact_in_world(), "Interaction re-enabled after Esc frame")

	ui.queue_free()
	await process_frame
