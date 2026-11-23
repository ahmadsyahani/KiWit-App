# Perbaikan enam temuan audit — 20 Oktober 2026

## Perubahan perilaku

1. **Risiko dan arahan konsisten.** Pilihan manual ditandai sebagai Penilaian
   petugas. Risiko akhir, arahan, badge, dan data tersimpan mengikuti pilihan
   tersebut. Hasil skrining model tetap terlihat terpisah. Mengubah konteks
   lingkungan memperbarui hasil model tanpa menimpa pilihan petugas. Tombol
   Gunakan hasil model mengembalikan keputusan akhir secara eksplisit.
2. **Antrean sinkronisasi tidak berhenti pada satu record.** Kegagalan per foto
   atau record tidak menghentikan unggahan berikutnya dan pengambilan data cloud.
   Daftar sinkronisasi menampilkan masalah per record dan tombol coba lagi.
   UUID tetap dipakai ulang agar retry tidak membuat duplikasi.
3. **Data lokal yang rusak dapat dipulihkan dengan cadangan.** Penyimpanan
   mencadangkan byte file asli, mengambil record milik akun yang masih dapat
   dibaca, lalu melanjutkan pemulihan dari cloud. Record pending yang masih bisa
   dibaca tetap dipertahankan, termasuk saat offline. Jika pencadangan gagal,
   file asli tidak ditimpa. Peringatan pemulihan ditampilkan terpisah dari status
   sinkronisasi agar cloud yang sudah berhasil tidak dilaporkan gagal.
4. **GPS otomatis diperbarui.** Kamera meminta posisi otomatis lagi saat aktif
   kembali. Sebelum capture, posisi berusia 30 detik atau lebih diperbarui.
   Permintaan yang masih berlangsung digunakan bersama; foto menunggu dengan
   batas waktu. Posisi lama tidak dijadikan pengganti ketika pembaruan gagal.
   Titik tetap yang diberikan sebagai selectedLocation tidak ditimpa GPS.
5. **Cuaca tidak memakai angka contoh.** Respons kosong, malformed, timeout,
   atau kegagalan jaringan menjadi Cuaca belum tersedia. Ketuk untuk mencoba
   lagi. Refresh Home dan app resume memperbarui cuaca bersama inspeksi.
   Detail menampilkan waktu pengambilan data dan lokasi Surabaya. Pesan angin
   aman yang sebelumnya selalu muncul dihapus. Waktu pembaruan adalah waktu
   aplikasi mengambil data, bukan jaminan umur observasi penyedia.
6. **Menu risiko dapat digulir.** Sheet mengikuti safe area dan mendukung layar
   pendek serta teks besar. Susunan badge, indeks kulit, dan detail cuaca juga
   dirapikan setelah test menemukan overflow pada layar kecil.

Penanda penilaian petugas (`isOfficerAssessed`, `modelRiskStatus`) disimpan di
payload JSON yang sama dengan inspeksi, sehingga tidak membutuhkan migration
database baru. Record lama tetap dapat dibaca; asal penilaian manual pada data
lama yang belum memiliki penanda tidak bisa diketahui secara otomatis.

## Cadangan data lokal

Cadangan berada di direktori dokumen aplikasi:

```text
inspections_v1/<ownerId>/records.recovery.<timestamp>.json
inspections_v1/<ownerId>/recovery-notice.txt
```

File pertama menyimpan seluruh byte asli; foto inspeksi di direktori akun tidak
dihapus oleh pemulihan. File notice mempertahankan peringatan setelah aplikasi
dibuka kembali. Cadangan tidak diunggah atau dibuang otomatis. JSON yang rusak
total mungkin tidak bisa dipulihkan sepenuhnya; salinan cloud hanya mengembalikan
record yang sebelumnya telah berhasil tersinkron. Jangan hapus data aplikasi
atau menginstal ulang ketika masih memerlukan cadangan lokal tersebut.

## Verifikasi

Hasil akhir: analyzer **No issues found**, dan **154 test lulus** (138 test
sebelumnya serta 16 test regresi baru). `git diff --check` tidak menemukan
kesalahan whitespace.

Test regresi:

- `test/risk_override_test.dart`: provenance JSON, risiko/arah tersimpan,
  perubahan konteks lingkungan, kembali ke model, dan dua ukuran layar.
- `test/inspection_recovery_test.dart`: record gagal tidak menghambat antrean,
  retry tanpa duplikasi, cadangan byte identik, salvage pending offline,
  pemisahan akun, dan pencadangan gagal.
- `test/scan_gps_refresh_test.dart`: resume, kedaluwarsa posisi, GPS gagal,
  permintaan bersama, serta titik manual.
- `test/weather_flow_test.dart`: respons tidak valid, retry, timestamp,
  penghapusan pesan aman, refresh Home, dan resume.

Pemeriksaan akhir dijalankan dengan:

```text
flutter analyze --no-pub
flutter test --no-pub
```

Pengujian host tidak menggantikan uji APK langsung untuk izin/GPS/kamera native,
email pemulihan, inferensi ONNX Android, dan sinkronisasi dua perangkat. Signing
release tetap menjadi pekerjaan terpisah dari enam temuan ini.

Setelah memperbarui kode pada sesi flutter run, gunakan hot restart (`R`) karena
struktur model/controller bertambah. APK lama perlu dibuild dan dipasang ulang
untuk memuat perubahan ini.
