import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetech_xyz/constants/constants.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/pages/home/produk_page.dart';
import 'package:vibetech_xyz/pages/payment/pembayaran_page.dart';
import 'package:vibetech_xyz/services/cloud_sync_service.dart';
import 'package:vibetech_xyz/services/firebase_transaction_service.dart';
import 'package:vibetech_xyz/services/language_service.dart';

/// ============================================================================
/// HALAMAN BILLING & INVOICE TAGIHAN (BILLING PAGE)
/// ============================================================================
/// Halaman ini menampilkan:
/// 1. Statistik total invoice, tagihan lunas, tagihan pending, dan total pengeluaran.
/// 2. Daftar invoice tagihan dengan filter status (Semua, Lunas, Belum Lunas).
/// 3. Rincian faktur digital (Receipt Modal) dengan tombol salin invoice dan bayar.
/// 4. Tab Layanan Aktif yang tertaut dengan masa aktif VPS, Panel Hosting, dan Bot WA.
class BillingPage extends StatefulWidget {
  final String? invoiceNumber;
  final DateTime? transactionDate;
  final String? paymentMethod;
  final int? totalAmount;
  final List<Map<String, dynamic>>? items;
  final String? status;
  final bool isDarkMode;
  final String? username;
  final String? userEmail;

  const BillingPage({
    super.key,
    this.invoiceNumber,
    this.transactionDate,
    this.paymentMethod,
    this.totalAmount,
    this.items,
    this.status,
    this.isDarkMode = true,
    this.username,
    this.userEmail,
  });

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage>
    with TickerProviderStateMixin {
  // Tab controller untuk beralih antara 'Semua Invoice', 'Tagihan Tertunda', dan 'Layanan Aktif'
  late TabController _tabController;
  late bool _isDarkMode;
  bool _isSyncingCloud = false;

  // Data identitas akun aktif yang sedang login
  String _activeUsername = '';
  String _activeEmail = '';
  String _currentUserRole = 'user';

  // Daftar data invoice dan layanan dari SQLite Database
  List<Map<String, dynamic>> _allInvoices = [];
  List<Map<String, dynamic>> _filteredInvoices = [];
  List<Map<String, dynamic>> _pendingInvoices = [];
  List<Map<String, dynamic>> _activeServices = [];

  // Statistik ringkasan tagihan pengguna
  Map<String, dynamic> _stats = {
    'totalInvoices': 0,
    'lunasCount': 0,
    'pendingCount': 0,
    'totalSpent': 0.0,
  };

  // Search & Filter State
  String _searchQuery = '';
  String _selectedStatusFilter = 'Semua';
  final TextEditingController _searchController = TextEditingController();

  // Animations & Cyber Particles
  late AnimationController _particleController;
  late AnimationController _pulseController;
  late AnimationController _listAnimController;
  final List<AppParticle> _particles = [];
  final math.Random _random = math.Random();

  bool get _isAdmin =>
      _currentUserRole == 'admin' ||
      _currentUserRole == 'administrator' ||
      _activeUsername.toLowerCase() == 'admin';

  Color get _bgColor => _isDarkMode ? AppColors.darkBg : AppColors.lightBg;
  Color get _cardColor =>
      _isDarkMode ? AppColors.darkCard : AppColors.lightCard;
  Color get _textPrimary =>
      _isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get _textSecondary =>
      _isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get _cardBorder => _isDarkMode
      ? AppColors.primary.withValues(alpha: 0.18)
      : const Color(0xFFE2E8F0);

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  Timer? _liveSyncTimer;
  VoidCallback? _billingRealtimeListener;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;

    // Inisialisasi 24 Partikel Cyber untuk Mode Gelap
    _particles.addAll(AppParticle.generateList(_random, count: 24));

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _particleController.addListener(() {
      AppParticle.updatePositions(_particles);
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _listAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Initial Tab: 0 = Semua, 1 = Menunggu Bayar, 2 = Layanan Aktif
    int initialTabIndex = 0;
    if (widget.status != null) {
      if (widget.status!.toLowerCase().contains('menunggu') ||
          widget.status!.toLowerCase().contains('pending')) {
        initialTabIndex = 1;
      } else if (widget.status!.toLowerCase().contains('lunas') ||
          widget.status!.toLowerCase().contains('selesai')) {
        initialTabIndex = 0;
      }
    }

    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialTabIndex,
    );

    // Hubungkan listener streaming real-time Firebase RTDB untuk transaksi & layanan
    _billingRealtimeListener = () async {
      if (mounted) {
        await _loadBillingDataFromDB(triggerCloudSync: false);
      }
    };
    CloudSyncService.instance.transactionsNotifier
        .addListener(_billingRealtimeListener!);
    CloudSyncService.instance.servicesNotifier
        .addListener(_billingRealtimeListener!);

    _initUserDataAndLoad();
  }

  @override
  void dispose() {
    if (_billingRealtimeListener != null) {
      CloudSyncService.instance.transactionsNotifier
          .removeListener(_billingRealtimeListener!);
      CloudSyncService.instance.servicesNotifier
          .removeListener(_billingRealtimeListener!);
    }
    _liveSyncTimer?.cancel();
    _tabController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    _listAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initUserDataAndLoad() async {
    try {
      await initializeDateFormatting('id_ID', null);
      final prefs = await SharedPreferences.getInstance();

      _activeUsername =
          widget.username ?? prefs.getString('username') ?? 'demouser';
      _activeEmail =
          widget.userEmail ?? prefs.getString('email') ?? 'user@vibetech.com';
      String role = prefs.getString('role') ?? 'user';

      final userDb = await DatabaseHelper.instance
          .getUserByUsernameOrEmail(_activeUsername);
      if (userDb != null) {
        if (userDb['role'] != null) {
          role = userDb['role'].toString().toLowerCase();
        }
        if (userDb['email'] != null && userDb['email'].toString().isNotEmpty) {
          _activeEmail = userDb['email'];
        }
      }
      _currentUserRole = role.toLowerCase();

      await _loadBillingDataFromDB();

      // Pasang fallback periodic sync (sebagai cadangan terhadap streaming listener)
      _liveSyncTimer?.cancel();
      _liveSyncTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (mounted && !_isSyncingCloud) {
          _syncWithFirebaseCloudInBackground();
        }
      });
    } catch (e) {
      debugPrint('Error initializing billing page: $e');
    } finally {
      if (mounted) {
        _listAnimController.forward(from: 0.0);
      }
    }
  }

  Future<void> _loadBillingDataFromDB({bool triggerCloudSync = true}) async {
    try {
      await DatabaseHelper.instance.cleanupDuplicateTransactions();
      // 1. Ambil data transaksi/invoice dari SQLite lokal
      List<Map<String, dynamic>> rawTransactions;
      if (_isAdmin) {
        rawTransactions = await DatabaseHelper.instance.getAllTransactions();
      } else {
        rawTransactions =
            await DatabaseHelper.instance.getTransactionsByUser(_activeEmail);
      }

      // 2. Ambil data layanan aktif dari SQLite lokal
      List<Map<String, dynamic>> rawServices;
      if (_isAdmin) {
        rawServices = await DatabaseHelper.instance.getAllServices();
      } else {
        rawServices =
            await DatabaseHelper.instance.getServicesByUser(_activeEmail);
      }

      _allInvoices = List.from(rawTransactions);
      _activeServices = List.from(rawServices);

      _calculateStats();
      _applyFilters();

      // 3. Sinkronisasi dua arah otomatis dengan Firebase Cloud di latar belakang (Non-blocking) jika diizinkan
      if (triggerCloudSync && !_isSyncingCloud) {
        _syncWithFirebaseCloudInBackground();
      }
    } catch (e) {
      debugPrint('Error loading billing data: $e');
    }
  }

  void _calculateStats() {
    int totalCount = _allInvoices.length;
    int lunasCount = 0;
    int pendingCount = 0;
    double totalSpent = 0.0;

    for (var inv in _allInvoices) {
      final st = (inv['status'] ?? '').toString().toLowerCase();
      final double amount = (inv['total_harga'] as num?)?.toDouble() ?? 0.0;

      if (st.contains('selesai') ||
          st.contains('lunas') ||
          st.contains('success') ||
          st.contains('settlement')) {
        lunasCount++;
        totalSpent += amount;
      } else if (st.contains('pending') ||
          st.contains('menunggu') ||
          st.contains('unpaid')) {
        pendingCount++;
      }
    }

    _stats = {
      'totalInvoices': totalCount,
      'lunasCount': lunasCount,
      'pendingCount': pendingCount,
      'totalSpent': totalSpent,
    };
  }

  Future<void> _syncWithFirebaseCloudInBackground() async {
    if (_isSyncingCloud) return;
    _isSyncingCloud = true;
    try {
      if (_isAdmin) {
        await Future.wait([
          FirebaseTransactionService.instance.syncTransactionsFromFirebase(),
          FirebaseTransactionService.instance.syncServicesFromFirebase(),
        ]).timeout(const Duration(seconds: 5), onTimeout: () => []);
      } else {
        await Future.wait([
          FirebaseTransactionService.instance
              .syncTransactionsFromFirebase(userEmail: _activeEmail),
          FirebaseTransactionService.instance
              .syncServicesFromFirebase(userEmail: _activeEmail),
        ]).timeout(const Duration(seconds: 5), onTimeout: () => []);
      }

      if (mounted) {
        final rawTransactions = _isAdmin
            ? await DatabaseHelper.instance.getAllTransactions()
            : await DatabaseHelper.instance.getTransactionsByUser(_activeEmail);
        final rawServices = _isAdmin
            ? await DatabaseHelper.instance.getAllServices()
            : await DatabaseHelper.instance.getServicesByUser(_activeEmail);

        if (mounted) {
          setState(() {
            _allInvoices = List.from(rawTransactions);
            _activeServices = List.from(rawServices);
            _calculateStats();
            _applyFilters();
          });
        }
      }
    } catch (e) {
      debugPrint('[BillingPage] Firebase auto-sync info: $e');
    } finally {
      _isSyncingCloud = false;
    }
  }

  /// Sinkronisasi manual satu pintu ke Firebase RTDB & Firestore
  Future<void> _manualSyncCloud() async {
    if (_isSyncingCloud) return;
    setState(() => _isSyncingCloud = true);
    HapticFeedback.mediumImpact();

    try {
      await CloudSyncService.instance.syncAllFromCloud();
      await _loadBillingDataFromDB();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_done_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    LanguageService.text(
                      'Pusat Tagihan berhasil disinkronkan dengan Firebase RTDB & SQLite!',
                      'Billing Center synced with Firebase RTDB & SQLite!',
                    ),
                    style: GoogleFonts.poppins(fontSize: 12.5),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Manual cloud sync error: $e');
    } finally {
      if (mounted) setState(() => _isSyncingCloud = false);
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> list = List.from(_allInvoices);

    // Filter status
    if (_selectedStatusFilter != 'Semua') {
      list = list.where((item) {
        final st = (item['status'] ?? '').toString().toLowerCase();
        if (_selectedStatusFilter == 'Lunas') {
          return st.contains('selesai') ||
              st.contains('lunas') ||
              st.contains('success') ||
              st.contains('settlement');
        } else if (_selectedStatusFilter == 'Pending') {
          return st.contains('pending') ||
              st.contains('menunggu') ||
              st.contains('unpaid');
        } else if (_selectedStatusFilter == 'Diproses') {
          return st.contains('proses') || st.contains('active');
        } else if (_selectedStatusFilter == 'Dibatalkan') {
          return st.contains('batal') ||
              st.contains('cancel') ||
              st.contains('expire');
        }
        return true;
      }).toList();
    }

    // Filter pencarian
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((item) {
        final invoiceNo = (item['invoice_no'] ?? '').toString().toLowerCase();
        final prodName = (item['nama_produk'] ?? '').toString().toLowerCase();
        final paymentMethod =
            (item['payment_method'] ?? '').toString().toLowerCase();
        final email = (item['user_email'] ?? '').toString().toLowerCase();
        return invoiceNo.contains(q) ||
            prodName.contains(q) ||
            paymentMethod.contains(q) ||
            email.contains(q);
      }).toList();
    }

    _filteredInvoices = list;

    // Filter khusus tab Menunggu Bayar
    _pendingInvoices = _allInvoices.where((item) {
      final st = (item['status'] ?? '').toString().toLowerCase();
      return st.contains('pending') ||
          st.contains('menunggu') ||
          st.contains('unpaid');
    }).toList();

    if (mounted) setState(() {});
  }

  // ================= NAVIGASI LANGSUNG KE METODE PEMBAYARAN =================

  void _navigateToPayment(Map<String, dynamic> item) {
    HapticFeedback.mediumImpact();
    final String prodName = item['nama_produk'] ?? 'Layanan VibeTech';
    // FIX CONVERSION: num -> int
    final int qty = (item['jumlah'] as num?)?.toInt() ?? 1;
    final double totalPrice = (item['total_harga'] as num?)?.toDouble() ?? 0.0;
    final double unitPrice = qty > 0 ? (totalPrice / qty) : totalPrice;
    final String email = item['user_email'] ?? _activeEmail;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PembayaranPage(
          totalAmount: totalPrice.toInt(),
          items: [
            {
              'name': prodName,
              'price': unitPrice,
              'quantity': qty,
            }
          ],
          isDarkMode: _isDarkMode,
          userEmail: email,
        ),
      ),
    ).then((_) => _loadBillingDataFromDB());
  }

  // ================= MODAL DETAIL INVOICE / RECEIPT =================

  void _showInvoiceReceiptModal(Map<String, dynamic> item) {
    // FIX CONVERSION: num -> int
    final int id = (item['id'] as num?)?.toInt() ?? 0;
    final String invoiceNo =
        item['invoice_no'] ?? 'INV-${id.toString().padLeft(5, '0')}';
    final String prodName = item['nama_produk'] ?? 'Layanan VibeTech';
    // FIX CONVERSION: num -> int
    final int qty = (item['jumlah'] as num?)?.toInt() ?? 1;
    final double totalPrice = (item['total_harga'] as num?)?.toDouble() ?? 0.0;
    final String status = item['status']?.toString() ?? 'Lunas';
    final String paymentMethod = item['payment_method'] ?? 'Saldo VibeWallet';
    final String dateStr = item['tanggal'] ?? '';
    final String notes = item['notes'] ?? '';
    final String email = item['user_email'] ?? _activeEmail;

    DateTime dateParsed = DateTime.tryParse(dateStr) ?? DateTime.now();
    final formattedDate =
        DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(dateParsed);

    final bool isLunas = status.toLowerCase().contains('selesai') ||
        status.toLowerCase().contains('lunas') ||
        status.toLowerCase().contains('success');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: _isDarkMode
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle Bar
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: _textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Header Invoice & Status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: isLunas
                          ? AppColors.emeraldGradient
                          : AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isLunas ? AppColors.success : AppColors.primary)
                                  .withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      isLunas
                          ? Icons.receipt_long_rounded
                          : Icons.hourglass_top_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoiceNo,
                          style: GoogleFonts.poppins(
                            color: _textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          formattedDate,
                          style: GoogleFonts.poppins(
                            color: _textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 20),

              // Garis Pembatas Putus-putus
              const AppDashedDivider(),
              const SizedBox(height: 16),

              // Info Ringkasan
              _buildDetailRow(
                  LanguageService.text('Pelanggan', 'Customer'), email),
              _buildDetailRow(
                  LanguageService.text('Metode', 'Method'), paymentMethod),
              _buildDetailRow(
                  LanguageService.text('Item Layanan', 'Service Item'),
                  '$prodName (x$qty)'),
              if (notes.isNotEmpty)
                _buildDetailRow(
                    LanguageService.text('Rincian', 'Details'), notes),

              const SizedBox(height: 12),
              const AppDashedDivider(),
              const SizedBox(height: 16),

              // Total Harga
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    LanguageService.text('Total Tagihan', 'Total Invoice'),
                    style: GoogleFonts.poppins(
                      color: _textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _currencyFormatter.format(totalPrice),
                    style: GoogleFonts.poppins(
                      color: isLunas ? AppColors.cyan : AppColors.accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: invoiceNo));
                        HapticFeedback.selectionClick();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Nomor invoice $invoiceNo berhasil disalin ke clipboard.',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: Text(
                        LanguageService.text('Salin Invoice', 'Copy Invoice'),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!isLunas)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(modalCtx);
                          _navigateToPayment(item);
                        },
                        icon: const Icon(Icons.payment_rounded,
                            color: Colors.white, size: 16),
                        label: Text(
                          LanguageService.text('Bayar Sekarang', 'Pay Now'),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          LanguageService.text('Tutup', 'Close'),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // Tombol Edit & Hapus Tagihan khusus Administrator
              if (_isAdmin) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(modalCtx);
                          _showEditInvoiceDialog(item);
                        },
                        icon: const Icon(Icons.edit_note_rounded,
                            color: AppColors.primary, size: 18),
                        label: Text(
                          LanguageService.text('Edit Tagihan', 'Edit Invoice'),
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(modalCtx);
                          _showDeleteInvoiceConfirmation(item);
                        },
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.error, size: 18),
                        label: Text(
                          LanguageService.text('Hapus Tagihan', 'Delete Invoice'),
                          style: GoogleFonts.poppins(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: AppColors.error.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteInvoiceConfirmation(Map<String, dynamic> item) {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.text(
            'Akses Ditolak! Hanya Administrator yang dapat menghapus tagihan.',
            'Access Denied! Only Administrators can delete invoices.',
          )),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final int id = (item['id'] as num?)?.toInt() ?? 0;
    final String invoiceNo = (item['invoice_no'] ?? '').toString();
    final String prodName = item['nama_produk']?.toString() ?? 'Layanan';
    final String email = item['user_email']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                LanguageService.text('Hapus Tagihan?', 'Delete Invoice?'),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          LanguageService.text(
            'Apakah Anda yakin ingin menghapus tagihan ${invoiceNo.isNotEmpty ? invoiceNo : "#$id"} ($prodName)? Tagihan akan dihapus permanen dari SQLite & Firebase Cloud RTDB.',
            'Are you sure you want to delete invoice ${invoiceNo.isNotEmpty ? invoiceNo : "#$id"} ($prodName)? It will be permanently removed from SQLite and Firebase RTDB.',
          ),
          style: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              LanguageService.text('Batal', 'Cancel'),
              style: GoogleFonts.poppins(color: _textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              HapticFeedback.heavyImpact();
              Navigator.of(dialogCtx, rootNavigator: true).pop();

              // Optimistic UI update
              setState(() {
                _allInvoices.removeWhere((t) {
                  final tInv = (t['invoice_no'] ?? '').toString().trim();
                  final tId = (t['id'] as num?)?.toInt();
                  if (invoiceNo.isNotEmpty &&
                      (tInv == invoiceNo ||
                          tInv == invoiceNo.replaceAll('INV-', ''))) {
                    return true;
                  }
                  if (id > 0 && tId == id) return true;
                  return false;
                });
                _calculateStats();
                _applyFilters();
              });

              // SQLite & Firebase delete
              try {
                if (id > 0) {
                  await DatabaseHelper.instance
                      .deleteTransaction(id, invoiceNo: invoiceNo);
                } else if (invoiceNo.isNotEmpty) {
                  await DatabaseHelper.instance
                      .deleteTransactionByInvoice(invoiceNo);
                } else {
                  await FirebaseTransactionService.instance
                      .deleteTransactionFromFirebase(
                    invoiceNo: invoiceNo,
                    localId: id > 0 ? id : null,
                    namaProduk: prodName,
                    userEmail: email,
                  );
                }
              } catch (e) {
                debugPrint('[BillingPage] Delete invoice error: $e');
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      LanguageService.text(
                        'Tagihan ${invoiceNo.isNotEmpty ? invoiceNo : "#$id"} berhasil dihapus permanen.',
                        'Invoice ${invoiceNo.isNotEmpty ? invoiceNo : "#$id"} deleted permanently.',
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              LanguageService.text('Hapus Permanen', 'Delete Permanently'),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditInvoiceDialog(Map<String, dynamic> item) {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.text(
            'Akses Ditolak! Hanya Administrator yang dapat mengubah invoice tagihan.',
            'Access Denied! Only Administrators can edit billing invoices.',
          )),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final int id = (item['id'] as num?)?.toInt() ?? 0;
    final String oldInvoice = (item['invoice_no'] ?? '').toString();
    final nameCtrl =
        TextEditingController(text: item['nama_produk']?.toString() ?? '');
    final priceCtrl = TextEditingController(
        text: ((item['total_harga'] as num?)?.toDouble() ?? 0.0)
            .toStringAsFixed(0));
    final qtyCtrl = TextEditingController(
        text: ((item['jumlah'] as num?)?.toInt() ?? 1).toString());
    final invoiceCtrl = TextEditingController(text: oldInvoice);
    final emailCtrl = TextEditingController(
        text: item['user_email']?.toString() ?? _activeEmail);
    final notesCtrl =
        TextEditingController(text: item['notes']?.toString() ?? '');
    String status = item['status']?.toString() ?? 'Selesai';
    String paymentMethod =
        item['payment_method']?.toString() ?? 'Saldo VibeWallet';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (sbContext, setDialogState) {
          return AlertDialog(
            backgroundColor: _cardColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.cyan]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_note_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    LanguageService.text(
                        'Edit Invoice Tagihan', 'Edit Billing Invoice'),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: invoiceCtrl,
                        style: GoogleFonts.poppins(
                            color: _textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: LanguageService.text(
                              'Nomor Invoice', 'Invoice No'),
                          prefixIcon:
                              const Icon(Icons.receipt_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameCtrl,
                        style: GoogleFonts.poppins(
                            color: _textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: LanguageService.text(
                              'Nama Layanan / Produk',
                              'Service / Product Name'),
                          prefixIcon:
                              const Icon(Icons.inventory_2_rounded, size: 18),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: priceCtrl,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.poppins(
                                  color: _textPrimary, fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: 'Total Harga (Rp)',
                                prefixIcon: Icon(Icons.monetization_on_rounded,
                                    size: 18),
                              ),
                              validator: (v) => (v == null ||
                                      double.tryParse(v.trim()) == null)
                                  ? 'Nominal tidak valid'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: qtyCtrl,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.poppins(
                                  color: _textPrimary, fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: 'Jumlah (Qty)',
                                prefixIcon: Icon(
                                    Icons.format_list_numbered_rounded,
                                    size: 18),
                              ),
                              validator: (v) =>
                                  (v == null || int.tryParse(v.trim()) == null)
                                      ? 'Qty tidak valid'
                                      : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: ['Selesai', 'Pending', 'Dibatalkan']
                                .contains(status)
                            ? status
                            : 'Selesai',
                        decoration: InputDecoration(
                          labelText: LanguageService.text(
                              'Status Pembayaran', 'Payment Status'),
                          prefixIcon:
                              const Icon(Icons.verified_rounded, size: 18),
                        ),
                        dropdownColor: _cardColor,
                        style: GoogleFonts.poppins(
                            color: _textPrimary, fontSize: 13),
                        items: ['Selesai', 'Pending', 'Dibatalkan']
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => status = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        style: GoogleFonts.poppins(
                            color: _textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: LanguageService.text(
                              'Email Pelanggan', 'Customer Email'),
                          prefixIcon: const Icon(Icons.email_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesCtrl,
                        style: GoogleFonts.poppins(
                            color: _textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: LanguageService.text(
                              'Catatan / Keterangan', 'Notes'),
                          prefixIcon: const Icon(Icons.note_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(
                  LanguageService.text('Batal', 'Cancel'),
                  style: GoogleFonts.poppins(color: _textSecondary),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  if (formKey.currentState?.validate() ?? false) {
                    final newInvoice = invoiceCtrl.text.trim();
                    final updatedData = {
                      'invoice_no':
                          newInvoice.isNotEmpty ? newInvoice : oldInvoice,
                      'nama_produk': nameCtrl.text.trim(),
                      'jumlah': int.tryParse(qtyCtrl.text.trim()) ?? 1,
                      'total_harga':
                          double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                      'status': status,
                      'payment_method': paymentMethod,
                      'user_email': emailCtrl.text.trim(),
                      'notes': notesCtrl.text.trim(),
                      'tanggal':
                          item['tanggal'] ?? DateTime.now().toIso8601String(),
                    };

                    Navigator.of(dialogCtx, rootNavigator: true).pop();

                    // Optimistic update
                    setState(() {
                      final idx = _allInvoices.indexWhere((t) =>
                          (id > 0 && (t['id'] as num?)?.toInt() == id) ||
                          (oldInvoice.isNotEmpty &&
                              t['invoice_no'] == oldInvoice));
                      if (idx != -1) {
                        _allInvoices[idx] = {
                          ..._allInvoices[idx],
                          ...updatedData,
                        };
                      }
                      _calculateStats();
                      _applyFilters();
                    });

                    // Save SQLite & Firebase
                    try {
                      if (id > 0) {
                        await DatabaseHelper.instance
                            .updateTransaction(id, updatedData);
                      } else {
                        await FirebaseTransactionService.instance
                            .updateTransactionInFirebase(
                          invoiceNo:
                              oldInvoice.isNotEmpty ? oldInvoice : newInvoice,
                          localId: id > 0 ? id : null,
                          namaProduk: nameCtrl.text.trim(),
                          userEmail: emailCtrl.text.trim(),
                          updatedData: updatedData,
                        );
                      }
                    } catch (e) {
                      debugPrint('[BillingPage] Update invoice error: $e');
                    }

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          LanguageService.text(
                            'Tagihan $newInvoice berhasil diperbarui ke SQLite & Firebase RTDB!',
                            'Invoice $newInvoice updated in SQLite & Firebase RTDB!',
                          ),
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 18),
                label: Text(
                  LanguageService.text('Simpan Perubahan', 'Save Changes'),
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: _textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(
                color: _textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ================= MAIN UI BUILDER =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
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

          // 2. Ambient Neon Glow Orbs in Dark Mode
          if (_isDarkMode) AppNeonOrbs(pulseAnimation: _pulseController),

          // 3. Floating Cyber Particle Canvas
          if (_isDarkMode)
            IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _particleController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: MediaQuery.of(context).size,
                      painter: AppParticlePainter(_particles),
                    );
                  },
                ),
              ),
            ),

          // 4. Foreground Content
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                _buildStatMetricCards(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildAllInvoicesTab(),
                            _buildPendingPaymentsTab(),
                            _buildActiveServicesTab(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= APP BAR =================

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cardBorder),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: _textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LanguageService.text(
                      'Pusat Tagihan & Billing', 'Billing Center & Invoices'),
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  _isAdmin
                      ? LanguageService.text(
                          'Akses Admin: Seluruh Transaksi & Layanan',
                          'Admin Access: All Invoices & Services')
                      : '$_activeUsername ($_activeEmail)',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: _textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _manualSyncCloud,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _isSyncingCloud
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.cyan,
                          ),
                        )
                      : const Icon(Icons.cloud_sync_rounded,
                          color: AppColors.cyan, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'RTDB',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cyan,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _isDarkMode = !_isDarkMode);
            },
            icon: Icon(
              _isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.nightlight_round_rounded,
              color: _isDarkMode ? Colors.amber : AppColors.primary,
            ),
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadBillingDataFromDB();
            },
            icon: const Icon(Icons.refresh_rounded, color: AppColors.cyan),
          ),
        ],
      ),
    );
  }

  // ================= STAT METRIC CARDS =================

  Widget _buildStatMetricCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _buildStatCard(
            title: LanguageService.text('Total Invoice', 'Total Invoices'),
            value: _stats['totalInvoices'].toString(),
            icon: Icons.receipt_long_rounded,
            gradientColors: [const Color(0xFF7C4DFF), const Color(0xFF9E7BFF)],
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            title: LanguageService.text('Lunas', 'Paid'),
            value: _stats['lunasCount'].toString(),
            icon: Icons.check_circle_rounded,
            gradientColors: [const Color(0xFF10B981), const Color(0xFF34D399)],
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            title: LanguageService.text('Menunggu', 'Pending'),
            value: _stats['pendingCount'].toString(),
            icon: Icons.pending_actions_rounded,
            gradientColors: [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            title: LanguageService.text('Total Bayar', 'Total Paid'),
            value: _currencyFormatter
                .format(_stats['totalSpent'])
                .replaceAll(',00', ''),
            icon: Icons.account_balance_wallet_rounded,
            gradientColors: [const Color(0xFF00E5FF), const Color(0xFF00B0FF)],
            isCompactCurrency: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradientColors,
    bool isCompactCurrency = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 14),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: _textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: isCompactCurrency ? 11.5 : 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: _textSecondary,
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ================= TAB BAR =================

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: _textSecondary,
        labelStyle:
            GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        tabs: [
          Tab(
            text: LanguageService.text('Semua Invoice', 'All Invoices'),
          ),
          Tab(
            text: LanguageService.text(
                'Menunggu (${_pendingInvoices.length})', 'Pending'),
          ),
          Tab(
            text: LanguageService.text('Layanan Aktif', 'Subscriptions'),
          ),
        ],
      ),
    );
  }

  // ================= TAB 1: ALL INVOICES =================

  Widget _buildAllInvoicesTab() {
    return RefreshIndicator(
      onRefresh: _loadBillingDataFromDB,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            _buildSearchAndFilterBar(),
            const SizedBox(height: 12),
            if (_filteredInvoices.isEmpty)
              _buildEmptyState(
                title: LanguageService.text(
                    'Belum Ada Tagihan', 'No Invoices Found'),
                subtitle: LanguageService.text(
                  'Tagihan dan bukti pembayaran Anda akan tercatat secara otomatis di sini.',
                  'Your invoices and receipts will automatically appear here.',
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredInvoices.length,
                itemBuilder: (context, index) {
                  final item = _filteredInvoices[index];
                  return _buildInvoiceCard(item);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ================= TAB 2: PENDING PAYMENTS =================

  Widget _buildPendingPaymentsTab() {
    return RefreshIndicator(
      onRefresh: _loadBillingDataFromDB,
      color: AppColors.primary,
      child: _pendingInvoices.isEmpty
          ? Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: _buildEmptyState(
                  icon: Icons.task_alt_rounded,
                  title: LanguageService.text(
                      'Semua Tagihan Lunas!', 'All Invoices Paid!'),
                  subtitle: LanguageService.text(
                    'Tidak ada tagihan yang menunggu pembayaran saat ini.',
                    'You have no pending payments right now.',
                  ),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _pendingInvoices.length,
              itemBuilder: (context, index) {
                final item = _pendingInvoices[index];
                return _buildInvoiceCard(item, isPendingTab: true);
              },
            ),
    );
  }

  // ================= TAB 3: ACTIVE SUBSCRIPTIONS =================

  Widget _buildActiveServicesTab() {
    return RefreshIndicator(
      onRefresh: _loadBillingDataFromDB,
      color: AppColors.primary,
      child: _activeServices.isEmpty
          ? Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: _buildEmptyState(
                  icon: Icons.cloud_done_rounded,
                  title: LanguageService.text(
                      'Belum Ada Layanan Aktif', 'No Active Services'),
                  subtitle: LanguageService.text(
                    'Layanan server, panel hosting, atau bot WhatsApp yang Anda beli akan aktif dan tercatat di sini.',
                    'Your active servers, panels, and WhatsApp bots will show here.',
                  ),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _activeServices.length,
              itemBuilder: (context, index) {
                final srv = _activeServices[index];
                return _buildActiveServiceCard(srv);
              },
            ),
    );
  }

  // ================= CARD BUILDERS =================

  Widget _buildInvoiceCard(Map<String, dynamic> item,
      {bool isPendingTab = false}) {
    // FIX CONVERSION: num -> int
    final int id = (item['id'] as num?)?.toInt() ?? 0;
    final String invoiceNo =
        item['invoice_no'] ?? 'INV-${id.toString().padLeft(5, '0')}';
    final String prodName = item['nama_produk'] ?? 'Layanan VibeTech';
    // FIX CONVERSION: num -> int
    final int qty = (item['jumlah'] as num?)?.toInt() ?? 1;
    final double totalPrice = (item['total_harga'] as num?)?.toDouble() ?? 0.0;
    final String status = item['status']?.toString() ?? 'Lunas';
    final String paymentMethod = item['payment_method'] ?? 'Saldo VibeWallet';
    final String dateStr = item['tanggal'] ?? '';

    DateTime parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    final formattedDate =
        DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(parsedDate);

    final bool isLunas = status.toLowerCase().contains('selesai') ||
        status.toLowerCase().contains('lunas') ||
        status.toLowerCase().contains('success');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPendingTab
              ? AppColors.warning.withValues(alpha: 0.35)
              : _cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.25 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _showInvoiceReceiptModal(item);
          },
          onLongPress: _isAdmin
              ? () {
                  HapticFeedback.heavyImpact();
                  _showDeleteInvoiceConfirmation(item);
                }
              : null,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header No Invoice & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: isLunas
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isLunas
                                  ? Icons.receipt_rounded
                                  : Icons.schedule_rounded,
                              color: isLunas
                                  ? AppColors.success
                                  : AppColors.primary,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              invoiceNo,
                              style: GoogleFonts.poppins(
                                color: _textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatusBadge(status, isCompact: true),
                        if (_isAdmin) ...[
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _showEditInvoiceDialog(item),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.edit_note_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _showDeleteInvoiceConfirmation(item),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Produk & Nominal
                Text(
                  prodName,
                  style: GoogleFonts.poppins(
                    color: _textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.payment_rounded,
                              size: 14, color: _textSecondary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              paymentMethod,
                              style: GoogleFonts.poppins(
                                color: _textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('•',
                              style: TextStyle(
                                  color: _textSecondary, fontSize: 12)),
                          const SizedBox(width: 8),
                          Text(
                            'Qty: $qty',
                            style: GoogleFonts.poppins(
                              color: _textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _currencyFormatter.format(totalPrice),
                      style: GoogleFonts.poppins(
                        color: isLunas ? AppColors.cyan : AppColors.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Footer Tanggal & Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        formattedDate,
                        style: GoogleFonts.poppins(
                          color: _textSecondary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!isLunas)
                      ElevatedButton.icon(
                        onPressed: () => _navigateToPayment(item),
                        icon: const Icon(Icons.payment_rounded,
                            color: Colors.white, size: 13),
                        label: Text(
                          LanguageService.text('Bayar Sekarang', 'Pay Now'),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Text(
                            LanguageService.text('Lihat Struk', 'View Receipt'),
                            style: GoogleFonts.poppins(
                              color: AppColors.primary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 10, color: AppColors.primary),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveServiceCard(Map<String, dynamic> srv) {
    final String name = srv['nama_produk'] ?? 'Layanan Cloud';
    final String category = srv['kategori'] ?? 'VPS';
    final String ip = srv['ip_address'] ?? '103.190.21.88';
    final String port = srv['port'] ?? '22';
    final String specs = srv['spesifikasi'] ?? 'Standard Specification';
    final String expDate = srv['tanggal_kadaluarsa'] ?? '';
    final String startDate = srv['tanggal_beli'] ?? '';

    DateTime? parsedExp = DateTime.tryParse(expDate);
    final String expStr = parsedExp != null
        ? DateFormat('dd MMM yyyy', 'id_ID').format(parsedExp)
        : expDate;

    DateTime? parsedStart = DateTime.tryParse(startDate);
    final String startStr = parsedStart != null
        ? DateFormat('dd MMM yyyy', 'id_ID').format(parsedStart)
        : startDate;

    int daysRemaining =
        parsedExp != null ? parsedExp.difference(DateTime.now()).inDays : 30;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.25 : 0.04),
            blurRadius: 14,
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
                  gradient: AppColors.cyanGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  category == 'VPS'
                      ? Icons.dns_rounded
                      : category.contains('Panel')
                          ? Icons.storage_rounded
                          : Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        color: _textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$category • $specs',
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
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Text(
                  LanguageService.text('Aktif', 'Active'),
                  style: GoogleFonts.poppins(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.terminal_rounded,
                        size: 14, color: AppColors.cyan),
                    const SizedBox(width: 6),
                    Text(
                      '$ip:$port',
                      style: GoogleFonts.firaCode(
                        color: _textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  daysRemaining >= 0 ? 'Sisa $daysRemaining Hari' : 'Expired',
                  style: GoogleFonts.poppins(
                    color:
                        daysRemaining > 5 ? AppColors.cyan : AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                startStr.isNotEmpty
                    ? 'Aktif: $startStr s/d $expStr'
                    : 'Masa Berlaku s/d: $expStr',
                style: GoogleFonts.poppins(
                  color: _textSecondary,
                  fontSize: 11,
                ),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProdukPage(
                        isDarkMode: _isDarkMode,
                        userRole: _currentUserRole,
                        userEmail: _activeEmail,
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  LanguageService.text('Perpanjang', 'Extend'),
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= FILTER & SEARCH BAR =================

  Widget _buildSearchAndFilterBar() {
    return Column(
      children: [
        // Search Input Field
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              _searchQuery = val;
              _applyFilters();
            },
            style: GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: LanguageService.text('Cari No. Invoice / Layanan...',
                  'Search Invoice / Service...'),
              hintStyle: GoogleFonts.poppins(
                  color: _textSecondary.withValues(alpha: 0.6), fontSize: 12.5),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.primary, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: _textSecondary, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _searchQuery = '';
                        _applyFilters();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              'Semua',
              'Lunas',
              'Pending',
              'Diproses',
              'Dibatalkan',
            ].map((st) {
              final isSelected = _selectedStatusFilter == st;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(st),
                  selected: isSelected,
                  onSelected: (selected) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedStatusFilter = st;
                      _applyFilters();
                    });
                  },
                  labelStyle: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : _textPrimary,
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  backgroundColor: _cardColor,
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : _cardBorder,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ================= HELPER WIDGETS =================

  Widget _buildStatusBadge(String status, {bool isCompact = false}) {
    Color badgeColor = AppColors.success;
    IconData badgeIcon = Icons.check_circle_rounded;
    String label = status;

    final lower = status.toLowerCase();
    if (lower.contains('selesai') ||
        lower.contains('lunas') ||
        lower.contains('success') ||
        lower.contains('settlement')) {
      badgeColor = AppColors.success;
      badgeIcon = Icons.check_circle_rounded;
      label = LanguageService.text('Lunas', 'Paid');
    } else if (lower.contains('pending') ||
        lower.contains('menunggu') ||
        lower.contains('unpaid')) {
      badgeColor = AppColors.warning;
      badgeIcon = Icons.schedule_rounded;
      label = LanguageService.text('Pending', 'Pending');
    } else if (lower.contains('batal') ||
        lower.contains('cancel') ||
        lower.contains('expire')) {
      badgeColor = AppColors.error;
      badgeIcon = Icons.cancel_rounded;
      label = LanguageService.text('Batal', 'Cancelled');
    } else {
      badgeColor = AppColors.cyan;
      badgeIcon = Icons.sync_rounded;
      label = LanguageService.text('Diproses', 'Processing');
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: isCompact ? 11 : 13, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: badgeColor,
              fontWeight: FontWeight.w700,
              fontSize: isCompact ? 10.5 : 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    IconData icon = Icons.receipt_long_outlined,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 50, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: _textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
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
              );
            },
            icon: const Icon(Icons.shopping_bag_outlined,
                color: Colors.white, size: 16),
            label: Text(
              LanguageService.text('Lihat Katalog Layanan', 'Explore Services'),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 12.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
