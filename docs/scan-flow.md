# Alur kamera dan scan

## Perubahan

- Kamera belakang, tanpa audio, flash dimatikan bila didukung perangkat.
- Inspeksi baru langsung membuka kamera, termasuk dari Peta. Izin kamera diminta
  sebelum izin lokasi, lalu GPS dicari otomatis. Tidak ada konfirmasi titik sebelum foto.
- Kamera dibuka/ditutup/diambil fotonya melalui antrean agar operasi native tidak bertabrakan.
- Kamera dilepas saat app tidak aktif, dibuka kembali saat aktif. Hasil dari operasi sebelum jeda/penutupan diabaikan.
- Satu pengambilan foto dan analisis pada satu waktu. Kegagalan teknis dapat dicoba ulang; foto tanpa penilaian tetap masuk hasil dan bisa disimpan.
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
confidence saat mask kosong sudah dihapus. Akurasi, ambang ketersediaan penilaian,
rumus risiko, dan kesesuaian pada spesies lapangan perlu evaluasi dataset tersendiri.

## Analisis kondisi tanpa memblokir pengambilan foto

Validasi pohon/nonpohon sebagai gerbang kamera telah dihapus. Semua foto yang
berhasil dibaca dan diproses dapat dilanjutkan ke hasil dan disimpan. Confidence
dan mask hanya menentukan apakah penilaian kondisi tersedia, bukan apakah
pengguna boleh mencatat inspeksi. Model saat ini bukan pengenal objek umum.

- Keluaran harus memiliki 39 kanal deteksi dan prototype mask 32 x 160 x 160.
- Foto dikoreksi orientasinya lalu di-resize ke 640 x 640 dengan stretch,
  sesuai README dataset Roboflow v2 yang telah diunduh dan diperiksa.
  Letterbox sebelumnya adalah asumsi yang tidak cocok dengan preprocessing
  dataset; perbandingan tiga foto tercatat pada notebook-dataset-audit-2026-10-19.md.
  Letterbox masih tersedia eksplisit pada alat audit, bukan jalur kamera produksi.
- Kandidat memerlukan confidence minimal 0,70 dan bounding box terlihat minimal
  4% dari area foto tanpa padding. Geometri/skor tidak valid ditolak.
- Skor finite pada rentang [-0,000001, 1,000001] dinormalisasi ke [0,1]
  hanya untuk menyerap pembulatan float32 di batas probabilitas. Log Android
  mengonfirmasi -5,960464477539063e-8 pernah memicu SCAN-03 dan membatalkan
  seluruh scan sebelum kandidat lain diperiksa. Nilai di luar toleransi,
  NaN/Infinity tetap ditolak; confidence minimal tetap 0,70.
- Anchor berulang pada kelas yang sama disaring dengan NMS (IoU > 0,5).
- Setiap kandidat harus memiliki mask minimal 3% area foto tanpa padding (768
  piksel untuk foto persegi pada grid 160 x 160), serta minimal 20% area
  bounding box yang berada dalam foto. Mask kosong/tipis ditolak.
- Hanya kandidat yang lolos mask boleh memengaruhi kondisi dan risiko.
- Jika confidence atau mask tidak cukup, hasil memakai `hasAssessment: false`
  dan status `Belum dinilai`. Foto, UUID, waktu, lokasi dan catatan tetap bisa
  disimpan lokal/disinkronkan. Halaman hasil/detail tidak menampilkan diagnosis,
  skor kesehatan, pengukuran, atau risiko numerik pada status ini.
- Status netral ini juga dipakai pada Home, Peta dan Laporan. Filter risiko rendah
  tidak memasukkan catatan belum dinilai; Laporan memiliki filter Belum dinilai.
- Alasan confidence rendah, mask tidak cukup, dan output tidak kompatibel
  dipisahkan. Confidence rendah tidak ditampilkan sebagai kepastian bukan pohon.
  Debug build mencatat `[BarkScan]` berisi alasan penolakan, skor tertinggi,
  dan jumlah kandidat; keberhasilan mencatat jumlah piksel mask.

Kegagalan kontrak output juga membawa kode pendek ke UI pada release build.
Kode membantu melacak kegagalan teknis yang masih memerlukan perbaikan:

| Kode | Pemeriksaan gagal |
|---|---|
| SCAN-01 | Batas area input tidak valid |
| SCAN-02 | Tensor deteksi kosong, jumlah kanal/bentuk tidak sesuai |
| SCAN-03 | Skor kelas nonfinite atau di luar 0–1 |
| SCAN-04 | Bentuk prototype mask tidak sesuai |
| SCAN-05 | Perhitungan mask menghasilkan nilai nonfinite |
| SCAN-06 | Runtime tidak mengembalikan output |
| SCAN-00 | Kegagalan output tanpa kode lebih spesifik |

Debug build menambahkan bentuk output dan rincian pemeriksaan ke `[BarkScan]`.
Kode diagnosis terbawa melalui worker/isolate ke pesan kamera. Versi APK harus
dibuild dan dipasang ulang agar kode ini terlihat di perangkat.

Setelah input disesuaikan ke stretch, foto batang berlubang dari pengguna lolos
ambang penilaian pada audit Windows (0,816; sebelumnya letterbox 0,387). Ini
belum membuktikan diagnosis atau akurasi lapangan. Ambang confidence tidak
diturunkan tanpa evaluasi foto positif dan negatif. Foto layar
bukan pengganti evaluasi foto batang asli. Untuk APK yang sudah terpasang,
build dan instal ulang agar perubahan ini ikut digunakan.

Ambang ini konservatif dan belum dikalibrasi dengan kumpulan foto lapangan.
Model kulit batang tetap dapat salah mengenali tekstur benda lain dengan skor
tinggi. Ini bukan validator semua jenis tanaman: daun/rumput saja belum cukup
untuk analisis kondisi batang. Untuk penolakan objek asing yang lebih andal,
perlu model pohon/nonpohon terpisah atau pelatihan ulang dengan contoh negatif
(kain, dinding, manusia, layar, tanah, dll.), beserta pengukuran false acceptance
dan false rejection. Setelah blokir objek dihapus, benda selain pohon pun dapat
disimpan sebagai catatan. Sistem ini tidak melakukan moderasi server.

### Penyimpanan status belum dinilai

Flag `hasAssessment` disimpan di JSON/payload Supabase dan dipertahankan saat
copy, perubahan lokasi, antrean offline, serta sinkronisasi. Data lama tanpa
flag tetap dianggap memiliki penilaian. Tidak perlu perubahan skema Supabase:
`risk_status` berupa teks bebas dan payload berupa JSON. Untuk kompatibilitas
kolom numerik non-null, nilai 0 disimpan sebagai placeholder ketika flag false;
nilai tersebut bukan pengukuran/hasil analisis dan seluruh UI menyembunyikannya.
Query eksternal atas health_score perlu memeriksa flag payload tersebut.

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

### Koreksi hasil skrining (19 Oktober 2026)

- Input model dan ambang confidence tetap mengikuti audit sebelumnya; tidak ada
  pelatihan ulang atau kenaikan akurasi yang diklaim dari perubahan logika ini.
- Lebar kotak deteksi tidak lagi dikonversi menjadi cm. Confidence kelas tidak
  lagi dikonversi menjadi sudut. DBH dan kemiringan ditampilkan **Belum diukur**.
  DBH dapat dicatat dari pengukuran langsung secara opsional; tidak wajib agar
  analisis otomatis dan penyimpanan dapat berjalan.
- `hasMeasuredDiameter`, `hasMeasuredInclination`, `hasPathologyAssessment`
  menyimpan asal nilai dalam payload. Data lama tanpa flag tidak dianggap hasil
  pengukuran terverifikasi. Skema SQL tidak berubah.
- Rough bark adalah kelas tekstur. Hanya mask kelas canker-like yang menjadi
  pembilang area pola kerusakan; semua area kulit yang dikenali menjadi penyebut.
  Ini bukan ukuran kedalaman rongga atau proporsi kerusakan seluruh batang.
- Model tiga kelas ini tidak mengonfirmasi jamur. UI menampilkan **Tidak dinilai**,
  bukan Positif/Negatif dari confidence rough bark atau canker.
- Kategori otomatis merupakan heuristik prioritas pemeriksaan awal. Diameter
  tidak mengubah kategorinya. UI tidak lagi mengklaim hasil sebagai penilaian
  ISA TRAQ terverifikasi, kepastian Aman, atau perintah Tebang Segera.
- Hasil lama tetap tersimpan; label tindakan lama yang menyatakan Aman/Tebang
  ditampilkan sebagai saran pemantauan/pemeriksaan lapangan saat dibuka.

### Langkah pemeriksaan perangkat

1. Hot restart (R di terminal Flutter) setelah perubahan struktur ini.
2. Buka kamera: coba izin ditolak lalu aktifkan, pastikan tombol foto hanya aktif setelah siap.
3. Foto batang pohon terang/fokus, coba ketuk cepat dua kali, lalu ulangi foto.
4. Coba foto dengan analisis lemah: halaman hasil Belum dinilai harus terbuka dan bisa disimpan. Periksa bahwa Home/Peta/Laporan/detail tidak menampilkan risiko rendah atau angka pengukuran untuk catatan itu.
5. Saat membuka kamera/memproses, tekan Home lalu kembali. Tutup kamera saat analisis dan pastikan hasil tidak muncul terlambat.
6. Mulai dari Peta dan pastikan langsung masuk kamera. Sesudah foto, koreksi titik
   bila perlu, lalu Foto Ulang; koordinat yang dikoreksi harus tetap sama.
7. Nonaktifkan GPS/internet: foto tetap bisa diproses lokal; lokasi kosong perlu diperbaiki di hasil, dan penyimpanan/sinkron mengikuti alur inspeksi yang sudah ada.
