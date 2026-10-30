extends SceneTree

const Assertions = preload("res://tests/assertions.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")
const PlayerConfigClass = preload("res://scripts/player/player_config.gd")

func _init() -> void:
	print("==================================================")
	print("[EMPIRICAL_CHALLENGE] Independent Adversarial Challenge Harness")
	print("==================================================")
	Assertions.reset()
	var all_passed := true

	if not challenge_diagonal_movement_normalization():
		all_passed = false

	if not challenge_360_degree_sweep_normalization():
		all_passed = false

	if not challenge_extreme_pitch_clamp_spikes():
		all_passed = false

	if not challenge_pitch_clamp_stress_alternating_jitters():
		all_passed = false

	if not challenge_framerate_independence_multi_fps():
		all_passed = false

	if not challenge_framerate_independence_variable_jitter():
		all_passed = false

	if not challenge_player_geometry_and_eye_height():
		all_passed = false

	if not challenge_fall_recovery_and_zero_velocity():
		all_passed = false

	print("==================================================")
	print("[EMPIRICAL_CHALLENGE] SUMMARY:")
	print("  Assertions Passed: %d" % Assertions.current_suite_passed)
	print("  Assertions Failed: %d" % Assertions.current_suite_failed)

	if all_passed and Assertions.current_suite_failed == 0:
		print("  RESULT: EMPIRICAL CHALLENGE PASSED (Exit Code: 0)")
		print("==================================================")
		quit(0)
	else:
		printerr("  RESULT: EMPIRICAL CHALLENGE FAILED (Exit Code: 1)")
		print("==================================================")
		quit(1)

func challenge_diagonal_movement_normalization() -> bool:
	print("  [CHALLENGE 1] Diagonal Movement Normalization & Opposing Input Vectors")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	# Test all 4 diagonal input combinations with raw unnormalized inputs (length = sqrt(2) ~ 1.414)
	var raw_diagonals = [
		Vector2(1.0, 1.0),   # S + D
		Vector2(-1.0, 1.0),  # S + A
		Vector2(1.0, -1.0),  # W + D
		Vector2(-1.0, -1.0)  # W + A
	]

	for diag in raw_diagonals:
		var vel = player.calculate_movement_velocity(diag, Vector3.ZERO, 0.016, true)
		var horizontal_speed = Vector2(vel.x, vel.z).length()
		Assertions.assert_true(
			abs(horizontal_speed - 3.0) < 0.001,
			"Raw diagonal input %s must normalize to exactly 3.0 m/s (got %.5f m/s)" % [diag, horizontal_speed]
		)
		Assertions.assert_true(
			horizontal_speed <= 3.0001,
			"Horizontal speed must never exceed 3.0 m/s on diagonal input"
		)

	# Test normalized diagonals
	for diag in raw_diagonals:
		var norm_diag = diag.normalized()
		var vel = player.calculate_movement_velocity(norm_diag, Vector3.ZERO, 0.016, true)
		var horizontal_speed = Vector2(vel.x, vel.z).length()
		Assertions.assert_true(
			abs(horizontal_speed - 3.0) < 0.001,
			"Normalized diagonal input %s must produce exactly 3.0 m/s (got %.5f m/s)" % [norm_diag, horizontal_speed]
		)

	# Opposing inputs cancellation
	var opposing_inputs = [
		Vector2(0.0, 0.0), # W+S or A+D canceled
		Vector2(1.0 - 1.0, 0.0),
		Vector2(0.0, 1.0 - 1.0)
	]
	for opp in opposing_inputs:
		var vel = player.calculate_movement_velocity(opp, Vector3.ZERO, 0.016, true)
		Assertions.assert_equal(vel, Vector3.ZERO, "Opposing inputs must result in Vector3.ZERO")

	player.free()
	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    -> PASS: Diagonal movement normalization verified.")
	else:
		printerr("    -> FAIL: Diagonal movement normalization failed.")
	return ok

func challenge_360_degree_sweep_normalization() -> bool:
	print("  [CHALLENGE 2] 360-Degree Continuous Radial Angle Sweep Normalization")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	# Sweep 360 degrees in 1-degree increments
	for deg in range(360):
		var rad = deg_to_rad(float(deg))
		var input_dir = Vector2(cos(rad), sin(rad))
		var vel = player.calculate_movement_velocity(input_dir, Vector3.ZERO, 0.016, true)
		var speed = Vector2(vel.x, vel.z).length()
		Assertions.assert_true(
			abs(speed - 3.0) < 0.001,
			"Radial input at %d deg must have horizontal speed 3.0 m/s (got %.5f)" % [deg, speed]
		)
		Assertions.assert_false(is_nan(vel.x), "vel.x must not be NaN at %d deg" % deg)
		Assertions.assert_false(is_nan(vel.z), "vel.z must not be NaN at %d deg" % deg)

	player.free()
	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    -> PASS: 360-degree sweep normalization verified.")
	else:
		printerr("    -> FAIL: 360-degree sweep normalization failed.")
	return ok

func challenge_extreme_pitch_clamp_spikes() -> bool:
	print("  [CHALLENGE 3] Extreme Pitch Clamp Spikes (+/- 10,000 to +/- 10,000,000 Pixels)")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	var spike_values = [
		10000.0,
		-10000.0,
		50000.0,
		-50000.0,
		100000.0,
		-100000.0,
		1000000.0,
		-1000000.0,
		10000000.0,
		-10000000.0
	]

	for spike in spike_values:
		player.camera_pitch = 0.0
		# relative.y motion: negative is up, positive is down
		player.handle_mouse_look(Vector2(0.0, spike))
		var pitch_deg = player.get_pitch_degrees()
		Assertions.assert_false(is_nan(pitch_deg), "Pitch must not be NaN after spike %.1f" % spike)
		Assertions.assert_false(is_inf(pitch_deg), "Pitch must not be Inf after spike %.1f" % spike)
		Assertions.assert_true(
			pitch_deg >= -85.0001 and pitch_deg <= 85.0001,
			"Pitch must remain within [-85°, +85°] after spike %.1f (got %.4f°)" % [spike, pitch_deg]
		)
		# Verify head node matches
		if player.head:
			Assertions.assert_true(
				abs(player.head.rotation.x - player.camera_pitch) < 0.0001,
				"Head rotation.x must match camera_pitch"
			)

	player.free()
	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    -> PASS: Extreme pitch clamp spikes verified.")
	else:
		printerr("    -> FAIL: Extreme pitch clamp spikes failed.")
	return ok

func challenge_pitch_clamp_stress_alternating_jitters() -> bool:
	print("  [CHALLENGE 4] Pitch Clamp Alternating Spikes & Micro-Jitter Stress (1000 Iterations)")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	# 1000 alternating violent spikes (+10,000 px, -10,000 px)
	for i in range(1000):
		var delta_y = 10000.0 if (i % 2 == 0) else -10000.0
		player.handle_mouse_look(Vector2(0.0, delta_y))
		var pitch = player.get_pitch_degrees()
		if is_nan(pitch) or is_inf(pitch) or pitch < -85.001 or pitch > 85.001:
			Assertions.assert_true(false, "Pitch invalid during alternating spike iter %d: %.4f" % [i, pitch])
			break

	# Micro-jitters around top boundary (+85°)
	player.apply_pitch_degrees(85.0)
	for i in range(500):
		player.handle_mouse_look(Vector2(0.0, -0.001))
		var pitch = player.get_pitch_degrees()
		Assertions.assert_true(pitch <= 85.0001, "Pitch must not drift above 85° on micro-jitters")

	# Micro-jitters around bottom boundary (-85°)
	player.apply_pitch_degrees(-85.0)
	for i in range(500):
		player.handle_mouse_look(Vector2(0.0, 0.001))
		var pitch = player.get_pitch_degrees()
		Assertions.assert_true(pitch >= -85.0001, "Pitch must not drift below -85° on micro-jitters")

	player.free()
	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    -> PASS: Alternating spikes and micro-jitters verified.")
	else:
		printerr("    -> FAIL: Alternating spikes and micro-jitters failed.")
	return ok

func challenge_framerate_independence_multi_fps() -> bool:
	print("  [CHALLENGE 5] Framerate Independence Across Standard & High-Refresh Rates")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	var test_framerates = [15, 30, 45, 60, 75, 90, 120, 144, 240]
	var durations = [1.0, 3.0] # test 1.0s and 3.0s

	for duration in durations:
		var expected_distance = 3.0 * duration
		for fps in test_framerates:
			var total_frames = int(round(fps * duration))
			var delta = 1.0 / float(fps)
			var total_distance = 0.0
			for f in range(total_frames):
				var vel = player.calculate_movement_velocity(Vector2(0.0, -1.0), Vector3.ZERO, delta, true)
				total_distance += vel.length() * delta
			
			var diff = abs(total_distance - expected_distance)
			Assertions.assert_true(
				diff < 0.001,
				"FPS %d over %.1fs must yield %.3fm (got %.5fm, diff: %.6f)" % [fps, duration, expected_distance, total_distance, diff]
			)

	player.free()
	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    -> PASS: Multi-FPS framerate independence verified.")
	else:
		printerr("    -> FAIL: Multi-FPS framerate independence failed.")
	return ok

func challenge_framerate_independence_variable_jitter() -> bool:
	print("  [CHALLENGE 6] Framerate Independence Under Frame Time Jitter & Fluctuating Delta")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	# Irregular frame time distribution simulating real-world hitching/stuttering
	var deltas: Array[float] = [
		0.016, 0.033, 0.008, 0.025, 0.050, 0.011, 0.019, 0.040, 0.016, 0.005,
		0.060, 0.015, 0.020, 0.010, 0.030, 0.022, 0.018, 0.014, 0.017, 0.021
	]
	var total_time := 0.0
	for d in deltas:
		total_time += d

	var total_distance := 0.0
	for d in deltas:
		var vel = player.calculate_movement_velocity(Vector2(0.0, -1.0), Vector3.ZERO, d, true)
		total_distance += vel.length() * d

	var expected_distance = 3.0 * total_time
	var diff = abs(total_distance - expected_distance)
	Assertions.assert_true(
		diff < 0.001,
		"Fluctuating frame deltas (total %.4fs) must travel %.4fm (got %.4fm, diff: %.6f)" % [total_time, expected_distance, total_distance, diff]
	)

	player.free()
	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    -> PASS: Variable delta framerate independence verified.")
	else:
		printerr("    -> FAIL: Variable delta framerate independence failed.")
	return ok

func challenge_player_geometry_and_eye_height() -> bool:
	print("  [CHALLENGE 7] Player Capsule Geometry, Center Offset & Camera Eye Height")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	# Check CollisionShape3D
	var col_shape = player.find_child("CollisionShape3D", true, false) as CollisionShape3D
	Assertions.assert_not_null(col_shape, "CollisionShape3D must exist")
	var capsule = col_shape.shape as CapsuleShape3D
	Assertions.assert_not_null(capsule, "Shape must be CapsuleShape3D")
	
	# Radius ~0.4m, Height ~1.8m
	Assertions.assert_true(abs(capsule.radius - 0.4) < 0.05, "Capsule radius must be ~0.4m (got %.3f)" % capsule.radius)
	Assertions.assert_true(abs(capsule.height - 1.8) < 0.05, "Capsule height must be ~1.8m (got %.3f)" % capsule.height)
	
	# Bottom of capsule touches ground Y=0: center position.y must be height / 2 = 0.9m
	Assertions.assert_true(abs(col_shape.position.y - 0.9) < 0.05, "CollisionShape3D center Y must be 0.9m (got %.3f)" % col_shape.position.y)

	# Camera eye height: 1.6m from player base (feet)
	var head = player.find_child("Head", true, false) as Node3D
	var cam = player.find_child("Camera3D", true, false) as Camera3D
	var eye_height = head.position.y + cam.position.y
	Assertions.assert_true(abs(eye_height - 1.6) < 0.05, "Camera eye height must be 1.6m (got %.3f)" % eye_height)

	# FOV default 80
	Assertions.assert_equal(cam.fov, 80.0, "Camera default FOV must be 80.0")

	player.free()
	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    -> PASS: Player geometry and eye height verified.")
	else:
		printerr("    -> FAIL: Player geometry and eye height failed.")
	return ok

func challenge_fall_recovery_and_zero_velocity() -> bool:
	print("  [CHALLENGE 8] Fall Recovery Signal, Position Reset & Velocity Zeroing")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	# Connect recovery signal
	var signal_received: Array[Vector3] = []
	player.recovered_to_safe_position.connect(func(target: Vector3): signal_received.append(target))

	# Set fallen state
	player.position = Vector3(25.0, -100.0, -30.0)
	player.velocity = Vector3(12.0, -500.0, 8.0)
	player.rotation.y = 2.5
	player.apply_pitch_degrees(45.0)

	# Trigger recovery
	player.trigger_recovery()

	# Assertions
	Assertions.assert_equal(signal_received.size(), 1, "recovered_to_safe_position signal must be emitted exactly once")
	Assertions.assert_equal(player.position, player.default_safe_return_position, "Player position must be reset to default_safe_return_position (0, 0, 8)")
	Assertions.assert_equal(player.velocity, Vector3.ZERO, "Player velocity must be zeroed out completely")
	Assertions.assert_equal(player.camera_pitch, 0.0, "Player camera pitch must reset to 0.0")

	player.free()
	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    -> PASS: Fall recovery and velocity zeroing verified.")
	else:
		printerr("    -> FAIL: Fall recovery and velocity zeroing failed.")
	return ok
