import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetech_xyz/constants/constants.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/balance_service.dart';
import 'package:vibetech_xyz/services/cloud_sync_service.dart';
import 'package:vibetech_xyz/services/firebase_transaction_service.dart';
import 'package:vibetech_xyz/services/firebase_user_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibetech_xyz/services/firebase_email_service.dart';
import 'package:vibetech_xyz/services/notification_service.dart';
import 'package:vibetech_xyz/services/language_service.dart';
import 'package:vibetech_xyz/utils/security_helper.dart';

/// ============================================================================
/// HALAMAN PORTAL ADMINISTRATOR: MANAJEMEN DATABASE PENGGUNA & ADMIN
/// ============================================================================
/// Fitur lengkap untuk Administrator:
/// 1. Melihat seluruh data Member dan Administrator yang terdaftar di SQLite.
/// 2. Mengubah kredensial (Username, Password, PIN Transaksi 6-Digit, Nama, Role, Saldo).
/// 3. Melihat riwayat pembelian (transaksi pesanan) & layanan aktif milik setiap pengguna.
/// 4. Menambah atau menghapus pengguna langsung ke database lokal SQLite.
class AdminDatabasePage extends StatefulWidget {
  final bool isDarkMode;
  final String currentAdminUsername;
  final String currentAdminEmail;

  const AdminDatabasePage({
    super.key,
    required this.isDarkMode,
    required this.currentAdminUsername,
    required this.currentAdminEmail,
  });

  @override
  State<AdminDatabasePage> createState() => _AdminDatabasePageState();
}

class _AdminDatabasePageState extends State<AdminDatabasePage>
    with TickerProviderStateMixin {
  late bool _isDarkMode;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];

  // Tab Menu Utama (0: Database Pengguna, 1: Pesanan & Transaksi Member)
  int _selectedMainTab = 0;

  // Filter & Search Pengguna
  String _selectedRoleFilter = 'Semua'; // 'Semua', 'Member', 'Administrator'
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Data Pesanan & Transaksi Member (SQLite + Firebase RTDB)
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  String _selectedTxFilter =
      'Semua'; // 'Semua', 'Selesai', 'Pending', 'Top Up', 'Layanan'
  final TextEditingController _searchTxController = TextEditingController();
  final FocusNode _searchTxFocusNode = FocusNode();

  // Show/Hide Credential Maps (User ID -> bool)
  final Map<int, bool> _showPasswordMap = {};
  final Map<int, bool> _showPinMap = {};

  // Controllers & Animations
  late AnimationController _mainAnimController;
  late AnimationController _particleController;
  final List<AppParticle> _particles = [];
  final math.Random _random = math.Random();
  Timer? _liveSyncTimer;
  VoidCallback? _usersRealtimeListener;
  VoidCallback? _txRealtimeListener;

  // Status Konfigurasi SMTP Email Administrator
  String? _smtpUser;
  bool _isSmtpActive = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;

    // Partikel Cyber Neon
    _particles.addAll(AppParticle.generateList(_random, count: 20));

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _particleController.addListener(() {
      AppParticle.updatePositions(_particles);
    });

    _mainAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _searchController.addListener(_applyFilter);
    _searchTxController.addListener(_applyTxFilter);
    _loadAllAdminData();

    // Hubungkan listener streaming real-time Firebase RTDB untuk pengguna & transaksi
    _usersRealtimeListener = () async {
      try {
        final freshUsers = await DatabaseHelper.instance.getAllUsers();
        if (mounted && freshUsers.isNotEmpty) {
          setState(() {
            _allUsers = List<Map<String, dynamic>>.from(
              freshUsers.map((u) => Map<String, dynamic>.from(u)),
            );
          });
          _applyFilter();
        }
      } catch (_) {}
    };

    _txRealtimeListener = () async {
      try {
        final freshTx = await DatabaseHelper.instance.getAllTransactions();
        if (mounted) {
          setState(() {
            _allTransactions = freshTx;
          });
          _applyTxFilter();
        }
      } catch (_) {}
    };

    CloudSyncService.instance.usersNotifier
        .addListener(_usersRealtimeListener!);
    CloudSyncService.instance.transactionsNotifier
        .addListener(_txRealtimeListener!);
  }

  @override
  void dispose() {
    if (_usersRealtimeListener != null) {
      CloudSyncService.instance.usersNotifier
          .removeListener(_usersRealtimeListener!);
    }
    if (_txRealtimeListener != null) {
      CloudSyncService.instance.transactionsNotifier
          .removeListener(_txRealtimeListener!);
    }
    _liveSyncTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchTxController.dispose();
    _searchTxFocusNode.dispose();
    _mainAnimController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  // --- Theme Getters ---
  Color get _bgColor => _isDarkMode ? AppColors.darkBg : AppColors.lightBg;
  Color get _cardColor =>
      _isDarkMode ? AppColors.darkCard : AppColors.lightCard;
  Color get _cardBorder => _isDarkMode
      ? const Color(0xFF7C4DFF).withValues(alpha: 0.22)
      : const Color(0xFFE2E8F0);
  Color get _textPrimary =>
      _isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get _textSecondary =>
      _isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

  // --- Load Data dari SQLite Database & Firebase Realtime Database ---
  bool _isSyncingCloud = false;

  Future<void> _loadAllAdminData() async {
    try {
      // 0. Verifikasi Otorisasi Hak Akses Administrator Secara Ketat
      final currentAdmin = await DatabaseHelper.instance.getUserByEmailOrUsername(
        widget.currentAdminEmail.isNotEmpty ? widget.currentAdminEmail : widget.currentAdminUsername,
      );
      final role = (currentAdmin?['role'] ?? '').toString().toLowerCase();
      final username = (currentAdmin?['username'] ?? widget.currentAdminUsername).toString().toLowerCase();
      final email = (currentAdmin?['email'] ?? widget.currentAdminEmail).toString().toLowerCase();
      final isAuthorized = role == 'admin' ||
          role == 'administrator' ||
          username == 'admin' ||
          username == 'raziek' ||
          email == 'admin@vibetech.com';

      if (!isAuthorized) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LanguageService.text(
                'Akses Ditolak! Anda bukan administrator.',
                'Access Denied! You are not an administrator.',
              )),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
        return;
      }

      // 1. Muat data pengguna & transaksi dari SQLite lokal secara INSTAN (0ms delay)
      final users = await DatabaseHelper.instance.getAllUsers();
      final localTx = await DatabaseHelper.instance.getAllTransactions();

      if (mounted) {
        setState(() {
          _allUsers = List<Map<String, dynamic>>.from(
            users.map((u) => Map<String, dynamic>.from(u)),
          );
          _allTransactions = List<Map<String, dynamic>>.from(
            localTx.map((t) => Map<String, dynamic>.from(t)),
          );
        });
        _applyFilter();
        _applyTxFilter();
        _mainAnimController.forward(from: 0.0);
      }

      // 2. Muat status konfigurasi SMTP Email
      try {
        final prefs = await SharedPreferences.getInstance();
        final emailSettings = await DatabaseHelper.instance.getEmailSettings(
              userEmail: widget.currentAdminEmail,
            ) ??
            await DatabaseHelper.instance.getEmailSettings();

        String? u = emailSettings?['smtp_user']?.toString().trim();
        if (u == null || u.isEmpty) {
          u = prefs.getString('smtp_user')?.trim();
        }

        String? p = emailSettings?['smtp_pass']?.toString().trim();
        if (p == null || p.isEmpty) {
          p = prefs.getString('smtp_pass')?.trim();
        }

        final bool hasCreds = (u != null && u.isNotEmpty && p != null && p.isNotEmpty);
        final bool isActive = prefs.getBool('smtp_is_active') ?? hasCreds;

        if (mounted) {
          setState(() {
            _smtpUser = u;
            _isSmtpActive = hasCreds || isActive;
          });
        }
      } catch (_) {}

      // 3. Muat pembaruan Firebase Realtime Database di latar belakang
      _fetchCloudUsersInBackground(users);
      _fetchCloudTransactionsInBackground(localTx);

      // 3. Pasang fallback live auto-sync berkala (sebagai cadangan terhadap streaming event)
      _liveSyncTimer?.cancel();
      _liveSyncTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (mounted && !_isSyncingCloud) {
          _fetchCloudUsersInBackground(_allUsers);
          _fetchCloudTransactionsInBackground(_allTransactions);
        }
      });
    } catch (e) {
      debugPrint('Error loading admin data: $e');
    }
  }

  void _fetchCloudUsersInBackground(
      List<Map<String, dynamic>> localUsers) async {
    try {
      await FirebaseUserService.instance.syncUsersFromFirebase();

      final refreshedUsers = await DatabaseHelper.instance.getAllUsers();
      if (mounted && refreshedUsers.isNotEmpty) {
        setState(() {
          _allUsers = List<Map<String, dynamic>>.from(
            refreshedUsers.map((u) => Map<String, dynamic>.from(u)),
          );
        });
        _applyFilter();
      }
    } catch (e) {
      debugPrint('[AdminDatabasePage] Background cloud fetch users info: $e');
    }
  }

  void _fetchCloudTransactionsInBackground(
      List<Map<String, dynamic>> localTx) async {
    try {
      await FirebaseTransactionService.instance.syncTransactionsFromFirebase();
      final freshTx = await DatabaseHelper.instance.getAllTransactions();
      if (!mounted) return;

      setState(() {
        _allTransactions = freshTx;
      });
      _applyTxFilter();
    } catch (e) {
      debugPrint('Background cloud fetch info: $e');
    }
  }

  Future<void> _loadUsersData() => _loadAllAdminData();

  Future<void> _syncUsersToFirebase() async {
    if (_isSyncingCloud) return;
    setState(() => _isSyncingCloud = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                LanguageService.text(
                  'Menyinkronkan akun & pesanan member ke Firebase RTDB...',
                  'Syncing accounts & member orders to Firebase RTDB...',
                ),
                style: GoogleFonts.poppins(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF7C4DFF),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      // 1. Sinkronisasi Pengguna secara langsung ke Firebase RTDB (https://vibetech-xyz-default-rtdb.asia-southeast1.firebasedatabase.app/users)
      await FirebaseUserService.instance.syncUsersFromFirebase();
      await FirebaseUserService.instance.syncAllLocalUsersToFirebase();

      // 2. Sinkronisasi penuh semua domain ke/dari Cloud
      await CloudSyncService.instance.syncAllFromCloud();
      await CloudSyncService.instance.syncAllToCloud();

      await _loadAllAdminData();

      if (mounted) {
        setState(() => _isSyncingCloud = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF00E676), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    LanguageService.text(
                      'Sukses! ${_allUsers.length} akun & ${_allTransactions.length} pesanan disinkronkan ke Firebase (RTDB & Cloud).',
                      'Success! ${_allUsers.length} accounts & ${_allTransactions.length} orders synced to Firebase (RTDB & Cloud).',
                    ),
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F1426),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncingCloud = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LanguageService.text(
                'Gagal menyinkronkan ke Firebase: $e',
                'Failed to sync to Firebase: $e',
              ),
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    List<Map<String, dynamic>> list = List.from(_allUsers);

    // 1. Role Filter
    if (_selectedRoleFilter == 'Member') {
      list = list.where((u) {
        final role = (u['role'] ?? 'user').toString().toLowerCase();
        return role != 'admin' && role != 'administrator';
      }).toList();
    } else if (_selectedRoleFilter == 'Administrator') {
      list = list.where((u) {
        final role = (u['role'] ?? 'user').toString().toLowerCase();
        return role == 'admin' || role == 'administrator';
      }).toList();
    }

    // 2. Search Query
    if (query.isNotEmpty) {
      list = list.where((u) {
        final username = (u['username'] ?? '').toString().toLowerCase();
        final nama = (u['nama'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final phone = (u['phone'] ?? '').toString().toLowerCase();
        final uid = (u['uid'] ?? '').toString().toLowerCase();
        return username.contains(query) ||
            nama.contains(query) ||
            email.contains(query) ||
            phone.contains(query) ||
            uid.contains(query);
      }).toList();
    }

    // 3. Urutkan: Administrator paling atas, kemudian urut nomor/nama alfabetis
    list.sort((a, b) {
      final roleA = (a['role'] ?? 'user').toString().toLowerCase();
      final roleB = (b['role'] ?? 'user').toString().toLowerCase();
      final isAdminA = roleA == 'admin' || roleA == 'administrator';
      final isAdminB = roleB == 'admin' || roleB == 'administrator';
      if (isAdminA && !isAdminB) return -1;
      if (!isAdminA && isAdminB) return 1;

      final orderA =
          (a['no'] ?? a['urutan'] ?? a['id'] as num?)?.toInt() ?? 999;
      final orderB =
          (b['no'] ?? b['urutan'] ?? b['id'] as num?)?.toInt() ?? 999;
      if (orderA != orderB) return orderA.compareTo(orderB);

      final nameA = (a['nama'] ?? a['username'] ?? '').toString().toLowerCase();
      final nameB = (b['nama'] ?? b['username'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });

    setState(() {
      _filteredUsers = list;
    });
  }

  void _applyTxFilter() {
    final query = _searchTxController.text.trim().toLowerCase();
    List<Map<String, dynamic>> list = List.from(_allTransactions);

    // 1. Status & Category Filter
    if (_selectedTxFilter == 'Selesai') {
      list = list.where((t) {
        final st = (t['status'] ?? '').toString().toLowerCase();
        return st == 'selesai' ||
            st == 'success' ||
            st == 'settlement' ||
            st == 'capture';
      }).toList();
    } else if (_selectedTxFilter == 'Pending') {
      list = list.where((t) {
        final st = (t['status'] ?? '').toString().toLowerCase();
        return st == 'pending' || st == 'menunggu pembayaran';
      }).toList();
    } else if (_selectedTxFilter == 'Top Up') {
      list = list.where((t) {
        final name = (t['nama_produk'] ?? '').toString().toLowerCase();
        final inv = (t['invoice_no'] ?? '').toString().toLowerCase();
        return name.contains('top up') || inv.contains('topup');
      }).toList();
    } else if (_selectedTxFilter == 'Layanan') {
      list = list.where((t) {
        final name = (t['nama_produk'] ?? '').toString().toLowerCase();
        final inv = (t['invoice_no'] ?? '').toString().toLowerCase();
        return !name.contains('top up') && !inv.contains('topup');
      }).toList();
    }

    // 2. Search query
    if (query.isNotEmpty) {
      list = list.where((t) {
        final inv = (t['invoice_no'] ?? '').toString().toLowerCase();
        final email = (t['user_email'] ?? '').toString().toLowerCase();
        final prod = (t['nama_produk'] ?? '').toString().toLowerCase();
        final method = (t['payment_method'] ?? '').toString().toLowerCase();
        return inv.contains(query) ||
            email.contains(query) ||
            prod.contains(query) ||
            method.contains(query);
      }).toList();
    }

    setState(() {
      _filteredTransactions = list;
    });
  }

  // --- METRIK KPI DATABASE PENGGUNA ---
  int get _totalUsersCount => _allUsers.length;
  int get _totalMembersCount => _allUsers.where((u) {
        final r = (u['role'] ?? 'user').toString().toLowerCase();
        return r != 'admin' && r != 'administrator';
      }).length;
  int get _totalAdminsCount => _allUsers.where((u) {
        final r = (u['role'] ?? 'user').toString().toLowerCase();
        return r == 'admin' || r == 'administrator';
      }).length;
  double get _totalSaldoBeredar => _allUsers.fold(
      0.0, (sum, u) => sum + ((u['saldo'] as num?)?.toDouble() ?? 0.0));

  // --- METRIK KPI DATABASE PESANAN MEMBER ---
  int get _totalTxCount => _allTransactions.length;
  int get _completedTxCount => _allTransactions.where((t) {
        final st = (t['status'] ?? '').toString().toLowerCase();
        return st == 'selesai' ||
            st == 'success' ||
            st == 'settlement' ||
            st == 'capture';
      }).length;
  int get _pendingTxCount => _allTransactions.where((t) {
        final st = (t['status'] ?? '').toString().toLowerCase();
        return st == 'pending' || st == 'menunggu pembayaran';
      }).length;
  double get _totalOmset => _allTransactions.fold(0.0, (sum, t) {
        final st = (t['status'] ?? '').toString().toLowerCase();
        if (st == 'selesai' ||
            st == 'success' ||
            st == 'settlement' ||
            st == 'capture') {
          return sum + ((t['total_harga'] as num?)?.toDouble() ?? 0.0);
        }
        return sum;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // 1. Background Cyber Radial Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: _isDarkMode
                    ? const RadialGradient(
                        center: Alignment(0.0, -0.4),
                        radius: 1.4,
                        colors: [
                          Color(0xFF19113B),
                          Color(0xFF0C0E24),
                          Color(0xFF05060F),
                        ],
                        stops: [0.0, 0.55, 1.0],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFF8FAFC),
                          Color(0xFFF1F5F9),
                          Color(0xFFE2E8F0),
                        ],
                      ),
              ),
            ),
          ),

          // 2. Floating Cyber Particles
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

          // 3. Foreground Safe Area
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: RefreshIndicator(
                          onRefresh: _loadAllAdminData,
                          color: const Color(0xFF00E5FF),
                          backgroundColor: _cardColor,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMainTabSelector(),
                                const SizedBox(height: 12),
                                if (_selectedMainTab == 0) ...[
                                  _buildHeaderMetrics(),
                                  const SizedBox(height: 20),
                                  _buildSearchAndFilterSection(),
                                  const SizedBox(height: 18),
                                  _buildUserListSection(),
                                ] else ...[
                                  _buildTransactionMetrics(),
                                  const SizedBox(height: 20),
                                  _buildTransactionSearchAndFilterSection(),
                                  const SizedBox(height: 18),
                                  _buildTransactionListSection(),
                                ],
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            _selectedMainTab == 0 ? _showAddUserDialog : _syncUsersToFirebase,
        backgroundColor: _selectedMainTab == 0
            ? const Color(0xFF7C4DFF)
            : const Color(0xFF00B0FF),
        elevation: 6,
        icon: Icon(
          _selectedMainTab == 0
              ? Icons.person_add_alt_1_rounded
              : Icons.cloud_sync_rounded,
          color: Colors.white,
        ),
        label: Text(
          _selectedMainTab == 0
              ? LanguageService.text('Tambah Akun', 'Add Account')
              : LanguageService.text('Sinkron RTDB', 'Sync RTDB'),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // --- APP BAR ---
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          _buildIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        LanguageService.text(
                            'Portal Administrator', 'Admin Portal'),
                        style: GoogleFonts.poppins(
                          color: _textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'SQLITE DB',
                        style: GoogleFonts.spaceMono(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  LanguageService.text(
                      'Kelola Seluruh Akun, Kredensial & Riwayat',
                      'Manage All Accounts, Credentials & History'),
                  style: GoogleFonts.poppins(
                    color: _textSecondary,
                    fontSize: 10.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconButton(
                icon: Icons.mark_email_read_outlined,
                onTap: _showSmtpConfigDialog,
              ),
              const SizedBox(width: 6),
              _buildIconButton(
                icon: Icons.cloud_sync_rounded,
                onTap: _syncUsersToFirebase,
              ),
              const SizedBox(width: 6),
              _buildIconButton(
                icon: Icons.refresh_rounded,
                onTap: _loadUsersData,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(
      {required IconData icon, required VoidCallback onTap}) {
    return AppBounceTap(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isDarkMode ? 0.25 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: _textPrimary, size: 18),
      ),
    );
  }

  // --- HEADER KPI SUMMARY CARDS ---
  Widget _buildHeaderMetrics() {
    final currencyFormatter = NumberFormat('#,###', 'id_ID');

    return Column(
      children: [
        // 0. Banner Sinkronisasi Cloud Firebase
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cloud_done_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Firebase Cloud Sync',
                            style: GoogleFonts.poppins(
                              color: _textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF00E676).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF00E676)
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            'ONLINE',
                            style: GoogleFonts.spaceMono(
                              color: const Color(0xFF00E676),
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      LanguageService.text(
                        'Cloud Firestore & Realtime Database aktif',
                        'Cloud Firestore & Realtime Database active',
                      ),
                      style: GoogleFonts.poppins(
                        color: _textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppBounceTap(
                onTap: _syncUsersToFirebase,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        LanguageService.text('Sinkron', 'Sync'),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 0.1 Banner Status & Manajemen SMTP Email Server
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (_isSmtpActive
                      ? const Color(0xFF00E676)
                      : const Color(0xFFFFB300))
                  .withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: (_isSmtpActive
                        ? const Color(0xFF00E676)
                        : const Color(0xFFFFB300))
                    .withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isSmtpActive
                        ? const [Color(0xFF00E676), Color(0xFF00B0FF)]
                        : const [Color(0xFFFFB300), Color(0xFFFF9100)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isSmtpActive
                      ? Icons.mark_email_read_rounded
                      : Icons.mail_lock_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            LanguageService.text(
                                'Konfigurasi Email SMTP', 'SMTP Email Server'),
                            style: GoogleFonts.poppins(
                              color: _textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: (_isSmtpActive
                                    ? const Color(0xFF00E676)
                                    : const Color(0xFFFFB300))
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (_isSmtpActive
                                      ? const Color(0xFF00E676)
                                      : const Color(0xFFFFB300))
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            _isSmtpActive ? 'AKTIF' : 'BELUM AKTIF',
                            style: GoogleFonts.spaceMono(
                              color: _isSmtpActive
                                  ? const Color(0xFF00E676)
                                  : const Color(0xFFFFB300),
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isSmtpActive
                          ? (_smtpUser ?? 'SMTP Server Terhubung')
                          : LanguageService.text(
                              'Atur kredensial email agar invoice & notifikasi otomatis terkirim',
                              'Setup email credentials for auto invoices & notifications',
                            ),
                      style: GoogleFonts.poppins(
                        color: _textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppBounceTap(
                onTap: _showSmtpConfigDialog,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00B0FF), Color(0xFF0091EA)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00B0FF).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.settings_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        LanguageService.text('Kelola', 'Manage'),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: LanguageService.text('Total Akun', 'Total Accounts'),
                value: '$_totalUsersCount',
                subtitle: LanguageService.text(
                    'Terdaftar di SQLite', 'Registered in SQLite'),
                icon: Icons.people_alt_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: LanguageService.text('Total Member', 'Total Members'),
                value: '$_totalMembersCount',
                subtitle:
                    LanguageService.text('Pengguna Biasa', 'Regular Users'),
                icon: Icons.person_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00B0FF), Color(0xFF0081CB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: LanguageService.text('Administrator', 'Administrators'),
                value: '$_totalAdminsCount',
                subtitle:
                    LanguageService.text('Akses Penuh', 'Full Access Role'),
                icon: Icons.admin_panel_settings_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFFF50057), Color(0xFFC51162)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title:
                    LanguageService.text('Saldo Beredar', 'Circulating Funds'),
                value:
                    'Rp ${currencyFormatter.format(_totalSaldoBeredar.toInt()).replaceAll(',', '.')}',
                subtitle: LanguageService.text(
                    'Total Seluruh Saldo', 'Total Combined Balance'),
                icon: Icons.account_balance_wallet_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E676), Color(0xFF00B248)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 18),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // --- SEARCH AND FILTER SECTION ---
  Widget _buildSearchAndFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(alpha: _isDarkMode ? 0.25 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            style: GoogleFonts.poppins(color: _textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: LanguageService.text(
                'Cari username, nama, email, nomor HP...',
                'Search username, name, email, phone...',
              ),
              hintStyle:
                  GoogleFonts.poppins(color: _textSecondary, fontSize: 12.5),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: _isDarkMode
                    ? const Color(0xFF00E5FF)
                    : const Color(0xFF7C4DFF),
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded,
                          color: _textSecondary, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilter();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip('Semua', Icons.grid_view_rounded,
                  count: _totalUsersCount),
              const SizedBox(width: 8),
              _buildFilterChip('Member', Icons.person_rounded,
                  count: _totalMembersCount),
              const SizedBox(width: 8),
              _buildFilterChip(
                  'Administrator', Icons.admin_panel_settings_rounded,
                  count: _totalAdminsCount),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, IconData icon, {required int count}) {
    final bool isSelected = _selectedRoleFilter == label;
    return AppBounceTap(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedRoleFilter = label;
        });
        _applyFilter();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7C4DFF)
              : _cardColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF7C4DFF) : _cardBorder,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : _textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : _textPrimary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : (_isDarkMode
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : _textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- USER LIST SECTION ---
  Widget _buildUserListSection() {
    if (_filteredUsers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 48,
              color: _textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              LanguageService.text(
                'Tidak ada akun yang sesuai dengan filter',
                'No accounts match the filter',
              ),
              style: GoogleFonts.poppins(
                color: _textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              LanguageService.text(
                'Coba gunakan kata kunci pencarian atau ganti filter role.',
                'Try different search keywords or change role filter.',
              ),
              style: GoogleFonts.poppins(
                color: _textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${LanguageService.text('Database Pengguna', 'User Database')} (${_filteredUsers.length})',
                style: GoogleFonts.poppins(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              LanguageService.text('Sentuh kartu opsi', 'Tap card for options'),
              style: GoogleFonts.poppins(
                color: _textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredUsers.length,
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final user = _filteredUsers[index];
            return _buildUserCard(user, index);
          },
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, int index) {
    final int id = user['id'] as int? ?? index;
    final String nama = user['nama']?.toString() ?? 'User $id';
    final String username = user['username']?.toString() ?? 'user_$id';
    final String email = user['email']?.toString() ?? 'user$id@vibetech.xyz';
    final String phone = user['phone']?.toString() ?? '-';
    final String password = user['password']?.toString() ?? '******';
    final String pin = user['pin']?.toString() ?? '123456';
    final String role = (user['role'] ?? 'user').toString();
    final double saldo = (user['saldo'] as num?)?.toDouble() ?? 0.0;

    final bool isAdmin =
        role.toLowerCase() == 'admin' || role.toLowerCase() == 'administrator';
    final bool isCurrentAdmin =
        username.toLowerCase() == widget.currentAdminUsername.toLowerCase() ||
            email.toLowerCase() == widget.currentAdminEmail.toLowerCase();

    final bool showPassword = _showPasswordMap[id] ?? false;
    final bool showPin = _showPinMap[id] ?? false;

    final currencyFormatter = NumberFormat('#,###', 'id_ID');

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAdmin
              ? const Color(0xFF7C4DFF).withValues(alpha: 0.35)
              : _cardBorder,
          width: isAdmin ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isAdmin
                ? const Color(0xFF7C4DFF).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card: Avatar, Name, Username & Role Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isAdmin
                          ? [const Color(0xFF7C4DFF), const Color(0xFFE040FB)]
                          : [const Color(0xFF00B0FF), const Color(0xFF00E5FF)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: CircleAvatar(
                      backgroundColor: _cardColor,
                      child: Text(
                        (nama.isNotEmpty ? nama[0] : username[0]).toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: isAdmin
                              ? const Color(0xFFE040FB)
                              : const Color(0xFF00B0FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Username
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              nama,
                              style: GoogleFonts.poppins(
                                color: _textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                LanguageService.text('Anda', 'You'),
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF00E676),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '@$username',
                        style: GoogleFonts.poppins(
                          color: _isDarkMode
                              ? const Color(0xFF00E5FF)
                              : const Color(0xFF7C4DFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: GoogleFonts.poppins(
                          color: _textSecondary,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Role Badge & Nomor Urut
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: isAdmin
                            ? const LinearGradient(
                                colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)])
                            : null,
                        color: isAdmin
                            ? null
                            : (_isDarkMode
                                ? const Color(0xFF00E5FF)
                                    .withValues(alpha: 0.12)
                                : const Color(0xFF00B0FF)
                                    .withValues(alpha: 0.12)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isAdmin
                              ? Colors.transparent
                              : (_isDarkMode
                                  ? const Color(0xFF00E5FF)
                                      .withValues(alpha: 0.3)
                                  : const Color(0xFF00B0FF)
                                      .withValues(alpha: 0.3)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAdmin
                                ? Icons.admin_panel_settings_rounded
                                : Icons.person_rounded,
                            size: 12,
                            color: isAdmin
                                ? Colors.white
                                : (_isDarkMode
                                    ? const Color(0xFF00E5FF)
                                    : const Color(0xFF0081CB)),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isAdmin ? 'ADMIN' : 'MEMBER',
                            style: GoogleFonts.poppins(
                              color: isAdmin
                                  ? Colors.white
                                  : (_isDarkMode
                                      ? const Color(0xFF00E5FF)
                                      : const Color(0xFF0081CB)),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isDarkMode
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: GoogleFonts.spaceMono(
                          color: _textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Divider
          Divider(color: _cardBorder.withValues(alpha: 0.5), height: 1),

          // Details Grid: PIN, Password, Saldo, Telepon
          Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isDarkMode
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cardBorder.withValues(alpha: 0.6)),
              ),
              child: Column(
                children: [
                  // Row 1: Username & Password
                  Row(
                    children: [
                      // Password Column
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                size: 15, color: _textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Pass: ',
                              style: GoogleFonts.poppins(
                                color: _textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                showPassword
                                    ? password
                                    : '••••••••',
                                style: GoogleFonts.spaceMono(
                                  color: _textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _showPasswordMap[id] = !showPassword;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Icon(
                                  showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 15,
                                  color: _textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 18,
                        width: 1,
                        color: _cardBorder,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      // PIN Column
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.pin_rounded,
                                size: 15, color: _textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'PIN: ',
                              style: GoogleFonts.poppins(
                                color: _textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                showPin
                                    ? (pin.startsWith('vbt\$pin\$')
                                        ? '🔒 [Terenkripsi]'
                                        : pin)
                                    : '••••••',
                                style: GoogleFonts.spaceMono(
                                  color: _textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _showPinMap[id] = !showPin;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Icon(
                                  showPin
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 15,
                                  color: _textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(color: _cardBorder.withValues(alpha: 0.3), height: 1),
                  const SizedBox(height: 10),

                  // Row 2: Saldo & No. Telepon
                  Row(
                    children: [
                      // Saldo
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 15,
                              color: Color(0xFF00E676),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Rp ${currencyFormatter.format(saldo.toInt()).replaceAll(',', '.')}',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF00E676),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Phone
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 15, color: _textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                phone,
                                style: GoogleFonts.poppins(
                                  color: _textSecondary,
                                  fontSize: 11.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons: Edit, Riwayat Pembelian, Hapus
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                // 1. Tombol Edit Kredensial & Akun
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showEditUserModal(user),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 9, horizontal: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C4DFF)
                                  .withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.edit_rounded,
                                size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  LanguageService.text(
                                      'Edit Kredensial', 'Edit Credentials'),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Tombol Riwayat Pembelian
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showPurchaseHistoryModal(user),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 9, horizontal: 4),
                        decoration: BoxDecoration(
                          color: _isDarkMode
                              ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                              : const Color(0xFF00B0FF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isDarkMode
                                ? const Color(0xFF00E5FF)
                                    .withValues(alpha: 0.35)
                                : const Color(0xFF00B0FF)
                                    .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 13,
                              color: _isDarkMode
                                  ? const Color(0xFF00E5FF)
                                  : const Color(0xFF0081CB),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  LanguageService.text(
                                      'Riwayat Beli', 'Purchase History'),
                                  style: GoogleFonts.poppins(
                                    color: _isDarkMode
                                        ? const Color(0xFF00E5FF)
                                        : const Color(0xFF0081CB),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Tombol Hapus (Tempat Sampah Merah)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showDeleteUserConfirm(user),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB SWITCHER: DATABASE PENGGUNA VS PESANAN MEMBER
  // ===========================================================================
  Widget _buildMainTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              index: 0,
              icon: Icons.people_alt_rounded,
              title: LanguageService.text('Pengguna', 'Users'),
              badgeCount: _totalUsersCount,
              badgeColor: const Color(0xFF7C4DFF),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabButton(
              index: 1,
              icon: Icons.receipt_long_rounded,
              title: LanguageService.text('Pesanan', 'Orders'),
              badgeCount: _totalTxCount,
              badgeColor: const Color(0xFF00E5FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String title,
    required int badgeCount,
    required Color badgeColor,
  }) {
    final bool isSelected = _selectedMainTab == index;
    return AppBounceTap(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedMainTab = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (index == 0 ? const Color(0xFF7C4DFF) : const Color(0xFF00B0FF))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (index == 0
                            ? const Color(0xFF7C4DFF)
                            : const Color(0xFF00B0FF))
                        .withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : _textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : _textPrimary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : badgeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION: DATABASE PESANAN & TRANSAKSI SELURUH MEMBER
  // ===========================================================================
  Widget _buildTransactionMetrics() {
    final currencyFormatter = NumberFormat('#,###', 'id_ID');

    return Column(
      children: [
        // 0. Banner Sinkronisasi RTDB Pesanan
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00B0FF), Color(0xFF00E5FF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            LanguageService.text(
                                'Pesanan Member', 'Member Orders'),
                            style: GoogleFonts.poppins(
                              color: _textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF00E676).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF00E676)
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            'RTDB SYNC',
                            style: GoogleFonts.spaceMono(
                              color: const Color(0xFF00E676),
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      LanguageService.text(
                        'Semua pesanan member otomatis tersimpan di Realtime Database',
                        'All member orders automatically synced to Realtime Database',
                      ),
                      style: GoogleFonts.poppins(
                        color: _textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppBounceTap(
                onTap: _syncUsersToFirebase,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00B0FF), Color(0xFF0081CB)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00B0FF).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        LanguageService.text('Sinkron', 'Sync'),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // KPI Row 1: Total Pesanan & Pesanan Lunas
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: LanguageService.text('Total Pesanan', 'Total Orders'),
                value: '$_totalTxCount',
                subtitle: LanguageService.text(
                    'Seluruh Transaksi Member', 'All Member Transactions'),
                icon: Icons.receipt_long_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: LanguageService.text('Pesanan Selesai', 'Completed'),
                value: '$_completedTxCount',
                subtitle:
                    LanguageService.text('Lunas & Aktif', 'Paid & Active'),
                icon: Icons.check_circle_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E676), Color(0xFF00B248)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // KPI Row 2: Pending & Total Omset
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: LanguageService.text('Menunggu Bayar', 'Pending Orders'),
                value: '$_pendingTxCount',
                subtitle:
                    LanguageService.text('Status Pending', 'Awaiting Payment'),
                icon: Icons.hourglass_top_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9100), Color(0xFFFF6D00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: LanguageService.text('Total Omset', 'Total Revenue'),
                value:
                    'Rp ${currencyFormatter.format(_totalOmset.toInt()).replaceAll(',', '.')}',
                subtitle: LanguageService.text(
                    'Akumulasi Nilai Transaksi', 'Total Settled Amount'),
                icon: Icons.account_balance_wallet_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00B0FF), Color(0xFF0081CB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransactionSearchAndFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(alpha: _isDarkMode ? 0.25 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchTxController,
            focusNode: _searchTxFocusNode,
            style: GoogleFonts.poppins(color: _textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: LanguageService.text(
                'Cari Invoice ID, email member, nama produk...',
                'Search Invoice ID, member email, product...',
              ),
              hintStyle:
                  GoogleFonts.poppins(color: _textSecondary, fontSize: 12.5),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: _isDarkMode
                    ? const Color(0xFF00E5FF)
                    : const Color(0xFF7C4DFF),
                size: 20,
              ),
              suffixIcon: _searchTxController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded,
                          color: _textSecondary, size: 18),
                      onPressed: () {
                        _searchTxController.clear();
                        _applyTxFilter();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildTxFilterChip('Semua', Icons.grid_view_rounded,
                  count: _totalTxCount),
              const SizedBox(width: 8),
              _buildTxFilterChip('Selesai', Icons.check_circle_rounded,
                  count: _completedTxCount),
              const SizedBox(width: 8),
              _buildTxFilterChip('Pending', Icons.pending_actions_rounded,
                  count: _pendingTxCount),
              const SizedBox(width: 8),
              _buildTxFilterChip('Top Up', Icons.account_balance_wallet_rounded,
                  count: _allTransactions.where((t) {
                    final name =
                        (t['nama_produk'] ?? '').toString().toLowerCase();
                    final inv =
                        (t['invoice_no'] ?? '').toString().toLowerCase();
                    return name.contains('top up') || inv.contains('topup');
                  }).length),
              const SizedBox(width: 8),
              _buildTxFilterChip('Layanan', Icons.cloud_outlined,
                  count: _allTransactions.where((t) {
                    final name =
                        (t['nama_produk'] ?? '').toString().toLowerCase();
                    final inv =
                        (t['invoice_no'] ?? '').toString().toLowerCase();
                    return !name.contains('top up') && !inv.contains('topup');
                  }).length),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTxFilterChip(String label, IconData icon, {required int count}) {
    final bool isSelected = _selectedTxFilter == label;
    return AppBounceTap(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedTxFilter = label;
        });
        _applyTxFilter();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00B0FF)
              : _cardColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF00B0FF) : _cardBorder,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00B0FF).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : _textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : _textPrimary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : (_isDarkMode
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : _textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionListSection() {
    final currencyFormatter = NumberFormat('#,###', 'id_ID');

    if (_filteredTransactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: _textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              LanguageService.text(
                'Tidak ada transaksi pesanan yang sesuai filter',
                'No orders match the filter',
              ),
              style: GoogleFonts.poppins(
                color: _textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              LanguageService.text(
                'Setiap pembelian produk & top up saldo member otomatis tersimpan di SQLite & Firebase RTDB.',
                'Every member purchase & top up is automatically saved to SQLite & Firebase RTDB.',
              ),
              style: GoogleFonts.poppins(
                color: _textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${LanguageService.text('Pesanan & Transaksi', 'Orders & Transactions')} (${_filteredTransactions.length})',
                style: GoogleFonts.poppins(
                  color: _textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'RTDB SYNC',
                style: GoogleFonts.spaceMono(
                  color: const Color(0xFF00E5FF),
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredTransactions.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final tx = _filteredTransactions[index];
            return _buildTransactionCard(tx, currencyFormatter);
          },
        ),
      ],
    );
  }

  Widget _buildTransactionCard(
      Map<String, dynamic> tx, NumberFormat currencyFormatter) {
    final String invoiceNo = tx['invoice_no']?.toString() ?? 'INV-${tx['id']}';
    final String userEmail =
        tx['user_email']?.toString() ?? 'customer@vibetech.xyz';
    final String namaProduk =
        tx['nama_produk']?.toString() ?? 'Layanan Digital';
    final double totalHarga = (tx['total_harga'] as num?)?.toDouble() ?? 0.0;
    final String status = tx['status']?.toString() ?? 'Pending';
    final String tanggal = tx['tanggal']?.toString() ?? '-';
    final String paymentMethod =
        tx['payment_method']?.toString() ?? 'Midtrans / Gateway';

    final bool isCompleted = status.toLowerCase() == 'selesai' ||
        status.toLowerCase() == 'success' ||
        status.toLowerCase() == 'settlement' ||
        status.toLowerCase() == 'capture';
    final bool isPending = status.toLowerCase() == 'pending' ||
        status.toLowerCase() == 'menunggu pembayaran';

    final Color statusBg = isCompleted
        ? const Color(0xFF00E676)
        : (isPending ? const Color(0xFFFF9100) : AppColors.error);

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF00E676).withValues(alpha: 0.3)
              : (isPending
                  ? const Color(0xFFFF9100).withValues(alpha: 0.3)
                  : _cardBorder),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCompleted
                ? const Color(0xFF00E676).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Invoice No + Copy Button + Status Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isDarkMode
                                ? Colors.black.withValues(alpha: 0.4)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _cardBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_rounded,
                                size: 13,
                                color: _isDarkMode
                                    ? const Color(0xFF00E5FF)
                                    : const Color(0xFF7C4DFF),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  invoiceNo,
                                  style: GoogleFonts.spaceMono(
                                    color: _textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: invoiceNo));
                          _showSnackBar('Invoice $invoiceNo disalin!');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(Icons.copy_rounded,
                              size: 14, color: _textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: statusBg.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusBg.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCompleted
                            ? Icons.check_circle_rounded
                            : (isPending
                                ? Icons.hourglass_bottom_rounded
                                : Icons.cancel_rounded),
                        size: 11,
                        color: statusBg,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: statusBg,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(color: _cardBorder.withValues(alpha: 0.5), height: 1),

          // Detail Produk & Pembeli
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  namaProduk,
                  style: GoogleFonts.poppins(
                    color: _textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 13, color: _textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        userEmail,
                        style: GoogleFonts.poppins(
                          color: _textSecondary,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.calendar_today_outlined,
                        size: 12, color: _textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      tanggal.length > 16 ? tanggal.substring(0, 16) : tanggal,
                      style: GoogleFonts.poppins(
                        color: _textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Bar: Payment Method + Price + Action
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? Colors.black.withValues(alpha: 0.2)
                  : const Color(0xFFF8FAFC),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF7C4DFF).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            paymentMethod.toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF7C4DFF),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Rp ${currencyFormatter.format(totalHarga.toInt()).replaceAll(',', '.')}',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF00E676),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                AppBounceTap(
                  onTap: () => _showEditTransactionDialog(tx),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                AppBounceTap(
                  onTap: () => _showDeleteTransactionDialog(tx),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 14,
                      color: AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                AppBounceTap(
                  onTap: () => _showTransactionDetailModal(tx),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                          : const Color(0xFF00B0FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isDarkMode
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.4)
                            : const Color(0xFF00B0FF).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 13,
                          color: _isDarkMode
                              ? const Color(0xFF00E5FF)
                              : const Color(0xFF0081CB),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          LanguageService.text('Detail', 'View'),
                          style: GoogleFonts.poppins(
                            color: _isDarkMode
                                ? const Color(0xFF00E5FF)
                                : const Color(0xFF0081CB),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditTransactionDialog(Map<String, dynamic> tx) {
    final formKey = GlobalKey<FormState>();
    final int txId = (tx['id'] as num?)?.toInt() ?? 0;
    final String oldInvoice =
        (tx['invoice_no'] ?? tx['id_ref'] ?? '').toString();

    final nameCtrl =
        TextEditingController(text: tx['nama_produk']?.toString() ?? '');
    final priceCtrl = TextEditingController(
        text: (tx['total_harga'] as num?)?.toInt().toString() ?? '0');
    final qtyCtrl = TextEditingController(
        text: (tx['jumlah'] as num?)?.toInt().toString() ?? '1');
    final emailCtrl =
        TextEditingController(text: tx['user_email']?.toString() ?? '');
    final invoiceCtrl = TextEditingController(
        text: oldInvoice.isNotEmpty
            ? oldInvoice
            : 'INV-${DateTime.now().millisecondsSinceEpoch}');
    final notesCtrl =
        TextEditingController(text: tx['notes']?.toString() ?? '');
    String selectedStatus = tx['status']?.toString() ?? 'Selesai';
    String paymentMethod =
        tx['payment_method']?.toString() ?? 'Saldo VibeWallet';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dContext, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            LanguageService.text(
                'Edit Transaksi Pesanan', 'Edit Order Transaction'),
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: _textPrimary, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: emailCtrl,
                    style:
                        GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText:
                          LanguageService.text('Email Member', 'Member Email'),
                      labelStyle: GoogleFonts.poppins(
                          color: _textSecondary, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: nameCtrl,
                    style:
                        GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: LanguageService.text(
                          'Nama Layanan / Produk', 'Product Name'),
                      labelStyle: GoogleFonts.poppins(
                          color: _textSecondary, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(
                              color: _textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: LanguageService.text(
                                'Total Harga (Rp)', 'Total Price'),
                            labelStyle: GoogleFonts.poppins(
                                color: _textSecondary, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(
                              color: _textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: LanguageService.text('Qty', 'Qty'),
                            labelStyle: GoogleFonts.poppins(
                                color: _textSecondary, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: invoiceCtrl,
                    style:
                        GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText:
                          LanguageService.text('No. Invoice', 'Invoice No.'),
                      labelStyle: GoogleFonts.poppins(
                          color: _textSecondary, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: [
                      'Selesai',
                      'Pending',
                      'Diproses',
                      'Dibatalkan'
                    ].contains(selectedStatus)
                        ? selectedStatus
                        : 'Selesai',
                    dropdownColor: _cardColor,
                    style:
                        GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: LanguageService.text('Status', 'Status'),
                      labelStyle: GoogleFonts.poppins(
                          color: _textSecondary, fontSize: 12),
                    ),
                    items: ['Selesai', 'Pending', 'Diproses', 'Dibatalkan']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedStatus = val);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(LanguageService.tr('batal'),
                  style: GoogleFonts.poppins(color: _textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final newInvoice = invoiceCtrl.text.trim();
                final updatedData = {
                  'id': txId > 0 ? txId : null,
                  'user_email': emailCtrl.text.trim(),
                  'nama_produk': nameCtrl.text.trim(),
                  'jumlah': int.tryParse(qtyCtrl.text.trim()) ?? 1,
                  'total_harga': double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                  'status': selectedStatus,
                  'invoice_no': newInvoice,
                  'notes': notesCtrl.text.trim(),
                  'tanggal': tx['tanggal'] ?? DateTime.now().toIso8601String(),
                  'payment_method': paymentMethod,
                };

                // 1. Optimistic UI update
                setState(() {
                  final idx = _allTransactions.indexWhere((t) =>
                      (txId > 0 && t['id'] == txId) ||
                      (oldInvoice.isNotEmpty &&
                          (t['invoice_no'] == oldInvoice ||
                              t['id_ref'] == oldInvoice)));
                  if (idx != -1) {
                    _allTransactions[idx] = {
                      ..._allTransactions[idx],
                      ...updatedData
                    };
                  }
                });
                _applyTxFilter();

                _showSnackBar(
                    'Transaksi $newInvoice berhasil diperbarui di SQLite & Firebase!');

                // 2. Simpan di DB lokal & Firebase RTDB
                try {
                  final db = await DatabaseHelper.instance.database;
                  if (txId > 0) {
                    await DatabaseHelper.instance
                        .updateTransaction(txId, updatedData);
                  } else if (oldInvoice.isNotEmpty) {
                    await db.update('transactions', updatedData,
                        where: 'invoice_no = ?', whereArgs: [oldInvoice]);
                  }
                  await FirebaseTransactionService.instance
                      .updateTransactionInFirebase(
                    invoiceNo: oldInvoice.isNotEmpty ? oldInvoice : newInvoice,
                    localId: txId > 0 ? txId : null,
                    namaProduk: nameCtrl.text.trim(),
                    userEmail: emailCtrl.text.trim(),
                    updatedData: updatedData,
                  );
                } catch (e) {
                  debugPrint('Error editing transaction: $e');
                }
              },
              child: Text(LanguageService.tr('simpan'),
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteTransactionDialog(Map<String, dynamic> tx) {
    final int txId = (tx['id'] as num?)?.toInt() ?? 0;
    final String invoiceNo =
        (tx['invoice_no'] ?? tx['id_ref'] ?? '').toString();
    final String productName = tx['nama_produk']?.toString() ?? 'Layanan';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          LanguageService.text('Hapus Transaksi', 'Delete Transaction'),
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: _textPrimary),
        ),
        content: Text(
          LanguageService.text(
            'Apakah Anda yakin ingin menghapus transaksi $invoiceNo ($productName)?',
            'Are you sure you want to delete transaction $invoiceNo ($productName)?',
          ),
          style: GoogleFonts.poppins(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LanguageService.tr('batal'),
                style: GoogleFonts.poppins(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);

              // 1. Optimistic UI update
              setState(() {
                _allTransactions.removeWhere((t) =>
                    (txId > 0 && t['id'] == txId) ||
                    (invoiceNo.isNotEmpty &&
                        (t['invoice_no'] == invoiceNo ||
                            t['id_ref'] == invoiceNo)));
              });
              _applyTxFilter();

              _showSnackBar('Transaksi $invoiceNo berhasil dihapus!');

              // 2. Hapus dari SQLite & Firebase RTDB
              try {
                if (txId > 0) {
                  await DatabaseHelper.instance
                      .deleteTransaction(txId, invoiceNo: invoiceNo);
                } else if (invoiceNo.isNotEmpty) {
                  await DatabaseHelper.instance
                      .deleteTransactionByInvoice(invoiceNo);
                }
                await FirebaseTransactionService.instance
                    .deleteTransactionFromFirebase(
                  invoiceNo: invoiceNo.isNotEmpty ? invoiceNo : null,
                  localId: txId > 0 ? txId : null,
                  namaProduk: productName,
                  userEmail: tx['user_email']?.toString(),
                );
              } catch (e) {
                debugPrint('Error deleting transaction: $e');
              }
            },
            child: Text(LanguageService.tr('hapus'),
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetailModal(Map<String, dynamic> tx) {
    final currencyFormatter = NumberFormat('#,###', 'id_ID');
    final String invoiceNo = tx['invoice_no']?.toString() ?? 'INV-${tx['id']}';
    final String userEmail =
        tx['user_email']?.toString() ?? 'customer@vibetech.xyz';
    final String namaProduk =
        tx['nama_produk']?.toString() ?? 'Layanan Digital';
    final double totalHarga = (tx['total_harga'] as num?)?.toDouble() ?? 0.0;
    final String status = tx['status']?.toString() ?? 'Pending';
    final String tanggal = tx['tanggal']?.toString() ?? '-';
    final String paymentMethod =
        tx['payment_method']?.toString() ?? 'Midtrans / Gateway';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    LanguageService.text(
                        'Rincian Pesanan Member', 'Member Order Details'),
                    style: GoogleFonts.poppins(
                      color: _textPrimary,
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: _textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isDarkMode
                      ? Colors.black.withValues(alpha: 0.3)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _cardBorder),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Nomor Invoice', invoiceNo, isBold: true),
                    const Divider(height: 16),
                    _buildDetailRow('Email Member', userEmail),
                    const Divider(height: 16),
                    _buildDetailRow('Nama Produk / Layanan', namaProduk),
                    const Divider(height: 16),
                    _buildDetailRow('Metode Pembayaran', paymentMethod),
                    const Divider(height: 16),
                    _buildDetailRow('Waktu Transaksi', tanggal),
                    const Divider(height: 16),
                    _buildDetailRow('Status Pesanan', status,
                        isStatus: true,
                        statusColor: status.toLowerCase() == 'selesai'
                            ? const Color(0xFF00E676)
                            : const Color(0xFFFF9100)),
                    const Divider(height: 16),
                    _buildDetailRow(
                      'Total Pembayaran',
                      'Rp ${currencyFormatter.format(totalHarga.toInt()).replaceAll(',', '.')}',
                      isPrice: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditTransactionDialog(tx);
                      },
                      icon: const Icon(Icons.edit_rounded,
                          color: Colors.white, size: 16),
                      label: Text(
                        LanguageService.text('Edit', 'Edit'),
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showDeleteTransactionDialog(tx);
                      },
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.white, size: 16),
                      label: Text(
                        LanguageService.text('Hapus', 'Delete'),
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isBold = false,
      bool isPrice = false,
      bool isStatus = false,
      Color? statusColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: _textSecondary,
            fontSize: 12,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              color: isPrice
                  ? const Color(0xFF00E676)
                  : (isStatus
                      ? (statusColor ?? const Color(0xFF00E676))
                      : _textPrimary),
              fontSize: isPrice ? 14 : 12,
              fontWeight: isBold || isPrice || isStatus
                  ? FontWeight.bold
                  : FontWeight.w500,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // MODAL 1: EDIT USER (USERNAME, PASSWORD, PIN, NAMA, ROLE, SALDO)
  // ===========================================================================
  void _showEditUserModal(Map<String, dynamic> user) {
    final int id = user['id'] as int;
    final String existingPass = user['password']?.toString() ?? '';
    final String existingPin = user['pin']?.toString() ?? '123456';
    final bool isHashedPass = existingPass.startsWith('vbt\$sha256\$');
    final bool isHashedPin = existingPin.startsWith('vbt\$pin\$');

    final TextEditingController usernameCtrl =
        TextEditingController(text: user['username'] ?? '');
    final TextEditingController passwordCtrl =
        TextEditingController(text: isHashedPass ? '' : existingPass);
    final TextEditingController pinCtrl =
        TextEditingController(text: isHashedPin ? '' : existingPin);
    final TextEditingController namaCtrl =
        TextEditingController(text: user['nama'] ?? '');
    final TextEditingController emailCtrl =
        TextEditingController(text: user['email'] ?? '');
    final TextEditingController phoneCtrl =
        TextEditingController(text: user['phone'] ?? '');
    final TextEditingController saldoCtrl = TextEditingController(
        text: ((user['saldo'] as num?)?.toDouble() ?? 0.0).toInt().toString());

    String selectedRole =
        (user['role'] ?? 'user').toString().toLowerCase() == 'admin'
            ? 'admin'
            : 'user';
    bool hidePassword = true;
    bool hidePin = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LanguageService.text(
                                'Edit Kredensial Pengguna',
                                'Edit User Credentials',
                              ),
                              style: GoogleFonts.poppins(
                                color: _textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'ID: ${user['uid'] ?? id} • ${user['email']}',
                              style: GoogleFonts.poppins(
                                color: _textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon:
                              Icon(Icons.close_rounded, color: _textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: _cardBorder, height: 1),
                    const SizedBox(height: 16),

                    // 1. Username Field
                    _buildInputField(
                      controller: usernameCtrl,
                      label: LanguageService.text('Username', 'Username'),
                      hint: 'username',
                      icon: Icons.alternate_email_rounded,
                    ),
                    const SizedBox(height: 12),

                    // 2. Password Field with Toggle
                    _buildInputField(
                      controller: passwordCtrl,
                      label:
                          LanguageService.text('Password Baru', 'New Password'),
                      hint: 'password',
                      icon: Icons.lock_outline_rounded,
                      isPassword: hidePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: _textSecondary,
                          size: 18,
                        ),
                        onPressed: () =>
                            setModalState(() => hidePassword = !hidePassword),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 3. PIN Transaksi 6-Digit Field with Toggle
                    _buildInputField(
                      controller: pinCtrl,
                      label: LanguageService.text('PIN Transaksi (6-Digit)',
                          'Transaction PIN (6-Digit)'),
                      hint: '123456',
                      icon: Icons.pin_rounded,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      isPassword: hidePin,
                      suffixIcon: IconButton(
                        icon: Icon(
                          hidePin
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: _textSecondary,
                          size: 18,
                        ),
                        onPressed: () =>
                            setModalState(() => hidePin = !hidePin),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 4. Nama Lengkap Field
                    _buildInputField(
                      controller: namaCtrl,
                      label: LanguageService.text('Nama Lengkap', 'Full Name'),
                      hint: 'Nama Lengkap',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 12),

                    // 5. Email & Phone
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            controller: emailCtrl,
                            label: 'Email',
                            hint: 'user@vibetech.xyz',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInputField(
                            controller: phoneCtrl,
                            label: LanguageService.text('No. HP', 'Phone'),
                            hint: '08123456789',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 6. Role Selector (Member vs Administrator)
                    Text(
                      LanguageService.text('Hak Akses / Role', 'Access Role'),
                      style: GoogleFonts.poppins(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: AppBounceTap(
                            onTap: () =>
                                setModalState(() => selectedRole = 'user'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selectedRole == 'user'
                                    ? const Color(0xFF00B0FF)
                                        .withValues(alpha: 0.2)
                                    : _cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selectedRole == 'user'
                                      ? const Color(0xFF00B0FF)
                                      : _cardBorder,
                                  width: selectedRole == 'user' ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_rounded,
                                    size: 16,
                                    color: selectedRole == 'user'
                                        ? const Color(0xFF00B0FF)
                                        : _textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Member',
                                    style: GoogleFonts.poppins(
                                      color: selectedRole == 'user'
                                          ? const Color(0xFF00B0FF)
                                          : _textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppBounceTap(
                            onTap: () =>
                                setModalState(() => selectedRole = 'admin'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selectedRole == 'admin'
                                    ? const Color(0xFF7C4DFF)
                                        .withValues(alpha: 0.2)
                                    : _cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selectedRole == 'admin'
                                      ? const Color(0xFF7C4DFF)
                                      : _cardBorder,
                                  width: selectedRole == 'admin' ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings_rounded,
                                    size: 16,
                                    color: selectedRole == 'admin'
                                        ? const Color(0xFF7C4DFF)
                                        : _textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Administrator',
                                    style: GoogleFonts.poppins(
                                      color: selectedRole == 'admin'
                                          ? const Color(0xFF7C4DFF)
                                          : _textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 7. Saldo VibeWallet Field
                    _buildInputField(
                      controller: saldoCtrl,
                      label: LanguageService.text(
                          'Saldo VibeWallet (Rp)', 'VibeWallet Balance (Rp)'),
                      hint: '0',
                      icon: Icons.account_balance_wallet_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final newUsername = usernameCtrl.text.trim();
                          final typedPass = passwordCtrl.text.trim();
                          final typedPin = pinCtrl.text.trim();
                          final newPass = typedPass.isNotEmpty ? typedPass : existingPass;
                          final newPin = typedPin.isNotEmpty ? typedPin : existingPin;
                          final newNama = namaCtrl.text.trim();
                          final newEmail = emailCtrl.text.trim();
                          final newPhone = phoneCtrl.text.trim();
                          final double newSaldo =
                              double.tryParse(saldoCtrl.text.trim()) ?? 0.0;

                          if (newUsername.isEmpty ||
                              newPass.isEmpty ||
                              newPin.isEmpty) {
                            _showSnackBar(
                              LanguageService.text(
                                'Username, Password, dan PIN tidak boleh kosong!',
                                'Username, Password, and PIN cannot be empty!',
                              ),
                              isError: true,
                            );
                            return;
                          }

                          if (typedPin.isNotEmpty &&
                              (typedPin.length != 6 ||
                                  int.tryParse(typedPin) == null)) {
                            _showSnackBar(
                              LanguageService.text(
                                'PIN Transaksi harus berupa 6 digit angka!',
                                'Transaction PIN must be 6 numeric digits!',
                              ),
                              isError: true,
                            );
                            return;
                          }

                          // Update ke Database SQLite
                          final updateData = {
                            'username': newUsername,
                            'password': newPass,
                            'pin': newPin,
                            'nama': newNama.isNotEmpty ? newNama : newUsername,
                            'email': newEmail.isNotEmpty
                                ? newEmail
                                : '$newUsername@vibetech.xyz',
                            'phone': newPhone,
                            'role': selectedRole,
                            'saldo': newSaldo,
                          };

                          await DatabaseHelper.instance
                              .updateUserFull(id, updateData);

                          // Sinkronkan ke Firebase RTDB & Firestore di latar belakang (Non-blocking)
                          FirebaseUserService.instance
                              .updateUserInFirebase(
                            uid: user['uid']?.toString(),
                            email: newEmail,
                            username: newUsername,
                            docId: user['doc_id']?.toString(),
                            updatedData: updateData,
                          )
                              .catchError((e) {
                            debugPrint(
                                '[AdminDatabasePage] Background update user error: $e');
                            return false;
                          });

                          // Sinkronisasi session SharedPreferences jika admin mengedit dirinya sendiri
                          final bool isEditingSelf = (user['username']
                                          ?.toString()
                                          .toLowerCase() ==
                                      widget.currentAdminUsername
                                          .toLowerCase() ||
                                  user['email']?.toString().toLowerCase() ==
                                      widget.currentAdminEmail.toLowerCase()) ||
                              (widget.currentAdminEmail.toLowerCase() ==
                                  newEmail.toLowerCase());

                          if (isEditingSelf) {
                            try {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setString('username',
                                  newNama.isNotEmpty ? newNama : newUsername);
                              await prefs.setString('email', newEmail);
                              await prefs.setString('role', selectedRole);
                              await BalanceService.loadUserBalance(newEmail);
                            } catch (_) {}
                          }

                          if (context.mounted) Navigator.pop(context);
                          _showSnackBar(LanguageService.text(
                            'Data akun $newUsername berhasil diperbarui!',
                            'Account data for $newUsername updated successfully!',
                          ));
                          _loadUsersData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C4DFF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          LanguageService.text(
                              'Simpan Perubahan', 'Save Changes'),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // MODAL 2: RIWAYAT PEMBELIAN & LAYANAN AKTIF PENGGUNA
  // ===========================================================================
  void _showPurchaseHistoryModal(Map<String, dynamic> user) {
    final String nama = user['nama'] ?? user['username'] ?? 'User';
    final String username = user['username'] ?? '';
    final String email = user['email'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _UserPurchaseHistorySheet(
          isDarkMode: _isDarkMode,
          userName: nama,
          username: username,
          userEmail: email,
        );
      },
    );
  }

  // ===========================================================================
  // MODAL 3: TAMBAH AKUN PENGGUNA / ADMIN BARU
  // ===========================================================================
  void _showAddUserDialog() {
    final TextEditingController usernameCtrl = TextEditingController();
    final TextEditingController passwordCtrl = TextEditingController();
    final TextEditingController pinCtrl = TextEditingController(text: '123456');
    final TextEditingController namaCtrl = TextEditingController();
    final TextEditingController emailCtrl = TextEditingController();
    final TextEditingController phoneCtrl = TextEditingController();
    final TextEditingController saldoCtrl =
        TextEditingController(text: '100000');
    String selectedRole = 'user';
    bool hidePassword = true;
    bool hidePin = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          LanguageService.text(
                            'Tambah Pengguna Baru',
                            'Add New User',
                          ),
                          style: GoogleFonts.poppins(
                            color: _textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon:
                              Icon(Icons.close_rounded, color: _textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      controller: usernameCtrl,
                      label: LanguageService.text('Username', 'Username'),
                      hint: 'contoh_user',
                      icon: Icons.alternate_email_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildInputField(
                      controller: passwordCtrl,
                      label: 'Password',
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      isPassword: hidePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: _textSecondary,
                          size: 18,
                        ),
                        onPressed: () =>
                            setModalState(() => hidePassword = !hidePassword),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInputField(
                      controller: pinCtrl,
                      label: LanguageService.text('PIN Transaksi (6-Digit)',
                          'Transaction PIN (6-Digit)'),
                      hint: '123456',
                      icon: Icons.pin_rounded,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      isPassword: hidePin,
                      suffixIcon: IconButton(
                        icon: Icon(
                          hidePin
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: _textSecondary,
                          size: 18,
                        ),
                        onPressed: () =>
                            setModalState(() => hidePin = !hidePin),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInputField(
                      controller: namaCtrl,
                      label: LanguageService.text('Nama Lengkap', 'Full Name'),
                      hint: 'John Doe',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            controller: emailCtrl,
                            label: 'Email',
                            hint: 'user@vibetech.xyz',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInputField(
                            controller: phoneCtrl,
                            label: LanguageService.text('No. HP', 'Phone'),
                            hint: '08123456789',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      LanguageService.text('Role', 'Role'),
                      style: GoogleFonts.poppins(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: AppBounceTap(
                            onTap: () =>
                                setModalState(() => selectedRole = 'user'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selectedRole == 'user'
                                    ? const Color(0xFF00B0FF)
                                        .withValues(alpha: 0.2)
                                    : _cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selectedRole == 'user'
                                      ? const Color(0xFF00B0FF)
                                      : _cardBorder,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Member',
                                  style: GoogleFonts.poppins(
                                    color: selectedRole == 'user'
                                        ? const Color(0xFF00B0FF)
                                        : _textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppBounceTap(
                            onTap: () =>
                                setModalState(() => selectedRole = 'admin'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selectedRole == 'admin'
                                    ? const Color(0xFF7C4DFF)
                                        .withValues(alpha: 0.2)
                                    : _cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selectedRole == 'admin'
                                      ? const Color(0xFF7C4DFF)
                                      : _cardBorder,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Administrator',
                                  style: GoogleFonts.poppins(
                                    color: selectedRole == 'admin'
                                        ? const Color(0xFF7C4DFF)
                                        : _textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInputField(
                      controller: saldoCtrl,
                      label: LanguageService.text(
                          'Saldo Awal (Rp)', 'Initial Balance (Rp)'),
                      hint: '0',
                      icon: Icons.account_balance_wallet_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final u = usernameCtrl.text.trim();
                          final p = passwordCtrl.text.trim();
                          final pin = pinCtrl.text.trim();
                          final n = namaCtrl.text.trim();
                          final e = emailCtrl.text.trim();
                          final ph = phoneCtrl.text.trim();
                          final s =
                              double.tryParse(saldoCtrl.text.trim()) ?? 0.0;

                          if (u.isEmpty || p.isEmpty || pin.isEmpty) {
                            _showSnackBar(
                              LanguageService.text(
                                'Username, Password, dan PIN wajib diisi!',
                                'Username, Password, and PIN are required!',
                              ),
                              isError: true,
                            );
                            return;
                          }

                          final newUser = {
                            'uid':
                                'usr_${DateTime.now().millisecondsSinceEpoch}',
                            'username': u,
                            'password': SecurityHelper.hashPassword(p),
                            'pin': SecurityHelper.hashPin(pin),
                            'nama': n.isNotEmpty ? n : u,
                            'email': e.isNotEmpty ? e : '$u@vibetech.xyz',
                            'phone': ph.isNotEmpty ? ph : '08123456789',
                            'role': selectedRole,
                            'saldo': s,
                            'createdAt': DateTime.now().toIso8601String(),
                            'location': 'Indonesia',
                            'is2FA': 1,
                            'language': 'Indonesia',
                          };

                          await DatabaseHelper.instance.addUser(newUser);
                          await FirebaseUserService.instance
                              .saveUserToFirebase(newUser);
                          if (context.mounted) Navigator.pop(context);
                          _showSnackBar(LanguageService.text(
                            'Akun $u berhasil didaftarkan ke SQLite & Firebase RTDB!',
                            'Account $u registered to SQLite & Firebase RTDB successfully!',
                          ));
                          _loadUsersData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          LanguageService.text(
                              'Daftarkan Pengguna', 'Register User'),
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // MODAL 4: KONFIRMASI HAPUS PENGGUNA (CONFIRM DELETE MODAL)
  // ===========================================================================
  void _showDeleteUserConfirm(Map<String, dynamic> user) {
    final String username =
        (user['username'] ?? user['nama'] ?? 'User').toString();
    final String nama = (user['nama'] ?? username).toString();
    final String email = (user['email'] ?? '').toString();

    final bool isCurrentAdmin =
        username.toLowerCase() == widget.currentAdminUsername.toLowerCase() ||
            (email.isNotEmpty &&
                email.toLowerCase() == widget.currentAdminEmail.toLowerCase());

    if (isCurrentAdmin) {
      _showSnackBar(
        LanguageService.text(
          'Tidak dapat menghapus akun Administrator yang sedang aktif digunakan!',
          'Cannot delete the currently active Administrator account!',
        ),
        isError: true,
      );
      return;
    }

    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalCtx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: AppColors.error.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Icon Danger
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.error,
                  size: 40,
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                LanguageService.text(
                    'Konfirmasi Hapus Akun', 'Confirm Delete Account'),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                LanguageService.text(
                  'Apakah Anda yakin ingin menghapus akun @$username ($nama)?\nData pengguna akan dihapus secara permanen dari SQLite dan Cloud Firebase.',
                  'Are you sure you want to delete account @$username ($nama)?\nUser data will be permanently removed from SQLite and Cloud Firebase.',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: _textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),

              // Action Buttons: Batal & Hapus Sekarang
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(modalCtx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: _cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        LanguageService.text('Batal', 'Cancel'),
                        style: GoogleFonts.poppins(
                          color: _textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(modalCtx);
                        _deleteUserDirectly(user);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        LanguageService.text('Hapus Sekarang', 'Delete Now'),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 1-CLICK DIRECT USER DELETION ---
  Future<void> _deleteUserDirectly(Map<String, dynamic> user) async {
    try {
      final int id = (user['id'] as num?)?.toInt() ?? 0;
      final String username = user['username'] ?? user['nama'] ?? 'User';
      final String email = (user['email'] ?? '').toString();
      final String? uid = user['uid']?.toString();

      final bool isCurrentAdmin = username.toLowerCase() ==
              widget.currentAdminUsername.toLowerCase() ||
          (email.isNotEmpty &&
              email.toLowerCase() == widget.currentAdminEmail.toLowerCase());

      if (isCurrentAdmin) {
        _showSnackBar(
          LanguageService.text(
            'Tidak dapat menghapus akun Administrator yang sedang aktif digunakan!',
            'Cannot delete the currently active Administrator account!',
          ),
          isError: true,
        );
        return;
      }

      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}

      // 1. Langsung hapus dari state UI (0ms responsif)
      if (mounted) {
        setState(() {
          _allUsers = _allUsers.where((u) {
            final matchId = id > 0 && u['id'] == id;
            final matchUid = uid != null && uid.isNotEmpty && u['uid'] == uid;
            final matchEmail = email.isNotEmpty && u['email'] == email;
            final matchUser = username.isNotEmpty && u['username'] == username;
            return !(matchId || matchUid || matchEmail || matchUser);
          }).toList();

          _filteredUsers = _filteredUsers.where((u) {
            final matchId = id > 0 && u['id'] == id;
            final matchUid = uid != null && uid.isNotEmpty && u['uid'] == uid;
            final matchEmail = email.isNotEmpty && u['email'] == email;
            final matchUser = username.isNotEmpty && u['username'] == username;
            return !(matchId || matchUid || matchEmail || matchUser);
          }).toList();
        });
        _applyFilter();

        _showSnackBar(
          LanguageService.text(
            'Akun @$username berhasil dihapus!',
            'Account @$username deleted successfully!',
          ),
          isError: false,
        );
      }

      // 2. Hapus dari SQLite lokal
      await DatabaseHelper.instance.deleteUser(
        id,
        uid: uid,
        email: email,
        username: username,
      );

      // 3. Hapus dari Firebase Realtime Database, Cloud Firestore, dan Firebase Auth
      await FirebaseUserService.instance.deleteUserFromFirebase(
        uid: uid,
        email: email,
        username: username,
        docId: user['doc_id']?.toString(),
      );
    } catch (err) {
      debugPrint('[AdminDatabasePage] Error deleteUserDirectly: $err');
      if (mounted) {
        _showSnackBar('Gagal menghapus user: $err', isError: true);
      }
    }
  }

  // --- REUSABLE INPUT FIELD ---
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: _textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: _isDarkMode
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: keyboardType,
            maxLength: maxLength,
            buildCounter: (context,
                    {required currentLength, required isFocused, maxLength}) =>
                null,
            style: GoogleFonts.poppins(color: _textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                color: _textSecondary.withValues(alpha: 0.6),
                fontSize: 12.5,
              ),
              prefixIcon: Icon(icon, color: _textSecondary, size: 18),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? AppColors.error : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ============================================================================
  // KONFIGURASI SERVER EMAIL (SMTP) UNTUK ADMINISTRATOR
  // ============================================================================
  void _showSmtpConfigDialog() async {
    final prefs = await SharedPreferences.getInstance();

    Map<String, dynamic>? dbSettings;
    try {
      dbSettings = await DatabaseHelper.instance.getEmailSettings(
            userEmail: widget.currentAdminEmail,
          ) ??
          await DatabaseHelper.instance.getEmailSettings();
    } catch (_) {}

    String initialUser = (dbSettings?['smtp_user']?.toString() ?? '').trim();
    if (initialUser.isEmpty) {
      initialUser = (prefs.getString('smtp_user') ?? widget.currentAdminEmail).trim();
    }
    String initialPass = (dbSettings?['smtp_pass']?.toString() ?? '').trim();
    if (initialPass.isEmpty) {
      initialPass = (prefs.getString('smtp_pass') ?? '').trim();
    }
    String initialHost = (dbSettings?['smtp_host']?.toString() ?? '').trim();
    if (initialHost.isEmpty) {
      initialHost = (prefs.getString('smtp_host') ?? 'smtp.gmail.com').trim();
    }
    int initialPort = (dbSettings?['smtp_port'] as num?)?.toInt() ??
        prefs.getInt('smtp_port') ??
        465;
    String? lastUpdated = dbSettings?['updated_at']?.toString() ??
        prefs.getString('smtp_updated_at');

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
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final bool isConfigured = (userController.text.trim().isNotEmpty &&
                  passController.text.trim().isNotEmpty) ||
              (prefs.getBool('smtp_is_active') == true &&
                  userController.text.trim().isNotEmpty);

          return AlertDialog(
            backgroundColor: _cardColor,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.mark_email_read_rounded,
                      color: Color(0xFF00E676), size: 20),
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
                              size: 12, color: Color(0xFF00E676)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              LanguageService.text(
                                'Cloud Firestore & SQLite Permanen',
                                'Cloud Firestore & Local SQLite Permanent',
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: const Color(0xFF00E676),
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
                  if (isConfigured)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF00E676).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF00E676), size: 20),
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
                                  color: const Color(0xFF00E676),
                                ),
                              ),
                              Text(
                                LanguageService.text(
                                  'Tersimpan otomatis di SQLite & Cloud. Notifikasi & invoice dikirim otomatis.',
                                  'Saved in SQLite & Cloud. Notifications & invoices sent automatically.',
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
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 18, color: Color(0xFF7C4DFF)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              LanguageService.text(
                                'Gunakan Sandi Aplikasi Google (16 digit) agar pengiriman invoice, transaksi, dan notifikasi otomatis berjalan lancar.',
                                'Use a 16-character Google App Password so automated transaction invoices and emails work seamlessly.',
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
                            color:
                                const Color(0xFF7C4DFF).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.open_in_new_rounded,
                                  size: 14, color: Color(0xFF7C4DFF)),
                              const SizedBox(width: 6),
                              Text(
                                LanguageService.text(
                                    'Buat Sandi Aplikasi di Google (1-Klik)',
                                    'Create App Password on Google (1-Tap)'),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF7C4DFF),
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
                _buildAdminDialogField(
                  controller: userController,
                  label: 'Email Pengirim (Gmail / Domain SMTP)',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _buildAdminDialogField(
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
                      child: _buildAdminDialogField(
                        controller: hostController,
                        label: 'Host SMTP',
                        icon: Icons.dns_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildAdminDialogField(
                        controller: portController,
                        label: 'Port',
                        icon: Icons.numbers_rounded,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                if ((lastUpdated ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 12, color: Color(0xFF00E676)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          LanguageService.text(
                            'Sinkronisasi Database aktif (${lastUpdated!})',
                            'Database sync active (${lastUpdated!})',
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
                              _showSnackBar(
                                LanguageService.text(
                                    'Email pengirim dan Sandi Aplikasi (16 digit) wajib diisi!',
                                    'Sender email and App Password (16-char) are required!'),
                                isError: true,
                              );
                              return;
                            }

                            setDialogState(() => isSendingTest = true);

                            final targetEmail = widget.currentAdminEmail.isNotEmpty
                                ? widget.currentAdminEmail
                                : user;

                            final res =
                                await NotificationService.sendDirectSmtpTest(
                              smtpUser: user,
                              smtpPass: pass,
                              targetEmail: targetEmail,
                              smtpHost:
                                  host.isNotEmpty ? host : 'smtp.gmail.com',
                              smtpPort: port,
                            );

                            if (mounted) {
                              setDialogState(() => isSendingTest = false);
                            }

                            if (res['success'] == true) {
                              try {
                                await DatabaseHelper.instance.saveEmailSettings(
                                  smtpUser: user,
                                  smtpPass: pass,
                                  smtpHost:
                                      host.isNotEmpty ? host : 'smtp.gmail.com',
                                  smtpPort: port,
                                  userEmail: widget.currentAdminEmail,
                                  syncToCloud: true,
                                );
                                final p = await SharedPreferences.getInstance();
                                await p.setString('smtp_user', user);
                                await p.setString('smtp_pass', pass);
                                await p.setString('smtp_host',
                                    host.isNotEmpty ? host : 'smtp.gmail.com');
                                await p.setInt('smtp_port', port);
                                await p.setBool('smtp_is_active', true);
                                final nowStr =
                                    DateTime.now().toString().split('.')[0];
                                await p.setString('smtp_updated_at', nowStr);
                                setDialogState(() {
                                  lastUpdated = nowStr;
                                });
                                FirebaseEmailService.instance
                                    .saveEmailSettings(
                                      smtpUser: user,
                                      smtpPass: pass,
                                      smtpHost: host.isNotEmpty
                                          ? host
                                          : 'smtp.gmail.com',
                                      smtpPort: port,
                                      userEmail: widget.currentAdminEmail,
                                    )
                                    .catchError((_) => false);
                                await NotificationService.setEmailEnabled(
                                    true, widget.currentAdminUsername);
                                if (mounted) {
                                  setState(() {
                                    _smtpUser = user;
                                    _isSmtpActive = true;
                                  });
                                }
                              } catch (_) {}

                              _showSnackBar(
                                LanguageService.text(
                                  '✅ Email tes berhasil terkirim! Konfigurasi SMTP langsung AKTIF PERMANEN & tersimpan otomatis.',
                                  '✅ Test email sent! SMTP is now PERMANENTLY ACTIVE & saved automatically.',
                                ),
                              );
                            } else {
                              _showSnackBar('${res['message']}', isError: true);
                            }
                          },
                    icon: isSendingTest
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF7C4DFF),
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      isSendingTest
                          ? LanguageService.text('Menguji Koneksi...', 'Testing Connection...')
                          : LanguageService.text(
                              'Kirim Email Tes ke ${widget.currentAdminEmail.isNotEmpty ? widget.currentAdminEmail : 'Admin'}',
                              'Send Test Email to ${widget.currentAdminEmail.isNotEmpty ? widget.currentAdminEmail : 'Admin'}'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7C4DFF),
                      side: const BorderSide(
                          color: Color(0xFF7C4DFF), width: 1.2),
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
              onPressed: () =>
                  Navigator.of(dialogCtx, rootNavigator: true).pop(),
              child: Text(
                LanguageService.text('Tutup', 'Close'),
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
                        _showSnackBar(
                          LanguageService.text('Email pengirim wajib diisi!',
                              'Sender email is required!'),
                          isError: true,
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);

                      try {
                        await DatabaseHelper.instance.saveEmailSettings(
                          smtpUser: user,
                          smtpPass: pass,
                          smtpHost: host.isNotEmpty ? host : 'smtp.gmail.com',
                          smtpPort: port,
                          userEmail: widget.currentAdminEmail,
                          syncToCloud: true,
                        );

                        final p = await SharedPreferences.getInstance();
                        await p.setString('smtp_user', user);
                        await p.setString('smtp_pass', pass);
                        await p.setString('smtp_host',
                            host.isNotEmpty ? host : 'smtp.gmail.com');
                        await p.setInt('smtp_port', port);
                        await p.setBool('smtp_is_active', true);
                        await p.setString('smtp_updated_at',
                            DateTime.now().toString().split('.')[0]);

                        FirebaseEmailService.instance
                            .saveEmailSettings(
                              smtpUser: user,
                              smtpPass: pass,
                              smtpHost:
                                  host.isNotEmpty ? host : 'smtp.gmail.com',
                              smtpPort: port,
                              userEmail: widget.currentAdminEmail,
                            )
                            .catchError((_) => false);

                        await NotificationService.setEmailEnabled(
                            true, widget.currentAdminUsername);

                        if (mounted) {
                          setState(() {
                            _smtpUser = user;
                            _isSmtpActive = true;
                          });
                        }

                        if (dialogCtx.mounted) {
                          Navigator.of(dialogCtx, rootNavigator: true).pop();
                        }

                        _showSnackBar(
                          LanguageService.text(
                            '✅ Konfigurasi SMTP Administrator berhasil disimpan permanen & AKTIF PERMANEN!',
                            '✅ Administrator SMTP configuration saved permanently & ACTIVE!',
                          ),
                        );
                      } catch (e) {
                        if (mounted) {
                          setDialogState(() => isSaving = false);
                        }
                        _showSnackBar('Gagal menyimpan SMTP: $e',
                            isError: true);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
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
                      LanguageService.text('Simpan & Aktifkan', 'Save & Activate'),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        );
      },
    ),
  );
}

  Widget _buildAdminDialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293D) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withValues(alpha: 0.15)
              : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(
          color: _textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: _textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          icon: Icon(icon, color: const Color(0xFF7C4DFF), size: 20),
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
}

// =============================================================================
// SUB-COMPONENT: USER PURCHASE & ACTIVE SERVICES HISTORY SHEET
// =============================================================================
class _UserPurchaseHistorySheet extends StatefulWidget {
  final bool isDarkMode;
  final String userName;
  final String username;
  final String userEmail;

  const _UserPurchaseHistorySheet({
    required this.isDarkMode,
    required this.userName,
    required this.username,
    required this.userEmail,
  });

  @override
  State<_UserPurchaseHistorySheet> createState() =>
      _UserPurchaseHistorySheetState();
}

class _UserPurchaseHistorySheetState extends State<_UserPurchaseHistorySheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _services = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserOrdersAndServices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserOrdersAndServices() async {
    setState(() => _isLoading = true);
    try {
      final txs =
          await DatabaseHelper.instance.getTransactionsByUser(widget.userEmail);
      final srvs =
          await DatabaseHelper.instance.getServicesByUser(widget.userEmail);
      final st = await DatabaseHelper.instance
          .getUserOrdersStats(widget.userEmail, isAdmin: false);

      // Sinkronisasi live dari Firebase Realtime Database
      List<Map<String, dynamic>> cloudTx = [];
      try {
        cloudTx = await FirebaseTransactionService.instance
            .getTransactionsByUser(widget.userEmail);
      } catch (_) {}

      final Map<String, Map<String, dynamic>> map = {};
      for (final t in txs) {
        final key = (t['invoice_no'] ?? 'loc_${t['id']}').toString();
        map[key] = Map<String, dynamic>.from(t);
      }
      for (final t in cloudTx) {
        final key = (t['invoice_no'] ??
                t['id_ref'] ??
                'cloud_${DateTime.now().millisecondsSinceEpoch}')
            .toString();
        if (!map.containsKey(key)) {
          map[key] = Map<String, dynamic>.from(t);
        } else {
          final cur = map[key]!['status']?.toString().toLowerCase();
          final cld = t['status']?.toString().toLowerCase();
          if (cld == 'selesai' && cur != 'selesai') {
            map[key]!['status'] = t['status'];
          }
        }
      }

      final combinedTx = map.values.toList();
      combinedTx.sort((a, b) {
        final dateA = (a['tanggal'] ?? a['created_at'] ?? '').toString();
        final dateB = (b['tanggal'] ?? b['created_at'] ?? '').toString();
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _transactions = combinedTx;
          _services = srvs;
          _stats = st;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading purchase history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color get _cardColor =>
      widget.isDarkMode ? AppColors.darkCard : AppColors.lightCard;
  Color get _cardBorder => widget.isDarkMode
      ? const Color(0xFF7C4DFF).withValues(alpha: 0.22)
      : const Color(0xFFE2E8F0);
  Color get _textPrimary => widget.isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.lightTextPrimary;
  Color get _textSecondary => widget.isDarkMode
      ? AppColors.darkTextSecondary
      : AppColors.lightTextSecondary;

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,###', 'id_ID');
    final double totalSpent = (_stats['totalSpent'] as num?)?.toDouble() ?? 0.0;
    final int totalOrders = _stats['total'] as int? ?? _transactions.length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LanguageService.text(
                          'Riwayat Pembelian & Layanan',
                          'Purchase & Services History',
                        ),
                        style: GoogleFonts.poppins(
                          color: _textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${widget.userName} (@${widget.username}) • ${widget.userEmail}',
                        style: GoogleFonts.poppins(
                          color: _textSecondary,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: _textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Quick Summary Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      LanguageService.text('Total Pesanan', 'Total Orders'),
                      '$totalOrders',
                      Icons.shopping_bag_outlined,
                    ),
                  ),
                  Container(
                    height: 28,
                    width: 1,
                    color: Colors.white.withValues(alpha: 0.3),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  Expanded(
                    child: _buildSummaryItem(
                      LanguageService.text('Layanan Aktif', 'Active Services'),
                      '${_services.length}',
                      Icons.dns_outlined,
                    ),
                  ),
                  Container(
                    height: 28,
                    width: 1,
                    color: Colors.white.withValues(alpha: 0.3),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  Expanded(
                    child: _buildSummaryItem(
                      LanguageService.text('Total Belanja', 'Total Spent'),
                      'Rp ${currencyFormatter.format(totalSpent.toInt()).replaceAll(',', '.')}',
                      Icons.payments_outlined,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tab Bar with Cyberpunk Pill Style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: _textSecondary,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                tabs: [
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${LanguageService.text('Transaksi', 'Transactions')} (${_transactions.length})',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${LanguageService.text('Layanan Aktif', 'Active Services')} (${_services.length})',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTransactionsTab(),
                      _buildServicesTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 3),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 9.5,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  // --- TAB 1: TRANSAKSI PESANAN ---
  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 40, color: _textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text(
              LanguageService.text(
                'Belum ada riwayat transaksi pemesanan',
                'No transaction history yet',
              ),
              style: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final currencyFormatter = NumberFormat('#,###', 'id_ID');

    return ListView.separated(
      padding: const EdgeInsets.all(18),
      physics: const BouncingScrollPhysics(),
      itemCount: _transactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final String namaProduk = tx['nama_produk']?.toString() ?? 'Produk';
        final double total = (tx['total_harga'] as num?)?.toDouble() ?? 0.0;
        final String status = tx['status']?.toString() ?? 'Selesai';
        final String tanggal = tx['tanggal']?.toString() ?? '-';
        final String invoice =
            tx['invoice_no']?.toString() ?? 'INV-${tx['id']}';
        final String method = tx['payment_method']?.toString() ?? 'VibeWallet';

        Color statusColor = const Color(0xFF00E676);
        final sLower = status.toLowerCase();
        if (sLower.contains('pending') || sLower.contains('menunggu')) {
          statusColor = const Color(0xFFFFB300);
        } else if (sLower.contains('batal') || sLower.contains('cancel')) {
          statusColor = const Color(0xFFFF3D00);
        } else if (sLower.contains('proses')) {
          statusColor = const Color(0xFF00B0FF);
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDarkMode
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      invoice,
                      style: GoogleFonts.spaceMono(
                        color: const Color(0xFF00E5FF),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.poppins(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                namaProduk,
                style: GoogleFonts.poppins(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$tanggal • $method',
                      style: GoogleFonts.poppins(
                        color: _textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Rp ${currencyFormatter.format(total.toInt()).replaceAll(',', '.')}',
                      style: GoogleFonts.poppins(
                        color: _textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: _cardBorder.withValues(alpha: 0.4), height: 1),
              const SizedBox(height: 8),
              // Action Buttons: Edit & Hapus Transaksi
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppBounceTap(
                    onTap: () => _showEditTransactionModal(tx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              const Color(0xFF7C4DFF).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.edit_rounded,
                            size: 13,
                            color: Color(0xFF7C4DFF),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            LanguageService.text('Ubah Data', 'Edit Order'),
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF7C4DFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppBounceTap(
                    onTap: () => _showDeleteTransactionDialog(tx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3D00).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFFF3D00).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.delete_outline_rounded,
                            size: 13,
                            color: Color(0xFFFF3D00),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            LanguageService.text('Hapus', 'Delete'),
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFFF3D00),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 2: LAYANAN AKTIF ---
  Widget _buildServicesTab() {
    if (_services.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dns_outlined,
                size: 40, color: _textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text(
              LanguageService.text(
                'Pengguna ini belum memiliki layanan aktif',
                'This user does not have active services yet',
              ),
              style: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(18),
      physics: const BouncingScrollPhysics(),
      itemCount: _services.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final srv = _services[index];
        final String nama = srv['nama_produk']?.toString() ?? 'Layanan';
        final String kategori = srv['kategori']?.toString() ?? 'VPS';
        final String specs = srv['spesifikasi']?.toString() ?? '';
        final String ip = srv['ip_address']?.toString() ?? '-';
        final String port = srv['port']?.toString() ?? '-';
        final String exp = srv['tanggal_kadaluarsa']?.toString() ?? '';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDarkMode
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      nama,
                      style: GoogleFonts.poppins(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      kategori,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF7C4DFF),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (specs.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  specs,
                  style: GoogleFonts.poppins(
                    color: _textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Divider(color: _cardBorder.withValues(alpha: 0.4), height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'IP: $ip : $port',
                      style: GoogleFonts.spaceMono(
                        color: const Color(0xFF00E5FF),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Exp: ${exp.split('T').first}',
                    style: GoogleFonts.poppins(
                      color: _textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: _cardBorder.withValues(alpha: 0.4), height: 1),
              const SizedBox(height: 8),
              // Action Buttons: Edit & Hapus Layanan
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppBounceTap(
                    onTap: () => _showEditServiceModal(srv),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              const Color(0xFF7C4DFF).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.edit_rounded,
                            size: 13,
                            color: Color(0xFF7C4DFF),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            LanguageService.text(
                                'Ubah Layanan', 'Edit Service'),
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF7C4DFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppBounceTap(
                    onTap: () => _showDeleteServiceDialog(srv),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3D00).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFFF3D00).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.delete_outline_rounded,
                            size: 13,
                            color: Color(0xFFFF3D00),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            LanguageService.text('Hapus', 'Delete'),
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFFF3D00),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // EDIT & DELETE MODALS FOR PURCHASE HISTORY & ACTIVE SERVICES
  // ===========================================================================

  // 1. Modal Edit Transaksi
  void _showEditTransactionModal(Map<String, dynamic> tx) {
    final int id = tx['id'] as int;
    final TextEditingController invoiceCtrl =
        TextEditingController(text: tx['invoice_no']?.toString() ?? '');
    final TextEditingController produkCtrl =
        TextEditingController(text: tx['nama_produk']?.toString() ?? '');
    final TextEditingController totalCtrl = TextEditingController(
        text: ((tx['total_harga'] as num?)?.toDouble() ?? 0.0)
            .toInt()
            .toString());
    final TextEditingController tanggalCtrl =
        TextEditingController(text: tx['tanggal']?.toString() ?? '');
    final TextEditingController methodCtrl = TextEditingController(
        text: tx['payment_method']?.toString() ?? 'VibeWallet');

    String selectedStatus = tx['status']?.toString() ?? 'SELESAI';
    final List<String> statusList = [
      'SELESAI',
      'DIPROSES',
      'MENUNGGU PEMBAYARAN',
      'DIBATALKAN',
    ];
    if (!statusList.contains(selectedStatus.toUpperCase())) {
      selectedStatus = 'SELESAI';
    } else {
      selectedStatus = selectedStatus.toUpperCase();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          LanguageService.text(
                              'Ubah Data Transaksi', 'Edit Order Data'),
                          style: GoogleFonts.poppins(
                            color: _textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon:
                              Icon(Icons.close_rounded, color: _textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _buildSheetInputField(
                      controller: invoiceCtrl,
                      label:
                          LanguageService.text('Nomor Invoice', 'Invoice No'),
                      hint: 'INV-123456',
                      icon: Icons.receipt_rounded,
                    ),
                    const SizedBox(height: 12),

                    _buildSheetInputField(
                      controller: produkCtrl,
                      label:
                          LanguageService.text('Nama Produk', 'Product Name'),
                      hint: 'Nama Produk',
                      icon: Icons.shopping_bag_outlined,
                    ),
                    const SizedBox(height: 12),

                    _buildSheetInputField(
                      controller: totalCtrl,
                      label: LanguageService.text(
                          'Total Harga (Rp)', 'Total Price (Rp)'),
                      hint: '100000',
                      icon: Icons.payments_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),

                    // Dropdown Status Transaksi
                    Text(
                      LanguageService.text('Status Transaksi', 'Order Status'),
                      style: GoogleFonts.poppins(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: widget.isDarkMode
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedStatus,
                          isExpanded: true,
                          dropdownColor: _cardColor,
                          style: GoogleFonts.poppins(
                              color: _textPrimary, fontSize: 13),
                          items: statusList.map((st) {
                            return DropdownMenuItem<String>(
                              value: st,
                              child: Text(st),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedStatus = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildSheetInputField(
                      controller: methodCtrl,
                      label: LanguageService.text(
                          'Metode Pembayaran', 'Payment Method'),
                      hint: 'VibeWallet / QRIS / Bank',
                      icon: Icons.credit_card_rounded,
                    ),
                    const SizedBox(height: 12),

                    _buildSheetInputField(
                      controller: tanggalCtrl,
                      label: LanguageService.text(
                          'Tanggal Transaksi', 'Transaction Date'),
                      hint: 'YYYY-MM-DD HH:mm',
                      icon: Icons.calendar_today_rounded,
                    ),
                    const SizedBox(height: 20),

                    // Tombol Simpan
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final double harga =
                              double.tryParse(totalCtrl.text.trim()) ??
                                  ((tx['total_harga'] as num?)?.toDouble() ??
                                      0.0);
                          final updateData = {
                            'invoice_no': invoiceCtrl.text.trim(),
                            'nama_produk': produkCtrl.text.trim(),
                            'total_harga': harga,
                            'status': selectedStatus,
                            'payment_method': methodCtrl.text.trim(),
                            'tanggal': tanggalCtrl.text.trim(),
                          };

                          await DatabaseHelper.instance
                              .updateTransaction(id, updateData);
                          if (context.mounted) Navigator.pop(context);
                          _showSnackBar(LanguageService.text(
                            'Transaksi berhasil diperbarui!',
                            'Transaction updated successfully!',
                          ));
                          _loadUserOrdersAndServices();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C4DFF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          LanguageService.text(
                              'Simpan Perubahan', 'Save Changes'),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 2. Dialog Hapus Transaksi
  void _showDeleteTransactionDialog(Map<String, dynamic> tx) {
    final int id = (tx['id'] as num?)?.toInt() ?? 0;
    final String invoice = tx['invoice_no']?.toString() ?? 'INV-$id';
    final String namaProduk = tx['nama_produk']?.toString() ?? 'Produk';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFF3D00), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  LanguageService.text('Hapus Transaksi?', 'Delete Order?'),
                  style: GoogleFonts.poppins(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            LanguageService.text(
              'Apakah Anda yakin ingin menghapus data transaksi $invoice ($namaProduk) secara permanen dari database lokal dan Firebase cloud? Tindakan ini tidak dapat dibatalkan.',
              'Are you sure you want to permanently delete transaction $invoice ($namaProduk) from local database and Firebase cloud? This action cannot be undone.',
            ),
            style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                LanguageService.text('Batal', 'Cancel'),
                style: GoogleFonts.poppins(color: _textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                HapticFeedback.heavyImpact();

                // 1. Langsung tutup dialog secara instan
                Navigator.of(dialogContext, rootNavigator: true).pop();

                // 2. Langsung hapus dari state UI (optimistic UI update)
                setState(() {
                  _transactions.removeWhere((t) {
                    final tInv = (t['invoice_no'] ?? t['id_ref'] ?? '')
                        .toString()
                        .trim();
                    final tId = (t['id'] as num?)?.toInt();
                    if (invoice.isNotEmpty &&
                        (tInv == invoice ||
                            tInv == invoice.replaceAll('INV-', ''))) {
                      return true;
                    }
                    if (id > 0 && tId == id) return true;
                    return false;
                  });
                });

                _showSnackBar(
                  LanguageService.text(
                    'Transaksi $invoice berhasil dihapus permanen!',
                    'Transaction $invoice permanently deleted!',
                  ),
                  isError: true,
                );

                // 3. Eksekusi penghapusan SQLite & Firebase dengan aman
                try {
                  if (id > 0) {
                    await DatabaseHelper.instance
                        .deleteTransaction(id, invoiceNo: invoice);
                  } else if (invoice.isNotEmpty) {
                    await DatabaseHelper.instance
                        .deleteTransactionByInvoice(invoice);
                  }

                  if (invoice.isNotEmpty) {
                    await FirebaseTransactionService.instance
                        .deleteTransactionFromFirebase(
                      invoiceNo: invoice,
                      localId: id > 0 ? id : null,
                    );
                  }
                } catch (e) {
                  debugPrint('Error deleting transaction: $e');
                }

                _loadUserOrdersAndServices();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3D00),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                LanguageService.text('Hapus', 'Delete'),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 3. Modal Edit Layanan Aktif
  void _showEditServiceModal(Map<String, dynamic> srv) {
    final int id = srv['id'] as int;
    final TextEditingController namaCtrl =
        TextEditingController(text: srv['nama_produk']?.toString() ?? '');
    final TextEditingController kategoriCtrl =
        TextEditingController(text: srv['kategori']?.toString() ?? 'VPS');
    final TextEditingController specsCtrl =
        TextEditingController(text: srv['spesifikasi']?.toString() ?? '');
    final TextEditingController ipCtrl =
        TextEditingController(text: srv['ip_address']?.toString() ?? '');
    final TextEditingController portCtrl =
        TextEditingController(text: srv['port']?.toString() ?? '');
    final TextEditingController expCtrl = TextEditingController(
        text: srv['tanggal_kadaluarsa']?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          LanguageService.text(
                              'Ubah Data Layanan', 'Edit Service Data'),
                          style: GoogleFonts.poppins(
                            color: _textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon:
                              Icon(Icons.close_rounded, color: _textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _buildSheetInputField(
                      controller: namaCtrl,
                      label:
                          LanguageService.text('Nama Layanan', 'Service Name'),
                      hint: 'VPS Cloud / Panel Hosting / Bot WA',
                      icon: Icons.dns_rounded,
                    ),
                    const SizedBox(height: 12),

                    _buildSheetInputField(
                      controller: kategoriCtrl,
                      label: LanguageService.text('Kategori', 'Category'),
                      hint: 'VPS / Panel / Bot WA',
                      icon: Icons.category_rounded,
                    ),
                    const SizedBox(height: 12),

                    _buildSheetInputField(
                      controller: specsCtrl,
                      label: LanguageService.text(
                          'Spesifikasi Layanan', 'Service Specs'),
                      hint: '2 Core CPU, 4GB RAM, 50GB NVMe',
                      icon: Icons.memory_rounded,
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildSheetInputField(
                            controller: ipCtrl,
                            label:
                                LanguageService.text('Alamat IP', 'IP Address'),
                            hint: '192.168.1.1',
                            icon: Icons.wifi_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSheetInputField(
                            controller: portCtrl,
                            label: LanguageService.text('Port', 'Port'),
                            hint: '22 / 8080',
                            icon: Icons.settings_ethernet_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildSheetInputField(
                      controller: expCtrl,
                      label: LanguageService.text(
                          'Tanggal Kedaluwarsa', 'Expiration Date'),
                      hint: 'YYYY-MM-DD',
                      icon: Icons.calendar_month_rounded,
                    ),
                    const SizedBox(height: 20),

                    // Tombol Simpan
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final updateData = {
                            'nama_produk': namaCtrl.text.trim(),
                            'kategori': kategoriCtrl.text.trim(),
                            'spesifikasi': specsCtrl.text.trim(),
                            'ip_address': ipCtrl.text.trim(),
                            'port': portCtrl.text.trim(),
                            'tanggal_kadaluarsa': expCtrl.text.trim(),
                          };

                          await DatabaseHelper.instance
                              .updateService(id, updateData);
                          if (context.mounted) Navigator.pop(context);
                          _showSnackBar(LanguageService.text(
                            'Data layanan berhasil diperbarui!',
                            'Service updated successfully!',
                          ));
                          _loadUserOrdersAndServices();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          LanguageService.text(
                              'Simpan Perubahan', 'Save Changes'),
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 4. Dialog Hapus Layanan Aktif
  void _showDeleteServiceDialog(Map<String, dynamic> srv) {
    final int id = srv['id'] as int;
    final String nama = srv['nama_produk']?.toString() ?? 'Layanan';
    final String ip = srv['ip_address']?.toString() ?? '-';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFF3D00), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  LanguageService.text('Hapus Layanan?', 'Delete Service?'),
                  style: GoogleFonts.poppins(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            LanguageService.text(
              'Apakah Anda yakin ingin menghapus data layanan $nama ($ip)? Tindakan ini tidak dapat dibatalkan.',
              'Are you sure you want to delete service $nama ($ip)? This action cannot be undone.',
            ),
            style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                LanguageService.text('Batal', 'Cancel'),
                style: GoogleFonts.poppins(color: _textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await DatabaseHelper.instance.deleteService(id);
                if (context.mounted) Navigator.pop(context);
                _showSnackBar(
                  LanguageService.text(
                    'Layanan $nama berhasil dihapus!',
                    'Service $nama deleted successfully!',
                  ),
                  isError: true,
                );
                _loadUserOrdersAndServices();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3D00),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                LanguageService.text('Hapus', 'Delete'),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSheetInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: _textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: widget.isDarkMode
                ? Colors.black.withValues(alpha: 0.35)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                color: _textSecondary.withValues(alpha: 0.6),
                fontSize: 12,
              ),
              prefixIcon: Icon(icon, color: _textSecondary, size: 17),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
