# Rencana 02 — Visual Stylized, Aset, Karakter dan UI

**Status:** USULAN perencanaan (bukan implementasi). **Tanggal:** 30 Oktober 2026. **Renderer:** Godot 4.7.2, `gl_compatibility` (project.godot).
**Prioritas keputusan:** instruksi terbaru pengguna (grafik stylized "lumayan", tidak kotak-kotak) mengungguli [ART_DIRECTION.md](../ART_DIRECTION.md) v0.2 yang menyebut graybox cukup untuk P0. Bagian ART_DIRECTION yang berubah (§5 kabut "tidak wajib", §6 tahap mutu, §7 daftar aset) harus diperbarui oleh task VIS-001 setelah rencana disetujui; jangan menambah catatan kontradiktif.
**Batas:** tidak ada kode, aset atau unduhan yang dibuat oleh dokumen ini. Semua angka bertanda HIPOTESIS wajib diukur di Windows pengguna. Godot tidak terpasang di sesi perencanaan; tidak ada yang sudah dilihat atau diuji.

## 0. Kondisi saat ini (diperiksa dari file)

- Level dibangun skrip `scripts/tools/build_level_graybox.gd` dari `BoxMesh`; material `StandardMaterial3D` polos per warna (hex dari ART_DIRECTION §4). Pagar bambu, rumah, atap miring semuanya kotak yang diputar.
- Tanaman bayam/jagung/temu kunci dirakit kode di `scripts/main.gd` (`_build_stage_0_seed` … `_build_stage_3_harvestable`, `CylinderMesh`/`BoxMesh`, cache material `_get_crop_material`). Meta `crop_height`, `primitive_count`, `stage_color` dibaca tes; jangan putus kontraknya tanpa memperbarui suite.
- `scenes/main.tscn` sudah memiliki `ProceduralSkyMaterial`, `Environment`, `tonemap_mode = 2`, `DirectionalLight3D` dengan `shadow_enabled`. Fog/glow belum diperiksa isinya; verifikasi saat VIS-001.
- Pemain (`build_player_scene.gd`): kapsul + `Head/Camera3D` FOV 80, tanpa viewmodel. Warga: hanya landmark interaksi, belum ada model.
- UI: tidak ada `Theme` resource; gaya tersebar lewat `add_theme_*_override` dan `StyleBoxFlat` inline (`build_ui_scenes.gd`, `notification_manager.gd`, `pause_menu.gd`, `settings_menu.gd`, `inventory_slot_ui.gd`) dan `modulate` hijau/kuning di `hud.gd` dan `book_ui.gd`. Warna status mengandalkan modulate, bertentangan dengan UI_UX §2 (warna bukan satu-satunya pembeda).
- `assets/` hanya berisi `audio/CREDITS.md` (audio prosedural). Belum ada `ASSET_LOG.md`.

## 1. Target visual terukur

**Pernyataan:** siluet datar berlapis (depan hijau gelap, tengah hijau-biru, latar gunung ungu-kebiruan pucat), langit gradasi senja, kabut jarak yang memudarkan lapisan jauh ke warna langit, bayangan lembut berwarna (bukan hitam), permukaan kasar tanpa tekstur foto. Terinspirasi, bukan salinan; tidak ada aset atau komposisi Firewatch.

**Palet per waktu hari** (HIPOTESIS awal; P0 memakai satu suasana "Senja", lainnya opsional/P1 dan untuk event):

| Slot | Senja (default P0) | Siang | Pagi berkabut | Malam |
| --- | --- | --- | --- | --- |
| Langit atas | `#5B4A7A` | `#6FA3C8` | `#8FA8B8` | `#1E2440` |
| Langit horizon | `#F2A25C` | `#CFE0D8` | `#E9D7BE` | `#3B3A5C` |
| Cahaya matahari | `#FFB06A` | `#FFF1D6` | `#FFE2B8` | `#6E7FB5` (bulan) |
| Ambient/bayangan | `#3D5558` | `#587068` | `#6A7F85` | `#232C45` |
| Warna kabut | `#C98F7E` | `#C8D5CA` | `#D8CFC0` | `#2C3350` |
| Hijau latar jauh | `#6C7F86` | `#7C9A8C` | `#8DA096` | `#2B3A4A` |

Palet kerja ART_DIRECTION §4 (daun, tanah, genteng, plester) tetap DEFAULT UJI untuk objek dekat; nilai tabel di atas hanya langit, kabut dan cahaya. Ubah hanya dengan catatan dampak.

**Parameter lain (HIPOTESIS, disetel lewat tangkapan layar pengguna):**
- Matahari senja: elevasi 12°–20° di atas horizon, azimut dari barat-barat daya agar teras rumah (sisi selatan, Z+) mendapat cahaya miring hangat. Siang: 55°. Energi 1,0–1,3.
- Kabut: eksponensial, `fog_density` 0,012–0,02 (jarak visibilitas separuh ~40–60 m dari kamera) pada Senja; target rasio: objek pada 80 m (gunung) tercampur ±70–80% ke warna kabut, objek pada 15 m ±10%. `fog_sky_affect` 0,3–0,6 agar horizon menyatu.
- Tonemap Filmic/ACES (nilai 2 sudah ada; periksa mapping enum 4.7.2), exposure 0,9–1,1, glow lembut intensitas ≤0,4 dengan threshold tinggi (hanya matahari/lampu dapur). Tanpa DoF, motion blur, SSAO.
- Bayangan: satu `DirectionalLight3D`, bayangan real-time PSSM 2 split, `directional_shadow_max_distance` 30–40 m, resolusi 2048 (turunkan ke 1024 bila lambat), `shadow_blur` dinaikkan sedikit untuk tepi lembut, `shadow_opacity` < 1 supaya bayangan terwarnai ambient. Bayangan palsu (blob decal/quad) untuk pohon latar.

**Batas renderer Compatibility vs Forward+** (dari pengetahuan dokumentasi Godot 4.x; WAJIB diverifikasi di 4.7.2 oleh VIS-001 karena daftar bergeser antarversi, terutama glow dan lightmap):

| Fitur | Compatibility (renderer sekarang) | Forward+ |
| --- | --- | --- |
| Sky procedural/panorama, fog depth/eksponensial, tonemap, adjustment warna | tersedia | tersedia |
| Glow | tersedia pada 4.3+ (cek 4.7.2), terbatas, terasa mahal di GPU lemah | penuh |
| Bayangan directional + PSSM, MSAA 3D | tersedia | tersedia |
| Volumetric fog, SSAO, SSIL, SSR, SDFGI, DoF berbasis kualitas tinggi, VoxelGI | tidak tersedia | tersedia |
| Cahaya omni/spot | batas jumlah per objek; hindari banyak lampu dinamis | longgar |
| Shader kustom (`spatial`) | tersedia; hindari bergantung pada depth/normal-roughness texture | penuh |
| Efek jarak dekat kabut (kabut tinggi/ground fog) | dipalsukan: quad gradien transparan terbatas atau kabut warna jauh | volumetric |

Konsekuensi: kesan Firewatch dicapai lewat warna, kabut depth, langit, siluet bertingkat dan shader, bukan lewat efek layar. Ambient occlusion dipalsukan dengan vertex color gelap di pangkal objek.

**Opsi pindah renderer (hanya bila pengguna menyetujui setelah ukuran):** Forward+ menambah SSAO, volumetric fog, glow lebih baik, tetapi memerlukan GPU/driver Vulkan yang lebih baru (risiko di laptop lama), memperbesar waktu muat dan memerlukan uji ulang seluruh adegan, material, serta ekspor. Mobile renderer tidak relevan (desktop). Rekomendasi: tetap Compatibility sampai ada bukti ukuran bahwa target visual tidak tercapai; perubahan renderer memerlukan task terpisah dan keputusan pengguna (AGENTS §4: jangan pindah engine/teknologi tanpa keputusan).

## 2. Rencana lingkungan

- **Satu `environment_senja.tres`** (WorldEnvironment) + `light_senja` pada `main.tscn`; preset waktu hari lain berupa resource yang dipertukarkan skrip kecil (jangan membangun siklus hari penuh; ART_DIRECTION §5).
- **Sky:** `ProceduralSkyMaterial` dengan warna §1 (top, horizon, ground), `sun_angle_max` kecil; opsi gradient shader sky bila procedural kurang hangat. Gunung backdrop memakai mesh siluet pada jarak 150–250 m, material unshaded bergradien yang memudar ke warna kabut (berlapis 3 lapisan: ungu pucat → biru → hijau abu).
- **Shader (satu folder `shaders/`, semua `spatial`):**
  1. `toon_lit.gdshader`: pencahayaan 2–3 pita (ramp) dengan ambient berwarna, tepi pita dihaluskan sedikit; mendukung vertex color sebagai warna dasar dan gelap pangkal (AO palsu).
  2. `gradient_height.gdshader`: warna dasar gradien vertikal (pangkal gelap → ujung terang) untuk pohon, rumput dan bangunan; dasar dari "siluet datar".
  3. `foliage_wind.gdshader`: gerak pucuk di vertex shader (`sin(TIME*kecepatan + world_pos.x*fase)` dikali bobot tinggi/vertex color), amplitudo kecil, kekuatan global satu uniform; tanpa tekstur. Tidak boleh menjadi syarat gameplay.
  4. `water_flat.gdshader`: warna dua nada, garis tepi sederhana lewat gradien UV, kilau lembut; tanpa refraksi/screen texture (mahal di Compatibility).
  Prinsip: satu `ShaderMaterial` per kelompok warna dibagi ulang, parameter lewat instance uniform atau materi duplikat sedikit. Bila shader toon gagal dibaca/lambat, cadangan adalah `StandardMaterial3D` (roughness 1, vertex color) tanpa mengubah aset.
- **Rumput/semak:** kartu (quad) bersilang yang dipasang `MultiMeshInstance3D` per area; bayangan nonaktif; jumlah dibatasi (§7). Rumput dekoratif harus berbeda bentuk dari bayam (ART_DIRECTION §3).
- **Siluet bertingkat:** penempatan vegetasi berkelompok dalam 3 bidang (dekat <15 m, tengah 15–60 m, jauh >60 m) dengan skala dan nilai warna berbeda; pagar batas map tertutup vegetasi/ gunung sehingga dinding tak terlihat.
- **Pembangun:** buat `scripts/tools/build_environment.gd` (pola yang sama dengan skrip `build_*` yang ada, headless) dan `scripts/tools/scatter_vegetation.gd` yang menyimpan hasil ke `.tscn` agar deterministik (seed tetap) dan mudah di-diff.

## 3. Katalog aset

Sumber: **CC0** = paket berlisensi CC0 yang dipilih pengguna; **Kode** = dihasilkan generator GDScript/shader. Prioritas: A = diperlukan agar tidak kotak-kotak, B = kualitas, C = hias.

| Kelompok | Kebutuhan | Sumber | Prio |
| --- | --- | --- | --- |
| Pohon | 5–6 bentuk: tropis berdaun lebar, pisang, kelapa, bambu rumpun, jati/akasia, pohon mati/semak besar; tiap 2–3 varian skala/warna | CC0 (low-poly nature pack); cadangan Kode (batang silinder bertaper + kanopi ikosfer berderau-noise, vertex color) | A |
| Semak, rumput, bunga | 3 semak, 2 rumput kartu, 2 bunga/ilalang | Kode (kartu quad) atau CC0 | A |
| Batu | 3 bongkahan + kerikil sungai | CC0 atau Kode (ikosfer didistorsi noise) | B |
| Rumah warga | model panggung, joglo, gubuk; masing-masing satu varian P0, warna atap/dinding berganti lewat material | CC0 kit bangunan bila tersedia (belum ditemukan yang khas Indonesia); sisanya Kode (modular: tiang, dinding, atap pelana/joglo bertumpang, tangga) | A |
| Rumah pemain | ganti graybox dengan modul bergenteng, kusen, teras; collision tetap dari graybox lama | Kode + material bersama | A |
| Pagar bambu | satu set modular (tiang, palang, paling) | Kode (silinder bambu beruas) | A |
| Jembatan, dermaga, perahu | jembatan kayu pendek, perahu sampan | Kode | B |
| Gunung backdrop | 3 lapisan siluet | Kode (heightmap noise ke mesh) | A |
| Sungai | ribbon mesh mengikuti jalur + dasar; tepi batu | Kode (`Path3D` ke mesh) + `water_flat` | A |
| Tanaman bayam | 4 tahap: benih, tunas, tumbuh, siap panen | Kode: ganti perakit primitif di `main.gd` dengan mesh daun bergradien (kartu melengkung, 3–8 daun); siluet dan tinggi tetap (meta tes) | A |
| Jagung, temu kunci | batang+tongkol sebelum/sesudah panen, rumpun daun rendah | Kode | A |
| Alat | cangkul, kantong benih, kantong pupuk, penyiram | CC0 (kit alat/farm) atau Kode | A |
| Viewmodel tangan | lihat §5 | Kode + CC0 opsional | A |
| Perabot dapur | meja, panci, mangkuk, tungku, peti, buku | CC0 (kit perabot) atau Kode | B |
| Makanan | mangkuk sayur bening | Kode | B |
| Dekor | jemuran, pot, drum air, tong, lampu | CC0/Kode | C |

**Sumber CC0 yang dapat diverifikasi dari sesi ini:** situs kenney.nl, quaternius.com, opengameart.org tidak terjangkau. Pemeriksaan GitHub (30 Okt 2026):
- `github.com/KenneyNL/Starter-Kit-FPS`, `Starter-Kit-Basic-Scene`, `Starter-Kit-3D-Platformer`: repositori ada (terlihat lewat API pencarian GitHub dan `raw.githubusercontent.com`). `LICENSE.md` = MIT (kode); README FPS dan Basic-Scene menyatakan "Assets included ... are CC0 licensed". Isi aset (model blok, bukan alam Indonesia) tidak dinilai; cocok hanya sebagai contoh struktur impor Godot, bukan sumber utama.
- Repositori GitHub resmi Quaternius yang sah tidak ditemukan. Ada repositori pihak ketiga (`chibifire-stages/quaternius-stage`, `khhvmc5g6f-eng/prior-mindset-assets`) yang mengklaim memuat paket Quaternius CC0: **BELUM DIVERIFIKASI** (bukan sumber resmi, lisensi tiap berkas tak diperiksa, tidak boleh dipakai tanpa memeriksa halaman paket asli). Direkomendasikan pengguna mengunduh langsung dari situs resmi Kenney/Quaternius di Windows.
- Tidak ada kandidat paket bangunan khas Indonesia yang diverifikasi. Anggap rumah panggung/joglo/gubuk sebagai **Kode**.

## 4. Pipeline aset

```
assets/
  models/<kategori>/<nama_snake>.glb      # pohon/, rumah/, pagar/, alat/, perabot/ ...
  materials/<nama>.tres                    # material bersama (palet)
  shaders/<nama>.gdshader
  textures/ (hanya bila perlu; utamakan vertex color)
  fonts/ , ui/ (ikon, 9-slice kertas), audio/ (sudah ada)
  _incoming/<paket>/                       # paket mentah + LICENSE asli; diabaikan impor
  ASSET_LOG.md
```
- **Penamaan:** `snake_case`, prefiks ID ART_DIRECTION (`env_`, `crop_`, `prop_`, `npc_`, `ui_`), varian `pohon_jati_01.glb`. ID data tidak berubah (AGENTS §8).
- **Impor .glb:** Godot mengimpor otomatis; atur skala 1 unit = 1 m, pivot di dasar, tanpa kamera/lampu di berkas; ekstrak material ke `assets/materials/` lalu ganti dengan material bersama, simpan pengaturan di berkas `.import` yang di-commit. Kolisi dibuat manual (kotak/kapsul sederhana), bukan trimesh otomatis dari mesh dekoratif.
- **Material bersama:** satu material per kelompok palet (daun_tua, daun_muda, kayu, plester, genteng, tanah, bambu, air) memakai shader §2; objek dekoratif mengambil warna dari vertex color agar jumlah material kecil (HIPOTESIS < 25).
- **`assets/ASSET_LOG.md`** (tabel, satu baris per aset atau paket): ID/path proyek · asal (URL halaman paket) · pembuat · lisensi (+ URL teks lisensi) · tanggal perolehan · perubahan (skala, warna, bagian dibuang) · atribusi (wajib/tidak, teks) · distribusi/modifikasi diizinkan · status (Terverifikasi/Belum). `audio/CREDITS.md` ditautkan dari sini. Aset Kode dicatat sebagai "Proyek Internal".
- **Cek lisensi:** sebelum commit, buka halaman asal, simpan salinan teks lisensi dan tangkapan halaman di `_incoming/<paket>/`; hanya CC0/domain publik; tolak CC-BY-NC, "gratis" tanpa lisensi, aset hasil ekstrak game, dan apa pun yang terkait Firewatch. Jangan mengarang lisensi: status "Belum diverifikasi" memblokir penggunaan.
- **Paket diunduh pengguna secara offline:** pengguna mengunduh ZIP resmi, menaruh di `assets/_incoming/<nama_paket>/` (termasuk berkas lisensi), lalu agent memeriksa isi, menyalin hanya model terpilih ke `assets/models/`, mengisi ASSET_LOG. Ukuran repo: hindari menyimpan seluruh paket (tambahkan `_incoming/` ke `.gitignore` bila besar; simpan hanya LICENSE dan daftar berkas). Agent tidak mengunduh dari sesi cloud.

## 5. Karakter

- **Pemain (first person):** tidak ada badan penuh. `Camera3D` mendapat anak `Viewmodel` (node `Node3D`) berisi dua lengan/tangan sederhana (kotak membulat → kapsul, warna kulit/lengan baju) dan alat aktif yang menempel di tangan kanan. Dirender dalam tampilan yang sama (tanpa SubViewport) dengan FOV viewmodel yang sama; cegah menembus dinding dengan menjaga alat dekat kamera (±0,5 m) dan bayangan nonaktif. Animasi prosedural dengan `Tween`/`AnimationPlayer`: sway halus saat jalan (mati bila head bob mati), ayun cangkul, tuang penyiram, tabur; durasi pendek dan tidak mengunci kamera. Sinkron dengan `tool_*` dan `HoldActionController` yang sudah ada; tidak ada aksi yang bergantung pada animasi (ART_DIRECTION: tangan bukan blocker).
- **NPC warga:** model humanoid low-poly beranimasi **idle** dan **jalan** (opsional **bicara/gestur**). Sumber: kit karakter CC0 berskeleton + animasi dasar bila tersedia (belum diverifikasi); cadangan Kode: boneka segmen (badan, kepala, lengan, kaki) dengan animasi `AnimationPlayer` prosedural. Retarget: gunakan skeleton `SkeletonProfileHumanoid` dengan BoneMap saat impor `.glb` agar animasi satu paket dipakai di beberapa model. Varian pakaian lewat parameter warna (uniform shader pada material baju/kerudung/topi), bukan model unik. Batas P0: 1 warga (tetangga), 2 animasi, tanpa lip-sync, tanpa pathfinding rumit (jalur `Path3D`/`Curve3D` sederhana atau diam di teras), tanpa suara bicara.
- **Batas realistis:** karakter terbaik yang dapat dijamin tanpa seniman adalah siluet bersih dengan proporsi wajar (ART_DIRECTION §3 "Warga"), wajah minimal. Hindari klaim kualitas Firewatch untuk karakter.

## 6. UI/UX

- **Satu Theme:** `assets/ui/theme_buku_resep.tres` dipasang pada root setiap `CanvasLayer`/`Control` utama (atau sebagai `project.godot` `gui/theme/custom`). Memuat: warna dari ART_DIRECTION (UI gelap `#24312E`, teks `#F5F0E4`, aksen hangat `#E7B476`), `StyleBox` tombol (normal/hover/pressed/focus/disabled), panel kertas, label, progress bar, ukuran font. Kode yang kini memakai override inline dipindah ke Theme.
- **Font:** satu font tampilan serif/hangat untuk judul buku dan satu sans netral untuk teks UI. Kandidat berlisensi bebas yang umum, **belum diverifikasi lisensinya di sesi ini**: Noto Sans / Noto Serif, Nunito, Lora (umumnya SIL OFL 1.1 di Google Fonts). Wajib memeriksa halaman lisensi tiap berkas, menyimpan teks OFL, dan mencatat di ASSET_LOG; pastikan glyph Indonesia (aksen jarang) lengkap.
- **Gaya buku kertas:** panel buku memakai tekstur kertas hangat (`#E4D6B5`) dibuat Kode (noise lembut) atau StyleBoxFlat bersudut halus dengan bayangan tipis; teks gelap di atas kertas (kontras ≥ 4,5:1, HIPOTESIS untuk dicek alat kontras); ilustrasi bahan kecil berupa ikon vektor sederhana. Tidak ada glassmorphism (ART_DIRECTION §4).
- **HUD:** tetap hanya tracker, crosshair, satu prompt, satu alat aktif, notifikasi (UI_UX §1). Ganti `modulate` hijau/kuning dengan ikon centang/teks tambahan + warna Theme. Prompt dengan kapsul kontras solid dan ikon tombol (E, klik) berbentuk keycap.
- **Keterbacaan:** teks isi 22–26 px pada baseline 1920×1080; uji 1280×720 dan skala 100/125/150% (UI_UX §2); fokus keyboard terlihat; outline/bayangan teks hanya untuk teks di atas dunia 3D; label bukan hanya warna. Opsi skala UI sudah direncanakan di pengaturan; hubungkan ke Theme.
- **Tidak ditambahkan:** hunger/health bar, minimap, currency, crafting menu, jam besar, panel statistik tanah, daftar shortcut permanen, pembelian bahan, telemetri (AGENTS §4, UI_UX §1).
- **Berkas UI yang perlu direfaktor:** `scripts/tools/build_ui_scenes.gd` (style inline reticle/prompt), `scripts/ui/hud.gd` (modulate, tool panel), `scripts/ui/book_ui.gd` (halaman buku, modulate status), `scripts/ui/kitchen_ui.gd`, `scripts/ui/inventory_slot_ui.gd`, `scripts/ui/notification_manager.gd`, `scripts/ui/pause_menu.gd`, `scripts/ui/settings_menu.gd`, `scripts/ui/dialogue_ui.gd`, dan `scenes/ui/*.tscn`. Pertahankan nama node yang dicari `find_child` (mis. `QuestTrackerContainer`, `BayamRow`, `PromptPanel`) karena tes dan skrip bergantung padanya.

## 7. Anggaran performa visual (HIPOTESIS, wajib diukur)

Ukur di Windows pengguna pada GPU/CPU sebenarnya (Godot monitor + FPS overlay; angka draw call/primitif dari Debug > Monitors). Target awal pada 1920×1080:
- 60 FPS stabil di rute inti; tidak turun < 45 FPS di titik terberat.
- Draw call ≲ 800, segitiga terlihat ≲ 400 ribu, material unik ≲ 25, satu lampu directional dengan bayangan; tidak ada lampu dinamis tambahan kecuali dapur (1 omni tanpa bayangan).
- Instans rumput/semak via MultiMesh ≲ 20 ribu kartu, jarak tampak ≲ 40 m; pohon dekat ≲ 150 instans penuh, jauh memakai LOD/billboard.
- Memori tekstur ≲ 256 MB; waktu muat adegan utama ≲ 5 detik (HIPOTESIS).
Bila target meleset, urutan pengurangan: resolusi bayangan, jarak rumput, glow, MSAA, kepadatan pohon. Catat hasil di laporan task; jangan menyatakan angka dari sesi tanpa Godot.

## 8. Task usulan (berurutan)

Tiap task mengikuti siklus AGENTS §5–6 (laporan `completed_tasks`, TASKS, PROJECT_STATUS). Hanya ID di bawah; ID resmi ditetapkan saat masuk TASKS.md.

**ASSET-001 — Kebijakan, log dan pengadaan aset.**
Dependensi: persetujuan rencana ini; pengguna mengunduh paket pilihan (§4).
Hasil: struktur `assets/` + `assets/ASSET_LOG.md` + `.gitignore` untuk `_incoming/`; pemeriksaan lisensi tiap paket (salinan teks lisensi); daftar pilihan model dengan status Terverifikasi/Belum; font terpilih dengan OFL tersimpan.
File: `assets/ASSET_LOG.md`, `assets/audio/CREDITS.md` (tautan), `docs/ART_DIRECTION.md` (§7, §10 diperbarui), `.gitignore`.
Bukti pengguna: pengguna menyediakan ZIP resmi dan menyatakan sumber/tanggal unduh; sesi agent tidak boleh mengklaim sudah melihat situs.

**VIS-001 — Fondasi lingkungan stylized.**
Dependensi: ASSET-001 (struktur dan material palet; model belum wajib).
Hasil: `environment_senja.tres`, pencahayaan/bayangan/kabut/sky, shader `toon_lit`, `gradient_height`, `foliage_wind`, `water_flat`; material bersama; gunung backdrop 3 lapis; sungai; tes headless: skena dimuat tanpa error shader/resource, material dan node yang dicari tes masih ada. Verifikasi daftar fitur Compatibility 4.7.2.
File: `scenes/main.tscn`, `scenes/world/level_graybox.tscn` (atau skena baru), `scripts/tools/build_environment.gd`, `assets/shaders/*`, `assets/materials/*`, `docs/ART_DIRECTION.md`.
Bukti Windows: pengguna menjalankan build/proyek, menilai tangkapan layar tiga sudut (teras, kebun, arah sungai/gunung) dan menyalin FPS; hanya pengguna yang membuat screenshot.

**VIS-002 — Dunia: vegetasi, rumah, pagar, tanaman.**
Dependensi: VIS-001; model CC0 terpilih (ASSET-001) atau generator Kode.
Hasil: pohon beragam, semak/rumput MultiMesh, batu, rumah pemain bergenteng, 3 tipe rumah warga, pagar bambu modular, jembatan/perahu, dan tanaman bayam 4 tahap/jagung/temu kunci yang menggantikan perakit primitif di `main.gd` tanpa mengubah kontrak meta/uji; collision tidak berubah kecuali dengan catatan; tes regresi lulus.
File: `scripts/tools/build_level_graybox.gd` (atau pembangun baru), `scripts/main.gd` (bagian `_build_stage_*`), `assets/models/*`, `scripts/tools/scatter_vegetation.gd`, suite tes terkait.
Bukti Windows: rute inti dijalankan pengguna; FPS pada titik terberat; pemeriksaan bahwa bayam 4 tahap dapat dibedakan dari jarak interaksi.

**VIS-003 — Karakter dan viewmodel.**
Dependensi: VIS-001; VIS-002 untuk teras warga.
Hasil: viewmodel tangan + 4 alat dengan animasi prosedural tak-memblok; 1 NPC beranimasi idle/jalan dengan varian warna; tidak mengubah `player_controller.gd`/`HoldActionController` selain titik pemasangan dan sinyal.
File: `scenes/player/player.tscn`, `scripts/tools/build_player_scene.gd`, `scenes/world/npc_warga.tscn` baru, `scripts/player/` (komponen viewmodel baru), `scripts/social/` (hanya penyambung visual).
Bukti Windows: gerak dan kenyamanan, alat tidak menembus dinding, animasi tidak mengganggu pandangan (hanya pengguna yang dapat menilai).

**VIS-004 (usulan tambahan, bukan dari daftar pengguna) — Theme dan refaktor UI.** Dependensi: ASSET-001 (font). Boleh paralel setelah ASSET-001. Hasil: `theme_buku_resep.tres`, pemindahan override inline (§6), ikon dan panel buku kertas; tes `find_child` tetap lulus. Bukti Windows: uji 1280×720 dan skala 125/150%.

## 9. Risiko

1. Fitur Compatibility berbeda dari ingatan; kabut/glow/bayangan mungkin tak memenuhi target. Mitigasi: verifikasi dini di VIS-001, bukan asumsi.
2. Tanpa seniman, bentuk Kode untuk rumah/NPC bisa tetap tampak "boneka"; model CC0 mungkin tak khas Indonesia. Mitigasi: fokus siluet, warna, kabut; terima asimetri gaya.
3. Lisensi: paket tak resmi/mirror, atribusi terlewat. Mitigasi: hanya dari halaman resmi, ASSET_LOG blok bila Belum.
4. Performa: banyak vegetasi + bayangan di GPU lemah. Mitigasi: anggaran §7, MultiMesh, LOD, opsi kualitas.
5. Regresi tes/kontrak (meta `crop_height`, nama node UI). Mitigasi: jalankan suite penuh, pertahankan nama.
6. Perubahan cakupan (graybox → stylized) menggeser jadwal P0/DEMO-001 yang masih DIKERJAKAN. Mitigasi: VIS dikerjakan setelah DEMO-001 atau di cabang terpisah.
7. Ukuran repo karena aset biner; hindari mengunggah paket penuh.
8. Estetika adalah penilaian subjektif; hanya pengguna yang memvalidasi.

## 10. Pertanyaan terbuka untuk pengguna

1. Apakah Anda mau mengunduh paket Kenney/Quaternius sendiri di Windows (nama paket mana), atau semua aset dibuat dengan generator kode dulu?
2. Suasana default: Senja jingga-ungu saja (disarankan), atau perlu siklus pagi/siang/malam dalam P0?
3. GPU/laptop target Anda (agar anggaran §7 dan keputusan tetap di Compatibility atau pindah ke Forward+ dapat diputuskan)?
4. Apakah visual stylized ini dikerjakan sebelum DEMO-001/DIST-001 ditutup atau sesudahnya?
5. Preferensi font (serif hangat untuk buku vs sans bersih saja) dan apakah Anda ingin tangan pemain terlihat (viewmodel) atau hanya alat melayang?
