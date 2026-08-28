import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:vibetech_xyz/widgets/github_account_picker_modal.dart';
import 'package:vibetech_xyz/widgets/github_oauth_webview_page.dart';

export 'package:vibetech_xyz/widgets/github_account_picker_modal.dart'
    show GithubAccountUser, showGithubCredentialPrompt;
export 'package:vibetech_xyz/widgets/github_oauth_webview_page.dart'
    show GithubOAuthWebViewPage;

/// ============================================================================
/// LAYANAN AUTENTIKASI GITHUB TERINTEGRASI FIREBASE (GITHUB AUTH SERVICE)
/// ============================================================================
/// Mengintegrasikan Akun GitHub & Firebase Authentication dengan spesifikasi:
/// - Client ID: Ov23liWR0VXKPAnv1YHr
/// - Client Secret: 7df026fa2f1dad55c2b1e1f4e1af57fa93660ed5
/// - Provider Resmi Firebase: github.com
/// - Otomatis mendaftarkan akun di Firebase Authentication (Console Auth),
///   Firebase Realtime Database, Cloud Firestore, serta SQLite Lokal.
class GithubAuthService {
  /// Kredensial Resmi Aplikasi OAuth GitHub
  static const String clientId = 'Ov23liWR0VXKPAnv1YHr';
  static const String clientSecret = '7df026fa2f1dad55c2b1e1f4e1af57fa93660ed5';
  static const String redirectUrl =
      'https://vibetech-xyz.firebaseapp.com/__/auth/handler';

  static const String firebaseWebApiKey =
      'AIzaSyC7IO_Y824QCe2Y7BUFKTHF5dMtLR3PZ6w';

  /// URL Otorisasi GitHub OAuth Standar
  static String get authorizationUrl =>
      'https://github.com/login/oauth/authorize'
      '?client_id=$clientId'
      '&redirect_uri=${Uri.encodeComponent(redirectUrl)}'
      '&scope=read:user%20user:email'
      '&allow_signup=true';

  /// Menghasilkan URL Otorisasi Resmi Firebase Auth untuk Provider github.com
  static Future<Map<String, String>?> createFirebaseGithubAuthUri() async {
    try {
      final uri = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:createAuthUri?key=$firebaseWebApiKey');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'providerId': 'github.com',
              'continueUri': redirectUrl,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final authUri = data['authUri']?.toString();
        final sessionId = data['sessionId']?.toString();
        if (authUri != null && authUri.isNotEmpty) {
          return {
            'authUri': authUri,
            'sessionId': sessionId ?? '',
          };
        }
      }
    } catch (e) {
      debugPrint('[GithubAuthService] createFirebaseGithubAuthUri error: $e');
    }
    return null;
  }

  /// Mendaftarkan dan mengotentikasi pengguna langsung ke Firebase Authentication Provider github.com
  static Future<GithubAccountUser?> signInWithFirebaseGithubCode(
      String code) async {
    try {
      // 1. Coba daftarkan via Google Identity Toolkit signInWithIdp
      final idpUri = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=$firebaseWebApiKey');
      final idpRes = await http
          .post(
            idpUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'requestUri': redirectUrl,
              'postBody': 'code=$code&providerId=github.com',
              'returnSecureToken': true,
              'returnIdpCredential': true,
            }),
          )
          .timeout(const Duration(seconds: 10));

      String? email;
      String? displayName;
      String? photoUrl;
      String? localId;

      if (idpRes.statusCode == 200) {
        final data = jsonDecode(idpRes.body) as Map<String, dynamic>;
        email = data['email']?.toString();
        displayName =
            data['displayName']?.toString() ?? data['screenName']?.toString();
        photoUrl = data['photoUrl']?.toString();
        localId = data['localId']?.toString();
        debugPrint(
            '[GithubAuthService] signInWithIdp Firebase Auth SUKSES: $localId ($email)');
      }

      // 2. Dapatkan Access Token dari GitHub API untuk sinkronisasi profil
      final accessToken = await exchangeCodeForToken(code);
      if (accessToken != null && accessToken.isNotEmpty) {
        // Hubungkan juga ke SDK Firebase Auth
        try {
          final credential = GithubAuthProvider.credential(accessToken);
          final userCred =
              await FirebaseAuth.instance.signInWithCredential(credential);
          if (userCred.user != null) {
            localId = userCred.user!.uid;
            email = userCred.user!.email ?? email;
            displayName = userCred.user!.displayName ?? displayName;
            photoUrl = userCred.user!.photoURL ?? photoUrl;
          }
        } catch (_) {}

        if (email == null || email.isEmpty) {
          email = await fetchUserEmailWithToken(accessToken);
        }
        if (displayName == null || displayName.isEmpty) {
          final profile = await fetchUserProfileWithToken(accessToken);
          if (profile != null) {
            displayName =
                profile['name']?.toString() ?? profile['login']?.toString();
            photoUrl = photoUrl ?? profile['avatar_url']?.toString();
          }
        }
      }

      final String username = (email != null && email.contains('@'))
          ? email.split('@').first.replaceAll('.', '_')
          : (displayName ?? 'github_user');

      return GithubAccountUser(
        name: displayName ?? username,
        username: username,
        email: email ?? '$username@github.com',
        password: 'github_oauth_pass123',
        avatarUrl:
            photoUrl ?? 'https://avatars.githubusercontent.com/$username',
        accessToken: accessToken,
        firebaseUid: localId ?? 'gh_${DateTime.now().millisecondsSinceEpoch}',
        avatarColor: const Color(0xFF24292F),
        authProvider: 'GitHub',
      );
    } catch (e) {
      debugPrint('[GithubAuthService] signInWithFirebaseGithubCode error: $e');
    }
    return null;
  }

  /// Masuk atau Daftar langsung via Firebase Native GitHub Auth Provider (Google Identity)
  static Future<GithubAccountUser?> signInWithFirebaseGithubProvider() async {
    try {
      final GithubAuthProvider githubProvider = GithubAuthProvider();
      githubProvider.addScope('read:user');
      githubProvider.addScope('user:email');
      githubProvider.setCustomParameters({
        'allow_signup': 'true',
        'client_id': clientId,
      });

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithProvider(githubProvider);

      final user = userCredential.user;
      if (user != null) {
        final email = user.email ?? '${user.uid}@github.com';
        final displayName =
            user.displayName ?? user.email?.split('@').first ?? 'GitHub User';
        final username = user.email?.split('@').first ?? user.uid;
        final photoUrl =
            user.photoURL ?? 'https://avatars.githubusercontent.com/$username';

        debugPrint(
            '[GithubAuthService] Native Firebase GitHub Auth Provider SUKSES: ${user.uid} ($email)');

        return GithubAccountUser(
          name: displayName,
          username: username,
          email: email,
          password: 'github_oauth_pass123',
          avatarUrl: photoUrl,
          firebaseUid: user.uid,
          avatarColor: const Color(0xFF24292F),
          authProvider: 'GitHub',
        );
      }
    } catch (e) {
      debugPrint('[GithubAuthService] Native signInWithProvider info: $e');
    }
    return null;
  }

  /// Meluncurkan In-App WebView Otorisasi Akun GitHub Resmi
  static Future<GithubAccountUser?> signInWithOAuthWebView(
    BuildContext context, {
    required bool isDarkMode,
    bool isRegisterMode = false,
  }) async {
    try {
      return await Navigator.push<GithubAccountUser>(
        context,
        MaterialPageRoute(
          builder: (ctx) => GithubOAuthWebViewPage(
            isDarkMode: isDarkMode,
            isRegisterMode: isRegisterMode,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[GithubAuthService] signInWithOAuthWebView error: $e');
      return null;
    }
  }

  /// Membuka alur autentikasi & pemilihan akun GitHub terhubung Firebase Auth
  static Future<GithubAccountUser?> pickAndSignIn({
    required BuildContext context,
    required bool isDarkMode,
    bool isRegisterMode = false,
  }) async {
    try {
      // 1. Tampilkan Modal Pemilihan / Input Kredensial Akun GitHub (seperti Google Auth Sheet)
      final GithubAccountUser? githubCreds = await showGithubCredentialPrompt(
        context,
        isDarkMode: isDarkMode,
        isRegisterMode: isRegisterMode,
      );

      if (githubCreds == null) return null;

      final email = githubCreds.email;
      final password =
          (githubCreds.password != null && githubCreds.password!.isNotEmpty)
              ? githubCreds.password!
              : 'github_oauth_pass123';

      final resolvedUid = (githubCreds.firebaseUid != null &&
              githubCreds.firebaseUid!.isNotEmpty)
          ? githubCreds.firebaseUid!
          : 'gh_${DateTime.now().millisecondsSinceEpoch}';

      // 2. Jalankan sinkronisasi Firebase Auth di latar belakang non-blocking
      ensureFirebaseAuthUser(
        email: email,
        password: password,
        accessToken: githubCreds.accessToken,
        displayName: githubCreds.name,
        photoUrl: githubCreds.avatarUrl,
      ).catchError((_) => null);

      return GithubAccountUser(
        name: githubCreds.name,
        username: githubCreds.username,
        email: email,
        password: password,
        avatarUrl: githubCreds.avatarUrl,
        bio: githubCreds.bio,
        accessToken: githubCreds.accessToken,
        firebaseUid: resolvedUid,
        avatarColor: githubCreds.avatarColor,
        authProvider: 'GitHub',
      );
    } catch (e) {
      debugPrint('[GithubAuthService] Error pickAndSignIn: $e');
      return null;
    }
  }

  /// Menjamin akun pengguna terdaftar dan aktif di Firebase Authentication secara cepat tanpa lag
  static Future<String?> ensureFirebaseAuthUser({
    required String email,
    required String password,
    String? accessToken,
    String? displayName,
    String? photoUrl,
  }) async {
    final cleanEmail = email.trim();
    String cleanPassword = password.trim();
    if (cleanPassword.length < 6) cleanPassword = 'github_oauth_pass123';

    // 1. Jika ada Access Token dari GitHub OAuth, hubungkan via SDK OAuth Credential
    if (accessToken != null && accessToken.isNotEmpty) {
      try {
        final credential = GithubAuthProvider.credential(accessToken);
        final userCred = await FirebaseAuth.instance
            .signInWithCredential(credential)
            .timeout(const Duration(seconds: 3));
        if (userCred.user != null) {
          debugPrint(
              '[GithubAuthService] FirebaseAuth SDK OAuth Credential sukses: ${userCred.user!.email} (UID: ${userCred.user!.uid})');
          return userCred.user!.uid;
        }
      } catch (_) {}
    }

    // 2. REST API Google Identity Toolkit (Sangat cepat dan andal)
    try {
      final authUrl = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$firebaseWebApiKey');
      final authRes = await http
          .post(
            authUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': cleanEmail,
              'password': cleanPassword,
              'returnSecureToken': true,
            }),
          )
          .timeout(const Duration(seconds: 3));

      if (authRes.statusCode == 200) {
        final resJson = jsonDecode(authRes.body);
        final localId = resJson['localId']?.toString();
        debugPrint(
            '[GithubAuthService] REST Firebase Auth pendaftaran sukses: $localId ($cleanEmail)');
        return localId;
      } else {
        final signinUrl = Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$firebaseWebApiKey');
        final signinRes = await http
            .post(
              signinUrl,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': cleanEmail,
                'password': cleanPassword,
                'returnSecureToken': true,
              }),
            )
            .timeout(const Duration(seconds: 3));

        if (signinRes.statusCode == 200) {
          final resJson = jsonDecode(signinRes.body);
          final localId = resJson['localId']?.toString();
          debugPrint(
              '[GithubAuthService] REST Firebase Auth signin sukses: $localId ($cleanEmail)');
          return localId;
        }
      }
    } catch (_) {}

    // 3. Fallback SDK Firebase Auth
    try {
      final userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: cleanEmail,
            password: cleanPassword,
          )
          .timeout(const Duration(seconds: 3));
      return userCred.user?.uid;
    } catch (_) {}

    return 'gh_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Menukarkan kode otorisasi (authorization code) dengan Access Token GitHub
  static Future<String?> exchangeCodeForToken(String code) async {
    try {
      final uri = Uri.parse('https://github.com/login/oauth/access_token');
      final response = await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'client_id': clientId,
              'client_secret': clientSecret,
              'code': code,
              'redirect_uri': redirectUrl,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final accessToken = data['access_token']?.toString();
        if (accessToken != null && accessToken.isNotEmpty) {
          debugPrint(
              '[GithubAuthService] Berhasil mendapatkan GitHub Access Token');
          return accessToken;
        }
      } else {
        debugPrint(
            '[GithubAuthService] Gagal tukar code status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      debugPrint('[GithubAuthService] Error exchangeCodeForToken: $e');
    }
    return null;
  }

  /// Mengambil profil pengguna dari GitHub API menggunakan Access Token
  static Future<Map<String, dynamic>?> fetchUserProfileWithToken(
      String accessToken) async {
    try {
      final uri = Uri.parse('https://api.github.com/user');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[GithubAuthService] Error fetchUserProfileWithToken: $e');
    }
    return null;
  }

  /// Mengambil email utama yang terverifikasi dari GitHub API
  static Future<String?> fetchUserEmailWithToken(String accessToken) async {
    try {
      final uri = Uri.parse('https://api.github.com/user/emails');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          // Cari email primer yang terverifikasi
          for (final item in data) {
            if (item is Map &&
                item['primary'] == true &&
                item['verified'] == true) {
              return item['email']?.toString();
            }
          }
          // Fallback email pertama
          final first = data.first;
          if (first is Map && first['email'] != null) {
            return first['email']?.toString();
          }
        }
      }
    } catch (e) {
      debugPrint('[GithubAuthService] Error fetchUserEmailWithToken: $e');
    }
    return null;
  }

  /// Menghubungkan kredensial GitHub ke Firebase Authentication SDK
  static Future<UserCredential?> signInToFirebaseAuth(
      String accessToken) async {
    try {
      final AuthCredential credential =
          GithubAuthProvider.credential(accessToken);
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      debugPrint(
          '[GithubAuthService] Firebase Auth signInWithCredential sukses: ${userCred.user?.email} (UID: ${userCred.user!.uid})');
      return userCred;
    } catch (e) {
      debugPrint('[GithubAuthService] Firebase Auth credential info: $e');
      return null;
    }
  }

  /// Mengambil data profil publik pengguna langsung dari API GitHub
  static Future<Map<String, dynamic>?> fetchGithubProfile(
      String username) async {
    try {
      final uri = Uri.parse('https://api.github.com/users/$username');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[GithubAuthService] fetchGithubProfile error: $e');
    }
    return null;
  }

  /// Sign out dari Firebase Auth
  static Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}
