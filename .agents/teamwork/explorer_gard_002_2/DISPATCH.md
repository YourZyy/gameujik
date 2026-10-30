# DISPATCH — explorer_gard_002_2: Atomic Harvesting & Inventory Interaction Explorer (GARD-002)

## 2026-10-27T19:05:00Z

### 1. Peran & Identitas
- **Archetype**: `teamwork_explorer`
- **Role**: Atomic Harvesting & Inventory Interaction Explorer
- **Working Directory**: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\explorer_gard_002_2\`
- **Parent**: `orchestrator_gen4` (`bc3795f9-23c4-4352-8a9c-4322971bcc61`)

### 2. Dokumen Sumber Wajib Dibaca
1. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\.agents\teamwork\ORIGINAL_REQUEST.md` (Wajib dibaca secara utuh)
2. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\docs\CONTENT.md` (§ 8 Pemanenan, § 3 Transaksi Atomik)
3. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\docs\PROTOTYPE.md` (§ 5.2 Pemanenan Atomik)
4. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\PRD.md` (FR09, FR10, NFR05)
5. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\scripts\garden\garden_manager.gd`
6. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\scripts\inventory\inventory_manager.gd`
7. `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\scripts\player\player_controller.gd`

### 3. Lingkup Investigasi
1. Mekanisme pemanenan (Harvesting):
   - Input trigger: aksi tombol E saat mengarahkan reticle ke titik tanam yang tanamannya berada di Stage 4 (Harvestable), atau interaksi petak jika spot terdeteksi.
   - Pengecekan pra-syarat kapasitas inventaris (2 slot kosong):
     - Pemanenan bayam menghasilkan 2 item: 1x `crop_spinach` + 1x `seed_spinach`.
     - Tas pemain (backpack, kapasitas 12) harus memiliki ruang untuk KEDUA item tersebut. Jika tas hanya memiliki 1 slot kosong atau 0 slot kosong, pemanenan DITOLAK secara atomik.
     - Penolakan harus mengeluarkan notifikasi error ("Tas penuh!", CONTENT § 11) dan TIDAK BOLEH memutasi tanaman atau nutrisi petak.
2. Eksekusi pemanenan atomik (2-phase commit):
   - Dry-run: cek `can_add_item` untuk `crop_spinach` (qty 1) dan `seed_spinach` (qty 1) di backpack.
   - Commit: tambahkan 1 `crop_spinach`, tambahkan 1 `seed_spinach`.
   - Kurangi nutrisi petak sebanyak 5 poin (`nutrients = maxf(0.0, nutrients - 5.0)`).
   - Reset spot state: status spot kembali ke `tilled` (siap ditanami benih kembali tanpa perlu dicangkul ulang), atau apakah perlu dicangkul lagi? Cek spesifikasi di CONTENT.md & PROTOTYPE.md.
3. Petakan integrasi antarmuka antara `PlayerController` dan `GardenManager`:
   - Bagaimana raycast player membedakan interaksi petak secara umum vs interaksi spesifik titik tanam (`spot_0`..`spot_3`) untuk pemanenan.
4. Tulis laporan handoff lengkap di `.agents/teamwork/explorer_gard_002_2/handoff.md` (5 komponen).
5. Kirim pesan notifikasi selesai via `send_message`.
