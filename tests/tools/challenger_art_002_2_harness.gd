class_name ChallengerArt002Harness
extends SceneTree

## Empirical Challenger Art & Complexity Stress Harness (challenger_art_002_2)
## Milestone: ART-001
## Adversarial verification of:
## 1. Scene complexity budgets (< 300 nodes, < 120 meshes, < 80 static bodies)
## 2. Frame time simulation across 60+ steps with full hierarchy traversal (< 8.0 ms avg)
## 3. Memory stability and ObjectDB retention during repetitive instantiation/free cycles
## 4. Multi-primitive crop geometry invariants and material cache deduplication

var test_passed := true
var failure_reasons: Array[String] = []

func log_fail(msg: String) -> void:
	test_passed = false
	failure_reasons.append(msg)
	printerr("  [FAIL] " + msg)

func _initialize() -> void:
	print("==================================================")
	print("[CHALLENGER_ART_002] Adversarial Empirical Verification Harness")
	print("==================================================")
	
	run_verification()

func run_verification() -> void:
	# 1. Scene Complexity & Low-End Desktop Budget
	test_scene_complexity_budget()
	
	# 2. Simulation Frame Time Stress (60Hz, 120Hz, Erratic Deltas)
	test_simulation_frame_time_stress()
	
	# 3. Memory Stability & ObjectDB Retention Under Instantiation Churn
	await test_memory_and_objectdb_retention()
	
	# 4. Multi-Primitive Crop Geometry & Material Cache Invariants
	await test_crop_geometry_and_material_cache()
	
	# 5. Isolated TestArt Suite 24 & ObjectDB Stability
	await test_isolated_test_art_suite()
	
	# Summary
	print("==================================================")
	print("[CHALLENGER_ART_002] SUMMARY:")
	if test_passed and failure_reasons.is_empty():
		print("  RESULT: ALL CHALLENGER CHECKS PASSED (VERDICT: APPROVE)")
		print("==================================================")
		quit(0)
	else:
		printerr("  RESULT: CHALLENGER FAILURES ENCOUNTERED (VERDICT: REJECT)")
		for reason in failure_reasons:
			printerr("    - " + reason)
		print("==================================================")
		quit(1)

func test_scene_complexity_budget() -> void:
	print("\n--- [TEST 1] Scene Complexity & Desktop Budget Verification ---")
	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	if scene_res == null:
		log_fail("Failed to load res://scenes/world/level_graybox.tscn")
		return
	
	var level = scene_res.instantiate() as Node3D
	if level == null:
		log_fail("Failed to instantiate level_graybox.tscn")
		return
	
	var total_nodes := 0
	var mesh_instances := 0
	var static_bodies := 0
	var collision_shapes := 0
	var area3d_count := 0
	var lights_count := 0
	
	var hierarchy_breakdown: Dictionary = {}
	
	var stack: Array[Node] = [level]
	while not stack.is_empty():
		var node = stack.pop_back()
		total_nodes += 1
		
		# Category tally
		if node is MeshInstance3D:
			mesh_instances += 1
		elif node is StaticBody3D:
			static_bodies += 1
		elif node is CollisionShape3D:
			collision_shapes += 1
		elif node is Area3D:
			area3d_count += 1
		elif node is Light3D:
			lights_count += 1
			
		# Record immediate children under root
		if node.get_parent() == level:
			hierarchy_breakdown[node.name] = _count_subtree(node)
			
		for child in node.get_children():
			stack.push_back(child)
			
	print("  Level Hierarchy Breakdown:")
	for group_name in hierarchy_breakdown:
		print("    - %s: %d nodes" % [group_name, hierarchy_breakdown[group_name]])
		
	print("  Total Node Count: %d (Budget: < 300)" % total_nodes)
	print("  MeshInstance3D Count: %d (Budget: < 120)" % mesh_instances)
	print("  StaticBody3D Count: %d (Budget: < 80)" % static_bodies)
	print("  CollisionShape3D Count: %d" % collision_shapes)
	print("  Area3D Count: %d" % area3d_count)
	print("  Light3D Count: %d" % lights_count)
	
	if total_nodes >= 300:
		log_fail("Total nodes %d exceeds budget of 300" % total_nodes)
	if mesh_instances >= 120:
		log_fail("Total MeshInstance3D %d exceeds budget of 120" % mesh_instances)
	if static_bodies >= 80:
		log_fail("Total StaticBody3D %d exceeds budget of 80" % static_bodies)
		
	level.free()

func _count_subtree(root: Node) -> int:
	var count := 1
	for child in root.get_children():
		count += _count_subtree(child)
	return count

func test_simulation_frame_time_stress() -> void:
	print("\n--- [TEST 2] Simulation Frame Time Stress Across 120+ Steps ---")
	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	var level = scene_res.instantiate() as Node3D
	
	# Warm-up 10 steps
	for i in range(10):
		level.propagate_call("_process", [0.016667])
		level.propagate_call("_physics_process", [0.016667])
		
	# Phase A: 60Hz delta (60 steps)
	var timings_60hz: Array[float] = []
	for i in range(60):
		var t0 = Time.get_ticks_usec()
		level.propagate_call("_process", [0.016667])
		level.propagate_call("_physics_process", [0.016667])
		var elapsed_ms = (Time.get_ticks_usec() - t0) / 1000.0
		timings_60hz.append(elapsed_ms)
		
	# Phase B: 120Hz delta (60 steps)
	var timings_120hz: Array[float] = []
	for i in range(60):
		var t0 = Time.get_ticks_usec()
		level.propagate_call("_process", [0.008333])
		level.propagate_call("_physics_process", [0.008333])
		var elapsed_ms = (Time.get_ticks_usec() - t0) / 1000.0
		timings_120hz.append(elapsed_ms)
		
	# Phase C: Adversarial erratic delta (30 steps, deltas from 0.001 to 0.1s)
	var timings_erratic: Array[float] = []
	for i in range(30):
		var delta: float = 0.001 * ((i % 10) + 1) * 5.0 # 0.005 to 0.05
		var t0 = Time.get_ticks_usec()
		level.propagate_call("_process", [delta])
		level.propagate_call("_physics_process", [delta])
		var elapsed_ms = (Time.get_ticks_usec() - t0) / 1000.0
		timings_erratic.append(elapsed_ms)
		
	var all_timings = timings_60hz + timings_120hz + timings_erratic
	var total_time := 0.0
	var max_spike := 0.0
	for t in all_timings:
		total_time += t
		if t > max_spike:
			max_spike = t
			
	var avg_frame = total_time / float(all_timings.size())
	print("  Total Simulation Steps Tested: %d" % all_timings.size())
	print("  Average Step Execution Time: %.4f ms (Budget: <= 8.0 ms)" % avg_frame)
	print("  Maximum Step Spike: %.4f ms (Budget: <= 16.67 ms)" % max_spike)
	
	if avg_frame > 8.0:
		log_fail("Average simulation step time %.4f ms exceeds 8.0 ms budget" % avg_frame)
	if max_spike > 16.67:
		log_fail("Maximum step spike %.4f ms exceeds 16.67 ms 60FPS frame budget" % max_spike)
		
	level.free()

func test_memory_and_objectdb_retention() -> void:
	print("\n--- [TEST 3] Memory Stability & ObjectDB Retention Under Churn ---")
	
	# Initial GC & Frame Flush
	await process_frame
	await process_frame
	
	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	
	# Warmup cycle to populate resource cache
	var warmup = scene_res.instantiate() as Node3D
	root.add_child(warmup)
	warmup.propagate_call("_process", [0.016])
	root.remove_child(warmup)
	warmup.free()
	await process_frame
	await process_frame
	
	var base_mem = Performance.get_monitor(Performance.MEMORY_STATIC)
	var base_obj = Performance.get_monitor(Performance.OBJECT_COUNT)
	var base_nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	
	print("  Post-Warmup Baseline: Static Mem = %.2f MB, Objects = %d, Nodes = %d" % [
		base_mem / (1024.0 * 1024.0), base_obj, base_nodes
	])
	
	# Measure at cycle 10 and cycle 30 to test for progressive growth
	var mem_at_10: int = 0
	var obj_at_10: int = 0
	
	for i in range(30):
		var lvl = scene_res.instantiate() as Node3D
		root.add_child(lvl)
		lvl.propagate_call("_process", [0.016])
		root.remove_child(lvl)
		lvl.free()
		if i == 9:
			await process_frame
			await process_frame
			mem_at_10 = Performance.get_monitor(Performance.MEMORY_STATIC)
			obj_at_10 = Performance.get_monitor(Performance.OBJECT_COUNT)
		
	await process_frame
	await process_frame
	
	var post_level_mem = Performance.get_monitor(Performance.MEMORY_STATIC)
	var post_level_obj = Performance.get_monitor(Performance.OBJECT_COUNT)
	var post_level_nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	
	var mem_growth_mb = (post_level_mem - base_mem) / (1024.0 * 1024.0)
	var obj_delta = post_level_obj - base_obj
	var node_delta = post_level_nodes - base_nodes
	var progressive_growth_mb = (post_level_mem - mem_at_10) / (1024.0 * 1024.0)
	var progressive_obj_delta = post_level_obj - obj_at_10
	
	print("  After 30 Level Graybox Cycles:")
	print("    Static Mem: %.2f MB (Total Growth: %+.2f MB, Cycle 10->30 Growth: %+.2f MB)" % [
		post_level_mem / (1024.0 * 1024.0), mem_growth_mb, progressive_growth_mb
	])
	print("    Objects: %d (Total Delta: %+d, Cycle 10->30 Delta: %+d)" % [
		post_level_obj, obj_delta, progressive_obj_delta
	])
	print("    Nodes: %d (Delta: %+d)" % [post_level_nodes, node_delta])
	
	if progressive_growth_mb > 1.0:
		log_fail("Progressive memory growth %.2f MB between cycle 10 and 30 exceeds 1.0 MB" % progressive_growth_mb)
	if progressive_obj_delta > 10:
		log_fail("Progressive ObjectDB leak: %+d objects retained between cycle 10 and 30" % progressive_obj_delta)
	if node_delta != 0:
		log_fail("Node leak detected: %+d nodes retained after free" % node_delta)
		
	# Static memory absolute check
	var current_static_mb = post_level_mem / (1024.0 * 1024.0)
	if current_static_mb >= 150.0:
		log_fail("Static memory usage %.2f MB exceeds 150 MB ceiling" % current_static_mb)

func test_crop_geometry_and_material_cache() -> void:
	print("\n--- [TEST 4] Multi-Primitive Crop Geometry & Material Cache Stress ---")
	
	var main_scene = ResourceLoader.load("res://scenes/main.tscn") as PackedScene
	if main_scene == null:
		log_fail("Failed to load res://scenes/main.tscn")
		return
		
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	
	var expected_primitives = {
		0: {"count": 2, "name": "Seed (Benih)", "min_h": 0.03, "max_h": 0.05, "key_node": "BaseMound"},
		1: {"count": 3, "name": "Sprout (Tunas)", "min_h": 0.12, "max_h": 0.16, "key_node": "CotyledonLeft"},
		2: {"count": 7, "name": "Growing (Tumbuh)", "min_h": 0.28, "max_h": 0.32, "key_node": "Leaf_0"},
		3: {"count": 10, "name": "Harvestable (Siap Panen)", "min_h": 0.48, "max_h": 0.52, "key_node": "FloweringPlume"}
	}
	
	# Rapid cycling across all 4 spots through all 4 stages for 10 iterations (160 transitions)
	for cycle in range(10):
		for spot_idx in range(4):
			for stage in range(4):
				var spot_info = {
					"is_occupied": true,
					"crop_data": {
						"growth_stage": stage,
						"effective_time": float(stage * 60)
					}
				}
				var spot_node: Node3D = null
				if main.level != null:
					spot_node = main.level.get_node_or_null("plot_home_01/spot_%d" % spot_idx) as Node3D
				if spot_node == null:
					spot_node = main.find_child("spot_%d" % spot_idx, true, false) as Node3D
				if spot_node == null:
					log_fail("Could not find spot_%d in main scene" % spot_idx)
					break
					
				main._update_crop_spot_visual(spot_node, spot_info)
				
				# In cycle 0, verify exact structural invariants
				if cycle == 0:
					var crop_mesh = spot_node.get_node_or_null("CropMesh")
					if crop_mesh == null:
						log_fail("Spot%d missing CropMesh after update to stage %d" % [spot_idx, stage])
						continue
						
					# 1. Scale must remain uniform Vector3(1, 1, 1)
					if not crop_mesh.scale.is_equal_approx(Vector3(1, 1, 1)):
						log_fail("Spot%d CropMesh scale %s is not uniform Vector3(1,1,1) at stage %d" % [
							spot_idx, str(crop_mesh.scale), stage
						])
						
					# 2. Child primitive count
					var expected = expected_primitives[stage]
					var child_count = crop_mesh.get_child_count()
					if child_count != expected["count"]:
						log_fail("Stage %d (%s) expected %d primitives, found %d on spot_%d" % [
							stage, expected["name"], expected["count"], child_count, spot_idx
						])
						
					# 3. Key node presence
					var key_node = crop_mesh.get_node_or_null(expected["key_node"])
					if key_node == null:
						log_fail("Stage %d missing expected key node %s on spot_%d" % [
							stage, expected["key_node"], spot_idx
						])
						
					# 4. Height metadata
					var h = crop_mesh.get_meta("crop_height", 0.0)
					if h < expected["min_h"] or h > expected["max_h"]:
						log_fail("Stage %d crop_height %.3f out of range [%.2f, %.2f]" % [
							stage, h, expected["min_h"], expected["max_h"]
						])
						
	# Check Material Cache Deduplication
	var mat_cache: Dictionary = main.get("_crop_mat_cache")
	print("  Crop Material Cache Entry Count: %d entries" % mat_cache.size())
	# There should only be a small number of cached materials (around 5: 1 brown, 1 lime, 1 green, 1 dark green, 1 plume)
	if mat_cache.size() > 10:
		log_fail("Crop material cache size %d unexpectedly large (possible cache key leak)" % mat_cache.size())
	elif mat_cache.size() >= 4:
		print("  [PASS] Crop materials correctly cached and reused across 160 stage transitions.")
		
	root.remove_child(main)
	main.free()

func test_isolated_test_art_suite() -> void:
	print("\n--- [TEST 5] Isolated TestArt (Suite 24) Execution & ObjectDB Retention ---")
	var Assertions = preload("res://tests/assertions.gd")
	var TestArt = preload("res://tests/suites/test_art.gd")
	
	await process_frame
	await process_frame
	
	var base_mem = Performance.get_monitor(Performance.MEMORY_STATIC)
	var base_obj = Performance.get_monitor(Performance.OBJECT_COUNT)
	var base_nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	
	var initial_failures = Assertions.current_suite_failed
	var suite := TestArt.new()
	var success := suite.run_all()
	
	await process_frame
	await process_frame
	
	var post_mem = Performance.get_monitor(Performance.MEMORY_STATIC)
	var post_obj = Performance.get_monitor(Performance.OBJECT_COUNT)
	var post_nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	
	print("  TestArt Execution Result: %s" % ("PASSED" if success else "FAILED"))
	print("  Static Memory: %.2f MB -> %.2f MB (Delta: %+.2f MB)" % [
		base_mem / (1024.0 * 1024.0), post_mem / (1024.0 * 1024.0), (post_mem - base_mem) / (1024.0 * 1024.0)
	])
	print("  ObjectDB Count: %d -> %d (Delta: %+d)" % [base_obj, post_obj, post_obj - base_obj])
	print("  Scene Nodes: %d -> %d (Delta: %+d)" % [base_nodes, post_nodes, post_nodes - base_nodes])
	
	if not success or Assertions.current_suite_failed != initial_failures:
		log_fail("Suite 24 (TestArt) reported assertion failures")
	if (post_nodes - base_nodes) != 0:
		log_fail("Suite 24 leaked %+d scene nodes" % (post_nodes - base_nodes))

