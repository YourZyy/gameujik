extends SceneTree

## Adversarial Inventory Challenge Harness (INV-001)
## Stress-testing edge cases, integrity boundaries, and failure modes

const InventoryManagerScript = preload("res://scripts/inventory/inventory_manager.gd")
const InventoryContainerScript = preload("res://scripts/inventory/inventory_container.gd")
const InventoryUIScript = preload("res://scripts/ui/inventory_ui.gd")

var total_assertions := 0
var passed_assertions := 0
var failed_assertions := 0

func _initialize() -> void:
	print("==================================================")
	print("[ADVERSARIAL_INVENTORY] Starting INV-001 Stress Harness...")
	print("==================================================")

	await run_all_challenges()

	print("==================================================")
	print("[ADVERSARIAL_INVENTORY] SUMMARY:")
	print("  Total Assertions:  %d" % total_assertions)
	print("  Passed Assertions: %d" % passed_assertions)
	print("  Failed Assertions: %d" % failed_assertions)
	if failed_assertions == 0:
		print("  VERDICT: ALL ADVERSARIAL CHALLENGES PASSED (Exit Code: 0)")
	else:
		print("  VERDICT: SOME CHALLENGES FAILED (Exit Code: 1)")
	print("==================================================")

	quit(1 if failed_assertions > 0 else 0)

func assert_test(cond: bool, msg: String) -> void:
	total_assertions += 1
	if cond:
		passed_assertions += 1
	else:
		failed_assertions += 1
		push_error("FAIL: %s" % msg)

func run_all_challenges() -> void:
	challenge_1_boundary_and_zero_inputs()
	challenge_2_partial_space_atomic_rejection()
	challenge_3_starter_crate_stack_merge_without_empty_slots()
	challenge_4_alias_resolution_consistency()
	challenge_5_cooking_reservations_edge_cases()
	await challenge_6_ui_and_bleedthrough_resilience()

## Challenge 1: Boundary and Zero/Negative Inputs
func challenge_1_boundary_and_zero_inputs() -> void:
	print("\n--- Challenge 1: Boundary, Zero and Negative Inputs ---")
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# 1.1 Add 0 items
	var ok0: bool = inv.add_items("backpack", [{"item_id": "seed_bayam", "count": 0}])
	assert_test(ok0, "Adding 0 items is a no-op that succeeds safely")
	assert_test(inv.backpack.get_item_count("seed_bayam") == 0, "Backpack still has 0 seeds after 0-count add")

	# 1.2 Add negative items
	var ok_neg: bool = inv.add_items("backpack", [{"item_id": "seed_bayam", "count": -5}])
	assert_test(ok_neg, "Adding negative count is ignored safely")
	assert_test(inv.backpack.get_item_count("seed_bayam") == 0, "Backpack still has 0 seeds after negative-count add")

	# 1.3 Remove items not present
	var ok_rem: bool = inv.remove_items("backpack", [{"item_id": "seed_bayam", "count": 5}])
	assert_test(not ok_rem, "Removing non-existent items fails cleanly")

	# 1.4 Single container clear integrity
	inv.add_items("backpack", [{"item_id": "seed_bayam", "count": 10}])
	assert_test(inv.backpack.get_item_count("seed_bayam") == 10, "10 seeds present")
	inv.backpack.clear()
	assert_test(inv.backpack.get_item_count("seed_bayam") == 0, "Clear empties all slots")
	assert_test(inv.backpack.get_empty_slot_count() == 12, "All 12 slots are empty")

	inv.free()

## Challenge 2: Partial Space Atomic Rejection (No Partial Mutations)
func challenge_2_partial_space_atomic_rejection() -> void:
	print("\n--- Challenge 2: Partial Space Atomic Rejection ---")
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# Fill chest so slot 0 has 18 seeds (space for 2), and remaining 11 slots are full with other items
	var s0 = inv.storage_home.get_slot(0)
	s0.item_id = "seed_bayam"
	s0.count = 18
	for i in range(1, 12):
		var s = inv.storage_home.get_slot(i)
		s.item_id = "filler_%d" % i
		s.count = 20

	assert_test(inv.storage_home.get_empty_slot_count() == 0, "Chest has 0 empty slots")
	assert_test(inv.storage_home.get_item_count("seed_bayam") == 18, "Chest slot 0 has 18 seeds")

	# Put 5 seeds into backpack slot 0
	var bp_s0 = inv.backpack.get_slot(0)
	bp_s0.item_id = "seed_bayam"
	bp_s0.count = 5
	assert_test(inv.backpack.get_item_count("seed_bayam") == 5, "Backpack has 5 seeds")

	# Attempt to transfer 5 seeds (chest only has room for 2)
	# Must be 100% rejected, no 2 seeds transferred!
	var ok_transfer: bool = inv.transfer_item("backpack", "storage", 0, 5)
	assert_test(not ok_transfer, "Transfer of 5 seeds to chest with room for 2 must fail")
	assert_test(inv.backpack.get_item_count("seed_bayam") == 5, "Backpack still has 5 seeds (zero loss)")
	assert_test(inv.storage_home.get_item_count("seed_bayam") == 18, "Chest still has 18 seeds (zero partial transfer)")

	# Now transfer exactly 2 seeds (should succeed)
	var ok_transfer2: bool = inv.transfer_item("backpack", "storage", 0, 2)
	assert_test(ok_transfer2, "Transfer of exactly 2 seeds into available space must succeed")
	assert_test(inv.backpack.get_item_count("seed_bayam") == 3, "Backpack has 3 seeds remaining")
	assert_test(inv.storage_home.get_item_count("seed_bayam") == 20, "Chest slot 0 is now exactly full (20 seeds)")

	inv.free()

## Challenge 3: Starter Crate Stack Merge Without Empty Slots
func challenge_3_starter_crate_stack_merge_without_empty_slots() -> void:
	print("\n--- Challenge 3: Starter Crate Merge Without Free Slots ---")
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# Configure backpack:
	# slot 0: 16 seed_bayam (space: 4)
	# slot 1: 19 soil_compost (space: 1)
	# slot 2: 19 fertilizer_basic (space: 1)
	# slots 3..11: full with other items (0 empty slots!)
	var s0 = inv.backpack.get_slot(0)
	s0.item_id = "seed_bayam"
	s0.count = 16
	var s1 = inv.backpack.get_slot(1)
	s1.item_id = "soil_compost"
	s1.count = 19
	var s2 = inv.backpack.get_slot(2)
	s2.item_id = "fertilizer_basic"
	s2.count = 19
	for i in range(3, 12):
		var s = inv.backpack.get_slot(i)
		s.item_id = "other_%d" % i
		s.count = 20

	assert_test(inv.backpack.get_empty_slot_count() == 0, "Backpack has 0 empty slots")

	# Starter crate requires 4 seeds, 1 compost, 1 fertilizer.
	# Even with 0 empty slots, existing stacks have exactly enough space!
	var ok_claim: bool = inv.pickup_starter_container()
	assert_test(ok_claim, "Starter crate pickup succeeds when existing stacks can absorb items without new slots")
	assert_test(inv.is_starter_collected(), "Starter claimed is true")
	assert_test(inv.backpack.get_item_count("seed_bayam") == 20, "Seeds merged to 20")
	assert_test(inv.backpack.get_item_count("soil_compost") == 20, "Compost merged to 20")
	assert_test(inv.backpack.get_item_count("fertilizer_basic") == 20, "Fertilizer merged to 20")

	inv.free()

## Challenge 4: Alias Resolution Consistency
func challenge_4_alias_resolution_consistency() -> void:
	print("\n--- Challenge 4: Alias Resolution Consistency ---")
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# In ItemsData:
	# crop_bayam -> ingredient_bayam
	# tool_fertilizer -> fertilizer_basic
	assert_test(inv.resolve_id("crop_bayam") == "ingredient_bayam", "crop_bayam resolves to ingredient_bayam")
	assert_test(inv.resolve_id("tool_fertilizer") == "fertilizer_basic", "tool_fertilizer resolves to fertilizer_basic")

	# Add canonical item
	inv.add_items("backpack", [{"item_id": "ingredient_bayam", "count": 7}])
	# Check query via canonical and alias
	assert_test(inv.get_available_item_count("ingredient_bayam") == 7, "Query canonical returns 7")
	assert_test(inv.get_available_item_count("crop_bayam") == 7, "Query alias returns 7")

	# Check item data lookup
	var def_canonical = inv.get_item_data("ingredient_bayam")
	var def_alias = inv.get_item_data("crop_bayam")
	assert_test(def_canonical != null, "Canonical item data found")
	assert_test(def_alias != null, "Alias item data found")
	assert_test(def_canonical == def_alias, "Canonical and alias return the same ItemData resource")

	inv.free()

## Challenge 5: Cooking Reservations Edge Cases
func challenge_5_cooking_reservations_edge_cases() -> void:
	print("\n--- Challenge 5: Cooking Reservations Edge Cases ---")
	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	inv.add_items("backpack", [{"item_id": "ingredient_bayam", "count": 3}])
	inv.add_items("storage", [{"item_id": "ingredient_jagung", "count": 1}])
	inv.add_items("backpack", [{"item_id": "ingredient_temu_kunci", "count": 1}])

	assert_test(inv.get_available_item_count("ingredient_bayam") == 3, "Bayam available = 3")
	assert_test(inv.get_available_item_count("ingredient_jagung") == 1, "Jagung available = 1")
	assert_test(inv.get_available_item_count("ingredient_temu_kunci") == 1, "Temu kunci available = 1")

	# Reserve recipe ingredients for job_01
	var job_items: Array[Dictionary] = [
		{"item_id": "ingredient_bayam", "count": 3},
		{"item_id": "ingredient_jagung", "count": 1},
		{"item_id": "ingredient_temu_kunci", "count": 1}
	]
	var res1: Dictionary = inv.reserve_ingredients("job_01", job_items)
	assert_test(res1.get("success", false), "Reservation succeeds")

	# Available counts should now be 0
	assert_test(inv.get_available_item_count("ingredient_bayam") == 0, "Bayam available is 0 under reservation")
	assert_test(inv.get_available_item_count("ingredient_jagung") == 0, "Jagung available is 0 under reservation")
	assert_test(inv.get_available_item_count("ingredient_temu_kunci") == 0, "Temu kunci available is 0 under reservation")

	# Duplicate reservation with same job_id fails
	var res_dup: Dictionary = inv.reserve_ingredients("job_01", job_items)
	assert_test(not res_dup.get("success", false), "Duplicate job ID reservation fails")

	# Second job cannot reserve because available is 0
	var res2: Dictionary = inv.reserve_ingredients("job_02", job_items)
	assert_test(not res2.get("success", false), "Job 2 fails because ingredients reserved")

	# Cancel reservation -> restores available counts
	inv.cancel_reservation("job_01")
	assert_test(inv.get_available_item_count("ingredient_bayam") == 3, "Bayam available restored to 3 after cancel")

	# Re-reserve and commit consumption
	inv.reserve_ingredients("job_03", job_items)
	inv.commit_consumption("job_03")
	assert_test(inv.backpack.get_item_count("ingredient_bayam") == 0, "Bayam consumed from backpack")
	assert_test(inv.storage_home.get_item_count("ingredient_jagung") == 0, "Jagung consumed from storage")
	assert_test(inv.backpack.get_item_count("ingredient_temu_kunci") == 0, "Temu kunci consumed from backpack")

	inv.free()

## Challenge 6: UI and Bleedthrough Resilience
func challenge_6_ui_and_bleedthrough_resilience() -> void:
	print("\n--- Challenge 6: UI and Bleedthrough Resilience ---")
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var input_mgr = tree.root.get_node_or_null("InputManager")
	assert_test(input_mgr != null, "InputManager autoload present")

	var ui_scene = load("res://scenes/ui/inventory_ui.tscn")
	var ui = ui_scene.instantiate() as CanvasLayer
	tree.root.add_child(ui)
	await tree.process_frame

	# Ensure starting state
	input_mgr.pop_to_world()
	assert_test(not ui.visible, "UI starts hidden")
	assert_test(input_mgr.can_interact_in_world(), "Can interact in world")

	# Rapid open-close cycle
	for cycle in range(5):
		input_mgr.push_context(input_mgr.ContextMode.STORAGE)
		assert_test(input_mgr.get_current_context() == input_mgr.ContextMode.STORAGE, "In STORAGE context cycle %d" % cycle)
		input_mgr.pop_context()
		assert_test(input_mgr.get_current_context() == input_mgr.ContextMode.WORLD, "In WORLD context cycle %d" % cycle)
		# On pop frame, bleed-through guard must be active
		assert_test(not input_mgr.can_interact_in_world(), "Bleedthrough blocked on pop frame cycle %d" % cycle)
		await tree.process_frame
		assert_test(input_mgr.can_interact_in_world(), "Interaction unblocked after 1 frame cycle %d" % cycle)

	ui.queue_free()
	await tree.process_frame
