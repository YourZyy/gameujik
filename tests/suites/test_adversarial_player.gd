class_name TestAdversarialPlayer
extends RefCounted

## Adversarial & Edge-Case Stress Suite untuk PLY-001 (Player Controller & Physics)
const Assertions = preload("res://tests/assertions.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")
const LevelGrayboxClass = preload("res://scripts/world/level_graybox.gd")

func run_all() -> bool:
	var passed := true
	print("==================================================")
	print("[ADVERSARIAL_SUITE] PLY-001 Stress Test & Edge Case Verification")
	print("==================================================")

	if not test_adv01_opposing_inputs_cancellation():
		passed = false
	if not test_adv02_continuous_yaw_multi_rotation():
		passed = false
	if not test_adv03_pitch_clamp_boundary_precision():
		passed = false
	if not test_adv04_extreme_mouse_motion_spikes():
		passed = false
	if not test_adv05_teleport_during_terminal_velocity():
		passed = false
	if not test_adv06_automated_fall_recovery_integration():
		passed = false

	return passed

func test_adv01_opposing_inputs_cancellation() -> bool:
	print("  [RUN] ADV.PLY-01: Opposing Input Vector Cancellation (W+S, A+D)")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	# Opposing W + S: input_dir = Vector2(0, 0)
	var vel_ws = player.calculate_movement_velocity(Vector2(0.0, 0.0), Vector3.ZERO, 0.016, true)
	Assertions.assert_equal(vel_ws, Vector3.ZERO, "Simultaneous W+S must cancel out to Vector3.ZERO")

	# Opposing A + D: input_dir = Vector2(0, 0)
	var vel_ad = player.calculate_movement_velocity(Vector2(0.0, 0.0), Vector3.ZERO, 0.016, true)
	Assertions.assert_equal(vel_ad, Vector3.ZERO, "Simultaneous A+D must cancel out to Vector3.ZERO")

	# Opposing diagonal W+S with D pressed: input_dir = Vector2(1, 0)
	var vel_ws_d = player.calculate_movement_velocity(Vector2(1.0, 0.0), Vector3.ZERO, 0.016, true)
	Assertions.assert_true(abs(vel_ws_d.x - 3.0) < 0.001, "W+S canceled while D pressed moves purely right at 3.0 m/s")
	Assertions.assert_true(abs(vel_ws_d.z) < 0.001, "Z velocity remains 0 when W+S cancel")

	player.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.PLY-01: Opposing input cancellation verified.")
	else:
		printerr("  [FAIL] ADV.PLY-01: Opposing input cancellation failed.")
	return ok

func test_adv02_continuous_yaw_multi_rotation() -> bool:
	print("  [RUN] ADV.PLY-02: Continuous Multi-turn Yaw Stability (10 Full 360° Rotations)")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	# Simulate 10 full 360-degree rotations in small steps
	var steps = 1000
	var delta_x_per_step = (TAU * 10.0) / (steps * player.mouse_sensitivity)

	for i in range(steps):
		player.handle_mouse_look(Vector2(delta_x_per_step, 0.0))

	# Ensure rotation is not NaN or Inf
	Assertions.assert_false(is_nan(player.rotation.y), "Yaw rotation must not be NaN after multi-turn")
	Assertions.assert_false(is_inf(player.rotation.y), "Yaw rotation must not be Infinite after multi-turn")
	
	# Pitch must remain strictly 0
	Assertions.assert_true(abs(player.get_pitch_degrees()) < 0.001, "Pitch must remain unaffected during yaw rotation")

	player.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.PLY-02: Continuous multi-turn yaw stability verified.")
	else:
		printerr("  [FAIL] ADV.PLY-02: Continuous multi-turn yaw stability failed.")
	return ok

func test_adv03_pitch_clamp_boundary_precision() -> bool:
	print("  [RUN] ADV.PLY-03: Pitch Clamp Boundary Precision at [-85.0°, +85.0°]")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	# Exact boundary values
	player.apply_pitch_degrees(85.0)
	Assertions.assert_true(abs(player.get_pitch_degrees() - 85.0) < 0.0001, "Exact +85° must be maintained")

	player.apply_pitch_degrees(-85.0)
	Assertions.assert_true(abs(player.get_pitch_degrees() - (-85.0)) < 0.0001, "Exact -85° must be maintained")

	# Slightly outside boundaries
	player.apply_pitch_degrees(85.0001)
	Assertions.assert_true(abs(player.get_pitch_degrees() - 85.0) < 0.001, "+85.0001° must clamp to +85°")

	player.apply_pitch_degrees(-85.0001)
	Assertions.assert_true(abs(player.get_pitch_degrees() - (-85.0)) < 0.001, "-85.0001° must clamp to -85°")

	player.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.PLY-03: Pitch clamp boundary precision verified.")
	else:
		printerr("  [FAIL] ADV.PLY-03: Pitch clamp boundary precision failed.")
	return ok

func test_adv04_extreme_mouse_motion_spikes() -> bool:
	print("  [RUN] ADV.PLY-04: Extreme Mouse Motion Spikes (+/- 10,000,000 Pixels)")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	# Massive spike upwards
	player.handle_mouse_look(Vector2(0.0, -10000000.0))
	Assertions.assert_true(abs(player.get_pitch_degrees() - 85.0) < 0.001, "Extreme upward spike must clamp safely to 85°")
	Assertions.assert_false(is_nan(player.get_pitch_degrees()), "Pitch must not be NaN after massive spike")

	# Massive spike downwards
	player.handle_mouse_look(Vector2(0.0, 20000000.0))
	Assertions.assert_true(abs(player.get_pitch_degrees() - (-85.0)) < 0.001, "Extreme downward spike must clamp safely to -85°")
	Assertions.assert_false(is_nan(player.get_pitch_degrees()), "Pitch must not be NaN after massive spike")

	player.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.PLY-04: Extreme mouse motion spikes handled safely.")
	else:
		printerr("  [FAIL] ADV.PLY-04: Extreme mouse motion spikes failed.")
	return ok

func test_adv05_teleport_during_terminal_velocity() -> bool:
	print("  [RUN] ADV.PLY-05: Teleportation with Extreme Terminal Velocity (-250 m/s)")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	player.position = Vector3(100.0, -100.0, 100.0)
	player.velocity = Vector3(50.0, -250.0, -80.0)

	player.teleport_to(Vector3(0.0, 0.0, 1.0), 0.0)

	Assertions.assert_equal(player.position, Vector3(0.0, 0.0, 1.0), "Position must be exactly at teleport target")
	Assertions.assert_equal(player.velocity, Vector3.ZERO, "Extreme velocity must be completely erased to Vector3.ZERO")

	player.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.PLY-05: Teleportation during terminal velocity verified.")
	else:
		printerr("  [FAIL] ADV.PLY-05: Teleportation during terminal velocity failed.")
	return ok

func test_adv06_automated_fall_recovery_integration() -> bool:
	print("  [RUN] ADV.PLY-06: Automatic Physics Process Fall Recovery below Y = -5.0")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	# Place player at Y = -6.0 and trigger physics step
	player.position = Vector3(10.0, -6.0, 15.0)
	player.velocity = Vector3(0.0, -30.0, 0.0)

	# Execute _physics_process
	player._physics_process(0.016)

	Assertions.assert_equal(player.position, player.default_safe_return_position, "Physics process must auto-recover player to safe_return_home")
	Assertions.assert_equal(player.velocity, Vector3.ZERO, "Velocity must be reset to zero on auto-recovery")

	player.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV.PLY-06: Automatic physics fall recovery verified.")
	else:
		printerr("  [FAIL] ADV.PLY-06: Automatic physics fall recovery failed.")
	return ok
