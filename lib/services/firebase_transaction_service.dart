import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vibetech_xyz/database/db_helper.dart';

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
      final uri = Uri.parse('$rtdbBaseUrl/$collectionName/$docId.json');
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
  Future<bool> updateTransactionInFirebase({
    String? invoiceNo,
    int? localId,
    required Map<String, dynamic> updatedData,
  }) async {
    final Map<String, dynamic> data = Map<String, dynamic>.from(updatedData);
    final String? cleanKey = (invoiceNo != null && invoiceNo.trim().isNotEmpty)
        ? invoiceNo.trim().replaceAll(RegExp(r'[/\\#?\[\]\.\$]'), '_')
        : null;

    final nowIso = DateTime.now().toIso8601String();
    data['updated_at'] = nowIso;

    // 1. Update ke Realtime Database via REST API
    if (cleanKey != null) {
      try {
        final uri = Uri.parse('$rtdbBaseUrl/$collectionName/$cleanKey.json');
        await http.patch(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        );
      } catch (_) {}
    }

    // 2. Update via SDK
    try {
      if (cleanKey != null) {
        await _rtdbRef.child(cleanKey).update(data);
      }
    } catch (_) {}

    // 3. Update Firestore
    try {
      if (cleanKey != null) {
        final firestoreData = Map<String, dynamic>.from(data);
        firestoreData['updated_at'] = FieldValue.serverTimestamp();
        await _firestoreRef
            .doc(cleanKey)
            .set(firestoreData, SetOptions(merge: true));
      }
    } catch (_) {}

    return true;
  }

  /// Menghapus data transaksi dari Firebase
  Future<bool> deleteTransactionFromFirebase({
    String? invoiceNo,
    int? localId,
  }) async {
    final String? cleanKey = (invoiceNo != null && invoiceNo.trim().isNotEmpty)
        ? invoiceNo.trim().replaceAll(RegExp(r'[/\\#?\[\]\.\$]'), '_')
        : null;

    if (cleanKey != null) {
      // 1. Hapus via REST API
      try {
        final uri = Uri.parse('$rtdbBaseUrl/$collectionName/$cleanKey.json');
        await http.delete(uri);
      } catch (_) {}

      // 2. Hapus via SDK RTDB
      try {
        await _rtdbRef.child(cleanKey).remove();
      } catch (_) {}

      // 3. Hapus via Firestore
      try {
        await _firestoreRef.doc(cleanKey).delete();
      } catch (_) {}
    }

    return true;
  }

  /// Sinkronisasi penuh: Salin semua transaksi dari SQLite lokal ke Firebase (RTDB & Firestore)
  Future<int> syncAllLocalTransactionsToFirebase() async {
    return syncAllLocalTransactionsToFirestore();
  }

  /// Sinkronisasi penuh: Salin semua transaksi dari SQLite lokal ke Firebase
  Future<int> syncAllLocalTransactionsToFirestore() async {
    try {
      final localTx = await DatabaseHelper.instance.getAllTransactions();
      int successCount = 0;

      if (localTx.isEmpty) {
        debugPrint(
            '[FirebaseTransactionService] Belum ada transaksi di database lokal SQLite.');
        // Jika kosong, kirim transaksi inisialisasi selamat datang/demo
        await _saveInitialSampleTransaction();
        return 1;
      }

      for (final tx in localTx) {
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

  /// Mengirim satu transaksi awal agar database di console Firebase tidak kosong (null)
  Future<void> _saveInitialSampleTransaction() async {
    try {
      final sample = {
        'invoice_no': 'INV-VIBETECH-INIT',
        'user_email': 'admin@vibetech.xyz',
        'nama_produk': 'Inisialisasi Sistem Database VibeTech',
        'jumlah': 1,
        'total_harga': 0.0,
        'tanggal': DateTime.now()
            .toIso8601String()
            .substring(0, 16)
            .replaceAll('T', ' '),
        'status': 'Selesai',
        'payment_method': 'System',
        'notes': 'Database Firebase VibeTech XYZ terhubung dan aktif.',
      };
      await saveTransactionToFirebase(sample);
    } catch (e) {
      debugPrint('[FirebaseTransactionService] Gagal inisialisasi sample: $e');
    }
  }

  /// Mengambil semua transaksi dari Firebase Realtime Database
  Future<List<Map<String, dynamic>>> getAllTransactionsFromFirebase() async {
    try {
      final uri = Uri.parse('$rtdbBaseUrl/$collectionName.json');
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
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

      if (cloudTxList.isEmpty) return 0;

      final db = await DatabaseHelper.instance.database;
      int imported = 0;

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

  static const String servicesCollection = 'purchased_services';

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

  /// Menyimpan layanan aktif ke Firebase RTDB & Firestore
  Future<String?> saveServiceToFirebase(
      Map<String, dynamic> serviceData) async {
    final Map<String, dynamic> data = Map<String, dynamic>.from(serviceData);
    final String docId = data['id'] != null
        ? 'srv_${data['id']}'
        : 'srv_${DateTime.now().millisecondsSinceEpoch}';

    data['doc_id'] = docId;
    data['updated_at'] = DateTime.now().toIso8601String();

    try {
      final uri = Uri.parse('$rtdbBaseUrl/$servicesCollection/$docId.json');
      await http
          .put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {}

    try {
      await _rtdbServicesRef
          .child(docId)
          .set(data)
          .timeout(const Duration(seconds: 3));
    } catch (_) {}

    try {
      await FirebaseFirestore.instance
          .collection(servicesCollection)
          .doc(docId)
          .set(data, SetOptions(merge: true))
          .timeout(const Duration(seconds: 3));
    } catch (_) {}

    return docId;
  }

  /// Menghapus layanan aktif dari Firebase
  Future<bool> deleteServiceFromFirebase(int id) async {
    final docId = 'srv_$id';
    try {
      final uri = Uri.parse('$rtdbBaseUrl/$servicesCollection/$docId.json');
      await http.delete(uri).timeout(const Duration(seconds: 4));
    } catch (_) {}

    try {
      await _rtdbServicesRef.child(docId).remove();
    } catch (_) {}

    return true;
  }

  /// Mengambil semua layanan aktif dari Firebase RTDB
  Future<List<Map<String, dynamic>>> getAllServicesFromFirebase() async {
    try {
      final uri = Uri.parse('$rtdbBaseUrl/$servicesCollection.json');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {
        final dynamic decoded = jsonDecode(res.body);
        if (decoded is Map) {
          final list = <Map<String, dynamic>>[];
          decoded.forEach((k, v) {
            if (v is Map) list.add(Map<String, dynamic>.from(v));
          });
          if (list.isNotEmpty) return list;
        }
      }
    } catch (_) {}
    return [];
  }

  /// Menyinkronkan semua layanan aktif SQLite lokal ke Firebase
  Future<int> syncAllLocalServicesToFirebase() async {
    try {
      final localSrv = await DatabaseHelper.instance.getAllServices();
      int success = 0;
      for (final srv in localSrv) {
        final res = await saveServiceToFirebase(srv);
        if (res != null) success++;
      }
      return success;
    } catch (_) {
      return 0;
    }
  }

  /// Mengunduh layanan aktif dari Firebase ke SQLite lokal PC
  Future<int> syncServicesFromFirebase({String? userEmail}) async {
    try {
      final cloudList = await getAllServicesFromFirebase();
      if (cloudList.isEmpty) return 0;

      final db = await DatabaseHelper.instance.database;
      int count = 0;

      for (final item in cloudList) {
        final email = (item['user_email'] ?? '').toString();
        if (userEmail != null &&
            userEmail.trim().isNotEmpty &&
            email.toLowerCase() != userEmail.trim().toLowerCase()) {
          continue;
        }

        final namaProduk = item['nama_produk']?.toString() ?? 'Cloud Service';
        final kategori = item['kategori']?.toString() ?? 'VPS';
        final harga = (item['harga'] as num?)?.toDouble() ?? 0.0;
        final tglBeli = item['tanggal_beli']?.toString() ??
            DateTime.now().toIso8601String();
        final tglExp = item['tanggal_kadaluarsa']?.toString() ?? '';
        final status = item['status']?.toString() ?? 'Aktif';

        final row = {
          'user_email': email,
          'nama_produk': namaProduk,
          'kategori': kategori,
          'harga': harga,
          'tanggal_beli': tglBeli,
          'tanggal_kadaluarsa': tglExp,
          'status': status,
          'ip_address': item['ip_address']?.toString(),
          'port': item['port']?.toString(),
          'username': item['username']?.toString(),
          'password': item['password']?.toString(),
          'server_url': item['server_url']?.toString(),
          'session_id': item['session_id']?.toString(),
          'spesifikasi': item['spesifikasi']?.toString(),
          'extra_data': item['extra_data']?.toString(),
        };

        final existing = await db.query(
          'purchased_services',
          where: 'user_email = ? AND nama_produk = ? AND tanggal_beli = ?',
          whereArgs: [email, namaProduk, tglBeli],
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
      return count;
    } catch (_) {
      return 0;
    }
  }
}
