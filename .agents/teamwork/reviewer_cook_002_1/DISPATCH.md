# Dispatch for reviewer_cook_002_1

## Objective
Lakukan evaluasi review kode independen untuk milestone `COOK-002`:
1. Periksa kebenaran implementasi logika backend di `scripts/cooking/kitchen_manager.gd` dan `scripts/world/world_resource_manager.gd`.
2. Validasi kesesuaian terhadap spesifikasi:
   - Kontrol Panas T41 (LOW 0.5x, MEDIUM 1.0x, HIGH 0.0x stall warning tanpa merusak bahan).
   - Timer 30 detik nominal.
   - Jeda Simulasi T42 saat panel ditutup/ESC.
   - Slot Output Tunggal T15, penolakan masakan baru saat terisi, dan proteksi tas penuh (T15).
   - Aksi Makan Hidangan T43 (`eat_dish`), pengurangan atomik dari tas, penetapan `meal_used = true`, umpan balik jujur tanpa hunger bar fiktif.
   - Pengecualian interlock tidur pada `OUTPUT_READY`.
   - Save snapshot envelope v1.
3. Jalankan pengujian headless Godot 4.7.2:
   `& "C:\Users\HP\.local\bin\godot.exe" --headless --path . --script res://tests/test_runner.gd`
   dan verifikasi seluruh 13 test suite lulus 100%.

## Mandatory Reading
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen7\PROJECT.md`
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_cook_002\handoff.md`

## Output Requirements
Tulis laporan review lengkap di `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\reviewer_cook_002_1\handoff.md` dengan verdict eksplisit: **APPROVE** atau **REQUEST_CHANGES**. Kirim ringkasan via `send_message`.

## 2026-10-28T15:55:48Z
Kamu bertugas sebagai reviewer_cook_002_1 (Code Reviewer) untuk milestone COOK-002 pada proyek Buku Resep 2045.

Working directory kamu: c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\reviewer_cook_002_1\

BACA TERLEBIH DAHULU:
1. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md
2. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen7\PROJECT.md
3. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\reviewer_cook_002_1\DISPATCH.md
4. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_cook_002\handoff.md
5. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\scripts\cooking\kitchen_manager.gd
6. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\scripts\world\world_resource_manager.gd

TUGAS:
Lakukan evaluasi kode backend secara menyeluruh terhadap implementasi COOK-002:
- Kontrol panas LOW (0.5x), MEDIUM (1.0x), HIGH (0.0x stall warning tanpa merusak bahan).
- Timer 30 detik nominal.
- Jeda simulasi saat tutup panel dapur.
- Slot output tunggal dan proteksi tas penuh (T15).
- Aksi makan hidangan (eat_dish) dari tas dan status meal_used = true.
- Pengecualian interlock tidur pada OUTPUT_READY.
- Jalankan & verifikasi test runner headless:
  & "C:\Users\HP\.local\bin\godot.exe" --headless --path . --script res://tests/test_runner.gd

OUTPUT:
Tulis laporan lengkap di c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\reviewer_cook_002_1\handoff.md
Sertakan VERDICT eksplisit: APPROVE atau REQUEST_CHANGES.
Kirim ringkasan via send_message ke Orchestrator.
