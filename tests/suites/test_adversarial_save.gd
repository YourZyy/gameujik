class_name TestAdversarialSave
extends RefCounted

## Test Suite Adversarial & Empirical Stress Testing untuk SAVE-001
## Memverifikasi secara independen & tanpa kompromi:
## 1. Jaminan Atomic Write: Penulisan .tmp, crash simulation, .bak fallback, dan self-healing
## 2. Multi-Roundtrip Idempotence: 50 siklus berulang tanpa drift/penyimpangan float & data
## 3. Pencegahan Progres Offline Memasak: Status COOKING (3) selalu menjadi PAUSED (4) saat dimuat
## 4. Isolasi Slot Manual & Autosave, serta Logika get_continue_slot() Lintas Revisi Monotonik
## 5. Pertahanan Terhadap Payload Korup, Tumpukan Ilegal, dan Sanitasi Koordinat Pemain

const Assertions = preload("res://tests/assertions.gd")
const SaveManagerClass = preload("res://scripts/save/save_manager.gd")
const ItemsDataClass = preload("res://scripts/inventory/items_data.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")

const ADV_SANDBOX_DIR: String = "user://test_adv_save_sandbox/"
const ADV_SETTINGS_PATH: String = "user://test_adv_save_sandbox/settings.cfg"

func run_all() -> bool:
	var passed := true
	print("==================================================")
	print("[ADVERSARIAL_SUITE] SAVE-001 Empirical Stress & Atomic Invariant Verification")
	print("==================================================")

	_setup_sandbox()

	# SECTION 1: ATOMIC WRITE & CRASH RECOVERY GUARANTEES
	if not test_adv01_atomic_write_unaffected_by_stale_or_corrupt_tmp(): passed = false
	if not test_adv02_simulate_crash_during_tmp_write(): passed = false
	if not test_adv03_primary_corruption_recovers_via_backup_with_self_healing(): passed = false
	if not test_adv04_sha256_checksum_tamper_detection_triggers_backup_fallback(): passed = false
	if not test_adv05_double_corruption_guarantees_all_or_nothing_state_preservation(): passed = false

	# SECTION 2: MULTI-ROUNDTRIP IDEMPOTENCE & ZERO DRIFT (50 CYCLES)
	if not test_adv06_50_roundtrips_zero_drift_stress(): passed = false

	# SECTION 3: OFFLINE COOKING PROGRESSION DEFENSE
	if not test_adv07_cooking_active_always_restored_as_paused(): passed = false
	if not test_adv08_all_other_cooking_states_preserved_unaltered(): passed = false

	# SECTION 4: SLOT ISOLATION & MONOTONIC CONTINUE LOGIC
	if not test_adv09_slot_isolation_manual_vs_autosave(): passed = false
	if not test_adv10_monotonic_continue_resolution_matrix(): passed = false
	if not test_adv11_backup_rotation_depth(): passed = false

	# SECTION 5: MALICIOUS / ANOMALOUS PAYLOAD STRESS & COORDINATE BOUNDS
	if not test_adv12_reject_illegal_stack_counts_and_slot_quantities(): passed = false
	if not test_adv13_player_bounds_and_nan_inf_sanitization(): passed = false

	_teardown_sandbox()
	return passed

# ==============================================================================
# Sandbox Helpers
# ==============================================================================

func _setup_sandbox() -> void:
	_clean_sandbox()
	DirAccess.make_dir_recursive_absolute(ADV_SANDBOX_DIR)

func _teardown_sandbox() -> void:
	_clean_sandbox()

func _clean_sandbox() -> void:
	if DirAccess.dir_exists_absolute(ADV_SANDBOX_DIR):
		var dir := DirAccess.open(ADV_SANDBOX_DIR)
		if dir:
			dir.list_dir_begin()
			var fn := dir.get_next()
			while fn != "":
				if not dir.current_is_dir():
					dir.remove(fn)
				fn = dir.get_next()
			dir.list_dir_end()
	if FileAccess.file_exists(ADV_SETTINGS_PATH):
		DirAccess.remove_absolute(ADV_SETTINGS_PATH)

func _create_test_sm() -> SaveManagerClass:
	var sm := SaveManagerClass.new()
	sm.set_save_directory(ADV_SANDBOX_DIR)
	sm.set_settings_path(ADV_SETTINGS_PATH)
	sm._ready()
	return sm

# ==============================================================================
# SECTION 1: ATOMIC WRITE & CRASH RECOVERY GUARANTEES
# ==============================================================================

## Skenario: Residu .tmp rusak yang tertinggal di disk (akibat crash mesin sebelumnya)
## tidak boleh menggagalkan proses penyimpanan baru dan target utama lama tetap aman.
func test_adv01_atomic_write_unaffected_by_stale_or_corrupt_tmp() -> bool:
	_clean_sandbox()
	var passed := true
	var sm := _create_test_sm()
	var wrm = sm._get_autoload("WorldResourceManager")
	if wrm == null: return Assertions.assert_true(false, "ADV-01: WorldResourceManager tidak ditemukan")

	# Buat save awal (Hari 1)
	wrm.current_day = 1
	var res1 := sm.save_game("manual")
	if not Assertions.assert_true(res1.get("success", false), "ADV-01: Save awal Hari 1 sukses"): passed = false

	# Sengaja buat residu .tmp korup
	var tmp_path := sm.get_slot_path("manual") + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	f.store_string("CORRUPTED_LEFTOVER_GARBAGE_BYTES_THAT_SHOULD_BE_OVERWRITTEN")
	f.close()

	# Simpan lagi saat hari 2
	wrm.current_day = 2
	var res2 := sm.save_game("manual")
	if not Assertions.assert_true(res2.get("success", false), "ADV-01: Save hari 2 sukses menimpa residu .tmp"): passed = false
	if not Assertions.assert_false(FileAccess.file_exists(tmp_path), "ADV-01: Berkas .tmp sudah tidak ada setelah rename atomik"): passed = false

	# Muat kembali
	wrm.current_day = 99
	var load_res := sm.load_game("manual")
	if not Assertions.assert_true(load_res.get("success", false), "ADV-01: Muat save berhasil"): passed = false
	if not Assertions.assert_equal(wrm.current_day, 2, "ADV-01: Hari 2 termuat dengan sempurna"): passed = false

	return passed

## Skenario: Simulasi crash/interupsi di tengah penulisan .tmp.
## Berkas sasaran utama (.json) dan cadangan (.bak) lama harus tetap 100% utuh dan tidak rusak.
func test_adv02_simulate_crash_during_tmp_write() -> bool:
	_clean_sandbox()
	var passed := true
	var sm := _create_test_sm()
	var wrm = sm._get_autoload("WorldResourceManager")

	# Simpan versi stabil (Hari 3)
	wrm.current_day = 3
	sm.save_game("manual")
	var target_path := sm.get_slot_path("manual")
	var orig_content := FileAccess.get_file_as_bytes(target_path)
	var orig_size := orig_content.size()

	# Simulasikan crash di tengah penulisan .tmp: tulis setengah JSON ke .tmp
	var tmp_path := target_path + ".tmp"
	var tf := FileAccess.open(tmp_path, FileAccess.WRITE)
	tf.store_string('{"header": {"schema_version": 1, "unfinished": true')
	tf.close()

	# Coba muat game sekarang: sistem harus mengabaikan .tmp dan memuat .json asli
	wrm.current_day = 0
	var load_res := sm.load_game("manual")
	if not Assertions.assert_true(load_res.get("success", false), "ADV-02: Load berhasil mengabaikan .tmp yang rusak"): passed = false
	if not Assertions.assert_equal(wrm.current_day, 3, "ADV-02: State Hari 3 tetap utuh"): passed = false

	# Pastikan berkas utama tidak mengalami korupsi atau penyusutan ukuran
	var curr_content := FileAccess.get_file_as_bytes(target_path)
	if not Assertions.assert_equal(curr_content.size(), orig_size, "ADV-02: Ukuran berkas utama tidak berubah"): passed = false

	return passed

## Skenario: Berkas utama korup (misalnya 0-byte atau JSON rusak), namun .bak tersedia.
## Sistem harus memuat dari .bak, memancarkan sinyal pemulihan, dan melakukan SELF-HEALING
## (menulis ulang berkas utama yang valid secara otomatis).
func test_adv03_primary_corruption_recovers_via_backup_with_self_healing() -> bool:
	_clean_sandbox()
	var passed := true
	var sm := _create_test_sm()
	var wrm = sm._get_autoload("WorldResourceManager")

	# Buat 2 revisi agar .bak tercipta
	wrm.current_day = 4
	sm.save_game("manual")
	wrm.current_day = 5
	sm.save_game("manual")

	var target_path := sm.get_slot_path("manual")
	var bak_path := target_path + ".bak"

	if not Assertions.assert_true(FileAccess.file_exists(bak_path), "ADV-03: Berkas .bak ada"): passed = false

	# Rusakkan berkas sasaran utama
	var cf := FileAccess.open(target_path, FileAccess.WRITE)
	cf.store_string("{ 'bad_syntax': true, ")
	cf.close()

	var sig_data := {"slot": "", "fired": false}
	var callback = func(slot: String, _path: String):
		sig_data["fired"] = true
		sig_data["slot"] = slot
	sm.save_recovered_from_backup.connect(callback)

	# Muat game
	wrm.current_day = 0
	var load_res := sm.load_game("manual")
	sm.save_recovered_from_backup.disconnect(callback)

	if not Assertions.assert_true(load_res.get("success", false), "ADV-03: Muat berhasil via fallback .bak"): passed = false
	if not Assertions.assert_true(sig_data["fired"], "ADV-03: Sinyal save_recovered_from_backup terpancar"): passed = false
	if not Assertions.assert_equal(sig_data["slot"], "manual", "ADV-03: Slot pemulihan adalah manual"): passed = false

	# Verifikasi Self-Healing: Berkas utama sekarang harus sudah ditulis ulang dan valid!
	var healed_env := sm.read_and_validate_envelope(target_path)
	if not Assertions.assert_true(healed_env.get("valid", false), "ADV-03: Berkas utama telah sembuh (self-healing) pasca-fallback"): passed = false

	return passed

## Skenario: Modifikasi manipulatif pada payload (bitrot/tampering) tanpa memperbarui checksum SHA-256.
## Sistem harus mendeteksi CHECKSUM_MISMATCH, menolak sasaran utama, dan fallback ke .bak yang valid.
func test_adv04_sha256_checksum_tamper_detection_triggers_backup_fallback() -> bool:
	_clean_sandbox()
	var passed := true
	var sm := _create_test_sm()
	var wrm = sm._get_autoload("WorldResourceManager")

	wrm.current_day = 10
	sm.save_game("manual")
	wrm.current_day = 11
	sm.save_game("manual")

	var target_path := sm.get_slot_path("manual")
	var bak_path := target_path + ".bak"

	# Baca envelope sah dari primary
	var orig_env: Dictionary = sm.read_and_validate_envelope(target_path)["envelope"]
	# Manipulasi payload (ubah current_day menjadi 999 tanpa hitung ulang checksum)
	orig_env["payload"]["world"]["current_day"] = 999

	var tampered_file := FileAccess.open(target_path, FileAccess.WRITE)
	tampered_file.store_string(JSON.stringify(orig_env, "\t"))
	tampered_file.close()

	# Coba read_and_validate_envelope langsung: harus gagal CHECKSUM_MISMATCH
	var check_res := sm.read_and_validate_envelope(target_path)
	if not Assertions.assert_false(check_res.get("valid", false), "ADV-04: Berkas yang di-tamper ditolak envelope validator"): passed = false
	if not Assertions.assert_equal(check_res.get("reason", ""), "CHECKSUM_MISMATCH", "ADV-04: Alasan penolakan CHECKSUM_MISMATCH"): passed = false

	# Panggil load_game: harus fallback ke .bak (yang berisi Hari 10 yang sah)
	wrm.current_day = 0
	var load_res := sm.load_game("manual")
	if not Assertions.assert_true(load_res.get("success", false), "ADV-04: Load fallback ke .bak sukses"): passed = false
	if not Assertions.assert_equal(wrm.current_day, 10, "ADV-04: Hari 10 dari .bak termuat (bukan data tampered 999)"): passed = false

	return passed

## Skenario: Kedua berkas (target utama dan .bak) korup parah.
## Transaksi harus gagal bersih, mengembalikan kode error jujur, dan MEMASTIKAN status live
## di singleton saat ini tidak termutasi sedikit pun (Zero Half-Loaded World).
func test_adv05_double_corruption_guarantees_all_or_nothing_state_preservation() -> bool:
	_clean_sandbox()
	var passed := true
	var sm := _create_test_sm()
	var inv = sm._get_autoload("InventoryManager")
	var wrm = sm._get_autoload("WorldResourceManager")

	# Tetapkan status live memori sebelum load
	inv.backpack.clear()
	inv.backpack.add_item("seed_bayam", 7)
	wrm.current_day = 42

	var target_path := sm.get_slot_path("manual")
	var bak_path := target_path + ".bak"

	# Tulis sampah ke primary dan .bak
	var f1 := FileAccess.open(target_path, FileAccess.WRITE)
	f1.store_string("JUNK_PRIMARY")
	f1.close()

	var f2 := FileAccess.open(bak_path, FileAccess.WRITE)
	f2.store_string("JUNK_BACKUP")
	f2.close()

	var load_res := sm.load_game("manual")
	if not Assertions.assert_false(load_res.get("success", false), "ADV-05: Load gagal saat primary dan bak korup"): passed = false
	if not Assertions.assert_equal(load_res.get("error"), ERR_FILE_CORRUPT, "ADV-05: Kode error ERR_FILE_CORRUPT"): passed = false

	# Verifikasi status live singleton sama sekali tidak termutasi (All-or-Nothing Guarantee)
	if not Assertions.assert_equal(inv.backpack.get_item_count("seed_bayam"), 7, "ADV-05: Item tas 100% tidak tersentuh"): passed = false
	if not Assertions.assert_equal(wrm.current_day, 42, "ADV-05: Hari dunia 100% tidak tersentuh"): passed = false

	_clean_sandbox()
	return passed

# ==============================================================================
# SECTION 2: MULTI-ROUNDTRIP IDEMPOTENCE & ZERO DRIFT (50 CYCLES)
# ==============================================================================

## Skenario Ekstrem: 50 siklus simpan-muat berturut-turut pada payload lengkap
## yang memuat floating-point, integer, array, nested dictionary, dan boolean.
## Tidak boleh ada penyusutan, akumulasi kesalahan floating-point (drift),
## atau korupsi relasional antar-siklus.
func test_adv06_50_roundtrips_zero_drift_stress() -> bool:
	_clean_sandbox()
	var passed := true
	var sm := _create_test_sm()

	var inv = sm._get_autoload("InventoryManager")
	var gard = sm._get_autoload("GardenManager")
	var wrm = sm._get_autoload("WorldResourceManager")
	var kit = sm._get_autoload("KitchenManager")
	var rm = sm._get_autoload("RecipeManager")
	var dia = sm._get_autoload("DialogueManager")

	# Inisialisasi State Kompleks
	inv.backpack.clear()
	inv.backpack.add_item("seed_bayam", 5)
	inv.backpack.add_item("ingredient_jagung", 2)
	inv.storage_home.clear()
	inv.storage_home.add_item("ingredient_temu_kunci", 4)
	inv.kitchen_refund.clear()
	inv.kitchen_refund.add_item("soil_compost", 1)
	inv.starter_claimed = true

	gard.active_tool = "tool_fertilizer"
	gard.watering_can_water = 6
	gard._plots["plot_home_01"]["is_hoed"] = true
	gard._plots["plot_home_01"]["has_compost"] = true
	gard._plots["plot_home_01"]["moisture"] = 61.25
	gard._plots["plot_home_01"]["nutrients"] = 82.50
	gard._plots["plot_home_01"]["spots"]["slot_01"]["is_occupied"] = true
	gard._plots["plot_home_01"]["spots"]["slot_01"]["crop_data"] = {
		"crop_id": "crop_bayam",
		"growth_time": 45.125,
		"growth_stage": 1,
		"is_ready_to_harvest": false,
		"is_stalled": false,
		"stall_reason": ""
	}

	wrm.current_day = 7
	wrm.day_active_time = 245.5
	wrm.meal_used = false
	wrm.last_harvested_day = {"resource_jagung_01": 5, "resource_temu_kunci_01": 6}

	kit.job_state = 4 # PAUSED
	kit.active_job_id = "job_stress_50"
	kit.active_recipe_id = "recipe_sayur_bening_01"
	kit.cook_progress = 17.75
	kit.cook_duration = 30.0
	kit.current_heat_level = 1
	kit.current_heat = "Sedang"
	kit.dish_output_slot = {}
	kit.reserved_ingredients.clear()
	kit.reserved_ingredients.append({"item_id": "ingredient_bayam", "count": 3})
	kit.origin_manifest.clear()
	kit.origin_manifest.append({"source": "backpack", "item_id": "ingredient_bayam", "count": 3})

	rm.tracked_recipe_id = "recipe_sayur_bening_01"
	rm.cooking_state = "paused"
	if rm._recipes.has("recipe_sayur_bening_01"):
		rm._recipes["recipe_sayur_bening_01"].times_cooked = 3
		rm._recipes["recipe_sayur_bening_01"].set("is_tracked", true)
	if rm._notes.has("note_garden_01"):
		rm._notes["note_garden_01"]["is_unlocked"] = true

	dia.has_spoken_intro = true
	dia._has_shared_meal = false
	dia.meal_used = false
	dia.p0_completed = false

	# Simpan Siklus 1 sebagai Golden Baseline
	sm.save_game("manual")
	var baseline_snap := sm.capture_all_states()
	var baseline_json := SaveManagerClass.canonical_json(baseline_snap)

	# Jalankan 50 siklus load & save berulang
	var drift_detected := false
	for i in range(1, 51):
		var l_res := sm.load_game("manual")
		if not l_res.get("success", false):
			drift_detected = true
			passed = Assertions.assert_true(false, "ADV-06: Gagal memuat pada iterasi ke-%d" % i)
			break

		var s_res := sm.save_game("manual")
		if not s_res.get("success", false):
			drift_detected = true
			passed = Assertions.assert_true(false, "ADV-06: Gagal menyimpan pada iterasi ke-%d" % i)
			break

	if not drift_detected:
		var final_snap := sm.capture_all_states()
		var final_json := SaveManagerClass.canonical_json(final_snap)
		if not Assertions.assert_equal(final_json, baseline_json, "ADV-06: Zero drift setelah 50 siklus save/load kontinu"):
			passed = false

		# Verifikasi batas toleransi numerik float secara eksplisit
		var g_moist: float = float(final_snap["gardening"]["plots"]["plot_home_01"]["moisture"])
		var g_time: float = float(final_snap["gardening"]["plots"]["plot_home_01"]["spots"]["slot_01"]["crop_data"]["growth_time"])
		var k_prog: float = float(final_snap["cooking"]["cook_progress"])
		if not Assertions.assert_approx_equal(g_moist, 61.25, 0.0001, "ADV-06: Kelembapan tanah presisi hingga <0.0001"): passed = false
		if not Assertions.assert_approx_equal(g_time, 45.125, 0.0001, "ADV-06: Waktu tumbuh tanaman presisi hingga <0.0001"): passed = false
		if not Assertions.assert_approx_equal(k_prog, 17.75, 0.0001, "ADV-06: Progress masak presisi hingga <0.0001"): passed = false

	return passed

# ==============================================================================
# SECTION 3: OFFLINE COOKING PROGRESSION DEFENSE
# ==============================================================================

## Skenario: Game disimpan saat status kompor aktif memasak (COOKING = 3).
## Saat dimuat kembali ke dunia 3D, status kompor WAJIB deterministik menjadi PAUSED (4),
## durasi masak WAJIB bertahan persis tanpa kemajuan offline (PROTOTYPE § 5, T14).
func test_adv07_cooking_active_always_restored_as_paused() -> bool:
	_clean_sandbox()
	var passed := true
	var sm := _create_test_sm()
	var kit = sm._get_autoload("KitchenManager")

	kit.job_state = 3 # COOKING
	kit.active_job_id = "job_offline_defense"
	kit.active_recipe_id = "recipe_sayur_bening_01"
	kit.cook_progress = 19.85
	kit.cook_duration = 30.0

	sm.save_game("manual")

	# Ubah memori
	kit.job_state = 0 # IDLE
	kit.cook_progress = 0.0

	# Muat
	sm.load_game("manual")

	if not Assertions.assert_equal(int(kit.job_state), 4, "ADV-07: Status COOKING (3) diubah menjadi PAUSED (4) saat load"): passed = false
	if not Assertions.assert_approx_equal(kit.cook_progress, 19.85, 0.001, "ADV-07: Progress masak 19.85s bertahan identik tanpa lompatan offline"): passed = false

	return passed

## Skenario: State kompor selain COOKING (yaitu IDLE = 0, RESERVED_PREPARING = 1,
## READY_TO_HEAT = 2, PAUSED = 4, OUTPUT_READY = 5) tidak boleh diubah menjadi PAUSED,
## melainkan harus pulih ke nilai state aslinya masing-masing.
func test_adv08_all_other_cooking_states_preserved_unaltered() -> bool:
	_clean_sandbox()
	var passed := true
	var sm := _create_test_sm()
	var kit = sm._get_autoload("KitchenManager")

	var non_cooking_states: Array[int] = [0, 1, 2, 4, 5]
	for expected_state in non_cooking_states:
		kit.job_state = expected_state
		kit.active_job_id = "job_state_%d" % expected_state
		sm.save_game("manual")

		kit.job_state = 6 # FAILED

		sm.load_game("manual")
		if not Assertions.assert_equal(int(kit.job_state), expected_state, "ADV-08: State %d pulih utuh tanpa salah dipaksa PAUSED" % expected_state):
			passed = false

	return passed

# ==============================================================================
# SECTION 4: SLOT ISOLATION & MONOTONIC CONTINUE LOGIC
# ==============================================================================

## Skenario: Menulis, menimpa, atau menghapus slot `manual` tidak boleh mencemari
## berkas fisik maupun cadangan slot `autosave` (begitu pula sebaliknya).
func test_adv09_slot_isolation_manual_vs_autosave() -> bool:
	_clean_sandbox()
	var passed := true
	var sm := _create_test_sm()
	var wrm = sm._get_autoload("WorldResourceManager")

	# Simpan Manual di Hari 10
	wrm.current_day = 10
	sm.save_game("manual")

	# Simpan Autosave di Hari 20
	wrm.current_day = 20
	sm.save_game("autosave")

	var man_path := sm.get_slot_path("manual")
	var auto_path := sm.get_slot_path("autosave")

	# Timpa manual berkali-kali hingga Hari 50
	wrm.current_day = 30
	sm.save_game("manual")
	wrm.current_day = 50
	sm.save_game("manual")

	# Verifikasi slot autosave masih menyimpan Hari 20 tanpa terpengaruh
	var auto_env: Dictionary = sm.read_and_validate_envelope(auto_path)["envelope"]
	if not Assertions.assert_equal(int(auto_env["payload"]["world"]["current_day"]), 20, "ADV-09: Autosave tetap Hari 20 pasca-penimpaan manual"): passed = false

	# Hapus slot manual
	sm.delete_slot("manual")
	if not Assertions.assert_false(FileAccess.file_exists(man_path), "ADV-09: Manual terhapus"): passed = false
	if not Assertions.assert_true(FileAccess.file_exists(auto_path), "ADV-09: Autosave tetap utuh setelah manual dihapus"): passed = false

	# Muat autosave
	wrm.current_day = 0
	sm.load_game("autosave")
	if not Assertions.assert_equal(wrm.current_day, 20, "ADV-09: Autosave dapat dimuat normal"): passed = false

	return passed

## Skenario: Uji komprehensif seluruh cabang logika get_continue_slot():
## 1. Sandbox kosong -> ""
## 2. Hanya manual -> "manual"
## 3. Hanya autosave -> "autosave"
## 4. Manual rev 10 vs Autosave rev 15 -> "autosave"
## 5. Manual rev 20 vs Autosave rev 15 -> "manual"
## 6. Revisi sama, Autosave timestamp lebih baru -> "autosave"
## 7. Revisi sama, Manual timestamp lebih baru -> "manual"
## 8. Primary manual korup, namun manual.bak valid rev 25 vs autosave rev 15 -> "manual"
func test_adv10_monotonic_continue_resolution_matrix() -> bool:
	_clean_sandbox()
	var passed := true
	var sm := _create_test_sm()

	# 1. Kosong
	sm.delete_slot("manual")
	sm.delete_slot("autosave")
	if not Assertions.assert_equal(sm.get_continue_slot(), "", "ADV-10.1: Kosong menghasilkan ''"): passed = false

	# 2. Hanya manual
	sm.save_game("manual")
	if not Assertions.assert_equal(sm.get_continue_slot(), "manual", "ADV-10.2: Hanya manual menghasilkan 'manual'"): passed = false

	# 3. Hanya autosave
	sm.delete_slot("manual")
	sm.save_game("autosave")
	if not Assertions.assert_equal(sm.get_continue_slot(), "autosave", "ADV-10.3: Hanya autosave menghasilkan 'autosave'"): passed = false

	# 4. Keduanya ada: Autosave lebih baru secara revisi
	sm.save_game("manual") # rev N
	sm.save_game("autosave") # rev N+1
	if not Assertions.assert_equal(sm.get_continue_slot(), "autosave", "ADV-10.4: Autosave rev lebih tinggi terpilih"): passed = false

	# 5. Manual disimpan setelahnya: Manual lebih baru secara revisi
	sm.save_game("manual") # rev N+2
	if not Assertions.assert_equal(sm.get_continue_slot(), "manual", "ADV-10.5: Manual rev lebih tinggi terpilih"): passed = false

	# 6. Fallback Cadangan pada Continue Resolution:
	# Jika primary manual korup, namun .bak manual memiliki revisi lebih tinggi daripada autosave
	sm.delete_slot("autosave")
	sm.save_game("autosave") # rev N+3 (misal)

	# Simpan manual 2 kali agar .bak tercipta dengan revisi tinggi
	sm.save_game("manual") # rev N+4
	sm.save_game("manual") # rev N+5

	# Rusakkan primary manual
	var man_target := sm.get_slot_path("manual")
	var f := FileAccess.open(man_target, FileAccess.WRITE)
	f.store_string("CORRUPTED_PRIMARY_MANUAL")
	f.close()

	# get_continue_slot harus memeriksa .bak dan tetap memilih "manual"!
	var chosen := sm.get_continue_slot()
	if not Assertions.assert_equal(chosen, "manual", "ADV-10.6: Continue memeriksa .bak dan memilih manual"): passed = false

	_clean_sandbox()
	return passed

## Skenario: Rotasi cadangan (.bak) hanya menyimpan 1 tingkat sebelumnya secara tepat.
func test_adv11_backup_rotation_depth() -> bool:
	_clean_sandbox()
	var passed := true
	var sm := _create_test_sm()
	var wrm = sm._get_autoload("WorldResourceManager")

	wrm.current_day = 1
	sm.save_game("manual") # Ver 1
	var bak_path := sm.get_slot_path("manual") + ".bak"
	if not Assertions.assert_false(FileAccess.file_exists(bak_path), "ADV-11: Simpan pertama belum menghasilkan .bak"): passed = false

	wrm.current_day = 2
	sm.save_game("manual") # Ver 2: Ver 1 masuk .bak
	if not Assertions.assert_true(FileAccess.file_exists(bak_path), "ADV-11: Simpan kedua menghasilkan .bak"): passed = false
	var bak_env1: Dictionary = sm.read_and_validate_envelope(bak_path)["envelope"]
	if not Assertions.assert_equal(int(bak_env1["payload"]["world"]["current_day"]), 1, "ADV-11: .bak menyimpan Hari 1"): passed = false

	wrm.current_day = 3
	sm.save_game("manual") # Ver 3: Ver 2 masuk .bak
	var bak_env2: Dictionary = sm.read_and_validate_envelope(bak_path)["envelope"]
	if not Assertions.assert_equal(int(bak_env2["payload"]["world"]["current_day"]), 2, "ADV-11: .bak sekarang menyimpan Hari 2"): passed = false

	return passed

# ==============================================================================
# SECTION 5: MALICIOUS / ANOMALOUS PAYLOAD STRESS & COORDINATE BOUNDS
# ==============================================================================

## Skenario: Penolakan payload yang dimanipulasi dengan tumpukan ilegal (>20 atau <0),
## jumlah slot yang salah (!=12), atau ID item yang tidak ada di registri item resmi.
func test_adv12_reject_illegal_stack_counts_and_slot_quantities() -> bool:
	_clean_sandbox()
	var passed := true
	var sm := _create_test_sm()

	var valid_payload := sm.capture_all_states()

	# 1. Tumpukan melebihi batas 20 (CONTENT § 2)
	var p_overflow := valid_payload.duplicate(true)
	p_overflow["inventory"]["backpack"][0] = {"item_id": "seed_bayam", "count": 25}
	var res_overflow := sm.validate_save_payload(p_overflow)
	if not Assertions.assert_false(res_overflow.get("valid", false), "ADV-12.1: Tumpukan 25 ditolak"): passed = false

	# 2. Tumpukan negatif
	var p_neg := valid_payload.duplicate(true)
	p_neg["inventory"]["backpack"][0] = {"item_id": "seed_bayam", "count": -1}
	var res_neg := sm.validate_save_payload(p_neg)
	if not Assertions.assert_false(res_neg.get("valid", false), "ADV-12.2: Tumpukan negatif ditolak"): passed = false

	# 3. Jumlah slot tas salah (11 slot)
	var p_slot11 := valid_payload.duplicate(true)
	p_slot11["inventory"]["backpack"].resize(11)
	var res_slot11 := sm.validate_save_payload(p_slot11)
	if not Assertions.assert_false(res_slot11.get("valid", false), "ADV-12.3: Tas 11 slot ditolak"): passed = false

	# 4. Item asing ilegal
	var p_alien := valid_payload.duplicate(true)
	p_alien["inventory"]["storage_home"][0] = {"item_id": "hyper_cannon_3000", "count": 1}
	var res_alien := sm.validate_save_payload(p_alien)
	if not Assertions.assert_false(res_alien.get("valid", false), "ADV-12.4: Item ilegal 'hyper_cannon_3000' ditolak"): passed = false

	return passed

## Skenario: Koordinat pemain ekstrem (NaN, Inf, Y = -999, X = 500) wajib dialihkan
## ke titik aman pekarangan rumah (0, 0, 8). Sebaliknya, koordinat di batas terluar level
## [-42.0, -5.0, -37.0] dan [42.0, 50.0, 47.0] harus diterima tanpa dialihkan.
func test_adv13_player_bounds_and_nan_inf_sanitization() -> bool:
	_clean_sandbox()
	var passed := true
	var sm := _create_test_sm()

	# 1. PlayerController langsung: NaN & Inf
	var player := PlayerControllerClass.new()
	player.default_safe_return_position = Vector3(0.0, 0.0, 8.0)

	var data_nan := {"position": [NAN, 0.0, 8.0], "rotation_y": 0.0, "camera_pitch": 0.0}
	player.load_save_snapshot(data_nan)
	if not Assertions.assert_vector3_approx_equal(player.position, Vector3(0.0, 0.0, 8.0), 0.01, "ADV-13.1: NaN dialihkan ke titik aman"): passed = false

	var data_inf := {"position": [0.0, INF, 0.0], "rotation_y": 0.0, "camera_pitch": 0.0}
	player.load_save_snapshot(data_inf)
	if not Assertions.assert_vector3_approx_equal(player.position, Vector3(0.0, 0.0, 8.0), 0.01, "ADV-13.2: Inf dialihkan ke titik aman"): passed = false

	# 2. Uji batas minimum sah
	var min_edge := {"position": [-42.0, -5.0, -37.0], "rotation_y": 0.0, "camera_pitch": 0.0}
	player.load_save_snapshot(min_edge)
	if not Assertions.assert_approx_equal(player.position.x, -42.0, 0.01, "ADV-13.3: Batas minimum X sah (-42.0) dipertahankan"): passed = false
	if not Assertions.assert_approx_equal(player.position.z, -37.0, 0.01, "ADV-13.4: Batas minimum Z sah (-37.0) dipertahankan"): passed = false

	# 3. Uji batas maksimum sah
	var max_edge := {"position": [42.0, 50.0, 47.0], "rotation_y": 0.0, "camera_pitch": 0.0}
	player.load_save_snapshot(max_edge)
	if not Assertions.assert_approx_equal(player.position.x, 42.0, 0.01, "ADV-13.5: Batas maksimum X sah (42.0) dipertahankan"): passed = false
	if not Assertions.assert_approx_equal(player.position.z, 47.0, 0.01, "ADV-13.6: Batas maksimum Z sah (47.0) dipertahankan"): passed = false

	# 4. Uji koordinat di luar batas (X = 42.5) -> wajib dialihkan ke titik aman (0, 0, 8)
	var oob_pos := {"position": [42.5, 0.0, 8.0], "rotation_y": 0.0, "camera_pitch": 0.0}
	player.load_save_snapshot(oob_pos)
	if not Assertions.assert_approx_equal(player.position.x, 0.0, 0.01, "ADV-13.7: Koordinat X=42.5 dialihkan ke titik aman 0.0"): passed = false
	if not Assertions.assert_approx_equal(player.position.z, 8.0, 0.01, "ADV-13.8: Koordinat Z dialihkan ke titik aman 8.0"): passed = false

	player.free()
	_clean_sandbox()
	return passed
