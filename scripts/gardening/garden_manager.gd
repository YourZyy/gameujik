extends Node

## Pengelola Sistem Kebun, Petak, Titik Tanam, Alat dan Air untuk 'Buku Resep 2045'
## Memenuhi spesifikasi PRD FR07..FR10, CONTENT.md § 5/6/7/8/9/11/12, TASKS.md GARD-001, dan TEST_PLAN T06, T07, T08, T32, T33

signal plot_state_changed(plot_id: String, plot_data: Dictionary)
signal plot_nutrients_changed(plot_id: String, new_nutrients: float)
signal plot_moisture_changed(plot_id: String, new_moisture: float)
signal plot_hoed(plot_id: String)
signal plot_composted(plot_id: String)
signal plot_fertilized(plot_id: String)
signal plot_watered(plot_id: String)
signal spot_planted(plot_id: String, spot_id: String, crop_id: String)
signal crop_stage_changed(plot_id: String, spot_id: String, stage: int)
signal crop_ready_to_harvest(plot_id: String, spot_id: String, crop_id: String)
signal crop_stalled(plot_id: String, spot_id: String, reason: String)
signal crop_resumed(plot_id: String, spot_id: String)
signal crop_harvested(plot_id: String, spot_id: String)
signal spot_harvested(plot_id: String, spot_id: String, crop_id: String)
signal active_tool_changed(tool_id: String)
signal water_level_changed(current_water: int, max_water: int)
signal watering_can_updated(current_water: int, max_water: int)
signal action_failed(reason: String)
signal action_success(action_name: String, message: String)

enum CropStage {
	SEED = 0,
	SPROUT = 1,
	GROWING = 2,
	HARVESTABLE = 3
}

const STAGE_SEED: int = 0
const STAGE_SPROUT: int = 1
const STAGE_GROWING: int = 2
const STAGE_HARVESTABLE: int = 3

const CROP_STAGE_NAMES: Dictionary = {
	CropStage.SEED: "Benih",
	CropStage.SPROUT: "Tunas",
	CropStage.GROWING: "Tumbuh",
	CropStage.HARVESTABLE: "Siap Panen"
}

const BAYAM_TOTAL_GROWTH_TIME: float = 180.0
const MATURE_GROWTH_TIME: float = 180.0
const STAGE_SPROUT_THRESHOLD: float = 30.0
const STAGE_GROWING_THRESHOLD: float = 90.0
const STAGE_HARVESTABLE_THRESHOLD: float = 180.0

const CROP_MOISTURE_GROWTH_THRESHOLD: float = 30.0
const CROP_NUTRIENTS_GROWTH_THRESHOLD: float = 20.0
const HARVEST_NUTRIENT_COST: float = 5.0

const DEFAULT_PLOT_ID: String = "plot_home_01"
const EVAPORATION_RATE: float = 0.1
const MAX_WATERING_CAN_CAPACITY: int = 10
const WATERING_COST: int = 2
const WATERING_TARGET_MOISTURE: float = 80.0
const WATERING_THRESHOLD: float = 60.0
const FERTILIZER_TARGET_NUTRIENTS: float = 100.0
const FERTILIZER_THRESHOLD: float = 20.0

const TOOL_NONE: String = ""
const TOOL_HOE: String = "tool_hoe"
const TOOL_SEED: String = "tool_seed"
const TOOL_FERTILIZER: String = "tool_fertilizer"
const TOOL_WATERING_CAN: String = "tool_watering_can"

const TOOL_NAMES: Dictionary = {
	TOOL_HOE: "Alat tanah (Cangkul)",
	TOOL_SEED: "Tanam benih",
	TOOL_FERTILIZER: "Pupuk",
	TOOL_WATERING_CAN: "Penyiram"
}

var active_tool: String = TOOL_NONE
var watering_can_water: int = 0:
	set(val):
		watering_can_water = clampi(val, 0, MAX_WATERING_CAN_CAPACITY)
		water_level_changed.emit(watering_can_water, MAX_WATERING_CAN_CAPACITY)
		watering_can_updated.emit(watering_can_water, MAX_WATERING_CAN_CAPACITY)

var watering_can_charges: int:
	get: return watering_can_water
	set(val): watering_can_water = val

func get_watering_can_charges() -> int:
	return watering_can_water

func get_max_watering_can_charges() -> int:
	return MAX_WATERING_CAN_CAPACITY

var _plots: Dictionary = {}
var _inventory_override: Node = null
var _input_override: Node = null

func _ready() -> void:
	if _plots.is_empty():
		reset_to_defaults()

func reset_to_defaults() -> void:
	active_tool = TOOL_NONE
	watering_can_water = 0
	_plots.clear()
	_plots[DEFAULT_PLOT_ID] = _create_default_plot(DEFAULT_PLOT_ID)

func _create_default_plot(p_id: String) -> Dictionary:
	var spots_dict: Dictionary = {}
	for i in range(1, 5):
		var s_id := "slot_%02d" % i
		spots_dict[s_id] = {
			"spot_id": s_id,
			"spot_index": i - 1,
			"is_occupied": false,
			"crop_data": null
		}
	return {
		"id": p_id,
		"is_hoed": false,
		"has_compost": false,
		"nutrients": 0.0,
		"moisture": 0.0,
		"spots": spots_dict
	}

# --- Injeksi Dependensi Manager untuk Testing Headless & Runtime ---

func set_inventory_manager(inv: Node) -> void:
	_inventory_override = inv

func _get_inventory_manager() -> Object:
	if _inventory_override != null and is_instance_valid(_inventory_override):
		return _inventory_override
	if Engine.has_singleton("InventoryManager"):
		return Engine.get_singleton("InventoryManager")
	if is_inside_tree() and has_node("/root/InventoryManager"):
		return get_node("/root/InventoryManager")
	return null

func set_input_manager(im: Variant) -> void:
	_input_override = im

func _get_input_manager() -> Object:
	if _input_override != null and is_instance_valid(_input_override):
		return _input_override
	if Engine.has_singleton("InputManager"):
		return Engine.get_singleton("InputManager")
	if is_inside_tree() and has_node("/root/InputManager"):
		return get_node("/root/InputManager")
	return null

# --- Pemetaan ID Titik Tanam (spot_0..spot_3 <-> slot_01..slot_04) ---

func resolve_spot_id(spot_id: String) -> String:
	match spot_id:
		"spot_0", "0", "slot_01": return "slot_01"
		"spot_1", "1", "slot_02": return "slot_02"
		"spot_2", "2", "slot_03": return "slot_03"
		"spot_3", "3", "slot_04": return "slot_04"
		_: return spot_id

func get_spot_node_name(slot_id: String) -> String:
	match slot_id:
		"slot_01": return "spot_0"
		"slot_02": return "spot_1"
		"slot_03": return "spot_2"
		"slot_04": return "spot_3"
		_: return slot_id

func get_spot_id_from_local_coords(local_pt: Vector3) -> String:
	if local_pt.x < 0.0:
		return "slot_01" if local_pt.z < 0.0 else "slot_03"
	else:
		return "slot_02" if local_pt.z < 0.0 else "slot_04"

# --- Akses Data Petak & Titik ---

func get_plot(plot_id: String = DEFAULT_PLOT_ID) -> Dictionary:
	return _plots.get(plot_id, {})

func get_spot(plot_id: String, spot_id: String) -> Dictionary:
	var resolved := resolve_spot_id(spot_id)
	var p := get_plot(plot_id)
	if p.has("spots") and p["spots"].has(resolved):
		return p["spots"][resolved]
	return {}

func is_plot_ready_to_plant(plot_id: String = DEFAULT_PLOT_ID) -> bool:
	var p := get_plot(plot_id)
	return bool(p.get("is_hoed", false)) and bool(p.get("has_compost", false))

func can_crop_grow_on_plot(plot_id: String = DEFAULT_PLOT_ID) -> bool:
	var p: Dictionary = get_plot(plot_id)
	if p.is_empty():
		return false
	if not (bool(p.get("is_hoed", false)) and bool(p.get("has_compost", false))):
		return false
	var n: float = float(p.get("nutrients", 0.0))
	var m: float = float(p.get("moisture", 0.0))
	return n >= CROP_NUTRIENTS_GROWTH_THRESHOLD and m >= CROP_MOISTURE_GROWTH_THRESHOLD

func get_plot_growth_stall_reason(plot_id: String = DEFAULT_PLOT_ID) -> String:
	var p: Dictionary = get_plot(plot_id)
	if p.is_empty():
		return "Petak tidak ditemukan."
	if not (bool(p.get("is_hoed", false)) and bool(p.get("has_compost", false))):
		return "Tanah belum siap ditanami."
	var n: float = float(p.get("nutrients", 0.0))
	var m: float = float(p.get("moisture", 0.0))
	if n < CROP_NUTRIENTS_GROWTH_THRESHOLD and m < CROP_MOISTURE_GROWTH_THRESHOLD:
		return "Kurang nutrisi dan air."
	elif n < CROP_NUTRIENTS_GROWTH_THRESHOLD:
		return "Kurang nutrisi (perlu pupuk)."
	elif m < CROP_MOISTURE_GROWTH_THRESHOLD:
		return "Kurang air (perlu disiram)."
	return ""

func calculate_crop_stage(growth_time: float) -> int:
	if growth_time < STAGE_SPROUT_THRESHOLD:
		return CropStage.SEED
	elif growth_time < STAGE_GROWING_THRESHOLD:
		return CropStage.SPROUT
	elif growth_time < STAGE_HARVESTABLE_THRESHOLD:
		return CropStage.GROWING
	else:
		return CropStage.HARVESTABLE

func get_moisture_status_text(plot_id: String = DEFAULT_PLOT_ID) -> String:
	var p := get_plot(plot_id)
	var m: float = float(p.get("moisture", 0.0))
	if m < 30.0:
		return "Kering"
	elif m < WATERING_THRESHOLD:
		return "Lembap — boleh disiram"
	return "Lembap"

func get_nutrient_status_text(plot_id: String = DEFAULT_PLOT_ID) -> String:
	var p := get_plot(plot_id)
	var n: float = float(p.get("nutrients", 0.0))
	if n < FERTILIZER_THRESHOLD:
		return "Perlu pupuk"
	return "Cukup"

# --- Pemilihan Alat (Keys 1–4 Toggle) ---

func select_tool(tool_id: String) -> void:
	if active_tool == tool_id:
		active_tool = TOOL_NONE
	else:
		active_tool = tool_id
	active_tool_changed.emit(active_tool)

func deselect_tool() -> void:
	if active_tool != TOOL_NONE:
		active_tool = TOOL_NONE
		active_tool_changed.emit(active_tool)

func get_active_tool_name() -> String:
	return TOOL_NAMES.get(active_tool, "Tangan Kosong")

# --- Operasi Transaksional Kebun ---

# 1. Cangkul (Hoe)
func can_hoe_plot(plot_id: String = DEFAULT_PLOT_ID) -> Dictionary:
	if not _plots.has(plot_id):
		return {"success": false, "reason": "Petak tidak ditemukan."}
	var p: Dictionary = _plots[plot_id]
	if p["is_hoed"]:
		return {"success": false, "reason": "Kondisi cukup."}
	return {"success": true, "reason": "Dapat digemburkan."}

func hoe_plot(plot_id: String = DEFAULT_PLOT_ID) -> bool:
	var check := can_hoe_plot(plot_id)
	if not check["success"]:
		action_failed.emit(check["reason"])
		return false
	_plots[plot_id]["is_hoed"] = true
	plot_hoed.emit(plot_id)
	plot_state_changed.emit(plot_id, _plots[plot_id])
	action_success.emit("hoe", "Tanah berhasil digemburkan.")
	return true

# 2. Pembenah Tanah (Compost)
func can_add_compost(plot_id: String = DEFAULT_PLOT_ID) -> Dictionary:
	if not _plots.has(plot_id):
		return {"success": false, "reason": "Petak tidak ditemukan."}
	var p: Dictionary = _plots[plot_id]
	if not p["is_hoed"]:
		return {"success": false, "reason": "Gemburkan tanah dan tambahkan pembenah dahulu."}
	if p["has_compost"]:
		return {"success": false, "reason": "Kondisi cukup. Tidak ada bahan yang digunakan."}
	var inv = _get_inventory_manager()
	if inv != null and inv.get_available_item_count("soil_compost") < 1:
		return {"success": false, "reason": "Pembenah belum tersedia."}
	return {"success": true, "reason": "Dapat diberi pembenah."}

func add_compost(plot_id: String = DEFAULT_PLOT_ID) -> bool:
	var check := can_add_compost(plot_id)
	if not check["success"]:
		action_failed.emit(check["reason"])
		return false
	if not _consume_item("soil_compost", 1):
		action_failed.emit("Pembenah belum tersedia.")
		return false
	_plots[plot_id]["has_compost"] = true
	plot_composted.emit(plot_id)
	plot_state_changed.emit(plot_id, _plots[plot_id])
	action_success.emit("compost", "Pembenah tanah ditambahkan. Petak siap ditanami.")
	return true

func apply_compost(plot_id: String = DEFAULT_PLOT_ID) -> bool:
	return add_compost(plot_id)

# 3. Pupuk (Fertilizer)
func can_fertilize_plot(plot_id: String = DEFAULT_PLOT_ID) -> Dictionary:
	if not _plots.has(plot_id):
		return {"success": false, "reason": "Petak tidak ditemukan."}
	var p: Dictionary = _plots[plot_id]
	if float(p["nutrients"]) >= FERTILIZER_THRESHOLD:
		return {"success": false, "reason": "Kondisi cukup. Tidak ada bahan yang digunakan."}
	var inv = _get_inventory_manager()
	if inv != null and inv.get_available_item_count("fertilizer_basic") < 1:
		return {"success": false, "reason": "Pupuk belum tersedia."}
	return {"success": true, "reason": "Dapat dipupuk."}

func fertilize_plot(plot_id: String = DEFAULT_PLOT_ID) -> bool:
	var check := can_fertilize_plot(plot_id)
	if not check["success"]:
		action_failed.emit(check["reason"])
		return false
	if not _consume_item("fertilizer_basic", 1):
		action_failed.emit("Pupuk belum tersedia.")
		return false
	_plots[plot_id]["nutrients"] = FERTILIZER_TARGET_NUTRIENTS
	plot_fertilized.emit(plot_id)
	plot_nutrients_changed.emit(plot_id, FERTILIZER_TARGET_NUTRIENTS)
	plot_state_changed.emit(plot_id, _plots[plot_id])
	action_success.emit("fertilize", "Petak berhasil dipupuk. Nutrisi penuh (100).")
	return true

# 4. Siram (Water)
func can_water_plot(plot_id: String = DEFAULT_PLOT_ID) -> Dictionary:
	if not _plots.has(plot_id):
		return {"success": false, "reason": "Petak tidak ditemukan."}
	var p: Dictionary = _plots[plot_id]
	if float(p["moisture"]) >= WATERING_THRESHOLD:
		return {"success": false, "reason": "Petak sudah cukup. Tidak ada bahan yang digunakan."}
	if watering_can_water < WATERING_COST:
		return {"success": false, "reason": "Air tidak cukup. Isi ulang penyiram di pekarangan."}
	return {"success": true, "reason": "Dapat disiram."}

func water_plot(plot_id: String = DEFAULT_PLOT_ID) -> bool:
	var check := can_water_plot(plot_id)
	if not check["success"]:
		action_failed.emit(check["reason"])
		return false
	watering_can_water -= WATERING_COST
	_plots[plot_id]["moisture"] = WATERING_TARGET_MOISTURE
	plot_watered.emit(plot_id)
	plot_moisture_changed.emit(plot_id, WATERING_TARGET_MOISTURE)
	plot_state_changed.emit(plot_id, _plots[plot_id])
	action_success.emit("water", "Petak disiram. Kelembapan optimal (80).")
	return true

# 5. Isi Ulang Air (Refill at water_home)
func can_refill_water() -> Dictionary:
	if watering_can_water >= MAX_WATERING_CAN_CAPACITY:
		return {"success": false, "reason": "Kondisi cukup. Air sudah penuh."}
	return {"success": true, "reason": "Dapat diisi ulang."}

func refill_water() -> bool:
	var check := can_refill_water()
	if not check["success"]:
		action_failed.emit(check["reason"])
		return false
	watering_can_water = MAX_WATERING_CAN_CAPACITY
	action_success.emit("refill", "Penyiram terisi penuh (10/10).")
	return true

func refill_watering_can() -> bool:
	return refill_water()

# 6. Tanam Benih (Plant Seed on Spot)
func can_plant_seed(plot_id: String, spot_id: String, seed_id: String = "seed_bayam") -> Dictionary:
	if not _plots.has(plot_id):
		return {"success": false, "reason": "Petak tidak ditemukan."}
	var p: Dictionary = _plots[plot_id]
	if not (p["is_hoed"] and p["has_compost"]):
		return {"success": false, "reason": "Gemburkan tanah dan tambahkan pembenah dahulu."}
	var resolved := resolve_spot_id(spot_id)
	var spots: Dictionary = p["spots"]
	if not spots.has(resolved):
		return {"success": false, "reason": "Titik tanam tidak valid."}
	if spots[resolved]["is_occupied"]:
		return {"success": false, "reason": "Titik tanam sudah terisi."}
	var inv = _get_inventory_manager()
	if inv != null and inv.get_available_item_count(seed_id) < 1:
		return {"success": false, "reason": "Benih belum tersedia. Periksa wadah dekat alat."}
	return {"success": true, "reason": "Dapat ditanam."}

func plant_seed(plot_id: String, spot_id: String, seed_id: String = "seed_bayam") -> bool:
	var check := can_plant_seed(plot_id, spot_id, seed_id)
	if not check["success"]:
		action_failed.emit(check["reason"])
		return false
	if not _consume_item(seed_id, 1):
		action_failed.emit("Benih belum tersedia.")
		return false
	var resolved := resolve_spot_id(spot_id)
	var spot: Dictionary = _plots[plot_id]["spots"][resolved]
	spot["is_occupied"] = true
	spot["crop_data"] = {
		"crop_id": "crop_bayam",
		"growth_time": 0.0,
		"growth_stage": 0,
		"is_ready_to_harvest": false,
		"is_stalled": false,
		"stall_reason": ""
	}
	spot_planted.emit(plot_id, resolved, "crop_bayam")
	plot_state_changed.emit(plot_id, _plots[plot_id])
	action_success.emit("plant", "Benih bayam berhasil ditanam pada titik %s." % resolved)
	return true

func plant_crop(plot_id: String, spot_id: String, crop_id: String = "crop_bayam") -> bool:
	return plant_seed(plot_id, spot_id, "seed_bayam")

# 7. Pemanenan Atomik (Atomic Harvesting)

func can_harvest_crop(plot_id: String, spot_id: String) -> Dictionary:
	if not _plots.has(plot_id):
		return {"success": false, "message": "Petak tidak ditemukan.", "reason": "Petak tidak ditemukan."}
	var resolved := resolve_spot_id(spot_id)
	var spot: Dictionary = get_spot(plot_id, resolved)
	if spot.is_empty() or not spot.get("is_occupied", false) or spot.get("crop_data") == null:
		return {"success": false, "message": "Tidak ada tanaman di titik ini.", "reason": "Tidak ada tanaman di titik ini."}
	var crop: Dictionary = spot["crop_data"]
	if not (bool(crop.get("is_ready_to_harvest", false)) or int(crop.get("growth_stage", 0)) >= 3 or float(crop.get("growth_time", 0.0)) >= BAYAM_TOTAL_GROWTH_TIME):
		return {"success": false, "message": "Tanaman belum siap dipanen.", "reason": "Tanaman belum siap dipanen."}

	# Verifikasi kapasitas tas (dry-run untuk 1 bayam + 1 benih)
	var inv = _get_inventory_manager()
	if inv != null:
		var harvest_batch: Array[Dictionary] = [
			{"item_id": "ingredient_bayam", "id": "ingredient_bayam", "count": 1},
			{"item_id": "seed_bayam", "id": "seed_bayam", "count": 1}
		]
		var can_fit := false
		if inv.has_method("can_harvest"):
			can_fit = inv.can_harvest(harvest_batch)
		elif inv.has_method("can_accept_items"):
			can_fit = inv.can_accept_items("backpack", harvest_batch)
		else:
			var bp = inv.get_container("backpack") if inv.has_method("get_container") else (inv.get("backpack") if "backpack" in inv else null)
			if bp != null and bp.has_method("can_add_batch"):
				can_fit = bp.can_add_batch(harvest_batch)
			elif bp != null and bp.has_method("can_add_item"):
				can_fit = bp.can_add_item("ingredient_bayam", 1) and bp.can_add_item("seed_bayam", 1)
			else:
				can_fit = true
		if not can_fit:
			return {
				"success": false,
				"message": "Tas tidak cukup. Kosongkan slot atau simpan barang di rumah.",
				"reason": "Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."
			}

	return {
		"success": true,
		"message": "Dapat dipanen.",
		"reason": "Dapat dipanen.",
		"items": [
			{"id": "ingredient_bayam", "quantity": 1},
			{"id": "seed_bayam", "quantity": 1}
		]
	}

func can_harvest(plot_id: String, spot_id: String) -> Dictionary:
	return can_harvest_crop(plot_id, spot_id)

func harvest_crop(plot_id: String, spot_id: String) -> bool:
	var check := can_harvest_crop(plot_id, spot_id)
	if not check["success"]:
		action_failed.emit(str(check.get("message", check.get("reason", "Gagal memanen."))))
		return false

	var resolved := resolve_spot_id(spot_id)
	var inv = _get_inventory_manager()
	if inv != null:
		var bp = inv.get_container("backpack") if inv.has_method("get_container") else (inv.get("backpack") if "backpack" in inv else null)
		if bp != null:
			if bp.has_method("add_batch"):
				bp.add_batch([
					{"item_id": "ingredient_bayam", "id": "ingredient_bayam", "count": 1},
					{"item_id": "seed_bayam", "id": "seed_bayam", "count": 1}
				])
			else:
				bp.add_item("ingredient_bayam", 1)
				bp.add_item("seed_bayam", 1)
		if inv.has_signal("inventory_updated"):
			inv.inventory_updated.emit()

	# Kurangi nutrisi petak sebesar 5 poin (minimum 0.0)
	var p: Dictionary = _plots[plot_id]
	var cur_n: float = float(p.get("nutrients", 0.0))
	var new_n: float = maxf(0.0, cur_n - HARVEST_NUTRIENT_COST)
	p["nutrients"] = new_n

	# Reset titik tanam ke status kosong
	var spot: Dictionary = p["spots"][resolved]
	spot["is_occupied"] = false
	spot["crop_data"] = null

	# Spot tetap gembur (is_hoed) dan berkompos (has_compost) untuk tanam ulang langsung
	plot_nutrients_changed.emit(plot_id, new_n)
	crop_harvested.emit(plot_id, resolved)
	spot_harvested.emit(plot_id, resolved, "crop_bayam")
	plot_state_changed.emit(plot_id, p)
	action_success.emit("harvest", "Bayam berhasil dipanen! Mendapatkan 1 Bayam dan 1 Benih.")
	return true

func harvest_spot(plot_id: String, spot_id: String) -> bool:
	return harvest_crop(plot_id, spot_id)

# Helper konsumsi item terpadu dari inventaris
func _consume_item(item_id: String, count: int = 1) -> bool:
	var inv = _get_inventory_manager()
	if inv == null:
		return true
	if inv.get_available_item_count(item_id) < count:
		return false
	var bp = inv.get_container("backpack")
	var st = inv.get_container("storage")
	var from_bp = mini(count, bp.get_item_count(item_id)) if bp != null else 0
	if from_bp > 0:
		bp.remove_item(item_id, from_bp)
		count -= from_bp
	if count > 0 and st != null:
		st.remove_item(item_id, count)
	if inv.has_signal("inventory_updated"):
		inv.inventory_updated.emit()
	return true

# --- Loop Simulasi Penguapan & Pertumbuhan ---

func _process(delta: float) -> void:
	simulate_process(delta)

func simulate_process(delta: float) -> void:
	simulate_growth(delta)
	simulate_evaporation(delta)

func simulate_evaporation(delta: float) -> void:
	var im = _get_input_manager()
	if im != null and im.has_method("is_simulation_paused"):
		if im.is_simulation_paused():
			return

	if is_inside_tree() and get_tree().paused:
		return

	for p_id in _plots:
		var plot: Dictionary = _plots[p_id]
		var cur_m: float = float(plot.get("moisture", 0.0))
		if cur_m > 0.0:
			var new_m: float = maxf(0.0, cur_m - EVAPORATION_RATE * delta)
			plot["moisture"] = new_m
			if floori(cur_m) != floori(new_m) or new_m == 0.0:
				plot_moisture_changed.emit(p_id, new_m)

func simulate_growth(delta: float) -> void:
	var im = _get_input_manager()
	if im != null and im.has_method("is_simulation_paused"):
		if im.is_simulation_paused():
			return

	if is_inside_tree() and get_tree().paused:
		return

	for p_id in _plots:
		_simulate_plot_growth(p_id, delta)

func _simulate_plot_growth(plot_id: String, delta: float) -> void:
	var plot: Dictionary = _plots.get(plot_id, {})
	if plot.is_empty():
		return

	var can_grow := can_crop_grow_on_plot(plot_id)
	var spots: Dictionary = plot.get("spots", {})

	for spot_id in spots:
		var spot: Dictionary = spots[spot_id]
		if not spot.get("is_occupied", false) or spot.get("crop_data") == null:
			continue

		var crop: Dictionary = spot["crop_data"]
		if crop.get("is_ready_to_harvest", false):
			continue

		if not can_grow:
			if not crop.get("is_stalled", false):
				crop["is_stalled"] = true
				var reason := get_plot_growth_stall_reason(plot_id)
				crop["stall_reason"] = reason
				crop_stalled.emit(plot_id, spot_id, reason)
			continue

		# Reset stall status if conditions restored
		if crop.get("is_stalled", false):
			crop["is_stalled"] = false
			crop["stall_reason"] = ""
			crop_resumed.emit(plot_id, spot_id)

		var old_stage: int = int(crop.get("growth_stage", 0))
		var old_time: float = float(crop.get("growth_time", 0.0))
		var new_time: float = minf(BAYAM_TOTAL_GROWTH_TIME, old_time + delta)
		crop["growth_time"] = new_time

		var new_stage: int = calculate_crop_stage(new_time)
		crop["growth_stage"] = new_stage

		if new_time >= BAYAM_TOTAL_GROWTH_TIME:
			crop["is_ready_to_harvest"] = true
			crop_ready_to_harvest.emit(plot_id, spot_id, str(crop.get("crop_id", "crop_bayam")))

		if old_stage != new_stage:
			crop_stage_changed.emit(plot_id, spot_id, new_stage)
			plot_state_changed.emit(plot_id, plot)

# --- Serialisasi SAVE-001 Persistence ---

func get_save_snapshot() -> Dictionary:
	var plots_data: Dictionary = {}
	for p_id in _plots:
		plots_data[p_id] = _plots[p_id].duplicate(true)
	return {
		"version": 1,
		"active_tool": active_tool,
		"watering_can_water": watering_can_water,
		"plots": plots_data
	}

func load_save_snapshot(data: Dictionary) -> bool:
	if not data.has("plots"):
		return false
	active_tool = str(data.get("active_tool", TOOL_NONE))
	watering_can_water = int(data.get("watering_can_water", 0))
	_plots = data["plots"].duplicate(true)
	active_tool_changed.emit(active_tool)
	water_level_changed.emit(watering_can_water, MAX_WATERING_CAN_CAPACITY)
	for p_id in _plots:
		plot_state_changed.emit(p_id, _plots[p_id])
	return true
