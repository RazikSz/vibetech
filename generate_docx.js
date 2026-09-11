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
        width: 100,
        height: 100,
      },
      type: 'png',
    });
  } catch (e) {
    console.log('Logo file not found:', e.message);
  }

  const doc = new Document({
    creator: 'VibeTech XYZ',
    title: 'Kebijakan Privasi VibeTech XYZ',
    description: 'Kebijakan Privasi Resmi VibeTech XYZ (UU PDP No. 27/2022)',
    styles: {
      default: {
        document: {
          run: {
            font: 'Arial',
            size: 22, // 11pt
            color: '1E293B',
          },
          paragraph: {
            spacing: {
              line: 280,
              after: 120,
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
              top: 1440, // 1 inch = 1440 dxa
              bottom: 1440,
              left: 1440,
              right: 1440,
            },
          },
        },
        children: [
          // 1. Logo
          ...(logoImageRun
            ? [
                new Paragraph({
                  alignment: AlignmentType.CENTER,
                  children: [logoImageRun],
                  spacing: { after: 120 },
                }),
              ]
            : []),

          // 2. Title & Subtitle
          new Paragraph({
            text: 'KEBIJAKAN PRIVASI (PRIVACY POLICY)',
            heading: HeadingLevel.TITLE,
            alignment: AlignmentType.CENTER,
            spacing: { after: 60 },
          }),
          new Paragraph({
            alignment: AlignmentType.CENTER,
            children: [
              new TextRun({
                text: 'VibeTech XYZ Cloud & Server Infrastructure Ecosystem',
                bold: true,
                size: 24, // 12pt
                color: '7C3AED',
              }),
            ],
            spacing: { after: 240 },
          }),

          // 3. Metadata Table (2 Columns with explicit DXA widths: 2800 dxa & 6200 dxa = 9000 dxa total)
          new Table({
            width: { size: 9000, type: WidthType.DXA },
            columnWidths: [2800, 6200],
            rows: [
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 2800, type: WidthType.DXA },
                    shading: { fill: 'F1F5F9', type: ShadingType.CLEAR },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ children: [new TextRun({ text: 'Nama Aplikasi', bold: true })] })],
                  }),
                  new TableCell({
                    width: { size: 6200, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: 'VibeTech XYZ (com.vibetech.xyz)' })],
                  }),
                ],
              }),
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 2800, type: WidthType.DXA },
                    shading: { fill: 'F1F5F9', type: ShadingType.CLEAR },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ children: [new TextRun({ text: 'Versi Dokumen', bold: true })] })],
                  }),
                  new TableCell({
                    width: { size: 6200, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: '2.0.0' })],
                  }),
                ],
              }),
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 2800, type: WidthType.DXA },
                    shading: { fill: 'F1F5F9', type: ShadingType.CLEAR },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ children: [new TextRun({ text: 'Tanggal Berlaku', bold: true })] })],
                  }),
                  new TableCell({
                    width: { size: 6200, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: '31 Agustus 2026' })],
                  }),
                ],
              }),
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 2800, type: WidthType.DXA },
                    shading: { fill: 'F1F5F9', type: ShadingType.CLEAR },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ children: [new TextRun({ text: 'Pengembang / Pemilik', bold: true })] })],
                  }),
                  new TableCell({
                    width: { size: 6200, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: 'VibeTech XYZ (Lead Developer: Raziek)' })],
                  }),
                ],
              }),
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 2800, type: WidthType.DXA },
                    shading: { fill: 'F1F5F9', type: ShadingType.CLEAR },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ children: [new TextRun({ text: 'Website Resmi', bold: true })] })],
                  }),
                  new TableCell({
                    width: { size: 6200, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: 'https://vibetech.xyz' })],
                  }),
                ],
              }),
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 2800, type: WidthType.DXA },
                    shading: { fill: 'F1F5F9', type: ShadingType.CLEAR },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ children: [new TextRun({ text: 'Email Dukungan', bold: true })] })],
                  }),
                  new TableCell({
                    width: { size: 6200, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: 'support@vibetech.xyz' })],
                  }),
                ],
              }),
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 2800, type: WidthType.DXA },
                    shading: { fill: 'F1F5F9', type: ShadingType.CLEAR },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ children: [new TextRun({ text: 'WhatsApp Layanan', bold: true })] })],
                  }),
                  new TableCell({
                    width: { size: 6200, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                    },
                    margins: { top: 80, bottom: 80, left: 120, right: 120 },
                    children: [new Paragraph({ text: '+62 878-8587-3325' })],
                  }),
                ],
              }),
            ],
          }),

          new Paragraph({ text: '', spacing: { after: 140 } }),

          // 4. Legal Statement Callout
          new Paragraph({
            children: [
              new TextRun({
                text: 'Pernyataan Kepatuhan Hukum: ',
                bold: true,
                color: '166534',
              }),
              new TextRun({
                text: 'Kebijakan Privasi ini disusun berdasarkan ketentuan Undang-Undang Republik Indonesia No. 27 Tahun 2022 tentang Perlindungan Data Pribadi (UU PDP) serta pedoman kepatuhan privasi resmi Google Play Store dan Apple App Store.',
                color: '166534',
              }),
            ],
            spacing: { before: 100, after: 180 },
          }),

          // Section 1
          new Paragraph({
            text: '1. PENDAHULUAN',
            heading: HeadingLevel.HEADING_1,
            spacing: { before: 200, after: 100 },
          }),
          new Paragraph({
            children: [
              new TextRun(
                'Selamat datang di VibeTech XYZ. Kami berkomitmen penuh untuk melindungi privasi dan keamanan data pribadi yang Anda percayakan saat mengakses maupun menggunakan seluruh ekosistem aplikasi kami (termasuk penyewaan Cloud VPS, Panel Hosting Game/Web Pterodactyl, Sewa Bot WhatsApp, VibeWallet, serta asisten cerdas Furina AI).'
              ),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun(
                'Dengan mengunduh, mendaftar, mengakses, atau menggunakan layanan VibeTech XYZ, Anda menyatakan bahwa Anda telah membaca, memahami, dan menyetujui seluruh ketentuan pengolahan data pribadi dalam dokumen Kebijakan Privasi ini.'
              ),
            ],
          }),

          // Section 2
          new Paragraph({
            text: '2. DATA PRIBADI YANG KAMI KUMPULKAN',
            heading: HeadingLevel.HEADING_1,
            spacing: { before: 240, after: 100 },
          }),
          new Paragraph({
            children: [
              new TextRun(
                'Aplikasi VibeTech XYZ mengumpulkan beberapa kategori data pribadi yang diperlukan untuk kelancaran transaksi dan operasional infrastruktur server:'
              ),
            ],
          }),

          // Sub 2.A
          new Paragraph({
            text: 'A. Data Identitas Akun Pengguna',
            heading: HeadingLevel.HEADING_2,
            spacing: { before: 140, after: 80 },
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Data Pokok: ', bold: true }),
              new TextRun('Nama lengkap, alamat email aktif, username unik, dan nomor telepon/WhatsApp.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Data Profil: ', bold: true }),
              new TextRun('Foto avatar profil, lokasi tempat tinggal/kota, biografi akun, serta kode referral.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Peran Akun (Role): ', bold: true }),
              new TextRun('Hak akses akun sistem (user atau admin).'),
            ],
          }),

          // Sub 2.B
          new Paragraph({
            text: 'B. Data Keamanan & Kredensial Akun',
            heading: HeadingLevel.HEADING_2,
            spacing: { before: 140, after: 80 },
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Kata Sandi (Password): ', bold: true }),
              new TextRun('Disimpan dalam bentuk hash kriptografi terenkripsi dan tidak dapat dibaca langsung oleh siapapun.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'PIN Transaksi 6-Digit: ', bold: true }),
              new TextRun('Digunakan untuk otorisasi checkout pembelian server, transfer saldo, dan perubahan konfigurasi akun.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Otentikasi Dua Faktor (2FA): ', bold: true }),
              new TextRun('Status proteksi autentikasi ganda akun.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Log Riwayat Masuk (Login History): ', bold: true }),
              new TextRun('Catatan waktu login, provider (Email, Google Sign-In, GitHub OAuth), dan status autentikasi.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Data Biometrik (Sidik Jari / Face ID): ', bold: true }),
              new TextRun('Diproses '),
              new TextRun({ text: '100% secara lokal ', bold: true }),
              new TextRun('melalui modul perangkat keras keamanan (Secure Enclave / Keystore) di perangkat Anda. VibeTech XYZ '),
              new TextRun({ text: 'TIDAK PERNAH ', bold: true }),
              new TextRun('mengumpulkan, mentransmisikan, atau menyimpan data biometrik mentah Anda di server kami.'),
            ],
          }),

          // Sub 2.C
          new Paragraph({
            text: 'C. Data Transaksi Keuangan & VibeWallet',
            heading: HeadingLevel.HEADING_2,
            spacing: { before: 140, after: 80 },
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun('Nomor Invoice digital dan ID Pesanan (Order ID).'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun('Paket layanan yang dibeli, kuantitas, total harga (Rupiah), catatan pesanan, dan tanggal transaksi.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun('Metode pembayaran yang digunakan (Saldo internal VibeWallet, QRIS Instant, Virtual Account Bank BCA/Mandiri/BRI/BNI/Permata, atau E-Wallet GoPay/DANA/OVO/ShopeePay).'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun('Saldo aktif dan riwayat mutasi transaksi VibeWallet.'),
            ],
          }),

          // Sub 2.D
          new Paragraph({
            text: 'D. Data Layanan Server & Bot WhatsApp Aktif',
            heading: HeadingLevel.HEADING_2,
            spacing: { before: 140, after: 80 },
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun('Alokasi alamat IP server, port jaringan, URL panel server, dan username server VPS/Panel.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun('Session ID dan nomor sesi bot WhatsApp aktif.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun('Siklus aktif paket langganan dan tanggal kadaluarsa (expired date).'),
            ],
          }),

          // Sub 2.E
          new Paragraph({
            text: 'E. Data Interaksi Asisten Cerdas (Furina AI)',
            heading: HeadingLevel.HEADING_2,
            spacing: { before: 140, after: 80 },
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun('Pesan konsultasi dan prompt pertanyaan teknis mengenai spesifikasi server.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun('ID Sesi percakapan (Session ID) yang dapat direset atau dibersihkan kapan saja oleh pengguna melalui fitur Reset Session.'),
            ],
          }),

          // Sub 2.F
          new Paragraph({
            text: 'F. Data Tiket Bantuan & Notifikasi',
            heading: HeadingLevel.HEADING_2,
            spacing: { before: 140, after: 80 },
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun('Nomor tiket bantuan, nama pengirim, subjek kendala, rincian pesan bantuan, dan status penyelesaian tiket.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun('Riwayat pesan email transaksional dan kode OTP verifikasi pemulihan kata sandi.'),
            ],
          }),

          // Section 3: Device Permissions Table (2800 dxa + 6200 dxa = 9000 dxa)
          new Paragraph({
            text: '3. IZIN AKSES PERANGKAT (DEVICE PERMISSIONS)',
            heading: HeadingLevel.HEADING_1,
            spacing: { before: 240, after: 100 },
          }),
          new Table({
            width: { size: 9000, type: WidthType.DXA },
            columnWidths: [3000, 6000],
            rows: [
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 3000, type: WidthType.DXA },
                    shading: { fill: 'F1F5F9', type: ShadingType.CLEAR },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 6, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 6, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 6, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 6, color: 'CBD5E1' },
                    },
                    margins: { top: 100, bottom: 100, left: 140, right: 140 },
                    children: [
                      new Paragraph({
                        children: [new TextRun({ text: 'Izin Perangkat', bold: true, color: '0F172A' })],
                      }),
                    ],
                  }),
                  new TableCell({
                    width: { size: 6000, type: WidthType.DXA },
                    shading: { fill: 'F1F5F9', type: ShadingType.CLEAR },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 6, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 6, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 6, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 6, color: 'CBD5E1' },
                    },
                    margins: { top: 100, bottom: 100, left: 140, right: 140 },
                    children: [
                      new Paragraph({
                        children: [new TextRun({ text: 'Fungsi & Tujuan Penggunaan', bold: true, color: '0F172A' })],
                      }),
                    ],
                  }),
                ],
              }),
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 3000, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                    },
                    margins: { top: 100, bottom: 100, left: 140, right: 140 },
                    children: [
                      new Paragraph({
                        children: [new TextRun({ text: 'android.permission.INTERNET', bold: true })],
                      }),
                    ],
                  }),
                  new TableCell({
                    width: { size: 6000, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                    },
                    margins: { top: 100, bottom: 100, left: 140, right: 140 },
                    children: [
                      new Paragraph({
                        text: 'Menghubungkan aplikasi ke backend Express, sinkronisasi Cloud Firestore, gerbang pembayaran Midtrans, otentikasi Google/GitHub, dan AI Furina.',
                      }),
                    ],
                  }),
                ],
              }),
              new TableRow({
                children: [
                  new TableCell({
                    width: { size: 3000, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                    },
                    margins: { top: 100, bottom: 100, left: 140, right: 140 },
                    children: [
                      new Paragraph({
                        children: [
                          new TextRun({ text: 'android.permission.USE_BIOMETRIC', bold: true }),
                        ],
                      }),
                      new Paragraph({
                        children: [
                          new TextRun({ text: 'android.permission.USE_FINGERPRINT', bold: true }),
                        ],
                      }),
                    ],
                  }),
                  new TableCell({
                    width: { size: 6000, type: WidthType.DXA },
                    borders: {
                      top: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      bottom: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      left: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                      right: { style: BorderStyle.SINGLE, size: 4, color: 'CBD5E1' },
                    },
                    margins: { top: 100, bottom: 100, left: 140, right: 140 },
                    children: [
                      new Paragraph({
                        text: 'Otentikasi login cepat dan aman dengan sensor biometrik lokal di perangkat Anda tanpa mentransmisikan data sidik jari ke server.',
                      }),
                    ],
                  }),
                ],
              }),
            ],
          }),

          new Paragraph({ text: '', spacing: { after: 160 } }),

          // Section 4
          new Paragraph({
            text: '4. TUJUAN PENGOLAHAN DATA',
            heading: HeadingLevel.HEADING_1,
            spacing: { before: 240, after: 100 },
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '1.  ', bold: true, color: '7C3AED' }),
              new TextRun('Mengaktifkan dan memproses otomatisasi provisioning Cloud VPS, Game Panel, dan Bot WhatsApp.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '2.  ', bold: true, color: '7C3AED' }),
              new TextRun('Memproses transaksi pembayaran digital dan penerbitan invoice resmi.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '3.  ', bold: true, color: '7C3AED' }),
              new TextRun('Mengamankan akun dari akses tidak sah melalui verifikasi PIN 6 digit, 2FA, OTP email, dan audit riwayat login.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '4.  ', bold: true, color: '7C3AED' }),
              new TextRun('Mengirimkan bukti transaksi, notifikasi kadaluarsa server, kode OTP reset password, dan layanan dukungan teknis.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '5.  ', bold: true, color: '7C3AED' }),
              new TextRun('Memberikan respons rekomendasi infrastruktur yang akurat melalui asisten AI Furina (Google Gemini).'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '6.  ', bold: true, color: '7C3AED' }),
              new TextRun('Menyelaraskan data secara real-time antara basis data lokal SQLite dengan Google Firebase Cloud.'),
            ],
          }),

          // Section 5
          new Paragraph({
            text: '5. INTEGRASI LAYANAN PIHAK KETIGA',
            heading: HeadingLevel.HEADING_1,
            spacing: { before: 240, after: 100 },
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Google Firebase: ', bold: true }),
              new TextRun('Layanan autentikasi, Cloud Firestore, dan Realtime Database.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Google Sign-In & GitHub OAuth: ', bold: true }),
              new TextRun('Layanan otentikasi Single Sign-On (SSO).'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Midtrans Payment Gateway (PT Midtrans): ', bold: true }),
              new TextRun('Pemrosesan pembayaran bersertifikasi PCI-DSS berizin Bank Indonesia.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Google Generative AI / Gemini API: ', bold: true }),
              new TextRun('Pemrosesan kecerdasan buatan untuk asisten Furina AI.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Nodemailer / Google Workspace SMTP: ', bold: true }),
              new TextRun('Pengiriman email transaksional dan OTP.'),
            ],
          }),

          // Section 6
          new Paragraph({
            text: '6. KEAMANAN DAN PENYIMPANAN DATA',
            heading: HeadingLevel.HEADING_1,
            spacing: { before: 240, after: 100 },
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Enkripsi Komunikasi: ', bold: true }),
              new TextRun('Seluruh komunikasi jaringan menggunakan protokol terenkripsi HTTPS / SSL / TLS.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Database Terisolasi: ', bold: true }),
              new TextRun('Data lokal disimpan di direktori terisolasi SQLite (vibetech.db).'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Proteksi Sandi & PIN: ', bold: true }),
              new TextRun('Disimpan dengan standar enkripsi hash satu arah yang aman.'),
            ],
          }),

          // Section 7
          new Paragraph({
            text: '7. HAK-HAK PENGGUNA ATAS DATA PRIBADI',
            heading: HeadingLevel.HEADING_1,
            spacing: { before: 240, after: 100 },
          }),
          new Paragraph({
            children: [
              new TextRun('Berdasarkan UU PDP No. 27/2022, Anda berhak untuk:'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Hak Akses: ', bold: true }),
              new TextRun('Melihat data profil, transaksi, invoice, dan server aktif kapan saja.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Hak Koreksi: ', bold: true }),
              new TextRun('Memperbarui informasi nama, nomor telepon, bio, lokasi, password, dan PIN di menu Akun.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Hak Reset AI: ', bold: true }),
              new TextRun('Membersihkan riwayat percakapan dengan Furina AI.'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Hak Penghapusan Akun (Right to Erasure): ', bold: true }),
              new TextRun('Mengajukan penutupan akun dan penghapusan data secara permanen dengan menghubungi Customer Service.'),
            ],
          }),

          // Section 8
          new Paragraph({
            text: '8. KONTAK DAN PUSAT BANTUAN',
            heading: HeadingLevel.HEADING_1,
            spacing: { before: 240, after: 100 },
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Organisasi / Pengembang: ', bold: true }),
              new TextRun('VibeTech XYZ (Lead Developer: Raziek)'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Email Dukungan: ', bold: true }),
              new TextRun('support@vibetech.xyz'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'WhatsApp Layanan Pelanggan: ', bold: true }),
              new TextRun('+62 878-8587-3325 (https://wa.me/6287885873325)'),
            ],
          }),
          new Paragraph({
            children: [
              new TextRun({ text: '•  ', bold: true, color: '7C3AED' }),
              new TextRun({ text: 'Website Resmi: ', bold: true }),
              new TextRun('https://vibetech.xyz'),
            ],
          }),
        ],
      },
    ],
  });

  const buffer = await Packer.toBuffer(doc);
  fs.writeFileSync('d:/vibetech_xyz_sqflite/vibetech_xyz/privacy_policy.docx', buffer);
  console.log('Successfully generated clean fixed privacy_policy.docx');
}

generateDocx().catch((err) => {
  console.error('Error generating docx:', err);
  process.exit(1);
});
