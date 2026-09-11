/**
 * ============================================================================
 * WHATSAPP BOT ADMIN (BAILEYS + FIREBASE ADMIN SDK) - VIBETECH XYZ
 * ============================================================================
 * Entry point utama bot WhatsApp untuk manajemen katalog produk dan saldo user.
 */

const {
  default: makeWASocket,
  useMultiFileAuthState,
  DisconnectReason,
  fetchLatestBaileysVersion,
  makeCacheableSignalKeyStore,
  isJidBroadcast,
} = require('@whiskeysockets/baileys');
const pino = require('pino');
const qrcode = require('qrcode-terminal');
const NodeCache = require('node-cache');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

const { initFirebase } = require('./config/firebase');
const { handleCommand, getHelpMenu } = require('./handlers/commandHandler');

// Cache untuk retry dekripsi pesan Baileys
const msgRetryCounterCache = new NodeCache();

/**
 * Mengambil daftar nomor/LID owner terbaru dari .env
 */
function getOwnerList() {
  return (process.env.OWNER_NUMBERS || '')
    .split(',')
    .map((num) => num.trim().replace(/[^0-9]/g, ''))
    .filter((num) => num.length > 3);
}

/**
 * Mengecek apakah nomor / LID pengirim adalah salah satu Owner resmi
 */
function isOwner(senderJid, msg = null, sock = null) {
  // Jika pesan dikirim dari akun bot sendiri (Self Message / Linked Device)
  if (msg && msg.key && msg.key.fromMe) {
    return true;
  }

  const ownerList = getOwnerList();

  // Tambahkan ID / LID bot sendiri jika sudah terhubung
  if (sock && sock.user) {
    const botPhone = sock.user.id ? sock.user.id.split('@')[0].split(':')[0].replace(/[^0-9]/g, '') : '';
    const botLid = sock.user.lid ? sock.user.lid.split('@')[0].split(':')[0].replace(/[^0-9]/g, '') : '';
    if (botPhone && !ownerList.includes(botPhone)) ownerList.push(botPhone);
    if (botLid && !ownerList.includes(botLid)) ownerList.push(botLid);
  }

  if (!senderJid) return false;

  // Bersihkan ID / LID
  const cleanSender = senderJid.split('@')[0].split(':')[0].replace(/[^0-9]/g, '');
  if (ownerList.includes(cleanSender)) return true;

  // Cek juga dari remoteJid
  if (msg && msg.key && msg.key.remoteJid) {
    const cleanRemote = msg.key.remoteJid.split('@')[0].split(':')[0].replace(/[^0-9]/g, '');
    if (ownerList.includes(cleanRemote)) return true;
  }

  return false;
}

/**
 * Mengambil teks pesan dari berbagai payload Baileys
 */
function extractMessageText(msg) {
  if (!msg.message) return '';
  return (
    msg.message.conversation ||
    msg.message.extendedTextMessage?.text ||
    msg.message.imageMessage?.caption ||
    msg.message.videoMessage?.caption ||
    ''
  );
}

/**
 * Inisialisasi Koneksi WhatsApp Socket Baileys
 */
async function startWhatsAppBot() {
  console.log('\n======================================================');
  console.log('🚀 MEMULAI VIBETECH WHATSAPP ADMIN BOT...');
  console.log('======================================================');

  // Inisialisasi Firebase Admin
  try {
    initFirebase();
  } catch (err) {
    console.error('❌ Gagal inisialisasi Firebase. Pastikan serviceAccountKey.json telah disiapkan!');
    process.exit(1);
  }

  // Siapkan folder auth credentials multi-device
  const authFolder = path.resolve(__dirname, 'auth_info_baileys');
  const { state, saveCreds } = await useMultiFileAuthState(authFolder);
  const { version, isLatest } = await fetchLatestBaileysVersion();

  const currentOwners = getOwnerList();
  console.log(`📱 Menggunakan Baileys v${version.join('.')} (Latest: ${isLatest})`);
  console.log(`🛡️ Terdaftar ${currentOwners.length} Identitas Owner (HP/LID): ${currentOwners.join(', ')}`);

  const logger = pino({ level: 'silent' });

  const sock = makeWASocket({
    version,
    logger,
    printQRInTerminal: false,
    auth: {
      creds: state.creds,
      keys: makeCacheableSignalKeyStore(state.keys, logger),
    },
    msgRetryCounterCache,
    generateHighQualityLinkPreview: false,
    syncFullHistory: false,
    shouldIgnoreJid: (jid) => isJidBroadcast?.(jid) || (jid && jid.endsWith('@newsletter')),
    getMessage: async (key) => {
      return {
        conversation: '',
      };
    },
  });

  // Simpan update kredensial autentikasi sesi
  sock.ev.on('creds.update', saveCreds);

  // Listener Update Status Koneksi
  sock.ev.on('connection.update', async (update) => {
    const { connection, lastDisconnect, qr } = update;

    if (qr) {
      console.log('\n📲 SILAKAN SCAN QR CODE INI DI APLIKASI WHATSAPP ANDA:\n');
      qrcode.generate(qr, { small: true });
      console.log('💡 Buka WhatsApp di HP -> Perangkat Tertaut (Linked Devices) -> Tautkan Perangkat -> Scan QR di atas.\n');
    }

    if (connection === 'close') {
      const statusCode = lastDisconnect?.error?.output?.statusCode;
      const isLoggedOut = statusCode === DisconnectReason.loggedOut || statusCode === 401;
      console.log(`⚠️ Koneksi WhatsApp terputus (Status: ${statusCode}). Mencoba menghubungkan kembali: ${!isLoggedOut}`);

      if (!isLoggedOut) {
        setTimeout(() => startWhatsAppBot(), 3000);
      } else {
        console.log('❌ Sesi telah logout / 401. Membersihkan folder auth_info_baileys secara otomatis...');
        try {
          fs.rmSync(authFolder, { recursive: true, force: true });
          console.log('🧹 Folder sesi lama berhasil dibersihkan.');
          console.log('🔄 Memulai ulang bot untuk generate QR Code baru...\n');
          setTimeout(() => startWhatsAppBot(), 2000);
        } catch (cleanErr) {
          console.error('Gagal membersihkan folder auth:', cleanErr);
        }
      }
    } else if (connection === 'open') {
      console.log('\n======================================================');
      console.log('🎉 WHATSAPP BOT BERHASIL TERHUBUNG & SIAP DIGUNAKAN!');
      if (sock.user) {
        console.log(`👤 Akun Bot: ${sock.user.name || 'Admin'} (${sock.user.id})`);
        if (sock.user.lid) console.log(`🆔 Akun Bot LID: ${sock.user.lid}`);
      }
      console.log('======================================================\n');
    }
  });

  // Listener Pesan Masuk
  sock.ev.on('messages.upsert', async (m) => {
    try {
      const msg = m.messages[0];
      if (!msg || !msg.message) return;

      const remoteJid = msg.key.remoteJid;
      const senderJid = msg.key.participant || remoteJid;
      const text = extractMessageText(msg);

      if (!text || !text.trim()) return;

      const trimmedText = text.trim();
      const configuredPrefix = process.env.BOT_PREFIX || '#';
      const isCmd =
        trimmedText.startsWith(configuredPrefix) ||
        trimmedText.startsWith('#') ||
        trimmedText.startsWith('.') ||
        trimmedText.startsWith('/') ||
        trimmedText.startsWith('!');

      // Hanya proses jika pesan merupakan perintah bot
      if (!isCmd) return;

      // 1. Verifikasi Keamanan Whitelist Owner (Mendukung Nomor HP, LID, dan fromMe)
      if (!isOwner(senderJid, msg, sock)) {
        console.log(`⛔ [Akses Ditolak] Perintah dari nomor/LID tak dikenal: ${senderJid} (Remote: ${remoteJid})`);
        await sock.sendMessage(
          remoteJid,
          {
            text: `⛔ *Akses Ditolak!*\nID WhatsApp Anda (\`${senderJid}\`) belum terdaftar di whitelist Owner.\n\n💡 Tambahkan ID \`${senderJid.split('@')[0]}\` ke \`OWNER_NUMBERS\` pada file \`.env\`.`,
          },
          { quoted: msg }
        );
        return;
      }

      console.log(`📩 [Pesan Masuk Owner (${senderJid})]: ${text}`);

      // 2. Kirim status mengetik (typing indicator)
      await sock.sendPresenceUpdate('composing', remoteJid);

      // 3. Proses perintah via commandHandler
      const responseText = await handleCommand(text, senderJid);

      await sock.sendPresenceUpdate('paused', remoteJid);

      // 4. Kirim balasan hasil eksekusi perintah
      if (responseText) {
        await sock.sendMessage(
          remoteJid,
          { text: responseText },
          { quoted: msg }
        );
      }
    } catch (err) {
      console.error('❌ Error memproses pesan masuk:', err);
    }
  });

  return sock;
}

// Jalankan Bot
startWhatsAppBot().catch((err) => {
  console.error('❌ Fatal error saat inisialisasi bot:', err);
});

