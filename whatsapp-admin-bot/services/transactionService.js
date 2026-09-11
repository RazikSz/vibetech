/**
 * ============================================================================
 * TRANSACTION SERVICE (FIREBASE ADMIN) - VIBETECH XYZ
 * ============================================================================
 * Layanan pencatatan invoice transaksi / mutasi saldo ke Cloud Firestore & RTDB.
 */

const { getFirestore, getRTDB } = require('../config/firebase');

const COLLECTION_NAME = 'transactions';

/**
 * Membuat Invoice No Unik
 */
function generateInvoiceNo(prefix = 'TOPUP') {
  const timestamp = Date.now().toString().slice(-6);
  const random = Math.floor(1000 + Math.random() * 9000);
  return `INV-${prefix}-${timestamp}${random}`;
}

/**
 * 1. Simpan Catatan Transaksi Baru (Top Up / Potong Saldo / Beli)
 */
async function recordTransaction({
  userEmail,
  namaProduk,
  kategori = 'Top Up',
  totalHarga,
  jumlah = 1,
  metodePembayaran = 'WhatsApp Admin',
  status = 'Success',
  keterangan = '',
}) {
  const db = getFirestore();
  const rtdb = getRTDB();

  const invoiceNo = generateInvoiceNo(kategori === 'Top Up' ? 'TOPUP' : 'ADJ');
  const nowIso = new Date().toISOString();

  const transactionData = {
    invoice_no: invoiceNo,
    user_email: (userEmail || '').trim().toLowerCase(),
    nama_produk: namaProduk || 'Top Up Saldo Akun',
    kategori: kategori,
    total_harga: parseFloat(totalHarga) || 0,
    jumlah: parseInt(jumlah, 10) || 1,
    metode_pembayaran: metodePembayaran,
    status: status,
    keterangan: keterangan,
    tanggal: nowIso,
    created_at: nowIso,
    updated_at: nowIso,
  };

  // Simpan ke Firestore
  await db.collection(COLLECTION_NAME).doc(invoiceNo).set(transactionData, { merge: true });

  // Simpan ke Realtime Database
  await rtdb.ref(`${COLLECTION_NAME}/${invoiceNo}`).set(transactionData);

  return transactionData;
}

/**
 * 2. Ambil Transaksi Terakhir (Firestore + RTDB Fallback)
 */
async function getRecentTransactions(limit = 10) {
  const db = getFirestore();
  const rtdb = getRTDB();
  const results = [];

  // 1. Coba baca dari Firestore
  try {
    const snapshot = await db
      .collection(COLLECTION_NAME)
      .orderBy('created_at', 'desc')
      .limit(limit)
      .get();

    snapshot.forEach((doc) => {
      results.push({ id: doc.id, ...doc.data() });
    });
  } catch (err) {
    console.warn('[transactionService] Firestore getRecentTransactions notice:', err.message);
  }

  // 2. Fallback baca dari RTDB
  if (results.length === 0) {
    try {
      const rtdbSnap = await rtdb.ref(COLLECTION_NAME).limitToLast(limit).once('value');
      const val = rtdbSnap.val();
      if (val) {
        Object.entries(val).forEach(([key, tx]) => {
          if (tx && typeof tx === 'object') {
            results.push({ id: key, ...tx });
          }
        });
        results.reverse(); // Urutkan terbaru di atas
      }
    } catch (rtdbErr) {
      console.error('[transactionService] RTDB getRecentTransactions error:', rtdbErr.message);
    }
  }

  return results;
}

module.exports = {
  recordTransaction,
  getRecentTransactions,
};
