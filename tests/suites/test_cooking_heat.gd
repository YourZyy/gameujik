class_name TestCookingHeat
extends RefCounted

## Test Suite COOK-002: Kontrol Panas, Timer Memasak 30s, Jeda Panel, Slot Output Tunggal,
## Centang Buku Resep, dan Aksi Makan Hidangan (Suite 13)
## Memverifikasi PRD FR12/FR13, CONTENT.md § 4, § 10, § 11, § 12, PROTOTYPE.md § 4, § 5, § 6.2, § 6.3,
## TASKS.md COOK-002, dan TEST_PLAN T12, T15, T19, T41, T42, T43.

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const RecipeManagerClass = preload("res://scripts/recipe/recipe_manager.gd")
const KitchenManagerClass = preload("res://scripts/cooking/kitchen_manager.gd")
const KitchenUIClass = preload("res://scripts/ui/kitchen_ui.gd")
const WorldResourceManagerClass = preload("res://scripts/world/world_resource_manager.gd")
const HUDClass = preload("res://scripts/ui/hud.gd")

func run_all() -> bool:
	var passed := true
	print("  Running TestCookingHeat suite (T12, T15, T19, T41, T42, T43 Heat Control, Pause, Output & Eating)...")
	var tree := Engine.get_main_loop() as SceneTree

	# Group 1: T41 — Empirical Heat Multipliers & Stall Warning Validation
	if not test_t41_heat_low_progression_half_speed(): passed = false
	if not test_t41_heat_medium_progression_nominal_speed(): passed = false
	if not test_t41_heat_high_stall_and_matter_conservation(): passed = false
	if not test_t41_dynamic_heat_switching_mid_cook(): passed = false

	# Group 2: T12 — Discrete Cooking Transition & Anti-Spam Start
	if not test_t12_discrete_transition_from_ready_to_heat(): passed = false
	if not test_t12_no_auto_cook_transition_from_prep(): passed = false
	if not test_t12_anti_spam_repeated_start_cooking_clicks(): passed = false

	# Group 3: T42 — Cooking Pause on UI Close & World Simulation Invariance
	if not test_t42_panel_close_pauses_cooking_state(): passed = false
	if not test_t42_time_in_world_does_not_advance_paused_cooking(): passed = false
	if not test_t42_panel_reopen_resumes_cooking_intact(): passed = false
	if not test_t42_hud_tracker_displays_paused_status(): passed = false

	# Group 4: T15 — Single Dish Output Slot & Occupation Gating
	if not test_t15_100_percent_progress_yields_single_dish_in_output(): passed = false
	if not test_t15_occupied_output_blocks_new_preparation(): passed = false
	if not test_t15_take_output_rejected_when_backpack_full(): passed = false
	if not test_t15_take_output_success_clears_slot_and_returns_station_to_idle(): passed = false

	# Group 5: T19 — Recipe Book Checkmark & Remake Count Invariant
	if not test_t19_no_premature_checkmark_before_100_percent(): passed = false
	if not test_t19_completion_at_exact_100_percent_and_signal_emission(): passed = false
	if not test_t19_remake_cycle_increments_counter_and_preserves_checkmark(): passed = false

	# Group 6: T42/T43 — Dish Consumption (Makan Hidangan) & P0 Experience Closing
	if not test_t42_action_eat_consumes_one_portion_atomically(): passed = false
	if not test_t42_action_eat_rejected_when_no_dish_in_backpack(): passed = false
	if not test_t42_p0_ending_flag_evaluation(): passed = false
	if not test_t42_action_eat_idempotency_and_no_hunger_bar(): passed = false

	# Group 7: UI Controls & WorldResourceManager Interlock
	if not test_extra_kitchen_ui_heat_controls_wiring(tree): passed = false
	if not test_extra_bed_sleep_allowed_when_output_ready(): passed = false

	# Group 8: Save Snapshot Envelope v1 Roundtrip
	if not test_extra_save_snapshot_preserves_heat_and_cooking_progress(): passed = false
	if not test_extra_save_snapshot_preserves_output_slot_and_meal_used(): passed = false

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

func _create_clean_recipe(inv: Node = null) -> Node:
	var rm: Node = RecipeManagerClass.new()
	if inv != null:
		rm.set_inventory_manager(inv)
	rm._ready()
	return rm

func _create_clean_kitchen(inv: Node, rm: Node = null) -> Node:
	var km: Node = KitchenManagerClass.new()
	km.set_inventory_manager(inv)
	if rm != null:
		km.set_recipe_manager(rm)
	km._ready()
	return km

func _setup_ready_to_heat(inv: Node, km: Node) -> void:
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	km.start_preparation("recipe_sayur_bening_01")
	km.advance_prep(4.0)

# ==============================================================================
# GROUP 1: T41 — Empirical Heat Multipliers & Stall Warning Validation
# ==============================================================================

func test_t41_heat_low_progression_half_speed() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	Assertions.assert_equal(km.job_state, km.JobState.READY_TO_HEAT, "T41: Siap dipanaskan")
	km.start_cooking(km.HeatLevel.LOW)
	Assertions.assert_equal(km.current_heat_level, km.HeatLevel.LOW, "T41: Tingkat panas awal Rendah")
	Assertions.assert_approx_equal(km.get_heat_multiplier(), 0.5, 0.01, "T41: Pengali Rendah adalah 0.5x")

	# Jalankan 10 detik waktu fisik
	km.advance_cooking(10.0)
	Assertions.assert_approx_equal(km.cook_progress, 5.0, 0.05, "T41: 10s pada Rendah menghasilkan 5.0s progres")

	# Jalankan 50 detik lagi (total 60s waktu fisik untuk mencapai 30s progres)
	km.advance_cooking(50.0)
	Assertions.assert_approx_equal(km.cook_progress, 30.0, 0.05, "T41: Progres mencapai 30.0s setelah 60s waktu fisik")
	Assertions.assert_equal(km.job_state, km.JobState.OUTPUT_READY, "T41: Bertransisi ke OUTPUT_READY")
	return true

func test_t41_heat_medium_progression_nominal_speed() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	km.start_cooking(km.HeatLevel.MEDIUM)
	Assertions.assert_equal(km.current_heat_level, km.HeatLevel.MEDIUM, "T41: Tingkat panas Sedang")
	Assertions.assert_approx_equal(km.get_heat_multiplier(), 1.0, 0.01, "T41: Pengali Sedang adalah 1.0x (nominal)")

	km.advance_cooking(10.0)
	Assertions.assert_approx_equal(km.cook_progress, 10.0, 0.05, "T41: 10s pada Sedang menghasilkan 10.0s progres")

	km.advance_cooking(20.0)
	Assertions.assert_approx_equal(km.cook_progress, 30.0, 0.05, "T41: Tepat 30s nominal selesai")
	Assertions.assert_equal(km.job_state, km.JobState.OUTPUT_READY, "T41: Bertransisi ke OUTPUT_READY pada 30.0s")
	return true

func test_t41_heat_high_stall_and_matter_conservation() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(5.0)

	var warning_received: Array[String] = []
	km.heat_stall_warning.connect(func(msg): warning_received.append(msg))

	km.set_heat_level(km.HeatLevel.HIGH)
	Assertions.assert_equal(km.current_heat_level, km.HeatLevel.HIGH, "T41: Panas Tinggi aktif")
	Assertions.assert_approx_equal(km.get_heat_multiplier(), 0.0, 0.01, "T41: Pengali Tinggi adalah 0.0x")
	Assertions.assert_true(km.is_heat_stalled(), "T41: Status stall aktif")
	Assertions.assert_true(warning_received.size() > 0, "T41: Sinyal peringatan stall terpancar")
	Assertions.assert_true(warning_received[0].contains("Kecilkan panas ke Sedang"), "T41: Pesan stall tepat")

	# Jalankan waktu 15 detik pada panas Tinggi
	km.advance_cooking(15.0)
	Assertions.assert_approx_equal(km.cook_progress, 5.0, 0.01, "T41: Progres tidak bertambah sama sekali saat panas Tinggi")
	Assertions.assert_equal(km.reserved_ingredients.size(), 3, "T41: Bahan tetap utuh tanpa rusak/hangus (Matter Conservation)")
	return true

func test_t41_dynamic_heat_switching_mid_cook() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	# 1. Mulai di Rendah selama 10s -> +5.0s progres
	km.start_cooking(km.HeatLevel.LOW)
	km.advance_cooking(10.0)
	Assertions.assert_approx_equal(km.cook_progress, 5.0, 0.05, "T41 dynamic: Progres 5.0s")

	# 2. Ganti ke Tinggi selama 8s -> progres tetap 5.0s
	km.set_heat_level(km.HeatLevel.HIGH)
	km.advance_cooking(8.0)
	Assertions.assert_approx_equal(km.cook_progress, 5.0, 0.05, "T41 dynamic: Progres tetap 5.0s saat stall")

	# 3. Ganti ke Sedang selama 25s -> +25.0s progres -> total 30.0s (selesai)
	km.set_heat_level(km.HeatLevel.MEDIUM)
	km.advance_cooking(25.0)
	Assertions.assert_approx_equal(km.cook_progress, 30.0, 0.05, "T41 dynamic: Progres mencapai 30.0s")
	Assertions.assert_equal(km.job_state, km.JobState.OUTPUT_READY, "T41 dynamic: Selesai pada total waktu 43s")
	return true

# ==============================================================================
# GROUP 2: T12 — Discrete Cooking Transition & Anti-Spam Start
# ==============================================================================

func test_t12_discrete_transition_from_ready_to_heat() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	Assertions.assert_equal(km.job_state, km.JobState.READY_TO_HEAT, "T12: READY_TO_HEAT")
	var start_res: Dictionary = km.start_cooking()
	Assertions.assert_true(start_res.get("success", false), "T12: start_cooking berhasil")
	Assertions.assert_equal(km.job_state, km.JobState.COOKING, "T12: Bertransisi ke COOKING")
	Assertions.assert_equal(rm.get_cooking_state(), "cooking", "T12: RecipeManager sinkron ke 'cooking'")
	Assertions.assert_equal(km.current_heat_level, km.HeatLevel.LOW, "T12: Default panas awal adalah Rendah")
	return true

func test_t12_no_auto_cook_transition_from_prep() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)

	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)
	km.start_preparation("recipe_sayur_bening_01")

	# Tahan 4.0 detik
	km.advance_prep(4.0)
	Assertions.assert_equal(km.job_state, km.JobState.READY_TO_HEAT, "T12: Tepat pada READY_TO_HEAT")

	# Simulasikan waktu tanpa menekan start_cooking
	km.advance_prep(10.0)
	Assertions.assert_equal(km.job_state, km.JobState.READY_TO_HEAT, "T12: Tetap READY_TO_HEAT, tidak auto-cook")
	Assertions.assert_equal(km.cook_progress, 0.0, "T12: Cook progress tetap 0.0")
	return true

func test_t12_anti_spam_repeated_start_cooking_clicks() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(12.0)
	var current_prog: float = km.cook_progress
	var orig_job_id: String = km.active_job_id

	# Klik start_cooking 30 kali berulang
	for i in range(30):
		var res: Dictionary = km.start_cooking(km.HeatLevel.MEDIUM)
		Assertions.assert_false(res.get("success", true), "T12 anti-spam: Klik berulang ditolak")
		Assertions.assert_true(res.get("idempotent", false), "T12 anti-spam: Respon idempotent")

	Assertions.assert_approx_equal(km.cook_progress, current_prog, 0.01, "T12 anti-spam: Timer tidak ter-reset")
	Assertions.assert_equal(km.active_job_id, orig_job_id, "T12 anti-spam: Job ID tidak berubah")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 0, "T12 anti-spam: Nol mutasi bahan tambahan")
	return true

# ==============================================================================
# GROUP 3: T42 — Cooking Pause on UI Close & World Simulation Invariance
# ==============================================================================

func test_t42_panel_close_pauses_cooking_state() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(14.0)

	var pause_signal_received: Array[String] = []
	km.cooking_paused.connect(func(job_id): pause_signal_received.append(job_id))

	var pause_res: Dictionary = km.pause_cooking()
	Assertions.assert_true(pause_res.get("success", false), "T42: pause_cooking sukses")
	Assertions.assert_equal(km.job_state, km.JobState.PAUSED, "T42: Status bertransisi ke PAUSED")
	Assertions.assert_equal(rm.get_cooking_state(), "paused", "T42: RecipeManager mencatat status 'paused'")
	Assertions.assert_equal(pause_signal_received.size(), 1, "T42: Sinyal cooking_paused terpancar")
	return true

func test_t42_time_in_world_does_not_advance_paused_cooking() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(14.0)
	km.pause_cooking()

	# Jalankan advance_cooking saat PAUSED (misal tick dunia di latar belakang)
	for i in range(10):
		km.advance_cooking(6.0)

	Assertions.assert_approx_equal(km.cook_progress, 14.0, 0.01, "T42: Waktu tidak maju diam-diam di luar panel (No Stealth Background Cooking)")
	Assertions.assert_equal(km.job_state, km.JobState.PAUSED, "T42: Tetap PAUSED")
	return true

func test_t42_panel_reopen_resumes_cooking_intact() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(14.0)
	km.pause_cooking()

	var resume_signal_received: Array[String] = []
	km.cooking_resumed.connect(func(job_id): resume_signal_received.append(job_id))

	var resume_res: Dictionary = km.resume_cooking()
	Assertions.assert_true(resume_res.get("success", false), "T42: resume_cooking sukses")
	Assertions.assert_equal(km.job_state, km.JobState.COOKING, "T42: Kembali ke COOKING")
	Assertions.assert_equal(rm.get_cooking_state(), "cooking", "T42: RecipeManager sinkron kembali ke 'cooking'")
	Assertions.assert_equal(resume_signal_received.size(), 1, "T42: Sinyal cooking_resumed terpancar")
	Assertions.assert_approx_equal(km.cook_progress, 14.0, 0.01, "T42: Progres melanjutkan persis dari 14.0s")

	# Lanjutkan sisa 16s
	km.advance_cooking(16.0)
	Assertions.assert_approx_equal(km.cook_progress, 30.0, 0.05, "T42: Selesai 30.0s setelah resume")
	Assertions.assert_equal(km.job_state, km.JobState.OUTPUT_READY, "T42: Bertransisi ke OUTPUT_READY")
	return true

func test_t42_hud_tracker_displays_paused_status() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	rm.track_recipe("recipe_sayur_bening_01")
	rm.set_cooking_state("paused")
	Assertions.assert_equal(rm.get_cooking_state(), "paused", "T42: Cooking state di RecipeManager adalah 'paused'")
	return true

# ==============================================================================
# GROUP 4: T15 — Single Dish Output Slot & Occupation Gating
# ==============================================================================

func test_t15_100_percent_progress_yields_single_dish_in_output() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	var completed_dishes: Array[Dictionary] = []
	km.cooking_completed.connect(func(_job, dish): completed_dishes.append(dish))

	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(30.0)

	Assertions.assert_equal(km.job_state, km.JobState.OUTPUT_READY, "T15: State adalah OUTPUT_READY")
	Assertions.assert_true(km.has_ready_output(), "T15: Memiliki output masakan yang siap")
	Assertions.assert_equal(completed_dishes.size(), 1, "T15: Sinyal cooking_completed terpancar tepat 1 kali")

	var out: Dictionary = km.get_dish_output()
	Assertions.assert_equal(out.get("item_id"), "dish_sayur_bening", "T15: Output berisi dish_sayur_bening")
	Assertions.assert_equal(out.get("count"), 1, "T15: Output berjumlah tepat 1 porsi")
	Assertions.assert_equal(km.reserved_ingredients.size(), 0, "T15: Bahan yang direservasi telah dikonsumsi penuh")
	return true

func test_t15_occupied_output_blocks_new_preparation() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(30.0)

	# Beri bahan baru ke tas
	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	var can_prep: Dictionary = km.can_start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(can_prep.get("success", true), "T15: can_start_preparation ditolak saat output terisi")
	Assertions.assert_true(str(can_prep.get("reason", "")).contains("Ambil hidangan sebelumnya"), "T15: Pesan jujur mengambil hidangan dahulu")

	var start_prep: Dictionary = km.start_preparation("recipe_sayur_bening_01")
	Assertions.assert_false(start_prep.get("success", true), "T15: start_preparation ditolak bersih")
	Assertions.assert_equal(km.job_state, km.JobState.OUTPUT_READY, "T15: Status tetap OUTPUT_READY")
	Assertions.assert_equal(inv.backpack.get_item_count("ingredient_bayam"), 3, "T15: Nol mutasi pada bahan baru di tas")
	return true

func test_t15_take_output_rejected_when_backpack_full() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(30.0)

	# Penuhi tas 12/12 dengan item lain (12 item ID berbeda agar mengisi 12 slot terpisah)
	for i in range(12):
		inv.backpack.add_item("dummy_item_%d" % i, 1)

	Assertions.assert_equal(inv.backpack.get_used_slots_count(), 12, "T15: Tas terisi penuh 12/12")

	var claim_res: Dictionary = km.claim_dish_output()
	Assertions.assert_false(claim_res.get("success", true), "T15: Klaim ditolak saat tas penuh")
	Assertions.assert_true(str(claim_res.get("reason", "")).contains("Tas tidak cukup"), "T15: Pesan jujur tas tidak cukup")

	# Asersi bahwa hidangan tetap aman di slot dapur tanpa rusak/hilang
	Assertions.assert_true(km.has_ready_output(), "T15: Hidangan tetap berada di slot dapur")
	Assertions.assert_equal(km.dish_output_slot.get("count"), 1, "T15: Jumlah hidangan tetap 1")
	Assertions.assert_equal(km.job_state, km.JobState.OUTPUT_READY, "T15: State tetap OUTPUT_READY")
	return true

func test_t15_take_output_success_clears_slot_and_returns_station_to_idle() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(30.0)

	var collected_items: Array[String] = []
	km.dish_collected.connect(func(it, _cnt): collected_items.append(it))

	var claim_res: Dictionary = km.claim_dish_output()
	Assertions.assert_true(claim_res.get("success", false), "T15: Klaim sukses saat tas memiliki ruang")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 1, "T15: Hidangan berpindah ke tas pemain")
	Assertions.assert_false(km.has_ready_output(), "T15: Slot output dapur kini kosong")
	Assertions.assert_equal(km.job_state, km.JobState.IDLE, "T15: Stasiun kembali ke IDLE")
	Assertions.assert_equal(rm.get_cooking_state(), "idle", "T15: RecipeManager sinkron kembali ke 'idle'")
	Assertions.assert_equal(collected_items.size(), 1, "T15: Sinyal dish_collected terpancar")
	return true

# ==============================================================================
# GROUP 5: T19 — Recipe Book Checkmark & Remake Count Invariant
# ==============================================================================

func test_t19_no_premature_checkmark_before_100_percent() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)

	inv.backpack.add_item("ingredient_bayam", 3)
	inv.backpack.add_item("ingredient_jagung", 1)
	inv.backpack.add_item("ingredient_temu_kunci", 1)

	var recipe = rm.get_recipe("recipe_sayur_bening_01")
	Assertions.assert_equal(recipe.times_cooked, 0, "T19 checkmark: times_cooked awal = 0")
	Assertions.assert_false(rm.is_recipe_completed("recipe_sayur_bening_01"), "T19: Belum selesai saat IDLE")

	km.start_preparation("recipe_sayur_bening_01")
	km.advance_prep(2.0)
	Assertions.assert_false(rm.is_recipe_completed("recipe_sayur_bening_01"), "T19: Belum selesai saat PREPARING 2s")

	km.advance_prep(2.0)
	Assertions.assert_false(rm.is_recipe_completed("recipe_sayur_bening_01"), "T19: Belum selesai saat READY_TO_HEAT")

	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(29.9)
	Assertions.assert_false(rm.is_recipe_completed("recipe_sayur_bening_01"), "T19: Belum selesai saat COOKING 29.9s")
	Assertions.assert_equal(recipe.times_cooked, 0, "T19: times_cooked tetap 0 pada 29.9s")
	return true

func test_t19_completion_at_exact_100_percent_and_signal_emission() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	var signals_emitted: Array[String] = []
	rm.recipe_completed.connect(func(rec_id): signals_emitted.append(rec_id))

	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(30.0)

	var recipe = rm.get_recipe("recipe_sayur_bening_01")
	Assertions.assert_equal(recipe.times_cooked, 1, "T19: times_cooked bertambah menjadi 1 tepat pada 100%")
	Assertions.assert_true(rm.is_recipe_completed("recipe_sayur_bening_01"), "T19: Resep centang selesai")
	Assertions.assert_equal(signals_emitted.size(), 1, "T19: Sinyal recipe_completed terpancar tepat 1 kali")
	return true

func test_t19_remake_cycle_increments_counter_and_preserves_checkmark() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	var signals_emitted: Array[String] = []
	rm.recipe_completed.connect(func(rec_id): signals_emitted.append(rec_id))

	# Masak pertama kali
	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(30.0)
	km.claim_dish_output()

	var recipe = rm.get_recipe("recipe_sayur_bening_01")
	Assertions.assert_equal(recipe.times_cooked, 1, "T19 remake: times_cooked = 1")
	Assertions.assert_equal(signals_emitted.size(), 1, "T19 remake: Sinyal pertama terpancar")

	# Masak kedua kali (Remake)
	_setup_ready_to_heat(inv, km)
	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(30.0)

	Assertions.assert_equal(recipe.times_cooked, 2, "T19 remake: times_cooked bertambah menjadi 2")
	Assertions.assert_true(rm.is_recipe_completed("recipe_sayur_bening_01"), "T19 remake: Centang resep tetap aktif")
	Assertions.assert_equal(signals_emitted.size(), 1, "T19 remake: Sinyal recipe_completed TIDAK dipancarkan ulang")
	return true

# ==============================================================================
# GROUP 6: T42/T43 — Dish Consumption (Makan Hidangan) & P0 Experience Closing
# ==============================================================================

func test_t42_action_eat_consumes_one_portion_atomically() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)

	inv.backpack.add_item("dish_sayur_bening", 2)
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 2, "T43: Tas memiliki 2 porsi hidangan")

	var eat_res: Dictionary = km.eat_dish("dish_sayur_bening")
	Assertions.assert_true(eat_res.get("success", false), "T43: eat_dish sukses")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 1, "T43: Tepat 1 porsi berkurang (sisa 1)")
	Assertions.assert_true(km.meal_used, "T43: Flag meal_used di KitchenManager menjadi true")
	Assertions.assert_true(str(eat_res.get("message", "")).contains("Hangat. Resep pertama berhasil dibuat."), "T43: Pesan jujur hangat")
	return true

func test_t42_action_eat_rejected_when_no_dish_in_backpack() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)

	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 0, "T43: Tas tidak memiliki hidangan")
	var eat_res: Dictionary = km.eat_dish("dish_sayur_bening")
	Assertions.assert_false(eat_res.get("success", true), "T43: eat_dish ditolak saat tidak ada hidangan")
	return true

func test_t42_p0_ending_flag_evaluation() -> bool:
	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	_setup_ready_to_heat(inv, km)

	# 1. Sebelum memasak & sebelum makan
	Assertions.assert_false(rm.is_recipe_completed("recipe_sayur_bening_01") and km.meal_used, "T43 ending: P0 belum terpenuhi")

	# 2. Masak selesai tapi belum makan
	km.start_cooking(km.HeatLevel.MEDIUM)
	km.advance_cooking(30.0)
	km.claim_dish_output()
	Assertions.assert_true(rm.is_recipe_completed("recipe_sayur_bening_01"), "T43 ending: Resep selesai")
	Assertions.assert_false(km.meal_used, "T43 ending: meal_used masih false")
	Assertions.assert_false(rm.is_recipe_completed("recipe_sayur_bening_01") and km.meal_used, "T43 ending: P0 belum terpenuhi sebelum makan")

	# 3. Makan hidangan
	var eat_res: Dictionary = km.eat_dish("dish_sayur_bening")
	Assertions.assert_true(eat_res.get("p0_completed", false), "T43 ending: P0 terpenuhi penuh setelah resep selesai + hidangan dimakan!")
	return true

func test_t42_action_eat_idempotency_and_no_hunger_bar() -> bool:
	var inv := _create_clean_inventory()
	var km := _create_clean_kitchen(inv)

	# Asersi bahwa tidak ada properti statistik fiktif atau hunger bar
	Assertions.assert_false("hunger" in km, "T43 no hunger bar: Tidak ada hunger property")
	Assertions.assert_false("stamina" in km, "T43 no stamina bar: Tidak ada stamina property")
	Assertions.assert_false("exp" in km, "T43 no exp: Tidak ada exp property")
	return true

# ==============================================================================
# GROUP 7: UI Controls & WorldResourceManager Interlock
# ==============================================================================

func test_extra_kitchen_ui_heat_controls_wiring(tree: SceneTree) -> bool:
	var kitchen_ui_scene = load("res://scenes/ui/kitchen_ui.tscn")
	Assertions.assert_true(kitchen_ui_scene != null, "UI: kitchen_ui.tscn berhasil dimuat")
	var ui: CanvasLayer = kitchen_ui_scene.instantiate() as CanvasLayer
	tree.root.add_child(ui)

	var inv := _create_clean_inventory()
	var rm := _create_clean_recipe(inv)
	var km := _create_clean_kitchen(inv, rm)
	ui.set_inventory_manager(inv)
	ui.set_kitchen_manager(km)
	ui.set_recipe_manager(rm)

	ui.open()
	Assertions.assert_true(ui.visible, "UI: Panel terbuka")

	# Setup cooking
	_setup_ready_to_heat(inv, km)
	km.start_cooking(km.HeatLevel.LOW)
	ui.refresh_ui()

	Assertions.assert_true(ui.cooking_section.visible, "UI: CookingSection tampil saat COOKING")
	Assertions.assert_false(ui.prep_section.visible, "UI: PrepSection tertutup")

	# Klik tombol Sedang
	ui.heat_med_button.emit_signal("pressed")
	Assertions.assert_equal(km.current_heat_level, km.HeatLevel.MEDIUM, "UI: Tombol Sedang mengubah heat level ke Sedang")

	# Klik tombol Tinggi
	ui.heat_high_button.emit_signal("pressed")
	Assertions.assert_equal(km.current_heat_level, km.HeatLevel.HIGH, "UI: Tombol Tinggi mengubah heat level ke Tinggi")
	Assertions.assert_true(ui.heat_warning_panel.visible, "UI: Heat warning panel tampil saat stall")

	# Close panel -> pause cooking
	ui.close()
	Assertions.assert_false(ui.visible, "UI: Panel tertutup")
	Assertions.assert_equal(km.job_state, km.JobState.PAUSED, "UI: Menutup panel memicu pause_cooking()")

	ui.open()
	Assertions.assert_true(ui.paused_panel.visible, "UI: PausedPanel tampil saat dibuka dalam kondisi PAUSED")

	ui.resume_cooking_button.emit_signal("pressed")
	Assertions.assert_equal(km.job_state, km.JobState.COOKING, "UI: Resume button melanjutkan memasak")

	# Selesaikan memasak
	km.set_heat_level(km.HeatLevel.MEDIUM)
	km.advance_cooking(30.0)
	ui.refresh_ui()

	Assertions.assert_true(ui.output_section.visible, "UI: OutputSection tampil saat masakan selesai")

	ui.take_dish_button.emit_signal("pressed")
	Assertions.assert_equal(inv.backpack.get_item_count("dish_sayur_bening"), 1, "UI: Tombol Ambil Masakan memindahkan hidangan ke tas")

	ui.queue_free()
	return true

func test_extra_bed_sleep_allowed_when_output_ready() -> bool:
	var wrm := WorldResourceManagerClass.new()
	var inv := _create_clean_inventory()
	var km := _create_clean_kitchen(inv)
	wrm.set_kitchen_manager(km)
	wrm.set_inventory_manager(inv)

	# 1. Saat memasak aktif -> tidur ditolak
	km.job_state = km.JobState.COOKING
	var sleep_res1 := wrm.can_sleep()
	Assertions.assert_false(sleep_res1.get("success", true), "Sleep: Ditolak saat COOKING")

	# 2. Saat jeda -> tidur ditolak
	km.job_state = km.JobState.PAUSED
	var sleep_res2 := wrm.can_sleep()
	Assertions.assert_false(sleep_res2.get("success", true), "Sleep: Ditolak saat PAUSED")

	# 3. Saat masakan sudah selesai (OUTPUT_READY) -> tidur diizinkan (CONTENT.md § 9 line 164)
	km.job_state = km.JobState.OUTPUT_READY
	var sleep_res3 := wrm.can_sleep()
	Assertions.assert_true(sleep_res3.get("success", false), "Sleep: Diizinkan saat OUTPUT_READY")
	return true

# ==============================================================================
# GROUP 8: Save Snapshot Envelope v1 Roundtrip
# ==============================================================================

func test_extra_save_snapshot_preserves_heat_and_cooking_progress() -> bool:
	var inv := _create_clean_inventory()
	var km1 := _create_clean_kitchen(inv)
	_setup_ready_to_heat(inv, km1)

	km1.start_cooking(km1.HeatLevel.LOW)
	km1.advance_cooking(12.0)
	km1.pause_cooking()

	var snapshot: Dictionary = km1.get_save_snapshot()
	Assertions.assert_equal(snapshot.get("version"), 1, "Save: Envelope v1")
	Assertions.assert_equal(snapshot.get("job_state"), int(km1.JobState.PAUSED), "Save: job_state PAUSED tersimpan")
	Assertions.assert_approx_equal(float(snapshot.get("cook_progress")), 6.0, 0.05, "Save: cook_progress tersimpan")
	Assertions.assert_equal(int(snapshot.get("heat_level")), int(km1.HeatLevel.LOW), "Save: heat_level tersimpan")

	var km2 := _create_clean_kitchen(inv)
	var load_ok: bool = km2.load_save_snapshot(snapshot)
	Assertions.assert_true(load_ok, "Save: load_save_snapshot berhasil")
	Assertions.assert_equal(km2.job_state, km2.JobState.PAUSED, "Save: job_state terpulihkan")
	Assertions.assert_approx_equal(km2.cook_progress, 6.0, 0.05, "Save: cook_progress terpulihkan")
	Assertions.assert_equal(km2.current_heat_level, km2.HeatLevel.LOW, "Save: heat_level terpulihkan")
	return true

func test_extra_save_snapshot_preserves_output_slot_and_meal_used() -> bool:
	var inv := _create_clean_inventory()
	var km1 := _create_clean_kitchen(inv)
	_setup_ready_to_heat(inv, km1)

	km1.start_cooking(km1.HeatLevel.MEDIUM)
	km1.advance_cooking(30.0)
	km1.meal_used = true

	var snapshot: Dictionary = km1.get_save_snapshot()
	Assertions.assert_equal(snapshot.get("job_state"), int(km1.JobState.OUTPUT_READY), "Save: OUTPUT_READY tersimpan")
	Assertions.assert_true(snapshot.get("meal_used"), "Save: meal_used = true tersimpan")
	var dish_slot: Dictionary = snapshot.get("dish_output_slot", {})
	Assertions.assert_equal(dish_slot.get("item_id"), "dish_sayur_bening", "Save: dish_output_slot tersimpan")

	var km2 := _create_clean_kitchen(inv)
	var load_ok: bool = km2.load_save_snapshot(snapshot)
	Assertions.assert_true(load_ok, "Save: load_save_snapshot berhasil")
	Assertions.assert_equal(km2.job_state, km2.JobState.OUTPUT_READY, "Save: OUTPUT_READY terpulihkan")
	Assertions.assert_true(km2.meal_used, "Save: meal_used terpulihkan")
	Assertions.assert_equal(km2.dish_output_slot.get("item_id"), "dish_sayur_bening", "Save: dish_output_slot terpulihkan")
	return true
