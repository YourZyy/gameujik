extends SceneTree

func _init() -> void:
	print("[BUILD_LEVEL] Generating scenes/world/level_graybox.tscn...")
	var err = generate_level()
	if err == OK:
		print("[BUILD_LEVEL] Successfully generated level_graybox.tscn!")
		quit(0)
	else:
		printerr("[BUILD_LEVEL] Failed to generate level_graybox.tscn: ", err)
		quit(1)

func generate_level() -> Error:
	var root = Node3D.new()
	root.name = "LevelGraybox"
	var level_script = load("res://scripts/world/level_graybox.gd")
	root.set_script(level_script)

	# --- MATERIALS (Indonesian Stylized Low-Poly Palette per ART_DIRECTION.md § 4) ---
	var mat_grass = StandardMaterial3D.new()
	mat_grass.albedo_color = Color(0.345, 0.439, 0.306) # #58704E Grassy green
	mat_grass.roughness = 0.90

	var mat_path = StandardMaterial3D.new()
	mat_path.albedo_color = Color(0.71, 0.62, 0.49) # Dirt path
	mat_path.roughness = 0.90

	var mat_house_wall = StandardMaterial3D.new()
	mat_house_wall.albedo_color = Color(0.894, 0.839, 0.710) # #E4D6B5 Warm off-white plaster wall
	mat_house_wall.roughness = 0.80

	var mat_plinth = StandardMaterial3D.new()
	mat_plinth.albedo_color = Color(0.353, 0.302, 0.255) # #5A4D41 Stone/brick plinth base
	mat_plinth.roughness = 0.85

	var mat_house_floor = StandardMaterial3D.new()
	mat_house_floor.albedo_color = Color(0.475, 0.333, 0.251) # #795540 Wood plank floor
	mat_house_floor.roughness = 0.75

	var mat_roof = StandardMaterial3D.new()
	mat_roof.albedo_color = Color(0.671, 0.404, 0.282) # #AB6748 Terracotta genteng red
	mat_roof.roughness = 0.65

	var mat_roof_ridge = StandardMaterial3D.new()
	mat_roof_ridge.albedo_color = Color(0.561, 0.310, 0.208) # #8F4F35 Ridge cap / bubungan
	mat_roof_ridge.roughness = 0.65

	var mat_door_frame = StandardMaterial3D.new()
	mat_door_frame.albedo_color = Color(0.361, 0.239, 0.180) # #5C3D2E Dark teak frame (kusen)
	mat_door_frame.roughness = 0.70

	var mat_door_wood = StandardMaterial3D.new()
	mat_door_wood.albedo_color = Color(0.408, 0.278, 0.208) # #684735 Paneled wooden door
	mat_door_wood.roughness = 0.70

	var mat_wood = StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.475, 0.333, 0.251) # #795540 Rustic wood pillars/crates
	mat_wood.roughness = 0.80

	var mat_bamboo = StandardMaterial3D.new()
	mat_bamboo.albedo_color = Color(0.659, 0.624, 0.431) # #A89F6E Bamboo rails & posts
	mat_bamboo.roughness = 0.75

	var mat_bamboo_pale = StandardMaterial3D.new()
	mat_bamboo_pale.albedo_color = Color(0.702, 0.651, 0.459) # #B3A675 Split bamboo palings
	mat_bamboo_pale.roughness = 0.80

	var mat_soil = StandardMaterial3D.new()
	mat_soil.albedo_color = Color(0.29, 0.21, 0.15) # Rich dark soil
	mat_soil.roughness = 0.95

	var mat_water = StandardMaterial3D.new()
	mat_water.albedo_color = Color(0.29, 0.48, 0.62) # Water basin blue
	mat_water.roughness = 0.25

	var mat_stone = StandardMaterial3D.new()
	mat_stone.albedo_color = Color(0.43, 0.44, 0.45) # River boulder gray
	mat_stone.roughness = 0.85

	var mat_plant = StandardMaterial3D.new()
	mat_plant.albedo_color = Color(0.569, 0.659, 0.424) # #91A86C Leaf green
	mat_plant.roughness = 0.70

	var mat_corn_ear = StandardMaterial3D.new()
	mat_corn_ear.albedo_color = Color(0.898, 0.663, 0.231) # #E5A93B Golden yellow corn ear
	mat_corn_ear.roughness = 0.60

	var mat_corn_husk = StandardMaterial3D.new()
	mat_corn_husk.albedo_color = Color(0.620, 0.722, 0.471) # #9EB878 Pale husk green
	mat_corn_husk.roughness = 0.75

	var mat_temu_foliage = StandardMaterial3D.new()
	mat_temu_foliage.albedo_color = Color(0.310, 0.427, 0.267) # #4F6D44 Glossy lanceolate leaves
	mat_temu_foliage.roughness = 0.50

	var mat_book = StandardMaterial3D.new()
	mat_book.albedo_color = Color(0.961, 0.941, 0.894) # #F5F0E4 Cream paper/cover
	mat_book.roughness = 0.70

	# --- 1. ENVIRONMENT ---
	var env_node = Node3D.new()
	env_node.name = "Environment"
	root.add_child(env_node)

	# Ground floor: spanning X -40..40, Z -35..45 (width 80, length 80, center X 0, Z 5, Y -0.1)
	var ground = create_box_static_body("Ground", Vector3(0, -0.1, 5), Vector3(80, 0.2, 80), mat_grass)
	env_node.add_child(ground)

	var ground_ph = Node3D.new()
	ground_ph.name = "GroundPlaceholder"
	ground.add_child(ground_ph)

	# House Structure: footprint X -4..4, Z -6..4, center (0, 0, -1)
	var house_node = Node3D.new()
	house_node.name = "HouseStructure"
	env_node.add_child(house_node)

	# House Floor (Wood planks)
	var house_floor = create_box_static_body("HouseFloor", Vector3(0, 0.05, -1), Vector3(8.0, 0.1, 10.0), mat_house_floor)
	house_node.add_child(house_floor)

	# Stone/Brick Foundation Plinth (Base at Y 0.2m, height 0.4m)
	house_node.add_child(create_box_mesh_only("PlinthNorth", Vector3(0, 0.2, -6), Vector3(8.26, 0.4, 0.26), mat_plinth))
	house_node.add_child(create_box_mesh_only("PlinthWest", Vector3(-4, 0.2, -1), Vector3(0.26, 0.4, 10.26), mat_plinth))
	house_node.add_child(create_box_mesh_only("PlinthEast", Vector3(4, 0.2, -1), Vector3(0.26, 0.4, 10.26), mat_plinth))
	house_node.add_child(create_box_mesh_only("PlinthSouthLeft", Vector3(-2.4, 0.2, 4), Vector3(3.26, 0.4, 0.26), mat_plinth))
	house_node.add_child(create_box_mesh_only("PlinthSouthRight", Vector3(2.4, 0.2, 4), Vector3(3.26, 0.4, 0.26), mat_plinth))

	# North Wall: Z = -6, width 8.2, height 3.0
	var wall_north = create_box_static_body("WallNorth", Vector3(0, 1.5, -6), Vector3(8.2, 3.0, 0.2), mat_house_wall)
	house_node.add_child(wall_north)

	# West Wall: X = -4, length 10.2, height 3.0
	var wall_west = create_box_static_body("WallWest", Vector3(-4, 1.5, -1), Vector3(0.2, 3.0, 10.2), mat_house_wall)
	house_node.add_child(wall_west)

	# East Wall: X = 4, length 10.2, height 3.0
	var wall_east = create_box_static_body("WallEast", Vector3(4, 1.5, -1), Vector3(0.2, 3.0, 10.2), mat_house_wall)
	house_node.add_child(wall_east)

	# South Wall: Z = 4 with doorway centered at X = 0 (doorway 1.6m wide, from -0.8 to 0.8)
	var wall_south_l = create_box_static_body("WallSouthLeft", Vector3(-2.4, 1.5, 4), Vector3(3.2, 3.0, 0.2), mat_house_wall)
	house_node.add_child(wall_south_l)

	var wall_south_r = create_box_static_body("WallSouthRight", Vector3(2.4, 1.5, 4), Vector3(3.2, 3.0, 0.2), mat_house_wall)
	house_node.add_child(wall_south_r)

	var wall_south_lintel = create_box_static_body("WallSouthLintel", Vector3(0, 2.6, 4), Vector3(1.6, 0.8, 0.2), mat_house_wall)
	house_node.add_child(wall_south_lintel)

	# Dark Teak Door Frame (Kusen)
	house_node.add_child(create_box_mesh_only("KusenLeft", Vector3(-0.8, 1.1, 4.0), Vector3(0.12, 2.2, 0.24), mat_door_frame))
	house_node.add_child(create_box_mesh_only("KusenRight", Vector3(0.8, 1.1, 4.0), Vector3(0.12, 2.2, 0.24), mat_door_frame))
	house_node.add_child(create_box_mesh_only("KusenTop", Vector3(0, 2.15, 4.0), Vector3(1.72, 0.12, 0.24), mat_door_frame))

	# Paneled Door (swung open interiorly at 75 degrees against west wall)
	var door_mesh = create_box_mesh_only("FrontDoor", Vector3(-0.72, 1.05, 3.5), Vector3(0.06, 2.05, 0.75), mat_door_wood)
	door_mesh.rotation.y = deg_to_rad(75.0)
	house_node.add_child(door_mesh)
	var door_handle = create_box_mesh_only("DoorHandle", Vector3(-0.70, 1.05, 3.2), Vector3(0.04, 0.10, 0.08), mat_stone)
	house_node.add_child(door_handle)

	# Front Porch (Teras Depan):
	# Porch floor extending south to Z = 5.8m
	var porch_floor = create_box_mesh_only("PorchFloor", Vector3(0, 0.04, 4.9), Vector3(6.0, 0.08, 1.8), mat_house_floor)
	house_node.add_child(porch_floor)

	# 2 Rustic Wooden Pillars (Tiang Teras)
	var tiang_l = create_box_static_body("TiangTerasLeft", Vector3(-2.2, 1.4, 5.6), Vector3(0.2, 2.8, 0.2), mat_wood)
	var tiang_r = create_box_static_body("TiangTerasRight", Vector3(2.2, 1.4, 5.6), Vector3(0.2, 2.8, 0.2), mat_wood)
	house_node.add_child(tiang_l)
	house_node.add_child(tiang_r)

	# Porch Awning Roof
	var porch_roof = create_box_mesh_only("PorchRoof", Vector3(0, 2.95, 4.9), Vector3(6.4, 0.12, 2.0), mat_roof)
	porch_roof.rotation.x = deg_to_rad(12.0)
	house_node.add_child(porch_roof)

	# Pitched Terracotta Roof (Atap Pelana / Limasan Kampung)
	# Base ceiling preserved for environmental tests
	var house_roof = create_box_static_body("HouseRoof", Vector3(0, 3.1, -1), Vector3(8.6, 0.2, 10.6), mat_roof)
	house_node.add_child(house_roof)

	# Pitched Roof Ridge Cap (Bubungan)
	var roof_ridge = create_box_mesh_only("RoofRidge", Vector3(0, 4.6, -1), Vector3(0.3, 0.25, 11.2), mat_roof_ridge)
	house_node.add_child(roof_ridge)

	# Sloped Terracotta Roof Planes (East and West sloping down to eaves)
	var roof_west = create_box_mesh_only("RoofSlopeWest", Vector3(-2.3, 3.85, -1), Vector3(5.3, 0.12, 11.2), mat_roof)
	roof_west.rotation.z = deg_to_rad(-30.0)
	house_node.add_child(roof_west)

	var roof_east = create_box_mesh_only("RoofSlopeEast", Vector3(2.3, 3.85, -1), Vector3(5.3, 0.12, 11.2), mat_roof)
	roof_east.rotation.z = deg_to_rad(30.0)
	house_node.add_child(roof_east)

	# Gable Infill Walls (Gunungan Atap)
	var gable_n = create_box_mesh_only("GableNorth", Vector3(0, 3.8, -6), Vector3(7.8, 1.4, 0.2), mat_house_wall)
	var gable_s = create_box_mesh_only("GableSouth", Vector3(0, 3.8, 4), Vector3(7.8, 1.4, 0.2), mat_house_wall)
	house_node.add_child(gable_n)
	house_node.add_child(gable_s)

	# Boundaries: Perimeter collision walls around X -40..40, Z -35..45
	var boundaries_node = Node3D.new()
	boundaries_node.name = "PerimeterBoundaries"
	env_node.add_child(boundaries_node)

	var b_north = create_box_static_body("BoundaryNorth", Vector3(0, 2.0, -35), Vector3(80.0, 4.0, 1.0), null)
	var b_south = create_box_static_body("BoundarySouth", Vector3(0, 2.0, 45), Vector3(80.0, 4.0, 1.0), null)
	var b_west = create_box_static_body("BoundaryWest", Vector3(-40, 2.0, 5), Vector3(1.0, 4.0, 80.0), null)
	var b_east = create_box_static_body("BoundaryEast", Vector3(40, 2.0, 5), Vector3(1.0, 4.0, 80.0), null)
	boundaries_node.add_child(b_north)
	boundaries_node.add_child(b_south)
	boundaries_node.add_child(b_west)
	boundaries_node.add_child(b_east)

	# Rustic Bamboo Perimeter & Garden Fences
	var fences_node = Node3D.new()
	fences_node.name = "Fences"
	env_node.add_child(fences_node)

	# South Perimeter Bamboo Fence West (X -8.0 to -1.1, Z 13.0)
	var fence_sw = create_box_static_body("FenceSouthWest", Vector3(-4.55, 0.6, 13.0), Vector3(6.9, 1.2, 0.2), null)
	fences_node.add_child(fence_sw)
	fence_sw.add_child(create_box_mesh_only("RailTop", Vector3(0, 0.25, 0), Vector3(6.9, 0.08, 0.08), mat_bamboo))
	fence_sw.add_child(create_box_mesh_only("RailBottom", Vector3(0, -0.20, 0), Vector3(6.9, 0.08, 0.08), mat_bamboo))
	for px in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		fence_sw.add_child(create_box_mesh_only("Post_%d" % int(px), Vector3(px, 0.0, 0), Vector3(0.10, 1.20, 0.10), mat_bamboo))
	# Palings
	for i in range(8):
		var paling_x = -3.0 + float(i) * 0.85
		var paling_h = 1.05 + ((i % 3) * 0.05)
		fence_sw.add_child(create_box_mesh_only("Paling_%d" % i, Vector3(paling_x, 0.0, 0.03), Vector3(0.08, paling_h, 0.03), mat_bamboo_pale))

	# South Perimeter Bamboo Fence East (X 1.1 to 12.0, Z 13.0)
	var fence_se = create_box_static_body("FenceSouthEast", Vector3(6.55, 0.6, 13.0), Vector3(10.9, 1.2, 0.2), null)
	fences_node.add_child(fence_se)
	fence_se.add_child(create_box_mesh_only("RailTop", Vector3(0, 0.25, 0), Vector3(10.9, 0.08, 0.08), mat_bamboo))
	fence_se.add_child(create_box_mesh_only("RailBottom", Vector3(0, -0.20, 0), Vector3(10.9, 0.08, 0.08), mat_bamboo))
	for px in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
		fence_se.add_child(create_box_mesh_only("Post_%d" % int(px), Vector3(px, 0.0, 0), Vector3(0.10, 1.20, 0.10), mat_bamboo))
	for i in range(12):
		var paling_x = -4.8 + float(i) * 0.88
		var paling_h = 1.05 + ((i % 3) * 0.05)
		fence_se.add_child(create_box_mesh_only("Paling_%d" % i, Vector3(paling_x, 0.0, 0.03), Vector3(0.08, paling_h, 0.03), mat_bamboo_pale))

	# Garden Plot Low Rustic Fence (East boundary of garden at X 10.5, Z 5.5 to 8.5)
	var fence_garden = create_box_static_body("FenceGarden", Vector3(10.5, 0.35, 7.0), Vector3(0.2, 0.7, 3.0), null)
	fences_node.add_child(fence_garden)
	fence_garden.add_child(create_box_mesh_only("RailTop", Vector3(0, 0.15, 0), Vector3(0.08, 0.08, 3.0), mat_bamboo))
	for pz in [-1.2, 0.0, 1.2]:
		fence_garden.add_child(create_box_mesh_only("Post_%d" % int(pz), Vector3(0, 0, pz), Vector3(0.09, 0.70, 0.09), mat_bamboo))
	for i in range(4):
		var paling_z = -1.1 + float(i) * 0.75
		fence_garden.add_child(create_box_mesh_only("Paling_%d" % i, Vector3(0.03, 0.0, paling_z), Vector3(0.03, 0.65, 0.08), mat_bamboo_pale))

	# Paths Node: Visual dirt pathways
	var paths_node = Node3D.new()
	paths_node.name = "Paths"
	env_node.add_child(paths_node)

	# Path House to Gate (Z 4 to 13)
	paths_node.add_child(create_box_mesh_only("Path_HouseToGate", Vector3(0, 0.01, 8.5), Vector3(2.5, 0.02, 9.0), mat_path))
	# Path Gate to Junction (Z 13 to 21)
	paths_node.add_child(create_box_mesh_only("Path_GateToJunction", Vector3(0, 0.01, 17.0), Vector3(2.5, 0.02, 8.0), mat_path))
	# Path East to Garden/Jagung (X 0 to 22, Z 21 to 28)
	paths_node.add_child(create_box_mesh_only("Path_JunctionToEast", Vector3(11.0, 0.01, 24.5), Vector3(22.0, 0.02, 3.0), mat_path))
	# Path West to Neighbor/Temu Kunci (X 0 to -20, Z 21 to 30)
	paths_node.add_child(create_box_mesh_only("Path_JunctionToWest", Vector3(-10.0, 0.01, 25.5), Vector3(20.0, 0.02, 3.0), mat_path))
	# South connecting path (connecting X -18 to +20 at Z 35) to allow circular exploration loop
	paths_node.add_child(create_box_mesh_only("Path_SouthLoop", Vector3(0.0, 0.01, 35.0), Vector3(40.0, 0.02, 3.0), mat_path))
	# Path connecting East garden to South Loop (around X 21, Z 28 to 35)
	paths_node.add_child(create_box_mesh_only("Path_EastConnector", Vector3(21.0, 0.01, 31.5), Vector3(3.0, 0.02, 7.0), mat_path))
	# Path connecting West temu kunci to South Loop (around X -18, Z 30 to 35)
	paths_node.add_child(create_box_mesh_only("Path_WestConnector", Vector3(-18.0, 0.01, 32.5), Vector3(3.0, 0.02, 5.0), mat_path))

	# --- 2. MANDATORY 18 LANDMARKS ---
	# 1. zone_home: (0, 0, -1)
	var zone_home = Node3D.new()
	zone_home.name = "zone_home"
	zone_home.position = Vector3(0, 0, -1)
	root.add_child(zone_home)

	# 2. spawn_home: (0, 0, 1) facing north (-Z)
	var spawn_home = Node3D.new()
	spawn_home.name = "spawn_home"
	spawn_home.position = Vector3(0, 0, 1)
	root.add_child(spawn_home)

	# 3. book_family: (-1, 0, -2) - table with book on top
	var book_family = Node3D.new()
	book_family.name = "book_family"
	book_family.position = Vector3(-1, 0, -2)
	root.add_child(book_family)
	var table_sb = create_box_static_body("Table", Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 0.8), mat_wood)
	book_family.add_child(table_sb)
	var book_mesh = create_box_mesh_only("BookMesh", Vector3(0, 0.825, 0), Vector3(0.35, 0.05, 0.25), mat_book)
	book_family.add_child(book_mesh)
	book_family.add_child(create_interactable("landmark_book", "Meja Resep", "Periksa", Vector3(0, 0.5, 0), Vector3(1.2, 0.8, 0.8)))

	# 4. station_kitchen_home: (2, 0, -4) - kitchen counter
	var kitchen = Node3D.new()
	kitchen.name = "station_kitchen_home"
	kitchen.position = Vector3(2, 0, -4)
	root.add_child(kitchen)
	var counter_sb = create_box_static_body("Counter", Vector3(0, 0.45, 0), Vector3(2.0, 0.9, 1.0), mat_stone)
	kitchen.add_child(counter_sb)
	kitchen.add_child(create_interactable("landmark_kitchen", "Dapur", "Periksa", Vector3(0, 0.45, 0), Vector3(2.0, 0.9, 1.0)))

	# 5. storage_home: (-2, 0, -4) - chest placeholder
	var storage = Node3D.new()
	storage.name = "storage_home"
	storage.position = Vector3(-2, 0, -4)
	root.add_child(storage)
	var chest_sb = create_box_static_body("Chest", Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 0.8), mat_wood)
	storage.add_child(chest_sb)
	storage.add_child(create_interactable("landmark_storage", "Peti", "Buka", Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 0.8)))

	# 6. bed_home: (-2, 0, 0) - bed/mat placeholder
	var bed = Node3D.new()
	bed.name = "bed_home"
	bed.position = Vector3(-2, 0, 0)
	root.add_child(bed)
	var bed_sb = create_box_static_body("BedMat", Vector3(0, 0.15, 0), Vector3(1.8, 0.3, 2.0), mat_house_wall)
	bed.add_child(bed_sb)
	bed.add_child(create_interactable("landmark_bed", "", "Istirahat", Vector3(0, 0.2, 0), Vector3(1.8, 0.3, 2.0)))

	# 7. zone_yard: (5, 0, 7) - yard center
	var zone_yard = Node3D.new()
	zone_yard.name = "zone_yard"
	zone_yard.position = Vector3(5, 0, 7)
	root.add_child(zone_yard)

	# 8. plot_home_01: (8, 0, 7) - 2x2m gardening plot with 4 crop spots
	var plot = Node3D.new()
	plot.name = "plot_home_01"
	plot.position = Vector3(8, 0, 7)
	root.add_child(plot)
	var plot_soil = create_box_static_body("SoilBed", Vector3(0, 0.075, 0), Vector3(2.0, 0.15, 2.0), mat_soil)
	plot.add_child(plot_soil)
	plot.add_child(create_interactable("landmark_plot", "Petak", "Periksa", Vector3(0, 0.15, 0), Vector3(2.0, 0.3, 2.0)))
	var spot_coords = [
		Vector3(-0.5, 0.1, -0.5), # spot_0: NW quadrant
		Vector3(0.5, 0.1, -0.5),  # spot_1: NE quadrant
		Vector3(-0.5, 0.1, 0.5),  # spot_2: SW quadrant
		Vector3(0.5, 0.1, 0.5)   # spot_3: SE quadrant
	]
	for i in range(4):
		var spot = Node3D.new()
		spot.name = "spot_%d" % i
		spot.position = spot_coords[i]
		plot.add_child(spot)
		var marker = create_box_mesh_only("Marker", Vector3(0, 0.02, 0), Vector3(0.25, 0.04, 0.25), mat_wood)
		spot.add_child(marker)

	# 9. water_home: (4, 0, 9) - water refill station
	var water_home = Node3D.new()
	water_home.name = "water_home"
	water_home.position = Vector3(4, 0, 9)
	root.add_child(water_home)
	var water_sb = create_box_static_body("WaterBasin", Vector3(0, 0.5, 0), Vector3(0.8, 1.0, 0.8), mat_water)
	water_home.add_child(water_sb)
	water_home.add_child(create_interactable("landmark_water", "Air", "Ambil", Vector3(0, 0.5, 0), Vector3(0.8, 1.0, 0.8)))

	# 10. container_starter: (6, 0, 4) - starter package container
	var container_starter = Node3D.new()
	container_starter.name = "container_starter"
	container_starter.position = Vector3(6, 0, 4)
	root.add_child(container_starter)
	var starter_sb = create_box_static_body("StarterCrate", Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 0.8), mat_wood)
	container_starter.add_child(starter_sb)
	container_starter.add_child(create_interactable("landmark_starter", "Wadah Starter", "Ambil", Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 0.8)))

	# 11. reserve_home: (7, 0, 4) - emergency reserve container
	var reserve_home = Node3D.new()
	reserve_home.name = "reserve_home"
	reserve_home.position = Vector3(7, 0, 4)
	root.add_child(reserve_home)
	var reserve_sb = create_box_static_body("ReserveCrate", Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 0.8), mat_wood)
	reserve_home.add_child(reserve_sb)
	reserve_home.add_child(create_interactable("landmark_reserve", "Cadangan", "Periksa", Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 0.8)))

	# 12. gate_home: (0, 0, 13) - gate opening from yard to village path
	var gate_home = Node3D.new()
	gate_home.name = "gate_home"
	gate_home.position = Vector3(0, 0, 13)
	root.add_child(gate_home)
	var gate_post_l = create_box_static_body("PostLeft", Vector3(-1.1, 1.0, 0), Vector3(0.2, 2.0, 0.2), mat_wood)
	var gate_post_r = create_box_static_body("PostRight", Vector3(1.1, 1.0, 0), Vector3(0.2, 2.0, 0.2), mat_wood)
	gate_home.add_child(gate_post_l)
	gate_home.add_child(gate_post_r)

	# 13. junction_path: (0, 0, 21) - path junction landmark
	var junction = Node3D.new()
	junction.name = "junction_path"
	junction.position = Vector3(0, 0, 21)
	root.add_child(junction)
	var sign_post = create_box_static_body("SignPost", Vector3(0, 1.0, 0), Vector3(0.2, 2.0, 0.2), mat_wood)
	junction.add_child(sign_post)
	var sign_board = create_box_mesh_only("SignBoard", Vector3(0, 1.8, 0), Vector3(0.8, 0.3, 0.05), mat_wood)
	junction.add_child(sign_board)

	# 14. resource_jagung_01: (22, 0, 28) - corn garden remnant with persistent stalk and detachable ear
	var jagung = Node3D.new()
	jagung.name = "resource_jagung_01"
	jagung.position = Vector3(22, 0, 28)
	root.add_child(jagung)
	var jagung_sb = create_box_static_body("CornStalks", Vector3(0, 0.9, 0), Vector3(1.5, 1.8, 1.5), mat_plant)
	jagung.add_child(jagung_sb)
	# Persistent Stalk mesh
	var stalk_mesh = create_box_mesh_only("StalkMesh", Vector3(0, 0.1, 0), Vector3(0.35, 1.8, 0.35), mat_plant)
	jagung_sb.add_child(stalk_mesh)
	# Wooden garden support stake
	var stake_mesh = create_box_mesh_only("GardenStake", Vector3(-0.15, 0.0, -0.15), Vector3(0.08, 1.6, 0.08), mat_wood)
	jagung_sb.add_child(stake_mesh)
	# Detachable Corn Ear (husk & golden kernels)
	var corn_ear = create_box_mesh_only("CornEar", Vector3(0.20, 0.10, 0.20), Vector3(0.22, 0.45, 0.22), mat_corn_ear)
	jagung_sb.add_child(corn_ear)
	jagung.add_child(create_interactable("landmark_jagung", "Jagung", "Periksa", Vector3(0, 0.9, 0), Vector3(1.5, 1.8, 1.5)))

	# 15. note_garden_01: (19, 0, 27) - note post placeholder
	var note = Node3D.new()
	note.name = "note_garden_01"
	note.position = Vector3(19, 0, 27)
	root.add_child(note)
	var note_post = create_box_static_body("NotePost", Vector3(0, 0.5, 0), Vector3(0.2, 1.0, 0.2), mat_wood)
	note.add_child(note_post)
	var note_paper = create_box_mesh_only("NotePaper", Vector3(0, 0.9, 0.12), Vector3(0.25, 0.3, 0.02), mat_book)
	note.add_child(note_paper)
	note.add_child(create_interactable("landmark_note", "Catatan Kebun", "Baca", Vector3(0, 0.5, 0), Vector3(0.4, 1.0, 0.4)))

	# 16. resource_temu_kunci_01: (-20, 0, 30) - ginger/herb cluster & river rock
	var temu_kunci = Node3D.new()
	temu_kunci.name = "resource_temu_kunci_01"
	temu_kunci.position = Vector3(-20, 0, 30)
	root.add_child(temu_kunci)
	var rock_sb = create_box_static_body("Rock", Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 1.4), mat_stone)
	temu_kunci.add_child(rock_sb)
	var herb_mesh = create_box_mesh_only("HerbMesh", Vector3(0.6, 0.3, 0.5), Vector3(0.8, 0.6, 0.8), mat_temu_foliage)
	temu_kunci.add_child(herb_mesh)
	temu_kunci.add_child(create_interactable("landmark_temu_kunci", "Temu Kunci", "Periksa", Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 1.4)))

	# 17. npc_neighbor_01: (-14, 0, 15) - neighbor terrace bench & shade
	var neighbor = Node3D.new()
	neighbor.name = "npc_neighbor_01"
	neighbor.position = Vector3(-14, 0, 15)
	root.add_child(neighbor)
	var bench_sb = create_box_static_body("Bench", Vector3(0, 0.4, 0), Vector3(1.8, 0.8, 0.8), mat_wood)
	neighbor.add_child(bench_sb)
	neighbor.add_child(create_interactable("landmark_neighbor", "", "Bicara", Vector3(0, 0.4, 0), Vector3(1.8, 0.8, 0.8)))

	# 18. safe_return_home: (0, 0, 8) facing north
	var safe_return = Node3D.new()
	safe_return.name = "safe_return_home"
	safe_return.position = Vector3(0, 0, 8)
	root.add_child(safe_return)

	# --- 3. RECOVERY SYSTEM ---
	var recovery_node = Node3D.new()
	recovery_node.name = "Recovery"
	root.add_child(recovery_node)

	var fall_area = Area3D.new()
	fall_area.name = "FallRecoveryArea"
	fall_area.position = Vector3(0, -6.0, 5)
	fall_area.collision_layer = 8 # Layer 4: triggers
	fall_area.collision_mask = 2 # Layer 2: player
	recovery_node.add_child(fall_area)

	var fall_col = CollisionShape3D.new()
	fall_col.name = "FallAreaCollision"
	var fall_shape = BoxShape3D.new()
	fall_shape.size = Vector3(200.0, 2.0, 200.0)
	fall_col.shape = fall_shape
	fall_area.add_child(fall_col)

	# Ensure all descendants have owner set to root
	set_owner_recursive(root, root)

	# Save to PackedScene
	var packed_scene = PackedScene.new()
	var pack_err = packed_scene.pack(root)
	if pack_err != OK:
		printerr("Error packing scene: ", pack_err)
		return pack_err

	# Ensure directory exists
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("scenes/world"):
		dir.make_dir_recursive("scenes/world")

	var save_err = ResourceSaver.save(packed_scene, "res://scenes/world/level_graybox.tscn")
	root.free()
	return save_err

func create_box_static_body(node_name: String, pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var sb = StaticBody3D.new()
	sb.name = node_name
	sb.position = pos
	sb.collision_layer = 1 # Layer 1: environment
	sb.collision_mask = 1

	var col = CollisionShape3D.new()
	col.name = "Collision"
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	sb.add_child(col)

	if mat != null:
		var mi = MeshInstance3D.new()
		mi.name = "Mesh"
		var box_mesh = BoxMesh.new()
		box_mesh.size = size
		box_mesh.material = mat
		mi.mesh = box_mesh
		sb.add_child(mi)

	return sb

func create_box_mesh_only(node_name: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.name = node_name
	mi.position = pos
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = mat
	mi.mesh = box_mesh
	return mi

func set_owner_recursive(node: Node, new_owner: Node) -> void:
	for child in node.get_children():
		child.owner = new_owner
		set_owner_recursive(child, new_owner)

func create_interactable(interaction_id: String, target_name: String, action: String, pos: Vector3, size: Vector3) -> Area3D:
	var area = Area3D.new()
	area.name = "Interactable"
	area.position = pos
	var script = load("res://scripts/interaction/interactable.gd")
	area.set_script(script)
	area.interaction_id = interaction_id
	area.target_name = target_name
	area.prompt_action = action
	area.enabled = true
	area.is_interactable = true
	area.collision_layer = 4 # Layer 3: interactables (1 << 2)
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true

	var col = CollisionShape3D.new()
	col.name = "Collision"
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)

	return area
