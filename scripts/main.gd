class_name Main
extends Node3D

@onready var sun: DirectionalLight3D = $DirectionalLight3D
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var level: Node3D = $LevelGraybox
@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD if has_node("HUD") else null
@onready var interaction_prompt: CanvasLayer = hud if hud != null else ($InteractionPrompt if has_node("InteractionPrompt") else null)
@onready var inventory_ui: CanvasLayer = $InventoryUI if has_node("InventoryUI") else null
@onready var book_ui: CanvasLayer = $BookUI if has_node("BookUI") else null
@onready var kitchen_ui: CanvasLayer = $KitchenUI if has_node("KitchenUI") else null
@onready var dialogue_ui: CanvasLayer = $DialogueUI if has_node("DialogueUI") else null
@onready var pause_menu: CanvasLayer = $PauseMenu if has_node("PauseMenu") else null
@onready var notification_toast: CanvasLayer = $NotificationToast if has_node("NotificationToast") else null

func _ready() -> void:
	_wire_inventory_and_landmarks()
	_wire_hud_detector()

func _wire_inventory_and_landmarks() -> void:
	if level == null:
		return

	# 1. Wire container_starter
	var starter_node = level.get_node_or_null("container_starter")
	if starter_node:
		var interactable = starter_node.get_node_or_null("Interactable")
		if interactable and interactable.has_signal("interacted"):
			interactable.interacted.connect(func(p): _on_starter_crate_interacted(p, interactable))

	# 2. Wire storage_home
	var storage_node = level.get_node_or_null("storage_home")
	if storage_node:
		var interactable = storage_node.get_node_or_null("Interactable")
		if interactable and interactable.has_signal("interacted"):
			interactable.interacted.connect(_on_storage_home_interacted)

	# 3. Listen for starter_collected signal from InventoryManager
	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_signal("starter_collected"):
		inv.starter_collected.connect(_on_starter_collected)

	# 4. Wire book_family landmark on house table
	var book_node = level.get_node_or_null("book_family")
	if book_node:
		var interactable = book_node.get_node_or_null("Interactable")
		if interactable and interactable.has_signal("interacted"):
			interactable.interacted.connect(_on_book_family_interacted)

	# 5. Wire note_garden_01 landmark on garden edge
	var note_node = level.get_node_or_null("note_garden_01")
	if note_node:
		var interactable = note_node.get_node_or_null("Interactable")
		if interactable and interactable.has_signal("interacted"):
			interactable.interacted.connect(func(p): _on_garden_note_interacted(p, interactable))

	# 6. Wire plot_home_01 landmark for compost interaction and visuals
	var plot_node = level.get_node_or_null("plot_home_01")
	if plot_node:
		var interactable = plot_node.get_node_or_null("Interactable")
		if interactable and interactable.has_signal("interacted"):
			interactable.interacted.connect(_on_plot_interacted)

	var gm = get_node_or_null("/root/GardenManager")
	if gm and gm.has_signal("plot_state_changed"):
		gm.plot_state_changed.connect(_on_garden_plot_state_changed)

	# 7. Wire resource_jagung_01
	var jagung_node = level.get_node_or_null("resource_jagung_01")
	if jagung_node:
		var interactable = jagung_node.get_node_or_null("Interactable")
		if interactable and interactable.has_signal("interacted"):
			interactable.interacted.connect(func(_p): _on_jagung_interacted())

	# 8. Wire resource_temu_kunci_01
	var temu_node = level.get_node_or_null("resource_temu_kunci_01")
	if temu_node:
		var interactable = temu_node.get_node_or_null("Interactable")
		if interactable and interactable.has_signal("interacted"):
			interactable.interacted.connect(func(_p): _on_temu_kunci_interacted())

	# 9. Wire reserve_home
	var reserve_node = level.get_node_or_null("reserve_home")
	if reserve_node:
		var interactable = reserve_node.get_node_or_null("Interactable")
		if interactable and interactable.has_signal("interacted"):
			interactable.interacted.connect(func(_p): _on_reserve_home_interacted())

	# 10. Wire bed_home
	var bed_node = level.get_node_or_null("bed_home")
	if bed_node:
		var interactable = bed_node.get_node_or_null("Interactable")
		if interactable and interactable.has_signal("interacted"):
			interactable.interacted.connect(func(_p): _on_bed_home_interacted())

	# 11. Wire WorldResourceManager foraging visual updates
	var wrm = get_node_or_null("/root/WorldResourceManager")
	if wrm and wrm.has_signal("foraging_state_changed"):
		wrm.foraging_state_changed.connect(_on_foraging_state_changed)

	# 12. Wire station_kitchen_home
	var kitchen_node = level.get_node_or_null("station_kitchen_home")
	if kitchen_node:
		var interactable = kitchen_node.get_node_or_null("Interactable")
		if interactable and interactable.has_signal("interacted"):
			interactable.interacted.connect(_on_kitchen_station_interacted)

	# 13. Wire npc_neighbor_01
	var neighbor_node = level.get_node_or_null("npc_neighbor_01")
	if neighbor_node:
		var interactable = neighbor_node.get_node_or_null("Interactable")
		if interactable and interactable.has_signal("interacted"):
			interactable.interacted.connect(_on_neighbor_interacted)

func _wire_hud_detector() -> void:
	if player != null and hud != null and hud.has_method("connect_detector"):
		var detector = player.find_child("InteractionDetector", true, false)
		if detector != null:
			hud.connect_detector(detector)

func _on_starter_crate_interacted(_player_node: Node3D, interactable: Node) -> void:
	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("pickup_starter_container"):
		var success: bool = inv.pickup_starter_container()
		if success and interactable:
			if interactable.has_method("set_prompt"):
				interactable.set_prompt("Wadah Kosong")
			interactable.set("prompt_action", "Wadah Kosong")
			interactable.set("target_name", "")

func _on_starter_collected(_items: Array) -> void:
	if level:
		var starter_node = level.get_node_or_null("container_starter")
		if starter_node:
			var interactable = starter_node.get_node_or_null("Interactable")
			if interactable:
				if interactable.has_method("set_prompt"):
					interactable.set_prompt("Wadah Kosong")
				interactable.set("prompt_action", "Wadah Kosong")
				interactable.set("target_name", "")

func _on_storage_home_interacted(_player_node: Node3D) -> void:
	var im = get_node_or_null("/root/InputManager")
	if im and im.has_method("push_context"):
		im.push_context(im.ContextMode.STORAGE)
	if inventory_ui and inventory_ui.has_method("open_dual"):
		inventory_ui.open_dual()

func _on_book_family_interacted(_player_node: Node3D) -> void:
	var im = get_node_or_null("/root/InputManager")
	if im != null and im.is_world_context():
		im.push_context(im.ContextMode.BOOK)

func _on_garden_note_interacted(_player_node: Node3D, interactable: Node) -> void:
	var rm = get_node_or_null("/root/RecipeManager")
	if rm and rm.has_method("unlock_note"):
		rm.unlock_note("note_garden_01")
	if interactable:
		if interactable.has_method("set_prompt"):
			interactable.set_prompt("Baca Ulang")
		interactable.set("prompt_action", "Baca Ulang")

func _on_plot_interacted(player_node: Node3D) -> void:
	var gm = get_node_or_null("/root/GardenManager")
	if gm == null:
		return
	if player_node != null and "interaction_detector" in player_node and player_node.interaction_detector != null:
		var hit_pt: Vector3 = player_node.interaction_detector.get_collision_point()
		var plot_node: Node3D = level.get_node_or_null("plot_home_01") if level != null else null
		if plot_node != null:
			var local_pt: Vector3 = plot_node.to_local(hit_pt)
			var spot_id: String = gm.get_spot_id_from_local_coords(local_pt) if gm.has_method("get_spot_id_from_local_coords") else "slot_01"
			var spot: Dictionary = gm.get_spot("plot_home_01", spot_id)
			if bool(spot.get("is_occupied", false)) and spot.get("crop_data") != null:
				var crop: Dictionary = spot["crop_data"]
				if bool(crop.get("is_ready_to_harvest", false)):
					gm.harvest_crop("plot_home_01", spot_id)
					return

	var plot: Dictionary = gm.get_plot("plot_home_01")
	if bool(plot.get("is_hoed", false)) and not bool(plot.get("has_compost", false)):
		gm.add_compost("plot_home_01")

func _on_garden_plot_state_changed(plot_id: String, plot_data: Dictionary) -> void:
	if level == null or plot_id != "plot_home_01":
		return
	var plot_node = level.get_node_or_null("plot_home_01")
	if plot_node == null:
		return

	# Update SoilBed visual material
	var soil_mesh: MeshInstance3D = plot_node.find_child("Mesh", true, false) as MeshInstance3D
	if soil_mesh != null:
		var mat = soil_mesh.material_override as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
			soil_mesh.material_override = mat

		var is_hoed: bool = bool(plot_data.get("is_hoed", false))
		var has_compost: bool = bool(plot_data.get("has_compost", false))
		var moisture: float = float(plot_data.get("moisture", 0.0))

		if not is_hoed:
			mat.albedo_color = Color(0.55, 0.44, 0.32)
			mat.roughness = 0.95
		elif not has_compost:
			mat.albedo_color = Color(0.38, 0.26, 0.16)
			mat.roughness = 0.85
		elif moisture < 30.0:
			mat.albedo_color = Color(0.28, 0.18, 0.10)
			mat.roughness = 0.80
		else:
			# Moist composted earth (darker and glossy)
			mat.albedo_color = Color(0.18, 0.12, 0.06)
			mat.roughness = 0.40

	# Update spot markers and crop stage meshes
	var spots: Dictionary = plot_data.get("spots", {})
	for spot_id in spots:
		var spot_info: Dictionary = spots[spot_id]
		var spot_node_name: String = "spot_0"
		match spot_id:
			"slot_01": spot_node_name = "spot_0"
			"slot_02": spot_node_name = "spot_1"
			"slot_03": spot_node_name = "spot_2"
			"slot_04": spot_node_name = "spot_3"
		var spot_node = plot_node.get_node_or_null(spot_node_name)
		if spot_node != null:
			var marker: MeshInstance3D = spot_node.find_child("Marker", true, false) as MeshInstance3D
			if marker != null:
				var m_mat = marker.material_override as StandardMaterial3D
				if m_mat == null:
					m_mat = StandardMaterial3D.new()
					marker.material_override = m_mat
				if bool(spot_info.get("is_occupied", false)):
					m_mat.albedo_color = Color(0.25, 0.85, 0.30)
				else:
					m_mat.albedo_color = Color(0.6, 0.6, 0.6)

			_update_crop_spot_visual(spot_node, spot_info)

# =============================================================================
# CROP VISUAL & MULTI-PRIMITIVE GEOMETRY (T55 SILHOUETTE COMPLIANCE)
# =============================================================================

var _crop_mat_cache: Dictionary = {}

func _get_crop_material(color: Color, roughness: float = 0.70) -> StandardMaterial3D:
	var key: String = "%s_%.2f" % [color.to_html(false), roughness]
	if not _crop_mat_cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
		_crop_mat_cache[key] = mat
	return _crop_mat_cache[key]

func _update_crop_spot_visual(spot_node: Node3D, spot_info: Dictionary) -> void:
	var is_occupied: bool = bool(spot_info.get("is_occupied", false))
	var crop_root: Node3D = spot_node.get_node_or_null("CropMesh") as Node3D

	if not is_occupied:
		if crop_root != null:
			crop_root.visible = false
		return

	if crop_root == null:
		crop_root = Node3D.new()
		crop_root.name = "CropMesh"
		spot_node.add_child(crop_root)

	crop_root.visible = true
	crop_root.scale = Vector3(1, 1, 1)
	var crop_data: Dictionary = spot_info.get("crop_data", {})
	var stage: int = int(crop_data.get("growth_stage", 0))
	var prev_stage: int = int(crop_root.get_meta("growth_stage", -1))

	if prev_stage != stage or crop_root.get_child_count() == 0:
		_rebuild_crop_stage(crop_root, stage)

func _rebuild_crop_stage(crop_root: Node3D, stage: int) -> void:
	# Immediately detach existing primitives so queries reading children see current state
	for child in crop_root.get_children():
		crop_root.remove_child(child)
		child.queue_free()

	crop_root.scale = Vector3(1, 1, 1)
	crop_root.set_meta("growth_stage", stage)

	match stage:
		0:
			_build_stage_0_seed(crop_root)
		1:
			_build_stage_1_sprout(crop_root)
		2:
			_build_stage_2_growing(crop_root)
		3:
			_build_stage_3_harvestable(crop_root)
		_:
			_build_stage_0_seed(crop_root)

func _build_stage_0_seed(root: Node3D) -> void:
	root.set_meta("crop_height", 0.04)
	root.set_meta("primitive_count", 2)
	root.set_meta("stage_color", Color(0.35, 0.25, 0.15))

	# 1. Base Mound: Gundukan tanah melingkar rendah (diameter 0.048m, tinggi 0.02m)
	var mound := MeshInstance3D.new()
	mound.name = "BaseMound"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.018
	cyl.bottom_radius = 0.024
	cyl.height = 0.02
	cyl.radial_segments = 8
	mound.mesh = cyl
	mound.position = Vector3(0, 0.01, 0)
	mound.material_override = _get_crop_material(Color(0.35, 0.25, 0.15), 0.90)
	root.add_child(mound)

	# 2. Seed Dibble: Titik tugal benih di tengah gundukan (puncak di 0.04m)
	var seed_dibble := MeshInstance3D.new()
	seed_dibble.name = "SeedDibble"
	var seed_mesh := CylinderMesh.new()
	seed_mesh.top_radius = 0.012
	seed_mesh.bottom_radius = 0.012
	seed_mesh.height = 0.015
	seed_mesh.radial_segments = 6
	seed_dibble.mesh = seed_mesh
	seed_dibble.position = Vector3(0, 0.0325, 0) # Peak reaches Y = 0.04m
	seed_dibble.material_override = _get_crop_material(Color(0.20, 0.15, 0.10), 0.85)
	root.add_child(seed_dibble)

func _build_stage_1_sprout(root: Node3D) -> void:
	root.set_meta("crop_height", 0.14)
	root.set_meta("primitive_count", 3)
	root.set_meta("stage_color", Color(0.55, 0.85, 0.25))

	var mat_sprout := _get_crop_material(Color(0.55, 0.85, 0.25), 0.70)

	# 1. Stem: Batang tegak ramping setinggi 0.10m
	var stem := MeshInstance3D.new()
	stem.name = "Stem"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.008
	cyl.bottom_radius = 0.010
	cyl.height = 0.10
	cyl.radial_segments = 6
	stem.mesh = cyl
	stem.position = Vector3(0, 0.05, 0)
	stem.material_override = mat_sprout
	root.add_child(stem)

	# 2. Cotyledon Left: Daun kotiledon kiri berbentuk siluet V khas (-35 derajat)
	var cot_l := MeshInstance3D.new()
	cot_l.name = "CotyledonLeft"
	var box_l := BoxMesh.new()
	box_l.size = Vector3(0.070, 0.010, 0.045)
	cot_l.mesh = box_l
	cot_l.position = Vector3(-0.032, 0.115, 0)
	cot_l.rotation = Vector3(0, 0, deg_to_rad(-35))
	cot_l.material_override = mat_sprout
	root.add_child(cot_l)

	# 3. Cotyledon Right: Daun kotiledon kanan berbentuk siluet V khas (+35 derajat)
	var cot_r := MeshInstance3D.new()
	cot_r.name = "CotyledonRight"
	var box_r := BoxMesh.new()
	box_r.size = Vector3(0.070, 0.010, 0.045)
	cot_r.mesh = box_r
	cot_r.position = Vector3(0.032, 0.115, 0)
	cot_r.rotation = Vector3(0, 0, deg_to_rad(35))
	cot_r.material_override = mat_sprout
	root.add_child(cot_r)

func _build_stage_2_growing(root: Node3D) -> void:
	root.set_meta("crop_height", 0.30)
	root.set_meta("primitive_count", 7)
	root.set_meta("stage_color", Color(0.22, 0.68, 0.20))

	var mat_veg := _get_crop_material(Color(0.22, 0.68, 0.20), 0.65)

	# 1. Stem: Batang tegak kokoh setinggi 0.24m
	var stem := MeshInstance3D.new()
	stem.name = "Stem"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.016
	cyl.height = 0.24
	cyl.radial_segments = 6
	stem.mesh = cyl
	stem.position = Vector3(0, 0.12, 0)
	stem.material_override = mat_veg
	root.add_child(stem)

	# 2. 6 Rosette Leaves: 6 helai daun roset menyebar melingkar (staggered 2-tier)
	for i in range(6):
		var leaf := MeshInstance3D.new()
		leaf.name = "Leaf_%d" % i
		var box := BoxMesh.new()
		var angle_deg := i * 60.0
		var angle_rad := deg_to_rad(angle_deg)

		var is_upper := (i % 2 == 1)
		var leaf_len := 0.09 if is_upper else 0.11
		var leaf_y := 0.22 if is_upper else 0.12
		var radial_dist := 0.050 if is_upper else 0.065
		var pitch_tilt := -15.0 if is_upper else 12.0

		box.size = Vector3(leaf_len, 0.010, 0.040 if is_upper else 0.045)
		leaf.mesh = box

		var lx := radial_dist * cos(angle_rad)
		var lz := radial_dist * sin(angle_rad)
		leaf.position = Vector3(lx, leaf_y, lz)
		leaf.rotation = Vector3(deg_to_rad(pitch_tilt), -angle_rad, 0)
		leaf.material_override = mat_veg
		root.add_child(leaf)

func _build_stage_3_harvestable(root: Node3D) -> void:
	root.set_meta("crop_height", 0.50)
	root.set_meta("primitive_count", 10)
	root.set_meta("stage_color", Color(0.14, 0.58, 0.18))

	var mat_mature := _get_crop_material(Color(0.14, 0.58, 0.18), 0.65)
	var mat_plume := _get_crop_material(Color(0.48, 0.58, 0.22), 0.75)

	# 1. Main Stalk: Batang tegak dewasa setinggi 0.38m
	var stalk := MeshInstance3D.new()
	stalk.name = "MainStalk"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.015
	cyl.bottom_radius = 0.022
	cyl.height = 0.38
	cyl.radial_segments = 6
	stalk.mesh = cyl
	stalk.position = Vector3(0, 0.19, 0)
	stalk.material_override = mat_mature
	root.add_child(stalk)

	# 2. Canopy Foliage: 8 helai daun rimbun, lebar kanopi mencapai 0.45m
	for i in range(8):
		var leaf := MeshInstance3D.new()
		leaf.name = "CanopyLeaf_%d" % i
		var box := BoxMesh.new()
		var angle_deg := i * 45.0
		var angle_rad := deg_to_rad(angle_deg)

		var is_upper := (i % 2 == 1)
		var leaf_len := 0.13 if is_upper else 0.16
		var leaf_y := 0.26 if is_upper else 0.15
		var radial_dist := 0.075 if is_upper else 0.105
		var pitch_tilt := -10.0 if is_upper else 10.0

		box.size = Vector3(leaf_len, 0.012, 0.055 if is_upper else 0.065)
		leaf.mesh = box

		var lx := radial_dist * cos(angle_rad)
		var lz := radial_dist * sin(angle_rad)
		leaf.position = Vector3(lx, leaf_y, lz)
		leaf.rotation = Vector3(deg_to_rad(pitch_tilt), -angle_rad, 0)
		leaf.material_override = mat_mature
		root.add_child(leaf)

	# 3. Flowering Plume: Bulir bunga / inflorescence spike di puncak mencapai Y = 0.50m
	var plume := MeshInstance3D.new()
	plume.name = "FloweringPlume"
	var plume_mesh := CylinderMesh.new()
	plume_mesh.top_radius = 0.010
	plume_mesh.bottom_radius = 0.025
	plume_mesh.height = 0.12
	plume_mesh.radial_segments = 6
	plume.mesh = plume_mesh
	plume.position = Vector3(0, 0.44, 0) # Base Y=0.38m, peak Y=0.50m
	plume.material_override = mat_plume
	root.add_child(plume)

func _on_jagung_interacted() -> void:
	var wrm = get_node_or_null("/root/WorldResourceManager")
	if wrm and wrm.has_method("harvest_foraging"):
		wrm.harvest_foraging("resource_jagung_01")

func _on_temu_kunci_interacted() -> void:
	var wrm = get_node_or_null("/root/WorldResourceManager")
	if wrm and wrm.has_method("harvest_foraging"):
		wrm.harvest_foraging("resource_temu_kunci_01")

func _on_reserve_home_interacted() -> void:
	var wrm = get_node_or_null("/root/WorldResourceManager")
	if wrm and wrm.has_method("claim_emergency_reserve"):
		wrm.claim_emergency_reserve()

func _on_bed_home_interacted() -> void:
	var wrm = get_node_or_null("/root/WorldResourceManager")
	if wrm and wrm.has_method("sleep_and_advance_day"):
		wrm.sleep_and_advance_day()

func _on_foraging_state_changed(node_id: String, is_available: bool) -> void:
	if level == null:
		return
	var node = level.get_node_or_null(node_id)
	if node == null:
		return
	if node_id == "resource_jagung_01":
		var corn_ear: MeshInstance3D = node.find_child("CornEar", true, false) as MeshInstance3D
		if corn_ear != null:
			corn_ear.visible = is_available
		else:
			var mesh: MeshInstance3D = node.find_child("Mesh", true, false) as MeshInstance3D
			if mesh != null:
				mesh.visible = is_available
	elif node_id == "resource_temu_kunci_01":
		var herb_mesh: MeshInstance3D = node.get_node_or_null("HerbMesh") as MeshInstance3D
		if herb_mesh != null:
			herb_mesh.visible = is_available

func _on_kitchen_station_interacted(_player_node: Node3D) -> void:
	var im = get_node_or_null("/root/InputManager")
	if im != null and im.is_world_context():
		im.push_context(im.ContextMode.KITCHEN)
	if kitchen_ui != null and kitchen_ui.has_method("open"):
		kitchen_ui.open()

func _on_neighbor_interacted(_player_node: Node3D) -> void:
	var im = get_node_or_null("/root/InputManager")
	if im != null and im.is_world_context():
		im.push_context(im.ContextMode.DIALOGUE)
	if dialogue_ui != null and dialogue_ui.has_method("open"):
		dialogue_ui.open()

