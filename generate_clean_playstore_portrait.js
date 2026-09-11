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

// Generate an ultra-clean flagship smartphone mockup with pristine titanium bezel & realistic shadows (NO ICONS / NO OVERLAYS)
async function createCleanPhoneMockup(screenshotPath, accentColor = '#6366F1', width = 910, height = 1880) {
  const bezel = 18;
  const screenWidth = width - (bezel * 2);
  const screenHeight = height - (bezel * 2);
  const cornerRadius = 48;
  const outerCornerRadius = 64;

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

  // 3. Premium Titanium Frame SVG
  const chassisSvg = Buffer.from(`
    <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="titaniumBorder" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#94A3B8" />
          <stop offset="15%" stop-color="#475569" />
          <stop offset="50%" stop-color="#1E293B" />
          <stop offset="85%" stop-color="#334155" />
          <stop offset="100%" stop-color="#CBD5E1" />
        </linearGradient>
        
        <linearGradient id="chassisFill" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stop-color="#0F172A" />
          <stop offset="100%" stop-color="#020617" />
        </linearGradient>

        <linearGradient id="screenGlare" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.08" />
          <stop offset="25%" stop-color="#FFFFFF" stop-opacity="0.02" />
          <stop offset="50%" stop-color="#FFFFFF" stop-opacity="0.0" />
        </linearGradient>
      </defs>

      <!-- Outer Phone Body -->
      <rect x="3" y="3" width="${width - 6}" height="${height - 6}" rx="${outerCornerRadius}" ry="${outerCornerRadius}" fill="url(#chassisFill)" stroke="url(#titaniumBorder)" stroke-width="5" />
      
      <!-- Inner Screen Base Fill -->
      <rect x="${bezel}" y="${bezel}" width="${screenWidth}" height="${screenHeight}" rx="${cornerRadius}" ry="${cornerRadius}" fill="#0A0E1A" />
    </svg>
  `);

  // Composite masked screen, top notch pill, and bottom bar
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
            <!-- Screen Diagonal Glare -->
            <path d="M ${bezel} ${bezel} L ${width - bezel} ${bezel} L ${bezel} ${height * 0.40} Z" fill="url(#screenGlare)"/>

            <!-- Top Camera Notch -->
            <g transform="translate(${width / 2}, 30)">
              <rect x="-85" y="0" width="170" height="28" rx="14" fill="#000000" stroke="#1E293B" stroke-width="1"/>
              <circle cx="48" cy="14" r="6.5" fill="#0A0E1A" />
              <circle cx="46" cy="12.5" r="2.2" fill="#38BDF8" opacity="0.6"/>
              <circle cx="-50" cy="14" r="4" fill="#1E293B" />
            </g>

            <!-- Bottom Home Indicator Bar -->
            <rect x="${width / 2 - 95}" y="${height - 30}" width="190" height="7" rx="3.5" ry="3.5" fill="#FFFFFF" opacity="0.45"/>
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

// 8 Clean, Professional Showcases
const CLEAN_SHOWCASES = [
  {
    fileName: '01_playstore_portrait_dashboard.png',
    badge: 'ALL-IN-ONE CLOUD ECOSYSTEM',
    titleLine1: 'Ekosistem Server Cloud',
    titleHighlight: '& Otomasi Modern',
    subtitle: 'Sewa Cloud VPS NVMe, Panel Hosting & Bot WhatsApp dalam Satu Aplikasi',
    accent1: '#818CF8', // Indigo
    accent2: '#C084FC', // Purple
    glowColor: '#6366F1',
    screenshot: 'assets/ss_vibetech/Dashboard.png',
  },
  {
    fileName: '02_playstore_portrait_vps.png',
    badge: 'HIGH PERFORMANCE CLOUD VPS',
    titleLine1: 'Cloud VPS NVMe',
    titleHighlight: 'Performa Ekstrem & Root Akses',
    subtitle: 'Dedicated Public IP, Port 1 Gbps & Pilihan OS Linux / Windows Lengkap',
    accent1: '#38BDF8', // Cyan
    accent2: '#34D399', // Emerald
    glowColor: '#0284C7',
    screenshot: 'assets/ss_vibetech/Produk.png',
  },
  {
    fileName: '03_playstore_portrait_panel.png',
    badge: 'GAME & WEB APPS PANEL HOSTING',
    titleLine1: 'Panel Pterodactyl',
    titleHighlight: 'Deploy Server Game & Web',
    subtitle: 'Siap Deploy Minecraft, SA:MP, FiveM, Node.js, Python & Web Console SFTP',
    accent1: '#34D399', // Emerald
    accent2: '#FBBF24', // Amber
    glowColor: '#059669',
    screenshot: 'assets/ss_vibetech/Kartu_layanan.png',
  },
  {
    fileName: '04_playstore_portrait_bot_wa.png',
    badge: '24/7 WHATSAPP CLOUD AUTOMATION',
    titleLine1: 'Sewa Bot WhatsApp',
    titleHighlight: 'Aktif 24 Jam Nonstop Cloud',
    subtitle: 'Koneksikan Cepat via Pairing Code 8-Digit Tanpa Scan QR & Tanpa PC',
    accent1: '#4ADE80', // Green
    accent2: '#38BDF8', // Cyan
    glowColor: '#16A34A',
    screenshot: 'assets/ss_vibetech/Kartu_layanan.png',
  },
  {
    fileName: '05_playstore_portrait_furina_ai.png',
    badge: 'POWERED BY GOOGLE GEMINI AI',
    titleLine1: 'Furina AI Assistant',
    titleHighlight: 'Konsultan Server Cerdas',
    subtitle: 'Rekomendasi Spesifikasi, Troubleshooting Script & Bantuan Teknis 24 Jam',
    accent1: '#60A5FA', // Sky Blue
    accent2: '#F472B6', // Pink
    glowColor: '#2563EB',
    screenshot: 'assets/ss_vibetech/Live_chat.png',
  },
  {
    fileName: '06_playstore_portrait_payment.png',
    badge: 'MIDTRANS PAYMENT GATEWAY',
    titleLine1: 'Pembayaran Instan',
    titleHighlight: 'QRIS & Virtual Account Bank',
    subtitle: 'Pelunasan Otomatis 1-5 Detik dengan Invoice Resmi Terkirim ke Email',
    accent1: '#FBBF24', // Amber
    accent2: '#F97316', // Orange
    glowColor: '#D97706',
    screenshot: 'assets/ss_vibetech/Pembayaran.png',
  },
  {
    fileName: '07_playstore_portrait_management.png',
    badge: 'REAL-TIME SERVICE MONITORING',
    titleLine1: 'Manajemen Layanan',
    titleHighlight: 'Pantau Status & Masa Aktif',
    subtitle: 'Salin Kredensial Server dengan 1-Klik & Notifikasi Pengingat Expired',
    accent1: '#F472B6', // Rose
    accent2: '#A78BFA', // Violet
    glowColor: '#DB2777',
    screenshot: 'assets/ss_vibetech/Total_Pesanan.png',
  },
  {
    fileName: '08_playstore_portrait_security.png',
    badge: 'ENTERPRISE SECURITY & PRIVACY',
    titleLine1: 'Keamanan Terpercaya',
    titleHighlight: 'Biometrik & Kepatuhan UU PDP',
    subtitle: 'Login Sidik Jari Lokal, PIN 6-Digit & Sinkronisasi SQLite / Firebase',
    accent1: '#A78BFA', // Purple
    accent2: '#34D399', // Emerald
    glowColor: '#7C3AED',
    screenshot: 'assets/ss_vibetech/Profil.png',
  },
];

async function generateCleanShowcase(config) {
  const width = 1080;
  const height = 2400;

  // Background & Clean Typography SVG (NO ICONS / NO CARTOON BADGES)
  const bgSvg = `
    <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <!-- Master Clean Background Gradient -->
        <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#050813" />
          <stop offset="35%" stop-color="#0B1224" />
          <stop offset="70%" stop-color="#080C1A" />
          <stop offset="100%" stop-color="#03050C" />
        </linearGradient>

        <!-- Elegant Atmospheric Glows -->
        <radialGradient id="topGlow" cx="50%" cy="15%" r="65%">
          <stop offset="0%" stop-color="${config.glowColor}" stop-opacity="0.40" />
          <stop offset="60%" stop-color="${config.glowColor}" stop-opacity="0.08" />
          <stop offset="100%" stop-color="#000000" stop-opacity="0" />
        </radialGradient>

        <radialGradient id="phoneBackdropGlow" cx="50%" cy="60%" r="55%">
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
          <stop offset="0%" stop-color="${config.accent1}" stop-opacity="0.22" />
          <stop offset="100%" stop-color="${config.glowColor}" stop-opacity="0.08" />
        </linearGradient>

        <!-- Modern Subtle Grid Pattern -->
        <pattern id="modernGrid" width="60" height="60" patternUnits="userSpaceOnUse">
          <path d="M 60 0 L 0 0 0 60" fill="none" stroke="#1E293B" stroke-width="0.75" stroke-opacity="0.30" />
        </pattern>
      </defs>

      <!-- 1. Background Fill & Grid -->
      <rect width="${width}" height="${height}" fill="url(#bgGrad)" />
      <rect width="${width}" height="${height}" fill="url(#modernGrid)" />

      <!-- 2. Ambient Lighting Auras -->
      <circle cx="540" cy="360" r="600" fill="url(#topGlow)" />
      <circle cx="540" cy="1450" r="580" fill="url(#phoneBackdropGlow)" />

      <!-- 3. Sleek Geometric Lines -->
      <path d="M -50 240 Q 300 170 540 250 T 1130 200" fill="none" stroke="${config.accent1}" stroke-opacity="0.20" stroke-width="2" />
      <path d="M -50 440 Q 400 490 800 420 T 1130 460" fill="none" stroke="${config.accent2}" stroke-opacity="0.18" stroke-width="2" />

      <!-- 4. Top Header Typography (Centered & Clean) -->
      
      <!-- Minimalist Pill Badge -->
      <g transform="translate(540, 100)">
        <rect x="-190" y="0" width="380" height="44" rx="22" fill="url(#badgeGrad)" stroke="${config.accent1}" stroke-opacity="0.65" stroke-width="1.6" />
        <circle cx="-160" cy="22" r="5" fill="${config.accent1}" />
        <text x="-142" y="28.5" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="14.5" font-weight="800" fill="${config.accent1}" letter-spacing="1.2">
          ${escapeXml(config.badge)}
        </text>
      </g>

      <!-- Main Headline Line 1 -->
      <text x="540" y="225" text-anchor="middle" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="62" font-weight="900" fill="#FFFFFF" letter-spacing="-1">
        ${escapeXml(config.titleLine1)}
      </text>

      <!-- Main Headline Line 2 (Glowing Color Accent) -->
      <text x="540" y="295" text-anchor="middle" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="62" font-weight="900" fill="url(#textGrad)" letter-spacing="-1">
        ${escapeXml(config.titleHighlight)}
      </text>

      <!-- Clean 1-Line Subtitle -->
      <text x="540" y="360" text-anchor="middle" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="23" font-weight="400" fill="#94A3B8">
        ${escapeXml(config.subtitle)}
      </text>

      <!-- Bottom Brand Mark -->
      <g transform="translate(540, 2340)">
        <text x="0" y="0" text-anchor="middle" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="19" font-weight="700" fill="#64748B" letter-spacing="1.5">
          VIBETECH<tspan fill="${config.accent1}">.XYZ</tspan> • GOOGLE PLAY STORE
        </text>
      </g>
    </svg>
  `;

  // 1. Build Flagship Phone Mockup (Completely Clean, No Overlays)
  const phoneBuf = await createCleanPhoneMockup(config.screenshot, config.glowColor, 910, 1880);

  // 2. Composite Background + Phone Mockup
  const result = await sharp(Buffer.from(bgSvg))
    .composite([
      {
        input: phoneBuf,
        left: 85,
        top: 415,
      },
    ])
    .png({ quality: 100, compressionLevel: 8 })
    .toFile(path.join(OUTPUT_DIR, config.fileName));

  console.log(`✅ Generated Clean Showcase: ${config.fileName} (${result.width}x${result.height})`);
}

async function runAll() {
  console.log('🚀 Generating 8 Clean, High-End Aesthetic 1080x2400 Play Store Showcases (NO ICONS)...');
  for (const showcase of CLEAN_SHOWCASES) {
    await generateCleanShowcase(showcase);
  }
  console.log('🎉 All 8 Clean Play Store Showcases Generated Successfully!');
}

runAll().catch((err) => {
  console.error('Error generating clean showcases:', err);
});
