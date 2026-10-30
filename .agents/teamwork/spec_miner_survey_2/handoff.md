# Handoff Report — Survey of Verification Specifications, Test Cases, and Compliance Rules

## 1. Observation
- **Direct Workspace Exploration**:
  - `docs/TEST_PLAN.md` (lines 1–168) explicitly defines 60 P0 test cases (`T01`–`T60`), 12 post-P0 Karhutla event cases (`EV-T01`–`EV-T12`), and 8 documentation audit cases (`DOC-T01`–`DOC-T08`). Line 8 notes: *"Semua tes gameplay, build, performa, instalasi dan event di bawah BELUM DIJALANKAN, karena kode game belum dibuat."*
  - `AGENTS.md` (lines 114–146) mandates Section 6 (*"Kewajiban pencatatan — setelah SETIAP task selesai"*): AI agents must create an individual detailed report in `docs/completed_tasks/` using `TEMPLATE.md` with incremental numbering starting from `002-` (since `001-paket-dokumentasi-v0-2.md` exists) and update `docs/PROJECT_STATUS.md` and `docs/TASKS.md`.
  - `AGENTS.md` Section 7 (lines 148–156) establishes strict status length limits: *"Status utama berisi daftar judul bertautan dan satu deskripsi terbaru, bukan riwayat percakapan, dump log atau diff. Target deskripsi terakhir 150–300 kata."*
  - `AGENTS.md` Section 8 (lines 158–179) dictates implementation architecture: Godot stable release, GDScript, desktop target, no extra plugins/add-ons without concrete need (*"Hindari plugin/add-on sebelum ada kebutuhan konkret"*), transaction atomicity, and single input context stack.
  - `docs/completed_tasks/README.md` (lines 9–11) explicitly states: *"Gunakan nama NNN-nama-task.md, nomor terbesar yang sudah ada ditambah satu. Nomor tiga digit minimum dan terus bertambah, tidak di-reset per milestone... Contoh nama untuk pekerjaan yang belum dilakukan: 002-setup-proyek-godot.md."*
  - `docs/completed_tasks/TEMPLATE.md` (lines 1–50) specifies 10 mandatory sections with no blanks allowed: Identitas, Tujuan dan pemicu, Ruang lingkup, Perubahan dan perilaku akhir, File yang ditambahkan atau diubah, Verifikasi yang benar-benar dilakukan, Kriteria selesai, Dampak kompatibilitas dan keterbatasan, Tindak lanjut dan handoff, Penutupan catatan.
  - `docs/TASKS.md` (lines 14–35, 38–147) details 19 core tasks (`DOC-001`, `SETUP-001` through `QA-001`, `DIST-001`, `DIST-002`) and 6 backlog event tasks (`EV-001` through `EV-QA-001`), linking acceptance criteria directly to `TEST_PLAN.md` test IDs.
  - `docs/CONTENT.md` (lines 12–25, 32–40, 110–126, 133–145) defines exact numerical thresholds (12 slots, 20 stack cap, 3 spinach, 1 corn, 1 temu kunci, 180s grow time, nutrient <20 needs fertilizer, moisture <60 can water, cost 2 water to reach 80, harvest yield 1 bayam + 1 seed, -5 soil nutrient).
  - `docs/PROTOTYPE.md` (lines 41–52, 55–69, 72–92, 94–105) establishes the state machines for the kitchen (`idle -> reserved/preparing -> ready_to_heat -> cooking <-> paused -> output_ready -> idle`), safe atomic file replacement (`.tmp` -> validation -> backup rotation -> final commit), and input context switching.

## 2. Logic Chain
1. **Verification Test Case Mapping**:
   - Starting from `docs/TEST_PLAN.md` and `docs/TASKS.md`, the 60 acceptance cases (`T01`–`T60`) form the basis of acceptance criteria across all P0 tasks.
   - To provide actionable implementation guidance, these cases naturally map into a 4-Tier test hierarchy:
     - **Tier 1 (Feature Coverage & Smoke)**: Direct unit checks of isolated functions (e.g., T01-T03 book tracker pin, T04 single pickup, T23 baseline engine setup).
     - **Tier 2 (Boundary & Concurrency)**: Capacity and threshold limits (e.g., 20 stack limit T29, watering cutoff at 60 moisture T07, cooking heat multiplier 0.0x T41, input de-bouncing T04/T12).
     - **Tier 3 (Cross-Feature Integration)**: Multi-subsystem interactions (e.g., inventory-kitchen multi-container reservation T11 and safe fallback refund T40; bed calendar day advance without leaping crop growth simulation T39; kitchen completion synchronizing with recipe book and neighbor sharing T43/T44; save/load round-trip state snapshot integrity T46).
     - **Tier 4 (Real-World & Playtest)**: End-to-end P0 loop playthrough (10–15 min clean profile), interrupted write/power-loss simulation (T22/T49), and standalone read-only desktop filesystem testing (T20/T57/T58).
2. **Test Harness & Runner Architecture**:
   - `AGENTS.md` mandates avoiding unnecessary external add-ons and strictly using GDScript in Godot stable for desktop.
   - Using a heavy external plugin like GUT adds overhead and potential compatibility risk. Conversely, a lightweight custom runner script executed via Godot CLI (`godot --headless --script res://tests/test_runner.gd`) satisfies all requirements: headless CLI execution, OS exit code (0 on pass, 1 on fail), discrete time-stepping (`tick()`) without wall-clock sleep delays, custom assertions, and modular fixtures.
3. **Compliance Requirements**:
   - `AGENTS.md` §6 & §7 and `docs/completed_tasks/README.md` establish that task completion requires three synchronized updates:
     1. Creating `docs/completed_tasks/NNN-nama-task.md` starting with `002-` following `TEMPLATE.md` completely.
     2. Appending one linked bullet to `docs/PROJECT_STATUS.md` under `## Pekerjaan yang Sudah Selesai` and replacing `## Deskripsi Status Pekerjaan Terakhir` with an accurate 150–300 word summary.
     3. Updating `docs/TASKS.md` status to `SELESAI` with a link to the report.
   - No task can be closed without executing real verification (anti-fabrication rule).
4. **Milestone & Gate Criteria**:
   - The milestone gates must enforce sequential execution (`SETUP-001` -> `LVL-001` -> `PLY-001` -> `INT-001` -> `INV-001` -> `BOOK-001` -> `GARD-001` -> `GARD-002` -> `WORLD-001` -> `COOK-001` -> `COOK-002` -> `SOC-001` -> `SAVE-001` -> `UI-001` -> `ART-001` -> `QA-001` -> `DIST-001` -> `DIST-002`).
   - `QA-001` represents the P0 Gameplay Gate; `DIST-002` represents the P0 Distribution Gate.

## 3. Caveats
- At the time of this survey, the Godot binary has not yet been executed in the active workspace and no game code has been written yet. All extracted numbers and thresholds represent the authoritative specifications (`DEFAULT UJI` from `CONTENT.md` and acceptance criteria from `TEST_PLAN.md`), ready to be instantiated as automated assertions upon engine setup.
- Event Karhutla specifications (`EV-001` through `EV-QA-001`, `EV-T01` through `EV-T12`) are formally designated as post-P0 backlog items; they must not be integrated into P0 code until P0 acceptance is complete.

## 4. Conclusion
- The verification landscape, full test suite mapping (Tiers 1–4), edge case inventory, Godot headless test runner architecture, AGENTS.md compliance protocols, and task gate criteria have been comprehensively extracted and documented in:
  `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\spec_miner_survey_2\test_survey_report.md`
- Next implementation agent (`SETUP-001`) has clear, unambiguous contracts and must register completion as `002-setup-proyek-godot.md`.

## 5. Verification Method
- **File Inspection**:
  - Inspect `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\spec_miner_survey_2\test_survey_report.md` (500 lines) to verify that all 25 features, 29 edge cases, 4 test tiers, Godot CLI architecture, AGENTS.md rules, and task gate criteria are fully articulated.
  - Inspect `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\spec_miner_survey_2\BRIEFING.md` and `progress.md` for situational tracking and liveness timestamps.
- **Cross-Reference Integrity**:
  - Verify test IDs against `docs/TEST_PLAN.md` (T01–T60 match exactly).
  - Verify completed task numbering against `docs/completed_tasks/` (001 is DOC-001; next is strictly 002).
  - Verify word count constraint (150–300 words) against `AGENTS.md` §7.
