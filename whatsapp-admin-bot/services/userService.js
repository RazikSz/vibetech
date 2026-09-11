/**
 * ============================================================================
 * USER & BALANCE SERVICE (FIREBASE ADMIN) - VIBETECH XYZ
 * ============================================================================
 * Layanan manajemen saldo pengguna dan sinkronisasi akun ke Firestore & RTDB.
 */

const { getFirestore, getRTDB } = require('../config/firebase');
const { recordTransaction } = require('./transactionService');

const COLLECTION_NAME = 'users';

/**
 * 1. Cari Akun User berdasarkan Email, Username, atau Doc ID
 */
/**
 * 1. Cari Akun User berdasarkan Email, Username, atau Doc ID
 */
async function findUser(identifier) {
  const db = getFirestore();
  const rtdb = getRTDB();
  const cleanId = (identifier || '').trim().toLowerCase();

  // 1. Coba dari Firestore
  try {
    const directDoc = await db.collection(COLLECTION_NAME).doc(cleanId).get();
    if (directDoc.exists) {
      return { docId: directDoc.id, ...directDoc.data() };
    }

    const emailSnap = await db
      .collection(COLLECTION_NAME)
      .where('email', '==', cleanId)
      .limit(1)
      .get();

    if (!emailSnap.empty) {
      const doc = emailSnap.docs[0];
      return { docId: doc.id, ...doc.data() };
    }

    const userSnap = await db
      .collection(COLLECTION_NAME)
      .where('username', '==', cleanId)
      .limit(1)
      .get();

    if (!userSnap.empty) {
      const doc = userSnap.docs[0];
      return { docId: doc.id, ...doc.data() };
    }

    const allUsersSnap = await db.collection(COLLECTION_NAME).get();
    let found = null;
    allUsersSnap.forEach((doc) => {
      const data = doc.data();
      const email = (data.email || '').toLowerCase();
      const username = (data.username || '').toLowerCase();
      const nama = (data.nama || '').toLowerCase();

      if (
        email === cleanId ||
        username === cleanId ||
        nama === cleanId ||
        doc.id.toLowerCase().includes(cleanId)
      ) {
        found = { docId: doc.id, ...data };
      }
    });

    if (found) return found;
  } catch (err) {
    console.warn('[userService] Firestore findUser error, beralih ke RTDB:', err.message);
  }

  // 2. Fallback baca dari Realtime Database
  try {
    const rtdbSnap = await rtdb.ref(COLLECTION_NAME).once('value');
    const val = rtdbSnap.val();
    if (val) {
      for (const [key, item] of Object.entries(val)) {
        if (!item || typeof item !== 'object') continue;
        const email = (item.email || '').toLowerCase();
        const username = (item.username || '').toLowerCase();
        const nama = (item.nama || '').toLowerCase();
        const keyLower = key.toLowerCase();

        if (
          keyLower === cleanId ||
          email === cleanId ||
          username === cleanId ||
          nama === cleanId ||
          keyLower.includes(cleanId)
        ) {
          return { docId: key, ...item };
        }
      }
    }
  } catch (rtdbErr) {
    console.error('[userService] RTDB findUser error:', rtdbErr.message);
  }

  return null;
}

/**
 * 2. Tambah Saldo User (Top Up)
 */
async function addBalance(identifier, amount, note = 'Top Up Saldo via WhatsApp Owner') {
  const numAmount = parseFloat(amount);
  if (isNaN(numAmount) || numAmount <= 0) {
    throw new Error('Nominal saldo harus berupa angka lebih dari 0!');
  }

  const user = await findUser(identifier);
  if (!user) {
    throw new Error(`Pengguna '${identifier}' tidak ditemukan di database!`);
  }

  const db = getFirestore();
  const rtdb = getRTDB();
  const userDocRef = db.collection(COLLECTION_NAME).doc(user.docId);
  const nowIso = new Date().toISOString();

  let oldBalance = parseFloat(user.saldo || 0);
  let newBalance = oldBalance + numAmount;

  // Coba update Firestore
  try {
    await db.runTransaction(async (transaction) => {
      const docSnapshot = await transaction.get(userDocRef);
      if (docSnapshot.exists) {
        const currentData = docSnapshot.data();
        oldBalance = parseFloat(currentData.saldo || 0);
        newBalance = oldBalance + numAmount;
        transaction.update(userDocRef, {
          saldo: newBalance,
          updated_at: nowIso,
        });
      } else {
        transaction.set(userDocRef, {
          ...user,
          saldo: newBalance,
          updated_at: nowIso,
        });
      }
    });
  } catch (fsErr) {
    console.warn('[userService] Firestore transaction notice:', fsErr.message);
  }

  // Update ke RTDB
  await rtdb.ref(`${COLLECTION_NAME}/${user.docId}`).update({
    saldo: newBalance,
    updated_at: nowIso,
  });

  // Catat riwayat transaksi mutasi
  const tx = await recordTransaction({
    userEmail: user.email || identifier,
    namaProduk: `Top Up Saldo (+Rp ${numAmount.toLocaleString('id-ID')})`,
    kategori: 'Top Up',
    totalHarga: numAmount,
    jumlah: 1,
    metodePembayaran: 'WhatsApp Admin',
    status: 'Success',
    keterangan: note,
  });

  return {
    docId: user.docId,
    email: user.email || user.username,
    nama: user.nama || user.username,
    oldBalance,
    newBalance,
    addedAmount: numAmount,
    invoiceNo: tx.invoice_no,
  };
}

/**
 * 3. Kurangi / Potong Saldo User (Koreksi / Penarikan)
 */
async function deductBalance(identifier, amount, note = 'Koreksi Saldo via WhatsApp Owner') {
  const numAmount = parseFloat(amount);
  if (isNaN(numAmount) || numAmount <= 0) {
    throw new Error('Nominal saldo harus berupa angka lebih dari 0!');
  }

  const user = await findUser(identifier);
  if (!user) {
    throw new Error(`Pengguna '${identifier}' tidak ditemukan di database!`);
  }

  const db = getFirestore();
  const rtdb = getRTDB();
  const userDocRef = db.collection(COLLECTION_NAME).doc(user.docId);
  const nowIso = new Date().toISOString();

  let oldBalance = parseFloat(user.saldo || 0);

  if (oldBalance < numAmount) {
    throw new Error(`Saldo pengguna tidak mencukupi! (Saldo saat ini: Rp ${oldBalance.toLocaleString('id-ID')})`);
  }

  let newBalance = oldBalance - numAmount;

  try {
    await db.runTransaction(async (transaction) => {
      const docSnapshot = await transaction.get(userDocRef);
      if (docSnapshot.exists) {
        const currentData = docSnapshot.data();
        oldBalance = parseFloat(currentData.saldo || 0);
        if (oldBalance < numAmount) {
          throw new Error(`Saldo pengguna tidak mencukupi! (Saldo saat ini: Rp ${oldBalance.toLocaleString('id-ID')})`);
        }
        newBalance = oldBalance - numAmount;
        transaction.update(userDocRef, {
          saldo: newBalance,
          updated_at: nowIso,
        });
      }
    });
  } catch (fsErr) {
    console.warn('[userService] Firestore deduct notice:', fsErr.message);
  }

  // Update ke RTDB
  await rtdb.ref(`${COLLECTION_NAME}/${user.docId}`).update({
    saldo: newBalance,
    updated_at: nowIso,
  });

  // Catat riwayat transaksi mutasi
  const tx = await recordTransaction({
    userEmail: user.email || identifier,
    namaProduk: `Pemotongan Saldo (-Rp ${numAmount.toLocaleString('id-ID')})`,
    kategori: 'Penyesuaian Saldo',
    totalHarga: numAmount,
    jumlah: 1,
    metodePembayaran: 'WhatsApp Admin',
    status: 'Success',
    keterangan: note,
  });

  return {
    docId: user.docId,
    email: user.email || user.username,
    nama: user.nama || user.username,
    oldBalance,
    newBalance,
    deductedAmount: numAmount,
    invoiceNo: tx.invoice_no,
  };
}

/**
 * 4. Ambil Daftar Ringkasan Pengguna
 */
async function listUsers(limit = 15) {
  const db = getFirestore();
  const rtdb = getRTDB();
  const users = [];

  // 1. Coba baca dari Firestore
  try {
    const snapshot = await db.collection(COLLECTION_NAME).limit(limit).get();
    snapshot.forEach((doc) => {
      const data = doc.data();
      users.push({
        docId: doc.id,
        email: data.email || '-',
        username: data.username || data.nama || '-',
        saldo: parseFloat(data.saldo || 0),
        role: data.role || 'user',
      });
    });
  } catch (err) {
    console.warn('[userService] Firestore listUsers error, beralih ke RTDB:', err.message);
  }

  // 2. Fallback baca dari RTDB jika kosong
  if (users.length === 0) {
    try {
      const rtdbSnap = await rtdb.ref(COLLECTION_NAME).limitToFirst(limit).once('value');
      const val = rtdbSnap.val();
      if (val) {
        Object.entries(val).forEach(([key, data]) => {
          if (data && typeof data === 'object') {
            users.push({
              docId: key,
              email: data.email || '-',
              username: data.username || data.nama || '-',
              saldo: parseFloat(data.saldo || 0),
              role: data.role || 'user',
            });
          }
        });
      }
    } catch (rtdbErr) {
      console.error('[userService] RTDB listUsers error:', rtdbErr.message);
    }
  }

  return users;
}

module.exports = {
  findUser,
  addBalance,
  deductBalance,
  listUsers,
};
