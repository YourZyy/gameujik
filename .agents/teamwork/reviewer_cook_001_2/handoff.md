# Review & Adversarial Audit Report: COOK-001 (reviewer_cook_001_2)

## 1. Observation

1. **Autoload Singleton Configuration & Namespace Safety (`project.godot` & `scripts/cooking/kitchen_manager.gd`):**
   - In `project.godot` line 21:
     ```ini
     KitchenManager="*res://scripts/cooking/kitchen_manager.gd"
     ```
   - In `scripts/cooking/kitchen_manager.gd` line 1:
     `kitchen_manager.gd` starts with `extends Node` and does not define a conflicting `class_name KitchenManager`. This prevents cyclic declaration warnings in Godot 4.7.2.
   - The global singleton `KitchenManager` is registered and functional across all scenes.

2. **UI Responsive Layout and Signal Bindings (`scenes/ui/kitchen_ui.tscn` & `scripts/ui/kitchen_ui.gd`):**
   - `scenes/ui/kitchen_ui.tscn`: Root `KitchenUI` node is a `CanvasLayer` at `layer = 10`. The layout uses `RootControl` (preset 15 / full rect), `DimBackground` (`ColorRect`), `CenterContainer`, and `MainPanel` (`PanelContainer` with `custom_minimum_size = Vector2(760, 520)`).
   - `scenes/main.tscn` line 54 instances `KitchenUI` under `Main`.
   - `scripts/ui/kitchen_ui.gd` connects to `KitchenManager` signals:
     - `state_changed` -> `_on_kitchen_state_changed` / `refresh_ui()`
     - `prep_completed` -> `refresh_ui()`
     - `job_cancelled` -> `refresh_ui()`
     - `refund_storage_updated` -> `refresh_ui()`
     - `inventory_updated` from `InventoryManager` -> `refresh_ui()`
   - Button callbacks and input hooks:
     - `CloseButton.pressed` -> `close()`
     - `StartPrepButton.pressed` -> `_on_start_prep_pressed()`
     - `CancelButton.pressed` -> `_on_cancel_pressed()`
     - `ClaimRefundButton.pressed` -> `_on_claim_refund_pressed()`
     - `HoldPrepButton` (`button_down` / `button_up`) -> controls `_is_holding`.
     - `_process(delta)`: when `visible and _is_holding`, calls `KitchenManager.advance_prep(delta)` and updates `PrepProgressBar` (0.0s to 4.0s).
     - `_unhandled_input(event)`: captures `pause_menu` (Esc), calls `close()`, and marks input handled via `get_viewport().set_input_as_handled()`.

3. **Landmark `station_kitchen_home` & World Raycast Integration (`scenes/world/level_graybox.tscn`, `scripts/main.gd`, `scripts/ui/hud.gd`):**
   - In `scenes/world/level_graybox.tscn` lines 509–532:
     - Node `station_kitchen_home` located at `Vector3(2, 0, -4)` inside the home.
     - Child `Counter`: `StaticBody3D` with collision shape `BoxShape3D_wuyg5`.
     - Child `Interactable`: `Area3D`, `collision_layer = 4` (Interactables layer), `interaction_id = "landmark_kitchen"`, `target_name = "Dapur"`.
   - In `scripts/main.gd` lines 99–105 and 303–309:
     - Connects `interactable.interacted` on `station_kitchen_home` to `_on_kitchen_station_interacted`.
     - Pushes `InputManager.ContextMode.KITCHEN` and calls `kitchen_ui.open()`.
   - In `scripts/ui/hud.gd` lines 458–468:
     `format_contextual_prompt` renders dynamic Indonesian text for `landmark_kitchen`:
     - If `km.has_ready_output()`: `"[E] Ambil Masakan"`
     - If `km.is_cooking_active()`: `"[E] Buka Dapur (Sedang Memasak)"`
     - If `km.is_job_active()`: `"[E] Lanjutkan Dapur"`
     - Else: `"[E] Masak"`

4. **InputManager Context Switching (`scripts/core/input_manager.gd`):**
   - Context `ContextMode.KITCHEN` (index 3) is integrated in `InputManager`.
   - When entering `KITCHEN`:
     - `_sync_mouse_mode()` sets `Input.mouse_mode = Input.MOUSE_MODE_VISIBLE`.
     - `_sync_player_gating()` disables player controller movement (`movement_enabled = false`) and mouse look (`look_enabled = false`).
     - `is_simulation_paused()` returns `false` (kitchen mode is intentionally excluded from paused contexts, ensuring hold timers and world progression continue).
   - When exiting `KITCHEN` (via `CloseButton` or `Esc`):
     - `consume_and_close(&"pause_menu")` pops the context back to `WORLD`.
     - Mouse mode returns to `MOUSE_MODE_CAPTURED`.
     - Player controller movement and look are re-enabled.
     - Action suppression prevents input bleed-through to world interactions on the same frame.

5. **Save Snapshot Envelope v1 Roundtrip Persistence (`scripts/cooking/kitchen_manager.gd` & `scripts/inventory/inventory_manager.gd`):**
   - `KitchenManager.get_save_snapshot()` outputs envelope v1 schema:
     ```gdscript
     {
         "version": 1,
         "job_state": int(job_state),
         "active_job_id": active_job_id,
         "active_recipe_id": active_recipe_id,
         "prep_progress": prep_progress,
         "prep_duration": prep_duration,
         "reserved_ingredients": reserved_ingredients.duplicate(true),
         "origin_manifest": origin_manifest.duplicate(true),
         "origin_records": origin_manifest.duplicate(true),
         "dish_output_slot": dish_output_slot.duplicate(true),
         "current_job": current_job.duplicate(true)
     }
     ```
   - `KitchenManager.load_save_snapshot(data)` parses schema safely, reconstructs all collections, and notifies `RecipeManager.set_cooking_state`.
   - `InventoryManager` includes `kitchen_refund` container contents in its snapshot and restores them reliably.

6. **Automated Headless Test Suite Execution (`tests/test_runner.gd`):**
   - Command executed:
     `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless --path . --script res://tests/test_runner.gd"`
   - Output summary:
     ```
     ==================================================
     [TEST_RUNNER] SUMMARY:
       Assertions Passed: 1386
       Assertions Failed: 0
       RESULT: ALL SUITES PASSED (Exit Code: 0)
     ==================================================
     ```
   - Test log in `test_summary.log`:
     ```
     Assertions Passed: 1386
     Assertions Failed: 0
     All Passed: true
     ```
   - All 11 suites passed, including all 26 test methods in Suite 11 (`TestCooking`).

---

## 2. Logic Chain

1. **Integrity Violation Analysis:**
   - Source code inspection of `scripts/cooking/kitchen_manager.gd`, `scripts/ui/kitchen_ui.gd`, `scripts/main.gd`, and `scripts/ui/hud.gd` reveals no hardcoded test results, facade shortcuts, or dummy logic.
   - Calculations for item availability (`get_available_item_count`), multi-container item withdrawals (`start_preparation`), incremental hold clamping (`advance_prep`), 3-tier cascade refund (`cancel_preparation`), and refund container recovery (`claim_refund_items`) operate on genuine data structures and state variables.
   - `TestCooking` executes real assertions against fresh instances of `InventoryManager`, `RecipeManager`, `KitchenManager`, and `WorldResourceManager`.
   - **Integrity Verdict:** ZERO integrity violations detected.

2. **Adversarial Stress Testing & Attack Vectors:**
   - **Attack Vector 1: Rapid Click / Action Spamming**
     - Scenario: User rapidly triggers `start_preparation` while a job is already in progress.
     - Defense: `is_job_active()` check at the top of `start_preparation` rejects subsequent calls with `{"success": false, "reason": "Job ID sudah aktif.", "idempotent": true}`. Verified in `test_t12_anti_spam_repeated_clicks_protection`.
   - **Attack Vector 2: Container Overflow on Cancellation (T40)**
     - Scenario: Ingredients are reserved from backpack and chest. During preparation, both backpack (12/12) and storage chest (12/12) are completely filled with other items (e.g., seeds and compost). The user cancels preparation.
     - Defense: The 3-tier refund logic redirects items that do not fit in primary or alternative containers into `inv.kitchen_refund`. Total items in the universe remain exactly conserved (485 items constant). Verified in `test_t40_both_containers_filled_spills_to_kitchen_refund` and `test_t40_conservation_of_matter_invariance_under_overflow`.
   - **Attack Vector 3: Output Slot Contamination**
     - Scenario: Cancelled raw ingredients spill into `dish_output_slot`.
     - Defense: `cancel_preparation` exclusively routes items to `backpack`, `storage_home`, and `kitchen_refund`. `dish_output_slot` remains untouched and empty. Verified in `test_t40_kitchen_refund_and_output_slot_strict_isolation`.
   - **Attack Vector 4: Auto-Cooking Exploit from Hold Input**
     - Scenario: User holds down "Siapkan" past 4.0s hoping to automatically start cooking.
     - Defense: Upon reaching 4.0s, state transitions to `READY_TO_HEAT`. Subsequent ticks do nothing because `advance_prep` gates on `job_state == RESERVED_PREPARING`. The system requires an explicit user action on `StartCookingButton` to proceed to cooking (planned for COOK-002). Verified in `test_t12_no_auto_cook_transition_from_hold`.
   - **Attack Vector 5: Circumvention via Sleep Interlock**
     - Scenario: User initiates ingredient preparation and attempts to sleep in bed to advance the day.
     - Defense: `WorldResourceManager.can_sleep()` queries `KitchenManager.is_job_active()`. Since the job is active, sleep is refused with the message `"Selesaikan atau batalkan proses memasak dahulu sebelum istirahat."` Verified in `test_interlock_world_resource_manager_can_sleep`.

3. **Interface Contract Conformance:**
   - Conforms to `PRD.md` FR12 and `PROJECT.md` interface specifications.
   - Conforms to `CONTENT.md` § 2 (items), § 3 (reservations), § 4 (cooking steps), § 11 (honest notifications & prompts), § 12 (persistence).
   - Conforms to `UI_UX.md` UI05 (kitchen modal) and `PROTOTYPE.md` § 4, § 5, § 6.2.

---

## 3. Caveats

- **Scope Boundary with COOK-002:** The cooking loop phase (heat stage selection: Low 0.5x, Med 1.0x, High stall; 30s cook timer; dish item creation `dish_sayur_bening`; and dish consumption `meal_used = true`) belongs to milestone COOK-002. In COOK-001, the flow cleanly stops at `READY_TO_HEAT` or safely cancels back to `IDLE`.
- **Godot Resource Warning at Exit:** The test runner produces standard engine cleanup notices (`WARNING: ObjectDB instances were leaked at exit / ERROR: 11 resources still in use at exit`) due to test-allocated resources freed during headless shutdown. This is standard behavior across all project test suites and does not affect test pass status or exit code 0.

---

## 4. Conclusion

**Verdict: APPROVE**

Milestone **COOK-001** has been fully, correctly, and securely implemented. The architecture fulfills all functional requirements and passes all adversarial challenge scenarios:
1. Autoload `KitchenManager` is registered and safe in Godot 4.7.
2. `KitchenUI` responsive layout and signal bindings work correctly.
3. Landmark `station_kitchen_home` interaction and HUD prompts are accurate.
4. `InputManager.ContextMode.KITCHEN` transitions seamlessly without action bleed-through.
5. Save snapshot envelope v1 persistence is robust.
6. All 1,386 assertions across 11 test suites pass with exit code 0.

---

## 5. Verification Method

To independently verify the implementation:

1. **Execute Headless Test Runner:**
   Run the following command from the project root:
   ```powershell
   & "C:\Users\HP\.local\bin\godot.exe" --headless --path . --script res://tests/test_runner.gd; exit $LASTEXITCODE
   ```

2. **Success Criteria:**
   - Process exits with code `0`.
   - Log reports:
     `Assertions Passed: 1386`
     `Assertions Failed: 0`
     `RESULT: ALL SUITES PASSED (Exit Code: 0)`
   - Suite 11 executes and passes all 26 test methods covering T10, T11, T12, T13, T40, sleep interlock, snapshot persistence, and UI/landmark wiring.

3. **Invalidation Conditions:**
   - Any assertion failure in `test_runner.gd`.
   - Loss or duplication of ingredients during reservation, spam clicking, or cancellation.
   - Raw ingredient leakage into `dish_output_slot`.
   - Ability to sleep in bed while kitchen preparation is active.
