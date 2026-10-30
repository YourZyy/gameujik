class_name TestAdversarialChallengerSnapshotSignals
extends RefCounted

## Adversarial Challenger Suite (Iteration 2):
## 1. Boolean snapshot deserialization fuzzing & corruption resistance.
## 2. P0 closure signal deduplication across eat and share sequential permutations.

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const RecipeManagerClass = preload("res://scripts/recipe/recipe_manager.gd")
const WorldResourceManagerClass = preload("res://scripts/world/world_resource_manager.gd")
const KitchenManagerClass = preload("res://scripts/cooking/kitchen_manager.gd")
const DialogueManagerClass = preload("res://scripts/social/dialogue_manager.gd")

const DISH_ID: String = "dish_sayur_bening"
const RECIPE_P0_ID: String = "recipe_sayur_bening_01"

func run_all() -> bool:
	var passed := true
	print("==================================================")
	print("[ADVERSARIAL_SUITE] SOC-001 Snapshot Deserialization & P0 Signal Stress (Challenger R2)")
	print("==================================================")

	if not test_adv_snap01_extreme_distorted_boolean_types_fuzzing():
		passed = false

	if not test_adv_snap02_partial_snapshots_and_key_fallbacks():
		passed = false

	if not test_adv_sig01_eat_first_then_share_deduplication():
		passed = false

	if not test_adv_sig02_share_first_then_eat_deduplication():
		passed = false

	if not test_adv_sig03_alternating_50x_eat_and_share_contention_spam():
		passed = false

	if not test_adv_sig04_out_of_order_consumption_before_recipe_completion():
		passed = false

	if not test_adv_sig05_reentrancy_signal_safety():
		passed = false

	return passed

func _create_clean_env() -> Dictionary:
	var inv = InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.storage_home.clear()

	var rm = RecipeManagerClass.new()
	rm.set_inventory_manager(inv)
	rm._ready()

	var wrm = WorldResourceManagerClass.new()
	wrm._ready()
	wrm.set_meal_used(false)

	var km = KitchenManagerClass.new()
	km.set_inventory_manager(inv)
	km.set_recipe_manager(rm)
	km._ready()

	var dm = DialogueManagerClass.new()
	dm._ready()
	dm.bind_managers(inv, rm, wrm, km)

	return {
		"inv": inv,
		"rm": rm,
		"wrm": wrm,
		"km": km,
		"dm": dm
	}

func _cleanup_env(env: Dictionary) -> void:
	for key in env:
		var node = env[key]
		if node is Object and is_instance_valid(node):
			node.free()

# ==============================================================================
# SECTION 1: BOOLEAN DESERIALIZATION FUZZING & CORRUPTED SNAPSHOTS
# ==============================================================================

func test_adv_snap01_extreme_distorted_boolean_types_fuzzing() -> bool:
	print("  [RUN] ADV.CHAL-01: Extreme Distorted Boolean Types Fuzzing (_parse_bool_safe & load_save_snapshot)")
	var dm = DialogueManagerClass.new()
	dm._ready()

	# 1. Truthy String Variants
	var truthy_strings: Array[String] = [
		"true", "TRUE", "TrUe", "tRuE",
		" 1 ", "1", "yes", "YES", "Yes",
		"on", "ON", "On", "-1", "42", "999"
	]
	for s in truthy_strings:
		var snap := {
			"version": 1,
			"has_spoken_intro": s,
			"has_shared_meal": s,
			"meal_used": s,
			"p0_completed": s
		}
		var ok := dm.load_save_snapshot(snap)
		Assertions.assert_true(ok, "ADV.CHAL-01: Load snapshot with truthy string '%s' succeeded" % s)
		Assertions.assert_true(dm.has_spoken_intro, "ADV.CHAL-01: has_spoken_intro is true for '%s'" % s)
		Assertions.assert_true(dm.has_shared_meal(), "ADV.CHAL-01: has_shared_meal is true for '%s'" % s)
		Assertions.assert_true(dm.meal_used, "ADV.CHAL-01: meal_used is true for '%s'" % s)
		Assertions.assert_true(dm.p0_completed, "ADV.CHAL-01: p0_completed is true for '%s'" % s)

	# 2. Falsy String Variants
	var falsy_strings: Array[String] = [
		"false", "FALSE", "FaLsE", "fAlSe",
		" 0 ", "0", "no", "NO", "No",
		"off", "OFF", "Off"
	]
	for s in falsy_strings:
		var snap := {
			"version": 1,
			"has_spoken_intro": s,
			"has_shared_meal": s,
			"meal_used": s,
			"p0_completed": s
		}
		var ok := dm.load_save_snapshot(snap)
		Assertions.assert_true(ok, "ADV.CHAL-01: Load snapshot with falsy string '%s' succeeded" % s)
		Assertions.assert_false(dm.has_spoken_intro, "ADV.CHAL-01: has_spoken_intro is false for '%s'" % s)
		Assertions.assert_false(dm.has_shared_meal(), "ADV.CHAL-01: has_shared_meal is false for '%s'" % s)
		Assertions.assert_false(dm.meal_used, "ADV.CHAL-01: meal_used is false for '%s'" % s)
		Assertions.assert_false(dm.p0_completed, "ADV.CHAL-01: p0_completed is false for '%s'" % s)

	# 3. Numeric Values (Integers & Floats)
	var truthy_nums: Array = [1, -1, 100, -99999, 1.0, -0.5, 0.0001]
	for n in truthy_nums:
		var snap := {
			"version": 1,
			"has_spoken_intro": n,
			"has_shared_meal": n,
			"meal_used": n,
			"p0_completed": n
		}
		var ok := dm.load_save_snapshot(snap)
		Assertions.assert_true(ok, "ADV.CHAL-01: Load snapshot with truthy numeric '%s' succeeded" % str(n))
		Assertions.assert_true(dm.has_spoken_intro, "ADV.CHAL-01: has_spoken_intro true for numeric %s" % str(n))
		Assertions.assert_true(dm.p0_completed, "ADV.CHAL-01: p0_completed true for numeric %s" % str(n))

	var falsy_nums: Array = [0, 0.0]
	for n in falsy_nums:
		var snap := {
			"version": 1,
			"has_spoken_intro": n,
			"has_shared_meal": n,
			"meal_used": n,
			"p0_completed": n
		}
		var ok := dm.load_save_snapshot(snap)
		Assertions.assert_true(ok, "ADV.CHAL-01: Load snapshot with zero numeric '%s' succeeded" % str(n))
		Assertions.assert_false(dm.has_spoken_intro, "ADV.CHAL-01: has_spoken_intro false for zero %s" % str(n))
		Assertions.assert_false(dm.p0_completed, "ADV.CHAL-01: p0_completed false for zero %s" % str(n))

	# 4. Complex Non-Primitive Objects & Garbage Strings (Safe Default Fallback)
	var garbage_inputs: Array = [
		"garbage_text", "undefined", "null_as_string", "", "   ",
		[1, 2, 3], {"nested": "dict"}, Vector2(10.0, 20.0),
		Vector3(1.0, 2.0, 3.0), Color.RED, RefCounted.new()
	]
	for g in garbage_inputs:
		var snap := {
			"version": 1,
			"has_spoken_intro": g,
			"has_shared_meal": g,
			"meal_used": g,
			"p0_completed": g
		}
		var ok := dm.load_save_snapshot(snap)
		Assertions.assert_true(ok, "ADV.CHAL-01: Garbage input %s safely loaded" % str(g))
		Assertions.assert_false(dm.has_spoken_intro, "ADV.CHAL-01: has_spoken_intro safely defaulted to false")
		Assertions.assert_false(dm.has_shared_meal(), "ADV.CHAL-01: has_shared_meal safely defaulted to false")
		Assertions.assert_false(dm.meal_used, "ADV.CHAL-01: meal_used safely defaulted to false")
		Assertions.assert_false(dm.p0_completed, "ADV.CHAL-01: p0_completed safely defaulted to false")

	dm.free()
	print("  [PASS] ADV.CHAL-01: Extreme Distorted Boolean Types Fuzzing verified.")
	return true

func test_adv_snap02_partial_snapshots_and_key_fallbacks() -> bool:
	print("  [RUN] ADV.CHAL-02: Partial Snapshots, Legacy Key Fallbacks & Flag Resilience")
	var dm = DialogueManagerClass.new()
	dm._ready()

	# 1. Fallback: talked_to_npc -> has_spoken_intro
	var snap_fallback_intro := {
		"version": 1,
		"talked_to_npc": "true"
	}
	Assertions.assert_true(dm.load_save_snapshot(snap_fallback_intro), "ADV.CHAL-02: Legacy talked_to_npc loaded")
	Assertions.assert_true(dm.has_spoken_intro, "ADV.CHAL-02: has_spoken_intro resolved from talked_to_npc")
	Assertions.assert_false(dm.has_shared_meal(), "ADV.CHAL-02: has_shared_meal defaults false")

	# 2. Fallback: has_shared -> has_shared_meal
	var snap_fallback_shared := {
		"version": 1,
		"has_shared": 1
	}
	Assertions.assert_true(dm.load_save_snapshot(snap_fallback_shared), "ADV.CHAL-02: Legacy has_shared loaded")
	Assertions.assert_true(dm.has_shared_meal(), "ADV.CHAL-02: has_shared_meal resolved from has_shared")

	# 3. Corrupt dialogue_flags (String / Int / Array / Null)
	var bad_flags: Array = ["corrupt_string", 12345, [1, 2], null]
	for bf in bad_flags:
		var snap_bad_flag := {
			"version": 1,
			"dialogue_flags": bf
		}
		Assertions.assert_true(dm.load_save_snapshot(snap_bad_flag), "ADV.CHAL-02: Corrupt dialogue_flags parsed safely")
		Assertions.assert_equal(dm.dialogue_flags.size(), 0, "ADV.CHAL-02: dialogue_flags cleared safely")

	# 4. Valid dialogue_flags Duplication Isolation
	var original_flags: Dictionary = {"flag_a": 100, "flag_b": "active"}
	var snap_flags := {
		"version": 1,
		"dialogue_flags": original_flags
	}
	Assertions.assert_true(dm.load_save_snapshot(snap_flags), "ADV.CHAL-02: Valid dialogue_flags loaded")
	Assertions.assert_equal(dm.dialogue_flags.get("flag_a"), 100, "ADV.CHAL-02: flag_a copied")
	original_flags["flag_a"] = 999
	Assertions.assert_equal(dm.dialogue_flags.get("flag_a"), 100, "ADV.CHAL-02: Deep copy prevents mutation")

	# 5. Injected Alien Keys (1,000 keys fuzzing)
	var alien_snap: Dictionary = {"version": 1}
	for i in range(1000):
		alien_snap["alien_key_%d" % i] = "alien_val_%d" % i
	Assertions.assert_true(dm.load_save_snapshot(alien_snap), "ADV.CHAL-02: 1000 alien keys loaded without crashing")

	dm.free()
	print("  [PASS] ADV.CHAL-02: Partial Snapshots, Legacy Key Fallbacks & Flag Resilience verified.")
	return true

# ==============================================================================
# SECTION 2: P0 CLOSURE SIGNAL DEDUPLICATION ACROSS SEQUENCES
# ==============================================================================

func test_adv_sig01_eat_first_then_share_deduplication() -> bool:
	print("  [RUN] ADV.CHAL-03: Sequential Calling: Eat Dish First, Then Share Dish (Strict Deduplication)")
	var env := _create_clean_env()
	var inv = env["inv"]
	var rm = env["rm"]
	var km = env["km"]
	var dm = env["dm"]

	rm.mark_recipe_completed(RECIPE_P0_ID)
	inv.backpack.add_item(DISH_ID, 2)

	var signal_log: Dictionary = {
		"km_p0": 0,
		"dm_p0": 0,
		"km_consumed": 0,
		"dm_shared": 0
	}

	km.p0_experience_completed.connect(func(): signal_log["km_p0"] += 1)
	dm.p0_experience_completed.connect(func(_msg): signal_log["dm_p0"] += 1)
	km.dish_consumed.connect(func(_it): signal_log["km_consumed"] += 1)
	dm.dish_shared.connect(func(_it, _cnt, _src): signal_log["dm_shared"] += 1)

	# STEP 1: Pemain makan hidangan pertama langsung dari tas
	var eat_res: Dictionary = km.eat_dish(DISH_ID)
	Assertions.assert_true(eat_res.get("success", false), "ADV.CHAL-03: eat_dish sukses")
	Assertions.assert_equal(signal_log["km_consumed"], 1, "ADV.CHAL-03: km dish_consumed emitted 1x")
	Assertions.assert_equal(signal_log["km_p0"], 1, "ADV.CHAL-03: km p0_experience_completed emitted 1x upon eating")
	Assertions.assert_equal(signal_log["dm_p0"], 0, "ADV.CHAL-03: dm p0_experience_completed NOT yet emitted")
	Assertions.assert_true(km.is_p0_completed(), "ADV.CHAL-03: km.is_p0_completed is true")
	Assertions.assert_true(dm.is_p0_completed(), "ADV.CHAL-03: dm.is_p0_completed bilateral sync is true")
	Assertions.assert_equal(inv.backpack.get_item_count(DISH_ID), 1, "ADV.CHAL-03: Sisa 1 porsi hidangan di tas")

	# STEP 2: Pemain membagikan hidangan kedua kepada tetangga
	var share_res: Dictionary = dm.share_dish("backpack")
	Assertions.assert_true(share_res.get("success", false), "ADV.CHAL-03: share_dish sukses")
	Assertions.assert_equal(signal_log["dm_shared"], 1, "ADV.CHAL-03: dm dish_shared emitted 1x")
	Assertions.assert_equal(inv.backpack.get_item_count(DISH_ID), 0, "ADV.CHAL-03: Sisa 0 porsi hidangan di tas")
	Assertions.assert_true(dm.has_shared_meal(), "ADV.CHAL-03: has_shared_meal is true")

	# ORACLE DEDUPLIKASI:
	Assertions.assert_equal(signal_log["dm_p0"], 0, "ADV.CHAL-03: dm p0_experience_completed is DEDUPLICATED (0x)")
	Assertions.assert_equal(signal_log["km_p0"], 1, "ADV.CHAL-03: km p0_experience_completed remains strictly 1x")
	var total_p0_signals: int = signal_log["km_p0"] + signal_log["dm_p0"]
	Assertions.assert_equal(total_p0_signals, 1, "ADV.CHAL-03: TOTAL P0 CLOSURE SIGNALS ACROSS SYSTEM IS EXACTLY 1")

	# STEP 3: Panggilan ulang makan & berbagi ketika stok habis / sudah berbagi
	var repeat_eat: Dictionary = km.eat_dish(DISH_ID)
	Assertions.assert_false(repeat_eat.get("success", true), "ADV.CHAL-03: repeat eat rejected (empty bag)")
	var repeat_share: Dictionary = dm.share_dish("auto")
	Assertions.assert_false(repeat_share.get("success", true), "ADV.CHAL-03: repeat share rejected (already shared)")
	Assertions.assert_equal(signal_log["km_p0"] + signal_log["dm_p0"], 1, "ADV.CHAL-03: Still exactly 1 P0 signal")

	_cleanup_env(env)
	print("  [PASS] ADV.CHAL-03: Sequential Calling: Eat First, Then Share verified.")
	return true

func test_adv_sig02_share_first_then_eat_deduplication() -> bool:
	print("  [RUN] ADV.CHAL-04: Sequential Calling: Share Dish First, Then Eat Dish (Strict Deduplication)")
	var env := _create_clean_env()
	var inv = env["inv"]
	var rm = env["rm"]
	var km = env["km"]
	var dm = env["dm"]

	rm.mark_recipe_completed(RECIPE_P0_ID)
	inv.backpack.add_item(DISH_ID, 2)

	var signal_log: Dictionary = {
		"km_p0": 0,
		"dm_p0": 0,
		"km_consumed": 0,
		"dm_shared": 0
	}

	km.p0_experience_completed.connect(func(): signal_log["km_p0"] += 1)
	dm.p0_experience_completed.connect(func(_msg): signal_log["dm_p0"] += 1)
	km.dish_consumed.connect(func(_it): signal_log["km_consumed"] += 1)
	dm.dish_shared.connect(func(_it, _cnt, _src): signal_log["dm_shared"] += 1)

	# STEP 1: Pemain membagikan hidangan pertama kepada tetangga
	var share_res: Dictionary = dm.share_dish("backpack")
	Assertions.assert_true(share_res.get("success", false), "ADV.CHAL-04: share_dish sukses")
	Assertions.assert_equal(signal_log["dm_shared"], 1, "ADV.CHAL-04: dm dish_shared emitted 1x")
	Assertions.assert_equal(signal_log["dm_p0"], 1, "ADV.CHAL-04: dm p0_experience_completed emitted 1x upon sharing")
	Assertions.assert_equal(signal_log["km_p0"], 0, "ADV.CHAL-04: km p0_experience_completed NOT yet emitted")
	Assertions.assert_true(dm.is_p0_completed(), "ADV.CHAL-04: dm.is_p0_completed is true")
	Assertions.assert_true(km.is_p0_completed(), "ADV.CHAL-04: km.is_p0_completed bilateral sync is true")
	Assertions.assert_equal(inv.backpack.get_item_count(DISH_ID), 1, "ADV.CHAL-04: Sisa 1 porsi hidangan di tas")

	# STEP 2: Pemain memakan hidangan kedua dari tas
	var eat_res: Dictionary = km.eat_dish(DISH_ID)
	Assertions.assert_true(eat_res.get("success", false), "ADV.CHAL-04: eat_dish sukses")
	Assertions.assert_equal(signal_log["km_consumed"], 1, "ADV.CHAL-04: km dish_consumed emitted 1x")
	Assertions.assert_equal(inv.backpack.get_item_count(DISH_ID), 0, "ADV.CHAL-04: Sisa 0 porsi hidangan di tas")

	# ORACLE DEDUPLIKASI:
	Assertions.assert_equal(signal_log["km_p0"], 0, "ADV.CHAL-04: km p0_experience_completed is DEDUPLICATED (0x)")
	Assertions.assert_equal(signal_log["dm_p0"], 1, "ADV.CHAL-04: dm p0_experience_completed remains strictly 1x")
	var total_p0_signals: int = signal_log["km_p0"] + signal_log["dm_p0"]
	Assertions.assert_equal(total_p0_signals, 1, "ADV.CHAL-04: TOTAL P0 CLOSURE SIGNALS ACROSS SYSTEM IS EXACTLY 1")

	_cleanup_env(env)
	print("  [PASS] ADV.CHAL-04: Sequential Calling: Share First, Then Eat verified.")
	return true

func test_adv_sig03_alternating_50x_eat_and_share_contention_spam() -> bool:
	print("  [RUN] ADV.CHAL-05: 100 Panggilan Berselingan (50x eat_dish + 50x share_dish) Kontensi Spam")
	var env := _create_clean_env()
	var inv = env["inv"]
	var rm = env["rm"]
	var km = env["km"]
	var dm = env["dm"]

	rm.mark_recipe_completed(RECIPE_P0_ID)
	inv.backpack.add_item(DISH_ID, 5)
	inv.storage_home.add_item(DISH_ID, 5)

	var signal_log: Dictionary = {
		"km_p0": 0,
		"dm_p0": 0
	}
	km.p0_experience_completed.connect(func(): signal_log["km_p0"] += 1)
	dm.p0_experience_completed.connect(func(_msg): signal_log["dm_p0"] += 1)

	var successful_eats: int = 0
	var successful_shares: int = 0

	for i in range(50):
		var res_eat = km.eat_dish(DISH_ID)
		if res_eat.get("success", false):
			successful_eats += 1

		var res_share = dm.share_dish("auto")
		if res_share.get("success", false):
			successful_shares += 1

	# ORACLE:
	# Berbagi hanya boleh sukses tepat 1 kali (kebijakan anti-spam wajar tetangga)
	Assertions.assert_equal(successful_shares, 1, "ADV.CHAL-05: share_dish sukses tepat 1 kali")
	# Makan menghabiskan hidangan di tas (5 porsi awal - 1 porsi dibagikan dari tas jika auto memilih tas)
	Assertions.assert_gt(successful_eats, 0, "ADV.CHAL-05: Minimal 1 porsi hidangan berhasil dimakan")
	Assertions.assert_equal(signal_log["km_p0"] + signal_log["dm_p0"], 1, "ADV.CHAL-05: Total sinyal P0 penutup TEPAT 1 KALI dalam 100x spam!")
	Assertions.assert_true(dm.p0_completed, "ADV.CHAL-05: dm.p0_completed is true")
	Assertions.assert_true(km.p0_completed, "ADV.CHAL-05: km.p0_completed is true")

	_cleanup_env(env)
	print("  [PASS] ADV.CHAL-05: Alternating 50x Eat & Share Contention Spam verified.")
	return true

func test_adv_sig04_out_of_order_consumption_before_recipe_completion() -> bool:
	print("  [RUN] ADV.CHAL-06: Out-of-Order Consumption Before Recipe Completion")
	var env := _create_clean_env()
	var inv = env["inv"]
	var rm = env["rm"]
	var km = env["km"]
	var dm = env["dm"]

	# Resep BELUM selesai
	inv.backpack.add_item(DISH_ID, 2)

	var signal_log: Dictionary = {
		"km_p0": 0,
		"dm_p0": 0
	}
	km.p0_experience_completed.connect(func(): signal_log["km_p0"] += 1)
	dm.p0_experience_completed.connect(func(_msg): signal_log["dm_p0"] += 1)

	# 1. Makan sebelum resep selesai
	var eat_res: Dictionary = km.eat_dish(DISH_ID)
	Assertions.assert_true(eat_res.get("success", false), "ADV.CHAL-06: eat_dish sukses dimakan")
	Assertions.assert_true(km.meal_used, "ADV.CHAL-06: km.meal_used true")
	Assertions.assert_false(km.is_p0_completed(), "ADV.CHAL-06: km p0_completed TETAP FALSE karena resep belum selesai")
	Assertions.assert_false(dm.is_p0_completed(), "ADV.CHAL-06: dm p0_completed TETAP FALSE")
	Assertions.assert_equal(signal_log["km_p0"] + signal_log["dm_p0"], 0, "ADV.CHAL-06: 0 sinyal terpancar sebelum resep selesai")

	# 2. Berbagi sebelum resep selesai
	var share_res: Dictionary = dm.share_dish("backpack")
	Assertions.assert_true(share_res.get("success", false), "ADV.CHAL-06: share_dish sukses dibagikan")
	Assertions.assert_true(dm.has_shared_meal(), "ADV.CHAL-06: has_shared_meal true")
	Assertions.assert_false(dm.is_p0_completed(), "ADV.CHAL-06: dm p0_completed TETAP FALSE")
	Assertions.assert_equal(signal_log["km_p0"] + signal_log["dm_p0"], 0, "ADV.CHAL-06: Masih 0 sinyal terpancar")

	# 3. Sekarang resep diselesaikan
	rm.mark_recipe_completed(RECIPE_P0_ID)

	# 4. Evaluasi penutup P0
	var closed: bool = dm.evaluate_p0_closure()
	Assertions.assert_true(closed, "ADV.CHAL-06: evaluate_p0_closure returns true pasca resep selesai")
	Assertions.assert_equal(signal_log["dm_p0"], 1, "ADV.CHAL-06: dm p0_experience_completed terpancar tepat 1 kali")
	Assertions.assert_equal(signal_log["km_p0"], 0, "ADV.CHAL-06: km p0_experience_completed 0")

	# 5. Evaluasi ulang tidak boleh memancarkan sinyal kedua
	dm.evaluate_p0_closure()
	Assertions.assert_equal(signal_log["dm_p0"], 1, "ADV.CHAL-06: evaluate_p0_closure redundant call emitted 0 additional signals")

	_cleanup_env(env)
	print("  [PASS] ADV.CHAL-06: Out-of-Order Consumption Before Recipe Completion verified.")
	return true

func test_adv_sig05_reentrancy_signal_safety() -> bool:
	print("  [RUN] ADV.CHAL-07: Re-Entrancy & Signal Listener Cross-Invocation Safety")
	var env := _create_clean_env()
	var inv = env["inv"]
	var rm = env["rm"]
	var km = env["km"]
	var dm = env["dm"]

	rm.mark_recipe_completed(RECIPE_P0_ID)
	inv.backpack.add_item(DISH_ID, 5)

	var reentrant_state: Dictionary = {
		"reentrant_calls": 0,
		"total_p0_emissions": 0
	}

	# Ketika dm memancarkan p0_experience_completed, listener mencoba memanggil km.eat_dish() dan dm.share_dish()
	dm.p0_experience_completed.connect(func(_msg):
		reentrant_state["total_p0_emissions"] += 1
		reentrant_state["reentrant_calls"] += 1
		var _res1: Dictionary = km.eat_dish(DISH_ID)
		var _res2: Dictionary = dm.share_dish("backpack")
	)

	# Ketika km memancarkan p0_experience_completed, listener mencoba memanggil dm.share_dish() dan km.eat_dish()
	km.p0_experience_completed.connect(func():
		reentrant_state["total_p0_emissions"] += 1
		reentrant_state["reentrant_calls"] += 1
		var _res3: Dictionary = dm.share_dish("backpack")
		var _res4: Dictionary = km.eat_dish(DISH_ID)
	)

	# Picu aksi pertama: share_dish
	var primary_share: Dictionary = dm.share_dish("backpack")
	Assertions.assert_true(primary_share.get("success", false), "ADV.CHAL-07: Panggilan share utama sukses")
	Assertions.assert_equal(reentrant_state["total_p0_emissions"], 1, "ADV.CHAL-07: Tepat 1 emisi p0_experience_completed terpancar (tidak ada infinite loop / cascade)")
	Assertions.assert_gt(reentrant_state["reentrant_calls"], 0, "ADV.CHAL-07: Hook reentrant dieksekusi")

	_cleanup_env(env)
	print("  [PASS] ADV.CHAL-07: Re-Entrancy & Signal Listener Safety verified.")
	return true
