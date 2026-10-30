extends SceneTree

## Empirical Challenge Harness: REBUILD-001 / PLY-001 Player Controller
## Stress-tests Framerate Independence, Pitch Clamping, Input Gating, Trauma Decay, and Teleport Reset

const Assertions = preload("res://tests/assertions.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")
const PlayerConfigClass = preload("res://scripts/player/player_config.gd")

func _initialize() -> void:
	print("==================================================")
	print("[CHALLENGER_STRESS_PLAYER] REBUILD-001 Empirical Stress Suite")
	print("==================================================")
	
	Assertions.reset()
	var all_passed := true

	# Suite 1: Framerate independence across extreme deltas (15, 60, 144, 300 FPS)
	if not test_framerate_independence_extreme():
		all_passed = false

	# Suite 2: Pitch clamp bounds & extreme mouse motion spikes (+/- 100,000 px)
	if not test_pitch_clamp_extreme_spikes():
		all_passed = false

	# Suite 3: Input gating flags (movement_enabled & look_enabled)
	if not test_input_gating_freeze_and_resume():
		all_passed = false

	# Suite 4: Camera shake trauma decay & game feel invariants
	if not test_trauma_shake_decay_and_feel():
		all_passed = false

	# Suite 5: Teleport interpolation reset & state cleanliness
	if not test_teleport_interpolation_and_reset():
		all_passed = false

	# Suite 6: Resolution independence & stretch mode robustness
	if not test_resolution_independence_motion():
		all_passed = false

	# Summary
	print("==================================================")
	print("[CHALLENGER_STRESS_PLAYER] VERIFICATION SUMMARY:")
	print("  Assertions Passed: %d" % Assertions.current_suite_passed)
	print("  Assertions Failed: %d" % Assertions.current_suite_failed)

	if all_passed and Assertions.current_suite_failed == 0:
		print("  VERDICT: CONFIRMED CORRECT")
		print("  All PLY-001 / REBUILD-001 empirical stress criteria verified successfully.")
		print("==================================================")
		quit(0)
	else:
		printerr("  VERDICT: ISSUE DETECTED")
		printerr("  Stress test failures encountered:")
		for msg in Assertions.failure_messages:
			printerr("    - ", msg)
		print("==================================================")
		quit(1)

func test_framerate_independence_extreme() -> bool:
	print("  [TEST 1] Framerate Independence Across Extreme Delta Values")
	var initial_failures: int = Assertions.current_suite_failed

	var scene_res := ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	Assertions.assert_not_null(scene_res, "Player scene must load")
	var player := scene_res.instantiate() as PlayerControllerClass
	player._ready()

	# Framerates to test:
	# 15 FPS: delta = 1/15 = 0.066667s
	# 60 FPS: delta = 1/60 = 0.016667s
	# 144 FPS: delta = 1/144 = 0.006944s
	# 300 FPS: delta = 1/300 = 0.003333s
	# Extreme boundary: 2 FPS (delta 0.5s) and 10,000 FPS (delta 0.0001s)
	var test_framerates: Array[int] = [15, 60, 144, 300]
	var test_directions: Array[Dictionary] = [
		{"name": "Forward", "dir": Vector2(0.0, -1.0)},
		{"name": "Backward", "dir": Vector2(0.0, 1.0)},
		{"name": "Left", "dir": Vector2(-1.0, 0.0)},
		{"name": "Right", "dir": Vector2(1.0, 0.0)},
		{"name": "Diagonal_Norm", "dir": Vector2(1.0, -1.0).normalized()},
		{"name": "Diagonal_Raw", "dir": Vector2(1.0, 1.0)}, # unnormalized diagonal input
	]

	# Test instantaneous speed at every framerate and direction
	for fps in test_framerates:
		var delta: float = 1.0 / float(fps)
		for t_dir in test_directions:
			var input_vec: Vector2 = t_dir["dir"]
			var vel := player.calculate_movement_velocity(input_vec, Vector3.ZERO, delta, true)
			var h_speed := Vector2(vel.x, vel.z).length()
			var diff := absf(h_speed - 3.0)
			Assertions.assert_true(diff < 0.0001, 
				"Instantaneous speed at %d FPS for %s must be exactly 3.0 m/s (got %.6f, diff=%.6f)" % [fps, t_dir["name"], h_speed, diff])

	# Test extreme delta boundaries
	var vel_hitch := player.calculate_movement_velocity(Vector2(0, -1), Vector3.ZERO, 0.5, true)
	Assertions.assert_approx_equal(Vector2(vel_hitch.x, vel_hitch.z).length(), 3.0, 0.0001, "Speed during 0.5s hitch must be exactly 3.0 m/s")

	var vel_micro := player.calculate_movement_velocity(Vector2(0, -1), Vector3.ZERO, 0.0001, true)
	Assertions.assert_approx_equal(Vector2(vel_micro.x, vel_micro.z).length(), 3.0, 0.0001, "Speed during 0.0001s micro-step must be exactly 3.0 m/s")

	# Test distance accumulation over 1.0 full simulated second for each target FPS
	var distances: Array[float] = []
	for fps in test_framerates:
		var delta: float = 1.0 / float(fps)
		var total_dist: float = 0.0
		for frame in range(fps):
			var vel := player.calculate_movement_velocity(Vector2(0.0, -1.0), Vector3.ZERO, delta, true)
			total_dist += vel.length() * delta
		distances.append(total_dist)
		print("    FPS: %3d | Delta: %.6fs | Total Distance in 1.0s: %.6f m" % [fps, delta, total_dist])
		var dist_diff := absf(total_dist - 3.0)
		Assertions.assert_true(dist_diff < 0.0001, 
			"Distance over 1.0s at %d FPS must be 3.0000m (got %.6fm)" % [fps, total_dist])

	# Cross-framerate discrepancy between 15 FPS and 300 FPS
	var max_diff: float = absf(distances[0] - distances[3])
	Assertions.assert_true(max_diff < 0.00001, 
		"Discrepancy between 15 FPS and 300 FPS must be < 0.00001m (got %.8fm)" % max_diff)

	player.free()
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Test 1: Framerate independence across 15, 60, 144, 300 FPS verified.")
	else:
		printerr("    [FAIL] Test 1: Framerate independence failed.")
	return ok

func test_pitch_clamp_extreme_spikes() -> bool:
	print("  [TEST 2] Pitch Clamp Bounds and Extreme Mouse Look Spikes (+/- 100,000 px)")
	var initial_failures: int = Assertions.current_suite_failed

	var scene_res := ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player := scene_res.instantiate() as PlayerControllerClass
	player._ready()

	# 1. Direct degrees API clamping
	player.apply_pitch_degrees(85.0)
	Assertions.assert_approx_equal(player.get_pitch_degrees(), 85.0, 0.001, "Pitch +85° must register exactly")

	player.apply_pitch_degrees(-85.0)
	Assertions.assert_approx_equal(player.get_pitch_degrees(), -85.0, 0.001, "Pitch -85° must register exactly")

	player.apply_pitch_degrees(90.0)
	Assertions.assert_approx_equal(player.get_pitch_degrees(), 85.0, 0.001, "Pitch +90° must clamp to +85°")

	player.apply_pitch_degrees(-90.0)
	Assertions.assert_approx_equal(player.get_pitch_degrees(), -85.0, 0.001, "Pitch -90° must clamp to -85°")

	player.apply_pitch_degrees(1000.0)
	Assertions.assert_approx_equal(player.get_pitch_degrees(), 85.0, 0.001, "Pitch +1000° must clamp to +85°")

	player.apply_pitch_degrees(-1000.0)
	Assertions.assert_approx_equal(player.get_pitch_degrees(), -85.0, 0.001, "Pitch -1000° must clamp to -85°")

	# 2. Extreme mouse look vectors: +/- 100,000 pixels
	player.apply_pitch_degrees(0.0)
	# Huge upward flick (negative relative Y in FPS screen space)
	player.handle_mouse_look(Vector2(0.0, -100000.0))
	var pitch_up := player.get_pitch_degrees()
	Assertions.assert_true(pitch_up <= 85.0001, "Pitch after -100,000px mouse motion must not exceed +85° (got %.4f°)" % pitch_up)
	Assertions.assert_true(pitch_up >= 84.9999, "Pitch after -100,000px mouse motion must reach +85° (got %.4f°)" % pitch_up)

	# Huge downward flick (positive relative Y)
	player.handle_mouse_look(Vector2(0.0, 100000.0))
	var pitch_down := player.get_pitch_degrees()
	Assertions.assert_true(pitch_down >= -85.0001, "Pitch after +100,000px mouse motion must not go below -85° (got %.4f°)" % pitch_down)
	Assertions.assert_true(pitch_down <= -84.9999, "Pitch after +100,000px mouse motion must reach -85° (got %.4f°)" % pitch_down)

	# 3. Colossal 10,000,000 pixel spike
	player.handle_mouse_look(Vector2(0.0, -10000000.0))
	Assertions.assert_true(player.get_pitch_degrees() <= 85.0001, "10M pixel upward spike must clamp strictly to +85°")
	player.handle_mouse_look(Vector2(0.0, 10000000.0))
	Assertions.assert_true(player.get_pitch_degrees() >= -85.0001, "10M pixel downward spike must clamp strictly to -85°")

	# 4. Diagonal extreme spike (large X and large Y simultaneously)
	player.handle_mouse_look(Vector2(50000.0, -100000.0))
	Assertions.assert_true(player.get_pitch_degrees() <= 85.0001, "Diagonal extreme spike must clamp pitch to +85°")
	Assertions.assert_false(is_nan(player.rotation.y), "Diagonal extreme spike must not cause NaN yaw")
	Assertions.assert_false(is_inf(player.rotation.y), "Diagonal extreme spike must not cause Inf yaw")

	# 5. Rapid alternating oscillation stress test (200 spikes)
	for i in range(200):
		var y_delta: float = 100000.0 if (i % 2 == 0) else -100000.0
		player.handle_mouse_look(Vector2(50.0, y_delta))
		var cur_p := player.get_pitch_degrees()
		if cur_p > 85.0001 or cur_p < -85.0001:
			Assertions.assert_true(false, "Oscillation cycle %d breached pitch bounds: %.4f°" % [i, cur_p])
			break

	# 6. Verify head node rotation is strictly synchronized
	if player.head:
		var head_pitch_deg := rad_to_deg(player.head.rotation.x)
		var cam_pitch_deg := player.get_pitch_degrees()
		Assertions.assert_approx_equal(head_pitch_deg, cam_pitch_deg, 0.001, "Head rotation.x must strictly match camera_pitch")

	player.free()
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Test 2: Pitch clamp bounds and extreme mouse spikes verified.")
	else:
		printerr("    [FAIL] Test 2: Pitch clamp bounds failed.")
	return ok

func test_input_gating_freeze_and_resume() -> bool:
	print("  [TEST 3] Input Gating Flags (movement_enabled & look_enabled)")
	var initial_failures: int = Assertions.current_suite_failed

	var scene_res := ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player := scene_res.instantiate() as PlayerControllerClass
	player._ready()

	# --- Part A: Look Gating ---
	player.look_enabled = false
	var saved_yaw := player.rotation.y
	var saved_pitch := player.camera_pitch

	# Send various mouse look commands while look is disabled
	player.handle_mouse_look(Vector2(50.0, 50.0))
	player.handle_mouse_look(Vector2(-100000.0, 100000.0))
	Assertions.assert_equal(player.rotation.y, saved_yaw, "Disabled look must completely freeze yaw")
	Assertions.assert_equal(player.camera_pitch, saved_pitch, "Disabled look must completely freeze pitch")
	if player.head:
		Assertions.assert_equal(player.head.rotation.x, saved_pitch, "Disabled look must freeze head rotation")

	# Re-enable look and verify normal operation resumes cleanly
	player.look_enabled = true
	player.handle_mouse_look(Vector2(100.0, 0.0))
	Assertions.assert_ne(player.rotation.y, saved_yaw, "Re-enabled look must process mouse yaw immediately")

	# --- Part B: Movement Gating ---
	player.movement_enabled = false
	player.velocity = Vector3(10.0, 0.0, 10.0) # pre-existing dirty velocity
	player._physics_process(0.016)

	Assertions.assert_equal(player.velocity.x, 0.0, "Disabled movement must zero horizontal X velocity")
	Assertions.assert_equal(player.velocity.z, 0.0, "Disabled movement must zero horizontal Z velocity")

	# Simulate 60 physics frames with movement disabled: state must remain completely static
	var pos_before := player.position
	for frame in range(60):
		player._physics_process(0.016)
	Assertions.assert_equal(player.position, pos_before, "Disabled movement must prevent any positional displacement over 60 frames")

	# Re-enable movement and verify velocity calculation functions
	player.movement_enabled = true
	var active_vel := player.calculate_movement_velocity(Vector2(0, -1), Vector3.ZERO, 0.016, true)
	Assertions.assert_approx_equal(active_vel.length(), 3.0, 0.001, "Re-enabled movement must resume 3.0 m/s velocity")

	# --- Part C: Combined Gating (Full Freeze) ---
	player.movement_enabled = false
	player.look_enabled = false
	var freeze_pos := player.position
	var freeze_yaw := player.rotation.y
	var freeze_pitch := player.camera_pitch

	player.handle_mouse_look(Vector2(500.0, -300.0))
	player._physics_process(0.016)

	Assertions.assert_equal(player.position, freeze_pos, "Full freeze: position must not alter")
	Assertions.assert_equal(player.rotation.y, freeze_yaw, "Full freeze: yaw must not alter")
	Assertions.assert_equal(player.camera_pitch, freeze_pitch, "Full freeze: pitch must not alter")

	player.free()
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Test 3: Input gating flags freeze and resume verified.")
	else:
		printerr("    [FAIL] Test 3: Input gating flags failed.")
	return ok

func test_trauma_shake_decay_and_feel() -> bool:
	print("  [TEST 4] Camera Shake Trauma Decay and Game Feel Invariants")
	var initial_failures: int = Assertions.current_suite_failed

	var scene_res := ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player := scene_res.instantiate() as PlayerControllerClass
	player._ready()

	# 1. Trauma accumulation and clamping [0.0, 1.0]
	Assertions.assert_equal(player.trauma, 0.0, "Initial trauma must be 0.0")
	player.add_trauma(0.8)
	Assertions.assert_approx_equal(player.trauma, 0.8, 0.001, "Trauma must register 0.8")

	# Trauma saturation: adding 0.5 to 0.8 must clamp strictly to 1.0, not 1.3
	player.add_trauma(0.5)
	Assertions.assert_equal(player.trauma, 1.0, "Trauma must clamp strictly at maximum 1.0")

	# 2. Smooth quadratic decay over physics/process steps
	# Reset trauma to 0.8
	player.trauma = 0.8
	var prev_trauma: float = player.trauma
	var decay_rate: float = player.trauma_decay # default 1.5
	var dt: float = 1.0 / 60.0
	var steps_to_zero := int(ceil((0.8 / decay_rate) / dt)) + 5

	for s in range(steps_to_zero):
		player._process(dt)
		# Invariant A: trauma must never increase during decay
		Assertions.assert_true(player.trauma <= prev_trauma, "Trauma must monotonically decrease (s=%d, curr=%.4f, prev=%.4f)" % [s, player.trauma, prev_trauma])
		# Invariant B: trauma must never be negative
		Assertions.assert_true(player.trauma >= 0.0, "Trauma must never become negative (s=%d, curr=%.4f)" % [s, player.trauma])
		# Invariant C: no NaN or Inf
		Assertions.assert_false(is_nan(player.trauma), "Trauma must not be NaN")
		if player.camera:
			Assertions.assert_false(is_nan(player.camera.position.x), "Camera offset X must not be NaN")
			Assertions.assert_false(is_nan(player.camera.rotation.z), "Camera roll Z must not be NaN")
			# Invariant D: shake offset is bounded by max_shake_offset
			var shake_mag := player._shake_offset.length()
			var max_mag := player.max_shake_offset.length()
			Assertions.assert_true(shake_mag <= max_mag + 0.001, "Shake offset must stay within max bounds")
		prev_trauma = player.trauma

	# At rest: trauma == 0.0, camera restored to base position and zero roll
	Assertions.assert_equal(player.trauma, 0.0, "Trauma must reach exactly 0.0")
	Assertions.assert_equal(player._shake_offset, Vector3.ZERO, "_shake_offset must be Vector3.ZERO at rest")
	Assertions.assert_equal(player._shake_roll, 0.0, "_shake_roll must be 0.0 at rest")
	if player.camera:
		Assertions.assert_vector3_approx_equal(player.camera.position, player._camera_base_pos, 0.001, "Camera position must return to base pos")
		Assertions.assert_approx_equal(player.camera.rotation.z, 0.0, 0.001, "Camera rotation Z must return to 0.0")

	# 3. Extreme frame hitch decay test (e.g. 10.0s lag spike)
	player.add_trauma(0.9)
	player._process(10.0) # 10 second hitch
	Assertions.assert_equal(player.trauma, 0.0, "Trauma after large delta hitch must clamp cleanly to 0.0 without underflow")
	Assertions.assert_equal(player._shake_offset, Vector3.ZERO, "Shake offset after hitch must be ZERO")

	# 4. Negative trauma addition guard
	player.add_trauma(-0.5)
	Assertions.assert_equal(player.trauma, 0.0, "Negative trauma addition must clamp cleanly to 0.0")

	player.free()
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Test 4: Camera shake trauma decay and feel invariants verified.")
	else:
		printerr("    [FAIL] Test 4: Camera shake trauma decay failed.")
	return ok

func test_teleport_interpolation_and_reset() -> bool:
	print("  [TEST 5] Teleport Interpolation Reset and State Cleanliness")
	var initial_failures: int = Assertions.current_suite_failed

	var scene_res := ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player := scene_res.instantiate() as PlayerControllerClass
	player._ready()

	# Signal emission tracking
	var signal_emitted: Array[Vector3] = []
	player.recovered_to_safe_position.connect(func(pos: Vector3): signal_emitted.append(pos))

	# Dirty the player's full state
	player.position = Vector3(45.0, -12.0, 88.0)
	player.velocity = Vector3(25.0, -50.0, -18.0)
	player.rotation.y = deg_to_rad(120.0)
	player.apply_pitch_degrees(-45.0)
	player.add_trauma(0.95)
	player._process(0.016) # update shake offset and roll

	# Invariants before teleport: state is definitely dirty
	Assertions.assert_true(player.velocity.length() > 10.0, "Pre-condition: velocity is non-zero")
	Assertions.assert_true(player.trauma > 0.5, "Pre-condition: trauma is active")

	# Teleport to clean target
	var target_pos := Vector3(0.0, 0.0, 8.0)
	var target_yaw := deg_to_rad(180.0)
	player.teleport_to(target_pos, target_yaw)

	# Verify complete and atomic post-conditions
	Assertions.assert_equal(player.position, target_pos, "Position must match target_pos exactly")
	Assertions.assert_equal(player.velocity, Vector3.ZERO, "Velocity must be reset to Vector3.ZERO")
	Assertions.assert_approx_equal(player.rotation.y, target_yaw, 0.001, "Yaw rotation must match target_yaw")
	Assertions.assert_equal(player.camera_pitch, 0.0, "camera_pitch must be reset to 0.0")
	if player.head:
		Assertions.assert_equal(player.head.rotation.x, 0.0, "head.rotation.x must be reset to 0.0")
	Assertions.assert_equal(player.trauma, 0.0, "Trauma must be reset to 0.0")
	Assertions.assert_equal(player._shake_offset, Vector3.ZERO, "Shake offset must be reset to ZERO")
	Assertions.assert_equal(player._shake_roll, 0.0, "Shake roll must be reset to 0.0")
	Assertions.assert_equal(player._bob_offset, Vector3.ZERO, "Bob offset must be reset to ZERO")
	if player.camera:
		Assertions.assert_vector3_approx_equal(player.camera.position, player._camera_base_pos, 0.001, "Camera position must reset to base")
		Assertions.assert_equal(player.camera.rotation.z, 0.0, "Camera roll must reset to 0.0")

	# Verify signal emission
	Assertions.assert_equal(signal_emitted.size(), 1, "recovered_to_safe_position signal must be emitted once")
	if signal_emitted.size() > 0:
		Assertions.assert_equal(signal_emitted[0], target_pos, "Signal emitted parameter must match target_pos")

	player.free()
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Test 5: Teleport interpolation reset and state cleanliness verified.")
	else:
		printerr("    [FAIL] Test 5: Teleport interpolation reset failed.")
	return ok

func test_resolution_independence_motion() -> bool:
	print("  [TEST 6] Resolution Independence and Input Motion Routing")
	var initial_failures: int = Assertions.current_suite_failed

	var scene_res := ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player := scene_res.instantiate() as PlayerControllerClass
	player._ready()

	# Simulate InputEventMouseMotion with screen_relative populated
	# In Godot 4.7 with canvas_items stretch mode, screen_relative avoids viewport scaling distortion
	var motion_event := InputEventMouseMotion.new()
	motion_event.screen_relative = Vector2(50.0, -25.0)
	motion_event.relative = Vector2(100.0, -50.0) # different value to verify screen_relative takes precedence

	player.rotation.y = 0.0
	player.apply_pitch_degrees(0.0)

	player._unhandled_input(motion_event)

	# Expected yaw: -screen_relative.x * mouse_sensitivity
	var expected_yaw := -50.0 * player.mouse_sensitivity
	var expected_pitch_rad := clampf(25.0 * player.mouse_sensitivity, deg_to_rad(-85.0), deg_to_rad(85.0))

	Assertions.assert_approx_equal(player.rotation.y, expected_yaw, 0.0001, 
		"Mouse look must prioritize screen_relative (got %.6f, expected %.6f)" % [player.rotation.y, expected_yaw])
	Assertions.assert_approx_equal(player.camera_pitch, expected_pitch_rad, 0.0001, 
		"Camera pitch must prioritize screen_relative (got %.6f, expected %.6f)" % [player.camera_pitch, expected_pitch_rad])

	player.free()
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Test 6: Resolution independence motion routing verified.")
	else:
		printerr("    [FAIL] Test 6: Resolution independence motion routing failed.")
	return ok
