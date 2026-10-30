Membangun implementasi game Buku Resep 2045 secara berurutan mulai dari SETUP-001 hingga QA-001 untuk tujuan produksi (versi awal utuh yang dapat dimainkan di Godot dan diverifikasi menyeluruh).

Integrity mode: development

## Verification Resources
- Rencana pengujian dan kasus uji penerimaan: `docs/TEST_PLAN.md`
- Aturan pelaksanaan, batasan, dan kepatuhan pengujian: `AGENTS.md`
- Register tugas dan kriteria penyelesaian: `docs/TASKS.md`
- Dokumen acuan produk dan konten: `PRD.md`, `docs/CONTENT.md`, `docs/PROTOTYPE.md`, `docs/UI_UX.md`, `docs/LEVEL_DESIGN.md`, `docs/ART_DIRECTION.md`

## Requirements

### R1. Pengerjaan Berurutan SETUP-001 sampai QA-001
Melaksanakan implementasi secara berurutan dari SETUP-001 (setup engine Godot rilis stabil dan struktur proyek) sampai QA-001 (playthrough penerimaan P0 gameplay), mencakup LVL-001, PLY-001, INT-001, INV-001, BOOK-001, GARD-001, GARD-002, WORLD-001, COOK-001, COOK-002, SOC-001, SAVE-001, UI-001, dan ART-001 (visual dan audio dasar yang konsisten). Setiap task harus memenuhi spesifikasi dan kriteria selesai yang didefinisikan pada docs/TASKS.md.

### R2. Kepatuhan Aturan Kerja AGENTS.md dan Pelaporan Per Task
Mengikuti seluruh aturan kerja pada AGENTS.md. Setiap task wajib diverifikasi secara nyata sebelum ditutup. Untuk setiap task yang selesai, tim wajib membuat satu laporan terperinci bernomor baru di docs/completed_tasks/ (menggunakan format TEMPLATE.md) serta memperbarui docs/PROJECT_STATUS.md dan docs/TASKS.md sebelum melanjutkan ke task berikutnya.

### R3. Kemandirian Eksekusi Tanpa Konfirmasi Rutin
Menjalankan seluruh rangkaian pekerjaan secara mandiri dan berkesinambungan tanpa berhenti meminta konfirmasi manual kepada pengguna, kecuali jika terdapat kendala teknis nyata (blocker teknis) yang menghalangi kelanjutan task.

### R4. Kepatuhan Aset, Dependensi, dan Integritas Pengujian
Setiap dependensi tambahan wajib terdokumentasi. Aset dan kode pihak ketiga harus memiliki izin penggunaan yang sesuai serta lisensi dan atribusi yang tercatat. Tes yang gagal tidak boleh dihapus atau dilemahkan hanya agar hasilnya tampak lulus.

## Acceptance Criteria

### Eksekusi dan Fungsionalitas Task (SETUP-001 hingga QA-001)
- [ ] SETUP-001: Proyek Godot rilis stabil dapat dibuka dan dijalankan tanpa error penghambat, dengan versi, renderer, main scene, dan cara run tercatat di README.
- [ ] LVL-001 & PLY-001: Graybox map, rumah, pekarangan, collision, kendali first-person, dan titik recovery berfungsi tanpa menembus dinding atau terjebak.
- [ ] INT-001 & INV-001: Interaksi objek (prompt, occlusion), sistem inventaris tas dan peti, transfer item, dan batasan kapasitas berfungsi tanpa duplikasi atau kehilangan item.
- [ ] BOOK-001, GARD-001 & GARD-002: Resep sayur bening bayam dan jagung dapat dilacak di buku; siklus berkebun bayam (persiapan petak, benih, penyiraman, pemupukan, pertumbuhan 4 tahap, dan panen) berfungsi sesuai data CONTENT.
- [ ] WORLD-001, COOK-001 & COOK-002: Sumber jagung, temu kunci, dan air di dunia dapat diambil/diisi ulang; alur memasak (validasi bahan, reservasi, tahapan panas, output, konsumsi hidangan) berfungsi tanpa duplikasi atau konsumsi ganda saat dibatalkan.
- [ ] SOC-001: Dialog tetangga dan opsi berbagi hidangan berfungsi serta menutup alur pengalaman P0 dengan benar.
- [ ] SAVE-001: Sistem save/load terpadu memulihkan seluruh state (posisi, inventaris, status kebun, alur masak, resep, pengaturan) secara konsisten dan mampu menangani kondisi gagal atau data rusak.
- [ ] UI-001: Antarmuka terpadu (menu pause, pengaturan, alur error, konfirmasi) berfungsi dan tersimpan.
- [ ] ART-001: Visual dan audio dasar konsisten diterapkan sehingga tanaman, item, dan lokasi dapat dikenali.
- [ ] QA-001: Playthrough penuh dari awal hingga akhir berhasil dijalankan tanpa bug kritis (crash, softlock, duplikasi/kehilangan data), dengan kasus uji relevan pada docs/TEST_PLAN.md diverifikasi dan dicatat.

### Dokumentasi dan Pencatatan (AGENTS.md)
- [ ] Setiap task yang selesai memiliki laporan bernomor unik di docs/completed_tasks/ (dimulai dari nomor berikutnya setelah 001, yaitu 002-...) yang lengkap sesuai docs/completed_tasks/TEMPLATE.md.
- [ ] docs/PROJECT_STATUS.md mencantumkan entri pekerjaan selesai yang bertautan ke setiap laporan baru dan memuat deskripsi status terkini (150–300 kata) yang akurat.
- [ ] docs/TASKS.md menandai task yang selesai sebagai SELESAI dengan tautan laporan completed_tasks yang bersangkutan.

### Integritas dan Kemandirian
- [ ] Seluruh dependensi, izin lisensi aset pihak ketiga, dan hasil pengujian nyata tercatat secara transparan tanpa manipulasi pengujian.
- [ ] Pengerjaan berjalan berurutan dari awal sampai akhir tanpa interupsi konfirmasi pengguna kecuali terdapat blocker teknis.
