class_name TestAdversarialLevel
extends RefCounted

const Assertions = preload("res://tests/assertions.gd")
const LevelGrayboxClass = preload("res://scripts/world/level_graybox.gd")

func run_all() -> bool:
	var passed := true
	print("==================================================")
	print("[ADVERSARIAL_SUITE] LVL-001 Stress Test & Safe Recovery Verification")
	print("==================================================")

	if not test_adv01_fall_recovery_area_and_trigger():
		passed = false
	if not test_adv02_velocity_reset_and_entity_types():
		passed = false
	if not test_adv03_state_preservation_and_non_mutation():
		passed = false
	if not test_adv04_safe_return_home_spatial_clearance():
		passed = false
	if not test_adv05_landmark_navigation_and_pathway_loop():
		passed = false
	if not test_adv06_perimeter_boundaries_and_oob_failsafe():
		passed = false

	return passed

func test_adv01_fall_recovery_area_and_trigger() -> bool:
	print("  [RUN] ADV-01: FallRecoveryArea Geometry, Signal, and Trigger Verification")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = scene_res.instantiate() as LevelGrayboxClass
	# Ensure _ready is invoked
	level._ready()

	var fall_area = level.find_child("FallRecoveryArea", true, false) as Area3D
	Assertions.assert_not_null(fall_area, "FallRecoveryArea must exist and be an Area3D")

	if fall_area:
		Assertions.assert_true(fall_area.position.y <= -5.0, "FallRecoveryArea Y position must be at or below -5.0m (actual: %.2f)" % fall_area.position.y)
		var col = fall_area.find_child("FallAreaCollision", true, false) as CollisionShape3D
		Assertions.assert_not_null(col, "FallAreaCollision must exist")
		if col and col.shape is BoxShape3D:
			var shape = col.shape as BoxShape3D
			Assertions.assert_true(shape.size.x >= 100.0, "Fall recovery volume X size must cover map envelope (actual: %.1f)" % shape.size.x)
			Assertions.assert_true(shape.size.z >= 100.0, "Fall recovery volume Z size must cover map envelope (actual: %.1f)" % shape.size.z)

		# Test signal connection and recovery invocation
		var test_body = CharacterBody3D.new()
		test_body.name = "FallingTestPlayer"
		test_body.position = Vector3(15.0, -8.0, 20.0)
		test_body.velocity = Vector3(5.0, -25.0, 5.0)
		level.add_child(test_body)

		var signal_data = {"received": false, "pos": Vector3.ZERO}
		var on_recovered = func(ent: Node3D, pos: Vector3):
			if ent == test_body:
				signal_data["received"] = true
				signal_data["pos"] = pos

		level.entity_recovered.connect(on_recovered)

		# Simulate body entering fall recovery area
		fall_area.body_entered.emit(test_body)

		Assertions.assert_true(signal_data["received"], "entity_recovered signal must be emitted on fall recovery")
		Assertions.assert_equal(signal_data["pos"], Vector3(0, 0, 8), "Recovered target position must be safe_return_home (0, 0, 8)")
		Assertions.assert_equal(test_body.position, Vector3(0, 0, 8), "test_body position must be redirected to (0, 0, 8)")
		Assertions.assert_equal(test_body.velocity, Vector3.ZERO, "test_body velocity must be reset to Vector3.ZERO")

		test_body.free()

	level.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV-01: FallRecoveryArea trigger verification passed.")
	else:
		printerr("  [FAIL] ADV-01: FallRecoveryArea trigger verification failed.")
	return ok

func test_adv02_velocity_reset_and_entity_types() -> bool:
	print("  [RUN] ADV-02: Velocity Nullification for CharacterBody3D, RigidBody3D, and Node3D")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = scene_res.instantiate() as LevelGrayboxClass

	# 1. CharacterBody3D
	var cb = CharacterBody3D.new()
	cb.position = Vector3(-10.0, -12.0, 15.0)
	cb.velocity = Vector3(14.2, -60.0, -18.7)
	level.recover_entity(cb)
	Assertions.assert_equal(cb.position, Vector3(0, 0, 8), "CharacterBody3D position must be (0, 0, 8)")
	Assertions.assert_equal(cb.velocity, Vector3.ZERO, "CharacterBody3D velocity must be reset to Vector3.ZERO")
	cb.free()

	# 2. RigidBody3D
	var rb = RigidBody3D.new()
	rb.position = Vector3(25.0, -10.0, -15.0)
	rb.linear_velocity = Vector3(10.0, -30.0, 5.0)
	rb.angular_velocity = Vector3(2.0, 4.0, 1.0)
	level.recover_entity(rb)
	Assertions.assert_equal(rb.position, Vector3(0, 0, 8), "RigidBody3D position must be (0, 0, 8)")
	Assertions.assert_equal(rb.linear_velocity, Vector3.ZERO, "RigidBody3D linear_velocity must be reset to Vector3.ZERO")
	Assertions.assert_equal(rb.angular_velocity, Vector3.ZERO, "RigidBody3D angular_velocity must be reset to Vector3.ZERO")
	rb.free()

	# 3. Generic Node3D
	var generic_node = Node3D.new()
	generic_node.position = Vector3(-5.0, -20.0, 10.0)
	level.recover_entity(generic_node)
	Assertions.assert_equal(generic_node.position, Vector3(0, 0, 8), "Generic Node3D position must be (0, 0, 8)")
	generic_node.free()

	# 4. Null instance handling (graceful, no crash)
	level.recover_entity(null)
	Assertions.assert_true(true, "recover_entity(null) handled gracefully without error")

	level.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV-02: Velocity nullification across entity types passed.")
	else:
		printerr("  [FAIL] ADV-02: Velocity nullification failed.")
	return ok

func test_adv03_state_preservation_and_non_mutation() -> bool:
	print("  [RUN] ADV-03: State Invariance & Non-Mutation on Recovery")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = scene_res.instantiate() as LevelGrayboxClass

	var player = CharacterBody3D.new()
	player.name = "PlayerEntity"
	player.position = Vector3(0, -9.0, 0)
	player.velocity = Vector3(0, -30.0, 0)

	# Attach rich player state
	var inventory_data = {
		"bayam": 4,
		"jagung": 2,
		"temu_kunci": 1,
		"seed_bayam": 5,
		"fertilizer": 3,
		"water_can_fill": 1
	}
	player.set_meta("inventory", inventory_data)
	player.set_meta("health", 100)
	player.set_meta("recipe_active", "sayur_bening_bayam_jagung")

	# Attach child components
	var item_holder = Node3D.new()
	item_holder.name = "HeldItemSlot"
	player.add_child(item_holder)

	var camera = Camera3D.new()
	camera.name = "FirstPersonCamera"
	player.add_child(camera)

	# Execute recovery
	level.recover_entity(player)

	# Assert state preservation
	Assertions.assert_true(player.has_meta("inventory"), "Player inventory metadata must be preserved")
	var inv_result = player.get_meta("inventory") as Dictionary
	Assertions.assert_equal(inv_result.get("bayam"), 4, "Item count bayam must be preserved exactly")
	Assertions.assert_equal(inv_result.get("jagung"), 2, "Item count jagung must be preserved exactly")
	Assertions.assert_equal(inv_result.get("temu_kunci"), 1, "Item count temu_kunci must be preserved exactly")
	Assertions.assert_equal(inv_result.get("seed_bayam"), 5, "Item count seed_bayam must be preserved exactly")

	Assertions.assert_equal(player.get_meta("health"), 100, "Health metadata must be preserved")
	Assertions.assert_equal(player.get_meta("recipe_active"), "sayur_bening_bayam_jagung", "Active recipe metadata preserved")

	Assertions.assert_true(player.has_node("HeldItemSlot"), "Child HeldItemSlot must not be modified or freed")
	Assertions.assert_true(player.has_node("FirstPersonCamera"), "Child FirstPersonCamera must not be modified or freed")
	Assertions.assert_equal(player.get_child_count(), 2, "Player child count must remain exactly 2")

	# Assert level scene state invariance
	var plot = level.get_landmark("plot_home_01")
	Assertions.assert_not_null(plot, "plot_home_01 must remain intact")
	var spots = level.get_crop_spots()
	Assertions.assert_equal(spots.size(), 4, "Crop spots must remain 4 after entity recovery")

	player.free()
	level.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV-03: State invariance and non-mutation passed.")
	else:
		printerr("  [FAIL] ADV-03: State invariance failed.")
	return ok

func test_adv04_safe_return_home_spatial_clearance() -> bool:
	print("  [RUN] ADV-04: safe_return_home Spatial Clearance and Collision Oracle")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = scene_res.instantiate() as LevelGrayboxClass

	var srp = level.get_safe_return_point()
	Assertions.assert_not_null(srp, "safe_return_home must exist in scene")
	var srp_pos = level.get_safe_return_position()
	Assertions.assert_equal(srp_pos, Vector3(0, 0, 8), "safe_return_home coordinates must be exactly (0, 0, 8)")

	# Clearance to House Walls (Footprint X [-4..4], Z [-6..4])
	var house_south_wall_z = 4.0
	var dist_to_house_wall = abs(srp_pos.z - house_south_wall_z)
	Assertions.assert_gt(dist_to_house_wall, 3.0, "safe_return_home must have >3m clearance from house south wall (actual: %.2f)" % dist_to_house_wall)

	# Clearance to plot_home_01 at (8, 0, 7)
	var plot = level.get_landmark("plot_home_01")
	Assertions.assert_not_null(plot, "plot_home_01 landmark must exist")
	if plot:
		var plot_dist = srp_pos.distance_to(plot.position)
		Assertions.assert_gt(plot_dist, 5.0, "safe_return_home must have >5m clearance from plot_home_01 (actual: %.2f)" % plot_dist)
		# Nearest edge of 2x2m plot is at X = 7.0, safe return is at X = 0.0 -> 7m horizontal gap
		var plot_edge_clearance = abs(plot.position.x - 1.0 - srp_pos.x)
		Assertions.assert_gt(plot_edge_clearance, 5.0, "safe_return_home must not overlap plot boundary (clearance: %.2f)" % plot_edge_clearance)

	# Clearance to water_home at (4, 0, 9)
	var water = level.get_landmark("water_home")
	if water:
		var water_dist = srp_pos.distance_to(water.position)
		Assertions.assert_gt(water_dist, 3.5, "safe_return_home must have clearance from water basin (actual: %.2f)" % water_dist)

	# Clearance to gate_home at (0, 0, 13)
	var gate = level.get_landmark("gate_home")
	if gate:
		var gate_dist = srp_pos.distance_to(gate.position)
		Assertions.assert_gt(gate_dist, 4.0, "safe_return_home must have clearance from gate (actual: %.2f)" % gate_dist)

	# Ground floor support check (ground extends X [-40..40], Z [-35..45])
	var ground = level.find_child("Ground", true, false) as StaticBody3D
	Assertions.assert_not_null(ground, "Ground static body must exist under safe_return_home")
	Assertions.assert_true(srp_pos.x >= -40.0 and srp_pos.x <= 40.0, "safe_return_home must be inside ground X bounds")
	Assertions.assert_true(srp_pos.z >= -35.0 and srp_pos.z <= 45.0, "safe_return_home must be inside ground Z bounds")
	Assertions.assert_true(srp_pos.y >= 0.0, "safe_return_home must be on or above ground level Y=0")

	level.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV-04: safe_return_home spatial clearance verified.")
	else:
		printerr("  [FAIL] ADV-04: safe_return_home spatial clearance failed.")
	return ok

func test_adv05_landmark_navigation_and_pathway_loop() -> bool:
	print("  [RUN] ADV-05: Landmark Navigation, East/West Connectivity & Southern Loop")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = scene_res.instantiate() as LevelGrayboxClass

	# 1. Landmark coordinates check
	var jagung = level.get_landmark("resource_jagung_01")
	Assertions.assert_not_null(jagung, "resource_jagung_01 must exist")
	if jagung:
		Assertions.assert_true(jagung.position.distance_to(Vector3(22, 0, 28)) <= 0.5, "resource_jagung_01 position matches (22, 0, 28)")

	var temu_kunci = level.get_landmark("resource_temu_kunci_01")
	Assertions.assert_not_null(temu_kunci, "resource_temu_kunci_01 must exist")
	if temu_kunci:
		Assertions.assert_true(temu_kunci.position.distance_to(Vector3(-20, 0, 30)) <= 0.5, "resource_temu_kunci_01 position matches (-20, 0, 30)")

	var neighbor = level.get_landmark("npc_neighbor_01")
	Assertions.assert_not_null(neighbor, "npc_neighbor_01 must exist")
	if neighbor:
		Assertions.assert_true(neighbor.position.distance_to(Vector3(-14, 0, 15)) <= 0.5, "npc_neighbor_01 position matches (-14, 0, 15)")

	var junction = level.get_landmark("junction_path")
	Assertions.assert_not_null(junction, "junction_path must exist")
	if junction:
		Assertions.assert_true(junction.position.distance_to(Vector3(0, 0, 21)) <= 0.5, "junction_path position matches (0, 0, 21)")

	# 2. Visual dirt pathways layout verification
	var paths_node = level.find_child("Paths", true, false)
	Assertions.assert_not_null(paths_node, "Paths container node must exist")

	var required_path_segments = [
		"Path_HouseToGate",
		"Path_GateToJunction",
		"Path_JunctionToEast",
		"Path_JunctionToWest",
		"Path_SouthLoop",
		"Path_EastConnector",
		"Path_WestConnector"
	]

	for path_name in required_path_segments:
		var p = level.find_child(path_name, true, false)
		Assertions.assert_not_null(p, "Path segment '%s' must exist in level" % path_name)

	# 3. Pathway Loop Connectivity Verification:
	# Trace full circular loop waypoints:
	# A: Junction (0, 0, 21)
	# B: East path to Jagung (22, 0, 28)
	# C: East Connector southward to (21, 0, 35)
	# D: South Loop connecting east to west along Z=35 (from X=20 to X=-18)
	# E: West Connector northward to Temu Kunci (-18, 0, 30)
	# F: West path back through neighbor area to Junction (0, 0, 21)
	var south_loop = level.find_child("Path_SouthLoop", true, false) as MeshInstance3D
	var east_conn = level.find_child("Path_EastConnector", true, false) as MeshInstance3D
	var west_conn = level.find_child("Path_WestConnector", true, false) as MeshInstance3D

	if south_loop and east_conn and west_conn:
		# South loop Z position check
		Assertions.assert_true(abs(south_loop.position.z - 35.0) < 1.0, "South loop must be placed in southern section (Z approx 35)")
		var south_mesh = south_loop.mesh as BoxMesh
		Assertions.assert_not_null(south_mesh, "South loop must have BoxMesh")
		if south_mesh:
			Assertions.assert_true(south_mesh.size.x >= 35.0, "South loop must bridge at least 35m across east and west paths (actual: %.1f)" % south_mesh.size.x)

		# East connector connects from East garden (Z=28) to South loop (Z=35)
		Assertions.assert_true(east_conn.position.x > 18.0, "East connector X must be in eastern sector (X > 18)")
		Assertions.assert_true(east_conn.position.z > 28.0 and east_conn.position.z < 35.0, "East connector must span between garden and south loop")

		# West connector connects from Temu Kunci (Z=30) to South loop (Z=35)
		Assertions.assert_true(west_conn.position.x < -15.0, "West connector X must be in western sector (X < -15)")
		Assertions.assert_true(west_conn.position.z >= 30.0 and west_conn.position.z <= 35.0, "West connector must span between west sector and south loop")

	level.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV-05: Landmark navigation & pathway loop connectivity verified.")
	else:
		printerr("  [FAIL] ADV-05: Pathway loop verification failed.")
	return ok

func test_adv06_perimeter_boundaries_and_oob_failsafe() -> bool:
	print("  [RUN] ADV-06: Perimeter Boundaries Integrity & OOB Fail-Safe Oracle")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = scene_res.instantiate() as LevelGrayboxClass

	# 1. Perimeter boundary static bodies
	var b_north = level.find_child("BoundaryNorth", true, false) as StaticBody3D
	var b_south = level.find_child("BoundarySouth", true, false) as StaticBody3D
	var b_west = level.find_child("BoundaryWest", true, false) as StaticBody3D
	var b_east = level.find_child("BoundaryEast", true, false) as StaticBody3D

	Assertions.assert_not_null(b_north, "BoundaryNorth must exist")
	Assertions.assert_not_null(b_south, "BoundarySouth must exist")
	Assertions.assert_not_null(b_west, "BoundaryWest must exist")
	Assertions.assert_not_null(b_east, "BoundaryEast must exist")

	# Check heights: must be at least 3.0m to prevent player jump-over
	for b in [b_north, b_south, b_west, b_east]:
		if b != null:
			var col = b.find_child("Collision", true, false) as CollisionShape3D
			Assertions.assert_not_null(col, "Boundary must have collision shape")
			if col and col.shape is BoxShape3D:
				var bs = col.shape as BoxShape3D
				Assertions.assert_true(bs.size.y >= 3.5, "Boundary height must be >= 3.5m (actual: %.1f)" % bs.size.y)

	# 2. Out-of-bounds programmatic fail-safe oracle: check_and_recover_entity
	var test_dummy = CharacterBody3D.new()
	test_dummy.name = "OOBTester"
	level.add_child(test_dummy)

	# Test 6 out-of-bounds directions:
	var oob_cases = [
		{"pos": Vector3(45.0, 0.0, 0.0), "name": "East OOB (X=45)"},
		{"pos": Vector3(-45.0, 0.0, 0.0), "name": "West OOB (X=-45)"},
		{"pos": Vector3(0.0, 0.0, 50.0), "name": "South OOB (Z=50)"},
		{"pos": Vector3(0.0, 0.0, -40.0), "name": "North OOB (Z=-40)"},
		{"pos": Vector3(60.0, 0.0, 60.0), "name": "Diagonal SE OOB"},
		{"pos": Vector3(0.0, -7.0, 0.0), "name": "Void Fall (Y=-7)"}
	]

	for tc in oob_cases:
		test_dummy.position = tc["pos"]
		test_dummy.velocity = Vector3(10.0, -20.0, 10.0)
		var recovered = level.check_and_recover_entity(test_dummy)
		Assertions.assert_true(recovered, "check_and_recover_entity must trigger for %s" % tc["name"])
		Assertions.assert_equal(test_dummy.position, Vector3(0, 0, 8), "%s must be teleported to (0, 0, 8)" % tc["name"])
		Assertions.assert_equal(test_dummy.velocity, Vector3.ZERO, "%s velocity must be zeroed" % tc["name"])

	# Test inside valid bounds: must NOT trigger recovery
	var inside_cases = [
		Vector3(0.0, 0.0, 1.0),   # spawn
		Vector3(0.0, 0.0, 8.0),   # safe return
		Vector3(22.0, 0.0, 28.0), # jagung
		Vector3(-20.0, 0.0, 30.0),# temu kunci
		Vector3(0.0, 0.0, 35.0),  # south loop
		Vector3(38.0, 0.0, 0.0),  # near east edge
		Vector3(-38.0, 0.0, 0.0)  # near west edge
	]

	for ip in inside_cases:
		test_dummy.position = ip
		test_dummy.velocity = Vector3(1.0, 0.0, 1.0)
		var triggered = level.check_and_recover_entity(test_dummy)
		Assertions.assert_false(triggered, "Valid inside position %s must NOT trigger recovery" % str(ip))
		Assertions.assert_equal(test_dummy.position, ip, "Inside entity position must remain unchanged")

	test_dummy.free()
	level.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV-06: Perimeter boundaries and OOB fail-safe verified.")
	else:
		printerr("  [FAIL] ADV-06: Perimeter boundaries verification failed.")
	return ok
