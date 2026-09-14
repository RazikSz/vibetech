import fs from 'fs';
import path from 'path';
import sharp from 'sharp';

const DIR_7_INCH = 'd:/vibetech_xyz_sqflite/vibetech_xyz/assets/playstore_tablet_7_inch';
const DIR_10_INCH = 'd:/vibetech_xyz_sqflite/vibetech_xyz/assets/playstore_tablet_10_inch';
const DIR_CHROMEBOOK = 'd:/vibetech_xyz_sqflite/vibetech_xyz/assets/playstore_chromebook';

[DIR_7_INCH, DIR_10_INCH, DIR_CHROMEBOOK].forEach((dir) => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

function escapeXml(unsafe) {
  if (!unsafe) return '';
  return unsafe
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

const SHOWCASES = [
  {
    fileName: '01_tablet_dashboard.png',
    chromebookName: '01_chromebook_dashboard.png',
    badge: 'ALL-IN-ONE CLOUD ECOSYSTEM',
    titleLine1: 'Ekosistem Server Cloud',
    titleHighlight: '& Otomasi Modern',
    subtitle: 'Sewa Cloud VPS NVMe, Panel Hosting & Bot WhatsApp dalam Satu Aplikasi',
    accent1: '#818CF8',
    accent2: '#C084FC',
    glowColor: '#6366F1',
    screenshot: 'assets/ss_vibetech/Dashboard.png',
  },
  {
    fileName: '02_tablet_vps.png',
    chromebookName: '02_chromebook_vps.png',
    badge: 'HIGH PERFORMANCE CLOUD VPS',
    titleLine1: 'Cloud VPS NVMe',
    titleHighlight: 'Performa Ekstrem & Root Akses',
    subtitle: 'Dedicated Public IP, Port 1 Gbps & Pilihan OS Linux / Windows Lengkap',
    accent1: '#38BDF8',
    accent2: '#34D399',
    glowColor: '#0284C7',
    screenshot: 'assets/ss_vibetech/Produk.png',
  },
  {
    fileName: '03_tablet_panel.png',
    chromebookName: '03_chromebook_panel.png',
    badge: 'GAME & WEB APPS PANEL HOSTING',
    titleLine1: 'Panel Pterodactyl',
    titleHighlight: 'Deploy Server Game & Web',
    subtitle: 'Siap Deploy Minecraft, SA:MP, FiveM, Node.js, Python & SFTP Web Console',
    accent1: '#34D399',
    accent2: '#FBBF24',
    glowColor: '#059669',
    screenshot: 'assets/ss_vibetech/Kartu_layanan.png',
  },
  {
    fileName: '04_tablet_bot_wa.png',
    chromebookName: '04_chromebook_bot_wa.png',
    badge: '24/7 WHATSAPP CLOUD AUTOMATION',
    titleLine1: 'Sewa Bot WhatsApp',
    titleHighlight: 'Aktif 24 Jam Nonstop Cloud',
    subtitle: 'Koneksikan Cepat via Pairing Code 8-Digit Tanpa Scan QR & Tanpa PC',
    accent1: '#4ADE80',
    accent2: '#38BDF8',
    glowColor: '#16A34A',
    screenshot: 'assets/ss_vibetech/Kartu_layanan.png',
  },
  {
    fileName: '05_tablet_furina_ai.png',
    chromebookName: '05_chromebook_furina_ai.png',
    badge: 'POWERED BY GOOGLE GEMINI AI',
    titleLine1: 'Furina AI Assistant',
    titleHighlight: 'Konsultan Server Cerdas',
    subtitle: 'Rekomendasi Spesifikasi, Troubleshooting Script & Bantuan Teknis 24 Jam',
    accent1: '#60A5FA',
    accent2: '#F472B6',
    glowColor: '#2563EB',
    screenshot: 'assets/ss_vibetech/Live_chat.png',
  },
  {
    fileName: '06_tablet_payment.png',
    chromebookName: '06_chromebook_payment.png',
    badge: 'MIDTRANS PAYMENT GATEWAY',
    titleLine1: 'Pembayaran Instan',
    titleHighlight: 'QRIS & Virtual Account Bank',
    subtitle: 'Pelunasan Otomatis 1-5 Detik dengan Invoice Resmi Terkirim ke Email',
    accent1: '#FBBF24',
    accent2: '#F97316',
    glowColor: '#D97706',
    screenshot: 'assets/ss_vibetech/Pembayaran.png',
  },
  {
    fileName: '07_tablet_management.png',
    chromebookName: '07_chromebook_management.png',
    badge: 'REAL-TIME SERVICE MONITORING',
    titleLine1: 'Manajemen Layanan',
    titleHighlight: 'Pantau Status & Masa Aktif',
    subtitle: 'Salin Kredensial Server dengan 1-Klik & Notifikasi Pengingat Expired',
    accent1: '#F472B6',
    accent2: '#A78BFA',
    glowColor: '#DB2777',
    screenshot: 'assets/ss_vibetech/Total_Pesanan.png',
  },
  {
    fileName: '08_tablet_security.png',
    chromebookName: '08_chromebook_security.png',
    badge: 'ENTERPRISE SECURITY & PRIVACY',
    titleLine1: 'Keamanan Terpercaya',
    titleHighlight: 'Biometrik & Kepatuhan UU PDP',
    subtitle: 'Login Sidik Jari Lokal, PIN 6-Digit & Sinkronisasi SQLite / Firebase',
    accent1: '#A78BFA',
    accent2: '#34D399',
    glowColor: '#7C3AED',
    screenshot: 'assets/ss_vibetech/Profil.png',
  },
];

// Tablet Mockup Generator (Portrait Aspect 10:16)
async function createTabletMockup(screenshotPath, width, height, cornerRadius = 40) {
  const bezel = Math.round(width * 0.035);
  const screenWidth = width - bezel * 2;
  const screenHeight = height - bezel * 2;

  const resizedScreen = await sharp(screenshotPath)
    .resize(screenWidth, screenHeight, { fit: 'cover', position: 'top' })
    .png()
    .toBuffer();

  const maskSvg = Buffer.from(`
    <svg width="${screenWidth}" height="${screenHeight}" xmlns="http://www.w3.org/2000/svg">
      <rect x="0" y="0" width="${screenWidth}" height="${screenHeight}" rx="${cornerRadius - 10}" ry="${cornerRadius - 10}" fill="#ffffff"/>
    </svg>
  `);

  const maskedScreen = await sharp(resizedScreen)
    .composite([{ input: maskSvg, blend: 'dest-in' }])
    .png()
    .toBuffer();

  const chassisSvg = Buffer.from(`
    <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="metalBorder" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#94A3B8" />
          <stop offset="25%" stop-color="#475569" />
          <stop offset="50%" stop-color="#1E293B" />
          <stop offset="75%" stop-color="#334155" />
          <stop offset="100%" stop-color="#CBD5E1" />
        </linearGradient>
        <linearGradient id="tabletBody" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stop-color="#0F172A" />
          <stop offset="100%" stop-color="#020617" />
        </linearGradient>
      </defs>
      <rect x="2" y="2" width="${width - 4}" height="${height - 4}" rx="${cornerRadius}" ry="${cornerRadius}" fill="url(#tabletBody)" stroke="url(#metalBorder)" stroke-width="4"/>
      <!-- Front camera sensor dot -->
      <circle cx="${width / 2}" cy="${bezel / 2}" r="5" fill="#1E293B" stroke="#334155" stroke-width="1"/>
      <circle cx="${width / 2}" cy="${bezel / 2}" r="2" fill="#38BDF8" opacity="0.7"/>
    </svg>
  `);

  return await sharp(chassisSvg)
    .composite([
      { input: maskedScreen, left: bezel, top: bezel },
    ])
    .png()
    .toBuffer();
}

// Generate Tablet Showcase Canvas
async function generateTabletShowcase(config, targetWidth, targetHeight, outputFolder) {
  const mockupWidth = Math.round(targetWidth * 0.72);
  const mockupHeight = Math.round(mockupWidth * 1.55);
  const mockupLeft = Math.round((targetWidth - mockupWidth) / 2);
  const mockupTop = Math.round(targetHeight * 0.28);

  const tabletDevice = await createTabletMockup(
    config.screenshot,
    mockupWidth,
    mockupHeight,
    targetWidth > 1400 ? 56 : 42
  );

  const headerSvg = Buffer.from(`
    <svg width="${targetWidth}" height="${targetHeight}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="bgGrad" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stop-color="#0F172A" />
          <stop offset="45%" stop-color="#090D1A" />
          <stop offset="100%" stop-color="#030712" />
        </linearGradient>
        <radialGradient id="aura" cx="50%" cy="30%" r="55%">
          <stop offset="0%" stop-color="${config.glowColor}" stop-opacity="0.22"/>
          <stop offset="60%" stop-color="${config.glowColor}" stop-opacity="0.04"/>
          <stop offset="100%" stop-color="${config.glowColor}" stop-opacity="0"/>
        </radialGradient>
        <linearGradient id="titleGrad" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="${config.accent1}" />
          <stop offset="100%" stop-color="${config.accent2}" />
        </linearGradient>
      </defs>

      <!-- Background with Radial Glow -->
      <rect x="0" y="0" width="${targetWidth}" height="${targetHeight}" fill="url(#bgGrad)" />
      <circle cx="${targetWidth / 2}" cy="${targetHeight * 0.25}" r="${targetWidth * 0.65}" fill="url(#aura)"/>

      <!-- Top Badge -->
      <g transform="translate(${targetWidth / 2}, ${targetHeight * 0.055})">
        <rect x="-240" y="-20" width="480" height="40" rx="20" fill="#1E293B" fill-opacity="0.8" stroke="${config.accent1}" stroke-width="1.5"/>
        <text x="0" y="5" font-family="'Segoe UI', Roboto, Helvetica, sans-serif" font-size="${targetWidth > 1400 ? '22' : '18'}" font-weight="700" fill="${config.accent1}" text-anchor="middle" letter-spacing="2">
          ${escapeXml(config.badge)}
        </text>
      </g>

      <!-- Main Headline -->
      <text x="${targetWidth / 2}" y="${targetHeight * 0.125}" font-family="'Segoe UI', Roboto, Helvetica, sans-serif" font-size="${targetWidth > 1400 ? '60' : '48'}" font-weight="800" fill="#FFFFFF" text-anchor="middle">
        ${escapeXml(config.titleLine1)}
      </text>
      <text x="${targetWidth / 2}" y="${targetHeight * 0.170}" font-family="'Segoe UI', Roboto, Helvetica, sans-serif" font-size="${targetWidth > 1400 ? '58' : '46'}" font-weight="800" fill="url(#titleGrad)" text-anchor="middle">
        ${escapeXml(config.titleHighlight)}
      </text>

      <!-- Subtitle Description -->
      <text x="${targetWidth / 2}" y="${targetHeight * 0.215}" font-family="'Segoe UI', Roboto, Helvetica, sans-serif" font-size="${targetWidth > 1400 ? '26' : '22'}" font-weight="500" fill="#94A3B8" text-anchor="middle">
        ${escapeXml(config.subtitle)}
      </text>
    </svg>
  `);

  const outputPath = path.join(outputFolder, config.fileName);

  await sharp(headerSvg)
    .composite([
      {
        input: tabletDevice,
        left: mockupLeft,
        top: mockupTop,
      },
    ])
    .png({ quality: 95, compressionLevel: 8 })
    .toFile(outputPath);

  console.log(`[Tablet Generated] -> ${outputPath} (${targetWidth}x${targetHeight})`);
}

// Generate Chromebook Showcase (Landscape 16:9 - 1920x1080)
async function generateChromebookShowcase(config) {
  const targetWidth = 1920;
  const targetHeight = 1080;

  const phoneMockupWidth = 380;
  const phoneMockupHeight = 780;
  const phoneMockup = await createTabletMockup(config.screenshot, phoneMockupWidth, phoneMockupHeight, 32);

  const svgContent = Buffer.from(`
    <svg width="${targetWidth}" height="${targetHeight}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="bgGradCb" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#0F172A" />
          <stop offset="50%" stop-color="#090D1A" />
          <stop offset="100%" stop-color="#020617" />
        </linearGradient>
        <radialGradient id="auraCb" cx="75%" cy="50%" r="50%">
          <stop offset="0%" stop-color="${config.glowColor}" stop-opacity="0.25"/>
          <stop offset="70%" stop-color="${config.glowColor}" stop-opacity="0.03"/>
          <stop offset="100%" stop-color="${config.glowColor}" stop-opacity="0"/>
        </radialGradient>
        <linearGradient id="titleGradCb" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="${config.accent1}" />
          <stop offset="100%" stop-color="${config.accent2}" />
        </linearGradient>
      </defs>

      <!-- Background -->
      <rect x="0" y="0" width="${targetWidth}" height="${targetHeight}" fill="url(#bgGradCb)" />
      <circle cx="1400" cy="540" r="700" fill="url(#auraCb)" />

      <!-- Left Side Copy -->
      <g transform="translate(140, 320)">
        <!-- Badge -->
        <rect x="0" y="0" width="380" height="42" rx="21" fill="#1E293B" stroke="${config.accent1}" stroke-width="1.5"/>
        <text x="190" y="27" font-family="'Segoe UI', Roboto, sans-serif" font-size="16" font-weight="700" fill="${config.accent1}" text-anchor="middle" letter-spacing="1.5">
          ${escapeXml(config.badge)}
        </text>

        <!-- Title -->
        <text x="0" y="110" font-family="'Segoe UI', Roboto, sans-serif" font-size="52" font-weight="800" fill="#FFFFFF">
          ${escapeXml(config.titleLine1)}
        </text>
        <text x="0" y="175" font-family="'Segoe UI', Roboto, sans-serif" font-size="50" font-weight="800" fill="url(#titleGradCb)">
          ${escapeXml(config.titleHighlight)}
        </text>

        <!-- Subtitle -->
        <text x="0" y="240" font-family="'Segoe UI', Roboto, sans-serif" font-size="22" font-weight="500" fill="#94A3B8">
          ${escapeXml(config.subtitle)}
        </text>

        <!-- Features list -->
        <g transform="translate(0, 300)">
          <circle cx="10" cy="-5" r="5" fill="${config.accent1}"/>
          <text x="28" y="0" font-family="'Segoe UI', Roboto, sans-serif" font-size="19" font-weight="600" fill="#E2E8F0">
            Performa Stabil &amp; Database Terproteksi 100%
          </text>

          <circle cx="10" cy="40" r="5" fill="${config.accent2}"/>
          <text x="28" y="45" font-family="'Segoe UI', Roboto, sans-serif" font-size="19" font-weight="600" fill="#E2E8F0">
            Sinkronisasi Otomatis Cloud SQLite &amp; Firebase RTDB
          </text>

          <circle cx="10" cy="85" r="5" fill="${config.accent1}"/>
          <text x="28" y="90" font-family="'Segoe UI', Roboto, sans-serif" font-size="19" font-weight="600" fill="#E2E8F0">
            Dukungan Resmi Google Play Store (64-Bit &amp; 16 KB Page Aligned)
          </text>
        </g>
      </g>
    </svg>
  `);

  const outputPath = path.join(DIR_CHROMEBOOK, config.chromebookName);

  await sharp(svgContent)
    .composite([
      {
        input: phoneMockup,
        left: 1250,
        top: 150,
      },
    ])
    .png({ quality: 95, compressionLevel: 8 })
    .toFile(outputPath);

  console.log(`[Chromebook Generated] -> ${outputPath} (1920x1080)`);
}

async function run() {
  console.log('--- Memulai Render Aset Tablet & Chromebook Google Play Store ---');

  for (const showcase of SHOWCASES) {
    // 1. Tablet 7 Inci: 1200 x 1920
    await generateTabletShowcase(showcase, 1200, 1920, DIR_7_INCH);

    // 2. Tablet 10 Inci: 1600 x 2560
    await generateTabletShowcase(showcase, 1600, 2560, DIR_10_INCH);

    // 3. Chromebook Landscape: 1920 x 1080
    await generateChromebookShowcase(showcase);
  }

  console.log('--- Seluruh Aset Tablet 7", Tablet 10", dan Chromebook Selesai Dibuat 100% ---');
}

run().catch((err) => {
  console.error('Error generating tablet assets:', err);
  process.exit(1);
});
