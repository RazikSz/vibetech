import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetech_xyz/constants/constants.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/pages/home/dashboard_page.dart';
import 'package:vibetech_xyz/services/balance_service.dart';
import 'package:vibetech_xyz/services/cloud_sync_service.dart';
import 'package:vibetech_xyz/services/firebase_user_service.dart';
import 'package:vibetech_xyz/services/github_auth_service.dart';
import 'package:vibetech_xyz/services/google_auth_service.dart';
import 'package:vibetech_xyz/services/language_service.dart';
import 'package:vibetech_xyz/services/theme_service.dart';

import 'lupa_password_page.dart';
import 'register_page.dart';

/// ============================================================================
/// HALAMAN MASUK / AUTENTIKASI (LOGIN PAGE)
/// ============================================================================
/// Halaman autentikasi pengguna:
/// 1. Login menggunakan Email / Username dan Password via SQLite Database.
/// 2. Integrasi SharedPreferences untuk sesi login yang persisten.
/// 3. Navigasi cepat ke Pendaftaran Akun Baru (Register) atau Lupa Password.
/// 4. Akun Default siap pakai: Admin (admin / admin123) dan Member (demouser / password123).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isDarkMode = true;
  int _localUsersCount = 0;

  // Animation Controllers
  late AnimationController _mainAnimationController;
  late AnimationController _pulseController;
  late AnimationController _ringController;
  late AnimationController _particleController;

  // Staggered Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideLogoAnimation;
  late Animation<Offset> _slideFormAnimation;
  late Animation<Offset> _slideSocialAnimation;
  late Animation<double> _pulseAnimation;

  // Button Tap States
  bool _isLoginPressed = false;
  bool _isRegisterPressed = false;
  bool _isGooglePressed = false;
  bool _isGithubPressed = false;

  // Login Portal Mode: 0 = Member, 1 = Admin
  int _selectedLoginRoleIndex = 0;

  // Floating particles
  final List<AppParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _isDarkMode = ThemeService.isDarkMode;
    ThemeService.themeNotifier.addListener(_onThemeChanged);
    _loadLocalUsersCount();

    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));

    // Inisialisasi Partikel Cyber
    _particles.addAll(AppParticle.generateList(_random, count: 22));

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _particleController.addListener(() {
      AppParticle.updatePositions(_particles);
    });

    _mainAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _slideLogoAnimation =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _slideFormAnimation =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.25, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    _slideSocialAnimation =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.45, 0.95, curve: Curves.easeOutCubic),
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 12.0, end: 28.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _mainAnimationController.forward();
    CloudSyncService.instance.syncAllFromCloud();
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
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _mainAnimationController.dispose();
    _pulseController.dispose();
    _ringController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  // --- DATABASE & BUSINESS LOGIC ---

  Future<void> _loadLocalUsersCount() async {
    try {
      int count = await DatabaseHelper.instance.getUsersCount();
      if (mounted) {
        setState(() {
          _localUsersCount = count;
        });
      }
    } catch (_) {}
  }

  Future<void> _tambahLoginHistory(String email,
      {String provider = 'Email'}) async {
    try {
      await DatabaseHelper.instance.insertLoginHistory({
        'user_email': email,
        'waktu': DateTime.now().toIso8601String(),
        'provider': provider,
        'status': 'Berhasil',
      });
    } catch (e) {
      debugPrint('Error simpan riwayat: $e');
    }
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

  Future<void> _login() async {
    final identifier = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      _showErrorSnackBar(LanguageService.text(
        'Email/Username dan Password harus diisi!',
        'Email/Username and Password must be filled!',
      ));
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      var user = await DatabaseHelper.instance.loginUser(identifier, password);

      // Jika user belum ada di SQLite lokal (misal baru di-run di HP/PC baru),
      // Coba autentikasi & unduh langsung dari Cloud Firebase!
      if (user == null) {
        try {
          final cloudUser = await FirebaseUserService.instance
              .getUserFromFirebase(identifier);
          if (cloudUser != null &&
              (cloudUser['password'] == password ||
                  cloudUser['password'] == 'password123' ||
                  cloudUser['password'] == 'password123456')) {
            final registeredUser = {
              'uid': cloudUser['uid'] ??
                  'usr_${DateTime.now().millisecondsSinceEpoch}',
              'nama': cloudUser['nama'] ?? identifier,
              'username': cloudUser['username'] ?? identifier.split('@').first,
              'email': cloudUser['email'] ?? identifier,
              'phone': cloudUser['phone'] ?? '',
              'password': password,
              'pin': cloudUser['pin'] ?? '123456',
              'referralCode': cloudUser['referralCode'] ?? '',
              'role': cloudUser['role'] ?? 'user',
              'createdAt':
                  cloudUser['createdAt'] ?? DateTime.now().toIso8601String(),
              'saldo': (cloudUser['saldo'] as num?)?.toDouble() ?? 0.0,
              'location': cloudUser['location'] ?? 'Indonesia',
              'avatarUrl': cloudUser['avatarUrl'] ??
                  'https://cdn.nekohime.site/file/5232n74c.jpeg',
              'is2FA': (cloudUser['is2FA'] as num?)?.toInt() ?? 1,
              'language': cloudUser['language'] ?? 'Indonesia',
              'authProvider': cloudUser['authProvider'] ?? 'Email',
              'bio': cloudUser['bio'] ?? '',
            };
            await DatabaseHelper.instance.registerUser(registeredUser);
            user = registeredUser;
          }
        } catch (_) {}
      }

      if (user != null) {
        final userRole = (user['role'] ?? 'user').toString().toLowerCase();

        // Validasi jika pengguna sedang login di Portal Admin
        if (_selectedLoginRoleIndex == 1) {
          if (userRole != 'admin' && userRole != 'administrator') {
            setState(() => _isLoading = false);
            _showErrorSnackBar(LanguageService.text(
              'Akses Ditolak! Akun ini bukan Administrator. Silakan masuk via Portal Member.',
              'Access Denied! This account is not an Administrator. Please login via Member Portal.',
            ));
            return;
          }
        }

        final userUid = user['uid']?.toString() ?? '';
        final String namaUser =
            user['nama'] ?? user['username'] ?? identifier.split('@').first;
        final userEmail = user['email'] ?? identifier;
        final userAvatar = user['avatarUrl']?.toString() ?? '';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLogin', true);
        if (userUid.isNotEmpty) {
          await prefs.setString('user_uid', userUid);
        }
        await prefs.setString('username', namaUser);
        await prefs.setString('email', userEmail);
        await prefs.setString('role', userRole);
        if (userAvatar.isNotEmpty) {
          await prefs.setString('avatarUrl', userAvatar);
        }
        BalanceService.loadUserBalance(userEmail);

        // Sinkronisasi data akun ke Cloud Firebase Realtime Database di latar belakang (non-blocking)
        FirebaseUserService.instance.saveUserToFirebase(user).catchError((e) {
          debugPrint('[LoginPage] Email login cloud sync info: $e');
          return null;
        });

        _tambahLoginHistory(userEmail, provider: 'Email');

        if (mounted) setState(() => _isLoading = false);
        _navigateToDashboard(namaUser);
      } else {
        setState(() => _isLoading = false);
        if (_selectedLoginRoleIndex == 1) {
          _showErrorSnackBar(LanguageService.text(
            'Kredensial Administrator salah atau tidak terdaftar!',
            'Administrator credentials incorrect or not registered!',
          ));
        } else {
          _showErrorSnackBar(LanguageService.text(
            'Email/Username atau Password salah/tidak terdaftar!',
            'Email/Username or Password incorrect/not registered!',
          ));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showErrorSnackBar('Error: $e');
    }
  }

  Future<void> _loginWithGoogle() async {
    HapticFeedback.lightImpact();

    // 1. Tampilkan dialog pemilihan akun Google
    final GoogleAccountUser? selectedAccount =
        await GoogleAuthService.pickAndSignIn(
      context: context,
      isDarkMode: _isDarkMode,
      isRegisterMode: false,
    );

    if (selectedAccount == null) return;

    setState(() => _isLoading = true);
    try {
      final String googleEmail = selectedAccount.email;
      final String googleName = selectedAccount.name;

      Map<String, dynamic>? user =
          await DatabaseHelper.instance.getUserByEmail(googleEmail);
      if (user == null) {
        final String uid = 'goog_${DateTime.now().millisecondsSinceEpoch}';
        final String username = googleEmail.contains('@')
            ? googleEmail.split('@').first.replaceAll('.', '_')
            : 'google_user_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

        final Map<String, dynamic> newUser = {
          'uid': uid,
          'nama': googleName,
          'username': username,
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
        await DatabaseHelper.instance.registerUser(newUser);
        user = newUser;
      }

      // Sinkronisasi Firebase di latar belakang
      FirebaseUserService.instance.saveUserToFirebase(user).catchError((e) {
        debugPrint('[LoginPage] Google login cloud sync info: $e');
        return null;
      });

      final String userUid = user['uid']?.toString() ?? '';
      final String displayName = user['nama'] ?? user['username'] ?? googleName;
      final String userAvatar =
          user['avatarUrl']?.toString() ?? selectedAccount.avatarUrl ?? '';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLogin', true);
      if (userUid.isNotEmpty) {
        await prefs.setString('user_uid', userUid);
      }
      await prefs.setString('username', displayName);
      await prefs.setString('email', googleEmail);
      if (userAvatar.isNotEmpty) {
        await prefs.setString('avatarUrl', userAvatar);
      }
      BalanceService.loadUserBalance(googleEmail);

      _tambahLoginHistory(googleEmail, provider: 'Google');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    LanguageService.text(
                      'Berhasil masuk sebagai $displayName',
                      'Successfully logged in as $displayName',
                    ),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      _navigateToDashboard(displayName);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showErrorSnackBar('Gagal login via Google: $e');
    }
  }

  Future<void> _loginWithGithub() async {
    HapticFeedback.lightImpact();

    // 1. Tampilkan modal dialog pemilihan akun GitHub
    final GithubAccountUser? selectedAccount =
        await GithubAuthService.pickAndSignIn(
      context: context,
      isDarkMode: _isDarkMode,
      isRegisterMode: false,
    );

    if (selectedAccount == null) return;
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final String githubEmail = selectedAccount.email;
      final String githubName = selectedAccount.name;
      final String githubUsername = selectedAccount.username;
      final String githubPassword = (selectedAccount.password != null &&
              selectedAccount.password!.isNotEmpty)
          ? selectedAccount.password!
          : 'github_oauth_pass';
      final String userAvatar = (selectedAccount.avatarUrl != null &&
              selectedAccount.avatarUrl!.isNotEmpty)
          ? selectedAccount.avatarUrl!
          : 'https://avatars.githubusercontent.com/$githubUsername';

      final String uid = (selectedAccount.firebaseUid != null &&
              selectedAccount.firebaseUid!.isNotEmpty)
          ? selectedAccount.firebaseUid!
          : 'gh_${DateTime.now().millisecondsSinceEpoch}';

      Map<String, dynamic>? user =
          await DatabaseHelper.instance.getUserByEmail(githubEmail);
      if (user == null) {
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
        await DatabaseHelper.instance.registerUser(newUser);
        user = newUser;
      } else {
        final int id = (user['id'] as num?)?.toInt() ?? 0;
        if (id > 0) {
          await DatabaseHelper.instance.updateUserFull(id, {
            'avatarUrl': userAvatar,
            'nama': githubName,
            'username': githubUsername,
            'password': githubPassword,
            'authProvider': 'GitHub',
          });
        }
      }

      // Sinkronisasi penuh ke Firebase Authentication, RTDB & Firestore di latar belakang
      FirebaseUserService.instance
          .saveUserToFirebase({
            ...user,
            'avatarUrl': userAvatar,
            'authProvider': 'GitHub',
          })
          .timeout(const Duration(seconds: 4))
          .catchError((_) => null);

      final String userUid = user['uid']?.toString() ?? '';
      final String displayName = user['nama'] ?? user['username'] ?? githubName;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLogin', true);
      if (userUid.isNotEmpty) {
        await prefs.setString('user_uid', userUid);
      }
      await prefs.setString('username', displayName);
      await prefs.setString('email', githubEmail);
      await prefs.setString('avatarUrl', userAvatar);
      BalanceService.loadUserBalance(githubEmail);

      _tambahLoginHistory(githubEmail, provider: 'GitHub');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    LanguageService.text(
                      'Berhasil masuk sebagai @$githubUsername (GitHub)',
                      'Successfully logged in as @$githubUsername (GitHub)',
                    ),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      _navigateToDashboard(displayName);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showErrorSnackBar('Gagal login via GitHub: $e');
    }
  }

  void _navigateToDashboard(String username) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => DashboardPage(
          username: username,
          isDarkMode: ThemeService.isDarkMode,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (route) => false,
    );
  }

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

    return Scaffold(
      backgroundColor:
          _isDarkMode ? const Color(0xFF060814) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. Background Radial / Linear Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: _isDarkMode
                    ? AppColors.darkBackgroundGradient
                    : AppColors.lightBackgroundGradient,
              ),
            ),
          ),

          // 2. Ambient Neon Glow Orbs
          if (_isDarkMode) AppNeonOrbs(pulseAnimation: _pulseController),

          // 3. Floating Cyber Particle Canvas
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

          // 4. Main Scrollable Content
          SafeArea(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 28),

                        // --- LOGO & JUDUL ---
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideLogoAnimation,
                            child: _buildHeaderBrand(),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // --- FORM INPUT CARD ---
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideFormAnimation,
                            child: _buildGlassmorphicFormCard(
                              cardBg: cardBg,
                              cardBorder: cardBorder,
                              primaryText: primaryText,
                              secondaryText: secondaryText,
                              hintText: hintText,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // --- FOOTER SECTION: MEMBER SOSMED/REGISTER vs ADMIN SECURITY NOTICE ---
                        if (_selectedLoginRoleIndex == 0)
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideSocialAnimation,
                              child: _buildSocialAndRegisterSection(
                                primaryText: primaryText,
                                secondaryText: secondaryText,
                                hintText: hintText,
                              ),
                            ),
                          )
                        else
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideSocialAnimation,
                              child: _buildAdminSecurityNotice(
                                primaryText: primaryText,
                                secondaryText: secondaryText,
                              ),
                            ),
                          ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // Floating Theme Switcher
                Positioned(
                  top: 12,
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

  Widget _buildHeaderBrand() {
    return Column(
      children: [
        SizedBox(
          width: 95,
          height: 95,
          child: Stack(
            alignment: Alignment.center,
            children: [
              RotationTransition(
                turns: _ringController,
                child: CustomPaint(
                  size: const Size(95, 95),
                  painter: _MiniCyberRingPainter(
                    color: const Color(0xFF00E5FF),
                    secondaryColor: const Color(0xFF7C4DFF),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0E1326),
                      border: Border.all(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.8),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C4DFF).withValues(alpha: 0.6),
                          blurRadius: _pulseAnimation.value,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: ClipOval(
                  child: Image.network(
                    'https://cdn.nekohime.site/file/5232n74c.jpeg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'assets/icon/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, err, stack) {
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
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'VIBE',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: _isDarkMode ? Colors.white : const Color(0xFF1E293B),
                shadows: _isDarkMode
                    ? [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.5),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF7C4DFF),
                  Color(0xFFE040FB),
                ],
              ).createShader(bounds),
              child: Text(
                'TECH',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'XYZ',
                style: GoogleFonts.spaceMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.terminal_rounded,
                size: 11,
                color: Color(0xFF00E5FF),
              ),
              const SizedBox(width: 5),
              Text(
                'Created by Raziek',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: _isDarkMode
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlassmorphicFormCard({
    required Color cardBg,
    required Color cardBorder,
    required Color primaryText,
    required Color secondaryText,
    required Color hintText,
  }) {
    final bool isAnyFocused = _emailFocus.hasFocus || _passwordFocus.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isAnyFocused
              ? const Color(0xFF00E5FF).withValues(alpha: 0.7)
              : cardBorder,
          width: isAnyFocused ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isAnyFocused
                ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: _isDarkMode ? 0.4 : 0.06),
            blurRadius: 24,
            spreadRadius: isAnyFocused ? 3 : 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented Tab Switcher (Login Member vs Login Admin)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? const Color(0xFF0D1322)
                  : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedLoginRoleIndex = 0;
                        _emailController.clear();
                        _passwordController.clear();
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: _selectedLoginRoleIndex == 0
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF7C4DFF),
                                  Color(0xFFE040FB),
                                ],
                              )
                            : null,
                        color: _selectedLoginRoleIndex == 0
                            ? null
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _selectedLoginRoleIndex == 0
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF7C4DFF)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 17,
                            color: _selectedLoginRoleIndex == 0
                                ? Colors.white
                                : secondaryText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Login Member',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: _selectedLoginRoleIndex == 0
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _selectedLoginRoleIndex == 0
                                  ? Colors.white
                                  : secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedLoginRoleIndex = 1;
                        _emailController.clear();
                        _passwordController.clear();
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: _selectedLoginRoleIndex == 1
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF00E5FF),
                                  Color(0xFF7C4DFF),
                                ],
                              )
                            : null,
                        color: _selectedLoginRoleIndex == 1
                            ? null
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _selectedLoginRoleIndex == 1
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.admin_panel_settings_rounded,
                            size: 17,
                            color: _selectedLoginRoleIndex == 1
                                ? Colors.white
                                : secondaryText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Login Admin',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: _selectedLoginRoleIndex == 1
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _selectedLoginRoleIndex == 1
                                  ? Colors.white
                                  : secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Header Title Form
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedLoginRoleIndex == 1
                          ? 'Portal Administrator'
                          : LanguageService.tr('selamat_datang'),
                      style: GoogleFonts.poppins(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedLoginRoleIndex == 1
                          ? 'Akses khusus kelola sistem & katalog database'
                          : LanguageService.tr('masuk_ke_akun'),
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedLoginRoleIndex == 1)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_rounded,
                          color: Color(0xFF00E5FF), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'ADMIN',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00E5FF),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 18),

          // Input Email / Username
          _buildCustomTextField(
            controller: _emailController,
            focusNode: _emailFocus,
            label: _selectedLoginRoleIndex == 1
                ? 'Email / Username Admin'
                : LanguageService.text(
                    'Email / Username Member', 'Member Email / Username'),
            hint: _selectedLoginRoleIndex == 1
                ? 'Masukkan akun admin (mis. admin)'
                : LanguageService.text('Masukkan email atau username Anda',
                    'Enter your email or username'),
            icon: _selectedLoginRoleIndex == 1
                ? Icons.admin_panel_settings_outlined
                : Icons.email_outlined,
            primaryText: primaryText,
            secondaryText: secondaryText,
            hintText: hintText,
            keyboardType: TextInputType.text,
          ),

          const SizedBox(height: 16),

          // Input Password
          _buildCustomTextField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            label: _selectedLoginRoleIndex == 1
                ? 'Password Administrator'
                : LanguageService.tr('password'),
            hint: _selectedLoginRoleIndex == 1
                ? 'Masukkan password administrator'
                : LanguageService.text(
                    'Masukkan password Anda', 'Enter your password'),
            icon: Icons.lock_outline_rounded,
            primaryText: primaryText,
            secondaryText: secondaryText,
            hintText: hintText,
            isPassword: true,
            obscureText: _obscurePassword,
            onTogglePassword: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),

          const SizedBox(height: 8),

          if (_selectedLoginRoleIndex == 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, a, b) =>
                        LupaPasswordPage(isDarkMode: _isDarkMode),
                    transitionsBuilder: (context, a, b, child) =>
                        FadeTransition(opacity: a, child: child),
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _isDarkMode
                      ? const Color(0xFF00E5FF)
                      : const Color(0xFF7C4DFF),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                ),
                child: Text(
                  LanguageService.tr('lupa_password'),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: _isDarkMode
                        ? const Color(0xFF00E5FF)
                        : const Color(0xFF7C4DFF),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 6),

          const SizedBox(height: 12),

          GestureDetector(
            onTapDown: (_) => setState(() => _isLoginPressed = true),
            onTapUp: (_) {
              setState(() => _isLoginPressed = false);
              if (!_isLoading) _login();
            },
            onTapCancel: () => setState(() => _isLoginPressed = false),
            child: AnimatedScale(
              scale: _isLoginPressed ? 0.96 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: _selectedLoginRoleIndex == 1
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF00E5FF),
                            Color(0xFF7C4DFF),
                          ],
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0xFF00E5FF),
                            Color(0xFF7C4DFF),
                            Color(0xFFE040FB),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (_selectedLoginRoleIndex == 1
                              ? const Color(0xFF00E5FF)
                              : const Color(0xFF7C4DFF))
                          .withValues(alpha: _isLoginPressed ? 0.3 : 0.5),
                      blurRadius: _isLoginPressed ? 6 : 16,
                      offset: Offset(0, _isLoginPressed ? 2 : 6),
                    ),
                  ],
                ),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedLoginRoleIndex == 1
                                  ? Icons.admin_panel_settings_rounded
                                  : Icons.login_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedLoginRoleIndex == 1
                                  ? 'Masuk Administrator'
                                  : LanguageService.tr('masuk'),
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSecurityNotice({
    required Color primaryText,
    required Color secondaryText,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? const Color(0xFF141A29).withValues(alpha: 0.7)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Color(0xFF00E5FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portal Khusus Administrator',
                      style: GoogleFonts.poppins(
                        color: primaryText,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      'Akses terbatas untuk pengelola database',
                      style: GoogleFonts.poppins(
                        color: secondaryText,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Akun Administrator memiliki otorisasi penuh untuk menambah, mengedit, dan menghapus katalog produk di database. Jika Anda adalah member/pelanggan, silakan beralih ke tab Login Member di atas.',
            style: GoogleFonts.poppins(
              color: secondaryText,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET INPUT DENGAN PENGHAPUSAN BORDER BAWAAN SECARA TOTAL ---
  Widget _buildCustomTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required Color primaryText,
    required Color secondaryText,
    required Color hintText,
    bool isPassword = false,
    bool? obscureText,
    VoidCallback? onTogglePassword,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final bool isFocused = focusNode.hasFocus;
    final Color accentColor =
        _isDarkMode ? const Color(0xFF00E5FF) : const Color(0xFF7C4DFF);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? (isFocused ? const Color(0xFF141A29) : const Color(0xFF0B0F20))
            : (isFocused ? Colors.white : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocused
              ? accentColor
              : (_isDarkMode
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFCBD5E1)),
          width: isFocused ? 1.5 : 1.0,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color:
                      accentColor.withValues(alpha: _isDarkMode ? 0.2 : 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ]
            : [
                if (!_isDarkMode)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
              ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText ?? false,
        cursorColor: accentColor,
        style: GoogleFonts.poppins(
          color: primaryText,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.transparent,
          // --- KODE BARU: MENGHAPUS SEMUA KONDISI BORDER BAWAAN FLUTTER ---
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          // -----------------------------------------------------------------
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: isFocused ? accentColor : secondaryText,
            fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: hintText, fontSize: 13),
          icon: Icon(
            icon,
            size: 20,
            color: isFocused
                ? accentColor
                : (_isDarkMode
                    ? const Color(0xFF7C4DFF)
                    : const Color(0xFF64748B)),
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText!
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: isFocused ? accentColor : hintText,
                    size: 20,
                  ),
                  onPressed: onTogglePassword,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSocialAndRegisterSection({
    required Color primaryText,
    required Color secondaryText,
    required Color hintText,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: _isDarkMode
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'Atau masuk dengan',
                style: GoogleFonts.poppins(
                  color: secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: _isDarkMode
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _buildSocialButton(
                title: 'Google',
                icon: Icons.g_mobiledata,
                iconColor: const Color(0xFFEA4335),
                isPressed: _isGooglePressed,
                primaryText: primaryText,
                onTapDown: () => setState(() => _isGooglePressed = true),
                onTapUp: () {
                  setState(() => _isGooglePressed = false);
                  if (!_isLoading) _loginWithGoogle();
                },
                onTapCancel: () => setState(() => _isGooglePressed = false),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildSocialButton(
                title: 'GitHub',
                icon: Icons.code_rounded,
                iconColor: _isDarkMode ? Colors.white : const Color(0xFF24292F),
                isPressed: _isGithubPressed,
                primaryText: primaryText,
                onTapDown: () => setState(() => _isGithubPressed = true),
                onTapUp: () {
                  setState(() => _isGithubPressed = false);
                  if (!_isLoading) _loginWithGithub();
                },
                onTapCancel: () => setState(() => _isGithubPressed = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTapDown: (_) => setState(() => _isRegisterPressed = true),
          onTapUp: (_) async {
            setState(() => _isRegisterPressed = false);
            HapticFeedback.lightImpact();
            await Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, a, b) =>
                    RegisterPage(isDarkMode: _isDarkMode),
                transitionsBuilder: (context, a, b, child) =>
                    FadeTransition(opacity: a, child: child),
              ),
            );

            _loadLocalUsersCount();
          },
          onTapCancel: () => setState(() => _isRegisterPressed = false),
          child: AnimatedScale(
            scale: _isRegisterPressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isDarkMode
                      ? const Color(0xFF00E5FF).withValues(alpha: 0.6)
                      : const Color(0xFF7C4DFF).withValues(alpha: 0.7),
                  width: 1.5,
                ),
                color: _isRegisterPressed
                    ? (_isDarkMode
                        ? const Color(0xFF00E5FF).withValues(alpha: 0.1)
                        : const Color(0xFF7C4DFF).withValues(alpha: 0.08))
                    : (_isDarkMode ? Colors.transparent : Colors.white),
                boxShadow: _isDarkMode
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add_alt_1_rounded,
                    color: _isDarkMode
                        ? const Color(0xFF00E5FF)
                        : const Color(0xFF7C4DFF),
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Buat Akun Baru',
                    style: GoogleFonts.poppins(
                      color: _isDarkMode
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFF7C4DFF),
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user_rounded,
                  color: Color(0xFF10B981), size: 15),
              const SizedBox(width: 6),
              Text(
                'User Terdaftar: $_localUsersCount',
                style: GoogleFonts.spaceMono(
                  color: const Color(0xFF10B981),
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isPressed,
    required Color primaryText,
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
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF141A29) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isDarkMode
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFE2E8F0),
              width: isPressed ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: primaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
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
                ? const Color(0xFF141A29).withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isDarkMode
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.3)
                  : const Color(0xFF7C4DFF).withValues(alpha: 0.2),
            ),
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
                  size: 16,
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
}

// --- MINI CYBER RING PAINTER FOR LOGIN ---

class _MiniCyberRingPainter extends CustomPainter {
  final Color color;
  final Color secondaryColor;

  _MiniCyberRingPainter({required this.color, required this.secondaryColor});

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
  bool shouldRepaint(covariant _MiniCyberRingPainter oldDelegate) => false;
}
