import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================================
/// LAYANAN PENGATURAN TEMA (THEME SERVICE) - VIBETECH XYZ
/// ============================================================================
/// Layanan global untuk mengelola mode tema (Dark Mode / Light Mode):
/// 1. Berbasis [ValueNotifier<bool>] untuk pembaruan instan dan sinkron di seluruh halaman.
/// 2. Menyimpan preferensi tema secara persisten ke [SharedPreferences].
/// 3. Menghubungkan LoginPage, DashboardPage, dan seluruh komponen aplikasi.
class ThemeService {
  /// Notifier tema aktif (true = Dark Mode / Cyber Neon, false = Light Mode / Modern Clean)
  static final ValueNotifier<bool> themeNotifier = ValueNotifier<bool>(true);

  /// Mengambil status Dark Mode aktif saat ini
  static bool get isDarkMode => themeNotifier.value;

  /// Memuat preferensi tema yang tersimpan dari SharedPreferences
  /// Jika belum ada preferensi tersimpan, tema akan otomatis disesuaikan berdasarkan waktu saat ini.
  static Future<void> initTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('isDarkMode')) {
        themeNotifier.value = prefs.getBool('isDarkMode') ?? true;
      } else {
        // Otomatis Dark Mode pada malam hari (18:00 - 06:00), Light Mode pada siang hari
        final currentHour = DateTime.now().hour;
        final autoDark = (currentHour >= 18 || currentHour < 6);
        themeNotifier.value = autoDark;
      }
    } catch (e) {
      debugPrint('[ThemeService] Gagal memuat tema tersimpan: $e');
    }
  }

  /// Mengubah mode tema secara manual dan menyimpannya secara persisten ke SharedPreferences
  static Future<void> setTheme(bool isDark) async {
    themeNotifier.value = isDark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', isDark);
    } catch (e) {
      debugPrint('[ThemeService] Gagal menyimpan preferensi tema: $e');
    }
  }

  /// Membalikkan mode tema aktif (Dark -> Light atau Light -> Dark)
  static Future<void> toggleTheme() async {
    await setTheme(!themeNotifier.value);
  }
}
