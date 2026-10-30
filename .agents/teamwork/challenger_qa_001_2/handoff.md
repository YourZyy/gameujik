# Empirical Challenger Report: Idempotency, Memory Stability & Orphan Node Prevention (QA-001)

**Verdict**: **APPROVE**  
**Role**: challenger_qa_001_2 (Idempotency & Memory Leak Challenger)  
**Milestone**: QA-001 (End-to-End P0 Acceptance Playthrough & Final QA Regression)  
**Date**: 2026-10-30  

---

## 1. Observation

### 1.1 Master Test Runner Execution (`tests/test_runner.gd`)
- **Command**:
  ```powershell
  & "C:\Users\HP\.local\bin\godot_console.exe" --headless --script tests/test_runner.gd
  ```
- **Exit Code**: `0`
- **Results**:
  - All 26 suites executed without errors.
  - Assertions Passed: `8,854`
  - Assertions Failed: `0`
  - Suite 26 (`test_qa_playthrough.gd`): Verified QA-01, QA-02, QA-03, QA-04, QA-05, and QA-06.

### 1.2 Dedicated Empirical Stress Harness (`tests/challenger_qa_001_idempotency_memory_stress.gd`)
- **Command**:
  ```powershell
  & "C:\Users\HP\.local\bin\godot_console.exe" --headless --script tests/challenger_qa_001_idempotency_memory_stress.gd
  ```
- **Exit Code**: `0`
- **Total Assertions**: `105` evaluated, `105` passed, `0` failed.
- **Baseline Engine Metrics (Pre-Stress)**:
  - Static Memory: `28.08 MB` (`29,448,461` bytes)
  - Total Objects: `1,616`
  - Total Active Nodes: `21`
  - Orphan Nodes: `0`
  - Loaded Resources: `26`
  - SceneTree Root: Exactly 9 authorized Autoload singletons (`InputManager`, `InventoryManager`, `RecipeManager`, `GardenManager`, `WorldResourceManager`, `KitchenManager`, `DialogueManager`, `SaveManager`, `AudioManager`).

### 1.3 Multi-Run Idempotency & Memory Profiling (5 Sequential Full Scenario A Runs)
Scenario A (complete P0 gameplay loop: spawn -> recipe book -> starter crate -> hoe -> compost -> plant 4 spots -> water/fertilize -> 4 growth stages -> harvest 4 bayam + 4 seeds -> wild corn -> wild temu kunci -> water refill -> kitchen reservation -> 4s prep -> 30s cook -> pause/resume -> claim dish -> neighbor dialogue -> share meal -> P0 experience closure) was executed 5 times sequentially in the same engine process:

| Run | Status | Static Memory | Total Objects | Orphan Nodes | Invariant Balance Verified |
| :---: | :---: | :---: | :---: | :---: | :---: |
| Run 1 | PASS | 47.52 MB | 1,687 | 0 | Yes (1 bayam, 4 seeds, 0 dish) |
| Run 2 | PASS | 47.56 MB | 1,696 | 0 | Yes (1 bayam, 4 seeds, 0 dish) |
| Run 3 | PASS | 47.59 MB | 1,696 | 0 | Yes (1 bayam, 4 seeds, 0 dish) |
| Run 4 | PASS | 47.59 MB | 1,696 | 0 | Yes (1 bayam, 4 seeds, 0 dish) |
| Run 5 | PASS | 47.57 MB | 1,689 | 0 | Yes (1 bayam, 4 seeds, 0 dish) |

- **Multi-Run Drift Analysis (Run 1 -> Run 5)**:
  - Memory Delta: `+0.048 MB` (within budget `< 2.0 MB`)
  - Object Delta: `+2 objects`
  - Orphan Node Delta: `+0 orphans` (strictly `0` orphan nodes across all 5 runs)

### 1.4 Dynamic Instance Teardown Stress
1. **CropMesh Primitives Rebuild Stress (50 consecutive stage rebuilds)**:
   - Evaluated rapid transitions across Stage 0 (2 primitives) -> Stage 1 (3 primitives) -> Stage 2 (7 primitives) -> Stage 3 (10 primitives) -> unoccupied.
   - Pre-Stress Orphans: `0`, Post-Stress Orphans: `0` (Delta: `+0`).
   - All intermediate `MeshInstance3D` children detached and freed via `queue_free()`.
2. **Notification Toast Flood (100 rapid mixed notifications & pickups)**:
   - NotificationManager strictly enforced `MAX_VISIBLE_TOASTS = 2`.
   - Advanced time and cleared queue.
   - Pre-Stress Orphans: `0`, Post-Stress Orphans: `0` (Delta: `+0`).
3. **Kitchen Reservation & Cancellation Cycles (30 rapid cycles)**:
   - 30 cycles of reserving 3 bayam, 1 corn, 1 temu kunci -> advancing prep -> calling `cancel_preparation()`.
   - Result: `JobState.IDLE` restored, `active_job_id` cleared, `reserved_ingredients` emptied, and `InventoryManager._reservations` completely cleared.
   - Pre-Stress Orphans: `0`, Post-Stress Orphans: `0` (Delta: `+0`).

### 1.5 Multi-Roundtrip Checkpoint Save/Load Stability (Scenario B x 3)
- Executed 3 sequential cycles of saving mid-game state (active cooking at 18.0s, growing crops at 60s, harvested foraging nodes), resetting state, and reloading save checkpoint.
- Pre-Test Memory: `47.58 MB`, Post-Test Memory: `47.73 MB` (Delta: `+0.147 MB`, well within `< 3.0 MB` limit).
- Pre-Test Orphans: `0`, Post-Test Orphans: `0` (Delta: `+0`).

### 1.6 Global Root Cleanliness Audit
- After full stress execution and `_reset_all_managers()`, the SceneTree root was inspected.
- Surviving nodes: Exactly 9 nodes, corresponding 100% to the authorized Autoload singletons.
- Zero dangling temporary scenes, orphan canvas layers, or abandoned modal dialogs.

---

## 2. Logic Chain

1. **Idempotency Proof**: Multi-run idempotency requires that running playthrough iteration $N$ does not leave leftover state or side effects that alter the behavior or outcome of iteration $N+1$. By executing Playthrough Scenario A five consecutive times in a single process, we verified that every single run passed 100% of its step assertions, adhered to the exact closed-system matter conservation law (1 bayam, 4 seeds, 0 dish remaining), and triggered clean P0 closure.
2. **Memory Leak Non-Existence**: If dynamic nodes or resources leaked, memory would increase monotonically with each playthrough. The measured memory profile across Runs 1–5 was: 47.52 MB -> 47.56 MB -> 47.59 MB -> 47.59 MB -> 47.57 MB. The net change between Run 1 and Run 5 was only +0.048 MB (+49 KB), demonstrating that after the initial asset and shader compilation warm-up in Run 1, memory plateaued with zero runaway leak.
3. **Orphan Node Elimination**: An orphan node in Godot is an unreferenced Node that is not in the SceneTree and has not been freed, which can cause memory leaks and phantom signal connections. Across all stress dimensions (CropMesh rebuilds, notification toasts, kitchen cancellations, and full scene instantiations/teardowns), `Performance.OBJECT_ORPHAN_NODE_COUNT` remained strictly `0`.
4. **Hermetic State Resetting**: The test harness properly resets all singletons (`_reset_all_managers()`) and tears down the main scene (`_free_test_main()`), proving that the game architecture is fully decoupled, capable of restarting sessions cleanly without requiring an engine process reboot.

---

## 3. Caveats

- **Headless Execution**: Verification was conducted in headless mode on Godot 4.7.2 (`--headless`), which profiles CPU memory (`MEMORY_STATIC`), ObjectDB references (`OBJECT_COUNT`), and node lifecycles (`OBJECT_ORPHAN_NODE_COUNT`). Dedicated GPU VRAM allocations for textures and framebuffers are driver-managed and not exercised in headless CLI mode.
- **Single Threaded Autoloads**: All autoload singletons run on the main SceneTree thread, which is standard for Godot 4 games and guarantees deterministic order of execution.

---

## 4. Conclusion

The implementation of `QA-001` (End-to-End P0 Acceptance Playthrough & Final QA Regression) exhibits **exemplary idempotency, rock-solid memory stability, and zero orphan node leakage**.

- Multi-run playthrough idempotency (`QA-06`) is verified across 5 sequential iterations with zero cross-session contamination.
- Memory drift across sequential playthroughs is negligible (`+0.048 MB`).
- Dynamic instances (`CropMesh`, toast notifications, kitchen reservations, modal dialogs) are cleanly reclaimed with `0` orphan nodes.
- All 105 empirical stress assertions passed with 0 failures.

**VERDICT**: **APPROVE**.

---

## 5. Verification Method

To independently verify these findings, run the dedicated stress harness and master runner from PowerShell:

1. **Run the Idempotency & Memory Leak Stress Harness**:
   ```powershell
   & "C:\Users\HP\.local\bin\godot_console.exe" --headless --script tests/challenger_qa_001_idempotency_memory_stress.gd
   ```
   *Expected Output*:
   - Evaluates all 5 stress sections.
   - Prints: `Total Assertions Evaluated: 105`, `Total Assertions Failed: 0`.
   - Prints: `>>> EMPIRICAL STRESS RESULT: ALL TESTS PASSED [APPROVE] <<<` (Exit Code: 0).

2. **Run Master Test Runner**:
   ```powershell
   & "C:\Users\HP\.local\bin\godot_console.exe" --headless --script tests/test_runner.gd
   ```
   *Expected Output*:
   - All 26 suites pass.
   - `Assertions Passed: 8854`, `Assertions Failed: 0` (Exit Code: 0).
