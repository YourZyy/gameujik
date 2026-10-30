# Laporan Analisis Teknis Mendalam: Dialogue Systems, Pohon Dialog Warga, Aksi Berbagi Hidangan, dan Penutup P0 (Milestone SOC-001)

**Penulis:** `explorer_soc_001_1` (Dialogue Systems Explorer)  
**Target Milestone:** `SOC-001` (Interaksi Sosial Tetangga, Pohon Dialog, Berbagi Hidangan, & Penutup P0)  
**Tanggal:** 28 Oktober 2026  
**Dokumen Acuan:** `docs/CONTENT.md` (§ 10, § 11), `docs/TEST_PLAN.md` (T43, T44, T45), `docs/UI_UX.md` (UI07, § 3, § 4), `orchestrator_gen8/PROJECT.md`, `AGENTS.md`  

---

## 1. Ringkasan Eksekutif & Batasan Masalah

Milestone `COOK-002` telah berhasil menyelesaikan seluruh alur memasak aktif hingga menghasilkan hidangan `dish_sayur_bening` di slot output, pencatatan resep selesai di `RecipeManager`, serta konsumsi makan hidangan dari tas (`eat_dish`) dengan verifikasi 4.024 asersi (Exit Code 0).

Milestone berikutnya, `SOC-001`, bertugas merealisasikan sistem sosial dan percakapan warga, yang berpusat pada:
1. **Autoload Singleton `DialogueManager` (`scripts/social/dialogue_manager.gd`)** untuk mengelola state percakapan, pohon dialog, evaluasi syarat ketersediaan hidangan, transaksi berbagi makanan, dan pemicu penutup P0.
2. **Pohon Dialog Tetangga (`npc_neighbor_01`)** yang memuat 7 node naratif resmi sesuai `CONTENT.md § 10`: `npc_intro`, `npc_hint_bayam`, `npc_hint_kunci`, `npc_waiting`, `npc_offer`, `npc_received`, dan `npc_repeat`.
3. **Logika Aksi Berbagi Hidangan (`action_share`)** dengan konfirmasi eksplisit dua langkah, pemotongan tepat 1 unit `dish_sayur_bening` (prioritas tas, fallback peti rumah), pembatalan aman tanpa mutasi, sinkronisasi flag global `meal_used = true` lintas manajer (`DialogueManager`, `WorldResourceManager`, `KitchenManager`), dan proteksi anti-spam idempotensi (T44).
4. **Pemicu Penutup Pengalaman P0** yang mengevaluasi `recipe_completed` dan `meal_used`, memancarkan umpan balik resmi *"Satu resep selesai. Kebun ini baru dimulai."* (`CONTENT.md § 11`).
5. **Invarian Bebas Penguncian (T45)**: Menjamin pemain bebas menjelajah, memanen, dan memasak sebelum berbicara dengan NPC tanpa mengunci sumber daya liar, serta dapat membuka ulang dialog berkali-kali untuk membaca petunjuk tanpa softlock.

Laporan ini bersifat **read-only investigation** untuk memberikan cetak biru arsitektur lengkap kepada implementer (`worker_soc_001`).

---

## 2. Analisis Titik Integrasi dan Status Modul Eksisting

Berdasarkan pemeriksaan mendalam terhadap skrip dan adegan yang ada:

### 2.1. `WorldResourceManager` (`scripts/world/world_resource_manager.gd`)
- **Observasi Baris 35 & 41–48**:
  Variabel `meal_used: bool = false`, fungsi `set_meal_used(val: bool)`, `is_meal_used() -> bool`, dan sinyal `meal_consumed(item_id: String, count: int)` sudah tersedia.
- **Observasi Baris 308–341**:
  Metode `get_save_snapshot()` dan `load_save_snapshot()` telah menyerialisasi `"meal_used": meal_used`.
- **Integrasi SOC-001**:
  Saat `DialogueManager.share_dish()` berhasil commit, `WorldResourceManager.set_meal_used(true)` harus dipanggil agar flag tersinkronisasi secara global.

### 2.2. `KitchenManager` (`scripts/cooking/kitchen_manager.gd`)
- **Observasi Baris 46, 78, 117, 728–787**:
  - `const DISH_ITEM_ID: String = "dish_sayur_bening"`
  - `signal p0_experience_completed()`
  - `var meal_used: bool = false`
  - Metode `eat_dish()` memotong 1 hidangan dari tas, menyetel `meal_used = true`, memanggil `WorldResourceManager.set_meal_used(true)`, dan memancarkan `p0_experience_completed()` jika `RecipeManager.is_recipe_completed(RECIPE_P0) == true`.
- **Integrasi SOC-001**:
  `DialogueManager.share_dish()` harus memperbarui `KitchenManager.meal_used = true` (atau helper `set_meal_used(true)` jika dibuat) agar status kedua modul konsisten dan tidak terjadi perbedaan state saat query status makan/berbagi.

### 2.3. `InventoryManager` (`scripts/inventory/inventory_manager.gd`)
- **Observasi Baris 281–295 (`get_available_item_count`)**:
  Menghitung agregat stok bebas tas (`backpack`) dan peti rumah (`storage_home`).
- **Observasi Baris 74–84 (`get_container`)**:
  Menyediakan akses terisolasi ke kontainer `backpack` (`"backpack"`) dan `storage_home` (`"storage"`).
- **Integrasi SOC-001**:
  - Pengecekan hidangan:
    ```gdscript
    var bp_count: int = inv.backpack.get_item_count("dish_sayur_bening")
    var st_count: int = inv.storage_home.get_item_count("dish_sayur_bening")
    var has_dish: bool = (bp_count + st_count) >= 1
    ```
  - Pemotongan berbagi:
    Dipotong dari `backpack` terlebih dahulu jika `bp_count >= 1`. Jika tidak ada di tas namun tersedia di peti rumah, dipotong dari `storage_home` (memenuhi `CONTENT.md § 10`: *"Mengonsumsi dari peti untuk berbagi diperbolehkan sebagai kemudahan P0; teks menyebut stok rumah bila relevan"*).

### 2.4. `InputManager` (`scripts/core/input_manager.gd`)
- **Observasi Baris 11 & 58**:
  - `enum ContextMode { WORLD, BOOK, STORAGE, KITCHEN, DIALOGUE, PAUSE }` telah memiliki `ContextMode.DIALOGUE`.
  - Fungsi `is_simulation_paused()` sudah menyertakan `ContextMode.DIALOGUE`:
    ```gdscript
    func is_simulation_paused() -> bool:
        var ctx := get_current_context()
        return ctx in [ContextMode.BOOK, ContextMode.STORAGE, ContextMode.DIALOGUE, ContextMode.PAUSE]
    ```
- **Integrasi SOC-001**:
  Saat dialog dibuka: `InputManager.push_context(InputManager.ContextMode.DIALOGUE)`.
  Saat dialog ditutup: `InputManager.consume_and_close(&"interact")` (mencegah klik penutup bocor dan membebaskan/menangkap mouse kembali secara otomatis).

### 2.5. Level & Landmark (`scenes/world/level_graybox.tscn` & `scripts/world/level_graybox.gd`)
- **Observasi Baris 829–852 di `scenes/world/level_graybox.tscn`**:
  Node `npc_neighbor_01` (Node3D transform `-14, 0, 15`) telah memiliki child `Bench` (bangku duduk), `Mesh`, dan `Interactable` (Area3D layer 4 mask 0, `interaction_id = "landmark_neighbor"`, `prompt_action = "Bicara"`).
- **Integrasi SOC-001**:
  `scripts/main.gd` perlu menyambungkan sinyal `interactable.interacted` dari `npc_neighbor_01` ke pembukaan antarmuka `DialogueUI`.

### 2.6. HUD (`scripts/ui/hud.gd`)
- **Observasi Baris 469–473**:
  Format prompt interaksi telah memanggil `interactable.get_prompt_text()`. Namun, helper `format_contextual_prompt` dapat diperkaya untuk `landmark_neighbor` agar menampilkan `"[E] Bicara dengan Tetangga"`.
- **Integrasi SOC-001**:
  HUD perlu mendengarkan sinyal penutup P0 (`p0_experience_completed` atau umpan balik `action_success`) untuk menampilkan banner/toast resmi:
  *"Satu resep selesai. Kebun ini baru dimulai."* (`CONTENT.md § 11`).

---

## 3. Arsitektur `DialogueManager` (`scripts/social/dialogue_manager.gd`)

### 3.1. Struktur Autoload Singleton
`DialogueManager` dirancang sebagai autoload singleton yang mewarisi `Node`. Singleton ini memisahkan logika data dan evaluasi state dari rendering tampilan UI (`DialogueUI`), sehingga dapat diuji secara headless 100% tanpa GUI.

```
                    ┌────────────────────────┐
                    │    DialogueManager     │
                    │   (Autoload / Logic)   │
                    └───────────┬────────────┘
                                │
        ┌───────────────────────┼────────────────────────┐
        ▼                       ▼                        ▼
┌───────────────┐       ┌───────────────┐        ┌───────────────┐
│ InventoryMgr  │       │ WorldResMgr   │        │  KitchenMgr   │
│ (Stok Hidang) │       │ (meal_used)   │        │  (P0 Ending)  │
└───────────────┘       └───────────────┘        └───────────────┘
        ▲                       ▲                        ▲
        └───────────────────────┼────────────────────────┘
                                │
                    ┌───────────┴────────────┐
                    │       DialogueUI       │
                    │  (CanvasLayer / View)  │
                    └────────────────────────┘
```

### 3.2. Sinyal-Sinyal Resmi
```gdscript
signal dialogue_started(npc_id: String, node_id: String)
signal dialogue_node_changed(node_id: String, data: Dictionary)
signal dialogue_choice_selected(choice_id: String, target_node: String)
signal dialogue_closed(npc_id: String)
signal dish_shared(item_id: String, count: int, source: String)
signal meal_consumed(item_id: String, count: int)
signal p0_experience_completed()
signal action_failed(reason: String)
signal action_success(action_name: String, message: String)
```

### 3.3. State & Flags Internal
```gdscript
var has_spoken_intro: bool = false    # True setelah percakapan pertama selesai/dimulai
var has_shared_meal: bool = false     # True setelah tepat 1 porsi hidangan diberikan ke tetangga
var meal_used: bool = false           # Flag global pemakaian hidangan (makan atau berbagi)
var dialogue_flags: Dictionary = {}   # Catatan percakapan: {"hint_bayam_seen": true, ...}
var current_npc_id: String = ""
var current_node_id: String = ""
var is_dialogue_active: bool = false

# Overrides untuk headless testing & modul isolasi
var _inventory_override: Node = null
var _recipe_override: Node = null
var _kitchen_override: Node = null
var _world_override: Node = null
var _input_override: Node = null
```

### 3.4. Kontrak Antarmuka (Interface Contracts)
Sesuai dengan `orchestrator_gen8/PROJECT.md`:
1. `has_dish() -> bool`:
   Memeriksa apakah terdapat minimal 1 unit `dish_sayur_bening` di tas atau peti rumah.
2. `get_dish_source() -> String`:
   Mengembalikan `"backpack"` jika ada di tas, `"storage"` jika hanya ada di peti, atau `""` jika kosong.
3. `get_starting_dialogue_node(npc_id: String = "npc_neighbor_01") -> String`:
   Mengembalikan node awal sesuai status permainan (`npc_repeat`, `npc_offer`, `npc_intro`, atau `npc_waiting`).
4. `start_dialogue(npc_id: String = "npc_neighbor_01", initial_node: String = "") -> Dictionary`:
   Memulai sesi dialog, mengunci konteks input ke `DIALOGUE`, dan mengembalikan data node aktif.
5. `select_choice(choice_id: String) -> Dictionary`:
   Memproses pilihan pemain, memicu navigasi node atau membuka konfirmasi berbagi.
6. `share_dish(from_source: String = "auto") -> Dictionary`:
   Mengeksekusi pemotongan atomik 1 unit hidangan, sinkronisasi flag, dan emisi sinyal P0 ending.
7. `close_dialogue() -> void`:
   Menutup sesi dialog dan mengembalikan konteks input ke `WORLD`.

---

## 4. Spesifikasi Pohon Dialog Warga (`npc_neighbor_01`)

### 4.1. Teks Naratif Resmi Verbatim (`CONTENT.md § 10`)
Semua teks naratif berikut wajib digunakan tanpa deviasi:

| ID Node | Pemicu & Kondisi | Teks Verbatim (Indonesia) | Pilihan Respon / Opsi yang Ditampilkan |
|---|---|---|---|
| `npc_intro` | Bicara pertama kali (`has_spoken_intro == false`) | *"Masih menyimpan buku itu? Coba lihat kebun di ujung jalan. Jagungnya belum semua habis."* | 1. `"choice_hint_bayam"`: "Bayamnya dari mana?" → `npc_hint_bayam`<br>2. `"choice_hint_kunci"`: "Temu kunci?" → `npc_hint_kunci`<br>3. `"choice_share"`: "Bagikan 1 porsi" → `npc_offer` *(hanya jika `has_dish()`)*<br>4. `"choice_close"`: "Tutup" → keluar |
| `npc_hint_bayam` | Memilih pertanyaan bayam | *"Ada benih di dekat alat. Petaknya memang lama tidak dipakai. Gemburkan dulu, baru tambah pembenah."* | 1. `"choice_hint_kunci"`: "Temu kunci?" → `npc_hint_kunci`<br>2. `"choice_share"`: "Bagikan 1 porsi" → `npc_offer` *(jika ada hidangan)*<br>3. `"choice_back"`: "Kembali" → `npc_intro`<br>4. `"choice_close"`: "Tutup" → keluar |
| `npc_hint_kunci` | Memilih pertanyaan temu kunci | *"Di tepi bambu, dekat batu besar. Daunnya lebih rendah dari rumpunnya."* | 1. `"choice_hint_bayam"`: "Bayamnya dari mana?" → `npc_hint_bayam`<br>2. `"choice_share"`: "Bagikan 1 porsi" → `npc_offer` *(jika ada hidangan)*<br>3. `"choice_back"`: "Kembali" → `npc_intro`<br>4. `"choice_close"`: "Tutup" → keluar |
| `npc_waiting` | Sudah pernah bicara, belum ada hidangan | *"Tidak perlu buru-buru. Yang penting tahu apa yang masih bisa ditanam."* | 1. `"choice_hint_bayam"`: "Bayamnya dari mana?" → `npc_hint_bayam`<br>2. `"choice_hint_kunci"`: "Temu kunci?" → `npc_hint_kunci`<br>3. `"choice_share"`: "Bagikan 1 porsi" → `npc_offer` *(jika ada hidangan)*<br>4. `"choice_close"`: "Tutup" → keluar |
| `npc_offer` | Hidangan tersedia di tas / peti | Pilihan penawaran hidangan (Teks konteks: *"Harum sekali. Kamu memasak Sayur Bening Bayam dan Jagung?"*) | 1. `"action_share"`: "Bagikan 1 porsi" → buka konfirmasi eksplisit<br>2. `"choice_cancel"`: "Nanti dulu" → keluar tanpa memotong hidangan |
| `npc_received` | Berbagi hidangan berhasil dikomit | *"Masih ingat rasanya. Besok, sisakan tempat buat menanam lagi."* | 1. `"choice_close"`: "Tutup" → keluar |
| `npc_repeat` | Bicara lagi setelah berbagi berhasil | *"Kebun kecil juga perlu diteruskan. Jangan berhenti di satu panci."* | 1. `"choice_close"`: "Tutup" → keluar |

### 4.2. Resolusi Node Awal (Starting Node Logic)
Saat pemain berinteraksi dengan `npc_neighbor_01`, `DialogueManager.get_starting_dialogue_node()` menyelesaikan node aktif berdasarkan pohon keputusan deterministik:

```
                          [Pemain Berinteraksi dengan NPC]
                                         │
                         Apakah has_shared_meal == true?
                                ├── Ya  ──► [npc_repeat]
                                └── Tidak
                                         │
                             Apakah has_dish() == true?
                                ├── Ya
                                │    ├── Belum pernah bicara? ──► [npc_intro] (opsi berbagi aktif)
                                │    └── Sudah pernah bicara? ──► [npc_offer]
                                └── Tidak
                                     ├── Belum pernah bicara? ──► [npc_intro]
                                     └── Sudah pernah bicara? ──► [npc_waiting]
```

Aturan ini menjamin pemain yang memasak terlebih dahulu sebelum berbicara dengan NPC (kasus T45) tetap dapat menikmati narasi pengantar (`npc_intro`) tanpa kehilangan opsi berbagi langsung.

---

## 5. Logika Aksi Berbagi Hidangan (`action_share`) & Konfirmasi Eksplisit

### 5.1. Alur Konfirmasi 2-Langkah (Two-Step Confirmation Flow)
Sesuai `UI_UX.md UI07` dan `CONTENT.md § 10`:
*"Berbagi mengonsumsi 1 hidangan di tas atau peti rumah melalui dialog eksplisit dengan konfirmasi jumlah, menetapkan flag yang sama dan memunculkan respons warga."*

1. **Langkah 1: Pemilihan Aksi di UI**
   - Pemain memilih tombol `"Bagikan 1 porsi"`.
   - Tombol menampilkan label informatif mengenai sumber hidangan:
     - Jika ada di tas: `"Bagikan 1 porsi (dari tas)"`
     - Jika hanya ada di peti: `"Bagikan 1 porsi (dari stok rumah)"`
2. **Langkah 2: Modal Konfirmasi Eksplisit (Inline Confirmation)**
   - Muncul panel dialog konfirmasi:
     - Teks: *"Bagikan 1 porsi Sayur Bening Bayam dan Jagung kepada tetangga?"*
     - Jika diambil dari peti: ditambahkan baris *"Termasuk stok rumah."* (`CONTENT.md § 11`).
     - Dua tombol pilihan tegas:
       - `[Konfirmasi]` / `"Ya, bagikan"` (`choice_id = "confirm_share"`)
       - `[Batal]` / `"Nanti dulu"` (`choice_id = "cancel_share"`)
3. **Penanganan Batal (Cancellation Invariant - T44)**:
   - Jika pemain menekan `[Batal]` atau tombol `Esc`:
     - Tidak ada mutasi inventaris apa pun (stok tas dan peti tetap 100%).
     - Flag `meal_used` tetap `false` (jika belum makan sebelumnya).
     - UI kembali ke daftar opsi atau menutup dialog secara aman.
4. **Penanganan Konfirmasi (Commit Execution)**:
   - Validasi ketersediaan hidangan ulang (*dry-run validation*).
   - Penarikan atomik tepat 1 unit `dish_sayur_bening`:
     - Cek tas: `backpack.remove_item("dish_sayur_bening", 1)`.
     - Jika tas 0, ambil dari peti: `storage_home.remove_item("dish_sayur_bening", 1)`.
   - Update flags:
     - `DialogueManager.has_shared_meal = true`
     - `DialogueManager.meal_used = true`
     - `WorldResourceManager.set_meal_used(true)`
     - `KitchenManager.meal_used = true`
   - Emisi sinyal:
     - `dish_shared.emit("dish_sayur_bening", 1, source)`
     - `meal_consumed.emit("dish_sayur_bening", 1)`
   - Transisi tampilan:
     - Node aktif langsung bertransisi ke `npc_received`: *"Masih ingat rasanya. Besok, sisakan tempat buat menanam lagi."*.

### 5.2. Proteksi Anti-Spam & Idempotensi (T44)
Pada `TEST_PLAN.md T44`: *"spam konfirmasi -> Batal tidak mengonsumsi; berhasil memakai satu; tidak ada duplikasi respons/hadiah"*.
- Backend `DialogueManager.share_dish()` dilindungi dengan penjaga:
  ```gdscript
  if has_shared_meal:
      return {
          "success": false,
          "reason": "Hidangan sudah pernah dibagikan kepada tetangga.",
          "idempotent": true
      }
  ```
- Klik berulang kali pada tombol konfirmasi dalam frame yang sama atau frame berdekatan akan ditolak secara bersih setelah eksekusi pertama selesai, menjamin tidak ada konsumsi ganda atau pengurangan item kedua.

---

## 6. Pemicu Penutup P0 (*P0 Experience Completion*)

### 6.1. Definisi Kondisi Penutup (`CONTENT.md § 10`)
*"Resep selesai saat output dibuat. Penutup pengalaman P0 terjadi saat `recipe_completed` dan `meal_used` sama-sama benar."*

Kondisi penutup terpenuhi jika:
1. `RecipeManager.is_recipe_completed("recipe_sayur_bening_01") == true` (resep telah dimasak hingga output selesai dibuat).
2. `meal_used == true` (hidangan telah digunakan, baik lewat aksi `eat_dish` di tas atau `action_share` kepada tetangga).

### 6.2. Jalur Pencapaian Penutup P0
| Jalur | Aksi Pemain | Evaluasi State | Hasil Pengalaman P0 |
|---|---|---|---|
| **Jalur A (Makan)** | Masak sampai output selesai → Ambil ke tas → Tekan tombol "Makan [1 porsi]" di panel tas | `is_recipe_completed` = true, `meal_used` = true di `KitchenManager` | P0 Selesai, pesan: *"Hangat. Resep pertama berhasil dibuat."* diikuti *"Satu resep selesai. Kebun ini baru dimulai."* |
| **Jalur B (Berbagi)** | Masak sampai output selesai → Bicara dengan tetangga → Pilih "Bagikan 1 porsi" → Konfirmasi | `is_recipe_completed` = true, `meal_used` = true di `DialogueManager` | P0 Selesai, respon: *"Masih ingat rasanya. Besok, sisakan tempat buat menanam lagi."* diikuti toast *"Satu resep selesai. Kebun ini baru dimulai."* |
| **Jalur C (Keduanya)** | Masak resep 1 → Makan → Masak resep 2 (remake) → Bagikan ke tetangga | `times_cooked` = 2, `has_shared_meal` = true, `meal_used` = true | Keduanya sukses tanpa konflik, sinyal penutup P0 tetap idempotent (hanya memicu selebrasi pertama kali). |

### 6.3. Teks Banner Penutup
Sesuai `CONTENT.md § 11`:
`| Penutup P0 | “Satu resep selesai. Kebun ini baru dimulai.” |`
Saat `p0_experience_completed` terpicu, `HUD.show_feedback("Satu resep selesai. Kebun ini baru dimulai.", 4.0)` dipanggil.

---

## 7. Analisis Invarian Bebas Penguncian (T45)

Kasus uji `TEST_PLAN.md T45` menyatakan:
*"T45: Lewati NPC/catatan, panen; kemudian baca catatan/dialog ulang -> Sumber tidak terkunci; isi/petunjuk tetap dapat diakses dan tercatat"*

Analisis pencegahan penguncian (*anti-softlock*):

1. **Non-linear Foraging & Farming**:
   - Sumber daya liar (`resource_jagung_01`, `resource_temu_kunci_01`), stasiun air (`water_home`), petak kebun (`plot_home_01`), dan stasiun dapur (`station_kitchen_home`) **tidak memiliki dependensi gating apa pun terhadap dialog NPC**.
   - Pemain dapat langsung mengambil jagung, mengambil temu kunci, menanam bayam, dan memasak tanpa menyapa tetangga.
2. **Aksesibilitas Petunjuk Setelah Memasak**:
   - Jika pemain telah memasak atau bahkan membagikan hidangan, petunjuk lokasi bayam (`npc_hint_bayam`) dan temu kunci (`npc_hint_kunci`) **tetap dapat dibuka dan dibaca ulang** (dapat diakses dari node `npc_waiting` atau riwayat dialog).
3. **Pembukaan Berulang Kali (*Idempotent Re-opening*)**:
   - Pemain dapat membuka dialog, menutup di tengah jalan (`Esc`), dan membukanya lagi seketika.
   - Tidak ada cooldown pengunci, tidak ada perubahan state yang merugikan pemain.
4. **Keamanan State Pasca-Berbagi (`npc_repeat`)**:
   - Setelah berbagi berhasil, interaksi berikutnya menampilkan `npc_repeat`: *"Kebun kecil juga perlu diteruskan. Jangan berhenti di satu panci."*.
   - Tidak memunculkan penawaran berbagi ulang yang dapat memotong hidangan baru secara tidak sengaja.

---

## 8. Cetak Biru Implementasi Antarmuka UI (`dialogue_ui.tscn` & `dialogue_ui.gd`)

### 8.1. Layout UI07 (`docs/UI_UX.md`)
- **Letak**: Panel bawah (*Bottom Anchor Panel*), tinggi ~180–220 px, lebar ~900–1100 px di tengah bawah.
- **Hierarki Node**:
  ```
  DialogueUI (CanvasLayer, layer = 12)
  └── RootControl (Control, Full Rect)
      ├── DimBackground (ColorRect, semi-transparan tipis untuk fokus)
      └── BottomPanelContainer (PanelContainer, Anchor Bottom-Center)
          └── MarginContainer
              └── VBoxContainer
                  ├── SpeakerHeader (HBoxContainer)
                  │   └── SpeakerNameLabel (Label: "Tetangga")
                  ├── DialogueTextLabel (Label: teks node aktif, autowrap)
                  ├── ChoicesContainer (VBoxContainer / HBoxContainer)
                  │   ├── ChoiceBtn1 (Button)
                  │   ├── ChoiceBtn2 (Button)
                  │   ├── ChoiceBtn3 (Button)
                  │   └── CloseBtn (Button: "Tutup")
                  └── ConfirmationBox (PanelContainer, default hidden)
                      └── VBoxContainer
                          ├── ConfirmPromptLabel (Label)
                          └── HBoxContainer
                              ├── ConfirmBtn (Button: "Konfirmasi")
                              └── CancelBtn (Button: "Batal")
  ```

### 8.2. Integrasi Navigasi Keyboard & Input Gating
- Sesuai `UI_UX § 3`:
  - `Tab` / `Shift+Tab` atau panah atas/bawah memilih tombol pilihan.
  - `Enter` / `Space` mengaktifkan tombol fokus.
  - `Esc` menutup konfirmasi terlebih dahulu; jika konfirmasi tidak aktif, `Esc` menutup dialog.
  - `E` yang membuka dialog ditekan tidak langsung memilih pilihan pertama (`_last_opened_frame` guard atau `InputManager.suppress_action_until_released(&"interact")`).

### 8.3. Penyambungan di `scripts/main.gd`
```gdscript
# Wire npc_neighbor_01
var neighbor_node = level.get_node_or_null("npc_neighbor_01")
if neighbor_node:
    var interactable = neighbor_node.get_node_or_null("Interactable")
    if interactable and interactable.has_signal("interacted"):
        interactable.interacted.connect(_on_neighbor_interacted)

func _on_neighbor_interacted(_player_node: Node3D) -> void:
    if dialogue_ui != null and dialogue_ui.has_method("open_dialogue"):
        dialogue_ui.open_dialogue("npc_neighbor_01")
```

---

## 9. Rencana Rangkaian Pengujian Otomatis (T43, T44, T45)

Implementer wajib membangun dua suite pengujian:

### 9.1. Suite 15: `tests/suites/test_social.gd` (Formal Acceptance Suite)
1. **Grup 1: T45 — Navigasi Pohon Dialog & Invarian Bebas Kunci**
   - `test_t45_first_talk_presents_npc_intro_verbatim()`
   - `test_t45_hint_bayam_navigation_and_verbatim_text()`
   - `test_t45_hint_kunci_navigation_and_verbatim_text()`
   - `test_t45_subsequent_talk_without_dish_presents_npc_waiting()`
   - `test_t45_hints_remain_re_readable_from_waiting_node()`
   - `test_t45_skipping_npc_allows_foraging_and_cooking_without_lock()`
2. **Grup 2: T44 — Aksi Berbagi Hidangan, Sumber Tas vs Peti, dan Konfirmasi**
   - `test_t44_dish_offer_node_available_when_dish_in_backpack()`
   - `test_t44_dish_offer_node_available_when_dish_in_storage()`
   - `test_t44_cancel_share_leaves_dish_counts_unmodified()`
   - `test_t44_confirm_share_consumes_one_portion_atomically_from_backpack()`
   - `test_t44_confirm_share_consumes_one_portion_atomically_from_storage()`
   - `test_t44_share_commit_transitions_to_npc_received_verbatim()`
   - `test_t44_subsequent_talk_after_sharing_presents_npc_repeat_verbatim()`
   - `test_t44_anti_spam_repeated_confirm_clicks_reject_double_consumption()`
3. **Grup 3: T43/T44 — Sinkronisasi Flag `meal_used` & Penutup P0**
   - `test_t44_share_dish_sets_meal_used_on_dialogue_world_and_kitchen()`
   - `test_t43_p0_ending_triggered_when_recipe_completed_and_meal_shared()`
   - `test_t43_p0_ending_message_matches_verbatim_content_11()`
4. **Grup 4: Input Context & Modal Gating**
   - `test_extra_dialogue_pushes_dialogue_context_and_pauses_world()`
   - `test_extra_dialogue_close_restores_world_context_without_bleedthrough()`
5. **Grup 5: Save Snapshot Envelope v1 Roundtrip**
   - `test_extra_save_snapshot_preserves_dialogue_flags_and_shared_state()`

### 9.2. Suite 16: `tests/suites/test_adversarial_social.gd` (Stress & Invariant Verification)
1. `test_adv_share_with_zero_dishes_rejected_cleanly()`
2. `test_adv_rapid_dialogue_toggle_100x_no_state_corruption()`
3. `test_adv_cook_two_dishes_eat_one_then_share_one_consistency()`
4. `test_adv_save_load_mid_dialogue_restores_safe_state()`
5. `test_adv_p0_ending_signal_single_emission_guarantee()`

Kedua suite wajib didaftarkan di `tests/test_runner.gd` dan diverifikasi lulus 100%.

---

## 10. Daftar Berkas yang Harus Dibuat/Dimodifikasi oleh Worker

| Path Berkas | Status | Tanggung Jawab Perubahan |
|---|---|---|
| `scripts/social/dialogue_manager.gd` | Baru | Autoload singleton logika dialog, pohon dialog, `action_share`, sinkronisasi `meal_used`, pemicu P0 |
| `project.godot` | Modifikasi | Registrasi `DialogueManager="*res://scripts/social/dialogue_manager.gd"` pada `[autoload]` |
| `scenes/ui/dialogue_ui.tscn` | Baru | Adegan visual UI dialog tetangga sesuai UI07 (panel bawah, nama, teks, pilihan, konfirmasi) |
| `scripts/ui/dialogue_ui.gd` | Baru | Pengendali UI dialog, navigasi tombol, modal konfirmasi, penutupan aman |
| `scripts/main.gd` | Modifikasi | Penyambungan interaksi `npc_neighbor_01` ke `DialogueUI` |
| `scenes/main.tscn` | Modifikasi | Instansiasi `DialogueUI` di dalam scene Main |
| `scripts/ui/hud.gd` | Modifikasi | Penyesuaian prompt `landmark_neighbor` dan pendengar sinyal penutup P0 |
| `tests/suites/test_social.gd` | Baru | Suite 15 pengujian penerimaan formal T43, T44, T45 |
| `tests/suites/test_adversarial_social.gd` | Baru | Suite 16 pengujian adversarial, anti-spam, dan stres mutasi |
| `tests/test_runner.gd` | Modifikasi | Pendaftaran dan eksekusi Suite 15 & 16 |

---

## 11. Kesimpulan & Rekomendasi untuk Orchestrator

1. Arsitektur sosial untuk milestone `SOC-001` telah didefinisikan secara presisi, mematuhi semua teks verbatim `CONTENT.md § 10` dan `§ 11`, serta memvalidasi kriteria uji `TEST_PLAN.md T43, T44, T45`.
2. Koordinasi lintas manajer (`InventoryManager`, `WorldResourceManager`, `KitchenManager`) berjalan mulus karena variabel `meal_used` dan `p0_experience_completed` telah dipersiapkan pada `COOK-002`.
3. Invarian bebas penguncian (T45) dijamin penuh karena tidak ada sumber daya liar atau dapur yang digerbang oleh NPC.
4. Pekerjaan siap dilanjutkan ke tahap implementasi oleh `worker_soc_001`.
