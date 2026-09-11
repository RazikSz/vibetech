import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/firebase_realtime_listener_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  group('All Databases Editable via Firebase RTDB Tests', () {
    test('1. Edit User in Firebase RTDB updates SQLite permanently', () async {
      final db = await DatabaseHelper.instance.database;

      // Seed initial user with createdAt
      await db.delete('users', where: 'username = ?', whereArgs: ['test_edit_user']);
      await db.insert('users', {
        'uid': 'usr_test_edit_001',
        'nama': 'Test User Old',
        'username': 'test_edit_user',
        'email': 'testedit@vibetech.com',
        'saldo': 10000.0,
        'role': 'user',
        'pin': '123456',
        'password': 'oldpassword',
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Simulate admin editing saldo & role in Firebase RTDB console:
      await FirebaseRealtimeListenerService.instance.processEventForTesting(
        nodeName: 'users',
        eventType: 'put',
        path: '/usr_test_edit_user/saldo',
        data: 75000.0,
      );

      await FirebaseRealtimeListenerService.instance.processEventForTesting(
        nodeName: 'users',
        eventType: 'put',
        path: '/usr_test_edit_user/role',
        data: 'administrator',
      );

      final user = await DatabaseHelper.instance.getUserByEmailOrUsername('test_edit_user');
      expect(user, isNotNull);
      expect((user!['saldo'] as num).toDouble(), equals(75000.0));
      expect(user['role'], equals('administrator'));
    });

    test('2. Edit Product in Firebase RTDB updates SQLite permanently', () async {
      final db = await DatabaseHelper.instance.database;

      // Seed product
      await db.delete('products', where: 'nama = ?', whereArgs: ['VPS Super Test']);
      final id = await db.insert('products', {
        'nama': 'VPS Super Test',
        'kategori': 'VPS',
        'harga': 50000.0,
        'stok': 10,
        'diskon': 0.0,
      });

      // Simulate admin editing harga via 'price' alias & stok in Firebase RTDB:
      await FirebaseRealtimeListenerService.instance.processEventForTesting(
        nodeName: 'products',
        eventType: 'put',
        path: '/prod_${id}_vps_super_test/price',
        data: 85000.0,
      );

      await FirebaseRealtimeListenerService.instance.processEventForTesting(
        nodeName: 'products',
        eventType: 'put',
        path: '/prod_${id}_vps_super_test/stok',
        data: 42,
      );

      final p = await db.query('products', where: 'id = ?', whereArgs: [id]);
      expect(p.isNotEmpty, isTrue);
      expect((p.first['harga'] as num).toDouble(), equals(85000.0));
      expect(p.first['stok'], equals(42));
    });

    test('3. Edit Transaction in Firebase RTDB updates status and provisions service', () async {
      final db = await DatabaseHelper.instance.database;

      // Seed transaction Pending
      const inv = 'INV-2026-TEST-999';
      await db.delete('transactions', where: 'invoice_no = ?', whereArgs: [inv]);
      await db.insert('transactions', {
        'invoice_no': inv,
        'user_email': 'buyer@vibetech.com',
        'nama_produk': 'VPS Pro Test',
        'jumlah': 1,
        'total_harga': 150000.0,
        'status': 'Pending',
        'tanggal': DateTime.now().toIso8601String(),
      });

      // Admin updates status in Firebase Console to 'Selesai'
      await FirebaseRealtimeListenerService.instance.processEventForTesting(
        nodeName: 'transactions',
        eventType: 'put',
        path: '/INV_2026_TEST_999/status',
        data: 'Selesai',
      );

      final tx = await DatabaseHelper.instance.getTransactionByInvoice(inv);
      expect(tx, isNotNull);
      expect(tx!['status'], equals('Selesai'));

      // Service should be auto-provisioned
      final srv = await db.query('purchased_services',
          where: 'LOWER(user_email) = ? AND LOWER(nama_produk) = ?',
          whereArgs: ['buyer@vibetech.com', 'vps pro test']);
      expect(srv.isNotEmpty, isTrue);
      expect(srv.first['status'], equals('Aktif'));
    });

    test('4. Edit Service in Firebase RTDB updates SQLite permanently', () async {
      final db = await DatabaseHelper.instance.database;

      await db.delete('purchased_services',
          where: 'user_email = ? AND nama_produk = ?',
          whereArgs: ['client@vibetech.com', 'Panel Hosting 2GB']);
      final id = await db.insert('purchased_services', {
        'user_email': 'client@vibetech.com',
        'nama_produk': 'Panel Hosting 2GB',
        'kategori': 'Panel Hosting',
        'harga': 30000.0,
        'status': 'Aktif',
        'tanggal_beli': DateTime.now().toIso8601String(),
        'tanggal_kadaluarsa': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'ip_address': '10.0.0.1',
      });

      // Admin modifies ip and status in Firebase RTDB
      await FirebaseRealtimeListenerService.instance.processEventForTesting(
        nodeName: 'services',
        eventType: 'put',
        path: '/srv_${id}_panel_hosting_2gb/ip',
        data: '172.16.0.50',
      );

      await FirebaseRealtimeListenerService.instance.processEventForTesting(
        nodeName: 'services',
        eventType: 'put',
        path: '/srv_${id}_panel_hosting_2gb/status',
        data: 'Suspended',
      );

      final s = await db.query('purchased_services', where: 'id = ?', whereArgs: [id]);
      expect(s.isNotEmpty, isTrue);
      expect(s.first['ip_address'], equals('172.16.0.50'));
      expect(s.first['status'], equals('Suspended'));
    });

    test('5. Edit Email SMTP Settings in Firebase RTDB updates SQLite permanently', () async {
      // Simulate admin editing SMTP settings directly in RTDB
      await FirebaseRealtimeListenerService.instance.processEventForTesting(
        nodeName: 'email_settings',
        eventType: 'put',
        path: '/global_config',
        data: {
          'smtp_user': 'supermailer@gmail.com',
          'smtp_pass': 'abcd efgh ijkl mnop',
          'smtp_host': 'smtp.gmail.com',
          'smtp_port': 587,
        },
      );

      final settings = await DatabaseHelper.instance.getEmailSettings();
      expect(settings, isNotNull);
      expect(settings!['smtp_user'], equals('supermailer@gmail.com'));
      expect(settings['smtp_pass'], equals('abcdefghijklmnop'));
      expect(settings['smtp_port'], equals(587));
    });

    test('6. Edit Promo Category Discount in Firebase RTDB applies to products', () async {
      final db = await DatabaseHelper.instance.database;

      await FirebaseRealtimeListenerService.instance.processEventForTesting(
        nodeName: 'promo_discounts',
        eventType: 'put',
        path: '/VPS/discount_percent',
        data: 25.0,
      );

      final vpsProducts = await db.query('products', where: 'kategori = ?', whereArgs: ['VPS']);
      expect(vpsProducts.isNotEmpty, isTrue);
      for (final p in vpsProducts) {
        expect((p['diskon'] as num).toDouble(), equals(25.0));
      }
    });
  });
}
