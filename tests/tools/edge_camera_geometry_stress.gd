extends SceneTree

## Edge Camera Geometry Stress Harness — challenger_art_003_1
## Tests crop geometry against extreme edge camera poses:
## 1. Cotyledon upward V-silhouette vector elevation (tip.y > base.y)
## 2. Real geometry extraction from scripts/main.gd (primitives & vertex counts)
## 3. First-person player perspective (1.6m eye height standing, 0.8m crouching at plot)
## 4. Extreme pitch angles (-89.9° nadir to +85° worm's-eye), extreme FOVs (15° to 120°), distances (0.25m to 8.0m)
## 5. Top-down overhead nadir projection area (Stage 1 > Stage 0 across 36 yaw orientations)

const MainScript = preload("res://scripts/main.gd")

func _initialize() -> void:
	print("==================================================")
	print("[EDGE_CAMERA_STRESS] challenger_art_003_1 Extreme Geometry Challenge")
	print("==================================================")

	var failures: int = 0
	var total_checks: int = 0

	var main_inst = MainScript.new()

	# --------------------------------------------------------------------------
	# CHECK 1: Cotyledon Upward V-Silhouette Vector Geometry
	# --------------------------------------------------------------------------
	print("\n--- CHECK 1: Cotyledon Upward V-Silhouette Vector Geometry ---")
	var root_s1 := Node3D.new()
	main_inst._rebuild_crop_stage(root_s1, 1)

	var cot_l = root_s1.get_node_or_null("CotyledonLeft") as MeshInstance3D
	var cot_r = root_s1.get_node_or_null("CotyledonRight") as MeshInstance3D
	var stem = root_s1.get_node_or_null("Stem") as MeshInstance3D

	if cot_l == null or cot_r == null or stem == null:
		print("FAIL: Stage 1 missing required nodes")
		failures += 1
		total_checks += 1
	else:
		var b_mesh_l: BoxMesh = cot_l.mesh as BoxMesh
		var b_mesh_r: BoxMesh = cot_r.mesh as BoxMesh
		var half_w_l: float = b_mesh_l.size.x * 0.5
		var half_w_r: float = b_mesh_r.size.x * 0.5

		# CotyledonLeft extends from base at +half_w_l to tip at -half_w_l in local space
		var tip_l: Vector3 = cot_l.transform * Vector3(-half_w_l, 0, 0)
		var base_l: Vector3 = cot_l.transform * Vector3(half_w_l, 0, 0)

		# CotyledonRight extends from base at -half_w_r to tip at +half_w_r in local space
		var tip_r: Vector3 = cot_r.transform * Vector3(half_w_r, 0, 0)
		var base_r: Vector3 = cot_r.transform * Vector3(-half_w_r, 0, 0)

		print("CotyledonLeft:  tip = %s, base = %s" % [str(tip_l), str(base_l)])
		print("CotyledonRight: tip = %s, base = %s" % [str(tip_r), str(base_r)])

		total_checks += 1
		if tip_l.y > base_l.y:
			print("PASS: CotyledonLeft tip Y (%.4fm) > base Y (%.4fm), delta = +%.4fm" % [tip_l.y, base_l.y, tip_l.y - base_l.y])
		else:
			print("FAIL: CotyledonLeft tip Y (%.4fm) <= base Y (%.4fm) (DROOP)" % [tip_l.y, base_l.y])
			failures += 1

		total_checks += 1
		if tip_r.y > base_r.y:
			print("PASS: CotyledonRight tip Y (%.4fm) > base Y (%.4fm), delta = +%.4fm" % [tip_r.y, base_r.y, tip_r.y - base_r.y])
		else:
			print("FAIL: CotyledonRight tip Y (%.4fm) <= base Y (%.4fm) (DROOP)" % [tip_r.y, base_r.y])
			failures += 1

		# Divergence: tip span must be significantly wider than base span
		var tip_span = tip_l.distance_to(tip_r)
		var base_span = base_l.distance_to(base_r)
		total_checks += 1
		if tip_span > base_span * 1.5:
			print("PASS: Cotyledon V-divergence verified: tip span (%.4fm) > 1.5x base span (%.4fm)" % [tip_span, base_span])
		else:
			print("FAIL: Cotyledon span divergence insufficient: tip span %.4fm vs base span %.4fm" % [tip_span, base_span])
			failures += 1

	root_s1.free()

	# --------------------------------------------------------------------------
	# CHECK 2: Grounded Geometry Extraction from scripts/main.gd
	# --------------------------------------------------------------------------
	print("\n--- CHECK 2: Extracting Real Geometry Vertices from scripts/main.gd ---")
	var stage_vertices: Array[PackedVector3Array] = []
	for stage in range(4):
		var root := Node3D.new()
		main_inst._rebuild_crop_stage(root, stage)
		var verts := PackedVector3Array()

		for child in root.get_children():
			var mi = child as MeshInstance3D
			if mi != null and mi.mesh != null:
				var xform = mi.transform
				var arrays = mi.mesh.get_mesh_arrays()
				if arrays.size() > Mesh.ARRAY_VERTEX:
					var local_verts = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
					for v in local_verts:
						verts.append(xform * v)

		total_checks += 1
		if verts.size() > 50:
			print("PASS: Stage %d extracted %d real mesh vertices (primitives: %d)" % [stage, verts.size(), root.get_child_count()])
		else:
			print("FAIL: Stage %d vertex count too low: %d" % [stage, verts.size()])
			failures += 1

		stage_vertices.append(verts)
		root.free()

	# --------------------------------------------------------------------------
	# CHECK 3: First-Person Player Viewpoint Stress (Standing 1.6m & Crouching 0.8m)
	# --------------------------------------------------------------------------
	print("\n--- CHECK 3: First-Person Player Viewing Distance & Angle Stress ---")
	var player_stances = [
		{"name": "Standing Close (0.5m)", "eye_y": 1.6, "dist_xz": 0.5},
		{"name": "Standing Normal Interaction (0.8m)", "eye_y": 1.6, "dist_xz": 0.8},
		{"name": "Standing Garden Walk (1.2m)", "eye_y": 1.6, "dist_xz": 1.2},
		{"name": "Standing Garden Perimeter (1.8m)", "eye_y": 1.6, "dist_xz": 1.8},
		{"name": "Standing Max Interaction (2.0m)", "eye_y": 1.6, "dist_xz": 2.0},
		{"name": "Crouching Inspection (0.4m)", "eye_y": 0.8, "dist_xz": 0.4},
		{"name": "Crouching Normal (0.8m)", "eye_y": 0.8, "dist_xz": 0.8},
		{"name": "Crouching Reach (1.5m)", "eye_y": 0.8, "dist_xz": 1.5},
	]

	var player_yaws = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
	var player_fovs = [60.0, 75.0, 90.0, 100.0]

	var fp_poses := 0
	var fp_aabb_passes := 0
	var fp_hull_passes := 0
	var fp_height_passes := 0

	for stance in player_stances:
		var eye_y: float = stance["eye_y"]
		var dist_xz: float = stance["dist_xz"]
		var pitch_rad: float = -atan2(eye_y - 0.2, dist_xz)
		var pitch_deg: float = rad_to_deg(pitch_rad)
		var total_dist: float = sqrt(dist_xz * dist_xz + (eye_y - 0.2) * (eye_y - 0.2))

		for fov in player_fovs:
			var focal_y = 1.0 / tan(deg_to_rad(fov) * 0.5)
			var aspect = 16.0 / 9.0
			var focal_x = focal_y / aspect

			for yaw_deg in player_yaws:
				fp_poses += 1
				var yaw_rad = deg_to_rad(yaw_deg)
				var target = Vector3(0.0, 0.2, 0.0)

				var cam_x = target.x + total_dist * cos(pitch_rad) * sin(yaw_rad)
				var cam_y = target.y - total_dist * sin(pitch_rad)
				var cam_z = target.z + total_dist * cos(pitch_rad) * cos(yaw_rad)
				var cam_pos = Vector3(cam_x, cam_y, cam_z)

				var forward = (target - cam_pos).normalized()
				var up_ref = Vector3.UP
				var right = forward.cross(up_ref).normalized()
				var up = right.cross(forward).normalized()
				var cam_basis = Basis(right, up, -forward)
				var cam_transform = Transform3D(cam_basis, cam_pos)
				var inv_view = cam_transform.affine_inverse()

				var stage_h: Array[float] = []
				var stage_aabb: Array[float] = []
				var stage_hull: Array[float] = []

				for s in range(4):
					var pts = stage_vertices[s]
					var min_2d := Vector2(INF, INF)
					var max_2d := Vector2(-INF, -INF)
					var pts_2d: Array[Vector2] = []

					for v in pts:
						var p_cam = inv_view * v
						var z = -p_cam.z
						if z <= 0.01:
							continue
						var p2 = Vector2(
							(p_cam.x * focal_x / z) * 960.0 + 960.0,
							-(p_cam.y * focal_y / z) * 540.0 + 540.0
						)
						pts_2d.append(p2)
						min_2d.x = minf(min_2d.x, p2.x)
						min_2d.y = minf(min_2d.y, p2.y)
						max_2d.x = maxf(max_2d.x, p2.x)
						max_2d.y = maxf(max_2d.y, p2.y)

					var h_2d = maxf(0.0, max_2d.y - min_2d.y)
					var w_2d = maxf(0.0, max_2d.x - min_2d.x)
					var aabb_area = w_2d * h_2d
					var hull_area = _compute_convex_hull_area_2d(pts_2d)

					stage_h.append(h_2d)
					stage_aabb.append(aabb_area)
					stage_hull.append(hull_area)

				var h_mono := true
				var aabb_mono := true
				var hull_mono := true
				for s in range(3):
					if stage_h[s+1] <= stage_h[s]:
						h_mono = false
					if stage_aabb[s+1] <= stage_aabb[s]:
						aabb_mono = false
					if stage_hull[s+1] <= stage_hull[s]:
						hull_mono = false

				if h_mono:
					fp_height_passes += 1
				if aabb_mono:
					fp_aabb_passes += 1
				if hull_mono:
					fp_hull_passes += 1

	print("Tested %d first-person player camera poses across 8 stances, 4 FOVs, 8 Yaws:" % fp_poses)
	print("  - Height Monotonicity:      %d / %d (%.1f%%)" % [fp_height_passes, fp_poses, (float(fp_height_passes)/fp_poses)*100.0])
	print("  - 2D Bounding Area Mono:   %d / %d (%.1f%%)" % [fp_aabb_passes, fp_poses, (float(fp_aabb_passes)/fp_poses)*100.0])
	print("  - Convex Hull Area Mono:   %d / %d (%.1f%%)" % [fp_hull_passes, fp_poses, (float(fp_hull_passes)/fp_poses)*100.0])

	total_checks += 3
	if fp_height_passes == fp_poses:
		print("PASS: First-person height is 100% strictly monotonic.")
	else:
		print("FAIL: First-person height failure in %d poses" % (fp_poses - fp_height_passes))
		failures += 1

	if fp_aabb_passes == fp_poses:
		print("PASS: First-person 2D Bounding Area is 100% strictly monotonic.")
	else:
		print("FAIL: First-person 2D Bounding Area failure in %d poses" % (fp_poses - fp_aabb_passes))
		failures += 1

	if fp_hull_passes == fp_poses:
		print("PASS: First-person Convex Hull Area is 100% strictly monotonic.")
	else:
		print("FAIL: First-person Convex Hull Area failure in %d poses" % (fp_poses - fp_hull_passes))
		failures += 1

	# --------------------------------------------------------------------------
	# CHECK 4: Terrestrial Extreme Camera Poses (Y >= 0.0m Above Ground)
	# --------------------------------------------------------------------------
	print("\n--- CHECK 4: Terrestrial Extreme Pitch, FOV, and Distance Stress (Y >= 0.0m) ---")
	var extreme_pitches: Array[float] = [-89.5, -85.0, -75.0, -45.0, -15.0, 0.0, 15.0, 45.0, 75.0, 85.0]
	var fine_yaws: Array[float] = []
	for y in range(0, 360, 15):
		fine_yaws.append(float(y))

	var extreme_fovs: Array[float] = [15.0, 30.0, 60.0, 75.0, 90.0, 105.0, 120.0]
	var extreme_dists: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0]

	var terr_total := 0
	var terr_aabb_passes := 0
	var terr_hull_passes := 0
	var terr_height_passes := 0
	var terr_height_candidates := 0

	var sub_total := 0
	var sub_aabb_passes := 0

	for fov in extreme_fovs:
		var focal_y = 1.0 / tan(deg_to_rad(fov) * 0.5)
		var aspect = 16.0 / 9.0
		var focal_x = focal_y / aspect

		for dist in extreme_dists:
			for pitch_deg in extreme_pitches:
				for yaw_deg in fine_yaws:
					var yaw_rad = deg_to_rad(yaw_deg)
					var pitch_rad = deg_to_rad(pitch_deg)
					var target = Vector3(0.0, 0.2, 0.0)

					var cam_x = target.x + dist * cos(pitch_rad) * sin(yaw_rad)
					var cam_y = target.y - dist * sin(pitch_rad)
					var cam_z = target.z + dist * cos(pitch_rad) * cos(yaw_rad)
					var cam_pos = Vector3(cam_x, cam_y, cam_z)

					var is_terrestrial: bool = (cam_pos.y >= 0.0)

					var forward = (target - cam_pos).normalized()
					var up_ref = Vector3.UP if abs(pitch_deg) < 85.0 else Vector3.FORWARD
					var right = forward.cross(up_ref).normalized()
					var up = right.cross(forward).normalized()
					var cam_basis = Basis(right, up, -forward)
					var cam_transform = Transform3D(cam_basis, cam_pos)
					var inv_view = cam_transform.affine_inverse()

					var stage_h: Array[float] = []
					var stage_aabb: Array[float] = []
					var stage_hull: Array[float] = []

					for s in range(4):
						var pts = stage_vertices[s]
						var min_2d := Vector2(INF, INF)
						var max_2d := Vector2(-INF, -INF)
						var pts_2d: Array[Vector2] = []

						for v in pts:
							var p_cam = inv_view * v
							var z = -p_cam.z
							if z <= 0.01:
								continue
							var p2 = Vector2(
								(p_cam.x * focal_x / z) * 960.0 + 960.0,
								-(p_cam.y * focal_y / z) * 540.0 + 540.0
							)
							pts_2d.append(p2)
							min_2d.x = minf(min_2d.x, p2.x)
							min_2d.y = minf(min_2d.y, p2.y)
							max_2d.x = maxf(max_2d.x, p2.x)
							max_2d.y = maxf(max_2d.y, p2.y)

						var h_2d = maxf(0.0, max_2d.y - min_2d.y)
						var w_2d = maxf(0.0, max_2d.x - min_2d.x)
						var aabb_area = w_2d * h_2d
						var hull_area = _compute_convex_hull_area_2d(pts_2d)

						stage_h.append(h_2d)
						stage_aabb.append(aabb_area)
						stage_hull.append(hull_area)

					var aabb_mono := true
					var hull_mono := true
					for s in range(3):
						if stage_aabb[s+1] <= stage_aabb[s]:
							aabb_mono = false
						if stage_hull[s+1] <= stage_hull[s]:
							hull_mono = false

					if is_terrestrial:
						terr_total += 1
						if aabb_mono:
							terr_aabb_passes += 1
						if hull_mono:
							terr_hull_passes += 1

						if abs(pitch_deg) < 75.0:
							terr_height_candidates += 1
							var h_mono := true
							for s in range(3):
								if stage_h[s+1] <= stage_h[s]:
									h_mono = false
							if h_mono:
								terr_height_passes += 1
					else:
						sub_total += 1
						if aabb_mono:
							sub_aabb_passes += 1

	print("Tested %d terrestrial camera poses (cam_pos.y >= 0.0m above ground):" % terr_total)
	print("  - 2D Bounding Area Mono: %d / %d (%.2f%%)" % [terr_aabb_passes, terr_total, (float(terr_aabb_passes)/terr_total)*100.0])
	print("  - Convex Hull Area Mono: %d / %d (%.2f%%)" % [terr_hull_passes, terr_total, (float(terr_hull_passes)/terr_total)*100.0])
	print("  - Height Mono (|pitch|<75°): %d / %d (%.2f%%)" % [terr_height_passes, terr_height_candidates, (float(terr_height_passes)/terr_height_candidates)*100.0])

	total_checks += 3
	if terr_aabb_passes == terr_total:
		print("PASS: Terrestrial 2D Bounding Area is 100% strictly monotonic across ALL %d reachable poses!" % terr_total)
	else:
		print("FAIL: Terrestrial 2D Bounding Area failed in %d poses" % (terr_total - terr_aabb_passes))
		failures += 1

	if terr_hull_passes == terr_total:
		print("PASS: Terrestrial Convex Hull Silhouette Area is 100% strictly monotonic across ALL %d reachable poses!" % terr_total)
	else:
		print("FAIL: Terrestrial Convex Hull Area failed in %d poses" % (terr_total - terr_hull_passes))
		failures += 1

	if terr_height_passes == terr_height_candidates:
		print("PASS: Terrestrial Height is 100% strictly monotonic across all %d non-overhead reachable poses!" % terr_height_candidates)
	else:
		print("FAIL: Terrestrial Height failed in %d poses" % (terr_height_candidates - terr_height_passes))
		failures += 1

	print("Subterranean Boundary Investigation: %d poses tested underground (cam_pos.y < 0): %d passed" % [sub_total, sub_aabb_passes])

	# --------------------------------------------------------------------------
	# CHECK 5: Top-Down Overhead View (Nadir pitch = -89.9°) Area Check (Stage 0 vs Stage 1)
	# --------------------------------------------------------------------------
	print("\n--- CHECK 5: Stage 0 vs Stage 1 Top-Down Projection Ratio Stress ---")
	var nadir_passes := 0
	var nadir_checks := 36
	for y in range(nadir_checks):
		var yaw_deg = float(y * 10)
		var yaw_rad = deg_to_rad(yaw_deg)
		var pitch_rad = deg_to_rad(-89.9)
		var dist = 1.5
		var target = Vector3(0.0, 0.2, 0.0)

		var cam_x = target.x + dist * cos(pitch_rad) * sin(yaw_rad)
		var cam_y = target.y - dist * sin(pitch_rad)
		var cam_z = target.z + dist * cos(pitch_rad) * cos(yaw_rad)
		var cam_pos = Vector3(cam_x, cam_y, cam_z)

		var forward = (target - cam_pos).normalized()
		var up_ref = Vector3.FORWARD
		var right = forward.cross(up_ref).normalized()
		var up = right.cross(forward).normalized()
		var cam_basis = Basis(right, up, -forward)
		var cam_transform = Transform3D(cam_basis, cam_pos)
		var inv_view = cam_transform.affine_inverse()

		var focal = 1.0 / tan(deg_to_rad(75.0) * 0.5)
		var focal_x = focal / (16.0 / 9.0)
		var focal_y = focal

		var s0_pts = stage_vertices[0]
		var s1_pts = stage_vertices[1]

		var s0_2d: Array[Vector2] = []
		var s1_2d: Array[Vector2] = []

		for v in s0_pts:
			var pc = inv_view * v
			var z = -pc.z
			if z > 0.01:
				s0_2d.append(Vector2((pc.x * focal_x / z) * 960.0 + 960.0, -(pc.y * focal_y / z) * 540.0 + 540.0))
		for v in s1_pts:
			var pc = inv_view * v
			var z = -pc.z
			if z > 0.01:
				s1_2d.append(Vector2((pc.x * focal_x / z) * 960.0 + 960.0, -(pc.y * focal_y / z) * 540.0 + 540.0))

		var s0_area = _compute_convex_hull_area_2d(s0_2d)
		var s1_area = _compute_convex_hull_area_2d(s1_2d)

		if s1_area > s0_area:
			nadir_passes += 1

	total_checks += 1
	if nadir_passes == nadir_checks:
		print("PASS: Stage 1 convex hull area > Stage 0 area across all %d top-down yaw orientations (100%%)" % nadir_checks)
	else:
		print("FAIL: Top-down nadir area failed in %d / %d orientations" % [nadir_checks - nadir_passes, nadir_checks])
		failures += 1

	main_inst.free()

	print("\n==================================================")
	print("[EDGE_CAMERA_STRESS] SUMMARY:")
	print("  Total Checks Executed: %d" % total_checks)
	print("  Failures Encountered:  %d" % failures)
	if failures == 0:
		print("  VERDICT: ALL REACHABLE EDGE CAMERA STRESS TESTS PASSED (APPROVE)")
		print("==================================================")
		quit(0)
	else:
		print("  VERDICT: EDGE CAMERA STRESS TESTS FAILED (REJECT)")
		print("==================================================")
		quit(1)

func _compute_convex_hull_area_2d(points: Array[Vector2]) -> float:
	if points.size() < 3:
		return 0.0

	var sorted_pts = points.duplicate()
	sorted_pts.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y
	)

	var lower: Array[Vector2] = []
	for p in sorted_pts:
		while lower.size() >= 2 and _cross_2d(lower[lower.size() - 2], lower[lower.size() - 1], p) <= 0.0:
			lower.pop_back()
		lower.append(p)

	var upper: Array[Vector2] = []
	for i in range(sorted_pts.size() - 1, -1, -1):
		var p = sorted_pts[i]
		while upper.size() >= 2 and _cross_2d(upper[upper.size() - 2], upper[upper.size() - 1], p) <= 0.0:
			upper.pop_back()
		upper.append(p)

	lower.pop_back()
	upper.pop_back()
	var hull = lower + upper

	var area := 0.0
	var n = hull.size()
	for i in range(n):
		var j = (i + 1) % n
		area += hull[i].x * hull[j].y
		area -= hull[j].x * hull[i].y
	return absf(area) * 0.5

func _cross_2d(o: Vector2, a: Vector2, b: Vector2) -> float:
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
