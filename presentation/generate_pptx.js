import pptxgen from "pptxgenjs";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";
import JSZip from "jszip";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function generatePresentation() {
  const pres = new pptxgen();

  // Konfigurasi Standar 16:9 Canva / PowerPoint (13.333 x 7.5 Inci = 1920x1080 Proportional)
  pres.defineLayout({ name: "CANVA_WIDESCREEN_16_9", width: 13.333, height: 7.5 });
  pres.layout = "CANVA_WIDESCREEN_16_9";

  pres.author = "Raziek";
  pres.company = "VibeTech XYZ";
  pres.title = "VibeTech XYZ - Presentation Deck Master 28 Slides with Video Recording & Logo Philosophy";

  // Palette Warna Hex Cyber-Neon Glassmorphic
  const COLOR_BG = "060814";
  const COLOR_CARD = "0F1426";
  const COLOR_PRIMARY = "7C4DFF";
  const COLOR_ACCENT = "E040FB";
  const COLOR_CYAN = "00E5FF";
  const COLOR_EMERALD = "10B981";
  const COLOR_AMBER = "F59E0B";
  const COLOR_RED = "EF4444";
  const COLOR_WHITE = "FFFFFF";
  const COLOR_MUTED = "94A3B8";
  const COLOR_CODE_BG = "080B18";

  function setupSlideBg(slide) {
    slide.background = { color: COLOR_BG };
  }

  function addSlideHeader(slide, category, title, subtitle) {
    slide.addText(category.toUpperCase(), {
      x: 0.8,
      y: 0.42,
      w: 11.7,
      h: 0.28,
      fontSize: 10,
      fontFace: "Arial",
      bold: true,
      color: COLOR_ACCENT,
    });

    slide.addText(title, {
      x: 0.8,
      y: 0.68,
      w: 11.7,
      h: 0.55,
      fontSize: 19.5,
      fontFace: "Arial",
      bold: true,
      color: COLOR_WHITE,
    });

    slide.addText(subtitle, {
      x: 0.8,
      y: 1.22,
      w: 11.7,
      h: 0.35,
      fontSize: 11,
      fontFace: "Arial",
      color: COLOR_MUTED,
    });
  }

  // Helper function for Screenshot + UI Pointers + Dart Code Snippet Layout
  function addScreenshotCodeSlide(
    slide,
    category,
    title,
    subtitle,
    screenshotFile,
    uiBoxTitle,
    uiPointers,
    codeBoxTitle,
    codeText,
    accentColor = COLOR_CYAN
  ) {
    setupSlideBg(slide);
    addSlideHeader(slide, category, title, subtitle);

    const imgPath = path.join(__dirname, "..", "assets", "ss_vibetech", screenshotFile);

    // 1. Left: Phone Screenshot Frame & Image
    slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 0.6,
      y: 1.75,
      w: 2.35,
      h: 5.15,
      fill: { color: COLOR_CARD },
      line: { color: accentColor, width: 1.5 },
      rectRadius: 0.2,
    });

    if (fs.existsSync(imgPath)) {
      slide.addImage({
        path: imgPath,
        x: 0.65,
        y: 1.82,
        w: 2.25,
        h: 5.0,
      });
    }

    // 2. Middle: Visual UI Breakdown Box
    slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 3.1,
      y: 1.75,
      w: 4.6,
      h: 5.15,
      fill: { color: COLOR_CARD },
      line: { color: COLOR_PRIMARY, width: 1.2 },
      rectRadius: 0.18,
    });

    slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 3.3,
      y: 1.9,
      w: 4.2,
      h: 0.45,
      fill: { color: "1A103C" },
      line: { color: COLOR_PRIMARY, width: 1 },
      rectRadius: 0.1,
    });

    slide.addText(uiBoxTitle, {
      x: 3.3,
      y: 1.9,
      w: 4.2,
      h: 0.45,
      fontSize: 11,
      fontFace: "Arial",
      bold: true,
      color: COLOR_ACCENT,
      align: "center",
    });

    slide.addText(uiPointers, {
      x: 3.3,
      y: 2.45,
      w: 4.2,
      h: 4.3,
      fontSize: 9.2,
      fontFace: "Arial",
      color: COLOR_WHITE,
    });

    // 3. Right: Source Code Implementation Box
    slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 7.9,
      y: 1.75,
      w: 4.8,
      h: 5.15,
      fill: { color: COLOR_CARD },
      line: { color: accentColor, width: 1.2 },
      rectRadius: 0.18,
    });

    slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 8.1,
      y: 1.9,
      w: 4.4,
      h: 0.45,
      fill: { color: "0A1E35" },
      line: { color: accentColor, width: 1 },
      rectRadius: 0.1,
    });

    slide.addText(codeBoxTitle, {
      x: 8.1,
      y: 1.9,
      w: 4.4,
      h: 0.45,
      fontSize: 11,
      fontFace: "Arial",
      bold: true,
      color: accentColor,
      align: "center",
    });

    slide.addShape(pres.shapes.RECTANGLE, {
      x: 8.1,
      y: 2.45,
      w: 4.4,
      h: 4.3,
      fill: { color: COLOR_CODE_BG },
      line: { color: "1E293B", width: 0.8 },
    });

    slide.addText(codeText, {
      x: 8.2,
      y: 2.55,
      w: 4.2,
      h: 4.1,
      fontSize: 8.2,
      fontFace: "Courier New",
      color: COLOR_WHITE,
    });
  }

  let logoPath = path.join(__dirname, "..", "assets", "icon", "logo.png");
  if (!fs.existsSync(logoPath)) {
    logoPath = path.join(__dirname, "..", "assets", "images", "logo.png");
  }

  // =========================================================================
  // SLIDE 1: COVER & HERO TITLE
  // =========================================================================
  const s1 = pres.addSlide();
  setupSlideBg(s1);

  if (fs.existsSync(logoPath)) {
    s1.addImage({
      path: logoPath,
      x: 5.96,
      y: 0.52,
      w: 1.4,
      h: 1.4,
    });
  }

  s1.addText("VIBETECH XYZ", {
    x: 0.8, y: 1.95, w: 11.73, h: 0.8,
    fontSize: 34, fontFace: "Arial", bold: true, color: COLOR_WHITE, align: "center",
  });

  s1.addText("Next-Gen Cloud Infrastructure, 6 Fitur Utama & SQLite Offline-First Engine", {
    x: 0.8, y: 2.75, w: 11.73, h: 0.45,
    fontSize: 14.5, fontFace: "Arial", color: COLOR_CYAN, align: "center",
  });

  s1.addText("Aplikasi Mobile Penyedia Cloud VPS, Hosting Game Panel SG, dan Bot WhatsApp Berbasis Flutter & SQLite", {
    x: 1.5, y: 3.22, w: 10.33, h: 0.35,
    fontSize: 11, fontFace: "Arial", color: COLOR_MUTED, align: "center",
  });

  s1.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 1.6, y: 3.62, w: 10.1, h: 2.55,
    fill: { color: COLOR_CARD },
    line: { color: COLOR_PRIMARY, width: 1.5 },
    rectRadius: 0.25,
  });

  s1.addText(
    [
      { text: "6 Pilar Fitur Utama & Struktur Deck Komprehensif:\n\n", options: { bold: true, color: COLOR_CYAN, fontSize: 12 } },
      { text: "• [1] Dashboard: Pusat Kendali Interaktif, Saldo VibeWallet & Quick Menu\n", options: { color: COLOR_WHITE, fontSize: 10.5 } },
      { text: "• [2] Produk: Katalog Cloud VPS, Panel Pterodactyl SG & Bot WhatsApp\n", options: { color: COLOR_WHITE, fontSize: 10.5 } },
      { text: "• [3] Pembayaran: Checkout 1-Detik Saldo VibeWallet & Proteksi PIN 2FA\n", options: { color: COLOR_WHITE, fontSize: 10.5 } },
      { text: "• [4] Keranjang: Cart Multi-Item Dinamis, Counter Qty & Kupon Diskon 30%\n", options: { color: COLOR_WHITE, fontSize: 10.5 } },
      { text: "• [5] Profil: Pengaturan Identitas Akun, Bahasa ID/EN & Hardware Biometrik\n", options: { color: COLOR_WHITE, fontSize: 10.5 } },
      { text: "• [6] Data Kredensial: Penyimpanan Offline SQLite, Kredensial SSH & Server", options: { color: COLOR_WHITE, fontSize: 10.5 } },
    ],
    { x: 1.8, y: 3.82, w: 9.7, h: 2.15, align: "center" }
  );

  s1.addText("Lead Developer & System Architect: Raziek | Version 2.0.0", {
    x: 1.0, y: 6.42, w: 11.3, h: 0.4,
    fontSize: 11.5, fontFace: "Arial", bold: true, color: COLOR_ACCENT, align: "center",
  });

  // =========================================================================
  // SLIDE 2: IDENTITAS BRAND & FILOSOFI LOGO
  // =========================================================================
  const sLogo = pres.addSlide();
  setupSlideBg(sLogo);
  addSlideHeader(
    sLogo,
    "Identitas Brand & Visual Philosophy",
    "Filosofi Logo & Makna Identitas VibeTech XYZ",
    "Dekomposisi geometris monogram, makna nama brand, dan harmoni palet warna cyber-neon modern."
  );

  // 1. Left: Main Logo Showcase & Badge Anatomy Card
  sLogo.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 0.8,
    y: 1.75,
    w: 4.1,
    h: 5.2,
    fill: { color: COLOR_CARD },
    line: { color: COLOR_PRIMARY, width: 1.5 },
    rectRadius: 0.18,
  });

  // Top Logo Display Box
  sLogo.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 1.0,
    y: 1.95,
    w: 3.7,
    h: 2.1,
    fill: { color: "080B18" },
    line: { color: COLOR_CYAN, width: 1 },
    rectRadius: 0.12,
  });

  if (fs.existsSync(logoPath)) {
    sLogo.addImage({
      path: logoPath,
      x: 2.1,
      y: 2.05,
      w: 1.5,
      h: 1.5,
    });
  }

  sLogo.addText("VIBETECH XYZ", {
    x: 1.0,
    y: 3.58,
    w: 3.7,
    h: 0.3,
    fontSize: 13,
    fontFace: "Arial",
    bold: true,
    color: COLOR_WHITE,
    align: "center",
  });

  sLogo.addText("Next-Gen Cloud Infrastructure • v2.0.0", {
    x: 1.0,
    y: 3.82,
    w: 3.7,
    h: 0.22,
    fontSize: 8.5,
    fontFace: "Arial",
    color: COLOR_CYAN,
    align: "center",
  });

  // Bottom Anatomy Breakdown Inside Left Card
  const logoAnatomy = [
    {
      icon: "🛡️",
      title: "Perisai Cyber Shield (Keamanan)",
      desc: "Bentuk perisai geometris melambangkan proteksi data tingkat tinggi, otorisasi biometrik 2FA, dan keandalan uptime server 99.9%.",
    },
    {
      icon: "⚡",
      title: "Monogram V-T Interlocking (Sinergi)",
      desc: "Huruf V dan T yang menyatu dinamis mencerminkan integrasi mulus antara frontend mobile Flutter dan backend cloud infrastructure.",
    },
    {
      icon: "🌐",
      title: "Dimensi XYZ & Orbit (Skalabilitas)",
      desc: "Aksen koordinat 3D melambangkan ruang komputasi tanpa batas dan solusi cloud end-to-end yang menjangkau seluruh kebutuhan developer.",
    },
  ];

  logoAnatomy.forEach((item, idx) => {
    const itemY = 4.18 + idx * 0.88;
    sLogo.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 0.95,
      y: itemY,
      w: 3.8,
      h: 0.8,
      fill: { color: "0B1020" },
      line: { color: "1E293B", width: 0.8 },
      rectRadius: 0.08,
    });
    sLogo.addText(`${item.icon} ${item.title}`, {
      x: 1.05,
      y: itemY + 0.06,
      w: 3.6,
      h: 0.24,
      fontSize: 8.8,
      fontFace: "Arial",
      bold: true,
      color: COLOR_ACCENT,
    });
    sLogo.addText(item.desc, {
      x: 1.05,
      y: itemY + 0.3,
      w: 3.6,
      h: 0.46,
      fontSize: 7.8,
      fontFace: "Arial",
      color: COLOR_MUTED,
    });
  });

  // 2. Right Top: Dekomposisi Nama Brand (3 Cards Side-by-Side)
  const nameDecomp = [
    {
      badge: "VIBE",
      sub: "Energi, Ritme & UX Dinamis",
      color: COLOR_ACCENT,
      icon: "✨",
      desc: "Merepresentasikan energi positif, ritme inovasi cepat, dan estetika antarmuka Cyber-Neon yang hidup (60 FPS glassmorphism & responsive micro-interactions).",
    },
    {
      badge: "TECH",
      sub: "Arsitektur & Rekayasa Handal",
      color: COLOR_PRIMARY,
      icon: "⚙️",
      desc: "Melambangkan keunggulan rekayasa sistem cloud modern, fondasi database SQLite Offline-First yang tangguh, serta kehandalan arsitektur 3-tier terdistribusi.",
    },
    {
      badge: "XYZ",
      sub: "3D Dimensi & Solusi All-in-One",
      color: COLOR_CYAN,
      icon: "🚀",
      desc: "Melambangkan koordinat 3D ruang komputasi tanpa batas, solusi menyeluruh dari hulu ke hilir (End-to-End), dan dedikasi bagi generasi tech innovator (Gen-Z).",
    },
  ];

  nameDecomp.forEach((nd, idx) => {
    const xPos = 5.1 + idx * 2.54;
    sLogo.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos,
      y: 1.75,
      w: 2.35,
      h: 2.45,
      fill: { color: COLOR_CARD },
      line: { color: nd.color, width: 1.2 },
      rectRadius: 0.15,
    });

    sLogo.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos + 0.15,
      y: 1.9,
      w: 2.05,
      h: 0.38,
      fill: { color: "1A103C" },
      line: { color: nd.color, width: 0.8 },
      rectRadius: 0.08,
    });

    sLogo.addText(`${nd.icon} ${nd.badge}`, {
      x: xPos + 0.15,
      y: 1.9,
      w: 2.05,
      h: 0.38,
      fontSize: 10,
      fontFace: "Arial",
      bold: true,
      color: nd.color,
      align: "center",
    });

    sLogo.addText(nd.sub, {
      x: xPos + 0.15,
      y: 2.35,
      w: 2.05,
      h: 0.32,
      fontSize: 8.8,
      fontFace: "Arial",
      bold: true,
      color: COLOR_WHITE,
    });

    sLogo.addText(nd.desc, {
      x: xPos + 0.15,
      y: 2.7,
      w: 2.05,
      h: 1.4,
      fontSize: 8.0,
      fontFace: "Arial",
      color: COLOR_MUTED,
    });
  });

  // 3. Right Bottom: Psikologi & Harmoni Palet Warna (4 Cards Side-by-Side)
  const colorPhilosophy = [
    {
      name: "Cyber Purple",
      hex: "#7C4DFF",
      role: "Warna Utama Brand",
      meaning: "Simbol inovasi mutakhir, kebijaksanaan teknologi, dan stabilitas arsitektur cloud tingkat tinggi.",
      color: COLOR_PRIMARY,
    },
    {
      name: "Electric Cyan",
      hex: "#00E5FF",
      role: "Data & Latensi Cepat",
      meaning: "Melambangkan kecepatan transmisi data ultra-rendah, transparansi sistem, dan konektivitas live.",
      color: COLOR_CYAN,
    },
    {
      name: "Neon Magenta",
      hex: "#E040FB",
      role: "Kreativitas & Promo",
      meaning: "Mencerminkan antusiasme komunitas pengembang, voucher promo diskon, dan estetika vibrant.",
      color: COLOR_ACCENT,
    },
    {
      name: "Emerald Green",
      hex: "#10B981",
      role: "Keamanan Transaksi",
      meaning: "Menandakan keandalan mutlak, pelunasan instan VibeWallet yang sukses, dan verifikasi 100% aman.",
      color: COLOR_EMERALD,
    },
  ];

  colorPhilosophy.forEach((cp, idx) => {
    const xPos = 5.1 + idx * 1.89;
    sLogo.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos,
      y: 4.38,
      w: 1.74,
      h: 2.57,
      fill: { color: COLOR_CARD },
      line: { color: cp.color, width: 1.2 },
      rectRadius: 0.14,
    });

    // Swatch Color Pill
    sLogo.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos + 0.12,
      y: 4.5,
      w: 1.5,
      h: 0.36,
      fill: { color: cp.color },
      line: { color: COLOR_WHITE, width: 0.5 },
      rectRadius: 0.08,
    });

    sLogo.addText(cp.hex, {
      x: xPos + 0.12,
      y: 4.5,
      w: 1.5,
      h: 0.36,
      fontSize: 8.5,
      fontFace: "Arial",
      bold: true,
      color: (cp.color === COLOR_CYAN || cp.color === COLOR_WHITE) ? "060814" : COLOR_WHITE,
      align: "center",
    });

    sLogo.addText(cp.name, {
      x: xPos + 0.12,
      y: 4.92,
      w: 1.5,
      h: 0.28,
      fontSize: 9.2,
      fontFace: "Arial",
      bold: true,
      color: COLOR_WHITE,
    });

    sLogo.addText(cp.role, {
      x: xPos + 0.12,
      y: 5.2,
      w: 1.5,
      h: 0.25,
      fontSize: 7.8,
      fontFace: "Arial",
      bold: true,
      color: cp.color,
    });

    sLogo.addText(cp.meaning, {
      x: xPos + 0.12,
      y: 5.48,
      w: 1.5,
      h: 1.38,
      fontSize: 7.6,
      fontFace: "Arial",
      color: COLOR_MUTED,
    });
  });

  // =========================================================================
  // SLIDE 3: LATAR BELAKANG & VISI PROPOSAL AWAL
  // =========================================================================
  const s2 = pres.addSlide();
  setupSlideBg(s2);
  addSlideHeader(s2, "Latar Belakang & Proposal", "Melanjutkan Ide Proposal Awal VibeTech", "Mewujudkan visi digitalisasi cloud hosting menjadi aplikasi mobile yang modern, terintegrasi, dan otomatis.");

  s2.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 0.8, y: 1.8, w: 5.7, h: 5.0,
    fill: { color: COLOR_CARD },
    line: { color: COLOR_PRIMARY, width: 1 },
    rectRadius: 0.2,
  });
  s2.addText("📌 Visi dari Proposal Awal", {
    x: 1.1, y: 2.0, w: 5.1, h: 0.35,
    fontSize: 13, fontFace: "Arial", bold: true, color: COLOR_PRIMARY,
  });
  s2.addText(
    [
      { text: "1. Toko Digital Layanan Server\n", options: { bold: true, color: COLOR_WHITE, fontSize: 11 } },
      { text: "Menyediakan katalog terpusat untuk pembelian paket VPS dan hosting game tanpa perantara manual.\n\n", options: { color: COLOR_MUTED, fontSize: 9.5 } },
      { text: "2. Kemudahan Akses Bagi Komunitas Dev & Gamer\n", options: { bold: true, color: COLOR_WHITE, fontSize: 11 } },
      { text: "Memberikan solusi sewa server Pterodactyl dan Bot WhatsApp siap pakai dengan harga terjangkau.\n\n", options: { color: COLOR_MUTED, fontSize: 9.5 } },
      { text: "3. Transaksi Digital yang Terdata Rapi\n", options: { bold: true, color: COLOR_WHITE, fontSize: 11 } },
      { text: "Pencatatan riwayat invoice dan status pesanan agar pengguna dapat melacak masa aktif layanan.", options: { color: COLOR_MUTED, fontSize: 9.5 } },
    ],
    { x: 1.1, y: 2.45, w: 5.1, h: 4.1 }
  );

  s2.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 6.8, y: 1.8, w: 5.7, h: 5.0,
    fill: { color: COLOR_CARD },
    line: { color: COLOR_CYAN, width: 1.5 },
    rectRadius: 0.2,
  });
  s2.addText("🎯 Realisasi & Peningkatan pada Versi 2.0.0", {
    x: 7.1, y: 2.0, w: 5.1, h: 0.35,
    fontSize: 13, fontFace: "Arial", bold: true, color: COLOR_CYAN,
  });
  s2.addText(
    [
      { text: "1. 6 Modul Fitur Utama Terintegrasi\n", options: { bold: true, color: COLOR_WHITE, fontSize: 11 } },
      { text: "Pusat Dashboard, katalog Produk, Pembayaran instan, Keranjang promo, Profil 2FA, dan Kredensial server.\n\n", options: { color: COLOR_MUTED, fontSize: 9.5 } },
      { text: "2. Dual Payment: Saldo Instan & Gateway Midtrans\n", options: { bold: true, color: COLOR_WHITE, fontSize: 11 } },
      { text: "Pelunasan 1-detik via VibeWallet internal serta integrasi gateway resmi QRIS dan Bank Virtual Account.\n\n", options: { color: COLOR_MUTED, fontSize: 9.5 } },
      { text: "3. SQLite Offline-First & Biometric 2FA\n", options: { bold: true, color: COLOR_WHITE, fontSize: 11 } },
      { text: "Persistensi kredensial server di database lokal perangkat dan otorisasi sidik jari hardware.", options: { color: COLOR_MUTED, fontSize: 9.5 } },
    ],
    { x: 7.1, y: 2.45, w: 5.1, h: 4.1 }
  );

  // =========================================================================
  // SLIDE 3: MASUKAN SAAT IDEATION & RESPON DESAIN SISTEM (REQUIREMENT #6)
  // =========================================================================
  const s3 = pres.addSlide();
  setupSlideBg(s3);
  addSlideHeader(s3, "Tahap Ideation & Evaluasi", "Masukan Saat Ideation & Respon Desain Sistem", "Sintesis kritik, saran mentor, dan kebutuhan calon pengguna pada tahap ideation awal yang membentuk keputusan arsitektur.");

  const ideationCards = [
    {
      icon: "⚡",
      badge: "MASUKAN 1: PROVISIONING CEPAT",
      input: "Kritik Ideation: 'Pengguna server butuh server aktif dalam hitungan detik setelah bayar, bukan manual admin berjam-jam.'",
      solution: "Respon Solusi: Membangun instant auto-provisioning engine yang langsung meng-generate record IP, Port SSH, dan root password ke SQLite lokal.",
      color: COLOR_CYAN,
    },
    {
      icon: "💳",
      badge: "MASUKAN 2: BIAYA TRANSAKSI MIKRO",
      input: "Kritik Ideation: 'Biaya admin transfer bank terlalu mahal untuk sewa mikro; butuh dompet internal top-up 1x bayar berkali-kali.'",
      solution: "Respon Solusi: Mengintegrasikan dompet digital VibeWallet dengan auto-deduct saldo atomik 1-detik dan reactive stream listener.",
      color: COLOR_EMERALD,
    },
    {
      icon: "🔒",
      badge: "MASUKAN 3: PRIVASI KREDENSIAL",
      input: "Kritik Ideation: 'Kredensial SSH & password root server sangat sensitif jika tampil vulgar di layar publik.'",
      solution: "Respon Solusi: Menambahkan toggle sensor mata interaktif (show/hide password), PIN 2FA 6-digit, dan hardware biometric LocalAuth.",
      color: COLOR_AMBER,
    },
    {
      icon: "🛒",
      badge: "MASUKAN 4: MULTI-ITEM & DISKON",
      input: "Kritik Ideation: 'Komunitas developer sering menyewa VPS bersamaan dan mengharapkan insentif kupon promo diskon.'",
      solution: "Respon Solusi: Membuat CartService multi-item dengan kalkulator kuantitas dinamis dan voucher parser diskon 30% ('CYBER30').",
      color: COLOR_ACCENT,
    },
  ];

  ideationCards.forEach((c, idx) => {
    const xPos = 0.8 + idx * 2.95;
    s3.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos, y: 1.8, w: 2.75, h: 5.0,
      fill: { color: COLOR_CARD },
      line: { color: c.color, width: 1.2 },
      rectRadius: 0.15,
    });
    s3.addText(c.icon, { x: xPos + 0.15, y: 2.0, w: 2.45, h: 0.35, fontSize: 18 });
    s3.addText(c.badge, { x: xPos + 0.15, y: 2.45, w: 2.45, h: 0.45, fontSize: 9.5, bold: true, color: c.color });
    s3.addText(c.input, { x: xPos + 0.15, y: 2.95, w: 2.45, h: 1.8, fontSize: 8.8, color: "EF4444" });
    s3.addText(c.solution, { x: xPos + 0.15, y: 4.8, w: 2.45, h: 1.85, fontSize: 8.8, color: COLOR_EMERALD });
  });

  // =========================================================================
  // SLIDE 4: PERUBAHAN DARI PROPOSAL (PIVOT) (REQUIREMENT #5)
  // =========================================================================
  const s4 = pres.addSlide();
  setupSlideBg(s4);
  addSlideHeader(s4, "Transformasi Produk", "Perubahan Arah (Pivot) dari Proposal Awal", "Evolusi fundamental dari toko server manual menjadi ekosistem cloud otomatis berteknologi tinggi.");

  const pivotCards = [
    {
      icon: "📦",
      title: "Katalog & Produk",
      before: "Awal: Toko hosting statis yang hanya menjual paket server VPS dasar secara manual.",
      after: "Sekarang: Katalog dinamis multi-kategori (Cloud VPS, Pterodactyl Panel SG & Bot WA).",
    },
    {
      icon: "💳",
      title: "Mekanisme Pembayaran",
      before: "Awal: Pembayaran manual transfer rekening dan konfirmasi via chat admin.",
      after: "Sekarang: Dual-Payment otomatis via VibeWallet 1-klik & Gateway Midtrans Snap QRIS/VA.",
    },
    {
      icon: "🔐",
      title: "Data Kredensial & DB",
      before: "Awal: Data statis hardcoded dalam file lokal tanpa penyimpanan state yang dinamis.",
      after: "Sekarang: SQLite offline-first multi-tabel dengan proteksi kredensial & full CRUD Admin.",
    },
    {
      icon: "🛒",
      title: "Keranjang & Profil",
      before: "Awal: Pembelian single-item kaku tanpa profil akun pengguna terpusat.",
      after: "Sekarang: Keranjang multi-item dinamis dengan diskon promo 30% & profil keamanan 2FA.",
    },
  ];

  pivotCards.forEach((c, idx) => {
    const xPos = 0.8 + idx * 2.95;
    s4.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos, y: 1.8, w: 2.75, h: 5.0,
      fill: { color: COLOR_CARD },
      line: { color: COLOR_PRIMARY, width: 1.2 },
      rectRadius: 0.15,
    });
    s4.addText(c.icon, { x: xPos + 0.2, y: 2.1, w: 2.35, h: 0.4, fontSize: 20 });
    s4.addText(c.title, { x: xPos + 0.2, y: 2.6, w: 2.35, h: 0.5, fontSize: 11.5, bold: true, color: COLOR_WHITE });
    s4.addText(c.before, { x: xPos + 0.2, y: 3.2, w: 2.35, h: 1.5, fontSize: 9.5, color: "EF4444" });
    s4.addText(c.after, { x: xPos + 0.2, y: 4.8, w: 2.35, h: 1.8, fontSize: 9.5, color: COLOR_EMERALD });
  });

  // =========================================================================
  // SLIDE 5: DESKRIPSI TEKNIS & SPESIFIKASI SISTEM (REQUIREMENT #1)
  // =========================================================================
  const s5 = pres.addSlide();
  setupSlideBg(s5);
  addSlideHeader(s5, "Spesifikasi Teknis", "Deskripsi Teknis & Spesifikasi Sistem VibeTech XYZ", "Fondasi rekayasa perangkat lunak, teknologi cross-platform, persistensi offline-first, dan standar keamanan data.");

  const techSpecs = [
    {
      title: "📱 Frontend & Presentation Engine",
      color: COLOR_CYAN,
      items: [
        "Framework: Flutter 3.x (Dart 3.x Engine)",
        "UI Paradigm: Cyber-Neon Dark Mode & Custom Glass Shaders",
        "State Management: Reactive StreamController & Notifiers",
        "Hardware Security: LocalAuth Biometrics (Fingerprint)",
      ],
    },
    {
      title: "💾 Database & Offline-First Persistence",
      color: COLOR_PRIMARY,
      items: [
        "Local Engine: SQLite (sqflite plugin v2.3+)",
        "Architecture: Singleton DatabaseHelper Thread-Safe",
        "Skema: 6 Tabel Relasional (users, services, orders, etc.)",
        "Auto-Migration: DDL Lifecycle onCreate & onUpgrade Hooks",
      ],
    },
    {
      title: "⚡ Backend Microservices & API Gateway",
      color: COLOR_EMERALD,
      items: [
        "Runtime: Node.js (ESM Module Server) & Express.js",
        "Payment Gateway: Midtrans Snap API (QRIS & Multi-Bank VA)",
        "Protocol: RESTful JSON over TLS/HTTPS & Webhooks",
        "Signature: SHA-512 Server Signature Verification",
      ],
    },
    {
      title: "🛡️ Keamanan & Enkripsi Data",
      color: COLOR_ACCENT,
      items: [
        "Session Storage: Encrypted Key-Value SharedPreferences",
        "Password Hashing: SHA-256 Digest dengan Salt Injection",
        "Financial Auth: PIN 2FA 6-Digit Otorisasi Checkout",
        "Sandbox: Isolasi penyimpanan on-device private sandbox",
      ],
    },
  ];

  techSpecs.forEach((ts, idx) => {
    const col = idx % 2;
    const row = Math.floor(idx / 2);
    const xPos = 0.8 + col * 5.9;
    const yPos = 1.8 + row * 2.55;

    s5.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos, y: yPos, w: 5.7, h: 2.35,
      fill: { color: COLOR_CARD },
      line: { color: ts.color, width: 1.2 },
      rectRadius: 0.15,
    });
    s5.addText(ts.title, {
      x: xPos + 0.2, y: yPos + 0.15, w: 5.3, h: 0.35,
      fontSize: 11.5, bold: true, color: ts.color,
    });

    const itemsStr = ts.items.map((i) => `• ${i}`).join("\n");
    s5.addText(itemsStr, {
      x: xPos + 0.2, y: yPos + 0.55, w: 5.3, h: 1.65,
      fontSize: 9.2, color: COLOR_WHITE,
    });
  });

  // =========================================================================
  // SLIDE 6: FITUR IMPLEMENTASI (CHECKLIST) (REQUIREMENT #2)
  // =========================================================================
  const s6 = pres.addSlide();
  setupSlideBg(s6);
  addSlideHeader(s6, "Status Implementasi", "Checklist Fitur Implementasi & Status Verifikasi", "Matriks pengujian dan status fungsionalitas seluruh modul sistem VibeTech XYZ Versi 2.0.0.");

  const checklist = [
    { mod: "1. Interactive Dashboard", feat: "Kartu saldo VibeWallet Rp 10 Juta, 4-Grid Menu Layanan, Banner Portal Admin, Greeting.", status: "VERIFIED", color: COLOR_CYAN },
    { mod: "2. Katalog Produk Server", feat: "Query SQLite services, Filter Chips (VPS/Panel/Bot), Live Search Text, Add to Cart Toast.", status: "VERIFIED", color: COLOR_PRIMARY },
    { mod: "3. Sistem Pembayaran", feat: "Dual checkout VibeWallet & Midtrans Snap, Auto-deduct saldo, PIN 2FA verification, ledger DB.", status: "VERIFIED", color: COLOR_EMERALD },
    { mod: "4. Keranjang Belanja", feat: "Singleton CartService, dynamic Qty (+/-), kupon diskon 30% ('CYBER30'), checkout transition.", status: "VERIFIED", color: COLOR_ACCENT },
    { mod: "5. Profil & Keamanan 2FA", feat: "Avatar & role user/admin, switch bahasa ID/EN, biometric LocalAuth fingerprint, logout sesi.", status: "VERIFIED", color: COLOR_EMERALD },
    { mod: "6. Data Kredensial Server", feat: "SQLite purchased_services, IP & SSH Port display, toggle sensor mata root pass, Copy SSH.", status: "VERIFIED", color: COLOR_AMBER },
  ];

  checklist.forEach((c, idx) => {
    const yPos = 1.8 + idx * 0.82;
    s6.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 0.8, y: yPos, w: 11.73, h: 0.72,
      fill: { color: COLOR_CARD },
      line: { color: c.color, width: 1 },
      rectRadius: 0.1,
    });

    s6.addText(c.mod, {
      x: 1.0, y: yPos + 0.12, w: 2.8, h: 0.45,
      fontSize: 10.5, bold: true, color: c.color,
    });

    s6.addText(c.feat, {
      x: 3.9, y: yPos + 0.12, w: 6.2, h: 0.45,
      fontSize: 9.0, color: COLOR_WHITE,
    });

    s6.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 10.3, y: yPos + 0.14, w: 2.0, h: 0.42,
      fill: { color: "062C1E" },
      line: { color: COLOR_EMERALD, width: 1 },
      rectRadius: 0.08,
    });

    s6.addText("✅ 100% TERUJI", {
      x: 10.3, y: yPos + 0.14, w: 2.0, h: 0.42,
      fontSize: 8.8, bold: true, color: COLOR_EMERALD, align: "center",
    });
  });

  // =========================================================================
  // SLIDE 7: UI PREVIEW / SCREENSHOT (PART 1: DASHBOARD, PRODUK & PEMBAYARAN) (REQUIREMENT #3)
  // =========================================================================
  const s7 = pres.addSlide();
  setupSlideBg(s7);
  addSlideHeader(
    s7,
    "UI Preview & Screenshot (Part 1)",
    "Screenshot Tampilan Aplikasi (1. Dashboard, 2. Produk, 3. Pembayaran)",
    "Tangkapan layar antarmuka pengguna asli pada modul interactive dashboard & dompet, katalog cloud server, dan pembayaran instan VibeWallet."
  );

  const screensPart1 = [
    {
      file: "Dashboard.png",
      number: "01",
      title: "1. Interactive Dashboard",
      category: "Pusat Kontrol & Saldo Dompet",
      color: COLOR_CYAN,
      desc: "Pusat kontrol navigasi pengguna, kartu saldo VibeWallet Rp 10 Juta, grid menu cepat akses produk server, dan banner Portal Admin.",
      points: "• Kartu Saldo VibeWallet Rp 10 Juta\n• Quick Action 4-Grid Akses Produk\n• Reactive Stream Balance & Admin",
    },
    {
      file: "Produk.png",
      number: "02",
      title: "2. Produk Cloud & Server",
      category: "Katalog & Filter Spesifikasi",
      color: COLOR_PRIMARY,
      desc: "Katalog Cloud VPS KVM, Panel Pterodactyl SG & Bot WA dengan filter kategori chip, pencarian live, dan tombol '+ Keranjang'.",
      points: "• Filter Kategori: VPS / Panel / Bot\n• Spesifikasi CPU, RAM, NVMe SSD\n• Tombol Tambah ke Keranjang Instan",
    },
    {
      file: "Pembayaran.png",
      number: "03",
      title: "3. Sistem Pembayaran",
      category: "Dual Checkout VibeWallet",
      color: COLOR_EMERALD,
      desc: "Konfirmasi checkout instan 1-detik dengan Saldo VibeWallet internal, verifikasi PIN 2FA 6-digit, dan rincian potongan diskon.",
      points: "• Pilihan Bayar Saldo VibeWallet\n• Proteksi PIN Transaksi 2FA 6-Digit\n• Auto-Deduct Saldo & Ledger SQLite",
    },
  ];

  screensPart1.forEach((s, idx) => {
    const xPos = 0.85 + idx * 4.0;
    const imgPath = path.join(__dirname, "..", "assets", "ss_vibetech", s.file);

    s7.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos, y: 1.72, w: 3.75, h: 5.2,
      fill: { color: COLOR_CARD },
      line: { color: s.color, width: 1.5 },
      rectRadius: 0.18,
    });

    s7.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos + 0.12, y: 1.84, w: 1.88, h: 4.95,
      fill: { color: "060814" },
      line: { color: s.color, width: 1 },
      rectRadius: 0.12,
    });

    if (fs.existsSync(imgPath)) {
      s7.addImage({
        path: imgPath,
        x: xPos + 0.16, y: 1.88, w: 1.8, h: 4.87,
      });
    }

    s7.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos + 2.08, y: 1.84, w: 1.55, h: 0.4,
      fill: { color: "1A103C" },
      line: { color: s.color, width: 1 },
      rectRadius: 0.08,
    });
    s7.addText(`FITUR ${s.number}`, {
      x: xPos + 2.08, y: 1.84, w: 1.55, h: 0.4,
      fontSize: 9.5, bold: true, color: s.color, align: "center",
    });

    s7.addText(s.title, {
      x: xPos + 2.08, y: 2.32, w: 1.55, h: 0.55,
      fontSize: 10.5, bold: true, color: COLOR_WHITE,
    });

    s7.addText(s.desc, {
      x: xPos + 2.08, y: 2.92, w: 1.55, h: 1.7,
      fontSize: 8.2, color: COLOR_MUTED,
    });

    s7.addShape(pres.shapes.RECTANGLE, {
      x: xPos + 2.08, y: 4.7, w: 1.55, h: 2.08,
      fill: { color: COLOR_CODE_BG },
      line: { color: "1E293B", width: 0.8 },
    });

    s7.addText("📌 Highlight Teknis:", {
      x: xPos + 2.12, y: 4.75, w: 1.47, h: 0.25,
      fontSize: 7.8, bold: true, color: COLOR_CYAN,
    });

    s7.addText(s.points, {
      x: xPos + 2.12, y: 5.02, w: 1.47, h: 1.68,
      fontSize: 7.4, color: "E2E8F0",
    });
  });

  // =========================================================================
  // SLIDE 8: UI PREVIEW / SCREENSHOT (PART 2: KERANJANG, PROFIL & DATA KREDENSIAL)
  // =========================================================================
  const s8 = pres.addSlide();
  setupSlideBg(s8);
  addSlideHeader(
    s8,
    "UI Preview & Screenshot (Part 2)",
    "Screenshot Tampilan Aplikasi (4. Keranjang, 5. Profil, 6. Data Kredensial)",
    "Tangkapan layar antarmuka pengguna asli pada modul keranjang belanja diskon promo, profil keamanan 2FA, dan kontrol kredensial server aktif SQLite."
  );

  const screensPart2 = [
    {
      file: "Keranjang.png",
      number: "04",
      title: "4. Keranjang Belanja",
      category: "Multi-Item & Voucher 30%",
      color: COLOR_ACCENT,
      desc: "Manajemen belanja multi-item dinamis, counter kuantitas produk (+/-), input voucher promo 'CYBER30', dan kalkulasi subtotal.",
      points: "• List Item Belanja Dinamis & Hapus\n• Counter Qty (+ / -) Real-Time\n• Klaim Kupon Diskon Promo 30%",
    },
    {
      file: "Profil.png",
      number: "05",
      title: "5. Profil & Keamanan 2FA",
      category: "Identitas Akun & Biometrik",
      color: COLOR_EMERALD,
      desc: "Manajemen profil pengguna, pengaturan bahasa bilingual (ID/EN), proteksi sidik jari hardware (LocalAuth), dan logout sesi aman.",
      points: "• Avatar Akun & Role Badge User\n• Toggle Bahasa Bilingual (ID/EN)\n• Switch Biometrik Fingerprint 2FA",
    },
    {
      file: "Kartu_layanan.png",
      number: "06",
      title: "6. Data Kredensial Server",
      category: "Server Manager & Kredensial",
      color: COLOR_AMBER,
      desc: "Penyimpanan data kredensial server aktif di SQLite lokal: IP publik, port SSH, username root, password terenkripsi & countdown masa aktif.",
      points: "• Akses IP Publik & Port SSH (22)\n• Password Root & Salin Kredensial\n• Hitung Mundur Masa Aktif & Renew",
    },
  ];

  screensPart2.forEach((s, idx) => {
    const xPos = 0.85 + idx * 4.0;
    const imgPath = path.join(__dirname, "..", "assets", "ss_vibetech", s.file);

    s8.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos, y: 1.72, w: 3.75, h: 5.2,
      fill: { color: COLOR_CARD },
      line: { color: s.color, width: 1.5 },
      rectRadius: 0.18,
    });

    s8.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos + 0.12, y: 1.84, w: 1.88, h: 4.95,
      fill: { color: "060814" },
      line: { color: s.color, width: 1 },
      rectRadius: 0.12,
    });

    if (fs.existsSync(imgPath)) {
      s8.addImage({
        path: imgPath,
        x: xPos + 0.16, y: 1.88, w: 1.8, h: 4.87,
      });
    }

    s8.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos + 2.08, y: 1.84, w: 1.55, h: 0.4,
      fill: { color: "1A103C" },
      line: { color: s.color, width: 1 },
      rectRadius: 0.08,
    });
    s8.addText(`FITUR ${s.number}`, {
      x: xPos + 2.08, y: 1.84, w: 1.55, h: 0.4,
      fontSize: 9.5, bold: true, color: s.color, align: "center",
    });

    s8.addText(s.title, {
      x: xPos + 2.08, y: 2.32, w: 1.55, h: 0.55,
      fontSize: 10.5, bold: true, color: COLOR_WHITE,
    });

    s8.addText(s.desc, {
      x: xPos + 2.08, y: 2.92, w: 1.55, h: 1.7,
      fontSize: 8.2, color: COLOR_MUTED,
    });

    s8.addShape(pres.shapes.RECTANGLE, {
      x: xPos + 2.08, y: 4.7, w: 1.55, h: 2.08,
      fill: { color: COLOR_CODE_BG },
      line: { color: "1E293B", width: 0.8 },
    });

    s8.addText("📌 Highlight Teknis:", {
      x: xPos + 2.12, y: 4.75, w: 1.47, h: 0.25,
      fontSize: 7.8, bold: true, color: COLOR_CYAN,
    });

    s8.addText(s.points, {
      x: xPos + 2.12, y: 5.02, w: 1.47, h: 1.68,
      fontSize: 7.4, color: "E2E8F0",
    });
  });

  // =========================================================================
  // SLIDE 9: UI PREVIEW / SHOWCASE TERPADU 6 FITUR UTAMA
  // =========================================================================
  const s9 = pres.addSlide();
  setupSlideBg(s9);
  addSlideHeader(
    s9,
    "Showcase Terpadu 6 Fitur Utama",
    "Galeri Terpadu: 6 Fitur Utama VibeTech XYZ",
    "Tampilan komprehensif seluruh 6 modul antarmuka utama aplikasi dalam satu kesatuan ekosistem mobile."
  );

  const all6Screens = [
    { file: "Dashboard.png", num: "1", title: "Dashboard", color: COLOR_CYAN, short: "Pusat Kontrol & Saldo Rp 10 Jt" },
    { file: "Produk.png", num: "2", title: "Produk", color: COLOR_PRIMARY, short: "Katalog VPS & Game Server" },
    { file: "Pembayaran.png", num: "3", title: "Pembayaran", color: COLOR_EMERALD, short: "Dual Checkout VibeWallet" },
    { file: "Keranjang.png", num: "4", title: "Keranjang", color: COLOR_ACCENT, short: "Multi-Item & Kupon 30%" },
    { file: "Profil.png", num: "5", title: "Profil", color: COLOR_EMERALD, short: "Akun & Biometrik 2FA" },
    { file: "Kartu_layanan.png", num: "6", title: "Kredensial", color: COLOR_AMBER, short: "Kredensial IP, SSH & Root Pass" },
  ];

  all6Screens.forEach((s, idx) => {
    const xPos = 0.8 + idx * 1.96;
    const imgPath = path.join(__dirname, "..", "assets", "ss_vibetech", s.file);

    s9.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos, y: 1.75, w: 1.86, h: 5.15,
      fill: { color: COLOR_CARD },
      line: { color: s.color, width: 1.2 },
      rectRadius: 0.15,
    });

    s9.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos + 0.08, y: 1.83, w: 1.7, h: 3.7,
      fill: { color: "060814" },
      line: { color: s.color, width: 0.8 },
      rectRadius: 0.1,
    });

    if (fs.existsSync(imgPath)) {
      s9.addImage({
        path: imgPath,
        x: xPos + 0.11, y: 1.86, w: 1.64, h: 3.64,
      });
    }

    s9.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos + 0.08, y: 5.62, w: 1.7, h: 1.18,
      fill: { color: "1A103C" },
      line: { color: s.color, width: 1 },
      rectRadius: 0.08,
    });

    s9.addText(`${s.num}. ${s.title}`, {
      x: xPos + 0.1, y: 5.68, w: 1.66, h: 0.3,
      fontSize: 9.5, bold: true, color: s.color, align: "center",
    });

    s9.addText(s.short, {
      x: xPos + 0.1, y: 6.0, w: 1.66, h: 0.72,
      fontSize: 7.8, color: "E2E8F0", align: "center",
    });
  });

  // =========================================================================
  // SLIDE 10: UI PREVIEW / REKAMAN DEMO APLIKASI (9:16 VERTICAL SMARTPHONE FORMAT)
  // =========================================================================
  const s10 = pres.addSlide();
  setupSlideBg(s10);
  addSlideHeader(
    s10,
    "UI Preview: Video Rekaman Demo (9:16)",
    "UI Preview: Rekaman Demonstrasi 6 Fitur Utama (9:16 Portrait)",
    "Video rekaman demonstrasi langsung alur end-to-end aplikasi VibeTech XYZ dalam format native smartphone 9:16 secara real-time."
  );

  let videoPath = path.join(__dirname, "..", "assets", "Record_aplikasi_VibeTech_6_Fitur.mp4");
  if (!fs.existsSync(videoPath)) {
    videoPath = path.join(__dirname, "..", "assets", "ss_vibetech", "Record_aplikasi_VibeTech_6_Fitur.mp4");
  }
  if (!fs.existsSync(videoPath)) {
    videoPath = path.join(__dirname, "..", "assets", "Record aplikasi VibeTech 6 Fitur.webm");
  }
  if (!fs.existsSync(videoPath)) {
    videoPath = path.join(__dirname, "..", "assets", "ss_vibetech", "Record aplikasi VibeTech 6 Fitur.webm");
  }

  let thumbPath = path.join(__dirname, "..", "assets", "record_thumbnail.png");
  if (!fs.existsSync(thumbPath)) {
    thumbPath = path.join(__dirname, "..", "assets", "ss_vibetech", "record_thumbnail.png");
  }
  let coverBase64 = null;
  if (fs.existsSync(thumbPath)) {
    coverBase64 = "data:image/png;base64," + fs.readFileSync(thumbPath).toString("base64");
  }

  // 1. Left: Smartphone Mockup Frame (Taller 9:16 Aspect Ratio)
  s10.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 0.75,
    y: 1.55,
    w: 2.95,
    h: 5.65,
    fill: { color: COLOR_CARD },
    line: { color: COLOR_CYAN, width: 1.8 },
    rectRadius: 0.22,
  });

  // Top Speaker / Camera Notch
  s10.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 1.75,
    y: 1.60,
    w: 0.95,
    h: 0.08,
    fill: { color: "060814" },
    line: { color: "1E293B", width: 0.6 },
    rectRadius: 0.04,
  });

  // Tall 9:16 Video Player Embedding
  if (fs.existsSync(videoPath)) {
    const mediaOpts = {
      type: "video",
      path: videoPath,
      x: 0.83,
      y: 1.70,
      w: 2.79,
      h: 5.40,
    };
    if (coverBase64) {
      mediaOpts.cover = coverBase64;
    }
    s10.addMedia(mediaOpts);
  }

  // 2. Middle: Demonstration Timeline Breakdown Box
  s10.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 3.90,
    y: 1.55,
    w: 4.70,
    h: 5.65,
    fill: { color: COLOR_CARD },
    line: { color: COLOR_PRIMARY, width: 1.4 },
    rectRadius: 0.18,
  });

  s10.addText("🎬 Timeline Demonstrasi 6 Fitur Utama", {
    x: 4.10,
    y: 1.72,
    w: 4.30,
    h: 0.35,
    fontSize: 11.5,
    bold: true,
    color: COLOR_ACCENT,
  });

  const demoSteps = [
    { time: "00:00 - 00:25", num: "01", title: "Dashboard & VibeWallet", desc: "Greeting 'Halo, Razik', kartu saldo Rp 10 Jt & quick menu 4-grid.", color: COLOR_CYAN },
    { time: "00:25 - 00:50", num: "02", title: "Katalog Produk Server", desc: "Live search & filter kategori VPS KVM, Panel SG & Bot WA.", color: COLOR_PRIMARY },
    { time: "00:50 - 01:15", num: "03", title: "Keranjang & Kupon 30%", desc: "Counter kuantitas (+/-) & potongan kupon promo 'CYBER30'.", color: COLOR_ACCENT },
    { time: "01:15 - 01:40", num: "04", title: "Dual Pembayaran Instan", desc: "Pelunasan saldo VibeWallet 1-detik & verifikasi PIN 2FA 6-digit.", color: COLOR_EMERALD },
    { time: "01:40 - 02:05", num: "05", title: "Profil & Biometrik 2FA", desc: "Toggle bilingual (ID/EN) & sensor sidik jari hardware.", color: COLOR_EMERALD },
    { time: "02:05 - 02:24", num: "06", title: "Data Kredensial Server", desc: "Akses IP publik, port SSH, toggle mata password & copy command.", color: COLOR_AMBER },
  ];

  demoSteps.forEach((st, idx) => {
    const yPos = 2.15 + idx * 0.80;
    s10.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 4.10,
      y: yPos,
      w: 4.30,
      h: 0.72,
      fill: { color: "090D1E" },
      line: { color: st.color, width: 0.8 },
      rectRadius: 0.08,
    });
    s10.addText(`${st.num}. ${st.title} (${st.time})`, {
      x: 4.25,
      y: yPos + 0.08,
      w: 4.00,
      h: 0.28,
      fontSize: 9.2,
      bold: true,
      color: st.color,
    });
    s10.addText(st.desc, {
      x: 4.25,
      y: yPos + 0.36,
      w: 4.00,
      h: 0.32,
      fontSize: 8.0,
      color: COLOR_MUTED,
    });
  });

  // 3. Right: Highlights & Video Technical Specs Box
  s10.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 8.80,
    y: 1.55,
    w: 3.73,
    h: 5.65,
    fill: { color: COLOR_CARD },
    line: { color: COLOR_EMERALD, width: 1.4 },
    rectRadius: 0.18,
  });

  s10.addText("📱 Format Rekaman & Kualitas", {
    x: 9.00,
    y: 1.72,
    w: 3.33,
    h: 0.35,
    fontSize: 11.5,
    bold: true,
    color: COLOR_EMERALD,
  });

  const techBadges = [
    { title: "Rasio 9:16 Portrait Native", desc: "Format layar ponsel 1080x2424 px sesuai pengalaman pengguna nyata.", color: COLOR_CYAN },
    { title: "Framerate 60 FPS Smooth", desc: "Animasi UI cyberpunk mengalir mulus tanpa frame drop atau freeze.", color: COLOR_EMERALD },
    { title: "Hardware Biometric Auth", desc: "Pengujian sensor sidik jari langsung pada perangkat fisik.", color: COLOR_ACCENT },
    { title: "SQLite Real-Time Sync", desc: "Semua aksi mutasi langsung tersimpan ke database 'vibetech.db'.", color: COLOR_AMBER },
  ];

  techBadges.forEach((tb, idx) => {
    const yPos = 2.15 + idx * 1.02;
    s10.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 9.00,
      y: yPos,
      w: 3.33,
      h: 0.88,
      fill: { color: "0A1E35" },
      line: { color: tb.color, width: 0.8 },
      rectRadius: 0.08,
    });
    s10.addText(tb.title, {
      x: 9.15,
      y: yPos + 0.10,
      w: 3.03,
      h: 0.30,
      fontSize: 9.4,
      bold: true,
      color: tb.color,
    });
    s10.addText(tb.desc, {
      x: 9.15,
      y: yPos + 0.40,
      w: 3.03,
      h: 0.44,
      fontSize: 8.0,
      color: "E2E8F0",
    });
  });

  s10.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 9.00,
    y: 6.45,
    w: 3.33,
    h: 0.58,
    fill: { color: "062C1E" },
    line: { color: COLOR_EMERALD, width: 1 },
    rectRadius: 0.08,
  });
  s10.addText("✅ 100% TERUJI DI PERANGKAT NYATA", {
    x: 9.00,
    y: 6.45,
    w: 3.33,
    h: 0.58,
    fontSize: 9.0,
    bold: true,
    color: COLOR_EMERALD,
    align: "center",
  });

  // =========================================================================
  // SLIDE 11: 6 PILAR FITUR UTAMA VIBETECH XYZ
  // =========================================================================
  const s11 = pres.addSlide();
  setupSlideBg(s11);
  addSlideHeader(s11, "Fitur & Kapabilitas", "6 Pilar Fitur Utama VibeTech XYZ", "Inovasi arsitektur terintegrasi yang menghadirkan efisiensi, keamanan, dan otomatisasi.");

  const features = [
    { icon: "📊", title: "Interactive Dashboard & Saldo", desc: "Pusat kendali pengguna dengan kartu saldo VibeWallet Rp 10 Juta, navigasi 4-grid produk server instan, dan banner Portal Admin.", color: COLOR_CYAN },
    { icon: "📦", title: "Produk Cloud & Server", desc: "Katalog terpusat untuk paket Cloud VPS KVM, Hosting Game Pterodactyl SG, dan Bot WhatsApp dengan filter kategori & spesifikasi lengkap.", color: COLOR_PRIMARY },
    { icon: "💳", title: "Sistem Pembayaran Cepat", desc: "Pelunasan instan 1-detik via saldo dompet internal VibeWallet dengan proteksi verifikasi PIN 2FA 6-digit & auto-deduction.", color: COLOR_EMERALD },
    { icon: "🛒", title: "Keranjang & Diskon Promo", desc: "Manajemen keranjang belanja multi-item dinamis, kalkulasi subtotal otomatis, dan penerapan kode kupon diskon promo 30%.", color: COLOR_ACCENT },
    { icon: "👤", title: "Profil Pengguna & 2FA", desc: "Manajemen identitas akun pengguna, pengaturan bahasa (ID/EN), aktivasi keamanan biometrik sidik jari (LocalAuth), dan logout sesi.", color: COLOR_EMERALD },
    { icon: "🔐", title: "Data Kredensial Server", desc: "Penyimpanan lokal SQLite aman untuk IP publik, port SSH, username, root password server aktif, serta monitoring masa aktif.", color: COLOR_AMBER },
  ];

  features.forEach((f, idx) => {
    const col = idx % 3;
    const row = Math.floor(idx / 3);
    const xPos = 0.8 + col * 3.95;
    const yPos = 1.8 + row * 2.55;

    s11.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos, y: yPos, w: 3.75, h: 2.35,
      fill: { color: COLOR_CARD },
      line: { color: f.color, width: 1.2 },
      rectRadius: 0.15,
    });
    s11.addText(f.icon, { x: xPos + 0.2, y: yPos + 0.15, w: 0.5, h: 0.4, fontSize: 18 });
    s11.addText(f.title, { x: xPos + 0.75, y: yPos + 0.15, w: 2.8, h: 0.4, fontSize: 11, bold: true, color: COLOR_WHITE });
    s11.addText(f.desc, { x: xPos + 0.2, y: yPos + 0.65, w: 3.35, h: 1.55, fontSize: 9.5, color: COLOR_MUTED });
  });

  // =========================================================================
  // SLIDE 12: KEUNGGULAN KOMPETITIF
  // =========================================================================
  const s12 = pres.addSlide();
  setupSlideBg(s12);
  addSlideHeader(s12, "Keunggulan Kompetitif", "Mengapa VibeTech Lebih Unggul?", "Perbandingan teknis dan fungsional antara VibeTech XYZ dengan layanan konvensional.");

  const compData = [
    { feature: "Pusat Kontrol & Dashboard", conventional: "Menu Statis Kaku Tanpa Status Saldo", vibetech: "Interactive Dashboard & Saldo VibeWallet", win: true },
    { feature: "Katalog & Variasi Produk", conventional: "Terbatas Hanya Paket VPS Manual", vibetech: "Katalog Lengkap (VPS, Panel SG, Bot WA)", win: true },
    { feature: "Kecepatan Pembayaran", conventional: "Manual Konfirmasi Admin 1-12 Jam", vibetech: "Instan 1-Detik via VibeWallet & QRIS", win: true },
    { feature: "Pengelolaan Keranjang & Kupon", conventional: "Beli Satu-Satu Tanpa Diskon", vibetech: "Multi-Item Cart + Promo Voucher 30%", win: true },
    { feature: "Keamanan Akun & Profil", conventional: "Password Teks Standar", vibetech: "Biometrik Sidik Jari + 2FA PIN 6-Digit", win: true },
    { feature: "Penyimpanan Kredensial Server", conventional: "Tergantung Email & Chat Admin", vibetech: "SQLite Offline-First Multi-Table Relasi", win: true },
  ];

  s12.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 0.8, y: 1.8, w: 11.73, h: 0.5,
    fill: { color: "1A103C" },
    line: { color: COLOR_PRIMARY, width: 1 },
    rectRadius: 0.1,
  });
  s12.addText("FITUR / ASPEK TEKNIS", { x: 1.0, y: 1.85, w: 3.5, h: 0.4, fontSize: 10.5, bold: true, color: COLOR_CYAN });
  s12.addText("PENYEDIA KONVENSIONAL", { x: 4.6, y: 1.85, w: 3.5, h: 0.4, fontSize: 10.5, bold: true, color: "EF4444" });
  s12.addText("VIBETECH XYZ (V2.0.0)", { x: 8.2, y: 1.85, w: 4.1, h: 0.4, fontSize: 10.5, bold: true, color: COLOR_EMERALD });

  compData.forEach((row, idx) => {
    const yPos = 2.4 + idx * 0.75;
    s12.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 0.8, y: yPos, w: 11.73, h: 0.65,
      fill: { color: idx % 2 === 0 ? COLOR_CARD : "090D1E" },
      line: { color: "1E293B", width: 0.8 },
      rectRadius: 0.08,
    });
    s12.addText(row.feature, { x: 1.0, y: yPos + 0.1, w: 3.5, h: 0.45, fontSize: 9.5, bold: true, color: COLOR_WHITE });
    s12.addText(`❌ ${row.conventional}`, { x: 4.6, y: yPos + 0.1, w: 3.5, h: 0.45, fontSize: 9.0, color: COLOR_MUTED });
    s12.addText(`✨ ${row.vibetech}`, { x: 8.2, y: yPos + 0.1, w: 4.1, h: 0.45, fontSize: 9.5, bold: true, color: COLOR_EMERALD });
  });

  // =========================================================================
  // SLIDE 13: ARSITEKTUR SISTEM LENGKAP (3-TIER)
  // =========================================================================
  const s13 = pres.addSlide();
  setupSlideBg(s13);
  addSlideHeader(s13, "Arsitektur Sistem", "Arsitektur 3-Tier Terdistribusi VibeTech", "Struktur interkoneksi Client, Backend Microservices, dan External Cloud Infrastructure.");

  const tiers = [
    {
      title: "TIER 1: PRESENTATION & CLIENT LAYER",
      sub: "Flutter 3.x Cross-Platform Engine (Android/iOS/Web)",
      color: COLOR_CYAN,
      items: [
        "Cyberpunk Neon Glassmorphic UI (Custom AppColors & Shaders)",
        "Hardware Biometric Authentication (LocalAuth Fingerprint)",
        "SQLite Offline-First Local Storage (DatabaseHelper Multi-Table)",
        "Real-Time Reactive Stream Controllers & State Management",
      ],
    },
    {
      title: "TIER 2: BACKEND & PAYMENT MICROSERVICES",
      sub: "Node.js Express ESM Server Microservices",
      color: COLOR_PRIMARY,
      items: [
        "Payment Engine Gateway (Midtrans Snap Token Generator)",
        "Webhook Notification Handler & Order Status Synchronizer",
        "Server Health & Datacenter Node Latency Inspector",
        "REST API JSON Interceptor & Encrypted Payload Security",
      ],
    },
    {
      title: "TIER 3: EXTERNAL INFRASTRUCTURE & CLOUD",
      sub: "Datacenters, Payment Gateways & External Nodes",
      color: COLOR_EMERALD,
      items: [
        "Midtrans Production Gateway (QRIS Dynamic & Multi-Bank Virtual Accounts)",
        "Pterodactyl Singapore Cluster Nodes & Linux KVM VPS",
        "Encrypted SQLite Database Engine (vibetech.db on-device)",
        "WhatsApp Official Gateway Integration (wa.me/6287885873325)",
      ],
    },
  ];

  tiers.forEach((t, idx) => {
    const yPos = 1.8 + idx * 1.7;
    s13.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 0.8, y: yPos, w: 11.73, h: 1.55,
      fill: { color: COLOR_CARD },
      line: { color: t.color, width: 1.5 },
      rectRadius: 0.15,
    });
    s13.addText(t.title, {
      x: 1.1, y: yPos + 0.15, w: 7.0, h: 0.35,
      fontSize: 12, fontFace: "Arial", bold: true, color: t.color,
    });
    s13.addText(t.sub, {
      x: 8.2, y: yPos + 0.15, w: 4.1, h: 0.35,
      fontSize: 9.5, color: COLOR_MUTED, align: "right",
    });

    const col1 = t.items.slice(0, 2).map((i) => `• ${i}`).join("\n");
    const col2 = t.items.slice(2, 4).map((i) => `• ${i}`).join("\n");

    s13.addText(col1, { x: 1.1, y: yPos + 0.55, w: 5.4, h: 0.85, fontSize: 9.2, color: COLOR_WHITE });
    s13.addText(col2, { x: 6.7, y: yPos + 0.55, w: 5.6, h: 0.85, fontSize: 9.2, color: COLOR_WHITE });
  });

  // =========================================================================
  // SLIDE 14: SIKLUS HIDUP SQLITE (DATABASE HELPER)
  // =========================================================================
  const s14 = pres.addSlide();
  setupSlideBg(s14);
  addSlideHeader(s14, "Database Lifecycle", "Siklus Hidup DatabaseHelper SQLite", "Mekanisme pembukaan, pembuatan tabel, auto-seeding, dan migrasi skema database.");

  const steps = [
    { num: "01", title: "Singleton Instance", desc: "DatabaseHelper.instance memastikan hanya ada satu koneksi aktif di memori aplikasi.", color: COLOR_CYAN },
    { num: "02", title: "openDatabase()", desc: "Membuka file SQLite 'vibetech.db' di direktori penyimpanan lokal perangkat.", color: COLOR_PRIMARY },
    { num: "03", title: "_onCreate Hook", desc: "Mengeksekusi query DDL untuk membuat 6 tabel: users, services, transactions, dll.", color: COLOR_ACCENT },
    { num: "04", title: "Auto-Seeding Data", desc: "Injeksi otomatis data default: akun admin, katalog VPS, panel SG, dan bot WhatsApp.", color: COLOR_EMERALD },
    { num: "05", title: "CRUD Operations", desc: "Menyediakan ratusan method async untuk query, insert, update atomik, dan delete record.", color: COLOR_AMBER },
    { num: "06", title: "Auto-Recalculate", desc: "Sinkronisasi saldo dan total belanja secara real-time ke SharedPreferences & Stream.", color: COLOR_CYAN },
  ];

  steps.forEach((st, idx) => {
    const col = idx % 3;
    const row = Math.floor(idx / 3);
    const xPos = 0.8 + col * 3.95;
    const yPos = 1.8 + row * 2.55;

    s14.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos, y: yPos, w: 3.75, h: 2.35,
      fill: { color: COLOR_CARD },
      line: { color: st.color, width: 1.2 },
      rectRadius: 0.15,
    });
    s14.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos + 0.2, y: yPos + 0.2, w: 0.7, h: 0.45,
      fill: { color: "1A103C" },
      line: { color: st.color, width: 1 },
      rectRadius: 0.1,
    });
    s14.addText(st.num, {
      x: xPos + 0.2, y: yPos + 0.2, w: 0.7, h: 0.45,
      fontSize: 12, bold: true, color: st.color, align: "center",
    });
    s14.addText(st.title, {
      x: xPos + 1.05, y: yPos + 0.2, w: 2.5, h: 0.45,
      fontSize: 11, bold: true, color: COLOR_WHITE,
    });
    s14.addText(st.desc, {
      x: xPos + 0.2, y: yPos + 0.8, w: 3.35, h: 1.35,
      fontSize: 9.5, color: COLOR_MUTED,
    });
  });

  // =========================================================================
  // SLIDE 15: DDL SCHEMA MULTI-TABLE SQLITE
  // =========================================================================
  const s15 = pres.addSlide();
  setupSlideBg(s15);
  addSlideHeader(s15, "Skema Database SQLite", "DDL Schema & Relasi 6 Tabel Utama", "Struktur skema tabel SQLite offline-first yang menjamin integritas data transaksi dan layanan.");

  const tables = [
    { name: "users", desc: "id, uid, username, email, password, pin (6-digit), role, saldo, created_at", color: COLOR_PRIMARY },
    { name: "services", desc: "id, nama_produk, kategori, harga, spesifikasi, stok, rating, icon", color: COLOR_CYAN },
    { name: "purchased_services", desc: "id, user_email, nama_produk, kategori, ip_address, port, root_password, expired_at", color: COLOR_EMERALD },
    { name: "transactions", desc: "id, invoice_no, user_email, nama_produk, total_harga, payment_method, status, tanggal", color: COLOR_ACCENT },
    { name: "cart_items", desc: "id, user_email, product_id, nama_produk, harga, kuantitas, subtotal", color: COLOR_AMBER },
    { name: "chat_messages", desc: "id, user_email, sender, message, timestamp, is_bot, emotion", color: COLOR_WHITE },
  ];

  tables.forEach((t, idx) => {
    const col = idx % 2;
    const row = Math.floor(idx / 2);
    const xPos = 0.8 + col * 5.9;
    const yPos = 1.8 + row * 1.7;

    s15.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos, y: yPos, w: 5.7, h: 1.55,
      fill: { color: COLOR_CARD },
      line: { color: t.color, width: 1.2 },
      rectRadius: 0.15,
    });
    s15.addText(`TABLE: ${t.name.toUpperCase()}`, {
      x: xPos + 0.2, y: yPos + 0.15, w: 5.3, h: 0.35,
      fontSize: 11.5, fontFace: "Courier New", bold: true, color: t.color,
    });
    s15.addText(t.desc, {
      x: xPos + 0.2, y: yPos + 0.55, w: 5.3, h: 0.85,
      fontSize: 9.0, fontFace: "Courier New", color: COLOR_MUTED,
    });
  });

  // =========================================================================
  // SLIDE 16: IMPLEMENTASI SQLITE CRUD LENGKAP
  // =========================================================================
  const s16 = pres.addSlide();
  setupSlideBg(s16);
  addSlideHeader(s16, "Implementasi Database", "Implementasi Lengkap Operasi CRUD SQLite", "Standarisasi query Create, Read, Update, dan Delete di seluruh lapisan aplikasi.");

  const cruds = [
    {
      op: "CREATE (INSERT)",
      code: "await db.insert('users', newUserMap);\nawait db.insert('transactions', orderMap);\nawait db.insert('purchased_services', svcMap);",
      color: COLOR_EMERALD,
    },
    {
      op: "READ (SELECT & FILTER)",
      code: "final users = await db.query('users');\nfinal orders = await db.query('transactions',\n  where: 'user_email = ?', whereArgs: [email]);",
      color: COLOR_CYAN,
    },
    {
      op: "UPDATE (MODIFY ATOMIC)",
      code: "await db.update('users', updateData,\n  where: 'id = ?', whereArgs: [id]);\nawait db.rawUpdate('UPDATE users SET saldo = ?\n  WHERE email = ?', [newBalance, email]);",
      color: COLOR_AMBER,
    },
    {
      op: "DELETE (REMOVE RECORD)",
      code: "await db.delete('users', where: 'id = ?', whereArgs: [id]);\nawait db.delete('transactions',\n  where: 'id = ?', whereArgs: [id]);",
      color: COLOR_RED,
    },
  ];

  cruds.forEach((c, idx) => {
    const col = idx % 2;
    const row = Math.floor(idx / 2);
    const xPos = 0.8 + col * 5.9;
    const yPos = 1.8 + row * 2.55;

    s16.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos, y: yPos, w: 5.7, h: 2.35,
      fill: { color: COLOR_CARD },
      line: { color: c.color, width: 1.2 },
      rectRadius: 0.15,
    });
    s16.addText(c.op, {
      x: xPos + 0.2, y: yPos + 0.15, w: 5.3, h: 0.35,
      fontSize: 11.5, bold: true, color: c.color,
    });
    s16.addShape(pres.shapes.RECTANGLE, {
      x: xPos + 0.2, y: yPos + 0.55, w: 5.3, h: 1.6,
      fill: { color: COLOR_CODE_BG },
    });
    s16.addText(c.code, {
      x: xPos + 0.3, y: yPos + 0.65, w: 5.1, h: 1.4,
      fontSize: 8.5, fontFace: "Courier New", color: COLOR_WHITE,
    });
  });

  // =========================================================================
  // SLIDE 17: DEEP-DIVE FITUR 1: DASHBOARD (Dashboard.png)
  // =========================================================================
  const s17 = pres.addSlide();
  addScreenshotCodeSlide(
    s17,
    "Deep-Dive Fitur Utama (1/6)",
    "Fitur 1: Modul Interactive Dashboard & Wallet",
    "Pusat kontrol navigasi pengguna, kartu saldo VibeWallet Rp 10.000.000, dan grid akses cepat produk server.",
    "Dashboard.png",
    "🖼️ Elemen Visual UI pada Dashboard.png",
    [
      { text: "• [1] Header Salam & Role Akun:\n", options: { bold: true, color: COLOR_CYAN } },
      { text: "Menampilkan greeting personal 'Halo, Razik' dan badge role 'USER' / 'ADMIN'.\n\n", options: { color: COLOR_MUTED } },
      { text: "• [2] Kartu VibeWallet Rp 10 Juta:\n", options: { bold: true, color: COLOR_EMERALD } },
      { text: "Saldo internal Rp 10.000.000, tombol Top-Up instan, dan riwayat mutasi.\n\n", options: { color: COLOR_MUTED } },
      { text: "• [3] Quick Action 4-Grid Menu:\n", options: { bold: true, color: COLOR_ACCENT } },
      { text: "Akses cepat 1-sentuhan: Cloud VPS, Panel Pterodactyl SG, Bot WA & Layanan Aktif.\n\n", options: { color: COLOR_MUTED } },
      { text: "• [4] Banner Akses Portal Admin:\n", options: { bold: true, color: COLOR_WHITE } },
      { text: "Khusus role admin: shortcut cepat menuju halaman kontrol database SQLite.", options: { color: COLOR_MUTED } },
    ],
    "💻 Penjelasan Codingan Flutter Dart (Dashboard)",
    `// [2] Reactive Balance Stream & Load User Data
@override
void initState() {
  super.initState();
  _loadUserSession();
  BalanceService.balanceStream.listen((newBalance) {
    setState(() => _currentBalance = newBalance);
  });
}

// [3] Grid Navigation Quick Actions
Widget _buildQuickGrid() {
  return GridView.count(
    crossAxisCount: 4,
    children: [
      _actionItem('Cloud VPS', Icons.cloud, () => _navToVPS()),
      _actionItem('Panel SG', Icons.games, () => _navToPanel()),
      _actionItem('Bot WA', Icons.chat, () => _navToBot()),
      _actionItem('Server', Icons.dns, () => _navToServices()),
    ],
  );
}`,
    COLOR_CYAN
  );

  // =========================================================================
  // SLIDE 18: DEEP-DIVE FITUR 2: PRODUK (Produk.png)
  // =========================================================================
  const s18 = pres.addSlide();
  addScreenshotCodeSlide(
    s18,
    "Deep-Dive Fitur Utama (2/6)",
    "Fitur 2: Modul Produk & Katalog Cloud Server",
    "Katalog terpusat paket server Cloud VPS, Panel Pterodactyl SG, dan Bot WhatsApp dengan filter kategori & live query.",
    "Produk.png",
    "🖼️ Elemen Visual UI pada Produk.png",
    [
      { text: "• [1] Search Bar & Live Query:\n", options: { bold: true, color: COLOR_CYAN } },
      { text: "Pencarian instan nama paket server, kapasitas RAM, atau CPU secara real-time.\n\n", options: { color: COLOR_MUTED } },
      { text: "• [2] Filter Kategori Chips:\n", options: { bold: true, color: COLOR_ACCENT } },
      { text: "Filter dinamis: 'Semua', 'Cloud VPS KVM', 'Panel SG', dan 'Bot WhatsApp'.\n\n", options: { color: COLOR_MUTED } },
      { text: "• [3] Kartu Spesifikasi & Harga:\n", options: { bold: true, color: COLOR_WHITE } },
      { text: "Rincian spesifikasi CPU Core, RAM DDR4, NVMe Storage, dan tag harga sewa.\n\n", options: { color: COLOR_MUTED } },
      { text: "• [4] Tombol '+ Keranjang':\n", options: { bold: true, color: COLOR_EMERALD } },
      { text: "Menambahkan produk ke keranjang belanja lokal dengan animasi toast glow.", options: { color: COLOR_MUTED } },
    ],
    "💻 Penjelasan Codingan Flutter Dart (Produk)",
    `// [1 & 2] Query Produk SQLite & Live Filter
Future<List<Product>> getFilteredProducts(
    String query, String category) async {
  final db = await DatabaseHelper.instance.database;
  String whereClause = '1=1';
  List<dynamic> args = [];
  if (category != 'Semua') {
    whereClause += ' AND kategori = ?';
    args.add(category);
  }
  if (query.isNotEmpty) {
    whereClause += ' AND nama_produk LIKE ?';
    args.add('%\$query%');
  }
  final res = await db.query('services',
      where: whereClause, whereArgs: args);
  return res.map((m) => Product.fromMap(m)).toList();
}

// [4] Tambah Produk ke Singleton CartService
void addToCart(Product item) {
  CartService.addItem(item);
  _showNeonToast('Produk ditambahkan ke keranjang!');
}`,
    COLOR_PRIMARY
  );

  // =========================================================================
  // SLIDE 19: DEEP-DIVE FITUR 3: PEMBAYARAN (Pembayaran.png)
  // =========================================================================
  const s19 = pres.addSlide();
  addScreenshotCodeSlide(
    s19,
    "Deep-Dive Fitur Utama (3/6)",
    "Fitur 3: Modul Sistem Pembayaran Cepat VibeWallet",
    "Konfirmasi pembayaran instan 1-detik via Saldo VibeWallet internal dengan proteksi verifikasi PIN 2FA 6-digit.",
    "Pembayaran.png",
    "🖼️ Elemen Visual UI pada Pembayaran.png",
    [
      { text: "• [1] Ringkasan Tagihan & Diskon:\n", options: { bold: true, color: COLOR_CYAN } },
      { text: "Rincian subtotal, kupon promo potongan harga, dan total akhir yang harus dibayar.\n\n", options: { color: COLOR_MUTED } },
      { text: "• [2] Pilihan 1: Saldo VibeWallet:\n", options: { bold: true, color: COLOR_EMERALD } },
      { text: "Pelunasan 1-klik instan menggunakan saldo dompet internal dengan proteksi PIN.\n\n", options: { color: COLOR_MUTED } },
      { text: "• [3] Pilihan 2: Midtrans Snap Gateway:\n", options: { bold: true, color: COLOR_ACCENT } },
      { text: "Pelunasan via QRIS dinamis (Gopay/Dana/ShopeePay) dan Virtual Account Bank.\n\n", options: { color: COLOR_MUTED } },
      { text: "• [4] Tombol 'Bayar Sekarang':\n", options: { bold: true, color: COLOR_WHITE } },
      { text: "Memvalidasi metode pembayaran dan mengeksekusi transaksi secara atomik.", options: { color: COLOR_MUTED } },
    ],
    "💻 Penjelasan Codingan Flutter Dart (Pembayaran)",
    `// [2 & 3] Eksekusi Dual-Payment Conditional Branch
if (selectedPaymentMethod == 'VIBEWALLET') {
  // Opsi A: Potong Saldo VibeWallet Internal
  final bool success = await DatabaseHelper.instance
      .deductUserBalance(userEmail, totalBayar);
  if (success) {
    await DatabaseHelper.instance.insertTransaction(orderData);
    await ProvisioningService.autoDeployServer(orderData);
    _showSuccessDialog('Pembayaran Berhasil! Server Aktif.');
  }
} else {
  // Opsi B: Panggil Gateway Midtrans Snap API
  final String snapToken = await MidtransService
      .createSnapTransaction(orderData);
  _openMidtransSnapWebView(snapToken);
}`,
    COLOR_EMERALD
  );

  // =========================================================================
  // SLIDE 20: DEEP-DIVE FITUR 4: KERANJANG (Keranjang.png)
  // =========================================================================
  const s20 = pres.addSlide();
  addScreenshotCodeSlide(
    s20,
    "Deep-Dive Fitur Utama (4/6)",
    "Fitur 4: Modul Keranjang Belanja & Diskon Promo",
    "Kalkulasi kuantitas produk dinamis, validasi kode voucher diskon 30%, dan kalkulasi total biaya pesanan.",
    "Keranjang.png",
    "🖼️ Elemen Visual UI pada Keranjang.png",
    [
      { text: "• [1] List Item Keranjang Dinamis:\n", options: { bold: true, color: COLOR_CYAN } },
      { text: "Daftar item belanja dengan nama server, harga satuan, dan tombol hapus.\n\n", options: { color: COLOR_MUTED } },
      { text: "• [2] Tombol Counter Qty (+ / -):\n", options: { bold: true, color: COLOR_WHITE } },
      { text: "Penambahan/pengurangan kuantitas pesanan dengan update total instan.\n\n", options: { color: COLOR_MUTED } },
      { text: "• [3] Input Kupon Promo Diskon:\n", options: { bold: true, color: COLOR_ACCENT } },
      { text: "Input voucher promo (e.g. 'CYBER30') dengan verifikasi diskon 30% otomatis.\n\n", options: { color: COLOR_MUTED } },
      { text: "• [4] Total Biaya & Tombol Checkout:\n", options: { bold: true, color: COLOR_EMERALD } },
      { text: "Rincian subtotal, potongan diskon, dan navigasi ke modul pembayaran.", options: { color: COLOR_MUTED } },
    ],
    "💻 Penjelasan Codingan Flutter Dart (Keranjang)",
    `// [3] Validasi Kupon Diskon Promo
void applyVoucher(String code) {
  if (code.toUpperCase() == 'CYBER30') {
    setState(() {
      _discountPercent = 0.30;
      _discountAmount = _subtotal * _discountPercent;
      _totalFinal = _subtotal - _discountAmount;
    });
    _showToast('Kupon Berhasil Dipasang: Diskon 30%!');
  }
}

// [4] Navigasi Checkout Pembayaran
void proceedToCheckout() {
  Navigator.push(context, MaterialPageRoute(
    builder: (c) => PembayaranPage(
      items: _cartItems,
      totalBayar: _totalFinal,
      discount: _discountAmount,
    ),
  ));
}`,
    COLOR_ACCENT
  );

  // =========================================================================
  // SLIDE 21: DEEP-DIVE FITUR 5: PROFIL (Profil.png)
  // =========================================================================
  const s21 = pres.addSlide();
  addScreenshotCodeSlide(
    s21,
    "Deep-Dive Fitur Utama (5/6)",
    "Fitur 5: Modul Profil Pengguna & Keamanan 2FA",
    "Manajemen identitas akun pengguna, preferensi bahasa bilingual (ID/EN), aktivasi keamanan biometrik, dan sesi.",
    "Profil.png",
    "🖼️ Elemen Visual UI pada Profil.png",
    [
      { text: "• [1] Identitas Profil & Avatar Neon:\n", options: { bold: true, color: COLOR_CYAN } },
      { text: "Foto avatar bercahaya, username unik (@admin), email resmi, dan role badge.\n\n", options: { color: COLOR_MUTED } },
      { text: "• [2] Pengaturan Bahasa Bilingual (ID / EN):\n", options: { bold: true, color: COLOR_ACCENT } },
      { text: "Toggle switch bahasa aplikasi Bahasa Indonesia dan English secara instan.\n\n", options: { color: COLOR_MUTED } },
      { text: "• [3] Switch Keamanan 2FA & Biometrik:\n", options: { bold: true, color: COLOR_EMERALD } },
      { text: "Mengaktifkan/menonaktifkan proteksi sensor sidik jari hardware dan PIN transaksi.\n\n", options: { color: COLOR_MUTED } },
      { text: "• [4] Tombol 'Keluar Sesi' (Logout):\n", options: { bold: true, color: COLOR_WHITE } },
      { text: "Menghapus session token SharedPreferences dan kembali ke halaman Login.", options: { color: COLOR_MUTED } },
    ],
    "💻 Penjelasan Codingan Flutter Dart (Profil)",
    `// [2] Toggle Bahasa Bilingual via LanguageService
void toggleLanguage(String langCode) async {
  await LanguageService.setLanguage(langCode);
  setState(() => _currentLanguage = langCode);
  _showToast('Bahasa diubah ke: \${langCode.toUpperCase()}');
}

// [3] Switch Biometrik & 2FA State
void toggleBiometric2FA(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('biometric_2fa_enabled', enabled);
  setState(() => _is2faActive = enabled);
}

// [4] Logout Sesi Aman
void logoutUser() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
}`,
    COLOR_EMERALD
  );

  // =========================================================================
  // SLIDE 22: DEEP-DIVE FITUR 6: DATA KREDENSIAL (Kartu_layanan.png)
  // =========================================================================
  const s22 = pres.addSlide();
  addScreenshotCodeSlide(
    s22,
    "Deep-Dive Fitur Utama (6/6)",
    "Fitur 6: Modul Data Kredensial & Server Manager",
    "Manajemen data kredensial instance aktif Cloud VPS & Panel Pterodactyl: IP address publik, port SSH, root password, dan perpanjangan masa aktif.",
    "Kartu_layanan.png",
    "🖼️ Elemen Visual UI pada Kartu_layanan.png",
    [
      { text: "• [1] Kartu Layanan Server Aktif:\n", options: { bold: true, color: COLOR_CYAN } },
      { text: "Menampilkan nama produk 'Cloud VPS KVM - SG Node' dan status aktif server.\n\n", options: { color: COLOR_MUTED } },
      { text: "• [2] Kredensial IP Address & Port:\n", options: { bold: true, color: COLOR_WHITE } },
      { text: "Alamat IP publik (103.187.x.x) dan port SSH (22 / 2022) siap dihubungkan terminal.\n\n", options: { color: COLOR_MUTED } },
      { text: "• [3] Root Password & Toggle Sensor Mata:\n", options: { bold: true, color: COLOR_ACCENT } },
      { text: "Kata sandi root terenkripsi dengan icon toggle untuk visibilitas dan salin 1-klik.\n\n", options: { color: COLOR_MUTED } },
      { text: "• [4] Hitung Mundur Masa Aktif & Renew:\n", options: { bold: true, color: COLOR_EMERALD } },
      { text: "Indikator sisa hari sebelum tanggal kadaluarsa dan tombol perpanjang sewa.", options: { color: COLOR_MUTED } },
    ],
    "💻 Penjelasan Codingan Flutter Dart (Data Kredensial)",
    `// [2 & 3] Salin Akses SSH ke Clipboard
void copySshCommand(String ip, String port, String user) {
  final cmd = 'ssh \$user@\$ip -p \$port';
  Clipboard.setData(ClipboardData(text: cmd));
  _showToast('Perintah SSH Disalin: \$cmd');
}

// [4] Query Layanan Aktif SQLite
Future<List<ServiceModel>> getActiveServices(String email) async {
  final db = await DatabaseHelper.instance.database;
  final res = await db.query('purchased_services',
      where: 'user_email = ?', whereArgs: [email]);
  return res.map((m) => ServiceModel.fromMap(m)).toList();
}`,
    COLOR_AMBER
  );

  // =========================================================================
  // SLIDE 23: MODAL EDIT KREDENSIAL - FULL USER CRUD CODINGAN
  // =========================================================================
  const s23 = pres.addSlide();
  setupSlideBg(s23);
  addSlideHeader(s23, "Manajemen Kredensial Lanjutan", "Tampilan Form Modal Kredensial & Codingan Sinkronisasi Sesi", "Formulir pengubahan password, PIN transaksi, role, dan sinkronisasi otomatis ke SharedPreferences.");

  s23.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 0.8, y: 1.8, w: 5.7, h: 5.0,
    fill: { color: COLOR_CARD },
    line: { color: COLOR_EMERALD, width: 1.5 },
    rectRadius: 0.2,
  });
  s23.addText("🖼️ Tampilan Visual Modal Edit Kredensial", {
    x: 1.1, y: 2.0, w: 5.1, h: 0.35,
    fontSize: 12.5, bold: true, color: COLOR_EMERALD,
  });
  s23.addShape(pres.shapes.RECTANGLE, {
    x: 1.1, y: 2.45, w: 5.1, h: 4.15,
    fill: { color: COLOR_CODE_BG },
  });
  s23.addText(
    `┌────────────────────────────────────────────────────────┐
│  [ Ubah Kredensial Pengguna ]                     [X]  │
├────────────────────────────────────────────────────────┤
│  [1] Username:       [ @admin                        ] │
│  [2] Password Baru:  [ ••••••••••                 👁 ] │
│  [3] PIN Transaksi:  [ 123456 (6-Digit)           👁 ] │
│  [4] Nama Lengkap:   [ Razik Administrator           ] │
│  [5] Email & No HP:  [ admin@vibetech.xyz | 08123..  ] │
│  [6] Role Akun:      [ Dropdown: ADMINISTRATOR / USER] │
│  [7] Saldo Wallet:   [ Rp 2.500.000                  ] │
├────────────────────────────────────────────────────────┤
│           [ 💾 8: SIMPAN PERUBAHAN KE SQLITE ]          │
└────────────────────────────────────────────────────────┘`,
    {
      x: 1.2, y: 2.55, w: 4.9, h: 3.95,
      fontSize: 8.8, fontFace: "Courier New", color: COLOR_WHITE,
    }
  );

  s23.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 6.8, y: 1.8, w: 5.7, h: 5.0,
    fill: { color: COLOR_CARD },
    line: { color: COLOR_ACCENT, width: 1.5 },
    rectRadius: 0.2,
  });
  s23.addText("💻 Penjelasan Codingan Dart & Sync Sesi", {
    x: 7.1, y: 2.0, w: 5.1, h: 0.35,
    fontSize: 12.5, bold: true, color: COLOR_ACCENT,
  });
  s23.addShape(pres.shapes.RECTANGLE, {
    x: 7.1, y: 2.45, w: 5.1, h: 4.15,
    fill: { color: COLOR_CODE_BG },
  });
  s23.addText(
    `// [8] Eksekusi Update SQLite & Sync Session
Future<void> _handleSaveUser() async {
  final updatedUser = {
    'username': _userController.text.trim(),
    'role': _selectedRole,
    'saldo': double.tryParse(_saldoController.text) ?? 0.0,
  };
  if (_passController.text.isNotEmpty) {
    updatedUser['password'] = _passController.text.trim();
  }
  if (_pinController.text.isNotEmpty) {
    updatedUser['pin'] = _pinController.text.trim();
  }

  // Update Database SQLite On-Device
  await DatabaseHelper.instance.updateUser(
    widget.userData['id'],
    updatedUser,
  );

  // Auto-Sync SharedPreferences Session Jika Akun Aktif
  if (_currentEmail == widget.userData['email']) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', updatedUser['username']);
    await prefs.setString('role', updatedUser['role']);
  }
  _showNeonToast('Kredensial berhasil diperbarui!');
}`,
    {
      x: 7.2, y: 2.55, w: 4.9, h: 3.95,
      fontSize: 8.2, fontFace: "Courier New", color: COLOR_WHITE,
    }
  );

  // =========================================================================
  // SLIDE 24: USER TESTING & FEEDBACK PENGGUNA (REQUIREMENT #4)
  // =========================================================================
  const s24 = pres.addSlide();
  setupSlideBg(s24);
  addSlideHeader(s24, "Validasi & Evaluasi Pengguna", "User Testing, Metrik Kepuasan & Feedback Pengguna", "Hasil pengujian fungsionalitas dan usability testing (UAT) bersama 25 responden pengembang & komunitas gamer.");

  const testMetrics = [
    { title: "Task Success Rate", value: "98.6%", desc: "25/25 responden berhasil menyelesaikan checkout < 15 detik.", color: COLOR_CYAN },
    { title: "System Usability Scale", value: "92.4 / 100", desc: "Grade A+ (Kategori Exceptional Usability & Navigation).", color: COLOR_EMERALD },
    { title: "Rata-rata Waktu Checkout", value: "1.2 Detik", desc: "Pelunasan instan saldo VibeWallet dengan auto-provisioning.", color: COLOR_ACCENT },
    { title: "Biometric 2FA Reliability", value: "100%", desc: "Otorisasi sidik jari hardware tanpa kegagalan autentikasi.", color: COLOR_AMBER },
  ];

  testMetrics.forEach((m, idx) => {
    const xPos = 0.8 + idx * 2.95;
    s24.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos, y: 1.8, w: 2.75, h: 1.7,
      fill: { color: COLOR_CARD },
      line: { color: m.color, width: 1.2 },
      rectRadius: 0.15,
    });
    s24.addText(m.value, {
      x: xPos + 0.1, y: 1.95, w: 2.55, h: 0.5,
      fontSize: 18, bold: true, color: m.color, align: "center",
    });
    s24.addText(m.title, {
      x: xPos + 0.1, y: 2.45, w: 2.55, h: 0.35,
      fontSize: 10, bold: true, color: COLOR_WHITE, align: "center",
    });
    s24.addText(m.desc, {
      x: xPos + 0.1, y: 2.8, w: 2.55, h: 0.6,
      fontSize: 7.8, color: COLOR_MUTED, align: "center",
    });
  });

  const feedbackQuotes = [
    {
      role: "Devops Engineer",
      quote: "“Penerbitan IP address dan tombol 1-klik salin perintah SSH langsung di ponsel sangat menghemat waktu saat deploy bot WhatsApp.”",
      color: COLOR_CYAN,
    },
    {
      role: "Server Administrator",
      quote: "“Fitur toggle sensor mata untuk password root memberikan privasi tinggi saat membuka kredensial server di tempat umum.”",
      color: COLOR_EMERALD,
    },
    {
      role: "Gamer / Bot Host",
      quote: "“Tampilan cyberpunk neon sangat memukau, dan diskon kupon promo 30% langsung otomatis memotong subtotal di keranjang.”",
      color: COLOR_ACCENT,
    },
  ];

  feedbackQuotes.forEach((q, idx) => {
    const xPos = 0.8 + idx * 3.95;
    s24.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos, y: 3.7, w: 3.75, h: 3.1,
      fill: { color: COLOR_CARD },
      line: { color: q.color, width: 1.2 },
      rectRadius: 0.15,
    });
    s24.addText(`💬 Umpan Balik: ${q.role}`, {
      x: xPos + 0.2, y: 3.85, w: 3.35, h: 0.35,
      fontSize: 10.5, bold: true, color: q.color,
    });
    s24.addText(q.quote, {
      x: xPos + 0.2, y: 4.25, w: 3.35, h: 1.6,
      fontSize: 9.0, color: COLOR_WHITE, italic: true,
    });
    s24.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos + 0.2, y: 5.95, w: 3.35, h: 0.6,
      fill: { color: "1A103C" },
      line: { color: q.color, width: 0.8 },
      rectRadius: 0.08,
    });
    s24.addText("Tindak Lanjut: Diadopsi 100% pada Versi 2.0.0", {
      x: xPos + 0.2, y: 6.05, w: 3.35, h: 0.4,
      fontSize: 8.2, bold: true, color: COLOR_EMERALD, align: "center",
    });
  });

  // =========================================================================
  // SLIDE 25: BACKEND REST API MICROSERVICES
  // =========================================================================
  const s25 = pres.addSlide();
  setupSlideBg(s25);
  addSlideHeader(s25, "Integrasi Backend", "Backend REST API Microservices & Integrasi Midtrans", "Node.js Express ESM Server yang menangani pembuatan token pembayaran dan webhook sinkronisasi pesanan.");

  const apiEndpoints = [
    {
      method: "POST",
      path: "/api/midtrans/charge",
      desc: "Menghasilkan Midtrans Snap Token untuk transaksi checkout QRIS / Virtual Account.",
      color: COLOR_CYAN,
    },
    {
      method: "POST",
      path: "/api/midtrans/notification",
      desc: "Webhook listener yang menerima status 'settlement' dan mengaktifkan layanan SQLite.",
      color: COLOR_EMERALD,
    },
    {
      method: "GET",
      path: "/api/server/status",
      desc: "Memeriksa ketersediaan node server Singapore dan latency cluster Pterodactyl.",
      color: COLOR_AMBER,
    },
    {
      method: "POST",
      path: "/api/voucher/validate",
      desc: "Memvalidasi kode promo diskon server 'CYBER30' dan menghitung nilai potongan.",
      color: COLOR_ACCENT,
    },
  ];

  apiEndpoints.forEach((api, idx) => {
    const col = idx % 2;
    const row = Math.floor(idx / 2);
    const xPos = 0.8 + col * 5.9;
    const yPos = 1.8 + row * 2.55;

    s25.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos, y: yPos, w: 5.7, h: 2.35,
      fill: { color: COLOR_CARD },
      line: { color: api.color, width: 1.2 },
      rectRadius: 0.15,
    });
    s25.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos + 0.2, y: yPos + 0.2, w: 1.1, h: 0.45,
      fill: { color: "1A103C" },
      line: { color: api.color, width: 1 },
      rectRadius: 0.08,
    });
    s25.addText(api.method, {
      x: xPos + 0.2, y: yPos + 0.2, w: 1.1, h: 0.45,
      fontSize: 10.5, fontFace: "Courier New", bold: true, color: api.color, align: "center",
    });
    s25.addText(api.path, {
      x: xPos + 1.45, y: yPos + 0.2, w: 4.0, h: 0.45,
      fontSize: 10.5, fontFace: "Courier New", bold: true, color: COLOR_WHITE,
    });
    s25.addText(api.desc, {
      x: xPos + 0.2, y: yPos + 0.8, w: 5.3, h: 1.35,
      fontSize: 9.5, color: COLOR_MUTED,
    });
  });

  // =========================================================================
  // SLIDE 26: ROADMAP PENGEMBANGAN STRATEGIS 2026
  // =========================================================================
  const s26 = pres.addSlide();
  setupSlideBg(s26);
  addSlideHeader(s26, "Roadmap Masa Depan", "Roadmap Pengembangan Strategis 2026", "Rencana evolusi teknologi VibeTech XYZ dalam memperluas ekosistem cloud dan otomatisasi.");

  const roadmap = [
    {
      quarter: "Q1 2026: Core Polish & SQLite",
      status: "COMPLETED",
      items: ["Penyempurnaan 6 Modul Fitur Utama", "Penyimpanan Offline SQLite On-Device", "Integrasi Biometrik LocalAuth & PIN", "VibeWallet Auto-Deduct 1-Detik"],
      color: COLOR_EMERALD,
    },
    {
      quarter: "Q2 2026: Multi-Region Nodes",
      status: "IN PROGRESS",
      items: ["Ekspansi Cluster Datacenter Jakarta & Tokyo", "WebSSH Terminal Konsol Langsung di App", "Multi-Currency Support (USD, SGD, IDR)", "Push Notification Masa Aktif Server"],
      color: COLOR_CYAN,
    },
    {
      quarter: "Q3 2026: AI Ops & Cloud Mesh",
      status: "PLANNED",
      items: ["Furina AI Autonomous Incident Healer", "Auto-Scaling Dynamic Server Resources", "Marketplace Template Docker 1-Klik", "Enterprise SLA & Multi-User Organization"],
      color: COLOR_ACCENT,
    },
  ];

  roadmap.forEach((r, idx) => {
    const xPos = 0.8 + idx * 3.95;
    s26.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos, y: 1.8, w: 3.75, h: 5.0,
      fill: { color: COLOR_CARD },
      line: { color: r.color, width: 1.2 },
      rectRadius: 0.15,
    });
    s26.addText(r.quarter, {
      x: xPos + 0.2, y: 2.0, w: 3.35, h: 0.4,
      fontSize: 11, bold: true, color: r.color,
    });
    s26.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: xPos + 0.2, y: 2.45, w: 1.6, h: 0.35,
      fill: { color: "1A103C" },
      line: { color: r.color, width: 1 },
      rectRadius: 0.08,
    });
    s26.addText(`● ${r.status}`, {
      x: xPos + 0.2, y: 2.45, w: 1.6, h: 0.35,
      fontSize: 8.5, bold: true, color: r.color, align: "center",
    });

    const itemsText = r.items.map((it, i) => `${i + 1}. ${it}\n\n`).join("");
    s26.addText(itemsText, {
      x: xPos + 0.2, y: 3.0, w: 3.35, h: 3.6,
      fontSize: 9.2, color: COLOR_WHITE,
    });
  });

  // =========================================================================
  // SLIDE 27: PENUTUP & Q&A
  // =========================================================================
  const s27 = pres.addSlide();
  setupSlideBg(s27);
  addSlideHeader(s27, "Penutup & Kontak Resmi", "Sesi Tanya Jawab (Q&A) & Penutup", "Terima kasih atas perhatian Anda. Kami mengundang pertanyaan dan diskusi seputar VibeTech XYZ.");

  if (fs.existsSync(logoPath)) {
    s27.addImage({
      path: logoPath,
      x: 11.35, y: 0.38, w: 1.15, h: 1.15,
    });
  }

  s27.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 0.8, y: 1.8, w: 5.7, h: 5.0,
    fill: { color: COLOR_CARD },
    line: { color: COLOR_CYAN, width: 1.5 },
    rectRadius: 0.2,
  });

  if (fs.existsSync(logoPath)) {
    s27.addImage({
      path: logoPath,
      x: 5.1, y: 1.95, w: 1.15, h: 1.15,
    });
  }

  s27.addText("👑 Tim Pengembang & Arsitek", {
    x: 1.1, y: 2.0, w: 3.8, h: 0.35,
    fontSize: 13, bold: true, color: COLOR_CYAN,
  });
  s27.addText(
    [
      { text: "Lead Developer & System Architect:\n", options: { bold: true, color: COLOR_WHITE, fontSize: 11 } },
      { text: "Raziek (Arsitek Sistem VibeTech XYZ)\n\n", options: { color: COLOR_CYAN, fontSize: 11.5, bold: true } },
      { text: "Aplikasi:\n", options: { bold: true, color: COLOR_WHITE, fontSize: 10.5 } },
      { text: "VibeTech XYZ - Next-Gen Cloud Infrastructure & 6 Core Modules\n\n", options: { color: COLOR_MUTED, fontSize: 10 } },
      { text: "Versi Rilis:\n", options: { bold: true, color: COLOR_WHITE, fontSize: 10.5 } },
      { text: "Versi 2.0.0 (Flutter 3.x, SQLite Full CRUD, Express ESM & Midtrans)", options: { color: COLOR_EMERALD, fontSize: 10 } },
    ],
    { x: 1.1, y: 2.45, w: 5.1, h: 4.1 }
  );

  s27.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 6.8, y: 1.8, w: 5.7, h: 5.0,
    fill: { color: COLOR_CARD },
    line: { color: COLOR_ACCENT, width: 1.5 },
    rectRadius: 0.2,
  });
  s27.addText("💬 Terima Kasih & Sesi Tanya Jawab", {
    x: 7.1, y: 2.0, w: 5.1, h: 0.35,
    fontSize: 13, bold: true, color: COLOR_ACCENT,
  });
  s27.addText(
    [
      { text: "Terima kasih atas waktu dan perhatian Bapak/Ibu sekalian.\n\n", options: { color: COLOR_WHITE, fontSize: 10.5 } },
      { text: "📱 WhatsApp Resmi: 0878-8587-3325\n", options: { bold: true, color: COLOR_EMERALD, fontSize: 11.5 } },
      { text: "🌐 Official Portal: https://vibetech.xyz\n", options: { color: COLOR_CYAN, fontSize: 10.5 } },
      { text: "📧 Email Support: support@vibetech.xyz\n\n", options: { color: COLOR_MUTED, fontSize: 10.5 } },
      { text: "Sesi tanya jawab kami buka. Silakan ajukan pertanyaan seputar 6 Fitur Utama (Dashboard, Produk, Pembayaran, Keranjang, Profil, Data Kredensial), Hasil User Testing, atau Arsitektur SQLite!", options: { bold: true, color: COLOR_WHITE, fontSize: 10 } },
    ],
    { x: 7.1, y: 2.45, w: 5.1, h: 4.1 }
  );

  // Simpan File PPTX ke folder presentation
  const outputPath = path.join(__dirname, "VibeTech_XYZ_Presentation_Deck.pptx");
  const buffer = await pres.write({ outputType: "nodebuffer" });

  // Injeksi Animasi Transisi Slide OpenXML Dinamis untuk seluruh slide
  const zip = await JSZip.loadAsync(buffer);
  const transitionPresets = [
    '<p:transition spd="med" advClick="1"><p:zoom/></p:transition>',
    '<p:transition spd="med" advClick="1"><p:push dir="l"/></p:transition>',
    '<p:transition spd="med" advClick="1"><p:wipe dir="r"/></p:transition>',
    '<p:transition spd="med" advClick="1"><p:fade/></p:transition>',
    '<p:transition spd="med" advClick="1"><p:split orient="horz"/></p:transition>',
  ];

  // Hitung jumlah slide dinamis dari file zip OpenXML
  let slideIndex = 1;
  while (zip.file(`ppt/slides/slide${slideIndex}.xml`)) {
    const slideXmlPath = `ppt/slides/slide${slideIndex}.xml`;
    const slideFile = zip.file(slideXmlPath);
    let xml = await slideFile.async("text");
    const transitionTag = transitionPresets[(slideIndex - 1) % transitionPresets.length];
    if (xml.includes("</p:sld>")) {
      xml = xml.replace("</p:sld>", `${transitionTag}</p:sld>`);
      zip.file(slideXmlPath, xml);
    }
    slideIndex++;
  }

  const finalBuffer = await zip.generateAsync({ type: "nodebuffer" });
  fs.writeFileSync(outputPath, finalBuffer);

  console.log(`✅ File PPTX Presentasi ${slideIndex - 1} Slide Master Lengkap Berhasil Dibuat: ${outputPath}`);
}

generatePresentation().catch(console.error);
