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

    test('isDummyProduct correctly detects test and dummy products', () {
      expect(FirebaseProductService.isDummyProduct({'nama': 'Cloud VPS Ultra Fast 32GB'}), isTrue);
      expect(FirebaseProductService.isDummyProduct({'nama': 'vps test discount'}), isTrue);
      expect(FirebaseProductService.isDummyProduct({'nama': 'VPS Starter'}), isFalse);
    });

    test('saveProductToFirebase saves product to RTDB via REST and returns docId', () async {
      final sampleProd = {
        'id': 1,
        'nama': 'VPS Starter',
        'kategori': 'VPS',
        'harga': 50000.0,
        'stok': 25,
        'deskripsi': '1 vCPU, 1GB RAM, 25GB NVMe SSD',
        'diskon': 0.0,
      };

      final docId = await FirebaseProductService.instance.saveProductToFirebase(sampleProd);
      expect(docId, contains('prod_01_vps_starter'));
    });

    test('updateProductDiscountInFirebase and deleteProductDiscountInFirebase manage discount in RTDB', () async {
      final updated = await FirebaseProductService.instance.updateProductDiscountInFirebase(1, 10.0, productName: 'VPS Starter');
      expect(updated, isTrue);

      final deleted = await FirebaseProductService.instance.deleteProductDiscountInFirebase(1, productName: 'VPS Starter');
      expect(deleted, isTrue);
    });

    test('applyCategoryDiscountInFirebase and deleteCategoryDiscountFromFirebase manage promo discounts in RTDB', () async {
      await FirebaseProductService.instance.applyCategoryDiscountInFirebase('VPS', 0.0);
      await FirebaseProductService.instance.deleteCategoryDiscountFromFirebase('VPS');
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

      // Bersihkan produk tes dari SQLite dan Firebase
      await DatabaseHelper.instance.deleteProduct(id);
      await FirebaseProductService.instance.deleteProductFromFirebase(id);
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

      // Test update transaction
      final updatedData = Map<String, dynamic>.from(txData);
      updatedData['total_harga'] = 120000.0;
      updatedData['status'] = 'Diproses';
      final updateSuccess = await FirebaseTransactionService.instance.updateTransactionInFirebase(
        invoiceNo: txData['invoice_no'].toString(),
        localId: 889,
        updatedData: updatedData,
      );
      expect(updateSuccess, isTrue);

      // Clean up after test
      final deleteSuccess = await FirebaseTransactionService.instance.deleteTransactionFromFirebase(
        invoiceNo: txData['invoice_no'].toString(),
        localId: 889,
      );
      expect(deleteSuccess, isTrue);
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
      expect(docId, contains('srv_881'));

      final services = await FirebaseTransactionService.instance.getAllServicesFromFirebase();
      expect(services, isNotEmpty);
      final foundSrv = services.any((s) => s['user_email'] == 'buyer.service@vibetech.xyz');
      expect(foundSrv, isTrue);

      // Clean up service after test
      await FirebaseTransactionService.instance.deleteServiceFromFirebase(881);
    });
  });
}
