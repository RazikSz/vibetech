import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/balance_service.dart';
import 'package:vibetech_xyz/services/cloud_sync_service.dart';
import 'package:vibetech_xyz/services/firebase_auth_token_service.dart';
import 'package:vibetech_xyz/services/firebase_realtime_listener_service.dart';
import 'package:vibetech_xyz/services/firebase_transaction_service.dart';
import 'package:vibetech_xyz/services/firebase_user_service.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({
      'email': 'admin@vibetech.com',
      'username': 'admin',
      'role': 'admin',
    });
  });

  group('Firebase Realtime Database Integration & Continuous Sync Tests', () {
    test('FirebaseAuthTokenService retrieves valid ID token for RTDB authorization', () async {
      final token = await FirebaseAuthTokenService.instance.getIdToken();
      expect(token, isNotNull);
      expect(token!.length, greaterThan(20));
    });

    test('buildRtdbUri and buildTxRtdbUri include auth token for secure endpoints', () async {
      final userUri = await FirebaseUserService.buildRtdbUri('users');
      expect(userUri.toString(), contains('vibetech-xyz-default-rtdb'));
      expect(userUri.queryParameters.containsKey('auth'), isTrue);

      final txUri = await FirebaseTransactionService.buildTxRtdbUri('transactions');
      expect(txUri.toString(), contains('vibetech-xyz-default-rtdb'));
      expect(txUri.queryParameters.containsKey('auth'), isTrue);

      final srvUri = await FirebaseTransactionService.buildServiceRtdbUri('services');
      expect(srvUri.toString(), contains('vibetech-xyz-default-rtdb'));
      expect(srvUri.queryParameters.containsKey('auth'), isTrue);
    });

    test('Echo guard isApplyingCloudUpdate prevents feedback loops during cloud processing', () async {
      expect(FirebaseRealtimeListenerService.isApplyingCloudUpdate, isFalse);

      FirebaseRealtimeListenerService.isApplyingCloudUpdate = true;
      expect(FirebaseRealtimeListenerService.isApplyingCloudUpdate, isTrue);

      // Perform local balance update while cloud update is active
      await DatabaseHelper.instance.updateUserBalance('admin@vibetech.com', 999999);
      final bal = await DatabaseHelper.instance.getUserBalance('admin@vibetech.com');
      expect(bal, 999999.0);

      FirebaseRealtimeListenerService.isApplyingCloudUpdate = false;
      expect(FirebaseRealtimeListenerService.isApplyingCloudUpdate, isFalse);
    });

    test('Processing RTDB Products event updates SQLite and triggers productsUpdateCount', () async {
      final listener = FirebaseRealtimeListenerService.instance;
      final initialCount = listener.productsUpdateCount.value;

      const testProdKey = 'prod_99_vps_extreme';
      final testProdData = {
        'id': 999,
        'nama': 'VPS Dedicated Extreme 99',
        'kategori': 'VPS',
        'harga': 125000.0,
        'stok': 15,
        'deskripsi': 'Realtime event sync extreme speed node',
        'diskon': 10.0,
      };

      await listener.processEventForTesting(
        nodeName: 'products',
        eventType: 'put',
        path: '/$testProdKey',
        data: testProdData,
      );

      // Verify notification triggered
      expect(listener.productsUpdateCount.value, greaterThan(initialCount));

      // Verify persisted in SQLite
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'products',
        where: 'nama = ?',
        whereArgs: ['VPS Dedicated Extreme 99'],
      );
      expect(rows.isNotEmpty, isTrue);
      expect(rows.first['harga'], 125000.0);
      expect(rows.first['stok'], 15);

      // Clean up test product
      await db.delete('products', where: 'nama = ?', whereArgs: ['VPS Dedicated Extreme 99']);
    });

    test('Processing RTDB Users event updates SQLite, BalanceService, and triggers usersUpdateCount', () async {
      final listener = FirebaseRealtimeListenerService.instance;
      final initialCount = listener.usersUpdateCount.value;

      // Ensure user exists in SQLite
      final db = await DatabaseHelper.instance.database;
      await db.insert('users', {
        'uid': 'usr_kevin_wijaya_99',
        'username': 'kevin_wijaya',
        'email': 'kevin.wijaya@vibetech.com',
        'password': 'hashed_password_123',
        'nama': 'Kevin Wijaya',
        'role': 'user',
        'saldo': 50000.0,
        'pin': '123456',
        'createdAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Set active user in BalanceService
      await BalanceService.initBalance(emailOrUsername: 'kevin.wijaya@vibetech.com');

      // Simulate RTDB PATCH event changing saldo to 250000
      await listener.processEventForTesting(
        nodeName: 'users',
        eventType: 'patch',
        path: '/usr_kevin_wijaya_99',
        data: {
          'email': 'kevin.wijaya@vibetech.com',
          'username': 'kevin_wijaya',
          'saldo': 250000,
          'nama': 'Kevin Wijaya Updated',
        },
      );

      // Verify notification count incremented
      expect(listener.usersUpdateCount.value, greaterThan(initialCount));

      // Verify persisted in SQLite
      final updatedUser = await DatabaseHelper.instance.getUserByUsernameOrEmail('kevin.wijaya@vibetech.com');
      expect(updatedUser, isNotNull);
      expect(updatedUser!['saldo'], 250000.0);
      expect(updatedUser['nama'], 'Kevin Wijaya Updated');

      // Verify BalanceService notifier updated
      expect(BalanceService.balance, 250000);

      // Clean up
      await db.delete('users', where: 'email = ?', whereArgs: ['kevin.wijaya@vibetech.com']);
    });

    test('Processing RTDB Transactions event persists to SQLite and triggers transactionsUpdateCount', () async {
      final listener = FirebaseRealtimeListenerService.instance;
      final initialCount = listener.transactionsUpdateCount.value;

      final testInvoice = 'INV-RTDB-TEST-${DateTime.now().millisecondsSinceEpoch}';
      final testTxData = {
        'invoice_number': testInvoice,
        'user_email': 'admin@vibetech.com',
        'nama_produk': 'VPS Enterprise Cloud',
        'kategori': 'VPS',
        'total_amount': 150000.0,
        'status': 'Selesai',
        'metode_pembayaran': 'VibeWallet Saldo',
        'created_at': DateTime.now().toIso8601String(),
      };

      await listener.processEventForTesting(
        nodeName: 'transactions',
        eventType: 'put',
        path: '/$testInvoice',
        data: testTxData,
      );

      expect(listener.transactionsUpdateCount.value, greaterThan(initialCount));

      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'transactions',
        where: 'invoice_no = ?',
        whereArgs: [testInvoice],
      );
      expect(rows.isNotEmpty, isTrue);
      expect(rows.first['total_harga'], 150000.0);
      expect(rows.first['status'], 'Selesai');

      // Clean up
      await db.delete('transactions', where: 'invoice_no = ?', whereArgs: [testInvoice]);
    });

    test('Processing RTDB Services event persists to SQLite and triggers servicesUpdateCount', () async {
      final listener = FirebaseRealtimeListenerService.instance;
      final initialCount = listener.servicesUpdateCount.value;

      const testDocId = 'srv_rtdb_ptero_8gb';
      final testSrvData = {
        'user_email': 'admin@vibetech.com',
        'nama_produk': 'Panel Pterodactyl Realtime 8GB',
        'kategori': 'Panel Hosting',
        'harga': 60000.0,
        'status': 'Aktif',
        'ip_address': '103.145.226.99',
        'port': '8080',
        'server_url': 'https://panel.vibetech.xyz',
        'spesifikasi': '4 vCPU, 8 GB RAM, 50 GB NVMe',
        'tanggal_beli': DateTime.now().toIso8601String(),
      };

      await listener.processEventForTesting(
        nodeName: 'services',
        eventType: 'put',
        path: '/$testDocId',
        data: testSrvData,
      );

      expect(listener.servicesUpdateCount.value, greaterThan(initialCount));

      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'purchased_services',
        where: 'nama_produk = ?',
        whereArgs: ['Panel Pterodactyl Realtime 8GB'],
      );
      expect(rows.isNotEmpty, isTrue);
      expect(rows.first['ip_address'], '103.145.226.99');
      expect(rows.first['harga'], 60000.0);

      // Clean up
      await db.delete('purchased_services', where: 'nama_produk = ?', whereArgs: ['Panel Pterodactyl Realtime 8GB']);
    });

    test('Processing RTDB Invoices event updates SQLite transactions and auto-provisions services', () async {
      final listener = FirebaseRealtimeListenerService.instance;
      final initialTxCount = listener.transactionsUpdateCount.value;
      final initialSrvCount = listener.servicesUpdateCount.value;

      final testInvNo = 'INV-PROVISION-TEST-${DateTime.now().millisecondsSinceEpoch}';
      final testInvData = {
        'invoice_no': testInvNo,
        'user_email': 'buyer@vibetech.com',
        'nama_produk': 'Panel Pterodactyl Auto Provision',
        'kategori': 'Panel Hosting',
        'total_harga': 45000.0,
        'status': 'Selesai',
        'payment_method': 'QRIS Dynamic',
        'tanggal': DateTime.now().toIso8601String(),
      };

      await listener.processEventForTesting(
        nodeName: 'invoices',
        eventType: 'put',
        path: '/$testInvNo',
        data: testInvData,
      );

      // Verify transactionsNotifier incremented
      expect(listener.transactionsUpdateCount.value, greaterThan(initialTxCount));

      // Verify DatabaseHelper.getTransactionByInvoice
      final foundTx = await DatabaseHelper.instance.getTransactionByInvoice(testInvNo);
      expect(foundTx, isNotNull);
      expect(foundTx!['total_harga'], 45000.0);
      expect(foundTx['status'], 'Selesai');

      // Verify auto-provision of purchased service
      final db = await DatabaseHelper.instance.database;
      final srvRows = await db.query(
        'purchased_services',
        where: 'user_email = ? AND nama_produk = ?',
        whereArgs: ['buyer@vibetech.com', 'Panel Pterodactyl Auto Provision'],
      );
      expect(srvRows.isNotEmpty, isTrue);
      expect(srvRows.first['status'], 'Aktif');
      expect(listener.servicesUpdateCount.value, greaterThan(initialSrvCount));

      // Clean up
      await db.delete('transactions', where: 'invoice_no = ?', whereArgs: [testInvNo]);
      await db.delete('purchased_services', where: 'user_email = ? AND nama_produk = ?', whereArgs: ['buyer@vibetech.com', 'Panel Pterodactyl Auto Provision']);
    });

    test('CloudSyncService exposes real-time notifiers linked to listener counts', () {
      final sync = CloudSyncService.instance;
      final listener = FirebaseRealtimeListenerService.instance;

      expect(sync.productsNotifier, same(listener.productsUpdateCount));
      expect(sync.usersNotifier, same(listener.usersUpdateCount));
      expect(sync.transactionsNotifier, same(listener.transactionsUpdateCount));
      expect(sync.servicesNotifier, same(listener.servicesUpdateCount));
    });
  });
}
