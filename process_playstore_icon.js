import fs from 'fs';
import path from 'path';
import sharp from 'sharp';

const SOURCE_IMAGE = 'C:/Users/PC-04/.gemini/antigravity-ide/brain/0483bf97-a4c2-4967-b214-0102c483a304/playstore_app_icon_3d_1788159735644.jpg';
const OUTPUT_DIR = 'd:/vibetech_xyz_sqflite/vibetech_xyz/assets/playstore_icon';

if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

async function processIcons() {
  console.log('🚀 Processing Play Store App Icons (1:1 Ratio)...');

  // 1. Master High-Res 1024x1024 PNG (Square)
  await sharp(SOURCE_IMAGE)
    .resize(1024, 1024, { fit: 'cover' })
    .png({ quality: 100, compressionLevel: 8 })
    .toFile(path.join(OUTPUT_DIR, 'playstore_icon_1024x1024.png'));
  console.log('✅ Generated: playstore_icon_1024x1024.png (1024x1024)');

  // 2. Official Google Play Console Icon (512x512 PNG, 32-bit sRGB, full square per Google requirements)
  await sharp(SOURCE_IMAGE)
    .resize(512, 512, { fit: 'cover' })
    .png({ quality: 100, compressionLevel: 8 })
    .toFile(path.join(OUTPUT_DIR, 'playstore_icon_512x512.png'));
  console.log('✅ Generated: playstore_icon_512x512.png (512x512 - Google Play Console Ready)');

  // 3. Play Store Squircle Preview (With Google Play 20% / 102.4px rounded corner mask for preview)
  const squircleRadius = 102.4; // 20% of 512px
  const squircleMask = Buffer.from(`
    <svg width="512" height="512" xmlns="http://www.w3.org/2000/svg">
      <rect x="0" y="0" width="512" height="512" rx="${squircleRadius}" ry="${squircleRadius}" fill="#ffffff"/>
    </svg>
  `);

  const resized512 = await sharp(SOURCE_IMAGE)
    .resize(512, 512, { fit: 'cover' })
    .png()
    .toBuffer();

  await sharp(resized512)
    .composite([{ input: squircleMask, blend: 'dest-in' }])
    .png({ quality: 100 })
    .toFile(path.join(OUTPUT_DIR, 'playstore_icon_squircle_preview_512x512.png'));
  console.log('✅ Generated: playstore_icon_squircle_preview_512x512.png (512x512)');

  // Also update assets/icon/logo.png
  await sharp(SOURCE_IMAGE)
    .resize(1024, 1024, { fit: 'cover' })
    .png({ quality: 100 })
    .toFile('d:/vibetech_xyz_sqflite/vibetech_xyz/assets/icon/logo.png');
  console.log('✅ Updated: assets/icon/logo.png');

  console.log('🎉 All Play Store 1:1 App Icons processed successfully!');
}

processIcons().catch((err) => {
  console.error('Error processing icons:', err);
});
