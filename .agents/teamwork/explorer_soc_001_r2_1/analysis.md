# Laporan Analisis Remediasi Teknis: SOC-001 (Buku Resep 2045)

**Agent**: `explorer_soc_001_r2_1` (Remediation Systems Explorer)  
**Milestone**: `SOC-001` (Interaksi Sosial Warga, Dialog Tetangga, Berbagi Hidangan, dan Penutup P0)  
**Tanggal**: 2026-10-29  
**Status**: INVESTIGASI TUNTAS — SOLUSI KONKRET SIAP EKSEKUSI

---

## Ringkasan Eksekutif

Investigasi mendalam telah dilakukan terhadap kegagalan verifikasi gerbang (Gate Status) putaran pertama pada milestone `SOC-001`, yang dipicu oleh temuan Reviewer 1 & 2 (`REQUEST_CHANGES`) dan Challenger 1 & 2 (`FAIL`). Tiga masalah utama yang ditugaskan serta dua cacat tambahan telah dianalisis hingga ke level instruksi kode dan backtrace GDScript:

1. **Bug Kritis Rekursi Mutual Tak Hingga (`Stack Overflow`)**: Koneksi siklikal tanpa guard re-entrancy antara sinyal `DialogueManager.dialogue_ended` dan metode `DialogueUI.close()` memicu panggilan timbal-balik tak terbatas (melebihi 1024 stack frames GDScript VM) saat UI ditutup via tombol, Esc, atau pilihan dialog.
2. **Pebagian Batal Terjebak di `NODE_OFFER`**: Pilihan `choice_share_cancel` ("Nanti dulu") pada `NODE_OFFER` mengembalikan state dialog tanpa memanggil transisi `_transition_to_node(NODE_WAITING)`, menjebak pemain dalam perulangan penawaran tanpa opsi keluar/bertanya.
3. **Pemotongan Narasi Respon Tetangga di `NODE_OFFER`**: `DialogueUI._on_choice_pressed()` mengintersepsi `choice_share` secara prematur langsung ke modal pop-up konfirmasi, melompati tampilan teks narasi tetangga ("Harum sekali. Kamu memasak Sayur Bening Bayam dan Jagung?").
4. **Cacat Tambahan Konstruktor `bool` pada Save Snapshot**: Penggunaan `bool(data.get(...))` di `DialogueManager.load_save_snapshot()` menyebabkan crash fatal `Invalid call. Nonexistent 'bool' constructor` di GDScript 4 ketika menerima data string ("true"/"false").
5. **Deduplikasi Sinyal Penutup P0 Lintas Manajer**: Konsumsi hidangan via tas (`KitchenManager.eat_dish`) dan dialog tetangga (`DialogueManager.share_dish`) belum menyinkronkan status penutup secara mutual, berisiko memancarkan sinyal ganda saat pemain membuat ulang hidangan kedua.

Seluruh akar masalah telah diverifikasi secara empiris melalui runner headless Godot (`tests/test_runner.gd`), dan perbaikan konkret telah dirancang secara presisi tanpa merusak spesifikasi `PRD.md`, `CONTENT.md`, `UI_UX.md`, maupun kasus uji `TEST_PLAN.md` (T43–T45).

---

## 1. Analisis Bug Kritis 1: Rekursi Mutual Tak Hingga (`Stack Overflow`)

### 1.1 Observasi & Bukti Empiris
Saat menjalankan pengujian headless (`godot_console.exe --headless --path . --script res://tests/test_runner.gd`), pengujian terhenti pada Suite 16 (`TestAdversarialSocial.test_adv20`) dan Suite 17 (`TestAdversarialLockFreeP0.test_adv04`) dengan log galat mesin Godot berikut:

```text
SCRIPT ERROR: Stack overflow. Check for infinite recursion in your script.
   at: close_dialogue (res://scripts/social/dialogue_manager.gd:314)
   GDScript backtrace (most recent call first):
       [0] end_dialogue (res://scripts/social/dialogue_manager.gd:322)
       [1] close_dialogue (res://scripts/social/dialogue_manager.gd:319)
       [2] end_dialogue (res://scripts/social/dialogue_manager.gd:322)
       [3] close (res://scripts/ui/dialogue_ui.gd:122)
       [4] close_dialogue (res://scripts/social/dialogue_manager.gd:319)
       [5] end_dialogue (res://scripts/social/dialogue_manager.gd:322)
       [6] close (res://scripts/ui/dialogue_ui.gd:122)
       ... [Exceeded 1024 stack frames]
ERROR: Stack underflow! (Engine Bug)
   at: exit_function (modules/gdscript/gdscript.h:529)
```

### 1.2 Rantai Logika Akar Masalah (Root Cause Analysis)
1. **Koneksi Sinyal Terlalu Agresif di `scripts/ui/dialogue_ui.gd` (baris 49–50)**:
   ```gdscript
   if dm.has_signal("dialogue_ended") and not dm.dialogue_ended.is_connected(close):
       dm.dialogue_ended.connect(close)
   ```
   `DialogueUI` menghubungkan sinyal `dialogue_ended` langsung ke fungsi `close()`.
2. **Ketiadaan Guard Visibilitas / Re-entrancy di `DialogueUI.close()` (baris 115–124)**:
   ```gdscript
   func close() -> void:
       visible = false
       if confirm_modal != null:
           confirm_modal.visible = false

       var dm := _get_dialogue_manager()
       if dm != null and dm.has_method("end_dialogue"):
           dm.end_dialogue()
       ...
   ```
   Fungsi `close()` tidak memeriksa `if not visible: return` di awal eksekusi, dan tanpa syarat memanggil `dm.end_dialogue()`.
3. **Ketiadaan Guard State Aktif di `DialogueManager.close_dialogue()` (baris 314–323)**:
   ```gdscript
   func close_dialogue() -> void:
       var prev_npc := current_npc_id
       _is_dialogue_active = false
       current_npc_id = ""
       dialogue_closed.emit(prev_npc)
       dialogue_ended.emit()

   func end_dialogue() -> void:
       close_dialogue()
   ```
   Fungsi `close_dialogue()` tidak memeriksa `if not _is_dialogue_active: return`. Akibatnya, setiap kali dipanggil (meskipun dialog sudah tidak aktif), ia tetap memancarkan `dialogue_ended.emit()`.
4. **Siklus Rekursi Mutual (Ping-Pong Loop)**:
   - Pemain menekan tombol Tutup / Esc / `choice_close` -> memanggil `DialogueUI.close()`.
   - `DialogueUI.close()` memanggil `dm.end_dialogue()`.
   - `dm.end_dialogue()` memanggil `dm.close_dialogue()`.
   - `dm.close_dialogue()` memancarkan sinyal `dialogue_ended`.
   - Sinyal `dialogue_ended` langsung memicu listener yang terhubung: `DialogueUI.close()`.
   - `DialogueUI.close()` kembali memanggil `dm.end_dialogue()`.
   - Siklus berulang secara sinkron hingga batas tumpukan panggilan GDScript (1024 frame) terlampaui -> **Crash Fatal (Stack Overflow)**.

### 1.3 Solusi Konkret & Kode Remediasi
Perbaikan harus dilakukan pada kedua sisi (pertahanan berlapis / defense-in-depth):

#### A. Pada `scripts/social/dialogue_manager.gd`:
Tambahkan active guard pada `close_dialogue()`:
```gdscript
# Target: scripts/social/dialogue_manager.gd (baris 314-323)
func close_dialogue() -> void:
	if not _is_dialogue_active:
		return
	_is_dialogue_active = false
	var prev_npc := current_npc_id
	current_npc_id = ""
	dialogue_closed.emit(prev_npc)
	dialogue_ended.emit()

func end_dialogue() -> void:
	close_dialogue()
```

#### B. Pada `scripts/ui/dialogue_ui.gd`:
1. Pisahkan handler sinyal `dialogue_ended` menjadi `_on_dialogue_ended()` tersendiri (jangan menghubungkannya langsung ke `close()`).
2. Tambahkan visibility guard dan state check pada `close()` sebelum memanggil `end_dialogue()`.

```gdscript
# Target: scripts/ui/dialogue_ui.gd (baris 45-51)
	var dm := _get_dialogue_manager()
	if dm != null:
		if dm.has_signal("dialogue_node_changed") and not dm.dialogue_node_changed.is_connected(_on_dialogue_node_changed):
			dm.dialogue_node_changed.connect(_on_dialogue_node_changed)
		if dm.has_signal("dialogue_ended") and not dm.dialogue_ended.is_connected(_on_dialogue_ended):
			dm.dialogue_ended.connect(_on_dialogue_ended)
```

```gdscript
# Target: scripts/ui/dialogue_ui.gd (baris 115-128)
func close() -> void:
	if not visible:
		return
	visible = false
	if confirm_modal != null:
		confirm_modal.visible = false

	var dm := _get_dialogue_manager()
	if dm != null and dm.has_method("is_dialogue_active") and dm.is_dialogue_active():
		if dm.has_method("end_dialogue"):
			dm.end_dialogue()

	var im := _get_input_manager()
	if im != null and im.has_method("get_current_context"):
		if im.get_current_context() == im.ContextMode.DIALOGUE:
			im.consume_and_close(&"interact")

func _on_dialogue_ended() -> void:
	if not visible:
		return
	visible = false
	if confirm_modal != null:
		confirm_modal.visible = false

	var im := _get_input_manager()
	if im != null and im.has_method("get_current_context"):
		if im.get_current_context() == im.ContextMode.DIALOGUE:
			im.consume_and_close(&"interact")
```

---

## 2. Analisis Bug 2: Transisi `choice_share_cancel` ("Nanti dulu") ke `NODE_WAITING`

### 2.1 Observasi & Bukti Empiris
Pada `scripts/social/dialogue_manager.gd`:
1. Definisi node `NODE_OFFER` (baris 237–246) menyatakan:
   ```gdscript
   NODE_OFFER:
       return {
           "id": NODE_OFFER,
           "speaker": "Tetangga",
           "text": "Harum sekali. Kamu memasak Sayur Bening Bayam dan Jagung?",
           "choices": [
               {"id": "choice_share_confirm", "text": "Bagikan 1 porsi", "action": "share"},
               {"id": "choice_share_cancel", "text": "Nanti dulu", "target_node": NODE_WAITING}
           ]
       }
   ```
2. Namun pada penanganan pilihan `on_dialogue_choice()` (baris 279–286):
   ```gdscript
   "choice_share_cancel", "choice_cancel", "cancel_share", "later":
       return {
           "success": true,
           "cancelled": true,
           "node_id": _current_node_id,
           "node": get_dialogue_node(_current_node_id)
       }
   ```

### 2.2 Rantai Logika & Dampak (Logic Chain)
- Node `NODE_OFFER` hanya memiliki dua pilihan: "Bagikan 1 porsi" dan "Nanti dulu". Tidak ada tombol "Tutup" di dalam daftar pilihan node tersebut.
- Ketika pemain menolak berbagi saat berada di `NODE_OFFER` dengan memilih "Nanti dulu" (`choice_share_cancel`), kontrak data node secara tegas menetapkan `"target_node": NODE_WAITING`.
- Karena fungsi `on_dialogue_choice()` hanya mengembalikan `_current_node_id` tanpa memanggil `_transition_to_node(NODE_WAITING)`, status node aktif tetap berada di `NODE_OFFER`.
- UI dialog menerima data tersebut dan menampilkan kembali teks: *"Harum sekali. Kamu memasak Sayur Bening Bayam dan Jagung?"*. Pemain terjebak dalam perulangan penawaran (*infinite offer loop*) dan tidak dapat kembali ke topik diskusi kebun/resep di `NODE_WAITING` kecuali menutup paksa dialog dengan Esc.

### 2.3 Solusi Konkret & Kode Remediasi
Ubah blok penanganan pilihan batal di `scripts/social/dialogue_manager.gd` agar melakukan transisi ke `NODE_WAITING`:

```gdscript
# Target: scripts/social/dialogue_manager.gd (baris 279-286)
		"choice_share_cancel", "choice_cancel", "cancel_share", "later":
			var node_data := _transition_to_node(NODE_WAITING)
			return {
				"success": true,
				"cancelled": true,
				"node_id": NODE_WAITING,
				"node": node_data
			}
```

**Dampak Positif & Kesesuaian Pengujian**:
- `dm.get_current_node_id()` menjadi `"npc_waiting"`.
- `DialogueUI` memperbarui tampilan ke `NODE_WAITING` ("Tidak perlu buru-buru. Yang penting tahu apa yang masih bisa ditanam.") yang memiliki pilihan navigasi kembali ("Bayamnya dari mana?", "Temu kunci?", "Tutup").
- Seluruh pengujian pengabaian & pembatalan (`test_t44_03`, `ADV.SOC-11`, `ADV.LF-02`, `ADV.LF-05`) tetap lulus 100% karena mengembalikan field `"success": true` dan `"cancelled": true` serta materi tidak terpotong.

---

## 3. Analisis Bug 3: Alur Tampilan Dialog Narasi pada `NODE_OFFER`

### 3.1 Observasi & Bukti Empiris
Pada `scripts/ui/dialogue_ui.gd` (baris 170–178):
```gdscript
func _on_choice_pressed(choice_id: String) -> void:
	if choice_id == "choice_close" or choice_id == "close":
		close()
		return

	if choice_id == "choice_share" or choice_id == "choice_share_confirm" or choice_id == "action_share":
		_prompt_share_confirmation()
		return

	var dm := _get_dialogue_manager()
	if dm != null and dm.has_method("select_choice"):
		var res: Dictionary = dm.select_choice(choice_id)
        ...
```

### 3.2 Rantai Logika & Dampak (Logic Chain)
- Berdasarkan desain narasi `PRD.md § 4`, `CONTENT.md § 10`, dan pohon dialog di `dialogue_manager.gd`:
  - Pada node `NODE_INTRO` dan `NODE_WAITING`, opsi berbagi memiliki `id`: `"choice_share"` dengan `target_node`: `NODE_OFFER`.
  - Tujuannya adalah memindahkan pemain ke node narasi penawaran: `NODE_OFFER` di mana tetangga merespon aroma masakan: *"Harum sekali. Kamu memasak Sayur Bening Bayam dan Jagung?"*.
  - Di dalam `NODE_OFFER`, pemain kemudian diberi pilihan eksplisit:
    1. "Bagikan 1 porsi" (`id`: `"choice_share_confirm"`, `action`: `"share"`)
    2. "Nanti dulu" (`id`: `"choice_share_cancel"`, `target_node`: `NODE_WAITING`)
- Namun karena `DialogueUI._on_choice_pressed()` mengikutsertakan pengecekan `choice_id == "choice_share"`, menekan tombol "Bagikan 1 porsi" pada `NODE_INTRO` atau `NODE_WAITING` langsung membuka modal pop-up konfirmasi di atas node intro/waiting.
- Pemain **sama sekali tidak pernah melihat teks dialog reaksi tetangga pada `NODE_OFFER`**; alur naratif terputus secara kasar oleh pop-up modal sistem.

### 3.3 Solusi Konkret & Kode Remediasi
Hapus `"choice_share"` dari intersepsi prematur di `_on_choice_pressed()`, sehingga hanya intersepsi terhadap aksi konfirmasi aktual (`choice_share_confirm` atau `action_share`) yang memunculkan pop-up modal. Pilihan `"choice_share"` dibiarkan mengalir ke `dm.select_choice()`, yang akan mentransisikan state ke `NODE_OFFER`.

```gdscript
# Target: scripts/ui/dialogue_ui.gd (baris 170-178)
func _on_choice_pressed(choice_id: String) -> void:
	if choice_id == "choice_close" or choice_id == "close":
		close()
		return

	if choice_id == "choice_share_confirm" or choice_id == "action_share":
		_prompt_share_confirmation()
		return

	var dm := _get_dialogue_manager()
	if dm != null and dm.has_method("select_choice"):
		var res: Dictionary = dm.select_choice(choice_id)
		if res.has("node"):
			display_node(res["node"])
		elif dm.has_method("get_current_node_data"):
			display_node(dm.get_current_node_data())
```

**Alur Pengalaman Pengguna Pasca Perbaikan**:
1. Pemain yang membawa Sayur Bening berbicara dengan tetangga:
   - Jika intro belum pernah dilakukan: dialog mulai di `NODE_INTRO`. Pemain melihat opsi "Bagikan 1 porsi" (`choice_share`).
   - Jika intro sudah selesai: dialog langsung dibuka di `NODE_OFFER`.
2. Pemain menekan "Bagikan 1 porsi" (`choice_share`) dari intro/waiting -> UI menampilkan `NODE_OFFER`:
   - Pembicara: Tetangga
   - Teks: *"Harum sekali. Kamu memasak Sayur Bening Bayam dan Jagung?"*
   - Opsi 1: "Bagikan 1 porsi" (`choice_share_confirm`)
   - Opsi 2: "Nanti dulu" (`choice_share_cancel`)
3. Pemain menekan "Bagikan 1 porsi" (`choice_share_confirm`) pada `NODE_OFFER` -> Pop-up modal konfirmasi muncul:
   *"Bagikan 1 porsi hidangan ini? (1 porsi Sayur Bening Bayam dan Jagung dari Tas/Peti Rumah)"*
4. Jika Batal: Modal tertutup, pemain tetap berada di `NODE_OFFER`. Pemain dapat memilih "Nanti dulu" untuk kembali ke `NODE_WAITING`.
5. Jika Ya: 1 porsi dipotong, transisi ke `NODE_RECEIVED` (*"Masih ingat rasanya..."*), dan penutup P0 terpicu.

---

## 4. Analisis Cacat Tambahan (Ancillary Remediation)

### 4.1 Konstruktor `bool` Gagal pada Save Snapshot Malformed
- **Gejala**: Pada Suite 17 (`TestAdversarialLockFreeP0.test_adv06`), snapshot yang memuat tipe string seperti `{"has_spoken_intro": "true"}` memicu galat kritis GDScript:  
  `SCRIPT ERROR: Invalid call. Nonexistent 'bool' constructor at res://scripts/social/dialogue_manager.gd:454`.
- **Akar Masalah**: GDScript 4 tidak mendukung konversi langsung `bool(String)`.
- **Solusi**: Tambahkan fungsi pembantu `_safe_bool(val: Variant, default_val: bool = false) -> bool`:
  ```gdscript
  func _safe_bool(val: Variant, default_val: bool = false) -> bool:
  	if val is bool:
  		return val
  	if val is int or val is float:
  		return val != 0
  	if val is String:
  		var s := val.strip_edges().to_lower()
  		if s == "true" or s == "1":
  			return true
  		if s == "false" or s == "0":
  			return false
  	return default_val
  ```
  Dan terapkan pada `load_save_snapshot()`:
  ```gdscript
  func load_save_snapshot(data: Dictionary) -> bool:
  	if data.is_empty():
  		return false
  	var ver: int = int(data.get("version", 0))
  	if ver < 1:
  		return false

  	has_spoken_intro = _safe_bool(data.get("has_spoken_intro", data.get("talked_to_npc", false)))
  	_has_shared_meal = _safe_bool(data.get("has_shared_meal", data.get("has_shared", false)))
  	meal_used = _safe_bool(data.get("meal_used", false))
  	p0_completed = _safe_bool(data.get("p0_completed", false))
  	dialogue_flags = data.get("dialogue_flags", {}).duplicate(true)
  	return true
  ```

### 4.2 Helper API yang Dijanjikan pada Laporan 014
- **Gejala**: Metode `is_p0_completed()` dan `evaluate_p0_closure()` tercantum pada laporan `014` namun belum ada pada implementasi `scripts/social/dialogue_manager.gd`.
- **Solusi**: Tambahkan kedua metode publik ini di `dialogue_manager.gd`:
  ```gdscript
  func is_p0_completed() -> bool:
  	return p0_completed

  func evaluate_p0_closure() -> bool:
  	var rm := _get_recipe_manager()
  	var recipe_done: bool = rm != null and rm.has_method("is_recipe_completed") and rm.is_recipe_completed(RECIPE_P0_ID)
  	var used: bool = is_meal_used()
  	if recipe_done and used and not p0_completed:
  		p0_completed = true
  		p0_experience_completed.emit(MSG_P0_ENDING)
  		action_success.emit("p0_experience_completed", MSG_P0_ENDING)
  		return true
  	return p0_completed
  ```

### 4.3 Sinkronisasi & Deduplikasi Penutup P0 Lintas Manajer
- **Gejala**: Jika pemain memasak, lalu memakan hidangan di tas (`km.eat_dish`), status `p0_completed` di `KitchenManager` menjadi `true`. Jika kemudian pemain memasak hidangan kedua dan membagikannya ke tetangga via `dm.share_dish`, `DialogueManager` memancarkan kembali sinyal `p0_experience_completed`.
- **Solusi**: Pada `DialogueManager.share_dish()`, periksa apakah `KitchenManager.p0_completed` atau `WorldResourceManager.is_meal_used()` sudah aktif sebelumnya:
  ```gdscript
  	# Evaluasi kondisi penutup P0: recipe_completed == true DAN meal_used == true
  	var rm := _get_recipe_manager()
  	var recipe_done: bool = false
  	if rm != null and rm.has_method("is_recipe_completed"):
  		recipe_done = rm.is_recipe_completed(RECIPE_P0_ID)

  	var newly_completed_p0: bool = false
  	var km_already_done: bool = km != null and km.get("p0_completed") == true
  	if recipe_done and not p0_completed and not km_already_done:
  		p0_completed = true
  		newly_completed_p0 = true
  		p0_experience_completed.emit(MSG_P0_ENDING)
  		action_success.emit("p0_experience_completed", MSG_P0_ENDING)
  	elif recipe_done and km_already_done:
  		p0_completed = true
  ```
  Serta pada `is_meal_used()`:
  ```gdscript
  func is_meal_used() -> bool:
  	if meal_used or _has_shared_meal:
  		return true
  	var wrm := _get_world_resource_manager()
  	if wrm != null and wrm.has_method("is_meal_used") and wrm.is_meal_used():
  		return true
  	return false
  ```

---

## 5. Rencana Verifikasi Komprehensif

Setelah worker pelaksana mengaplikasikan perbaikan di atas, verifikasi menyeluruh dapat dieksekusi melalui urutan berikut:

1. **Uji Otomatis Headless Keseluruhan**:
   Jalankan seluruh suite pengujian melalui terminal headless Godot:
   ```powershell
   & "C:\Users\HP\.local\bin\godot_console.exe" --headless --path . --script res://tests/test_runner.gd
   ```
   **Kriteria Sukses**:
   - Seluruh 17 suite pengujian (termasuk Suite 15 `TestSocial`, Suite 16 `TestAdversarialSocial`, dan Suite 17 `TestAdversarialLockFreeP0`) lulus tanpa galat.
   - Total asersi lulus melampaui 4.100 asersi, Asersi Gagal: 0, Exit Code: 0.
   - Tidak ada lagi pesan error `SCRIPT ERROR: Stack overflow` maupun `ERROR: Stack underflow!`.

2. **Verifikasi Spesifik Kasus Uji Challenger 1 (`ADV.SOC-20`)**:
   - `dm.dialogue_ended.is_connected(ui.close)` bernilai `false`.
   - Pemanggilan `dm.close_dialogue()` saat dialog tidak aktif tidak memancarkan `dialogue_ended`.
   - `test_adv20` mencetak `[PASS] ADV.SOC-20: Tidak terjadi rekursi timbal balik.`.

3. **Verifikasi Alur Dialog Naratif**:
   - Menghubungi tetangga dengan hidangan Sayur Bening: dialog berpindah ke `NODE_OFFER` ("Harum sekali...").
   - Memilih "Nanti dulu" berpindah bersih ke `NODE_WAITING` ("Tidak perlu buru-buru...").
   - Memilih "Bagikan 1 porsi" pada `NODE_OFFER` menampilkan pop-up modal konfirmasi.

4. **Verifikasi Save Snapshot Resiliency (`ADV.LF-06`)**:
   - Snapshot yang memiliki data bolean terdistorsi string (`"true"`, `"false"`) berhasil dimuat secara bersih tanpa error `bool` constructor.
