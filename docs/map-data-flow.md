# Alur data peta inspeksi

Peta menggunakan `inspectionControllerProvider`, sumber data yang sama dengan Home
dan profil. Tidak ada query kedua ke tabel `trees` atau fallback ke contoh pohon.

## Alur pengguna

1. Buka Peta, lalu pilih **Inspeksi baru** untuk langsung membuka kamera.
2. Lokasi GPS dicari otomatis setelah izin kamera diselesaikan.
3. Ambil foto. Lokasi yang selesai dicari selama analisis ikut diteruskan ke hasil;
   pencarian yang masih berjalan ditunggu maksimal 10 detik tambahan.
4. Di hasil, lokasi ditampilkan dengan aksi **Ubah lokasi** atau **Lengkapi lokasi**.
   Pengguna dapat mencoba GPS lagi atau memilih titik di peta jika perlu.
5. Pin muncul setelah penyimpanan lokal berhasil. Sinkronisasi cloud memakai antrean
   inspeksi yang sudah tersedia; perangkat lain dengan akun sama menerima pembaruan.
6. Ketuk pin untuk membuka detail dari UUID inspeksi yang dipilih.

Scan dari navigasi utama juga memakai alur kamera dan GPS otomatis yang sama.
Pilihan titik hanya menjadi koreksi opsional setelah foto. Jika koordinat awal
belum ada, peta koreksi mewajibkan ketukan/geseran sebelum titik dapat dikonfirmasi;
pusat peta bawaan tidak otomatis dianggap lokasi pohon.

## Ketentuan data

- Saat Peta dibuka, aplikasi memeriksa GPS dan meminta izin lokasi bila diperlukan.
  Posisi perangkat saat ini diprioritaskan untuk pemusatan awal, dengan batas
  pencarian GPS 10 detik setelah izin selesai. Posisi ini tidak disimpan sebagai inspeksi.
- Jika pengguna sudah menggeser peta atau memilih fokus lain, hasil GPS terlambat
  hanya memperbarui penanda pengguna, tanpa memindahkan tampilan.
- Jika GPS gagal/izin ditolak, tampilkan petunjuk mencoba **Lokasi saya**; pusatkan
  ke titik inspeksi jika tersedia. Tanpa keduanya, tampilkan gambaran Indonesia,
  bukan titik ITS atau posisi pengguna rekaan.
- Tombol **Lokasi saya** meminta posisi terbaru setiap ditekan; tidak ada
  pelacakan lokasi terus-menerus. Data inspeksi baru tidak menarik kembali peta
  yang sudah difokuskan atau digeser pengguna.

- Satu pin mewakili satu inspeksi, bukan inventaris unik satu pohon.
- UUID menentukan identitas; kode tampilan yang sama tidak menggabungkan inspeksi.
- Latitude/longitude harus lengkap, finite, dan dalam rentang geografis yang valid.
  Data tanpa lokasi tetap tersimpan dan dapat dibuka melalui daftar belum dipetakan.
- Filter risiko, rayon, dan pencarian diterapkan pada snapshot yang sama.
  Bentuk nama rayon seperti `Rayon 3` dan `Rayon 3 — Sukolilo` disamakan.
- Pilihan rayon berasal dari data, termasuk Rayon 7 jika tersedia. Tidak ada asumsi
  pembagian wilayah atau koordinat pusat rayon baru.
- Seleksi mengikuti data terbaru dan tidak menampilkan objek yang sudah hilang.
  Filter, seleksi, dan sumber data direset saat akun berganti.
- Status memuat, kegagalan baca lokal, kegagalan cloud, data kosong, hasil filter
  kosong, dan data yang menunggu sinkron ditampilkan sesuai keadaan.
- Pin tetap tersedia dari cache lokal. Tampilan dasar peta berasal dari penyedia
  tile online; tidak ada fitur unduh peta offline pada perubahan ini.

## Batas cakupan

Migration `202610170001_inspections.sql` yang sudah diterapkan tetap dipakai.
Tidak ada migration baru atau perubahan akses database. Data cloud masih milik
akun yang sedang masuk; akses koordinator lintas petugas belum ditambahkan.
Data lama yang hanya berada dalam tabel `trees` tidak diimpor otomatis.

Sorotan risiko tinggi/kritis adalah efek visual pada pin, bukan radius rebahan.
Analisis PostGIS, zona fasilitas publik, riwayat berkelompok per pohon, weather alert,
dan work order masih merupakan pekerjaan lanjutan.

## Pemeriksaan

- `flutter analyze --no-pub`
- `flutter test --no-pub test/map_data_flow_test.dart test/inspection_sync_test.dart`
- `flutter test --no-pub test/map_location_test.dart test/scan_location_test.dart`

Test peta mencakup GPS tidak valid, rayon, kode kembar, simpan offline, pembaruan
realtime, pergantian akun, kegagalan baca, konfirmasi titik, serta pencarian dan
navigasi detail pada layar kecil. Tile dalam test disediakan dari memori.
Alur kamera/GPS fisik dan sinkronisasi dua perangkat perlu dicoba pada perangkat.
