import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vibetech_xyz/database/db_helper.dart';

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

  /// Menentukan ID Dokumen untuk akun pengguna
  String _resolveDocId(Map<String, dynamic> data) {
    final uid = data['uid']?.toString().trim();
    if (uid != null && uid.isNotEmpty) {
      return _sanitizeKey(uid);
    }
    final email = data['email']?.toString().trim();
    if (email != null && email.isNotEmpty) {
      return _sanitizeKey(email);
    }
    final username = data['username']?.toString().trim();
    if (username != null && username.isNotEmpty) {
      return _sanitizeKey(username);
    }
    return 'usr_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Memeriksa apakah suatu akun adalah akun dummy / mock / unit test
  static bool isDummyUser(Map<String, dynamic> data) {
    final email = (data['email'] ?? '').toString().trim().toLowerCase();
    final username = (data['username'] ?? '').toString().trim().toLowerCase();
    final nama = (data['nama'] ?? '').toString().trim().toLowerCase();
    final uid = (data['uid'] ?? '').toString().trim().toLowerCase();

    // Daftar kata kunci dummy / mock / test data yang dilarang masuk ke cloud Firebase
    final dummyKeywords = [
      'test_',
      'mock_',
      'balance_test',
      'alex.pratama',
      'alex_pratama',
      'budi.santoso',
      'budi_santoso',
      'budi santoso',
      'budi',
      'dev.github',
      'dev_github',
      'cloud_',
      'sync_test',
      'fake_',
      'temp_',
      'dummy',
      'demouser',
      'example.com',
      'test.com',
    ];

    for (final keyword in dummyKeywords) {
      if (email.contains(keyword) ||
          username.contains(keyword) ||
          nama.contains(keyword) ||
          uid.contains(keyword)) {
        return true;
      }
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

      data['uid_ref'] = docId;

      final nowIso = DateTime.now().toIso8601String();
      data['updated_at'] = nowIso;
      if (!data.containsKey('createdAt') && !data.containsKey('created_at')) {
        data['createdAt'] = nowIso;
      }

      // --- 1. SIMPAN KE REALTIME DATABASE VIA HTTP REST API (GARANSI UTAMA & INSTANT DI SEMUA OS) ---
      try {
        final uri = Uri.parse('$rtdbBaseUrl/$collectionName/$docId.json');
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
              '[FirebaseUserService] HTTP REST RTDB gagal status: ${response.statusCode}, body: ${response.body}');
        }
      } catch (httpError) {
        debugPrint(
            '[FirebaseUserService] HTTP REST RTDB Exception: $httpError');
      }

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
      try {
        final userEmail = data['email']?.toString().trim();
        String userPass = (data['password'] ?? 'password123456').toString();
        if (userPass.length < 6) userPass = 'password123456';
        if (userEmail != null &&
            userEmail.contains('@') &&
            !isDummyUser(data)) {
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
          } on FirebaseAuthException catch (authEx) {
            if (authEx.code == 'email-already-in-use') {
              try {
                await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: userEmail,
                  password: userPass,
                );
              } catch (_) {}
            }
          } catch (_) {}

          // B. Jamin melalui REST API Google Identity Toolkit
          final authUrl = Uri.parse(
              'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=AIzaSyC7IO_Y824QCe2Y7BUFKTHF5dMtLR3PZ6w');
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
          } else {
            final signinUrl = Uri.parse(
                'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=AIzaSyC7IO_Y824QCe2Y7BUFKTHF5dMtLR3PZ6w');
            await http
                .post(
                  signinUrl,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(authBody),
                )
                .timeout(const Duration(seconds: 5));
          }
        }
      } catch (authErr) {
        debugPrint('[FirebaseUserService] Firebase Auth sync info: $authErr');
      }

      return docId;
    } catch (e) {
      debugPrint('[FirebaseUserService] Gagal menyimpan user ke Firebase: $e');
      return null;
    }
  }

  /// Memperbarui atribut pengguna tertentu di Firebase
  Future<bool> updateUserInFirebase({
    String? uid,
    String? email,
    String? username,
    required Map<String, dynamic> updatedData,
  }) async {
    try {
      final Map<String, dynamic> data = Map<String, dynamic>.from(updatedData);
      String? cleanKey;
      if (uid != null && uid.trim().isNotEmpty) {
        cleanKey = _sanitizeKey(uid);
      } else if (email != null && email.trim().isNotEmpty) {
        cleanKey = _sanitizeKey(email);
      } else if (username != null && username.trim().isNotEmpty) {
        cleanKey = _sanitizeKey(username);
      }

      if (cleanKey == null) return false;

      final nowIso = DateTime.now().toIso8601String();
      data['updated_at'] = nowIso;

      // 1. Update ke Realtime Database via REST API
      try {
        final uri = Uri.parse('$rtdbBaseUrl/$collectionName/$cleanKey.json');
        await http.patch(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        );
      } catch (_) {}

      // 2. Update via SDK RTDB
      try {
        await _rtdbRef.child(cleanKey).update(data);
      } catch (_) {}

      // 3. Update via Firestore
      try {
        final firestoreData = Map<String, dynamic>.from(data);
        firestoreData['updated_at'] = FieldValue.serverTimestamp();
        await _firestoreRef
            .doc(cleanKey)
            .set(firestoreData, SetOptions(merge: true));
      } catch (_) {}

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
  }) async {
    try {
      final keysToDelete = <String>{};
      if (uid != null && uid.trim().isNotEmpty) {
        keysToDelete.add(_sanitizeKey(uid));
      }
      if (email != null && email.trim().isNotEmpty) {
        keysToDelete.add(_sanitizeKey(email));
      }
      if (username != null && username.trim().isNotEmpty) {
        keysToDelete.add(_sanitizeKey(username));
      }

      for (final cleanKey in keysToDelete) {
        // 1. Hapus via REST API RTDB
        try {
          final uri = Uri.parse('$rtdbBaseUrl/$collectionName/$cleanKey.json');
          await http.delete(uri);
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
          final signinUrl = Uri.parse(
              'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=AIzaSyC7IO_Y824QCe2Y7BUFKTHF5dMtLR3PZ6w');
          final signinRes = await http.post(
            signinUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'password': 'password123456',
              'returnSecureToken': true,
            }),
          );
          if (signinRes.statusCode == 200) {
            final resJson = jsonDecode(signinRes.body);
            final idToken = resJson['idToken'];
            if (idToken != null) {
              final delUrl = Uri.parse(
                  'https://identitytoolkit.googleapis.com/v1/accounts:delete?key=AIzaSyC7IO_Y824QCe2Y7BUFKTHF5dMtLR3PZ6w');
              await http.post(
                delUrl,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'idToken': idToken}),
              );
            }
          }
        } catch (_) {}
      }

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
      int successCount = 0;

      if (localUsers.isEmpty) {
        debugPrint(
            '[FirebaseUserService] Belum ada user di SQLite lokal. Menginisialisasi user default...');
        await _saveDefaultAdminAndUser();
        return 2;
      }

      for (final userMap in localUsers) {
        final res = await saveUserToFirebase(userMap);
        if (res != null) successCount++;
      }

      debugPrint(
          '[FirebaseUserService] Sukses sinkronisasi $successCount / ${localUsers.length} akun pengguna ke Firebase.');
      return successCount;
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
      final uri = Uri.parse('$rtdbBaseUrl/$collectionName/$cleanKey.json');
      final response = await http.get(uri);
      if (response.statusCode == 200 && response.body != 'null') {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }

      // Coba cari di seluruh daftar user RTDB
      final allUri = Uri.parse('$rtdbBaseUrl/$collectionName.json');
      final allRes = await http.get(allUri);
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
      final uri = Uri.parse('$rtdbBaseUrl/$collectionName.json');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 &&
          response.body != 'null' &&
          response.body.isNotEmpty) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map) {
          int imported = 0;
          for (final entry in decoded.entries) {
            if (entry.value is Map) {
              final userMap = Map<String, dynamic>.from(entry.value as Map);
              if (isDummyUser(userMap)) continue; // Abaikan akun testing dummy

              final email = userMap['email']?.toString().trim();
              final username = userMap['username']?.toString().trim();
              if ((email == null || email.isEmpty) &&
                  (username == null || username.isEmpty)) {
                continue;
              }

              final existingUser = await DatabaseHelper.instance
                  .getUserByEmailOrUsername(email ?? username ?? '');
              if (existingUser != null) {
                final updateData = <String, dynamic>{};
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
                if (userMap['pin'] != null) {
                  updateData['pin'] = userMap['pin'];
                }
                if (userMap['role'] != null) {
                  updateData['role'] = userMap['role'];
                }
                if (userMap['password'] != null) {
                  updateData['password'] = userMap['password'];
                }

                final uid = existingUser['uid']?.toString() ??
                    userMap['uid']?.toString();
                if (uid != null && uid.isNotEmpty) {
                  await DatabaseHelper.instance
                      .updateUserByUid(uid, updateData);
                } else if (email != null && email.isNotEmpty) {
                  await DatabaseHelper.instance
                      .updateUserProfile(email, updateData);
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
                  'password': userMap['password'] ?? 'password123',
                  'pin': userMap['pin'] ?? '123456',
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
                await DatabaseHelper.instance.registerUser(insertData);
                imported++;
              }
            }
          }
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

  /// Menginisialisasi akun admin resmi di cloud jika belum ada
  Future<void> _saveDefaultAdminAndUser() async {
    final nowIso = DateTime.now().toIso8601String();
    final defaultAdmin = {
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
}
