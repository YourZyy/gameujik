extends SceneTree

## Empirical Performance Challenger — Scene Budget & Stability Stress Harness
## Milestone: ART-001 (Iteration 3)
## Challenger: challenger_art_003_2
## Verifies scene tree budget, rendering complexity, process frame time,
## and memory stability across repeated stage rebuilds and state mutations.

const MainScript = preload("res://scripts/main.gd")

func _initialize() -> void:
	await run_benchmarks()

func run_benchmarks() -> void:
	print("==================================================")
	print("[EMPIRICAL_PERFORMANCE_CHALLENGER] ART-001 Stress Harness")
	print("==================================================")

	var failures: int = 0
	var total_checks: int = 0

	# --------------------------------------------------------------------------
	# TEST 1: Exact Scene Tree Hierarchy & Budget Metrics (level_graybox.tscn)
	# --------------------------------------------------------------------------
	print("\n--- TEST 1: Scene Tree Budget & Complexity ---")
	var scene_path := "res://scenes/world/level_graybox.tscn"
	var scene_res := ResourceLoader.load(scene_path) as PackedScene
	total_checks += 1
	if scene_res == null:
		print("FAIL: Could not load %s" % scene_path)
		failures += 1
		quit(1)
		return
	else:
		print("PASS: Successfully loaded %s" % scene_path)

	var level := scene_res.instantiate() as Node3D
	total_checks += 1
	if level == null:
		print("FAIL: Could not instantiate %s" % scene_path)
		failures += 1
		quit(1)
		return
	else:
		print("PASS: Successfully instantiated %s" % scene_path)

	var node_count := 0
	var mesh_count := 0
	var static_body_count := 0
	var collision_shape_count := 0
	var light_count := 0
	var world_env_count := 0
	var total_triangles := 0
	var total_vertices := 0

	var stack: Array[Node] = [level]
	while not stack.is_empty():
		var node = stack.pop_back()
		node_count += 1

		if node is MeshInstance3D:
			mesh_count += 1
			var mi := node as MeshInstance3D
			if mi.mesh != null:
				var arrays: Array = mi.mesh.get_mesh_arrays()
				if arrays.size() > Mesh.ARRAY_VERTEX:
					var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
					total_vertices += verts.size()
					if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
						var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
						total_triangles += indices.size() / 3
					else:
						total_triangles += verts.size() / 3
		elif node is StaticBody3D:
			static_body_count += 1
		elif node is CollisionShape3D:
			collision_shape_count += 1
		elif node is Light3D:
			light_count += 1
		elif node is WorldEnvironment:
			world_env_count += 1

		for child in node.get_children():
			stack.push_back(child)

	print("Scene Metrics for '%s':" % level.name)
	print("  - Total Nodes:             %d (Budget: <= 500, Spec: ~226)" % node_count)
	print("  - MeshInstance3D:          %d (Budget: <= 120, Spec: ~104)" % mesh_count)
	print("  - StaticBody3D:            %d (Budget: <= 80, Spec: ~33)" % static_body_count)
	print("  - CollisionShape3D:        %d" % collision_shape_count)
	print("  - Light3D:                 %d (Budget: <= 4)" % light_count)
	print("  - WorldEnvironment:        %d (Budget: <= 1)" % world_env_count)
	print("  - Total Geometry Vertices: %d" % total_vertices)
	print("  - Total Geometry Triangles:%d (Budget: <= 50,000)" % total_triangles)

	# Assertions on budgets
	total_checks += 1
	if node_count > 500:
		print("FAIL: Node count %d exceeds budget of 500" % node_count)
		failures += 1
	else:
		print("PASS: Node count %d is well within budget (<= 500)" % node_count)

	total_checks += 1
	if mesh_count > 120:
		print("FAIL: Mesh count %d exceeds draw call budget of 120" % mesh_count)
		failures += 1
	else:
		print("PASS: Mesh count %d is within budget (<= 120)" % mesh_count)

	total_checks += 1
	if static_body_count > 80:
		print("FAIL: StaticBody3D count %d exceeds physics budget of 80" % static_body_count)
		failures += 1
	else:
		print("PASS: StaticBody3D count %d is within budget (<= 80)" % static_body_count)

	total_checks += 1
	if total_triangles > 50000:
		print("FAIL: Total triangles %d exceeds budget of 50,000" % total_triangles)
		failures += 1
	else:
		print("PASS: Total triangles %d is low-poly optimized (<= 50,000)" % total_triangles)

	# --------------------------------------------------------------------------
	# TEST 2: Process Frame Execution Delta Profiling (1,000 Simulation Steps)
	# --------------------------------------------------------------------------
	print("\n--- TEST 2: Simulation Frame Delta & Process Budget Profiling ---")
	var sample_frames := 1000
	var step_delta: float = 1.0 / 60.0
	var frame_deltas: Array[float] = []

	# Warm up 20 frames
	for w in range(20):
		level.propagate_call("_process", [step_delta])
		level.propagate_call("_physics_process", [step_delta])

	var start_benchmark = Time.get_ticks_usec()
	for i in range(sample_frames):
		var t0 = Time.get_ticks_usec()
		level.propagate_call("_process", [step_delta])
		level.propagate_call("_physics_process", [step_delta])
		var elapsed_ms = (Time.get_ticks_usec() - t0) / 1000.0
		frame_deltas.append(elapsed_ms)
	var total_benchmark_ms = (Time.get_ticks_usec() - start_benchmark) / 1000.0

	var min_delta := 999999.0
	var max_delta := 0.0
	var sum_delta := 0.0
	for d in frame_deltas:
		if d < min_delta:
			min_delta = d
		if d > max_delta:
			max_delta = d
		sum_delta += d
	var avg_delta = sum_delta / float(sample_frames)

	frame_deltas.sort()
	var p95_delta = frame_deltas[int(sample_frames * 0.95)]
	var p99_delta = frame_deltas[int(sample_frames * 0.99)]

	print("Simulation Performance over %d frames:" % sample_frames)
	print("  - Min frame delta: %.4f ms" % min_delta)
	print("  - Avg frame delta: %.4f ms (Budget: <= 1.0 ms headless, <= 16.6 ms 60FPS)" % avg_delta)
	print("  - P95 frame delta: %.4f ms" % p95_delta)
	print("  - P99 frame delta: %.4f ms" % p99_delta)
	print("  - Max frame delta: %.4f ms (Budget: <= 16.67 ms)" % max_delta)
	print("  - Total run time:  %.2f ms" % total_benchmark_ms)

	total_checks += 1
	if avg_delta > 1.0:
		print("FAIL: Average frame delta %.4f ms exceeds headless target of 1.0 ms" % avg_delta)
		failures += 1
	else:
		print("PASS: Average frame delta %.4f ms is far below 1.0 ms headroom ceiling" % avg_delta)

	total_checks += 1
	if max_delta > 16.67:
		print("FAIL: Peak frame delta %.4f ms exceeds 60 FPS frame time of 16.67 ms" % max_delta)
		failures += 1
	else:
		print("PASS: Peak frame delta %.4f ms is strictly under 16.67 ms (60 FPS safe)" % max_delta)

	level.free()
	await process_frame

	# --------------------------------------------------------------------------
	# TEST 3: Memory Stability & Leak Analysis across Repeated Crop Rebuilds
	# --------------------------------------------------------------------------
	print("\n--- TEST 3: Crop Stage Rebuild Memory Stability (100 Cycles) ---")
	var main_inst = MainScript.new()
	var rebuild_cycles := 100

	# Ensure idle message queue is completely flushed before baseline
	await process_frame
	await process_frame
	var mem_initial = Performance.get_monitor(Performance.MEMORY_STATIC)
	var obj_initial = Performance.get_monitor(Performance.OBJECT_COUNT)
	var node_initial = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	print("Initial baseline: Static Memory = %.2f MB, Objects = %d, Nodes = %d" % [
		mem_initial / (1024.0 * 1024.0), obj_initial, node_initial
	])

	for cycle in range(rebuild_cycles):
		var crop_root := Node3D.new()
		crop_root.name = "CropMesh"
		root.add_child(crop_root)
		# Cycle through all 4 growth stages repeatedly
		for stage in range(4):
			main_inst._rebuild_crop_stage(crop_root, stage)
		# Clean up
		crop_root.queue_free()
		# Allow engine to process queued deletions periodically
		if (cycle + 1) % 10 == 0:
			await process_frame

	await process_frame
	await process_frame
	main_inst.free()
	await process_frame

	var mem_final = Performance.get_monitor(Performance.MEMORY_STATIC)
	var mem_diff_bytes = mem_final - mem_initial
	var mem_diff_mb = mem_diff_bytes / (1024.0 * 1024.0)
	print("Post-rebuild: Static Memory = %.2f MB (Delta: %+.3f MB across %d cycles)" % [
		mem_final / (1024.0 * 1024.0), mem_diff_mb, rebuild_cycles
	])

	total_checks += 1
	# Delta across 100 cycles of creating and destroying nodes should be minimal (< 0.5 MB)
	if mem_diff_mb > 0.5:
		print("FAIL: Memory leak detected! Static memory grew by %.3f MB" % mem_diff_mb)
		failures += 1
	else:
		print("PASS: Memory stability confirmed: static memory delta is %.3f MB (< 0.5 MB threshold)" % mem_diff_mb)

	# --------------------------------------------------------------------------
	# TEST 4: Full Game Scene Rapid Garden State Thrashing (500 Iterations)
	# --------------------------------------------------------------------------
	print("\n--- TEST 4: Rapid Garden Plot State Thrashing Stress Test (500 Iterations) ---")
	var main_scene_res = ResourceLoader.load("res://scenes/main.tscn") as PackedScene
	total_checks += 1
	if main_scene_res == null:
		print("FAIL: Could not load res://scenes/main.tscn")
		failures += 1
		quit(1)
		return

	var main_node = main_scene_res.instantiate()
	root.add_child(main_node)
	if main_node.get("level") == null:
		main_node.set("level", main_node.get_node_or_null("LevelGraybox"))

	var plot_node = main_node.get_node_or_null("LevelGraybox/plot_home_01")
	total_checks += 1
	if plot_node == null:
		print("FAIL: plot_home_01 not found in main LevelGraybox")
		failures += 1
	else:
		print("PASS: plot_home_01 located in main scene")

	await process_frame
	await process_frame
	var mem_before_thrash = Performance.get_monitor(Performance.MEMORY_STATIC)
	var thrash_iterations := 500

	for it in range(thrash_iterations):
		var st := it % 5
		var plot_data: Dictionary
		if st == 0:
			plot_data = {"is_hoed": false, "has_compost": false, "moisture": 0.0, "spots": {"slot_01": {"is_occupied": false}}}
		elif st == 1:
			plot_data = {"is_hoed": true, "has_compost": false, "moisture": 10.0, "spots": {"slot_01": {"is_occupied": true, "crop_data": {"crop_id": "crop_bayam_01", "growth_stage": 0}}}}
		elif st == 2:
			plot_data = {"is_hoed": true, "has_compost": true, "moisture": 30.0, "spots": {"slot_01": {"is_occupied": true, "crop_data": {"crop_id": "crop_bayam_01", "growth_stage": 1}}}}
		elif st == 3:
			plot_data = {"is_hoed": true, "has_compost": true, "moisture": 60.0, "spots": {"slot_01": {"is_occupied": true, "crop_data": {"crop_id": "crop_bayam_01", "growth_stage": 2}}}}
		else:
			plot_data = {"is_hoed": true, "has_compost": true, "moisture": 80.0, "spots": {"slot_01": {"is_occupied": true, "crop_data": {"crop_id": "crop_bayam_01", "growth_stage": 3}}}}

		main_node._on_garden_plot_state_changed("plot_home_01", plot_data)

		# In realistic gameplay, frames process between state updates
		if (it + 1) % 25 == 0:
			await process_frame

	# Flush any remaining message queue deletions
	await process_frame
	await process_frame
	await process_frame

	var mem_after_thrash = Performance.get_monitor(Performance.MEMORY_STATIC)
	var thrash_delta_mb = (mem_after_thrash - mem_before_thrash) / (1024.0 * 1024.0)
	print("Garden State Thrashing (500 state updates): Delta = %+.3f MB" % thrash_delta_mb)

	total_checks += 1
	if thrash_delta_mb > 0.5:
		print("FAIL: Progressive leak during rapid garden state updates: %+.3f MB" % thrash_delta_mb)
		failures += 1
	else:
		print("PASS: Zero progressive leak during 500 rapid garden state updates (Delta: %+.3f MB)" % thrash_delta_mb)

	# Verify final spot node has exactly one CropMesh and no leftover dangling orphan instances
	var spot_0 = plot_node.get_node_or_null("spot_0")
	var crop_mesh_nodes := 0
	if spot_0 != null:
		for ch in spot_0.get_children():
			if ch.name == "CropMesh":
				crop_mesh_nodes += 1
	total_checks += 1
	if crop_mesh_nodes != 1:
		print("FAIL: Expected exactly 1 CropMesh in spot_0, got %d" % crop_mesh_nodes)
		failures += 1
	else:
		print("PASS: Exactly 1 clean CropMesh in spot_0 (no leaked duplicate node instances)")

	root.remove_child(main_node)
	main_node.queue_free()
	await process_frame

	# --------------------------------------------------------------------------
	# SUMMARY & VERDICT
	# --------------------------------------------------------------------------
	print("\n==================================================")
	print("[EMPIRICAL_PERFORMANCE_CHALLENGER] SUMMARY:")
	print("  Total Checks Executed: %d" % total_checks)
	print("  Failures Encountered:  %d" % failures)
	if failures == 0:
		print("  VERDICT: ALL PERFORMANCE & BUDGET CHECKS PASSED (APPROVE)")
		print("==================================================")
		quit(0)
	else:
		print("  VERDICT: PERFORMANCE BUDGET FAILURES DETECTED (REJECT)")
		print("==================================================")
		quit(1)
