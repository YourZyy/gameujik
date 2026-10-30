class_name TestSave
extends RefCounted

## Test Suite SAVE-001: Persistensi Lengkap, Checkpoint, Validasi Envelope, Snapshot Swap, dan Error Recovery (Suite 19)
## Memverifikasi PRD FR15, CONTENT.md § 11, § 12, § 14, PROTOTYPE.md § 5, § 7,
## TASKS.md SAVE-001, dan TEST_PLAN T14, T16, T17, T22, T46, T47, T48, T49, T50.

const Assertions = preload("res://tests/assertions.gd")
const SaveManagerClass = preload("res://scripts/save/save_manager.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const RecipeManagerClass = preload("res://scripts/recipe/recipe_manager.gd")
const GardenManagerClass = preload("res://scripts/gardening/garden_manager.gd")
const WorldResourceManagerClass = preload("res://scripts/world/world_resource_manager.gd")
const KitchenManagerClass = preload("res://scripts/cooking/kitchen_manager.gd")
const DialogueManagerClass = preload("res://scripts/social/dialogue_manager.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")

const SANDBOX_DIR: String = "user://test_save_sandbox/"
const SANDBOX_SETTINGS_PATH: String = "user://test_save_sandbox/settings.cfg"

func run_all() -> bool:
	var passed := true
	print("==================================================")
	print("[SUITE 19] TestSave: Persistensi Lengkap, Validasi Envelope & Error Recovery (SAVE-001)")
	print("==================================================")

	_setup_sandbox()

	# Grup 1: T14 — Preservasi Tas, Peti, Alat & Job Dijeda
	if not test_t14_01_backpack_storage_and_tools_preservation(): passed = false
	if not test_t14_02_paused_job_and_crop_growth_preservation_no_offline_progress(): passed = false

	# Grup 2: T16 — Validasi Pra-Swap Dunia & Penolakan Snapshot Rusak
	if not test_t16_01_reject_snapshot_with_missing_mandatory_sections(): passed = false
	if not test_t16_02_reject_snapshot_with_unknown_item_ids_and_illegal_counts(): passed = false
	if not test_t16_03_atomic_world_swap_all_or_nothing(): passed = false

	# Grup 3: T17 — Ketahanan Berkas Korup & Fallback Cadangan (.bak)
	if not test_t17_01_fallback_to_bak_when_primary_save_file_corrupted(): passed = false
	if not test_t17_02_clean_failure_when_both_primary_and_bak_are_corrupted(): passed = false
	if not test_t17_03_zero_byte_file_resilience(): passed = false

	# Grup 4: T22 — Validasi Posisi Pemain & Safe Spawn Redirection
	if not test_t22_01_redirect_nan_and_inf_coordinates_to_safe_spawn(): passed = false
	if not test_t22_02_redirect_out_of_bounds_coordinates_to_safe_spawn(): passed = false
	if not test_t22_03_valid_coordinates_preserved_without_redirection(): passed = false

	# Grup 5: T46 — Pemulihan Status Dinamis Kebun dan Dapur
	if not test_t46_01_garden_plot_and_crop_stages_restoration(): passed = false
	if not test_t46_02_kitchen_job_reservation_origin_and_refund_restoration(): passed = false

	# Grup 6: T47 — Uji Ketahanan Crash Penulisan Atomik via .tmp
	if not test_t47_01_atomic_write_creates_tmp_before_target(): passed = false
	if not test_t47_02_existing_save_unharmed_if_write_fails_midway(): passed = false
	if not test_t47_03_temp_file_cleanup_on_failure(): passed = false

	# Grup 7: T48 — Manajemen Slot Manual, Autosave, dan Cadangan
	if not test_t48_01_separate_manual_and_autosave_slot_isolation(): passed = false
	if not test_t48_02_continue_selects_newest_revision_across_slots(): passed = false
	if not test_t48_03_explicit_manual_slot_selection_when_autosave_is_newer(): passed = false
	if not test_t48_04_backup_creation_on_every_successful_overwrite(): passed = false

	# Grup 8: T49 — Isolasi Pengaturan (settings.cfg) dari Save Game
	if not test_t49_01_settings_stored_in_standalone_config_file(): passed = false
	if not test_t49_02_game_load_and_new_game_preserves_settings(): passed = false
	if not test_t49_03_settings_corruption_does_not_affect_save_game(): passed = false

	# Grup 9: T50 — Round-Trip Save/Load 100% Identik & Idempotensi
	if not test_t50_01_comprehensive_p0_game_state_roundtrip(): passed = false
	if not test_t50_02_idempotent_multi_roundtrip(): passed = false

	_teardown_sandbox()
	return passed

# ==============================================================================
# Sandbox Helpers
# ==============================================================================

func _setup_sandbox() -> void:
	_clean_sandbox()
	DirAccess.make_dir_recursive_absolute(SANDBOX_DIR)

func _teardown_sandbox() -> void:
	_clean_sandbox()

func _clean_sandbox() -> void:
	if DirAccess.dir_exists_absolute(SANDBOX_DIR):
		var dir := DirAccess.open(SANDBOX_DIR)
		if dir:
			dir.list_dir_begin()
			var fn := dir.get_next()
			while fn != "":
				if not dir.current_is_dir():
					dir.remove(fn)
				fn = dir.get_next()
			dir.list_dir_end()
	if FileAccess.file_exists(SANDBOX_SETTINGS_PATH):
		DirAccess.remove_absolute(SANDBOX_SETTINGS_PATH)

func _create_test_save_manager() -> SaveManagerClass:
	var sm := SaveManagerClass.new()
	sm.set_save_directory(SANDBOX_DIR)
	sm.set_settings_path(SANDBOX_SETTINGS_PATH)
	sm._ready()
	return sm

# ==============================================================================
# Grup 1: T14 — Preservasi Tas, Peti, Alat & Job Dijeda
# ==============================================================================

func test_t14_01_backpack_storage_and_tools_preservation() -> bool:
	var passed := true
	var sm := _create_test_save_manager()

	var inv = sm._get_autoload("InventoryManager")
	var gard = sm._get_autoload("GardenManager")
	if inv == null or gard == null:
		return Assertions.assert_true(false, "T14-01: Autoload singletons tidak ditemukan")

	# Fixture Setup
	inv.backpack.clear()
	inv.storage_home.clear()
	inv.kitchen_refund.clear()
	inv.backpack.add_item("seed_bayam", 3)
	inv.backpack.add_item("soil_compost", 1)
	inv.backpack.add_item("fertilizer_basic", 2)
	inv.storage_home.add_item("ingredient_temu_kunci", 1)
	inv.storage_home.add_item("ingredient_bayam", 6)
	inv.kitchen_refund.add_item("seed_bayam", 1)
	inv.starter_claimed = true

	gard.active_tool = "tool_watering_can"
	gard.watering_can_water = 7

	# Save
	var save_res := sm.save_game("manual")
	if not Assertions.assert_true(save_res.get("success", false), "T14-01: Simpan game manual berhasil"): passed = false

	# Mutasi/Clear State
	inv.backpack.clear()
	inv.storage_home.clear()
	inv.kitchen_refund.clear()
	inv.starter_claimed = false
	gard.active_tool = ""
	gard.watering_can_water = 0

	# Load
	var load_res := sm.load_game("manual")
	if not Assertions.assert_true(load_res.get("success", false), "T14-01: Muat game manual berhasil"): passed = false

	# Verifikasi Preservasi
	if not Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 3, "T14-01: Bayam tas pulih x3"): passed = false
	if not Assertions.assert_equal(inv.backpack.get_item_count("soil_compost"), 1, "T14-01: Kompos tas pulih x1"): passed = false
	if not Assertions.assert_equal(inv.backpack.get_item_count("fertilizer_basic"), 2, "T14-01: Pupuk tas pulih x2"): passed = false
	if not Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_temu_kunci"), 1, "T14-01: Temu kunci peti pulih x1"): passed = false
	if not Assertions.assert_equal(inv.storage_home.get_item_count("ingredient_bayam"), 6, "T14-01: Bayam peti pulih x6"): passed = false
	if not Assertions.assert_equal(inv.kitchen_refund.get_item_count("seed_bayam"), 1, "T14-01: Refund pulih x1"): passed = false
	if not Assertions.assert_true(inv.starter_claimed, "T14-01: starter_claimed tetap true"): passed = false
	if not Assertions.assert_equal(gard.active_tool, "tool_watering_can", "T14-01: Alat aktif pulih tool_watering_can"): passed = false
	if not Assertions.assert_equal(gard.watering_can_water, 7, "T14-01: Air penyiram pulih 7/10"): passed = false

	return passed

func test_t14_02_paused_job_and_crop_growth_preservation_no_offline_progress() -> bool:
	var passed := true
	var sm := _create_test_save_manager()

	var gard = sm._get_autoload("GardenManager")
	var kit = sm._get_autoload("KitchenManager")
	if gard == null or kit == null:
		return Assertions.assert_true(false, "T14-02: Singletons tidak ditemukan")

	# Setup Garden
	gard._plots["plot_home_01"]["is_hoed"] = true
	gard._plots["plot_home_01"]["has_compost"] = true
	gard._plots["plot_home_01"]["moisture"] = 65.0
	gard._plots["plot_home_01"]["nutrients"] = 80.0
	gard._plots["plot_home_01"]["spots"]["slot_01"]["is_occupied"] = true
	gard._plots["plot_home_01"]["spots"]["slot_01"]["crop_data"] = {
		"crop_id": "crop_bayam",
		"growth_time": 45.0,
		"growth_stage": 1,
		"is_ready_to_harvest": false,
		"is_stalled": false,
		"stall_reason": ""
	}

	# Setup Kitchen
	kit.job_state = 3 # COOKING
	kit.active_job_id = "job_t14_test"
	kit.active_recipe_id = "recipe_sayur_bening_01"
	kit.cook_progress = 12.5
	kit.cook_duration = 30.0
	kit.reserved_ingredients.clear()
	kit.reserved_ingredients.append({"item_id": "ingredient_bayam", "count": 3})
	kit.reserved_ingredients.append({"item_id": "ingredient_jagung", "count": 1})
	kit.reserved_ingredients.append({"item_id": "ingredient_temu_kunci", "count": 1})
	kit.origin_manifest.clear()
	kit.origin_manifest.append({"source": "backpack", "item_id": "ingredient_bayam", "count": 3})


	# Save
	sm.save_game("manual")

	# Ubah state memori
	kit.job_state = 0 # IDLE
	kit.cook_progress = 0.0
	gard._plots["plot_home_01"]["moisture"] = 0.0

	# Load
	sm.load_game("manual")

	# Verifikasi: Memasak dipulihkan sebagai PAUSED (4) agar tidak jalan diam-diam (PROTOTYPE § 5, T14)
	if not Assertions.assert_equal(int(kit.job_state), 4, "T14-02: Job cooking dipulihkan sebagai PAUSED (4)"): passed = false
	if not Assertions.assert_approx_equal(kit.cook_progress, 12.5, 0.01, "T14-02: Progress masak tetap 12.5s tanpa offline advancement"): passed = false
	if not Assertions.assert_equal(kit.reserved_ingredients.size(), 3, "T14-02: Bahan tereservasi tetap 3 item"): passed = false
	if not Assertions.assert_approx_equal(gard._plots["plot_home_01"]["moisture"], 65.0, 0.01, "T14-02: Kelembapan kebun pulih 65.0"): passed = false
	var spot_data = gard._plots["plot_home_01"]["spots"]["slot_01"]["crop_data"]
	if not Assertions.assert_approx_equal(float(spot_data["growth_time"]), 45.0, 0.01, "T14-02: Waktu tumbuh tanaman tidak lompat"): passed = false

	return passed

# ==============================================================================
# Grup 2: T16 — Validasi Pra-Swap Dunia & Penolakan Snapshot Rusak
# ==============================================================================

func test_t16_01_reject_snapshot_with_missing_mandatory_sections() -> bool:
	var passed := true
	var sm := _create_test_save_manager()

	var valid_payload := sm.capture_all_states()

	# Coba hilangkan section satu per satu
	for missing_sec in ["inventory", "gardening", "world", "cooking", "recipe", "dialogue", "player"]:
		var broken_payload: Dictionary = valid_payload.duplicate(true)
		broken_payload.erase(missing_sec)
		var val_res := sm.validate_save_payload(broken_payload)
		if not Assertions.assert_false(val_res.get("valid", false), "T16-01: Payload tanpa '%s' wajib ditolak" % missing_sec):
			passed = false

	return passed

func test_t16_02_reject_snapshot_with_unknown_item_ids_and_illegal_counts() -> bool:
	var passed := true
	var sm := _create_test_save_manager()

	var payload := sm.capture_all_states()

	# 1. Unknown Item ID
	var broken_payload_1 := payload.duplicate(true)
	broken_payload_1["inventory"]["backpack"][0] = {"item_id": "laser_gun_99", "count": 1}
	var res1 := sm.validate_save_payload(broken_payload_1)
	if not Assertions.assert_false(res1.get("valid", false), "T16-02: ID item fiktif/asing wajib ditolak"): passed = false

	# 2. Illegal count > 20
	var broken_payload_2 := payload.duplicate(true)
	broken_payload_2["inventory"]["backpack"][0] = {"item_id": "seed_bayam", "count": 99}
	var res2 := sm.validate_save_payload(broken_payload_2)
	if not Assertions.assert_false(res2.get("valid", false), "T16-02: Count > 20 wajib ditolak"): passed = false

	# 3. Negative count
	var broken_payload_3 := payload.duplicate(true)
	broken_payload_3["inventory"]["backpack"][0] = {"item_id": "seed_bayam", "count": -5}
	var res3 := sm.validate_save_payload(broken_payload_3)
	if not Assertions.assert_false(res3.get("valid", false), "T16-02: Count negatif wajib ditolak"): passed = false

	return passed

func test_t16_03_atomic_world_swap_all_or_nothing() -> bool:
	var passed := true
	var sm := _create_test_save_manager()
	var inv = sm._get_autoload("InventoryManager")

	sm.delete_slot("manual")

	inv.backpack.clear()
	inv.backpack.add_item("seed_bayam", 2)
	var baseline_count: int = inv.backpack.get_item_count("seed_bayam")

	# Buat berkas simpanan rusak (section dialogue sengaja dihilangkan)
	var payload := sm.capture_all_states()
	payload.erase("dialogue")
	var env := sm.create_envelope("manual", payload)
	var p := sm.get_slot_path("manual")
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify(env))
	f.close()

	# Coba muat berkas rusak
	var load_res := sm.load_game("manual")
	if not Assertions.assert_false(load_res.get("success", false), "T16-03: Load berkas rusak ditolak"): passed = false

	# Pastikan state live inventory sama sekali tidak berubah (zero half-loaded world)
	var post_count: int = inv.backpack.get_item_count("seed_bayam")
	if not Assertions.assert_equal(post_count, baseline_count, "T16-03: Dunia live tidak termutasi sebagian saat validasi gagal"):
		passed = false

	sm.delete_slot("manual")
	return passed

# ==============================================================================
# Grup 3: T17 — Ketahanan Berkas Korup & Fallback Cadangan (.bak)
# ==============================================================================

func test_t17_01_fallback_to_bak_when_primary_save_file_corrupted() -> bool:
	var passed := true
	var sm := _create_test_save_manager()
	var wrm = sm._get_autoload("WorldResourceManager")

	# 1. Simpan save valid ke manual (Revisi 1)
	wrm.current_day = 3
	sm.save_game("manual")

	# 2. Simpan save kedua agar terbentuk .bak yang valid (Revisi 2)
	wrm.current_day = 4
	sm.save_game("manual")

	# 3. Rusakkan berkas utama (save_manual.json) dengan JSON terpotong / byte korup
	var primary_path := sm.get_slot_path("manual")
	var f := FileAccess.open(primary_path, FileAccess.WRITE)
	f.store_string('{"schema_version": 1, "payload": {"corrupted": [unclosed json')
	f.close()

	# Pasang pendengar sinyal
	var recovered_signal_fired := [false]
	var recovered_slot := [""]
	var on_rec := func(slot, _path):
		recovered_signal_fired[0] = true
		recovered_slot[0] = slot
	sm.save_recovered_from_backup.connect(on_rec)

	# 4. Muat save: harus otomatis fallback ke .bak
	var load_res := sm.load_game("manual")
	sm.save_recovered_from_backup.disconnect(on_rec)

	if not Assertions.assert_true(load_res.get("success", false), "T17-01: Muat berhasil via fallback ke .bak"): passed = false
	if not Assertions.assert_true(recovered_signal_fired[0], "T17-01: Sinyal save_recovered_from_backup terpancar"): passed = false
	if not Assertions.assert_equal(recovered_slot[0], "manual", "T17-01: Sinyal memancarkan slot manual"): passed = false

	# 5. Verifikasi self-healing: berkas utama harus pulih kembali dan valid di disk
	var healed_meta := sm.get_slot_metadata("manual")
	if not Assertions.assert_true(healed_meta.get("valid", false), "T17-01: Self-healing memulihkan berkas primary di disk"): passed = false

	sm.delete_slot("manual")
	return passed

func test_t17_02_clean_failure_when_both_primary_and_bak_are_corrupted() -> bool:
	var passed := true
	var sm := _create_test_save_manager()

	var primary_path := sm.get_slot_path("manual")
	var bak_path := primary_path + ".bak"

	# Tulis sampah ke kedua berkas
	var f1 := FileAccess.open(primary_path, FileAccess.WRITE)
	f1.store_string("corrupted garbage 12345")
	f1.close()

	var f2 := FileAccess.open(bak_path, FileAccess.WRITE)
	f2.store_string("corrupted backup garbage 67890")
	f2.close()

	var load_res := sm.load_game("manual")
	if not Assertions.assert_false(load_res.get("success", false), "T17-02: Muat gagal bersih bila primary dan bak rusak"): passed = false
	if not Assertions.assert_true(load_res.has("message"), "T17-02: Memuat pesan kegagalan yang jelas untuk UI"): passed = false

	sm.delete_slot("manual")
	return passed

func test_t17_03_zero_byte_file_resilience() -> bool:
	var passed := true
	var sm := _create_test_save_manager()

	var primary_path := sm.get_slot_path("manual")
	var f := FileAccess.open(primary_path, FileAccess.WRITE)
	f.close() # 0-byte file

	var meta := sm.get_slot_metadata("manual")
	if not Assertions.assert_false(meta.get("valid", false), "T17-03: Berkas 0-byte terdeteksi tidak valid"): passed = false

	var load_res := sm.load_game("manual")
	if not Assertions.assert_false(load_res.get("success", false), "T17-03: Berkas 0-byte ditolak tanpa crash"): passed = false

	sm.delete_slot("manual")
	return passed


# ==============================================================================
# Grup 4: T22 — Validasi Posisi Pemain & Safe Spawn Redirection
# ==============================================================================

func test_t22_01_redirect_nan_and_inf_coordinates_to_safe_spawn() -> bool:
	var passed := true
	var player := PlayerControllerClass.new()
	player.default_safe_return_position = Vector3(0.0, 0.0, 8.0)

	# Varian NaN
	var data_nan := {
		"position": [NAN, 0.0, 8.0],
		"rotation_y": 0.0,
		"camera_pitch": 0.0
	}
	var res_nan := player.load_save_snapshot(data_nan)
	if not Assertions.assert_true(res_nan, "T22-01: Load snapshot NaN berhasil diproses"): passed = false
	if not Assertions.assert_vector3_approx_equal(player.position, Vector3(0.0, 0.0, 8.0), 0.01, "T22-01: NaN dialihkan ke safe return home"): passed = false

	# Varian Inf
	var data_inf := {
		"position": [0.0, INF, 0.0],
		"rotation_y": 0.0,
		"camera_pitch": 0.0
	}
	player.load_save_snapshot(data_inf)
	if not Assertions.assert_vector3_approx_equal(player.position, Vector3(0.0, 0.0, 8.0), 0.01, "T22-01: Inf dialihkan ke safe return home"): passed = false

	player.free()
	return passed

func test_t22_02_redirect_out_of_bounds_coordinates_to_safe_spawn() -> bool:
	var passed := true
	var player := PlayerControllerClass.new()
	player.default_safe_return_position = Vector3(0.0, 0.0, 8.0)

	# Jurang di bawah Y = -5.0
	var data_abyss := {
		"position": [0.0, -100.0, 0.0],
		"rotation_y": 0.0,
		"camera_pitch": 0.0
	}
	player.load_save_snapshot(data_abyss)
	if not Assertions.assert_vector3_approx_equal(player.position, Vector3(0.0, 0.0, 8.0), 0.01, "T22-02: Jurang (Y < -5) dialihkan ke safe return home"): passed = false

	# Di luar batas level X = 500
	var data_oob := {
		"position": [500.0, 0.0, 0.0],
		"rotation_y": 0.0,
		"camera_pitch": 0.0
	}
	player.load_save_snapshot(data_oob)
	if not Assertions.assert_vector3_approx_equal(player.position, Vector3(0.0, 0.0, 8.0), 0.01, "T22-02: Out of bounds X dialihkan ke safe return home"): passed = false

	player.free()
	return passed

func test_t22_03_valid_coordinates_preserved_without_redirection() -> bool:
	var passed := true
	var player := PlayerControllerClass.new()
	player.default_safe_return_position = Vector3(0.0, 0.0, 8.0)

	var valid_pos := Vector3(8.0, 0.0, 7.0)
	var data_valid := {
		"position": [valid_pos.x, valid_pos.y, valid_pos.z],
		"rotation_y": 1.57,
		"camera_pitch": 0.2
	}
	player.load_save_snapshot(data_valid)
	if not Assertions.assert_vector3_approx_equal(player.position, valid_pos, 0.01, "T22-03: Koordinat valid tidak dialihkan"): passed = false
	if not Assertions.assert_approx_equal(player.camera_pitch, 0.2, 0.01, "T22-03: Pitch kamera pulih"): passed = false

	player.free()
	return passed

# ==============================================================================
# Grup 5: T46 — Pemulihan Status Dinamis Kebun dan Dapur
# ==============================================================================

func test_t46_01_garden_plot_and_crop_stages_restoration() -> bool:
	var passed := true
	var sm := _create_test_save_manager()
	var gard = sm._get_autoload("GardenManager")

	# Setup 4 spot berbeda tahap
	gard._plots["plot_home_01"]["is_hoed"] = true
	gard._plots["plot_home_01"]["has_compost"] = true
	gard._plots["plot_home_01"]["moisture"] = 52.3
	gard._plots["plot_home_01"]["nutrients"] = 77.8

	gard._plots["plot_home_01"]["spots"]["slot_01"]["is_occupied"] = false
	gard._plots["plot_home_01"]["spots"]["slot_01"]["crop_data"] = null

	gard._plots["plot_home_01"]["spots"]["slot_02"]["is_occupied"] = true
	gard._plots["plot_home_01"]["spots"]["slot_02"]["crop_data"] = {
		"crop_id": "crop_bayam", "growth_time": 15.0, "growth_stage": 0, "is_ready_to_harvest": false, "is_stalled": false, "stall_reason": ""
	}

	gard._plots["plot_home_01"]["spots"]["slot_03"]["is_occupied"] = true
	gard._plots["plot_home_01"]["spots"]["slot_03"]["crop_data"] = {
		"crop_id": "crop_bayam", "growth_time": 50.0, "growth_stage": 1, "is_ready_to_harvest": false, "is_stalled": false, "stall_reason": ""
	}

	gard._plots["plot_home_01"]["spots"]["slot_04"]["is_occupied"] = true
	gard._plots["plot_home_01"]["spots"]["slot_04"]["crop_data"] = {
		"crop_id": "crop_bayam", "growth_time": 180.0, "growth_stage": 3, "is_ready_to_harvest": true, "is_stalled": false, "stall_reason": ""
	}

	sm.save_game("manual")

	# Bersihkan kebun
	gard.reset_to_defaults()

	# Muat kembali
	sm.load_game("manual")

	if not Assertions.assert_approx_equal(gard._plots["plot_home_01"]["moisture"], 52.3, 0.01, "T46-01: Kelembapan petak pulih 52.3"): passed = false
	if not Assertions.assert_approx_equal(gard._plots["plot_home_01"]["nutrients"], 77.8, 0.01, "T46-01: Nutrisi petak pulih 77.8"): passed = false
	if not Assertions.assert_false(gard._plots["plot_home_01"]["spots"]["slot_01"]["is_occupied"], "T46-01: Slot 1 kosong"): passed = false
	if not Assertions.assert_true(gard._plots["plot_home_01"]["spots"]["slot_04"]["crop_data"]["is_ready_to_harvest"], "T46-01: Slot 4 siap panen"): passed = false

	return passed

func test_t46_02_kitchen_job_reservation_origin_and_refund_restoration() -> bool:
	var passed := true
	var sm := _create_test_save_manager()
	var kit = sm._get_autoload("KitchenManager")

	kit.job_state = 5 # OUTPUT_READY
	kit.active_job_id = "job_acceptance_001"
	kit.active_recipe_id = "recipe_sayur_bening_01"
	kit.dish_output_slot = {"item_id": "dish_sayur_bening", "count": 1}
	kit.origin_manifest.clear()
	kit.origin_manifest.append({"container": "backpack", "item_id": "ingredient_bayam", "count": 3})


	sm.save_game("manual")

	kit.job_state = 0 # IDLE
	kit.dish_output_slot.clear()
	kit.origin_manifest.clear()
	sm.load_game("manual")

	if not Assertions.assert_equal(int(kit.job_state), 5, "T46-02: Status job OUTPUT_READY pulih"): passed = false
	if not Assertions.assert_equal(str(kit.dish_output_slot.get("item_id")), "dish_sayur_bening", "T46-02: Hidangan di output slot utuh"): passed = false
	if not Assertions.assert_equal(kit.origin_manifest.size(), 1, "T46-02: Origin manifest utuh"): passed = false

	return passed

# ==============================================================================
# Grup 6: T47 — Uji Ketahanan Crash Penulisan Atomik via .tmp
# ==============================================================================

func test_t47_01_atomic_write_creates_tmp_before_target() -> bool:
	var passed := true
	var sm := _create_test_save_manager()

	var target_path := sm.get_slot_path("manual")
	var tmp_path := target_path + ".tmp"

	sm.save_game("manual")

	if not Assertions.assert_true(FileAccess.file_exists(target_path), "T47-01: Berkas target utama ada pasca-save"): passed = false
	if not Assertions.assert_false(FileAccess.file_exists(tmp_path), "T47-01: Berkas .tmp telah di-rename (tidak tersisa .tmp)"): passed = false

	return passed

func test_t47_02_existing_save_unharmed_if_write_fails_midway() -> bool:
	var passed := true
	var sm := _create_test_save_manager()
	var wrm = sm._get_autoload("WorldResourceManager")

	# Save revisi 1
	wrm.current_day = 1
	sm.save_game("manual")
	var meta1 := sm.get_slot_metadata("manual")
	var rev1: int = int(meta1["revision"])

	# Coba simpan saat write failure hook aktif (T49)
	sm.simulate_write_failure = true
	wrm.current_day = 5
	var fail_res := sm.save_game("manual")
	sm.simulate_write_failure = false

	if not Assertions.assert_false(fail_res.get("success", false), "T47-02: Save gagal saat simulasi write failure"): passed = false

	# Verifikasi berkas di disk tidak rusak dan tetap menyimpan revisi 1
	var meta2 := sm.get_slot_metadata("manual")
	if not Assertions.assert_true(meta2.get("valid", false), "T47-02: Berkas lama tetap valid"): passed = false
	if not Assertions.assert_equal(int(meta2.get("revision")), rev1, "T47-02: Revisi lama tidak rusak"): passed = false

	return passed

func test_t47_03_temp_file_cleanup_on_failure() -> bool:
	var passed := true
	var sm := _create_test_save_manager()

	sm.simulate_write_failure = true
	sm.save_game("manual")
	sm.simulate_write_failure = false

	var tmp_path := sm.get_slot_path("manual") + ".tmp"
	if not Assertions.assert_false(FileAccess.file_exists(tmp_path), "T47-03: Berkas .tmp tidak ditinggalkan saat gagal"): passed = false

	return passed

# ==============================================================================
# Grup 7: T48 — Manajemen Slot Manual, Autosave, dan Cadangan
# ==============================================================================

func test_t48_01_separate_manual_and_autosave_slot_isolation() -> bool:
	var passed := true
	var sm := _create_test_save_manager()
	var wrm = sm._get_autoload("WorldResourceManager")

	# Simpan manual di Hari 1
	wrm.current_day = 1
	sm.save_game("manual")

	# Simpan autosave di Hari 2
	wrm.current_day = 2
	sm.save_game("autosave")

	var man_path := sm.get_slot_path("manual")
	var auto_path := sm.get_slot_path("autosave")

	if not Assertions.assert_ne(man_path, auto_path, "T48-01: Jalur slot manual dan autosave berbeda"): passed = false

	var man_env: Dictionary = sm.read_and_validate_envelope(man_path)["envelope"]
	var auto_env: Dictionary = sm.read_and_validate_envelope(auto_path)["envelope"]

	if not Assertions.assert_equal(int(man_env["payload"]["world"]["current_day"]), 1, "T48-01: Manual slot menyimpan Hari 1"): passed = false
	if not Assertions.assert_equal(int(auto_env["payload"]["world"]["current_day"]), 2, "T48-01: Autosave slot menyimpan Hari 2"): passed = false

	return passed

func test_t48_02_continue_selects_newest_revision_across_slots() -> bool:
	var passed := true
	var sm := _create_test_save_manager()
	sm.delete_slot("manual")
	sm.delete_slot("autosave")

	# 1. Manual rev 1
	sm.save_game("manual")
	if not Assertions.assert_equal(sm.get_continue_slot(), "manual", "T48-02: Continue memilih manual saat hanya manual ada"): passed = false

	# 2. Autosave rev 2
	sm.save_game("autosave")
	if not Assertions.assert_equal(sm.get_continue_slot(), "autosave", "T48-02: Continue memilih autosave karena revisi lebih baru"): passed = false

	# 3. Manual rev 3
	sm.save_game("manual")
	if not Assertions.assert_equal(sm.get_continue_slot(), "manual", "T48-02: Continue beralih ke manual karena revisi lebih baru"): passed = false

	return passed

func test_t48_03_explicit_manual_slot_selection_when_autosave_is_newer() -> bool:
	var passed := true
	var sm := _create_test_save_manager()
	var wrm = sm._get_autoload("WorldResourceManager")

	wrm.current_day = 10
	sm.save_game("manual")

	wrm.current_day = 20
	sm.save_game("autosave")

	# Pemain secara eksplisit memilih "manual" di menu Load
	wrm.current_day = 0
	sm.load_game("manual")

	if not Assertions.assert_equal(wrm.current_day, 10, "T48-03: Pemanggilan manual memuat Hari 10 bukan Hari 20"): passed = false

	return passed

func test_t48_04_backup_creation_on_every_successful_overwrite() -> bool:
	var passed := true
	var sm := _create_test_save_manager()

	sm.save_game("manual")
	var bak_path := sm.get_slot_path("manual") + ".bak"

	# Simpan kedua kali
	sm.save_game("manual")
	if not Assertions.assert_true(FileAccess.file_exists(bak_path), "T48-04: Berkas .bak tercipta saat overwrite"): passed = false

	return passed

# ==============================================================================
# Grup 8: T49 — Isolasi Pengaturan (settings.cfg) dari Save Game
# ==============================================================================

func test_t49_01_settings_stored_in_standalone_config_file() -> bool:
	var passed := true
	var sm := _create_test_save_manager()

	var cfg := ConfigFile.new()
	var err := cfg.load(SANDBOX_SETTINGS_PATH)
	if not Assertions.assert_equal(err, OK, "T49-01: settings.cfg ada dan terbaca via ConfigFile"): passed = false

	# Verifikasi nilai default per CONTENT § 14
	var fov: float = float(cfg.get_value("video", "fov", 0.0))
	var sens: float = float(cfg.get_value("gameplay", "mouse_sensitivity_multiplier", 0.0))
	var vol_master: float = float(cfg.get_value("audio", "master_volume", 0.0))
	var subtitles: bool = bool(cfg.get_value("accessibility", "subtitles", false))

	if not Assertions.assert_approx_equal(fov, 80.0, 0.01, "T49-01: Default FOV 80"): passed = false
	if not Assertions.assert_approx_equal(sens, 1.0, 0.01, "T49-01: Default sensitivitas 1.0"): passed = false
	if not Assertions.assert_approx_equal(vol_master, 0.7, 0.01, "T49-01: Default master volume 0.7"): passed = false
	if not Assertions.assert_true(subtitles, "T49-01: Default subtitles true"): passed = false

	return passed

func test_t49_02_game_load_and_new_game_preserves_settings() -> bool:
	var passed := true
	var sm := _create_test_save_manager()

	# Kustomisasi pengaturan
	var custom_settings := sm.get_default_settings()
	custom_settings["video"]["fov"] = 95.0
	custom_settings["gameplay"]["mouse_sensitivity_multiplier"] = 1.4
	custom_settings["audio"]["master_volume"] = 0.5
	sm.save_settings(custom_settings)

	# Simpan dan Muat game
	sm.save_game("manual")
	sm.load_game("manual")

	# Pastikan pengaturan tidak tertimpa oleh load game
	var active_fov: float = float(sm.get_setting("video", "fov", 0.0))
	var active_sens: float = float(sm.get_setting("gameplay", "mouse_sensitivity_multiplier", 0.0))
	var active_vol: float = float(sm.get_setting("audio", "master_volume", 0.0))

	if not Assertions.assert_approx_equal(active_fov, 95.0, 0.01, "T49-02: FOV 95 tidak tertimpa load game"): passed = false
	if not Assertions.assert_approx_equal(active_sens, 1.4, 0.01, "T49-02: Sensitivitas 1.4 tidak tertimpa load game"): passed = false
	if not Assertions.assert_approx_equal(active_vol, 0.5, 0.01, "T49-02: Volume 0.5 tidak tertimpa load game"): passed = false

	return passed

func test_t49_03_settings_corruption_does_not_affect_save_game() -> bool:
	var passed := true
	var sm := _create_test_save_manager()

	sm.save_game("manual")

	# Rusakkan settings.cfg
	var f := FileAccess.open(SANDBOX_SETTINGS_PATH, FileAccess.WRITE)
	f.store_string("corrupted [not a valid config] &&&&")
	f.close()

	# Muat pengaturan kembali: harus pulih ke default
	var settings = sm.load_settings()
	if not Assertions.assert_not_null(settings, "T49-03: Pengaturan pulih ke default"): passed = false

	# Save game tetap utuh dan valid
	var meta := sm.get_slot_metadata("manual")
	if not Assertions.assert_true(meta.get("valid", false), "T49-03: Kerusakan settings tidak merusak save game"): passed = false

	return passed

# ==============================================================================
# Grup 9: T50 — Round-Trip Save/Load 100% Identik & Idempotensi
# ==============================================================================

func test_t50_01_comprehensive_p0_game_state_roundtrip() -> bool:
	var passed := true
	var sm := _create_test_save_manager()

	var inv = sm._get_autoload("InventoryManager")
	var rm = sm._get_autoload("RecipeManager")
	var gard = sm._get_autoload("GardenManager")
	var wr = sm._get_autoload("WorldResourceManager")
	var kit = sm._get_autoload("KitchenManager")
	var dia = sm._get_autoload("DialogueManager")

	# Setup P0 Comprehensive State
	inv.backpack.clear()
	inv.backpack.add_item("seed_bayam", 4)
	inv.backpack.add_item("ingredient_jagung", 2)
	inv.storage_home.clear()
	inv.storage_home.add_item("ingredient_temu_kunci", 3)

	rm.tracked_recipe_id = "recipe_sayur_bening_01"
	if rm._recipes.has("recipe_sayur_bening_01"):
		rm._recipes["recipe_sayur_bening_01"].times_cooked = 1

	gard.active_tool = "tool_hoe"
	gard.watering_can_water = 8
	gard._plots["plot_home_01"]["moisture"] = 75.0
	gard._plots["plot_home_01"]["nutrients"] = 90.0

	wr.current_day = 3
	wr.meal_used = true

	kit.job_state = 0 # IDLE
	kit.active_recipe_id = "recipe_sayur_bening_01"

	dia.has_spoken_intro = true
	dia._has_shared_meal = true
	dia.meal_used = true
	dia.p0_completed = true

	# Capture Snapshot A
	var snap_a := sm.capture_all_states()

	# Save
	sm.save_game("manual")

	# Scramble State
	inv.backpack.clear()
	gard.watering_can_water = 0
	wr.current_day = 1
	wr.meal_used = false
	dia.p0_completed = false

	# Load
	sm.load_game("manual")

	# Capture Snapshot B
	var snap_b := sm.capture_all_states()

	# Perbandingan
	if not Assertions.assert_equal(snap_b["inventory"]["backpack"], snap_a["inventory"]["backpack"], "T50-01: Backpack round-trip identik"): passed = false
	if not Assertions.assert_equal(snap_b["inventory"]["storage_home"], snap_a["inventory"]["storage_home"], "T50-01: Storage round-trip identik"): passed = false
	if not Assertions.assert_equal(snap_b["recipe"]["tracked_recipe_id"], snap_a["recipe"]["tracked_recipe_id"], "T50-01: Recipe tracked round-trip identik"): passed = false
	if not Assertions.assert_equal(snap_b["gardening"]["watering_can_water"], snap_a["gardening"]["watering_can_water"], "T50-01: Watering can round-trip identik"): passed = false
	if not Assertions.assert_equal(int(snap_b["world"]["current_day"]), int(snap_a["world"]["current_day"]), "T50-01: World day round-trip identik"): passed = false
	if not Assertions.assert_equal(snap_b["dialogue"]["p0_completed"], snap_a["dialogue"]["p0_completed"], "T50-01: P0 completion round-trip identik"): passed = false

	return passed

func test_t50_02_idempotent_multi_roundtrip() -> bool:
	var passed := true
	var sm := _create_test_save_manager()

	# Siklus 1: Save & Load
	sm.save_game("manual")
	var snap1 := sm.capture_all_states()

	sm.load_game("manual")
	var snap2 := sm.capture_all_states()

	# Siklus 2: Save & Load lagi
	sm.save_game("manual")
	sm.load_game("manual")
	var snap3 := sm.capture_all_states()

	var str1 := JSON.stringify(snap1)
	var str2 := JSON.stringify(snap2)
	var str3 := JSON.stringify(snap3)

	if not Assertions.assert_equal(str2, str1, "T50-02: Zero drift pada siklus 1 load"): passed = false
	if not Assertions.assert_equal(str3, str1, "T50-02: Zero drift pada siklus 2 save/load multi-iterasi"): passed = false

	return passed
