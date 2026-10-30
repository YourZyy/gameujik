# Folder tests/

Berisi pustaka asersi, runner utama, 26 suite, dan skrip mandiri (alat) untuk stres/adversarial.
Perintah di bawah adalah **contoh yang belum diverifikasi** pada sesi penataan (TEST-001); Godot tidak terpasang di lingkungan itu. Rujukan resmi cara menjalankan ada di [README proyek](../README.md) dan [TEST_PLAN](../docs/TEST_PLAN.md).

## Struktur

| Path | Isi |
| --- | --- |
| `assertions.gd` | Pustaka asersi bersama (`class_name Assertions`). |
| `test_runner.gd` | Runner utama; memuat semua suite di `tests/suites/` lewat `preload`. |
| `suites/` | Suite bernomor yang dijalankan runner (acuan hitungan: 26 suite, 8.854 asersi, 0 gagal menurut laporan 018). |
| `tools/` | Skrip mandiri (`extends SceneTree`), **tidak** dimuat runner. Hasil tidak dihitung dalam 8.854 asersi. |

## Menjalankan runner utama (contoh, belum diverifikasi di sesi ini)

```
godot --headless --script res://tests/test_runner.gd
godot_console --headless --script res://tests/test_runner.gd
```

Kode keluar 0 bila semua lulus, 1 bila ada kegagalan (per skrip runner).

## Menjalankan skrip tools (contoh, belum diverifikasi)

```
godot --headless --script res://tests/tools/<nama_skrip>.gd
```

Setiap skrip memanggil `quit(0)` atau `quit(1)` sendiri. Beberapa menulis berkas `.log` ke root proyek (`*.log` diabaikan Git).

## Daftar skrip di tools/

| Skrip | Tujuan | Catatan |
| --- | --- | --- |
| `adversarial_art_001_stress.gd` | Stres audio/ART-001 (konkurensi, limiter, memori) | Loop `_process`; mandiri penuh |
| `adversarial_art_oracle.gd` | Pembungkus suite 25 (`test_adversarial_art.gd`) | Duplikat suite; usulan hapus |
| `adversarial_cook_001_stress.gd` | Stres COOK-001: progres tahan, retensi, reservasi | Menulis `adversarial_cook_001_stress.log` |
| `adversarial_inv_reviewer_stress.gd` | Stres INV-001 (invarian, korupsi, atomisitas) | Mandiri |
| `adversarial_inventory_challenge.gd` | Tantangan INV-001 (batas integritas, UI) | Tumpang tindih dengan atas; usulan gabung |
| `adversarial_level_challenge.gd` | Tantangan LVL-001 (graybox) | Tumpang tindih `test_adversarial_level.gd` |
| `adversarial_qa_oracle.gd` | Oracle QA-001: invarian dan anti-softlock | Memakai autoload; mandiri |
| `adversarial_world_001_stress.gd` | Stres WORLD-001 (tantangan 1) | Tumpang tindih `stress_world_invariants.gd` |
| `challenger_art_002_2_harness.gd` | Harness kompleksitas/seni ART-001 | `class_name ChallengerArt002Harness` |
| `challenger_lvl_001_runner.gd` | Pembungkus suite `test_adversarial_level.gd` | Duplikat suite; usulan hapus |
| `challenger_ply_001_runner.gd` | Stres PLY-001 (kapsul, spawn, teleport) | Mandiri |
| `challenger_qa_001_idempotency_memory_stress.gd` | Idempotensi, kebocoran memori, node yatim QA-001 | Mandiri |
| `edge_camera_geometry_stress.gd` | Geometri crop kamera pada pose ekstrem | Mandiri |
| `empirical_art_challenger.gd` | Stres ART-001 dan oracle geometri | Tumpang tindih `challenger_art_002_2_harness.gd` |
| `empirical_performance_challenger.gd` | Anggaran adegan dan stabilitas | Mandiri |
| `run_adversarial_cooking.gd` | Pembungkus suite `test_adversarial_cooking.gd` | Duplikat suite; usulan hapus |
| `stress_garden_invariants.gd` | Stres GARD-001 (invarian kebun) | Mandiri |
| `stress_hold_actions.gd` | Stres kendali aksi tahan GARD-001 (T06, T07, T32, T33) | Mandiri |
| `stress_world_invariants.gd` | Stres WORLD-001 (invarian dunia) | Mandiri |

Keputusan hapus/gabung memerlukan persetujuan pemilik proyek; tidak ada skrip yang dihapus di sini.
