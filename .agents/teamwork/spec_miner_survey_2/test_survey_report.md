# Laporan Survei Spesifikasi Pengujian, Verifikasi, dan Kepatuhan
**Proyek:** Buku Resep 2045  
**Penyusun:** `spec_miner_survey_2` (Specification Miner)  
**Tanggal:** 27 Oktober 2026  
**Status Acuan:** v0.2  
**Dokumen Sumber Otoritatif:** `docs/TEST_PLAN.md`, `AGENTS.md`, `docs/PROJECT_STATUS.md`, `docs/TASKS.md`, `docs/completed_tasks/` (`001-paket-dokumentasi-v0-2.md`, `TEMPLATE.md`, `README.md`), `PRD.md`, `docs/CONTENT.md`, `docs/PROTOTYPE.md`, `docs/UI_UX.md`, `docs/LEVEL_DESIGN.md`.

---

## 1. Ringkasan Eksekutif & Ruang Lingkup Survei

Survei ini melakukan ekstraksi dan penataan menyeluruh terhadap seluruh spesifikasi verifikasi, kasus uji penerimaan, kebutuhan test harness / test runner untuk engine Godot, aturan kepatuhan pelaporan agent (`AGENTS.md`), serta kriteria gerbang (gate criteria) dari seluruh rangkaian task (mulai dari `SETUP-001` hingga `QA-001`, `DIST-001`/`DIST-002`, dan jalur pasca-P0 `EV-001` s/d `EV-QA-001`).

Seluruh temuan disusun secara ketat untuk menjadi dasar perancangan arsitektur pengujian otomatis, panduan validasi gameplay, dan protokol integritas pengiriman task bagi agent implementasi dan QA.

---

## 2. Features Discovered

Tabel berikut memetakan seluruh fitur dan subsistem game yang memiliki kontrak perilaku, kebutuhan verifikasi, dan batasan operasional yang ditemukan pada dokumen otoritatif proyek:

| # | Kategori | Fitur | Deskripsi | Input | Output | Perilaku Error / Kegagalan | Ditemukan Via |
|---|---|---|---|---|---|---|---|
| 1 | Lingkungan & Spasial | Graybox Map & Spawn Point | Ruang 3D pekarangan, rumah, jalan setapak, collision batas, titik spawn awal | Inisialisasi main scene | Entitas pemain ter-spawn pada koordinat valid | Spawn overlap collision dicegah; recovery ke anchor aman | `docs/LEVEL_DESIGN.md`, `docs/TASKS.md` (LVL-001) |
| 2 | Lingkungan & Spasial | Safe Position Recovery | Fitur pemulihan pemain tersangkut | Tombol "Kembali ke posisi aman" dari menu pause | Posisi/rotasi dipindahkan ke spawn aman | Ditolak saat load/save/commit transaksi sedang berjalan | `docs/PROTOTYPE.md` §8, `docs/TEST_PLAN.md` (T25) |
| 3 | Kendali & Kamera | First-Person Movement & Look | Kendali WASD, mouse look, batas pitch vertikal, tanpa sprint/crouch/head-bob | Keyboard WASD, Mouse Delta | Transform kamera & kinematic character body | Jarak tempuh konsisten pada FPS 30/60/144; delta-time scaled | `docs/TASKS.md` (PLY-001), `docs/TEST_PLAN.md` (T18, T26) |
| 4 | Interaksi & Input | Raycast Target & Occlusion | Bidik objek dalam jangkauan pandang; pencegahan tembus dinding | Kamera raycast arah forward, jarak jangkau | Reticle aktif, prompt label aksi (misal "E Ambil") | Objek terhalang collision tidak terpilih; prompt hilang | `docs/UI_UX.md` §4, `docs/TEST_PLAN.md` (T27) |
| 5 | Interaksi & Input | Input Context Management | Pengendali konteks input memisahkan Dunia, Buku, Tas, Peti, Dapur, Dialog, Pause | Tombol aksi (E, B, Esc, Tab, Klik) | Transisi status input, mouse captured vs visible | Aksi penutup modal tidak bocor ke aksi dunia | `AGENTS.md` §8, `docs/PROTOTYPE.md` §5, `docs/TEST_PLAN.md` (T28) |
| 6 | Inventaris & Item | Data Kamus Item & Batas Tumpukan | Definisi 7 item stabil, tumpukan maks 20 unit/slot, tas 12 slot, peti 12 slot | Penambahan/pengurangan item | Slot terisi, jumlah tumpukan terupdate | Slot penuh membuka slot baru; transaksi gagal total bila penuh | `docs/CONTENT.md` §2-3, `docs/TEST_PLAN.md` (T29) |
| 7 | Inventaris & Item | Atomic Transfer Tas-Peti | Pemindahan tumpukan / seluruh isi antar kontainer secara utuh | Klik transfer slot / tombol "Pindah Semua" | Item berpindah kontainer | Ditolak total jika kapasitas tujuan kurang; no partial loss | `docs/CONTENT.md` §3, `docs/TEST_PLAN.md` (T30) |
| 8 | Resep & Buku | Pelacakan Resep & HUD Tracker | Buku resep keluarga (`recipe_sayur_bening_01`), pin ke tracker HUD atas | Buka buku (B / meja), klik "Lacak" | HUD menampilkan resep & 3 bahan (x/kebutuhan) | Lacak/berhenti lacak tidak memutasi item atau progres | `docs/CONTENT.md` §4, `docs/TEST_PLAN.md` (T01, T03) |
| 9 | Resep & Buku | Pola Ketersediaan Bersama | Hitungan bahan bebas menggabungkan Tas + Peti rumah secara terpadu | Query ketersediaan bahan | Nilai agregat total bahan bebas | Barang dalam reservasi dapur & benih tertanam tidak dihitung | `docs/CONTENT.md` §3, `docs/TEST_PLAN.md` (T02, T11, T31) |
| 10 | Pertanian & Lahan | Siklus Olah Tanah & Pembenah | 1 petak `plot_home_01` (4 titik): Belum diolah -> Gembur -> Siap tanam | Cangkul (tahan 2s), Pembenah E (1 unit) | State petak berubah, visual tanah siap | Pembenah ditolak sebelum gembur; tidak dikonsumsi ganda | `docs/CONTENT.md` §6-7, `docs/TEST_PLAN.md` (T08, T32) |
| 11 | Pertanian & Lahan | Pemupukan & Penyiraman Petak | Pupuk (tahan 1s, nutrisi -> 100), Siram (tahan 2s, air -> 80, biaya 2 air) | Tool klik tahan pada petak | Nutrisi & kelembapan petak terupdate | Ditolak tanpa biaya jika nutrisi >=20 atau kelembapan >=60 | `docs/CONTENT.md` §7, `docs/TEST_PLAN.md` (T06, T07, T33) |
| 12 | Pertanian & Lahan | Pertumbuhan Tanaman Bayam | 4 tahap: Benih (<30s), Tunas (30-90s), Tumbuh (90-180s), Siap (>=180s) | Detik simulasi aktif (total 180s) | Model 3D tahap tanaman berganti | Berhenti jika nutrisi <20 atau lembap <30; tidak mati/mundur | `docs/CONTENT.md` §8, `docs/TEST_PLAN.md` (T34, T35) |
| 13 | Pertanian & Lahan | Panen Bayam & Imbal Balik Nutrisi | Panen titik siap: hasil 1 bayam + 1 benih; nutrisi petak -5 | Tombol interaksi E pada titik siap panen | 1 Bayam + 1 Benih masuk tas, titik kosong | Ditolak total jika tas tidak muat keduanyanya; tanaman utuh | `docs/CONTENT.md` §8, `docs/TEST_PLAN.md` (T05, T36) |
| 14 | Sumber Dunia & Kalender | Sumber Liar (Jagung & Temu Kunci) | Jagung keluarga & Temu kunci tepi bambu: panen 1x per hari simulasi | Interaksi E pada objek sumber | Item masuk tas, sumber menjadi pasif | Tidak memberi hasil ganda pada hari sama; pulih esok hari | `docs/CONTENT.md` §9, `docs/TEST_PLAN.md` (T04, T37) |
| 15 | Sumber Dunia & Kalender | Siklus Hari & Istirahat Ranjang | 1 hari = 720s aktif. Istirahat di kasur memajukan indeks hari & pulihkan sumber | Interaksi E di ranjang, konfirmasi dialog | Hari bertambah, waktu aktif reset ke 0, sumber pulih | Ditolak jika dapur sedang aktif memasak; tanaman tidak lompat | `docs/CONTENT.md` §9, `docs/TEST_PLAN.md` (T39) |
| 16 | Sumber Dunia & Kalender | Cadangan Pemulihan (Softlock Prevention) | Kotak cadangan memberi benih/pembenah/pupuk jika pemain kehabisan total | Interaksi E pada `reserve_home` | Paket darurat masuk inventaris | Ditolak jika masih ada stok di tas/peti atau tanaman hidup | `docs/CONTENT.md` §9, `docs/TEST_PLAN.md` (T09, T38) |
| 17 | Memasak di Dapur | Reservasi Bahan & Pembatalan | Validasi 3 bahan, tahan Siapkan 4s -> job ID dibuat, bahan dipesan | Tombol "Siapkan", Tombol "Batal" | Bahan masuk kontainer reservasi internal | Batal kembalikan bahan ke asal; jika penuh lari ke refund aman | `docs/PROTOTYPE.md` §6, `docs/TEST_PLAN.md` (T10, T12, T13, T40) |
| 18 | Memasak di Dapur | Tahap Memasak & Kontrol Panas | Pemasakan 30s efektif. Panas: Rendah (0.5x), Sedang (1.0x), Tinggi (0.0x) | Tombol "Mulai memasak", pilih radio panas | Bar progress memasak berjalan | Panas Tinggi tampilkan peringatan; bahan tidak pernah gosong | `docs/CONTENT.md` §4, `docs/TEST_PLAN.md` (T41) |
| 19 | Memasak di Dapur | Jeda Dapur & Penyelesaian Output | Menutup panel dapur menjeda job. Selesai -> 1 dish masuk slot output | Esc tutup panel / progress capai 100% | Job status `paused` / status `output_ready` | Job tidak jalan di background dunia; resep centang saat commit | `docs/PROTOTYPE.md` §6, `docs/TEST_PLAN.md` (T15, T42, T50) |
| 20 | Konsumsi & Sosial | Makan Hidangan & Berbagi Warga | Makan (makanan -1, flag `meal_used`) / Berbagi dengan tetangga via dialog | Klik "Makan" di tas/panel / dialog warga | Flag `meal_used` aktif, respons dialog penutup | Memerlukan hidangan di tas/peti; tidak ada duplikasi porsi | `docs/CONTENT.md` §10, `docs/TEST_PLAN.md` (T43, T44, T45) |
| 21 | Persistensi (Save/Load) | Envelope Serialisasi & Snapshot | Simpan seluruh state (pemain, tas, peti, petak, tanaman, dapur, flags, hari) | Save Manual (Pause menu) / Autosave pemicu | File json valid `save_checkpoint.json` | Validasi envelope; format korup tolak swap, cadangan dipakai | `docs/PROTOTYPE.md` §7, `docs/TEST_PLAN.md` (T14, T16, T46, T47) |
| 22 | Persistensi (Save/Load) | Penulisan Aman (Safe Atomic Write) | Tulis snapshot ke `.tmp` -> validasi -> rotasi file utama & backup | Fungsi penyimpanan runtime | File tersimpan tanpa risiko data terpotong | Interupsi tulis pertahankan file lama; tampilkan pesan gagal | `docs/PROTOTYPE.md` §7, `docs/TEST_PLAN.md` (T22, T49) |
| 23 | Antarmuka & Pengaturan | Menu Pause, Pengaturan, Aksesibilitas | Slider FOV, sensitivitas mouse, volume audio, skala UI, subtitle | Esc saat bermain, navigasi UI | Perubahan konfigurasi runtime & persistent file | Pengaturan tersimpan terpisah dari savegame progres | `docs/UI_UX.md` §5, `docs/TEST_PLAN.md` (T21, T51, T52) |
| 24 | Distribusi Desktop | Standalone Packaging & Portabilitas | Ekspor build desktop mandiri, pengoperasian offline, hak tulis `user://` | Eksekusi biner game di luar editor | Game berjalan mulus tanpa koneksi internet | Read-only folder instalasi tidak menyebabkan crash saat save | `AGENTS.md` §4, `docs/TEST_PLAN.md` (T20, T57, T58, T59, T60) |
| 25 | Event Tematik (Post-P0) | Mode Karhutla & Sains Sederhana | Simulasi kebakaran hutan, perubahan rute akses air, dampak lingkungan | Trigger event (sesudah P0) | Map state berubah, api aktif, objektif baru | Checkpoint pra-event dipertahankan; tidak merusak loop P0 | `docs/EVENT_DESIGN.md`, `docs/TEST_PLAN.md` (EV-T01 - EV-T12) |

---

## 3. Edge Cases Discovered

Tabel berikut mendokumentasikan kasus-kasus batas, input ekstrem, dan perilaku teramati yang ditentukan secara eksplisit dalam dokumen spesifikasi proyek:

| # | Fitur | Input / Kondisi Ekstrem | Perilaku yang Ditetapkan (Authoritative Spec) |
|---|---|---|---|
| 1 | Interaksi Objek (T04) | Spam tombol 'E' secara cepat pada wadah awal / sumber | Hasil hanya diberikan satu kali; state sumber termutasi satu kali; tidak ada duplikasi item. |
| 2 | Panen Tanaman (T05) | Panen saat tas hanya memiliki 1 sisa slot kosong (butuh 2 slot: bayam + benih) | Panen ditolak penuh; tanaman tetap pada status Siap Panen; nutrisi tanah tidak berkurang. |
| 3 | Penyiraman Petak (T07) | Melakukan aksi siram pada petak yang kelembapannya sudah >= 60 | Aksi ditolak dengan pesan kondisi cukup; air dalam penyiram tidak berkurang; tidak ada transaksi sia-sia. |
| 4 | Penanaman Titik (T08) | Mencoba menanam benih pada titik yang sudah terisi atau tanah belum diberi pembenah | Aksi ditolak dengan alasan jelas ("Tanah belum siap" / "Titik terisi"); benih tidak berkurang. |
| 5 | Cadangan Softlock (T09, T38) | Pemain meminta benih cadangan saat benih di tas/peti = 0, tetapi masih ada tanaman hidup di petak | Cadangan ditolak; teks UI menjelaskan bahwa tanaman yang sedang tumbuh akan menghasilkan benih saat panen. |
| 6 | Validasi Memasak (T10) | Menekan tombol "Siapkan" saat salah satu bahan kurang (misal bayam hanya 2 dari 3) | Transaksi ditolak 100%; tidak ada bahan yang dipindahkan ke reservasi; bahan yang kurang disebutkan di UI. |
| 7 | Reservasi Memasak (T11) | Bahan terbagi di dua tempat (2 bayam di tas, 1 bayam di peti) | Panel buku dan dapur mendeteksi total 3 bayam; reservasi mengambil dari tas terlebih dahulu, lalu peti. |
| 8 | Spam Tombol Dapur (T12) | Klik berulang kali secara cepat pada tombol "Siapkan" atau "Mulai" | Hanya satu Job ID yang dibuat; hanya satu paket reservasi bahan yang dikonsumsi; output tetap satu. |
| 9 | Pembatalan Masak (T13) | Membatalkan job pada tahap persiapan sebelum memasak dimulai | Bahan dikembalikan persis ke kontainer asalnya; jumlah bahan bebas kembali utuh tanpa ada yang hilang. |
| 10 | Batal Masak Saat Tas Penuh (T40) | Bahan dipesan dari tas, lalu tas dipenuhi barang lain via fixture, kemudian persiapan dibatalkan | Bahan dialihkan ke peti rumah; jika peti juga penuh, bahan dialihkan ke `kitchen_refund_container` persisten. |
| 11 | Pemasakan Panas Tinggi (T41) | Pengaturan kontrol panas diatur ke posisi "Tinggi" | Multiplier kemajuan menjadi 0.0x (tertahan); pesan "Kecilkan panas ke Sedang"; bahan tidak rusak/hangus. |
| 12 | Penutupan Panel Dapur (T42) | Menutup panel dapur dengan Esc saat timer memasak sedang berjalan | Job memasak dijeda (`paused`); job tidak berjalan di background dunia; tracker menyebut status tertahan. |
| 13 | Output Selesai Tas Penuh (T15) | Memasak selesai tetapi kapasitas tas pemain penuh saat menekan "Ambil" | Output hidangan tetap tersimpan aman di slot hasil dapur; resep tetap tercatat selesai di buku. |
| 14 | Penyerapan Output Idempoten (T50) | Muat snapshot saat job selesai / output ready berulang kali, lalu ambil hidangan | Output hanya diambil satu kali; tidak terjadi re-commit output atau penggandaan hidangan. |
| 15 | Istirahat Saat Masak Aktif (T39) | Mencoba tidur di kasur saat ada job dapur yang sedang aktif/berjalan | Aksi istirahat ditolak dengan peringatan untuk menyelesaikan atau membatalkan proses dapur terlebih dahulu. |
| 16 | Lompatan Hari via Istirahat (T39) | Pemain tidur di ranjang untuk memajukan hari | Indeks hari bertambah dan sumber liar pulih, tetapi simulasi tanaman & penguapan TIDAK dimajukan 720 detik. |
| 17 | Pemulihan Sumber Liar (T37) | Mencoba memanen jagung/temu kunci kedua kali sebelum tidur/ganti hari | Interaksi tidak menghasilkan item tambahan; sumber berstatus pasif hingga hari simulasi berganti. |
| 18 | Tumpukan Item Melebihi 20 (T29) | Menambahkan 5 item pada slot yang sudah berisi 18 item (total 23) | 2 unit mengisi slot hingga 20; 3 unit sisanya membuka slot kosong baru jika ada; jika tidak ada slot, aksi ditolak total. |
| 19 | Transfer Massal Antar Wadah (T30) | Menekan tombol "Pindah Semua" ke kontainer yang slot kosongnya tidak mencukupi | Transaksi ditolak secara utuh (atomic); tidak terjadi pemindahan parsial diam-diam; pesan kapasitas tampil. |
| 20 | Pembatalan Aksi Tahan (T32) | Menahan klik cangkul/pupuk/air lalu melepas tombol sebelum lingkaran penuh | Tidak ada sumber daya / biaya air yang dikonsumsi; progres aksi reset ke 0; pemain harus menekan ulang. |
| 21 | Pemulihan Posisi Tersangkut (T25) | Menekan "Kembali ke posisi aman" saat tersangkut di geometri | Posisi dan orientasi pemain dipindahkan ke titik aman spawn; inventaris dan progres game tidak berubah sedikit pun. |
| 22 | Variasi Frame Rate (T26) | Menjalankan karakter pada framerate terkunci 30 FPS vs 60 FPS vs 144 FPS | Jarak perpindahan per detik dan akumulasi waktu memasak/tumbuh identik karena diskalakan delta-time murni. |
| 23 | Raycast Oklusi Dinding (T27) | Mengarahkan pandangan ke wadah/tanaman yang berada di balik dinding tipis | Raycast mendeteksi collider penghalang; prompt interaksi tidak muncul; objek tidak dapat diakses. |
| 24 | Input Leak pada Penutup Modal (T28) | Menutup panel inventaris/buku dengan menekan tombol 'E' atau klik mouse | Input penutup dikonsumsi oleh UI; karakter di dunia tidak langsung memukul/memakai alat pada frame penutupan. |
| 25 | Hilang Fokus Aplikasi (T50, T18) | Pemain melakukan Alt-Tab atau memindahkan fokus jendela game ke aplikasi lain | Game secara otomatis berpindah ke status Pause; simulasi waktu, pertumbuhan, dan pergerakan dunia berhenti. |
| 26 | Save File Korup / Rusak (T17, T47) | Memuat save file dengan JSON terpotong, versi skema tidak cocok, atau ID item tak dikenal | Engine menolak me-load dunia korup; menampilkan dialog error dan opsi memuat checkpoint cadangan valid. |
| 27 | Interupsi Penulisan Save (T22, T49) | Proses penulisan save terputus mendadak (misal disk penuh atau proses mati saat write) | File checkpoint utama sebelumnya tetap utuh dan valid; game tidak mengklaim save baru berhasil jika write gagal. |
| 28 | Isolasi Pengaturan vs Save Progres (T52)| Mengubah FOV/volume audio, lalu memuat savegame lama dari hari sebelumnya | Nilai FOV dan volume tetap menggunakan pengaturan terbaru pemain; tidak tertimpa oleh data savegame lama. |
| 29 | Read-Only Directory & Spasi (T57, T58) | Build dijalankan pada direktori read-only (misal `C:\Program Files\Game\`) dan path berkarakter spasi | Seluruh penulisan save/konfigurasi diarahkan ke direktori profil pengguna (`user://`); game boot tanpa crash. |

---

## 4. Pemetaan Kasus Uji Menyeluruh (Tier 1 s/d Tier 4)

Sistem pengujian proyek Buku Resep 2045 dibagi ke dalam empat tingkatan (Tier) hierarkis untuk memastikan cakupan menyeluruh dari unit murni hingga integrasi end-to-end:

```
+-------------------------------------------------------------------------+
|                  TIER 4: REAL-WORLD & PLAYTEST SCENARIOS                |
|  - Full P0 Playthrough (Clean Profile, 10-15 min)                       |
|  - Mid-Game Checkpoint Resume & Interrupted Session Recovery            |
|  - Standalone Read-Only OS Environment & Display Scaling (T20, T56-T60) |
+-------------------------------------------------------------------------+
                                    ^
                                    |
+-------------------------------------------------------------------------+
|              TIER 3: CROSS-FEATURE & SUBSYSTEM INTEGRATION              |
|  - Inventory <-> Cooking Multi-Container Pooling & Fallback Refund      |
|  - Garden <-> World Bed Calendar Leap vs Real Simulation Time           |
|  - Kitchen <-> Book <-> Social State Synchronization                    |
|  - Save/Load Snapshot Isolation & Round-Trip World Restoration          |
+-------------------------------------------------------------------------+
                                    ^
                                    |
+-------------------------------------------------------------------------+
|              TIER 2: BOUNDARY, CAPACITY & CONCURRENCY CASES             |
|  - Slot & Stack Limits (12 Slots, 20 Units, Atomic Overflow)            |
|  - Threshold Boundaries (Nutrient 20/100, Moisture 30/60/80)           |
|  - Input De-bouncing & Rapid Spamming Rejections (T04, T12, T44)        |
|  - Modal UI Input Concurrency & Context Stack Isolation                 |
+-------------------------------------------------------------------------+
                                    ^
                                    |
+-------------------------------------------------------------------------+
|              TIER 1: FEATURE COVERAGE & ATOMIC UNIT TESTS               |
|  - 60 Core Acceptance Tests (T01 - T60) from docs/TEST_PLAN.md          |
|  - 8 Documentation & Asset Consistency Checks (DOC-T01 - DOC-T08)      |
|  - 12 Thematic Post-P0 Karhutla Verification Cases (EV-T01 - EV-T12)   |
+-------------------------------------------------------------------------+
```

### 4.1. Tier 1: Feature Coverage & Unit Tests

Mencakup seluruh 60 kasus uji P0 (`T01`–`T60`), kasus uji audit dokumen (`DOC-T01`–`DOC-T08`), dan kasus uji event pasca-P0 (`EV-T01`–`EV-T12`):

#### 4.1.1. Kasus Inti P0 (T01 – T60)
1. **T01 (Buku & Tracker):** Game baru -> Buka buku -> Tekan Lacak -> Tutup. *Expected:* Tracker atas memunculkan resep dan 3 kebutuhan tanpa centang selesai.
2. **T02 (Ketersediaan Awal):** Ambil jagung sebelum melacak -> Buka buku dan lacak. *Expected:* Jagung langsung terhitung (1/1) tanpa perlu ambil ulang.
3. **T03 (Toggle Tracker):** Lacak -> Berhenti melacak -> Buka lagi. *Expected:* Item dan status progres tidak berubah; hanya status pin tracker yang berganti.
4. **T04 (Anti-Duplikasi Pickup):** Spam tombol E pada wadah awal / sumber jagung. *Expected:* Item diberikan tepat 1 kali; sumber berubah 1 kali; tidak ada duplikasi.
5. **T05 (Pencegahan Panen Penuh):** Tas tidak muat bayam + benih -> Panen. *Expected:* Panen ditolak; tanaman siap panen dan nutrisi tanah tidak berubah.
6. **T06 (Pemupukan Area):** Isi 4 titik tanam -> Pupuk petak 1 kali. *Expected:* 1 pupuk dikonsumsi; nutrisi petak menjadi 100 dan berlaku untuk semua titik.
7. **T07 (Penyiraman Cukup):** Siram petak dengan kelembapan >= 60. *Expected:* Tidak membuang air; pesan kondisi cukup; transaksi ditolak.
8. **T08 (Penanaman Tanah Belum Siap):** Tanam pada tanah belum gembur/belum diberi pembenah. *Expected:* Ditolak dengan alasan; benih tidak berkurang.
9. **T09 (Paket Cadangan Benih):** Fixture: benih habis, tidak ada tanaman, starter container sudah diambil. *Expected:* Cadangan aktif dan dapat diambil jika tas muat.
10. **T10 (Validasi Bahan Kurang):** Bahan kurang 1 -> Tekan Siapkan di dapur. *Expected:* Tidak ada reservasi / job / mutasi; bahan yang kurang disebutkan.
11. **T11 (Agregasi Tas + Peti):** Bahan dibagi di tas dan peti -> Periksa buku & dapur. *Expected:* Kedua panel menampilkan total yang sama; reservasi mengambil tas dulu baru peti.
12. **T12 (Anti-Duplikasi Dapur):** Klik Siapkan/Mulai berulang kali secara cepat. *Expected:* Hanya satu Job ID dibuat; satu reservasi; satu output hidangan.
13. **T13 (Pembatalan Persiapan):** Bahan direservasi -> Batal sebelum memasak. *Expected:* Total bahan kembali utuh ke kontainer asal; tidak ada bahan hilang.
14. **T14 (Persistensi Dapur Jeda):** Simpan saat tanaman tumbuh dan job dapur dijeda -> Keluar -> Load. *Expected:* Waktu tanaman/job, reservasi, alat pulih persis; tidak bertambah saat offline.
15. **T15 (Output Tertahan Tas Penuh):** Selesaikan job dengan tas penuh. *Expected:* Output tetap di dapur, resep selesai; hidangan bisa diambil saat tas longgar.
16. **T16 (Roundtrip State Penuh):** Main hingga berbagi -> Simpan -> Tutup -> Buka -> Lanjutkan. *Expected:* Seluruh state (buku, meal_used, hari, petak, posisi aman) konsisten.
17. **T17 (Penanganan Save Korup):** Rusakkan file checkpoint fixture -> Muat game. *Expected:* Engine menolak memuat data korup; tawarkan checkpoint cadangan valid.
18. **T18 (Isolasi Input Modal):** Tahan gerak/klik -> Buka/tutup panel -> Ubah fokus jendela. *Expected:* Dunia berhenti saat modal aktif; input tidak bocor ke dunia.
19. **T19 (Pengulangan Resep Selesai):** Buat resep yang sudah selesai sekali lagi. *Expected:* Jumlah masakan bertambah 1; centang resep tetap satu.
20. **T20 (Distribusi Offline Standalone):** Jalankan build tanpa engine editor dan tanpa jaringan. *Expected:* Aset lengkap; loop selesai; tidak ada panggilan internet.
21. **T21 (Skala UI & FOV):** Ubah FOV dan skala UI pada berbagai resolusi. *Expected:* Tombol dan prompt tetap terlihat jelas tanpa terpotong.
22. **T22 (Interupsi Tulis Save):** Matikan proses saat penulisan file save berlangsung. *Expected:* Checkpoint valid sebelumnya dapat dipulihkan; tidak ada save korup yang diakui sukses.
23. **T23 (Baseline Setup Engine):** Buka proyek pada Godot versi stabil yang dikunci. *Expected:* Versi/renderer cocok; proyek terbuka tanpa dependency hilang.
24. **T24 (Smoke Run Level):** Jalankan main scene awal dan inspeksi spawn/map. *Expected:* Tidak ada error penghambat; spawn di ruang valid; landmark dikenali.
25. **T25 (Collision & Recovery):** Jelajahi seluruh rute pekarangan; picu recovery aman. *Expected:* Tidak ada tembus dinding; recovery memulihkan posisi tanpa mutasi item.
26. **T26 (Independensi Frame Rate):** Bandingkan pergerakan dan timer pada FPS 30 vs 60 vs 144. *Expected:* Kecepatan gerak dan akumulasi waktu identik berbasis delta.
27. **T27 (Raycast & Oklusi):** Bidik objek di luar jangkauan dan di balik dinding. *Expected:* Objek terhalang tidak terpilih; prompt muncul hanya bila valid dan terlihat.
28. **T28 (Navigasi Lapisan UI):** Buka buku/tas/dapur berturut-turut -> Tutup dengan Esc. *Expected:* Panel ditutup berlapis; mouse pulih; tidak ada aksi dunia tak sengaja.
29. **T29 (Batas Tumpukan 20):** Isi tumpukan mendekati 20 lalu tambah melebihi batas. *Expected:* Kelebihan item membuka slot baru; jika slot habis, transaksi ditolak utuh.
30. **T30 (Transfer Utuh & Tolak Parsial):** Transfer batch ke tujuan yang kapasitasnya kurang. *Expected:* Tidak ada transfer parsial diam-diam; transaksi ditolak 100%.
31. **T31 (Kesiapan Tanpa Memasak):** Kumpulkan bahan lengkap -> Periksa buku resep. *Expected:* Status resep "Siap dimasak", belum centang selesai; transfer tas-peti tidak ubah total.
32. **T32 (Pembatalan Aksi Tahan):** Tahan klik cangkul/pupuk/air lalu lepas sebelum selesai. *Expected:* Progres aksi reset; tidak ada biaya alat/sumber daya yang keluar.
33. **T33 (Pencegahan Boros Pupuk/Air):** Gunakan pupuk saat nutrisi cukup / isi air melebihi batas 10. *Expected:* Aksi ditolak; kapasitas tidak tembus batas maksimal; sumber daya aman.
34. **T34 (Kemajuan Tumbuh Efektif):** Tanam benih dan ukur kemajuan tiap tahap sesuai CONTENT. *Expected:* Waktu tumbuh tepat 180s (30s/60s/90s); seluruh tanaman membaca status petak.
35. **T35 (Jeda Nutrisi/Air Tanaman):** Biarkan petak kering / kurang nutrisi saat tanaman tumbuh. *Expected:* Tumbuh berhenti; tidak mundur dan tidak mati; lanjut saat dirawat.
36. **T36 (Panen & Penanaman Ulang):** Panen bayam berhasil lalu tanam kembali. *Expected:* 1 bayam + 1 benih masuk tas; nutrisi tanah -5; titik kembali siap ditanami.
37. **T37 (Reset Harian Sumber Liar):** Ambil jagung -> coba ambil lagi -> istirahat di ranjang. *Expected:* Tidak dapat diambil dua kali pada hari sama; pulih setelah bangun tidur.
38. **T38 (Kondisi Cadangan Ditolak):** Masih ada benih di peti / tanaman hidup -> minta cadangan. *Expected:* Cadangan ditolak; UI menjelaskan lokasi persediaan yang masih ada.
39. **T39 (Kalender Istirahat vs Dapur):** Istirahat di ranjang saat job dapur aktif. *Expected:* Istirahat ditolak; hari bertambah hanya saat dapur tidak aktif; tanaman tidak lompat.
40. **T40 (Refund Dapur Kontainer Penuh):** Reservasi dari tas -> penuhi tas via fixture -> batalkan persiapan. *Expected:* Bahan dialihkan ke peti; jika peti penuh, dialihkan ke refund aman dapur.
41. **T41 (Efek Pengaturan Panas):** Jalankan panas Rendah (0.5x), Sedang (1.0x), Tinggi (0.0x). *Expected:* Kemajuan sesuai pengali; panas Tinggi memberi pesan dan tidak merusak bahan.
42. **T42 (Jeda Panel Dapur Tertutup):** Tutup dapur saat memasak -> tunggu di dunia -> buka kembali. *Expected:* Job tidak berjalan saat ditutup; status job paused; dapat dilanjutkan.
43. **T43 (Konsumsi Hidangan Makan):** Selesaikan hidangan lalu pilih aksi Makan. *Expected:* Jumlah hidangan -1; flag `meal_used` aktif; centang buku tetap.
44. **T44 (Berbagi Hidangan ke Warga):** Bagikan masakan dari tas/peti -> konfirmasi / batal. *Expected:* Batal tidak makan hidangan; konfirmasi kurangi 1 hidangan; dialog penutup tampil.
45. **T45 (Dialog & Akses Non-Blocking):** Lewati NPC -> panen & masak -> bicara ke NPC belakangan. *Expected:* Sumber tidak terkunci oleh dialog; teks petunjuk tetap relevan dan ramah.
46. **T46 (Verifikasi Snapshot Penuh):** Bandingkan state sebelum save dan sesudah load. *Expected:* Seluruh variabel dinamis pulih identik (refund, flag, output, hari, alat).
47. **T47 (Validasi Versi & Skema Save):** Coba muat file save versi tidak cocok / atribut asing. *Expected:* Validasi envelope menolak data; dunia aktif tidak ditimpa state korup.
48. **T48 (Hirarki Checkpoint Lanjutkan):** Ada manual save lama dan autosave baru. *Expected:* Tombol Lanjutkan memilih checkpoint terbaru; menu Muat menampilkan keduanya.
49. **T49 (Penanganan Gagal Simpan):** Simulasikan disk write-protected saat memilih Simpan. *Expected:* Pesan gagal simpan muncul; game tidak keluar seolah-olah sukses.
50. **T50 (Idempotesi Pengambilan Output):** Load berulang kali saat output dapur siap -> ambil 1x. *Expected:* Output hanya masuk sekali; slot hasil bersih; tidak ada duplikasi hidangan.
51. **T51 (Aksesibilitas Navigasi Keyboard):** Navigasikan seluruh menu hanya dengan keyboard / gamepad. *Expected:* Fokus visual terlihat jelas; urutan tabulasi logis; tidak ada trap input.
52. **T52 (Pemisahan Pengaturan Audio/Display):** Ubah volume audio & FOV -> restart -> load game lama. *Expected:* Pengaturan audio/FOV tetap yang terbaru; tidak tertimpa oleh file savegame.
53. **T53 (Dialog Konfirmasi Game Baru/Keluar):** Buka Game Baru saat ada progres belum disimpan. *Expected:* Muncul konfirmasi; tombol Batal mempertahankan permainan tanpa kehilangan data.
54. **T54 (Antrean Notifikasi UI):** Ambil beberapa item secara beruntun dan lakukan aksi gagal. *Expected:* Notifikasi teks tertata rapi; tidak menutupi reticle pandang atau prompt penting.
55. **T55 (Keterbacaan Visual & Aset):** Amati tanaman, alat, dan landmark pada latar terang/gelap. *Expected:* Siluet jelas; teks memiliki kontras cukup; tidak ada tekstur hilang/pink.
56. **T56 (Benchmark Performa Rute Standar):** Jalankan rute dari rumah ke kebun dan bambu. *Expected:* Frame time stabil; tidak ada stutter ekstrem pada pemuatan aset graybox.
57. **T57 (Path Spasi & User Profile Directory):** Jalankan build pada path folder mengandung spasi. *Expected:* Game menemukan seluruh resource; file save diarahkan ke direktori user OS.
58. **T58 (Folder Instalasi Read-Only):** Kunci hak akses folder instalasi menjadi Read-Only. *Expected:* Game tetap dapat menyimpan data di `user://` tanpa crash permission.
59. **T59 (Kebijakan Retensi Uninstaller):** Jalankan uninstall game pada sistem desktop. *Expected:* File biner terhapus bersih; savegame di folder profil dipertahankan/diberi opsi.
60. **T60 (Kelengkapan Paket & Lisensi):** Audit isi folder paket rilis build. *Expected:* README, informasi lisensi, atribusi pihak ketiga lengkap; tanpa file sampah/secret.

#### 4.1.2. Kasus Audit Dokumentasi (DOC-T01 – DOC-T08)
- **DOC-T01 (Kelengkapan):** Struktur paket markdown sesuai README.
- **DOC-T02 (Resolusi Tautan):** Seluruh tautan relatif MD dan SVG valid.
- **DOC-T03 (Keputusan Inti):** Engine Godot, first-person, satu resep, konsisten di semua file.
- **DOC-T04 (Kontrak Data):** Keselarasan angka bahan, slot, dan parameter di CONTENT vs PRD/PROTOTYPE.
- **DOC-T05 (Keterlacakan):** Pemetaan FR01–FR24 terhadap task dan test ID.
- **DOC-T06 (Status & Arsip):** Format ringkas PROJECT_STATUS dan arsip per task completed_tasks.
- **DOC-T07 (Format Teks):** Bebas file kosong, no code fencing leaks, UTF-8 bersih.
- **DOC-T08 (Integritas Paket):** SVG wireframe valid dan render visual tidak overflow.

#### 4.1.3. Kasus Event Tematik Karhutla (EV-T01 – EV-T12)
- **EV-T01:** Aktivasi event dengan/tanpa prasyarat P0 selesai -> Penolakan/penerimaan valid.
- **EV-T02:** Judul game + format event "Buku Resep 2045: Karhutla" (bukan chapter).
- **EV-T03:** Jalur kebun terdampak api aktif; perubahan rute akses pos air.
- **EV-T04:** Respons stasiun pemadam api; aksi batal tidak menciptakan suplai liar.
- **EV-T05:** Suplai air pemadaman deterministik; penyiram kebun tidak menjadi alat sakti.
- **EV-T06:** Batas penyebaran api terkendali; rumah dan pekarangan utama aman.
- **EV-T07:** Pause / menu selama event menjeda seluruh simulasi api dan waktu.
- **EV-T08:** Save/load selama status warning, active, contained, recovery pulih presisi.
- **EV-T09:** Tindakan mulsa / perlindungan air sesuai angka parameter sains CONTENT.
- **EV-T10:** Memasak dan berbagi dalam kondisi event mencatat progres event tersendiri.
- **EV-T11:** Event selesai meninggalkan jejak map permanen; load idempotent.
- **EV-T12:** Performa visual api stabil; loop dasar dan save P0 tidak rusak.

---

### 4.2. Tier 2: Boundary & Corner Cases

Menguji ketahanan batas sistem terhadap nilai ekstrem, limit memori, kapasitas kontainer, dan timing:

1. **Batas Kapasitas Slot & Tumpukan (INV-001):**
   - Batas slot: Tepat 12 slot tas dan 12 slot peti. Mencoba memasukkan jenis item ke-13 saat 12 slot terisi penuh harus ditolak secara deterministik.
   - Batas tumpukan: Nilai tumpukan 19 + 1 -> 20 (slot tetap satu). Nilai tumpukan 20 + 1 -> membuka slot baru dengan isi 1.
   - Nol item (zero quantity): Item dengan kuantitas 0 harus segera menghapus entri slot dan membebaskan indeks slot.
2. **Ambang Ambigu Pertanian (GARD-001, GARD-002):**
   - Ambang Kelembapan:
     - Kelembapan = 29.9 -> status "Kering", tanaman berhenti tumbuh.
     - Kelembapan = 30.0 -> status "Lembap", tanaman mulai tumbuh.
     - Kelembapan = 59.9 -> boleh disiram (aksi valid).
     - Kelembapan = 60.0 -> aksi siram ditolak ("Kondisi cukup").
     - Kelembapan pasca-siram = 80.0 (nilai cap maksimum siram).
   - Ambang Nutrisi:
     - Nutrisi = 19.9 -> status "Perlu pupuk", tanaman berhenti tumbuh.
     - Nutrisi = 20.0 -> status "Cukup", tanaman mulai tumbuh, pemupukan ditolak.
     - Nutrisi pasca-pupuk = 100.0 (nilai cap maksimum pupuk).
     - Biaya panen = -5 per titik berhasil dipanen; nilai nutrisi clamped pada minimum 0.
   - Ambang Waktu Tumbuh:
     - Waktu 29.99s -> tahap benih.
     - Waktu 30.00s -> transisi instan ke tahap tunas.
     - Waktu 89.99s -> tahap tunas.
     - Waktu 90.00s -> transisi instan ke tahap tumbuh.
     - Waktu 179.99s -> tahap tumbuh.
     - Waktu >= 180.00s -> siap panen; timer di-clamp pada 180s dan tidak bertambah lagi.
3. **Batas Kontrol Dapur (COOK-001, COOK-002):**
   - Timer Tahan Siapkan: Tahan 3.99s lalu lepas -> progres tertahan pada 3.99s (tidak reset ke 0, tetapi belum bertransisi ke status ready). Tahan mencapai 4.00s -> transisi ke tombol "Mulai memasak".
   - Timer Memasak Efektif: Tepat 30 detik pada Sedang (1.0x). Pada Rendah (0.5x), butuh 60 detik waktu nyata. Pada Tinggi (0.0x), timer tidak maju sama sekali.
4. **Batas Penyiram Air (WORLD-001):**
   - Kapasitas air penyiram: Clamped pada 10 unit. Pemakaian per siram = 2 unit. Ketika sisa air = 1 unit, aksi siram ditolak ("Air tidak cukup, isi di sumber pekarangan").
5. **Anti-Spam & Konkurensi Input:**
   - 10 klik tombol E dalam rentang 100ms hanya mengeksekusi 1 transaksi state machine.

---

### 4.3. Tier 3: Cross-Feature Integration Tests

Menguji interaksi antarsubsistem independen agar tidak terjadi inkonsistensi data:

1. **Integrasi Inventaris <-> Dapur (Reservasi Lintas Kontainer & Safe Refund):**
   - Skenario: Resep butuh 3 bayam. Pemain memiliki 2 bayam di tas dan 5 bayam di peti.
   - Verifikasi:
     - Buku menampilkan ketersediaan 7/3.
     - Saat "Siapkan" ditekan: 2 bayam diambil dari tas (slot indeks terendah), 1 bayam diambil dari peti.
     - Data reservasi mencatat origin: `{from: "bag", count: 2}, {from: "chest", count: 1}`.
     - Jika pemain membatalkan: 2 dikembalikan ke tas, 1 dikembalikan ke peti.
     - Jika sebelum dibatalkan peti dipenuhi item lain via fixture: 1 bayam yang gagal masuk peti dialihkan ke `kitchen_refund_container` persisten.
2. **Integrasi Pertanian <-> Kalender Istirahat Ranjang:**
   - Skenario: Tanaman berada di detik ke-60 (tunas), kelembapan 50. Pemain pergi tidur di ranjang (`bed_home`).
   - Verifikasi:
     - Indeks hari bertambah dari 1 ke 2.
     - Waktu simulasi tanaman TETAP di detik ke-60 (tidak melonjak 720 detik).
     - Kelembapan petak TETAP di 50 (penguapan tidak disimulasikan secara offline).
     - Jagung liar yang kemarin dipanen sekarang pulih dan siap dipetik kembali.
3. **Integrasi Dapur <-> Kalender Istirahat Ranjang:**
   - Skenario: Job memasak sedang berlangsung di status cooking / preparing. Pemain berinteraksi dengan kasur.
   - Verifikasi: Dialog kasur menolak aksi istirahat ("Selesaikan atau batalkan proses di dapur terlebih dahulu").
4. **Integrasi Buku Resep <-> Dapur <-> Sosial Tetangga:**
   - Skenario: Memasak selesai -> Hidangan berada di slot output.
   - Verifikasi:
     - Status resep di buku otomatis tercentang selesai (`recipe_completed = true`), counter masakan = 1.
     - Pemain mengambil hidangan ke tas -> Berbicara dengan Tetangga.
     - Muncul opsi dialog "Berbagi hidangan".
     - Konfirmasi dialog mengonsumsi 1 hidangan dari tas -> Flag `meal_used = true`.
     - Pengalaman P0 dinyatakan tamat sempurna (P0 Loop Completed).
5. **Integrasi Save/Load <-> Seluruh Subsistem (Snapshot Round-Trip):**
   - Skenario: Game disimpan saat:
     - Pemain berada di koordinat X=12.5, Y=1.0, Z=-4.2.
     - Tas terisi 4 item, peti terisi 2 item.
     - Petak memiliki 1 tunas (detik 45), 1 siap panen (detik 180), nutrisi 95, kelembapan 72.
     - Dapur memiliki job yang dijeda pada detik ke-15 (panas Rendah).
     - Jagung liar sudah dipanen hari ini.
   - Verifikasi pasca-Load:
     - Seluruh nilai di atas terekonstruksi persis 100% tanpa ada pergeseran waktu atau kehilangan state.

---

### 4.4. Tier 4: Real-World Scenarios, Usability & Stress Scenarios

Menguji sistem dalam kondisi operasional nyata pemain dan ketahanan lingkungan:

1. **Playthrough End-to-End P0 (Profil Bersih):**
   - Menjalankan alur lengkap dari game baru tanpa cheat/fixture:
     - Spawn -> Baca buku resep -> Buka wadah awal pekarangan -> Cangkul petak -> Beri pembenah -> Tanam benih -> Beri pupuk -> Ambil air di sumur -> Siram petak -> Jalan ke kebun ambil jagung -> Jalan ke bambu ambil temu kunci -> Kembali ke pekarangan panen bayam -> Masuk dapur -> Siapkan bahan -> Mulai masak (panas Sedang) -> Ambil hidangan -> Makan / Bagikan -> Simpan game -> Muat game.
   - Target observasi: Durasi 10–15 menit, kejelasan prompt, tidak ada softlock atau instruksi membingungkan.
2. **Simulasi Kegagalan Daya / Crash Saat Penulisan Save:**
   - Memutus proses / melempar error I/O tiruan tepat di tengah proses serialisasi JSON savegame.
   - Verifikasi: File save sementara `.tmp` dibuang; file utama `save_checkpoint.json` tetap utuh pada versi sebelumnya; aplikasi menampilkan pesan error yang ramah.
3. **Uji Lingkungan Portabilitas & Read-Only OS:**
   - Menempatkan build game pada folder berkarakter spasi (`C:\Game Labs 2045\Buku Resep\`) dengan atribut folder di-set Read-Only.
   - Verifikasi: Game dapat dijalankan tanpa crash; seluruh penulisan save, log, dan konfigurasi diarahkan ke `%APPDATA%\Godot\app_userdata\Buku Resep 2045\` (`user://`).
4. **Stress Test Input & Konkurensi Layar:**
   - Melakukan navigasi cepat antara keyboard, mouse, membuka menu pause (Esc), membuka tas (Tab/I), membuka buku (B), dan mengecilkan jendela aplikasi (minimize/unfocus) secara acak.
   - Verifikasi: Engine tidak melempar null pointer reference; status mouse ter-capture kembali dengan benar saat kembali ke dunia; game ter-pause otomatis saat kehilangan fokus jendela.

---

## 5. Arsitektur Test Harness & Runner untuk Godot

Sesuai arahan `AGENTS.md` §4 dan §8 (*"Hindari plugin/add-on sebelum ada kebutuhan konkret"*), implementasi pengujian otomatis dalam proyek ini harus mengutamakan harness mandiri (custom test harness) yang ringan, deterministik, dan dapat dijalankan secara headless melalui command line tanpa ketergantungan plugin pihak ketiga yang berat.

### 5.1. Kebutuhan Eksekusi Headless & CLI

Engine Godot 4.x menyediakan mode `--headless` untuk menjalankan skrip tanpa membuka antarmuka GUI jendela render. Arsitektur test harness dirancang dengan struktur pemanggilan berikut:

```bash
# Perintah eksekusi seluruh suite pengujian otomatis headless
godot --headless --script res://tests/test_runner.gd
```

**Karakteristik & Kontrak Runner CLI:**
1. **Exit Code Standar:**
   - `0`: Seluruh pengujian berhasil (PASS).
   - `1`: Minimal satu kasus uji gagal (FAIL / CRASH).
2. **Keluaran Konsol Terstruktur:**
   - Format laporan konsol menggunakan gaya TAP (Test Anything Protocol) atau laporan ringkas standar CI:
     ```text
     [RUNNING] Suite: InventoryTestSuite ...
       [PASS] test_stack_limit_exceeded
       [PASS] test_atomic_transfer_insufficient_space
     [RUNNING] Suite: GardenTestSuite ...
       [PASS] test_watering_threshold_rejected_at_60
       [PASS] test_harvest_rejected_when_bag_full
     ==================================================
     TOTAL: 42 | PASSED: 42 | FAILED: 0 | DURATION: 1.24s
     RESULT: ALL TESTS PASSED (Exit Code: 0)
     ```
3. **Eksekusi Deterministik Frame:**
   - Untuk pengujian yang memerlukan simulasi waktu (misal pertumbuhan tanaman atau timer memasak), harness tidak boleh menggunakan `OS.delay_msec()` yang membuang waktu nyata.
   - Harness memanggil metode pembaruan internal secara diskret:
     `garden_manager.tick(180.0)` atau memajukan frame engine dengan `get_tree().process_frame`.

### 5.2. Arsitektur Assertion Library & Fixture Manager

Harness pengujian dibangun di atas tiga komponen inti di folder `res://tests/`:

```
res://tests/
├── test_runner.gd         # Skrip entry point utama eksekusi CLI headless
├── assertions.gd          # Pustaka asersi (assert_eq, assert_true, assert_null, dll.)
├── fixture_manager.gd     # Penyedia profil awal & snapshot kondisi ekstrem
├── unit/                  # Pengujian unit murni logika domain (tanpa render)
│   ├── test_inventory.gd
│   ├── test_garden.gd
│   ├── test_cooking.gd
│   └── test_save_envelope.gd
└── integration/           # Pengujian integrasi lintas sistem
    ├── test_kitchen_inventory.gd
    ├── test_day_cycle_garden.gd
    └── test_save_load_roundtrip.gd
```

#### 5.2.1. Pustaka Asersi (`assertions.gd`)
Menyediakan pengecekan kontrak ketat dengan pesan diagnostik yang jelas saat gagal:
- `assert_eq(actual, expected, message)`
- `assert_ne(actual, expected, message)`
- `assert_true(condition, message)`
- `assert_false(condition, message)`
- `assert_null(object, message)`
- `assert_not_null(object, message)`
- `assert_in_range(val, min_val, max_val, message)`
- `assert_signal_emitted(emitter, signal_name, message)`

#### 5.2.2. Penyedia Fixture (`fixture_manager.gd`)
Menyediakan state terkontrol untuk menguji edge cases tanpa harus memainkan game secara manual:
- `get_clean_profile()`: Profil standar game baru (tas kosong, petak belum diolah, hari 1).
- `get_full_bag_fixture()`: Tas terisi penuh 12 slot dengan tumpukan 20 item acak.
- `get_cooking_paused_fixture()`: Job dapur sedang berada pada tahap memasak detik ke-15 status `paused`.
- `get_dry_nutrient_depleted_fixture()`: Petak dengan tanaman bayam tetapi nutrisi = 0, kelembapan = 0.
- `get_corrupt_save_fixture()`: Data JSON save yang sengaja dirusak sintaks atau versinya.

### 5.3. Evaluasi GUT (Godot Unit Test) vs Custom Harness

| Aspek | Custom Headless Runner (Rekomendasi) | GUT Framework (Plugin Pihak Ketiga) |
|---|---|---|
| **Kepatuhan AGENTS.md** | Sangat Patuh (tanpa dependensi add-on eksternal) | Membutuhkan dependensi add-on pihak ketiga |
| **Ukuran & Kompleksitas** | Sangat Ringan (<300 baris GDScript terfokus) | Besar (~beberapa MB skrip & resource editor) |
| **Kecepatan Headless CLI** | Instan (<1-2 detik untuk puluhan tes) | Cepat, namun memiliki overhead plugin |
| **Pemeliharaan** | Sepenuhnya dikontrol oleh tim proyek | Terikat pada versi kompatibilitas add-on GUT |
| **Integrasi CI / Scripting**| Mudah diintegrasikan dengan exit code OS | Memiliki CLI runner bawaan |

**Kesimpulan:** Menggunakan **Custom Headless Test Harness** (`test_runner.gd`) sebagai arsitektur default uji otomatis P0. Jika di kemudian hari tim memutuskan menggunakan GUT untuk kebutuhan visual GUI testing di editor, transisi dapat dilakukan dengan mudah karena modul pengujian memisahkan logika domain dari scene.

---

## 6. Kepatuhan Aturan Kerja AGENTS.md

Kepatuhan terhadap aturan pencatatan dan siklus kerja agent adalah kewajiban mutlak pada proyek Buku Resep 2045. Bagian ini merangkum aturan kepatuhan yang harus diikuti oleh setiap agent pengembang:

### 6.1. Aturan Penomoran & Penamaan Laporan `docs/completed_tasks/`

1. **Format Penamaan File:**
   - Wajib menggunakan slug huruf kecil, angka, dan tanda hubung: `NNN-nama-task-dengan-huruf-kecil.md`.
2. **Urutan Penomoran Monotonik:**
   - Nomor arsip harus selalu bertambah berdasarkan nomor terbesar yang sudah ada + 1.
   - Format nomor minimal tiga digit (`NNN`).
   - Karena laporan `001-paket-dokumentasi-v0-2.md` sudah ada sebagai nomor 001, maka laporan berikutnya untuk task implementasi pertama (`SETUP-001`) **WAJIB MENGGUNAKAN NOMOR `002-`** (contoh: `002-setup-proyek-godot.md`).
   - Nomor tidak boleh di-reset saat berganti milestone.
   - Nomor yang pernah digunakan tidak boleh dipakai ulang.
3. **Struktur Isi Laporan (Wajib Mengikuti `TEMPLATE.md`):**
   Laporan harus memuat 10 bagian wajib tanpa ada bagian yang sengaja dikosongkan (jika tidak relevan, tulis "Tidak berlaku" beserta alasannya):
   - `## Identitas` (ID task, Judul, Tanggal, Pelaksana, Tahap, Status, Versi build)
   - `## Tujuan dan pemicu`
   - `## Ruang lingkup`
   - `## Perubahan dan perilaku akhir`
   - `## File yang ditambahkan atau diubah` (tabel path relatif, jenis perubahan, tujuan)
   - `## Verifikasi yang benar-benar dilakukan` (tabel pemeriksaan, input, tindakan, hasil nyata, status)
   - `## Kriteria selesai` (pemetaan bukti terhadap kriteria task)
   - `## Dampak, kompatibilitas dan keterbatasan`
   - `## Tindak lanjut dan handoff` (ID task berikutnya, prasyarat, acuan data)
   - `## Penutupan catatan` (konfirmasi pembaruan status dan tautan)

### 6.2. Aturan Integritas & Verifikasi Nyata (Anti-Fabrikasi)

1. **Status Kejujuran:**
   - *"Sudah ditulis"* $\neq$ *"sudah dijalankan"* $\neq$ *"sudah lolos uji"*.
   - Dilarang keras mengklaim hasil tes "Lulus" jika pengujian belum benar-benar dieksekusi di engine / lingkungan nyata.
   - Dilarang membuat commit hash fiktif, benchmark palsu, atau screenshot tiruan.
2. **Integritas Tes Gagal:**
   - Tes yang gagal tidak boleh dihapus atau dilemahkan asersinya hanya agar laporan tampak lulus.
   - Jika terjadi kegagalan/regresi, catat fakta reproduksi dan perbaiki kodenya, atau tandai task sebagai `TERHAMBAT`.

### 6.3. Format Pembaruan `docs/PROJECT_STATUS.md`

Setiap kali satu task selesai, agent wajib memperbarui dua bagian dalam `docs/PROJECT_STATUS.md`:
1. **Pekerjaan yang Sudah Selesai (`## Pekerjaan yang Sudah Selesai`):**
   - Tambahkan **satu bullet singkat** yang memuat ID task, nama ringkas, dan tautan markdown relatif ke laporan `completed_tasks/`.
   - Diurutkan secara kronologis dari awal ke terbaru.
   - Contoh entri berikutnya:
     `- [SETUP-001 — Setup engine Godot dan fondasi proyek](completed_tasks/002-setup-proyek-godot.md).`
2. **Deskripsi Status Pekerjaan Terakhir (`## Deskripsi Status Pekerjaan Terakhir`):**
   - **Ganti seluruh isinya** dengan kondisi terkini (bukan menambah sublaporan historis).
   - Target panjang: **150–300 kata**.
   - Wajib mencantumkan secara ringkas: Tanggal, Task terakhir, Keadaan fitur, Verifikasi nyata yang dilakukan, Kendala/keterbatasan, dan Langkah terdekat berikutnya.

### 6.4. Format Pembaruan `docs/TASKS.md`

1. Perbarui kolom status task yang bersangkutan pada tabel register menjadi `SELESAI`.
2. Cantumkan tautan relatif ke laporan arsip `completed_tasks/` pada kolom Laporan (contoh: `[002](completed_tasks/002-setup-proyek-godot.md)`).
3. Jika ada dependensi yang terhambat, ubah statusnya menjadi `TERHAMBAT` beserta catatan penjelas.
4. Jangan menyelesaikan seluruh milestone jika baru satu sub-task yang lulus.

---

## 7. Kriteria Gerbang (Gate Criteria) per Milestone & Task

Implementasi game mengikuti alur berurutan tanpa melompati dependensi. Tabel berikut mendefinisikan gerbang masuk, kriteria verifikasi wajib, dan gerbang keluar untuk setiap task:

| Milestone / Task ID | Nama Task | Prasyarat (In-Gate) | Kriteria Verifikasi Wajib (Verification Gate) | Status Keluar (Out-Gate / Deliverable) |
|---|---|---|---|---|
| **DOC-001** | Paket Dokumentasi v0.2 | Pembahasan desain awal | Audit tautan, konsistensi data CONTENT, 60 kasus uji P0 tercatat (`DOC-T01` s/d `DOC-T08`) | SELESAI (Laporan 001) |
| **SETUP-001** | Proyek Godot & Fondasi | DOC-001 disetujui | Proyek Godot stabil dapat dibuka tanpa error; renderer terkunci; README memuat cara run (`T23`, `T24`) | Proyek minimal bootable; Laporan 002 |
| **LVL-001** | Graybox Map & Spawn | SETUP-001 selesai | Graybox rumah, kebun, batas collision, titik spawn valid, recovery anchor berfungsi (`T24`, `T25`) | Scene 3D level dasar; Laporan 003 |
| **PLY-001** | Kendali First Person | LVL-001 selesai | Gerak WASD, pitch clamping, collision dinding, tidak tembus geometri, bebas variasi FPS (`T18`, `T25`, `T26`) | Player controller stabil; Laporan 004 |
| **INT-001** | Interaksi & Input Context | PLY-001 selesai | Raycast bidik, deteksi oklusi dinding, prompt E responsif, penutup modal tidak bocor ke dunia (`T18`, `T27`, `T28`) | Manager interaksi & context stack; Laporan 005 |
| **INV-001** | Inventaris & Transaksi | INT-001 selesai | Kamus 7 item CONTENT, 12 slot tas, 12 slot peti, stack 20, transfer batch atomik tolak parsial (`T04`, `T05`, `T29`, `T30`) | Modul inventaris & UI tas/peti; Laporan 006 |
| **BOOK-001** | Buku Resep & Pelacak | INV-001 selesai | Resep sayur bening, pin tracker HUD, hitungan ketersediaan gabungan tas+peti (`T01`, `T02`, `T03`, `T11`, `T31`) | UI buku & HUD tracker; Laporan 007 |
| **GARD-001** | Persiapan & Rawat Lahan | INV-001, BOOK-001 | 1 petak 4 titik; cangkul tahan 2s, pembenah prompt E; pupuk nutrisi -> 100; siram air -> 80 (`T06`, `T07`, `T08`, `T32`, `T33`) | Sistem petak & aksi lahan; Laporan 008 |
| **GARD-002** | Pertumbuhan & Panen | GARD-001 selesai | 4 tahap tumbuh (180s); jeda nutrisi/air; panen 1 bayam + 1 benih; nutrisi -5; tolak panen tas penuh (`T05`, `T34`, `T35`, `T36`) | Siklus tanam-tumbuh-panen utuh; Laporan 009 |
| **WORLD-001** | Sumber Dunia & Kalender | GARD-002 selesai | Jagung & temu kunci panen 1x/hari; istirahat kasur majukan hari & pulihkan sumber; cadangan softlock (`T09`, `T37`, `T38`, `T39`) | Node sumber & siklus hari; Laporan 010 |
| **COOK-001** | Reservasi & Persiapan | WORLD-001, BOOK-001 | Tahan Siapkan 4s; reservasi tas->peti; batal kembalikan bahan utuh; fallback ke refund container (`T10`, `T11`, `T12`, `T13`, `T40`) | Logika persiapan dapur; Laporan 011 |
| **COOK-002** | Pemasakan & Output | COOK-001 selesai | Masak 30s; kontrol 3 level panas; jeda panel tutup; output commit 1 masakan; centang resep (`T12`, `T15`, `T19`, `T41`, `T42`, `T50`) | Alur dapur masak lengkap; Laporan 012 |
| **SOC-001** | Warga & Dialog Penutup | COOK-002 selesai | Dialog tetangga; berbagi hidangan; makan hidangan; penetapan flag `meal_used`; P0 selesai (`T43`, `T44`, `T45`) | Dialog NPC & ending P0; Laporan 013 |
| **SAVE-001** | Persistensi Terpadu | SOC-001 selesai | Serialisasi envelope versioned; safe write `.tmp`; pulihkan seluruh state; fallback data korup (`T14`, `T16`, `T17`, `T22`, `T46`-`T50`) | Save/load system tangguh; Laporan 014 |
| **UI-001** | Antarmuka & Kenyamanan | SAVE-001 selesai | Menu pause; pengaturan FOV/audio/sensitivitas terpisah; dialog konfirmasi; navigasi keyboard (`T18`, `T21`, `T28`, `T51`-`T54`) | Sistem UI terpadu; Laporan 015 |
| **ART-001** | Visual & Audio Dasar | UI-001 selesai | Model/tekstur terbaca jelas; pencahayaan hangat; SFX aksi utama; lisensi aset tercatat (`T55`, `T56`) | Aset visual & audio terintegrasi; Laporan 016 |
| **QA-001** | Gerbang Penerimaan P0 | ART-001 selesai | Playthrough lengkap 10-15 menit profil bersih & lanjutan; seluruh tes T01-T60 diverifikasi nyata | **GERBANG GAMEPLAY P0 TERPENUHI**; Laporan 017 |
| **DIST-001** | Ekspor Desktop Mandiri | QA-001 lulus | Build biner mandiri OS target; berjalan offline tanpa editor; save di `user://` (`T20`, `T57`, `T58`) | Paket executable mandiri; Laporan 018 |
| **DIST-002** | Installer & Distribusi | DIST-001 selesai | Installer desktop; petunjuk install/uninstall; lisensi lengkap; retensi save (`T59`, `T60`) | **GERBANG DISTRIBUSI P0 TERPENUHI**; Laporan 019 |
| **EV-001 - EV-QA-001**| Event Karhutla (Pasca-P0)| QA-001 / DIST-001 | Verifikasi kasus `EV-T01` s/d `EV-T12`; simulasi api, jalur air, sains sederhana | Jalur event tematik terverifikasi |

---

## 8. Panduan Langkah Terdekat

1. **Inisialisasi `SETUP-001`**: Agent berikutnya harus membaca laporan survei ini, mengonfirmasi engine Godot stabil pada lingkungan eksekusi, membuat project structure minimal, mengunci renderer, dan menyiapkan skrip dasar `test_runner.gd`.
2. **Kepatuhan Pencatatan Task 002**: Laporan penutupan `SETUP-001` wajib menggunakan berkas `docs/completed_tasks/002-setup-proyek-godot.md` (atau slug setara yang relevan), memperbarui `docs/PROJECT_STATUS.md` dengan bullet baru bertautan dan deskripsi status terkini (150-300 kata), serta memperbarui `docs/TASKS.md`.
