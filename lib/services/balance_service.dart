import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';
import 'firebase_user_service.dart';

/// ============================================================================
/// LAYANAN SALDO VIBEWALLET (BALANCE SERVICE) - VIBETECH XYZ
/// ============================================================================
/// Layanan global yang menangani sinkronisasi saldo aktif pengguna:
/// 1. Berbasis [ValueNotifier<int>] sehingga perubahan saldo langsung ter-update di seluruh UI (Header, Dashboard, Checkout).
/// 2. Terkoneksi ganda: Menulis/Membaca ke SQLite Database dan cache SharedPreferences.
/// 3. Isolasi Saldo Multi-Akun: Saldo tersimpan secara spesifik per email/username pengguna.
class BalanceService {
  /// Saldo awal default jika akun belum terdata di SQLite
  static const int defaultInitialBalance = 0;

  /// Identifier (Email / Username) akun pengguna yang sedang aktif
  static String _activeUserIdentifier = 'user@vibetech.com';

  /// ValueNotifier reaktif penyimpan saldo aktif (Rupiah)
  static final ValueNotifier<int> notifier =
      ValueNotifier<int>(defaultInitialBalance);

  /// Nilai saldo aktif saat ini
  static int get balance => notifier.value;

  /// Pengguna aktif saat ini
  static String get activeUser => _activeUserIdentifier;

  /// Kunci cache SharedPreferences unik per akun
  static String _getKey(String identifier) =>
      'user_balance_${identifier.toLowerCase().trim()}';

  /// Inisialisasi awal saat aplikasi mulai atau saat pengguna berhasil login
  static Future<void> initBalance({String? emailOrUsername}) async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = emailOrUsername ??
        prefs.getString('email') ??
        prefs.getString('username') ??
        'user@vibetech.com';
    await loadUserBalance(savedEmail);
  }

  /// Memuat saldo spesifik untuk akun pengguna dari SQLite Database / SharedPreferences / Firebase RTDB
  static Future<int> loadUserBalance(String emailOrUsername) async {
    _activeUserIdentifier = emailOrUsername.trim();
    final prefs = await SharedPreferences.getInstance();

    // 1. Coba ambil dari database lokal SQLite
    try {
      final dbBalance =
          await DatabaseHelper.instance.getUserBalance(_activeUserIdentifier);
      notifier.value = dbBalance.toInt();
      await prefs.setInt(_getKey(_activeUserIdentifier), notifier.value);
    } catch (_) {}

    // 2. Refresh live dari Firebase Realtime Database secara background (Cross-device sync)
    FirebaseUserService.instance.getUserFromFirebase(_activeUserIdentifier).then((cloudUser) {
      if (cloudUser != null && cloudUser['saldo'] != null) {
        final cloudSaldo = (cloudUser['saldo'] as num).toInt();
        if (cloudSaldo != notifier.value) {
          notifier.value = cloudSaldo;
          DatabaseHelper.instance.updateUserBalance(_activeUserIdentifier, cloudSaldo.toDouble());
          prefs.setInt(_getKey(_activeUserIdentifier), cloudSaldo);
        }
      }
    }).catchError((_) {});

    final key = _getKey(_activeUserIdentifier);
    final cached = prefs.getInt(key) ?? notifier.value;
    return cached;
  }

  /// Mengurangi saldo untuk akun tertentu saat melakukan transaksi pembayaran
  static Future<bool> deductBalance(int amount,
      {String? emailOrUsername}) async {
    final target = (emailOrUsername ?? _activeUserIdentifier).trim();

    // Verifikasi ketersediaan saldo di database SQLite
    final currentDb = await DatabaseHelper.instance.getUserBalance(target);
    if (currentDb < amount) {
      return false; // Saldo tidak mencukupi
    }

    final success =
        await DatabaseHelper.instance.deductSaldo(target, amount.toDouble());
    if (!success) {
      return false;
    }

    final updated = (currentDb - amount).toInt();
    if (target.toLowerCase() == _activeUserIdentifier.toLowerCase()) {
      notifier.value = updated;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_getKey(target), updated);
    return true;
  }

  /// Menambahkan saldo untuk akun tertentu saat Top Up berhasil
  static Future<void> addBalance(int amount, {String? emailOrUsername}) async {
    final target = (emailOrUsername ?? _activeUserIdentifier).trim();

    final newDbBalance =
        await DatabaseHelper.instance.addSaldo(target, amount.toDouble());
    final updated = newDbBalance.toInt();

    if (target.toLowerCase() == _activeUserIdentifier.toLowerCase()) {
      notifier.value = updated;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_getKey(target), updated);
  }

  /// Mereset session saldo saat pengguna melakukan logout
  static void resetActiveUser() {
    _activeUserIdentifier = '';
    notifier.value = defaultInitialBalance;
  }
}
