# Identitas Android KiWit

- Nama aplikasi pada launcher: **KiWit** (`android:label` di manifest).
- Logo menggunakan gambar pengguna **KiWit v2.png**; bentuk dan tulisan asli
  dipertahankan, dengan margin luar disesuaikan untuk ukuran ikon.
- Ikon `ic_kiwit` tersedia pada mdpi, hdpi, xhdpi, xxhdpi, dan xxxhdpi.
  Android 8+ memakai adaptive icon, dengan seluruh logo berada di area aman.
- Gambar sumber disalin ke `assets/branding/kiwit-logo-original.png` saat
  generator dijalankan; berkas di Downloads tidak diubah.
- Pratinjau ikon: `assets/branding/kiwit-launcher-preview.png`.

Untuk membuat ulang ikon dari gambar sumber pada Windows:

```powershell
.\tool\generate_android_icons.ps1 -SourcePath 'C:\path\KiWit v2.png'
```

Untuk build release sekaligus menyalin hasil menjadi **KiWit.apk**:

```powershell
.\tool\build_kiwit_apk.ps1
```

Hasil: `build/app/outputs/flutter-apk/KiWit.apk`. Script menggunakan konfigurasi
signing release yang ada di project. Nama paket Dart dan application ID Android
tidak perlu diubah untuk mengganti nama aplikasi pada launcher.

Perubahan ikon dan nama launcher perlu build/install ulang; hot reload dan hot
restart Flutter tidak memperbarui resource launcher pada aplikasi terpasang.
