# Rencana 04 — Dampak Dokumen, Task Terpadu, Rencana Uji, Risiko dan Kerja Tim

**Tanggal:** 30 Oktober 2026 · **Status:** RENCANA (belum diterapkan ke dokumen sumber) · **Pelengkap:** rencana 01 (dunia), 02 (visual), 03 (konten/NPC). Isi teknis ketiganya tidak diulang di sini.
**Keadaan nyata yang dipakai:** 18 laporan selesai (terakhir 018); DEMO-001 DIKERJAKAN; master runner terakhir tercatat 8.854 asersi lulus pada Godot 4.7.2 Windows (bukti di PROJECT_STATUS, bukan diulang sesi ini). Sesi cloud tidak memiliki Godot: tidak ada klaim uji baru di sini.

## 1. Peta dampak dokumen

Pemicu: arahan pemilik 30 Oktober 2026 (visual Firewatch dengan aset CC0 + generator kode; dunia ~1 km² dengan chunk streaming; NPC bergerak; tujuan "kumpulkan 3 resep warisan"). Menurut AGENTS §3 arahan ini mengungguli dokumen; label DISETUJUI tidak diturunkan diam-diam, melainkan **dilengkapi/digantikan dengan ID baru bertanggal** dan dokumen sumber diedit di tempat (bukan catatan kontradiktif di ujung). Seluruh perubahan dikerjakan oleh SCOPE-001 (bagian 3).

### 1.1 Keputusan baru siap salin ke PRD §3 (setelah D25)

| ID | Keputusan | Status |
| --- | --- | --- |
| D26 | Tahap baru **P0.5 "Kampung Hidup"** di antara P0 dan P1; P0 tetap tercatat SELESAI sebagai riwayat | DISETUJUI oleh pemilik pada 30 Okt 2026; gerbang angka DEFAULT UJI |
| D27 | Satu map fiksi diperluas menjadi ±1 km² dengan chunk streaming; area awal P0 menjadi zona inti; ID lokasi P0 tidak berubah. Melengkapi D14 | DISETUJUI oleh pemilik pada 30 Okt 2026; ukuran chunk/radius DEFAULT UJI (rencana 01) |
| D28 | Visual stylized terinspirasi Firewatch memakai aset CC0 yang terverifikasi + generator kode; tanpa aset Firewatch; semua aset masuk manifes lisensi. Melengkapi D12 | DISETUJUI oleh pemilik pada 30 Okt 2026 |
| D29 | NPC bergerak dengan jadwal sederhana berbasis waktu simulasi, lebih dari satu warga. Menggantikan "satu NPC" pada D19 untuk P0.5 | DISETUJUI oleh pemilik pada 30 Okt 2026; jumlah NPC/jadwal DEFAULT UJI (rencana 03) |
| D30 | Tujuan P0.5: mengumpulkan **3 resep warisan**; Sayur Bening Bayam dan Jagung (D13) tetap salah satunya. Satu resep aktif (D17) tetap. Mengisi sebagian D22; jumlah akhir 8–12 (P2) tetap TERBUKA | DISETUJUI oleh pemilik pada 30 Okt 2026; pilihan dua resep lain DEFAULT UJI (rencana 03) |
| D31 | Save berpindah ke skema v2 dengan migrasi v1→v2 tertulis, cadangan v1 dipertahankan | DEFAULT UJI (kebijakan AGENTS §8); dikunci pada SAVE-002 |
| D32 | Dalam P0.5 tetap tanpa combat, multiplayer, backend, login, telemetri, AI runtime, pembelian bahan, hunger bar, minimap wajib. Satu petak/empat titik dan dua tahap memasak (sisa D19) tetap sampai GOAL-001 membuktikan perlu berubah | DISETUJUI (mempertahankan D06/D15/D20) |

Perlakuan label lama: D13, D14, D19 diberi tambahan "Berlaku untuk P0; dilengkapi D27/D29/D30 sejak 30 Okt 2026" pada kolom status, bukan dihapus. D22 ditulis "jumlah resep P0.5 = 3 (D30); jumlah akhir tetap TERBUKA".

### 1.2 Dampak per berkas

Versi baru **0.3 · 30 Oktober 2026** hanya untuk berkas yang benar-benar diubah; berkas tak tersentuh tetap 0.2.

| Berkas | Bagian/ID usang atau bertentangan | Perubahan yang diusulkan | Status label |
| --- | --- | --- | --- |
| PRD.md | Baris 4 "belum ada implementasi game" (sudah usang sejak SETUP-001); §1 "satu perjalanan"; §2 baris Tujuan P0, Tempat, Arah visual; D13, D14, D19, D22; §6 tabel tahap dan paragraf "Peta Indonesia luas…"; §10 "Area kecil terhubung"; §12 baris Performa; §13 aset; §15 risiko; §16 jumlah resep | Tambah D26–D32 (1.1); tambah baris tahap P0.5 pada §6 dengan gerbang bagian 2; FR25–FR30 baru (dunia chunk, aset CC0, NPC bergerak, 3 resep warisan, save v2, performa dunia luas); revisi §10 menjadi zona inti + dunia ±1 km²; risiko baru dari bagian 5; perbaiki baris 4 sesuai PROJECT_STATUS; tambah baris riwayat 0.3 | D26–D30, D32 DISETUJUI (pemilik, 30 Okt 2026); D31 DEFAULT UJI |
| AGENTS.md | §4 butir "Satu petak…", "Satu map fiksi", "Satu resep P0", "Detail event baru dibangun setelah loop dasar"; §1 batas sesi; §8 save; header versi 0.2 | Ubah butir menjadi "P0: …; P0.5: lihat D26–D32"; tambahkan aturan aset CC0/manifes (rujuk ART_DIRECTION §10) dan kebijakan pembagian berkas (bagian 6); naikkan ke 0.3 | Aturan kerja; disetujui lewat arahan pemilik |
| README.md | Baris 4 "Kode game… belum dibuat"; §1 "prototipe satu resep"; §3 baris Prototipe/Visual; §6 "Belum ada aset eksternal"; §7 tabel direktori; §10 | Perbarui keadaan nyata (kode ada, 26 suite); tambah baris Cakupan aktif P0.5; tambah direktori aset pihak ketiga dan generator visual; tautkan folder `docs/plans/` | Faktual |
| LEVEL_DESIGN.md | §1 "bukan map Indonesia luas"; §2 amplop X −40..+40, Z −35..+45; §3 rute tunggal; §7 batas dunia; §8 `zone_event_edge`; §9 urutan; §10 kriteria | Ubah §2 menjadi `zone_core` (koordinat tabel lama dipertahankan persis, ID stabil); tambah bagian dunia ±1 km² (zona, jalan antar-zona, batas, titik 3 sumber warisan) merujuk rencana 01 tanpa menyalin angka chunk; kriteria baru: tiap resep warisan dapat ditemukan tanpa minimap | DEFAULT UJI; tata ruang graybox |
| ART_DIRECTION.md | §6 "Anggaran awal produksi: satu rumah…"; §7 "Seluruh aset BELUM DIBUAT" (usang sejak ART-001); §3 "material terbatas"; §10 lisensi | Ganti anggaran ke anggaran per-chunk (angka di satu tabel, rencana 02); perbarui §7 dengan keadaan nyata ART-001; tambah aturan CC0 + generator, manifes, larangan campuran CC-BY tanpa atribusi tercatat | D28 DISETUJUI; anggaran DEFAULT UJI |
| CONTENT.md | §1 "sumber tunggal P0"; §4 satu resep; §9 durasi hari; §12 bentuk data; §14 parameter | Tambah bagian: dua resep warisan (ID, bahan, sumber, tahap), jadwal NPC, parameter dunia/streaming sebagai **satu-satunya** tempat angka; hari 720 s dan durasi lain tetap di sini (lihat FIX-001) | DEFAULT UJI |
| PROTOTYPE.md | §2 "Satu map kecil… NPC berjalan terjadwal" tidak ada; §5 matriks waktu; §7 save; §10 gerbang | Beri banner "kontrak P0; ditambah P0.5"; tambah baris matriks waktu untuk NPC dan streaming (berhenti saat pause); §7 tambah skema v2 dan migrasi; gerbang P0.5 merujuk bagian 2 | Kontrak perilaku |
| TEST_PLAN.md | §1 klaim "BELUM DIJALANKAN" sudah sebagian usang dan memuat path lokal `C:\Users\HP`; §6 durasi 10–15 menit; matriks §5 | Tambah §10 (T61–T90), baris matriks FR25–FR30, ganti path lokal dengan placeholder `<folder-proyek>` | Faktual |
| TASKS.md | §1 "mulai SETUP-001"; §2 dependensi DIST-001/002 ke QA-001; §4 EV-001 ke QA-001; §5 baris "Resep kedua/ketiga" | Tambah register P0.5 (bagian 3); DIST dan EV bergantung ke QA-002 (dependensi lama dicatat sebagai riwayat); baris backlog resep ditandai "diambil oleh GOAL-001" | Faktual |
| CONSISTENCY_CHECK.md | Seluruh isi adalah snapshot 27 Okt (mis. "25 task", "belum ada kode") | **Jangan ubah isi lama.** Tambah bagian "Audit v0.3" dengan DOC-T09–T12 (lihat 4.3) dan baris hubungan baru (skala dunia, aset CC0, 3 resep) | Riwayat dipertahankan |
| UI_UX.md | §3 "Tidak ada minimap" (tetap berlaku); UI02 "daftar resep baru bila >1"; belum ada penanda navigasi dunia luas; UI07 dialog NPC statis | Aktifkan daftar resep untuk 3 resep warisan (tetap satu resep dilacak); tambah UI09 progres warisan (ringkas, di buku); indikator pemuatan chunk hanya bila terlihat; arah/kompas tanpa minimap adalah USULAN (pertanyaan 4) | USULAN BARU |
| EVENT_DESIGN.md | §1 "P0 tetap membuktikan satu loop"; §7 baseline "jumlah masakan"; `zone_event_edge` | Gate event menjadi QA-002; baseline masakan dihitung per resep; tegaskan event tetap P1 dan tidak ikut P0.5 | Tetap USULAN BARU |

## 2. Kebijakan tahap

**Nama:** P0.5 "Kampung Hidup". **Isi:** dunia ±1 km² chunk streaming, visual CC0+generator, NPC bergerak, tiga resep warisan, save v2. **Bukan isi:** event Karhutla (tetap P1, setelah QA-002), pasar, memancing, installer (DIST tetap, kini setelah QA-002).

**Pencatatan P0:** P0 tetap "SELESAI (gameplay)" dengan laporan 001–018 utuh; tidak ada bullet dihapus. PROJECT_STATUS mendapat bullet baru P0.5 di bawah daftar yang ada. Rilis P0 ditandai sebagai build rujukan regresi: fixture save v1 dibuat dari alur QA-001 dan disimpan di `tests/fixtures/` (bukan save pribadi). Regresi P0 (T01–T60) menjadi syarat tetap P0.5.

**Gerbang penerimaan P0.5** (DEFAULT UJI, dapat disesuaikan dengan catatan dampak sesuai AGENTS §3):

1. Semua tes otomatis kritis (T61–T77) lulus, termasuk seluruh suite P0 lama; tidak ada pengurangan asersi tanpa alasan tertulis.
2. Perangkat uji pengguna dicatat; rute standar tepi-ke-tepi: rata-rata ≥60 FPS, 1% terendah ≥30 FPS pada 1080p kualitas rendah; fallback sah: rata-rata ≥30 FPS dengan catatan jujur dan keputusan pemilik.
3. Lintasan batas chunk: tidak ada frame >100 ms pada ≥95% dari 20 lintasan; maksimum dilaporkan.
4. Memori 30 menit: pertumbuhan setelah pemanasan <10% dan jumlah ObjectDB saat exit tidak lebih buruk dari baseline P0 (5.026 tercatat 30 Okt).
5. Pemain baru menyelesaikan 3 resep warisan dari profil bersih dan dari save tengah, tanpa minimap, bantuan tercatat.
6. Nol masalah kritis (definisi TEST_PLAN §2); nol aset tanpa entri manifes lisensi; save v1 pengguna termigrasi tanpa kehilangan.

## 3. Daftar task terpadu (urutan global)

Ukuran relatif: S kecil, M sedang, L besar. "Paralel" berarti tidak menyentuh berkas yang sama (kepemilikan di bagian 6). Setiap task menghasilkan satu laporan bernomor (mulai 019).

| # | ID | Pekerjaan | Dependensi | Paralel dengan | Ukuran | Gerbang penerimaan |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | SCOPE-001 | Terapkan bagian 1 ke PRD, AGENTS, README, LEVEL_DESIGN, ART_DIRECTION, CONTENT (kerangka), PROTOTYPE, TEST_PLAN, TASKS, UI_UX, EVENT_DESIGN; tambah entri CONSISTENCY_CHECK | Jawaban pertanyaan 1–3; rencana 01–03 final | REPO-001, TEST-001 | M | Audit tautan/ID/T-nomor (DOC-T09–T12) lulus; tidak ada kontradiksi D13/D19 vs D26–D32 |
| 2 | REPO-001 | Keluarkan `.agents/` (960 berkas), `.hermes/` (59), `agents/` (1), `skills-lock.json` dari indeks Git (`git rm --cached`) dan tambahkan ke `.gitignore`; berkas tetap di disk. Alasan: memuat path lokal `C:\Users\HP` dan artefak kerja agen | Pertanyaan 3 | Semua kecuali yang menyentuh `.gitignore` | S | `git ls-files` tidak memuat path itu; tidak ada rewrite riwayat tanpa izin |
| 3 | TEST-001 | Rapikan 19 skrip stres/adversarial di root `tests/` (total 21 `.gd` termasuk `assertions.gd` dan `test_runner.gd`, yang tetap): pindah ke `tests/tools/` atau gabung ke suite bila bernilai; periksa tidak ada rujukan `res://tests/…` yang patah | — | SCOPE-001, REPO-001, ASSET-001 | S | Runner tetap lulus pada jumlah asersi tidak berkurang; daftar pindah/gabung/hapus (hapus perlu persetujuan) |
| 4 | FIX-001 | Konsolidasi durasi ganda ke satu sumber (mis. `COOK_DURATION` di `kitchen_manager.gd` vs `cook_duration` di `recipe_data.gd`; konstanta tumbuh di `garden_manager.gd`; `DAY_DURATION` di `world_resource_manager.gd`) dengan nilai dari CONTENT | SCOPE-001 (CONTENT) | ASSET-001, VIS-001 | S | T75 lulus; nilai perilaku tidak berubah (regresi T34/T41/T37) |
| 5 | ASSET-001 | Pilih, unduh dan inventarisasi aset CC0; `assets/third_party/**` + manifes (sumber, pembuat, lisensi, tanggal, hash, perubahan); kebijakan impor | Pertanyaan 5 (akses unduh) | TEST-001, FIX-001, SCOPE-001 | M | T71/T72 lulus; setiap berkas ada di manifes; jalur fallback tanpa unduhan terdokumentasi |
| 6 | FIX-002 | Analisis peringatan ObjectDB (5.026 instance, 14 resource saat exit): reproduksi dengan `--verbose`, tentukan akar (autoload, preload, node yatim), perbaiki atau dokumentasikan sebagai bawaan tes | Godot di Windows pengguna | VIS-001, ASSET-001 | M | Penyebab tertulis; angka sebelum/sesudah dari run nyata; T76 ditulis |
| 7 | VIS-001 | Pustaka generator kode: palet, material bersama, shader sederhana, pembangun prop prosedural, seed deterministik | SCOPE-001, ASSET-001 (daftar aset) | WORLD-002 (berkas berbeda) | M | T73/T74 lulus; render GUI diperiksa pengguna (H2) |
| 8 | WORLD-002 | Inti chunk streaming: koordinat chunk, manajer muat/bongkar, status persisten per chunk, anggaran per frame | SCOPE-001, FIX-001 | VIS-001, GOAL-001 (data) | L | T61–T63, T74, T76 lulus; ditulis ≠ lulus performa (H3) |
| 9 | WORLD-003 | Peta ±1 km²: zona, jalan, batas, penempatan sumber, ID stabil dan migrasi ID lokasi P0 | WORLD-002, VIS-001 | GOAL-001 | L | T64 lulus; rute 3 sumber warisan terhubung; recovery di tepi |
| 10 | GOAL-001 | Dua resep warisan tambahan, daftar resep buku, progres 3 resep, penutup tujuan | SCOPE-001, rencana 03 | WORLD-002 | M | T69/T70 lulus; T11/T12/T13 tidak regresi |
| 11 | WORLD-004 | NPC bergerak: jadwal, waypoint/navigasi, dialog kontekstual, pause-aware | WORLD-003, GOAL-001 | VIS-002 | L | T67/T68 lulus; NPC tidak mengunci sumber (T45) |
| 12 | VIS-002 | Lingkungan: rumah, vegetasi, prop, tanaman memakai aset + generator, per-chunk | VIS-001, WORLD-003 | WORLD-004 (berkas berbeda) | L | T72/T74 lulus; keterbacaan sumber (T82) dinilai pengguna |
| 13 | SAVE-002 | Skema v2 (chunk, NPC, progres 3 resep), migrasi v1→v2, fixture, pemulihan | WORLD-004, GOAL-001 | VIS-002, VIS-003 | M | T65/T66 lulus; T14/T16/T17/T22/T46–T50 ulang lulus |
| 14 | VIS-003 | Cahaya, atmosfer, penyesuaian UI, profil performa dan anggaran | VIS-002 | SAVE-002 | M | Metrik H3 dicatat; T86 oleh pengguna |
| 15 | QA-002 | Regresi penuh, playtest, gerbang P0.5 (bagian 2) | Semua di atas, DEMO-001 | — | L | Semua gerbang bagian 2; laporan dengan perangkat dan angka nyata |
| — | DEMO-001 | Tetap DIKERJAKAN: bukti kendali desktop manual (T88). Dikerjakan pengguna di Windows; tidak diblokir task lain, tetapi QA-002 menunggunya | QA-001 | Semua | S | Status tidak berubah sampai pengguna melapor |
| — | TOOL-001 | Pasang skill `.agents/skills` ke `.claude/skills` hanya bila pengguna setuju | Pertanyaan 5 | Semua | S | Berkas tersalin tanpa path lokal; tidak masuk Git bila berisi artefak lokal |
| — | DIST-001/002 | Tidak berubah selain dependensi: setelah QA-002 | QA-002 | — | — | — |

Jalur paralel aman: {SCOPE-001, REPO-001, TEST-001, ASSET-001} pada gelombang pertama; {VIS-001, WORLD-002, GOAL-001, FIX-002} pada kedua; {WORLD-004, VIS-002} pada ketiga; {SAVE-002, VIS-003} pada keempat. Dua agen tidak pernah menyentuh `tests/test_runner.gd`, `scripts/main.gd` atau `project.godot` pada gelombang yang sama (lihat bagian 6).

## 4. Rencana uji

### 4.1 Otomatis (headless, tanpa GUI) — dapat ditulis di sesi cloud, hanya dijalankan di mesin ber-Godot

Penomoran melanjutkan T60. Semua status awal **BELUM DIJALANKAN**. Kolom Jenis: A otomatis, M manual Windows.

| ID | Jenis | Kondisi dan langkah | Hasil yang diharapkan |
| --- | --- | --- | --- |
| T61 | A | Konversi posisi dunia ↔ ID chunk, termasuk koordinat negatif dan batas tepat | Pemetaan deterministik dan bolak-balik konsisten |
| T62 | A | Gerakkan posisi simulasi melintasi banyak chunk; periksa himpunan chunk aktif | Himpunan sesuai radius; tak ada chunk ganda; muat/bongkar idempoten |
| T63 | A | Ubah sumber/petak/pickup, bongkar lalu muat chunk | Status tetap; tidak ada panen ganda atau reset |
| T64 | A | Semua ID lokasi P0 (LEVEL_DESIGN §2) dan ID baru | Ada, unik global, koordinat zona inti tak berubah |
| T65 | A | Fixture save v1 → muat dengan migrasi → simpan v2 → muat | Seluruh state P0 sama; cadangan v1 tidak ditimpa |
| T66 | A | Save v2 rusak, versi lebih baru, ID tak dikenal | Ditolak dengan alasan; dunia lama tidak diganti |
| T67 | A | Maju waktu simulasi; pause; save/load | NPC maju hanya saat simulasi berjalan; posisi/jadwal pulih |
| T68 | A | Graf waypoint semua jadwal NPC | Semua titik jadwal terhubung dan terjangkau; tak ada titik di collision |
| T69 | A | Selesaikan 3 resep berurutan dan berulang | Tiap resep tercatat sekali; penutup tujuan sekali; ulangan tak memberi hadiah ganda |
| T70 | A | Bahan tumpang tindih antar-resep; reservasi | Tracker dan dapur memakai total sama; tak ada hitung ganda (regresi T11/T12) |
| T71 | A | Pindai `assets/third_party/` terhadap manifes | Setiap berkas punya entri; lisensi CC0; hash cocok; tak ada berkas yatim |
| T72 | A | Pindai rujukan `res://` di skrip/scene | Semua resolvable; tak ada aset hilang |
| T73 | A | Generator dengan seed sama dua kali | Keluaran identik (jumlah vertex/hash) |
| T74 | A | Hitung node, instance MultiMesh dan material per chunk | Di bawah anggaran CONTENT; bukan klaim FPS |
| T75 | A | Cari definisi durasi ganda | Satu sumber per nilai; perilaku tak berubah |
| T76 | A | 50 siklus buat/bebaskan chunk dan NPC | Jumlah objek kembali ke baseline; tanpa node yatim baru |
| T77 | A | Jalankan seluruh suite P0 | Lulus; jumlah asersi dilaporkan |

### 4.2 Wajib manual di Windows pengguna

Catat tiap kali: tanggal, build/commit, Godot 4.7.2 + renderer, CPU/GPU/RAM, driver, resolusi, mode layar, kualitas, rute. Metrik: FPS rata-rata, 1% terendah, frame time maksimum (monitor Godot), memori awal/akhir.

| ID | Kondisi dan langkah | Hasil yang diharapkan |
| --- | --- | --- |
| T78 | Rute standar tepi-ke-tepi 1 km² tiga kali | FPS dan frame time dicatat; memenuhi gerbang 2 atau dilaporkan jujur |
| T79 | 20 lintasan batas chunk dengan kecepatan jalan | Frame >100 ms ≤5% lintasan; maksimum dilaporkan |
| T80 | Berjalan 30 menit lalu keluar | Pertumbuhan memori <10% setelah pemanasan; ObjectDB saat exit dibanding baseline |
| T81 | Salinan save v1 asli pengguna → Lanjutkan | Termigrasi, posisi aman, state sama; save asli tidak rusak |
| T82 | Lihat jagung, temu kunci, bayam, rumah dari jarak interaksi dan 25 m | Sumber wajib dikenali tanpa ikon saja; rumah tetap landmark |
| T83 | Pemain baru mencari tiga sumber warisan tanpa minimap | Berhasil; bantuan dan waktu tersasar tercatat |
| T84 | Amati NPC bergerak dan ajak bicara | Tidak menembus/menjebak; dialog tak mengunci sumber; terasa wajar |
| T85 | Playthrough 3 resep dari profil bersih dan save tengah | Selesai; durasi dan titik bingung dicatat |
| T86 | FOV 60/80/100 di lingkungan baru | Tanpa ketidaknyamanan berat; UI tak terpotong |
| T87 | Periksa kredit/atribusi pada build | Sesuai manifes |
| T88 | WASD+mouse langsung di window game (tertunda DEMO-001) | Gerak, bidik, E, panel berfungsi |
| T89 | 1280×720 dan 1920×1080, jendela dan layar penuh | Tata letak dan kinerja dicatat |
| T90 | Berjalan ke tepi dunia | Batas terbaca; recovery tidak mengubah item |

### 4.3 Audit dokumen (lanjutan DOC-T08)

DOC-T09 tautan dan ID setelah SCOPE-001; DOC-T10 tiap D26–D32 punya status dan tanggal, tidak ada D lama terhapus; DOC-T11 angka tidak ganda (angka dunia/chunk hanya di CONTENT); DOC-T12 setiap task P0.5 punya baris di TASKS, PROJECT_STATUS dan laporan setelah selesai.

Matriks untuk disalin: FR25 dunia chunk → T61–T64, T76, T78–T80, T90; FR26 aset CC0 → T71–T74, T82, T87; FR27 NPC → T67, T68, T84; FR28 3 resep → T69, T70, T83, T85; FR29 save v2 → T65, T66, T81; FR30 performa → T74, T78–T80, T89. FR numbering mengikuti PRD (FR25–FR30 diusulkan di SCOPE-001).

## 5. Register risiko (urut kemungkinan × dampak)

| # | Risiko | Kem. | Dampak | Mitigasi | Pemilik |
| --- | --- | --- | --- | --- | --- |
| R1 | Tidak ada Godot di sesi cloud: kode ditulis tanpa dijalankan, error baru terlambat ketahuan | Tinggi | Tinggi | Setiap laporan memisahkan "ditulis" dari "dijalankan"; task gameplay tidak SELESAI tanpa log run pengguna; titik cek H1–H4 (bagian 6); tes headless ditulis dahulu | Koordinator + pengguna |
| R2 | Scope creep: dunia 1 km² memancing konten, resep, event ekstra | Tinggi | Tinggi | Gerbang bagian 2; D32; ide baru ke backlog; dunia dibuat jarang (sparse) lebih dahulu | Pemilik produk |
| R3 | Performa chunk streaming (hitch, GDScript, renderer `gl_compatibility`) | Sedang-tinggi | Tinggi | Anggaran per frame, pemuatan berutas bila terbukti perlu, MultiMesh, profil pada T78–T79 sebelum menambah visual; urutan WORLD-002 sebelum VIS-002 | Agen WORLD |
| R4 | Aset CC0 tidak terunduh (proxy cloud membatasi; terlihat dari kegagalan koneksi MCP sesi ini) | Sedang-tinggi | Sedang | Unduh oleh pengguna/Windows; ASSET-001 memiliki jalur generator-saja; sumber diverifikasi saat itu, bukan dari ingatan | Agen ASSET + pengguna |
| R5 | Migrasi save v1→v2 menghilangkan atau menggandakan progres | Sedang | Tinggi | Fixture v1 dari QA-001, migrasi tak mutasi file asli, cadangan v1, T65/T66/T81 | Agen SAVE |
| R6 | Kebocoran memori/ObjectDB membesar karena streaming dan NPC | Sedang | Sedang-tinggi | FIX-002 lebih dulu menetapkan baseline; T76, T80 | Agen FIX |
| R7 | Lisensi: label CC0 salah, campuran CC-BY, kemiripan dengan Firewatch | Sedang | Tinggi | Manifes + hash, tangkapan halaman lisensi, T71/T87; tanpa aset game referensi | Agen ASSET |
| R8 | Dua agen mengubah berkas sama; dokumen saling kontradiksi | Sedang | Sedang | Kepemilikan berkas (bagian 6); SCOPE-001 satu pemilik; DOC-T09–T12 | Koordinator |
| R9 | Bug NPC (macet, menembus, nonaktif saat pause, state tak tersimpan) | Sedang | Sedang | Waypoint sederhana lebih dahulu; T67/T68/T84 | Agen WORLD |
| R10 | Path lokal/artefak agen (`C:\Users\HP`) tetap di riwayat Git | Tinggi (sudah terjadi) | Rendah-sedang | REPO-001; rewrite riwayat hanya atas izin | Pengguna |
| R11 | Repositori membengkak oleh aset | Sedang | Sedang | Anggaran ukuran di ASSET-001; pertimbangkan Git LFS (pertanyaan terbuka bila perlu) | Agen ASSET |
| R12 | Regresi sistem P0 (inventaris, reservasi, save) | Sedang | Tinggi | T77 di tiap gelombang; perbaikan dengan task baru, bukti lama tak dihapus | Semua agen |

## 6. Kebijakan kerja tim agen

**Kepemilikan berkas (satu pemilik per gelombang):**

| Jalur | Berkas milik | Task |
| --- | --- | --- |
| Dokumen | PRD, AGENTS, README, semua `docs/*.md` kecuali yang di bawah | SCOPE-001 (kemudian task yang namanya tertulis) |
| Aset | `assets/third_party/**`, manifes lisensi | ASSET-001 |
| Visual | `scripts/visual/**`, `scenes/env/**` | VIS-001/002/003 |
| Dunia | `scripts/world/**`, `scenes/world/**` | WORLD-002/003 |
| NPC | `scripts/npc/**` | WORLD-004 |
| Resep | `scripts/recipe/**`, bagian resep CONTENT | GOAL-001 |
| Save | `scripts/save/**`, `tests/fixtures/**` | SAVE-002 |
| Hygiene | `.gitignore`, indeks Git | REPO-001 |
| Tes | berkas suite baru bernama per task; `tests/test_runner.gd` hanya oleh koordinator | tiap task menulis suite baru, koordinator mendaftarkan berurutan |

Berkas lintas jalur (`scripts/main.gd`, `project.godot`, `tests/test_runner.gd`, PROJECT_STATUS, TASKS) hanya diubah serial oleh koordinator.

**Urutan penutupan:** agen menyelesaikan kode dan menulis tes → agen menyerahkan draf laporan memakai TEMPLATE → koordinator menentukan nomor (terbesar + 1; mulai 019) menurut urutan selesai, bukan urutan mulai → membuat `NNN-nama-task.md` → menambah bullet di PROJECT_STATUS (urut waktu) dan mengganti Deskripsi Status 150–300 kata → menandai TASKS dan menautkan → periksa tautan/ID. Task tanpa bukti run pengguna ditandai DIKERJAKAN atau TERHAMBAT, bukan SELESAI. Tidak ada angka commit/FPS fiktif.

**Titik cek manusia (pengguna menjalankan game di Windows dan melapor):**

| Titik | Setelah | Yang dijalankan |
| --- | --- | --- |
| H1 | Gelombang 1 | Runner headless (T77), T88/DEMO-001 |
| H2 | VIS-001 | Pemandangan uji generator; foto/tangkapan layar dilampirkan pengguna |
| H3 | WORLD-002 dan WORLD-003 | T78–T80 awal: FPS, hitch, memori sebelum konten visual berat |
| H4 | WORLD-004 + GOAL-001 | T84, T83 awal |
| H5 | SAVE-002 | T81 dengan salinan save asli |
| H6 | QA-002 | T78–T90 penuh dan playtest |

Perintah, hasil mentah dan perangkat dilaporkan apa adanya; agen tidak menafsirkan "tidak ada error" sebagai kenyamanan.

## 7. Pertanyaan terbuka (maksimal lima; default bila tidak dijawab)

1. **Cakupan tersisa D19:** apakah petak/titik tanam dan tahap memasak boleh bertambah untuk tiga resep? *Default:* tetap satu petak/empat titik/dua tahap hingga GOAL-001 membuktikan kekurangannya.
2. **Nama dan gerbang:** setuju nama "P0.5 Kampung Hidup", DIST-001/002 dan EV-001 digeser setelah QA-002, dan gerbang bagian 2 (60 FPS rata-rata, ≥30 FPS terendah, hitch ≤100 ms)? *Default:* ya.
3. **Hygiene Git:** setuju `.agents/`, `.hermes/`, `agents/`, `skills-lock.json` dikeluarkan dari indeks tanpa menulis ulang riwayat? *Default:* ya, tanpa rewrite.
4. **Navigasi tanpa minimap:** kompas/arah di buku atau petunjuk lingkungan saja? *Default:* petunjuk lingkungan + deskripsi arah di buku, tanpa HUD baru.
5. **Aset dan skill:** apakah pengguna mengunduh aset CC0 sendiri (mengirim ke folder proyek) bila sesi cloud tidak bisa, dan setuju skill `.agents/skills` dipasang ke `.claude/skills` (TOOL-001)? *Default:* generator-saja sampai aset tersedia; skill tidak dipasang.

## Ringkasan 10 baris

1. Dokumen dibuat di `docs/plans/04-dampak-dokumen-task-uji-risiko.md`; tidak ada berkas lain diubah, tidak ada klaim uji baru.
2. Usul D26–D32 siap salin (P0.5, dunia ±1 km², CC0+generator, NPC bergerak, 3 resep warisan, save v2, batas lingkup); D13/D14/D19 dilengkapi bertanggal, tidak dihapus.
3. Peta dampak 12 berkas dengan bagian usang spesifik; versi 0.3 hanya untuk berkas yang berubah; CONSISTENCY_CHECK tidak ditulis ulang.
4. Temuan stale: PRD baris 4, README baris 4/§6, ART_DIRECTION §7, TEST_PLAN §1 dan path `C:\Users\HP`.
5. Tahap "P0.5 Kampung Hidup" dengan enam gerbang terukur (DEFAULT UJI); P0 tetap SELESAI sebagai riwayat dan baseline regresi.
6. 15 task berurutan + DEMO-001/TOOL-001/DIST, dengan dependensi, jalur paralel, ukuran S/M/L; FIX-001/002, REPO-001, TEST-001 disisipkan.
7. Fakta repo: 960 berkas `.agents`, 59 `.hermes`, 1 `agents/`, `skills-lock.json` terlacak Git; 21 `.gd` di root tests (19 skrip + `assertions.gd` + `test_runner.gd`).
8. 17 tes otomatis (T61–T77) dan 13 manual Windows (T78–T90) dengan metrik perangkat; matriks FR25–FR30.
9. 12 risiko berurut; teratas: tanpa Godot di cloud, scope creep, performa streaming, aset CC0 tak terunduh.
10. Kebijakan kerja: kepemilikan berkas per jalur, penutupan serial oleh koordinator (laporan mulai 019), enam titik cek manusia H1–H6, lima pertanyaan terbuka dengan default.
