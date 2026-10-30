class_name TestInteraction
extends RefCounted

## Test Suite INT-001: Target Interaksi, Prompt UI, Occlusion dan Pengendali Konteks Input
## Memverifikasi PRD FR02, UI_UX.md § 3/4, PROTOTYPE.md § 5, dan TEST_PLAN T18/T27/T28

const Assertions = preload("res://tests/assertions.gd")
const InteractableClass = preload("res://scripts/interaction/interactable.gd")
const InteractionDetectorClass = preload("res://scripts/interaction/interaction_detector.gd")
const InteractionPromptClass = preload("res://scripts/ui/interaction_prompt.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")
const LevelGrayboxClass = preload("res://scripts/world/level_graybox.gd")

func run_all() -> bool:
	var passed := true
	print("  Running TestInteraction suite (T18, T27, T28)...")

	var tree := Engine.get_main_loop() as SceneTree

	if not test_interactable_component_properties():
		passed = false
	if not test_detector_configuration():
		passed = false
	if not test_ui_prompt_hierarchy_and_anchors():
		passed = false
	if not test_ui_prompt_visibility_and_text():
		passed = false
	if not test_player_scene_has_interaction_detector():
		passed = false
	if not test_t27_landmark_interactables_in_graybox():
		passed = false
	if not test_t28_input_manager_context_stack():
		passed = false
	if not test_t28_input_manager_player_gating():
		passed = false
	if not test_t28_bleed_through_prevention():
		passed = false
	if not test_t28_simulation_pause_rules():
		passed = false

	# Async physics raycast tests (T18, T27)
	if not await test_t18_range_acquisition_at_2m(tree):
		passed = false
	if not await test_t18_interaction_execution_and_signals(tree):
		passed = false
	if not await test_t27_wall_occlusion(tree):
		passed = false

	return passed

func test_interactable_component_properties() -> bool:
	print("    [RUN] INT-01: Interactable Area3D Properties, Formatting & State")
	var initial_failures: int = Assertions.current_suite_failed

	var area = InteractableClass.new()
	area._ready()

	# 1. Collision settings
	Assertions.assert_equal(area.collision_layer, 4, "Interactable must be on Layer 3 (bitmask 4)")
	Assertions.assert_equal(area.collision_mask, 0, "Interactable must have collision_mask 0")
	Assertions.assert_false(area.monitoring, "Interactable monitoring must be false")
	Assertions.assert_true(area.monitorable, "Interactable monitorable must be true")

	# 2. Defaults
	Assertions.assert_true(area.enabled, "Default enabled must be true")
	Assertions.assert_true(area.is_interactable, "Default is_interactable must be true")
	Assertions.assert_true(area.is_enabled(), "is_enabled() must return true")
	Assertions.assert_equal(area.prompt_action, "Periksa", "Default prompt_action is 'Periksa'")

	# 3. Prompt formatting
	area.target_name = "Peti"
	Assertions.assert_equal(area.get_prompt_text(), "[E] Periksa Peti", "Prompt text with target_name")
	area.target_name = ""
	Assertions.assert_equal(area.get_prompt_text(), "[E] Periksa", "Prompt text without target_name")

	# 4. set_prompt helper
	area.set_prompt("[E] Buka")
	Assertions.assert_equal(area.prompt_action, "Buka", "set_prompt sets prompt_action")
	Assertions.assert_equal(area.get_prompt_text(), "[E] Buka", "get_prompt_text returns [E] Buka")

	# 5. Signal emission on interact
	var dummy_player = Node3D.new()
	var signal_received := [false]
	area.interacted.connect(func(p): signal_received[0] = (p == dummy_player))
	var res = area.interact(dummy_player)
	Assertions.assert_true(res, "interact() returns true when enabled")
	Assertions.assert_true(signal_received[0], "interacted signal emitted with player reference")

	# 6. Disabled state rejection
	area.set_enabled(false)
	Assertions.assert_false(area.is_enabled(), "is_enabled() returns false when disabled")
	var res_disabled = area.interact(dummy_player)
	Assertions.assert_false(res_disabled, "interact() returns false when disabled")

	dummy_player.free()
	area.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] INT-01: Interactable Area3D passed.")
	else:
		printerr("    [FAIL] INT-01: Interactable Area3D failed.")
	return ok

func test_detector_configuration() -> bool:
	print("    [RUN] INT-02: InteractionDetector RayCast3D Configuration")
	var initial_failures: int = Assertions.current_suite_failed

	var detector = InteractionDetectorClass.new()
	detector._ready()

	# 1. Physics properties
	Assertions.assert_vector3_approx_equal(detector.target_position, Vector3(0.0, 0.0, -2.0), 0.001, "target_position is (0, 0, -2.0)")
	Assertions.assert_approx_equal(detector.max_interaction_distance, 2.0, 0.001, "max_interaction_distance is 2.0m")
	Assertions.assert_equal(detector.collision_mask, 5, "collision_mask must be 5 (Layer 1 Environment + Layer 3 Interactables)")
	Assertions.assert_true(detector.collide_with_areas, "collide_with_areas must be true")
	Assertions.assert_true(detector.collide_with_bodies, "collide_with_bodies must be true")
	Assertions.assert_true(detector.enabled, "enabled must be true")
	Assertions.assert_true(detector.interaction_enabled, "interaction_enabled must be true")

	# 2. Dynamic distance adjustment
	detector.max_interaction_distance = 1.5
	Assertions.assert_vector3_approx_equal(detector.target_position, Vector3(0.0, 0.0, -1.5), 0.001, "target_position updates with max_interaction_distance")

	detector.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] INT-02: InteractionDetector configuration passed.")
	else:
		printerr("    [FAIL] INT-02: InteractionDetector configuration failed.")
	return ok

func test_ui_prompt_hierarchy_and_anchors() -> bool:
	print("    [RUN] INT-03: UI Prompt Hierarchy, Anchors & Mouse Filter")
	var initial_failures: int = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/ui/interaction_prompt.tscn") as PackedScene
	Assertions.assert_not_null(scene_res, "interaction_prompt.tscn must load")

	var prompt_ui = scene_res.instantiate() as CanvasLayer
	Assertions.assert_not_null(prompt_ui, "interaction_prompt.tscn must instantiate")
	Assertions.assert_equal(prompt_ui.layer, 1, "CanvasLayer layer must be 1")

	var root_ctrl = prompt_ui.find_child("RootControl", true, false) as Control
	Assertions.assert_not_null(root_ctrl, "RootControl must exist")
	Assertions.assert_equal(root_ctrl.mouse_filter, Control.MOUSE_FILTER_IGNORE, "RootControl mouse_filter must be MOUSE_FILTER_IGNORE (2)")

	var reticle = prompt_ui.find_child("Reticle", true, false) as Control
	Assertions.assert_not_null(reticle, "Reticle must exist")
	Assertions.assert_equal(reticle.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Reticle mouse_filter must be MOUSE_FILTER_IGNORE")

	var panel = prompt_ui.find_child("PromptPanel", true, false) as PanelContainer
	Assertions.assert_not_null(panel, "PromptPanel must exist")
	Assertions.assert_equal(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE, "PromptPanel mouse_filter must be MOUSE_FILTER_IGNORE")
	Assertions.assert_true(panel.offset_top >= 36.0, "PromptPanel is placed below center (offset_top >= 36.0)")

	var label = prompt_ui.find_child("PromptLabel", true, false) as Label
	Assertions.assert_not_null(label, "PromptLabel must exist")
	Assertions.assert_equal(label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "PromptLabel mouse_filter must be MOUSE_FILTER_IGNORE")

	prompt_ui.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] INT-03: UI prompt hierarchy passed.")
	else:
		printerr("    [FAIL] INT-03: UI prompt hierarchy failed.")
	return ok

func test_ui_prompt_visibility_and_text() -> bool:
	print("    [RUN] INT-04: UI Prompt Visibility and Text API")
	var initial_failures: int = Assertions.current_suite_failed

	var prompt_ui = InteractionPromptClass.new()
	var root_ctrl = Control.new()
	root_ctrl.name = "RootControl"
	prompt_ui.add_child(root_ctrl)
	var panel = PanelContainer.new()
	panel.name = "PromptPanel"
	root_ctrl.add_child(panel)
	var label = Label.new()
	label.name = "PromptLabel"
	panel.add_child(label)

	prompt_ui._ready()

	# 1. Initial state hidden
	Assertions.assert_false(prompt_ui.is_prompt_visible(), "Initial prompt is not visible")

	# 2. show_prompt
	prompt_ui.show_prompt("[E] Ambil Air")
	Assertions.assert_true(prompt_ui.is_prompt_visible(), "Prompt becomes visible after show_prompt")
	Assertions.assert_equal(prompt_ui.get_prompt_text(), "[E] Ambil Air", "Prompt text matches show_prompt parameter")

	# 3. hide_prompt
	prompt_ui.hide_prompt()
	Assertions.assert_false(prompt_ui.is_prompt_visible(), "Prompt is hidden after hide_prompt")

	prompt_ui.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] INT-04: UI prompt visibility API passed.")
	else:
		printerr("    [FAIL] INT-04: UI prompt visibility API failed.")
	return ok

func test_player_scene_has_interaction_detector() -> bool:
	print("    [RUN] INT-05: Player Scene InteractionDetector Attachment")
	var initial_failures: int = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/player/player.tscn") as PackedScene
	Assertions.assert_not_null(scene_res, "Player scene must load")

	var player = scene_res.instantiate() as CharacterBody3D
	Assertions.assert_not_null(player, "Player must instantiate")

	var detector = player.find_child("InteractionDetector", true, false) as RayCast3D
	Assertions.assert_not_null(detector, "InteractionDetector must exist as child of Camera3D in player.tscn")
	if detector:
		Assertions.assert_equal(detector.collision_mask, 5, "Player detector collision_mask must be 5")
		Assertions.assert_vector3_approx_equal(detector.target_position, Vector3(0.0, 0.0, -2.0), 0.001, "Player detector length must be 2.0m")

	player.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] INT-05: Player InteractionDetector attachment passed.")
	else:
		printerr("    [FAIL] INT-05: Player InteractionDetector attachment failed.")
	return ok

func test_t27_landmark_interactables_in_graybox() -> bool:
	print("    [RUN] T27.LM: 12 Landmark Interactables in level_graybox.tscn")
	var initial_failures: int = Assertions.current_suite_failed

	var scene_res = ResourceLoader.load("res://scenes/world/level_graybox.tscn") as PackedScene
	Assertions.assert_not_null(scene_res, "level_graybox.tscn must load")

	var level = scene_res.instantiate() as Node3D

	var expected_landmarks = {
		"book_family": { "id": "landmark_book", "prompt": "[E] Periksa Meja Resep" },
		"storage_home": { "id": "landmark_storage", "prompt": "[E] Buka Peti" },
		"station_kitchen_home": { "id": "landmark_kitchen", "prompt": "[E] Periksa Dapur" },
		"water_home": { "id": "landmark_water", "prompt": "[E] Ambil Air" },
		"container_starter": { "id": "landmark_starter", "prompt": "[E] Ambil Wadah Starter" },
		"reserve_home": { "id": "landmark_reserve", "prompt": "[E] Periksa Cadangan" },
		"resource_jagung_01": { "id": "landmark_jagung", "prompt": "[E] Periksa Jagung" },
		"resource_temu_kunci_01": { "id": "landmark_temu_kunci", "prompt": "[E] Periksa Temu Kunci" },
		"npc_neighbor_01": { "id": "landmark_neighbor", "prompt": "[E] Bicara" },
		"note_garden_01": { "id": "landmark_note", "prompt": "[E] Baca Catatan Kebun" },
		"plot_home_01": { "id": "landmark_plot", "prompt": "[E] Periksa Petak" },
		"bed_home": { "id": "landmark_bed", "prompt": "[E] Istirahat" }
	}

	for landmark_name in expected_landmarks.keys():
		var lm_node = level.find_child(landmark_name, true, false) as Node3D
		Assertions.assert_not_null(lm_node, "Landmark node '%s' must exist" % landmark_name)
		if lm_node:
			var interactable = lm_node.find_child("Interactable", true, false) as Area3D
			Assertions.assert_not_null(interactable, "Landmark '%s' must have an 'Interactable' Area3D child" % landmark_name)
			if interactable:
				Assertions.assert_equal(interactable.collision_layer, 4, "Landmark '%s' interactable on Layer 3" % landmark_name)
				Assertions.assert_equal(interactable.interaction_id, expected_landmarks[landmark_name]["id"], "Landmark '%s' interaction_id matches" % landmark_name)
				Assertions.assert_equal(interactable.get_prompt_text(), expected_landmarks[landmark_name]["prompt"], "Landmark '%s' prompt text matches" % landmark_name)
				Assertions.assert_true(interactable.is_enabled(), "Landmark '%s' interactable must be enabled" % landmark_name)

	level.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T27.LM: 12 Landmark interactables verified.")
	else:
		printerr("    [FAIL] T27.LM: 12 Landmark interactables failed.")
	return ok

func test_t28_input_manager_context_stack() -> bool:
	print("    [RUN] T28.CTX1: InputManager Context Stack Hierarchy")
	var initial_failures: int = Assertions.current_suite_failed

	var im = InputManagerClass.new()

	# 1. Initial State
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Initial context is WORLD")
	Assertions.assert_true(im.is_world_context(), "is_world_context() returns true initially")
	Assertions.assert_equal(im.get_stack_depth(), 1, "Initial stack depth is 1")

	# 2. Pop underflow protection
	var popped = im.pop_context()
	Assertions.assert_equal(popped, InputManagerClass.ContextMode.WORLD, "Pop at root returns WORLD")
	Assertions.assert_equal(im.get_stack_depth(), 1, "Stack depth remains 1")

	# 3. Push and nesting: BOOK -> PAUSE
	im.push_context(InputManagerClass.ContextMode.BOOK)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.BOOK, "Current context is BOOK")
	Assertions.assert_false(im.is_world_context(), "is_world_context() returns false in BOOK")
	Assertions.assert_equal(im.get_stack_depth(), 2, "Stack depth is 2")

	im.push_context(InputManagerClass.ContextMode.PAUSE)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.PAUSE, "Current context is PAUSE")
	Assertions.assert_equal(im.get_stack_depth(), 3, "Stack depth is 3")

	# 4. Pop PAUSE -> returns to BOOK
	var popped_pause = im.pop_context()
	Assertions.assert_equal(popped_pause, InputManagerClass.ContextMode.PAUSE, "Popped context is PAUSE")
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.BOOK, "Current context restored to BOOK")
	Assertions.assert_equal(im.get_stack_depth(), 2, "Stack depth restored to 2")

	# 5. Pop BOOK -> returns to WORLD
	var popped_book = im.pop_context()
	Assertions.assert_equal(popped_book, InputManagerClass.ContextMode.BOOK, "Popped context is BOOK")
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Current context restored to WORLD")
	Assertions.assert_true(im.is_world_context(), "is_world_context() is true")

	# 6. set_context & pop_to_world
	im.set_context(InputManagerClass.ContextMode.KITCHEN)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.KITCHEN, "Current context set to KITCHEN")
	im.pop_to_world()
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "pop_to_world restores WORLD")
	Assertions.assert_equal(im.get_stack_depth(), 1, "Stack depth is 1 after pop_to_world")

	im.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T28.CTX1: Context stack hierarchy passed.")
	else:
		printerr("    [FAIL] T28.CTX1: Context stack hierarchy failed.")
	return ok

func test_t28_input_manager_player_gating() -> bool:
	print("    [RUN] T28.CTX2: InputManager Player Locomotion & Look Gating")
	var initial_failures: int = Assertions.current_suite_failed

	var im = InputManagerClass.new()
	var player = PlayerControllerClass.new()

	im.register_player(player)

	# 1. In WORLD: player moves and looks freely
	Assertions.assert_true(player.movement_enabled, "Player movement_enabled is true in WORLD")
	Assertions.assert_true(player.look_enabled, "Player look_enabled is true in WORLD")

	# 2. In BOOK modal: movement and look are disabled
	im.push_context(InputManagerClass.ContextMode.BOOK)
	Assertions.assert_false(player.movement_enabled, "Player movement_enabled is false in BOOK modal")
	Assertions.assert_false(player.look_enabled, "Player look_enabled is false in BOOK modal")

	# 3. Return to WORLD: movement and look restored
	im.pop_context()
	Assertions.assert_true(player.movement_enabled, "Player movement_enabled restored in WORLD")
	Assertions.assert_true(player.look_enabled, "Player look_enabled restored in WORLD")

	player.free()
	im.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T28.CTX2: Player gating passed.")
	else:
		printerr("    [FAIL] T28.CTX2: Player gating failed.")
	return ok

func test_t28_bleed_through_prevention() -> bool:
	print("    [RUN] T28.BLD: Action Bleed-Through Prevention & Frame Guard")
	var initial_failures: int = Assertions.current_suite_failed

	var im = InputManagerClass.new()

	im.push_context(InputManagerClass.ContextMode.BOOK)
	im.consume_and_close(&"interact")

	# 1. On same frame that modal closed: can_interact_in_world must be false
	Assertions.assert_false(im.can_interact_in_world(), "can_interact_in_world() is false on the exact close frame")

	# 2. Action suppression until released
	Assertions.assert_true(im.is_action_suppressed(&"interact"), "is_action_suppressed('interact') is true until release")

	im.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T28.BLD: Bleed-through prevention passed.")
	else:
		printerr("    [FAIL] T28.BLD: Bleed-through prevention failed.")
	return ok

func test_t28_simulation_pause_rules() -> bool:
	print("    [RUN] T28.SIM: Simulation Pausing Rules (PROTOTYPE.md § 5)")
	var initial_failures: int = Assertions.current_suite_failed

	var im = InputManagerClass.new()

	# WORLD: simulation runs
	Assertions.assert_false(im.is_simulation_paused(), "WORLD: is_simulation_paused is false")

	# BOOK: simulation pauses
	im.set_context(InputManagerClass.ContextMode.BOOK)
	Assertions.assert_true(im.is_simulation_paused(), "BOOK: is_simulation_paused is true")

	# STORAGE: simulation pauses
	im.set_context(InputManagerClass.ContextMode.STORAGE)
	Assertions.assert_true(im.is_simulation_paused(), "STORAGE: is_simulation_paused is true")

	# KITCHEN: simulation RUNS (cooking & garden time continues per PROTOTYPE § 5)
	im.set_context(InputManagerClass.ContextMode.KITCHEN)
	Assertions.assert_false(im.is_simulation_paused(), "KITCHEN: is_simulation_paused is false")

	# DIALOGUE: simulation pauses
	im.set_context(InputManagerClass.ContextMode.DIALOGUE)
	Assertions.assert_true(im.is_simulation_paused(), "DIALOGUE: is_simulation_paused is true")

	# PAUSE: simulation pauses
	im.set_context(InputManagerClass.ContextMode.PAUSE)
	Assertions.assert_true(im.is_simulation_paused(), "PAUSE: is_simulation_paused is true")

	im.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T28.SIM: Simulation pause rules passed.")
	else:
		printerr("    [FAIL] T28.SIM: Simulation pause rules failed.")
	return ok

func test_t18_range_acquisition_at_2m(tree: SceneTree) -> bool:
	print("    [RUN] T18.RNG: Target Acquisition at <= 2.0m vs Rejection at > 2.0m")
	var initial_failures: int = Assertions.current_suite_failed

	var world_node = Node3D.new()
	tree.root.add_child(world_node)

	var target = InteractableClass.new()
	target.name = "Interactable"
	target.position = Vector3(0.0, 0.0, -1.5)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.0, 1.0, 1.0)
	col.shape = shape
	target.add_child(col)
	world_node.add_child(target)

	var detector = InteractionDetectorClass.new()
	detector.position = Vector3.ZERO
	world_node.add_child(detector)

	# Await frames for physics space synchronization
	for i in range(3):
		await tree.process_frame
		await tree.physics_frame

	# 1. Target at 1.5m (within 2m)
	detector.update_target()
	Assertions.assert_not_null(detector.get_current_target(), "Target at 1.5m must be acquired")
	Assertions.assert_equal(detector.get_current_target(), target, "Acquired target matches target instance")
	Assertions.assert_true(detector.has_focused_target(), "has_focused_target() is true")

	# 2. Move target to 3.0m (beyond 2m: nearest surface at Z = -2.5, detector reaches -2.0)
	target.position = Vector3(0.0, 0.0, -3.0)
	for i in range(3):
		await tree.process_frame
		await tree.physics_frame

	detector.update_target()
	Assertions.assert_null(detector.get_current_target(), "Target at 3.0m must NOT be acquired (out of range)")
	Assertions.assert_false(detector.has_focused_target(), "has_focused_target() is false out of range")

	world_node.queue_free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T18.RNG: Target range acquisition verified.")
	else:
		printerr("    [FAIL] T18.RNG: Target range acquisition failed.")
	return ok

func test_t18_interaction_execution_and_signals(tree: SceneTree) -> bool:
	print("    [RUN] T18.EXE: Interaction Trigger, Signals and Disabled Target")
	var initial_failures: int = Assertions.current_suite_failed

	# Ensure InputManager is in WORLD context
	var im = tree.root.get_node_or_null("InputManager")
	if im != null and im.has_method("pop_to_world"):
		im.pop_to_world()

	var world_node = Node3D.new()
	tree.root.add_child(world_node)

	var target = InteractableClass.new()
	target.name = "Interactable"
	target.position = Vector3(0.0, 0.0, -1.2)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.0, 1.0, 1.0)
	col.shape = shape
	target.add_child(col)
	world_node.add_child(target)

	var detector = InteractionDetectorClass.new()
	detector.position = Vector3.ZERO
	world_node.add_child(detector)

	var dummy_player = Node3D.new()
	world_node.add_child(dummy_player)

	var target_interacted_count := [0]
	target.interacted.connect(func(p): target_interacted_count[0] += 1)

	var detector_performed_count := [0]
	detector.interaction_performed.connect(func(t): detector_performed_count[0] += 1)

	for i in range(3):
		await tree.process_frame
		await tree.physics_frame

	detector.update_target()
	Assertions.assert_true(detector.has_focused_target(), "Target acquired")

	# 1. Execute interaction
	var success = detector.try_interact(dummy_player)
	Assertions.assert_true(success, "try_interact returns true on active target")
	Assertions.assert_equal(target_interacted_count[0], 1, "target interacted signal emitted once")
	Assertions.assert_equal(detector_performed_count[0], 1, "detector interaction_performed signal emitted once")

	# 2. Disabled target
	target.enabled = false
	detector.update_target()
	Assertions.assert_false(detector.has_focused_target(), "Disabled target is not focused")
	var failed_res = detector.try_interact(dummy_player)
	Assertions.assert_false(failed_res, "try_interact returns false on disabled target")

	world_node.queue_free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T18.EXE: Interaction execution verified.")
	else:
		printerr("    [FAIL] T18.EXE: Interaction execution failed.")
	return ok

func test_t27_wall_occlusion(tree: SceneTree) -> bool:
	print("    [RUN] T27.OCC: Wall Occlusion Blocks Interaction (T27 Specification)")
	var initial_failures: int = Assertions.current_suite_failed

	var world_node = Node3D.new()
	tree.root.add_child(world_node)

	# 1. Interactable target at (0, 0, -1.8) on Layer 3
	var target = InteractableClass.new()
	target.name = "TargetBehindWall"
	target.position = Vector3(0.0, 0.0, -1.8)
	var col_target = CollisionShape3D.new()
	var shape_target = BoxShape3D.new()
	shape_target.size = Vector3(1.0, 1.0, 1.0)
	col_target.shape = shape_target
	target.add_child(col_target)
	world_node.add_child(target)

	# 2. Opaque solid wall at (0, 0, -0.9) on Layer 1 (Environment)
	var wall = StaticBody3D.new()
	wall.name = "OpaqueWall"
	wall.collision_layer = 1 # Environment
	wall.collision_mask = 1
	wall.position = Vector3(0.0, 0.0, -0.9)
	var col_wall = CollisionShape3D.new()
	var shape_wall = BoxShape3D.new()
	shape_wall.size = Vector3(4.0, 4.0, 0.2)
	col_wall.shape = shape_wall
	wall.add_child(col_wall)
	world_node.add_child(wall)

	# 3. Detector at (0, 0, 0)
	var detector = InteractionDetectorClass.new()
	detector.position = Vector3.ZERO
	world_node.add_child(detector)

	for i in range(3):
		await tree.process_frame
		await tree.physics_frame

	# Raycast hits the wall on Layer 1 first -> find_interactable(wall) == null
	detector.update_target()
	Assertions.assert_null(detector.get_current_target(), "Target behind solid wall must NOT be acquired")
	Assertions.assert_false(detector.has_focused_target(), "has_focused_target() must be false when occluded")

	var dummy_player = Node3D.new()
	world_node.add_child(dummy_player)
	var interact_occluded = detector.try_interact(dummy_player)
	Assertions.assert_false(interact_occluded, "try_interact must return false when target is behind a wall")

	# 4. Remove the wall: target should now be acquired
	world_node.remove_child(wall)
	wall.queue_free()

	for i in range(3):
		await tree.process_frame
		await tree.physics_frame

	detector.update_target()
	Assertions.assert_not_null(detector.get_current_target(), "Target acquired once wall is removed")
	Assertions.assert_equal(detector.get_current_target(), target, "Acquired target is the unobstructed target")
	Assertions.assert_true(detector.has_focused_target(), "has_focused_target() is true after wall removal")

	world_node.queue_free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T27.OCC: Wall occlusion verified.")
	else:
		printerr("    [FAIL] T27.OCC: Wall occlusion failed.")
	return ok
