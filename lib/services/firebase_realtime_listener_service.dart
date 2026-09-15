import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/balance_service.dart';
import 'package:vibetech_xyz/services/firebase_auth_token_service.dart';
import 'package:vibetech_xyz/services/firebase_product_service.dart';
import 'package:vibetech_xyz/services/firebase_transaction_service.dart';
import 'package:vibetech_xyz/services/firebase_user_service.dart';
import 'package:vibetech_xyz/utils/security_helper.dart';

/// ============================================================================
/// FIREBASE REALTIME LISTENER SERVICE - VIBETECH XYZ
/// ============================================================================
/// Layanan streaming real-time yang mendengarkan perubahan pada Firebase Realtime
/// Database secara langsung (Server-Sent Events / SSE Stream) di semua platform
/// (Desktop Windows, Android, iOS, Web).
///
/// Fitur Utama:
/// 1. Real-time Reactive: Saat data diubah di Firebase Console / Perangkat lain,
///    event langsung diterima dalam hitungan milidetik.
/// 2. Permanent SQLite Persistence: Setiap perubahan langsung disimpan permanen
///    ke database SQLite lokal (products, users, transactions, purchased_services).
/// 3. Echo-Loop Guard: Mencegah siklus sinkronisasi tak berujung (looping).
/// 4. Auto-Reconnect: Otomatis menghubungkan ulang jika jaringan terputus.
class FirebaseRealtimeListenerService {
  static final FirebaseRealtimeListenerService instance =
      FirebaseRealtimeListenerService._init();

  FirebaseRealtimeListenerService._init();

  static const String rtdbBaseUrl =
      'https://vibetech-xyz-default-rtdb.asia-southeast1.firebasedatabase.app';

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Guard untuk mencegah trigger balik ke Firebase saat perubahan berasal dari Cloud
  static bool isApplyingCloudUpdate = false;

  // Domain Notifiers untuk pembaruan UI instan
  final ValueNotifier<int> productsUpdateCount = ValueNotifier<int>(0);
  final ValueNotifier<int> usersUpdateCount = ValueNotifier<int>(0);
  final ValueNotifier<int> transactionsUpdateCount = ValueNotifier<int>(0);
  final ValueNotifier<int> servicesUpdateCount = ValueNotifier<int>(0);

  // Clients & Stream Subscriptions
  final Map<String, http.Client> _activeClients = {};
  final Map<String, StreamSubscription> _activeSubs = {};
  final Map<String, Timer> _reconnectTimers = {};
  final Map<String, int> _retryCounts = {};

  /// Memulai seluruh real-time stream listener untuk semua node database
  Future<void> startAllListeners() async {
    if (_isRunning) return;
    _isRunning = true;
    debugPrint('[RealtimeListener] 🚀 Memulai seluruh listener real-time Firebase RTDB...');

    await _startNodeListener('products');
    await _startNodeListener('promo_discounts');
    await _startNodeListener('users');
    await _startNodeListener('transactions');
    await _startNodeListener('invoices');
    await _startNodeListener('services');
    await _startNodeListener('purchased_services');
    await _startNodeListener('email_settings');
  }

  /// Menghentikan seluruh listener
  void stopAllListeners() {
    _isRunning = false;
    for (final timer in _reconnectTimers.values) {
      try {
        timer.cancel();
      } catch (_) {}
    }
    _reconnectTimers.clear();
    _retryCounts.clear();

    for (final sub in _activeSubs.values) {
      try {
        sub.cancel();
      } catch (_) {}
    }
    _activeSubs.clear();

    for (final client in _activeClients.values) {
      try {
        client.close();
      } catch (_) {}
    }
    _activeClients.clear();

    debugPrint('[RealtimeListener] 🛑 Seluruh listener real-time dihentikan.');
  }

  /// Memulai listener untuk SATU node spesifik dengan auto-reconnect
  Future<void> _startNodeListener(String nodeName) async {
    if (!_isRunning) return;

    // Bersihkan koneksi lama jika ada
    try {
      _activeSubs[nodeName]?.cancel();
      _activeClients[nodeName]?.close();
    } catch (_) {}

    try {
      // 1. Dapatkan auth token jika node membutuhkan izin
      String authParam = '';
      if (nodeName != 'products') {
        final token = await FirebaseAuthTokenService.instance.getIdToken();
        if (token != null && token.isNotEmpty) {
          authParam = '?auth=$token';
        } else {
          debugPrint('[RealtimeListener] ⚠️ Token auth belum tersedia untuk node $nodeName, menjadwalkan ulang...');
          _scheduleReconnect(nodeName);
          return;
        }
      }

      final url = Uri.parse('$rtdbBaseUrl/$nodeName.json$authParam');
      final client = http.Client();
      _activeClients[nodeName] = client;

      final request = http.Request('GET', url)
        ..headers['Accept'] = 'text/event-stream'
        ..headers['Cache-Control'] = 'no-cache';

      debugPrint('[RealtimeListener] 📡 Menghubungkan SSE Stream ke node: $nodeName');
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        debugPrint('[RealtimeListener] ⚠️ Gagal buka stream $nodeName (Status ${streamedResponse.statusCode})');
        client.close();
        if (streamedResponse.statusCode == 401) {
          FirebaseAuthTokenService.instance.clearToken();
        }
        _scheduleReconnect(nodeName);
        return;
      }

      // Reset retry count bila sukses terhubung
      _retryCounts[nodeName] = 0;

      String? currentEventType;
      final sub = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) async {
          try {
            final trimmed = line.trim();
            if (trimmed.isEmpty) return;

            if (trimmed.startsWith('event:')) {
              currentEventType = trimmed.substring(6).trim();
            } else if (trimmed.startsWith('data:')) {
              final rawData = trimmed.substring(5).trim();
              if (rawData == 'null' || rawData.isEmpty) return;

              final dynamic parsed = jsonDecode(rawData);
              if (parsed is Map) {
                final path = parsed['path']?.toString() ?? '/';
                final data = parsed['data'];
                await _handleRealtimeEvent(
                  nodeName: nodeName,
                  eventType: currentEventType ?? 'put',
                  path: path,
                  data: data,
                );
              }
            }
          } catch (eventErr) {
            debugPrint('[RealtimeListener] Error parse event $nodeName: $eventErr');
          }
        },
        onError: (err) {
          debugPrint('[RealtimeListener] Error stream $nodeName: $err');
          _scheduleReconnect(nodeName);
        },
        onDone: () {
          debugPrint('[RealtimeListener] Stream $nodeName tertutup, mencoba rekoneksi...');
          _scheduleReconnect(nodeName);
        },
        cancelOnError: true,
      );

      _activeSubs[nodeName] = sub;
    } catch (e) {
      debugPrint('[RealtimeListener] Exception pada _startNodeListener($nodeName): $e');
      _scheduleReconnect(nodeName);
    }
  }

  void _scheduleReconnect(String nodeName) {
    if (!_isRunning) return;

    // Batalkan timer aktif sebelumnya untuk node ini
    _reconnectTimers[nodeName]?.cancel();

    final retries = _retryCounts[nodeName] ?? 0;
    _retryCounts[nodeName] = retries + 1;

    // Exponential backoff: 5s, 12s, 25s, max 60s
    final delaySeconds = retries == 0 ? 5 : (retries == 1 ? 12 : (retries == 2 ? 25 : 60));

    _reconnectTimers[nodeName] = Timer(Duration(seconds: delaySeconds), () {
      if (_isRunning) {
        _startNodeListener(nodeName);
      }
    });
  }

  /// Public helper untuk testing simulasi event realtime
  Future<void> processEventForTesting({
    required String nodeName,
    required String eventType,
    required String path,
    required dynamic data,
  }) async {
    await _handleRealtimeEvent(
      nodeName: nodeName,
      eventType: eventType,
      path: path,
      data: data,
    );
  }

  /// Memproses event perubahan data dan menyimpannya secara PERMANEN ke SQLite
  Future<void> _handleRealtimeEvent({
    required String nodeName,
    required String eventType,
    required String path,
    required dynamic data,
  }) async {
    isApplyingCloudUpdate = true;
    try {
      switch (nodeName) {
        case 'products':
          await _applyProductsUpdate(path, data, eventType);
          productsUpdateCount.value++;
          break;
        case 'promo_discounts':
          await _applyPromoDiscountsUpdate(path, data, eventType);
          productsUpdateCount.value++;
          break;
        case 'users':
          await _applyUsersUpdate(path, data, eventType);
          usersUpdateCount.value++;
          break;
        case 'transactions':
        case 'invoices':
          await _applyTransactionsUpdate(path, data, eventType);
          transactionsUpdateCount.value++;
          break;
        case 'services':
        case 'purchased_services':
          await _applyServicesUpdate(path, data, eventType);
          servicesUpdateCount.value++;
          break;
        case 'email_settings':
          await _applyEmailSettingsUpdate(path, data, eventType);
          break;
      }
    } catch (e) {
      debugPrint('[RealtimeListener] Gagal memproses update cloud untuk $nodeName: $e');
    } finally {
      isApplyingCloudUpdate = false;
    }
  }

  // ===========================================================================
  // 1. SINKRONISASI REALTIME & PERMANEN PRODUK
  // ===========================================================================
  Future<void> _applyProductsUpdate(String path, dynamic data, String eventType) async {
    final db = await DatabaseHelper.instance.database;

    // A. Snapshot Seluruh Produk (path == '/')
    if (path == '/' && data is Map) {
      for (final entry in data.entries) {
        if (entry.value is Map) {
          final pMap = Map<String, dynamic>.from(entry.value as Map);
          pMap['doc_id'] = entry.key.toString();
          await _saveSingleProductToSqlite(db, pMap);
        }
      }
      debugPrint('[RealtimeListener] ✅ Sinkronisasi snapshot katalog produk (${data.length} item) ke SQLite berhasil.');
      return;
    }

    // B. Perubahan Pada Item Spesifik (misal: /prod_01_vps_starter atau /prod_01_vps_starter/harga)
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final segments = cleanPath.split('/');
    final docKey = segments.first;

    if (segments.length == 1) {
      // Seluruh objek produk diubah atau dihapus
      if (data == null) {
        // Produk dihapus di Firebase -> Hapus juga permanen dari SQLite
        await _deleteProductFromSqlite(db, docKey);
      } else if (data is Map) {
        final pMap = Map<String, dynamic>.from(data);
        pMap['doc_id'] = docKey;
        await _saveSingleProductToSqlite(db, pMap);
      }
    } else if (segments.length >= 2) {
      // Satu atribut spesifik diubah langsung di Firebase Console (misal: harga atau diskon)
      final field = segments[1];
      await _updateProductFieldInSqlite(db, docKey, field, data);
    }
  }

  Future<void> _saveSingleProductToSqlite(dynamic db, Map<String, dynamic> pMap) async {
    final rawNama = pMap['nama']?.toString().trim();
    if (rawNama == null || rawNama.isEmpty) return;
    if (FirebaseProductService.isDummyProduct(pMap)) return;

    double diskonVal = 0.0;
    final rawDiskon = pMap['diskon'] ?? pMap['discount'];
    if (rawDiskon is num) {
      diskonVal = rawDiskon.toDouble();
    } else if (rawDiskon is String) {
      diskonVal = double.tryParse(rawDiskon.replaceAll('%', '').trim()) ?? 0.0;
    }

    final row = {
      'nama': rawNama,
      'kategori': pMap['kategori'] ?? 'VPS',
      'harga': (pMap['harga'] as num?)?.toDouble() ?? 0.0,
      'stok': (pMap['stok'] as num?)?.toInt() ?? 0,
      'deskripsi': pMap['deskripsi']?.toString(),
      'diskon': diskonVal,
    };

    final docId = pMap['doc_id']?.toString() ?? '';
    final idVal = (pMap['id'] as num?)?.toInt();

    List<Map<String, dynamic>> existing = [];
    if (idVal != null && idVal > 0) {
      existing = await db.query('products', where: 'id = ?', whereArgs: [idVal], limit: 1);
    }
    if (existing.isEmpty && docId.isNotEmpty) {
      final match = RegExp(r'^prod_(\d{2})_').firstMatch(docId);
      if (match != null) {
        final orderNo = int.tryParse(match.group(1)!);
        if (orderNo != null && orderNo > 0) {
          existing = await db.query('products', where: 'id = ?', whereArgs: [orderNo], limit: 1);
        }
      }
    }
    if (existing.isEmpty) {
      existing = await db.query('products', where: 'LOWER(TRIM(nama)) = ?', whereArgs: [rawNama.toLowerCase()], limit: 1);
    }

    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      await db.update('products', row, where: 'id = ?', whereArgs: [id]);
      debugPrint('[RealtimeListener] 🔄 Produk "$rawNama" otomatis diperbarui permanen di SQLite.');
    } else {
      await db.insert('products', row);
      debugPrint('[RealtimeListener] ➕ Produk baru "$rawNama" otomatis ditambahkan permanen ke SQLite.');
    }
  }

  Future<void> _updateProductFieldInSqlite(dynamic db, String docKey, String field, dynamic value) async {
    final lowerField = field.toLowerCase();
    String sanitizedField = field;
    dynamic cleanVal = value;
    if (lowerField == 'harga' || lowerField == 'price') {
      sanitizedField = 'harga';
      cleanVal = (value as num?)?.toDouble() ?? 0.0;
    } else if (lowerField == 'diskon' || lowerField == 'discount') {
      sanitizedField = 'diskon';
      cleanVal = (value as num?)?.toDouble() ?? 0.0;
    } else if (lowerField == 'stok' || lowerField == 'stock') {
      sanitizedField = 'stok';
      cleanVal = (value as num?)?.toInt() ?? 0;
    } else if (lowerField == 'nama' || lowerField == 'name') {
      sanitizedField = 'nama';
      cleanVal = value?.toString();
    } else if (lowerField == 'kategori' || lowerField == 'category') {
      sanitizedField = 'kategori';
      cleanVal = value?.toString();
    } else if (lowerField == 'deskripsi' || lowerField == 'description') {
      sanitizedField = 'deskripsi';
      cleanVal = value?.toString();
    }

    final matchOrder = RegExp(r'^prod_(\d{2})_').firstMatch(docKey);
    final orderNo = matchOrder != null ? int.tryParse(matchOrder.group(1)!) : null;

    // Cari produk di SQLite yang cocok dengan docKey atau namanya
    final all = await db.query('products');
    for (final p in all) {
      final pNama = (p['nama'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[/\\#?\[\]\.\$\s]'), '_');
      final pId = p['id'].toString();
      final isMatch = (orderNo != null && p['id'] == orderNo) ||
          docKey.contains(pNama) ||
          pNama.contains(docKey) ||
          docKey == 'prod_$pId';

      if (isMatch) {
        final id = p['id'] as int;
        await db.update('products', {sanitizedField: cleanVal}, where: 'id = ?', whereArgs: [id]);
        debugPrint('[RealtimeListener] ⚡ Field "$sanitizedField" produk "${p['nama']}" diubah menjadi $cleanVal di SQLite.');
        break;
      }
    }
  }

  Future<void> _deleteProductFromSqlite(dynamic db, String docKey) async {
    final matchOrder = RegExp(r'^prod_(\d{2})_').firstMatch(docKey);
    final orderNo = matchOrder != null ? int.tryParse(matchOrder.group(1)!) : null;

    final all = await db.query('products');
    for (final p in all) {
      final pNama = (p['nama'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[/\\#?\[\]\.\$\s]'), '_');
      final pId = p['id'].toString();
      if ((orderNo != null && p['id'] == orderNo) || docKey.contains(pNama) || docKey == 'prod_$pId') {
        final id = p['id'] as int;
        await db.delete('products', where: 'id = ?', whereArgs: [id]);
        debugPrint('[RealtimeListener] 🗑️ Produk "${p['nama']}" dihapus dari SQLite karena dihapus di Firebase.');
        break;
      }
    }
  }

  // ===========================================================================
  // 2. SINKRONISASI REALTIME & PERMANEN PENGGUNA & SALDO (USERS & BALANCE)
  // ===========================================================================
  Future<void> _applyUsersUpdate(String path, dynamic data, String eventType) async {
    final db = await DatabaseHelper.instance.database;

    // A. Snapshot Seluruh Pengguna
    if (path == '/' && data is Map) {
      for (final entry in data.entries) {
        if (entry.value is Map) {
          final uMap = Map<String, dynamic>.from(entry.value as Map);
          uMap['doc_id'] = entry.key.toString();
          await _saveSingleUserToSqlite(db, uMap);
        }
      }
      debugPrint('[RealtimeListener] ✅ Sinkronisasi snapshot pengguna (${data.length} akun) ke SQLite berhasil.');
      return;
    }

    // B. Perubahan Pada Pengguna Spesifik
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final segments = cleanPath.split('/');
    final docKey = segments.first;

    if (segments.length == 1) {
      if (data == null) {
        // Hapus akun dari SQLite jika dihapus di Firebase
        await _deleteUserFromSqlite(db, docKey);
      } else if (data is Map) {
        final uMap = Map<String, dynamic>.from(data);
        uMap['doc_id'] = docKey;
        await _saveSingleUserToSqlite(db, uMap);
      }
    } else if (segments.length >= 2) {
      // Field spesifik diubah (misal: saldo, role, pin, password)
      final field = segments[1];
      await _updateUserFieldInSqlite(db, docKey, field, data);
    }
  }

  Future<void> _saveSingleUserToSqlite(dynamic db, Map<String, dynamic> uMap) async {
    if (FirebaseUserService.isDummyUser(uMap)) return;

    final email = uMap['email']?.toString().trim();
    final username = uMap['username']?.toString().trim();
    final uid = uMap['uid']?.toString().trim();
    if ((email == null || email.isEmpty) && (username == null || username.isEmpty)) return;

    Map<String, dynamic>? existingUser;
    if (uid != null && uid.isNotEmpty) {
      existingUser = await DatabaseHelper.instance.getUserByUid(uid);
    }
    if (existingUser == null && email != null && email.isNotEmpty) {
      existingUser = await DatabaseHelper.instance.getUserByEmailOrUsername(email);
    }
    if (existingUser == null && username != null && username.isNotEmpty) {
      existingUser = await DatabaseHelper.instance.getUserByEmailOrUsername(username);
    }

    if (existingUser != null) {
      final updateData = <String, dynamic>{};
      if (username != null && username.isNotEmpty) updateData['username'] = username;
      if (email != null && email.isNotEmpty) updateData['email'] = email;
      if (uMap['nama'] != null) updateData['nama'] = uMap['nama'];
      if (uMap['saldo'] != null) updateData['saldo'] = (uMap['saldo'] as num).toDouble();
      if (uMap['phone'] != null) updateData['phone'] = uMap['phone'];
      if (uMap['location'] != null) updateData['location'] = uMap['location'];
      if (uMap['avatarUrl'] != null) updateData['avatarUrl'] = uMap['avatarUrl'];
      if (uMap['pin'] != null) updateData['pin'] = uMap['pin'];
      if (uMap['role'] != null) updateData['role'] = uMap['role'];
      if (uMap['password'] != null) updateData['password'] = uMap['password'];
      if (uMap['is2FA'] != null) updateData['is2FA'] = (uMap['is2FA'] as num).toInt();
      if (uMap['language'] != null) updateData['language'] = uMap['language'];
      if (uMap['bio'] != null) updateData['bio'] = uMap['bio'];
      if (uMap['referralCode'] != null) updateData['referralCode'] = uMap['referralCode'];

      final int? existingId = (existingUser['id'] as num?)?.toInt();
      final existingUid = existingUser['uid']?.toString() ?? uid;
      if (existingId != null && existingId > 0) {
        await DatabaseHelper.instance.updateUserById(existingId, updateData, syncToCloud: false);
      } else if (existingUid != null && existingUid.isNotEmpty) {
        await DatabaseHelper.instance.updateUserByUid(existingUid, updateData, syncToCloud: false);
      }

      // Periksa apakah pengguna yang diedit adalah akun yang sedang aktif saat ini
      _syncActiveSessionIfMatched(email, username, updateData);
      debugPrint('[RealtimeListener] 👤 Akun "$username / $email" otomatis diperbarui permanen di SQLite.');
    } else {
      final insertData = <String, dynamic>{
        'uid': uid ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
        'nama': uMap['nama'] ?? username ?? 'User VibeTech',
        'username': username ?? (email != null ? email.split('@').first : 'user'),
        'email': email ?? '${username ?? 'user'}@vibetech.com',
        'phone': uMap['phone'] ?? '',
        'password': uMap['password'] ??
            SecurityHelper.hashPassword(
                'vbt_cloud_${DateTime.now().millisecondsSinceEpoch}'),
        'pin': uMap['pin'] != null
            ? SecurityHelper.hashPin(uMap['pin'].toString())
            : SecurityHelper.hashPin('123456'),
        'referralCode': uMap['referralCode'] ?? '',
        'role': uMap['role'] ?? 'user',
        'createdAt': uMap['createdAt'] ?? DateTime.now().toIso8601String(),
        'saldo': (uMap['saldo'] as num?)?.toDouble() ?? 0.0,
        'location': uMap['location'] ?? 'Indonesia',
        'avatarUrl': uMap['avatarUrl'] ?? 'https://cdn.nekohime.site/file/5232n74c.jpeg',
        'is2FA': (uMap['is2FA'] as num?)?.toInt() ?? 1,
        'language': uMap['language'] ?? 'Indonesia',
        'authProvider': uMap['authProvider'] ?? 'Cloud',
        'bio': uMap['bio'] ?? '',
      };
      await DatabaseHelper.instance.registerUser(insertData);
      debugPrint('[RealtimeListener] ➕ Akun baru "$username / $email" otomatis didaftarkan ke SQLite.');
    }
  }

  Future<void> _updateUserFieldInSqlite(dynamic db, String docKey, String field, dynamic value) async {
    final lowerField = field.toLowerCase();
    String sanitizedField = field;
    dynamic cleanVal = value;
    if (lowerField == 'saldo' || lowerField == 'balance') {
      sanitizedField = 'saldo';
      cleanVal = (value as num?)?.toDouble() ?? 0.0;
    } else if (lowerField == 'is2fa' || lowerField == 'is_2fa' || lowerField == 'is_2fa_enabled') {
      sanitizedField = 'is2FA';
      cleanVal = (value as num?)?.toInt() ?? 1;
    } else if (lowerField == 'avatarurl' || lowerField == 'avatar_url') {
      sanitizedField = 'avatarUrl';
      cleanVal = value?.toString();
    } else if (lowerField == 'authprovider' || lowerField == 'auth_provider') {
      sanitizedField = 'authProvider';
      cleanVal = value?.toString();
    } else if (lowerField == 'referralcode' || lowerField == 'referral_code') {
      sanitizedField = 'referralCode';
      cleanVal = value?.toString();
    } else if (lowerField == 'createdat' || lowerField == 'created_at') {
      sanitizedField = 'createdAt';
      cleanVal = value?.toString();
    } else if (lowerField == 'password') {
      sanitizedField = 'password';
      cleanVal = SecurityHelper.hashPassword(value.toString().trim());
    } else if (lowerField == 'pin') {
      sanitizedField = 'pin';
      cleanVal = SecurityHelper.hashPin(value.toString().trim());
    } else if (lowerField == 'role') {
      sanitizedField = 'role';
      cleanVal = value?.toString().trim();
    } else if (lowerField == 'nama' || lowerField == 'name') {
      sanitizedField = 'nama';
      cleanVal = value?.toString();
    } else if (lowerField == 'username') {
      sanitizedField = 'username';
      cleanVal = value?.toString().trim();
    } else if (lowerField == 'email') {
      sanitizedField = 'email';
      cleanVal = value?.toString().trim();
    } else if (lowerField == 'phone') {
      sanitizedField = 'phone';
      cleanVal = value?.toString().trim();
    } else if (lowerField == 'location') {
      sanitizedField = 'location';
      cleanVal = value?.toString();
    } else if (lowerField == 'language') {
      sanitizedField = 'language';
      cleanVal = value?.toString();
    } else if (lowerField == 'bio') {
      sanitizedField = 'bio';
      cleanVal = value?.toString();
    }

    final allUsers = await DatabaseHelper.instance.getAllUsers();
    bool matched = false;
    for (final u in allUsers) {
      final uMail = (u['email'] ?? '').toString().toLowerCase();
      final uName = (u['username'] ?? '').toString().toLowerCase();
      final uUid = (u['uid'] ?? '').toString().toLowerCase();
      final uDocId = (u['doc_id'] ?? '').toString().toLowerCase();
      final cleanKey = docKey.toLowerCase();
      final isMatch = (uDocId.isNotEmpty && cleanKey == uDocId) ||
          (uUid.isNotEmpty && cleanKey == uUid) ||
          cleanKey == 'usr_$uName' ||
          cleanKey.endsWith('_$uName') ||
          (uMail.isNotEmpty && (cleanKey == 'usr_${uMail.split('@').first}' || cleanKey.endsWith('_${uMail.split('@').first}')));

      if (isMatch) {
        matched = true;
        final uid = u['uid']?.toString() ?? '';
        final int? id = (u['id'] as num?)?.toInt();
        if (id != null && id > 0) {
          await DatabaseHelper.instance.updateUserById(id, {sanitizedField: cleanVal}, syncToCloud: false);
        } else if (uid.isNotEmpty) {
          await DatabaseHelper.instance.updateUserByUid(uid, {sanitizedField: cleanVal}, syncToCloud: false);
        }
        _syncActiveSessionIfMatched(uMail, uName, {sanitizedField: cleanVal});
        debugPrint('[RealtimeListener] ⚡ Akun "$uName": Field "$sanitizedField" diubah jadi $cleanVal di SQLite.');
        break;
      }
    }

    // Fallback jika belum cocok (misal docKey format Google OAuth seperti goog_1788759770304)
    if (!matched) {
      try {
        final uri = await FirebaseUserService.buildRtdbUri('$docKey.json');
        final res = await http.get(uri).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
          final dynamic userObj = jsonDecode(res.body);
          if (userObj is Map) {
            final fullMap = Map<String, dynamic>.from(userObj);
            fullMap['doc_id'] = docKey;
            await _saveSingleUserToSqlite(db, fullMap);
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _deleteUserFromSqlite(dynamic db, String docKey) async {
    final cleanKey = docKey.toLowerCase();
    final allUsers = await DatabaseHelper.instance.getAllUsers();
    for (final u in allUsers) {
      final uName = (u['username'] ?? '').toString().toLowerCase();
      final uMail = (u['email'] ?? '').toString().toLowerCase();
      final uUid = (u['uid'] ?? '').toString().toLowerCase();
      final uRole = (u['role'] ?? 'user').toString().toLowerCase();
      if (uRole == 'admin' || uRole == 'administrator') continue;

      final isMatch = cleanKey == uUid ||
          cleanKey == 'usr_$uName' ||
          cleanKey.endsWith('_$uName') ||
          (uMail.isNotEmpty && (cleanKey == 'usr_${uMail.split('@').first}' || cleanKey.endsWith('_${uMail.split('@').first}')));

      if (isMatch) {
        final id = u['id'] as int;
        await db.delete('users', where: 'id = ?', whereArgs: [id]);
        debugPrint('[RealtimeListener] 🗑️ User "$uName" ($uUid) dihapus dari SQLite karena dihapus di Firebase.');
        break;
      }
    }
  }

  /// Memperbarui session aktif jika akun yang diedit adalah akun yang sedang login di perangkat ini
  Future<void> _syncActiveSessionIfMatched(String? email, String? username, Map<String, dynamic> changes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentEmail = (prefs.getString('email') ?? '').toLowerCase();
      final currentUsername = (prefs.getString('username') ?? '').toLowerCase();

      final isCurrent = (email != null && email.toLowerCase() == currentEmail) ||
          (username != null && username.toLowerCase() == currentUsername) ||
          (email != null && email.toLowerCase() == BalanceService.activeUser.toLowerCase());

      if (isCurrent) {
        if (changes.containsKey('saldo')) {
          final newSaldo = (changes['saldo'] as num).toInt();
          BalanceService.notifier.value = newSaldo;
          await prefs.setInt('user_balance_$currentEmail', newSaldo);
          debugPrint('[RealtimeListener] 💰 Saldo pengguna aktif otomatis diselaraskan ke Rp $newSaldo!');
        }
        if (changes.containsKey('role')) {
          await prefs.setString('role', changes['role'].toString());
        }
        if (changes.containsKey('nama')) {
          await prefs.setString('nama', changes['nama'].toString());
        }
        if (changes.containsKey('avatarUrl')) {
          await prefs.setString('avatarUrl', changes['avatarUrl'].toString());
        }
      }
    } catch (_) {}
  }

  // ===========================================================================
  // 3. SINKRONISASI REALTIME & PERMANEN TRANSAKSI (TRANSACTIONS)
  // ===========================================================================
  Future<void> _applyTransactionsUpdate(String path, dynamic data, String eventType) async {
    final db = await DatabaseHelper.instance.database;

    // A. Snapshot Seluruh Transaksi
    if (path == '/' && data is Map) {
      for (final entry in data.entries) {
        if (entry.value is Map) {
          final txMap = Map<String, dynamic>.from(entry.value as Map);
          txMap['invoice_no'] = txMap['invoice_no'] ?? entry.key.toString();
          await _saveSingleTransactionToSqlite(db, txMap);
        }
      }
      debugPrint('[RealtimeListener] ✅ Sinkronisasi snapshot transaksi (${data.length} item) ke SQLite berhasil.');
      return;
    }

    // B. Perubahan Pada Transaksi Spesifik
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final segments = cleanPath.split('/');
    final invoiceKey = segments.first;

    if (segments.length == 1) {
      if (data == null) {
        // Hapus transaksi jika dihapus di Firebase
        await db.delete('transactions', where: 'invoice_no = ?', whereArgs: [invoiceKey]);
        debugPrint('[RealtimeListener] 🗑️ Transaksi "$invoiceKey" dihapus dari SQLite karena dihapus di Firebase.');
      } else if (data is Map) {
        final txMap = Map<String, dynamic>.from(data);
        txMap['invoice_no'] = txMap['invoice_no'] ?? invoiceKey;
        await _saveSingleTransactionToSqlite(db, txMap);
      }
    } else if (segments.length >= 2) {
      final rawField = segments[1];
      final lowerField = rawField.toLowerCase();
      String field = rawField;
      dynamic cleanData = data;
      if (lowerField == 'total_amount' || lowerField == 'total' || lowerField == 'total_harga') {
        field = 'total_harga';
        cleanData = (data as num?)?.toDouble() ?? 0.0;
      } else if (lowerField == 'product_name' || lowerField == 'nama_produk') {
        field = 'nama_produk';
        cleanData = data?.toString();
      } else if (lowerField == 'email' || lowerField == 'user_email') {
        field = 'user_email';
        cleanData = data?.toString().trim();
      } else if (lowerField == 'qty' || lowerField == 'quantity' || lowerField == 'jumlah') {
        field = 'jumlah';
        cleanData = (data as num?)?.toInt() ?? 1;
      } else if (lowerField == 'status') {
        field = 'status';
        cleanData = data?.toString();
      } else if (lowerField == 'metode_pembayaran' || lowerField == 'payment_method') {
        field = 'payment_method';
        cleanData = data?.toString();
      }

      final targetInv = invoiceKey.replaceAll('_', '-');
      await db.update(
        'transactions',
        {field: cleanData},
        where: 'invoice_no = ? OR invoice_no = ?',
        whereArgs: [invoiceKey, targetInv],
      );
      debugPrint('[RealtimeListener] ⚡ Transaksi "$invoiceKey": Field "$field" diubah jadi $cleanData di SQLite.');

      if (field.toLowerCase() == 'status') {
        final txRows = await db.query(
          'transactions',
          where: 'invoice_no = ? OR invoice_no = ?',
          whereArgs: [invoiceKey, targetInv],
          limit: 1,
        );
        if (txRows.isNotEmpty) {
          await _checkAndAutoProvisionService(db, txRows.first);
        }
      }
    }
  }

  Future<void> _saveSingleTransactionToSqlite(dynamic db, Map<String, dynamic> txMap) async {
    final invoice = (txMap['invoice_no'] ?? txMap['invoice_number'])?.toString();
    if (invoice == null || invoice.isEmpty) return;

    final num? rawTotal = (txMap['total_harga'] ?? txMap['total_amount']) as num?;
    final row = {
      'invoice_no': invoice,
      'user_email': txMap['user_email']?.toString() ?? 'user@vibetech.com',
      'nama_produk': txMap['nama_produk']?.toString() ?? 'Layanan Cloud',
      'jumlah': (txMap['jumlah'] as num?)?.toInt() ?? 1,
      'total_harga': rawTotal?.toDouble() ?? 0.0,
      'tanggal': txMap['tanggal']?.toString() ?? txMap['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'status': txMap['status']?.toString() ?? 'Selesai',
      'payment_method': txMap['payment_method']?.toString() ?? txMap['metode_pembayaran']?.toString(),
      'notes': txMap['notes']?.toString(),
    };

    final existing = await db.query(
      'transactions',
      where: 'invoice_no = ?',
      whereArgs: [invoice],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      await db.update('transactions', row, where: 'id = ?', whereArgs: [id]);
      debugPrint('[RealtimeListener] 🔄 Transaksi "$invoice" diperbarui permanen di SQLite.');
    } else {
      await db.insert('transactions', row);
      debugPrint('[RealtimeListener] ➕ Transaksi "$invoice" ditambahkan permanen ke SQLite.');
    }

    // Otomatis aktifkan layanan jika transaksi lunas / selesai
    await _checkAndAutoProvisionService(db, row);
  }

  /// Memeriksa dan mengaktifkan data layanan di SQLite jika transaksi dinyatakan selesai/lunas
  Future<void> _checkAndAutoProvisionService(dynamic db, Map<String, dynamic> txRow) async {
    try {
      final status = (txRow['status'] ?? '').toString().toLowerCase();
      if (!status.contains('selesai') && !status.contains('lunas') && !status.contains('success')) {
        return;
      }
      final email = (txRow['user_email'] ?? '').toString().trim().toLowerCase();
      final namaProduk = (txRow['nama_produk'] ?? '').toString().trim();
      if (email.isEmpty || namaProduk.isEmpty || email.contains('test_') || email.contains('dummy')) {
        return;
      }

      final existing = await db.query(
        'purchased_services',
        where: 'LOWER(user_email) = ? AND LOWER(nama_produk) = ?',
        whereArgs: [email, namaProduk.toLowerCase()],
        limit: 1,
      );

      if (existing.isEmpty) {
        String kategori = 'VPS';
        final lowerName = namaProduk.toLowerCase();
        if (lowerName.contains('panel') || lowerName.contains('pterodactyl') || lowerName.contains('hosting')) {
          kategori = 'Panel Hosting';
        } else if (lowerName.contains('bot') || lowerName.contains('whatsapp') || lowerName.contains('wa')) {
          kategori = 'Bot WhatsApp';
        }

        final now = DateTime.now();
        final kadaluarsa = now.add(const Duration(days: 30)).toIso8601String();

        final srvRow = {
          'user_email': email,
          'nama_produk': namaProduk,
          'kategori': kategori,
          'harga': (txRow['total_harga'] as num?)?.toDouble() ?? 0.0,
          'tanggal_beli': txRow['tanggal']?.toString() ?? now.toIso8601String(),
          'tanggal_kadaluarsa': kadaluarsa,
          'status': 'Aktif',
          'spesifikasi': 'Layanan Cloud Otomatis VibeTech',
        };

        final newId = await db.insert('purchased_services', srvRow);
        try {
          final syncData = Map<String, dynamic>.from(srvRow);
          syncData['id'] = newId;
          FirebaseTransactionService.instance
              .saveServiceToFirebase(syncData)
              .catchError((_) => null);
        } catch (_) {}
        servicesUpdateCount.value++;
        debugPrint('[RealtimeListener] 🚀 Layanan "$namaProduk" otomatis dibuat untuk $email karena transaksi Selesai.');
      }
    } catch (e) {
      debugPrint('[RealtimeListener] Auto-provision service error: $e');
    }
  }

  // ===========================================================================
  // 4. SINKRONISASI REALTIME & PERMANEN LAYANAN AKTIF (PURCHASED SERVICES)
  // ===========================================================================
  Future<void> _applyServicesUpdate(String path, dynamic data, String eventType) async {
    final db = await DatabaseHelper.instance.database;

    // A. Snapshot Seluruh Layanan
    if (path == '/' && data is Map) {
      for (final entry in data.entries) {
        if (entry.value is Map) {
          final sMap = Map<String, dynamic>.from(entry.value as Map);
          sMap['doc_id'] = entry.key.toString();
          await _saveSingleServiceToSqlite(db, sMap);
        }
      }
      debugPrint('[RealtimeListener] ✅ Sinkronisasi snapshot layanan (${data.length} item) ke SQLite berhasil.');
      return;
    }

    // B. Perubahan Pada Layanan Spesifik
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final segments = cleanPath.split('/');
    final srvKey = segments.first;

    if (segments.length == 1) {
      if (data == null) {
        await _deleteServiceFromSqlite(db, srvKey);
      } else if (data is Map) {
        final sMap = Map<String, dynamic>.from(data);
        sMap['doc_id'] = srvKey;
        await _saveSingleServiceToSqlite(db, sMap);
      }
    } else if (segments.length >= 2) {
      final field = segments[1];
      await _updateServiceFieldInSqlite(db, srvKey, field, data);
    }
  }

  Future<void> _saveSingleServiceToSqlite(dynamic db, Map<String, dynamic> sMap) async {
    final email = (sMap['user_email'] ?? '').toString().trim().toLowerCase();
    final namaProduk = (sMap['nama_produk'] ?? 'Cloud Service').toString().trim();
    if (email.isEmpty || namaProduk.isEmpty) return;

    final row = {
      'user_email': email,
      'nama_produk': namaProduk,
      'kategori': sMap['kategori']?.toString() ?? 'VPS',
      'harga': (sMap['harga'] as num?)?.toDouble() ?? 0.0,
      'tanggal_beli': sMap['tanggal_beli']?.toString() ?? DateTime.now().toIso8601String(),
      'tanggal_kadaluarsa': sMap['tanggal_kadaluarsa']?.toString() ?? '',
      'status': sMap['status']?.toString() ?? 'Aktif',
      'ip_address': sMap['ip_address']?.toString(),
      'port': sMap['port']?.toString(),
      'username': sMap['username_srv']?.toString() ?? sMap['username']?.toString(),
      'password': sMap['password_srv']?.toString() ?? sMap['password']?.toString(),
      'server_url': sMap['server_url']?.toString(),
      'session_id': sMap['session_id']?.toString(),
      'spesifikasi': sMap['spesifikasi']?.toString(),
      'extra_data': sMap['extra_data']?.toString(),
    };

    final existing = await db.query(
      'purchased_services',
      where: 'LOWER(user_email) = ? AND LOWER(nama_produk) = ?',
      whereArgs: [email, namaProduk.toLowerCase()],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      await db.update('purchased_services', row, where: 'id = ?', whereArgs: [id]);
      debugPrint('[RealtimeListener] 🔄 Layanan "$namaProduk" ($email) diperbarui permanen di SQLite.');
    } else {
      await db.insert('purchased_services', row);
      debugPrint('[RealtimeListener] ➕ Layanan "$namaProduk" ($email) ditambahkan permanen ke SQLite.');
    }
  }

  Future<void> _updateServiceFieldInSqlite(dynamic db, String srvKey, String field, dynamic value) async {
    final lowerField = field.toLowerCase();
    String sanitizedField = field;
    dynamic cleanVal = value;
    if (lowerField == 'username_srv' || lowerField == 'user_srv') {
      sanitizedField = 'username';
      cleanVal = value?.toString();
    } else if (lowerField == 'password_srv' || lowerField == 'pass_srv') {
      sanitizedField = 'password';
      cleanVal = value?.toString();
    } else if (lowerField == 'expiry_date' || lowerField == 'kadaluarsa' || lowerField == 'expired_at') {
      sanitizedField = 'tanggal_kadaluarsa';
      cleanVal = value?.toString();
    } else if (lowerField == 'ip') {
      sanitizedField = 'ip_address';
      cleanVal = value?.toString();
    } else if (lowerField == 'price') {
      sanitizedField = 'harga';
      cleanVal = (value as num?)?.toDouble() ?? 0.0;
    } else if (lowerField == 'category') {
      sanitizedField = 'kategori';
      cleanVal = value?.toString();
    }

    final all = await db.query('purchased_services');
    for (final s in all) {
      final sMail = (s['user_email'] ?? '').toString().toLowerCase();
      final sName = (s['nama_produk'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[/\\#?\[\]\.\$\s]'), '_');
      final sId = s['id'].toString();
      if (srvKey.toLowerCase().contains(sName) ||
          srvKey == 'srv_$sId' ||
          (sMail.isNotEmpty && srvKey.toLowerCase().contains(sMail.split('@').first))) {
        final id = s['id'] as int;
        await db.update('purchased_services', {sanitizedField: cleanVal}, where: 'id = ?', whereArgs: [id]);
        debugPrint('[RealtimeListener] ⚡ Layanan #$id: Field "$sanitizedField" diubah jadi $cleanVal di SQLite.');
        break;
      }
    }
  }

  Future<void> _deleteServiceFromSqlite(dynamic db, String srvKey) async {
    final all = await db.query('purchased_services');
    for (final s in all) {
      final sMail = (s['user_email'] ?? '').toString().toLowerCase();
      final sName = (s['nama_produk'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[/\\#?\[\]\.\$\s]'), '_');
      final sId = s['id'].toString();
      if (srvKey.toLowerCase().contains(sName) ||
          srvKey == 'srv_$sId' ||
          (sMail.isNotEmpty && srvKey.toLowerCase().contains(sMail.split('@').first))) {
        final id = s['id'] as int;
        await db.delete('purchased_services', where: 'id = ?', whereArgs: [id]);
        debugPrint('[RealtimeListener] 🗑️ Layanan #$id (${s['nama_produk']}) dihapus dari SQLite.');
        break;
      }
    }
  }

  // ===========================================================================
  // 5. SINKRONISASI REALTIME & PERMANEN KONFIGURASI EMAIL (SMTP CONFIGURATION)
  // ===========================================================================
  Future<void> _applyEmailSettingsUpdate(String path, dynamic data, String eventType) async {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final segments = cleanPath.split('/');

    Map<String, dynamic>? configMap;
    if (path == '/' && data is Map) {
      if (data.containsKey('global_config') && data['global_config'] is Map) {
        configMap = Map<String, dynamic>.from(data['global_config'] as Map);
      } else if (data.isNotEmpty && data.values.first is Map) {
        configMap = Map<String, dynamic>.from(data.values.first as Map);
      } else {
        configMap = Map<String, dynamic>.from(data);
      }
    } else if (segments.length == 1) {
      if (data is Map) {
        configMap = Map<String, dynamic>.from(data);
      }
    } else if (segments.length >= 2) {
      final field = segments[1];
      final prefs = await SharedPreferences.getInstance();
      if (field == 'smtp_user' || field == 'user') {
        await prefs.setString('smtp_user', data.toString().trim());
      } else if (field == 'smtp_pass' || field == 'pass') {
        await prefs.setString('smtp_pass', data.toString().replaceAll(' ', '').trim());
      } else if (field == 'smtp_host' || field == 'host') {
        await prefs.setString('smtp_host', data.toString().trim());
      } else if (field == 'smtp_port' || field == 'port') {
        await prefs.setInt('smtp_port', (data as num).toInt());
      }
      final curSettings = await DatabaseHelper.instance.getEmailSettings();
      final curUser = (curSettings?['smtp_user'] ?? '').toString();
      final curPass = (curSettings?['smtp_pass'] ?? '').toString();
      final curHost = (curSettings?['smtp_host'] ?? 'smtp.gmail.com').toString();
      final curPort = (curSettings?['smtp_port'] as num?)?.toInt() ?? 465;

      final newUser = (field == 'smtp_user' || field == 'user') ? data.toString().trim() : curUser;
      final newPass = (field == 'smtp_pass' || field == 'pass') ? data.toString().replaceAll(' ', '').trim() : curPass;
      final newHost = (field == 'smtp_host' || field == 'host') ? data.toString().trim() : curHost;
      final newPort = (field == 'smtp_port' || field == 'port') ? (data as num).toInt() : curPort;

      if (newUser.isNotEmpty && newPass.isNotEmpty) {
        await DatabaseHelper.instance.saveEmailSettings(
          smtpUser: newUser,
          smtpPass: newPass,
          smtpHost: newHost,
          smtpPort: newPort,
          syncToCloud: false,
        );
      }
      debugPrint('[RealtimeListener] 📧 SMTP Setting "$field" diubah jadi $data di SQLite & runtime.');
      return;
    }

    if (configMap != null) {
      final user = (configMap['smtp_user'] ?? configMap['user'] ?? '').toString().trim();
      final pass = (configMap['smtp_pass'] ?? configMap['pass'] ?? '').toString().replaceAll(' ', '').trim();
      final host = (configMap['smtp_host'] ?? configMap['host'] ?? 'smtp.gmail.com').toString().trim();
      final port = (configMap['smtp_port'] ?? configMap['port'] as num?)?.toInt() ?? 465;

      if (user.isNotEmpty && pass.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('smtp_user', user);
        await prefs.setString('smtp_pass', pass);
        await prefs.setString('smtp_host', host);
        await prefs.setInt('smtp_port', port);
        await prefs.setBool('smtp_is_active', true);

        await DatabaseHelper.instance.saveEmailSettings(
          smtpUser: user,
          smtpPass: pass,
          smtpHost: host,
          smtpPort: port,
          syncToCloud: false,
        );
        debugPrint('[RealtimeListener] ✅ Konfigurasi SMTP diperbarui permanen dari RTDB ke SQLite & SharedPreferences.');
      }
    }
  }

  // ===========================================================================
  // 6. SINKRONISASI REALTIME & PERMANEN DISKON PROMO KATEGORI (PROMO DISCOUNTS)
  // ===========================================================================
  Future<void> _applyPromoDiscountsUpdate(String path, dynamic data, String eventType) async {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final segments = cleanPath.split('/');
    final db = await DatabaseHelper.instance.database;

    if (path == '/' && data is Map) {
      for (final entry in data.entries) {
        if (entry.value is Map) {
          final cat = (entry.value['category'] ?? entry.key).toString();
          final disc = (entry.value['discount_percent'] as num?)?.toDouble() ?? 0.0;
          await db.update(
            'products',
            {'diskon': disc},
            where: 'kategori LIKE ?',
            whereArgs: ['%$cat%'],
          );
        }
      }
      return;
    }

    if (segments.length == 1) {
      final categoryKey = segments.first.replaceAll('_', ' ');
      if (data == null) {
        await db.update(
          'products',
          {'diskon': 0.0},
          where: 'kategori LIKE ?',
          whereArgs: ['%$categoryKey%'],
        );
      } else if (data is Map) {
        final disc = (data['discount_percent'] as num?)?.toDouble() ?? 0.0;
        await db.update(
          'products',
          {'diskon': disc},
          where: 'kategori LIKE ?',
          whereArgs: ['%$categoryKey%'],
        );
      }
    } else if (segments.length >= 2) {
      final categoryKey = segments.first.replaceAll('_', ' ');
      final field = segments[1];
      if (field == 'discount_percent' || field == 'diskon') {
        final disc = (data as num?)?.toDouble() ?? 0.0;
        await db.update(
          'products',
          {'diskon': disc},
          where: 'kategori LIKE ?',
          whereArgs: ['%$categoryKey%'],
        );
      }
    }
  }
}
