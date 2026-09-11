/**
 * ============================================================================
 * COMMAND HANDLER - WHATSAPP BOT ADMIN VIBETECH XYZ
 * ============================================================================
 * Menghandle parsing text pesan, validasi argumen, dan merespon WhatsApp.
 */

const productService = require('../services/productService');
const userService = require('../services/userService');
const transactionService = require('../services/transactionService');

const PREFIX = process.env.BOT_PREFIX || '#';

/**
 * Format Rupiah Helper
 */
function formatRupiah(number) {
  return 'Rp ' + (parseFloat(number) || 0).toLocaleString('id-ID');
}

/**
 * Menu Panduan Bantuan
 */
function getHelpMenu() {
  return `*🤖 VIBETECH XYZ - WHATSAPP ADMIN BOT*
====================================
Gunakan format perintah dengan awalan *${PREFIX}* dan pemisah tanda pagar *(#)*.

📦 *MANAJEMEN PRODUK:*
1️⃣ *Tambah Produk Baru:*
\`${PREFIX}tambahproduk [Nama]#[Harga]#[Stok]#[Kategori]#[Deskripsi]\`
_Contoh:_ \`${PREFIX}tambahproduk VPS Extreme#85000#15#VPS#4 CPU 8GB RAM\`

2️⃣ *Edit Harga Produk:*
\`${PREFIX}editharga [ID/Nama]#[HargaBaru]\`
_Contoh:_ \`${PREFIX}editharga VPS Starter#35000\`

3️⃣ *Edit Stok Produk:*
\`${PREFIX}editstok [ID/Nama]#[StokBaru]\`
_Contoh:_ \`${PREFIX}editstok VPS Starter#20\`

4️⃣ *Hapus Produk:*
\`${PREFIX}hapusproduk [ID/Nama]\`
_Contoh:_ \`${PREFIX}hapusproduk VPS Extreme\`

5️⃣ *Lihat Daftar Produk:*
\`${PREFIX}listproduk\`

💰 *MANAJEMEN SALDO USER:*
6️⃣ *Cek Saldo User:*
\`${PREFIX}ceksaldo [Email/Username]\`
_Contoh:_ \`${PREFIX}ceksaldo user@vibetech.xyz\`

7️⃣ *Tambah Saldo (Top-up):*
\`${PREFIX}tambahsaldo [Email/Username]#[Nominal]#[Keterangan]\`
_Contoh:_ \`${PREFIX}tambahsaldo user@vibetech.xyz#50000#Top up BCA\`

8️⃣ *Kurang / Potong Saldo:*
\`${PREFIX}kurangsaldo [Email/Username]#[Nominal]#[Keterangan]\`
_Contoh:_ \`${PREFIX}kurangsaldo user@vibetech.xyz#10000#Koreksi refund\`

👥 *INFORMASI & LAPORAN:*
9️⃣ *Daftar Pengguna:* \`${PREFIX}listuser\`
🔟 *Daftar Transaksi:* \`${PREFIX}listtransaksi\`
⚙️ *Cek Koneksi Bot:* \`${PREFIX}ping\`
====================================`;
}

/**
 * Router Utama Pemroses Perintah
 */
/**
 * Parser Fleksibel untuk Memecah Perintah dan Argumen
 * Mendukung format:
 * - #editstok VPS Starter#20
 * - #editstok#VPS Starter#20
 * - .editstok VPS Starter#20
 * - #ceksaldo user@vibetech.xyz
 */
function parseCommandInput(rawText) {
  let text = (rawText || '').trim();

  // Deteksi dan hilangkan prefix umum (#, ., /, !, dll) jika ada di awal
  const prefixMatch = text.match(/^[#./!]/);
  let detectedPrefix = '#';
  if (prefixMatch) {
    detectedPrefix = prefixMatch[0];
    text = text.slice(prefixMatch[0].length).trim();
  }

  // Jika setelah prefix masih ada tanda #
  if (text.startsWith('#')) {
    text = text.slice(1).trim();
  }

  // Cari pemisah pertama antara kata perintah dan argumen (spasi atau #)
  const firstHashIndex = text.indexOf('#');
  const firstSpaceIndex = text.indexOf(' ');

  let splitIndex = -1;
  if (firstHashIndex !== -1 && firstSpaceIndex !== -1) {
    splitIndex = Math.min(firstHashIndex, firstSpaceIndex);
  } else if (firstHashIndex !== -1) {
    splitIndex = firstHashIndex;
  } else if (firstSpaceIndex !== -1) {
    splitIndex = firstSpaceIndex;
  }

  let command = '';
  let args = [];

  if (splitIndex === -1) {
    command = text.toLowerCase();
    args = [];
  } else {
    command = text.slice(0, splitIndex).trim().toLowerCase();
    const remaining = text.slice(splitIndex + 1).trim();
    args = remaining.split('#').map((p) => p.trim()).filter((p) => p.length > 0);
  }

  return { command, args, prefix: detectedPrefix };
}

/**
 * Router Utama Pemroses Perintah
 */
/**
 * Router Utama Pemroses Perintah
 */
async function handleCommand(bodyText, senderJid) {
  let { command, args, prefix } = parseCommandInput(bodyText);

  if (!command) {
    return null;
  }

  // -------------------------------------------------------------
  // SMART COMPOUND COMMAND ROUTER
  // Menangani input seperti:
  // .edit stok ... -> .editstok ...
  // .edit harga ... -> .editharga ...
  // .tambah produk ... -> .tambahproduk ...
  // .tambah saldo ... -> .tambahsaldo ...
  // .cek saldo ... -> .ceksaldo ...
  // .hapus produk ... -> .hapusproduk ...
  // .list produk ... -> .listproduk ...
  // -------------------------------------------------------------
  if (command === 'edit' && args.length > 0) {
    const sub = args[0].toLowerCase();
    if (sub.startsWith('stok') || sub === 'stock') {
      command = 'editstok';
      args[0] = args[0].replace(/^(stok|stock)\s*/i, '').trim();
      if (!args[0] && args.length > 1) args.shift();
    } else if (sub.startsWith('harga') || sub === 'price') {
      command = 'editharga';
      args[0] = args[0].replace(/^(harga|price)\s*/i, '').trim();
      if (!args[0] && args.length > 1) args.shift();
    }
  } else if ((command === 'tambah' || command === 'add') && args.length > 0) {
    const sub = args[0].toLowerCase();
    if (sub.startsWith('produk') || sub.startsWith('product') || sub.startsWith('barang')) {
      command = 'tambahproduk';
      args[0] = args[0].replace(/^(produk|product|barang)\s*/i, '').trim();
      if (!args[0] && args.length > 1) args.shift();
    } else if (sub.startsWith('saldo') || sub.startsWith('balance') || sub.startsWith('topup')) {
      command = 'tambahsaldo';
      args[0] = args[0].replace(/^(saldo|balance|topup)\s*/i, '').trim();
      if (!args[0] && args.length > 1) args.shift();
    }
  } else if ((command === 'kurang' || command === 'potong' || command === 'tarik') && args.length > 0) {
    const sub = args[0].toLowerCase();
    if (sub.startsWith('saldo') || sub.startsWith('balance')) {
      command = 'kurangsaldo';
      args[0] = args[0].replace(/^(saldo|balance)\s*/i, '').trim();
      if (!args[0] && args.length > 1) args.shift();
    }
  } else if ((command === 'cek' || command === 'check') && args.length > 0) {
    const sub = args[0].toLowerCase();
    if (sub.startsWith('saldo') || sub.startsWith('balance')) {
      command = 'ceksaldo';
      args[0] = args[0].replace(/^(saldo|balance)\s*/i, '').trim();
      if (!args[0] && args.length > 1) args.shift();
    } else if (sub.startsWith('produk') || sub.startsWith('product')) {
      command = 'listproduk';
    } else if (sub.startsWith('user')) {
      command = 'listuser';
    }
  } else if ((command === 'list' || command === 'daftar') && args.length > 0) {
    const sub = args[0].toLowerCase();
    if (sub.startsWith('produk') || sub.startsWith('product') || sub.startsWith('barang') || sub.startsWith('katalog')) {
      command = 'listproduk';
    } else if (sub.startsWith('user') || sub.startsWith('pengguna') || sub.startsWith('member')) {
      command = 'listuser';
    } else if (sub.startsWith('transaksi') || sub.startsWith('mutasi') || sub.startsWith('trx') || sub.startsWith('tx')) {
      command = 'listtransaksi';
    }
  } else if (command === 'hapus' || command === 'delete' || command === 'del' || command === 'rm') {
    if (args.length > 0 && (args[0].toLowerCase().startsWith('produk') || args[0].toLowerCase().startsWith('product'))) {
      command = 'hapusproduk';
      args[0] = args[0].replace(/^(produk|product)\s*/i, '').trim();
      if (!args[0] && args.length > 1) args.shift();
    }
  }

  // Bersihkan argumen kosong
  args = args.filter((a) => a && a.length > 0);

  try {
    switch (command) {
      // -------------------------------------------------------------
      // BANTUAN & STATUS
      // -------------------------------------------------------------
      case 'menu':
      case 'help':
      case 'bantuan':
      case 'start':
        return getHelpMenu();

      case 'ping':
      case 'test':
      case 'status':
        return `🏓 *Pong!*\n✅ Bot WhatsApp Vibetech Admin aktif dan terhubung ke Firebase.\n⏱️ Waktu Server: ${new Date().toLocaleString('id-ID', { timeZone: 'Asia/Jakarta' })} WIB`;

      // -------------------------------------------------------------
      // MANAJEMEN PRODUK
      // -------------------------------------------------------------
      case 'tambahproduk':
      case 'addproduct':
      case 'addproduk':
      case 'tambah_produk': {
        // Format: #tambahproduk [Nama]#[Harga]#[Stok]#[Kategori]#[Deskripsi]
        const nama = args[0];
        const harga = args[1];
        const stok = args[2] || 10;
        const kategori = args[3] || 'Layanan Cloud';
        const deskripsi = args[4] || '';

        if (!nama || !harga) {
          return `❌ *Format Salah!*\nGunakan:\n\`${prefix}tambahproduk [Nama]#[Harga]#[Stok]#[Kategori]#[Deskripsi]\`\n\nContoh:\n\`${prefix}tambahproduk VPS Gaming#75000#10#VPS#RAM 4GB CPU 2 Core\``;
        }

        const result = await productService.addProduct({
          nama,
          harga,
          stok,
          kategori,
          deskripsi,
        });

        return `✅ *PRODUK BERHASIL DITAMBAHKAN!*\n====================================\n📦 *Doc ID:* \`${result.docId}\`\n🏷️ *Nama:* ${result.data.nama}\n💵 *Harga:* ${formatRupiah(result.data.harga)}\n📊 *Stok:* ${result.data.stok} unit\n📂 *Kategori:* ${result.data.kategori}\n📝 *Deskripsi:* ${result.data.deskripsi || '-'}\n====================================\n_Data telah disinkronkan ke Firestore & RTDB._`;
      }

      case 'editharga':
      case 'ubahharga':
      case 'setharga':
      case 'updateharga':
      case 'harga': {
        // Format: #editharga [ID/Nama]#[HargaBaru]
        let identifier = args[0];
        let hargaBaru = args[1];

        // Dukung input dengan spasi: .editharga VPS Starter 35000
        if (identifier && hargaBaru === undefined && identifier.includes(' ')) {
          const spaceParts = identifier.split(/\s+/);
          const lastPart = spaceParts[spaceParts.length - 1];
          if (!isNaN(lastPart)) {
            hargaBaru = lastPart;
            identifier = spaceParts.slice(0, -1).join(' ');
          }
        }

        if (!identifier || !hargaBaru) {
          return `❌ *Format Salah!*\nGunakan:\n\`${prefix}editharga [ID/Nama]#[HargaBaru]\`\n\nContoh:\n\`${prefix}editharga VPS Starter#35000\``;
        }

        const result = await productService.updateProduct(identifier, {
          harga: hargaBaru,
        });

        return `✅ *HARGA PRODUK BERHASIL DIUBAH!*\n====================================\n📦 *Doc ID:* \`${result.docId}\`\n💵 *Harga Baru:* ${formatRupiah(hargaBaru)}\n====================================`;
      }

      case 'editstok':
      case 'ubahstok':
      case 'setstok':
      case 'updatestok':
      case 'stok':
      case 'stock': {
        // Format: #editstok [ID/Nama]#[StokBaru]
        let identifier = args[0];
        let stokBaru = args[1];

        // Dukung input dengan spasi: .editstok prod_01_vps_starter 50
        if (identifier && stokBaru === undefined && identifier.includes(' ')) {
          const spaceParts = identifier.split(/\s+/);
          const lastPart = spaceParts[spaceParts.length - 1];
          if (!isNaN(lastPart)) {
            stokBaru = lastPart;
            identifier = spaceParts.slice(0, -1).join(' ');
          }
        }

        if (!identifier || stokBaru === undefined) {
          return `❌ *Format Salah!*\nGunakan:\n\`${prefix}editstok [ID/Nama]#[StokBaru]\`\n\nContoh:\n\`${prefix}editstok VPS Starter#20\``;
        }

        const result = await productService.updateProduct(identifier, {
          stok: stokBaru,
        });

        return `✅ *STOK PRODUK BERHASIL DIUBAH!*\n====================================\n📦 *Doc ID:* \`${result.docId}\`\n📊 *Stok Baru:* ${stokBaru} unit\n====================================`;
      }

      case 'hapusproduk':
      case 'deleteproduct':
      case 'delproduk':
      case 'deleteproduk':
      case 'hapus_produk':
      case 'rmproduk': {
        // Format: #hapusproduk [ID/Nama]
        const identifier = args[0];
        if (!identifier) {
          return `❌ *Format Salah!*\nGunakan:\n\`${prefix}hapusproduk [ID/Nama]\`\n\nContoh:\n\`${prefix}hapusproduk VPS Starter\``;
        }

        const result = await productService.deleteProduct(identifier);
        return `🗑️ *PRODUK TELAH DIHAPUS!*\n====================================\n📦 *Doc ID:* \`${result.docId}\`\n🏷️ *Nama:* ${result.nama}\n====================================\n_Produk dihapus dari Firestore & RTDB._`;
      }

      case 'listproduk':
      case 'produk':
      case 'daftarproduk':
      case 'katalog':
      case 'products': {
        const products = await productService.listProducts();
        if (!products.length) {
          return `📦 Belum ada produk di database Firebase.`;
        }

        let response = `📦 *KATALOG PRODUK VIBETECH XYZ* (${products.length} item)\n====================================\n`;
        products.forEach((p, idx) => {
          response += `*${idx + 1}. ${p.nama || p.id}*\n`;
          response += `   🆔 ID: \`${p.doc_id || p.id}\`\n`;
          response += `   💵 Harga: ${formatRupiah(p.harga)}\n`;
          response += `   📊 Stok: ${p.stok ?? 0} | 📂 Kategori: ${p.kategori || '-'}\n\n`;
        });
        response += `====================================\n_Gunakan \`${prefix}editharga\` atau \`${prefix}editstok\` untuk modifikasi._`;
        return response;
      }

      // -------------------------------------------------------------
      // MANAJEMEN SALDO PENGGUNA
      // -------------------------------------------------------------
      case 'ceksaldo':
      case 'saldo':
      case 'mysaldo':
      case 'usersaldo': {
        const identifier = args[0];
        if (!identifier) {
          return `❌ *Format Salah!*\nGunakan:\n\`${prefix}ceksaldo [Email/Username]\`\n\nContoh:\n\`${prefix}ceksaldo user@vibetech.xyz\``;
        }

        const user = await userService.findUser(identifier);
        if (!user) {
          return `❌ Pengguna dengan identifier *'${identifier}'* tidak ditemukan di Firebase!`;
        }

        return `👤 *INFORMASI PENGGUNA*\n====================================\n🆔 *Doc ID:* \`${user.docId}\`\n📧 *Email:* ${user.email || '-'}\n👤 *Username:* ${user.username || user.nama || '-'}\n💰 *Saldo Saat Ini:* *${formatRupiah(user.saldo || 0)}*\n🛡️ *Role:* ${user.role || 'user'}\n====================================`;
      }

      case 'tambahsaldo':
      case 'topup':
      case 'isisaldo':
      case 'isi_saldo':
      case 'addsaldo': {
        // Format: #tambahsaldo [Email/Username]#[Nominal]#[Keterangan]
        let identifier = args[0];
        let nominal = args[1];
        let keterangan = args[2] || 'Top Up Manual via WhatsApp Owner';

        // Dukung input dengan spasi: .tambahsaldo user@vibetech.xyz 50000
        if (identifier && nominal === undefined && identifier.includes(' ')) {
          const spaceParts = identifier.split(/\s+/);
          const lastPart = spaceParts[spaceParts.length - 1];
          if (!isNaN(lastPart)) {
            nominal = lastPart;
            identifier = spaceParts.slice(0, -1).join(' ');
          }
        }

        if (!identifier || !nominal) {
          return `❌ *Format Salah!*\nGunakan:\n\`${prefix}tambahsaldo [Email/Username]#[Nominal]#[Keterangan]\`\n\nContoh:\n\`${prefix}tambahsaldo user@vibetech.xyz#50000#Transfer BCA\``;
        }

        const res = await userService.addBalance(identifier, nominal, keterangan);
        return `✅ *TOP UP SALDO BERHASIL!*\n====================================\n🧾 *Invoice:* \`${res.invoiceNo}\`\n👤 *User:* ${res.nama} (${res.email})\n➕ *Nominal Ditambah:* +${formatRupiah(res.addedAmount)}\n📉 *Saldo Sebelumnya:* ${formatRupiah(res.oldBalance)}\n💰 *SALDO SEKARANG:* *${formatRupiah(res.newBalance)}*\n📝 *Catatan:* ${keterangan}\n====================================\n_Tercatat otomatis di mutasi transaksi Firebase!_`;
      }

      case 'kurangsaldo':
      case 'potongsaldo':
      case 'tariksaldo':
      case 'minussaldo':
      case 'deductsaldo': {
        // Format: #kurangsaldo [Email/Username]#[Nominal]#[Keterangan]
        let identifier = args[0];
        let nominal = args[1];
        let keterangan = args[2] || 'Koreksi Saldo via WhatsApp Owner';

        if (identifier && nominal === undefined && identifier.includes(' ')) {
          const spaceParts = identifier.split(/\s+/);
          const lastPart = spaceParts[spaceParts.length - 1];
          if (!isNaN(lastPart)) {
            nominal = lastPart;
            identifier = spaceParts.slice(0, -1).join(' ');
          }
        }

        if (!identifier || !nominal) {
          return `❌ *Format Salah!*\nGunakan:\n\`${prefix}kurangsaldo [Email/Username]#[Nominal]#[Keterangan]\`\n\nContoh:\n\`${prefix}kurangsaldo user@vibetech.xyz#10000#Koreksi overpayment\``;
        }

        const res = await userService.deductBalance(identifier, nominal, keterangan);
        return `✅ *PEMOTONGAN SALDO BERHASIL!*\n====================================\n🧾 *Invoice:* \`${res.invoiceNo}\`\n👤 *User:* ${res.nama} (${res.email})\n➖ *Nominal Dipotong:* -${formatRupiah(res.deductedAmount)}\n📈 *Saldo Sebelumnya:* ${formatRupiah(res.oldBalance)}\n💰 *SALDO SEKARANG:* *${formatRupiah(res.newBalance)}*\n📝 *Catatan:* ${keterangan}\n====================================`;
      }

      case 'listuser':
      case 'users':
      case 'daftaruser':
      case 'user': {
        const users = await userService.listUsers(15);
        if (!users.length) {
          return `👥 Belum ada pengguna terdaftar di Firebase.`;
        }

        let response = `👥 *DAFTAR PENGGUNA VIBETECH* (${users.length} user)\n====================================\n`;
        users.forEach((u, idx) => {
          response += `*${idx + 1}. ${u.username}* (${u.role})\n`;
          response += `   📧 ${u.email}\n`;
          response += `   💰 Saldo: *${formatRupiah(u.saldo)}*\n\n`;
        });
        response += `====================================`;
        return response;
      }

      case 'listtransaksi':
      case 'transaksi':
      case 'daftartransaksi':
      case 'mutasi':
      case 'riwayat':
      case 'history': {
        const txs = await transactionService.getRecentTransactions(8);
        if (!txs.length) {
          return `🧾 Belum ada riwayat transaksi di Firebase.`;
        }

        let response = `🧾 *RIWAYAT TRANSAKSI TERAKHIR*\n====================================\n`;
        txs.forEach((tx, idx) => {
          response += `*${idx + 1}. ${tx.nama_produk || 'Transaksi'}*\n`;
          response += `   🧾 \`${tx.invoice_no || tx.id}\`\n`;
          response += `   👤 User: ${tx.user_email || '-'}\n`;
          response += `   💵 Total: ${formatRupiah(tx.total_harga)} | Status: *${tx.status || 'Success'}*\n`;
          response += `   ⏱️ ${tx.tanggal ? new Date(tx.tanggal).toLocaleString('id-ID') : '-'}\n\n`;
        });
        response += `====================================`;
        return response;
      }

      default:
        return `⚠️ Perintah *${prefix}${command}* tidak dikenali.\nKetik \`${prefix}menu\` untuk melihat daftar seluruh perintah yang tersedia.`;
    }
  } catch (error) {
    console.error(`[Command Error: ${command}]:`, error);
    return `❌ *TERJADI KESALAHAN!*\n\n⚠️ Detail: ${error.message || error}\n\nSilakan periksa kembali input data Anda atau coba beberapa saat lagi.`;
  }
}

module.exports = {
  handleCommand,
  getHelpMenu,
};


