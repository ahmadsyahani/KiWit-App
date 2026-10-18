# Alur kamera dan scan

## Perubahan

- Kamera belakang, tanpa audio, flash dimatikan bila didukung perangkat.
- Inspeksi baru langsung membuka kamera, termasuk dari Peta. Izin kamera diminta
  sebelum izin lokasi, lalu GPS dicari otomatis. Tidak ada konfirmasi titik sebelum foto.
- Kamera dibuka/ditutup/diambil fotonya melalui antrean agar operasi native tidak bertabrakan.
- Kamera dilepas saat app tidak aktif, dibuka kembali saat aktif. Hasil dari operasi sebelum jeda/penutupan diabaikan.
- Satu pengambilan foto dan analisis pada satu waktu. Setelah kegagalan atau objek tidak dikenali, pengguna dapat mencoba lagi.
- Decode foto, koreksi orientasi EXIF, persiapan input, eksekusi model, dan perhitungan mask berjalan di isolate terpisah.
- Worker memuat sesi model per foto dan melepaskan tensor, opsi, sesi, serta environment. Ini dapat menambah waktu tunggu per foto; UI tetap dapat merespons.
- Model asset dimuat saat persiapan. Keberhasilan inisialisasi runtime native baru diketahui saat worker menganalisis foto pertama; bila gagal tidak dibuat hasil pengganti.
- Waktu foto dibekukan saat tombol ditekan. Lokasi yang sudah siap dipertahankan.
  Jika belum siap, hasil memakai pencarian GPS yang selesai selama analisis atau
  maksimal 10 detik tambahan sesudah analisis. Jika tetap gagal, koordinat tidak direkayasa.
- Reverse geocoding dibatasi dua detik total agar internet lambat tidak menahan
  koordinat GPS yang sudah didapat.
- Hasil menyediakan Ubah lokasi/Lengkapi lokasi: coba GPS lagi atau pilih di peta.
  Pilihan titik peta merupakan koreksi opsional setelah foto, bukan langkah wajib.
- ID inspeksi menggunakan UUID. Header hasil menampilkan delapan karakter pertama untuk menghindari overflow.
- Foto Ulang membawa koordinat dan alamat hasil saat ini. Tombol kembali di halaman hasil keluar ke halaman asal.
- Tombol sampel sintetis dan status teknis model di kamera dihapus.

## Temuan model dan batas pemeriksaan

Metadata file best.onnx yang ada menyebut YOLO11n-seg, input 640x640, tiga kelas:
0 = Rough bark, 1 = healthy bark, 2 = stripecanker.
Ini berbeda dari dokumen assets/models/requirements.md yang menyebut dua kelas.
Pemetaan tiga kelas di layanan dipertahankan mengikuti asset sebenarnya.

Model tersebut mengklasifikasikan/menyegmentasi kulit batang; bukan pengenal jenis pohon.
Hasil baru memakai "Belum ditentukan", agar pengguna memilih jenis pohon secara manual.

Implementasi lama mengestimasi DBH dari lebar bounding box dengan faktor tetap,
serta menghitung sudut dari confidence kelas. Keduanya belum merupakan pengukuran
fisik yang terkalibrasi. Rumus ini belum diganti dalam perbaikan alur kamera;
halaman hasil menandai estimasi dan menyediakan koreksi DBH.
Status jamur dari confidence juga belum merupakan konfirmasi penyakit.
Persentase luka hanya dihitung jika mask batang lolos validasi. Fallback rasio
confidence saat mask kosong sudah dihapus. Akurasi, ambang penolakan objek,
rumus risiko, dan kesesuaian pada spesies lapangan perlu evaluasi dataset tersendiri.

## Validasi objek sebelum hasil dibuat

- Keluaran harus memiliki 39 kanal deteksi dan prototype mask 32 x 160 x 160.
- Kandidat memerlukan confidence minimal 0,70 dan bounding box terlihat minimal
  4% dari gambar input. Geometri/skor tidak valid ditolak.
- Anchor berulang pada kelas yang sama disaring dengan NMS (IoU > 0,5).
- Setiap kandidat harus memiliki mask minimal 3% gambar (768 piksel pada grid
  160 x 160), serta minimal 20% area bounding box. Mask kosong/tipis ditolak.
- Hanya kandidat yang lolos mask boleh memengaruhi kondisi dan risiko.
- Jika tidak lolos, kamera tetap terbuka dengan arahan foto ulang; tidak dibuat
  InspectionResultData, halaman hasil, maupun laporan baru.

Ambang ini konservatif dan belum dikalibrasi dengan kumpulan foto lapangan.
Model kulit batang tetap dapat salah mengenali tekstur benda lain dengan skor
tinggi. Ini bukan validator semua jenis tanaman: daun/rumput saja belum cukup
untuk analisis kondisi batang. Untuk penolakan objek asing yang lebih andal,
perlu model pohon/nonpohon terpisah atau pelatihan ulang dengan contoh negatif
(kain, dinding, manusia, layar, tanah, dll.), beserta pengukuran false acceptance
dan false rejection. Validasi ini berjalan di aplikasi, bukan moderasi server;
klien yang dimodifikasi masih dapat melewatinya.

## Pemeriksaan otomatis

test/scan_flow_test.dart menggunakan adapter kamera dan analisis palsu:
persiapan/izin gagal dan retry, shutter ganda, capture gagal, analisis gagal,
foto tidak dikenali, koordinat pilihan peta, waktu/UUID, GPS tidak tersedia,
jeda saat inisialisasi/capture/analisis, buka ulang dan pencegahan hasil terlambat,
serta interaksi UI pada layar pendek.
test/isa_traq_test.dart memeriksa aturan matriks yang sudah ada.
test/scan_object_validation_test.dart memeriksa post-processing asli memakai
tensor sintetis: skor lemah, mask kosong/tipis, box kecil/tidak valid, data rusak,
batang sehat/cacat, serta anchor berulang. Tidak membuktikan akurasi semantik foto.

Test tidak mengakses sensor kamera, izin Android nyata, GPS nyata, atau runtime
ONNX Android. Kelulusan test bukan bukti akurasi model atau kinerja perangkat.

## Coba di HP

1. Hot restart (R di terminal Flutter) setelah perubahan struktur ini.
2. Buka kamera: coba izin ditolak lalu aktifkan, pastikan tombol foto hanya aktif setelah siap.
3. Foto batang pohon terang/fokus, coba ketuk cepat dua kali, lalu ulangi foto.
4. Coba objek lain dan foto gelap; hasil seharusnya dapat ditolak, tetapi ambang model belum tervalidasi.
5. Saat membuka kamera/memproses, tekan Home lalu kembali. Tutup kamera saat analisis dan pastikan hasil tidak muncul terlambat.
6. Mulai dari Peta dan pastikan langsung masuk kamera. Sesudah foto, koreksi titik
   bila perlu, lalu Foto Ulang; koordinat yang dikoreksi harus tetap sama.
7. Nonaktifkan GPS/internet: foto tetap bisa diproses lokal; lokasi kosong perlu diperbaiki di hasil, dan penyimpanan/sinkron mengikuti alur inspeksi yang sudah ada.
