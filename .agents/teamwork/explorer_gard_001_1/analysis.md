# Cetak Biru Arsitektur Teknis GardenManager & Sistem Petak/Titik Kebun (GARD-001)

**Penulis:** explorer_gard_001_1  
**Target Milestone:** GARD-001 (Persiapan dan perawatan area)  
**Dokumen Acuan:** `PRD.md`, `docs/CONTENT.md` (§ 5, 6, 7, 8, 11, 12), `docs/TASKS.md` (GARD-001), `docs/TEST_PLAN.md` (T06, T07, T08, T32, T33), `scenes/world/level_graybox.tscn`.

---

## 1. Ringkasan Eksekutif & Prinsip Desain

Sistem berkebun pada *Buku Resep 2045* merupakan pilar pengalaman inti (P0) untuk memperoleh bahan utama resep: `ingredient_bayam` dan pemulihan `seed_bayam`. Sesuai mandat `AGENTS.md` dan `CONTENT.md`, mekanika berkebun P0 dirancang berbasis data terpusat, deterministik, tanpa random number generator (RNG) yang tidak perlu, mematuhi prinsip transaksi atomik, dan memisahkan state murni dari representasi visual 3D.

### Prinsip Utama GARD-001:
1. **Transaksional Area vs. Titik Mandiri**:
   - Pemupukan, penyiraman, penggemburan, dan pemberian pembenah adalah **transaksi satu petak penuh (2 × 2 m)**. Satu biaya bahan/air berlaku untuk seluruh petak (termasuk 4 titik di dalamnya).
   - Penanaman benih adalah **transaksi per titik (kuadran)**.
2. **Kekebalan Mutasi Sia-sia (Anti-Waste & Idempotency)**:
   - Pemupukan ketika nutrisi $\ge 20$ ditolak tanpa konsumsi pupuk (T06, T33).
   - Penyiraman ketika kelembapan $\ge 60$ ditolak tanpa konsumsi air penyiram (T07, T33).
   - Pembenah tanah hanya diberikan satu kali per petak seumur hidup kebun, tidak habis setelah panen, dan percobaan pemberian kedua ditolak tanpa konsumsi (T33).
   - Penanaman pada titik terisi atau petak belum siap ditolak tanpa konsumsi benih (T08).
3. **Penguapan Terkendali Waktu Simulasi Aktif (Deterministic Evaporation)**:
   - Kelembapan menguap tepat `0.1` unit per detik simulasi aktif (minimum 0.0).
   - Penguapan **berhenti total** saat simulasi dijeda (pause menu, buku resep, peti, dialog).
   - Istirahat ranjang (`bed_home`) adalah lompatan kalender untuk pemulihan sumber liar dan **tidak** mensimulasikan penguapan 720 detik (kelembapan dan kemajuan tanaman dipertahankan utuh).
4. **Keamanan Aksi Tahan (Hold-to-Commit Atomic Transaction)**:
   - Penggemburan (2s), pemupukan (1s), penyiraman (2s), dan pengisian air (2s) menggunakan mekanisme tahan tombol.
   - Pembatalan sebelum durasi penuh mereset progres menjadi 0.0 tanpa biaya dan tanpa mutasi state (T32).
   - Aksi commit tepat sekali; tombol harus dilepas sebelum aksi baru dapat dimulai.
5. **Kesesuaian Penuh Landmark Graybox**:
   - Landmark `plot_home_01` berada di koordinat `(8, 0, 7)`.
   - Node 3D kuadran eksisting `spot_0`, `spot_1`, `spot_2`, `spot_3` dipertahankan untuk kompatibilitas suite uji `test_level.gd` (T24.3) dan dipetakan ke ID data kanonikal `slot_01`, `slot_02`, `slot_03`, `slot_04`.

---

## 2. Arsitektur Autoload Singleton: `GardenManager`

`GardenManager` diposisikan sebagai Autoload singleton Godot 4.7 (`res://scripts/gardening/garden_manager.gd`) sejajar dengan `InputManager`, `InventoryManager`, dan `RecipeManager`.

### 2.1 Diagram Relasi Sistem
```
                +---------------------+
                |    InputManager     |  (Pause state & Context gating)
                +----------+----------+
                           |
                           v
+------------------+   +-------------------+   +--------------------+
| InventoryManager |<--|   GardenManager   |-->|   HUD / Prompt UI  |
+------------------+   +---------+---------+   +--------------------+
 (Item consumption &             |               (Threshold status &
  Capacity checking)             |                Hold progress bar)
                                 v
                       +-------------------+
                       |    GardenPlot     |  (Node3D di level_graybox.tscn)
                       +---------+---------+
                                 |
                     +-----------+-----------+
                     |                       |
                     v                       v
               +-----------+           +-----------+
               |  SoilBed  |           | 4 Spots   |
               | (Visual & |           | (slot_01..|
               |  Area3D)  |           |  slot_04) |
               +-----------+           +-----------+
```

### 2.2 Tanggung Jawab `GardenManager`
1. Menyimpan dan mengelola state seluruh petak (`_plots: Dictionary`).
2. Mengelola status alat aktif pemain (`active_tool: String`) dari 4 akses tetap.
3. Mengelola cadangan air penyiram pemain (`watering_can_water: int`, kapasitas 10).
4. Menjalankan loop penguapan berbasis `_process(delta)` yang hanya bergerak saat `InputManager.is_simulation_paused() == false`.
5. Menyediakan API transaksional validasi & eksekusi aksi kebun (`can_*` dan `do_*`).
6. Memancarkan sinyal decoupled untuk update visual 3D, pembaruan HUD, dan efek suara.
7. Menyediakan serialisasi snapshot lengkap untuk `SaveManager` (SAVE-001).

---

## 3. Spesifikasi Model Data

### 3.1 Model Data Petak (`PlotData`)
Berdasarkan `CONTENT.md` § 7 & § 12:

| Field | Tipe | Nilai Awal | Keterangan |
|---|---|---|---|
| `id` | `String` | `"plot_home_01"` | Pengenal unik petak di dunia |
| `is_hoed` | `bool` | `false` | Status gembur tanah (alat cangkul) |
| `has_compost` | `bool` | `false` | Status penambahan pembenah tanah (`soil_compost`) |
| `nutrients` | `float` | `0.0` | Nilai nutrisi petak (rentang valid: `0.0` s.d. `100.0`) |
| `moisture` | `float` | `0.0` | Nilai kelembapan petak (rentang valid: `0.0` s.d. `100.0`) |
| `spots` | `Dictionary` | `{}` | Peta 4 kuadran titik tanam (`slot_01`..`slot_04`) |

#### Status Kondisi Terhitung (Derived Properties):
- `is_ready_to_plant -> bool`: `is_hoed and has_compost`
- `can_fertilize -> bool`: `nutrients < 20.0`
- `can_water -> bool`: `moisture < 60.0`
- `is_growth_possible -> bool`: `is_ready_to_plant and nutrients >= 20.0 and moisture >= 30.0`
- `moisture_status_text -> String`:
  - `moisture < 30.0`: `"Kering"`
  - `30.0 <= moisture < 60.0`: `"Lembap — boleh disiram"`
  - `moisture >= 60.0`: `"Lembap"`
- `nutrient_status_text -> String`:
  - `nutrients < 20.0`: `"Perlu pupuk"`
  - `nutrients >= 20.0`: `"Cukup"`

### 3.2 Model Data Titik Tanam (`SpotData`)
Berdasarkan `CONTENT.md` § 7, 8, 12:

| Field | Tipe | Nilai Awal | Keterangan |
|---|---|---|---|
| `spot_id` | `String` | `"slot_01"`..`"slot_04"` | ID logis kanonikal data |
| `spot_index` | `int` | `0`..`3` | Indeks integer titik kuadran |
| `is_occupied` | `bool` | `false` | True jika terdapat benih/tanaman |
| `crop_data` | `Variant` | `null` | Dictionary state tanaman (null jika kosong) |

#### Struktur `crop_data` (Saat Terisi):
```gdscript
{
    "crop_id": "crop_bayam",
    "growth_time": 0.0,       # Akumulasi detik tumbuh efektif (0.0 s.d. 180.0)
    "growth_stage": 0,        # 0: Benih (<30s), 1: Tunas (30..<90s), 2: Tumbuh (90..<180s), 3: Siap Panen (>=180s)
    "is_ready_to_harvest": false
}
```

### 3.3 Pemetaan Node 3D Graybox ke ID Data
| Node di `level_graybox.tscn` | Koordinat Lokal terhadap Plot | ID Data Kanonikal | Posisi Kuadran |
|---|---|---|---|
| `spot_0` | `Vector3(-0.5, 0.1, -0.5)` | `"slot_01"` | Barat Laut (North-West) |
| `spot_1` | `Vector3(0.5, 0.1, -0.5)` | `"slot_02"` | Timur Laut (North-East) |
| `spot_2` | `Vector3(-0.5, 0.1, 0.5)` | `"slot_03"` | Barat Daya (South-West) |
| `spot_3` | `Vector3(0.5, 0.1, 0.5)` | `"slot_04"` | Tenggara (South-East) |

---

## 4. Mekanika Aksi Area, Ambang Batas (Thresholds) & Efek

### 4.1 Tabel Matriks Aksi dan Syarat Penerimaan
| Aksi | Input / Alat | Durasi Tahan | Syarat Pra-kondisi | Biaya Sumber Daya | Efek State Petak | Pesan / Penolakan jika Gagal |
|---|---|---|---|---|---|---|
| **Gemburkan** | `tool_hoe` (LMB) | 2.0 s | `not is_hoed` | Tidak ada | `is_hoed = true` | Jika sudah gembur: "Kondisi cukup." |
| **Pembenah** | Interaksi `[E]` | Instan | `is_hoed == true` dan `not has_compost` | 1 `soil_compost` | `has_compost = true` | Jika belum gembur: "Gemburkan tanah dan tambahkan pembenah dahulu."<br>Jika sudah ada: "Kondisi cukup. Tidak ada bahan yang digunakan."<br>Jika item 0: "Pembenah belum tersedia." |
| **Pupuk** | `tool_fertilizer` (LMB) | 1.0 s | `nutrients < 20.0` | 1 `fertilizer_basic` | `nutrients = 100.0` | Jika $\ge 20$: "Kondisi cukup. Tidak ada bahan yang digunakan."<br>Jika item 0: "Pupuk belum tersedia." |
| **Siram** | `tool_watering_can` (LMB) | 2.0 s | `moisture < 60.0` dan `water >= 2` | 2 unit air penyiram | `moisture = 80.0` | Jika $\ge 60$: "Petak sudah cukup. Tidak ada bahan yang digunakan."<br>Jika air < 2: "Air tidak cukup. Isi ulang penyiram di pekarangan." |
| **Tanam** | `tool_seed` (LMB pada titik) | Instan | `is_ready_to_plant == true` dan `not is_occupied` | 1 `seed_bayam` | `spot.is_occupied = true`, init `crop_data` | Jika belum siap: "Gemburkan tanah dan tambahkan pembenah dahulu."<br>Jika titik terisi: "Titik tanam sudah terisi."<br>Jika benih 0: "Benih belum tersedia. Periksa wadah dekat alat." |
| **Isi Air** | Interaksi `[E]` di `water_home` | 2.0 s | `watering_can_water < 10` | Bebas (sumber tak terbatas) | `watering_can_water = 10` | Jika sudah 10: "Kondisi cukup. Air sudah penuh." |

---

## 5. Loop Simulasi Penguapan (Evaporation Loop)

### 5.1 Perhitungan Matematika Determinik
Penguapan air tanah dihitung setiap frame aktif pada `_process(delta)`:
$$\Delta M = R_{\text{evap}} \times \Delta t_{\text{active}}$$
Di mana:
- $R_{\text{evap}} = 0.1 \text{ unit/detik}$ (CONTENT.md § 7 line 124)
- $\Delta t_{\text{active}} = \text{delta jika simulasi aktif, 0 jika dijeda}$
- Nilai minimum dikunci pada $0.0$:
$$M_{t+\Delta t} = \max(0.0, M_t - 0.1 \times \Delta t)$$

### 5.2 Gating Simulasi Aktif
Penguapan **hanya** berjalan jika seluruh kondisi berikut terpenuhi:
1. `not get_tree().paused`
2. `InputManager != null and not InputManager.is_simulation_paused()`
3. Konteks input aktif adalah `ContextMode.WORLD`

Jika pemain membuka `Buku Resep`, `Tas/Peti`, `Dialog NPC`, atau `Menu Pause`, `InputManager.is_simulation_paused()` mengembalikan `true`. Evaporation loop langsung membekukan delta penguapan.

### 5.3 Throttling Emisi Sinyal Kelembapan
Karena penguapan berjalan kontinyu berbasis float per-frame, emisi sinyal UI `plot_moisture_changed` di-throttle:
- Sinyal dipancarkan saat:
  1. Terjadi perubahan integer nilai kelembapan (`floor(moisture)` berubah).
  2. Terjadi transisi ambang batas kritis:
     - Melintasi 60.0 (dari status "Lembap" ke "Boleh disiram").
     - Melintasi 30.0 (dari status "Lembap — boleh disiram" ke "Kering").
     - Mencapai 0.0.
  3. Aksi penyiraman berhasil dieksekusi.

---

## 6. Arsitektur Aksi Tahan (Hold Action) & Anti-Eksploitasi (T32)

Untuk memenuhi kriteria uji T32 secara mutlak:
> "Tahan aksi gembur/pupuk/siram lalu batal sebelum penuh -> Tidak ada biaya/mutasi; progres dunia reset; harus melepas sebelum aksi baru"

### 6.1 State Machine Aksi Tahan Pemain (`HoldActionController`)
Aksi tahan dikelola melalui state machine yang tertanam pada pengontrol interaksi / alat:

```
      +-------------+
      |    IDLE     |<---------------------------------+
      +------+------+                                  |
             | LMB ditekan & Target valid              |
             v                                         |
      +-------------+  LMB dilepas sebelum t_req       |
      |   HOLDING   |--------------------------------->+ (Reset progress = 0.0,
      +------+------+  atau raycast lepas dari target  |  Biaya = 0, Mutasi = 0)
             |                                         |
             | hold_timer >= t_req                     |
             v                                         |
      +-------------+                                  |
      |  COMMITTED  | (Eksekusi atomik tepat 1 kali)   |
      +------+------+                                  |
             |                                         |
             v                                         |
      +-------------+                                  |
      | MUST_RELEASE|----------------------------------+
      +-------------+  LMB dilepas sepenuhnya
```

### 6.2 Aturan Keamanan Eksekusi:
1. **Verifikasi Kontinyu**: Selama fase `HOLDING`, sistem memeriksa setiap frame:
   - Tombol mouse kiri (atau E) masih ditekan.
   - Raycast kamera masih membidik collider petak yang sama.
   - Jarak pemain ke petak tetap dalam jangkauan interaksi ($\le 2.5\text{ m}$).
2. **Pembersihan Bersih**: Jika salah satu verifikasi kontinyu gagal sebelum durasi selesai:
   - Progres tahan langsung kembali ke `0.0`.
   - UI progress bar disembunyikan.
   - Tidak ada item tas, air penyiram, atau state petak yang terpotong/berubah.
3. **Pencegahan Spam Auto-Repeat (`MUST_RELEASE`)**:
   - Setelah aksi berhasil commit (100%), state berpindah ke `MUST_RELEASE`.
   - Meskipun pemain terus menahan klik kiri, sistem tidak akan memulai siklus tahan kedua.
   - Pemain wajib melepas tombol terlebih dahulu sebelum siklus baru dapat dimulai.

---

## 7. Integrasi dengan Adegan 3D `level_graybox.tscn`

### 7.1 Analisis Struktur Eksisting `plot_home_01`
Pada `scenes/world/level_graybox.tscn` (baris 585–636):
- Root Node: `plot_home_01` (Node3D, posisi global: `Vector3(8, 0, 7)`).
- Anak 1: `SoilBed` (StaticBody3D) dengan mesh dan collision box ($2 \times 0.15 \times 2\text{ m}$).
- Anak 2: `Interactable` (Area3D) pada collision layer 4 (`interactables`), script `interactable.gd`, `interaction_id = "landmark_plot"`.
- Anak 3..6: `spot_0`, `spot_1`, `spot_2`, `spot_3` (Node3D) pada posisi kuadran dengan mesh `Marker`.

### 7.2 Skrip Pengendali Adegan: `GardenPlot` (`scripts/gardening/garden_plot.gd`)
Skrip `GardenPlot` akan dipasang pada node `plot_home_01` untuk menyambungkan data logis `GardenManager` dengan representasi visual di dunia 3D:
1. **Binding ke GardenManager**:
   - Menghubungkan sinyal `plot_state_changed`, `plot_hoed`, `plot_composted`, `plot_fertilized`, `plot_watered`, dan `spot_planted`.
2. **Umpan Balik Visual Material Tanah**:
   - **Belum Gembur**: Tekstur/warna tanah abu-abu kecokelatan kering, permukaan rata.
   - **Gembur**: Warna tanah cokelat lebih gelap, tekstur gembur/kasar.
   - **Diberi Pembenah**: Warna tanah lebih kaya/hitam organik.
   - **Disiram (Lembap)**: Material tanah mengilap (roughness rendah, specular meningkat).
   - **Kering**: Kilau hilang, warna kembali memudar.
3. **Umpan Balik Marker Titik**:
   - Kuadran kosong: Menampilkan cincin marker tanah tipis.
   - Kuadran terisi: Memunculkan mesh tunas/benih sesuai tahap pertumbuhan.
4. **Dukungan Raycast Multi-Target (Plot vs Spot)**:
   - `SoilBed/Interactable` menangani interaksi area petak (Hoe, Compost, Fertilizer, Water, Inspect).
   - Setiap `spot_0`..`spot_3` dilengkapi sub-Area3D interaksi atau kalkulasi titik terdekat berdasarkan posisi benturan raycast (`get_collision_point()`) untuk penanaman `tool_seed` yang akurat.

---

## 8. Integrasi Antar-Sistem (Input, Inventaris, HUD, Save)

### 8.1 Integrasi dengan `InventoryManager`
1. **Pemeriksaan Stok Bebas**:
   - Memakai `InventoryManager.get_available_item_count(item_id)` untuk memastikan item tersedia di Tas atau Peti.
2. **Konsumsi Transaksional Terpadu**:
   - Konsumsi item perawatan/tanam mengikuti hierarki: Tas terlebih dahulu, lalu Peti Rumah (CONTENT § 3 line 43).
   - Implementasi helper konsumsi pada `GardenManager`:
     ```gdscript
     func _consume_item(item_id: String, count: int = 1) -> bool:
         var inv = _get_inventory_manager()
         if inv.get_available_item_count(item_id) < count:
             return false
         var bp = inv.get_container("backpack")
         var st = inv.get_container("storage")
         var from_bp = mini(count, bp.get_item_count(item_id))
         if from_bp > 0:
             bp.remove_item(item_id, from_bp)
             count -= from_bp
         if count > 0:
             st.remove_item(item_id, count)
         inv.inventory_updated.emit()
         return true
     ```

### 8.2 Integrasi dengan `HUD` (`scripts/ui/hud.gd`)
1. **Toolbelt Widget**:
   - Menampilkan 4 slot alat tetap di bagian bawah layar:
     - Slot 1: Cangkul (`tool_hoe`)
     - Slot 2: Kantong Benih (`tool_seed`)
     - Slot 3: Pupuk (`tool_fertilizer`)
     - Slot 4: Penyiram (`tool_watering_can`) dengan indikator air (misal: `8/10`)
   - Slot aktif disorot dengan bingkai terang.
2. **Prompt & Progress Tahan Dinamis**:
   - Saat membidik petak, prompt teks beradaptasi dengan alat aktif dan kondisi petak:
     - Misalnya alat aktif cangkul & petak belum gembur: `"[LMB Tahan] Gemburkan Petak"`
     - Saat menahan tombol, progress bar radial / horizontal mengisi sesuai waktu tahan (0..100%).
     - Jika kondisi tidak valid (misal: pupuk saat nutrisi 100): `"Kondisi cukup. Tidak ada bahan yang digunakan."`

### 8.3 Integrasi dengan `SaveManager` (SAVE-001)
`GardenManager` menyediakan API serialisasi persisten lengkap:
```gdscript
func get_save_snapshot() -> Dictionary:
    var plots_data: Dictionary = {}
    for p_id in _plots:
        plots_data[p_id] = _plots[p_id].duplicate(true)
    return {
        "version": 1,
        "active_tool": active_tool,
        "watering_can_water": watering_can_water,
        "plots": plots_data
    }

func load_save_snapshot(data: Dictionary) -> bool:
    if not data.has("plots"):
        return false
    active_tool = str(data.get("active_tool", ""))
    watering_can_water = int(data.get("watering_can_water", 0))
    _plots = data["plots"].duplicate(true)
    plot_state_restored.emit()
    return true
```

---

## 9. Penanganan Kasus Ekstrem & Edge Cases

| No | Situasi Ekstrem | Potensi Masalah | Penanganan Bertahan (Defensive Guard) |
|---|---|---|---|
| 1 | Pemain memupuk saat nutrisi 19.99 | Pembulatan float menyebabkan salah deteksi | Evaluasi menggunakan operator ketat `nutrients < 20.0`. Nutrisi di-set tepat `100.0`. |
| 2 | Pemain menyiram saat kelembapan 59.99 | Kelembapan melompat melampaui batas 100 | Kelembapan diset tepat `80.0` (bukan ditambah 80). Sesuai CONTENT § 7: "mengatur ke 80". |
| 3 | Penyiram kosong (0/10) dicoba dipakai | Nilai negatif air | Pengecekan pra-syarat `watering_can_water >= 2`. Jika gagal, aksi ditolak sebelum timer tahan dimulai. |
| 4 | Pemain menahan klik kiri 1.9 detik lalu mouse lepas dari petak | Aksi tereksekusi tanpa sengaja | Deteksi continuous raycast membatalkan aksi seketika raycast lepas dari collision interactable. |
| 5 | Pemain menutup game atau menu pause saat penguapan | Penguapan offline merusak tanaman | Penguapan terikat pada `_process` dan dijeda saat modal/pause aktif. Save hanya menyimpan float terakhir. |
| 6 | Pemain spam tombol klik kiri pada penanaman titik | Duplikasi benih atau penanaman ganda | Transaksi memeriksa `is_occupied == false` secara atomik dalam satu frame sebelum memotong inventaris. |
| 7 | Pembenah tanah dicoba dimasukkan sebelum dicangkul | Urutan perawatan salah | `can_add_compost` memvalidasi `is_hoed == true`. Menolak dengan pesan "Gemburkan tanah dan tambahkan pembenah dahulu." |

---

## 10. Rencana Pengujian dan Matriks Verifikasi Kasus Uji

Berikut kasus uji yang disyaratkan pada `docs/TEST_PLAN.md` beserta metode verifikasi otomatisnya:

| Kode Tes | Deskripsi Kasus Uji | Skenario Langkah Pengujian | Expected Output Penerimaan |
|---|---|---|---|
| **T06** | Pemupukan Area Petak | Isi 4 titik; jalankan `fertilize_plot("plot_home_01")` saat nutrisi < 20 | 1 pupuk terpotong dari inventaris; nutrisi petak berubah menjadi 100; berlaku untuk seluruh kuadran titik. |
| **T07** | Penolakan Penyiraman Berlebih | Atur kelembapan petak $\ge 60$ (misal 65); coba jalankan `water_plot("plot_home_01")` | Aksi ditolak (`can_water` false); air penyiram tidak berkurang; pesan "Petak sudah cukup. Tidak ada bahan yang digunakan." |
| **T08** | Penolakan Tanam Invalid | 1. Tanam di petak belum gembur/belum diberi pembenah.<br>2. Tanam di titik yang sudah terisi. | Seluruh percobaan ditolak; 0 benih terpotong dari inventaris; pesan error spesifik muncul ("Gemburkan tanah dahulu..." / "Titik tanam sudah terisi."). |
| **T32** | Pembatalan Aksi Tahan (Hold Cancel) | Mulai tahan gembur/pupuk/siram; batalkan pada 50% durasi; verifikasi state dan coba lagi tanpa melepas tombol | Progres reset ke 0.0; 0 sumber daya terpakai; state petak utuh; aksi baru tidak dimulai sebelum tombol dilepas penuh. |
| **T33** | Anti-Boros Pembenah/Pupuk & Air Penuh | 1. Berikan pembenah kedua kali pada petak.<br>2. Pupuk petak saat nutrisi 100.<br>3. Isi air saat penyiram sudah 10/10. | Seluruh aksi ditolak dengan alasan benar; tidak ada item terbuang; kapasitas air tidak melampaui 10. |

---

## 11. Rancangan Konkret Kode GDScript `GardenManager`

Berikut adalah cetak biru implementasi `res://scripts/gardening/garden_manager.gd`:

```gdscript
extends Node

## Autoload Singleton GardenManager untuk Buku Resep 2045
## Mengelola Petak (plot_home_01), Titik Kuadran (slot_01..slot_04), Penguapan, Alat, dan Air
## Memenuhi spesifikasi PRD FR07..FR10, CONTENT.md § 6, 7, 8, 12, dan TEST_PLAN T06, T07, T08, T32, T33

signal plot_state_changed(plot_id: String, plot_data: Dictionary)
signal plot_nutrients_changed(plot_id: String, new_nutrients: float)
signal plot_moisture_changed(plot_id: String, new_moisture: float)
signal plot_hoed(plot_id: String)
signal plot_composted(plot_id: String)
signal plot_fertilized(plot_id: String)
signal plot_watered(plot_id: String)
signal spot_planted(plot_id: String, spot_id: String, crop_id: String)
signal active_tool_changed(tool_id: String)
signal water_level_changed(current_water: int, max_water: int)
signal action_failed(reason: String)

const EVAPORATION_RATE: float = 0.1 # 0.1 unit per detik aktif (CONTENT § 7)
const MAX_WATERING_CAN_CAPACITY: int = 10
const WATERING_COST: int = 2
const WATERING_TARGET_MOISTURE: float = 80.0
const WATERING_THRESHOLD: float = 60.0
const FERTILIZER_TARGET_NUTRIENTS: float = 100.0
const FERTILIZER_THRESHOLD: float = 20.0

const TOOL_HOE: String = "tool_hoe"
const TOOL_SEED: String = "tool_seed"
const TOOL_FERTILIZER: String = "tool_fertilizer"
const TOOL_WATERING_CAN: String = "tool_watering_can"

var active_tool: String = ""
var watering_can_water: int = 0: # Mulai 0 di game baru (CONTENT § 5)
	set(val):
		watering_can_water = clampi(val, 0, MAX_WATERING_CAN_CAPACITY)
		water_level_changed.emit(watering_can_water, MAX_WATERING_CAN_CAPACITY)

var _plots: Dictionary = {}

var _inventory_override: Node = null
var _input_override: Node = null

func _ready() -> void:
	reset_to_defaults()

func reset_to_defaults() -> void:
	active_tool = ""
	watering_can_water = 0
	_plots.clear()
	_plots["plot_home_01"] = _create_default_plot("plot_home_01")

func _create_default_plot(p_id: String) -> Dictionary:
	var spots_dict: Dictionary = {}
	for i in range(1, 5):
		var s_id = "slot_%02d" % i
		spots_dict[s_id] = {
			"spot_id": s_id,
			"spot_index": i - 1,
			"is_occupied": false,
			"crop_data": null
		}
	return {
		"id": p_id,
		"is_hoed": false,
		"has_compost": false,
		"nutrients": 0.0,
		"moisture": 0.0,
		"spots": spots_dict
	}

# --- Service Dependency Injection ---
func set_inventory_manager(inv: Node) -> void:
	_inventory_override = inv

func _get_inventory_manager() -> Node:
	if _inventory_override != null and is_instance_valid(_inventory_override):
		return _inventory_override
	if Engine.has_singleton("InventoryManager"):
		return Engine.get_singleton("InventoryManager")
	if has_node("/root/InventoryManager"):
		return get_node("/root/InventoryManager")
	return null

func set_input_manager(im: Node) -> void:
	_input_override = im

func _get_input_manager() -> Node:
	if _input_override != null and is_instance_valid(_input_override):
		return _input_override
	if Engine.has_singleton("InputManager"):
		return Engine.get_singleton("InputManager")
	if has_node("/root/InputManager"):
		return get_node("/root/InputManager")
	return null

# --- Evaporation Simulation Loop ---
func _process(delta: float) -> void:
	var im = _get_input_manager()
	if im != null and im.has_method("is_simulation_paused"):
		if im.is_simulation_paused():
			return
	
	for p_id in _plots:
		var plot: Dictionary = _plots[p_id]
		var cur_m: float = float(plot["moisture"])
		if cur_m > 0.0:
			var new_m: float = maxf(0.0, cur_m - EVAPORATION_RATE * delta)
			plot["moisture"] = new_m
			if floori(cur_m) != floori(new_m) or new_m == 0.0:
				plot_moisture_changed.emit(p_id, new_m)

# --- Tool Management ---
func select_tool(tool_id: String) -> void:
	if active_tool == tool_id:
		active_tool = ""
	else:
		active_tool = tool_id
	active_tool_changed.emit(active_tool)

# --- Plot Operations ---
func can_hoe_plot(plot_id: String) -> Dictionary:
	if not _plots.has(plot_id):
		return {"success": false, "reason": "Petak tidak ditemukan."}
	var p: Dictionary = _plots[plot_id]
	if p["is_hoed"]:
		return {"success": false, "reason": "Kondisi cukup."}
	return {"success": true, "reason": "Dapat digemburkan."}

func hoe_plot(plot_id: String) -> bool:
	var check := can_hoe_plot(plot_id)
	if not check["success"]:
		action_failed.emit(check["reason"])
		return false
	_plots[plot_id]["is_hoed"] = true
	plot_hoed.emit(plot_id)
	plot_state_changed.emit(plot_id, _plots[plot_id])
	return true

func can_add_compost(plot_id: String) -> Dictionary:
	if not _plots.has(plot_id):
		return {"success": false, "reason": "Petak tidak ditemukan."}
	var p: Dictionary = _plots[plot_id]
	if not p["is_hoed"]:
		return {"success": false, "reason": "Gemburkan tanah dan tambahkan pembenah dahulu."}
	if p["has_compost"]:
		return {"success": false, "reason": "Kondisi cukup. Tidak ada bahan yang digunakan."}
	var inv = _get_inventory_manager()
	if inv != null and inv.get_available_item_count("soil_compost") < 1:
		return {"success": false, "reason": "Pembenah belum tersedia."}
	return {"success": true, "reason": "Dapat diberi pembenah."}

func add_compost(plot_id: String) -> bool:
	var check := can_add_compost(plot_id)
	if not check["success"]:
		action_failed.emit(check["reason"])
		return false
	if not _consume_item("soil_compost", 1):
		action_failed.emit("Pembenah belum tersedia.")
		return false
	_plots[plot_id]["has_compost"] = true
	plot_composted.emit(plot_id)
	plot_state_changed.emit(plot_id, _plots[plot_id])
	return true

func can_fertilize_plot(plot_id: String) -> Dictionary:
	if not _plots.has(plot_id):
		return {"success": false, "reason": "Petak tidak ditemukan."}
	var p: Dictionary = _plots[plot_id]
	if float(p["nutrients"]) >= FERTILIZER_THRESHOLD:
		return {"success": false, "reason": "Kondisi cukup. Tidak ada bahan yang digunakan."}
	var inv = _get_inventory_manager()
	if inv != null and inv.get_available_item_count("fertilizer_basic") < 1:
		return {"success": false, "reason": "Pupuk belum tersedia."}
	return {"success": true, "reason": "Dapat dipupuk."}

func fertilize_plot(plot_id: String) -> bool:
	var check := can_fertilize_plot(plot_id)
	if not check["success"]:
		action_failed.emit(check["reason"])
		return false
	if not _consume_item("fertilizer_basic", 1):
		action_failed.emit("Pupuk belum tersedia.")
		return false
	_plots[plot_id]["nutrients"] = FERTILIZER_TARGET_NUTRIENTS
	plot_fertilized.emit(plot_id)
	plot_nutrients_changed.emit(plot_id, FERTILIZER_TARGET_NUTRIENTS)
	plot_state_changed.emit(plot_id, _plots[plot_id])
	return true

func can_water_plot(plot_id: String) -> Dictionary:
	if not _plots.has(plot_id):
		return {"success": false, "reason": "Petak tidak ditemukan."}
	var p: Dictionary = _plots[plot_id]
	if float(p["moisture"]) >= WATERING_THRESHOLD:
		return {"success": false, "reason": "Petak sudah cukup. Tidak ada bahan yang digunakan."}
	if watering_can_water < WATERING_COST:
		return {"success": false, "reason": "Air tidak cukup. Isi ulang penyiram di pekarangan."}
	return {"success": true, "reason": "Dapat disiram."}

func water_plot(plot_id: String) -> bool:
	var check := can_water_plot(plot_id)
	if not check["success"]:
		action_failed.emit(check["reason"])
		return false
	watering_can_water -= WATERING_COST
	_plots[plot_id]["moisture"] = WATERING_TARGET_MOISTURE
	plot_watered.emit(plot_id)
	plot_moisture_changed.emit(plot_id, WATERING_TARGET_MOISTURE)
	plot_state_changed.emit(plot_id, _plots[plot_id])
	return true

func can_refill_water() -> Dictionary:
	if watering_can_water >= MAX_WATERING_CAN_CAPACITY:
		return {"success": false, "reason": "Kondisi cukup. Air sudah penuh."}
	return {"success": true, "reason": "Dapat diisi ulang."}

func refill_water() -> bool:
	var check := can_refill_water()
	if not check["success"]:
		action_failed.emit(check["reason"])
		return false
	watering_can_water = MAX_WATERING_CAN_CAPACITY
	return true

func can_plant_seed(plot_id: String, spot_id: String, seed_id: String = "seed_bayam") -> Dictionary:
	if not _plots.has(plot_id):
		return {"success": false, "reason": "Petak tidak ditemukan."}
	var p: Dictionary = _plots[plot_id]
	if not (p["is_hoed"] and p["has_compost"]):
		return {"success": false, "reason": "Gemburkan tanah dan tambahkan pembenah dahulu."}
	var spots: Dictionary = p["spots"]
	if not spots.has(spot_id):
		return {"success": false, "reason": "Titik tanam tidak valid."}
	if spots[spot_id]["is_occupied"]:
		return {"success": false, "reason": "Titik tanam sudah terisi."}
	var inv = _get_inventory_manager()
	if inv != null and inv.get_available_item_count(seed_id) < 1:
		return {"success": false, "reason": "Benih belum tersedia. Periksa wadah dekat alat."}
	return {"success": true, "reason": "Dapat ditanam."}

func plant_seed(plot_id: String, spot_id: String, seed_id: String = "seed_bayam") -> bool:
	var check := can_plant_seed(plot_id, spot_id, seed_id)
	if not check["success"]:
		action_failed.emit(check["reason"])
		return false
	if not _consume_item(seed_id, 1):
		action_failed.emit("Benih belum tersedia.")
		return false
	var spot: Dictionary = _plots[plot_id]["spots"][spot_id]
	spot["is_occupied"] = true
	spot["crop_data"] = {
		"crop_id": "crop_bayam",
		"growth_time": 0.0,
		"growth_stage": 0,
		"is_ready_to_harvest": false
	}
	spot_planted.emit(plot_id, spot_id, "crop_bayam")
	plot_state_changed.emit(plot_id, _plots[plot_id])
	return true

func _consume_item(item_id: String, count: int = 1) -> bool:
	var inv = _get_inventory_manager()
	if inv == null:
		return true
	if inv.get_available_item_count(item_id) < count:
		return false
	var bp = inv.get_container("backpack")
	var st = inv.get_container("storage")
	var from_bp = mini(count, bp.get_item_count(item_id))
	if from_bp > 0:
		bp.remove_item(item_id, from_bp)
		count -= from_bp
	if count > 0 and st != null:
		st.remove_item(item_id, count)
	inv.inventory_updated.emit()
	return true
```

---

## 12. Rekomendasi Urutan Implementasi untuk Agent Penerus

1. **Langkah 1**: Daftarkan file singleton `res://scripts/gardening/garden_manager.gd` dan pasang pada `project.godot` di bawah section `[autoload]`.
2. **Langkah 2**: Buat skrip `res://scripts/gardening/garden_plot.gd` untuk node `plot_home_01` di `level_graybox.tscn` guna menghubungkan sinyal visual material tanah dan kuadran titik tanam.
3. **Langkah 3**: Tambahkan interaksi pengisian air pada landmark `water_home` (`res://scripts/world/water_source.gd`).
4. **Langkah 4**: Hubungkan kontrol pemilihan alat angka 1–4 pada `PlayerController` / `InputManager` dan tambahkan widget indikator toolbelt pada `HUD`.
5. **Langkah 5**: Tulis suite uji otomatis komprehensif `tests/suites/test_gardening.gd` yang memverifikasi T06, T07, T08, T32, T33, serialisasi snapshot, serta penguapan deterministik, dan integrasikan ke `tests/test_runner.gd`.
