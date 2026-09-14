import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/firebase_auth_token_service.dart';
import 'package:vibetech_xyz/services/firebase_product_service.dart';

import 'dart:io';

void main() {
  setUpAll(() async {
    HttpOverrides.global = null;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  group('Product Creation & Firebase RTDB Sync Tests', () {
    test('createProduct saves product to SQLite and saves to Firebase RTDB', () async {
      final token = await FirebaseAuthTokenService.instance.getIdToken();
      expect(token, isNotNull);

      final productData = {
        'nama': 'Vps 10Gb Test Server',
        'kategori': 'VPS',
        'harga': 120000.0,
        'stok': 15,
        'deskripsi': '10GB RAM, 4 vCPU NVMe Server',
        'diskon': 0.0,
      };

      // 1. Create product via DatabaseHelper
      final newId = await DatabaseHelper.instance.createProduct(productData);
      expect(newId, greaterThan(0));

      // 2. Verify it is immediately loaded by getAllProducts()
      final allProducts = await DatabaseHelper.instance.getAllProducts();
      final foundInLocal = allProducts.any((p) => p['id'] == newId && p['nama'] == 'Vps 10Gb Test Server');
      expect(foundInLocal, isTrue);

      // 3. Verify docId and saving to Firebase
      final docId = await FirebaseProductService.instance.saveProductToFirebase({
        'id': newId,
        ...productData,
      });
      expect(docId, isNotNull);

      // 4. Verify product exists in Firebase RTDB directly via HTTP GET
      final uri = await FirebaseProductService.buildRtdbUri(docId);
      final res = await http.get(uri);
      expect(res.statusCode, 200);
      final remoteData = jsonDecode(res.body);
      expect(remoteData, isNotNull);
      expect(remoteData['nama'], 'Vps 10Gb Test Server');
      expect((remoteData['harga'] as num).toDouble(), 120000.0);

      // 5. Clean up test product
      await DatabaseHelper.instance.deleteProduct(newId);
      await FirebaseProductService.instance.deleteProductFromFirebase(newId, productName: 'Vps 10Gb Test Server');
    });
  });
}
