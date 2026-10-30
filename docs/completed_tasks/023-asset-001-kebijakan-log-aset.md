# Kebijakan, Log dan Pengadaan Aset (ASSET-001)

## Identitas

- **ID task:** ASSET-001
- **Judul:** Kebijakan, log dan pengadaan aset
- **Tanggal selesai:** 2026-10-30
- **Agent/pelaksana:** Claude Code (subagent ASSET-001)
- **Tahap produk:** Persiapan visual stylized (rencana 02), dokumentasi dan struktur
- **Status:** Selesai
- **Versi sumber/build:** Working tree lokal di repositori `/home/user/gameujik`, belum di-commit oleh task ini; tidak ada build.

## Tujuan dan pemicu

Rencana 02 §8 menetapkan ASSET-001 sebagai dasar sebelum VIS-001/VIS-002/VIS-004. Pemilik menyetujui jawaban default `docs/plans/00-rencana-induk.md` §5 butir 6: generator kode saja sampai paket CC0 tersedia; pengguna boleh menaruh paket di `assets/_incoming/`. Kebutuhan: kebijakan lisensi tertulis (AGENTS §10, ART_DIRECTION §10), log aset, struktur folder, dan pemeriksaan sumber kandidat tanpa mengunduh paket besar.

## Ruang lingkup

Dikerjakan: `assets/ASSET_LOG.md`, folder `assets/third_party/` dan `assets/generated/` (dengan `.gitkeep`), verifikasi kandidat lewat `curl`. Di luar cakupan: `.gitignore` (REPO-001), `scripts/`, dokumen lain, TASKS, PROJECT_STATUS (diperbarui oleh koordinator), model/gambar/font, dan pengunduhan paket. Folder `assets/_incoming/` sengaja tidak dibuat; petunjuknya ada di ASSET_LOG §4.

## Perubahan dan perilaku akhir

- ASSET_LOG memuat: kebijakan lisensi (CC0/CC-BY/MIT-setara yang dapat diverifikasi; aset Firewatch dan game referensi, mirror non-resmi, NC/ND dan "gratis" tanpa lisensi dilarang; lisensi kode tidak otomatis berlaku untuk aset; klaim README repositori bukan verifikasi tingkat berkas), 10 kolom wajib per aset, tabel eksternal kosong tanpa data palsu, tabel aset proyek (audio prosedural dirujuk ke `audio/CREDITS.md`, graybox ditandai placeholder), struktur folder, penamaan `snake_case`, prosedur impor `.glb` (ditandai belum diverifikasi, dijalankan di editor Windows pengguna), prosedur 6 langkah pemeriksaan lisensi sebelum menyalin model, dan petunjuk `_incoming/`.
- Verifikasi kandidat (2026-10-30): `raw.githubusercontent.com` terjangkau; `github.com` dan `api.github.com` ditolak proxy (403); `kenney.nl`, `quaternius.com`, `opengameart.org` tidak terjangkau. LICENSE dan README lima repositori Kenney terbaca: Starter-Kit-FPS, Basic-Scene, 3D-Platformer, City-Builder, Racing. Semuanya MIT untuk kode (Copyright Kenney) dan README menyatakan aset (sprite, model 3D, suara) CC0; Racing menambah satu efek suara oleh Landeplage, juga dinyatakan CC0. Daftar berkas aset tidak dapat dilihat, jadi lisensi tingkat berkas tidak terverifikasi.
- Keputusan jalur aset: **generator kode saja adalah jalur aktif**; tidak ada aset yang disalin ke `assets/third_party/`.

## File yang ditambahkan atau diubah

| Path | Jenis | Tujuan |
| --- | --- | --- |
| [assets/ASSET_LOG.md](../../assets/ASSET_LOG.md) | Baru | Kebijakan, kolom wajib, log, prosedur, kandidat sumber |
| `assets/third_party/.gitkeep` | Baru | Penjaga folder aset eksternal terverifikasi |
| `assets/generated/.gitkeep` | Baru | Penjaga folder keluaran generator kode |
| [docs/completed_tasks/023-asset-001-kebijakan-log-aset.md](023-asset-001-kebijakan-log-aset.md) | Baru | Laporan ini |

## Verifikasi yang benar-benar dilakukan

| ID | Lingkungan/input | Tindakan | Hasil nyata | Status |
| --- | --- | --- | --- | --- |
| V1 | Sesi cloud, proxy | `curl -I` ke github.com/KenneyNL/<repo> (5 repo) | HTTP 200 pada status awal proxy; `github.com/KenneyNL`, `/Quaternius`, `/quaternius` memberi 403 | Dijalankan; halaman HTML tidak andal |
| V2 | `raw.githubusercontent.com` | Unduh LICENSE/LICENSE.md dan README.md ke scratchpad (bukan repo) | 200 untuk kelima repo; teks MIT dan pernyataan CC0 terbaca; hash SHA-256 dicatat di ASSET_LOG | Lulus |
| V3 | `api.github.com` | Query repo FPS | 403 (akses GitHub tidak diaktifkan sesi) | Gagal; daftar berkas tak terverifikasi |
| V4 | kenney.nl, quaternius.com, opengameart.org | `curl` | Koneksi gagal (000) | Tidak terjangkau |
| V5 | Working tree | `git status --short` | Hanya `assets/ASSET_LOG.md`, `assets/generated/`, `assets/third_party/` (dan laporan ini) baru; `.gitignore` tidak diubah | Lulus |
| V6 | Dokumen | Rujukan skrip di §3.2 dicek ada: `audio_synthesizer.gd`, `main.gd`, `build_level_graybox.gd` | Ketiganya ada | Lulus |

Tidak ada tes engine/otomatis yang relevan; impor `.glb` tidak dijalankan.

## Kriteria selesai

- Kebijakan, kolom wajib, tabel tanpa data palsu, referensi audio: ASSET_LOG §1–§3.
- Struktur folder dan penamaan/impor/prosedur lisensi: ASSET_LOG §4; folder tersedia.
- Verifikasi kandidat dengan teks lisensi aktual, kesamaan lisensi aset/kode, BELUM DIVERIFIKASI untuk yang tak terjangkau: ASSET_LOG §5.
- Tidak ada model/gambar dibuat atau disalin; jalur aktif dinyatakan generator kode.

## Dampak, kompatibilitas dan keterbatasan

Tidak ada dampak pada kode, save atau data. Keterbatasan: lisensi tingkat berkas tidak terverifikasi karena `github.com`/API diblokir; bukti halaman resmi Kenney/Quaternius harus datang dari pengguna di Windows. `.gitignore` belum mengabaikan `_incoming/` sampai REPO-001; ASSET_LOG memperingatkan agar tidak `git add` folder itu. Prosedur impor `.glb` belum dicoba di Godot. Font dengan OFL (hasil ASSET-001 menurut rencana) belum dipilih dan berada di luar cakupan task ini; dicatat sebagai tindak lanjut VIS-004.

## Tindak lanjut dan handoff

- REPO-001: tambahkan `assets/_incoming/` ke `.gitignore`.
- VIS-001/VIS-002: lanjut dengan generator kode; tidak ada dependensi model eksternal.
- VIS-004: pilih font berlisensi OFL, simpan teks lisensi, catat di ASSET_LOG §3.1.
- Jika pengguna menaruh paket di `assets/_incoming/<paket>/`, jalankan prosedur ASSET_LOG §4 dan isi §3.1.

## Penutupan catatan

Laporan ini belum ditautkan dari PROJECT_STATUS dan status TASKS belum diperbarui oleh subagent ini sesuai batas file yang diberikan; koordinator perlu melakukannya.
