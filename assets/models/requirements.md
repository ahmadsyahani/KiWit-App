# AI Model Integration & Logic Specifications (Flutter Handoff)

Dokumen ini berisi spesifikasi teknis dan panduan implementasi untuk integrasi model AI (Segmentasi YOLO11) ke dalam aplikasi Flutter. 

## 1. Spesifikasi Model AI
* **File Model:** `assets/models/best.onnx`
* **Ukuran File:** ~11.1 MB (Telah dioptimasi menggunakan `onnxslim` untuk *mobile*)
* **Mesin Eksekusi:** Diwajibkan menggunakan package `onnxruntime` di Flutter.
* **Format Input:** Gambar dari kamera/galeri **WAJIB** di-*resize* ke ukuran tepat **640x640 piksel** (Format warna RGB) sebelum dimasukkan ke dalam model.

## 2. Indeks Kelas (Label)
Output dari model mendeteksi 2 kelas. Pastikan pemetaan indeks (ID) di kode Flutter sesuai dengan urutan berikut:
* `0` = `healthy bark` (Kulit kayu sehat — *Abaikan area ini dalam perhitungan persentase kerusakan*)
* `1` = `cacat_kulit` (Luka/cacat pada batang — *Gunakan poligon dari kelas ini untuk menghitung area kerusakan*)

## 3. Alur Pemrosesan Logika (Post-Processing)

### Tahap 1: Ekstraksi Data (AI ke Angka)
Dari titik koordinat poligon (*bounding mask*) yang dihasilkan oleh ONNX, sistem Flutter harus menghitung luas area menggunakan algoritma *Pixel Area Calculation*.
* **Rumus:** 
  `Persentase Luka = (Total Area Piksel Cacat / Total Area Piksel Batang) * 100`

### Tahap 2: Matriks ISA TRAQ (Penentu Status Risiko)
Aplikasi membutuhkan dua variabel untuk menentukan Status Bahaya Pohon akhir.

**Variabel A: Potensi Kegagalan (Otomatis dari Output AI & Input DBH)**
Evaluasi nilai `Persentase Luka` dan `DBH` (Diameter at Breast Height dalam cm) menggunakan aturan *if-else* berikut:
* `if (Persentase Luka < 10%)` ➔ **Improbable** (Kecil kemungkinan patah)
* `if (Persentase Luka >= 10% && Persentase Luka <= 30%)` ➔ **Possible** (Mungkin patah)
* `if (Persentase Luka > 30% || DBH < 30 cm)` ➔ **Probable** (Pohon kecil dengan luka sedang = Sangat mungkin patah)
* `if (Persentase Luka > 50%)` ➔ **Imminent** (Pasti akan patah/tumbang)

**Variabel B: Dampak Lingkungan (Input Manual Pengguna dari UI)**
Sediakan *dropdown* atau *radio button* di halaman inspeksi dengan bobot nilai berikut:
* **Low**: Lahan kosong / Hutan lebat
* **Medium**: Taman / Area jarang dilewati orang
* **High**: Jalan raya ramai / Dekat bangunan atau fasilitas umum

### Tahap 3: Keputusan Akhir (Vonis Laporan)
Gabungkan Variabel A dan B untuk memunculkan peringatan warna dan teks di UI aplikasi (Berdasarkan Matriks Risiko ISA TRAQ standar):
* Jika **Improbable** + **Low** ➔ Tampilkan UI **Hijau**: `RISIKO RENDAH (Aman)`
* Jika **Possible** + **Medium** ➔ Tampilkan UI **Kuning**: `RISIKO SEDANG (Perlu Dipantau)`
* Jika **Probable** + **High** ➔ Tampilkan UI **Oranye**: `RISIKO TINGGI (Tindak Lanjuti)`
* Jika **Imminent** + **High** ➔ Tampilkan UI **Merah**: `RISIKO EKSTREM (Tebang Segera!)`