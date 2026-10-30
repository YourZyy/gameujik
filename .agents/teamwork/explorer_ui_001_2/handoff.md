# Handoff Report: Investigasi & Perancangan Panel Pengaturan & Live Parameter Bindings (UI-001)

## 1. Observation

### 1.1 Struktur dan Implementasi `settings.cfg` di `SaveManager`
Pemeriksaan langsung pada `scripts/save/save_manager.gd` (baris 548–624):
```gdscript
func load_settings() -> Dictionary:
	var config := ConfigFile.new()
	var err := config.load(_settings_path)
	if err != OK:
		_settings = get_default_settings()
		save_settings(_settings)
	else:
		_settings = {
			"gameplay": {
				"mouse_sensitivity_multiplier": float(config.get_value("gameplay", "mouse_sensitivity_multiplier", 1.0)),
				"head_bob": bool(config.get_value("gameplay", "head_bob", false))
			},
			"video": {
				"fov": float(config.get_value("video", "fov", 80.0)),
				"ui_scale": float(config.get_value("video", "ui_scale", 1.0)),
				"window_mode": int(config.get_value("video", "window_mode", 0))
			},
			"audio": {
				"master_volume": float(config.get_value("audio", "master_volume", 0.7)),
				"music_volume": float(config.get_value("audio", "music_volume", 0.4)),
				"sfx_volume": float(config.get_value("audio", "sfx_volume", 0.7))
			},
			"accessibility": {
				"subtitles": bool(config.get_value("accessibility", "subtitles", true))
			}
		}
	settings_loaded.emit()
	return _settings
```
Dan pada `tests/suites/test_save.gd` (baris 688–698):
```gdscript
var fov: float = float(cfg.get_value("video", "fov", 0.0))
var sens: float = float(cfg.get_value("gameplay", "mouse_sensitivity_multiplier", 0.0))
var vol_master: float = float(cfg.get_value("audio", "master_volume", 0.0))
var subtitles: bool = bool(cfg.get_value("accessibility", "subtitles", false))

if not Assertions.assert_approx_equal(fov, 80.0, 0.01, "T49-01: Default FOV 80"): passed = false
if not Assertions.assert_approx_equal(sens, 1.0, 0.01, "T49-01: Default sensitivitas 1.0"): passed = false
if not Assertions.assert_approx_equal(vol_master, 0.7, 0.01, "T49-01: Default master volume 0.7"): passed = false
if not Assertions.assert_true(subtitles, "T49-01: Default subtitles true"): passed = false
```

### 1.2 Status Parameter dan Kendali pada `PlayerController`
Pemeriksaan langsung pada `scripts/player/player_controller.gd`:
- **FOV:** Baris 19–23:
  ```gdscript
  @export var fov: float = PlayerConfig.DEFAULT_FOV:
      set(value):
          fov = clampf(value, PlayerConfig.MIN_FOV, PlayerConfig.MAX_FOV)
          if camera:
              camera.fov = fov
  ```
- **Sensitivitas Mouse:** Baris 18, 196–199:
  ```gdscript
  @export var mouse_sensitivity: float = PlayerConfig.DEFAULT_MOUSE_SENSITIVITY
  ...
  rotate_y(-relative_motion.x * mouse_sensitivity)
  camera_pitch -= relative_motion.y * mouse_sensitivity
  ```
  Pada `scripts/player/player_config.gd` (baris 18–19):
  `BASE_MOUSE_SENSITIVITY_DEG_PER_PIXEL: float = 0.1`
  `DEFAULT_MOUSE_SENSITIVITY: float = 0.00174532925` (ekuivalen dengan `deg_to_rad(0.1)`).
- **Head Bob:** Baris 28, 282–292:
  `@export var head_bob_enabled: bool = false`
  Saat false, offset lerp halus ke `Vector3.ZERO`:
  `_bob_offset = _bob_offset.lerp(Vector3.ZERO, clampf(delta * 10.0, 0.0, 1.0))`.

### 1.3 Keadaan Bus Audio Mesin Godot
Melalui pengujian empiris CLI konsol Godot engine (`godot_console.exe --headless`):
- `AudioServer.bus_count` saat ini bernilai **1** (hanya bus index 0: `"Master"`).
- Bus `"Music"` dan `"SFX"` belum terdaftar pada berkas proyek (`default_bus_layout.tres` belum ada di repositori). Pemanggilan `AudioServer.get_bus_index("Music")` saat ini mengembalikan `-1`.
- `linear_to_db(1.0) == 0.0 dB`, `linear_to_db(0.7) == -3.1 dB`, `linear_to_db(0.4) == -8.0 dB`, `linear_to_db(0.0001) == -80.0 dB`. `linear_to_db(0.0)` bernilai `-inf`.

### 1.4 Mekanisme Skala UI di Godot 4.7 (T21)
Pengujian API membuktikan:
- `get_tree().root` bertipe `Window`.
- Properti bawaan `get_tree().root.content_scale_factor` bernilai `1.0` secara default dan dapat dimutasi secara dinamis (misal `1.25`, `1.5`) saat runtime.
- Bersama konfigurasi `project.godot`:
  `window/stretch/mode="canvas_items"`
  `window/stretch/aspect="keep"`
  Pengubahan `content_scale_factor` secara otomatis menskala seluruh elemen CanvasLayer / Control tanpa memecah hierarki kontainer.

### 1.5 Mode Layar Windowed vs Fullscreen
Pengujian DisplayServer:
- `DisplayServer.WINDOW_MODE_WINDOWED` bernilai `0`.
- `DisplayServer.WINDOW_MODE_FULLSCREEN` bernilai `3`.
- `DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN` bernilai `4`.

---

## 2. Logic Chain

### 2.1 Rekonsiliasi Skema `settings.cfg` (Integritas Suite 19 vs Spesifikasi Baru)
1. **Fakta:** Suite 19 `test_save.gd` (`test_t49_01`) secara ketat memverifikasi bahwa `cfg.get_value("gameplay", "mouse_sensitivity_multiplier", 0.0)` bernilai `1.0` dan `cfg.get_value("audio", "master_volume", 0.0)` bernilai `0.7` (mengikuti `CONTENT.md` §14).
2. **Implikasi:** Jika worker mengganti nama kunci disk `mouse_sensitivity_multiplier` menjadi `mouse_sensitivity`, atau mengubah default volume master menjadi `1.0`, maka Suite 19 akan mengalami regresi/kegagalan uji.
3. **Solusi Desain:**
   - Kunci disk di `settings.cfg` tetap mempertahankan `mouse_sensitivity_multiplier` sebagai kunci utama serialisasi, namun API antarmuka `SaveManager.get_setting()` / `set_setting()` mendukung alias `mouse_sensitivity`.
   - Nilai default audio tetap `0.7` (Master), `0.4` (Musik), dan `0.7` (SFX) sesuai `CONTENT.md` §14 dan Suite 19, sedangkan slider UI merepresentasikan rentang 0% hingga 100% (0.0..1.0).
   - Mode layar `"window_mode"` disimpan sebagai integer (`0` = Windowed, `1` / `3` = Fullscreen) dengan konversi transparan dari/ke string `"windowed"` / `"fullscreen"`.

### 2.2 Jalur Ikatan Dinamis Parameter (Dynamic Live Engine Bindings)

#### A. FOV (Field of View) Pandangan
- **Jalur:** `HSlider` (60°..100°, step 1°) → `SaveManager.set_setting("video", "fov", val)` → `SaveManager.setting_changed.emit("video", "fov", val)` → `PlayerController.fov = val` → setter memicu `camera.fov = val`.
- **Inisialisasi Awal:** Di `PlayerController._ready()`, membaca `SaveManager.get_setting("video", "fov", 80.0)`.

#### B. Sensitivitas Mouse
- **Jalur:** `HSlider` (0.1..5.0x, step 0.1x) → `SaveManager.set_setting("gameplay", "mouse_sensitivity_multiplier", val)` → `PlayerController.mouse_sensitivity_multiplier = val` → setter mengalikan `mouse_sensitivity = PlayerConfig.DEFAULT_MOUSE_SENSITIVITY * val`.
- **Dampak Rotasi:** Saat `handle_mouse_look(relative_motion)` dieksekusi di `_unhandled_input`, yaw dan pitch kamera diskalakan secara linear sesuai pengali.

#### C. Head Bob (Goyangan Kepala)
- **Jalur:** `CheckButton` (Aktif/Nonaktif, default Nonaktif) → `SaveManager.set_setting("gameplay", "head_bob", val)` → `PlayerController.head_bob_enabled = val`.
- **Dampak:** Logika kalkulasi `_update_head_bob()` diaktifkan atau dinonaktifkan. Saat dinonaktifkan di tengah langkah, `_bob_offset` melakukan interpolasi `lerp` menuju `Vector3.ZERO`, menjamin ketiadaan visual jerk/snap.

#### D. Skala UI (T21)
- **Jalur:** `OptionButton` ("100%", "125%", "150%") atau `HSlider` (0.8..1.5) → `SaveManager.set_setting("video", "ui_scale", val)` → eksekusi `get_tree().root.content_scale_factor = val`.
- **Dampak:** Seluruh kanvas UI (HUD, BookUI, InventoryUI, KitchenUI, PauseMenu, DialogueUI) diskalakan secara seragam oleh mesin. Safe-margin ~4% pada layout kontainer mencegah pemotongan teks di tepi layar (T21).

#### E. Server Audio (AudioServer & Fallback Bus)
- **Jalur:** `HSlider` (0%..100%) → konversi linear ke dB: `linear_to_db(clampf(vol, 0.0001, 1.0))`.
- **Penanganan Bus Hilang:**
  Karena bus `"Music"` dan `"SFX"` belum ada pada bus layout default, modul audio wajib menjalankan `ensure_audio_buses()` saat inisialisasi:
  ```gdscript
  for bus_name in ["Music", "SFX"]:
      if AudioServer.get_bus_index(bus_name) == -1:
          var idx := AudioServer.bus_count
          AudioServer.add_bus(idx)
          AudioServer.set_bus_name(idx, bus_name)
          AudioServer.set_bus_send(idx, "Master")
  ```
- **Batas Nilai Ekstrem (Muting):**
  Jika volume `linear_vol <= 0.0001`, panggil `AudioServer.set_bus_mute(idx, true)` dan set `-80.0 dB` untuk menghindari nilai `-inf`. Jika `> 0.0001`, aktifkan `set_bus_mute(idx, false)` dan atur volume dB.

#### F. Mode Jendela (Window Mode)
- **Jalur:** `OptionButton` ("Jendela", "Layar Penuh") → jika mode fullscreen, panggil `DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)`. Jika windowed, panggil `DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)`.
- **Perlindungan Uji:** Beri pengecekan `if DisplayServer.get_name() != "headless":` agar test suite headless tidak mengalami crash grafis.

### 2.3 Pembuktian Ketahanan Pengaturan Lintas Sesi & Reset Adegan (T52)
1. `settings.cfg` dikelola terpisah dari arsip save game (`save_manual.json` dan `save_autosave.json`).
2. `SaveManager.load_game()` hanya memvalidasi dan memuat snapshot entitas dunia (`player`, `inventory`, `gardening`, `world`, `cooking`, `recipe`, `dialogue`). `_settings` di memori tidak disentuh.
3. Karena `SaveManager` adalah Autoload singleton, dictionary `_settings` bertahan sepanjang siklus hidup proses aplikasi, termasuk saat `get_tree().reload_current_scene()` atau `get_tree().change_scene_to_file()` dipanggil.
4. Setiap node `PlayerController` baru yang diinstansiasi secara otomatis membaca pengaturan mutakhir dari `SaveManager` pada fungsi `_ready()`.

---

## 3. Caveats

1. **Resolusi Window Saat Headless:**
   Di lingkungan headless (eksekusi CLI test runner), fungsi `DisplayServer.window_set_mode` dan `DisplayServer.window_get_size` berstatus virtual tanpa tampilan jendela fisik. Pengujian mode layar dan ukuran jendela harus diverifikasi via pengecekan nilai state dan mock driver, bukan inspeksi monitor fisik.
2. **Audio Output di Headless:**
   `AudioServer` memproses bus volume secara internal (dB level berubah), namun driver audio fisik bernilai dummy (`Dummy`). Pemeriksaan volume audio pada test suite harus memverifikasi nilai `AudioServer.get_bus_volume_db(idx)` dan `AudioServer.is_bus_mute(idx)`.
3. **Penyelarasan Nilai Default Volume:**
   Dokumen `CONTENT.md` §14 dan test suite `test_save.gd` mematok volume Master awal pada 0.7 (70%) dan Musik pada 0.4 (40%). Dispatch menyebutkan Master 1.0, Musik 0.8, SFX 0.8. Worker disarankan mempertahankan default internal `SaveManager` pada 0.7 / 0.4 / 0.7 agar Suite 19 tidak rusak, sementara slider UI diberi kebebasan penuh dari 0.0 hingga 1.0.

---

## 4. Conclusion

### 4.1 Rancangan Arsitektur Modul UI-001
Untuk menyelesaikan UI-001 secara elegan, Worker direkomendasikan mengimplementasikan:

1. **Pembaruan `SaveManager` (`scripts/save/save_manager.gd`):**
   - Tambahkan sinyal: `signal setting_changed(section: String, key: String, value: Variant)` dan `signal settings_applied()`.
   - Tambahkan metode `ensure_audio_buses() -> void` untuk membuat bus `"Music"` dan `"SFX"` bila belum ada.
   - Tambahkan metode `apply_setting(section: String, key: String, value: Variant) -> void`.
   - Tambahkan metode `apply_all_settings() -> void` yang menerapkan video (FOV, skala UI, mode layar), audio (Master, Musik, SFX), dan gameplay (sensitivitas, head bob) ke sistem live.
   - Dukung alias `mouse_sensitivity` ↔ `mouse_sensitivity_multiplier` dan `window_mode` string/int.

2. **Pembaruan `PlayerController` (`scripts/player/player_controller.gd`):**
   - Tambahkan properti setter:
     ```gdscript
     @export var mouse_sensitivity_multiplier: float = 1.0:
         set(value):
             mouse_sensitivity_multiplier = clampf(value, 0.1, 5.0)
             mouse_sensitivity = PlayerConfig.DEFAULT_MOUSE_SENSITIVITY * mouse_sensitivity_multiplier
     ```
   - Di `_ready()`, hubungkan ke `SaveManager.setting_changed` dan baca konfigurasi awal untuk FOV, sensitivitas, dan head bob.

3. **Komponen UI Pengaturan (`scenes/ui/settings_menu.tscn` & `scripts/ui/settings_menu.gd`):**
   - Tata letak Kontrol: `PanelContainer` berlatar solid dengan `TabContainer` atau kelompok kartu vertikal:
     - **Tab Kendali:** Slider Sensitivitas (0.1..5.0×, step 0.1) & Slider FOV (60..100°, step 1).
     - **Tab Tampilan:** Opsi Mode Layar (Jendela / Layar Penuh) & Opsi Skala UI (100%, 125%, 150%).
     - **Tab Audio:** Slider Master, Musik, SFX (0..100%).
     - **Tab Kenyamanan:** CheckButton Head Bob & Subtitle.
     - **Bilah Bawah:** Tombol "Terapkan & Simpan", "Batal", "Default".
   - Integrasi keyboard focus: Tombol pertama otomatis mengambil `grab_focus()`, seluruh kontrol memiliki `focus_mode = FOCUS_ALL`.
   - Tombol Esc menutup SettingsMenu dan kembali ke PauseMenu tanpa aksi dunia yang bocor.

4. **Komponen UI Pause Menu (`scenes/ui/pause_menu.tscn` & `scripts/ui/pause_menu.gd`):**
   - Memuat tombol aksi: "Lanjutkan", "Simpan Permainan", "Muat Permainan", "Pengaturan", "Kembali ke Pekarangan", "Menu Utama", "Keluar".
   - Menggunakan `InputManager.ContextMode.PAUSE` untuk mengunci pergerakan dan membebaskan mouse.

5. **Audio Bus Layout (`default_bus_layout.tres`):**
   - Tambahkan berkas `default_bus_layout.tres` di root proyek dengan 3 bus: Master, Music, SFX.

---

## 5. Verification Method

### 5.1 Perintah Verifikasi Headless CLI
Jalankan test suite menggunakan konsol Godot di Windows host:
```powershell
& "C:\Users\HP\.local\bin\godot_console.exe" --headless --script res://tests/test_runner.gd
```

### 5.2 Kasus Uji Penerimaan yang Wajib Terpenuhi di Suite UI (T21, T51, T52)
1. **Kasus T21 (Skala UI & FOV):**
   - Skrip uji memodifikasi `ui_scale` menjadi `1.25` dan `1.5`: periksa `get_tree().root.content_scale_factor == 1.25`.
   - Modifikasi FOV menjadi 90°: verifikasi `player.camera.fov == 90.0`.
2. **Kasus T51 (Navigasi Fokus & Hirarki Input):**
   - Buka `PauseMenu`: periksa kontrol pertama memiliki fokus (`has_focus() == true`).
   - Tekan Esc dari Settings: pastikan konteks input kembali ke `PAUSE`, bukan bocor ke `WORLD`.
   - Tekan Esc dari Pause: pastikan konteks input kembali ke `WORLD` dan mouse terkunci kembali.
3. **Kasus T52 (Persistensi Pengaturan Lintas Sesi):**
   - Simpan pengaturan baru via `SaveManager.save_settings(...)`.
   - Jalankan `SaveManager.load_game("manual")` (simulasi muat save lama).
   - Pastikan nilai `SaveManager.get_setting("video", "fov")` tetap mempertahankan nilai baru dan tidak tertimpa oleh save game lama.
4. **Kasus Audio (AudioServer & Fallback Bus):**
   - Jalankan `ensure_audio_buses()`: periksa `AudioServer.get_bus_index("Music") != -1` dan `AudioServer.get_bus_index("SFX") != -1`.
   - Set volume `0.5`: periksa `AudioServer.get_bus_volume_db(idx)` mendekati `linear_to_db(0.5)` (~ -6.02 dB) dan `is_bus_mute == false`.
   - Set volume `0.0`: periksa `is_bus_mute == true` dan `volume_db <= -80.0 dB`.

### 5.3 Kondisi Kegagalan (Invalidation Conditions)
Laporan ini batal jika:
- Penulisan `settings.cfg` mengubah format sehingga menyebabkan Suite 19 `test_save.gd` gagal.
- Pemanggilan `AudioServer.set_bus_volume_db` menghasilkan error indeks bus negatif `-1`.
- Pengubahan skala UI atau FOV memicu pemotongan elemen teks penting di luar safe margin 4%.
