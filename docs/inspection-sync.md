# Data inspeksi Home dan sinkronisasi

## Setup Supabase

Migrasi: supabase/migrations/202610170001_inspections.sql

1. Buka dashboard Supabase dan pilih project yang URL-nya sesuai SUPABASE_URL di .env.
2. Buka SQL Editor, buat query baru, salin seluruh file migrasi, lalu klik Run.
3. Migrasi membuat public.inspections, bucket privat kiwit-inspection-photos, policy per akun, dan publication Realtime.
4. Aplikasi menggunakan akun pengguna yang login dan anon/publishable key biasa. Service-role key tidak dibutuhkan di aplikasi.

## Penggunaan

Setelah dependency diperbarui, lakukan hot restart dengan R besar pada terminal flutter run.

1. Masuk ke akun petugas.
2. Ambil foto melalui Scan, lengkapi hasil dan catatan, lalu tekan Simpan.
3. Hasil dan foto disimpan di penyimpanan aplikasi terlebih dahulu. Pesan berhasil hanya muncul setelah penulisan lokal selesai.
4. Home langsung memperbarui total dan grafik tujuh hari kalender terakhir, serta lima inspeksi terbaru.
5. Sinkronisasi mengunggah foto privat dan metadata ke Supabase. Status Home menunjukkan antrean, kegagalan koneksi, atau data yang telah tersinkron.
6. Untuk menguji antarperangkat, gunakan akun yang sama pada perangkat kedua. Home menerima perubahan lewat Supabase Realtime; tarik untuk memperbarui jika diperlukan.

## Perilaku data

- Grafik menghitung jumlah inspeksi tersimpan menurut waktu scan dalam zona waktu perangkat, bukan jumlah pohon unik.
- Label hari mengikuti rentang tujuh hari yang sebenarnya, termasuk pergantian bulan dan tahun.
- Data contoh lama di Home tidak dimigrasikan menjadi inspeksi sungguhan.
- Data lokal dan foto dipisahkan menurut akun. Data mode tamu tidak otomatis dialihkan ke akun lain.
- Koneksi terputus tidak menghapus data lokal. Retry otomatis berjalan setiap satu menit dan saat Home dibuka kembali; menarik Home juga memicu sinkronisasi.
- UUID yang sama digunakan pada retry agar inspeksi tidak terduplikasi.
- Pengambilan data cloud memakai pagination sehingga jumlah inspeksi tidak dibatasi satu halaman.
- Sinkronisasi saat ini mengikuti akun petugas yang sama; bukan penggabungan seluruh akun dalam satu rayon.
- Home, Peta, Profil, dan Laporan memakai sumber inspeksi yang sama. Laporan dapat menampilkan bulan berjalan atau semua waktu, serta membuka detail inspeksi berdasarkan UUID.

## Pemeriksaan

flutter test --no-pub test/inspection_sync_test.dart

Test mencakup hitungan kalender, serialisasi, simpan offline, kegagalan disk, retry tanpa duplikasi, koneksi lambat, notifikasi Realtime, cache offline, isolasi akun, dan tampilan pada layar sempit.
