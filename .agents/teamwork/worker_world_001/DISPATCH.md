## 2026-10-28T03:13:09Z
Anda adalah Worker untuk milestone WORLD-001 pada proyek game Buku Resep 2045.

Bekerjalah di direktori metadata Anda:
`c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_world_001\`

DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Wajib membaca dokumen berikut sebelum mulai bekerja:
1. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md`
2. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\orchestrator_gen5\PROJECT.md`
3. Laporan handoff ketiga Explorer:
   - `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_world_001_1\handoff.md` (Foraging & Cadangan Darurat)
   - `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_world_001_2\handoff.md` (Isi Ulang Air & Hold Controller)
   - `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_world_001_3\handoff.md` (Siklus Hari, Kasur Istirahat, & Test Suite T09/T37/T38/T39)
4. Dokumen spesifikasi: `docs/TASKS.md` (§ WORLD-001), `docs/CONTENT.md` (§ 5, § 6, § 9, § 11, § 12), `docs/PROTOTYPE.md` (§ 5.1), `docs/TEST_PLAN.md` (T09, T37, T38, T39), `AGENTS.md`.
5. Skills gamedev relevan: `.agents/skills/godot-gdscript/SKILL.md`, `.agents/skills/godot-nodes-scenes/SKILL.md`, `.agents/skills/godot-signals-groups/SKILL.md`, `.agents/skills/godot-gdscript-headless-testing/SKILL.md`, `.agents/skills/save-systems/SKILL.md`, `.agents/skills/game-ui-ux/SKILL.md`.

TUGAS IMPLEMENTASI LENGKAP:
1. Buat Autoload `WorldResourceManager` di `scripts/world/world_resource_manager.gd` dan daftarkan ke `project.godot`:
   - State siklus hari: `current_day: int = 1`, `day_active_time: float = 0.0`, `DAY_DURATION: float = 720.0`.
   - `_process(delta)` menghitung `day_active_time` saat simulasi berjalan. Jika `day_active_time >= DAY_DURATION`, naikkan `current_day += 1` dan reset `day_active_time = 0.0`.
   - Foraging harian: dictionary `last_harvested_day` menyimpan hari panen per node (`resource_jagung_01` -> `ingredient_jagung`, `resource_temu_kunci_01` -> `ingredient_temu_kunci`).
   - `can_harvest_foraging(node_id: String) -> Dictionary`: tolak jika sudah diambil hari ini (`"Sumber daya sudah diambil hari ini. Tunggu besok."`), tolak jika tas penuh (`"Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."`), lolos jika valid.
   - `harvest_foraging(node_id: String) -> bool`: transaksi atomik, menambahkan 1 item ke tas via `InventoryManager`, mencatat `last_harvested_day`, memancarkan sinyal.
   - Titik cadangan darurat (`reserve_home`):
     - Prasyarat gerbang: `is_starter_collected() == true`. Jika false, tolak: `"Ambil wadah awal dekat alat terlebih dahulu."`.
     - Jika true, cek darurat:
       - Benih: jika `get_available_item_count("seed_bayam") == 0` DAN seluruh 4 spot di `plot_home_01` kosong (`is_occupied == false`), berikan paket 4 `seed_bayam`. Jika masih ada benih di tas/peti atau ada tanaman hidup, tolak dan beri petunjuk lokasi/tanaman (T38).
       - Pembenah: jika petak sudah digembur (`is_hoed == true`) tapi belum berkompos (`has_compost == false`) dan stok bebas `soil_compost` == 0, berikan 1 `soil_compost`.
       - Pupuk: jika nutrisi petak `< 20.0` dan stok bebas `fertilizer_basic` == 0, berikan 1 `fertilizer_basic`.
       - Jika tidak darurat: tolak jujur `"Kondisi cadangan belum terpenuhi. Pasokan darurat hanya tersedia jika kehabisan bahan."`.
   - Kasur istirahat (`bed_home`):
     - Tolak jika ada job dapur aktif.
     - Lolos: naikkan `current_day += 1`, reset `day_active_time = 0.0`.
     - **INVARIAN KRITIS**: JANGAN sekali-kali mempercepat atau menyimulasikan pertumbuhan/penguapan kebun saat tidur! Tanaman dan kondisi petak dipertahankan persis.
     - Pulihkan kuota panen harian untuk jagung & temu kunci.
   - Integrasikan save snapshot `get_save_snapshot()` dan `load_save_snapshot(data)`.
2. Hubungkan landmark dunia di `scripts/main.gd`:
   - Hubungkan interaksi `landmark_jagung`, `landmark_temu_kunci`, `landmark_reserve`, `landmark_bed`, `landmark_water` ke `WorldResourceManager`.
3. Perbarui tampilan prompt dan umpan balik di `scripts/ui/hud.gd`:
   - Prompt kontekstual dinamis untuk landmark jagung, temu kunci, cadangan, kasur tidur, dan air.
4. Buat test suite lengkap di `tests/suites/test_world.gd` (mencakup T09, T37, T38, T39, dan snapshot roundtrip), serta daftarkan ke `tests/test_runner.gd` sebagai Suite 10.
5. Jalankan verifikasi pengujian headless:
   `& "C:\Users\HP\.local\bin\godot.exe" --headless --script tests/test_runner.gd`
   Pastikan seluruh test (Suite 1..10) lulus 100% tanpa error/warning.
6. Buat laporan penyelesaian tugas terperinci di:
   `docs/completed_tasks/011-sumber-pemulihan-jagung-temu-kunci-air-cadangan-istirahat.md` (mengikuti `docs/completed_tasks/TEMPLATE.md`).
7. Perbarui `docs/PROJECT_STATUS.md` (150-300 kata deskripsi status terkini, tambahkan bullet task selesai 011).
8. Perbarui `docs/TASKS.md` (tandai WORLD-001 sebagai SELESAI dan tautkan laporan 011).
9. Tulis laporan handoff lengkap di direktori kerja Anda:
   `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_world_001\handoff.md`

Kirim pesan konfirmasi singkat via send_message setelah semua langkah selesai.


## 2026-10-28T03:34:16Z
**Context**: Implementasi Milestone WORLD-001
**Content**: Memeriksa status pengerjaan implementasi WORLD-001. Apakah proses pengujian headless dan pembuatan laporan 011 sedang berjalan atau ada kendala/blocker yang dihadapi?
**Action**: Berikan ringkasan kemajuan status Anda saat ini.
