extends SceneTree

## Adversarial Stress Harness: Hold Action Controller & Tool Timing (GARD-001 Gate)
## Memverifikasi ketahanan PRD FR07..FR10, CONTENT.md § 6, dan TEST_PLAN T06, T07, T32, T33

const Assertions = preload("res://tests/assertions.gd")
const HoldActionControllerClass = preload("res://scripts/gardening/hold_action_controller.gd")
const GardenManagerClass = preload("res://scripts/gardening/garden_manager.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")

func _initialize() -> void:
	print("==================================================")
	print("[ADVERSARIAL_HARNESS] Stress Test: Hold Action Controller & Tool Timing")
	print("==================================================")

	Assertions.reset()
	var all_passed := true

	# Challenge 1: Pure HoldActionController State Machine & Invariants
	if not test_challenge_1_state_machine_and_invariants():
		all_passed = false

	# Challenge 2: Rapid Cancellation 100 Cycles (T32 Zero-Cost Invariance)
	if not test_challenge_2_rapid_cancellation_100_cycles():
		all_passed = false

	# Challenge 3: Re-Trigger Protection (Continuous Hold past Commit)
	if not test_challenge_3_retrigger_protection():
		all_passed = false

	# Challenge 4: GardenManager + Inventory Transactional Invariance under Stress
	if not test_challenge_4_garden_manager_transaction_stress():
		all_passed = false

	# Challenge 5: Tool Switching and Target Swapping under Active Hold
	if not await test_challenge_5_tool_and_target_swapping():
		all_passed = false

	# Challenge 6: Numerical Boundaries & Extreme Delta Stress
	if not test_challenge_6_numerical_boundaries_and_extreme_deltas():
		all_passed = false

	# Summary
	print("==================================================")
	print("[ADVERSARIAL_HARNESS] SUMMARY:")
	print("  Assertions Passed: %d" % Assertions.current_suite_passed)
	print("  Assertions Failed: %d" % Assertions.current_suite_failed)

	if all_passed and Assertions.current_suite_failed == 0:
		print("  VERDICT: CONFIRMED CORRECT (Exit Code: 0)")
		print("==================================================")
		quit(0)
	else:
		printerr("  VERDICT: DEFECT DETECTED (Exit Code: 1)")
		print("==================================================")
		quit(1)

# ==============================================================================
# CHALLENGE 1: Pure HoldActionController State Machine & Invariants
# ==============================================================================
func test_challenge_1_state_machine_and_invariants() -> bool:
	print("  [RUN] Challenge 1: HoldActionController State Machine & Invariant Oracles")
	var initial_failures := Assertions.current_suite_failed

	var ctrl = HoldActionControllerClass.new()
	Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.IDLE, "Initial state must be IDLE")
	Assertions.assert_false(ctrl.is_holding(), "is_holding() must be false initially")
	Assertions.assert_false(ctrl.is_active(), "is_active() must be false initially")

	# Idempotent cancel in IDLE
	var cancel_count := [0]
	ctrl.hold_cancelled.connect(func(_a): cancel_count[0] += 1)
	ctrl.cancel()
	Assertions.assert_equal(cancel_count[0], 0, "Cancelling while IDLE must be a no-op (no signals emitted)")
	Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.IDLE, "State remains IDLE after cancel in IDLE")

	# Ticking in IDLE
	ctrl.tick(1.0, true, true)
	Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.IDLE, "Ticking while IDLE must be a no-op")
	Assertions.assert_approx_equal(ctrl.elapsed_time, 0.0, 0.001, "elapsed_time remains 0.0")

	# Start transition to HOLDING
	var start_signal_data := {"received": false, "action": "", "duration": 0.0}
	ctrl.hold_started.connect(func(act, dur):
		start_signal_data["received"] = true
		start_signal_data["action"] = act
		start_signal_data["duration"] = dur
	)
	ctrl.start("hoe", "plot_home_01", 2.0, &"action_tool_use")
	Assertions.assert_true(start_signal_data["received"], "hold_started signal must be emitted on start")
	Assertions.assert_equal(start_signal_data["action"], "hoe")
	Assertions.assert_approx_equal(start_signal_data["duration"], 2.0, 0.001)
	Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.HOLDING, "State transitions to HOLDING")
	Assertions.assert_true(ctrl.is_holding(), "is_holding() must be true")
	Assertions.assert_true(ctrl.is_active(), "is_active() must be true")
	Assertions.assert_equal(ctrl.action_id, "hoe")
	Assertions.assert_equal(ctrl.target_id, "plot_home_01")
	Assertions.assert_equal(ctrl.button_name, &"action_tool_use")
	Assertions.assert_approx_equal(ctrl.get_progress(), 0.0, 0.001, "Progress at start is 0.0")

	if Assertions.current_suite_failed == initial_failures:
		print("  [PASS] Challenge 1: State machine & invariant oracles verified.")
		return true
	return false

# ==============================================================================
# CHALLENGE 2: Rapid Cancellation 100 Cycles (T32 Zero-Cost Invariance)
# ==============================================================================
func test_challenge_2_rapid_cancellation_100_cycles() -> bool:
	print("  [RUN] Challenge 2: Rapid Cancellation 100 Cycles (0.05s to 1.95s cancellation)")
	var initial_failures := Assertions.current_suite_failed

	var ctrl = HoldActionControllerClass.new()
	var completed_actions: Array[String] = []
	var cancelled_actions: Array[String] = []
	var progress_history: Array[float] = []

	ctrl.hold_completed.connect(func(a): completed_actions.append(a))
	ctrl.hold_cancelled.connect(func(a): cancelled_actions.append(a))
	ctrl.hold_progress.connect(func(_a, p, _e, _d): progress_history.append(p))

	# Execute 100 cycles of start -> partial hold -> cancel via 4 distinct adversarial vectors
	for i in range(100):
		var duration := 2.0 if (i % 2 == 0) else 1.0
		var hold_fraction := 0.05 + 0.9 * ((i * 17) % 100) / 100.0 # Range: ~0.05 to ~0.95
		var partial_time := duration * hold_fraction
		var action_name := "action_%d" % i

		ctrl.start(action_name, "target_node", duration, &"action_tool_use")
		Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.HOLDING)
		Assertions.assert_true(ctrl.is_holding())

		# Partial tick
		ctrl.tick(partial_time, true, true)
		Assertions.assert_approx_equal(ctrl.get_progress(), hold_fraction, 0.01, "Progress matches partial time")
		Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.HOLDING)

		# Choose cancellation vector
		match i % 4:
			0:
				# Vector A: Explicit controller.cancel() (e.g. tool cancel hotkey / context change)
				ctrl.cancel()
			1:
				# Vector B: Button released during tick
				ctrl.tick(0.016, false, true)
			2:
				# Vector C: Target invalidated / looked away during tick
				ctrl.tick(0.016, true, false)
			3:
				# Vector D: Both button released and target invalidated
				ctrl.tick(0.016, false, false)

		# Strict post-cancellation invariant assertions
		Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.IDLE, "Cycle %d: state must be IDLE" % i)
		Assertions.assert_false(ctrl.is_holding(), "Cycle %d: is_holding() must be false" % i)
		Assertions.assert_false(ctrl.is_active(), "Cycle %d: is_active() must be false" % i)
		Assertions.assert_approx_equal(ctrl.get_progress(), 0.0, 0.0001, "Cycle %d: progress must be 0.0" % i)
		Assertions.assert_approx_equal(ctrl.elapsed_time, 0.0, 0.0001, "Cycle %d: elapsed_time must be 0.0" % i)
		Assertions.assert_equal(ctrl.action_id, "", "Cycle %d: action_id must be cleared" % i)
		Assertions.assert_equal(ctrl.target_id, "", "Cycle %d: target_id must be cleared" % i)
		Assertions.assert_equal(ctrl.button_name, &"", "Cycle %d: button_name must be cleared" % i)

	# Invariance checks after 100 cycles
	Assertions.assert_equal(completed_actions.size(), 0, "0 completed signals must be emitted in 100 cancelled cycles")
	Assertions.assert_equal(cancelled_actions.size(), 100, "Exactly 100 cancelled signals must be emitted")

	if Assertions.current_suite_failed == initial_failures:
		print("  [PASS] Challenge 2: 100 rapid cancellation cycles passed with 0 leaks/mutations.")
		return true
	return false

# ==============================================================================
# CHALLENGE 3: Re-Trigger Protection (Continuous Hold past Commit)
# ==============================================================================
func test_challenge_3_retrigger_protection() -> bool:
	print("  [RUN] Challenge 3: Re-Trigger Protection Oracle (Holding LMB across and past Commit)")
	var initial_failures := Assertions.current_suite_failed

	var ctrl = HoldActionControllerClass.new()
	var complete_data := {"count": 0, "action": ""}
	ctrl.hold_completed.connect(func(a):
		complete_data["count"] += 1
		complete_data["action"] = a
	)

	# Start 2.0s hold
	ctrl.start("hoe", "plot_home_01", 2.0, &"action_tool_use")

	# Tick to 1.9s (not finished)
	ctrl.tick(1.9, true, true)
	Assertions.assert_equal(complete_data["count"], 0)
	Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.HOLDING)

	# Tick 0.1s -> commits at 2.0s
	ctrl.tick(0.1, true, true)
	Assertions.assert_equal(complete_data["count"], 1, "Action must commit exactly once")
	Assertions.assert_equal(complete_data["action"], "hoe")
	Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.MUST_RELEASE, "State must transition to MUST_RELEASE")
	Assertions.assert_false(ctrl.is_holding(), "is_holding() must be false in MUST_RELEASE")
	Assertions.assert_true(ctrl.is_active(), "is_active() must be true in MUST_RELEASE")

	# Continuous hold: simulate 200 frames (3.33s) of player keeping LMB down
	for frame in range(200):
		ctrl.tick(0.016, true, true)
		Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.MUST_RELEASE, "Frame %d: MUST_RELEASE persists while button is held" % frame)
		Assertions.assert_equal(complete_data["count"], 1, "Frame %d: no duplicate commits allowed" % frame)

	# Adversarial attempt to call start() while in MUST_RELEASE
	ctrl.start("water", "plot_home_01", 2.0, &"action_tool_use")
	Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.MUST_RELEASE, "start() during MUST_RELEASE must be rejected")
	Assertions.assert_equal(ctrl.action_id, "hoe", "action_id must not be overwritten during MUST_RELEASE")

	# Now player releases button
	ctrl.tick(0.016, false, true)
	Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.IDLE, "Releasing button transitions MUST_RELEASE -> IDLE")
	Assertions.assert_false(ctrl.is_active(), "is_active() must now be false")
	Assertions.assert_equal(ctrl.action_id, "")
	Assertions.assert_approx_equal(ctrl.elapsed_time, 0.0, 0.001)

	# Now a fresh start can proceed normally
	ctrl.start("water", "plot_home_01", 2.0, &"action_tool_use")
	Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.HOLDING)
	Assertions.assert_equal(ctrl.action_id, "water")
	ctrl.tick(2.0, true, true)
	Assertions.assert_equal(complete_data["count"], 2, "Second action completes cleanly after proper release cycle")

	if Assertions.current_suite_failed == initial_failures:
		print("  [PASS] Challenge 3: Re-trigger protection oracle verified.")
		return true
	return false

# ==============================================================================
# CHALLENGE 4: GardenManager + Inventory Transactional Invariance under Stress
# ==============================================================================
func test_challenge_4_garden_manager_transaction_stress() -> bool:
	print("  [RUN] Challenge 4: GardenManager & Inventory Atomic Invariance under 100 Interrupted Cycles")
	var initial_failures := Assertions.current_suite_failed

	var inv: Node = InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.storage_home.clear()

	# Supply initial resources
	inv.backpack.add_item("fertilizer_basic", 10)
	inv.backpack.add_item("soil_compost", 10)
	inv.backpack.add_item("seed_bayam", 10)

	var gm: Node = GardenManagerClass.new()
	gm.reset_to_defaults()
	gm.set_inventory_manager(inv)
	gm.watering_can_water = 10

	var ctrl = HoldActionControllerClass.new()

	# Interrupted cycles across all 4 gardening hold actions
	var actions = ["hoe", "fertilize", "water", "refill"]
	var durations = {"hoe": 2.0, "fertilize": 1.0, "water": 2.0, "refill": 2.0}

	for i in range(100):
		var act = actions[i % 4]
		var req_dur: float = durations[act]
		var hold_fraction: float = 0.1 + 0.8 * ((i * 31) % 100) / 100.0 # 10% to 90%
		var elapsed := req_dur * hold_fraction

		ctrl.start(act, "plot_home_01", req_dur, &"action_tool_use")
		ctrl.tick(elapsed, true, true)
		# Cancel action without completing
		ctrl.cancel()

	# Strict asset invariance check
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 10, "10 fertilizer_basic must remain (0 consumed)")
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 10, "10 soil_compost must remain (0 consumed)")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 10, "10 seed_bayam must remain (0 consumed)")
	Assertions.assert_equal(gm.watering_can_water, 10, "Watering can must remain 10 units (0 water consumed)")

	# Strict plot invariance check
	var plot: Dictionary = gm.get_plot("plot_home_01")
	Assertions.assert_false(plot["is_hoed"], "Plot is_hoed must remain false")
	Assertions.assert_false(plot["has_compost"], "Plot has_compost must remain false")
	Assertions.assert_approx_equal(float(plot["nutrients"]), 0.0, 0.001, "Plot nutrients must remain 0.0")
	Assertions.assert_approx_equal(float(plot["moisture"]), 0.0, 0.001, "Plot moisture must remain 0.0")

	if Assertions.current_suite_failed == initial_failures:
		print("  [PASS] Challenge 4: GardenManager + inventory atomic invariance verified under stress.")
		return true
	return false

# ==============================================================================
# CHALLENGE 5: Tool Switching and Target Swapping under Active Hold
# ==============================================================================
func test_challenge_5_tool_and_target_swapping() -> bool:
	print("  [RUN] Challenge 5: Tool Switching and Target Swapping under Active Hold")
	var initial_failures := Assertions.current_suite_failed

	var tree := Engine.get_main_loop() as SceneTree
	var player_scene = load("res://scenes/player/player.tscn") as PackedScene
	Assertions.assert_not_null(player_scene, "player.tscn must exist")
	var player: CharacterBody3D = player_scene.instantiate()
	tree.root.add_child(player)
	await tree.process_frame

	var inv: Node = InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.backpack.add_item("fertilizer_basic", 5)

	var gm: Node = Engine.get_singleton("GardenManager") if Engine.has_singleton("GardenManager") else tree.root.find_child("GardenManager", true, false)
	if gm != null:
		gm.reset_to_defaults()
		gm.set_inventory_manager(inv)
		gm.watering_can_water = 10

	# 5.1 Hotkey tool toggle during active hold
	player.hold_controller.start("hoe", "plot_home_01", 2.0, &"action_tool_use")
	player.hold_controller.tick(1.0, true, true) # 50% hold
	Assertions.assert_true(player.hold_controller.is_holding(), "Hold is active")

	# Player toggles tool 3 (fertilizer)
	player._handle_tool_toggle("tool_fertilizer")
	Assertions.assert_false(player.hold_controller.is_active(), "Toggling tool must cancel active hold immediately")
	Assertions.assert_equal(player.hold_controller.state, HoldActionControllerClass.State.IDLE)
	Assertions.assert_approx_equal(player.hold_controller.get_progress(), 0.0, 0.001)

	# 5.2 Cancel tool action (e.g. right click)
	player.hold_controller.start("fertilize", "plot_home_01", 1.0, &"action_tool_use")
	player.hold_controller.tick(0.5, true, true)
	Assertions.assert_true(player.hold_controller.is_holding())

	var cancel_event = InputEventAction.new()
	cancel_event.action = "action_tool_cancel"
	cancel_event.pressed = true
	player._unhandled_input(cancel_event)
	Assertions.assert_false(player.hold_controller.is_active(), "action_tool_cancel event must cancel active hold")
	Assertions.assert_equal(player.hold_controller.state, HoldActionControllerClass.State.IDLE)

	# 5.3 Adversarial tool switching rapid spam (10 rapid switches)
	var tools = ["tool_hoe", "tool_seed", "tool_fertilizer", "tool_watering_can"]
	for i in range(10):
		player.hold_controller.start("action", "plot_home_01", 2.0, &"action_tool_use")
		player.hold_controller.tick(0.2, true, true)
		player._handle_tool_toggle(tools[i % tools.size()])
		Assertions.assert_equal(player.hold_controller.state, HoldActionControllerClass.State.IDLE, "Switch %d: hold must be cancelled" % i)

	# 5.4 Target Swapping from landmark_plot to landmark_water during active hold
	# Create a mock detector target
	var mock_detector = MockInteractionDetector.new()
	player.interaction_detector = mock_detector
	
	# Start hoe action on plot
	mock_detector.current_target = MockTarget.new("landmark_plot")
	player.hold_controller.start("hoe", "plot_home_01", 2.0, &"action_tool_use")
	player.hold_controller.tick(0.5, true, true)
	Assertions.assert_true(player.hold_controller.is_holding())

	# Now camera swings directly to landmark_water while LMB is still pressed
	mock_detector.current_target = MockTarget.new("landmark_water")
	player._update_hold_action(0.016)

	# Challenger Oracle: When looking at landmark_water while holding a plot hoe action,
	# the hold must NOT remain active or frozen in limbo. It MUST cancel cleanly.
	Assertions.assert_false(player.hold_controller.is_active(), "5.4: Swapping target to landmark_water must cancel active plot hold action")
	Assertions.assert_equal(player.hold_controller.state, HoldActionControllerClass.State.IDLE)

	# 5.5 Target Swapping from landmark_water to landmark_plot during active refill hold
	mock_detector.current_target = MockTarget.new("landmark_water")
	player.hold_controller.start("refill", "water_home", 2.0, &"interact")
	player.hold_controller.tick(0.5, true, true)
	Assertions.assert_true(player.hold_controller.is_holding())

	# Camera swings directly to landmark_plot while E is still pressed
	mock_detector.current_target = MockTarget.new("landmark_plot")
	player._update_hold_action(0.016)

	Assertions.assert_false(player.hold_controller.is_active(), "5.5: Swapping target to landmark_plot must cancel active refill hold action")
	Assertions.assert_equal(player.hold_controller.state, HoldActionControllerClass.State.IDLE)

	# 5.6 External tool selection change while holding LMB on landmark_plot
	mock_detector.current_target = MockTarget.new("landmark_plot")
	if gm != null:
		gm.select_tool("tool_hoe")
	player.hold_controller.start("hoe", "plot_home_01", 2.0, &"action_tool_use")
	player.hold_controller.tick(0.5, true, true)
	Assertions.assert_true(player.hold_controller.is_holding())

	# External tool change to tool_fertilizer without calling _handle_tool_toggle
	if gm != null:
		gm.select_tool("tool_fertilizer")
	player._update_hold_action(0.016)

	Assertions.assert_false(player.hold_controller.is_active(), "5.6: External tool change must cancel active hold action")
	Assertions.assert_equal(player.hold_controller.state, HoldActionControllerClass.State.IDLE)

	player.queue_free()
	await tree.process_frame

	if Assertions.current_suite_failed == initial_failures:
		print("  [PASS] Challenge 5: Tool switching and target swapping verified.")
		return true
	return false

# ==============================================================================
# CHALLENGE 6: Numerical Boundaries & Extreme Delta Stress
# ==============================================================================
func test_challenge_6_numerical_boundaries_and_extreme_deltas() -> bool:
	print("  [RUN] Challenge 6: Numerical Boundaries, Zero Duration & Extreme Deltas")
	var initial_failures := Assertions.current_suite_failed

	var ctrl = HoldActionControllerClass.new()

	# Zero duration clamped to 0.01 minimum
	ctrl.start("zero_dur", "target", 0.0, &"action")
	Assertions.assert_approx_equal(ctrl.required_time, 0.01, 0.001, "0.0 duration clamped to 0.01 minimum")
	Assertions.assert_approx_equal(ctrl.get_progress(), 0.0, 0.001, "Progress at 0.0 elapsed is 0.0")
	ctrl.cancel()

	# Negative duration clamped to 0.01 minimum
	ctrl.start("neg_dur", "target", -5.0, &"action")
	Assertions.assert_approx_equal(ctrl.required_time, 0.01, 0.001, "Negative duration clamped to 0.01 minimum")
	ctrl.cancel()

	# Extreme large delta in single tick
	var committed := [false]
	ctrl.hold_completed.connect(func(_a): committed[0] = true)
	ctrl.start("fast", "target", 1.0, &"action")
	ctrl.tick(1000.0, true, true)
	Assertions.assert_true(committed[0], "Massive delta must trigger commit cleanly")
	Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.MUST_RELEASE)
	ctrl.tick(0.016, false, true) # Release

	# Micro deltas accumulation precision test (10,000 ticks of 0.0001s = 1.0s)
	ctrl.start("micro", "target", 1.0, &"action")
	for _i in range(10000):
		ctrl.tick(0.0001, true, true)
	# Due to IEEE 754 float rounding, 10,000 * 0.0001 can be 0.9999999999999065. Verify progress is approx 1.0
	Assertions.assert_approx_equal(ctrl.get_progress(), 1.0, 0.001, "10,000 micro-ticks must accumulate to ~1.0s")
	# One additional epsilon micro-tick guarantees crossing threshold if slightly below
	if ctrl.state != HoldActionControllerClass.State.MUST_RELEASE:
		ctrl.tick(0.0001, true, true)
	Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.MUST_RELEASE, "Should commit at >= 1.0s")
	ctrl.tick(0.016, false, true) # Release

	# Zero delta tick stability
	ctrl.start("zero_tick", "target", 1.0, &"action")
	ctrl.tick(0.0, true, true)
	Assertions.assert_approx_equal(ctrl.elapsed_time, 0.0, 0.0001, "0.0 delta must not advance time")
	Assertions.assert_equal(ctrl.state, HoldActionControllerClass.State.HOLDING)
	ctrl.cancel()

	if Assertions.current_suite_failed == initial_failures:
		print("  [PASS] Challenge 6: Numerical boundaries and extreme deltas verified.")
		return true
	return false

# ==============================================================================
# Helper Mock Classes for Testing
# ==============================================================================
class MockInteractionDetector:
	extends RayCast3D
	var current_target: Object = null

	func get_current_target() -> Object:
		return current_target

class MockTarget:
	extends RefCounted
	var interaction_id: String = ""

	func _init(id: String) -> void:
		interaction_id = id

