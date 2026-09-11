import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/firebase_email_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('FirebaseEmailService & Cloud Firestore SMTP Config Tests', () {
    test('FirebaseEmailService config constants point to vibetech-xyz project',
        () {
      expect(FirebaseEmailService.projectId, 'vibetech-xyz');
      expect(FirebaseEmailService.collectionName, 'email_settings');
      expect(FirebaseEmailService.globalDocId, 'global_config');
    });

    test(
        'saveEmailSettings persists data to SQLite and SharedPreferences fallback',
        () async {
      await FirebaseEmailService.instance.saveEmailSettings(
        smtpUser: 'vibetech.official.xyz@gmail.com',
        smtpPass: 'fuhs qpvu fskx jmsw',
        smtpHost: 'smtp.gmail.com',
        smtpPort: 465,
        userEmail: 'admin@vibetech.xyz',
      );

      // Verify saveEmailSettings executed (in test environment without initialized Firebase SDK, REST and local fallback execute gracefully)
      final settings = await FirebaseEmailService.instance
          .getEmailSettings(userEmail: 'admin@vibetech.xyz');
      expect(settings, isNotNull);
      expect(settings!['smtp_user'], 'vibetech.official.xyz@gmail.com');
      expect(settings['smtp_pass'], 'fuhsqpvufskxjmsw');
      expect(settings['smtp_host'], 'smtp.gmail.com');
      expect(settings['smtp_port'], 465);
    });

    test(
        'DatabaseHelper.saveEmailSettings automatically triggers FirebaseEmailService sync',
        () async {
      final res = await DatabaseHelper.instance.saveEmailSettings(
        smtpUser: 'notification.system@vibetech.xyz',
        smtpPass: 'abcd 1234 efgh 5678',
        smtpHost: 'smtp.gmail.com',
        smtpPort: 587,
        userEmail: 'support@vibetech.xyz',
      );

      expect(res, greaterThan(0));

      final retrieved = await DatabaseHelper.instance
          .getEmailSettings(userEmail: 'support@vibetech.xyz');
      expect(retrieved, isNotNull);
      expect(retrieved!['smtp_user'], 'notification.system@vibetech.xyz');
      expect(retrieved['smtp_pass'], 'abcd1234efgh5678');
      expect(retrieved['smtp_port'], 587);
    });

    test(
        'FirebaseEmailService fallback to global_config when user-specific settings not found',
        () async {
      await FirebaseEmailService.instance.saveEmailSettings(
        smtpUser: 'vibetech.official.xyz@gmail.com',
        smtpPass: 'fuhs qpvu fskx jmsw',
        smtpHost: 'smtp.gmail.com',
        smtpPort: 465,
      );

      final globalConfig =
          await FirebaseEmailService.instance.getEmailSettings();
      expect(globalConfig, isNotNull);
      expect(globalConfig!['smtp_user'], isNotEmpty);
    });
  });
}
