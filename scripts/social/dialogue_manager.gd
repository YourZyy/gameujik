extends Node

## Pengendali Percakapan Warga, Logika Berbagi Hidangan, dan Penutup P0
## Memenuhi spesifikasi PRD FR13, FR14, FR21, CONTENT.md § 10, § 11, § 12,
## PROTOTYPE.md § 5, TASKS.md SOC-001, dan TEST_PLAN T43, T44, T45.

const NODE_INTRO: String = "npc_intro"
const NODE_HINT_BAYAM: String = "npc_hint_bayam"
const NODE_HINT_KUNCI: String = "npc_hint_kunci"
const NODE_WAITING: String = "npc_waiting"
const NODE_OFFER: String = "npc_offer"
const NODE_RECEIVED: String = "npc_received"
const NODE_REPEAT: String = "npc_repeat"

const DISH_ID: String = "dish_sayur_bening"
const RECIPE_P0_ID: String = "recipe_sayur_bening_01"
const MSG_P0_ENDING: String = "Satu resep selesai. Kebun ini baru dimulai."

# Sinyal siklus hidup dialog
signal dialogue_started(npc_id: String, node_id: String)
signal dialogue_node_changed(node_id: String, data: Dictionary)
signal node_changed(data: Dictionary)
signal dialogue_choice_selected(choice_id: String, target_node: String)
signal dialogue_closed(npc_id: String)
signal dialogue_ended()

# Sinyal transaksi hidangan & penutup P0
signal dish_shared(item_id: String, count: int, source: String)
signal meal_shared(source: String, remaining_count: int)
signal meal_consumed(item_id: String, count: int)
signal p0_experience_completed(message: String)
signal action_failed(reason: String)
signal action_success(action_name: String, message: String)

# State internal percakapan dan progres
var has_spoken_intro: bool = false
var _has_shared_meal: bool = false
var meal_used: bool = false
var p0_completed: bool = false
var dialogue_flags: Dictionary = {}

var current_npc_id: String = ""
var _current_node_id: String = ""
var _is_dialogue_active: bool = false

# Overrides untuk pengujian hermetis (headless test runner)
var _inventory_override: Node = null
var _recipe_override: Node = null
var _world_override: Node = null
var _kitchen_override: Node = null
var _input_override: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func bind_managers(inv: Node = null, rm: Node = null, wrm: Node = null, km: Node = null, im: Node = null) -> void:
	_inventory_override = inv
	_recipe_override = rm
	_world_override = wrm
	_kitchen_override = km
	_input_override = im
	if km != null and km.has_method("set_dialogue_manager"):
		km.set_dialogue_manager(self)

func reset_state() -> void:
	has_spoken_intro = false
	_has_shared_meal = false
	meal_used = false
	p0_completed = false
	dialogue_flags.clear()
	current_npc_id = ""
	_current_node_id = ""
	_is_dialogue_active = false

# --- Query & Setter Status ---

func has_shared_meal() -> bool:
	return _has_shared_meal

func is_meal_used() -> bool:
	if meal_used or _has_shared_meal:
		return true
	var wrm := _get_world_resource_manager()
	if wrm != null and wrm.has_method("is_meal_used") and wrm.is_meal_used():
		meal_used = true
		return true
	var km := _get_kitchen_manager()
	if km != null and bool(km.get("meal_used")) == true:
		meal_used = true
		return true
	return false

func is_p0_completed() -> bool:
	if p0_completed:
		return true
	var km := _get_kitchen_manager()
	if km != null and bool(km.get("p0_completed")) == true:
		p0_completed = true
		return true
	return false

func evaluate_p0_closure() -> bool:
	if is_p0_completed():
		return true

	var rm := _get_recipe_manager()
	var recipe_done: bool = rm != null and rm.has_method("is_recipe_completed") and rm.is_recipe_completed(RECIPE_P0_ID)
	var used: bool = is_meal_used()

	if recipe_done and used and not p0_completed:
		p0_completed = true

		var km := _get_kitchen_manager()
		if km != null:
			km.set("p0_completed", true)

		p0_experience_completed.emit(MSG_P0_ENDING)
		action_success.emit("p0_experience_completed", MSG_P0_ENDING)
		return true

	return p0_completed

func has_talked_to_npc() -> bool:
	return has_spoken_intro

func set_has_shared(val: bool) -> void:
	_has_shared_meal = val
	if val:
		meal_used = true

func set_has_shared_meal(val: bool) -> void:
	set_has_shared(val)

func set_talked_to_npc(val: bool) -> void:
	has_spoken_intro = val

func get_current_node_id() -> String:
	return _current_node_id

func get_current_text() -> String:
	var data := get_dialogue_node(_current_node_id)
	return str(data.get("text", ""))

func get_current_node_data() -> Dictionary:
	return get_dialogue_node(_current_node_id)

func is_dialogue_active() -> bool:
	return _is_dialogue_active

# --- Evaluasi Ketersediaan Hidangan ---

func has_dish() -> bool:
	var inv := _get_inventory_manager()
	if inv == null:
		return false
	var bp_count: int = 0
	var st_count: int = 0
	if "backpack" in inv and inv.backpack != null and inv.backpack.has_method("get_item_count"):
		bp_count = inv.backpack.get_item_count(DISH_ID)
	if "storage_home" in inv and inv.storage_home != null and inv.storage_home.has_method("get_item_count"):
		st_count = inv.storage_home.get_item_count(DISH_ID)
	return (bp_count + st_count) >= 1

func get_dish_source() -> String:
	var inv := _get_inventory_manager()
	if inv == null:
		return ""
	if "backpack" in inv and inv.backpack != null and inv.backpack.has_method("get_item_count"):
		if inv.backpack.get_item_count(DISH_ID) >= 1:
			return "backpack"
	if "storage_home" in inv and inv.storage_home != null and inv.storage_home.has_method("get_item_count"):
		if inv.storage_home.get_item_count(DISH_ID) >= 1:
			return "storage"
	return ""

# --- Alur Pohon Percakapan ---

func get_starting_dialogue_node(npc_id: String = "npc_neighbor_01") -> String:
	if _has_shared_meal:
		return NODE_REPEAT
	elif has_dish():
		if not has_spoken_intro:
			return NODE_INTRO
		else:
			return NODE_OFFER
	else:
		if not has_spoken_intro:
			return NODE_INTRO
		else:
			return NODE_WAITING

func start_dialogue(npc_id: String = "npc_neighbor_01", initial_node: String = "") -> Dictionary:
	current_npc_id = npc_id
	_is_dialogue_active = true

	var target_node := initial_node
	if target_node.is_empty():
		target_node = get_starting_dialogue_node(npc_id)

	return _transition_to_node(target_node)

func _transition_to_node(node_id: String) -> Dictionary:
	_current_node_id = node_id
	if node_id == NODE_INTRO:
		has_spoken_intro = true

	var node_data := get_dialogue_node(node_id)
	dialogue_node_changed.emit(node_id, node_data)
	node_changed.emit(node_data)
	dialogue_started.emit(current_npc_id, node_id)
	return node_data

func get_dialogue_node(node_id: String) -> Dictionary:
	match node_id:
		NODE_INTRO:
			var choices: Array = [
				{"id": "choice_hint_bayam", "text": "Bayamnya dari mana?", "target_node": NODE_HINT_BAYAM},
				{"id": "choice_hint_kunci", "text": "Temu kunci?", "target_node": NODE_HINT_KUNCI}
			]
			if has_dish() and not _has_shared_meal:
				choices.append({"id": "choice_share", "text": "Bagikan 1 porsi", "target_node": NODE_OFFER})
			choices.append({"id": "choice_close", "text": "Tutup", "target_node": ""})

			return {
				"id": NODE_INTRO,
				"speaker": "Tetangga",
				"text": "Masih menyimpan buku itu? Coba lihat kebun di ujung jalan. Jagungnya belum semua habis.",
				"choices": choices
			}

		NODE_HINT_BAYAM:
			var choices: Array = [
				{"id": "choice_hint_kunci", "text": "Temu kunci?", "target_node": NODE_HINT_KUNCI}
			]
			if has_dish() and not _has_shared_meal:
				choices.append({"id": "choice_share", "text": "Bagikan 1 porsi", "target_node": NODE_OFFER})
			choices.append({"id": "choice_back_intro", "text": "Kembali", "target_node": NODE_INTRO})
			choices.append({"id": "choice_close", "text": "Tutup", "target_node": ""})

			return {
				"id": NODE_HINT_BAYAM,
				"speaker": "Tetangga",
				"text": "Ada benih di dekat alat. Petaknya memang lama tidak dipakai. Gemburkan dulu, baru tambah pembenah.",
				"choices": choices
			}

		NODE_HINT_KUNCI:
			var choices: Array = [
				{"id": "choice_hint_bayam", "text": "Bayamnya dari mana?", "target_node": NODE_HINT_BAYAM}
			]
			if has_dish() and not _has_shared_meal:
				choices.append({"id": "choice_share", "text": "Bagikan 1 porsi", "target_node": NODE_OFFER})
			choices.append({"id": "choice_back_intro", "text": "Kembali", "target_node": NODE_INTRO})
			choices.append({"id": "choice_close", "text": "Tutup", "target_node": ""})

			return {
				"id": NODE_HINT_KUNCI,
				"speaker": "Tetangga",
				"text": "Di tepi bambu, dekat batu besar. Daunnya lebih rendah dari rumpunnya.",
				"choices": choices
			}

		NODE_WAITING:
			var choices: Array = [
				{"id": "choice_hint_bayam", "text": "Bayamnya dari mana?", "target_node": NODE_HINT_BAYAM},
				{"id": "choice_hint_kunci", "text": "Temu kunci?", "target_node": NODE_HINT_KUNCI}
			]
			if has_dish() and not _has_shared_meal:
				choices.append({"id": "choice_share", "text": "Bagikan 1 porsi", "target_node": NODE_OFFER})
			choices.append({"id": "choice_close", "text": "Tutup", "target_node": ""})

			return {
				"id": NODE_WAITING,
				"speaker": "Tetangga",
				"text": "Tidak perlu buru-buru. Yang penting tahu apa yang masih bisa ditanam.",
				"choices": choices
			}

		NODE_OFFER:
			return {
				"id": NODE_OFFER,
				"speaker": "Tetangga",
				"text": "Harum sekali. Kamu memasak Sayur Bening Bayam dan Jagung?",
				"choices": [
					{"id": "choice_share_confirm", "text": "Bagikan 1 porsi", "action": "share"},
					{"id": "choice_share_cancel", "text": "Nanti dulu", "target_node": NODE_WAITING}
				]
			}

		NODE_RECEIVED:
			return {
				"id": NODE_RECEIVED,
				"speaker": "Tetangga",
				"text": "Masih ingat rasanya. Besok, sisakan tempat buat menanam lagi.",
				"choices": [
					{"id": "choice_close", "text": "Tutup", "target_node": ""}
				]
			}

		NODE_REPEAT:
			return {
				"id": NODE_REPEAT,
				"speaker": "Tetangga",
				"text": "Kebun kecil juga perlu diteruskan. Jangan berhenti di satu panci.",
				"choices": [
					{"id": "choice_close", "text": "Tutup", "target_node": ""}
				]
			}

		_:
			return {}

func on_dialogue_choice(choice_id: String) -> Dictionary:
	dialogue_choice_selected.emit(choice_id, "")

	match choice_id:
		"choice_share_confirm", "action_share", "share_dish":
			var share_res := share_dish("auto")
			return share_res

		"choice_share_cancel", "choice_cancel", "cancel_share", "later":
			var node_data := _transition_to_node(NODE_WAITING)
			return {
				"success": true,
				"cancelled": true,
				"node_id": NODE_WAITING,
				"node": node_data
			}

		"choice_close", "close":
			close_dialogue()
			return {"success": true, "closed": true}

		"choice_hint_bayam", "hint_bayam":
			return _transition_to_node(NODE_HINT_BAYAM)

		"choice_hint_kunci", "hint_kunci":
			return _transition_to_node(NODE_HINT_KUNCI)

		"choice_back_intro", "choice_back", "back_intro":
			return _transition_to_node(NODE_INTRO)

		"choice_share":
			return _transition_to_node(NODE_OFFER)

		_:
			action_failed.emit("Pilihan dialog tidak dikenal: %s" % choice_id)
			return {
				"success": false,
				"reason": "Pilihan dialog tidak dikenal: %s" % choice_id,
				"node_id": _current_node_id
			}

func select_choice(choice_id: String) -> Dictionary:
	return on_dialogue_choice(choice_id)

func close_dialogue() -> void:
	if not _is_dialogue_active:
		return
	_is_dialogue_active = false
	var prev_npc := current_npc_id
	current_npc_id = ""
	dialogue_closed.emit(prev_npc)
	dialogue_ended.emit()

func end_dialogue() -> void:
	close_dialogue()

# --- Aksi Berbagi Hidangan & Penutup P0 ---

func share_dish(from_source: String = "auto") -> Dictionary:
	# Anti-spam guard: jika hidangan sudah pernah dibagikan ke tetangga
	if _has_shared_meal:
		action_failed.emit("Hidangan sudah pernah dibagikan kepada tetangga.")
		return {
			"success": false,
			"reason": "Hidangan sudah pernah dibagikan kepada tetangga.",
			"idempotent": true
		}

	var inv := _get_inventory_manager()
	if inv == null:
		action_failed.emit("InventoryManager tidak tersedia.")
		return {"success": false, "reason": "InventoryManager tidak tersedia."}

	var bp_count: int = 0
	var st_count: int = 0
	if "backpack" in inv and inv.backpack != null and inv.backpack.has_method("get_item_count"):
		bp_count = inv.backpack.get_item_count(DISH_ID)
	if "storage_home" in inv and inv.storage_home != null and inv.storage_home.has_method("get_item_count"):
		st_count = inv.storage_home.get_item_count(DISH_ID)

	var source_to_use: String = ""
	if from_source == "backpack":
		if bp_count < 1:
			action_failed.emit("Hidangan tidak cukup di tas.")
			return {"success": false, "reason": "Hidangan tidak cukup di tas."}
		source_to_use = "backpack"
	elif from_source == "storage":
		if st_count < 1:
			action_failed.emit("Hidangan tidak cukup di peti rumah.")
			return {"success": false, "reason": "Hidangan tidak cukup di peti rumah."}
		source_to_use = "storage"
	else: # "auto"
		if bp_count >= 1:
			source_to_use = "backpack"
		elif st_count >= 1:
			source_to_use = "storage"
		else:
			action_failed.emit("Tidak ada hidangan Sayur Bening untuk dibagikan.")
			return {"success": false, "reason": "Tidak ada hidangan Sayur Bening untuk dibagikan."}

	# Pemotongan atomik 1 unit
	var removed: bool = false
	if source_to_use == "backpack":
		removed = inv.backpack.remove_item(DISH_ID, 1)
	else:
		removed = inv.storage_home.remove_item(DISH_ID, 1)

	if not removed:
		action_failed.emit("Gagal memotong hidangan dari penyimpanan.")
		return {"success": false, "reason": "Gagal memotong hidangan dari penyimpanan."}

	# Sinkronisasi status
	_has_shared_meal = true
	meal_used = true

	var wrm := _get_world_resource_manager()
	if wrm != null and wrm.has_method("set_meal_used"):
		wrm.set_meal_used(true)

	var km := _get_kitchen_manager()
	if km != null:
		km.set("meal_used", true)

	# Transisi node percakapan ke respon penerimaan warga
	_current_node_id = NODE_RECEIVED
	var received_data := get_dialogue_node(NODE_RECEIVED)
	dialogue_node_changed.emit(NODE_RECEIVED, received_data)
	node_changed.emit(received_data)

	# Emisi sinyal transaksi
	dish_shared.emit(DISH_ID, 1, source_to_use)
	var rem_count: int = 0
	if inv.has_method("get_available_item_count"):
		rem_count = inv.get_available_item_count(DISH_ID)
	meal_shared.emit(source_to_use, rem_count)
	meal_consumed.emit(DISH_ID, 1)

	# Evaluasi kondisi penutup P0 terpusat via evaluate_p0_closure()
	var was_already_p0: bool = is_p0_completed()
	evaluate_p0_closure()
	var newly_completed_p0: bool = not was_already_p0 and is_p0_completed()

	action_success.emit("share_dish", "Hidangan berhasil dibagikan.")

	return {
		"success": true,
		"source": source_to_use,
		"item_id": DISH_ID,
		"count": 1,
		"p0_completed": p0_completed,
		"newly_completed_p0": newly_completed_p0,
		"message": MSG_P0_ENDING if p0_completed else "Hidangan berhasil dibagikan."
	}

func share_meal(from_source: String = "auto") -> Dictionary:
	return share_dish(from_source)

# --- Save / Load Envelope ---

func get_save_snapshot() -> Dictionary:
	return {
		"version": 1,
		"has_spoken_intro": has_spoken_intro,
		"has_shared_meal": _has_shared_meal,
		"has_shared": _has_shared_meal,
		"talked_to_npc": has_spoken_intro,
		"meal_used": meal_used,
		"p0_completed": p0_completed,
		"dialogue_flags": dialogue_flags.duplicate(true)
	}

static func _parse_bool_safe(val: Variant, default_val: bool = false) -> bool:
	if val == null:
		return default_val
	if val is bool:
		return val
	if val is int or val is float:
		return val != 0
	if val is String:
		var s: String = str(val).strip_edges().to_lower()
		if s == "true" or s == "1" or s == "yes" or s == "on":
			return true
		if s == "false" or s == "0" or s == "no" or s == "off":
			return false
		if s.is_valid_int():
			return int(s) != 0
		return default_val
	return default_val

func load_save_snapshot(data: Dictionary) -> bool:
	if not (data is Dictionary) or data.is_empty():
		return false
	var ver: int = int(data.get("version", 0))
	if ver < 1:
		return false

	var raw_spoken = data.get("has_spoken_intro")
	if raw_spoken == null:
		raw_spoken = data.get("talked_to_npc", false)
	has_spoken_intro = _parse_bool_safe(raw_spoken, false)

	var raw_shared = data.get("has_shared_meal")
	if raw_shared == null:
		raw_shared = data.get("has_shared", false)
	_has_shared_meal = _parse_bool_safe(raw_shared, false)

	meal_used = _parse_bool_safe(data.get("meal_used", false), false)
	p0_completed = _parse_bool_safe(data.get("p0_completed", false), false)

	var raw_flags = data.get("dialogue_flags", {})
	if raw_flags is Dictionary:
		dialogue_flags = raw_flags.duplicate(true)
	else:
		dialogue_flags.clear()
	return true

# --- Resolusi Manajer Dependensi ---

func _get_inventory_manager() -> Node:
	if _inventory_override != null and is_instance_valid(_inventory_override):
		return _inventory_override
	if Engine.has_singleton("InventoryManager"):
		return Engine.get_singleton("InventoryManager")
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var node = tree.root.get_node_or_null("InventoryManager")
		if node != null:
			return node
	if is_inside_tree() and has_node("/root/InventoryManager"):
		return get_node("/root/InventoryManager")
	return null

func _get_recipe_manager() -> Node:
	if _recipe_override != null and is_instance_valid(_recipe_override):
		return _recipe_override
	if Engine.has_singleton("RecipeManager"):
		return Engine.get_singleton("RecipeManager")
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var node = tree.root.get_node_or_null("RecipeManager")
		if node != null:
			return node
	if is_inside_tree() and has_node("/root/RecipeManager"):
		return get_node("/root/RecipeManager")
	return null

func _get_world_resource_manager() -> Node:
	if _world_override != null and is_instance_valid(_world_override):
		return _world_override
	if Engine.has_singleton("WorldResourceManager"):
		return Engine.get_singleton("WorldResourceManager")
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var node = tree.root.get_node_or_null("WorldResourceManager")
		if node != null:
			return node
	if is_inside_tree() and has_node("/root/WorldResourceManager"):
		return get_node("/root/WorldResourceManager")
	return null

func _get_kitchen_manager() -> Node:
	if _kitchen_override != null and is_instance_valid(_kitchen_override):
		return _kitchen_override
	if Engine.has_singleton("KitchenManager"):
		return Engine.get_singleton("KitchenManager")
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var node = tree.root.get_node_or_null("KitchenManager")
		if node != null:
			return node
	if is_inside_tree() and has_node("/root/KitchenManager"):
		return get_node("/root/KitchenManager")
	return null

func _get_input_manager() -> Node:
	if _input_override != null and is_instance_valid(_input_override):
		return _input_override
	if Engine.has_singleton("InputManager"):
		return Engine.get_singleton("InputManager")
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var node = tree.root.get_node_or_null("InputManager")
		if node != null:
			return node
	if is_inside_tree() and has_node("/root/InputManager"):
		return get_node("/root/InputManager")
	return null
