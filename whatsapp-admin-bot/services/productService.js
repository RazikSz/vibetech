/**
 * ============================================================================
 * PRODUCT SERVICE (FIREBASE ADMIN) - VIBETECH XYZ
 * ============================================================================
 * Layanan CRUD data produk sinkron ke Cloud Firestore & Firebase RTDB.
 */

const { getFirestore, getRTDB } = require('../config/firebase');

const COLLECTION_NAME = 'products';

const OFFICIAL_CATALOG_ORDER = {
  'vps starter': 1,
  'vps basic': 2,
  'vps pro': 3,
  'vps enterprise': 4,
  'panel hosting 1gb': 5,
  'panel hosting 2gb': 6,
  'panel hosting 4gb': 7,
  'panel hosting unlimited': 8,
  'bot whatsapp basic': 9,
  'bot whatsapp pro': 10,
  'bot whatsapp enterprise': 11,
};

/**
 * Format ID Dokumen produk yang konsisten dengan Flutter Client
 */
function resolveProductDocId(nama, orderNum) {
  const sanitized = (nama || 'product')
    .trim()
    .toLowerCase()
    .replace(/[/\\#?[\]\.\$\s]/g, '_');

  const order = orderNum || OFFICIAL_CATALOG_ORDER[nama.toLowerCase()];
  if (order && !isNaN(order)) {
    const orderInt = parseInt(order, 10);
    const prefix = orderInt < 10 ? `0${orderInt}` : `${orderInt}`;
    return `prod_${prefix}_${sanitized}`;
  }
  return `prod_${sanitized}`;
}

/**
 * 1. Tambah Produk Baru
 */
async function addProduct({ nama, harga, stok, kategori, deskripsi, diskon = 0, no = null }) {
  const db = getFirestore();
  const rtdb = getRTDB();

  if (!nama || !harga) {
    throw new Error('Nama produk dan harga wajib diisi!');
  }

  const numHarga = parseFloat(harga) || 0;
  const numStok = parseInt(stok, 10) || 0;
  const numDiskon = parseFloat(diskon) || 0;
  const docId = resolveProductDocId(nama, no);
  const nowIso = new Date().toISOString();

  const productData = {
    doc_id: docId,
    nama: nama.trim(),
    harga: numHarga,
    stok: numStok,
    kategori: (kategori || 'Layanan').trim(),
    deskripsi: (deskripsi || '').trim(),
    diskon: numDiskon,
    is_active: 1,
    no: no ? parseInt(no, 10) : (OFFICIAL_CATALOG_ORDER[nama.toLowerCase()] || 99),
    urutan: no ? parseInt(no, 10) : (OFFICIAL_CATALOG_ORDER[nama.toLowerCase()] || 99),
    created_at: nowIso,
    updated_at: nowIso,
  };

  // Simpan ke Firestore
  await db.collection(COLLECTION_NAME).doc(docId).set(productData, { merge: true });

  // Simpan ke Realtime Database
  await rtdb.ref(`${COLLECTION_NAME}/${docId}`).set(productData);

  return { docId, data: productData };
}

/**
 * 2. Cari Dokumen Produk berdasarkan DocID atau Nama
 */
/**
 * 2. Cari Dokumen Produk berdasarkan DocID atau Nama
 */
async function findProduct(identifier) {
  const db = getFirestore();
  const rtdb = getRTDB();
  const cleanId = (identifier || '').trim();

  // 1. Coba dari Firestore
  try {
    const directDoc = await db.collection(COLLECTION_NAME).doc(cleanId).get();
    if (directDoc.exists) {
      return { id: directDoc.id, ...directDoc.data() };
    }

    const snapshot = await db.collection(COLLECTION_NAME).get();
    let found = null;
    snapshot.forEach((doc) => {
      const data = doc.data();
      const nama = (data.nama || '').toLowerCase();
      const search = cleanId.toLowerCase();
      if (doc.id.toLowerCase() === search || nama.includes(search)) {
        found = { id: doc.id, ...data };
      }
    });

    if (found) return found;
  } catch (err) {
    console.warn('[productService] Firestore query error, fallback ke RTDB:', err.message);
  }

  // 2. Fallback baca dari Realtime Database
  try {
    const rtdbSnap = await rtdb.ref(COLLECTION_NAME).once('value');
    const val = rtdbSnap.val();
    if (val) {
      for (const [key, item] of Object.entries(val)) {
        const nama = (item.nama || '').toLowerCase();
        const search = cleanId.toLowerCase();
        if (key.toLowerCase() === search || nama.includes(search)) {
          return { id: key, ...item };
        }
      }
    }
  } catch (rtdbErr) {
    console.error('[productService] RTDB fallback error:', rtdbErr.message);
  }

  return null;
}

/**
 * 3. Update Field Produk (Harga, Stok, Deskripsi, dll)
 */
async function updateProduct(identifier, updates) {
  const db = getFirestore();
  const rtdb = getRTDB();

  const existing = await findProduct(identifier);
  if (!existing) {
    throw new Error(`Produk '${identifier}' tidak ditemukan di database!`);
  }

  const docId = existing.doc_id || existing.id;
  const nowIso = new Date().toISOString();

  const cleanUpdates = {
    ...updates,
    updated_at: nowIso,
  };

  if (cleanUpdates.harga !== undefined) cleanUpdates.harga = parseFloat(cleanUpdates.harga);
  if (cleanUpdates.stok !== undefined) cleanUpdates.stok = parseInt(cleanUpdates.stok, 10);
  if (cleanUpdates.diskon !== undefined) cleanUpdates.diskon = parseFloat(cleanUpdates.diskon);

  // Update Firestore
  try {
    await db.collection(COLLECTION_NAME).doc(docId).update(cleanUpdates);
  } catch (e) {
    console.warn('[productService] Gagal update Firestore, tetap lanjut update RTDB:', e.message);
  }

  // Update RTDB
  await rtdb.ref(`${COLLECTION_NAME}/${docId}`).update(cleanUpdates);

  return { docId, updated: cleanUpdates };
}

/**
 * 4. Hapus Produk
 */
async function deleteProduct(identifier) {
  const db = getFirestore();
  const rtdb = getRTDB();

  const existing = await findProduct(identifier);
  if (!existing) {
    throw new Error(`Produk '${identifier}' tidak ditemukan di database!`);
  }

  const docId = existing.doc_id || existing.id;

  // Hapus dari Firestore
  try {
    await db.collection(COLLECTION_NAME).doc(docId).delete();
  } catch (e) {
    console.warn('[productService] Gagal delete Firestore, tetap lanjut delete RTDB:', e.message);
  }

  // Hapus dari RTDB
  await rtdb.ref(`${COLLECTION_NAME}/${docId}`).remove();

  return { docId, nama: existing.nama };
}

/**
 * 5. Ambil Daftar Semua Produk (Dengan Sinkronisasi Firestore & RTDB Fallback)
 */
async function listProducts() {
  const db = getFirestore();
  const rtdb = getRTDB();
  const products = [];

  // 1. Coba baca dari Firestore
  try {
    const snapshot = await db.collection(COLLECTION_NAME).get();
    snapshot.forEach((doc) => {
      products.push({ id: doc.id, ...doc.data() });
    });
  } catch (err) {
    console.warn(`[productService] Firestore listProducts error: ${err.message}. Beralih ke Realtime Database.`);
  }

  // 2. Jika Firestore kosong atau bermasalah, baca dari Realtime Database
  if (products.length === 0) {
    try {
      const rtdbSnap = await rtdb.ref(COLLECTION_NAME).once('value');
      const val = rtdbSnap.val();
      if (val) {
        Object.entries(val).forEach(([key, item]) => {
          if (item && typeof item === 'object') {
            products.push({ id: key, ...item });
          }
        });
      }
    } catch (rtdbErr) {
      console.error('[productService] RTDB listProducts error:', rtdbErr.message);
    }
  }

  // Urutkan berdasarkan nomor urut katalog
  products.sort((a, b) => (a.urutan || a.no || 99) - (b.urutan || b.no || 99));

  return products;
}

module.exports = {
  addProduct,
  findProduct,
  updateProduct,
  deleteProduct,
  listProducts,
};
