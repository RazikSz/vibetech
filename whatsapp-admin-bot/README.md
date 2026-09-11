# 🤖 Vibetech WhatsApp Admin Bot

Microservice Backend berbasis **Node.js (@whiskeysockets/baileys + Firebase Admin SDK)** untuk mengelola katalog produk dan saldo pengguna **Vibetech XYZ** langsung melalui pesan WhatsApp Owner/Admin.

---

## 🌟 Fitur Utama

- 📦 **CRUD Produk Cloud**: Tambah produk baru, ubah harga, ubah stok, hapus produk, dan tampilkan katalog langsung tersinkron ke **Firestore & Firebase RTDB**.
- 💰 **Manajemen Saldo Pengguna**: Cek saldo user, tambah saldo (*top-up* instan), dan potong/koreksi saldo dengan otomatis mencatat bukti invoice transaksi mutasi.
- 🛡️ **Owner Whitelist Security**: Hanya nomor WhatsApp yang terdaftar di file `.env` yang dapat menjalankan perintah admin.
- 🔄 **Real-Time Synchronization**: Perubahan data langsung ter-update di aplikasi Android/iOS/Desktop Flutter pengguna.

---

## 📂 Struktur File

```
whatsapp-admin-bot/
├── config/
│   └── firebase.js          # Inisialisasi Firebase Admin SDK (Firestore & RTDB)
├── handlers/
│   └── commandHandler.js    # Parser perintah teks WhatsApp & router logika
├── services/
│   ├── productService.js    # Layanan CRUD produk ke Firestore & RTDB
│   ├── userService.js       # Layanan akun & penyesuaian saldo atomic
│   └── transactionService.js# Pencatatan invoice mutasi transaksi
├── index.js                 # Entry point: Koneksi Baileys & event listeners
├── .env.example             # Contoh template konfigurasi environment
├── package.json             # Dependensi Node.js
└── serviceAccountKey.json   # Kredensial Firebase Admin SDK (Unduh dari Firebase Console)
```

---

## 🚀 Cara Setup & Menjalankan

### 1. Masuk ke Direktori Bot & Install Dependensi
Buka terminal dan masuk ke folder `whatsapp-admin-bot`:
```bash
cd whatsapp-admin-bot
npm install
```

### 2. Dapatkan Kredensial Firebase (`serviceAccountKey.json`)
1. Buka [Firebase Console](https://console.firebase.google.com/).
2. Pilih project **vibetech-xyz**.
3. Klik ikon gear ⚙️ (**Project Settings**) -> Tab **Service accounts**.
4. Klik tombol **Generate new private key** -> lalu klik **Generate key**.
5. Simpan file JSON hasil download ke dalam folder `whatsapp-admin-bot/` dan beri nama persis: `serviceAccountKey.json`.

### 3. Konfigurasi File `.env`
Salin file `.env.example` menjadi `.env`:
```bash
cp .env.example .env
```
Buka `.env` dan masukkan nomor WhatsApp Anda sebagai Owner:
```env
# Nomor HP Owner (format 628xxx tanpa tanda +, pisahkan dengan koma jika lebih dari 1)
OWNER_NUMBERS=6281234567890

FIREBASE_SERVICE_ACCOUNT=./serviceAccountKey.json
FIREBASE_RTDB_URL=https://vibetech-xyz-default-rtdb.asia-southeast1.firebasedatabase.app
BOT_PREFIX=#
```

### 4. Jalankan Bot & Scan QR Code
Jalankan bot dengan perintah:
```bash
npm start
```
Terminal akan menampilkan **QR Code**:
1. Buka aplikasi **WhatsApp** di smartphone Anda.
2. Buka menu **Titik Tiga / Pengaturan** -> **Perangkat Tertaut (Linked Devices)**.
3. Klik **Tautkan Perangkat (Link a Device)**.
4. Scan QR Code yang muncul di terminal.
5. Setelah terhubung, sesi akan tersimpan di folder `auth_info_baileys/` sehingga Anda tidak perlu scan QR lagi saat restart.

---

## 📋 Daftar Perintah (Commands)

| Kategori | Perintah | Format Syntax | Contoh Penggunaan |
| :--- | :--- | :--- | :--- |
| **Bantuan** | Menu Bantuan | `#menu` | `#menu` |
| **Status** | Ping / Cek Status | `#ping` | `#ping` |
| **Produk** | Tambah Produk Baru | `#tambahproduk [Nama]#[Harga]#[Stok]#[Kategori]#[Deskripsi]` | `#tambahproduk VPS Gaming#75000#10#VPS#RAM 4GB CPU 2 Core` |
| **Produk** | Edit Harga Produk | `#editharga [ID/Nama]#[HargaBaru]` | `#editharga VPS Starter#35000` |
| **Produk** | Edit Stok Produk | `#editstok [ID/Nama]#[StokBaru]` | `#editstok VPS Starter#20` |
| **Produk** | Hapus Produk | `#hapusproduk [ID/Nama]` | `#hapusproduk VPS Gaming` |
| **Produk** | List Seluruh Produk | `#listproduk` | `#listproduk` |
| **Saldo** | Cek Saldo User | `#ceksaldo [Email/Username]` | `#ceksaldo user@vibetech.xyz` |
| **Saldo** | Top Up / Tambah Saldo | `#tambahsaldo [Email/Username]#[Nominal]#[Keterangan]` | `#tambahsaldo user@vibetech.xyz#50000#Top up BCA` |
| **Saldo** | Potong Saldo | `#kurangsaldo [Email/Username]#[Nominal]#[Keterangan]` | `#kurangsaldo user@vibetech.xyz#10000#Koreksi refund` |
| **Laporan** | Daftar Pengguna | `#listuser` | `#listuser` |
| **Laporan** | Daftar Transaksi | `#listtransaksi` | `#listtransaksi` |

---

## 🌐 Menjalankan di Background / VPS Server (24/7)

Gunakan **PM2** agar bot tetap aktif tanpa henti di server VPS:

```bash
# Install PM2 secara global (jika belum)
npm install -g pm2

# Jalankan bot dengan PM2
pm2 start index.js --name "vibetech-wa-bot"

# Simpan agar otomatis hidup setelah restart VPS
pm2 save
pm2 startup
```

Untuk melihat log live:
```bash
pm2 logs vibetech-wa-bot
```
