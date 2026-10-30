class_name SaveManagerClass
extends Node

## SaveManager — Pengelola Persistensi Terpadu Buku Resep 2045
## Memenuhi spesifikasi PRD FR15, CONTENT.md § 11, § 12, § 14, PROTOTYPE.md § 5, § 7,
## TASKS.md SAVE-001, dan TEST_PLAN T14, T16, T17, T22, T46, T47, T48, T49, T50

signal save_started(slot_type: String)
signal save_completed(slot_type: String, file_path: String)
signal save_failed(slot_type: String, error_code: int, error_message: String)

signal load_started(slot_type: String)
signal load_completed(slot_type: String, file_path: String)
signal load_failed(slot_type: String, error_code: int, error_message: String)

signal save_recovered_from_backup(slot_type: String, backup_path: String)
signal player_position_sanitized(original_pos: Vector3, sanitized_pos: Vector3)

signal settings_loaded()
signal settings_saved()
signal setting_changed(section: String, key: String, value: Variant)
signal settings_applied()

const SCHEMA_VERSION: int = 1
const GAME_VERSION: String = "0.2.0"

# Fallback Koordinat Aman (LEVEL_DESIGN § 4 & PlayerConfig)
const SAFE_RETURN_POSITION: Vector3 = Vector3(0.0, 0.0, 8.0)
const SPAWN_HOME_POSITION: Vector3 = Vector3(0.0, 0.0, 1.0)
const BOUND_MIN_X: float = -42.0
const BOUND_MAX_X: float = 42.0
const BOUND_MIN_Z: float = -37.0
const BOUND_MAX_Z: float = 47.0
const BOUND_MIN_Y: float = -5.0
const BOUND_MAX_Y: float = 50.0

const ItemsDataClass = preload("res://scripts/inventory/items_data.gd")

var _save_directory: String = "user://"
var _settings_path: String = "user://settings.cfg"

# Monotonically increasing revision counter
var _current_revision: int = 0

# Hook Pengujian Kegagalan Tulis (T49)
var simulate_write_failure: bool = false

# Cache Pengaturan
var _settings: Dictionary = {}

# Registri item pasif untuk validasi integritas payload (T47)
var _items_data_validator: RefCounted = null

func _ready() -> void:
	_items_data_validator = ItemsDataClass.new()
	load_settings()
	_update_revision_from_existing_saves()

func set_save_directory(dir_path: String) -> void:
	_save_directory = dir_path
	if not _save_directory.ends_with("/"):
		_save_directory += "/"
	DirAccess.make_dir_recursive_absolute(_save_directory)
	_update_revision_from_existing_saves()

func get_save_directory() -> String:
	return _save_directory

func set_settings_path(path: String) -> void:
	_settings_path = path

func get_settings_path() -> String:
	return _settings_path

func get_slot_path(slot_type: String) -> String:
	var clean_slot := slot_type.strip_edges().to_lower()
	if clean_slot == "slot_manual" or clean_slot == "manual":
		return _save_directory.path_join("save_manual.json")
	elif clean_slot == "slot_autosave" or clean_slot == "autosave":
		return _save_directory.path_join("save_autosave.json")
	else:
		if clean_slot.begins_with("save_"):
			return _save_directory.path_join("%s.json" % clean_slot)
		return _save_directory.path_join("save_%s.json" % clean_slot)

# ==============================================================================
# 1. ATOMIC SAVE PIPELINE (T47, T49)
# ==============================================================================

func save_game(slot_type: String = "manual") -> Dictionary:
	save_started.emit(slot_type)

	if simulate_write_failure:
		var err_msg := "Progres belum tersimpan. Coba lagi atau gunakan lokasi simpan yang dapat ditulis."
		save_failed.emit(slot_type, ERR_FILE_CANT_WRITE, err_msg)
		return {"success": false, "error": ERR_FILE_CANT_WRITE, "message": err_msg}

	var target_path := get_slot_path(slot_type)
	var tmp_path := target_path + ".tmp"
	var bak_path := target_path + ".bak"

	# Pastikan direktori tujuan tersedia
	var parent_dir := target_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)

	# 1. Kumpulkan snapshot payload dari seluruh manajer
	var payload := capture_all_states()

	# 2. Buat Envelope v1 dengan Checksum SHA-256
	_current_revision += 1
	var envelope := create_envelope(slot_type, payload)
	var json_str := JSON.stringify(envelope, "\t")

	# 3. Tulis ke berkas sementara .tmp
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		var err_msg := "Progres belum tersimpan. Coba lagi atau gunakan lokasi simpan yang dapat ditulis."
		save_failed.emit(slot_type, err, err_msg)
		return {"success": false, "error": err, "message": err_msg}

	file.store_string(json_str)
	file.flush()
	file.close()

	# 4. Verifikasi berkas .tmp tertulis dan tidak 0-byte
	if not FileAccess.file_exists(tmp_path) or FileAccess.get_file_as_bytes(tmp_path).size() == 0:
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(tmp_path)
		var err_msg := "Progres belum tersimpan. File sementara tidak valid."
		save_failed.emit(slot_type, ERR_FILE_CORRUPT, err_msg)
		return {"success": false, "error": ERR_FILE_CORRUPT, "message": err_msg}

	# 5. Rotasi file target lama ke .bak (hapus .bak lama di Windows agar tidak ERR_ALREADY_EXISTS)
	if FileAccess.file_exists(target_path):
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		var bak_err := DirAccess.rename_absolute(target_path, bak_path)
		if bak_err != OK:
			print("[SaveManager] Peringatan: Gagal merotasi ke .bak: ", bak_err)

	# 6. Ganti target utama dengan .tmp
	if FileAccess.file_exists(target_path):
		DirAccess.remove_absolute(target_path)
	var rename_err := DirAccess.rename_absolute(tmp_path, target_path)
	if rename_err != OK:
		# Upaya pemulihan dari .bak jika rename gagal
		if FileAccess.file_exists(bak_path) and not FileAccess.file_exists(target_path):
			DirAccess.rename_absolute(bak_path, target_path)
		var err_msg := "Gagal mengganti berkas simpanan utama."
		save_failed.emit(slot_type, rename_err, err_msg)
		return {"success": false, "error": rename_err, "message": err_msg}

	save_completed.emit(slot_type, target_path)
	return {"success": true, "path": target_path, "revision": _current_revision}

# ==============================================================================
# 2. DEFENSIVE LOAD & RECOVERY PIPELINE (T16, T17, T47)
# ==============================================================================

func load_game(slot_type: String = "manual") -> Dictionary:
	load_started.emit(slot_type)
	var target_path := get_slot_path(slot_type)
	var bak_path := target_path + ".bak"

	var active_envelope: Dictionary = {}
	var recovered_from_backup := false

	# 1. Coba baca target utama
	var primary_res := read_and_validate_envelope(target_path)
	if primary_res.get("valid", false):
		active_envelope = primary_res["envelope"]
	else:
		# 2. Fallback ke cadangan .bak jika target utama rusak atau hilang (T17)
		print("[SaveManager] Checkpoint utama rusak/hilang (%s: %s). Mencoba .bak..." % [target_path, primary_res.get("reason", "UNKNOWN")])
		var bak_res := read_and_validate_envelope(bak_path)
		if bak_res.get("valid", false):
			active_envelope = bak_res["envelope"]
			recovered_from_backup = true
			save_recovered_from_backup.emit(slot_type, bak_path)
		else:
			var err_msg := "Data simpan tidak cocok dengan versi ini atau rusak. Cadangan tidak tersedia."
			load_failed.emit(slot_type, ERR_FILE_CORRUPT, err_msg)
			return {"success": false, "error": ERR_FILE_CORRUPT, "message": err_msg}

	# 3. Two-Phase Commit: Fase 1 Pre-Flight Dry-Run
	var payload: Dictionary = active_envelope.get("payload", {})
	var val_res := validate_save_payload(payload)
	if not val_res.get("valid", false):
		# Jika data utama tidak lolos validasi payload tetapi belum mencoba .bak
		if not recovered_from_backup:
			var bak_res2 := read_and_validate_envelope(bak_path)
			if bak_res2.get("valid", false):
				var bak_payload: Dictionary = bak_res2["envelope"].get("payload", {})
				var bak_val := validate_save_payload(bak_payload)
				if bak_val.get("valid", false):
					payload = bak_payload
					recovered_from_backup = true
					save_recovered_from_backup.emit(slot_type, bak_path)
				else:
					var err_msg := "Data simpan tidak cocok dengan versi ini: %s" % val_res.get("reason", "")
					load_failed.emit(slot_type, ERR_INVALID_DATA, err_msg)
					return {"success": false, "error": ERR_INVALID_DATA, "message": err_msg}
			else:
				var err_msg := "Data simpan tidak cocok dengan versi ini: %s" % val_res.get("reason", "")
				load_failed.emit(slot_type, ERR_INVALID_DATA, err_msg)
				return {"success": false, "error": ERR_INVALID_DATA, "message": err_msg}
		else:
			var err_msg := "Data simpan tidak cocok dengan versi ini: %s" % val_res.get("reason", "")
			load_failed.emit(slot_type, ERR_INVALID_DATA, err_msg)
			return {"success": false, "error": ERR_INVALID_DATA, "message": err_msg}

	# 4. Two-Phase Commit: Fase 2 Atomic Application ke Live Singletons
	apply_all_states(payload)

	# 5. Jika pulih dari cadangan, simpan ulang secara atomik untuk menyembuhkan berkas primary (Self-Healing)
	if recovered_from_backup:
		save_game(slot_type)

	load_completed.emit(slot_type, target_path if not recovered_from_backup else bak_path)
	return {"success": true, "slot_type": slot_type, "recovered_from_backup": recovered_from_backup}

func read_and_validate_envelope(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"valid": false, "reason": "FILE_NOT_FOUND"}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"valid": false, "reason": "FILE_OPEN_FAILED"}

	var content := file.get_as_text()
	file.close()

	if content.strip_edges().is_empty():
		return {"valid": false, "reason": "EMPTY_FILE"}

	var parsed = JSON.parse_string(content)
	if not (parsed is Dictionary):
		return {"valid": false, "reason": "INVALID_JSON"}

	var envelope: Dictionary = parsed
	var ver: int = int(envelope.get("schema_version", envelope.get("header", {}).get("schema_version", 0)))
	if ver != SCHEMA_VERSION:
		return {"valid": false, "reason": "VERSION_MISMATCH"}

	var payload = envelope.get("payload")
	if not (payload is Dictionary) or payload.is_empty():
		return {"valid": false, "reason": "MISSING_PAYLOAD"}

	# Verifikasi Checksum SHA-256
	var expected_hash: String = str(envelope.get("checksum", envelope.get("header", {}).get("checksum", "")))
	if not expected_hash.is_empty():
		var actual_hash: String = canonical_json(payload).sha256_text()
		if actual_hash != expected_hash:
			return {"valid": false, "reason": "CHECKSUM_MISMATCH"}

	return {"valid": true, "envelope": envelope}

func validate_save_payload(payload: Dictionary) -> Dictionary:
	var required_sections := ["player", "inventory", "recipe", "gardening", "world", "cooking", "dialogue"]
	for sec in required_sections:
		if not payload.has(sec) or not (payload[sec] is Dictionary):
			return {"valid": false, "reason": "Missing required section: " + sec}

	# 1. Validasi Inventory
	var inv_data: Dictionary = payload["inventory"]
	if not inv_data.has("backpack") or not inv_data.has("storage_home"):
		return {"valid": false, "reason": "Invalid inventory structure"}
	var bp = inv_data["backpack"]
	var st = inv_data["storage_home"]
	if not (bp is Array) or not (st is Array) or bp.size() != 12 or st.size() != 12:
		return {"valid": false, "reason": "Inventory slots count mismatch (must be 12)"}

	# Validasi ID item terdaftar dan batas stack (T47)
	if _items_data_validator == null:
		_items_data_validator = ItemsDataClass.new()
	for slot in bp:
		if slot is Dictionary:
			var it_id: String = str(slot.get("item_id", slot.get("id", "")))
			var count: int = int(slot.get("count", 0))
			if count < 0 or count > 20:
				return {"valid": false, "reason": "Illegal stack count: %d" % count}
			if not it_id.is_empty() and not _items_data_validator.has_item(it_id):
				return {"valid": false, "reason": "Unknown item ID in backpack: " + it_id}

	for slot in st:
		if slot is Dictionary:
			var it_id: String = str(slot.get("item_id", slot.get("id", "")))
			var count: int = int(slot.get("count", 0))
			if count < 0 or count > 20:
				return {"valid": false, "reason": "Illegal stack count: %d" % count}
			if not it_id.is_empty() and not _items_data_validator.has_item(it_id):
				return {"valid": false, "reason": "Unknown item ID in storage: " + it_id}

	# 2. Validasi Gardening
	var gard_data: Dictionary = payload["gardening"]
	if not gard_data.has("plots") or not (gard_data["plots"] is Dictionary):
		return {"valid": false, "reason": "Invalid gardening plots structure"}
	if not gard_data["plots"].has("plot_home_01"):
		return {"valid": false, "reason": "Missing required plot: plot_home_01"}

	# 3. Validasi Cooking
	var cook_data: Dictionary = payload["cooking"]
	var js: int = int(cook_data.get("job_state", -1))
	if js < 0 or js > 6:
		return {"valid": false, "reason": "Invalid cooking job_state: %d" % js}

	# 4. Validasi World
	var world_data: Dictionary = payload["world"]
	var cur_day: int = int(world_data.get("current_day", 0))
	if cur_day < 1:
		return {"valid": false, "reason": "Invalid world current_day: %d" % cur_day}

	# 5. Validasi Player
	var player_data: Dictionary = payload["player"]
	var raw_pos = player_data.get("position")
	if not (raw_pos is Array) or raw_pos.size() < 3:
		return {"valid": false, "reason": "Invalid player position array"}

	return {"valid": true}

# ==============================================================================
# 3. SNAPSHOT ORCHESTRATION (CAPTURE & APPLY)
# ==============================================================================

func _get_autoload(name: String) -> Node:
	if is_inside_tree() and has_node("/root/" + name):
		return get_node("/root/" + name)
	if Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st.root and st.root.has_node(name):
			return st.root.get_node(name)
	return null

func capture_all_states() -> Dictionary:
	var payload: Dictionary = {}

	# Player
	var player = _get_player_node()
	if player and player.has_method("get_save_snapshot"):
		payload["player"] = player.get_save_snapshot()
	else:
		payload["player"] = {
			"position": [SPAWN_HOME_POSITION.x, SPAWN_HOME_POSITION.y, SPAWN_HOME_POSITION.z],
			"rotation_y": 0.0,
			"camera_pitch": 0.0
		}

	# Live Singletons
	var inv = _get_autoload("InventoryManager")
	if inv and inv.has_method("get_save_snapshot"):
		payload["inventory"] = inv.get_save_snapshot()

	var rec = _get_autoload("RecipeManager")
	if rec and rec.has_method("get_save_snapshot"):
		payload["recipe"] = rec.get_save_snapshot()

	var gard = _get_autoload("GardenManager")
	if gard and gard.has_method("get_save_snapshot"):
		payload["gardening"] = gard.get_save_snapshot()

	var wr = _get_autoload("WorldResourceManager")
	if wr and wr.has_method("get_save_snapshot"):
		payload["world"] = wr.get_save_snapshot()

	var kit = _get_autoload("KitchenManager")
	if kit and kit.has_method("get_save_snapshot"):
		payload["cooking"] = kit.get_save_snapshot()

	var dia = _get_autoload("DialogueManager")
	if dia and dia.has_method("get_save_snapshot"):
		payload["dialogue"] = dia.get_save_snapshot()

	return payload

func apply_all_states(payload: Dictionary) -> void:
	var inv = _get_autoload("InventoryManager")
	if inv and payload.has("inventory") and inv.has_method("load_save_snapshot"):
		inv.load_save_snapshot(payload["inventory"])

	var rec = _get_autoload("RecipeManager")
	if rec and payload.has("recipe") and rec.has_method("load_save_snapshot"):
		rec.load_save_snapshot(payload["recipe"])

	var gard = _get_autoload("GardenManager")
	if gard and payload.has("gardening") and gard.has_method("load_save_snapshot"):
		gard.load_save_snapshot(payload["gardening"])

	var wr = _get_autoload("WorldResourceManager")
	if wr and payload.has("world") and wr.has_method("load_save_snapshot"):
		wr.load_save_snapshot(payload["world"])

	var kit = _get_autoload("KitchenManager")
	if kit and payload.has("cooking") and kit.has_method("load_save_snapshot"):
		kit.load_save_snapshot(payload["cooking"])
		# Jika dimuat dalam keadaan COOKING (3) di saat pemain berada di dunia 3D,
		# jadikan PAUSED (4) agar tidak berjalan offline/di latar belakang tanpa disadari pemain (PROTOTYPE § 5, T14)
		if int(kit.job_state) == 3:
			kit.job_state = 4 # PAUSED

	var dia = _get_autoload("DialogueManager")
	if dia and payload.has("dialogue") and dia.has_method("load_save_snapshot"):
		dia.load_save_snapshot(payload["dialogue"])

	if payload.has("player"):
		_apply_player_snapshot(payload["player"])

func _apply_player_snapshot(player_data: Dictionary) -> void:
	var player = _get_player_node()
	if player == null:
		return

	if player.has_method("load_save_snapshot"):
		player.load_save_snapshot(player_data)
	else:
		# Fallback sanitasi koordinat T22 jika controller belum mengimplementasikan snapshot
		var raw_pos = player_data.get("position", [SAFE_RETURN_POSITION.x, SAFE_RETURN_POSITION.y, SAFE_RETURN_POSITION.z])
		var target_pos := SAFE_RETURN_POSITION
		if raw_pos is Array and raw_pos.size() >= 3:
			var px: float = float(raw_pos[0])
			var py: float = float(raw_pos[1])
			var pz: float = float(raw_pos[2])
			if not (is_nan(px) or is_nan(py) or is_nan(pz) or is_inf(px) or is_inf(py) or is_inf(pz)):
				if px >= BOUND_MIN_X and px <= BOUND_MAX_X and pz >= BOUND_MIN_Z and pz <= BOUND_MAX_Z and py >= BOUND_MIN_Y and py <= BOUND_MAX_Y:
					target_pos = Vector3(px, py, pz)
				else:
					player_position_sanitized.emit(Vector3(px, py, pz), SAFE_RETURN_POSITION)
		player.global_position = target_pos

static func canonical_json(val: Variant) -> String:
	if val is Dictionary:
		var d: Dictionary = val
		var keys: Array = d.keys()
		keys.sort()
		var parts: Array[String] = []
		for k in keys:
			parts.append(JSON.stringify(str(k)) + ":" + canonical_json(d[k]))
		return "{" + ",".join(parts) + "}"
	elif val is Array:
		var a: Array = val
		var parts: Array[String] = []
		for item in a:
			parts.append(canonical_json(item))
		return "[" + ",".join(parts) + "]"
	elif val is float:
		var f: float = val
		if not is_nan(f) and not is_inf(f) and is_equal_approx(f, roundf(f)) and abs(f) < 1e15:
			return str(int(roundf(f)))
		return JSON.stringify(val)
	elif val is int:
		return str(val)
	else:
		return JSON.stringify(val)

func create_envelope(slot_type: String, payload: Dictionary) -> Dictionary:
	var payload_str := canonical_json(payload)
	var hash_str := payload_str.sha256_text()
	var now_unix := Time.get_unix_time_from_system()
	var now_iso := Time.get_datetime_string_from_system(true, true)

	var header_dict := {
		"schema_version": SCHEMA_VERSION,
		"game_version": GAME_VERSION,
		"slot_type": slot_type,
		"revision": _current_revision,
		"timestamp": now_unix,
		"timestamp_iso": now_iso,
		"checksum": hash_str
	}

	return {
		"header": header_dict,
		"schema_version": SCHEMA_VERSION,
		"slot_type": slot_type,
		"revision": _current_revision,
		"timestamp": now_unix,
		"timestamp_iso": now_iso,
		"checksum": hash_str,
		"payload": payload
	}

# ==============================================================================
# 4. CONTINUE RESOLUTION & SLOT METADATA API (T48)
# ==============================================================================

func get_continue_slot() -> String:
	var manual_meta := get_slot_metadata("manual")
	var auto_meta := get_slot_metadata("autosave")

	var manual_valid: bool = manual_meta.get("valid", false)
	var auto_valid: bool = auto_meta.get("valid", false)

	if not manual_valid and not auto_valid:
		return ""
	if manual_valid and not auto_valid:
		return "manual"
	if not manual_valid and auto_valid:
		return "autosave"

	# Keduanya valid: pilih slot dengan revisi terbesar (atau timestamp jika revisi sama) (T48)
	var rev_manual: int = int(manual_meta.get("revision", 0))
	var rev_auto: int = int(auto_meta.get("revision", 0))

	if rev_auto > rev_manual:
		return "autosave"
	elif rev_manual > rev_auto:
		return "manual"
	else:
		return "autosave" if int(auto_meta.get("timestamp", 0)) >= int(manual_meta.get("timestamp", 0)) else "manual"

func get_slot_metadata(slot_type: String) -> Dictionary:
	var target_path := get_slot_path(slot_type)
	var bak_path := target_path + ".bak"

	for path in [target_path, bak_path]:
		var res := read_and_validate_envelope(path)
		if res.get("valid", false):
			var env: Dictionary = res["envelope"]
			var hdr: Dictionary = env.get("header", env)
			return {
				"valid": true,
				"slot_type": slot_type,
				"revision": int(hdr.get("revision", env.get("revision", 0))),
				"timestamp": int(hdr.get("timestamp", env.get("timestamp", 0))),
				"timestamp_iso": str(hdr.get("timestamp_iso", env.get("timestamp_iso", ""))),
				"recovered_from_backup": (path == bak_path)
			}
	return {"valid": false, "slot_type": slot_type}

func has_valid_save(slot_type: String) -> bool:
	var meta := get_slot_metadata(slot_type)
	return meta.get("valid", false)

func has_any_valid_save() -> bool:
	return has_valid_save("manual") or has_valid_save("autosave")

func delete_slot(slot_type: String) -> void:
	var target_path := get_slot_path(slot_type)
	var bak_path := target_path + ".bak"
	var tmp_path := target_path + ".tmp"
	for p in [target_path, bak_path, tmp_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

# ==============================================================================
# 5. SEPARATE SETTINGS PERSISTENCE (user://settings.cfg) (T49, T52)
# ==============================================================================

func load_settings() -> Dictionary:
	var config := ConfigFile.new()
	var err := config.load(_settings_path)
	if err != OK:
		_settings = get_default_settings()
		save_settings(_settings)
	else:
		_settings = {
			"gameplay": {
				"mouse_sensitivity_multiplier": float(config.get_value("gameplay", "mouse_sensitivity_multiplier", 1.0)),
				"head_bob": bool(config.get_value("gameplay", "head_bob", false))
			},
			"video": {
				"fov": float(config.get_value("video", "fov", 80.0)),
				"ui_scale": float(config.get_value("video", "ui_scale", 1.0)),
				"window_mode": int(config.get_value("video", "window_mode", 0))
			},
			"audio": {
				"master_volume": float(config.get_value("audio", "master_volume", 0.7)),
				"music_volume": float(config.get_value("audio", "music_volume", 0.4)),
				"sfx_volume": float(config.get_value("audio", "sfx_volume", 0.7))
			},
			"accessibility": {
				"subtitles": bool(config.get_value("accessibility", "subtitles", true))
			}
		}
	settings_loaded.emit()
	apply_all_settings()
	return _settings

func save_settings(new_settings: Dictionary) -> Error:
	var config := ConfigFile.new()
	for sec in new_settings:
		for k in new_settings[sec]:
			config.set_value(sec, k, new_settings[sec][k])
	
	# Pastikan direktori settings ada
	var base_dir := _settings_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)

	var err := config.save(_settings_path)
	if err == OK:
		_settings = new_settings.duplicate(true)
		settings_saved.emit()
		apply_all_settings()
	return err

func get_default_settings() -> Dictionary:
	return {
		"gameplay": {
			"mouse_sensitivity_multiplier": 1.0,
			"head_bob": false
		},
		"video": {
			"fov": 80.0,
			"ui_scale": 1.0,
			"window_mode": 0
		},
		"audio": {
			"master_volume": 0.7,
			"music_volume": 0.4,
			"sfx_volume": 0.7
		},
		"accessibility": {
			"subtitles": true
		}
	}

func get_setting(section: String, key: String, default_val: Variant = null) -> Variant:
	if _settings.has(section):
		if _settings[section].has(key):
			return _settings[section][key]
		if section == "gameplay" and key == "mouse_sensitivity" and _settings[section].has("mouse_sensitivity_multiplier"):
			return _settings[section]["mouse_sensitivity_multiplier"]
		elif section == "gameplay" and key == "mouse_sensitivity_multiplier" and _settings[section].has("mouse_sensitivity"):
			return _settings[section]["mouse_sensitivity"]
	return default_val

func set_setting(section: String, key: String, val: Variant) -> void:
	if not _settings.has(section):
		_settings[section] = {}
	_settings[section][key] = val
	setting_changed.emit(section, key, val)

func ensure_audio_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

func apply_all_settings() -> void:
	ensure_audio_buses()

	# 1. Video
	var fov_val: float = float(get_setting("video", "fov", 80.0))
	var ui_scale_val: float = float(get_setting("video", "ui_scale", 1.0))
	var win_mode: int = int(get_setting("video", "window_mode", 0))

	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree and tree.root:
		tree.root.content_scale_factor = ui_scale_val

	if DisplayServer.get_name() != "headless":
		if win_mode == 3 or win_mode == 4:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# 2. Audio
	_apply_bus_volume("Master", float(get_setting("audio", "master_volume", 0.7)))
	_apply_bus_volume("Music", float(get_setting("audio", "music_volume", 0.4)))
	_apply_bus_volume("SFX", float(get_setting("audio", "sfx_volume", 0.7)))

	# 3. Gameplay & Player
	var p := _get_player_node()
	if p:
		if "fov" in p:
			p.fov = fov_val
		var sens_mult: float = float(get_setting("gameplay", "mouse_sensitivity_multiplier", 1.0))
		if "mouse_sensitivity_multiplier" in p:
			p.mouse_sensitivity_multiplier = sens_mult
		elif "mouse_sensitivity" in p:
			p.mouse_sensitivity = 0.00174532925 * sens_mult
		if "head_bob_enabled" in p:
			p.head_bob_enabled = bool(get_setting("gameplay", "head_bob", false))

	settings_applied.emit()

func _apply_bus_volume(bus_name: String, linear_vol: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	if linear_vol <= 0.0001:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear_vol, 0.0001, 1.0)))

# ==============================================================================
# 6. INTERNAL HELPERS
# ==============================================================================

func _get_player_node() -> CharacterBody3D:
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree == null or tree.root == null:
		return null
	return tree.root.find_child("Player", true, false) as CharacterBody3D

func _update_revision_from_existing_saves() -> void:
	for slot in ["manual", "autosave"]:
		var meta := get_slot_metadata(slot)
		if meta.get("valid", false):
			var rev: int = int(meta.get("revision", 0))
			if rev > _current_revision:
				_current_revision = rev
