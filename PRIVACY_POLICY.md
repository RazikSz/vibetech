# Kebijakan Privasi (Privacy Policy) - VibeTech XYZ

**Terakhir Diperbarui:** 31 Agustus 2026  
**Versi Dokumen:** 2.0.0  
**Nama Aplikasi:** VibeTech XYZ (`com.vibetech.xyz`)  
**Pengembang / Pemilik Layanan:** VibeTech XYZ (Lead Developer: Raziek)  
**Website Resmi:** [https://vibetech.xyz](https://vibetech.xyz)  
**Email Dukungan:** [support@vibetech.xyz](mailto:support@vibetech.xyz)  
**Kontak WhatsApp Dukungan:** [+62 878-8587-3325](https://wa.me/6287885873325)  

---

## 1. Pendahuluan

Selamat datang di **VibeTech XYZ**. Kami sangat menghargai privasi Anda dan berkomitmen untuk melindungi data pribadi yang Anda percayakan kepada kami. Kebijakan Privasi ini menjelaskan bagaimana VibeTech XYZ mengumpulkan, menggunakan, menyimpan, memproses, membagikan, dan melindungi data pribadi Anda saat menggunakan aplikasi mobile, desktop, dan ekosistem layanan kami (termasuk penyewaan Cloud VPS, Panel Hosting Pterodactyl, Sewa Bot WhatsApp, VibeWallet, serta asisten cerdas Furina AI).

Dengan mengunduh, mendaftar, mengakses, atau menggunakan aplikasi **VibeTech XYZ**, Anda menyatakan bahwa Anda telah membaca, memahami, dan menyetujui seluruh ketentuan dalam Kebijakan Privasi ini sesuai dengan peraturan perundang-undangan yang berlaku, termasuk **Undang-Undang Republik Indonesia No. 27 Tahun 2022 tentang Perlindungan Data Pribadi (UU PDP)**.

---

## 2. Data Pribadi yang Kami Kumpulkan

Berdasarkan arsitektur kode sumber dan fungsi teknis aplikasi VibeTech XYZ, kami mengumpulkan kategori data berikut:

### A. Data Identitas Akun & Profil Pengguna
* **Identitas Dasar:** Nama lengkap, alamat email, username unik, nomor telepon / WhatsApp.
* **Informasi Profil Tambahan:** Foto avatar (URL), biografi singkat, lokasi tempat tinggal/kota, dan kode referral.
* **Peran Akun:** Tingkat hak akses sistem (`user` atau `admin`/`administrator`).

### B. Data Kredensial & Keamanan Akun
* **Kata Sandi (Password):** Disimpan dalam bentuk hash terenkripsi dan tidak dapat dibaca langsung.
* **Security PIN Transaksi (6-Digit):** Digunakan sebagai lapisan otorisasi pembayaran, transfer saldo, dan checkout layanan server.
* **Otentikasi Dua Faktor (2FA):** Status aktivasi keamanan tambahan akun.
* **Riwayat Masuk (Login History):** Pencatatan waktu login, penyedia otentikasi (Email, Google Sign-In, GitHub OAuth), dan status keberhasilan sesi.
* **Data Biometrik (Sidik Jari / Face ID):** Digunakan melalui library `local_auth`. **Penting:** Data biometrik Anda diproses 100% secara lokal oleh modul perangkat keras keamanan (*Secure Enclave / Keystore*) perangkat Anda. VibeTech XYZ **TIDAK PERNAH** mengumpulkan, mentransmisikan, atau menyimpan data biometrik mentah Anda di server kami.

### C. Data Transaksi Finansial & VibeWallet
* **Informasi Transaksi:** Nomor Invoice unik, ID Pesanan (*Order ID*), nama paket produk yang dipesan, kuantitas, total tagihan (Rupiah), catatan pesanan, dan tanggal transaksi.
* **Metode Pembayaran:** Saldo internal VibeWallet, QRIS Instant, Virtual Account Bank (BCA, Mandiri, BRI, BNI, Permata), dan E-Wallet (GoPay, DANA, OVO, ShopeePay).
* **Saldo & Mutasi:** Saldo aktif VibeWallet, riwayat top-up, dan pengurangan saldo untuk pembelian layanan.

### D. Data Layanan Server & Infrastruktur Digital Aktif
* **Alokasi Server VPS & Panel:** Alamat IP server, port jaringan, URL panel server, username server, dan spesifikasi paket (CPU Core, RAM, NVMe Storage).
* **Bot WhatsApp:** Nomor sesi bot, Session ID, dan masa aktif sewa bot.
* **Siklus Langganan:** Tanggal aktivasi layanan dan tanggal kadaluarsa (*expired date*).

### E. Data Interaksi Asisten AI (Furina AI Assistant)
* **Pesan & Prompt Konsultasi:** Pesan teks yang Anda kirimkan ke asisten AI Furina untuk rekomendasi server atau bantuan teknis.
* **Sesi Percakapan:** *Session ID* percakapan sementara untuk menjaga kelancaran dialog interaktif (dapat direset sewaktu-waktu oleh pengguna).

### F. Data Bantuan Pelanggan (Customer Support) & Notifikasi
* **Tiket Bantuan:** Nomor tiket bantuan, nama pengirim, subjek kendala, rincian pesan, dan status penanganan tiket.
* **Kotak Masuk Notifikasi (Inbox):** Riwayat email transaksi, kode verifikasi OTP (One-Time Password) reset password, dan status keterbacaan notifikasi.

### G. Data Preferensi & Penyimpanan Lokal
* **Penyimpanan Lokal (SQLite & SharedPreferences):** Menyimpan status login sesi, preferensi tema (*Cyber Neon Dark Mode* / *Light Mode*), preferensi bahasa (Bahasa Indonesia / English), serta cache keranjang belanja.

---

## 3. Izin Akses Perangkat (Device Permissions)

Aplikasi VibeTech XYZ memerlukan beberapa izin akses sistem untuk beroperasi secara optimal:

| Izin Perangkat | Fungsi & Penggunaan |
| :--- | :--- |
| **`android.permission.INTERNET`** | Diperlukan untuk menghubungkan aplikasi ke backend VibeTech, sinkronisasi Cloud Firestore, gerbang pembayaran Midtrans, otentikasi Google/GitHub, dan AI Furina. |
| **`android.permission.USE_BIOMETRIC`** & **`android.permission.USE_FINGERPRINT`** | Diperlukan untuk otentikasi login cepat dan aman menggunakan sensor sidik jari atau pemindai wajah lokal perangkat. |

---

## 4. Tujuan Penggunaan & Pemrosesan Data

Kami menggunakan data pribadi Anda untuk tujuan-tujuan berikut:
1. **Penyediaan & Otomasi Layanan:** Memproses aktivasi instan Cloud VPS, akun game panel hosting Pterodactyl, dan runtime WhatsApp bot.
2. **Pemrosesan Pembayaran:** Memvalidasi transaksi pembayaran secara aman, mengelola saldo VibeWallet, serta menerbitkan invoice digital resmi.
3. **Keamanan & Pencegahan Penipuan:** Melindungi akun dari akses ilegal melalui verifikasi PIN 6-digit, 2FA, OTP email, dan audit riwayat login.
4. **Layanan Bantuan & Notifikasi:** Mengirimkan bukti pembayaran, notifikasi perpanjangan server, kode OTP pemulihan kata sandi, dan merespons tiket bantuan teknis.
5. **Peningkatan Layanan & AI:** Mengoptimalkan respons asisten AI Furina dalam memberikan rekomendasi spesifikasi infrastruktur server yang relevan.
6. **Sinkronisasi Multi-Perangkat:** Menjaga keselarasan data antara database lokal SQLite perangkat Anda dengan Firebase Cloud.

---

## 5. Layanan dan Integrasi Pihak Ketiga (Third-Party Services)

Dalam menyediakan layanan, VibeTech XYZ bekerja sama dengan penyedia teknologi pihak ketiga terpercaya:

1. **Google Firebase (Google LLC):**
   * Digunakan untuk *Firebase Authentication*, *Cloud Firestore*, dan *Firebase Realtime Database* guna otentikasi aman dan sinkronisasi basis data cloud.
   * Kebijakan Privasi Google: [https://policies.google.com/privacy](https://policies.google.com/privacy)
2. **Google Sign-In & GitHub OAuth (Microsoft / GitHub):**
   * Digunakan untuk otentikasi masuk sosial cepat (*Single Sign-On*).
3. **Midtrans Payment Gateway (PT Midtrans):**
   * Digunakan untuk memproses transaksi pembayaran digital (QRIS, GoPay, ShopeePay, DANA, OVO, dan Virtual Account Bank).
   * Data kartu/rekening diproses langsung melalui sistem PCI-DSS Midtrans yang aman; VibeTech XYZ tidak menyimpan nomor kartu debit/kredit pengguna.
   * Kebijakan Privasi Midtrans: [https://midtrans.com/privacy-policy](https://midtrans.com/privacy-policy)
4. **Google Generative AI / Gemini API (Google LLC):**
   * Digunakan sebagai mesin pemrosesan kecerdasan buatan (*AI Engine*) untuk asisten Furina AI.
5. **Nodemailer & Layanan SMTP Email (Google Workspace / Gmail SMTP):**
   * Digunakan untuk pengiriman email transaksional, invoice digital, dan kode OTP verifikasi keamanan.

---

## 6. Penyimpanan, Retensi, dan Keamanan Data

* **Keamanan Transmisi:** Seluruh komunikasi data antara aplikasi klien, server Express Node.js, dan cloud dilindungi dengan enkripsi standar industri **HTTPS / TLS (Transport Layer Security)**.
* **Penyimpanan Terisolasi:** Data lokal disimpan dalam direktori aman perangkat pengguna melalui enkapsulasi SQLite (`vibetech.db`) dan SharedPreferences.
* **Perlindungan Kredensial:** Kata sandi dan PIN transaksi disimpan dalam bentuk hash terenkripsi.
* **Retensi Data:** Kami menyimpan data akun dan riwayat transaksi Anda selama akun Anda aktif atau selama diperlukan untuk mematuhi kewajiban hukum dan audit akuntansi. Anda dapat meminta penghapusan data kapan saja.

---

## 7. Hak-Hak Anda atas Data Pribadi

Sesuai dengan regulasi perlindungan data yang berlaku (termasuk UU PDP No. 27/2022), Anda memiliki hak-hak berikut:
1. **Hak Mengakses & Melihat:** Anda berhak melihat seluruh data profil, saldo, riwayat transaksi, invoice, dan layanan aktif Anda langsung melalui aplikasi.
2. **Hak Memperbarui & Mengoreksi (Koreksi Data):** Anda dapat memperbarui nama, nomor telepon, bio, lokasi, kata sandi, dan PIN transaksi secara langsung di menu *Profile* / *Pengaturan*.
3. **Hak Menghapus Sesi AI:** Anda dapat membersihkan riwayat percakapan dengan Furina AI melalui fitur *Reset Session*.
4. **Hak Menghapus Akun & Data (Right to Erasure):** Anda berhak mengajukan permohonan penutupan akun dan penghapusan data pribadi Anda secara permanen dari server kami dengan menghubungi Tim Dukungan VibeTech XYZ.
5. **Hak Mengatur Keamanan:** Anda memiliki kendali penuh untuk mengaktifkan atau menonaktifkan fitur biometrik dan otentikasi dua faktor (2FA).

---

## 8. Privasi Anak di Bawah Umur

Layanan VibeTech XYZ ditujukan untuk pengguna yang telah memenuhi usia cakap hukum (minimal 17 tahun atau di bawah pengawasan orang tua/wali) untuk melakukan transaksi digital dan sewa infrastruktur server. Kami tidak secara sengaja mengumpulkan data pribadi anak di bawah umur 13 tahun tanpa persetujuan orang tua/wali.

---

## 9. Perubahan pada Kebijakan Privasi Ini

Kami dapat memperbarui Kebijakan Privasi ini dari waktu ke waktu untuk menyesuaikan dengan pembaruan fitur aplikasi atau perubahan regulasi hukum. Setiap perubahan akan diberitahukan melalui pembaruan pada halaman ini dan/atau melalui notifikasi aplikasi. Tanggal "Terakhir Diperbarui" di bagian atas dokumen ini akan mencerminkan versi terbaru.

---

## 10. Hubungi Kami & Pusat Bantuan

Jika Anda memiliki pertanyaan, saran, keluhan mengenai privasi, atau ingin menggunakan hak-hak perlindungan data pribadi Anda, silakan hubungi tim kami melalui kontak resmi berikut:

* **Nama Pengembang / Organisasi:** VibeTech XYZ
* **Lead Developer & Grand Director:** Raziek
* **Alamat Email Dukungan:** [support@vibetech.xyz](mailto:support@vibetech.xyz)
* **Nomor WhatsApp Layanan Pelanggan:** [+62 878-8587-3325](https://wa.me/6287885873325)
* **Website Resmi:** [https://vibetech.xyz](https://vibetech.xyz)
* **Saluran Telegram Resmi:** [https://t.me/vibetech_official](https://t.me/vibetech_official)
* **Repository & Panduan Teknis:** [https://github.com/vibetech-xyz](https://github.com/vibetech-xyz)

---
*Dokumen ini dibuat secara resmi untuk ekosistem aplikasi VibeTech XYZ.*
