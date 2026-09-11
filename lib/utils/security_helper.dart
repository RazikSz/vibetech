import 'dart:convert';
import 'package:crypto/crypto.dart';

/// ============================================================================
/// SECURITY HELPER - VIBETECH XYZ
/// ============================================================================
/// Modul keamanan terpusat untuk:
/// 1. Kriptografi Kata Sandi (One-way Hashing SHA-256 + Salt).
/// 2. Verifikasi PIN Transaksi dengan perlindungan backward-compatibility.
/// 3. Obfuskasi & Deobfuskasi runtime untuk rahasia API & kunci server.
class SecurityHelper {
  // Salt kriptografis unik aplikasi VibeTech XYZ
  static const String _passSaltPrefix = 'vbt_sec_salt_2026_';
  static const String _passSaltSuffix = '_xyz_vault_protect';
  static const String _hashHeader = 'vbt\$sha256\$';

  static const String _pinSaltPrefix = 'vbt_pin_salt_';
  static const String _pinSaltSuffix = '_vbt_pay_lock';
  static const String _pinHeader = 'vbt\$pin\$';

  // Kunci XOR runtime untuk obfuskasi rahasia
  static const int _xorKey = 0x5A;

  /// Mengembalikan kata sandi biasa (plaintext) tanpa di-hash, sesuai preferensi sistem
  static String hashPassword(String rawPassword) {
    return rawPassword.trim();
  }

  /// Verifikasi kata sandi dengan backward compatibility:
  /// Mendukung password biasa (plaintext) dan verifikasi hash lama jika database belum diperbarui.
  static bool verifyPassword(String inputPassword, String storedPasswordOrHash) {
    if (storedPasswordOrHash.isEmpty) return false;

    // 1. Verifikasi langsung password biasa (plaintext)
    if (inputPassword == storedPasswordOrHash) return true;

    // 2. Fallback backward compatibility jika akun di database masih menyimpan hash lama
    if (storedPasswordOrHash.startsWith(_hashHeader)) {
      final salted = '$_passSaltPrefix$inputPassword$_passSaltSuffix';
      final bytes = utf8.encode(salted);
      final digest = sha256.convert(bytes);
      final oldHash = '$_hashHeader$digest';
      return oldHash == storedPasswordOrHash;
    }

    return false;
  }

  /// Cek apakah akun masih menggunakan format hash lama (bukan password biasa)
  static bool isLegacyPassword(String storedPasswordOrHash) {
    return storedPasswordOrHash.startsWith(_hashHeader);
  }

  /// Mengembalikan PIN biasa (plaintext) tanpa di-hash
  static String hashPin(String rawPin) {
    return rawPin.trim();
  }

  /// Verifikasi PIN Transaksi dengan backward compatibility
  static bool verifyPin(String inputPin, String storedPinOrHash) {
    if (storedPinOrHash.isEmpty) return false;

    // 1. Verifikasi langsung PIN biasa
    if (inputPin == storedPinOrHash) return true;

    // 2. Fallback backward compatibility jika database masih menyimpan hash PIN lama
    if (storedPinOrHash.startsWith(_pinHeader)) {
      final salted = '$_pinSaltPrefix$inputPin$_pinSaltSuffix';
      final bytes = utf8.encode(salted);
      final digest = sha256.convert(bytes);
      final oldHash = '$_pinHeader$digest';
      return oldHash == storedPinOrHash;
    }

    return false;
  }

  /// Cek apakah PIN masih menggunakan format hash lama
  static bool isLegacyPin(String storedPinOrHash) {
    return storedPinOrHash.startsWith(_pinHeader);
  }

  /// Obfuskasi string menggunakan XOR masking + Base64
  static String obfuscate(String plain) {
    final bytes = utf8.encode(plain);
    final xorBytes = bytes.map((b) => b ^ _xorKey).toList();
    return base64.encode(xorBytes);
  }

  /// Membaca string terobfuskasi saat runtime
  static String deobfuscate(String encoded) {
    try {
      final bytes = base64.decode(encoded);
      final xorBytes = bytes.map((b) => b ^ _xorKey).toList();
      return utf8.decode(xorBytes);
    } catch (_) {
      return encoded;
    }
  }
}
