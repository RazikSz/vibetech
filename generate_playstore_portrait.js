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

// Create a large, high-res smartphone mockup for 1080x2400 canvas
async function createPortraitPhoneMockup(screenshotPath, width = 860, height = 1820) {
  const bezelThickness = 16;
  const screenWidth = width - (bezelThickness * 2);
  const screenHeight = height - (bezelThickness * 2);
  const cornerRadius = 46;
  const outerCornerRadius = 58;

  // 1. Resize screenshot to fill screen area
  const resizedScreen = await sharp(screenshotPath)
    .resize(screenWidth, screenHeight, { fit: 'cover', position: 'top' })
    .toBuffer();

  // 2. SVG Mask for rounded corners of inner screen
  const maskSvg = Buffer.from(`
    <svg width="${screenWidth}" height="${screenHeight}" xmlns="http://www.w3.org/2000/svg">
      <rect x="0" y="0" width="${screenWidth}" height="${screenHeight}" rx="${cornerRadius}" ry="${cornerRadius}" fill="#ffffff"/>
    </svg>
  `);

  const maskedScreen = await sharp(resizedScreen)
    .composite([{ input: maskSvg, blend: 'dest-in' }])
    .png()
    .toBuffer();

  // 3. Phone Chassis Frame SVG
  const chassisSvg = Buffer.from(`
    <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="chassisBorder" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#64748B"/>
          <stop offset="25%" stop-color="#334155"/>
          <stop offset="50%" stop-color="#1E293B"/>
          <stop offset="75%" stop-color="#0F172A"/>
          <stop offset="100%" stop-color="#94A3B8"/>
        </linearGradient>
        <linearGradient id="chassisBody" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stop-color="#0F172A"/>
          <stop offset="100%" stop-color="#020617"/>
        </linearGradient>
      </defs>
      
      <!-- Outer Phone Body -->
      <rect x="2" y="2" width="${width - 4}" height="${height - 4}" rx="${outerCornerRadius}" ry="${outerCornerRadius}" fill="url(#chassisBody)" stroke="url(#chassisBorder)" stroke-width="4.5" />
      
      <!-- Inner Screen Base Background -->
      <rect x="${bezelThickness}" y="${bezelThickness}" width="${screenWidth}" height="${screenHeight}" rx="${cornerRadius}" ry="${cornerRadius}" fill="#0A0E1A" />
    </svg>
  `);

  // Composite masked screen & top camera notch / bottom bar
  const phone = await sharp(chassisSvg)
    .composite([
      {
        input: maskedScreen,
        left: bezelThickness,
        top: bezelThickness,
      },
      {
        input: Buffer.from(`
          <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
            <!-- Dynamic Island / Camera Notch -->
            <rect x="${width / 2 - 80}" y="28" width="160" height="28" rx="14" ry="14" fill="#000000" />
            <circle cx="${width / 2 + 45}" cy="42" r="7" fill="#1E293B" />
            
            <!-- Bottom Home Indicator -->
            <rect x="${width / 2 - 90}" y="${height - 30}" width="180" height="8" rx="4" ry="4" fill="#FFFFFF" opacity="0.45"/>
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

// 8 Portrait Showcase Configurations (1080 x 2400)
const PORTRAIT_BANNERS = [
  {
    fileName: '01_playstore_portrait_dashboard.png',
    badgeText: '🚀 ALL-IN-ONE CLOUD ECOSYSTEM',
    title: 'Infrastruktur Cloud',
    subtitle: 'VPS, Hosting & Bot WhatsApp',
    description: 'Kelola seluruh kebutuhan server dan otomasi dalam satu aplikasi.',
    accentColor: '#818CF8', // Indigo
    accentGlow: '#6366F1',
    screenshot: 'assets/ss_vibetech/Dashboard.png',
    chips: [
      { text: '⚡ 99.9% Uptime SLA', color: '#10B981', x: 70, y: 820 },
      { text: '💎 VibeWallet Instant Pay', color: '#818CF8', x: 670, y: 1550 },
    ],
  },
  {
    fileName: '02_playstore_portrait_vps.png',
    badgeText: '⚡ HIGH PERFORMANCE CLOUD VPS',
    title: 'Cloud VPS NVMe',
    subtitle: 'Performa Ekstrem & Root Akses',
    description: 'Server virtual KVM NVMe SSD super cepat dengan dedicated public IP.',
    accentColor: '#38BDF8', // Cyan
    accentGlow: '#0284C7',
    screenshot: 'assets/ss_vibetech/Produk.png',
    chips: [
      { text: '🚀 1 Gbps Port Speed', color: '#38BDF8', x: 70, y: 820 },
      { text: '🛡️ Anti-DDoS Shield', color: '#10B981', x: 700, y: 1550 },
    ],
  },
  {
    fileName: '03_playstore_portrait_panel.png',
    badgeText: '🎮 GAME & WEB HOSTING PANEL',
    title: 'Panel Pterodactyl',
    subtitle: 'Deploy Server Game & Web',
    description: 'Minecraft, SA:MP, FiveM, Node.js, Python, Web Console & SFTP.',
    accentColor: '#34D399', // Emerald
    accentGlow: '#059669',
    screenshot: 'assets/ss_vibetech/Kartu_layanan.png',
    chips: [
      { text: '🕹️ Pterodactyl Node', color: '#34D399', x: 70, y: 820 },
      { text: '⚡ Auto Restart & Backup', color: '#F59E0B', x: 660, y: 1550 },
    ],
  },
  {
    fileName: '04_playstore_portrait_bot_wa.png',
    badgeText: '🤖 24/7 WHATSAPP AUTOMATION',
    title: 'Sewa Bot WhatsApp',
    subtitle: 'Aktif 24 Jam Nonstop Cloud',
    description: 'Koneksikan nomor instan via Pairing Code 8-Digit tanpa perlu PC.',
    accentColor: '#4ADE80', // Green
    accentGlow: '#16A34A',
    screenshot: 'assets/ss_vibetech/Kartu_layanan.png',
    chips: [
      { text: '🟢 Online 24/7 Cloud', color: '#22C55E', x: 70, y: 820 },
      { text: '📱 Pairing Code Instan', color: '#38BDF8', x: 690, y: 1550 },
    ],
  },
  {
    fileName: '05_playstore_portrait_furina_ai.png',
    badgeText: '🎭 POWERED BY GOOGLE GEMINI AI',
    title: 'Furina AI Assistant',
    subtitle: 'Konsultan Server Cerdas 24/7',
    description: 'Bantuan teknis, troubleshooting coding script & rekomendasi spek.',
    accentColor: '#60A5FA', // Sky Blue
    accentGlow: '#2563EB',
    screenshot: 'assets/ss_vibetech/Live_chat.png',
    chips: [
      { text: '✨ Google Gemini AI', color: '#60A5FA', x: 70, y: 820 },
      { text: '💡 Instant Script Helper', color: '#A78BFA', x: 670, y: 1550 },
    ],
  },
  {
    fileName: '06_playstore_portrait_payment.png',
    badgeText: '💳 AUTOMATED PAYMENT GATEWAY',
    title: 'Pembayaran Instan',
    subtitle: 'QRIS, Virtual Account & Wallet',
    description: 'Verifikasi pelunasan kilat 1-5 detik via Midtrans resmi.',
    accentColor: '#FBBF24', // Amber
    accentGlow: '#D97706',
    screenshot: 'assets/ss_vibetech/Pembayaran.png',
    chips: [
      { text: '🔒 PCI-DSS Certified', color: '#10B981', x: 70, y: 820 },
      { text: '🧾 Auto Invoice Email', color: '#FBBF24', x: 690, y: 1550 },
    ],
  },
  {
    fileName: '07_playstore_portrait_monitoring.png',
    badgeText: '📊 REAL-TIME SERVICE MONITORING',
    title: 'Kelola Layanan',
    subtitle: 'Pantau IP, Port & Masa Aktif',
    description: 'Salin kredensial server dan terima pengingat kadaluarsa tepat waktu.',
    accentColor: '#F472B6', // Pink
    accentGlow: '#DB2777',
    screenshot: 'assets/ss_vibetech/Total_Pesanan.png',
    chips: [
      { text: '📡 Realtime Monitoring', color: '#F472B6', x: 70, y: 820 },
      { text: '🔔 Expired Date Alert', color: '#38BDF8', x: 680, y: 1550 },
    ],
  },
  {
    fileName: '08_playstore_portrait_security.png',
    badgeText: '🛡️ ENTERPRISE GRADE SECURITY',
    title: 'Aman & Terpercaya',
    subtitle: 'Biometrik & Hybrid Database',
    description: 'Login Sidik Jari/Wajah lokal, PIN 6-Digit & Kepatuhan UU PDP.',
    accentColor: '#A78BFA', // Purple
    accentGlow: '#7C3AED',
    screenshot: 'assets/ss_vibetech/Profil.png',
    chips: [
      { text: '🔐 256-Bit SSL & 2FA', color: '#34D399', x: 70, y: 820 },
      { text: '🏛️ UU PDP No. 27/2022', color: '#A78BFA', x: 680, y: 1550 },
    ],
  },
];

async function generatePortraitBanner(config) {
  const width = 1080;
  const height = 2400;

  // Background & Header Typography SVG
  const bgSvg = `
    <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <!-- Background Gradients -->
        <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#070A13" />
          <stop offset="40%" stop-color="#0F172A" />
          <stop offset="100%" stop-color="#030509" />
        </linearGradient>
        
        <radialGradient id="topGlow" cx="50%" cy="15%" r="65%">
          <stop offset="0%" stop-color="${config.accentGlow}" stop-opacity="0.38" />
          <stop offset="100%" stop-color="#000000" stop-opacity="0" />
        </radialGradient>

        <radialGradient id="bottomGlow" cx="50%" cy="85%" r="50%">
          <stop offset="0%" stop-color="${config.accentGlow}" stop-opacity="0.25" />
          <stop offset="100%" stop-color="#000000" stop-opacity="0" />
        </radialGradient>

        <linearGradient id="badgeGrad" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="${config.accentColor}" stop-opacity="0.25" />
          <stop offset="100%" stop-color="${config.accentGlow}" stop-opacity="0.10" />
        </linearGradient>

        <!-- Cyber Grid -->
        <pattern id="cyberGrid" width="48" height="48" patternUnits="userSpaceOnUse">
          <path d="M 48 0 L 0 0 0 48" fill="none" stroke="#334155" stroke-width="0.75" stroke-opacity="0.25" />
        </pattern>
      </defs>

      <!-- 1. Background Fill & Cyber Grid -->
      <rect width="${width}" height="${height}" fill="url(#bgGrad)" />
      <rect width="${width}" height="${height}" fill="url(#cyberGrid)" />
      
      <!-- 2. Ambient Light Flares -->
      <circle cx="540" cy="350" r="580" fill="url(#topGlow)" />
      <circle cx="540" cy="1900" r="500" fill="url(#bottomGlow)" />

      <!-- 3. Decorative Cyber Circuit Lines -->
      <path d="M 0 200 Q 300 150 600 240 T 1080 180" fill="none" stroke="${config.accentColor}" stroke-opacity="0.18" stroke-width="2" />
      <path d="M 0 620 Q 400 680 800 580 T 1080 640" fill="none" stroke="${config.accentColor}" stroke-opacity="0.18" stroke-width="2" />

      <!-- 4. Top Header & Typography Area (Centered) -->
      
      <!-- Badge Pill -->
      <g transform="translate(540, 110)">
        <rect x="-190" y="0" width="380" height="46" rx="23" fill="url(#badgeGrad)" stroke="${config.accentColor}" stroke-opacity="0.6" stroke-width="1.8" />
        <circle cx="-160" cy="23" r="6" fill="${config.accentColor}" />
        <text x="-142" y="30" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="16" font-weight="800" fill="${config.accentColor}" letter-spacing="1">
          ${escapeXml(config.badgeText)}
        </text>
      </g>

      <!-- Main Title (H1) -->
      <text x="540" y="235" text-anchor="middle" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="64" font-weight="900" fill="#FFFFFF" letter-spacing="-1">
        ${escapeXml(config.title)}
      </text>

      <!-- Subtitle (H2) -->
      <text x="540" y="300" text-anchor="middle" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="36" font-weight="700" fill="${config.accentColor}">
        ${escapeXml(config.subtitle)}
      </text>

      <!-- Short Description -->
      <text x="540" y="358" text-anchor="middle" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="24" font-weight="400" fill="#94A3B8">
        ${escapeXml(config.description)}
      </text>

      <!-- Floating Chips Graphics Over Phone -->
      ${config.chips.map((chip) => `
        <g transform="translate(${chip.x}, ${chip.y})">
          <rect x="0" y="0" width="310" height="60" rx="30" fill="#0F172A" fill-opacity="0.95" stroke="${chip.color}" stroke-width="2.5" />
          <circle cx="28" cy="30" r="7" fill="${chip.color}" />
          <text x="48" y="38" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="20" font-weight="700" fill="#FFFFFF">
            ${escapeXml(chip.text)}
          </text>
        </g>
      `).join('')}

      <!-- Bottom Brand Signature -->
      <g transform="translate(540, 2340)">
        <text x="0" y="0" text-anchor="middle" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="20" font-weight="700" fill="#64748B">
          VIBETECH.XYZ • GOOGLE PLAY STORE OFFICIAL
        </text>
      </g>
    </svg>
  `;

  // 1. Generate Big Portrait Phone Mockup
  const phoneBuf = await createPortraitPhoneMockup(config.screenshot, 860, 1820);

  // 2. Composite Phone onto 1080x2400 Background
  const result = await sharp(Buffer.from(bgSvg))
    .composite([
      {
        input: phoneBuf,
        left: 110,
        top: 440,
      },
    ])
    .png({ quality: 100, compressionLevel: 8 })
    .toFile(path.join(OUTPUT_DIR, config.fileName));

  console.log(`✅ Generated Portrait: ${config.fileName} (${result.width}x${result.height})`);
}

async function runAll() {
  console.log('🚀 Generating 8 High-End Google Play Store 1080x2400 Portrait Screenshots...');
  for (const banner of PORTRAIT_BANNERS) {
    await generatePortraitBanner(banner);
  }
  console.log('🎉 All 8 Google Play Store Portrait Screenshots Generated Successfully!');
}

runAll().catch((err) => {
  console.error('Error generating portrait screenshots:', err);
});
