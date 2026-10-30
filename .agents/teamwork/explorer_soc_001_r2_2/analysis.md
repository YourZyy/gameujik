# Laporan Analisis Remediasi Snapshot & Sinyal (Milestone SOC-001)

**Penyusun:** `explorer_soc_001_r2_2` (Save & Signal Remediation Explorer)  
**Tanggal:** 29 Oktober 2026  
**Status:** Rekomendasi Analisis Tuntas (Read-Only)  
**Tujuan Dokumen:** Memberikan cetak biru perbaikan konkret, tepat kode, dan bebas regresi untuk mengatasi kegagalan gate pada Milestone SOC-001 (Buku Resep 2045).

---

## 1. Ringkasan Eksekutif & Pemetaan Masalah

Berdasarkan hasil investigasi mendalam terhadap codebase, laporan Reviewer (`reviewer_soc_001_1`), laporan Challenger (`challenger_soc_001_2`), serta eksekusi riil pengujian headless Godot 4.7.2, ditemukan tiga masalah inti yang ditugaskan kepada explorer ini beserta dua cacat runtime pengiring yang saling terkait:

1. **[Kritis] Script Crash `Nonexistent 'bool' constructor` di `DialogueManager.load_save_snapshot:454`**:
   GDScript 4 tidak memiliki konstruktor `bool(String)`. Ketika snapshot memuat nilai boolean terdistorsi berupa string (`"true"`, `"false"`), pemanggilan `bool(data.get(...))` memicu *runtime exception* fatal yang menggagalkan deserialisasi save data (terbukti empiris pada tes `ADV.LF-06`).
2. **[Mayor] Duplikasi Sinyal `p0_experience_completed` Lintas Manajer (`DialogueManager` vs `KitchenManager`)**:
   P0 completion memiliki dua jalur eksekusi: memakan hidangan di tas (`KitchenManager.eat_dish`) dan membagikan hidangan ke tetangga (`DialogueManager.share_dish`). Karena kedua manajer tidak melakukan sinkronisasi dua arah terhadap flag `p0_completed`, pemain yang memakan hidangan lalu kemudian memasak lagi dan membagikannya ke tetangga (atau sebaliknya) akan memicu sinyal `p0_experience_completed` dua kali. Selain itu, terdapat ketidaksesuaian tanda tangan sinyal (`KitchenManager` 0 parameter, `DialogueManager` 1 parameter string pesan).
3. **[Mayor] Ketiadaan API Publik `is_p0_completed()` dan `evaluate_p0_closure()` di `DialogueManager`**:
   Laporan penyelesaian tugas `014` dan dokumentasi arsitektur mencantumkan ketersediaan metode ini, tetapi implementasi di `scripts/social/dialogue_manager.gd` tidak memilikinya sehingga logika evaluasi penutupan P0 tertanam kaku (*hardcoded*) di dalam `share_dish()`.
4. **[Kritis - Pengiring] Stack Overflow via Rekursi Sirkular Tak Terbatas pada Penutupan Dialog**:
   Pemanggilan `dialogue_ui.close()` memanggil `dm.end_dialogue()`, yang memancarkan `dialogue_ended`, yang kembali memanggil `dialogue_ui.close()` tanpa *active-state guard*, melebihi batas 1.024 frame tumpukan panggilan Godot.
5. **[Mayor - Pengiring] Trapping Node Dialog pada Pembatalan Berbagi**:
   Memilih "Nanti dulu" (`choice_share_cancel`) pada `NODE_OFFER` mengembalikan `_current_node_id` tanpa melakukan transisi ke `NODE_WAITING`, mengurung pemain di node penawaran hidangan.

---

## 2. Masalah 1: Bug Crash Parsing Boolean di `DialogueManager.load_save_snapshot`

### 2.1. Observasi & Bukti Empiris

Pada file `scripts/social/dialogue_manager.gd` baris 454–457:
```gdscript
454: 	has_spoken_intro = bool(data.get("has_spoken_intro", data.get("talked_to_npc", false)))
455: 	_has_shared_meal = bool(data.get("has_shared_meal", data.get("has_shared", false)))
456: 	meal_used = bool(data.get("meal_used", false))
457: 	p0_completed = bool(data.get("p0_completed", false))
```

Pada pengujian adversarial `ADV.LF-06` (`tests/suites/test_adversarial_lock_free_p0.gd:508-520`):
```gdscript
var corrupted: Dictionary = {
    "version": 1,
    "has_spoken_intro": "true",
    "has_shared_meal": 12345,
    "meal_used": false,
    "p0_completed": 1,
    "dialogue_flags": {"test_flag": true}
}
Assertions.assert_true(dm.load_save_snapshot(corrupted), "ADV.LF-06: Snapshot valid berhasil dimuat")
```

Log kegagalan mesin Godot 4.7.2:
```text
SCRIPT ERROR: Invalid call. Nonexistent 'bool' constructor.
   at: load_save_snapshot (res://scripts/social/dialogue_manager.gd:454)
GDScript backtrace (most recent call first):
   [0] load_save_snapshot (res://scripts/social/dialogue_manager.gd:454)
   [1] test_adv06_malformed_save_snapshot_resilience (res://tests/suites/test_adversarial_lock_free_p0.gd:516)
```

### 2.2. Analisis Akar Masalah (Root Cause)

Di GDScript 4, fungsi bawaan `bool()` hanya mendukung tipe primitif numerik (`int`, `float`) dan `bool` itu sendiri:
- `bool(1)` -> `true`
- `bool(0)` -> `false`
- `bool("true")` -> **Fatal Script Error**: `Nonexistent 'bool' constructor`.

Pada format serialisasi JSON (seperti `JSON.stringify`/`JSON.parse`), data format lama, atau payload yang termodifikasi, nilai boolean kerap kali direpresentasikan sebagai string (`"true"`, `"false"`, `"1"`, `"0"`), integer (`1`, `0`), atau `null`. Penggunaan langsung `bool(...)` tanpa pemeriksaan tipe membuat sistem penyimpanan (Save System) rapuh dan rentan *crash* total saat memuat berkas simpanan pemain.

### 2.3. Rancangan Helper Parsing Boolean Aman (`_parse_bool_safe`)

Helper statis dirancang untuk menangani seluruh spektrum tipe data masukan secara tangguh (*fail-safe*):

```gdscript
## Mengonversi sembarang Variant (String, int, float, bool, null) menjadi boolean dengan aman.
## Menangani format umum seperti "true", "false", "1", "0", 1, 0, tanpa memicu
## runtime error GDScript 4 'Nonexistent bool constructor'.
static func _parse_bool_safe(val: Variant, default_val: bool = false) -> bool:
	if val == null:
		return default_val
	if val is bool:
		return val
	if val is int or val is float:
		return val != 0
	if val is String:
		var s := val.strip_edges().to_lower()
		if s == "true" or s == "1" or s == "yes" or s == "on":
			return true
		if s == "false" or s == "0" or s == "no" or s == "off":
			return false
		if s.is_valid_int():
			return int(s) != 0
		return default_val
	return default_val
```

### 2.4. Penerapan Konkret pada `load_save_snapshot`

Diperlukan perbaikan pada pengambilan nilai agar *fallback alias* (misal: `"talked_to_npc"` jika `"has_spoken_intro"` bernilai null/tidak ada) tidak terabaikan:

```gdscript
func load_save_snapshot(data: Dictionary) -> bool:
	if not (data is Dictionary) or data.is_empty():
		return false
	var ver: int = int(data.get("version", 0))
	if ver < 1:
		return false

	var raw_spoken = data.get("has_spoken_intro")
	if raw_spoken == null:
		raw_spoken = data.get("talked_to_npc", false)
	has_spoken_intro = _parse_bool_safe(raw_spoken, false)

	var raw_shared = data.get("has_shared_meal")
	if raw_shared == null:
		raw_shared = data.get("has_shared", false)
	_has_shared_meal = _parse_bool_safe(raw_shared, false)

	meal_used = _parse_bool_safe(data.get("meal_used", false), false)
	p0_completed = _parse_bool_safe(data.get("p0_completed", false), false)

	var raw_flags = data.get("dialogue_flags", {})
	if raw_flags is Dictionary:
		dialogue_flags = raw_flags.duplicate(true)
	else:
		dialogue_flags.clear()

	return true
```

---

## 3. Masalah 2: Deduplikasi Sinyal `p0_experience_completed` Lintas Manajer

### 3.1. Observasi & Arsitektur Alur P0

P0 Closure (Kriteria Penutup Pengalaman P0) didefinisikan oleh dua prasyarat mutlak:
1. `recipe_completed == true` (Resep `recipe_sayur_bening_01` telah dimasak).
2. `meal_used == true` (Satu porsi hidangan telah digunakan).

Penggunaan hidangan memiliki dua modalitas independen:
- **Jalur A (Konsumsi Pribadi / Lock-Free)**: Pemain memakan hidangan dari tas melalui `KitchenManager.eat_dish()`.
- **Jalur B (Sosial / Berbagi ke Tetangga)**: Pemain membagikan hidangan melalui `DialogueManager.share_dish()`.

### 3.2. Vektor Duplikasi Sinyal

Saat ini, kedua manajer memiliki variabel status terpisah (`KitchenManager.p0_completed` dan `DialogueManager.p0_completed`):

1. **Vektor 1 (Makan Pertama -> Berbagi Kedua)**:
   - Pemain memasak sayur bening ke-1.
   - Pemain memakannya di tas: `KitchenManager.eat_dish()` tereksekusi.
     - `km.meal_used = true`
     - `km.p0_completed = true`
     - `km.p0_experience_completed.emit()` terpancar (Emisi 1).
     - `km` **tidak memperbarui** `DialogueManager.p0_completed`.
   - Pemain memasak sayur bening ke-2.
   - Pemain menemui tetangga dan memilih "Bagikan 1 porsi" (`dm.share_dish()`):
     - `dm.p0_completed` masih bernilai `false`.
     - `dm` memicu `dm.p0_completed = true` dan memancarkan `dm.p0_experience_completed.emit(MSG_P0_ENDING)` (Emisi 2).
   - **Dampak:** Sinyal penutup P0 dipancarkan dua kali sepanjang siklus hidup permainan.
2. **Vektor 2 (Berbagi Pertama -> Makan Kedua)**:
   - Pemain memasak sayur bening ke-1 lalu membagikannya (`dm.share_dish()`).
   - `dm` memancarkan `dm.p0_experience_completed` dan mengeset `km.set("meal_used", true)`.
   - Namun, `dm` **tidak mengeset** `km.set("p0_completed", true)`.
   - Pemain memasak sayur bening ke-2 lalu memakannya di tas (`km.eat_dish()`).
   - Karena `km.p0_completed` masih `false`, `km.eat_dish()` memancarkan `km.p0_experience_completed.emit()` lagi.
3. **Vektor 3 (Inkonsistensi Antarmuka Sinyal & Pendengar HUD)**:
   - `KitchenManager`: `signal p0_experience_completed()` (0 parameter).
   - `DialogueManager`: `signal p0_experience_completed(message: String)` (1 parameter teks).
   - `scripts/ui/hud.gd` hanya mendengarkan sinyal dari `DialogueManager`:
     ```gdscript
     func _connect_dialogue_manager_signals() -> void:
         var dm := _get_dialogue_manager()
         if dm != null:
             if dm.has_signal("p0_experience_completed") and not dm.p0_experience_completed.is_connected(_on_p0_experience_completed):
                 dm.p0_experience_completed.connect(_on_p0_experience_completed)
     ```
     Jika pemain menyelesaikan game secara *lock-free* (hanya makan di tas tanpa pernah berinteraksi dengan tetangga), HUD tidak pernah menampilkan notifikasi toast *"Satu resep selesai. Kebun ini baru dimulai."* karena `KitchenManager` tidak menyinkronkan emisi ke HUD atau `DialogueManager`.

### 3.3. Solusi Remediasi Deduplikasi Terpadu

Untuk menjamin invariansi emisi tepat 1 kali (*exactly-once execution*):

1. **Sinkronisasi Dua Arah (Bidirectional State Sync)**:
   - Ketika `DialogueManager` menutup P0: ia menandai `p0_completed = true` lokal dan mengeset `km.set("p0_completed", true)`.
   - Ketika `KitchenManager` menutup P0: ia memeriksa `DialogueManager.is_p0_completed()`. Jika sudah selesai, ia membatalkan emisi ulang. Jika belum, ia menandai `p0_completed = true`, mengeset `dm.set("p0_completed", true)`, dan dapat memancarkan sinyal ke `dm` agar HUD terpapar pesan akhir.
2. **Kueri Status Agregat pada `is_p0_completed()`**:
   Metode `is_p0_completed()` di kedua manajer harus mengecek status manajer pasangannya jika status lokal masih `false`.
3. **Agregasi Status Penggunaan Makanan pada `is_meal_used()`**:
   `DialogueManager.is_meal_used()` harus memeriksa:
   - Flag lokal `meal_used` atau `_has_shared_meal`.
   - `WorldResourceManager.is_meal_used()`.
   - `KitchenManager.meal_used`.

---

## 4. Masalah 3: Penyediaan Helper API `is_p0_completed()` dan `evaluate_p0_closure()` di `DialogueManager`

### 4.1. Spesifikasi Kontrak API

Sesuai dokumen register tugas dan laporan selesai `014`, `DialogueManager` wajib menyediakan dua helper publik:

#### A. `is_p0_completed() -> bool`
- **Fungsi:** Memeriksa apakah pengalaman P0 sudah berstatus selesai.
- **Logika:** Mengembalikan `true` jika flag lokal `p0_completed` aktif ATAU jika `KitchenManager.p0_completed` aktif.

```gdscript
## Memeriksa apakah milestone P0 (Buku Resep 2045) telah selesai.
## Memeriksa status internal p0_completed atau status tersinkronisasi pada KitchenManager.
func is_p0_completed() -> bool:
	if p0_completed:
		return true
	var km := _get_kitchen_manager()
	if km != null and bool(km.get("p0_completed")) == true:
		p0_completed = true
		return true
	return false
```

#### B. `is_meal_used() -> bool`
- **Fungsi:** Mengagregasi status penggunaan hidangan dari seluruh sumber kebenaran (lokal, WorldResourceManager, KitchenManager).

```gdscript
## Memeriksa apakah hidangan Sayur Bening telah digunakan (dimakan atau dibagikan).
## Melakukan agregasi lintas status lokal, WorldResourceManager, dan KitchenManager.
func is_meal_used() -> bool:
	if meal_used or _has_shared_meal:
		return true
	var wrm := _get_world_resource_manager()
	if wrm != null and wrm.has_method("is_meal_used") and wrm.is_meal_used():
		meal_used = true
		return true
	var km := _get_kitchen_manager()
	if km != null and bool(km.get("meal_used")) == true:
		meal_used = true
		return true
	return false
```

#### C. `evaluate_p0_closure() -> bool`
- **Fungsi:** Melakukan evaluasi terpusat terhadap kriteria penutup P0. Menjalankan emisi sinyal `p0_experience_completed` tepat 1 kali dan mengembalikan status akhir P0.
- **Logika:**
  1. Periksa `if is_p0_completed(): return true` (Idempotent guard / anti-duplikasi).
  2. Periksa ketersediaan penyelesaian resep: `rm.is_recipe_completed(RECIPE_P0_ID)`.
  3. Periksa status konsumsi/berbagi makanan: `is_meal_used()`.
  4. Jika kedua prasyarat terpenuhi:
     - Set `p0_completed = true`.
     - Sinkronkan `km.set("p0_completed", true)`.
     - Pancarkan `p0_experience_completed.emit(MSG_P0_ENDING)`.
     - Pancarkan `action_success.emit("p0_experience_completed", MSG_P0_ENDING)`.
     - Return `true`.
  5. Jika belum terpenuhi: return `false`.

```gdscript
## Mengevaluasi kriteria penutup pengalaman P0 (T43):
## Prasyarat: recipe_completed(recipe_sayur_bening_01) == true DAN meal_used == true.
## Memancarkan p0_experience_completed tepat 1 kali (idempotent / deduplicated).
## Mengembalikan status boolean apakah P0 telah selesai.
func evaluate_p0_closure() -> bool:
	if is_p0_completed():
		return true

	var rm := _get_recipe_manager()
	var recipe_done: bool = rm != null and rm.has_method("is_recipe_completed") and rm.is_recipe_completed(RECIPE_P0_ID)
	var used: bool = is_meal_used()

	if recipe_done and used and not p0_completed:
		p0_completed = true

		var km := _get_kitchen_manager()
		if km != null:
			km.set("p0_completed", true)

		p0_experience_completed.emit(MSG_P0_ENDING)
		action_success.emit("p0_experience_completed", MSG_P0_ENDING)
		return true

	return p0_completed
```

### 4.2. Refaktor `DialogueManager.share_dish()` Memanfaatkan Helper Baru

Dengan adanya helper di atas, blok evaluasi manual pada `share_dish()` dapat disederhanakan secara elegan:

```gdscript
	# Sinkronisasi status penggunaan
	_has_shared_meal = true
	meal_used = true

	var wrm := _get_world_resource_manager()
	if wrm != null and wrm.has_method("set_meal_used"):
		wrm.set_meal_used(true)

	var km := _get_kitchen_manager()
	if km != null:
		km.set("meal_used", true)

	# Transisi node percakapan ke respon penerimaan warga
	_current_node_id = NODE_RECEIVED
	var received_data := get_dialogue_node(NODE_RECEIVED)
	dialogue_node_changed.emit(NODE_RECEIVED, received_data)
	node_changed.emit(received_data)

	# Emisi sinyal transaksi
	dish_shared.emit(DISH_ID, 1, source_to_use)
	var rem_count: int = 0
	if inv.has_method("get_available_item_count"):
		rem_count = inv.get_available_item_count(DISH_ID)
	meal_shared.emit(source_to_use, rem_count)
	meal_consumed.emit(DISH_ID, 1)

	# Evaluasi kondisi penutup P0 terpusat via evaluate_p0_closure()
	var was_already_p0: bool = is_p0_completed()
	evaluate_p0_closure()
	var newly_completed_p0: bool = not was_already_p0 and is_p0_completed()

	action_success.emit("share_dish", "Hidangan berhasil dibagikan.")

	return {
		"success": true,
		"source": source_to_use,
		"item_id": DISH_ID,
		"count": 1,
		"p0_completed": p0_completed,
		"newly_completed_p0": newly_completed_p0,
		"message": MSG_P0_ENDING if p0_completed else "Hidangan berhasil dibagikan."
	}
```

---

## 5. Remediasi Cacat Pengiring (Sinergi Reviewer & Challenger)

Agar implementer/worker berikutnya dapat menutup seluruh temuan sekaligus tanpa putaran revisi tambahan (*single-shot remediation*), berikut analisis dan solusi untuk dua cacat pengiring:

### 5.1. Perbaikan Rekursi Tak Terbatas (`DialogueUI.close` <-> `dm.close_dialogue`)
- **Akar Masalah:**
  - `dm.dialogue_ended` disambungkan ke `DialogueUI.close`.
  - Di dalam `DialogueUI.close()`, ia memanggil `dm.end_dialogue()`.
  - `dm.end_dialogue()` memanggil `dm.close_dialogue()`, yang memancarkan `dialogue_ended`, memanggil kembali `DialogueUI.close()`.
  - Kedua fungsi tidak memiliki *active guard*.
- **Solusi:**
  1. Pada `scripts/social/dialogue_manager.gd`:
     ```gdscript
     func close_dialogue() -> void:
         if not _is_dialogue_active:
             return
         _is_dialogue_active = false
         var prev_npc := current_npc_id
         current_npc_id = ""
         dialogue_closed.emit(prev_npc)
         dialogue_ended.emit()
     ```
  2. Pada `scripts/ui/dialogue_ui.gd`:
     ```gdscript
     func close() -> void:
         if not visible:
             return
         visible = false
         ...
     ```

### 5.2. Perbaikan Trapping Node pada Pembatalan Berbagi
- **Akar Masalah:** Di `scripts/social/dialogue_manager.gd:279-286`, `choice_share_cancel` mengembalikan `_current_node_id` tanpa memanggil `_transition_to_node(NODE_WAITING)`.
- **Solusi:**
  ```gdscript
  "choice_share_cancel", "choice_cancel", "cancel_share", "later":
      return _transition_to_node(NODE_WAITING)
  ```

### 5.3. Perbaikan Lewatan Dialog Tanggapan Tetangga di UI
- **Akar Masalah:** Di `scripts/ui/dialogue_ui.gd:175`, `choice_share` dicegat langsung oleh modal konfirmasi tanpa membiarkan dialog berpindah ke `NODE_OFFER`.
- **Solusi:**
  ```gdscript
  if choice_id == "choice_share_confirm" or choice_id == "action_share":
      _prompt_share_confirmation()
      return
  ```

---

## 6. Draf Kode Lengkap untuk Implementer

### 6.1. Draf Perubahan pada `scripts/social/dialogue_manager.gd`

```gdscript
# --- Tambahkan Helper Statis Parsing Boolean (misal di akhir file atau di atas load_save_snapshot) ---
static func _parse_bool_safe(val: Variant, default_val: bool = false) -> bool:
	if val == null:
		return default_val
	if val is bool:
		return val
	if val is int or val is float:
		return val != 0
	if val is String:
		var s := val.strip_edges().to_lower()
		if s == "true" or s == "1" or s == "yes" or s == "on":
			return true
		if s == "false" or s == "0" or s == "no" or s == "off":
			return false
		if s.is_valid_int():
			return int(s) != 0
		return default_val
	return default_val

# --- Perbarui fungsi Query Status P0 & Penggunaan Makanan ---
func is_p0_completed() -> bool:
	if p0_completed:
		return true
	var km := _get_kitchen_manager()
	if km != null and bool(km.get("p0_completed")) == true:
		p0_completed = true
		return true
	return false

func is_meal_used() -> bool:
	if meal_used or _has_shared_meal:
		return true
	var wrm := _get_world_resource_manager()
	if wrm != null and wrm.has_method("is_meal_used") and wrm.is_meal_used():
		meal_used = true
		return true
	var km := _get_kitchen_manager()
	if km != null and bool(km.get("meal_used")) == true:
		meal_used = true
		return true
	return false

# --- Tambahkan evaluate_p0_closure() ---
func evaluate_p0_closure() -> bool:
	if is_p0_completed():
		return true

	var rm := _get_recipe_manager()
	var recipe_done: bool = rm != null and rm.has_method("is_recipe_completed") and rm.is_recipe_completed(RECIPE_P0_ID)
	var used: bool = is_meal_used()

	if recipe_done and used and not p0_completed:
		p0_completed = true

		var km := _get_kitchen_manager()
		if km != null:
			km.set("p0_completed", true)

		p0_experience_completed.emit(MSG_P0_ENDING)
		action_success.emit("p0_experience_completed", MSG_P0_ENDING)
		return true

	return p0_completed

# --- Perbarui load_save_snapshot() ---
func load_save_snapshot(data: Dictionary) -> bool:
	if not (data is Dictionary) or data.is_empty():
		return false
	var ver: int = int(data.get("version", 0))
	if ver < 1:
		return false

	var raw_spoken = data.get("has_spoken_intro")
	if raw_spoken == null:
		raw_spoken = data.get("talked_to_npc", false)
	has_spoken_intro = _parse_bool_safe(raw_spoken, false)

	var raw_shared = data.get("has_shared_meal")
	if raw_shared == null:
		raw_shared = data.get("has_shared", false)
	_has_shared_meal = _parse_bool_safe(raw_shared, false)

	meal_used = _parse_bool_safe(data.get("meal_used", false), false)
	p0_completed = _parse_bool_safe(data.get("p0_completed", false), false)

	var raw_flags = data.get("dialogue_flags", {})
	if raw_flags is Dictionary:
		dialogue_flags = raw_flags.duplicate(true)
	else:
		dialogue_flags.clear()

	return true

# --- Perbarui close_dialogue() dengan guard aktif ---
func close_dialogue() -> void:
	if not _is_dialogue_active:
		return
	_is_dialogue_active = false
	var prev_npc := current_npc_id
	current_npc_id = ""
	dialogue_closed.emit(prev_npc)
	dialogue_ended.emit()

# --- Perbarui on_dialogue_choice() untuk pembatalan ---
"choice_share_cancel", "choice_cancel", "cancel_share", "later":
	return _transition_to_node(NODE_WAITING)
```

### 6.2. Draf Perubahan pada `scripts/cooking/kitchen_manager.gd`

```gdscript
# Tambahkan helper getter & setter dialogue manager:
var _dialogue_manager_override: Node = null

func set_dialogue_manager(dm: Node) -> void:
	_dialogue_manager_override = dm

func _get_dialogue_manager() -> Node:
	if _dialogue_manager_override != null and is_instance_valid(_dialogue_manager_override):
		return _dialogue_manager_override
	if Engine.has_singleton("DialogueManager"):
		return Engine.get_singleton("DialogueManager")
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var node = tree.root.get_node_or_null("DialogueManager")
		if node != null:
			return node
	if is_inside_tree() and has_node("/root/DialogueManager"):
		return get_node("/root/DialogueManager")
	return null

# Di dalam eat_dish():
	var rm := _get_recipe_manager()
	var is_recipe_done: bool = rm != null and rm.has_method("is_recipe_completed") and rm.is_recipe_completed(RECIPE_P0)

	var dm := _get_dialogue_manager()
	var dm_already_completed: bool = dm != null and dm.has_method("is_p0_completed") and dm.is_p0_completed()

	if not p0_completed and dm_already_completed:
		p0_completed = true

	if is_recipe_done and meal_used and not p0_completed:
		p0_completed = true
		if dm != null:
			dm.set("p0_completed", true)
			dm.set("meal_used", true)
		p0_experience_completed.emit()
```

---

## 7. Rencana Verifikasi Independen

Implementer dan reviewer dapat memverifikasi perbaikan melalui serangkaian pengujian:

1. **Uji Parsing Boolean Snapshot Malformed**:
   - Jalankan suite 17: `ADV.LF-06` di `tests/suites/test_adversarial_lock_free_p0.gd`.
   - Hasil yang diharapkan: Snapshot berisi `"has_spoken_intro": "true"` dan `"has_shared_meal": 12345` berhasil dimuat tanpa crash `Nonexistent 'bool' constructor`.
2. **Uji Anti-Rekursi Stack Overflow Penutupan Dialog**:
   - Jalankan suite 17: `ADV.LF-03` dan `ADV.LF-04`.
   - Hasil yang diharapkan: 100x pembukaan dan penutupan dialog melalui `DialogueUI.close()` selesai dengan exit code 0 tanpa stack overflow.
3. **Uji Deduplikasi Sinyal Lintas Jalur (Makan vs Berbagi)**:
   - Skenario Uji Baru:
     - Masak resep 1, makan via `km.eat_dish()`. Hitung emisi sinyal = 1.
     - Masak resep 2, bagikan via `dm.share_dish()`. Hitung emisi sinyal = tetap 1 (tidak bertambah).
     - Sebaliknya: Bagikan dulu, lalu makan hidangan kedua -> emisi sinyal tetap 1.
4. **Uji Eksekusi Penuh Runner CLI**:
   ```powershell
   & "C:\Users\HP\.local\bin\godot_console.exe" --headless --path . --script res://tests/test_runner.gd
   ```
   - Target hasil: Seluruh 17 suite lolos 100%, 0 asersi gagal, exit code 0.
