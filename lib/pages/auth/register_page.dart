import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibetech_xyz/constants/constants.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/firebase_user_service.dart';
import 'package:vibetech_xyz/services/github_auth_service.dart';
import 'package:vibetech_xyz/services/google_auth_service.dart';
import 'package:vibetech_xyz/services/language_service.dart';
import 'package:vibetech_xyz/services/notification_service.dart';
import 'package:vibetech_xyz/services/theme_service.dart';

import 'login_page.dart';

/// ============================================================================
/// HALAMAN DAFTAR AKUN BARU (REGISTER PAGE) - VIBETECH XYZ
/// ============================================================================
/// Fitur Utama:
/// 1. Desain Cyber Glassmorphism sinkron 100% dengan Login Page & Dashboard.
/// 2. Mode Gelap & Terang dinamis dengan partikel ambient neon di mode gelap.
/// 3. Formulir pendaftaran akun lengkap + PIN Pembayaran (6 Digit Angka).
/// 4. Layout anti-overflow di semua ukuran layar dan rasio resolusi HP.
class RegisterPage extends StatefulWidget {
  final bool? isDarkMode;

  const RegisterPage({super.key, this.isDarkMode});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();

  final FocusNode _fullnameFocus = FocusNode();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();
  final FocusNode _pinFocus = FocusNode();
  final FocusNode _confirmPinFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _isLoading = false;
  bool _agreeTerms = false;
  bool _isGooglePressed = false;
  bool _isGithubPressed = false;
  bool _isDarkMode = true;

  // Animation Controllers & Particle System
  late AnimationController _mainAnimationController;
  late AnimationController _pulseController;
  late AnimationController _ringController;
  late AnimationController _particleController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<AppParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _initThemeMode();

    _fullnameFocus.addListener(() => setState(() {}));
    _usernameFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
    _phoneFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    _confirmPasswordFocus.addListener(() => setState(() {}));
    _pinFocus.addListener(() => setState(() {}));
    _confirmPinFocus.addListener(() => setState(() {}));

    // Inisialisasi 24 Partikel Cyber Ambient
    _particles.addAll(AppParticle.generateList(_random, count: 24));

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _particleController.addListener(() {
      AppParticle.updatePositions(_particles);
    });

    _mainAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _mainAnimationController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _mainAnimationController,
          curve: const Interval(0.15, 0.85, curve: Curves.easeOutCubic)),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _mainAnimationController.forward();
  }

  void _initThemeMode() {
    _isDarkMode = widget.isDarkMode ?? ThemeService.isDarkMode;
    ThemeService.themeNotifier.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _isDarkMode = ThemeService.isDarkMode;
      });
    }
  }

  @override
  void dispose() {
    ThemeService.themeNotifier.removeListener(_onThemeChanged);
    _fullnameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _referralController.dispose();

    _fullnameFocus.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _pinFocus.dispose();
    _confirmPinFocus.dispose();

    _mainAnimationController.dispose();
    _pulseController.dispose();
    _ringController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  // --- VALIDASI FORMULIR REGISTRASI ---

  bool _validateForm() {
    if (_fullnameController.text.trim().isEmpty) {
      _showErrorSnackBar(LanguageService.text(
          'Nama lengkap harus diisi!', 'Full name is required!'));
      return false;
    }
    if (_usernameController.text.trim().isEmpty) {
      _showErrorSnackBar(LanguageService.text(
          'Username harus diisi!', 'Username is required!'));
      return false;
    }
    if (_usernameController.text.trim().length < 4) {
      _showErrorSnackBar(LanguageService.text('Username minimal 4 karakter!',
          'Username must be at least 4 characters!'));
      return false;
    }
    if (_emailController.text.trim().isEmpty) {
      _showErrorSnackBar(
          LanguageService.text('Email harus diisi!', 'Email is required!'));
      return false;
    }
    if (!_emailController.text.contains('@')) {
      _showErrorSnackBar(LanguageService.text(
          'Format email tidak valid!', 'Invalid email format!'));
      return false;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showErrorSnackBar(LanguageService.text(
          'Nomor telepon harus diisi!', 'Phone number is required!'));
      return false;
    }
    if (_phoneController.text.trim().length < 10) {
      _showErrorSnackBar(LanguageService.text('Nomor telepon minimal 10 digit!',
          'Phone number must be at least 10 digits!'));
      return false;
    }
    if (_passwordController.text.trim().isEmpty) {
      _showErrorSnackBar(LanguageService.text(
          'Password harus diisi!', 'Password is required!'));
      return false;
    }
    if (_passwordController.text.trim().length < 6) {
      _showErrorSnackBar(LanguageService.text('Password minimal 6 karakter!',
          'Password must be at least 6 characters!'));
      return false;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar(LanguageService.text(
          'Konfirmasi password tidak cocok!',
          'Password confirmation does not match!'));
      return false;
    }
    if (_pinController.text.trim().isEmpty) {
      _showErrorSnackBar(LanguageService.text(
          'PIN Transaksi 6-digit harus diisi!',
          '6-digit Transaction PIN is required!'));
      return false;
    }
    if (_pinController.text.trim().length != 6 ||
        int.tryParse(_pinController.text.trim()) == null) {
      _showErrorSnackBar(LanguageService.text(
          'PIN Transaksi harus berupa 6 digit angka!',
          'Transaction PIN must be 6 numeric digits!'));
      return false;
    }
    if (_pinController.text.trim() != _confirmPinController.text.trim()) {
      _showErrorSnackBar(LanguageService.text(
          'Konfirmasi PIN Transaksi tidak cocok!',
          'Transaction PIN confirmation does not match!'));
      return false;
    }
    if (!_agreeTerms) {
      _showErrorSnackBar(LanguageService.text(
          'Anda harus menyetujui syarat & ketentuan!',
          'You must agree to terms & conditions!'));
      return false;
    }
    return true;
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _register() async {
    if (!_validateForm()) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final String fullname = _fullnameController.text.trim();
      final String username = _usernameController.text.trim();
      final String email = _emailController.text.trim();
      final String uid = 'usr_${DateTime.now().millisecondsSinceEpoch}';
      final String pin = _pinController.text.trim();

      final Map<String, dynamic> newUser = {
        'uid': uid,
        'nama': fullname,
        'username': username,
        'email': email,
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text.trim(),
        'pin': pin,
        'referralCode': _referralController.text.trim(),
        'role': 'user',
        'createdAt': DateTime.now().toIso8601String(),
        'saldo': 0.0,
      };

      // 1. Simpan akun baru ke tabel users SQLite lokal secara INSTAN (<5ms)
      await DatabaseHelper.instance.registerUser(newUser);

      if (!mounted) return;
      setState(() => _isLoading = false);

      // 2. Kirim email aktivasi dan sambutan di latar belakang (non-blocking)
      NotificationService.sendEmailNotification(
        context,
        toEmail: email,
        subject: 'Selamat Datang di VibeTech XYZ! 🚀',
        message:
            'Halo $fullname,\n\nSelamat! Akun VibeTech XYZ Anda ($username) telah berhasil didaftarkan dan aktif.\n\nEmail Akun: $email\nStatus: Terverifikasi & Aktif\nTanggal Daftar: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} WIB\n\nAnda sekarang dapat mulai menyewa Cloud VPS, Bot WhatsApp, dan Panel Hosting dengan mudah dan cepat.',
        category: 'Aktivasi Akun',
        showPopupImmediately: false,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      final Color dialogBg =
          _isDarkMode ? const Color(0xFF0F1426) : Colors.white;
      final Color titleColor =
          _isDarkMode ? Colors.white : const Color(0xFF1E293B);
      final Color descColor =
          _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: dialogBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 56),
                ),
                const SizedBox(height: 16),
                Text(
                  LanguageService.text(
                      'Registrasi Berhasil!', 'Registration Successful!'),
                  style: GoogleFonts.poppins(
                    color: titleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  LanguageService.text(
                    'Akun "$username" dan PIN Keamanan berhasil dibuat di sistem VibeTech XYZ.',
                    'Account "$username" and Security PIN were successfully created in VibeTech XYZ.',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: descColor, fontSize: 12.5),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF7C4DFF).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginPage()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        LanguageService.text('Login Sekarang', 'Login Now'),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      _showErrorSnackBar(LanguageService.text(
        'Email atau Username sudah terdaftar!',
        'Email or Username is already registered!',
      ));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _registerWithGoogle() async {
    HapticFeedback.lightImpact();

    // 1. Tampilkan Google Account Picker dari HP (Native / Fallback)
    final GoogleAccountUser? selectedAccount =
        await GoogleAuthService.pickAndSignIn(
      context: context,
      isDarkMode: _isDarkMode,
      isRegisterMode: true,
    );

    // Pengguna membatalkan dialog
    if (selectedAccount == null) return;

    setState(() => _isLoading = true);
    try {
      final String googleEmail = selectedAccount.email;
      final String googleName = selectedAccount.name;
      final String googleUsername = googleEmail.contains('@')
          ? googleEmail.split('@').first.replaceAll('.', '_')
          : 'google_user_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final String uid = 'goog_${DateTime.now().millisecondsSinceEpoch}';

      // Periksa apakah akun sudah terdaftar
      final existing =
          await DatabaseHelper.instance.getUserByEmail(googleEmail);
      if (existing != null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageService.text(
              'Akun Google "$googleEmail" sudah terdaftar! Silakan langsung login.',
              'Google account "$googleEmail" is already registered! Please login.',
            )),
            backgroundColor: const Color(0xFF3B82F6),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
        return;
      }

      final Map<String, dynamic> newUser = {
        'uid': uid,
        'nama': googleName,
        'username': googleUsername,
        'email': googleEmail,
        'phone': '081234567890',
        'password': 'google_oauth_pass',
        'pin': '123456',
        'referralCode': '',
        'role': 'user',
        'createdAt': DateTime.now().toIso8601String(),
        'saldo': 0.0,
        'avatarUrl': selectedAccount.avatarUrl ?? '',
      };

      // 1. Simpan akun ke SQLite lokal secara instan (<5ms)
      await DatabaseHelper.instance.registerUser(newUser);

      if (!mounted) return;
      setState(() => _isLoading = false);

      // 2. Kirim notifikasi sambutan di latar belakang (non-blocking)
      NotificationService.sendEmailNotification(
        context,
        toEmail: googleEmail,
        subject: 'Selamat Datang di VibeTech XYZ! 🚀 (Google Auth)',
        message:
            'Halo $googleName,\n\nSelamat! Akun Google Anda ($googleEmail) telah berhasil didaftarkan di VibeTech XYZ.\n\nStatus: Terverifikasi & Aktif\nTanggal Daftar: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} WIB\n\nAnda sekarang dapat mulai menggunakan seluruh layanan Cloud VPS, Bot WhatsApp, dan Panel Hosting.',
        category: 'Aktivasi Akun',
        showPopupImmediately: false,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      final Color dialogBg =
          _isDarkMode ? const Color(0xFF0F1426) : Colors.white;
      final Color titleColor =
          _isDarkMode ? Colors.white : const Color(0xFF1E293B);
      final Color descColor =
          _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: dialogBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 56),
                ),
                const SizedBox(height: 16),
                Text(
                  LanguageService.text('Pendaftaran Google Berhasil!',
                      'Google Registration Successful!'),
                  style: GoogleFonts.poppins(
                    color: titleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  LanguageService.text(
                    'Akun Google "$googleName" ($googleEmail) berhasil didaftarkan di sistem VibeTech XYZ.',
                    'Google account "$googleName" ($googleEmail) was successfully registered in VibeTech XYZ.',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: descColor, fontSize: 12.5),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF7C4DFF).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginPage()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        LanguageService.text('Login Sekarang', 'Login Now'),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Gagal daftar via Google: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerWithGithub() async {
    HapticFeedback.lightImpact();

    // 1. Tampilkan GitHub Account Picker
    final GithubAccountUser? selectedAccount =
        await GithubAuthService.pickAndSignIn(
      context: context,
      isDarkMode: _isDarkMode,
      isRegisterMode: true,
    );

    if (selectedAccount == null) return;
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final String githubEmail = selectedAccount.email;
      final String githubName = selectedAccount.name;
      final String githubUsername = selectedAccount.username;
      final String uid = (selectedAccount.firebaseUid != null &&
              selectedAccount.firebaseUid!.isNotEmpty)
          ? selectedAccount.firebaseUid!
          : 'gh_${DateTime.now().millisecondsSinceEpoch}';

      // Periksa apakah akun sudah terdaftar
      final existing =
          await DatabaseHelper.instance.getUserByEmail(githubEmail);
      if (existing != null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageService.text(
              'Akun GitHub "$githubEmail" (@$githubUsername) sudah terdaftar! Silakan langsung login.',
              'GitHub account "$githubEmail" (@$githubUsername) is already registered! Please login.',
            )),
            backgroundColor: const Color(0xFF3B82F6),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
        return;
      }

      final String userAvatar = (selectedAccount.avatarUrl != null &&
              selectedAccount.avatarUrl!.isNotEmpty)
          ? selectedAccount.avatarUrl!
          : 'https://avatars.githubusercontent.com/$githubUsername';
      final String githubPassword = (selectedAccount.password != null &&
              selectedAccount.password!.isNotEmpty)
          ? selectedAccount.password!
          : 'github_oauth_pass';

      final Map<String, dynamic> newUser = {
        'uid': uid,
        'nama': githubName,
        'username': githubUsername,
        'email': githubEmail,
        'phone': '081299887766',
        'password': githubPassword,
        'pin': '123456',
        'referralCode': '',
        'role': 'user',
        'createdAt': DateTime.now().toIso8601String(),
        'saldo': 0.0,
        'avatarUrl': userAvatar,
        'authProvider': 'GitHub',
      };

      // 1. Simpan ke SQLite lokal secara instan
      await DatabaseHelper.instance.registerUser(newUser);

      // 2. Sinkronisasi penuh ke Firebase Authentication, Realtime Database & Cloud Firestore di latar belakang
      FirebaseUserService.instance
          .saveUserToFirebase(newUser)
          .timeout(const Duration(seconds: 4))
          .catchError((_) => null);

      if (!mounted) return;
      setState(() => _isLoading = false);

      // 3. Kirim notifikasi sambutan di latar belakang (non-blocking)
      NotificationService.sendEmailNotification(
        context,
        toEmail: githubEmail,
        subject: 'Selamat Datang di VibeTech XYZ! 🚀 (GitHub Auth)',
        message:
            'Halo $githubName (@$githubUsername),\n\nSelamat! Akun GitHub Anda ($githubEmail) telah berhasil didaftarkan di VibeTech XYZ.\n\nStatus: Terverifikasi & Aktif\nTanggal Daftar: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} WIB\n\nAnda sekarang dapat mulai menggunakan seluruh layanan Cloud VPS, Bot WhatsApp, dan Panel Hosting.',
        category: 'Aktivasi Akun',
        showPopupImmediately: false,
      );

      // 4. Tampilkan dialog sukses
      final Color dialogBg =
          _isDarkMode ? const Color(0xFF0F1426) : Colors.white;
      final Color titleColor =
          _isDarkMode ? Colors.white : const Color(0xFF1E293B);
      final Color descColor =
          _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: dialogBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF238636).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF238636), size: 56),
                ),
                const SizedBox(height: 16),
                Text(
                  LanguageService.text('Pendaftaran GitHub Berhasil!',
                      'GitHub Registration Successful!'),
                  style: GoogleFonts.poppins(
                    color: titleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  LanguageService.text(
                    'Akun GitHub "$githubName" (@$githubUsername) berhasil didaftarkan di sistem VibeTech XYZ.',
                    'GitHub account "$githubName" (@$githubUsername) was successfully registered in VibeTech XYZ.',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: descColor, fontSize: 12.5),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF238636), Color(0xFF2EA44F)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF238636).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginPage()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        LanguageService.text(
                            'Lanjut ke Halaman Masuk', 'Proceed to Login'),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showErrorSnackBar('Gagal daftar via GitHub: $e');
    }
  }

  // --- BUILD METODE UI UTAMA ---

  @override
  Widget build(BuildContext context) {
    final Color primaryText =
        _isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final Color secondaryText =
        _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color hintText =
        _isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    final Color cardBg = _isDarkMode
        ? const Color(0xFF0F1426).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.95);

    final Color cardBorder = _isDarkMode
        ? const Color(0xFF7C4DFF).withValues(alpha: 0.25)
        : const Color(0xFF7C4DFF).withValues(alpha: 0.15);

    final Color fieldBg = _isDarkMode
        ? const Color(0xFF161B2E).withValues(alpha: 0.7)
        : const Color(0xFFF1F5F9);
    final Color fieldBorder =
        _isDarkMode ? const Color(0xFF2A334D) : const Color(0xFFCBD5E1);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor:
          _isDarkMode ? const Color(0xFF060814) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. Background Cyber Linear/Radial Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: _isDarkMode
                    ? AppColors.darkBackgroundGradient
                    : AppColors.lightBackgroundGradient,
              ),
            ),
          ),

          // 2. Ambient Neon Glow Orbs (Mode Gelap)
          if (_isDarkMode) AppNeonOrbs(pulseAnimation: _pulseController),

          // 3. Floating Cyber Particle Canvas (Identik dengan LoginPage)
          if (_isDarkMode)
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: AppParticlePainter(_particles),
                );
              },
            ),

          // 4. Main Content dengan Floating Top Bar
          SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    physics: const BouncingScrollPhysics(),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            // Jarak atas untuk floating buttons
                            const SizedBox(height: 48),

                            // Logo Header Ring Cyber & VIBETECH XYZ Brand (100% Identik dengan LoginPage)
                            Center(
                              child: Column(
                                children: [
                                  SizedBox(
                                    width: 95,
                                    height: 95,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (_isDarkMode)
                                          RotationTransition(
                                            turns: _ringController,
                                            child: CustomPaint(
                                              size: const Size(95, 95),
                                              painter: _MiniRegisterRingPainter(
                                                color: const Color(0xFF00E5FF),
                                                secondaryColor:
                                                    const Color(0xFF7C4DFF),
                                              ),
                                            ),
                                          ),
                                        Container(
                                          width: 76,
                                          height: 76,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF0E1326),
                                            border: Border.all(
                                              color: const Color(0xFF7C4DFF)
                                                  .withValues(alpha: 0.8),
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF7C4DFF)
                                                    .withValues(alpha: 0.6),
                                                blurRadius: 18,
                                                spreadRadius: 2,
                                              ),
                                              BoxShadow(
                                                color: const Color(0xFF00E5FF)
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 15,
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: Image.network(
                                              'https://cdn.nekohime.site/file/5232n74c.jpeg',
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Image.asset(
                                                  'assets/icon/logo.png',
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (context, err, stack) {
                                                    return const Icon(
                                                      Icons.cloud_queue_rounded,
                                                      color: Color(0xFF00E5FF),
                                                      size: 34,
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'VIBE',
                                        style: GoogleFonts.poppins(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2,
                                          color: _isDarkMode
                                              ? Colors.white
                                              : const Color(0xFF1E293B),
                                          shadows: _isDarkMode
                                              ? [
                                                  Shadow(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.5),
                                                    blurRadius: 12,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                      ShaderMask(
                                        shaderCallback: (bounds) =>
                                            const LinearGradient(
                                          colors: [
                                            Color(0xFF7C4DFF),
                                            Color(0xFF00E5FF),
                                          ],
                                        ).createShader(bounds),
                                        child: Text(
                                          'TECH',
                                          style: GoogleFonts.poppins(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00E5FF)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: const Color(0xFF00E5FF)
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: Text(
                                          'XYZ',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF00E5FF),
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    LanguageService.tr('daftar_layanan'),
                                    style: GoogleFonts.poppins(
                                        color: secondaryText, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Card Form Utama
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(24),
                                border:
                                    Border.all(color: cardBorder, width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                        alpha: _isDarkMode ? 0.35 : 0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 1. Seksi Informasi Akun
                                  _buildSectionTitle(
                                    icon: Icons.person_pin_rounded,
                                    title: LanguageService.tr('informasi_akun'),
                                    color: const Color(0xFF7C4DFF),
                                  ),
                                  const SizedBox(height: 14),
                                  _buildInputField(
                                    controller: _fullnameController,
                                    focusNode: _fullnameFocus,
                                    label: LanguageService.tr('nama_lengkap'),
                                    hint: LanguageService.text(
                                        'Nama Lengkap Anda', 'Your Full Name'),
                                    icon: Icons.badge_rounded,
                                    primaryText: primaryText,
                                    secondaryText: secondaryText,
                                    hintText: hintText,
                                    fieldBg: fieldBg,
                                    fieldBorder: fieldBorder,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInputField(
                                    controller: _usernameController,
                                    focusNode: _usernameFocus,
                                    label: LanguageService.tr('username'),
                                    hint: LanguageService.text(
                                        'Minimal 4 karakter',
                                        'Minimum 4 characters'),
                                    icon: Icons.alternate_email_rounded,
                                    primaryText: primaryText,
                                    secondaryText: secondaryText,
                                    hintText: hintText,
                                    fieldBg: fieldBg,
                                    fieldBorder: fieldBorder,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInputField(
                                    controller: _emailController,
                                    focusNode: _emailFocus,
                                    label: LanguageService.tr('email'),
                                    hint: 'contoh@vibetech.xyz',
                                    icon: Icons.email_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    primaryText: primaryText,
                                    secondaryText: secondaryText,
                                    hintText: hintText,
                                    fieldBg: fieldBg,
                                    fieldBorder: fieldBorder,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInputField(
                                    controller: _phoneController,
                                    focusNode: _phoneFocus,
                                    label: LanguageService.tr('no_telepon'),
                                    hint: '08xxxxxxxxxx',
                                    icon: Icons.phone_android_rounded,
                                    keyboardType: TextInputType.phone,
                                    primaryText: primaryText,
                                    secondaryText: secondaryText,
                                    hintText: hintText,
                                    fieldBg: fieldBg,
                                    fieldBorder: fieldBorder,
                                  ),

                                  const SizedBox(height: 20),
                                  Divider(
                                      color: _isDarkMode
                                          ? Colors.white10
                                          : Colors.black
                                              .withValues(alpha: 0.06)),
                                  const SizedBox(height: 12),

                                  // 2. Seksi Keamanan Password & PIN Pembayaran
                                  _buildSectionTitle(
                                    icon: Icons.security_rounded,
                                    title: LanguageService.text(
                                        'Keamanan Password & PIN Pembayaran',
                                        'Password & Payment PIN Security'),
                                    color: const Color(0xFF00E5FF),
                                  ),
                                  const SizedBox(height: 14),
                                  _buildInputField(
                                    controller: _passwordController,
                                    focusNode: _passwordFocus,
                                    label: 'Password',
                                    hint: LanguageService.text(
                                        'Minimal 6 karakter',
                                        'Minimum 6 characters'),
                                    icon: Icons.lock_rounded,
                                    obscureText: _obscurePassword,
                                    onToggleObscure: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                    primaryText: primaryText,
                                    secondaryText: secondaryText,
                                    hintText: hintText,
                                    fieldBg: fieldBg,
                                    fieldBorder: fieldBorder,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInputField(
                                    controller: _confirmPasswordController,
                                    focusNode: _confirmPasswordFocus,
                                    label: LanguageService.text(
                                        'Konfirmasi Password',
                                        'Confirm Password'),
                                    hint: LanguageService.text(
                                        'Masukkan ulang password',
                                        'Re-enter password'),
                                    icon: Icons.lock_outline_rounded,
                                    obscureText: _obscureConfirmPassword,
                                    onToggleObscure: () => setState(() =>
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword),
                                    primaryText: primaryText,
                                    secondaryText: secondaryText,
                                    hintText: hintText,
                                    fieldBg: fieldBg,
                                    fieldBorder: fieldBorder,
                                  ),
                                  const SizedBox(height: 14),

                                  // PIN Transaksi (6 Digit)
                                  _buildInputField(
                                    controller: _pinController,
                                    focusNode: _pinFocus,
                                    label: LanguageService.text(
                                        'PIN Pembayaran (6 Digit Angka)',
                                        'Payment PIN (6 Numeric Digits)'),
                                    hint: '123456',
                                    icon: Icons.pin_outlined,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    letterSpacing: 4,
                                    obscureText: _obscurePin,
                                    onToggleObscure: () => setState(
                                        () => _obscurePin = !_obscurePin),
                                    primaryText: primaryText,
                                    secondaryText: secondaryText,
                                    hintText: hintText,
                                    fieldBg: fieldBg,
                                    fieldBorder: fieldBorder,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInputField(
                                    controller: _confirmPinController,
                                    focusNode: _confirmPinFocus,
                                    label: LanguageService.text(
                                        'Konfirmasi PIN Pembayaran',
                                        'Confirm Payment PIN'),
                                    hint: '123456',
                                    icon: Icons.pin_rounded,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    letterSpacing: 4,
                                    obscureText: _obscureConfirmPin,
                                    onToggleObscure: () => setState(() =>
                                        _obscureConfirmPin =
                                            !_obscureConfirmPin),
                                    primaryText: primaryText,
                                    secondaryText: secondaryText,
                                    hintText: hintText,
                                    fieldBg: fieldBg,
                                    fieldBorder: fieldBorder,
                                  ),

                                  const SizedBox(height: 20),
                                  Divider(
                                      color: _isDarkMode
                                          ? Colors.white10
                                          : Colors.black
                                              .withValues(alpha: 0.06)),
                                  const SizedBox(height: 12),

                                  // 3. Seksi Opsional
                                  _buildSectionTitle(
                                    icon: Icons.card_giftcard_rounded,
                                    title: LanguageService.text(
                                        'Opsional', 'Optional'),
                                    color: const Color(0xFF7C4DFF),
                                  ),
                                  const SizedBox(height: 14),
                                  _buildInputField(
                                    controller: _referralController,
                                    label: LanguageService.text(
                                        'Kode Referral (Opsional)',
                                        'Referral Code (Optional)'),
                                    hint: 'VIBE2026',
                                    icon: Icons.redeem_rounded,
                                    primaryText: primaryText,
                                    secondaryText: secondaryText,
                                    hintText: hintText,
                                    fieldBg: fieldBg,
                                    fieldBorder: fieldBorder,
                                  ),

                                  const SizedBox(height: 18),

                                  // Checkbox Persetujuan Syarat & Ketentuan
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: Checkbox(
                                          value: _agreeTerms,
                                          onChanged: (value) => setState(() =>
                                              _agreeTerms = value ?? false),
                                          activeColor: const Color(0xFF7C4DFF),
                                          checkColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6)),
                                          side: BorderSide(
                                            color: _isDarkMode
                                                ? const Color(0xFF7C4DFF)
                                                    .withValues(alpha: 0.6)
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: GoogleFonts.poppins(
                                                color: secondaryText,
                                                fontSize: 12),
                                            children: [
                                              TextSpan(
                                                  text: LanguageService.text(
                                                      'Saya menyetujui ',
                                                      'I agree to the ')),
                                              TextSpan(
                                                text: LanguageService.text(
                                                    'Syarat & Ketentuan',
                                                    'Terms & Conditions'),
                                                style: const TextStyle(
                                                  color: Color(0xFF00E5FF),
                                                  fontWeight: FontWeight.bold,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                              TextSpan(
                                                  text: LanguageService.text(
                                                      ' dan ', ' and ')),
                                              TextSpan(
                                                text: LanguageService.text(
                                                    'Kebijakan Privasi',
                                                    'Privacy Policy'),
                                                style: const TextStyle(
                                                  color: Color(0xFF00E5FF),
                                                  fontWeight: FontWeight.bold,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 24),

                                  // Tombol Submit Registrasi
                                  Container(
                                    width: double.infinity,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF7C4DFF),
                                          Color(0xFF00E5FF)
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF7C4DFF)
                                              .withValues(alpha: 0.35),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: _isLoading ? null : _register,
                                      icon: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2))
                                          : const Icon(Icons.person_add_rounded,
                                              color: Colors.white, size: 20),
                                      label: Text(
                                        _isLoading
                                            ? LanguageService.text(
                                                'Mendaftarkan...',
                                                'Registering...')
                                            : LanguageService.tr(
                                                'daftar_sekarang'),
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Divider atau daftar dengan
                                  Row(
                                    children: [
                                      Expanded(
                                          child: Divider(
                                              color: _isDarkMode
                                                  ? Colors.white12
                                                  : Colors.black12)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text(
                                          LanguageService.text(
                                              'atau daftar dengan',
                                              'or register with'),
                                          style: GoogleFonts.poppins(
                                              color: hintText, fontSize: 12.5),
                                        ),
                                      ),
                                      Expanded(
                                          child: Divider(
                                              color: _isDarkMode
                                                  ? Colors.white12
                                                  : Colors.black12)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Tombol Google & GitHub
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildSocialButton(
                                          title: 'Google',
                                          icon: Icons.g_mobiledata_rounded,
                                          iconColor: Colors.redAccent,
                                          isPressed: _isGooglePressed,
                                          primaryText: primaryText,
                                          fieldBg: fieldBg,
                                          fieldBorder: fieldBorder,
                                          onTapDown: () => setState(
                                              () => _isGooglePressed = true),
                                          onTapUp: () {
                                            setState(
                                                () => _isGooglePressed = false);
                                            if (!_isLoading) {
                                              _registerWithGoogle();
                                            }
                                          },
                                          onTapCancel: () => setState(
                                              () => _isGooglePressed = false),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _buildSocialButton(
                                          title: 'GitHub',
                                          icon: Icons.terminal_rounded,
                                          iconColor: _isDarkMode
                                              ? const Color(0xFF00E5FF)
                                              : const Color(0xFF1E293B),
                                          isPressed: _isGithubPressed,
                                          primaryText: primaryText,
                                          fieldBg: fieldBg,
                                          fieldBorder: fieldBorder,
                                          onTapDown: () => setState(
                                              () => _isGithubPressed = true),
                                          onTapUp: () {
                                            setState(
                                                () => _isGithubPressed = false);
                                            if (!_isLoading) {
                                              _registerWithGithub();
                                            }
                                          },
                                          onTapCancel: () => setState(
                                              () => _isGithubPressed = false),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // Link ke Halaman Login
                                  Center(
                                    child: Wrap(
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          LanguageService.tr(
                                              'sudah_punya_akun'),
                                          style: GoogleFonts.poppins(
                                              color: secondaryText,
                                              fontSize: 13),
                                        ),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            Navigator.pushAndRemoveUntil(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      const LoginPage()),
                                              (route) => false,
                                            );
                                          },
                                          child: Text(
                                            LanguageService.tr('masuk_di_sini'),
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFF00E5FF),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Floating Back Button (Pojok Kiri Atas)
                Positioned(
                  top: 10,
                  left: 16,
                  child: _buildBackButton(primaryText),
                ),

                // Floating Theme Switcher (Pojok Kanan Atas - Identik dengan LoginPage)
                Positioned(
                  top: 10,
                  right: 16,
                  child: _buildThemeToggle(primaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(Color primaryText) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _isDarkMode
                ? const Color(0xFF141A29).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isDarkMode
                  ? const Color(0xFF7C4DFF).withValues(alpha: 0.35)
                  : const Color(0xFF7C4DFF).withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 13,
                color: _isDarkMode
                    ? const Color(0xFF00E5FF)
                    : const Color(0xFF7C4DFF),
              ),
              const SizedBox(width: 5),
              Text(
                LanguageService.text('Kembali', 'Back'),
                style: GoogleFonts.poppins(
                  color: primaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(Color primaryText) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          ThemeService.toggleTheme();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _isDarkMode
                ? const Color(0xFF141A29).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isDarkMode
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.35)
                  : const Color(0xFF7C4DFF).withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) =>
                    RotationTransition(turns: anim, child: child),
                child: Icon(
                  _isDarkMode ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                  key: ValueKey(_isDarkMode),
                  color: _isDarkMode
                      ? const Color(0xFF00E5FF)
                      : const Color(0xFFFFB300),
                  size: 15,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isDarkMode ? 'Gelap' : 'Terang',
                style: GoogleFonts.poppins(
                  color: primaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    int? maxLength,
    double? letterSpacing,
    required Color primaryText,
    required Color secondaryText,
    required Color hintText,
    required Color fieldBg,
    required Color fieldBorder,
  }) {
    final bool isFocused = focusNode?.hasFocus ?? false;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      style: GoogleFonts.poppins(
        color: primaryText,
        fontSize: 13.5,
        fontWeight: letterSpacing != null ? FontWeight.bold : FontWeight.normal,
        letterSpacing: letterSpacing,
      ),
      cursorColor: const Color(0xFF7C4DFF),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: isFocused ? const Color(0xFF7C4DFF) : secondaryText,
          fontSize: 13,
        ),
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: hintText, fontSize: 13),
        counterText: '',
        prefixIcon: Icon(
          icon,
          color: isFocused ? const Color(0xFF7C4DFF) : secondaryText,
          size: 20,
        ),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: isFocused ? const Color(0xFF00E5FF) : secondaryText,
                  size: 20,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: fieldBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: fieldBorder, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: fieldBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 1.8),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isPressed,
    required Color primaryText,
    required Color fieldBg,
    required Color fieldBorder,
    required VoidCallback onTapDown,
    required VoidCallback onTapUp,
    required VoidCallback onTapCancel,
  }) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: () => onTapCancel(),
      child: AnimatedScale(
        scale: isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPressed ? const Color(0xFF7C4DFF) : fieldBorder,
              width: isPressed ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: primaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- MINI CYBER RING PAINTER FOR REGISTER ---

class _MiniRegisterRingPainter extends CustomPainter {
  final Color color;
  final Color secondaryColor;

  _MiniRegisterRingPainter({required this.color, required this.secondaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final dashPaint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    const int segments = 4;
    const double sweepAngle = (math.pi * 2) / segments * 0.65;
    const double gapAngle = (math.pi * 2) / segments * 0.35;

    for (int i = 0; i < segments; i++) {
      final startAngle = i * (sweepAngle + gapAngle);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        dashPaint,
      );
    }

    final dotPaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final angle = i * (math.pi / 2);
      final dotX = center.dx + (radius - 1.5) * math.cos(angle);
      final dotY = center.dy + (radius - 1.5) * math.sin(angle);
      canvas.drawCircle(Offset(dotX, dotY), 2.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniRegisterRingPainter oldDelegate) => false;
}
