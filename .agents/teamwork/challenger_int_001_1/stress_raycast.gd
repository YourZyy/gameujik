extends SceneTree

# ==============================================================================
# EMPIRICAL STRESS TEST HARNESS: INT-001 RAYCAST INTERACTION & OCCLUSION
# ==============================================================================
# Agent: challenger_int_001_1 (teamwork_challenger)
# Target: Raycast interaction detection, distance precision cutoffs,
#         multi-layer wall occlusion physics, off-axis alignment,
#         and landmark interactable registration.
# Executed via: godot --headless -s res://.agents/teamwork/challenger_int_001_1/stress_raycast.gd
# ==============================================================================

const InteractableClass = preload("res://scripts/interaction/interactable.gd")
const InteractionDetectorClass = preload("res://scripts/interaction/interaction_detector.gd")
const LevelGrayboxClass = preload("res://scripts/world/level_graybox.gd")

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0

var failure_log: Array[String] = []

func _init() -> void:
	print("==================================================================")
	print("[EMPIRICAL_CHALLENGER] Starting INT-001 Raycast Stress Harness...")
	print("==================================================================")
	call_deferred("_run_harness")

func assert_true(condition: bool, description: String) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
	else:
		failed_assertions += 1
		var msg = "  [FAIL] %s" % description
		failure_log.append(msg)
		printerr(msg)

func assert_false(condition: bool, description: String) -> void:
	assert_true(not condition, description)

func assert_equal(actual, expected, description: String) -> void:
	var ok: bool = (actual == expected)
	assert_true(ok, "%s (actual='%s', expected='%s')" % [description, str(actual), str(expected)])

func assert_not_null(val, description: String) -> void:
	assert_true(val != null, "%s (expected non-null, got null)" % description)

func assert_null(val, description: String) -> void:
	assert_true(val == null, "%s (expected null, got %s)" % [description, str(val)])

func _run_harness() -> void:
	var success := true

	# Test 1: Distance Precision Cutoffs
	print("\n--- TEST SECTION 1: Distance Precision & Cutoff Boundaries ---")
	if not await test_distance_precision():
		success = false

	# Test 2: Multi-Layer Wall Occlusion Physics
	print("\n--- TEST SECTION 2: Multi-Layer Wall Occlusion Physics ---")
	if not await test_wall_occlusion_thicknesses():
		success = false

	# Test 3: Off-Axis Alignment & Cone Angle
	print("\n--- TEST SECTION 3: Off-Axis Alignment & Angular Line of Sight ---")
	if not await test_off_axis_alignment():
		success = false

	# Test 4: Landmark Interactable Registration & Spatial Accessibility
	print("\n--- TEST SECTION 4: 12 Graybox Landmark Interactables Registration ---")
	if not await test_landmark_registration():
		success = false

	# Test 5: Dynamic State Transitions & State Invariance
	print("\n--- TEST SECTION 5: Dynamic State Transitions & Enable/Disable Invariance ---")
	if not await test_dynamic_state_invariance():
		success = false

	print("\n==================================================================")
	print("[EMPIRICAL_CHALLENGER] STRESS HARNESS SUMMARY:")
	print("  Total Assertions:  %d" % total_assertions)
	print("  Passed Assertions: %d" % passed_assertions)
	print("  Failed Assertions: %d" % failed_assertions)

	if failed_assertions == 0 and success:
		print("  VERDICT: CONFIRMED CORRECT (Exit Code: 0)")
		print("==================================================================")
		quit(0)
	else:
		printerr("  VERDICT: ISSUE DETECTED (Exit Code: 1)")
		print("  Failures:")
		for f in failure_log:
			printerr(f)
		print("==================================================================")
		quit(1)

# ------------------------------------------------------------------------------
# 1. DISTANCE PRECISION CUTOFFS
# Required distances:
#   1.95m -> MUST detect
#   1.99m -> MUST detect
#   2.00m -> MUST detect
#   2.01m -> MUST NOT detect
#   2.05m -> MUST NOT detect
#   3.00m -> MUST NOT detect
# ------------------------------------------------------------------------------
func test_distance_precision() -> bool:
	var world_node = Node3D.new()
	root.add_child(world_node)

	var detector = InteractionDetectorClass.new()
	detector.position = Vector3.ZERO
	world_node.add_child(detector)

	# Thin planar target to test exact surface distance (thickness dz = 0.002m)
	# Half-extent = 0.001m
	var target = InteractableClass.new()
	target.name = "DistanceTarget"
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.5, 0.5, 0.002)
	col.shape = shape
	target.add_child(col)
	world_node.add_child(target)

	var initial_failures = failed_assertions

	# Target surface distance is exactly d when target.position.z = -d - 0.001
	var precision_tests = [
		{ "distance": 1.95, "expected_detect": true,  "label": "1.95m (within 2.0m range)" },
		{ "distance": 1.99, "expected_detect": true,  "label": "1.99m (sub-centimeter margin)" },
		{ "distance": 2.00, "expected_detect": true,  "label": "2.00m (exact cutoff boundary)" },
		{ "distance": 2.01, "expected_detect": false, "label": "2.01m (1cm beyond cutoff)" },
		{ "distance": 2.05, "expected_detect": false, "label": "2.05m (5cm beyond cutoff)" },
		{ "distance": 3.00, "expected_detect": false, "label": "3.00m (1m beyond cutoff)" },
	]

	for pt in precision_tests:
		var d: float = pt["distance"]
		var should_detect: bool = pt["expected_detect"]
		var label: String = pt["label"]

		# Position target so nearest front face is at z = -d
		target.position = Vector3(0.0, 0.0, -d - 0.001)

		for i in range(2):
			await process_frame
			await physics_frame

		detector.update_target()
		var acquired = detector.get_current_target()

		if should_detect:
			assert_not_null(acquired, "Distance %s MUST be detected" % label)
			assert_equal(acquired, target, "Acquired target at %s must match target instance" % label)
			assert_true(detector.has_focused_target(), "has_focused_target() must be true at %s" % label)
		else:
			assert_null(acquired, "Distance %s MUST NOT be detected" % label)
			assert_false(detector.has_focused_target(), "has_focused_target() must be false at %s" % label)

	# Additional sub-millimeter stress test around cutoff: 1.999m vs 2.001m
	target.position = Vector3(0.0, 0.0, -1.999 - 0.001)
	for i in range(2):
		await process_frame
		await physics_frame
	detector.update_target()
	assert_not_null(detector.get_current_target(), "1.999m (sub-millimeter inside) MUST be detected")

	target.position = Vector3(0.0, 0.0, -2.001 - 0.001)
	for i in range(2):
		await process_frame
		await physics_frame
	detector.update_target()
	assert_null(detector.get_current_target(), "2.001m (sub-millimeter outside) MUST NOT be detected")

	world_node.queue_free()
	return failed_assertions == initial_failures

# ------------------------------------------------------------------------------
# 2. MULTI-LAYER WALL OCCLUSION PHYSICS
# Thicknesses required: 0.1m, 1.0m, 5.0m on Layer 1.
# Also test composite multi-wall barriers and verify 100% rejection.
# ------------------------------------------------------------------------------
func test_wall_occlusion_thicknesses() -> bool:
	var world_node = Node3D.new()
	root.add_child(world_node)

	var detector = InteractionDetectorClass.new()
	detector.position = Vector3.ZERO
	world_node.add_child(detector)

	var target = InteractableClass.new()
	target.name = "TargetBehindWall"
	target.position = Vector3(0.0, 0.0, -1.8)
	var col_target = CollisionShape3D.new()
	var shape_target = BoxShape3D.new()
	shape_target.size = Vector3(0.5, 0.5, 0.2)
	col_target.shape = shape_target
	target.add_child(col_target)
	world_node.add_child(target)

	var initial_failures = failed_assertions

	# Baseline: confirm target is detected when unoccluded
	for i in range(2):
		await process_frame
		await physics_frame
	detector.update_target()
	assert_equal(detector.get_current_target(), target, "Baseline: unobstructed target at 1.8m is detected")

	# Thickness cases:
	# Case 2A: Thin wall (0.1m thickness) at z = -0.9
	# Case 2B: Medium wall (1.0m thickness) centered at z = -0.9 (front -0.4, back -1.4)
	# Case 2C: Thick solid obstacle (5.0m thickness) extending from z = -0.2 to z = -5.2
	var thicknesses = [
		{ "thickness": 0.1, "center_z": -0.9, "label": "0.1m thin partition wall" },
		{ "thickness": 1.0, "center_z": -0.9, "label": "1.0m concrete block wall" },
		{ "thickness": 5.0, "center_z": -2.7, "label": "5.0m massive geological rock formation" }
	]

	for tc in thicknesses:
		var th: float = tc["thickness"]
		var cz: float = tc["center_z"]
		var label: String = tc["label"]

		var wall = StaticBody3D.new()
		wall.name = "OcclusionWall"
		wall.collision_layer = 1 # Environment Layer 1
		wall.collision_mask = 1
		wall.position = Vector3(0.0, 0.0, cz)

		var col_wall = CollisionShape3D.new()
		var shape_wall = BoxShape3D.new()
		shape_wall.size = Vector3(3.0, 3.0, th)
		col_wall.shape = shape_wall
		wall.add_child(col_wall)
		world_node.add_child(wall)

		for i in range(2):
			await process_frame
			await physics_frame

		detector.update_target()
		assert_null(detector.get_current_target(), "Occluded by %s: get_current_target() must be null" % label)
		assert_false(detector.has_focused_target(), "Occluded by %s: has_focused_target() must be false" % label)

		var dummy_player = Node3D.new()
		world_node.add_child(dummy_player)
		var interact_res = detector.try_interact(dummy_player)
		assert_false(interact_res, "Occluded by %s: try_interact() must return false" % label)
		dummy_player.queue_free()

		world_node.remove_child(wall)
		wall.queue_free()

		# Verify immediate re-acquisition after wall removal
		for i in range(2):
			await process_frame
			await physics_frame
		detector.update_target()
		assert_equal(detector.get_current_target(), target, "Re-acquisition after %s removal" % label)

	# Case 2D: Multi-wall barrier (2 distinct 0.1m walls in succession: z = -0.6 and z = -1.2)
	var wall1 = StaticBody3D.new()
	wall1.collision_layer = 1
	wall1.position = Vector3(0.0, 0.0, -0.6)
	var c1 = CollisionShape3D.new()
	var s1 = BoxShape3D.new()
	s1.size = Vector3(2.0, 2.0, 0.1)
	c1.shape = s1
	wall1.add_child(c1)
	world_node.add_child(wall1)

	var wall2 = StaticBody3D.new()
	wall2.collision_layer = 1
	wall2.position = Vector3(0.0, 0.0, -1.2)
	var c2 = CollisionShape3D.new()
	var s2 = BoxShape3D.new()
	s2.size = Vector3(2.0, 2.0, 0.1)
	c2.shape = s2
	wall2.add_child(c2)
	world_node.add_child(wall2)

	for i in range(2):
		await process_frame
		await physics_frame

	detector.update_target()
	assert_null(detector.get_current_target(), "Multi-wall (2 layers): target cleanly occluded")
	assert_false(detector.has_focused_target(), "Multi-wall (2 layers): has_focused_target() is false")

	world_node.queue_free()
	return failed_assertions == initial_failures

# ------------------------------------------------------------------------------
# 3. OFF-AXIS ALIGNMENT & ANGULAR LINE OF SIGHT
# Must strictly be forward along line of sight with zero side bleed.
# ------------------------------------------------------------------------------
func test_off_axis_alignment() -> bool:
	var world_node = Node3D.new()
	root.add_child(world_node)

	var detector = InteractionDetectorClass.new()
	detector.position = Vector3.ZERO
	world_node.add_child(detector)

	# Compact target: 0.2m x 0.2m x 0.2m at z = -1.5m
	# Spans x in [-0.1, +0.1], y in [-0.1, +0.1]
	var target = InteractableClass.new()
	target.name = "CompactTarget"
	target.position = Vector3(0.0, 0.0, -1.5)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.2, 0.2, 0.2)
	col.shape = shape
	target.add_child(col)
	world_node.add_child(target)

	var initial_failures = failed_assertions

	# 1. On-axis baseline: exactly along ray (x=0, y=0) -> DETECTED
	for i in range(2):
		await process_frame
		await physics_frame
	detector.update_target()
	assert_equal(detector.get_current_target(), target, "On-axis (x=0, y=0): target detected")

	# 2. Lateral offset X (outside shape bounds [-0.1, +0.1])
	var lateral_offsets = [
		{ "pos": Vector3(0.05, 0.0, -1.5),  "expected": true,  "label": "X=+0.05m (inside shape bounds)" },
		{ "pos": Vector3(0.12, 0.0, -1.5),  "expected": false, "label": "X=+0.12m (just outside right edge)" },
		{ "pos": Vector3(-0.12, 0.0, -1.5), "expected": false, "label": "X=-0.12m (just outside left edge)" },
		{ "pos": Vector3(0.5, 0.0, -1.5),   "expected": false, "label": "X=+0.50m (side flank)" },
		{ "pos": Vector3(-0.5, 0.0, -1.5),  "expected": false, "label": "X=-0.50m (side flank)" },
		{ "pos": Vector3(0.0, 0.12, -1.5),  "expected": false, "label": "Y=+0.12m (just outside top edge)" },
		{ "pos": Vector3(0.0, -0.12, -1.5), "expected": false, "label": "Y=-0.12m (just outside bottom edge)" },
		{ "pos": Vector3(0.0, 0.5, -1.5),   "expected": false, "label": "Y=+0.50m (above eye line)" },
		{ "pos": Vector3(0.0, -0.5, -1.5),  "expected": false, "label": "Y=-0.50m (below eye line)" },
	]

	for lo in lateral_offsets:
		target.position = lo["pos"]
		for i in range(2):
			await process_frame
			await physics_frame
		detector.update_target()
		var hit = detector.get_current_target()
		if lo["expected"]:
			assert_not_null(hit, "Lateral offset %s must be detected" % lo["label"])
		else:
			assert_null(hit, "Lateral offset %s must NOT be detected (zero side bleed)" % lo["label"])

	# 3. Detector orientation / angular rotation test (target fixed at 0, 0, -1.5)
	target.position = Vector3(0.0, 0.0, -1.5)

	# Target spans [-0.1, +0.1] at distance 1.4m (nearest surface)
	# Max angle to hit target: atan(0.1 / 1.4) = ~4.085 degrees
	var angular_tests = [
		{ "yaw": deg_to_rad(0.0),   "pitch": deg_to_rad(0.0),   "expected": true,  "label": "0° center gaze" },
		{ "yaw": deg_to_rad(2.0),   "pitch": deg_to_rad(0.0),   "expected": true,  "label": "+2° slight graze (inside cone)" },
		{ "yaw": deg_to_rad(-2.0),  "pitch": deg_to_rad(0.0),   "expected": true,  "label": "-2° slight graze (inside cone)" },
		{ "yaw": deg_to_rad(6.0),   "pitch": deg_to_rad(0.0),   "expected": false, "label": "+6° yaw off-target" },
		{ "yaw": deg_to_rad(-6.0),  "pitch": deg_to_rad(0.0),   "expected": false, "label": "-6° yaw off-target" },
		{ "yaw": deg_to_rad(15.0),  "pitch": deg_to_rad(0.0),   "expected": false, "label": "+15° yaw glancing" },
		{ "yaw": deg_to_rad(-15.0), "pitch": deg_to_rad(0.0),   "expected": false, "label": "-15° yaw glancing" },
		{ "yaw": deg_to_rad(45.0),  "pitch": deg_to_rad(0.0),   "expected": false, "label": "+45° yaw diagonal" },
		{ "yaw": deg_to_rad(90.0),  "pitch": deg_to_rad(0.0),   "expected": false, "label": "+90° perpendicular lookaway" },
		{ "yaw": deg_to_rad(180.0), "pitch": deg_to_rad(0.0),   "expected": false, "label": "180° complete look-behind" },
		{ "yaw": deg_to_rad(0.0),   "pitch": deg_to_rad(6.0),   "expected": false, "label": "+6° pitch look-up" },
		{ "yaw": deg_to_rad(0.0),   "pitch": deg_to_rad(-6.0),  "expected": false, "label": "-6° pitch look-down" },
		{ "yaw": deg_to_rad(0.0),   "pitch": deg_to_rad(45.0),  "expected": false, "label": "+45° steep look-up" },
		{ "yaw": deg_to_rad(0.0),   "pitch": deg_to_rad(-45.0), "expected": false, "label": "-45° steep look-down" },
	]

	for at in angular_tests:
		detector.rotation = Vector3(at["pitch"], at["yaw"], 0.0)
		for i in range(2):
			await process_frame
			await physics_frame
		detector.update_target()
		var hit = detector.get_current_target()
		if at["expected"]:
			assert_not_null(hit, "Angular gaze %s must detect target" % at["label"])
		else:
			assert_null(hit, "Angular gaze %s must NOT detect target (line of sight preserved)" % at["label"])

	world_node.queue_free()
	return failed_assertions == initial_failures

# ------------------------------------------------------------------------------
# 4. LANDMARK INTERACTABLE REGISTRATION (level_graybox.tscn)
# Verify all 12 key landmarks:
#   - Node exists in scene
#   - Has an Interactable child on Layer 3
#   - collision_mask == 0, monitorable == true
#   - valid prompt text matching Indonesian specification
#   - valid non-empty CollisionShape3D
# ------------------------------------------------------------------------------
func test_landmark_registration() -> bool:
	var initial_failures = failed_assertions

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	assert_not_null(scene_res, "level_graybox.tscn resource loads successfully")
	if scene_res == null:
		return false

	var level = scene_res.instantiate() as Node3D
	assert_not_null(level, "level_graybox.tscn instantiates cleanly")
	if level == null:
		return false

	root.add_child(level)

	var expected_landmarks = {
		"book_family": {
			"interaction_id": "landmark_book",
			"action": "Periksa",
			"target": "Meja Resep",
			"expected_prompt": "[E] Periksa Meja Resep"
		},
		"storage_home": {
			"interaction_id": "landmark_storage",
			"action": "Buka",
			"target": "Peti",
			"expected_prompt": "[E] Buka Peti"
		},
		"station_kitchen_home": {
			"interaction_id": "landmark_kitchen",
			"action": "Periksa",
			"target": "Dapur",
			"expected_prompt": "[E] Periksa Dapur"
		},
		"water_home": {
			"interaction_id": "landmark_water",
			"action": "Ambil",
			"target": "Air",
			"expected_prompt": "[E] Ambil Air"
		},
		"container_starter": {
			"interaction_id": "landmark_starter",
			"action": "Ambil",
			"target": "Wadah Starter",
			"expected_prompt": "[E] Ambil Wadah Starter"
		},
		"reserve_home": {
			"interaction_id": "landmark_reserve",
			"action": "Periksa",
			"target": "Cadangan",
			"expected_prompt": "[E] Periksa Cadangan"
		},
		"resource_jagung_01": {
			"interaction_id": "landmark_jagung",
			"action": "Periksa",
			"target": "Jagung",
			"expected_prompt": "[E] Periksa Jagung"
		},
		"resource_temu_kunci_01": {
			"interaction_id": "landmark_temu_kunci",
			"action": "Periksa",
			"target": "Temu Kunci",
			"expected_prompt": "[E] Periksa Temu Kunci"
		},
		"npc_neighbor_01": {
			"interaction_id": "landmark_neighbor",
			"action": "Bicara",
			"target": "",
			"expected_prompt": "[E] Bicara"
		},
		"note_garden_01": {
			"interaction_id": "landmark_note",
			"action": "Baca",
			"target": "Catatan Kebun",
			"expected_prompt": "[E] Baca Catatan Kebun"
		},
		"plot_home_01": {
			"interaction_id": "landmark_plot",
			"action": "Periksa",
			"target": "Petak",
			"expected_prompt": "[E] Periksa Petak"
		},
		"bed_home": {
			"interaction_id": "landmark_bed",
			"action": "Istirahat",
			"target": "",
			"expected_prompt": "[E] Istirahat"
		}
	}

	for lm_name in expected_landmarks.keys():
		var spec = expected_landmarks[lm_name]
		var lm_node = level.find_child(lm_name, true, false) as Node3D
		assert_not_null(lm_node, "Landmark '%s' exists in graybox scene" % lm_name)
		if lm_node == null:
			continue

		var interactable = lm_node.find_child("Interactable", true, false) as Area3D
		assert_not_null(interactable, "Landmark '%s' has 'Interactable' child" % lm_name)
		if interactable == null:
			continue

		# Layer verification: must be Layer 3 (bit 3 = 4)
		assert_equal(interactable.collision_layer, 4, "Landmark '%s' Interactable is on Layer 3 (bitmask 4)" % lm_name)
		assert_equal(interactable.collision_mask, 0, "Landmark '%s' Interactable collision_mask is 0" % lm_name)
		assert_false(interactable.monitoring, "Landmark '%s' Interactable monitoring is false" % lm_name)
		assert_true(interactable.monitorable, "Landmark '%s' Interactable monitorable is true" % lm_name)

		# State & API verification
		assert_true(interactable.is_enabled(), "Landmark '%s' Interactable is enabled" % lm_name)
		assert_equal(interactable.interaction_id, spec["interaction_id"], "Landmark '%s' interaction_id matches '%s'" % [lm_name, spec["interaction_id"]])
		assert_equal(interactable.get_prompt_text(), spec["expected_prompt"], "Landmark '%s' prompt text matches '%s'" % [lm_name, spec["expected_prompt"]])

		# Collision shape geometry verification
		var col = interactable.find_child("Collision*", true, false) as CollisionShape3D
		if col == null:
			for ch in interactable.get_children():
				if ch is CollisionShape3D:
					col = ch
					break
		assert_not_null(col, "Landmark '%s' Interactable has CollisionShape3D" % lm_name)
		if col != null:
			assert_not_null(col.shape, "Landmark '%s' CollisionShape3D has assigned shape" % lm_name)
			if col.shape is BoxShape3D:
				var box: BoxShape3D = col.shape
				assert_true(box.size.x > 0.1 and box.size.y > 0.1 and box.size.z > 0.1,
					"Landmark '%s' BoxShape3D has positive 3D extents (%s)" % [lm_name, str(box.size)])

	# Test dynamic raycast acquisition in the live level for a landmark (book_family)
	var book_node = level.find_child("book_family", true, false) as Node3D
	assert_not_null(book_node, "book_family node found for live test")
	if book_node != null:
		var detector = InteractionDetectorClass.new()
		level.add_child(detector)
		# Position detector 1.0m south of book_family, facing north (-Z)
		detector.global_position = book_node.global_position + Vector3(0.0, 0.5, 1.0)
		detector.rotation = Vector3.ZERO

		for i in range(3):
			await process_frame
			await physics_frame

		detector.update_target()
		var acquired = detector.get_current_target()
		assert_not_null(acquired, "Live landmark book_family acquired by raycast detector")
		if acquired != null:
			assert_equal(acquired.interaction_id, "landmark_book", "Acquired live landmark is landmark_book")

	level.queue_free()
	return failed_assertions == initial_failures

# ------------------------------------------------------------------------------
# 5. DYNAMIC STATE INVARIANCE & RAPID TOGGLE STRESS
# Verify enable/disable toggling, rapid focus switching, and null safety.
# ------------------------------------------------------------------------------
func test_dynamic_state_invariance() -> bool:
	var world_node = Node3D.new()
	root.add_child(world_node)

	var detector = InteractionDetectorClass.new()
	detector.position = Vector3.ZERO
	world_node.add_child(detector)

	var target1 = InteractableClass.new()
	target1.name = "Target1"
	target1.position = Vector3(0.0, 0.0, -1.2)
	var c1 = CollisionShape3D.new()
	var s1 = BoxShape3D.new()
	s1.size = Vector3(0.5, 0.5, 0.5)
	c1.shape = s1
	target1.add_child(c1)
	world_node.add_child(target1)

	var target2 = InteractableClass.new()
	target2.name = "Target2"
	target2.position = Vector3(0.0, 0.0, -1.8)
	var c2 = CollisionShape3D.new()
	var s2 = BoxShape3D.new()
	s2.size = Vector3(0.5, 0.5, 0.5)
	c2.shape = s2
	target2.add_child(c2)
	world_node.add_child(target2)

	var initial_failures = failed_assertions

	for i in range(2):
		await process_frame
		await physics_frame

	# 1. Target 1 is closest (1.2m), Target 2 is behind it (1.8m)
	# Raycast hits closest target first
	detector.update_target()
	assert_equal(detector.get_current_target(), target1, "Closest target (1.2m) is prioritized over farther target (1.8m)")

	# 2. Disabled Target: when target1 is disabled, target1 still physically blocks the raycast,
	# but candidate.is_enabled() returns false, so detector correctly returns null.
	target1.set_enabled(false)
	detector.update_target()
	assert_null(detector.get_current_target(), "Disabled target does not acquire focus")
	assert_false(detector.has_focused_target(), "has_focused_target() is false on disabled target")

	# 3. Disable collision shape on target1 completely (c1.disabled = true)
	# Now raycast passes through target1 and hits Target 2!
	c1.disabled = true
	for i in range(2):
		await process_frame
		await physics_frame
	detector.update_target()
	assert_equal(detector.get_current_target(), target2, "When front target collision is disabled, ray acquires target2 behind it")

	# 4. Rapid toggle test (100 iterations of enable/disable without leak or crash)
	for k in range(100):
		detector.interaction_enabled = (k % 2 == 0)
		detector.update_target()
	detector.interaction_enabled = true
	detector.update_target()
	assert_equal(detector.get_current_target(), target2, "Target re-acquired cleanly after 100 rapid toggles")

	world_node.queue_free()
	return failed_assertions == initial_failures
