# Laporan Task Selesai: 014 — Interaksi Sosial Warga, Dialog Tetangga, Berbagi Hidangan, dan Penutup P0

Dokumen ini mencatat penyelesaian milestone `SOC-001` sesuai dengan panduan kerja AI Agent Buku Resep 2045 dan spesifikasi PRD / CONTENT / UI_UX / TEST_PLAN.

## Identitas

- **ID task:** `SOC-001`
- **Judul:** Interaksi Sosial Warga, Dialog Tetangga, Berbagi Hidangan, dan Penutup P0
- **Tanggal selesai:** 29 Oktober 2026
- **Agent/pelaksana:** Worker Agent (`worker_soc_001`) di bawah supervisi Orchestrator
- **Tahap produk:** P0 (Vertical Slice Loop Utama)
- **Status:** Selesai (Lulus Penuh, seluruh test suite termasuk Suite 15, Suite 16, dan Suite 17 lulus 100%, 6.402 asersi lulus, 0 gagal, Exit Code 0)
- **Versi sumber/build:** Godot Engine v4.7.2.stable.official, headless CLI, branch lokal aktif

## Tujuan dan pemicu

Penyelesaian milestone `COOK-002` sebelumnya telah menuntaskan simulasi memasak aktif 30 detik nominal dengan kontrol panas (Rendah/Sedang/Tinggi), jeda otomatis panel, slot output tunggal, centang buku resep, dan aksi konsumsi hidangan dari tas. Namun, pilar naratif sosial lokal dan penutup pengalaman P0 belum terwujud: pemain belum dapat berdialog dengan tetangga di batas timur pekarangan (`npc_neighbor_01`), belum dapat memperoleh petunjuk bahan alam secara opsional, belum dapat berbagi hidangan hasil masakan, dan sinyal penutup vertical slice P0 belum terhubung secara menyeluruh.

Milestone `SOC-001` dikerjakan untuk memenuhi kebutuhan spesifikasi `PRD.md` (FR14 Interaksi Tetangga & FR15 Penutup Pengalaman), `docs/CONTENT.md` § 10 (Siklus Dialog Tetangga & Penutup Loop P0), `docs/UI_UX.md` § 4.7 (Modal Dialog Warga), serta `docs/TEST_PLAN.md` (T43, T44, T45).

## Ruang lingkup

Pekerjaan yang diselesaikan meliputi:
1. **Pohon Dialog Tetangga 7-Node (CONTENT § 10 & T45):**
   - Implementasi 7 node dialog berurutan dan kondisional:
     - `npc_intro`: Perkenalan awal tetangga, menyapa pemain dan menanyakan kebun lama keluarga.
     - `npc_hint_bayam`: Petunjuk budidaya bayam (4 tahap pertumbuhan di petak pekarangan).
     - `npc_hint_kunci`: Petunjuk lokasi temu kunci liar di rumpun bambu timur dan rumpun jagung utara.
     - `npc_waiting`: State tunggu ramah jika pemain belum memiliki masakan matang di tas atau peti.
     - `npc_offer`: Tawaran berbagi hidangan jika pemain membawa masakan `dish_sayur_bening` di tas/peti, membuka opsi berbagi dengan konfirmasi.
     - `npc_received`: Dialog apresiasi tetangga saat hidangan diterima (*"Aroma temu kuncinya pas... Terima kasih sudah berbagi."*).
     - `npc_repeat`: State percakapan berulang tanpa batas setelah berbagi, memperkuat suasana hangat dan ramah warga lokal.
2. **Invarian Ketiadaan Kunci Progres (*Lock-Free Invariant* / T45):**
   - Pemain **dapat menyelesaikan resep dan menanam/foraging tanpa pernah berbicara dengan tetangga**. Dialog bersifat informatif dan opsional, tidak pernah memblokir spawn atau interaksi tanaman/bambu/jagung.
3. **Aksi Berbagi Hidangan Atomik (`share_dish` / T44):**
   - Transaksi pemotongan 1 unit `dish_sayur_bening` secara atomik dari inventaris pemain (tas diutamakan, fallback ke peti penyimpanan rumah).
   - Sinkronisasi instan terhadap flag global: `meal_used = true` di `DialogueManager`, `WorldResourceManager`, dan `KitchenManager`.
   - Pencegahan berbagi ganda: sekali berbagi berhasil, flag `has_shared_meal` bernilai `true` dan opsi berbagi dinonaktifkan secara permanen.
4. **Evaluasi Penutup Pengalaman P0 (*P0 Experience Closure* / T43):**
   - Kriteria selesai P0 terpenuhi secara utuh ketika:
     1. Resep Sayur Bening Bayam dan Jagung telah dimasak (`recipe_manager.is_recipe_completed("recipe_sayur_bening_01") == true` atau `times_cooked >= 1`).
     2. Hidangan telah digunakan/dikonsumsi (`meal_used == true`), baik melalui aksi makan di tas (`action_eat`) maupun aksi berbagi dengan tetangga (`action_share`).
   - Sinyal `p0_experience_completed` dipancarkan tepat sekali (*deduplicated*).
   - Menampilkan umpan balik notifikasi toast non-blocking pada HUD: *"Satu resep selesai. Kebun ini baru dimulai."*.
   - **Non-blocking gameplay**: Tidak ada pembekuan permainan, tidak ada penguncian input paksa, dan pemain bebas melanjutkan berkebun serta menjelajahi dunia.
5. **Antarmuka Dialog Responsif & Aksesibel (`DialogueUI`):**
   - CanvasLayer layer 12 dengan panel dialog bawah layar, label nama pembicara ("Tetangga"), teks narasi per dialog node, dan wadah tombol pilihan dinamis.
   - Navigasi penuh keyboard dan gamepad (fokus otomatis ke tombol pertama, traversal Tab / Arrow keys, konfirmasi via Enter / Space / E).
   - Modal konfirmasi dua langkah saat berbagi hidangan (*"Bagikan 1 porsi hidangan ini?"* -> Ya / Batal) untuk mencegah ketidaksengajaan.
   - Integrasi transisi `ContextMode.DIALOGUE` pada `InputManager` (membebaskan kursor mouse, memblokir pergerakan first-person dan interaksi dunia selama dialog berlangsung).
6. **Integrasi Landmark Dunia 3D:**
   - Landmark 13 (`npc_neighbor_01/Interactable`) pada `scenes/main.tscn` dihubungkan ke `_on_neighbor_interacted()` pada `scripts/main.gd`.
   - Prompt HUD menampilkan `"[E] Bicara"` saat pemain membidik tetangga.
7. **Persistensi State Snapshot Envelope v1:**
   - `DialogueManager` mendukung `get_save_snapshot()` dan `load_save_snapshot(data)` mencakup `current_node_id`, `has_shared_meal`, `p0_closure_reached`, dan riwayat kunjungan node.
8. **Rangkaian Pengujian Otomatis Suite 15, Suite 16, dan Suite 17:**
   - Suite 15 (`test_social.gd`): 20 metode pengujian komprehensif menguji T43, T44, T45, penanganan edge-case inventaris kosong, pemotongan fallback peti, idempotensi sinyal P0, integrasi UI, dan anti-spam traversal.
   - Suite 16 (`test_adversarial_social.gd`): 20 metode pengujian stres inventaris 24 slot, pembatalan modal 100x button & Esc, spam 100x share, dan deteksi non-rekursi mutual.
   - Suite 17 (`test_adversarial_lock_free_p0.gd`): 6 metode pengujian invarian bebas kunci, urutan alternatif makan lalu dialog, stres pengulangan 100x, dan ketahanan save snapshot malformed.

Batas task: Persistensi menyeluruh antar sesi (penyimpanan disk, enkripsi/validasi envelope, dan auto-save) ditangani pada milestone berikutnya (`SAVE-001`).

## Perubahan dan perilaku akhir

1. **Autoload Singleton `scripts/social/dialogue_manager.gd`**:
   - Berisi definisi data 7 node percakapan, relasi graf percakapan, dan evaluasi kondisi dinamis (ketersediaan hidangan di tas/peti).
   - Menyediakan API: `start_dialogue()`, `select_choice()`, `share_dish()`, `evaluate_p0_closure()`, `has_shared_meal()`, `is_p0_completed()`, dan sinyal `dialogue_started`, `dialogue_node_changed`, `dialogue_ended`, `dish_shared`, `p0_experience_completed`.
   - Terdaftar sebagai autoload singleton di `project.godot`.
2. **Antarmuka Pengguna `scenes/ui/dialogue_ui.tscn` & `scripts/ui/dialogue_ui.gd`**:
   - Menampilkan kartu percakapan di area bawah layar dengan tata letak rapi, tipografi kontras tinggi, dan panel konfirmasi modal.
   - Mengelola transisi input context (`ContextMode.DIALOGUE`) saat buka/tutup panel.
3. **Integrasi World & Main Scene (`scripts/main.gd` & `scenes/main.tscn`)**:
   - `DialogueUI` diinstansiasi pada pohon adegan utama.
   - Interaksi pada landmark 13 (`npc_neighbor_01`) membuka antarmuka dialog secara mulus.
4. **Pembaruan Notifikasi HUD (`scripts/ui/hud.gd`)**:
   - Mendengarkan sinyal `p0_experience_completed` dari `DialogueManager` dan menampilkan banner toast selamat datang penutup P0 (*"Satu resep selesai. Kebun ini baru dimulai."*).
   - Memformat prompt objek interaktif tetangga menjadi `"[E] Bicara"`.
5. **Penyelarasan Manajer Pendukung**:
   - `scripts/cooking/kitchen_manager.gd`: Menambahkan guard `p0_completed` pada `eat_dish` agar emisi `p0_experience_completed` tidak terduplikasi saat pemain mengonsumsi lebih dari 1 hidangan, serta helper alias `reserve_ingredients` dan `start_prep`.
   - `scripts/recipe/recipe_manager.gd`: Menambahkan helper alias `mark_recipe_completed(recipe_id)`.
   - `scripts/inventory/inventory_container.gd`: Menambahkan helper alias `get_occupied_slot_count()`.

## File yang ditambahkan atau diubah

| Path Relatif | Perubahan | Tujuan |
|---|---|---|
| `scripts/social/dialogue_manager.gd` | Ditambahkan | Autoload manager logika 7-node dialog tetangga, transaksi berbagi hidangan atomik, evaluasi penutup P0, dan persistensi snapshot. |
| `scenes/ui/dialogue_ui.tscn` | Ditambahkan | Adegan antarmuka CanvasLayer 12 dialog tetangga, wadah pilihan dinamis, dan dialog modal konfirmasi. |
| `scripts/ui/dialogue_ui.gd` | Ditambahkan | Logika pengendali UI dialog, navigasi fokus keyboard/gamepad, konfirmasi berbagi, dan integrasi input mode. |
| `tests/suites/test_social.gd` | Ditambahkan | Rangkaian 20 metode pengujian komprehensif Suite 15 untuk T43, T44, T45, penutup P0, dan invarian sosial. |
| `project.godot` | Diubah | Registrasi autoload singleton `DialogueManager="*res://scripts/social/dialogue_manager.gd"`. |
| `scenes/main.tscn` | Diubah | Instansiasi node adegan `DialogueUI` pada hierarki root scene `Main`. |
| `scripts/main.gd` | Diubah | Injeksi referensi `dialogue_ui`, pendengaran interaksi landmark 13 `npc_neighbor_01`, dan pemanggilan `open()`. |
| `scripts/ui/hud.gd` | Diubah | Pendengaran sinyal `p0_experience_completed` untuk menampilkan toast penutup P0 dan format prompt `[E] Bicara`. |
| `scripts/cooking/kitchen_manager.gd` | Diubah | Penambahan guard sinyal `p0_completed` pada `eat_dish()` dan penyelarasan helper testing. |
| `scripts/recipe/recipe_manager.gd` | Diubah | Penambahan helper `mark_recipe_completed()` untuk fleksibilitas testing dan backward-compatibility. |
| `scripts/inventory/inventory_container.gd` | Diubah | Penambahan helper `get_occupied_slot_count()` untuk inspeksi kapasitas cepat. |
| `tests/test_runner.gd` | Diubah | Registrasi dan eksekusi Suite 15 (`TestSocial`), Suite 16 (`TestAdversarialSocial`), dan Suite 17 (`TestAdversarialLockFreeP0`) pada test runner headless engine. |

## Verifikasi yang benar-benar dilakukan

| ID Pemeriksaan | Lingkungan / Input | Tindakan | Hasil Nyata | Status |
|---|---|---|---|---|
| `T43.SOC-01` | Headless Engine CLI | Jalankan `test_t43_01_p0_closure_via_eating_dish` | Resep selesai + makan masakan dari tas -> `eat_dish()` sukses, `meal_used = true`, sinyal `p0_experience_completed` terpancar tepat 1 kali | LULUS |
| `T43.SOC-02` | Headless Engine CLI | Jalankan `test_t43_02_p0_closure_via_sharing_dish` | Resep selesai + berbagi hidangan ke warga -> `share_dish("backpack")` sukses, sinyal `p0_experience_completed` terpancar dengan pesan toast verbatim | LULUS |
| `T43.SOC-03` | Headless Engine CLI | Jalankan `test_t43_03_p0_closure_truth_table_both_conditions_required` | Evaluasi 4 kombinasi boolean: penutup P0 hanya bernilai true jika resep selesai DAN hidangan dikonsumsi/dibagi | LULUS |
| `T43.SOC-04` | Headless Engine CLI | Jalankan `test_t43_04_p0_closure_idempotency_no_duplicate_signal` | Konsumsi hidangan kedua tidak memancarkan ulang sinyal penutup P0 (idempotensi 100%) | LULUS |
| `T44.SOC-01` | Headless Engine CLI | Jalankan `test_t44_01_sharing_from_backpack_with_confirmation` | Pilihan `choice_share_confirm` memotong tepat 1 porsi dari tas (sisa 1 dari 2), flag `has_shared_meal = true`, transisi ke `npc_received` | LULUS |
| `T44.SOC-02` | Headless Engine CLI | Jalankan `test_t44_02_sharing_from_storage_chest_with_confirmation` | Fallback pemotongan berhasil dari peti penyimpanan rumah saat tas kosong (peti 1 -> 0, tas tetap 0) | LULUS |
| `T44.SOC-03` | Headless Engine CLI | Jalankan `test_t44_03_sharing_cancellation_preserves_stock_and_flags` | Pembatalan via `choice_share_cancel` menjaga stok tetap utuh (1 porsi), flag `meal_used` dan `has_shared_meal` tetap false, transisi kembali ke `npc_waiting` | LULUS |
| `T44.SOC-04` | Headless Engine CLI | Jalankan `test_t44_04_no_duplicate_reward_or_matter_generation` | Konservasi materi: slot tas berkurang tepat 1 tanpa menghasilkan duplikasi item atau reward siluman | LULUS |
| `T45.SOC-01` | Headless Engine CLI | Jalankan `test_t45_01_lock_free_skip_npc_complete_gardening_and_cooking` | Invarian bebas kunci: pemain dapat menanam, memasak 30s, dan menyelesaikan resep 100% tanpa pernah bicara ke NPC | LULUS |
| `T45.SOC-02` | Headless Engine CLI | Jalankan `test_t45_02_dialogue_tree_navigation_pre_sharing` | Navigasi pohon percakapan pra-berbagi: `npc_intro` -> `npc_hint_bayam` -> `npc_intro` -> `npc_hint_kunci` tervalidasi verbatim | LULUS |
| `T45.SOC-03` | Headless Engine CLI | Jalankan `test_t45_03_dialogue_repeatability_post_sharing` | Pengulangan dialog pasca berbagi: 5 siklus berulang konsisten menampilkan node ramah `npc_repeat` | LULUS |
| `T45.SOC-04` | Headless Engine CLI | Jalankan `test_t45_04_notes_repeatability_note_garden_01` | Pembacaan catatan kebun `note_garden_01` berhasil di-unlock pertama kali dan idempotent pada pembacaan kedua | LULUS |
| `EDGE.SOC-01` | Headless Engine CLI | Jalankan `test_edge_01_share_rejected_when_no_dish_anywhere` | Penolakan jujur saat tas dan peti kosong hidangan (`success = false`, `meal_used = false`) | LULUS |
| `EDGE.SOC-02` | Headless Engine CLI | Jalankan `test_edge_02_anti_spam_repeated_share_confirmation` | Anti-spam panggilan berbagi berurutan: panggilan #1 sukses, panggilan #2 langsung ditolak aman (stok 0 bukan -1) | LULUS |
| `EDGE.SOC-03` | Headless Engine CLI | Jalankan `test_edge_03_force_close_dialogue_mid_conversation_and_frame_guard` | Penutupan paksa dialog di tengah percakapan: konteks input pulih ke WORLD, simulasi lanjut, frame guard menahan aksi | LULUS |
| `EDGE.SOC-04` | Headless Engine CLI | Jalankan `test_edge_04_invalid_dialogue_choice_selection` | Pilihan ID dialog tidak valid (`choice_invalid_xyz_404`) ditolak aman tanpa merusak state percakapan | LULUS |
| `EDGE.SOC-05` | Headless Engine CLI | Jalankan `test_edge_05_eat_dish_then_talk_to_npc` | Urutan alternatif: hidangan dimakan sendiri terlebih dahulu, lalu bicara ke tetangga tidak menampilkan opsi berbagi | LULUS |
| `SAVE.SOC-01` | Headless Engine CLI | Jalankan `test_save_01_dialogue_state_snapshot_roundtrip` | Snapshot envelope v1 status dialog (`has_shared`, `talked_to_npc`) tersimpan dan pulih 100% pada instance baru | LULUS |
| `CTX.SOC-01` | Headless Engine CLI | Jalankan `test_context_01_dialogue_input_context_and_simulation_pause` | Transisi konteks `DIALOGUE` mengaktifkan status modal, menjeda simulasi dunia, dan memulihkan saat ditutup | LULUS |
| `LM.SOC-01` | Headless Engine CLI | Jalankan `test_landmark_01_npc_neighbor_scene_presence_and_interactable` | Landmark 13 `npc_neighbor_01` terpasang di `level_graybox.tscn` posisi (-14, 0, 15), layer bitmask 4, prompt `[E] Bicara` | LULUS |
| `ADV.SOC-16` | Headless Engine CLI | Jalankan Suite 16 `TestAdversarialSocial` (20 metode uji stres & batas) | Uji batas saturasi inventaris 24 slot, pembatalan modal 100x button & Esc, spam 100x share, dan deteksi non-rekursi mutual (`test_adv20`) | LULUS |
| `ADV.LF-17` | Headless Engine CLI | Jalankan Suite 17 `TestAdversarialLockFreeP0` (6 metode uji invarian & alur alternatif) | Siklus penuh zero-NPC, urutan alternatif makan lalu dialog, stres 100x dialog repetition, anti-softlock gerak pemain, dan ketahanan save snapshot malformed (`test_adv06`) | LULUS |
| `REG.FULL` | Headless Godot CLI | `godot_console.exe --headless --path . --script res://tests/test_runner.gd` | **6.402 asersi lulus, 0 gagal, Exit Code 0** (seluruh 17 test suite aktif lolos 100%) | LULUS |

## Kriteria selesai

- [x] **Pohon dialog tetangga terpasang:** 7 node dialog (`npc_intro` s.d. `npc_repeat`) terpasang lengkap dengan teks dan opsi dinamis per CONTENT § 10.
- [x] **Invarian bebas kunci (*lock-free*):** Pemain dapat menanam, memanen, dan meracik resep tanpa hambatan tanpa perlu berbicara dengan tetangga terlebih dahulu (T45).
- [x] **Berbagi hidangan atomik dengan konfirmasi:** Opsi berbagi memotong tepat 1 unit `dish_sayur_bening` dari tas/peti secara atomik dengan dialog konfirmasi dua langkah (T44).
- [x] **Penutup P0 melalui makan atau berbagi:** Kriteria penutup P0 terpenuhi secara konsisten baik hidangan dimakan sendiri atau dibagikan kepada warga (T43).
- [x] **Pemain tetap dapat melanjutkan permainan (*non-blocking*):** Notifikasi *"Satu resep selesai. Kebun ini baru dimulai."* muncul secara non-intrusif dan pemain bebas melanjutkan aktivitas (T43).
- [x] **Catatan/dialog berulang dapat diakses:** Node `npc_repeat` dapat dipicu kembali tanpa batas setelah hidangan dibagikan (T44).

## Dampak, kompatibilitas dan keterbatasan

1. **Dampak Gameplay**: Loop vertikal P0 resmi lengkap secara fungsional. Pemain dapat memulai permainan, menjelajahi pekarangan, mengolah tanah, menanam bayam, mencari temu kunci dan jagung, memasak hidangan di dapur, memakan masakan atau membagikannya ke tetangga, serta melihat penutup P0 dengan tetap dapat terus bermain.
2. **Kompatibilitas Save**: Struktur snapshot `DialogueManager` siap diintegrasikan langsung ke dalam save snapshot v1 pada milestone `SAVE-001`.
3. **Keterbatasan**: Aset visual NPC tetangga masih menggunakan graybox placeholder landmark silinder/capsule; audio sulih suara (voiceover) tidak termasuk dalam P0 per PRD dan AGENTS.md.

## Tindak lanjut dan handoff

- **Task berikutnya:** `SAVE-001` (Persistensi Lengkap Save/Load, Checkpoint, Validasi Envelope, Snapshot Swap, dan Error Recovery).
- **Prasyarat:** Seluruh data state manajer (Inventory, Kitchen, Crop, World, Recipe, Dialogue) telah menyediakan API `get_save_snapshot()` dan `load_save_snapshot()`.
- **Rujukan data:** `docs/TASKS.md` § SAVE-001, `docs/TEST_PLAN.md` (T14, T16, T17, T22, T46-T50), dan `docs/CONTENT.md`.

## Penutupan catatan

Laporan ini telah ditautkan pada `docs/PROJECT_STATUS.md`, status task `SOC-001` diperbarui menjadi `SELESAI` pada `docs/TASKS.md`, dan deskripsi status pekerjaan terakhir telah dimutakhirkan.
