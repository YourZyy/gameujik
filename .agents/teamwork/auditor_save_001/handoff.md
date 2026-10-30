# Forensic Audit Report: SAVE-001 (Save/Load Persistence, Envelope v1, Atomic File Writes, Checkpoints, and Recovery)

**Work Product**: Milestone SAVE-001 (`scripts/save/save_manager.gd`, `tests/suites/test_save.gd`, snapshot implementations in all managers and player controller, `docs/completed_tasks/015-persistensi-lengkap-save-load-slot-backup.md`)  
**Profile**: General Project  
**Integrity Mode**: Development (from `ORIGINAL_REQUEST.md`)  
**Verdict**: **CLEAN**

---

### Phase Results
- **Hardcoded Test Results Check**: PASS — Zero hardcoded expected outcomes, dummy assertions, or fabricated return strings.
- **Facade Detection Check**: PASS — Substantial logic implemented; FileAccess, DirAccess, JSON canonical serialization, SHA-256 calculation, and ConfigFile operations are authentic.
- **Atomic File Writing Verification**: PASS — File writes utilize genuine `.tmp` creation, size verification, `.bak` rotation, and atomic rename swap.
- **Two-Phase Commit Verification**: PASS — Phase 1 dry-run validation validates required sections, stack limits (0..20), valid Item IDs, and coordinate bounds prior to mutating live singletons; live state remains untouched if validation fails.
- **Checksum Integrity Verification**: PASS — Canonical JSON serialization is hashed via `.sha256_text()` and verified upon envelope reading.
- **Error Recovery Authenticity**: PASS — Automatic fallback to `.bak` upon corruption with self-healing rewrite, clean failure on dual corruption, 0-byte file handling, out-of-bounds coordinate redirection to safe spawn (0, 0, 8), and cooking paused on load.
- **Pre-populated Artifact Detection**: PASS — Test logs reflect live runtime execution.
- **Headless Build and Test Execution**: PASS — Godot Engine v4.7.2 headless execution succeeded with 6,769 passed assertions, 0 failed, Exit Code 0.

---

## 1. Observation

1. **Autoload Registration (`project.godot:23`):**
   ```ini
   SaveManager="*res://scripts/save/save_manager.gd"
   ```
   `SaveManager` is properly registered as an active Autoload singleton.

2. **Atomic File Write Pipeline (`scripts/save/save_manager.gd:88-155`):**
   ```gdscript
   var target_path := get_slot_path(slot_type)
   var tmp_path := target_path + ".tmp"
   var bak_path := target_path + ".bak"
   ...
   var file := FileAccess.open(tmp_path, FileAccess.WRITE)
   ...
   file.store_string(json_str)
   file.flush()
   file.close()
   ...
   if FileAccess.file_exists(target_path):
       if FileAccess.file_exists(bak_path):
           DirAccess.remove_absolute(bak_path)
       var bak_err := DirAccess.rename_absolute(target_path, bak_path)
   ...
   var rename_err := DirAccess.rename_absolute(tmp_path, target_path)
   ```
   Writing writes to `.tmp`, verifies existence and non-zero byte size, rotates `target_path` to `.bak`, and renames `.tmp` to `target_path`.

3. **Canonical JSON and SHA-256 Checksum (`scripts/save/save_manager.gd:429-479`):**
   ```gdscript
   static func canonical_json(val: Variant) -> String:
   ...
   func create_envelope(slot_type: String, payload: Dictionary) -> Dictionary:
       var payload_str := canonical_json(payload)
       var hash_str := payload_str.sha256_text()
   ...
   # In read_and_validate_envelope:
   var expected_hash: String = str(envelope.get("checksum", envelope.get("header", {}).get("checksum", "")))
   if not expected_hash.is_empty():
       var actual_hash: String = canonical_json(payload).sha256_text()
       if actual_hash != expected_hash:
           return {"valid": false, "reason": "CHECKSUM_MISMATCH"}
   ```
   Checksum calculations sort dictionary keys leksikografically, format numbers deterministically, and compute SHA-256 via Godot's built-in `.sha256_text()`.

4. **Two-Phase Commit Validation (`scripts/save/save_manager.gd:185-214`):**
   ```gdscript
   # Phase 1 Pre-Flight Dry-Run
   var payload: Dictionary = active_envelope.get("payload", {})
   var val_res := validate_save_payload(payload)
   if not val_res.get("valid", false):
       ... return {"success": false, "error": ERR_INVALID_DATA, "message": err_msg}
   # Phase 2 Atomic Application to Live Singletons
   apply_all_states(payload)
   ```
   `validate_save_payload` verifies required sections (`player`, `inventory`, `recipe`, `gardening`, `world`, `cooking`, `dialogue`), verifies inventory slot counts (12 slots), item registry existence via `ItemsDataClass`, stack counts (0..20), cooking state range, world day, and player coordinates.

5. **Coordinate Sanitization and Safe Spawn Redirection (`scripts/player/player_controller.gd:505-549`):**
   ```gdscript
   if px >= -42.0 and px <= 42.0 and pz >= -37.0 and pz <= 47.0 and py >= -5.0 and py <= 50.0:
       target_pos = Vector3(px, py, pz)
       is_coord_valid = true
   if not is_coord_valid:
       target_pos = default_safe_return_position
   ```
   Redirection activates for NaN, Inf, or out-of-bounds coordinates, resetting position to pekarangan rumah (0.0, 0.0, 8.0).

6. **Separate Settings Isolation (`scripts/save/save_manager.gd:548-624`):**
   Settings are stored in `user://settings.cfg` via Godot's `ConfigFile`, separate from save JSON files. Loading a save or starting a new game does not touch user settings.

7. **Empirical Test Execution Output:**
   Command:
   ```powershell
   & "C:\Users\HP\.local\bin\godot_console.exe" --headless --path . --script res://tests/test_runner.gd
   ```
   Verbatim output:
   ```
   Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
   ...
   ==================================================
   [SUITE 19] TestSave: Persistensi Lengkap, Validasi Envelope & Error Recovery (SAVE-001)
   ==================================================
   ERROR: Parse JSON failed. Error at line 0: Expected 'true', 'false', or 'null', got 'unclosed'
      at: parse_string (core/io/json.cpp:629)
   [SaveManager] Checkpoint utama rusak/hilang (user://test_save_sandbox/save_manual.json: INVALID_JSON). Mencoba .bak...
   [PlayerController] Koordinat pemain out-of-bounds/NaN/Inf ([nan, 0.0, 8.0]). Dialihkan ke titik aman: (0.0, 0.0, 8.0)
   [PlayerController] Koordinat pemain out-of-bounds/NaN/Inf ([0.0, inf, 0.0]). Dialihkan ke titik aman: (0.0, 0.0, 8.0)
   [PlayerController] Koordinat pemain out-of-bounds/NaN/Inf ([0.0, -100.0, 0.0]). Dialihkan ke titik aman: (0.0, 0.0, 8.0)
   [PlayerController] Koordinat pemain out-of-bounds/NaN/Inf ([500.0, 0.0, 0.0]). Dialihkan ke titik aman: (0.0, 0.0, 8.0)
   ==================================================
   [TEST_RUNNER] SUMMARY:
     Assertions Passed: 6769
     Assertions Failed: 0
     RESULT: ALL SUITES PASSED (Exit Code: 0)
   ==================================================
   ```

---

## 2. Logic Chain

1. **Premise 1 (File Operations Authenticity)**:
   Observations 2 and 7 prove that save operations interact with real files on disk (`user://test_save_sandbox/`), executing atomic write flows via `.tmp`, `.bak`, and target `.json`. Simulated write failures in `test_t47_02` prove that existing saves remain unharmed during incomplete write attempts.
2. **Premise 2 (Cryptographic Integrity)**:
   Observation 3 confirms that envelope checksums are computed over canonical payload serialization using SHA-256 and verified during load. Corrupted files trigger `CHECKSUM_MISMATCH` or `INVALID_JSON` and fall back to valid backups.
3. **Premise 3 (State Invariance & Two-Phase Commit)**:
   Observations 4 and 7 demonstrate that invalid snapshots are rejected during Phase 1 pre-flight validation before mutating singleton memory. In `test_t16_03`, state before the failed load is proven to be identical to state after the failed load.
4. **Premise 4 (Resilience & Recovery)**:
   Observations 5 and 7 demonstrate that invalid/out-of-bounds player positions are automatically recovered to `Vector3(0, 0, 8)`. Corrupted primary files automatically trigger recovery from `.bak` and self-healing rewrites.
5. **Premise 5 (No Prohibited Patterns)**:
   No hardcoded test outcomes, dummy constants, or fake bypasses exist. The entire test suite executes against real game systems and asserts actual data properties.

---

## 3. Caveats

- Graphical UI dialogs (Pause Menu, slot picker buttons, settings sliders) are scheduled for milestone UI-001 as specified in `TASKS.md` and `PROJECT.md`. The backend API and headless test verification for all persistence contracts are complete.

---

## 4. Conclusion

The work product for **SAVE-001** is genuine, robust, and completely adheres to the architectural requirements and integrity constraints. All 25 test methods in Suite 19 execute authentically, and all 6,769 assertions in the full test runner pass with zero failures.

**VERDICT**: **CLEAN**

---

## 5. Verification Method

To independently reproduce this verification:
1. Open PowerShell in the workspace root:
   ```powershell
   & "C:\Users\HP\.local\bin\godot_console.exe" --headless --path . --script res://tests/test_runner.gd
   ```
2. Verify:
   - Exit code: 0
   - Assertions Passed: 6769
   - Assertions Failed: 0
   - Confirmation of Suite 19 execution with JSON corruption recovery logs and player coordinate sanitization logs.
