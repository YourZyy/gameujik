extends Node

## Autoload Singleton WorldResourceManager untuk Buku Resep 2045
## Mengelola Siklus Hari (720s), Foraging Liar (Jagung & Temu Kunci 1x/hari),
## Titik Cadangan Darurat (Benih/Pembenah/Pupuk), Kasur Istirahat, dan Stasiun Air.
## Memenuhi PRD FR09/FR10, CONTENT.md § 5/6/9/11/12, PROTOTYPE.md § 5.1, TASKS.md WORLD-001, dan TEST_PLAN T09, T37, T38, T39.

signal day_advanced(current_day: int)
signal calendar_ticked(current_day: int, day_active_time: float)
signal foraging_node_harvested(node_id: String, item_id: String, count: int)
signal foraging_state_changed(node_id: String, is_available: bool)
signal emergency_reserve_claimed(reserve_type: String, item_id: String, count: int)
signal rest_completed(new_day: int)
signal foraging_nodes_refreshed()
signal action_failed(reason: String)
signal action_success(action_name: String, message: String)
signal meal_consumed(item_id: String, count: int)

const DAY_DURATION: float = 720.0
const NODE_JAGUNG: String = "resource_jagung_01"
const NODE_TEMU_KUNCI: String = "resource_temu_kunci_01"

const NODE_ITEM_MAP: Dictionary = {
	"resource_jagung_01": "ingredient_jagung",
	"resource_temu_kunci_01": "ingredient_temu_kunci"
}

const NODE_NAMES: Dictionary = {
	"resource_jagung_01": "Jagung",
	"resource_temu_kunci_01": "Temu Kunci"
}

var current_day: int = 1
var day_active_time: float = 0.0
var meal_used: bool = false
var last_harvested_day: Dictionary = {
	"resource_jagung_01": 0,
	"resource_temu_kunci_01": 0
}

func set_meal_used(val: bool) -> void:
	meal_used = val
	if val:
		meal_consumed.emit("dish_sayur_bening", 1)

func is_meal_used() -> bool:
	return meal_used

# Overrides untuk pengujian headless dan isolasi modul
var _inventory_override: Node = null
var _garden_override: Node = null
var _kitchen_override: Node = null
var _input_override: Node = null

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if _is_simulation_paused():
		return

	day_active_time += delta
	calendar_ticked.emit(current_day, day_active_time)

	if day_active_time >= DAY_DURATION:
		advance_day()

func advance_day() -> void:
	current_day += 1
	day_active_time = 0.0
	day_advanced.emit(current_day)
	foraging_nodes_refreshed.emit()
	for node_id in NODE_ITEM_MAP:
		foraging_state_changed.emit(node_id, is_foraging_node_available(node_id))

# ==============================================================================
# 1. FORAGING SUMBER DAYA LIAR (T37/T38)
# ==============================================================================

func is_foraging_node_available(node_id: String) -> bool:
	if not NODE_ITEM_MAP.has(node_id):
		return false
	var last_day: int = int(last_harvested_day.get(node_id, 0))
	return last_day < current_day

func can_harvest_foraging(node_id: String) -> Dictionary:
	if not NODE_ITEM_MAP.has(node_id):
		return {"success": false, "reason": "Sumber daya liar tidak dikenal."}

	if not is_foraging_node_available(node_id):
		return {"success": false, "reason": "Sumber daya sudah diambil hari ini. Tunggu besok."}

	var inv = _get_inventory_manager()
	if inv != null and inv.backpack != null:
		var item_id: String = NODE_ITEM_MAP[node_id]
		if not inv.backpack.can_add(item_id, 1):
			return {"success": false, "reason": "Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."}

	return {"success": true, "reason": "Dapat dipanen."}

func harvest_foraging(node_id: String) -> bool:
	var check := can_harvest_foraging(node_id)
	if not check.get("success", false):
		action_failed.emit(check.get("reason", "Gagal memanen sumber daya."))
		return false

	var item_id: String = NODE_ITEM_MAP[node_id]
	var inv = _get_inventory_manager()
	if inv != null and inv.backpack != null:
		var remaining: int = inv.backpack.add_item(item_id, 1)
		if remaining > 0:
			action_failed.emit("Tas tidak cukup. Kosongkan slot atau simpan barang di rumah.")
			return false

	last_harvested_day[node_id] = current_day
	foraging_node_harvested.emit(node_id, item_id, 1)
	foraging_state_changed.emit(node_id, false)

	var node_name: String = NODE_NAMES.get(node_id, item_id)
	action_success.emit("harvest", "Berhasil memetik 1 %s." % node_name)
	return true

# ==============================================================================
# 2. TITIK CADANGAN DARURAT (T09/T38)
# ==============================================================================

func can_claim_emergency_reserve() -> Dictionary:
	var inv = _get_inventory_manager()
	if inv == null:
		return {"success": false, "reason": "Sistem inventaris tidak tersedia."}

	# Prasyarat gerbang: wadah awal harus sudah diambil dahulu
	if not inv.is_starter_collected():
		return {"success": false, "reason": "Ambil wadah awal dekat alat terlebih dahulu."}

	var seed_count: int = inv.get_available_item_count("seed_bayam")
	var has_living_plants: bool = false
	var gm = _get_garden_manager()
	if gm != null and gm.has_method("get_plot"):
		var plot: Dictionary = gm.get_plot("plot_home_01")
		var spots: Dictionary = plot.get("spots", {})
		for s_id in spots:
			var s_data: Dictionary = spots[s_id]
			if bool(s_data.get("is_occupied", false)):
				has_living_plants = true
				break

	# 1. Evaluasi Kebutuhan Benih Bayam
	if seed_count == 0:
		if has_living_plants:
			return {
				"success": false,
				"reason": "Tanaman bayam sedang tumbuh di petak. Panen saat matang untuk mendapatkan benih."
			}
		# Benih benar-benar habis total dan tidak ada tanaman hidup: berikan paket darurat 4 benih
		if inv.backpack != null and not inv.backpack.can_add("seed_bayam", 4):
			return {"success": false, "reason": "Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."}
		return {
			"success": true,
			"type": "seed",
			"item_id": "seed_bayam",
			"count": 4,
			"reason": "Cadangan darurat 4 benih bayam tersedia."
		}

	# 2. Evaluasi Kebutuhan Pembenah Tanah (hanya jika petak gembur tapi belum diberi pembenah)
	if gm != null and gm.has_method("get_plot"):
		var plot: Dictionary = gm.get_plot("plot_home_01")
		var is_hoed: bool = bool(plot.get("is_hoed", false))
		var has_compost: bool = bool(plot.get("has_compost", false))
		var compost_count: int = inv.get_available_item_count("soil_compost")
		if is_hoed and not has_compost and compost_count == 0:
			if inv.backpack != null and not inv.backpack.can_add("soil_compost", 1):
				return {"success": false, "reason": "Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."}
			return {
				"success": true,
				"type": "compost",
				"item_id": "soil_compost",
				"count": 1,
				"reason": "Cadangan darurat 1 pembenah tanah tersedia."
			}

	# 3. Evaluasi Kebutuhan Pupuk (hanya jika petak siap tapi nutrisi < 20 dan pupuk 0)
	if gm != null and gm.has_method("get_plot"):
		var plot: Dictionary = gm.get_plot("plot_home_01")
		var is_hoed: bool = bool(plot.get("is_hoed", false))
		var has_compost: bool = bool(plot.get("has_compost", false))
		var nutrients: float = float(plot.get("nutrients", 100.0))
		var fertilizer_count: int = inv.get_available_item_count("fertilizer_basic")
		if is_hoed and has_compost and nutrients < 20.0 and fertilizer_count == 0:
			if inv.backpack != null and not inv.backpack.can_add("fertilizer_basic", 1):
				return {"success": false, "reason": "Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."}
			return {
				"success": true,
				"type": "fertilizer",
				"item_id": "fertilizer_basic",
				"count": 1,
				"reason": "Cadangan darurat 1 pupuk dasar tersedia."
			}

	# Jika tidak darurat: berikan alasan jujur dan penjelasan lokasi stok / tanaman
	if seed_count > 0:
		return {
			"success": false,
			"reason": "Benih bayam masih tersedia di tas atau peti rumah."
		}
	elif has_living_plants:
		return {
			"success": false,
			"reason": "Tanaman bayam sedang tumbuh di petak. Panen saat matang untuk mendapatkan benih."
		}

	return {
		"success": false,
		"reason": "Kondisi cadangan belum terpenuhi. Pasokan darurat hanya tersedia jika kehabisan bahan."
	}

func claim_emergency_reserve() -> bool:
	var check := can_claim_emergency_reserve()
	if not check.get("success", false):
		action_failed.emit(check.get("reason", "Kondisi cadangan belum terpenuhi."))
		return false

	var inv = _get_inventory_manager()
	var item_id: String = str(check["item_id"])
	var count: int = int(check["count"])
	var r_type: String = str(check["type"])

	if inv != null and inv.backpack != null:
		var remaining: int = inv.backpack.add_item(item_id, count)
		if remaining > 0:
			action_failed.emit("Tas tidak cukup. Kosongkan slot atau simpan barang di rumah.")
			return false

	emergency_reserve_claimed.emit(r_type, item_id, count)
	var item_name: String = item_id
	if inv != null and inv.item_registry != null:
		item_name = inv.item_registry.get_item_name(item_id)
	action_success.emit("reserve", "Menerima pasokan cadangan: %d %s." % [count, item_name])
	return true

# ==============================================================================
# 3. STASIUN AIR PEKARANGAN (T37)
# ==============================================================================

func can_refill_water() -> Dictionary:
	var gm = _get_garden_manager()
	if gm == null:
		return {"success": false, "reason": "Sistem kebun tidak tersedia."}
	var current_water: int = int(gm.get("watering_can_water"))
	var max_cap: int = int(gm.get("MAX_WATERING_CAN_CAPACITY")) if gm.get("MAX_WATERING_CAN_CAPACITY") != null else 10
	if current_water >= max_cap:
		return {"success": false, "reason": "Kondisi cukup. Air sudah penuh."}
	return {"success": true, "reason": "Dapat mengisi air."}

func refill_water() -> bool:
	var check := can_refill_water()
	if not check.get("success", false):
		action_failed.emit(check.get("reason", "Gagal mengisi air."))
		return false
	var gm = _get_garden_manager()
	if gm != null:
		var max_cap: int = int(gm.get("MAX_WATERING_CAN_CAPACITY")) if gm.get("MAX_WATERING_CAN_CAPACITY") != null else 10
		gm.set("watering_can_water", max_cap)
	action_success.emit("water_refill", "Berhasil mengisi penuh alat penyiram (10/10).")
	return true

# ==============================================================================
# 4. KASUR ISTIRAHAT & SIKLUS HARI (T39)
# ==============================================================================

func can_sleep() -> Dictionary:
	var km = _get_kitchen_manager()
	if km != null:
		if km.has_method("is_cooking_active") and km.is_cooking_active():
			return {"success": false, "reason": "Selesaikan atau batalkan proses memasak dahulu sebelum istirahat."}
		if km.has_method("is_job_active") and km.is_job_active():
			return {"success": false, "reason": "Selesaikan atau batalkan proses memasak dahulu sebelum istirahat."}
		if km.get("is_active") == true:
			return {"success": false, "reason": "Selesaikan atau batalkan proses memasak dahulu sebelum istirahat."}
	return {"success": true, "reason": "Dapat beristirahat."}

func sleep_and_advance_day() -> bool:
	var check := can_sleep()
	if not check.get("success", false):
		action_failed.emit(check.get("reason", "Tidak bisa istirahat."))
		return false

	# Majukan hari dan reset waktu aktif harian
	current_day += 1
	day_active_time = 0.0

	# INVARIAN MUTLAK: GardenManager TIDAK disimulasikan saat tidur.
	# Kelembapan, nutrisi, dan tanaman tetap pada nilainya.
	day_advanced.emit(current_day)
	rest_completed.emit(current_day)
	foraging_nodes_refreshed.emit()
	for node_id in NODE_ITEM_MAP:
		foraging_state_changed.emit(node_id, is_foraging_node_available(node_id))

	action_success.emit("sleep", "Hari berganti ke Hari %d. Sumber daya telah pulih." % current_day)
	return true

func rest() -> bool:
	return sleep_and_advance_day()

# ==============================================================================
# 5. SAVE SNAPSHOT ROUNDTRIP (SAVE-001 Contract)
# ==============================================================================

func get_save_snapshot() -> Dictionary:
	return {
		"version": 1,
		"current_day": current_day,
		"day_active_time": day_active_time,
		"meal_used": meal_used,
		"last_harvested_day": last_harvested_day.duplicate(true)
	}

func load_save_snapshot(data: Dictionary) -> bool:
	if data == null or not (data is Dictionary):
		return false
	if int(data.get("version", 0)) != 1:
		return false

	current_day = int(data.get("current_day", 1))
	day_active_time = float(data.get("day_active_time", 0.0))
	meal_used = bool(data.get("meal_used", false))

	var raw_harvested = data.get("last_harvested_day", {})
	if raw_harvested is Dictionary:
		last_harvested_day.clear()
		for k in raw_harvested:
			last_harvested_day[str(k)] = int(raw_harvested[k])

	day_advanced.emit(current_day)
	for node_id in NODE_ITEM_MAP:
		foraging_state_changed.emit(node_id, is_foraging_node_available(node_id))

	return true

func reset_state() -> void:
	current_day = 1
	day_active_time = 0.0
	meal_used = false
	last_harvested_day = {
		"resource_jagung_01": 0,
		"resource_temu_kunci_01": 0
	}
	_inventory_override = null
	_garden_override = null
	_kitchen_override = null
	_input_override = null
	var gm = _get_garden_manager()
	if gm != null and gm.has_method("reset_to_defaults"):
		gm.reset_to_defaults()

# ==============================================================================
# 6. INTERNAL RESOLVERS & HELPERS
# ==============================================================================

func set_inventory_manager(inv: Node) -> void:
	_inventory_override = inv

func set_garden_manager(gm: Node) -> void:
	_garden_override = gm

func set_kitchen_manager(km: Node) -> void:
	_kitchen_override = km

func set_input_manager(im: Node) -> void:
	_input_override = im

func _get_inventory_manager() -> Object:
	if _inventory_override != null and is_instance_valid(_inventory_override):
		return _inventory_override
	if Engine.has_singleton("InventoryManager"):
		return Engine.get_singleton("InventoryManager")
	if is_inside_tree() and has_node("/root/InventoryManager"):
		return get_node("/root/InventoryManager")
	return null

func _get_garden_manager() -> Object:
	if _garden_override != null and is_instance_valid(_garden_override):
		return _garden_override
	if Engine.has_singleton("GardenManager"):
		return Engine.get_singleton("GardenManager")
	if is_inside_tree() and has_node("/root/GardenManager"):
		return get_node("/root/GardenManager")
	return null

func _get_kitchen_manager() -> Object:
	if _kitchen_override != null and is_instance_valid(_kitchen_override):
		return _kitchen_override
	if Engine.has_singleton("KitchenManager"):
		return Engine.get_singleton("KitchenManager")
	if is_inside_tree() and has_node("/root/KitchenManager"):
		return get_node("/root/KitchenManager")
	return null

func _is_simulation_paused() -> bool:
	if _input_override != null and is_instance_valid(_input_override):
		if _input_override.has_method("is_simulation_paused"):
			return _input_override.is_simulation_paused()
	if Engine.has_singleton("InputManager"):
		var im = Engine.get_singleton("InputManager")
		if im.has_method("is_simulation_paused"):
			return im.is_simulation_paused()
	if is_inside_tree() and has_node("/root/InputManager"):
		var im = get_node("/root/InputManager")
		if im.has_method("is_simulation_paused"):
			return im.is_simulation_paused()
	return false
