# DISPATCH — worker_gard_002: Implementasi Pertumbuhan 4 Tahap Bayam & Pemanenan Atomik (GARD-002)

## 2026-10-27T19:15:00Z

### 1. Peran & Identitas
- **Archetype**: `teamwork_worker`
- **Role**: Gardening Growth & Harvesting Worker (GARD-002)
- **Working Directory**: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\worker_gard_002\`
- **Parent**: `orchestrator_gen4` (`bc3795f9-23c4-4352-8a9c-4322971bcc61`)

### 2. Dokumen Sumber Wajib Dibaca
1. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md` (Wajib dibaca secara utuh)
2. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_gard_002_1\handoff.md` (Spesifikasi pertumbuhan 4 tahap, timing, stall)
3. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_gard_002_2\handoff.md` (Spesifikasi pemanenan atomik 2-slot, deduksi nutrisi, raycast)
4. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_gard_002_3\handoff.md` (Spesifikasi tes T05, T34, T35, T36 dan harness stress)
5. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_gard_002_3\proposed_test_gardening_methods.gd` (Implementasi metode tes)
6. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_gard_002_3\proposed_stress_invariants_extension.gd` (Ekstensi stress invariants)
7. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\docs\CONTENT.md` (§ 8, § 3, § 11)
8. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\docs\PROTOTYPE.md` (§ 5)
9. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\PRD.md` (FR07, FR08, FR09, FR10, FR11)
10. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\AGENTS.md` (§ 4, § 6, § 7)

### 3. MANDATORY INTEGRITY WARNING
> DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

### 4. Instruksi Tugas Implementasi Konkret

#### A. Pertumbuhan Tanaman di `scripts/garden/garden_manager.gd`
1. Struktur data tanaman pada spot:
   - Tambahkan/perluas `crop_data` pada dictionary spot:
     - `crop_id: String` (misal `"crop_spinach"` atau `"bayam"`)
     - `growth_stage: int` (0: Seed `0..<30s`, 1: Sprout `30..<90s`, 2: Growing `90..<180s`, 3: Harvestable `>=180s`)
     - `growth_time: float` (waktu aktif terakumulasi dalam detik, clamped ke 180.0)
     - `is_ready_to_harvest: bool` (true jika `growth_stage == 3` / `>= 180s`)
2. Logika pertumbuhan dalam `simulate_process(delta: float)` / loop proses:
   - Evaluasi setiap spot yang memiliki tanaman (`is_occupied == true` dan `crop_data != null`).
   - Cek syarat pertumbuhan: `moisture >= 30.0` DAN `nutrients >= 20.0` pada petak yang bersangkutan.
   - Jika syarat terpenuhi: tambahkan `delta` ke `crop_data["growth_time"]`, mutasikan `growth_stage` sesuai rentang waktu, dan jika mencapai 180.0s set `is_ready_to_harvest = true` serta pancarkan sinyal `crop_stage_changed(plot_id, spot_id, stage)`.
   - Jika syarat TIDAK terpenuhi (kelembapan < 30 atau nutrisi < 20): pertumbuhan stall (timer tidak bertambah), namun tanaman tidak mati, layu, atau berkurang nilainya.
   - Simulasi jeda (pause gating): Jangan tambah waktu pertumbuhan jika game sedang pause atau InputManager tidak berada pada konteks aktif dunia.

#### B. Pemanenan Atomik di `scripts/garden/garden_manager.gd` & `scripts/inventory/inventory_manager.gd`
1. Tambahkan method `can_harvest(plot_id: String, spot_id: String) -> Dictionary`:
   - Validasi: spot valid, tanaman ada, `is_ready_to_harvest == true`.
   - Pengecekan kapasitas tas pemain (dry-run):
     - Hasil panen: 1x `ingredient_bayam` + 1x `seed_bayam`.
     - Tas (backpack) harus memiliki kapasitas untuk KEDUA item sekaligus.
     - Gunakan dry-run pada `InventoryManager` (`can_add_batch` atau simulasi penambahan 2 item).
     - Kembalikan `{"success": true}` jika muat, atau `{"success": false, "message": "Tas tidak cukup. Kosongkan slot atau simpan barang di rumah."}` jika tas penuh / kurang dari 2 slot.
2. Tambahkan method `harvest_crop(plot_id: String, spot_id: String) -> Dictionary`:
   - Panggil `can_harvest(plot_id, spot_id)`. Jika gagal, return pesan penolakan tanpa memutasi apapun.
   - Jika berhasil:
     - Tambahkan 1 `ingredient_bayam` ke tas pemain.
     - Tambahkan 1 `seed_bayam` ke tas pemain.
     - Kurangi nutrisi petak sebanyak 5 poin: `nutrients = maxf(0.0, nutrients - 5.0)`.
     - Kosongkan tanaman dari spot: `is_occupied = false`, `crop_data = null`.
     - Spot tetap dalam keadaan `is_tilled = true` (gembur) sehingga pemain dapat langsung menanam benih kembali tanpa perlu mencangkul ulang.
     - Pancarkan sinyal `crop_harvested(plot_id, spot_id)`.
     - Kembalikan `{"success": true, "items": [{"id": "ingredient_bayam", "quantity": 1}, {"id": "seed_bayam", "quantity": 1}]}`.

#### C. Integrasi Interaksi Player & Reticle di `scripts/player/player_controller.gd`
1. Saat reticle mengarah ke titik tanam dengan tanaman yang sudah siap panen (`is_ready_to_harvest == true`), prompt interaksi menampilkan:
   `[E] Panen Bayam`
2. Menekan tombol `interact` (E) pada titik tersebut mengeksekusi `GardenManager.harvest_crop()`.
3. Jika ditolak karena tas tidak cukup, tampilkan pesan umpan balik jujur 2.5s ("Tas tidak cukup...").

#### D. Visualisasi Tanaman di `scenes/world/plot.tscn` / `scenes/world/level_graybox.tscn`
1. Pastikan titik tanam `spot_0`..`spot_3` memperbarui visual mesh/node sesuai `growth_stage`:
   - Stage 0 (Seed): mesh kecil / indikator benih (skala ~0.15)
   - Stage 1 (Sprout): tunas kecil (skala ~0.4)
   - Stage 2 (Growing): tanaman sedang tumbuh daun (skala ~0.75)
   - Stage 3 (Harvestable): tanaman rimbun bayam matang (skala 1.0)
   - Saat dipanen: visual crop disembunyikan/dihapus.

#### E. Pengujian Komprehensif
1. Tambahkan metode uji baru ke `tests/suites/test_gardening.gd` (ambil dari rancangan `explorer_gard_002_3/proposed_test_gardening_methods.gd`):
   - `test_t34_crop_growth_4_stages` (T05/T34)
   - `test_t34_crop_growth_stall_conditions` (T34)
   - `test_t35_atomic_harvesting_yield_and_replanting` (T35)
   - `test_t36_atomic_harvesting_capacity_rejection` (T36)
   - Sambungkan ke `run_all()`.
2. Perluas `tests/stress_garden_invariants.gd` dengan Challenge 7–10 dari `explorer_gard_002_3/proposed_stress_invariants_extension.gd`.
3. Jalankan seluruh suite verifikasi dan pastikan 100% LULUS dengan Exit Code 0:
   - `tests/test_runner.gd` (semua 9 suite harus lulus).
   - `tests/stress_garden_invariants.gd` (seluruh challenge harus lulus).
   - `tests/stress_hold_actions.gd` (1,679 asersi harus tetap lulus 100%).
   - `python check_godot_project.py .` (0 error, 0 warning).
   - Headless smoke run `scenes/main.tscn` (60 frame).

#### F. Dokumentasi Tugas Selesai (AGENTS.md § 6 & § 7)
1. Tentukan nomor laporan berikutnya: periksa laporan terbesar di `docs/completed_tasks/`. Nomor berikutnya adalah `010`.
2. Buat berkas `docs/completed_tasks/010-pertumbuhan-bayam-4-tahap-pemanenan-atomik.md` menggunakan `docs/completed_tasks/TEMPLATE.md`.
3. Perbarui `docs/PROJECT_STATUS.md`:
   - Tambahkan bullet baru pada **Pekerjaan yang Sudah Selesai**: `10. [GARD-002: Pertumbuhan 4 Tahap Bayam & Pemanenan Atomik](completed_tasks/010-pertumbuhan-bayam-4-tahap-pemanenan-atomik.md)`.
   - Ganti isi **Deskripsi Status Pekerjaan Terakhir** (target 150–300 kata) merangkum kondisi sistem pasca GARD-002.
4. Perbarui `docs/TASKS.md`: tandai `GARD-002` sebagai `SELESAI` dan tautkan ke laporan `010`.
5. Tulis laporan handoff lengkap di `.agents/teamwork/worker_gard_002/handoff.md` dan kirim pesan notifikasi ke orchestrator via `send_message`.

## 2026-10-27T19:31:09Z

Heartbeat query from parent orchestrator:
**Context**: Liveness status check for worker_gard_002 (GARD-002).
**Content**: Heartbeat check: `progress.md` timestamp is at 19:15:00Z. What is your current progress on implementing crop growth, atomic harvesting, and test extensions?
**Action**: Please provide a brief status update and update your `progress.md` heartbeat.
