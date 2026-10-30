extends SceneTree

## Dedicated Stress Harness for HUD Quest Tracker Dynamic Updates and Input Context Switching
## Milestone BOOK-001 (Buku Resep dan Tracker)
## Challenger Agent: challenger_book_001_2

const InventoryManagerScript = preload("res://scripts/inventory/inventory_manager.gd")
const RecipeManagerScript = preload("res://scripts/recipe/recipe_manager.gd")
const InputManagerScript = preload("res://scripts/core/input_manager.gd")
const PlayerControllerScript = preload("res://scripts/player/player_controller.gd")
const InteractionDetectorScript = preload("res://scripts/interaction/interaction_detector.gd")
const InteractableScript = preload("res://scripts/interaction/interactable.gd")

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var detected_defects: Array[Dictionary] = []

func _initialize() -> void:
	print("================================================================================")
	print("[CHALLENGER_BOOK_001_2] STARTING EMPIRICAL STRESS & VERIFICATION HARNESS")
	print("================================================================================")

	await test_suite_1_hud_dynamic_tracker_progression()
	await test_suite_2_context_switching_100_toggles()
	await test_suite_3_click_bleed_through_world_oracle()
	await test_suite_4_modal_exclusivity_and_stack_integrity()
	await test_suite_5_main_scene_input_dispatch_empirical_challenge()

	print("\n================================================================================")
	print("[CHALLENGER_BOOK_001_2] HARNESS EXECUTION SUMMARY")
	print("  Total Assertions Checked : %d" % total_assertions)
	print("  Assertions Passed        : %d" % passed_assertions)
	print("  Assertions Failed        : %d" % failed_assertions)
	print("  Defects Detected Count   : %d" % detected_defects.size())

	if detected_defects.size() > 0:
		print("\n[CHALLENGER_BOOK_001_2] CONFIRMED EMPIRICAL DEFECTS:")
		for i in range(detected_defects.size()):
			var d: Dictionary = detected_defects[i]
			print("  Defect #%d [%s]: %s" % [i + 1, d.get("severity", "MEDIUM"), d.get("title", "")])
			print("    Description: %s" % d.get("description", ""))
			print("    Reproduction: %s" % d.get("reproduction", ""))
			print("    Location: %s" % d.get("location", ""))
	print("================================================================================")

	# Non-zero exit code if failures/defects encountered
	quit(1 if failed_assertions > 0 else 0)

func check(condition: bool, test_name: String, failure_detail: String = "") -> bool:
	total_assertions += 1
	if condition:
		passed_assertions += 1
		return true
	else:
		failed_assertions += 1
		printerr("  [ASSERT FAIL] %s%s" % [test_name, " -> " + failure_detail if not failure_detail.is_empty() else ""])
		return false

func record_defect(title: String, severity: String, description: String, reproduction: String, location: String) -> void:
	detected_defects.append({
		"title": title,
		"severity": severity,
		"description": description,
		"reproduction": reproduction,
		"location": location
	})

# ==============================================================================
# SUITE 1: HUD Dynamic Tracker Progression & Zero Desync Oracle
# ==============================================================================
func test_suite_1_hud_dynamic_tracker_progression() -> void:
	print("\n--- SUITE 1: Dynamic Tracker State Progression & Zero Desync ---")

	var hud_scene = load("res://scenes/ui/hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	await process_frame

	var inv: Node = root.get_node_or_null("InventoryManager")
	var rm: Node = root.get_node_or_null("RecipeManager")

	var is_local_inv := false
	var is_local_rm := false
	if inv == null:
		inv = InventoryManagerScript.new()
		inv._ready()
		is_local_inv = true
	if rm == null:
		rm = RecipeManagerScript.new()
		rm.set_inventory_manager(inv)
		rm._ready()
		is_local_rm = true

	# Reset inventory & recipe manager state
	inv.backpack.clear()
	inv.storage_home.clear()
	inv.kitchen_refund.clear()
	rm.untrack_recipe()
	rm.set_cooking_state("idle")
	hud.set_recipe_manager(rm)
	hud.refresh_tracker()
	await process_frame

	var untracked_c: Control = hud.find_child("UntrackedContainer", true, false) as Control
	var tracked_c: Control = hud.find_child("TrackedContainer", true, false) as Control
	var untracked_lbl: Label = hud.find_child("UntrackedLabel", true, false) as Label
	var title_lbl: Label = hud.find_child("RecipeTitleLabel", true, false) as Label
	var bayam_row: Label = hud.find_child("BayamRow", true, false) as Label
	var jagung_row: Label = hud.find_child("JagungRow", true, false) as Label
	var temu_row: Label = hud.find_child("TemuKunciRow", true, false) as Label
	var status_lbl: Label = hud.find_child("TrackerStatusLabel", true, false) as Label

	# 1.1 Untracked Baseline
	print("  [1.1] Verifying Untracked Baseline...")
	check(untracked_c.visible == true, "1.1 UntrackedContainer visible when no recipe tracked")
	check(tracked_c.visible == false, "1.1 TrackedContainer hidden when no recipe tracked")
	check(untracked_lbl.text == "Buka buku [B] untuk memilih masakan.", "1.1 UntrackedLabel text matches spec", "Got: '%s'" % untracked_lbl.text)

	# 1.2 Track Recipe Initial (0 ingredients)
	print("  [1.2] Verifying Tracked Initial State (0/3, 0/1, 0/1)...")
	rm.track_recipe("recipe_sayur_bening_01")
	await process_frame

	check(untracked_c.visible == false, "1.2 UntrackedContainer hidden after track")
	check(tracked_c.visible == true, "1.2 TrackedContainer visible after track")
	check(title_lbl.text == "Sayur Bening Bayam dan Jagung", "1.2 Title label displays recipe name", "Got: '%s'" % title_lbl.text)
	check(bayam_row.text == "• Bayam: 0/3", "1.2 Bayam initial row '• Bayam: 0/3'", "Got: '%s'" % bayam_row.text)
	check(jagung_row.text == "• Jagung: 0/1", "1.2 Jagung initial row '• Jagung: 0/1'", "Got: '%s'" % jagung_row.text)
	check(temu_row.text == "• Temu Kunci: 0/1", "1.2 Temu Kunci initial row '• Temu Kunci: 0/1'", "Got: '%s'" % temu_row.text)
	check(status_lbl.visible == false or status_lbl.text == "", "1.2 Status label hidden initially (not ready)")
	check(bayam_row.modulate != Color(0.4, 0.95, 0.4), "1.2 Bayam row not green when 0/3")

	# 1.3 Incremental Additions & Multi-Container Free Stock
	print("  [1.3] Verifying Increments Across Backpack & Storage...")
	# Add 1 bayam to backpack
	inv.add_items("backpack", [{"item_id": "ingredient_bayam", "count": 1}])
	await process_frame
	check(bayam_row.text == "• Bayam: 1/3", "1.3 Bayam incremented to 1/3 in backpack", "Got: '%s'" % bayam_row.text)

	# Add 1 bayam to storage
	inv.add_items("storage", [{"item_id": "ingredient_bayam", "count": 1}])
	await process_frame
	check(bayam_row.text == "• Bayam: 2/3", "1.3 Bayam incremented to 2/3 (split backpack+storage)", "Got: '%s'" % bayam_row.text)

	# Add 1 more bayam to storage (total 3)
	inv.add_items("storage", [{"item_id": "ingredient_bayam", "count": 1}])
	await process_frame
	check(bayam_row.text == "• Bayam: 3/3", "1.3 Bayam reached 3/3", "Got: '%s'" % bayam_row.text)
	check(bayam_row.modulate == Color(0.4, 0.95, 0.4), "1.3 Bayam modulate turns green at 3/3")
	check(status_lbl.visible == false or status_lbl.text == "", "1.3 Status still hidden because corn & temu kunci not met")

	# Add 1 jagung
	inv.add_items("backpack", [{"item_id": "ingredient_jagung", "count": 1}])
	await process_frame
	check(jagung_row.text == "• Jagung: 1/1", "1.3 Jagung reached 1/1", "Got: '%s'" % jagung_row.text)
	check(jagung_row.modulate == Color(0.4, 0.95, 0.4), "1.3 Jagung modulate turns green at 1/1")
	check(status_lbl.visible == false or status_lbl.text == "", "1.3 Status still hidden because temu kunci not met")

	# 1.4 Ready State ("Bahan lengkap. Siap dimasak di dapur.")
	print("  [1.4] Verifying Ready Status Display...")
	inv.add_items("backpack", [{"item_id": "ingredient_temu_kunci", "count": 1}])
	await process_frame
	check(temu_row.text == "• Temu Kunci: 1/1", "1.4 Temu Kunci reached 1/1", "Got: '%s'" % temu_row.text)
	check(temu_row.modulate == Color(0.4, 0.95, 0.4), "1.4 Temu Kunci modulate turns green at 1/1")
	check(status_lbl.visible == true, "1.4 Status label visible when all ingredients met")
	check(status_lbl.text == "Bahan lengkap. Siap dimasak di dapur.", "1.4 Status label text matches ready string", "Got: '%s'" % status_lbl.text)
	check(status_lbl.modulate == Color(0.4, 0.95, 0.45), "1.4 Status label modulate is green")

	# 1.5 Cooking Active & Paused
	print("  [1.5] Verifying Cooking Active & Paused State...")
	rm.set_cooking_state("cooking")
	await process_frame
	check(status_lbl.visible == true, "1.5 Status label visible in cooking state")
	check(status_lbl.text == "Sedang memasak...", "1.5 Status label text is 'Sedang memasak...'", "Got: '%s'" % status_lbl.text)
	check(status_lbl.modulate == Color(1.0, 0.8, 0.3), "1.5 Status label modulate is cooking yellow/orange")

	rm.set_cooking_state("paused")
	await process_frame
	check(status_lbl.visible == true, "1.5 Status label visible in paused state")
	check(status_lbl.text == "Masakan dijeda", "1.5 Status label text is 'Masakan dijeda'", "Got: '%s'" % status_lbl.text)
	check(status_lbl.modulate == Color(1.0, 0.6, 0.3), "1.5 Status label modulate is paused orange")

	# 1.6 Completion State
	print("  [1.6] Verifying Completion State...")
	# Simulate consumption of ingredients upon cooking finish
	inv.backpack.clear()
	inv.storage_home.clear()
	rm.set_cooking_state("idle")
	rm.record_recipe_cooked("recipe_sayur_bening_01")
	await process_frame

	check(status_lbl.visible == true, "1.6 Status label visible when completed")
	check(status_lbl.text == "Resep selesai. Boleh dimasak ulang.", "1.6 Status label text is 'Resep selesai. Boleh dimasak ulang.'", "Got: '%s'" % status_lbl.text)
	check(status_lbl.modulate == Color(0.5, 0.9, 0.6), "1.6 Status label modulate matches completed tint")
	check(bayam_row.text == "• Bayam: 0/3", "1.6 Bayam stock consumed to 0/3", "Got: '%s'" % bayam_row.text)
	check(jagung_row.text == "• Jagung: 0/1", "1.6 Jagung stock consumed to 0/1", "Got: '%s'" % jagung_row.text)
	check(temu_row.text == "• Temu Kunci: 0/1", "1.6 Temu Kunci stock consumed to 0/1", "Got: '%s'" % temu_row.text)

	# 1.7 Cooking Reservation Impact on Live Tracker
	print("  [1.7] Verifying Cooking Reservation Free Stock Exclusion...")
	inv.add_items("backpack", [
		{"item_id": "ingredient_bayam", "count": 3},
		{"item_id": "ingredient_jagung", "count": 1},
		{"item_id": "ingredient_temu_kunci", "count": 1}
	])
	await process_frame
	check(status_lbl.text == "Bahan lengkap. Siap dimasak di dapur.", "1.7 Status ready before reservation")

	# Reserve 1 corn for cooking job
	var res_corn: Array[Dictionary] = [{"item_id": "ingredient_jagung", "count": 1}]
	inv.reserve_ingredients("job_test_tracker", res_corn)
	await process_frame
	check(jagung_row.text == "• Jagung: 0/1", "1.7 Reserved corn excluded from free stock display (0/1)", "Got: '%s'" % jagung_row.text)
	check(jagung_row.modulate != Color(0.4, 0.95, 0.4), "1.7 Jagung row loses green tint when reserved")
	check(status_lbl.text == "Resep selesai. Boleh dimasak ulang.", "1.7 Ready status revoked while ingredient reserved")

	# Cancel reservation
	inv.cancel_reservation("job_test_tracker")
	await process_frame
	check(jagung_row.text == "• Jagung: 1/1", "1.7 Corn restored to 1/1 after cancellation", "Got: '%s'" % jagung_row.text)
	check(status_lbl.text == "Bahan lengkap. Siap dimasak di dapur.", "1.7 Ready status restored")

	# 1.8 Desync Stress Test (100 Random Mutations)
	print("  [1.8] Running 100 Random Inventory Mutations Desync Oracle...")
	var desync_count := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 987654321

	for iter in range(100):
		var op := rng.randi_range(0, 3)
		var item_type: String = ["ingredient_bayam", "ingredient_jagung", "ingredient_temu_kunci"][rng.randi_range(0, 2)]
		var target_c := "backpack" if rng.randf() > 0.5 else "storage"

		match op:
			0: # Add items
				inv.add_items(target_c, [{"item_id": item_type, "count": rng.randi_range(1, 3)}])
			1: # Remove items
				var container_obj = inv.backpack if target_c == "backpack" else inv.storage_home
				container_obj.remove_item(item_type, rng.randi_range(1, 2))
			2: # Transfer
				var from_c := "backpack" if target_c == "storage" else "storage"
				inv.transfer_item(from_c, target_c, 0, 1)
			3: # Reservation toggle
				if rng.randf() > 0.5:
					var r_batch: Array[Dictionary] = [{"item_id": item_type, "count": 1}]
					inv.reserve_ingredients("stress_job_%d" % iter, r_batch)
				else:
					inv.cancel_reservation("stress_job_%d" % iter)

		await process_frame

		# Verify HUD display exactly matches actual inventory free count
		var actual_bayam: int = inv.get_available_item_count("ingredient_bayam")
		var actual_jagung: int = inv.get_available_item_count("ingredient_jagung")
		var actual_temu: int = inv.get_available_item_count("ingredient_temu_kunci")

		var expected_bayam := "• Bayam: %d/3" % actual_bayam
		var expected_jagung := "• Jagung: %d/1" % actual_jagung
		var expected_temu := "• Temu Kunci: %d/1" % actual_temu

		if bayam_row.text != expected_bayam or jagung_row.text != expected_jagung or temu_row.text != expected_temu:
			desync_count += 1
			printerr("  Desync at iter %d: expected [%s, %s, %s] vs got [%s, %s, %s]" % [
				iter, expected_bayam, expected_jagung, expected_temu,
				bayam_row.text, jagung_row.text, temu_row.text
			])

	check(desync_count == 0, "1.8 Zero desync across 100 rapid inventory mutations", "%d desyncs" % desync_count)

	hud.queue_free()
	if is_local_rm:
		rm.free()
	if is_local_inv:
		inv.free()
	await process_frame

# ==============================================================================
# SUITE 2: Rapid Context Switching (100 Iterations) & Frame Guard
# ==============================================================================
func test_suite_2_context_switching_100_toggles() -> void:
	print("\n--- SUITE 2: Rapid Input Context Switching & 100 Toggles Stress Test ---")

	var im: Node = root.get_node_or_null("InputManager")
	var is_local := false
	if im == null:
		im = InputManagerScript.new()
		is_local = true

	var player = PlayerControllerScript.new()
	player._ready()
	im.register_player(player)

	# Ensure clean WORLD baseline
	im.pop_to_world()
	await process_frame

	check(im.get_current_context() == im.ContextMode.WORLD, "2.0 Baseline context is WORLD")
	check(im.is_world_context() == true, "2.0 Baseline is_world_context is true")
	check(im.is_simulation_paused() == false, "2.0 Baseline simulation not paused")
	check(player.movement_enabled == true, "2.0 Baseline player movement enabled")
	check(player.look_enabled == true, "2.0 Baseline player look enabled")

	var toggle_failures := 0
	var frame_guard_failures := 0

	print("  Running 100 Rapid Toggles between WORLD and BOOK (50 via B, 50 via Esc)...")

	for i in range(100):
		var close_action: StringName = &"open_book" if (i % 2 == 0) else &"pause_menu"

		# 1. Transition WORLD -> BOOK
		im.push_context(im.ContextMode.BOOK)

		if im.get_current_context() != im.ContextMode.BOOK:
			toggle_failures += 1
		if not im.is_simulation_paused():
			toggle_failures += 1
		if im.is_world_context():
			toggle_failures += 1
		if im.can_interact_in_world():
			toggle_failures += 1
		if player.movement_enabled or player.look_enabled:
			toggle_failures += 1
		if im._mouse_captured_state:
			toggle_failures += 1

		# 2. Transition BOOK -> WORLD
		im.consume_and_close(close_action)

		# Check on the EXACT frame of closing (Frame Guard Active)
		if im.get_current_context() != im.ContextMode.WORLD:
			toggle_failures += 1
		if im.is_simulation_paused():
			toggle_failures += 1
		if not im.is_world_context():
			toggle_failures += 1
		if not player.movement_enabled or not player.look_enabled:
			toggle_failures += 1
		if not im._mouse_captured_state:
			toggle_failures += 1

		# Frame Guard Check: can_interact_in_world() MUST BE FALSE on closing frame
		if im.can_interact_in_world():
			frame_guard_failures += 1
			printerr("  [FRAME GUARD FAIL] Iteration %d: can_interact_in_world() was TRUE on close frame!" % i)

		# 3. Advance to next frame -> Frame Guard MUST LIFT
		await process_frame
		if not im.can_interact_in_world():
			frame_guard_failures += 1
			printerr("  [FRAME GUARD FAIL] Iteration %d: can_interact_in_world() remained FALSE on next frame!" % i)

	check(toggle_failures == 0, "2.1 100 Context toggles completed with zero state corruption", "%d toggle errors" % toggle_failures)
	check(frame_guard_failures == 0, "2.2 Frame guard 100% active on every close frame and lifted on next frame", "%d frame guard errors" % frame_guard_failures)

	im.register_player(null)
	player.free()
	if is_local:
		im.free()
	await process_frame

# ==============================================================================
# SUITE 3: Physical Click Bleed-Through & World Interaction Oracle (T18, T28)
# ==============================================================================
func test_suite_3_click_bleed_through_world_oracle() -> void:
	print("\n--- SUITE 3: Click Bleed-Through & 3D World Interaction Oracle ---")

	var im: Node = root.get_node_or_null("InputManager")
	var is_local := false
	if im == null:
		im = InputManagerScript.new()
		is_local = true

	# Create a physical 3D test environment
	var world_root := Node3D.new()
	root.add_child(world_root)

	var player_scene = load("res://scenes/player/player.tscn")
	var player = player_scene.instantiate()
	world_root.add_child(player)
	player.position = Vector3(0, 0, 0)
	im.register_player(player)

	# Create an Interactable target 1.0m directly in front of the player (at camera height y=1.6)
	var interactable := InteractableScript.new()
	interactable.name = "Interactable"
	interactable.position = Vector3(0, 1.6, -1.0)
	interactable.prompt_action = "Ambil"
	interactable.target_name = "Target Uji"

	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	col_shape.shape = box
	interactable.add_child(col_shape)
	world_root.add_child(interactable)
	interactable._ready()

	var interacted_count := [0]
	interactable.interacted.connect(func(_p): interacted_count[0] += 1)

	var detector: RayCast3D = player.find_child("InteractionDetector", true, false) as RayCast3D
	check(detector != null, "3.0 InteractionDetector attached to player")

	# Wait for physics / raycast to update
	await process_frame
	detector.force_raycast_update()
	detector.update_target()

	check(detector.has_focused_target() == true, "3.0 Detector successfully focused on test target")

	# Baseline: Interaction in WORLD context MUST SUCCEED
	im.pop_to_world()
	await process_frame
	var ok_world: bool = detector.try_interact(player)
	check(ok_world == true, "3.1 Interaction succeeds in WORLD context")
	check(interacted_count[0] == 1, "3.1 Target interacted callback executed")

	# Now stress test bleed-through prevention across 20 cycles
	var bleed_through_leaks := 0
	var normal_interactions_ok := 0

	print("  Running 20 Bleed-Through Oracle Cycles...")
	for cycle in range(20):
		# Open Book Modal
		im.push_context(im.ContextMode.BOOK)

		# Attempt interaction while Book is open -> MUST BE BLOCKED
		var ok_in_modal: bool = detector.try_interact(player)
		if ok_in_modal:
			bleed_through_leaks += 1
			printerr("  Cycle %d: Bleed-through leak! Interaction succeeded while in BOOK context!" % cycle)

		# Close Book Modal -> Pop context to WORLD
		im.pop_context()

		# ATTEMPT INTERACTION ON THE EXACT CLOSING FRAME
		# Frame guard MUST BLOCK this click from leaking into 3D world!
		var ok_closing_frame: bool = detector.try_interact(player)
		if ok_closing_frame:
			bleed_through_leaks += 1
			printerr("  Cycle %d: Bleed-through leak! Interaction succeeded on modal CLOSING frame!" % cycle)

		# Advance to next frame
		await process_frame

		# Interaction on next frame MUST SUCCEED
		var ok_next_frame: bool = detector.try_interact(player)
		if ok_next_frame:
			normal_interactions_ok += 1
		else:
			printerr("  Cycle %d: Interaction failed to execute on subsequent frame after modal close!" % cycle)

	check(bleed_through_leaks == 0, "3.2 Zero clicks leaked through to 3D world interaction during modal or closing frame", "%d leaks" % bleed_through_leaks)
	check(normal_interactions_ok == 20, "3.3 100% of interactions executed successfully once frame guard lifted", "%d ok / 20" % normal_interactions_ok)

	im.register_player(null)
	world_root.queue_free()
	if is_local:
		im.free()
	await process_frame

# ==============================================================================
# SUITE 4: Modal Exclusivity & Stack Integrity
# ==============================================================================
func test_suite_4_modal_exclusivity_and_stack_integrity() -> void:
	print("\n--- SUITE 4: Modal Exclusivity & Stack Integrity ---")

	var im: Node = root.get_node_or_null("InputManager")
	var is_local := false
	if im == null:
		im = InputManagerScript.new()
		is_local = true

	im.pop_to_world()
	await process_frame

	# 4.1 Re-entrant push of the same modal
	print("  [4.1] Testing Re-entrant push...")
	im.push_context(im.ContextMode.BOOK)
	check(im.get_stack_depth() == 2, "4.1 Stack depth is 2 after pushing BOOK")

	for i in range(10):
		im.push_context(im.ContextMode.BOOK)
	check(im.get_stack_depth() == 2, "4.1 Stack depth remains strictly 2 after 10 re-entrant pushes")
	check(im.get_current_context() == im.ContextMode.BOOK, "4.1 Context remains BOOK")

	# 4.2 Push of WORLD is rejected
	print("  [4.2] Testing push_context(WORLD)...")
	im.push_context(im.ContextMode.WORLD)
	check(im.get_stack_depth() == 2, "4.2 push_context(WORLD) ignored, depth remains 2")
	check(im.get_current_context() == im.ContextMode.BOOK, "4.2 Context remains BOOK")

	# 4.3 Nested Modal Stacking: WORLD -> BOOK -> PAUSE
	print("  [4.3] Testing Nested Modal Stacking...")
	im.push_context(im.ContextMode.PAUSE)
	check(im.get_stack_depth() == 3, "4.3 Stack depth is 3 after pushing PAUSE over BOOK")
	check(im.get_current_context() == im.ContextMode.PAUSE, "4.3 Context is PAUSE")
	check(im.is_simulation_paused() == true, "4.3 Simulation paused in PAUSE")

	# Pop PAUSE -> returns cleanly to BOOK
	var popped_pause = im.pop_context()
	check(popped_pause == im.ContextMode.PAUSE, "4.3 Popped PAUSE")
	check(im.get_stack_depth() == 2, "4.3 Stack depth returns to 2")
	check(im.get_current_context() == im.ContextMode.BOOK, "4.3 Context returns cleanly to BOOK")
	check(im.is_simulation_paused() == true, "4.3 Simulation still paused in BOOK")
	check(im.can_interact_in_world() == false, "4.3 World interaction still blocked while in BOOK")

	# Pop BOOK -> returns cleanly to WORLD
	var popped_book = im.pop_context()
	check(popped_book == im.ContextMode.BOOK, "4.3 Popped BOOK")
	check(im.get_stack_depth() == 1, "4.3 Stack depth returns to 1")
	check(im.get_current_context() == im.ContextMode.WORLD, "4.3 Context returns to WORLD")
	check(im.is_simulation_paused() == false, "4.3 Simulation unpaused in WORLD")
	check(im.can_interact_in_world() == false, "4.3 Frame guard active on pop to WORLD")

	await process_frame
	check(im.can_interact_in_world() == true, "4.3 Frame guard lifted on next frame")

	# 4.4 Excessive pops on empty / single stack
	print("  [4.4] Testing Excessive pops underflow protection...")
	for i in range(10):
		var p = im.pop_context()
		check(p == im.ContextMode.WORLD, "4.4 Excessive pop returns WORLD safely")
		check(im.get_stack_depth() == 1, "4.4 Stack depth never drops below 1")

	# 4.5 pop_to_world from deep stack
	print("  [4.5] Testing pop_to_world from deep stack...")
	im.push_context(im.ContextMode.BOOK)
	im.push_context(im.ContextMode.PAUSE)
	check(im.get_stack_depth() == 3, "4.5 Depth is 3")
	im.pop_to_world()
	check(im.get_stack_depth() == 1, "4.5 pop_to_world resets depth to strictly 1")
	check(im.get_current_context() == im.ContextMode.WORLD, "4.5 Current context is WORLD")
	check(im.can_interact_in_world() == false, "4.5 Frame guard active on pop_to_world")
	await process_frame
	check(im.can_interact_in_world() == true, "4.5 Frame guard lifted on next frame")

	if is_local:
		im.free()
	await process_frame

# ==============================================================================
# SUITE 5: Main Scene Input Dispatch Empirical Challenge (Defect Investigation)
# ==============================================================================
func test_suite_5_main_scene_input_dispatch_empirical_challenge() -> void:
	print("\n--- SUITE 5: Main Scene Input Dispatch Empirical Challenge ---")

	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var im: Node = root.get_node_or_null("InputManager")
	var book_ui = main.find_child("BookUI", true, false)

	check(im != null, "5.0 InputManager singleton found")
	check(book_ui != null, "5.0 BookUI found in main.tscn")

	# Reset context to WORLD
	im.pop_to_world()
	book_ui.visible = false
	await process_frame

	check(im.get_current_context() == im.ContextMode.WORLD, "5.0 Initial context is WORLD")
	check(book_ui.visible == false, "5.0 BookUI initially hidden")

	# 5.1 Test: Player presses hotkey 'B' (action "open_book") in main.tscn
	print("  [5.1] EMPIRICAL CHALLENGE: Dispatching 'open_book' (hotkey B) input event to main.tscn...")
	var ev_b = InputEventAction.new()
	ev_b.action = "open_book"
	ev_b.pressed = true

	root.push_input(ev_b)
	await process_frame

	# What is the actual state?
	var final_context: int = im.get_current_context()
	var final_book_visible: bool = book_ui.visible

	print("    Observed State after hotkey 'B': Context = %d (expected 1/BOOK), BookUI.visible = %s (expected true)" % [
		final_context, str(final_book_visible)
	])

	# Check whether hotkey 'B' opened and kept the book open
	var book_opened_correctly: bool = (final_context == im.ContextMode.BOOK and final_book_visible == true)
	if not book_opened_correctly:
		record_defect(
			"DEFECT-BOOK-01: Hotkey B (open_book) instantly closes in main.tscn due to unconsumed input propagation",
			"HIGH",
			"In scripts/main.gd lines 60-70, _unhandled_input() intercepts 'open_book' and opens BookUI, but fails to call get_viewport().set_input_as_handled(). The event leaks to InputManager._unhandled_input(), which detects ContextMode.BOOK and immediately calls consume_and_close(&'open_book'), closing the book on the exact same frame.",
			"1. Load scenes/main.tscn. 2. Dispatch InputEventAction for 'open_book' with pressed=true. 3. Observe BookUI is immediately closed and context reverts to 0 (WORLD).",
			"scripts/main.gd:60-70"
		)
		check(false, "5.1 Hotkey B opens and keeps BookUI visible in main.tscn", "DEFECT DETECTED: Book opened and closed on same frame (Context=%d, BookUI.visible=%s)" % [final_context, final_book_visible])
	else:
		check(true, "5.1 Hotkey B opens and keeps BookUI visible in main.tscn")

	# 5.2 Test: Programmatic / Landmark Open followed by Esc (pause_menu)
	print("  [5.2] Testing Esc (pause_menu) close when book is open in main.tscn...")
	book_ui.open_book()
	await process_frame
	check(im.get_current_context() == im.ContextMode.BOOK, "5.2 Book opened via API. Context is BOOK")
	check(book_ui.visible == true, "5.2 BookUI is visible")

	var ev_esc = InputEventAction.new()
	ev_esc.action = "pause_menu"
	ev_esc.pressed = true

	root.push_input(ev_esc)
	await process_frame

	check(im.get_current_context() == im.ContextMode.WORLD, "5.2 Esc closes book and restores Context to WORLD")
	check(book_ui.visible == false, "5.2 BookUI is closed by Esc")

	main.queue_free()
	await process_frame
