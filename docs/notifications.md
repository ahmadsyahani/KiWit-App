# Notifikasi inspeksi di aplikasi

## Sumber dan aturan

Lonceng Home membuka pusat notifikasi yang menggunakan inspectionControllerProvider,
sama seperti Home, Peta, dan Laporan. Tidak ada data contoh, tabel Supabase baru,
atau dependensi baru.

- Hasil risiko tinggi/kritis menghasilkan satu notifikasi per inspeksi dan tingkat risiko.
  Label risiko mengikuti normalisasi SavedInspection, termasuk Ekstrem/critical.
- Menekan item membuka SavedInspectionDetailScreen untuk ID record yang tepat.
- Pergantian tingkat risiko membuat item belum dibaca. Risiko yang sudah rendah/sedang
  dan inspeksi yang dihapus tidak lagi ditampilkan sebagai peringatan aktif.
- Sinkronisasi otomatis yang normal tidak menghasilkan notifikasi setiap penyimpanan.
- Kegagalan dengan inspeksi tertunda diringkas menjadi satu item, bukan satu per foto.
  Percobaan ulang tidak mengatur ulang status dibaca. Tambahan inspeksi tertunda
  membuat ringkasan kembali belum dibaca.
- Menekan item sinkronisasi membuka daftar inspeksi tertunda serta tombol sinkronkan.
- Jika semua record tertunda yang sebelumnya diberitahukan benar-benar tersedia dalam
  keadaan tersinkron, ringkasan tertunda diganti satu pemberitahuan berhasil.
  Penghapusan record tidak dianggap keberhasilan sinkronisasi.
- Sepuluh ringkasan keberhasilan terakhir dipertahankan. Peringatan risiko mengikuti data aktif.
- Kendala koneksi tanpa foto tertunda juga ditampilkan dan hilang saat pulih.

Notifikasi risiko menggunakan kalimat "Perlu pemeriksaan lanjutan", sesuai sifat
hasil analisis yang masih merupakan estimasi.

## Status dibaca dan akun

Badge hanya menghitung item belum dibaca. Membuka item menandainya dibaca;
membuka daftar saja tidak mengubah status semua item. Tombol Tandai semua dibaca
tersedia saat ada item belum dibaca.

Riwayat disimpan ke application documents:
notifications_v1/<ownerId>/inbox.json. Pembacaan memvalidasi identitas akun,
penulisan melalui file sementara, dan semua mutasi diserialkan.
Pergantian akun membuat controller baru dan memuat penyimpanan akun tersebut.
Data inspeksi dari pemilik lain juga diabaikan dalam pembentukan notifikasi.

Status dibaca dan riwayat keberhasilan bersifat lokal per akun/perangkat.
Data inspeksi tetap mengikuti sinkronisasi Supabase yang sudah ada; notifikasi
risikonya akan terbentuk dari data yang diterima perangkat tersebut.

Kegagalan penyimpanan ditampilkan di halaman notifikasi. Status dibaca tetap
berubah di memori, tetapi tidak diklaim sudah tersimpan. Tarik ke bawah mencoba
memperbarui data dan menyimpan ulang status.

## UI dan cakupan

Daftar memakai kelompok Hari ini dan Sebelumnya, waktu lokal, indikator belum
dibaca, serta warna berbeda untuk tinggi/kritis. Halaman menyediakan kondisi
kosong, loading, masalah sumber data, dan tarik untuk memperbarui.

Ini adalah pusat pemberitahuan di dalam aplikasi. Push notification di luar app,
jadwal inspeksi ulang, dan status tindak lanjut belum termasuk tahap ini.

## Pemeriksaan

test/notification_flow_test.dart mencakup pembentukan dari feed asli, deduplikasi,
restart/persistensi, pergantian akun, file JSON per akun, kegagalan disk, izin
penyimpanan baca, badge, tandai dibaca, navigasi detail, daftar tertunda,
sinkronisasi retry/berhasil, data kosong, dan layar sempit dengan teks besar.
Tidak mengirim push notification atau mengakses Supabase produksi.
