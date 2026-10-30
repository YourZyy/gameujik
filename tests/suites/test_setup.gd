class_name TestSetup
extends RefCounted

const Assertions = preload("res://tests/assertions.gd")
const MainClass = preload("res://scripts/main.gd")

func run_all() -> bool:
	var passed := true
	print("  Running TestSetup suite...")
	if not test_t23_baseline_setup():
		passed = false
	if not test_t24_main_scene_smoke():
		passed = false
	return passed

func test_t23_baseline_setup() -> bool:
	print("    [RUN] T23: Baseline Setup Engine & Project Configuration")
	var initial_failures: int = Assertions.current_suite_failed

	# 1. Engine version verification
	var ver: Dictionary = Engine.get_version_info()
	Assertions.assert_equal(ver.get("major"), 4, "Engine major version must be 4")
	Assertions.assert_equal(ver.get("minor"), 7, "Engine minor version must be 7")

	# 2. Project settings verification
	var app_name: Variant = ProjectSettings.get_setting("application/config/name")
	Assertions.assert_equal(app_name, "Buku Resep 2045", "Project name must be 'Buku Resep 2045'")

	var renderer: Variant = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	Assertions.assert_equal(renderer, "gl_compatibility", "Renderer must be 'gl_compatibility'")

	var main_scene: Variant = ProjectSettings.get_setting("application/run/main_scene")
	Assertions.assert_equal(main_scene, "res://scenes/main.tscn", "Main scene must be 'res://scenes/main.tscn'")

	var width: Variant = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height: Variant = ProjectSettings.get_setting("display/window/size/viewport_height")
	Assertions.assert_equal(width, 1280, "Viewport width must be 1280")
	Assertions.assert_equal(height, 720, "Viewport height must be 720")

	# 3. 3D Physics layer names and physics interpolation verification
	Assertions.assert_equal(ProjectSettings.get_setting("layer_names/3d_physics/layer_1"), "environment", "Physics 3D layer 1 must be 'environment'")
	Assertions.assert_equal(ProjectSettings.get_setting("layer_names/3d_physics/layer_2"), "player", "Physics 3D layer 2 must be 'player'")
	Assertions.assert_equal(ProjectSettings.get_setting("layer_names/3d_physics/layer_3"), "interactables", "Physics 3D layer 3 must be 'interactables'")
	Assertions.assert_equal(ProjectSettings.get_setting("layer_names/3d_physics/layer_4"), "triggers", "Physics 3D layer 4 must be 'triggers'")
	Assertions.assert_true(ProjectSettings.get_setting("physics/common/physics_interpolation", false), "Physics interpolation must be enabled")

	# 4. Input actions verification
	var required_actions: Array[String] = [
		"move_forward",
		"move_backward",
		"move_left",
		"move_right",
		"interact",
		"open_book",
		"open_inventory",
		"pause_menu"
	]
	for action in required_actions:
		Assertions.assert_true(InputMap.has_action(action), "InputMap must have action: " + action)

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T23: Baseline Setup Engine passed.")
	else:
		printerr("    [FAIL] T23: Baseline Setup Engine failed.")
	return ok

func test_t24_main_scene_smoke() -> bool:
	print("    [RUN] T24: Main Scene Smoke Run & Hierarchy Verification")
	var initial_failures: int = Assertions.current_suite_failed

	# 1. Check file exists
	var file_exists := FileAccess.file_exists("res://scenes/main.tscn")
	Assertions.assert_true(file_exists, "scenes/main.tscn must exist")

	# 2. Resource loader verification
	var scene_res := ResourceLoader.load("res://scenes/main.tscn")
	Assertions.assert_not_null(scene_res, "ResourceLoader must load scenes/main.tscn")

	if scene_res is PackedScene:
		var node = scene_res.instantiate()
		Assertions.assert_not_null(node, "PackedScene must instantiate successfully")
		Assertions.assert_true(node is Node3D, "Root node must be Node3D")
		Assertions.assert_equal(node.name, "Main", "Root node name must be 'Main'")
		Assertions.assert_true(node is MainClass, "Root node must have Main script attached")

		# Check 3D environment components: DirectionalLight3D
		var light = node.find_child("DirectionalLight3D", true, false)
		Assertions.assert_not_null(light, "DirectionalLight3D must exist in scene tree")
		if light is DirectionalLight3D:
			Assertions.assert_true(light.shadow_enabled, "DirectionalLight3D shadow must be enabled")
			Assertions.assert_approx_equal(light.light_color.r, 0.906, 0.01, "Sunlight red channel matches warm afternoon palette")
			Assertions.assert_approx_equal(light.light_color.g, 0.706, 0.01, "Sunlight green channel matches warm afternoon palette")
			Assertions.assert_approx_equal(light.light_color.b, 0.463, 0.01, "Sunlight blue channel matches warm afternoon palette")

		# Check WorldEnvironment and Environment resource
		var world_env = node.find_child("WorldEnvironment", true, false)
		Assertions.assert_not_null(world_env, "WorldEnvironment must exist in scene tree")
		if world_env is WorldEnvironment:
			Assertions.assert_not_null(world_env.environment, "WorldEnvironment must have Environment resource")
			if world_env.environment:
				Assertions.assert_equal(world_env.environment.background_mode, Environment.BG_SKY, "Background mode must be BG_SKY")
				Assertions.assert_equal(world_env.environment.tonemap_mode, Environment.TONE_MAPPER_FILMIC, "Tonemap mode must be TONE_MAPPER_FILMIC")

		var cam = node.find_child("Camera3D", true, false)
		Assertions.assert_not_null(cam, "Camera3D must exist in scene tree")

		var ground = node.find_child("GroundPlaceholder", true, false)
		Assertions.assert_not_null(ground, "Ground geometry placeholder must exist in scene tree")

		node.free()
	else:
		Assertions.assert_true(false, "scenes/main.tscn is not a PackedScene")

	var ok := (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T24: Main Scene Smoke Run passed.")
	else:
		printerr("    [FAIL] T24: Main Scene Smoke Run failed.")
	return ok
