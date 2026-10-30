# Rencana Induk — Upgrade "Kampung Hidup" (visual, dunia chunk, goal 3 resep)

**Status:** USULAN untuk persetujuan pemilik. **Tanggal:** 30 Oktober 2026. Dokumen ini menggabungkan rencana [01 dunia](01-dunia-chunk-streaming.md), [02 visual](02-visual-aset-karakter-ui.md), [03 goal/NPC](03-goal-resep-npc-cerita.md) dan [04 dampak/uji/risiko](04-dampak-dokumen-task-uji-risiko.md). Belum ada kode game dan belum ada dokumen sumber (PRD, CONTENT, TASKS lama) yang diubah; semuanya baru terjadi di SCOPE-001 setelah pemilik menyetujui. Tidak ada angka di sini yang sudah diukur: Godot tidak tersedia di sesi perencanaan.

## 1. Keputusan pemilik yang menjadi dasar
Dari instruksi pengguna: grafik stylized lumayan (tidak kotak-kotak, target arah Firewatch tanpa aset Firewatch); aset dari paket CC0 + generator kode; goal "kumpulkan 3 resep warisan"; dunia bertahap mulai ~1 km²; NPC bergerak; hanya chunk dekat pemain yang dimuat, dengan rumus deterministik; aset lebih banyak (pohon, sungai, gunung, perumahan).

Yang BUKAN keputusan pemilik dan tetap DEFAULT UJI: nama tahap "P0.5", angka gerbang performa, pilihan dua resep baru dan penerimanya, ukuran chunk 28 m dan radius, jumlah warga (8), tepi dunia.

## 2. Penyelarasan ID task (dokumen 01–04 saling bertabrakan)
Rencana ini menetapkan satu penomoran. Dokumen lain dibaca dengan tabel pemetaan ini.

| ID kanonik | Isi | Catatan penyelarasan |
| --- | --- | --- |
| SCOPE-001 | Terapkan peta dampak 04 ke PRD, LEVEL_DESIGN, ART_DIRECTION, CONTENT, TEST_PLAN, TASKS, dll. | Gerbang pertama; menunggu persetujuan |
| REPO-001, TEST-001 | Bersihkan indeks Git (`.agents/`, `.hermes/`, `agents/`, `skills-lock.json`) tanpa menulis ulang riwayat; rapikan 19 skrip stres di `tests/` | Dari 04 |
| FIX-001 | Satu sumber untuk durasi masak/persiapan, konstanta tumbuh bayam, `DAY_DURATION` | Dari 04; GOAL-001a hanya menambah konten, tidak mengulang pekerjaan ini |
| FIX-002 | Analisis peringatan ObjectDB | Butuh Godot di Windows pengguna |
| ASSET-001 | Kebijakan, log, pengadaan aset CC0 | Dari 02 dan 04 |
| VIS-001 | Lingkungan: sky, kabut, cahaya, palet, material bersama, shader | 02 (lingkungan) + palet/material dari 04; pustaka prop pindah ke VIS-002 |
| VIS-002 | Dunia visual: vegetasi, rumah, pagar, tanaman, prop prosedural | Makna 02; bukan "karakter" seperti di draf awal |
| VIS-003 | Karakter pemain (viewmodel) dan tampilan NPC | Makna 02 |
| VIS-004 | Theme tunggal dan refaktor UI | Tambahan 02; permintaan "UI UX" pengguna |
| WORLD-002 | Fondasi deterministik: hash, `WorldField`, grid, perencana tanpa node | Makna 01 |
| WORLD-003 | Streaming terrain runtime, collision, kabut | Makna 01 |
| SAVE-002 | Save v2 (seksi `worldgen`, progres resep) + migrasi v1→v2 | Setelah WORLD-003 dan GOAL-001b; ditunda dari urutan 01 karena butuh progres resep dari 03 |
| WORLD-004 | Isi dunia: sungai, hutan, ladang, dusun, backdrop, LOD | Makna 01 (bukan NPC) |
| GOAL-001a/b/c | Konten 3 resep; progres/buku/penutup; dialog berbasis data | Makna 03 |
| WORLD-005 | NPC bergerak berjadwal di dunia chunk | Gabungan 01 (kontrak chunk↔NPC) dan 03 (jadwal, `NpcSimulation`) |
| SAVE-003 | Tambahan state NPC ke save v2 | Kecil; dipisah dari SAVE-002 agar SAVE-002 tidak menunggu NPC |
| QA-002 | Regresi penuh dan penerimaan gerbang | Terakhir |
| DEMO-001 | Tetap DIKERJAKAN; bukti kendali desktop manual | Hanya bisa dilakukan pengguna |
| TOOL-001 | Pasang `.agents/skills` ke `.claude/skills` | Hanya bila pengguna setuju |

## 3. Urutan dan gelombang
Tiap task = satu laporan bernomor (mulai 020; 019 dipakai PLAN-001, task perencanaan ini) dan pembaruan PROJECT_STATUS/TASKS (AGENTS §6). Dua agent tidak menyentuh file yang sama dalam satu gelombang. `scripts/main.gd`, `project.godot`, `tests/test_runner.gd`, `PROJECT_STATUS.md`, `TASKS.md` hanya diubah serial oleh koordinator.

| Gelombang | Task | Prasyarat |
| --- | --- | --- |
| 0 — keputusan | Pemilik menjawab pertanyaan §5 | — |
| 1 | SCOPE-001, REPO-001, TEST-001, ASSET-001 (paralel) | Persetujuan §5 |
| 2 | FIX-001, VIS-001, WORLD-002, GOAL-001a (paralel) | SCOPE-001 |
| 3 | WORLD-003, GOAL-001b, GOAL-001c, VIS-004 | Gelombang 2 |
| 4 | SAVE-002, WORLD-004, VIS-002 | WORLD-003, GOAL-001b |
| 5 | WORLD-005, VIS-003, SAVE-003 | WORLD-004, GOAL-001c |
| 6 | FIX-002, QA-002, DEMO-001 | Godot di Windows pengguna |

**Hasil terlihat paling cepat:** VIS-001 (cahaya, kabut, palet) dan VIS-002 (pohon, rumah) mengubah tampilan sebelum dunia besar siap. Karena itu rekomendasi: kerjakan VIS-001 lebih dulu bila ingin melihat kemajuan visual secepatnya.

## 4. Batas kemampuan sesi cloud dan titik cek manusia
- Sesi cloud bisa menulis kode, data dan tes, tetapi tidak bisa menjalankan Godot. Task ditutup SELESAI hanya bila bukti yang dibutuhkan ada; sisanya DIKERJAKAN (AGENTS §9).
- Titik cek manusia di Windows: (H1) jalankan harness dan lapor jumlah asersi; (H2) lihat visual VIS-001 dan lapor/kirim screenshot sendiri; (H3) rute ukur FPS, frame time dan memori di kampung→sungai→hutan; (H4) playtest 3 resep; (H5) impor aset di editor sekali.
- Aset: dari sesi cloud hanya GitHub terjangkau. Yang terverifikasi CC0 baru `KenneyNL/Starter-Kit-*`; Quaternius resmi belum ditemukan. Bangunan khas Indonesia sebagian besar dari generator kode. Pengguna dapat mengunduh paket CC0 sendiri ke `assets/_incoming/`.
- Push ke GitHub tertunda: akses ke `YourZyy/gameujik` ditolak (403) sampai pemilik menyambung ulang.

## 5. Pertanyaan yang perlu dijawab sebelum SCOPE-001
Dedup dari 20 pertanyaan agent; default dipakai bila tidak dijawab.
1. **Nama tahap, gerbang performa dan keputusan D26–D32** (04 §1.1): setuju? *Default:* ya; angka gerbang tetap DEFAULT UJI.
2. **Dua resep baru** Pepes Ikan Nila (penerima Mbah Wiji) dan Urap Pakis Kelapa (penerima Mas Bayu), memancing titik tetap tanpa minigame. *Default:* ya.
3. **Dunia:** tepi 1 km² berupa gunung tak terdaki; sungai hanya dapat diseberangi, bukan sumber air; foraging baru hanya setelah CONTENT diperbarui. *Default:* ya.
4. **Perangkat uji:** spesifikasi PC Windows Anda (CPU/GPU/RAM) untuk menetapkan radius muat. *Default:* 60 FPS pada perangkat Anda, radius muat 6.
5. **Repo:** setuju mengeluarkan `.agents/`, `.hermes/`, `agents/`, `skills-lock.json` dari indeks Git (tanpa rewrite riwayat), dan memasang skill ke `.claude/skills`? *Default:* keluarkan dari Git, skill tidak dipasang.
6. **Aset:** apakah Anda mau mengunduh paket CC0 sendiri, atau generator kode saja dulu? *Default:* generator saja sampai aset tersedia.
7. **Visual:** suasana senja tetap atau ada siklus waktu; font dan tangan pemain (02 §10). *Default:* senja tetap, tangan sederhana.
8. **Tempo:** sesi 45–75 menit, tanpa HUD jam (matahari sebagai isyarat waktu). *Default:* ya.

## 6. Risiko teratas (lengkap di 04 §5)
1. Tidak ada Godot di sesi cloud → bug streaming dan visual baru tampak saat Anda menjalankan; mitigasi: tes headless dan titik cek H1–H5.
2. Scope creep (dunia, resep, NPC sekaligus); mitigasi: gelombang bertahap dan SCOPE-001 sebagai gerbang.
3. Performa chunk streaming di Compatibility; mitigasi: anggaran per frame, mode sinkron cadangan, ukur di H3.
4. Migrasi save v1→v2; mitigasi: fixture dari alur QA-001, cadangan `.v1.bak`.
5. Aset CC0 tak terunduh atau lisensi tak terverifikasi; mitigasi: generator kode, ASSET_LOG wajib.
