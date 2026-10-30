# Laporan Survei Spesifikasi Teknis Lengkap — Buku Resep 2045
**Dokumen:** `survey_report.md`  
**Disusun oleh:** `spec_miner_survey_1` (Specification Miner)  
**Tanggal:** 27 Oktober 2026  
**Target:** Penyiapan Implementasi Berurutan SETUP-001 hingga QA-001  
**Sumber Otoritatif:** `PRD.md`, `docs/TASKS.md`, `docs/CONTENT.md`, `docs/PROTOTYPE.md`, `docs/UI_UX.md`, `docs/LEVEL_DESIGN.md`, `docs/ART_DIRECTION.md`, `docs/EVENT_DESIGN.md`, `docs/TEST_PLAN.md`, `AGENTS.md`, `README.md`.

---

## 1. Ringkasan Eksekutif dan Tujuan Survei

Survei ini melakukan ekstraksi dan penataan menyeluruh terhadap seluruh spesifikasi produk, aturan mekanik game, inventaris fitur per task, batas modul dan kontrak antarmuka, kamus ID/angka numerik, serta rantai dependensi dari **SETUP-001** hingga **QA-001** (termasuk gerbang distribusi dan usulan event) untuk game **Buku Resep 2045**.

Game ini adalah pengalaman first-person 3D desktop PC bernuansa Indonesia tahun 2045 dalam latar krisis pangan fiktif. Pilar utama:
1. **Engine & Bahasa:** Godot Engine rilis stabil, GDScript murni, tanpa dependensi eksternal tak berlisensi.
2. **Kamera & Kontrol:** 3D First Person (desktop keyboard + mouse WASD), tanpa sprint/jongkok/lompat wajib pada P0.
3. **Loop Utama P0:** Membuka buku resep keluarga -> melacak resep -> mengambil persediaan awal -> menggemburkan tanah & membenahi petak -> menanam bayam -> menyiram & memupuk per petak -> mencari jagung & temu kunci di dunia -> memanen bayam + benih -> menyiapkan & memasak di dapur (kontrol panas 3 tingkat) -> menghasilkan Sayur Bening Bayam dan Jagung -> makan atau berbagi dengan tetangga -> menyimpan progres (save/load) secara terpadu.
4. **Integritas Transaksi:** Idempotensi ketat, tidak ada duplikasi item, tidak ada item hilang, pembatalan reservasi memasak mengembalikan item secara aman (kontainer refund), validasi kapasitas penuh sebelum transaksi.
5. **Waktu & Simulasi:** Tidak ada kerugian offline saat aplikasi ditutup. Menu modal/pause menghentikan simulasi. Satu-satunya pengecualian: Dapur memasak berjalan saat panel dapur aktif, dan dijeda saat panel ditutup atau pause ditekan.

---

## 2. Inventaris Fitur (Features Discovered)

Berikut adalah enumerasi seluruh fitur yang diekstraksi dari spesifikasi otoritatif:

## Features Discovered
| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | Setup & Engine | Godot Project Structure & Config | Setup proyek Godot rilis stabil, konfigurasi render desktop, scene tree awal (`project.godot`, `scenes/`, `scripts/`, `data/`, `assets/`, `tests/`) | Buka project di Godot | Project terbuka bersih tanpa error | Log error jika renderer/versi tidak kompatibel | `SETUP-001`, `PRD.md §3, §13`, `README.md` |
| 2 | Level & World | Graybox Map & Environmental Collision | Area pekarangan, rumah keluarga, jalan kampung, kebun jagung, rumpun bambu, teras tetangga dengan koordinat meter (X, Y, Z) | Posisi pemain di dalam amplop map (X: -40..40, Z: -35..45) | Collision fisik solid, navigasi tanpa celah tembus | Mencegah tembus dinding; trigger recovery jika out of bounds | `LVL-001`, `LEVEL_DESIGN.md §2, §7` |
| 3 | Level & World | Safe Return / Recovery Point | Titik recovery `safe_return_home` (0, 0, 8) dan fallback `spawn_home` (0, 0, 1) saat terjebak atau load save corrupt | Menu pause -> "Kembali ke posisi aman" / auto-recovery | Pemain dipindahkan ke koordinat aman; inventaris/progres tidak berubah | Jika recovery terhalang, fallback ke spawn_home tervalidasi | `LVL-001`, `PLY-001`, `LEVEL_DESIGN.md §4`, `UI_UX.md UI06` |
| 4 | Player & Motion | First-Person Movement & Look | Kendali first-person WASD kecepatan 3 m/s, rotasi mouse, pitch vertikal terkunci -85° s/d +85°, kamera tinggi 1.6m, capsule radius 0.3m tinggi 1.8m | Input WASD, gerakan mouse | Gerak fisik CharacterBody3D, pembaruan Transform3D | Tidak ada gerak jika pause/panel modal aktif; jarak konsisten pada variasi framerate | `PLY-001`, `CONTENT.md §14`, `PRD.md FR01` |
| 5 | Interaction | Raycast Target Detection & Occlusion | Deteksi target interaksi dalam jarak 2.0 meter dari kamera pandangan, seleksi target tunggal, pemeriksaan garis pandang terhalang (occlusion) | Arah hadap kamera pemain | Emisi target aktif yang valid ke UI prompt | Objek di balik dinding/rintangan tidak terpilih; target >2m hilang prompt | `INT-001`, `UI_UX.md §4`, `CONTENT.md §14` |
| 6 | Interaction | Context & Input Mode Manager | Pemisahan tegas konteks input: World, Book, Storage, Kitchen, Dialogue, Pause. Mengunci/melepas kursor mouse dan mencegah input leak | Tombol aksi (E, B, Tab, Esc) | Perubahan mode kontrol, mouse captured / visible | Input penutup panel (Esc/E) tidak bocor mengeksekusi aksi di dunia | `INT-001`, `PROTOTYPE.md §5`, `UI_UX.md §3` |
| 7 | Inventory | Item Dictionary & Definitions | Registri 7 item P0 (`seed_bayam`, `soil_compost`, `fertilizer_basic`, `ingredient_bayam`, `ingredient_jagung`, `ingredient_temu_kunci`, `dish_sayur_bening`) dengan batas tumpukan 20/slot | Query item ID | Data item (nama, kategori, batas stack, icon) | ID tidak dikenal ditolak dan gagal validasi | `INV-001`, `CONTENT.md §2` |
| 8 | Inventory | Backpack (Tas) Management | Tas pemain berkapasitas 12 slot, tumpukan max 20 unit/slot, pelacakan slot kosong | Tambah/kurang item, query slot | Perubahan isi tas, emisi event perubahan isi | Jika slot penuh (12/12) dan stack penuh, transaksi ditolak dengan pesan UI jelas | `INV-001`, `CONTENT.md §3`, `UI_UX.md UI04` |
| 9 | Inventory | House Storage (Peti Rumah) | Kontainer penyimpanan persisten di rumah (`storage_home`), 12 slot, tumpukan max 20 unit/slot | Interaksi E pada peti, transfer slot | Perubahan isi peti, update total stok rumah | Transaksi ditolak jika kapasitas peti tidak mencukupi | `INV-001`, `CONTENT.md §3, §5`, `UI_UX.md UI04` |
| 10 | Inventory | Two-Way Item Transfer | Transfer pilihan (pindah stack) dan transfer semua antara tas dan peti rumah secara atomik | Klik "Pindahkan pilihan" / "Pindahkan semua" | Pemindahan item tanpa kehilangan atau penambahan | Jika kontainer tujuan tidak muat seluruhnya, transfer dibatalkan utuh (tanpa transfer parsial diam-diam) | `INV-001`, `CONTENT.md §3`, `PROTOTYPE.md §6.1` |
| 11 | Inventory | Starter Container Pickup | Pengambilan paket awal dari `container_starter` (Benih: 4, Pembenah: 1, Pupuk: 1) secara atomik | E pada peti starter pekarangan | 3 item masuk tas pemain; peti starter ditandai kosong permanen | Ditolak utuh jika tas tidak muat ketiga jenis item; spam E hanya memberi 1 kali | `INV-001`, `CONTENT.md §5`, `TEST_PLAN.md T04` |
| 12 | Recipe & Book | Recipe Book UI & Detail View | Buku resep keluarga (`book_family`), menampilkan judul resep, deskripsi, 3 bahan wajib, dan petunjuk lokasi sumber | Tombol B atau E pada meja buku | Panel buku terbuka, pause simulasi dunia | Tidak menampilkan kartu resep kosong/palsu | `BOOK-001`, `PRD.md FR03`, `UI_UX.md UI02` |
| 13 | Recipe & Book | Recipe Tracking & HUD Quest Tracker | Opsi Lacak/Berhenti Lacak resep `recipe_sayur_bening_01`. Menampilkan ringkasan bahan di HUD kiri atas | Klik "Lacak" di buku | HUD tracker menampilkan hitungan `tas + stok rumah` (maksimal kebutuhan, misal 3/3) | Berhenti melacak tidak mereset progres atau menghapus item | `BOOK-001`, `PRD.md FR04`, `UI_UX.md UI01, UI02` |
| 14 | Recipe & Book | Unified Free Stock Calculation | Perhitungan ketersediaan bahan bebas dari tas pemain + peti rumah, mengecualikan item yang di-reserve oleh cooking job | Polling/event perubahan kontainer | Angka agregat bahan bebas untuk tracker dan dapur | Item di reservasi dapur tidak dihitung sebagai bebas | `BOOK-001`, `CONTENT.md §3`, `PROTOTYPE.md §4` |
| 15 | Recipe & Book | Notes Registry in Book | Pencatatan teks narasi lingkungan (`note_garden_01`) ke dalam buku setelah diperiksa di dunia | E pada catatan di dunia | Teks catatan tersimpan permanen di flag buku dan dapat dibaca ulang | Memeriksa catatan tidak wajib untuk memanen bahan | `BOOK-001`, `SOC-001`, `CONTENT.md §10`, `UI_UX.md UI02` |
| 16 | Gardening | Plot & Spot State Architecture | 1 petak `plot_home_01` (2x2 meter) memiliki status tanah: `gembur` (bool), `pembenah` (bool), `nutrisi` (0..100), `kelembapan` (0..100), dan 4 titik tanam (`slot_01`..`slot_04`) | Query status petak/titik | Nilai status tanah dan kondisi tanaman per titik | Nilai nutrisi/kelembapan diklem pada rentang 0..100 | `GARD-001`, `CONTENT.md §7` |
| 17 | Gardening | Soil Hoeing (Gemburkan Tanah) | Menggemburkan petak yang belum diolah menggunakan alat cangkul/tanah (`tool_hoe`) dengan menahan klik kiri 2 detik | Tahan LMB 2 detik dengan alat tanah aktif | Status tanah menjadi `gembur = true` | Lepas sebelum 2 detik membatalkan tanpa mutasi; petak sudah gembur menolak aksi | `GARD-001`, `CONTENT.md §6, §7` |
| 18 | Gardening | Soil Amendment (Tambah Pembenah) | Menambahkan pembenah tanah (`soil_compost`) pada petak yang sudah gembur melalui prompt E kontekstual | E pada petak gembur saat membawa pembenah | Konsumsi 1 `soil_compost`, status `pembenah = true` (petak menjadi "Siap tanam") | Ditolak jika belum gembur, sudah dibenahi, atau tidak punya item di tas | `GARD-001`, `CONTENT.md §6, §7` |
| 19 | Gardening | Seed Planting per Spot | Menanam 1 benih bayam (`seed_bayam`) pada salah satu titik tanam kosong dari petak yang siap tanam | Pilih alat benih (2), bidik titik kosong, klik kiri | Konsumsi 1 `seed_bayam`, titik terisi entitas `crop_bayam` tahap Benih | Ditolak jika tanah belum siap, titik sudah terisi, atau tas kehabisan benih | `GARD-001`, `CONTENT.md §6, §8` |
| 20 | Gardening | Area Fertilizing (Pupuk Petak) | Memupuk seluruh petak menggunakan alat pupuk (`tool_fertilizer`), menahan LMB 1 detik saat nutrisi < 20 | Tahan LMB 1 detik dengan alat pupuk aktif | Konsumsi 1 `fertilizer_basic`, nutrisi petak diset ke 100 | Ditolak tanpa biaya jika nutrisi >= 20; berlaku untuk seluruh 4 titik | `GARD-001`, `CONTENT.md §6, §7` |
| 21 | Gardening | Area Watering (Siram Petak) | Menyiram petak menggunakan penyiram (`tool_watering_can`), menahan LMB 2 detik saat kelembapan < 60 | Tahan LMB 2 detik dengan alat penyiram aktif | Konsumsi 2 air dari penyiram, kelembapan petak diset ke 80 | Ditolak tanpa biaya jika kelembapan >= 60 atau isi penyiram < 2; berlaku 1 petak | `GARD-001`, `CONTENT.md §6, §7` |
| 22 | Gardening | Moisture Evaporation Simulation | Penguapan air tanah sebesar 0.1 unit per detik simulasi aktif (minimum 0) | Delta waktu simulasi aktif | Kelembapan tanah berkurang bertahap | Berhenti saat game pause, menu modal terbuka, atau aplikasi tutup | `GARD-001`, `CONTENT.md §7`, `PROTOTYPE.md §5` |
| 23 | Gardening | 4-Stage Crop Growth & Stalling | Pertumbuhan tanaman bayam selama 180 detik efektif: Benih (0-<30s), Tunas (30-<90s), Tumbuh (90-<180s), Siap Panen (>=180s). Syarat tumbuh: siap tanam, nutrisi >= 20, kelembapan >= 30 | Tick simulasi per detik | Update stage visual dan progress tanaman | Jika kelembapan < 30 atau nutrisi < 20, progress freeze (tidak mundur, tanaman tidak mati) | `GARD-002`, `CONTENT.md §7, §8` |
| 24 | Gardening | Crop Harvesting & Replanting | Panen tanaman bayam yang siap panen (>=180s) dengan menekan E. Memberikan 1 bayam + 1 benih bayam, mengurangi nutrisi petak 5, titik kembali kosong | E pada tanaman siap panen | 1 `ingredient_bayam` dan 1 `seed_bayam` masuk tas, titik kosong, nutrisi -5 | Ditolak utuh jika tas tidak mampu menampung kedua item; nutrisi tidak berkurang | `GARD-002`, `CONTENT.md §8`, `TEST_PLAN.md T05` |
| 25 | World Resources | Corn Foraging Node | Titik panen jagung liar `resource_jagung_01` di sisa kebun keluarga. Menghasilkan 1 `ingredient_jagung` per panen | E pada pohon jagung siap panen | 1 `ingredient_jagung` masuk tas, visual jagung hilang, node tercatat dipanen | Ditolak jika tas penuh; tidak dapat dipanen lagi di hari yang sama | `WORLD-001`, `CONTENT.md §9` |
| 26 | World Resources | Temu Kunci Foraging Node | Titik panen temu kunci liar `resource_temu_kunci_01` di tepi bambu. Menghasilkan 1 `ingredient_temu_kunci` per panen | E pada rumpun temu kunci | 1 `ingredient_temu_kunci` masuk tas, node tercatat dipanen | Ditolak jika tas penuh; tidak dapat dipanen lagi di hari yang sama | `WORLD-001`, `CONTENT.md §9` |
| 27 | World Resources | Well / Water Refill Station | Titik pengisian air `water_home` di pekarangan untuk mengisi ulang penyiram hingga 10 unit penuh | Tahan E 2 detik di `water_home` | Isi air penyiram menjadi 10 / 10 | Tidak menghabiskan cadangan air dunia; dibatalkan tanpa perubahan jika dilepas | `WORLD-001`, `CONTENT.md §5, §9` |
| 28 | World Resources | Day Calendar & Sleep Recovery | Sistem hari simulasi (1 hari = 720 detik aktif). Tidur di ranjang (`bed_home`) memajukan indeks hari, mereset waktu hari ke 0, dan memulihkan sumber jagung & temu kunci | E pada ranjang -> konfirmasi "Istirahat sampai besok" | Hari bertambah (+1), sumber liar pulih | Ditolak jika job memasak sedang aktif di dapur; tanaman/petak tidak disimulasikan 720s instan | `WORLD-001`, `CONTENT.md §9`, `PROTOTYPE.md §5` |
| 29 | World Resources | Emergency Contextual Reserves | Titik cadangan `reserve_home` untuk mencegah deadlock jika pemain kehabisan bahan perawatan/benih | E pada `reserve_home` | Paket darurat: 4 benih (jika benih=0 & tak ada tanaman), 1 pembenah, atau 1 pupuk | Hanya aktif setelah `container_starter` diambil; ditolak jika masih ada stok/tanaman hidup | `WORLD-001`, `CONTENT.md §9`, `TEST_PLAN.md T09` |
| 30 | Cooking | Ingredient Validation & Reservation | Dapur memeriksa 3 bayam, 1 jagung, 1 temu kunci dari tas + peti, memindahkan item ke wadah reservasi dengan mencatat lokasi asal | Klik "Siapkan" pada stasiun dapur | Bahan berpindah ke reservasi internal ber-ID stabil; status job: `preparing` | Ditolak tanpa mutasi jika bahan kurang, stasiun sibuk, atau slot hasil belum diambil | `COOK-001`, `CONTENT.md §4`, `PROTOTYPE.md §6.2` |
| 31 | Cooking | Preparation Hold & State Transition | Tahan tombol "Siapkan" selama 4 detik untuk menyelesaikan fase persiapan menuju `ready_to_heat` | Tahan klik "Siapkan" 4 detik | Progress persiapan 100%, tombol "Mulai memasak" aktif | Melepas tahan tombol mempertahankan progres persiapan parsial (tidak reset ke 0) | `COOK-001`, `CONTENT.md §4`, `PROTOTYPE.md §6.2` |
| 32 | Cooking | Pre-Cooking Cancellation & Safe Refund | Membatalkan job sebelum menekan "Mulai memasak" mengembalikan seluruh bahan ke wadah asal (tas/peti) atau ke kontainer refund aman | Klik "Batal" di panel dapur | Seluruh reservasi dikembalikan tepat 100%; job dihapus | Jika tas & peti penuh, item masuk kontainer refund dapur permanen; tak ada item hilang | `COOK-001`, `CONTENT.md §3`, `PROTOTYPE.md §6.2` |
| 33 | Cooking | Heat Stage Control & Cooking Progress | Memasak membutuhkan 30 detik kemajuan efektif pada panas Sedang. 3 pilihan panas: Rendah (0.5x), Sedang (1.0x), Tinggi (0x + pesan peringatan) | Pilihan tombol radio panas: Rendah, Sedang, Tinggi | Kemajuan memasak bertambah sesuai multiplier | Panas tinggi menahan progress tanpa menghanguskan/merusak bahan | `COOK-002`, `CONTENT.md §4`, `TEST_PLAN.md T41` |
| 34 | Cooking | Cooking Pause & Window Closure | Menutup panel dapur (Esc) saat memasak menjeda job (`paused`). Tracker menampilkan "Masakan dijeda" | Tekan Esc saat cooking | Job disimpan status paused; simulasi masak berhenti | Membuka kembali dapur memungkinkan lanjut tanpa mengulang dari awal | `COOK-002`, `PROTOTYPE.md §5, §6.2` |
| 35 | Cooking | Dish Output & Recipe Completion Commit | Saat progress mencapai 30 detik efektif, secara atomik membuat 1 `dish_sayur_bening` di slot output dapur, reservasi dikonsumsi, flag resep selesai dicentang | Kemajuan memasak selesai 100% | 1 hidangan di slot hasil, `recipe_completed = true`, counter masakan +1 | Slot hasil tunggal memblokir resep berikutnya hingga diambil; load tidak double-commit | `COOK-002`, `CONTENT.md §4`, `PROTOTYPE.md §6.3` |
| 36 | Cooking | Dish Consumption (Makan Hidangan) | Mengonsumsi 1 hidangan dari tas dengan tombol "Makan 1 porsi?". Menampilkan teks "Hangat. Resep pertama berhasil dibuat." dan set flag `meal_used = true` | Klik "Makan" pada hidangan di tas | 1 `dish_sayur_bening` berkurang, flag `meal_used = true` | Ditolak jika hidangan tidak tersedia; tidak mengurangi status selesai resep | `COOK-002`, `CONTENT.md §10`, `TEST_PLAN.md T43` |
| 37 | Social | Neighbor Dialogue System | Percakapan dengan tetangga di teras (`npc_neighbor_01`) dengan pilihan dialog: petunjuk bayam, temu kunci, dan berbagi hidangan | E pada NPC tetangga | Panel dialog tampil, teks petunjuk ramah, opsi respons | Dialog dapat diulang kapan saja; tidak mengunci pengambilan bahan liar | `SOC-001`, `CONTENT.md §10`, `UI_UX.md UI07` |
| 38 | Social | Share Meal Option & P0 Ending | Opsi membagikan 1 porsi hidangan (dari tas atau peti rumah) ke tetangga melalui konfirmasi eksplisit. Menetapkan flag `meal_used = true` dan memicu penutup P0 | Pilih "Bagikan 1 porsi" di dialog NPC | 1 hidangan terkonsumsi, dialog terima kasih, flag `meal_used = true`, P0 selesai | Ditolak jika tidak memiliki hidangan; membatalkan konfirmasi tidak mengurangi item | `SOC-001`, `CONTENT.md §10`, `TEST_PLAN.md T44` |
| 39 | Save/Load | Unified Game State Serialization | Serialisasi seluruh entitas game: pemain, inventaris (tas + peti), status petak & tanaman, sumber dunia, cooking job & output/refund, resep & buku, flag dunia | Menu pause -> Simpan / Autosave event | Snapshot tersimpan di file temporary -> validasi -> simpan permanen | Menjaga backup valid jika penulisan gagal; tidak korup data lama | `SAVE-001`, `CONTENT.md §12`, `PROTOTYPE.md §7` |
| 40 | Save/Load | Checkpoint Management (Manual & Auto) | Pemisahan checkpoint manual dan autosave, masing-masing dengan file cadangan (.bak). Menu Lanjutkan memuat revisi valid terbaru | Tombol "Simpan" (manual) / autosave trigger / "Lanjutkan" | File checkpoint terpisah, pemulihan ke state valid terbaru | Manual save tidak menimpa slot autosave diam-diam | `SAVE-001`, `PROTOTYPE.md §7`, `TEST_PLAN.md T48` |
| 41 | Save/Load | Robust Error Recovery & Schema Validation | Validasi skema dan versi envelope sebelum mengganti state dunia. Penanganan corrupt data, disk full, interrupted write, dan invalid spawn | Coba Muat data corrupt/salah versi | Menolak load invalid, menampilkan pesan error jujur, tawarkan checkpoint valid lain | Dunia tidak termuat setengah-setengah; posisi invalid dialihkan ke recovery point | `SAVE-001`, `PROTOTYPE.md §7`, `TEST_PLAN.md T17, T22, T47` |
| 42 | UI & UX | Pause Menu & Game State Control | Menu pause (Esc): Lanjutkan, Simpan, Muat, Pengaturan, Kembali ke posisi aman, Menu utama, Keluar | Tombol Esc di dunia | Pause aktif, waktu game berhenti, mouse bebas | Esc di submenu menutup lapisan tersebut terlebih dahulu | `UI-001`, `UI_UX.md UI06` |
| 43 | UI & UX | Settings Manager (Terpisah dari Save Progres) | Pengaturan: Sensitivitas mouse (0.2-3.0x), FOV (60-100°), Skala UI (100/125/150%), Audio master/musik/SFX (0-100%), Subtitle, Head bob (mati) | Pengaturan slider/opsi di panel | File pengaturan terpisah (`settings.cfg`), langsung teraplikasikan | Load save game tidak menimpa pengaturan pemain | `UI-001`, `CONTENT.md §14`, `UI_UX.md UI06` |
| 44 | UI & UX | Honest Notification & Error System | Umpan balik teks jelas untuk setiap aksi gagal (tas penuh, tanah belum siap, bahan kurang, save gagal). Penggabungan notifikasi duplikat | Event error / pickup | Pesan UI tampil selama 2.5s tanpa menutupi prompt tengah atau mencuri fokus | Tidak pernah mengklaim sukses jika transaksi gagal | `UI-001`, `CONTENT.md §11`, `UI_UX.md §6` |
| 45 | Art & Audio | Low-Poly Stylized Indonesian Aesthetic | Visual terinspirasi Firewatch dengan identitas lokal (genteng terakota, dinding plester tambalan, pagar bambu, tanaman bayam/jagung/temu kunci terbaca) | Render scene 3D | Suasana hangat sore hari, siluet terbaca jelas pada jarak interaksi | Tanpa efek berat (motion blur, heavy bloom) yang merusak keterbacaan/FPS | `ART-001`, `ART_DIRECTION.md §1..§7` |
| 46 | Art & Audio | Core Audio Ambiance & SFX | Audio pedesaan (angin, bambu, langkah kaki, feedback cangkul/siram/pupuk, dapur, notifikasi halus). Slider volume berfungsi nyata | Pemicu aksi audio | Playback SFX / Stream bus audio | Audio tidak boleh menjadi satu-satunya pembawa informasi kritis (subtitle aktif) | `ART-001`, `ART_DIRECTION.md §8`, `CONTENT.md §14` |
| 47 | Quality Assurance | End-to-End P0 Acceptance Playthrough | Verifikasi menyeluruh alur hidup game dari setup, graybox, berkebun, panen, memasak, berbagi, save/load tanpa softlock atau duplikasi | Eksekusi test suite & playthrough | Seluruh kriteria T01-T60 tervalidasi dan terdokumentasi di arsip | Menemukan blocker memicu pembuatan bug fix task baru | `QA-001`, `TEST_PLAN.md`, `TASKS.md` |
| 48 | Distribution | Standalone Desktop Build & Offline Run | Ekspor rilis mandiri Godot PC desktop (Windows 64-bit), tanpa editor, tanpa koneksi jaringan, save ke direktori app data | Menjalankan binary standalone | Game berjalan lancar offline, save ke `%APPDATA%` | Ditolak jika mencoba menulis ke folder instalasi read-only | `DIST-001`, `PRD.md FR22`, `TEST_PLAN.md T20, T57, T58` |
| 49 | Distribution | Installer Packaging & Licensing Notices | Pembuatan installer/uninstaller bersih, menyertakan lisensi engine dan atribusi aset pihak ketiga | Eksekusi installer | Instalasi bersih, uninstall tidak menghapus save tanpa izin eksplisit | Aset tanpa lisensi diverifikasi dilarang masuk paket | `DIST-002`, `TASKS.md`, `TEST_PLAN.md T59, T60` |
| 50 | Thematic Event | Karhutla Event Framework (P1 Backlog) | Kerangka event tematik Karhutla pada map yang sama: titik api `fire_edge_01..03`, pos air, perlindungan limpasan, sains sederhana mulsa | Aktivasi setelah P0 selesai | Koridor api, rute alternatif, status contained, checkpoint pra-event | Timer event berhenti saat pause/app tertutup; rumah pemain tetap aman | `EVENT_DESIGN.md`, `CONTENT.md §13`, `TASKS.md EV-001..EV-005` |

---

## 3. Matriks Kasus Uji & Batas Ekstrem (Edge Cases)

## Edge Cases
| # | Feature | Input | Observed Behavior |
|---|---------|-------|-------------------|
| 1 | Inventory & Harvesting | Tas hanya tersisa 1 slot kosong, pemain memanen bayam (yang menghasilkan 2 jenis item: bayam + benih bayam) | Panen ditolak secara atomik. Teks muncul: "Tas tidak cukup. Kosongkan slot atau simpan barang di rumah." Tanaman tetap siap panen di titiknya, nutrisi tanah tidak berkurang. |
| 2 | Interaction & Raycast | Menatap peti starter atau tanaman bayam yang terhalang sepenuhnya oleh dinding rumah | Raycast mendeteksi occlusion. Tidak ada prompt interaksi yang muncul, dan tombol E tidak memicu aksi pada objek di balik dinding. |
| 3 | Starter Container | Spam tombol E secara cepat berkali-kali pada `container_starter` | Paket awal hanya diberikan tepat 1 kali. Status wadah berubah jadi kosong, spam berikutnya tidak memicu duplikasi atau penambahan item. |
| 4 | Gardening & Tool Use | Menggunakan alat cangkul pada petak yang sudah gembur, atau alat pupuk saat nutrisi >= 20 | Aksi ditolak tanpa mutasi. Tidak ada pembenah atau pupuk yang terkonsumsi dari tas; pesan "Petak sudah cukup. Tidak ada bahan yang digunakan" ditampilkan. |
| 5 | Gardening & Watering | Menyiram petak yang kelembapannya sudah 60 unit (ambang batas tidak perlu siram) | Aksi siram ditolak tanpa mengurangi air penyiram. UI memberi tahu tanah masih cukup lembap. |
| 6 | Gardening & Stalling | Kelembapan tanah turun hingga di bawah 30 atau nutrisi turun di bawah 20 saat bayam dalam tahap Tunas | Pertumbuhan efektif terhenti (freeze). Progres tidak berkurang/mundur dan tanaman tidak mati. Begitu disiram/dipupuk kembali hingga memenuhi syarat, pertumbuhan melanjutkan dari detik yang sama. |
| 7 | Cooking Reservation | Bahan di tas hanya ada 2 bayam, 1 jagung, 1 temu kunci (kurang 1 bayam), lalu klik "Siapkan" | Stasiun memeriksa prasyarat secara atomik. Tidak ada bahan yang berpindah ke reservasi, tidak ada job dibuat. Pesan UI menampilkan bahan yang belum lengkap. |
| 8 | Cooking Reservation Refund | Bahan telah di-reserve, pemain keluar panel, mengisi penuh tas dan peti rumah melalui item lain, lalu kembali ke dapur dan menekan "Batal" | Seluruh bahan reservasi tidak muat di tas/peti asal. Sistem memindahkan kelebihan bahan ke kontainer refund aman dapur (`kitchen_refund_storage`). Bahan tidak hilang dan tidak tercampur ke slot output hidangan. |
| 9 | Cooking Heat Management | Memilih pengaturan panas "Tinggi" saat fase cooking | Multiplier kemajuan menjadi 0x (stuck/terhenti) dan muncul peringatan "Kecilkan panas ke Sedang". Bahan masakan tidak gosong atau rusak; begitu dipindah ke Sedang, kemajuan lanjut normal. |
| 10 | Cooking Interruption | Menutup panel dapur (Esc) saat proses cooking berjalan 15 detik, lalu berjalan-jalan di dunia selama 2 menit | Waktu memasak tidak berjalan di latar belakang saat panel tertutup. Job berada dalam status `paused`. Saat pemain membuka kembali panel dapur, waktu tetap di 15 detik dan dapat dilanjutkan. |
| 11 | Cooking Output Slot Full | Memasak selesai, output `dish_sayur_bening` siap di slot hasil. Tas pemain penuh. Pemain menekan "Ambil" | Hidangan tetap berada di slot hasil dapur. Resep tetap tercatat selesai di buku. Pemain tidak dapat memulai job memasak baru sebelum mengambil hidangan tersebut ke tas yang sudah dikosongkan. |
| 12 | World Calendar & Sleep | Memilih istirahat di ranjang (`bed_home`) saat cooking job masih aktif di dapur | Aksi istirahat ditolak dengan pesan peringatan bahwa proses memasak sedang berjalan. Pemain harus menyelesaikan atau membatalkan job terlebih dahulu. |
| 13 | World Calendar & Plants | Memilih istirahat di ranjang untuk melompat ke hari berikutnya | Indeks hari bertambah (+1), sumber jagung dan temu kunci pulih kembali jika sudah dipanen. Namun, kemajuan tanaman di kebun dan kelembapan tanah TIDAK disimulasikan 720 detik instan, melainkan tetap pada status aslinya. |
| 14 | Emergency Reserves | Pemain memiliki 0 benih di tas, 0 benih di peti, namun masih ada 1 tanaman bayam hidup di kebun | Interaksi pada `reserve_home` menolak memberikan benih cadangan karena pemain masih memiliki tanaman aktif yang akan menghasilkan benih saat dipanen. |
| 15 | Save Interruption | Terjadi kegagalan penulisan disk atau proses dihentikan mendadak saat serialisasi save game | Mekanisme atomic write ke temporary file mencegah rusaknya checkpoint lama. Checkpoint valid sebelumnya dan file cadangan (.bak) tetap utuh. Game menampilkan pesan "Progres belum tersimpan". |
| 16 | Save Load Deserialization | Memuat file save yang memiliki versi skema tidak kompatibel atau field corrupt | Validator skema menolak swap dunia secara parsial. Game menampilkan peringatan dan menawarkan memuat backup valid lainnya, tanpa membuat dunia setengah jadi atau menghapus save secara diam-diam. |
| 17 | Player Stuck in Geometry | Pemain tersangkut di antara collision atau load save menempatkan pemain di koordinat collision | Memilih "Kembali ke posisi aman" di pause menu memindahkan pemain ke `safe_return_home` (0, 0, 8). Tidak ada inventaris yang hilang, petak dan waktu tidak terpengaruh. |
| 18 | Input Leak Prevention | Menutup menu tas atau buku dengan menekan tombol Esc atau E | Sinyal input dikonsumsi oleh UI layer. Pemain tidak melakukan swing tool atau interaksi tidak sengaja dengan objek dunia tepat saat menu tertutup. |
| 19 | Repeat Recipe Cook | Pemain memasak resep `recipe_sayur_bening_01` untuk kedua kalinya setelah berhasil membuat yang pertama | Jumlah hidangan yang dibuat bertambah (counter +1). Centang selesai pada buku tetap satu (tidak terhapus atau digandakan sebagai pencapaian ganda). |
| 20 | Offline / No Network | Memutus koneksi internet seluruhnya sebelum menjalankan game | Game berjalan 100% normal tanpa prompt login, telemetri, atau dependensi jaringan. Seluruh aset dan logika berjalan lokal. |

---

## 4. Batas Modul & Kontrak Antarmuka (Module Boundaries & Interface Contracts)

Arsitektur kode Godot/GDScript dibagi menjadi modul-modul independen dengan batas tanggung jawab yang jelas:

```
┌────────────────────────────────────────────────────────────────────────┐
│                              UI MANAGER                                │
│    (HUD Tracker, Recipe Book, Inventory/Storage, Kitchen, Pause, Nav)  │
└──────▲──────────────────────▲──────────────────────▲───────────────────▲
       │                      │                      │                   │
┌──────┴──────────────┐┌──────┴──────────────┐┌──────┴───────────┐┌──────┴──────────┐
│  INVENTORY MANAGER  ││    GARDEN MANAGER   ││  COOKING MANAGER ││ DIALOGUE MANAGER│
│ (Backpack, Storage, ││(Plot State, Moisture││ (Jobs, Heating,   ││ (NPC Neighbor,  │
│  Item Dict, Trans)  ││ Nutrients, 4 Crops) ││  Reservation,Out)││  Sharing Meal)  │
└──────▲──────▲───────┘└──────▲──────▲───────┘└──────▲──────▲────┘└──────▲──────────┘
       │      │               │      │               │      │            │
       │      └───────────────┼──────┴───────────────┼──────┴────────────┘
       │                      │                      │
┌──────┴──────────────────────┴──────────────────────┴───────────────────┐
│                          SAVE / LOAD MANAGER                           │
│     (Envelope Schema, Atomic Snapshot, Backup Recovery, Settings)      │
└────────────────────────────────────────────────────────────────────────┘
```

### 4.1 Modul Inventaris (`InventoryManager` / `ContainerData`)
- **Tanggung Jawab:** Menyimpan data tumpukan slot (ID item, jumlah), memeriksa kapasitas bebas, mengeksekusi transfer antar-kontainer secara atomik.
- **Data Internal:**
  - `backpack_slots`: Array[Dictionary] (ukuran 12, max stack 20)
  - `storage_slots`: Array[Dictionary] (ukuran 12, max stack 20)
  - `kitchen_refund_slots`: Array[Dictionary] (penampung sisa refund aman)
- **Metode Publik / Kontrak:**
  - `can_add_item(container_id: String, item_id: String, amount: int) -> bool`
  - `can_add_items(container_id: String, items: Array[Dictionary]) -> bool`
  - `add_item(container_id: String, item_id: String, amount: int) -> bool`
  - `remove_item(container_id: String, item_id: String, amount: int) -> bool`
  - `transfer_stack(from_container: String, to_container: String, slot_idx: int) -> bool`
  - `transfer_all(from_container: String, to_container: String) -> bool`
  - `get_free_stock(item_id: String) -> int` (menghitung total di tas + peti yang tidak di-reserve)
- **Sinyal:**
  - `inventory_changed(container_id: String)`
  - `transaction_failed(reason_message: String)`

### 4.2 Modul Pemain & Kontrol (`PlayerController`)
- **Tanggung Jawab:** Mengendalikan pergerakan first person CharacterBody3D, rotasi kamera pitch/yaw, klem pitch vertikal (-85° s/d +85°), pemilihan alat aktif 1..4.
- **Data Internal:**
  - `walk_speed: float = 3.0`
  - `camera_height: float = 1.6`
  - `active_tool_id: String` (`tool_hoe`, `tool_seed`, `tool_fertilizer`, `tool_watering_can`)
  - `watering_can_water: int` (0..10)
- **Metode Publik / Kontrak:**
  - `teleport_to(position: Vector3, rotation_yaw: float) -> void`
  - `set_movement_enabled(enabled: bool) -> void`
  - `set_active_tool(tool_id: String) -> void`
  - `add_water_to_can(amount: int) -> int`
  - `consume_water(amount: int) -> bool`
- **Sinyal:**
  - `tool_changed(tool_id: String)`
  - `watering_can_updated(current_water: int, max_water: int)`

### 4.3 Modul Interaksi & Konteks (`InteractionSystem` & `InputContextManager`)
- **Tanggung Jawab:** Raycast 2.0m dari Camera3D, deteksi objek bertipe `Interactable`, manajemen prompt, pergantian konteks input dan visibilitas mouse.
- **Konteks:** `CONTEXT_WORLD`, `CONTEXT_BOOK`, `CONTEXT_STORAGE`, `CONTEXT_KITCHEN`, `CONTEXT_DIALOGUE`, `CONTEXT_PAUSE`.
- **Metode Publik / Kontrak:**
  - `get_current_target() -> Interactable`
  - `switch_context(new_context: int) -> void`
  - `pop_context() -> void`
- **Sinyal:**
  - `target_focused(target: Interactable)`
  - `target_unfocused()`
  - `context_changed(old_context: int, new_context: int)`

### 4.4 Modul Kebun & Tanaman (`GardenManager` / `PlotEntity`)
- **Tanggung Jawab:** Mengelola status fisik petak `plot_home_01` (gembur, pembenah, nutrisi, kelembapan) dan siklus hidup tanaman bayam pada 4 titik tanam `slot_01`..`slot_04`.
- **Aturan Transisi & Angka:**
  - Gembur: alat `tool_hoe` (tahan 2s)
  - Pembenah: 1 `soil_compost` (prompt E saat gembur)
  - Benih: 1 `seed_bayam` per titik tanam
  - Nutrisi: < 20 perlu pupuk; 1 `fertilizer_basic` menaikkan nutrisi ke 100
  - Kelembapan: < 60 boleh disiram; aksi memakai 2 air dan mengeset ke 80; penguapan 0.1/s
  - Syarat tumbuh bayam: siap tanam + nutrisi >= 20 + kelembapan >= 30
  - Tahap bayam: Benih (0-<30s), Tunas (30-<90s), Tumbuh (90-<180s), Siap Panen (>=180s)
  - Panen: menghasilkan 1 `ingredient_bayam` + 1 `seed_bayam`, nutrisi -5, titik kosong
- **Metode Publik / Kontrak:**
  - `hoe_plot() -> bool`
  - `apply_compost() -> bool`
  - `plant_seed(slot_id: String) -> bool`
  - `fertilize_plot() -> bool`
  - `water_plot() -> bool`
  - `harvest_crop(slot_id: String) -> bool`
- **Sinyal:**
  - `plot_state_changed(plot_id: String, nutrient: float, moisture: float)`
  - `crop_stage_changed(slot_id: String, stage: int)`
  - `crop_harvested(slot_id: String)`

### 4.5 Modul Dapur & Memasak (`CookingManager`)
- **Tanggung Jawab:** Validasi bahan masakan, alur reservasi atomik, progress persiapan (hold 4s), progress memasak (30s efektif pada panas Sedang), kontrol panas (Rendah 0.5x, Sedang 1.0x, Tinggi 0x), slot output, dan pembatalan aman (refund).
- **State Job:** `IDLE` -> `PREPARING` -> `READY_TO_HEAT` -> `COOKING` <-> `PAUSED` -> `OUTPUT_READY`.
- **Metode Publik / Kontrak:**
  - `can_start_preparation(recipe_id: String) -> bool`
  - `start_preparation(recipe_id: String) -> bool`
  - `set_preparation_progress(progress_seconds: float) -> void`
  - `start_cooking() -> void`
  - `set_heat_level(level: int) -> void` # 0: Rendah, 1: Sedang, 2: Tinggi
  - `pause_cooking() -> void`
  - `resume_cooking() -> void`
  - `cancel_preparation() -> bool` # Mengembalikan bahan reservasi
  - `take_dish_output() -> bool`
- **Sinyal:**
  - `cooking_state_changed(job_state: int)`
  - `cooking_progress_updated(current_seconds: float, target_seconds: float)`
  - `dish_cooked(dish_id: String)`
  - `dish_taken(dish_id: String)`

### 4.6 Modul Buku & Resep (`RecipeBookManager`)
- **Tanggung Jawab:** Melacak resep aktif, menghitung bahan dari tas + peti secara terpadu, menyimpan flag resep selesai dan jumlah masakan, mengelola catatan lingkungan.
- **Metode Publik / Kontrak:**
  - `track_recipe(recipe_id: String) -> void`
  - `untrack_recipe() -> void`
  - `mark_recipe_completed(recipe_id: String) -> void`
  - `record_note(note_id: String) -> void`
  - `get_tracked_recipe_data() -> Dictionary`
- **Sinyal:**
  - `recipe_tracked(recipe_id: String)`
  - `recipe_completed_event(recipe_id: String)`
  - `note_discovered(note_id: String)`

### 4.7 Modul Sosial & Narasi (`DialogueManager`)
- **Tanggung Jawab:** Menangani pohon dialog warga (`npc_neighbor_01`), opsi bertanya petunjuk, opsi berbagi hidangan 1 porsi, dan pembaruan flag `meal_used`.
- **Metode Publik / Kontrak:**
  - `start_dialogue(npc_id: String) -> void`
  - `select_option(option_index: int) -> void`
  - `share_dish() -> bool`
  - `consume_dish_player() -> bool`
- **Sinyal:**
  - `dialogue_opened(npc_id: String)`
  - `dialogue_closed()`
  - `p0_experience_completed()` # Dipicu saat recipe_completed AND meal_used

### 4.8 Modul Save & Persistensi (`SaveManager`)
- **Tanggung Jawab:** Serialisasi snapshot lengkap ke format JSON envelope, validasi skema/versi, penulisan aman melalui file temporer, rotasi file backup (.bak), deserialisasi ke state game, penanganan error korupsi.
- **Payload Snapshot:**
  - Envelope: `schema_version: 1`, `checkpoint_revision: int`, `save_time: String`, `save_type: "manual" | "autosave"`
  - Player: posisi, rotasi yaw, alat aktif, isi air penyiram
  - Inventory: slot tas, slot peti rumah, slot refund dapur
  - Garden: status petak (gembur, pembenah, nutrisi, kelembapan), 4 titik tanaman (progress, stage, crop_id)
  - Resources: status panen harian jagung & temu kunci, status wadah starter
  - Cooking: active job state, ID job, reservasi + asal kontainer, heat level, progress, output slot
  - Book: resep dilacak, resep selesai, counter masakan dibuat, flag catatan
  - World: indeks hari, waktu aktif hari, flag dialog, `meal_used`
- **Metode Publik / Kontrak:**
  - `save_game(is_manual: bool) -> bool`
  - `load_game(save_path: String) -> bool`
  - `get_latest_valid_checkpoint() -> String`
  - `validate_save_file(path: String) -> bool`
- **Sinyal:**
  - `save_completed(success: bool, message: String)`
  - `load_completed(success: bool, message: String)`

---

## 5. Definisi ID Data & Parameter Numerik Lengkap

Seluruh ID stabil dan angka numerik di bawah ini merujuk langsung pada acuan tunggal `docs/CONTENT.md` (label **DEFAULT UJI**):

### 5.1 Kamus Item
| ID | Nama Tampil | Kategori | Batas Stack | Pemakaian | Sumber |
|---|---|---|---|---|---|
| `seed_bayam` | Benih bayam | Benih | 20 unit | 1 per titik tanam | Wadah awal, hasil panen, cadangan |
| `soil_compost` | Pembenah tanah | Perawatan | 20 unit | 1 untuk 1 petak sekali | Wadah awal / cadangan |
| `fertilizer_basic` | Pupuk | Perawatan | 20 unit | 1 untuk 1 petak jika perlu | Wadah awal / cadangan |
| `ingredient_bayam` | Bayam | Bahan resep | 20 unit | 3 per masakan | Panen tanaman kebun |
| `ingredient_jagung` | Jagung | Bahan resep | 20 unit | 1 per masakan | Sisa kebun keluarga |
| `ingredient_temu_kunci` | Temu kunci | Bahan resep | 20 unit | 1 per masakan | Tepi rumpun bambu |
| `dish_sayur_bening` | Sayur Bening Bayam dan Jagung | Hidangan | 20 unit | 1 dimakan / dibagikan | Stasiun dapur rumah |

### 5.2 Resep Masakan
| Properti | Nilai |
|---|---|
| ID Resep | `recipe_sayur_bening_01` |
| Nama | Sayur Bening Bayam dan Jagung |
| Ketersediaan | Tersedia langsung sejak game baru |
| Kebutuhan Bahan | 3 `ingredient_bayam`, 1 `ingredient_jagung`, 1 `ingredient_temu_kunci` |
| Stasiun Masak | `station_kitchen_home` |
| Air & Bahan Bakar | Fasilitas rumah (selalu cukup di P0, bukan item inventaris) |
| Durasi Persiapan | Tahan tombol "Siapkan" selama 4.0 detik |
| Durasi Memasak | 30.0 detik kemajuan efektif pada panas Sedang |
| Pengali Panas Rendah | Kemajuan × 0.5 |
| Pengali Panas Sedang | Kemajuan × 1.0 (target normal) |
| Pengali Panas Tinggi | Kemajuan × 0.0 + pesan "Kecilkan panas ke Sedang" (bahan tidak gosong) |
| Pilihan Panas Awal | Panas Rendah |
| Output | 1 `dish_sayur_bening` pada slot hasil tunggal dapur |

### 5.3 Petak & Parameter Tanah
| Parameter | Nilai Otoritatif |
|---|---|
| ID Petak | `plot_home_01` |
| Dimensi Fisik | 2 × 2 meter |
| Titik Tanam | 4 titik: `slot_01`, `slot_02`, `slot_03`, `slot_04` |
| Status Awal | Belum diolah (`gembur = false`), `pembenah = false`, `nutrisi = 0`, `kelembapan = 0` |
| Syarat Siap Tanam | `gembur == true` dan `pembenah == true` |
| Skala Nutrisi | 0 s/d 100 ("Perlu pupuk" bila < 20, "Cukup" bila >= 20) |
| Efek Pemupukan | Jika nutrisi < 20, 1 pupuk mengeset nutrisi petak ke 100 |
| Biaya Panen Nutrisi | Berkurang 5 unit per panen tanaman berhasil (min 0) |
| Skala Kelembapan | 0 s/d 100 ("Kering" bila < 30, "Lembap" bila >= 30) |
| Efek Penyiraman | Jika kelembapan < 60, aksi memakai 2 air dan mengeset kelembapan ke 80 |
| Ambang Tolak Siram | Kelembapan >= 60 (aksi ditolak tanpa biaya) |
| Laju Penguapan | Berkurang 0.1 per detik simulasi aktif (min 0) |
| Syarat Tumbuh | Siap tanam + nutrisi >= 20 + kelembapan >= 30 |

### 5.4 Siklus Hidup Tanaman Bayam
| Parameter | Nilai Otoritatif |
|---|---|
| Definisi | `crop_bayam` |
| Biaya Tanam | 1 `seed_bayam` per titik tanam |
| Total Waktu Efektif | 180.0 detik |
| Tahap 1: Benih | Kemajuan 0 s/d < 30 detik |
| Tahap 2: Tunas | Kemajuan 30 s/d < 90 detik |
| Tahap 3: Tumbuh | Kemajuan 90 s/d < 180 detik |
| Tahap 4: Siap Panen | Kemajuan >= 180 detik (dikunci pada 180) |
| Hasil Panen | 1 `ingredient_bayam` dan 1 `seed_bayam` |
| Dampak Panen | Titik kembali kosong, nutrisi petak berkurang 5 |
| Efek Kekurangan Air/Nutrisi | Pertumbuhan berhenti sementara (freeze), tidak mundur, tidak mati |

### 5.5 Sumber Daya & Fasilitas Dunia
| ID Dunia | Lokasi / Landmark | Perilaku & Isi |
|---|---|---|
| `container_starter` | Pekarangan dekat rak alat (6, 0, 4) | Berisi: Benih 4, Pembenah 1, Pupuk 1. Diambil sekaligus jika tas muat. Sekali per game. |
| `storage_home` | Rumah dekat dapur (-2, 0, -4) | Peti penyimpanan 12 slot, 2 arah, sumber bahan bebas untuk dapur. |
| `water_home` | Pekarangan (4, 0, 9) | Tahan E 2 detik untuk mengisi penyiram hingga 10 unit penuh. |
| `reserve_home` | Dekat wadah awal (7, 0, 4) | Cadangan darurat: memberi 4 benih (jika benih=0 dan tak ada tanaman), 1 pembenah, atau 1 pupuk. Aktif setelah wadah awal diambil. |
| `book_family` | Meja rumah (-1, 0, -2) | E membuka buku resep keluarga. Meja diegetik, buku juga bisa dibuka dengan hotkey B. |
| `station_kitchen_home` | Dapur rumah (2, 0, -4) | 1 stasiun memasak aktif, 1 slot hasil, kontainer refund terpisah. |
| `bed_home` | Rumah (-2, 0, 0) | Tidur sampai besok: memajukan hari (+1), reset timer hari (0s), mereset sumber jagung & temu kunci. Ditolak jika job masak aktif. |
| `resource_jagung_01` | Sisa kebun keluarga (22, 0, 28) | Panen 1 `ingredient_jagung` sekali per hari simulasi. |
| `resource_temu_kunci_01` | Tepi rumpun bambu (-20, 0, 30) | Panen 1 `ingredient_temu_kunci` sekali per hari simulasi. |
| `npc_neighbor_01` | Teras tetangga (-14, 0, 15) | Tetangga untuk dialog petunjuk dan berbagi hidangan. |
| `note_garden_01` | Sisa kebun keluarga (19, 0, 27) | Catatan lingkungan: "Pagar boleh miring. Jangan sampai lupa jalan pulang." Masuk flag buku. |
| `safe_return_home` | Depan rumah (0, 0, 8) | Titik recovery default pemain. |
| `spawn_home` | Dalam rumah (0, 0, 1) | Titik awal spawn pemain baru menghadap meja buku. |

### 5.6 Parameter Gerak, Kamera & Pengaturan P0
| Parameter | Nilai Default / Batas |
|---|---|
| Kecepatan Jalan | 3.0 m/s (tanpa sprint) |
| Tinggi Kamera | 1.6 m dari posisi kaki |
| Dimensi Kapsul Pemain | Radius 0.3 m, tinggi 1.8 m |
| Jangkauan Interaksi | 2.0 m dari kamera pandangan |
| FOV Kamera | Default 80° (rentang pengaturan 60° s/d 100°) |
| Sensitivitas Mouse | Default 1.0x (rentang 0.2x s/d 3.0x, basis 0.1° per piksel) |
| Klem Pandang Vertikal | -85° s/d +85° |
| Skala UI | Default 100% (pilihan: 100%, 125%, 150%) |
| Volume Audio Default | Master 70%, SFX 70%, Musik 40% (rentang 0 s/d 100%) |
| Subtitle | Aktif default (semua info penting bersubtitle) |
| Head Bob & Motion Blur | Mati default |
| Resolusi Baseline | 1920 × 1080 (verifikasi layout minimum 1280 × 720, safe margin 4%) |

### 5.7 Parameter Event Karhutla (P1 Backlog)
| Parameter | Nilai Rujukan |
|---|---|
| ID Event | `event_karhutla_01` |
| Judul Lengkap | Buku Resep 2045: Karhutla |
| Titik Api Interaktif | 3 titik: `fire_edge_01`, `fire_edge_02`, `fire_edge_03` (intensitas awal 2 unit abstrak) |
| Aksi Pemadaman Selang | Tahan 3s, biaya suplai 1, intensitas turun 1 unit |
| Pos Air Suplai | Kapasitas 8 unit, awal 0, isi ulang 3s setelah suplai disambungkan |
| Petak Pemulihan | 1 petak nonpangan `recovery_edge_01` (inspeksi + penutup, 120s aktif menuju pemulihan awal) |
| Pengaruh Mulsa | Laju penguapan × 0.5 pada petak aman |

---

## 6. Rantai Dependensi & Urutan Pelaksanaan (SETUP-001 hingga QA-001)

Rantai tugas disusun secara berurutan dan ketat mengikuti `docs/TASKS.md` dan `ORIGINAL_REQUEST.md`:

```
SETUP-001 ──► LVL-001 ──► PLY-001 ──► INT-001 ──► INV-001 ──► BOOK-001 ──► GARD-001
                                                                                  │
┌─────────────────────────────────────────────────────────────────────────────────┘
│
▼
GARD-002 ──► WORLD-001 ──► COOK-001 ──► COOK-002 ──► SOC-001 ──► SAVE-001
                                                                      │
┌─────────────────────────────────────────────────────────────────────┘
│
▼
UI-001 ──► ART-001 ──► QA-001 ──► (DIST-001 ──► DIST-002)
```

### Tabel Rincian Rantai Tugas
| Task ID | Nama Tugas | Dependensi Wajib | Deliverable Utama & Kriteria Selesai | Cakupan Kasus Uji (TEST_PLAN) |
|---|---|---|---|---|
| **SETUP-001** | Setup Godot & Struktur Proyek | DOC-001; instruksi coding | Proyek Godot terbuka di engine, versi dikunci, renderer desktop dipilih, scene awal & README terisi cara run | T23, T24 |
| **LVL-001** | Graybox Map & Spawn | SETUP-001 | Geometri map, rumah, pekarangan, jalan, teras, collision batas, spawn point, dan safe recovery point | T24, T25 |
| **PLY-001** | Kendali First Person | LVL-001 | CharacterBody3D, WASD gerak 3 m/s, rotasi kamera pitch -85°..85°, deteksi collision dinding tanpa tembus | T18, T25, T26 |
| **INT-001** | Interaksi & Konteks Input | PLY-001 | Raycast 2m, prompt E tunggal, occlusion check, context manager (World vs UI modal) cegah input leak | T18, T27, T28 |
| **INV-001** | Data Item & Inventaris | INT-001 | Registri 7 item, tas 12 slot, peti 12 slot, max stack 20, atomic transfer dua arah, starter pack pickup | T04, T05, T29, T30 |
| **BOOK-001** | Buku & Tracker Resep | INV-001 | UI buku resep B/E, lacak resep Sayur Bening, agregat stok bebas tas+peti, catatan lingkungan, HUD quest tracker | T01, T02, T03, T11, T31 |
| **GARD-001** | Persiapan Petak & Perawatan | INV-001, BOOK-001 | Petak 2x2m 4 titik, cangkul tanah (tahan 2s), pembenah E, pupuk area (tahan 1s), siram area (tahan 2s), penguapan 0.1/s | T06, T07, T08, T32, T33 |
| **GARD-002** | Pertumbuhan & Panen Bayam | GARD-001 | 4 tahap bayam 180s, stall saat kering/nutrisi kurang, panen 1 bayam + 1 benih, nutrisi -5, replanting | T05, T34, T35, T36 |
| **WORLD-001** | Sumber Daya Liar & Kalender | GARD-002 | Panen jagung & temu kunci 1x/hari, isi ulang air penyiram di sumur pekarangan, istirahat ranjang ganti hari, cadangan darurat | T09, T37, T38, T39 |
| **COOK-001** | Reservasi & Persiapan Dapur | WORLD-001, BOOK-001 | Validasi 3 bayam 1 jagung 1 temu kunci, pindah ke reservasi ber-ID, tahan Siapkan 4s, pembatalan aman ke tas/refund | T10, T11, T12, T13, T40 |
| **COOK-002** | Pemasakan & Output Hidangan | COOK-001 | Kontrol panas 3 level (0.5x, 1x, 0x), pause job saat panel tutup, output 1 hidangan, centang buku, makan hidangan | T12, T15, T19, T41, T42 |
| **SOC-001** | Warga & Penutup P0 | COOK-002 | Dialog NPC tetangga, petunjuk, opsi berbagi 1 porsi hidangan, penutup P0 tercapai (`recipe_completed` & `meal_used`) | T43, T44, T45 |
| **SAVE-001** | Persistensi Lengkap (Save/Load) | SOC-001 | Serialisasi seluruh snapshot game, manual save, autosave, file backup, penanganan korupsi data & interrupted write | T14, T16, T17, T22, T46, T47, T48, T49, T50 |
| **UI-001** | UI Terpadu & Pengaturan | SAVE-001 | Menu pause, halaman pengaturan (FOV, Sens, Volume, Skala UI), konfirmasi keluar/game baru, sistem notifikasi honest | T18, T21, T28, T51, T52, T53, T54 |
| **ART-001** | Visual & Audio Dasar Konsisten | UI-001 | Identitas visual stylized Firewatch pedesaan Indonesia, siluet item/tanaman terbaca, audio ambience & SFX responsif | T55, T56 |
| **QA-001** | Playthrough & Penerimaan P0 | ART-001 | Verifikasi menyeluruh alur P0 dari game baru hingga makan/berbagi dan save/load, validasi ketiadaan softlock/duplikasi | Playthrough penuh, T01..T60 |

---

## 7. Kesimpulan & Rekomendasi Eksekusi

1. **Kelengkapan Spesifikasi:** Seluruh dokumen rujukan telah diverifikasi silang dan konsisten 100%. Tidak ditemukan kontradiksi atau ruang kosong pada logika P0.
2. **Kesiapan Fase Implementasi:** Sesi coding dapat langsung dimulai dari **SETUP-001** dengan memeriksa engine Godot yang terpasang di sistem pengguna, mengunci versi dan renderer, serta membangun fondasi arsitektur modul sesuai kontrak data di atas.
3. **Kepatuhan AGENTS.md:** Setiap task selesai wajib disertai laporan bernomor baru di `docs/completed_tasks/` (mulai dari `002-...`), pembaruan daftar di `docs/PROJECT_STATUS.md`, dan pengubahan status di `docs/TASKS.md`.
