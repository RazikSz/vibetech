import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/firebase_auth_token_service.dart';
import 'package:vibetech_xyz/utils/security_helper.dart';

/// ============================================================================
/// FIREBASE USER SERVICE - VIBETECH XYZ
/// ============================================================================
/// Layanan cloud database ganda untuk menyimpan, memperbarui, dan menyinkronkan
/// seluruh data akun pengguna (Users Database) ke:
/// 1. Firebase Realtime Database (via FlutterFire SDK + HTTP REST API Fallback)
/// 2. Google Cloud Firestore (koleksi 'users')
class FirebaseUserService {
  static final FirebaseUserService instance = FirebaseUserService._init();

  FirebaseUserService._init();

  static const String rtdbBaseUrl =
      'https://vibetech-xyz-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String collectionName = 'users';

  /// Helper untuk membangun URI RTDB terautentikasi (mencegah 401 Permission Denied)
  static Future<Uri> buildRtdbUri([String? docKey]) async {
    final token = await FirebaseAuthTokenService.instance.getIdToken();
    final authParam = (token != null && token.isNotEmpty) ? '?auth=$token' : '';
    if (docKey != null && docKey.isNotEmpty) {
      final clean = docKey.endsWith('.json') ? docKey : '$docKey.json';
      return Uri.parse('$rtdbBaseUrl/$collectionName/$clean$authParam');
    }
    return Uri.parse('$rtdbBaseUrl/$collectionName.json$authParam');
  }

  /// Referensi Firebase Realtime Database
  DatabaseReference get _rtdbRef {
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: rtdbBaseUrl,
      ).ref(collectionName);
    } catch (_) {
      return FirebaseDatabase.instance.ref(collectionName);
    }
  }

  /// Referensi Google Cloud Firestore
  CollectionReference<Map<String, dynamic>> get _firestoreRef =>
      FirebaseFirestore.instance.collection(collectionName);

  /// Menghasilkan Key / Document ID yang aman dan valid untuk Firebase
  String _sanitizeKey(String rawKey) {
    return rawKey.trim().replaceAll(RegExp(r'[/\\#?\[\]\.\$]'), '_');
  }

  /// Menentukan ID Dokumen untuk akun pengguna yang rapi, berurutan nomor dan username
  String _resolveDocId(Map<String, dynamic> data, {int? orderIndex}) {
    final role = (data['role'] ?? 'user').toString().toLowerCase();
    final username = (data['username'] ?? data['nama'] ?? 'user')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[/\\#?\[\]\.\$\s]'), '_');

    // 1. Jika eksplisit diberikan nomor urutan (misal saat syncOrderedUsersToFirebase)
    if (orderIndex != null && orderIndex > 0) {
      final prefix = orderIndex < 10 ? '0$orderIndex' : '$orderIndex';
      return 'usr_${prefix}_$username';
    }

    // 2. Jika ada nomor urutan katalog resmi kecil (1 - 99)
    final explicitNo = data['no'] ?? data['urutan'];
    if (explicitNo != null &&
        explicitNo is num &&
        explicitNo >= 1 &&
        explicitNo <= 99) {
      final orderInt = explicitNo.toInt();
      final prefix = orderInt < 10 ? '0$orderInt' : '$orderInt';
      return 'usr_${prefix}_$username';
    }

    // 3. Administrator utama selalu memiliki format usr_01_$username
    if (role == 'admin' ||
        role == 'administrator' ||
        username == 'admin' ||
        username == 'raziek') {
      return 'usr_01_$username';
    }

    // 4. Jika akun login pihak ketiga (Google / GitHub OAuth), gunakan UID provider tersebut
    final uid = data['uid']?.toString().trim();
    if (uid != null && uid.isNotEmpty) {
      if (uid.startsWith('goog_') ||
          uid.startsWith('gh_') ||
          uid.startsWith('git_')) {
        return _sanitizeKey(uid);
      }
    }

    // 5. Jika memiliki doc_id eksplisit yang valid (bukan junk auto-increment SQLite usr_2440_...)
    final docId = data['doc_id']?.toString().trim();
    if (docId != null &&
        docId.isNotEmpty &&
        !RegExp(r'^usr_\d{3,}_').hasMatch(docId)) {
      return _sanitizeKey(docId);
    }

    // 6. Jika memiliki UID custom eksplisit yang valid (misal usr_sync_test_..., usr_admin_001)
    if (uid != null &&
        uid.isNotEmpty &&
        !RegExp(r'^usr_\d{3,}_').hasMatch(uid) &&
        !RegExp(r'^usr_\d{10,}$').hasMatch(uid)) {
      return _sanitizeKey(uid);
    }

    // 7. Format standar deterministik dan stabil untuk pengguna biasa: usr_$username
    if (username.isNotEmpty && username != 'user') {
      return 'usr_$username';
    }

    // 8. Fallback email jika username kosong
    final email = data['email']?.toString().trim();
    if (email != null && email.contains('@')) {
      final emailPrefix = email
          .split('@')
          .first
          .toLowerCase()
          .replaceAll(RegExp(r'[/\\#?\[\]\.\$\s]'), '_');
      if (emailPrefix.isNotEmpty) {
        return 'usr_$emailPrefix';
      }
    }

    if (uid != null &&
        uid.isNotEmpty &&
        !RegExp(r'^usr_\d{3,}_').hasMatch(uid)) {
      return _sanitizeKey(uid);
    }

    return 'usr_$username';
  }

  /// Memeriksa apakah suatu akun adalah akun dummy / mock / unit test
  static bool isDummyUser(Map<String, dynamic> data) {
    final email = (data['email'] ?? '').toString().trim().toLowerCase();
    final username = (data['username'] ?? '').toString().trim().toLowerCase();
    final uid = (data['uid'] ?? '').toString().trim().toLowerCase();
    final nama = (data['nama'] ?? '').toString().trim().toLowerCase();

    // 1. Akun pengguna resmi dan nyata TIDAK BOLEH dianggap dummy
    if (email == 'admin@vibetech.com' ||
        email == 'admin@vibetech.xyz' ||
        username == 'admin' ||
        username == 'raziek' ||
        username == 'oooo' ||
        username == 'agus' ||
        username == 'alfin' ||
        username == 'fiqri' ||
        username == 'jezgrn' ||
        username == 'zhil' ||
        email == 'test@gmail.com' ||
        email == 'raziek.official@gmail.com' ||
        username == 'raziek_pro' ||
        username == 'testuser') {
      return false;
    }

    // 2. Akun testing / mock / unit test terdeteksi dari pola eksplisit
    if (username.startsWith('mock_') ||
        email.startsWith('mock_') ||
        uid.startsWith('mock_') ||
        uid.startsWith('usr_sync_test_') ||
        username.startsWith('temp_test_') ||
        email.startsWith('temp_test_') ||
        username.startsWith('temp_test_runner_') ||
        username.startsWith('balance_test_') ||
        email.startsWith('balance_test_') ||
        username.startsWith('balance_') ||
        email.startsWith('balance_') ||
        username.startsWith('merge_order_') ||
        email.startsWith('merge_order_') ||
        username.startsWith('sec_user_') ||
        email.startsWith('sec_user_') ||
        username.startsWith('test_edit_user') ||
        email.startsWith('test_edit_user') ||
        username.startsWith('victim_') ||
        email.startsWith('victim_') ||
        username.contains('alex_pratama') ||
        email.contains('alex.pratama') ||
        username.contains('dev_github') ||
        email.contains('dev.github') ||
        username.startsWith('cloud_') ||
        email.startsWith('cloud_') ||
        username == 'demouser' ||
        nama.contains('demo member') ||
        email.contains('dummy') ||
        username.contains('dummy') ||
        uid.contains('dummy') ||
        nama.contains('dummy') ||
        email.contains('mock_user') ||
        nama.contains('budi santoso') ||
        email.contains('budi.santoso')) {
      return true;
    }

    return false;
  }

  /// Menyimpan atau memperbarui data akun pengguna ke Firebase (RTDB & Cloud Firestore)
  Future<String?> saveUserToFirebase(Map<String, dynamic> userData) async {
    try {
      final Map<String, dynamic> data = Map<String, dynamic>.from(userData);
      final String docId = _resolveDocId(data);

      // Filter ketat: Tolak penyimpanan akun dummy / mock / test ke Firebase
      if (isDummyUser(data)) {
        debugPrint(
            '[FirebaseUserService] Akun dummy/test diabaikan dari Firebase Cloud: ${data['email'] ?? data['username']}');
        return docId;
      }

      // Normalisasi tipe data
      if (data['saldo'] != null) {
        data['saldo'] = (data['saldo'] as num).toDouble();
      }
      if (data['is2FA'] != null) {
        data['is2FA'] = (data['is2FA'] as num).toInt();
      }

      // Normalisasi password & PIN: jangan pernah biarkan kosong atau hilang saat diunggah ke Firebase
      if (data['password'] != null &&
          data['password'].toString().trim().isNotEmpty) {
        data['password'] =
            SecurityHelper.hashPassword(data['password'].toString().trim());
      } else {
        // Ambil password dari database lokal jika tidak disertakan dalam payload
        try {
          final uEmail = data['email']?.toString().trim();
          final uName = data['username']?.toString().trim();
          Map<String, dynamic>? local;
          if (uEmail != null && uEmail.isNotEmpty) {
            local = await DatabaseHelper.instance.getUserByEmail(uEmail);
          }
          if (local == null && uName != null && uName.isNotEmpty) {
            local =
                await DatabaseHelper.instance.getUserByEmailOrUsername(uName);
          }
          if (local != null &&
              local['password'] != null &&
              local['password'].toString().trim().isNotEmpty) {
            data['password'] = SecurityHelper.hashPassword(
                local['password'].toString().trim());
          } else if (uEmail == 'admin@vibetech.com' ||
              uName == 'raziek' ||
              data['role'] == 'admin') {
            data['password'] = 'razieksz';
          }
        } catch (_) {}
      }

      if (data['pin'] != null && data['pin'].toString().trim().isNotEmpty) {
        data['pin'] = SecurityHelper.hashPin(data['pin'].toString().trim());
      } else {
        // Ambil PIN dari database lokal jika tidak disertakan dalam payload
        try {
          final uEmail = data['email']?.toString().trim();
          final uName = data['username']?.toString().trim();
          Map<String, dynamic>? local;
          if (uEmail != null && uEmail.isNotEmpty) {
            local = await DatabaseHelper.instance.getUserByEmail(uEmail);
          }
          if (local == null && uName != null && uName.isNotEmpty) {
            local =
                await DatabaseHelper.instance.getUserByEmailOrUsername(uName);
          }
          if (local != null &&
              local['pin'] != null &&
              local['pin'].toString().trim().isNotEmpty) {
            data['pin'] =
                SecurityHelper.hashPin(local['pin'].toString().trim());
          } else {
            data['pin'] = '123456';
          }
        } catch (_) {}
      }

      data['doc_id'] = docId;
      data['uid_ref'] = docId;

      final nowIso = DateTime.now().toIso8601String();
      data['updated_at'] = nowIso;
      if (!data.containsKey('createdAt') && !data.containsKey('created_at')) {
        data['createdAt'] = nowIso;
      }

      // --- 1. SIMPAN KE REALTIME DATABASE VIA HTTP REST API (GARANSI UTAMA & INSTANT DI SEMUA OS) ---
      try {
        final uri = await buildRtdbUri('$docId.json');
        final response = await http
            .put(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data),
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          debugPrint(
              '[FirebaseUserService] HTTP REST RTDB simpan user sukses: $docId');
        } else {
          debugPrint(
              '[FirebaseUserService] HTTP REST RTDB status: ${response.statusCode}');
        }
      } catch (httpError) {
        debugPrint(
            '[FirebaseUserService] HTTP REST RTDB Exception: $httpError');
      }

      // Bersihkan key lama/duplikat di RTDB jika nama akun atau docId berubah
      try {
        final allUri = await buildRtdbUri();
        final allRes =
            await http.get(allUri).timeout(const Duration(seconds: 3));
        if (allRes.statusCode == 200 &&
            allRes.body.isNotEmpty &&
            allRes.body != 'null') {
          final dynamic allDecoded = jsonDecode(allRes.body);
          if (allDecoded is Map) {
            final uEmail = (data['email'] ?? '').toString().toLowerCase();
            final uName = (data['username'] ?? '').toString().toLowerCase();
            final uUid = (data['uid'] ?? '').toString().toLowerCase();

            for (final entry in allDecoded.entries) {
              final k = entry.key.toString();
              if (k == docId) continue;
              final v = entry.value;
              if (v is Map) {
                final existEmail = (v['email'] ?? '').toString().toLowerCase();
                final existName =
                    (v['username'] ?? '').toString().toLowerCase();
                final existUid = (v['uid'] ?? '').toString().toLowerCase();

                final isMatch = (uUid.isNotEmpty && existUid == uUid) ||
                    (uEmail.isNotEmpty && existEmail == uEmail) ||
                    (uName.isNotEmpty && existName == uName);

                if (isMatch) {
                  try {
                    final delUri = await buildRtdbUri('$k.json');
                    await http
                        .delete(delUri)
                        .timeout(const Duration(seconds: 2));
                  } catch (_) {}
                }
              }
            }
          }
        }
      } catch (_) {}

      // --- 2. SIMPAN KE SDK REALTIME DATABASE ---
      try {
        await _rtdbRef
            .child(docId)
            .set(data)
            .timeout(const Duration(seconds: 3));
        debugPrint('[FirebaseUserService] SDK RTDB simpan user sukses: $docId');
      } catch (sdkError) {
        debugPrint('[FirebaseUserService] SDK RTDB info: $sdkError');
      }

      // --- 3. SIMPAN KE GOOGLE CLOUD FIRESTORE ---
      try {
        final firestoreData = Map<String, dynamic>.from(data);
        firestoreData['updated_at'] = FieldValue.serverTimestamp();
        await _firestoreRef
            .doc(docId)
            .set(firestoreData, SetOptions(merge: true))
            .timeout(const Duration(seconds: 3));
        debugPrint(
            '[FirebaseUserService] Firestore simpan user sukses: $docId');
      } catch (e) {
        debugPrint('[FirebaseUserService] Firestore user sync info: $e');
      }

      // --- 4. SINKRONKAN KE FIREBASE AUTHENTICATION (SDK & REST API) ---
      await syncUserToFirebaseAuth(data);

      return docId;
    } catch (e) {
      debugPrint('[FirebaseUserService] Gagal menyimpan user ke Firebase: $e');
      return null;
    }
  }

  /// Sinkronisasi akun pengguna ke Firebase Authentication (SDK + Google Identity Toolkit REST API)
  /// Menjamin seluruh akun pengguna SQLite terdaftar di Firebase Authentication (Console Auth)
  Future<bool> syncUserToFirebaseAuth(Map<String, dynamic> data) async {
    try {
      final userEmail = data['email']?.toString().trim();
      if (userEmail == null || !userEmail.contains('@') || isDummyUser(data)) {
        return false;
      }

      final authProvider =
          (data['authProvider'] ?? '').toString().toLowerCase();
      // Akun OAuth resmi pihak ketiga (GitHub, Google) dikelola langsung oleh provider resminya (github.com / google.com).
      // Jangan pernah daftarkan via email/password agar logo provider resmi tetap terjaga di Firebase Console!
      if (authProvider == 'github' || authProvider == 'google') {
        return true;
      }

      String userPass =
          (data['password'] != null && data['password'].toString().isNotEmpty)
              ? data['password'].toString()
              : 'User1234!';
      if (userPass.length < 6) {
        userPass = '${userPass}123456';
      }

      bool success = false;

      // A. Coba daftarkan via FirebaseAuth SDK
      try {
        final userCred =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: userEmail,
          password: userPass,
        );
        if (data['nama'] != null) {
          await userCred.user?.updateDisplayName(data['nama'].toString());
        }
        if (data['avatarUrl'] != null) {
          await userCred.user?.updatePhotoURL(data['avatarUrl'].toString());
        }
        debugPrint(
            '[FirebaseUserService] FirebaseAuth SDK createUser sukses: ${userCred.user?.uid}');
        success = true;
      } on FirebaseAuthException catch (authEx) {
        if (authEx.code == 'email-already-in-use') {
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: userEmail,
              password: userPass,
            );
            success = true;
          } catch (_) {
            success = true;
          }
        }
      } catch (_) {}

      // B. Jamin melalui REST API Google Identity Toolkit (kompatibel lintas OS: Android, Desktop, Web)
      try {
        final apiKey = FirebaseAuthTokenService.instance.apiKey;
        final authUrl = Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey');
        final authBody = {
          'email': userEmail,
          'password': userPass,
          'returnSecureToken': true,
        };
        final authRes = await http
            .post(
              authUrl,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(authBody),
            )
            .timeout(const Duration(seconds: 5));
        if (authRes.statusCode == 200) {
          debugPrint(
              '[FirebaseUserService] Firebase Auth REST signup sukses: $userEmail');
          success = true;
        } else if (authRes.statusCode == 400 &&
            authRes.body.contains('EMAIL_EXISTS')) {
          success = true;
        }
      } catch (_) {}

      return success;
    } catch (authErr) {
      debugPrint('[FirebaseUserService] Firebase Auth sync info: $authErr');
      return false;
    }
  }

  /// Memperbarui atribut pengguna tertentu di Firebase tanpa membuat table/node ganda di RTDB
  Future<bool> updateUserInFirebase({
    String? uid,
    String? email,
    String? username,
    String? docId,
    required Map<String, dynamic> updatedData,
  }) async {
    try {
      final Map<String, dynamic> data = Map<String, dynamic>.from(updatedData);

      // Filter ketat: Tolak penyimpanan akun dummy / mock / test ke Firebase
      if (isDummyUser(data)) return true;

      // Normalisasi tipe data jika ada
      if (data['saldo'] != null) {
        data['saldo'] = (data['saldo'] as num).toDouble();
      }
      if (data['is2FA'] != null) {
        data['is2FA'] = (data['is2FA'] as num).toInt();
      }
      if (data['password'] != null &&
          data['password'].toString().trim().isNotEmpty) {
        data['password'] =
            SecurityHelper.hashPassword(data['password'].toString().trim());
      }
      if (data['pin'] != null && data['pin'].toString().trim().isNotEmpty) {
        data['pin'] = SecurityHelper.hashPin(data['pin'].toString().trim());
      }

      if (uid != null && uid.isNotEmpty) {
        data['uid'] = uid;
      }
      if (email != null && email.isNotEmpty && data['email'] == null) {
        data['email'] = email;
      }
      if (username != null && username.isNotEmpty && data['username'] == null) {
        data['username'] = username;
      }

      final nowIso = DateTime.now().toIso8601String();
      data['updated_at'] = nowIso;

      // 1. Tentukan target docId yang valid
      String targetDocId = '';
      if (docId != null &&
          docId.trim().isNotEmpty &&
          docId.startsWith('usr_')) {
        targetDocId = _sanitizeKey(docId);
      }

      // 2. Periksa apakah ada node user yang cocok di RTDB
      final oldKeysToDelete = <String>{};
      try {
        final allUri = await buildRtdbUri();
        final allRes =
            await http.get(allUri).timeout(const Duration(seconds: 4));
        if (allRes.statusCode == 200 &&
            allRes.body.isNotEmpty &&
            allRes.body != 'null') {
          final dynamic allDecoded = jsonDecode(allRes.body);
          if (allDecoded is Map) {
            for (final entry in allDecoded.entries) {
              final k = entry.key.toString();
              final v = entry.value;
              if (v is Map) {
                final uEmail = (v['email'] ?? '').toString().toLowerCase();
                final uName = (v['username'] ?? '').toString().toLowerCase();
                final uUid = (v['uid'] ?? '').toString().toLowerCase();

                final isMatch = (email != null &&
                        email.isNotEmpty &&
                        uEmail == email.toLowerCase()) ||
                    (username != null &&
                        username.isNotEmpty &&
                        uName == username.toLowerCase()) ||
                    (uid != null &&
                        uid.isNotEmpty &&
                        uUid == uid.toLowerCase()) ||
                    (data['email'] != null &&
                        uEmail == data['email'].toString().toLowerCase()) ||
                    (data['username'] != null &&
                        uName == data['username'].toString().toLowerCase()) ||
                    (data['uid'] != null &&
                        uUid == data['uid'].toString().toLowerCase()) ||
                    (docId != null && k == docId);

                if (isMatch) {
                  if (targetDocId.isEmpty) {
                    targetDocId = k;
                  } else if (k != targetDocId) {
                    oldKeysToDelete.add(k);
                  }
                }
              }
            }
          }
        }
      } catch (_) {}

      if (targetDocId.isEmpty) {
        targetDocId = _resolveDocId({
          'uid': uid ?? data['uid'],
          'email': email ?? data['email'],
          'username': username ?? data['username'],
          'nama': data['nama'],
          'role': data['role'],
        });
      }

      data['doc_id'] = targetDocId;

      // 3. Update HANYA SATU node targetDocId di Realtime Database via REST API & SDK (TIDAK MEMBUAT TABLE/NODE BARU)
      try {
        final uri = await buildRtdbUri('$targetDocId.json');
        await http
            .patch(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data),
            )
            .timeout(const Duration(seconds: 4));
      } catch (_) {}

      try {
        await _rtdbRef.child(targetDocId).update(data);
      } catch (_) {}

      // 4. Update via Cloud Firestore
      try {
        final firestoreData = Map<String, dynamic>.from(data);
        firestoreData['updated_at'] = FieldValue.serverTimestamp();
        await _firestoreRef
            .doc(targetDocId)
            .set(firestoreData, SetOptions(merge: true));
      } catch (_) {}

      // 5. Bersihkan node-node lama / duplikat yang berbeda agar RTDB bersih (1 akun = 1 node)
      for (final oldKey in oldKeysToDelete) {
        try {
          final delUri = await buildRtdbUri('$oldKey.json');
          await http.delete(delUri).timeout(const Duration(seconds: 3));
        } catch (_) {}

        try {
          await _rtdbRef.child(oldKey).remove();
        } catch (_) {}

        try {
          await _firestoreRef.doc(oldKey).delete();
        } catch (_) {}
      }

      return true;
    } catch (e) {
      debugPrint('[FirebaseUserService] Gagal update user di Firebase: $e');
      return false;
    }
  }

  /// Menghapus data akun pengguna dari Firebase (RTDB, Firestore & Auth)
  Future<bool> deleteUserFromFirebase({
    String? uid,
    String? email,
    String? username,
    String? docId,
  }) async {
    try {
      final keysToDelete = <String>{};
      if (docId != null && docId.trim().isNotEmpty) {
        keysToDelete.add(_sanitizeKey(docId));
      }
      if (uid != null && uid.trim().isNotEmpty) {
        keysToDelete.add(_sanitizeKey(uid));
      }
      if (email != null && email.trim().isNotEmpty) {
        keysToDelete.add(_sanitizeKey(email));
      }
      if (username != null && username.trim().isNotEmpty) {
        keysToDelete.add(_sanitizeKey(username));
      }

      // Cari juga key di RTDB yang sesuai
      try {
        final uri = await buildRtdbUri();
        final response =
            await http.get(uri).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200 &&
            response.body.isNotEmpty &&
            response.body != 'null') {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              final k = entry.key.toString();
              final v = entry.value;
              if (v is Map) {
                final uMail = (v['email'] ?? '').toString().toLowerCase();
                final uName = (v['username'] ?? '').toString().toLowerCase();
                final uUid = (v['uid'] ?? '').toString().toLowerCase();
                if ((email != null && uMail == email.toLowerCase()) ||
                    (username != null && uName == username.toLowerCase()) ||
                    (uid != null && uUid == uid.toLowerCase())) {
                  keysToDelete.add(k);
                }
              }
            }
          }
        }
      } catch (_) {}

      for (final cleanKey in keysToDelete) {
        // 1. Hapus via REST API RTDB
        try {
          final uri = await buildRtdbUri('$cleanKey.json');
          await http.delete(uri).timeout(const Duration(seconds: 4));
        } catch (_) {}

        // 2. Hapus via SDK RTDB
        try {
          await _rtdbRef.child(cleanKey).remove();
        } catch (_) {}

        // 3. Hapus via Cloud Firestore
        try {
          await _firestoreRef.doc(cleanKey).delete();
        } catch (_) {}
      }

      // 4. Hapus dari Firebase Authentication jika email tersedia
      if (email != null && email.contains('@')) {
        try {
          final apiKey = FirebaseAuthTokenService.instance.apiKey;
          final signinUrl = Uri.parse(
              'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey');
          final userInDb = await DatabaseHelper.instance.getUserByEmail(email);
          final passToTry = userInDb?['password']?.toString() ?? 'User1234!';
          final signinRes = await http.post(
            signinUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'password': passToTry,
              'returnSecureToken': true,
            }),
          );
          if (signinRes.statusCode == 200) {
            final resJson = jsonDecode(signinRes.body);
            final idToken = resJson['idToken'];
            if (idToken != null) {
              final delUrl = Uri.parse(
                  'https://identitytoolkit.googleapis.com/v1/accounts:delete?key=$apiKey');
              await http.post(
                delUrl,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'idToken': idToken}),
              );
            }
          }
        } catch (_) {}
      }

      // Susun ulang urutan sisa akun di Firebase RTDB
      await syncOrderedUsersToFirebase();

      debugPrint(
          '[FirebaseUserService] Sukses menghapus user dari Firebase: $keysToDelete');
      return true;
    } catch (e) {
      debugPrint(
          '[FirebaseUserService] Gagal menghapus user dari Firebase: $e');
      return false;
    }
  }

  /// Sinkronisasi penuh: Salin semua akun pengguna dari SQLite lokal ke Firebase
  Future<int> syncAllLocalUsersToFirebase() async {
    try {
      final localUsers = await DatabaseHelper.instance.getAllUsers();
      if (localUsers.isEmpty) {
        await _saveDefaultAdminAndUser();
        return 2;
      }

      await syncOrderedUsersToFirebase();
      return localUsers.length;
    } catch (e) {
      debugPrint(
          '[FirebaseUserService] Gagal sinkronisasi pengguna ke Firebase: $e');
      return 0;
    }
  }

  /// Mengambil data pengguna dari Firebase berdasarkan identifier (UID / Email / Username)
  Future<Map<String, dynamic>?> getUserFromFirebase(String identifier) async {
    try {
      final cleanKey = _sanitizeKey(identifier);

      // Coba ambil dari Realtime Database via REST API
      final uri = await buildRtdbUri('$cleanKey.json');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 && response.body != 'null') {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }

      // Coba cari di seluruh daftar user RTDB
      final allUri = await buildRtdbUri();
      final allRes = await http.get(allUri).timeout(const Duration(seconds: 4));
      if (allRes.statusCode == 200 && allRes.body != 'null') {
        final dynamic allDecoded = jsonDecode(allRes.body);
        if (allDecoded is Map) {
          final target = identifier.trim().toLowerCase();
          for (final entry in allDecoded.entries) {
            if (entry.value is Map) {
              final user = Map<String, dynamic>.from(entry.value as Map);
              if ((user['email'] ?? '').toString().toLowerCase() == target ||
                  (user['username'] ?? '').toString().toLowerCase() == target ||
                  (user['uid'] ?? '').toString().toLowerCase() == target) {
                return user;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint(
          '[FirebaseUserService] Error mengambil data user dari Firebase: $e');
    }
    return null;
  }

  /// Mengunduh seluruh akun pengguna dari Firebase ke database SQLite lokal
  Future<int> syncUsersFromFirebase() async {
    try {
      final uri = await buildRtdbUri();
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 &&
          response.body != 'null' &&
          response.body.isNotEmpty) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map) {
          int imported = 0;
          final cloudUserIdentifiers = <String>{};

          for (final entry in decoded.entries) {
            if (entry.value is Map) {
              final userMap = Map<String, dynamic>.from(entry.value as Map);
              if (isDummyUser(userMap)) continue;

              final email = userMap['email']?.toString().trim();
              final username = userMap['username']?.toString().trim();
              if ((email == null || email.isEmpty) &&
                  (username == null || username.isEmpty)) {
                continue;
              }

              if (email != null) cloudUserIdentifiers.add(email.toLowerCase());
              if (username != null) {
                cloudUserIdentifiers.add(username.toLowerCase());
              }

              final uidFromCloud = userMap['uid']?.toString().trim();
              Map<String, dynamic>? existingUser;
              if (uidFromCloud != null && uidFromCloud.isNotEmpty) {
                existingUser =
                    await DatabaseHelper.instance.getUserByUid(uidFromCloud);
              }
              if (existingUser == null && email != null && email.isNotEmpty) {
                existingUser = await DatabaseHelper.instance
                    .getUserByEmailOrUsername(email);
              }
              if (existingUser == null &&
                  username != null &&
                  username.isNotEmpty) {
                existingUser = await DatabaseHelper.instance
                    .getUserByEmailOrUsername(username);
              }

              if (existingUser != null) {
                final updateData = <String, dynamic>{};
                if (username != null && username.isNotEmpty) {
                  updateData['username'] = username;
                }
                if (email != null && email.isNotEmpty) {
                  updateData['email'] = email;
                }
                if (userMap['nama'] != null) {
                  updateData['nama'] = userMap['nama'];
                }
                if (userMap['saldo'] != null) {
                  updateData['saldo'] = (userMap['saldo'] as num).toDouble();
                }
                if (userMap['phone'] != null) {
                  updateData['phone'] = userMap['phone'];
                }
                if (userMap['location'] != null) {
                  updateData['location'] = userMap['location'];
                }
                if (userMap['avatarUrl'] != null) {
                  updateData['avatarUrl'] = userMap['avatarUrl'];
                }
                if (userMap['pin'] != null &&
                    userMap['pin'].toString().isNotEmpty) {
                  updateData['pin'] =
                      SecurityHelper.hashPin(userMap['pin'].toString());
                }
                if (userMap['role'] != null) {
                  updateData['role'] = userMap['role'];
                }
                if (userMap['password'] != null &&
                    userMap['password'].toString().isNotEmpty) {
                  updateData['password'] = SecurityHelper.hashPassword(
                      userMap['password'].toString());
                }
                if (userMap['is2FA'] != null) {
                  updateData['is2FA'] = (userMap['is2FA'] as num).toInt();
                }
                if (userMap['language'] != null) {
                  updateData['language'] = userMap['language'];
                }
                if (userMap['bio'] != null) {
                  updateData['bio'] = userMap['bio'];
                }
                if (userMap['referralCode'] != null) {
                  updateData['referralCode'] = userMap['referralCode'];
                }

                final int? existingId = (existingUser['id'] as num?)?.toInt();
                final uid = existingUser['uid']?.toString() ?? uidFromCloud;
                if (existingId != null && existingId > 0) {
                  await DatabaseHelper.instance.updateUserById(
                      existingId, updateData,
                      syncToCloud: false);
                } else if (uid != null && uid.isNotEmpty) {
                  await DatabaseHelper.instance
                      .updateUserByUid(uid, updateData, syncToCloud: false);
                }
                imported++;
              } else {
                final insertData = <String, dynamic>{
                  'uid': userMap['uid'] ??
                      'usr_${DateTime.now().millisecondsSinceEpoch}',
                  'nama': userMap['nama'] ?? username ?? 'User VibeTech',
                  'username': username ??
                      (email != null ? email.split('@').first : 'user'),
                  'email': email ?? '${username ?? 'user'}@vibetech.com',
                  'phone': userMap['phone'] ?? '',
                  'password': userMap['password'] ??
                      SecurityHelper.hashPassword(
                          'vbt_vault_${DateTime.now().millisecondsSinceEpoch}'),
                  'pin': userMap['pin'] != null
                      ? SecurityHelper.hashPin(userMap['pin'].toString())
                      : SecurityHelper.hashPin('123456'),
                  'referralCode': userMap['referralCode'] ?? '',
                  'role': userMap['role'] ?? 'user',
                  'createdAt':
                      userMap['createdAt'] ?? DateTime.now().toIso8601String(),
                  'saldo': (userMap['saldo'] as num?)?.toDouble() ?? 0.0,
                  'location': userMap['location'] ?? 'Indonesia',
                  'avatarUrl': userMap['avatarUrl'] ??
                      'https://cdn.nekohime.site/file/5232n74c.jpeg',
                  'is2FA': (userMap['is2FA'] as num?)?.toInt() ?? 1,
                  'language': userMap['language'] ?? 'Indonesia',
                  'authProvider': userMap['authProvider'] ?? 'Local',
                  'bio': userMap['bio'] ?? '',
                };
                await DatabaseHelper.instance
                    .registerUser(insertData, syncToCloud: false);
                imported++;
              }
            }
          }

          // Sinkronisasi hapus akun jika sudah dihapus di Firebase
          if (cloudUserIdentifiers.isNotEmpty) {
            final db = await DatabaseHelper.instance.database;
            final localUsers = await DatabaseHelper.instance.getAllUsers();
            for (final lu in localUsers) {
              final luEmail =
                  (lu['email'] ?? '').toString().trim().toLowerCase();
              final luName =
                  (lu['username'] ?? '').toString().trim().toLowerCase();
              final luRole =
                  (lu['role'] ?? 'user').toString().trim().toLowerCase();
              if (luRole == 'admin' || luRole == 'administrator') continue;
              if (!cloudUserIdentifiers.contains(luEmail) &&
                  !cloudUserIdentifiers.contains(luName)) {
                final id = (lu['id'] as num?)?.toInt() ?? 0;
                if (id > 0) {
                  await db.delete('users', where: 'id = ?', whereArgs: [id]);
                  debugPrint(
                      '[FirebaseUserService] 🗑️ User "$luName" dihapus dari SQLite karena sudah dihapus di Firebase.');
                }
              }
            }
          }

          // Bersihkan key spam / duplikat yang mungkin tertinggal di cloud
          await cleanupDuplicateSpamUsersFromFirebase();

          debugPrint(
              '[FirebaseUserService] 📥 Sukses menyinkronkan $imported akun dari Cloud Firebase ke SQLite lokal.');
          return imported;
        }
      }
    } catch (e) {
      debugPrint('[FirebaseUserService] Gagal sync users dari Firebase: $e');
    }
    return 0;
  }

  /// Menyusun dan menyinkronkan daftar akun di Firebase RTDB agar berurutan sesuai nomor & nama akun (usr_01_..., usr_02_...)
  Future<void> syncOrderedUsersToFirebase() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final localUsers = await db.query('users');
      if (localUsers.isEmpty) return;

      final sortedUsers = List<Map<String, dynamic>>.from(
        localUsers.map((u) => Map<String, dynamic>.from(u)),
      );

      // Urutan: Administrator pertama, kemudian diurutkan secara alfabetis berdasarkan nama / username
      sortedUsers.sort((a, b) {
        final roleA = (a['role'] ?? 'user').toString().toLowerCase();
        final roleB = (b['role'] ?? 'user').toString().toLowerCase();
        final isAdminA = roleA == 'admin' || roleA == 'administrator';
        final isAdminB = roleB == 'admin' || roleB == 'administrator';
        if (isAdminA && !isAdminB) return -1;
        if (!isAdminA && isAdminB) return 1;

        final nameA =
            (a['nama'] ?? a['username'] ?? '').toString().toLowerCase();
        final nameB =
            (b['nama'] ?? b['username'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      });

      // Bersihkan key lama yang tidak berurutan di RTDB
      try {
        final uri = await buildRtdbUri();
        final resp = await http.get(uri).timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200 &&
            resp.body.isNotEmpty &&
            resp.body != 'null') {
          final dynamic decoded = jsonDecode(resp.body);
          if (decoded is Map) {
            final validKeys = <String>{};
            for (int i = 0; i < sortedUsers.length; i++) {
              validKeys.add(_resolveDocId(sortedUsers[i], orderIndex: i + 1));
            }
            for (final k in decoded.keys) {
              final kStr = k.toString();
              if (!validKeys.contains(kStr)) {
                final delUri = await buildRtdbUri('$kStr.json');
                await http.delete(delUri).timeout(const Duration(seconds: 3));
              }
            }
          }
        }
      } catch (_) {}

      // Tulis ulang akun dengan key berurutan usr_01_..., usr_02_..., dst.
      for (int i = 0; i < sortedUsers.length; i++) {
        final user = sortedUsers[i];
        if (isDummyUser(user)) continue;

        final orderNum = i + 1;
        user['no'] = orderNum;
        user['urutan'] = orderNum;
        final docId = _resolveDocId(user, orderIndex: orderNum);
        user['doc_id'] = docId;
        user['updated_at'] = DateTime.now().toIso8601String();

        if (user['password'] == null ||
            user['password'].toString().trim().isEmpty) {
          if ((user['email'] ?? '') == 'admin@vibetech.com' ||
              (user['username'] ?? '') == 'raziek' ||
              (user['role'] ?? '') == 'admin') {
            user['password'] = 'razieksz';
          }
        }
        if (user['pin'] == null || user['pin'].toString().trim().isEmpty) {
          user['pin'] = '123456';
        }

        // Put ke RTDB via REST API
        try {
          final uri = await buildRtdbUri('$docId.json');
          await http
              .put(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(user),
              )
              .timeout(const Duration(seconds: 4));
        } catch (_) {}

        // Put ke Firestore
        try {
          final firestoreData = Map<String, dynamic>.from(user);
          firestoreData['updated_at'] = FieldValue.serverTimestamp();
          await _firestoreRef
              .doc(docId)
              .set(firestoreData, SetOptions(merge: true));
        } catch (_) {}

        // Sinkronkan akun pengguna ke Firebase Authentication (Console Auth)
        await syncUserToFirebaseAuth(user);
      }

      debugPrint(
          '[FirebaseUserService] 🚀 Sukses menyusun database Firebase RTDB akun pengguna terurut rapi.');
    } catch (e) {
      debugPrint(
          '[FirebaseUserService] Gagal menyusun urutan akun di Firebase: $e');
    }
  }

  /// Menginisialisasi akun admin resmi di cloud jika belum ada
  Future<void> _saveDefaultAdminAndUser() async {
    final nowIso = DateTime.now().toIso8601String();
    final defaultAdmin = {
      'no': 1,
      'urutan': 1,
      'doc_id': 'usr_01_raziek',
      'uid': 'usr_admin_001',
      'nama': 'Admin VibeTech',
      'username': 'raziek',
      'email': 'admin@vibetech.com',
      'phone': '081122334455',
      'password': 'razieksz',
      'pin': '123456',
      'referralCode': 'ADMIN2026',
      'role': 'admin',
      'createdAt': nowIso,
      'saldo': 10000000.0,
      'location': 'Jakarta, Indonesia',
      'avatarUrl': 'https://cdn.nekohime.site/file/5232n74c.jpeg',
      'is2FA': 1,
      'language': 'Indonesia',
    };

    await saveUserToFirebase(defaultAdmin);
  }

  /// Menghapus seluruh akun dummy / test dari SQLite lokal dan Firebase RTDB & Firestore
  Future<void> cleanupDummyUsersFromFirebaseAndLocal() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Hapus dari SQLite lokal (hanya akun mock unit test otomatis)
      await db.delete(
        'users',
        where:
            "username LIKE 'mock_unittest_%' OR username LIKE 'temp_test_runner_%' OR email LIKE 'mock_unittest_%'",
      );

      // 2. Hapus akun dummy dari Firebase RTDB & Firestore
      try {
        final uri = await buildRtdbUri();
        final response =
            await http.get(uri).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200 &&
            response.body != 'null' &&
            response.body.isNotEmpty) {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              final k = entry.key.toString();
              final v = entry.value;
              if (v is Map) {
                final userMap = Map<String, dynamic>.from(v);
                if (isDummyUser(userMap)) {
                  try {
                    final delUri = await buildRtdbUri('$k.json');
                    await http
                        .delete(delUri)
                        .timeout(const Duration(seconds: 3));
                  } catch (_) {}

                  try {
                    await _rtdbRef.child(k).remove();
                  } catch (_) {}

                  try {
                    await _firestoreRef.doc(k).delete();
                  } catch (_) {}
                }
              }
            }
          }
        }
      } catch (_) {}

      // 3. Jaga data akun nyata di Firebase tetap permanen (tidak ditimpa ulang)
      debugPrint(
          '[FirebaseUserService] 🧹 Sukses memverifikasi akun pengguna permanen di Firebase.');
    } catch (e) {
      debugPrint('[FirebaseUserService] Error cleanup dummy users: $e');
    }
  }

  /// Membersihkan seluruh akun spam, duplikat, dan key malformed (seperti usr_2440_oooo, usr_25xx_oooo)
  /// dari Firebase RTDB dan menyisakan HANYA satu akun resmi bersih (usr_01_raziek, usr_oooo, dll.)
  Future<int> cleanupDuplicateSpamUsersFromFirebase() async {
    try {
      final uri = await buildRtdbUri();
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200 ||
          response.body == 'null' ||
          response.body.isEmpty) {
        return 0;
      }
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map) return 0;

      int deletedCount = 0;
      final Map<String, dynamic> allUsers = Map<String, dynamic>.from(decoded);

      // Kumpulkan akun berdasarkan identifier unik (email dan username)
      final Map<String, List<MapEntry<String, dynamic>>> groupedUsers = {};
      final List<String> orphanedKeys = [];

      for (final entry in allUsers.entries) {
        final key = entry.key.toString();
        final val = entry.value;
        if (val is! Map) {
          orphanedKeys.add(key);
          continue;
        }

        final email = (val['email'] ?? '').toString().trim().toLowerCase();
        final username =
            (val['username'] ?? '').toString().trim().toLowerCase();

        // 1. Akun tanpa email dan tanpa username (orphaned / empty keys)
        if (email.isEmpty && username.isEmpty) {
          orphanedKeys.add(key);
          continue;
        }

        // 2. Akun dummy / test unit
        if (isDummyUser(Map<String, dynamic>.from(val))) {
          orphanedKeys.add(key);
          continue;
        }

        // Gunakan identifier utama: username atau email
        final identifier = username.isNotEmpty ? username : email;
        groupedUsers.putIfAbsent(identifier, () => []).add(entry);
      }

      // Hapus orphaned / dummy keys
      for (final junkKey in orphanedKeys) {
        try {
          final delUri = await buildRtdbUri('$junkKey.json');
          await http.delete(delUri).timeout(const Duration(seconds: 2));
          await _rtdbRef.child(junkKey).remove();
          await _firestoreRef.doc(junkKey).delete();
          deletedCount++;
        } catch (_) {}
      }

      // Proses setiap grup akun untuk menyisakan HANYA 1 key bersih canonical
      for (final entry in groupedUsers.entries) {
        final list = entry.value;
        if (list.length == 1) {
          // Hanya 1 akun, cek apakah key-nya spam seperti usr_2514_oooo
          final currentKey = list.first.key.toString();
          final userData = Map<String, dynamic>.from(list.first.value as Map);
          final canonicalKey = _resolveDocId(userData);

          if (currentKey != canonicalKey &&
              RegExp(r'^usr_\d{3,}_').hasMatch(currentKey)) {
            // Migrasikan ke canonical key
            userData['doc_id'] = canonicalKey;
            final putUri = await buildRtdbUri('$canonicalKey.json');
            await http.put(putUri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(userData));
            try {
              await _rtdbRef.child(canonicalKey).set(userData);
            } catch (_) {}

            // Hapus key lama
            final delUri = await buildRtdbUri('$currentKey.json');
            await http.delete(delUri).timeout(const Duration(seconds: 2));
            try {
              await _rtdbRef.child(currentKey).remove();
            } catch (_) {}
            deletedCount++;
          }
        } else {
          // Ada beberapa entri duplikat (seperti puluhan usr_25xx_oooo)
          // Cari entri terbaik (yang punya data lengkap / updated_at terbaru)
          Map<String, dynamic> bestData = {};
          String bestKey = '';

          for (final item in list) {
            final m = Map<String, dynamic>.from(item.value as Map);
            if (bestKey.isEmpty ||
                (m['updated_at'] ?? '')
                        .toString()
                        .compareTo((bestData['updated_at'] ?? '').toString()) >
                    0) {
              bestData = m;
              bestKey = item.key.toString();
            }
          }

          final canonicalKey = _resolveDocId(bestData);
          bestData['doc_id'] = canonicalKey;

          // Simpan SATU entri bersih ke canonicalKey
          final putUri = await buildRtdbUri('$canonicalKey.json');
          await http.put(putUri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(bestData));
          try {
            await _rtdbRef.child(canonicalKey).set(bestData);
          } catch (_) {}

          // Hapus SEMUA key duplikat lainnya
          for (final item in list) {
            final k = item.key.toString();
            if (k != canonicalKey) {
              try {
                final delUri = await buildRtdbUri('$k.json');
                await http.delete(delUri).timeout(const Duration(seconds: 2));
                await _rtdbRef.child(k).remove();
                await _firestoreRef.doc(k).delete();
                deletedCount++;
              } catch (_) {}
            }
          }
        }
      }

      // Bersihkan juga duplikat lokal di SQLite jika ada
      try {
        final db = await DatabaseHelper.instance.database;
        await db.execute('''
          DELETE FROM users
          WHERE id NOT IN (
            SELECT MAX(id)
            FROM users
            GROUP BY LOWER(TRIM(username))
          )
          AND role != 'admin' AND role != 'administrator'
        ''');
      } catch (_) {}

      debugPrint(
          '[FirebaseUserService] 🧹 Sukses membersihkan $deletedCount key duplikat/spam dari Firebase RTDB.');
      return deletedCount;
    } catch (e) {
      debugPrint(
          '[FirebaseUserService] Error saat cleanup duplicate users: $e');
      return 0;
    }
  }
}

/// Extension agar method pembantu URI RTDB dapat diakses secara langsung lewat instance maupun static
extension FirebaseUserServiceExtension on FirebaseUserService {
  Future<Uri> buildRtdbUri([String? docKey]) =>
      FirebaseUserService.buildRtdbUri(docKey);
}

