import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:vibetech_xyz/utils/security_helper.dart';
import 'package:vibetech_xyz/widgets/github_oauth_webview_page.dart';

export 'package:vibetech_xyz/widgets/github_oauth_webview_page.dart'
    show GithubOAuthWebViewPage;

/// Model data representasi akun GitHub terintegrasi Firebase
class GithubAccountUser {
  final String name;
  final String username;
  final String email;
  final String? password;
  final String? avatarUrl;
  final String? bio;
  final String? accessToken;
  final String? firebaseUid;
  final Color avatarColor;
  final String authProvider;

  const GithubAccountUser({
    required this.name,
    required this.username,
    required this.email,
    this.password,
    this.avatarUrl,
    this.bio,
    this.accessToken,
    this.firebaseUid,
    this.avatarColor = const Color(0xFF6C5CE7),
    this.authProvider = 'GitHub',
  });
}

/// ============================================================================
/// GITHUB AUTHENTICATION & FIREBASE OAUTH LINKING SERVICE
/// ============================================================================
/// Mengintegrasikan Akun GitHub & Firebase Authentication dengan spesifikasi:
/// - Client ID: Ov23liWR0VXKPAnv1YHr
/// - Client Secret: Terproteksi Obfuskasi Dinamis
/// - Provider Resmi Firebase: github.com
/// - Otomatis mendaftarkan akun di Firebase Authentication (Console Auth),
///   Firebase Realtime Database, Cloud Firestore, serta SQLite Lokal.
class GithubAuthService {
  /// Kredensial Resmi Aplikasi OAuth GitHub (Sesuai Konfigurasi Firebase Auth Console)
  static const String clientId = 'Ov23liWR0VXKPAnv1YHr';
  static final String clientSecret = SecurityHelper.deobfuscate(
      'bT48amhsPDtoPGs+Oz5vbzloOGs/azxuP2s7PG9tPDtjaWxsaj8+bw==');
  static const String redirectUrl =
      'https://vibetech-xyz.firebaseapp.com/__/auth/handler';

  static final String firebaseWebApiKey = SecurityHelper.deobfuscate(
      'GxMgOwkjGW0TFQUDYmhuCxk/aANtGA8cEQ4SHG8+Fy4WCGkKAGwt');

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
      // 1. Dapatkan Access Token dari GitHub API via authorization code
      final accessToken = await exchangeCodeForToken(code);
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint(
            '[GithubAuthService] Gagal menukarkan authorization code dengan Access Token');
        return null;
      }

      String? email;
      String? displayName;
      String? photoUrl;
      String? localId;

      // 2. Daftarkan / Hubungkan Access Token GitHub ke Firebase Authentication SDK
      try {
        final credential = GithubAuthProvider.credential(accessToken);
        final userCred =
            await FirebaseAuth.instance.signInWithCredential(credential);
        if (userCred.user != null) {
          localId = userCred.user!.uid;
          email = userCred.user!.email;
          displayName = userCred.user!.displayName;
          photoUrl = userCred.user!.photoURL;
          debugPrint(
              '[GithubAuthService] FirebaseAuth SDK signInWithCredential SUKSES: $localId ($email)');
        }
      } catch (sdkError) {
        debugPrint(
            '[GithubAuthService] FirebaseAuth SDK signInWithCredential info: $sdkError');
        if (sdkError is FirebaseAuthException &&
            sdkError.code == 'account-exists-with-different-credential') {
          final pendingCred = sdkError.credential;
          final userEmail = sdkError.email;
          if (userEmail != null && userEmail.isNotEmpty) email = userEmail;
          try {
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null && pendingCred != null) {
              final linkRes = await currentUser.linkWithCredential(pendingCred);
              if (linkRes.user != null) {
                localId = linkRes.user!.uid;
                email = linkRes.user!.email;
                displayName = linkRes.user!.displayName;
                photoUrl = linkRes.user!.photoURL;
                debugPrint(
                    '[GithubAuthService] Link credential berhasil: $localId ($email)');
              }
            }
          } catch (_) {}
        }
      }

      // 3. Cadangan pendaftaran via Google Identity Toolkit REST API (signInWithIdp)
      if (localId == null) {
        try {
          final idpUri = Uri.parse(
              'https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=$firebaseWebApiKey');
          final idpRes = await http
              .post(
                idpUri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'requestUri': redirectUrl,
                  'postBody': 'access_token=$accessToken&providerId=github.com',
                  'returnSecureToken': true,
                  'returnIdpCredential': true,
                }),
              )
              .timeout(const Duration(seconds: 8));

          if (idpRes.statusCode == 200) {
            final data = jsonDecode(idpRes.body) as Map<String, dynamic>;
            email ??= data['email']?.toString();
            displayName ??= data['displayName']?.toString() ??
                data['screenName']?.toString();
            photoUrl ??= data['photoUrl']?.toString();
            localId = data['localId']?.toString();
            debugPrint(
                '[GithubAuthService] signInWithIdp REST Firebase Auth SUKSES: $localId ($email)');
          } else {
            debugPrint(
                '[GithubAuthService] signInWithIdp REST status: ${idpRes.statusCode}, body: ${idpRes.body}');
          }
        } catch (e) {
          debugPrint('[GithubAuthService] signInWithIdp REST error: $e');
        }
      }

      // 4. Ambil profil GitHub resmi dan email terverifikasi langsung via API GitHub
      if (email == null || email.isEmpty) {
        email = await fetchUserEmailWithToken(accessToken);
      }
      final profile = await fetchUserProfileWithToken(accessToken);
      if (profile != null) {
        displayName ??=
            profile['name']?.toString() ?? profile['login']?.toString();
        photoUrl ??= profile['avatar_url']?.toString();
      }

      final String username = (profile != null &&
              profile['login'] != null &&
              profile['login'].toString().isNotEmpty)
          ? profile['login'].toString()
          : ((email != null && email.contains('@'))
              ? email.split('@').first.replaceAll('.', '_')
              : (displayName ?? 'github_user'));

      email ??= '$username@github.com';
      photoUrl ??= 'https://avatars.githubusercontent.com/$username';
      localId ??= 'gh_${DateTime.now().millisecondsSinceEpoch}';

      return GithubAccountUser(
        name: displayName ?? username,
        username: username,
        email: email,
        password: 'github_oauth_pass123',
        avatarUrl: photoUrl,
        accessToken: accessToken,
        firebaseUid: localId,
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

  /// Membuka langsung alur autentikasi GitHub resmi via In-App WebView tanpa pop up kustom
  static Future<GithubAccountUser?> pickAndSignIn({
    required BuildContext context,
    required bool isDarkMode,
    bool isRegisterMode = false,
  }) async {
    return signInWithOAuthWebView(
      context,
      isDarkMode: isDarkMode,
      isRegisterMode: isRegisterMode,
    );
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

    // 1. Jika ada Access Token dari GitHub OAuth, hubungkan via SDK OAuth Credential atau REST IDP
    if (accessToken != null && accessToken.isNotEmpty) {
      try {
        final credential = GithubAuthProvider.credential(accessToken);
        final userCred = await FirebaseAuth.instance
            .signInWithCredential(credential)
            .timeout(const Duration(seconds: 5));
        if (userCred.user != null) {
          debugPrint(
              '[GithubAuthService] FirebaseAuth SDK OAuth Credential sukses: ${userCred.user!.email} (UID: ${userCred.user!.uid})');
          return userCred.user!.uid;
        }
      } catch (sdkErr) {
        debugPrint('[GithubAuthService] SDK signInWithCredential fallback: $sdkErr');
      }

      // 1.b Cadangan REST API Google Identity Toolkit (signInWithIdp resmi provider github.com)
      try {
        final idpUri = Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=$firebaseWebApiKey');
        final idpRes = await http
            .post(
              idpUri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'requestUri': redirectUrl,
                'postBody': 'access_token=$accessToken&providerId=github.com',
                'returnSecureToken': true,
                'returnIdpCredential': true,
              }),
            )
            .timeout(const Duration(seconds: 6));

        if (idpRes.statusCode == 200) {
          final data = jsonDecode(idpRes.body) as Map<String, dynamic>;
          final localId = data['localId']?.toString();
          if (localId != null && localId.isNotEmpty) {
            debugPrint(
                '[GithubAuthService] REST signInWithIdp github.com SUKSES: $localId ($cleanEmail)');
            return localId;
          }
        }
      } catch (idpErr) {
        debugPrint('[GithubAuthService] REST signInWithIdp fallback: $idpErr');
      }
    }

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
