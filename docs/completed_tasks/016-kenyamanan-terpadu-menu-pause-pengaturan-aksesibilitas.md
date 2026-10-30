# Laporan Task Selesai: UI-001 — Kenyamanan Terpadu: Menu Jeda, Panel Pengaturan, Aksesibilitas Fokus Keyboard, Dialog Konfirmasi Modal, dan Sistem Notifikasi Toast Jujur

Dokumen ini mencatat penyelesaian milestone UI-001 sesuai dengan standar pelaporan AGENTS.md dan TEMPLATE.md.

## Identitas

- **ID task:** UI-001
- **Judul:** Menu jeda, panel pengaturan, aksesibilitas fokus keyboard, dialog konfirmasi modal, dan sistem notifikasi toast jujur
- **Tanggal selesai:** 29 Oktober 2026
- **Agent/pelaksana:** worker_ui_001 (implementer, qa, specialist)
- **Tahap produk:** P0
- **Status:** Selesai
- **Versi sumber/build:** Godot Engine v4.7.2.stable.official.ed1daf0bf, branch `main` / commit lokal (working tree)

## Tujuan dan pemicu

Pemain memerlukan antarmuka terpadu yang nyaman, mudah dinavigasi dengan keyboard maupun mouse, konsisten dengan aturan desain `UI_UX.md` (§ 2, § 3, § 4, § 5, § 6, § 7) dan `CONTENT.md` (§ 11, § 14), serta memenuhi kriteria pengujian `TEST_PLAN.md` (T18, T21, T28, T51, T52, T53, T54). Antarmuka harus menyediakan kontrol jeda simulasi, halaman pengaturan terisolasi (FOV, sensitivitas mouse, head bob, skala UI, mode layar, volume audio, dan subtitle), dialog konfirmasi modal dengan fokus aman untuk aksi destruktif (Game Baru dan Keluar ke Desktop dengan progres belum disimpan), rantai navigasi fokus keyboard beraksen kontras tinggi tanpa softlock, penanganan konflik hotkey Tab, serta sistem notifikasi toast jujur yang terpisah dari prompt interaksi reticle.

Kondisi awal sebelum task ini: Seluruh panel gameplay (tas, buku, dapur, dialog warga) dan sistem penyimpanan (SaveManager) telah berfungsi penuh di memori dan disk, namun belum terdapat `PauseMenu` (`scenes/ui/pause_menu.tscn`), `SettingsMenu` (`scenes/ui/settings_menu.tscn`), `NotificationManager` (`scenes/ui/notification_toast.tscn`), maupun layout audio bus `default_bus_layout.tres` untuk bus "Master", "Music", dan "SFX". Prompt HUD sebelumnya menimpa label reticle (`prompt_label.text`) saat menampilkan feedback tindakan, yang membingungkan pemain ketika melakukan aksi berulang.

## Ruang lingkup

Pekerjaan yang diselesaikan dalam cakupan UI-001 mencakup:
1. **Tata Letak Bus Audio Mesin (`default_bus_layout.tres` & `project.godot`):**
   - Pembuatan aset resource `default_bus_layout.tres` dengan 3 bus audio terdaftar: `Master` (idx 0), `Music` (idx 1), dan `SFX` (idx 2).
   - Konfigurasi `audio/buses/default_bus_layout="res://default_bus_layout.tres"` di `project.godot`.
   - Implementasi metode fallback dinamis `SaveManager.ensure_audio_buses()` agar bus audio otomatis dibuat jika belum terdaftar di lingkungan eksekusi tertentu.
2. **Panel Pengaturan Terpadu (`scenes/ui/settings_menu.tscn` & `scripts/ui/settings_menu.gd`):**
   - Slider FOV (60°..100°, step 1°, default 80°) yang langsung mengikat live ke `PlayerController.fov` dan `Camera3D.fov`.
   - Slider Sensitivitas Mouse (0.1..5.0x, step 0.1x, default 1.0x) yang mengikat live ke `PlayerController.mouse_sensitivity_multiplier` dan `mouse_sensitivity`.
   - Toggle CheckBox Goyangan Kepala (Head Bob, default false) yang mengikat live ke `PlayerController.head_bob_enabled`.
   - Slider Skala UI (0.8..1.5, step 0.05, default 1.0) yang mengikat live ke `get_tree().root.content_scale_factor` (T21).
   - Dropdown OptionButton Mode Layar ("Jendela" 0, "Layar Penuh" 3) yang mengikat ke `DisplayServer.window_set_mode()`.
   - Slider Volume Audio Master, Musik, dan SFX (0%..100%, default 70%, 40%, 70% per CONTENT § 14 dan Suite 19), yang mengonversi linear ke desibel via `linear_to_db()` pada AudioServer dan mengaktifkan mute jika volume <= 0.0001.
   - Toggle CheckBox Subtitle (default true) untuk teks informasi narasi.
   - Tombol aksi: "Simpan & Terapkan", "Kembalikan Default", dan "Kembali".
   - Persistensi mandiri terisolasi di `user://settings.cfg` via `SaveManager.load_settings()` dan `save_settings()` (T52).
3. **Menu Jeda & Dialog Konfirmasi Modal (`scenes/ui/pause_menu.tscn` & `scripts/ui/pause_menu.gd`):**
   - Tombol aksi utama: "Lanjutkan", "Simpan Progres", "Muat Checkpoint", "Pengaturan", "Kembali ke Pekarangan", "Mulai Game Baru", dan "Keluar ke Desktop".
   - Sub-panel modal bertumpuk (*subpanel stack*): `SlotPickerModal` (pemilih slot manual vs otomatis ber-metadata revisi dan ISO timestamp), `SettingsMenu`, dan `ConfirmModal`.
   - Dialog konfirmasi modal:
     - Konfirmasi Timpa Simpanan (*Overwrite Warning*) saat slot manual sudah berisi checkpoint valid.
     - Peringatan Muat Simpanan (*Unsaved Data Loss Warning*) saat memilih slot checkpoint untuk dimuat.
     - Konfirmasi Game Baru: *"Mulai Game Baru? Progres yang belum disimpan akan hilang."* ("Batal" vs "Mulai Baru") (T53).
     - Konfirmasi Keluar Permainan (UI_UX UI06 & T53): *"Simpan & Keluar"*, *"Keluar Tanpa Simpan"*, dan *"Batal"*.
     - Penanganan Error Jujur saat Simpan & Keluar Gagal (T49, T53): Jika penulisan save gagal, aplikasi **tidak keluar**, modal ditutup, dan status error jujur ditampilkan (*"Progres belum tersimpan. Coba lagi atau gunakan lokasi simpan yang dapat ditulis."*).
     - Kembali ke Pekarangan Rumah (posisi aman `(0.0, 0.0, 8.0)` dengan `velocity = Vector3.ZERO` tanpa mereset data dunia).
   - Perilaku Hierarki Tombol Escape (Esc / T18, T28): Menutup lapisan modal teratas terlebih dahulu (ConfirmModal -> SlotPicker/Settings -> Main Pause -> World). Saat kembali ke dunia, mouse dikunci kembali (`MOUSE_MODE_CAPTURED`) dan interaksi dunia diblokir pada frame penutupan (*frame bleed guard*).
   - Integrasi Autoload `InputManager`: Mendorong `ContextMode.PAUSE` dan mematuhi auto-pause saat kehilangan fokus jendela aplikasi (`NOTIFICATION_APPLICATION_FOCUS_OUT`).
4. **Sistem Notifikasi Toast Jujur (`scenes/ui/notification_toast.tscn` & `scripts/ui/notification_manager.gd`):**
   - Kontainer toast terdedikasi pada layer 15 yang ditempatkan di pojok bawah-kanan ("bawah samping"), bebas dari reticle tengah dan prompt interaksi reticle (T54, UI_UX § 5, § 6).
   - Properti `mouse_filter = MOUSE_FILTER_IGNORE` pada kontainer dan panel toast sehingga tidak pernah memblokir putaran mouse maupun klik pemain.
   - Kapasitas maksimal 2 toast terlihat bersamaan. Pesan baru berikutnya masuk antrean (*pending queue*).
   - Durasi tampil 2.5 detik dengan animasi fadeout halus pada 0.4 detik terakhir.
   - Penggabungan Pickup Cepat (*Rapid Item Pickup Merging*): Pengambilan item yang sama secara beruntun menggabungkan jumlah (misal: `"Memetik Bayam (x2)"`) dan me-reset timer durasi ke 2.5 detik.
   - Peredam Error Berulang (*Repeated Error Debounce*): Jendela debounce 1.2 detik sehingga menahan tombol aksi gagal tidak membanjiri layar.
   - Dukungan pesan jujur standar `CONTENT.md` § 11 via `show_honest_message()`.
5. **Navigasi Aksesibilitas Keyboard (T51):**
   - Indikator visual fokus beraksen kontras tinggi (`StyleBoxFlat` dengan border 2px warna emas hangat `Color(1.0, 0.85, 0.3)`).
   - Tautan sirkular navigasi fokus (*circular traversal loops*) pada seluruh tombol menu jeda dan panel pengaturan menggunakan panah Atas/Bawah serta Tab/Shift+Tab tanpa softlock.
   - Resolusi konflik tombol Tab (UI_UX § 3): Pada panel inventaris solo, tombol Tab dikonsumsi untuk menutup panel; pada panel menu lain Tab menggerakkan fokus.
   - Pemulihan fokus modal: Menutup modal konfirmasi secara otomatis memulihkan fokus keyboard ke tombol pemanggilnya. Default fokus modal konfirmasi selalu diarahkan ke "Batal" demi keamanan.
6. **Integrasi Scene Utama (`scenes/main.tscn` & `scripts/main.gd`):**
   - Penambahan instansiasi `PauseMenu` dan `NotificationToast` ke dalam scene utama `Main`.
   - Penyambungan delegasi `show_toast`, `show_pickup`, dan `show_error` pada `HUD` ke `NotificationManager`.
7. **Suite Pengujian Penerimaan 21 (`tests/suites/test_ui.gd`):**
   - 17 metode pengujian terstruktur dalam 8 grup yang memverifikasi T18, T21, T28, T51, T52, T53, T54, dan Audio Buses.
   - Pendaftaran Suite 21 pada `tests/test_runner.gd`.

## Perubahan dan perilaku akhir

- **Pengalaman Menu Jeda:** Menekan Esc di dunia 3D membuka Menu Jeda. Simulasi kompor dan pertumbuhan tanaman membeku (`ContextMode.PAUSE`). Kursor mouse bebas. Tombol pertama ("Lanjutkan") otomatis memegang fokus keyboard. Menekan Esc atau tombol Lanjutkan menutup menu, mengunci mouse kembali, dan mencegah kebocoran klik ke dunia.
- **Pengaturan Langsung Berfungsi:** Mengubah slider FOV, sensitivitas mouse, head bob, atau skala UI langsung mengubah perilaku permainan dan tersimpan ke `user://settings.cfg`. Memuat save game lama tidak menimpa pengaturan yang sudah disesuaikan.
- **Keamanan Progres:** Aksi destruktif (menimpa save, memuat save saat ada progres belum disimpan, memulai Game Baru, atau keluar ke desktop) dilindungi dialog modal dengan tombol Batal sebagai fokus default. Jika pemain memilih "Simpan & Keluar" tetapi terjadi kegagalan tulis disk, aplikasi menolak keluar dan memberikan pesan jujur di layar.
- **Umpan Balik Tidak Mengganggu:** Notifikasi item dan status tampil di pojok kanan bawah, tidak menutupi crosshair atau prompt interaksi tombol E, menggabungkan item berturut-turut, membatasi maksimal 2 pesan, dan tidak pernah merebut input mouse/kamera.

## File yang ditambahkan atau diubah

| File | Status | Deskripsi Perubahan |
| --- | --- | --- |
| `default_bus_layout.tres` | Ditambahkan | Resource layout audio bus Godot dengan bus "Master", "Music", dan "SFX". |
| `project.godot` | Diubah | Mendaftarkan `audio/buses/default_bus_layout="res://default_bus_layout.tres"`. |
| `scripts/save/save_manager.gd` | Diubah | Menambahkan sinyal `setting_changed`, `settings_applied`, metode `ensure_audio_buses()`, `apply_all_settings()`, `_apply_bus_volume()`, penanganan alias sensitivitas, dan auto-apply saat save/load settings. |
| `scripts/player/player_controller.gd` | Diubah | Menambahkan setter `mouse_sensitivity_multiplier`, inisialisasi live settings dari SaveManager pada `_ready()`, dan listener dinamis `_on_save_manager_setting_changed`. |
| `scripts/core/input_manager.gd` | Diubah | Memperluas auto-pause on focus loss agar berlaku pada konteks apapun selain PAUSE (`get_current_context() != ContextMode.PAUSE`). |
| `scripts/ui/inventory_ui.gd` | Diubah | Menambahkan penanganan `_unhandled_input` untuk menutup panel inventaris solo ketika tombol Tab ditekan, mencegah konflik navigasi fokus (UI_UX § 3). |
| `scripts/ui/hud.gd` | Diubah | Menambahkan delegasi `show_toast()`, `show_pickup()`, `show_error()` ke `NotificationManagerClass.instance` tanpa menimpa prompt reticle. |
| `scripts/ui/notification_manager.gd` | Ditambahkan | Implementasi lengkap antarmuka notifikasi toast jujur (maksimal 2 toast, durasi 2.5s, merging pickup cepat, debounce error 1.2s, mouse filter ignore, static instance). |
| `scenes/ui/notification_toast.tscn` | Ditambahkan | Scene grafis untuk kontainer toast di layer 15 pada posisi bawah-kanan (bottom-right 4% safe margin). |
| `scripts/ui/settings_menu.gd` | Ditambahkan | Logika panel pengaturan terpadu (FOV, Sensitivitas, Head Bob, UI Scale, Window Mode, Audio Buses, Subtitle, Save/Apply, Reset Default, dan circular keyboard focus). |
| `scenes/ui/settings_menu.tscn` | Ditambahkan | Scene grafis panel pengaturan berlatar solid dengan TabContainer (Kendali, Tampilan, Audio, Aksesibilitas) dan tombol aksi. |
| `scripts/ui/pause_menu.gd` | Ditambahkan | Logika menu jeda utama, subpanel stack, hirarki Esc, dialog konfirmasi modal timpa/keluar/baru/muat, pengalihan posisi aman pekarangan, dan status jujur. |
| `scenes/ui/pause_menu.tscn` | Ditambahkan | Scene grafis menu jeda di layer 14 memuat background dimmer, panel tombol aksi, modal slot picker, modal konfirmasi, dan instansiasi settings menu. |
| `scenes/main.tscn` | Diubah | Menambahkan node `PauseMenu` dan `NotificationToast` ke dalam hierarki scene utama. |
| `scripts/main.gd` | Diubah | Mereferensikan node `pause_menu` dan `notification_toast`. |
| `tests/suites/test_ui.gd` | Ditambahkan | Suite pengujian penerimaan Suite 21 mencakup 17 metode uji untuk T18, T21, T28, T51, T52, T53, T54, dan Audio Buses. |
| `tests/test_runner.gd` | Diubah | Mendaftarkan dan mengeksekusi Suite 21 `TestUI`. |

## Verifikasi yang benar-benar dilakukan

Pemeriksaan otomatis dijalankan menggunakan binary Godot 4.7.2 stable headless console di lingkungan Windows 11 host:

```powershell
& "C:\Users\HP\.local\bin\godot_console.exe" --headless --script tests/test_runner.gd
```

### Tabel Rincian Hasil Verifikasi

| ID Uji | Lingkungan / Input | Tindakan Pemeriksaan | Hasil Aktual | Status |
| --- | --- | --- | --- | --- |
| **T18-01** | Headless CLI / `InputManager` & `PlayerController` | Dorong konteks PAUSE -> periksa penguncian gerak/pandang dan pembekuan simulasi -> pop konteks -> periksa *frame guard* interaksi | Gerak dan pandang terkunci saat jeda; simulasi membeku; interaksi dunia diblokir pada frame penutupan | **LULUS** |
| **T18-02** | Headless CLI / `InputManager` | Emisikan notifikasi `NOTIFICATION_APPLICATION_FOCUS_OUT` saat auto-pause aktif | Konteks otomatis beralih ke `ContextMode.PAUSE` | **LULUS** |
| **T21-01** | Headless CLI / `SaveManager` & `PlayerController` | Ubah FOV ke 90° dan UI Scale ke 1.25 -> panggil `apply_all_settings()` | `player.fov == 90.0`, `cam.fov == 90.0`, dan `content_scale_factor == 1.25` | **LULUS** |
| **T21-02** | Headless CLI / `scenes/ui/hud.tscn` & `notification_toast.tscn` | Muat layout HUD dan ToastContainer -> periksa reticle dan mouse filter | Reticle terpusat; ToastContainer ber-preset `mouse_filter == MOUSE_FILTER_IGNORE` | **LULUS** |
| **T28-01** | Headless CLI / `PauseMenu` | Buka jeda -> dorong `slot_picker_modal` -> dorong `confirm_modal` | Kedalaman tumpukan subpanel tepat bernilai 2 | **LULUS** |
| **T28-02** | Headless CLI / `PauseMenu` | Kirimkan 3 event aksi `pause_menu` (Esc) berurutan | Esc 1 menutup confirm modal; Esc 2 menutup slot picker; Esc 3 menutup pause menu ke dunia | **LULUS** |
| **T51-01** | Headless CLI / `PauseMenu` | Periksa 7 tombol menu jeda | Seluruh tombol memiliki `focus_mode == FOCUS_ALL`, StyleBox focus terpasang, dan link sirkular atas/bawah terhubung | **LULUS** |
| **T51-02** | Headless CLI / `InventoryUI` | Buka inventaris solo -> kirimkan aksi `open_inventory` (Tab) | Panel inventaris solo langsung tertutup tanpa softlock | **LULUS** |
| **T51-03** | Headless CLI / `PauseMenu` | Beri fokus pada `btn_settings` -> buka modal konfirmasi -> tutup modal | Fokus keyboard kembali pulih secara otomatis ke `btn_settings` | **LULUS** |
| **T52-01** | Headless CLI / `SaveManager` | Tulis sensitivitas 2.5, master 0.55, subtitles true ke `settings.cfg` -> baca ulang | Nilai pengaturan persisten dan terbaca identik dari disk | **LULUS** |
| **T52-02** | Headless CLI / `SaveManager` | Set FOV 92° -> simpan game manual -> muat ulang game manual | Nilai FOV tetap 92.0°, tidak tertimpa oleh data snapshot save game | **LULUS** |
| **T53-01** | Headless CLI / `PauseMenu` | Klik tombol Keluar -> periksa dialog modal konfirmasi -> klik Batal | Modal konfirmasi keluar tampil; memilih Batal membatalkan keluar dengan aman | **LULUS** |
| **T53-02** | Headless CLI / `PauseMenu` & `SaveManager` | Simulasikan kegagalan tulis disk (`simulate_write_failure = true`) -> pilih "Simpan & Keluar" | Aplikasi menolak keluar (`quit()` tidak dipanggil), modal tertutup, dan pesan jujur *"Progres belum tersimpan..."* tampil | **LULUS** |
| **T53-03** | Headless CLI / `PauseMenu` | Klik tombol "Mulai Game Baru" | Modal konfirmasi tampil dengan peringatan kehilangan data belum disimpan | **LULUS** |
| **T54-01** | Headless CLI / `NotificationManager` | Panggil `show_toast` 4 kali beruntun -> majukan waktu 2.6s | Maksimal 2 toast tampil bersamaan; antrean berikutnya tampil sesudah 2.5s | **LULUS** |
| **T54-02** | Headless CLI / `NotificationManager` | Panggil `show_pickup("Bayam", 1)` 2 kali beruntun | Digabung menjadi 1 toast dengan teks `"Memetik Bayam (x2)"` dan durasi ter-refresh | **LULUS** |
| **T54-03** | Headless CLI / `NotificationManager` | Panggil `show_error("Tanah belum siap")` 5 kali dalam 0.3s | Hanya 1 toast ditampilkan; 4 pemanggilan berikutnya diredam oleh debounce 1.2s | **LULUS** |
| **T54-04** | Headless CLI / `NotificationManager` | Evaluasi `mouse_filter` pada container dan toast children | `mouse_filter == MOUSE_FILTER_IGNORE` pada container dan panel toast | **LULUS** |
| **AUDIO-01** | Headless CLI / `AudioServer` & `SaveManager` | Panggil `ensure_audio_buses()` -> uji volume 0.5 linear -> uji volume 0.0 | Bus Master, Music, dan SFX terverifikasi; 0.5 terkonversi ke ~ -6.02 dB; 0.0 otomatis di-mute | **LULUS** |
| **REGRESI** | Headless CLI / `tests/test_runner.gd` | Jalankan seluruh Suite 1 s/d 21 | **Total 6.895 asersi LULUS, 0 asersi GAGAL (Exit Code: 0)** | **LULUS** |

## Kriteria selesai

- [x] **T18 (Pause & Input Gating):** Simulasi membeku saat jeda, mouse bebas, kehilangan fokus aplikasi memicu jeda otomatis, dan interaksi pada frame penutupan tidak bocor ke dunia.
- [x] **T21 (Pengaturan FOV & Skala UI):** Slider FOV dan Skala UI langsung memperbarui kamera pemain dan skala antarmuka kanvas tanpa merusak hierarki tampilan.
- [x] **T28 (Hierarki Esc & Input Context):** Tumpukan subpanel menutup secara berlapis (Confirm -> Subpanel -> Menu Jeda -> Dunia) dengan pemulihan penangkapan mouse.
- [x] **T51 (Aksesibilitas & Fokus Keyboard):** Indikator fokus emas kontras tinggi terlihat, tombol memiliki link sirkular atas/bawah, penutupan modal memulihkan fokus pemanggil, dan Tab pada inventaris solo menutup panel tanpa konflik.
- [x] **T52 (Persistensi Pengaturan):** Konfigurasi tersimpan mandiri di `user://settings.cfg` dan terisolasi dari snapshot save/load dunia.
- [x] **T53 (Konfirmasi Aksi Destruktif & Error Jujur):** Modal konfirmasi melindungi Game Baru dan Keluar. Jika Simpan & Keluar gagal tulis disk, aplikasi tidak keluar dan menampilkan alasan jujur.
- [x] **T54 (Notifikasi Toast Jujur):** Notifikasi berada di pojok kanan bawah, tidak menutupi prompt reticle, maksimal 2 terlihat, durasi 2.5s, pickup cepat digabung, error berulang diredam 1.2s, dan mouse filter ignore.

## Dampak, kompatibilitas dan keterbatasan

- **Dampak Konten & UI:** HUD gameplay sekarang bersih dari feedback yang menimpa reticle prompt. Pemain dapat menyesuaikan kontrol kenyamanan visual dan audio secara mandiri.
- **Kompatibilitas:** Struktur save game dan skema `settings.cfg` terpisah sepenuhnya, menjamin kompatibilitas mundur terhadap checkpoint SAVE-001 yang telah dibuat sebelumnya. Nilai default volume (0.7 / 0.4 / 0.7) menjaga validitas seluruh asersi Suite 19.
- **Keterbatasan:** Di lingkungan headless CLI, mode fullscreen fisik dan output driver audio menggunakan driver virtual dummy. Pengujian kenyamanan visual layout dilakukan saat playtest antarmuka grafis.

## Tindak lanjut dan handoff

- **ID task berikutnya:** `ART-001` (Identitas Visual dan Audio Dasar yang Konsisten).
- **Prasyarat:** Milestone UI-001 telah selesai 100% dan seluruh 21 suite uji (6.895 asersi) lulus tanpa kegagalan.
- **Fokus ART-001:** Memperjelas identitas visual dan audio dasar (penggantian graybox secukupnya pada tanaman bayam/jagung/temu kunci, model rumah, dan efek suara penting pada interaksi alat/pemasakan) dengan lisensi/atribusi yang tercatat rapi.

## Penutupan catatan

Laporan ini ditautkan pada `docs/PROJECT_STATUS.md`, status task UI-001 ditandai `SELESAI` pada `docs/TASKS.md`, dan deskripsi status pekerjaan terakhir diperbarui sesuai ketentuan AGENTS.md.
