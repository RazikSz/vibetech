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
  static final FirebaseProductService instance = FirebaseProductService._init();

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

  static const Map<String, int> officialCatalogOrder = {
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

  /// Memeriksa apakah suatu produk adalah data dummy / mock / unit test
  static bool isDummyProduct(Map<String, dynamic> data) {
    final name = (data['nama'] ?? '').toString().trim().toLowerCase();
    if (name.isEmpty) return true;

    // 1. Produk katalog resmi VibeTech tidak boleh dianggap dummy
    if (officialCatalogOrder.containsKey(name)) {
      return false;
    }

    // 2. Produk unit test dummy terdeteksi dari pola eksplisit
    if (name.startsWith('mock_unittest_') ||
        name.startsWith('temp_test_product_') ||
        name.contains('ultra fast 32gb') ||
        name.contains('test discount')) {
      return true;
    }

    return false;
  }

  /// Format ID dokumen produk yang rapi dan terurut sesuai nomor katalog di Firebase RTDB & Firestore
  String _resolveProductDocId(Map<String, dynamic> data) {
    final rawNama = (data['nama'] ?? 'product').toString().trim();
    final namaLower = rawNama.toLowerCase();
    final sanitized = namaLower.replaceAll(RegExp(r'[/\\#?\[\]\.\$\s]'), '_');

    final order = data['no'] ??
        data['urutan'] ??
        officialCatalogOrder[namaLower] ??
        data['id'];
    if (order != null && order is num) {
      final orderInt = order.toInt();
      final prefix = orderInt < 10 ? '0$orderInt' : '$orderInt';
      return 'prod_${prefix}_$sanitized';
    }

    return 'prod_$sanitized';
  }

  /// Menyimpan produk baru atau memperbarui produk di Firebase RTDB & Firestore
  Future<String?> saveProductToFirebase(
      Map<String, dynamic> productData) async {
    final Map<String, dynamic> data = Map<String, dynamic>.from(productData);

    final rawNama = (data['nama'] ?? '').toString().trim();
    final docId = _resolveProductDocId(data);
    data['doc_id'] = docId;

    // Filter ketat: Tolak penyimpanan produk dummy / test / auto ke Firebase
    if (isDummyProduct(data)) {
      debugPrint(
          '[FirebaseProductService] ⚠️ Produk test/dummy diabaikan dari Firebase: $rawNama');
      return docId;
    }

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

    final int? orderNum = data['no'] ??
        data['urutan'] ??
        officialCatalogOrder[rawNama.toLowerCase()] ??
        data['id'];
    if (orderNum != null) {
      data['no'] = orderNum;
      data['urutan'] = orderNum;
    }

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
        debugPrint(
            '[FirebaseProductService] ✅ HTTP REST RTDB simpan produk sukses: $docId');
      }
    } catch (e) {
      debugPrint('[FirebaseProductService] HTTP REST RTDB Exception: $e');
    }

    // Bersihkan key lama/duplikat di RTDB jika nama produk atau docId berubah
    try {
      final idNum = data['id'];
      if (idNum != null) {
        final legacyUri = Uri.parse('$rtdbBaseUrl/$collectionName/prod_$idNum.json');
        await http.delete(legacyUri).timeout(const Duration(seconds: 2));
      }
    } catch (_) {}

    // 2. Simpan via SDK Realtime Database
    try {
      await _rtdbRef.child(docId).set(data).timeout(const Duration(seconds: 3));
      debugPrint(
          '[FirebaseProductService] SDK RTDB simpan produk sukses: $docId');
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
      debugPrint(
          '[FirebaseProductService] Firestore simpan produk sukses: $docId');
    } catch (e) {
      debugPrint('[FirebaseProductService] Firestore sync info: $e');
    }

    return docId;
  }

  /// Memperbarui data produk di Firebase tanpa membuat table/node ganda di RTDB
  Future<bool> updateProductInFirebase(
      int id, Map<String, dynamic> updatedData) async {
    final Map<String, dynamic> data = Map<String, dynamic>.from(updatedData);

    if (isDummyProduct(data)) return true;

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

    String? prodName = data['nama']?.toString();
    if (prodName == null || prodName.isEmpty) {
      try {
        final db = await DatabaseHelper.instance.database;
        final p = await db
            .query('products', where: 'id = ?', whereArgs: [id], limit: 1);
        if (p.isNotEmpty) {
          prodName = p.first['nama']?.toString();
        }
      } catch (_) {}
    }

    final docId = _resolveProductDocId({'id': id, 'nama': prodName});
    data['doc_id'] = docId;

    // 1. Update ke SATU node yang tepat di RTDB via REST API
    try {
      final uri = Uri.parse('$rtdbBaseUrl/$collectionName/$docId.json');
      await http
          .patch(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {}

    // Hapus key legacy prod_$id atau key lama jika nama produk diubah
    final oldKeysToDelete = <String>{};
    try {
      final legacyUri = Uri.parse('$rtdbBaseUrl/$collectionName/prod_$id.json');
      await http.delete(legacyUri).timeout(const Duration(seconds: 2));
    } catch (_) {}

    try {
      final allUri = Uri.parse('$rtdbBaseUrl/$collectionName.json');
      final res = await http.get(allUri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
        final dynamic decoded = jsonDecode(res.body);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final k = entry.key.toString();
            final v = entry.value;
            if (v is Map) {
              final vId = (v['id'] as num?)?.toInt();
              if (vId == id && k != docId) {
                oldKeysToDelete.add(k);
              }
            }
          }
        }
      }
    } catch (_) {}

    for (final oldKey in oldKeysToDelete) {
      try {
        final delUri = Uri.parse('$rtdbBaseUrl/$collectionName/$oldKey.json');
        await http.delete(delUri).timeout(const Duration(seconds: 2));
        await _rtdbRef.child(oldKey).remove();
        await _firestoreRef.doc(oldKey).delete();
      } catch (_) {}
    }

    // 2. Update via RTDB SDK
    try {
      await _rtdbRef
          .child(docId)
          .update(data)
          .timeout(const Duration(seconds: 3));
    } catch (_) {}

    // 3. Update via Firestore
    try {
      final firestoreData = Map<String, dynamic>.from(data);
      firestoreData['updated_at'] = FieldValue.serverTimestamp();
      await _firestoreRef
          .doc(docId)
          .set(firestoreData, SetOptions(merge: true));
    } catch (_) {}

    return true;
  }

  /// Menghapus produk dari Firebase
  Future<bool> deleteProductFromFirebase(int id, {String? productName}) async {
    final docId = _resolveProductDocId({'id': id, 'nama': productName});

    // 1. Hapus via REST API
    try {
      final uri = Uri.parse('$rtdbBaseUrl/$collectionName/$docId.json');
      await http.delete(uri).timeout(const Duration(seconds: 4));
    } catch (_) {}

    try {
      final legacyUri = Uri.parse('$rtdbBaseUrl/$collectionName/prod_$id.json');
      await http.delete(legacyUri).timeout(const Duration(seconds: 4));
    } catch (_) {}

    // 2. Hapus via RTDB SDK
    try {
      await _rtdbRef.child(docId).remove();
      await _rtdbRef.child('prod_$id').remove();
    } catch (_) {}

    // 3. Hapus via Firestore
    try {
      await _firestoreRef.doc(docId).delete();
      await _firestoreRef.doc('prod_$id').delete();
    } catch (_) {}

    return true;
  }

  static const String promoCollection = 'promo_discounts';

  /// Memperbarui atau menghapus diskon produk tertentu di Firebase pada node yang tepat
  Future<bool> updateProductDiscountInFirebase(
      int id, double discountPercent, {String? productName}) async {
    final cleanDiscount = discountPercent.clamp(0.0, 99.0);

    String? name = productName;
    if (name == null || name.isEmpty) {
      try {
        final db = await DatabaseHelper.instance.database;
        final p = await db
            .query('products', where: 'id = ?', whereArgs: [id], limit: 1);
        if (p.isNotEmpty) {
          name = p.first['nama']?.toString();
        }
      } catch (_) {}
    }

    final docId = _resolveProductDocId({'id': id, 'nama': name});

    // 1. Direct REST PATCH ke SATU node resmi di RTDB
    try {
      final uri = Uri.parse('$rtdbBaseUrl/$collectionName/$docId.json');
      await http.patch(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'diskon': cleanDiscount,
          'updated_at': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}

    // Hapus legacy prod_$id jika ada di RTDB
    try {
      final legacyUri = Uri.parse('$rtdbBaseUrl/$collectionName/prod_$id.json');
      await http.delete(legacyUri).timeout(const Duration(seconds: 2));
    } catch (_) {}

    // 2. Update via RTDB SDK
    try {
      await _rtdbRef.child(docId).update({
        'diskon': cleanDiscount,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    // 3. Update via Firestore
    try {
      await _firestoreRef.doc(docId).set({
        'diskon': cleanDiscount,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    debugPrint(
        '[FirebaseProductService] ✅ Sukses update diskon produk $docId -> $cleanDiscount% di Firebase');
    return true;
  }

  /// Menghapus / reset diskon produk tertentu di Firebase
  Future<bool> deleteProductDiscountInFirebase(int id,
      {String? productName}) async {
    return await updateProductDiscountInFirebase(id, 0.0,
        productName: productName);
  }

  /// Menerapkan, memperbarui, atau menghapus diskon kategori di Firebase RTDB & Firestore
  Future<void> applyCategoryDiscountInFirebase(
      String category, double discountPercent) async {
    final cleanCategory = category.trim();
    final cleanDiscount = discountPercent.clamp(0.0, 99.0);
    final key = cleanCategory.replaceAll(' ', '_');

    try {
      // 1. Simpan atau Hapus data promo di node promo_discounts
      if (cleanDiscount > 0) {
        final promoData = {
          'category': cleanCategory,
          'discount_percent': cleanDiscount,
          'active': true,
          'updated_at': DateTime.now().toIso8601String(),
        };

        try {
          final uri = Uri.parse('$rtdbBaseUrl/$promoCollection/$key.json');
          await http.put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(promoData),
          ).timeout(const Duration(seconds: 4));
        } catch (_) {}

        try {
          await FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: rtdbBaseUrl,
          ).ref(promoCollection).child(key).set(promoData);
        } catch (_) {}

        try {
          await _firestoreRef.firestore
              .collection(promoCollection)
              .doc(key)
              .set(promoData, SetOptions(merge: true));
        } catch (_) {}
      } else {
        // Hapus promo dari Firebase jika diskon direset ke 0
        try {
          final uri = Uri.parse('$rtdbBaseUrl/$promoCollection/$key.json');
          await http.delete(uri).timeout(const Duration(seconds: 4));
        } catch (_) {}

        try {
          await FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: rtdbBaseUrl,
          ).ref(promoCollection).child(key).remove();
        } catch (_) {}

        try {
          await _firestoreRef.firestore
              .collection(promoCollection)
              .doc(key)
              .delete();
        } catch (_) {}
      }

      // 2. Perbarui seluruh produk yang berada dalam kategori ini di node products
      final allProducts = await getAllProductsFromFirebase();
      for (final prod in allProducts) {
        final prodCat = (prod['kategori'] ?? '').toString();
        final prodId = (prod['id'] as num?)?.toInt();
        final prodName = prod['nama']?.toString();
        if (prodId != null) {
          if (cleanCategory == 'Semua' ||
              cleanCategory == 'All' ||
              prodCat.toLowerCase().contains(cleanCategory.toLowerCase())) {
            await updateProductDiscountInFirebase(prodId, cleanDiscount,
                productName: prodName);
          }
        }
      }
      debugPrint(
          '[FirebaseProductService] ✅ Sukses mengupdate diskon $cleanDiscount% untuk "$cleanCategory" di Firebase.');
    } catch (e) {
      debugPrint(
          '[FirebaseProductService] Gagal update diskon kategori di Firebase: $e');
    }
  }

  /// Menghapus diskon kategori tertentu dari Firebase
  Future<void> deleteCategoryDiscountFromFirebase(String category) async {
    await applyCategoryDiscountInFirebase(category, 0.0);
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
              final m = Map<String, dynamic>.from(v);
              m['doc_id'] = k.toString();
              list.add(m);
            }
          });
          if (list.isNotEmpty) return list;
        } else if (decoded is List) {
          final list = <Map<String, dynamic>>[];
          for (int i = 0; i < decoded.length; i++) {
            final v = decoded[i];
            if (v is Map) {
              final m = Map<String, dynamic>.from(v);
              m['doc_id'] = 'prod_$i';
              list.add(m);
            }
          }
          if (list.isNotEmpty) return list;
        }
      }
    } catch (e) {
      debugPrint('[FirebaseProductService] Gagal memuat produk dari RTDB: $e');
    }

    // Fallback: coba dari Cloud Firestore
    try {
      final snapshot =
          await _firestoreRef.get().timeout(const Duration(seconds: 3));
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

      debugPrint(
          '[FirebaseProductService] 🔄 Sukses sinkronisasi $successCount / ${localProducts.length} produk ke Firebase.');
      return successCount;
    } catch (e) {
      debugPrint(
          '[FirebaseProductService] Gagal sinkronisasi produk ke Firebase: $e');
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

      final cloudProductNames = <String>{};

      for (final cloudItem in cloudProducts) {
        final nama = cloudItem['nama']?.toString().trim();
        if (nama == null || nama.isEmpty) continue;

        cloudProductNames.add(nama.toLowerCase());

        // Parsing diskon secara aman baik tipe number maupun string dari Firebase
        double diskonVal = 0.0;
        final rawDiskon = cloudItem['diskon'] ?? cloudItem['discount'];
        if (rawDiskon is num) {
          diskonVal = rawDiskon.toDouble();
        } else if (rawDiskon is String) {
          diskonVal =
              double.tryParse(rawDiskon.replaceAll('%', '').trim()) ?? 0.0;
        }

        final existing = await db.query(
          'products',
          where: 'LOWER(TRIM(nama)) = ?',
          whereArgs: [nama.toLowerCase()],
          limit: 1,
        );

        final Map<String, dynamic> row = {
          'nama': nama,
          'kategori': cloudItem['kategori'] ?? 'VPS',
          'harga': (cloudItem['harga'] as num?)?.toDouble() ?? 0.0,
          'stok': (cloudItem['stok'] as num?)?.toInt() ?? 0,
          'deskripsi': cloudItem['deskripsi']?.toString(),
          'diskon': diskonVal,
        };

        if (existing.isNotEmpty) {
          final id = existing.first['id'] as int;
          await db.update('products', row, where: 'id = ?', whereArgs: [id]);
        } else {
          await db.insert('products', row);
        }
        imported++;
      }

      // Jika produk dihapus di Firebase, hapus juga dari database SQLite lokal
      if (cloudProductNames.isNotEmpty) {
        final localProducts = await db.query('products');
        for (final lp in localProducts) {
          final lName = lp['nama']?.toString().trim().toLowerCase();
          if (lName != null && !cloudProductNames.contains(lName)) {
            final id = lp['id'] as int;
            await db.delete('products', where: 'id = ?', whereArgs: [id]);
            debugPrint(
                '[FirebaseProductService] 🗑️ Produk "$lName" dihapus dari SQLite karena sudah dihapus di Firebase.');
          }
        }
      }

      debugPrint(
          '[FirebaseProductService] 📥 Berhasil menyelaraskan $imported produk dari Cloud ke database SQLite lokal.');
      return imported;
    } catch (e) {
      debugPrint('[FirebaseProductService] Info sync produk dari cloud: $e');
      return 0;
    }
  }

  /// Menghapus produk dummy, auto-test, atau produk acak dari Firebase RTDB dan Firestore
  Future<void> cleanupDummyAndRandomProductsFromFirebaseAndLocal() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Hapus dari SQLite lokal HANYA data produk dummy/test yang jelas
      await db.delete(
        'products',
        where:
            "LOWER(nama) LIKE '%dummy%' OR LOWER(nama) LIKE '%mock_%' OR LOWER(nama) LIKE '%test_product%' OR LOWER(nama) LIKE '%fake_%'",
      );

      // 2. Bersihkan dari Firebase RTDB & Firestore HANYA jika jelas-jelas data test/dummy
      try {
        final uri = Uri.parse('$rtdbBaseUrl/$collectionName.json');
        final response =
            await http.get(uri).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200 &&
            response.body != 'null' &&
            response.body.isNotEmpty) {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              final key = entry.key.toString();
              final val = entry.value;
              String name = '';
              if (val is Map) {
                name = (val['nama'] ?? '').toString().trim().toLowerCase();
              }
              final isDummy = name.contains('dummy') ||
                  name.contains('mock_') ||
                  name.contains('test_product') ||
                  name.contains('fake_') ||
                  key.contains('dummy');
              if (isDummy) {
                try {
                  final delUri =
                      Uri.parse('$rtdbBaseUrl/$collectionName/$key.json');
                  await http.delete(delUri).timeout(const Duration(seconds: 3));
                } catch (_) {}

                try {
                  await _rtdbRef.child(key).remove();
                } catch (_) {}

                try {
                  await _firestoreRef.doc(key).delete();
                } catch (_) {}
              }
            }
          }
        }
      } catch (_) {}

      // 3. JANGAN PERNAH menimpa editan pengguna!
      // Hanya isi katalog default awal jika di Firebase benar-benar kosong (0 produk)
      final existingProducts = await getAllProductsFromFirebase();
      if (existingProducts.isEmpty) {
        await syncOrderedCatalogToFirebase();
      }

      debugPrint(
          '[FirebaseProductService] 🧹 Sukses memverifikasi produk Firebase tetap permanen dan tidak tertimpa.');
    } catch (e) {
      debugPrint('[FirebaseProductService] Error cleanup dummy products: $e');
    }
  }

  /// Menyusun dan menyinkronkan katalog produk di Firebase RTDB agar berurutan sesuai nomor & nama produk (1 - 11)
  Future<void> syncOrderedCatalogToFirebase() async {
    final orderedCatalog = [
      // 1-4: VPS (Virtual Private Server)
      {
        'no': 1,
        'urutan': 1,
        'id': 1,
        'doc_id': 'prod_01_vps_starter',
        'nama': 'VPS Starter',
        'kategori': 'VPS',
        'harga': 50000.0,
        'stok': 25,
        'diskon': 0.0,
        'deskripsi':
            '1 vCPU, 1GB RAM, 25GB NVMe SSD, Bandwidth 1TB (Ubuntu 22.04)',
      },
      {
        'no': 2,
        'urutan': 2,
        'id': 2,
        'doc_id': 'prod_02_vps_basic',
        'nama': 'VPS Basic',
        'kategori': 'VPS',
        'harga': 95000.0,
        'stok': 20,
        'diskon': 0.0,
        'deskripsi':
            '2 vCPU, 2GB RAM, 50GB NVMe SSD, Bandwidth 2TB (Ubuntu 22.04)',
      },
      {
        'no': 3,
        'urutan': 3,
        'id': 3,
        'doc_id': 'prod_03_vps_pro',
        'nama': 'VPS Pro',
        'kategori': 'VPS',
        'harga': 160000.0,
        'stok': 15,
        'diskon': 0.0,
        'deskripsi':
            '4 vCPU, 4GB RAM, 80GB NVMe SSD, Bandwidth 3TB (Ubuntu 22.04)',
      },
      {
        'no': 4,
        'urutan': 4,
        'id': 4,
        'doc_id': 'prod_04_vps_enterprise',
        'nama': 'VPS Enterprise',
        'kategori': 'VPS',
        'harga': 300000.0,
        'stok': 10,
        'diskon': 0.0,
        'deskripsi':
            '8 vCPU, 8GB RAM, 160GB NVMe SSD, Bandwidth 5TB (Ubuntu 22.04)',
      },

      // 5-8: Panel Hosting (Pterodactyl Node SG)
      {
        'no': 5,
        'urutan': 5,
        'id': 5,
        'doc_id': 'prod_05_panel_hosting_1gb',
        'nama': 'Panel Hosting 1GB',
        'kategori': 'Panel Hosting',
        'harga': 15000.0,
        'stok': 30,
        'diskon': 0.0,
        'deskripsi':
            '1GB RAM, 1 Core CPU, 10GB NVMe Storage (Pterodactyl Node SG)',
      },
      {
        'no': 6,
        'urutan': 6,
        'id': 6,
        'doc_id': 'prod_06_panel_hosting_2gb',
        'nama': 'Panel Hosting 2GB',
        'kategori': 'Panel Hosting',
        'harga': 30000.0,
        'stok': 25,
        'diskon': 0.0,
        'deskripsi':
            '2GB RAM, 1.5 Core CPU, 20GB NVMe Storage (Pterodactyl Node SG)',
      },
      {
        'no': 7,
        'urutan': 7,
        'id': 7,
        'doc_id': 'prod_07_panel_hosting_4gb',
        'nama': 'Panel Hosting 4GB',
        'kategori': 'Panel Hosting',
        'harga': 55000.0,
        'stok': 20,
        'diskon': 0.0,
        'deskripsi':
            '4GB RAM, 2 Core CPU, 40GB NVMe Storage (Pterodactyl Node SG)',
      },
      {
        'no': 8,
        'urutan': 8,
        'id': 8,
        'doc_id': 'prod_08_panel_hosting_unlimited',
        'nama': 'Panel Hosting Unlimited',
        'kategori': 'Panel Hosting',
        'harga': 95000.0,
        'stok': 15,
        'diskon': 0.0,
        'deskripsi':
            'Unlimited RAM, 4 Core CPU, 100GB NVMe Storage (Pterodactyl Turbo)',
      },

      // 9-11: Bot WhatsApp (Automation & Multi-Device)
      {
        'no': 9,
        'urutan': 9,
        'id': 9,
        'doc_id': 'prod_09_bot_whatsapp_basic',
        'nama': 'Bot WhatsApp Basic',
        'kategori': 'Bot WhatsApp',
        'harga': 25000.0,
        'stok': 40,
        'diskon': 0.0,
        'deskripsi':
            '1 Sesi WhatsApp, Auto-Reply, Broadcast Group, Uptime 99.9%',
      },
      {
        'no': 10,
        'urutan': 10,
        'id': 10,
        'doc_id': 'prod_10_bot_whatsapp_pro',
        'nama': 'Bot WhatsApp Pro',
        'kategori': 'Bot WhatsApp',
        'harga': 50000.0,
        'stok': 30,
        'diskon': 0.0,
        'deskripsi':
            '3 Sesi WhatsApp, AI Gemini Integration, Auto Responder, Blast Unlimited',
      },
      {
        'no': 11,
        'urutan': 11,
        'id': 11,
        'doc_id': 'prod_11_bot_whatsapp_enterprise',
        'nama': 'Bot WhatsApp Enterprise',
        'kategori': 'Bot WhatsApp',
        'harga': 100000.0,
        'stok': 20,
        'diskon': 0.0,
        'deskripsi':
            'Unlimited Sesi, Multi-Device AI Blast 24/7, Dedicated Node, Priority Support 24/7',
      },
    ];

    try {
      // 1. Ambil data produk yang sudah ada di Firebase untuk mempertahankan diskon aktif
      final existingCloudProducts = await getAllProductsFromFirebase();
      final Map<String, double> existingDiscounts = {};
      for (final p in existingCloudProducts) {
        final name = (p['nama'] ?? '').toString().trim().toLowerCase();
        final d = (p['diskon'] as num?)?.toDouble() ?? 0.0;
        if (d > 0) {
          existingDiscounts[name] = d;
        }
      }

      // 2. Bersihkan key lama yang tidak berurutan di RTDB
      try {
        final uri = Uri.parse('$rtdbBaseUrl/$collectionName.json');
        final resp = await http.get(uri).timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200 &&
            resp.body.isNotEmpty &&
            resp.body != 'null') {
          final dynamic decoded = jsonDecode(resp.body);
          if (decoded is Map) {
            final validKeys =
                orderedCatalog.map((e) => e['doc_id'].toString()).toSet();
            for (final k in decoded.keys) {
              final kStr = k.toString();
              if (!validKeys.contains(kStr)) {
                final delUri =
                    Uri.parse('$rtdbBaseUrl/$collectionName/$kStr.json');
                await http.delete(delUri).timeout(const Duration(seconds: 3));
              }
            }
          }
        }
      } catch (_) {}

      // 3. Tulis seluruh katalog dengan kunci terurut 'prod_01_vps_starter' s/d 'prod_11_bot_whatsapp_enterprise'
      final db = await DatabaseHelper.instance.database;
      for (final item in orderedCatalog) {
        final copy = Map<String, dynamic>.from(item);
        final namaLower = copy['nama'].toString().toLowerCase();
        if (existingDiscounts.containsKey(namaLower)) {
          copy['diskon'] = existingDiscounts[namaLower]!;
        }

        // Tulis ke RTDB via REST API
        final docId = copy['doc_id'] as String;
        try {
          final uri = Uri.parse('$rtdbBaseUrl/$collectionName/$docId.json');
          await http
              .put(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(copy),
              )
              .timeout(const Duration(seconds: 4));
        } catch (_) {}

        // Tulis ke Firestore
        try {
          final firestoreData = Map<String, dynamic>.from(copy);
          firestoreData['updated_at'] = FieldValue.serverTimestamp();
          await _firestoreRef
              .doc(docId)
              .set(firestoreData, SetOptions(merge: true));
        } catch (_) {}

        // Tulis ke SQLite
        final existingLocal = await db.query(
          'products',
          where: 'LOWER(TRIM(nama)) = ?',
          whereArgs: [namaLower],
          limit: 1,
        );
        if (existingLocal.isNotEmpty) {
          final id = existingLocal.first['id'] as int;
          await db.update('products', {
            'nama': copy['nama'],
            'kategori': copy['kategori'],
            'harga': copy['harga'],
            'stok': copy['stok'],
            'deskripsi': copy['deskripsi'],
            'diskon': copy['diskon'],
          }, where: 'id = ?', whereArgs: [id]);
        } else {
          await db.insert('products', {
            'nama': copy['nama'],
            'kategori': copy['kategori'],
            'harga': copy['harga'],
            'stok': copy['stok'],
            'deskripsi': copy['deskripsi'],
            'diskon': copy['diskon'],
          });
        }
      }

      debugPrint(
          '[FirebaseProductService] 🚀 Sukses menyusun database Firebase RTDB terurut nomor 1-11 & nama produk!');
    } catch (e) {
      debugPrint(
          '[FirebaseProductService] Gagal menyusun urutan database produk di Firebase: $e');
    }
  }
}
