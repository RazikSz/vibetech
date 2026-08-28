import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vibetech_xyz/database/db_helper.dart';

/// ============================================================================
/// FIREBASE PRODUCT SERVICE - VIBETECH XYZ
/// ============================================================================
/// Layanan sinkronisasi katalog produk & diskon ke Firebase Realtime Database
/// (https://vibetech-xyz-default-rtdb.asia-southeast1.firebasedatabase.app/)
/// dan Google Cloud Firestore (databaseId: vibetech-xyz).
class FirebaseProductService {
  static final FirebaseProductService instance =
      FirebaseProductService._init();

  FirebaseProductService._init();

  static const String rtdbBaseUrl =
      'https://vibetech-xyz-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String collectionName = 'products';
  static const String projectId = 'vibetech-xyz';
  static const String databaseId = 'vibetech-xyz';

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

  /// Referensi Google Cloud Firestore
  CollectionReference<Map<String, dynamic>> get _firestoreRef {
    try {
      return FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: databaseId,
      ).collection(collectionName);
    } catch (_) {
      return FirebaseFirestore.instance.collection(collectionName);
    }
  }

  /// Format ID dokumen produk yang aman untuk path RTDB dan Firestore
  String _resolveProductDocId(Map<String, dynamic> data) {
    if (data['id'] != null) {
      return 'prod_${data['id']}';
    }
    final nama = (data['nama'] ?? 'product').toString().trim().toLowerCase();
    final sanitized = nama.replaceAll(RegExp(r'[/\\#?\[\]\.\$\s]'), '_');
    return 'prod_$sanitized';
  }

  /// Menyimpan produk baru atau memperbarui produk di Firebase RTDB & Firestore
  Future<String?> saveProductToFirebase(Map<String, dynamic> productData) async {
    final Map<String, dynamic> data = Map<String, dynamic>.from(productData);

    // Normalisasi tipe data numerik
    if (data['harga'] != null) {
      data['harga'] = (data['harga'] as num).toDouble();
    }
    if (data['diskon'] != null) {
      data['diskon'] = (data['diskon'] as num).toDouble();
    }
    if (data['stok'] != null) {
      data['stok'] = (data['stok'] as num).toInt();
    }

    final docId = _resolveProductDocId(data);
    data['doc_id'] = docId;
    final nowIso = DateTime.now().toIso8601String();
    data['updated_at'] = nowIso;

    // 1. Simpan ke Firebase Realtime Database via HTTP REST API (Garansi Lintas Perangkat)
    try {
      final uri = Uri.parse('$rtdbBaseUrl/$collectionName/$docId.json');
      final response = await http
          .put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        debugPrint('[FirebaseProductService] ✅ HTTP REST RTDB simpan produk sukses: $docId');
      }
    } catch (e) {
      debugPrint('[FirebaseProductService] HTTP REST RTDB Exception: $e');
    }

    // 2. Simpan via SDK Realtime Database
    try {
      await _rtdbRef.child(docId).set(data).timeout(const Duration(seconds: 3));
      debugPrint('[FirebaseProductService] SDK RTDB simpan produk sukses: $docId');
    } catch (e) {
      debugPrint('[FirebaseProductService] SDK RTDB info: $e');
    }

    // 3. Simpan ke Google Cloud Firestore
    try {
      final firestoreData = Map<String, dynamic>.from(data);
      firestoreData['updated_at'] = FieldValue.serverTimestamp();
      await _firestoreRef
          .doc(docId)
          .set(firestoreData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 3));
      debugPrint('[FirebaseProductService] Firestore simpan produk sukses: $docId');
    } catch (e) {
      debugPrint('[FirebaseProductService] Firestore sync info: $e');
    }

    return docId;
  }

  /// Memperbarui data produk di Firebase
  Future<bool> updateProductInFirebase(
      int id, Map<String, dynamic> updatedData) async {
    final docId = 'prod_$id';
    final Map<String, dynamic> data = Map<String, dynamic>.from(updatedData);

    if (data['harga'] != null) {
      data['harga'] = (data['harga'] as num).toDouble();
    }
    if (data['diskon'] != null) {
      data['diskon'] = (data['diskon'] as num).toDouble();
    }
    if (data['stok'] != null) {
      data['stok'] = (data['stok'] as num).toInt();
    }
    data['updated_at'] = DateTime.now().toIso8601String();

    // 1. Update ke RTDB via REST API
    try {
      final uri = Uri.parse('$rtdbBaseUrl/$collectionName/$docId.json');
      await http.patch(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}

    // 2. Update via RTDB SDK
    try {
      await _rtdbRef.child(docId).update(data).timeout(const Duration(seconds: 3));
    } catch (_) {}

    // 3. Update via Firestore
    try {
      final firestoreData = Map<String, dynamic>.from(data);
      firestoreData['updated_at'] = FieldValue.serverTimestamp();
      await _firestoreRef.doc(docId).set(firestoreData, SetOptions(merge: true));
    } catch (_) {}

    return true;
  }

  /// Menghapus produk dari Firebase
  Future<bool> deleteProductFromFirebase(int id) async {
    final docId = 'prod_$id';

    // 1. Hapus via REST API
    try {
      final uri = Uri.parse('$rtdbBaseUrl/$collectionName/$docId.json');
      await http.delete(uri).timeout(const Duration(seconds: 4));
    } catch (_) {}

    // 2. Hapus via RTDB SDK
    try {
      await _rtdbRef.child(docId).remove();
    } catch (_) {}

    // 3. Hapus via Firestore
    try {
      await _firestoreRef.doc(docId).delete();
    } catch (_) {}

    return true;
  }

  /// Memperbarui diskon produk di Firebase
  Future<bool> updateProductDiscountInFirebase(
      int id, double discountPercent) async {
    return await updateProductInFirebase(id, {'diskon': discountPercent});
  }

  /// Menerapkan diskon kategori di Firebase RTDB
  Future<void> applyCategoryDiscountInFirebase(
      String category, double discountPercent) async {
    try {
      final allProducts = await getAllProductsFromFirebase();
      for (final prod in allProducts) {
        final prodCat = (prod['kategori'] ?? '').toString();
        final prodId = (prod['id'] as num?)?.toInt();
        if (prodId != null) {
          if (category == 'Semua' ||
              category == 'All' ||
              prodCat.toLowerCase().contains(category.toLowerCase())) {
            await updateProductDiscountInFirebase(prodId, discountPercent);
          }
        }
      }
    } catch (e) {
      debugPrint('[FirebaseProductService] Gagal update diskon kategori di Firebase: $e');
    }
  }

  /// Mengambil semua produk dari Firebase Realtime Database
  Future<List<Map<String, dynamic>>> getAllProductsFromFirebase() async {
    try {
      final uri = Uri.parse('$rtdbBaseUrl/$collectionName.json');
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
      debugPrint('[FirebaseProductService] Gagal memuat produk dari RTDB: $e');
    }

    // Fallback: coba dari Cloud Firestore
    try {
      final snapshot = await _firestoreRef.get().timeout(const Duration(seconds: 3));
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) => doc.data()).toList();
      }
    } catch (_) {}

    return [];
  }

  /// Menyinkronkan semua produk lokal SQLite ke Firebase Realtime Database
  Future<int> syncAllLocalProductsToFirebase() async {
    try {
      final localProducts = await DatabaseHelper.instance.getAllProducts();
      int successCount = 0;

      for (final prod in localProducts) {
        final res = await saveProductToFirebase(prod);
        if (res != null) successCount++;
      }

      debugPrint('[FirebaseProductService] 🔄 Sukses sinkronisasi $successCount / ${localProducts.length} produk ke Firebase.');
      return successCount;
    } catch (e) {
      debugPrint('[FirebaseProductService] Gagal sinkronisasi produk ke Firebase: $e');
      return 0;
    }
  }

  /// Mengunduh dan memperbarui produk dari Firebase ke SQLite lokal PC
  Future<int> syncProductsFromFirebase() async {
    try {
      final cloudProducts = await getAllProductsFromFirebase();
      if (cloudProducts.isEmpty) return 0;

      final db = await DatabaseHelper.instance.database;
      int imported = 0;

      for (final cloudItem in cloudProducts) {
        final nama = cloudItem['nama']?.toString();
        if (nama == null || nama.isEmpty) continue;

        final existing = await db.query(
          'products',
          where: 'nama = ?',
          whereArgs: [nama],
          limit: 1,
        );

        final Map<String, dynamic> row = {
          'nama': nama,
          'kategori': cloudItem['kategori'] ?? 'VPS',
          'harga': (cloudItem['harga'] as num?)?.toDouble() ?? 0.0,
          'stok': (cloudItem['stok'] as num?)?.toInt() ?? 0,
          'deskripsi': cloudItem['deskripsi']?.toString(),
          'diskon': (cloudItem['diskon'] as num?)?.toDouble() ?? 0.0,
        };

        if (existing.isNotEmpty) {
          final id = existing.first['id'] as int;
          await db.update('products', row, where: 'id = ?', whereArgs: [id]);
        } else {
          await db.insert('products', row);
        }
        imported++;
      }

      debugPrint('[FirebaseProductService] 📥 Berhasil mengimpor $imported produk dari Cloud ke database SQLite lokal.');
      return imported;
    } catch (e) {
      debugPrint('[FirebaseProductService] Info sync produk dari cloud: $e');
      return 0;
    }
  }
}
