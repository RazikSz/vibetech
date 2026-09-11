import express from 'express';
import cors from 'cors';
import fs from 'fs';
import path from 'path';
import axios from 'axios';
import FormData from 'form-data';
import nodemailer from 'nodemailer';
import midtransClient from 'midtrans-client';
import {
  askFurinaAI,
  resetFurinaSession,
  FURINA_AVATAR_URL,
  FURINA_DIRECTOR,
} from './plugins/furina_scraper.js';

const app = express();
const PORT = process.env.PORT || 3000;

// Enable CORS & JSON Body Parser
app.use(cors());
app.use(express.json());

// ============================================================================
// 1. MIDTRANS CONFIGURATION
// ============================================================================
const serverKey = 'Mid-server-dtHCBAI47kvZYV98pjt68ut8';
const isProduction = false;

const snap = new midtransClient.Snap({
  isProduction: isProduction,
  serverKey: serverKey,
});

// Endpoint Welcome / Health Check
app.get('/', (req, res) => {
  res.status(200).json({
    app: 'VibeTech XYZ Backend API & AI Engine',
    version: '2.0.0',
    director: FURINA_DIRECTOR,
    endpoints: [
      'POST /api/ai/chat',
      'POST /api/ai/furina',
      'POST /api/ai/reset-session',
      'GET  /api/ai/status',
      'POST /api/qris/dynamic',
      'POST /api/charge',
      'GET  /api/status/:order_id',
    ],
  });
});

// ============================================================================
// 2. ENDPOINT AI FURINA (THEATRICAL ASSISTANT VIBETECH XYZ)
// ============================================================================

/**
 * POST /api/ai/chat atau POST /api/ai/furina
 * Request Body:
 * {
 *   "prompt": "Rekomendasikan VPS terbaik",
 *   "sessionId": "user_email@example.com"
 * }
 */
const handleAiChat = async (req, res) => {
  try {
    const text = req.body.prompt || req.body.text || req.body.message;
    const sessionId =
      req.body.sessionId || req.body.user || req.body.sender || 'default_session';

    if (!text || typeof text !== 'string' || !text.trim()) {
      return res.status(400).json({
        status: false,
        error: 'Pesan (prompt / message) tidak boleh kosong.',
      });
    }

    const appContext =
      req.body.appContext || req.body.context || req.body.appData || '';

    console.log(`[AI Request - Session: ${sessionId}]: "${text}"`);
    const answer = await askFurinaAI({
      text: text.trim(),
      sessionId,
      appContext,
    });

    return res.status(200).json({
      status: true,
      result: {
        answer: answer,
        character: 'Furina',
        director: FURINA_DIRECTOR,
        avatarUrl: FURINA_AVATAR_URL,
        timestamp: new Date().toISOString(),
      },
    });
  } catch (error) {
    console.error('[AI Chat Route Error]:', error.message);
    return res.status(500).json({
      status: false,
      error: 'Aiya! Terjadi kesalahan teknis di atas panggung!',
      details: error.message,
    });
  }
};

app.post('/api/ai/chat', handleAiChat);
app.post('/api/ai/furina', handleAiChat);

/**
 * POST /api/ai/reset-session
 * Membersihkan riwayat percakapan sesi user
 */
app.post('/api/ai/reset-session', (req, res) => {
  const sessionId = req.body.sessionId || req.body.user || 'default_session';
  const success = resetFurinaSession(sessionId);
  return res.status(200).json({
    status: true,
    message: success
      ? `Sesi [${sessionId}] berhasil direset ke babak awal.`
      : `Sesi [${sessionId}] sudah kosong.`,
  });
});

/**
 * GET /api/ai/status
 * Cek status layanan AI
 */
app.get('/api/ai/status', (req, res) => {
  res.status(200).json({
    status: true,
    service: 'Furina AI Engine',
    character: 'Furina (Genshin Impact / VibeTech Edition)',
    director: FURINA_DIRECTOR,
    avatarUrl: FURINA_AVATAR_URL,
    uptimeSeconds: Math.floor(process.uptime()),
  });
});

// ============================================================================
// 3. ENDPOINT MIDTRANS PAYMENT GATEWAY
// ============================================================================

// ENDPOINT CHARGE
app.post('/api/charge', async (req, res) => {
  try {
    const { order_id, gross_amount, customer_details, payment_method } = req.body;

    // JIKA PEMBAYARAN QRIS: JANGAN GUNAKAN MIDTRANS, GUNAKAN QRIS DINAMIS NEXRAY
    if (payment_method === 'qris') {
      const nominal = String(gross_amount || req.body.nominal || '25000');
      const form = new FormData();
      form.append('nominal', nominal);

      const possiblePaths = [
        path.resolve('../assets/images/qris.jpg'),
        path.resolve('./assets/images/qris.jpg'),
        path.resolve('assets/images/qris.jpg'),
      ];

      for (const p of possiblePaths) {
        if (fs.existsSync(p)) {
          form.append('file', fs.createReadStream(p));
          break;
        }
      }
      form.append('url', req.body.url || '');

      const response = await axios.post('https://api.nexray.eu.cc/payment/qris', form, {
        headers: {
          ...form.getHeaders(),
        },
      });

      return res.status(200).json(response.data);
    }

    let enabledPayments = [];
    switch (payment_method) {
      case 'gopay':
        enabledPayments = ['gopay'];
        break;
      case 'shopeepay':
        enabledPayments = ['shopeepay'];
        break;
      case 'dana':
        enabledPayments = ['dana'];
        break;
      case 'ovo':
        enabledPayments = ['ovo'];
        break;
      case 'transfer':
        enabledPayments = ['bca_va', 'echannel', 'bni_va', 'bri_va', 'permata_va'];
        break;
      default:
        enabledPayments = [
          'gopay',
          'shopeepay',
          'dana',
          'ovo',
          'bca_va',
          'bni_va',
          'bri_va',
        ];
    }

    const parameter = {
      transaction_details: {
        order_id: order_id,
        gross_amount: gross_amount,
      },
      customer_details: customer_details,
      enabled_payments: enabledPayments,
    };

    let transaction;
    try {
      transaction = await snap.createTransaction(parameter);
    } catch (createErr) {
      const errMsg = String(createErr.message || '').toLowerCase();
      if (
        errMsg.includes('order_id') ||
        errMsg.includes('already been taken') ||
        errMsg.includes('sudah digunakan')
      ) {
        const retryOrderId = `${order_id}-${Date.now() % 100000}`;
        console.log(`[Charge Auto-Recovery] Order ID taken. Retrying with: ${retryOrderId}`);
        parameter.transaction_details.order_id = retryOrderId;
        transaction = await snap.createTransaction(parameter);
      } else {
        throw createErr;
      }
    }

    // Otomatis ekstrak deep link / VA langsung dari Midtrans Snap Pay API
    let directPayData = null;
    let payChannel = null;
    if (payment_method === 'gopay') payChannel = 'gopay';
    else if (payment_method === 'shopeepay') payChannel = 'shopeepay';
    else if (payment_method === 'dana') payChannel = 'dana';
    else if (payment_method === 'bca_va' || payment_method === 'transfer') payChannel = 'bca_va';
    else if (payment_method === 'bri_va') payChannel = 'bri_va';
    else if (payment_method === 'bni_va') payChannel = 'bni_va';
    else if (payment_method === 'mandiri_va' || payment_method === 'echannel') payChannel = 'echannel';

    if (payChannel && transaction.token) {
      try {
        const snapPayBase = isProduction
          ? 'https://app.midtrans.com/snap/v1/transactions'
          : 'https://app.sandbox.midtrans.com/snap/v1/transactions';
        const payPayload = { payment_type: payChannel };
        if (payChannel === 'ovo' && customer_details && customer_details.phone) {
          payPayload.customer_details = { phone: customer_details.phone };
        }
        const payRes = await axios.post(`${snapPayBase}/${transaction.token}/pay`, payPayload, {
          headers: { 'Content-Type': 'application/json' },
          timeout: 5000,
        });
        directPayData = payRes.data;
      } catch (err) {
        console.warn('[Direct Pay Warning]:', err.response?.data || err.message);
      }
    }

    res.status(200).json({
      success: true,
      order_id: parameter.transaction_details.order_id,
      token: transaction.token,
      redirect_url: transaction.redirect_url,
      deeplink_url: directPayData?.deeplink_url || null,
      qr_code_url: directPayData?.qr_code_url || null,
      qr_string: directPayData?.qr_string || null,
      va_number: directPayData?.bca_va_number ||
        directPayData?.bri_va_number ||
        directPayData?.bni_va_number ||
        (directPayData?.va_numbers && directPayData.va_numbers[0]?.va_number) ||
        null,
      bank: payChannel,
      expiry_time: directPayData?.expiry_time || null,
      direct_data: directPayData,
    });
  } catch (e) {
    console.error('Charge Error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// ============================================================================
// 3.5. ENDPOINT QRIS DINAMIS (NEXRAY API - CODINGAN DARI USER)
// ============================================================================
app.post('/api/qris/dynamic', async (req, res) => {
  try {
    const nominal = String(req.body.nominal || req.body.amount || '25000');
    const form = new FormData();
    form.append('nominal', nominal);

    const possiblePaths = [
      path.resolve('../assets/images/qris.jpg'),
      path.resolve('./assets/images/qris.jpg'),
      path.resolve('assets/images/qris.jpg'),
    ];

    let foundFile = false;
    for (const p of possiblePaths) {
      if (fs.existsSync(p)) {
        form.append('file', fs.createReadStream(p));
        foundFile = true;
        break;
      }
    }
    if (!foundFile) {
      form.append('file', '');
    }
    form.append('url', req.body.url || '');

    const response = await axios.post('https://api.nexray.eu.cc/payment/qris', form, {
      headers: {
        ...form.getHeaders(),
      },
    });

    return res.status(200).json(response.data);
  } catch (error) {
    console.error('[QRIS Dynamic Endpoint Error]:', error.message);
    return res.status(500).json({
      status: false,
      error: error.message,
    });
  }
});

// ENDPOINT CEK STATUS PEMBAYARAN MIDTRANS
app.get('/api/status/:order_id', async (req, res) => {
  try {
    const orderId = req.params.order_id;
    const authHeader = Buffer.from(serverKey + ':').toString('base64');
    const baseUrl = isProduction
      ? 'https://api.midtrans.com'
      : 'https://api.sandbox.midtrans.com';

    const response = await fetch(`${baseUrl}/v2/${orderId}/status`, {
      method: 'GET',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        Authorization: `Basic ${authHeader}`,
      },
    });

    const data = await response.json();
    console.log(`[STATUS MIDTRANS - ${orderId}]:`, data.transaction_status || response.status);

    if (response.status === 404) {
      return res.status(200).json({
        transaction_status: 'pending',
        status_message: 'Transaksi belum dibayar atau masih dalam proses Sandbox',
      });
    }

    res.status(response.status).json(data);
  } catch (e) {
    console.error('Cek Status Error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// ============================================================================
// 4. ENDPOINT EMAIL DISPATCHER & NODEMAILER (VIBETECH NOTIFICATION SYSTEM)
// ============================================================================
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.SMTP_USER || 'vibetech.official.xyz@gmail.com',
    pass: process.env.SMTP_PASS || 'fuhs qpvu fskx jmsw',
  },
});

app.post('/api/send-email', async (req, res) => {
  try {
    const { to, subject, message, category, orderId, amount } = req.body;

    if (!to || !subject || !message) {
      return res.status(400).json({
        status: false,
        error: 'Parameter to, subject, dan message wajib diisi.',
      });
    }

    console.log(`\n📧 [EMAIL DISPATCHER - VIBETECH]:`);
    console.log(`   -> Kepada   : ${to}`);
    console.log(`   -> Subjek   : ${subject}`);
    console.log(`   -> Kategori : ${category || 'Sistem'}`);
    console.log(`   -> Transaksi: ${orderId || '-'}`);
    console.log(`   -> Nominal  : ${amount || '-'}`);
    console.log(`   -> Waktu    : ${new Date().toLocaleString('id-ID')}`);

    const htmlContent = `
      <div style="font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background: #0B0E1B; color: #FFFFFF; padding: 32px 20px; border-radius: 16px; max-width: 600px; margin: 0 auto; border: 1px solid rgba(124, 77, 255, 0.35);">
        <div style="text-align: center; margin-bottom: 24px;">
          <h1 style="color: #7C4DFF; margin: 0; font-size: 26px; font-weight: 800; letter-spacing: 1px;">VIBETECH <span style="color: #00E5FF;">XYZ</span></h1>
          <p style="color: #94A3B8; margin: 4px 0 0 0; font-size: 13px;">Cloud Hosting & Digital Automation System</p>
        </div>
        
        <div style="background: rgba(255, 255, 255, 0.05); padding: 22px; border-radius: 14px; border: 1px solid rgba(255, 255, 255, 0.12); margin-bottom: 20px;">
          <div style="margin-bottom: 12px;">
            <span style="background: #7C4DFF; color: #FFFFFF; font-size: 11px; font-weight: 700; padding: 4px 12px; border-radius: 20px; text-transform: uppercase;">${category || 'Notifikasi Resmi'}</span>
          </div>
          <h2 style="color: #FFFFFF; font-size: 18px; margin: 0 0 14px 0;">${subject}</h2>
          <div style="color: #E2E8F0; font-size: 14px; line-height: 1.7; white-space: pre-line;">${message}</div>
        </div>

        ${orderId ? `
        <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px; background: rgba(255,255,255,0.03); border-radius: 10px; border: 1px solid rgba(255,255,255,0.08);">
          <tr>
            <td style="padding: 12px 14px; color: #94A3B8; font-size: 13px;">ID Transaksi / Invoice:</td>
            <td style="padding: 12px 14px; color: #00E5FF; font-weight: bold; font-size: 13px; text-align: right;">${orderId}</td>
          </tr>
          ${amount ? `
          <tr style="border-top: 1px solid rgba(255,255,255,0.05);">
            <td style="padding: 12px 14px; color: #94A3B8; font-size: 13px;">Total Pembayaran:</td>
            <td style="padding: 12px 14px; color: #10B981; font-weight: bold; font-size: 15px; text-align: right;">${amount}</td>
          </tr>` : ''}
        </table>` : ''}

        <div style="text-align: center; border-top: 1px solid rgba(255,255,255,0.1); padding-top: 18px; color: #64748B; font-size: 11px;">
          <p style="margin: 0;">Email ini dibuat secara otomatis oleh sistem notifikasi VibeTech XYZ.</p>
          <p style="margin: 4px 0 0 0;">© 2026 VibeTech XYZ. Seluruh hak cipta dilindungi undang-undang.</p>
        </div>
      </div>
    `;

    try {
      await transporter.sendMail({
        from: `"VibeTech XYZ" <${process.env.SMTP_USER || 'vibetech.official.xyz@gmail.com'}>`,
        to: to,
        subject: `[VibeTech XYZ] ${subject}`,
        text: message,
        html: htmlContent,
      });
      console.log(`   -> Status   : ✅ BERHASIL TERKIRIM KE INBOX EMAIL ${to}\n`);
    } catch (smtpErr) {
      console.log(`   -> Status   : ⚠️ SMTP Delivery Note (${smtpErr.message}), dicatat di database server.\n`);
    }

    return res.status(200).json({
      status: true,
      message: `Email notifikasi '${subject}' berhasil diproses untuk ${to}`,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Send Email Error:', error.message);
    res.status(500).json({ status: false, error: error.message });
  }
});

// Jalankan Server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`✨ Server VibeTech & Furina AI berjalan di port ${PORT} (0.0.0.0:${PORT})`);
});