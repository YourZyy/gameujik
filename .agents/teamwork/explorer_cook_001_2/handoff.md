# Handoff Report — COOK-001 Investigation: Kitchen Station, Input Context, UI Layout & 4.0s Hold Preparation

**Agent:** explorer_cook_001_2  
**Working Directory:** `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_cook_001_2\`  
**Date:** 2026-10-28T14:18:00Z  
**Target Milestone:** `COOK-001` (Kitchen Station UI, Ingredient Reservation, 4.0s Hold Preparation, Pre-Cooking Safe Cancellation & Refund Storage)

---

## 1. Observation

Direct code and documentation observations from the workspace:

### 1.1 3D Landmark `station_kitchen_home` in `scenes/world/level_graybox.tscn`
- File `scenes/world/level_graybox.tscn` lines 509–532 defines `station_kitchen_home`:
  ```tscn
  [node name="station_kitchen_home" type="Node3D" parent="." unique_id=329321679]
  transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 2, 0, -4)

  [node name="Counter" type="StaticBody3D" parent="station_kitchen_home" unique_id=508093710]
  transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.45, 0)

  [node name="Collision" type="CollisionShape3D" parent="station_kitchen_home/Counter" unique_id=750139197]
  shape = SubResource("BoxShape3D_wuyg5")

  [node name="Mesh" type="MeshInstance3D" parent="station_kitchen_home/Counter" unique_id=1173530178]
  mesh = SubResource("BoxMesh_nkq5c")

  [node name="Interactable" type="Area3D" parent="station_kitchen_home" unique_id=1737290530]
  transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.45, 0)
  collision_layer = 4
  collision_mask = 0
  monitoring = false
  script = ExtResource("2_t2kf2")
  interaction_id = "landmark_kitchen"
  target_name = "Dapur"
  ```
- File `scripts/interaction/interactable.gd` lines 11–13: Default `prompt_action = "Periksa"`, `target_name = ""`. In `level_graybox.tscn`, `target_name` is set to `"Dapur"`, producing `"[E] Periksa Dapur"` via `get_prompt_text()`.
- File `scripts/ui/hud.gd` lines 427–431: Unhandled landmarks fall back to `interactable.get_prompt_text()`.
- File `scripts/main.gd` lines 17–97 (`_wire_inventory_and_landmarks()`): `container_starter`, `storage_home`, `book_family`, `note_garden_01`, `plot_home_01`, `resource_jagung_01`, `resource_temu_kunci_01`, `reserve_home`, and `bed_home` are wired. However, `station_kitchen_home` is **not yet wired** to any signal handler.

### 1.2 Input Context Transition and Simulation Pausing in `scripts/core/input_manager.gd`
- File `scripts/core/input_manager.gd` lines 6–13:
  ```gdscript
  enum ContextMode {
      WORLD,
      BOOK,
      STORAGE,
      KITCHEN,
      DIALOGUE,
      PAUSE
  }
  ```
- File `scripts/core/input_manager.gd` lines 56–59:
  ```gdscript
  func is_simulation_paused() -> bool:
      var ctx := get_current_context()
      return ctx in [ContextMode.BOOK, ContextMode.STORAGE, ContextMode.DIALOGUE, ContextMode.PAUSE]
  ```
  `ContextMode.KITCHEN` is **intentionally excluded** from `is_simulation_paused()`.
- File `scripts/core/input_manager.gd` lines 158–172 (`_sync_player_gating()`):
  When in `ContextMode.KITCHEN`, `in_world` is `false`:
  - `_player.movement_enabled = false`
  - `_player.look_enabled = false`
  - `_player.release_mouse()`
  - `Input.mouse_mode = Input.MOUSE_MODE_VISIBLE`
  This freezes player movement and look controls and frees the mouse cursor for UI navigation, while allowing world simulation (plant growth/evaporation) to run per `PROTOTYPE.md` § 5.
- File `scripts/core/input_manager.gd` lines 190–192:
  ```gdscript
  if event.is_action_pressed("pause_menu") and not event.is_echo():
      consume_and_close(&"pause_menu")
      get_viewport().set_input_as_handled()
  ```
  Pressing Esc (`pause_menu`) while in `ContextMode.KITCHEN` calls `consume_and_close()`, which pops the context back to `WORLD` without popping up the full pause menu.

### 1.3 Hold Action Controller in `scripts/gardening/hold_action_controller.gd`
- File `scripts/gardening/hold_action_controller.gd` lines 7–18:
  ```gdscript
  enum State { IDLE, HOLDING, COMMITTED, MUST_RELEASE }
  signal hold_started(action_id: String, duration: float)
  signal hold_progress(action_id: String, progress: float, elapsed: float, duration: float)
  signal hold_completed(action_id: String)
  signal hold_cancelled(action_id: String)
  ```
- File `scripts/gardening/hold_action_controller.gd` lines 38–64:
  `tick(delta, is_button_pressed, is_target_valid)`:
  - If `not is_button_pressed` during `HOLDING`, it calls `cancel()`.
  - In `cancel()` (lines 65–76): `state = State.IDLE`, `elapsed_time = 0.0`, and `hold_cancelled.emit(cancelled_action)`.
  - When `elapsed_time >= required_time`: `state = State.COMMITTED`, `hold_completed.emit(completed_action)`, then transitions to `State.MUST_RELEASE`.

### 1.4 Inventory Reservation & Refund Storage in `scripts/inventory/inventory_manager.gd`
- File `scripts/inventory/inventory_manager.gd` lines 13, 30, 59:
  `kitchen_refund` is already initialized: `kitchen_refund = InventoryContainerClass.new(STORAGE_SLOTS, MAX_STACK_SIZE)`.
- File `scripts/inventory/inventory_manager.gd` lines 280–295:
  `get_available_item_count(item_id)` sums `backpack` + `storage_home` counts and subtracts items in `_reservations[job_id]`.
- File `scripts/inventory/inventory_manager.gd` lines 306–345:
  `reserve_ingredients(job_id, items)` stores items into `_reservations[job_id]`.
  `cancel_reservation(job_id)` erases `_reservations[job_id]`.
  `commit_consumption(job_id)` removes items from `backpack` first, then `storage_home`.
- Note: The current `reserve_ingredients` implementation in `inventory_manager.gd` only tracks virtual reservations; it does not physically pull items out of container slots into a temporary holding container. However, for `TEST_PLAN` T40 ("Reservasi, tutup panel, penuhi kontainer asal via fixture, lalu batalkan -> Bahan kembali tepat sekali melalui sumber alternatif/refund persisten"), the items must actually vacate the original container slots so that a test fixture can fill those containers to capacity!

### 1.5 Recipe Definitions in `scripts/recipe/recipe_data.gd` and `recipes_data.gd`
- `RecipesData.ID_RECIPE_SAYUR_BENING`: `recipe_sayur_bening_01`
- Ingredients: 3 `ingredient_bayam`, 1 `ingredient_jagung`, 1 `ingredient_temu_kunci`.
- `prep_duration`: 4.0 seconds.
- `cook_duration`: 30.0 seconds.
- `station`: `"station_kitchen_home"`.
- `output_dish_id`: `"dish_sayur_bening"`.

### 1.6 World Resource Manager Interlock in `scripts/world/world_resource_manager.gd`
- Lines 262–271:
  ```gdscript
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
  ```
  This mandates that `KitchenManager` must expose `is_job_active() -> bool` and `is_cooking_active() -> bool`.

---

## 2. Logic Chain

1. **Detection & Prompt**:
   - `PlayerController` casts a 2.0m raycast along the camera look vector.
   - When aiming at `station_kitchen_home`, the raycast hits the `Interactable` (collision layer 4).
   - In `hud.gd`, `format_contextual_prompt` can either read `interactable.get_prompt_text()` or format dynamically based on kitchen state:
     - If output is ready: `"[E] Ambil Masakan"`
     - If job is active/preparing/cooking: `"[E] Buka Dapur (Sedang Memasak)"` or `"[E] Lanjutkan Dapur"`
     - Default: `"[E] Masak"` or `"[E] Buka Dapur"`.

2. **Context Transition**:
   - When player presses `E` while targeting `station_kitchen_home`, `main.gd` receives `interactable.interacted`.
   - `main.gd` calls `InputManager.push_context(ContextMode.KITCHEN)`.
   - `InputManager` immediately frees the mouse cursor (`Input.mouse_mode = Input.MOUSE_MODE_VISIBLE`) and gates player movement (`_player.movement_enabled = false`, `_player.look_enabled = false`).
   - World simulation (garden evaporation, growth, calendar active time) continues to tick in KITCHEN context per PROTOTYPE § 5.
   - If player presses Esc, `InputManager.consume_and_close(&"pause_menu")` pops the context back to `WORLD`, hides the kitchen UI, captures mouse, and re-enables player movement. The active job is preserved in a paused/preparing state.

3. **Preparation Hold & State Transition (4.0s Hold)**:
   - When the Kitchen UI opens, it validates ingredients via `KitchenManager.can_start_preparation("recipe_sayur_bening_01")`.
   - If ingredients are complete (3 bayam, 1 jagung, 1 temu kunci) and the station is idle with no uncollected output:
     - The player clicks "Siapkan Bahan".
     - `KitchenManager.start_preparation()` creates a stable `active_job_id` (e.g. `"job_sayur_bening_..."`) and reserves ingredients.
     - State transitions to `CookingState.PREPARING`.
     - An anti-spam guard prevents duplicate jobs: if `current_job != null` or state is not `IDLE`, calls to `start_preparation` are rejected idempotently without extra reservations (satisfying TEST_PLAN T12).
   - In `PREPARING` state:
     - UI presents a hold button `"Tahan Siapkan"` (and an explicit `"Batal"` button).
     - The hold mechanism uses `HoldActionController` with a duration of 4.0s.
     - While holding (button held down / pressed), `tick(delta, true, true)` advances elapsed time and emits `hold_progress`. UI updates `PrepProgressBar` (0.0 to 1.0) and time label (`"0.0s / 4.0s"`).
     - **Premature Release (< 4.0s)**:
       If the player releases the button before 4.0s:
       - `HoldActionController.cancel()` fires, emitting `hold_cancelled`.
       - Hold progress resets to 0.0s (or stroke resets).
       - No ingredients are consumed, no cooking progress starts, and state does not transition to `ready_to_heat`.
       - The reserved items remain held in the job until the player holds again to finish the 4.0s, OR clicks the `"Batal"` button.
     - **Successful Completion (4.0s)**:
       When elapsed time reaches 4.0s:
       - `HoldActionController` emits `hold_completed`.
       - `KitchenManager` transitions job state: `PREPARING` → `READY_TO_HEAT`.
       - UI hides the hold button and reveals `"Mulai Memasak"` (Start Cooking) button and `"Batal"` (Cancel) button.
       - As explicitly mandated by `CONTENT.md` § 4 ("Setelah persiapan penuh, tombol Mulai memasak melakukan transisi; jangan langsung mulai dari input tahan yang sama"), cooking does NOT auto-start from the hold stroke; the user must click "Mulai Memasak" to enter the cooking stage (COOK-002).

4. **Pre-Cooking Cancellation & Refund Handling (T13, T40)**:
   - While in `PREPARING` or `READY_TO_HEAT`, the player can click `"Batal"` (or call `KitchenManager.cancel_preparation()`).
   - For each item in `current_job.reserved_items`:
     1) Try returning to origin container (`backpack` first, or `storage_home` depending on where it came from).
     2) If the origin container cannot accept all items (e.g. was filled via fixture per T40), try the alternative container (`storage_home` / `backpack`).
     3) If both are full, deposit into `InventoryManager.kitchen_refund`.
   - `current_job` is cleared, `active_job_id = ""`, and state returns to `IDLE` (or `REFUND_PENDING` if refund storage contains items).
   - `RecipeManager.set_cooking_state("idle")` is called.
   - Total free + refund items equals initial items exactly (satisfying T13 & T40).

5. **Kitchen UI Architecture (`kitchen_ui.tscn`)**:
   - `KitchenUI` (`CanvasLayer`) instances in `scenes/main.tscn` alongside `HUD`, `InventoryUI`, and `BookUI`.
   - Layout follows Godot 4 responsive control tree (`Control` full rect -> `CenterContainer` -> `MainPanel` -> `MarginContainer` -> `VBoxContainer`).
   - Contains distinct, state-driven sections:
     - Header (`TitleLabel`, `CloseButton`)
     - Recipe summary (`RecipeTitleLabel`, `StationLabel`)
     - Ingredients grid (3 slots showing available / required)
     - Preparation section (`PrepProgressBar`, `PrepTimeLabel`, `HoldPrepButton`)
     - Ready section (`ReadyLabel`, `StartCookingButton`)
     - Refund section (`RefundLabel`, `RefundGrid`, `ClaimRefundButton`)
     - Actions footer (`CancelButton`, `StatusFeedbackLabel`)

---

## 3. Caveats

1. **COOK-002 Cooking Stage**: Heat control (Low/Med/High), 30s effective cook timer, output slot generation (`dish_sayur_bening`), and dish eating are scoped for milestone COOK-002. In COOK-001, the "Mulai Memasak" button in `READY_TO_HEAT` state acts as the handover boundary.
2. **Physical vs Virtual Item Reservation**: In `InventoryManager`, `_reservations` currently only deducts from `get_available_item_count` without removing items from container slots. To fully satisfy test case T40 (where containers can be filled up with other items during an active reservation), items must be physically removed from slots during `reserve_ingredients` and placed in a `holding_container` or `current_job.reserved_items`, with origin container and slot metadata saved for refund.
3. **World Simulation during Kitchen Modal**: Per `PROTOTYPE.md` § 5, `ContextMode.KITCHEN` does not pause world simulation (unlike `BOOK` or `STORAGE`), allowing garden growth and day timers to run. If an implementer needs to pause world simulation during kitchen prep, `input_manager.gd`'s `is_simulation_paused()` would need to include `ContextMode.KITCHEN`, but keeping it unpaused is the explicitly approved product specification.

---

## 4. Conclusion & Recommendations

### 4.1 Recommended File Structure
```
res://
├── scenes/
│   └── ui/
│       └── kitchen_ui.tscn             <-- New Kitchen UI scene
├── scripts/
│   ├── cooking/
│   │   └── kitchen_manager.gd         <-- New Autoload Singleton
│   └── ui/
│       └── kitchen_ui.gd              <-- New UI Controller script
└── tests/
    └── suites/
        └── test_cooking.gd            <-- Suite 11 (T10, T11, T12, T13, T40)
```

### 4.2 Scene Node Hierarchy (`scenes/ui/kitchen_ui.tscn`)
```
KitchenUI (CanvasLayer, layer = 10) [script: res://scripts/ui/kitchen_ui.gd]
└── RootControl (Control, anchors_preset = Full Rect, mouse_filter = Stop)
    ├── DarkOverlay (ColorRect, color = Color(0, 0, 0, 0.45))
    └── CenterContainer (CenterContainer, anchors_preset = Full Rect)
        └── MainPanel (PanelContainer, custom_minimum_size = Vector2(720, 520))
            └── Margin (MarginContainer, margins = 20)
                └── VBox (VBoxContainer, separation = 12)
                    ├── HeaderHBox (HBoxContainer)
                    │   ├── TitleLabel (Label, text: "Dapur Rumah")
                    │   └── CloseButton (Button, text: "Tutup [Esc]")
                    ├── RecipeSummaryPanel (PanelContainer)
                    │   └── SummaryVBox (VBoxContainer)
                    │       ├── RecipeNameLabel (Label, text: "Sayur Bening Bayam dan Jagung")
                    │       └── StationDescLabel (Label, text: "Stasiun: station_kitchen_home")
                    ├── IngredientsSection (VBoxContainer)
                    │   ├── SectionTitleLabel (Label, text: "Bahan yang Dibutuhkan:")
                    │   ├── IngredientsGrid (GridContainer, columns = 3)
                    │   │   ├── BayamSlot (PanelContainer)
                    │   │   ├── JagungSlot (PanelContainer)
                    │   │   └── TemuKunciSlot (PanelContainer)
                    │   └── IngredientStatusLabel (Label, text: "Bahan lengkap.")
                    ├── PreparationSection (VBoxContainer)
                    │   ├── PrepTitleLabel (Label, text: "Persiapan Bahan")
                    │   ├── PrepProgressBar (ProgressBar, min = 0.0, max = 1.0)
                    │   ├── PrepTimeLabel (Label, text: "Tahan Siapkan: 0.0s / 4.0s")
                    │   └── HoldPrepButton (Button, text: "Tahan untuk Menyiapkan (4.0s)")
                    ├── ReadySection (VBoxContainer, visible = false)
                    │   ├── ReadyStatusLabel (Label, text: "Bahan telah siap! Siap untuk dimasak.")
                    │   └── StartCookingButton (Button, text: "Mulai Memasak")
                    ├── RefundSection (VBoxContainer, visible = false)
                    │   ├── RefundNoticeLabel (Label, text: "Wadah Pengembalian Dapur (Peti/Tas Penuh)")
                    │   ├── RefundGrid (GridContainer, columns = 3)
                    │   └── ClaimRefundButton (Button, text: "Ambil Semua Pengembalian")
                    ├── ActionsHBox (HBoxContainer)
                    │   ├── StartPrepButton (Button, text: "Siapkan Bahan")
                    │   ├── CancelButton (Button, text: "Batal")
                    │   └── FeedbackLabel (Label, text: "")
```

### 4.3 Proposed Implementation Architecture

#### A. Autoload `KitchenManager` (`res://scripts/cooking/kitchen_manager.gd`)
```gdscript
class_name KitchenManager
extends Node

## Autoload Singleton KitchenManager untuk Buku Resep 2045 (COOK-001 / COOK-002)
## Mengelola state machine memasak, reservasi atomik, aksi tahan 4s, dan pengembalian aman

enum CookingState {
	IDLE,
	PREPARING,
	READY_TO_HEAT,
	COOKING,
	PAUSED,
	OUTPUT_READY,
	REFUND_PENDING
}

signal cooking_state_changed(new_state: CookingState, old_state: CookingState)
signal prep_started(job_id: String, duration: float)
signal prep_progress(job_id: String, progress: float, elapsed: float, duration: float)
signal prep_completed(job_id: String)
signal prep_cancelled(job_id: String)
signal job_cancelled(job_id: String, refunded_items: Array)
signal refund_storage_updated()
signal action_failed(reason: String)

const RECIPE_ID: String = "recipe_sayur_bening_01"
const PREP_DURATION: float = 4.0

var current_state: CookingState = CookingState.IDLE
var current_job: Dictionary = {} # {"id": String, "recipe_id": String, "reserved_items": Array, "origin_records": Array}
var active_job_id: String = ""
var prep_elapsed: float = 0.0
var output_slot: Dictionary = {}

var _hold_controller: HoldActionController = null
var _job_counter: int = 0

func _ready() -> void:
	_hold_controller = HoldActionController.new()
	_hold_controller.hold_started.connect(func(act, dur): prep_started.emit(active_job_id, dur))
	_hold_controller.hold_progress.connect(func(act, prog, elap, dur):
		prep_elapsed = elap
		prep_progress.emit(active_job_id, prog, elap, dur)
	)
	_hold_controller.hold_completed.connect(_on_prep_hold_completed)
	_hold_controller.hold_cancelled.connect(_on_prep_hold_cancelled)

func is_job_active() -> bool:
	return current_state != CookingState.IDLE and current_state != CookingState.REFUND_PENDING

func is_cooking_active() -> bool:
	return current_state == CookingState.COOKING

func can_start_preparation(recipe_id: String = RECIPE_ID) -> Dictionary:
	if is_job_active():
		return {"success": false, "reason": "Job memasak sudah aktif."}
	if not output_slot.is_empty():
		return {"success": false, "reason": "Ambil masakan yang ada di slot hasil terlebih dahulu."}
	
	var inv := _get_inventory_manager()
	if inv == null:
		return {"success": false, "reason": "InventoryManager tidak tersedia."}
	
	var rm := _get_recipe_manager()
	var recipe: Resource = rm.get_recipe(recipe_id) if rm != null else null
	if recipe == null:
		return {"success": false, "reason": "Resep tidak ditemukan."}
	
	var missing: Dictionary = {}
	for it_id in recipe.ingredients:
		var req: int = int(recipe.ingredients[it_id])
		var avail: int = inv.get_available_item_count(it_id)
		if avail < req:
			missing[it_id] = req - avail
	
	if not missing.is_empty():
		return {"success": false, "reason": "Bahan tidak mencukupi.", "missing": missing}
	return {"success": true, "reason": "Bahan mencukupi."}

func start_preparation(recipe_id: String = RECIPE_ID) -> Dictionary:
	# Anti-spam guard: prevent duplicate job or double reservation
	if is_job_active():
		return {"success": false, "reason": "Job sudah aktif.", "job_id": active_job_id}
	
	var check := can_start_preparation(recipe_id)
	if not check.get("success", false):
		action_failed.emit(check.get("reason", "Gagal memulai persiapan."))
		return check

	var inv := _get_inventory_manager()
	var rm := _get_recipe_manager()
	var recipe: Resource = rm.get_recipe(recipe_id)

	_job_counter += 1
	active_job_id = "job_%s_%d" % [recipe_id, _job_counter]
	
	# Atomically extract ingredients from backpack first, then storage_home
	var reserved: Array[Dictionary] = []
	var origins: Array[Dictionary] = []

	for it_id in recipe.ingredients:
		var needed: int = int(recipe.ingredients[it_id])
		var from_bp: int = mini(needed, inv.backpack.get_item_count(it_id))
		if from_bp > 0:
			inv.backpack.remove_item(it_id, from_bp)
			origins.append({"container": "backpack", "item_id": it_id, "count": from_bp})
			needed -= from_bp
		if needed > 0:
			inv.storage_home.remove_item(it_id, needed)
			origins.append({"container": "storage", "item_id": it_id, "count": needed})
		reserved.append({"item_id": it_id, "count": int(recipe.ingredients[it_id])})

	current_job = {
		"id": active_job_id,
		"recipe_id": recipe_id,
		"reserved_items": reserved,
		"origin_records": origins,
		"prep_progress": 0.0
	}

	_set_state(CookingState.PREPARING)
	if rm != null:
		rm.set_cooking_state("preparing")
	return {"success": true, "job_id": active_job_id}

func hold_tick(delta: float, is_button_pressed: bool) -> void:
	if current_state != CookingState.PREPARING:
		return
	if not _hold_controller.is_active() and is_button_pressed:
		_hold_controller.start("prep", active_job_id, PREP_DURATION, &"prep_hold")
	_hold_controller.tick(delta, is_button_pressed, true)

func _on_prep_hold_completed(_action_id: String) -> void:
	prep_elapsed = PREP_DURATION
	_set_state(CookingState.READY_TO_HEAT)
	prep_completed.emit(active_job_id)

func _on_prep_hold_cancelled(_action_id: String) -> void:
	prep_elapsed = 0.0
	prep_cancelled.emit(active_job_id)

func cancel_preparation() -> Dictionary:
	if current_state != CookingState.PREPARING and current_state != CookingState.READY_TO_HEAT:
		return {"success": false, "reason": "Tidak dapat membatalkan di tahap ini."}

	var inv := _get_inventory_manager()
	var refunded: Array = []
	var origin_records: Array = current_job.get("origin_records", [])

	for rec in origin_records:
		var c_name: String = str(rec.get("container", "backpack"))
		var it_id: String = str(rec.get("item_id", ""))
		var count: int = int(rec.get("count", 0))

		var primary_c = inv.get_container(c_name)
		var left := primary_c.add_item(it_id, count)
		if left > 0:
			var alt_c = inv.storage_home if c_name == "backpack" else inv.backpack
			left = alt_c.add_item(it_id, left)
		if left > 0:
			inv.kitchen_refund.add_item(it_id, left)
		refunded.append({"item_id": it_id, "count": count})

	var old_job_id := active_job_id
	current_job.clear()
	active_job_id = ""
	prep_elapsed = 0.0
	_hold_controller.cancel()

	var next_state := CookingState.IDLE
	if inv.kitchen_refund.get_used_slots_count() > 0:
		next_state = CookingState.REFUND_PENDING
	_set_state(next_state)

	var rm := _get_recipe_manager()
	if rm != null:
		rm.set_cooking_state("idle")

	job_cancelled.emit(old_job_id, refunded)
	inv.inventory_updated.emit()
	return {"success": true, "reason": "Persiapan dibatalkan. Bahan telah dikembalikan."}
```

#### B. Main Scene Wiring (`scripts/main.gd`)
```gdscript
# In _wire_inventory_and_landmarks():
var kitchen_node = level.get_node_or_null("station_kitchen_home")
if kitchen_node:
	var interactable = kitchen_node.get_node_or_null("Interactable")
	if interactable and interactable.has_signal("interacted"):
		interactable.interacted.connect(_on_kitchen_station_interacted)

func _on_kitchen_station_interacted(_player_node: Node3D) -> void:
	var im = get_node_or_null("/root/InputManager")
	if im != null and im.is_world_context():
		im.push_context(im.ContextMode.KITCHEN)
	if kitchen_ui != null:
		kitchen_ui.open()
```

#### C. HUD Prompt Formatting (`scripts/ui/hud.gd`)
```gdscript
elif i_id == "landmark_kitchen":
	var km = get_node_or_null("/root/KitchenManager")
	if km != null:
		if km.has_method("has_ready_output") and km.has_ready_output():
			return "[E] Ambil Masakan"
		elif km.has_method("is_cooking_active") and km.is_cooking_active():
			return "[E] Buka Dapur (Sedang Memasak)"
		elif km.has_method("is_job_active") and km.is_job_active():
			return "[E] Lanjutkan Dapur"
	return "[E] Masak"
```

---

## 5. Verification Method

To verify these findings and subsequently validate the implementation:

1. **Static Syntax & Codebase Integrity**:
   Run the headless Godot test suite via powershell:
   ```powershell
   & "C:\Users\HP\.local\bin\godot.exe" --headless --script res://tests/test_runner.gd
   ```
   *Expected result*: Exit code 0, 1,233+ assertions passing across all suites.

2. **Automated Unit & Invariant Testing (Suite 11: `test_cooking.gd`)**:
   Implement `test_cooking.gd` in `tests/suites/` covering:
   - **T10**: Insufficient ingredients check (e.g. only 2 bayam or missing temu kunci). Call `start_preparation()` -> verifies clean rejection, zero inventory mutation, zero reservations created.
   - **T11**: Ingredients split across backpack and storage chest (e.g. 2 bayam in backpack, 1 in chest). Call `start_preparation()` -> verifies items pulled according to CONTENT order (backpack first, then chest).
   - **T12**: Anti-spam test: spamming `start_preparation()` or hold 5 times consecutively -> verifies exactly 1 stable job ID created, exactly 1 batch of ingredients reserved, 0 duplications.
   - **T13**: Premature release & Cancel before cooking:
     - Hold for 2.0s (< 4.0s) and release -> verifies hold cancelled, elapsed resets, job remains in `PREPARING` without state mutation or consumption.
     - Hold for 4.0s -> verifies transition to `READY_TO_HEAT`.
     - Call `cancel_preparation()` from `READY_TO_HEAT` -> verifies all items restored to original containers with exact count matching initial state.
   - **T40**: T40 Refund Overflow: Reserve ingredients, simulate full backpack and full storage chest via fixture, call `cancel_preparation()` -> verifies all items successfully deposited into `kitchen_refund` storage without loss, job destroyed, and refund accessible.
   - **T39 Interlock**: Call `WorldResourceManager.sleep_and_advance_day()` while `KitchenManager.is_job_active()` is true -> verifies sleep is rejected with message `"Selesaikan atau batalkan proses memasak dahulu sebelum istirahat."`

3. **Interactive & Visual Spot-Check**:
   - Aim raycast at `station_kitchen_home` -> verify HUD displays `[E] Masak`.
   - Press `E` -> verify `InputManager` enters `ContextMode.KITCHEN`, mouse cursor is freed, camera/movement is locked, and `KitchenUI` appears.
   - Press Esc -> verify `KitchenUI` closes and `InputManager` returns to `ContextMode.WORLD` with mouse recaptured.
