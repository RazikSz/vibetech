import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/referral_tier_model.dart';
import 'balance_service.dart';
import 'notification_service.dart';
import 'firebase_auth_token_service.dart';
import 'firebase_user_service.dart';

/// ============================================================================
/// SERVICE SISTEM REFERRAL & RESELLER TIER (AFFILIATE ENGINE)
/// ============================================================================
/// Mengelola:
/// 1. Pembuatan & validasi kode referral unik setiap akun.
/// 2. Akumulasi total belanja pengguna untuk kenaikan level Reseller Tier.
/// 3. Perhitungan dan pencairan otomatis komisi referral saat downline bertransaksi.
/// 4. Pemberian diskon otomatis member (Silver, Gold, Platinum).
/// 5. Sinkronisasi ganda: SQLite Database lokal & Firebase Realtime Database.
class ReferralService {
  static final ReferralService instance = ReferralService._init();
  ReferralService._init();

  static const String _firebaseDbUrl =
      'https://vibetech-xyz-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Mendapatkan atau membuat kode referral unik akun
  Future<String> getOrCreateReferralCode({
    required String userEmail,
    required String username,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query(
        'users',
        columns: ['referralCode'],
        where: 'LOWER(email) = ? OR LOWER(username) = ?',
        whereArgs: [userEmail.toLowerCase().trim(), username.toLowerCase().trim()],
      );

      String? existingCode;
      if (res.isNotEmpty && res.first['referralCode'] != null) {
        existingCode = res.first['referralCode']?.toString().trim();
      }

      if (existingCode != null && existingCode.isNotEmpty) {
        return existingCode;
      }

      // Generate kode baru: VT-USERNAME (atau fallback 6 char)
      final cleanUsername = username.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      final String newCode = cleanUsername.isNotEmpty
          ? 'VT-$cleanUsername'
          : 'VT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // Simpan ke SQLite
      await db.update(
        'users',
        {'referralCode': newCode},
        where: 'LOWER(email) = ? OR LOWER(username) = ?',
        whereArgs: [userEmail.toLowerCase().trim(), username.toLowerCase().trim()],
      );

      // Simpan ke Firebase RTDB di background
      _syncReferralCodeToFirebase(userEmail, newCode);

      return newCode;
    } catch (e) {
      debugPrint('[ReferralService] Error getOrCreateReferralCode: $e');
      final cleanUsername = username.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      return 'VT-$cleanUsername';
    }
  }

  /// Menghubungkan downline dengan pengundang (referrer)
  Future<bool> bindReferrer({
    required String userEmail,
    required String referralCode,
  }) async {
    try {
      final code = referralCode.trim().toUpperCase();
      if (code.isEmpty) return false;

      final db = await DatabaseHelper.instance.database;

      // Cek apakah kode referral ini valid (bukan milik sendiri)
      final selfCheck = await db.query(
        'users',
        where: '(LOWER(email) = ? OR LOWER(username) = ?) AND UPPER(referralCode) = ?',
        whereArgs: [userEmail.toLowerCase().trim(), userEmail.toLowerCase().trim(), code],
      );
      if (selfCheck.isNotEmpty) {
        debugPrint('[ReferralService] Tidak bisa menggunakan kode referral milik sendiri.');
        return false;
      }

      // Update di SQLite
      await db.update(
        'users',
        {'referredBy': code},
        where: 'LOWER(email) = ?',
        whereArgs: [userEmail.toLowerCase().trim()],
      );

      // Sync ke Firebase
      _syncReferredByToFirebase(userEmail, code);
      return true;
    } catch (e) {
      debugPrint('[ReferralService] Error bindReferrer: $e');
      return false;
    }
  }

  /// Menghitung statistik lengkap Reseller Tier dan Referral pengguna
  Future<Map<String, dynamic>> getUserTierStats(String userEmail) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final cleanEmail = userEmail.toLowerCase().trim();

      // 1. Ambil data user
      final userRows = await db.query(
        'users',
        where: 'LOWER(email) = ?',
        whereArgs: [cleanEmail],
      );

      String myReferralCode = '';
      String myReferredBy = '';
      if (userRows.isNotEmpty) {
        myReferralCode = userRows.first['referralCode']?.toString() ?? '';
        myReferredBy = userRows.first['referredBy']?.toString() ?? '';
      }

      // 2. Hitung total belanja dari transaksi sukses
      final txRows = await db.rawQuery('''
        SELECT SUM(total_harga) as totalSpending 
        FROM transactions 
        WHERE LOWER(user_email) = ? AND (LOWER(status) = 'selesai' OR LOWER(status) = 'success' OR LOWER(status) = 'paid')
      ''', [cleanEmail]);

      double totalSpending = 0.0;
      if (txRows.isNotEmpty && txRows.first['totalSpending'] != null) {
        totalSpending = (txRows.first['totalSpending'] as num).toDouble();
      }

      // 3. Hitung jumlah teman yang menggunakan referral code ini
      int referralCount = 0;
      if (myReferralCode.isNotEmpty) {
        final refRows = await db.rawQuery('''
          SELECT COUNT(*) as count 
          FROM users 
          WHERE UPPER(referredBy) = ?
        ''', [myReferralCode.toUpperCase()]);
        if (refRows.isNotEmpty && refRows.first['count'] != null) {
          referralCount = (refRows.first['count'] as num).toInt();
        }
      }

      // 4. Hitung total komisi yang pernah didapatkan
      double totalCommissionEarned = 0.0;
      try {
        final commRows = await db.rawQuery('''
          SELECT SUM(commissionAmount) as totalComm 
          FROM referral_history 
          WHERE LOWER(referrerEmail) = ?
        ''', [cleanEmail]);
        if (commRows.isNotEmpty && commRows.first['totalComm'] != null) {
          totalCommissionEarned = (commRows.first['totalComm'] as num).toDouble();
        }
      } catch (_) {}

      // 5. Tentukan Reseller Tier
      final currentTier = ResellerTierHelper.getTier(
        totalSpending: totalSpending,
        referralCount: referralCount,
      );

      final (nextTier, progress, remaining) = ResellerTierHelper.getNextTierProgress(
        totalSpending: totalSpending,
        referralCount: referralCount,
      );

      return {
        'referralCode': myReferralCode,
        'referredBy': myReferredBy,
        'totalSpending': totalSpending,
        'referralCount': referralCount,
        'totalCommissionEarned': totalCommissionEarned,
        'currentTier': currentTier,
        'nextTier': nextTier,
        'nextTierProgress': progress,
        'remainingSpendingForNextTier': remaining,
      };
    } catch (e) {
      debugPrint('[ReferralService] Error getUserTierStats: $e');
      return {
        'referralCode': '',
        'referredBy': '',
        'totalSpending': 0.0,
        'referralCount': 0,
        'totalCommissionEarned': 0.0,
        'currentTier': ResellerTierHelper.standardTier,
        'nextTier': ResellerTierHelper.silverTier,
        'nextTierProgress': 0.0,
        'remainingSpendingForNextTier': 500000.0,
      };
    }
  }

  /// Dipanggil otomatis saat checkout selesai (di pembayaran_page.dart)
  Future<void> processOrderSettlement({
    required String buyerEmail,
    required double totalAmount,
    required String invoiceNo,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final cleanBuyer = buyerEmail.toLowerCase().trim();

      // Buat tabel referral_history jika belum ada
      await db.execute('''
        CREATE TABLE IF NOT EXISTS referral_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          referrerEmail TEXT,
          buyerEmail TEXT,
          orderAmount REAL,
          commissionAmount REAL,
          tier TEXT,
          invoiceNo TEXT,
          createdAt TEXT
        )
      ''');

      // 1. Cek apakah pembeli terhubung dengan pengundang (referredBy)
      final buyerRows = await db.query(
        'users',
        columns: ['referredBy', 'username', 'nama'],
        where: 'LOWER(email) = ?',
        whereArgs: [cleanBuyer],
      );

      if (buyerRows.isEmpty) return;
      final referredByCode = buyerRows.first['referredBy']?.toString().trim().toUpperCase();
      if (referredByCode == null || referredByCode.isEmpty) {
        debugPrint('[ReferralService] Pembeli $buyerEmail tidak memiliki pengundang (organic user).');
        return;
      }

      // 2. Cari data pengundang berdasarkan kode referral
      final referrerRows = await db.query(
        'users',
        where: 'UPPER(referralCode) = ?',
        whereArgs: [referredByCode],
      );

      if (referrerRows.isEmpty) {
        debugPrint('[ReferralService] Pengundang dengan kode $referredByCode tidak ditemukan.');
        return;
      }

      final referrer = referrerRows.first;
      final String referrerEmail = referrer['email']?.toString() ?? '';
      final String referrerUid = referrer['uid']?.toString() ?? '';
      if (referrerEmail.isEmpty) return;

      // 3. Hitung statistik pengundang untuk menentukan tier & rate komisinya
      final referrerStats = await getUserTierStats(referrerEmail);
      final ResellerTierInfo referrerTier = referrerStats['currentTier'] as ResellerTierInfo;

      // 4. Hitung nominal komisi
      final double commissionAmount = ResellerTierHelper.calculateCommission(totalAmount, referrerTier);
      if (commissionAmount <= 0) return;

      // 5. Tambahkan komisi langsung ke Saldo VibeWallet pengundang
      await BalanceService.addBalance(
        commissionAmount.toInt(),
        emailOrUsername: referrerEmail,
      );

      // Simpan riwayat komisi ke SQLite
      final String nowIso = DateTime.now().toIso8601String();
      await db.insert('referral_history', {
        'referrerEmail': referrerEmail,
        'buyerEmail': buyerEmail,
        'orderAmount': totalAmount,
        'commissionAmount': commissionAmount,
        'tier': referrerTier.title,
        'invoiceNo': invoiceNo,
        'createdAt': nowIso,
      });

      // 6. Simpan transaksi komisi ke tabel transaksi agar muncul di mutasi saldo pengundang
      await db.insert('transactions', {
        'user_email': referrerEmail,
        'nama_produk': 'Komisi Referral (${referrerTier.badgeText})',
        'jumlah': 1,
        'total_harga': commissionAmount,
        'tanggal': nowIso,
        'status': 'Selesai',
        'payment_method': 'Referral Reward',
        'invoice_no': 'REF-${DateTime.now().millisecondsSinceEpoch}',
        'notes': 'Komisi dari pembelian $buyerEmail (#$invoiceNo)',
      });

      // 7. Sinkronkan ke Firebase RTDB
      _syncCommissionToFirebase(
        referrerUid: referrerUid,
        referrerEmail: referrerEmail,
        buyerEmail: buyerEmail,
        orderAmount: totalAmount,
        commissionAmount: commissionAmount,
        tier: referrerTier.title,
        invoiceNo: invoiceNo,
        createdAt: nowIso,
      );

      // 8. Kirim Push Notification & notifikasi lokal ke Pengundang
      final formattedComm = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(commissionAmount);

      const notifTitle = 'Komisi Referral Masuk! 🎉';
      final notifBody = 'Selamat! Saldo VibeWallet Anda bertambah $formattedComm (${referrerTier.commissionPercentText}) dari transaksi member referral Anda ($buyerEmail).';

      await NotificationService.showSystemNotification(
        title: notifTitle,
        body: notifBody,
        category: 'Kemitraan & Referral',
        payload: invoiceNo,
      );

      await NotificationService.syncNotificationToFirebase(referrerEmail, {
        'title': notifTitle,
        'body': notifBody,
        'type': 'referral_commission',
        'payload': invoiceNo,
        'order_id': 'REF_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': nowIso,
      });

      // 9. Sinkronisasi status Reseller Tier & Total Belanja Pengguna & Pengundang ke Firebase RTDB
      Future.microtask(() async {
        try {
          final buyerStats = await getUserTierStats(buyerEmail);
          final ResellerTierInfo buyerTier = buyerStats['currentTier'] as ResellerTierInfo;
          await FirebaseUserService.instance.updateUserInFirebase(
            email: buyerEmail.contains('@') ? buyerEmail : null,
            username: !buyerEmail.contains('@') ? buyerEmail : null,
            updatedData: {
              'totalSpending': buyerStats['totalSpending'],
              'resellerTier': buyerTier.title,
            },
          );
          await FirebaseUserService.instance.updateUserInFirebase(
            email: referrerEmail.contains('@') ? referrerEmail : null,
            username: !referrerEmail.contains('@') ? referrerEmail : null,
            updatedData: {
              'resellerTier': referrerTier.title,
              'referralCount': referrerStats['referralCount'],
            },
          );
        } catch (_) {}
      });

      debugPrint('[ReferralService] ✅ Komisi $formattedComm berhasil dikreditkan ke $referrerEmail!');
    } catch (e) {
      debugPrint('[ReferralService] Error processOrderSettlement: $e');
    }
  }

  /// Mengambil daftar riwayat komisi yang diperoleh pengguna
  Future<List<ReferralHistoryItem>> getReferralHistory(String userEmail) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'referral_history',
        where: 'LOWER(referrerEmail) = ?',
        whereArgs: [userEmail.toLowerCase().trim()],
        orderBy: 'createdAt DESC',
        limit: 50,
      );
      return rows.map((r) => ReferralHistoryItem.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[ReferralService] Error getReferralHistory: $e');
      return [];
    }
  }

  // --- PRIVATE FIREBASE SYNC METHODS ---
  void _syncReferralCodeToFirebase(String email, String code) {
    Future.microtask(() async {
      try {
        final token = await FirebaseAuthTokenService.instance.getIdToken();
        final authParam = (token != null && token.isNotEmpty) ? '?auth=$token' : '';
        final safeKey = email.replaceAll('.', '_').replaceAll('@', '_at_');
        final uri = Uri.parse('$_firebaseDbUrl/users_meta/$safeKey/referral.json$authParam');
        await http.patch(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'referralCode': code,
            'updatedAt': DateTime.now().toIso8601String(),
          }),
        );
        await FirebaseUserService.instance.updateUserInFirebase(
          email: email.contains('@') ? email : null,
          username: !email.contains('@') ? email : null,
          updatedData: {'referralCode': code},
        );
      } catch (_) {}
    });
  }

  void _syncReferredByToFirebase(String email, String code) {
    Future.microtask(() async {
      try {
        final token = await FirebaseAuthTokenService.instance.getIdToken();
        final authParam = (token != null && token.isNotEmpty) ? '?auth=$token' : '';
        final safeKey = email.replaceAll('.', '_').replaceAll('@', '_at_');
        final uri = Uri.parse('$_firebaseDbUrl/users_meta/$safeKey/referral.json$authParam');
        await http.patch(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'referredBy': code,
            'boundAt': DateTime.now().toIso8601String(),
          }),
        );
        await FirebaseUserService.instance.updateUserInFirebase(
          email: email.contains('@') ? email : null,
          username: !email.contains('@') ? email : null,
          updatedData: {'referredBy': code},
        );
      } catch (_) {}
    });
  }

  void _syncCommissionToFirebase({
    required String referrerUid,
    required String referrerEmail,
    required String buyerEmail,
    required double orderAmount,
    required double commissionAmount,
    required String tier,
    required String invoiceNo,
    required String createdAt,
  }) {
    Future.microtask(() async {
      try {
        final token = await FirebaseAuthTokenService.instance.getIdToken();
        final authParam = (token != null && token.isNotEmpty) ? '?auth=$token' : '';
        final commId = 'comm_${DateTime.now().millisecondsSinceEpoch}';
        final uri = Uri.parse('$_firebaseDbUrl/referral_commissions/$commId.json$authParam');
        await http.put(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'referrerUid': referrerUid,
            'referrerEmail': referrerEmail,
            'buyerEmail': buyerEmail,
            'orderAmount': orderAmount,
            'commissionAmount': commissionAmount,
            'tier': tier,
            'invoiceNo': invoiceNo,
            'createdAt': createdAt,
          }),
        );
      } catch (_) {}
    });
  }
}
