class_name TestQAPlaythrough
extends RefCounted

## Test Suite QA-001: End-to-End P0 Acceptance Playthrough & Final QA Regression (Suite 26)
## Memverifikasi seluruh alur penerimaan P0 gameplay sesuai dengan PRD FR01–FR22,
## CONTENT.md § 1..14, LEVEL_DESIGN.md, UI_UX.md, TASKS.md QA-001, dan TEST_PLAN.md T01–T60.
##
## Cakupan Utama:
## 1. Baseline Preconditions & Scene Integrity
## 2. Playthrough Scenario A (Clean New Profile, Full P0 Loop):
##    - Spawn (0, 0, 1), Day 1, profil bersih
##    - Recipe Book inspection & HUD recipe tracking
##    - Starter container pickup (4 bayam seeds, 1 compost, 1 fertilizer)
##    - Garden plot prep (cangkul tanah, tambah kompos, tanam 4 benih bayam)
##    - Siram & pupuk petak, simulasi pertumbuhan 4 tahap (180s) tanpa stall, panen 4 bayam + 4 benih
##    - Panen sumber jagung liar (resource_jagung_01)
##    - Panen sumber temu kunci liar (resource_temu_kunci_01)
##    - Isi ulang air penyiram di sumur pekarangan (water_home -> 10/10)
##    - Stasiun dapur (station_kitchen_home): validasi bahan, reservasi 3 bayam, 1 jagung, 1 temu kunci
##    - Aksi tahan persiapan 4s, ganti panas ke Sedang (1.0x progress), masak 30s
##    - Uji jeda memasak saat panel ditutup, buka kembali dapur, selesaikan masak, ambil 1 hidangan
##    - Dialog warga (npc_neighbor_01), opsi berbagi hidangan dengan konfirmasi, konsumsi 1 hidangan
##    - Penutup pengalaman P0 (cooked + meal_used = true, p0_completed = true)
##    - Jaminan nol kehilangan item, nol duplikasi, nol input bleed, dan nol softlock
## 3. Playthrough Scenario B (Mid-Game Checkpoint Save & Resume):
##    - Main sampai mid-growth tanaman dan mid-cooking job
##    - Simpan ke slot manual / autosave envelope v1
##    - Simulasi restart game / reset total state
##    - Muat checkpoint, verifikasi restorasi identik seluruh entitas & state
##    - Lanjutkan dari state termuat hingga hidangan matang dan dibagikan ke tetangga
## 4. Empirical Matter Conservation & Zero-Loss Invariant Oracle
## 5. Input Context Stack & Anti-Softlock Freedom Oracle
## 6. Repeatable Playthrough Idempotency

const Assertions = preload("res://tests/assertions.gd")
const MainClass = preload("res://scripts/main.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const RecipeManagerClass = preload("res://scripts/recipe/recipe_manager.gd")
const GardenManagerClass = preload("res://scripts/gardening/garden_manager.gd")
const WorldResourceManagerClass = preload("res://scripts/world/world_resource_manager.gd")
const KitchenManagerClass = preload("res://scripts/cooking/kitchen_manager.gd")
const DialogueManagerClass = preload("res://scripts/social/dialogue_manager.gd")
const SaveManagerClass = preload("res://scripts/save/save_manager.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")
const HUDClass = preload("res://scripts/ui/hud.gd")

const QA_SANDBOX_DIR: String = "user://test_qa_sandbox/"
const QA_SETTINGS_PATH: String = "user://test_qa_sandbox/settings.cfg"

var _tree: SceneTree = null

func _get_tree() -> SceneTree:
	if _tree == null:
		_tree = Engine.get_main_loop() as SceneTree
	return _tree

func run_all() -> bool:
	var passed := true
	print("\n==================================================")
	print("[SUITE 26] TestQAPlaythrough: End-to-End P0 Acceptance Playthrough & Final QA Regression")
	print("==================================================")

	var tree := _get_tree()
	_setup_qa_sandbox()

	# 1. Baseline Preconditions & Scene Integrity
	if not await test_qa_01_baseline_preconditions(tree):
		passed = false

	# 2. Playthrough Scenario A: Clean New Profile, Full P0 Loop
	if not await test_qa_02_scenario_a_full_p0_loop(tree):
		passed = false

	# 3. Playthrough Scenario B: Mid-Game Checkpoint Save & Resume
	if not await test_qa_03_scenario_b_mid_game_checkpoint_save_and_resume(tree):
		passed = false

	# 4. Matter Conservation & Zero-Item-Loss Oracle
	if not test_qa_04_matter_conservation_and_zero_loss_oracle():
		passed = false

	# 5. Anti-Softlock & Input Context Freedom Oracle
	if not await test_qa_05_anti_softlock_and_input_context_freedom_oracle(tree):
		passed = false

	# 6. Repeatable Playthrough Idempotency
	if not await test_qa_06_repeatable_playthrough_idempotency(tree):
		passed = false

	_teardown_qa_sandbox()
	return passed

# ==============================================================================
# SANDBOX & STATE RESET HELPERS
# ==============================================================================

func _setup_qa_sandbox() -> void:
	_clean_qa_sandbox()
	DirAccess.make_dir_recursive_absolute(QA_SANDBOX_DIR)

func _teardown_qa_sandbox() -> void:
	_clean_qa_sandbox()
	# Restore default SaveManager paths
	var sm = _get_autoload("SaveManager") as SaveManagerClass
	if sm != null:
		sm.set_save_directory("user://")
		sm.set_settings_path("user://settings.cfg")

func _clean_qa_sandbox() -> void:
	if DirAccess.dir_exists_absolute(QA_SANDBOX_DIR):
		var dir := DirAccess.open(QA_SANDBOX_DIR)
		if dir:
			dir.list_dir_begin()
			var fn := dir.get_next()
			while fn != "":
				if not dir.current_is_dir():
					dir.remove(fn)
				fn = dir.get_next()
			dir.list_dir_end()
	if FileAccess.file_exists(QA_SETTINGS_PATH):
		DirAccess.remove_absolute(QA_SETTINGS_PATH)

func _get_autoload(name: String) -> Node:
	var tree := _get_tree()
	if tree != null and tree.root != null and tree.root.has_node(name):
		return tree.root.get_node(name)
	return null

func _clean_root_orphans() -> void:
	var tree := _get_tree()
	if tree != null and tree.root != null:
		var autoloads = [
			"InputManager", "InventoryManager", "RecipeManager",
			"GardenManager", "WorldResourceManager", "KitchenManager",
			"DialogueManager", "SaveManager", "AudioManager"
		]
		for child in tree.root.get_children():
			if child != null and not child.name in autoloads and not child.name.begins_with("@"):
				tree.root.remove_child(child)
				child.free()

func _reset_all_managers() -> void:
	_clean_root_orphans()

	var inv = _get_autoload("InventoryManager")
	if inv != null:
		inv.backpack.clear()
		inv.storage_home.clear()
		inv.kitchen_refund.clear()
		inv.starter_claimed = false
		inv._reservations.clear()
		inv.inventory_updated.emit()

	var rm = _get_autoload("RecipeManager")
	if rm != null:
		rm.untrack_recipe()
		rm.set_cooking_state("idle")
		for r in rm.get_all_recipes():
			r.is_tracked = false
			r.times_cooked = 0
		rm._notes.clear()
		rm._register_default_notes()
		if inv != null:
			rm.set_inventory_manager(inv)

	var gm = _get_autoload("GardenManager")
	if gm != null:
		gm.reset_to_defaults()
		gm.active_tool = gm.TOOL_NONE
		gm.watering_can_water = 0
		if inv != null:
			gm.set_inventory_manager(inv)

	var wrm = _get_autoload("WorldResourceManager")
	if wrm != null:
		wrm.current_day = 1
		wrm.day_active_time = 0.0
		wrm.meal_used = false
		wrm.last_harvested_day = {
			"resource_jagung_01": 0,
			"resource_temu_kunci_01": 0
		}
		wrm.foraging_nodes_refreshed.emit()
		if inv != null:
			wrm.set_inventory_manager(inv)

	var km = _get_autoload("KitchenManager")
	if km != null:
		km.active_job_id = ""
		km.active_recipe_id = ""
		km.job_state = km.JobState.IDLE
		km.current_heat_level = km.HeatLevel.LOW
		km.cook_progress = 0.0
		km.prep_progress = 0.0
		km.meal_used = false
		km.p0_completed = false
		km.reserved_ingredients.clear()
		km.origin_manifest.clear()
		km.dish_output_slot.clear()
		km.current_job.clear()
		if inv != null:
			km.set_inventory_manager(inv)

	var dm = _get_autoload("DialogueManager")
	var im = _get_autoload("InputManager")
	if dm != null:
		dm.reset_state()
		dm.close_dialogue()
		dm.bind_managers(inv, rm, wrm, km, im)

	if im != null:
		im.pop_to_world()

func _create_test_main(tree: SceneTree) -> Node:
	var scene_res = ResourceLoader.load("res://scenes/main.tscn") as PackedScene
	if scene_res == null:
		return null
	var main = scene_res.instantiate()
	tree.root.add_child(main)
	return main

func _free_test_main(main: Node, tree: SceneTree) -> void:
	if main == null:
		return
	if main.get_parent() != null:
		main.get_parent().remove_child(main)
	main.free()

# ==============================================================================
# TEST 1: Baseline Preconditions & Scene Integrity
# ==============================================================================

func test_qa_01_baseline_preconditions(tree: SceneTree) -> bool:
	print("  [RUN] QA-01: Baseline Preconditions & Scene Composition Integrity")
	var initial_failures = Assertions.current_suite_failed

	_reset_all_managers()

	# 1. Autoload Presence
	var autoload_names: Array[String] = [
		"InputManager", "InventoryManager", "RecipeManager",
		"GardenManager", "WorldResourceManager", "KitchenManager",
		"DialogueManager", "SaveManager", "AudioManager"
	]
	for a_name in autoload_names:
		var node := _get_autoload(a_name)
		Assertions.assert_not_null(node, "QA-01: Autoload '%s' harus aktif di SceneTree root" % a_name)

	# 2. Main Scene Instantiation
	var main = _create_test_main(tree)
	Assertions.assert_not_null(main, "QA-01: scenes/main.tscn harus dapat diinstansiasi")
	await tree.process_frame

	# 3. Hierarchy Check
	var player = main.get_node_or_null("Player") as CharacterBody3D
	Assertions.assert_not_null(player, "QA-01: Node Player harus ada di Main")
	Assertions.assert_vector3_approx_equal(player.global_position, Vector3(0, 0, 1), 0.1, "QA-01: Posisi awal Player harus di spawn point (0, 0, 1)")

	var level = main.get_node_or_null("LevelGraybox")
	Assertions.assert_not_null(level, "QA-01: Node LevelGraybox harus ada di Main")

	# 4. Mandatory Landmarks Verification
	var required_landmarks: Array[String] = [
		"container_starter", "plot_home_01", "resource_jagung_01",
		"resource_temu_kunci_01", "water_home", "station_kitchen_home",
		"npc_neighbor_01", "storage_home", "book_family", "bed_home", "reserve_home"
	]
	for lm_name in required_landmarks:
		var lm_node = level.get_node_or_null(lm_name)
		Assertions.assert_not_null(lm_node, "QA-01: Landmark wajib '%s' harus tersedia di Level" % lm_name)

	# 5. UI Layers Verification
	var hud = main.get_node_or_null("HUD")
	Assertions.assert_not_null(hud, "QA-01: HUD harus ada di Main")
	var book_ui = main.get_node_or_null("BookUI")
	Assertions.assert_not_null(book_ui, "QA-01: BookUI harus ada di Main")
	var kitchen_ui = main.get_node_or_null("KitchenUI")
	Assertions.assert_not_null(kitchen_ui, "QA-01: KitchenUI harus ada di Main")
	var dialogue_ui = main.get_node_or_null("DialogueUI")
	Assertions.assert_not_null(dialogue_ui, "QA-01: DialogueUI harus ada di Main")
	var pause_menu = main.get_node_or_null("PauseMenu")
	Assertions.assert_not_null(pause_menu, "QA-01: PauseMenu harus ada di Main")

	_free_test_main(main, tree)
	await tree.process_frame

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] QA-01: Baseline preconditions & scene composition verified.")
	return ok

# ==============================================================================
# TEST 2: Playthrough Scenario A (Clean New Profile, Full P0 Loop)
# ==============================================================================

func test_qa_02_scenario_a_full_p0_loop(tree: SceneTree) -> bool:
	print("  [RUN] QA-02: Playthrough Scenario A (Clean New Profile, Full P0 Loop)")
	var initial_failures = Assertions.current_suite_failed

	_reset_all_managers()
	var main = _create_test_main(tree)
	await tree.process_frame

	var inv = _get_autoload("InventoryManager") as InventoryManagerClass
	var rm = _get_autoload("RecipeManager") as RecipeManagerClass
	var gm = _get_autoload("GardenManager") as GardenManagerClass
	var wrm = _get_autoload("WorldResourceManager") as WorldResourceManagerClass
	var km = _get_autoload("KitchenManager") as KitchenManagerClass
	var dm = _get_autoload("DialogueManager") as DialogueManagerClass
	var im = _get_autoload("InputManager") as InputManagerClass

	var player = main.get_node_or_null("Player") as CharacterBody3D
	var hud = main.get_node_or_null("HUD") as HUDClass
	var level = main.get_node_or_null("LevelGraybox")

	# --------------------------------------------------------------------------
	# STEP 1: Spawn Point & Clean Profile State
	# --------------------------------------------------------------------------
	Assertions.assert_vector3_approx_equal(player.global_position, Vector3(0, 0, 1), 0.1, "Step 1: Player at spawn point (0, 0, 1)")
	Assertions.assert_equal(wrm.current_day, 1, "Step 1: Start at Day 1")
	Assertions.assert_equal(inv.backpack.get_used_slots_count(), 0, "Step 1: Backpack kosong pada game baru")
	Assertions.assert_false(inv.starter_claimed, "Step 1: starter_claimed = false")
	Assertions.assert_false(rm.is_recipe_tracked("recipe_sayur_bening_01"), "Step 1: Resep belum dilacak")
	Assertions.assert_false(rm.is_recipe_completed("recipe_sayur_bening_01"), "Step 1: Resep belum selesai")
	Assertions.assert_false(dm.has_talked_to_npc(), "Step 1: Belum pernah bicara ke NPC")
	Assertions.assert_false(dm.is_p0_completed(), "Step 1: P0 belum selesai")

	# --------------------------------------------------------------------------
	# STEP 2: Open Recipe Book, Inspect Ingredients & Track on HUD
	# --------------------------------------------------------------------------
	# Buka buku resep (konteks BOOK)
	im.push_context(im.ContextMode.BOOK)
	Assertions.assert_equal(im.get_current_context(), im.ContextMode.BOOK, "Step 2: Konteks beralih ke BOOK")
	Assertions.assert_false(player.movement_enabled, "Step 2: Player movement terkunci saat buku terbuka")

	# Periksa status bahan (0/3 bayam, 0/1 jagung, 0/1 temu kunci)
	var recipe = rm.get_recipe("recipe_sayur_bening_01")
	Assertions.assert_not_null(recipe, "Step 2: Resep sayur bening harus terdaftar")
	Assertions.assert_equal(rm.get_available_ingredient_count("ingredient_bayam"), 0, "Step 2: Bayam tersedia = 0")
	Assertions.assert_equal(rm.get_available_ingredient_count("ingredient_jagung"), 0, "Step 2: Jagung tersedia = 0")
	Assertions.assert_equal(rm.get_available_ingredient_count("ingredient_temu_kunci"), 0, "Step 2: Temu kunci tersedia = 0")

	# Lacak resep pada HUD
	var tracked_ok: bool = rm.track_recipe("recipe_sayur_bening_01")
	Assertions.assert_true(tracked_ok, "Step 2: track_recipe berhasil")
	Assertions.assert_true(rm.is_recipe_tracked("recipe_sayur_bening_01"), "Step 2: Resep tercentang aktif pelacakan")

	# Tutup buku, kembali ke konteks WORLD
	im.pop_context()
	Assertions.assert_true(im.is_world_context(), "Step 2: Kembali ke konteks WORLD")
	await tree.process_frame

	# Verifikasi HUD menampilkan resep terlacak
	if hud != null:
		hud.refresh_tracker()
		var title_lbl: Label = hud.find_child("RecipeTitleLabel", true, false) as Label
		if title_lbl != null:
			Assertions.assert_equal(title_lbl.text, "Sayur Bening Bayam dan Jagung", "Step 2: Judul resep tampil di HUD Tracker")
		var bayam_row: Label = hud.find_child("BayamRow", true, false) as Label
		if bayam_row != null:
			Assertions.assert_true(bayam_row.text.contains("0/3"), "Step 2: HUD mencatat 0/3 bayam")

	# --------------------------------------------------------------------------
	# STEP 3: Pick up Starter Container (container_starter)
	# --------------------------------------------------------------------------
	var starter_node = level.get_node_or_null("container_starter")
	Assertions.assert_not_null(starter_node, "Step 3: Landmark container_starter harus ada")

	# Ambil paket starter wadah pekarangan
	var pickup_ok: bool = inv.pickup_starter_container()
	Assertions.assert_true(pickup_ok, "Step 3: pickup_starter_container berhasil")
	Assertions.assert_true(inv.starter_claimed, "Step 3: starter_claimed = true")

	# Verifikasi isi tas menerima tepat 4 benih, 1 pembenah kompos, 1 pupuk
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "Step 3: Tas menerima 4 benih bayam")
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 1, "Step 3: Tas menerima 1 pembenah kompos")
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 1, "Step 3: Tas menerima 1 pupuk dasar")

	# Uji Anti-Duplikasi (T04): Pengambilan kedua harus ditolak
	var second_pickup: bool = inv.pickup_starter_container()
	Assertions.assert_false(second_pickup, "Step 3: Pengambilan starter kedua kali ditolak (T04)")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "Step 3: Jumlah benih tidak berlipat ganda")

	# --------------------------------------------------------------------------
	# STEP 4: Prepare Garden Plot (plot_home_01) & Plant 4 Spots
	# --------------------------------------------------------------------------
	var plot_node = level.get_node_or_null("plot_home_01")
	Assertions.assert_not_null(plot_node, "Step 4: Landmark plot_home_01 harus ada")

	# Cangkul tanah petak (Gemburkan)
	var hoe_ok: bool = gm.hoe_plot("plot_home_01")
	Assertions.assert_true(hoe_ok, "Step 4: gm.hoe_plot sukses")
	var plot_data: Dictionary = gm.get_plot("plot_home_01")
	Assertions.assert_true(bool(plot_data.get("is_hoed", false)), "Step 4: is_hoed = true")

	# Tambah pembenah kompos ke petak
	var compost_ok: bool = gm.add_compost("plot_home_01")
	Assertions.assert_true(compost_ok, "Step 4: gm.add_compost sukses")
	plot_data = gm.get_plot("plot_home_01")
	Assertions.assert_true(bool(plot_data.get("has_compost", false)), "Step 4: has_compost = true")
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 0, "Step 4: 1 kompos dikonsumsi dari tas (sisa 0)")

	# Tanam 4 benih bayam pada seluruh titik slot_01 s/d slot_04
	for i in range(1, 5):
		var s_id := "slot_%02d" % i
		var plant_ok: bool = gm.plant_seed("plot_home_01", s_id, "seed_bayam")
		Assertions.assert_true(plant_ok, "Step 4: Tanam benih di %s sukses" % s_id)

	# Verifikasi 4 benih habis dari tas dan seluruh titik terisi
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 0, "Step 4: 4 benih bayam ditanam (sisa 0 di tas)")
	plot_data = gm.get_plot("plot_home_01")
	var spots: Dictionary = plot_data.get("spots", {})
	for i in range(1, 5):
		var s_id := "slot_%02d" % i
		var sp: Dictionary = spots[s_id]
		Assertions.assert_true(bool(sp.get("is_occupied", false)), "Step 4: Titik %s terisi tanaman" % s_id)

	# --------------------------------------------------------------------------
	# STEP 5: Water, Fertilize & Simulate 4-Stage Crop Growth (180s) & Harvest
	# --------------------------------------------------------------------------
	# Isi air dan siram petak
	gm.refill_water()
	Assertions.assert_equal(gm.watering_can_water, 10, "Step 5: Penyiram terisi 10/10")
	var water_ok: bool = gm.water_plot("plot_home_01")
	Assertions.assert_true(water_ok, "Step 5: Siram petak sukses")
	plot_data = gm.get_plot("plot_home_01")
	Assertions.assert_approx_equal(float(plot_data.get("moisture", 0.0)), 80.0, 0.1, "Step 5: Kelembapan petak = 80.0")

	# Beri pupuk pada petak
	var fert_ok: bool = gm.fertilize_plot("plot_home_01")
	Assertions.assert_true(fert_ok, "Step 5: Pupuk petak sukses")
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 0, "Step 5: 1 pupuk dasar dikonsumsi dari tas (sisa 0)")
	plot_data = gm.get_plot("plot_home_01")
	Assertions.assert_approx_equal(float(plot_data.get("nutrients", 0.0)), 100.0, 0.1, "Step 5: Nutrisi petak = 100.0")

	# Simulasi Tahap 0 (Benih, 0..30s): verifikasi visual 2 primitif & tinggi 0.04m
	gm._simulate_plot_growth("plot_home_01", 10.0)
	main._on_garden_plot_state_changed("plot_home_01", gm.get_plot("plot_home_01"))
	var spot0_node = plot_node.get_node_or_null("spot_0")
	var crop0_mesh = spot0_node.get_node_or_null("CropMesh") as Node3D
	Assertions.assert_not_null(crop0_mesh, "Step 5: CropMesh harus ada pada spot 0")
	Assertions.assert_equal(crop0_mesh.get_child_count(), 2, "Step 5: Tahap 0 (Benih) memiliki 2 primitif geometris")
	Assertions.assert_approx_equal(float(crop0_mesh.get_meta("crop_height", 0.0)), 0.04, 0.005, "Step 5: Tinggi tahap 0 = 0.04m")

	# Simulasi Tahap 1 (Tunas, 30..90s): advance +30s -> total 40s
	gm._simulate_plot_growth("plot_home_01", 30.0)
	main._on_garden_plot_state_changed("plot_home_01", gm.get_plot("plot_home_01"))
	Assertions.assert_equal(crop0_mesh.get_child_count(), 3, "Step 5: Tahap 1 (Tunas) memiliki 3 primitif geometris")
	Assertions.assert_approx_equal(float(crop0_mesh.get_meta("crop_height", 0.0)), 0.14, 0.005, "Step 5: Tinggi tahap 1 = 0.14m")

	# Simulasi Tahap 2 (Tumbuh, 90..180s): advance +60s -> total 100s
	gm._simulate_plot_growth("plot_home_01", 60.0)
	main._on_garden_plot_state_changed("plot_home_01", gm.get_plot("plot_home_01"))
	Assertions.assert_equal(crop0_mesh.get_child_count(), 7, "Step 5: Tahap 2 (Tumbuh) memiliki 7 primitif geometris")
	Assertions.assert_approx_equal(float(crop0_mesh.get_meta("crop_height", 0.0)), 0.30, 0.005, "Step 5: Tinggi tahap 2 = 0.30m")

	# Simulasi Tahap 3 (Siap Panen, >= 180s): advance +85s -> total 185s
	gm._simulate_plot_growth("plot_home_01", 85.0)
	main._on_garden_plot_state_changed("plot_home_01", gm.get_plot("plot_home_01"))
	Assertions.assert_equal(crop0_mesh.get_child_count(), 10, "Step 5: Tahap 3 (Siap Panen) memiliki 10 primitif geometris")
	Assertions.assert_approx_equal(float(crop0_mesh.get_meta("crop_height", 0.0)), 0.50, 0.005, "Step 5: Tinggi tahap 3 = 0.50m")

	# Panen 4 titik bayam sekaligus
	for i in range(1, 5):
		var s_id := "slot_%02d" % i
		var h_ok: bool = gm.harvest_crop("plot_home_01", s_id)
		Assertions.assert_true(h_ok, "Step 5: Panen titik %s sukses" % s_id)

	# Verifikasi hasil panen masuk ke tas: 4 bayam + 4 benih bayam
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 4, "Step 5: Tas menerima 4 bayam segar")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "Step 5: Tas menerima 4 benih bayam hasil panen")

	# Nutrisi berkurang 5 x 4 = 20 poin (100 -> 80)
	plot_data = gm.get_plot("plot_home_01")
	Assertions.assert_approx_equal(float(plot_data.get("nutrients", 0.0)), 80.0, 0.1, "Step 5: Nutrisi petak berkurang 20 poin (100 -> 80)")

	# --------------------------------------------------------------------------
	# STEP 6: Wild Foraging (Jagung & Temu Kunci)
	# --------------------------------------------------------------------------
	# Panen Jagung Liar
	var corn_ok: bool = wrm.harvest_foraging("resource_jagung_01")
	Assertions.assert_true(corn_ok, "Step 6: Panen jagung liar sukses")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 1, "Step 6: Tas menerima 1 jagung")
	main._on_foraging_state_changed("resource_jagung_01", false)

	# Panen Temu Kunci Liar
	var temu_ok: bool = wrm.harvest_foraging("resource_temu_kunci_01")
	Assertions.assert_true(temu_ok, "Step 6: Panen temu kunci liar sukses")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 1, "Step 6: Tas menerima 1 temu kunci")
	main._on_foraging_state_changed("resource_temu_kunci_01", false)

	# Verifikasi kedua sumber daya terkunci untuk sisa Hari 1 (T37)
	Assertions.assert_false(wrm.is_foraging_node_available("resource_jagung_01"), "Step 6: Jagung terkunci untuk hari ini")
	Assertions.assert_false(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Step 6: Temu kunci terkunci untuk hari ini")

	# --------------------------------------------------------------------------
	# STEP 7: Refill Watering Can at Well Station (water_home)
	# --------------------------------------------------------------------------
	var refill_ok: bool = gm.refill_water()
	Assertions.assert_true(refill_ok, "Step 7: Isi ulang penyiram di sumur sukses")
	Assertions.assert_equal(gm.watering_can_water, 10, "Step 7: Penyiram terisi penuh 10/10")

	# --------------------------------------------------------------------------
	# STEP 8: Kitchen Station Interaction & Ingredient Reservation
	# --------------------------------------------------------------------------
	# Verifikasi bahan lengkap untuk resep Sayur Bening
	Assertions.assert_true(rm.can_cook_recipe("recipe_sayur_bening_01"), "Step 8: can_cook_recipe = true")
	Assertions.assert_true(rm.are_ingredients_complete("recipe_sayur_bening_01"), "Step 8: are_ingredients_complete = true")

	# Reservasi bahan: 3 bayam, 1 jagung, 1 temu kunci
	var reserve_res: Dictionary = km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_true(reserve_res.get("success", false), "Step 8: start_preparation berhasil mereservasi bahan")
	Assertions.assert_equal(km.job_state, km.JobState.RESERVED_PREPARING, "Step 8: JobState = RESERVED_PREPARING")

	# Stok bebas tersisa di tas: 1 bayam (4-3), 0 jagung, 0 temu kunci, 4 benih
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 1, "Step 8: Sisa bebas bayam di tas = 1")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 0, "Step 8: Sisa bebas jagung di tas = 0")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 0, "Step 8: Sisa bebas temu kunci di tas = 0")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "Step 8: 4 benih bayam tetap utuh di tas")

	# --------------------------------------------------------------------------
	# STEP 9 & 10: 4s Prep, Heat Medium (1.0x), Cook 30s, Pause, Resume & Claim Output
	# --------------------------------------------------------------------------
	# Tahan persiapan 4.0s
	km.advance_prep(4.0)
	Assertions.assert_equal(km.job_state, km.JobState.READY_TO_HEAT, "Step 9: Persiapan 4s selesai -> READY_TO_HEAT")

	# Mulai memasak pada panas Sedang (1.0x)
	var start_cook_res: Dictionary = km.start_cooking(km.HeatLevel.MEDIUM)
	Assertions.assert_true(start_cook_res.get("success", false), "Step 9: start_cooking Medium sukses")
	Assertions.assert_equal(km.job_state, km.JobState.COOKING, "Step 9: Status bertransisi ke COOKING")
	Assertions.assert_approx_equal(km.get_heat_multiplier(), 1.0, 0.01, "Step 9: Pengali panas Sedang = 1.0x")

	# Masak separuh jalan (15 detik)
	km.advance_cooking(15.0)
	Assertions.assert_approx_equal(km.cook_progress, 15.0, 0.05, "Step 10: Progres memasak mencapai 15.0s")

	# Jeda memasak saat panel dapur ditutup (Esc / tutup jendela)
	var pause_res: Dictionary = km.pause_cooking()
	Assertions.assert_true(pause_res.get("success", false), "Step 10: pause_cooking sukses")
	Assertions.assert_equal(km.job_state, km.JobState.PAUSED, "Step 10: Status bertransisi ke PAUSED")

	# Verifikasi waktu di dunia tidak memajukan masakan yang dijeda (No Stealth Cooking)
	km.advance_cooking(10.0)
	Assertions.assert_approx_equal(km.cook_progress, 15.0, 0.01, "Step 10: Progres tetap 15.0s saat PAUSED")

	# Buka kembali panel dapur & lanjutkan memasak
	var resume_res: Dictionary = km.resume_cooking()
	Assertions.assert_true(resume_res.get("success", false), "Step 10: resume_cooking sukses")
	Assertions.assert_equal(km.job_state, km.JobState.COOKING, "Step 10: Kembali ke COOKING")

	# Masak 15 detik sisanya (total 30 detik selesai)
	km.advance_cooking(15.0)
	Assertions.assert_approx_equal(km.cook_progress, 30.0, 0.05, "Step 10: Progres mencapai 30.0s")
	Assertions.assert_equal(km.job_state, km.JobState.OUTPUT_READY, "Step 10: Status bertransisi ke OUTPUT_READY")

	# Ambil hidangan dari slot output ke tas
	var claim_res: Dictionary = km.claim_dish_output()
	Assertions.assert_true(claim_res.get("success", false), "Step 10: claim_dish_output sukses")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 1, "Step 10: 1 hidangan Sayur Bening masuk ke tas")
	Assertions.assert_true(rm.is_recipe_completed("recipe_sayur_bening_01"), "Step 10: Resep tercatat selesai di RecipeManager")
	Assertions.assert_equal(rm.get_recipe("recipe_sayur_bening_01").times_cooked, 1, "Step 10: times_cooked = 1")

	# --------------------------------------------------------------------------
	# STEP 11: Neighbor NPC Interaction, Meal Sharing & P0 Experience Closure
	# --------------------------------------------------------------------------
	# Dekati tetangga dan buka dialog
	var dia_start: Dictionary = dm.start_dialogue("npc_neighbor_01")
	Assertions.assert_true(dm.is_dialogue_active(), "Step 11: Dialog aktif dengan tetangga")
	Assertions.assert_true(dm.has_dish(), "Step 11: Tetangga mendeteksi hidangan pada pemain")

	# Pilih opsi menawarkan hidangan
	var offer_res: Dictionary = dm.select_choice("choice_share")
	Assertions.assert_equal(dm.get_current_node_id(), dm.NODE_OFFER, "Step 11: Berpindah ke node konfirmasi penawaran hidangan")

	# Konfirmasi berbagi hidangan
	var share_res: Dictionary = dm.select_choice("choice_share_confirm")
	Assertions.assert_true(share_res.get("success", false), "Step 11: share_dish sukses dikonfirmasi")
	Assertions.assert_true(dm.has_shared_meal(), "Step 11: has_shared_meal = true")
	Assertions.assert_true(dm.is_meal_used(), "Step 11: is_meal_used = true")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 0, "Step 11: 1 porsi hidangan dikonsumsi/diberikan (sisa 0)")

	# Verifikasi Penutup P0 (cooked + meal_used)
	Assertions.assert_true(dm.is_p0_completed(), "Step 11: P0 Experience Selesai 100%!")

	# Tutup dialog
	dm.close_dialogue()
	Assertions.assert_false(dm.is_dialogue_active(), "Step 11: Dialog ditutup")

	# --------------------------------------------------------------------------
	# STEP 12: Invariants Audit — Zero Loss, Zero Duplication, Zero Softlock
	# --------------------------------------------------------------------------
	# Audit Isi Tas Pemain:
	# Bayam: 4 panen - 3 masak = 1 sisa
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 1, "Step 12: Audit: tepat 1 bayam tersisa")
	# Benih Bayam: 4 paket awal - 4 tanam + 4 panen = 4 sisa
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "Step 12: Audit: tepat 4 benih bayam tersisa")
	# Jagung: 1 panen - 1 masak = 0 sisa
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 0, "Step 12: Audit: 0 jagung tersisa")
	# Temu Kunci: 1 panen - 1 masak = 0 sisa
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 0, "Step 12: Audit: 0 temu kunci tersisa")
	# Hidangan: 1 matang - 1 dibagi = 0 sisa
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 0, "Step 12: Audit: 0 hidangan tersisa")
	# Peti penyimpanan rumah tetap bersih
	Assertions.assert_equal(inv.storage_home.get_used_slots_count(), 0, "Step 12: Audit: Peti penyimpanan tetap 0 item")

	# Kontrol pemain tetap responsif (Anti-Softlock)
	Assertions.assert_true(im.is_world_context(), "Step 12: Konteks akhir adalah WORLD")
	Assertions.assert_true(player.movement_enabled, "Step 12: Pemain bebas bergerak setelah seluruh loop P0 tuntas")

	_free_test_main(main, tree)
	await tree.process_frame

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] QA-02: Playthrough Scenario A passed 100% with zero defect.")
	return ok

# ==============================================================================
# TEST 3: Playthrough Scenario B (Mid-Game Checkpoint Save & Resume)
# ==============================================================================

func test_qa_03_scenario_b_mid_game_checkpoint_save_and_resume(tree: SceneTree) -> bool:
	print("  [RUN] QA-03: Playthrough Scenario B (Mid-Game Checkpoint Save & Resume)")
	var initial_failures = Assertions.current_suite_failed

	_clean_qa_sandbox()
	_reset_all_managers()

	var sm = _get_autoload("SaveManager") as SaveManagerClass
	sm.set_save_directory(QA_SANDBOX_DIR)
	sm.set_settings_path(QA_SETTINGS_PATH)

	var inv = _get_autoload("InventoryManager") as InventoryManagerClass
	var rm = _get_autoload("RecipeManager") as RecipeManagerClass
	var gm = _get_autoload("GardenManager") as GardenManagerClass
	var wrm = _get_autoload("WorldResourceManager") as WorldResourceManagerClass
	var km = _get_autoload("KitchenManager") as KitchenManagerClass
	var dm = _get_autoload("DialogueManager") as DialogueManagerClass
	var im = _get_autoload("InputManager") as InputManagerClass

	var main = _create_test_main(tree)
	await tree.process_frame
	var player = main.get_node_or_null("Player") as CharacterBody3D

	# --------------------------------------------------------------------------
	# FASE 1: Bentuk Keadaan Mid-Game (Mid-Crops & Mid-Cooking)
	# --------------------------------------------------------------------------
	# 1. Posisi pemain di pekarangan
	var saved_pos := Vector3(12.5, 0.0, 15.0)
	player.global_position = saved_pos

	# 2. Kalender & waktu aktif
	wrm.current_day = 1
	wrm.day_active_time = 250.0

	# 3. Kebun: gembur, kompos, pupuk, siram, tanam 2 titik pada tahap 1 (Tunas 60s)
	inv.pickup_starter_container()
	gm.refill_water()
	gm.hoe_plot("plot_home_01")
	gm.add_compost("plot_home_01")
	gm.fertilize_plot("plot_home_01")
	gm.water_plot("plot_home_01")
	gm.plant_seed("plot_home_01", "slot_01", "seed_bayam")
	gm.plant_seed("plot_home_01", "slot_02", "seed_bayam")
	gm._simulate_plot_growth("plot_home_01", 60.0) # Mencapai tahap 1 (Tunas)
	main._on_garden_plot_state_changed("plot_home_01", gm.get_plot("plot_home_01"))

	# 4. Sumber daya liar: jagung telah dipetik hari ini, temu kunci belum
	wrm.harvest_foraging("resource_jagung_01")
	Assertions.assert_false(wrm.is_foraging_node_available("resource_jagung_01"), "Scenario B: Jagung dipetik")
	Assertions.assert_true(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Scenario B: Temu kunci siap petik")

	# 5. Siapkan bahan dapur untuk masakan yang sedang berjalan:
	# Wadah starter memberikan 4 benih bayam; 2 ditanam, menyisakan tepat 2 di tas.
	# Tambahkan 3 bayam dan 1 temu kunci (jagung sudah didapat dari foraging):
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	rm.track_recipe("recipe_sayur_bening_01")
	km.start_preparation("recipe_sayur_bening_01")
	km.advance_prep(4.0)
	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(18.0) # 18 detik dari 30 detik
	km.pause_cooking() # Dijeda di panel dapur

	Assertions.assert_equal(km.job_state, km.JobState.PAUSED, "Scenario B: JobState adalah PAUSED")
	Assertions.assert_approx_equal(km.cook_progress, 18.0, 0.05, "Scenario B: cook_progress = 18.0s")
	var pre_save_job_id: String = km.active_job_id

	# --------------------------------------------------------------------------
	# FASE 2: Simpan Checkpoint ke Slot Manual (Save Envelope v1)
	# --------------------------------------------------------------------------
	var save_res := sm.save_game("manual")
	Assertions.assert_true(save_res.get("success", false), "Scenario B: sm.save_game('manual') sukses")

	var manual_path := QA_SANDBOX_DIR + "save_manual.json"
	Assertions.assert_true(FileAccess.file_exists(manual_path), "Scenario B: Berkas save_manual.json tercipta")

	# --------------------------------------------------------------------------
	# FASE 3: Simulasi Restart Game / Reset Total State
	# --------------------------------------------------------------------------
	_free_test_main(main, tree)
	_reset_all_managers()
	main = _create_test_main(tree)
	player = main.get_node_or_null("Player") as CharacterBody3D
	await tree.process_frame

	# Verifikasi bahwa state benar-benar telah di-reset
	Assertions.assert_equal(inv.backpack.get_used_slots_count(), 0, "Scenario B: Verifikasi reset: tas kosong")
	Assertions.assert_equal(km.job_state, km.JobState.IDLE, "Scenario B: Verifikasi reset: dapur idle")
	Assertions.assert_equal(gm.get_plot("plot_home_01")["is_hoed"], false, "Scenario B: Verifikasi reset: kebun belum dicangkul")
	Assertions.assert_vector3_approx_equal(player.global_position, Vector3(0, 0, 1), 0.2, "Scenario B: Player di default spawn point (0, 0, 1)")

	# --------------------------------------------------------------------------
	# FASE 4: Muat Checkpoint & Verifikasi Restorasi 100% Identik
	# --------------------------------------------------------------------------
	var load_res := sm.load_game("manual")
	Assertions.assert_true(load_res.get("success", false), "Scenario B: sm.load_game('manual') sukses")
	await tree.process_frame

	# 1. Posisi Pemain dipulihkan
	Assertions.assert_vector3_approx_equal(player.global_position, saved_pos, 0.2, "Scenario B: Posisi player dipulihkan ke (12.5, 0, 15)")

	# 2. Kalender & waktu aktif dipulihkan
	Assertions.assert_equal(wrm.current_day, 1, "Scenario B: Day 1 dipulihkan")
	Assertions.assert_approx_equal(wrm.day_active_time, 250.0, 0.5, "Scenario B: day_active_time dipulihkan")

	# 3. Kebun & tanaman dipulihkan
	var loaded_plot: Dictionary = gm.get_plot("plot_home_01")
	Assertions.assert_true(bool(loaded_plot.get("is_hoed", false)), "Scenario B: is_hoed dipulihkan")
	Assertions.assert_true(bool(loaded_plot.get("has_compost", false)), "Scenario B: has_compost dipulihkan")
	var l_spots: Dictionary = loaded_plot.get("spots", {})
	var sp1: Dictionary = l_spots["slot_01"]
	var sp2: Dictionary = l_spots["slot_02"]
	Assertions.assert_true(bool(sp1.get("is_occupied", false)), "Scenario B: spot 1 terisi tanaman")
	Assertions.assert_true(bool(sp2.get("is_occupied", false)), "Scenario B: spot 2 terisi tanaman")
	Assertions.assert_equal(int(sp1["crop_data"]["growth_stage"]), 1, "Scenario B: spot 1 growth_stage = 1 (Tunas)")
	Assertions.assert_approx_equal(float(sp1["crop_data"]["growth_time"]), 60.0, 0.5, "Scenario B: spot 1 growth_time = 60s")

	# 4. Status Foraging Liar dipulihkan
	Assertions.assert_false(wrm.is_foraging_node_available("resource_jagung_01"), "Scenario B: Jagung tetap berstatus sudah dipetik")
	Assertions.assert_true(wrm.is_foraging_node_available("resource_temu_kunci_01"), "Scenario B: Temu kunci tetap siap dipetik")

	# 5. Dapur dipulihkan persis (PAUSED, cook_progress = 18.0s, bahan tereservasi aman)
	Assertions.assert_equal(km.active_job_id, pre_save_job_id, "Scenario B: Job ID dapur dipulihkan persis")
	Assertions.assert_equal(km.job_state, km.JobState.PAUSED, "Scenario B: JobState dapur tetap PAUSED (T14)")
	Assertions.assert_approx_equal(km.cook_progress, 18.0, 0.05, "Scenario B: cook_progress dipulihkan ke 18.0s")
	Assertions.assert_equal(km.reserved_ingredients.size(), 3, "Scenario B: 3 jenis bahan tereservasi dipulihkan utuh")

	# 6. Tas & resep dipulihkan
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 2, "Scenario B: 2 benih bayam dipulihkan di tas")
	Assertions.assert_true(rm.is_recipe_tracked("recipe_sayur_bening_01"), "Scenario B: Resep terlacak dipulihkan")

	# --------------------------------------------------------------------------
	# FASE 5: Lanjutkan Gameplay dari State Termuat Hingga Penutup P0
	# --------------------------------------------------------------------------
	# Lanjutkan memasak sisa 12 detik
	km.resume_cooking()
	km.advance_cooking(12.0)
	Assertions.assert_approx_equal(km.cook_progress, 30.0, 0.05, "Scenario B: Sisa 12s selesai dimasak (total 30s)")
	Assertions.assert_equal(km.job_state, km.JobState.OUTPUT_READY, "Scenario B: Bertransisi ke OUTPUT_READY")

	# Ambil hidangan
	var claim_res: Dictionary = km.claim_dish_output()
	Assertions.assert_true(claim_res.get("success", false), "Scenario B: claim_dish_output sukses dari save")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 1, "Scenario B: 1 hidangan masuk tas")

	# Bagikan ke tetangga
	dm.start_dialogue("npc_neighbor_01")
	dm.select_choice("choice_share")
	var share_res: Dictionary = dm.select_choice("choice_share_confirm")
	Assertions.assert_true(share_res.get("success", false), "Scenario B: share_dish sukses dari sesi lanjutan")
	Assertions.assert_true(dm.is_p0_completed(), "Scenario B: P0 Selesai pada sesi muat save!")
	dm.close_dialogue()

	_free_test_main(main, tree)
	await tree.process_frame

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] QA-03: Playthrough Scenario B (Checkpoint Save & Resume) passed 100%.")
	return ok

# ==============================================================================
# TEST 4: Matter Conservation & Zero-Item-Loss Oracle
# ==============================================================================

func test_qa_04_matter_conservation_and_zero_loss_oracle() -> bool:
	print("  [RUN] QA-04: Empirical Matter Conservation & Zero-Item-Loss Oracle")
	var initial_failures = Assertions.current_suite_failed

	_reset_all_managers()
	var inv = _get_autoload("InventoryManager") as InventoryManagerClass
	var gm = _get_autoload("GardenManager") as GardenManagerClass
	var wrm = _get_autoload("WorldResourceManager") as WorldResourceManagerClass
	var km = _get_autoload("KitchenManager") as KitchenManagerClass
	var dm = _get_autoload("DialogueManager") as DialogueManagerClass

	# Perhitungan konservasi materi P0:
	# Sumber masuk:
	# 1. Starter crate: +4 seed_bayam, +1 soil_compost, +1 fertilizer_basic (6 item)
	# 2. Panen kebun (4 titik): -4 seed_bayam + 4 ingredient_bayam + 4 seed_bayam (+4 netto)
	# 3. Foraging jagung: +1 ingredient_jagung
	# 4. Foraging temu kunci: +1 ingredient_temu_kunci
	# Total material masuk dunia: 6 + 4 + 1 + 1 = 12 item fisik
	#
	# Penggunaan materi:
	# 1. Kompos dipakai ke tanah: -1 soil_compost
	# 2. Pupuk dipakai ke tanah: -1 fertilizer_basic
	# 3. Dapur reservasi & masak: -3 ingredient_bayam, -1 ingredient_jagung, -1 ingredient_temu_kunci -> +1 dish_sayur_bening
	# 4. Berbagi hidangan ke tetangga: -1 dish_sayur_bening
	#
	# Sisa netto di tas pemain:
	# - ingredient_bayam: 4 - 3 = 1
	# - seed_bayam: 4 - 4 + 4 = 4
	# - total item tersisa = exactly 5 item (1 bayam + 4 benih)

	inv.pickup_starter_container()
	gm.hoe_plot("plot_home_01")
	gm.add_compost("plot_home_01")
	gm.fertilize_plot("plot_home_01")
	gm.refill_water()
	gm.water_plot("plot_home_01")

	for i in range(1, 5):
		gm.plant_seed("plot_home_01", "slot_%02d" % i, "seed_bayam")

	gm._simulate_plot_growth("plot_home_01", 185.0)

	for i in range(1, 5):
		gm.harvest_crop("plot_home_01", "slot_%02d" % i)

	wrm.harvest_foraging("resource_jagung_01")
	wrm.harvest_foraging("resource_temu_kunci_01")

	# Sebelum masak: total item di tas harus tepat 10
	# (4 bayam + 4 benih + 1 jagung + 1 temu kunci = 10)
	var total_pre_cook: int = inv.backpack.get_item_count("ingredient_bayam") + \
		inv.backpack.get_item_count("seed_bayam") + \
		inv.backpack.get_item_count("ingredient_jagung") + \
		inv.backpack.get_item_count("ingredient_temu_kunci")
	Assertions.assert_equal(total_pre_cook, 10, "QA-04: Total item sebelum memasak = 10")

	km.start_preparation("recipe_sayur_bening_01")
	km.advance_prep(4.0)
	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(30.0)
	km.claim_dish_output()

	# Setelah masak: 1 bayam + 4 benih + 1 hidangan = 6
	var total_post_cook: int = inv.backpack.get_item_count("ingredient_bayam") + \
		inv.backpack.get_item_count("seed_bayam") + \
		inv.backpack.get_item_count("dish_sayur_bening")
	Assertions.assert_equal(total_post_cook, 6, "QA-04: Total item setelah memasak = 6")

	dm.start_dialogue("npc_neighbor_01")
	dm.select_choice("choice_share")
	dm.select_choice("choice_share_confirm")
	dm.close_dialogue()

	# Setelah berbagi: 1 bayam + 4 benih = 5
	var total_final: int = inv.backpack.get_item_count("ingredient_bayam") + \
		inv.backpack.get_item_count("seed_bayam")
	Assertions.assert_equal(total_final, 5, "QA-04: Total item akhir = tepat 5")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 0, "QA-04: 0 hidangan tersisa")
	Assertions.assert_equal(inv.storage_home.get_used_slots_count(), 0, "QA-04: 0 item di peti")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] QA-04: Matter conservation oracle verified: 100% mathematical zero-loss balance.")
	return ok

# ==============================================================================
# TEST 5: Anti-Softlock & Input Context Freedom Oracle
# ==============================================================================

func test_qa_05_anti_softlock_and_input_context_freedom_oracle(tree: SceneTree) -> bool:
	print("  [RUN] QA-05: Anti-Softlock & Input Context Stack Freedom Oracle")
	var initial_failures = Assertions.current_suite_failed

	_reset_all_managers()
	var main = _create_test_main(tree)
	await tree.process_frame

	var im = _get_autoload("InputManager") as InputManagerClass
	var player = main.get_node_or_null("Player") as CharacterBody3D
	im.register_player(player)

	# 1. Siklus cepat seluruh modal UI: BOOK -> KITCHEN -> DIALOGUE -> PAUSE -> WORLD
	var modal_contexts: Array[int] = [
		im.ContextMode.BOOK,
		im.ContextMode.KITCHEN,
		im.ContextMode.DIALOGUE,
		im.ContextMode.PAUSE,
		im.ContextMode.STORAGE
	]

	for ctx in modal_contexts:
		im.push_context(ctx)
		Assertions.assert_equal(im.get_current_context(), ctx, "QA-05: Konteks aktif = %d" % ctx)
		Assertions.assert_false(player.movement_enabled, "QA-05: Gerak terkunci saat modal %d" % ctx)
		Assertions.assert_false(player.look_enabled, "QA-05: Kamera terkunci saat modal %d" % ctx)

		# Pop context kembali ke WORLD
		im.pop_context()
		Assertions.assert_true(im.is_world_context(), "QA-05: Berhasil kembali ke WORLD dari modal %d" % ctx)
		Assertions.assert_true(player.movement_enabled, "QA-05: Gerak pulih di WORLD")
		Assertions.assert_true(player.look_enabled, "QA-05: Kamera pulih di WORLD")

	# 2. Uji Rapid Nested Push & Emergency pop_to_world
	im.push_context(im.ContextMode.BOOK)
	im.push_context(im.ContextMode.PAUSE)
	Assertions.assert_equal(im.get_stack_depth(), 3, "QA-05: Stack depth = 3")

	im.pop_to_world()
	Assertions.assert_equal(im.get_stack_depth(), 1, "QA-05: pop_to_world membersihkan seluruh modal stack")
	Assertions.assert_true(im.is_world_context(), "QA-05: Konteks akhir adalah WORLD")
	Assertions.assert_true(player.movement_enabled, "QA-05: Pemain bebas bergerak")

	_free_test_main(main, tree)
	await tree.process_frame

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] QA-05: Anti-softlock & input context stack freedom verified.")
	return ok

# ==============================================================================
# TEST 6: Repeatable Playthrough Idempotency
# ==============================================================================

func test_qa_06_repeatable_playthrough_idempotency(tree: SceneTree) -> bool:
	print("  [RUN] QA-06: Repeatable Playthrough Idempotency (Sequential Double Playthrough)")
	var initial_failures = Assertions.current_suite_failed

	# Jalankan Scenario A kali pertama
	var pass1: bool = await test_qa_02_scenario_a_full_p0_loop(tree)
	Assertions.assert_true(pass1, "QA-06: Playthrough run 1 harus sukses")

	# Reset dan jalankan Scenario A kali kedua tanpa mematikan proses
	var pass2: bool = await test_qa_02_scenario_a_full_p0_loop(tree)
	Assertions.assert_true(pass2, "QA-06: Playthrough run 2 harus sukses secara identik")

	var ok = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("  [PASS] QA-06: Repeatable playthrough idempotency verified (zero state contamination).")
	return ok
