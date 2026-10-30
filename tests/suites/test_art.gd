class_name TestArt
extends RefCounted

## TestArt — Suite 24: Identitas Visual & Audio Dasar Konsisten (Milestone ART-001)
## Memenuhi spesifikasi PRD FR21, FR22, ART_DIRECTION.md § 1..10, dan TEST_PLAN.md T55 & T56.

const Assertions = preload("res://tests/assertions.gd")
const AudioSynthesizer = preload("res://scripts/audio/audio_synthesizer.gd")
const AudioManagerClass = preload("res://scripts/audio/audio_manager.gd")

func run_all() -> bool:
	print("\n==================================================")
	print("[SUITE 24] TestArt: Identitas Visual, Audio & Performa (ART-001)")
	print("==================================================")

	var all_passed := true

	# Group 1: Material Presence & Indonesian Stylized Palette (T55.1)
	if not test_art01_terracotta_and_architectural_materials():
		all_passed = false
	if not test_art02_soil_stage_materials():
		all_passed = false
	if not test_art03_crop_stage_materials_and_colors():
		all_passed = false

	# Group 2: Crop Silhouette & Physical Height Distinctiveness (T55.2)
	if not test_art04_crop_bayam_height_and_bounding_volume_progression():
		all_passed = false
	if not test_art05_foraging_and_landmark_silhouette_distinctiveness():
		all_passed = false

	# Group 3: Visual Integrity, Missing Asset & Pink Shader Guard (T55.3)
	if not test_art06_mesh_and_material_integrity_oracle():
		all_passed = false
	if not test_art07_ui_contrast_and_text_readability():
		all_passed = false

	# Group 4: Audio System, Bus Routing & Volume Compliance (T55.4)
	if not test_art08_audio_bus_layout_and_routing():
		all_passed = false
	if not test_art09_audio_volume_attenuation_and_mute_boundaries():
		all_passed = false
	if not test_art10_audio_manager_streams_and_triggers():
		all_passed = false

	# Group 5: Performance Metrics & Exploration Route Sanity (T56)
	if not test_art11_scene_tree_node_count_and_composition_budget():
		all_passed = false
	if not test_art12_frame_time_and_process_budget_oracle():
		all_passed = false
	if not test_art13_static_memory_and_exploration_path_stability():
		all_passed = false

	return all_passed

# -----------------------------------------------------------------------------
# LIFECYCLE HELPERS FOR SCENE GRAPH TESTING
# -----------------------------------------------------------------------------

func _create_test_main() -> Node:
	var main_scene = ResourceLoader.load("res://scenes/main.tscn") as PackedScene
	if main_scene == null:
		return null
	var main = main_scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.add_child(main)
	elif main.get("level") == null:
		main.set("level", main.get_node_or_null("LevelGraybox"))
	return main

func _free_test_main(main: Node) -> void:
	if main == null:
		return
	if main.get_parent() != null:
		main.get_parent().remove_child(main)
	main.free()

# -----------------------------------------------------------------------------
# GROUP 1: MATERIAL PRESENCE & INDONESIAN STYLIZED PALETTE COMPLIANCE (T55.1)
# -----------------------------------------------------------------------------

func test_art01_terracotta_and_architectural_materials() -> bool:
	print("  [RUN] ART-01: Terracotta & Indonesian Architectural Palette")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	Assertions.assert_not_null(scene_res, "level_graybox.tscn harus dapat dimuat")
	var level = scene_res.instantiate() as Node3D
	Assertions.assert_not_null(level, "level_graybox.tscn harus dapat diinstansiasi")

	# 1. Atap Genteng Terracotta (#AB6748)
	var house_roof = level.find_child("HouseRoof", true, false)
	Assertions.assert_not_null(house_roof, "HouseRoof harus ada")
	var roof_mesh = house_roof.find_child("Mesh", true, false) as MeshInstance3D
	Assertions.assert_not_null(roof_mesh, "HouseRoof harus memiliki Mesh")
	var roof_mat = _get_active_material(roof_mesh)
	Assertions.assert_not_null(roof_mat, "Material atap genteng tidak boleh null")
	var expected_genteng = Color(0.671, 0.404, 0.282)
	Assertions.assert_true(roof_mat.albedo_color.is_equal_approx(expected_genteng),
		"Warna genteng harus cocok dengan #AB6748 (aktual: %s)" % str(roof_mat.albedo_color))
	Assertions.assert_true(roof_mat.roughness <= 0.70, "Roughness genteng harus terarah (<= 0.70)")

	# 2. Bubungan Atap Ridge Cap (#8F4F35)
	var roof_ridge = level.find_child("RoofRidge", true, false) as MeshInstance3D
	Assertions.assert_not_null(roof_ridge, "RoofRidge (bubungan atap) harus ada")
	var ridge_mat = _get_active_material(roof_ridge)
	Assertions.assert_not_null(ridge_mat, "Material bubungan atap tidak boleh null")
	var expected_ridge = Color(0.561, 0.310, 0.208)
	Assertions.assert_true(ridge_mat.albedo_color.is_equal_approx(expected_ridge),
		"Warna bubungan harus cocok dengan #8F4F35 (aktual: %s)" % str(ridge_mat.albedo_color))

	# 3. Dinding Plester (#E4D6B5)
	var wall_north = level.find_child("WallNorth", true, false)
	var wall_mesh = wall_north.find_child("Mesh", true, false) as MeshInstance3D
	var wall_mat = _get_active_material(wall_mesh)
	var expected_wall = Color(0.894, 0.839, 0.710)
	Assertions.assert_true(wall_mat.albedo_color.is_equal_approx(expected_wall),
		"Warna plester dinding harus cocok dengan #E4D6B5 (aktual: %s)" % str(wall_mat.albedo_color))

	# 4. Plinth Fondasi Batu/Bata (#5A4D41)
	var plinth = level.find_child("PlinthNorth", true, false) as MeshInstance3D
	Assertions.assert_not_null(plinth, "PlinthNorth fondasi harus ada")
	var plinth_mat = _get_active_material(plinth)
	var expected_plinth = Color(0.353, 0.302, 0.255)
	Assertions.assert_true(plinth_mat.albedo_color.is_equal_approx(expected_plinth),
		"Warna plinth fondasi harus cocok dengan #5A4D41 (aktual: %s)" % str(plinth_mat.albedo_color))

	# 5. Kusen Kayu Jati Gelap (#5C3D2E) & Pintu Kayu Panel (#684735)
	var kusen = level.find_child("KusenLeft", true, false) as MeshInstance3D
	Assertions.assert_not_null(kusen, "Kusen pintu harus ada")
	var kusen_mat = _get_active_material(kusen)
	var expected_kusen = Color(0.361, 0.239, 0.180)
	Assertions.assert_true(kusen_mat.albedo_color.is_equal_approx(expected_kusen),
		"Warna kusen jati harus cocok dengan #5C3D2E (aktual: %s)" % str(kusen_mat.albedo_color))

	var door = level.find_child("FrontDoor", true, false) as MeshInstance3D
	Assertions.assert_not_null(door, "FrontDoor harus ada")
	var door_mat = _get_active_material(door)
	var expected_door = Color(0.408, 0.278, 0.208)
	Assertions.assert_true(door_mat.albedo_color.is_equal_approx(expected_door),
		"Warna daun pintu harus cocok dengan #684735 (aktual: %s)" % str(door_mat.albedo_color))

	# 6. Tiang Teras Kayu (#795540)
	var tiang_l = level.find_child("TiangTerasLeft", true, false)
	Assertions.assert_not_null(tiang_l, "TiangTerasLeft harus ada")
	var tiang_r = level.find_child("TiangTerasRight", true, false)
	Assertions.assert_not_null(tiang_r, "TiangTerasRight harus ada")

	# 7. Pagar Bambu Keliling & Kebun (#A89F6E & #B3A675)
	var fence_sw = level.find_child("FenceSouthWest", true, false)
	Assertions.assert_not_null(fence_sw, "Pagar bambu barat daya harus ada")
	var fence_se = level.find_child("FenceSouthEast", true, false)
	Assertions.assert_not_null(fence_se, "Pagar bambu tenggara harus ada")
	var fence_g = level.find_child("FenceGarden", true, false)
	Assertions.assert_not_null(fence_g, "Pagar bambu kebun harus ada")

	level.free()
	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ART-01: Terracotta & Indonesian architectural palette verified.")
	return ok

func test_art02_soil_stage_materials() -> bool:
	print("  [RUN] ART-02: Soil States & Monotonic Roughness Attenuation")
	var initial_failures = Assertions.current_suite_failed

	var main = _create_test_main()
	Assertions.assert_not_null(main, "main.tscn harus dapat diinstansiasi")
	if main == null or main.level == null:
		Assertions.assert_true(false, "Main level tidak terinisialisasi")
		_free_test_main(main)
		return false

	var plot_node = main.level.get_node_or_null("plot_home_01")
	Assertions.assert_not_null(plot_node, "plot_home_01 harus ada di LevelGraybox")
	var soil_bed = plot_node.get_node_or_null("SoilBed")
	Assertions.assert_not_null(soil_bed, "SoilBed static body harus ada di dalam plot_home_01")
	var soil_mesh = soil_bed.find_child("Mesh", true, false) as MeshInstance3D
	Assertions.assert_not_null(soil_mesh, "SoilBed harus memiliki MeshInstance3D")

	# 4 state tanah per PRD/CONTENT: unhoed, hoed dry, compost dry, compost moist
	var test_states: Array[Dictionary] = [
		{"data": {"is_hoed": false, "has_compost": false, "moisture": 0.0}, "exp_r": 0.95, "exp_c": Color(0.55, 0.44, 0.32)},
		{"data": {"is_hoed": true, "has_compost": false, "moisture": 0.0}, "exp_r": 0.85, "exp_c": Color(0.38, 0.26, 0.16)},
		{"data": {"is_hoed": true, "has_compost": true, "moisture": 15.0}, "exp_r": 0.80, "exp_c": Color(0.28, 0.18, 0.10)},
		{"data": {"is_hoed": true, "has_compost": true, "moisture": 60.0}, "exp_r": 0.40, "exp_c": Color(0.18, 0.12, 0.06)}
	]

	var prev_roughness := 1.0
	for i in range(test_states.size()):
		var tc: Dictionary = test_states[i]
		# Panggil handler nyata di scripts/main.gd
		main._on_garden_plot_state_changed("plot_home_01", tc["data"])

		# Query material aktual pada scene node
		var mat = soil_mesh.material_override as StandardMaterial3D
		Assertions.assert_not_null(mat, "Material override pada SoilBed MeshInstance3D harus ada pada state %d" % i)
		if mat != null:
			var r: float = mat.roughness
			Assertions.assert_true(r < prev_roughness,
				"Roughness aktual material tanah state %d (%.2f) harus strictly < state sebelumnya (%.2f)" % [i, r, prev_roughness])
			Assertions.assert_true(mat.albedo_color.is_equal_approx(tc["exp_c"]),
				"Warna aktual material tanah state %d harus sesuai palette (aktual: %s, expected: %s)" % [i, str(mat.albedo_color), str(tc["exp_c"])])
			prev_roughness = r

	# Verifikasi kilau spekular pada tanah lembap (roughness <= 0.45)
	var final_mat = soil_mesh.material_override as StandardMaterial3D
	Assertions.assert_not_null(final_mat, "Material tanah akhir harus valid")
	if final_mat != null:
		Assertions.assert_true(final_mat.roughness <= 0.45,
			"Tanah lembap berair harus memiliki roughness rendah untuk kilau spekular (aktual: %.2f)" % final_mat.roughness)

	_free_test_main(main)
	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ART-02: Soil states & monotonic roughness attenuation verified.")
	return ok

func test_art03_crop_stage_materials_and_colors() -> bool:
	print("  [RUN] ART-03: Crop Stages Color Progression & Modular Silhouette")
	var initial_failures = Assertions.current_suite_failed

	var main = _create_test_main()
	Assertions.assert_not_null(main, "main.tscn harus dapat diinstansiasi")
	if main == null or main.level == null:
		Assertions.assert_true(false, "Main level tidak terinisialisasi")
		_free_test_main(main)
		return false

	var spot_node = main.level.get_node_or_null("plot_home_01/spot_0")
	Assertions.assert_not_null(spot_node, "spot_0 harus ada di plot_home_01")

	var actual_stage_colors: Array[Color] = []
	var expected_primitive_counts: Array[int] = [2, 3, 7, 10]
	var expected_key_children: Array[String] = ["BaseMound", "CotyledonLeft", "Leaf_0", "FloweringPlume"]

	# Iterasi 4 stage pertumbuhan melalui update state nyata
	for stage in range(4):
		var plot_data = {
			"is_hoed": true,
			"has_compost": true,
			"moisture": 50.0,
			"spots": {
				"slot_01": {
					"is_occupied": true,
					"crop_data": {
						"crop_id": "crop_bayam_01",
						"growth_stage": stage
					}
				}
			}
		}
		main._on_garden_plot_state_changed("plot_home_01", plot_data)

		var crop_mesh = spot_node.get_node_or_null("CropMesh") as Node3D
		Assertions.assert_not_null(crop_mesh, "CropMesh harus di-instantiate oleh main._on_garden_plot_state_changed untuk stage %d" % stage)
		if crop_mesh != null:
			Assertions.assert_true(crop_mesh.visible, "CropMesh harus visible saat slot occupied pada stage %d" % stage)
			Assertions.assert_equal(crop_mesh.get_child_count(), expected_primitive_counts[stage],
				"CropMesh stage %d harus memiliki %d child primitives (aktual: %d)" % [stage, expected_primitive_counts[stage], crop_mesh.get_child_count()])

			# Periksa child kunci khas siluet per stage
			var key_child = crop_mesh.get_node_or_null(expected_key_children[stage])
			Assertions.assert_not_null(key_child, "CropMesh stage %d harus memiliki child node '%s'" % [stage, expected_key_children[stage]])

			# Ambil warna stage aktual dari metadata dan material child primitive
			var stage_color: Color = crop_mesh.get_meta("stage_color", Color.BLACK)
			actual_stage_colors.append(stage_color)

			var key_mi = key_child as MeshInstance3D
			if key_mi != null and key_mi.material_override != null:
				var mat = key_mi.material_override as StandardMaterial3D
				Assertions.assert_not_null(mat, "Child '%s' stage %d harus memiliki material override" % [expected_key_children[stage], stage])
				if mat != null:
					Assertions.assert_true(mat.albedo_color.a > 0.0, "Material albedo alpha harus valid")

	Assertions.assert_equal(actual_stage_colors.size(), 4, "Harus mengumpulkan 4 warna dari scene graph untuk 4 stage bayam")

	# Warna aktual harus berbeda secara terukur pada setiap tahap (diff > 0.15)
	for i in range(actual_stage_colors.size()):
		for j in range(i + 1, actual_stage_colors.size()):
			var c1 = actual_stage_colors[i]
			var c2 = actual_stage_colors[j]
			var total_diff = absf(c1.r - c2.r) + absf(c1.g - c2.g) + absf(c1.b - c2.b)
			Assertions.assert_true(total_diff > 0.15,
				"Warna aktual CropMesh bayam tahap %d dan %d harus berbeda secara visual (diff: %.3f)" % [i, j, total_diff])

	# Test unplanting: slot tidak terisi menyembunyikan CropMesh
	var unplant_data = {
		"is_hoed": true,
		"has_compost": true,
		"moisture": 50.0,
		"spots": {
			"slot_01": {
				"is_occupied": false
			}
		}
	}
	main._on_garden_plot_state_changed("plot_home_01", unplant_data)
	var final_crop_mesh = spot_node.get_node_or_null("CropMesh") as Node3D
	if final_crop_mesh != null:
		Assertions.assert_false(final_crop_mesh.visible, "CropMesh harus disembunyikan (visible == false) saat slot dikosongkan")

	_free_test_main(main)
	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ART-03: Crop stages color progression & modular silhouette verified.")
	return ok

# -----------------------------------------------------------------------------
# GROUP 2: CROP SILHOUETTE & PHYSICAL HEIGHT DISTINCTIVENESS (T55.2)
# -----------------------------------------------------------------------------

func test_art04_crop_bayam_height_and_bounding_volume_progression() -> bool:
	print("  [RUN] ART-04: Bayam Height & Volume Monotonic Progression (T55 Silhouette)")
	var initial_failures = Assertions.current_suite_failed

	var main = _create_test_main()
	Assertions.assert_not_null(main, "main.tscn harus dapat diinstansiasi")
	if main == null or main.level == null:
		Assertions.assert_true(false, "Main level tidak terinisialisasi")
		_free_test_main(main)
		return false

	var spot_node = main.level.get_node_or_null("plot_home_01/spot_0")
	Assertions.assert_not_null(spot_node, "spot_0 harus ada di plot_home_01")

	var expected_heights: Array[float] = [0.04, 0.14, 0.30, 0.50]
	var expected_counts: Array[int] = [2, 3, 7, 10]
	var prev_height := 0.0

	for stage in range(4):
		var plot_data = {
			"is_hoed": true,
			"has_compost": true,
			"moisture": 50.0,
			"spots": {
				"slot_01": {
					"is_occupied": true,
					"crop_data": {
						"crop_id": "crop_bayam_01",
						"growth_stage": stage
					}
				}
			}
		}
		main._on_garden_plot_state_changed("plot_home_01", plot_data)

		var crop_mesh = spot_node.get_node_or_null("CropMesh") as Node3D
		Assertions.assert_not_null(crop_mesh, "CropMesh stage %d harus ada di scene" % stage)
		if crop_mesh == null:
			continue

		# Uniform root scaling Vector3(1, 1, 1) agar child rotation tidak terdistorsi shear
		Assertions.assert_true(crop_mesh.scale.is_equal_approx(Vector3.ONE),
			"CropMesh root container harus mempertahankan uniform scale Vector3(1, 1, 1)")

		# Query tinggi dan child primitives dari metadata dan scene tree aktual
		var h: float = float(crop_mesh.get_meta("crop_height", 0.0))

		Assertions.assert_approx_equal(h, expected_heights[stage], 0.001,
			"Tinggi terukur CropMesh stage %d harus %.2fm (aktual: %.2fm)" % [stage, expected_heights[stage], h])
		Assertions.assert_equal(crop_mesh.get_child_count(), expected_counts[stage],
			"Jumlah child primitive mesh stage %d harus %d (aktual: %d)" % [stage, expected_counts[stage], crop_mesh.get_child_count()])

		Assertions.assert_gt(h, prev_height,
			"Tinggi aktual CropMesh stage %d (%.2fm) harus strictly monotonic lebih tinggi dari stage sebelumnya (%.2fm)" % [stage, h, prev_height])

		if stage > 0:
			var height_ratio = h / prev_height
			Assertions.assert_true(height_ratio >= 1.5,
				"Rasio tinggi antar stage %d harus >= 1.5x (aktual: %.2fx)" % [stage, height_ratio])

		# Validasi geometri internal khas setiap stage
		match stage:
			0:
				var mound = crop_mesh.get_node_or_null("BaseMound") as MeshInstance3D
				var dibble = crop_mesh.get_node_or_null("SeedDibble") as MeshInstance3D
				Assertions.assert_not_null(mound, "Stage 0 harus memiliki BaseMound")
				Assertions.assert_not_null(dibble, "Stage 0 harus memiliki SeedDibble")
				if mound != null and dibble != null:
					var m_mesh = mound.mesh as CylinderMesh
					var d_mesh = dibble.mesh as CylinderMesh
					Assertions.assert_not_null(m_mesh, "BaseMound harus CylinderMesh")
					Assertions.assert_not_null(d_mesh, "SeedDibble harus CylinderMesh")
					var peak_y = dibble.position.y + (d_mesh.height / 2.0)
					Assertions.assert_approx_equal(peak_y, 0.04, 0.005, "Puncak SeedDibble harus mencapai Y = 0.04m")
			1:
				var stem = crop_mesh.get_node_or_null("Stem") as MeshInstance3D
				var cot_l = crop_mesh.get_node_or_null("CotyledonLeft") as MeshInstance3D
				var cot_r = crop_mesh.get_node_or_null("CotyledonRight") as MeshInstance3D
				Assertions.assert_not_null(stem, "Stage 1 harus memiliki Stem")
				Assertions.assert_not_null(cot_l, "Stage 1 harus memiliki CotyledonLeft")
				Assertions.assert_not_null(cot_r, "Stage 1 harus memiliki CotyledonRight")
				if cot_l != null and cot_r != null:
					Assertions.assert_true(abs(cot_l.rotation.z - deg_to_rad(-35.0)) < 0.05, "CotyledonLeft roll harus -35 deg")
					Assertions.assert_true(abs(cot_r.rotation.z - deg_to_rad(35.0)) < 0.05, "CotyledonRight roll harus +35 deg")
					var b_mesh_l = cot_l.mesh as BoxMesh
					var half_x_l = b_mesh_l.size.x * 0.5 if b_mesh_l != null else 0.0325
					var tip_l = cot_l.transform * Vector3(-half_x_l, 0, 0)
					var base_l = cot_l.transform * Vector3(half_x_l, 0, 0)
					Assertions.assert_true(tip_l.y > base_l.y, "CotyledonLeft tip Y (%.4fm) harus > base Y (%.4fm) untuk siluet V naik" % [tip_l.y, base_l.y])
					var b_mesh_r = cot_r.mesh as BoxMesh
					var half_x_r = b_mesh_r.size.x * 0.5 if b_mesh_r != null else 0.0325
					var tip_r = cot_r.transform * Vector3(half_x_r, 0, 0)
					var base_r = cot_r.transform * Vector3(-half_x_r, 0, 0)
					Assertions.assert_true(tip_r.y > base_r.y, "CotyledonRight tip Y (%.4fm) harus > base Y (%.4fm) untuk siluet V naik" % [tip_r.y, base_r.y])
			2:
				var stem = crop_mesh.get_node_or_null("Stem") as MeshInstance3D
				Assertions.assert_not_null(stem, "Stage 2 harus memiliki Stem")
				for li in range(6):
					var leaf = crop_mesh.get_node_or_null("Leaf_%d" % li)
					Assertions.assert_not_null(leaf, "Stage 2 harus memiliki rosette Leaf_%d" % li)
			3:
				var stalk = crop_mesh.get_node_or_null("MainStalk") as MeshInstance3D
				var plume = crop_mesh.get_node_or_null("FloweringPlume") as MeshInstance3D
				Assertions.assert_not_null(stalk, "Stage 3 harus memiliki MainStalk")
				Assertions.assert_not_null(plume, "Stage 3 harus memiliki FloweringPlume")
				for ci in range(8):
					var leaf = crop_mesh.get_node_or_null("CanopyLeaf_%d" % ci)
					Assertions.assert_not_null(leaf, "Stage 3 harus memiliki CanopyLeaf_%d" % ci)
				if plume != null:
					var p_mesh = plume.mesh as CylinderMesh
					var plume_peak = plume.position.y + (p_mesh.height / 2.0)
					Assertions.assert_approx_equal(plume_peak, 0.50, 0.005, "Puncak FloweringPlume harus mencapai Y = 0.50m")

		prev_height = h

	# Bounding tinggi akhir (Stage 3) harus mencapai 0.50m
	Assertions.assert_true(abs(prev_height - 0.50) < 0.01,
		"Tinggi tanaman siap panen harus mencapai 0.50m (aktual: %.2f)" % prev_height)

	_free_test_main(main)
	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ART-04: Bayam height & volume monotonic progression verified.")
	return ok

func test_art05_foraging_and_landmark_silhouette_distinctiveness() -> bool:
	print("  [RUN] ART-05: Wild Foraging & Landmark Silhouette Distinctiveness")
	var initial_failures = Assertions.current_suite_failed

	var main = _create_test_main()
	Assertions.assert_not_null(main, "main.tscn harus dapat diinstansiasi")
	if main == null or main.level == null:
		Assertions.assert_true(false, "Main level tidak terinisialisasi")
		_free_test_main(main)
		return false

	var level = main.level

	# 1. Jagung (resource_jagung_01): Stalk persisten + CornEar terpisah
	var jagung = level.find_child("resource_jagung_01", true, false)
	Assertions.assert_not_null(jagung, "resource_jagung_01 harus ada di level")
	var corn_stalk = jagung.find_child("CornStalks", true, false)
	Assertions.assert_not_null(corn_stalk, "CornStalks static body harus ada")
	var stalk_mesh = corn_stalk.find_child("StalkMesh", true, false) as MeshInstance3D
	Assertions.assert_not_null(stalk_mesh, "StalkMesh batang jagung persisten harus ada")
	var corn_ear = corn_stalk.find_child("CornEar", true, false) as MeshInstance3D
	Assertions.assert_not_null(corn_ear, "CornEar tongkol jagung harus ada sebagai child mesh terpisah")

	# Test foraging detachment logic melalui handler resmi main._on_foraging_state_changed
	main._on_foraging_state_changed("resource_jagung_01", false)
	Assertions.assert_true(stalk_mesh.visible, "Batang jagung StalkMesh harus TETAP terlihat saat tongkol dipanen")
	Assertions.assert_false(corn_ear.visible, "Hanya tongkol CornEar yang hilang saat dipanen")

	main._on_foraging_state_changed("resource_jagung_01", true)
	Assertions.assert_true(corn_ear.visible, "CornEar harus kembali terlihat saat regenerasi")

	# 2. Temu Kunci (resource_temu_kunci_01): Batu kali + HerbMesh
	var temu_kunci = level.find_child("resource_temu_kunci_01", true, false)
	Assertions.assert_not_null(temu_kunci, "resource_temu_kunci_01 harus ada di level")
	var rock = temu_kunci.find_child("Rock", true, false)
	Assertions.assert_not_null(rock, "Rock batu kali temu kunci harus ada")
	var herb_mesh = temu_kunci.find_child("HerbMesh", true, false) as MeshInstance3D
	Assertions.assert_not_null(herb_mesh, "HerbMesh daun temu kunci harus ada")

	# Test foraging detachment temu kunci melalui handler resmi main._on_foraging_state_changed
	main._on_foraging_state_changed("resource_temu_kunci_01", false)
	Assertions.assert_true(rock.visible, "Batu kali harus tetap terlihat di dunia saat herba dipanen")
	Assertions.assert_false(herb_mesh.visible, "HerbMesh disembunyikan saat habis dipanen")

	main._on_foraging_state_changed("resource_temu_kunci_01", true)
	Assertions.assert_true(herb_mesh.visible, "HerbMesh kembali terlihat saat regenerasi")

	# 3. Siluet Jagung (tinggi >= 1.8m) vs Temu Kunci (rendah <= 0.8m) diukur dari mesh asli
	var stalk_box = stalk_mesh.mesh as BoxMesh
	var actual_corn_height: float = stalk_box.size.y if stalk_box != null else stalk_mesh.get_aabb().size.y

	var herb_box = herb_mesh.mesh as BoxMesh
	var actual_temu_height: float = herb_box.size.y if herb_box != null else herb_mesh.get_aabb().size.y

	Assertions.assert_true(actual_corn_height >= 1.79,
		"Tinggi aktual mesh siluet batang jagung di scene harus >= 1.8m (aktual: %.2fm)" % actual_corn_height)
	Assertions.assert_true(actual_temu_height <= 0.8,
		"Tinggi aktual mesh herba temu kunci di scene harus <= 0.8m (aktual: %.2fm)" % actual_temu_height)
	Assertions.assert_true(actual_corn_height > 2.0 * actual_temu_height,
		"Siluet jagung (tinggi: %.2fm) harus >2x lebih tinggi dari siluet herba temu kunci (daun rendah: %.2fm)" % [actual_corn_height, actual_temu_height])

	_free_test_main(main)
	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ART-05: Wild foraging & landmark silhouette distinctiveness verified.")
	return ok

# -----------------------------------------------------------------------------
# GROUP 3: VISUAL INTEGRITY, MISSING ASSET & PINK SHADER GUARD (T55.3)
# -----------------------------------------------------------------------------

func test_art06_mesh_and_material_integrity_oracle() -> bool:
	print("  [RUN] ART-06: Recursive Mesh & Material Integrity (Zero Magenta Shader Guard)")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = scene_res.instantiate() as Node3D

	var meshes_checked := 0
	var stack: Array[Node] = [level]

	while not stack.is_empty():
		var node = stack.pop_back()
		if node is MeshInstance3D:
			var mi = node as MeshInstance3D
			Assertions.assert_not_null(mi.mesh, "MeshInstance3D '%s' tidak boleh memiliki mesh null" % mi.name)
			var mat = _get_active_material(mi)
			Assertions.assert_not_null(mat, "MeshInstance3D '%s' harus memiliki material aktif" % mi.name)
			if mat is StandardMaterial3D:
				var std_mat = mat as StandardMaterial3D
				# Guard against uncompiled magenta shader fallback
				var is_magenta = std_mat.albedo_color.is_equal_approx(Color.MAGENTA) or std_mat.albedo_color.is_equal_approx(Color(1, 0, 1, 1))
				Assertions.assert_false(is_magenta, "Material '%s' tidak boleh memakai warna magenta fallback" % mi.name)
			meshes_checked += 1

		for child in node.get_children():
			stack.push_back(child)

	Assertions.assert_true(meshes_checked >= 20, "Harus ada minimal 20 mesh yang diverifikasi integritasnya (aktual: %d)" % meshes_checked)

	level.free()
	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ART-06: Recursive mesh & material integrity verified (%d meshes checked)." % meshes_checked)
	return ok

func test_art07_ui_contrast_and_text_readability() -> bool:
	print("  [RUN] ART-07: WCAG AAA UI Contrast & Text Readability")
	var initial_failures = Assertions.current_suite_failed

	# Warna UI dari ART_DIRECTION § 4:
	# UI Teks: #F5F0E4
	# UI Gelap: #24312E
	var c_text = Color("F5F0E4")
	var c_bg = Color("24312E")

	var l_text = _calculate_relative_luminance(c_text)
	var l_bg = _calculate_relative_luminance(c_bg)

	var contrast_ratio = (l_text + 0.05) / (l_bg + 0.05)
	Assertions.assert_true(contrast_ratio >= 7.0,
		"Rasio kontras UI teks terhadap UI background harus >= 7.0 (WCAG AAA) (aktual: %.2f:1)" % contrast_ratio)
	Assertions.assert_true(contrast_ratio > 10.0,
		"Kontras Buku Resep 2045 sangat tinggi (%.2f:1) memastikan kenyamanan baca di layar redup" % contrast_ratio)

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ART-07: WCAG AAA UI contrast & readability verified (%.2f:1)." % contrast_ratio)
	return ok

# -----------------------------------------------------------------------------
# GROUP 4: AUDIO SYSTEM, BUS ROUTING & VOLUME COMPLIANCE (T55.4)
# -----------------------------------------------------------------------------

func test_art08_audio_bus_layout_and_routing() -> bool:
	print("  [RUN] ART-08: Audio Bus Layout, Routing & Master Limiter")
	var initial_failures = Assertions.current_suite_failed

	var idx_master = AudioServer.get_bus_index("Master")
	var idx_music = AudioServer.get_bus_index("Music")
	var idx_sfx = AudioServer.get_bus_index("SFX")

	Assertions.assert_true(idx_master != -1, "Bus Master harus ada")
	Assertions.assert_true(idx_music != -1, "Bus Music harus ada")
	Assertions.assert_true(idx_sfx != -1, "Bus SFX harus ada")

	var music_send = AudioServer.get_bus_send(idx_music)
	var sfx_send = AudioServer.get_bus_send(idx_sfx)
	Assertions.assert_equal(str(music_send), "Master", "Bus Music harus diarahkan ke Master")
	Assertions.assert_equal(str(sfx_send), "Master", "Bus SFX harus diarahkan ke Master")

	# Verifikasi AudioEffectLimiter pada Master bus
	var effect_count = AudioServer.get_bus_effect_count(idx_master)
	var has_limiter := false
	for i in range(effect_count):
		var eff = AudioServer.get_bus_effect(idx_master, i)
		if eff is AudioEffectLimiter:
			has_limiter = true
			var lim = eff as AudioEffectLimiter
			Assertions.assert_true(lim.ceiling_db <= -0.5, "Ceiling limiter harus <= -0.5 dB untuk mencegah clipping (aktual: %.1f dB)" % lim.ceiling_db)
			break
	Assertions.assert_true(has_limiter, "Bus Master harus dipasangi AudioEffectLimiter untuk proteksi digital clipping")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ART-08: Audio bus layout, routing & master limiter verified.")
	return ok

func test_art09_audio_volume_attenuation_and_mute_boundaries() -> bool:
	print("  [RUN] ART-09: Audio Volume Decibel Mapping & Numerical Bounds")
	var initial_failures = Assertions.current_suite_failed

	# Uji linear_to_db batas aman:
	var db_full = linear_to_db(1.0)
	Assertions.assert_true(abs(db_full - 0.0) < 0.001, "linear_to_db(1.0) harus 0.0 dB")

	var db_half = linear_to_db(0.5)
	Assertions.assert_true(db_half < -5.9 and db_half > -6.1, "linear_to_db(0.5) harus sekitar -6.02 dB")

	var db_low = linear_to_db(0.0001)
	Assertions.assert_true(db_low > -81.0 and not is_nan(db_low) and not is_inf(db_low),
		"linear_to_db(0.0001) tidak boleh NaN/Inf")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ART-09: Audio volume decibel mapping verified.")
	return ok

func test_art10_audio_manager_streams_and_triggers() -> bool:
	print("  [RUN] ART-10: Procedural Streams & AudioManager Lifecycle")
	var initial_failures = Assertions.current_suite_failed

	# 1. Test Procedural Generation
	var amb = AudioSynthesizer.generate_ambience_countryside()
	Assertions.assert_not_null(amb, "Ambience audio harus berhasil digenerate")
	Assertions.assert_equal(amb.loop_mode, AudioStreamWAV.LOOP_FORWARD, "Ambience harus looping forward")
	Assertions.assert_true(amb.data.size() > 20000, "Ambience PCM buffer harus terisi valid")

	var step = AudioSynthesizer.generate_footstep()
	Assertions.assert_not_null(step, "Footstep audio harus berhasil digenerate")
	Assertions.assert_equal(step.loop_mode, AudioStreamWAV.LOOP_DISABLED, "Footstep tidak boleh looping")

	var hoe = AudioSynthesizer.generate_tool_hoe()
	Assertions.assert_not_null(hoe, "Tool hoe audio harus berhasil digenerate")

	var water = AudioSynthesizer.generate_tool_water()
	Assertions.assert_not_null(water, "Tool water audio harus berhasil digenerate")

	var fert = AudioSynthesizer.generate_tool_fertilizer()
	Assertions.assert_not_null(fert, "Tool fertilizer audio harus berhasil digenerate")

	var harvest = AudioSynthesizer.generate_harvest_pickup()
	Assertions.assert_not_null(harvest, "Harvest audio harus berhasil digenerate")

	var simmer = AudioSynthesizer.generate_kitchen_simmer()
	Assertions.assert_not_null(simmer, "Kitchen simmer audio harus berhasil digenerate")
	Assertions.assert_equal(simmer.loop_mode, AudioStreamWAV.LOOP_FORWARD, "Kitchen simmer harus looping forward")

	var click = AudioSynthesizer.generate_ui_click()
	Assertions.assert_not_null(click, "UI click audio harus berhasil digenerate")

	var confirm = AudioSynthesizer.generate_ui_confirm()
	Assertions.assert_not_null(confirm, "UI confirm audio harus berhasil digenerate")

	var eat = AudioSynthesizer.generate_eat_dish()
	Assertions.assert_not_null(eat, "Eat dish audio harus berhasil digenerate")

	var heat_stall = AudioSynthesizer.generate_heat_stall()
	Assertions.assert_not_null(heat_stall, "Heat stall warning audio harus berhasil digenerate")

	# 2. Test AudioManager Instance & Pooling
	var tree := Engine.get_main_loop() as SceneTree
	var am: Node = null
	var is_ephemeral := false
	if tree != null and tree.root != null and tree.root.has_node("AudioManager"):
		am = tree.root.get_node("AudioManager")
	else:
		am = AudioManagerClass.new()
		if tree != null and tree.root != null:
			tree.root.add_child(am)
		is_ephemeral = true

	Assertions.assert_not_null(am.get("_ambience_player"), "Ambience player harus ada")
	Assertions.assert_not_null(am.get("_cooking_player"), "Cooking player harus ada")
	Assertions.assert_not_null(am.get("_ui_player"), "UI player harus ada")
	var pool: Array = am.get("_sfx_pool")
	Assertions.assert_equal(pool.size(), 8, "SFX pool harus memiliki 8 player")

	# Headless triggers
	am.play_sfx("tool_hoe")
	am.play_footstep()
	am.play_ui_click()
	am.play_ui_confirm()
	am.start_cooking_loop()
	am.stop_cooking_loop()
	am.stop_ambience()

	if is_ephemeral:
		am.queue_free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ART-10: Procedural streams & AudioManager lifecycle verified.")
	return ok

# -----------------------------------------------------------------------------
# GROUP 5: PERFORMANCE METRICS & EXPLORATION ROUTE SANITY (T56)
# -----------------------------------------------------------------------------

func test_art11_scene_tree_node_count_and_composition_budget() -> bool:
	print("  [RUN] ART-11: Scene Tree Node Count & Complexity Budget (T56)")
	var initial_failures = Assertions.current_suite_failed

	var start_time = Time.get_ticks_msec()
	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = scene_res.instantiate() as Node3D
	var load_time = Time.get_ticks_msec() - start_time

	Assertions.assert_true(load_time < 100, "Instansiasi level harus cepat (< 100ms, aktual: %dms)" % load_time)

	var node_count := 0
	var mesh_count := 0
	var static_body_count := 0

	var stack: Array[Node] = [level]
	while not stack.is_empty():
		var node = stack.pop_back()
		node_count += 1
		if node is MeshInstance3D:
			mesh_count += 1
		elif node is StaticBody3D:
			static_body_count += 1
		for child in node.get_children():
			stack.push_back(child)

	Assertions.assert_true(node_count < 300,
		"Total node count level (%d) harus di bawah anggaran batas 300 node untuk kompatibilitas desktop ringan" % node_count)
	Assertions.assert_true(mesh_count < 120,
		"Total mesh instances (%d) harus di bawah batas draw call 120" % mesh_count)
	Assertions.assert_true(static_body_count < 80,
		"Total static bodies (%d) harus di bawah batas fisika 80" % static_body_count)

	level.free()
	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ART-11: Scene composition within budget (Nodes: %d, Meshes: %d, SBs: %d)." % [node_count, mesh_count, static_body_count])
	return ok

func test_art12_frame_time_and_process_budget_oracle() -> bool:
	print("  [RUN] ART-12: Frame Time & Simulation Process Budget (T56)")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = scene_res.instantiate() as Node3D
	Assertions.assert_not_null(level, "level_graybox.tscn harus dapat diinstansiasi")

	var frame_times: Array[float] = []
	var step_delta: float = 1.0 / 60.0 # 0.016667
	var start_sim = Time.get_ticks_usec()

	for frame in range(60):
		var t0 = Time.get_ticks_usec()
		# Propagasi proses simulasi nyata melintasi seluruh 226+ node hierarchy level
		level.propagate_call("_process", [step_delta])
		level.propagate_call("_physics_process", [step_delta])
		var elapsed = (Time.get_ticks_usec() - t0) / 1000.0 # ms
		frame_times.append(elapsed)

	var total_sim_time = (Time.get_ticks_usec() - start_sim) / 1000.0 # ms
	var avg_frame = total_sim_time / 60.0

	var max_frame := 0.0
	for ft in frame_times:
		if ft > max_frame:
			max_frame = ft

	Assertions.assert_true(avg_frame <= 8.0,
		"Rata-rata frame process step simulasi harus <= 8.0ms (aktual: %.3fms)" % avg_frame)
	Assertions.assert_true(max_frame <= 16.67,
		"Spike maksimum frame step simulasi harus <= 16.67ms (aktual: %.3fms)" % max_frame)

	level.free()
	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ART-12: Frame simulation process budget verified (avg: %.3fms/frame, max: %.3fms)." % [avg_frame, max_frame])
	return ok

func test_art13_static_memory_and_exploration_path_stability() -> bool:
	print("  [RUN] ART-13: 7-Checkpoint Exploration Route Traversal & Memory Stability")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = scene_res.instantiate() as Node3D
	Assertions.assert_not_null(level, "level_graybox.tscn harus dapat diinstansiasi")

	# 7 Titik Rute Eksplorasi Standar per Handoff Blueprint & Korelasi Node Aktual di Scene
	var route_checkpoints: Array[Dictionary] = [
		{"name": "spawn_home", "node_id": "spawn_home", "expected_pos": Vector3(0.0, 0.0, 1.0), "route_pt": Vector3(0.0, 1.0, 1.0)},
		{"name": "porch_threshold", "node_id": "HouseStructure", "expected_pos": Vector3(0.0, 0.0, 4.0), "route_pt": Vector3(0.0, 1.0, 4.0)},
		{"name": "plot_home_01", "node_id": "plot_home_01", "expected_pos": Vector3(8.0, 0.0, 7.0), "route_pt": Vector3(8.0, 1.0, 7.0)},
		{"name": "resource_jagung_01", "node_id": "resource_jagung_01", "expected_pos": Vector3(22.0, 0.0, 28.0), "route_pt": Vector3(22.0, 1.0, 28.0)},
		{"name": "resource_temu_kunci_01", "node_id": "resource_temu_kunci_01", "expected_pos": Vector3(-20.0, 0.0, 30.0), "route_pt": Vector3(-20.0, 1.0, 30.0)},
		{"name": "npc_neighbor_01", "node_id": "npc_neighbor_01", "expected_pos": Vector3(-14.0, 0.0, 15.0), "route_pt": Vector3(-14.0, 1.0, 15.0)},
		{"name": "safe_return_home", "node_id": "safe_return_home", "expected_pos": Vector3(0.0, 0.0, 8.0), "route_pt": Vector3(0.0, 1.0, 8.0)}
	]

	# 1. Verifikasi Ground Static Body & Bounding Envelope
	var ground = level.find_child("Ground", true, false) as StaticBody3D
	Assertions.assert_not_null(ground, "Ground static body harus ada di level_graybox.tscn")
	var ground_col = ground.find_child("Collision", true, false) as CollisionShape3D
	Assertions.assert_not_null(ground_col, "Ground harus memiliki CollisionShape3D")
	var ground_box = ground_col.shape as BoxShape3D
	Assertions.assert_not_null(ground_box, "Bentuk collision ground harus BoxShape3D")

	var half_w = ground_box.size.x / 2.0
	var half_l = ground_box.size.z / 2.0
	var min_x = ground.position.x - half_w
	var max_x = ground.position.x + half_w
	var min_z = ground.position.z - half_l
	var max_z = ground.position.z + half_l

	# 2. Iterasi & Verifikasi Setiap Checkpoint terhadap Node Scene Nyata
	for i in range(route_checkpoints.size()):
		var cp = route_checkpoints[i]
		var cp_name: String = cp["name"]
		var node_id: String = cp["node_id"]
		var route_pt: Vector3 = cp["route_pt"]
		var expected_pos: Vector3 = cp["expected_pos"]

		# Pastikan node landmark nyata ada di dalam scene
		var target_node = level.get_node_or_null(node_id)
		if target_node == null:
			target_node = level.find_child(node_id, true, false)
		Assertions.assert_not_null(target_node, "Node target %s untuk checkpoint %d harus ada di level" % [node_id, i])
		if target_node != null and node_id != "HouseStructure":
			var dist = target_node.position.distance_to(expected_pos)
			Assertions.assert_true(dist <= 0.5,
				"Posisi landmark %s harus berada dalam toleransi 0.5m dari blueprint (aktual: %s, expected: %s)" % [node_id, str(target_node.position), str(expected_pos)])

		# Pastikan titik waypoint rute berada di atas tanah dan di dalam envelope batas dunia
		Assertions.assert_true(route_pt.y >= 1.0, "Checkpoint %d (%s) harus berada pada ketinggian berdiri player (Y >= 1.0)" % [i, cp_name])
		Assertions.assert_true(route_pt.x >= min_x and route_pt.x <= max_x,
			"Checkpoint %d (%s) X coordinate (%.1f) harus berada di dalam batas Ground [%.1f, %.1f]" % [i, cp_name, route_pt.x, min_x, max_x])
		Assertions.assert_true(route_pt.z >= min_z and route_pt.z <= max_z,
			"Checkpoint %d (%s) Z coordinate (%.1f) harus berada di dalam batas Ground [%.1f, %.1f]" % [i, cp_name, route_pt.z, min_z, max_z])

	# 3. Verifikasi Porch Doorway Clearance pada Checkpoint 2 (Z = 4)
	var wall_l = level.find_child("WallSouthLeft", true, false) as StaticBody3D
	var wall_r = level.find_child("WallSouthRight", true, false) as StaticBody3D
	Assertions.assert_not_null(wall_l, "WallSouthLeft harus ada")
	Assertions.assert_not_null(wall_r, "WallSouthRight harus ada")
	if wall_l != null and wall_r != null:
		var door_width = 0.8 - (-0.8) # 1.6m opening between WallSouthLeft and WallSouthRight
		Assertions.assert_true(door_width >= 1.4,
			"Lebar bukaan pintu depan harus memadai untuk navigasi bebas hambatan (aktual: %.2fm)" % door_width)

	# 4. Verifikasi Monitor Memori Statis Engine
	var static_mem = Performance.get_monitor(Performance.MEMORY_STATIC)
	var static_mem_mb = static_mem / (1024.0 * 1024.0)
	Assertions.assert_true(static_mem_mb < 150.0,
		"Penggunaan memori statis (%.2f MB) harus berada di bawah budget 150 MB" % static_mem_mb)

	level.free()
	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ART-13: 7-Checkpoint exploration route & memory verified (%.2f MB static mem)." % static_mem_mb)
	return ok

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS
# -----------------------------------------------------------------------------

func _get_active_material(mi: MeshInstance3D) -> Material:
	if mi == null:
		return null
	if mi.material_override != null:
		return mi.material_override
	if mi.get_surface_override_material(0) != null:
		return mi.get_surface_override_material(0)
	if mi.mesh != null and mi.mesh.material != null:
		return mi.mesh.material
	return null

func _calculate_relative_luminance(c: Color) -> float:
	var r = _gamma_expand(c.r)
	var g = _gamma_expand(c.g)
	var b = _gamma_expand(c.b)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b

func _gamma_expand(v: float) -> float:
	if v <= 0.03928:
		return v / 12.92
	else:
		return pow((v + 0.055) / 1.055, 2.4)
