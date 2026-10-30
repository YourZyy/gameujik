# Laporan Task Selesai: TEST-001 — Rapikan Skrip Stres/Adversarial di tests/

## Identitas

- **ID task:** TEST-001
- **Judul:** Rapikan 19 skrip stres/adversarial di root `tests/`
- **Tanggal selesai:** 30 Oktober 2026
- **Agent/pelaksana:** subagent Claude Code (koordinator mengurus commit dan pencatatan TASKS/PROJECT_STATUS)
- **Tahap produk:** Pemeliharaan pengujian (sebelum P0.5)
- **Status:** Selesai untuk penataan dan konsistensi path (diperiksa statis). **Runner TIDAK dijalankan**; verifikasi di Windows oleh pengguna masih diperlukan.
- **Versi sumber/build:** Working tree lokal, belum di-commit pada saat laporan ini; Godot tidak terpasang di lingkungan.

## Tujuan dan pemicu

Rencana [04 §3](../plans/04-dampak-dokumen-task-uji-risiko.md) (TEST-001) menugaskan perapian 19 skrip di root `tests/` selain `assertions.gd` dan `test_runner.gd`, tanpa menghapus dan tanpa mengurangi asersi.

## Ruang lingkup

Inventarisasi, pemindahan ke `tests/tools/`, pembaruan rujukan path, `tests/README.md`. Tidak ada penghapusan, penggabungan, maupun perubahan logika asersi. `test_runner.gd` tidak diubah.

## Perubahan dan perilaku akhir

Inventarisasi (hasil baca kode dan grep): seluruh 19 skrip `extends SceneTree` (dapat berjalan mandiri via `--script`), **tidak satu pun** dirujuk `test_runner.gd`, suite mana pun, kode, scene, atau dokumen kerja non-arsip. Runner hanya memuat `assertions.gd` dan berkas di `tests/suites/`. Tiga skrip hanyalah pembungkus suite yang sudah ada di runner (`adversarial_art_oracle`, `challenger_lvl_001_runner`, `run_adversarial_cooking`). Tidak ada `.uid` pendamping untuk 19 skrip itu (hanya `assertions.gd.uid` dan `test_runner.gd.uid`, tetap di tempat).

Seluruh 19 dipindah dengan `mv` ke `tests/tools/` (daftar dan tujuan: [tests/README.md](../../tests/README.md)). Rujukan yang disesuaikan (hanya string/komentar, bukan asersi):

| Berkas | Perubahan |
| --- | --- |
| `tests/tools/adversarial_level_challenge.gd` | Komentar perintah: `res://tests/` menjadi `res://tests/tools/` |
| `tests/tools/adversarial_qa_oracle.gd` | Komentar baris 1 menjadi `tests/tools/...` |
| `tests/tools/adversarial_cook_001_stress.gd` | String baris log `Harness:` menjadi `tests/tools/...` |

Rujukan lama di `.agents/`, `agents/` dan `docs/completed_tasks/001–019` (arsip riwayat) sengaja **tidak diubah** agar bukti lama tidak ditulis ulang; rujukan itu kini menunjuk path historis. `docs/plans/01-dunia-chunk-streaming.md` hanya cocok pada kata "stress", bukan path.

### Usulan hapus/gabung (perlu persetujuan pemilik; tidak dilaksanakan)

- Usulan hapus (pembungkus tipis, duplikat suite di runner): `adversarial_art_oracle.gd`, `challenger_lvl_001_runner.gd`, `run_adversarial_cooking.gd`. Catatan: ketiganya memberi titik masuk mandiri per suite; hapus hanya bila itu tidak dibutuhkan.
- Usulan gabung/periksa tumpang tindih (belum dibandingkan asersi demi asersi): `adversarial_inventory_challenge.gd` + `adversarial_inv_reviewer_stress.gd` (INV-001); `adversarial_world_001_stress.gd` + `stress_world_invariants.gd` (WORLD-001); `empirical_art_challenger.gd` + `challenger_art_002_2_harness.gd` (ART-001); `adversarial_level_challenge.gd` vs `tests/suites/test_adversarial_level.gd`.

## File yang ditambahkan atau diubah

| Path | Jenis | Tujuan |
| --- | --- | --- |
| `tests/tools/*.gd` (19 berkas) | Dipindah (`mv`) | Skrip mandiri |
| `tests/README.md` | Baru | Cara menjalankan dan daftar skrip |
| 3 berkas pada tabel di atas | Diubah (string/komentar) | Path baru |
| `docs/completed_tasks/022-test-001-rapikan-skrip-tests.md` | Baru | Laporan ini |

`TASKS.md`, `PROJECT_STATUS.md`, `scripts/`, `project.godot`, `.gitignore`, PRD tidak disentuh.

## Verifikasi yang benar-benar dilakukan

| ID | Tindakan | Hasil | Status |
| --- | --- | --- | --- |
| V1 | `grep` nama 19 skrip di luar `.agents`, `completed_tasks` | Hanya 3 string diri sendiri (sudah diperbarui) dan 1 kecocokan kata tak terkait | Lulus (statis) |
| V2 | `grep res://tests/<nama>.gd` pada `test_runner.gd`, `tests/tools`, `scripts`, `scenes`, `project.godot`, `docs/*.md`, README | Tidak ada rujukan ke path lama selain `assertions.gd`/`test_runner.gd` yang tetap | Lulus (statis) |
| V3 | `test_runner.gd` memuat skrip yang dipindah | 0 rujukan `tests/tools`; semua preload ke `suites/` dan `assertions.gd` | Lulus (statis) |
| V4 | Hitung berkas | 19 di `tests/tools/`; root hanya `assertions.gd`, `test_runner.gd`, `.uid`, `suites/`, `tools/`, `README.md` | Lulus |
| V5 | Menjalankan `test_runner.gd` / skrip tools | **TIDAK DIJALANKAN** (Godot tidak terpasang) | Belum dijalankan |

## Kriteria selesai

- Path konsisten, tidak ada rujukan patah: terpenuhi secara statis (V1–V3).
- Daftar pindah/gabung/hapus dengan hapus menunggu persetujuan: terpenuhi.
- "Runner tetap lulus, asersi tidak berkurang": **belum terbukti**; tidak ada asersi diubah dan runner tidak berubah, sehingga hasilnya diharapkan sama, tetapi belum dijalankan.

## Dampak, kompatibilitas dan keterbatasan

Runner tidak memuat skrip yang dipindah, jadi jumlah asersi runner secara struktural tidak berubah. Skrip tools menulis `.log` ke root proyek seperti sebelumnya. Mungkin ada cache `global_script_class_cache.cfg` yang perlu diperbarui Godot saat impor (`class_name` pada `adversarial_art_oracle.gd` dan `challenger_art_002_2_harness.gd` tetap sama); belum diverifikasi.

## Tindak lanjut dan handoff

Pengguna di Windows: jalankan `godot_console --headless --script res://tests/test_runner.gd` dan pastikan 26 suite, 8.854 asersi, 0 gagal (acuan [laporan 018](018-playthrough-penerimaan-p0-gameplay-regresi-akhir.md)); opsional jalankan satu-dua skrip tools untuk memastikan path baru dapat dimuat. Keputusan hapus/gabung menunggu pemilik. Task berikutnya per rencana 04: SCOPE-001, REPO-001, ASSET-001 (gelombang pertama).

## Penutupan catatan

Penautan dari PROJECT_STATUS dan penandaan TASKS dilakukan koordinator (di luar kepemilikan berkas subagen ini).
