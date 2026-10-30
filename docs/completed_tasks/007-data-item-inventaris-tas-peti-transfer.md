# Laporan Selesai: Data Item dan Inventaris Tas & Peti, Transfer Dua Arah, dan Paket Awal (INV-001)

Dokumen ini mencatat penyelesaian implementasi task INV-001 sesuai aturan kerja `AGENTS.md` § 6.

## Identitas

- **ID task:** INV-001
- **Judul:** Data item dan inventaris tas & peti, transfer dua arah, dan paket awal
- **Tanggal selesai:** 27 Oktober 2026
- **Agent/pelaksana:** worker_inv_001 (teamwork_worker)
- **Tahap produk:** P0 (Item Data, Dual Inventory Container, Atomic Transfers, Starter Pickup & UI)
- **Status:** Selesai (Lulus 100% verifikasi headless, 606 asersi lulus, 0 gagal, exit code 0)
- **Versi sumber/build:** Git working tree lokal, Godot 4.7.2-stable official

## Tujuan dan pemicu

Sesuai spesifikasi `PRD.md` FR05/FR06, `docs/TASKS.md` (bagian INV-001), `docs/CONTENT.md` § 2, 3, 5, `docs/PROTOTYPE.md` § 6.1, `docs/UI_UX.md` UI04, dan kasus uji `docs/TEST_PLAN.md` T02, T03, T04, T05, T29, T30, T31, T32, T33:
1. Game membutuhkan sistem inventaris inti untuk menampung item berkebun, memasak, dan hasil panen tanpa risiko kehilangan atau penggandaan item.
2. Definisi data item harus bertipe statis dan terpusat berdasarkan kamus item resmi `CONTENT.md` § 2 (7 item inti P0 dengan batas tumpukan 20 unit per slot, alat berada di luar slot tas).
3. Kontainer Tas Pemain (12 slot) dan Peti Penyimpanan Rumah (12 slot) harus mengimplementasikan transaksi atomik 2-fase: dry-run pengecekan kapasitas terlebih dahulu sebelum mutasi fisik dilakukan.
4. Tidak boleh ada transfer parsial diam-diam: jika kontainer tujuan tidak dapat menampung seluruh unit yang ingin dipindahkan, transaksi ditolak utuh dan umpan balik kesalahan jujur (honest error feedback) diberikan kepada pemain (T30).
5. Paket Wadah Awal (`container_starter`) di pekarangan harus dapat diambil sekaligus (4x `seed_bayam`, 1x `soil_compost`, 1x `fertilizer_basic`) jika tas memiliki minimal 3 slot kosong, dengan flag anti-spam yang mencegah pengambilan ganda (T04, T31).
6. Subsistem kalkulasi stok bebas bersama (`get_available_item_count`) harus mengagregasi isi tas dan peti dikurangi reservasi dapur secara akurat untuk kebutuhan buku resep (T02, T31).
7. Antarmuka UI CanvasLayer responsif menyediakan tampilan Solo (saat Tab ditekan di dunia) dan tampilan Dual (saat pemain berinteraksi dengan Peti Rumah), terintegrasi dengan konteks input `InputManager.ContextMode.STORAGE` untuk mencegah aksi bocor (zero bleed-through).

## Ruang lingkup

Ruang lingkup yang diselesaikan dalam task ini:
- `scripts/inventory/item_data.gd`: Kelas `ItemData` berbasis `Resource` dengan properti bertipe statis (`id`, `display_name`, `name`, `category`, `max_stack = 20`, `description`, `icon`, `icon_color`), serta serialisasi dictionary `to_dict()` dan deserialisasi `from_dict()`.
- `scripts/inventory/items_data.gd` & `scripts/inventory/item_registry.gd`: Katalog dan registri sentral 7 item P0 resmi `CONTENT.md` § 2 (`seed_bayam`, `soil_compost`, `fertilizer_basic`, `ingredient_bayam`, `ingredient_jagung`, `ingredient_temu_kunci`, `dish_sayur_bening`) + `water_fresh`, serta resolusi alias transparan (`crop_bayam` -> `ingredient_bayam`, `tool_fertilizer` -> `fertilizer_basic`).
- `scripts/inventory/inventory_slot.gd`: Model data satu slot inventaris (`RefCounted`) yang menegakkan invarian kapasitas 0..20, pembersihan otomatis ID saat jumlah 0, proteksi rekursi setter, serta metode mutasi `add()`, `remove()`, `clear()`, dan serialisasi dictionary.
- `scripts/inventory/inventory_container.gd`: Model kontainer 12 slot tetap dengan batas tumpukan 20. Menyediakan simulasi kapasitas multi-item atomik (`can_add_batch`), penambahan batch atomik (`add_batch`), penghapusan batch (`remove_batch`), mutasi slot indeks terkecil, dan serialisasi save data murni (`to_array`, `from_array`).
- `scripts/inventory/inventory_manager.gd`: Autoload singleton (`*res://scripts/inventory/inventory_manager.gd`) yang mengelola Tas (`backpack`), Peti Rumah (`storage_home`), dan Refund Dapur (`kitchen_refund`). Mengimplementasikan pemindahan dua arah atomik (`transfer_item`, `transfer_slot`, `transfer_all`), penarikan paket starter pekarangan (`pickup_starter_container`, `claim_starter_container`), kalkulator stok bebas bersama (`get_available_item_count`), validasi kapasitas panen 2-item (`can_harvest`), kontrak reservasi memasak, serta sinyal event bus inventaris.
- `project.godot`: Pendaftaran autoload singleton `InventoryManager="*res://scripts/inventory/inventory_manager.gd"`.
- `scripts/ui/inventory_slot_ui.gd`: Komponen tombol slot inventaris berbasis `Button` dengan fallback warna kategori dinamis, label jumlah tumpukan (> 1), dan dukungan navigasi keyboard focus.
- `scenes/ui/inventory_ui.tscn` & `scripts/ui/inventory_ui.gd`: Scene antarmuka `CanvasLayer` (layer 10) dengan tata letak responsif 1280x720 canvas_items, latar redup semi-transparan, panel utama 12 slot tas + 12 slot peti, tombol transfer pilihan/semua, panel detail item, label status umpan balik, dan mode tampilan Solo (Tab) vs Dual (E pada peti).
- Integrasi Landmark & Input: Penautan interaksi `landmark_starter` (ambil wadah awal dan pembaruan prompt menjadi "Wadah Kosong") dan `landmark_storage` (buka dual mode inventaris) di `scripts/main.gd`, serta penambahan instance `InventoryUI` pada `scenes/main.tscn`.
- Test Suite: Pembuatan suite pengujian komprehensif `tests/suites/test_inventory.gd` (8 metode pengujian unit & integrasi untuk T02, T03, T04, T29, T30, T31, T32, T33) dan pendaftaran sebagai Suite 7 pada `tests/test_runner.gd`.

Batas cakupan: Antarmuka buku resep dan pelacakan pin/unpin dibangun pada `BOOK-001`, mekanik persiapan lahan dan penyiraman pada `GARD-001`, pertumbuhan tanaman dan eksekusi panen kebun pada `GARD-002`, serta pemrosesan memasak dapur pada `COOK-001/002`.

## Perubahan dan perilaku akhir

- **Batas Kapasitas dan Pengisian Tumpukan (T02, T29):** Setiap slot dibatasi secara ketat maksimal 20 unit. Menambahkan unit ke-21 pada item yang sama secara otomatis membuka slot kosong berikutnya dengan isi 1 unit. Tas dan peti memiliki tepat 12 slot (kapasitas total 240 unit). Menambahkan jenis item ke-13 ketika seluruh 12 slot terisi ditolak secara aman (`can_add == false`, 0 mutasi parsial).
- **Transfer Dua Arah Atomik & Pencegahan Transfer Parsial (T03, T30):** Pemindahan item antara tas dan peti rumah melalui `transfer_item`, `transfer_slot`, atau `transfer_all` melakukan simulasi dry-run pada kontainer tujuan terlebih dahulu. Jika kontainer tujuan penuh atau tidak dapat menampung seluruh unit yang diminta, transaksi ditolak utuh, pesan umpan balik *"Penyimpanan tidak cukup. Tidak ada barang yang dipindahkan."* dipancarkan, dan tidak ada satu unit pun yang berpindah. Jumlah item terjaga 100% konsisten (zero loss, zero duplication).
- **Pengambilan Paket Awal Pekarangan & Anti-Spam (T04, T31):** Pemain yang menekan tombol E pada `container_starter` di pekarangan menerima paket 4x `seed_bayam`, 1x `soil_compost`, dan 1x `fertilizer_basic` secara atomik jika tas memiliki minimal 3 slot kosong. Jika tas hanya memiliki < 3 slot kosong, transaksi ditolak utuh dan wadah tidak termutasi. Setelah berhasil diambil, flag `starter_claimed` terkunci menjadi `true` dan prompt di dunia berubah menjadi `[E] Wadah Kosong`. Spam interaksi berulang ditolak bersih tanpa duplikasi item.
- **Kalkulator Stok Bebas Bersama (T02, T31):** Fungsi `get_available_item_count(item_id)` menjumlahkan stok di tas dan peti dikurangi reservasi aktif dapur. Pemindahan item antara tas dan peti tidak pernah mengubah nilai return fungsi ini.
- **Pemeriksaan Kapasitas Panen 2-Item (T05):** Fungsi `can_harvest()` melakukan simulasi apakah tas dapat menampung hasil panen bayam pekarangan (1 bayam + 1 benih bayam). Jika tas tidak memiliki ruang untuk kedua item tersebut, panen ditolak sebelum tanaman di kebun dipotong.
- **Antarmuka UI Responsif & Konteks Input (T32, T33):**
  - Menekan tombol Tab di dunia membuka tampilan Solo (hanya tas) dan membebaskan mouse (`InputManager.ContextMode.STORAGE`).
  - Menekan tombol E pada peti rumah membuka tampilan Dual (tas di sebelah kiri, peti di sebelah kanan, tombol transfer di bawah tiap grid).
  - Menutup antarmuka dengan Esc atau Tab memulihkan mouse captured ke dunia first-person dengan proteksi frame guard untuk mencegah aksi dunia bocor.

## File yang ditambahkan atau diubah

| Path Relatif | Jenis Perubahan | Tujuan |
|---|---|---|
| `scripts/inventory/item_data.gd` | Baru | Resource template data item statis (id, display_name, category, max_stack=20, description, icon_color, dict helpers) |
| `scripts/inventory/items_data.gd` | Baru | Katalog dan registri 7 item resmi CONTENT.md § 2 + water_fresh + alias crop_bayam & tool_fertilizer |
| `scripts/inventory/item_registry.gd` | Baru | Subclass / alias ItemRegistry untuk interoperabilitas pemanggilan lintas modul |
| `scripts/inventory/inventory_slot.gd` | Baru | RefCounted slot data dengan penjaga invarian kapasitas 0..20, setter anti-recursion, dan serialisasi |
| `scripts/inventory/inventory_container.gd` | Baru | RefCounted container 12 slot, transaksi atomik 2-fase dry-run (add_batch, remove_batch), dan array serialisasi |
| `scripts/inventory/inventory_manager.gd` | Baru | Autoload singleton pengelola tas, peti, refund, transfer atomik, paket starter, stok bebas, dan reservasi |
| `project.godot` | Diubah | Mendaftarkan autoload `InventoryManager="*res://scripts/inventory/inventory_manager.gd"` |
| `scripts/ui/inventory_slot_ui.gd` | Baru | Button control slot UI dengan fallback warna kategori, label kuantitas, dan navigasi fokus keyboard |
| `scenes/ui/inventory_ui.tscn` | Baru | Scene CanvasLayer responsif untuk inventaris (mode solo & dual, 12+12 slot grid, tombol aksi transfer) |
| `scripts/ui/inventory_ui.gd` | Baru | Skrip pengendali UI inventaris terhubung dengan InventoryManager dan InputManager |
| `scripts/main.gd` | Diubah | Menghubungkan landmark_starter dan landmark_storage dengan InventoryManager dan InventoryUI |
| `scenes/main.tscn` | Diubah | Menginstansiasi InventoryUI CanvasLayer di dalam adegan utama |
| `tests/suites/test_inventory.gd` | Baru | Suite pengujian otomatis komprehensif INV-001 (8 metode pengujian untuk T02, T03, T04, T29, T30, T31, T32, T33) |
| `tests/test_runner.gd` | Diubah | Mendaftarkan dan mengeksekusi Suite 7: TestInventory pada harness pengujian utama |

## Verifikasi yang benar-benar dilakukan

| ID Uji | Lingkungan / Perintah | Tindakan | Hasil Nyata | Status |
|---|---|---|---|---|
| UJI-RUN-ALL | `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd"` | Menjalankan seluruh test runner otomatis (Suite 1..7) | 606 asersi lulus, 0 gagal, exit code 0 | LULUS |
| UJI-ADV-LVL | `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless -s tests/adversarial_level_challenge.gd"` | Menjalankan tantangan ketahanan level dan 18 landmark | 95 asersi lulus, 0 gagal, exit code 0 | LULUS |
| UJI-CHK-PRJ | `python ".agents/skills/godot-nodes-scenes/scripts/check_godot_project.py" .` | Validasi konsistensi struktur node, scene, skrip, dan UID | 0 errors, 0 warnings pada 44 file | LULUS |
| UJI-SMK-60F | `cmd /c "C:\Users\HP\.local\bin\godot.exe --headless --scene res://scenes/main.tscn --fixed-fps 60 --quit-after 60"` | Smoke run 60 frame main.tscn dengan inventaris, interaksi, dan UI | 60 frame dieksekusi bersih tanpa runtime error/warning | LULUS |

## Kriteria selesai

- [x] 1. Angka kapasitas awal cocok dengan CONTENT.md § 3 (Tas 12 slot, Peti 12 slot, batas tumpukan 20 unit per slot, alat di luar slot).
- [x] 2. Registri item mendefinisikan 7 item P0 resmi (`seed_bayam`, `soil_compost`, `fertilizer_basic`, `ingredient_bayam`, `ingredient_jagung`, `ingredient_temu_kunci`, `dish_sayur_bening`) + `water_fresh` dan resolusi alias transparan.
- [x] 3. Pickup paket awal (`container_starter`) memberikan 4 benih bayam, 1 pembenah tanah, 1 pupuk; spam E ditolak bersih tanpa penggandaan (T04).
- [x] 4. Transfer dua arah tas–peti berjalan atomik tanpa kehilangan atau duplikasi barang (T03).
- [x] 5. Kontainer penuh memberikan alasan penolakan yang jelas dan membatalkan seluruh transaksi tanpa mutasi parsial (T30).
- [x] 6. Pengambilan starter crate ditolak utuh jika tas kekurangan slot (< 3 slot kosong) (T31).
- [x] 7. Seluruh hasil panen (2 item: bayam + benih) dapat diperiksa kapasitasnya terlebih dahulu lewat fungsi `can_harvest()` (T05).
- [x] 8. UI CanvasLayer responsif menampilkan slot tas dan peti dengan nama dan jumlah yang terlihat jelas, serta mendukung mode solo (Tab) dan dual (E pada peti) (T32).
- [x] 9. Integrasi konteks input `InputManager.ContextMode.STORAGE` membebaskan kursor dan mencegah aksi bocor saat ditutup (T33).
- [x] 10. Seluruh suite pengujian otomatis (`tests/test_runner.gd`) lulus 100% tanpa kegagalan (606 asersi lulus, exit code 0).

## Dampak, kompatibilitas dan keterbatasan

- **Kepatuhan Data & Kontrak:** Seluruh ID item konsisten huruf kecil snake_case mengikuti `CONTENT.md` § 2. Alias `crop_bayam` dan `tool_fertilizer` menjamin kompatibilitas penuh dengan kode atau event lama.
- **Kesiapan Modul Berikutnya:**
  - `BOOK-001`: Metode `get_available_item_count(item_id)` siap dipakai langsung oleh Recipe Tracker untuk menghitung stok bebas tanpa memedulikan lokasi item di tas atau peti (T11/T31).
  - `GARD-001/GARD-002`: Metode `can_harvest()` dan `add_batch()` siap dipakai untuk memeriksa dan mengeksekusi panen bayam 2-item.
  - `COOK-001`: Kontrak `reserve_ingredients()`, `cancel_reservation()`, dan `commit_consumption()` sudah tersedia di `InventoryManager`.
  - `SAVE-001`: Struktur snapshot murni `get_save_snapshot()` dan `load_save_snapshot()` menjamin serialisasi save game JSON bebas dari referensi Resource engine.
- **Keterbatasan Visual Tahap P0:** Ikon item menggunakan kode warna kategori geometris responsif (`ColorFallback`) karena aset tekstur 2D final baru akan diproduksi pada milestone `ART-001`.

## Tindak lanjut dan handoff

- **Task berikutnya:** `BOOK-001` (Buku Resep dan Tracker).
- **Prasyarat yang telah terpenuhi:** Sistem inventaris tas dan peti, registri item P0, dan kalkulator stok bebas bersama `get_available_item_count()` telah beroperasi penuh dan terverifikasi.
- **Fokus pekerjaan `BOOK-001`:** Membangun antarmuka buku resep keluarga (`scenes/ui/book_ui.tscn`), resep tunggal Sayur Bening Bayam dan Jagung (3 bayam, 1 jagung, 1 temu kunci), penandaan lacak/berhenti (pin/unpin) pada HUD tracker, petunjuk perolehan bahan, dan catatan lingkungan pekarangan.

## Penutupan catatan

Laporan ini telah dicatat dan ditautkan pada `docs/PROJECT_STATUS.md` serta diperbarui pada `docs/TASKS.md` sesuai dengan aturan penutupan task `AGENTS.md` § 6.
