extends SceneTree

# Adversarial Challenge Test Harness for Milestone LVL-001
# Executed via: godot_console.exe --headless --script res://tests/adversarial_level_challenge.gd

const LevelGrayboxClass = preload("res://scripts/world/level_graybox.gd")

var total_assertions := 0
var passed_assertions := 0
var failed_assertions := 0

func _init() -> void:
	print("==================================================")
	print("[ADVERSARIAL_CHALLENGE] Starting LVL-001 Stress Harness...")
	print("==================================================")
	call_deferred("_run_suite")

func _run_suite() -> void:
	var passed = await run_adversarial_tests()

	print("==================================================")
	print("[ADVERSARIAL_CHALLENGE] SUMMARY:")
	print("  Total Assertions:  ", total_assertions)
	print("  Passed Assertions: ", passed_assertions)
	print("  Failed Assertions: ", failed_assertions)
	if passed and failed_assertions == 0:
		print("  VERDICT: ALL ADVERSARIAL CHALLENGES PASSED (Exit Code: 0)")
		quit(0)
	else:
		printerr("  VERDICT: ADVERSARIAL CHALLENGES FAILED (Exit Code: 1)")
		quit(1)

func assert_true(condition: bool, msg: String) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
	else:
		failed_assertions += 1
		printerr("    [CHALLENGE_FAIL] ", msg)

func assert_false(condition: bool, msg: String) -> void:
	assert_true(not condition, msg)

func assert_gt(val: float, threshold: float, msg: String) -> void:
	assert_true(val > threshold, "%s (val=%.3f, threshold=%.3f)" % [msg, val, threshold])

func run_adversarial_tests() -> bool:
	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	assert_true(scene_res != null, "Scene resource level_graybox.tscn must load")
	if scene_res == null:
		return false

	var level = scene_res.instantiate()
	assert_true(level != null, "level_graybox.tscn must instantiate")
	if level == null:
		return false

	root.add_child(level)

	# Wait two physics frames for physics space to initialize
	for i in range(3):
		await process_frame

	var world_3d = level.get_world_3d()
	assert_true(world_3d != null, "World3D must be accessible")
	var space_state = world_3d.direct_space_state
	assert_true(space_state != null, "PhysicsDirectSpaceState3D must be valid")

	print("\n--- Challenge 1: Spawn Home & Safe Return Clearance ---")
	test_spawn_clearance(level, space_state)

	print("\n--- Challenge 2: Doorway Traversal & Wall Blockades ---")
	test_doorway_and_walls(level, space_state)

	print("\n--- Challenge 3: Ground Collision Coverage & Envelope Bounds ---")
	test_ground_and_boundaries(level, space_state)

	print("\n--- Challenge 4: Fall Recovery Area & OOB Recovery Logic ---")
	test_recovery_edge_cases(level)

	print("\n--- Challenge 5: 18 Landmarks Strict Tolerances & Quadrant Crop Spots ---")
	test_landmarks_and_crop_spots(level)

	root.remove_child(level)
	level.free()
	return failed_assertions == 0

func test_spawn_clearance(level: Node3D, space_state: PhysicsDirectSpaceState3D) -> void:
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8

	var spawn_pos: Vector3 = level.get_spawn_position()
	print("  Spawn Home Position: ", spawn_pos)
	assert_true(spawn_pos.is_equal_approx(Vector3(0, 0, 1)), "spawn_home must be at (0, 0, 1)")

	# Capsule center at Y = 0.9 (bottom at Y = 0.0, top at Y = 1.8)
	var spawn_capsule_transform = Transform3D(Basis.IDENTITY, spawn_pos + Vector3(0, 0.9, 0))
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = spawn_capsule_transform
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_bodies = true
	query.collide_with_areas = false

	# Test shape collision
	var hits = space_state.intersect_shape(query, 10)
	var wall_obstacle_hits: Array = []
	for hit in hits:
		var col = hit.collider
		var col_name = col.name if col else "unknown"
		if col_name != "Ground" and col_name != "HouseFloor":
			wall_obstacle_hits.append(col_name)

	print("  Obstacle hits at spawn: ", wall_obstacle_hits)
	assert_true(wall_obstacle_hits.is_empty(), "Player capsule at spawn_home must have ZERO collisions with walls or obstacles")

	# Safe return point clearance
	var safe_pos: Vector3 = level.get_safe_return_position()
	print("  Safe Return Position: ", safe_pos)
	assert_true(safe_pos.is_equal_approx(Vector3(0, 0, 8)), "safe_return_home must be at (0, 0, 8)")
	var safe_capsule_transform = Transform3D(Basis.IDENTITY, safe_pos + Vector3(0, 0.9, 0))
	query.transform = safe_capsule_transform
	var safe_hits = space_state.intersect_shape(query, 10)
	var safe_obstacle_hits: Array = []
	for hit in safe_hits:
		var col = hit.collider
		var col_name = col.name if col else "unknown"
		if col_name != "Ground":
			safe_obstacle_hits.append(col_name)
	print("  Obstacle hits at safe_return: ", safe_obstacle_hits)
	assert_true(safe_obstacle_hits.is_empty(), "Player capsule at safe_return_home must have ZERO collisions with obstacles")

func test_doorway_and_walls(level: Node3D, space_state: PhysicsDirectSpaceState3D) -> void:
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8

	# Check doorway: Walk from spawn (0, 0.9, 1) through doorway (0, 0.9, 4) to yard (0, 0.9, 6)
	var steps = 20
	var door_blocked := false
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var test_pos = Vector3(0.0, 0.9, lerp(1.0, 6.0, t))
		var q = PhysicsShapeQueryParameters3D.new()
		q.shape = capsule
		q.transform = Transform3D(Basis.IDENTITY, test_pos)
		q.collide_with_bodies = true
		q.collide_with_areas = false
		var hits = space_state.intersect_shape(q, 10)
		for hit in hits:
			var cname = hit.collider.name
			if cname != "Ground" and cname != "HouseFloor":
				door_blocked = true
				printerr("  Doorway blocked at pos ", test_pos, " by ", cname)

	assert_false(door_blocked, "Player capsule must have unobstructed walk through south doorway (Z=1 to Z=6)")

	# Challenge walls in all 4 directions:
	# 1. North Wall (Z = -6): Raycast from (0, 1.5, -4) to (0, 1.5, -8)
	var ray_north = PhysicsRayQueryParameters3D.create(Vector3(0, 1.5, -4), Vector3(0, 1.5, -8))
	var hit_north = space_state.intersect_ray(ray_north)
	assert_true(not hit_north.is_empty(), "North wall must block raycast at Z = -6")
	if not hit_north.is_empty():
		assert_true(hit_north.collider.name == "WallNorth", "Hit collider must be WallNorth")

	# 2. West Wall (X = -4): Raycast from (-2, 1.5, -1) to (-6, 1.5, -1)
	var ray_west = PhysicsRayQueryParameters3D.create(Vector3(-2, 1.5, -1), Vector3(-6, 1.5, -1))
	var hit_west = space_state.intersect_ray(ray_west)
	assert_true(not hit_west.is_empty(), "West wall must block raycast at X = -4")
	if not hit_west.is_empty():
		assert_true(hit_west.collider.name == "WallWest", "Hit collider must be WallWest")

	# 3. East Wall (X = 4): Raycast from (2, 1.5, -1) to (6, 1.5, -1)
	var ray_east = PhysicsRayQueryParameters3D.create(Vector3(2, 1.5, -1), Vector3(6, 1.5, -1))
	var hit_east = space_state.intersect_ray(ray_east)
	assert_true(not hit_east.is_empty(), "East wall must block raycast at X = 4")
	if not hit_east.is_empty():
		assert_true(hit_east.collider.name == "WallEast", "Hit collider must be WallEast")

	# 4. South Wall Left & Right (Z = 4):
	var ray_south_l = PhysicsRayQueryParameters3D.create(Vector3(-2.4, 1.5, 2), Vector3(-2.4, 1.5, 6))
	var hit_south_l = space_state.intersect_ray(ray_south_l)
	assert_true(not hit_south_l.is_empty(), "South wall left must block raycast at X = -2.4")
	if not hit_south_l.is_empty():
		assert_true(hit_south_l.collider.name == "WallSouthLeft", "Hit collider must be WallSouthLeft")

	var ray_south_r = PhysicsRayQueryParameters3D.create(Vector3(2.4, 1.5, 2), Vector3(2.4, 1.5, 6))
	var hit_south_r = space_state.intersect_ray(ray_south_r)
	assert_true(not hit_south_r.is_empty(), "South wall right must block raycast at X = 2.4")
	if not hit_south_r.is_empty():
		assert_true(hit_south_r.collider.name == "WallSouthRight", "Hit collider must be WallSouthRight")

func test_ground_and_boundaries(level: Node3D, space_state: PhysicsDirectSpaceState3D) -> void:
	# First, let's directly verify Ground StaticBody3D properties:
	var ground = level.find_child("Ground", true, false) as StaticBody3D
	assert_true(ground != null, "Ground StaticBody3D must exist")
	if ground:
		var col = ground.find_child("Collision", true, false) as CollisionShape3D
		assert_true(col != null, "Ground must have CollisionShape3D")
		var shape = col.shape as BoxShape3D
		assert_true(shape != null, "Ground collision shape must be BoxShape3D")
		if shape:
			print("  Ground shape size: ", shape.size)
			print("  Ground node position: ", ground.position)
			# Envelope check: width 80 (X -40..40), length 80 (Z -35..45 with center Z=5)
			assert_true(shape.size.x >= 80.0, "Ground width (X) must be at least 80.0m")
			assert_true(shape.size.z >= 80.0, "Ground length (Z) must be at least 80.0m")
			var min_x = ground.position.x - shape.size.x / 2.0
			var max_x = ground.position.x + shape.size.x / 2.0
			var min_z = ground.position.z - shape.size.z / 2.0
			var max_z = ground.position.z + shape.size.z / 2.0
			assert_true(min_x <= -40.0, "Ground min X must cover <= -40.0 (actual: %.2f)" % min_x)
			assert_true(max_x >= 40.0, "Ground max X must cover >= 40.0 (actual: %.2f)" % max_x)
			assert_true(min_z <= -35.0, "Ground min Z must cover <= -35.0 (actual: %.2f)" % min_z)
			assert_true(max_z >= 45.0, "Ground max Z must cover >= 45.0 (actual: %.2f)" % max_z)

	# Raycast downward test inside playable open terrain (avoiding walls/props)
	var open_test_points = [
		Vector3(-35.0, 5.0, -30.0), # Open terrain NW
		Vector3(35.0, 5.0, -30.0),  # Open terrain NE
		Vector3(-35.0, 5.0, 40.0),  # Open terrain SW
		Vector3(35.0, 5.0, 40.0),   # Open terrain SE
		Vector3(0.0, 5.0, 5.0),     # Center of ground envelope
		Vector3(2.0, 5.0, 15.0),    # Yard path area
		Vector3(15.0, 5.0, 25.0),   # Approaching east garden
		Vector3(-10.0, 5.0, 25.0),  # Approaching west bamboo
		Vector3(0.0, 5.0, 35.0),    # South loop path
	]

	for pt in open_test_points:
		var ray = PhysicsRayQueryParameters3D.create(pt, pt + Vector3(0, -10.0, 0))
		var hit = space_state.intersect_ray(ray)
		assert_true(not hit.is_empty(), "Ground must be detected below point (%s)" % str(pt))
		if not hit.is_empty():
			assert_true(hit.collider.name == "Ground" or hit.collider.name == "HouseFloor", "Collider below point %s must be Ground or HouseFloor (got %s)" % [str(pt), hit.collider.name])
			assert_true(abs(hit.position.y) < 0.2, "Ground hit Y must be near Y=0 (actual: %.2f)" % hit.position.y)

	# Verify Perimeter Boundaries block rays leaving envelope
	# North: Z < -35
	var ray_north = PhysicsRayQueryParameters3D.create(Vector3(0, 2.0, -30), Vector3(0, 2.0, -40))
	var hit_north = space_state.intersect_ray(ray_north)
	assert_true(not hit_north.is_empty(), "Perimeter BoundaryNorth must block outward ray")
	if not hit_north.is_empty():
		assert_true(hit_north.collider.name == "BoundaryNorth", "Collider must be BoundaryNorth")

	# South: Z > 45
	var ray_south = PhysicsRayQueryParameters3D.create(Vector3(0, 2.0, 40), Vector3(0, 2.0, 50))
	var hit_south = space_state.intersect_ray(ray_south)
	assert_true(not hit_south.is_empty(), "Perimeter BoundarySouth must block outward ray")
	if not hit_south.is_empty():
		assert_true(hit_south.collider.name == "BoundarySouth", "Collider must be BoundarySouth")

	# West: X < -40
	var ray_west = PhysicsRayQueryParameters3D.create(Vector3(-35, 2.0, 5), Vector3(-45, 2.0, 5))
	var hit_west = space_state.intersect_ray(ray_west)
	assert_true(not hit_west.is_empty(), "Perimeter BoundaryWest must block outward ray")
	if not hit_west.is_empty():
		assert_true(hit_west.collider.name == "BoundaryWest", "Collider must be BoundaryWest")

	# East: X > 40
	var ray_east = PhysicsRayQueryParameters3D.create(Vector3(35, 2.0, 5), Vector3(45, 2.0, 5))
	var hit_east = space_state.intersect_ray(ray_east)
	assert_true(not hit_east.is_empty(), "Perimeter BoundaryEast must block outward ray")
	if not hit_east.is_empty():
		assert_true(hit_east.collider.name == "BoundaryEast", "Collider must be BoundaryEast")

func test_recovery_edge_cases(level: Node3D) -> void:
	var safe_pos: Vector3 = level.get_safe_return_position()

	var dummy = CharacterBody3D.new()
	dummy.name = "StressDummy"
	level.add_child(dummy)

	# 1. Negative Y below -5.0
	dummy.position = Vector3(10.0, -5.01, 10.0)
	dummy.velocity = Vector3(2.0, -20.0, 3.0)
	var rec1 = level.check_and_recover_entity(dummy)
	assert_true(rec1, "Entity at Y = -5.01 must trigger recovery")
	assert_true(dummy.position.is_equal_approx(safe_pos), "Dummy must be teleported to safe_return_home")
	assert_true(dummy.velocity == Vector3.ZERO, "Dummy velocity must be zeroed")

	# 2. X beyond boundary (> 42.0)
	dummy.position = Vector3(42.5, 1.0, 0.0)
	dummy.velocity = Vector3(10.0, 0.0, 0.0)
	var rec2 = level.check_and_recover_entity(dummy)
	assert_true(rec2, "Entity at X = 42.5 must trigger boundary recovery")
	assert_true(dummy.position.is_equal_approx(safe_pos), "Dummy must be teleported to safe_return_home")

	# 3. Z beyond boundary (< -37.0)
	dummy.position = Vector3(0.0, 1.0, -38.0)
	var rec3 = level.check_and_recover_entity(dummy)
	assert_true(rec3, "Entity at Z = -38.0 must trigger boundary recovery")
	assert_true(dummy.position.is_equal_approx(safe_pos), "Dummy must be teleported to safe_return_home")

	# 4. Safe position should NOT trigger recovery
	dummy.position = Vector3(0.0, 0.0, 1.0)
	var rec4 = level.check_and_recover_entity(dummy)
	assert_false(rec4, "Entity at normal valid position (0, 0, 1) must NOT trigger recovery")

	dummy.free()

func test_landmarks_and_crop_spots(level: Node3D) -> void:
	var landmarks: Array[String] = level.LANDMARK_IDS
	assert_true(landmarks.size() == 18, "Level must define exactly 18 landmarks")

	for lid in landmarks:
		var node = level.get_landmark(lid)
		assert_true(node != null, "Landmark '%s' must be resolvable via get_landmark()" % lid)

	var spots: Array[Node3D] = level.get_crop_spots()
	assert_true(spots.size() == 4, "get_crop_spots() must return exactly 4 spots")
	if spots.size() == 4:
		var plot_pos = level.get_landmark("plot_home_01").position
		for i in range(4):
			var spot = spots[i]
			var global_spot_pos = spot.global_position if spot.is_inside_tree() else (plot_pos + spot.position)
			print("  Crop spot %d global pos: %s" % [i, str(global_spot_pos)])
			assert_gt(global_spot_pos.y, -0.05, "Spot %d Y must be at or above ground" % i)
