import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Message;
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibetech_xyz/constants/constants.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/firebase_email_service.dart';
import 'package:vibetech_xyz/services/language_service.dart';
import 'package:vibetech_xyz/services/theme_service.dart';
import 'package:vibetech_xyz/utils/security_helper.dart';

/// ============================================================================
/// LAYANAN NOTIFIKASI & EMAIL (NOTIFICATION & EMAIL SERVICE) - VIBETECH XYZ
/// ============================================================================
/// Layanan terpusat untuk:
/// 1. Mengelola preferensi pengguna (Push Notification & Email Notification).
/// 2. Meminta perizinan notifikasi Android 13+ (POST_NOTIFICATIONS) & iOS.
/// 3. Menampilkan notifikasi status bar sistem (System Tray Notification / Heads-Up Banner).
/// 4. Menampilkan in-app Push Notification banner dengan animasi meluncur.
/// 5. Menampilkan modal simulasi Email masuk & integrasi URL Launcher (Mailto).
/// 6. Menyimpan riwayat email inbox untuk ditampilkan di Pusat Notifikasi.
/// 7. Menyediakan antarmuka interaktif untuk uji coba (Test Notification Sheet).
class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isPluginInitialized = false;

  static final ValueNotifier<bool> pushEnabledNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> emailEnabledNotifier =
      ValueNotifier<bool>(true);

  static bool get isPushEnabled => pushEnabledNotifier.value;
  static bool get isEmailEnabled => emailEnabledNotifier.value;

  /// Riwayat email yang masuk ke akun pengguna
  static final List<Map<String, dynamic>> emailInboxHistory = [
    {
      'id': 'EML-8821',
      'sender': 'no-reply@vibetech.xyz',
      'senderName': 'VibeTech Billing System',
      'subject': 'Bukti Pembayaran VibeTech XYZ: #INV-2026-8821',
      'category': 'Invoice & Billing',
      'orderId': '#INV-2026-8821',
      'amount': 'Rp 150.000',
      'date': 'Hari ini, 08:30 WIB',
      'isRead': false,
      'body':
          'Terima kasih telah berlangganan layanan di VibeTech XYZ. Pembayaran tagihan invoice #INV-2026-8821 untuk layanan VPS KVM Ubuntu sebesar Rp 150.000 telah kami terima dan terverifikasi otomatis.',
    },
    {
      'id': 'EML-4920',
      'sender': 'security@vibetech.xyz',
      'senderName': 'VibeTech Security Alert',
      'subject': 'Peringatan Keamanan: Aktivitas Login Baru Terdeteksi',
      'category': 'Keamanan Akun',
      'orderId': null,
      'amount': null,
      'date': 'Kemarin, 14:15 WIB',
      'isRead': true,
      'body':
          'Kami mendeteksi aktivitas login baru pada akun VibeTech XYZ Anda dari perangkat Desktop Windows (Jakarta, Indonesia). Jika aktivitas ini bukan dilakukan oleh Anda, segera ubah kata sandi dan aktifkan 2FA.',
    },
    {
      'id': 'EML-1102',
      'sender': 'support@vibetech.xyz',
      'senderName': 'VibeTech Cloud Support',
      'subject': 'Pemberitahuan Kedaluwarsa Layanan Panel Hosting 4GB',
      'category': 'Peringatan Sistem',
      'orderId': 'SRV-PANEL-4GB',
      'amount': 'Rp 75.000',
      'date': '2 hari yang lalu',
      'isRead': true,
      'body':
          'Layanan Panel Hosting 4GB Anda akan berakhir dalam 7 hari (31 Agustus 2026). Silakan lakukan perpanjangan langganan melalui aplikasi VibeTech XYZ untuk menghindari penghentian akses server.',
    },
  ];

  /// Inisialisasi preferensi notifikasi dari SharedPreferences dan Local Notifications Engine
  static Future<void> init([String? username]) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Deteksi status aktif permanen dari SMTP SharedPreferences
      final hasSmtpUser = prefs.getString('smtp_user')?.trim().isNotEmpty ?? false;
      final hasSmtpPass = prefs.getString('smtp_pass')?.trim().isNotEmpty ?? false;
      final isSmtpConfigured = hasSmtpUser && hasSmtpPass;
      final bool smtpActive = prefs.getBool('smtp_is_active') ?? isSmtpConfigured;

      if (username != null && username.isNotEmpty) {
        final userKey = username.toLowerCase().replaceAll(' ', '_');
        pushEnabledNotifier.value =
            prefs.getBool('push_notif_$userKey') ?? true;
        // Jika SMTP sudah dikonfigurasi, email notifikasi permanen aktif
        emailEnabledNotifier.value =
            smtpActive ? true : (prefs.getBool('email_notif_$userKey') ?? true);
      } else {
        if (smtpActive) {
          emailEnabledNotifier.value = true;
        }
      }

      if (!_isPluginInitialized && !kIsWeb) {
        const androidInit =
            AndroidInitializationSettings('@mipmap/launcher_icon');
        const darwinInit = DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
        const linuxInit =
            LinuxInitializationSettings(defaultActionName: 'Open notification');

        const initSettings = InitializationSettings(
          android: androidInit,
          iOS: darwinInit,
          macOS: darwinInit,
          linux: linuxInit,
        );

        await _localNotifPlugin.initialize(
          settings: initSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) {
            debugPrint(
                '[NotificationService] Notifikasi sistem diklik: ${response.payload}');
          },
        );

        // Buat Android Notification Channels berkategori
        if (Platform.isAndroid) {
          final androidPlugin = _localNotifPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

          if (androidPlugin != null) {
            await androidPlugin.createNotificationChannel(
              const AndroidNotificationChannel(
                'vibetech_general',
                'Notifikasi Umum & Sistem',
                description:
                    'Informasi sistem dan pembaruan aplikasi VibeTech XYZ',
                importance: Importance.high,
                enableVibration: true,
                playSound: true,
              ),
            );

            await androidPlugin.createNotificationChannel(
              const AndroidNotificationChannel(
                'vibetech_transaction',
                'Transaksi & Billing',
                description:
                    'Bukti pembayaran, verifikasi invoice, dan top-up saldo',
                importance: Importance.max,
                enableVibration: true,
                playSound: true,
              ),
            );

            await androidPlugin.createNotificationChannel(
              const AndroidNotificationChannel(
                'vibetech_promo',
                'Promo & Diskon Eksklusif',
                description:
                    'Voucher potongan harga VPS, bot WhatsApp, dan panel hosting',
                importance: Importance.defaultImportance,
                enableVibration: true,
                playSound: true,
              ),
            );

            await androidPlugin.createNotificationChannel(
              const AndroidNotificationChannel(
                'vibetech_security',
                'Peringatan Keamanan Akun',
                description:
                    'Peringatan login baru, perubahan PIN, dan autentikasi 2FA',
                importance: Importance.max,
                enableVibration: true,
                playSound: true,
              ),
            );
          }
        }

        _isPluginInitialized = true;
      }
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  /// Meminta perizinan notifikasi ke sistem OS Android 13+ (POST_NOTIFICATIONS) atau iOS
  static Future<bool> requestNotificationPermission(
    BuildContext context, {
    bool forceDialog = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasAskedBefore =
          prefs.getBool('has_prompted_notif_permission') ?? false;

      if (forceDialog || !hasAskedBefore) {
        await prefs.setBool('has_prompted_notif_permission', true);
        if (context.mounted) {
          final bool? shouldRequest = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => _NotificationPermissionBottomSheet(
              isDarkMode: ThemeService.isDarkMode,
            ),
          );
          if (shouldRequest != true) return false;
        }
      }

      if (kIsWeb) return true;

      if (Platform.isAndroid) {
        final androidPlugin = _localNotifPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final granted =
            await androidPlugin?.requestNotificationsPermission() ?? true;
        return granted;
      } else if (Platform.isIOS || Platform.isMacOS) {
        final iosPlugin = _localNotifPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosPlugin?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            true;
        return granted;
      }
      return true;
    } catch (e) {
      debugPrint(
          '[NotificationService] Error requesting notification permission: $e');
      return true;
    }
  }

  /// Memunculkan notifikasi status bar sistem (System Tray / Heads-Up Banner)
  static Future<void> showSystemNotification({
    required String title,
    required String body,
    String category = 'Sistem',
    String? payload,
    int? id,
  }) async {
    if (!isPushEnabled || kIsWeb) return;

    try {
      if (!_isPluginInitialized) await init();

      final notifId =
          id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
      final cat = category.toLowerCase();

      String channelId = 'vibetech_general';
      String channelName = 'Notifikasi Umum & Sistem';
      Importance importance = Importance.high;
      Priority priority = Priority.high;

      if (cat.contains('transaksi') ||
          cat.contains('invoice') ||
          cat.contains('billing') ||
          cat.contains('saldo') ||
          cat.contains('payment') ||
          cat.contains('success')) {
        channelId = 'vibetech_transaction';
        channelName = 'Transaksi & Billing';
        importance = Importance.max;
        priority = Priority.max;
      } else if (cat.contains('promo') ||
          cat.contains('diskon') ||
          cat.contains('voucher')) {
        channelId = 'vibetech_promo';
        channelName = 'Promo & Diskon Eksklusif';
        importance = Importance.defaultImportance;
        priority = Priority.defaultPriority;
      } else if (cat.contains('keamanan') ||
          cat.contains('security') ||
          cat.contains('login') ||
          cat.contains('2fa') ||
          cat.contains('pin') ||
          cat.contains('warning')) {
        channelId = 'vibetech_security';
        channelName = 'Peringatan Keamanan Akun';
        importance = Importance.max;
        priority = Priority.max;
      }

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Saluran resmi notifikasi VibeTech XYZ',
        importance: importance,
        priority: priority,
        icon: '@mipmap/launcher_icon',
        enableVibration: true,
        playSound: true,
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          contentTitle: title,
          htmlFormatContentTitle: false,
        ),
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notifDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _localNotifPlugin.show(
        id: notifId,
        title: title,
        body: body,
        notificationDetails: notifDetails,
        payload: payload ?? category,
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing system notification: $e');
    }
  }

  /// Update pengaturan Push Notification
  static Future<void> setPushEnabled(bool value, String username) async {
    pushEnabledNotifier.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = username.toLowerCase().replaceAll(' ', '_');
      await prefs.setBool('push_notif_$userKey', value);
    } catch (e) {
      debugPrint('Error saving push notification setting: $e');
    }
  }

  /// Update pengaturan Email Notification
  static Future<void> setEmailEnabled(bool value, String username) async {
    emailEnabledNotifier.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = username.toLowerCase().replaceAll(' ', '_');
      await prefs.setBool('email_notif_$userKey', value);
      await prefs.setBool('smtp_is_active', value);
    } catch (e) {
      debugPrint('Error saving email notification setting: $e');
    }
  }

  /// Membuka aplikasi Email perangkat (Gmail / Outlook / Apple Mail / Web) melalui URL Scheme
  static Future<bool> openExternalEmailApp({
    required String toEmail,
    required String subject,
    required String body,
  }) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: toEmail,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;
    } catch (e) {
      debugPrint('Could not launch mailto scheme: $e');
    }

    // Fallback: Web Gmail direct compose
    try {
      final webGmailUri = Uri.parse(
          'https://mail.google.com/mail/?view=cm&fs=1&to=${Uri.encodeComponent(toEmail)}&su=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
      return await launchUrl(
        webGmailUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}

    return false;
  }

  /// Menampilkan In-App Banner Push Notification yang meluncur dari atas layar
  /// dan memunculkan notifikasi status bar sistem jika diizinkan
  static void showInAppNotification(
    BuildContext context, {
    required String title,
    required String message,
    String type = 'info', // 'success', 'warning', 'info', 'payment', 'security'
    VoidCallback? onTap,
  }) {
    if (!isPushEnabled) return;

    // 1. Kirim notifikasi status bar sistem (System Tray Notification)
    showSystemNotification(
      title: title,
      body: message,
      category: type,
    );

    HapticFeedback.mediumImpact();

    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    Color iconColor;
    IconData iconData;

    switch (type) {
      case 'success':
      case 'payment':
        iconColor = AppColors.success;
        iconData = Icons.check_circle_rounded;
        break;
      case 'warning':
      case 'expiry':
        iconColor = AppColors.warning;
        iconData = Icons.warning_amber_rounded;
        break;
      case 'security':
        iconColor = const Color(0xFF00E5FF);
        iconData = Icons.shield_rounded;
        break;
      default:
        iconColor = AppColors.primary;
        iconData = Icons.notifications_active_rounded;
    }

    overlayEntry = OverlayEntry(
      builder: (context) => _InAppNotificationBanner(
        title: title,
        message: message,
        icon: iconData,
        accentColor: iconColor,
        onTap: () {
          overlayEntry.remove();
          if (onTap != null) onTap();
        },
        onDismiss: () {
          overlayEntry.remove();
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }

  /// Mengirimkan simulasi notifikasi email, mencatat ke inbox, dan menampilkan modal popup
  static void sendEmailNotification(
    BuildContext context, {
    required String toEmail,
    required String subject,
    required String message,
    String category = 'Sistem',
    String? orderId,
    String? amount,
    bool showPopupImmediately = true,
  }) {
    final dateStr =
        'Hari ini, ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} WIB';

    // Catat ke daftar email inbox runtime
    final newEmail = {
      'id':
          'EML-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      'sender': 'no-reply@vibetech.xyz',
      'senderName': 'VibeTech System Mailer',
      'subject': subject,
      'category': category,
      'orderId': orderId,
      'amount': amount,
      'date': dateStr,
      'isRead': false,
      'body': message,
    };

    emailInboxHistory.insert(0, newEmail);

    // Simpan permanen ke SQLite Database
    try {
      DatabaseHelper.instance.insertNotification({
        'user_email': toEmail,
        'title': subject,
        'message': message,
        'category': category,
        'order_id': orderId,
        'amount': amount,
        'date_time': dateStr,
        'is_read': 0,
        'type': 'email',
        'sender': 'no-reply@vibetech.xyz',
        'sender_name': 'VibeTech System Mailer',
      });
    } catch (e) {
      debugPrint('Error saving notification to DB: $e');
    }

    // Pengiriman email nyata ke inbox email pengguna via Internet Cloud Mailer & Backend
    _dispatchRealEmail(
      toEmail: toEmail,
      subject: subject,
      message: message,
      category: category,
      orderId: orderId,
      amount: amount,
    );

    if (showPopupImmediately) {
      showEmailNotificationModal(
        context,
        toEmail: toEmail,
        subject: subject,
        message: message,
        category: category,
        orderId: orderId,
        amount: amount,
      );
    }
  }

  /// Menyiarkan notifikasi push dan email diskon/promo baru ke seluruh pengguna terdaftar
  static Future<void> broadcastPromoDiscount(
    BuildContext context, {
    required String title,
    required String subject,
    required String message,
    required String productName,
    required int discountPercent,
    String category = 'Promo & Diskon',
  }) async {
    // 1. Tampilkan Push Notification banner di aplikasi
    showInAppNotification(
      context,
      title: title,
      message: message,
      type: 'success',
      onTap: () {
        showEmailNotificationModal(
          context,
          toEmail: 'customer@vibetech.xyz',
          subject: subject,
          message: message,
          category: category,
        );
      },
    );

    // 2. Kirim email promo ke seluruh member di database secara otomatis
    try {
      final allUsers = await DatabaseHelper.instance.getAllUsers();
      final List<String> targetEmails = [];

      for (var u in allUsers) {
        final email = u['email']?.toString();
        if (email != null &&
            email.contains('@') &&
            !targetEmails.contains(email)) {
          targetEmails.add(email);
        }
      }

      if (targetEmails.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final currentEmail = prefs.getString('email');
        if (currentEmail != null && currentEmail.contains('@')) {
          targetEmails.add(currentEmail);
        }
      }

      for (var email in targetEmails) {
        emailInboxHistory.insert(0, {
          'id': 'PRM-${DateTime.now().millisecondsSinceEpoch % 10000}',
          'sender': 'promo@vibetech.xyz',
          'senderName': 'VibeTech Promo System',
          'subject': subject,
          'category': category,
          'orderId': null,
          'amount': null,
          'date': 'Baru saja',
          'isRead': false,
          'body': message,
        });

        // Simpan ke SQLite Database
        try {
          await DatabaseHelper.instance.insertNotification({
            'user_email': email,
            'title': subject,
            'message': message,
            'category': category,
            'order_id': null,
            'amount': null,
            'date_time':
                'Hari ini, ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} WIB',
            'is_read': 0,
            'type': 'promo',
            'sender': 'promo@vibetech.xyz',
            'sender_name': 'VibeTech Promo System',
          });
        } catch (_) {}

        if (isEmailEnabled) {
          _dispatchRealEmail(
            toEmail: email,
            subject: subject,
            message: message,
            category: category,
          );
        }
      }
      debugPrint(
          '📢 [NotificationService] Promo Diskon berhasil disiarkan ke ${targetEmails.length} pengguna!');
    } catch (e) {
      debugPrint('Error broadcasting promo discount: $e');
    }
  }

  /// Mengirimkan email asli ke inbox email pengguna secara otomatis via SMTP & Cloud Gateway
  static Future<bool> _dispatchRealEmail({
    required String toEmail,
    required String subject,
    required String message,
    String? category,
    String? orderId,
    String? amount,
  }) async {
    if (!toEmail.contains('@')) return false;

    final String tableSection = orderId != null
        ? '<table class="table"><tr><td class="label">ID Transaksi / Invoice:</td><td class="val-order">$orderId</td></tr>${amount != null ? '<tr style="border-top: 1px solid rgba(255,255,255,0.05);"><td class="label">Total Transaksi:</td><td class="val-price">$amount</td></tr>' : ''}</table>'
        : '';

    final String htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0B0E1B; color: #FFFFFF; margin: 0; padding: 20px; }
    .card { background-color: #121829; border: 1px solid rgba(124, 77, 255, 0.4); border-radius: 16px; padding: 28px; max-width: 580px; margin: 0 auto; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }
    .header { text-align: center; margin-bottom: 24px; }
    .brand { color: #7C4DFF; font-size: 26px; font-weight: 800; letter-spacing: 1px; margin: 0; }
    .brand-accent { color: #00E5FF; }
    .badge { display: inline-block; background: #7C4DFF; color: #FFFFFF; font-size: 11px; font-weight: 700; padding: 4px 12px; border-radius: 20px; text-transform: uppercase; margin-bottom: 12px; }
    .content-box { background: rgba(255, 255, 255, 0.05); padding: 20px; border-radius: 12px; border: 1px solid rgba(255, 255, 255, 0.1); margin-bottom: 20px; }
    .title { color: #FFFFFF; font-size: 18px; margin: 0 0 12px 0; }
    .message { color: #E2E8F0; font-size: 14px; line-height: 1.7; white-space: pre-line; }
    .table { width: 100%; border-collapse: collapse; margin-bottom: 20px; background: rgba(255,255,255,0.03); border-radius: 10px; border: 1px solid rgba(255,255,255,0.08); }
    .table td { padding: 12px 14px; font-size: 13px; }
    .label { color: #94A3B8; }
    .val-order { color: #00E5FF; font-weight: bold; text-align: right; }
    .val-price { color: #10B981; font-weight: bold; font-size: 15px; text-align: right; }
    .footer { text-align: center; border-top: 1px solid rgba(255,255,255,0.1); padding-top: 18px; color: #64748B; font-size: 11px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1 class="brand">VIBETECH <span class="brand-accent">XYZ</span></h1>
      <p style="color: #94A3B8; margin: 4px 0 0 0; font-size: 13px;">Cloud Hosting & Digital Services</p>
    </div>
    <div class="content-box">
      <span class="badge">${category ?? 'Notifikasi Transaksi'}</span>
      <h2 class="title">$subject</h2>
      <div class="message">$message</div>
    </div>
    $tableSection
    <div class="footer">
      <p style="margin: 0;">Email ini dibuat secara otomatis oleh sistem notifikasi VibeTech XYZ.</p>
      <p style="margin: 4px 0 0 0;">© 2026 VibeTech XYZ. Seluruh hak cipta dilindungi undang-undang.</p>
    </div>
  </div>
</body>
</html>
''';

    // 1. Jalur Utama: Direct SMTP via Google Mail / Custom SMTP Server (Membaca Konfigurasi dari Cloud Firestore / SQLite)
    try {
      Map<String, dynamic>? dbSettings;
      try {
        dbSettings = await FirebaseEmailService.instance.getEmailSettings();
      } catch (_) {}

      if (dbSettings == null ||
          dbSettings['smtp_pass'] == null ||
          dbSettings['smtp_pass'].toString().trim().isEmpty) {
        try {
          dbSettings = await DatabaseHelper.instance.getEmailSettings();
        } catch (_) {}
      }

      final prefs = await SharedPreferences.getInstance();
      String smtpUser = (dbSettings?['smtp_user']?.toString() ?? '').trim();
      if (smtpUser.isEmpty) {
        smtpUser = (prefs.getString('smtp_user') ?? 'vibetech.official.xyz@gmail.com').trim();
      }

      String rawPass = (dbSettings?['smtp_pass']?.toString() ?? '').trim();
      if (rawPass.isEmpty) {
        rawPass = (prefs.getString('smtp_pass') ??
                SecurityHelper.deobfuscate('PC8yKXorKiwvejwpMSJ6MDcpLQ=='))
            .trim();
      }
      final cleanPass = rawPass.replaceAll(' ', '').trim();

      String smtpHost = (dbSettings?['smtp_host']?.toString() ?? '').trim();
      if (smtpHost.isEmpty) {
        smtpHost = (prefs.getString('smtp_host') ?? 'smtp.gmail.com').trim();
      }

      final smtpPort = (dbSettings?['smtp_port'] as num?)?.toInt() ??
          prefs.getInt('smtp_port') ??
          465;

      final bool isGmail = smtpHost.toLowerCase().contains('gmail.com');
      final SmtpServer smtpServer = isGmail
          ? (smtpPort == 465
              ? SmtpServer(
                  'smtp.gmail.com',
                  port: 465,
                  ssl: true,
                  username: smtpUser,
                  password: cleanPass,
                )
              : gmail(smtpUser, cleanPass))
          : SmtpServer(
              smtpHost,
              port: smtpPort,
              ssl: smtpPort == 465,
              username: smtpUser,
              password: cleanPass,
            );

      final mailMessage = Message()
        ..from = Address(smtpUser, 'VibeTech XYZ Official')
        ..recipients.add(toEmail)
        ..subject = '[VibeTech XYZ] $subject'
        ..text = message
        ..html = htmlContent;

      final sendReport = await send(mailMessage, smtpServer)
          .timeout(const Duration(seconds: 10));
      debugPrint(
          '✅ [NotificationService] EMAIL ASLI BERHASIL TERKIRIM LANGSUNG KE INBOX $toEmail via SMTP ($smtpUser): ${sendReport.toString()}');
      return true;
    } catch (smtpError) {
      debugPrint('⚠️ [NotificationService] Direct SMTP attempt: $smtpError');
    }

    // 2. Jalur Sekunder: Cloud Email REST Gateway (FormSubmit / Webhook)
    try {
      final cloudUrl = Uri.parse('https://formsubmit.co/ajax/$toEmail');
      final response = await http
          .post(
            cloudUrl,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              '_subject': '[$category] $subject',
              '_template': 'table',
              'Aplikasi': 'VibeTech XYZ Cloud & Hosting System',
              'Kategori': category ?? 'Notifikasi Transaksi',
              'ID_Layanan_Transaksi': orderId ?? '-',
              'Total_Nominal': amount ?? '-',
              'Isi_Pemberitahuan': message,
              'Waktu_Kirim': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint(
            '✅ [NotificationService] Email terkirim via Cloud Gateway ke: $toEmail');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Cloud gateway notice: $e');
    }

    // 3. Jalur Tersier: Local Backend API jika aktif
    try {
      final backendUrl = Uri.parse('http://localhost:3000/api/send-email');
      final backendResp = await http
          .post(
            backendUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'to': toEmail,
              'subject': subject,
              'message': message,
              'category': category,
              'orderId': orderId,
              'amount': amount,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (backendResp.statusCode == 200) {
        debugPrint(
            '✅ [NotificationService] Email terkirim via local backend ke: $toEmail');
        return true;
      }
    } catch (_) {}

    return false;
  }

  /// Mengirimkan email uji coba langsung menggunakan konfigurasi SMTP tertentu
  static Future<Map<String, dynamic>> sendDirectSmtpTest({
    required String smtpUser,
    required String smtpPass,
    required String targetEmail,
    String smtpHost = 'smtp.gmail.com',
    int smtpPort = 465,
  }) async {
    final cleanUser = smtpUser.trim();
    final cleanPass = smtpPass.replaceAll(' ', '').trim();
    final cleanHost = smtpHost.trim();

    try {
      final bool isGmail = cleanHost.toLowerCase().contains('gmail.com');
      final SmtpServer smtpServer = isGmail
          ? (smtpPort == 465
              ? SmtpServer(
                  'smtp.gmail.com',
                  port: 465,
                  ssl: true,
                  username: cleanUser,
                  password: cleanPass,
                )
              : gmail(cleanUser, cleanPass))
          : SmtpServer(
              cleanHost,
              port: smtpPort,
              ssl: smtpPort == 465,
              username: cleanUser,
              password: cleanPass,
            );

      final mailMessage = Message()
        ..from = Address(cleanUser, 'VibeTech XYZ Official')
        ..recipients.add(targetEmail)
        ..subject =
            '[Uji Coba] Konfigurasi Server Email VibeTech XYZ Sukses! 🎉'
        ..text =
            'Halo!\n\nEmail ini mengonfirmasi bahwa konfigurasi SMTP server VibeTech XYZ Anda ($smtpUser) telah terhubung dan aktif.\n\nNotifikasi transaksi pembelian, invoice, dan top up saldo akan otomatis dikirimkan ke alamat email ini.'
        ..html = '''
        <div style="font-family: Arial, sans-serif; background: #0B0E1B; color: #FFFFFF; padding: 28px; border-radius: 16px; max-width: 540px; margin: 0 auto; border: 1px solid #7C4DFF;">
          <h2 style="color: #7C4DFF; margin-top: 0;">VIBETECH <span style="color: #00E5FF;">XYZ</span></h2>
          <div style="background: rgba(255,255,255,0.06); padding: 18px; border-radius: 12px; margin-bottom: 16px;">
            <p style="margin: 0; color: #10B981; font-weight: bold; font-size: 16px;">✅ Koneksi Server Email Berhasil!</p>
            <p style="color: #CBD5E1; font-size: 13px; line-height: 1.6; margin-top: 8px;">
              Konfigurasi server SMTP <strong>$smtpUser</strong> telah aktif. Seluruh bukti transaksi dan invoice Anda akan dikirimkan otomatis ke inbox email ini.
            </p>
          </div>
          <p style="color: #64748B; font-size: 11px; margin: 0;">© 2026 VibeTech XYZ Notification Engine.</p>
        </div>
        ''';

      await send(mailMessage, smtpServer).timeout(const Duration(seconds: 12));
      return {
        'success': true,
        'message': 'Email uji coba berhasil dikirim ke $targetEmail!',
      };
    } catch (e) {
      final errStr = e.toString();
      String friendlyMsg = 'Gagal mengirim email: $errStr';
      if (errStr.contains('535') ||
          errStr.contains('BadCredentials') ||
          errStr.contains('not accepted') ||
          errStr.contains('Username and Password not accepted')) {
        friendlyMsg =
            'Google menolak autentikasi (535 BadCredentials).\n\n⚠️ PENTING: Akun Gmail WAJIB menggunakan "Sandi Aplikasi" (App Password) 16 karakter yang dibuat di myaccount.google.com/apppasswords (BUKAN password login biasa).';
      } else if (errStr.contains('SocketException') ||
          errStr.contains('timed out') ||
          errStr.contains('Connection refused')) {
        friendlyMsg =
            'Koneksi ke $cleanHost:$smtpPort gagal/terblokir jaringan. Coba gunakan Port 587 atau koneksi Wi-Fi.';
      }
      return {
        'success': false,
        'message': friendlyMsg,
      };
    }
  }

  /// Menampilkan Dialog Pratinjau Email Notifikasi Resmi VibeTech
  static void showEmailNotificationModal(
    BuildContext context, {
    required String toEmail,
    required String subject,
    required String message,
    String category = 'Sistem',
    String? orderId,
    String? amount,
  }) {
    HapticFeedback.lightImpact();
    final isDark = ThemeService.isDarkMode;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1426) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Email App Header Bar ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF161C36)
                          : const Color(0xFFF8FAFC),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(22)),
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.accent],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.email_rounded,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LanguageService.text('Notifikasi Email Masuk',
                                    'Incoming Email Notification'),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                'VibeTech Mailer • no-reply@vibetech.xyz',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white54
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 20,
                              color: isDark ? Colors.white70 : Colors.black54),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Recipient and Date meta
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Kepada: ',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white70
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      toEmail,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Waktu: ',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white54
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  Text(
                                    '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} WIB (Hari ini)',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white54
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Subject Badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                category.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subject,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Email Body Box (Styled Letter)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF141A2E)
                                : const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  height: 1.6,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                              if (orderId != null || amount != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      if (orderId != null)
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'ID Transaksi / Layanan:',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black87),
                                            ),
                                            Text(
                                              orderId,
                                              style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary),
                                            ),
                                          ],
                                        ),
                                      if (amount != null) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Total:',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black87),
                                            ),
                                            Text(
                                              amount,
                                              style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.success),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Divider(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFFE2E8F0),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Salam Hangat,\nTim Operasional & Cloud System VibeTech XYZ',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Action Buttons: Open in Email App & Close
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  openExternalEmailApp(
                                    toEmail: toEmail,
                                    subject: subject,
                                    body: message,
                                  );
                                },
                                icon: const Icon(Icons.open_in_new_rounded,
                                    size: 16),
                                label: const Text('Buka di Gmail/Mail',
                                    style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: BorderSide(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.4)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: Text(
                                  LanguageService.text(
                                      'Mengerti', 'Understood'),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Menampilkan Bottom Sheet Uji Coba Pengiriman Notifikasi & Email
  static void showTestNotificationSheet(
    BuildContext parentContext, {
    required String username,
    required String userEmail,
    required bool isDarkMode,
  }) {
    showModalBottomSheet(
      context: parentContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return _TestNotificationSheet(
          parentContext: parentContext,
          username: username,
          userEmail: userEmail,
          isDarkMode: isDarkMode,
        );
      },
    );
  }
}

/// ============================================================================
/// WIDGET IN-APP NOTIFICATION BANNER
/// ============================================================================
class _InAppNotificationBanner extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _InAppNotificationBanner({
    required this.title,
    required this.message,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<_InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    // Auto dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.isDarkMode;
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                _dismiss();
                widget.onTap();
              },
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! < 0) {
                  _dismiss();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF141A2E).withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.accentColor.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.icon,
                          color: widget.accentColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'VibeTech Alert',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: widget.accentColor,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Baru saja',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.white38
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.title,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _dismiss,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// SHEET UJI COBA PENGIRIMAN NOTIFIKASI & EMAIL
/// ============================================================================
class _TestNotificationSheet extends StatefulWidget {
  final BuildContext parentContext;
  final String username;
  final String userEmail;
  final bool isDarkMode;

  const _TestNotificationSheet({
    required this.parentContext,
    required this.username,
    required this.userEmail,
    required this.isDarkMode,
  });

  @override
  State<_TestNotificationSheet> createState() => _TestNotificationSheetState();
}

class _TestNotificationSheetState extends State<_TestNotificationSheet> {
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF161C36) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1426) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.3)
                : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LanguageService.text('Uji Coba Pengiriman Notifikasi',
                          'Test Notification Delivery'),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      LanguageService.text(
                          'Kirim simulasi Push Notifikasi atau Email Notifikasi',
                          'Send simulated Push Notification or Email Notification'),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Status Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: NotificationService.isPushEnabled
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        NotificationService.isPushEnabled
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_rounded,
                        size: 18,
                        color: NotificationService.isPushEnabled
                            ? AppColors.success
                            : AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Push Notif',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              NotificationService.isPushEnabled
                                  ? 'Aktif'
                                  : 'Nonaktif',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: NotificationService.isPushEnabled
                                    ? AppColors.success
                                    : AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: NotificationService.isEmailEnabled
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        NotificationService.isEmailEnabled
                            ? Icons.mark_email_read_rounded
                            : Icons.mail_lock_rounded,
                        size: 18,
                        color: NotificationService.isEmailEnabled
                            ? AppColors.success
                            : AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Email Notif',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              NotificationService.isEmailEnabled
                                  ? 'Aktif'
                                  : 'Nonaktif',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: NotificationService.isEmailEnabled
                                    ? AppColors.success
                                    : AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text(
            LanguageService.text(
                'PILIH SKENARIO PENGUJIAN', 'CHOOSE TEST SCENARIO'),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Scenario 1: Pembayaran & Invoice
          _buildScenarioTile(
            title: 'Pembayaran VPS Berhasil',
            subtitle: 'Kirim notifikasi transaksi invoice Rp 150.000',
            icon: Icons.receipt_long_rounded,
            color: AppColors.success,
            onTestPush: () {
              Navigator.pop(context);
              NotificationService.showInAppNotification(
                widget.parentContext,
                title: 'Pembayaran Sukses! 🎉',
                message:
                    'Pembayaran VPS KVM 4GB sebesar Rp 150.000 telah kami terima. Server Anda siap dikonfigurasi.',
                type: 'payment',
              );
            },
            onTestEmail: () {
              Navigator.pop(context);
              NotificationService.sendEmailNotification(
                widget.parentContext,
                toEmail: widget.userEmail,
                subject: 'Bukti Pembayaran VibeTech XYZ: #INV-2026-8821',
                message:
                    'Halo ${widget.username},\n\nTerima kasih telah berlangganan di VibeTech XYZ. Pembayaran tagihan layanan Anda telah berhasil diproses secara otomatis.',
                category: 'Invoice & Billing',
                orderId: '#INV-2026-8821',
                amount: 'Rp 150.000',
              );
            },
          ),
          const SizedBox(height: 10),

          // Scenario 2: Server Expiry
          _buildScenarioTile(
            title: 'Peringatan Masa Aktif Server',
            subtitle: 'Alert 7 hari sebelum layanan kedaluwarsa',
            icon: Icons.timer_rounded,
            color: AppColors.warning,
            onTestPush: () {
              Navigator.pop(context);
              NotificationService.showInAppNotification(
                widget.parentContext,
                title: 'Masa Aktif Server Segera Berakhir! ⏳',
                message:
                    'Layanan VPS Ubuntu Anda akan berakhir dalam 7 hari. Lakukan perpanjangan untuk mencegah suspensi.',
                type: 'expiry',
              );
            },
            onTestEmail: () {
              Navigator.pop(context);
              NotificationService.sendEmailNotification(
                widget.parentContext,
                toEmail: widget.userEmail,
                subject: 'Pemberitahuan Kedaluwarsa Layanan Server VibeTech',
                message:
                    'Halo ${widget.username},\n\nKami menginformasikan bahwa layanan Panel Hosting 4GB Anda akan berakhir pada tanggal 31 Agustus 2026. Silakan lakukan perpanjangan melalui aplikasi VibeTech XYZ.',
                category: 'Peringatan Sistem',
                orderId: 'SRV-PANEL-4GB',
              );
            },
          ),
          const SizedBox(height: 10),

          // Scenario 3: Keamanan Akun
          _buildScenarioTile(
            title: 'Alert Keamanan Akun',
            subtitle: 'Deteksi login perangkat baru atau perubahan PIN',
            icon: Icons.security_rounded,
            color: const Color(0xFF00E5FF),
            onTestPush: () {
              Navigator.pop(context);
              NotificationService.showInAppNotification(
                widget.parentContext,
                title: 'Aktivitas Login Baru Terdeteksi 🛡️',
                message:
                    'Akun Anda baru saja masuk dari perangkat Windows di Jakarta, Indonesia.',
                type: 'security',
              );
            },
            onTestEmail: () {
              Navigator.pop(context);
              NotificationService.sendEmailNotification(
                widget.parentContext,
                toEmail: widget.userEmail,
                subject: 'Peringatan Keamanan Akun: Aktivitas Login Baru',
                message:
                    'Halo ${widget.username},\n\nKami mendeteksi aktivitas login baru pada akun Anda melalui aplikasi VibeTech XYZ.\n\nWaktu: ${DateTime.now().toLocal()}\nPerangkat: Android / Windows Client\n\nJika ini bukan Anda, segera ubah kata sandi dan aktifkan 2FA di menu Profil.',
                category: 'Keamanan Akun',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTestPush,
    required VoidCallback onTestEmail,
  }) {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF161C36) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTestPush,
                  icon:
                      const Icon(Icons.notifications_active_rounded, size: 15),
                  label:
                      const Text('Test Push', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onTestEmail,
                  icon: const Icon(Icons.email_rounded, size: 15),
                  label:
                      const Text('Test Email', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// BOTTOM SHEET PERIZINAN NOTIFIKASI (PERMISSION EXPLANATION SHEET)
/// ============================================================================
class _NotificationPermissionBottomSheet extends StatelessWidget {
  final bool isDarkMode;

  const _NotificationPermissionBottomSheet({required this.isDarkMode});

  Color get _bgColor => isDarkMode ? const Color(0xFF0F1426) : Colors.white;
  Color get _cardColor =>
      isDarkMode ? const Color(0xFF171E36) : const Color(0xFFF8FAFC);
  Color get _borderColor => isDarkMode
      ? const Color(0xFF7C4DFF).withValues(alpha: 0.25)
      : const Color(0xFFE2E8F0);
  Color get _textPrimary => isDarkMode ? Colors.white : const Color(0xFF0F172A);
  Color get _textSecondary =>
      isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: _textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Notification Bell Icon with Glowing Gradient
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(height: 18),

          // Title
          Text(
            LanguageService.text(
              'Aktifkan Notifikasi VibeTech XYZ',
              'Enable VibeTech XYZ Notifications',
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18.5,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            LanguageService.text(
              'Dapatkan pembaruan instan mengenai status pesanan, bukti pembayaran, promo diskon, dan peringatan keamanan akun langsung di perangkat Anda.',
              'Get instant updates about order statuses, payment receipts, discount promos, and account security alerts directly on your device.',
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: _textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Feature Benefit Cards
          _buildBenefitItem(
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFF00E676),
            title: LanguageService.text(
                'Status Invoice & Billing', 'Invoice & Billing Status'),
            subtitle: LanguageService.text(
              'Notifikasi verifikasi top-up dan konfirmasi pembayaran seketika.',
              'Instant verification for top-ups and payment confirmations.',
            ),
          ),
          const SizedBox(height: 10),
          _buildBenefitItem(
            icon: Icons.local_offer_rounded,
            iconColor: const Color(0xFFFF9100),
            title: LanguageService.text('Promo & Diskon Eksklusif',
                'Exclusive Promos & Discounts'),
            subtitle: LanguageService.text(
              'Pemberitahuan voucher potongan harga VPS dan panel hosting.',
              'Special voucher alerts for VPS and hosting panel discounts.',
            ),
          ),
          const SizedBox(height: 10),
          _buildBenefitItem(
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFF00B0FF),
            title: LanguageService.text(
                'Keamanan & Sistem', 'Security & System Alerts'),
            subtitle: LanguageService.text(
              'Peringatan login baru, token kadaluarsa, dan informasi server.',
              'Alerts for new logins, expiry reminders, and server updates.',
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              // Nanti Saja Button
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: _borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    LanguageService.text('Nanti Saja', 'Not Now'),
                    style: GoogleFonts.poppins(
                      color: _textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Izinkan Notifikasi Button
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 4,
                    shadowColor:
                        const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        LanguageService.text(
                            'Izinkan Notifikasi', 'Allow Notifications'),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
