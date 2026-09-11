import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibetech_xyz/constants/constants.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/language_service.dart';
import 'package:vibetech_xyz/services/theme_service.dart';

import 'login_page.dart';

/// ============================================================================
/// HALAMAN PEMULIHAN KATA SANDI (FORGOT PASSWORD PAGE) - VIBETECH XYZ
/// ============================================================================
/// Fitur Utama:
/// 1. Desain Cyber Glassmorphism sinkron 100% dengan Register Page & Login Page.
/// 2. Mode Gelap & Terang dinamis dengan partikel ambient neon di mode gelap.
/// 3. Sinkronisasi tema otomatis mengikuti Login Page & ThemeService global.
/// 4. Alur 2-Langkah interaktif: Verifikasi email terdaftar & Buat kata sandi baru.
/// 5. Pembaruan langsung kata sandi pengguna ke database lokal SQLite.
class LupaPasswordPage extends StatefulWidget {
  final bool? isDarkMode;

  const LupaPasswordPage({super.key, this.isDarkMode});

  @override
  State<LupaPasswordPage> createState() => _LupaPasswordPageState();
}

class _LupaPasswordPageState extends State<LupaPasswordPage>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _pinFocus = FocusNode();
  final FocusNode _newPasswordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();

  bool _obscurePin = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isSubmitPressed = false;
  bool _isDarkMode = true;

  // Alur 2-Langkah (0 = Verifikasi Email, 1 = Buat Password Baru)
  bool _isEmailVerified = false;
  String _verifiedUsername = '';
  String _verifiedNama = '';
  String _verifiedRole = '';

  // Animation Controllers & Particle System
  late AnimationController _mainAnimationController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initThemeMode();

    _emailFocus.addListener(() => setState(() {}));
    _pinFocus.addListener(() => setState(() {}));
    _newPasswordFocus.addListener(() => setState(() {}));
    _confirmPasswordFocus.addListener(() => setState(() {}));

    _mainAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.15, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

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
    _emailController.dispose();
    _pinController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    _emailFocus.dispose();
    _pinFocus.dispose();
    _newPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();

    _mainAnimationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // --- SNACKBAR NOTIFIKASI CYBER ---

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

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
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
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // --- LOGIKA VERIFIKASI EMAIL & PIN (LANGKAH 1) ---

  Future<void> _verifyEmail() async {
    final email = _emailController.text.trim();
    final pin = _pinController.text.trim();

    if (email.isEmpty) {
      _showErrorSnackBar(LanguageService.text(
        'Alamat email harus diisi!',
        'Email address is required!',
      ));
      return;
    }

    if (!email.contains('@')) {
      _showErrorSnackBar(LanguageService.text(
        'Format email tidak valid! Harap sertakan tanda @',
        'Invalid email format! Please include @',
      ));
      return;
    }

    if (pin.isEmpty || pin.length != 6) {
      _showErrorSnackBar(LanguageService.text(
        'PIN Transaksi Keamanan 6-digit harus diisi!',
        '6-digit Security PIN is required!',
      ));
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      // Cek ketersediaan akun di database lokal SQLite
      final user = await DatabaseHelper.instance.getUserByEmail(email);

      if (!mounted) return;

      if (user == null) {
        _showErrorSnackBar(LanguageService.text(
          'Email "$email" tidak terdaftar di database sistem!',
          'Email "$email" is not registered in system database!',
        ));
      } else {
        final isPinValid =
            await DatabaseHelper.instance.verifyUserPin(email, pin);
        if (!isPinValid) {
          _showErrorSnackBar(LanguageService.text(
            'PIN Keamanan salah! Verifikasi identitas gagal.',
            'Incorrect Security PIN! Identity verification failed.',
          ));
          return;
        }

        setState(() {
          _isEmailVerified = true;
          _verifiedUsername = (user['username'] ?? '').toString();
          _verifiedNama = (user['nama'] ?? _verifiedUsername).toString();
          _verifiedRole = (user['role'] ?? 'user').toString().toUpperCase();
        });
        _showSuccessSnackBar(LanguageService.text(
          'Identitas akun terverifikasi! Silakan tentukan kata sandi baru.',
          'Account identity verified! Please set a new password.',
        ));
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIKA SIMPAN PASSWORD BARU (LANGKAH 2) ---

  Future<void> _resetPassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final email = _emailController.text.trim();
    final pin = _pinController.text.trim();

    if (newPassword.isEmpty) {
      _showErrorSnackBar(LanguageService.text(
        'Kata sandi baru harus diisi!',
        'New password is required!',
      ));
      return;
    }

    if (newPassword.length < 6) {
      _showErrorSnackBar(LanguageService.text(
        'Kata sandi baru minimal 6 karakter!',
        'New password must be at least 6 characters!',
      ));
      return;
    }

    if (newPassword != confirmPassword) {
      _showErrorSnackBar(LanguageService.text(
        'Konfirmasi kata sandi tidak cocok!',
        'Password confirmation does not match!',
      ));
      return;
    }

    // Re-verifikasi otorisasi PIN sebelum eksekusi pembaruan
    final isPinValid = await DatabaseHelper.instance.verifyUserPin(email, pin);
    if (!isPinValid) {
      _showErrorSnackBar(LanguageService.text(
        'Otorisasi ditolak! PIN keamanan tidak valid.',
        'Authorization denied! Security PIN is invalid.',
      ));
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      // Update password pengguna di SQLite database
      final result =
          await DatabaseHelper.instance.updateUserPassword(email, newPassword);

      if (!mounted) return;

      if (result > 0) {
        _showSuccessDialog();
      } else {
        _showErrorSnackBar(LanguageService.text(
          'Gagal memperbarui kata sandi di database!',
          'Failed to update password in database!',
        ));
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- DIALOG SUKSES RESET PASSWORD ---

  void _showSuccessDialog() {
    final Color dialogBg = _isDarkMode ? const Color(0xFF0F1426) : Colors.white;
    final Color titleColor =
        _isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final Color descColor =
        _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 54,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                LanguageService.text(
                  'Kata Sandi Berhasil Direset!',
                  'Password Successfully Reset!',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: titleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                LanguageService.text(
                  'Kata sandi untuk akun "$_verifiedUsername" telah berhasil diperbarui di database lokal. Silakan masuk kembali menggunakan kata sandi baru Anda.',
                  'Password for account "$_verifiedUsername" has been successfully updated in the local database. Please login with your new password.',
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
                      colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.35),
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
                        PageRouteBuilder(
                          pageBuilder: (context, a, b) => const LoginPage(),
                          transitionsBuilder: (context, a, b, child) =>
                              FadeTransition(opacity: a, child: child),
                        ),
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

          // 3. Floating Cyber Particle Canvas (Animated & GPU-isolated)
          if (_isDarkMode)
            const CyberParticlesLayer(count: 20),

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

                            // Logo Header Ring Cyber & VIBETECH XYZ Brand (Identik dengan Register Page)
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
                                          CustomPaint(
                                            size: const Size(95, 95),
                                            painter: _MiniResetRingPainter(
                                              color: const Color(0xFF00E5FF),
                                              secondaryColor:
                                                  const Color(0xFF7C4DFF),
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
                                                      Icons.lock_reset_rounded,
                                                      color: Color(0xFF00E5FF),
                                                      size: 36,
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
                                    LanguageService.text(
                                      'Pemulihan Akses & Kata Sandi Akun',
                                      'Account Access & Password Recovery',
                                    ),
                                    style: GoogleFonts.poppins(
                                      color: secondaryText,
                                      fontSize: 12.5,
                                    ),
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
                                  // Header Card & Indikator Tahap
                                  _buildStepHeader(primaryText, secondaryText),

                                  const SizedBox(height: 18),

                                  // --- LANGKAH 1: INPUT EMAIL TERDAFTAR ---
                                  _buildSectionTitle(
                                    icon: Icons.mark_email_read_rounded,
                                    title: LanguageService.text(
                                      'Alamat Email Terdaftar',
                                      'Registered Email Address',
                                    ),
                                    color: const Color(0xFF00E5FF),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInputField(
                                    controller: _emailController,
                                    focusNode: _emailFocus,
                                    label: LanguageService.tr('email'),
                                    hint: 'contoh@vibetech.xyz',
                                    icon: Icons.email_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    readOnly: _isEmailVerified,
                                    primaryText: primaryText,
                                    secondaryText: secondaryText,
                                    hintText: hintText,
                                    fieldBg: fieldBg,
                                    fieldBorder: fieldBorder,
                                    suffixWidget: _isEmailVerified
                                        ? IconButton(
                                            tooltip: LanguageService.text(
                                                'Ganti Email', 'Change Email'),
                                            icon: const Icon(
                                              Icons.edit_rounded,
                                              color: Color(0xFF00E5FF),
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              HapticFeedback.selectionClick();
                                              setState(() {
                                                _isEmailVerified = false;
                                                _pinController.clear();
                                                _newPasswordController.clear();
                                                _confirmPasswordController
                                                    .clear();
                                              });
                                            },
                                          )
                                        : null,
                                  ),

                                  if (!_isEmailVerified) ...[
                                    const SizedBox(height: 14),
                                    _buildSectionTitle(
                                      icon: Icons.pin_rounded,
                                      title: LanguageService.text(
                                        'PIN Transaksi Keamanan (6 Digit)',
                                        'Security Transaction PIN (6 Digits)',
                                      ),
                                      color: const Color(0xFF00E5FF),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInputField(
                                      controller: _pinController,
                                      focusNode: _pinFocus,
                                      label: LanguageService.text(
                                        'PIN Keamanan Akun',
                                        'Account Security PIN',
                                      ),
                                      hint: '123456',
                                      icon: Icons.lock_outline_rounded,
                                      keyboardType: TextInputType.number,
                                      obscureText: _obscurePin,
                                      onToggleObscure: () => setState(
                                          () => _obscurePin = !_obscurePin),
                                      primaryText: primaryText,
                                      secondaryText: secondaryText,
                                      hintText: hintText,
                                      fieldBg: fieldBg,
                                      fieldBorder: fieldBorder,
                                    ),
                                  ],

                                  // Jika Akun Berhasil Ditemukan (Info Banner)
                                  if (_isEmailVerified) ...[
                                    const SizedBox(height: 14),
                                    _buildVerifiedAccountCard(secondaryText),
                                    const SizedBox(height: 16),
                                    Divider(
                                      color: _isDarkMode
                                          ? Colors.white10
                                          : Colors.black
                                              .withValues(alpha: 0.06),
                                    ),
                                    const SizedBox(height: 14),

                                    // --- LANGKAH 2: INPUT PASSWORD BARU ---
                                    _buildSectionTitle(
                                      icon: Icons.lock_reset_rounded,
                                      title: LanguageService.text(
                                        'Kata Sandi Baru',
                                        'New Password',
                                      ),
                                      color: const Color(0xFF7C4DFF),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInputField(
                                      controller: _newPasswordController,
                                      focusNode: _newPasswordFocus,
                                      label: LanguageService.text(
                                        'Kata Sandi Baru',
                                        'New Password',
                                      ),
                                      hint: LanguageService.text(
                                        'Minimal 6 karakter',
                                        'Minimum 6 characters',
                                      ),
                                      icon: Icons.lock_outline_rounded,
                                      obscureText: _obscureNewPassword,
                                      onToggleObscure: () => setState(() =>
                                          _obscureNewPassword =
                                              !_obscureNewPassword),
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
                                        'Konfirmasi Kata Sandi Baru',
                                        'Confirm New Password',
                                      ),
                                      hint: LanguageService.text(
                                        'Masukkan ulang kata sandi baru',
                                        'Re-enter new password',
                                      ),
                                      icon: Icons.check_circle_outline_rounded,
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
                                  ],

                                  const SizedBox(height: 22),

                                  // --- TOMBOL AKSI UTAMA DENGAN ANIMASI SCALE ---
                                  GestureDetector(
                                    onTapDown: (_) =>
                                        setState(() => _isSubmitPressed = true),
                                    onTapUp: (_) {
                                      setState(() => _isSubmitPressed = false);
                                      if (!_isLoading) {
                                        if (!_isEmailVerified) {
                                          _verifyEmail();
                                        } else {
                                          _resetPassword();
                                        }
                                      }
                                    },
                                    onTapCancel: () => setState(
                                        () => _isSubmitPressed = false),
                                    child: AnimatedScale(
                                      scale: _isSubmitPressed ? 0.96 : 1.0,
                                      duration:
                                          const Duration(milliseconds: 150),
                                      child: Container(
                                        width: double.infinity,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: _isEmailVerified
                                                ? [
                                                    const Color(0xFF00E5FF),
                                                    const Color(0xFF7C4DFF),
                                                    const Color(0xFFE040FB),
                                                  ]
                                                : [
                                                    const Color(0xFF7C4DFF),
                                                    const Color(0xFF00E5FF),
                                                  ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF7C4DFF)
                                                  .withValues(
                                                alpha: _isSubmitPressed
                                                    ? 0.25
                                                    : 0.45,
                                              ),
                                              blurRadius:
                                                  _isSubmitPressed ? 8 : 16,
                                              offset: Offset(
                                                  0, _isSubmitPressed ? 2 : 6),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: _isLoading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2.5,
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      _isEmailVerified
                                                          ? Icons
                                                              .published_with_changes_rounded
                                                          : Icons
                                                              .search_rounded,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      _isEmailVerified
                                                          ? LanguageService
                                                              .text(
                                                              'Simpan Kata Sandi Baru',
                                                              'Save New Password',
                                                            )
                                                          : LanguageService
                                                              .text(
                                                              'Verifikasi Email Terdaftar',
                                                              'Verify Registered Email',
                                                            ),
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  // --- SECURITY TIPS NOTICE BOX ---
                                  _buildSecurityNotice(
                                      primaryText, secondaryText),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Link Navigasi Kembali ke Login
                            Center(
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    LanguageService.text(
                                      'Sudah mengingat kata sandi?',
                                      'Already remember password?',
                                    ),
                                    style: GoogleFonts.poppins(
                                      color: secondaryText,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (context, a, b) =>
                                              const LoginPage(),
                                          transitionsBuilder:
                                              (context, a, b, child) =>
                                                  FadeTransition(
                                                      opacity: a, child: child),
                                        ),
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
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Floating Back Button (Pojok Kiri Atas - Identik dengan Register Page)
                Positioned(
                  top: 10,
                  left: 16,
                  child: _buildBackButton(primaryText),
                ),

                // Floating Theme Switcher (Pojok Kanan Atas - Identik dengan Register & Login)
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

  // --- WIDGET HELPER BUILDERS ---

  Widget _buildStepHeader(Color primaryText, Color secondaryText) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.35),
            ),
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            color: Color(0xFF00E5FF),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LanguageService.tr('lupa_password'),
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              Text(
                _isEmailVerified
                    ? LanguageService.text(
                        'Langkah 2 dari 2: Buat kata sandi baru',
                        'Step 2 of 2: Create new password',
                      )
                    : LanguageService.text(
                        'Langkah 1 dari 2: Verifikasi email',
                        'Step 1 of 2: Verify email',
                      ),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _isEmailVerified
                      ? const Color(0xFF00E5FF)
                      : secondaryText,
                  fontWeight:
                      _isEmailVerified ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerifiedAccountCard(Color secondaryText) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded,
              color: Color(0xFF10B981), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_verifiedNama (@$_verifiedUsername)',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10B981),
                  ),
                ),
                Text(
                  'Tipe Akun: $_verifiedRole • Siap reset kata sandi',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityNotice(Color primaryText, Color secondaryText) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? const Color(0xFF141A29).withValues(alpha: 0.6)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 16,
            color:
                _isDarkMode ? const Color(0xFF00E5FF) : const Color(0xFF7C4DFF),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              LanguageService.text(
                'Kata sandi baru akan langsung diperbarui ke database SQLite lokal terenkripsi perangkat Anda.',
                'New password will be immediately updated to your device\'s local encrypted SQLite database.',
              ),
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: secondaryText,
                height: 1.4,
              ),
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
              fontSize: 14,
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
    bool readOnly = false,
    VoidCallback? onToggleObscure,
    Widget? suffixWidget,
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
      readOnly: readOnly,
      style: GoogleFonts.poppins(
        color: primaryText,
        fontSize: 13.5,
        fontWeight: FontWeight.normal,
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
        prefixIcon: Icon(
          icon,
          color: isFocused ? const Color(0xFF7C4DFF) : secondaryText,
          size: 20,
        ),
        suffixIcon: suffixWidget ??
            (onToggleObscure != null
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color:
                          isFocused ? const Color(0xFF00E5FF) : secondaryText,
                      size: 20,
                    ),
                    onPressed: onToggleObscure,
                  )
                : null),
        filled: true,
        fillColor: readOnly ? fieldBg.withValues(alpha: 0.4) : fieldBg,
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
}

// --- MINI CYBER RESET RING PAINTER ---

class _MiniResetRingPainter extends CustomPainter {
  final Color color;
  final Color secondaryColor;

  _MiniResetRingPainter({required this.color, required this.secondaryColor});

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
  bool shouldRepaint(covariant _MiniResetRingPainter oldDelegate) => false;
}
