class_name TestSocial
extends RefCounted

## Test Suite SOC-001: Interaksi Sosial, Dialog Tetangga, Berbagi Hidangan, dan Penutup P0 (Suite 15)
## Memverifikasi PRD FR13/FR14/FR21, CONTENT.md § 10, § 11, § 12, PROTOTYPE.md § 5,
## TASKS.md SOC-001, dan TEST_PLAN T43, T44, T45.

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const RecipeManagerClass = preload("res://scripts/recipe/recipe_manager.gd")
const WorldResourceManagerClass = preload("res://scripts/world/world_resource_manager.gd")
const KitchenManagerClass = preload("res://scripts/cooking/kitchen_manager.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")
const DialogueManagerClass = preload("res://scripts/social/dialogue_manager.gd")

func run_all() -> bool:
	var passed := true
	print("  Running TestSocial suite (T43, T44, T45 Neighbor Dialogue, Meal Sharing & P0 Closure)...")
	var tree := Engine.get_main_loop() as SceneTree

	# Group 1: T43 — P0 Closure
	if not test_t43_01_p0_closure_via_eating_dish(): passed = false
	if not test_t43_02_p0_closure_via_sharing_dish(): passed = false
	if not test_t43_03_p0_closure_truth_table_both_conditions_required(): passed = false
	if not test_t43_04_p0_closure_idempotency_no_duplicate_signal(): passed = false

	# Group 2: T44 — Dish Sharing
	if not test_t44_01_sharing_from_backpack_with_confirmation(): passed = false
	if not test_t44_02_sharing_from_storage_chest_with_confirmation(): passed = false
	if not test_t44_03_sharing_cancellation_preserves_stock_and_flags(): passed = false
	if not test_t44_04_no_duplicate_reward_or_matter_generation(): passed = false

	# Group 3: T45 — Dialogue Tree & Lock-Free Invariants
	if not test_t45_01_lock_free_skip_npc_complete_gardening_and_cooking(): passed = false
	if not test_t45_02_dialogue_tree_navigation_pre_sharing(): passed = false
	if not test_t45_03_dialogue_repeatability_post_sharing(): passed = false
	if not test_t45_04_notes_repeatability_note_garden_01(): passed = false

	# Group 4: Edge & Negative Cases
	if not test_edge_01_share_rejected_when_no_dish_anywhere(): passed = false
	if not test_edge_02_anti_spam_repeated_share_confirmation(): passed = false
	if not await test_edge_03_force_close_dialogue_mid_conversation_and_frame_guard(tree): passed = false
	if not test_edge_04_invalid_dialogue_choice_selection(): passed = false
	if not test_edge_05_eat_dish_then_talk_to_npc(): passed = false

	# Group 5: Save/Load Snapshot & 3D Scene Integration
	if not test_save_01_dialogue_state_snapshot_roundtrip(): passed = false
	if not test_context_01_dialogue_input_context_and_simulation_pause(): passed = false
	if not test_landmark_01_npc_neighbor_scene_presence_and_interactable(): passed = false

	return passed

# ==============================================================================
# Helper Factories & Cleanups
# ==============================================================================

func _create_clean_env() -> Dictionary:
	var inv = InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.storage_home.clear()

	var rm = RecipeManagerClass.new()
	rm.set_inventory_manager(inv)
	rm._ready()

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
# GROUP 1: T43 — P0 Closure & Experience Ending Evaluation
# ==============================================================================

func test_t43_01_p0_closure_via_eating_dish() -> bool:
	var env := _create_clean_env()
	var inv = env["inv"]
	var rm = env["rm"]
	var km = env["km"]

	rm.mark_recipe_completed("recipe_sayur_bening_01")
	inv.backpack.add_item("dish_sayur_bening", 1)

	var signals_emitted: Array = []
	if km.has_signal("p0_experience_completed"):
		km.p0_experience_completed.connect(func(): signals_emitted.append("km_p0"))

	var eat_res: Dictionary = km.eat_dish("dish_sayur_bening")
	Assertions.assert_true(eat_res.get("success", false), "T43-01: eat_dish berhasil")
	Assertions.assert_true(km.meal_used, "T43-01: km.meal_used true")
	Assertions.assert_true(eat_res.get("p0_completed", false), "T43-01: p0_completed true pada hasil eat")
	Assertions.assert_equal(signals_emitted.size(), 1, "T43-01: Sinyal p0_experience_completed terpancar tepat 1 kali")
	_cleanup_env(env)
	return true

func test_t43_02_p0_closure_via_sharing_dish() -> bool:
	var env := _create_clean_env()
	var inv = env["inv"]
	var rm = env["rm"]
	var dm = env["dm"]

	rm.mark_recipe_completed("recipe_sayur_bening_01")
	inv.backpack.add_item("dish_sayur_bening", 1)

	var signals_emitted: Array = []
	if dm.has_signal("p0_experience_completed"):
		dm.p0_experience_completed.connect(func(msg): signals_emitted.append(msg))

	var share_res: Dictionary = dm.share_dish("backpack")
	Assertions.assert_true(share_res.get("success", false), "T43-02: share_dish berhasil")
	Assertions.assert_true(dm.is_meal_used(), "T43-02: dm meal_used true")
	Assertions.assert_true(share_res.get("p0_completed", false), "T43-02: p0_completed true pada hasil share")
	Assertions.assert_equal(signals_emitted.size(), 1, "T43-02: Sinyal p0_experience_completed terpancar dari dm")
	Assertions.assert_equal(signals_emitted[0], "Satu resep selesai. Kebun ini baru dimulai.", "T43-02: Pesan penutup cocok verbatim")
	_cleanup_env(env)
	return true

func test_t43_03_p0_closure_truth_table_both_conditions_required() -> bool:
	var env := _create_clean_env()
	var rm = env["rm"]
	var wrm = env["wrm"]

	# Case A: recipe false, meal false -> false
	Assertions.assert_false(rm.is_recipe_completed("recipe_sayur_bening_01") and wrm.is_meal_used(), "T43-03: F & F = F")

	# Case B: recipe true, meal false -> false
	rm.mark_recipe_completed("recipe_sayur_bening_01")
	Assertions.assert_false(rm.is_recipe_completed("recipe_sayur_bening_01") and wrm.is_meal_used(), "T43-03: T & F = F")

	# Case C: recipe false, meal true -> false
	var env_c := _create_clean_env()
	env_c["wrm"].set_meal_used(true)
	Assertions.assert_false(env_c["rm"].is_recipe_completed("recipe_sayur_bening_01") and env_c["wrm"].is_meal_used(), "T43-03: F & T = F")
	_cleanup_env(env_c)

	# Case D: recipe true, meal true -> true
	wrm.set_meal_used(true)
	Assertions.assert_true(rm.is_recipe_completed("recipe_sayur_bening_01") and wrm.is_meal_used(), "T43-03: T & T = T")
	_cleanup_env(env)
	return true

func test_t43_04_p0_closure_idempotency_no_duplicate_signal() -> bool:
	var env := _create_clean_env()
	var inv = env["inv"]
	var rm = env["rm"]
	var km = env["km"]

	rm.mark_recipe_completed("recipe_sayur_bening_01")
	inv.backpack.add_item("dish_sayur_bening", 2)

	var p0_signals: Array = []
	km.p0_experience_completed.connect(func(): p0_signals.append("p0"))

	# Makan pertama -> p0 signal dipicu
	km.eat_dish("dish_sayur_bening")
	Assertions.assert_equal(p0_signals.size(), 1, "T43-04: Sinyal pertama dipancarkan")

	# Makan kedua -> p0 signal TIDAK boleh dipancarkan ulang
	km.eat_dish("dish_sayur_bening")
	Assertions.assert_equal(p0_signals.size(), 1, "T43-04: Sinyal tidak dipancarkan ulang saat konsumsi kedua")
	_cleanup_env(env)
	return true

# ==============================================================================
# GROUP 2: T44 — Dish Sharing with Confirmation & Atomic Consumption
# ==============================================================================

func test_t44_01_sharing_from_backpack_with_confirmation() -> bool:
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]

	inv.backpack.add_item("dish_sayur_bening", 2)
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 2, "T44-01: Awal tas 2 hidangan")

	dm.start_dialogue("npc_neighbor_01")
	var node: Dictionary = dm.get_dialogue_node("npc_offer")
	Assertions.assert_equal(node.get("id"), "npc_offer", "T44-01: Node npc_offer ditemukan")

	var share_res: Dictionary = dm.on_dialogue_choice("choice_share_confirm")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 1, "T44-01: Tas terpotong tepat 1 (sisa 1)")
	Assertions.assert_true(dm.has_shared_meal(), "T44-01: Flag has_shared_meal true")
	Assertions.assert_equal(dm.get_current_node_id(), "npc_received", "T44-01: Dialog beralih ke npc_received")
	_cleanup_env(env)
	return true

func test_t44_02_sharing_from_storage_chest_with_confirmation() -> bool:
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]

	inv.storage_home.add_item("dish_sayur_bening", 1)
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 0, "T44-02: Tas 0 hidangan")
	Assertions.assert_equal(inv.storage_home.get_item_count("dish_sayur_bening"), 1, "T44-02: Peti 1 hidangan")
	Assertions.assert_true(dm.has_dish(), "T44-02: dm.has_dish true via peti")

	var share_res: Dictionary = dm.share_dish("storage")
	Assertions.assert_true(share_res.get("success", false), "T44-02: Berbagi dari peti sukses")
	Assertions.assert_equal(inv.storage_home.get_item_count("dish_sayur_bening"), 0, "T44-02: Peti terpotong tepat 1 (sisa 0)")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 0, "T44-02: Tas tetap 0")
	_cleanup_env(env)
	return true

func test_t44_03_sharing_cancellation_preserves_stock_and_flags() -> bool:
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]

	inv.backpack.add_item("dish_sayur_bening", 1)
	dm.start_dialogue("npc_neighbor_01")
	var cancel_res: Dictionary = dm.on_dialogue_choice("choice_share_cancel")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 1, "T44-03: Stok tas tetap 1 setelah batal")
	Assertions.assert_false(dm.is_meal_used(), "T44-03: meal_used tetap false")
	Assertions.assert_false(dm.has_shared_meal(), "T44-03: has_shared_meal tetap false")
	_cleanup_env(env)
	return true

func test_t44_04_no_duplicate_reward_or_matter_generation() -> bool:
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]

	inv.backpack.add_item("dish_sayur_bening", 1)
	var initial_slots_occupied: int = inv.backpack.get_occupied_slot_count()

	dm.share_dish("backpack")
	var final_slots_occupied: int = inv.backpack.get_occupied_slot_count()

	Assertions.assert_equal(final_slots_occupied, initial_slots_occupied - 1, "T44-04: Slot berkurang 1 tanpa reward fiktif masuk tas")
	_cleanup_env(env)
	return true

# ==============================================================================
# GROUP 3: T45 — Dialogue Tree Navigation & Lock-Free Invariants
# ==============================================================================

func test_t45_01_lock_free_skip_npc_complete_gardening_and_cooking() -> bool:
	var env := _create_clean_env()
	var inv = env["inv"]
	var rm = env["rm"]
	var km = env["km"]

	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	var res_val: Dictionary = km.reserve_ingredients("recipe_sayur_bening_01")
	Assertions.assert_true(res_val.get("success", false), "T45-01: Reservasi dapur sukses tanpa bicara ke NPC")
	km.start_prep()
	km.advance_prep(4.0)
	km.start_cooking("medium")
	km.advance_cooking(30.0)
	var claim_res: Dictionary = km.claim_dish_output()
	Assertions.assert_true(claim_res.get("success", false), "T45-01: Output masakan sukses diklaim")
	Assertions.assert_true(rm.is_recipe_completed("recipe_sayur_bening_01"), "T45-01: Resep selesai mandiri 100%")
	_cleanup_env(env)
	return true

func test_t45_02_dialogue_tree_navigation_pre_sharing() -> bool:
	var env := _create_clean_env()
	var dm = env["dm"]

	dm.start_dialogue("npc_neighbor_01")
	Assertions.assert_equal(dm.get_current_node_id(), "npc_intro", "T45-02: Node awal npc_intro")

	dm.on_dialogue_choice("choice_hint_bayam")
	Assertions.assert_equal(dm.get_current_node_id(), "npc_hint_bayam", "T45-02: Beralih ke npc_hint_bayam")
	Assertions.assert_true(dm.get_current_text().contains("Gemburkan dulu"), "T45-02: Teks hint bayam cocok")

	dm.on_dialogue_choice("choice_back_intro")
	Assertions.assert_equal(dm.get_current_node_id(), "npc_intro", "T45-02: Kembali ke npc_intro")

	dm.on_dialogue_choice("choice_hint_kunci")
	Assertions.assert_equal(dm.get_current_node_id(), "npc_hint_kunci", "T45-02: Beralih ke npc_hint_kunci")
	Assertions.assert_true(dm.get_current_text().contains("Di tepi bambu"), "T45-02: Teks hint kunci cocok")
	_cleanup_env(env)
	return true

func test_t45_03_dialogue_repeatability_post_sharing() -> bool:
	var env := _create_clean_env()
	var dm = env["dm"]

	dm.set_has_shared(true)

	for i in range(5):
		dm.start_dialogue("npc_neighbor_01")
		Assertions.assert_equal(dm.get_current_node_id(), "npc_repeat", "T45-03: Iterasi %d selalu npc_repeat" % i)
		Assertions.assert_true(dm.get_current_text().contains("Kebun kecil juga perlu diteruskan"), "T45-03: Teks konsisten")
		dm.close_dialogue()
	_cleanup_env(env)
	return true

func test_t45_04_notes_repeatability_note_garden_01() -> bool:
	var env := _create_clean_env()
	var rm = env["rm"]

	Assertions.assert_false(rm.is_note_unlocked("note_garden_01"), "T45-04: Catatan awal terkunci")
	var unlocked_first: bool = rm.unlock_note("note_garden_01")
	Assertions.assert_true(unlocked_first, "T45-04: Pembacaan pertama berhasil meng-unlock")
	Assertions.assert_true(rm.is_note_unlocked("note_garden_01"), "T45-04: Catatan kini unlocked")

	var unlocked_second: bool = rm.unlock_note("note_garden_01")
	Assertions.assert_false(unlocked_second, "T45-04: Pembacaan kedua idempotent (return false tanpa duplikasi)")
	Assertions.assert_true(rm.is_note_unlocked("note_garden_01"), "T45-04: Catatan tetap unlocked")
	_cleanup_env(env)
	return true

# ==============================================================================
# GROUP 4: Edge & Negative Test Cases
# ==============================================================================

func test_edge_01_share_rejected_when_no_dish_anywhere() -> bool:
	var env := _create_clean_env()
	var dm = env["dm"]

	var res: Dictionary = dm.share_dish("auto")
	Assertions.assert_false(res.get("success", true), "EDGE-01: Berbagi ditolak saat hidangan kosong")
	Assertions.assert_false(dm.is_meal_used(), "EDGE-01: meal_used tetap false")
	_cleanup_env(env)
	return true

func test_edge_02_anti_spam_repeated_share_confirmation() -> bool:
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]

	inv.backpack.add_item("dish_sayur_bening", 1)

	var res1: Dictionary = dm.share_dish("backpack")
	var res2: Dictionary = dm.share_dish("backpack")

	Assertions.assert_true(res1.get("success", false), "EDGE-02: Panggilan 1 sukses")
	Assertions.assert_false(res2.get("success", true), "EDGE-02: Panggilan 2 ditolak aman")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 0, "EDGE-02: Stok 0 bukan -1")
	_cleanup_env(env)
	return true

func test_edge_03_force_close_dialogue_mid_conversation_and_frame_guard(tree: SceneTree) -> bool:
	var im = InputManagerClass.new()
	im._ready()

	im.push_context(im.ContextMode.DIALOGUE)
	Assertions.assert_equal(im.get_current_context(), im.ContextMode.DIALOGUE, "EDGE-03: Konteks aktif DIALOGUE")
	Assertions.assert_true(im.is_simulation_paused(), "EDGE-03: Simulasi dijeda di DIALOGUE")

	im.pop_context()
	Assertions.assert_equal(im.get_current_context(), im.ContextMode.WORLD, "EDGE-03: Kembali ke WORLD")
	Assertions.assert_false(im.is_simulation_paused(), "EDGE-03: Simulasi aktif kembali")
	Assertions.assert_false(im.can_interact_in_world(), "EDGE-03: Frame guard menahan aksi pada frame penutupan")

	await tree.process_frame
	Assertions.assert_true(im.can_interact_in_world(), "EDGE-03: Aksi dunia aktif kembali setelah frame berganti")
	im.free()
	return true

func test_edge_04_invalid_dialogue_choice_selection() -> bool:
	var env := _create_clean_env()
	var dm = env["dm"]

	dm.start_dialogue("npc_neighbor_01")
	var cur_node: String = dm.get_current_node_id()
	var res: Dictionary = dm.on_dialogue_choice("choice_invalid_xyz_404")
	Assertions.assert_false(res.get("success", true), "EDGE-04: Pilihan invalid ditolak")
	Assertions.assert_equal(dm.get_current_node_id(), cur_node, "EDGE-04: Node dialog tidak bergeser ke state rusak")
	_cleanup_env(env)
	return true

func test_edge_05_eat_dish_then_talk_to_npc() -> bool:
	var env := _create_clean_env()
	var inv = env["inv"]
	var km = env["km"]
	var dm = env["dm"]

	inv.backpack.add_item("dish_sayur_bening", 1)
	km.eat_dish("dish_sayur_bening")
	Assertions.assert_true(km.meal_used, "EDGE-05: Hidangan dimakan sendiri")

	dm.start_dialogue("npc_neighbor_01")
	Assertions.assert_false(dm.has_dish(), "EDGE-05: dm.has_dish false")
	Assertions.assert_ne(dm.get_current_node_id(), "npc_offer", "EDGE-05: Tidak menawarkan hidangan yang sudah dimakan")
	_cleanup_env(env)
	return true

# ==============================================================================
# GROUP 5: Save/Load Snapshot Roundtrip & 3D Landmark Integration
# ==============================================================================

func test_save_01_dialogue_state_snapshot_roundtrip() -> bool:
	var env := _create_clean_env()
	var dm = env["dm"]

	dm.set_has_shared(true)
	dm.set_talked_to_npc(true)
	var snap: Dictionary = dm.get_save_snapshot()

	Assertions.assert_equal(snap.get("version"), 1, "SAVE-01: Envelope version 1")
	Assertions.assert_true(snap.get("has_shared", false), "SAVE-01: has_shared tersimpan true")
	Assertions.assert_true(snap.get("talked_to_npc", false), "SAVE-01: talked_to_npc tersimpan true")

	var dm2 = DialogueManagerClass.new()
	dm2._ready()
	dm2.load_save_snapshot(snap)

	Assertions.assert_true(dm2.has_shared_meal(), "SAVE-01: has_shared terpulihkan true")
	Assertions.assert_true(dm2.has_talked_to_npc(), "SAVE-01: talked_to_npc terpulihkan true")
	dm2.free()
	_cleanup_env(env)
	return true

func test_context_01_dialogue_input_context_and_simulation_pause() -> bool:
	var im = InputManagerClass.new()
	im._ready()

	im.push_context(im.ContextMode.DIALOGUE)
	Assertions.assert_true(im.is_modal_active(), "CTX-01: Modal aktif di DIALOGUE")
	Assertions.assert_true(im.is_simulation_paused(), "CTX-01: Simulasi dijeda di DIALOGUE")

	im.pop_context()
	Assertions.assert_false(im.is_modal_active(), "CTX-01: Modal nonaktif setelah pop")
	Assertions.assert_false(im.is_simulation_paused(), "CTX-01: Simulasi jalan kembali")
	im.free()
	return true

func test_landmark_01_npc_neighbor_scene_presence_and_interactable() -> bool:
	var scene = load("res://scenes/world/level_graybox.tscn").instantiate()
	var npc = scene.get_node_or_null("npc_neighbor_01")
	Assertions.assert_not_null(npc, "LANDMARK-01: Node npc_neighbor_01 ada di level graybox")
	if npc != null:
		Assertions.assert_true(npc.position.distance_to(Vector3(-14, 0, 15)) <= 0.1, "LANDMARK-01: Posisi (-14, 0, 15)")
		var interactable = npc.get_node_or_null("Interactable")
		Assertions.assert_not_null(interactable, "LANDMARK-01: Komponen Interactable ada")
		if interactable != null:
			Assertions.assert_equal(interactable.collision_layer, 4, "LANDMARK-01: Layer bitmask 4 (Layer 3)")
			Assertions.assert_equal(interactable.interaction_id, "landmark_neighbor", "LANDMARK-01: interaction_id landmark_neighbor")
			Assertions.assert_equal(interactable.prompt_action, "Bicara", "LANDMARK-01: prompt_action Bicara")
	scene.free()
	return true
