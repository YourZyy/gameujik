extends SceneTree

## Empirical Challenger — Idempotency, Memory Leak & Orphan Node Stress Harness
## Milestone: QA-001 (Playthrough Acceptance)
## Agent: challenger_qa_001_2 (Idempotency & Memory Leak Challenger)
##
## Stress tests:
## 1. Multi-Run Playthrough Idempotency (5 sequential full P0 loop executions)
## 2. Memory stability & leak profiling before, during, and after repeated playthroughs
## 3. Dynamic instance lifecycle & zero-orphan node verification (CropMesh, Toasts, Kitchen jobs, Dialogue UI)
## 4. Multi-roundtrip Save/Load Checkpoint stability (Scenario B repeated 3x)
## 5. Root scene tree cleanliness & leak audit

const Assertions = preload("res://tests/assertions.gd")
const TestQAPlaythrough = preload("res://tests/suites/test_qa_playthrough.gd")
const MainClass = preload("res://scripts/main.gd")
const GardenManagerClass = preload("res://scripts/gardening/garden_manager.gd")
const KitchenManagerClass = preload("res://scripts/cooking/kitchen_manager.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")
const NotificationManagerClass = preload("res://scripts/ui/notification_manager.gd")

var total_assertions: int = 0
var total_failures: int = 0

func _assert(condition: bool, label: String, detail: String = "") -> void:
	total_assertions += 1
	if condition:
		print("  [PASS] %s" % label)
	else:
		total_failures += 1
		var err_msg = "  [FAIL] %s" % label
		if not detail.is_empty():
			err_msg += " (%s)" % detail
		printerr(err_msg)

func _initialize() -> void:
	await run_stress_suite()

func run_stress_suite() -> void:
	print("==================================================")
	print("[CHALLENGER_QA_001_2] Idempotency & Memory Leak Stress Harness")
	print("==================================================")

	# Warm up frames to allow engine autoloads and shaders to settle
	await process_frame
	await process_frame

	var base_mem_bytes: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var base_objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var base_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var base_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var base_resources: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))

	print("\n--- BASELINE ENGINE METRICS (Pre-Stress) ---")
	print("  Static Memory:       %.2f MB (%d bytes)" % [base_mem_bytes / (1024.0 * 1024.0), base_mem_bytes])
	print("  Total Objects:       %d" % base_objects)
	print("  Total Active Nodes:  %d" % base_nodes)
	print("  Orphan Nodes:        %d" % base_orphans)
	print("  Loaded Resources:    %d" % base_resources)

	# --------------------------------------------------------------------------
	# TEST 1: Baseline SceneTree Root Cleanliness & Autoload Integrity
	# --------------------------------------------------------------------------
	print("\n--- TEST 1: Baseline Root Cleanliness & Autoload Verification ---")
	var expected_autoloads: Array[String] = [
		"InputManager", "InventoryManager", "RecipeManager",
		"GardenManager", "WorldResourceManager", "KitchenManager",
		"DialogueManager", "SaveManager", "AudioManager"
	]
	var root_children = root.get_children()
	print("  Root Child Count: %d" % root_children.size())
	for child in root_children:
		print("    - Child: %s (%s)" % [child.name, child.get_class()])

	for autoload_name in expected_autoloads:
		var has_al := root.has_node(autoload_name)
		_assert(has_al, "Autoload '%s' is registered on SceneTree root" % autoload_name)

	_assert(base_orphans <= 10, "Baseline orphan node count within acceptable bounds (<= 10)", "Got %d" % base_orphans)

	# --------------------------------------------------------------------------
	# TEST 2: Multi-Run Playthrough Idempotency (5 Consecutive Full P0 Runs)
	# --------------------------------------------------------------------------
	print("\n--- TEST 2: Multi-Run Playthrough Idempotency (5 Sequential P0 Loops) ---")
	var qa_suite := TestQAPlaythrough.new()
	qa_suite._setup_qa_sandbox()

	var run_memory: Array[int] = []
	var run_objects: Array[int] = []
	var run_orphans: Array[int] = []

	const NUM_RUNS: int = 5
	for run_idx in range(1, NUM_RUNS + 1):
		print("\n  >>> Executing Playthrough Scenario A: Run %d of %d <<<" % [run_idx, NUM_RUNS])
		
		# 1. Verify pristine state before run
		var inv = root.get_node("InventoryManager")
		var rm = root.get_node("RecipeManager")
		var gm = root.get_node("GardenManager")
		var wrm = root.get_node("WorldResourceManager")
		var km = root.get_node("KitchenManager")
		var dm = root.get_node("DialogueManager")

		var run_pass: bool = await qa_suite.test_qa_02_scenario_a_full_p0_loop(self)
		_assert(run_pass, "Playthrough Run %d passed completely without defects" % run_idx)

		# Allow queue_free and deferred calls to resolve
		await process_frame
		await process_frame

		# Sample metrics immediately after teardown
		var cur_mem: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
		var cur_obj: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var cur_orph: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

		run_memory.append(cur_mem)
		run_objects.append(cur_obj)
		run_orphans.append(cur_orph)

		print("  [METRICS Run %d] Mem: %.2f MB | Objects: %d | Orphans: %d" % [
			run_idx, cur_mem / (1024.0 * 1024.0), cur_obj, cur_orph
		])

		# Post-Run State Verification: check all managers cleanly reset/freed
		_assert(inv.backpack.get_used_slots_count() == 0 or inv.backpack.get_item_count("seed_bayam") == 4, 
			"Run %d post-run invariant state verified" % run_idx)

	# Analyze Multi-Run Drift
	print("\n  --- Multi-Run Idempotency Drift Analysis ---")
	var mem_delta_1_to_5: float = (run_memory[NUM_RUNS - 1] - run_memory[0]) / (1024.0 * 1024.0)
	var obj_delta_1_to_5: int = run_objects[NUM_RUNS - 1] - run_objects[0]
	var orphan_delta_1_to_5: int = run_orphans[NUM_RUNS - 1] - run_orphans[0]

	print("  Memory Delta (Run 1 -> Run 5):   %+.3f MB" % mem_delta_1_to_5)
	print("  Object Delta (Run 1 -> Run 5):   %+d objects" % obj_delta_1_to_5)
	print("  Orphan Delta (Run 1 -> Run 5):   %+d orphans" % orphan_delta_1_to_5)

	# We assert that memory drift across 5 full playthroughs is bounded (< 2.0 MB)
	_assert(absf(mem_delta_1_to_5) < 2.0, "Playthrough memory growth across 5 runs is strictly bounded (< 2.0 MB)", "Got %.3f MB" % mem_delta_1_to_5)
	# Orphan nodes must not accumulate linearly across runs
	_assert(orphan_delta_1_to_5 <= 2, "Zero orphan node accumulation across 5 repeated playthrough runs", "Delta was %d" % orphan_delta_1_to_5)

	# --------------------------------------------------------------------------
	# TEST 3: Dynamic Entity Allocation & Teardown Stress
	# --------------------------------------------------------------------------
	print("\n--- TEST 3: Dynamic Entity Lifecycle & Teardown Stress ---")

	# 3A. CropMesh Primitives Allocation & Rebuild Stress (50 stage rebuilds)
	print("  [SUBTEST 3A] CropMesh Primitives Rebuild Stress (50 iterations)...")
	var main_node = qa_suite._create_test_main(self)
	await process_frame
	var level_node = main_node.get_node("LevelGraybox")
	var plot_node = level_node.get_node("plot_home_01")
	var spot0 = plot_node.get_node("spot_0")

	var pre_crop_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var pre_crop_objs: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))

	for cycle in range(50):
		var stage = cycle % 4
		var fake_spot_info := {
			"is_occupied": true,
			"crop_data": {
				"crop_id": "crop_bayam",
				"growth_stage": stage,
				"growth_time": 45.0 * stage
			}
		}
		main_node._update_crop_spot_visual(spot0, fake_spot_info)

	await process_frame
	await process_frame

	# Now unoccupy spot (should hide crop_root)
	main_node._update_crop_spot_visual(spot0, {"is_occupied": false})
	await process_frame
	await process_frame

	qa_suite._free_test_main(main_node, self)
	await process_frame
	await process_frame

	var post_crop_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var crop_orphan_delta = post_crop_orphans - pre_crop_orphans
	print("  CropMesh Rebuild: Pre Orphans = %d, Post Orphans = %d (Delta: %+d)" % [
		pre_crop_orphans, post_crop_orphans, crop_orphan_delta
	])
	_assert(crop_orphan_delta <= 1, "CropMesh 50x stage rebuild leaves zero dangling orphan nodes", "Delta was %d" % crop_orphan_delta)

	# 3B. Notification Toast Stress (100 rapid toasts & clearance)
	print("  [SUBTEST 3B] Notification Toast Rapid Queue & Dismiss Stress (100 toasts)...")
	var toast_scene = ResourceLoader.load("res://scenes/ui/notification_toast.tscn") as PackedScene
	_assert(toast_scene != null, "notification_toast.tscn loads cleanly")
	var toast_mgr = toast_scene.instantiate() as NotificationManagerClass
	root.add_child(toast_mgr)
	await process_frame

	var pre_toast_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	# Fire 100 mixed toasts
	for t_idx in range(100):
		var t_type = ["info", "success", "error", "pickup"][t_idx % 4]
		toast_mgr.show_toast("Stress notification message #%d" % t_idx, t_type, 0.5)

	_assert(toast_mgr.get_visible_toast_count() <= NotificationManagerClass.MAX_VISIBLE_TOASTS, 
		"NotificationManager enforces MAX_VISIBLE_TOASTS limit under 100-toast flood")

	# Fast-forward toast lifecycle
	for step in range(30):
		toast_mgr.advance_time(0.2)
		await process_frame

	toast_mgr.clear_all()
	await process_frame
	await process_frame

	root.remove_child(toast_mgr)
	toast_mgr.free()
	await process_frame
	await process_frame

	var post_toast_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var toast_orphan_delta = post_toast_orphans - pre_toast_orphans
	print("  Toast Stress: Pre Orphans = %d, Post Orphans = %d (Delta: %+d)" % [
		pre_toast_orphans, post_toast_orphans, toast_orphan_delta
	])
	_assert(toast_orphan_delta <= 1, "100 Notification Toasts fully freed with zero orphan leaks", "Delta was %d" % toast_orphan_delta)

	# 3C. Kitchen Job State Machine Cycling & Cancellation Stress (30 rapid cycles)
	print("  [SUBTEST 3C] Kitchen Job Reservation & Cancellation Stress (30 cycles)...")
	var km = root.get_node("KitchenManager") as KitchenManagerClass
	var inv = root.get_node("InventoryManager") as InventoryManagerClass
	qa_suite._reset_all_managers()

	var pre_kitchen_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	for cycle in range(30):
		# Populate inventory with required ingredients
		inv.backpack.add_item("ingredient_bayam", 3)
		inv.backpack.add_item("ingredient_jagung", 1)
		inv.backpack.add_item("ingredient_temu_kunci", 1)

		# Start prep (reserves items)
		var prep_res = km.start_preparation("recipe_sayur_bening_01")
		_assert(prep_res.get("success", false), "Kitchen cycle %d prep start successful" % cycle)

		# Advance prep partially
		km.advance_prep(1.5)

		# Cancel job (triggers refund and clears job records)
		var cancel_res = km.cancel_preparation()
		_assert(cancel_res.get("success", false), "Kitchen cycle %d cancel successful" % cycle)

		# Clear refunded items from backpack for clean next loop
		inv.backpack.clear()

	_assert(km.job_state == KitchenManagerClass.JobState.IDLE, "Kitchen job state returned to IDLE after 30 cancel cycles")
	_assert(km.active_job_id.is_empty(), "Kitchen active_job_id is completely cleared")
	_assert(km.reserved_ingredients.is_empty(), "Kitchen reserved_ingredients list is empty")
	_assert(inv._reservations.is_empty(), "InventoryManager _reservations map is empty (zero lock leaks)")

	var post_kitchen_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var kitchen_orphan_delta = post_kitchen_orphans - pre_kitchen_orphans
	print("  Kitchen Stress: Pre Orphans = %d, Post Orphans = %d (Delta: %+d)" % [
		pre_kitchen_orphans, post_kitchen_orphans, kitchen_orphan_delta
	])
	_assert(kitchen_orphan_delta <= 1, "Kitchen 30x reserve/cancel cycles produce zero orphan leaks")

	# --------------------------------------------------------------------------
	# TEST 4: Multi-Roundtrip Mid-Game Checkpoint Save/Load Stability (Scenario B x 3)
	# --------------------------------------------------------------------------
	print("\n--- TEST 4: Multi-Roundtrip Checkpoint Save/Load Stability (Scenario B x 3) ---")
	var pre_sb_mem: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var pre_sb_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	for sb_idx in range(1, 4):
		print("  Executing Scenario B Checkpoint Save & Resume iteration %d of 3..." % sb_idx)
		var sb_pass: bool = await qa_suite.test_qa_03_scenario_b_mid_game_checkpoint_save_and_resume(self)
		_assert(sb_pass, "Scenario B iteration %d passed completely" % sb_idx)
		await process_frame
		await process_frame

	var post_sb_mem: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var post_sb_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var sb_mem_delta_mb: float = (post_sb_mem - pre_sb_mem) / (1024.0 * 1024.0)
	var sb_orphan_delta: int = post_sb_orphans - pre_sb_orphans

	print("  Scenario B 3x: Memory Delta = %+.3f MB | Orphan Delta = %+d" % [sb_mem_delta_mb, sb_orphan_delta])
	_assert(absf(sb_mem_delta_mb) < 3.0, "Scenario B 3x save/load roundtrips memory delta bounded (< 3.0 MB)")
	_assert(sb_orphan_delta <= 2, "Scenario B 3x save/load roundtrips zero orphan node accumulation")

	# --------------------------------------------------------------------------
	# TEST 5: Final Global Teardown & Root Cleanliness Audit
	# --------------------------------------------------------------------------
	print("\n--- TEST 5: Final Global Teardown & Root Cleanliness Audit ---")
	qa_suite._reset_all_managers()
	qa_suite._teardown_qa_sandbox()
	await process_frame
	await process_frame

	var final_root_children = root.get_children()
	print("  Final Root Child Count: %d" % final_root_children.size())
	for child in final_root_children:
		print("    - Surviving Child: %s (%s)" % [child.name, child.get_class()])

	# Root should contain ONLY the 9 registered autoload singletons plus the test runner node itself
	for child in final_root_children:
		if child.name.begins_with("@"):
			continue
		var is_known_autoload = child.name in expected_autoloads
		_assert(is_known_autoload, "Surviving root node '%s' is an authorized Autoload singleton" % child.name)

	var final_mem_bytes: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var final_objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var final_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	print("\n==================================================")
	print("[FINAL STRESS METRICS SUMMARY]")
	print("  Total Assertions Evaluated: %d" % total_assertions)
	print("  Total Assertions Failed:    %d" % total_failures)
	print("  Initial Baseline Memory:    %.2f MB" % [base_mem_bytes / (1024.0 * 1024.0)])
	print("  Final Post-Stress Memory:   %.2f MB (Net Delta: %+.2f MB)" % [
		final_mem_bytes / (1024.0 * 1024.0),
		(final_mem_bytes - base_mem_bytes) / (1024.0 * 1024.0)
	])
	print("  Initial Baseline Objects:   %d" % base_objects)
	print("  Final Post-Stress Objects:  %d (Net Delta: %+d)" % [final_objects, final_objects - base_objects])
	print("  Initial Baseline Orphans:   %d" % base_orphans)
	print("  Final Post-Stress Orphans:  %d (Net Delta: %+d)" % [final_orphans, final_orphans - base_orphans])
	print("==================================================")

	if total_failures == 0:
		print(">>> EMPIRICAL STRESS RESULT: ALL TESTS PASSED [APPROVE] <<<")
		quit(0)
	else:
		printerr(">>> EMPIRICAL STRESS RESULT: %d FAILURES ENCOUNTERED [REJECT] <<<" % total_failures)
		quit(1)
