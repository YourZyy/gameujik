# Handoff Report: Recipe Book UI & HUD Quest Tracker Architecture (BOOK-001)

**Agent ID:** `explorer_book_001_2`  
**Milestone:** BOOK-001 (Buku Resep dan Tracker)  
**Target:** Production-grade Architecture for Recipe Book UI, HUD Quest Tracker, and Recipe Manager Subsystem  
**Date:** 2026-10-27  

---

## 1. Observation

### 1.1 Codebase & Project Baseline
- **Godot Version & Environment:** Godot 4.7.2-stable official (`gl_compatibility` renderer, desktop 1280x720 base viewport, stretch mode `canvas_items`, aspect `keep`).
  - Command: `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"`
  - Result: 606 assertions passed across 7 test suites (`TestSetup`, `TestLevel`, `TestAdversarialLevel`, `TestPlayer`, `TestAdversarialPlayer`, `TestInteraction`, `TestInventory`). Exit code 0.
  - Project consistency validator: `python ".agents/skills/godot-nodes-scenes/scripts/check_godot_project.py" .` yielded 0 errors, 0 warnings across 45 files.

### 1.2 Input Context & Singleton State
- `scripts/core/input_manager.gd`:
  - Contains enum `ContextMode { WORLD, BOOK, STORAGE, KITCHEN, DIALOGUE, PAUSE }` (lines 6–13).
  - Lines 56–58: `is_simulation_paused()` explicitly includes `ContextMode.BOOK`.
  - Lines 86–88 & 127–129: `pop_context()` and `set_context(WORLD)` record `_last_closed_frame = Engine.get_process_frames()` to enforce frame guard.
  - Lines 183–185:
    ```gdscript
    elif event.is_action_pressed("open_book") and not event.is_echo():
        push_context(ContextMode.BOOK)
        get_viewport().set_input_as_handled()
    ```
  - Lines 193–195:
    ```gdscript
    elif event.is_action_pressed("open_book") and get_current_context() == ContextMode.BOOK and not event.is_echo():
        consume_and_close(&"open_book")
        get_viewport().set_input_as_handled()
    ```
- `project.godot`:
  - Input action `open_book` is mapped to physical keycode 66 (`Key.B`) at lines 70–74.
  - Input action `pause_menu` is mapped to physical keycode 4194305 (`Key.ESCAPE`) at lines 80–84.
  - Autoloads currently registered: `InputManager` and `InventoryManager`.

### 1.3 Inventory & Free Stock Calculations
- `scripts/inventory/inventory_manager.gd`:
  - Lines 281–294: Implements `get_available_item_count(item_id: String) -> int`:
    ```gdscript
    func get_available_item_count(item_id: String) -> int:
        var canonical_id := resolve_id(item_id)
        var total: int = backpack.get_item_count(canonical_id) + storage_home.get_item_count(canonical_id)
        for job_id in _reservations:
            ...
        return max(0, total)
    ```
  - Lines 70–73: Emits `inventory_updated()` and `inventory_changed(container_name)` whenever backpack or storage_home mutate.
  - Canonical item IDs registered: `ingredient_bayam` (alias `crop_bayam`), `ingredient_jagung`, `ingredient_temu_kunci`, `dish_sayur_bening`.

### 1.4 Existing UI & Main Scene Composition
- `scenes/main.tscn`:
  - Instances `LevelGraybox` (line 42), `Player` (line 44), `InteractionPrompt` (line 47), and `InventoryUI` (line 49).
- `scripts/main.gd`:
  - Lines 18–36: Wires `container_starter` and `storage_home` via their child `Interactable` nodes.
- `scenes/world/level_graybox.tscn`:
  - Lines 481–507: Contains landmark `book_family` at `Vector3(-1, 0, -2)` with an `Interactable` component (`interaction_id = "landmark_book"`, `prompt_action = "Periksa"`, `target_name = "Meja Resep"`).
- `scenes/ui/interaction_prompt.tscn` & `scripts/ui/interaction_prompt.gd`:
  - Provides `Reticle` (ColorRect 4x4) and `PromptPanel` (PanelContainer +36px below reticle). Tested in `test_interaction.gd` suite 6.

### 1.5 Specifications from Documentation
- `docs/UI_UX.md` § UI02 & § 3:
  - Single page layout without empty sidebars: Title at top, notes/status on left, 3 ingredients with source hints on right, Track button at bottom.
  - Baseline 1920x1080 scaled down to 1280x720 responsive, safe margin ~4% (20–24px).
  - Focus navigation: Arrow keys, Enter/Space to click, Tab/Shift+Tab focus traversal, B/Esc to close.
- `docs/UI_UX.md` § UI01:
  - Top-left HUD quest tracker: max ~30% screen width (~384px at 1280px).
  - Untracked: *"Buka buku [B] untuk memilih masakan."*
  - Tracked: Recipe name + 3 ingredient lines with live counters (e.g. `Bayam: 2/3`, `Jagung: 1/1`, `Temu Kunci: 1/1`).
  - Ready: *"Bahan lengkap. Siap dimasak di dapur."*
  - Active cooking: *"Masakan dijeda"* / *"Sedang memasak"*.
- `docs/CONTENT.md` § 4:
  - Recipe ID: `recipe_sayur_bening_01`
  - Name: "Sayur Bening Bayam dan Jagung"
  - Ingredients: Bayam 3 (`ingredient_bayam`), Jagung 1 (`ingredient_jagung`), Temu Kunci 1 (`ingredient_temu_kunci`).
  - Note: *"Bayam paling enak dipetik dekat waktu memasak. Jagung di kebun ujung jalan mungkin masih bisa dipanen. Temu kunci tumbuh di tepi bambu, dekat batu besar."*
  - Source hints:
    - Bayam: *"Benih ada di wadah dekat alat. Siapkan petak di pekarangan, lalu tanam."*
    - Jagung: *"Cari sisa kebun keluarga di ujung jalan, dekat pagar miring."*
    - Temu kunci: *"Periksa tanaman di tepi rumpun bambu, dekat batu besar."*

---

## 2. Logic Chain

1. **State Decoupling via RecipeManager:**
   - *Observation:* `InventoryManager` handles items and aggregates free stock across backpack and chest via `get_available_item_count()`, but does not manage recipe tracking or cooking progress.
   - *Deduction:* A dedicated autoload singleton `RecipeManager` (`scripts/recipe/recipe_manager.gd`) must own recipe definitions, tracked state (`tracked_recipe_id`), cooking state, and recipe completion counts. It listens to `InventoryManager.inventory_updated` and emits `recipe_progress_updated`, `recipe_tracked`, `recipe_untracked`, and `recipe_completed`.
   - *Benefit:* Both `BookUI` and `HUD` quest tracker subscribe to `RecipeManager` signals, ensuring zero polling in `_process()` and perfect event-driven synchronization (Skill: `game-ui-ux` Pattern 5).

2. **Responsive Single-Page Layout for Book UI:**
   - *Observation:* `UI_UX.md` § UI02 explicitly mandates "P0 menggunakan satu halaman utama tanpa sidebar kosong" and rejects placeholder recipe cards.
   - *Deduction:* `BookUI` (`scenes/ui/book_ui.tscn`) must use a centered `PanelContainer` inside a `CenterContainer` (custom minimum size `880x540` inside 1280x720 canvas), with a 2-column `HBoxContainer`:
     - Top: Header with book subtitle "BUKU RESEP KELUARGA", title "Sayur Bening Bayam dan Jagung", and "Tutup [Esc / B]" button.
     - Left Column (~380px): Recipe notes in smart word-wrapped label, cooking station indicator ("Dapur Rumah"), times cooked counter ("Belum pernah dimasak" / "Selesai: X kali dimasak"), and status badge.
     - Right Column (~440px): 3 ingredient cards/rows (Bayam 0/3, Jagung 0/1, Temu Kunci 0/1) with category color accent, completion checkmarks, and source hints.
     - Bottom Bar: Live aggregate status badge on the left ("Bahan belum lengkap" vs "Bahan lengkap. Siap dimasak di dapur."), and a large primary action button `btn_track` on the right ("Lacak Masakan" vs "Berhenti Melacak").

3. **Input Context & Anti Bleed-Through Discipline:**
   - *Observation:* `InputManager` already defines `ContextMode.BOOK` which pauses simulation and manages mouse capture/release. When popped, `_last_closed_frame` is marked and `can_interact_in_world()` returns false on that frame.
   - *Deduction:* When `BookUI` is opened (via key `B`, landmark `book_family`, or script), `InputManager.push_context(ContextMode.BOOK)` is engaged. When closed via button, `Esc`, or `B`, `InputManager.consume_and_close(&"open_book")` is called. This guarantees the closing key/click never bleeds through into 3D world interaction or camera pitch/yaw spikes (T18, T28).

4. **Focus Navigation & Keyboard Accessibility:**
   - *Observation:* `UI_UX.md` § 3 and `godot-ui-control` require controller/keyboard usability where every menu is navigable without a mouse.
   - *Deduction:* On `open_book()`, `btn_track.grab_focus()` is called. Focus neighbors are explicitly linked between `btn_track`, `close_button`, and the ingredient hint toggle buttons. Arrow keys, Tab, Shift+Tab, and Enter/Space work out-of-the-box.

5. **HUD Quest Tracker Architecture & Crosshair Integration:**
   - *Observation:* `docs/UI_UX.md` UI01 specifies the exploration HUD with top-left tracker (<=30% width) and center reticle + prompt. `player_controller.gd` expects an `InteractionPrompt` node or a node responding to `connect_detector()`.
   - *Deduction:* `scenes/ui/hud.tscn` & `scripts/ui/hud.gd` provides the comprehensive exploration HUD (Layer 1):
     - `QuestTrackerPanel` (top-left, width ~340px <= 30% of 1280px, mouse_filter = IGNORE):
       - Untracked mode: *"Buka buku [B] untuk memilih masakan."*
       - Tracked mode: Recipe Title, 3 ingredient lines with live counters (e.g. `• Bayam: 0/3`, `• Jagung: 0/1`, `• Temu Kunci: 0/1`), and status badge (*"Bahan lengkap. Siap dimasak di dapur."*, *"Masakan dijeda"*, *"Sedang memasak"*).
     - Center crosshair (`Reticle`, 4x4 ColorRect) and `PromptPanel` with `PromptLabel`.
     - `scripts/ui/hud.gd` implements `connect_detector()`, `show_prompt()`, `hide_prompt()`, `is_prompt_visible()`, and `get_prompt_text()`.
     - In `scenes/main.tscn`, `HUD` replaces/integrates `InteractionPrompt` while maintaining complete API compatibility so `player_controller.gd` and existing tests operate without discrepancy.

6. **Diegetic Landmark Interaction:**
   - *Observation:* `book_family` exists at `Vector3(-1, 0, -2)` on the house table in `level_graybox.tscn`. Its `Interactable` child has prompt `[E] Periksa Meja Resep`.
   - *Deduction:* In `scripts/main.gd`, connecting `book_family/Interactable.interacted` to call `InputManager.push_context(ContextMode.BOOK)` and `book_ui.open_book()` allows the player to open the family recipe book both diegetically in the world by inspecting the table and remotely via key `B`.

---

## 3. Caveats

1. **No Cooking Mini-Game in Scope:** Cooking progress stages (preparing 4s, cooking 30s, heat levels) belong to `COOK-001` and `COOK-002`. In `BOOK-001`, `RecipeManager` supports setting `cooking_state` (`idle`, `preparing`, `cooking`, `paused`, `output_ready`), and `HUD` displays corresponding state strings ("Masakan dijeda", "Sedang memasak"), but actual kitchen station interaction is not triggered until `COOK-001`.
2. **Backward Compatibility with `interaction_prompt.tscn`:** Existing automated suite `tests/suites/test_interaction.gd` loads `res://scenes/ui/interaction_prompt.tscn` directly. To guarantee 100% test integrity, `scenes/ui/interaction_prompt.tscn` must be preserved in the repository, while `scenes/ui/hud.tscn` serves as the game HUD in `main.tscn`.
3. **Single Recipe Scope (P0):** Per PRD D13 and CONTENT § 4, only `recipe_sayur_bening_01` is implemented. Additional recipe cards are intentionally omitted to avoid empty sidebar clutter.

---

## 4. Conclusion & Technical Blueprint

The implementation for `BOOK-001` requires creating 4 new files and updating 3 existing files:

### 4.1 New Files to Create

#### 1. `scripts/recipe/recipe_manager.gd` (Autoload Singleton `RecipeManager`)
```gdscript
class_name RecipeManagerScript
extends Node

## Autoload Singleton RecipeManager untuk Buku Resep 2045
## Mengelola katalog resep, status pelacakan (tracking/HUD), progres masakan, dan integrasi stok bebas

signal recipe_tracked(recipe_id: String)
signal recipe_untracked()
signal recipe_tracking_toggled(recipe_id: String, is_tracked: bool)
signal recipe_progress_updated(recipe_id: String)
signal recipe_completed(recipe_id: String, times_cooked: int)
signal cooking_state_changed(new_state: String)

const RECIPE_SAYUR_BENING: String = "recipe_sayur_bening_01"

const RECIPES: Dictionary = {
	"recipe_sayur_bening_01": {
		"id": "recipe_sayur_bening_01",
		"name": "Sayur Bening Bayam dan Jagung",
		"description": "Sayur bening segar dengan bayam pekarangan, jagung manis, dan aroma temu kunci.",
		"notes": "Bayam paling enak dipetik dekat waktu memasak. Jagung di kebun ujung jalan mungkin masih bisa dipanen. Temu kunci tumbuh di tepi bambu, dekat batu besar.",
		"station_id": "station_kitchen_home",
		"station_name": "Dapur Rumah",
		"output_item_id": "dish_sayur_bening",
		"output_count": 1,
		"prep_duration": 4.0,
		"cook_duration": 30.0,
		"ingredients": [
			{
				"item_id": "ingredient_bayam",
				"name": "Bayam",
				"count": 3,
				"hint": "Benih ada di wadah dekat alat. Siapkan petak di pekarangan, lalu tanam."
			},
			{
				"item_id": "ingredient_jagung",
				"name": "Jagung",
				"count": 1,
				"hint": "Cari sisa kebun keluarga di ujung jalan, dekat pagar miring."
			},
			{
				"item_id": "ingredient_temu_kunci",
				"name": "Temu Kunci",
				"count": 1,
				"hint": "Periksa tanaman di tepi rumpun bambu, dekat batu besar."
			}
		]
	}
}

var tracked_recipe_id: String = ""
var cooking_state: String = "idle" # idle, preparing, cooking, paused, output_ready
var recipe_progress: Dictionary = {
	"recipe_sayur_bening_01": {
		"unlocked": true,
		"times_cooked": 0,
		"completed": false
	}
}

func _ready() -> void:
	var inv = _get_inventory_manager()
	if inv != null:
		if inv.has_signal("inventory_updated"):
			inv.inventory_updated.connect(_on_inventory_updated)
		elif inv.has_signal("inventory_changed"):
			inv.inventory_changed.connect(func(_c): _on_inventory_updated())

func _on_inventory_updated() -> void:
	if not tracked_recipe_id.is_empty():
		recipe_progress_updated.emit(tracked_recipe_id)

func get_recipe(id: String) -> Dictionary:
	return RECIPES.get(id, {})

func get_all_recipes() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for k in RECIPES:
		list.append(RECIPES[k])
	return list

func get_tracked_recipe_id() -> String:
	return tracked_recipe_id

func is_recipe_tracked(id: String) -> bool:
	return tracked_recipe_id == id and not id.is_empty()

func is_tracking_any() -> bool:
	return not tracked_recipe_id.is_empty()

func track_recipe(id: String) -> bool:
	if not RECIPES.has(id):
		return false
	tracked_recipe_id = id
	recipe_tracked.emit(id)
	recipe_tracking_toggled.emit(id, true)
	recipe_progress_updated.emit(id)
	return true

func untrack_recipe() -> void:
	if tracked_recipe_id.is_empty():
		return
	var old_id := tracked_recipe_id
	tracked_recipe_id = ""
	recipe_untracked.emit()
	recipe_tracking_toggled.emit(old_id, false)

func toggle_track_recipe(id: String) -> bool:
	if tracked_recipe_id == id:
		untrack_recipe()
		return false
	else:
		return track_recipe(id)

func get_ingredient_status(recipe_id: String = "") -> Array[Dictionary]:
	var target_id := recipe_id if not recipe_id.is_empty() else (tracked_recipe_id if not tracked_recipe_id.is_empty() else RECIPE_SAYUR_BENING)
	var rec := get_recipe(target_id)
	if rec.is_empty():
		return []
	
	var inv = _get_inventory_manager()
	var result: Array[Dictionary] = []
	var ing_list: Array = rec.get("ingredients", [])
	for ing in ing_list:
		var item_id: String = str(ing.get("item_id", ""))
		var req_count: int = int(ing.get("count", 0))
		var avail_count: int = 0
		if inv != null and inv.has_method("get_available_item_count"):
			avail_count = inv.get_available_item_count(item_id)
		
		result.append({
			"item_id": item_id,
			"name": str(ing.get("name", item_id)),
			"required": req_count,
			"available": avail_count,
			"is_complete": avail_count >= req_count,
			"hint": str(ing.get("hint", ""))
		})
	return result

func are_ingredients_complete(recipe_id: String = "") -> bool:
	var status_list := get_ingredient_status(recipe_id)
	if status_list.is_empty():
		return false
	for st in status_list:
		if not st.get("is_complete", false):
			return false
	return true

func is_recipe_completed(recipe_id: String) -> bool:
	return bool(recipe_progress.get(recipe_id, {}).get("completed", false))

func get_times_cooked(recipe_id: String) -> int:
	return int(recipe_progress.get(recipe_id, {}).get("times_cooked", 0))

func record_recipe_cooked(recipe_id: String) -> void:
	if not recipe_progress.has(recipe_id):
		recipe_progress[recipe_id] = {"unlocked": true, "times_cooked": 0, "completed": false}
	recipe_progress[recipe_id]["times_cooked"] += 1
	recipe_progress[recipe_id]["completed"] = true
	recipe_completed.emit(recipe_id, recipe_progress[recipe_id]["times_cooked"])
	recipe_progress_updated.emit(recipe_id)

func set_cooking_state(state: String) -> void:
	if cooking_state != state:
		cooking_state = state
		cooking_state_changed.emit(cooking_state)
		if not tracked_recipe_id.is_empty():
			recipe_progress_updated.emit(tracked_recipe_id)

func get_cooking_state() -> String:
	return cooking_state

func get_save_snapshot() -> Dictionary:
	return {
		"tracked_recipe_id": tracked_recipe_id,
		"cooking_state": cooking_state,
		"recipe_progress": recipe_progress.duplicate(true)
	}

func load_save_snapshot(data: Dictionary) -> bool:
	tracked_recipe_id = str(data.get("tracked_recipe_id", ""))
	cooking_state = str(data.get("cooking_state", "idle"))
	if data.has("recipe_progress") and data["recipe_progress"] is Dictionary:
		recipe_progress = data["recipe_progress"].duplicate(true)
	recipe_progress_updated.emit(tracked_recipe_id)
	return true

func _get_inventory_manager() -> Node:
	if Engine.has_singleton("InventoryManager"):
		return Engine.get_singleton("InventoryManager")
	if has_node("/root/InventoryManager"):
		return get_node("/root/InventoryManager")
	return null
```

#### 2. `scenes/ui/book_ui.tscn` & `scripts/ui/book_ui.gd`
- **Root Node:** `BookUI` (`CanvasLayer`, layer = 10, script = `res://scripts/ui/book_ui.gd`)
- **Structure:**
  ```
  BookUI (CanvasLayer, layer=10)
  └── RootControl (Control, PRESET_FULL_RECT)
      ├── DimBackground (ColorRect, PRESET_FULL_RECT, Color(0.04, 0.05, 0.08, 0.75))
      └── CenterContainer (CenterContainer, PRESET_FULL_RECT)
          └── MainPanel (PanelContainer, min_size 880x540, dark slate StyleBoxFlat)
              └── Margin (MarginContainer, 24px sides, 20px top/bottom)
                  └── VBox (VBoxContainer, separation 16px)
                      ├── HeaderHBox (HBoxContainer)
                      │   ├── TitleVBox (VBoxContainer)
                      │   │   ├── BookSubtitle ("BUKU RESEP KELUARGA", 14px, muted gold)
                      │   │   └── RecipeTitle ("Sayur Bening Bayam dan Jagung", 24px, bold)
                      │   ├── Spacer (Control, expand)
                      │   └── CloseButton ("Tutup [Esc / B]", Button, min_size 140x36)
                      ├── ContentHBox (HBoxContainer, separation 24px)
                      │   ├── LeftColumn (VBoxContainer, min_width 380px, expand)
                      │   │   ├── NotesHeader ("Catatan Resep", Label, 18px bold)
                      │   │   ├── NotesCard (PanelContainer, dark inset)
                      │   │   │   └── NotesLabel (Label, autowrap, notes text)
                      │   │   ├── Spacer (Control, vertical expand)
                      │   │   └── RecipeInfoCard (PanelContainer)
                      │   │       └── InfoVBox (VBoxContainer)
                      │   │           ├── StationLabel ("Tempat Memasak: Dapur Rumah")
                      │   │           ├── CookCountLabel ("Riwayat Masak: Belum pernah dimasak")
                      │   │           └── StatusBadgeLabel ("Status: Belum Dimasak")
                      │   └── RightColumn (VBoxContainer, min_width 440px, expand)
                      │       ├── IngHeaderHBox (HBoxContainer)
                      │       │   ├── IngTitle ("Bahan yang Dibutuhkan", Label, 18px bold)
                      │       │   ├── Spacer (Control, expand)
                      │       │   └── SourceHintLabel ("Termasuk tas + peti", 12px muted)
                      │       └── IngredientsVBox (VBoxContainer, separation 10px)
                      │           ├── IngCard_Bayam (PanelContainer)
                      │           ├── IngCard_Jagung (PanelContainer)
                      │           └── IngCard_TemuKunci (PanelContainer)
                      └── BottomBarHBox (HBoxContainer, separation 16px)
                          ├── StatusBadge (Label, 14px, ready/incomplete message)
                          ├── Spacer (Control, expand)
                          └── BtnTrack (Button, min_size 200x42, "Lacak Masakan" / "Berhenti Melacak")
  ```
- **Logic in `scripts/ui/book_ui.gd`:**
  - `open_book()`:
    - Sets `visible = true`.
    - Updates recipe information and ingredient statuses.
    - Grabs focus on `btn_track`.
    - Configures focus neighbors.
  - `close_book()`:
    - Sets `visible = false`.
    - Calls `InputManager.consume_and_close(&"open_book")`.
  - `_on_track_button_pressed()`:
    - Toggles tracking in `RecipeManager`.
    - Refreshes track button text and colors.
  - Listens to `InputManager.context_changed`:
    - Automatically opens if context pushed is `BOOK`.
    - Closes if context switches away from `BOOK`.
  - Listens to `RecipeManager.recipe_progress_updated`:
    - Refreshes counters live when items change.

#### 3. `scenes/ui/hud.tscn` & `scripts/ui/hud.gd`
- **Root Node:** `HUD` (`CanvasLayer`, layer = 1, script = `res://scripts/ui/hud.gd`)
- **Structure:**
  ```
  HUD (CanvasLayer, layer=1)
  └── RootControl (Control, PRESET_FULL_RECT, mouse_filter=IGNORE)
      ├── QuestTrackerPanel (PanelContainer, PRESET_TOP_LEFT, max_width 360px, mouse_filter=IGNORE)
      │   └── Margin (MarginContainer, 14px padding)
      │       └── VBox (VBoxContainer, separation 6px)
      │           ├── UntrackedContainer (VBoxContainer)
      │           │   └── UntrackedLabel ("Buka buku [B] untuk memilih masakan.", 14px muted)
      │           └── TrackedContainer (VBoxContainer)
      │               ├── RecipeTitleLabel ("Sayur Bening Bayam dan Jagung", 15px bold gold)
      │               ├── IngredientRows (VBoxContainer, separation 4px)
      │               │   ├── BayamRow (Label, "• Bayam: 0/3")
      │               │   ├── JagungRow (Label, "• Jagung: 0/1")
      │               │   └── TemuKunciRow (Label, "• Temu Kunci: 0/1")
      │               └── TrackerStatusLabel (Label, 13px, "Bahan lengkap. Siap dimasak di dapur.")
      ├── Reticle (ColorRect 4x4, PRESET_CENTER, mouse_filter=IGNORE, white 85%)
      └── PromptPanel (PanelContainer, PRESET_CENTER, offset_top=36px, mouse_filter=IGNORE)
          └── PromptLabel (Label, "[E] Interaksi", mouse_filter=IGNORE)
  ```
- **Logic in `scripts/ui/hud.gd`:**
  - Event-driven quest tracker updates:
    - Connects to `RecipeManager.recipe_tracked`, `recipe_untracked`, `recipe_progress_updated`, `cooking_state_changed`.
    - When untracked: shows `UntrackedContainer` with `"Buka buku [B] untuk memilih masakan."`, hides `TrackedContainer`.
    - When tracked: updates live counters (e.g. `• Bayam: 2/3`, `• Jagung: 1/1`, `• Temu Kunci: 1/1`).
    - When all ingredients >= required: displays `"Bahan lengkap. Siap dimasak di dapur."` in soft green.
    - When cooking is active/paused: displays `"Masakan dijeda"` or `"Sedang memasak"`.
  - Prompt & reticle methods:
    - `connect_detector(detector: Node) -> void`
    - `show_prompt(text: String) -> void`
    - `hide_prompt() -> void`
    - `is_prompt_visible() -> bool`
    - `get_prompt_text() -> String`
  - Zero-polling design (no per-frame computations in `_process`).

#### 4. `tests/suites/test_book.gd`
- Automated test suite validating:
  - **T01:** Track recipe from book -> HUD displays title and 3 ingredients with 0/3, 0/1, 0/1, no completion badge.
  - **T02:** Adding ingredients (e.g. 1 jagung) before tracking -> tracking immediately reflects 1/1 without needing re-acquisition.
  - **T03:** Untracking recipe (toggle) -> clears HUD to untracked prompt, leaves inventory and recipe progress 100% intact.
  - **T11:** Shared stock calculation -> items split between backpack and chest calculate identical total in both Book and HUD.
  - **T31:** Completing all ingredients (3 bayam, 1 jagung, 1 temu kunci) -> status badge indicates "Siap dimasak di dapur", but `is_recipe_completed()` remains false until actually cooked.
  - **T18 / T28:** Context switching to `ContextMode.BOOK` pauses simulation, frees mouse, and suppresses click bleed-through upon closing.
  - **Hierarchy & Focus:** Validates responsive container hierarchy and focus grabbing on `btn_track`.
  - **Landmark Diegetic Integration:** Simulates interacting with `book_family` landmark and confirms Book UI opens.

### 4.2 Existing Files to Update
1. `project.godot`:
   - Register autoload: `RecipeManager="*res://scripts/recipe/recipe_manager.gd"`.
2. `scripts/main.gd`:
   - Add `@onready var book_ui = $BookUI if has_node("BookUI") else null`.
   - Add `@onready var hud = $HUD if has_node("HUD") else null`.
   - Connect `book_family/Interactable.interacted` to open `BookUI`.
   - Connect `player` interaction detector to `hud`.
3. `scenes/main.tscn`:
   - Replace standalone `InteractionPrompt` with `HUD` (`scenes/ui/hud.tscn`).
   - Add `BookUI` (`scenes/ui/book_ui.tscn`).
4. `tests/test_runner.gd`:
   - Add `Suite 8: TestBook` (`tests/suites/test_book.gd`) to the test runner.

---

## 5. Verification Method

### 5.1 Independent Headless Test Commands
1. **Full Test Runner Execution:**
   ```powershell
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"
   ```
   *Expected outcome:* All 8 test suites pass with 0 failures and exit code 0.
2. **Adversarial Level & Landmark Verification:**
   ```powershell
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/adversarial_level_challenge.gd"
   ```
   *Expected outcome:* 95/95 assertions pass, confirming `book_family` position and collision clearance remain valid.
3. **Project Scene & UID Consistency Check:**
   ```powershell
   python ".agents/skills/godot-nodes-scenes/scripts/check_godot_project.py" .
   ```
   *Expected outcome:* 0 errors, 0 warnings across all files.
4. **Main Scene Smoke Run (60 frames):**
   ```powershell
   cmd /c "C:\Users\HP\.local\bin\godot.exe --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 60"
   ```
   *Expected outcome:* Executes cleanly without error or warning.

### 5.2 Interactive GUI / Playtest Verification Points
- Pressing `B` in world opens Book UI and frees mouse cursor; WASD player locomotion is disabled.
- Pressing `Esc` or `B` closes Book UI and recaptures mouse; clicking immediately does not trigger world interaction.
- Approaching the wooden table in the graybox house and pressing `E` on `book_family` opens the Book UI diegetically.
- Clicking "Lacak Masakan" updates the top-left HUD with the recipe title and 3 live counters.
- Picking up items updates the live counters without closing or reopening the book.
- Tab/Shift+Tab and Arrow keys traverse buttons, with `btn_track` focused by default.
- Untracking returns HUD to *"Buka buku [B] untuk memilih masakan."* without affecting inventory.

---
*Report generated and self-verified by explorer_book_001_2.*
