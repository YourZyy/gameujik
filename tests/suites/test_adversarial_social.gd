class_name TestAdversarialSocial
extends RefCounted

## Adversarial & Stress Testing Harness untuk Milestone SOC-001 (Sistem Berbagi Hidangan & Dialog Warga)
## Memverifikasi secara empiris:
## 1. Uji batas inventaris tas & peti (Inventory Bounds & Partitioning Stress)
## 2. Pembatalan modal berulang kali (Modal Cancellation & Zero-Loss Verification)
## 3. Panggilan spam / konkuren simultan (Rapid-Fire Spam, Re-Entrancy & Signal Deduplication)
## 4. Deteksi defek rekurrensi tak terbatas (DEFECT-SOC-01 Mutual Recursion)

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const RecipeManagerClass = preload("res://scripts/recipe/recipe_manager.gd")
const WorldResourceManagerClass = preload("res://scripts/world/world_resource_manager.gd")
const KitchenManagerClass = preload("res://scripts/cooking/kitchen_manager.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")
const DialogueManagerClass = preload("res://scripts/social/dialogue_manager.gd")
const DialogueUIClass = preload("res://scripts/ui/dialogue_ui.gd")

const DISH_ID: String = "dish_sayur_bening"
const RECIPE_P0_ID: String = "recipe_sayur_bening_01"

func run_all() -> bool:
	var passed := true
	print("==================================================")
	print("[ADVERSARIAL_SUITE] SOC-001 Empirical Stress & Invariant Verification")
	print("==================================================")
	var tree := Engine.get_main_loop() as SceneTree

	# --- SECTION 1: UJI BATAS INVENTARIS TAS & PETI ---
	if not test_adv01_backpack_full_chest_single_dish_auto_share(): passed = false
	if not test_adv02_backpack_full_with_dish_chest_full_non_dish(): passed = false
	if not test_adv03_dual_storage_auto_priority_backpack(): passed = false
	if not test_adv04_dual_storage_explicit_chest_share(): passed = false
	if not test_adv05_strict_source_gating_missing_specified_container(): passed = false
	if not test_adv06_total_saturation_zero_dishes_strict_rejection(): passed = false
	if not test_adv07_max_stack_boundary_20_dishes(): passed = false
	if not test_adv08_fragmented_dish_slots_conservation(): passed = false

	# --- SECTION 2: PEMBATALAN MODAL BERULANG KALI ---
	if not await test_adv09_100x_modal_cancellation_button_zero_loss(tree): passed = false
	if not await test_adv10_100x_modal_cancellation_esc_input_zero_loss(tree): passed = false
	if not test_adv11_50x_dialogue_choice_cancel_zero_loss(): passed = false
	if not await test_adv12_force_close_dialogue_while_modal_active(tree): passed = false
	if not await test_adv13_interleaved_dialogue_navigation_and_cancel(tree): passed = false

	# --- SECTION 3: PANGGILAN SPAM / KONKUREN SIMULTAN ---
	if not test_adv14_100x_rapid_fire_share_spam_single_consumption(): passed = false
	if not await test_adv15_100x_ui_confirm_button_spam_single_consumption(tree): passed = false
	if not test_adv16_alternating_source_contention_spam(): passed = false
	if not test_adv17_reentrancy_defense_via_signal_callback(): passed = false
	if not test_adv18_signal_deduplication_and_p0_closure_single_fire(): passed = false
	if not test_adv19_post_share_save_snapshot_immutability(): passed = false

	# --- SECTION 4: EMPIRICAL DEFECT DETECTION ---
	if not test_adv20_mutual_recursion_defect_on_dialogue_close(): passed = false

	return passed

# ==============================================================================
# Helper Factories & Cleanups
# ==============================================================================

func _create_clean_env() -> Dictionary:
	var inv = InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.storage_home.clear()
	if "kitchen_refund" in inv and inv.kitchen_refund != null:
		inv.kitchen_refund.clear()

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

	var im = InputManagerClass.new()
	im._ready()

	return {
		"inv": inv,
		"rm": rm,
		"wrm": wrm,
		"km": km,
		"dm": dm,
		"im": im
	}

func _cleanup_env(env: Dictionary) -> void:
	for key in env:
		var node = env[key]
		if node is Object and is_instance_valid(node):
			node.free()

func _count_universe_items(inv: Node) -> int:
	var total: int = 0
	if inv.backpack != null:
		for slot in inv.backpack.slots:
			if slot != null and not slot.is_empty():
				total += slot.count
	if inv.storage_home != null:
		for slot in inv.storage_home.slots:
			if slot != null and not slot.is_empty():
				total += slot.count
	if "kitchen_refund" in inv and inv.kitchen_refund != null:
		for slot in inv.kitchen_refund.slots:
			if slot != null and not slot.is_empty():
				total += slot.count
	return total

func _fill_container_with_dummy_items(container: RefCounted, count_per_slot: int = 5) -> void:
	# Isi seluruh slot kosong kontainer dengan item non-hidangan
	var dummy_items = ["ingredient_bayam", "ingredient_jagung", "ingredient_temu_kunci", "seed_bayam"]
	var dummy_idx = 0
	for i in range(container.max_slots):
		if container.slots[i] == null or container.slots[i].is_empty():
			container.slots[i].item_id = dummy_items[dummy_idx % dummy_items.size()]
			container.slots[i].count = count_per_slot
			dummy_idx += 1

func _safely_disconnect_close_recursion(dm: Node, ui: CanvasLayer) -> void:
	if dm != null and dm.has_signal("dialogue_ended"):
		if dm.dialogue_ended.is_connected(ui.close):
			dm.dialogue_ended.disconnect(ui.close)

# ==============================================================================
# SECTION 1: UJI BATAS INVENTARIS TAS & PETI
# ==============================================================================

func test_adv01_backpack_full_chest_single_dish_auto_share() -> bool:
	print("  [RUN] ADV.SOC-01: Tas Penuh Non-Hidangan & Peti Punya 1 Hidangan (Auto Fallback)")
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]

	_fill_container_with_dummy_items(inv.backpack, 3)
	Assertions.assert_equal(inv.backpack.get_occupied_slot_count(), 12, "ADV-01: Tas penuh 12/12 slot")
	Assertions.assert_equal(inv.backpack.get_item_count(DISH_ID), 0, "ADV-01: Tas tidak punya hidangan")

	inv.storage_home.add_item(DISH_ID, 1)
	Assertions.assert_equal(inv.storage_home.get_item_count(DISH_ID), 1, "ADV-01: Peti punya 1 hidangan")
	Assertions.assert_true(dm.has_dish(), "ADV-01: dm.has_dish true melalui peti")

	var res: Dictionary = dm.share_dish("auto")
	Assertions.assert_true(res.get("success", false), "ADV-01: share_dish sukses")
	Assertions.assert_equal(res.get("source"), "storage", "ADV-01: Sumber otomatis memilih storage")
	Assertions.assert_equal(inv.storage_home.get_item_count(DISH_ID), 0, "ADV-01: Peti terpotong tepat 1 (sisa 0)")

	Assertions.assert_equal(inv.backpack.get_occupied_slot_count(), 12, "ADV-01: Tas tetap 12 slot terisi")
	Assertions.assert_true(dm.has_shared_meal(), "ADV-01: Flag has_shared_meal aktif")
	Assertions.assert_true(dm.is_meal_used(), "ADV-01: Flag meal_used aktif")

	_cleanup_env(env)
	print("  [PASS] ADV.SOC-01: Tas Penuh & Peti 1 Hidangan verified.")
	return true

func test_adv02_backpack_full_with_dish_chest_full_non_dish() -> bool:
	print("  [RUN] ADV.SOC-02: Tas Penuh (11 Sampah + 1 Hidangan) & Peti Penuh Non-Hidangan")
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]

	for i in range(11):
		inv.backpack.slots[i].item_id = "seed_bayam"
		inv.backpack.slots[i].count = 2
	inv.backpack.slots[11].item_id = DISH_ID
	inv.backpack.slots[11].count = 1
	Assertions.assert_equal(inv.backpack.get_occupied_slot_count(), 12, "ADV-02: Tas 12 slot terisi penuh")

	_fill_container_with_dummy_items(inv.storage_home, 4)
	Assertions.assert_equal(inv.storage_home.get_occupied_slot_count(), 12, "ADV-02: Peti 12 slot terisi penuh")
	Assertions.assert_equal(inv.storage_home.get_item_count(DISH_ID), 0, "ADV-02: Peti 0 hidangan")

	var res: Dictionary = dm.share_dish("auto")
	Assertions.assert_true(res.get("success", false), "ADV-02: share_dish sukses")
	Assertions.assert_equal(res.get("source"), "backpack", "ADV-02: Terambil dari tas")
	Assertions.assert_equal(inv.backpack.get_item_count(DISH_ID), 0, "ADV-02: Hidangan di tas habis")
	Assertions.assert_equal(inv.backpack.get_occupied_slot_count(), 11, "ADV-02: Slot tas berkurang jadi 11 (1 slot kosong)")
	Assertions.assert_equal(inv.storage_home.get_occupied_slot_count(), 12, "ADV-02: Peti tetap utuh 12 slot")

	_cleanup_env(env)
	print("  [PASS] ADV.SOC-02: Tas Penuh dengan Hidangan verified.")
	return true

func test_adv03_dual_storage_auto_priority_backpack() -> bool:
	print("  [RUN] ADV.SOC-03: Prioritas Auto saat Tas (5) & Peti (10) Sama-sama Punya Hidangan")
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]

	inv.backpack.add_item(DISH_ID, 5)
	inv.storage_home.add_item(DISH_ID, 10)
	Assertions.assert_equal(inv.backpack.get_item_count(DISH_ID), 5, "ADV-03: Tas 5 hidangan")
	Assertions.assert_equal(inv.storage_home.get_item_count(DISH_ID), 10, "ADV-03: Peti 10 hidangan")

	var res: Dictionary = dm.share_dish("auto")
	Assertions.assert_true(res.get("success", false), "ADV-03: share_dish sukses")
	Assertions.assert_equal(res.get("source"), "backpack", "ADV-03: Prioritas auto adalah tas")
	Assertions.assert_equal(inv.backpack.get_item_count(DISH_ID), 4, "ADV-03: Tas berkurang tepat 1 (sisa 4)")
	Assertions.assert_equal(inv.storage_home.get_item_count(DISH_ID), 10, "ADV-03: Peti tidak tersentuh (tetap 10)")

	_cleanup_env(env)
	print("  [PASS] ADV.SOC-03: Prioritas Auto Tas verified.")
	return true

func test_adv04_dual_storage_explicit_chest_share() -> bool:
	print("  [RUN] ADV.SOC-04: Pemotongan Eksplisit dari Peti saat Tas (5) & Peti (10) Ada")
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]

	inv.backpack.add_item(DISH_ID, 5)
	inv.storage_home.add_item(DISH_ID, 10)

	var res: Dictionary = dm.share_dish("storage")
	Assertions.assert_true(res.get("success", false), "ADV-04: share_dish storage sukses")
	Assertions.assert_equal(res.get("source"), "storage", "ADV-04: Terambil dari storage")
	Assertions.assert_equal(inv.storage_home.get_item_count(DISH_ID), 9, "ADV-04: Peti berkurang tepat 1 (sisa 9)")
	Assertions.assert_equal(inv.backpack.get_item_count(DISH_ID), 5, "ADV-04: Tas tetap 5")

	_cleanup_env(env)
	print("  [PASS] ADV.SOC-04: Pemotongan Eksplisit Peti verified.")
	return true

func test_adv05_strict_source_gating_missing_specified_container() -> bool:
	print("  [RUN] ADV.SOC-05: Strict Gating jika Sumber Tertentu Tidak Memiliki Hidangan")
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]

	inv.storage_home.add_item(DISH_ID, 5)
	var res_a: Dictionary = dm.share_dish("backpack")
	Assertions.assert_false(res_a.get("success", true), "ADV-05A: Minta tas ditolak saat tas kosong")
	Assertions.assert_true(res_a.get("reason", "").contains("tidak cukup di tas"), "ADV-05A: Alasan jujur tas tidak cukup")
	Assertions.assert_equal(inv.storage_home.get_item_count(DISH_ID), 5, "ADV-05A: Peti tidak terpotong sembunyi-sembunyi")
	Assertions.assert_false(dm.has_shared_meal(), "ADV-05A: Flag shared tetap false")

	var env_b := _create_clean_env()
	var inv_b = env_b["inv"]
	var dm_b = env_b["dm"]
	inv_b.backpack.add_item(DISH_ID, 5)
	var res_b: Dictionary = dm_b.share_dish("storage")
	Assertions.assert_false(res_b.get("success", true), "ADV-05B: Minta peti ditolak saat peti kosong")
	Assertions.assert_true(res_b.get("reason", "").contains("tidak cukup di peti"), "ADV-05B: Alasan jujur peti tidak cukup")
	Assertions.assert_equal(inv_b.backpack.get_item_count(DISH_ID), 5, "ADV-05B: Tas tidak terpotong sembunyi-sembunyi")
	Assertions.assert_false(dm_b.has_shared_meal(), "ADV-05B: Flag shared tetap false")

	_cleanup_env(env)
	_cleanup_env(env_b)
	print("  [PASS] ADV.SOC-05: Strict Gating Sumber Tertentu verified.")
	return true

func test_adv06_total_saturation_zero_dishes_strict_rejection() -> bool:
	print("  [RUN] ADV.SOC-06: 24 Slot Saturated (Tas & Peti Penuh Non-Hidangan, 0 Hidangan)")
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]

	_fill_container_with_dummy_items(inv.backpack, 5)
	_fill_container_with_dummy_items(inv.storage_home, 5)
	Assertions.assert_equal(inv.backpack.get_occupied_slot_count(), 12, "ADV-06: Tas 12/12")
	Assertions.assert_equal(inv.storage_home.get_occupied_slot_count(), 12, "ADV-06: Peti 12/12")
	var initial_total: int = _count_universe_items(inv)

	var res: Dictionary = dm.share_dish("auto")
	Assertions.assert_false(res.get("success", true), "ADV-06: Ditolak aman saat 0 hidangan")
	Assertions.assert_equal(_count_universe_items(inv), initial_total, "ADV-06: 0 item termutasi")
	Assertions.assert_false(dm.has_shared_meal(), "ADV-06: Flag shared tetap false")

	_cleanup_env(env)
	print("  [PASS] ADV.SOC-06: Saturasi 24 Slot Tanpa Hidangan verified.")
	return true

func test_adv07_max_stack_boundary_20_dishes() -> bool:
	print("  [RUN] ADV.SOC-07: Batas Tumpukan Maksimum 20 Hidangan dalam 1 Slot")
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]

	inv.backpack.slots[0].item_id = DISH_ID
	inv.backpack.slots[0].count = 20
	Assertions.assert_equal(inv.backpack.get_item_count(DISH_ID), 20, "ADV-07: Tumpukan awal 20")
	Assertions.assert_equal(inv.backpack.get_occupied_slot_count(), 1, "ADV-07: Tepat 1 slot terisi")

	var res: Dictionary = dm.share_dish("backpack")
	Assertions.assert_true(res.get("success", false), "ADV-07: share_dish sukses")
	Assertions.assert_equal(inv.backpack.slots[0].count, 19, "ADV-07: Tumpukan menjadi 19")
	Assertions.assert_equal(inv.backpack.get_occupied_slot_count(), 1, "ADV-07: Tidak ada slot hantu/duplikasi")

	_cleanup_env(env)
	print("  [PASS] ADV.SOC-07: Batas Tumpukan 20 Hidangan verified.")
	return true

func test_adv08_fragmented_dish_slots_conservation() -> bool:
	print("  [RUN] ADV.SOC-08: Konservasi Tumpukan Terfragmentasi Multi-Slot")
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]

	inv.backpack.slots[0].item_id = DISH_ID
	inv.backpack.slots[0].count = 1
	inv.backpack.slots[4].item_id = DISH_ID
	inv.backpack.slots[4].count = 2
	inv.backpack.slots[9].item_id = DISH_ID
	inv.backpack.slots[9].count = 5
	Assertions.assert_equal(inv.backpack.get_item_count(DISH_ID), 8, "ADV-08: Awal 8 hidangan terfragmentasi")

	var res: Dictionary = dm.share_dish("backpack")
	Assertions.assert_true(res.get("success", false), "ADV-08: share_dish sukses")
	Assertions.assert_equal(inv.backpack.get_item_count(DISH_ID), 7, "ADV-08: Sisa tepat 7 hidangan")
	Assertions.assert_true(inv.backpack.slots[0].is_empty(), "ADV-08: Slot 0 terpotong dan kini kosong")
	Assertions.assert_equal(inv.backpack.slots[4].count, 2, "ADV-08: Slot 4 tetap 2")
	Assertions.assert_equal(inv.backpack.slots[9].count, 5, "ADV-08: Slot 9 tetap 5")

	_cleanup_env(env)
	print("  [PASS] ADV.SOC-08: Fragmented Multi-Slot Conservation verified.")
	return true

# ==============================================================================
# SECTION 2: PEMBATALAN MODAL BERULANG KALI (ZERO ITEM LOSS)
# ==============================================================================

func test_adv09_100x_modal_cancellation_button_zero_loss(tree: SceneTree) -> bool:
	print("  [RUN] ADV.SOC-09: 100x Pembatalan Modal Berulang via Tombol Batal (Zero Loss Oracle)")
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]
	var im = env["im"]

	inv.backpack.add_item(DISH_ID, 3)
	inv.storage_home.add_item(DISH_ID, 2)
	inv.backpack.add_item("seed_bayam", 4)
	var initial_universe_items: int = _count_universe_items(inv)
	Assertions.assert_equal(initial_universe_items, 9, "ADV-09: Total awal 9 item di semesta")

	var ui_scene = load("res://scenes/ui/dialogue_ui.tscn")
	var ui = ui_scene.instantiate() as CanvasLayer
	ui._dialogue_manager_override = dm
	ui._input_manager_override = im
	tree.root.add_child(ui)
	await tree.process_frame

	ui.open("npc_offer")
	await tree.process_frame

	for i in range(100):
		ui._prompt_share_confirmation()
		Assertions.assert_true(ui.confirm_modal.visible, "ADV-09: Iterasi %d modal terbuka" % i)

		ui._on_cancel_share_pressed()
		Assertions.assert_false(ui.confirm_modal.visible, "ADV-09: Iterasi %d modal tertutup" % i)

		Assertions.assert_equal(_count_universe_items(inv), initial_universe_items, "ADV-09: Iterasi %d semesta item utuh" % i)
		Assertions.assert_false(dm.has_shared_meal(), "ADV-09: Iterasi %d has_shared_meal tetap false" % i)
		Assertions.assert_false(dm.is_meal_used(), "ADV-09: Iterasi %d meal_used tetap false" % i)

	_safely_disconnect_close_recursion(dm, ui)
	ui.close()
	ui.queue_free()
	await tree.process_frame
	_cleanup_env(env)
	print("  [PASS] ADV.SOC-09: 100x Modal Button Cancellation verified.")
	return true

func test_adv10_100x_modal_cancellation_esc_input_zero_loss(tree: SceneTree) -> bool:
	print("  [RUN] ADV.SOC-10: 100x Pembatalan Modal via Action 'pause_menu' (Esc Key) (Zero Loss)")
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]
	var im = env["im"]

	inv.backpack.add_item(DISH_ID, 2)
	inv.storage_home.add_item(DISH_ID, 2)
	var initial_items: int = _count_universe_items(inv)

	var ui_scene = load("res://scenes/ui/dialogue_ui.tscn")
	var ui = ui_scene.instantiate() as CanvasLayer
	ui._dialogue_manager_override = dm
	ui._input_manager_override = im
	tree.root.add_child(ui)
	await tree.process_frame

	var ev_esc = InputEventAction.new()
	ev_esc.action = "pause_menu"
	ev_esc.pressed = true

	for i in range(100):
		ui.open("npc_offer")
		ui._prompt_share_confirmation()
		Assertions.assert_true(ui.confirm_modal.visible, "ADV-10: Iterasi %d modal terbuka" % i)

		ui._unhandled_input(ev_esc)
		Assertions.assert_false(ui.confirm_modal.visible, "ADV-10: Iterasi %d modal tertutup oleh Esc" % i)
		Assertions.assert_true(ui.visible, "ADV-10: Iterasi %d dialog utama tetap terbuka saat modal batal" % i)

		Assertions.assert_equal(_count_universe_items(inv), initial_items, "ADV-10: Iterasi %d 0 item hilang" % i)
		Assertions.assert_false(dm.has_shared_meal(), "ADV-10: Flag shared tetap false")

	_safely_disconnect_close_recursion(dm, ui)
	ui.close()
	ui.queue_free()
	await tree.process_frame
	_cleanup_env(env)
	print("  [PASS] ADV.SOC-10: 100x Modal Esc Cancellation verified.")
	return true

func test_adv11_50x_dialogue_choice_cancel_zero_loss() -> bool:
	print("  [RUN] ADV.SOC-11: 50x Pilihan Dialog Batal 'choice_share_cancel' (Zero Loss)")
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]

	inv.backpack.add_item(DISH_ID, 3)
	var initial_count: int = _count_universe_items(inv)

	for i in range(50):
		dm.start_dialogue("npc_neighbor_01", "npc_offer")
		var res: Dictionary = dm.on_dialogue_choice("choice_share_cancel")
		Assertions.assert_true(res.get("success", false), "ADV-11: Choice cancel sukses")
		Assertions.assert_true(res.get("cancelled", false), "ADV-11: Flag cancelled true")
		Assertions.assert_equal(_count_universe_items(inv), initial_count, "ADV-11: Iterasi %d item utuh" % i)
		Assertions.assert_false(dm.has_shared_meal(), "ADV-11: has_shared_meal tetap false")

	_cleanup_env(env)
	print("  [PASS] ADV.SOC-11: 50x Dialogue Choice Cancel verified.")
	return true

func test_adv12_force_close_dialogue_while_modal_active(tree: SceneTree) -> bool:
	print("  [RUN] ADV.SOC-12: Tutup Paksa Dialog UI Saat Modal Konfirmasi Aktif")
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]
	var im = env["im"]

	inv.backpack.add_item(DISH_ID, 2)
	var initial_count: int = _count_universe_items(inv)

	var ui_scene = load("res://scenes/ui/dialogue_ui.tscn")
	var ui = ui_scene.instantiate() as CanvasLayer
	ui._dialogue_manager_override = dm
	ui._input_manager_override = im
	tree.root.add_child(ui)
	await tree.process_frame

	ui.open("npc_offer")
	ui._prompt_share_confirmation()
	Assertions.assert_true(ui.confirm_modal.visible, "ADV-12: Modal aktif")

	_safely_disconnect_close_recursion(dm, ui)
	ui.close()
	Assertions.assert_false(ui.visible, "ADV-12: UI tertutup")
	Assertions.assert_false(ui.confirm_modal.visible, "ADV-12: Modal konfirmasi ikut tertutup")
	Assertions.assert_false(dm.is_dialogue_active(), "ADV-12: DM dialogue tidak aktif")
	Assertions.assert_equal(_count_universe_items(inv), initial_count, "ADV-12: 0 item terpotong")

	ui.queue_free()
	await tree.process_frame
	_cleanup_env(env)
	print("  [PASS] ADV.SOC-12: Force Close Dialog UI verified.")
	return true

func test_adv13_interleaved_dialogue_navigation_and_cancel(tree: SceneTree) -> bool:
	print("  [RUN] ADV.SOC-13: 25 Siklus Navigasi Pohon Dialog Berselingan Batal Modal")
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]
	var im = env["im"]

	inv.backpack.add_item(DISH_ID, 1)
	var initial_count: int = _count_universe_items(inv)

	var ui_scene = load("res://scenes/ui/dialogue_ui.tscn")
	var ui = ui_scene.instantiate() as CanvasLayer
	ui._dialogue_manager_override = dm
	ui._input_manager_override = im
	tree.root.add_child(ui)
	await tree.process_frame

	_safely_disconnect_close_recursion(dm, ui)

	for i in range(25):
		ui.open()
		dm.on_dialogue_choice("choice_hint_bayam")
		Assertions.assert_equal(dm.get_current_node_id(), "npc_hint_bayam", "ADV-13: Node hint_bayam")
		dm.on_dialogue_choice("choice_back_intro")
		Assertions.assert_equal(dm.get_current_node_id(), "npc_intro", "ADV-13: Node intro")
		dm.on_dialogue_choice("choice_share")
		Assertions.assert_equal(dm.get_current_node_id(), "npc_offer", "ADV-13: Node offer")
		ui._prompt_share_confirmation()
		Assertions.assert_true(ui.confirm_modal.visible, "ADV-13: Modal terbuka")
		ui._on_cancel_share_pressed()
		Assertions.assert_false(ui.confirm_modal.visible, "ADV-13: Modal batal")
		ui.close()
		Assertions.assert_equal(_count_universe_items(inv), initial_count, "ADV-13: Iterasi %d materi kekal" % i)

	ui.queue_free()
	await tree.process_frame
	_cleanup_env(env)
	print("  [PASS] ADV.SOC-13: Interleaved Dialogue Navigation verified.")
	return true

# ==============================================================================
# SECTION 3: PANGGILAN SPAM / KONKUREN SIMULTAN
# ==============================================================================

func test_adv14_100x_rapid_fire_share_spam_single_consumption() -> bool:
	print("  [RUN] ADV.SOC-14: 100x Rapid-Fire Spam share_dish() (Tepat 1 Porsi Terpotong)")
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]

	inv.backpack.add_item(DISH_ID, 5)
	inv.storage_home.add_item(DISH_ID, 5)
	Assertions.assert_equal(inv.backpack.get_item_count(DISH_ID), 5, "ADV-14: Awal tas 5 hidangan")
	Assertions.assert_equal(inv.storage_home.get_item_count(DISH_ID), 5, "ADV-14: Awal peti 5 hidangan")

	var success_count: int = 0
	var reject_count: int = 0

	for i in range(100):
		var res: Dictionary = dm.share_dish("auto")
		if res.get("success", false):
			success_count += 1
		else:
			reject_count += 1
			Assertions.assert_true(res.get("idempotent", false), "ADV-14: Penolakan ditandai idempotent")

	Assertions.assert_equal(success_count, 1, "ADV-14: Tepat 1 panggilan yang berhasil")
	Assertions.assert_equal(reject_count, 99, "ADV-14: 99 panggilan ditolak aman")

	Assertions.assert_equal(inv.backpack.get_item_count(DISH_ID), 4, "ADV-14: Tas terpotong tepat 1 (sisa 4)")
	Assertions.assert_equal(inv.storage_home.get_item_count(DISH_ID), 5, "ADV-14: Peti tetap 5")
	Assertions.assert_equal(_count_universe_items(inv), 9, "ADV-14: Total semesta 9 hidangan")

	_cleanup_env(env)
	print("  [PASS] ADV.SOC-14: 100x Rapid-Fire Share Spam verified.")
	return true

func test_adv15_100x_ui_confirm_button_spam_single_consumption(tree: SceneTree) -> bool:
	print("  [RUN] ADV.SOC-15: 100x Spam Tombol Konfirmasi UI '_on_confirm_share_yes()'")
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]
	var im = env["im"]

	inv.backpack.add_item(DISH_ID, 5)

	var ui_scene = load("res://scenes/ui/dialogue_ui.tscn")
	var ui = ui_scene.instantiate() as CanvasLayer
	ui._dialogue_manager_override = dm
	ui._input_manager_override = im
	tree.root.add_child(ui)
	await tree.process_frame

	ui.open("npc_offer")
	ui._prompt_share_confirmation()

	for i in range(100):
		ui._on_confirm_share_yes()

	Assertions.assert_equal(inv.backpack.get_item_count(DISH_ID), 4, "ADV-15: Tas terpotong tepat 1 (sisa 4)")
	Assertions.assert_true(dm.has_shared_meal(), "ADV-15: has_shared_meal aktif")

	_safely_disconnect_close_recursion(dm, ui)
	ui.close()
	ui.queue_free()
	await tree.process_frame
	_cleanup_env(env)
	print("  [PASS] ADV.SOC-15: 100x UI Confirm Button Spam verified.")
	return true

func test_adv16_alternating_source_contention_spam() -> bool:
	print("  [RUN] ADV.SOC-16: 100 Panggilan Berselingan 'backpack' vs 'storage' (Zero Double Consumption)")
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]

	inv.backpack.add_item(DISH_ID, 5)
	inv.storage_home.add_item(DISH_ID, 5)

	var total_successes: int = 0
	for i in range(50):
		var res_bp = dm.share_dish("backpack")
		if res_bp.get("success", false):
			total_successes += 1
		var res_st = dm.share_dish("storage")
		if res_st.get("success", false):
			total_successes += 1

	Assertions.assert_equal(total_successes, 1, "ADV-16: Tepat 1 transaksi berhasil di tengah kontensi")
	Assertions.assert_equal(inv.backpack.get_item_count(DISH_ID), 4, "ADV-16: Tas terpotong 1 (sisa 4)")
	Assertions.assert_equal(inv.storage_home.get_item_count(DISH_ID), 5, "ADV-16: Peti tetap utuh 5")
	Assertions.assert_equal(_count_universe_items(inv), 9, "ADV-16: Total sisa 9")

	_cleanup_env(env)
	print("  [PASS] ADV.SOC-16: Alternating Source Contention Spam verified.")
	return true

func test_adv17_reentrancy_defense_via_signal_callback() -> bool:
	print("  [RUN] ADV.SOC-17: Pertahanan Re-Entrancy pada Hook Sinyal 'dish_shared'")
	var env := _create_clean_env()
	var inv = env["inv"]
	var dm = env["dm"]

	inv.backpack.add_item(DISH_ID, 5)

	var reentrant_state := {
		"executed": false,
		"result": {}
	}

	dm.dish_shared.connect(func(_id, _cnt, _src):
		reentrant_state["executed"] = true
		reentrant_state["result"] = dm.share_dish("backpack")
	)

	var primary_res: Dictionary = dm.share_dish("backpack")
	Assertions.assert_true(primary_res.get("success", false), "ADV-17: Panggilan utama sukses")
	Assertions.assert_true(reentrant_state["executed"], "ADV-17: Listener re-entrant terpanggil")
	Assertions.assert_false(reentrant_state["result"].get("success", true), "ADV-17: Panggilan nested re-entrant DITOLAK aman")
	Assertions.assert_true(reentrant_state["result"].get("idempotent", false), "ADV-17: Re-entrant ditolak idempotent")

	Assertions.assert_equal(inv.backpack.get_item_count(DISH_ID), 4, "ADV-17: Tas tetap 4, bukan 3!")

	_cleanup_env(env)
	print("  [PASS] ADV.SOC-17: Re-Entrancy Defense verified.")
	return true

func test_adv18_signal_deduplication_and_p0_closure_single_fire() -> bool:
	print("  [RUN] ADV.SOC-18: Deduplikasi Sinyal Penutup P0 (Tepat 1 Emisi dalam 100x Spam)")
	var env := _create_clean_env()
	var inv = env["inv"]
	var rm = env["rm"]
	var dm = env["dm"]

	rm.mark_recipe_completed(RECIPE_P0_ID)
	inv.backpack.add_item(DISH_ID, 3)

	var emissions := {
		"p0": 0,
		"dish_shared": 0,
		"meal_shared": 0,
		"meal_consumed": 0
	}

	dm.p0_experience_completed.connect(func(_msg): emissions["p0"] += 1)
	dm.dish_shared.connect(func(_id, _cnt, _src): emissions["dish_shared"] += 1)
	dm.meal_shared.connect(func(_src, _rem): emissions["meal_shared"] += 1)
	dm.meal_consumed.connect(func(_id, _cnt): emissions["meal_consumed"] += 1)

	for i in range(100):
		dm.share_dish("auto")

	Assertions.assert_equal(emissions["p0"], 1, "ADV-18: p0_experience_completed dipancarkan TEPAT 1 KALI")
	Assertions.assert_equal(emissions["dish_shared"], 1, "ADV-18: dish_shared dipancarkan TEPAT 1 KALI")
	Assertions.assert_equal(emissions["meal_shared"], 1, "ADV-18: meal_shared dipancarkan TEPAT 1 KALI")
	Assertions.assert_equal(emissions["meal_consumed"], 1, "ADV-18: meal_consumed dipancarkan TEPAT 1 KALI")

	_cleanup_env(env)
	print("  [PASS] ADV.SOC-18: Signal Deduplication & Single Fire verified.")
	return true

func test_adv19_post_share_save_snapshot_immutability() -> bool:
	print("  [RUN] ADV.SOC-19: Immutabilitas Snapshot Save/Load Pasca Berbagi & Spam 50x")
	var env := _create_clean_env()
	var inv = env["inv"]
	var rm = env["rm"]
	var dm = env["dm"]

	rm.mark_recipe_completed(RECIPE_P0_ID)
	inv.backpack.add_item(DISH_ID, 2)

	dm.start_dialogue("npc_neighbor_01")
	dm.share_dish("auto")

	var snap1: Dictionary = dm.get_save_snapshot()
	Assertions.assert_true(snap1.get("has_shared_meal", false), "ADV-19: Snapshot 1 has_shared_meal true")
	Assertions.assert_true(snap1.get("p0_completed", false), "ADV-19: Snapshot 1 p0_completed true")

	for i in range(50):
		dm.share_dish("auto")

	var snap2: Dictionary = dm.get_save_snapshot()
	Assertions.assert_equal(snap1.get("has_shared_meal"), snap2.get("has_shared_meal"), "ADV-19: has_shared_meal tidak terkorupsi")
	Assertions.assert_equal(snap1.get("meal_used"), snap2.get("meal_used"), "ADV-19: meal_used stabil")
	Assertions.assert_equal(snap1.get("p0_completed"), snap2.get("p0_completed"), "ADV-19: p0_completed stabil")

	var dm_fresh = DialogueManagerClass.new()
	dm_fresh._ready()
	var load_ok: bool = dm_fresh.load_save_snapshot(snap2)
	Assertions.assert_true(load_ok, "ADV-19: load_save_snapshot sukses")
	Assertions.assert_true(dm_fresh.has_shared_meal(), "ADV-19: dm_fresh has_shared_meal true")
	Assertions.assert_true(dm_fresh.p0_completed, "ADV-19: dm_fresh p0_completed true")

	dm_fresh.free()
	_cleanup_env(env)
	print("  [PASS] ADV.SOC-19: Post-Share Save Snapshot Immutability verified.")
	return true

# ==============================================================================
# SECTION 4: EMPIRICAL DEFECT DETECTION
# ==============================================================================

func test_adv20_mutual_recursion_defect_on_dialogue_close() -> bool:
	print("  [RUN] ADV.SOC-20: Deteksi Defek Rekursi Tak Terbatas DialogueUI.close() <-> DialogueManager.close_dialogue()")
	var env := _create_clean_env()
	var dm = env["dm"]
	var im = env["im"]

	var ui_scene = load("res://scenes/ui/dialogue_ui.tscn")
	var ui = ui_scene.instantiate() as CanvasLayer
	ui._dialogue_manager_override = dm
	ui._input_manager_override = im
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(ui)

	# 1. Verifikasi koneksi sinyal mutual: dm.dialogue_ended terhubung langsung ke ui.close
	var is_connected_to_close: bool = dm.dialogue_ended.is_connected(ui.close)
	Assertions.assert_false(is_connected_to_close, "DEFECT-SOC-01: Sinyal dm.dialogue_ended terhubung langsung ke ui.close tanpa re-entrancy guard")
	_safely_disconnect_close_recursion(dm, ui)

	# 2. Verifikasi ketiadaan active guard di dm.close_dialogue():
	# Jika dm tidak aktif (_is_dialogue_active = false), memanggil close_dialogue() tetap memancarkan dialogue_ended!
	var flags := {"emitted_when_inactive": false}
	dm.close_dialogue() # pastikan tidak aktif
	var check_listener = func(): flags["emitted_when_inactive"] = true
	dm.dialogue_ended.connect(check_listener)
	dm.close_dialogue() # panggil saat sudah tidak aktif
	dm.dialogue_ended.disconnect(check_listener)

	Assertions.assert_false(flags["emitted_when_inactive"], "DEFECT-SOC-01: dm.close_dialogue() memancarkan dialogue_ended saat dialog sudah tidak aktif (ketiadaan active guard)")

	_safely_disconnect_close_recursion(dm, ui)
	ui.queue_free()
	_cleanup_env(env)

	var has_defect: bool = is_connected_to_close or flags["emitted_when_inactive"]
	if has_defect:
		print("  [DEFECT CONFIRMED] ADV.SOC-20: DEFECT-SOC-01 terbukti nyata! Terjadi infinite recursion loop.")
		return false
	else:
		print("  [PASS] ADV.SOC-20: Tidak terjadi rekursi timbal balik.")
		return true
