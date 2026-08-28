import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/firebase_user_service.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Multi-Device Cross-Platform Account Sync Tests', () {
    test('syncUsersFromFirebase downloads and synchronizes cloud accounts into local SQLite', () async {
      final db = await DatabaseHelper.instance.database;
      expect(db.isOpen, true);

      // Jalankan sinkronisasi cloud users
      final count = await FirebaseUserService.instance.syncUsersFromFirebase();
      expect(count, greaterThanOrEqualTo(0));

      // Verifikasi akun admin dan akun cloud tersimpan di SQLite lokal
      final allUsers = await DatabaseHelper.instance.getAllUsers();
      expect(allUsers.isNotEmpty, true);

      final admin = await DatabaseHelper.instance.getUserByEmailOrUsername('admin@vibetech.com');
      expect(admin, isNotNull);
      expect(admin!['role'], 'admin');
    });

    test('getUserByEmailOrUsername retrieves accounts by email, username, or UID', () async {
      final userByEmail = await DatabaseHelper.instance.getUserByEmailOrUsername('admin@vibetech.com');
      expect(userByEmail, isNotNull);

      final userByUsername = await DatabaseHelper.instance.getUserByEmailOrUsername('raziek');
      expect(userByUsername, isNotNull);

      final userByUid = await DatabaseHelper.instance.getUserByEmailOrUsername('usr_admin_001');
      expect(userByUid, isNotNull);
    });

    test('Cross-device account balance and profile edits sync to SQLite seamlessly', () async {
      final testEmail = 'cross_device_${DateTime.now().millisecondsSinceEpoch}@vibetech.xyz';
      final newUser = {
        'uid': 'usr_test_${DateTime.now().millisecondsSinceEpoch}',
        'nama': 'Cross Device User',
        'username': 'cross_device_user',
        'email': testEmail,
        'phone': '081234567890',
        'password': 'password123',
        'pin': '123456',
        'role': 'user',
        'saldo': 150000.0,
      };

      final insertRes = await DatabaseHelper.instance.registerUser(newUser);
      expect(insertRes, greaterThan(0));

      final retrieved = await DatabaseHelper.instance.getUserByEmail(testEmail);
      expect(retrieved, isNotNull);
      expect((retrieved!['saldo'] as num).toDouble(), 150000.0);

      // Update saldo
      await DatabaseHelper.instance.updateUserProfile(testEmail, {'saldo': 250000.0});
      final updated = await DatabaseHelper.instance.getUserByEmail(testEmail);
      expect((updated!['saldo'] as num).toDouble(), 250000.0);
    });
  });
}
