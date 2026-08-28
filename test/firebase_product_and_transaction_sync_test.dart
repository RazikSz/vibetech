import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/firebase_product_service.dart';
import 'package:vibetech_xyz/services/firebase_transaction_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Firebase RTDB Product & Transaction Realtime Sync Tests', () {
    test('FirebaseProductService config points to vibetech-xyz RTDB and Firestore', () {
      expect(FirebaseProductService.rtdbBaseUrl,
          'https://vibetech-xyz-default-rtdb.asia-southeast1.firebasedatabase.app');
      expect(FirebaseProductService.collectionName, 'products');
      expect(FirebaseProductService.databaseId, 'vibetech-xyz');
    });

    test('saveProductToFirebase saves product to RTDB via REST and returns docId', () async {
      final sampleProd = {
        'id': 991,
        'nama': 'Cloud VPS Ultra Fast 32GB',
        'kategori': 'VPS',
        'harga': 350000.0,
        'stok': 5,
        'deskripsi': '8 vCPU, 32GB RAM, 200GB NVMe SSD',
        'diskon': 10.0,
      };

      final docId = await FirebaseProductService.instance.saveProductToFirebase(sampleProd);
      expect(docId, 'prod_991');

      final products = await FirebaseProductService.instance.getAllProductsFromFirebase();
      expect(products, isNotEmpty);
      final found = products.any((p) => (p['nama'] ?? '').toString().contains('Cloud VPS Ultra Fast 32GB'));
      expect(found, isTrue);
    });

    test('updateProductDiscountInFirebase updates discount percentage in RTDB', () async {
      final updated = await FirebaseProductService.instance.updateProductDiscountInFirebase(991, 25.0);
      expect(updated, isTrue);
    });

    test('DatabaseHelper.createProduct auto-syncs product to RTDB and SQLite', () async {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newProd = {
        'nama': 'Panel Pterodactyl Auto $timestamp',
        'kategori': 'Panel Hosting',
        'harga': 45000.0,
        'stok': 12,
        'deskripsi': '4GB RAM Node Singapore',
        'diskon': 0.0,
      };

      final id = await DatabaseHelper.instance.createProduct(newProd);
      expect(id, greaterThan(0));

      final allLocal = await DatabaseHelper.instance.getAllProducts();
      expect(allLocal.any((p) => p['nama'] == newProd['nama']), isTrue);
    });

    test('FirebaseTransactionService saves transaction to RTDB and syncs across devices', () async {
      final txData = {
        'invoice_no': 'INV-RTDB-TEST-${DateTime.now().millisecondsSinceEpoch}',
        'user_email': 'test.crossdevice@vibetech.xyz',
        'nama_produk': 'VPS Pro (Cross-Device Sync)',
        'jumlah': 1,
        'total_harga': 95000.0,
        'tanggal': DateTime.now().toIso8601String(),
        'status': 'Selesai',
        'payment_method': 'VibeWallet',
        'notes': 'Sync test transaction',
      };

      final docId = await FirebaseTransactionService.instance.saveTransactionToFirebase(txData);
      expect(docId, isNotNull);

      final userTx = await FirebaseTransactionService.instance.getTransactionsByUser('test.crossdevice@vibetech.xyz');
      expect(userTx, isNotEmpty);
      expect(userTx.any((t) => t['invoice_no'] == txData['invoice_no']), isTrue);

      // Clean up after test
      await FirebaseTransactionService.instance.deleteTransactionFromFirebase(invoiceNo: txData['invoice_no'].toString());
    });

    test('FirebaseTransactionService saves and syncs purchased services to RTDB', () async {
      final srvData = {
        'id': 881,
        'user_email': 'buyer.service@vibetech.xyz',
        'nama_produk': 'VPS Starter Ubuntu 22.04',
        'kategori': 'VPS',
        'harga': 50000.0,
        'tanggal_beli': DateTime.now().toIso8601String(),
        'tanggal_kadaluarsa': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'status': 'Aktif',
        'ip_address': '103.189.201.44',
        'port': '22',
        'username': 'root',
        'password': 'StrongSecurePassword123!',
      };

      final docId = await FirebaseTransactionService.instance.saveServiceToFirebase(srvData);
      expect(docId, 'srv_881');

      final services = await FirebaseTransactionService.instance.getAllServicesFromFirebase();
      expect(services, isNotEmpty);
      final foundSrv = services.any((s) => s['user_email'] == 'buyer.service@vibetech.xyz');
      expect(foundSrv, isTrue);

      // Clean up service after test
      await FirebaseTransactionService.instance.deleteServiceFromFirebase(881);
    });
  });
}
