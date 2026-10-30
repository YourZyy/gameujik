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
- [PLAN-001 — Perencanaan upgrade visual, dunia chunk streaming, NPC bergerak dan goal 3 resep](completed_tasks/019-perencanaan-upgrade-kampung-hidup.md).
- [REPO-001 — Artefak agen lokal dikeluarkan dari indeks Git tanpa menulis ulang riwayat](completed_tasks/021-repo-001-bersihkan-indeks-git.md).
- [TEST-001 — 19 skrip stres dipindah ke tests/tools dan tests/README ditambahkan (runner belum dijalankan)](completed_tasks/022-test-001-rapikan-skrip-tests.md).
- [ASSET-001 — Kebijakan, log dan struktur aset; jalur aktif generator kode](completed_tasks/023-asset-001-kebijakan-log-aset.md).

## Deskripsi Status Pekerjaan Terakhir

**Pembaruan:** 30 Oktober 2026. **Status:** DIJEDA atas permintaan pengguna. **Task selesai terakhir:** ASSET-001 (laporan 023). **Task berjalan:** SCOPE-001 (DIKERJAKAN); DEMO-001 (DIKERJAKAN, menunggu pengguna).

Gelombang 1 rencana induk ([plans/00](plans/00-rencana-induk.md)) selesai sebagian. REPO-001, TEST-001 dan ASSET-001 selesai dan sudah di remote. TEST-001 hanya memindahkan skrip; runner belum dijalankan (Godot tidak ada di sesi cloud), jadi 26 suite/8.854 asersi harus dicek ulang di Windows. ASSET-001 menetapkan generator kode sebagai jalur aktif: klaim CC0 repo Kenney baru tingkat README dan tidak cocok untuk dunia Indonesia.

SCOPE-001 dihentikan di tengah jalan. Belum di-commit sebagai selesai: sembilan dokumen sudah diubah ke v0.3 (PRD D26–D32, README, CONTENT bagian 15–20, LEVEL_DESIGN, ART_DIRECTION, PROTOTYPE, TEST_PLAN, UI_UX, EVENT_DESIGN). Belum dikerjakan: CONSISTENCY_CHECK (bagian audit v0.3), pemeriksaan silang ID/T-nomor/tautan lintas berkas, dan laporan 020. Isi dokumen yang diubah belum ditinjau koordinator maupun pemilik.

Langkah berikutnya: lanjutkan SCOPE-001 (periksa konsistensi, tulis laporan 020), lalu gelombang 2: FIX-001, VIS-001, WORLD-002, GOAL-001a. Tidak ada kode game yang berubah. DIST-001 belum dimulai.
