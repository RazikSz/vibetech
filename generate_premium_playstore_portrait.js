import fs from 'fs';
import path from 'path';
import sharp from 'sharp';

const OUTPUT_DIR = 'd:/vibetech_xyz_sqflite/vibetech_xyz/assets/playstore_portrait_1080x2400';
if (fs.existsSync(OUTPUT_DIR)) {
  fs.rmSync(OUTPUT_DIR, { recursive: true, force: true });
}
fs.mkdirSync(OUTPUT_DIR, { recursive: true });

function escapeXml(unsafe) {
  if (!unsafe) return '';
  return unsafe
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

// Generate an ultra-premium flagship smartphone mockup with metallic titanium borders, 3D shadows, and glare
async function createUltraPhoneMockup(screenshotPath, accentGlow = '#6366F1', width = 880, height = 1840) {
  const bezel = 18;
  const screenWidth = width - (bezel * 2);
  const screenHeight = height - (bezel * 2);
  const cornerRadius = 46;
  const outerCornerRadius = 60;

  // 1. Resize & sharpen the screenshot
  const resizedScreen = await sharp(screenshotPath)
    .resize(screenWidth, screenHeight, { fit: 'cover', position: 'top' })
    .png()
    .toBuffer();

  // 2. Inner Screen Mask (smooth rounded corners)
  const maskSvg = Buffer.from(`
    <svg width="${screenWidth}" height="${screenHeight}" xmlns="http://www.w3.org/2000/svg">
      <rect x="0" y="0" width="${screenWidth}" height="${screenHeight}" rx="${cornerRadius}" ry="${cornerRadius}" fill="#ffffff"/>
    </svg>
  `);

  const maskedScreen = await sharp(resizedScreen)
    .composite([{ input: maskSvg, blend: 'dest-in' }])
    .png()
    .toBuffer();

  // 3. Titanium Chassis SVG Frame with Glass Sheen & Dynamic Notch
  const chassisSvg = Buffer.from(`
    <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="titaniumBorder" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#94A3B8" />
          <stop offset="20%" stop-color="#334155" />
          <stop offset="50%" stop-color="#0F172A" />
          <stop offset="80%" stop-color="#334155" />
          <stop offset="100%" stop-color="#CBD5E1" />
        </linearGradient>
        
        <linearGradient id="chassisFill" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stop-color="#0F172A" />
          <stop offset="100%" stop-color="#020617" />
        </linearGradient>

        <linearGradient id="screenGlare" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.12" />
          <stop offset="30%" stop-color="#FFFFFF" stop-opacity="0.03" />
          <stop offset="60%" stop-color="#FFFFFF" stop-opacity="0.0" />
        </linearGradient>
      </defs>

      <!-- Outer Chassis -->
      <rect x="3" y="3" width="${width - 6}" height="${height - 6}" rx="${outerCornerRadius}" ry="${outerCornerRadius}" fill="url(#chassisFill)" stroke="url(#titaniumBorder)" stroke-width="5" />
      
      <!-- Inner Screen Base Fill -->
      <rect x="${bezel}" y="${bezel}" width="${screenWidth}" height="${screenHeight}" rx="${cornerRadius}" ry="${cornerRadius}" fill="#0A0E1A" />
    </svg>
  `);

  // Composite the masked screenshot, glass glare, notch pill, and home bar
  const phone = await sharp(chassisSvg)
    .composite([
      {
        input: maskedScreen,
        left: bezel,
        top: bezel,
      },
      {
        input: Buffer.from(`
          <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
            <!-- Screen Diagonal Glass Glare -->
            <path d="M ${bezel} ${bezel} L ${width - bezel} ${bezel} L ${bezel} ${height * 0.45} Z" fill="url(#screenGlare)" opacity="0.7"/>

            <!-- Top Dynamic Island Pill -->
            <g transform="translate(${width / 2}, 30)">
              <rect x="-85" y="0" width="170" height="30" rx="15" fill="#000000" stroke="#1E293B" stroke-width="1"/>
              <!-- Camera Lens Reflection -->
              <circle cx="48" cy="15" r="7" fill="#0A0E1A" />
              <circle cx="46" cy="13" r="2.5" fill="#38BDF8" opacity="0.7"/>
              <circle cx="-50" cy="15" r="4.5" fill="#1E293B" />
            </g>

            <!-- Bottom Home Indicator Bar -->
            <rect x="${width / 2 - 95}" y="${height - 30}" width="190" height="7" rx="3.5" ry="3.5" fill="#FFFFFF" opacity="0.5"/>
          </svg>
        `),
        left: 0,
        top: 0,
      }
    ])
    .png()
    .toBuffer();

  return phone;
}

// 8 High-Impact Showcase Configurations
const SHOWCASES = [
  {
    fileName: '01_playstore_portrait_dashboard.png',
    badge: '⚡ THE ALL-IN-ONE CLOUD APP',
    titleLine1: 'Ekosistem Server &',
    titleHighlight: 'Otomasi No. 1',
    subtitle: 'Sewa Cloud VPS NVMe, Panel Game & Bot WhatsApp 24 Jam Nonstop',
    accent1: '#818CF8', // Indigo
    accent2: '#C084FC', // Purple
    glowColor: '#6366F1',
    screenshot: 'assets/ss_vibetech/Dashboard.png',
    cards: [
      {
        icon: '⚡',
        iconBg: '#4F46E5',
        title: '99.9% Uptime SLA',
        subtitle: 'Infrastruktur Tier-3 NVMe',
        x: 45,
        y: 840,
      },
      {
        icon: '💎',
        iconBg: '#7C3AED',
        title: 'VibeWallet Instant',
        subtitle: 'Checkout Kilat & Auto QRIS',
        x: 650,
        y: 1540,
      },
      {
        icon: '🚀',
        iconBg: '#0284C7',
        title: 'Super Low Latency',
        subtitle: 'Node Jakarta & Singapura',
        x: 45,
        y: 1920,
      },
    ],
  },
  {
    fileName: '02_playstore_portrait_vps.png',
    badge: '💻 HIGH PERFORMANCE CLOUD VPS',
    titleLine1: 'Cloud VPS NVMe',
    titleHighlight: 'Performa Ekstrem',
    subtitle: 'Dedicated Public IP, Full Root Access & Garansi Port 1 Gbps Unmetered',
    accent1: '#38BDF8', // Sky Cyan
    accent2: '#34D399', // Emerald
    glowColor: '#0284C7',
    screenshot: 'assets/ss_vibetech/Produk.png',
    cards: [
      {
        icon: '🌐',
        iconBg: '#0284C7',
        title: '1 Gbps Port Speed',
        subtitle: 'Bandwidth Unmetered Cepat',
        x: 45,
        y: 840,
      },
      {
        icon: '🛡️',
        iconBg: '#059669',
        title: 'Anti-DDoS Shield',
        subtitle: 'Proteksi Serangan 24/7',
        x: 650,
        y: 1540,
      },
      {
        icon: '🐧',
        iconBg: '#6366F1',
        title: 'Multi OS KVM',
        subtitle: 'Ubuntu, Debian & Windows',
        x: 45,
        y: 1920,
      },
    ],
  },
  {
    fileName: '03_playstore_portrait_panel.png',
    badge: '🎮 GAME & WEB APPS HOSTING',
    titleLine1: 'Panel Pterodactyl',
    titleHighlight: 'Deploy Instan',
    subtitle: 'Host Minecraft, SA:MP, FiveM, Node.js, Python dengan Web Console SFTP',
    accent1: '#34D399', // Emerald
    accent2: '#FBBF24', // Amber
    glowColor: '#059669',
    screenshot: 'assets/ss_vibetech/Kartu_layanan.png',
    cards: [
      {
        icon: '🕹️',
        iconBg: '#059669',
        title: 'Game Server Ready',
        subtitle: 'Minecraft, SA:MP & FiveM',
        x: 45,
        y: 840,
      },
      {
        icon: '⚡',
        iconBg: '#D97706',
        title: 'Auto Restart & Backup',
        subtitle: 'Jadwal Otomatis & SFTP',
        x: 650,
        y: 1540,
      },
      {
        icon: '📦',
        iconBg: '#0284C7',
        title: 'Docker Isolated',
        subtitle: 'Node.js, Python & Golang',
        x: 45,
        y: 1920,
      },
    ],
  },
  {
    fileName: '04_playstore_portrait_bot_wa.png',
    badge: '🤖 24/7 WHATSAPP CLOUD AUTOMATION',
    titleLine1: 'Sewa Bot WhatsApp',
    titleHighlight: 'Aktif 24/7 Nonstop',
    subtitle: 'Koneksikan 8-Digit Pairing Code Cepat Tanpa Scan & Tanpa Menyalakan PC',
    accent1: '#4ADE80', // Green
    accent2: '#38BDF8', // Cyan
    glowColor: '#16A34A',
    screenshot: 'assets/ss_vibetech/Kartu_layanan.png',
    cards: [
      {
        icon: '📱',
        iconBg: '#16A34A',
        title: 'Pairing Code 8-Digit',
        subtitle: 'Koneksi Kilat 5 Detik',
        x: 45,
        y: 840,
      },
      {
        icon: '🟢',
        iconBg: '#0284C7',
        title: 'Baileys Multi-Device',
        subtitle: 'Auto-Reply & Broadcast Grup',
        x: 650,
        y: 1540,
      },
      {
        icon: '🔄',
        iconBg: '#7C3AED',
        title: 'Reset Sesi Mandiri',
        subtitle: 'Kendali Sesi Penuh di HP',
        x: 45,
        y: 1920,
      },
    ],
  },
  {
    fileName: '05_playstore_portrait_furina_ai.png',
    badge: '🎭 POWERED BY GOOGLE GEMINI AI',
    titleLine1: 'Furina AI Assistant',
    titleHighlight: 'Konsultan Cerdas',
    subtitle: 'Rekomendasi Spek Server, Troubleshooting Coding Script & Panduan 24 Jam',
    accent1: '#60A5FA', // Sky Blue
    accent2: '#F472B6', // Pink
    glowColor: '#2563EB',
    screenshot: 'assets/ss_vibetech/Live_chat.png',
    cards: [
      {
        icon: '✨',
        iconBg: '#2563EB',
        title: 'Google Gemini Pro',
        subtitle: 'Kecerdasan AI Canggih',
        x: 45,
        y: 840,
      },
      {
        icon: '💡',
        iconBg: '#DB2777',
        title: 'Script & Code Helper',
        subtitle: 'Debug Node.js & Linux Shell',
        x: 650,
        y: 1540,
      },
      {
        icon: '🎭',
        iconBg: '#7C3AED',
        title: 'Persona Diva Teater',
        subtitle: 'Solutif, Ramah & Interaktif',
        x: 45,
        y: 1920,
      },
    ],
  },
  {
    fileName: '06_playstore_portrait_payment.png',
    badge: '💳 AUTOMATED PAYMENT GATEWAY',
    titleLine1: 'Pembayaran Instan',
    titleHighlight: 'QRIS & VA Bank',
    subtitle: 'Pelunasan Otomatis 1-5 Detik via Midtrans Berlisensi Bank Indonesia',
    accent1: '#FBBF24', // Amber
    accent2: '#F97316', // Orange
    glowColor: '#D97706',
    screenshot: 'assets/ss_vibetech/Pembayaran.png',
    cards: [
      {
        icon: '🔒',
        iconBg: '#059669',
        title: 'PCI-DSS Certified',
        subtitle: 'Standar Keamanan Tertinggi',
        x: 45,
        y: 840,
      },
      {
        icon: '📱',
        iconBg: '#D97706',
        title: 'QRIS Semua E-Wallet',
        subtitle: 'BCA, GoPay, OVO, DANA, Shopee',
        x: 650,
        y: 1540,
      },
      {
        icon: '🧾',
        iconBg: '#4F46E5',
        title: 'Auto Invoice Email',
        subtitle: 'Bukti Transaksi Resmi Terbit',
        x: 45,
        y: 1920,
      },
    ],
  },
  {
    fileName: '07_playstore_portrait_management.png',
    badge: '📊 REAL-TIME SERVER DASHBOARD',
    titleLine1: 'Kelola Layanan',
    titleHighlight: 'Pantau Real-Time',
    subtitle: 'Akses Salin IP, Port, Password Server & Pengingat Kadaluarsa Otomatis',
    accent1: '#F472B6', // Rose
    accent2: '#A78BFA', // Violet
    glowColor: '#DB2777',
    screenshot: 'assets/ss_vibetech/Total_Pesanan.png',
    cards: [
      {
        icon: '📡',
        iconBg: '#DB2777',
        title: 'Real-Time Monitoring',
        subtitle: 'Status Server & Node Aktif',
        x: 45,
        y: 840,
      },
      {
        icon: '🔔',
        iconBg: '#7C3AED',
        title: 'Expired Date Alert',
        subtitle: 'Notifikasi Sebelum Expired',
        x: 650,
        y: 1540,
      },
      {
        icon: '📋',
        iconBg: '#0284C7',
        title: '1-Click Copy Data',
        subtitle: 'Salin IP, Port & Password',
        x: 45,
        y: 1920,
      },
    ],
  },
  {
    fileName: '08_playstore_portrait_security.png',
    badge: '🛡️ ENTERPRISE GRADE PRIVACY',
    titleLine1: 'Keamanan Akun',
    titleHighlight: 'Biometrik & UU PDP',
    subtitle: 'Login Sidik Jari/Wajah Lokal, PIN 6-Digit & Sinkronisasi SQLite/Firebase',
    accent1: '#A78BFA', // Purple
    accent2: '#34D399', // Emerald
    glowColor: '#7C3AED',
    screenshot: 'assets/ss_vibetech/Profil.png',
    cards: [
      {
        icon: '🔐',
        iconBg: '#059669',
        title: 'Biometrik Lokal',
        subtitle: 'Hardware Secure Enclave',
        x: 45,
        y: 840,
      },
      {
        icon: '🏛️',
        iconBg: '#7C3AED',
        title: 'UU PDP No. 27/2022',
        subtitle: 'Kepatuhan Hukum Privasi',
        x: 650,
        y: 1540,
      },
      {
        icon: '⚡',
        iconBg: '#4F46E5',
        title: 'SQLite & Firebase',
        subtitle: 'Arsitektur Data Hibrida',
        x: 45,
        y: 1920,
      },
    ],
  },
];

async function generateShowcaseImage(config) {
  const width = 1080;
  const height = 2400;

  // Render SVG Background, Lighting Orbs, Cyber Grid, Glowing Header, and Glassmorphism Cards
  const bgSvg = `
    <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <!-- Master Background Gradient -->
        <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#040711" />
          <stop offset="35%" stop-color="#0A1022" />
          <stop offset="70%" stop-color="#080C1A" />
          <stop offset="100%" stop-color="#020409" />
        </linearGradient>

        <!-- Ambient Atmospheric Glows -->
        <radialGradient id="topAura" cx="50%" cy="16%" r="65%">
          <stop offset="0%" stop-color="${config.glowColor}" stop-opacity="0.45" />
          <stop offset="60%" stop-color="${config.glowColor}" stop-opacity="0.10" />
          <stop offset="100%" stop-color="#000000" stop-opacity="0" />
        </radialGradient>

        <radialGradient id="centerAura" cx="50%" cy="58%" r="55%">
          <stop offset="0%" stop-color="${config.glowColor}" stop-opacity="0.32" />
          <stop offset="100%" stop-color="#000000" stop-opacity="0" />
        </radialGradient>

        <radialGradient id="bottomAura" cx="50%" cy="92%" r="45%">
          <stop offset="0%" stop-color="${config.glowColor}" stop-opacity="0.25" />
          <stop offset="100%" stop-color="#000000" stop-opacity="0" />
        </radialGradient>

        <!-- Title Text Gradient -->
        <linearGradient id="textGrad" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="${config.accent1}" />
          <stop offset="100%" stop-color="${config.accent2}" />
        </linearGradient>

        <!-- Badge Pill Gradient -->
        <linearGradient id="badgeGrad" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="${config.accent1}" stop-opacity="0.28" />
          <stop offset="100%" stop-color="${config.glowColor}" stop-opacity="0.12" />
        </linearGradient>

        <!-- Card Glass Border Gradient -->
        <linearGradient id="cardBorder" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="${config.accent1}" stop-opacity="0.85" />
          <stop offset="50%" stop-color="#334155" stop-opacity="0.3" />
          <stop offset="100%" stop-color="${config.accent2}" stop-opacity="0.8" />
        </linearGradient>

        <!-- Cyber Grid Pattern -->
        <pattern id="cyberGrid" width="60" height="60" patternUnits="userSpaceOnUse">
          <path d="M 60 0 L 0 0 0 60" fill="none" stroke="#1E293B" stroke-width="0.8" stroke-opacity="0.35" />
          <circle cx="60" cy="60" r="1.5" fill="#334155" opacity="0.4" />
        </pattern>
      </defs>

      <!-- 1. Background Base & Cyber Grid -->
      <rect width="${width}" height="${height}" fill="url(#bgGrad)" />
      <rect width="${width}" height="${height}" fill="url(#cyberGrid)" />

      <!-- 2. Ambient Light Flares -->
      <circle cx="540" cy="380" r="620" fill="url(#topAura)" />
      <circle cx="540" cy="1400" r="580" fill="url(#centerAura)" />
      <circle cx="540" cy="2200" r="500" fill="url(#bottomAura)" />

      <!-- 3. Decorative Geometric Vector Waves -->
      <path d="M -50 260 Q 280 180 540 280 T 1130 220" fill="none" stroke="${config.accent1}" stroke-opacity="0.25" stroke-width="2.5" />
      <path d="M -50 680 Q 400 760 800 640 T 1130 720" fill="none" stroke="${config.accent2}" stroke-opacity="0.22" stroke-width="2.5" />
      <circle cx="280" cy="180" r="4" fill="${config.accent1}" opacity="0.6" />
      <circle cx="800" cy="640" r="4" fill="${config.accent2}" opacity="0.6" />

      <!-- 4. Top Header Typography Area -->
      
      <!-- Badge Pill -->
      <g transform="translate(540, 105)">
        <rect x="-210" y="0" width="420" height="48" rx="24" fill="url(#badgeGrad)" stroke="${config.accent1}" stroke-opacity="0.75" stroke-width="1.8" />
        <circle cx="-175" cy="24" r="6.5" fill="${config.accent1}" />
        <text x="-155" y="31.5" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="15" font-weight="800" fill="${config.accent1}" letter-spacing="1.2">
          ${escapeXml(config.badge)}
        </text>
      </g>

      <!-- Main Headline (2-Tier Bold Typography) -->
      <text x="540" y="230" text-anchor="middle" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="62" font-weight="900" fill="#FFFFFF" letter-spacing="-1">
        ${escapeXml(config.titleLine1)}
      </text>

      <text x="540" y="300" text-anchor="middle" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="62" font-weight="900" fill="url(#textGrad)" letter-spacing="-1">
        ${escapeXml(config.titleHighlight)}
      </text>

      <!-- Subtitle Description -->
      <text x="540" y="365" text-anchor="middle" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="23" font-weight="500" fill="#94A3B8">
        ${escapeXml(config.subtitle)}
      </text>

      <!-- Bottom Brand Signature -->
      <g transform="translate(540, 2335)">
        <text x="0" y="0" text-anchor="middle" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="20" font-weight="800" fill="#64748B" letter-spacing="1">
          VIBETECH<tspan fill="${config.accent1}">.XYZ</tspan> • GOOGLE PLAY STORE 2026
        </text>
      </g>
    </svg>
  `;

  // Render Glassmorphism Floating Cards Overlay SVG
  const cardsSvg = `
    <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="cardBorderGrad" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="${config.accent1}" stop-opacity="0.9" />
          <stop offset="40%" stop-color="#475569" stop-opacity="0.4" />
          <stop offset="100%" stop-color="${config.accent2}" stop-opacity="0.85" />
        </linearGradient>

        <linearGradient id="cardFillGrad" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stop-color="#0F172A" stop-opacity="0.96" />
          <stop offset="100%" stop-color="#020617" stop-opacity="0.98" />
        </linearGradient>
      </defs>

      <!-- Render 3 Glass Floating Cards -->
      ${config.cards.map((card) => `
        <g transform="translate(${card.x}, ${card.y})">
          <!-- Card Container -->
          <rect x="0" y="0" width="385" height="96" rx="26" fill="url(#cardFillGrad)" stroke="url(#cardBorderGrad)" stroke-width="2.5" />
          
          <!-- Icon Box -->
          <rect x="18" y="18" width="60" height="60" rx="18" fill="${card.iconBg}" fill-opacity="0.25" stroke="${card.iconBg}" stroke-width="1.5" />
          <text x="48" y="56" text-anchor="middle" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="28">
            ${card.icon}
          </text>

          <!-- Card Content -->
          <text x="94" y="44" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="21" font-weight="800" fill="#FFFFFF">
            ${escapeXml(card.title)}
          </text>
          <text x="94" y="69" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="14.5" font-weight="500" fill="#94A3B8">
            ${escapeXml(card.subtitle)}
          </text>
        </g>
      `).join('')}
    </svg>
  `;

  // 1. Build Flagship Phone Mockup
  const phoneBuf = await createUltraPhoneMockup(config.screenshot, config.glowColor, 880, 1840);

  // 2. Composite Background + Phone Mockup + Floating Glass Cards
  const result = await sharp(Buffer.from(bgSvg))
    .composite([
      // Phone at Center
      {
        input: phoneBuf,
        left: 100,
        top: 430,
      },
      // Floating Glass Cards (Overlapping phone edges)
      {
        input: Buffer.from(cardsSvg),
        left: 0,
        top: 0,
      }
    ])
    .png({ quality: 100, compressionLevel: 8 })
    .toFile(path.join(OUTPUT_DIR, config.fileName));

  console.log(`✨ Generated Premium Showcase: ${config.fileName} (${result.width}x${result.height})`);
}

async function runAll() {
  console.log('🚀 Generating 8 High-End Aesthetic 1080x2400 Play Store Showcases...');
  for (const showcase of SHOWCASES) {
    await generateShowcaseImage(showcase);
  }
  console.log('🎉 All 8 Ultra-Premium Play Store Portrait Showcases Generated Successfully!');
}

runAll().catch((err) => {
  console.error('Error generating premium showcases:', err);
});
