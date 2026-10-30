class_name TestPlayer
extends RefCounted

const Assertions = preload("res://tests/assertions.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")
const PlayerConfigClass = preload("res://scripts/player/player_config.gd")

func run_all() -> bool:
	var passed := true
	print("  Running TestPlayer suite (T18, T25, T26)...")
	
	if not test_player_scene_loads():
		passed = false
	if not test_player_collision_shape():
		passed = false
	if not test_player_camera_eye_height():
		passed = false
	if not test_player_movement_velocity_math():
		passed = false
	if not test_player_pitch_clamp():
		passed = false
	if not test_framerate_independence():
		passed = false
	if not test_safe_recovery_and_teleport():
		passed = false
	if not test_player_mouse_mode_and_yaw():
		passed = false
	if not test_skills_slope_and_collision_layers():
		passed = false
	if not test_skills_input_gating_flags():
		passed = false
	if not test_skills_camera_shake_and_head_bob():
		passed = false

	return passed

func test_player_scene_loads() -> bool:
	print("    [RUN] T25.PLY1: Player Scene Loading and CharacterBody3D Hierarchy")
	var initial_failures = Assertions.current_suite_failed

	var scene_path = "res://scenes/player/player.tscn"
	Assertions.assert_true(FileAccess.file_exists(scene_path), "Player scene file must exist at " + scene_path)

	var scene_res = ResourceLoader.load(scene_path)
	Assertions.assert_not_null(scene_res, "ResourceLoader must load player.tscn")
	Assertions.assert_true(scene_res is PackedScene, "player.tscn must be a PackedScene")

	if scene_res is PackedScene:
		var player = scene_res.instantiate()
		Assertions.assert_not_null(player, "Player scene must instantiate")
		Assertions.assert_true(player is CharacterBody3D, "Root node must be CharacterBody3D")
		Assertions.assert_equal(player.name, "Player", "Root node name must be 'Player'")
		Assertions.assert_true(player is PlayerControllerClass, "Root script must be PlayerController")
		Assertions.assert_equal(player.move_speed, 3.0, "Default move_speed must be 3.0 m/s")
		Assertions.assert_false(player.head_bob_enabled, "head_bob_enabled must default to false")
		player.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T25.PLY1: Player scene loading passed.")
	else:
		printerr("    [FAIL] T25.PLY1: Player scene loading failed.")
	return ok

func test_player_collision_shape() -> bool:
	print("    [RUN] T25.PLY2: Player CollisionShape3D and Capsule Dimensions")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	var col_node = player.find_child("CollisionShape3D", true, false) as CollisionShape3D
	Assertions.assert_not_null(col_node, "Player must contain a CollisionShape3D")

	if col_node:
		var shape = col_node.shape
		Assertions.assert_not_null(shape, "CollisionShape3D must have a shape resource")
		Assertions.assert_true(shape is CapsuleShape3D, "Collision shape must be CapsuleShape3D")
		
		if shape is CapsuleShape3D:
			# Capsule radius ~0.4m, height ~1.8m
			var radius_diff = abs(shape.radius - 0.4)
			var height_diff = abs(shape.height - 1.8)
			Assertions.assert_true(radius_diff < 0.05, "Capsule radius must be ~0.4m (got %.3f)" % shape.radius)
			Assertions.assert_true(height_diff < 0.05, "Capsule height must be ~1.8m (got %.3f)" % shape.height)
			
			# Feet touch ground at Y = 0: position.y should be centered at height / 2 = 0.9m
			var center_y_diff = abs(col_node.position.y - 0.9)
			Assertions.assert_true(center_y_diff < 0.05, "CollisionShape3D position.y must be centered at ~0.9m for feet to touch Y=0 (got %.3f)" % col_node.position.y)

	player.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T25.PLY2: Player collision shape passed.")
	else:
		printerr("    [FAIL] T25.PLY2: Player collision shape failed.")
	return ok

func test_player_camera_eye_height() -> bool:
	print("    [RUN] T25.PLY3: Player Camera Pivot and Eye Height (1.6m)")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	var head = player.find_child("Head", true, false) as Node3D
	if head == null:
		head = player.find_child("CameraPivot", true, false) as Node3D
	Assertions.assert_not_null(head, "Head or CameraPivot node must exist")

	var cam = player.find_child("Camera3D", true, false) as Camera3D
	Assertions.assert_not_null(cam, "Camera3D must exist as a child of Head/CameraPivot")

	if head and cam:
		# Eye height relative to feet: head.position.y + cam.position.y
		var effective_eye_height = head.position.y + cam.position.y
		var diff = abs(effective_eye_height - 1.6)
		Assertions.assert_true(diff < 0.05, "Camera eye height must be 1.6m (+/- 0.05m, got %.3f)" % effective_eye_height)
		Assertions.assert_equal(cam.fov, 80.0, "Camera default FOV must be 80.0 degrees")

	player.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T25.PLY3: Player camera eye height passed.")
	else:
		printerr("    [FAIL] T25.PLY3: Player camera eye height failed.")
	return ok

func test_player_movement_velocity_math() -> bool:
	print("    [RUN] T26.PLY1: Movement Velocity Math (3.0 m/s, WASD Directions & Normalization)")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	# Test 1: Moving Forward (input_dir = (0, -1) -> towards -Z)
	var forward_vel = player.calculate_movement_velocity(Vector2(0.0, -1.0), Vector3.ZERO, 0.016, true)
	Assertions.assert_true(abs(forward_vel.x) < 0.001, "Forward movement X velocity must be 0")
	Assertions.assert_true(abs(forward_vel.z - (-3.0)) < 0.001, "Forward movement Z velocity must be -3.0 m/s (got %.3f)" % forward_vel.z)
	Assertions.assert_true(abs(forward_vel.length() - 3.0) < 0.001, "Forward movement total speed must be 3.0 m/s")

	# Test 2: Moving Backward (input_dir = (0, 1) -> towards +Z)
	var backward_vel = player.calculate_movement_velocity(Vector2(0.0, 1.0), Vector3.ZERO, 0.016, true)
	Assertions.assert_true(abs(backward_vel.x) < 0.001, "Backward movement X velocity must be 0")
	Assertions.assert_true(abs(backward_vel.z - 3.0) < 0.001, "Backward movement Z velocity must be +3.0 m/s (got %.3f)" % backward_vel.z)

	# Test 3: Moving Left (input_dir = (-1, 0) -> towards -X)
	var left_vel = player.calculate_movement_velocity(Vector2(-1.0, 0.0), Vector3.ZERO, 0.016, true)
	Assertions.assert_true(abs(left_vel.x - (-3.0)) < 0.001, "Left movement X velocity must be -3.0 m/s (got %.3f)" % left_vel.x)
	Assertions.assert_true(abs(left_vel.z) < 0.001, "Left movement Z velocity must be 0")

	# Test 4: Moving Right (input_dir = (1, 0) -> towards +X)
	var right_vel = player.calculate_movement_velocity(Vector2(1.0, 0.0), Vector3.ZERO, 0.016, true)
	Assertions.assert_true(abs(right_vel.x - 3.0) < 0.001, "Right movement X velocity must be +3.0 m/s (got %.3f)" % right_vel.x)
	Assertions.assert_true(abs(right_vel.z) < 0.001, "Right movement Z velocity must be 0")

	# Test 5: Diagonal Movement (forward + right, input_dir = (1, -1))
	# Must be normalized so speed does NOT exceed 3.0 m/s (no diagonal speed exploit)
	var diag_vel = player.calculate_movement_velocity(Vector2(1.0, -1.0).normalized(), Vector3.ZERO, 0.016, true)
	var diag_speed = Vector2(diag_vel.x, diag_vel.z).length()
	Assertions.assert_true(abs(diag_speed - 3.0) < 0.005, "Diagonal movement speed must stay exactly 3.0 m/s (got %.3f)" % diag_speed)

	# Test 6: Zero input produces zero horizontal velocity
	var zero_vel = player.calculate_movement_velocity(Vector2.ZERO, Vector3.ZERO, 0.016, true)
	Assertions.assert_true(abs(zero_vel.x) < 0.001 and abs(zero_vel.z) < 0.001, "Zero input must produce zero horizontal velocity")

	# Test 7: Gravity application when in air (on_floor = false)
	var air_vel = player.calculate_movement_velocity(Vector2.ZERO, Vector3(0.0, 0.0, 0.0), 0.1, false)
	Assertions.assert_true(air_vel.y < 0.0, "Gravity must pull downward when not on floor (got Y=%.3f)" % air_vel.y)

	player.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T26.PLY1: Movement velocity math passed.")
	else:
		printerr("    [FAIL] T26.PLY1: Movement velocity math failed.")
	return ok

func test_player_pitch_clamp() -> bool:
	print("    [RUN] T25.PLY4: Mouse Look Vertical Pitch Clamp ([-85.0°, +85.0°])")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	# Test extreme upward pitch (e.g. +90°, +120°, +180°)
	player.apply_pitch_degrees(120.0)
	var clamped_up = player.get_pitch_degrees()
	Assertions.assert_true(abs(clamped_up - 85.0) < 0.01, "Upward pitch exceeding 85° must clamp to +85° (got %.2f°)" % clamped_up)

	# Test extreme downward pitch (e.g. -90°, -120°, -180°)
	player.apply_pitch_degrees(-150.0)
	var clamped_down = player.get_pitch_degrees()
	Assertions.assert_true(abs(clamped_down - (-85.0)) < 0.01, "Downward pitch exceeding -85° must clamp to -85° (got %.2f°)" % clamped_down)

	# Test simulated mouse delta look accumulation
	player.apply_pitch_degrees(0.0)
	# Push mouse upwards heavily: relative.y = -100000.0 (in standard FPS, moving mouse up has negative Y delta)
	player.handle_mouse_look(Vector2(0.0, -100000.0))
	var mouse_up_clamped = player.get_pitch_degrees()
	Assertions.assert_true(mouse_up_clamped <= 85.0 + 0.001, "Simulated large upward mouse look must not exceed 85° (got %.2f°)" % mouse_up_clamped)

	# Push mouse downwards heavily: relative.y = +100000.0
	player.handle_mouse_look(Vector2(0.0, 100000.0))
	var mouse_down_clamped = player.get_pitch_degrees()
	Assertions.assert_true(mouse_down_clamped >= -85.0 - 0.001, "Simulated large downward mouse look must not go below -85° (got %.2f°)" % mouse_down_clamped)

	player.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T25.PLY4: Pitch clamp verification passed.")
	else:
		printerr("    [FAIL] T25.PLY4: Pitch clamp verification failed.")
	return ok

func test_framerate_independence() -> bool:
	print("    [RUN] T26.PLY2: Framerate Independence (30 FPS vs 60 FPS vs 120 FPS)")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	var test_framerates = [30, 60, 120]
	var distances: Array[float] = []

	for fps in test_framerates:
		var delta: float = 1.0 / float(fps)
		var total_distance: float = 0.0
		
		# Simulate 1.0 full second of movement forward
		for frame in range(fps):
			var vel = player.calculate_movement_velocity(Vector2(0.0, -1.0), Vector3.ZERO, delta, true)
			var step_dist = vel.length() * delta
			total_distance += step_dist
		
		distances.append(total_distance)
		print("      FPS: %d | Total Distance in 1.0s: %.4f m" % [fps, total_distance])

	# Each simulation over 1.0s at speed 3.0 m/s must yield exactly 3.0m
	for i in range(distances.size()):
		var diff = abs(distances[i] - 3.0)
		Assertions.assert_true(diff < 0.001, "Distance at %d FPS must be 3.0m within 0.001m (got %.4fm)" % [test_framerates[i], distances[i]])

	# Difference between 30 FPS and 120 FPS must be negligible
	var max_discrepancy = abs(distances[0] - distances[2])
	Assertions.assert_true(max_discrepancy < 0.0001, "Max discrepancy between framerates must be < 0.0001m (got %.6fm)" % max_discrepancy)

	player.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T26.PLY2: Framerate independence verified.")
	else:
		printerr("    [FAIL] T26.PLY2: Framerate independence failed.")
	return ok

func test_safe_recovery_and_teleport() -> bool:
	print("    [RUN] T25.PLY5: Safe Recovery, Teleportation & Velocity Nullification")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	# 1. Teleportation to arbitrary target
	var dest = Vector3(15.0, 0.0, -12.0)
	var rot_target = deg_to_rad(45.0)
	player.velocity = Vector3(5.0, -2.0, 3.0)
	player.teleport_to(dest, rot_target)

	Assertions.assert_equal(player.position, dest, "Player position must match teleport destination")
	Assertions.assert_equal(player.velocity, Vector3.ZERO, "Player velocity must be reset to Vector3.ZERO on teleport")
	Assertions.assert_true(abs(player.rotation.y - rot_target) < 0.001, "Player facing Y must align with target rotation")
	Assertions.assert_true(abs(player.get_pitch_radians()) < 0.001, "Player pitch must reset to 0.0 on teleport")

	# 2. Recovery trigger below threshold (Y < -5.0)
	player.position = Vector3(0.0, -8.0, 0.0)
	player.velocity = Vector3(0.0, -20.0, 0.0)
	player.trigger_recovery()

	var safe_pos = player.default_safe_return_position
	Assertions.assert_equal(player.position, safe_pos, "Player must recover to default_safe_return_position (0, 0, 8)")
	Assertions.assert_equal(player.velocity, Vector3.ZERO, "Player velocity must be reset to Vector3.ZERO after recovery")

	player.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T25.PLY5: Safe recovery and teleportation verified.")
	else:
		printerr("    [FAIL] T25.PLY5: Safe recovery and teleportation failed.")
	return ok

func test_player_mouse_mode_and_yaw() -> bool:
	print("    [RUN] T18.PLY1: Mouse Mode State and Horizontal Yaw Controls")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player = scene_res.instantiate() as PlayerControllerClass

	# 1. Yaw rotation verification
	player.rotation.y = 0.0
	# Relative mouse motion to the right (+X = 100 pixels) rotates player clockwise (-Y)
	player.handle_mouse_look(Vector2(100.0, 0.0))
	var expected_yaw_change = -100.0 * player.mouse_sensitivity
	Assertions.assert_true(abs(player.rotation.y - expected_yaw_change) < 0.001, "Horizontal mouse look must update player yaw")

	# 2. Pitch shouldn't change from horizontal mouse movement
	Assertions.assert_true(abs(player.get_pitch_degrees()) < 0.001, "Horizontal mouse motion must not change pitch")

	# 3. Mouse capture & release API methods
	player.release_mouse()
	Assertions.assert_false(player.is_mouse_captured(), "release_mouse() must make is_mouse_captured() false")
	
	player.capture_mouse()
	Assertions.assert_true(player.is_mouse_captured(), "capture_mouse() must make is_mouse_captured() true")
	
	player.release_mouse()

	player.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T18.PLY1: Mouse mode and yaw passed.")
	else:
		printerr("    [FAIL] T18.PLY1: Mouse mode and yaw failed.")
	return ok

func test_skills_slope_and_collision_layers() -> bool:
	print("    [RUN] T25.SKL1: Player Slope Snapping & Physics Collision Layers")
	var initial_failures: int = Assertions.current_suite_failed

	var scene_res := ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player := scene_res.instantiate() as PlayerControllerClass
	player._ready()

	# 1. Slope & floor snapping configuration
	Assertions.assert_true(player.floor_constant_speed, "floor_constant_speed must be true")
	Assertions.assert_approx_equal(player.floor_snap_length, 0.2, 0.01, "floor_snap_length must be 0.2m")
	Assertions.assert_true(player.floor_stop_on_slope, "floor_stop_on_slope must be true")

	# 2. Physics 3D collision layers
	Assertions.assert_equal(player.collision_layer, 2, "collision_layer must be 2 (player)")
	Assertions.assert_equal(player.collision_mask, 13, "collision_mask must be 13 (environment | interactables | triggers)")

	player.free()

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T25.SKL1: Slope snapping & collision layers verified.")
	else:
		printerr("    [FAIL] T25.SKL1: Slope snapping & collision layers failed.")
	return ok

func test_skills_input_gating_flags() -> bool:
	print("    [RUN] T25.SKL2: Input Gating Flags (movement_enabled & look_enabled)")
	var initial_failures: int = Assertions.current_suite_failed

	var scene_res := ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player := scene_res.instantiate() as PlayerControllerClass
	player._ready()

	# Test look gating
	player.look_enabled = false
	var initial_yaw := player.rotation.y
	var initial_pitch := player.camera_pitch
	player.handle_mouse_look(Vector2(50.0, 50.0))
	Assertions.assert_equal(player.rotation.y, initial_yaw, "Disabled look must ignore yaw input")
	Assertions.assert_equal(player.camera_pitch, initial_pitch, "Disabled look must ignore pitch input")

	player.look_enabled = true
	player.handle_mouse_look(Vector2(50.0, 0.0))
	Assertions.assert_ne(player.rotation.y, initial_yaw, "Enabled look must process mouse motion")

	# Test movement gating
	player.movement_enabled = false
	player._physics_process(0.016)
	Assertions.assert_equal(player.velocity.x, 0.0, "Disabled movement must produce zero X velocity")
	Assertions.assert_equal(player.velocity.z, 0.0, "Disabled movement must produce zero Z velocity")

	player.free()

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T25.SKL2: Input gating flags verified.")
	else:
		printerr("    [FAIL] T25.SKL2: Input gating flags failed.")
	return ok

func test_skills_camera_shake_and_head_bob() -> bool:
	print("    [RUN] T25.SKL3: Trauma Camera Shake Hook & Head Bob Stability")
	var initial_failures: int = Assertions.current_suite_failed

	var scene_res := ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	var player := scene_res.instantiate() as PlayerControllerClass
	player._ready()

	# 1. Trauma addition and decay
	Assertions.assert_equal(player.trauma, 0.0, "Initial trauma must be 0.0")
	player.add_trauma(0.8)
	Assertions.assert_approx_equal(player.trauma, 0.8, 0.001, "Trauma must clamp and register to 0.8")

	# Process 0.1s -> trauma should decay by 1.5 * 0.1 = 0.15 -> 0.65
	player._process(0.1)
	Assertions.assert_approx_equal(player.trauma, 0.65, 0.02, "Trauma must decay quadratically over time")
	Assertions.assert_not_null(player.camera, "Camera must exist for shake verification")

	# 2. Teleportation must reset trauma to zero
	player.teleport_to(Vector3(0, 0, 8))
	Assertions.assert_equal(player.trauma, 0.0, "teleport_to must reset camera trauma to 0.0")
	if player.camera:
		Assertions.assert_vector3_approx_equal(player.camera.position, Vector3.ZERO, 0.001, "Camera offset must reset to ZERO on teleport")
		Assertions.assert_approx_equal(player.camera.rotation.z, 0.0, 0.001, "Camera roll must reset to 0.0 on teleport")

	# 3. Head bob disabled by default: eye height remains strictly 1.6m
	Assertions.assert_false(player.head_bob_enabled, "head_bob_enabled must be false by default")
	if player.head:
		Assertions.assert_approx_equal(player.head.position.y, 1.6, 0.01, "Resting eye height must remain strictly 1.6m")

	player.free()

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T25.SKL3: Trauma camera shake & head bob verified.")
	else:
		printerr("    [FAIL] T25.SKL3: Trauma camera shake & head bob failed.")
	return ok
