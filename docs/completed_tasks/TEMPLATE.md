# Template Laporan Task Selesai

Dokumen ini adalah panduan struktur, bukan laporan task yang sudah dikerjakan. Salin ke file bernomor baru; ganti petunjuk pada setiap bagian dengan isi faktual. Tidak ada field yang boleh dibiarkan kosong pada laporan final. Jika tidak berlaku, tulis “Tidak berlaku” dan alasannya.

## Identitas

- **ID task:** tulis ID yang sama dengan TASKS.
- **Judul:** nama pekerjaan lengkap yang mudah dipahami.
- **Tanggal selesai:** tanggal pelaksanaan sebenarnya.
- **Agent/pelaksana:** identitas pelaksana yang tersedia; tidak perlu mengarang nama model.
- **Tahap produk:** dokumentasi, P0, P1 atau tahap lain yang benar.
- **Status:** Selesai hanya jika kriteria task terpenuhi.
- **Versi sumber/build:** commit/branch/versi nyata; jika repository/build belum ada, nyatakan demikian.

## Tujuan dan pemicu

Jelaskan masalah atau kebutuhan yang membuat task diperlukan, hasil yang diminta pengguna, dan rujukan PRD/dokumen domain. Tuliskan kondisi awal yang membantu pembaca memahami perubahannya.

## Ruang lingkup

Jelaskan bagian yang dikerjakan dan batas task. Pisahkan cakupan selesai dari ide lanjutan. Jika keputusan baru diambil, nyatakan apakah keputusan pengguna atau default uji dan alasannya.

## Perubahan dan perilaku akhir

Jelaskan hasil secara terperinci: apa yang berubah, cara kerjanya, hubungan antarsistem dan akibatnya bagi pengguna/pemain. Untuk bug, sertakan reproduksi dan penyebab. Untuk dokumentasi, jelaskan keputusan yang diselaraskan dan hubungan antarfile.

## File yang ditambahkan atau diubah

Buat tabel path relatif, jenis perubahan dan tujuan. Tautkan file yang masih tersedia. Jangan menulis “semua file” bila daftar konkret diperlukan untuk review. Tidak perlu menempel seluruh kode atau log.

## Verifikasi yang benar-benar dilakukan

Buat tabel ID pemeriksaan, lingkungan/input, tindakan, hasil nyata dan status. Tulis perintah aktual hanya jika benar-benar dijalankan. Untuk visual, sebut bagian/layout yang diperiksa dan keterbatasan penampil. Pisahkan pemeriksaan dokumen, tes otomatis dan playtest. Catat tes gagal yang relevan beserta penyelesaiannya.

## Kriteria selesai

Hubungkan hasil dengan setiap kriteria task. Jangan hanya menulis “selesai” tanpa bukti. Kriteria yang belum terpenuhi berarti task belum layak mendapat laporan selesai; pindahkan sebagai status terhambat/berjalan hingga benar-benar dipenuhi.

## Dampak, kompatibilitas dan keterbatasan

Jelaskan pengaruh pada konten, UI, save, data, performa dan cara menjalankan jika relevan. Nyatakan apa yang belum dapat diverifikasi dan apakah itu di luar task. Bedakan batas verifikasi dari kegagalan yang menghalangi penerimaan.

## Tindak lanjut dan handoff

Sebut ID task berikutnya, alasan urutan, prasyarat dan risiko yang harus diperhatikan. Rujuk sumber data yang harus dibaca agent berikutnya. Jangan memberi instruksi bertentangan dengan PRD atau menganggap task berikutnya sudah diotorisasi.

## Penutupan catatan

Konfirmasikan laporan ditautkan dari PROJECT_STATUS, status task diperbarui di TASKS dan deskripsi terakhir diganti. Cantumkan koreksi bertanggal bila laporan ini nantinya diperbaiki; jangan menghapus riwayat hasil hanya untuk menutupi regresi.
