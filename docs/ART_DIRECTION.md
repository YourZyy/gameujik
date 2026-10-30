# Arah Visual, Audio dan Produksi Aset

**Versi:** 0.2 · **Tanggal:** 27 Oktober 2026  
**Keputusan utama:** stylized sederhana, referensi artistik Firewatch, kampung fiktif Indonesia.  
**Rujukan:** [PRD](../PRD.md), [Level](LEVEL_DESIGN.md), [UI/UX](UI_UX.md), [Event](EVENT_DESIGN.md).

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
| Warga | Proporsi manusia sederhana, pakaian sehari-hari | Gestur tenang dan ekspresi dasar | Karakter fotorealistis yang bertabrakan dengan lingkungan |
| Papan/catatan | Tulisan terbaca, komposisi sederhana | Petunjuk narasi yang dipakai | Teks dekorasi kecil yang harus dibaca untuk progres |

Pilih material terbatas yang dapat dipakai ulang. Tekstur menunjukkan kayu, tanah dan plester tanpa meniru detail foto pada seluruh permukaan. Tanaman dan bangunan tidak harus memiliki material unik per benda. Bekas pakai boleh melalui variasi warna atau decal selektif.

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

UI mengambil warna yang selaras dengan dunia tetapi memprioritaskan kontras. Efek glassmorphism dekoratif bukan tujuan UI game; blur/transparansi tidak boleh mengganggu pembacaan.

## 5. Cahaya, atmosfer dan kamera

P0 memakai satu suasana sore stabil untuk menilai bentuk dan warna. Gunakan arah cahaya yang menonjolkan teras serta jalur pulang. Rumah hangat tanpa harus menerangi semua ruangan dengan banyak lampu real-time. Bayangan selektif dan ambient cukup agar objek interaksi tidak hilang dalam gelap.

Kabut tipis dapat memisahkan foreground dan backdrop bila renderer/perangkat mendukung dengan baik; tidak wajib. Hindari menjadikan volumetric, bloom, depth of field dan motion blur sebagai syarat grafis menarik. Kamera stabil, head bob mati default. Jangan memakai shake pada pickup, siram atau panen rutin.

Perubahan waktu visual penuh bukan kebutuhan P0. Hari simulasi sumber bahan dapat berjalan tanpa animasi matahari malam. Saat event kebakaran diperkenalkan, perubahan langit/asap harus tetap memungkinkan membaca landmark dan batas zona.

## 6. Tahap mutu dan batas produksi

| Tahap | Mutu yang diperlukan | Belum diperlukan |
| --- | --- | --- |
| Graybox | Skala, collision, warna pembeda, prompt dan rute benar | Tekstur final, tangan lengkap, detail dekorasi |
| P0 gameplay | Bahan dapat dikenali, perubahan tanaman/petak terlihat, dapur terbaca | Seluruh map setara screenshot promosi |
| P0 distribusi | Aset sementara berlisensi, visual/audio tidak rusak | Trailer atau brand final |
| P1 | Satu area dan event representatif terhadap arah akhir | Semua variasi resep/daerah sekaligus |

Anggaran awal produksi: satu rumah utama, satu teras warga, satu set pagar modular, satu set vegetasi terbatas, satu petak empat tahap bayam, satu sumber jagung, satu temu kunci, empat alat dan satu hidangan. Jumlah variasi tidak ditambah sebelum loop dan performa diuji.

Untuk objek di dekat kamera, periksa siluet dan shading dari jarak interaksi; untuk latar, prioritaskan massa dan orientasi. Jangan menetapkan jumlah polygon sebagai jaminan performa. Ukur biaya adegan, bayangan, transparansi, material dan efek pada renderer/perangkat nyata.

## 7. Daftar aset P0 dan status

Seluruh aset dunia di bawah berstatus **BELUM DIBUAT / BELUM DIPILIH** pada paket dokumentasi. Wireframe SVG adalah satu-satunya gambar rancangan yang disertakan, bukan aset runtime.

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

## 8. Audio

Ambience kampung, angin tipis, bambu, langkah dan kegiatan dapur memberi tempat terasa hidup. Musik tidak harus terus berjalan. Pickup, tanam, gemburkan, pupuk, siram, panen, tombol buku dan hasil masak mendapat feedback singkat yang berbeda.

Volume master/musik/efek dapat diubah. Informasi penting tetap punya teks. NPC tidak membutuhkan voice-over P0. Jangan memakai suara notifikasi keras untuk interaksi yang diulang. Event kebakaran boleh memakai bunyi api dan lingkungan yang berubah, tetapi tidak menghilangkan kemampuan membaca instruksi.

## 9. Identitas event tematik

Format publik: **Nama Game: Nama Event**. Contoh kerja: **Buku Resep 2045: Karhutla**. Buku Resep 2045 masih nama kerja; Karhutla adalah judul event. Tidak ada label chapter atau nomor episode wajib.

Map dasar mempertahankan siluet rumah, rute dan identitas kampung. Event menambah variasi lokal pada vegetasi, asap, api, arang, suara, sumber air dan beberapa objek cerita. Jangan membuat setiap event memerlukan seluruh aset dunia baru. Api harus benar-benar terlihat serta memengaruhi akses/state, bukan sekadar filter warna.

Efek kebakaran dimulai dari bentuk api stylized terbatas, partikel selektif dan perubahan material lokal. Tidak perlu simulasi asap fluida atau semua objek mudah terbakar. Batasi efek transparan berlapis dan cahaya api dinamis; ukur saat banyak titik api aktif. Efek harus memiliki status teks, batas area dan kontrol yang jelas.

## 10. Lisensi dan kriteria penerimaan

Sebelum aset eksternal masuk, catat: ID/path proyek, sumber URL atau pembuat, jenis lisensi, tanggal perolehan, perubahan, kewajiban atribusi dan apakah distribusi/modifikasi diperbolehkan. Jangan menyalin aset internet berdasarkan kemiripan saja. Font/audio termasuk dalam pencatatan, bukan pengecualian.

Sumber wajib dapat dikenali dari jarak interaksi, skala ruangan nyaman, warna UI terbaca pada seluruh latar, kondisi petak/tanaman berbeda secara bentuk/teks, dan dunia tetap terasa Indonesia tanpa detail berlebihan. Visual P1 diterima setelah uji rute dan performa; bukan hanya satu kamera screenshot yang menarik.
