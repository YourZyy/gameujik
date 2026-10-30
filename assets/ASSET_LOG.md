# Log Aset, Lisensi dan Atribusi (ASSET-001)

**Versi:** 1.0, 30 Oktober 2026. Rujukan: `AGENTS.md` §10, `docs/ART_DIRECTION.md` §10, `docs/plans/02-visual-aset-karakter-ui.md` §3–§4.

**Jalur aset aktif: generator kode saja** (keputusan default `docs/plans/00-rencana-induk.md` §5 butir 6, disetujui pemilik). Belum ada aset eksternal yang lolos verifikasi lisensi tingkat berkas, sehingga `assets/third_party/` kosong. Jalur ini berubah hanya bila pengguna menaruh paket di `assets/_incoming/` dan seluruh prosedur §4 lolos.

## 1. Kebijakan lisensi

1. Hanya aset berlisensi **CC0 / domain publik**, **CC-BY** (dengan atribusi dipenuhi) atau **MIT/OFL-setara** yang **dapat diverifikasi** dari halaman atau berkas lisensi asli yang dibaca langsung pada hari perolehan.
2. **Dilarang:** aset Firewatch atau game referensi lain (termasuk hasil ekstrak, tiruan tekstur atau salinan "mirip"), CC-BY-NC / CC-BY-ND, "gratis" tanpa lisensi tertulis, paket mirror atau repositori pihak ketiga yang bukan sumber resmi, dan aset yang lisensinya hanya diingat atau diasumsikan.
3. **Lisensi kode tidak otomatis berlaku untuk aset.** Lisensi repositori (mis. MIT) harus dicek apakah menyatakan aset berlisensi sama atau berbeda (mis. CC0). Pernyataan di README tingkat repositori dicatat sebagai klaim pemilik, bukan verifikasi tingkat berkas.
4. Status **BELUM DIVERIFIKASI** memblokir penggunaan: berkas tidak boleh disalin ke `assets/third_party/` atau dirujuk dari adegan/skrip.
5. Placeholder dan graybox harus ditandai; visual akhir tidak boleh diklaim dari placeholder.
6. Font dan audio termasuk dalam log ini. Aset hasil generator kode dicatat sebagai "Proyek Internal".

## 2. Kolom wajib per aset

| Kolom | Isi |
| --- | --- |
| ID/path proyek | Path relatif dari `res://` (mis. `assets/third_party/<paket>/<berkas>`) |
| Asal (URL) | URL halaman paket atau berkas yang benar-benar dibuka |
| Pembuat | Nama pembuat sesuai sumber |
| Lisensi | Nama lisensi dan URL teks lisensi |
| Tanggal perolehan | Tanggal unduh/pemeriksaan (YYYY-MM-DD) |
| SHA-256 berkas | Hash berkas yang masuk repo (`sha256sum`), bukan hash arsip |
| Perubahan | Skala, warna, bagian dibuang, konversi format; "tidak ada" bila murni salinan |
| Atribusi | Wajib/tidak wajib, beserta teks yang harus dicantumkan |
| Distribusi/modifikasi | Diizinkan atau tidak menurut teks lisensi |
| Status verifikasi | `TERVERIFIKASI` (tingkat berkas) / `BELUM DIVERIFIKASI` + alasan |

Baris tidak boleh berisi data tebakan; kolom yang belum diketahui ditulis `BELUM DIVERIFIKASI`, bukan diisi perkiraan.

## 3. Daftar aset yang ada

### 3.1 Aset eksternal (`assets/third_party/`)

| ID/path | Asal | Pembuat | Lisensi | Tanggal | SHA-256 | Perubahan | Atribusi | Distribusi/modifikasi | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| *(kosong: belum ada aset eksternal yang lolos verifikasi)* | | | | | | | | | |

### 3.2 Aset buatan proyek

| ID/path | Asal | Pembuat | Lisensi | Keterangan | Status |
| --- | --- | --- | --- | --- | --- |
| Audio prosedural (11 suara) | `scripts/audio/audio_synthesizer.gd`; daftar rinci di [audio/CREDITS.md](audio/CREDITS.md) | Tim proyek Buku Resep 2045 | Proyek Internal (MIT / hak cipta tim, sesuai CREDITS) | Dihasilkan saat runtime; tidak ada berkas biner | Proyek Internal |
| Bentuk graybox dunia (primitif Godot) | `scripts/tools/build_level_graybox.gd`, `scripts/main.gd` | Tim proyek | Proyek Internal | Placeholder, bukan visual akhir | Proyek Internal |

Saluran drop-in audio CC0 (`assets/audio/*.wav|*.ogg`) tetap diatur oleh [audio/CREDITS.md](audio/CREDITS.md) §2; berkas yang ditambahkan ke sana wajib juga mendapat baris di §3.1.

## 4. Struktur folder, penamaan dan prosedur

```
assets/
  third_party/   # aset eksternal TERVERIFIKASI yang masuk repo (+ salinan LICENSE per paket)
  generated/     # keluaran generator kode yang disimpan (mis. .tres/.tscn/.res)
  _incoming/     # paket mentah unduhan pengguna; BUKAN bagian Git
  audio/         # sudah ada; CREDITS.md
```

- **`_incoming/`:** folder mentah tidak masuk Git. Penambahan ignore di `.gitignore` adalah tugas REPO-001; sampai itu selesai, **jangan menjalankan `git add` pada `_incoming/`** dan jangan membuat berkas lain di sana. Pengguna menaruh ZIP yang sudah diekstrak sebagai `assets/_incoming/<nama_paket_snake_case>/` lengkap dengan berkas lisensi aslinya dan mencatat URL serta tanggal unduh. Folder `_incoming/` tidak dibuat oleh task ini.
- **Penamaan:** `snake_case` untuk folder dan berkas; prefiks sesuai ART_DIRECTION (`env_`, `crop_`, `prop_`, `npc_`, `ui_`); varian bernomor (`pohon_jati_01.glb`). ID data tidak diterjemahkan.
- **Impor `.glb` (BELUM DIVERIFIKASI; dijalankan di editor Godot pada Windows pengguna, belum dicoba di sesi ini):** biarkan Godot mengimpor otomatis; atur skala 1 unit = 1 m, pivot di dasar, tanpa kamera/lampu bawaan berkas; ekstrak material ke `assets/materials/` lalu ganti dengan material bersama; commit berkas `.import` yang dihasilkan; buat collision manual (kotak/kapsul), bukan trimesh otomatis. Cek bahwa model terbuka tanpa galat di editor sebelum dinyatakan lolos.
- **Prosedur memeriksa lisensi sebelum menyalin model:**
  1. Buka halaman paket resmi (atau berkas LICENSE di dalam paket yang diunduh dari sumber resmi); catat URL dan tanggal.
  2. Baca teks lisensi sebenarnya; catat jenisnya. Cek apakah lisensi aset berbeda dari lisensi kode (butir kebijakan 3).
  3. Pastikan lisensi berlaku untuk **berkas yang akan disalin** (bukan hanya repositori/paket), termasuk berkas pihak ketiga di dalam paket (mis. suara dari pembuat lain).
  4. Salin hanya berkas terpilih ke `assets/third_party/<paket>/` bersama salinan LICENSE; hitung `sha256sum`.
  5. Isi baris di §3.1 dengan semua kolom §2; jika ada kolom yang tak dapat diisi dari bukti, status tetap `BELUM DIVERIFIKASI` dan berkas tidak dipakai.
  6. Jangan mengklaim sudah melihat situs yang tidak terjangkau dari sesi; bukti pengguna (ZIP resmi + pernyataan sumber/tanggal) diperlukan untuk situs yang diblokir.

## 5. Kandidat sumber

Pemeriksaan dilakukan 2026-10-30 dari sesi cloud (`curl` lewat proxy). Berkas lisensi/README diunduh hanya ke direktori scratchpad, tidak ke repo. Keterbatasan: `github.com` (halaman HTML) dan `api.github.com` ditolak proxy (HTTP 403), sehingga **daftar berkas dan isi aset tiap repositori tidak dapat diperiksa**; yang terbaca hanya `LICENSE`/`README.md` lewat `raw.githubusercontent.com`. Karena itu lisensi **tingkat berkas** tidak terverifikasi untuk semua kandidat. Situs `kenney.nl`, `quaternius.com` dan `opengameart.org` tidak terjangkau (koneksi gagal).

| Kandidat | URL diperiksa | Teks lisensi yang terbaca | Lisensi aset sama dengan kode? | Status |
| --- | --- | --- | --- | --- |
| Kenney Starter-Kit-FPS | `https://raw.githubusercontent.com/KenneyNL/Starter-Kit-FPS/main/LICENSE.md` dan `README.md` | LICENSE.md: "MIT License, Copyright (c) 2025 Kenney". README: "Assets included in this package (2D sprites, 3D models and sound effects) are CC0 licensed" | Tidak: kode MIT, aset CC0 (klaim README repositori) | Lisensi repositori terbaca; berkas aset **BELUM DIVERIFIKASI**; tidak dipakai |
| Kenney Starter-Kit-Basic-Scene | `.../Starter-Kit-Basic-Scene/main/LICENSE.md`, `README.md` | MIT, Copyright (c) 2025 Kenney. README: aset CC0; menyebut paket "Mini Arena" CC0 | Tidak: kode MIT, aset CC0 (klaim README) | Sama; berkas aset **BELUM DIVERIFIKASI** |
| Kenney Starter-Kit-3D-Platformer | `.../Starter-Kit-3D-Platformer/main/LICENSE.md`, `README.md` | MIT, Copyright (c) 2023 Kenney. README: sprite, model 3D dan efek suara CC0 | Tidak: kode MIT, aset CC0 (klaim README) | Sama; berkas aset **BELUM DIVERIFIKASI** |
| Kenney Starter-Kit-City-Builder | `.../Starter-Kit-City-Builder/main/LICENSE.md`, `README.md` | MIT, Copyright (c) 2025 Kenney. README: sprite dan model 3D CC0 | Tidak: kode MIT, aset CC0 (klaim README) | Sama; berkas aset **BELUM DIVERIFIKASI** |
| Kenney Starter-Kit-Racing | `.../Starter-Kit-Racing/main/LICENSE` (tanpa ekstensi), `README.md` | MIT, Copyright (c) 2023 Kenney. README: model 3D dan suara CC0; satu efek suara "skid" oleh Landeplage, juga dinyatakan CC0 | Tidak: kode MIT, aset CC0 (klaim README), ada kontributor pihak ketiga | Sama; berkas aset **BELUM DIVERIFIKASI** |
| Quaternius (situs resmi `quaternius.com`) | Tidak terjangkau dari sesi | Tidak terbaca | Tidak diketahui | **BELUM DIVERIFIKASI** |
| Repositori GitHub resmi Quaternius | `https://github.com/Quaternius` dan `/quaternius` mengembalikan HTTP 403 (proxy); tidak dapat dikonfirmasi ada atau tidak | Tidak terbaca | Tidak diketahui | **BELUM DIVERIFIKASI** |
| Repo pihak ketiga yang mengklaim memuat Quaternius (`chibifire-stages/quaternius-stage`, `khhvmc5g6f-eng/prior-mindset-assets`, dari catatan rencana 02) | Tidak diperiksa ulang (github.com ditolak proxy) | Tidak terbaca | Tidak diketahui | **BELUM DIVERIFIKASI**; mirror non-resmi, ditolak oleh kebijakan butir 2 |
| OpenGameArt, kenney.nl | Tidak terjangkau | Tidak terbaca | Tidak diketahui | **BELUM DIVERIFIKASI** |

**Catatan hash (tanpa menyalin aset):** SHA-256 berkas yang dibaca, sebagai pembanding bila pengguna ingin memeriksa teks lisensi yang sama.
- Starter-Kit-FPS dan Starter-Kit-City-Builder `LICENSE.md`: `8e99e4045f71bb96d77a1765c815511c63c9f9185bfada2b8917e041ced00754` (identik).
- Starter-Kit-Basic-Scene `LICENSE.md`: `a1b860d3d4348ec91c134645716e4cabc374313e017353420d57b44e49d56874`.
- Starter-Kit-3D-Platformer `LICENSE.md`: `f755bf8f21002f8d5baedaf75564141d363971f3f7bc8c4062956b0b15a6f04f`.
- Starter-Kit-Racing `LICENSE`: `db2c350e96739247706b6b395aae08ac335395eda9cfe2bc80b79636934ecdc2`.

**Kesimpulan kandidat:** tidak ada kandidat yang lolos verifikasi tingkat berkas. Kandidat Kenney hanya menyatakan CC0 untuk aset pada tingkat repositori, isinya (model blok/arena/kendaraan) tidak sesuai dunia Indonesia, dan hanya berguna sebagai contoh struktur impor Godot. Tidak ada aset yang disalin ke `assets/third_party/`. **Jalur aktif tetap generator kode** (rencana 02 §3, kolom "Kode"). Untuk paket dari situs resmi Kenney/Quaternius, pengguna mengunduh ZIP di Windows, menaruhnya di `assets/_incoming/<paket>/`, dan menyatakan sumber serta tanggal unduh; agent kemudian menjalankan prosedur §4.

## 6. Riwayat

- 2026-10-30: ASSET-001 dibuat; kebijakan, struktur folder dan verifikasi kandidat. Belum ada aset eksternal.
