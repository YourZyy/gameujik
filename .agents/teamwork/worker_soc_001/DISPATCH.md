## 2026-10-28T18:36:24Z
Kamu bertugas sebagai worker_soc_001 (Gameplay & Systems Worker) untuk mengimplementasikan milestone SOC-001 pada proyek Buku Resep 2045.

Working directory kamu: c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_soc_001\

BACA TERLEBIH DAHULU:
1. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md
2. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen8\PROJECT.md
3. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen8\synthesis_soc_001.md
4. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_soc_001_1\analysis.md
5. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_soc_001_2\analysis.md
6. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_soc_001_3\analysis.md
7. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\docs\CONTENT.md (§ 10, § 11)
8. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\docs\TEST_PLAN.md (T43, T44, T45)
9. c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\AGENTS.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

TUGAS UTAMA IMPLEMENTASI:
1. Bangun `scripts/social/dialogue_manager.gd`:
   - Singleton autoload `DialogueManager` di `project.godot`.
   - Pohon dialog 7 node sesuai `CONTENT.md § 10`: `npc_intro`, `npc_hint_bayam`, `npc_hint_kunci`, `npc_waiting`, `npc_offer`, `npc_received`, `npc_repeat`.
   - Logika berbagi hidangan `share_meal(from_source = "auto")`: validasi ketersediaan `dish_sayur_bening`, pemotongan atomik 1 porsi (tas prioritas, peti fallback), sinkronisasi flag `meal_used = true` di DialogueManager, WorldResourceManager, dan KitchenManager.
   - Pemicu penutup P0: jika resep sayur bening telah selesai dan `meal_used == true`, pancarkan sinyal `p0_experience_completed` dan tampilkan notifikasi toast *"Satu resep selesai. Kebun ini baru dimulai."* tanpa membekukan gerak pemain di dunia (bebas lanjut bermain).
   - Invarian bebas penguncian: loop berkebun dan memasak dapat diselesaikan mandiri tanpa pernah bicara ke NPC; dialog dan catatan dapat dibaca ulang berkali-kali tanpa korupsi state.
2. Bangun `scenes/ui/dialogue_ui.tscn` dan `scripts/ui/dialogue_ui.gd`:
   - Modal dialog berlatar gelap semi-transparan, header nama tokoh ("Tetangga"), penampil teks narasi, kontainer tombol pilihan dinamis dengan navigasi keyboard/gamepad focus.
   - Popup konfirmasi berbagi hidangan ("Bagikan 1 porsi hidangan ini?") dengan tombol [Ya, Bagikan] dan [Batal].
   - Integrasi `InputManager.ContextMode.DIALOGUE`: bebaskan kursor mouse, bekukan gerak/kamera, jeda simulasi kebun, supresi aksi 'interact' saat membuka dialog, dan guard frame saat menutup dialog agar tidak bocor ke dunia.
3. Sambungkan landmark 3D `npc_neighbor_01`:
   - Pasang instance `DialogueUI` di `scenes/main.tscn`.
   - Sambungkan interaksi landmark 13 di `scripts/main.gd` ke pembukaan dialog `DialogueUI.open_dialogue("npc_neighbor_01")`.
4. Bangun Test Suite 15 di `tests/suites/test_social.gd`:
   - 16 metode pengujian komprehensif mencakup T43, T44, T45, penolakan saat stok 0, pembatalan konfirmasi, anti-spam, frame guard, dan non-blocking continuation.
   - Daftarkan Suite 15 ke `tests/test_runner.gd`.
5. Eksekusi pengujian nyata via run_command:
   - Jalankan `godot --headless --script res://tests/test_runner.gd`.
   - Pastikan seluruh suite (Suite 1 s/d 15) lulus 100% tanpa error, dan catat log output serta jumlah asersi yang lulus.
6. Penutupan task sesuai AGENTS.md § 6:
   - Buat laporan bernomor `docs/completed_tasks/014-interaksi-sosial-warga-dialog-berbagi-hidangan.md` menggunakan `TEMPLATE.md`.
   - Perbarui `docs/PROJECT_STATUS.md` (bagian Pekerjaan Selesai dan ringkasan 150-300 kata di status terakhir).
   - Perbarui `docs/TASKS.md` (tandai SOC-001 SELESAI dan tautkan laporan 014).
