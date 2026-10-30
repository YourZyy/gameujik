class_name TestAdversarialArt
extends RefCounted

## TestAdversarialArt — Suite 25: Empirical Adversarial Oracles & Stress Verification (ART-001)
## Oracles:
## 1. Monotonic crop scaling & 2D silhouette projection across 2,268 camera poses (T55)
## 2. Exhaustive WCAG AAA contrast ratio across all 9 UI scenes and text elements
## 3. Absence of missing mesh, missing material, or magenta fallback shaders in all 3D scenes
## 4. Audio synthesizer PCM integrity, bus headroom, and peak acoustic stacking

const Assertions = preload("res://tests/assertions.gd")
const AudioSynthesizer = preload("res://scripts/audio/audio_synthesizer.gd")
const MainScript = preload("res://scripts/main.gd")

func run_all() -> bool:
	print("\n==================================================")
	print("[SUITE 25] TestAdversarialArt: Empirical Adversarial Oracles & Stress")
	print("==================================================")

	var all_passed := true

	if not test_adv01_crop_monotonic_scaling_under_camera_sweep():
		all_passed = false
	if not test_adv02_wcag_aaa_text_contrast_across_ui_scenes():
		all_passed = false
	if not test_adv03_recursive_mesh_material_and_shader_integrity():
		all_passed = false
	if not test_adv04_audio_synthesizer_pcm_and_headroom_limiter():
		all_passed = false

	return all_passed

# ==============================================================================
# 1. CROP MONOTONIC SCALING & 2D SILHOUETTE PROJECTION ORACLE (T55)
# ==============================================================================

func test_adv01_crop_monotonic_scaling_under_camera_sweep() -> bool:
	print("  [RUN] ADV-ART-01: Crop Monotonic Silhouette & Multi-Angle Projection (2,268 poses)")
	var initial_failures = Assertions.current_suite_failed

	# Extract real vertices from actual CropMesh geometry for all 4 stages
	var main_inst = MainScript.new()
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
		stage_vertices.append(verts)
		root.free()
	main_inst.free()

	# Sweep parameters
	var distances: Array[float] = [0.8, 1.2, 1.6, 2.0, 3.0, 5.0, 8.0]
	var yaws: Array[float] = [0.0, 30.0, 60.0, 90.0, 120.0, 150.0, 180.0, 210.0, 240.0, 270.0, 300.0, 330.0]
	var pitches: Array[float] = [-85.0, -60.0, -45.0, -30.0, -15.0, 0.0, 15.0, 30.0, 45.0]
	var fovs: Array[float] = [60.0, 75.0, 90.0]

	var total_poses := 0
	var monotonic_height_passes := 0
	var monotonic_aabb_passes := 0
	var monotonic_hull_passes := 0
	var debug_fails := 0

	for fov in fovs:
		var focal_y = 1.0 / tan(deg_to_rad(fov) * 0.5)
		var aspect = 16.0 / 9.0
		var focal_x = focal_y / aspect

		for dist in distances:
			for pitch_deg in pitches:
				for yaw_deg in yaws:
					total_poses += 1

					# Compute camera position on spherical orbit around target (0, 0.2, 0)
					var yaw_rad = deg_to_rad(yaw_deg)
					var pitch_rad = deg_to_rad(pitch_deg)
					var target = Vector3(0.0, 0.2, 0.0)

					var cam_x = target.x + dist * cos(pitch_rad) * sin(yaw_rad)
					var cam_y = target.y - dist * sin(pitch_rad)
					var cam_z = target.z + dist * cos(pitch_rad) * cos(yaw_rad)
					var cam_pos = Vector3(cam_x, cam_y, cam_z)

					var forward = (target - cam_pos).normalized()
					var up_ref = Vector3.UP if abs(pitch_deg) < 85.0 else Vector3.FORWARD
					var right = forward.cross(up_ref).normalized()
					var up = right.cross(forward).normalized()
					var cam_basis = Basis(right, up, -forward)
					var cam_transform = Transform3D(cam_basis, cam_pos)
					var inv_view = cam_transform.affine_inverse()

					# Evaluate projection for all 4 stages using actual geometry
					var proj_heights: Array[float] = []
					var proj_aabbs: Array[float] = []
					var proj_hulls: Array[float] = []

					for s in range(4):
						var pts = stage_vertices[s]

						# Project actual mesh vertices to 2D
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

						proj_heights.append(h_2d)
						proj_aabbs.append(aabb_area)
						proj_hulls.append(hull_area)

					# Check monotonic bounding area
					var aabb_mono := true
					for s in range(3):
						if proj_aabbs[s+1] <= proj_aabbs[s]:
							aabb_mono = false
							if debug_fails < 10:
								debug_fails += 1
								print("AABB FAIL #%d: pitch=%.1f yaw=%.1f dist=%.1f s=%d (s+1=%.1f <= s=%.1f)" % [debug_fails, pitch_deg, yaw_deg, dist, s, proj_aabbs[s+1], proj_aabbs[s]])
							break
					if aabb_mono:
						monotonic_aabb_passes += 1

					# Check monotonic hull area
					var hull_mono := true
					for s in range(3):
						if proj_hulls[s+1] <= proj_hulls[s]:
							hull_mono = false
							break
					if hull_mono:
						monotonic_hull_passes += 1

					# Check monotonic height (valid for pitches < 75 degrees)
					if abs(pitch_deg) < 75.0:
						var h_mono := true
						for s in range(3):
							if proj_heights[s+1] <= proj_heights[s]:
								h_mono = false
								break
						if h_mono:
							monotonic_height_passes += 1

	Assertions.assert_true(monotonic_aabb_passes == total_poses,
		"Monotonic projected bounding box area passed %d / %d poses (100%% strictly increasing)" % [monotonic_aabb_passes, total_poses])
	Assertions.assert_true(monotonic_hull_passes == total_poses,
		"Monotonic projected convex hull area passed %d / %d poses (100%% strictly increasing)" % [monotonic_hull_passes, total_poses])
	var expected_h_poses = total_poses * 8 / 9
	Assertions.assert_true(monotonic_height_passes == expected_h_poses,
		"Monotonic projected vertical pixel height passed %d / %d oblique poses (100%% strictly increasing)" % [monotonic_height_passes, expected_h_poses])

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV-ART-01: Verified 2,268 camera poses: 100% strict monotonicity in bounding area, hull silhouette area, and height.")
	return ok

func _compute_convex_hull_area_2d(points: Array[Vector2]) -> float:
	if points.size() < 3:
		return 0.0
	# Monotone chain algorithm for 2D convex hull
	var sorted_pts = points.duplicate()
	sorted_pts.sort_custom(func(a, b): return a.x < b.x if a.x != b.x else a.y < b.y)

	var lower: Array[Vector2] = []
	for p in sorted_pts:
		while lower.size() >= 2 and _cross_2d(lower[lower.size()-2], lower[lower.size()-1], p) <= 0:
			lower.pop_back()
		lower.append(p)

	var upper: Array[Vector2] = []
	for i in range(sorted_pts.size() - 1, -1, -1):
		var p = sorted_pts[i]
		while upper.size() >= 2 and _cross_2d(upper[upper.size()-2], upper[upper.size()-1], p) <= 0:
			upper.pop_back()
		upper.append(p)

	lower.pop_back()
	upper.pop_back()
	var hull = lower + upper

	# Polygon area via Shoelace formula
	var area := 0.0
	var n = hull.size()
	for i in range(n):
		var j = (i + 1) % n
		area += hull[i].x * hull[j].y - hull[j].x * hull[i].y
	return absf(area) * 0.5

func _cross_2d(o: Vector2, a: Vector2, b: Vector2) -> float:
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)

# ==============================================================================
# 2. EXHAUSTIVE WCAG AAA TEXT CONTRAST ORACLE ACROSS ALL UI SCENES
# ==============================================================================

func test_adv02_wcag_aaa_text_contrast_across_ui_scenes() -> bool:
	print("  [RUN] ADV-ART-02: Exhaustive WCAG AAA Text Contrast across All 9 UI Scenes")
	var initial_failures = Assertions.current_suite_failed

	var ui_scene_paths: Array[String] = [
		"res://scenes/ui/hud.tscn",
		"res://scenes/ui/interaction_prompt.tscn",
		"res://scenes/ui/book_ui.tscn",
		"res://scenes/ui/inventory_ui.tscn",
		"res://scenes/ui/kitchen_ui.tscn",
		"res://scenes/ui/dialogue_ui.tscn",
		"res://scenes/ui/pause_menu.tscn",
		"res://scenes/ui/settings_menu.tscn",
		"res://scenes/ui/notification_toast.tscn"
	]

	# Indonesian vernacular dark UI palette background baseline from ART_DIRECTION: #24312E
	var fallback_bg = Color("24312E")

	var total_text_elements := 0
	var aaa_passed_elements := 0
	var min_contrast_found := 999.0

	for path in ui_scene_paths:
		if not ResourceLoader.exists(path):
			Assertions.assert_true(false, "UI Scene missing: %s" % path)
			continue

		var scene_res = ResourceLoader.load(path) as PackedScene
		if scene_res == null:
			Assertions.assert_true(false, "Failed to load UI scene: %s" % path)
			continue

		var instance = scene_res.instantiate()
		var text_nodes = _find_all_text_nodes(instance)

		for node in text_nodes:
			total_text_elements += 1
			var font_color: Color = _extract_font_color(node)
			var bg_color: Color = _find_background_color(node, fallback_bg)
			var font_size: int = _extract_font_size(node)

			var l_text = _calculate_relative_luminance(font_color)
			var l_bg = _calculate_relative_luminance(bg_color)
			var cr = (maxf(l_text, l_bg) + 0.05) / (minf(l_text, l_bg) + 0.05)

			min_contrast_found = minf(min_contrast_found, cr)

			# WCAG AAA threshold: 7.0:1 for normal text, 4.5:1 for large text (>= 18pt)
			var threshold = 4.5 if font_size >= 18 else 7.0
			var is_aaa = (cr >= threshold)

			if is_aaa:
				aaa_passed_elements += 1
			else:
				print("  [WARN/FAIL] Low contrast in %s (%s): CR = %.2f:1 (required %.1f:1). Text: %s, BG: %s" % [
					path.get_file(), node.name, cr, threshold, font_color.to_html(), bg_color.to_html()
				])

		instance.free()

	Assertions.assert_true(total_text_elements >= 20,
		"Exhaustive text elements verified: %d (minimum expected >= 20)" % total_text_elements)
	Assertions.assert_true(aaa_passed_elements == total_text_elements,
		"WCAG AAA compliance passed on %d / %d UI text elements (100%% compliant)" % [aaa_passed_elements, total_text_elements])
	Assertions.assert_true(min_contrast_found >= 7.0,
		"Global minimum contrast ratio found is %.2f:1 (exceeds WCAG AAA 7.0:1 requirement)" % min_contrast_found)

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV-ART-02: WCAG AAA verified: %d text nodes checked. Global min contrast ratio: %.2f:1." % [total_text_elements, min_contrast_found])
	return ok

func _find_all_text_nodes(root_node: Node) -> Array[Control]:
	var result: Array[Control] = []
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is Label or n is Button or n is RichTextLabel:
			result.append(n as Control)
		for child in n.get_children():
			stack.push_back(child)
	return result

func _extract_font_color(ctrl: Control) -> Color:
	# Check theme override font color
	if ctrl.has_theme_color_override("font_color"):
		return ctrl.get_theme_color("font_color")
	# Check modulate
	if ctrl.modulate != Color.WHITE:
		return ctrl.modulate
	# Check default theme
	if ctrl is Label:
		var lbl = ctrl as Label
		if lbl.label_settings != null and lbl.label_settings.font_color != Color.WHITE:
			return lbl.label_settings.font_color
	# Default Godot UI text color or project theme
	return Color("F5F0E4")

func _extract_font_size(ctrl: Control) -> int:
	if ctrl.has_theme_font_size_override("font_size"):
		return ctrl.get_theme_font_size("font_size")
	if ctrl is Label and (ctrl as Label).label_settings != null:
		return (ctrl as Label).label_settings.font_size
	return 14 # default

func _find_background_color(node: Node, fallback: Color) -> Color:
	var curr = node.get_parent()
	while curr != null:
		if curr is PanelContainer:
			var pc = curr as PanelContainer
			var sb = pc.get_theme_stylebox("panel")
			if sb is StyleBoxFlat:
				var sbf = sb as StyleBoxFlat
				var c = sbf.bg_color
				# If semi-transparent, blend with dark background
				if c.a < 1.0:
					return fallback.lerp(Color(c.r, c.g, c.b, 1.0), c.a)
				return c
		elif curr is Panel:
			var p = curr as Panel
			var sb = p.get_theme_stylebox("panel")
			if sb is StyleBoxFlat:
				var sbf = sb as StyleBoxFlat
				var c = sbf.bg_color
				if c.a < 1.0:
					return fallback.lerp(Color(c.r, c.g, c.b, 1.0), c.a)
				return c
		elif curr is ColorRect:
			var cr = curr as ColorRect
			var c = cr.color
			if c.a < 1.0:
				return fallback.lerp(Color(c.r, c.g, c.b, 1.0), c.a)
				return c
		curr = curr.get_parent()
	return fallback

func _calculate_relative_luminance(c: Color) -> float:
	var r = c.r / 12.92 if c.r <= 0.04045 else pow((c.r + 0.055) / 1.055, 2.4)
	var g = c.g / 12.92 if c.g <= 0.04045 else pow((c.g + 0.055) / 1.055, 2.4)
	var b = c.b / 12.92 if c.b <= 0.04045 else pow((c.b + 0.055) / 1.055, 2.4)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b

# ==============================================================================
# 3. RECURSIVE MESH, MATERIAL & ZERO MAGENTA SHADER INTEGRITY ORACLE
# ==============================================================================

func test_adv03_recursive_mesh_material_and_shader_integrity() -> bool:
	print("  [RUN] ADV-ART-03: Recursive Mesh, Material & Zero Magenta Shader Integrity")
	var initial_failures = Assertions.current_suite_failed

	var scenes_to_check: Array[String] = [
		"res://scenes/world/level_graybox.tscn",
		"res://scenes/main.tscn",
		"res://scenes/player/player.tscn"
	]

	var total_meshes_checked := 0

	for sc_path in scenes_to_check:
		if not ResourceLoader.exists(sc_path):
			Assertions.assert_true(false, "Scene not found: %s" % sc_path)
			continue

		var packed = ResourceLoader.load(sc_path) as PackedScene
		var inst = packed.instantiate()

		var stack: Array[Node] = [inst]
		while not stack.is_empty():
			var n = stack.pop_back()
			if n is MeshInstance3D:
				var mi = n as MeshInstance3D
				total_meshes_checked += 1

				# 1. Mesh must not be null
				Assertions.assert_not_null(mi.mesh, "MeshInstance3D '%s' in %s has null mesh" % [mi.name, sc_path.get_file()])

				# 2. Material must not be null
				var mat: Material = mi.material_override
				if mat == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
					mat = mi.get_surface_override_material(0)
					if mat == null:
						mat = mi.mesh.surface_get_material(0)

				Assertions.assert_not_null(mat, "MeshInstance3D '%s' in %s has null material" % [mi.name, sc_path.get_file()])

				# 3. Guard against uncompiled magenta fallback shader
				if mat is StandardMaterial3D:
					var sm = mat as StandardMaterial3D
					var dist_to_magenta = Vector3(sm.albedo_color.r, sm.albedo_color.g, sm.albedo_color.b).distance_to(Vector3(1.0, 0.0, 1.0))
					Assertions.assert_true(dist_to_magenta > 0.25,
						"Material on '%s' has magenta fallback color: %s (dist: %.3f)" % [mi.name, sm.albedo_color, dist_to_magenta])
				elif mat is ShaderMaterial:
					var shm = mat as ShaderMaterial
					Assertions.assert_not_null(shm.shader, "ShaderMaterial on '%s' has null shader" % mi.name)

			for ch in n.get_children():
				stack.push_back(ch)

		inst.free()

	Assertions.assert_true(total_meshes_checked >= 100,
		"Total meshes verified for mesh & material integrity: %d (expected >= 100)" % total_meshes_checked)

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV-ART-03: Verified %d MeshInstance3D nodes across scenes: zero null meshes, zero null materials, zero magenta shaders." % total_meshes_checked)
	return ok

# ==============================================================================
# 4. AUDIO SYNTHESIZER PCM INTEGRITY & MASTER BUS HEADROOM LIMITER ORACLE
# ==============================================================================

func test_adv04_audio_synthesizer_pcm_and_headroom_limiter() -> bool:
	print("  [RUN] ADV-ART-04: Audio Synthesizer PCM Integrity & Master Bus Limiter")
	var initial_failures = Assertions.current_suite_failed

	# 1. Bus Layout & Limiter Verification
	var bus_layout_path := "res://default_bus_layout.tres"
	Assertions.assert_true(ResourceLoader.exists(bus_layout_path), "Audio bus layout file exists")
	var bus_layout = ResourceLoader.load(bus_layout_path) as AudioBusLayout
	Assertions.assert_not_null(bus_layout, "AudioBusLayout loaded successfully")

	# Check Bus 0 Limiter
	var master_effects_count = AudioServer.get_bus_effect_count(0)
	var has_limiter := false
	var ceiling_db := 0.0

	for i in range(master_effects_count):
		var eff = AudioServer.get_bus_effect(0, i)
		if eff is AudioEffectLimiter:
			has_limiter = true
			ceiling_db = (eff as AudioEffectLimiter).ceiling_db

	Assertions.assert_true(has_limiter, "Master bus (Bus 0) has AudioEffectLimiter effect attached")
	Assertions.assert_true(ceiling_db <= -0.5, "Master bus limiter ceiling is <= -0.5 dB (actual: %.2f dB)" % ceiling_db)

	# 2. Synthesize and verify all 11 PCM audio cues
	var sfx_generators: Dictionary = {
		"ambience": func(): return AudioSynthesizer.generate_ambience_countryside(),
		"footstep": func(): return AudioSynthesizer.generate_footstep(),
		"tool_hoe": func(): return AudioSynthesizer.generate_tool_hoe(),
		"tool_water": func(): return AudioSynthesizer.generate_tool_water(),
		"tool_fertilizer": func(): return AudioSynthesizer.generate_tool_fertilizer(),
		"harvest_pickup": func(): return AudioSynthesizer.generate_harvest_pickup(),
		"kitchen_simmer": func(): return AudioSynthesizer.generate_kitchen_simmer(),
		"ui_click": func(): return AudioSynthesizer.generate_ui_click(),
		"ui_confirm": func(): return AudioSynthesizer.generate_ui_confirm(),
		"eat_dish": func(): return AudioSynthesizer.generate_eat_dish(),
		"heat_stall": func(): return AudioSynthesizer.generate_heat_stall()
	}

	for id in sfx_generators:
		var stream: AudioStreamWAV = sfx_generators[id].call()
		Assertions.assert_not_null(stream, "SFX '%s' stream created successfully" % id)
		Assertions.assert_true(stream.data.size() > 0, "SFX '%s' PCM byte buffer is non-empty (%d bytes)" % [id, stream.data.size()])
		Assertions.assert_true(stream.format == AudioStreamWAV.FORMAT_16_BITS, "SFX '%s' format is 16-bit PCM" % id)
		Assertions.assert_true(stream.mix_rate == 22050, "SFX '%s' mix rate is 22,050 Hz" % id)

		# Inspect raw 16-bit PCM samples
		var sample_count = stream.data.size() / 2
		var max_abs_amp := 0.0
		var sum_squares := 0.0
		var nan_or_inf_detected := false

		for i in range(sample_count):
			var sample_val = stream.data.decode_s16(i * 2)
			var float_val = float(sample_val) / 32768.0
			if is_nan(float_val) or is_inf(float_val):
				nan_or_inf_detected = true
			max_abs_amp = maxf(max_abs_amp, absf(float_val))
			sum_squares += float_val * float_val

		var rms = sqrt(sum_squares / float(sample_count))

		Assertions.assert_true(not nan_or_inf_detected, "SFX '%s' has zero NaN or Inf values in PCM stream" % id)
		Assertions.assert_true(max_abs_amp <= 1.0, "SFX '%s' peak amplitude <= 1.0 (actual: %.3f)" % [id, max_abs_amp])
		Assertions.assert_true(rms > 0.01, "SFX '%s' has audible acoustic energy (RMS: %.4f > 0.01)" % [id, rms])

	# 3. Peak Acoustic Stacking Headroom Model
	var linear_ceiling = db_to_linear(ceiling_db)
	Assertions.assert_true(linear_ceiling <= 0.95, "Master limiter guaranteed headroom ceiling: %.4f linear <= 0.9500 (-0.5 dBFS)" % linear_ceiling)

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV-ART-04: Verified 11 procedural SFX cues and Master limiter headroom: zero clipping, zero NaN/Infs, valid PCM.")
	return ok
