# Dispatch for challenger_cook_002_2

## Objective
Lakukan verifikasi adversarial dan stress testing mendalam untuk milestone `COOK-002`:
1. Uji Invarian Centang Buku Resep (T19):
   - Pastikan resep sama sekali TIDAK centang pada progres 0.0s s/d 29.99s.
   - Uji siklus masak ulang (remake cycle): masak resep ke-2 dan ke-3 kali, verifikasi counter `times_cooked` bertambah tepat, sinyal `recipe_completed` TIDAK dipancarkan ulang, dan tidak ada memory leak.
2. Uji Aksi Makan Hidangan (`eat_dish`):
   - Percobaan memakan saat tas tidak memiliki hidangan (harus gagal bersih).
   - Memakan saat tas memiliki hidangan (harus mengurangi tepat 1 unit, menyetel `meal_used = true`).
   - Panggilan berulang `eat_dish` setelah hidangan habis.
3. Uji Save/Load Roundtrip (Envelope v1):
   - Serialisasi state saat sedang memasak (mid-cook, misal progres 15s panas Sedang atau berstatus PAUSED), reload, dan verifikasi proses dapat dilanjutkan tanpa korupsi data.
4. Jalankan test runner headless:
   `& "C:\Users\HP\.local\bin\godot.exe" --headless --path . --script res://tests/test_runner.gd`

## Mandatory Reading
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen7\PROJECT.md`
- `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_cook_002\handoff.md`

## Output Requirements
Tulis laporan penantang di `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\challenger_cook_002_2\handoff.md` dengan verdict eksplisit: **APPROVE** atau **REQUEST_CHANGES**. Kirim ringkasan via `send_message`.


## 2026-10-28T15:56:28Z
Kamu bertugas sebagai challenger_cook_002_2 (Adversarial Challenger) untuk milestone COOK-002 pada proyek Buku Resep 2045.

Working directory kamu: c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\challenger_cook_002_2\

BACA TERLEBIH DAHULU:
1. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md
2. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen7\PROJECT.md
3. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\challenger_cook_002_2\DISPATCH.md
4. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_cook_002\handoff.md
5. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\scripts\recipe\recipe_manager.gd
6. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\scripts\cooking\kitchen_manager.gd

TUGAS:
Lakukan pengujian adversarial terhadap integritas siklus resep dan aksi makan:
- Uji invarian centang buku resep (T19): buktikan tidak ada centang prematur saat progres 0.0s s/d 29.99s.
- Uji siklus remake (masak ke-2 dan ke-3): times_cooked naik tepat, recipe_completed tidak terpancar ganda.
- Uji makan hidangan (eat_dish): makan saat tas kosong vs ada hidangan, pengurangan atomik 1 unit, meal_used = true, honest toast tanpa hunger bar.
- Uji save/load snapshot envelope v1 saat proses memasak berjalan (mid-cooking save & reload).
- Jalankan test runner headless:
  & "C:\Users\HP\.local\bin\godot.exe" --headless --path . --script res://tests/test_runner.gd

OUTPUT:
Tulis laporan penantang di c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\challenger_cook_002_2\handoff.md
Sertakan VERDICT eksplisit: APPROVE atau REQUEST_CHANGES.
Kirim ringkasan via send_message ke Orchestrator.
