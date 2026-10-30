# Handoff Report: Investigasi Validasi Bahan, Reservasi Atomik, Pemetaan Asal & Pembatalan Pra-Masak Dapur (COOK-001)

## 1. Observation

Berdasarkan inspeksi langsung terhadap repositori dan dokumen referensi:

1. **Model Resep & Kamus Bahan:**
   - Di `docs/CONTENT.md` § 2 & § 4 dan `scripts/recipe/recipes_data.gd` (baris 15–33), resep awal P0 adalah `recipe_sayur_bening_01` ("Sayur Bening Bayam dan Jagung").
   - Kebutuhan bahan baku wajib:
     - `ingredient_bayam`: 3 unit
     - `ingredient_jagung`: 1 unit
     - `ingredient_temu_kunci`: 1 unit
   - Stasiun kerja: `station_kitchen_home`
   - Durasi persiapan (prep): 4.0 detik (aksi tahan / hold)
   - Durasi memasak: 30.0 detik pada panas Sedang (skup COOK-002)
   - Output dish: 1 unit `dish_sayur_bening`

2. **Status Kontainer & Inventaris Saat Ini:**
   - Di `scripts/inventory/inventory_manager.gd`:
     - Baris 11–16 mendefinisikan konstanta kontainer: `CONTAINER_BACKPACK = "backpack"`, `CONTAINER_STORAGE = "storage"`, `CONTAINER_REFUND = "kitchen_refund"`.
     - Baris 28–30 & 57–59 menginisialisasi tiga kontainer berkapasitas 12 slot, 20 max stack: `backpack`, `storage_home`, dan `kitchen_refund`.
     - Baris 281–295: `get_available_item_count(item_id)` menjumlahkan `backpack` + `storage_home` dan mengurangi item dari `_reservations`.
     - Baris 307–346: Terdapat fungsi *stub* dari milestone INV-001/BOOK-001:
       ```gdscript
       func reserve_ingredients(job_id: String, items: Array[Dictionary]) -> Dictionary:
           if _reservations.has(job_id):
               return {"success": false, "reason": "Job ID sudah aktif."}
           ...
           _reservations[job_id] = items.duplicate(true)
           inventory_updated.emit()
           return {"success": true, "reason": "Bahan berhasil direservasi."}
       ```
     - **Defisiensi saat ini:** `reserve_ingredients` yang ada saat ini hanya mencatat kamus `_reservations[job_id]` tanpa memindahkan (*withdraw*) bahan secara fisik dari `backpack` atau `storage_home`.
     - Akibatnya:
       a. Bahan tetap berada di slot tas/peti selama fase persiapan.
       b. Pemetaan asal kontainer (*origin breakdown* tas vs peti) tidak disimpan.
       c. Kontainer asal tidak pernah memiliki slot kosong tambahan akibat reservasi, sehingga skenario T40 (*mengisi kontainer asal hingga penuh lalu membatalkan*) tidak mungkin terjadi.
       d. Kontainer `kitchen_refund` yang sudah disiapkan di `InventoryManager` belum pernah digunakan sama sekali.

3. **Status Stasiun Dunia 3D & Konteks Input:**
   - Di `scenes/world/level_graybox.tscn` (baris 509–535), node `station_kitchen_home` telah tersedia pada koordinat `(2, 0, -4)` dengan StaticBody3D Counter dan Area3D Interactable (collision layer 3/interactables).
   - Di `scripts/core/input_manager.gd` (baris 6–13), telah terdefinisi `ContextMode.KITCHEN`.
   - Di baris 58: `is_simulation_paused()` mengecualikan `ContextMode.KITCHEN` (artinya saat dapur terbuka, simulasi waktu/pertumbuhan tetap berjalan sesuai `PROTOTYPE.md` § 5: "Dapur aktif: Pertumbuhan/penguapan/hari Berjalan; Job memasak Berjalan").
   - Di `scripts/main.gd`, interaksi `station_kitchen_home` belum disambungkan ke pembukaan antarmuka dapur.
   - `KitchenManager` belum dibuat dan belum terdaftar di `project.godot` `[autoload]`.

4. **Integrasi Kasur Tidur Dunia (WORLD-001):**
   - Di `scripts/world/world_resource_manager.gd` baris 262–271 dan 379–387, fungsi `can_sleep()` memanggil `_get_kitchen_manager()` dan secara eksplisit memeriksa `km.is_cooking_active()`, `km.is_job_active()`, atau `km.get("is_active") == true` untuk menolak tidur jika dapur sedang memiliki job aktif.

5. **Spesifikasi Kasus Uji `docs/TEST_PLAN.md`:**
   - **T10:** Bahan resep kurang satu $\rightarrow$ tolak bersih tanpa reservasi, tanpa job, tanpa mutasi item apa pun, sebutkan bahan yang kurang.
   - **T11:** Bahan terbagi antara tas dan peti $\rightarrow$ kueri stok bebas identik antara buku dan dapur; urutan pengambilan mengikuti CONTENT § 3 (tas dahulu, baru peti, indeks terkecil dahulu).
   - **T12:** Klik Siapkan / Mulai berulang $\rightarrow$ idempotent: tepat 1 job ID, 1 reservasi, 1 output; tidak ada konsumsi ganda.
   - **T13:** Reservasi bahan lalu batalkan sebelum memasak $\rightarrow$ total bahan bebas + refund sama dengan sebelum mulai; tidak ada bahan hilang atau bertambah.
   - **T40:** Reservasi, tutup panel, penuhi kontainer asal via fixture/item lain, lalu batalkan $\rightarrow$ bahan kembali ke kontainer asal jika muat; jika tidak muat, coba kontainer alternatif; jika tetap tidak muat, tumpahkan ke `kitchen_refund` yang persisten; jangan pernah menumpuk bahan batal ke slot hasil masakan.

6. **Kondisi Baseline Eksekusi:**
   - Menjalankan `C:\Users\HP\.local\bin\godot.exe --headless --path . --script res://tests/test_runner.gd` menghasilkan exit code 0 (`Assertions Passed: 1233, Assertions Failed: 0, All Passed: true`). Baseline proyek 100% hijau.

---

## 2. Logic Chain

1. **Kebutuhan Isolasi Transaksi Atomik (T10):**
   - `CONTENT.md` § 3 menyatakan: *"Seluruh bahan harus lolos pemeriksaan sebelum satu unit pun diambil. Resep tidak memakai barang yang sudah dicadangkan proses lain."*
   - Oleh karena itu, sebelum satu item pun dipindahkan, `KitchenManager` / `InventoryManager` wajib melakukan validasi menyeluruh (*dry-run validation*).
   - Jika kebutuhan 3 bayam, 1 jagung, atau 1 temu kunci kurang 1 unit saja: fungsi harus mengembalikan kegagalan (`success: false`, `reason: "Bahan belum lengkap. Buka buku untuk melihat sumbernya."`) tanpa memutasi satu pun slot di `backpack` maupun `storage_home`.

2. **Deduction Fisik & Pemetaan Asal (T11):**
   - `CONTENT.md` § 3 menetapkan urutan penarikan: tas (`backpack`) terlebih dahulu, kemudian peti (`storage_home`), slot indeks terkecil dahulu.
   - Jika bahan diambil secara fisik dari kontainer pada saat penekanan Siapkan, maka:
     a. Slot kontainer asal berkurang/kosong secara riil.
     b. Job reservasi wajib mencatat daftar rincian asal (*origin breakdown*):
        `[ {"container": "backpack", "item_id": "ingredient_bayam", "count": 2}, {"container": "storage", "item_id": "ingredient_bayam", "count": 1}, ... ]`
     c. `get_available_item_count(item_id)` di `InventoryManager` secara alami mencerminkan sisa stok bebas tanpa risiko pengurangan ganda (*double deduction*).

3. **Pencegahan Duplikasi Job / Spam Input (T12):**
   - Sesuai `PROTOTYPE.md` § 6.2: *"Tombol berulang mengarah ke job yang sama, bukan job kedua."*
   - Ketika job sedang aktif (dalam status `preparing` atau `ready_to_heat`), pemanggilan ulang `start_preparation()` harus mendeteksi job aktif dan mengembalikan instance job yang sama secara idempotent tanpa mengambil bahan baru.

4. **Pembatalan & Pengembalian 3-Tingkat (T13 & T40):**
   - Sesuai `PROTOTYPE.md` § 6.2:
     *"Batal mengembalikan bahan ke kontainer asal jika muat, lalu tas/peti lain bila perlu. Sisa yang tidak muat masuk kontainer pengembalian aman milik dapur yang persisten. Pesan menyebut tempat mengambilnya. Job ditutup hanya setelah seluruh reservasi berpindah tepat sekali."*
   - Algoritma pengembalian untuk setiap elemen pada `origin_breakdown`:
     - **Tingkat 1 (Kontainer Asal):** Coba kembalikan ke kontainer asal (`origin_container`). Jika berhasil seluruhnya (`remaining == 0`), selesai.
     - **Tingkat 2 (Kontainer Alternatif):** Jika masih ada sisa (`remaining > 0`), coba masukkan ke kontainer alternatif (jika asal `backpack`, masukkan ke `storage_home`; jika asal `storage`, masukkan ke `backpack`).
     - **Tingkat 3 (Refund Storage Dapur):** Jika masih ada sisa (`remaining > 0`), masukkan sisa tersebut ke `inv.kitchen_refund`.
   - Invarian total item dijamin: $\text{Backpack} + \text{Storage} + \text{Refund} + \text{Reserved} = \text{Konstan}$.
   - Bahan batal **DILARANG KERAS** ditaruh di slot hasil hidangan (`output_slot`).

5. **Mekanika Aksi Tahan 4 Detik (Hold Action) Persiapan:**
   - Berbeda dari aksi alat berkebun yang reset saat dibatalkan, `CONTENT.md` § 4 & § 6 menegaskan bahwa progress persiapan dapur disimpan per job (*retained on interrupt*).
   - Menutup panel dapur atau melepas tombol saat progress mencapai 2.5s tidak membatalkan reservasi. Saat dibuka kembali, progress tetap 2.5s.
   - Ketika progress mencapai 4.0s (100%), status job bertransisi ke `STATE_READY_TO_HEAT`.
   - Transisi ke tahap memasak (`COOK-002`) membutuhkan penekanan tombol "Mulai Memasak" secara terpisah (*discrete action*), bukan terpicu otomatis dari input tahan yang sama.

6. **Penyimpanan Snapshot (Save / Load Envelope v1):**
   - `KitchenManager` harus menyediakan `get_save_snapshot()` dan `load_save_snapshot(data)` yang menyimpan:
     - `current_state`
     - `active_job` (termasuk `job_id`, `prep_progress`, `reserved_items`, dan `origin_breakdown`)
     - `output_slot`
   - Ini memastikan state persiapan yang sedang berjalan atau bahan yang sedang tertahan dapat dipulihkan utuh pada SAVE-001.

---

## 3. Caveats

1. **Batasan Cakupan Milestone COOK-001 vs COOK-002:**
   - COOK-001 berfokus pada: validasi bahan, reservasi atomik dengan ID stabil, penahanan persiapan 4 detik (`preparing` $\rightarrow$ `ready_to_heat`), pembatalan aman pra-masak, pemetaan asal, dan tumpahan ke `kitchen_refund_storage`.
   - Pengaturan panas (Rendah $\times 0.5$, Sedang $\times 1.0$, Tinggi $\times 0.0$), timer memasak 30 detik, jeda saat jendela ditutup pada tahap cooking, pembuatan hidangan output (`dish_sayur_bening`), pencatatan buku selesai, dan konsumsi/berbagi hidangan berada di bawah lingkup **COOK-002**. State machine yang dirancang di COOK-001 harus menyediakan transisi tersebut namun tidak mengimplementasikan loop memasaknya terlebih dahulu.
2. **Kompatibilitas Backward Uji Eksisting:**
   - Suite uji sebelumnya (`adversarial_inventory_challenge.gd` dan `adversarial_inv_reviewer_stress.gd`) memanggil `inv.reserve_ingredients(job_id, items)` dan `inv.commit_consumption(job_id)`.
   - Modifikasi pada `InventoryManager` harus mempertahankan kompatibilitas tanda tangan fungsi tersebut agar tidak merusak pengujian dari milestone INV-001 dan BOOK-001.

---

## 4. Conclusion & Rekomendasi Arsitektur

### A. Kontrak Antarmuka `InventoryManager` (Update)

File sasaran: `scripts/inventory/inventory_manager.gd`

```gdscript
## Kontrak Reservasi Dapur Tingkat Lanjut (COOK-001)

func reserve_ingredients_atomic(job_id: String, recipe_req: Dictionary) -> Dictionary:
    # 1. Cek duplikasi job_id
    if _reservations.has(job_id):
        return {"success": false, "reason": "Job ID sudah aktif."}

    # 2. Dry-run validation: periksa apakah seluruh bahan mencukupi di (backpack + storage)
    for item_id in recipe_req:
        var req_cnt: int = int(recipe_req[item_id])
        if get_available_item_count(item_id) < req_cnt:
            return {
                "success": false, 
                "reason": "Bahan belum lengkap. Buka buku untuk melihat sumbernya.",
                "missing_item": item_id
            }

    # 3. Penarikan fisik berurutan: tas dahulu (indeks 0..11), lalu peti (indeks 0..11)
    var origin_map: Array[Dictionary] = []
    var reserved_summary: Array[Dictionary] = []

    for item_id in recipe_req:
        var needed: int = int(recipe_req[item_id])
        reserved_summary.append({"item_id": item_id, "count": needed})
        
        # Ambil dari tas
        var from_bp: int = mini(needed, backpack.get_item_count(item_id))
        if from_bp > 0:
            backpack.remove_item(item_id, from_bp)
            origin_map.append({"container": CONTAINER_BACKPACK, "item_id": item_id, "count": from_bp})
            needed -= from_bp
        
        # Ambil sisa dari peti
        if needed > 0:
            var from_storage: int = mini(needed, storage_home.get_item_count(item_id))
            if from_storage > 0:
                storage_home.remove_item(item_id, from_storage)
                origin_map.append({"container": CONTAINER_STORAGE, "item_id": item_id, "count": from_storage})
                needed -= from_storage

    _reservations[job_id] = {
        "items": reserved_summary,
        "origin_map": origin_map
    }
    inventory_updated.emit()
    return {
        "success": true,
        "status": "OK",
        "job_id": job_id,
        "reserved_items": reserved_summary,
        "origin_map": origin_map
    }

func cancel_reservation_with_refund(job_id: String) -> Dictionary:
    if not _reservations.has(job_id):
        return {"success": false, "reason": "Reservasi tidak ditemukan."}

    var res_data: Dictionary = _reservations[job_id]
    var origin_map: Array = res_data.get("origin_map", [])
    var refund_log: Array[Dictionary] = []

    for entry in origin_map:
        var c_orig_name: String = str(entry.get("container", CONTAINER_BACKPACK))
        var item_id: String = str(entry.get("item_id", ""))
        var count_to_refund: int = int(entry.get("count", 0))
        var orig_c = get_container(c_orig_name)
        var alt_c = storage_home if c_orig_name == CONTAINER_BACKPACK else backpack

        # 1. Coba kontainer asal
        var rem: int = orig_c.add_item(item_id, count_to_refund)
        var added_orig: int = count_to_refund - rem
        if added_orig > 0:
            refund_log.append({"item_id": item_id, "count": added_orig, "destination": c_orig_name})

        # 2. Coba kontainer alternatif
        if rem > 0:
            var rem_alt: int = alt_c.add_item(item_id, rem)
            var added_alt: int = rem - rem_alt
            if added_alt > 0:
                var alt_name := CONTAINER_STORAGE if c_orig_name == CONTAINER_BACKPACK else CONTAINER_BACKPACK
                refund_log.append({"item_id": item_id, "count": added_alt, "destination": alt_name})
            rem = rem_alt

        # 3. Tumpahkan sisa ke kitchen_refund
        if rem > 0:
            kitchen_refund.add_item(item_id, rem)
            refund_log.append({"item_id": item_id, "count": rem, "destination": CONTAINER_REFUND})

    _reservations.erase(job_id)
    inventory_updated.emit()
    return {"success": true, "refund_log": refund_log}
```

### B. Arsitektur Modul Baru `KitchenManager`

File sasaran: `scripts/cooking/kitchen_manager.gd` (Didaftarkan sebagai Autoload di `project.godot`).

1. **State Machine:**
   - `STATE_IDLE = "idle"`
   - `STATE_PREPARING = "preparing"`
   - `STATE_READY_TO_HEAT = "ready_to_heat"`
   - `STATE_COOKING = "cooking"`
   - `STATE_PAUSED = "paused"`
   - `STATE_OUTPUT_READY = "output_ready"`
2. **Struktur Data `active_job`:**
   ```gdscript
   {
       "job_id": "job_cooking_01",
       "recipe_id": "recipe_sayur_bening_01",
       "state": "preparing",
       "prep_progress": 2.5,
       "prep_duration": 4.0,
       "cook_progress": 0.0,
       "cook_duration": 30.0,
       "heat_level": "low",
       "reserved_items": [...],
       "origin_breakdown": [...],
       "output_dish_id": "dish_sayur_bening",
       "output_count": 1,
       "output_committed": false
   }
   ```
3. **Metode Utama:**
   - `is_job_active() -> bool`: mengembalikan `true` bila state bukan `idle` dan bukan `output_ready`.
   - `is_cooking_active() -> bool`: alias untuk kompatibilitas `can_sleep()` di `WorldResourceManager`.
   - `can_prepare_recipe(recipe_id: String) -> Dictionary`: validasi prasyarat (stasiun idle, output kosong, bahan lengkap).
   - `start_preparation(recipe_id: String = "") -> Dictionary`: memulai reservasi atomik ber-ID stabil dan inisialisasi job.
   - `advance_prep(delta: float) -> void`: memajukan progress hold persiapan hingga 4.0s lalu transisi ke `ready_to_heat`.
   - `cancel_current_job() -> Dictionary`: eksekusi pengembalian aman dan reset stasiun ke `idle`.
   - `has_refund_items() -> bool` & `claim_refund_items() -> Dictionary`: utilitas mengambil item tertahan di `kitchen_refund`.
   - `get_save_snapshot()` & `load_save_snapshot(data)`: snapshot state, job, dan output slot.

### C. Scene & Script Antarmuka `KitchenUI`

File sasaran:
- `scenes/ui/kitchen_ui.tscn`
- `scripts/ui/kitchen_ui.gd`
- Fitur UI:
  - Header: Nama masakan ("Sayur Bening Bayam dan Jagung") & status dapur.
  - Daftar Bahan: Status ketersediaan (Bayam 3/3, Jagung 1/1, Temu Kunci 1/1).
  - Indikator Persiapan: ProgressBar aksi tahan (0.0s s/d 4.0s).
  - Tombol Aksi:
    - `[Tahan Siapkan 4s]`: Hold button untuk persiapan.
    - `[Batal]`: Membatalkan reservasi dan mengembalikan bahan.
    - `[Tutup / Esc]`: Menutup panel tanpa membatalkan progress.
    - `[Wadah Pengembalian]`: Muncul bila terdapat barang di `kitchen_refund`.

---

## 5. Verification Method

Implementer dan reviewer dapat memverifikasi implementasi COOK-001 melalui pengujian berikut:

### Perintah Uji Headless Godot
```powershell
C:\Users\HP\.local\bin\godot.exe --headless --path . --script res://tests/test_runner.gd
```

### Rincian Kasus Uji yang Harus Ditambahkan di `tests/suites/test_cooking.gd` (Suite 11):

1. **Uji T10 (Insufficiency Rejection):**
   - Setup: Tas memiliki 2 bayam, 1 jagung, 1 temu kunci (bayam kurang 1).
   - Eksekusi: Panggil `KitchenManager.start_preparation("recipe_sayur_bening_01")`.
   - Verifikasi: Hasil ditolak (`success == false`), `active_job` tetap null, tidak ada item yang berkurang di tas/peti (bayam tetap 2, jagung 1, temu kunci 1).

2. **Uji T11 (Split Ingredients & Deduction Order):**
   - Setup: Tas memiliki 2 bayam, 1 temu kunci. Peti memiliki 1 bayam, 1 jagung.
   - Eksekusi: Panggil `KitchenManager.start_preparation("recipe_sayur_bening_01")`.
   - Verifikasi:
     - Reservasi sukses.
     - `origin_breakdown` mencatat: `backpack` diambil 2 bayam dan 1 temu kunci; `storage` diambil 1 bayam dan 1 jagung.
     - Sisa stok bebas yang dapat digunakan di `InventoryManager.get_available_item_count()` untuk ketiga bahan menjadi 0.

3. **Uji T12 (Idempotent Single Job on Spam):**
   - Setup: Bahan lengkap di tas.
   - Eksekusi: Panggil `start_preparation()` sebanyak 5 kali berturut-turut.
   - Verifikasi: Hanya ada 1 job ID yang tercipta, reservasi hanya terjadi 1 kali (tepat 3 bayam, 1 jagung, 1 temu kunci yang ditarik), sisa pemanggilan tidak menggandakan penarikan item.

4. **Uji T13 (Safe Cancellation & Exact Refund):**
   - Setup: Reservasi aktif dari kondisi T11.
   - Eksekusi: Panggil `KitchenManager.cancel_current_job()`.
   - Verifikasi:
     - `job_cancelled` terpancar.
     - Tas kembali memiliki 2 bayam dan 1 temu kunci.
     - Peti kembali memiliki 1 bayam dan 1 jagung.
     - Total bahan di tas dan peti persis sama dengan kondisi sebelum reservasi.

5. **Uji T40 (Full Container Spillover to Persistent Kitchen Refund):**
   - Setup: Bahan direservasi dari tas. Slot kosong di tas dipenuhi 12 slot item lain (fixture fill). Peti rumah juga dipenuhi hingga 12 slot.
   - Eksekusi: Panggil `KitchenManager.cancel_current_job()`.
   - Verifikasi:
     - Bahan tidak dapat masuk ke tas maupun peti.
     - Seluruh bahan yang dibatalkan tertampung dengan aman di `inv.kitchen_refund`.
     - Slot hasil masakan (`output_slot`) tetap kosong (tidak tercampur).
     - Total item dalam game terjaga secara utuh (tidak ada yang hilang).
     - UI/feedback menampilkan notifikasi bahwa bahan berada di wadah pengembalian dapur.

6. **Kondisi Invalidasi (Invalidation Conditions):**
   - Adanya item yang hilang (*item sink*) atau bertambah ganda (*duplication exploit*) pada saat reservasi, pembatalan berulang, atau pergantian panel.
   - Terjadinya mutasi parsial pada tas saat validasi bahan gagal.
   - Terbukanya peluang tidur kasur (`bed_home`) saat job persiapan dapur sedang aktif.
