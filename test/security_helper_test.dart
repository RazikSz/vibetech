import 'package:flutter_test/flutter_test.dart';
import 'package:vibetech_xyz/utils/security_helper.dart';

void main() {
  group('SecurityHelper Cryptography & Compatibility Tests', () {
    test('hashPassword preserves password for Firebase RTDB and login compatibility', () {
      const raw = 'mySecurePassword123!';
      final hash1 = SecurityHelper.hashPassword(raw);
      final hash2 = SecurityHelper.hashPassword(raw);

      expect(hash1, equals(raw));
      expect(hash1, equals(hash2));
    });

    test('verifyPassword handles newly hashed passwords correctly', () {
      const raw = 'password123';
      final hash = SecurityHelper.hashPassword(raw);

      expect(SecurityHelper.verifyPassword(raw, hash), isTrue);
      expect(SecurityHelper.verifyPassword('wrongpassword', hash), isFalse);
    });

    test('verifyPassword handles legacy plaintext passwords for backward compatibility', () {
      const legacyPlain = 'razieksz';

      // Plaintext vs plaintext
      expect(SecurityHelper.verifyPassword('razieksz', legacyPlain), isTrue);
      expect(SecurityHelper.verifyPassword('wrongpass', legacyPlain), isFalse);
    });

    test('hashPin and verifyPin protect 6-digit transaction PIN', () {
      const pin = '889900';
      final hashedPin = SecurityHelper.hashPin(pin);

      expect(hashedPin, equals(pin));
      expect(SecurityHelper.verifyPin(pin, hashedPin), isTrue);
      expect(SecurityHelper.verifyPin('123456', hashedPin), isFalse);

      // Legacy PIN fallback
      expect(SecurityHelper.verifyPin('123456', '123456'), isTrue);
    });

    test('obfuscate and deobfuscate preserve sensitive strings perfectly', () {
      const secret = 'AQ.Ab8RN6JoGnIKwXcGp0yPQyHSIfnRGf1pDoPM0LqBVK7lbJWtgQ';
      final obf = SecurityHelper.obfuscate(secret);

      expect(obf, isNot(equals(secret)));
      expect(SecurityHelper.deobfuscate(obf), equals(secret));

      final adminPassObf = SecurityHelper.obfuscate('razieksz');
      expect(adminPassObf, equals('KDsgMz8xKSA='));
      expect(SecurityHelper.deobfuscate('KDsgMz8xKSA='), equals('razieksz'));

      final smtpPassObf = SecurityHelper.obfuscate('fuhs qpvu fskx jmsw');
      expect(smtpPassObf, equals('PC8yKXorKiwvejwpMSJ6MDcpLQ=='));
      expect(SecurityHelper.deobfuscate('PC8yKXorKiwvejwpMSJ6MDcpLQ=='), equals('fuhs qpvu fskx jmsw'));
    });
  });
}
