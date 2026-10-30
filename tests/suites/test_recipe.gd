class_name TestRecipe
extends RefCounted

## Test Suite BOOK-001: Model Data Resep, RecipeManager, Unified Free Stock, Book UI, HUD Tracker, dan Persistence
## Memverifikasi PRD FR03/FR04, CONTENT.md § 4/5/10/12, UI_UX.md UI01/UI02, dan TEST_PLAN T01, T02, T03, T11, T31, T45, T46

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")
const RecipeDataClass = preload("res://scripts/recipe/recipe_data.gd")
const RecipeManagerClass = preload("res://scripts/recipe/recipe_manager.gd")

var BookUIClass: Variant = null
var HUDClass: Variant = null

func _init() -> void:
	if ResourceLoader.exists("res://scripts/ui/book_ui.gd"):
		BookUIClass = load("res://scripts/ui/book_ui.gd")
	if ResourceLoader.exists("res://scripts/ui/hud.gd"):
		HUDClass = load("res://scripts/ui/hud.gd")

func run_all() -> bool:
	var passed := true
	print("  Running TestRecipe suite (T01, T02, T03, T11, T31, Notes, Save, Context Guard)...")
	var tree := Engine.get_main_loop() as SceneTree

	if not test_rec01_recipe_data_model_and_catalog():
		passed = false
	if not await test_t01_new_game_tracking_and_hud(tree):
		passed = false
	if not await test_t02_pre_acquired_items_immediately_counted(tree):
		passed = false
	if not await test_t03_track_untrack_reopen_state_invariance(tree):
		passed = false
	if not test_t11_unified_free_stock_query_and_transfer_invariance():
		passed = false
	if not test_t31_complete_ingredients_ready_not_finished():
		passed = false
	if not test_extra_notes_registry_and_unlock():
		passed = false
	if not test_extra_save_snapshot_roundtrip():
		passed = false
	if not await test_extra_input_context_switching_and_frame_guard(tree):
		passed = false
	if not await test_extra_ui_instantiation_and_responsive_hierarchy(tree):
		passed = false
	if not await test_extra_world_landmarks_interaction(tree):
		passed = false
	if not await test_regression_defect_book_01_hotkey_b_bounce(tree):
		passed = false

	return passed

# --- Helper Factory Methods ---

func _create_clean_inventory() -> Node:
	var inv: Node = InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.storage_home.clear()
	inv.kitchen_refund.clear()
	inv.starter_claimed = false
	return inv

func _create_clean_recipe_manager(inv: Node) -> Node:
	if RecipeManagerClass != null:
		var rm: Node = RecipeManagerClass.new()
		if rm.has_method("set_inventory_manager"):
			rm.set_inventory_manager(inv)
		rm._ready()
		return rm
	return null

# --- Test Cases ---

## REC-01: Recipe Data Model & Default Registration Baseline
func test_rec01_recipe_data_model_and_catalog() -> bool:
	print("    [RUN] REC-01: Recipe Data Model & Catalog Registration Baseline")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var rm: Node = _create_clean_recipe_manager(inv)

	if rm == null:
		print("      [SKIP] RecipeManager not available")
		inv.free()
		return true

	# 1. Verifikasi resep default P0 terdaftar
	Assertions.assert_true(rm.has_recipe("recipe_sayur_bening_01"), "recipe_sayur_bening_01 must be registered in catalog")
	var recipe = rm.get_recipe("recipe_sayur_bening_01")
	Assertions.assert_not_null(recipe, "recipe_sayur_bening_01 must exist")

	# 2. Verifikasi metadata resep sesuai CONTENT.md § 4
	Assertions.assert_equal(recipe.get("id"), "recipe_sayur_bening_01", "Recipe ID matches")
	Assertions.assert_equal(recipe.get("display_name"), "Sayur Bening Bayam dan Jagung", "Display name matches")
	Assertions.assert_equal(recipe.get("station"), "station_kitchen_home", "Station matches station_kitchen_home")
	Assertions.assert_equal(recipe.get("output_dish_id"), "dish_sayur_bening", "Output item ID matches dish_sayur_bening")
	Assertions.assert_equal(int(recipe.get("output_count")), 1, "Output count matches 1")
	Assertions.assert_approx_equal(float(recipe.get("prep_duration")), 4.0, 0.01, "Prep duration matches 4.0s")
	Assertions.assert_approx_equal(float(recipe.get("cook_duration")), 30.0, 0.01, "Cook duration matches 30.0s")

	# 3. Verifikasi daftar bahan & jumlah
	var ingredients: Dictionary = recipe.get("ingredients")
	Assertions.assert_equal(int(ingredients.get("ingredient_bayam", 0)), 3, "Requires 3 bayam")
	Assertions.assert_equal(int(ingredients.get("ingredient_jagung", 0)), 1, "Requires 1 jagung")
	Assertions.assert_equal(int(ingredients.get("ingredient_temu_kunci", 0)), 1, "Requires 1 temu kunci")

	# 4. Verifikasi petunjuk sumber bahan
	var hints: Dictionary = recipe.get("source_hints")
	Assertions.assert_true(hints.has("ingredient_bayam"), "Bayam has source hint")
	Assertions.assert_true(hints.has("ingredient_jagung"), "Jagung has source hint")
	Assertions.assert_true(hints.has("ingredient_temu_kunci"), "Temu kunci has source hint")

	# 5. Status awal
	Assertions.assert_equal(int(recipe.get("times_cooked")), 0, "Initial times_cooked is 0")
	Assertions.assert_false(recipe.get("is_completed"), "Initial is_completed is false")

	rm.free()
	inv.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] REC-01: Recipe Data Model & Catalog verified.")
	return ok

## T01: New game state -> open book -> click Lacak -> HUD displays recipe title and 3 ingredient requirements without completed checkmark
func test_t01_new_game_tracking_and_hud(tree: SceneTree) -> bool:
	print("    [RUN] T01: New Game State Tracking Activation & HUD Tracker Display")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var rm: Node = _create_clean_recipe_manager(inv)

	if rm == null:
		print("      [SKIP] RecipeManager not available")
		inv.free()
		return true

	# 1. State awal game baru: belum ada yang dilacak
	Assertions.assert_equal(rm.tracked_recipe_id, "", "Initially no recipe is tracked")
	Assertions.assert_null(rm.get_tracked_recipe(), "get_tracked_recipe() is null initially")
	Assertions.assert_false(rm.is_recipe_tracked("recipe_sayur_bening_01"), "recipe_sayur_bening_01 is not tracked initially")

	# 2. Buka buku dan tekan Lacak
	var signal_emitted := [false]
	rm.recipe_tracked.connect(func(r_id): if r_id == "recipe_sayur_bening_01": signal_emitted[0] = true)

	var ok_track: bool = rm.track_recipe("recipe_sayur_bening_01")
	Assertions.assert_true(ok_track, "track_recipe must return true")
	Assertions.assert_true(signal_emitted[0], "recipe_tracked signal must be emitted")
	Assertions.assert_equal(rm.tracked_recipe_id, "recipe_sayur_bening_01", "tracked_recipe_id updated")
	Assertions.assert_true(rm.is_recipe_tracked("recipe_sayur_bening_01"), "is_recipe_tracked returns true")

	# 3. Status resep belum selesai & belum siap masak
	Assertions.assert_false(rm.is_recipe_completed("recipe_sayur_bening_01"), "Recipe must not be marked completed (no checkmark)")
	Assertions.assert_false(rm.can_cook_recipe("recipe_sayur_bening_01"), "Recipe cannot be cooked with 0 ingredients")

	# 4. Verifikasi status setiap bahan pada tracker: 0/3, 0/1, 0/1
	var recipe = rm.get_recipe("recipe_sayur_bening_01")
	if recipe.has_method("get_ingredient_status"):
		var stat_bayam: Dictionary = recipe.get_ingredient_status("ingredient_bayam", inv)
		Assertions.assert_equal(int(stat_bayam.get("available")), 0, "Bayam available = 0")
		Assertions.assert_equal(int(stat_bayam.get("required")), 3, "Bayam required = 3")
		Assertions.assert_false(bool(stat_bayam.get("satisfied")), "Bayam not satisfied")

		var stat_jagung: Dictionary = recipe.get_ingredient_status("ingredient_jagung", inv)
		Assertions.assert_equal(int(stat_jagung.get("available")), 0, "Jagung available = 0")
		Assertions.assert_equal(int(stat_jagung.get("required")), 1, "Jagung required = 1")
		Assertions.assert_false(bool(stat_jagung.get("satisfied")), "Jagung not satisfied")

		var stat_kunci: Dictionary = recipe.get_ingredient_status("ingredient_temu_kunci", inv)
		Assertions.assert_equal(int(stat_kunci.get("available")), 0, "Temu kunci available = 0")
		Assertions.assert_equal(int(stat_kunci.get("required")), 1, "Temu kunci required = 1")
		Assertions.assert_false(bool(stat_kunci.get("satisfied")), "Temu kunci not satisfied")

	# 5. Verifikasi integrasi HUD UI jika scene HUD tersedia
	if ResourceLoader.exists("res://scenes/ui/hud.tscn"):
		var hud_scene = load("res://scenes/ui/hud.tscn")
		var hud = hud_scene.instantiate()
		tree.root.add_child(hud)
		await tree.process_frame

		if hud.has_method("set_recipe_manager"):
			hud.set_recipe_manager(rm)
		if hud.has_method("refresh_tracker"):
			hud.refresh_tracker()

		var title_label = hud.find_child("RecipeTitleLabel", true, false)
		if title_label is Label:
			Assertions.assert_equal(title_label.text, "Sayur Bening Bayam dan Jagung", "HUD displays tracked recipe title")

		hud.queue_free()
		await tree.process_frame

	rm.free()
	inv.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T01: New Game State Tracking Activation & HUD verified.")
	return ok

## T02: Acquire item before tracking -> activate tracking -> acquired item is immediately counted in recipe tracker
func test_t02_pre_acquired_items_immediately_counted(tree: SceneTree) -> bool:
	print("    [RUN] T02: Pre-Acquisition Item Counting on Track Activation")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var rm: Node = _create_clean_recipe_manager(inv)

	if rm == null:
		print("      [SKIP] RecipeManager not available")
		inv.free()
		return true

	# 1. Belum melacak resep
	Assertions.assert_equal(rm.tracked_recipe_id, "", "Untracked initially")

	# 2. Pemain memperoleh 1 jagung di tas dan 1 bayam di peti SEBELUM melacak
	inv.add_items("backpack", [{"item_id": "ingredient_jagung", "count": 1}])
	inv.add_items("storage", [{"item_id": "ingredient_bayam", "count": 1}])

	Assertions.assert_equal(inv.get_available_item_count("ingredient_jagung"), 1, "Possess 1 jagung")
	Assertions.assert_equal(inv.get_available_item_count("ingredient_bayam"), 1, "Possess 1 bayam")

	# 3. Sekarang aktifkan pelacakan resep
	rm.track_recipe("recipe_sayur_bening_01")
	Assertions.assert_equal(rm.tracked_recipe_id, "recipe_sayur_bening_01", "Now tracking recipe")

	# 4. Jagung dan bayam yang sudah dimiliki LANGSUNG terhitung tanpa harus memetik ulang
	var recipe = rm.get_recipe("recipe_sayur_bening_01")
	if recipe.has_method("get_ingredient_status"):
		var stat_jagung: Dictionary = recipe.get_ingredient_status("ingredient_jagung", inv)
		Assertions.assert_equal(int(stat_jagung.get("available")), 1, "Jagung immediately counted as 1")
		Assertions.assert_true(bool(stat_jagung.get("satisfied")), "Jagung is satisfied (1/1)")

		var stat_bayam: Dictionary = recipe.get_ingredient_status("ingredient_bayam", inv)
		Assertions.assert_equal(int(stat_bayam.get("available")), 1, "Bayam immediately counted as 1")
		Assertions.assert_false(bool(stat_bayam.get("satisfied")), "Bayam is not yet fully satisfied (1/3)")

	Assertions.assert_false(rm.can_cook_recipe("recipe_sayur_bening_01"), "Recipe cannot cook until all ingredients met")

	rm.free()
	inv.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T02: Pre-Acquisition item counting verified.")
	return ok

## T03: Track recipe -> untrack recipe -> re-open book -> items and progress remain intact, only tracking state changes
func test_t03_track_untrack_reopen_state_invariance(tree: SceneTree) -> bool:
	print("    [RUN] T03: Track/Untrack State Invariance & Re-opening Book")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var rm: Node = _create_clean_recipe_manager(inv)

	if rm == null:
		print("      [SKIP] RecipeManager not available")
		inv.free()
		return true

	# 1. Miliki item parsial (1 jagung, 1 bayam) dan lacak
	inv.add_items("backpack", [{"item_id": "ingredient_jagung", "count": 1}])
	inv.add_items("backpack", [{"item_id": "ingredient_bayam", "count": 1}])
	rm.track_recipe("recipe_sayur_bening_01")

	Assertions.assert_true(rm.is_recipe_tracked("recipe_sayur_bening_01"), "Recipe is tracked")
	Assertions.assert_equal(rm.tracked_recipe_id, "recipe_sayur_bening_01", "tracked_recipe_id is active")

	# 2. Berhenti melacak (untrack)
	var signal_untracked := [false]
	rm.recipe_untracked.connect(func(r_id): signal_untracked[0] = true)

	var ok_untrack: bool = rm.untrack_recipe("recipe_sayur_bening_01")
	Assertions.assert_true(ok_untrack, "untrack_recipe returns true")
	Assertions.assert_true(signal_untracked[0], "recipe_untracked signal emitted")
	Assertions.assert_equal(rm.tracked_recipe_id, "", "tracked_recipe_id cleared to empty")
	Assertions.assert_false(rm.is_recipe_tracked("recipe_sayur_bening_01"), "is_recipe_tracked returns false")

	# 3. Verifikasi invarian item: tidak ada item berkurang atau bertambah
	Assertions.assert_equal(inv.get_available_item_count("ingredient_jagung"), 1, "Jagung count strictly 1")
	Assertions.assert_equal(inv.get_available_item_count("ingredient_bayam"), 1, "Bayam count strictly 1")
	Assertions.assert_equal(inv.get_available_item_count("ingredient_temu_kunci"), 0, "Temu kunci strictly 0")

	# 4. Buka kembali buku & periksa progres resep tetap terjaga
	var recipe = rm.get_recipe("recipe_sayur_bening_01")
	Assertions.assert_equal(int(recipe.get("times_cooked")), 0, "times_cooked remains 0")
	Assertions.assert_false(recipe.get("is_completed"), "is_completed remains false")

	# 5. Aktifkan kembali pelacakan -> langsung pulih ke state semula
	rm.track_recipe("recipe_sayur_bening_01")
	Assertions.assert_equal(rm.tracked_recipe_id, "recipe_sayur_bening_01", "Re-tracking restores tracked_recipe_id")

	rm.free()
	inv.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T03: Track/Untrack state invariance verified.")
	return ok

## T11: Items split across backpack and storage chest -> book and kitchen query identical available stock count; moving items between backpack and storage chest does not change total stock
func test_t11_unified_free_stock_query_and_transfer_invariance() -> bool:
	print("    [RUN] T11: Unified Free Stock Query & Container Transfer Invariance")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var rm: Node = _create_clean_recipe_manager(inv)

	if rm == null:
		print("      [SKIP] RecipeManager not available")
		inv.free()
		return true

	# 1. Sebarkan bahan antara tas dan peti rumah:
	inv.add_items("backpack", [
		{"item_id": "ingredient_bayam", "count": 2},
		{"item_id": "ingredient_temu_kunci", "count": 1}
	])
	inv.add_items("storage", [
		{"item_id": "ingredient_bayam", "count": 1},
		{"item_id": "ingredient_jagung", "count": 1}
	])

	# 2. Query agregat via InventoryManager
	Assertions.assert_equal(inv.get_available_item_count("ingredient_bayam"), 3, "Inventory total bayam = 3")
	Assertions.assert_equal(inv.get_available_item_count("ingredient_jagung"), 1, "Inventory total jagung = 1")
	Assertions.assert_equal(inv.get_available_item_count("ingredient_temu_kunci"), 1, "Inventory total temu kunci = 1")

	# 3. Query agregat via RecipeManager
	if rm.has_method("get_available_ingredient_count"):
		Assertions.assert_equal(rm.get_available_ingredient_count("ingredient_bayam"), 3, "RecipeManager bayam = 3")
		Assertions.assert_equal(rm.get_available_ingredient_count("ingredient_jagung"), 1, "RecipeManager jagung = 1")
		Assertions.assert_equal(rm.get_available_ingredient_count("ingredient_temu_kunci"), 1, "RecipeManager temu kunci = 1")

	Assertions.assert_true(rm.can_cook_recipe("recipe_sayur_bening_01"), "Recipe is ready to cook with 3 bayam, 1 corn, 1 temu kunci")

	# 4. Transfer dinamis: Pindahkan 1 bayam dari tas ke peti
	var ok_tr1: bool = inv.transfer_item("backpack", "storage", 0, 1)
	Assertions.assert_true(ok_tr1, "Transfer bayam to storage succeeds")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 1, "Backpack now has 1 bayam")
	Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_bayam"), 2, "Storage now has 2 bayam")

	if rm.has_method("get_available_ingredient_count"):
		Assertions.assert_equal(rm.get_available_ingredient_count("ingredient_bayam"), 3, "Available bayam strictly conserved at 3")
	Assertions.assert_true(rm.can_cook_recipe("recipe_sayur_bening_01"), "Recipe remains cookable after transfer")

	# 5. Pindahkan jagung dari peti ke tas
	var ok_tr2: bool = inv.transfer_item("storage", "backpack", 1, 1)
	Assertions.assert_true(ok_tr2, "Transfer jagung to backpack succeeds")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 1, "Backpack now has 1 jagung")
	Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_jagung"), 0, "Storage now has 0 jagung")

	if rm.has_method("get_available_ingredient_count"):
		Assertions.assert_equal(rm.get_available_ingredient_count("ingredient_jagung"), 1, "Available jagung strictly conserved at 1")

	# 6. Efek reservasi dapur: reservasi 1 jagung untuk memasak (menggunakan typed Array[Dictionary])
	var res_batch: Array[Dictionary] = [{"item_id": "ingredient_jagung", "count": 1}]
	inv.reserve_ingredients("job_p0_cooking", res_batch)
	Assertions.assert_equal(inv.get_available_item_count("ingredient_jagung"), 0, "Reserved corn excluded from free stock")
	if rm.has_method("get_available_ingredient_count"):
		Assertions.assert_equal(rm.get_available_ingredient_count("ingredient_jagung"), 0, "RecipeManager reflects reservation")
	Assertions.assert_false(rm.can_cook_recipe("recipe_sayur_bening_01"), "Recipe cannot cook while ingredient is reserved")

	# Batalkan reservasi -> stok bebas pulih
	inv.cancel_reservation("job_p0_cooking")
	Assertions.assert_equal(inv.get_available_item_count("ingredient_jagung"), 1, "Free stock restored after reservation cancel")
	Assertions.assert_true(rm.can_cook_recipe("recipe_sayur_bening_01"), "Recipe cookable again")

	rm.free()
	inv.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T11: Unified free stock & transfer invariance verified.")
	return ok

## T31: Gather all required ingredients without cooking -> status displays "Siap dimasak" (NOT "Selesai"); transfers between backpack and chest preserve "Siap dimasak" status
func test_t31_complete_ingredients_ready_not_finished() -> bool:
	print("    [RUN] T31: Gather Complete Ingredients — 'Siap dimasak' vs 'Selesai'")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var rm: Node = _create_clean_recipe_manager(inv)

	if rm == null:
		print("      [SKIP] RecipeManager not available")
		inv.free()
		return true

	# 1. Kumpulkan seluruh bahan lengkap (3 bayam, 1 jagung, 1 temu kunci)
	inv.add_items("backpack", [
		{"item_id": "ingredient_bayam", "count": 3},
		{"item_id": "ingredient_jagung", "count": 1},
		{"item_id": "ingredient_temu_kunci", "count": 1}
	])

	# 2. Resep harus siap dimasak, namun BELUM selesai
	Assertions.assert_true(rm.can_cook_recipe("recipe_sayur_bening_01"), "can_cook_recipe is true")
	Assertions.assert_false(rm.is_recipe_completed("recipe_sayur_bening_01"), "is_recipe_completed must strictly be false (NOT Selesai)")
	var recipe = rm.get_recipe("recipe_sayur_bening_01")
	Assertions.assert_equal(int(recipe.get("times_cooked")), 0, "times_cooked must be 0")

	# 3. Pindahkan bahan bolak-balik antara tas dan peti
	inv.transfer_all("backpack", "storage")
	Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_bayam"), 3, "Storage holds 3 bayam")
	Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_jagung"), 1, "Storage holds 1 jagung")
	Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_temu_kunci"), 1, "Storage holds 1 temu kunci")

	Assertions.assert_true(rm.can_cook_recipe("recipe_sayur_bening_01"), "Still ready to cook after transfer to storage")
	Assertions.assert_false(rm.is_recipe_completed("recipe_sayur_bening_01"), "Still not completed")

	# 4. Transisi ke 'Selesai' HANYA terjadi saat masakan selesai dimasak
	var signal_completed := [false]
	rm.recipe_completed.connect(func(r_id): signal_completed[0] = true)

	if rm.has_method("record_recipe_cooked"):
		rm.record_recipe_cooked("recipe_sayur_bening_01")
		Assertions.assert_true(signal_completed[0], "recipe_completed signal emitted")
		Assertions.assert_true(rm.is_recipe_completed("recipe_sayur_bening_01"), "is_recipe_completed is now true")
		Assertions.assert_equal(int(recipe.get("times_cooked")), 1, "times_cooked is now 1")

		rm.record_recipe_cooked("recipe_sayur_bening_01")
		Assertions.assert_true(rm.is_recipe_completed("recipe_sayur_bening_01"), "is_recipe_completed remains true")
		Assertions.assert_equal(int(recipe.get("times_cooked")), 2, "times_cooked is now 2")

	rm.free()
	inv.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] T31: 'Siap dimasak' vs 'Selesai' distinction verified.")
	return ok

## Extra: Notes registry (unlock note_garden_01 and inherent notes)
func test_extra_notes_registry_and_unlock() -> bool:
	print("    [RUN] NOTE-01: Notes Registry, Unlocking & Idempotency")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var rm: Node = _create_clean_recipe_manager(inv)

	if rm == null:
		print("      [SKIP] RecipeManager not available")
		inv.free()
		return true

	# 1. Catatan keluarga bawaan resep harus terbuka sejak awal
	Assertions.assert_true(rm.is_note_unlocked("recipe_note_sayur_bening"), "Family recipe note unlocked by default")

	# 2. Catatan kebun note_garden_01 terkunci diawal
	Assertions.assert_false(rm.is_note_unlocked("note_garden_01"), "note_garden_01 is locked initially")

	# 3. Interaksi / buka catatan kebun
	var signal_received := [false, ""]
	rm.note_unlocked.connect(func(n_id, text):
		signal_received[0] = true
		signal_received[1] = text
	)

	var ok_unlock: bool = rm.unlock_note("note_garden_01")
	Assertions.assert_true(ok_unlock, "unlock_note returns true on first unlock")
	Assertions.assert_true(signal_received[0], "note_unlocked signal emitted")
	Assertions.assert_true(rm.is_note_unlocked("note_garden_01"), "note_garden_01 is now unlocked")

	# 4. Verifikasi teks catatan sesuai CONTENT.md § 10
	var note_data: Dictionary = rm.get_note("note_garden_01")
	Assertions.assert_equal(note_data.get("text"), "Pagar boleh miring. Jangan sampai lupa jalan pulang.", "Garden note text matches CONTENT.md")

	# 5. Idempotensi: buka ulang tidak menduplikasi catatan
	var ok_unlock2: bool = rm.unlock_note("note_garden_01")
	Assertions.assert_false(ok_unlock2, "Unlocking already unlocked note returns false")

	var unlocked_notes: Array = rm.get_unlocked_notes()
	var count_garden := 0
	for n in unlocked_notes:
		if n.get("id") == "note_garden_01":
			count_garden += 1
	Assertions.assert_equal(count_garden, 1, "note_garden_01 present exactly once in unlocked notes")

	rm.free()
	inv.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] NOTE-01: Notes registry & unlock verified.")
	return ok

## Extra: Save snapshot round-trip persistence
func test_extra_save_snapshot_roundtrip() -> bool:
	print("    [RUN] SAVE-01: Save Snapshot Round-Trip Persistence (SAVE-001 Contract)")
	var initial_failures: int = Assertions.current_suite_failed

	var inv: Node = _create_clean_inventory()
	var rm: Node = _create_clean_recipe_manager(inv)

	if rm == null:
		print("      [SKIP] RecipeManager not available")
		inv.free()
		return true

	# 1. Buat state dinamis: Lacak resep, masak 2 kali, buka catatan kebun
	rm.track_recipe("recipe_sayur_bening_01")
	rm.record_recipe_cooked("recipe_sayur_bening_01")
	rm.record_recipe_cooked("recipe_sayur_bening_01")
	rm.unlock_note("note_garden_01")

	# 2. Ambil snapshot
	var snapshot: Dictionary = rm.get_save_snapshot()
	Assertions.assert_true(snapshot.has("version"), "Snapshot contains version")
	Assertions.assert_equal(snapshot.get("tracked_recipe_id"), "recipe_sayur_bening_01", "Snapshot tracked_recipe_id matches")
	Assertions.assert_true(snapshot.has("recipes"), "Snapshot contains recipes dictionary")
	Assertions.assert_true(snapshot.has("unlocked_notes"), "Snapshot contains unlocked_notes array")

	# 3. Buat instance RecipeManager baru (atau reset state)
	var rm2: Node = _create_clean_recipe_manager(inv)
	Assertions.assert_equal(rm2.tracked_recipe_id, "", "Clean instance has empty tracked_recipe_id")
	Assertions.assert_false(rm2.is_note_unlocked("note_garden_01"), "Clean instance note_garden_01 is locked")

	# 4. Muat snapshot ke instance baru
	var ok_load: bool = rm2.load_save_snapshot(snapshot)
	Assertions.assert_true(ok_load, "load_save_snapshot returns true")

	# 5. Verifikasi seluruh state pulih persis
	Assertions.assert_equal(rm2.tracked_recipe_id, "recipe_sayur_bening_01", "Restored tracked_recipe_id matches")
	Assertions.assert_true(rm2.is_recipe_tracked("recipe_sayur_bening_01"), "Restored is_recipe_tracked is true")
	Assertions.assert_true(rm2.is_recipe_completed("recipe_sayur_bening_01"), "Restored is_recipe_completed is true")
	var r2 = rm2.get_recipe("recipe_sayur_bening_01")
	Assertions.assert_equal(int(r2.get("times_cooked")), 2, "Restored times_cooked matches 2")
	Assertions.assert_true(rm2.is_note_unlocked("note_garden_01"), "Restored note_garden_01 is unlocked")

	# 6. Negative / Corrupted testing
	Assertions.assert_false(rm2.load_save_snapshot({}), "Empty dictionary load handled safely")

	rm.free()
	rm2.free()
	inv.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] SAVE-01: Save snapshot round-trip verified.")
	return ok

## Extra: Input Context Switching, Player Gating & Bleed-Through Frame Guard
func test_extra_input_context_switching_and_frame_guard(tree: SceneTree) -> bool:
	print("    [RUN] CTX-01: BookUI Context Switching & Bleed-Through Frame Guard")
	var initial_failures: int = Assertions.current_suite_failed

	var im = tree.root.get_node_or_null("InputManager")
	var is_local := false
	if im == null:
		im = InputManagerClass.new()
		is_local = true

	var player = PlayerControllerClass.new()
	im.register_player(player)

	# 1. State awal di WORLD
	im.pop_to_world()
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Initial context is WORLD")
	Assertions.assert_true(im.is_world_context(), "is_world_context is true")
	Assertions.assert_false(im.is_simulation_paused(), "Simulation unpaused in WORLD")
	Assertions.assert_true(player.movement_enabled, "Player movement enabled in WORLD")
	Assertions.assert_true(player.look_enabled, "Player look enabled in WORLD")

	# 2. Buka Buku Resep -> Push ContextMode.BOOK
	im.push_context(InputManagerClass.ContextMode.BOOK)
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.BOOK, "Current context is BOOK")
	Assertions.assert_false(im.is_world_context(), "is_world_context is false in BOOK")
	Assertions.assert_true(im.is_simulation_paused(), "Simulation is paused in BOOK")
	Assertions.assert_false(player.movement_enabled, "Player movement disabled in BOOK")
	Assertions.assert_false(player.look_enabled, "Player look disabled in BOOK")

	# 3. Tutup Buku Resep -> Pop context & Frame Guard
	im.pop_context()
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Restored to WORLD")
	Assertions.assert_false(im.is_simulation_paused(), "Simulation unpaused in WORLD")
	Assertions.assert_true(player.movement_enabled, "Player movement re-enabled")
	Assertions.assert_true(player.look_enabled, "Player look re-enabled")

	# Verifikasi Frame Guard: can_interact_in_world() harus FALSE pada frame pop yang sama
	Assertions.assert_false(im.can_interact_in_world(), "Action bleed-through guard active on pop frame")

	# Maju 1 frame -> interaksi dunia diizinkan kembali
	await tree.process_frame
	Assertions.assert_true(im.can_interact_in_world(), "Interaction in world allowed on next frame")

	im.register_player(null)
	player.free()
	if is_local:
		im.free()

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] CTX-01: BookUI context switching & frame guard verified.")
	return ok

## Extra: UI Instantiation & Responsive Hierarchy (BookUI & HUD)
func test_extra_ui_instantiation_and_responsive_hierarchy(tree: SceneTree) -> bool:
	print("    [RUN] UI-01: BookUI & HUD Scene Instantiation & Hierarchy")
	var initial_failures: int = Assertions.current_suite_failed

	# 1. Periksa BookUI scene jika sudah dibuat
	if ResourceLoader.exists("res://scenes/ui/book_ui.tscn"):
		var book_scene = load("res://scenes/ui/book_ui.tscn")
		var book_ui = book_scene.instantiate() as CanvasLayer
		tree.root.add_child(book_ui)
		await tree.process_frame

		# Pastikan control nodes utama ada
		Assertions.assert_not_null(book_ui.find_child("MainPanel", true, false), "BookUI has MainPanel")
		Assertions.assert_not_null(book_ui.find_child("TitleLabel", true, false), "BookUI has TitleLabel")
		Assertions.assert_not_null(book_ui.find_child("TrackButton", true, false), "BookUI has TrackButton")
		Assertions.assert_not_null(book_ui.find_child("CloseButton", true, false), "BookUI has CloseButton")

		book_ui.queue_free()
		await tree.process_frame
	else:
		print("      [NOTE] scenes/ui/book_ui.tscn not yet present")

	# 2. Periksa HUD scene jika sudah dibuat
	if ResourceLoader.exists("res://scenes/ui/hud.tscn"):
		var hud_scene = load("res://scenes/ui/hud.tscn")
		var hud = hud_scene.instantiate() as CanvasLayer
		tree.root.add_child(hud)
		await tree.process_frame

		Assertions.assert_not_null(hud.find_child("QuestTrackerContainer", true, false), "HUD has QuestTrackerContainer")

		hud.queue_free()
		await tree.process_frame
	else:
		print("      [NOTE] scenes/ui/hud.tscn not yet present")

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] UI-01: UI instantiation & hierarchy verified.")
	return ok

## Extra: World Landmark Wiring (book_family on table and note_garden_01 in garden)
func test_extra_world_landmarks_interaction(tree: SceneTree) -> bool:
	print("    [RUN] LM-01: World Landmark Wiring (book_family and note_garden_01)")
	var initial_failures: int = Assertions.current_suite_failed

	var main_scene = load("res://scenes/main.tscn") as PackedScene
	Assertions.assert_not_null(main_scene, "main.tscn must load")
	var main_node = main_scene.instantiate()
	tree.root.add_child(main_node)
	await tree.process_frame

	var im = tree.root.get_node_or_null("InputManager")
	var rm = tree.root.get_node_or_null("RecipeManager")
	var level = main_node.find_child("LevelGraybox", true, false)
	var book_ui = main_node.find_child("BookUI", true, false)
	var player = main_node.find_child("Player", true, false)

	# 1. Test book_family landmark interaction
	var book_landmark = level.find_child("book_family", true, false)
	Assertions.assert_not_null(book_landmark, "book_family landmark exists")
	var book_interactable = book_landmark.find_child("Interactable", true, false)
	Assertions.assert_not_null(book_interactable, "book_family has Interactable")

	# Interact with book on table
	book_interactable.interact(player)
	await tree.process_frame

	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.BOOK, "Interacting with table book pushes BOOK context")
	Assertions.assert_true(book_ui.visible, "BookUI is visible when opened via table")

	# Close book
	book_ui.close_book()
	await tree.process_frame
	Assertions.assert_false(book_ui.visible, "BookUI is closed")
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Context restored to WORLD")

	# 2. Test note_garden_01 landmark interaction
	var note_landmark = level.find_child("note_garden_01", true, false)
	Assertions.assert_not_null(note_landmark, "note_garden_01 landmark exists")
	var note_interactable = note_landmark.find_child("Interactable", true, false)
	Assertions.assert_not_null(note_interactable, "note_garden_01 has Interactable")

	# Interact with note in garden
	note_interactable.interact(player)
	await tree.process_frame

	Assertions.assert_true(rm.is_note_unlocked("note_garden_01"), "Interacting with garden note unlocks it in RecipeManager")

	main_node.queue_free()
	await tree.process_frame

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] LM-01: World Landmark Wiring verified.")
	return ok

## Regression: DEFECT-BOOK-01 Hotkey B Bounce / Double-Toggle in Full Main Scene
func test_regression_defect_book_01_hotkey_b_bounce(tree: SceneTree) -> bool:
	print("    [RUN] REG-BOOK-01: Hotkey B Open/Close in Full Main Scene (DEFECT-BOOK-01 Guard)")
	var initial_failures: int = Assertions.current_suite_failed

	var main_scene = load("res://scenes/main.tscn") as PackedScene
	Assertions.assert_not_null(main_scene, "main.tscn must load successfully")
	if main_scene == null:
		return false

	var main_node = main_scene.instantiate()
	tree.root.add_child(main_node)
	await tree.process_frame

	var im = tree.root.get_node_or_null("InputManager")
	Assertions.assert_not_null(im, "InputManager singleton must exist in root")
	var book_ui = main_node.find_child("BookUI", true, false)
	Assertions.assert_not_null(book_ui, "BookUI must exist in Main scene")

	if im == null or book_ui == null:
		main_node.queue_free()
		await tree.process_frame
		return false

	# 1. State awal harus WORLD dan BookUI tidak terlihat
	im.pop_to_world()
	book_ui.visible = false
	await tree.process_frame

	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Initial context is WORLD")
	Assertions.assert_false(book_ui.visible, "BookUI initially hidden")

	# 2. Simulasikan event penekanan tombol 'open_book' (hotkey B)
	var ev_press = InputEventAction.new()
	ev_press.action = "open_book"
	ev_press.pressed = true

	tree.root.push_input(ev_press)
	await tree.process_frame

	# 3. Assertions: BookUI harus terbuka (visible == true) dan context == BOOK
	# Memastikan tidak terjadi double-toggle/bounce seketika ke WORLD pada frame yang sama
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.BOOK, "Context must remain BOOK after open_book pressed")
	Assertions.assert_true(book_ui.visible, "BookUI must be visible after open_book pressed")

	# 4. Simulasikan penekanan kedua untuk menutup buku via hotkey B
	var ev_close = InputEventAction.new()
	ev_close.action = "open_book"
	ev_close.pressed = true

	tree.root.push_input(ev_close)
	await tree.process_frame

	# 5. Assertions: BookUI harus tertutup dan context kembali ke WORLD
	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Context must restore to WORLD after second open_book")
	Assertions.assert_false(book_ui.visible, "BookUI must be hidden after second open_book")

	# 6. Simulasikan buka lagi dan tutup via 'pause_menu' (Esc)
	var ev_reopen = InputEventAction.new()
	ev_reopen.action = "open_book"
	ev_reopen.pressed = true
	tree.root.push_input(ev_reopen)
	await tree.process_frame

	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.BOOK, "Context is BOOK after re-open")
	Assertions.assert_true(book_ui.visible, "BookUI is visible after re-open")

	var ev_esc = InputEventAction.new()
	ev_esc.action = "pause_menu"
	ev_esc.pressed = true
	tree.root.push_input(ev_esc)
	await tree.process_frame

	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Context restored to WORLD after Esc")
	Assertions.assert_false(book_ui.visible, "BookUI hidden after Esc")

	# 7. Bersihkan node
	main_node.queue_free()
	await tree.process_frame

	var ok: bool = (Assertions.current_suite_failed == initial_failures)
	if ok:
		print("    [PASS] REG-BOOK-01: Hotkey B double-toggle regression guard verified.")
	else:
		print("    [FAIL] REG-BOOK-01: Defect reproduced! Failures count: %d" % (Assertions.current_suite_failed - initial_failures))
	return ok


