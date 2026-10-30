class_name TestLevel
extends RefCounted

const Assertions = preload("res://tests/assertions.gd")
const LevelGrayboxClass = preload("res://scripts/world/level_graybox.gd")

const EXPECTED_LANDMARKS: Dictionary = {
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

func run_all() -> bool:
	var passed := true
	print("  Running TestLevel suite...")
	if not test_level_scene_loads():
		passed = false
	if not test_landmarks_exist_and_coordinates():
		passed = false
	if not test_plot_crop_spots():
		passed = false
	if not test_spawn_and_safe_return_transforms_and_clearance():
		passed = false
	if not test_environmental_collisions():
		passed = false
	if not test_recovery_mechanism():
		passed = false
	return passed

func test_level_scene_loads() -> bool:
	print("    [RUN] T24.1: Level Graybox Scene Loading and Hierarchy")
	var initial_failures = Assertions.current_suite_failed

	var file_exists = FileAccess.file_exists("res://scenes/world/level_graybox.tscn")
	Assertions.assert_true(file_exists, "scenes/world/level_graybox.tscn must exist")

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn")
	Assertions.assert_not_null(scene_res, "ResourceLoader must load level_graybox.tscn")

	if scene_res is PackedScene:
		var level = scene_res.instantiate()
		Assertions.assert_not_null(level, "level_graybox.tscn must instantiate successfully")
		Assertions.assert_true(level is Node3D, "Root node must be Node3D")
		Assertions.assert_equal(level.name, "LevelGraybox", "Root node name must be 'LevelGraybox'")
		Assertions.assert_true(level is LevelGrayboxClass, "Root node script must be LevelGraybox")
		level.free()
	else:
		Assertions.assert_true(false, "level_graybox.tscn is not a PackedScene")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T24.1: Level scene loading passed.")
	else:
		printerr("    [FAIL] T24.1: Level scene loading failed.")
	return ok

func test_landmarks_exist_and_coordinates() -> bool:
	print("    [RUN] T24.2: 18 Stable Landmarks Verification & Coordinate Tolerances")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = scene_res.instantiate() as Node3D

	for landmark_id in EXPECTED_LANDMARKS.keys():
		var expected_pos: Vector3 = EXPECTED_LANDMARKS[landmark_id]
		var landmark_node = level.find_child(landmark_id, true, false) as Node3D
		Assertions.assert_not_null(landmark_node, "Landmark '%s' must exist in scene tree" % landmark_id)

		if landmark_node != null:
			var actual_pos = landmark_node.position
			var dist = actual_pos.distance_to(expected_pos)
			Assertions.assert_true(dist <= 0.5, "Landmark '%s' position %s must match expected %s within 0.5m (diff: %.3f)" % [landmark_id, str(actual_pos), str(expected_pos), dist])
			Assertions.assert_true(actual_pos.y >= -0.1, "Landmark '%s' Y position must be at or above ground reference (Y=%.2f)" % [landmark_id, actual_pos.y])

	level.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T24.2: 18 Stable landmarks verification passed.")
	else:
		printerr("    [FAIL] T24.2: 18 Stable landmarks verification failed.")
	return ok

func test_plot_crop_spots() -> bool:
	print("    [RUN] T24.3: Crop Plot Quadrant Spots Verification")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = scene_res.instantiate() as LevelGrayboxClass

	var plot = level.get_landmark("plot_home_01")
	Assertions.assert_not_null(plot, "plot_home_01 must exist")

	if plot:
		var spots: Array[Node3D] = []
		for i in range(4):
			var spot_name = "spot_%d" % i
			var spot = plot.find_child(spot_name, true, false) as Node3D
			Assertions.assert_not_null(spot, "Plot spot '%s' must exist as child of plot_home_01" % spot_name)
			if spot:
				spots.append(spot)

		Assertions.assert_equal(spots.size(), 4, "plot_home_01 must contain exactly 4 crop spots")

		# Check spot distinctness and quadrant bounds
		for i in range(spots.size()):
			for j in range(i + 1, spots.size()):
				var dist = spots[i].position.distance_to(spots[j].position)
				Assertions.assert_gt(dist, 0.4, "Spots %d and %d must be distinct and spaced apart (dist: %.2f)" % [i, j, dist])

			# Verify within 2x2m plot (each quadrant center approx 0.5m from plot center)
			var offset_from_center = spots[i].position
			Assertions.assert_true(abs(offset_from_center.x) <= 1.0, "Spot %d X offset must be within 1.0m of plot center" % i)
			Assertions.assert_true(abs(offset_from_center.z) <= 1.0, "Spot %d Z offset must be within 1.0m of plot center" % i)

	level.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T24.3: Crop plot quadrant spots verification passed.")
	else:
		printerr("    [FAIL] T24.3: Crop plot quadrant spots verification failed.")
	return ok

func test_spawn_and_safe_return_transforms_and_clearance() -> bool:
	print("    [RUN] T25.1: Spawn & Safe Return Transforms, Facing and Wall Clearance")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = scene_res.instantiate() as LevelGrayboxClass

	# 1. Spawn home verification
	var spawn = level.get_spawn_point()
	Assertions.assert_not_null(spawn, "spawn_home must exist")
	if spawn:
		Assertions.assert_true(spawn.position.y >= 0.0, "spawn_home Y must be >= 0 (on/above floor)")
		# Orientation facing north (-Z)
		var forward_dot = -spawn.transform.basis.z.dot(Vector3(0, 0, -1))
		Assertions.assert_gt(forward_dot, 0.5, "spawn_home must face north (-Z direction)")

		# Clearance from house walls (Footprint X: -4..4, Z: -6..4)
		var spawn_pos = spawn.position
		var dist_to_west_wall = abs(spawn_pos.x - (-4.0))
		var dist_to_east_wall = abs(4.0 - spawn_pos.x)
		var dist_to_north_wall = abs(spawn_pos.z - (-6.0))
		var dist_to_south_wall = abs(4.0 - spawn_pos.z)

		Assertions.assert_gt(dist_to_west_wall, 1.5, "spawn_home must have >1.5m clearance from west wall (actual: %.2f)" % dist_to_west_wall)
		Assertions.assert_gt(dist_to_east_wall, 1.5, "spawn_home must have >1.5m clearance from east wall (actual: %.2f)" % dist_to_east_wall)
		Assertions.assert_gt(dist_to_north_wall, 1.5, "spawn_home must have >1.5m clearance from north wall (actual: %.2f)" % dist_to_north_wall)
		Assertions.assert_gt(dist_to_south_wall, 1.5, "spawn_home must have >1.5m clearance from south doorway (actual: %.2f)" % dist_to_south_wall)

	# 2. Safe return home verification
	var safe_return = level.get_safe_return_point()
	Assertions.assert_not_null(safe_return, "safe_return_home must exist")
	if safe_return:
		Assertions.assert_true(safe_return.position.y >= 0.0, "safe_return_home Y must be >= 0")
		var s_forward_dot = -safe_return.transform.basis.z.dot(Vector3(0, 0, -1))
		Assertions.assert_gt(s_forward_dot, 0.5, "safe_return_home must face north (-Z)")

		# Open area clearance: safe return is at (0, 0, 8), distance from house wall (Z=4) is 4m, from gate (Z=13) is 5m
		var dist_to_house = abs(safe_return.position.z - 4.0)
		var dist_to_gate = abs(13.0 - safe_return.position.z)
		Assertions.assert_gt(dist_to_house, 2.0, "safe_return_home must have open yard clearance from house (actual: %.2f)" % dist_to_house)
		Assertions.assert_gt(dist_to_gate, 2.0, "safe_return_home must have clearance from gate (actual: %.2f)" % dist_to_gate)

	level.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T25.1: Spawn & Safe Return verification passed.")
	else:
		printerr("    [FAIL] T25.1: Spawn & Safe Return verification failed.")
	return ok

func test_environmental_collisions() -> bool:
	print("    [RUN] T25.2: Environmental Collision Bodies (Ground, House Walls, Perimeter)")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = scene_res.instantiate() as Node3D

	# 1. Ground collision
	var ground = level.find_child("Ground", true, false)
	Assertions.assert_not_null(ground, "Ground node must exist")
	Assertions.assert_true(ground is StaticBody3D, "Ground must be a StaticBody3D")
	if ground is StaticBody3D:
		var ground_col = ground.find_child("Collision", true, false) as CollisionShape3D
		Assertions.assert_not_null(ground_col, "Ground must have a CollisionShape3D")
		if ground_col:
			Assertions.assert_true(ground_col.shape is BoxShape3D, "Ground shape must be BoxShape3D")

	# 2. House walls collision
	var required_walls = ["WallNorth", "WallWest", "WallEast", "WallSouthLeft", "WallSouthRight"]
	for wall_name in required_walls:
		var wall = level.find_child(wall_name, true, false)
		Assertions.assert_not_null(wall, "Wall '%s' must exist" % wall_name)
		Assertions.assert_true(wall is StaticBody3D, "Wall '%s' must be StaticBody3D" % wall_name)
		if wall is StaticBody3D:
			var col = wall.find_child("Collision", true, false) as CollisionShape3D
			Assertions.assert_not_null(col, "Wall '%s' must have CollisionShape3D" % wall_name)

	# 3. Perimeter boundaries collision
	var boundaries = ["BoundaryNorth", "BoundarySouth", "BoundaryWest", "BoundaryEast"]
	for b_name in boundaries:
		var b_node = level.find_child(b_name, true, false)
		Assertions.assert_not_null(b_node, "Perimeter boundary '%s' must exist" % b_name)
		Assertions.assert_true(b_node is StaticBody3D, "Boundary '%s' must be StaticBody3D" % b_name)

	level.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T25.2: Environmental collision bodies verification passed.")
	else:
		printerr("    [FAIL] T25.2: Environmental collision bodies verification failed.")
	return ok

func test_recovery_mechanism() -> bool:
	print("    [RUN] T25.3: Recovery Volume and Fall Detection Repositioning")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = scene_res.instantiate() as LevelGrayboxClass
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(level)

	# 1. Fall recovery volume check
	var fall_area = level.find_child("FallRecoveryArea", true, false) as Area3D
	Assertions.assert_not_null(fall_area, "FallRecoveryArea must exist and be an Area3D")
	if fall_area:
		var col = fall_area.find_child("FallAreaCollision", true, false) as CollisionShape3D
		Assertions.assert_not_null(col, "FallRecoveryArea must have a CollisionShape3D")
		Assertions.assert_true(fall_area.position.y < -5.0, "FallRecoveryArea must be placed below Y = -5.0")

	# 2. Test programmatic recovery when entity falls below Y = -5.0
	var dummy_entity = CharacterBody3D.new()
	dummy_entity.name = "DummyPlayer"
	dummy_entity.position = Vector3(0.0, -8.0, 0.0)
	dummy_entity.velocity = Vector3(0.0, -15.0, 0.0)
	level.add_child(dummy_entity)

	var safe_pos = level.get_safe_return_position()
	var recovered = level.check_and_recover_entity(dummy_entity)
	Assertions.assert_true(recovered, "check_and_recover_entity must return true for entity below Y = -5.0")
	Assertions.assert_true(dummy_entity.position.distance_to(safe_pos) < 0.1, "Entity position must be restored to safe_return_home")
	Assertions.assert_equal(dummy_entity.velocity, Vector3.ZERO, "Entity velocity must be reset to zero on recovery")

	# 3. Test entity out-of-bounds recovery
	dummy_entity.position = Vector3(80.0, 0.0, 80.0)
	var oob_recovered = level.check_and_recover_entity(dummy_entity)
	Assertions.assert_true(oob_recovered, "check_and_recover_entity must return true for out-of-bounds entity")
	Assertions.assert_true(dummy_entity.position.distance_to(safe_pos) < 0.1, "OOB entity must be restored to safe_return_home")

	dummy_entity.free()
	if tree and tree.root and level.get_parent() == tree.root:
		tree.root.remove_child(level)
	level.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T25.3: Recovery mechanism verification passed.")
	else:
		printerr("    [FAIL] T25.3: Recovery mechanism verification failed.")
	return ok
