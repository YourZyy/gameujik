# Project Status

**Aturan wajib:** AI agent memperbarui file ini setiap selesai melakukan sebuah task, sekaligus membuat laporan terperinci dalam [completed_tasks](completed_tasks/README.md). Detail historis berada di arsip; deskripsi terakhir diganti, bukan terus ditambahkan. Task belum selesai hanya dicatat sebagai kemajuan terbaru, tidak dimasukkan ke daftar selesai. Aturan lengkap pada [AGENTS](../AGENTS.md).

## Pekerjaan yang Sudah Selesai

- [DOC-001 — Penyusunan paket dokumentasi v0.2 dan wireframe berdasarkan diskusi terbaru](completed_tasks/001-paket-dokumentasi-v0-2.md).
- [SETUP-001 — Inisialisasi proyek Godot, verifikasi engine, struktur direktori, dan test harness headless](completed_tasks/002-setup-proyek-godot.md).
- [LVL-001 — Graybox map, rumah, pekarangan, collision, spawn dan recovery](completed_tasks/003-graybox-map-rumah-spawn-recovery.md).
- [PLY-001 — Gerak dan pandang first person, batasan vertikal dan collision](completed_tasks/004-kendali-first-person-player.md).
- [REBUILD-001 — Audit dan refinement arsitektur SETUP-001, LVL-001, dan PLY-001 berbasis skill gamedev](completed_tasks/005-rebuild-refinement-skills-setup-lvl-ply.md).
- [INT-001 — Target interaksi objek, prompt, occlusion, dan pengontrol konteks input](completed_tasks/006-target-interaksi-prompt-konteks-input.md).
- [INV-001 — Data item dan inventaris tas & peti, transfer dua arah, dan paket awal](completed_tasks/007-data-item-inventaris-tas-peti-transfer.md).
- [BOOK-001 — Buku resep keluarga, pelacakan tracker HUD, registri catatan, dan stok bebas bersama](completed_tasks/008-buku-resep-tracker-hud-stok-bersama.md).
- [GARD-001 — Persiapan petak, benih dan perawatan area](completed_tasks/009-persiapan-petak-benih-perawatan-kebun.md).
- [GARD-002 — Pertumbuhan 4 tahap bayam dan pemanenan atomik](completed_tasks/010-pertumbuhan-bayam-4-tahap-pemanenan-atomik.md).
- [WORLD-001 — Sumber daya dunia, foraging liar, stasiun air, benih cadangan, kalender hari dan istirahat](completed_tasks/011-sumber-pemulihan-jagung-temu-kunci-air-cadangan-istirahat.md).
- [COOK-001 — Validasi bahan resep, reservasi atomik, aksi tahan persiapan 4s, pembatalan aman pra-masak dan wadah refund](completed_tasks/012-validasi-reservasi-persiapan-pembatalan-dapur.md).
- [COOK-002 — Kontrol panas, timer memasak 30s, jeda panel dapur, slot output tunggal, centang buku resep, dan aksi makan hidangan](completed_tasks/013-kontrol-panas-output-makan-hidangan.md).
- [SOC-001 — Interaksi sosial warga, dialog tetangga 7-node, berbagi hidangan, dan penutup P0](completed_tasks/014-interaksi-sosial-warga-dialog-berbagi-hidangan.md).
- [SAVE-001 — Checkpoint manual/auto, validasi envelope v1, backup fallback, atomic temp write, dan pemulihan posisi aman](completed_tasks/015-persistensi-lengkap-save-load-slot-backup.md).
- [UI-001 — Menu jeda, panel pengaturan, aksesibilitas fokus keyboard, dialog konfirmasi modal, dan sistem notifikasi toast jujur](completed_tasks/016-kenyamanan-terpadu-menu-pause-pengaturan-aksesibilitas.md).
- [ART-001 — Identitas visual dan audio dasar yang konsisten](completed_tasks/017-identitas-visual-audio-dasar-konsisten.md).
- [QA-001 — Playthrough penerimaan P0 gameplay dan verifikasi regresi akhir](completed_tasks/018-playthrough-penerimaan-p0-gameplay-regresi-akhir.md).

## Deskripsi Status Pekerjaan Terakhir

**Pembaruan:** 30 Oktober 2026. **Task terakhir:** DEMO-001 (DIKERJAKAN — demonstrasi playable P0). **Task selesai terakhir:** QA-001 (SELESAI — Playthrough penerimaan P0 gameplay dan verifikasi regresi akhir). Status milestone P0 tetap selesai; demonstrasi manual desktop belum ditutup.

Pada 30 Oktober 2026, executable Godot 4.7.2 berhasil membuka main scene GUI dan merender menu jeda serta dunia 3D rumah/pekarangan. Master runner (`tests/test_runner.gd`) juga dijalankan ulang dan mencatat 26 suite, 8.854 asersi lulus, 0 gagal, exit code 0; QA-02/03/04/05/06 mencakup loop resep, save/resume, konservasi item, modal input, dan idempotensi. Kontrol keyboard/mouse dari otomasi desktop eksternal tidak diterima oleh window pada sesi ini, sehingga gerak manual, interaksi target, dan penutupan P0 belum dapat diklaim sebagai playtest langsung. Proses uji juga melaporkan 5.026 ObjectDB instance dan 14 resource masih digunakan saat exit; ini belum dianalisis sebagai bug runtime.

DEMO-001 tetap dikerjakan untuk memperoleh bukti interaksi desktop yang dapat diulang tanpa injeksi input eksternal yang gagal. Setelah itu, periksa warning cleanup tersebut sebelum menyatakan demonstrasi selesai. DIST-001 tidak dimulai; ekspor mandiri belum diverifikasi.
