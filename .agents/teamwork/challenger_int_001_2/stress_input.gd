extends SceneTree

## Empirical Challenge Test Harness for Milestone INT-001
## Adversarial Stress Testing of InputManager Context Stack,
## Modal Transitions, Action Bleed-Through Prevention, and Simulation Pause Rules.

const Assertions = preload("res://tests/assertions.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")
const InteractionDetectorClass = preload("res://scripts/interaction/interaction_detector.gd")
const InteractableClass = preload("res://scripts/interaction/interactable.gd")

var _all_passed: bool = true

func _initialize() -> void:
	print("==================================================")
	print("[CHALLENGER_INT_001] Empirical Stress & Adversarial Harness")
	print("Target: InputManager Context Stack & Action Bleed-Through (INT-001)")
	print("==================================================")
	
	Assertions.reset()
	
	# Execute all empirical challenges
	await run_all_challenges()
	
	print("==================================================")
	print("[CHALLENGER_INT_001] VERIFICATION SUMMARY:")
	print("  Assertions Passed: %d" % Assertions.current_suite_passed)
	print("  Assertions Failed: %d" % Assertions.current_suite_failed)
	
	if _all_passed and Assertions.current_suite_failed == 0:
		print("  FINAL VERDICT: CONFIRMED CORRECT")
		print("  All INT-001 empirical challenge criteria verified successfully.")
		print("==================================================")
		quit(0)
	else:
		printerr("  FINAL VERDICT: ISSUE DETECTED")
		printerr("  Adversarial challenge failures encountered:")
		for msg in Assertions.failure_messages:
			printerr("    - ", msg)
		print("==================================================")
		quit(1)

func run_all_challenges() -> void:
	# Challenge 1: Deep nested modal transitions
	if not await challenge_01_deep_nested_modal_transitions():
		_all_passed = false
	
	# Challenge 2: Rapid context switching (100 rapid push/pop cycles)
	if not await challenge_02_rapid_context_switching_100_cycles():
		_all_passed = false
	
	# Challenge 3: Action bleed-through prevention & frame cooldown (T28)
	if not await challenge_03_action_bleed_through_prevention():
		_all_passed = false
	
	# Challenge 4: Simulation pause compliance & SceneTree behavior (PROTOTYPE § 5)
	if not await challenge_04_simulation_pause_compliance():
		_all_passed = false

	# Challenge 5: Window focus loss auto-pause oracle (PROTOTYPE § 5)
	if not await challenge_05_focus_loss_auto_pause():
		_all_passed = false

	# Challenge 6: Hotkey input dispatch & modal toggling oracle
	if not await challenge_06_hotkey_input_dispatch():
		_all_passed = false

	# Challenge 7: Player lifecycle & freed node resilience oracle
	if not await challenge_07_player_lifecycle_resilience():
		_all_passed = false

# ==============================================================================
# CHALLENGE 1: Deep Nested Modal Transitions & Gating Invariance
# ==============================================================================
func challenge_01_deep_nested_modal_transitions() -> bool:
	print("\n  [CHALLENGE 1] Deep Nested Modal Transitions: BOOK -> STORAGE -> KITCHEN -> DIALOGUE -> PAUSE")
	var initial_failures: int = Assertions.current_suite_failed
	
	var im: Node = root.get_node_or_null("InputManager")
	var owns_im := false
	if im == null:
		im = InputManagerClass.new()
		root.add_child(im)
		owns_im = true
	
	var player = PlayerControllerClass.new()
	root.add_child(player)
	im.register_player(player)
	im.pop_to_world()
	
	# Baseline check in WORLD
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Initial context is WORLD")
	Assertions.assert_true(im.is_world_context(), "is_world_context() is true")
	Assertions.assert_false(im.is_modal_active(), "is_modal_active() is false in WORLD")
	Assertions.assert_equal(im.get_stack_depth(), 1, "Stack depth is 1 in WORLD")
	Assertions.assert_true(player.movement_enabled, "Player movement_enabled is true in WORLD")
	Assertions.assert_true(player.look_enabled, "Player look_enabled is true in WORLD")
	Assertions.assert_true(im._mouse_captured_state, "Mouse captured state is true in WORLD")
	
	# Transition 1: Push BOOK
	im.push_context(InputManagerClass.ContextMode.BOOK)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.BOOK, "Context after push(BOOK) is BOOK")
	Assertions.assert_equal(im.get_stack_depth(), 2, "Stack depth is 2 after BOOK")
	Assertions.assert_false(im.is_world_context(), "is_world_context() is false in BOOK")
	Assertions.assert_true(im.is_modal_active(), "is_modal_active() is true in BOOK")
	Assertions.assert_false(player.movement_enabled, "Player movement_enabled disabled in BOOK")
	Assertions.assert_false(player.look_enabled, "Player look_enabled disabled in BOOK")
	Assertions.assert_false(im._mouse_captured_state, "Mouse released in BOOK")
	
	# Transition 2: Push STORAGE
	im.push_context(InputManagerClass.ContextMode.STORAGE)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.STORAGE, "Context after push(STORAGE) is STORAGE")
	Assertions.assert_equal(im.get_stack_depth(), 3, "Stack depth is 3 after STORAGE")
	Assertions.assert_false(player.movement_enabled, "Player movement_enabled disabled in STORAGE")
	Assertions.assert_false(player.look_enabled, "Player look_enabled disabled in STORAGE")
	Assertions.assert_false(im._mouse_captured_state, "Mouse released in STORAGE")
	
	# Transition 3: Push KITCHEN
	im.push_context(InputManagerClass.ContextMode.KITCHEN)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.KITCHEN, "Context after push(KITCHEN) is KITCHEN")
	Assertions.assert_equal(im.get_stack_depth(), 4, "Stack depth is 4 after KITCHEN")
	Assertions.assert_false(player.movement_enabled, "Player movement_enabled disabled in KITCHEN")
	Assertions.assert_false(player.look_enabled, "Player look_enabled disabled in KITCHEN")
	Assertions.assert_false(im._mouse_captured_state, "Mouse released in KITCHEN")
	
	# Transition 4: Push DIALOGUE
	im.push_context(InputManagerClass.ContextMode.DIALOGUE)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.DIALOGUE, "Context after push(DIALOGUE) is DIALOGUE")
	Assertions.assert_equal(im.get_stack_depth(), 5, "Stack depth is 5 after DIALOGUE")
	Assertions.assert_false(player.movement_enabled, "Player movement_enabled disabled in DIALOGUE")
	Assertions.assert_false(player.look_enabled, "Player look_enabled disabled in DIALOGUE")
	Assertions.assert_false(im._mouse_captured_state, "Mouse released in DIALOGUE")
	
	# Transition 5: Push PAUSE (peak depth: 6)
	im.push_context(InputManagerClass.ContextMode.PAUSE)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.PAUSE, "Context after push(PAUSE) is PAUSE")
	Assertions.assert_equal(im.get_stack_depth(), 6, "Stack depth is 6 after PAUSE")
	Assertions.assert_false(player.movement_enabled, "Player movement_enabled disabled in PAUSE")
	Assertions.assert_false(player.look_enabled, "Player look_enabled disabled in PAUSE")
	Assertions.assert_false(im._mouse_captured_state, "Mouse released in PAUSE")
	
	# Idempotent push test: pushing PAUSE again while at top of stack
	im.push_context(InputManagerClass.ContextMode.PAUSE)
	Assertions.assert_equal(im.get_stack_depth(), 6, "Duplicate push(PAUSE) is ignored (depth remains 6)")
	
	# Push WORLD while modal is active: must be ignored
	im.push_context(InputManagerClass.ContextMode.WORLD)
	Assertions.assert_equal(im.get_stack_depth(), 6, "push(WORLD) into modal stack is rejected (depth remains 6)")
	
	# POP STEP 1: Pop PAUSE -> returns to DIALOGUE
	var popped1 = im.pop_context()
	Assertions.assert_equal(popped1, InputManagerClass.ContextMode.PAUSE, "Popped mode is PAUSE")
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.DIALOGUE, "Current mode restored to DIALOGUE")
	Assertions.assert_equal(im.get_stack_depth(), 5, "Stack depth restored to 5")
	Assertions.assert_false(player.movement_enabled, "Player remains gated in intermediate DIALOGUE")
	Assertions.assert_false(player.look_enabled, "Player look remains gated in intermediate DIALOGUE")
	Assertions.assert_false(im._mouse_captured_state, "Mouse remains visible in intermediate DIALOGUE")
	
	# POP STEP 2: Pop DIALOGUE -> returns to KITCHEN
	var popped2 = im.pop_context()
	Assertions.assert_equal(popped2, InputManagerClass.ContextMode.DIALOGUE, "Popped mode is DIALOGUE")
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.KITCHEN, "Current mode restored to KITCHEN")
	Assertions.assert_equal(im.get_stack_depth(), 4, "Stack depth restored to 4")
	Assertions.assert_false(player.movement_enabled, "Player remains gated in intermediate KITCHEN")
	Assertions.assert_false(im._mouse_captured_state, "Mouse remains visible in intermediate KITCHEN")
	
	# POP STEP 3: Pop KITCHEN -> returns to STORAGE
	var popped3 = im.pop_context()
	Assertions.assert_equal(popped3, InputManagerClass.ContextMode.KITCHEN, "Popped mode is KITCHEN")
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.STORAGE, "Current mode restored to STORAGE")
	Assertions.assert_equal(im.get_stack_depth(), 3, "Stack depth restored to 3")
	Assertions.assert_false(player.movement_enabled, "Player remains gated in intermediate STORAGE")
	Assertions.assert_false(im._mouse_captured_state, "Mouse remains visible in intermediate STORAGE")
	
	# POP STEP 4: Pop STORAGE -> returns to BOOK
	var popped4 = im.pop_context()
	Assertions.assert_equal(popped4, InputManagerClass.ContextMode.STORAGE, "Popped mode is STORAGE")
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.BOOK, "Current mode restored to BOOK")
	Assertions.assert_equal(im.get_stack_depth(), 2, "Stack depth restored to 2")
	Assertions.assert_false(player.movement_enabled, "Player remains gated in intermediate BOOK")
	Assertions.assert_false(im._mouse_captured_state, "Mouse remains visible in intermediate BOOK")
	
	# POP STEP 5: Pop BOOK -> returns to WORLD
	var popped5 = im.pop_context()
	Assertions.assert_equal(popped5, InputManagerClass.ContextMode.BOOK, "Popped mode is BOOK")
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Current mode fully restored to WORLD")
	Assertions.assert_equal(im.get_stack_depth(), 1, "Stack depth fully restored to 1")
	Assertions.assert_true(im.is_world_context(), "is_world_context() is true after returning to WORLD")
	Assertions.assert_true(player.movement_enabled, "Player movement_enabled restored in WORLD")
	Assertions.assert_true(player.look_enabled, "Player look_enabled restored in WORLD")
	Assertions.assert_true(im._mouse_captured_state, "Mouse captured state restored in WORLD")
	
	# UNDERFLOW DEFENSE: Pop 5 additional times from base WORLD
	for u in range(5):
		var underflow_result = im.pop_context()
		Assertions.assert_equal(underflow_result, InputManagerClass.ContextMode.WORLD, "Underflow pop %d returns WORLD" % u)
		Assertions.assert_equal(im.get_stack_depth(), 1, "Stack depth remains 1 during underflow attempts")
		Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Context remains WORLD during underflow")
		Assertions.assert_true(player.movement_enabled, "Player movement remains true during underflow")
		Assertions.assert_true(player.look_enabled, "Player look remains true during underflow")
	
	player.queue_free()
	if owns_im:
		im.queue_free()
	
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 1: Deep nested modal transitions verified.")
	else:
		printerr("    [FAIL] Challenge 1: Deep nested modal transitions failed.")
	return ok

# ==============================================================================
# CHALLENGE 2: Rapid Context Switching (100 Rapid Push/Pop Cycles)
# ==============================================================================
func challenge_02_rapid_context_switching_100_cycles() -> bool:
	print("\n  [CHALLENGE 2] Rapid Context Switching: 100 Rapid Push/Pop Stress Cycles")
	var initial_failures: int = Assertions.current_suite_failed
	
	var im: Node = root.get_node_or_null("InputManager")
	var owns_im := false
	if im == null:
		im = InputManagerClass.new()
		root.add_child(im)
		owns_im = true
	
	var player = PlayerControllerClass.new()
	root.add_child(player)
	im.register_player(player)
	im.pop_to_world()
	
	var modes: Array = [
		InputManagerClass.ContextMode.BOOK,
		InputManagerClass.ContextMode.STORAGE,
		InputManagerClass.ContextMode.KITCHEN,
		InputManagerClass.ContextMode.DIALOGUE,
		InputManagerClass.ContextMode.PAUSE
	]
	
	# 2A: 100 alternating push/pop cycles
	for i in range(100):
		var target_mode = modes[i % modes.size()]
		im.push_context(target_mode)
		
		# Invariant checks mid-push
		if im.get_current_context() != target_mode:
			Assertions.assert_equal(im.get_current_context(), target_mode, "Cycle %d: context must match pushed mode" % i)
		if im.get_stack_depth() != 2:
			Assertions.assert_equal(im.get_stack_depth(), 2, "Cycle %d: stack depth must be exactly 2" % i)
		if player.movement_enabled != false or player.look_enabled != false:
			Assertions.assert_false(player.movement_enabled, "Cycle %d: player movement must be disabled" % i)
		
		var popped = im.pop_context()
		if popped != target_mode:
			Assertions.assert_equal(popped, target_mode, "Cycle %d: popped mode must match pushed mode" % i)
		if im.get_current_context() != InputManagerClass.ContextMode.WORLD:
			Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Cycle %d: context restored to WORLD" % i)
		if im.get_stack_depth() != 1:
			Assertions.assert_equal(im.get_stack_depth(), 1, "Cycle %d: stack depth restored to 1" % i)
		if not player.movement_enabled or not player.look_enabled:
			Assertions.assert_true(player.movement_enabled, "Cycle %d: player movement restored" % i)
	
	Assertions.assert_equal(im.get_stack_depth(), 1, "Stack depth strictly 1 after 100 alternating cycles")
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Final context is WORLD after 100 cycles")
	
	# 2B: Rapid Burst Pushes (depth 5) followed by Burst Pops + extra underflow pops
	for cycle in range(10):
		for m in modes:
			im.push_context(m)
		Assertions.assert_equal(im.get_stack_depth(), 6, "Burst cycle %d: stack depth is 6" % cycle)
		
		# Pop all back + 3 underflow pops
		for p in range(8):
			im.pop_context()
		
		Assertions.assert_equal(im.get_stack_depth(), 1, "Burst cycle %d: stack depth is cleanly 1 after burst pops" % cycle)
		Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Burst cycle %d: context is WORLD" % cycle)
		Assertions.assert_true(player.movement_enabled, "Burst cycle %d: player movement restored" % cycle)
	
	# 2C: pop_to_world() stress from varying depths
	for depth in [1, 2, 4, 6]:
		im.pop_to_world()
		for d in range(depth - 1):
			im.push_context(modes[d % modes.size()])
		Assertions.assert_equal(im.get_stack_depth(), depth, "Stack reached depth %d" % depth)
		
		im.pop_to_world()
		Assertions.assert_equal(im.get_stack_depth(), 1, "pop_to_world() from depth %d resets depth to 1" % depth)
		Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "pop_to_world() resets to WORLD")
		Assertions.assert_true(player.movement_enabled, "pop_to_world() restores player movement")
		Assertions.assert_true(player.look_enabled, "pop_to_world() restores player look")
	
	player.queue_free()
	if owns_im:
		im.queue_free()
	
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 2: Rapid context switching (100 cycles) verified.")
	else:
		printerr("    [FAIL] Challenge 2: Rapid context switching (100 cycles) failed.")
	return ok

# ==============================================================================
# CHALLENGE 3: Action Bleed-Through Prevention & Frame Cooldown (T28)
# ==============================================================================
func challenge_03_action_bleed_through_prevention() -> bool:
	print("\n  [CHALLENGE 3] Action Bleed-Through Prevention & Frame Cooldown (T28)")
	var initial_failures: int = Assertions.current_suite_failed
	
	var im: Node = root.get_node_or_null("InputManager")
	var owns_im := false
	if im == null:
		im = InputManagerClass.new()
		root.add_child(im)
		owns_im = true
	
	im.pop_to_world()
	
	var world_node = Node3D.new()
	root.add_child(world_node)
	
	# Setup target interactable at 1.0m
	var target = InteractableClass.new()
	target.name = "Interactable"
	target.prompt_action = "Periksa"
	target.target_name = "Meja"
	target.interaction_id = "test_target"
	target.position = Vector3(0.0, 0.0, -1.0)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.0, 1.0, 1.0)
	col.shape = shape
	target.add_child(col)
	world_node.add_child(target)
	
	# Setup player and detector
	var player = PlayerControllerClass.new()
	player.position = Vector3.ZERO
	world_node.add_child(player)
	im.register_player(player)
	
	var detector = player.get_node_or_null("Head/Camera3D/InteractionDetector") as InteractionDetectorClass
	if detector == null:
		detector = InteractionDetectorClass.new()
		player.add_child(detector)
	
	var target_interacted_count := [0]
	target.interacted.connect(func(_p): target_interacted_count[0] += 1)
	
	# Synchronize physics frames for raycast hit
	for f in range(3):
		await process_frame
		await physics_frame
	
	detector.update_target()
	Assertions.assert_true(detector.has_focused_target(), "Precondition: target acquired at 1.0m")
	Assertions.assert_equal(detector.get_current_target(), target, "Precondition: acquired target matches instance")
	
	# Phase 1: Open BOOK modal
	im.push_context(InputManagerClass.ContextMode.BOOK)
	Assertions.assert_false(im.is_world_context(), "Context is modal BOOK")
	Assertions.assert_false(im.can_interact_in_world(), "can_interact_in_world() is false while modal is active")
	
	# Interacting while modal is active MUST fail
	var interact_during_modal = detector.try_interact(player)
	Assertions.assert_false(interact_during_modal, "Interaction during active modal is strictly rejected")
	Assertions.assert_equal(target_interacted_count[0], 0, "No interacted signal emitted during active modal")
	
	# Phase 2: Close modal with 'E' key (consume_and_close(&"interact"))
	# This simulates pressing E to close a modal UI
	Input.action_press(&"interact")
	im.consume_and_close(&"interact")
	
	# ORACLE CHECK 1 (Same Frame as Close):
	# On the exact frame of closing, can_interact_in_world MUST be false,
	# and is_action_suppressed(&"interact") MUST be true.
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Context returned to WORLD")
	Assertions.assert_false(im.can_interact_in_world(), "can_interact_in_world() is FALSE on the exact close frame")
	Assertions.assert_true(im.is_action_suppressed(&"interact"), "is_action_suppressed('interact') is TRUE on close frame")
	
	var same_frame_interact = detector.try_interact(player)
	Assertions.assert_false(same_frame_interact, "World interaction is REJECTED on the exact close frame (bleed-through blocked)")
	Assertions.assert_equal(target_interacted_count[0], 0, "Interacted signal NOT emitted on close frame")
	
	# ORACLE CHECK 2 (Subsequent frame while key remains held):
	# Advance 2 process frames while 'interact' action is STILL held.
	# Bleed-through prevention requires action suppression to remain active until released!
	await process_frame
	await physics_frame
	
	Assertions.assert_true(Input.is_action_pressed(&"interact"), "Action 'interact' is physically held down")
	Assertions.assert_true(im.is_action_suppressed(&"interact"), "Action remains suppressed while key is still held")
	
	var held_frame_interact = detector.try_interact(player)
	Assertions.assert_false(held_frame_interact, "World interaction is REJECTED on subsequent frame while key is still held")
	Assertions.assert_equal(target_interacted_count[0], 0, "Interacted signal NOT emitted while key is held")
	
	# ORACLE CHECK 3 (Key Released):
	# Now player physically releases 'E' key.
	Input.action_release(&"interact")
	await process_frame
	await physics_frame
	
	# Checking suppression after release: suppression must now be cleared!
	Assertions.assert_false(im.is_action_suppressed(&"interact"), "Suppression is CLEARED after action release")
	Assertions.assert_true(im.can_interact_in_world(), "can_interact_in_world() is now TRUE")
	
	# ORACLE CHECK 4 (Fresh New Press):
	# Player presses 'E' fresh to interact with world object.
	Input.action_press(&"interact")
	detector.update_target()
	var fresh_interact = detector.try_interact(player)
	Assertions.assert_true(fresh_interact, "Fresh interaction succeeds after release and re-press")
	Assertions.assert_equal(target_interacted_count[0], 1, "Interacted signal emitted exactly once for fresh press")
	Input.action_release(&"interact")
	
	# ORACLE CHECK 5 (Esc key modal close bleed-through):
	im.push_context(InputManagerClass.ContextMode.STORAGE)
	im.consume_and_close(&"pause_menu")
	Assertions.assert_false(im.can_interact_in_world(), "can_interact_in_world() is FALSE on exact frame after Esc close")
	var esc_bleed_interact = detector.try_interact(player)
	Assertions.assert_false(esc_bleed_interact, "World interaction is REJECTED on Esc close frame")
	Assertions.assert_equal(target_interacted_count[0], 1, "Interacted count remains 1 (no spurious execution)")
	
	world_node.queue_free()
	if owns_im:
		im.queue_free()
	
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 3: Action bleed-through prevention verified.")
	else:
		printerr("    [FAIL] Challenge 3: Action bleed-through prevention failed.")
	return ok

# ==============================================================================
# CHALLENGE 4: Simulation Pause Compliance & SceneTree Behavior (PROTOTYPE § 5)
# ==============================================================================
func challenge_04_simulation_pause_compliance() -> bool:
	print("\n  [CHALLENGE 4] Simulation Pause Compliance & SceneTree Behavior (PROTOTYPE § 5)")
	var initial_failures: int = Assertions.current_suite_failed
	
	var im: Node = root.get_node_or_null("InputManager")
	var owns_im := false
	if im == null:
		im = InputManagerClass.new()
		root.add_child(im)
		owns_im = true
	
	var player = PlayerControllerClass.new()
	root.add_child(player)
	im.register_player(player)
	im.pop_to_world()
	
	var recorded_signals: Array[bool] = []
	var sig_callable = func(is_paused: bool): recorded_signals.append(is_paused)
	im.simulation_state_changed.connect(sig_callable)
	
	# PROTOTYPE § 5 Simulation Matrix:
	# Context   | Movement | Simulation Paused (Time Controller) | SceneTree.paused
	# WORLD     | true     | false                                | false
	# BOOK      | false    | true                                 | false
	# STORAGE   | false    | true                                 | false
	# KITCHEN   | false    | false                                | false
	# DIALOGUE  | false    | true                                 | false
	# PAUSE     | false    | true                                 | false
	
	# 4A. Baseline in WORLD
	Assertions.assert_false(im.is_simulation_paused(), "WORLD: is_simulation_paused is false")
	Assertions.assert_true(player.movement_enabled, "WORLD: player movement_enabled is true")
	Assertions.assert_true(player.look_enabled, "WORLD: player look_enabled is true")
	Assertions.assert_false(paused, "WORLD: SceneTree.paused is false")
	
	# 4B. Context: BOOK
	recorded_signals.clear()
	im.set_context(InputManagerClass.ContextMode.BOOK)
	Assertions.assert_true(im.is_simulation_paused(), "BOOK: is_simulation_paused is TRUE (PROTOTYPE § 5: growth & cooking stop)")
	Assertions.assert_false(player.movement_enabled, "BOOK: player movement is disabled")
	Assertions.assert_false(player.look_enabled, "BOOK: player look is disabled")
	Assertions.assert_equal(recorded_signals.size(), 1, "simulation_state_changed emitted once on BOOK")
	Assertions.assert_true(recorded_signals[0], "simulation_state_changed emitted TRUE on BOOK")
	Assertions.assert_false(paused, "BOOK: SceneTree.paused remains false (UI/animations continue)")
	
	# 4C. Context: STORAGE
	recorded_signals.clear()
	im.set_context(InputManagerClass.ContextMode.STORAGE)
	Assertions.assert_true(im.is_simulation_paused(), "STORAGE: is_simulation_paused is TRUE (PROTOTYPE § 5: growth & cooking stop)")
	Assertions.assert_false(player.movement_enabled, "STORAGE: player movement is disabled")
	Assertions.assert_false(player.look_enabled, "STORAGE: player look is disabled")
	Assertions.assert_false(paused, "STORAGE: SceneTree.paused remains false")
	
	# 4D. Context: KITCHEN (Explicit Exception per PROTOTYPE § 5)
	recorded_signals.clear()
	im.set_context(InputManagerClass.ContextMode.KITCHEN)
	Assertions.assert_false(im.is_simulation_paused(), "KITCHEN: is_simulation_paused is FALSE (PROTOTYPE § 5: cooking & growth continue while cooking)")
	Assertions.assert_false(player.movement_enabled, "KITCHEN: player movement is disabled")
	Assertions.assert_false(player.look_enabled, "KITCHEN: player look is disabled")
	Assertions.assert_equal(recorded_signals.size(), 1, "simulation_state_changed emitted once on KITCHEN")
	Assertions.assert_false(recorded_signals[0], "simulation_state_changed emitted FALSE on KITCHEN")
	Assertions.assert_false(paused, "KITCHEN: SceneTree.paused remains false")
	
	# 4E. Context: DIALOGUE
	recorded_signals.clear()
	im.set_context(InputManagerClass.ContextMode.DIALOGUE)
	Assertions.assert_true(im.is_simulation_paused(), "DIALOGUE: is_simulation_paused is TRUE (PROTOTYPE § 5)")
	Assertions.assert_false(player.movement_enabled, "DIALOGUE: player movement is disabled")
	Assertions.assert_false(player.look_enabled, "DIALOGUE: player look is disabled")
	Assertions.assert_false(paused, "DIALOGUE: SceneTree.paused remains false")
	
	# 4F. Context: PAUSE
	recorded_signals.clear()
	im.set_context(InputManagerClass.ContextMode.PAUSE)
	Assertions.assert_true(im.is_simulation_paused(), "PAUSE: is_simulation_paused is TRUE (PROTOTYPE § 5)")
	Assertions.assert_false(player.movement_enabled, "PAUSE: player movement is disabled")
	Assertions.assert_false(player.look_enabled, "PAUSE: player look is disabled")
	Assertions.assert_equal(recorded_signals.size(), 1, "simulation_state_changed emitted once on PAUSE")
	Assertions.assert_true(recorded_signals[0], "simulation_state_changed emitted TRUE on PAUSE")
	
	# Empirical verification of SceneTree pausing behavior:
	# In InputManager (milestone INT-001), scene tree pausing is decoupled:
	# InputManager manages the simulation pause flag/signals (is_simulation_paused)
	# while SceneTree.paused is NOT modified by the input manager autoload.
	# This keeps UI, tweens, and input responsive without requiring global PROCESS_MODE overrides.
	print("    [ORACLE] SceneTree.paused in PAUSE context: ", paused)
	print("    [ORACLE] InputManager.is_simulation_paused() in PAUSE: ", im.is_simulation_paused())
	Assertions.assert_true(im.is_simulation_paused(), "PAUSE context simulation pause state verified")
	
	# 4G. Return to WORLD
	recorded_signals.clear()
	im.pop_to_world()
	Assertions.assert_false(im.is_simulation_paused(), "WORLD: is_simulation_paused restored to false")
	Assertions.assert_true(player.movement_enabled, "WORLD: player movement restored")
	Assertions.assert_true(player.look_enabled, "WORLD: player look restored")
	Assertions.assert_equal(recorded_signals.size(), 1, "simulation_state_changed emitted once on return to WORLD")
	Assertions.assert_false(recorded_signals[0], "simulation_state_changed emitted FALSE on return to WORLD")
	
	im.simulation_state_changed.disconnect(sig_callable)
	player.queue_free()
	if owns_im:
		im.queue_free()
	
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 4: Simulation pause compliance verified.")
	else:
		printerr("    [FAIL] Challenge 4: Simulation pause compliance failed.")
	return ok

# ==============================================================================
# CHALLENGE 5: Window Focus Loss Auto-Pause Oracle (PROTOTYPE § 5)
# ==============================================================================
func challenge_05_focus_loss_auto_pause() -> bool:
	print("\n  [CHALLENGE 5] Window Focus Loss Auto-Pause Oracle (PROTOTYPE § 5)")
	var initial_failures: int = Assertions.current_suite_failed
	
	var im: Node = root.get_node_or_null("InputManager")
	var owns_im := false
	if im == null:
		im = InputManagerClass.new()
		root.add_child(im)
		owns_im = true
	
	var player = PlayerControllerClass.new()
	root.add_child(player)
	im.register_player(player)
	im.pop_to_world()
	
	# Case 5A: Focus loss while in WORLD -> must push PAUSE
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Pre-condition: context is WORLD")
	im.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.PAUSE, "Focus loss in WORLD pushes PAUSE")
	Assertions.assert_true(im.is_simulation_paused(), "Simulation is paused on focus loss")
	Assertions.assert_false(player.movement_enabled, "Player movement disabled on focus loss")
	
	# Case 5B: Focus loss while already in a modal (e.g. BOOK) -> stays in BOOK
	im.pop_to_world()
	im.push_context(InputManagerClass.ContextMode.BOOK)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.BOOK, "Pre-condition: context is BOOK")
	im.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.BOOK, "Focus loss while in BOOK does not corrupt stack")
	
	# Case 5C: auto_pause_on_focus_loss disabled
	im.pop_to_world()
	im.auto_pause_on_focus_loss = false
	im.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "When auto_pause_on_focus_loss is false, context remains WORLD")
	im.auto_pause_on_focus_loss = true
	
	player.queue_free()
	if owns_im:
		im.queue_free()
	
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 5: Focus loss auto-pause verified.")
	else:
		printerr("    [FAIL] Challenge 5: Focus loss auto-pause failed.")
	return ok

# ==============================================================================
# CHALLENGE 6: Hotkey Input Dispatch & Modal Toggling Oracle
# ==============================================================================
func challenge_06_hotkey_input_dispatch() -> bool:
	print("\n  [CHALLENGE 6] Hotkey Input Dispatch & Modal Toggling Oracle")
	var initial_failures: int = Assertions.current_suite_failed
	
	var im: Node = root.get_node_or_null("InputManager")
	var owns_im := false
	if im == null:
		im = InputManagerClass.new()
		root.add_child(im)
		owns_im = true
	
	var player = PlayerControllerClass.new()
	root.add_child(player)
	im.register_player(player)
	im.pop_to_world()
	
	# 6A: 'open_book' action in WORLD pushes BOOK
	var ev_book = InputEventAction.new()
	ev_book.action = &"open_book"
	ev_book.pressed = true
	im._unhandled_input(ev_book)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.BOOK, "open_book pushes BOOK")
	
	# 6B: 'open_book' action again while in BOOK closes BOOK
	im._unhandled_input(ev_book)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "open_book in BOOK closes BOOK")
	
	# 6C: 'open_inventory' action in WORLD pushes STORAGE
	var ev_inv = InputEventAction.new()
	ev_inv.action = &"open_inventory"
	ev_inv.pressed = true
	im._unhandled_input(ev_inv)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.STORAGE, "open_inventory pushes STORAGE")
	
	# 6D: 'open_inventory' again while in STORAGE closes STORAGE
	im._unhandled_input(ev_inv)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "open_inventory in STORAGE closes STORAGE")
	
	# 6E: 'pause_menu' (Esc) in WORLD pushes PAUSE
	var ev_esc = InputEventAction.new()
	ev_esc.action = &"pause_menu"
	ev_esc.pressed = true
	im._unhandled_input(ev_esc)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.PAUSE, "pause_menu pushes PAUSE")
	
	# 6F: 'pause_menu' (Esc) in PAUSE closes PAUSE
	im._unhandled_input(ev_esc)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "pause_menu in PAUSE closes PAUSE")
	
	# 6G: 'pause_menu' (Esc) while in BOOK closes BOOK
	im.push_context(InputManagerClass.ContextMode.BOOK)
	im._unhandled_input(ev_esc)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "pause_menu in BOOK closes BOOK")
	
	player.queue_free()
	if owns_im:
		im.queue_free()
	
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 6: Hotkey input dispatch verified.")
	else:
		printerr("    [FAIL] Challenge 6: Hotkey input dispatch failed.")
	return ok

# ==============================================================================
# CHALLENGE 7: Player Lifecycle & Freed Node Resilience Oracle
# ==============================================================================
func challenge_07_player_lifecycle_resilience() -> bool:
	print("\n  [CHALLENGE 7] Player Lifecycle & Freed Node Resilience Oracle")
	var initial_failures: int = Assertions.current_suite_failed
	
	var im: Node = root.get_node_or_null("InputManager")
	var owns_im := false
	if im == null:
		im = InputManagerClass.new()
		root.add_child(im)
		owns_im = true
	
	# Test with null player
	im.register_player(null)
	im.push_context(InputManagerClass.ContextMode.BOOK)
	im.pop_context()
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Context transitions safe with null player")
	
	# Test with freed player node
	var temp_player = PlayerControllerClass.new()
	root.add_child(temp_player)
	im.register_player(temp_player)
	im.push_context(InputManagerClass.ContextMode.STORAGE)
	
	# Free player mid-modal
	temp_player.free()
	
	# Popping back to WORLD with freed player must not crash or throw errors
	var popped = im.pop_context()
	Assertions.assert_equal(popped, InputManagerClass.ContextMode.STORAGE, "Pop with freed player succeeds")
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Context restores to WORLD with freed player")
	
	if owns_im:
		im.queue_free()
	
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 7: Player lifecycle resilience verified.")
	else:
		printerr("    [FAIL] Challenge 7: Player lifecycle resilience failed.")
	return ok

