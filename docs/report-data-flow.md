# Laporan inspeksi

Laporan memakai `inspectionControllerProvider`, sumber data yang sama dengan Home,
Peta, dan Profil. Data contoh beserta model dan halaman detail lama yang tidak
digunakan sudah dihapus. Nama petugas berasal dari profil akun saat inspeksi
disimpan; tidak ada nama pribadi yang ditetapkan sebagai data contoh Laporan.

- Periode awal adalah bulan berjalan berdasarkan waktu lokal perangkat.
- Pilihan **Semua waktu** menampilkan inspeksi dari seluruh bulan.
- **Pilih bulan dan tahun** menyediakan Januari–Desember dan tahun 1–9999.
  Pilih **Semua bulan** untuk laporan satu tahun penuh. Bulan/tahun tanpa data
  tetap boleh dipilih dan menampilkan keadaan kosong yang sesuai.
- Pilihan khusus diterapkan melalui **Terapkan periode**. Menutup sheet tanpa
  menerapkan tidak mengubah laporan. Saat dibuka ulang, pilihan terakhir ditampilkan.
- Periode khusus tetap pada bulan/tahun pilihan saat kalender berganti;
  **Bulan ini** tetap mengikuti kalender lokal perangkat.
- Hitungan ringkasan mengikuti periode, sedangkan filter risiko dan pencarian hanya
  menyaring daftar. Satu hitungan adalah satu inspeksi tersimpan, bukan pohon unik.
- Ringkasan hanya menampilkan angka. Pilihan periode, pencarian, filter risiko,
  dan reset filter berada pada bagian Daftar inspeksi.
- **Belum sinkron** mengikuti `isSynced` pada data lokal, bukan deteksi jaringan.
- Filter, pencarian, dan pilihan periode direset ketika akun berganti.
- Ketukan kartu membuka detail dari inspeksi yang dipilih.
- Penyimpanan offline dan pembaruan Realtime diteruskan oleh controller yang sudah ada.
- Pergantian hari/bulan diperiksa pada tengah malam dan ketika aplikasi aktif kembali.
- Kegagalan cloud tanpa cache tidak ditampilkan sebagai laporan kosong yang berhasil dimuat.
- Migration Supabase dan batas akses per akun tetap mengikuti konfigurasi inspeksi yang ada.

Desain mengikuti struktur mockup Laporan pada proposal: ringkasan hijau, kartu putih,
badge risiko, tanggal, alamat, dan indikator skor kesehatan. Ringkasan memakai empat
kolom pada lebar yang cukup dan dua kolom pada layar kecil atau teks besar.

Pemeriksaan: `flutter analyze --no-pub` dan
`flutter test --no-pub test/report_data_flow_test.dart`.

Test mencakup batas bulan/tahun, filter, laporan lama, simpan offline dan sinkronisasi,
pergantian kalender dan akun, bulan/tahun pilihan, laporan setahun penuh,
validasi tahun, pembatalan pilihan, navigasi detail, serta tampilan layar kecil.
