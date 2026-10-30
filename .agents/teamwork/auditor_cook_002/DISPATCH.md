# Dispatch for auditor_cook_002

## Objective
Lakukan Forensic Integrity Audit independen terhadap implementasi milestone `COOK-002`:
1. Verifikasi Integritas Kode Sumber:
   - Pastikan implementasi kontrol panas, timer 30 detik, pause/resume, output slot, dan aksi makan di `scripts/cooking/kitchen_manager.gd`, `scripts/ui/kitchen_ui.gd`, `scripts/ui/inventory_ui.gd`, dan `scripts/world/world_resource_manager.gd` adalah IMPLEMENTASI ASLI (GENUINE).
   - Pastikan TIDAK ADA kecurangan (cheating), dummy/facade implementations, stub kosong, hardcoded boolean return khusus untuk test runner, atau pemalsuan hasil pengujian.
   - Pastikan `tests/suites/test_cooking_heat.gd` menguji perilaku nyata dan tidak menggunakan assertion tiruan yang selalu pass (e.g. `assert_true(true)`).
2. Verifikasi Kepatuhan Batasan Produk & Game Rules:
   - Pastikan tidak ada hunger bar, hunger meter, currency, buff stat fiktif, combat, atau telemetri yang ditambahkan diam-diam (melanggar AGENTS.md § 4 & PRD).
3. Jalankan pengujian headless:
   `& "C:\Users\HP\.local\bin\godot.exe" --headless --path . --script res://tests/test_runner.gd`
   Verifikasi 1.885 asersi benar-benar dieksekusi dan lulus tanpa masking error.

## Mandatory Reading
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen7\PROJECT.md`
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\AGENTS.md`
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_cook_002\handoff.md`

## Output Requirements
Tulis laporan audit forensik lengkap di `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\auditor_cook_002\handoff.md` dengan verdict eksplisit: **CLEAN** atau **INTEGRITY VIOLATION**. Kirim ringkasan via `send_message`.
