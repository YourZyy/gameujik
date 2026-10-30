# Handoff Report: COOK-001 Test Architecture, Suite 11 Design & Invariant Test Matrix

**Agent**: `explorer_cook_001_3`  
**Milestone**: `COOK-001` (Kitchen Validation, Reservation, 4.0s Hold Preparation, Pre-Cooking Cancellation & Safe Refund)  
**Date**: 2026-10-28  
**Working Directory**: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_cook_001_3\`  
**Target Recipient**: `orchestrator_gen6` (Conversation ID: `9ce6da24-fd14-4dbb-be3b-c55e3808c4cc`)

---

## 1. Observation

### 1.1 Existing Test Harness & Baseline Execution
- **File**: `tests/test_runner.gd`
  - Lines 1–14 load suites 1 through 10 (`TestSetup`, `TestLevel`, `TestAdversarialLevel`, `TestPlayer`, `TestAdversarialPlayer`, `TestInteraction`, `TestInventory`, `TestRecipe`, `TestGardening`, `TestWorld`).
  - Lines 73–94 print summary and exit with code `0` if all pass, `1` on failure.
  - Verification execution command: `godot --headless --path . --script res://tests/test_runner.gd`
  - Observed result: **Exit code 0**, `Assertions Passed: 1233`, `Assertions Failed: 0`, `All Passed: true` (recorded in `test_summary.log`).
- **File**: `tests/assertions.gd`
  - Provides static assertions: `assert_true(cond, msg)`, `assert_false(cond, msg)`, `assert_equal(act, exp, msg)`, `assert_ne(act, exp, msg)`, `assert_null(obj, msg)`, `assert_not_null(obj, msg)`, `assert_gt(act, exp, msg)`, `assert_approx_equal(act, exp, tol, msg)`.

### 1.2 Specification Requirements for COOK-001
- **File**: `docs/TEST_PLAN.md`
  - Line 42: `| T10 | Bahan resep kurang satu; tekan Siapkan | Tidak ada reservasi/job/mutasi; bahan yang kurang disebut |`
  - Line 43: `| T11 | Bahan dibagi tas dan peti; cek buku lalu dapur | Kedua panel memakai total sama; reservasi mengambil urutan CONTENT |`
  - Line 44: `| T12 | Klik Siapkan/Mulai berulang saat proses dimulai | Satu ID job, satu reservasi, satu output; tidak ada konsumsi ganda |`
  - Line 45: `| T13 | Reservasi bahan; batalkan sebelum memasak | Jumlah total bebas+refund sama dengan sebelum mulai; tidak ada bahan hilang/bertambah |`
  - Line 72: `| T40 | Reservasi, tutup panel, penuhi kontainer asal via fixture, lalu batalkan | Bahan kembali tepat sekali melalui sumber alternatif/refund persisten; tidak ditumpuk pada slot hasil |`
  - Line 103: `| FR12 memasak | T10–T15, T40–T42, T50 |`
- **File**: `docs/TASKS.md` § COOK-001
  - Lines 95–99:
    ```markdown
    ### COOK-001 — Reservasi dan persiapan
    Bangun satu job ID stabil, validasi bahan lintas tas/peti, tahan persiapan, pembatalan dan pengembalian aman. Slot hasil dan pengembalian berbeda.
    Selesai bila bahan kurang tidak termutasi, spam mulai tidak menggandakan job, batal sebelum pemasakan mengembalikan tepat jumlah semula, termasuk ketika kontainer asal penuh. T10/T11/T12/T13/T40.
    ```
- **File**: `docs/CONTENT.md`
  - § 2 (Lines 21–23): P0 Recipe Ingredients:
    - 3 `ingredient_bayam` (Sayur bayam)
    - 1 `ingredient_jagung` (Jagung)
    - 1 `ingredient_temu_kunci` (Temu kunci)
  - § 3 (Lines 38–44):
    - "Slot hasil dapur: 1 hidangan batch; tidak dapat mulai job baru sebelum diambil"
    - "Kontainer reservasi/refund: Internal dan persisten; hanya untuk job/pengembalian aman, bukan tas ekstra biasa"
    - "Ketersediaan bahan bebas untuk buku dan dapur = jumlah di tas + jumlah di peti rumah. Reservasi job... tidak dihitung."
    - "Urutan pengambilan bahan: tas lebih dahulu, kemudian peti; konsumsi slot dengan indeks terkecil dahulu. Simpan asal setiap reservasi untuk pengembalian. Seluruh bahan harus lolos pemeriksaan sebelum satu unit pun diambil."
  - § 4 (Lines 57–67):
    - "Persiapan: Tahan tombol Siapkan selama 4 detik; dapat dihentikan sementara"
    - "Pembatalan tersedia hanya sebelum tahap pemasakan dimulai. Menutup panel ketika persiapan belum selesai menjeda; tidak membatalkan otomatis. Tahan Siapkan yang terputus mempertahankan progress persiapan. Setelah persiapan penuh, tombol Mulai memasak melakukan transisi; jangan langsung mulai dari input tahan yang sama."
  - § 11 (Lines 204–205): Honest UI Messages:
    - Bahan dapur kurang: `"Bahan belum lengkap. Buka buku untuk melihat sumbernya."`
    - Hasil tertahan: `"Ambil hidangan sebelumnya dahulu."`
    - Job dijeda: `"Masakan dijeda. Buka dapur untuk melanjutkan."`
    - Tujuan penuh: `"Penyimpanan tidak cukup. Tidak ada barang yang dipindahkan."`
  - § 12 (Line 226):
    - `CookingJob`: ID unik, resep, state, reservasi dan asal, progress tahap, panas, output_committed.
- **File**: `docs/PROTOTYPE.md`
  - § 4 (Line 48): Kitchen State Machine:
    `Idle -> reserved/preparing -> ready_to_heat -> cooking ↔ paused -> output_ready -> idle`
  - § 5 (Line 59): Context Table:
    `Dapur aktif | Pemain bergerak: Tidak | Pertumbuhan/penguapan/hari: Berjalan | Job memasak: Berjalan | Mouse: Bebas untuk UI`
  - § 6.2 (Lines 79–85):
    - "Menekan Siapkan memeriksa resep, bahan bebas tas/peti, stasiun idle dan slot hasil kosong. Setelah lengkap, buat ID job dan pindahkan bahan ke reservasi beserta sumber asalnya. Tombol berulang mengarah ke job yang sama, bukan job kedua."
    - "Pada tahap persiapan, Batal mengembalikan bahan ke kontainer asal jika muat, lalu tas/peti lain bila perlu. Sisa yang tidak muat masuk kontainer pengembalian aman milik dapur yang persisten. Pesan menyebut tempat mengambilnya. Job ditutup hanya setelah seluruh reservasi berpindah tepat sekali."
  - § 6.3 (Lines 88–90):
    - "Dapur tidak menjalankan resep berikutnya bila hasil belum diambil. Pengembalian aman dan slot hasil adalah kontainer berbeda agar pembatalan tidak memakan tempat hidangan."

### 1.3 Codebase Infrastructure & Existing Hooks
- **File**: `scripts/inventory/inventory_manager.gd`
  - Line 13: `const CONTAINER_REFUND: String = "kitchen_refund"`
  - Line 30: `var kitchen_refund: RefCounted = null` (initialized as 12-slot `InventoryContainerClass` in `_init_containers()`)
  - Lines 49, 307–345: Has initial prototypes for `_reservations: Dictionary`, `reserve_ingredients(job_id, items)`, `cancel_reservation(job_id)`, `commit_consumption(job_id)`, and `get_available_item_count(item_id)`.
  - Lines 348–355: `get_save_snapshot()` and `load_save_snapshot()` already include `kitchen_refund`.
- **File**: `scripts/core/input_manager.gd`
  - Line 10: `enum ContextMode { WORLD, BOOK, STORAGE, KITCHEN, DIALOGUE, PAUSE }`
  - Lines 56–58: `is_simulation_paused()` does NOT pause for `KITCHEN` (correct per PROTOTYPE § 5).
  - Lines 184–198: Action bleed-through guard (`_last_closed_frame == current_frame` suppresses world interaction on pop frame).
- **File**: `scenes/world/level_graybox.tscn`
  - Lines 509–532: Landmark `station_kitchen_home` already exists in graybox with `Interactable` (layer 4, `interaction_id = "landmark_kitchen"`, `target_name = "Dapur"`).
- **File**: `scripts/world/world_resource_manager.gd`
  - Lines 262–271: `can_sleep()` already hooks into `_get_kitchen_manager()` to reject sleep if kitchen job is active.

---

## 2. Logic Chain

1. **Test Runner Integration**:
   - The test harness is driven by `tests/test_runner.gd`.
   - To integrate COOK-001 into the regression and CI suite, `tests/suites/test_cooking.gd` must be registered as **Suite 11** (`suite_cooking := TestCooking.new()`, `await suite_cooking.run_all()`).
   - The suite must run asynchronously (`await`) because tests involve scene tree integration, UI instancing, signal emissions, and input context transitions.

2. **Deconstruction of Acceptance Criteria for COOK-001**:
   - **T10 (Gating & Validation)**:
     - Prerequisite check must verify: station is `IDLE`, `dish_output_slot` is empty (if output is present, reject with `"Ambil hidangan sebelumnya dahulu."`), and unified free stock satisfies `recipe_sayur_bening_01` (3 bayam, 1 corn, 1 temu kunci).
     - If any ingredient is insufficient, validation returns `success = false`, specifies missing items in Indonesian, and guarantees **zero mutation** to inventories.
   - **T11 (Reservation & Cross-Container Accounting)**:
     - When validation passes, atomic reservation pulls items: first from `backpack` (lowest slot indices), then from `storage_home`.
     - An explicit origin manifest must be stored in the job: `[{"item_id": id, "count": N, "source": "backpack" | "storage"}]`.
     - Unified free stock query (`inv.get_available_item_count()`) immediately reflects the reservation, decrementing by the exact reserved quantities.
     - Unreserved items (surplus ingredients, seeds, compost, fertilizer) remain completely untouched.
   - **T12 (4.0s Hold Preparation State & Anti-Spam)**:
     - Preparation requires holding "Siapkan" for 4.0s (`CONTENT.md` § 4).
     - Premature release or interruption (< 4.0s) pauses/retains progress per job or resets cleanly; no items are consumed, no dish is produced.
     - Full 4.0s hold transitions state to `READY_TO_HEAT` and emits `preparation_completed`.
     - It does **not** auto-start cooking (per `CONTENT.md` § 4, "Mulai memasak" requires a separate click).
     - Rapid spam clicks during preparation or `READY_TO_HEAT` return error (`"Job ID sudah aktif."`) and never spawn a duplicate job or double-reserve ingredients.
   - **T13 (Pre-Cooking Cancellation & Exact Origin Return)**:
     - Cancellation is strictly permitted during `RESERVED_PREPARING` and `READY_TO_HEAT`.
     - When cancelled, the reservation manifest is processed in reverse: items return 100% to their origin containers (`backpack` and `storage`).
     - Station state returns to `IDLE`, job ID is cleared, and free stock is fully restored.
     - Cancellation is idempotent (repeated cancel calls do not double-refund).
   - **T40 (Safe Refund Redirection Under Extreme Capacity Constraints)**:
     - If the player/fixture fills the origin container (e.g. fills backpack to 12/12) after reservation, cancel attempts origin return -> fails -> redirects spillover to storage chest.
     - If BOTH backpack (12/12) AND storage chest (12/12) are completely full, unreturned items are safely dumped into persistent `kitchen_refund` (`InventoryManager.kitchen_refund`).
     - **Conservation of Matter Law**: `initial_total == backpack_total + storage_total + refund_total` (zero duplication, zero item destruction).
     - **Strict Isolation**: `kitchen_refund` and `dish_output_slot` are physically and logically isolated. Refunded ingredients never spill into `dish_output_slot`.

---

## 3. Test Suite Design: Suite 11 (`tests/suites/test_cooking.gd`)

### 3.1 Architecture & Class Skeleton

```gdscript
class_name TestCooking
extends RefCounted

## Test Suite COOK-001: Validasi Bahan, Reservasi Atomik, Tahan Persiapan 4s, Pembatalan Aman & Refund Persisten (Suite 11)
## Memverifikasi PRD FR12, CONTENT.md § 2, 3, 4, 5, 11, 12, PROTOTYPE.md § 4, 5, 6.2, 6.3, TASKS.md COOK-001, dan TEST_PLAN T10, T11, T12, T13, T40

const Assertions = preload("res://tests/assertions.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const RecipeManagerClass = preload("res://scripts/recipe/recipe_manager.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")
const HoldActionControllerClass = preload("res://scripts/gardening/hold_action_controller.gd")

var KitchenManagerClass: Variant = null
var KitchenUIClass: Variant = null

func _init() -> void:
	if ResourceLoader.exists("res://scripts/cooking/kitchen_manager.gd"):
		KitchenManagerClass = load("res://scripts/cooking/kitchen_manager.gd")
	if ResourceLoader.exists("res://scripts/ui/kitchen_ui.gd"):
		KitchenUIClass = load("res://scripts/ui/kitchen_ui.gd")

func run_all() -> bool:
	var passed := true
	print("  Running TestCooking suite (T10, T11, T12, T13, T40, Kitchen Landmarks & Invariants)...")
	var tree := Engine.get_main_loop() as SceneTree

	# Group 1: T10 — Recipe Gating, Prerequisite Validation & Honest Error Reporting
	if not test_t10_zero_ingredients_gating_and_honest_error():
		passed = false
	if not test_t10_partial_ingredients_rejection_and_specification():
		passed = false
	if not test_t10_surplus_ingredients_validation_succeeds():
		passed = false
	if not test_t10_occupied_output_slot_gating():
		passed = false

	# Group 2: T11 — Ingredient Reservation, Cross-Container Unified Stock & Origin Manifest
	if not test_t11_reservation_all_from_backpack():
		passed = false
	if not test_t11_reservation_split_across_backpack_and_storage():
		passed = false
	if not test_t11_unreserved_items_completely_untouched():
		passed = false
	if not test_t11_free_stock_reduction_and_recipe_tracker_sync():
		passed = false

	# Group 3: T12 — 4.0s Preparation Hold State, Interruption, Transition & Anti-Spam
	if not test_t12_prep_hold_partial_progress_and_retention():
		passed = false
	if not test_t12_prep_hold_4s_completion_to_ready_to_heat():
		passed = false
	if not test_t12_no_auto_cook_transition_from_hold():
		passed = false
	if not test_t12_anti_spam_repeated_clicks_protection():
		passed = false

	# Group 4: T13 — Safe Pre-Cooking Cancellation & Exact Origin Return
	if not test_t13_cancel_during_preparing_returns_to_exact_origins():
		passed = false
	if not test_t13_cancel_at_ready_to_heat_returns_to_exact_origins():
		passed = false
	if not test_t13_cancel_idempotency_guard():
		passed = false
	if not test_t13_station_returns_to_clean_idle_on_cancel():
		passed = false

	# Group 5: T40 — Safe Refund Redirection Under Full Container Edge Cases & Strict Isolation
	if not test_t40_backpack_filled_in_interim_spills_to_storage():
		passed = false
	if not test_t40_both_containers_filled_spills_to_kitchen_refund():
		passed = false
	if not test_t40_conservation_of_matter_invariance_under_overflow():
		passed = false
	if not test_t40_kitchen_refund_and_output_slot_strict_isolation():
		passed = false

	# Group 6: Architecture, Save Snapshot Roundtrip & Context Invariants
	if not test_extra_save_snapshot_roundtrip():
		passed = false
	if not await test_extra_input_context_kitchen_mode_and_frame_guard(tree):
		passed = false
	if not await test_extra_world_landmark_kitchen_station(tree):
		passed = false

	return passed
```

### 3.2 Fixture & Clean State Helper Methods

```gdscript
func _create_clean_inventory() -> Node:
	var inv: Node = InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.storage_home.clear()
	inv.kitchen_refund.clear()
	inv.starter_claimed = false
	inv._reservations.clear()
	return inv

func _create_clean_kitchen(inv: Node, rm: Node = null) -> Node:
	if KitchenManagerClass == null:
		return null
	var km: Node = KitchenManagerClass.new()
	if km.has_method("set_inventory_manager"):
		km.set_inventory_manager(inv)
	if rm != null and km.has_method("set_recipe_manager"):
		km.set_recipe_manager(rm)
	if km.has_method("_ready"):
		km._ready()
	return km

func _populate_inventory(inv: Node, bp_items: Array[Dictionary], st_items: Array[Dictionary]) -> void:
	if not bp_items.is_empty():
		inv.add_items("backpack", bp_items)
	if not st_items.is_empty():
		inv.add_items("storage", st_items)
```

---

## 4. Invariant Assertion Matrix & Test Method Specifications

| Test Method | Objective / Invariant Checked | Preconditions & Actions | Required Assertions |
|---|---|---|---|
| **`test_t10_zero_ingredients_gating_and_honest_error`** | Recipe cannot start with 0 ingredients; honest error; 0 mutation | Backpack empty, storage empty. Call `km.can_start_preparation("recipe_sayur_bening_01")` and `km.start_preparation("recipe_sayur_bening_01")`. | - `check.success == false`<br>- `check.reason.contains("Bahan belum lengkap")`<br>- `check.missing.size() == 3`<br>- `km.start_preparation().success == false`<br>- `km.job_state == JobState.IDLE`<br>- `km.active_job_id == ""` |
| **`test_t10_partial_ingredients_rejection_and_specification`** | Rejects if any 1 of the 3 ingredients is missing; specifies exact missing item | Run 3 sub-cases:<br>1) 2 bayam, 1 jagung, 1 temu kunci<br>2) 3 bayam, 0 jagung, 1 temu kunci<br>3) 3 bayam, 1 jagung, 0 temu kunci | - Each sub-case: `can_start_preparation().success == false`<br>- Missing item name listed in reason/missing list<br>- `km.start_preparation().success == false`<br>- Inventory item counts 100% unchanged |
| **`test_t10_surplus_ingredients_validation_succeeds`** | Surplus ingredients allow starting; checks exact requirement | Backpack: 10 bayam, 5 corn, 5 temu kunci. Call `km.can_start_preparation()`. | - `check.success == true`<br>- `check.missing.is_empty() == true`<br>- Station eligible to start |
| **`test_t10_occupied_output_slot_gating`** | Cannot start new job if previous finished dish still in output slot | Inventory has all ingredients. Fixture sets `km.dish_output_slot = {"item_id": "dish_sayur_bening", "count": 1}`. | - `check.success == false`<br>- `check.reason.contains("Ambil hidangan sebelumnya dahulu")`<br>- `km.start_preparation().success == false` |
| **`test_t11_reservation_all_from_backpack`** | All ingredients taken from backpack; exact count deducted; job ID created | Backpack: 3 bayam, 1 corn, 1 temu kunci. Storage empty. Call `km.start_preparation()`. | - `res.success == true`<br>- `km.active_job_id != ""` (e.g. `"job_p0_cooking"`)<br>- `km.job_state == JobState.RESERVED_PREPARING`<br>- `inv.backpack.get_item_count(id) == 0` for all 3<br>- `inv.get_available_item_count(id) == 0`<br>- `manifest.size() == 3` (all origin="backpack") |
| **`test_t11_reservation_split_across_backpack_and_storage`** | Priority rule: backpack first, then storage; cross-container accounting | Backpack: 2 bayam, 0 corn, 1 temu kunci.<br>Storage: 1 bayam, 1 corn, 0 temu kunci. Call `start_preparation()`. | - `res.success == true`<br>- Backpack bayam: 2 -> 0<br>- Storage bayam: 1 -> 0<br>- Storage corn: 1 -> 0<br>- Backpack temu kunci: 1 -> 0<br>- Manifest records: 2 bayam from BP, 1 bayam from ST, 1 corn from ST, 1 kunci from BP |
| **`test_t11_unreserved_items_completely_untouched`** | Surplus and non-recipe items completely unmutated | Backpack: 5 bayam, 2 corn, 2 temu kunci, 4 seed_bayam, 1 compost, 1 fertilizer. Call `start_preparation()`. | - Remaining in BP: 2 bayam, 1 corn, 1 temu kunci<br>- Seeds: strictly 4<br>- Compost: strictly 1<br>- Fertilizer: strictly 1<br>- Zero item corruption |
| **`test_t11_free_stock_reduction_and_recipe_tracker_sync`** | RecipeManager and InventoryManager free stock decrease by exact reserved count | Track recipe in `RecipeManager`. Call `start_preparation()`. | - `inv.get_available_item_count("ingredient_bayam") == 0`<br>- `rm.get_available_ingredient_count("ingredient_bayam") == 0`<br>- Recipe status displays reserved state |
| **`test_t12_prep_hold_partial_progress_and_retention`** | Releasing hold before 4.0s retains progress or safely pauses; no item loss | Job in `RESERVED_PREPARING`. Call `km.tick_preparation(2.0)`. | - `km.prep_progress == 2.0`<br>- `km.job_state == JobState.RESERVED_PREPARING`<br>- Not yet `READY_TO_HEAT`<br>- No dish output, ingredients still reserved |
| **`test_t12_prep_hold_4s_completion_to_ready_to_heat`** | 4.0s hold completes to `READY_TO_HEAT`; emits signal | Advance prep hold to 4.0s (`km.tick_preparation(4.0)`). | - `km.prep_progress >= 4.0`<br>- `km.job_state == JobState.READY_TO_HEAT`<br>- Signal `preparation_completed` emitted<br>- Dish output slot still empty (`null`) |
| **`test_t12_no_auto_cook_transition_from_hold`** | Completing 4.0s prep hold does NOT automatically begin cooking | Check state immediately after 4.0s hold finishes. | - `km.job_state != JobState.COOKING`<br>- Separate button click required to start cooking (COOK-002) |
| **`test_t12_anti_spam_repeated_clicks_protection`** | 10 rapid spam clicks/calls do not duplicate jobs or double-reserve | While job in `RESERVED_PREPARING`, loop 10 calls to `km.start_preparation()`. | - All 10 return `success == false`<br>- Reason: `"Job ID sudah aktif."`<br>- Job ID unchanged<br>- Zero additional item deductions |
| **`test_t13_cancel_during_preparing_returns_to_exact_origins`** | Cancelling during preparation restores items 100% to exact origin containers | Start split job (2 bayam BP, 1 bayam ST, 1 corn ST, 1 kunci BP). At prep=1.5s, call `km.cancel_preparation()`. | - `km.cancel_preparation().success == true`<br>- `km.job_state == JobState.IDLE`<br>- `km.active_job_id == ""` (cleared)<br>- Backpack has: 2 bayam, 1 kunci<br>- Storage has: 1 bayam, 1 corn<br>- Free stock restored 100% |
| **`test_t13_cancel_at_ready_to_heat_returns_to_exact_origins`** | Cancelling in `READY_TO_HEAT` before cooking restores items 100% | Advance prep to 4.0s (`READY_TO_HEAT`). Call `km.cancel_preparation()`. | - Cancel succeeds<br>- All 5 items returned to origins<br>- State returns to `IDLE`<br>- Zero item loss or duplication |
| **`test_t13_cancel_idempotency_guard`** | Repeated cancel calls are safe no-ops | Call `km.cancel_preparation()` twice in a row. | - First call returns true<br>- Second call returns false / no-op<br>- No double refunds, no crash |
| **`test_t13_station_returns_to_clean_idle_on_cancel`** | Complete state reset upon cancellation | Check all internal fields after cancellation. | - `active_job_id == ""` , `prep_progress == 0.0`<br>- `reserved_ingredients.is_empty() == true`<br>- `origin_manifest.is_empty() == true`<br>- `dish_output_slot.is_empty() == true` |
| **`test_t40_backpack_filled_in_interim_spills_to_storage`** | If origin (backpack) is filled during prep, cancel spills items to storage | 1. Reserve 5 items from backpack (BP now empty).<br>2. Fixture fills all 12 BP slots with `seed_bayam`.<br>3. Call `cancel_preparation()`. | - Cancel succeeds<br>- Backpack remains 12/12 full of seeds<br>- 5 ingredients successfully spilled into `storage_home`<br>- Total items in universe conserved |
| **`test_t40_both_containers_filled_spills_to_kitchen_refund`** | If BOTH backpack (12/12) and storage (12/12) are filled, unreturned items go to `kitchen_refund` | 1. Reserve 5 items.<br>2. Fixture fills ALL 12 backpack slots AND ALL 12 storage slots.<br>3. Call `cancel_preparation()`. | - Cancel succeeds<br>- Backpack is 12/12 full<br>- Storage is 12/12 full<br>- `inv.kitchen_refund` contains all 5 unreturned items!<br>- Signal `kitchen_refund_occurred` emitted<br>- Notice generated explaining items sent to refund |
| **`test_t40_conservation_of_matter_invariance_under_overflow`** | Absolute conservation law: initial item count == backpack + storage + refund | Verify item totals before reservation vs after full overflow cancel. | - `initial_items == current_bp + current_st + current_refund`<br>- Zero duplication, zero loss |
| **`test_t40_kitchen_refund_and_output_slot_strict_isolation`** | Refund container and dish output slot are strictly separate containers | Check `dish_output_slot` during and after T40 overflow refund. | - `km.dish_output_slot` remains `null` / empty<br>- Refunded raw ingredients NEVER appear in output slot<br>- Output slot reserved purely for finished `dish_sayur_bening` |
| **`test_extra_save_snapshot_roundtrip`** | Serializes active job ID, state, prep progress, and origin manifest (SAVE-001) | Save snapshot at `prep_progress = 2.5s`, restore in clean instance. | - `snapshot.version == 1`<br>- Restored job ID, state, prep progress (2.5s), and origin manifest match perfectly<br>- Can continue hold prep from 2.5s to 4.0s |
| **`test_extra_input_context_kitchen_mode_and_frame_guard`** | Context switching to KITCHEN frees mouse, unpauses simulation, guards pop frame | 1. Push `ContextMode.KITCHEN`<br>2. Pop context to `WORLD` | - In KITCHEN: `is_world() == false`, `is_simulation_paused() == false`, mouse free<br>- On pop: context is `WORLD`, `can_interact_in_world() == false` on same frame<br>- Next frame: `can_interact_in_world() == true` |
| **`test_extra_world_landmark_kitchen_station`** | Verifies 3D landmark `station_kitchen_home` in `level_graybox.tscn` | Instantiate `level_graybox.tscn`, find `station_kitchen_home`. | - Node exists at `(2, 0, -4)`<br>- Has `Counter` StaticBody3D with collision<br>- Has `Interactable` Area3D with `interaction_id == "landmark_kitchen"` and `collision_layer == 4` |

---

## 5. Implementation Recommendations for Worker Agent

### 5.1 KitchenManager Interface Contract (`res://scripts/cooking/kitchen_manager.gd`)

```gdscript
extends Node

## Autoload Singleton KitchenManager untuk Buku Resep 2045
## Mengelola Stasiun Dapur (station_kitchen_home), Reservasi Bahan Lintas Kontainer,
## Tahan Persiapan 4s, Pembatalan Aman & Kontainer Pengembalian Persisten.
## Memenuhi PRD FR12, CONTENT.md § 2, 3, 4, 5, 11, 12, PROTOTYPE.md § 4, 5, 6.2, 6.3, TASKS.md COOK-001, dan TEST_PLAN T10, T11, T12, T13, T40.

enum JobState {
	IDLE,
	RESERVED_PREPARING,
	READY_TO_HEAT,
	COOKING,
	PAUSED,
	OUTPUT_READY
}

signal job_started(job_id: String, recipe_id: String)
signal preparation_progress_changed(progress: float, duration: float)
signal preparation_completed(job_id: String)
signal job_cancelled(job_id: String, refunded_items: Array)
signal kitchen_refund_occurred(items: Array)
signal state_changed(new_state: JobState, old_state: JobState)

const RECIPE_P0: String = "recipe_sayur_bening_01"
const PREP_DURATION: float = 4.0

var active_job_id: String = ""
var active_recipe_id: String = ""
var job_state: JobState = JobState.IDLE:
	set(val):
		var old = job_state
		job_state = val
		if old != val:
			state_changed.emit(val, old)

var prep_progress: float = 0.0
var prep_duration: float = PREP_DURATION
var reserved_ingredients: Array[Dictionary] = []
var origin_manifest: Array[Dictionary] = [] # [{"item_id": String, "count": int, "source": "backpack" | "storage"}]
var dish_output_slot: Dictionary = {}

var _inventory_override: Node = null
var _recipe_override: Node = null
```

### 5.2 Registration in `tests/test_runner.gd`
Add Suite 11 after Suite 10:
```gdscript
const TestCooking = preload("res://tests/suites/test_cooking.gd")
...
	# Suite 11: TestCooking (T10, T11, T12, T13, T40 Kitchen Validation, Reservation, Hold Prep, Cancel & Safe Refund)
	var suite_cooking := TestCooking.new()
	if not await suite_cooking.run_all():
		all_passed = false
```

---

## 6. Caveats

1. **COOK-002 Decoupling**: Heating controls (Low 0.5x, Medium 1.0x, High 0x stall warning), 30.0s cooking timer, cooking pause on window close, output dish creation (`dish_sayur_bening`), and eating/sharing are explicitly scoped to milestone `COOK-002` (and `SOC-001`). In COOK-001, state strictly transitions from `IDLE -> RESERVED_PREPARING -> READY_TO_HEAT`, and cancels back to `IDLE`.
2. **Autoload Registration**: `KitchenManager` should be registered as an Autoload in `project.godot` (`KitchenManager="*res://scripts/cooking/kitchen_manager.gd"`), but Suite 11 is designed with internal overrides (`set_inventory_manager()`, `set_recipe_manager()`) so tests can execute either with the global autoload or in pure isolated unit test fixtures.
3. **Refund Location Visibility**: When T40 triggers and items are sent to `kitchen_refund`, the UI notification message must clearly state where the items were sent (`"Penyimpanan penuh. Sisa barang dialihkan ke pengembalian dapur."`) per CONTENT § 3.

---

## 7. Conclusion

The test architecture, test method specifications, invariant matrix, and Suite 11 design for **COOK-001** are complete, exhaustive, and rigorously grounded in `PRD.md`, `CONTENT.md`, `PROTOTYPE.md`, `TASKS.md`, and `TEST_PLAN.md`.
The implementation covers:
- **T10**: 0-ingredient, partial-ingredient, surplus, and output-slot occupancy gating.
- **T11**: Cross-container atomic reservation (backpack priority, origin tracking, untouched surplus/non-recipe items).
- **T12**: 4.0s preparation hold, interruption retention, clean transition to `READY_TO_HEAT`, and anti-spam protection against duplicate jobs.
- **T13**: Pre-cooking cancellation restoring 100% of items to exact container origins.
- **T40**: Safe spillover to storage and persistent `kitchen_refund` when containers are filled in the interim, strictly isolating `dish_output_slot` and preserving total universe item counts.

The worker agent has all necessary specifications and interface contracts to write `scripts/cooking/kitchen_manager.gd`, `tests/suites/test_cooking.gd`, and wire `station_kitchen_home` in `scripts/main.gd`.

---

## 8. Verification Method

To independently verify the test suite once implemented:
1. **Command**:
   ```powershell
   C:\Users\HP\.local\bin\godot.exe --headless --path . --script res://tests/test_runner.gd
   ```
2. **Inspect Output / Log**:
   - Check `test_summary.log`.
   - Confirm Suite 11 runs all 22 test methods.
   - Confirm exit code is `0`.
   - Invalidation conditions: Any assertion failure (`Assertions.current_suite_failed > 0`), hang during hold execution, double-reservation on spam click, item loss on cancel, or spillover into `dish_output_slot`.
