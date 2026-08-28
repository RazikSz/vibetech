import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetech_xyz/database/db_helper.dart';

/// ============================================================================
/// FIREBASE EMAIL CONFIG SERVICE - VIBETECH XYZ
/// ============================================================================
/// Layanan cloud database ganda untuk menyimpan, mengambil, dan menyinkronkan
/// konfigurasi server email (SMTP Configuration) ke:
/// 1. Google Cloud Firestore (Koleksi: 'email_settings' pada project vibetech-xyz)
///    URL Console: https://console.cloud.google.com/firestore/databases/vibetech-xyz/data/editor?authuser=0&project=vibetech-xyz&hl=en-US
/// 2. Firebase Realtime Database (Node: 'email_settings')
/// 3. Local SQLite Database (Tabel: 'email_settings') sebagai offline cache & fallback
/// 4. SharedPreferences sebagai runtime cache
class FirebaseEmailService {
  static final FirebaseEmailService instance = FirebaseEmailService._init();

  FirebaseEmailService._init();

  static const String projectId = 'vibetech-xyz';
  static const String rtdbBaseUrl =
      'https://vibetech-xyz-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String collectionName = 'email_settings';
  static const String globalDocId = 'global_config';

  static const String databaseId = 'vibetech-xyz';

  /// Referensi Google Cloud Firestore SDK (Mendukung named database vibetech-xyz & default)
  CollectionReference<Map<String, dynamic>> get _firestoreRef {
    try {
      return FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: databaseId,
      ).collection(collectionName);
    } catch (_) {
      try {
        return FirebaseFirestore.instance.collection(collectionName);
      } catch (_) {
        return FirebaseFirestore.instance.collection(collectionName);
      }
    }
  }

  /// Referensi Firebase Realtime Database SDK
  DatabaseReference get rtdbRef {
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: rtdbBaseUrl,
      ).ref(collectionName);
    } catch (_) {
      return FirebaseDatabase.instance.ref(collectionName);
    }
  }

  /// Menghasilkan Document ID / Key yang aman untuk Firestore & Firebase
  String _resolveDocId(String? userEmail) {
    if (userEmail == null || userEmail.trim().isEmpty) {
      return globalDocId;
    }
    final sanitized = userEmail.trim().toLowerCase().replaceAll(RegExp(r'[/\\#?\[\]\.\$]'), '_');
    return sanitized.isEmpty ? globalDocId : sanitized;
  }

  /// Format data ke Firestore REST API JSON format
  Map<String, dynamic> _formatToFirestoreRestFields(Map<String, dynamic> data) {
    final fields = <String, dynamic>{};
    data.forEach((key, value) {
      if (value == null) {
        fields[key] = {'nullValue': null};
      } else if (value is String) {
        fields[key] = {'stringValue': value};
      } else if (value is int) {
        fields[key] = {'integerValue': value.toString()};
      } else if (value is double) {
        fields[key] = {'doubleValue': value};
      } else if (value is bool) {
        fields[key] = {'booleanValue': value};
      } else {
        fields[key] = {'stringValue': value.toString()};
      }
    });
    return {'fields': fields};
  }

  /// Parse data dari Firestore REST API JSON format ke standard Map
  Map<String, dynamic> _parseFirestoreRestFields(Map<String, dynamic> restDoc) {
    final result = <String, dynamic>{};
    final fields = restDoc['fields'] as Map<String, dynamic>?;
    if (fields == null) return result;

    fields.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        if (value.containsKey('stringValue')) {
          result[key] = value['stringValue'];
        } else if (value.containsKey('integerValue')) {
          result[key] = int.tryParse(value['integerValue'].toString()) ?? 0;
        } else if (value.containsKey('doubleValue')) {
          result[key] = (value['doubleValue'] as num).toDouble();
        } else if (value.containsKey('booleanValue')) {
          result[key] = value['booleanValue'];
        } else if (value.containsKey('timestampValue')) {
          result[key] = value['timestampValue'];
        } else if (value.containsKey('nullValue')) {
          result[key] = null;
        }
      }
    });
    return result;
  }

  /// Menyimpan konfigurasi server email (SMTP) ke Google Cloud Firestore, RTDB, SQLite, dan SharedPreferences
  Future<bool> saveEmailSettings({
    required String smtpUser,
    required String smtpPass,
    String smtpHost = 'smtp.gmail.com',
    int smtpPort = 465,
    String? userEmail,
  }) async {
    final cleanUser = smtpUser.trim();
    final cleanPass = smtpPass.replaceAll(' ', '').trim();
    final cleanHost = smtpHost.trim().isEmpty ? 'smtp.gmail.com' : smtpHost.trim();
    final nowIso = DateTime.now().toIso8601String();
    final docId = _resolveDocId(userEmail);

    final data = <String, dynamic>{
      'smtp_user': cleanUser,
      'smtp_pass': cleanPass,
      'smtp_host': cleanHost,
      'smtp_port': smtpPort,
      'user_email': userEmail?.trim(),
      'updated_at': nowIso,
      'project_id': projectId,
      'doc_id': docId,
      'is_active': true,
    };

    bool isSavedToCloud = false;

    // --- 1. SIMPAN KE GOOGLE CLOUD FIRESTORE VIA SDK ---
    try {
      final firestoreData = Map<String, dynamic>.from(data);
      firestoreData['firestore_timestamp'] = FieldValue.serverTimestamp();
      
      await _firestoreRef.doc(docId).set(firestoreData, SetOptions(merge: true)).timeout(const Duration(seconds: 2));
      if (docId != globalDocId) {
        await _firestoreRef.doc(globalDocId).set(firestoreData, SetOptions(merge: true)).timeout(const Duration(seconds: 2));
      }
      
      isSavedToCloud = true;
      debugPrint('[FirebaseEmailService] ✅ Cloud Firestore simpan SMTP config sukses: $docId');
    } catch (e) {
      debugPrint('[FirebaseEmailService] ⚠️ Cloud Firestore SDK info: $e');
    }

    // --- 2. SIMPAN KE GOOGLE CLOUD FIRESTORE VIA HTTP REST API (GARANSI UTAMA & DIRECT WEB/DESKTOP) ---
    final databasesToTry = [databaseId, '(default)'];
    final restBody = _formatToFirestoreRestFields(data);

    for (final db in databasesToTry) {
      try {
        final restUrl = Uri.parse(
            'https://firestore.googleapis.com/v1/projects/$projectId/databases/$db/documents/$collectionName/$docId');
        final response = await http.patch(
          restUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(restBody),
        ).timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          isSavedToCloud = true;
          debugPrint('[FirebaseEmailService] ✅ Cloud Firestore REST API ($db) simpan SMTP sukses: $docId');
          
          if (docId != globalDocId) {
            final globalRestUrl = Uri.parse(
                'https://firestore.googleapis.com/v1/projects/$projectId/databases/$db/documents/$collectionName/$globalDocId');
            await http.patch(
              globalRestUrl,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(restBody),
            ).timeout(const Duration(seconds: 2));
          }
          break;
        }
      } catch (_) {}
    }

    // --- 3. SIMPAN KE FIREBASE REALTIME DATABASE (DUAL-CLOUD REDUNDANCY & CROSS-DEVICE INSTANT SYNC) ---
    try {
      final uri = Uri.parse('$rtdbBaseUrl/$collectionName/$docId.json');
      await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 2));

      if (docId != globalDocId) {
        final globalRtdbUri = Uri.parse('$rtdbBaseUrl/$collectionName/$globalDocId.json');
        await http.put(
          globalRtdbUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        ).timeout(const Duration(seconds: 2));
      }
    } catch (_) {}

    // --- 4. SIMPAN KE RUNTIME SHAREDPREFERENCES ---
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('smtp_user', cleanUser);
      await prefs.setString('smtp_pass', cleanPass);
      await prefs.setString('smtp_host', cleanHost);
      await prefs.setInt('smtp_port', smtpPort);
      await prefs.setString('smtp_updated_at', nowIso);
    } catch (_) {}

    return isSavedToCloud;
  }

  /// Mengambil konfigurasi server email (SMTP) dari Cloud Firestore dengan fallback ke SQLite & SharedPreferences
  Future<Map<String, dynamic>?> getEmailSettings({String? userEmail}) async {
    final docId = _resolveDocId(userEmail);

    // 1. Coba ambil dari Google Cloud Firestore via SDK
    try {
      final docSnap = await _firestoreRef.doc(docId).get().timeout(const Duration(seconds: 3));
      if (docSnap.exists && docSnap.data() != null) {
        final cloudData = Map<String, dynamic>.from(docSnap.data()!);
        debugPrint('[FirebaseEmailService] 📥 Berhasil memuat konfigurasi SMTP dari Cloud Firestore SDK: $docId');
        _cacheSettingsLocally(cloudData);
        return cloudData;
      } else if (docId != globalDocId) {
        final globalSnap = await _firestoreRef.doc(globalDocId).get().timeout(const Duration(seconds: 3));
        if (globalSnap.exists && globalSnap.data() != null) {
          final cloudData = Map<String, dynamic>.from(globalSnap.data()!);
          _cacheSettingsLocally(cloudData);
          return cloudData;
        }
      }
    } catch (e) {
      debugPrint('[FirebaseEmailService] Firestore SDK fetch info: $e');
    }

    // 2. Coba ambil dari Cloud Firestore via HTTP REST API
    final databasesToTry = [databaseId, '(default)'];
    for (final db in databasesToTry) {
      try {
        final restUrl = Uri.parse(
            'https://firestore.googleapis.com/v1/projects/$projectId/databases/$db/documents/$collectionName/$docId');
        final res = await http.get(restUrl).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          final parsedData = _parseFirestoreRestFields(decoded);
          if (parsedData.isNotEmpty && parsedData['smtp_user'] != null) {
            debugPrint('[FirebaseEmailService] 📥 Berhasil memuat SMTP config dari Cloud Firestore REST ($db): $docId');
            _cacheSettingsLocally(parsedData);
            return parsedData;
          }
        } else if (docId != globalDocId) {
          final globalRestUrl = Uri.parse(
              'https://firestore.googleapis.com/v1/projects/$projectId/databases/$db/documents/$collectionName/$globalDocId');
          final gRes = await http.get(globalRestUrl).timeout(const Duration(seconds: 3));
          if (gRes.statusCode == 200) {
            final gDecoded = jsonDecode(gRes.body) as Map<String, dynamic>;
            final gParsed = _parseFirestoreRestFields(gDecoded);
            if (gParsed.isNotEmpty && gParsed['smtp_user'] != null) {
              _cacheSettingsLocally(gParsed);
              return gParsed;
            }
          }
        }
      } catch (_) {}
    }

    // 3. Coba ambil dari Firebase Realtime Database (Cross-Device Guarantee)
    try {
      final rtdbUri = Uri.parse('$rtdbBaseUrl/$collectionName/$docId.json');
      final rtdbRes = await http.get(rtdbUri).timeout(const Duration(seconds: 3));
      if (rtdbRes.statusCode == 200 && rtdbRes.body != 'null' && rtdbRes.body.isNotEmpty) {
        final rtdbData = jsonDecode(rtdbRes.body) as Map<String, dynamic>;
        if (rtdbData.isNotEmpty && rtdbData['smtp_user'] != null) {
          debugPrint('[FirebaseEmailService] 📥 Berhasil memuat SMTP config dari Firebase RTDB: $docId');
          _cacheSettingsLocally(rtdbData);
          return rtdbData;
        }
      }
    } catch (_) {}

    // Fallback RTDB: coba ambil global_config jika query awal bukan global_config
    if (docId != globalDocId) {
      try {
        final globalRtdbUri = Uri.parse('$rtdbBaseUrl/$collectionName/$globalDocId.json');
        final gRes = await http.get(globalRtdbUri).timeout(const Duration(seconds: 3));
        if (gRes.statusCode == 200 && gRes.body != 'null' && gRes.body.isNotEmpty) {
          final gData = jsonDecode(gRes.body) as Map<String, dynamic>;
          if (gData.isNotEmpty && gData['smtp_user'] != null) {
            debugPrint('[FirebaseEmailService] 📥 Berhasil memuat SMTP config global dari Firebase RTDB');
            _cacheSettingsLocally(gData);
            return gData;
          }
        }
      } catch (_) {}
    }

    // Fallback RTDB: ambil record email_settings apapun yang tersedia di database
    try {
      final allRtdbUri = Uri.parse('$rtdbBaseUrl/$collectionName.json');
      final allRes = await http.get(allRtdbUri).timeout(const Duration(seconds: 3));
      if (allRes.statusCode == 200 && allRes.body != 'null' && allRes.body.isNotEmpty) {
        final allData = jsonDecode(allRes.body);
        if (allData is Map<String, dynamic>) {
          for (final entry in allData.values) {
            if (entry is Map<String, dynamic> && entry['smtp_user'] != null) {
              debugPrint('[FirebaseEmailService] 📥 Memuat SMTP config fallback dari node RTDB: ${entry['smtp_user']}');
              _cacheSettingsLocally(entry);
              return entry;
            }
          }
        }
      }
    } catch (_) {}

    // 4. Fallback ke Database SQLite Lokal
    try {
      final dbData = await DatabaseHelper.instance.getEmailSettings(userEmail: userEmail) ??
          await DatabaseHelper.instance.getEmailSettings();
      if (dbData != null && dbData.isNotEmpty) {
        return dbData;
      }
    } catch (_) {}

    // 5. Fallback ke SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final smtpUser = prefs.getString('smtp_user');
      if (smtpUser != null && smtpUser.isNotEmpty) {
        return {
          'smtp_user': smtpUser,
          'smtp_pass': prefs.getString('smtp_pass') ?? '',
          'smtp_host': prefs.getString('smtp_host') ?? 'smtp.gmail.com',
          'smtp_port': prefs.getInt('smtp_port') ?? 465,
          'updated_at': prefs.getString('smtp_updated_at') ?? DateTime.now().toIso8601String(),
        };
      }
    } catch (_) {}

    return null;
  }

  /// Sinkronisasi konfigurasi dari Cloud Database ke SQLite lokal dan SharedPreferences
  Future<void> syncEmailSettings() async {
    try {
      final settings = await getEmailSettings();
      if (settings != null && settings['smtp_user'] != null) {
        final smtpUser = settings['smtp_user'].toString();
        _cacheSettingsLocally(settings, writeToDb: true);
        debugPrint('[FirebaseEmailService] 🔄 Sinkronisasi email settings dari Cloud berhasil: $smtpUser');
      }
    } catch (e) {
      debugPrint('[FirebaseEmailService] Sinkronisasi email settings info: $e');
    }
  }

  /// Cache data ke SharedPreferences dan SQLite secara background
  void _cacheSettingsLocally(Map<String, dynamic> data, {bool writeToDb = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final smtpUser = data['smtp_user']?.toString();
      final smtpPass = data['smtp_pass']?.toString() ?? '';
      final smtpHost = data['smtp_host']?.toString() ?? 'smtp.gmail.com';
      final smtpPort = (data['smtp_port'] as num?)?.toInt() ?? 465;
      final updatedAt = data['updated_at']?.toString() ?? DateTime.now().toIso8601String();
      final userEmail = data['user_email']?.toString();

      if (smtpUser != null && smtpUser.isNotEmpty) {
        await prefs.setString('smtp_user', smtpUser);
        await prefs.setString('smtp_pass', smtpPass);
        await prefs.setString('smtp_host', smtpHost);
        await prefs.setInt('smtp_port', smtpPort);
        await prefs.setString('smtp_updated_at', updatedAt);

        if (writeToDb) {
          try {
            await DatabaseHelper.instance.saveEmailSettings(
              smtpUser: smtpUser,
              smtpPass: smtpPass,
              smtpHost: smtpHost,
              smtpPort: smtpPort,
              userEmail: userEmail,
              syncToCloud: false,
            );
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
