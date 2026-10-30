extends SceneTree

# ==============================================================================
# EMPIRICAL CHALLENGE HARNESS: REBUILD-001 (LVL-001 Level Graybox & Environment)
# Agent: challenger_rebuild_001_1
# ==============================================================================

const LevelGrayboxClass = preload("res://scripts/world/level_graybox.gd")

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var failure_details: Array[String] = []

func _init() -> void:
	print("======================================================================")
	print("[EMPIRICAL_CHALLENGER] Starting REBUILD-001 Stress Harness...")
	print("======================================================================")
	call_deferred("_execute_harness")

func assert_true(condition: bool, msg: String) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
	else:
		failed_assertions += 1
		var err_msg = "FAILED: %s" % msg
		failure_details.append(err_msg)
		printerr("  [ASSERT_FAIL] ", err_msg)

func assert_false(condition: bool, msg: String) -> void:
	assert_true(not condition, msg)

func assert_eq(a, b, msg: String) -> void:
	assert_true(a == b, "%s (expected %s, got %s)" % [msg, str(b), str(a)])

func assert_approx_eq_vector3(a: Vector3, b: Vector3, tolerance: float, msg: String) -> void:
	var diff = a.distance_to(b)
	assert_true(diff <= tolerance, "%s (expected %s, got %s, diff=%.6f, tol=%.6f)" % [msg, str(b), str(a), diff, tolerance])

func _execute_harness() -> void:
	var success := await run_all_challenges()
	print("======================================================================")
	print("[EMPIRICAL_CHALLENGER] SUMMARY:")
	print("  Total Assertions:  ", total_assertions)
	print("  Passed Assertions: ", passed_assertions)
	print("  Failed Assertions: ", failed_assertions)
	if success and failed_assertions == 0:
		print("  VERDICT: CONFIRMED CORRECT (Exit Code: 0)")
		print("======================================================================")
		quit(0)
	else:
		printerr("  VERDICT: ISSUE DETECTED (Exit Code: 1)")
		for detail in failure_details:
			printerr("    - ", detail)
		print("======================================================================")
		quit(1)

func run_all_challenges() -> bool:
	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	assert_true(scene_res != null, "Scene resource 'res://scenes/world/level_graybox.tscn' must load")
	if scene_res == null:
		return false

	var level = scene_res.instantiate() as Node3D
	assert_true(level != null, "level_graybox.tscn must instantiate as Node3D")
	if level == null:
		return false

	root.add_child(level)

	# Allow 3 physics frames for physics space setup
	for i in range(3):
		await process_frame

	var world_3d = level.get_world_3d()
	assert_true(world_3d != null, "World3D must be valid")
	var space_state = world_3d.direct_space_state
	assert_true(space_state != null, "PhysicsDirectSpaceState3D must be valid")

	# --- TEST 1: Collision Layer & Mask Filtering ---
	print("\n>>> CHALLENGE 1: Collision Layer Filtering & Segregation")
	challenge_collision_layer_filtering(level, space_state)

	# --- TEST 2: Fall Recovery Boundary & Volume Stress ---
	print("\n>>> CHALLENGE 2: Fall Recovery 200x200m Area & Sub-Y Boundary Test")
	challenge_fall_recovery_boundary(level, space_state)

	# --- TEST 3: Landmark Integrity & Exact Tolerances ---
	print("\n>>> CHALLENGE 3: 18 Landmarks & Crop Plot Integrity Check")
	challenge_landmark_integrity(level)

	# --- TEST 4: Doorway Traversal & Snagging Clearance ---
	print("\n>>> CHALLENGE 4: House Doorway (1.6m) Z-Traversal & Physical Simulation")
	await challenge_doorway_clearance(level, space_state)

	root.remove_child(level)
	level.free()

	return failed_assertions == 0

# ==============================================================================
# CHALLENGE 1: Collision Layer Filtering
# ==============================================================================
func challenge_collision_layer_filtering(level: Node3D, space_state: PhysicsDirectSpaceState3D) -> void:
	# 1. Find all StaticBody3D in the entire level hierarchy
	var static_bodies: Array[StaticBody3D] = []
	_collect_nodes_of_type(level, "StaticBody3D", static_bodies)
	print("  Found %d StaticBody3D instances in level." % static_bodies.size())
	assert_true(static_bodies.size() >= 15, "Level must contain all primary static bodies")

	for sb in static_bodies:
		assert_eq(sb.collision_layer, 1, "StaticBody3D '%s' must have collision_layer == 1 (environment)" % sb.name)
		assert_eq(sb.get_collision_layer_value(1), true, "StaticBody3D '%s' must have layer 1 enabled" % sb.name)
		assert_eq(sb.get_collision_layer_value(2), false, "StaticBody3D '%s' must NOT have layer 2 enabled" % sb.name)
		assert_eq(sb.get_collision_layer_value(3), false, "StaticBody3D '%s' must NOT have layer 3 enabled" % sb.name)
		assert_eq(sb.get_collision_layer_value(4), false, "StaticBody3D '%s' must NOT have layer 4 enabled" % sb.name)

	# 2. Check FallRecoveryArea
	var fall_area: Area3D = level.find_child("FallRecoveryArea", true, false) as Area3D
	assert_true(fall_area != null, "FallRecoveryArea must exist")
	if fall_area:
		assert_eq(fall_area.collision_layer, 8, "FallRecoveryArea collision_layer must be 8 (Layer 4: triggers)")
		assert_eq(fall_area.collision_mask, 2, "FallRecoveryArea collision_mask must be 2 (Layer 2: player)")
		assert_eq(fall_area.get_collision_layer_value(4), true, "FallRecoveryArea layer 4 must be true")
		assert_eq(fall_area.get_collision_layer_value(1), false, "FallRecoveryArea layer 1 must be false")
		assert_eq(fall_area.get_collision_mask_value(2), true, "FallRecoveryArea mask 2 must be true")
		assert_eq(fall_area.get_collision_mask_value(1), false, "FallRecoveryArea mask 1 must be false")
		assert_eq(fall_area.get_collision_mask_value(3), false, "FallRecoveryArea mask 3 must be false")
		assert_true(fall_area.monitoring, "FallRecoveryArea must have monitoring = true")

	# 3. Layer Separation Physics Test:
	# Verify that an entity on Layer 1 does NOT trigger FallRecoveryArea mask
	var env_probe = CharacterBody3D.new()
	env_probe.name = "EnvProbe"
	env_probe.collision_layer = 1 # layer 1: environment
	env_probe.position = Vector3(0, -6.0, 5)
	level.add_child(env_probe)

	# Verify with query: layer 1 probe vs fall_area (mask 2)
	var q_env = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.5
	q_env.shape = sphere
	q_env.transform = Transform3D(Basis.IDENTITY, Vector3(0, -6.0, 5))
	q_env.collision_mask = 1 # mask 1: scanning environment
	q_env.collide_with_areas = true
	var hits_env = space_state.intersect_shape(q_env, 10)
	var hit_fall_on_layer1 := false
	for h in hits_env:
		if h.collider == fall_area:
			hit_fall_on_layer1 = true
	assert_false(hit_fall_on_layer1, "FallRecoveryArea (layer 4) must NOT be hit when querying layer 1")

	# Now query with mask = 8 (layer 4 triggers) -> should detect fall_area
	var q_trig = PhysicsShapeQueryParameters3D.new()
	q_trig.shape = sphere
	q_trig.transform = Transform3D(Basis.IDENTITY, Vector3(0, -6.0, 5))
	q_trig.collision_mask = 8 # mask 8: triggers
	q_trig.collide_with_areas = true
	var hits_trig = space_state.intersect_shape(q_trig, 10)
	var hit_fall_on_trig := false
	for h in hits_trig:
		if h.collider == fall_area:
			hit_fall_on_trig = true
	assert_true(hit_fall_on_trig, "FallRecoveryArea (layer 4) MUST be hit when querying layer 4 (bitmask 8)")

	env_probe.free()

# ==============================================================================
# CHALLENGE 2: Fall Recovery 200x200m Area & Sub-Y Boundary Test
# ==============================================================================
func challenge_fall_recovery_boundary(level: Node3D, space_state: PhysicsDirectSpaceState3D) -> void:
	var safe_pos = level.get_safe_return_position()
	assert_approx_eq_vector3(safe_pos, Vector3(0, 0, 8), 0.001, "safe_return_home must be at (0, 0, 8)")

	var fall_area: Area3D = level.find_child("FallRecoveryArea", true, false) as Area3D
	assert_true(fall_area != null, "FallRecoveryArea must exist")
	var col_shape: CollisionShape3D = fall_area.find_child("FallAreaCollision", true, false) as CollisionShape3D
	assert_true(col_shape != null, "FallAreaCollision must exist")
	var box = col_shape.shape as BoxShape3D
	assert_true(box != null, "FallAreaCollision shape must be BoxShape3D")
	assert_eq(box.size, Vector3(200.0, 2.0, 200.0), "Fall recovery volume must be exactly 200x2x200m")

	# Test 4 extreme boundary corners of the 200x200m recovery area
	# Center is (0, -6.0, 5), so X range [-100, 100], Z range [-95, 105], Y range [-7.0, -5.0]
	var corners = [
		Vector3(-98.0, -6.0, -93.0), # NW
		Vector3(98.0, -6.0, -93.0),  # NE
		Vector3(-98.0, -6.0, 103.0), # SW
		Vector3(98.0, -6.0, 103.0),  # SE
	]

	var sphere = SphereShape3D.new()
	sphere.radius = 0.5
	var q = PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.collision_mask = 8 # triggers
	q.collide_with_areas = true

	for c in corners:
		q.transform = Transform3D(Basis.IDENTITY, c)
		var hits = space_state.intersect_shape(q, 5)
		var hit_area := false
		for h in hits:
			if h.collider == fall_area:
				hit_area = true
		assert_true(hit_area, "FallRecoveryArea must physically cover corner %s" % str(c))

	# Test 50 pseudo-random positions below Y = -6.0 across the 200x200m area
	var dummy = CharacterBody3D.new()
	dummy.name = "StressFallDummy"
	level.add_child(dummy)

	var rng = RandomNumberGenerator.new()
	rng.seed = 20451027 # Deterministic reproducible seed

	var sampled_points := 0
	for i in range(50):
		var rand_x = rng.randf_range(-95.0, 95.0)
		var rand_z = rng.randf_range(-90.0, 100.0)
		var rand_y = rng.randf_range(-6.01, -25.0) # all below -6.0
		var test_pos = Vector3(rand_x, rand_y, rand_z)

		dummy.position = test_pos
		dummy.velocity = Vector3(rng.randf_range(-5.0, 5.0), rng.randf_range(-30.0, -5.0), rng.randf_range(-5.0, 5.0))

		var recovered = level.check_and_recover_entity(dummy)
		assert_true(recovered, "check_and_recover_entity must return true for position %s" % str(test_pos))
		assert_approx_eq_vector3(dummy.position, safe_pos, 0.001, "Dummy must be teleported to safe_return_home from %s" % str(test_pos))
		assert_eq(dummy.velocity, Vector3.ZERO, "Dummy velocity must be zeroed from %s" % str(test_pos))
		sampled_points += 1

	print("  Successfully stress-tested %d random positions below Y=-6.0 across 200x200m envelope." % sampled_points)

	# Invariance check: Position inside playable area (e.g. Y = 1.0) must NOT trigger recovery
	dummy.position = Vector3(0.0, 0.5, 5.0)
	dummy.velocity = Vector3(1.0, 0.0, 0.0)
	var false_recovery = level.check_and_recover_entity(dummy)
	assert_false(false_recovery, "Entity at valid playable position must NOT trigger recovery")
	assert_eq(dummy.position, Vector3(0.0, 0.5, 5.0), "Valid entity position must NOT be mutated")

	dummy.free()

# ==============================================================================
# CHALLENGE 3: 18 Landmarks Integrity Check
# ==============================================================================
func challenge_landmark_integrity(level: Node3D) -> void:
	var expected_landmarks: Dictionary = {
		"zone_home": Vector3(0, 0, -1),
		"spawn_home": Vector3(0, 0, 1),
		"book_family": Vector3(-1, 0, -2),
		"station_kitchen_home": Vector3(2, 0, -4),
		"storage_home": Vector3(-2, 0, -4),
		"bed_home": Vector3(-2, 0, 0),
		"zone_yard": Vector3(5, 0, 7),
		"plot_home_01": Vector3(8, 0, 7),
		"water_home": Vector3(4, 0, 9),
		"container_starter": Vector3(6, 0, 4),
		"reserve_home": Vector3(7, 0, 4),
		"gate_home": Vector3(0, 0, 13),
		"junction_path": Vector3(0, 0, 21),
		"resource_jagung_01": Vector3(22, 0, 28),
		"note_garden_01": Vector3(19, 0, 27),
		"resource_temu_kunci_01": Vector3(-20, 0, 30),
		"npc_neighbor_01": Vector3(-14, 0, 15),
		"safe_return_home": Vector3(0, 0, 8),
	}

	assert_eq(level.LANDMARK_IDS.size(), 18, "level.LANDMARK_IDS must have exactly 18 entries")

	for lid in expected_landmarks.keys():
		var expected_pos: Vector3 = expected_landmarks[lid]
		var node = level.get_landmark(lid)
		assert_true(node != null, "Landmark '%s' must exist and be accessible" % lid)
		if node != null:
			var actual_pos = node.global_position if node.is_inside_tree() else node.position
			assert_approx_eq_vector3(actual_pos, expected_pos, 0.001, "Landmark '%s' position exact match" % lid)

	# Crop plot quadrant spots
	var spots = level.get_crop_spots()
	assert_eq(spots.size(), 4, "Crop plot must return exactly 4 spots")
	var expected_spot_globals = [
		Vector3(7.5, 0.1, 6.5), # spot_0: NW
		Vector3(8.5, 0.1, 6.5), # spot_1: NE
		Vector3(7.5, 0.1, 7.5), # spot_2: SW
		Vector3(8.5, 0.1, 7.5), # spot_3: SE
	]
	for i in range(mini(spots.size(), 4)):
		var s = spots[i]
		var g_pos = s.global_position
		assert_approx_eq_vector3(g_pos, expected_spot_globals[i], 0.005, "Crop spot_%d global position" % i)

	print("  All 18 landmarks and 4 crop spots verified at exact coordinates within tolerance.")

# ==============================================================================
# CHALLENGE 4: Doorway Clearance (1.6m width Z traversal without snagging)
# ==============================================================================
func challenge_doorway_clearance(level: Node3D, space_state: PhysicsDirectSpaceState3D) -> void:
	# House South wall is at Z = 4.0.
	# Doorway opening spans X = -0.8 to +0.8 (width 1.6m), Y = 0.0 to 2.2m.
	# Standard player capsule: radius 0.4m, height 1.8m (cylinder center at Y = 0.9m).

	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8

	# Part A: Multi-lane geometric shape sweep through doorway from Z = 1.0 (indoor) to Z = 7.0 (yard)
	# Lateral lanes: X = 0.0 (center), X = -0.3 (left), X = +0.3 (right), X = -0.35 (near left margin), X = +0.35 (near right margin)
	var lanes = [0.0, -0.3, 0.3, -0.35, 0.35]
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1 # layer 1 environment
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var total_doorway_checks := 0
	for lane_x in lanes:
		var z_steps = 60 # step by 0.1m
		for step in range(z_steps + 1):
			var z = lerp(1.0, 7.0, float(step) / float(z_steps))
			var check_pos = Vector3(lane_x, 0.9, z)
			query.transform = Transform3D(Basis.IDENTITY, check_pos)
			var hits = space_state.intersect_shape(query, 10)

			var snagged_colliders: Array[String] = []
			for hit in hits:
				var cname = hit.collider.name
				# Ground and HouseFloor are floor beneath feet, not doorway snags
				if cname != "Ground" and cname != "HouseFloor":
					snagged_colliders.append(cname)

			assert_true(snagged_colliders.is_empty(), "Doorway sweep at (%f, 0.9, %f) must not snag: %s" % [lane_x, z, str(snagged_colliders)])
			total_doorway_checks += 1

	print("  Geometric sweep: %d shape tests across 5 lateral lanes passed with ZERO doorway collisions." % total_doorway_checks)

	# Part B: Physical dynamic simulation with real Player scene
	var player_scene = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	assert_true(player_scene != null, "Player scene must load")
	if player_scene == null:
		return

	var player = player_scene.instantiate() as CharacterBody3D
	assert_true(player != null, "Player must instantiate as CharacterBody3D")
	if player == null:
		return

	level.add_child(player)

	# Wait for physics ready
	await process_frame
	await process_frame

	# Simulation 1: Forward walk from inside house (0, 0.1, 1.0) through doorway (Z=4) out to yard
	player.global_position = Vector3(0, 0.1, 1.0)
	player.velocity = Vector3.ZERO
	if player.has_method("reset_physics_interpolation"):
		player.reset_physics_interpolation()

	# Simulate 120 physics frames with forward movement (3.0 m/s * 2.0s = 6.0m forward -> should reach Z=7.0)
	var sim_frames = 120
	for f in range(sim_frames):
		await physics_frame
		player.velocity = Vector3(0, 0, 3.0) # Moving in +Z towards south yard
		player.move_and_slide()
		# Check for abnormal lateral deflections
		assert_true(abs(player.global_position.x) < 0.2, "Player should not be pushed laterally while walking through doorway")

	print("  Dynamic forward simulation result position: %s" % str(player.global_position))
	assert_true(player.global_position.z >= 6.8, "Player must successfully walk completely through doorway into yard (Z >= 6.8, actual: %.2f)" % player.global_position.z)

	# Simulation 2: Reverse walk from yard (0, 0.0, 7.0) through doorway (Z=4) into house (Z=1.0)
	player.global_position = Vector3(0, 0.0, 7.0)
	player.velocity = Vector3.ZERO
	if player.has_method("reset_physics_interpolation"):
		player.reset_physics_interpolation()

	for f in range(sim_frames):
		await physics_frame
		player.velocity = Vector3(0, 0, -3.0) # Moving in -Z towards indoor
		player.move_and_slide()
		assert_true(abs(player.global_position.x) < 0.2, "Player should not be deflected while entering doorway")

	print("  Dynamic reverse simulation result position: %s" % str(player.global_position))
	assert_true(player.global_position.z <= 1.2, "Player must successfully walk backward through doorway into house (Z <= 1.2, actual: %.2f)" % player.global_position.z)

	# Simulation 3: Jump clearance under lintel
	# Lintel is at Z = 4.0, Y from 2.2 to 3.0. Player eye is at 1.6, top of head is at 1.8.
	# At Y = 0.35 (simulating jump apex), player top of head is at 0.35 + 1.8 = 2.15m (below lintel 2.2m).
	query.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.9 + 0.3, 4.0)) # bottom at 0.3, top at 2.1
	var jump_hits = space_state.intersect_shape(query, 5)
	var lintel_hit := false
	for jh in jump_hits:
		if jh.collider.name == "WallSouthLintel":
			lintel_hit = true
	assert_false(lintel_hit, "Player jumping up to 0.3m must still clear under doorway lintel")

	level.remove_child(player)
	player.free()

func _collect_nodes_of_type(node: Node, type_name: String, result: Array) -> void:
	if node.is_class(type_name):
		result.append(node)
	for child in node.get_children():
		_collect_nodes_of_type(child, type_name, result)
