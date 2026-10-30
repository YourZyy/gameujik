# DISPATCH — worker_gard_001_r2: Remediasi DEFECT-GARD-01 & Integrasi Tes Regresi GARD-001

## 2026-10-27T18:50:00Z

### 1. Peran & Identitas
- **Archetype**: `teamwork_worker`
- **Role**: Gardening Remediation Worker (GARD-001 Iteration 2)
- **Working Directory**: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_gard_001_r2\`
- **Parent**: `orchestrator_gen4` (`bc3795f9-23c4-4352-8a9c-4322971bcc61`)

### 2. Dokumen Sumber Wajib Dibaca
1. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md` (Wajib dibaca secara utuh sebelum mulai)
2. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_gard_001_r2_1\handoff.md` (Analisis root cause & opsi perbaikan)
3. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_gard_001_r2_3\handoff.md` (Laporan verifikasi harness & desain regresi)
4. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_gard_001_r2_3\defect_gard_01.patch` (Patch siap terap)
5. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\docs\completed_tasks\009-persiapan-petak-benih-perawatan-kebun.md` (Dokumen laporan task aktif)
6. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\AGENTS.md` (Aturan kerja, § 4, § 6, § 7)

### 3. MANDATORY INTEGRITY WARNING
> DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

### 4. Instruksi Tugas Konkret
1. **Terapkan Remediasi DEFECT-GARD-01 pada `scripts/player/player_controller.gd`**:
   - Tambahkan invariant compatibility guard di awal fungsi `_update_hold_action()` (tepat sebelum percabangan `if target_id == "landmark_water":`):
     ```gdscript
     # Invariant guard: Cancel active hold immediately if target landmark or active tool is no longer compatible
     if hold_controller.is_holding():
         var is_compat := false
         if hold_controller.action_id == "refill":
             is_compat = (target_id == "landmark_water")
         elif target_id == "landmark_plot":
             match hold_controller.action_id:
                 "hoe": is_compat = (active_tool == "tool_hoe")
                 "fertilize": is_compat = (active_tool == "tool_fertilizer")
                 "water": is_compat = (active_tool == "tool_watering_can")
         if not is_compat:
             hold_controller.cancel()
     ```
2. **Tambahkan Tes Regresi ke `tests/suites/test_gardening.gd`**:
   - Tambahkan fungsi pengujian regresi `test_regression_defect_gard_01_retargeting_hold_cancel(tree: SceneTree) -> bool` yang memverifikasi:
     - Retargeting langsung `plot_home_01` (sedang hold cangkul) ke `water_home` langsung memicu `cancel()` dan mereset progress ke 0.
     - Retargeting langsung `water_home` (sedang hold isi air) ke `plot_home_01` langsung memicu `cancel()`.
     - Mutasi tool eksternal saat sedang hold di `plot_home_01` langsung memicu `cancel()`.
     - Retargeting ke area kosong / null langsung memicu `cancel()`.
   - Sambungkan pemanggilan fungsi ini pada method `run_all()` di `tests/suites/test_gardening.gd`.
3. **Eksekusi Verifikasi Mandiri & Pastikan 100% Lulus**:
   - `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/stress_hold_actions.gd"` (1,679 asersi WAJIB LULUS dengan Exit Code 0, 0 error).
   - `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/stress_garden_invariants.gd"` (340 asersi WAJIB LULUS dengan Exit Code 0).
   - `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"` (947+ asersi WAJIB LULUS di seluruh 9 suite dengan Exit Code 0).
   - `python ".agents/skills/godot-nodes-scenes/scripts/check_godot_project.py" .` (0 error, 0 warning pada seluruh 56 file proyek).
   - Headless smoke run: `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless --quit-after 60 scenes/main.tscn"` (Exit Code 0).
4. **Dokumentasi & Pelaporan Wajib (AGENTS.md § 6 & § 7)**:
   - Perbarui `docs/completed_tasks/009-persiapan-petak-benih-perawatan-kebun.md` dengan menyertakan detail remedi `DEFECT-GARD-01`, hasil uji `tests/stress_hold_actions.gd` (1,679 lulus) dan tes regresi baru pada Suite 9.
   - Perbarui `docs/PROJECT_STATUS.md` (deskripsi status terkini 150–300 kata, tautan bullet laporan 009).
   - Perbarui `docs/TASKS.md` (pastikan GARD-001 terhubung ke laporan 009).
5. **Output**:
   - Tulis `handoff.md` di `.agents/teamwork/worker_gard_001_r2/handoff.md` berisi 5 komponen standar (Observation, Logic Chain, Caveats, Conclusion, Verification Method) dan kirimkan notifikasi penyelesaian via `send_message`.
