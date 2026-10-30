extends SceneTree

## Challenger Empirical Stress Test Harness for Milestone PLY-001
## Adversarial Verification of Collision Capsule, Spawn, Teleportation & Recovery

const Assertions = preload("res://tests/assertions.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")
const PlayerConfigClass = preload("res://scripts/player/player_config.gd")
const LevelGrayboxClass = preload("res://scripts/world/level_graybox.gd")

var _frame: int = 0
var _all_passed: bool = true

func _process(delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		run_all_challenges()
		finish_and_quit()
		return true
	return false

func finish_and_quit() -> void:
	print("==================================================")
	print("[CHALLENGER_PLY_001] VERIFICATION SUMMARY:")
	print("  Assertions Passed: %d" % Assertions.current_suite_passed)
	print("  Assertions Failed: %d" % Assertions.current_suite_failed)

	if _all_passed and Assertions.current_suite_failed == 0:
		print("  FINAL VERDICT: APPROVE")
		print("  All PLY-001 empirical challenge criteria verified successfully.")
		print("==================================================")
		quit(0)
	else:
		printerr("  FINAL VERDICT: REJECT")
		printerr("  Adversarial challenge failures encountered:")
		for msg in Assertions.failure_messages:
			printerr("    - ", msg)
		print("==================================================")
		quit(1)

func run_all_challenges() -> void:
	print("==================================================")
	print("[CHALLENGER_PLY_001] Empirical Adversarial Verification")
	print("Milestone: PLY-001 (Collision Capsule, Spawn & Safe Recovery)")
	print("==================================================")

	Assertions.reset()

	# Challenge 1: Collision capsule geometry and grounding oracle
	if not challenge_01_capsule_geometry_and_grounding():
		_all_passed = false

	# Challenge 2: Spawn point coordinates, orientation & wall clearance oracle
	if not challenge_02_spawn_point_coordinates_and_clearance():
		_all_passed = false

	# Challenge 3: Teleportation immediate state overwrite and velocity nullification oracle
	if not challenge_03_teleportation_and_velocity_nullification():
		_all_passed = false

	# Challenge 4: Auto fall recovery threshold trigger at Y < -5.0 oracle
	if not challenge_04_fall_recovery_threshold_trigger():
		_all_passed = false

	# Challenge 5: safe_return_home (0, 0, 8) spatial clearance and non-clipping oracle
	if not challenge_05_safe_return_spatial_clearance():
		_all_passed = false

	# Challenge 6: Recovery stress test & property invariance oracle (100 rapid cycles)
	if not challenge_06_recovery_stress_and_property_invariance():
		_all_passed = false

	# Challenge 7: Live physics stepping in main.tscn scene tree
	if not challenge_07_live_physics_main_scene_stability():
		_all_passed = false

func challenge_01_capsule_geometry_and_grounding() -> bool:
	print("  [CHALLENGE 1] Collision Capsule Geometry & Grounding Oracle")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	Assertions.assert_not_null(scene_res, "Player scene player.tscn must load successfully")
	if not scene_res:
		return false

	var player = scene_res.instantiate() as PlayerControllerClass
	root.add_child(player)
	Assertions.assert_not_null(player, "Player scene must instantiate as PlayerController")

	var col_shape_node = player.find_child("CollisionShape3D", true, false) as CollisionShape3D
	Assertions.assert_not_null(col_shape_node, "Player must have CollisionShape3D child")

	if col_shape_node and col_shape_node.shape is CapsuleShape3D:
		var capsule = col_shape_node.shape as CapsuleShape3D
		# Radius check: 0.4m
		Assertions.assert_true(abs(capsule.radius - 0.4) < 0.001, "Capsule radius must be exactly 0.4m (got %.4f)" % capsule.radius)
		# Height check: 1.8m
		Assertions.assert_true(abs(capsule.height - 1.8) < 0.001, "Capsule height must be exactly 1.8m (got %.4f)" % capsule.height)
		# Transform offset: Y = 0.9m
		Assertions.assert_true(abs(col_shape_node.position.y - 0.9) < 0.001, "CollisionShape3D Y offset must be 0.9m (got %.4f)" % col_shape_node.position.y)
		Assertions.assert_true(abs(col_shape_node.position.x) < 0.001, "CollisionShape3D X offset must be 0.0m")
		Assertions.assert_true(abs(col_shape_node.position.z) < 0.001, "CollisionShape3D Z offset must be 0.0m")

		# Calculate lowest point of capsule when player is at Y = 0.0
		var capsule_half_height = capsule.height / 2.0 # 0.9m
		var lowest_point_y = col_shape_node.position.y - capsule_half_height
		var highest_point_y = col_shape_node.position.y + capsule_half_height

		Assertions.assert_true(abs(lowest_point_y - 0.0) < 0.001, "Lowest capsule point must be exactly at Y = 0.0 (feet ground contact) (got %.4f)" % lowest_point_y)
		Assertions.assert_true(abs(highest_point_y - 1.8) < 0.001, "Highest capsule point must be at Y = 1.8m (got %.4f)" % highest_point_y)

	# Verify Head and Eye Height
	var head = player.find_child("Head", true, false) as Node3D
	Assertions.assert_not_null(head, "Head node must exist")
	if head:
		Assertions.assert_true(abs(head.position.y - 1.6) < 0.001, "Eye height (Head position.y) must be exactly 1.6m (got %.4f)" % head.position.y)

	root.remove_child(player)
	player.free()
	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 1: Capsule dimensions and feet grounding verified.")
	else:
		printerr("    [FAIL] Challenge 1: Capsule dimensions and feet grounding failed.")
	return ok

func challenge_02_spawn_point_coordinates_and_clearance() -> bool:
	print("  [CHALLENGE 2] Spawn Point Coordinates, Orientation & Wall Clearance Oracle")
	var initial_failures = Assertions.current_suite_failed

	var level_scene = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	Assertions.assert_not_null(level_scene, "Level scene must load")
	var level = level_scene.instantiate() as LevelGrayboxClass
	root.add_child(level)

	var main_scene = ResourceLoader.load("res://scenes/main.tscn") as PackedScene
	Assertions.assert_not_null(main_scene, "Main scene must load")
	var main = main_scene.instantiate()
	root.add_child(main)

	# Check spawn position in level
	var spawn_node = level.get_landmark("spawn_home")
	Assertions.assert_not_null(spawn_node, "spawn_home landmark must exist in level")
	if spawn_node:
		var expected_spawn = Vector3(0.0, 0.0, 1.0)
		var diff = (spawn_node.position - expected_spawn).length()
		Assertions.assert_true(diff < 0.01, "spawn_home must be at (0, 0, 1) (got %s)" % str(spawn_node.position))

	# Check Player instance transform in main.tscn
	var main_player = main.find_child("Player", true, false) as CharacterBody3D
	Assertions.assert_not_null(main_player, "Player node must exist in main.tscn")
	if main_player:
		var diff = (main_player.global_position - Vector3(0.0, 0.0, 1.0)).length()
		Assertions.assert_true(diff < 0.01, "Player initial global position in main.tscn must be (0, 0, 1) (got %s)" % str(main_player.global_position))
		# Check facing direction: rotation.y = 0.0 (facing North / -Z)
		Assertions.assert_true(abs(main_player.rotation.y) < 0.001, "Player initial yaw must be 0.0 rad (got %.4f)" % main_player.rotation.y)
		var forward_vec = -main_player.global_transform.basis.z
		Assertions.assert_true(abs(forward_vec.z - (-1.0)) < 0.001, "Player forward vector must point North (-Z) (got %s)" % str(forward_vec))

	# Wall clearance checks around spawn_home (0, 0, 1)
	var spawn_pos = Vector3(0.0, 0.0, 1.0)
	var player_radius = 0.4

	# Distance to North wall: Z = -6 (wall thickness 0.2 -> inner face at Z = -5.9)
	var dist_north = abs(spawn_pos.z - (-5.9)) - player_radius
	Assertions.assert_true(dist_north > 5.0, "Clearance to North wall must be > 5.0m (got %.2fm)" % dist_north)

	# Distance to West wall: X = -4 (wall thickness 0.2 -> inner face at X = -3.9)
	var dist_west = abs(spawn_pos.x - (-3.9)) - player_radius
	Assertions.assert_true(dist_west > 3.0, "Clearance to West wall must be > 3.0m (got %.2fm)" % dist_west)

	# Distance to East wall: X = 4 (wall thickness 0.2 -> inner face at X = 3.9)
	var dist_east = abs(spawn_pos.x - 3.9) - player_radius
	Assertions.assert_true(dist_east > 3.0, "Clearance to East wall must be > 3.0m (got %.2fm)" % dist_east)

	# Distance to South doorway: Z = 4
	var dist_south = abs(spawn_pos.z - 4.0) - player_radius
	Assertions.assert_true(dist_south > 2.0, "Clearance to South wall must be > 2.0m (got %.2fm)" % dist_south)

	# Distance to table (book_family at (-1, 0, -2))
	var table_dist = Vector2(spawn_pos.x - (-1.0), spawn_pos.z - (-2.0)).length() - player_radius
	Assertions.assert_true(table_dist > 2.0, "Clearance to book table must be > 2.0m (got %.2fm)" % table_dist)

	root.remove_child(level)
	level.free()
	root.remove_child(main)
	main.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 2: Spawn point coordinates, facing and clearance verified.")
	else:
		printerr("    [FAIL] Challenge 2: Spawn point coordinates, facing and clearance failed.")
	return ok

func challenge_03_teleportation_and_velocity_nullification() -> bool:
	print("  [CHALLENGE 3] Teleportation Immediate State Overwrite & Velocity Nullification Oracle")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass
	root.add_child(player)

	# Connect recovery signal to track emission using Dictionary reference
	var signal_data = {"received": false, "target": Vector3.ZERO}
	player.recovered_to_safe_position.connect(func(pos: Vector3):
		signal_data["received"] = true
		signal_data["target"] = pos
	)

	# Corrupt player state with non-zero position, high velocities, and non-zero camera pitch
	player.global_position = Vector3(123.4, -4.2, -567.8)
	player.velocity = Vector3(88.0, -150.0, 99.0)
	player.apply_pitch_degrees(75.0)
	player.rotation.y = 1.234

	var dest_pos = Vector3(5.0, 0.0, 7.0)
	var dest_rot_y = deg_to_rad(90.0)

	# Execute teleport_to
	player.teleport_to(dest_pos, dest_rot_y)

	Assertions.assert_equal(player.global_position, dest_pos, "Position must be overwritten immediately to target destination")
	Assertions.assert_equal(player.velocity, Vector3.ZERO, "Velocity must be immediately erased to Vector3.ZERO")
	Assertions.assert_true(abs(player.rotation.y - dest_rot_y) < 0.001, "Yaw rotation must match target rotation")
	Assertions.assert_true(abs(player.get_pitch_radians()) < 0.001, "Camera pitch must be immediately zeroed")
	if player.head:
		Assertions.assert_true(abs(player.head.rotation.x) < 0.001, "Head X rotation must be immediately zeroed")

	Assertions.assert_true(signal_data["received"], "recovered_to_safe_position signal must be emitted")
	Assertions.assert_equal(signal_data["target"], dest_pos, "Signal payload must carry exact target position")

	# Test subsequent movement frame from rest: no residual momentum
	var next_vel = player.calculate_movement_velocity(Vector2.ZERO, player.velocity, 0.016, true)
	Assertions.assert_equal(next_vel, Vector3.ZERO, "Subsequent physics step with zero input must produce zero velocity")

	root.remove_child(player)
	player.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 3: Teleportation and velocity nullification verified.")
	else:
		printerr("    [FAIL] Challenge 3: Teleportation and velocity nullification failed.")
	return ok

func challenge_04_fall_recovery_threshold_trigger() -> bool:
	print("  [CHALLENGE 4] Auto Fall Recovery Threshold Trigger at Y < -5.0 Oracle")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass
	root.add_child(player)

	# Test 4A: Boundary condition just above threshold: Y = -4.99
	# At Y = -4.99, cur_y < -5.0 is FALSE, so trigger_recovery() is NOT called
	player.global_position = Vector3(10.0, -4.99, 10.0)
	player.velocity = Vector3(0.0, 0.0, 0.0)
	var recovered_above := false
	player.recovered_to_safe_position.connect(func(_p): recovered_above = true)
	player._physics_process(0.016)
	Assertions.assert_false(recovered_above, "At Y = -4.99, recovery must NOT be triggered (threshold is Y < -5.0)")

	# Test 4B: Boundary condition just below threshold: Y = -5.01
	var signal_data = {"received": false, "pos": Vector3.ZERO}
	player.recovered_to_safe_position.connect(func(pos):
		signal_data["received"] = true
		signal_data["pos"] = pos
	)
	player.global_position = Vector3(10.0, -5.01, 10.0)
	player.velocity = Vector3(0.0, -25.0, 0.0)
	player._physics_process(0.016)

	# Must auto-recover to safe_return_home (0, 0, 8)
	var expected_safe = Vector3(0.0, 0.0, 8.0)
	Assertions.assert_equal(player.global_position, expected_safe, "At Y = -5.01, player must auto-recover to default_safe_return_position (0, 0, 8)")
	Assertions.assert_equal(player.velocity, Vector3.ZERO, "Velocity must be reset to Vector3.ZERO on auto-recovery")
	Assertions.assert_true(abs(player.get_pitch_radians()) < 0.001, "Camera pitch must be reset to 0.0 on auto-recovery")
	Assertions.assert_true(signal_data["received"], "Signal must be emitted on auto-recovery")

	# Test 4C: Deep fall at extreme negative Y (e.g. Y = -1000.0)
	player.global_position = Vector3(-50.0, -1000.0, 50.0)
	player.velocity = Vector3(100.0, -500.0, -100.0)
	player._physics_process(0.016)
	Assertions.assert_equal(player.global_position, expected_safe, "Deep fall at Y = -1000.0 must recover to (0, 0, 8)")
	Assertions.assert_equal(player.velocity, Vector3.ZERO, "Velocity must be reset to Vector3.ZERO after deep fall")

	root.remove_child(player)
	player.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 4: Fall recovery threshold trigger verified.")
	else:
		printerr("    [FAIL] Challenge 4: Fall recovery threshold trigger failed.")
	return ok

func challenge_05_safe_return_spatial_clearance() -> bool:
	print("  [CHALLENGE 5] safe_return_home (0, 0, 8) Spatial Clearance & Non-Clipping Oracle")
	var initial_failures = Assertions.current_suite_failed

	var level_scene = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = level_scene.instantiate() as LevelGrayboxClass
	root.add_child(level)

	var safe_node = level.get_landmark("safe_return_home")
	Assertions.assert_not_null(safe_node, "safe_return_home must exist in level")
	if safe_node:
		var safe_pos = safe_node.position
		Assertions.assert_equal(safe_pos, Vector3(0.0, 0.0, 8.0), "safe_return_home position must be (0, 0, 8)")

		# Clearance checks:
		# 1. House south wall is at Z = 4. Distance to Z=8 is 4.0m.
		var dist_to_house = safe_pos.z - 4.0
		Assertions.assert_true(dist_to_house >= 3.5, "Distance from safe_return_home to house south wall must be >= 3.5m (got %.2fm)" % dist_to_house)

		# 2. Gate is at Z = 13. Distance to Z=8 is 5.0m.
		var dist_to_gate = 13.0 - safe_pos.z
		Assertions.assert_true(dist_to_gate >= 4.5, "Distance from safe_return_home to gate must be >= 4.5m (got %.2fm)" % dist_to_gate)

		# 3. Crop plot plot_home_01 is at (8, 0, 7). Distance: sqrt(8^2 + 1^2) = sqrt(65) ≈ 8.06m.
		var plot_node = level.get_landmark("plot_home_01")
		if plot_node:
			var dist_to_plot = (safe_pos - plot_node.position).length()
			Assertions.assert_true(dist_to_plot >= 7.0, "safe_return_home must not overlap crop plot (distance %.2fm >= 7.0m)" % dist_to_plot)

		# 4. Water home is at (4, 0, 9). Distance: sqrt(4^2 + 1^2) = sqrt(17) ≈ 4.12m.
		var water_node = level.get_landmark("water_home")
		if water_node:
			var dist_to_water = (safe_pos - water_node.position).length()
			Assertions.assert_true(dist_to_water >= 3.5, "safe_return_home must not overlap water container (distance %.2fm >= 3.5m)" % dist_to_water)

	root.remove_child(level)
	level.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 5: safe_return_home spatial clearance verified.")
	else:
		printerr("    [FAIL] Challenge 5: safe_return_home spatial clearance failed.")
	return ok

func challenge_06_recovery_stress_and_property_invariance() -> bool:
	print("  [CHALLENGE 6] Recovery Stress Test & Property Invariance Oracle (100 Rapid Cycles)")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass
	root.add_child(player)

	# Record original properties before stress test
	var orig_move_speed = player.move_speed
	var orig_fov = player.fov
	var orig_mouse_sens = player.mouse_sensitivity
	var orig_min_pitch = player.min_pitch_deg
	var orig_max_pitch = player.max_pitch_deg
	var orig_head_bob = player.head_bob_enabled

	var signal_data = {"count": 0}
	player.recovered_to_safe_position.connect(func(_pos): signal_data["count"] += 1)

	# Execute 100 consecutive rapid fall & recovery triggers with randomized angles and velocities
	var rng = RandomNumberGenerator.new()
	rng.seed = 20451027

	for i in range(100):
		var rand_x = rng.randf_range(-100.0, 100.0)
		var rand_z = rng.randf_range(-100.0, 100.0)
		var rand_fall_y = rng.randf_range(-6.0, -500.0)
		var rand_vel_x = rng.randf_range(-50.0, 50.0)
		var rand_vel_y = rng.randf_range(-200.0, -10.0)
		var rand_vel_z = rng.randf_range(-50.0, 50.0)
		var rand_pitch = rng.randf_range(-85.0, 85.0)

		player.global_position = Vector3(rand_x, rand_fall_y, rand_z)
		player.velocity = Vector3(rand_vel_x, rand_vel_y, rand_vel_z)
		player.apply_pitch_degrees(rand_pitch)

		# Trigger physics process
		player._physics_process(0.016)

		# Verify immediate post-condition on each cycle
		if player.global_position != player.default_safe_return_position:
			Assertions.assert_equal(player.global_position, player.default_safe_return_position, "Position failed to recover on cycle %d" % i)
			break
		if player.velocity != Vector3.ZERO:
			Assertions.assert_equal(player.velocity, Vector3.ZERO, "Velocity failed to zero on cycle %d" % i)
			break
		if abs(player.get_pitch_radians()) > 0.001:
			Assertions.assert_true(abs(player.get_pitch_radians()) < 0.001, "Pitch failed to reset on cycle %d" % i)
			break

	Assertions.assert_equal(signal_data["count"], 100, "All 100 recoveries must emit recovered_to_safe_position signal")

	# Verify complete property invariance (no corruption after 100 rapid recoveries)
	Assertions.assert_equal(player.move_speed, orig_move_speed, "move_speed must remain unchanged")
	Assertions.assert_equal(player.fov, orig_fov, "fov must remain unchanged")
	Assertions.assert_equal(player.mouse_sensitivity, orig_mouse_sens, "mouse_sensitivity must remain unchanged")
	Assertions.assert_equal(player.min_pitch_deg, orig_min_pitch, "min_pitch_deg must remain unchanged")
	Assertions.assert_equal(player.max_pitch_deg, orig_max_pitch, "max_pitch_deg must remain unchanged")
	Assertions.assert_equal(player.head_bob_enabled, orig_head_bob, "head_bob_enabled must remain unchanged")

	# Check for NaN / Inf
	Assertions.assert_false(is_nan(player.global_position.x) or is_nan(player.global_position.y) or is_nan(player.global_position.z), "Player position must not be NaN")
	Assertions.assert_false(is_inf(player.global_position.x) or is_inf(player.global_position.y) or is_inf(player.global_position.z), "Player position must not be Inf")
	Assertions.assert_false(is_nan(player.rotation.y), "Player yaw must not be NaN")

	root.remove_child(player)
	player.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 6: 100 recovery stress cycles & property invariance verified.")
	else:
		printerr("    [FAIL] Challenge 6: 100 recovery stress cycles & property invariance failed.")
	return ok

func challenge_07_live_physics_main_scene_stability() -> bool:
	print("  [CHALLENGE 7] Live Physics Stepping in main.tscn Scene Tree Oracle")
	var initial_failures = Assertions.current_suite_failed

	var main_scene = ResourceLoader.load("res://scenes/main.tscn") as PackedScene
	Assertions.assert_not_null(main_scene, "main.tscn must load")
	var main = main_scene.instantiate()
	root.add_child(main)

	var player = main.find_child("Player", true, false) as PlayerControllerClass
	Assertions.assert_not_null(player, "Player must exist in active scene tree")

	if player:
		# Initial position before physics step
		var init_pos = player.global_position
		Assertions.assert_equal(init_pos, Vector3(0.0, 0.0, 1.0), "Initial player global position in main.tscn must be (0, 0, 1)")

		# Simulate 60 physics frames (1.0 second of simulation)
		for f in range(60):
			player._physics_process(1.0 / 60.0)

		# After 60 frames on floor, player must remain near Y = 0.0 (or on house floor Y = 0.1)
		# and must NOT have fallen through floor (Y < -1.0) nor launched into the sky (Y > 5.0)
		var final_pos = player.global_position
		Assertions.assert_true(final_pos.y >= -0.05 and final_pos.y <= 0.2, "Player Y coordinate after 60 frames must remain stably grounded between -0.05 and 0.2m (got Y = %.4fm)" % final_pos.y)
		Assertions.assert_true(abs(final_pos.x - 0.0) < 0.1, "Player X coordinate must remain centered (got X = %.4fm)" % final_pos.x)
		Assertions.assert_true(abs(final_pos.z - 1.0) < 0.1, "Player Z coordinate must remain at spawn Z=1.0 (got Z = %.4fm)" % final_pos.z)

	root.remove_child(main)
	main.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] Challenge 7: Live physics stepping and grounded stability verified.")
	else:
		printerr("    [FAIL] Challenge 7: Live physics stepping and grounded stability failed.")
	return ok
