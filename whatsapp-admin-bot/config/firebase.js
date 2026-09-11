/**
 * ============================================================================
 * FIREBASE ADMIN INITIALIZATION - VIBETECH XYZ
 * ============================================================================
 * Menginisialisasi koneksi Firebase Admin SDK ke Firestore dan Realtime Database.
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

const { getFirestore } = require('firebase-admin/firestore');

let isInitialized = false;
let firestoreInstance = null;
let rtdbInstance = null;

function initFirebase() {
  if (isInitialized && firestoreInstance && rtdbInstance) {
    return {
      admin,
      db: firestoreInstance,
      rtdb: rtdbInstance,
    };
  }

  const serviceAccountPath = path.resolve(
    __dirname,
    '..',
    process.env.FIREBASE_SERVICE_ACCOUNT || 'serviceAccountKey.json'
  );

  if (!fs.existsSync(serviceAccountPath)) {
    console.error(`\n❌ [Firebase Config Error]: File service account tidak ditemukan di: ${serviceAccountPath}`);
    console.error(`👉 Silakan unduh file serviceAccountKey.json dari Firebase Console -> Project Settings -> Service Accounts -> Generate New Private Key, lalu letakkan di folder 'whatsapp-admin-bot/serviceAccountKey.json'.\n`);
    throw new Error('Service account key file missing.');
  }

  const serviceAccount = require(serviceAccountPath);

  const app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: process.env.FIREBASE_RTDB_URL || 'https://vibetech-xyz-default-rtdb.asia-southeast1.firebasedatabase.app',
  });

  const customDatabaseId = process.env.FIREBASE_DATABASE_ID || 'vibetech-xyz';

  // Inisialisasi Firestore dengan Database ID kustom atau fallback ke default
  try {
    firestoreInstance = getFirestore(app, customDatabaseId);
    console.log(`✅ [Firebase Admin] Terhubung ke Firestore Database: '${customDatabaseId}'`);
  } catch (err) {
    console.warn(`⚠️ [Firebase Admin] Gagal terhubung ke database '${customDatabaseId}', mencoba fallback default:`, err.message);
    try {
      firestoreInstance = getFirestore(app);
    } catch (_) {
      firestoreInstance = admin.firestore();
    }
  }

  rtdbInstance = admin.database();

  isInitialized = true;
  console.log('✅ [Firebase Admin] Berhasil terhubung ke Firebase Realtime Database!');

  return {
    admin,
    db: firestoreInstance,
    rtdb: rtdbInstance,
  };
}

module.exports = {
  initFirebase,
  getFirestore: () => {
    if (!firestoreInstance) initFirebase();
    return firestoreInstance;
  },
  getRTDB: () => {
    if (!rtdbInstance) initFirebase();
    return rtdbInstance;
  },
  admin,
};
