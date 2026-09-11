import fs from 'fs';
import path from 'path';
import sharp from 'sharp';

const OUTPUT_DIR = 'd:/vibetech_xyz_sqflite/vibetech_xyz/assets/playstore_portrait_1080x2400';
if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

function escapeXml(unsafe) {
  if (!unsafe) return '';
  return unsafe
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

// Generate a Figma-grade, borderless flagship phone with realistic 3D shadow and bottom bleed
async function createFigmaPhoneMockup(screenshotPath, accentGlow, width = 960, height = 2020) {
  const bezel = 12;
  const screenWidth = width - (bezel * 2);
  const screenHeight = height - (bezel * 2);
  const cornerRadius = 46;
  const outerCornerRadius = 56;

  // 1. Resize & sharpen screenshot
  const resizedScreen = await sharp(screenshotPath)
    .resize(screenWidth, screenHeight, { fit: 'cover', position: 'top' })
    .png()
    .toBuffer();

  // 2. Inner screen smooth mask
  const maskSvg = Buffer.from(`
    <svg width="${screenWidth}" height="${screenHeight}" xmlns="http://www.w3.org/2000/svg">
      <rect x="0" y="0" width="${screenWidth}" height="${screenHeight}" rx="${cornerRadius}" ry="${cornerRadius}" fill="#ffffff"/>
    </svg>
  `);

  const maskedScreen = await sharp(resizedScreen)
    .composite([{ input: maskSvg, blend: 'dest-in' }])
    .png()
    .toBuffer();

  // 3. Ultra-thin titanium chassis
  const chassisSvg = Buffer.from(`
    <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="titaniumRim" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#E2E8F0" />
          <stop offset="15%" stop-color="#475569" />
          <stop offset="50%" stop-color="#1E293B" />
          <stop offset="85%" stop-color="#334155" />
          <stop offset="100%" stop-color="#94A3B8" />
        </linearGradient>
        <linearGradient id="chassisBack" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stop-color="#0F172A" />
          <stop offset="100%" stop-color="#020617" />
        </linearGradient>
      </defs>
      <rect x="2" y="2" width="${width - 4}" height="${height - 4}" rx="${outerCornerRadius}" ry="${outerCornerRadius}" fill="url(#chassisBack)" stroke="url(#titaniumRim)" stroke-width="3" />
      <rect x="${bezel}" y="${bezel}" width="${screenWidth}" height="${screenHeight}" rx="${cornerRadius}" ry="${cornerRadius}" fill="#0A0E1A" />
    </svg>
  `);

  // Composite screen, top dynamic punch notch, and bottom home bar
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
            <!-- Dynamic Island Notch -->
            <g transform="translate(${width / 2}, 24)">
              <rect x="-70" y="0" width="140" height="24" rx="12" fill="#000000" />
              <circle cx="36" cy="12" r="5" fill="#0F172A" />
              <circle cx="34.5" cy="10.5" r="1.8" fill="#38BDF8" opacity="0.8"/>
              <circle cx="-40" cy="12" r="3.5" fill="#1E293B" />
            </g>
            <!-- Bottom Home Indicator -->
            <rect x="${width / 2 - 90}" y="${height - 24}" width="180" height="6" rx="3" fill="#FFFFFF" opacity="0.4"/>
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

const FIGMA_SHOWCASES = [
  {
    fileName: '01_playstore_portrait_dashboard.png',
    tag: 'ALL-IN-ONE CLOUD ECOSYSTEM',
    title: 'Infrastruktur Server',
    highlight: '& Otomasi Cloud',
    subtitle: 'Kelola VPS NVMe, Panel Game & Bot WhatsApp dalam Satu Aplikasi',
    accent1: '#818CF8',
    accent2: '#C084FC',
    glowColor: '#6366F1',
    screenshot: 'assets/ss_vibetech/Dashboard.png',
  },
  {
    fileName: '02_playstore_portrait_vps.png',
    tag: 'HIGH PERFORMANCE CLOUD VPS',
    title: 'Cloud VPS NVMe',
    highlight: 'Performa Ekstrem & Root Akses',
    subtitle: 'Dedicated IP, Port 1 Gbps Unmetered & Pilihan OS Linux / Windows',
    accent1: '#38BDF8',
    accent2: '#34D399',
    glowColor: '#0284C7',
    screenshot: 'assets/ss_vibetech/Produk.png',
  },
  {
    fileName: '03_playstore_portrait_panel.png',
    tag: 'GAME & WEB PANEL HOSTING',
    title: 'Panel Pterodactyl',
    highlight: 'Deploy Server Game & Web',
    subtitle: 'Minecraft, SA:MP, FiveM, Node.js, Python dengan Web Console & SFTP',
    accent1: '#34D399',
    accent2: '#FBBF24',
    glowColor: '#059669',
    screenshot: 'assets/ss_vibetech/Kartu_layanan.png',
  },
  {
    fileName: '04_playstore_portrait_bot_wa.png',
    tag: '24/7 WHATSAPP AUTOMATION',
    title: 'Sewa Bot WhatsApp',
    highlight: 'Online 24 Jam di Cloud',
    subtitle: 'Koneksikan Pairing Code 8-Digit Instan Tanpa Scan QR & Tanpa PC',
    accent1: '#4ADE80',
    accent2: '#38BDF8',
    glowColor: '#16A34A',
    screenshot: 'assets/ss_vibetech/Kartu_layanan.png',
  },
  {
    fileName: '05_playstore_portrait_furina_ai.png',
    tag: 'POWERED BY GOOGLE GEMINI AI',
    title: 'Furina AI Assistant',
    highlight: 'Konsultan Server Cerdas',
    subtitle: 'Rekomendasi Spesifikasi, Troubleshooting Script & Bantuan 24/7',
    accent1: '#60A5FA',
    accent2: '#F472B6',
    glowColor: '#2563EB',
    screenshot: 'assets/ss_vibetech/Live_chat.png',
  },
  {
    fileName: '06_playstore_portrait_payment.png',
    tag: 'MIDTRANS PAYMENT GATEWAY',
    title: 'Pembayaran Instan',
    highlight: 'QRIS & Virtual Account',
    subtitle: 'Verifikasi Pelunasan 1-5 Detik Otomatis dengan Invoice Resmi',
    accent1: '#FBBF24',
    accent2: '#F97316',
    glowColor: '#D97706',
    screenshot: 'assets/ss_vibetech/Pembayaran.png',
  },
  {
    fileName: '07_playstore_portrait_management.png',
    tag: 'REAL-TIME SERVICE MONITORING',
    title: 'Manajemen Layanan',
    highlight: 'Pantau Status & Masa Aktif',
    subtitle: 'Salin Kredensial Server 1-Klik & Notifikasi Pengingat Expired',
    accent1: '#F472B6',
    accent2: '#A78BFA',
    glowColor: '#DB2777',
    screenshot: 'assets/ss_vibetech/Total_Pesanan.png',
  },
  {
    fileName: '08_playstore_portrait_security.png',
    tag: 'ENTERPRISE SECURITY & PRIVACY',
    title: 'Keamanan Terpercaya',
    highlight: 'Biometrik & UU PDP No. 27',
    subtitle: 'Login Sidik Jari Lokal, PIN 6-Digit & Database Hibrida SQLite/Firebase',
    accent1: '#A78BFA',
    accent2: '#34D399',
    glowColor: '#7C3AED',
    screenshot: 'assets/ss_vibetech/Profil.png',
  },
];

async function generateFigmaStyle(config) {
  const width = 1080;
  const height = 2400;

  // Background SVG with Rich Gradient, Soft Spotlight, and Modern Typography
  const bgSvg = `
    <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <!-- Deep Cinematic Dark Background -->
        <linearGradient id="bgGradient" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#060914" />
          <stop offset="30%" stop-color="#0E162B" />
          <stop offset="70%" stop-color="#0A1020" />
          <stop offset="100%" stop-color="#03050C" />
        </linearGradient>

        <!-- Top Spotlight Glow -->
        <radialGradient id="topSpotlight" cx="50%" cy="12%" r="60%">
          <stop offset="0%" stop-color="${config.glowColor}" stop-opacity="0.45" />
          <stop offset="50%" stop-color="${config.glowColor}" stop-opacity="0.10" />
          <stop offset="100%" stop-color="#000000" stop-opacity="0" />
        </radialGradient>

        <!-- Device Ambient Backlight -->
        <radialGradient id="deviceAura" cx="50%" cy="52%" r="50%">
          <stop offset="0%" stop-color="${config.glowColor}" stop-opacity="0.30" />
          <stop offset="100%" stop-color="#000000" stop-opacity="0" />
        </radialGradient>

        <!-- Text Highlight Gradient -->
        <linearGradient id="textGrad" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="${config.accent1}" />
          <stop offset="100%" stop-color="${config.accent2}" />
        </linearGradient>

        <!-- Tag Badge Gradient -->
        <linearGradient id="tagGrad" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="${config.accent1}" stop-opacity="0.25" />
          <stop offset="100%" stop-color="${config.glowColor}" stop-opacity="0.08" />
        </linearGradient>
      </defs>

      <!-- Background Base -->
      <rect width="${width}" height="${height}" fill="url(#bgGradient)" />

      <!-- Ambient Lighting Spotlights -->
      <circle cx="540" cy="280" r="550" fill="url(#topSpotlight)" />
      <circle cx="540" cy="1300" r="600" fill="url(#deviceAura)" />

      <!-- Minimalist Category Tag Pill -->
      <g transform="translate(540, 85)">
        <rect x="-190" y="0" width="380" height="42" rx="21" fill="url(#tagGrad)" stroke="${config.accent1}" stroke-opacity="0.6" stroke-width="1.5" />
        <circle cx="-160" cy="21" r="5" fill="${config.accent1}" />
        <text x="-142" y="27" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="14" font-weight="800" fill="${config.accent1}" letter-spacing="1.2">
          ${escapeXml(config.tag)}
        </text>
      </g>

      <!-- Main Headline Line 1 (Large, Bold, Clean) -->
      <text x="540" y="200" text-anchor="middle" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="64" font-weight="900" fill="#FFFFFF" letter-spacing="-1">
        ${escapeXml(config.title)}
      </text>

      <!-- Headline Highlight Line 2 (Vibrant Brand Gradient) -->
      <text x="540" y="272" text-anchor="middle" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="64" font-weight="900" fill="url(#textGrad)" letter-spacing="-1">
        ${escapeXml(config.highlight)}
      </text>

      <!-- Subtitle Description (Refined, High Readability) -->
      <text x="540" y="335" text-anchor="middle" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="23" font-weight="400" fill="#94A3B8">
        ${escapeXml(config.subtitle)}
      </text>
    </svg>
  `;

  // 1. Build Large Borderless Phone Mockup (Width 960px, Height 2020px)
  const phoneBuf = await createFigmaPhoneMockup(config.screenshot, config.glowColor, 960, 2020);

  // 2. Composite Phone onto Background (Left: 60px, Top: 390px - Bleeding off bottom edge)
  const result = await sharp(Buffer.from(bgSvg))
    .composite([
      {
        input: phoneBuf,
        left: 60,
        top: 390,
      },
    ])
    .png({ quality: 100, compressionLevel: 8 })
    .toFile(path.join(OUTPUT_DIR, config.fileName));

  console.log(`🚀 Generated Figma-Grade Showcase: ${config.fileName} (${result.width}x${result.height})`);
}

async function runAll() {
  console.log('✨ Generating 8 Figma-Grade 1080x2400 Play Store Showcases...');
  for (const showcase of FIGMA_SHOWCASES) {
    await generateFigmaStyle(showcase);
  }
  console.log('🎉 All 8 Figma-Grade Play Store Showcases Completed!');
}

runAll().catch((err) => {
  console.error('Error generating Figma-style showcases:', err);
});
