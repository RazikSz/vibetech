import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/notification_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('SMTP Permanent Persistence & Auto-Active Tests', () {
    test('Saving SMTP config persists is_active = 1 in SQLite and SharedPreferences', () async {
      final res = await DatabaseHelper.instance.saveEmailSettings(
        smtpUser: 'official.system@vibetech.xyz',
        smtpPass: 'abcd efgh ijkl mnop',
        smtpHost: 'smtp.gmail.com',
        smtpPort: 465,
        userEmail: 'admin@vibetech.xyz',
        syncToCloud: false,
      );

      expect(res, greaterThan(0));

      // Verifikasi SQLite
      final settings = await DatabaseHelper.instance.getEmailSettings(
        userEmail: 'admin@vibetech.xyz',
      );
      expect(settings, isNotNull);
      expect(settings!['smtp_user'], 'official.system@vibetech.xyz');
      expect(settings['smtp_pass'], 'abcdefghijklmnop');
      expect(settings['is_active'], 1);

      // Verifikasi SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('smtp_user'), 'official.system@vibetech.xyz');
      expect(prefs.getString('smtp_pass'), 'abcdefghijklmnop');
      expect(prefs.getBool('smtp_is_active'), true);
    });

    test('Global getEmailSettings returns active credentials even when queried without userEmail', () async {
      await DatabaseHelper.instance.saveEmailSettings(
        smtpUser: 'mailer.daemon@vibetech.xyz',
        smtpPass: '1234 5678 9012 3456',
        smtpHost: 'smtp.gmail.com',
        smtpPort: 465,
        userEmail: 'custom_admin@vibetech.com',
        syncToCloud: false,
      );

      // Pemanggilan global tanpa userEmail
      final globalConfig = await DatabaseHelper.instance.getEmailSettings();
      expect(globalConfig, isNotNull);
      expect(globalConfig!['smtp_user'], 'mailer.daemon@vibetech.xyz');
      expect(globalConfig['smtp_pass'], '1234567890123456');
      expect(globalConfig['is_active'], 1);
    });

    test('NotificationService.init initializes emailEnabledNotifier as true when SMTP is active', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('smtp_user', 'active.smtp@vibetech.xyz');
      await prefs.setString('smtp_pass', 'secretpassword123');
      await prefs.setBool('smtp_is_active', true);

      await NotificationService.init('admin_test_user');

      expect(NotificationService.isEmailEnabled, isTrue);
      expect(NotificationService.emailEnabledNotifier.value, isTrue);
    });

    test('Local password and active state are preserved in SQLite and SharedPreferences', () async {
      await DatabaseHelper.instance.saveEmailSettings(
        smtpUser: 'protected.user@vibetech.xyz',
        smtpPass: 'strongsecretpass',
        smtpHost: 'smtp.gmail.com',
        smtpPort: 465,
        userEmail: 'unique_isolated_user@vibetech.xyz',
        syncToCloud: false,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('smtp_pass'), 'strongsecretpass');
      expect(prefs.getBool('smtp_is_active'), true);

      final dbCheck = await DatabaseHelper.instance.getEmailSettings(
        userEmail: 'unique_isolated_user@vibetech.xyz',
      );
      expect(dbCheck, isNotNull);
      expect(dbCheck!['smtp_pass'], 'strongsecretpass');
      expect(dbCheck['is_active'], 1);
    });

    test('NotificationService.setEmailEnabled syncs smtp_is_active to true', () async {
      await NotificationService.setEmailEnabled(true, 'user_john');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('smtp_is_active'), isTrue);
      expect(prefs.getBool('email_notif_user_john'), isTrue);
      expect(NotificationService.isEmailEnabled, isTrue);
    });
  });
}
