class_name TestCooking
extends RefCounted

## Test Suite COOK-001: Validasi Bahan, Reservasi Atomik, Tahan Persiapan 4s, Pembatalan Aman & Refund Persisten (Suite 11)
## Memverifikasi PRD FR12, CONTENT.md § 2, 3, 4, 11, 12, PROTOTYPE.md § 4, 5, 6.2, 6.3, TASKS.md COOK-001, dan TEST_PLAN T10, T11, T12, T13, T40.

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const RecipeManagerClass = preload("res://scripts/recipe/recipe_manager.gd")
const KitchenManagerClass = preload("res://scripts/cooking/kitchen_manager.gd")
const KitchenUIClass = preload("res://scripts/ui/kitchen_ui.gd")
const WorldResourceManagerClass = preload("res://scripts/world/world_resource_manager.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")
const HUDClass = preload("res://scripts/ui/hud.gd")

class MockKitchenInteractable extends RefCounted:
	var interaction_id: String = "landmark_kitchen"

func run_all() -> bool:
	var passed := true
	print("  Running TestCooking suite (T10, T11, T12, T13, T40, Kitchen UI, Landmarks & Invariants)...")
	var tree := Engine.get_main_loop() as SceneTree

	# Group 1: T10 — Recipe Gating, Prerequisite Validation & Honest Error Reporting
	if not test_t10_zero_ingredients_gating_and_honest_error():
		passed = false
	if not test_t10_partial_ingredients_rejection_and_specification():
		passed = false
	if not test_t10_surplus_ingredients_validation_succeeds():
		passed = false
	if not test_t10_occupied_output_slot_gating():
		passed = false

	# Group 2: T11 — Ingredient Reservation, Cross-Container Unified Stock & Origin Manifest
	if not test_t11_reservation_all_from_backpack():
		passed = false
	if not test_t11_reservation_split_across_backpack_and_storage():
		passed = false
	if not test_t11_unreserved_items_completely_untouched():
		passed = false
	if not test_t11_free_stock_reduction_and_recipe_tracker_sync():
		passed = false

	# Group 3: T12 — 4.0s Preparation Hold State, Interruption, Transition & Anti-Spam
	if not test_t12_prep_hold_partial_progress_and_retention():
		passed = false
	if not test_t12_prep_hold_4s_completion_to_ready_to_heat():
		passed = false
	if not test_t12_no_auto_cook_transition_from_hold():
		passed = false
	if not test_t12_anti_spam_repeated_clicks_protection():
		passed = false

	# Group 4: T13 — Safe Pre-Cooking Cancellation & Exact Origin Return
	if not test_t13_cancel_during_preparing_returns_to_exact_origins():
		passed = false
	if not test_t13_cancel_at_ready_to_heat_returns_to_exact_origins():
		passed = false
	if not test_t13_cancel_idempotency_guard():
		passed = false
	if not test_t13_station_returns_to_clean_idle_on_cancel():
		passed = false

	# Group 5: T40 — Safe Refund Redirection Under Full Container Edge Cases & Strict Isolation
	if not test_t40_backpack_filled_in_interim_spills_to_storage():
		passed = false
	if not test_t40_both_containers_filled_spills_to_kitchen_refund():
		passed = false
	if not test_t40_conservation_of_matter_invariance_under_overflow():
		passed = false
	if not test_t40_kitchen_refund_and_output_slot_strict_isolation():
		passed = false
	if not test_t40_claim_refund_items():
		passed = false

	# Group 6: Architecture, Interlocks, UI & Context Invariants
	if not test_interlock_world_resource_manager_can_sleep():
		passed = false
	if not test_extra_save_snapshot_roundtrip():
		passed = false
	if not await test_extra_kitchen_ui_instantiation_and_wiring(tree):
		passed = false
	if not test_extra_hud_landmark_prompt():
		passed = false
	if not await test_extra_world_landmark_kitchen_station(tree):
		passed = false

	return passed

# --- Helpers ---

func _create_clean_inventory() -> Node:
	var inv: Node = InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.storage_home.clear()
	inv.kitchen_refund.clear()
	inv.starter_claimed = false
	inv._reservations.clear()
	return inv

func _create_clean_kitchen(inv: Node, rm: Node = null) -> Node:
	var km: Node = KitchenManagerClass.new()
	km.set_inventory_manager(inv)
	if rm != null:
		km.set_recipe_manager(rm)
	km._ready()
	return km

func _create_clean_recipe(inv: Node = null) -> Node:
	var rm: Node = RecipeManagerClass.new()
	if inv != null:
		rm.set_inventory_manager(inv)
	rm._ready()
	return rm

# ==============================================================================
# GROUP 1: T10 — Gating & Prerequisite Validation
# ==============================================================================

func test_t10_zero_ingredients_gating_and_honest_error() -> bool:
	var inv := _create_clean_inventory()
	var km := _create_clean_kitchen(inv)

	var check: Dictionary = km.can_start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(check.get("success", true), "T10: Gagal bila bahan kosong sama sekali")
	Assertions.assert_true(str(check.get("reason", "")).contains("Bahan belum lengkap"), "T10: Pesan jujur menyebut bahan belum lengkap")
	var missing: Dictionary = check.get("missing", {})
	Assertions.assert_equal(missing.size(), 3, "T10: Ketiga bahan dilaporkan kurang")
	Assertions.assert_equal(missing.get("ingredient_bayam"), 3, "T10: Kurang 3 bayam")
	Assertions.assert_equal(missing.get("ingredient_jagung"), 1, "T10: Kurang 1 jagung")
	Assertions.assert_equal(missing.get("ingredient_temu_kunci"), 1, "T10: Kurang 1 temu kunci")

	var start_res: Dictionary = km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(start_res.get("success", true), "T10: start_preparation ditolak bersih")
	Assertions.assert_equal(km.job_state, km.JobState.IDLE, "T10: Stasiun tetap IDLE")
	Assertions.assert_equal(km.active_job_id, "", "T10: Tidak ada job ID yang tercipta")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 0, "T10: Nol mutasi pada tas")
	return true

func test_t10_partial_ingredients_rejection_and_specification() -> bool:
	# Sub-case A: Kurang 1 bayam (2 bayam, 1 jagung, 1 temu kunci)
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 2)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	var km := _create_clean_kitchen(inv)

	var check_a: Dictionary = km.can_start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(check_a.get("success", true), "T10-A: Ditolak bila bayam kurang 1")
	var missing_a: Dictionary = check_a.get("missing", {})
	Assertions.assert_equal(missing_a.get("ingredient_bayam"), 1, "T10-A: Melaporkan kurang 1 bayam")
	Assertions.assert_false(missing_a.has("ingredient_jagung"), "T10-A: Jagung tidak dilaporkan kurang")

	var start_a: Dictionary = km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(start_a.get("success", true), "T10-A: start_preparation gagal")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 2, "T10-A: Bayam tetap 2 di tas (nol mutasi)")

	# Sub-case B: Kurang jagung (3 bayam, 0 jagung, 1 temu kunci)
	inv.backpack.clear()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	var check_b: Dictionary = km.can_start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(check_b.get("success", true), "T10-B: Ditolak bila jagung kurang")
	var missing_b: Dictionary = check_b.get("missing", {})
	Assertions.assert_equal(missing_b.get("ingredient_jagung"), 1, "T10-B: Melaporkan kurang 1 jagung")

	# Sub-case C: Kurang temu kunci (3 bayam, 1 jagung, 0 temu kunci)
	inv.backpack.clear()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	var check_c: Dictionary = km.can_start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(check_c.get("success", true), "T10-C: Ditolak bila temu kunci kurang")
	var missing_c: Dictionary = check_c.get("missing", {})
	Assertions.assert_equal(missing_c.get("ingredient_temu_kunci"), 1, "T10-C: Melaporkan kurang 1 temu kunci")
	return true

func test_t10_surplus_ingredients_validation_succeeds() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 10)
	inv.backpack.add_item("ingredient_jagung", 5)
	inv.backpack.add_item("ingredient_temu_kunci", 5)
	var km := _create_clean_kitchen(inv)

	var check: Dictionary = km.can_start_preparation("recipe_sayur_bening_01")
	Assertions.assert_true(check.get("success", false), "T10: Validasi sukses bila bahan surplus")
	var missing: Dictionary = check.get("missing", {})
	Assertions.assert_true(missing.is_empty(), "T10: Tidak ada bahan yang kurang")
	return true

func test_t10_occupied_output_slot_gating() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	var km := _create_clean_kitchen(inv)

	# Simulasikan slot output masih berisi masakan sebelumnya
	km.dish_output_slot = {"item_id": "dish_sayur_bening", "count": 1}

	var check: Dictionary = km.can_start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(check.get("success", true), "T10: Ditolak jika slot output masih terisi")
	Assertions.assert_true(str(check.get("reason", "")).contains("Ambil hidangan"), "T10: Pesan menyebut ambil hidangan sebelumnya dahulu")

	var start_res: Dictionary = km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(start_res.get("success", true), "T10: start_prep ditolak bila slot output terisi")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 3, "T10: Bahan di tas tidak termutasi")
	return true

# ==============================================================================
# GROUP 2: T11 — Reservation & Origin Mapping
# ==============================================================================

func test_t11_reservation_all_from_backpack() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	var km := _create_clean_kitchen(inv)

	var res: Dictionary = km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_true(res.get("success", false), "T11: Reservasi seluruhnya dari tas berhasil")
	Assertions.assert_true(km.active_job_id.begins_with("job_sayur_bening"), "T11: Job ID stabil berawalan recipe")
	Assertions.assert_equal(km.job_state, km.JobState.RESERVED_PREPARING, "T11: Transisi ke status RESERVED_PREPARING")

	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 0, "T11: Bayam tas ditarik secara fisik")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 0, "T11: Jagung tas ditarik secara fisik")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 0, "T11: Temu kunci tas ditarik secara fisik")

	Assertions.assert_equal(km.origin_manifest.size(), 3, "T11: 3 record asal tersimpan")
	for rec in km.origin_manifest:
		Assertions.assert_equal(rec.get("container"), "backpack", "T11: Seluruh asal tercatat dari backpack")
	return true

func test_t11_reservation_split_across_backpack_and_storage() -> bool:
	var inv := _create_clean_inventory()
	# Tas: 2 bayam, 1 temu kunci
	inv.backpack.add_item("ingredient_bayam", 2)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	# Peti: 1 bayam, 1 jagung
	inv.storage_home.add_item("ingredient_bayam", 1)
	inv.storage_home.add_item("ingredient_jagung", 1)

	var km := _create_clean_kitchen(inv)
	var res: Dictionary = km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_true(res.get("success", false), "T11: Reservasi terbelah berhasil")

	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 0, "T11: 2 bayam ditarik dari tas")
	Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_bayam"), 0, "T11: 1 bayam sisa ditarik dari peti")
	Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_jagung"), 0, "T11: 1 jagung ditarik dari peti")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 0, "T11: 1 temu kunci ditarik dari tas")

	# Periksa origin manifest
	var bp_bayam: int = 0
	var st_bayam: int = 0
	var st_jagung: int = 0
	var bp_kunci: int = 0

	for rec in km.origin_manifest:
		var c = rec.get("container")
		var it = rec.get("item_id")
		var cnt = int(rec.get("count"))
		if it == "ingredient_bayam" and c == "backpack": bp_bayam += cnt
		elif it == "ingredient_bayam" and c == "storage": st_bayam += cnt
		elif it == "ingredient_jagung" and c == "storage": st_jagung += cnt
		elif it == "ingredient_temu_kunci" and c == "backpack": bp_kunci += cnt

	Assertions.assert_equal(bp_bayam, 2, "T11: Manifest mencatat 2 bayam dari tas")
	Assertions.assert_equal(st_bayam, 1, "T11: Manifest mencatat 1 bayam dari peti")
	Assertions.assert_equal(st_jagung, 1, "T11: Manifest mencatat 1 jagung dari peti")
	Assertions.assert_equal(bp_kunci, 1, "T11: Manifest mencatat 1 temu kunci dari tas")
	return true

func test_t11_unreserved_items_completely_untouched() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 5)
	inv.backpack.add_item("ingredient_jagung", 2)
	inv.backpack.add_item("ingredient_temu_kunci", 2)
	inv.backpack.add_item("seed_bayam", 4)
	inv.backpack.add_item("soil_compost", 1)
	inv.backpack.add_item("tool_fertilizer", 1)

	var km := _create_clean_kitchen(inv)
	km.start_preparation("recipe_sayur_bening_01")

	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 2, "T11: Sisa bayam tetap 2")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 1, "T11: Sisa jagung tetap 1")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 1, "T11: Sisa temu kunci tetap 1")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 4, "T11: Benih bayam utuh 4")
	Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 1, "T11: Kompos utuh 1")
	Assertions.assert_equal(inv.backpack.get_item_count("tool_fertilizer"), 1, "T11: Pupuk utuh 1")
	return true

func test_t11_free_stock_reduction_and_recipe_tracker_sync() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	var rm := _create_clean_recipe(inv)
	rm.track_recipe("recipe_sayur_bening_01")

	Assertions.assert_equal(rm.get_available_ingredient_count("ingredient_bayam"), 3, "T11: Sebelum reservasi, bayam bebas = 3")

	var km := _create_clean_kitchen(inv, rm)
	km.start_preparation("recipe_sayur_bening_01")

	Assertions.assert_equal(rm.get_available_ingredient_count("ingredient_bayam"), 0, "T11: Setelah reservasi, bayam bebas di RecipeManager = 0")
	Assertions.assert_equal(rm.cooking_state, "preparing", "T11: RecipeManager cooking_state = preparing")
	return true

# ==============================================================================
# GROUP 3: T12 — 4.0s Hold Preparation & Anti-Spam
# ==============================================================================

func test_t12_prep_hold_partial_progress_and_retention() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	var km := _create_clean_kitchen(inv)

	km.start_preparation("recipe_sayur_bening_01")
	km.advance_prep(2.0)

	Assertions.assert_approx_equal(km.prep_progress, 2.0, 0.01, "T12: Progress persiapan tercapai 2.0s")
	Assertions.assert_equal(km.job_state, km.JobState.RESERVED_PREPARING, "T12: Masih dalam tahap RESERVED_PREPARING")
	Assertions.assert_true(km.dish_output_slot.is_empty(), "T12: Belum ada output masakan")

	# Simulasikan pelepasan tombol: progress tidak hilang (retained on interrupt)
	km.hold_tick(0.5, false)
	Assertions.assert_approx_equal(km.prep_progress, 2.0, 0.01, "T12: Melepas tombol mempertahankan 2.0s progress")
	return true

func test_t12_prep_hold_4s_completion_to_ready_to_heat() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)

	var signal_emitted := [false]
	km.preparation_completed.connect(func(_j): signal_emitted[0] = true)

	km.start_preparation("recipe_sayur_bening_01")
	km.advance_prep(4.0)

	Assertions.assert_approx_equal(km.prep_progress, 4.0, 0.01, "T12: Progress mencapai 4.0s")
	Assertions.assert_equal(km.job_state, km.JobState.READY_TO_HEAT, "T12: Transisi ke status READY_TO_HEAT")
	Assertions.assert_true(signal_emitted[0], "T12: Sinyal preparation_completed terpancar")
	Assertions.assert_equal(rm.cooking_state, "ready_to_heat", "T12: RecipeManager mencatat status ready_to_heat")
	return true

func test_t12_no_auto_cook_transition_from_hold() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	var km := _create_clean_kitchen(inv)

	km.start_preparation("recipe_sayur_bening_01")
	km.advance_prep(4.0)

	# Teruskan hold lebih dari 4.0s
	km.advance_prep(1.5)
	Assertions.assert_equal(km.job_state, km.JobState.READY_TO_HEAT, "T12: Hold berkelanjutan TIDAK otomatis memulai COOKING (CONTENT.md § 4)")
	Assertions.assert_ne(km.job_state, km.JobState.COOKING, "T12: Tidak berpindah ke COOKING tanpa tombol terpisah")
	return true

func test_t12_anti_spam_repeated_clicks_protection() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	var km := _create_clean_kitchen(inv)

	var initial_res: Dictionary = km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_true(initial_res.get("success", false), "T12: Pemanggilan pertama berhasil")
	var stable_job_id: String = km.active_job_id

	# Lakukan 10 panggilan berulang cepat
	for i in range(10):
		var spam_res: Dictionary = km.start_preparation("recipe_sayur_bening_01")
		Assertions.assert_false(spam_res.get("success", true), "T12: Spam klik %d ditolak" % i)
		Assertions.assert_true(spam_res.get("idempotent", false), "T12: Respon idempotensi aktif")

	Assertions.assert_equal(km.active_job_id, stable_job_id, "T12: Job ID tidak berubah")
	Assertions.assert_equal(km.reserved_ingredients.size(), 3, "T12: Tidak ada duplikasi reservasi")
	return true

# ==============================================================================
# GROUP 4: T13 — Safe Cancellation & Exact Origin Return
# ==============================================================================

func test_t13_cancel_during_preparing_returns_to_exact_origins() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 2)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	inv.storage_home.add_item("ingredient_bayam", 1)
	inv.storage_home.add_item("ingredient_jagung", 1)

	var km := _create_clean_kitchen(inv)
	km.start_preparation("recipe_sayur_bening_01")
	km.advance_prep(1.5)

	var cancel_res: Dictionary = km.cancel_preparation()
	Assertions.assert_true(cancel_res.get("success", false), "T13: Pembatalan saat preparing berhasil")
	Assertions.assert_equal(km.job_state, km.JobState.IDLE, "T13: Stasiun kembali IDLE")
	Assertions.assert_equal(km.active_job_id, "", "T13: Job ID dibersihkan")

	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 2, "T13: 2 bayam kembali ke tas")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 1, "T13: 1 temu kunci kembali ke tas")
	Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_bayam"), 1, "T13: 1 bayam kembali ke peti")
	Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_jagung"), 1, "T13: 1 jagung kembali ke peti")
	return true

func test_t13_cancel_at_ready_to_heat_returns_to_exact_origins() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	var km := _create_clean_kitchen(inv)
	km.start_preparation("recipe_sayur_bening_01")
	km.advance_prep(4.0)
	Assertions.assert_equal(km.job_state, km.JobState.READY_TO_HEAT, "T13: Berada di READY_TO_HEAT")

	var cancel_res: Dictionary = km.cancel_preparation()
	Assertions.assert_true(cancel_res.get("success", false), "T13: Batal di tahap READY_TO_HEAT berhasil")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 3, "T13: 3 bayam kembali ke tas")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_jagung"), 1, "T13: 1 jagung kembali ke tas")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_temu_kunci"), 1, "T13: 1 temu kunci kembali ke tas")
	return true

func test_t13_cancel_idempotency_guard() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	var km := _create_clean_kitchen(inv)
	km.start_preparation("recipe_sayur_bening_01")

	var res1: Dictionary = km.cancel_preparation()
	Assertions.assert_true(res1.get("success", false), "T13: Batal pertama berhasil")
	var res2: Dictionary = km.cancel_preparation()
	Assertions.assert_false(res2.get("success", true), "T13: Batal kedua no-op aman (gagal bersih)")

	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 3, "T13: Bayam tidak digandakan")
	return true

func test_t13_station_returns_to_clean_idle_on_cancel() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	var km := _create_clean_kitchen(inv)
	km.start_preparation("recipe_sayur_bening_01")
	km.cancel_preparation()

	Assertions.assert_equal(km.active_job_id, "", "T13: active_job_id kosong")
	Assertions.assert_equal(km.prep_progress, 0.0, "T13: prep_progress reset 0")
	Assertions.assert_true(km.reserved_ingredients.is_empty(), "T13: reserved_ingredients kosong")
	Assertions.assert_true(km.origin_manifest.is_empty(), "T13: origin_manifest kosong")
	Assertions.assert_true(km.dish_output_slot.is_empty(), "T13: dish_output_slot kosong")
	return true

# ==============================================================================
# GROUP 5: T40 — Full Container Spillover & Strict Isolation
# ==============================================================================

func test_t40_backpack_filled_in_interim_spills_to_storage() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	var km := _create_clean_kitchen(inv)
	km.start_preparation("recipe_sayur_bening_01")

	# Fixture: Penuhi seluruh 12 slot tas dengan item lain
	for i in range(12):
		inv.backpack.add_item("seed_bayam", 20)
	Assertions.assert_equal(inv.backpack.get_used_slots_count(), 12, "T40: Tas penuh 12/12 slot")

	# Batalkan persiapan
	var res: Dictionary = km.cancel_preparation()
	Assertions.assert_true(res.get("success", false), "T40: Pembatalan berhasil saat tas penuh")
	Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 240, "T40: 240 benih di tas tidak terusir")

	# Bahan dialihkan ke peti rumah (storage_home)
	Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_bayam"), 3, "T40: 3 bayam dialihkan ke peti")
	Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_jagung"), 1, "T40: 1 jagung dialihkan ke peti")
	Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_temu_kunci"), 1, "T40: 1 temu kunci dialihkan ke peti")
	return true

func test_t40_both_containers_filled_spills_to_kitchen_refund() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	var km := _create_clean_kitchen(inv)
	km.start_preparation("recipe_sayur_bening_01")

	# Fixture: Penuhi kedua kontainer (tas 12/12 DAN peti 12/12)
	for i in range(12):
		inv.backpack.add_item("seed_bayam", 20)
		inv.storage_home.add_item("soil_compost", 20)

	Assertions.assert_equal(inv.backpack.get_used_slots_count(), 12, "T40: Tas penuh 12/12")
	Assertions.assert_equal(inv.storage_home.get_used_slots_count(), 12, "T40: Peti penuh 12/12")

	var refund_signal_fired := [false]
	km.kitchen_refund_occurred.connect(func(_items): refund_signal_fired[0] = true)

	var res: Dictionary = km.cancel_preparation()
	Assertions.assert_true(res.get("success", false), "T40: Pembatalan berhasil meski tas dan peti penuh")
	Assertions.assert_true(refund_signal_fired[0], "T40: Sinyal kitchen_refund_occurred terpancar")
	Assertions.assert_true(km.has_refund_items(), "T40: Dapur mendeteksi adanya barang di kitchen_refund")

	# Seluruh 5 bahan selamat di kitchen_refund persisten
	Assertions.assert_equal(inv.kitchen_refund.get_item_count("ingredient_bayam"), 3, "T40: 3 bayam berada di kitchen_refund")
	Assertions.assert_equal(inv.kitchen_refund.get_item_count("ingredient_jagung"), 1, "T40: 1 jagung berada di kitchen_refund")
	Assertions.assert_equal(inv.kitchen_refund.get_item_count("ingredient_temu_kunci"), 1, "T40: 1 temu kunci berada di kitchen_refund")
	return true

func test_t40_conservation_of_matter_invariance_under_overflow() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	var km := _create_clean_kitchen(inv)
	km.start_preparation("recipe_sayur_bening_01")

	for i in range(12):
		inv.backpack.add_item("seed_bayam", 20)
		inv.storage_home.add_item("soil_compost", 20)

	km.cancel_preparation()

	# Total item dalam alam semesta: 5 bahan masak + 240 benih + 240 kompos = 485
	var total_items: int = 0
	for it_name in ["ingredient_bayam", "ingredient_jagung", "ingredient_temu_kunci", "seed_bayam", "soil_compost"]:
		total_items += inv.backpack.get_item_count(it_name)
		total_items += inv.storage_home.get_item_count(it_name)
		total_items += inv.kitchen_refund.get_item_count(it_name)

	Assertions.assert_equal(total_items, 485, "T40: Hukum kekekalan materi terpenuhi (485 total item konstan)")
	return true

func test_t40_kitchen_refund_and_output_slot_strict_isolation() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	var km := _create_clean_kitchen(inv)
	km.start_preparation("recipe_sayur_bening_01")

	for i in range(12):
		inv.backpack.add_item("seed_bayam", 20)
		inv.storage_home.add_item("soil_compost", 20)

	km.cancel_preparation()

	# Verifikasi isolasi ketat: slot output masakan DILARANG terkontaminasi bahan batal
	Assertions.assert_true(km.dish_output_slot.is_empty(), "T40: dish_output_slot tetap kosong/bersih dari refund")
	Assertions.assert_false(km.has_ready_output(), "T40: has_ready_output mengembalikan false")
	return true

func test_t40_claim_refund_items() -> bool:
	var inv := _create_clean_inventory()
	inv.kitchen_refund.add_item("ingredient_bayam", 3)

	var km := _create_clean_kitchen(inv)
	Assertions.assert_true(km.has_refund_items(), "T40: has_refund_items = true")

	var claim_res: Dictionary = km.claim_refund_items()
	Assertions.assert_true(claim_res.get("success", false), "T40: Pengambilan refund sukses")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 3, "T40: Bayam berhasil dipindahkan ke tas")
	Assertions.assert_equal(inv.kitchen_refund.get_item_count("ingredient_bayam"), 0, "T40: kitchen_refund kini kosong")
	Assertions.assert_false(km.has_refund_items(), "T40: has_refund_items = false setelah diambil")
	return true

# ==============================================================================
# GROUP 6: Architecture, Interlocks & UI Integration
# ==============================================================================

func test_interlock_world_resource_manager_can_sleep() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	var km := _create_clean_kitchen(inv)
	var wrm := WorldResourceManagerClass.new()
	wrm.set_kitchen_manager(km)

	# Saat dapur IDLE -> dapat tidur
	var sleep_idle: Dictionary = wrm.can_sleep()
	Assertions.assert_true(sleep_idle.get("success", false), "Interlock: Dapat tidur saat dapur IDLE")

	# Saat dapur memiliki job persiapan aktif -> ditolak
	km.start_preparation("recipe_sayur_bening_01")
	var sleep_prep: Dictionary = wrm.can_sleep()
	Assertions.assert_false(sleep_prep.get("success", true), "Interlock: Ditolak tidur saat persiapan dapur aktif")
	Assertions.assert_true(str(sleep_prep.get("reason", "")).contains("Selesaikan atau batalkan proses memasak dahulu"), "Interlock: Pesan penolakan tidur sesuai")

	# Saat dibatalkan kembali ke IDLE -> dapat tidur lagi
	km.cancel_preparation()
	var sleep_after_cancel: Dictionary = wrm.can_sleep()
	Assertions.assert_true(sleep_after_cancel.get("success", false), "Interlock: Dapat tidur lagi setelah persiapan dibatalkan")
	return true

func test_extra_save_snapshot_roundtrip() -> bool:
	var inv := _create_clean_inventory()
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	var km := _create_clean_kitchen(inv)
	km.start_preparation("recipe_sayur_bening_01")
	km.advance_prep(2.5)

	var snapshot: Dictionary = km.get_save_snapshot()
	Assertions.assert_equal(snapshot.get("version"), 1, "Snapshot: versi 1")
	Assertions.assert_approx_equal(float(snapshot.get("prep_progress")), 2.5, 0.01, "Snapshot: progress 2.5s tersimpan")

	# Pulihkan di instance baru
	var fresh_km: Node = KitchenManagerClass.new()
	fresh_km.set_inventory_manager(inv)
	var load_success: bool = fresh_km.load_save_snapshot(snapshot)
	Assertions.assert_true(load_success, "Snapshot: snapshot berhasil dimuat")
	Assertions.assert_equal(fresh_km.job_state, fresh_km.JobState.RESERVED_PREPARING, "Snapshot: status RESERVED_PREPARING dipulihkan")
	Assertions.assert_approx_equal(fresh_km.prep_progress, 2.5, 0.01, "Snapshot: progress 2.5s dipulihkan")
	Assertions.assert_equal(fresh_km.active_job_id, km.active_job_id, "Snapshot: job ID cocok")

	# Lanjutkan progress dari 2.5s ke 4.0s
	fresh_km.advance_prep(1.5)
	Assertions.assert_equal(fresh_km.job_state, fresh_km.JobState.READY_TO_HEAT, "Snapshot: Melanjutkan hingga 4.0s sukses ke READY_TO_HEAT")
	return true

func test_extra_kitchen_ui_instantiation_and_wiring(tree: SceneTree) -> bool:
	var ui_scene: PackedScene = load("res://scenes/ui/kitchen_ui.tscn")
	Assertions.assert_not_null(ui_scene, "UI: scenes/ui/kitchen_ui.tscn berhasil dimuat")
	var ui_instance = ui_scene.instantiate()
	Assertions.assert_not_null(ui_instance, "UI: KitchenUI berhasil diinstantiate")

	var inv := _create_clean_inventory()
	var km := _create_clean_kitchen(inv)
	ui_instance.set_kitchen_manager(km)
	ui_instance.set_inventory_manager(inv)

	if tree != null and tree.root != null:
		tree.root.add_child(ui_instance)

	ui_instance.open()
	Assertions.assert_true(ui_instance.visible, "UI: KitchenUI terbuka (visible = true)")

	ui_instance.close()
	Assertions.assert_false(ui_instance.visible, "UI: KitchenUI tertutup (visible = false)")

	if ui_instance.get_parent() != null:
		ui_instance.get_parent().remove_child(ui_instance)
	ui_instance.queue_free()
	return true

func test_extra_hud_landmark_prompt() -> bool:
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	var hud = hud_scene.instantiate()

	var inv := _create_clean_inventory()
	var km := _create_clean_kitchen(inv)
	hud.set_kitchen_manager(km)

	var kitchen_target := MockKitchenInteractable.new()

	# 1. State IDLE -> "[E] Masak"
	var prompt_idle: String = hud.format_contextual_prompt(kitchen_target)
	Assertions.assert_equal(prompt_idle, "[E] Masak", "HUD: Prompt landmark_kitchen saat idle = [E] Masak")

	# 2. State RESERVED_PREPARING -> "[E] Lanjutkan Dapur"
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	km.start_preparation("recipe_sayur_bening_01")
	var prompt_prep: String = hud.format_contextual_prompt(kitchen_target)
	Assertions.assert_equal(prompt_prep, "[E] Lanjutkan Dapur", "HUD: Prompt saat persiapan aktif = [E] Lanjutkan Dapur")

	# 3. State Output Ready -> "[E] Ambil Masakan"
	km.cancel_preparation()
	km.dish_output_slot = {"item_id": "dish_sayur_bening", "count": 1}
	var prompt_out: String = hud.format_contextual_prompt(kitchen_target)
	Assertions.assert_equal(prompt_out, "[E] Ambil Masakan", "HUD: Prompt saat output siap = [E] Ambil Masakan")

	hud.queue_free()
	return true

func test_extra_world_landmark_kitchen_station(tree: SceneTree) -> bool:
	var graybox_scene: PackedScene = load("res://scenes/world/level_graybox.tscn")
	Assertions.assert_not_null(graybox_scene, "Level: scenes/world/level_graybox.tscn berhasil dimuat")
	var level = graybox_scene.instantiate()
	Assertions.assert_not_null(level, "Level: level_graybox ter-instantiate")

	var kitchen_node = level.get_node_or_null("station_kitchen_home")
	Assertions.assert_not_null(kitchen_node, "Level: station_kitchen_home ada di level_graybox")

	var counter = kitchen_node.get_node_or_null("Counter")
	Assertions.assert_not_null(counter, "Level: Counter StaticBody3D ada pada station_kitchen_home")

	var interactable = kitchen_node.get_node_or_null("Interactable")
	Assertions.assert_not_null(interactable, "Level: Interactable Area3D ada pada station_kitchen_home")
	Assertions.assert_equal(interactable.get("interaction_id"), "landmark_kitchen", "Level: interaction_id = landmark_kitchen")
	Assertions.assert_equal(int(interactable.get("collision_layer")), 4, "Level: collision_layer = 4")

	level.queue_free()
	return true
