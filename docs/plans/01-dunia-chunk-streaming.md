# Rencana Teknis 01 — Dunia Luas, Chunk Streaming, dan Terrain Deterministik

**Status:** USULAN BARU, belum dibaca pemilik proyek, belum ada kode. **Tanggal:** 30 Oktober 2026. **Godot:** 4.7.2, GDScript, `gl_compatibility`. Godot tidak terpasang di lingkungan penyusun, jadi **tidak ada klaim hasil uji**; semua angka performa/memori adalah TARGET atau hipotesis (bagian 9). Keputusan pengguna terbaru (dunia ±1 km² dan tumbuh, isi beragam, NPC bergerak, chunk dekat saja) mengungguli LEVEL_DESIGN §2 (amplop 80×80 m) dan PROTOTYPE §2 (tanpa NPC berjalan); dokumen sumber itu harus diperbarui saat WORLD-002 dikerjakan, bukan ditambah catatan kontradiktif.

## 1. Tujuan dan non-tujuan

**Tujuan:** (1) dunia sekitar 1 km² yang dapat diperluas tanpa merusak save; (2) hanya chunk dekat pemain yang ada di RAM/GPU; (3) isi dunia (bukit, sungai, hutan, ladang, permukiman, backdrop gunung) lahir dari rumus deterministik `f(seed, x, z)`, bukan data per-objek yang disimpan; (4) area lama (ID di LEVEL_DESIGN §2 dan `build_level_graybox.gd`) tetap valid dan tidak bergeser; (5) pilar teknis ini dapat diuji tanpa GUI.

**Non-tujuan:** NPC bergerak (hanya antarmuka, bagian 8.5); event Karhutla; rilis/ekspor; air dengan fisika/renang; navmesh dunia; cuaca; penambahan bahan/angka CONTENT baru; mengganti engine, renderer atau physics engine.

## 2. Kondisi saat ini (dibaca dari berkas kerja)

| Fakta | Rujukan |
| --- | --- |
| Seluruh dunia satu scene `LevelGraybox`; tanah satu `StaticBody3D` kotak 80×80 m, tebal 0,2, puncak y=0 | `build_level_graybox.gd:105-107` |
| Empat dinding batas kotak di ±40/−35/+45 | `build_level_graybox.gd:203-215` |
| Landmark (18 ID) dibuat sebagai anak langsung root, koordinat tabel LEVEL_DESIGN | `build_level_graybox.gd:277-456`, `level_graybox.gd:6-25` |
| Batas dunia ditulis keras di tiga tempat: ±42/−37..47 | `level_graybox.gd:100-102`, `save_manager.gd:30-35`, `player_controller.gd` (`load_save_snapshot`, ±42/−37..47) |
| `FallRecoveryArea` 200×2×200 di y=−6; pemain juga pulih bila y < −5 | `build_level_graybox.gd:463-475`, `player_controller.gd:274-276` |
| `main.gd` mencari landmark lewat `level.get_node_or_null(id)` dan memasang sinyal sekali di `_ready` | `main.gd:21-114`, `main.gd:185-241`, `main.gd:497-514` |
| `GardenManager._plots` adalah Dictionary data global, disimulasikan di `_process` tanpa peduli node ada/tidak | `garden_manager.gd:94`, `:547-632` |
| `WorldResourceManager` hanya mengenal dua node foraging lewat `const NODE_ITEM_MAP`; keadaan = `last_harvested_day[id]` | `world_resource_manager.gd:23-26`, `:80-121`, `:311-340` |
| Save: envelope `SCHEMA_VERSION = 1`; versi lain ditolak `VERSION_MISMATCH`; payload 7 seksi wajib | `save_manager.gd:24`, `:243-245`, `:260-264` |
| `InteractionDetector.find_interactable` naik maksimal dua induk dan memiliki daftar nama penolak (`HouseStructure`, `Environment`, `LevelGraybox`, `World`, `Main`); `clear_target()` tersedia | `interaction_detector.gd:72-110`, `:143` |
| Renderer `gl_compatibility`, physics interpolation aktif, belum ada fog, bayangan matahari aktif | `project.godot`, `scenes/main.tscn` |

Kesimpulan: logika permainan (kebun, foraging, dapur) sudah **berbasis data global dengan ID string**, sehingga streaming visual dapat dipasang di atasnya. Hambatan nyata hanya batas keras ±42, dinding kotak, `get_node_or_null` pada landmark, dan penolakan versi save.

## 3. Desain chunk

### 3.1 Ukuran dan grid

**Chunk 28 × 28 m.** Alasan: (a) blok rumah-pekarangan-percabangan lama (X −42..42, Z −37..47) adalah **tepat 3×3 chunk** bila grid digeser: `cx = floor((x+14)/28)`, `cz = floor((z+9)/28)`, sudut barat-laut chunk `(cx·28−14, cz·28−9)`; (b) 28 habis dibagi 1, 2, 4, 7, 14, sehingga LOD 1 m/2 m/4 m berbagi vertex; (c) 29×29 = 841 vertex, 1.568 segitiga per chunk LOD0 — kecil; (d) laju penyeberangan batas pada 3 m/s hanya satu per 9,3 s. Alternatif 32 m memecah blok rumah; 64 m membuat satu chunk LOD0 = 8.192 segitiga.

Dunia awal: `cx, cz ∈ [−18, 18]` = 37×37 = 1.369 chunk ≈ 1,07 km². Rentang disimpan di save (`extent`) sehingga perluasan nanti tidak mengubah dunia save lama.

### 3.2 Jarak, radius, histeresis

Jarak chunk (Chebyshev, untuk membangun lingkaran persegi): `d = max(|cx−pcx|, |cz−pcz|)`. Prioritas antrean dalam satu `d`: `key = (dx²+dz²) − 0,5·dot(arah_pandang_xz, vektor_ke_chunk)` — terkecil dulu.

| Tingkat | `d` | Isi | Chunk |
| --- | --- | --- | --- |
| A Aktif | ≤ 2 | mesh LOD0 (1 m), `HeightMapShape3D`, objek interaktif, collider batang pohon hanya `d ≤ 1`, hunian, NPC fisik | 25 |
| B1 Dekat | 3–4 | mesh LOD1 (2 m), MultiMesh pohon/batu, tanpa collider | 56 |
| B2 Jauh | 5–6 | mesh LOD2 (4 m), pohon versi silang/impostor | 88 |
| Dibuang | > 7 | semua node dibebaskan | — |

`R_muat = 6` (169 chunk), `R_buang = 7`. Histeresis: chunk dimuat bila `d ≤ 6`, baru dibuang bila `d > 7` **dan** sudah di luar sekurang-kurangnya 2 detik; perubahan tingkat A↔B memakai ambang yang sama (naik ke A pada `d ≤ 2`, turun ke B1 hanya pada `d ≥ 4`). Ini mencegah memuat-buang berulang ketika pemain berdiri di sudut chunk. **Pinned:** 9 chunk blok rumah (`cx, cz ∈ [−1,1]`) selalu tingkat A; tidak masuk antrean buang; berisi `LevelGraybox` apa adanya.

Chunk tidak dibuang selama ada `Interactable` difokus/dipakai UI di dalamnya (kunci hitungan referensi).

### 3.3 Anggaran per frame

- Tahap komit (thread utama): (S1) `ArrayMesh`+`MeshInstance3D`, (S2) `HeightMapShape3D`+`StaticBody3D`, (S3) `MultiMesh`, (S4) air/rumah, (S5) `add_child`. **Satu chunk per frame, tahap dijalankan sambil `Time.get_ticks_usec()` ≤ 1.500 µs per frame (TARGET).** Pembuangan: maksimum 1 chunk per frame (`queue_free`, kumpulan MultiMesh dibebaskan sekaligus).
- Beban kebutuhan: `laju = v/S · (2R+1) = 3/28 · 13 ≈ 1,4 chunk/detik`; kapasitas komit 60 chunk/detik pada 60 FPS, jadi ada keleluasaan ±40×.
- Muat game/teleport/pemulihan: **penghalang muat** — blokir kendali dan gravitasi pemain sampai `d ≤ 1` (9 chunk) memiliki collider; sisanya streaming normal. `PlayerController.movement_enabled` sudah ada (`player_controller.gd:14`); tambahkan pemeriksaan `WorldStreamer.is_collision_ready_at(pos)` agar pemain tidak jatuh menembus chunk yang belum dibangun (jatuh = pemicu pemulihan y < −5).

### 3.4 Pemuatan: tiga pilihan, satu dipilih

| Pilihan | Kelebihan | Kekurangan |
| --- | --- | --- |
| (a) `ResourceLoader.load_threaded_request` pada `.tscn`/`.res` per chunk | API bawaan | Perlu 1.369 berkas hasil bake (disk, versi, git), bertentangan dengan tujuan "dirumuskan"; cocok hanya untuk scene karangan tangan |
| (b) Generasi prosedural di thread utama, dibagi per frame | Sederhana, tanpa isu thread | Perhitungan noise 841 titik × beberapa lapisan ikut memakan anggaran frame; sulit menjaga ≤1,5 ms bila sungai/permukiman ditambah |
| (c) **Generasi data murni di `WorkerThreadPool`, komit bertahap di thread utama** | Thread utama hanya membuat resource dari array siap pakai; fungsi generator murni sehingga dapat diuji headless | Perlu disiplin: worker tidak menyentuh `SceneTree`/`RenderingServer`; risiko thread harus diukur |

**Dipilih (c).** Generator mengembalikan `ChunkData` (RefCounted berisi `PackedVector3Array`, `PackedFloat32Array`, `PackedInt32Array`, buffer transform MultiMesh, daftar deskriptor rumah). Mode sinkron (jalankan fungsi yang sama di thread utama dengan tahapan) disediakan untuk uji headless dan sebagai jalan keluar bila pengukuran menunjukkan thread bermasalah di Windows pengguna. (a) hanya dipakai untuk memuat scene karangan tangan (mis. prefab rumah) sekali di awal. Maksimum 3 job worker berjalan bersamaan (TARGET; `OS.get_processor_count()−2`, minimal 1).

## 4. Generasi deterministik

- **Seed:** `world_seed` bilangan bulat **< 2³¹** (aman di JSON/float64 dan di `FastNoiseLite.seed`), disimpan di save. Game baru memakai konstanta default `DEFAULT_WORLD_SEED` (angka dipilih di WORLD-002 dan dicatat; bukan keputusan produk).
- **Hash koordinat:** fungsi sendiri berbasis bilangan bulat 64-bit (gaya splitmix) `hash(seed, cx, cz, salt)`; generator acak kecil buatan sendiri. **Jangan** memakai `hash()` bawaan atau `RandomNumberGenerator` untuk penempatan: kestabilan lintas versi engine tidak dijamin.
- **Medan:** `WorldField.sample_height(x, z)` adalah fungsi murni atas **koordinat dunia**, bukan koordinat lokal chunk, sehingga vertex tepi tetangga identik tanpa jahitan data. Lapisan: bukit (`FastNoiseLite` simplex halus FBM, ~1/180 m), punggungan gunung (ridged, ~1/400 m, mask `smoothstep` jarak-∞ dari rumah 380→480 m, tidak dapat didaki), detail (~1/25 m, amplitudo <0,6 m). Mask rumah: `h = lerp(0, h_noise, smoothstep(0, 40, jarak_luar_persegi_rumah))` — tepat 0 pada tepi blok 3×3 sehingga cocok dengan puncak `Ground` y=0.
- **Presisi:** koordinat ≤ ±600 m: float32 memberi ±0,00006 m, aman. Seluruh perhitungan indeks chunk memakai `int`. Bila dunia tumbuh melewati ±4 km, perlu *origin rebasing* — **dicatat, tidak dikerjakan sekarang**. Rentang tinggi ruang jelajah dijaga −3..+30 m agar ambang pemulihan y<−5 tetap benar; gunung backdrop dapat lebih tinggi namun di luar ruang jelajah.
- **Penempatan pohon/batu:** per chunk, kandidat dari grid terjitter 3,5 m (≈64 kandidat); diterima bila `rand < density(biome)` dan lolos kemiringan, jarak sungai, jarak pad permukiman, dan pengecualian blok rumah. Transform ke `MultiMeshInstance3D` (per jenis × per LOD). ID objek = `kandidat ke-k` dalam chunk (stabil selama `worldgen_version` sama).
- **Permukiman:** wilayah 4×4 chunk; hash menentukan ada/tidaknya dusun (peluang DEFAULT UJI 0,3), pusat, 3–8 rumah dari beberapa prefab kotak; terrain diratakan oleh `WorldField` di sekitar pad (fungsi tinggi menengok maksimal 4 wilayah tetangga, sehingga tetap lokal dan konsisten).
- **Biome:** noise frekuensi rendah → {hutan, ladang, padang, permukiman}; hanya mengatur kerapatan/warna, tidak menambah sumber bahan (itu keputusan CONTENT).

**Disimpan:** seed, `worldgen_version`, `extent`, delta (bagian 7). **Tidak disimpan:** tinggi, mesh, pohon, batu, sungai, rumah, collider, status LOD, apa pun yang dapat dihitung ulang.

**Aturan perubahan formula:** perubahan yang menggeser tata letak wajib menaikkan `WORLDGEN_VERSION`, mempertahankan generator versi sebelumnya atau menulis migrasi delta, dan memperbarui uji hash emas (bagian 10). Hasil `FastNoiseLite` tidak dijamin identik antar versi engine: uji emas mendeteksi hal itu saat versi Godot dinaikkan.

## 5. Terrain, sungai, backdrop

- **Mesh:** satu `ArrayMesh` per chunk, 1 surface, warna vertex (rumput/tanah/pasir tepi sungai) agar tanpa tekstur dan satu material per jenis; normal dihitung dari beda hingga pada medan (bukan dari mesh) sehingga tepi cocok. **Skirt** 1,5 m ke bawah pada keempat sisi LOD1/LOD2 menutup retak antar-LOD.
- **Collision:** `HeightMapShape3D` 29×29 (841 float ≈ 3,4 KB) di `StaticBody3D` layer 1, hanya untuk `d ≤ 2` (≤ 25 bentuk). Dipilih daripada trimesh karena tidak perlu membangun BVH (jauh lebih murah dibuat/dibuang) dan medan tidak memiliki overhang. Pemasangan: pusat body di tengah chunk, spasi 1 m cocok dengan vertex; **orientasi indeks harus diverifikasi di Godot 4.7.2** (uji visual + raycast di WORLD-003). Collider batang pohon: silinder sederhana hanya `d ≤ 1`, TARGET ≤ 400 bentuk total; pohon di luar itu tanpa collider.
- **Sungai:** polilin kontrol (DEFAULT UJI di LEVEL_DESIGN, mis. (−150,−500)→(−110,−200)→(−130,0)→(−170,200)→(−140,500), jarak ≥ 90 m dari blok rumah). Fungsi `river_distance(x,z)` = jarak ke segmen hasil tesselasi 4 m (hanya segmen yang berimpit bbox chunk). Tinggi: `h = lerp(h_medan, dasar, 1 − smoothstep(lebar_air/2, lebar_air/2 + tepi, jarak))`, kedalaman maks **1,2 m (dapat diseberangi)**. Permukaan air: pita (ribbon) per chunk dari polilin pada tinggi `y_air(s)` yang dihitung sekali (medan di garis tengah, dihaluskan, dipaksa tidak naik ke hilir) — **tidak ada simulasi aliran**. Material `StandardMaterial3D` transparan sederhana dengan alfa dari warna vertex (tanpa refraksi layar yang tidak ada di Compatibility). Di air: pengali kecepatan 0,7 (usul, uji rasa) dan footstep berbeda; tidak ada mati/renang.
- **Gunung backdrop:** satu `MeshInstance3D` cincin (≈96 sudut × 24 radius ≈ 2.300 vertex, ~4.600 segitiga) mengikuti pemain dengan pembulatan 64 m, dibangun dari `sample_height` yang sama, **dibangun ulang di worker** hanya saat langkah pembulatan berubah. Material `disable_fog = true`, tanpa pencahayaan, warna vertex bergradasi ke warna horizon langit seiring jarak (gaya lapisan kabut ala Firewatch). Tepi dalam cincin disamakan dengan warna kabut dan diturunkan 2 m untuk mencegah z-fight dengan chunk B2.

## 6. LOD, jarak pandang, kabut, occlusion

- Pohon: dua MultiMesh per jenis (model sederhana, silang/impostor); `visibility_range_end` 70 m untuk model, `visibility_range_begin` 60 m untuk impostor. **Fade dithering mungkin tidak tersedia di Compatibility; verifikasi** dan, bila tidak, pakai tumpang-tindih 10 m tanpa fade.
- **Kabut sebagai penyamar:** `Environment.fog_enabled`, warna = warna horizon langit di `main.tscn`, `fog_end ≈ (R_muat−1)·28 − 5 = 135 m`, `fog_begin ≈ 45 m`. Jarak minimum sisi chunk terjauh ke pemain pada `d=6` adalah `6·28−27 = 141 m`, jadi chunk yang baru dimuat muncul di balik kabut. Dukungan kabut di Compatibility harus diverifikasi visual.
- Bayangan: `directional_shadow_max_distance` ≈ 80 m (TARGET).
- Occlusion: **tidak dipasang awal.** Biaya/manfaat tidak jelas di Compatibility; gunakan frustum culling, kabut, dan radius. Evaluasi hanya bila draw call dusun melebihi TARGET.

## 7. State delta dan integrasi save

### 7.1 Pemilik data (tidak ada duplikasi)

| Data | Pemilik | Disimpan |
| --- | --- | --- |
| Tinggi, pohon, batu, sungai, rumah dusun | formula `WorldField` | tidak |
| Petak/tanaman | `GardenManager._plots` (global, tumbuh walau chunk tak dimuat) | ya, seksi `gardening` (tambah `chunk: [cx,cz]` opsional) |
| Foraging terambil | `WorldResourceManager.last_harvested_day[id]` | ya, seksi `world`; entri dipangkas saat simpan bila `hari_ambil < current_day` (sudah pulih) |
| Objek dihapus (kelak) | `ChunkStateStore.removed[chunk] = [id]` | ya, `worldgen.chunks` jarang |
| NPC (identitas, aktivitas, posisi terakhir) | `NpcRegistry` (WORLD-005) | ya, `worldgen.npc` (dicadangkan) |
| Mesh, collider, MultiMesh, LOD | node chunk | tidak |

Keputusan: **simulasi data tidak bergantung chunk**; tanaman tetap tumbuh saat pemain menjelajah (sesuai PROTOTYPE §3 "Jelajah"). Chunk hanya menyajikan visual. Saat chunk menjadi tingkat A, streamer memancarkan `chunk_activated`; `ChunkVisualSync` meminta ulang `plot_state_changed`/`foraging_state_changed` untuk ID di chunk itu (idempoten). `main.gd:185-241` dan `:497-514` memakai `level.get_node_or_null`; ID yang di luar blok rumah harus dilayani lewat `WorldStreamer.get_node_for_id(id)` (pemasangan sinyal interaksi juga lewat `chunk_activated`, bukan `_ready` sekali).

`WorldResourceManager`: ganti `const NODE_ITEM_MAP` dengan registri `register_foraging_node(id, item_id, nama)`; dua ID lama didaftarkan saat start. Jangan menyiarkan `foraging_state_changed` untuk ribuan ID — hanya yang terdaftar (aktif). ID prosedural: `fx:<jenis>:<cx>:<cz>:<k>`. **Jenis/angka sumber baru adalah keputusan CONTENT; rencana ini hanya menyediakan jalur.**

### 7.2 Skema save v2 dan migrasi dari v1

Tambahan seksi wajib `worldgen`: `{version:1, seed:int, extent:[−18,18,−18,18], chunks:{"cx,cz":{removed:[...]}}, npc:{}}`. `SCHEMA_VERSION = 2`.

| Kebijakan | Isi |
| --- | --- |
| Baca | `read_and_validate_envelope` menerima {1,2}; checksum divalidasi terhadap payload **aslinya** sebelum migrasi |
| Migrasi v1→v2 | fungsi murni `SaveMigrator.migrate()` menambah `worldgen` default (seed default, extent saat ini); seksi lain tidak disentuh; pemain di posisi lama tetap valid karena blok rumah ada di dunia baru |
| Validasi | payload hasil migrasi lulus `validate_save_payload` v2 sebelum `apply_all_states`; gagal = tidak ada keadaan terpasang |
| Tulis | simpan pertama setelah migrasi menyalin berkas v1 ke `<slot>.v1.bak` **sekali** (tidak pernah ditimpa), lalu jalur atomik biasa (.tmp → .bak → target) |
| Pemulihan | primer gagal migrasi → coba `.bak` dengan migrasi yang sama → gagal → pesan "Data simpan tidak cocok…" dan checkpoint lain ditawarkan; berkas v1 tidak dihapus |
| Lebih baru | `schema_version > 2` ditolak dengan pesan "dibuat versi game lebih baru"; tidak ditimpa |
| Seksi `world` | tetap `version:1` (versi seksi ≠ versi envelope; `world_resource_manager.gd:323` tidak berubah) |
| Batas posisi | tiga konstanta keras diganti satu sumber `WorldBounds`; posisi tersimpan di luar `extent` atau di bawah tanah (`y < ground−0,5`) dipulihkan ke `ground+0,05` lewat rumus, atau ke `safe_return_home` bila di zona terlarang |

## 8. Integrasi sistem yang ada

1. **ID stabil:** `LevelGraybox` tetap satu scene, ditempatkan di bawah `WorldRoot/Pinned/` tanpa mengubah nama atau koordinat 18 landmark; `get_landmark()` tidak berubah. `build_level_graybox.gd`: hapus `Ground` 80×80 (ganti 84×84, pusat (0,5), puncak y=0) dan `PerimeterBoundaries`; `FallRecoveryArea` diperbesar atau dibiarkan (cek y pemain sudah ada).
2. **InteractionDetector:** collider medan masuk grup `terrain`; `find_interactable` kembali `null` untuk grup itu (menghindari ketergantungan pada nama induk). Interaktif prosedural memakai struktur sama dengan landmark (node dengan anak `Interactable`, layer 3). Sebelum chunk dibuang, streamer memanggil `detector.clear_target()` bila fokus berada di dalamnya (hindari `on_unfocused` pada objek terbebas). Medan menghalangi sinar (mask 5 menyertakan layer 1) — perilaku "di balik bukit tidak bisa dipakai" sesuai T27.
3. **Recovery:** `LevelGraybox.check_and_recover_entity`, `SaveManager.BOUND_*`, dan `PlayerController.load_save_snapshot` memakai `WorldBounds`; `safe_return_home` (0,0,8) dan `spawn_home` tidak berubah.
4. **Autoload baru `WorldState`** (seed, extent, `ChunkStateStore`; murni data, dapat diuji headless) dan node `WorldStreamer` di `main.tscn`. `SaveManager.capture_all_states/apply_all_states` mendapat seksi `worldgen`.
5. **Antarmuka chunk↔NPC (kontrak untuk WORLD-005):** sinyal `chunk_activated(coord: Vector2i, root: Node3D)` dan `chunk_deactivating(coord, root)`; metode `world_to_chunk(pos)`, `is_chunk_active(coord)`, `get_active_chunks()`, `WorldField.sample_height(x,z)` (agar NPC menempel ke tanah tanpa raycast), `is_collision_ready_at(pos)`. NPC fisik hanya ada di chunk tingkat A; di luar itu posisi NPC dihitung dari rute+waktu (data, tanpa node) dan saat `chunk_deactivating` keadaan ditulis kembali. Tanpa navmesh dunia. `npc_neighbor_01` tetap karangan tangan di blok rumah.

## 9. Anggaran memori dan frame — TARGET, harus diukur

- Memori per chunk: `M = V·28 B + I·2 B + 841·4 B (tinggi, hanya A) + T·64 B + k_node`, `k_node ≈ 6 KB` (hipotesis). LOD0 ≈ 40 KB, LOD1 ≈ 8 KB, LOD2 ≈ 2,5 KB.
- Total: `M_dunia ≈ 25·(40+2,6+6) + 56·(8+1,3+6) + 88·(2,5+0,6+6) ≈ 2,9 MB` + salinan GPU yang sebanding. **TARGET ≤ 15 MB memori statis tambahan** (dengan kelonggaran) dan **drift ≤ +10 %** setelah berjalan 10 km mengitari dunia (uji kebocoran, memakai pola monitor `Performance.MEMORY_STATIC`/`OBJECT_COUNT` seperti `tests/empirical_performance_challenger.gd`).
- Frame: **TARGET** waktu streamer ≤ 1,5 ms/frame di thread utama; generasi worker ≤ 8 ms/chunk; draw call terlihat ≤ 800; jumlah node chunk ≤ 12 per chunk; 60 FPS stabil pada perangkat uji. Angka ini hipotesis; penyesuaian `R_muat`, `fog_end` dan kerapatan dilakukan dari hasil ukur.

## 10. Daftar task berurutan

Urutan: WORLD-002 → WORLD-003 → SAVE-002 → WORLD-004 → (WORLD-005 NPC, agen lain). Semua dependensi awal: QA-001 SELESAI. Setiap task menutup dengan laporan bernomor + pembaruan PROJECT_STATUS/TASKS sesuai AGENTS §6; ID usulan, belum terdaftar di TASKS.

| Task | Dependensi | Hasil yang dapat diperiksa | Berkas dibuat/diubah | Tes otomatis headless |
| --- | --- | --- | --- | --- |
| **WORLD-002** Fondasi deterministik dan perencana | QA-001 | `WorldField`, hash, grid, perencana tanpa node; LEVEL_DESIGN/PROTOTYPE diperbarui | baru: `scripts/world/world_config.gd`, `world_bounds.gd`, `chunk_math.gd`, `seeded_hash.gd`, `world_field.gd`, `chunk_generator.gd`, `chunk_stream_planner.gd`, `tests/suites/test_world_chunks.gd`; ubah `tests/test_runner.gd`, `LEVEL_DESIGN.md`, `PROTOTYPE.md` | `world_to_chunk` ↔ `chunk_origin` bolak-balik di negatif/nol/batas; blok rumah = tepat chunk (−1..1); `sample_height` tepi bersama dua chunk identik; hash emas tinggi di 20 titik + hash `ChunkData`; seed sama dua kali = byte sama; seed beda = beda; tinggi = 0 dan datar di blok rumah; pohon tidak jatuh di blok rumah/air/pad; perencana: radius, histeresis (tanpa osilasi pada 1.000 langkah acak di sudut), pin, urutan prioritas, batas muat/buang per frame, tidak membuang chunk terkunci; invarian ruang jelajah −3..30 m |
| **WORLD-003** Streaming terrain runtime | WORLD-002 | Berjalan di dunia kosong (hanya bukit) dari rumah ke tepi; collision; kabut; tanpa jatuh; metrik ke konsol | baru: `world_streamer.gd`, `chunk_builder.gd`, `chunk_visual_sync.gd`, `world_state.gd`, `chunk_state_store.gd`, `scenes/world/world_streamer.tscn` (via `scripts/tools/build_world_scenes.gd`); ubah `build_level_graybox.gd`, `level_graybox.gd`, `main.tscn`, `main.gd`, `player_controller.gd`, `save_manager.gd` (hanya `WorldBounds`), `interaction_detector.gd`, `project.godot` (autoload), `tests/suites/test_level.gd`, `test_adversarial_level.gd`, `test_player.gd` (menyesuaikan asersi batas ±42 secara sengaja, tidak dihapus) | simulasi streamer mode sinkron memakai posisi skrip 5.000 langkah: jumlah chunk per tingkat sama dengan perencana, tidak ada node yatim, `OBJECT_COUNT` kembali ke dasar setelah kembali ke rumah; `clear_target` dipanggil sebelum buang; `is_collision_ready_at`; `ChunkVisualSync` memancarkan ulang untuk ID uji; 18 landmark ditemukan dengan koordinat sama; seluruh suite lama tetap lulus |
| **SAVE-002** Skema v2 dan migrasi | WORLD-003 | v1 lama termuat; save baru v2; jalur gagal aman | ubah `save_manager.gd`, `world_resource_manager.gd` (registri foraging, pangkas simpan), `garden_manager.gd` (`chunk` opsional); baru `scripts/save/save_migrator.gd`, `tests/suites/test_save_v2.gd` | fixture v1 asli → migrasi → payload sama selain `worldgen`; checksum v1 salah ditolak; v1 korup → `.bak`; `schema_version 99` ditolak tanpa menimpa; `.v1.bak` dibuat sekali dan tidak ditimpa; bulat-pergi-balik v2; posisi di bawah tanah dipulihkan; pangkas foraging; idempotensi muat berulang; tes T46/T47/T49 lama tetap lulus |
| **WORLD-004** Isi dunia dan LOD | SAVE-002 | sungai, hutan, ladang, dusun, backdrop, LOD, profil performa | baru: `river_field.gd`, `settlement_field.gd`, `backdrop_ring.gd`, `scripts/tools/world_probe.gd` (rute uji + metrik); ubah `world_field.gd`, `chunk_generator.gd`, `chunk_builder.gd`, `LEVEL_DESIGN.md`, `ART_DIRECTION.md` bila perlu | `river_distance` kontinu; dasar ≥ −1,2 m dari permukaan; air tidak naik ke hilir; dusun tidak tumpang tindih dan ratakan pad; jumlah pohon per chunk ≤ batas; hash emas diperbarui bersama `WORLDGEN_VERSION`; batas memori `M_dunia` dihitung dari `ChunkData` ≤ TARGET |
| WORLD-005 NPC bergerak (agen lain) | WORLD-003, SAVE-002 | memakai kontrak 8.5 | di luar dokumen ini | — |

Gerak, kamera, rasa air, keterbacaan, dan frame time **tidak** dapat dibuktikan tanpa GUI; task tersebut tetap DIKERJAKAN sampai uji manual desktop dilakukan (DEMO-001 saat ini masih menunjukkan input desktop eksternal tidak diterima — ini juga menghalangi bukti WORLD-003/004).

## 11. Risiko dan cara ukur di Windows pengguna

| Risiko | Cara ukur / mitigasi |
| --- | --- |
| Thread worker menimbulkan masalah di Compatibility/Windows | bandingkan mode sinkron vs worker; jadikan sinkron bila tersendat |
| Hitch saat komit mesh/collider | `Time.get_ticks_usec()` per tahap, catat p95/p99 ke konsol; turunkan ukuran tahap |
| Draw call tinggi (Compatibility tanpa penggabungan) | `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_PRIMITIVES_IN_FRAME`, `TIME_FPS`; kurangi jenis/surface per chunk |
| Beban bayangan | bandingkan FPS bayangan on/off dan `shadow_max_distance` |
| Kebocoran saat streaming | berjalan mengitari dunia (rute spiral) dan kembali ke rumah; `OBJECT_COUNT`, `OBJECT_NODE_COUNT`, `MEMORY_STATIC` sebelum/sesudah; pola sama dengan harness empiris yang ada; jangan campur dengan 5.026 ObjectDB yang dilaporkan saat keluar (belum dianalisis) |
| Orientasi `HeightMapShape3D`/retak antar-LOD | raycast jatuh ke grid 1 m dan bandingkan dengan `sample_height`; uji visual tepi chunk |
| Perubahan hasil noise antar versi engine | uji hash emas; nomor versi dikunci |
| Perluasan dunia mengubah punggungan gunung | `extent` disimpan di save; punggungan dihitung dari `extent`; perluasan = naikkan `WORLDGEN_VERSION` |
| Penyimpanan ID prosedural bila generator berubah | kebijakan 4 (versi generator) + uji emas |

Rute uji (DEFAULT UJI): (1) rute P0 rumah→jagung→temu kunci→rumah; (2) rumah→sungai→tepi barat; (3) spiral 10 km; (4) bolak-balik di sudut chunk 2 menit; (5) muat save di titik jauh. Catat tanggal, CPU/GPU, versi Godot, build, resolusi; hasil tidak digeneralisasi ke perangkat lain.

## 12. Pertanyaan terbuka (butuh keputusan pengguna)

1. **Dunia 1 km² persegi dengan tepi gunung tak dapat didaki** (usulan), atau tepi lain (laut/sungai besar)? Memengaruhi backdrop dan LEVEL_DESIGN.
2. **Spesifikasi perangkat minimum** (CPU/GPU/RAM) untuk menetapkan `R_muat` dan target FPS — default 60 FPS pada perangkat Windows pengguna.
3. **Apakah sungai boleh menjadi sumber air** (menggantikan atau melengkapi `water_home`)? Rencana ini hanya membuat sungai dapat diseberangi, bukan sumber.
4. **Apakah sumber foraging prosedural di luar dua ID lama diizinkan** (jenis, bahan, kerapatan) atau dunia luas sementara hanya dekorasi sampai CONTENT diperbarui?
5. **Persetujuan mengubah LEVEL_DESIGN §2 dan PROTOTYPE §2** (amplop 80×80 m dan "tanpa NPC berjalan") agar sejalan dengan keputusan terbaru.
