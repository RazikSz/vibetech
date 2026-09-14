import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vibetech_xyz/firebase_options.dart';
import 'package:vibetech_xyz/pages/common/splash_page.dart';
import 'package:vibetech_xyz/services/balance_service.dart';
import 'package:vibetech_xyz/services/cloud_sync_service.dart';
import 'package:vibetech_xyz/services/language_service.dart';
import 'package:vibetech_xyz/services/notification_service.dart';
import 'package:vibetech_xyz/services/theme_service.dart';

/// ============================================================================
/// TITIK MASUK UTAMA APLIKASI (MAIN ENTRY POINT)
/// ============================================================================
/// Fungsi main() mempersiapkan binding, Firebase, locale waktu/mata uang Indonesia (id_ID),
/// serta memuat preferensi pengguna (tema, bahasa dan saldo) sebelum UI dirender.
void main() async {
  // 1. Memastikan seluruh binding framework Flutter siap sebelum operasi asinkron
  WidgetsFlutterBinding.ensureInitialized();

  // Penangkal crash global agar aplikasi tidak pernah mengalami "Lost connection to device"
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] Tertangkap framework error: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[PlatformDispatcher] Tertangkap async error non-fatal: $error');
    return true; // Mencegah crash fatal pada level engine dan memelihara koneksi debugger
  };

  // 1. Inisialisasi SQLite database factory untuk platform Desktop (Windows, Linux, macOS)
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 2. Inisialisasi Firebase dengan konfigurasi platform saat ini
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('[Main] Info inisialisasi Firebase SDK: $e');
  }

  // 3. Inisialisasi Notification Service & Channels
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('[Main] Gagal menginisialisasi NotificationService: $e');
  }

  // 4. Sinkronisasi penuh lintas perangkat (Multi-Platform Cloud Sync: PC, Android, iOS, Web)
  // Menjamin seluruh HP & PC memiliki database pengguna, produk, layanan, transaksi, dan SMTP yang persis sama
  try {
    CloudSyncService.instance.startRealtimeSync();
  } catch (e) {
    debugPrint('[Main] Realtime background sync info: $e');
  }

  // 5. Inisialisasi locale formatting untuk format tanggal & mata uang Rupiah
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    debugPrint('[Main] Gagal menginisialisasi locale id_ID: $e');
  }

  // 6. Inisialisasi layanan tema (Dark Mode / Light Mode) dari SharedPreferences
  try {
    await ThemeService.initTheme();
  } catch (e) {
    debugPrint('[Main] Gagal menginisialisasi ThemeService: $e');
  }

  // 7. Inisialisasi layanan bahasa (Indonesia / English) dari SharedPreferences
  try {
    await LanguageService.initLanguage();
  } catch (e) {
    debugPrint('[Main] Gagal menginisialisasi LanguageService: $e');
  }

  // 8. Inisialisasi layanan saldo pengguna aktif dari SQLite / SharedPreferences
  try {
    await BalanceService.initBalance();
  } catch (e) {
    debugPrint('[Main] Gagal menginisialisasi BalanceService: $e');
  }

  // 9. Jalankan aplikasi utama
  runApp(const VibeTechApp());
}

/// ============================================================================
/// ROOT WIDGET APLIKASI VIBETECH
/// ============================================================================
/// Widget root yang mendengarkan perubahan bahasa dan tema secara reaktif melalui
/// [LanguageService.languageNotifier] dan [ThemeService.themeNotifier].
class VibeTechApp extends StatelessWidget {
  const VibeTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, isDarkMode, _) {
        return ValueListenableBuilder<String>(
          valueListenable: LanguageService.languageNotifier,
          builder: (context, currentLang, child) {
            return MaterialApp(
              title: 'VibeTech XYZ',
              debugShowCheckedModeBanner: false,
              themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
              // Konfigurasi Tema Terang (Light Mode)
              theme: ThemeData(
                primarySwatch: Colors.purple,
                scaffoldBackgroundColor: const Color(0xFFF8FAFC),
                brightness: Brightness.light,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF7C4DFF),
                  brightness: Brightness.light,
                  primary: const Color(0xFF7C4DFF),
                  secondary: const Color(0xFFE040FB),
                  surface: Colors.white,
                ),
                fontFamily: 'Poppins',
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  centerTitle: true,
                  iconTheme: IconThemeData(color: Color(0xFF1E293B)),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF7C4DFF), width: 2),
                  ),
                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              // Konfigurasi Tema Gelap (Dark Mode)
              darkTheme: ThemeData(
                primarySwatch: Colors.purple,
                scaffoldBackgroundColor: const Color(0xFF060814),
                brightness: Brightness.dark,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF7C4DFF),
                  brightness: Brightness.dark,
                  primary: const Color(0xFF7C4DFF),
                  secondary: const Color(0xFFE040FB),
                  surface: const Color(0xFF0F1426),
                ),
                fontFamily: 'Poppins',
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF0F1426),
                  elevation: 0,
                  centerTitle: true,
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: const Color(0xFF141A29),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF7C4DFF), width: 2),
                  ),
                  labelStyle: const TextStyle(color: Colors.white70),
                ),
              ),
              // Halaman pembuka awal (Splash Screen)
              home: const SplashPage(),
            );
          },
        );
      },
    );
  }
}
