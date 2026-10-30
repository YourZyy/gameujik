# Arsip Task Selesai

Folder ini menampung penjabaran pekerjaan yang benar-benar selesai. Status utama tetap ringkas di [PROJECT_STATUS](../PROJECT_STATUS.md); daftar rencana tetap berada di [TASKS](../TASKS.md).

## Aturan wajib

AI agent wajib membuat satu laporan per task selesai dan memperbarui daftar selesai serta deskripsi terakhir pada PROJECT_STATUS. Aturan lengkap ada di [AGENTS](../../AGENTS.md). Task yang belum lolos kriteria tidak dimasukkan ke arsip selesai.

Gunakan nama `NNN-nama-task.md`, nomor terbesar yang sudah ada ditambah satu. Nomor tiga digit minimum dan terus bertambah, tidak di-reset per milestone. Slug huruf kecil, angka dan tanda hubung; judul laporan memakai nama lengkap yang mudah dibaca.

Contoh nama untuk pekerjaan yang belum dilakukan: `002-setup-proyek-godot.md`. File contoh tersebut tidak dibuat dan tidak menjadi bukti setup sudah selesai. Laporan yang benar-benar tersedia saat penyerahan adalah [001 — Paket dokumentasi v0.2](001-paket-dokumentasi-v0-2.md).

## Membuat laporan berikutnya

1. Baca task dan kriteria selesai; pastikan bukti tersedia.
2. Salin struktur [TEMPLATE](TEMPLATE.md) ke file bernomor baru.
3. Isi tujuan, ruang lingkup, perubahan, daftar file, verifikasi nyata dan keterbatasan. Tidak berlaku ditulis dengan alasan, bukan dibiarkan kosong.
4. Bedakan fakta implementasi, hasil tes dan saran berikutnya. Jangan mengarang commit atau status lulus.
5. Tambahkan satu judul bertautan di PROJECT_STATUS, ganti deskripsi terakhir, lalu tandai task SELESAI pada TASKS dengan tautan laporan yang sama.
6. Periksa semua tautan setelah file disimpan.

Jika tugas gagal/terhambat, simpan kemajuan pada status terakhir dan TASKS. Jangan menerbitkan laporan berjudul selesai untuk hal yang belum selesai. Jika ada regresi setelah task pernah lulus, buat task perbaikan baru yang merujuk laporan lama. Arsip tidak menjadi tumpukan transkrip atau log mentah; cukup bukti yang relevan dan dapat diperiksa.

## Batas data

Jangan memasukkan secret, kredensial, isi save pribadi atau informasi personal penguji tanpa kebutuhan. Lampiran berukuran besar ditempatkan di folder yang sesuai dan ditautkan, bukan ditanam berulang di setiap laporan. README dan TEMPLATE bukan task yang dihitung selesai.
