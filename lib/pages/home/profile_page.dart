import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibetech_xyz/constants/constants.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/pages/auth/login_page.dart';
import 'package:vibetech_xyz/pages/common/data_layanan_page.dart';
import 'package:vibetech_xyz/pages/common/notifikasi_page.dart';
import 'package:vibetech_xyz/pages/common/total_pesanan_page.dart';
import 'package:vibetech_xyz/services/cloud_sync_service.dart';
import 'package:vibetech_xyz/services/firebase_email_service.dart';
import 'package:vibetech_xyz/services/firebase_user_service.dart';
import 'package:vibetech_xyz/services/language_service.dart';
import 'package:vibetech_xyz/services/notification_service.dart';
import 'package:vibetech_xyz/services/theme_service.dart';

/// ============================================================================
/// HALAMAN PROFIL & PENGATURAN AKUN (PROFILE PAGE)
/// ============================================================================
/// Halaman ini mengelola:
/// 1. Informasi identitas pengguna (Nama, Username, Email, No. HP, Lokasi, Avatar).
/// 2. Pengaturan keamanan (Ubah Password, Toggle 2FA Authenticator).
/// 3. Pemilihan preferensi bahasa (Indonesia / English).
/// 4. Notifikasi dan fitur Logout / Keluar Akun.
class ProfilePage extends StatefulWidget {
  final bool isDarkMode;
  final String username;

  const ProfilePage({
    super.key,
    required this.isDarkMode,
    required this.username,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  late AnimationController _mainAnimationController;
  late AnimationController _headerAnimationController;
  late Animation<double> _headerScaleAnimation;
  late bool _isDarkMode;

  // --- STATE USER DARI DATABASE ---
  late String _currentUsername;
  String _userUid = '';
  String _displayName = '';
  String _email = '';
  String _phone = '';
  String _location = '';
  String _avatarUrl = '';
  String _currentUserRole = 'user';
  bool _is2FA = true;
  bool _isLoadingDB = true;

  // Statistik Dinamis (Pesanan, Layanan, Transaksi)
  int _pesananCount = 0;
  int _layananCount = 0;
  int _transaksiCount = 0;

  bool get _isAdmin =>
      _currentUserRole.toLowerCase() == 'admin' ||
      _currentUserRole.toLowerCase() == 'administrator';

  // Notifikasi toggle state
  bool _pushNotification = true;
  bool _emailNotification = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode = ThemeService.isDarkMode;
    ThemeService.themeNotifier.addListener(_onThemeChanged);
    _currentUsername = widget.username;

    _mainAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _headerScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _mainAnimationController.forward();
    _headerAnimationController.forward();

    _loadUserDataFromDB();
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
    _headerAnimationController.dispose();
    super.dispose();
  }

  // =====================================================
  // ===         DATABASE SYNC / LOAD DATA             ===
  // =====================================================
  Future<void> _loadUserDataFromDB() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUid = prefs.getString('user_uid');
      final savedEmail = prefs.getString('email');
      final savedUsername = prefs.getString('username');

      Map<String, dynamic>? user;
      if (savedUid != null && savedUid.isNotEmpty) {
        user = await DatabaseHelper.instance.getUserByUid(savedUid);
      }
      if (user == null && savedEmail != null && savedEmail.isNotEmpty) {
        user = await DatabaseHelper.instance.getUserByEmail(savedEmail);
      }
      if (user == null && savedUsername != null && savedUsername.isNotEmpty) {
        user = await DatabaseHelper.instance
            .getUserByUsernameOrEmail(savedUsername);
      }
      user ??= await DatabaseHelper.instance
          .getUserByUsernameOrEmail(_currentUsername);

      if (user == null) {
        // 1. Coba cari & unduh dari Cloud Firebase terlebih dahulu
        try {
          final cloudUser = await FirebaseUserService.instance
              .getUserFromFirebase(savedEmail ?? savedUsername ?? _currentUsername);
          if (cloudUser != null) {
            final registeredUser = {
              'uid': cloudUser['uid'] ??
                  'usr_${DateTime.now().millisecondsSinceEpoch}',
              'nama': cloudUser['nama'] ?? _currentUsername,
              'username': cloudUser['username'] ??
                  _currentUsername.toLowerCase().replaceAll(' ', '_'),
              'email': cloudUser['email'] ??
                  '${_currentUsername.toLowerCase().replaceAll(' ', '_')}@vibetech.xyz',
              'phone': cloudUser['phone'] ?? '081234567890',
              'password': cloudUser['password'] ?? 'password123',
              'pin': cloudUser['pin'] ?? '123456',
              'role': cloudUser['role'] ?? 'user',
              'saldo': (cloudUser['saldo'] as num?)?.toDouble() ?? 0.0,
              'location': cloudUser['location'] ?? 'Jakarta, Indonesia',
              'avatarUrl': cloudUser['avatarUrl'] ??
                  'https://cdn.nekohime.site/file/5232n74c.jpeg',
              'is2FA': (cloudUser['is2FA'] as num?)?.toInt() ?? 1,
              'language': cloudUser['language'] ?? 'Indonesia',
              'createdAt': cloudUser['createdAt'] ??
                  DateTime.now().toIso8601String(),
            };
            await DatabaseHelper.instance.registerUser(registeredUser);
            user = registeredUser;
          }
        } catch (_) {}
      }

      if (user == null) {
        // Fallback: daftarkan user jika belum ada di DB
        final newUser = {
          'uid': 'usr_${DateTime.now().millisecondsSinceEpoch}',
          'nama': _currentUsername,
          'username': _currentUsername.toLowerCase().replaceAll(' ', '_'),
          'email':
              '${_currentUsername.toLowerCase().replaceAll(' ', '_')}@vibetech.xyz',
          'phone': '081234567890',
          'password': 'password123',
          'location': 'Jakarta, Indonesia',
          'avatarUrl': 'https://cdn.nekohime.site/file/5232n74c.jpeg',
          'is2FA': 1,
          'language': 'Indonesia',
          'role': 'User',
          'createdAt': DateTime.now().toIso8601String(),
        };
        await DatabaseHelper.instance.registerUser(newUser);
        user = newUser;
      }

      final uid = user['uid']?.toString() ?? '';
      final name = user['nama'] ?? user['username'] ?? _currentUsername;
      final email = user['email'] ??
          '${_currentUsername.toLowerCase().replaceAll(' ', '_')}@vibetech.xyz';

      final savedAvatar = prefs.getString('avatarUrl') ?? '';
      String avatar = savedAvatar;
      if (user['avatarUrl'] != null &&
          user['avatarUrl'].toString().isNotEmpty) {
        avatar = user['avatarUrl'].toString();
      } else if (avatar.isEmpty) {
        final cleanUser = (user['username'] ?? name)
            .toString()
            .toLowerCase()
            .replaceAll(' ', '_');
        avatar = 'https://avatars.githubusercontent.com/$cleanUser';
      }

      final role =
          (user['role'] ?? prefs.getString('role') ?? 'user').toString();

      if (uid.isNotEmpty) await prefs.setString('user_uid', uid);
      await prefs.setString('username', name);
      await prefs.setString('email', email);
      await prefs.setString('avatarUrl', avatar);
      await prefs.setString('role', role);

      await NotificationService.init(name);
      CloudSyncService.instance.syncAllFromCloud();

      // Hitung Data Realtime: Pesanan, Layanan, dan Transaksi Pengguna
      int pesanan = 0;
      int layanan = 0;
      int transaksi = 0;

      try {
        final txs = await DatabaseHelper.instance.getTransactionsByUser(email);
        final services = await DatabaseHelper.instance.getServicesByUser(email);
        pesanan = txs.where((t) {
          final pName = (t['nama_produk'] ?? '').toString().toLowerCase();
          final inv = (t['invoice_no'] ?? '').toString().toLowerCase();
          return !pName.contains('top up') && !inv.contains('topup');
        }).length;
        layanan = services.length;
        transaksi = txs.length;
      } catch (err) {
        debugPrint('[ProfilePage] Error hitung statistik pengguna: $err');
      }

      if (mounted) {
        setState(() {
          _userUid = uid;
          _displayName = name;
          _email = email;
          _phone = user!['phone'] ?? '+62 812 3456 7890';
          _location = user['location'] ?? 'Jakarta, Indonesia';
          _avatarUrl = avatar;
          _currentUserRole = role.toLowerCase();
          _is2FA = (user['is2FA'] ?? 1) == 1;
          _pushNotification = NotificationService.isPushEnabled;
          _emailNotification = NotificationService.isEmailEnabled;
          _pesananCount = pesanan;
          _layananCount = layanan;
          _transaksiCount = transaksi;
          _isLoadingDB = false;
          _currentUsername = name;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data from DB: $e');
      if (mounted) {
        setState(() {
          _displayName = _currentUsername;
          _email = '${_currentUsername.toLowerCase()}@vibetech.xyz';
          _phone = '+62 812 3456 7890';
          _location = 'Jakarta, Indonesia';
          _currentUserRole = 'user';
          _avatarUrl = 'https://cdn.nekohime.site/file/5232n74c.jpeg';
          _isLoadingDB = false;
        });
      }
    }
  }

  // --- Theme Helpers ---
  Color get _bgColor => _isDarkMode ? AppColors.darkBg : AppColors.lightBg;
  Color get _cardColor =>
      _isDarkMode ? AppColors.darkCard : AppColors.lightCard;
  Color get _textPrimary =>
      _isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get _textSecondary =>
      _isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

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

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
    ));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: _bgColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: _buildBounceTap(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.only(left: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: _textPrimary, size: 18),
            ),
          ),
          title: Text(
            LanguageService.tr('profil_saya'),
            style: GoogleFonts.poppins(
              color: _textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _buildBounceTap(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isDarkMode = !_isDarkMode);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, anim) => RotationTransition(
                      turns: anim,
                      child: ScaleTransition(scale: anim, child: child),
                    ),
                    child: Icon(
                      _isDarkMode
                          ? Icons.wb_sunny_outlined
                          : Icons.nightlight_round,
                      key: ValueKey(_isDarkMode),
                      color: _isDarkMode ? Colors.amber : AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: _isLoadingDB
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --- HEADER PROFIL ---
                    _buildStaggeredItem(_buildProfileHeader(), 0),
                    const SizedBox(height: 24),

                    // --- STATS ROW ---
                    _buildStaggeredItem(_buildStatsRow(), 1),
                    const SizedBox(height: 28),

                    // --- INFORMASI AKUN ---
                    _buildStaggeredItem(
                        _buildSectionTitle(
                            LanguageService.tr('informasi_akun')),
                        2),
                    const SizedBox(height: 12),
                    _buildStaggeredItem(_buildAccountInfoCard(), 3),
                    const SizedBox(height: 28),

                    // --- PENGATURAN ---
                    _buildStaggeredItem(
                        _buildSectionTitle(LanguageService.tr('pengaturan')),
                        4),
                    const SizedBox(height: 12),
                    _buildStaggeredItem(_buildSettingsCard(), 5),
                    const SizedBox(height: 28),

                    // --- NOTIFIKASI ---
                    _buildStaggeredItem(
                        _buildSectionTitle(LanguageService.tr('notifikasi')),
                        6),
                    const SizedBox(height: 12),
                    _buildStaggeredItem(_buildNotificationSettings(), 7),
                    const SizedBox(height: 28),

                    // --- TENTANG ---
                    _buildStaggeredItem(
                        _buildSectionTitle(LanguageService.tr('lainnya')), 8),
                    const SizedBox(height: 12),
                    _buildStaggeredItem(_buildOtherCard(), 9),
                    const SizedBox(height: 24),

                    // --- LOGOUT BUTTON ---
                    _buildStaggeredItem(_buildLogoutButton(), 10),
                    const SizedBox(height: 16),

                    // --- VERSION ---
                    _buildStaggeredItem(
                      Text(
                        'VibeTech v1.0.0',
                        style: GoogleFonts.poppins(
                          color: _textSecondary.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      11,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
      ),
    );
  }

  // =====================================================
  // ===         PROFILE HEADER WITH AVATAR            ===
  // =====================================================
  Widget _buildProfileHeader() {
    return ScaleTransition(
      scale: _headerScaleAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            // Avatar with glowing ring
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5), width: 3),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: ClipOval(
                      child: Image.network(
                        _avatarUrl.isNotEmpty
                            ? _avatarUrl
                            : 'https://cdn.nekohime.site/file/5232n74c.jpeg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Image.network(
                          'https://cdn.nekohime.site/file/5232n74c.jpeg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: _buildBounceTap(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showEditProfileDialog();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 16, color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _displayName.isNotEmpty ? _displayName : _currentUsername,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _email,
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium_rounded,
                      color: Colors.amber, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Member Premium',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // ===               STATS ROW                       ===
  // =====================================================
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildBounceTap(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TotalPesananPage(
                    isDarkMode: _isDarkMode,
                    userRole: _currentUserRole,
                    username: _displayName,
                    userEmail: _email,
                  ),
                ),
              ).then((_) => _loadUserDataFromDB());
            },
            child: _buildStatItem(
              icon: Icons.shopping_bag_outlined,
              value: '$_pesananCount',
              label: LanguageService.tr('pesanan'),
              color: const Color(0xFF818CF8),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBounceTap(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DataLayananPage(
                    isDarkMode: _isDarkMode,
                    userEmail: _email,
                  ),
                ),
              ).then((_) => _loadUserDataFromDB());
            },
            child: _buildStatItem(
              icon: Icons.cloud_queue_rounded,
              value: '$_layananCount',
              label: LanguageService.tr('layanan'),
              color: const Color(0xFF34D399),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBounceTap(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TotalPesananPage(
                    isDarkMode: _isDarkMode,
                    userRole: _currentUserRole,
                    username: _displayName,
                    userEmail: _email,
                  ),
                ),
              ).then((_) => _loadUserDataFromDB());
            },
            child: _buildStatItem(
              icon: Icons.receipt_long_outlined,
              value: '$_transaksiCount',
              label: LanguageService.tr('transaksi'),
              color: const Color(0xFFF472B6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _textSecondary.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: double.tryParse(value) ?? 0),
            duration: const Duration(seconds: 1),
            curve: Curves.easeOutExpo,
            builder: (context, val, child) {
              return Text(
                val.toInt().toString(),
                style: GoogleFonts.poppins(
                  color: _textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // ===          SECTION TITLE                        ===
  // =====================================================
  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _cardColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: _isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : const Color(0xFFE2E8F0),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: _isDarkMode
              ? Colors.black.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // =====================================================
  // ===          INFORMASI AKUN CARD                  ===
  // =====================================================
  Widget _buildAccountInfoCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildInfoTile(
            icon: Icons.person_outline_rounded,
            label: LanguageService.tr('nama_lengkap'),
            value: _displayName,
          ),
          _buildDivider(),
          _buildInfoTile(
            icon: Icons.email_outlined,
            label: LanguageService.tr('email'),
            value: _email,
          ),
          _buildDivider(),
          _buildInfoTile(
            icon: Icons.phone_outlined,
            label: LanguageService.tr('no_telepon'),
            value: _phone,
          ),
          _buildDivider(),
          _buildInfoTile(
            icon: Icons.location_on_outlined,
            label: LanguageService.tr('lokasi'),
            value: _location,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: _textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // ===          SETTINGS CARD                        ===
  // =====================================================
  Widget _buildSettingsCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.edit_outlined,
            label: LanguageService.tr('edit_profil'),
            onTap: _showEditProfileDialog,
            subtitle: '.................................',
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.lock_outline_rounded,
            label: LanguageService.tr('ubah_password'),
            onTap: _showChangePasswordDialog,
            subtitle: '',
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.pin_outlined,
            label: LanguageService.text(
                'Ubah PIN Pembayaran', 'Change Payment PIN'),
            trailing: _buildBadge(LanguageService.text('6 Digit', '6 Digits'),
                const Color(0xFF00BCD4)),
            onTap: _showChangePinDialog,
            subtitle: '',
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.security_rounded,
            label: LanguageService.tr('2fa_keamanan'),
            trailing: _buildBadge(
                _is2FA
                    ? LanguageService.tr('aktif')
                    : LanguageService.tr('nonaktif'),
                _is2FA ? AppColors.success : AppColors.error),
            onTap: _toggle2FAKeamanan,
            subtitle: '',
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.language_rounded,
            label: LanguageService.tr('bahasa'),
            trailing: Text(
              LanguageService.isEnglish ? 'English' : 'Indonesia',
              style: GoogleFonts.poppins(
                color: _textSecondary,
                fontSize: 13,
              ),
            ),
            onTap: _showLanguageDialog,
            subtitle: '',
          ),
        ],
      ),
    );
  }

  // =====================================================
  // ===     NOTIFICATION SETTINGS CARD                ===
  // =====================================================
  Widget _buildNotificationSettings() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildSwitchTile(
            icon: Icons.notifications_active_outlined,
            label: LanguageService.tr('push_notification'),
            subtitle: LanguageService.text(
              'Terima alert instan di perangkat (Server, Tagihan, Promo)',
              'Receive instant device alerts (Server, Billing, Promo)',
            ),
            value: _pushNotification,
            onChanged: (val) {
              setState(() => _pushNotification = val);
              NotificationService.setPushEnabled(val, _currentUsername);
              if (val) {
                NotificationService.showInAppNotification(
                  context,
                  title: 'Push Notifikasi Aktif! 🔔',
                  message:
                      'Anda akan menerima pemberitahuan langsung di aplikasi.',
                  type: 'info',
                );
              } else {
                _showSnackbarInfo(LanguageService.text(
                    'Push notifikasi dinonaktifkan',
                    'Push notification disabled'));
              }
            },
          ),
          _buildDivider(),
          _buildSwitchTile(
            icon: Icons.email_outlined,
            label: LanguageService.tr('email_notification'),
            subtitle: LanguageService.text(
              'Kirim salinan invoice & laporan keamanan ke $_email',
              'Send invoice copies & security alerts to $_email',
            ),
            value: _emailNotification,
            onChanged: (val) {
              setState(() => _emailNotification = val);
              NotificationService.setEmailEnabled(val, _currentUsername);
              if (val) {
                _showSnackbarInfo(LanguageService.text(
                    '📧 Notifikasi email diaktifkan untuk $_email',
                    '📧 Email notification enabled for $_email'));
              } else {
                _showSnackbarInfo(LanguageService.text(
                    'Notifikasi email dinonaktifkan',
                    'Email notification disabled'));
              }
            },
          ),
          if (_isAdmin) ...[
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.mark_email_read_outlined,
              label: LanguageService.text('Konfigurasi Server Email (SMTP)',
                  'Email Server Setup (SMTP)'),
              subtitle: LanguageService.text(
                'Tersimpan permanen & otomatis untuk seluruh notifikasi',
                'Permanently saved & automated for all notifications',
              ),
              trailing: _buildBadge(
                  LanguageService.text('Aktif Permanen', 'Permanent Active'),
                  AppColors.success),
              onTap: _showSmtpConfigDialog,
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.science_outlined,
              label: LanguageService.text(
                  'Uji Coba Pengiriman Notifikasi & Email',
                  'Test Notification & Email Delivery'),
              trailing: _buildBadge(
                  LanguageService.text('Administrator', 'Admin'),
                  AppColors.accent),
              onTap: () {
                NotificationService.showTestNotificationSheet(
                  context,
                  username:
                      _displayName.isNotEmpty ? _displayName : _currentUsername,
                  userEmail: _email,
                  isDarkMode: _isDarkMode,
                );
              },
              subtitle: '',
            ),
          ],
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.notifications_none_rounded,
            label: LanguageService.text(
                'Buka Pusat Notifikasi', 'Open Notification Center'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.primary),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotifikasiPage(isDarkMode: _isDarkMode),
                ),
              );
            },
            subtitle: '..........................',
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: _textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // ===           OTHER / ABOUT CARD                  ===
  // =====================================================
  Widget _buildOtherCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.help_outline_rounded,
            label: LanguageService.tr('pusat_bantuan'),
            onTap: () => _showSnackbarInfo(LanguageService.text(
                'Pusat Bantuan - Hubungi Customer Care',
                'Help Center - Contact Customer Care')),
            subtitle: '.',
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.info_outline_rounded,
            label: LanguageService.tr('tentang_aplikasi'),
            onTap: _showAboutDialog,
            subtitle: '.',
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.star_outline_rounded,
            label: LanguageService.tr('beri_rating'),
            onTap: () => _showSnackbarInfo(LanguageService.text(
                'Terima kasih atas penilaian Anda! ⭐⭐⭐⭐⭐',
                'Thank you for your rating! ⭐⭐⭐⭐⭐')),
            subtitle: '.....',
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: LanguageService.tr('kebijakan_privasi'),
            onTap: () => _showSnackbarInfo(LanguageService.text(
                'Data Anda aman bersama VibeTech XYZ.',
                'Your data is safe with VibeTech XYZ.')),
            subtitle: '........',
          ),
        ],
      ),
    );
  }

  // =====================================================
  // ===           LOGOUT BUTTON                       ===
  // =====================================================
  Widget _buildLogoutButton() {
    return _buildBounceTap(
      onTap: () => _showLogoutConfirmDialog(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Text(
              LanguageService.tr('keluar_dari_akun'),
              style: GoogleFonts.poppins(
                color: AppColors.error,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // ===          FITUR 1: EDIT PROFIL DIALOG          ===
  // =====================================================
  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _displayName);
    final emailController = TextEditingController(text: _email);
    final phoneController = TextEditingController(text: _phone);
    final locationController = TextEditingController(text: _location);
    final avatarController = TextEditingController(text: _avatarUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        surfaceTintColor: const Color.fromARGB(0, 252, 249, 249),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Edit Profil',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                  fontSize: 18),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogTextField(
                controller: nameController,
                label: 'Nama Lengkap',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
              _buildDialogTextField(
                controller: emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _buildDialogTextField(
                controller: phoneController,
                label: 'No. Telepon',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildDialogTextField(
                controller: locationController,
                label: 'Lokasi',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 12),
              _buildDialogTextField(
                controller: avatarController,
                label: 'URL Foto Profil',
                icon: Icons.image_outlined,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal',
                style: GoogleFonts.poppins(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newEmail = emailController.text.trim();
              final newPhone = phoneController.text.trim();
              final newLocation = locationController.text.trim();
              final newAvatar = avatarController.text.trim();

              if (newName.isEmpty || newEmail.isEmpty) {
                _showSnackbarInfo('Nama dan Email tidak boleh kosong!');
                return;
              }

              final updatedData = {
                'nama': newName,
                'username': newName.toLowerCase().replaceAll(' ', '_'),
                'email': newEmail,
                'phone': newPhone,
                'location': newLocation,
                'avatarUrl': newAvatar.isNotEmpty
                    ? newAvatar
                    : (_avatarUrl.isNotEmpty
                        ? _avatarUrl
                        : 'https://cdn.nekohime.site/file/5232n74c.jpeg'),
              };

              int rows = 0;
              if (_userUid.isNotEmpty) {
                rows = await DatabaseHelper.instance
                    .updateUserByUid(_userUid, updatedData);
              }
              if (rows == 0 && _email.isNotEmpty) {
                rows = await DatabaseHelper.instance
                    .updateUserProfile(_email, updatedData);
              }
              if (rows == 0) {
                rows = await DatabaseHelper.instance
                    .updateUserProfile(_currentUsername, updatedData);
              }

              // Update SharedPreferences secara permanen
              final prefs = await SharedPreferences.getInstance();
              if (_userUid.isNotEmpty) {
                await prefs.setString('user_uid', _userUid);
              }
              await prefs.setString('username', newName);
              await prefs.setString('email', newEmail);
              if (newAvatar.isNotEmpty) {
                await prefs.setString('avatarUrl', newAvatar);
              }

              setState(() {
                _displayName = newName;
                _email = newEmail;
                _phone = newPhone;
                _location = newLocation;
                _avatarUrl = newAvatar.isNotEmpty
                    ? newAvatar
                    : (_avatarUrl.isNotEmpty
                        ? _avatarUrl
                        : 'https://cdn.nekohime.site/file/5232n74c.jpeg');
                _currentUsername = newName;
              });

              if (context.mounted) Navigator.pop(context);
              _showSnackbarSuccess(
                  'Profil berhasil diperbarui dan disimpan permanen di database!');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Simpan',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // ===       FITUR 2: UBAH PASSWORD DIALOG           ===
  // =====================================================
  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_reset_rounded,
                    color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Ubah Password',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                    fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(
                  controller: currentPassController,
                  label: 'Password Saat Ini',
                  icon: Icons.lock_outline,
                  obscureText: obscureCurrent,
                  onToggleObscure: () =>
                      setDialogState(() => obscureCurrent = !obscureCurrent),
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  controller: newPassController,
                  label: 'Password Baru',
                  icon: Icons.lock_clock_outlined,
                  obscureText: obscureNew,
                  onToggleObscure: () =>
                      setDialogState(() => obscureNew = !obscureNew),
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  controller: confirmPassController,
                  label: 'Konfirmasi Password Baru',
                  icon: Icons.check_circle_outline_rounded,
                  obscureText: obscureConfirm,
                  onToggleObscure: () =>
                      setDialogState(() => obscureConfirm = !obscureConfirm),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal',
                  style: GoogleFonts.poppins(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final currentPass = currentPassController.text.trim();
                final newPass = newPassController.text.trim();
                final confirmPass = confirmPassController.text.trim();

                if (currentPass.isEmpty ||
                    newPass.isEmpty ||
                    confirmPass.isEmpty) {
                  _showSnackbarInfo('Semua field password harus diisi!');
                  return;
                }

                if (newPass.length < 6) {
                  _showSnackbarInfo('Password baru minimal 6 karakter!');
                  return;
                }

                if (newPass != confirmPass) {
                  _showSnackbarInfo('Konfirmasi password tidak cocok!');
                  return;
                }

                final userIdentifier = _userUid.isNotEmpty
                    ? _userUid
                    : (_email.isNotEmpty ? _email : _currentUsername);

                // Verifikasi password lama ke database
                final isValidPass = await DatabaseHelper.instance
                    .verifyUserPassword(userIdentifier, currentPass);

                if (!isValidPass) {
                  _showSnackbarError('Password saat ini salah!');
                  return;
                }

                // Update password di SQLite
                await DatabaseHelper.instance
                    .updateUserPassword(userIdentifier, newPass);
                if (_email.isNotEmpty && _email != userIdentifier) {
                  await DatabaseHelper.instance
                      .updateUserPassword(_email, newPass);
                }

                if (context.mounted) Navigator.pop(context);
                _showSnackbarSuccess(
                    'Password berhasil diperbarui di database!');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Ubah Password',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // ===    FITUR: UBAH PIN PEMBAYARAN DIALOG          ===
  // =====================================================
  void _showChangePinDialog() {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pin_rounded,
                    color: Color(0xFF00BCD4), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LanguageService.text(
                          'Ubah PIN Pembayaran', 'Change Payment PIN'),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                          fontSize: 16),
                    ),
                    Text(
                      LanguageService.text(
                          'PIN 6-digit untuk keamanan transaksi',
                          '6-digit PIN for transaction security'),
                      style: GoogleFonts.poppins(
                          color: _textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(
                  controller: currentPinController,
                  label: LanguageService.text('PIN Saat Ini', 'Current PIN'),
                  icon: Icons.pin_outlined,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  letterSpacing: 4,
                  obscureText: obscureCurrent,
                  onToggleObscure: () =>
                      setDialogState(() => obscureCurrent = !obscureCurrent),
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  controller: newPinController,
                  label: LanguageService.text(
                      'PIN Baru (6 Digit)', 'New PIN (6 Digits)'),
                  icon: Icons.lock_outline_rounded,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  letterSpacing: 4,
                  obscureText: obscureNew,
                  onToggleObscure: () =>
                      setDialogState(() => obscureNew = !obscureNew),
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  controller: confirmPinController,
                  label: LanguageService.text(
                      'Konfirmasi PIN Baru', 'Confirm New PIN'),
                  icon: Icons.check_circle_outline_rounded,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  letterSpacing: 4,
                  obscureText: obscureConfirm,
                  onToggleObscure: () =>
                      setDialogState(() => obscureConfirm = !obscureConfirm),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(LanguageService.tr('batal'),
                  style: GoogleFonts.poppins(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final currentPin = currentPinController.text.trim();
                final newPin = newPinController.text.trim();
                final confirmPin = confirmPinController.text.trim();

                if (currentPin.isEmpty ||
                    newPin.isEmpty ||
                    confirmPin.isEmpty) {
                  _showSnackbarInfo(LanguageService.text(
                      'Semua field PIN harus diisi!',
                      'All PIN fields must be filled!'));
                  return;
                }

                if (newPin.length != 6 || int.tryParse(newPin) == null) {
                  _showSnackbarInfo(LanguageService.text(
                      'PIN Baru harus berupa 6 digit angka!',
                      'New PIN must be 6 numeric digits!'));
                  return;
                }

                if (newPin != confirmPin) {
                  _showSnackbarInfo(LanguageService.text(
                      'Konfirmasi PIN tidak cocok!',
                      'PIN confirmation does not match!'));
                  return;
                }

                final userIdentifier = _userUid.isNotEmpty
                    ? _userUid
                    : (_email.isNotEmpty ? _email : _currentUsername);

                // Verifikasi PIN saat ini langsung ke SQLite
                final isValidPin = await DatabaseHelper.instance
                    .verifyUserPin(userIdentifier, currentPin);

                if (!isValidPin) {
                  _showSnackbarError(LanguageService.text(
                      'PIN saat ini salah!', 'Current PIN is incorrect!'));
                  return;
                }

                // Update PIN di SQLite untuk akun pengguna aktif
                await DatabaseHelper.instance
                    .updateUserPin(userIdentifier, newPin);
                if (_email.isNotEmpty && _email != userIdentifier) {
                  await DatabaseHelper.instance.updateUserPin(_email, newPin);
                }
                if (_displayName.isNotEmpty && _displayName != userIdentifier) {
                  await DatabaseHelper.instance
                      .updateUserPin(_displayName, newPin);
                }

                if (context.mounted) Navigator.pop(context);
                _showSnackbarSuccess(LanguageService.text(
                    'PIN Pembayaran berhasil diperbarui di database!',
                    'Payment PIN successfully updated in database!'));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                LanguageService.text('Simpan PIN', 'Save PIN'),
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // ===         FITUR 3: TOGGLE 2FA / SFA KEAMANAN    ===
  // =====================================================
  Future<void> _toggle2FAKeamanan() async {
    final newStatus = !_is2FA;
    final userIdentifier = _userUid.isNotEmpty
        ? _userUid
        : (_email.isNotEmpty ? _email : _currentUsername);

    await DatabaseHelper.instance.updateUser2FA(userIdentifier, newStatus);
    if (_email.isNotEmpty && _email != userIdentifier) {
      await DatabaseHelper.instance.updateUser2FA(_email, newStatus);
    }
    setState(() => _is2FA = newStatus);

    if (newStatus) {
      _showSnackbarSuccess('2FA / SFA Keamanan telah DIAKTIFKAN');
    } else {
      _showSnackbarInfo('2FA / SFA Keamanan telah DINONAKTIFKAN');
    }
  }

  // =====================================================
  // ===     FITUR 3.5: KONFIGURASI SERVER EMAIL (SMTP) ===
  // =====================================================
  void _showSmtpConfigDialog() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Muat data konfigurasi dari Google Cloud Firestore, Firebase RTDB & SQLite (dengan fallback SharedPreferences)
    Map<String, dynamic>? dbSettings;
    try {
      dbSettings = await FirebaseEmailService.instance
              .getEmailSettings(userEmail: _email) ??
          await FirebaseEmailService.instance.getEmailSettings() ??
          await DatabaseHelper.instance.getEmailSettings(userEmail: _email) ??
          await DatabaseHelper.instance.getEmailSettings();
    } catch (e) {
      debugPrint('Error getting email settings: $e');
    }

    final initialUser = dbSettings?['smtp_user']?.toString() ??
        prefs.getString('smtp_user') ??
        '';
    final initialPass = dbSettings?['smtp_pass']?.toString() ??
        prefs.getString('smtp_pass') ??
        '';
    final initialHost = dbSettings?['smtp_host']?.toString() ??
        prefs.getString('smtp_host') ??
        'smtp.gmail.com';
    final initialPort = (dbSettings?['smtp_port'] as num?)?.toInt() ??
        prefs.getInt('smtp_port') ??
        465;
    final lastUpdated = dbSettings?['updated_at']?.toString();

    final userController = TextEditingController(text: initialUser);
    final passController = TextEditingController(text: initialPass);
    final hostController = TextEditingController(text: initialHost);
    final portController = TextEditingController(text: initialPort.toString());

    bool isSendingTest = false;
    bool isSaving = false;
    bool obscurePass = true;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud_done_rounded,
                    color: AppColors.success, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LanguageService.text(
                          'Konfigurasi Email SMTP', 'SMTP Mail Server'),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.cloud_sync_rounded,
                            size: 12, color: AppColors.success),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            LanguageService.text(
                              'Cloud Firestore (vibetech-xyz) & SQLite',
                              'Cloud Firestore (vibetech-xyz) & SQLite',
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner Status Aktif & Permanen jika sudah terisi
                if (initialUser.isNotEmpty && initialPass.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LanguageService.text(
                                  'STATUS: AKTIF & TERSIMPAN PERMANEN',
                                  'STATUS: ACTIVE & PERMANENTLY SAVED',
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                              Text(
                                LanguageService.text(
                                  'Tersimpan otomatis di SQLite & Cloud. Seluruh notifikasi dikirim otomatis.',
                                  'Permanently saved in SQLite & Cloud. All notifications are sent automatically.',
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Info Box Database & Sandi Aplikasi Google
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              LanguageService.text(
                                'Konfigurasi ini disinkronkan secara realtime ke Google Cloud Firestore (vibetech-xyz) & SQLite lokal. Gunakan Sandi Aplikasi Google (16 digit) agar invoice & notifikasi otomatis terkirim.',
                                'This configuration is synced in realtime to Google Cloud Firestore (vibetech-xyz) & local SQLite. Use 16-digit Google App Password for automatic invoice delivery.',
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: _textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () async {
                          final uri = Uri.parse(
                              'https://myaccount.google.com/apppasswords');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.open_in_new_rounded,
                                  size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                LanguageService.text(
                                    'Buat Sandi Aplikasi di Google (1-Klik)',
                                    'Create App Password on Google (1-Tap)'),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildDialogTextField(
                  controller: userController,
                  label: 'Email Pengirim (Gmail Anda)',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  controller: passController,
                  label: 'Sandi Aplikasi (16 Karakter)',
                  icon: Icons.key_rounded,
                  obscureText: obscurePass,
                  onToggleObscure: () =>
                      setDialogState(() => obscurePass = !obscurePass),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildDialogTextField(
                        controller: hostController,
                        label: 'Host SMTP',
                        icon: Icons.dns_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildDialogTextField(
                        controller: portController,
                        label: 'Port',
                        icon: Icons.numbers_rounded,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                if (lastUpdated != null && lastUpdated.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 12, color: AppColors.success),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          LanguageService.text(
                            'Sinkronisasi Database aktif ($lastUpdated)',
                            'Database sync active ($lastUpdated)',
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: _textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: isSendingTest
                        ? null
                        : () async {
                            final user = userController.text.trim();
                            final pass =
                                passController.text.trim().replaceAll(' ', '');
                            final host = hostController.text.trim();
                            final port =
                                int.tryParse(portController.text.trim()) ?? 465;

                            if (user.isEmpty || pass.isEmpty) {
                              _showSnackbarError(
                                  'Email pengirim dan Sandi Aplikasi (16 digit) wajib diisi!');
                              return;
                            }

                            setDialogState(() => isSendingTest = true);

                            final res =
                                await NotificationService.sendDirectSmtpTest(
                              smtpUser: user,
                              smtpPass: pass,
                              targetEmail: _email,
                              smtpHost:
                                  host.isNotEmpty ? host : 'smtp.gmail.com',
                              smtpPort: port,
                            );

                            setDialogState(() => isSendingTest = false);

                            if (res['success'] == true) {
                              _showSnackbarSuccess(
                                  '✅ Email tes berhasil terkirim ke $_email! Silakan periksa inbox.');
                            } else {
                              _showSnackbarError('${res['message']}');
                            }
                          },
                    icon: isSendingTest
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      isSendingTest
                          ? 'Menguji Koneksi...'
                          : 'Kirim Email Uji Coba ke $_email',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                          color: AppColors.primary, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Tutup',
                style: GoogleFonts.poppins(color: _textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final user = userController.text.trim();
                      final pass =
                          passController.text.trim().replaceAll(' ', '');
                      final host = hostController.text.trim();
                      final port =
                          int.tryParse(portController.text.trim()) ?? 465;

                      if (user.isEmpty) {
                        _showSnackbarError('Email pengirim wajib diisi!');
                        return;
                      }

                      setDialogState(() => isSaving = true);

                      try {
                        // 1. Simpan ke database SQLite lokal secara permanen (Instan < 30ms)
                        await DatabaseHelper.instance.saveEmailSettings(
                          smtpUser: user,
                          smtpPass: pass,
                          smtpHost: host.isNotEmpty ? host : 'smtp.gmail.com',
                          smtpPort: port,
                          userEmail: _email,
                        );

                        // 2. Simpan ke SharedPreferences sebagai cache runtime
                        final p = await SharedPreferences.getInstance();
                        await p.setString('smtp_user', user);
                        await p.setString('smtp_pass', pass);
                        await p.setString('smtp_host',
                            host.isNotEmpty ? host : 'smtp.gmail.com');
                        await p.setInt('smtp_port', port);

                        // 3. Sinkronkan ke Google Cloud Firestore & Firebase RTDB di latar belakang
                        FirebaseEmailService.instance
                            .saveEmailSettings(
                              smtpUser: user,
                              smtpPass: pass,
                              smtpHost:
                                  host.isNotEmpty ? host : 'smtp.gmail.com',
                              smtpPort: port,
                              userEmail: _email,
                            )
                            .catchError((_) => false);

                        if (context.mounted) Navigator.pop(context);
                        _showSnackbarSuccess(
                            '✅ Konfigurasi SMTP berhasil disimpan ke Database Cloud & SQLite!');
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        _showSnackbarError(
                            'Gagal menyimpan konfigurasi ke database: $e');
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Simpan Permanen',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // ===         FITUR 4: PILIH BAHASA DIALOG          ===
  // =====================================================
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.language_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              LanguageService.tr('pilih_bahasa'),
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                  fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageItem('Indonesia', '🇮🇩 Bahasa Indonesia'),
            const SizedBox(height: 8),
            _buildLanguageItem('English', '🇬🇧 English (US)'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageItem(String langKey, String label) {
    final isSelected = LanguageService.currentLanguage == langKey;
    final Color itemBg = isSelected
        ? AppColors.primary.withValues(alpha: 0.12)
        : (_isDarkMode ? const Color(0xFF1E293D) : const Color(0xFFF1F5F9));
    final Color borderColor = isSelected
        ? AppColors.primary
        : (_isDarkMode
            ? Colors.white.withValues(alpha: 0.15)
            : const Color(0xFFCBD5E1));

    return InkWell(
      onTap: () async {
        await LanguageService.setLanguage(langKey, username: _currentUsername);
        if (mounted) Navigator.pop(context);
        final msg = langKey == 'English'
            ? 'Language changed to English'
            : 'Bahasa diubah ke Bahasa Indonesia';
        _showSnackbarSuccess(msg);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: itemBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? AppColors.primary : _textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // ===          REUSABLE WIDGETS & DIALOG UTILS      ===
  // =====================================================

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    double? letterSpacing,
  }) {
    // Penentuan warna background menyesuaikan mode
    final Color fieldBg =
        _isDarkMode ? const Color(0xFF1E293D) : const Color(0xFFF8FAFC);

    final Color borderColor = _isDarkMode
        ? Colors.white.withValues(alpha: 0.15)
        : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLength: maxLength,
        cursorColor: AppColors.primary,
        style: GoogleFonts.poppins(
          color: _textPrimary,
          fontSize: 13,
          fontWeight: letterSpacing != null ? FontWeight.bold : FontWeight.w500,
          letterSpacing: letterSpacing,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor:
              Colors.transparent, // Mematikan warna paksaan dari tema global
          hoverColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          counterText: '',
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: _textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          icon: Icon(icon, color: AppColors.primary, size: 20),
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: _textSecondary,
                    size: 18,
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String label,
    Widget? trailing,
    required VoidCallback onTap,
    required String subtitle,
  }) {
    return _buildBounceTap(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right_rounded,
                size: 20, color: _textSecondary.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Divider(
        color: _textSecondary.withValues(alpha: 0.07),
        height: 1,
      ),
    );
  }

  // =====================================================
  // ===           DIALOGS & SNACKBARS                 ===
  // =====================================================

  void _showSnackbarSuccess(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSnackbarError(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSnackbarInfo(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.rocket_launch_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Vibe',
                    style: GoogleFonts.poppins(
                        color: _textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 22),
                  ),
                  TextSpan(
                    text: 'Tech',
                    style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w400,
                        fontSize: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Versi 1.0.0',
              style: GoogleFonts.poppins(
                color: _textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Solusi hosting, VPS, dan WhatsApp Bot terbaik untuk bisnis Anda.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: _textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '© 2026 VibeTech XYZ By Raziek',
              style: GoogleFonts.poppins(
                color: _textSecondary.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Tutup',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isLogin', false);
              await prefs.remove('user_uid');
              await prefs.remove('email');
              await prefs.remove('username');
              await prefs.remove('avatarUrl');

              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false);
              }
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

  // =====================================================
  // ===           BOUNCE TAP WRAPPER                  ===
  // =====================================================
  Widget _buildBounceTap({required VoidCallback onTap, required Widget child}) {
    return AppBounceTap(onTap: onTap, child: child);
  }
}
