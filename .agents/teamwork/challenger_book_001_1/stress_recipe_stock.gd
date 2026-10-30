extends SceneTree

## Dedicated Stress Harness for BOOK-001 (Buku Resep & Tracker HUD)
## Author: challenger_book_001_1
## Target Verifications:
## 1. Track / Untrack Invariance (T03): 200 rapid cycles; zero item loss, zero count mutation.
## 2. Pre-acquisition Counting (T02): Gather items before tracking; immediately counted.
## 3. Shared Stock Transfer Invariance (T11, T31): Split 3 spinach, 1 corn, 1 temu kunci across backpack and chest.
##    Perform 300 rapid random transfers between backpack and chest. Verify RecipeManager.get_available_item_count()
##    and can_cook remain strictly invariant on every single iteration!
## 4. Status Boundary (T31): Verify collecting all required ingredients results strictly in status "Siap dimasak",
##    NEVER "Selesai" before actual cooking.

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const RecipeManagerClass = preload("res://scripts/recipe/recipe_manager.gd")
const RecipeDataClass = preload("res://scripts/recipe/recipe_data.gd")
const RecipesDataClass = preload("res://scripts/recipe/recipes_data.gd")

var _passed_count: int = 0
var _failed_count: int = 0
var _test_failures: Array[String] = []

func _record_assert(cond: bool, msg: String) -> bool:
	if cond:
		_passed_count += 1
		return true
	else:
		_failed_count += 1
		_test_failures.append(msg)
		printerr("    [CHALLENGE FAIL] " + msg)
		return false

func _initialize() -> void:
	print("======================================================================")
	print("[CHALLENGER_BOOK_001_1] EMPIRICAL STRESS & ADVERSARIAL HARNESS")
	print("======================================================================")
	
	if not _test_challenge_1_track_untrack_invariance_200_cycles():
		pass
		
	if not _test_challenge_2_pre_acquisition_counting():
		pass
		
	if not _test_challenge_3_shared_stock_transfer_invariance_300_cycles():
		pass
		
	if not await _test_challenge_4_status_boundary_siap_dimasak_vs_selesai():
		pass

	if not _test_challenge_5_adversarial_reservations_and_full_capacity_transfers():
		pass

	print("======================================================================")
	print("[CHALLENGER_BOOK_001_1] SUMMARY OF RESULTS:")
	print("  Total Stress Assertions Passed: %d" % _passed_count)
	print("  Total Stress Assertions Failed: %d" % _failed_count)
	if _failed_count > 0:
		print("  FAILURES:")
		for f in _test_failures:
			print("   - %s" % f)
		printerr("  VERDICT: DEFECT DETECTED")
		print("======================================================================")
		quit(1)
	else:
		print("  VERDICT: CONFIRMED CORRECT (Zero Defect, 100% Invariant)")
		print("======================================================================")
		quit(0)

func _create_test_inventory() -> Node:
	var inv: Node = InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.storage_home.clear()
	inv.kitchen_refund.clear()
	inv.starter_claimed = false
	return inv

func _create_test_recipe_manager(inv: Node) -> Node:
	var rm: Node = RecipeManagerClass.new()
	rm.set_inventory_manager(inv)
	rm._ready()
	return rm

## CHALLENGE 1: Track / untrack invariance (T03)
## 200 rapid cycles: zero item loss, zero count mutation.
func _test_challenge_1_track_untrack_invariance_200_cycles() -> bool:
	print("\n>>> [RUN] Challenge 1: Track / Untrack Invariance (200 Rapid Cycles)")
	var start_fails: int = _failed_count
	
	var inv: Node = _create_test_inventory()
	var rm: Node = _create_test_recipe_manager(inv)
	
	# Seed inventory with distinct initial inventory distribution
	inv.add_items("backpack", [
		{"item_id": "ingredient_bayam", "count": 2},
		{"item_id": "ingredient_jagung", "count": 1},
		{"item_id": "seed_bayam", "count": 4}
	])
	inv.add_items("storage", [
		{"item_id": "ingredient_bayam", "count": 1},
		{"item_id": "fertilizer_basic", "count": 2}
	])
	
	var baseline_bp_bayam: int = int(inv.backpack.get_item_count("ingredient_bayam")) # 2
	var baseline_st_bayam: int = int(inv.storage_home.get_item_count("ingredient_bayam")) # 1
	var baseline_bp_jagung: int = int(inv.backpack.get_item_count("ingredient_jagung")) # 1
	var baseline_bp_seed: int = int(inv.backpack.get_item_count("seed_bayam")) # 4
	var baseline_st_fert: int = int(inv.storage_home.get_item_count("fertilizer_basic")) # 2
	
	# In GDScript lambdas, capture array to mutate by reference
	var track_signal_count: Array[int] = [0]
	var untrack_signal_count: Array[int] = [0]
	var update_signal_count: Array[int] = [0]
	
	rm.recipe_tracked.connect(func(_id): track_signal_count[0] += 1)
	rm.recipe_untracked.connect(func(_id): untrack_signal_count[0] += 1)
	rm.recipe_updated.connect(func(_id): update_signal_count[0] += 1)
	
	const CYCLES: int = 200
	for i in range(CYCLES):
		# Rapid track
		var ok_track: bool = rm.track_recipe("recipe_sayur_bening_01")
		_record_assert(ok_track, "Cycle %d: rm.track_recipe must return true" % i)
		_record_assert(rm.is_recipe_tracked("recipe_sayur_bening_01"), "Cycle %d: must report tracked" % i)
		_record_assert(rm.tracked_recipe_id == "recipe_sayur_bening_01", "Cycle %d: tracked_recipe_id matches" % i)
		
		# Rapid untrack
		var ok_untrack: bool = rm.untrack_recipe("recipe_sayur_bening_01")
		_record_assert(ok_untrack, "Cycle %d: rm.untrack_recipe must return true" % i)
		_record_assert(not rm.is_recipe_tracked("recipe_sayur_bening_01"), "Cycle %d: must report untracked" % i)
		_record_assert(rm.tracked_recipe_id == "", "Cycle %d: tracked_recipe_id cleared" % i)
		
		# Invariant checks on EVERY cycle: zero item loss, zero count mutation
		var curr_bp_bayam: int = int(inv.backpack.get_item_count("ingredient_bayam"))
		var curr_st_bayam: int = int(inv.storage_home.get_item_count("ingredient_bayam"))
		var curr_bp_jagung: int = int(inv.backpack.get_item_count("ingredient_jagung"))
		var curr_bp_seed: int = int(inv.backpack.get_item_count("seed_bayam"))
		var curr_st_fert: int = int(inv.storage_home.get_item_count("fertilizer_basic"))
		
		_record_assert(curr_bp_bayam == baseline_bp_bayam, "Cycle %d: bp bayam mutated! expected %d got %d" % [i, baseline_bp_bayam, curr_bp_bayam])
		_record_assert(curr_st_bayam == baseline_st_bayam, "Cycle %d: st bayam mutated! expected %d got %d" % [i, baseline_st_bayam, curr_st_bayam])
		_record_assert(curr_bp_jagung == baseline_bp_jagung, "Cycle %d: bp jagung mutated!" % i)
		_record_assert(curr_bp_seed == baseline_bp_seed, "Cycle %d: bp seed mutated!" % i)
		_record_assert(curr_st_fert == baseline_st_fert, "Cycle %d: st fertilizer mutated!" % i)
		
		var avail_bayam: int = int(rm.get_available_ingredient_count("ingredient_bayam"))
		var avail_jagung: int = int(rm.get_available_ingredient_count("ingredient_jagung"))
		var avail_kunci: int = int(rm.get_available_ingredient_count("ingredient_temu_kunci"))
		_record_assert(avail_bayam == 3, "Cycle %d: available bayam != 3" % i)
		_record_assert(avail_jagung == 1, "Cycle %d: available jagung != 1" % i)
		_record_assert(avail_kunci == 0, "Cycle %d: available temu_kunci != 0" % i)

	_record_assert(track_signal_count[0] == CYCLES, "recipe_tracked signal emitted exactly %d times (got %d)" % [CYCLES, track_signal_count[0]])
	_record_assert(untrack_signal_count[0] == CYCLES, "recipe_untracked signal emitted exactly %d times (got %d)" % [CYCLES, untrack_signal_count[0]])

	rm.free()
	inv.free()
	
	var ok: bool = (_failed_count == start_fails)
	if ok:
		print("<<< [PASS] Challenge 1: 200 rapid track/untrack cycles passed with ZERO mutations.")
	return ok

## CHALLENGE 2: Pre-acquisition counting (T02)
## Gather items before tracking; immediately counted across various combinations.
func _test_challenge_2_pre_acquisition_counting() -> bool:
	print("\n>>> [RUN] Challenge 2: Pre-acquisition Counting Across Combinations")
	var start_fails: int = _failed_count
	
	var test_cases: Array[Dictionary] = [
		{
			"desc": "Empty inventory",
			"bp": [],
			"st": [],
			"exp_bayam": 0, "exp_jagung": 0, "exp_kunci": 0, "can_cook": false
		},
		{
			"desc": "Partial ingredients in backpack only",
			"bp": [{"item_id": "ingredient_bayam", "count": 2}],
			"st": [],
			"exp_bayam": 2, "exp_jagung": 0, "exp_kunci": 0, "can_cook": false
		},
		{
			"desc": "Partial ingredients in storage only",
			"bp": [],
			"st": [{"item_id": "ingredient_jagung", "count": 1}, {"item_id": "ingredient_temu_kunci", "count": 1}],
			"exp_bayam": 0, "exp_jagung": 1, "exp_kunci": 1, "can_cook": false
		},
		{
			"desc": "Complete ingredients split across containers",
			"bp": [{"item_id": "ingredient_bayam", "count": 1}, {"item_id": "ingredient_jagung", "count": 1}],
			"st": [{"item_id": "ingredient_bayam", "count": 2}, {"item_id": "ingredient_temu_kunci", "count": 1}],
			"exp_bayam": 3, "exp_jagung": 1, "exp_kunci": 1, "can_cook": true
		},
		{
			"desc": "Surplus ingredients gathered before tracking",
			"bp": [{"item_id": "ingredient_bayam", "count": 10}, {"item_id": "ingredient_jagung", "count": 5}],
			"st": [{"item_id": "ingredient_bayam", "count": 5}, {"item_id": "ingredient_temu_kunci", "count": 3}],
			"exp_bayam": 15, "exp_jagung": 5, "exp_kunci": 3, "can_cook": true
		}
	]
	
	for tc in test_cases:
		var inv: Node = _create_test_inventory()
		var rm: Node = _create_test_recipe_manager(inv)
		
		# 1. Gather before tracking
		if tc["bp"].size() > 0:
			inv.add_items("backpack", tc["bp"])
		if tc["st"].size() > 0:
			inv.add_items("storage", tc["st"])
			
		_record_assert(rm.tracked_recipe_id == "", "Pre-track: recipe is untracked for '%s'" % tc["desc"])
		
		# 2. Activate tracking
		rm.track_recipe("recipe_sayur_bening_01")
		
		# 3. Immediately counted check
		var bayam_cnt: int = int(rm.get_available_ingredient_count("ingredient_bayam"))
		var jagung_cnt: int = int(rm.get_available_ingredient_count("ingredient_jagung"))
		var kunci_cnt: int = int(rm.get_available_ingredient_count("ingredient_temu_kunci"))
		var can_cook: bool = bool(rm.can_cook_recipe("recipe_sayur_bening_01"))
		
		_record_assert(bayam_cnt == tc["exp_bayam"], "'%s': bayam expected %d got %d" % [tc["desc"], tc["exp_bayam"], bayam_cnt])
		_record_assert(jagung_cnt == tc["exp_jagung"], "'%s': jagung expected %d got %d" % [tc["desc"], tc["exp_jagung"], jagung_cnt])
		_record_assert(kunci_cnt == tc["exp_kunci"], "'%s': temu_kunci expected %d got %d" % [tc["desc"], tc["exp_kunci"], kunci_cnt])
		_record_assert(can_cook == tc["can_cook"], "'%s': can_cook expected %s got %s" % [tc["desc"], tc["can_cook"], can_cook])
		
		# Check individual ingredient statuses via recipe_data
		var recipe = rm.get_recipe("recipe_sayur_bening_01")
		var s_bayam: Dictionary = recipe.get_ingredient_status("ingredient_bayam", inv)
		var s_jagung: Dictionary = recipe.get_ingredient_status("ingredient_jagung", inv)
		var s_kunci: Dictionary = recipe.get_ingredient_status("ingredient_temu_kunci", inv)
		
		_record_assert(int(s_bayam["available"]) == int(tc["exp_bayam"]), "'%s': recipe_data s_bayam available" % tc["desc"])
		_record_assert(bool(s_bayam["satisfied"]) == (int(tc["exp_bayam"]) >= 3), "'%s': recipe_data s_bayam satisfied" % tc["desc"])
		_record_assert(int(s_jagung["available"]) == int(tc["exp_jagung"]), "'%s': recipe_data s_jagung available" % tc["desc"])
		_record_assert(bool(s_jagung["satisfied"]) == (int(tc["exp_jagung"]) >= 1), "'%s': recipe_data s_jagung satisfied" % tc["desc"])
		_record_assert(int(s_kunci["available"]) == int(tc["exp_kunci"]), "'%s': recipe_data s_kunci available" % tc["desc"])
		_record_assert(bool(s_kunci["satisfied"]) == (int(tc["exp_kunci"]) >= 1), "'%s': recipe_data s_kunci satisfied" % tc["desc"])
		
		rm.free()
		inv.free()
		
	var ok: bool = (_failed_count == start_fails)
	if ok:
		print("<<< [PASS] Challenge 2: Pre-acquisition counting confirmed across all combinations.")
	return ok

## CHALLENGE 3: Shared stock transfer invariance (T11, T31)
## Split 3 spinach, 1 corn, 1 temu kunci across backpack and chest.
## Perform 300 rapid random transfers between backpack and chest.
## Verify RecipeManager.get_available_item_count() and can_cook remain strictly invariant on every single iteration!
func _test_challenge_3_shared_stock_transfer_invariance_300_cycles() -> bool:
	print("\n>>> [RUN] Challenge 3: Shared Stock Transfer Invariance (300 Rapid Random Transfers)")
	var start_fails: int = _failed_count
	
	var inv: Node = _create_test_inventory()
	var rm: Node = _create_test_recipe_manager(inv)
	
	# Initial split:
	# Backpack: 2 spinach, 1 temu kunci
	# Storage: 1 spinach, 1 corn
	inv.add_items("backpack", [
		{"item_id": "ingredient_bayam", "count": 2},
		{"item_id": "ingredient_temu_kunci", "count": 1}
	])
	inv.add_items("storage", [
		{"item_id": "ingredient_bayam", "count": 1},
		{"item_id": "ingredient_jagung", "count": 1}
	])
	
	rm.track_recipe("recipe_sayur_bening_01")
	
	# Initial state sanity
	_record_assert(rm.get_available_ingredient_count("ingredient_bayam") == 3, "Baseline bayam = 3")
	_record_assert(rm.get_available_ingredient_count("ingredient_jagung") == 1, "Baseline jagung = 1")
	_record_assert(rm.get_available_ingredient_count("ingredient_temu_kunci") == 1, "Baseline temu_kunci = 1")
	_record_assert(rm.can_cook_recipe("recipe_sayur_bening_01") == true, "Baseline can_cook = true")
	
	# Deterministic pseudo-random seed for repeatable empirical challenge
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20451027
	
	const TOTAL_TRANSFERS: int = 300
	var successful_transfers: int = 0
	
	for iter in range(TOTAL_TRANSFERS):
		# Direction: 0 = Backpack -> Storage, 1 = Storage -> Backpack
		var dir: int = rng.randi_range(0, 1)
		var from_c: String = "backpack" if dir == 0 else "storage"
		var to_c: String = "storage" if dir == 0 else "backpack"
		
		# Transfer operation type:
		# 0: transfer_item (1 unit from a slot)
		# 1: transfer_slot (full stack from a slot)
		# 2: transfer_all (with or without filter)
		var op_type: int = rng.randi_range(0, 2)
		var slot_idx: int = rng.randi_range(0, 11)
		
		match op_type:
			0:
				var ok_tr: bool = inv.transfer_item(from_c, to_c, slot_idx, 1)
				if ok_tr:
					successful_transfers += 1
			1:
				var res: Dictionary = inv.transfer_slot(from_c, to_c, slot_idx)
				if res.get("success", false):
					successful_transfers += 1
			2:
				var filter_choice: int = rng.randi_range(0, 3)
				var filter: String = ""
				match filter_choice:
					1: filter = "ingredient_bayam"
					2: filter = "ingredient_jagung"
					3: filter = "ingredient_temu_kunci"
				var res_all: Dictionary = inv.transfer_all(from_c, to_c, filter)
				if res_all.get("success", false):
					successful_transfers += 1

		# STRICT INVARIANCE ASSERTION ON EVERY SINGLE ITERATION!
		var cur_bayam: int = int(rm.get_available_ingredient_count("ingredient_bayam"))
		var cur_jagung: int = int(rm.get_available_ingredient_count("ingredient_jagung"))
		var cur_kunci: int = int(rm.get_available_ingredient_count("ingredient_temu_kunci"))
		var cur_cook: bool = bool(rm.can_cook_recipe("recipe_sayur_bening_01"))
		
		if cur_bayam != 3 or cur_jagung != 1 or cur_kunci != 1 or not cur_cook:
			_record_assert(false, "Transfer Iteration %d VIOLATED INVARIANCE: bayam=%d (exp 3), jagung=%d (exp 1), kunci=%d (exp 1), can_cook=%s" % [
				iter, cur_bayam, cur_jagung, cur_kunci, str(cur_cook)
			])
			break
		else:
			_record_assert(cur_bayam == 3, "Iter %d: bayam invariant" % iter)
			_record_assert(cur_jagung == 1, "Iter %d: jagung invariant" % iter)
			_record_assert(cur_kunci == 1, "Iter %d: temu_kunci invariant" % iter)
			_record_assert(cur_cook == true, "Iter %d: can_cook invariant" % iter)

	print("    [INFO] Completed %d transfer operations (%d state-mutating transfers executed successfully)." % [TOTAL_TRANSFERS, successful_transfers])
	_record_assert(successful_transfers > 50, "Sufficient dynamic movement occurred (%d successful transfers)" % successful_transfers)

	rm.free()
	inv.free()
	
	var ok: bool = (_failed_count == start_fails)
	if ok:
		print("<<< [PASS] Challenge 3: 300 rapid random transfers maintained 100% strict stock invariance.")
	return ok

## CHALLENGE 4: Status boundary (T31)
## Verify that collecting all required ingredients results strictly in status "Siap dimasak",
## NEVER "Selesai" before actual cooking.
func _test_challenge_4_status_boundary_siap_dimasak_vs_selesai() -> bool:
	print("\n>>> [RUN] Challenge 4: Status Boundary ('Siap dimasak' vs 'Selesai')")
	var start_fails: int = _failed_count
	
	var inv: Node = _create_test_inventory()
	var rm: Node = _create_test_recipe_manager(inv)
	
	# Instantiate HUD scene to test UI presentation as well
	var hud_node: Node = null
	if ResourceLoader.exists("res://scenes/ui/hud.tscn"):
		var hud_scene = load("res://scenes/ui/hud.tscn")
		hud_node = hud_scene.instantiate()
		root.add_child(hud_node)
		await process_frame
		if hud_node.has_method("set_recipe_manager"):
			hud_node.set_recipe_manager(rm)
		await process_frame
	
	# Step 1: Initial state (0 items)
	rm.track_recipe("recipe_sayur_bening_01")
	if hud_node != null and hud_node.has_method("refresh_tracker"):
		hud_node.refresh_tracker()
		
	var recipe = rm.get_recipe("recipe_sayur_bening_01")
	_record_assert(int(recipe.times_cooked) == 0, "Phase 1: times_cooked is 0")
	_record_assert(not recipe.is_completed, "Phase 1: is_completed is false")
	_record_assert(not rm.is_recipe_completed("recipe_sayur_bening_01"), "Phase 1: rm.is_recipe_completed is false")
	_record_assert(not rm.can_cook_recipe("recipe_sayur_bening_01"), "Phase 1: can_cook_recipe is false")
	
	if hud_node != null:
		var status_lbl: Label = hud_node.find_child("TrackerStatusLabel", true, false) as Label
		_record_assert(status_lbl != null, "HUD TrackerStatusLabel exists")
		if status_lbl != null:
			_record_assert(status_lbl.text == "" or not status_lbl.visible, "Phase 1: Status label is empty or hidden when incomplete")
			_record_assert(not status_lbl.visible or not status_lbl.text.contains("Selesai"), "Phase 1: Status label does NOT say 'Selesai'")
			_record_assert(not status_lbl.visible or not status_lbl.text.contains("Siap"), "Phase 1: Status label does NOT say 'Siap'")

	# Step 2: Partial items (2 spinach, 1 corn, 0 temu kunci)
	inv.add_items("backpack", [
		{"item_id": "ingredient_bayam", "count": 2},
		{"item_id": "ingredient_jagung", "count": 1}
	])
	if hud_node != null and hud_node.has_method("refresh_tracker"):
		hud_node.refresh_tracker()
		
	_record_assert(not rm.can_cook_recipe("recipe_sayur_bening_01"), "Phase 2: can_cook is false with missing temu kunci")
	_record_assert(not rm.is_recipe_completed("recipe_sayur_bening_01"), "Phase 2: is_completed is false")
	if hud_node != null:
		var status_lbl: Label = hud_node.find_child("TrackerStatusLabel", true, false) as Label
		if status_lbl != null:
			_record_assert(status_lbl.text == "" or not status_lbl.visible, "Phase 2: Status label hidden with partial items")
			_record_assert(not status_lbl.visible or not status_lbl.text.contains("Selesai"), "Phase 2: Status label MUST NOT say 'Selesai'")
			_record_assert(not status_lbl.visible or not status_lbl.text.contains("Siap"), "Phase 2: Status label MUST NOT say 'Siap'")

	# Step 3: Complete items (Add 1 bayam, 1 temu kunci)
	inv.add_items("storage", [
		{"item_id": "ingredient_bayam", "count": 1},
		{"item_id": "ingredient_temu_kunci", "count": 1}
	])
	if hud_node != null and hud_node.has_method("refresh_tracker"):
		hud_node.refresh_tracker()

	_record_assert(rm.can_cook_recipe("recipe_sayur_bening_01") == true, "Phase 3: can_cook is TRUE with complete items")
	_record_assert(rm.is_recipe_completed("recipe_sayur_bening_01") == false, "Phase 3: is_completed MUST STRICTLY BE FALSE before cooking!")
	_record_assert(int(recipe.times_cooked) == 0, "Phase 3: times_cooked is STILL 0")
	
	if hud_node != null:
		var status_lbl: Label = hud_node.find_child("TrackerStatusLabel", true, false) as Label
		if status_lbl != null:
			_record_assert(status_lbl.visible == true, "Phase 3: Status label is visible when ready")
			_record_assert(status_lbl.text.contains("Siap dimasak"), "Phase 3: Status label STRICTLY contains 'Siap dimasak' (got: '%s')" % status_lbl.text)
			_record_assert(not status_lbl.text.contains("Selesai"), "Phase 3: Status label MUST NOT contain 'Selesai' before cooking!")

	# Step 4: After ACTUAL cooking completion via rm.record_recipe_cooked()
	rm.record_recipe_cooked("recipe_sayur_bening_01")
	if hud_node != null and hud_node.has_method("refresh_tracker"):
		hud_node.refresh_tracker()

	_record_assert(int(recipe.times_cooked) == 1, "Phase 4: times_cooked is now 1 after cooking")
	_record_assert(rm.is_recipe_completed("recipe_sayur_bening_01") == true, "Phase 4: is_recipe_completed is now TRUE")

	if hud_node != null:
		# Consume the ingredients to simulate finished meal
		inv.backpack.clear()
		inv.storage_home.clear()
		hud_node.refresh_tracker()
		
		var status_lbl: Label = hud_node.find_child("TrackerStatusLabel", true, false) as Label
		if status_lbl != null:
			_record_assert(status_lbl.visible == true, "Phase 4: Completed recipe shows completed status when ingredients empty")
			_record_assert(status_lbl.text.contains("Resep selesai"), "Phase 4: Status label now says 'Resep selesai' (got: '%s')" % status_lbl.text)

	if hud_node != null:
		hud_node.queue_free()
		await process_frame

	rm.free()
	inv.free()
	
	var ok: bool = (_failed_count == start_fails)
	if ok:
		print("<<< [PASS] Challenge 4: Status boundary verified — 'Siap dimasak' strictly enforced, NEVER premature 'Selesai'.")
	return ok

## CHALLENGE 5: Adversarial edge cases: Reservations & full capacity transfers
func _test_challenge_5_adversarial_reservations_and_full_capacity_transfers() -> bool:
	print("\n>>> [RUN] Challenge 5: Adversarial Edge Cases (Reservations & Capacity Gating)")
	var start_fails: int = _failed_count
	
	var inv: Node = _create_test_inventory()
	var rm: Node = _create_test_recipe_manager(inv)
	
	# Fill backpack with non-recipe items completely (12 slots, 20 items per slot = 240 items)
	for slot_idx in range(12):
		var slot = inv.backpack.get_slot(slot_idx)
		slot.item_id = "seed_bayam"
		slot.count = 20
	inv.backpack.contents_changed.emit()
	
	_record_assert(int(inv.backpack.get_empty_slot_count()) == 0, "Backpack has 0 empty slots")
	
	# Storage has recipe ingredients
	inv.add_items("storage", [
		{"item_id": "ingredient_bayam", "count": 3},
		{"item_id": "ingredient_jagung", "count": 1},
		{"item_id": "ingredient_temu_kunci", "count": 1}
	])
	
	rm.track_recipe("recipe_sayur_bening_01")
	
	# Verify even when backpack is 100% full, RecipeManager correctly counts storage ingredients and declares can_cook
	_record_assert(rm.get_available_ingredient_count("ingredient_bayam") == 3, "Storage items accessible when backpack full")
	_record_assert(rm.can_cook_recipe("recipe_sayur_bening_01") == true, "Recipe can cook from storage even when backpack full")
	
	# Attempt to transfer storage ingredient to full backpack -> Must be rejected cleanly
	var tr_res: Dictionary = inv.transfer_slot("storage", "backpack", 0)
	_record_assert(not tr_res.get("success", false), "Transfer to full backpack rejected cleanly")
	
	# Verify stock remains strictly invariant after rejected transfer
	_record_assert(rm.get_available_ingredient_count("ingredient_bayam") == 3, "Bayam invariant after rejected transfer")
	_record_assert(rm.can_cook_recipe("recipe_sayur_bening_01") == true, "can_cook invariant after rejected transfer")

	# Test kitchen reservation decrement & restoration
	var res_batch: Array[Dictionary] = [{"item_id": "ingredient_bayam", "count": 2}]
	var ok_res: Dictionary = inv.reserve_ingredients("test_job_1", res_batch)
	_record_assert(ok_res.get("success", false), "Reserve 2 bayam succeeds")
	
	# Free bayam should now be 3 - 2 = 1
	_record_assert(rm.get_available_ingredient_count("ingredient_bayam") == 1, "Reserved bayam decremented to 1")
	_record_assert(rm.can_cook_recipe("recipe_sayur_bening_01") == false, "Recipe cannot cook while bayam reserved")
	
	# Cancel reservation -> immediate restoration
	var ok_cancel: bool = inv.cancel_reservation("test_job_1")
	_record_assert(ok_cancel, "Cancel reservation succeeds")
	_record_assert(rm.get_available_ingredient_count("ingredient_bayam") == 3, "Bayam restored to 3 after cancellation")
	_record_assert(rm.can_cook_recipe("recipe_sayur_bening_01") == true, "Recipe cookable again")

	rm.free()
	inv.free()
	
	var ok: bool = (_failed_count == start_fails)
	if ok:
		print("<<< [PASS] Challenge 5: Adversarial edge cases passed.")
	return ok
