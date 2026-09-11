import fs from 'fs';
import {
  Document,
  Packer,
  Paragraph,
  TextRun,
  HeadingLevel,
  Table,
  TableRow,
  TableCell,
  WidthType,
  BorderStyle,
  AlignmentType,
  ShadingType,
  ImageRun
} from 'docx';

async function generateDocx() {
  let logoImageRun = null;
  try {
    const logoBuffer = fs.readFileSync('d:/vibetech_xyz_sqflite/vibetech_xyz/assets/images/logo.png');
    logoImageRun = new ImageRun({
      data: logoBuffer,
      transformation: {
        width: 90,
        height: 90,
      },
      type: 'png',
    });
  } catch (e) {
    console.log('Logo file not found:', e.message);
  }

  // Primary colors
  const COLOR_PRIMARY = '4F46E5'; // Indigo
  const COLOR_SECONDARY = '7C3AED'; // Violet
  const COLOR_DARK = '0F172A'; // Slate 900
  const COLOR_TEXT = '1E293B'; // Slate 800
  const COLOR_MUTED = '64748B'; // Slate 500
  const COLOR_LIGHT_BG = 'F8FAFC'; // Slate 50
  const COLOR_HEADER_BG = 'EEF2FF'; // Indigo 50
  const COLOR_BORDER = 'CBD5E1'; // Slate 300
  const COLOR_SUCCESS = '059669'; // Emerald 600

  // Helper for Section Headings
  const createSectionHeader = (title) => {
    return new Paragraph({
      text: title,
      heading: HeadingLevel.HEADING_1,
      spacing: { before: 280, after: 120 },
      border: {
        bottom: { color: COLOR_PRIMARY, size: 12, style: BorderStyle.SINGLE, space: 4 }
      }
    });
  };

  const createSubHeader = (title) => {
    return new Paragraph({
      text: title,
      heading: HeadingLevel.HEADING_2,
      spacing: { before: 200, after: 80 },
    });
  };

  const createBullet = (label, text) => {
    return new Paragraph({
      children: [
        new TextRun({ text: '•  ', bold: true, color: COLOR_SECONDARY }),
        new TextRun({ text: label ? `${label}: ` : '', bold: true, color: COLOR_DARK }),
        new TextRun({ text: text, color: COLOR_TEXT }),
      ],
      spacing: { before: 40, after: 60 },
    });
  };

  const createNumberBullet = (num, label, text) => {
    return new Paragraph({
      children: [
        new TextRun({ text: `${num}. `, bold: true, color: COLOR_PRIMARY }),
        new TextRun({ text: label ? `${label}: ` : '', bold: true, color: COLOR_DARK }),
        new TextRun({ text: text, color: COLOR_TEXT }),
      ],
      spacing: { before: 40, after: 60 },
    });
  };

  const doc = new Document({
    creator: 'VibeTech XYZ Developer Team',
    title: 'Dokumen Listing Google Play Store & Deskripsi Lengkap VibeTech XYZ',
    description: 'Deskripsi Resmi Google Play Store (Batas Karakter Konsol & Panduan Fitur Lengkap) VibeTech XYZ',
    styles: {
      default: {
        document: {
          run: {
            font: 'Segoe UI',
            size: 21, // 10.5pt
            color: COLOR_TEXT,
          },
          paragraph: {
            spacing: {
              line: 270,
              after: 100,
            },
          },
        },
      },
    },
    sections: [
      {
        properties: {
          page: {
            margin: {
              top: 1440, // 1 inch
              bottom: 1440,
              left: 1440,
              right: 1440,
            },
          },
        },
        children: [
          // Logo & Header
          ...(logoImageRun
            ? [
                new Paragraph({
                  alignment: AlignmentType.CENTER,
                  children: [logoImageRun],
                  spacing: { after: 100 },
                }),
              ]
            : []),

          new Paragraph({
            text: 'GOOGLE PLAY STORE STORE LISTING & DOKUMEN DESKRIPSI',
            heading: HeadingLevel.TITLE,
            alignment: AlignmentType.CENTER,
            spacing: { after: 40 },
          }),
          new Paragraph({
            alignment: AlignmentType.CENTER,
            children: [
              new TextRun({
                text: 'VIBETECH XYZ — Cloud VPS, Panel Hosting, Bot WhatsApp & Furina AI',
                bold: true,
                size: 24, // 12pt
                color: COLOR_PRIMARY,
              }),
            ],
            spacing: { after: 200 },
          }),

          // Metadata Table
          new Table({
            width: { size: 9000, type: WidthType.DXA },
            columnWidths: [2800, 6200],
            rows: [
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 2800, type: WidthType.DXA },
                    shading: { fill: COLOR_HEADER_BG, type: ShadingType.CLEAR },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ children: [new TextRun({ text: 'Nama Paket Aplikasi (Package)', bold: true })] })],
                  }),
                  new TableCell({
                    width: { size: 6200, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: 'com.vibetech.xyz (vibetech_xyz)' })],
                  }),
                ],
              }),
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 2800, type: WidthType.DXA },
                    shading: { fill: COLOR_HEADER_BG, type: ShadingType.CLEAR },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ children: [new TextRun({ text: 'Judul Aplikasi (Maks 30 Karakter)', bold: true })] })],
                  }),
                  new TableCell({
                    width: { size: 6200, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: 'VibeTech XYZ: Cloud VPS & Host' })],
                  }),
                ],
              }),
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 2800, type: WidthType.DXA },
                    shading: { fill: COLOR_HEADER_BG, type: ShadingType.CLEAR },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ children: [new TextRun({ text: 'Deskripsi Singkat (Maks 80 Karakter)', bold: true })] })],
                  }),
                  new TableCell({
                    width: { size: 6200, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: 'Sewa Cloud VPS Murah, Panel Pterodactyl Game, Bot WhatsApp 24/7 & Furina AI.' })],
                  }),
                ],
              }),
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 2800, type: WidthType.DXA },
                    shading: { fill: COLOR_HEADER_BG, type: ShadingType.CLEAR },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ children: [new TextRun({ text: 'Kategori Aplikasi', bold: true })] })],
                  }),
                  new TableCell({
                    width: { size: 6200, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: 'Tools (Alat) / Produktivitas / Bisnis' })],
                  }),
                ],
              }),
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 2800, type: WidthType.DXA },
                    shading: { fill: COLOR_HEADER_BG, type: ShadingType.CLEAR },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ children: [new TextRun({ text: 'Target Audiens', bold: true })] })],
                  }),
                  new TableCell({
                    width: { size: 6200, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: 'Developer, Gamer, Pemilik Komunitas Game, Pengusaha Online, Pelajar IT (Usia 13+)' })],
                  }),
                ],
              }),
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 2800, type: WidthType.DXA },
                    shading: { fill: COLOR_HEADER_BG, type: ShadingType.CLEAR },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ children: [new TextRun({ text: 'Rating Konten', bold: true })] })],
                  }),
                  new TableCell({
                    width: { size: 6200, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: 'PEGI 3 / Everyone (Semua Umur)' })],
                  }),
                ],
              }),
            ],
          }),

          new Paragraph({ text: '', spacing: { after: 120 } }),

          // SECTION 1: PLAY STORE FULL DESCRIPTION (COPY-PASTE READY FOR GOOGLE PLAY CONSOLE)
          createSectionHeader('BAGIAN 1: DESKRIPSI LENGKAP GOOGLE PLAY STORE (READY COPY-PASTE)'),
          new Paragraph({
            children: [
              new TextRun({
                text: 'Catatan Pengembang: ',
                bold: true,
                color: COLOR_SUCCESS,
              }),
              new TextRun({
                text: 'Teks di bawah ini telah disesuaikan secara khusus dengan batas 4.000 karakter Google Play Console, dilengkapi format emoji dan struktur copywriting standar ASO (App Store Optimization) tingkat tinggi.',
                color: COLOR_SUCCESS,
              }),
            ],
            spacing: { before: 60, after: 160 },
          }),

          // Box Container for Play Store Direct Copy
          new Table({
            width: { size: 9000, type: WidthType.DXA },
            columnWidths: [9000],
            rows: [
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 9000, type: WidthType.DXA },
                    shading: { fill: COLOR_LIGHT_BG, type: ShadingType.CLEAR },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 8, color: COLOR_PRIMARY },
                      bottom: { style: BorderStyle.SINGLE, size: 8, color: COLOR_PRIMARY },
                      left: { style: BorderStyle.SINGLE, size: 8, color: COLOR_PRIMARY },
                      right: { style: BorderStyle.SINGLE, size: 8, color: COLOR_PRIMARY },
                    },
                    margins: { top: 140, bottom: 140, left: 180, right: 180 },
                    children: [
                      new Paragraph({
                        children: [
                          new TextRun({
                            text: '🚀 VibeTech XYZ — Solusi Infrastruktur Cloud Server, Panel Hosting & Otomasi Modern dalam Satu Genggaman!',
                            bold: true,
                            size: 22,
                            color: COLOR_PRIMARY,
                          }),
                        ],
                        spacing: { after: 100 },
                      }),
                      new Paragraph({
                        text: 'Kelola dan sewa server Cloud VPS berkecepatan tinggi, panel hosting game & web Pterodactyl, serta bot WhatsApp aktif 24 jam nonstop tanpa ribet. Dilengkapi kecerdasan buatan Furina AI dan sistem pembayaran instan Midtrans (QRIS, VA Bank & E-Wallet), VibeTech XYZ menghadirkan pengalaman deployment server paling mudah, cepat, dan terpercaya di Indonesia.',
                        spacing: { after: 120 },
                      }),

                      new Paragraph({
                        children: [new TextRun({ text: '🔥 LAYANAN UTAMA VIBETECH XYZ', bold: true, color: COLOR_DARK })],
                        spacing: { before: 80, after: 60 },
                      }),
                      new Paragraph({
                        text: '1. 💻 CLOUD VPS (VIRTUAL PRIVATE SERVER)\n• Pilihan OS Lengkap: Ubuntu 22.04 LTS, Debian 11/12, CentOS, AlmaLinux, & Windows Server.\n• Akses Full Root & SSH / RDP Port 22.\n• Penyimpanan Ultra-Cepat NVMe SSD & Port Jaringan 1 Gbps Unmetered.\n• Dilengkapi Proteksi Anti-DDoS & Garansi 99.9% Uptime SLA.\n• Provisioning otomatis: Alamat IP Public dan kredensial langsung terbit seketika.',
                        spacing: { after: 100 },
                      }),
                      new Paragraph({
                        text: '2. 🎮 PANEL HOSTING PTERODACTYL (GAME & WEB APPS)\n• Siap deploy server game favorit: Minecraft (Paper, Spigot, Forge, Fabric), SA:MP, FiveM, Rust, Terraria.\n• Hosting aplikasi web & bot backend: Node.js, Python, PHP, Golang, Java.\n• Antarmuka web Pterodactyl modern, Web Console interaktif, File Manager bawaan, & Auto Backup terjadwal.',
                        spacing: { after: 100 },
                      }),
                      new Paragraph({
                        text: '3. 🤖 SEWA BOT WHATSAPP AKTIF 24/7\n• Solusi bot WhatsApp online terus tanpa harus menyalakan HP atau laptop Anda.\n• Hubungkan mudah melalui 8-Digit Pairing Code / QR Web tanpa ribet.\n• Cocok untuk auto-responder toko online, bot broadcast komunitas, bot grup, hingga asisten cerdas.',
                        spacing: { after: 100 },
                      }),
                      new Paragraph({
                        text: '4. 🎭 FURINA AI — ASISTEN TEKNIS PINTAR 24/7\n• Didukung teknologi Google Gemini terkini.\n• Konsultasi spesifikasi server terbaik, troubleshooting script bot, konfigurasi Linux, hingga rekomendasi paket hemat.\n• Interaktif, solutif, dan ramah untuk developer pemula hingga profesional.',
                        spacing: { after: 100 },
                      }),

                      new Paragraph({
                        children: [new TextRun({ text: '💳 PEMBAYARAN FLEKSIBEL & OTOMATIS (MIDTRANS)', bold: true, color: COLOR_DARK })],
                        spacing: { before: 80, after: 60 },
                      }),
                      new Paragraph({
                        text: '• QRIS Instant: Scan langsung dari BCA Mobile, GoPay, OVO, DANA, ShopeePay, LinkAja, dsb.\n• Virtual Account Bank: BCA, Mandiri, BRI, BNI, Permata Bank (Verifikasi Real-Time Otomatis).\n• VibeWallet: Dompet digital internal untuk transaksi kilat 1-klik tanpa biaya admin tambahan.\n• Invoice Resmi: Bukti pembayaran digital dan rincian transaksi otomatis dikirim ke email Anda.',
                        spacing: { after: 100 },
                      }),

                      new Paragraph({
                        children: [new TextRun({ text: '🛡️ KEAMANAN & PRIVASI TINGKAT TINGGI', bold: true, color: COLOR_DARK })],
                        spacing: { before: 80, after: 60 },
                      }),
                      new Paragraph({
                        text: '• PIN Transaksi 6 Digit & Otentikasi Dua Faktor (2FA) untuk setiap pembayaran.\n• Login Biometrik Cepat (Sidik Jari / Face ID) diproses aman di enklaf lokal perangkat Anda.\n• Arsitektur data hibrida: Sinkronisasi Cloud Firestore dengan basis data lokal SQLite (vibetech.db).\n• Kepatuhan Penuh terhadap Undang-Undang Perlindungan Data Pribadi (UU PDP No. 27/2022).',
                        spacing: { after: 100 },
                      }),

                      new Paragraph({
                        children: [new TextRun({ text: '🌟 FITUR EKSKLUSIF LAINNYA', bold: true, color: COLOR_DARK })],
                        spacing: { before: 80, after: 60 },
                      }),
                      new Paragraph({
                        text: '• Status Server Real-Time: Pantau sisa masa aktif, IP, dan node server langsung dari menu Layanan Saya.\n• Promo Diskon Menarik: Nikmati potongan harga rutin untuk paket VPS dan Panel tertentu.\n• Mode Tampilan Gelap (Cyber Dark Mode) & Terang (Clean Light Mode) yang memanjakan mata.\n• Bantuan Pelanggan 24/7 melalui Live Chat & WhatsApp CS resmi.',
                        spacing: { after: 100 },
                      }),

                      new Paragraph({
                        children: [new TextRun({ text: '📞 HUBUNGI KAMI', bold: true, color: COLOR_DARK })],
                        spacing: { before: 80, after: 40 },
                      }),
                      new Paragraph({
                        text: '• Website: https://vibetech.xyz\n• Email Dukungan: support@vibetech.xyz\n• Layanan WhatsApp CS: +62 878-8587-3325\n• Alamat: Indonesia\n\nUnduh VibeTech XYZ sekarang dan nikmati kemudahan kelola infrastruktur server handal dalam satu genggaman!',
                        spacing: { after: 40 },
                      }),
                    ],
                  }),
                ],
              }),
            ],
          }),

          new Paragraph({ text: '', spacing: { after: 160 } }),

          // SECTION 2: EXTENSIVE IN-DEPTH WHITEPAPER & DOCUMENTATION
          createSectionHeader('BAGIAN 2: PROFIL LENGKAP & WHITEPAPER EKOSISTEM VIBETECH XYZ'),

          createSubHeader('1. LATAR BELAKANG & VISI PRODUK'),
          new Paragraph({
            text: 'Perkembangan ekosistem digital di Indonesia menuntut tersedianya infrastruktur server yang tidak hanya handal dan berperforma tinggi, tetapi juga mudah diakses secara mobile oleh siapa saja. Para pengembang perangkat lunak, komunitas gamer, pemilik server game multiplayer, maupun pengelola bisnis digital kerap menghadapi kendala rumitnya proses penyewaan VPS tradisional yang lambat, metode pembayaran luar negeri yang terbatas, serta kurangnya layanan otomasi bot WhatsApp.',
          }),
          new Paragraph({
            text: 'VibeTech XYZ (vibetech_xyz) hadir sebagai platform All-in-One Cloud Infrastructure Ecosystem berbasis mobile. Aplikasi ini dirancang khusus untuk memadukan kemudahan pemesanan instan, manajemen server real-time, dompet digital terpadu (VibeWallet), gerbang pembayaran resmi berizin Bank Indonesia (Midtrans), serta asisten cerdas bertenaga Artificial Intelligence (Furina AI) ke dalam satu antarmuka modern yang futuristik.',
          }),

          createSubHeader('2. RINCIAN SPESIFIKASI INFRASTRUKTUR & LAYANAN UNGGULAN'),
          new Paragraph({
            text: 'Aplikasi VibeTech XYZ menyediakan 3 pilar layanan utama yang didukung oleh node server berlokasi di Jakarta (Indonesia) dan Singapura untuk menjamin latensi ultra-rendah:',
          }),

          createBullet('A. Cloud VPS (Virtual Private Server)', 'Solusi mesin virtual mandiri dengan virtualisasi KVM tingkat enterprise. Pengguna memperoleh isolasi resource 100% tanpa adanya noisy neighbor. Dilengkapi dengan bandwidth 1 Gbps unmetered, storage PCIe NVMe berkecepatan baca/tulis di atas 3000 MB/s, serta alamat IP Public IPv4 khusus. Pengguna bebas menginstall distro Linux (Ubuntu 20.04/22.04 LTS, Debian 10/11/12, CentOS 7/8, AlmaLinux 8/9, Rocky Linux) maupun Windows Server. Akses root penuh diberikan langsung melalui terminal SSH port 22 atau Remote Desktop Protocol (RDP).'),

          createBullet('B. Panel Hosting Game & Web (Pterodactyl Engine)', 'Layanan hosting berbasis kontainer Docker terisolasi yang diatur melalui kontrol panel Pterodactyl open-source terpopuler di dunia. Pengguna dapat meng-host server game seperti Minecraft Java & Bedrock Edition, SA:MP (San Andreas Multiplayer), FiveM GTA V, Counter-Strike, Rust, dan Terraria dengan kemudahan instalasi plugin/mod, SFTP file access, jadwal restart otomatis, dan pembuatan database MySQL gratis. Selain server game, panel ini mendukung runtime Node.js, Python Flask/Django, Golang, dan PHP untuk hosting REST API atau bot Discord.'),

          createBullet('C. Sewa Bot WhatsApp Cloud 24/7', 'Layanan otomasi WhatsApp multi-device bertenaga Baileys. Pengguna tidak perlu menyediakan server sendiri atau membiarkan komputer rumah menyala terus menerus. Cukup dengan menautkan nomor WhatsApp melalui 8-Digit Pairing Code atau Scan QR, bot akan langsung aktif di cloud dengan garansi uptime 99.9%. Sangat ideal untuk layanan customer service otomatis, notifikasi transaksi toko online, broadcast pengumuman, auto-download media, dan manajemen grup interaktif.'),

          createBullet('D. Furina AI — Theatrical Technical Assistant', 'Asisten kecerdasan buatan berbasis Google Gemini AI dengan persona Diva Teater yang cerdas, anggun, dan menghibur. Furina AI mampu menganalisis kebutuhan kapasitas RAM/CPU pengguna, memberikan script konfigurasi Nginx/Apache, membantu debugging syntax JavaScript/Python, serta memandu proses aktivasi bot WhatsApp secara interaktif tanpa jeda.'),

          createSubHeader('3. ARSITEKTUR TEKNOLOGI & BASIS DATA HIBRIDA'),
          new Paragraph({
            text: 'VibeTech XYZ dibangun dengan arsitektur modern berstandar industri tinggi untuk menjamin performa super cepat dan ketahanan data tanpa kompromi:',
          }),

          createNumberBullet('1', 'Flutter Modern Framework', 'Antarmuka aplikasi dibangun menggunakan Google Flutter versi terbaru dengan render engine Impeller/Skia, menghasilkan transisi 60–120 FPS yang sangat mulus, responsif di berbagai resolusi layar, dan hemat konsumsi baterai.'),
          createNumberBullet('2', 'SQLite Local Engine (vibetech.db)', 'Seluruh data katalog produk, keranjang belanja, pengaturan akun, riwayat transaksi, dan sesi tersimpan di SQLite lokal. Pengguna dapat membuka katalog dan data layanan secara instan dengan response time 0 milidetik bahkan saat kondisi sinyal internet kurang stabil.'),
          createNumberBullet('3', 'Google Cloud Firestore & Realtime DB', 'Sinkronisasi cloud otomatis secara background menjamin data saldo VibeWallet, invoice pesanan, dan status server pengguna selalu terbarui secara real-time antar perangkat.'),
          createNumberBullet('4', 'Express.js Backend & Midtrans Gateway Engine', 'Pemrosesan pesanan dan transaksi ditangani oleh backend microservice Express.js yang terhubung langsung ke Midtrans API dengan standar keamanan PCI-DSS Tier 1.'),

          createSubHeader('4. SISTEM KEUANGAN, VIBEWALLET & ALUR PEMBAYARAN'),
          new Paragraph({
            text: 'Kemudahan transaksi menjadi prioritas utama VibeTech XYZ. Sistem pembayaran kami dirancang sepenuhnya otomatis (auto-approval):',
          }),

          createBullet('Metode QRIS Nasional (Quick Response Code Indonesian Standard)', 'Mendukung pembayaran langsung dari seluruh aplikasi perbankan (BCA, Mandiri Livin, BRImo, BNI Mobile, CIMB Octo, PermataMobile) dan seluruh e-wallet terdaftar (GoPay, DANA, OVO, ShopeePay, LinkAja, AstraPay). Cukup scan QR code dan saldo/layanan aktif seketika.'),
          createBullet('Virtual Account (VA) Bank Otomatis', 'Nomor rekening virtual unik diterbitkan khusus untuk setiap transaksi melalui Bank BCA, Mandiri, BRI, BNI, dan Permata dengan verifikasi pelunasan 1–5 detik tanpa perlu unggah bukti transfer manual.'),
          createBullet('VibeWallet Saldo Internal', 'Pengguna dapat melakukan top-up saldo kapan saja dan menikmati proses checkout pesanan 1-klik dengan validasi PIN keamanan 6-digit.'),
          createBullet('Penerbitan Invoice & Pengiriman Email Otomatis', 'Setiap pesanan yang berhasil akan langsung menerbitkan Invoice Digital dengan nomor unik resmi, rincian item, PPN, dan dikirimkan tembusannya ke alamat email pengguna melalui integrasi SMTP.'),

          createSubHeader('5. SISTEM KEAMANAN & KEPATUHAN PRIVASI (UU PDP NO. 27/2022)'),
          new Paragraph({
            text: 'VibeTech XYZ menerapkan prinsip Privacy by Design dan mematuhi seluruh perundang-undangan perlindungan privasi yang berlaku di Indonesia:',
          }),

          createBullet('Keamanan Akses Biometrik Lokal', 'Aplikasi mendukung autentikasi Sidik Jari (Fingerprint) dan Pemindai Wajah (Face ID). Seluruh validasi biometrik dilakukan 100% pada hardware Secure Enclave / Android Keystore di perangkat pengguna. VibeTech XYZ tidak pernah merekam atau mengirim data sidik jari ke server manapun.'),
          createBullet('Enkripsi Kredensial & PIN Transaksi', 'Kata sandi akun dan PIN transaksi 6 digit dienkripsi dengan algoritma hashing kriptografi satu arah yang tidak dapat didekripsi oleh pihak pengelola sekalipun.'),
          createBullet('Enkripsi Jalur Komunikasi (SSL/TLS)', 'Seluruh pertukaran data antara aplikasi mobile, server backend, Firebase, dan payment gateway diproteksi enkripsi TLS 1.3 / HTTPS 256-bit.'),
          createBullet('Hak Pengguna atas Data Pribadi', 'Pengguna memiliki kendali penuh atas data mereka, termasuk hak untuk melihat riwayat login, memperbarui biodata, mereset sesi percakapan Furina AI, serta mengajukan penutupan dan penghapusan akun permanen (Right to Erasure).'),

          createSubHeader('6. APP STORE OPTIMIZATION (ASO) & KATA KUNCI PENCARIAN'),
          new Paragraph({
            text: 'Daftar kata kunci strategis untuk memaksimalkan visibilitas aplikasi di Google Play Store Indonesia & Internasional:',
          }),

          // Keywords Table
          new Table({
            width: { size: 9000, type: WidthType.DXA },
            columnWidths: [3000, 6000],
            rows: [
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 3000, type: WidthType.DXA },
                    shading: { fill: COLOR_HEADER_BG, type: ShadingType.CLEAR },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ children: [new TextRun({ text: 'Kategori Kata Kunci', bold: true })] })],
                  }),
                  new TableCell({
                    width: { size: 6000, type: WidthType.DXA },
                    shading: { fill: COLOR_HEADER_BG, type: ShadingType.CLEAR },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ children: [new TextRun({ text: 'Target Kata Kunci (Keywords)', bold: true })] })],
                  }),
                ],
              }),
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 3000, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: 'Infrastruktur VPS' })],
                  }),
                  new TableCell({
                    width: { size: 6000, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: 'sewa vps murah, cloud vps indonesia, vps ubuntu, vps windows, rdp murah, vps nvme, cloud server' })],
                  }),
                ],
              }),
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 3000, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: 'Game Panel & Web' })],
                  }),
                  new TableCell({
                    width: { size: 6000, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: 'panel pterodactyl, hosting minecraft, hosting samp, hosting fivem, nodejs hosting, bot discord host' })],
                  }),
                ],
              }),
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 3000, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: 'Otomasi WhatsApp' })],
                  }),
                  new TableCell({
                    width: { size: 6000, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: 'sewa bot wa, bot whatsapp 24 jam, bot wa cloud, whatsapp automation, pairing code bot' })],
                  }),
                ],
              }),
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 3000, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: 'Kecerdasan Buatan (AI)' })],
                  }),
                  new TableCell({
                    width: { size: 6000, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      left: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_BORDER },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: 'furina ai, asisten server ai, google gemini bot, ai chatbot coding, konsultan vps' })],
                  }),
                ],
              }),
            ],
          }),

          new Paragraph({ text: '', spacing: { after: 120 } }),

          createSubHeader('7. CATATAN RILIS PERDANA (WHAT’S NEW v1.0.0)'),
          new Paragraph({
            text: 'Pemberitahuan pembaruan yang dicantumkan pada form "What’s new in this release" di Google Play Console:',
          }),
          new Paragraph({
            children: [
              new TextRun({
                text: '🎉 Selamat Datang di Rilis Perdana VibeTech XYZ v1.0.0!\n',
                bold: true,
                color: COLOR_PRIMARY,
              }),
              new TextRun({
                text: '• Peluncuran katalog Cloud VPS NVMe instan dengan ragam OS Linux & Windows.\n• Deployment panel Pterodactyl untuk server Minecraft, SA:MP, FiveM & Node.js.\n• Integrasi layanan Sewa Bot WhatsApp 24/7 dengan metode pairing code kilat.\n• Asisten pintar Furina AI berbasis Google Gemini untuk panduan teknis tanpa henti.\n• Sistem pembayaran instan terintegrasi Midtrans (QRIS & Virtual Account Bank).\n• Dompet digital VibeWallet dan autentikasi aman dengan Biometrik & PIN 6 Digit.\n• Peningkatan stabilitas performa sinkronisasi database SQLite & Firebase.',
              }),
            ],
            spacing: { after: 140 },
          }),

          createSubHeader('8. PANDUAN PENGGUNAAN CEPAT (QUICK START GUIDE)'),
          new Paragraph({
            text: 'Langkah mudah menggunakan VibeTech XYZ bagi pengguna baru:',
          }),
          createNumberBullet('1', 'Pendaftaran Akun', 'Unduh aplikasi, lalu daftar dengan email aktif atau gunakan Single Sign-On (Google Sign-In / GitHub) untuk masuk seketika.'),
          createNumberBullet('2', 'Pilih Produk / Layanan', 'Buka menu Produk, pilih kategori (VPS, Panel, atau Bot WA), dan tentukan paket spesifikasi yang sesuai kebutuhan Anda.'),
          createNumberBullet('3', 'Pembayaran Otomatis', 'Pilih metode bayar QRIS atau Transfer Virtual Account melalui Midtrans. Anda juga dapat menggunakan saldo VibeWallet.'),
          createNumberBullet('4', 'Akses Kredensial Layanan', 'Setelah pembayaran berhasil, buka menu "Layanan Saya". Alamat IP, port, password server, atau pairing code bot Anda telah terbit dan siap digunakan!'),

          createSubHeader('9. LAYANAN BANTUAN & INFORMASI KONTAK RESMI'),
          new Paragraph({
            text: 'Tim VibeTech XYZ berkomitmen memberikan layanan purna jual terbaik dengan dukungan teknis 24/7:',
          }),
          createBullet('Website Resmi', 'https://vibetech.xyz'),
          createBullet('Email Dukungan Pelanggan', 'support@vibetech.xyz'),
          createBullet('WhatsApp Customer Care', '+62 878-8587-3325'),
          createBullet('Pengembang Utama (Lead Developer)', 'Raziek & VibeTech XYZ Developer Ecosystem'),
          createBullet('Lokasi Server & Operasional', 'Indonesia & Singapura'),

          new Paragraph({ text: '', spacing: { after: 200 } }),
          new Paragraph({
            alignment: AlignmentType.CENTER,
            children: [
              new TextRun({
                text: '— Dokumen Resmi Pengajuan Google Play Store VibeTech XYZ © 2026 —',
                bold: true,
                size: 20,
                color: COLOR_MUTED,
              }),
            ],
          }),
        ],
      },
    ],
  });

  const buffer = await Packer.toBuffer(doc);
  fs.writeFileSync('d:/vibetech_xyz_sqflite/vibetech_xyz/Deskripsi_PlayStore_VibeTech_XYZ.docx', buffer);
  console.log('✅ File Deskripsi_PlayStore_VibeTech_XYZ.docx berhasil dibuat!');
}

generateDocx().catch((err) => {
  console.error('Error generating docx:', err);
});
