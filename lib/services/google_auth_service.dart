import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:vibetech_xyz/services/language_service.dart';

/// ============================================================================
/// MODEL DATA PENGGUNA GOOGLE
/// ============================================================================
class GoogleAccountUser {
  final String name;
  final String email;
  final String? avatarUrl;
  final Color avatarColor;

  const GoogleAccountUser({
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.avatarColor,
  });
}

/// ============================================================================
/// LAYANAN AUTENTIKASI RESMI GOOGLE (OFFICIAL GOOGLE SIGN-IN SERVICE)
/// ============================================================================
/// HANYA menggunakan dialog native resmi Google Play Services / Google OAuth.
/// Tidak menggunakan pemilih akun custom / bottom sheet modal kustom.
class GoogleAuthService {
  /// Web Client ID resmi Firebase / Google Cloud untuk otentikasi Google Sign-In & Firebase Auth
  static const String serverClientId =
      '567350641192-na1ceptefqbtf0j8v1aicsfif1lvupn8.apps.googleusercontent.com';

  /// Instance Google Sign-In resmi dengan serverClientId untuk integrasi token Firebase Auth
  static final GoogleSignIn _googleSignInWithServer = GoogleSignIn(
    serverClientId: serverClientId,
    scopes: ['email', 'profile'],
  );

  /// Instance Google Sign-In native standar (fallback konfigurasi google-services.json)
  static final GoogleSignIn _googleSignInNative = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Masuk HANYA menggunakan dialog pemilih akun resmi Google Play Services dari sistem perangkat.
  static Future<GoogleAccountUser?> signIn({
    required BuildContext context,
    required bool isDarkMode,
    bool isRegisterMode = false,
  }) async {
    try {
      // 1. Reset sesi akun terlebih dahulu agar dialog resmi Google SELALU muncul untuk memilih akun
      try {
        await _googleSignInWithServer.signOut();
      } catch (_) {}
      try {
        await _googleSignInNative.signOut();
      } catch (_) {}

      GoogleSignInAccount? googleUser;

      // 2. Buka dialog pemilih akun resmi Google dari Google Play Services sistem
      try {
        googleUser = await _googleSignInWithServer.signIn();
      } catch (e) {
        debugPrint('[GoogleAuthService] ServerClientId signIn error: $e');
        try {
          googleUser = await _googleSignInNative.signIn();
        } catch (e2) {
          debugPrint('[GoogleAuthService] Native signIn error: $e2');
          rethrow;
        }
      }

      // Pengguna membatalkan dialog resmi Google (klik tombol back / di luar dialog)
      if (googleUser == null) {
        return null;
      }

      // 3. Hubungkan kredensial Google ke Firebase Auth (Best-effort / opsional)
      try {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        if (googleAuth.idToken != null || googleAuth.accessToken != null) {
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await FirebaseAuth.instance.signInWithCredential(credential);
          debugPrint(
              '[GoogleAuthService] FirebaseAuth signInWithCredential sukses: ${googleUser.email}');
        }
      } catch (authErr) {
        debugPrint('[GoogleAuthService] FirebaseAuth sync info: $authErr');
      }

      final String displayName = (googleUser.displayName != null &&
              googleUser.displayName!.trim().isNotEmpty)
          ? googleUser.displayName!
          : googleUser.email.split('@').first;

      return GoogleAccountUser(
        name: displayName,
        email: googleUser.email,
        avatarUrl: googleUser.photoUrl,
        avatarColor: const Color(0xFF4285F4),
      );
    } catch (e) {
      debugPrint('[GoogleAuthService] Google Sign-In Native error: $e');

      final errStr = e.toString().toLowerCase();

      // Pengguna membatalkan dialog resmi Google
      if (errStr.contains('sign_in_canceled') ||
          errStr.contains('canceled') ||
          errStr.contains('cancelled')) {
        return null;
      }

      // Tampilkan notifikasi jika ada kendala teknis (tanpa membuka picker kustom)
      if (context.mounted) {
        String msg = LanguageService.text(
          'Gagal menghubungkan Google. Pastikan perangkat Anda terhubung ke internet dan coba lagi.',
          'Failed to connect to Google. Please ensure your device is connected to the internet and try again.',
        );

        if (errStr.contains('network') || errStr.contains('apiexception: 7')) {
          msg = LanguageService.text(
            'Koneksi internet terputus. Silakan periksa jaringan internet Anda.',
            'Internet connection lost. Please check your network connection.',
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    msg,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return null;
    }
  }

  /// Alias pickAndSignIn mengarahkan langsung ke signIn resmi Google
  static Future<GoogleAccountUser?> pickAndSignIn({
    required BuildContext context,
    required bool isDarkMode,
    bool isRegisterMode = false,
  }) async {
    return await signIn(
      context: context,
      isDarkMode: isDarkMode,
      isRegisterMode: isRegisterMode,
    );
  }

  /// Sign out dari sesi Google
  static Future<void> signOut() async {
    try {
      await _googleSignInWithServer.signOut();
    } catch (_) {}
    try {
      await _googleSignInNative.signOut();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}
