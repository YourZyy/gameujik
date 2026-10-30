class_name TestInventory
extends RefCounted

## Test Suite INV-001: Data Item, Tas, Peti Rumah, Transaksi Atomik, Wadah Starter, dan UI
## Memverifikasi PRD FR05/FR06, CONTENT.md § 2/3/5, PROTOTYPE.md § 6.1, UI_UX.md UI04, dan TEST_PLAN T02/T03/T04/T29/T30/T31/T32/T33

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerScript = preload("res://scripts/inventory/inventory_manager.gd")
const InventoryUIScript = preload("res://scripts/ui/inventory_ui.gd")

func run_all() -> bool:
	var passed := true
	print("  Running TestInventory suite (T02, T03, T04, T29, T30, T31, T32, T33)...")
	var tree := Engine.get_main_loop() as SceneTree

	if not test_t02_backpack_slot_limit_and_stack_capacity():
		passed = false
	if not test_t03_two_way_atomic_transfer():
		passed = false
	if not test_t04_starter_crate_pickup():
		passed = false
	if not test_t29_single_container_add_remove_stack_merge():
		passed = false
	if not test_t30_rejection_when_target_full():
		passed = false
	if not test_t31_starter_crate_rejection_insufficient_slots():
		passed = false
	if not await test_t32_ui_instantiation_and_slots(tree):
		passed = false
	if not await test_t33_context_switching_integration(tree):
		passed = false

	return passed

## T02: Batas slot tas (12 slot tetap) dan kapasitas tumpukan (20 max stack)
func test_t02_backpack_slot_limit_and_stack_capacity() -> bool:
	print("    [RUN] T02: Backpack Slot Limit (12 Slots) & Stack Capacity (20 Max)")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# 1. Verifikasi batas 12 slot
	var slots: Array = inv.get_container_slots("backpack")
	Assertions.assert_equal(slots.size(), 12, "Backpack must have exactly 12 slots")

	# 2. Registri item P0 terdaftar dengan benar
	Assertions.assert_not_null(inv.get_item_data("seed_bayam"), "seed_bayam must be registered")
	Assertions.assert_not_null(inv.get_item_data("soil_compost"), "soil_compost must be registered")
	Assertions.assert_not_null(inv.get_item_data("fertilizer_basic"), "fertilizer_basic must be registered")
	Assertions.assert_not_null(inv.get_item_data("ingredient_bayam"), "ingredient_bayam must be registered")
	Assertions.assert_not_null(inv.get_item_data("ingredient_jagung"), "ingredient_jagung must be registered")
	Assertions.assert_not_null(inv.get_item_data("ingredient_temu_kunci"), "ingredient_temu_kunci must be registered")
	Assertions.assert_not_null(inv.get_item_data("dish_sayur_bening"), "dish_sayur_bening must be registered")
	Assertions.assert_not_null(inv.get_item_data("water_fresh"), "water_fresh must be registered")

	# 3. Alias kompatibilitas teresolusi ke ID kanonik
	Assertions.assert_equal(inv.resolve_id("crop_bayam"), "ingredient_bayam", "crop_bayam must resolve to ingredient_bayam")
	Assertions.assert_equal(inv.resolve_id("tool_fertilizer"), "fertilizer_basic", "tool_fertilizer must resolve to fertilizer_basic")

	# 4. Mengisi satu tumpukan hingga batas 20
	var ok_add: bool = inv.add_items("backpack", [{"item_id": "seed_bayam", "count": 20}])
	Assertions.assert_true(ok_add, "Adding 20 seeds to empty backpack must succeed")
	Assertions.assert_equal(inv.get_available_item_count("seed_bayam"), 20, "Should hold 20 seed_bayam")

	# 5. Unit ke-21 membuka slot baru (overflow)
	var ok_add21: bool = inv.add_items("backpack", [{"item_id": "seed_bayam", "count": 1}])
	Assertions.assert_true(ok_add21, "Adding 21st seed must succeed into next slot")
	Assertions.assert_equal(inv.get_available_item_count("seed_bayam"), 21, "Total seeds should now be 21 across 2 slots")
	var s0 = inv.backpack.get_slot(0)
	var s1 = inv.backpack.get_slot(1)
	Assertions.assert_equal(int(s0.count), 20, "Slot 0 should remain full with 20")
	Assertions.assert_equal(int(s1.count), 1, "Slot 1 should hold 1 overflow unit")

	# 6. Mengisi seluruh 12 slot tas hingga penuh (240 unit)
	inv.backpack.clear()
	for i in range(12):
		var item_id := "item_%02d" % i
		inv.add_items("backpack", [{"item_id": item_id, "count": 20}])

	Assertions.assert_true(inv.backpack.is_full(), "Backpack must be reported full when 12x20 items loaded")

	# 7. Mencoba menambahkan jenis item baru ke-13 ditolak
	var can_add_13th: bool = inv.can_accept_items("backpack", [{"item_id": "item_overflow", "count": 1}])
	Assertions.assert_false(can_add_13th, "Cannot add 13th distinct item when 12 slots are full")

	inv.free()
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T02: Backpack slot limit & stack capacity verified.")
	return ok

## T03: Transfer dua arah atomik antara tas dan peti
func test_t03_two_way_atomic_transfer() -> bool:
	print("    [RUN] T03: Two-Way Atomic Item Transfer Between Backpack and Chest")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# Masukkan 5 seed_bayam ke tas, peti kosong
	inv.add_items("backpack", [{"item_id": "seed_bayam", "count": 5}])
	Assertions.assert_equal(inv.get_available_item_count("seed_bayam"), 5, "Initial total seeds = 5")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 5, "Backpack has 5 seeds")
	Assertions.assert_equal(inv.storage_home.get_item_count("seed_bayam"), 0, "Chest has 0 seeds")

	# Transfer dari tas ke peti
	var res: bool = inv.transfer_item("backpack", "storage", 0, 5)
	Assertions.assert_true(res, "Transfer 5 seeds to chest must succeed")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 0, "Backpack has 0 seeds after transfer")
	Assertions.assert_equal(inv.storage_home.get_item_count("seed_bayam"), 5, "Chest has 5 seeds after transfer")
	Assertions.assert_equal(inv.get_available_item_count("seed_bayam"), 5, "Total free stock remains strictly 5")

	# Transfer sebagian (2 buah) kembali dari peti ke tas
	var res2: bool = inv.transfer_item("storage", "backpack", 0, 2)
	Assertions.assert_true(res2, "Transfer 2 seeds back to backpack must succeed")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 2, "Backpack has 2 seeds")
	Assertions.assert_equal(inv.storage_home.get_item_count("seed_bayam"), 3, "Chest has 3 seeds")
	Assertions.assert_equal(inv.get_available_item_count("seed_bayam"), 5, "Total seeds strictly conserved: zero duplication, zero loss")

	# Uji transfer_all atomik
	var res_all: Dictionary = inv.transfer_all("storage", "backpack")
	Assertions.assert_true(res_all.get("success", false), "transfer_all back to backpack must succeed")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 5, "Backpack now has all 5 seeds")
	Assertions.assert_equal(inv.storage_home.get_item_count("seed_bayam"), 0, "Chest is now empty")

	inv.free()
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T03: Two-way atomic transfer verified.")
	return ok

## T04: Pengambilan paket awal starter (4 seeds, 1 compost, 1 fertilizer)
func test_t04_starter_crate_pickup() -> bool:
	print("    [RUN] T04: Starter Crate Pickup, Slot Verification & Spam Protection")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	Assertions.assert_false(inv.is_starter_collected(), "Starter crate must initially not be collected")

	# Pengambilan pertama
	var ok_claim: bool = inv.pickup_starter_container()
	Assertions.assert_true(ok_claim, "First claim of starter crate must succeed")
	Assertions.assert_true(inv.is_starter_collected(), "Starter crate flag must now be collected")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "Must receive 4 seed_bayam")
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 1, "Must receive 1 soil_compost")
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 1, "Must receive 1 fertilizer_basic")

	# Pengambilan kedua (Spam E) ditolak tanpa duplikasi
	var spam_claim: bool = inv.pickup_starter_container()
	Assertions.assert_false(spam_claim, "Second claim must be rejected (one-time flag)")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "Seeds must not duplicate")
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 1, "Compost must not duplicate")
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 1, "Fertilizer must not duplicate")

	inv.free()
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T04: Starter crate pickup & spam protection verified.")
	return ok

## T29: Single container add/remove & stack merging
func test_t29_single_container_add_remove_stack_merge() -> bool:
	print("    [RUN] T29: Single Container Addition, Stack Merging and Removal")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# Tambah 15 air
	inv.add_items("backpack", [{"item_id": "water_fresh", "count": 15}])
	Assertions.assert_equal(inv.backpack.get_item_count("water_fresh"), 15, "Initial 15 water added")

	# Tambah 10 air -> tumpukan pertama penuh 20, tumpukan kedua 5
	inv.add_items("backpack", [{"item_id": "water_fresh", "count": 10}])
	Assertions.assert_equal(inv.backpack.get_item_count("water_fresh"), 25, "Total water is now 25 across 2 stacks")

	var s0 = inv.backpack.get_slot(0)
	var s1 = inv.backpack.get_slot(1)
	Assertions.assert_equal(int(s0.count), 20, "First stack has 20")
	Assertions.assert_equal(int(s1.count), 5, "Second stack has 5")

	# Hapus 7 air -> diambil dari s0 dahulu (sisa 13 di s0, 5 di s1)
	inv.remove_items("backpack", [{"item_id": "water_fresh", "count": 7}])
	Assertions.assert_equal(inv.backpack.get_item_count("water_fresh"), 18, "Remaining water should be 18")

	inv.free()
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T29: Single container add/remove/merge verified.")
	return ok

## T30: Penolakan transfer saat kontainer tujuan penuh
func test_t30_rejection_when_target_full() -> bool:
	print("    [RUN] T30: Transfer Rejection When Target Container Full (No Partial Transfer)")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# Penuhi 12 slot peti dengan 12 item berbeda
	for i in range(12):
		var it := "chest_item_%02d" % i
		inv.add_items("storage", [{"item_id": it, "count": 20}])

	Assertions.assert_true(inv.storage_home.is_full(), "Storage container must be completely full")

	# Masukkan 5 jagung ke tas
	inv.add_items("backpack", [{"item_id": "ingredient_jagung", "count": 5}])

	# Coba transfer jagung ke peti yang penuh
	var res: bool = inv.transfer_item("backpack", "storage", 0, 5)
	Assertions.assert_false(res, "Transfer to full storage container must be rejected")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 5, "Backpack must still have 5 jagung intact")

	# Coba transfer_slot juga harus ditolak
	var res_slot: Dictionary = inv.transfer_slot("backpack", "storage", 0)
	Assertions.assert_false(res_slot.get("success", false), "transfer_slot to full chest must return success: false")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 5, "Backpack jagung intact after transfer_slot rejection")

	inv.free()
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T30: Target full transfer rejection verified.")
	return ok

## T31: Penolakan starter crate jika tas kekurangan slot (< 3 slot kosong)
func test_t31_starter_crate_rejection_insufficient_slots() -> bool:
	print("    [RUN] T31: Starter Crate Rejection When Free Slots < 3")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = InventoryManagerScript.new()
	inv._ready()

	# Isi 10 slot tas dengan 10 item unik (hanya tersisa 2 slot kosong)
	for i in range(10):
		var it := "filler_%02d" % i
		inv.add_items("backpack", [{"item_id": it, "count": 1}])

	Assertions.assert_equal(inv.backpack.get_empty_slot_count(), 2, "Backpack has exactly 2 empty slots")

	# Ambil starter (memerlukan 3 slot terpisah)
	var claim_res: bool = inv.pickup_starter_container()
	Assertions.assert_false(claim_res, "Starter crate pickup must fail when only 2 free slots available")
	Assertions.assert_false(inv.is_starter_collected(), "Starter crate flag must remain false on failure")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 0, "Zero seeds given on failure")

	# Kosongkan 1 slot lagi sehingga tersisa 3 slot kosong
	inv.remove_items("backpack", [{"item_id": "filler_00", "count": 1}])
	Assertions.assert_equal(inv.backpack.get_empty_slot_count(), 3, "Backpack now has 3 empty slots")

	# Ambil sekarang -> harus berhasil 100%
	var claim_res2: bool = inv.pickup_starter_container()
	Assertions.assert_true(claim_res2, "Starter crate pickup succeeds when 3 slots are available")
	Assertions.assert_true(inv.is_starter_collected(), "Starter crate flag is now true")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "Seeds granted properly")
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 1, "Compost granted properly")
	Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 1, "Fertilizer granted properly")

	inv.free()
	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T31: Starter crate insufficient slots rejection verified.")
	return ok

## T32: Instansiasi UI, verifikasi jumlah slot, dan toggling visibilitas
func test_t32_ui_instantiation_and_slots(tree: SceneTree) -> bool:
	print("    [RUN] T32: UI Instantiation, 12+12 Slots Verification & Visibility Toggling")
	var initial_failures: int = Assertions.current_suite_failed

	var ui_scene = load("res://scenes/ui/inventory_ui.tscn")
	Assertions.assert_not_null(ui_scene, "inventory_ui.tscn scene file must exist")
	if ui_scene == null:
		return false

	var ui = ui_scene.instantiate() as CanvasLayer
	tree.root.add_child(ui)
	await tree.process_frame

	# Verifikasi 12 slot tas dan 12 slot peti
	Assertions.assert_equal(ui.backpack_slot_nodes.size(), 12, "Backpack grid must have 12 slot controls")
	Assertions.assert_equal(ui.storage_slot_nodes.size(), 12, "Storage grid must have 12 slot controls")

	# Uji Solo mode
	ui.open_solo()
	Assertions.assert_true(ui.visible, "UI is visible in solo mode")
	Assertions.assert_false(ui.storage_section.visible, "Storage section is hidden in solo mode")

	# Uji Dual mode
	ui.open_dual()
	Assertions.assert_true(ui.visible, "UI is visible in dual mode")
	Assertions.assert_true(ui.storage_section.visible, "Storage section is visible in dual mode")

	# Uji Tutup
	ui.close_ui()
	Assertions.assert_false(ui.visible, "UI is hidden after close_ui()")

	ui.queue_free()
	await tree.process_frame

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T32: UI instantiation and slot controls verified.")
	return ok

## T33: Integrasi peralihan konteks input dengan InputManager
func test_t33_context_switching_integration(tree: SceneTree) -> bool:
	print("    [RUN] T33: Context Switching Integration with InputManager")
	var initial_failures: int = Assertions.current_suite_failed

	var input_mgr = tree.root.get_node_or_null("InputManager")
	Assertions.assert_not_null(input_mgr, "InputManager autoload must be present")
	if input_mgr == null:
		return false

	var ui_scene = load("res://scenes/ui/inventory_ui.tscn")
	var ui = ui_scene.instantiate() as CanvasLayer
	tree.root.add_child(ui)
	await tree.process_frame

	# 1. Pastikan konteks awal adalah WORLD
	input_mgr.pop_to_world()
	Assertions.assert_equal(input_mgr.get_current_context(), input_mgr.ContextMode.WORLD, "Current context is WORLD")
	Assertions.assert_false(ui.visible, "UI hidden in WORLD")

	# 2. Push konteks STORAGE -> UI harus terbuka
	input_mgr.push_context(input_mgr.ContextMode.STORAGE)
	Assertions.assert_equal(input_mgr.get_current_context(), input_mgr.ContextMode.STORAGE, "Current context is STORAGE")
	Assertions.assert_true(input_mgr.is_simulation_paused(), "Simulation is paused in STORAGE context")

	# 3. Pop konteks -> kembali ke WORLD, UI tertutup, frame guard aktif
	input_mgr.pop_context()
	Assertions.assert_equal(input_mgr.get_current_context(), input_mgr.ContextMode.WORLD, "Returned to WORLD context")
	Assertions.assert_false(input_mgr.is_simulation_paused(), "Simulation unpaused in WORLD")
	Assertions.assert_false(input_mgr.can_interact_in_world(), "Bleed-through guard active on pop frame")

	await tree.process_frame
	Assertions.assert_true(input_mgr.can_interact_in_world(), "Interaction allowed on subsequent frame")

	ui.queue_free()
	await tree.process_frame

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T33: Context switching integration verified.")
	return ok
