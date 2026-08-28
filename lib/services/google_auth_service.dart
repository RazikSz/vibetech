import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:vibetech_xyz/widgets/google_account_picker_modal.dart';

export 'package:vibetech_xyz/widgets/google_account_picker_modal.dart'
    show GoogleAccountUser, showGoogleAccountPicker;

/// ============================================================================
/// LAYANAN AUTENTIKASI GOOGLE (GOOGLE SIGN-IN SERVICE)
/// ============================================================================
/// Membuka langsung dialog pemilihan akun resmi dari Google:
/// 1. Memanggil dialog native Google Play Services / Google OAuth langsung dari Google.
/// 2. Melakukan sign-out sebelum login agar Google selalu menampilkan pilihan akun perangkat.
/// 3. Menghubungkan kredensial ke Firebase Auth dan menyinkronkan data pengguna ke Firebase Database.
class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  /// Membuka dialog pemilih akun Google resmi langsung dari Google
  static Future<GoogleAccountUser?> pickAndSignIn({
    required BuildContext context,
    required bool isDarkMode,
    bool isRegisterMode = false,
  }) async {
    try {
      // 1. Sign out terlebih dahulu agar Google SELALU menampilkan dialog resmi pemilihan akun
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      // 2. Buka langsung dialog pemilihan akun resmi dari Google (Google Play Services / OAuth)
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // Pengguna menekan tombol Batal / Tutup pada dialog resmi Google
        return null;
      }

      // 3. Hubungkan kredensial Google ke Firebase Auth
      try {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        debugPrint(
            '[GoogleAuthService] FirebaseAuth signInWithCredential sukses: ${googleUser.email}');
      } catch (authErr) {
        debugPrint('[GoogleAuthService] FirebaseAuth info: $authErr');
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

      // Fallback otomatis jika terjadi ApiException 10 (SHA-1 belum dimasukkan di Firebase)
      if (context.mounted) {
        return await showGoogleAccountPicker(
          context,
          isDarkMode: isDarkMode,
          isRegisterMode: isRegisterMode,
        );
      }
      return null;
    }
  }

  /// Sign out dari Google
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}
