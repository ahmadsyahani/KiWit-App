<div align="center">

<img src="assets/branding/kiwit-launcher-preview.png" alt="Logo KiWit" width="160" />

# KiWit

### Rawat pohon kota, mulai dari satu inspeksi.

Aplikasi pendamping inspeksi pohon untuk petugas lapangan.<br />
Ambil foto, catat kondisi, dan pantau hasilnya melalui peta serta laporan.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-154D38?style=flat-square&logo=supabase&logoColor=white)
![ONNX Runtime](https://img.shields.io/badge/YOLO11-ONNX_Runtime-336B46?style=flat-square)
![Status](https://img.shields.io/badge/Status-Prototipe_demo-E8F0E9?style=flat-square&labelColor=104C3B)

[Tentang](#tentang-kiwit) · [Fitur](#fitur-utama) · [Mulai](#menjalankan-project) · [Tim](#tim-pengembang) · [Dokumentasi](#dokumentasi)

</div>

---

## Tentang KiWit

KiWit membantu petugas mencatat inspeksi pohon secara terstruktur, dari pengambilan foto di lapangan sampai peninjauan riwayat. Dirancang untuk konteks inspeksi pohon perkotaan di Surabaya, aplikasi ini menghubungkan hasil scan, lokasi, catatan petugas, dan status sinkronisasi dalam satu alur.

Hasil inspeksi disimpan di perangkat terlebih dahulu. Saat koneksi tersedia, data dan foto disinkronkan ke Supabase agar dapat diakses dari perangkat lain dengan akun yang sama.

> **Tahap pengembangan:** prototipe untuk demo dan evaluasi lapangan. Analisis otomatis membantu pencatatan awal; hasilnya tetap perlu ditinjau oleh petugas.

## Fitur utama

| Fitur | Yang bisa dilakukan |
| :--- | :--- |
| **Akun petugas** | Daftar, masuk, pulihkan kata sandi, dan kelola profil serta rayon penugasan. |
| **Inspeksi kamera** | Ambil foto kulit batang dan proses segmentasi dengan YOLO11 melalui ONNX Runtime. Foto dengan bukti deteksi yang tidak memadai diminta diulang. |
| **Lokasi otomatis** | Cari GPS saat inspeksi; koreksi alamat atau titik peta setelah foto jika diperlukan. |
| **Home** | Lihat ringkasan, tren tujuh hari, dan inspeksi terbaru dari data tersimpan. |
| **Peta inspeksi** | Mulai dari posisi perangkat, telusuri inspeksi, dan filter menurut risiko atau rayon. Tersedia tampilan standar, satelit, dan topografi. |
| **Laporan** | Pilih bulan berjalan, bulan/tahun tertentu, satu tahun penuh, atau semua waktu. Saring daftar menurut risiko, kata kunci, dan status sinkronisasi. |
| **Detail inspeksi** | Baca foto, kondisi, risiko, lokasi, identitas petugas, dan catatan. |
| **Notifikasi aplikasi** | Tinjau pemberitahuan risiko tinggi/kritis dan masalah sinkronisasi dari lonceng Home. |
| **Penyimpanan & sinkronisasi** | Simpan hasil lokal sebelum unggah, coba kembali unggahan tertunda, dan terima pembaruan Supabase Realtime. |

### Dari lapangan ke laporan

```mermaid
flowchart TB
    %% ==================== TAHAP 1 ====================
    subgraph Tahap1 ["Tahap 1 — Pemindaian visual di lapangan"]
        direction LR
        T1_A("<b>Petugas tiba di lokasi pohon</b><br/><small>7 rayon operasional DLH Surabaya</small>")
        T1_B("<b>Buka Flutter App</b><br/><small>Kamera minimal 12 MP + GPS aktif</small>")
        T1_A --> T1_B
    end

    %% ==================== TAHAP 2 ====================
    subgraph Tahap2 ["Tahap 2 — Inferensi Edge AI offline (ONNX Runtime Mobile)"]
        direction LR
        T2_A("<b>YOLOv11-seg</b><br/><small>Deteksi cacat: rongga,<br/>jamur, dahan menggantung</small>")
        T2_B("<b>Mask R-CNN</b><br/><small>Estimasi DBH<br/>Ukur sudut θ batang</small>")
        T2_C("<b>Mesin TRAQ</b><br/><small>Matriks ISA-TRAQ<br/>Hitung skor risiko awal</small>")
        T2_A --> T2_B --> T2_C
    end

    %% ==================== PERCABANGAN ====================
    subgraph Keputusan ["Evaluasi Hasil Inferensi"]
        direction LR
        AMAN("<b>Status aman</b><br/><small>Catat ke log</small>")
        CACAT{"<b>Cacat<br/>terdeteksi?</b>"}
        RISIKO("<b>Skor risiko</b><br/><small>Rendah–Ekstrem</small>")
        
        CACAT -- "Tidak" --> AMAN
        CACAT -- "Ya" --> RISIKO
    end

    %% ==================== TAHAP 3 ====================
    subgraph Tahap3 ["Tahap 3 — Sinkronisasi spasial ke Supabase"]
        direction LR
        T3_A("<b>Upload data</b><br/><small>Koordinat GPS + foto<br/>+ spesies + skor risiko</small>")
        T3_B("<b>PostGIS kalkulasi</b><br/><small>ST_DWithin radius rebahan<br/>Geofencing zona bahaya</small>")
        T3_C("<b>Klasifikasi final</b><br/><small>Rendah / Sedang /<br/>Tinggi / Ekstrem</small>")
        T3_A --> T3_B --> T3_C
    end

    %% ==================== TAHAP 4 ====================
    subgraph Tahap4 ["Tahap 4 — Visualisasi peta & respons taktis dalam aplikasi"]
        direction LR
        T4_A("<b>flutter_map</b><br/><small>Pin merah/kuning/hijau<br/>Peta risiko pohon</small>")
        T4_B("<b>Push notification</b><br/><small>Weather alert cuaca ekstrem<br/>via Open-Meteo API</small>")
        T4_C("<b>Work order digital</b><br/><small>Penugasan armada perantingan<br/>ke rayon terdekat</small>")
        T4_A --> T4_B --> T4_C
    end

    %% ==================== INTEGRASI EKSTERNAL ====================
    WARGA("<b>Laporan warga via Wargaku / SSW Alfa</b><br/><small>Foto → validasi AI Supabase Edge Fn → work order otomatis</small>")

    %% ==================== RELASI ANTAR TAHAP ====================
    Tahap1 --> Tahap2
    T2_B --> CACAT
    CACAT --> Tahap3
    T3_B --> Tahap4
    WARGA -. "Integrasi API dua arah" .-> T4_A

    %% ==================== STYLING WARNA ====================
    classDef stage1 fill:#e0f5ed,stroke:#6eb89f,stroke-width:1.5px,color:#0d5c46;
    classDef stage2 fill:#eeedfc,stroke:#8e8cd8,stroke-width:1.5px,color:#312e81;
    classDef safeNode fill:#e4f4d9,stroke:#7ab85c,stroke-width:1.5px,color:#2d5a18;
    classDef riskNode fill:#fae5e5,stroke:#c97a7e,stroke-width:1.5px,color:#7f1d1d;
    classDef decisionNode fill:#ffffff,stroke:#b0b0b0,stroke-width:1.5px,color:#1f2937;
    classDef stage3 fill:#fcede4,stroke:#d49573,stroke-width:1.5px,color:#7c2d12;
    classDef stage4 fill:#e5f2fc,stroke:#6ba5d8,stroke-width:1.5px,color:#1e3a8a;
    classDef citizenNode fill:#faeedb,stroke:#c89e63,stroke-width:1.5px,color:#653700;
    classDef subgraphStyle fill:transparent,stroke:#d1d5db,stroke-width:1px,stroke-dasharray: 4 4,color:#4b5563;

    class T1_A,T1_B stage1;
    class T2_A,T2_B,T2_C stage2;
    class AMAN safeNode;
    class RISIKO riskNode;
    class CACAT decisionNode;
    class T3_A,T3_B,T3_C stage3;
    class T4_A,T4_B,T4_C stage4;
    class WARGA citizenNode;
    class Tahap1,Tahap2,Keputusan,Tahap3,Tahap4 subgraphStyle;
```

Inspeksi tanpa koordinat valid tetap tersimpan dalam daftar, tetapi belum ditampilkan sebagai titik pada peta.

## Teknologi

| Bagian | Teknologi |
| :--- | :--- |
| Aplikasi | Flutter, Dart, Material 3 |
| State | Riverpod |
| Backend | Supabase Auth, PostgreSQL, Storage privat, Realtime |
| Analisis foto | YOLO11 segmentation, ONNX Runtime, Image Processing |
| Peta & GPS | Flutter Map, Geolocator, OpenStreetMap, Esri, OpenTopoMap |
| Perangkat | Camera, Permission Handler |
| Grafik | FL Chart |

## Menjalankan project

### Prasyarat

- Flutter dengan Dart **`>=3.12.2 <4.0.0`**, sesuai `pubspec.yaml`.
- Android SDK yang mendukung **compile SDK 37** dan JDK **17**.
- Perangkat Android **7.0 / API 24** atau lebih baru.
- Project Supabase untuk autentikasi dan sinkronisasi.

### 1. Ambil source code

```bash
git clone https://github.com/ahmadsyahani/KiWit-App.git
cd KiWit-App
flutter pub get
```

### 2. Siapkan konfigurasi

Salin `.env.example` menjadi `.env`. Pada PowerShell:

```powershell
Copy-Item .env.example .env
```

Isi konfigurasi Supabase:

```dotenv
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

Gunakan key klien Supabase, bukan `service_role` atau secret key server. File `.env` diabaikan oleh Git. Karena didaftarkan sebagai aset Flutter, file ini tetap harus tersedia saat aplikasi dibuild.

### 3. Siapkan Supabase

1. Aktifkan autentikasi email/password pada project Supabase.
2. Buka **SQL Editor** dan jalankan [migration inspeksi](supabase/migrations/202610170001_inspections.sql).
3. Migration menyiapkan tabel `inspections`, kebijakan akses per akun, bucket foto privat `kiwit-inspection-photos`, dan publication Realtime.
4. Sesuaikan konfirmasi email dan URL pemulihan kata sandi dengan lingkungan pengujian.

Profil dapat memakai metadata akun Auth. Tabel `profiles`, jika tersedia pada backend, dipakai untuk sinkronisasi profil; migration inspeksi tidak membuat tabel tersebut.

Panduan lengkap: [setup dan sinkronisasi inspeksi](docs/inspection-sync.md).

### 4. Jalankan di perangkat

```bash
flutter devices
flutter run --no-enable-impeller
```

Izinkan kamera dan lokasi saat diminta. Pada terminal Flutter, tekan `r` untuk hot reload dan `R` untuk hot restart. Perubahan ikon, nama aplikasi, atau konfigurasi Android memerlukan build dan instalasi ulang.

## Membuat APK

Pada Windows, script berikut membuat build release dan menyalin hasilnya menjadi **`KiWit.apk`**:

```powershell
.\tool\build_kiwit_apk.ps1
```

Jika eksekusi script dibatasi PowerShell, jalankan khusus untuk proses tersebut:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_kiwit_apk.ps1
```

Hasil:

```text
build/app/outputs/flutter-apk/KiWit.apk
```

Alternatif build Flutter biasa:

```bash
flutter build apk --release
```

Perintah biasa menghasilkan `app-release.apk`. Konfigurasi release saat ini masih memakai debug signing; siapkan keystore release sebelum distribusi produksi. Keberhasilan build release dan perilaku APK tetap perlu diperiksa di perangkat tujuan.

## Struktur project

```text
lib/
├── core/                 # Tema, konfigurasi, layanan, dan komponen bersama
└── features/
    ├── auth/             # Login, register, dan pemulihan akun
    ├── home/             # Ringkasan dan tren inspeksi
    ├── map/              # Titik inspeksi, pencarian, dan lokasi perangkat
    ├── notifications/    # Kotak notifikasi dalam aplikasi
    ├── profile/          # Profil petugas
    ├── report/           # Filter periode dan daftar laporan
    └── scan/             # Kamera, analisis, penyimpanan, dan sinkronisasi
assets/
├── branding/             # Logo KiWit
└── models/               # Model ONNX
supabase/migrations/      # Skema dan kebijakan data inspeksi
test/                     # Test logika dan widget
tool/                     # Generator ikon dan script build APK
docs/                     # Catatan alur dan batas implementasi
```

## Pemeriksaan

```bash
flutter analyze --no-pub
flutter test --no-pub
```

Test mencakup alur kamera dan lokasi, validasi output model, sinkronisasi, isolasi akun, peta, laporan, notifikasi, detail inspeksi, dan tampilan auth. Sebagian pemeriksaan memakai adapter atau data simulasi; kelulusannya belum membuktikan akurasi model atau keberhasilan sensor pada perangkat fisik.

### Batas prototipe

- Model berfokus pada **kulit batang**, bukan semua jenis tanaman atau identifikasi spesies. Benda dengan tekstur mirip batang masih dapat salah dikenali.
- Diameter dan kemiringan otomatis masih **estimasi yang belum terkalibrasi**. Indikasi penyakit serta kategori risiko memerlukan peninjauan lapangan.
- Sinkronisasi berlaku untuk **akun yang sama**. Dashboard lintas petugas/rayon belum tersedia.
- Notifikasi berada **di dalam aplikasi**; status baca disimpan lokal per akun/perangkat. Push notification sistem belum tersedia.
- Tampilan dasar peta dan penerjemahan koordinat menjadi alamat memerlukan koneksi. Penyimpanan inspeksi lokal tetap tersedia saat koneksi terputus.

## Tim pengembang

| Anggota | GitHub |
| :--- | :--- |
| **Ahmad Syahani** | [@ahmadsyahani](https://github.com/ahmadsyahani) |
| **Lugas Madya Hanestyan** | [@garyeggsy](https://github.com/garyeggsy) |
| **Daffa Rahman Budi Santoso** | [@damanbs](https://github.com/damanbs) |

## Dokumentasi

| Panduan | Isi |
| :--- | :--- |
| [Kamera dan scan](docs/scan-flow.md) | Pengambilan foto, validasi objek, dan batas model. |
| [Penyimpanan dan sinkronisasi](docs/inspection-sync.md) | Setup Supabase, penyimpanan lokal, dan akses antarperangkat. |
| [Peta inspeksi](docs/map-data-flow.md) | Lokasi perangkat, marker, filter, dan inspeksi tanpa koordinat. |
| [Laporan](docs/report-data-flow.md) | Periode bulan/tahun, ringkasan, dan pencarian. |
| [Notifikasi](docs/notifications.md) | Pemberitahuan risiko dan antrean sinkronisasi. |
| [Identitas Android](docs/android-branding.md) | Logo, ikon launcher, nama aplikasi, dan build APK. |

---

<div align="center">

**KiWit**<br />
Catat kondisinya. Kenali risikonya. Rawat pohonnya.

</div>
