# Log Lisensi dan Atribusi Audio (ART-001)

Sesuai aturan kerja `AGENTS.md` § 10 dan `docs/ART_DIRECTION.md` § 10:

## 1. Pipeline Audio Prosedural (Default Mandiri)
- **Implementasi**: `scripts/audio/audio_synthesizer.gd`
- **Lisensi**: Proyek Internal Buku Resep 2045 (MIT / Hak Cipta Tim Proyek)
- **Metode**: Sintesis PCM 16-bit 22.050 Hz matematis deterministik di dalam GDScript murni.
- **Dependensi Eksternal**: Nol (0) dependensi unduhan atau file binary eksternal tak terlacak.
- **Daftar Suara Prosedural**:
  1. `ambience_countryside`: Angin perdesaan lembut low-pass ~150Hz + harmonik bambu (loop 4.0s).
  2. `footstep`: Langkah kaki di tanah/rumput dengan variasi acak nada (pitch jitter) ±7%.
  3. `tool_hoe`: Dentang mata cangkul kontak tanah + getaran bumi (0.22s).
  4. `tool_water`: Gemercik aliran siraman air (0.60s).
  5. `tool_fertilizer`: Taburan butiran kompos/pupuk (0.25s).
  6. `harvest`: Denting nada D5 naik saat memetik/memanen (0.22s).
  7. `kitchen_simmer`: Gemuruh rebusan dan letupan gelembung masakan sayur bening (loop 2.5s).
  8. `ui_click`: Klik taktil tombol antarmuka (0.04s).
  9. `ui_confirm`: Akord konfirmasi dua nada harmonis (0.28s).
  10. `eat_dish`: Sentuhan sendok keramik mangkuk dan konsumsi hidangan (0.35s).
  11. `heat_stall`: Peringatan nada turun saat panas kompor tertahan (0.30s).

## 2. Saluran Drop-In Aset CC0 (Opsional)
- Direktori: `res://assets/audio/`
- Sistem `AudioManager` mendeteksi file `.wav` atau `.ogg` bernama sama di folder ini dan secara otomatis memprioritaskannya di atas generator prosedural.
- Setiap aset yang ditambahkan ke folder ini wajib mencantumkan sumber URL, lisensi (CC0 / Domain Publik), pencipta, tanggal perolehan, dan modifikasi pada file ini.
