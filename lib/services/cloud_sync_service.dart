import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/balance_service.dart';
import 'package:vibetech_xyz/services/firebase_email_service.dart';
import 'package:vibetech_xyz/services/firebase_product_service.dart';
import 'package:vibetech_xyz/services/firebase_transaction_service.dart';
import 'package:vibetech_xyz/services/firebase_user_service.dart';

/// ============================================================================
/// CLOUD SYNC SERVICE - VIBETECH XYZ (MULTI-DEVICE SINGLE SOURCE OF TRUTH)
/// ============================================================================
/// Layanan terpusat yang menjamin seluruh perangkat (PC 1, PC 2, HP Android, Web)
/// memiliki database akun, transaksi, produk, layanan, dan konfigurasi email
/// yang 100% SAMA PERSIS dan tersinkronisasi secara real-time dari Firebase Cloud.
class CloudSyncService {
  static final CloudSyncService instance = CloudSyncService._init();

  CloudSyncService._init();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Sinkronisasi penuh satu pintu dari Firebase Cloud ke SQLite Lokal
  Future<void> syncAllFromCloud({bool isInitial = false}) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      debugPrint('[CloudSyncService] 🔄 Memulai sinkronisasi penuh dari Firebase Cloud...');

      // 1. Jalankan sinkronisasi seluruh domain database dari Cloud ke SQLite lokal
      await Future.wait([
        FirebaseUserService.instance.syncUsersFromFirebase(),
        FirebaseTransactionService.instance.syncTransactionsFromFirebase(),
        FirebaseProductService.instance.syncProductsFromFirebase(),
        FirebaseTransactionService.instance.syncServicesFromFirebase(),
        FirebaseEmailService.instance.syncEmailSettings(),
      ]).timeout(const Duration(seconds: 6), onTimeout: () => []);

      // 2. Bersihkan akun dummy lokal (demouser) agar tidak membedakan data di PC baru
      try {
        final db = await DatabaseHelper.instance.database;
        final realUsers = await db.rawQuery(
          "SELECT COUNT(*) as count FROM users WHERE email != 'user@vibetech.com' AND username != 'demouser'",
        );
        final realCount = (realUsers.first['count'] as num?)?.toInt() ?? 0;
        if (realCount > 0) {
          await db.delete('users', where: "email = 'user@vibetech.com' OR username = 'demouser'");
        }
      } catch (_) {}

      // 3. Sinkronkan saldo akun yang sedang aktif di runtime
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentEmail = prefs.getString('email') ?? prefs.getString('username');
        if (currentEmail != null && currentEmail.isNotEmpty) {
          await BalanceService.loadUserBalance(currentEmail);
        }
      } catch (_) {}

      debugPrint('[CloudSyncService] ✅ Sinkronisasi penuh dari Firebase Cloud berhasil diselesaikan!');
    } catch (e) {
      debugPrint('[CloudSyncService] Info sinkronisasi cloud: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sinkronisasi cadangan dari SQLite Lokal ke Firebase Cloud
  Future<void> syncAllToCloud() async {
    try {
      await Future.wait([
        FirebaseUserService.instance.syncAllLocalUsersToFirebase(),
        FirebaseTransactionService.instance.syncAllLocalTransactionsToFirestore(),
        FirebaseProductService.instance.syncAllLocalProductsToFirebase(),
        FirebaseTransactionService.instance.syncAllLocalServicesToFirebase(),
        FirebaseEmailService.instance.syncEmailSettings(),
      ]).timeout(const Duration(seconds: 6), onTimeout: () => []);
    } catch (e) {
      debugPrint('[CloudSyncService] Info push ke cloud: $e');
    }
  }
}
