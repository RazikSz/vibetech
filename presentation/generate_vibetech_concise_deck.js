import pptxgen from "pptxgenjs";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function generateUltraConciseDeck() {
  const pres = new pptxgen();

  // Widescreen 16:9 Canva Standard (13.333 x 7.5 in = 1920x1080)
  pres.defineLayout({ name: "CANVA_WIDESCREEN_16_9", width: 13.333, height: 7.5 });
  pres.layout = "CANVA_WIDESCREEN_16_9";

  pres.author = "Raziek";
  pres.company = "VibeTech XYZ";
  pres.title = "VibeTech XYZ - Pendahuluan, Masalah Lapangan, Solusi, Kemudahan & Manfaat";

  // Color Palette
  const COLOR_BG = "060814";
  const COLOR_CARD = "0E1428";
  const COLOR_CARD_LIGHT = "151C36";
  const COLOR_PRIMARY = "7C4DFF";
  const COLOR_ACCENT = "E040FB";
  const COLOR_CYAN = "00E5FF";
  const COLOR_EMERALD = "10B981";
  const COLOR_AMBER = "F59E0B";
  const COLOR_RED = "EF4444";
  const COLOR_WHITE = "FFFFFF";
  const COLOR_MUTED = "94A3B8";
  const COLOR_CODE_BG = "080B18";

  const logoPath = path.join(__dirname, "..", "assets", "images", "logo.png");
  const ssDir = path.join(__dirname, "..", "assets", "ss_vibetech");

  function setupSlideBg(slide) {
    slide.background = { color: COLOR_BG };
  }

  function addHeader(slide, tag, title, subtitle) {
    slide.addText(tag.toUpperCase(), {
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
      fontSize: 21,
      fontFace: "Arial",
      bold: true,
      color: COLOR_WHITE,
    });

    if (subtitle) {
      slide.addText(subtitle, {
        x: 0.8,
        y: 1.22,
        w: 11.7,
        h: 0.35,
        fontSize: 10.5,
        fontFace: "Arial",
        color: COLOR_MUTED,
      });
    }
  }

  // =========================================================================
  // SLIDE 1: COVER (HERO PRESENTATION)
  // =========================================================================
  {
    const slide = pres.addSlide();
    setupSlideBg(slide);

    slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 1.0,
      y: 0.9,
      w: 11.333,
      h: 5.7,
      fill: { color: COLOR_CARD },
      line: { color: COLOR_PRIMARY, width: 2 },
      rectRadius: 0.25,
    });

    if (fs.existsSync(logoPath)) {
      slide.addImage({
        path: logoPath,
        x: 1.6,
        y: 1.7,
        w: 2.3,
        h: 2.3,
      });
    }

    slide.addText("⚡ VIBETECH XYZ", {
      x: 4.3,
      y: 1.6,
      w: 7.5,
      h: 0.75,
      fontSize: 34,
      fontFace: "Arial",
      bold: true,
      color: COLOR_WHITE,
    });

    slide.addText("Ekosistem Cloud VPS, WhatsApp Bot & Panel Hosting All-in-One", {
      x: 4.3,
      y: 2.35,
      w: 7.5,
      h: 0.45,
      fontSize: 14,
      fontFace: "Arial",
      bold: true,
      color: COLOR_CYAN,
    });

    slide.addText(
      "Solusi sewa infrastruktur server cepat, praktis, dan aman berbasis Flutter, SQLite, serta AI Assistant dalam satu genggaman.",
      {
        x: 4.3,
        y: 2.85,
        w: 7.5,
        h: 0.7,
        fontSize: 11.5,
        fontFace: "Arial",
        color: COLOR_MUTED,
      }
    );

    // 3 Highlight Chips
    const chips = [
      { text: "🎯 Solusi Terpadu", col: COLOR_PRIMARY },
      { text: "✨ Kemudahan 1-Klik", col: COLOR_CYAN },
      { text: "🚀 Hemat Waktu 90%", col: COLOR_EMERALD },
    ];
    chips.forEach((chip, i) => {
      slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: 4.3 + i * 2.5,
        y: 3.85,
        w: 2.35,
        h: 0.5,
        fill: { color: "181432" },
        line: { color: chip.col, width: 1.2 },
        rectRadius: 0.1,
      });
      slide.addText(chip.text, {
        x: 4.3 + i * 2.5,
        y: 3.85,
        w: 2.35,
        h: 0.5,
        fontSize: 10,
        fontFace: "Arial",
        bold: true,
        color: COLOR_WHITE,
        align: "center",
      });
    });

    slide.addText("Lead Developer: Raziek • Versi 2.0.0 (2026)", {
      x: 4.3,
      y: 5.4,
      w: 7.5,
      h: 0.35,
      fontSize: 10.5,
      fontFace: "Arial",
      color: COLOR_MUTED,
    });
  }

  // =========================================================================
  // SLIDE 2: PEMBUKAAN — CERITA MASALAH NYATA DI LAPANGAN & LATAR BELAKANG
  // =========================================================================
  {
    const slide = pres.addSlide();
    setupSlideBg(slide);
    addHeader(
      slide,
      "PEMBUKAAN: REALITA LAPANGAN & LATAR BELAKANG",
      "Cerita Nyata di Lapangan: Mengapa VibeTech XYZ Dibuat?",
      "Banyak yang butuh server bot & game, tapi terhalang karena tidak punya kartu kredit dan tidak paham Linux"
    );

    // Left Box: Masalah Nyata di Kehidupan Sehari-hari (The Real Problem Hook)
    slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 0.8,
      y: 1.75,
      w: 5.75,
      h: 4.95,
      fill: { color: COLOR_CARD },
      line: { color: COLOR_RED, width: 1.5 },
      rectRadius: 0.18,
    });

    slide.addText("⚠️ Realita Masalah di Lapangan (Pain Point)", {
      x: 1.1,
      y: 1.95,
      w: 5.2,
      h: 0.4,
      fontSize: 13,
      fontFace: "Arial",
      bold: true,
      color: COLOR_RED,
    });

    const realProblems = [
      "🎮 Butuh Server Tapi Terbentur Akses: Banyak mahasiswa, pemula, gamer, & pelaku UMKM ingin pasang bot WhatsApp otomatis untuk jualan atau server Minecraft bersama teman.",
      "💳 Gak Punya Kartu Kredit: Provider cloud luar negeri wajib bayar pakai Kartu Kredit (USD). Mahasiswa & UMKM mayoritas tidak punya CC dan tidak bisa bayar via QRIS / Dana / GoPay.",
      "💻 Ketergantungan Laptop & Terminal: Setiap kelola server harus buka PC desktop dan mengetik kode Linux SSH yang rumit. Kalau bot mati di jalan, tidak bisa diperbaiki dari HP.",
    ];

    slide.addText(realProblems.join("\n\n"), {
      x: 1.1,
      y: 2.5,
      w: 5.2,
      h: 3.95,
      fontSize: 10.2,
      fontFace: "Arial",
      color: COLOR_MUTED,
      lineSpacing: 14,
    });

    // Right Box: Makanya Kami Menciptakan VibeTech XYZ! (The Solution Hook)
    slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 6.8,
      y: 1.75,
      w: 5.733,
      h: 4.95,
      fill: { color: COLOR_CARD },
      line: { color: COLOR_EMERALD, width: 1.5 },
      rectRadius: 0.18,
    });

    slide.addText("🚀 Makanya Kami Buat VibeTech XYZ!", {
      x: 7.1,
      y: 1.95,
      w: 5.2,
      h: 0.4,
      fontSize: 13,
      fontFace: "Arial",
      bold: true,
      color: COLOR_EMERALD,
    });

    const solutionBorn = [
      "📱 Solusi 1-Genggaman (Mobile-First): Mengubah proses sewa server cloud yang rumit menjadi semudah belanja online di aplikasi smartphone.",
      "💳 Bebas Kartu Kredit: Mendukung pembayaran lokal QRIS instan, E-Wallet (GoPay/Dana/OVO), serta potong Saldo VibeWallet tanpa biaya konversi valas.",
      "⚡ Otomatis Tanpa Perlu Jago Linux: Server langsung terbit otomatis (IP, SSH Port, Root Password) dalam waktu <60 detik tanpa harus ketik terminal!",
      "🤖 Didukung Furina AI 24/7: Asisten cerdas yang siap menjawab pertanyaan dan troubleshooting server kapan saja.",
    ];

    slide.addText(solutionBorn.join("\n\n"), {
      x: 7.1,
      y: 2.5,
      w: 5.2,
      h: 3.95,
      fontSize: 10.2,
      fontFace: "Arial",
      color: COLOR_MUTED,
      lineSpacing: 14,
    });
  }

  // =========================================================================
  // SLIDE 3: DETAIL 3 MASALAH PENGGUNA (THE CORE PROBLEMS)
  // =========================================================================
  {
    const slide = pres.addSlide();
    setupSlideBg(slide);
    addHeader(
      slide,
      "TANTANGAN PENGGUNA",
      "3 Kendala Kritis Pengelolaan Server Konvensional",
      "Detail hambatan teknis dan finansial yang dialami pengguna sebelum hadirnya VibeTech XYZ"
    );

    const problems = [
      {
        icon: "⏳",
        tag: "KENDALA 1",
        title: "Setup Rumit & Manual",
        points: [
          "• Harus menguasai command Linux/SSH rumit dan rentan salah konfigurasi.",
          "• Waktu tunggu aktivasi server 1 s/d 24 jam karena verifikasi admin manual.",
          "• Tidak ada panduan ramah bagi pemula saat server mengalami kendala.",
        ],
        color: COLOR_RED,
      },
      {
        icon: "💳",
        tag: "KENDALA 2",
        title: "Pembayaran Ribet & Kaku",
        points: [
          "• Wajib Kartu Kredit internasional (USD) yang sulit dijangkau mahasiswa/UMKM.",
          "• Kurs valas tinggi dan beban biaya admin bank yang mahal.",
          "• Tidak mendukung pembayaran instan lokal (QRIS, E-Wallet, Virtual Account).",
        ],
        color: COLOR_AMBER,
      },
      {
        icon: "🤹",
        tag: "KENDALA 3",
        title: "Layanan Terpecah-pecah",
        points: [
          "• Sewa VPS, Bot WA, & Panel Game harus di vendor dan website terpisah.",
          "• Sulit memantau masa aktif tagihan dan riwayat sewa di banyak tempat.",
          "• Kredensial server (IP & password) rawan hilang karena dicatat manual.",
        ],
        color: COLOR_ACCENT,
      },
    ];

    problems.forEach((p, i) => {
      const posX = 0.8 + i * 3.95;
      const posY = 1.75;

      slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: posX,
        y: posY,
        w: 3.8,
        h: 4.95,
        fill: { color: COLOR_CARD },
        line: { color: p.color, width: 1.5 },
        rectRadius: 0.18,
      });

      // Top Icon Box
      slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: posX + 0.3,
        y: posY + 0.3,
        w: 0.7,
        h: 0.7,
        fill: { color: "1A122E" },
        line: { color: p.color, width: 1 },
        rectRadius: 0.1,
      });

      slide.addText(p.icon, {
        x: posX + 0.3,
        y: posY + 0.3,
        w: 0.7,
        h: 0.7,
        fontSize: 16,
        align: "center",
      });

      // Tag Pill
      slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: posX + 1.15,
        y: posY + 0.35,
        w: 1.6,
        h: 0.32,
        fill: "181236",
        line: { color: p.color, width: 0.8 },
        rectRadius: 0.08,
      });
      slide.addText(p.tag, {
        x: posX + 1.15,
        y: posY + 0.35,
        w: 1.6,
        h: 0.32,
        fontSize: 8.5,
        bold: true,
        color: p.color,
        align: "center",
      });

      slide.addText(p.title, {
        x: posX + 0.3,
        y: posY + 1.2,
        w: 3.2,
        h: 0.45,
        fontSize: 14,
        fontFace: "Arial",
        bold: true,
        color: COLOR_WHITE,
      });

      slide.addText(p.points.join("\n\n"), {
        x: posX + 0.3,
        y: posY + 1.8,
        w: 3.2,
        h: 2.7,
        fontSize: 10.5,
        fontFace: "Arial",
        color: COLOR_MUTED,
        lineSpacing: 15,
      });
    });
  }

  // =========================================================================
  // SLIDE 4: SOLUSI VIBETECH XYZ
  // =========================================================================
  {
    const slide = pres.addSlide();
    setupSlideBg(slide);
    addHeader(
      slide,
      "SOLUSI INOVATIF",
      "Solusi Terpadu: Otomasi Server dalam 1 Aplikasi",
      "Mentransformasi seluruh kendala konvensional menjadi ekosistem sewa server instan dan otomatis"
    );

    const solutions = [
      {
        icon: "🚀",
        tag: "SOLUSI 1",
        title: "All-in-One Platform",
        desc: "Sewa Cloud VPS KVM, Panel Pterodactyl Singapore, & Bot WhatsApp 24/7 dalam satu antarmuka terpadu tanpa berpindah-pindah website.",
        color: COLOR_PRIMARY,
      },
      {
        icon: "⚡",
        tag: "SOLUSI 2",
        title: "Instant Auto-Provisioning",
        desc: "IP Publik, Root Password, dan 8-Digit Pairing Code terbit otomatis dalam hitungan detik setelah checkout terselesaikan.",
        color: COLOR_CYAN,
      },
      {
        icon: "🤖",
        tag: "SOLUSI 3",
        title: "Furina AI Assistant & SQLite",
        desc: "Asisten cerdas 24/7 untuk rekomendasi server, cek voucher diskon, dan penyimpanan kredensial aman di database lokal offline-first.",
        color: COLOR_EMERALD,
      },
    ];

    solutions.forEach((s, i) => {
      const posX = 0.8 + i * 3.95;
      const posY = 1.75;

      slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: posX,
        y: posY,
        w: 3.8,
        h: 4.95,
        fill: { color: COLOR_CARD },
        line: { color: s.color, width: 1.5 },
        rectRadius: 0.18,
      });

      // Top Icon Box
      slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: posX + 0.3,
        y: posY + 0.3,
        w: 0.7,
        h: 0.7,
        fill: { color: "1A122E" },
        line: { color: s.color, width: 1 },
        rectRadius: 0.1,
      });

      slide.addText(s.icon, {
        x: posX + 0.3,
        y: posY + 0.3,
        w: 0.7,
        h: 0.7,
        fontSize: 16,
        align: "center",
      });

      // Tag Pill
      slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: posX + 1.15,
        y: posY + 0.35,
        w: 1.5,
        h: 0.32,
        fill: "181236",
        line: { color: s.color, width: 0.8 },
        rectRadius: 0.08,
      });
      slide.addText(s.tag, {
        x: posX + 1.15,
        y: posY + 0.35,
        w: 1.5,
        h: 0.32,
        fontSize: 8.5,
        bold: true,
        color: s.color,
        align: "center",
      });

      slide.addText(s.title, {
        x: posX + 0.3,
        y: posY + 1.25,
        w: 3.2,
        h: 0.45,
        fontSize: 14,
        fontFace: "Arial",
        bold: true,
        color: COLOR_WHITE,
      });

      slide.addText(s.desc, {
        x: posX + 0.3,
        y: posY + 1.85,
        w: 3.2,
        h: 2.6,
        fontSize: 11,
        fontFace: "Arial",
        color: COLOR_MUTED,
        lineSpacing: 16,
      });
    });
  }

  // =========================================================================
  // SLIDE 5: PREVIEW 3 GAMBAR TAMPILAN UI APLIKASI
  // =========================================================================
  {
    const slide = pres.addSlide();
    setupSlideBg(slide);
    addHeader(
      slide,
      "PREVIEW ANTARMUKA APLIKASI",
      "3 Tampilan Utama: Solusi, Kemudahan & Manfaat",
      "Tangkapan layar antarmuka asli Flutter pada 3 fitur kunci penyedia solusi dan efisiensi pengguna"
    );

    const uiScreens = [
      {
        file: "Dashboard.png",
        tag: "📱 TAMPILAN 1 • SOLUSI TERPADU",
        title: "Dashboard & Saldo Dompet",
        sub: "Pusat Kendali Ekosistem Server",
        color: COLOR_PRIMARY,
        points: [
          "• Kartu Saldo VibeWallet Rp 10 Juta",
          "• Quick Menu 4 Layanan Utama",
          "• Monitoring & Banner Portal Admin",
        ],
        benefit: "💡 Nilai Solusi: Akses seluruh server dalam 1 genggaman tanpa ribet login banyak web.",
      },
      {
        file: "Pembayaran.png",
        tag: "💳 TAMPILAN 2 • KEMUDAHAN BAYAR",
        title: "Checkout & QRIS Instan",
        sub: "Transaksi Cepat Multi-Channel",
        color: COLOR_CYAN,
        points: [
          "• Dual Payment: Saldo / Midtrans",
          "• Pembayaran QRIS & E-Wallet Lokal",
          "• Proteksi PIN Transaksi 2FA 6-Digit",
        ],
        benefit: "✨ Kemudahan: Bayar 1-klik tanpa kartu kredit internasional dan bebas biaya admin.",
      },
      {
        file: "Kartu_layanan.png",
        tag: "⚡ TAMPILAN 3 • MANFAAT OTOMASI",
        title: "Kelola Server & Kredensial",
        sub: "Auto-Provisioning & 1-Tap Copy",
        color: COLOR_EMERALD,
        points: [
          "• IP Publik & SSH Port Siap Pakai",
          "• Sensor Mata Root Password Aman",
          "• Salin 1-Tap Kredensial ke Clipboard",
        ],
        benefit: "🚀 Manfaat: Server siap pakai <60 detik, hemat waktu 90% tanpa setup manual.",
      },
    ];

    uiScreens.forEach((ui, i) => {
      const posX = 0.85 + i * 3.94;
      const posY = 1.72;
      const imgPath = path.join(ssDir, ui.file);

      // Main Outer Card
      slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: posX,
        y: posY,
        w: 3.75,
        h: 5.25,
        fill: { color: COLOR_CARD },
        line: { color: ui.color, width: 1.5 },
        rectRadius: 0.18,
      });

      // Top Tag Badge
      slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: posX + 0.15,
        y: posY + 0.12,
        w: 3.45,
        h: 0.34,
        fill: { color: "181236" },
        line: { color: ui.color, width: 0.8 },
        rectRadius: 0.08,
      });

      slide.addText(ui.tag, {
        x: posX + 0.15,
        y: posY + 0.12,
        w: 3.45,
        h: 0.34,
        fontSize: 8.5,
        fontFace: "Arial",
        bold: true,
        color: ui.color,
        align: "center",
      });

      // Left Phone Mockup Inside Card
      slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: posX + 0.15,
        y: posY + 0.54,
        w: 1.82,
        h: 4.52,
        fill: { color: "060814" },
        line: { color: ui.color, width: 1 },
        rectRadius: 0.12,
      });

      if (fs.existsSync(imgPath)) {
        slide.addImage({
          path: imgPath,
          x: posX + 0.18,
          y: posY + 0.57,
          w: 1.76,
          h: 4.46,
        });
      }

      // Right Detail Box Inside Card
      slide.addText(ui.title, {
        x: posX + 2.05,
        y: posY + 0.54,
        w: 1.58,
        h: 0.45,
        fontSize: 10.2,
        fontFace: "Arial",
        bold: true,
        color: COLOR_WHITE,
      });

      slide.addText(ui.sub, {
        x: posX + 2.05,
        y: posY + 0.95,
        w: 1.58,
        h: 0.28,
        fontSize: 7.8,
        fontFace: "Arial",
        bold: true,
        color: ui.color,
      });

      // Bullet Points
      slide.addText(ui.points.join("\n\n"), {
        x: posX + 2.05,
        y: posY + 1.28,
        w: 1.58,
        h: 2.1,
        fontSize: 8.0,
        fontFace: "Arial",
        color: COLOR_MUTED,
        lineSpacing: 12,
      });

      // Highlight Box
      slide.addShape(pres.shapes.RECTANGLE, {
        x: posX + 2.05,
        y: posY + 3.5,
        w: 1.58,
        h: 1.55,
        fill: { color: COLOR_CODE_BG },
        line: { color: "1E293B", width: 0.8 },
      });

      slide.addText(ui.benefit, {
        x: posX + 2.1,
        y: posY + 3.55,
        w: 1.48,
        h: 1.45,
        fontSize: 7.6,
        fontFace: "Arial",
        color: "E2E8F0",
        lineSpacing: 11,
      });
    });
  }

  // =========================================================================
  // SLIDE 6: KEMUDAHAN & MANFAAT (EASE & BENEFITS)
  // =========================================================================
  {
    const slide = pres.addSlide();
    setupSlideBg(slide);
    addHeader(
      slide,
      "FITUR & VALUE PROPOSITION",
      "Kemudahan Pengguna & Manfaat Nyata Aplikasi",
      "Kombinasi kemudahan operasional dan efisiensi biaya maksimal bagi pengguna"
    );

    // Left Box: Kemudahan Pengguna (Ease of Use)
    slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 0.8,
      y: 1.75,
      w: 5.75,
      h: 4.95,
      fill: { color: COLOR_CARD },
      line: { color: COLOR_CYAN, width: 1.5 },
      rectRadius: 0.18,
    });

    slide.addText("✨ Kemudahan Pengguna (Ease of Use)", {
      x: 1.1,
      y: 1.95,
      w: 5.2,
      h: 0.4,
      fontSize: 13.5,
      fontFace: "Arial",
      bold: true,
      color: COLOR_CYAN,
    });

    const easeList = [
      "🔐 Login 1-Klik: Google Sign-In & Biometrik (Fingerprint/Face ID).",
      "💳 Bayar Otomatis: QRIS Instan, GoPay, DANA, OVO, & Bank VA.",
      "📲 Self-Service 1-Tap: Salin IP, root password, & pairing code instan.",
      "🎟️ Diskon Instan: Voucher promo otomatis & saldo dompet internal.",
    ];

    slide.addText(easeList.join("\n\n"), {
      x: 1.1,
      y: 2.55,
      w: 5.2,
      h: 3.9,
      fontSize: 10.8,
      fontFace: "Arial",
      color: COLOR_MUTED,
      lineSpacing: 15,
    });

    // Right Box: Manfaat Aplikasi (Key Benefits)
    slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 6.8,
      y: 1.75,
      w: 5.733,
      h: 4.95,
      fill: { color: COLOR_CARD },
      line: { color: COLOR_EMERALD, width: 1.5 },
      rectRadius: 0.18,
    });

    slide.addText("💡 Manfaat Nyata (Key Benefits)", {
      x: 7.1,
      y: 1.95,
      w: 5.2,
      h: 0.4,
      fontSize: 13.5,
      fontFace: "Arial",
      bold: true,
      color: COLOR_EMERALD,
    });

    const benefitsList = [
      "⏱️ Hemat Waktu 90%: Server langsung aktif dalam <60 detik.",
      "💰 Hemat Biaya: Harga terjangkau + promo diskon berkala.",
      "🛡️ Aman Terjamin: PIN Transaksi 6 Digit & audit login history.",
      "🌐 Multi-Platform: Sinkronisasi cloud di Android, Windows & Web.",
    ];

    slide.addText(benefitsList.join("\n\n"), {
      x: 7.1,
      y: 2.55,
      w: 5.2,
      h: 3.9,
      fontSize: 10.8,
      fontFace: "Arial",
      color: COLOR_MUTED,
      lineSpacing: 15,
    });
  }

  // =========================================================================
  // SLIDE 7: PENUTUP & CALL TO ACTION (CTA)
  // =========================================================================
  {
    const slide = pres.addSlide();
    setupSlideBg(slide);
    addHeader(
      slide,
      "RINGKASAN & MULAI SEKARANG",
      "Mulai Bersama VibeTech XYZ Hari Ini",
      "Sewa dan kelola server impian Anda secara instan tanpa ribet"
    );

    // Left Column: Key Highlights
    slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 0.8,
      y: 1.75,
      w: 5.75,
      h: 4.95,
      fill: { color: COLOR_CARD },
      line: { color: COLOR_PRIMARY, width: 1.5 },
      rectRadius: 0.18,
    });

    slide.addText("🏆 Mengapa Memilih VibeTech XYZ?", {
      x: 1.1,
      y: 2.0,
      w: 5.2,
      h: 0.4,
      fontSize: 14,
      fontFace: "Arial",
      bold: true,
      color: COLOR_WHITE,
    });

    const summaryPoints = [
      "⚡ Cepat: Kredensial aktif seketika setelah checkout.",
      "👌 Praktis: Kendalikan server langsung dari smartphone/PC.",
      "💳 Fleksibel: Dukung pembayaran lokal QRIS & E-Wallet.",
      "🤖 Cerdas: Didukung Furina AI 24/7.",
    ];

    slide.addText(summaryPoints.join("\n\n"), {
      x: 1.1,
      y: 2.6,
      w: 5.2,
      h: 3.8,
      fontSize: 11.5,
      fontFace: "Arial",
      color: COLOR_MUTED,
      lineSpacing: 16,
    });

    // Right Column: Promo & Contact CTA Box
    slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 6.8,
      y: 1.75,
      w: 5.733,
      h: 4.95,
      fill: { color: COLOR_CARD_LIGHT },
      line: { color: COLOR_ACCENT, width: 1.8 },
      rectRadius: 0.18,
    });

    // Promo Badge
    slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 7.2,
      y: 2.0,
      w: 5.0,
      h: 1.1,
      fill: { color: "26123D" },
      line: { color: COLOR_ACCENT, width: 1.2 },
      rectRadius: 0.1,
    });

    slide.addText("🎁 PROMO SPESIAL DISKON 30%", {
      x: 7.3,
      y: 2.15,
      w: 4.8,
      h: 0.3,
      fontSize: 10,
      fontFace: "Arial",
      bold: true,
      color: COLOR_ACCENT,
      align: "center",
    });

    slide.addText("Kode Voucher: VIBESERVER", {
      x: 7.3,
      y: 2.5,
      w: 4.8,
      h: 0.45,
      fontSize: 13,
      fontFace: "Arial",
      bold: true,
      color: COLOR_WHITE,
      align: "center",
    });

    // Contact List
    const ctaContacts = [
      "🌐 Website: vibetech.xyz",
      "💬 WhatsApp: +62 878-8587-3325",
      "✉️ Email: support@vibetech.xyz",
      "🔑 Akun Demo: demouser / password123",
    ];

    slide.addText(ctaContacts.join("\n\n"), {
      x: 7.2,
      y: 3.35,
      w: 5.0,
      h: 3.1,
      fontSize: 11,
      fontFace: "Arial",
      color: COLOR_WHITE,
      lineSpacing: 14,
    });
  }

  // Save the presentation
  const outputPath = path.join(__dirname, "VibeTech_XYZ_Kemudahan_Manfaat_Solusi.pptx");
  await pres.writeFile({ fileName: outputPath });
  console.log(`[PPTX] File presentasi berhasil diperbarui di: ${outputPath}`);
}

generateUltraConciseDeck().catch((err) => {
  console.error("[PPTX Error]", err);
  process.exit(1);
});
