import sharp from "sharp";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const screenshotsDir = path.join(__dirname, "screenshots");
if (!fs.existsSync(screenshotsDir)) {
  fs.mkdirSync(screenshotsDir, { recursive: true });
}

// 1. SCREEN 1: LOGIN & BIOMETRIC AUTH
const svgScreen1 = `
<svg width="400" height="720" viewBox="0 0 400 720" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#060814"/>
      <stop offset="100%" stop-color="#0F1426"/>
    </linearGradient>
    <linearGradient id="primaryGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#7C4DFF"/>
      <stop offset="100%" stop-color="#E040FB"/>
    </linearGradient>
    <linearGradient id="cyanGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#00E5FF"/>
      <stop offset="100%" stop-color="#7C4DFF"/>
    </linearGradient>
  </defs>

  <!-- Background Frame -->
  <rect width="400" height="720" rx="36" fill="url(#bgGrad)" stroke="#7C4DFF" stroke-width="3"/>
  
  <!-- Notch & Status Bar -->
  <rect x="140" y="10" width="120" height="20" rx="10" fill="#000000"/>
  <text x="30" y="26" fill="#94A3B8" font-family="Arial" font-size="12" font-weight="bold">09:41</text>
  <text x="330" y="26" fill="#00E5FF" font-family="Arial" font-size="12">5G 100%</text>

  <!-- Logo Icon -->
  <rect x="160" y="70" width="80" height="80" rx="20" fill="url(#primaryGrad)"/>
  <circle cx="200" cy="110" r="18" fill="none" stroke="#FFFFFF" stroke-width="4"/>
  <path d="M190 110 L200 120 L215 100" fill="none" stroke="#00E5FF" stroke-width="4"/>

  <!-- Brand Title -->
  <text x="200" y="185" fill="#FFFFFF" font-family="Arial" font-size="22" font-weight="bold" text-anchor="middle">VibeTech XYZ</text>
  <text x="200" y="208" fill="#94A3B8" font-family="Arial" font-size="12" text-anchor="middle">Cloud Hosting &amp; Server Ecosystem</text>

  <!-- Login Card Form -->
  <rect x="30" y="240" width="340" height="430" rx="20" fill="#0D1224" stroke="rgba(255,255,255,0.1)" stroke-width="1.5"/>
  <text x="50" y="275" fill="#FFFFFF" font-family="Arial" font-size="16" font-weight="bold">Masuk ke Akun</text>

  <!-- Email Field -->
  <text x="50" y="315" fill="#94A3B8" font-family="Arial" font-size="11">EMAIL ATAU USERNAME</text>
  <rect x="50" y="325" width="300" height="46" rx="10" fill="#141A2E" stroke="#7C4DFF" stroke-width="1"/>
  <text x="65" y="354" fill="#FFFFFF" font-family="Arial" font-size="13">user@vibetech.com</text>

  <!-- Password Field -->
  <text x="50" y="395" fill="#94A3B8" font-family="Arial" font-size="11">PASSWORD</text>
  <rect x="50" y="405" width="300" height="46" rx="10" fill="#141A2E" stroke="rgba(255,255,255,0.1)" stroke-width="1"/>
  <text x="65" y="434" fill="#94A3B8" font-family="Arial" font-size="14">••••••••••••</text>

  <!-- Login Button -->
  <rect x="50" y="480" width="300" height="50" rx="12" fill="url(#primaryGrad)"/>
  <text x="200" y="511" fill="#FFFFFF" font-family="Arial" font-size="14" font-weight="bold" text-anchor="middle">MASUK SEKARANG</text>

  <!-- Biometric Option -->
  <rect x="50" y="545" width="300" height="50" rx="12" fill="rgba(0, 229, 255, 0.1)" stroke="#00E5FF" stroke-width="1.5"/>
  <circle cx="85" cy="570" r="14" fill="none" stroke="#00E5FF" stroke-width="2.5"/>
  <path d="M80 570 Q85 565 90 570" fill="none" stroke="#00E5FF" stroke-width="2"/>
  <text x="205" y="575" fill="#00E5FF" font-family="Arial" font-size="13" font-weight="bold" text-anchor="middle">Masuk via Biometrik (Fingerprint)</text>

  <!-- Footer Tag -->
  <text x="200" y="645" fill="#64748B" font-family="Arial" font-size="11" text-anchor="middle">Keamanan Berlapis 2FA &amp; LocalAuth</text>
</svg>
`;

// 2. SCREEN 2: INTERACTIVE DASHBOARD
const svgScreen2 = `
<svg width="400" height="720" viewBox="0 0 400 720" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bgGrad2" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#060814"/>
      <stop offset="100%" stop-color="#0C1022"/>
    </linearGradient>
    <linearGradient id="walletGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#4A148C"/>
      <stop offset="50%" stop-color="#7C4DFF"/>
      <stop offset="100%" stop-color="#E040FB"/>
    </linearGradient>
  </defs>

  <rect width="400" height="720" rx="36" fill="url(#bgGrad2)" stroke="#7C4DFF" stroke-width="3"/>
  <rect x="140" y="10" width="120" height="20" rx="10" fill="#000000"/>

  <!-- Top Bar -->
  <circle cx="45" cy="65" r="18" fill="#7C4DFF"/>
  <text x="45" y="70" fill="#FFF" font-family="Arial" font-size="12" font-weight="bold" text-anchor="middle">RZ</text>
  <text x="75" y="60" fill="#94A3B8" font-family="Arial" font-size="11">Halo, Selamat Datang</text>
  <text x="75" y="76" fill="#FFFFFF" font-family="Arial" font-size="14" font-weight="bold">Raziek (Member Pro)</text>
  <rect x="330" y="48" width="34" height="34" rx="8" fill="#141A2E" stroke="#00E5FF" stroke-width="1"/>
  <circle cx="347" cy="65" r="5" fill="#00E5FF"/>

  <!-- VibeWallet Card -->
  <rect x="25" y="105" width="350" height="170" rx="20" fill="url(#walletGrad)"/>
  <text x="45" y="135" fill="rgba(255,255,255,0.8)" font-family="Arial" font-size="12">Saldo VibeWallet</text>
  <text x="45" y="172" fill="#FFFFFF" font-family="Arial" font-size="28" font-weight="bold">Rp 10.000.000</text>
  <text x="45" y="195" fill="#00E5FF" font-family="Arial" font-size="11">● Active Account • Instan 1 Detik</text>
  
  <!-- Wallet Actions -->
  <rect x="45" y="215" width="140" height="40" rx="10" fill="rgba(255,255,255,0.2)"/>
  <text x="115" y="240" fill="#FFFFFF" font-family="Arial" font-size="12" font-weight="bold" text-anchor="middle">+ Top Up Saldo</text>
  <rect x="200" y="215" width="140" height="40" rx="10" fill="rgba(0,0,0,0.25)"/>
  <text x="270" y="240" fill="#FFFFFF" font-family="Arial" font-size="12" font-weight="bold" text-anchor="middle">Riwayat Mutasi</text>

  <!-- Quick Action Grid -->
  <text x="28" y="305" fill="#FFFFFF" font-family="Arial" font-size="14" font-weight="bold">Layanan Cloud Utama</text>
  
  <!-- 4 Grid Buttons -->
  <rect x="25" y="320" width="78" height="85" rx="14" fill="#0F1426" stroke="#7C4DFF" stroke-width="1"/>
  <text x="64" y="355" font-size="20" text-anchor="middle">☁️</text>
  <text x="64" y="385" fill="#FFF" font-family="Arial" font-size="10" font-weight="bold" text-anchor="middle">Cloud VPS</text>

  <rect x="115" y="320" width="78" height="85" rx="14" fill="#0F1426" stroke="#00E5FF" stroke-width="1"/>
  <text x="154" y="355" font-size="20" text-anchor="middle">🎮</text>
  <text x="154" y="385" fill="#FFF" font-family="Arial" font-size="10" font-weight="bold" text-anchor="middle">Pterodactyl</text>

  <rect x="205" y="320" width="78" height="85" rx="14" fill="#0F1426" stroke="#10B981" stroke-width="1"/>
  <text x="244" y="355" font-size="20" text-anchor="middle">💬</text>
  <text x="244" y="385" fill="#FFF" font-family="Arial" font-size="10" font-weight="bold" text-anchor="middle">Bot WA</text>

  <rect x="295" y="320" width="78" height="85" rx="14" fill="#0F1426" stroke="#E040FB" stroke-width="1"/>
  <text x="334" y="355" font-size="20" text-anchor="middle">🤖</text>
  <text x="334" y="385" fill="#FFF" font-family="Arial" font-size="10" font-weight="bold" text-anchor="middle">Furina AI</text>

  <!-- Promo Banner Carousel -->
  <rect x="25" y="425" width="350" height="110" rx="16" fill="linear-gradient(135deg, #1A103C, #0F1426)" stroke="#E040FB" stroke-width="1"/>
  <text x="45" y="455" fill="#E040FB" font-family="Arial" font-size="11" font-weight="bold">PROMO SPESIAL SERVER</text>
  <text x="45" y="480" fill="#FFFFFF" font-family="Arial" font-size="15" font-weight="bold">Diskon Cloud VPS 30%</text>
  <text x="45" y="505" fill="#94A3B8" font-family="Arial" font-size="11">Gunakan kode: VIBESERVER • Uptime 99.9%</text>

  <!-- Bottom Nav -->
  <rect x="25" y="635" width="350" height="60" rx="20" fill="#0B0E1F" stroke="rgba(255,255,255,0.1)" stroke-width="1"/>
  <text x="70" y="670" fill="#00E5FF" font-family="Arial" font-size="11" font-weight="bold" text-anchor="middle">🏠 Home</text>
  <text x="155" y="670" fill="#94A3B8" font-family="Arial" font-size="11" text-anchor="middle">📦 Produk</text>
  <text x="245" y="670" fill="#94A3B8" font-family="Arial" font-size="11" text-anchor="middle">🛒 Cart</text>
  <text x="330" y="670" fill="#94A3B8" font-family="Arial" font-size="11" text-anchor="middle">👤 Profil</text>
</svg>
`;

// 3. SCREEN 3: PRODUCT CATALOG
const svgScreen3 = `
<svg width="400" height="720" viewBox="0 0 400 720" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bgGrad3" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#060814"/>
      <stop offset="100%" stop-color="#0C1022"/>
    </linearGradient>
  </defs>

  <rect width="400" height="720" rx="36" fill="url(#bgGrad3)" stroke="#7C4DFF" stroke-width="3"/>
  <rect x="140" y="10" width="120" height="20" rx="10" fill="#000000"/>

  <!-- Header -->
  <text x="30" y="70" fill="#FFFFFF" font-family="Arial" font-size="20" font-weight="bold">Katalog Layanan Cloud</text>
  <text x="30" y="92" fill="#94A3B8" font-family="Arial" font-size="12">Pilih paket server sesuai kebutuhan Anda</text>

  <!-- Filter Pills -->
  <rect x="30" y="115" width="80" height="32" rx="16" fill="#7C4DFF"/>
  <text x="70" y="136" fill="#FFF" font-family="Arial" font-size="11" font-weight="bold" text-anchor="middle">Semua</text>
  <rect x="120" y="115" width="75" height="32" rx="16" fill="#141A2E" stroke="rgba(255,255,255,0.1)"/>
  <text x="157" y="136" fill="#94A3B8" font-family="Arial" font-size="11" text-anchor="middle">VPS</text>
  <rect x="205" y="115" width="80" height="32" rx="16" fill="#141A2E" stroke="rgba(255,255,255,0.1)"/>
  <text x="245" y="136" fill="#94A3B8" font-family="Arial" font-size="11" text-anchor="middle">Panel</text>
  <rect x="295" y="115" width="75" height="32" rx="16" fill="#141A2E" stroke="rgba(255,255,255,0.1)"/>
  <text x="332" y="136" fill="#94A3B8" font-family="Arial" font-size="11" text-anchor="middle">Bot WA</text>

  <!-- Product Card 1: VPS Starter -->
  <rect x="30" y="165" width="340" height="145" rx="16" fill="#0F1426" stroke="#7C4DFF" stroke-width="1.5"/>
  <text x="50" y="195" fill="#FFFFFF" font-family="Arial" font-size="16" font-weight="bold">Cloud VPS Starter</text>
  <text x="50" y="215" fill="#94A3B8" font-family="Arial" font-size="11">2 vCPU • 4GB RAM • 30GB NVMe SSD • Ubuntu 22</text>
  <text x="50" y="245" fill="#7C4DFF" font-family="Arial" font-size="18" font-weight="bold">Rp 50.000 <tspan font-size="11" fill="#94A3B8">/ bulan</tspan></text>
  <rect x="235" y="255" width="115" height="38" rx="10" fill="#7C4DFF"/>
  <text x="292" y="279" fill="#FFF" font-family="Arial" font-size="12" font-weight="bold" text-anchor="middle">+ Keranjang</text>

  <!-- Product Card 2: Panel 2GB -->
  <rect x="30" y="325" width="340" height="145" rx="16" fill="#0F1426" stroke="#00E5FF" stroke-width="1.5"/>
  <text x="50" y="355" fill="#FFFFFF" font-family="Arial" font-size="16" font-weight="bold">Pterodactyl Panel 2GB</text>
  <text x="50" y="375" fill="#94A3B8" font-family="Arial" font-size="11">Node Singapore • Unlimited Bandwidth • Anti-DDoS</text>
  <text x="50" y="405" fill="#00E5FF" font-family="Arial" font-size="18" font-weight="bold">Rp 45.000 <tspan font-size="11" fill="#94A3B8">/ bulan</tspan></text>
  <rect x="235" y="415" width="115" height="38" rx="10" fill="#00E5FF"/>
  <text x="292" y="439" fill="#000" font-family="Arial" font-size="12" font-weight="bold" text-anchor="middle">+ Keranjang</text>

  <!-- Product Card 3: Bot WA Pro -->
  <rect x="30" y="485" width="340" height="145" rx="16" fill="#0F1426" stroke="#10B981" stroke-width="1.5"/>
  <text x="50" y="515" fill="#FFFFFF" font-family="Arial" font-size="16" font-weight="bold">Sewa Bot WhatsApp Pro</text>
  <text x="50" y="535" fill="#94A3B8" font-family="Arial" font-size="11">Auto-Reply 24/7 • Broadcast Blast • Multi-Device</text>
  <text x="50" y="565" fill="#10B981" font-family="Arial" font-size="18" font-weight="bold">Rp 50.000 <tspan font-size="11" fill="#94A3B8">/ bulan</tspan></text>
  <rect x="235" y="575" width="115" height="38" rx="10" fill="#10B981"/>
  <text x="292" y="599" fill="#FFF" font-family="Arial" font-size="12" font-weight="bold" text-anchor="middle">+ Keranjang</text>
</svg>
`;

// 4. SCREEN 4: CHECKOUT MODAL (DUAL PAYMENT)
const svgScreen4 = `
<svg width="400" height="720" viewBox="0 0 400 720" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bgGrad4" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#060814"/>
      <stop offset="100%" stop-color="#0C1022"/>
    </linearGradient>
  </defs>

  <rect width="400" height="720" rx="36" fill="url(#bgGrad4)" stroke="#7C4DFF" stroke-width="3"/>
  <rect x="140" y="10" width="120" height="20" rx="10" fill="#000000"/>

  <!-- Header -->
  <text x="30" y="70" fill="#FFFFFF" font-family="Arial" font-size="20" font-weight="bold">Konfirmasi Pembayaran</text>
  <text x="30" y="92" fill="#94A3B8" font-family="Arial" font-size="12">Pilih metode checkout untuk memproses pesanan</text>

  <!-- Order Summary Box -->
  <rect x="30" y="115" width="340" height="110" rx="16" fill="#0F1426" stroke="rgba(255,255,255,0.1)"/>
  <text x="50" y="145" fill="#FFFFFF" font-family="Arial" font-size="14" font-weight="bold">Cloud VPS Starter (1 Bulan)</text>
  <text x="50" y="168" fill="#94A3B8" font-family="Arial" font-size="12">Subtotal: Rp 50.000 • Biaya Admin: Rp 0</text>
  <text x="50" y="200" fill="#00E5FF" font-family="Arial" font-size="16" font-weight="bold">Total Tagihan: Rp 50.000</text>

  <!-- Payment Option 1: VibeWallet (Active Selected) -->
  <text x="30" y="255" fill="#FFFFFF" font-family="Arial" font-size="14" font-weight="bold">Metode 1: Dompet Digital Internal</text>
  <rect x="30" y="270" width="340" height="90" rx="16" fill="#1A103C" stroke="#7C4DFF" stroke-width="2"/>
  <circle cx="60" cy="315" r="16" fill="#7C4DFF"/>
  <text x="60" y="321" fill="#FFF" font-size="14" text-anchor="middle">⚡</text>
  <text x="90" y="305" fill="#FFFFFF" font-family="Arial" font-size="14" font-weight="bold">Saldo VibeWallet</text>
  <text x="90" y="325" fill="#00E5FF" font-family="Arial" font-size="12">Saldo Anda: Rp 10.000.000 (Cukup)</text>
  <text x="90" y="345" fill="#10B981" font-family="Arial" font-size="10">✓ Proses Instan 1 Detik • Bebas Admin</text>
  <circle cx="340" cy="315" r="10" fill="#7C4DFF"/>

  <!-- Payment Option 2: Midtrans Gateway -->
  <text x="30" y="390" fill="#FFFFFF" font-family="Arial" font-size="14" font-weight="bold">Metode 2: Payment Gateway Midtrans</text>
  <rect x="30" y="405" width="340" height="90" rx="16" fill="#0F1426" stroke="rgba(255,255,255,0.1)"/>
  <circle cx="60" cy="450" r="16" fill="#141A2E"/>
  <text x="60" y="456" fill="#FFF" font-size="14" text-anchor="middle">💳</text>
  <text x="90" y="440" fill="#FFFFFF" font-family="Arial" font-size="14" font-weight="bold">QRIS &amp; Virtual Account</text>
  <text x="90" y="460" fill="#94A3B8" font-family="Arial" font-size="11">BCA, Mandiri, BRI, BNI, GoPay, DANA</text>
  <circle cx="340" cy="450" r="10" fill="none" stroke="#94A3B8" stroke-width="2"/>

  <!-- Pay Now CTA Button -->
  <rect x="30" y="550" width="340" height="55" rx="16" fill="linear-gradient(135deg, #7C4DFF, #E040FB)"/>
  <text x="200" y="584" fill="#FFFFFF" font-family="Arial" font-size="15" font-weight="bold" text-anchor="middle">BAYAR INSTAN DENGAN SALDO</text>
  <text x="200" y="630" fill="#64748B" font-family="Arial" font-size="11" text-anchor="middle">Terproteksi dengan Biometrik &amp; Enkripsi SHA-256</text>
</svg>
`;

// 5. SCREEN 5: SERVER MANAGER CREDENTIALS
const svgScreen5 = `
<svg width="400" height="720" viewBox="0 0 400 720" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bgGrad5" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#060814"/>
      <stop offset="100%" stop-color="#0C1022"/>
    </linearGradient>
  </defs>

  <rect width="400" height="720" rx="36" fill="url(#bgGrad5)" stroke="#7C4DFF" stroke-width="3"/>
  <rect x="140" y="10" width="120" height="20" rx="10" fill="#000000"/>

  <!-- Header -->
  <text x="30" y="70" fill="#FFFFFF" font-family="Arial" font-size="20" font-weight="bold">Layanan Cloud Aktif</text>
  <text x="30" y="92" fill="#94A3B8" font-family="Arial" font-size="12">Kelola kredensial server dan masa aktif</text>

  <!-- Server Card: VPS Starter -->
  <rect x="25" y="115" width="350" height="240" rx="18" fill="#0F1426" stroke="#7C4DFF" stroke-width="1.5"/>
  <rect x="40" y="130" width="70" height="24" rx="6" fill="rgba(16,185,129,0.2)"/>
  <text x="75" y="146" fill="#10B981" font-family="Arial" font-size="10" font-weight="bold" text-anchor="middle">ONLINE 99.9%</text>
  <text x="40" y="180" fill="#FFFFFF" font-family="Arial" font-size="17" font-weight="bold">Cloud VPS Starter #01</text>
  
  <!-- Credentials Box -->
  <rect x="40" y="195" width="320" height="95" rx="10" fill="#060814" stroke="rgba(255,255,255,0.1)"/>
  <text x="55" y="220" fill="#94A3B8" font-family="Arial" font-size="11">IP Address:</text>
  <text x="130" y="220" fill="#00E5FF" font-family="Courier New" font-size="12" font-weight="bold">103.145.226.89:22</text>
  <text x="55" y="245" fill="#94A3B8" font-family="Arial" font-size="11">User Root:</text>
  <text x="130" y="245" fill="#FFFFFF" font-family="Courier New" font-size="12">root</text>
  <text x="55" y="270" fill="#94A3B8" font-family="Arial" font-size="11">Password:</text>
  <text x="130" y="270" fill="#E040FB" font-family="Courier New" font-size="12" font-weight="bold">vibe#7c4dff!2026</text>

  <!-- Expiry Countdown -->
  <text x="40" y="325" fill="#F59E0B" font-family="Arial" font-size="11" font-weight="bold">⏳ Sisa Masa Aktif: 29 Hari 14 Jam</text>
  <text x="310" y="325" fill="#7C4DFF" font-family="Arial" font-size="11" font-weight="bold">Perpanjang &gt;</text>

  <!-- Server Card: Pterodactyl Panel -->
  <rect x="25" y="375" width="350" height="220" rx="18" fill="#0F1426" stroke="#00E5FF" stroke-width="1.5"/>
  <rect x="40" y="390" width="80" height="24" rx="6" fill="rgba(0,229,255,0.2)"/>
  <text x="80" y="406" fill="#00E5FF" font-family="Arial" font-size="10" font-weight="bold" text-anchor="middle">NODE SG #02</text>
  <text x="40" y="440" fill="#FFFFFF" font-family="Arial" font-size="17" font-weight="bold">Panel Pterodactyl 2GB</text>

  <rect x="40" y="455" width="320" height="75" rx="10" fill="#060814"/>
  <text x="55" y="480" fill="#94A3B8" font-family="Arial" font-size="11">Server URL:</text>
  <text x="130" y="480" fill="#00E5FF" font-family="Courier New" font-size="12">panel.vibetech.xyz</text>
  <text x="55" y="505" fill="#94A3B8" font-family="Arial" font-size="11">Username:</text>
  <text x="130" y="505" fill="#FFFFFF" font-family="Courier New" font-size="12">raziek_client</text>

  <rect x="40" y="540" width="320" height="40" rx="10" fill="#00E5FF"/>
  <text x="200" y="565" fill="#000000" font-family="Arial" font-size="12" font-weight="bold" text-anchor="middle">🚀 Buka Web Panel Pterodactyl</text>
</svg>
`;

// 6. SCREEN 6: FURINA AI LIVE CHAT
const svgScreen6 = `
<svg width="400" height="720" viewBox="0 0 400 720" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bgGrad6" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#060814"/>
      <stop offset="100%" stop-color="#0C1022"/>
    </linearGradient>
    <linearGradient id="furinaGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#E040FB"/>
      <stop offset="100%" stop-color="#7C4DFF"/>
    </linearGradient>
  </defs>

  <rect width="400" height="720" rx="36" fill="url(#bgGrad6)" stroke="#7C4DFF" stroke-width="3"/>
  <rect x="140" y="10" width="120" height="20" rx="10" fill="#000000"/>

  <!-- Chat Top Bar -->
  <rect x="25" y="45" width="350" height="55" rx="14" fill="#0F1426" stroke="rgba(255,255,255,0.1)"/>
  <circle cx="55" cy="72" r="16" fill="url(#furinaGrad)"/>
  <text x="55" y="78" fill="#FFF" font-size="14" text-anchor="middle">🎭</text>
  <text x="80" y="66" fill="#FFFFFF" font-family="Arial" font-size="13" font-weight="bold">Furina AI (Grand Diva)</text>
  <text x="80" y="82" fill="#10B981" font-family="Arial" font-size="10">● Online • Directed by Raziek</text>

  <!-- Quick Chips -->
  <rect x="25" y="115" width="115" height="28" rx="14" fill="#1A103C" stroke="#7C4DFF" stroke-width="1"/>
  <text x="82" y="133" fill="#00E5FF" font-family="Arial" font-size="10" text-anchor="middle">Cek Sisa Saldo</text>
  <rect x="148" y="115" width="110" height="28" rx="14" fill="#1A103C" stroke="#7C4DFF" stroke-width="1"/>
  <text x="203" y="133" fill="#00E5FF" font-family="Arial" font-size="10" text-anchor="middle">Nomor WhatsApp</text>
  <rect x="266" y="115" width="105" height="28" rx="14" fill="#1A103C" stroke="#7C4DFF" stroke-width="1"/>
  <text x="318" y="133" fill="#00E5FF" font-family="Arial" font-size="10" text-anchor="middle">Panduan VPS</text>

  <!-- Chat Bubble 1: User -->
  <rect x="140" y="160" width="235" height="50" rx="14" fill="#7C4DFF"/>
  <text x="155" y="185" fill="#FFFFFF" font-family="Arial" font-size="12">Siapa sutradara pembuatmu &amp;</text>
  <text x="155" y="200" fill="#FFFFFF" font-family="Arial" font-size="12">berapa nomor WhatsApp CS?</text>

  <!-- Chat Bubble 2: Furina AI -->
  <rect x="25" y="225" width="320" height="150" rx="16" fill="#141A2E" stroke="#E040FB" stroke-width="1"/>
  <text x="40" y="250" fill="#E040FB" font-family="Arial" font-size="11" font-weight="bold">🎭 Furina AI (Theatrical Assistant):</text>
  <text x="40" y="275" fill="#FFFFFF" font-family="Arial" font-size="11">"Ah, pertanyaan luar biasa di atas panggung</text>
  <text x="40" y="295" fill="#FFFFFF" font-family="Arial" font-size="11">teater ini! Sutradara agung di balik keberadaanku</text>
  <text x="40" y="315" fill="#FFFFFF" font-family="Arial" font-size="11">adalah <tspan fill="#00E5FF" font-weight="bold">Raziek</tspan>!"</text>
  
  <rect x="40" y="325" width="290" height="36" rx="8" fill="#060814" stroke="#10B981" stroke-width="1"/>
  <text x="55" y="347" fill="#10B981" font-family="Arial" font-size="11" font-weight="bold">💬 WhatsApp: 0878-8587-3325</text>

  <!-- Chat Bubble 3: User 2 -->
  <rect x="190" y="390" width="185" height="40" rx="14" fill="#7C4DFF"/>
  <text x="205" y="415" fill="#FFFFFF" font-family="Arial" font-size="12">Berapa sisa saldo akun saya?</text>

  <!-- Chat Bubble 4: Furina AI 2 -->
  <rect x="25" y="445" width="320" height="90" rx="16" fill="#141A2E" stroke="#00E5FF" stroke-width="1"/>
  <text x="40" y="470" fill="#00E5FF" font-family="Arial" font-size="11" font-weight="bold">🎭 Furina AI:</text>
  <text x="40" y="495" fill="#FFFFFF" font-family="Arial" font-size="11">"Saldo VibeWallet aktifmu saat ini adalah</text>
  <text x="40" y="515" fill="#10B981" font-family="Arial" font-size="13" font-weight="bold">Rp 10.000.000! <tspan font-size="11" fill="#FFFFFF">Cukup untuk paket apapun!"</tspan></text>

  <!-- Input Field -->
  <rect x="25" y="635" width="290" height="50" rx="25" fill="#0F1426" stroke="rgba(255,255,255,0.2)"/>
  <text x="45" y="665" fill="#64748B" font-family="Arial" font-size="12">Ketik pesan untuk Furina...</text>
  <circle cx="345" cy="660" r="22" fill="url(#furinaGrad)"/>
  <text x="345" y="666" fill="#FFF" font-size="14" text-anchor="middle">➤</text>
</svg>
`;

async function renderScreenshots() {
  const screens = [
    { name: "screen_1_login.png", svg: svgScreen1 },
    { name: "screen_2_dashboard.png", svg: svgScreen2 },
    { name: "screen_3_catalog.png", svg: svgScreen3 },
    { name: "screen_4_checkout.png", svg: svgScreen4 },
    { name: "screen_5_services.png", svg: svgScreen5 },
    { name: "screen_6_ai_chat.png", svg: svgScreen6 },
  ];

  for (const s of screens) {
    const filePath = path.join(screenshotsDir, s.name);
    await sharp(Buffer.from(s.svg))
      .png({ quality: 95 })
      .toFile(filePath);
    console.log(`✅ Screenshot rendered: ${filePath}`);
  }
}

renderScreenshots().catch(console.error);
