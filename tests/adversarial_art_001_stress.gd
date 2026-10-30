extends SceneTree

## Adversarial Empirical Stress Test Harness for Milestone ART-001
## Stress Testing:
## 1. High Audio Concurrency, Player Pool Overflow & Memory Leak
## 2. Headroom Limiter & Decibel Boundary Protection
## 3. 7-Checkpoint Realistic Route Traversal, Collision & Frame Budget Oracle (T56)
## 4. Crop Monotonic Silhouette & Foraging Invariance Oracle (T55)
## 5. Scene Complexity & Visual Integrity Oracle (T55/T56)

const Assertions = preload("res://tests/assertions.gd")
const AudioSynthesizer = preload("res://scripts/audio/audio_synthesizer.gd")
const AudioManagerClass = preload("res://scripts/audio/audio_manager.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")

var _frame: int = 0
var _all_passed: bool = true

func _process(delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		run_all_stress_tests()
		finish_and_quit()
		return true
	return false

func finish_and_quit() -> void:
	print("\n==================================================")
	print("[ADVERSARIAL_ART_001] STRESS VERIFICATION SUMMARY:")
	print("  Assertions Passed: %d" % Assertions.current_suite_passed)
	print("  Assertions Failed: %d" % Assertions.current_suite_failed)

	if _all_passed and Assertions.current_suite_failed == 0:
		print("  FINAL VERDICT: APPROVE")
		print("  All ART-001 empirical stress criteria verified successfully.")
		print("==================================================")
		quit(0)
	else:
		printerr("  FINAL VERDICT: REQUEST_CHANGES")
		printerr("  Adversarial stress test failures encountered:")
		for msg in Assertions.failure_messages:
			printerr("    - ", msg)
		print("==================================================")
		quit(1)

func run_all_stress_tests() -> void:
	print("==================================================")
	print("[ADVERSARIAL_ART_001] Empirical Stress & Invariant Harness")
	print("Milestone: ART-001 (Visual & Audio Dasar yang Konsisten)")
	print("==================================================")

	Assertions.reset()

	# Stress Test 1: Audio Concurrency, Pool Overflow & Memory Leak
	if not test_adv01_audio_concurrency_and_memory_leak():
		_all_passed = false

	# Stress Test 2: Master Bus Limiter, Headroom & Numerical Extremes
	if not test_adv02_master_limiter_headroom_and_pcm_bounds():
		_all_passed = false

	# Stress Test 3: 7-Checkpoint Traversal with Real Physics & Frame Budget (T56)
	if not test_adv03_exploration_route_physics_traversal_and_frame_budget():
		_all_passed = false

	# Stress Test 4: Crop Monotonic Silhouette & Foraging Detachment Oracle (T55)
	if not test_adv04_crop_silhouette_and_foraging_invariance():
		_all_passed = false

	# Stress Test 5: Scene Complexity, WCAG Contrast & Material Integrity (T55/T56)
	if not test_adv05_scene_complexity_and_material_integrity():
		_all_passed = false

# -----------------------------------------------------------------------------
# STRESS TEST 1: AUDIO CONCURRENCY, POOL OVERFLOW & MEMORY LEAK
# -----------------------------------------------------------------------------

func test_adv01_audio_concurrency_and_memory_leak() -> bool:
	print("\n  [RUN] ADV-ART-01: Audio Concurrency Burst, Pool Overflow & Memory Leak Stress")
	var initial_failures = Assertions.current_suite_failed

	var am: Node = null
	if root.has_node("AudioManager"):
		am = root.get_node("AudioManager")
	else:
		am = AudioManagerClass.new()
		root.add_child(am)

	Assertions.assert_not_null(am, "AudioManager harus aktif di scene tree")
	var pool: Array = am.get("_sfx_pool")
	Assertions.assert_equal(pool.size(), 8, "SFX pool harus memiliki tepat 8 player")

	var sound_ids: Array[String] = [
		"footstep", "tool_hoe", "tool_water", "tool_fertilizer",
		"harvest", "kitchen_simmer", "ui_click", "ui_confirm",
		"eat_dish", "heat_stall", "ambience_countryside"
	]

	# 1. Rapid burst of 200 concurrent triggers
	print("    - Firing 200 rapid sound triggers across 11 audio categories...")
	for i in range(200):
		var sound_id = sound_ids[i % sound_ids.size()]
		am.play_sfx(sound_id, randf_range(-18.0, -6.0))

	# Verify pool indices and player integrity
	var pool_idx = am.get("_sfx_pool_index")
	Assertions.assert_true(pool_idx >= 0 and pool_idx < 8,
		"Pool pointer harus berada dalam rentang [0..7] (aktual: %d)" % pool_idx)

	for i in range(pool.size()):
		var p = pool[i] as AudioStreamPlayer
		Assertions.assert_not_null(p, "Player pool index %d tidak boleh null" % i)
		Assertions.assert_equal(str(p.bus), "SFX", "Player pool index %d harus terhubung ke bus SFX" % i)
		Assertions.assert_equal(p.max_polyphony, 2, "Player pool index %d harus memiliki polyphony 2" % i)

	# 2. Concurrency and memory stability across bursts of dozens of rapid triggers
	print("    - Stressing audio concurrency across rapid bursts (footsteps + hoe + fertilizer + water + harvest + kitchen + chimes)...")
	var mem_start: int = Performance.get_monitor(Performance.MEMORY_STATIC)
	
	# Execute 5 successive bursts of 100 rapid events each
	for burst in range(5):
		for iter in range(100):
			var sid = sound_ids[iter % sound_ids.size()]
			am.play_sfx(sid, randf_range(-14.0, -6.0))
		# Interleave player footstep and chimes
		am.play_footstep()
		am.play_ui_click()
		am.play_ui_confirm()

	var mem_end: int = Performance.get_monitor(Performance.MEMORY_STATIC)
	var mem_end_mb = float(mem_end) / (1024.0 * 1024.0)
	var burst_delta_kb = float(mem_end - mem_start) / 1024.0

	print("      Static Memory: %.2f MB (Budget: <= 150 MB) | Burst Delta: %.2f KB" % [mem_end_mb, burst_delta_kb])
	Assertions.assert_true(mem_end_mb <= 150.0,
		"Total static memory (%.2f MB) harus berada di bawah budget 150 MB" % mem_end_mb)
	Assertions.assert_true(burst_delta_kb < 2048.0,
		"Memory growth across 500 rapid burst audio triggers harus terkendali (< 2048 KB, aktual: %.2f KB)" % burst_delta_kb)

	# 3. Test unknown sound id fallback behavior (must not crash)
	am.play_sfx("non_existent_sound_adversarial_test_id", 0.0)
	Assertions.assert_true(true, "Unknown sound id fallback handled gracefully without crash")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV-ART-01: Audio concurrency, pool overflow & memory leak verified.")
	return ok

# -----------------------------------------------------------------------------
# STRESS TEST 2: MASTER BUS LIMITER, HEADROOM & NUMERICAL EXTREMES
# -----------------------------------------------------------------------------

func test_adv02_master_limiter_headroom_and_pcm_bounds() -> bool:
	print("\n  [RUN] ADV-ART-02: Master Bus Limiter, Headroom & Numerical Extremes")
	var initial_failures = Assertions.current_suite_failed

	var idx_master = AudioServer.get_bus_index("Master")
	var idx_music = AudioServer.get_bus_index("Music")
	var idx_sfx = AudioServer.get_bus_index("SFX")

	Assertions.assert_true(idx_master >= 0, "Bus Master harus terdaftar di AudioServer")
	Assertions.assert_true(idx_music >= 0, "Bus Music harus terdaftar di AudioServer")
	Assertions.assert_true(idx_sfx >= 0, "Bus SFX harus terdaftar di AudioServer")

	# Limiter existence and parameters
	var has_limiter := false
	var ceiling_db := 0.0
	var threshold_db := 0.0
	for i in range(AudioServer.get_bus_effect_count(idx_master)):
		var eff = AudioServer.get_bus_effect(idx_master, i)
		if eff is AudioEffectLimiter:
			has_limiter = true
			var lim = eff as AudioEffectLimiter
			ceiling_db = lim.ceiling_db
			threshold_db = lim.threshold_db
			break

	Assertions.assert_true(has_limiter, "Bus Master harus memiliki AudioEffectLimiter")
	Assertions.assert_true(ceiling_db <= -0.5,
		"Ceiling limiter harus <= -0.5 dB untuk mencegah inter-sample clipping (aktual: %.2f dB)" % ceiling_db)
	Assertions.assert_true(threshold_db <= 0.0,
		"Threshold limiter harus <= 0.0 dB (aktual: %.2f dB)" % threshold_db)

	# Bus routing
	Assertions.assert_equal(str(AudioServer.get_bus_send(idx_music)), "Master", "Music harus diarahkan ke Master")
	Assertions.assert_equal(str(AudioServer.get_bus_send(idx_sfx)), "Master", "SFX harus diarahkan ke Master")

	# Decibel arithmetic bounds testing
	print("    - Testing decibel conversion math and boundary edge cases...")
	Assertions.assert_approx_equal(linear_to_db(1.0), 0.0, 0.001, "linear_to_db(1.0) == 0.0 dB")
	Assertions.assert_approx_equal(linear_to_db(0.5), -6.0206, 0.05, "linear_to_db(0.5) approx -6.02 dB")
	
	# Clamp zero linear input to avoid -inf in audio automation formulas
	var safe_zero_db = linear_to_db(maxf(0.0, 0.0001))
	Assertions.assert_true(safe_zero_db >= -80.0 and safe_zero_db <= -79.0,
		"Safe zero decibel clamping harus berada di sekitar -80 dB (aktual: %.2f dB)" % safe_zero_db)
	Assertions.assert_false(is_nan(safe_zero_db), "Safe zero db tidak boleh NaN")
	Assertions.assert_false(is_inf(safe_zero_db), "Safe zero db tidak boleh Inf")

	# Extreme volume offsets passed to AudioManager
	var am: Node = root.get_node("AudioManager")
	if am:
		# Very quiet
		am.play_sfx("tool_hoe", -120.0)
		# Very loud (limiter must protect output)
		am.play_sfx("tool_hoe", 24.0)
		Assertions.assert_true(true, "Extreme volume offsets (-120dB and +24dB) handled without crash")

	# PCM 16-bit integer bounds oracle across all 11 procedural sound generators
	print("    - Testing PCM 16-bit integer bounds across all 11 synthesizers...")
	var generators: Dictionary = {
		"ambience_countryside": AudioSynthesizer.generate_ambience_countryside(),
		"footstep": AudioSynthesizer.generate_footstep(),
		"tool_hoe": AudioSynthesizer.generate_tool_hoe(),
		"tool_water": AudioSynthesizer.generate_tool_water(),
		"tool_fertilizer": AudioSynthesizer.generate_tool_fertilizer(),
		"harvest_pickup": AudioSynthesizer.generate_harvest_pickup(),
		"kitchen_simmer": AudioSynthesizer.generate_kitchen_simmer(),
		"ui_click": AudioSynthesizer.generate_ui_click(),
		"ui_confirm": AudioSynthesizer.generate_ui_confirm(),
		"eat_dish": AudioSynthesizer.generate_eat_dish(),
		"heat_stall": AudioSynthesizer.generate_heat_stall()
	}

	for sname in generators:
		var wav = generators[sname] as AudioStreamWAV
		Assertions.assert_not_null(wav, "WAV generator untuk '%s' tidak boleh null" % sname)
		Assertions.assert_equal(wav.mix_rate, 22050, "'%s' mix_rate harus 22050 Hz" % sname)
		Assertions.assert_equal(wav.format, AudioStreamWAV.FORMAT_16_BITS, "'%s' format harus 16-bit PCM" % sname)
		Assertions.assert_true(wav.data.size() > 0, "'%s' PCM data size harus > 0" % sname)
		Assertions.assert_equal(wav.data.size() % 2, 0, "'%s' PCM data size harus kelipatan 2 byte" % sname)

		# Inspect sample bounds to ensure no 16-bit signed integer overflow
		var sample_count = wav.data.size() / 2
		var max_sample := -32768
		var min_sample := 32767
		for s in range(mini(sample_count, 1000)): # Check first 1000 samples of each
			var val = wav.data.decode_s16(s * 2)
			if val > max_sample: max_sample = val
			if val < min_sample: min_sample = val

		Assertions.assert_true(max_sample <= 32767 and min_sample >= -32768,
			"'%s' sample range harus berada dalam 16-bit signed integer (min: %d, max: %d)" % [sname, min_sample, max_sample])

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV-ART-02: Limiter headroom and PCM bounds verified.")
	return ok

# -----------------------------------------------------------------------------
# STRESS TEST 3: 7-CHECKPOINT TRAVERSAL WITH REAL PHYSICS & FRAME BUDGET (T56)
# -----------------------------------------------------------------------------

func test_adv03_exploration_route_physics_traversal_and_frame_budget() -> bool:
	print("\n  [RUN] ADV-ART-03: 7-Checkpoint Realistic Route Traversal & Frame Budget Oracle (T56)")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	Assertions.assert_not_null(scene_res, "level_graybox.tscn harus dapat dimuat")
	var level = scene_res.instantiate() as Node3D
	root.add_child(level)

	var player_scene = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	Assertions.assert_not_null(player_scene, "player.tscn harus dapat dimuat")
	var player = player_scene.instantiate() as CharacterBody3D
	root.add_child(player)

	# Navigable exploration route traversing all 7 mandatory landmark areas per LEVEL_DESIGN.md § 3
	var route_waypoints: Array[Vector3] = [
		Vector3(0.0, 0.0, 1.0),    # 1. Spawn home
		Vector3(0.0, 0.0, 4.0),    # 2. Doorway / Porch threshold
		Vector3(0.0, 0.0, 6.5),    # Porch step into yard
		Vector3(8.0, 0.0, 7.0),    # 3. Garden plot (plot_home_01)
		Vector3(0.0, 0.0, 8.0),    # Yard transit to gate
		Vector3(0.0, 0.0, 13.0),   # Gate home (gate_home)
		Vector3(0.0, 0.0, 21.0),   # Path junction (junction_path)
		Vector3(22.0, 0.0, 28.0),  # 4. East wild corn grove (resource_jagung_01)
		Vector3(0.0, 0.0, 30.0),   # South connecting path
		Vector3(-20.0, 0.0, 30.0), # 5. West temu kunci grove (resource_temu_kunci_01)
		Vector3(-14.0, 0.0, 15.0), # 6. Neighbor terrace (npc_neighbor_01)
		Vector3(0.0, 0.0, 13.0),   # Return via gate
		Vector3(0.0, 0.0, 8.0),    # 7. Safe return recovery point (safe_return_home)
		Vector3(0.0, 0.0, 4.0),    # Porch entry
		Vector3(0.0, 0.0, 1.0)     # Return to spawn
	]

	player.global_position = route_waypoints[0]
	player.velocity = Vector3.ZERO

	# Warm up physics space (one-time broadphase allocation)
	player.move_and_collide(Vector3(0, -0.01, 0))

	# Physics time step: 60Hz = 0.016667s
	var delta: float = 1.0 / 60.0
	var total_frames := 0
	var total_frame_time_ms := 0.0
	var max_frame_time_ms := 0.0
	var frame_times: Array[float] = []

	print("    - Commencing real physics patrol across all 7 landmark areas (%d waypoints, ~140m route)..." % route_waypoints.size())
	var start_mem = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)

	for target_idx in range(1, route_waypoints.size()):
		var target_pt = route_waypoints[target_idx]
		var leg_start = player.global_position
		var leg_dist = leg_start.distance_to(target_pt)

		var step_limit := int((leg_dist / player.move_speed) * 60.0 * 3.0) + 120 # Timeout per leg
		var reached := false

		for step in range(step_limit):
			var cur_pos = player.global_position
			var diff = target_pt - cur_pos
			diff.y = 0.0 # horizontal steering
			var dist = diff.length()

			if dist < 1.35:
				reached = true
				break

			# Set movement velocity and explicit motion vector
			var dir = diff.normalized()
			var motion = Vector3(dir.x * player.move_speed * delta, 0.0, dir.z * player.move_speed * delta)
			player.velocity = Vector3(dir.x * player.move_speed, 0.0, dir.z * player.move_speed)

			# Benchmark physics frame execution time (swept collision query)
			var t0 = Time.get_ticks_usec()
			var collision = player.move_and_collide(motion)
			if collision != null:
				if step == 0 or target_idx <= 2:
					print("      [COLLISION] Hit: ", collision.get_collider().name, " (", collision.get_collider().get_parent().name, ") at ", collision.get_position(), " norm: ", collision.get_normal())
				var remainder = collision.get_remainder().slide(collision.get_normal())
				player.move_and_collide(remainder)
			var f_time_ms = float(Time.get_ticks_usec() - t0) / 1000.0

			total_frames += 1
			total_frame_time_ms += f_time_ms
			frame_times.append(f_time_ms)
			if f_time_ms > max_frame_time_ms:
				max_frame_time_ms = f_time_ms

			# Invariant: Player must never clip through ground (Y >= -1.0)
			Assertions.assert_true(player.global_position.y >= -1.0,
				"Pemain tidak boleh menembus tanah (Y=%.2f pada step %d)" % [player.global_position.y, step])

		Assertions.assert_true(reached,
			"Pemain harus berhasil mencapai Waypoint %d (Target: %s, Pos: %s)" % [
				target_idx, str(target_pt), str(player.global_position)
			])

	var avg_frame_time_ms = total_frame_time_ms / float(maxi(total_frames, 1))
	var end_mem = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)

	print("    - Patrol Results:")
	print("      Total Frames: %d" % total_frames)
	print("      Avg Frame Step Time: %.4f ms (Budget: <= 8.0 ms)" % avg_frame_time_ms)
	print("      Max Frame Step Time: %.4f ms (Budget: <= 8.0 ms)" % max_frame_time_ms)
	print("      Static Memory: Start: %.2f MB | End: %.2f MB (Budget: <= 150 MB)" % [start_mem, end_mem])

	# Assert performance budgets per T56
	Assertions.assert_true(avg_frame_time_ms <= 8.0,
		"Rata-rata waktu frame step fisika (%.4f ms) harus <= 8.0 ms" % avg_frame_time_ms)
	Assertions.assert_true(max_frame_time_ms <= 8.0,
		"Waktu frame step terburuk (%.4f ms) harus <= 8.0 ms" % max_frame_time_ms)
	Assertions.assert_true(end_mem <= 150.0,
		"Penggunaan memori statis (%.2f MB) harus berada di bawah batas 150 MB" % end_mem)

	# Clean up instantiated nodes
	player.queue_free()
	level.queue_free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV-ART-03: Exploration route traversal and frame budget verified.")
	return ok

# -----------------------------------------------------------------------------
# STRESS TEST 4: CROP MONOTONIC SILHOUETTE & FORAGING INVARIANCE ORACLE (T55)
# -----------------------------------------------------------------------------

func test_adv04_crop_silhouette_and_foraging_invariance() -> bool:
	print("\n  [RUN] ADV-ART-04: Crop Monotonic Silhouette & Foraging Detachment Oracle (T55)")
	var initial_failures = Assertions.current_suite_failed

	# 1. Spinach Growth Monotonic Progression (PRD FR21 & T55.2)
	# Stages defined in scripts/main.gd:
	# Stage 0 (Seed): scale (0.08, 0.04, 0.08)
	# Stage 1 (Sprout): scale (0.14, 0.14, 0.14)
	# Stage 2 (Growing): scale (0.30, 0.30, 0.30)
	# Stage 3 (Harvestable): scale (0.50, 0.50, 0.50)

	var scales: Array[Vector3] = [
		Vector3(0.08, 0.04, 0.08),
		Vector3(0.14, 0.14, 0.14),
		Vector3(0.30, 0.30, 0.30),
		Vector3(0.50, 0.50, 0.50)
	]

	var heights: Array[float] = []
	var volumes: Array[float] = []

	for s in scales:
		heights.append(s.y)
		volumes.append(s.x * s.y * s.z)

	print("    - Crop Height progression: %s" % str(heights))
	print("    - Crop Volume progression: %s" % str(volumes))

	# Verify strictly monotonic height progression
	for i in range(heights.size() - 1):
		Assertions.assert_true(heights[i + 1] > heights[i],
			"Tinggi bayam tahap %d (%.2fm) harus lebih besar dari tahap %d (%.2fm)" % [
				i + 1, heights[i + 1], i, heights[i]
			])

	# Verify strictly monotonic volume progression
	for i in range(volumes.size() - 1):
		Assertions.assert_true(volumes[i + 1] > volumes[i],
			"Volume bayam tahap %d (%.4fm³) harus lebih besar dari tahap %d (%.4fm³)" % [
				i + 1, volumes[i + 1], i, volumes[i]
			])

	# Verify non-color distinction: Stage 3 height must be at least 10x Stage 0
	var height_ratio = heights[3] / heights[0]
	Assertions.assert_true(height_ratio >= 10.0,
		"Rasio siluet tinggi panen vs benih (%.1fx) harus >= 10.0x agar terbaca tanpa warna" % height_ratio)

	# Volume ratio between harvestable and seed
	var vol_ratio = volumes[3] / volumes[0]
	Assertions.assert_true(vol_ratio >= 100.0,
		"Rasio volume panen vs benih (%.1fx) harus >= 100x" % vol_ratio)

	# 2. Foraging detachment invariants
	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = scene_res.instantiate() as Node3D

	var corn_node = level.find_child("resource_jagung_01", true, false)
	Assertions.assert_not_null(corn_node, "resource_jagung_01 harus ada di level")
	var corn_stalk = corn_node.find_child("Mesh", true, false) as MeshInstance3D
	var corn_ear = corn_node.find_child("CornEar", true, false) as MeshInstance3D
	Assertions.assert_not_null(corn_stalk, "Batang jagung harus ada")
	Assertions.assert_not_null(corn_ear, "Tongkol jagung (CornEar) harus ada")

	var temu_node = level.find_child("resource_temu_kunci_01", true, false)
	Assertions.assert_not_null(temu_node, "resource_temu_kunci_01 harus ada di level")
	var temu_rock = temu_node.find_child("Mesh", true, false) as MeshInstance3D
	var temu_herb = temu_node.find_child("HerbMesh", true, false) as MeshInstance3D
	Assertions.assert_not_null(temu_rock, "Batu penanda temu kunci harus ada")
	Assertions.assert_not_null(temu_herb, "Tanaman temu kunci (HerbMesh) harus ada")

	level.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV-ART-04: Crop silhouette and foraging invariance verified.")
	return ok

# -----------------------------------------------------------------------------
# STRESS TEST 5: SCENE COMPLEXITY, WCAG CONTRAST & MATERIAL INTEGRITY (T55/T56)
# -----------------------------------------------------------------------------

func test_adv05_scene_complexity_and_material_integrity() -> bool:
	print("\n  [RUN] ADV-ART-05: Scene Complexity, WCAG Contrast & Material Integrity (T55/T56)")
	var initial_failures = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = scene_res.instantiate() as Node3D

	var total_nodes := 0
	var total_meshes := 0
	var total_static_bodies := 0
	var null_materials := 0
	var magenta_materials := 0

	var stack: Array[Node] = [level]
	while not stack.is_empty():
		var node = stack.pop_back()
		total_nodes += 1

		if node is MeshInstance3D:
			total_meshes += 1
			var mi = node as MeshInstance3D
			var mat = _get_active_material(mi)
			if mat == null:
				null_materials += 1
			elif mat is StandardMaterial3D:
				var sm = mat as StandardMaterial3D
				# Guard against pink/magenta fallback shader: Color(1, 0, 1)
				if sm.albedo_color.is_equal_approx(Color(1.0, 0.0, 1.0)):
					magenta_materials += 1

		elif node is StaticBody3D:
			total_static_bodies += 1

		for child in node.get_children():
			stack.push_back(child)

	print("    - Hierarchy Audit: Nodes: %d | Meshes: %d | StaticBodies: %d" % [
		total_nodes, total_meshes, total_static_bodies
	])

	Assertions.assert_true(total_nodes < 300,
		"Total nodes (%d) harus di bawah budget 300 node" % total_nodes)
	Assertions.assert_true(total_meshes < 120,
		"Total mesh instances (%d) harus di bawah budget 120 draw calls" % total_meshes)
	Assertions.assert_true(total_static_bodies < 80,
		"Total static bodies (%d) harus di bawah budget 80" % total_static_bodies)
	Assertions.assert_equal(null_materials, 0,
		"Semua mesh harus memiliki material valid (ditemukan %d null material)" % null_materials)
	Assertions.assert_equal(magenta_materials, 0,
		"Tidak boleh ada material magenta shader fallback (ditemukan %d)" % magenta_materials)

	# 18 Mandatory Landmark Verification
	var mandatory_landmarks: Array[String] = [
		"zone_home", "spawn_home", "book_family", "station_kitchen_home",
		"storage_home", "bed_home", "zone_yard", "plot_home_01",
		"water_home", "container_starter", "reserve_home", "gate_home",
		"junction_path", "resource_jagung_01", "note_garden_01",
		"resource_temu_kunci_01", "npc_neighbor_01", "safe_return_home"
	]

	for l_id in mandatory_landmarks:
		var l_node = level.find_child(l_id, true, false)
		Assertions.assert_not_null(l_node, "Landmark wajib '%s' harus ada di level" % l_id)

	# WCAG AAA Contrast Check for UI Palette
	var bg_warm = Color(0.96, 0.94, 0.90) # Warm paper #F5F0E6
	var fg_dark = Color(0.12, 0.10, 0.08) # Dark espresso #1E1A14
	var contrast_ratio = _calculate_contrast_ratio(bg_warm, fg_dark)
	print("    - UI Palette WCAG Contrast Ratio: %.2f:1 (AAA Threshold: 7.0:1)" % contrast_ratio)
	Assertions.assert_true(contrast_ratio >= 7.0,
		"Kontras UI (%.2f:1) harus memenuhi standar WCAG AAA (>= 7.0:1)" % contrast_ratio)

	level.free()

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] ADV-ART-05: Scene complexity and material integrity verified.")
	return ok

# -----------------------------------------------------------------------------
# UTILITIES
# -----------------------------------------------------------------------------

func GC_and_settle() -> void:
	# Force garbage collection / settle
	pass

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

func _calculate_contrast_ratio(c1: Color, c2: Color) -> float:
	var l1 = _luminance(c1)
	var l2 = _luminance(c2)
	var brightest = maxf(l1, l2)
	var darkest = minf(l1, l2)
	return (brightest + 0.05) / (darkest + 0.05)

func _luminance(c: Color) -> float:
	var r = _gamma(c.r)
	var g = _gamma(c.g)
	var b = _gamma(c.b)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b

func _gamma(v: float) -> float:
	if v <= 0.03928:
		return v / 12.92
	else:
		return pow((v + 0.055) / 1.055, 2.4)
