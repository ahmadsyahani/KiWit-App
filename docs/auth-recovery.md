# Pemulihan password KiWit (Android)

## Konfigurasi Supabase yang diperlukan

Pada project Supabase KiWit, buka **Authentication → URL Configuration → Redirect URLs**.
Tambahkan alamat berikut dan simpan:

Alamat `redirectTo` harus terdaftar pada allowlist
([dokumentasi Supabase](https://supabase.com/docs/guides/auth/redirect-urls)).

```text
kiwit://auth/recovery
```

Kode Android sudah mendaftarkan scheme, host, dan path yang sama. Email recovery
memakai `redirectTo` ini. SDK Supabase Flutter menangani verifikasi token / pertukaran
kode PKCE; aplikasi menampilkan form hanya setelah event `passwordRecovery` diterima.
Form tetap aktif ketika event `userUpdated` atau refresh token diterima.

Jangan menganggap alur email sudah teruji hanya karena test lokal lulus. Pengaturan
allowlist dan pengiriman email pada project Supabase harus diuji dengan akun nyata.

## Uji pada HP

1. Pasang ulang build Android yang memuat manifest baru. Hot reload / hot restart
   tidak memperbarui intent filter pada APK yang sudah terpasang.
2. Pilih **Lupa kata sandi**, masukkan email akun yang terdaftar.
3. Buka tautan email pada HP dan instalasi aplikasi yang sama dengan yang meminta
   tautan. PKCE membutuhkan verifier lokal; tautan dari perangkat lain dapat gagal.
4. KiWit harus menampilkan **Atur ulang kata sandi**, termasuk ketika halaman login
   atau dialog pengiriman email sebelumnya masih terbuka.
5. Coba konfirmasi berbeda, lalu simpan kata sandi baru yang valid.
6. Setelah berhasil, tekan **Oke, masuk kembali**. Aplikasi mengakhiri sesi
   pemulihan dan kembali ke halaman masuk. Pastikan kata sandi baru bisa dipakai,
   sedangkan kata sandi lama tidak bisa. Jika logout gagal, pesan berhasil tetap
   tampil bersama informasi untuk mencoba mengakhiri sesi lagi; aplikasi tidak
   membuka dashboard sebagai pengganti login ulang.
7. Coba tautan kedaluwarsa / sudah dipakai: pemulihan tidak boleh dilaporkan berhasil.
   Minta tautan baru bila diperlukan.

Test regresi menggunakan server HTTP loopback dan stream event buatan. Tidak ada
email yang dikirim dan tidak ada akun Supabase asli yang diubah selama test.

## Email pemulihan

Gunakan template reset password bawaan Supabase. Kustomisasi tampilan email
tidak diperlukan untuk alur pemulihan di aplikasi ini.
