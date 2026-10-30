# Synthesis Report — Milestone SAVE-001: Persistensi Lengkap Save/Load, Checkpoint, Validasi Envelope, Snapshot Swap, dan Error Recovery

**Target Milestone:** `SAVE-001` (Milestone 13)  
**Orchestrator:** `orchestrator_gen8`  
**Date:** 2026-10-29  
**Inputs:**
- Explorer 1 (`0cb43a54-891f-4112-8710-955527794238`): Arsitektur SaveManager, skema envelope v1, atomic file write via `.tmp`, backup rotation `.bak`, auto-recovery, dan `settings.cfg`.
- Explorer 2 (`d187cab5-40c5-4ba9-b620-b5add6d818f3`): Kontrak serialisasi dinamis (`get_save_snapshot` & `load_save_snapshot`) pada 7 manajer, validasi pra-swap two-phase commit, dan T22 player safe coordinates.
- Explorer 3 (`6043f0bb-e10d-41ee-b512-db2ea7a1525f`): Spesifikasi test suite penerimaan `tests/suites/test_save.gd` (Suite 19) mencakup T14, T16, T17, T22, T46, T47, T48, T49, T50 di sandbox `user://test_save_sandbox/`.

---

## 1. Consensus & Core Architecture

1. **Autoload Singleton `SaveManager` (`scripts/save/save_manager.gd`)**:
   - Terdaftar di `project.godot` di bawah `InputManager` dan sebelum manajer gameplay, atau setelah manajer gameplay (`res://scripts/save/save_manager.gd="*res://scripts/save/save_manager.gd"`).
   - Mengelola checkpoint manual (`user://save_manual.json`), autosave (`user://save_autosave.json`), dan cadangan valid masing-masing (`.bak`).
   - Algoritma resolusi "Lanjutkan" (Continue) memilih slot valid dengan `revision` terbesar (monotonik naik) (T48).
   - Pengaturan pemain disimpan 100% terpisah di `user://settings.cfg` (`ConfigFile`), tidak tersentuh saat New Game atau Muat Save lama (T49, T52).

2. **Skema Envelope v1**:
   ```json
   {
     "schema_version": 1,
     "slot_type": "manual",
     "revision": 1,
     "timestamp_unix": 1793232000,
     "timestamp_iso": "2026-10-29T02:00:00Z",
     "game_version": "0.1.0",
     "checksum": "<sha256_text_of_payload_canonical_json>",
     "payload": {
       "player": { ... },
       "inventory": { ... },
       "recipe": { ... },
       "gardening": { ... },
       "world": { ... },
       "cooking": { ... },
       "dialogue": { ... }
     }
   }
   ```

3. **Two-Phase Commit Pre-Swap Validation (T16, T17, T47)**:
   - **Fase 1 (Validasi Pasif)**: Memverifikasi header envelope, membandingkan checksum SHA-256 payload, dan memvalidasi keberadaan seluruh 7 domain section serta format tipe data (`backpack`, `plots`, `job_state`, dll.). Memvalidasi tidak ada ID item asing (unknown item IDs).
   - Jika Fase 1 gagal: **Dilarang memutasi state live** ("zero half-loaded world"). Coba pulihkan cadangan `.bak` yang sesuai. Jika `.bak` valid, muat dari `.bak` dan pancarkan sinyal `save_recovered_from_backup`. Jika keduanya gagal, laporkan kegagalan secara transparan tanpa mengubah memori aktif.
   - **Fase 2 (Aplikasi State Terpadu)**: Terapkan snapshot secara berurutan ke `InventoryManager`, `RecipeManager`, `GardenManager`, `WorldResourceManager`, `KitchenManager`, `DialogueManager`, dan `PlayerController`.

4. **Atomic File Write Protocol on Windows (T22, T47, T49)**:
   - Tulis payload ke `<path>.tmp`.
   - `flush()` dan `close()`.
   - Verifikasi bahwa `<path>.tmp` ada dan memiliki `size > 0`.
   - Jika `<path>` (file utama) sudah ada:
     - Hapus `<path>.bak` jika ada (`DirAccess.remove_absolute`).
     - Ganti nama `<path>` menjadi `<path>.bak` (`DirAccess.rename_absolute`).
   - Ganti nama `<path>.tmp` menjadi `<path>`.
   - Jika terjadi kegagalan pada tahap mana pun: bersihkan `.tmp`, pertahankan berkas target dan cadangan lama, kembalikan status gagal (T49).

5. **Sanitasi Koordinat Pemain Aman (T22)**:
   - Parameter batas ruang: $X \in [-42.0, 42.0]$, $Z \in [-37.0, 47.0]$, $Y \ge -5.0$.
   - Jika koordinat bernilai `NaN`, `Inf`, atau di luar batas level graybox, alihkan posisi secara otomatis ke titik aman `safe_return_home` `Vector3(0.0, 0.0, 8.0)` tanpa merusak inventaris, resep, atau progres quest.

6. **Konsistensi Pertanian & Dapur**:
   - `GardenManager.load_save_snapshot()` wajib memancarkan sinyal visual `plot_state_changed` dan `water_level_changed` agar adegan 3D sinkron pasca-load.
   - `KitchenManager`: jika dimuat dari status `COOKING`, job dipulihkan dalam status `PAUSED` saat pemain kembali ke dunia agar pemain tidak terhukum waktu offline (T14). Slot output hidangan bersifat tunggal dan idempotent (T50).

---

## 2. Test Suite Specification (`tests/suites/test_save.gd`)

Suite 19 didaftarkan di `tests/test_runner.gd` dan menjalankan minimal 25 asersi mencakup:
- **T14**: Simpan saat tanaman tumbuh dan job dijeda; muat memulihkan kemajuan tanaman, job timer, reservasi bahan, alat aktif, dan level air.
- **T16**: Dua-fase validasi; reject payload yang kehilangan section wajib tanpa merusak data memori yang sedang aktif.
- **T17**: File korup/rusak/0-byte memicu fallback otomatis ke `.bak` valid dan memancarkan sinyal `save_recovered_from_backup`.
- **T22**: Validasi posisi pemain dialihkan ke `(0, 0, 8)` jika koordinat `NaN`, `Inf`, atau out-of-bounds, serta uji crash resistance saat penulisan dipotong.
- **T46**: Snapshot komparasi sebelum simpan vs sesudah muat memulihkan seluruh 7 subsistem secara identik.
- **T47**: Penulisan atomik via `.tmp` -> rename, simulasi berkas versi tidak cocok/ID item tak dikenal ditolak tanpa merusak dunia aktif.
- **T48**: Pengujian multi-slot manual vs autosave, pemilihan "Lanjutkan" berbasis revisi terbaru, dan pemuatan eksplisit manual.
- **T49**: Isolasi `user://settings.cfg`, persistensi konfigurasi FOV/sensitivitas/audio tanpa terpengaruh oleh aksi save/load/new game.
- **T50**: Idempotensi pengambilan hidangan matang (`dish_output_slot`) dan invariant kekekalan materi bahan reservasi.

---

## 3. Implementation Directive for Worker

1. `scripts/save/save_manager.gd`: Buat Autoload singleton lengkap sesuai blueprint.
2. `project.godot`: Daftarkan `SaveManager="*res://scripts/save/save_manager.gd"`.
3. `scripts/player/player_controller.gd`: Tambahkan `get_save_snapshot() -> Dictionary` dan `load_save_snapshot(data: Dictionary) -> bool` dengan validasi boundary T22.
4. `scripts/gardening/garden_manager.gd`: Pastikan emisi sinyal `plot_state_changed` dan `water_level_changed` terpancar di `load_save_snapshot()`.
5. `tests/suites/test_save.gd`: Tulis test suite komprehensif menguji T14, T16, T17, T22, T46-T50 menggunakan sandbox terisolasi `user://test_save_sandbox/`.
6. `tests/test_runner.gd`: Daftarkan Suite 19 (`TestSave`).
7. Jalankan Godot CLI headless dan verifikasi 100% tes lulus dengan exit code 0.
8. Buat `docs/completed_tasks/015-persistensi-lengkap-save-load-slot-backup.md`, perbarui `docs/PROJECT_STATUS.md` dan `docs/TASKS.md`.
