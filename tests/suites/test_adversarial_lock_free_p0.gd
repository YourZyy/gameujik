class_name TestAdversarialLockFreeP0
extends RefCounted

## Adversarial & Stress Testing Harness untuk Milestone SOC-001: Lock-Free & P0 Closure (Suite 17)
## Memverifikasi secara empiris:
## 1. Invarian Bebas Penguncian (Lock-Free): Menanam, merawat, memanen, menjelajah, dan memasak tanpa bicara ke NPC
## 2. Urutan Alternatif: Makan hidangan di tas terlebih dahulu, baru kemudian bicara ke tetangga (adaptasi pohon dialog)
## 3. Repetisi Dialog 100 Kali Tanpa Bocor Memori / Bloat / State Corruption
## 4. Kebebasan Bergerak Pemain (Anti-Softlock & Anti-Freeze) saat Penutup P0 Aktif
## 5. Konservasi Materi & Batas Penyimpanan Peti saat Berbagi Hidangan
## 6. Ketahanan Snapshot Save Envelope v1 terhadap Data Rusak / Malformed

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const RecipeManagerClass = preload("res://scripts/recipe/recipe_manager.gd")
const GardenManagerClass = preload("res://scripts/gardening/garden_manager.gd")
const WorldResourceManagerClass = preload("res://scripts/world/world_resource_manager.gd")
const KitchenManagerClass = preload("res://scripts/cooking/kitchen_manager.gd")
const DialogueManagerClass = preload("res://scripts/social/dialogue_manager.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")
const DialogueUIClass = preload("res://scripts/ui/dialogue_ui.gd")

func run_all() -> bool:
	var passed := true
	print("==================================================")
	print("[ADVERSARIAL_SUITE] SOC-001 Lock-Free & P0 Closure Verification (Challenger 2)")
	print("==================================================")
	var tree := Engine.get_main_loop() as SceneTree

	# Challenge 1: Lock-Free Invariant (Zero NPC Interaction)
	if not test_adv01_lock_free_zero_npc_end_to_end_farming_and_cooking():
		passed = false

	# Challenge 2: Alternative Sequence (Eat First, Then Talk to Neighbor)
	if not test_adv02_alternative_sequence_eat_in_backpack_then_talk_to_neighbor():
		passed = false

	# Challenge 3: 100x Dialogue Repetition & Memory Leak Oracle
	if not await test_adv03_100x_dialogue_repetition_stress_and_leak_oracle(tree):
		passed = false

	# Challenge 4: Player Movement Freedom & Anti-Softlock Oracle
	if not await test_adv04_player_movement_freedom_and_anti_softlock_oracle(tree):
		passed = false

	# Challenge 5: Storage Chest Sharing & Matter Conservation Stress
	if not test_adv05_storage_chest_sharing_and_matter_conservation_stress():
		passed = false

	# Challenge 6: Malformed Save Snapshot Resilience
	if not test_adv06_malformed_save_snapshot_resilience():
		passed = false

	return passed

# ==============================================================================
# Helper Factories
# ==============================================================================

func _create_clean_env() -> Dictionary:
	var inv = InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.storage_home.clear()

	var rm = RecipeManagerClass.new()
	rm.set_inventory_manager(inv)
	rm._ready()

	var gm = GardenManagerClass.new()
	gm.set_inventory_manager(inv)
	gm.reset_to_defaults()

	var wrm = WorldResourceManagerClass.new()
	wrm._ready()
	wrm.set_meal_used(false)

	var km = KitchenManagerClass.new()
	km.set_inventory_manager(inv)
	km.set_recipe_manager(rm)
	km._ready()

	var dm = DialogueManagerClass.new()
	dm._ready()
	dm.bind_managers(inv, rm, wrm, km)

	return {
		"inv": inv,
		"rm": rm,
		"gm": gm,
		"wrm": wrm,
		"km": km,
		"dm": dm
	}

func _cleanup_env(env: Dictionary) -> void:
	for key in env:
		var node = env[key]
		if node is Object and is_instance_valid(node):
			node.free()

# ==============================================================================
# CHALLENGE 1: Absolute Lock-Free Zero-NPC Lifecycle
# ==============================================================================

func test_adv01_lock_free_zero_npc_end_to_end_farming_and_cooking() -> bool:
	print("  [RUN] ADV.LF-01: Absolute Lock-Free Zero-NPC Lifecycle (Farming, Foraging, Cooking & Eating)")
	var env := _create_clean_env()
	var inv = env["inv"]
	var rm = env["rm"]
	var gm = env["gm"]
	var wrm = env["wrm"]
	var km = env["km"]
	var dm = env["dm"]

	# Oracle 1: Baseline Dialogue Invariant - NPC has never been contacted
	Assertions.assert_false(dm.has_talked_to_npc(), "ADV.LF-01: NPC belum pernah diajak bicara")
	Assertions.assert_false(dm.has_spoken_intro, "ADV.LF-01: Intro dialog belum pernah dipicu")
	Assertions.assert_false(dm.is_dialogue_active(), "ADV.LF-01: Dialog tidak aktif")

	# Step 1: Berikan alat dan bahan awal ke tas pemain
	inv.backpack.add_item("tool_hoe", 1)
	inv.backpack.add_item("soil_compost", 1)
	inv.backpack.add_item("seed_bayam", 4)
	inv.backpack.add_item("fertilizer_basic", 1)
	inv.backpack.add_item("tool_watering_can", 1)

	# Step 2: Siklus Berkebun Bayam Mandiri (Tanpa Dialog)
	Assertions.assert_true(gm.hoe_plot("plot_home_01"), "ADV.LF-01: Gemburkan petak sukses mandiri")
	Assertions.assert_true(gm.add_compost("plot_home_01"), "ADV.LF-01: Tambah pembenah kompos sukses mandiri")
	Assertions.assert_true(gm.is_plot_ready_to_plant("plot_home_01"), "ADV.LF-01: Petak siap ditanami")

	# Tanam benih bayam di 3 titik
	Assertions.assert_true(gm.plant_seed("plot_home_01", "slot_01", "seed_bayam"), "ADV.LF-01: Tanam slot_01 sukses")
	Assertions.assert_true(gm.plant_seed("plot_home_01", "slot_02", "seed_bayam"), "ADV.LF-01: Tanam slot_02 sukses")
	Assertions.assert_true(gm.plant_seed("plot_home_01", "slot_03", "seed_bayam"), "ADV.LF-01: Tanam slot_03 sukses")

	# Beri pupuk, isi air dan siram petak
	Assertions.assert_true(gm.fertilize_plot("plot_home_01"), "ADV.LF-01: Pupuk petak sukses")
	gm.refill_water()
	Assertions.assert_true(gm.water_plot("plot_home_01"), "ADV.LF-01: Siram petak sukses")

	# Simulasikan pertumbuhan 180 detik hingga panen
	gm._simulate_plot_growth("plot_home_01", 185.0)

	# Panen 3 titik bayam
	Assertions.assert_true(gm.harvest_crop("plot_home_01", "slot_01"), "ADV.LF-01: Panen slot_01 sukses")
	Assertions.assert_true(gm.harvest_crop("plot_home_01", "slot_02"), "ADV.LF-01: Panen slot_02 sukses")
	Assertions.assert_true(gm.harvest_crop("plot_home_01", "slot_03"), "ADV.LF-01: Panen slot_03 sukses")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 3, "ADV.LF-01: Pemain memiliki 3 bayam di tas")

	# Step 3: Pemanenan Liar di Dunia (Jagung dan Temu Kunci)
	wrm.set_inventory_manager(inv)
	Assertions.assert_true(wrm.is_foraging_node_available("resource_jagung_01"), "ADV.LF-01: Node jagung tersedia")
	Assertions.assert_true(wrm.is_foraging_node_available("resource_temu_kunci_01"), "ADV.LF-01: Node temu kunci tersedia")

	var corn_res: bool = wrm.harvest_foraging("resource_jagung_01")
	var temu_res: bool = wrm.harvest_foraging("resource_temu_kunci_01")
	Assertions.assert_true(corn_res, "ADV.LF-01: Panen jagung liar sukses")
	Assertions.assert_true(temu_res, "ADV.LF-01: Panen temu kunci liar sukses")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 1, "ADV.LF-01: Pemain memiliki 1 jagung di tas")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 1, "ADV.LF-01: Pemain memiliki 1 temu kunci di tas")

	# Step 4: Memasak di Dapur Rumah
	var res_reserve: Dictionary = km.reserve_ingredients("recipe_sayur_bening_01")
	Assertions.assert_true(res_reserve.get("success", false), "ADV.LF-01: Reservasi bahan dapur sukses")

	km.start_prep()
	km.advance_prep(4.0)
	km.start_cooking("medium")
	km.advance_cooking(30.0)

	var claim_res: Dictionary = km.claim_dish_output()
	Assertions.assert_true(claim_res.get("success", false), "ADV.LF-01: Klaim hidangan sukses")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 1, "ADV.LF-01: 1 porsi hidangan tersimpan di tas")
	Assertions.assert_true(rm.is_recipe_completed("recipe_sayur_bening_01"), "ADV.LF-01: Resep tercatat selesai di RecipeManager")

	# Step 5: Makan Hidangan Langsung dari Tas
	var eat_res: Dictionary = km.eat_dish("dish_sayur_bening")
	Assertions.assert_true(eat_res.get("success", false), "ADV.LF-01: Aksi makan hidangan dari tas sukses")
	Assertions.assert_true(km.meal_used, "ADV.LF-01: meal_used = true")
	Assertions.assert_true(eat_res.get("p0_completed", false), "ADV.LF-01: Penutup P0 terpenuhi 100%")

	# Oracle 2: Invarian Lock-Free Terbukti Penuh
	Assertions.assert_false(dm.has_talked_to_npc(), "ADV.LF-01: INVARIANT: has_talked_to_npc tetap false sepanjang seluruh gameplay")
	Assertions.assert_false(dm.has_spoken_intro, "ADV.LF-01: INVARIANT: has_spoken_intro tetap false")
	Assertions.assert_false(dm.has_shared_meal(), "ADV.LF-01: INVARIANT: has_shared_meal tetap false")

	_cleanup_env(env)
	print("  [PASS] ADV.LF-01: Absolute Lock-Free Zero-NPC Lifecycle verified.")
	return true

# ==============================================================================
# CHALLENGE 2: Alternative Sequence (Eat First, Then Talk to Neighbor)
# ==============================================================================

func test_adv02_alternative_sequence_eat_in_backpack_then_talk_to_neighbor() -> bool:
	print("  [RUN] ADV.LF-02: Alternative Sequence (Eat First, Then Talk to Neighbor & Tree Adaptation)")
	var env := _create_clean_env()
	var inv = env["inv"]
	var rm = env["rm"]
	var km = env["km"]
	var dm = env["dm"]

	# Selesaikan resep dan makan hidangan
	rm.mark_recipe_completed("recipe_sayur_bening_01")
	inv.backpack.add_item("dish_sayur_bening", 1)
	var eat_res: Dictionary = km.eat_dish("dish_sayur_bening")
	Assertions.assert_true(eat_res.get("success", false), "ADV.LF-02: Hidangan berhasil dimakan")
	Assertions.assert_true(km.meal_used, "ADV.LF-02: meal_used aktif")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 0, "ADV.LF-02: Hidangan di tas 0")

	# Sekarang pemain mendatangi tetangga untuk PERTAMA KALI
	var node1: Dictionary = dm.start_dialogue("npc_neighbor_01")
	Assertions.assert_equal(node1.get("id"), "npc_intro", "ADV.LF-02: Node awal harus npc_intro walau sudah makan")

	# Periksa opsi choices: tidak boleh ada opsi berbagi karena hidangan 0
	var choices: Array = node1.get("choices", [])
	var has_share_choice: bool = false
	for ch in choices:
		if str(ch.get("id")) == "choice_share":
			has_share_choice = true
	Assertions.assert_false(has_share_choice, "ADV.LF-02: Opsi berbagi TIDAK MUNCUL karena stok hidangan 0")

	# Pemain menanyakan tentang bayam
	var node_bayam: Dictionary = dm.on_dialogue_choice("choice_hint_bayam")
	Assertions.assert_equal(node_bayam.get("id"), "npc_hint_bayam", "ADV.LF-02: Masuk ke hint bayam")

	# Pemain kembali ke intro
	var node_back: Dictionary = dm.on_dialogue_choice("choice_back_intro")
	Assertions.assert_equal(node_back.get("id"), "npc_intro", "ADV.LF-02: Berhasil kembali ke intro")

	# Pemain menutup dialog
	dm.close_dialogue()
	Assertions.assert_false(dm.is_dialogue_active(), "ADV.LF-02: Dialog tertutup")
	Assertions.assert_true(dm.has_talked_to_npc(), "ADV.LF-02: has_talked_to_npc menjadi true")

	# Pemain mendatangi tetangga untuk KEDUA KALI (tanpa hidangan)
	var node2: Dictionary = dm.start_dialogue("npc_neighbor_01")
	Assertions.assert_equal(node2.get("id"), "npc_waiting", "ADV.LF-02: Percakapan ke-2 tanpa hidangan masuk npc_waiting")
	Assertions.assert_true(dm.get_current_text().contains("Tidak perlu buru-buru"), "ADV.LF-02: Teks menunggu cocok")
	dm.close_dialogue()

	# Pemain memasak hidangan KEDUA (remake dish)
	inv.backpack.add_item("dish_sayur_bening", 1)
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 1, "ADV.LF-02: Hidangan kedua siap di tas")

	# Pemain mendatangi tetangga untuk KETIGA KALI (kini dengan hidangan kedua)
	var node3: Dictionary = dm.start_dialogue("npc_neighbor_01")
	Assertions.assert_equal(node3.get("id"), "npc_offer", "ADV.LF-02: Pohon dialog adaptif beralih ke npc_offer")
	Assertions.assert_true(dm.get_current_text().contains("Harum sekali"), "ADV.LF-02: Tetangga mencium aroma hidangan")

	# Pemain membatalkan berbagi terlebih dahulu
	var cancel_res: Dictionary = dm.on_dialogue_choice("choice_share_cancel")
	Assertions.assert_true(cancel_res.get("cancelled", false), "ADV.LF-02: Pembatalan berbagi berhasil")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 1, "ADV.LF-02: Stok tetap 1 setelah batal")
	Assertions.assert_false(dm.has_shared_meal(), "ADV.LF-02: has_shared_meal tetap false")

	# Pemain menyetujui berbagi hidangan kedua
	var share_res: Dictionary = dm.on_dialogue_choice("choice_share_confirm")
	Assertions.assert_true(share_res.get("success", false), "ADV.LF-02: Berbagi hidangan kedua berhasil")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 0, "ADV.LF-02: Hidangan terpotong tepat 1")
	Assertions.assert_true(dm.has_shared_meal(), "ADV.LF-02: has_shared_meal kini true")
	Assertions.assert_equal(dm.get_current_node_id(), "npc_received", "ADV.LF-02: Node beralih ke npc_received")
	dm.close_dialogue()

	# Percakapan KEEMPAT: Tetangga mengulang kalimat penutup hangat
	var node4: Dictionary = dm.start_dialogue("npc_neighbor_01")
	Assertions.assert_equal(node4.get("id"), "npc_repeat", "ADV.LF-02: Pasca berbagi selalu npc_repeat")
	Assertions.assert_true(dm.get_current_text().contains("Jangan berhenti di satu panci"), "ADV.LF-02: Pesan kebun berlanjut")
	dm.close_dialogue()

	_cleanup_env(env)
	print("  [PASS] ADV.LF-02: Alternative Sequence verified.")
	return true

# ==============================================================================
# CHALLENGE 3: 100x Dialogue Repetition & Memory Leak Oracle
# ==============================================================================

func test_adv03_100x_dialogue_repetition_stress_and_leak_oracle(tree: SceneTree) -> bool:
	print("  [RUN] ADV.LF-03: 100x Dialogue Repetition Stress & Memory Leak Oracle")
	var env := _create_clean_env()
	var dm = env["dm"]

	# 100 siklus interaksi dialog penuh dengan navigasi percabangan
	for i in range(100):
		var n_intro: Dictionary = dm.start_dialogue("npc_neighbor_01")
		Assertions.assert_true(dm.is_dialogue_active(), "ADV.LF-03: Iterasi %d dialog aktif" % i)

		# Navigasi ke hint bayam
		var n_bayam: Dictionary = dm.on_dialogue_choice("choice_hint_bayam")
		Assertions.assert_equal(n_bayam.get("id"), "npc_hint_bayam", "ADV.LF-03: Navigasi hint bayam iterasi %d" % i)

		# Navigasi ke hint temu kunci
		var n_kunci: Dictionary = dm.on_dialogue_choice("choice_hint_kunci")
		Assertions.assert_equal(n_kunci.get("id"), "npc_hint_kunci", "ADV.LF-03: Navigasi hint kunci iterasi %d" % i)

		# Kembali ke intro
		var n_back: Dictionary = dm.on_dialogue_choice("choice_back_intro")
		Assertions.assert_equal(n_back.get("id"), "npc_intro", "ADV.LF-03: Navigasi back intro iterasi %d" % i)

		# Tutup dialog
		dm.close_dialogue()
		Assertions.assert_false(dm.is_dialogue_active(), "ADV.LF-03: Iterasi %d dialog tertutup" % i)
		Assertions.assert_equal(dm.current_npc_id, "", "ADV.LF-03: current_npc_id ter-reset pada iterasi %d" % i)

	# Uji stabilitas dan kebocoran state internal
	Assertions.assert_equal(dm.dialogue_flags.size(), 0, "ADV.LF-03: dialogue_flags tidak bocor/bloat")
	Assertions.assert_true(dm.has_talked_to_npc(), "ADV.LF-03: has_talked_to_npc tetap konsisten true")

	# Uji instansiasi DialogueUI dengan 50 siklus buka/tutup cepat
	var dialogue_ui_scene = load("res://scenes/ui/dialogue_ui.tscn")
	if dialogue_ui_scene != null:
		var ui = dialogue_ui_scene.instantiate()
		ui.set("_dialogue_manager_override", dm)
		tree.root.add_child(ui)

		for j in range(50):
			ui.open()
			ui._on_choice_pressed("choice_hint_bayam")
			ui._on_choice_pressed("choice_hint_kunci")
			ui.close()

		# Pompa SceneTree 2 frame untuk membersihkan queue_free()
		await tree.process_frame
		await tree.process_frame

		Assertions.assert_false(ui.visible, "ADV.LF-03: UI tertutup bersih")
		ui.queue_free()
		await tree.process_frame

	_cleanup_env(env)
	print("  [PASS] ADV.LF-03: 100x Dialogue Repetition Stress & Memory Leak Oracle verified.")
	return true

# ==============================================================================
# CHALLENGE 4: Player Movement Freedom & Anti-Softlock Oracle
# ==============================================================================

func test_adv04_player_movement_freedom_and_anti_softlock_oracle(tree: SceneTree) -> bool:
	print("  [RUN] ADV.LF-04: Player Movement Freedom & Anti-Softlock Oracle Upon P0 Closure")
	var im = InputManagerClass.new()
	im._ready()
	tree.root.add_child(im)

	var player = PlayerControllerClass.new()
	player._ready()
	tree.root.add_child(player)
	im.register_player(player)

	var env := _create_clean_env()
	var inv = env["inv"]
	var rm = env["rm"]
	var km = env["km"]
	var dm = env["dm"]
	dm.bind_managers(inv, rm, env["wrm"], km, im)

	# --- Jalur 1: Penutup P0 via Makan Hidangan di Dunia Bebas ---
	Assertions.assert_equal(im.get_current_context(), im.ContextMode.WORLD, "ADV.LF-04: Konteks awal WORLD")
	Assertions.assert_true(player.movement_enabled, "ADV.LF-04: Movement enabled di WORLD")
	Assertions.assert_true(player.look_enabled, "ADV.LF-04: Look enabled di WORLD")

	# Selesaikan resep dan makan di tas
	rm.mark_recipe_completed("recipe_sayur_bening_01")
	inv.backpack.add_item("dish_sayur_bening", 1)
	km.eat_dish("dish_sayur_bening")

	# Evaluasi state pemain setelah P0 selesai: pemain HARUS tetap bebas bergerak
	Assertions.assert_equal(im.get_current_context(), im.ContextMode.WORLD, "ADV.LF-04: Konteks tetap WORLD setelah makan")
	Assertions.assert_false(im.is_simulation_paused(), "ADV.LF-04: Simulasi dunia TIDAK dijeda")
	Assertions.assert_true(player.movement_enabled, "ADV.LF-04: Pemain BEBAS bergerak setelah P0 selesai")
	Assertions.assert_true(player.look_enabled, "ADV.LF-04: Kamera pemain BEBAS berputar setelah P0 selesai")

	# Verifikasi kalkulasi vektor gerak WASD 3.0 m/s
	var vel_forward: Vector3 = player.calculate_movement_velocity(Vector2(0, -1), Vector3.ZERO, 0.016, true)
	Assertions.assert_approx_equal(vel_forward.z, -3.0, 0.05, "ADV.LF-04: Kecepatan maju tetap 3.0 m/s tanpa softlock")

	var vel_right: Vector3 = player.calculate_movement_velocity(Vector2(1, 0), Vector3.ZERO, 0.016, true)
	Assertions.assert_approx_equal(vel_right.x, 3.0, 0.05, "ADV.LF-04: Kecepatan geser kanan tetap 3.0 m/s tanpa softlock")

	# --- Jalur 2: Penutup P0 via Berbagi Hidangan di Modal Dialog ---
	# Reset state untuk pengujian penutup via dialog
	dm.reset_state()
	inv.backpack.add_item("dish_sayur_bening", 1)

	var dialogue_ui_scene = load("res://scenes/ui/dialogue_ui.tscn")
	Assertions.assert_not_null(dialogue_ui_scene, "ADV.LF-04: Scene dialogue_ui.tscn tersedia")
	var ui = dialogue_ui_scene.instantiate()
	ui.set("_dialogue_manager_override", dm)
	ui.set("_input_manager_override", im)
	tree.root.add_child(ui)

	# Buka dialog tetangga
	ui.open()
	Assertions.assert_equal(im.get_current_context(), im.ContextMode.DIALOGUE, "ADV.LF-04: Konteks aktif DIALOGUE saat UI terbuka")
	Assertions.assert_false(player.movement_enabled, "ADV.LF-04: Gerak tertahan aman selama dialog aktif")
	Assertions.assert_false(player.look_enabled, "ADV.LF-04: Kamera tertahan aman selama dialog aktif")

	# Pilih opsi bagikan hidangan
	ui._prompt_share_confirmation()
	Assertions.assert_true(ui.confirm_modal.visible, "ADV.LF-04: Modal konfirmasi tampil")

	# Konfirmasi ya -> pemicu sinyal p0_experience_completed
	ui._on_confirm_share_yes()
	Assertions.assert_true(dm.has_shared_meal(), "ADV.LF-04: Hidangan berhasil dibagikan")
	Assertions.assert_true(dm.p0_completed, "ADV.LF-04: p0_completed aktif dari dialog")

	# Pemain menutup antarmuka dialog
	ui.close()
	await tree.process_frame

	# Oracle Krusial Anti-Softlock:
	Assertions.assert_false(ui.visible, "ADV.LF-04: UI dialog tertutup")
	Assertions.assert_equal(im.get_current_context(), im.ContextMode.WORLD, "ADV.LF-04: InputManager kembali ke WORLD")
	Assertions.assert_false(im.is_modal_active(), "ADV.LF-04: Tidak ada modal aktif")
	Assertions.assert_false(im.is_simulation_paused(), "ADV.LF-04: Simulasi berjalan normal")

	# Pemain kembali bebas bergerak dan melihat ke sekeliling
	Assertions.assert_true(player.movement_enabled, "ADV.LF-04: Gerak pemain pulih 100% (movement_enabled == true)")
	Assertions.assert_true(player.look_enabled, "ADV.LF-04: Kendali pandang pulih 100% (look_enabled == true)")

	# Uji coba mouse look pasca penutup P0
	var yaw_before: float = player.get_yaw_degrees()
	player.handle_mouse_look(Vector2(50.0, 20.0))
	var yaw_after: float = player.get_yaw_degrees()
	Assertions.assert_ne(yaw_after, yaw_before, "ADV.LF-04: Pemain dapat memutar kamera bebas pasca penutup P0")

	# Cleanup
	ui.queue_free()
	player.queue_free()
	im.queue_free()
	_cleanup_env(env)
	await tree.process_frame

	print("  [PASS] ADV.LF-04: Player Movement Freedom & Anti-Softlock Oracle verified.")
	return true

# ==============================================================================
# CHALLENGE 5: Storage Chest Sharing & Matter Conservation Stress
# ==============================================================================

func test_adv05_storage_chest_sharing_and_matter_conservation_stress() -> bool:
	print("  [RUN] ADV.LF-05: Storage Chest Sharing & Matter Conservation Stress")
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]

	# Uji 1: Penolakan tanpa stok di seluruh kontainer
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 0, "ADV.LF-05: Tas kosong")
	Assertions.assert_equal(inv.storage_home.get_item_count("dish_sayur_bening"), 0, "ADV.LF-05: Peti kosong")

	var res_bp: Dictionary = dm.share_dish("backpack")
	var res_st: Dictionary = dm.share_dish("storage")
	var res_au: Dictionary = dm.share_dish("auto")

	Assertions.assert_false(res_bp.get("success", true), "ADV.LF-05: share_dish backpack ditolak")
	Assertions.assert_false(res_st.get("success", true), "ADV.LF-05: share_dish storage ditolak")
	Assertions.assert_false(res_au.get("success", true), "ADV.LF-05: share_dish auto ditolak")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 0, "ADV.LF-05: Tidak ada stok negatif di tas")
	Assertions.assert_equal(inv.storage_home.get_item_count("dish_sayur_bening"), 0, "ADV.LF-05: Tidak ada stok negatif di peti")
	Assertions.assert_false(dm.has_shared_meal(), "ADV.LF-05: has_shared_meal tetap false")

	# Uji 2: Prioritas Peti Penyimpanan saat Spesifik Dipilih
	inv.backpack.add_item("dish_sayur_bening", 1)
	inv.storage_home.add_item("dish_sayur_bening", 1)

	var share_storage_res: Dictionary = dm.share_dish("storage")
	Assertions.assert_true(share_storage_res.get("success", false), "ADV.LF-05: Berbagi dari peti sukses")
	Assertions.assert_equal(inv.storage_home.get_item_count("dish_sayur_bening"), 0, "ADV.LF-05: Peti terpotong 1 (sisa 0)")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 1, "ADV.LF-05: Tas utuh (tetap 1)")

	# Uji 3: Penolakan Berbagi Ulang (Anti-Spam & Matter Invariance)
	var repeat_share: Dictionary = dm.share_dish("backpack")
	Assertions.assert_false(repeat_share.get("success", true), "ADV.LF-05: Berbagi ulang ditolak")
	Assertions.assert_true(repeat_share.get("idempotent", false), "ADV.LF-05: Status penolakan idempotent")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 1, "ADV.LF-05: Stok tas tetap 1")

	# Uji 4: Spam Pembatalan 50 Kali pada Pilihan Konfirmasi
	for k in range(50):
		var cancel_choice: Dictionary = dm.on_dialogue_choice("choice_share_cancel")
		Assertions.assert_true(cancel_choice.get("cancelled", false), "ADV.LF-05: Cancel iterasi %d valid" % k)

	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 1, "ADV.LF-05: Stok tetap 1 setelah 50x batal")

	_cleanup_env(env)
	print("  [PASS] ADV.LF-05: Storage Chest Sharing & Matter Conservation Stress verified.")
	return true

# ==============================================================================
# CHALLENGE 6: Malformed Save Snapshot Resilience
# ==============================================================================

func test_adv06_malformed_save_snapshot_resilience() -> bool:
	print("  [RUN] ADV.LF-06: Malformed Save Snapshot Resilience")
	var dm = DialogueManagerClass.new()
	dm._ready()

	# 1. Snapshot kosong
	Assertions.assert_false(dm.load_save_snapshot({}), "ADV.LF-06: Empty dictionary ditolak")

	# 2. Version < 1
	Assertions.assert_false(dm.load_save_snapshot({"version": 0}), "ADV.LF-06: Version 0 ditolak")
	Assertions.assert_false(dm.load_save_snapshot({"version": -5}), "ADV.LF-06: Negative version ditolak")

	# 3. Tipe data terdistorsi (coerced safely)
	var corrupted: Dictionary = {
		"version": 1,
		"has_spoken_intro": "true",
		"has_shared_meal": 12345,
		"meal_used": false,
		"p0_completed": 1,
		"dialogue_flags": {"test_flag": true}
	}
	Assertions.assert_true(dm.load_save_snapshot(corrupted), "ADV.LF-06: Snapshot valid berhasil dimuat")
	Assertions.assert_true(dm.has_talked_to_npc(), "ADV.LF-06: has_spoken_intro coerced boolean")
	Assertions.assert_true(dm.has_shared_meal(), "ADV.LF-06: has_shared_meal coerced boolean")
	Assertions.assert_true(dm.p0_completed, "ADV.LF-06: p0_completed coerced boolean")

	# 4. Kunci asing / injected keys
	var injected: Dictionary = {
		"version": 1,
		"has_spoken_intro": false,
		"has_shared_meal": false,
		"hacked_admin_key": 999999
	}
	Assertions.assert_true(dm.load_save_snapshot(injected), "ADV.LF-06: Injected keys tidak merusak pemuatan")
	Assertions.assert_false(dm.has_talked_to_npc(), "ADV.LF-06: State normal")

	dm.free()
	print("  [PASS] ADV.LF-06: Malformed Save Snapshot Resilience verified.")
	return true
