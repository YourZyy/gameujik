extends SceneTree

func _init() -> void:
	print("[BUILD_PLAYER] Generating scenes/player/player.tscn...")
	var err = generate_player_scene()
	if err == OK:
		print("[BUILD_PLAYER] Successfully generated player.tscn!")
		quit(0)
	else:
		printerr("[BUILD_PLAYER] Failed to generate player.tscn: ", err)
		quit(1)

func generate_player_scene() -> Error:
	var root = CharacterBody3D.new()
	root.name = "Player"
	var player_script = load("res://scripts/player/player_controller.gd")
	root.set_script(player_script)
	root.collision_layer = 2 # Layer 2: player
	root.collision_mask = 13 # Layers 1, 3, 4: environment (1), interactables (4), triggers (8)
	root.floor_constant_speed = true
	root.floor_snap_length = 0.2
	root.floor_stop_on_slope = true

	# 1. CollisionShape3D with CapsuleShape3D
	var col_shape = CollisionShape3D.new()
	col_shape.name = "CollisionShape3D"
	col_shape.position = Vector3(0.0, 0.9, 0.0) # Height 1.8 / 2 = 0.9 -> feet touch Y=0

	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	col_shape.shape = capsule
	root.add_child(col_shape)

	# 2. Camera Pivot / Head
	var head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 1.6, 0.0) # Eye height 1.6m

	var camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 80.0
	camera.current = true
	camera.position = Vector3.ZERO
	head.add_child(camera)

	# 3. Interaction Detector (RayCast3D)
	var detector = RayCast3D.new()
	detector.name = "InteractionDetector"
	var detector_script = load("res://scripts/interaction/interaction_detector.gd")
	detector.set_script(detector_script)
	detector.target_position = Vector3(0.0, 0.0, -2.0)
	detector.position = Vector3.ZERO
	detector.collision_mask = 5
	detector.collide_with_areas = true
	detector.collide_with_bodies = true
	camera.add_child(detector)

	root.add_child(head)

	# Set owners for PackedScene serialization
	set_owner_recursive(root, root)

	var packed_scene = PackedScene.new()
	var pack_err = packed_scene.pack(root)
	if pack_err != OK:
		printerr("Error packing player scene: ", pack_err)
		return pack_err

	# Ensure directory exists
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("scenes/player"):
		dir.make_dir_recursive("scenes/player")

	var save_err = ResourceSaver.save(packed_scene, "res://scenes/player/player.tscn")
	root.free()
	return save_err

func set_owner_recursive(node: Node, new_owner: Node) -> void:
	for child in node.get_children():
		child.owner = new_owner
		set_owner_recursive(child, new_owner)
