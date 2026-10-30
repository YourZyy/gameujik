# Arah Visual, Audio dan Produksi Aset

**Versi:** 0.3 · **Tanggal:** 30 Oktober 2026  
**Keputusan utama:** stylized sederhana, referensi artistik Firewatch, kampung fiktif Indonesia; pada P0.5 memakai aset CC0 terverifikasi dan generator kode (PRD D28).  
**Rujukan:** [PRD](../PRD.md), [Level](LEVEL_DESIGN.md), [UI/UX](UI_UX.md), [Event](EVENT_DESIGN.md), [Konten dan anggaran](CONTENT.md).

## 1. Pernyataan visual

Dunia terasa membumi, hangat dan layak dijelajahi, meskipun hidup sedang sulit. Bentuk disederhanakan, siluet jelas, warna terarah dan pencahayaan memberi suasana. Detail dipusatkan pada benda yang sering dilihat dekat: buku, makanan, tanaman yang dirawat, alat, pintu dan dapur.

Firewatch adalah referensi pendekatan bentuk, komposisi dan suasana cahaya. Identitas objek, wilayah, warna lokal, cerita dan aset tetap milik proyek ini. Jangan menyalin peta, model, logo, lukisan atau UI game referensi. Low-poly tidak harus terlihat seperti mainan, serba kotak atau berproporsi chibi.

## 2. Karakter dunia Indonesia

Gunakan rumah sederhana dengan genteng, teras, dinding plester, pagar bambu/kayu, meja dapur, wadah air dan peralatan yang masuk akal. Kesan lokal datang dari hubungan benda dan kebiasaan, bukan menempel banyak bendera atau tulisan stereotip.

Proporsi pintu, meja, panci dan tanaman nyaman dilihat dari first person. Kerusakan berupa tambalan, cat terkikis, pagar miring dan bekas penggunaan; tidak seluruh lingkungan ditutupi noda yang sama. Makanan tetap menarik dan dapat dikenali. Tidak perlu futurisme neon hanya karena latar 2045.

## 3. Bentuk, material dan tingkat detail

| Kelompok | Arahan bentuk | Detail prioritas | Hindari |
| --- | --- | --- | --- |
| Rumah | Volume sederhana, atap dan teras jelas | Pintu, kusen, meja dan bagian yang disentuh | Interior luas yang tidak dipakai |
| Tanaman kebun | Siluet tiap tahap berbeda | Bayam, jagung dan temu kunci harus berbeda | Rumput dekorasi sama bentuk dengan item wajib |
| Vegetasi latar | Kelompok massa dan variasi tinggi | Menuntun pandangan/menutup batas | Ribuan helai bergerak dengan bayangan individual |
| Alat | Bentuk fungsional dan mudah dibaca | Ujung alat, gagang, kontak dengan petak | Animasi tangan kompleks sebagai prasyarat loop |
| Makanan | Warna bahan dan bentuk hidangan | Panci, jagung, daun, mangkuk | Mesh sangat detail yang hanya terlihat sesaat |
| Warga | Proporsi manusia sederhana, pakaian sehari-hari; P0.5: animasi idle dan jalan, varian pakaian lewat parameter warna | Gestur tenang dan ekspresi dasar | Karakter fotorealistis yang bertabrakan dengan lingkungan; model unik per warga |
| Papan/catatan | Tulisan terbaca, komposisi sederhana | Petunjuk narasi yang dipakai | Teks dekorasi kecil yang harus dibaca untuk progres |

Pilih material terbatas yang dapat dipakai ulang. Tekstur menunjukkan kayu, tanah dan plester tanpa meniru detail foto pada seluruh permukaan. Tanaman dan bangunan tidak harus memiliki material unik per benda. Bekas pakai boleh melalui variasi warna atau decal selektif.

P0.5 menambah satu set shader `spatial` sederhana yang dibagi ulang, tanpa tekstur foto dan tanpa bergantung pada depth atau normal texture layar: `toon_lit` (2–3 pita cahaya dengan ambient berwarna dan warna vertex), `gradient_height` (gradien vertikal pangkal gelap ke ujung terang, siluet datar berlapis), `foliage_wind` (gerak pucuk kecil di vertex shader, tidak boleh menjadi syarat gameplay) dan `water_flat` (dua nada dengan garis tepi, tanpa refraksi layar). Bila shader gagal atau lambat, cadangannya `StandardMaterial3D` dengan roughness penuh dan warna vertex. Ambient occlusion dipalsukan dengan warna vertex gelap di pangkal objek.

## 4. Palet kerja DEFAULT UJI

Warna berikut panduan awal, bukan larangan memakai warna lain. Uji di pencahayaan actual; warna swatch tidak menjamin keterbacaan.

| Fungsi | Warna contoh | Peran |
| --- | --- | --- |
| Daun utama | `#58704E` | Massa hijau alami |
| Daun muda | `#91A86C` | Menonjolkan pertumbuhan tanpa neon |
| Tanah | `#795540` | Kehangatan dan kontras tanaman |
| Genteng | `#AB6748` | Landmark rumah |
| Plester/kertas | `#E4D6B5` | Dinding, buku dan permukaan terang |
| Bayangan | `#3D5558` | Kedalaman yang tetap berwarna |
| Langit sore | `#C8D5CA` | Latar terang lembut |
| Cahaya hangat | `#E7B476` | Arah matahari dan dapur |
| UI gelap | `#24312E` | Latar teks yang stabil |
| UI teks | `#F5F0E4` | Kontras teks utama |
| Event api | `#E78B45` | Aksen zona aktif, bukan seluruh layar oranye |
| Event arang | `#484642` | Jejak terbakar lokal, tidak menyelimuti seluruh map |

Suasana **Senja** (default P0 dan P0.5) untuk langit, cahaya dan kabut, DEFAULT UJI dan dinilai pemilik lewat tangkapan layar yang dibuat pemilik:

| Slot | Senja |
| --- | --- |
| Langit atas | `#5B4A7A` |
| Langit horizon | `#F2A25C` |
| Cahaya matahari | `#FFB06A` |
| Ambient/bayangan | `#3D5558` |
| Warna kabut | `#C98F7E` |
| Hijau latar jauh (gunung) | `#6C7F86` |

Palet kerja di atas tetap untuk objek dekat; tabel Senja hanya langit, kabut dan cahaya. Preset siang, pagi dan malam tidak dibuat pada P0.5 (siklus waktu bukan cakupan); bila kelak diperlukan untuk event, ia berupa resource yang dipertukarkan, bukan siklus hari penuh. Siluet bertingkat dengan tiga bidang (dekat, tengah, jauh) berbeda skala dan nilai warna: hijau gelap di depan, hijau kebiruan di tengah, ungu kebiruan pucat di latar.

UI mengambil warna yang selaras dengan dunia tetapi memprioritaskan kontras. Satu Theme UI tunggal (VIS-004) menyatukan warna, StyleBox dan font; font dan lisensinya dicatat di manifes. Efek glassmorphism dekoratif bukan tujuan UI game; blur/transparansi tidak boleh mengganggu pembacaan.

## 5. Cahaya, atmosfer dan kamera

P0 dan P0.5 memakai satu suasana sore (Senja) yang stabil untuk menilai bentuk dan warna. Gunakan arah cahaya yang menonjolkan teras serta jalur pulang. Rumah hangat tanpa harus menerangi semua ruangan dengan banyak lampu real-time. Bayangan selektif dan ambient cukup agar objek interaksi tidak hilang dalam gelap.

Nilai awal atmosfer berikut HIPOTESIS/DEFAULT UJI dan disetel lewat tangkapan layar pemilik pada VIS-001 (angka anggaran dan jarak chunk ada di CONTENT bagian 19–20): matahari rendah dari barat-barat daya agar teras selatan terkena cahaya miring hangat (elevasi sekitar 12°–20°, energi sekitar 1,0–1,3); tonemap filmic atau ACES dengan eksposur sekitar 0,9–1,1; glow lembut berintensitas rendah dengan ambang tinggi, hanya untuk matahari dan lampu dapur; tanpa depth of field, motion blur atau SSAO; satu cahaya directional dengan bayangan lembut berwarna (bukan hitam) dan bayangan palsu sederhana untuk pohon latar.

Kabut jarak **wajib pada P0.5**: ia menyamarkan batas muat chunk dan memudarkan lapisan jauh ke warna kabut Senja; jenis dan nilai ditetapkan VIS-001 setelah dukungan renderer diperiksa (CONTENT bagian 19). Renderer tetap `gl_compatibility`; fitur yang tidak ada di renderer itu (volumetric fog, SSAO, SSR, SDFGI) tidak dijadikan syarat. Pindah ke Forward+ hanya dengan keputusan pemilik setelah pengukuran, sebagai task tersendiri. Hindari menjadikan volumetric, bloom, depth of field dan motion blur sebagai syarat grafis menarik. Kamera stabil, head bob mati default. Jangan memakai shake pada pickup, siram atau panen rutin.

Perubahan waktu visual penuh bukan kebutuhan P0 maupun P0.5. Hari simulasi sumber bahan dan jadwal warga berjalan tanpa animasi matahari malam; isyarat waktu memakai posisi warga, bukan jam HUD. Saat event kebakaran diperkenalkan, perubahan langit/asap harus tetap memungkinkan membaca landmark dan batas zona.

## 6. Tahap mutu dan batas produksi

| Tahap | Mutu yang diperlukan | Belum diperlukan |
| --- | --- | --- |
| Graybox | Skala, collision, warna pembeda, prompt dan rute benar | Tekstur final, tangan lengkap, detail dekorasi |
| P0 gameplay | Bahan dapat dikenali, perubahan tanaman/petak terlihat, dapur terbaca | Seluruh map setara screenshot promosi |
| P0 distribusi | Aset sementara berlisensi, visual/audio tidak rusak | Trailer atau brand final |
| P0.5 | Siluet bertingkat, kabut jarak, material bersama dan vegetasi/rumah/pagar yang tidak kotak; sumber wajib tetap terbaca; setiap aset punya entri manifes lisensi | Mutu akhir semua area, animasi karakter lengkap, musik |
| P1 | Satu area dan event representatif terhadap arah akhir | Semua variasi resep/daerah sekaligus |

Anggaran P0 (riwayat): satu rumah utama, satu teras warga, satu set pagar modular, satu set vegetasi terbatas, satu petak empat tahap bayam, satu sumber jagung, satu temu kunci, empat alat dan satu hidangan. Pada P0.5 anggaran dinyatakan per chunk dan per adegan (draw call, segitiga, material, node per chunk, MultiMesh, memori) dalam **satu tabel di [CONTENT](CONTENT.md) bagian 20**; dokumen ini tidak menyalinnya. Jumlah variasi aset tidak ditambah sebelum performa rute standar diukur; bila anggaran meleset, urutan pengurangan ada di tabel itu.

Untuk objek di dekat kamera, periksa siluet dan shading dari jarak interaksi; untuk latar, prioritaskan massa dan orientasi. Jangan menetapkan jumlah polygon sebagai jaminan performa. Ukur biaya adegan, bayangan, transparansi, material dan efek pada renderer/perangkat nyata.

## 7. Daftar aset P0 dan status

Keadaan nyata sejak ART-001 ([laporan 017](completed_tasks/017-identitas-visual-audio-dasar-konsisten.md), 29 Oktober 2026): lingkungan adalah **placeholder graybox prosedural** buatan kode proyek (atap genteng, kusen, teras, pagar bambu, bayam empat tahap dari primitif, jagung dan temu kunci dengan siluet terpisah, material tanah bertahap) ditambah audio prosedural; belum ada model atau aset visual eksternal (`assets/` hanya memuat log audio), belum ada model tangan, model warga atau ikon final. Wireframe SVG adalah gambar rancangan, bukan aset runtime. Tabel di bawah adalah kebutuhan P0 dan tetap berlaku sebagai kontrak siluet; ia tidak menyatakan aset sudah final.

| ID aset rencana | Kebutuhan | Versi awal yang cukup |
| --- | --- | --- |
| `env_home` | Rumah, pintu dan teras | Geometri sederhana dengan collision |
| `env_kitchen` | Meja, panci, titik hasil | Mesh terpisah pada interaksi |
| `env_storage` | Peti penyimpanan | Bentuk kotak, tutup dan penanda |
| `env_water` | Sumber isi ulang | Wadah mudah dikenali |
| `env_plot` | Petak awal/gembur/siap | Variasi bentuk/warna tanah |
| `crop_bayam_stages` | Empat tahap | Siluet dan tinggi berbeda |
| `resource_jagung` | Sebelum/sesudah panen | Tongkol terlihat dan hilang setelah panen |
| `resource_temu_kunci` | Sumber bumbu | Daun rendah, collider mudah dibidik |
| `prop_tools` | Empat alat | Bentuk placeholder konsisten |
| `prop_book` | Buku keluarga | Sampul dan posisi di meja |
| `prop_seed_care` | Paket awal/cadangan | Wadah dan label singkat |
| `food_sayur_bening` | Satu hidangan | Mangkuk/panci dengan isi terbaca |
| `npc_neighbor` | Satu warga | Placeholder berproporsi masuk akal |
| `ui_icons` | Alat, centang, item dan kursor | Bentuk sederhana disertai label |
| `audio_core` | Ambience dan feedback | Rekaman/sintesis yang lisensinya jelas |

Model tangan bukan blocker. Aksi boleh memakai alat sederhana di layar dan perubahan objek sebelum animasi tangan final tersedia.

### 7.1 Katalog aset P0.5 (rencana)

Sumber: **CC0** (paket yang dipilih dan diverifikasi pemilik atau task ASSET-001) atau **Kode** (generator GDScript/shader proyek). Prioritas: A diperlukan agar tidak kotak-kotak, B kualitas, C hias. Tidak ada aset di tabel ini yang sudah ada; bangunan khas Indonesia dianggap Kode karena belum ada paket CC0 yang diverifikasi.

| Kelompok | Kebutuhan | Sumber | Prio |
| --- | --- | --- | --- |
| Pohon | Beberapa bentuk (tropis berdaun lebar, pisang, kelapa, bambu rumpun, jati/akasia, pohon mati) dengan varian skala/warna | CC0, cadangan Kode | A |
| Semak, rumput, bunga | Beberapa semak, rumput kartu, ilalang | Kode atau CC0 | A |
| Batu | Bongkahan dan kerikil sungai | CC0 atau Kode | B |
| Rumah warga | Tipe panggung, joglo, gubuk; warna atap/dinding lewat material | Kode (modular) | A |
| Rumah pemain | Modul bergenteng, kusen, teras; collision lama tetap | Kode | A |
| Pagar bambu | Set modular (tiang, palang, paling) | Kode | A |
| Jembatan, dermaga, perahu | Jembatan kayu pendek, sampan | Kode | B |
| Gunung latar | Tiga lapisan siluet berwarna kabut | Kode | A |
| Sungai | Pita air mengikuti jalur, tepi batu | Kode + `water_flat` | A |
| Tanaman | Bayam empat tahap, jagung, temu kunci dengan siluet dan tinggi yang kontrak ART-001 tetap | Kode | A |
| Alat, perabot, makanan | Empat alat, perabot dapur, mangkuk hidangan | CC0 atau Kode | A/B |
| Tangan pemain (viewmodel) | Dua tangan sederhana dan alat aktif; animasi prosedural pendek, bukan blocker | Kode | A |
| Warga | Humanoid sederhana animasi idle dan jalan; varian warna | CC0 berskeleton bila terverifikasi, cadangan Kode | A |
| Dekor | Jemuran, pot, drum air, tong, lampu | CC0 atau Kode | C |

## 8. Audio

Ambience kampung, angin tipis, bambu, langkah dan kegiatan dapur memberi tempat terasa hidup. Musik tidak harus terus berjalan. Pickup, tanam, gemburkan, pupuk, siram, panen, tombol buku dan hasil masak mendapat feedback singkat yang berbeda.

Volume master/musik/efek dapat diubah. Informasi penting tetap punya teks. NPC tidak membutuhkan voice-over P0. Jangan memakai suara notifikasi keras untuk interaksi yang diulang. Event kebakaran boleh memakai bunyi api dan lingkungan yang berubah, tetapi tidak menghilangkan kemampuan membaca instruksi.

## 9. Identitas event tematik

Format publik: **Nama Game: Nama Event**. Contoh kerja: **Buku Resep 2045: Karhutla**. Buku Resep 2045 masih nama kerja; Karhutla adalah judul event. Tidak ada label chapter atau nomor episode wajib.

Map dasar mempertahankan siluet rumah, rute dan identitas kampung. Event menambah variasi lokal pada vegetasi, asap, api, arang, suara, sumber air dan beberapa objek cerita. Jangan membuat setiap event memerlukan seluruh aset dunia baru. Api harus benar-benar terlihat serta memengaruhi akses/state, bukan sekadar filter warna.

Efek kebakaran dimulai dari bentuk api stylized terbatas, partikel selektif dan perubahan material lokal. Tidak perlu simulasi asap fluida atau semua objek mudah terbakar. Batasi efek transparan berlapis dan cahaya api dinamis; ukur saat banyak titik api aktif. Efek harus memiliki status teks, batas area dan kontrol yang jelas.

## 10. Lisensi dan kriteria penerimaan

Sebelum aset eksternal masuk, catat: ID/path proyek, sumber URL atau pembuat, jenis lisensi, tanggal perolehan, perubahan, kewajiban atribusi dan apakah distribusi/modifikasi diperbolehkan. Jangan menyalin aset internet berdasarkan kemiripan saja. Font/audio termasuk dalam pencatatan, bukan pengecualian.

Aturan P0.5 (D28): (1) hanya dua sumber yang sah, yaitu aset CC0 yang halaman resmi dan teks lisensinya sudah diperiksa, dan keluaran generator kode proyek (dicatat sebagai proyek internal); (2) semuanya masuk satu manifes lisensi (`assets/ASSET_LOG.md`; nama dan lokasi final ditetapkan ASSET-001) dengan kolom sumber, pembuat, lisensi, tanggal perolehan, hash, perubahan dan kewajiban atribusi, dan berkas tanpa entri tidak boleh ada; (3) status "belum diverifikasi" memblokir pemakaian; (4) tidak boleh mencampur aset CC-BY atau lisensi lain kecuali atribusinya tercatat dan ditampilkan sesuai manifes, dan CC-BY-NC, aset hasil ekstrak game serta apa pun dari Firewatch ditolak; (5) paket mentah yang diunduh pemilik ditaruh di folder masuk terpisah bersama berkas lisensi aslinya, lalu hanya model terpilih disalin ke proyek; (6) bila unduhan tidak mungkin, jalur generator-saja tetap sah dan tidak menurunkan syarat bentuk di bagian 3.

Sumber wajib dapat dikenali dari jarak interaksi, skala ruangan nyaman, warna UI terbaca pada seluruh latar, kondisi petak/tanaman berbeda secara bentuk/teks, dan dunia tetap terasa Indonesia tanpa detail berlebihan. Visual P1 diterima setelah uji rute dan performa; bukan hanya satu kamera screenshot yang menarik.

## 11. Riwayat perubahan

| Versi | Tanggal | Perubahan |
| --- | --- | --- |
| 0.2 | 27 Oktober 2026 | Arah visual dan produksi aset P0 |
| 0.3 | 30 Oktober 2026 | SCOPE-001: shader dan material bersama, palet Senja, atmosfer dan kabut P0.5, tahap mutu, keadaan nyata aset sejak ART-001, katalog aset P0.5, aturan CC0 + generator dan manifes; anggaran dipindahkan ke CONTENT bagian 20 |
