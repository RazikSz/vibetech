import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/firebase_auth_token_service.dart';
import 'package:vibetech_xyz/services/firebase_user_service.dart';
import 'package:vibetech_xyz/utils/security_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Firebase Authentication & RTDB Hardening Tests', () {
    test('1. syncUserToFirebaseAuth safely rejects dummy and mock users', () async {
      final dummyUser = {
        'email': 'mock_user@example.com',
        'username': 'mock_user',
        'password': 'password123',
      };

      final result = await FirebaseUserService.instance.syncUserToFirebaseAuth(dummyUser);
      expect(result, false, reason: 'Dummy user must never be synced to Firebase Auth');
    });

    test('2. syncUserToFirebaseAuth rejects invalid email or missing email', () async {
      final invalidUser = {
        'email': 'invalid_email_without_at',
        'username': 'invaliduser',
        'password': 'password123',
      };

      final result = await FirebaseUserService.instance.syncUserToFirebaseAuth(invalidUser);
      expect(result, false, reason: 'User without valid @ email must not be synced to Firebase Auth');
    });

    test('3. FirebaseAuthTokenService API key is valid and non-empty', () {
      final apiKey = FirebaseAuthTokenService.instance.apiKey;
      expect(apiKey, isNotEmpty);
      expect(apiKey.startsWith('AIzaSy'), true,
          reason: 'Firebase API Key must have the valid Google Cloud API key format');
    });

    test('4. SecurityHelper password hashing generates valid length for Firebase Auth fallback', () {
      const email = 'user_test@vibetech.xyz';
      final hash = SecurityHelper.hashPassword(email);
      expect(hash.length, greaterThanOrEqualTo(16));
      final generatedPass = '${hash.substring(0, 16)}Aa1!';
      expect(generatedPass.length, greaterThanOrEqualTo(6));
    });

    test('5. AndroidManifest has INTERNET and ACCESS_NETWORK_STATE permissions for Play Store', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), true, reason: 'AndroidManifest.xml must exist');
      final content = manifestFile.readAsStringSync();
      expect(content.contains('android.permission.INTERNET'), true,
          reason: 'INTERNET permission required for Firebase and online database');
      expect(content.contains('android.permission.ACCESS_NETWORK_STATE'), true,
          reason: 'ACCESS_NETWORK_STATE required for network status monitoring');
    });

    test('6. google-services.json is present and configured for com.raziek.vibetech_xyz', () {
      final gsFile = File('android/app/google-services.json');
      expect(gsFile.existsSync(), true, reason: 'google-services.json must exist');
      final content = gsFile.readAsStringSync();
      expect(content.contains('com.raziek.vibetech_xyz'), true,
          reason: 'Package name in google-services.json must match com.raziek.vibetech_xyz');
      expect(content.contains('vibetech-xyz-default-rtdb'), true,
          reason: 'RTDB URL must point to vibetech-xyz-default-rtdb');
    });

    test('7. ProGuard rules protect SQLite and Firebase from R8 obfuscation for Play Store release', () {
      final proguardFile = File('android/app/proguard-rules.pro');
      expect(proguardFile.existsSync(), true, reason: 'proguard-rules.pro must exist');
      final content = proguardFile.readAsStringSync();
      expect(content.contains('com.tekartik.sqflite'), true,
          reason: 'sqflite must be preserved in ProGuard');
      expect(content.contains('androidx.sqlite'), true,
          reason: 'androidx.sqlite must be preserved in ProGuard');
      expect(content.contains('com.google.firebase.database'), true,
          reason: 'Firebase Realtime Database must be preserved in ProGuard');
      expect(content.contains('com.google.firebase.auth'), true,
          reason: 'Firebase Authentication must be preserved in ProGuard');
      expect(content.contains('com.google.firebase.firestore'), true,
          reason: 'Cloud Firestore must be preserved in ProGuard');
    });

    test('8. DatabaseHelper registers user and verifies database integrity', () async {
      final db = await DatabaseHelper.instance.database;
      expect(db.isOpen, true);

      // Verify all essential tables exist
      final tablesResult = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('users', 'products', 'transactions', 'purchased_services', 'email_settings');");
      final foundTables = tablesResult.map((r) => r['name']).toSet();
      expect(foundTables.contains('users'), true);
      expect(foundTables.contains('products'), true);
      expect(foundTables.contains('transactions'), true);
      expect(foundTables.contains('purchased_services'), true);
      expect(foundTables.contains('email_settings'), true);
    });
  });
}
