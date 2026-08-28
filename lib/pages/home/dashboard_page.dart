import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk status bar control
import 'package:google_fonts/google_fonts.dart'; // Tipografi Modern
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetech_xyz/constants/constants.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/pages/admin/admin_database_page.dart';
import 'package:vibetech_xyz/pages/auth/login_page.dart';
import 'package:vibetech_xyz/pages/common/contact_page.dart';
import 'package:vibetech_xyz/pages/common/data_layanan_page.dart';
import 'package:vibetech_xyz/pages/common/live_chat_page.dart';
import 'package:vibetech_xyz/pages/common/status_server_page.dart';
import 'package:vibetech_xyz/pages/common/total_pesanan_page.dart';
import 'package:vibetech_xyz/pages/home/keranjang_page.dart';
import 'package:vibetech_xyz/pages/home/produk_page.dart';
import 'package:vibetech_xyz/pages/home/profile_page.dart';
import 'package:vibetech_xyz/pages/payment/billing_page.dart';
import 'package:vibetech_xyz/pages/payment/topup_page.dart';
import 'package:vibetech_xyz/services/balance_service.dart';
import 'package:vibetech_xyz/services/cloud_sync_service.dart';
import 'package:vibetech_xyz/services/language_service.dart';
import 'package:vibetech_xyz/services/theme_service.dart';

/// ============================================================================
/// HALAMAN UTAMA DASHBOARD (MAIN DASHBOARD & BOTTOM NAVIGATION)
/// ============================================================================
/// Halaman pusat aplikasi yang menyediakan:
/// 1. Bottom Navigation Bar untuk berpindah tab (Beranda, Produk, Pesanan, Profil).
/// 2. Ringkasan saldo, statistik server aktif, promo diskon SQLite, dan aksi cepat.
/// 3. Navigasi menuju Live Chat CS, Keranjang, Panduan, dan Portal Admin.
class DashboardPage extends StatefulWidget {
  final String username;
  final bool isDarkMode;
  final String userRole;
  final String userEmail;

  const DashboardPage({
    super.key,
    this.username = 'demouser',
    this.isDarkMode = true,
    this.userRole = 'user',
    this.userEmail = 'user@vibetech.com',
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isDarkMode = true;
  String _activeEmail = 'user@vibetech.com';
  String _currentUserRole = 'user';
  String _activeUsername = '';
  String _activeAvatarUrl = '';
  int _totalOrdersCount = 0;

  // Floating particles
  final List<AppParticle> _particles = [];
  final math.Random _random = math.Random();
  late AnimationController _particleController;

  // Controllers & Animations
  late AnimationController _mainAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;

  List<Map<String, dynamic>> _dynamicActiveServices = [];
  Map<String, int> _serviceCounts = {
    'VPS': 0,
    'Panel': 0,
    'Bot WA': 0,
    'Total': 0,
  };

  // State Diskon Dinamis Real-Time dari SQLite Database
  double _maxDiscount = 0.0;
  int _discountedProductsCount = 0;
  String _discountedCategoryNames = 'VPS & Panel Hosting';
  String _topDiscountedProductName = '';

  @override
  void initState() {
    super.initState();
    _isDarkMode = ThemeService.isDarkMode;
    ThemeService.themeNotifier.addListener(_onThemeChanged);

    // Inisialisasi Partikel Cyber
    _particles.addAll(AppParticle.generateList(_random, count: 24));

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _particleController.addListener(() {
      AppParticle.updatePositions(_particles);
    });

    // Durasi diperpanjang untuk mengakomodasi staggered animation
    _mainAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation =
        Tween<double>(begin: 0.2, end: 0.5).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));

    _mainAnimationController.forward();
    _loadDashboardServicesFromDB();
  }

  Future<void> _loadDashboardServicesFromDB() async {
    try {
      String email = 'user@vibetech.com';
      String role = 'user';
      String username = widget.username;
      String avatar = 'https://cdn.nekohime.site/file/5232n74c.jpeg';
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedUid = prefs.getString('user_uid');
        final savedEmail = prefs.getString('email');
        final savedRole = prefs.getString('role');
        final savedUsername = prefs.getString('username');
        final savedAvatar = prefs.getString('avatarUrl');

        if (savedEmail != null && savedEmail.isNotEmpty) {
          email = savedEmail;
        }
        if (savedRole != null && savedRole.isNotEmpty) {
          role = savedRole;
        }
        if (savedUsername != null && savedUsername.isNotEmpty) {
          username = savedUsername;
        }
        if (savedAvatar != null && savedAvatar.isNotEmpty) {
          avatar = savedAvatar;
        }

        Map<String, dynamic>? user;
        if (savedUid != null && savedUid.isNotEmpty) {
          user = await DatabaseHelper.instance.getUserByUid(savedUid);
        }
        user ??= await DatabaseHelper.instance.getUserByEmail(email);
        user ??= await DatabaseHelper.instance.getUserByUsernameOrEmail(username);

        if (user != null) {
          if (user['email'] != null && user['email'].toString().isNotEmpty) {
            email = user['email'];
          }
          if (user['role'] != null && user['role'].toString().isNotEmpty) {
            role = user['role'];
          }
          if (user['nama'] != null && user['nama'].toString().isNotEmpty) {
            username = user['nama'];
          }
          if (user['avatarUrl'] != null &&
              user['avatarUrl'].toString().isNotEmpty) {
            avatar = user['avatarUrl'];
          }
        }
      } catch (_) {}

      _activeEmail = email;
      _currentUserRole = role.toLowerCase();
      _activeUsername = username;
      _activeAvatarUrl = avatar;
      await BalanceService.loadUserBalance(_activeEmail);
      CloudSyncService.instance.syncAllFromCloud();
      final rawServices =
          await DatabaseHelper.instance.getServicesByUser(email);
      final counts =
          await DatabaseHelper.instance.getServicesCountByCategory(email);

      final totalOrders = await DatabaseHelper.instance.getTotalOrdersCount(
        email,
        isAdmin: false,
        onlyProductPurchases: true,
      );

      // Hitung Diskon Aktif Secara Real-Time dari Katalog Produk SQLite
      final allProducts = await DatabaseHelper.instance.getAllProducts();
      double maxD = 0.0;
      int discountedCount = 0;
      final Set<String> discountedCategories = {};
      String topProduct = '';

      for (var p in allProducts) {
        final d = (p['diskon'] as num?)?.toDouble() ?? 0.0;
        if (d > 0) {
          discountedCount++;
          if (d > maxD) {
            maxD = d;
            topProduct = p['nama']?.toString() ?? '';
          }
          final cat = p['kategori']?.toString();
          if (cat != null && cat.trim().isNotEmpty) {
            discountedCategories.add(cat.trim());
          }
        }
      }

      String catNames = discountedCategories.join(' & ');
      if (catNames.isEmpty) {
        catNames = 'VPS & Panel Hosting';
      }

      if (mounted) {
        setState(() {
          _activeEmail = email;
          _currentUserRole = role.toLowerCase();
          _activeUsername = username;
          _activeAvatarUrl = avatar;
          _dynamicActiveServices = rawServices;
          _serviceCounts = counts;
          _totalOrdersCount = totalOrders;
          _maxDiscount = maxD;
          _discountedProductsCount = discountedCount;
          _discountedCategoryNames = catNames;
          _topDiscountedProductName = topProduct;
        });
      }
    } catch (_) {}
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
    _mainAnimationController.dispose();
    _pulseAnimationController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  bool get _isAdmin =>
      _currentUserRole == 'admin' ||
      _currentUserRole == 'administrator' ||
      widget.username.toLowerCase() == 'admin';

  // --- Helper Getters untuk Tema ---
  Color get _bgColor => _isDarkMode ? AppColors.darkBg : AppColors.lightBg;
  Color get _cardColor =>
      _isDarkMode ? AppColors.darkCard : AppColors.lightCard;
  Color get _cardBorder => _isDarkMode
      ? const Color(0xFF7C4DFF).withValues(alpha: 0.2)
      : const Color(0xFFE2E8F0);
  Color get _textPrimary =>
      _isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get _textSecondary =>
      _isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

  // --- Dynamic Greeting berdasarkan Waktu Indonesia ---
  String get _greetingText {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) {
      return LanguageService.text('Selamat Pagi,', 'Good Morning,');
    } else if (hour >= 11 && hour < 15) {
      return LanguageService.text('Selamat Siang,', 'Good Afternoon,');
    } else if (hour >= 15 && hour < 18) {
      return LanguageService.text('Selamat Sore,', 'Good Afternoon,');
    } else {
      return LanguageService.text('Selamat Malam,', 'Good Evening,');
    }
  }

  // --- WIDGET HELPER: Staggered Animation ---
  // Fungsi ini membuat elemen muncul bergiliran dari atas ke bawah
  Widget _buildStaggeredItem(Widget child, int index) {
    final start = (index * 0.1).clamp(0.0, 1.0);
    final end = (start + 0.4).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _mainAnimationController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
            .animate(animation),
        child: child,
      ),
    );
  }

  void _navigateToBilling({required String status}) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => BillingPage(
          isDarkMode: _isDarkMode,
          username: widget.username,
          userEmail: _activeEmail,
          status: status,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: _textSecondary),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.accent]),
              ),
              child: CircleAvatar(
                radius: 45,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 42,
                  backgroundImage: NetworkImage(_activeAvatarUrl.isNotEmpty
                      ? _activeAvatarUrl
                      : 'https://cdn.nekohime.site/file/5232n74c.jpeg'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _activeUsername.isNotEmpty ? _activeUsername : widget.username,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            Text(
              _activeEmail,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                gradient: _isAdmin
                    ? const LinearGradient(
                        colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
                      )
                    : null,
                color:
                    _isAdmin ? null : AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isAdmin ? 'Administrator' : 'Member Premium',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: _isAdmin ? Colors.white : AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Divider(color: _textSecondary.withValues(alpha: 0.1), height: 1),
            const SizedBox(height: 8),
            if (_isAdmin)
              _buildProfileMenuItem(
                Icons.admin_panel_settings_rounded,
                LanguageService.text('Portal Administrator', 'Admin Portal'),
                LanguageService.text('Kelola DB', 'Manage DB'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminDatabasePage(
                        isDarkMode: _isDarkMode,
                        currentAdminUsername: widget.username,
                        currentAdminEmail: _activeEmail,
                      ),
                    ),
                  ).then((_) => _loadDashboardServicesFromDB());
                },
              ),
            _buildProfileMenuItem(
                Icons.security_rounded, '2FA Keamanan', 'Aktif'),
            _buildProfileMenuItem(
                Icons.settings_outlined, 'Pengaturan Akun', ''),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileMenuItem(IconData icon, String title, String trailing,
      {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _isDarkMode
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
      title: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 14, color: _textPrimary, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing.isNotEmpty)
            Text(trailing,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: trailing == 'Aktif' || trailing.contains('DB')
                        ? AppColors.success
                        : _textSecondary)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 20, color: _textSecondary),
        ],
      ),
    );
  }

  /// Menangani aksi tap pada item Bottom Navigation Bar
  /// Memicu haptic feedback taktil ringan dan melakukan navigasi ke halaman terkait
  void _onItemTapped(int index) async {
    // Memberikan umpan balik getaran ringan pada perangkat
    HapticFeedback.lightImpact();
    setState(() => _selectedIndex = index);

    switch (index) {
      case 0:
        // Tab 0: Halaman Beranda (tetap di Dashboard)
        break;
      case 1:
        // Tab 1: Menuju Halaman Katalog Produk & Layanan
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProdukPage(
              isDarkMode: _isDarkMode,
              userRole: _currentUserRole,
              userEmail: _activeEmail,
            ),
          ),
        );
        // Memuat ulang data dashboard agar perubahan diskon langsung terupdate
        _loadDashboardServicesFromDB();
        // Mengembalikan indeks tab ke beranda setelah kembali
        if (mounted) {
          setState(() => _selectedIndex = 0);
        }
        break;

      case 2:
        // Tab 2: Menuju Halaman Keranjang Belanja
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => KeranjangPage(
              isDarkMode: _isDarkMode,
            ),
          ),
        );
        if (mounted) {
          setState(() => _selectedIndex = 0);
          _loadDashboardServicesFromDB();
        }
        break;
      case 3:
        // Tab 3: Menuju Halaman Profil Pengguna & Pengaturan
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfilePage(
              isDarkMode: _isDarkMode,
              username: _activeUsername.isNotEmpty
                  ? _activeUsername
                  : widget.username,
            ),
          ),
        );
        if (mounted) {
          setState(() => _selectedIndex = 0);
          _loadDashboardServicesFromDB();
        }
        break;
    }
  }

  /// Menghitung persentase sisa masa aktif server (0.0 sampai 1.0) untuk progress bar
  double _calculateExpiryProgress(String expiryDateStr) {
    try {
      final expiryDate = DateTime.parse(expiryDateStr);
      final now = DateTime.now();
      const totalDuration = 30; // Siklus default durasi sewa bulanan (30 hari)
      final daysLeft = expiryDate.difference(now).inDays;

      if (daysLeft <= 0) return 0.0; // Server telah kedaluwarsa
      if (daysLeft >= totalDuration) return 1.0; // Server baru aktif
      return daysLeft / totalDuration; // Rasio sisa hari
    } catch (_) {
      return 1.0;
    }
  }

  // --- KODE UI UTAMA & BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
      systemNavigationBarColor:
          _isDarkMode ? AppColors.darkCard : AppColors.lightCard,
      systemNavigationBarIconBrightness:
          _isDarkMode ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // 1. Background Cyber Gradient Matching Login Page
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: _isDarkMode
                    ? AppColors.darkBackgroundGradient
                    : AppColors.lightBackgroundGradient,
              ),
            ),
          ),

          // 2. Ambient Neon Glow Orbs in Dark Mode
          if (_isDarkMode)
            AppNeonOrbs(pulseAnimation: _pulseAnimationController),

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

          // 4. Foreground SafeArea & Layout
          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Brand Logo Title
                      Row(
                        children: [
                          Text(
                            'VIBE',
                            style: GoogleFonts.poppins(
                              color: _textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              letterSpacing: 1.5,
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
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              'XYZ',
                              style: GoogleFonts.spaceMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Action Buttons (Theme Switcher & Logout)
                      Row(
                        children: [
                          BounceTap(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ThemeService.toggleTheme();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _cardBorder),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                transitionBuilder: (child, anim) =>
                                    RotationTransition(
                                  turns: anim,
                                  child: ScaleTransition(
                                      scale: anim, child: child),
                                ),
                                child: Icon(
                                  _isDarkMode
                                      ? Icons.wb_sunny_outlined
                                      : Icons.nightlight_round,
                                  key: ValueKey(_isDarkMode),
                                  color: _isDarkMode
                                      ? const Color(0xFF00E5FF)
                                      : AppColors.primary,
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          BounceTap(
                            onTap: _showLogoutConfirmDialog,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _cardBorder),
                              ),
                              child: const Icon(
                                Icons.logout_rounded,
                                color: AppColors.error,
                                size: 19,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Main Content Body
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStaggeredItem(_buildHeaderProfile(), 0),
                        const SizedBox(height: 24),
                        _buildStaggeredItem(_buildQuickStats(), 1),
                        if (_isAdmin) ...[
                          const SizedBox(height: 20),
                          _buildStaggeredItem(_buildAdminPortalBanner(), 2),
                        ],
                        const SizedBox(height: 32),
                        _buildStaggeredItem(
                            _buildSectionTitle(LanguageService.text(
                                'Ikhtisar Layanan', 'Services Overview')),
                            3),
                        const SizedBox(height: 12),
                        _buildStaggeredItem(_buildServicesOverviewList(), 4),
                        const SizedBox(height: 32),
                        _buildStaggeredItem(
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionTitle(LanguageService.text(
                                    'Layanan Aktif', 'Active Services')),
                                TextButton.icon(
                                  onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => ProdukPage(
                                                isDarkMode: _isDarkMode,
                                                userRole: _currentUserRole,
                                                userEmail: _activeEmail,
                                              ))).then(
                                      (_) => _loadDashboardServicesFromDB()),
                                  icon: const Icon(
                                      Icons.add_shopping_cart_rounded,
                                      size: 16,
                                      color: AppColors.accent),
                                  label: Text(
                                    LanguageService.text(
                                        'Beli Baru', 'Buy New'),
                                    style: GoogleFonts.poppins(
                                        color: AppColors.accent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                            5),
                        const SizedBox(height: 12),
                        _buildStaggeredItem(
                            _buildActiveServicesDetailList(), 6),
                        const SizedBox(height: 32),
                        _buildStaggeredItem(
                            _buildSectionTitle(LanguageService.text(
                                'Menu Cepat', 'Quick Menu')),
                            7),
                        const SizedBox(height: 16),
                        _buildStaggeredItem(_buildQuickMenuGrid(), 8),
                        const SizedBox(height: 32),
                        _buildStaggeredItem(_buildPromoBanner(), 9),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // --- WIDGET BUILDER METHODS ---

  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        surfaceTintColor: Colors.transparent,
        title: Text('Konfirmasi',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: _textPrimary)),
        content: Text('Apakah Anda yakin ingin keluar dari aplikasi?',
            style: GoogleFonts.poppins(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal',
                style: GoogleFonts.poppins(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Logout',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: _textPrimary,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildHeaderProfile() {
    return Row(
      children: [
        BounceTap(
          onTap: _showProfileDialog,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: Lottie.network(
                  "https://lottie.host/8018e6ff-4cb9-43c2-9e90-c24719b33a01/4M3l33K8Bv.json",
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.accent]),
                ),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Colors.white),
                  child: ClipOval(
                    child: Image(
                      image: NetworkImage(_activeAvatarUrl.isNotEmpty
                          ? _activeAvatarUrl
                          : "https://cdn.nekohime.site/file/5232n74c.jpeg"),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greetingText,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: _textSecondary,
                ),
              ),
              Text(
                '${_activeUsername.isNotEmpty ? _activeUsername : widget.username} 👋',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: AppColors.success),
              SizedBox(width: 5),
              Text(
                'Online',
                style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: BounceTap(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TotalPesananPage(
                    isDarkMode: _isDarkMode,
                    username: widget.username,
                    userEmail: _activeEmail,
                    userRole: _currentUserRole,
                  ),
                ),
              ).then((_) => _loadDashboardServicesFromDB());
            },
            child: _buildStatCard(
              title: LanguageService.text('Total Pesanan', 'Total Orders'),
              targetValue: _totalOrdersCount.toDouble(),
              prefix: '',
              suffix: '',
              icon: Icons.shopping_bag_outlined,
              gradient: const LinearGradient(
                colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: BounceTap(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => TopUpPage(
                            isDarkMode: _isDarkMode,
                            username: widget.username,
                          ))).then((_) => _loadDashboardServicesFromDB());
            },
            child: ValueListenableBuilder<int>(
              valueListenable: BalanceService.notifier,
              builder: (context, currentBalance, child) {
                return _buildStatCard(
                  title: LanguageService.text('Saldo Pengguna', 'User Balance'),
                  targetValue: currentBalance.toDouble(),
                  prefix: 'Rp ',
                  suffix: '',
                  isCurrency: true,
                  icon: Icons.account_balance_wallet_outlined,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF472B6), Color(0xFFEC4899)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required double targetValue,
    required String prefix,
    required String suffix,
    required IconData icon,
    required Gradient gradient,
    bool isCurrency = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.last.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 18),
            ],
          ),
          const SizedBox(height: 10),
          // Animasi Angka berjalan naik dari 0 ke targetValue
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: targetValue),
            duration: const Duration(seconds: 2),
            curve: Curves.easeOutExpo,
            builder: (context, value, child) {
              final formattedNumber = isCurrency
                  ? NumberFormat('#,###', 'id_ID')
                      .format(value.toInt())
                      .replaceAll(',', '.')
                  : value.toInt().toString();
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$prefix$formattedNumber$suffix',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServicesOverviewList() {
    final overviewItems = [
      {
        'name': 'VPS Server',
        'icon': Icons.dns_rounded,
        'count': '${_serviceCounts['VPS'] ?? 0}',
        'color': const Color(0xFF818CF8),
        'tabIndex': 1,
      },
      {
        'name': 'WhatsApp Bot',
        'icon': Icons.chat_bubble_outline_rounded,
        'count': '${_serviceCounts['Bot WA'] ?? 0}',
        'color': const Color(0xFF34D399),
        'tabIndex': 3,
      },
      {
        'name': 'Panel Hosting',
        'icon': Icons.cloud_queue_rounded,
        'count': '${_serviceCounts['Panel'] ?? 0}',
        'color': const Color(0xFFF472B6),
        'tabIndex': 2,
      },
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemCount: overviewItems.length,
        itemBuilder: (context, index) {
          final service = overviewItems[index];
          final color = service['color'] as Color;
          final tabIndex = service['tabIndex'] as int;
          return BounceTap(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DataLayananPage(
                    isDarkMode: _isDarkMode,
                    userEmail: _activeEmail,
                    initialTabIndex: tabIndex,
                  ),
                ),
              ).then((_) => _loadDashboardServicesFromDB());
            },
            child: Container(
              width: 150,
              margin: const EdgeInsets.only(right: 12, bottom: 5, top: 5),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: _isDarkMode ? 0.2 : 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(service['icon'] as IconData,
                        color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service['count'] as String,
                          style: GoogleFonts.poppins(
                            color: _textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          service['name'] as String,
                          style: GoogleFonts.poppins(
                            color: _textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveServicesDetailList() {
    if (_dynamicActiveServices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _cardBorder),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 40, color: _textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 8),
              Text(
                LanguageService.text(
                    'Belum ada layanan aktif', 'No active services'),
                style: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount:
          _dynamicActiveServices.length > 5 ? 5 : _dynamicActiveServices.length,
      itemBuilder: (context, index) {
        final service = _dynamicActiveServices[index];
        final String name =
            service['nama_produk']?.toString() ?? 'Layanan VibeTech';
        final String category = service['kategori']?.toString() ?? 'VPS';
        final String specs =
            service['spesifikasi']?.toString() ?? 'Standard Spec';
        final double price = (service['harga'] as num?)?.toDouble() ?? 0.0;
        final String expStr = service['tanggal_kadaluarsa']?.toString() ??
            DateTime.now().add(const Duration(days: 30)).toIso8601String();

        DateTime expDate;
        try {
          expDate = DateTime.parse(expStr);
        } catch (_) {
          expDate = DateTime.now().add(const Duration(days: 30));
        }

        final daysLeft = expDate.difference(DateTime.now()).inDays;
        final progress = _calculateExpiryProgress(expStr);

        Color timerColor = AppColors.success;
        if (daysLeft < 7) {
          timerColor = AppColors.error;
        } else if (daysLeft < 14) {
          timerColor = AppColors.warning;
        }

        IconData getCategoryIcon() {
          if (category.toLowerCase().contains('vps')) {
            return Icons.dns_rounded;
          }
          if (category.toLowerCase().contains('panel') ||
              category.toLowerCase().contains('hosting')) {
            return Icons.cloud_rounded;
          }
          return Icons.chat_bubble_rounded;
        }

        Color getCategoryColor() {
          if (category.toLowerCase().contains('vps')) {
            return AppColors.primary;
          }
          if (category.toLowerCase().contains('panel') ||
              category.toLowerCase().contains('hosting')) {
            return AppColors.accent;
          }
          return const Color(0xFF10B981);
        }

        final cardThemeColor = getCategoryColor();

        return BounceTap(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DataLayananPage(
                  isDarkMode: _isDarkMode,
                ),
              ),
            ).then((_) => _loadDashboardServicesFromDB());
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _cardBorder),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: _isDarkMode ? 0.25 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardThemeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        getCategoryIcon(),
                        color: cardThemeColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                              fontSize: 15,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            specs,
                            style: GoogleFonts.poppins(
                              color: _textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Aktif',
                        style: GoogleFonts.poppins(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: _cardBorder, height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                color: timerColor, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              daysLeft > 0
                                  ? '$daysLeft ${LanguageService.tr('sisa_hari')}'
                                  : LanguageService.text(
                                      'Kadaluarsa', 'Expired'),
                              style: GoogleFonts.poppins(
                                color: timerColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 120,
                          child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: progress),
                              duration: const Duration(seconds: 1),
                              curve: Curves.easeOut,
                              builder: (context, val, _) {
                                return LinearProgressIndicator(
                                  value: val,
                                  backgroundColor:
                                      timerColor.withValues(alpha: 0.15),
                                  color: timerColor,
                                  minHeight: 4,
                                  borderRadius: BorderRadius.circular(2),
                                );
                              }),
                        ),
                      ],
                    ),
                    Text(
                      'Rp ${NumberFormat('#,###', 'id_ID').format(price.toInt()).replaceAll(',', '.')}',
                      style: GoogleFonts.poppins(
                        color: _isDarkMode
                            ? const Color(0xFF00E5FF)
                            : AppColors.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdminPortalBanner() {
    return BounceTap(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminDatabasePage(
              isDarkMode: _isDarkMode,
              currentAdminUsername: widget.username,
              currentAdminEmail: _activeEmail,
            ),
          ),
        ).then((_) => _loadDashboardServicesFromDB());
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF2E1065), // Deep Cyber Violet
              Color(0xFF581C87), // Rich Purple
              Color(0xFF7C3AED), // Vibrant Neon Purple
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFC084FC).withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE040FB),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'PORTAL ADMINISTRATOR',
                          style: GoogleFonts.spaceMono(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    LanguageService.text(
                      'Database Pengguna & Kredensial',
                      'User Database & Credentials',
                    ),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    LanguageService.text(
                      'Kelola Password, PIN, Username & Riwayat Pembelian seluruh akun.',
                      'Manage Password, PIN, Username & Purchase History for all accounts.',
                    ),
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMenuGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.85,
      children: [
        if (_isAdmin)
          _buildQuickMenuItem(
            Icons.admin_panel_settings_rounded,
            LanguageService.text('Portal Admin', 'Admin Portal'),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminDatabasePage(
                    isDarkMode: _isDarkMode,
                    currentAdminUsername: widget.username,
                    currentAdminEmail: _activeEmail,
                  ),
                ),
              ).then((_) => _loadDashboardServicesFromDB());
            },
          ),
        _buildQuickMenuItem(
            Icons.shopping_bag_outlined, LanguageService.tr('produk'), () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ProdukPage(
                        isDarkMode: _isDarkMode,
                        userRole: _currentUserRole,
                        userEmail: _activeEmail,
                      ))).then((_) => _loadDashboardServicesFromDB());
        }),
        _buildQuickMenuItem(
            Icons.shopping_cart_outlined, LanguageService.tr('keranjang'), () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      KeranjangPage(isDarkMode: _isDarkMode))).then(
              (_) => _loadDashboardServicesFromDB());
        }),
        _buildQuickMenuItem(Icons.receipt_long_outlined,
            LanguageService.text('Tagihan', 'Billing'), () {
          _navigateToBilling(status: 'MENUNGGU PEMBAYARAN');
        }),
        _buildQuickMenuItem(Icons.forum_outlined,
            LanguageService.text('Live Chat', 'Live Chat'), () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => LiveChatPage(isDarkMode: _isDarkMode)));
        }),
        _buildQuickMenuItem(Icons.headset_mic_outlined,
            LanguageService.text('Kontak', 'Contact'), () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ContactPage(isDarkMode: _isDarkMode)));
        }),
        _buildQuickMenuItem(Icons.account_balance_wallet_outlined,
            LanguageService.text('Top Up', 'Top Up'), () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => TopUpPage(
                        isDarkMode: _isDarkMode,
                        username: widget.username,
                      ))).then((_) => _loadDashboardServicesFromDB());
        }),
        _buildQuickMenuItem(Icons.receipt_long_rounded,
            LanguageService.text('Total Pesanan', 'Total Orders'), () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => TotalPesananPage(
                        isDarkMode: _isDarkMode,
                        username: widget.username,
                        userEmail: _activeEmail,
                        userRole: _currentUserRole,
                      ))).then((_) => _loadDashboardServicesFromDB());
        }),
        _buildQuickMenuItem(Icons.inventory_2_outlined,
            LanguageService.text('Data Layanan', 'My Services'), () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => DataLayananPage(
                        isDarkMode: _isDarkMode,
                        userEmail: _activeEmail,
                      ))).then((_) => _loadDashboardServicesFromDB());
        }),
      ],
    );
  }

  Widget _buildQuickMenuItem(IconData icon, String label, VoidCallback onTap) {
    return BounceTap(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardBorder),
              boxShadow: [
                BoxShadow(
                  color: _isDarkMode
                      ? const Color(0xFF7C4DFF).withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: _isDarkMode ? const Color(0xFF00E5FF) : AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: _textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBanner() {
    final bool hasActivePromo = _maxDiscount > 0;
    final String discountStr = _maxDiscount.toStringAsFixed(
        _maxDiscount.truncateToDouble() == _maxDiscount ? 0 : 1);

    final String bannerTitle = hasActivePromo
        ? LanguageService.text(
            '🔥 Promo Diskon $discountStr%!',
            '🔥 $discountStr% Special Promo!',
          )
        : LanguageService.text(
            '🚀 Layanan Cloud & VPS',
            '🚀 Cloud & VPS Services',
          );

    final String bannerDesc = hasActivePromo
        ? (_discountedProductsCount == 1 && _topDiscountedProductName.isNotEmpty
            ? LanguageService.text(
                'Dapatkan diskon $discountStr% spesial untuk $_topDiscountedProductName! Diskon otomatis terpotong saat pemesanan.',
                'Get special $discountStr% discount on $_topDiscountedProductName! Discount is automatically applied on order.',
              )
            : LanguageService.text(
                'Dapatkan diskon hingga $discountStr% untuk $_discountedProductsCount produk $_discountedCategoryNames! Diskon otomatis terpotong saat pemesanan.',
                'Get up to $discountStr% discount on $_discountedProductsCount $_discountedCategoryNames products! Discounts are automatically applied on order.',
              ))
        : LanguageService.text(
            'Deploy VPS, Web Panel Hosting, dan Bot WhatsApp dengan performa tinggi & uptime 99.9%!',
            'Deploy high-performance VPS, Web Hosting, and WhatsApp Bots with 99.9% uptime!',
          );

    final String buttonText = hasActivePromo
        ? LanguageService.text(
            'Klaim Diskon $discountStr%', 'Claim $discountStr% Off')
        : LanguageService.text('Pesan Sekarang', 'Order Now');

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return BounceTap(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProdukPage(
                  isDarkMode: _isDarkMode,
                  userRole: _currentUserRole,
                  userEmail: _activeEmail,
                ),
              ),
            ).then((_) => _loadDashboardServicesFromDB());
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: hasActivePromo
                  ? const LinearGradient(
                      colors: [
                        Color(0xFFFF5722),
                        Color(0xFF7C4DFF),
                        Color(0xFF00E5FF),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (hasActivePromo
                          ? const Color(0xFFFF5722)
                          : AppColors.accent)
                      .withValues(alpha: _pulseAnimation.value),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasActivePromo)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded,
                            color: Colors.amberAccent, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          LanguageService.text(
                            'DISKON OTOMATIS AKTIF',
                            'AUTOMATIC DISCOUNT ACTIVE',
                          ),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 9.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  bannerTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  bannerDesc,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    buttonText,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: hasActivePromo
                          ? const Color(0xFFFF5722)
                          : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Lottie.asset(
              "assets/animation/Promotions.json",
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.card_giftcard_rounded,
                    color: Colors.white, size: 50);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: _cardBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.35 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor:
                _isDarkMode ? const Color(0xFF00E5FF) : AppColors.primary,
            unselectedItemColor: _textSecondary.withValues(alpha: 0.5),
            selectedLabelStyle:
                GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle:
                GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: const Icon(Icons.home_rounded),
                label: LanguageService.tr('beranda'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.inventory_2_outlined),
                activeIcon: const Icon(Icons.inventory_2_rounded),
                label: LanguageService.tr('produk'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.shopping_cart_outlined),
                activeIcon: const Icon(Icons.shopping_cart_rounded),
                label: LanguageService.tr('keranjang'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline_rounded),
                activeIcon: const Icon(Icons.person_rounded),
                label: LanguageService.tr('profil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BounceTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const BounceTap({super.key, required this.child, required this.onTap});

  @override
  State<BounceTap> createState() => _BounceTapState();
}

class _BounceTapState extends State<BounceTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _controller.forward();
  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
