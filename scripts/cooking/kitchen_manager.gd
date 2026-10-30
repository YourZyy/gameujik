extends Node

## Autoload Singleton KitchenManager untuk Buku Resep 2045
## Mengelola Stasiun Dapur (station_kitchen_home), Reservasi Bahan Lintas Kontainer,
## Aksi Tahan Persiapan 4s, Pembatalan Aman Pra-Masak & Kontainer Pengembalian Persisten.
## Memenuhi PRD FR12, CONTENT.md § 2, 3, 4, 11, 12, PROTOTYPE.md § 4, 5, 6.2, 6.3, TASKS.md COOK-001, dan TEST_PLAN T10, T11, T12, T13, T40.

enum JobState {
	IDLE = 0,
	RESERVED_PREPARING = 1,
	PREPARING = 1,
	READY_TO_HEAT = 2,
	COOKING = 3,
	PAUSED = 4,
	OUTPUT_READY = 5,
	REFUND_PENDING = 6
}

# Alias enum CookingState untuk kompatibilitas explorer/caller
const CookingState = JobState

enum HeatLevel {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2
}

const HEAT_MULTIPLIERS: Dictionary = {
	HeatLevel.LOW: 0.5,
	HeatLevel.MEDIUM: 1.0,
	HeatLevel.HIGH: 0.0
}

const HEAT_NAMES: Dictionary = {
	HeatLevel.LOW: "Rendah",
	HeatLevel.MEDIUM: "Sedang",
	HeatLevel.HIGH: "Tinggi"
}

const HEAT_LOW: String = "low"
const HEAT_MEDIUM: String = "medium"
const HEAT_HIGH: String = "high"
const COOK_DURATION: float = 30.0
const STALL_WARNING_HIGH_HEAT: String = "Kecilkan panas ke Sedang."
const DEFAULT_HEAT_LEVEL: HeatLevel = HeatLevel.LOW
const DISH_ITEM_ID: String = "dish_sayur_bening"

signal state_changed(new_state: JobState, old_state: JobState)
signal cooking_state_changed(new_state: Variant, old_state: Variant)
signal job_started(job_id: String, recipe_id: String)
signal prep_started(job_id: String, duration: float)
signal prep_progress_updated(job_id: String, progress: float, elapsed: float, duration: float)
signal preparation_progress_changed(progress: float, duration: float)
signal prep_completed(job_id: String)
signal preparation_completed(job_id: String)
signal prep_cancelled(job_id: String)
signal job_cancelled(job_id: String, refunded_items: Array)
signal kitchen_refund_occurred(items: Array)
signal refund_storage_updated()
signal action_failed(reason: String)

# Sinyal Memasak & Panas (COOK-002)
signal heat_level_changed(new_heat: int, old_heat: int)
signal heat_changed(new_heat: String)
signal heat_stall_warning(message: String)
signal heat_stalled(warning_message: String)
signal cooking_started(job_id: String, duration: float)
signal cooking_progress_updated(job_id: String, fraction: float, elapsed: float, duration: float)
signal cook_progress_changed(progress: float, duration: float)
signal cook_progress_updated(job_id: String, fraction: float, elapsed: float, duration: float)
signal cooking_paused(job_id: String)
signal cooking_resumed(job_id: String)
signal cooking_completed(job_id: String, output: Dictionary)
signal cook_completed(job_id: String, output: Dictionary)
signal dish_collected(item_id: String, count: int)
signal dish_consumed(item_id: String)
signal meal_consumed(item_id: String)
signal p0_experience_completed()

const RECIPE_P0: String = "recipe_sayur_bening_01"
const RECIPE_ID: String = "recipe_sayur_bening_01"
const PREP_DURATION: float = 4.0

var active_job_id: String = ""
var active_recipe_id: String = ""
var job_state: JobState = JobState.IDLE:
	set(val):
		var old = job_state
		job_state = val
		if old != val:
			state_changed.emit(val, old)
			cooking_state_changed.emit(val, old)

var current_state: JobState:
	get:
		return job_state
	set(val):
		job_state = val

var is_active: bool:
	get:
		return is_job_active()

var current_heat_level: HeatLevel = HeatLevel.LOW
var current_heat: String:
	get:
		match current_heat_level:
			HeatLevel.LOW: return HEAT_LOW
			HeatLevel.MEDIUM: return HEAT_MEDIUM
			HeatLevel.HIGH: return HEAT_HIGH
			_: return HEAT_LOW
	set(val):
		set_heat_level(val)

var cook_progress: float = 0.0
var cook_duration: float = COOK_DURATION
var meal_used: bool = false
var p0_completed: bool = false

var prep_progress: float = 0.0
var prep_elapsed: float:
	get:
		return prep_progress
	set(val):
		prep_progress = val

var prep_duration: float = PREP_DURATION
var reserved_ingredients: Array[Dictionary] = []
var origin_manifest: Array[Dictionary] = [] # [{"container": String, "source": String, "item_id": String, "count": int}]
var origin_records: Array[Dictionary]:
	get:
		return origin_manifest

var dish_output_slot: Dictionary = {}
var output_slot: Dictionary:
	get:
		return dish_output_slot
	set(val):
		dish_output_slot = val

var current_job: Dictionary = {}
var _job_counter: int = 0

var _inventory_override: Node = null
var _recipe_override: Node = null
var _dialogue_manager_override: Node = null

func _ready() -> void:
	pass

# --- Dependency Overrides ---

func set_inventory_manager(inv: Node) -> void:
	_inventory_override = inv

func set_recipe_manager(rm: Node) -> void:
	_recipe_override = rm

func set_dialogue_manager(dm: Node) -> void:
	_dialogue_manager_override = dm

func _get_inventory() -> Node:
	if _inventory_override != null and is_instance_valid(_inventory_override):
		return _inventory_override
	if Engine.has_singleton("InventoryManager"):
		return Engine.get_singleton("InventoryManager")
	if is_inside_tree() and has_node("/root/InventoryManager"):
		return get_node("/root/InventoryManager")
	return null

func _get_recipe_manager() -> Node:
	if _recipe_override != null and is_instance_valid(_recipe_override):
		return _recipe_override
	if Engine.has_singleton("RecipeManager"):
		return Engine.get_singleton("RecipeManager")
	if is_inside_tree() and has_node("/root/RecipeManager"):
		return get_node("/root/RecipeManager")
	return null

func _get_dialogue_manager() -> Node:
	if _dialogue_manager_override != null and is_instance_valid(_dialogue_manager_override):
		return _dialogue_manager_override
	if Engine.has_singleton("DialogueManager"):
		return Engine.get_singleton("DialogueManager")
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var node = tree.root.get_node_or_null("DialogueManager")
		if node != null:
			return node
	if is_inside_tree() and has_node("/root/DialogueManager"):
		return get_node("/root/DialogueManager")
	return null

# --- Status Query Helpers ---

func is_job_active() -> bool:
	# Output ready tidak menghalangi istirahat kasur (CONTENT.md § 9 baris 164)
	return job_state != JobState.IDLE and job_state != JobState.REFUND_PENDING and job_state != JobState.OUTPUT_READY

func is_cooking_active() -> bool:
	return job_state == JobState.COOKING

func is_cooking_paused() -> bool:
	return job_state == JobState.PAUSED

func has_ready_output() -> bool:
	return not dish_output_slot.is_empty() and int(dish_output_slot.get("count", 0)) > 0

func has_refund_items() -> bool:
	var inv := _get_inventory()
	if inv != null and inv.get("kitchen_refund") != null:
		var kr = inv.kitchen_refund
		if kr.has_method("get_used_slots_count"):
			return kr.get_used_slots_count() > 0
	return false

func is_p0_completed() -> bool:
	if p0_completed:
		return true
	var dm := _get_dialogue_manager()
	if dm != null and dm.has_method("is_p0_completed") and dm.is_p0_completed():
		p0_completed = true
		return true
	return false

# --- Validation & Dry-Run Gating (T10) ---

func can_start_preparation(recipe_id: String = RECIPE_P0) -> Dictionary:
	# 1. Stasiun tidak boleh memiliki job aktif
	if is_job_active():
		return {"success": false, "reason": "Job memasak sudah aktif."}

	# 2. Slot output harus kosong (CONTENT.md § 3, § 11)
	if has_ready_output():
		return {"success": false, "reason": "Ambil hidangan sebelumnya dahulu."}

	var inv := _get_inventory()
	if inv == null:
		return {"success": false, "reason": "InventoryManager tidak tersedia."}

	var rm := _get_recipe_manager()
	var recipe_res: Resource = null
	if rm != null and rm.has_method("get_recipe"):
		recipe_res = rm.get_recipe(recipe_id)

	# Fallback ke RecipesData jika recipe_res belum terdaftar di instance
	var req_ingredients: Dictionary = {}
	if recipe_res != null and "ingredients" in recipe_res:
		req_ingredients = recipe_res.ingredients
	elif recipe_id == RECIPE_P0 or recipe_id == "recipe_sayur_bening_01":
		req_ingredients = {
			"ingredient_bayam": 3,
			"ingredient_jagung": 1,
			"ingredient_temu_kunci": 1
		}
	else:
		return {"success": false, "reason": "Resep tidak ditemukan."}

	# Validasi seluruh bahan bebas lintas tas dan peti
	var missing: Dictionary = {}
	for it_id in req_ingredients:
		var needed: int = int(req_ingredients[it_id])
		var available: int = 0
		if inv.has_method("get_available_item_count"):
			available = inv.get_available_item_count(it_id)
		else:
			var bp_c = inv.get_container("backpack") if inv.has_method("get_container") else inv.get("backpack")
			var st_c = inv.get_container("storage") if inv.has_method("get_container") else inv.get("storage_home")
			if bp_c != null and bp_c.has_method("get_item_count"):
				available += bp_c.get_item_count(it_id)
			if st_c != null and st_c.has_method("get_item_count"):
				available += st_c.get_item_count(it_id)

		if available < needed:
			missing[it_id] = needed - available

	if not missing.is_empty():
		return {
			"success": false,
			"reason": "Bahan belum lengkap. Buka buku untuk melihat sumbernya.",
			"missing": missing
		}

	return {"success": true, "reason": "Bahan mencukupi.", "missing": {}}

func can_prepare_recipe(recipe_id: String = RECIPE_P0) -> Dictionary:
	return can_start_preparation(recipe_id)

# --- Start Preparation & Physical Atomic Deduction (T11, T12) ---

func reserve_ingredients(recipe_id: String = RECIPE_P0) -> Dictionary:
	return start_preparation(recipe_id)

func start_preparation(recipe_id: String = RECIPE_P0) -> Dictionary:
	# Anti-spam guard: jika job sedang aktif, tolak secara idempotent tanpa mutasi ganda
	if is_job_active():
		return {
			"success": false,
			"reason": "Job ID sudah aktif.",
			"job_id": active_job_id,
			"idempotent": true
		}

	var validation := can_start_preparation(recipe_id)
	if not validation.get("success", false):
		action_failed.emit(validation.get("reason", "Gagal memulai persiapan."))
		return validation

	var inv := _get_inventory()
	var rm := _get_recipe_manager()
	var recipe_res: Resource = null
	if rm != null and rm.has_method("get_recipe"):
		recipe_res = rm.get_recipe(recipe_id)

	var req_ingredients: Dictionary = {}
	if recipe_res != null and "ingredients" in recipe_res:
		req_ingredients = recipe_res.ingredients
	elif recipe_id == RECIPE_P0 or recipe_id == "recipe_sayur_bening_01":
		req_ingredients = {
			"ingredient_bayam": 3,
			"ingredient_jagung": 1,
			"ingredient_temu_kunci": 1
		}

	_job_counter += 1
	var clean_recipe_name := recipe_id.trim_prefix("recipe_")
	active_job_id = "job_%s_%d" % [clean_recipe_name, _job_counter]
	active_recipe_id = recipe_id

	var bp_c = inv.get_container("backpack") if inv.has_method("get_container") else inv.get("backpack")
	var st_c = inv.get_container("storage") if inv.has_method("get_container") else inv.get("storage_home")

	var reserved: Array[Dictionary] = []
	var origins: Array[Dictionary] = []

	# Urutan penarikan fisik: tas dahulu (indeks terkecil), lalu peti rumah
	for it_id in req_ingredients:
		var needed: int = int(req_ingredients[it_id])
		reserved.append({"item_id": it_id, "count": needed})

		# 1. Ambil dari tas
		var from_bp: int = 0
		if bp_c != null and bp_c.has_method("get_item_count") and bp_c.has_method("remove_item"):
			from_bp = mini(needed, bp_c.get_item_count(it_id))
			if from_bp > 0:
				bp_c.remove_item(it_id, from_bp)
				origins.append({
					"container": "backpack",
					"source": "backpack",
					"item_id": it_id,
					"count": from_bp
				})
				needed -= from_bp

		# 2. Ambil sisa dari peti penyimpanan
		if needed > 0 and st_c != null and st_c.has_method("get_item_count") and st_c.has_method("remove_item"):
			var from_st: int = mini(needed, st_c.get_item_count(it_id))
			if from_st > 0:
				st_c.remove_item(it_id, from_st)
				origins.append({
					"container": "storage",
					"source": "storage",
					"item_id": it_id,
					"count": from_st
				})
				needed -= from_st

	reserved_ingredients = reserved
	origin_manifest = origins
	prep_progress = 0.0

	current_job = {
		"id": active_job_id,
		"job_id": active_job_id,
		"recipe_id": recipe_id,
		"reserved_items": reserved,
		"origin_records": origins,
		"origin_manifest": origins,
		"prep_progress": 0.0,
		"prep_duration": prep_duration
	}

	job_state = JobState.RESERVED_PREPARING
	if rm != null and rm.has_method("set_cooking_state"):
		rm.set_cooking_state("preparing")

	job_started.emit(active_job_id, recipe_id)
	prep_started.emit(active_job_id, prep_duration)
	if inv.has_signal("inventory_updated"):
		inv.inventory_updated.emit()

	return {
		"success": true,
		"job_id": active_job_id,
		"reserved_items": reserved,
		"origin_records": origins,
		"origin_manifest": origins
	}

# --- Preparation Hold Progression (T12) ---

func start_prep() -> void:
	pass

func advance_prep(delta: float) -> void:
	if job_state != JobState.RESERVED_PREPARING:
		return

	prep_progress = clampf(prep_progress + delta, 0.0, prep_duration)
	if not current_job.is_empty():
		current_job["prep_progress"] = prep_progress

	var progress_fraction := prep_progress / prep_duration
	prep_progress_updated.emit(active_job_id, progress_fraction, prep_progress, prep_duration)
	preparation_progress_changed.emit(prep_progress, prep_duration)

	# 4.0s selesai -> transisi ke READY_TO_HEAT (tidak otomatis memasak)
	if prep_progress >= prep_duration:
		job_state = JobState.READY_TO_HEAT
		var rm := _get_recipe_manager()
		if rm != null and rm.has_method("set_cooking_state"):
			rm.set_cooking_state("ready_to_heat")
		prep_completed.emit(active_job_id)
		preparation_completed.emit(active_job_id)

func tick_preparation(delta: float) -> void:
	advance_prep(delta)

func hold_tick(delta: float, is_button_pressed: bool) -> void:
	if job_state != JobState.RESERVED_PREPARING:
		return
	if is_button_pressed:
		advance_prep(delta)
	# Catatan: jika tombol dilepas sebelum 4.0s, progress dipertahankan (CONTENT.md § 4)

# --- Pre-Cooking Cancellation & Safe 3-Tier Refund (T13, T40) ---

func cancel_preparation() -> Dictionary:
	if job_state != JobState.RESERVED_PREPARING and job_state != JobState.READY_TO_HEAT:
		return {"success": false, "reason": "Tidak ada persiapan yang dapat dibatalkan."}

	var inv := _get_inventory()
	var bp_c = inv.get_container("backpack") if inv.has_method("get_container") else inv.get("backpack")
	var st_c = inv.get_container("storage") if inv.has_method("get_container") else inv.get("storage_home")
	var rf_c = inv.get_container("kitchen_refund") if inv.has_method("get_container") else inv.get("kitchen_refund")

	var refund_log: Array[Dictionary] = []
	var spilled_to_refund: bool = false
	var refund_spill_items: Array[Dictionary] = []

	# Pengembalian aman berjenjang (3-Tier Safe Refund)
	for entry in origin_manifest:
		var c_name: String = str(entry.get("container", entry.get("source", "backpack")))
		var it_id: String = str(entry.get("item_id", ""))
		var count_to_refund: int = int(entry.get("count", 0))

		var primary_c = bp_c if c_name == "backpack" else st_c
		var alt_c = st_c if c_name == "backpack" else bp_c

		# Tingkat 1: Kembalikan ke kontainer asal
		var rem: int = count_to_refund
		if primary_c != null and primary_c.has_method("add_item"):
			rem = primary_c.add_item(it_id, count_to_refund)
		var added_prim: int = count_to_refund - rem
		if added_prim > 0:
			refund_log.append({"item_id": it_id, "count": added_prim, "destination": c_name})

		# Tingkat 2: Jika asal penuh, kembalikan ke kontainer alternatif
		if rem > 0 and alt_c != null and alt_c.has_method("add_item"):
			var rem_alt: int = alt_c.add_item(it_id, rem)
			var added_alt: int = rem - rem_alt
			if added_alt > 0:
				var alt_name := "storage" if c_name == "backpack" else "backpack"
				refund_log.append({"item_id": it_id, "count": added_alt, "destination": alt_name})
			rem = rem_alt

		# Tingkat 3: Jika keduanya penuh, alihkan ke wadah kitchen_refund persisten
		if rem > 0 and rf_c != null and rf_c.has_method("add_item"):
			rf_c.add_item(it_id, rem)
			spilled_to_refund = true
			refund_spill_items.append({"item_id": it_id, "count": rem})
			refund_log.append({"item_id": it_id, "count": rem, "destination": "kitchen_refund"})

		# Invarian: Bahan mentah DILARANG KERAS masuk ke slot hasil masakan (dish_output_slot)

	var old_job_id := active_job_id
	var old_reserved := reserved_ingredients.duplicate(true)

	active_job_id = ""
	active_recipe_id = ""
	current_job.clear()
	reserved_ingredients.clear()
	origin_manifest.clear()
	prep_progress = 0.0

	job_state = JobState.IDLE

	var rm := _get_recipe_manager()
	if rm != null and rm.has_method("set_cooking_state"):
		rm.set_cooking_state("idle")

	if spilled_to_refund:
		kitchen_refund_occurred.emit(refund_spill_items)
		refund_storage_updated.emit()

	prep_cancelled.emit(old_job_id)
	job_cancelled.emit(old_job_id, old_reserved)

	if inv != null and inv.has_signal("inventory_updated"):
		inv.inventory_updated.emit()

	return {
		"success": true,
		"reason": "Persiapan dibatalkan. Bahan telah dikembalikan.",
		"refund_log": refund_log,
		"refunded_items": old_reserved,
		"spilled_to_refund": spilled_to_refund
	}

func cancel_current_job() -> Dictionary:
	return cancel_preparation()

# --- Refund Storage Claiming ---

func claim_refund_items() -> Dictionary:
	var inv := _get_inventory()
	if inv == null:
		return {"success": false, "reason": "InventoryManager tidak tersedia."}

	var bp_c = inv.get_container("backpack") if inv.has_method("get_container") else inv.get("backpack")
	var rf_c = inv.get_container("kitchen_refund") if inv.has_method("get_container") else inv.get("kitchen_refund")

	if rf_c == null or bp_c == null:
		return {"success": false, "reason": "Kontainer tidak ditemukan."}

	var claimed_any: bool = false
	var slots: Array = rf_c.get_slots() if rf_c.has_method("get_slots") else []
	for i in range(slots.size()):
		var slot = slots[i]
		if slot != null and not slot.is_empty():
			var it_id: String = str(slot.get("item_id"))
			var it_cnt: int = int(slot.get("count"))
			if it_cnt > 0:
				var rem: int = bp_c.add_item(it_id, it_cnt)
				var transferred: int = it_cnt - rem
				if transferred > 0:
					rf_c.remove_item(it_id, transferred)
					claimed_any = true

	if claimed_any:
		if inv.has_signal("inventory_updated"):
			inv.inventory_updated.emit()
		refund_storage_updated.emit()
		return {"success": true, "reason": "Barang pengembalian berhasil diambil."}

	return {"success": false, "reason": "Tas penuh atau tidak ada barang di wadah pengembalian."}

# --- Cooking & Heat Control (COOK-002) ---

func set_heat_level(level: Variant) -> bool:
	var old_level := current_heat_level
	var target_level := HeatLevel.LOW

	if level is int:
		match level:
			HeatLevel.LOW: target_level = HeatLevel.LOW
			HeatLevel.MEDIUM: target_level = HeatLevel.MEDIUM
			HeatLevel.HIGH: target_level = HeatLevel.HIGH
			_: target_level = HeatLevel.LOW
	elif level is String:
		match level.to_lower():
			"low", "rendah": target_level = HeatLevel.LOW
			"medium", "sedang": target_level = HeatLevel.MEDIUM
			"high", "tinggi": target_level = HeatLevel.HIGH
			_: target_level = HeatLevel.LOW

	current_heat_level = target_level

	if old_level != target_level:
		heat_level_changed.emit(int(target_level), int(old_level))
		heat_changed.emit(current_heat)

	if target_level == HeatLevel.HIGH:
		heat_stall_warning.emit(STALL_WARNING_HIGH_HEAT)
		heat_stalled.emit(STALL_WARNING_HIGH_HEAT)

	return true

func get_heat_multiplier() -> float:
	return float(HEAT_MULTIPLIERS.get(current_heat_level, 1.0))

func is_heat_stalled() -> bool:
	return current_heat_level == HeatLevel.HIGH

func start_cooking(initial_heat: Variant = HeatLevel.LOW) -> Dictionary:
	if job_state == JobState.COOKING:
		return {"success": false, "reason": "Sedang memasak.", "idempotent": true}

	if job_state != JobState.READY_TO_HEAT and job_state != JobState.PAUSED:
		return {"success": false, "reason": "Persiapan belum selesai."}

	set_heat_level(initial_heat)
	job_state = JobState.COOKING

	var rm := _get_recipe_manager()
	if rm != null and rm.has_method("set_cooking_state"):
		rm.set_cooking_state("cooking")

	cooking_started.emit(active_job_id, cook_duration)
	return {"success": true, "job_id": active_job_id}

func advance_cooking(delta: float) -> Dictionary:
	if job_state != JobState.COOKING:
		return {"success": false, "reason": "Bukan dalam proses memasak aktif."}

	var mult: float = get_heat_multiplier()
	if mult > 0.0:
		cook_progress = clampf(cook_progress + (delta * mult), 0.0, cook_duration)
		var frac := cook_progress / cook_duration
		cooking_progress_updated.emit(active_job_id, frac, cook_progress, cook_duration)
		cook_progress_updated.emit(active_job_id, frac, cook_progress, cook_duration)
		cook_progress_changed.emit(cook_progress, cook_duration)

		if cook_progress >= cook_duration:
			_complete_cooking()
			return {"success": true, "completed": true, "progress": cook_progress}
		return {"success": true, "completed": false, "progress": cook_progress}
	else:
		heat_stall_warning.emit(STALL_WARNING_HIGH_HEAT)
		heat_stalled.emit(STALL_WARNING_HIGH_HEAT)
		return {"success": true, "completed": false, "stalled": true, "progress": cook_progress}

func pause_cooking() -> Dictionary:
	if job_state == JobState.COOKING:
		job_state = JobState.PAUSED
		var rm := _get_recipe_manager()
		if rm != null and rm.has_method("set_cooking_state"):
			rm.set_cooking_state("paused")
		cooking_paused.emit(active_job_id)
		return {"success": true, "reason": "Memasak dijeda."}
	return {"success": false, "reason": "Tidak sedang memasak aktif."}

func resume_cooking() -> Dictionary:
	if job_state == JobState.PAUSED:
		job_state = JobState.COOKING
		var rm := _get_recipe_manager()
		if rm != null and rm.has_method("set_cooking_state"):
			rm.set_cooking_state("cooking")
		cooking_resumed.emit(active_job_id)
		return {"success": true, "reason": "Memasak dilanjutkan."}
	return {"success": false, "reason": "Tidak dalam kondisi jeda."}

func _complete_cooking() -> void:
	job_state = JobState.OUTPUT_READY
	cook_progress = cook_duration
	dish_output_slot = {
		"item_id": DISH_ITEM_ID,
		"count": 1
	}

	reserved_ingredients.clear()
	origin_manifest.clear()
	if not current_job.is_empty():
		current_job["output_committed"] = true
		current_job["completed"] = true
		current_job["cook_progress"] = cook_duration

	var rm := _get_recipe_manager()
	if rm != null:
		if rm.has_method("record_recipe_cooked"):
			rm.record_recipe_cooked(active_recipe_id)
		if rm.has_method("set_cooking_state"):
			rm.set_cooking_state("output_ready")

	cooking_completed.emit(active_job_id, dish_output_slot.duplicate(true))
	cook_completed.emit(active_job_id, dish_output_slot.duplicate(true))

# --- Output Dish Helpers (T15) ---

func get_dish_output() -> Dictionary:
	return dish_output_slot.duplicate(true)

func take_dish_output() -> Dictionary:
	var out := dish_output_slot.duplicate(true)
	dish_output_slot.clear()
	if job_state == JobState.OUTPUT_READY:
		job_state = JobState.IDLE
		active_job_id = ""
		active_recipe_id = ""
		current_job.clear()
		cook_progress = 0.0
		prep_progress = 0.0
		var rm := _get_recipe_manager()
		if rm != null and rm.has_method("set_cooking_state"):
			rm.set_cooking_state("idle")
	return out

func claim_dish_output() -> Dictionary:
	if not has_ready_output():
		return {"success": false, "reason": "Tidak ada masakan yang siap diambil."}

	var inv := _get_inventory()
	if inv == null:
		return {"success": false, "reason": "InventoryManager tidak tersedia."}

	var bp_c = inv.get_container("backpack") if inv.has_method("get_container") else inv.get("backpack")
	if bp_c == null:
		return {"success": false, "reason": "Tas tidak ditemukan."}

	var it_id: String = str(dish_output_slot.get("item_id", DISH_ITEM_ID))
	var cnt: int = int(dish_output_slot.get("count", 1))

	var can_add: bool = true
	if bp_c.has_method("can_add_item"):
		can_add = bp_c.can_add_item(it_id, cnt)
	elif bp_c.has_method("can_add"):
		can_add = bp_c.can_add(it_id, cnt)

	if not can_add:
		return {
			"success": false,
			"reason": "Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."
		}

	var rem: int = 0
	if bp_c.has_method("add_item"):
		rem = bp_c.add_item(it_id, cnt)
	elif bp_c.has_method("add"):
		rem = bp_c.add(it_id, cnt)

	if rem > 0:
		return {
			"success": false,
			"reason": "Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."
		}

	var collected_dish := dish_output_slot.duplicate(true)
	dish_output_slot.clear()
	active_job_id = ""
	active_recipe_id = ""
	current_job.clear()
	cook_progress = 0.0
	prep_progress = 0.0
	job_state = JobState.IDLE

	var rm := _get_recipe_manager()
	if rm != null and rm.has_method("set_cooking_state"):
		rm.set_cooking_state("idle")

	dish_collected.emit(it_id, cnt)
	if inv.has_signal("inventory_updated"):
		inv.inventory_updated.emit()

	return {
		"success": true,
		"reason": "Hidangan berhasil diambil ke dalam tas.",
		"dish": collected_dish
	}

# --- Action Eat Dish (T43) ---

func eat_dish(item_id: String = DISH_ITEM_ID) -> Dictionary:
	var inv := _get_inventory()
	if inv == null:
		return {"success": false, "reason": "InventoryManager tidak tersedia."}

	var bp_c = inv.get_container("backpack") if inv.has_method("get_container") else inv.get("backpack")
	if bp_c == null:
		return {"success": false, "reason": "Tas tidak ditemukan."}

	var count: int = 0
	if bp_c.has_method("get_item_count"):
		count = bp_c.get_item_count(item_id)
	elif bp_c.has_method("count_item"):
		count = bp_c.count_item(item_id)

	if count <= 0:
		return {
			"success": false,
			"reason": "Tidak ada hidangan di tas untuk dimakan.",
			"message": "Tidak ada hidangan di tas untuk dimakan.",
			"meal_used": meal_used
		}

	if bp_c.has_method("remove_item"):
		bp_c.remove_item(item_id, 1)
	elif bp_c.has_method("remove"):
		bp_c.remove(item_id, 1)

	meal_used = true

	# Sinkronkan ke WorldResourceManager
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null and tree.root.has_node("WorldResourceManager"):
		var wrm = tree.root.get_node("WorldResourceManager")
		if wrm != null and wrm.has_method("set_meal_used"):
			wrm.set_meal_used(true)
	elif Engine.has_singleton("WorldResourceManager"):
		var wrm = Engine.get_singleton("WorldResourceManager")
		if wrm != null and wrm.has_method("set_meal_used"):
			wrm.set_meal_used(true)

	dish_consumed.emit(item_id)
	meal_consumed.emit(item_id)

	if inv.has_signal("inventory_updated"):
		inv.inventory_updated.emit()

	var rm := _get_recipe_manager()
	var is_recipe_done: bool = rm != null and rm.has_method("is_recipe_completed") and rm.is_recipe_completed(RECIPE_P0)

	var dm := _get_dialogue_manager()
	var dm_already_completed: bool = dm != null and dm.has_method("is_p0_completed") and dm.is_p0_completed()
	if not p0_completed and dm_already_completed:
		p0_completed = true

	if is_recipe_done and meal_used and not p0_completed:
		p0_completed = true
		if dm != null:
			dm.set("p0_completed", true)
			dm.set("meal_used", true)
		p0_experience_completed.emit()

	return {
		"success": true,
		"message": "Hangat. Resep pertama berhasil dibuat.",
		"reason": "Hangat. Resep pertama berhasil dibuat.",
		"meal_used": true,
		"p0_completed": is_recipe_done and meal_used
	}

# --- Save & Load Envelope (SAVE-001) ---

func get_save_snapshot() -> Dictionary:
	return {
		"version": 1,
		"job_state": int(job_state),
		"active_job_id": active_job_id,
		"active_recipe_id": active_recipe_id,
		"prep_progress": prep_progress,
		"prep_duration": prep_duration,
		"cook_progress": cook_progress,
		"cook_duration": cook_duration,
		"heat_level": int(current_heat_level),
		"current_heat": current_heat,
		"meal_used": meal_used,
		"p0_completed": p0_completed,
		"reserved_ingredients": reserved_ingredients.duplicate(true),
		"origin_manifest": origin_manifest.duplicate(true),
		"origin_records": origin_manifest.duplicate(true),
		"dish_output_slot": dish_output_slot.duplicate(true),
		"current_job": current_job.duplicate(true)
	}

func load_save_snapshot(data: Dictionary) -> bool:
	if not data is Dictionary or data.is_empty():
		return false

	job_state = int(data.get("job_state", JobState.IDLE)) as JobState
	active_job_id = str(data.get("active_job_id", ""))
	active_recipe_id = str(data.get("active_recipe_id", ""))
	prep_progress = float(data.get("prep_progress", 0.0))
	prep_duration = float(data.get("prep_duration", PREP_DURATION))
	cook_progress = float(data.get("cook_progress", 0.0))
	cook_duration = float(data.get("cook_duration", COOK_DURATION))

	if data.has("heat_level"):
		set_heat_level(int(data.get("heat_level")))
	elif data.has("current_heat"):
		set_heat_level(str(data.get("current_heat")))

	meal_used = bool(data.get("meal_used", false))
	p0_completed = bool(data.get("p0_completed", false))

	reserved_ingredients.clear()
	for it in data.get("reserved_ingredients", []):
		if it is Dictionary:
			reserved_ingredients.append(it.duplicate(true))

	origin_manifest.clear()
	for it in data.get("origin_manifest", data.get("origin_records", [])):
		if it is Dictionary:
			origin_manifest.append(it.duplicate(true))

	dish_output_slot = data.get("dish_output_slot", {}).duplicate(true)
	current_job = data.get("current_job", {}).duplicate(true)

	var rm := _get_recipe_manager()
	if rm != null and rm.has_method("set_cooking_state"):
		match job_state:
			JobState.IDLE: rm.set_cooking_state("idle")
			JobState.RESERVED_PREPARING: rm.set_cooking_state("preparing")
			JobState.READY_TO_HEAT: rm.set_cooking_state("ready_to_heat")
			JobState.COOKING: rm.set_cooking_state("cooking")
			JobState.PAUSED: rm.set_cooking_state("paused")
			JobState.OUTPUT_READY: rm.set_cooking_state("output_ready")

	return true
