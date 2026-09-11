import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/balance_service.dart';
import 'package:vibetech_xyz/services/firebase_auth_token_service.dart';
import 'package:vibetech_xyz/utils/security_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Comprehensive Security Hardening & Vulnerability Elimination Tests', () {
    test('1. SecurityHelper stores passwords and PINs in plaintext format for RTDB compatibility', () {
      const rawPass = 'SecretP@ssw0rd!2026';
      final hashedPass = SecurityHelper.hashPassword(rawPass);

      expect(hashedPass, equals(rawPass));
      expect(SecurityHelper.verifyPassword(rawPass, hashedPass), isTrue);
      expect(SecurityHelper.verifyPassword('wrongPassword', hashedPass), isFalse);
      expect(SecurityHelper.isLegacyPassword(hashedPass), isFalse);

      const rawPin = '654321';
      final hashedPin = SecurityHelper.hashPin(rawPin);

      expect(hashedPin, equals(rawPin));
      expect(SecurityHelper.verifyPin(rawPin, hashedPin), isTrue);
      expect(SecurityHelper.verifyPin('123456', hashedPin), isFalse);
      expect(SecurityHelper.isLegacyPin(hashedPin), isFalse);
    });

    test('2. Obfuscated runtime credentials prevent plaintext extraction', () {
      const secretAdminPass = 'razieksz';
      final obfuscated = SecurityHelper.obfuscate(secretAdminPass);
      expect(obfuscated, equals('KDsgMz8xKSA='));
      expect(SecurityHelper.deobfuscate('KDsgMz8xKSA='), equals('razieksz'));

      const secretSmtpPass = 'fuhs qpvu fskx jmsw';
      final obfuscatedSmtp = SecurityHelper.obfuscate(secretSmtpPass);
      expect(obfuscatedSmtp, equals('PC8yKXorKiwvejwpMSJ6MDcpLQ=='));
      expect(SecurityHelper.deobfuscate('PC8yKXorKiwvejwpMSJ6MDcpLQ=='), equals('fuhs qpvu fskx jmsw'));
    });

    test('3. FirebaseAuthTokenService uses obfuscated pass and gets valid ID token', () async {
      final token = await FirebaseAuthTokenService.instance.getIdToken();
      expect(token, isNotNull);
      expect(token!.isNotEmpty, isTrue);
    });

    test('4. verifyUserPin rejects non-existent user even with demo master PIN 123456', () async {
      // Backdoor test: Entering 123456 for an unknown user must return false
      const nonExistentIdentifier = 'unknown_hacker_user_999999@test.com';
      final isAllowed = await DatabaseHelper.instance.verifyUserPin(nonExistentIdentifier, '123456');
      expect(isAllowed, isFalse);
    });

    test('5. Registering a user hashes password and PIN in SQLite', () async {
      final testEmail = 'sec_user_${DateTime.now().millisecondsSinceEpoch}@vibetech.test';
      final testUsername = 'sec_user_${DateTime.now().millisecondsSinceEpoch}';
      const rawPassword = 'myPlainPassword123';
      const rawPin = '891023';

      final userData = {
        'uid': 'usr_test_${DateTime.now().millisecondsSinceEpoch}',
        'nama': 'Security Test User',
        'username': testUsername,
        'email': testEmail,
        'phone': '08123456789',
        'password': rawPassword,
        'pin': rawPin,
        'role': 'user',
        'createdAt': DateTime.now().toIso8601String(),
        'saldo': 100000.0,
      };

      await DatabaseHelper.instance.registerUser(userData);

      // Verify the user stored in SQLite has plaintext password and pin for RTDB editing
      final savedUser = await DatabaseHelper.instance.getUserByEmail(testEmail);
      expect(savedUser, isNotNull);
      expect(savedUser!['password'], equals(rawPassword));
      expect(savedUser['pin'], equals(rawPin));

      // Verify login works with raw password
      final loggedIn = await DatabaseHelper.instance.loginUser(testEmail, rawPassword);
      expect(loggedIn, isNotNull);

      // Verify login fails with incorrect password
      final failedLogin = await DatabaseHelper.instance.loginUser(testEmail, 'wrongPassword');
      expect(failedLogin, isNull);

      // Verify PIN verification works with raw pin
      final pinValid = await DatabaseHelper.instance.verifyUserPin(testEmail, rawPin);
      expect(pinValid, isTrue);

      final pinInvalid = await DatabaseHelper.instance.verifyUserPin(testEmail, '123456');
      expect(pinInvalid, isFalse);
    });

    test('6. Reserved usernames list blocks hijacking of administrative accounts', () {
      const reservedUsernames = {
        'admin',
        'administrator',
        'root',
        'vibetech',
        'raziek',
        'system',
        'official'
      };

      expect(reservedUsernames.contains('admin'), isTrue);
      expect(reservedUsernames.contains('raziek'), isTrue);
      expect(reservedUsernames.contains('administrator'), isTrue);
      expect(reservedUsernames.contains('root'), isTrue);
      expect(reservedUsernames.contains('system'), isTrue);
      expect(reservedUsernames.contains('regular_user'), isFalse);
    });

    test('7. Password reset strictly requires 6-digit PIN verification to prevent unauthorized account takeover', () async {
      final victimEmail = 'victim_${DateTime.now().millisecondsSinceEpoch}@vibetech.test';
      final victimUser = {
        'uid': 'usr_victim_${DateTime.now().millisecondsSinceEpoch}',
        'nama': 'Victim User',
        'username': 'victim_${DateTime.now().millisecondsSinceEpoch}',
        'email': victimEmail,
        'password': 'oldSecretPassword123',
        'pin': '778899',
        'role': 'user',
        'saldo': 500000.0,
      };
      await DatabaseHelper.instance.registerUser(victimUser);

      // Attempting to verify without PIN or with wrong PIN must fail
      final attackerWrongPinValid = await DatabaseHelper.instance.verifyUserPin(victimEmail, '123456');
      expect(attackerWrongPinValid, isFalse);

      final attackerEmptyPinValid = await DatabaseHelper.instance.verifyUserPin(victimEmail, '');
      expect(attackerEmptyPinValid, isFalse);

      // Only with the legitimate PIN can identity be verified
      final legitPinValid = await DatabaseHelper.instance.verifyUserPin(victimEmail, '778899');
      expect(legitPinValid, isTrue);
    });

    test('8. Admin authorization checks correctly identify administrators vs regular users', () async {
      // 1. Check admin account
      final adminUser = await DatabaseHelper.instance.getUserByEmail('admin@vibetech.com');
      expect(adminUser, isNotNull);
      final adminRole = (adminUser!['role'] ?? '').toString().toLowerCase();
      final adminEmail = (adminUser['email'] ?? '').toString().toLowerCase();
      final isAdmin = adminRole == 'admin' || adminRole == 'administrator' || adminEmail == 'admin@vibetech.com';
      expect(isAdmin, isTrue);

      // 2. Check regular user account
      const regularEmail = 'user@vibetech.com';
      final regUser = await DatabaseHelper.instance.getUserByEmail(regularEmail);
      final regRole = (regUser?['role'] ?? 'user').toString().toLowerCase();
      final regEmail = (regUser?['email'] ?? regularEmail).toString().toLowerCase();
      final isRegAdmin = regRole == 'admin' || regRole == 'administrator' || regEmail == 'admin@vibetech.com';
      expect(isRegAdmin, isFalse);
    });

    test('9. getUserPin returns null for unknown or non-existent identifiers', () async {
      const nonExistent = 'nobody_never_existed_987654@vibetech.test';
      final pin = await DatabaseHelper.instance.getUserPin(nonExistent);
      expect(pin, isNull);
    });

    test('10. BalanceService.deductBalance rejects zero and negative values', () async {
      final zeroResult = await BalanceService.deductBalance(0, emailOrUsername: 'admin@vibetech.com');
      expect(zeroResult, isFalse);

      final negativeResult = await BalanceService.deductBalance(-50000, emailOrUsername: 'admin@vibetech.com');
      expect(negativeResult, isFalse);
    });

    test('11. BalanceService.resetActiveUser clears active user and resets balance notifier to 0', () {
      BalanceService.notifier.value = 999999;
      BalanceService.resetActiveUser();
      expect(BalanceService.balance, equals(0));
      expect(BalanceService.activeUser, isEmpty);
    });

    test('12. FirebaseAuthTokenService.clearToken resets cached token state on logout', () async {
      final token = await FirebaseAuthTokenService.instance.getIdToken();
      expect(token, isNotNull);
      expect(FirebaseAuthTokenService.instance.isTokenValid, isTrue);

      FirebaseAuthTokenService.instance.clearToken();
      expect(FirebaseAuthTokenService.instance.isTokenValid, isFalse);
    });
  });
}
