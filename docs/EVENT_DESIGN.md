# Event Tematik — Kerangka dan Usulan “Karhutla”

**Versi:** 0.3 · **Tanggal:** 30 Oktober 2026  
**Dasar:** ide terbaru pengguna tentang event bertema kondisi Indonesia, pada satu map fiksi, dengan sains dasar dalam beberapa aspek permainan.  
**Rujukan:** [PRD](../PRD.md), [Prototipe](PROTOTYPE.md), [Level](LEVEL_DESIGN.md), [Konten](CONTENT.md), [UI/UX](UI_UX.md).

## 1. Hal yang sudah jelas dan hal yang masih usulan

**ARAH DISETUJUI DALAM DISKUSI:** identitas memakai nama game utama + judul event; “Karhutla” adalah contoh judul event, bukan nama game utama atau chapter. Dunia berupa satu map fiksi dengan banyak referensi Indonesia. Event dapat membawa tema berbeda, mengubah tantangan memperoleh bahan dan memanfaatkan sains sederhana di beberapa kegiatan. Kebakaran harus benar-benar menjadi kejadian di dunia, bukan sekadar tema poster.

**DEFAULT RENCANA:** P0 membuktikan satu loop memasak sebelum event aktif ditambahkan. Event pertama masuk jalur P1 setelah gerbang gameplay/save dasar lulus; sejak 30 Oktober 2026 itu berarti setelah gerbang P0.5 "Kampung Hidup" (QA-002, PRD D26), yang sengaja tidak memuat event. Ini pembagian produksi untuk mengendalikan cakupan, bukan penghapusan ide.

**USULAN BARU:** rincian aktivasi, titik api, alur, angka, UI tambahan dan resep event dalam dokumen ini adalah rancangan konkret yang belum diuji. Pengguna belum mengunci seluruh detail. Jangan menandai event sudah terimplementasi atau seluruhnya disetujui hanya karena ide utamanya telah dibahas.

## 2. Identitas dan arti event

Format: **Nama Game: Nama Event**. Contoh dengan nama kerja: **Buku Resep 2045: Karhutla**. Nama utama final masih terbuka. Event lain dapat memakai judul lain dan tema lain; tidak otomatis menjadi chapter berurutan.

Event adalah paket keadaan lingkungan, tujuan situasional, konten, perubahan sumber dan akibat yang terjadi pada map yang sama. Tidak harus live-service, kompetisi musiman atau terbatas tanggal dunia nyata. Default: konten event terpasang bersama versi game, dipilih/dipicu melalui progres dan konfirmasi pemain, dapat dimainkan offline dan disimpan.

Kondisi Indonesia memberi inspirasi tematik saat konten ditulis. Tidak ada pengambilan berita langsung, sinkronisasi bencana aktual atau klaim mewakili kejadian nyata tertentu. Usulan ini tidak menyatakan bahwa saat ini ada bencana tertentu di Indonesia. Tiap event membutuhkan riset dan penulisan tersendiri sebelum produksi.

## 3. Hubungan dengan buku dan map

Buku tetap tujuan utama, memasak tetap loop pengikat. Event mengubah **cara mencapai bahan**, alasan berinteraksi dengan warga dan perubahan sumber pangan. Event tidak mengganti tujuan menjadi simulasi pemadam kebakaran penuh.

Satu map menyimpan rumah, kebun dan landmark yang sudah dikenal. Event menerapkan perubahan pada subset objek melalui ID stabil. Rumah aman, save dan sumber pemulihan awal tetap tersedia. Karhutla mengganggu jalur menuju kebun; pemain menanggapi masalah lokal agar dapat melanjutkan kebutuhan masakan.

Resep P0 tetap sama dan tidak dihapus. Event pertama memakai resep tersebut sebagai uji hubungan event–bahan; resep baru bukan prasyarat membuktikan event. Pada P0.5 buku memiliki tiga resep warisan; default rancangan event tetap memakai resep pertama, dan EV-001 memutuskan apakah tiga resep itu mengubah prasyarat atau pilihan resep event. Area hutan desa P0.5 menyisakan tepi yang kelak dapat menjadi koridor event tanpa dibangun sekarang (LEVEL_DESIGN bagian 2.1). Resep event tambahan nanti memerlukan definisi lengkap CONTENT, bukan kartu kosong di buku.

## 4. Usulan alur Karhutla

| Tahap | Dunia/tujuan pemain | Mekanik | Hubungan dengan masakan |
| --- | --- | --- | --- |
| Normal | Kampung dikenal, resep dasar pernah selesai | Loop P0 | Pemain punya kemampuan dasar |
| Kabar/peringatan | Warga menyampaikan api di tepi kebun; asap lokal terlihat | Panel aktivasi singkat dan penjelasan rute | Sumber jagung lama belum bisa diakses |
| Gangguan aktif | Beberapa titik vegetasi benar-benar terbakar pada zona terbatas | Rute utama ditutup, rute pos air tersedia | Tracker menyebut akses kebun terganggu |
| Respons lokal | Periksa pos air, sambungkan suplai, gunakan selang terpasang pada titik kecil yang ditentukan | Aksi tahan, resource abstrak dan feedback api mereda | Membuka koridor ke bagian kebun yang tersisa |
| Terkendali | Api aktif di koridor selesai; area bekas tetap hangus | Validasi state, bukan langsung pulih hijau | Jagung dari tanaman yang tidak terbakar dapat dipanen |
| Pemulihan | Petak pemulihan nonpangan diperiksa dan dilindungi; sumber air dijaga dari limpasan | Tutup pelindung, saluran pengalih sederhana, mulsa pada bedeng yang layak | Mempertahankan sumber air dan efisiensi perawatan kebun |
| Masak dan berbagi | Bahan diperoleh, hidangan dibuat dan digunakan | Sistem dapur/buku yang sudah ada | Makanan menutup pengalaman lokal |
| Sisa dampak | Api padam, jejak hangus/pemulihan tetap terlihat | Save menyimpan perubahan | Dunia menunjukkan akibat dan kemungkinan lanjut |

Bukan semua titik api pada cakrawala yang harus dipadamkan pemain. Api latar dapat menggambarkan wilayah lebih luas, sedangkan respons pemain terbatas pada koridor lokal yang dirancang. Tidak ada tujuan masuk ke bangunan terbakar atau memadamkan kebakaran besar sendirian.

## 5. Sains dasar melalui tindakan

Pemain melihat gejala → memilih tindakan masuk akal → mengamati akibat → mendapat penjelasan singkat opsional. Tidak perlu rumus, kuis, pengukuran laboratorium atau banyak jenis bahan kimia.

| Aspek | Konsep yang mendasari | Tindakan/feedback rancangan | Batas representasi |
| --- | --- | --- | --- |
| Api | Pembakaran berkaitan dengan panas, bahan bakar dan oksigen [S1] | Selang terpasang menurunkan intensitas titik api yang sudah ditentukan; bentuk/bunyi berubah | Durasi, unit air dan jangkauan adalah aturan game, bukan prosedur lapangan |
| Air dan aliran | Hilangnya penutup lahan dapat meningkatkan aliran permukaan dan membawa sedimen pascakebakaran [S2] | Lindungi penampung bersih dan alihkan jalur limpasan menjauh dari suplai | Tidak mengubah air tercemar menjadi layak minum dengan satu filter |
| Kebun dan kelembapan | Mulsa dapat membantu mengurangi penguapan permukaan tanah [S3] | Pilih tutup tanah/mulsa untuk petak aman; laju kering berkurang dalam simulasi | Besar pengurangan adalah balancing, tidak berlaku universal |
| Pemulihan lahan | Pemulihan berbeda dari sekadar api tidak menyala | Inspeksi, penutup lahan, waktu/kunjungan lanjutan dan tanaman nonpangan | Hijau kembali tidak membuktikan tanah aman untuk pangan |

Pilih tiga contoh yang mendukung event dahulu. Jangan langsung menambah seluruh mekanik di tabel sebagai sistem wajib P0. Sains dapat juga muncul pada panas memasak yang sudah ada: memilih panas sesuai petunjuk mengubah kemajuan, tanpa mengklaim proses keamanan pangan nyata.

## 6. Usulan batas aksi dan kesulitan

Satu event aktif pada satu waktu. Intensitas awal terkontrol, tidak ada kehancuran seluruh map secara acak. Default pertama tidak memakai sebaran acak atau sebaran tambahan. Sebaran tambahan pada iterasi berikutnya, bila dipakai, hanya pada hubungan antartitik yang sudah didesain dan tidak dapat melewati rumah aman. Menutup menu/app menghentikan seluruh timer event.

P1 awal tidak memakai kematian, kehilangan buku, kehilangan semua panen atau kekalahan permanen. Memasuki batas bahaya menahan gerak/menampilkan peringatan dan mengarahkan kembali, bukan memberi damage tersembunyi. Tantangan berasal dari akses, sumber daya lokal dan urutan respons, bukan refleks menekan puluhan tombol.

Suplai pos air untuk respons event terpisah dari penyiram kebun P0. Jangan menjadikan penyiram kecil sebagai alat universal pemadam semua kebakaran. Jika suplai event kurang, ada isi ulang deterministik dari fasilitas event yang dapat dicapai. Nilai percobaan dinyatakan pada bagian event CONTENT, bukan diduplikasi di sini.

## 7. Aktivasi dan perjalanan state

Usulan prasyarat pertama: P0 selesai sampai hidangan digunakan dan save dasar tersedia. Buku membuka bagian **Kabar kampung** hanya setelah kontennya tersedia. Pemain membaca ringkasan lalu memilih **Mulai event Karhutla**; tidak dimulai diam-diam ketika sedang menyimpan atau memasak.

Sebelum aktivasi, pastikan tidak ada job memasak aktif dan buat checkpoint pra-event. Terapkan kondisi event sebagai transaksi dunia yang utuh. Jika aktivasi gagal, kembali ke keadaan sebelum aktivasi; jangan menyimpan setengah objek terbakar.

Checkpoint pra-event adalah tambahan khusus P1, terpisah dari checkpoint manual/autosave P0. Simpan sebagai snapshot yang tidak ditimpa autosave berikutnya selama event berlangsung. Tawarkan pemuatan dengan peringatan kehilangan progres sejak aktivasi; bukan tombol membatalkan event sambil mempertahankan barang hasil event.

Pada aktivasi, simpan jumlah masakan yang pernah dibuat sebagai baseline per resep (P0.5 memiliki tiga resep) dan reset flag penggunaan khusus event. Akhir event mensyaratkan commit masakan baru setelah aktivasi, lalu makan/berbagi setelah commit itu. Centang buku dan `meal_used` P0 yang sudah ada tidak otomatis memenuhi event; aturan angka dan urutan lengkap pada CONTENT.

Keadaan konseptual: `available → warning → active → contained → recovery → resolved`. `active` berarti kejadian kebakaran berjalan; `contained` berarti target koridor lokal terkendali; `recovery` berarti pekerjaan pascakejadian; `resolved` berarti tujuan lokal dan masakan event selesai. Nama `contained` tidak menyatakan seluruh wilayah bebas risiko.

Pemain dapat keluar dari game dan melanjutkan tahap yang sama. Tidak ada tombol hapus event di tengah yang mengembalikan barang/dunia secara ambigu. Pemain yang ingin kembali sebelum aktivasi dapat memilih checkpoint pra-event dengan peringatan kehilangan progres setelahnya. Selesai event tidak otomatis menghapus bekas kebakaran. Event berikutnya hanya tersedia setelah kompatibilitas perubahan map ditentukan.

## 8. Kontrak data dan save lanjutan

Tambahan konseptual, belum skema runtime yang diimplementasikan:

| Entitas | Field penting |
| --- | --- |
| EventDefinition | ID, versi konten, nama tampilan, prasyarat, area terdampak, tujuan, ID sumber dan referensi sains |
| EventInstance | ID instance, event_id, fase, tujuan selesai, state titik api, suplai, perbaikan, flag hidangan digunakan |
| WorldOverrides | ID objek → perubahan akses/visual/status yang disebabkan event |
| FireNode | ID tetap, intensitas abstrak, status, koneksi spread terbatas bila dipakai |
| RecoverySite | ID, inspeksi, intervensi, kemajuan pemulihan, batas penggunaan pangan |
| EventCheckpoint | Identitas snapshot pra-event dan versi save yang valid |

Pada dunia chunk P0.5 perubahan event disimpan sebagai override berdasarkan ID objek yang stabil, bukan dengan mengubah keluaran generator dunia; objek prosedural hanya boleh dirujuk event bila ID-nya stabil pada versi generator yang sama. Event tidak menimpa data petak awal atau inventaris dengan baseline kosong. Gunakan ID sumber yang sama jika objek sama, dan ID baru untuk objek event baru. Job memasak dan panen tetap memakai aturan transaksi P0. Save memuat definisi versi yang cocok; konten event hilang/tidak cocok tidak boleh menyebabkan penghapusan progres diam-diam.

Load hanya memulihkan keadaan, bukan memutar ulang aktivasi, mengurangi air lagi atau memberi reward kedua kali. Penulisan snapshot mengikuti kontrak safe save PROTOTYPE. Timer api/spread hanya berjalan saat simulasi aktif, termasuk dapur aktif sesuai kontrak waktu; pause, buku, tas, dialog dan aplikasi tertutup menghentikannya.

## 9. UI dan identitas

Judul event muncul pada aktivasi dan halaman Kabar kampung, bukan permanen besar di layar. HUD tetap satu tracker resep dengan satu kebutuhan situasional terdekat. Detail kondisi, sumber air, pemulihan dan penjelasan sains berada dalam interaksi relevan/buku.

Gunakan status “Api aktif”, “Mereda”, “Koridor terkendali”, “Perlu pemulihan”, bukan angka temperatur palsu atau klaim “Tanah steril/aman dimakan”. Aksi menyatakan target dan biaya. Event tidak menambah hotbar besar; selang dapat dipakai melalui stasiun kontekstual dengan E dan klik kiri, lalu kembali ke alat biasa saat ditutup.

## 10. Uji dan gerbang produksi

Event baru boleh diimplementasikan setelah P0 gameplay/save terbukti dan gerbang P0.5 (QA-002) lulus. Task persiapannya tercatat EV-001 dan seterusnya pada TASKS dan bergantung ke QA-002; dependensi lama ke QA-001 dicatat di TASKS sebagai riwayat. Kriteria event: api benar-benar berubah keadaan, akses bahan terhubung tujuan, jalur pemulihan selalu ada, UI tetap sederhana, menu menghentikan timer, dan save/load tidak menggandakan suplai/reward.

Penguji harus dapat menjelaskan satu sebab-akibat dari tindakannya tanpa menghafal istilah sains. Pastikan juga ia memahami bahwa api padam tidak berarti lahan pulih, dan air/hasil pangan terdampak tidak langsung aman. Data keberhasilan berasal dari playtest, bukan asumsi dokumen.

## 11. Kandidat event lain — bukan janji konten

Kekeringan dapat menguji penyimpanan air dan pengurangan penguapan; banjir dapat mengubah rute dan perlindungan persediaan; gangguan pasokan dapat mendorong diversifikasi bahan lokal. Tiap tema memerlukan riset, definisi resep dan uji tersendiri. Tidak ada urutan chapter, jadwal peluncuran atau integrasi berita otomatis yang dikunci.

## 12. Sumber konsep yang diperiksa

Sumber berikut mendukung konsep umum, bukan validasi angka mekanik atau panduan menangani bencana nyata. Diakses 27 Oktober 2026.

- **[S1]** National Park Service, [Wildland Fire Behavior](https://www.nps.gov/articles/wildland-fire-behavior.htm): kerangka dasar api dan faktor perilaku kebakaran.
- **[S2]** U.S. Geological Survey, [Water Quality After Wildfire](https://www.usgs.gov/mission-areas/water-resources/science/water-quality-after-wildfire/): hubungan perubahan vegetasi/tanah dengan aliran permukaan serta material yang terbawa ke air.
- **[S3]** Food and Agriculture Organization, [Drought-resistant soils](https://www.fao.org/4/a0072e/a0072e07.htm): peran penutup tanah/mulsa dalam mengurangi penguapan permukaan.

Sains lokal Indonesia, tipe vegetasi, gambut, musim, pencemar dan tindakan pemulihan spesifik belum divalidasi untuk event ini. Judul Karhutla tidak otomatis berarti simulasi kebakaran gambut. Sebelum menulis narasi atau mekanik spesifik, verifikasi konteks tersebut dan batasi klaimnya.

## 13. Riwayat perubahan

| Versi | Tanggal | Perubahan |
| --- | --- | --- |
| 0.2 | 27 Oktober 2026 | Kerangka event dan usulan Karhutla |
| 0.3 | 30 Oktober 2026 | SCOPE-001: gerbang event dipindah ke QA-002 (P0.5 tidak memuat event), baseline masakan per resep, override event pada dunia chunk; event tetap USULAN BARU |
