import fs from 'fs';
import path from 'path';
import sharp from 'sharp';

const OUTPUT_DIR = 'd:/vibetech_xyz_sqflite/vibetech_xyz/assets/playstore_1024x500';
const OUTPUT_4K_DIR = 'd:/vibetech_xyz_sqflite/vibetech_xyz/assets/playstore_4k_4096x2000';
const OUTPUT_8K_DIR = 'd:/vibetech_xyz_sqflite/vibetech_xyz/assets/playstore_8k_8192x4000';
const LOGO_PATH = 'd:/vibetech_xyz_sqflite/vibetech_xyz/assets/icon/logo.png';

if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR, { recursive: true });
if (!fs.existsSync(OUTPUT_4K_DIR)) fs.mkdirSync(OUTPUT_4K_DIR, { recursive: true });
if (!fs.existsSync(OUTPUT_8K_DIR)) fs.mkdirSync(OUTPUT_8K_DIR, { recursive: true });

function escapeXml(unsafe) {
  if (!unsafe) return '';
  return unsafe
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

const SVG_ICONS = {
  bolt: `<path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" />`,
  server: `<path d="M4 4h16c1.1 0 2 .9 2 2v4c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2zm0 10h16c1.1 0 2 .9 2 2v4c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2v-4c0-1.1.9-2 2-2zm2-7a1.5 1.5 0 100 3 1.5 1.5 0 000-3zm0 10a1.5 1.5 0 100 3 1.5 1.5 0 000-3z" />`,
  gamepad: `<path d="M21 6H3c-1.1 0-2 .9-2 2v8c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-10 7H9v2H7v-2H5v-2h2V9h2v2h2v2zm4.5 2c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zm3-3c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5z" />`,
  whatsapp: `<path d="M12.04 2C6.58 2 2.13 6.45 2.13 11.91c0 1.75.46 3.45 1.32 4.95L2.05 22l5.25-1.38c1.45.79 3.08 1.21 4.74 1.21 5.46 0 9.91-4.45 9.91-9.91 0-2.65-1.03-5.14-2.9-7.01A9.82 9.82 0 0012.04 2zm0 18.08c-1.48 0-2.93-.4-4.2-1.15l-.3-.18-3.12.82.83-3.04-.2-.31a8.03 8.03 0 01-1.23-4.31c0-4.46 3.63-8.08 8.09-8.08 2.16 0 4.19.84 5.72 2.37a8.03 8.03 0 012.36 5.71c0 4.46-3.63 8.08-8.08 8.08z" />`,
  sparkles: `<path d="M12 2L9.5 8.5 3 11l6.5 2.5L12 20l2.5-6.5L21 11l-6.5-2.5L12 2zm7 13l-1.25 2.75L15 19l2.75 1.25L19 23l1.25-2.75L23 19l-2.75-1.25L19 15z" />`,
  creditcard: `<path d="M20 4H4c-1.11 0-1.99.89-1.99 2L2 18c0 1.11.89 2 2 2h16c1.11 0 2-.89 2-2V6c0-1.11-.89-2-2-2zm0 14H4v-6h16v6zm0-10H4V6h16v2z" />`,
  shield: `<path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-1 16l-4-4 1.41-1.41L11 14.17l6.59-6.59L19 9l-8 8z" />`,
  chart: `<path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zM9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4z" />`,
  key: `<path d="M12.65 10C11.83 7.67 9.61 6 7 6c-3.31 0-6 2.69-6 6s2.69 6 6 6c2.61 0 4.83-1.67 5.65-4H17v4h4v-4h2v-4H12.65zM7 14c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2z" />`,
  docker: `<path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM19 18H6c-2.21 0-4-1.79-4-4 0-2.05 1.53-3.76 3.56-3.97l1.07-.11.5-.95C8.08 7.14 9.94 6 12 6c2.62 0 4.88 1.86 5.39 4.43l.3 1.5 1.53.11c1.56.1 2.78 1.41 2.78 2.96 0 1.65-1.35 3-3 3z" />`,
  rocket: `<path d="M13.13 2.05L12 1 10.87 2.05C8.36 4.39 7 7.68 7 11.12V14l-3 3v2h6v4h4v-4h6v-2l-3-3v-2.88c0-3.44-1.36-6.73-3.87-9.07zM12 12c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2z" />`,
  database: `<path d="M12 2C6.48 2 2 4.02 2 6.5v11C2 19.98 6.48 22 12 22s10-2.02 10-4.5v-11C22 4.02 17.52 2 12 2zm0 2.5c4.14 0 7.5 1.34 7.5 2s-3.36 2-7.5 2-7.5-1.34-7.5-2 3.36-2 7.5-2zm0 6c4.14 0 7.5 1.34 7.5 2s-3.36 2-7.5 2-7.5-1.34-7.5-2 3.36-2 7.5-2zm0 6c4.14 0 7.5 1.34 7.5 2s-3.36 2-7.5 2-7.5-1.34-7.5-2 3.36-2 7.5-2z" />`,
  code: `<path d="M9.4 16.6L4.8 12l4.6-4.6L8 6l-6 6 6 6 1.4-1.4zm5.2 0l4.6-4.6-4.6-4.6L16 6l6 6-6 6-1.4-1.4z" />`,
  bell: `<path d="M12 22c1.1 0 2-.9 2-2h-4c0 1.1.9 2 2 2zm6-6v-5c0-3.07-1.63-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.64 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z" />`,
  fingerprint: `<path d="M17.81 4.47c-.08 0-.16-.02-.23-.06C15.66 3.42 14 3 12.01 3c-1.98 0-3.86.47-5.57 1.41-.24.13-.54.04-.68-.2-.13-.24-.04-.55.2-.68C7.82 2.52 9.86 2 12.01 2c2.13 0 3.99.47 5.92 1.5.24.13.33.43.2.67-.09.19-.24.3-.32.3zM3.46 8.83c-.26-.06-.41-.32-.35-.57.77-3.15 3.19-5.6 6.32-6.52.26-.07.52.09.59.35.07.26-.09.52-.35.59-2.82.83-5 3.03-5.69 5.86-.06.23-.27.35-.52.29zm17.08 0c-.05.06-.26-.06-.32-.29-.69-2.83-2.87-5.03-5.69-5.86-.26-.07-.42-.33-.35-.59.07-.26.33-.42.59-.35 3.13.92 5.55 3.37 6.32 6.52.06.25-.09.51-.35.57-.07 0-.13 0-.2-.0zM12 6.5c-3.04 0-5.5 2.46-5.5 5.5v3.5c0 .28-.22.5-.5.5s-.5-.22-.5-.5V12c0-3.59 2.91-6.5 6.5-6.5s6.5 2.91 6.5 6.5v3.5c0 .28-.22.5-.5.5s-.5-.22-.5-.5V12c0-3.04-2.46-5.5-5.5-5.5zm0 4c-1.38 0-2.5 1.12-2.5 2.5v4c0 .28-.22.5-.5.5s-.5-.22-.5-.5v-4c0-1.93 1.57-3.5 3.5-3.5s3.5 1.57 3.5 3.5v4c0 .28-.22.5-.5.5s-.5-.22-.5-.5v-4c0-1.38-1.12-2.5-2.5-2.5z" />`,
  sync: `<path d="M12 4V1L8 5l4 4V6c3.31 0 6 2.69 6 6 0 1.01-.25 1.97-.7 2.8l1.46 1.46C19.54 15.03 20 13.57 20 12c0-4.42-3.58-8-8-8zm0 14c-3.31 0-6-2.69-6-6 0-1.01.25-1.97.7-2.8L5.24 7.74C4.46 8.97 4 10.43 4 12c0 4.42 3.58 8 8 8v3l4-4-4-4v3z" />`,
  phone: `<path d="M17 1.01L7 1c-1.1 0-2 .9-2 2v18c0 1.1.9 2 2 2h10c1.1 0 2-.9 2-2V3c0-1.1-.9-1.99-2-1.99zM17 19H7V5h10v14z" />`,
  diamond: `<path d="M12.16 3h-.32L9.21 8.24h5.58zm4.3 5.24h5.08L18.25 3h-3.92zm-8.92 0L10.87 3H6.95L3.65 8.24zm-.82 1.5H1.67L12 21.48 6.72 9.74zm2.14 0h6.28L12 19.55zm7.56 0h5.05L12 21.48z" />`,
  cpu: `<path d="M9 2v3h6V2h2v3h2a2 2 0 012 2v2h3v2h-3v6h3v2h-3v2a2 2 0 01-2 2h-2v3h-2v-3H9v3H7v-3H5a2 2 0 01-2-2v-2H0v-2h3v-6H0V9h3V7a2 2 0 012-2h2V2h2zm8 5H7v10h10V7zm-2 2v6H9V9h6z" />`,
};

function renderSvgIcon(iconName, color = '#FFFFFF', size = 144) {
  const pathData = SVG_ICONS[iconName] || SVG_ICONS.bolt;
  return `
    <svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="${color}" xmlns="http://www.w3.org/2000/svg">
      ${pathData}
    </svg>
  `;
}

// 8K Grand Logo Badge
async function create8KGrandLogoBadge(size = 448, borderColor = '#818CF8') {
  const cornerRadius = 120;
  const innerSize = size - 64;

  const resizedLogo = await sharp(LOGO_PATH)
    .resize(innerSize, innerSize, { fit: 'cover' })
    .png()
    .toBuffer();

  const maskSvg = Buffer.from(`
    <svg width="${innerSize}" height="${innerSize}" xmlns="http://www.w3.org/2000/svg">
      <rect x="0" y="0" width="${innerSize}" height="${innerSize}" rx="${cornerRadius - 16}" ry="${cornerRadius - 16}" fill="#ffffff"/>
    </svg>
  `);

  const maskedLogo = await sharp(resizedLogo)
    .composite([{ input: maskSvg, blend: 'dest-in' }])
    .png()
    .toBuffer();

  const frameSvg = Buffer.from(`
    <svg width="${size}" height="${size}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="logoRim8k" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.95" />
          <stop offset="25%" stop-color="${borderColor}" />
          <stop offset="60%" stop-color="#0F172A" />
          <stop offset="100%" stop-color="${borderColor}" />
        </linearGradient>
        <linearGradient id="logoGlassBg8k" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stop-color="#1E293B" stop-opacity="0.9" />
          <stop offset="100%" stop-color="#030712" stop-opacity="0.98" />
        </linearGradient>
      </defs>
      <rect x="8" y="8" width="${size - 16}" height="${size - 16}" rx="${cornerRadius}" ry="${cornerRadius}" fill="url(#logoGlassBg8k)" stroke="url(#logoRim8k)" stroke-width="20" />
    </svg>
  `);

  const badge = await sharp(frameSvg)
    .composite([{ input: maskedLogo, left: 32, top: 32 }])
    .png()
    .toBuffer();

  return badge;
}

// 8K Smartphone Mockup
async function create8KFlagshipMockup(screenshotPath, width = 1808, height = 3640) {
  const bezel = 40;
  const screenWidth = width - (bezel * 2);
  const screenHeight = height - (bezel * 2);
  const cornerRadius = 160;
  const outerCornerRadius = 192;

  const resizedScreen = await sharp(screenshotPath)
    .resize(screenWidth, screenHeight, { fit: 'cover', position: 'top' })
    .png()
    .toBuffer();

  const maskSvg = Buffer.from(`
    <svg width="${screenWidth}" height="${screenHeight}" xmlns="http://www.w3.org/2000/svg">
      <rect x="0" y="0" width="${screenWidth}" height="${screenHeight}" rx="${cornerRadius}" ry="${cornerRadius}" fill="#ffffff"/>
    </svg>
  `);

  const maskedScreen = await sharp(resizedScreen)
    .composite([{ input: maskSvg, blend: 'dest-in' }])
    .png()
    .toBuffer();

  const chassisSvg = Buffer.from(`
    <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="titaniumRim8k" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#E2E8F0" />
          <stop offset="20%" stop-color="#475569" />
          <stop offset="50%" stop-color="#0F172A" />
          <stop offset="80%" stop-color="#334155" />
          <stop offset="100%" stop-color="#94A3B8" />
        </linearGradient>
        <linearGradient id="chassisBack8k" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stop-color="#0F172A" />
          <stop offset="100%" stop-color="#020617" />
        </linearGradient>
        <linearGradient id="screenGlare8k" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.14" />
          <stop offset="35%" stop-color="#FFFFFF" stop-opacity="0.03" />
          <stop offset="65%" stop-color="#FFFFFF" stop-opacity="0.0" />
        </linearGradient>
      </defs>
      <rect x="8" y="8" width="${width - 16}" height="${height - 16}" rx="${outerCornerRadius}" ry="${outerCornerRadius}" fill="url(#chassisBack8k)" stroke="url(#titaniumRim8k)" stroke-width="20" />
      <rect x="${bezel}" y="${bezel}" width="${screenWidth}" height="${screenHeight}" rx="${cornerRadius}" ry="${cornerRadius}" fill="#0A0E1A" />
    </svg>
  `);

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
            <path d="M ${bezel} ${bezel} L ${width - bezel} ${bezel} L ${bezel} ${height * 0.44} Z" fill="url(#screenGlare8k)" opacity="0.9"/>
            <g transform="translate(${width / 2}, 104)">
              <rect x="-192" y="0" width="384" height="72" rx="36" fill="#000000" stroke="#1E293B" stroke-width="6"/>
              <circle cx="96" cy="36" r="18" fill="#0A0E1A" />
              <circle cx="92" cy="30" r="7" fill="#38BDF8" opacity="0.8"/>
              <circle cx="-112" cy="36" r="12" fill="#1E293B" />
            </g>
            <rect x="${width / 2 - 240}" y="${height - 80}" width="480" height="24" rx="12" fill="#FFFFFF" opacity="0.5"/>
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

// 🌟 GAMBAR UTAMA (FEATURE GRAPHIC HERO)
async function generateMainFeatureGraphic() {
  const width = 8192;
  const height = 4000;

  const bgSvg = `
    <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="mainHeroBg8k" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#02040D" />
          <stop offset="25%" stop-color="#070D1E" />
          <stop offset="60%" stop-color="#0A1026" />
          <stop offset="100%" stop-color="#02050E" />
        </linearGradient>

        <radialGradient id="heroGlowCenter" cx="62%" cy="48%" r="65%">
          <stop offset="0%" stop-color="#6366F1" stop-opacity="0.5" />
          <stop offset="40%" stop-color="#38BDF8" stop-opacity="0.18" />
          <stop offset="80%" stop-color="#000000" stop-opacity="0" />
        </radialGradient>

        <radialGradient id="heroGlowLeft" cx="15%" cy="30%" r="55%">
          <stop offset="0%" stop-color="#A855F7" stop-opacity="0.38" />
          <stop offset="60%" stop-color="#6366F1" stop-opacity="0.08" />
          <stop offset="100%" stop-color="#000000" stop-opacity="0" />
        </radialGradient>

        <linearGradient id="mainTitleGrad" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="#FFFFFF" />
          <stop offset="45%" stop-color="#E0E7FF" />
          <stop offset="75%" stop-color="#818CF8" />
          <stop offset="100%" stop-color="#38BDF8" />
        </linearGradient>

        <linearGradient id="tagPillGrad" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="#6366F1" stop-opacity="0.35" />
          <stop offset="100%" stop-color="#38BDF8" stop-opacity="0.15" />
        </linearGradient>

        <linearGradient id="glassCardFill" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stop-color="#0F172A" stop-opacity="0.92" />
          <stop offset="100%" stop-color="#030712" stop-opacity="0.96" />
        </linearGradient>

        <linearGradient id="glassCardBorder" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#818CF8" stop-opacity="0.9" />
          <stop offset="50%" stop-color="#38BDF8" stop-opacity="0.4" />
          <stop offset="100%" stop-color="#C084FC" stop-opacity="0.8" />
        </linearGradient>

        <pattern id="mainGrid8k" width="352" height="352" patternUnits="userSpaceOnUse">
          <path d="M 352 0 L 0 0 0 352" fill="none" stroke="#1E293B" stroke-width="5" stroke-opacity="0.3" />
          <circle cx="352" cy="352" r="10" fill="#334155" opacity="0.35" />
        </pattern>
      </defs>

      <rect width="${width}" height="${height}" fill="url(#mainHeroBg8k)" />
      <rect width="${width}" height="${height}" fill="url(#mainGrid8k)" />
      <circle cx="5080" cy="1920" r="3200" fill="url(#heroGlowCenter)" />
      <circle cx="1200" cy="1200" r="2800" fill="url(#heroGlowLeft)" />

      <path d="M -160 480 Q 2000 120 4000 680 T 8320 400" fill="none" stroke="#6366F1" stroke-opacity="0.28" stroke-width="18" />
      <path d="M -160 3440 Q 2800 3760 5200 3280 T 8320 3600" fill="none" stroke="#38BDF8" stroke-opacity="0.25" stroke-width="18" />
      <circle cx="4000" cy="680" r="36" fill="#818CF8" />
      <circle cx="5200" cy="3280" r="36" fill="#38BDF8" />

      <!-- TOP BRAND HEADER -->
      <g transform="translate(320, 200)">
        <g transform="translate(560, 24)">
          <text x="0" y="192" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="184" font-weight="900" fill="#FFFFFF" letter-spacing="-4">
            VIBETECH<tspan fill="#38BDF8">.XYZ</tspan>
          </text>
          <g transform="translate(1500, 56)">
            <rect x="0" y="0" width="760" height="160" rx="80" fill="#38BDF8" fill-opacity="0.18" stroke="#38BDF8" stroke-width="8" />
            <circle cx="80" cy="80" r="32" fill="#38BDF8" />
            <text x="160" y="108" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="68" font-weight="800" fill="#FFFFFF" letter-spacing="4">
              OFFICIAL APP
            </text>
          </g>
          <text x="0" y="352" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="88" font-weight="700" fill="#94A3B8" letter-spacing="9.6">
            NEXT-GENERATION DIGITAL &amp; CLOUD PLATFORM
          </text>
        </g>
      </g>

      <!-- MAIN HERO HEADLINE -->
      <g transform="translate(320, 760)">
        <rect x="0" y="0" width="2480" height="208" rx="104" fill="url(#tagPillGrad)" stroke="#818CF8" stroke-width="10" />
        <circle cx="112" cy="104" r="32" fill="#818CF8" />
        <text x="208" y="136" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="80" font-weight="800" fill="#818CF8" letter-spacing="6">
          ⚡ ALL-IN-ONE CLOUD &amp; AUTOMATION ECOSYSTEM
        </text>

        <text x="0" y="480" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="248" font-weight="900" fill="url(#mainTitleGrad)" letter-spacing="-6.4">
          Ekosistem Server Cloud
        </text>
        <text x="0" y="740" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="248" font-weight="900" fill="#38BDF8" letter-spacing="-6.4">
          &amp; Otomasi No. 1
        </text>

        <text x="0" y="940" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="96" font-weight="500" fill="#CBD5E1">
          Sewa Cloud VPS NVMe, Hosting Game Pterodactyl &amp; Bot WhatsApp 24 Jam
        </text>
      </g>

      <!-- FOUR MAJESTIC FEATURE PILLS -->
      <g transform="translate(320, 1840)">
        <g transform="translate(0, 0)">
          <rect x="0" y="0" width="1800" height="368" rx="96" fill="url(#glassCardFill)" stroke="url(#glassCardBorder)" stroke-width="10" />
          <rect x="64" y="64" width="240" height="240" rx="64" fill="#38BDF8" fill-opacity="0.22" stroke="#38BDF8" stroke-width="8" />
          <g transform="translate(112, 112)">
            ${renderSvgIcon('cpu', '#38BDF8', 144)}
          </g>
          <text x="368" y="184" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="92" font-weight="800" fill="#FFFFFF">
            Cloud VPS NVMe Tier-3
          </text>
          <text x="368" y="272" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="68" font-weight="500" fill="#94A3B8">
            Port 1 Gbps • KVM Multi OS Linux/Windows
          </text>
        </g>

        <g transform="translate(1920, 0)">
          <rect x="0" y="0" width="1800" height="368" rx="96" fill="url(#glassCardFill)" stroke="url(#glassCardBorder)" stroke-width="10" />
          <rect x="64" y="64" width="240" height="240" rx="64" fill="#4ADE80" fill-opacity="0.22" stroke="#4ADE80" stroke-width="8" />
          <g transform="translate(112, 112)">
            ${renderSvgIcon('whatsapp', '#4ADE80', 144)}
          </g>
          <text x="368" y="184" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="92" font-weight="800" fill="#FFFFFF">
            Sewa Bot WhatsApp 24/7
          </text>
          <text x="368" y="272" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="68" font-weight="500" fill="#94A3B8">
            Pairing Code Instan • Tanpa Scan QR
          </text>
        </g>

        <g transform="translate(0, 432)">
          <rect x="0" y="0" width="1800" height="368" rx="96" fill="url(#glassCardFill)" stroke="url(#glassCardBorder)" stroke-width="10" />
          <rect x="64" y="64" width="240" height="240" rx="64" fill="#FBBF24" fill-opacity="0.22" stroke="#FBBF24" stroke-width="8" />
          <g transform="translate(112, 112)">
            ${renderSvgIcon('gamepad', '#FBBF24', 144)}
          </g>
          <text x="368" y="184" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="92" font-weight="800" fill="#FFFFFF">
            Panel Game Pterodactyl
          </text>
          <text x="368" y="272" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="68" font-weight="500" fill="#94A3B8">
            Deploy Minecraft, SAMP &amp; Node.js Kilat
          </text>
        </g>

        <g transform="translate(1920, 432)">
          <rect x="0" y="0" width="1800" height="368" rx="96" fill="url(#glassCardFill)" stroke="url(#glassCardBorder)" stroke-width="10" />
          <rect x="64" y="64" width="240" height="240" rx="64" fill="#C084FC" fill-opacity="0.22" stroke="#C084FC" stroke-width="8" />
          <g transform="translate(112, 112)">
            ${renderSvgIcon('creditcard', '#C084FC', 144)}
          </g>
          <text x="368" y="184" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="92" font-weight="800" fill="#FFFFFF">
            Pembayaran Instan Otomatis
          </text>
          <text x="368" y="272" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="68" font-weight="500" fill="#94A3B8">
            QRIS Semua E-Wallet &amp; Virtual Account Bank
          </text>
        </g>
      </g>

      <!-- FOOTER BADGES -->
      <g transform="translate(320, 3360)">
        <text x="0" y="112" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="112" font-weight="900" fill="#FFFFFF">
          Google Play Store
        </text>
        <text x="1000" y="112" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="112" font-weight="600" fill="#F59E0B">
          ★★★★★
        </text>
        <text x="1500" y="108" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="88" font-weight="500" fill="#94A3B8">
          • Top Rated Cloud &amp; Hosting Solution
        </text>
        <text x="0" y="272" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="80" font-weight="500" fill="#64748B">
          🛡️ PCI-DSS Certified • Enkripsi 256-Bit • Kepatuhan UU Perlindungan Data Pribadi
        </text>
      </g>
    </svg>
  `;

  const chipsSvg = `
    <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="mainChipFill" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stop-color="#0F172A" stop-opacity="0.96" />
          <stop offset="100%" stop-color="#020617" stop-opacity="0.98" />
        </linearGradient>
      </defs>

      <g transform="translate(4160, 480)">
        <rect x="0" y="0" width="1360" height="256" rx="128" fill="url(#mainChipFill)" stroke="#10B981" stroke-width="14" />
        <rect x="40" y="32" width="192" height="192" rx="96" fill="#10B981" fill-opacity="0.25" />
        <g transform="translate(72, 64)">
          ${renderSvgIcon('bolt', '#10B981', 128)}
        </g>
        <text x="288" y="164" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="84" font-weight="800" fill="#FFFFFF">
          99.9% Uptime SLA
        </text>
      </g>

      <g transform="translate(6680, 3180)">
        <rect x="0" y="0" width="1340" height="256" rx="128" fill="url(#mainChipFill)" stroke="#38BDF8" stroke-width="14" />
        <rect x="40" y="32" width="192" height="192" rx="96" fill="#38BDF8" fill-opacity="0.25" />
        <g transform="translate(72, 64)">
          ${renderSvgIcon('rocket', '#38BDF8', 128)}
        </g>
        <text x="288" y="164" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="84" font-weight="800" fill="#FFFFFF">
          Port 1 Gbps Speed
        </text>
      </g>

      <g transform="translate(4240, 3120)">
        <rect x="0" y="0" width="1340" height="256" rx="128" fill="url(#mainChipFill)" stroke="#F472B6" stroke-width="14" />
        <rect x="40" y="32" width="192" height="192" rx="96" fill="#F472B6" fill-opacity="0.25" />
        <g transform="translate(72, 64)">
          ${renderSvgIcon('sparkles', '#F472B6', 128)}
        </g>
        <text x="288" y="164" font-family="Segoe UI, -apple-system, Roboto, sans-serif" font-size="84" font-weight="800" fill="#FFFFFF">
          Furina AI Assistant
        </text>
      </g>
    </svg>
  `;

  const logoBuf = await create8KGrandLogoBadge(448, '#38BDF8');
  const primaryPhoneBuf = await create8KFlagshipMockup('assets/ss_vibetech/Dashboard.png', 1808, 3640);
  const secondaryPhoneBuf = await create8KFlagshipMockup('assets/ss_vibetech/Kartu_layanan.png', 1632, 3280);

  const masterHeroImage = sharp(Buffer.from(bgSvg))
    .composite([
      { input: logoBuf, left: 320, top: 200 },
      { input: secondaryPhoneBuf, left: 4560, top: 440 },
      { input: primaryPhoneBuf, left: 6040, top: 200 },
      { input: Buffer.from(chipsSvg), left: 0, top: 0 },
    ])
    .png({ quality: 100, compressionLevel: 6 });

  const masterHeroBuf = await masterHeroImage.toBuffer();

  // Save 8K Master
  await sharp(masterHeroBuf)
    .png({ quality: 100, compressionLevel: 6 })
    .toFile(path.join(OUTPUT_8K_DIR, '00_feature_graphic_main.png'));

  // Save 4K Master
  await sharp(masterHeroBuf)
    .resize(4096, 2000, { kernel: sharp.kernel.lanczos3 })
    .png({ quality: 100, compressionLevel: 6 })
    .toFile(path.join(OUTPUT_4K_DIR, '00_feature_graphic_main.png'));

  // Save EXACT 1024x500 (Feature Graphic)
  await sharp(masterHeroBuf)
    .resize(1024, 500, { kernel: sharp.kernel.lanczos3 })
    .sharpen({ sigma: 0.6, m1: 0.7, m2: 1.5 })
    .png({ quality: 100, compressionLevel: 9 })
    .toFile(path.join(OUTPUT_DIR, '00_feature_graphic_main.png'));

  await sharp(masterHeroBuf)
    .resize(1024, 500, { kernel: sharp.kernel.lanczos3 })
    .sharpen({ sigma: 0.6, m1: 0.7, m2: 1.5 })
    .png({ quality: 100, compressionLevel: 9 })
    .toFile(path.join(OUTPUT_DIR, 'feature_graphic.png'));

  console.log('👑 GAMBAR UTAMA (00_feature_graphic_main.png & feature_graphic.png) Ready at 1024x500 & 8K!');
}

generateMainFeatureGraphic().catch(console.error);
