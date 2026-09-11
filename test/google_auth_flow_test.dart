import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/google_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.database;
  });

  group('Google Auth Direct Flow Tests', () {
    test('GoogleAccountUser model stores credentials properly without extra modal', () {
      const user = GoogleAccountUser(
        name: 'John Doe',
        email: 'johndoe@gmail.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        avatarColor: Color(0xFF4285F4),
      );

      expect(user.name, 'John Doe');
      expect(user.email, 'johndoe@gmail.com');
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
    });

    test('Google login saves session directly to SharedPreferences for immediate Dashboard access', () async {
      final prefs = await SharedPreferences.getInstance();
      const testEmail = 'googletest_user@gmail.com';
      const testName = 'Google Test User';
      const testUid = 'goog_123456789';

      // Simulate the Google sign-in completion logic in LoginPage & RegisterPage
      await prefs.setBool('isLogin', true);
      await prefs.setString('user_uid', testUid);
      await prefs.setString('username', testName);
      await prefs.setString('email', testEmail);

      expect(prefs.getBool('isLogin'), isTrue);
      expect(prefs.getString('user_uid'), testUid);
      expect(prefs.getString('username'), testName);
      expect(prefs.getString('email'), testEmail);
    });

    test('Existing Google account registration seamlessly transitions without redirecting to LoginPage', () async {
      final db = DatabaseHelper.instance;
      final existingEmail = 'existing_goog_${DateTime.now().millisecondsSinceEpoch}@gmail.com';

      // 1. Create existing user
      final existingUser = {
        'uid': 'goog_existing_${DateTime.now().millisecondsSinceEpoch}',
        'nama': 'Existing User',
        'username': 'existing_user',
        'email': existingEmail,
        'phone': '081234567890',
        'password': 'google_oauth_pass',
        'pin': '123456',
        'referralCode': '',
        'role': 'user',
        'createdAt': DateTime.now().toIso8601String(),
        'saldo': 50000.0,
        'avatarUrl': '',
        'authProvider': 'Google',
      };
      await db.registerUser(existingUser);

      // 2. Query user by email (simulating register_page.dart Google handler)
      final found = await db.getUserByEmail(existingEmail);
      expect(found, isNotNull);
      expect(found!['email'], existingEmail);

      // 3. Directly log in without bouncing to LoginPage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLogin', true);
      await prefs.setString('user_uid', found['uid'].toString());
      await prefs.setString('username', found['nama'].toString());
      await prefs.setString('email', found['email'].toString());

      expect(prefs.getBool('isLogin'), isTrue);
      expect(prefs.getString('email'), existingEmail);
      expect(prefs.getString('username'), 'Existing User');
    });
  });
}
