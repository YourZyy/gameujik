# Rencana 03 — Goal "3 Resep Warisan", Warga Bergerak, Dialog dan Cerita

**Status:** USULAN untuk ditinjau pengguna. **Tanggal:** 30 Oktober 2026. Dokumen ini tidak mengubah CONTENT/PRD/TASKS; setelah disetujui, angka dan ID di §3 disalin ke [CONTENT](../CONTENT.md) oleh GOAL-001a. Seluruh angka berlabel **DEFAULT UJI**: belum pernah dijalankan; Godot tidak dipakai saat menulis rencana ini.

**Dasar keputusan pengguna (mengungguli dokumen lama):** goal jelas dan dapat dimainkan lama; "Kumpulkan 3 resep warisan"; dunia ~1 km² (chunk streaming dikerjakan rencana lain); warga banyak dan bergerak berjadwal. Resep 1 (Sayur Bening Bayam dan Jagung) **tidak berubah**. Event Karhutla tetap tidak dibangun; area hutan hanya dirancang agar kelak dapat dipakai ([EVENT_DESIGN](../EVENT_DESIGN.md)).

Dampak pada dokumen lama yang harus diperbarui saat disetujui: PRD D19 (satu NPC → banyak), D22 (jumlah resep akhir = 3), CONTENT §10 (penutup P0 menjadi "Tahap 1"), PROTOTYPE (kontrak waktu NPC), UI_UX (halaman buku).

## 1. Struktur goal

**Tujuan utama:** melengkapi buku resep keluarga, yaitu 3 halaman, masing-masing diberi stempel setelah hidangannya dimasak lalu diserahkan kepada warga penerimanya.

**Tujuan antara (per halaman):** (1) halaman ditemukan, (2) bahan terkumpul dari areanya, (3) dimasak di dapur rumah, (4) diserahkan kepada penerima. Tiap langkah sudah ada mekanismenya kecuali (1) dan (4) untuk resep 2–3.

**Indikator progres (tanpa panel statistik baru):** sampul buku menampilkan "Halaman distempel 1/3"; setiap halaman memuat empat baris centang (Ditemukan, Bahan, Dimasak, Diserahkan) yang membaca aturan ketersediaan yang sama dengan tracker; tracker HUD tetap satu resep (D17). Tidak ada persen, bar atau penghitung lain.

**Akhir:** saat stempel ketiga terpasang muncul layar penutup (§7) satu kali; permainan tetap berlanjut (kebun, memasak ulang, bicara dengan warga).

**Tidak mengunci jalan:**
- Urutan bebas; urutan rekomendasi hanya tersirat di petunjuk Bu Tarni (1 → 2 → 3).
- Tidak ada deadline, tidak ada kematian, tidak ada barang buangan. Sumber liar pulih tiap hari (pola `WorldResourceManager` sekarang); istirahat melompati hari.
- Penerima tidur/bergeser: ketuk pintu teras selalu menawarkan "titip hidangan" pada hari berikutnya; hidangan tetap di tas/peti dan tidak kedaluwarsa. Penerima selalu berada di titik temu pasti pada 10.00–14.00 (§4).
- Hidangan salah alamat tidak terkonsumsi: warga lain menjawab "Sepertinya itu bukan buat saya" tanpa efek.
- Hubungan (level 0–2) hanya mengubah dialog/petunjuk, bukan gerbang.

## 2. Rancangan tiga resep

| | Resep 1 (tidak berubah) | Resep 2 (baru) | Resep 3 (baru) |
| --- | --- | --- | --- |
| ID | `recipe_sayur_bening_01` | `recipe_pepes_nila_01` | `recipe_urap_pakis_01` |
| Nama | Sayur Bening Bayam dan Jagung | Pepes Ikan Nila | Urap Pakis Kelapa |
| Bahan | bayam 3, jagung 1, temu kunci 1 | ikan nila 1, daun pisang 2, serai 1 | pakis 3, kelapa 1, cabai rawit 1 |
| Area | Pekarangan sendiri; ujung jalan; tepi bambu | Sungai; pekarangan Bu Sri | Hutan desa; kebun Pak Darmo |
| Persiapan | 4 d | 6 d (DEFAULT UJI) | 5 d (DEFAULT UJI) |
| Memasak (panas Sedang) | 30 d | 40 d (DEFAULT UJI) | 35 d (DEFAULT UJI) |
| Penerima | Bu Tarni | Mbah Wiji | Mas Bayu |

Kelayakan kuliner: pepes ikan dibungkus daun pisang dengan serai dan bumbu adalah masakan Jawa/Sunda yang lazim; urap sayur berkelapa parut berbumbu cabai lazim di Jawa Tengah dan pucuk pakis (pakis sayur) lazim dipakai. Bumbu dasar lain (garam, bawang) dianggap persediaan dapur dan tidak menjadi item. Panas, pembatalan, reservasi, slot hasil tunggal: aturan CONTENT §4 berlaku identik; pengali panas tetap satu tabel bersama.

**Cara memperoleh — keputusan:** semua bahan baru memakai **pola node liar yang sudah ada** (tahan E, 1 panen/hari/node, pulih saat ganti hari), bukan sistem baru:
- **Memancing = titik pancing tetap di sungai** (`resource_ikan_nila_01/02`): tahan E 5 detik, hasil pasti 1 ikan, tanpa joran/umpan/minigame/RNG. Alasan: memberi rasa "area sungai" tanpa sistem besar; deterministik sehingga dapat diuji dan tidak bisa mengunci pemain.
- Foraging: daun pisang (hasil 2), serai, pakis (hasil 3 per rumpun), kelapa, cabai rawit (hasil 1). Menanam serai/cabai ditunda; bayam tetap satu-satunya tanaman (cakupan kebun tidak bertambah).
- Waktu perjalanan ke tiap area 1–2 menit jalan kaki (3 m/s); perkiraan total 45–75 menit sesi pertama, **belum diuji**.
- Tanpa pembelian/barter; warga memberi petunjuk, bukan barang wajib.

Urutan rekomendasi: 1 (dekat, mengajarkan alur) → 2 (sungai, jalan lurus) → 3 (hutan, terjauh). Tidak ada prasyarat teknis; ketiganya dapat dikerjakan paralel (mis. memancing sambil menunggu bayam).

Catatan sains/keamanan: tidak ada klaim keamanan pangan. Teks pakis tidak boleh menyebut ciri identifikasi atau kematangan; teks ilmiah apa pun yang ditambahkan (mis. pakis menyukai tempat lembap teduh) divalidasi dahulu (PRD §14).

## 3. Tabel siap salin ke CONTENT.md

**Item baru** (tumpukan 20, aturan §2/§3 CONTENT berlaku):

| ID | Nama tampil | Kategori | Sumber |
| --- | --- | --- | --- |
| `ingredient_ikan_nila` | Ikan nila | Bahan resep | `resource_ikan_nila_01`, `_02` (sungai), 1 per panen |
| `ingredient_daun_pisang` | Daun pisang | Bahan resep | `resource_daun_pisang_01` (rumpun tepi sungai), 2 per panen |
| `ingredient_serai` | Serai | Bahan resep | `resource_serai_01` (pekarangan Bu Sri), 1 |
| `ingredient_pakis` | Pucuk pakis | Bahan resep | `resource_pakis_01` (hutan desa lembap), 3 |
| `ingredient_kelapa` | Kelapa | Bahan resep | `resource_kelapa_01` (kebun Pak Darmo), 1 |
| `ingredient_cabai_rawit` | Cabai rawit | Bahan resep | `resource_cabai_rawit_01` (kebun Pak Darmo), 1 |
| `dish_pepes_nila` | Pepes Ikan Nila | Hidangan | Dapur, resep 2 |
| `dish_urap_pakis` | Urap Pakis Kelapa | Hidangan | Dapur, resep 3 |

**Resep baru:** `recipe_pepes_nila_01` (stasiun `station_kitchen_home`, output `dish_pepes_nila` ×1, `prep_duration` 6, `cook_duration` 40, `delivery_npc_id` = `npc_mbah_wiji`); `recipe_urap_pakis_01` (output `dish_urap_pakis` ×1, prep 5, cook 35, `delivery_npc_id` = `npc_mas_bayu`); `recipe_sayur_bening_01` mendapat `delivery_npc_id` = `npc_neighbor_01` (ID lama dipertahankan). Catatan resep: `recipe_note_pepes_nila`, `recipe_note_urap_pakis`; teks petunjuk bahan per baris ditulis di data resep (mis. ikan: "Titik pancing di pinggir sungai, dekat batu datar.").

**Area:** `area_rumah`, `area_ujung_jalan`, `area_sungai`, `area_kebun_warga`, `area_hutan`. **Bukan item baru:** stempel halaman (state resep), titip hidangan (aksi dialog).

## 4. Warga

| ID | Nama, peran | Rumah (teras) | Pekerjaan / titik siang | Peran cerita |
| --- | --- | --- | --- | --- |
| `npc_neighbor_01` | Bu Tarni, tetangga | sebelah rumah | pagar & jalan depan | Penerima R1; pemberi lembar halaman |
| `npc_pak_darmo` | Pak Darmo, petani | kebun warga | kebun singkong | Petunjuk kelapa/cabai; satir benih |
| `npc_bu_sri` | Bu Sri, warung kosong | rumah desa | warung (rak ditata, kosong) | Petunjuk serai; satir rak kosong |
| `npc_mbah_wiji` | Mbah Wiji, lansia | dekat sungai | teras, sore ke tepi sungai | **Penerima R2** |
| `npc_pak_joko` | Pak Joko, penjaga pintu air | pos sungai | pintu air & titik pancing | Petunjuk ikan |
| `npc_mas_bayu` | Mas Bayu, penjaga hutan desa | pos hutan | jalur hutan | **Penerima R3** |
| `npc_pak_harjo` | Pak Harjo, petugas desa | balai desa | balai, papan program | Satir lembaga |
| `npc_dik_rini` | Dik Rini, kurir remaja | dekat jalan | keliling desa | Mengarahkan ke warga lain |

Koordinat dunia diisi bersama rencana level/WORLD-004; dokumen ini hanya mendefinisikan ID waypoint (`wp_<npc>_rumah`, `_kerja`, `_temu`, `_istirahat`).

**Jam dalam game:** `jam = 6 + (day_active_time / hari_durasi) × 24` mod 24; 720 d = 24 jam, jadi 1 jam = 30 d; hari mulai 06.00. Tidak ada jam di HUD; isyarat berupa posisi warga dan petunjuk Dik Rini. Pencahayaan sore stabil P0 tidak berubah. **Jadwal DEFAULT UJI** (semua warga kecuali Rini):

| Blok | Aktivitas | Titik |
| --- | --- | --- |
| 06.00–10.00 | bekerja | `_kerja` |
| 10.00–14.00 | **titik temu pasti** (berdiri/duduk, dapat diajak bicara) | `_temu` |
| 14.00–18.00 | bekerja/berjalan | `_kerja` (Mbah Wiji: tepi sungai) |
| 18.00–21.00 | di teras | `_rumah` |
| 21.00–06.00 | tidur (di dalam; ketuk pintu = dialog "sudah tidur", tanpa efek) | `_istirahat` |

Dik Rini: 06–10 jalan `wp_rini_a→b`, 10–14 di `_temu` dekat jalan rumah, 14–20 keliling `c→d`. Batas jalur: tiap perpindahan ≤150 m pada 1,5 m/s (≤100 d = 3,3 jam); Rini ≤400 m pada 2,5 m/s. Lokasi rumah dan kerja satu warga harus dekat. Aturan itu diperiksa tes validasi data (§9).

**Model data (Resource, semua di `data/npcs/`):**
- `NpcData`: `id`, `display_name`, `role`, `home_area`, `walk_speed`, `schedule: NpcSchedule`, `dialogue_id`, `accepts_dish: Array[String]` (ID hidangan), `visual_id`.
- `NpcSchedule`: `blocks: Array[ScheduleBlock]` terurut; `ScheduleBlock{start_hour, activity (work|talk|sit|sleep), waypoint_id, route_id}`.
- `NpcRouteData`: `id`, `points: PackedVector3Array` (poliline antar-waypoint; bukan navmesh; hanya belok pada titik yang ditulis tangan di jalur datar).
- `WaypointData`: `id`, `position: Vector3`, `facing`.

**Posisi = fungsi murni** `NpcSimulation.get_state(npc: NpcData, day: int, hour: float) -> {pos, facing, activity, moving}`: cari blok aktif; bila `hour` masih dalam `jarak_rute / walk_speed` setelah `start_hour`, posisi = panjang-lengkung di poliline rute; selain itu posisi = waypoint blok. Tidak ada state per-frame, tidak ada pencarian jalur, tidak ada fisika, sehingga: (a) deterministik (T "posisi sama untuk day+hour sama"); (b) chunk tak aktif cukup menghitung ini saat dibutuhkan, tanpa node; (c) load save tidak perlu menyimpan koordinat, cukup `day` dan `day_active_time` (sudah disimpan).

**Antarmuka ke chunk streaming (sisi konten):** `NpcDirector` (autoload) menyediakan `get_npcs_for_chunk(chunk_id: Vector2i, day: int, hour: float) -> Array[NpcState]` (memakai fungsi `chunk_of(pos: Vector3) -> Vector2i` milik sistem dunia), sinyal masuk `chunk_activated(chunk_id)` / `chunk_deactivated(chunk_id)`, dan menciptakan/membebaskan node `NpcActor` (reuse scene). Pemetaan chunk ke warga dihitung saat dibutuhkan; warga yang berjalan antar-chunk dimiliki chunk tempat ia berada pada jam itu. `NpcActor` hanya menyetel posisinya ke `get_state` tiap frame fisika dan memutar animasi sederhana; ia **tidak** menyimpan waktunya sendiri.

**Pause/dialog:** NPC tidak punya timer; waktu NPC = `day_active_time`, jadi ia berhenti otomatis pada setiap konteks yang menghentikan simulasi (PROTOTYPE §5: buku, inventaris, dialog, pause, transisi). Karena dialog menjeda jam, warga lawan bicara tidak bisa "pergi di tengah kalimat". Lawan bicara menghadap pemain (`facing` ditimpa sementara). Istirahat melompat ke hari berikutnya dengan layar gelap sehingga tidak ada pop-in. Kolisi NPC tidak menghalangi pemain (hanya area interaksi) agar tidak ada jalan buntu.

**Penyerahan hidangan:** warga yang `accepts_dish` memuat ID hidangan menampilkan "Serahkan [nama] — 1" di dialog; sama dengan `share_dish` sekarang tetapi menerima `dish_id` dan `npc_id`, memotong 1 dari tas/peti atomik, menandai `delivered_to` pada resep, dan memanggil `RecipeManager.mark_delivered(recipe_id, npc_id)` (idempoten, sekali per resep).

## 5. Dialog

**Perluasan `dialogue_manager.gd`:** `get_dialogue_node()` kini `match` 7 konstanta dan `DISH_ID`/`RECIPE_P0_ID` tertanam. Rencana: (1) pindahkan isi ke `DialogueTree` Resource per NPC (`data/dialogue/<npc_id>.tres`): `entry_rules: Array[{condition, node_id}]` (urutan prioritas), `nodes: Array[DialogueNodeData{id, text, choices}]`, `DialogueChoiceData{text, target, condition, actions}`; (2) kondisi: `flag`, `recipe_state(recipe_id, ditemukan|dimasak|diserahkan)`, `has_item(item_id)`, `hour_range`, `relation_min`; (3) aksi: `set_flag`, `reveal_pages`, `deliver_dish`, `unlock_note`, `relation_add`; (4) tujuh node lama menjadi pohon `npc_neighbor_01` dengan ID dan teks yang sama, sehingga tes SOC-001 (T43–T45) tetap lulus sebagai regresi; (5) `dialogue_flags` yang sudah ada menyimpan flag generik; `has_spoken_intro` diganti flag `met_<npc_id>` dengan migrasi dari field lama.

**Pohon ringkas per warga (DEFAULT UJI, ≤5 node):** `sapa` (kenalan, relasi 0→1) → `petunjuk` (1–2 pilihan) → `menunggu` (bila belum ada hidangan) → `terima` (hanya penerima; aksi `deliver_dish`) → `ulang`.

| Warga | Kalimat kunci |
| --- | --- |
| Bu Tarni | (lama) + setelah R1: "Ini lembar yang terselip di buku Ibumu. Ke sungai, ke hutan, terserah mana dulu." (`reveal_pages`) |
| Pak Darmo | "Kelapa jatuh dan cabai yang merah, ambil saja. Benih bersertifikat dari program? Kotaknya masih kosong." |
| Bu Sri | "Serai di belakang, silakan. Rak depan memang rapi, tinggal barangnya." |
| Mbah Wiji | Terima: "Ibumu dulu membungkusnya begini. Duduklah sebentar." |
| Pak Joko | "Pancing saja di batu datar. Pintu air itu tidak pernah selesai diperbaiki, sama seperti janjinya." |
| Mas Bayu | Terima: "Pakis dari hutan sendiri, rasanya memang lain. Hutan ini masih mau diurus." |
| Pak Harjo | "Kawasan Pangan Masa Depan itu program tahap pemeliharaan. Tahap pemeliharaannya sudah lima tahun." |
| Dik Rini | "Mbah Wiji siang di teras, sore ke sungai. Mas Bayu pagi di jalur hutan." |

Relasi: 0 belum kenal, 1 sudah bicara (`sapa` selesai), 2 sudah menerima hidangan (penerima) atau tiga percakapan (lainnya). Level 2 hanya membuka satu baris dialog cerita tambahan; tidak ada hadiah item.

## 6. Lingkungan dan satir ringan (PRD §4)

Papan "Kawasan Pangan Masa Depan — Tahap Pemeliharaan" (sudah ada) dipakai Pak Harjo. Sungai: papan "Sungai Percontohan Bersih" di samping beberapa sampah plastik di tepi (dekorasi, tanpa mekanik bersih-bersih). Hutan: papan "Hutan Produksi Terpadu" dan tunggul tebangan yang sudah lama; Mas Bayu menjaga jalur kecil. Kebun warga: kotak benih bersertifikat yang kosong. Tokoh dan lembaga fiktif, tanpa ceramah; cerita tidak diwajibkan dibaca. Kebutuhan masa depan: area hutan menyisakan tepi yang bisa menjadi koridor event tanpa membangunnya sekarang.

## 7. Buku 3 halaman dan layar penutup

- **Halaman** hanya ada bila ditemukan. Awal: halaman 1 saja, ditambah sampul "Halaman distempel 0/3" dan kalimat nyata "Dua lembar lain terselip di buku ini" (bukan kartu kosong). Setelah `reveal_pages` (dialog pertama Bu Tarni, tidak perlu masak dahulu agar urutan bebas) halaman 2 dan 3 muncul penuh: nama, bahan, petunjuk sumber, catatan, penerima ("Untuk Mbah Wiji, dekat sungai").
- Tiap halaman: baris bahan (angka dari aturan stok bebas yang sama), tombol "Lacak", empat centang, dan stempel setelah diserahkan. Hanya satu resep dilacak.
- UI mengikuti [UI_UX](../UI_UX.md) dan wireframe buku; perlu penyesuaian layout tab/tombol halaman (UI sudah memuat satu halaman).
- **Layar penutup:** overlay modal satu kali (flag `book_completed_shown`) memuat tiga stempel, nama tiga penerima dan satu kalimat dari masing-masing, lalu "Buku ini lengkap. Kebun ini baru dimulai." dan tombol Lanjutkan. Tidak ada skor, bintang atau waktu. Fokus input dikembalikan ke dunia setelah ditutup; input penutup tidak diteruskan ke aksi dunia.

## 8. Masukan untuk SAVE-002

State baru (versi skema save 1 → 2, migrasi dari 1: semua default; wajib ada kebijakan di SAVE-002):
- Per resep: `discovered`, `times_cooked` (sudah ada), `delivered_to` (`""` atau `npc_id`), `stamped`.
- Buku: `pages_revealed`, `book_completed_shown`.
- Per NPC: `met`, `relation_level`, `dialogue_flags`, `dishes_received`; tidak menyimpan posisi (hitung dari `day`+`day_active_time` yang sudah ada di `world`).
- Node liar baru masuk `last_harvested_day` (kunci berdasar `node_id`, sudah generik); `dialogue` lama dimigrasikan ke `npc.npc_neighbor_01`.
- Validasi memuat: `delivered_to` harus ID NPC yang ada dan cocok `delivery_npc_id` resep; ID tidak dikenal ditolak dengan cadangan, bukan dibuang diam-diam.
- Tidak ada "hidangan hilang": jumlah hidangan di tas/peti + `times_cooked` tetap konsisten.

## 9. Rencana tes otomatis

Tambahkan ke suite headless (nama sementara; tidak dijalankan):
1. **Konservasi item:** untuk tiap resep, bahan masuk = bahan keluar + reservasi; panen yang tidak muat tidak mengubah sumber (pola T40).
2. **Idempotensi:** serah ganda/klik berulang mengonsumsi satu hidangan dan satu stempel; muat ulang tidak menggandakan stempel/hidangan.
3. **Urutan non-linear:** 6 permutasi (1-2-3 … 3-2-1) menghasilkan buku lengkap dengan state akhir identik.
4. **Playthrough 3 resep (skrip):** panen bayam, forage semua node, masak tiga resep, serahkan, assert layar penutup sekali.
5. **Jadwal deterministik:** `get_state` dipanggil dengan (day, jam) sama menghasilkan keluaran sama; urutan pemanggilan tidak memengaruhi; posisi kontinu pada batas blok; load-save-load tidak menggeser posisi.
6. **Validasi data NPC:** tiap warga punya tepat satu blok `talk` 10–14; panjang rute ≤ batas; waypoint terdaftar; penerima hidangan berada pada jam 10–14 di titik yang dapat dicapai.
7. **Single-source:** durasi masak/prep di kitchen sama dengan `RecipeData`; durasi tumbuh bayam sama dengan `CropData`; tidak ada konstanta duplikat (tes membaca satu sumber).
8. **Dialog:** tujuh node lama identik; setiap kondisi/aksi data dikenal; hidangan salah penerima tidak mengonsumsi.
9. **Save:** migrasi v1→v2 dan round-trip state NPC/resep; rusak = pemulihan cadangan.
10. **Pause:** NPC tidak bergerak saat `day_active_time` dihentikan.

Tes manual perlu: kenyamanan jarak tempuh, keterbacaan petunjuk, rasa memancing 5 d, tempo 45–75 menit, pop-in NPC saat chunk berganti.

## 10. Daftar task berurutan

| ID | Tujuan | Dependensi | Hasil yang dapat diperiksa | File terdampak |
| --- | --- | --- | --- | --- |
| **GOAL-001a** | Satu sumber data + konten 3 resep | persetujuan pengguna, QA-001 | Tabel §3 masuk CONTENT; `RecipeData` jadi satu-satunya sumber `prep/cook`; `kitchen_manager.gd` (`COOK_DURATION`, `PREP_DURATION`) membaca resep; `CropData` mengganti `BAYAM_*`/`STAGE_*` di `garden_manager.gd`; `ForagingNodeData` menggantikan `NODE_ITEM_MAP/NAMES` di `world_resource_manager.gd`; 8 item baru; tes 1, 7 | `docs/CONTENT.md`, PRD, `recipes_data.gd`, `recipe_data.gd`, `kitchen_manager.gd`, `garden_manager.gd`, `world_resource_manager.gd`, `items_data.gd`, `data/` |
| **GOAL-001b** | Progres resep, penyerahan, buku 3 halaman, penutup | GOAL-001a | `delivered_to`/stempel, `mark_delivered`, UI buku, layar penutup; tes 2–4 (dengan NPC statis sementara) | `recipe_manager.gd`, `book_ui.gd`, `hud.gd`, `dialogue_manager.gd`, scene UI |
| **GOAL-001c** | Dialog berbasis data | GOAL-001a | `DialogueTree`, kondisi/aksi; tujuh node lama lolos regresi; tes 8 | `dialogue_manager.gd`, `dialogue_ui.gd`, `data/dialogue/` |
| **WORLD-004 (sisi NPC)** | Warga bergerak berjadwal di dunia chunk | GOAL-001c, WORLD-004 sisi dunia (chunk, `chunk_of`), koordinat level | `NpcData/Schedule/Route`, `NpcSimulation`, `NpcDirector`, `NpcActor`; 8 warga; tes 5, 6, 10; uji visual pop-in | `data/npcs/`, `scripts/social/`, scene warga |
| **SAVE-002** | Skema save v2 | GOAL-001b, WORLD-004 NPC | Migrasi v1→v2, tes 9 | `save_manager.gd`, tiap `get_save_snapshot` |
| **QA-002** | Penerimaan goal 3 resep | semua di atas | Playthrough otomatis + manual 3 resep lengkap, regresi P0, laporan tempo | `tests/`, `docs/TEST_PLAN.md` |

GOAL-001a/b/c dapat dipisahkan di sesi berbeda; b dan c independen setelah a. Tiap task wajib diarsipkan sesuai AGENTS §6.

## 11. Risiko dan pertanyaan terbuka

**Risiko:** (1) jarak dunia 1 km² membuat tempo terlalu panjang atau sepi; (2) NPC berjadwal menimbulkan frustrasi mencari penerima, dimitigasi titik temu pasti 10–14 dan Rini; (3) pop-in NPC antar-chunk; (4) refactor dialog memecah tes SOC-001; (5) save v2 gagal migrasi; (6) klaim bahan hutan/pakis tanpa validasi; (7) teks satir menjadi ceramah; (8) angka DEFAULT UJI memerlukan balancing.

**Pertanyaan untuk pengguna:**
1. Setuju dua resep baru Pepes Ikan Nila dan Urap Pakis Kelapa, dengan penerima Mbah Wiji dan Mas Bayu?
2. Memancing sebagai titik tetap tanpa minigame cukup, atau ingin sistem lebih kaya (menunda ke P1)?
3. Apakah perlu jam/isyarat waktu sederhana (mis. matahari) agar pemain tahu kapan warga di titik temu, mengingat tanpa HUD baru?
4. Panjang sesi 45–75 menit sesuai harapan, atau lebih panjang?
5. Layar penutup cukup teks statis, atau perlu adegan jamuan 3D kecil (menambah cakupan ART/LEVEL)?
