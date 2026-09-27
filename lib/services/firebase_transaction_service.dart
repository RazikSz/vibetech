import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/firebase_auth_token_service.dart';

/// ============================================================================
/// FIREBASE TRANSACTION SERVICE - VIBETECH XYZ
/// ============================================================================
/// Layanan cloud database ganda untuk menyimpan dan menyinkronkan data transaksi ke:
/// 1. Firebase Realtime Database (via SDK + HTTP REST API Fallback)
/// 2. Google Cloud Firestore
class FirebaseTransactionService {
  static final FirebaseTransactionService instance =
      FirebaseTransactionService._init();

  FirebaseTransactionService._init();

  static const String rtdbBaseUrl =
      'https://vibetech-xyz-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String collectionName = 'transactions';

  /// Helper untuk membangun URI RTDB terautentikasi transaksi (mencegah 401 Permission Denied)
  static Future<Uri> buildTxRtdbUri([String? docKey]) async {
    final token = await FirebaseAuthTokenService.instance.getIdToken();
    final authParam = (token != null && token.isNotEmpty) ? '?auth=$token' : '';
    if (docKey != null && docKey.isNotEmpty) {
      final clean = docKey.endsWith('.json') ? docKey : '$docKey.json';
      return Uri.parse('$rtdbBaseUrl/$collectionName/$clean$authParam');
    }
    return Uri.parse('$rtdbBaseUrl/$collectionName.json$authParam');
  }

  /// Helper untuk membangun URI RTDB terautentikasi layanan aktif (mencegah 401 Permission Denied)
  static Future<Uri> buildServiceRtdbUri(String col, [String? docKey]) async {
    final token = await FirebaseAuthTokenService.instance.getIdToken();
    final authParam = (token != null && token.isNotEmpty) ? '?auth=$token' : '';
    if (docKey != null && docKey.isNotEmpty) {
      final clean = docKey.endsWith('.json') ? docKey : '$docKey.json';
      return Uri.parse('$rtdbBaseUrl/$col/$clean$authParam');
    }
    return Uri.parse('$rtdbBaseUrl/$col.json$authParam');
  }

  /// Referensi Firebase Realtime Database
  DatabaseReference get _rtdbRef {
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: rtdbBaseUrl,
      ).ref(collectionName);
    } catch (_) {
      return FirebaseDatabase.instance.ref(collectionName);
    }
  }

  /// Referensi Firebase Cloud Firestore
  CollectionReference<Map<String, dynamic>> get _firestoreRef =>
      FirebaseFirestore.instance.collection(collectionName);

  /// Menyimpan atau memperbarui data transaksi ke Firebase (RTDB & Firestore)
  Future<String?> saveTransactionToFirebase(
      Map<String, dynamic> transactionData) async {
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(transactionData);

    // Normalisasi tipe data
    if (data['total_harga'] != null) {
      data['total_harga'] = (data['total_harga'] as num).toDouble();
    }
    if (data['jumlah'] != null) {
      data['jumlah'] = (data['jumlah'] as num).toInt();
    }

    final String? invoiceNo = data['invoice_no']?.toString().trim();
    if (invoiceNo == 'INV-VIBETECH-INIT' ||
        invoiceNo == 'TX_INIT' ||
        (invoiceNo != null &&
            (invoiceNo.contains('test_') || invoiceNo.contains('mock_')))) {
      debugPrint(
          '[FirebaseTransactionService] Transaksi dummy/test diabaikan dari Firebase: $invoiceNo');
      return invoiceNo;
    }

    final String docId = (invoiceNo != null && invoiceNo.isNotEmpty)
        ? invoiceNo.replaceAll(RegExp(r'[/\\#?\[\]\.\$]'), '_')
        : 'TX_${DateTime.now().millisecondsSinceEpoch}';

    data['id_ref'] = docId;
    final nowIso = DateTime.now().toIso8601String();
    data['updated_at'] = nowIso;
    if (!data.containsKey('created_at') || data['created_at'] == null) {
      data['created_at'] = nowIso;
    }

    // --- 1. SIMPAN KE REALTIME DATABASE VIA HTTP REST API (GARANSI UTAMA DI SEMUA OS) ---
    try {
      final uri = await buildTxRtdbUri('$docId.json');
      final response = await http
          .put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        debugPrint(
            '[FirebaseTransactionService] HTTP REST RTDB simpan sukses: $docId');
      } else {
        debugPrint(
            '[FirebaseTransactionService] HTTP REST RTDB gagal status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (httpError) {
      debugPrint(
          '[FirebaseTransactionService] HTTP REST RTDB Exception: $httpError');
    }

    // --- 2. SIMPAN KE SDK REALTIME DATABASE ---
    try {
      await _rtdbRef.child(docId).set(data).timeout(const Duration(seconds: 3));
      debugPrint('[FirebaseTransactionService] SDK RTDB simpan sukses: $docId');
    } catch (sdkError) {
      debugPrint('[FirebaseTransactionService] SDK RTDB info: $sdkError');
    }

    // --- 3. SIMPAN KE CLOUD FIRESTORE ---
    try {
      final firestoreData = Map<String, dynamic>.from(data);
      firestoreData['updated_at'] = FieldValue.serverTimestamp();
      if (firestoreData['created_at'] is String) {
        firestoreData['created_at'] = FieldValue.serverTimestamp();
      }
      await _firestoreRef
          .doc(docId)
          .set(firestoreData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 3));
      debugPrint(
          '[FirebaseTransactionService] Firestore simpan sukses: $docId');
    } catch (e) {
      debugPrint('[FirebaseTransactionService] Firestore sync info: $e');
    }

    return docId;
  }

  /// Memperbarui data transaksi di Firebase
  /// Memperbarui data transaksi di Firebase (RTDB & Firestore)
  Future<bool> updateTransactionInFirebase({
    String? invoiceNo,
    int? localId,
    String? namaProduk,
    String? userEmail,
    required Map<String, dynamic> updatedData,
  }) async {
    final Map<String, dynamic> data = Map<String, dynamic>.from(updatedData);
    final String? newInv = data['invoice_no']?.toString().trim();
    final String? oldInv = invoiceNo?.trim();
    final String targetKey = (newInv != null && newInv.isNotEmpty)
        ? _sanitizeKey(newInv)
        : (oldInv != null && oldInv.isNotEmpty)
            ? _sanitizeKey(oldInv)
            : 'TX_${DateTime.now().millisecondsSinceEpoch}';

    data['id_ref'] = targetKey;
    final nowIso = DateTime.now().toIso8601String();
    data['updated_at'] = nowIso;

    final keysToUpdate = <String>{targetKey};
    if (oldInv != null && oldInv.isNotEmpty) {
      keysToUpdate.add(_sanitizeKey(oldInv));
    }

    // Cari key di RTDB yang cocok dengan invoice_no, localId, atau nama_produk + user_email
    try {
      final uri = await buildTxRtdbUri();
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
        final dynamic decoded = jsonDecode(res.body);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final v = entry.value;
            if (v is Map) {
              final vInv = v['invoice_no']?.toString().toLowerCase();
              final vRef = v['id_ref']?.toString().toLowerCase();
              final vId = (v['id'] as num?)?.toInt();
              final vName = v['nama_produk']?.toString().toLowerCase();
              final vEmail = v['user_email']?.toString().toLowerCase();

              final matchOldInv = oldInv != null && (vInv == oldInv.toLowerCase() || vRef == oldInv.toLowerCase());
              final matchNewInv = newInv != null && (vInv == newInv.toLowerCase() || vRef == newInv.toLowerCase());
              final matchId = (localId != null && localId > 0 && vId == localId);
              final matchNameEmail = (namaProduk != null && userEmail != null && vName == namaProduk.toLowerCase() && vEmail == userEmail.toLowerCase());

              if (matchOldInv || matchNewInv || matchId || matchNameEmail) {
                keysToUpdate.add(entry.key.toString());
              }
            }
          }
        }
      }
    } catch (_) {}

    // Simpan ke node utama di RTDB via REST API
    try {
      final uri = await buildTxRtdbUri('$targetKey.json');
      await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}

    // Hapus key lama jika nama invoice berubah
    for (final k in keysToUpdate) {
      if (k != targetKey) {
        try {
          final delUri = await buildTxRtdbUri('$k.json');
          await http.delete(delUri).timeout(const Duration(seconds: 2));
        } catch (_) {}
      }
    }

    // Update Firestore
    try {
      final firestoreData = Map<String, dynamic>.from(data);
      firestoreData['updated_at'] = FieldValue.serverTimestamp();
      await _firestoreRef
          .doc(targetKey)
          .set(firestoreData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 2));
    } catch (_) {}

    return true;
  }

  /// Menghapus data transaksi dari Firebase RTDB & Firestore
  Future<bool> deleteTransactionFromFirebase({
    String? invoiceNo,
    int? localId,
    String? namaProduk,
    String? userEmail,
  }) async {
    final Set<String> keysToDelete = {};
    if (invoiceNo != null && invoiceNo.trim().isNotEmpty) {
      final clean = _sanitizeKey(invoiceNo);
      keysToDelete.add(clean);
      if (clean.startsWith('INV-')) {
        keysToDelete.add(clean.replaceFirst('INV-', ''));
      } else {
        keysToDelete.add('INV-$clean');
      }
    }
    if (localId != null && localId > 0) {
      keysToDelete.add('loc_$localId');
      keysToDelete.add('TX_$localId');
    }

    final cleanInv = invoiceNo?.trim().toLowerCase();
    final cleanName = namaProduk?.trim().toLowerCase();
    final cleanEmail = userEmail?.trim().toLowerCase();

    // Cari seluruh key di RTDB yang cocok
    try {
      final uri = await buildTxRtdbUri();
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
        final dynamic decoded = jsonDecode(res.body);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final kStr = entry.key.toString();
            final v = entry.value;
            if (v is Map) {
              final vInv = v['invoice_no']?.toString().toLowerCase();
              final vRef = v['id_ref']?.toString().toLowerCase();
              final vId = (v['id'] as num?)?.toInt();
              final vName = v['nama_produk']?.toString().toLowerCase();
              final vEmail = v['user_email']?.toString().toLowerCase();

              final matchInv = cleanInv != null && (kStr.toLowerCase() == cleanInv || vInv == cleanInv || vRef == cleanInv || kStr.toLowerCase().contains(cleanInv));
              final matchId = (localId != null && localId > 0 && vId == localId);
              final matchName = (cleanName != null && vName == cleanName && (cleanEmail == null || vEmail == cleanEmail));

              if (matchInv || matchId || matchName) {
                keysToDelete.add(kStr);
              }
            }
          }
        }
      }
    } catch (_) {}

    for (final cleanKey in keysToDelete) {
      // 1. Hapus via REST API RTDB
      try {
        final uri = await buildTxRtdbUri('$cleanKey.json');
        await http.delete(uri).timeout(const Duration(seconds: 3));
      } catch (_) {}

      // 2. Hapus via SDK RTDB
      try {
        await _rtdbRef.child(cleanKey).remove().timeout(const Duration(seconds: 2));
      } catch (_) {}

      // 3. Hapus via Firestore
      try {
        await _firestoreRef.doc(cleanKey).delete().timeout(const Duration(seconds: 2));
      } catch (_) {}
    }

    return true;
  }

  /// Sinkronisasi penuh: Salin semua transaksi dari SQLite lokal ke Firebase (RTDB & Firestore)
  Future<int> syncAllLocalTransactionsToFirebase() async {
    return syncAllLocalTransactionsToFirestore();
  }

  /// Sinkronisasi penuh: Salin semua transaksi nyata dari SQLite lokal ke Firebase
  Future<int> syncAllLocalTransactionsToFirestore() async {
    try {
      // Bersihkan data dummy lama jika ada di cloud
      cleanupDummyTransactionsFromFirebase();

      final localTx = await DatabaseHelper.instance.getAllTransactions();
      int successCount = 0;

      if (localTx.isEmpty) {
        debugPrint(
            '[FirebaseTransactionService] Belum ada transaksi nyata di database lokal SQLite.');
        return 0;
      }

      for (final tx in localTx) {
        final inv = (tx['invoice_no'] ?? '').toString();
        if (inv == 'INV-VIBETECH-INIT' || inv.contains('test_') || inv.contains('mock_')) {
          continue;
        }
        final res = await saveTransactionToFirebase(tx);
        if (res != null) successCount++;
      }
      debugPrint(
          '[FirebaseTransactionService] Sukses sinkronisasi $successCount / ${localTx.length} transaksi ke Firebase.');
      return successCount;
    } catch (e) {
      debugPrint(
          '[FirebaseTransactionService] Gagal sinkronisasi transaksi ke Firebase: $e');
      return 0;
    }
  }

  /// Menghapus transaksi dummy / inisialisasi lama dari Firebase
  Future<void> cleanupDummyTransactionsFromFirebase() async {
    final dummyInvoices = ['INV-VIBETECH-INIT', 'TX_INIT', 'INV-INIT'];
    for (final inv in dummyInvoices) {
      try {
        await deleteTransactionFromFirebase(invoiceNo: inv);
      } catch (_) {}
    }
  }

  /// Mengambil semua transaksi dari Firebase Realtime Database
  Future<List<Map<String, dynamic>>> getAllTransactionsFromFirebase() async {
    try {
      final uri = await buildTxRtdbUri();
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 &&
          response.body != 'null' &&
          response.body.isNotEmpty) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final list = <Map<String, dynamic>>[];
          decoded.forEach((k, v) {
            if (v is Map) {
              list.add(Map<String, dynamic>.from(v));
            }
          });
          if (list.isNotEmpty) return list;
        }
      }
    } catch (e) {
      debugPrint(
          '[FirebaseTransactionService] Gagal memuat transaksi dari RTDB: $e');
    }

    try {
      final snap =
          await _firestoreRef.get().timeout(const Duration(seconds: 2));
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => d.data()).toList();
      }
    } catch (_) {}

    return [];
  }

  /// Mengambil semua transaksi pengguna berdasarkan email dari Firestore/RTDB
  Future<List<Map<String, dynamic>>> getTransactionsByUser(String email) async {
    try {
      final allTx = await getAllTransactionsFromFirebase();
      if (allTx.isNotEmpty) {
        final cleanEmail = email.trim().toLowerCase();
        return allTx.where((item) {
          final uEmail =
              (item['user_email'] ?? '').toString().trim().toLowerCase();
          return uEmail == cleanEmail;
        }).toList();
      }
    } catch (_) {}

    return [];
  }

  /// Mengunduh dan menyinkronkan transaksi dari Firebase RTDB ke SQLite lokal PC
  Future<int> syncTransactionsFromFirebase({String? userEmail}) async {
    try {
      final cloudTxList = userEmail != null && userEmail.trim().isNotEmpty
          ? await getTransactionsByUser(userEmail)
          : await getAllTransactionsFromFirebase();

      final db = await DatabaseHelper.instance.database;
      int imported = 0;

      // --- 1. Import/Update transaksi dari Cloud ke SQLite lokal ---
      final Set<String> cloudInvoices = {};
      for (final cloudItem in cloudTxList) {
        final invoice = cloudItem['invoice_no']?.toString();
        final email =
            cloudItem['user_email']?.toString() ?? 'user@vibetech.com';
        final namaProduk =
            cloudItem['nama_produk']?.toString() ?? 'Layanan Cloud';
        final jumlah = (cloudItem['jumlah'] as num?)?.toInt() ?? 1;
        final totalHarga =
            (cloudItem['total_harga'] as num?)?.toDouble() ?? 0.0;
        final tanggal = cloudItem['tanggal']?.toString() ??
            DateTime.now().toIso8601String();
        final status = cloudItem['status']?.toString() ?? 'Selesai';
        final paymentMethod = cloudItem['payment_method']?.toString();
        final notes = cloudItem['notes']?.toString();

        if (invoice != null && invoice.trim().isNotEmpty) {
          cloudInvoices.add(invoice.trim());
        }

        final Map<String, dynamic> row = {
          'invoice_no': invoice,
          'user_email': email,
          'nama_produk': namaProduk,
          'jumlah': jumlah,
          'total_harga': totalHarga,
          'tanggal': tanggal,
          'status': status,
          'payment_method': paymentMethod,
          'notes': notes,
        };

        if (invoice != null && invoice.trim().isNotEmpty) {
          final existing = await db.query(
            'transactions',
            where: 'invoice_no = ?',
            whereArgs: [invoice.trim()],
            limit: 1,
          );

          if (existing.isNotEmpty) {
            final id = existing.first['id'] as int;
            await db
                .update('transactions', row, where: 'id = ?', whereArgs: [id]);
          } else {
            await db.insert('transactions', row);
          }
        } else {
          await db.insert('transactions', row);
        }
        imported++;
      }

      // --- 2. Deteksi & hapus transaksi lokal yang sudah dihapus di Firebase RTDB ---
      try {
        List<Map<String, dynamic>> localTxList;
        if (userEmail != null && userEmail.trim().isNotEmpty) {
          localTxList = await db.query('transactions',
              where: 'LOWER(user_email) = ?',
              whereArgs: [userEmail.trim().toLowerCase()]);
        } else {
          localTxList = await db.query('transactions');
        }

        int deletedCount = 0;
        for (final localTx in localTxList) {
          final localInv = localTx['invoice_no']?.toString().trim();
          if (localInv != null &&
              localInv.isNotEmpty &&
              !cloudInvoices.contains(localInv) &&
              !cloudInvoices.contains('INV-$localInv') &&
              !cloudInvoices.contains(localInv.replaceAll('INV-', ''))) {
            await db.delete('transactions',
                where: 'id = ?', whereArgs: [localTx['id']]);
            deletedCount++;
          }
        }
        if (deletedCount > 0) {
          debugPrint(
              '[FirebaseTransactionService] 🗑️ Menghapus $deletedCount transaksi lokal yang sudah dihapus di Firebase RTDB.');
        }
      } catch (e) {
        debugPrint(
            '[FirebaseTransactionService] Info deteksi penghapusan cloud: $e');
      }

      debugPrint(
          '[FirebaseTransactionService] 📥 Berhasil menyinkronkan $imported transaksi dari Cloud ke SQLite.');
      return imported;
    } catch (e) {
      debugPrint(
          '[FirebaseTransactionService] Info sync transaksi dari cloud: $e');
      return 0;
    }
  }

  // ===========================================================================
  // SINKRONISASI LAYANAN AKTIF (PURCHASED SERVICES) KE FIREBASE RTDB
  // ===========================================================================

  static const String servicesCollection = 'services';
  static const String servicesCollectionLegacy = 'purchased_services';

  DatabaseReference get _rtdbServicesRef {
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: rtdbBaseUrl,
      ).ref(servicesCollection);
    } catch (_) {
      return FirebaseDatabase.instance.ref(servicesCollection);
    }
  }

  /// Menghasilkan Key / Document ID yang aman dan valid untuk Firebase
  String _sanitizeKey(String rawKey) {
    return rawKey.trim().replaceAll(RegExp(r'[/\\#?\[\]\.\$]'), '_');
  }

  /// Menentukan ID Dokumen untuk layanan aktif yang terurut rapi berdasarkan nomor, user, dan produk
  String resolveServiceDocId(Map<String, dynamic> data, {int? orderIndex}) =>
      _resolveServiceDocId(data, orderIndex: orderIndex);

  String _resolveServiceDocId(Map<String, dynamic> data, {int? orderIndex}) {
    final username = (data['username'] ?? data['user_email'] ?? 'user')
        .toString()
        .split('@')
        .first
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[/\\#?\[\]\.\$\s]'), '_');

    final namaProduk = (data['nama_produk'] ?? 'service')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .trim()
        .replaceAll(RegExp(r'[/\\#?\[\]\.\$\s\-_]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    final order = data['no'] ?? data['urutan'] ?? orderIndex ?? data['id'];
    if (order != null && order is num) {
      final orderInt = order.toInt();
      final prefix = orderInt < 10 ? '0$orderInt' : '$orderInt';
      return 'srv_${prefix}_${username}_$namaProduk';
    }

    return 'srv_${username}_$namaProduk';
  }

  /// Menyimpan atau memperbarui data layanan aktif ke Firebase RTDB & Firestore
  Future<String?> saveServiceToFirebase(
      Map<String, dynamic> serviceData) async {
    try {
      final Map<String, dynamic> data = Map<String, dynamic>.from(serviceData);
      final String docId = _resolveServiceDocId(data);

      data['doc_id'] = docId;
      final nowIso = DateTime.now().toIso8601String();
      data['updated_at'] = nowIso;
      if (!data.containsKey('created_at') && !data.containsKey('tanggal_beli')) {
        data['created_at'] = nowIso;
      }

      // 1. Simpan ke RTDB via REST API
      for (final col in [servicesCollection, servicesCollectionLegacy]) {
        try {
          final uri = await buildServiceRtdbUri(col, '$docId.json');
          await http
              .put(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(data),
              )
              .timeout(const Duration(seconds: 4));
        } catch (_) {}
      }

      // 2. Simpan ke RTDB via SDK
      try {
        await _rtdbServicesRef
            .child(docId)
            .set(data)
            .timeout(const Duration(seconds: 3));
      } catch (_) {}

      // 3. Simpan ke Firestore
      try {
        await FirebaseFirestore.instance
            .collection(servicesCollection)
            .doc(docId)
            .set(data, SetOptions(merge: true))
            .timeout(const Duration(seconds: 3));
      } catch (_) {}

      return docId;
    } catch (e) {
      debugPrint('[FirebaseTransactionService] Gagal simpan layanan: $e');
      return null;
    }
  }

  /// Memperbarui data layanan aktif di Firebase & SQLite
  Future<bool> updateServiceInFirebase({
    required int id,
    String? docId,
    String? namaProduk,
    String? userEmail,
    required Map<String, dynamic> updatedData,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      if (id > 0) {
        await db.update('purchased_services', updatedData,
            where: 'id = ?', whereArgs: [id]);
      }
      final srvName = (namaProduk ?? updatedData['nama_produk'])?.toString().trim().toLowerCase();
      final srvEmail = (userEmail ?? updatedData['user_email'])?.toString().trim().toLowerCase();
      if (srvName != null && srvName.isNotEmpty) {
        if (srvEmail != null && srvEmail.isNotEmpty) {
          await db.update(
            'purchased_services',
            updatedData,
            where: 'LOWER(nama_produk) = ? AND LOWER(user_email) = ?',
            whereArgs: [srvName, srvEmail],
          );
        } else {
          await db.update(
            'purchased_services',
            updatedData,
            where: 'LOWER(nama_produk) = ?',
            whereArgs: [srvName],
          );
        }
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(updatedData);
      data['updated_at'] = DateTime.now().toIso8601String();

      final keysToUpdate = <String>{};
      if (docId != null && docId.trim().isNotEmpty) {
        keysToUpdate.add(_sanitizeKey(docId));
      }
      if (id > 0) keysToUpdate.add('srv_$id');

      // Cari juga key yang cocok di RTDB
      try {
        final uri = await buildServiceRtdbUri(servicesCollection);
        final res = await http.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
          final dynamic decoded = jsonDecode(res.body);
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              final v = entry.value;
              if (v is Map) {
                final vId = (v['id'] as num?)?.toInt();
                final vDoc = v['doc_id']?.toString();
                final vName = v['nama_produk']?.toString().toLowerCase();
                final vEmail = v['user_email']?.toString().toLowerCase();

                final matchId = (id > 0 && vId == id);
                final matchDoc = (docId != null && docId.isNotEmpty && vDoc == docId);
                final matchName = (srvName != null && srvName.isNotEmpty && vName == srvName && (srvEmail == null || vEmail == srvEmail));

                if (matchId || matchDoc || matchName) {
                  keysToUpdate.add(entry.key.toString());
                }
              }
            }
          }
        }
      } catch (_) {}

      for (final cleanKey in keysToUpdate) {
        for (final col in [servicesCollection, servicesCollectionLegacy]) {
          try {
            final uri = await buildServiceRtdbUri(col, '$cleanKey.json');
            await http.patch(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data),
            );
          } catch (_) {}
        }
      }

      await syncOrderedServicesToFirebase();
      return true;
    } catch (e) {
      debugPrint('[FirebaseTransactionService] Error update service di Firebase: $e');
      return false;
    }
  }

  /// Menghapus layanan aktif dari Firebase RTDB & Firestore & SQLite
  Future<bool> deleteServiceFromFirebase(
    int id, {
    String? docId,
    String? namaProduk,
    String? userEmail,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      if (id > 0) {
        await db.delete('purchased_services', where: 'id = ?', whereArgs: [id]);
      }
      final srvName = namaProduk?.trim().toLowerCase();
      final srvEmail = userEmail?.trim().toLowerCase();
      if (srvName != null && srvName.isNotEmpty) {
        if (srvEmail != null && srvEmail.isNotEmpty) {
          await db.delete(
            'purchased_services',
            where: 'LOWER(nama_produk) = ? AND LOWER(user_email) = ?',
            whereArgs: [srvName, srvEmail],
          );
        } else {
          await db.delete(
            'purchased_services',
            where: 'LOWER(nama_produk) = ?',
            whereArgs: [srvName],
          );
        }
      }

      final keysToDelete = <String>{};
      if (docId != null && docId.trim().isNotEmpty) {
        keysToDelete.add(_sanitizeKey(docId));
      }
      if (id > 0) keysToDelete.add('srv_$id');

      // Cari key di RTDB yang cocok
      try {
        final uri = await buildServiceRtdbUri(servicesCollection);
        final res = await http.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
          final dynamic decoded = jsonDecode(res.body);
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              final v = entry.value;
              if (v is Map) {
                final vId = (v['id'] as num?)?.toInt();
                final vDoc = v['doc_id']?.toString();
                final vName = v['nama_produk']?.toString().toLowerCase();
                final vEmail = v['user_email']?.toString().toLowerCase();

                final matchId = (id > 0 && vId == id);
                final matchDoc = (docId != null && docId.isNotEmpty && vDoc == docId);
                final matchName = (srvName != null && srvName.isNotEmpty && vName == srvName && (srvEmail == null || vEmail == srvEmail));

                if (matchId || matchDoc || matchName) {
                  keysToDelete.add(entry.key.toString());
                }
              }
            }
          }
        }
      } catch (_) {}

      for (final cleanKey in keysToDelete) {
        for (final col in [servicesCollection, servicesCollectionLegacy]) {
          try {
            final uri = await buildServiceRtdbUri(col, '$cleanKey.json');
            await http.delete(uri).timeout(const Duration(seconds: 3));
          } catch (_) {}
        }
        try {
          await _rtdbServicesRef.child(cleanKey).remove().timeout(const Duration(seconds: 2));
        } catch (_) {}
        try {
          await FirebaseFirestore.instance
              .collection(servicesCollection)
              .doc(cleanKey)
              .delete()
              .timeout(const Duration(seconds: 2));
        } catch (_) {}
      }

      await syncOrderedServicesToFirebase();
      return true;
    } catch (e) {
      debugPrint('[FirebaseTransactionService] Error delete service dari Firebase: $e');
      return false;
    }
  }

  /// Mengambil semua layanan aktif dari Firebase RTDB (Mendukung /purchased_services & /services)
  Future<List<Map<String, dynamic>>> getAllServicesFromFirebase() async {
    final list = <Map<String, dynamic>>[];
    final seenKeys = <String>{};

    for (final col in [servicesCollectionLegacy, servicesCollection]) {
      try {
        final uri = await buildServiceRtdbUri(col);
        final res = await http.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
          final dynamic decoded = jsonDecode(res.body);
          if (decoded is Map) {
            decoded.forEach((k, v) {
              final kStr = k.toString();
              if (v is Map && !seenKeys.contains(kStr)) {
                seenKeys.add(kStr);
                final m = Map<String, dynamic>.from(v);
                m['doc_id'] = kStr;
                list.add(m);
              }
            });
          }
        }
      } catch (_) {}
    }
    return list;
  }

  /// Menyinkronkan seluruh layanan aktif ke Firebase RTDB dengan urutan rapi (Admin first, Member berikutnya)
  Future<int> syncOrderedServicesToFirebase() async {
    try {
      final db = await DatabaseHelper.instance.database;
      List<Map<String, dynamic>> localSrv = await db.query('purchased_services');

      // Jika belum ada data layanan sama sekali, inisialisasi layanan realistis default untuk masing-masing user
      if (localSrv.isEmpty) {
        await initDefaultServicesIfEmpty();
        localSrv = await db.query('purchased_services');
      }

      final usersList = await db.query('users');
      final userMapByIdentifier = <String, Map<String, dynamic>>{};
      for (final u in usersList) {
        final email = (u['email'] ?? '').toString().toLowerCase();
        final username = (u['username'] ?? '').toString().toLowerCase();
        if (email.isNotEmpty) userMapByIdentifier[email] = u;
        if (username.isNotEmpty) userMapByIdentifier[username] = u;
      }

      final sortedServices = List<Map<String, dynamic>>.from(
        localSrv.map((s) => Map<String, dynamic>.from(s)),
      );

      // Urutkan: Layanan milik Administrator di paling atas, lalu member alfabetis berdasarkan username & nama layanan
      sortedServices.sort((a, b) {
        final emailA = (a['user_email'] ?? '').toString().toLowerCase();
        final emailB = (b['user_email'] ?? '').toString().toLowerCase();
        final userA = userMapByIdentifier[emailA] ?? {};
        final userB = userMapByIdentifier[emailB] ?? {};

        final roleA = (userA['role'] ?? 'user').toString().toLowerCase();
        final roleB = (userB['role'] ?? 'user').toString().toLowerCase();
        final isAdminA = roleA == 'admin' || roleA == 'administrator';
        final isAdminB = roleB == 'admin' || roleB == 'administrator';

        if (isAdminA && !isAdminB) return -1;
        if (!isAdminA && isAdminB) return 1;

        final nameA = (userA['username'] ?? userA['nama'] ?? emailA).toString().toLowerCase();
        final nameB = (userB['username'] ?? userB['nama'] ?? emailB).toString().toLowerCase();
        final userComp = nameA.compareTo(nameB);
        if (userComp != 0) return userComp;

        final prodA = (a['nama_produk'] ?? '').toString().toLowerCase();
        final prodB = (b['nama_produk'] ?? '').toString().toLowerCase();
        return prodA.compareTo(prodB);
      });

      // Bersihkan key lama yang tidak valid di RTDB
      try {
        final uri = await buildServiceRtdbUri(servicesCollection);
        final resp = await http.get(uri).timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200 && resp.body.isNotEmpty && resp.body != 'null') {
          final dynamic decoded = jsonDecode(resp.body);
          if (decoded is Map) {
            final validKeys = <String>{};
            for (int i = 0; i < sortedServices.length; i++) {
              final srv = sortedServices[i];
              final email = (srv['user_email'] ?? '').toString().toLowerCase();
              final userObj = userMapByIdentifier[email] ?? {};
              srv['username'] = userObj['username'] ?? email.split('@').first;
              srv['role'] = userObj['role'] ?? 'user';
              srv['nama_user'] = userObj['nama'] ?? srv['username'];
              validKeys.add(_resolveServiceDocId(srv, orderIndex: i + 1));
            }

            for (final k in decoded.keys) {
              final kStr = k.toString();
              if (!validKeys.contains(kStr)) {
                final delUri = await buildServiceRtdbUri(servicesCollection, '$kStr.json');
                await http.delete(delUri).timeout(const Duration(seconds: 3));
              }
            }
          }
        }
      } catch (_) {}

      // Tulis ulang layanan terurut rapi ke Firebase RTDB
      for (int i = 0; i < sortedServices.length; i++) {
        final srv = sortedServices[i];
        final orderNum = i + 1;
        final email = (srv['user_email'] ?? '').toString().toLowerCase();
        final userObj = userMapByIdentifier[email] ?? {};

        srv['no'] = orderNum;
        srv['urutan'] = orderNum;
        srv['username'] = userObj['username'] ?? email.split('@').first;
        srv['role'] = userObj['role'] ?? 'user';
        srv['nama_user'] = userObj['nama'] ?? srv['username'];

        final docId = _resolveServiceDocId(srv, orderIndex: orderNum);
        srv['doc_id'] = docId;
        srv['updated_at'] = DateTime.now().toIso8601String();

        for (final col in [servicesCollection, servicesCollectionLegacy]) {
          try {
            final uri = await buildServiceRtdbUri(col, '$docId.json');
            await http
                .put(
                  uri,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(srv),
                )
                .timeout(const Duration(seconds: 4));
          } catch (_) {}
        }

        try {
          await FirebaseFirestore.instance
              .collection(servicesCollection)
              .doc(docId)
              .set(srv, SetOptions(merge: true))
              .timeout(const Duration(seconds: 2));
        } catch (_) {}
      }

      debugPrint(
          '[FirebaseTransactionService] 🚀 Sukses menyusun ${sortedServices.length} data layanan terurut nomor & nama akun di Firebase RTDB!');
      return sortedServices.length;
    } catch (e) {
      debugPrint('[FirebaseTransactionService] Gagal menyusun layanan di Firebase: $e');
      return 0;
    }
  }

  /// Menginisialisasi data layanan default realistis untuk akun pengguna yang terdaftar
  Future<void> initDefaultServicesIfEmpty() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final existing = await db.query('purchased_services');
      if (existing.isNotEmpty) return;

      final users = await db.query('users');
      final now = DateTime.now();
      final expDate = now.add(const Duration(days: 30)).toIso8601String();

      for (final user in users) {
        final email = (user['email'] ?? '').toString();
        final username = (user['username'] ?? '').toString();
        final role = (user['role'] ?? 'user').toString().toLowerCase();
        final isAdmin = role == 'admin' || role == 'administrator';

        if (isAdmin || username == 'raziek') {
          // Layanan Admin 1: VPS Enterprise
          await db.insert('purchased_services', {
            'user_email': email,
            'nama_produk': 'VPS Enterprise (Ubuntu 22.04 LTS)',
            'kategori': 'VPS',
            'harga': 150000.0,
            'tanggal_beli': now.toIso8601String(),
            'tanggal_kadaluarsa': expDate,
            'status': 'Aktif',
            'ip_address': '103.145.226.10',
            'port': '22',
            'username': 'root',
            'password': 'vbt_vps_adm2026!',
            'server_url': 'ssh root@103.145.226.10',
            'spesifikasi': '8 Core CPU, 16 GB RAM, 160 GB NVMe SSD',
            'extra_data': 'Data Center Singapore (SG-01), Bandwidth 10 Gbps',
          });

          // Layanan Admin 2: Panel Hosting Unlimited
          await db.insert('purchased_services', {
            'user_email': email,
            'nama_produk': 'Panel Hosting Unlimited (Pterodactyl)',
            'kategori': 'Panel Hosting',
            'harga': 50000.0,
            'tanggal_beli': now.toIso8601String(),
            'tanggal_kadaluarsa': expDate,
            'status': 'Aktif',
            'ip_address': '103.145.226.11',
            'port': '8080',
            'username': 'raziek_admin',
            'password': 'vbt_panel_adm2026!',
            'server_url': 'https://panel.vibetech.xyz',
            'spesifikasi': 'Unlimited Node, 16 GB RAM, 100 GB Disk',
            'extra_data': 'Pterodactyl v1.11, Wings Node 1 Online',
          });
        } else if (username == 'zyrogans') {
          // Member zyrogans: Panel Hosting 4GB & VPS Pro
          await db.insert('purchased_services', {
            'user_email': email,
            'nama_produk': 'Panel Hosting 4GB (Pterodactyl)',
            'kategori': 'Panel Hosting',
            'harga': 25000.0,
            'tanggal_beli': now.toIso8601String(),
            'tanggal_kadaluarsa': expDate,
            'status': 'Aktif',
            'ip_address': '103.145.226.15',
            'port': '8080',
            'username': 'zyrogans',
            'password': 'zyro_pterodactyl99',
            'server_url': 'https://panel.vibetech.xyz',
            'spesifikasi': '2 Core CPU, 4 GB RAM, 20 GB Disk',
            'extra_data': 'Pterodactyl Node 2, Egg Node.js & Python',
          });

          await db.insert('purchased_services', {
            'user_email': email,
            'nama_produk': 'VPS Pro (Ubuntu 22.04 LTS)',
            'kategori': 'VPS',
            'harga': 75000.0,
            'tanggal_beli': now.toIso8601String(),
            'tanggal_kadaluarsa': expDate,
            'status': 'Aktif',
            'ip_address': '103.145.226.16',
            'port': '22',
            'username': 'root',
            'password': 'zyro_vps_pass2026',
            'server_url': 'ssh root@103.145.226.16',
            'spesifikasi': '4 Core CPU, 8 GB RAM, 80 GB NVMe SSD',
            'extra_data': 'Data Center Singapore (SG-02), Bandwidth 1 Gbps',
          });
        } else if (username == 'mcdandigaming') {
          // Member mcdandigaming: Bot WhatsApp Pro
          await db.insert('purchased_services', {
            'user_email': email,
            'nama_produk': 'Bot WhatsApp Pro (Node.js & Baileys)',
            'kategori': 'Bot WhatsApp',
            'harga': 50000.0,
            'tanggal_beli': now.toIso8601String(),
            'tanggal_kadaluarsa': expDate,
            'status': 'Aktif',
            'session_id': 'vbt_wa_mcdandi_7721',
            'server_url': 'https://wa.vibetech.xyz/dandi',
            'spesifikasi': 'High Speed Baileys Session, Auto Reply 24/7',
            'extra_data': 'Multi-Device WA Web API, Anti Delete Plugin Active',
          });
        } else if (username == 'razikrdtya') {
          // Member razikrdtya: VPS Starter
          await db.insert('purchased_services', {
            'user_email': email,
            'nama_produk': 'VPS Starter (Ubuntu 22.04 LTS)',
            'kategori': 'VPS',
            'harga': 35000.0,
            'tanggal_beli': now.toIso8601String(),
            'tanggal_kadaluarsa': expDate,
            'status': 'Aktif',
            'ip_address': '103.145.226.20',
            'port': '22',
            'username': 'root',
            'password': 'razik_vps_pass2026',
            'server_url': 'ssh root@103.145.226.20',
            'spesifikasi': '2 Core CPU, 2 GB RAM, 40 GB NVMe SSD',
            'extra_data': 'Data Center Jakarta (ID-01), Bandwidth 1 Gbps',
          });
        }
      }

      debugPrint(
          '[FirebaseTransactionService] 💡 Sukses menginisialisasi data layanan default untuk semua akun pengguna.');
    } catch (e) {
      debugPrint('[FirebaseTransactionService] Error initDefaultServices: $e');
    }
  }

  /// Menyinkronkan semua layanan aktif SQLite lokal ke Firebase
  Future<int> syncAllLocalServicesToFirebase() async {
    return await syncOrderedServicesToFirebase();
  }

  /// Mengunduh layanan aktif dari Firebase ke SQLite lokal PC (Full 2-Way Sync: Update, Insert, Delete)
  Future<int> syncServicesFromFirebase({String? userEmail}) async {
    try {
      final cloudList = await getAllServicesFromFirebase();
      final db = await DatabaseHelper.instance.database;

      if (cloudList.isEmpty) {
        final localAll = await db.query('purchased_services');
        if (localAll.isNotEmpty) {
          await syncOrderedServicesToFirebase();
        }
        return 0;
      }

      int count = 0;
      final Set<String> cloudMatchingKeys = {};

      for (final item in cloudList) {
        final email = (item['user_email'] ?? '').toString().trim().toLowerCase();
        final username = (item['username'] ?? '').toString().trim().toLowerCase();
        final namaProduk = (item['nama_produk'] ?? 'Cloud Service').toString().trim();
        final docId = item['doc_id']?.toString() ?? '';

        final keyEmail = '${email}_${namaProduk.toLowerCase()}';
        final keyUser = '${username}_${namaProduk.toLowerCase()}';
        cloudMatchingKeys.add(keyEmail);
        cloudMatchingKeys.add(keyUser);
        if (docId.isNotEmpty) cloudMatchingKeys.add(docId.toLowerCase());

        // Filter jika dipanggil spesifik untuk 1 user email/username
        if (userEmail != null && userEmail.trim().isNotEmpty) {
          final target = userEmail.trim().toLowerCase();
          final isMatch = email == target ||
              username == target ||
              (target.contains('@') && target.split('@').first == username);
          if (!isMatch) continue;
        }

        final kategori = item['kategori']?.toString() ?? 'VPS';
        final harga = (item['harga'] as num?)?.toDouble() ?? 0.0;
        final tglBeli = item['tanggal_beli']?.toString() ??
            DateTime.now().toIso8601String();
        final tglExp = item['tanggal_kadaluarsa']?.toString() ?? '';
        final status = item['status']?.toString() ?? 'Aktif';

        final row = {
          'user_email': email.isNotEmpty ? email : (item['user_email']?.toString() ?? userEmail ?? ''),
          'nama_produk': namaProduk,
          'kategori': kategori,
          'harga': harga,
          'tanggal_beli': tglBeli,
          'tanggal_kadaluarsa': tglExp,
          'status': status,
          'ip_address': item['ip_address']?.toString(),
          'port': item['port']?.toString(),
          'username': item['username_srv']?.toString() ?? item['username']?.toString(),
          'password': item['password_srv']?.toString() ?? item['password']?.toString(),
          'server_url': item['server_url']?.toString(),
          'session_id': item['session_id']?.toString(),
          'spesifikasi': item['spesifikasi']?.toString(),
          'extra_data': item['extra_data']?.toString(),
        };

        final existing = await db.query(
          'purchased_services',
          where: 'LOWER(user_email) = ? AND LOWER(nama_produk) = ?',
          whereArgs: [email, namaProduk.toLowerCase()],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          final id = existing.first['id'] as int;
          await db.update('purchased_services', row,
              where: 'id = ?', whereArgs: [id]);
        } else {
          await db.insert('purchased_services', row);
        }
        count++;
      }

      // Hapus data lokal yang telah dihapus di Firebase Cloud RTDB
      List<Map<String, dynamic>> localQuery;
      if (userEmail != null && userEmail.trim().isNotEmpty) {
        final target = userEmail.trim().toLowerCase();
        localQuery = await db.query(
          'purchased_services',
          where: 'LOWER(user_email) = ? OR LOWER(user_email) LIKE ?',
          whereArgs: [target, '$target%'],
        );
      } else {
        localQuery = await db.query('purchased_services');
      }

      for (final localSrv in localQuery) {
        final lEmail = (localSrv['user_email'] ?? '').toString().toLowerCase();
        final lUser = lEmail.contains('@') ? lEmail.split('@').first : lEmail;
        final lNama = (localSrv['nama_produk'] ?? '').toString().toLowerCase();
        final key1 = '${lEmail}_$lNama';
        final key2 = '${lUser}_$lNama';

        final isPresentInCloud =
            cloudMatchingKeys.contains(key1) || cloudMatchingKeys.contains(key2);

        if (!isPresentInCloud) {
          final localId = localSrv['id'] as int?;
          if (localId != null) {
            await db.delete('purchased_services',
                where: 'id = ?', whereArgs: [localId]);
            debugPrint(
                '[FirebaseTransactionService] 🗑️ Menghapus layanan lokal #$localId ($lNama) karena telah dihapus di Firebase Cloud RTDB.');
          }
        }
      }

      return count;
    } catch (e) {
      debugPrint('[FirebaseTransactionService] Error syncServicesFromFirebase: $e');
      return 0;
    }
  }
}

/// Extension agar method pembantu URI RTDB dapat diakses secara langsung lewat instance maupun static
extension FirebaseTransactionServiceExtension on FirebaseTransactionService {
  Future<Uri> buildTxRtdbUri([String? docKey]) =>
      FirebaseTransactionService.buildTxRtdbUri(docKey);

  Future<Uri> buildServiceRtdbUri(String col, [String? docKey]) =>
      FirebaseTransactionService.buildServiceRtdbUri(col, docKey);
}


