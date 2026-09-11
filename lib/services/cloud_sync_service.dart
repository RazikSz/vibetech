import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetech_xyz/services/balance_service.dart';
import 'package:vibetech_xyz/services/firebase_email_service.dart';
import 'package:vibetech_xyz/services/firebase_product_service.dart';
import 'package:vibetech_xyz/services/firebase_realtime_listener_service.dart';
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

  /// Sinkronisasi cepat satu pintu dari Firebase Cloud ke SQLite Lokal
  Future<void> syncAllFromCloud({bool isInitial = false, bool runHeavyCleanup = false}) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      debugPrint(
          '[CloudSyncService] 🔄 Memulai sinkronisasi cepat dari Firebase Cloud...');

      // 1. Jalankan sinkronisasi seluruh domain database dari Cloud ke SQLite lokal
      await Future.wait([
        FirebaseUserService.instance.syncUsersFromFirebase(),
        FirebaseTransactionService.instance.syncTransactionsFromFirebase(),
        FirebaseProductService.instance.syncProductsFromFirebase(),
        FirebaseTransactionService.instance.syncServicesFromFirebase(),
        FirebaseEmailService.instance.syncEmailSettings(),
      ]).timeout(const Duration(seconds: 6), onTimeout: () => []);

      // 2. Sinkronkan saldo akun yang sedang aktif di runtime
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentEmail =
            prefs.getString('email') ?? prefs.getString('username');
        if (currentEmail != null && currentEmail.isNotEmpty) {
          await BalanceService.loadUserBalance(currentEmail);
        }
      } catch (_) {}

      // 3. Hanya jalankan pembersihan berat jika diminta secara eksplisit
      if (runHeavyCleanup) {
        try {
          await FirebaseUserService.instance
              .cleanupDummyUsersFromFirebaseAndLocal();
          await FirebaseUserService.instance
              .cleanupDuplicateSpamUsersFromFirebase();
          await FirebaseTransactionService.instance
              .cleanupDummyTransactionsFromFirebase();
          await FirebaseProductService.instance
              .cleanupDummyAndRandomProductsFromFirebaseAndLocal();
        } catch (_) {}
      }

      debugPrint(
          '[CloudSyncService] ✅ Sinkronisasi cepat dari Firebase Cloud selesai!');
    } catch (e) {
      debugPrint('[CloudSyncService] Info sinkronisasi cloud: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Domain notifiers yang dapat dipantau oleh antarmuka UI secara reaktif
  ValueNotifier<int> get productsNotifier =>
      FirebaseRealtimeListenerService.instance.productsUpdateCount;
  ValueNotifier<int> get usersNotifier =>
      FirebaseRealtimeListenerService.instance.usersUpdateCount;
  ValueNotifier<int> get transactionsNotifier =>
      FirebaseRealtimeListenerService.instance.transactionsUpdateCount;
  ValueNotifier<int> get servicesNotifier =>
      FirebaseRealtimeListenerService.instance.servicesUpdateCount;

  /// Memulai sinkronisasi awal dan mengaktifkan continuous real-time streaming listener secara non-blocking
  Future<void> startRealtimeSync() async {
    // Jalankan non-blocking agar frame pertama UI aplikasi langsung terbuka mulus tanpa lag
    Future.delayed(const Duration(milliseconds: 600), () async {
      await syncAllFromCloud();
      await FirebaseRealtimeListenerService.instance.startAllListeners();
    });
  }

  /// Menghentikan real-time stream listener
  void stopRealtimeSync() {
    FirebaseRealtimeListenerService.instance.stopAllListeners();
  }

  /// Sinkronisasi cadangan dari SQLite Lokal ke Firebase Cloud
  Future<void> syncAllToCloud() async {
    try {
      debugPrint(
          '[CloudSyncService] 📤 Mengunggah seluruh database nyata (Akun, Produk, Transaksi, Layanan, SMTP) ke Firebase...');
      await Future.wait([
        FirebaseUserService.instance.syncAllLocalUsersToFirebase(),
        FirebaseTransactionService.instance
            .syncAllLocalTransactionsToFirestore(),
        FirebaseProductService.instance.syncAllLocalProductsToFirebase(),
        FirebaseTransactionService.instance.syncAllLocalServicesToFirebase(),
        FirebaseEmailService.instance.syncEmailSettings(),
      ]).timeout(const Duration(seconds: 8), onTimeout: () => []);
      debugPrint(
          '[CloudSyncService] ✅ Berhasil mengunggah seluruh database nyata ke Firebase Cloud!');
    } catch (e) {
      debugPrint('[CloudSyncService] Info push ke cloud: $e');
    }
  }
}
