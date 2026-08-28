---
name: VibeTech Cyber-Neon Design System
colors:
  surface: '#0F1426'
  surface-dim: '#060814'
  surface-bright: '#161C36'
  surface-container-lowest: '#060814'
  surface-container-low: '#0A0E17'
  surface-container: '#0F1426'
  surface-container-high: '#161C36'
  surface-container-highest: '#1E2542'
  on-surface: '#FFFFFF'
  on-surface-variant: '#94A3B8'
  inverse-surface: '#F8FAFC'
  inverse-on-surface: '#0F172A'
  outline: '#7C4DFF'
  outline-variant: '#374151'
  surface-tint: '#7C4DFF'
  primary: '#7C4DFF'
  on-primary: '#FFFFFF'
  primary-container: '#5E35B1'
  on-primary-container: '#FFFFFF'
  inverse-primary: '#9E7BFF'
  secondary: '#00E5FF'
  on-secondary: '#060814'
  secondary-container: '#00B0FF'
  on-secondary-container: '#FFFFFF'
  tertiary: '#E040FB'
  on-tertiary: '#FFFFFF'
  tertiary-container: '#C2185B'
  on-tertiary-container: '#FFFFFF'
  error: '#EF4444'
  on-error: '#FFFFFF'
  error-container: '#991B1B'
  on-error-container: '#FEE2E2'
  primary-fixed: '#9E7BFF'
  primary-fixed-dim: '#7C4DFF'
  on-primary-fixed: '#FFFFFF'
  on-primary-fixed-variant: '#5E35B1'
  secondary-fixed: '#00E5FF'
  secondary-fixed-dim: '#00B0FF'
  on-secondary-fixed: '#060814'
  on-secondary-fixed-variant: '#00838F'
  tertiary-fixed: '#E040FB'
  tertiary-fixed-dim: '#D500F9'
  on-tertiary-fixed: '#FFFFFF'
  on-tertiary-fixed-variant: '#880E4F'
  background: '#060814'
  on-background: '#FFFFFF'
  surface-variant: '#161C36'
  text-primary: '#FFFFFF'
  text-secondary: '#94A3B8'
  accent: '#E040FB'
  cyan: '#00E5FF'
  emerald: '#10B981'
  success: '#10B981'
  warning: '#F59E0B'
  danger: '#EF4444'
typography:
  display-lg:
    fontFamily: Outfit
    fontSize: 38px
    fontWeight: '800'
    lineHeight: '1.1'
  headline-lg:
    fontFamily: Poppins
    fontSize: 24px
    fontWeight: '700'
    lineHeight: '32px'
  headline-md:
    fontFamily: Poppins
    fontSize: 20px
    fontWeight: '600'
    lineHeight: '28px'
  headline-sm:
    fontFamily: Poppins
    fontSize: 16px
    fontWeight: '600'
    lineHeight: '24px'
  body-lg:
    fontFamily: Poppins
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '24px'
  body-md:
    fontFamily: Poppins
    fontSize: 14px
    fontWeight: '400'
    lineHeight: '20px'
  label-sm:
    fontFamily: Poppins
    fontSize: 12px
    fontWeight: '500'
    lineHeight: '16px'
  code-mono:
    fontFamily: Fira Code
    fontSize: 12px
    fontWeight: '600'
    lineHeight: '16px'
rounded:
  sm: 0.5rem
  DEFAULT: 0.75rem
  md: 0.875rem
  lg: 1.25rem
  xl: 1.75rem
  full: 9999px
spacing:
  margin-page: 1rem
  gutter-grid: 1rem
  stack-xs: 0.25rem
  stack-sm: 0.5rem
  stack-md: 1rem
  stack-lg: 1.5rem
  stack-xl: 2rem
---

# 🌌 VibeTech XYZ — System Design & UI/UX Specification (DESIGN.md)

> **Google Stitch Design Document**  
> **Application**: VibeTech XYZ (Next-Gen Cloud Infrastructure, Server Provisioning & AI Ecosystem)  
> **Lead Architect & Developer**: **Raziek**  
> **Target Platforms**: Flutter Mobile (Android, iOS) & Web Architecture  
> **Design Theme**: Cyber-Neon Dark Glassmorphism with Clean Light Mode Support  
> **Version**: 2.0.0 (Production Release)

---

## 📑 Daftar Isi (Table of Contents)

1. [Visi Produk & Filosofi Desain](#1-visi-produk--filosofi-desain)
2. [Design Tokens & Sistem Warna (Color Palette)](#2-design-tokens--sistem-warna-color-palette)
3. [Tipografi & Skala Teks (Typography Hierarchy)](#3-tipografi--skala-teks-typography-hierarchy)
4. [Sistem Spasial, Grid & Glassmorphic Elevation](#4-sistem-spasial-grid--glassmorphic-elevation)
5. [Komponen Inti Desain (UI Component Library)](#5-komponen-inti-desain-ui-component-library)
6. [Spesifikasi Layar Aplikasi (Screen-by-Screen Architecture)](#6-spesifikasi-layar-aplikasi-screen-by-screen-architecture)
   - [6.1 Layar Autentikasi & Biometrik (Auth Module)](#61-layar-autentikasi--biometrik-auth-module)
   - [6.2 Interactive Dashboard & VibeWallet](#62-interactive-dashboard--vibewallet)
   - [6.3 Katalog Layanan Cloud & Keranjang Belanja](#63-katalog-layanan-cloud--keranjang-belanja)
   - [6.4 Dual Payment Gateway & Midtrans Snap](#64-dual-payment-gateway--midtrans-snap)
   - [6.5 Active Server Manager (VPS, Panel, Bot WA)](#65-active-server-manager-vps-panel-bot-wa)
   - [6.6 Furina AI Theatrical Live Chat (Directed by Raziek)](#66-furina-ai-theatrical-live-chat-directed-by-raziek)
   - [6.7 Riwayat Transaksi & Digital Invoicing](#67-riwayat-transaksi--digital-invoicing)
   - [6.8 Notifikasi, Profil, Dark/Light Mode & Multi-Bahasa](#68-notifikasi-profil-darklight-mode--multi-bahasa)
7. [Mikro-Interaksi, Animasi & Haptic Feedback](#7-mikro-interaksi-animasi--haptic-feedback)
8. [Panduan Integrasi Google Stitch (stitch.withgoogle.com)](#8-panduan-integrasi-google-stitch-stitchwithgooglecom)

---

## 1. Visi Produk & Filosofi Desain

**VibeTech XYZ** dirancang untuk menghadirkan pengalaman pengadaan infrastruktur server yang **instan**, **aman**, dan **bernuansa futuristik** bagi developer, gamer, dan pelaku bisnis modern.

### 🌟 Prinsip Desain Utama:
1. **Instant Gratification (1-Detik Provisioning)**: Setiap tindakan mulai dari top-up saldo, checkout pesanan, hingga penerbitan IP publik dan root password SSH diselesaikan secara instan tanpa jeda manual.
2. **Cyber-Neon Glassmorphism**: Permukaan kartu semi-transparan dengan efek pantulan cahaya neon (Deep Cyber Purple, Neon Magenta, Electric Cyan) di atas latar belakang pitch dark void.
3. **Hardware-Level Security**: Memberikan rasa aman penuh melalui integrasi biometrik sidik jari (*Fingerprint* / *Face ID*) dan enkripsi lokal offline-first SQLite.
4. **Theatrical & Contextual Interaction**: Menghadirkan asisten AI Furina karya **Raziek** dengan persona panggung teater yang hidup, mampu membaca konteks saldo dan database server pengguna secara dinamis.

---

## 2. Design Tokens & Sistem Warna (Color Palette)

Aplikasi mengimplementasikan sistem warna adaptif dengan mode default **Cyber Dark Mode** dan fallback **Clean Light Mode**.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        BRAND & NEON PALETTE                           │
├───────────────────┬───────────────────┬───────────────────┬────────────┤
│ Deep Purple       │ Neon Magenta      │ Electric Cyan     │ Emerald    │
│ #7C4DFF           │ #E040FB           │ #00E5FF           │ #10B981    │
│ Primary Brand     │ Accent & AI Chat  │ Data, IPs, Links  │ Success    │
└───────────────────┴───────────────────┴───────────────────┴────────────┘
```

### 🎨 A. Token Warna Lengkap (Design Tokens)

| Token Name | Hex Code | RGB / Alpha | Semantic Role |
|---|---|---|---|
| `color.brand.primary` | `#7C4DFF` | `rgb(124, 77, 255)` | Warna brand utama, tombol primer, active tabs |
| `color.brand.primaryLight` | `#9E7BFF` | `rgb(158, 123, 255)` | Hover state, border glow, highlight text |
| `color.brand.primaryDark` | `#5E35B1` | `rgb(94, 53, 177)` | Gradient start, active card gradient |
| `color.brand.accent` | `#E040FB` | `rgb(224, 64, 251)` | Neon Magenta, Furina AI, promo badges |
| `color.brand.cyan` | `#00E5FF` | `rgb(0, 229, 255)` | Electric Cyan, server metrics, IP addresses |
| `color.brand.indigo` | `#6366F1` | `rgb(99, 102, 241)` | Secondary button, subtle accent |
| `color.status.success` | `#10B981` | `rgb(16, 185, 129)` | Server Online, status Lunas, balance plus |
| `color.status.warning` | `#F59E0B` | `rgb(245, 158, 11)` | Server expiring soon (<14 hari), status Pending |
| `color.status.error` | `#EF4444` | `rgb(239, 68, 68)` | Server expired, delete product, status Batal |
| `color.status.info` | `#3B82F6` | `rgb(59, 130, 246)` | System alerts, help tooltips |

### 🌑 B. Dark Surface & Background Tokens
- `color.surface.darkBg`: `#060814` *(Pitch Dark Void — Latar Belakang Utama)*
- `color.surface.darkBgSecondary`: `#0A0E17` *(Dark Slate Blue — Header/Appbar)*
- `color.surface.darkCard`: `#0F1426` *(Midnight Navy Card — Permukaan Kartu Glass)*
- `color.surface.darkCardElevated`: `#161C36` *(Elevated Surface — Modal Popup & Bottom Sheet)*
- `color.surface.darkCodeBg`: `#080B18` *(Code Box Background — Blok Kredensial & DDL)*
- `color.text.darkPrimary`: `#FFFFFF` *(Teks Judul & Label Penting)*
- `color.text.darkSecondary`: `#94A3B8` *(Muted Steel — Deskripsi & Subtitle)*
- `color.text.darkMuted`: `#64748B` *(Footnotes & Inactive Icons)*

### ☀️ C. Light Surface & Background Tokens
- `color.surface.lightBg`: `#F8FAFC` *(Clean Ghost White)*
- `color.surface.lightCard`: `#FFFFFF` *(Pure White Card)*
- `color.surface.lightCardElevated`: `#F1F5F9` *(Soft Grey Surface)*
- `color.text.lightPrimary`: `#1E293B` *(Charcoal Slate)*
- `color.text.lightSecondary`: `#64748B` *(Slate Muted)*

### 🌈 D. Gradient Tokens
- `gradient.primary`: `linear-gradient(135deg, #7C4DFF 0%, #E040FB 100%)`
- `gradient.cyan`: `linear-gradient(135deg, #00E5FF 0%, #7C4DFF 100%)`
- `gradient.walletCard`: `linear-gradient(135deg, #4A148C 0%, #7C4DFF 50%, #E040FB 100%)`
- `gradient.glass`: `linear-gradient(135deg, rgba(255,255,255,0.08) 0%, rgba(255,255,255,0.02) 100%)`

---

## 3. Tipografi & Skala Teks (Typography Hierarchy)

Menggunakan keluarga huruf Google Fonts: **Outfit** untuk Display/Heading dan **Poppins** untuk Body, UI Components, serta **Fira Code** untuk kredensial teknis.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        TYPOGRAPHY HIERARCHY                           │
├────────────────┬──────────┬──────────┬────────────────────────────────┤
│ Style Token    │ Size     │ Weight   │ Font Family & Application      │
├────────────────┼──────────┼──────────┼────────────────────────────────┤
│ display.large  │ 36-38 pt │ 800 Bold │ Outfit (Cover & Hero Titles)   │
│ display.medium │ 28-32 pt │ 700 Bold │ Outfit (Wallet Balance Amount) │
│ heading.h1     │ 22-24 pt │ 700 Bold │ Poppins (Page Header Title)    │
│ heading.h2     │ 18-20 pt │ 600 Semi │ Poppins (Card Titles, Sections)│
│ heading.h3     │ 15-16 pt │ 600 Semi │ Poppins (Product Names, Modals)│
│ body.large     │ 14 pt    │ 500 Med  │ Poppins (Input Fields, Buttons)│
│ body.regular   │ 12-13 pt │ 400 Reg  │ Poppins (Descriptions, Badges) │
│ caption        │ 10-11 pt │ 400 Reg  │ Poppins (Timestamps, Footnotes)│
│ code.mono      │ 11-12 pt │ 600 Semi │ Fira Code (IP, Ports, Passwords│
└────────────────┴──────────┴──────────┴────────────────────────────────┘
```

---

## 4. Sistem Spasial, Grid & Glassmorphic Elevation

### 📐 A. Spacing & Padding Tokens (8pt Grid)
- `spacing.xs`: `4px`
- `spacing.sm`: `8px`
- `spacing.md`: `12px`
- `spacing.lg`: `16px`
- `spacing.xl`: `20px`
- `spacing.2xl`: `24px`
- `spacing.3xl`: `32px`

### 🔲 B. Border Radius Tokens
- `radius.sm`: `8px` *(Badge, input chip, small buttons)*
- `radius.md`: `12-14px` *(Input fields, action cards, dialogs)*
- `radius.lg`: `18-20px` *(Glassmorphic cards, service cards, bottom sheets)*
- `radius.xl`: `28-36px` *(Mobile device frame containers, promo banners)*
- `radius.pill`: `999px` *(Floating tags, filter pills, quick chips)*

### 🔮 C. Glassmorphic Elevation & Box Shadows
- **Glass Card Surface**: `background: rgba(15, 20, 38, 0.85); backdrop-filter: blur(16px);`
- **Neon Glow Border**: `border: 1.5px solid rgba(124, 77, 255, 0.35);`
- **Cyan Glow Shadow**: `box-shadow: 0 8px 32px rgba(0, 229, 255, 0.15);`
- **Purple Pulse Glow**: `box-shadow: 0 10px 30px rgba(124, 77, 255, 0.25);`

---

## 5. Komponen Inti Desain (UI Component Library)

### 🔘 A. Buttons & Interactive Controls
1. **Primary Gradient CTA**:
   - `background: LinearGradient(colors: [#7C4DFF, #E040FB])`
   - `height: 50px`, `border-radius: 14px`
   - Efek: Tap scale bounce `transform: scale(0.97)` + haptic feedback.
2. **Outlined Cyan Action Button**:
   - `border: 1.5px solid #00E5FF`, `background: rgba(0, 229, 255, 0.08)`
   - Label: Electric Cyan Bold. Digunakan untuk "+ Keranjang" dan "Buka Panel".
3. **Biometric Quick Trigger**:
   - Ikon sidik jari hardware melingkar dengan pulsing ripple animation.

### 💳 B. Glassmorphic VibeWallet Card
- Dimensi: Lebar 100%, Tinggi `170px`, `border-radius: 20px`
- Latar Belakang: `linear-gradient(135deg, #4A148C, #7C4DFF, #E040FB)`
- Elemen: Chip active account, Saldo `Rp 10.000.000` (Outfit 28pt Bold), tombol Top Up & Riwayat Mutasi.

### 📦 C. Product & Server Instance Card
- Header: Nama Paket + Badge Kategori (VPS, Panel SG, Bot WA).
- Spesifikasi Box: IP Publik, Port SSH (22), Username (root), Password tersamar dengan tombol copy.
- Footer: Countdown timer masa aktif (29 Hari) + Tombol perpanjang layanan.

---

## 6. Spesifikasi Layar Aplikasi (Screen-by-Screen Architecture)

```
┌────────────────────────────────────────────────────────────────────────┐
│                     VIBETECH XYZ APP FLOW MAP                          │
├────────────────────────────────────────────────────────────────────────┤
│  [1. Login / 2FA Biometric] ──> [2. Interactive Dashboard]             │
│                                       │                                │
│       ┌───────────────────────────────┼────────────────────────┐       │
│       ▼                               ▼                        ▼       │
│  [3. Katalog & Cart]        [4. Active Servers]        [6. Furina AI]  │
│       │                               │                        │       │
│       ▼                               ▼                        ▼       │
│  [5. Dual Checkout]         [7. Riwayat & Invoice]     [8. Profile]    │
│  (Saldo vs Midtrans)                                                   │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 6.1 Layar Autentikasi & Biometrik (Auth Module)
- **Nama File Source**: `lib/pages/auth/login_page.dart`
- **Fungsi Utama**: Validasi kredensial pengguna dan autentikasi instan via sensor sidik jari perangkat keras.
- **Elemen UI**:
  - Logo VibeTech XYZ Cyber Glow Badge.
  - Text Field Input Email/Username dengan ikon prefix neon.
  - Text Field Password dengan toggle visibilitas sandi.
  - Tombol Utama: *"Masuk Sekarang"* (Gradient Purple-Magenta).
  - Tombol Sekunder Biometrik: *"Masuk via Biometrik (Fingerprint)"* (`local_auth`).
  - Fallback 2FA PIN dialog untuk keamanan ganda.

---

### 6.2 Interactive Dashboard & VibeWallet
- **Nama File Source**: `lib/pages/home/dashboard_page.dart`
- **Fungsi Utama**: Pusat komando akun pengguna, saldo dompet, dan peluncur layanan cepat.
- **Elemen UI**:
  - Top Bar: Avatar Pengguna (RZ) + Member Tier Status ("Member Pro").
  - **Kartu VibeWallet**: Saldo aktif Rp 10.000.000 dengan aksi Top Up & Mutasi.
  - **4-Grid Layanan Cloud**:
    1. ☁️ *Cloud VPS* (`#7C4DFF`)
    2. 🎮 *Pterodactyl Panel* (`#00E5FF`)
    3. 💬 *Bot WhatsApp* (`#10B981`)
    4. 🤖 *Furina AI Chat* (`#E040FB`)
  - **Promo Banner Carousel**: Diskon 30% Server kode `VIBESERVER`.

---

### 6.3 Katalog Layanan Cloud & Keranjang Belanja
- **Nama File Source**: `lib/pages/home/produk_page.dart` & `keranjang_page.dart`
- **Fungsi Utama**: Eksplorasi produk hosting multi-kategori dan keranjang belanja dinamis berbasis `CartService`.
- **Elemen UI**:
  - Filter Category Pills: *Semua, VPS, Panel, Bot WA*.
  - Product Card: Spesifikasi CPU/RAM/NVMe SSD, Harga `/bulan`, tombol `+ Keranjang`.
  - Order Dialog Sheet: Stepper jumlah unit, dropdown durasi (1, 3, 6, 12 bulan), total harga real-time.
  - Cart Page: Reactive list, tombol tambah/kurang kuantitas, tombol checkout sticky bottom.

---

### 6.4 Dual Payment Gateway & Midtrans Snap
- **Nama File Source**: `lib/pages/payment/pembayaran_page.dart`
- **Fungsi Utama**: Eksekusi pelunasan order melalui Saldo VibeWallet 1-detik atau Midtrans Snap Gateway.
- **Elemen UI**:
  - Ringkasan Tagihan & Nomor Invoice (`INV-YYYYMMDD-XXXXX`).
  - **Opsi 1 (Saldo VibeWallet)**: Eksekusi instan 1 detik, bebas biaya admin, terpotong otomatis di SQLite.
  - **Opsi 2 (Midtrans Snap)**: Scan QRIS dinamis (GoPay, DANA, ShopeePay, BCA Mobile) dan Virtual Account (BCA, Mandiri, BRI, BNI).
  - Countdown Payment Timer (17 Menit).
  - Otorisasi biometrik sebelum saldo terpotong.

---

### 6.5 Active Server Manager (VPS, Panel, Bot WA)
- **Nama File Source**: `lib/pages/services/data_vps_page.dart`, `data_panel_page.dart`, `data_bot_page.dart`
- **Fungsi Utama**: Manajemen kredensial instance server yang telah terbit secara otomatis.
- **Elemen UI**:
  - Badge Status Online 99.9% (Emerald Glow).
  - Box Kredensial: IP Public (`103.187.x.x:22`), User (`root`), Password terenkripsi dengan tombol copy.
  - Expiry Countdown Badge: Sisa masa aktif (contoh: *29 Hari 14 Jam*).
  - Launcher Button: *"Buka Web Panel Pterodactyl Singapore"* (`panel.vibetech.xyz`).
  - Tombol Perpanjang Layanan (+30 hari perpanjangan).

---

### 6.6 Furina AI Theatrical Live Chat (Directed by Raziek)
- **Nama File Source**: `lib/pages/common/live_chat_page.dart` & `plugins/furina_ai.js`
- **Fungsi Utama**: Asisten konsultasi teknis berkarakter Grand Diva teatrikal karya **Raziek** dengan pemahaman database real-time.
- **Elemen UI**:
  - Header: Avatar Teatrikal Furina 🎭 + Status Online (Directed by Raziek).
  - Quick Inquiry Chips: *"Cek Sisa Saldo"*, *"Nomor WhatsApp"*, *"Panduan VPS"*.
  - Chat Bubble User: Deep Cyber Purple bubble (rata kanan).
  - Chat Bubble Furina: Dark Glass bubble dengan border Neon Magenta (rata kiri).
  - Auto-Answer Resmi: Menyajikan kontak resmi WhatsApp **`0878-8587-3325`** (`https://wa.me/6287885873325`) dan saldo aktif Rp 10.000.000.

---

### 6.7 Riwayat Transaksi & Digital Invoicing
- **Nama File Source**: `lib/pages/history/riwayat_transaksi_page.dart`
- **Fungsi Utama**: Arsip ledger transaksi keuangan dan peninjauan tanda terima digital.
- **Elemen UI**:
  - Filter Status: *Semua, Selesai (Hijau), Pending (Kuning), Batal (Merah)*.
  - Kartu Transaksi: Nomor Invoice unik, Tanggal & Jam, Metode Bayar, Nominal Transaksi.
  - Modal Digital Receipt: Tanda terima resmi pembelian server untuk audit pengguna.

---

### 6.8 Notifikasi, Profil, Dark/Light Mode & Multi-Bahasa
- **Nama File Source**: `lib/pages/common/notifikasi_page.dart` & `lib/pages/profile/profile_page.dart`
- **Fungsi Utama**: Pusat pengaturan preferensi antarmuka dan kotak masuk notifikasi.
- **Elemen UI**:
  - In-App Notification Center: Unread badge counter, riwayat event auto-provisioning.
  - Switcher Tema: Cyber Dark Mode vs Clean Light Mode.
  - Switcher Bahasa: Bahasa Indonesia (ID) & English (EN) via `LanguageService`.
  - Database Maintenance: Ekspor & Impor database SQLite.

---

## 7. Mikro-Interaksi, Animasi & Haptic Feedback

1. **Button Bounce Tap (`BounceTap`)**:
   - Setiap tombol interaktif mengecil sebesar 3% (`scale: 0.97`) saat ditekan dan memicu getaran taktil ringan (`HapticFeedback.lightImpact()`).
2. **Staggered Card Cascade**:
   - Komponen kartu pada Dashboard dan Katalog muncul secara berurutan (*staggered*) dengan transisi `translateY(20px -> 0px)` dan `opacity(0 -> 1)`.
3. **Neon Glow Pulse**:
   - Saldo VibeWallet dan Avatar Furina AI memiliki animasi napas halus (*breathing glow animation*) dengan durasi `3.0s infinite`.
4. **Dynamic Expiry Warning**:
   - Indikator masa aktif otomatis bertransisi warna dari Hijau (>14 hari), Kuning (<14 hari), hingga Merah (<7 hari).

---

## 8. Panduan Integrasi Google Stitch (stitch.withgoogle.com)

Berkas `DESIGN.md` ini telah diformat sesuai standar spesifikasi Google Stitch.

### 🚀 Cara Mengimpor ke Stitch:
1. Buka dashboard Google Stitch: **[https://stitch.withgoogle.com](https://stitch.withgoogle.com)**
2. Buat proyek baru atau pilih proyek **VibeTech XYZ**.
3. Buka tab **Design System** ➔ Pilih **Import DESIGN.md**.
4. Unggah berkas [DESIGN.md](file:///d:/vibetech_xyz_sqflite/vibetech_xyz/DESIGN.md).
5. Stitch akan secara otomatis menghasilkan token warna, tipografi, komponen glassmorphism, dan alur layar yang presisi sesuai arsitektur VibeTech XYZ!

---

*© 2026 VibeTech XYZ Ecosystem. Architected & Directed with pride by **Raziek**.*
