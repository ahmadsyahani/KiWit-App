# Audit kode KiWit · 23 November 2026

## Cakupan

Inventaris file Dart di `lib/` dan suite di `test/`. Peninjauan manual
difokuskan pada alur penyimpanan, sinkronisasi, refresh layar, serta jalur
autentikasi, pemindaian dan laporan yang terkait. Perubahan dibatasi pada
penyimpanan inspeksi dan pemanggil refresh.

## Temuan dan tindakan

1. **Versi penyimpanan tidak didukung bisa mengganti file aktif.** Saat
   membaca versi numerik selain versi 1, pemulihan lama membuat cadangan,
   lalu menulis daftar kosong dengan skema versi 1. Ini bisa mengeluarkan
   inspeksi yang belum tersinkron dari penyimpanan aktif. Pemulihan kini
   memeriksa versi dari byte file asli dan berhenti sebelum penulisan.
   Untuk JSON rusak dan record versi 1, pemulihan tetap membuat cadangan
   dan menyelamatkan record yang masih terbaca.
2. **Empat alur refresh mengulang penanganan error.** Home, Peta, Profil dan
   alur notifikasi memakai `refreshInspections` dari provider inspeksi.
   Saat feed sudah error, fungsi meminta Riverpod membuat ulang controller.
   Laporan memiliki perilaku tersendiri yang menunggu percobaan refresh
   setelah invalidasi. Susunan layar dan label tetap sama.
3. **Status error sinkronisasi disalin dua kali.** `InspectionFeed` sudah
   membuat snapshot map yang tidak dapat diubah. Controller sekarang
   meneruskan map sumber langsung ke konstruktor.
4. **Tes Peta mengasumsikan nama pohon muncul sekali.** Detail yang
   sekarang menampilkan nama di judul foto dan ringkasan spesies. Tes
   memverifikasi ID inspeksi yang dibuka, nama di dalam layar detail,
   dan alamat setelah layar digulir.

## Bagian panjang yang ditinjau

`inspection_result_screen.dart` dan `onnx_service.dart` merupakan dua
file terpanjang. Yang pertama memuat form, dialog dan tampilan hasil. Yang
kedua memuat evaluasi risiko dan pemrosesan keluaran model. Panjangnya
sendiri belum menunjukkan duplikasi yang bisa dihapus tanpa menambah
perantara atau memperluas perubahan.

## Verifikasi

- `flutter analyze --no-pub` selesai dengan `No issues found!`. Saat
  pemeriksaan versi SDK, Git Flutter sempat melaporkan objek commit yang
  hilang. Analisis proyek tetap berjalan sampai selesai.
- Suite awal menghasilkan 157 lulus dan satu assertion Peta gagal.
  Setelah assertion disesuaikan, `flutter test --no-pub` lulus 158 tes.
- `git diff --check` lulus.
- Skenario regresi di `test/inspection_recovery_test.dart` memeriksa file
  versi 2 tetap identik, feed masuk status error, dan cloud tidak di-fetch.
- Kamera dan GPS Android, inferensi ONNX native, serta Supabase langsung
  berada di luar cakupan pengujian host.
