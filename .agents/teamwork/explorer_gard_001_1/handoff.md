# Laporan Handoff Penyelidikan Teknis GARD-001 (Persiapan dan Perawatan Area)

**Penulis:** `explorer_gard_001_1`  
**Target Penerima:** Orchestrator (`bc3795f9-23c4-4352-8a9c-4322971bcc61`)  
**Tipe Handoff:** Hard Handoff (Penyelidikan Tuntas & Siap Eksekusi Implementasi)

---

## 1. Observation (Hasil Pengamatan Langsung)

1. **Struktur Data Dokumen Acuan (`docs/CONTENT.md`)**:
   - Baris 112–126: ID petak `plot_home_01`, luas 2 × 2 m, 4 titik dengan ID logis `slot_01` hingga `slot_04`.
   - Baris 115: Keadaan awal: `is_hoed = false`, `has_compost = false`, `nutrients = 0`, `moisture = 0`.
   - Baris 116–117: Syarat siap tanam adalah sudah gembur dan diberi pembenah. Pembenah diberikan sekali per petak dan tidak habis setelah panen.
   - Baris 118–120: Nutrisi valid 0–100. "Perlu pupuk" bila < 20, "Cukup" bila $\ge 20$. Jika nutrisi < 20, 1 pupuk (`fertilizer_basic`) mengatur nutrisi menjadi 100. Biaya panen nutrisi berkurang 5 per tanaman panen berhasil.
   - Baris 121–124: Kelembapan valid 0–100. "Kering" bila < 30, "Lembap" bila $\ge 30$. Jika kelembapan < 60, aksi memakai 2 air dan mengatur ke 80. Jika kelembapan $\ge 60$, aksi ditolak tanpa biaya. Penguapan turun 0,1 per detik simulasi aktif (minimum 0).
   - Baris 125: Syarat tumbuh adalah siap tanam (`is_hoed and has_compost`), nutrisi $\ge 20$, kelembapan $\ge 30$.
   - Baris 98–103 & 152–154: Akses alat 4 slot tetap (`tool_hoe`, `tool_seed`, `tool_fertilizer`, `tool_watering_can`). Kapasitas penyiram 10 unit abstrak, isi awal 0, isi ulang tahan E 2 detik di `water_home`.
   - Baris 164: "Istirahat adalah lompatan kalender untuk memulihkan sumber, **tidak menyimulasikan 720 detik pertumbuhan/penguapan sekaligus**. Kondisi petak dan kemajuan tanaman dipertahankan."

2. **Kriteria Selesai & Kasus Uji (`docs/TASKS.md` & `docs/TEST_PLAN.md`)**:
   - `docs/TASKS.md` (baris 77–81): "GARD-001 — Persiapan dan perawatan area. Bangun gembur, pembenah, penanaman per titik, pemupukan/air per petak, akses alat dan isi ulang. Semua aksi tahan commit sekali dan batal tanpa biaya. Selesai bila syarat dan biaya CONTENT benar, satu biaya memengaruhi seluruh petak, titik invalid ditolak, pemupukan/penyiraman berlebih tidak boros, dan seluruh prompt terbaca. T06/T07/T08/T32/T33."
   - `docs/TEST_PLAN.md`:
     - T06 (baris 38): "Isi empat titik; pupuk petak satu kali -> Satu pupuk digunakan, nutrisi petak diperbarui dan berlaku untuk semua titik."
     - T07 (baris 39): "Siram petak yang kelembapannya sudah $\ge$ ambang tidak perlu siram -> Tidak menghabiskan air; pesan kondisi cukup; tidak spam transaksi."
     - T08 (baris 40): "Tanam pada titik terisi/tanah belum siap -> Ditolak dengan alasan; benih tidak berkurang."
     - T32 (baris 64): "Tahan aksi gembur/pupuk/siram lalu batal sebelum penuh -> Tidak ada biaya/mutasi; progres dunia reset; harus melepas sebelum aksi baru."
     - T33 (baris 65): "Pakai pembenah/pupuk saat tidak perlu; ulangi isi air penuh -> Tidak boros resource; kapasitas tidak lewat maksimum; alasan benar."

3. **Kondisi Adegan 3D Eksisting (`scenes/world/level_graybox.tscn`)**:
   - Baris 585–636: Landmark `plot_home_01` ditempatkan pada posisi `(8, 0, 7)` sebagai anak langsung root adegan. Memiliki anak `SoilBed` (StaticBody3D), `Interactable` (Area3D, interaction_id = `"landmark_plot"`, layer 4), dan 4 titik tanam kuadran bernama `spot_0`, `spot_1`, `spot_2`, `spot_3` pada ketinggian $Y = 0.1$, masing-masing dengan child `Marker` (MeshInstance3D).
   - Baris 637–645: Landmark `water_home` ditempatkan pada posisi `(4, 0, 9)` dengan child `WaterBasin` (StaticBody3D).
   - `tests/suites/test_level.gd` (baris 106–118) secara eksplisit memeriksa keberadaan node anak bernama persis `"spot_0"`, `"spot_1"`, `"spot_2"`, `"spot_3"` dan memvalidasi jarak antar titik $> 0.4\text{ m}$. Node ini tidak boleh diubah namanya demi kompatibilitas regresi.

4. **Arsitektur Autoload Eksisting (`project.godot`)**:
   - `InputManager` (`scripts/core/input_manager.gd`): memiliki fungsi `is_simulation_paused() -> bool` (mengembalikan true jika konteks aktif adalah BOOK, STORAGE, DIALOGUE, atau PAUSE) dan sinyal `simulation_state_changed`.
   - `InventoryManager` (`scripts/inventory/inventory_manager.gd`): mengelola kontainer `backpack` dan `storage_home`, memiliki fungsi `get_available_item_count(item_id)` dan transaksi batch atomik.
   - `RecipeManager` (`scripts/recipe/recipe_manager.gd`): telah terpasang dan melacak resep P0.

5. **Hasil Eksekusi Test Runner Headless**:
   - Menjalankan `& "C:\Users\HP\.local\bin\godot.exe" --headless -s tests/test_runner.gd` menghasilkan exit code 0 tanpa kegagalan (seluruh 8 suite lulus).

---

## 2. Logic Chain (Rantai Penalaran)

1. **Dari Observasi 1 & 2 ke Rancangan Singleton `GardenManager`**:
   Karena status tanah, kelembapan, nutrisi, alat aktif, dan air penyiram harus bertahan lintas adegan, lintas interaksi UI, dan diikutsertakan pada serialisasi SAVE-001, maka `GardenManager` wajib dirancang sebagai Autoload Singleton pada `project.godot`.

2. **Dari Observasi 1 & 3 ke Pemetaan Data Plot dan Spot**:
   Dokumen konten menetapkan ID titik logis `slot_01`..`slot_04`, sedangkan adegan 3D graybox eksisting memakai nama node `spot_0`..`spot_3` yang dipagari oleh uji regresi `test_level.gd`. Oleh karena itu, arsitektur terbaik adalah memetakan `slot_01` <-> `spot_0`, `slot_02` <-> `spot_1`, `slot_03` <-> `spot_2`, `slot_04` <-> `spot_3` secara deterministik di dalam dictionary `spots`.

3. **Dari Observasi 1 & 4 ke Loop Penguapan (Evaporation Loop)**:
   Penguapan bernilai `0.1` per detik simulasi aktif. Dengan memanfaatkan `InputManager.is_simulation_paused()`, `GardenManager` dapat secara akurat menghentikan pengurangan kelembapan seketika jendela modal dibuka atau game dijeda. Istirahat ranjang (`bed_home`) tidak mensimulasikan penguapan, sehingga nilai kelembapan float tetap utuh saat indeks hari berganti.

4. **Dari Observasi 1, 2, & 4 ke Efek Area dan Ambang Batas (T06, T07, T33)**:
   - Pemupukan memeriksa `nutrients < 20.0`. Bila $\ge 20$, fungsi menolak transaksi sebelum memotong 1 `fertilizer_basic` dari `InventoryManager`. Jika diterima, nutrisi petak langsung diset ke `100.0` (mencakup seluruh titik).
   - Penyiraman memeriksa `moisture < 60.0` dan `watering_can_water >= 2`. Bila kelembapan $\ge 60$, fungsi menolak transaksi tanpa memotong air penyiram. Jika diterima, air berkurang 2 dan kelembapan diset ke `80.0`.
   - Pembenah tanah memeriksa `is_hoed == true` dan `has_compost == false`. Pembenah kedua ditolak tanpa memotong item.

5. **Dari Observasi 2 ke Desain Aksi Tahan (T32)**:
   Untuk memenuhi T32, timer tahan dikelola dengan status pembatalan deterministik: jika input mouse/E dilepas sebelum durasi penuh ($2.0\text{ s}$ cangkul, $1.0\text{ s}$ pupuk, $2.0\text{ s}$ siram, $2.0\text{ s}$ isi air), progress timer langsung direset ke `0.0`, dan 0 sumber daya terpakai. State `MUST_RELEASE` mencegah re-trigger otomatis tanpa melepas tombol.

---

## 3. Caveats (Batasan & Asumsi)

1. **Cakupan Penanaman (GARD-001 vs GARD-002)**:
   GARD-001 mencakup penyiapan petak (gembur, pembenah), pemupukan, penyiraman, akses alat, isi ulang air, dan penempatan benih awal pada titik (`plant_seed`). Kemajuan pertumbuhan multi-tahap (benih -> tunas -> tumbuh -> panen) dan pemanenan bayam+benih adalah ranah GARD-002. Namun struktur data `crop_data` pada titik tanam telah dirancang kompatibel ke depan.
2. **Visual Graybox vs Visual Final**:
   Sesuai `AGENTS.md` § 10, representasi visual pada tahap ini adalah pembaruan material shader/warna sederhana (tanah kering vs lembap vs gembur), belum aset 3D final tingkat produksi (yang dijadwalkan pada ART-001).
3. **Penyiram Dimulai Kosong**:
   Sesuai `CONTENT.md` § 5 baris 93, kapasitas penyiram adalah 10, tetapi pada game baru dimulai dari 0 agar pemain diarahkan mengisi air terlebih dahulu di `water_home`.

---

## 4. Conclusion (Kesimpulan & Keputusan Teknis)

1. Desain teknis arsitektur untuk `GardenManager`, data petak `plot_home_01`, 4 titik kuadran `slot_01`..`slot_04`, penguapan deterministik 0.1/s, ambang batas fertilize (<20 -> 100), ambang batas water (<60 -> 80), serta pola aksi tahan anti-bocor T32 telah dirumuskan secara lengkap di file `.agents/teamwork/explorer_gard_001_1/analysis.md`.
2. Model ini siap diimplementasikan langsung oleh implementer GARD-001 tanpa dependensi eksternal tambahan.
3. Rencana pengujian komprehensif untuk T06, T07, T08, T32, T33 telah disiapkan untuk dimasukkan ke dalam `tests/suites/test_gardening.gd`.

---

## 5. Verification Method (Metode Verifikasi Independen)

Agent atau penguji berikutnya dapat memverifikasi temuan dan rancangan ini melalui:

1. **Pemeriksaan Dokumen Sumber**:
   - `docs/CONTENT.md` § 6, 7, 8, 12 untuk mencocokkan seluruh konstanta numerik (ambang 20, ambang 60, target 100, target 80, biaya air 2, kapasitas 10, laju 0.1/s).
   - `scenes/world/level_graybox.tscn` (baris 585–636) untuk memeriksa keberadaan `plot_home_01` dan `spot_0`..`spot_3`.
   - `tests/suites/test_level.gd` (baris 106–118) untuk memeriksa kontrak integritas nama node `spot_0`..`spot_3`.
2. **Uji Regresi Proyek Saat Ini**:
   Jalankan perintah berikut di terminal:
   ```powershell
   & "C:\Users\HP\.local\bin\godot.exe" --headless -s tests/test_runner.gd
   ```
   *Kondisi invalidasi:* Exit code selain 0 atau terjadi assertion failure.
3. **Dokumen Hasil Analisis**:
   Buka dan periksa detail lengkap spesifikasi, state machine, dan diagram relasi pada:
   `.agents/teamwork/explorer_gard_001_1/analysis.md`.
