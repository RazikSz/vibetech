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
/// HALAMAN TOTAL PESANAN & MANAJEMEN TRANSAKSI (TOTAL PESANAN PAGE)
/// ============================================================================
/// Halaman ini berfungsi sebagai:
/// 1. Pelacak status pesanan member (Pending, Selesai, Diproses, Dibatalkan).
/// 2. Panel Admin untuk mengelola (Edit/Hapus/Tambah) transaksi seluruh member & admin.
/// 3. Navigasi pembayaran langsung bagi transaksi yang belum lunas.
/// 4. Pencarian dan filter interaktif pesanan berdasarkan invoice, nama, atau email.
class TotalPesananPage extends StatefulWidget {
  final bool isDarkMode;
  final String? username;
  final String? userEmail;
  final String? userRole;

  const TotalPesananPage({
    super.key,
    this.isDarkMode = true,
    this.username,
    this.userEmail,
    this.userRole,
  });

  @override
  State<TotalPesananPage> createState() => _TotalPesananPageState();
}

class _TotalPesananPageState extends State<TotalPesananPage>
    with TickerProviderStateMixin {
  bool _isSyncing = false;
  bool _isFetchingCloud = false;

  // Hak akses pengguna ('admin' / 'user')
  String _currentUserRole = 'user';
  String _activeEmail = '';
  String _activeUsername = '';

  // Data transaksi dan statistik pemesanan dari SQLite
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  List<Map<String, dynamic>> _allUsers = [];
  Map<String, dynamic> _stats = {
    'total': 0,
    'selesai': 0,
    'pending': 0,
    'diproses': 0,
    'dibatalkan': 0,
    'totalSpent': 0.0,
  };

  // State Filter Kategori & Pencarian
  String _selectedFilter = 'Semua';
  String _searchQuery = '';
  String _selectedMemberFilter =
      'ALL'; // Filter khusus Admin: 'ALL' atau email tertentu
  final TextEditingController _searchController = TextEditingController();

  // Controller animasi partikel latar belakang
  late AnimationController _particleController;
  late AnimationController _pulseController;
  late AnimationController _listAnimController;
  final List<AppParticle> _particles = [];
  final math.Random _random = math.Random();

  bool get _isAdmin =>
      _currentUserRole == 'admin' ||
      _currentUserRole == 'administrator' ||
      _activeUsername.toLowerCase() == 'admin' ||
      _activeUsername.toLowerCase() == 'raziek' ||
      _activeEmail.toLowerCase() == 'admin@vibetech.com';

  Color get _bgColor =>
      widget.isDarkMode ? AppColors.darkBg : AppColors.lightBg;
  Color get _cardColor =>
      widget.isDarkMode ? AppColors.darkCard : AppColors.lightCard;
  Color get _cardElevated => widget.isDarkMode
      ? AppColors.darkCardElevated
      : AppColors.lightCardElevated;
  Color get _textPrimary => widget.isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.lightTextPrimary;
  Color get _textSecondary => widget.isDarkMode
      ? AppColors.darkTextSecondary
      : AppColors.lightTextSecondary;
  Color get _cardBorder => widget.isDarkMode
      ? AppColors.primary.withValues(alpha: 0.18)
      : const Color(0xFFE2E8F0);

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  Timer? _liveSyncTimer;
  VoidCallback? _txRealtimeListener;

  @override
  void initState() {
    super.initState();

    // Inisialisasi Partikel Cyber untuk Dark Mode
    _particles.addAll(AppParticle.generateList(_random, count: 22));

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _particleController.addListener(() {
      AppParticle.updatePositions(_particles);
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _listAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Hubungkan listener streaming real-time Firebase RTDB untuk pembaruan pesanan transaksi
    _txRealtimeListener = () async {
      if (mounted) {
        await _loadOrdersData(triggerCloudSync: false);
      }
    };
    CloudSyncService.instance.transactionsNotifier
        .addListener(_txRealtimeListener!);
    CloudSyncService.instance.servicesNotifier
        .addListener(_txRealtimeListener!);

    _initUserDataAndLoad();
  }

  @override
  void dispose() {
    if (_txRealtimeListener != null) {
      CloudSyncService.instance.transactionsNotifier
          .removeListener(_txRealtimeListener!);
      CloudSyncService.instance.servicesNotifier
          .removeListener(_txRealtimeListener!);
    }
    _liveSyncTimer?.cancel();
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
      String role = widget.userRole ?? prefs.getString('role') ?? 'user';

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

      await _loadOrdersData();

      // Mulai sinkronisasi cadangan di latar belakang (fallback untuk streaming listener)
      _liveSyncTimer?.cancel();
      _liveSyncTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (mounted && !_isSyncing) {
          if (_isAdmin) {
            _fetchCloudOrdersInBackground(_allTransactions);
          } else {
            _fetchUserCloudOrdersInBackground(_allTransactions);
          }
        }
      });
    } catch (e) {
      debugPrint('Error initializing orders page: $e');
    } finally {
      if (mounted) {
        _listAnimController.forward(from: 0.0);
      }
    }
  }

  Future<void> _loadOrdersData({bool triggerCloudSync = true}) async {
    try {
      await DatabaseHelper.instance.cleanupDuplicateTransactions();
      List<Map<String, dynamic>> rawList = [];

      if (_isAdmin) {
        // 1. Muat seluruh transaksi dari SQLite lokal secara INSTAN
        final localTx = await DatabaseHelper.instance.getAllTransactions();
        _allUsers = await DatabaseHelper.instance.getAllUsers();

        if (_selectedMemberFilter != 'ALL') {
          rawList = localTx.where((t) {
            final email = (t['user_email'] ?? '').toString().toLowerCase();
            return email == _selectedMemberFilter.toLowerCase();
          }).toList();
        } else {
          rawList = localTx;
        }

        _recalculateStats(rawList);
        _allTransactions = rawList;
        _applyFilterAndSearch();

        // 2. Muat pembaruan Firebase Realtime Database di background jika diizinkan
        if (triggerCloudSync && !_isFetchingCloud) {
          _fetchCloudOrdersInBackground(localTx);
        }
      } else {
        // Pengguna/Member biasa: muat data SQLite miliknya secara INSTAN
        final localTx =
            await DatabaseHelper.instance.getTransactionsByUser(_activeEmail);

        rawList = localTx;
        _recalculateStats(rawList);
        _allTransactions = rawList;
        _applyFilterAndSearch();

        // Muat RTDB background untuk user jika diizinkan
        if (triggerCloudSync && !_isFetchingCloud) {
          _fetchUserCloudOrdersInBackground(localTx);
        }
      }
    } catch (e) {
      debugPrint('Error loading orders: $e');
    }
  }

  void _recalculateStats(List<Map<String, dynamic>> list) {
    final int total = list.length;
    final int selesai = list.where((t) {
      final st = (t['status'] ?? '').toString().toLowerCase();
      return st == 'selesai' ||
          st == 'success' ||
          st == 'settlement' ||
          st == 'capture' ||
          st == 'berhasil';
    }).length;
    final int pending = list.where((t) {
      final st = (t['status'] ?? '').toString().toLowerCase();
      return st.contains('pending') ||
          st.contains('menunggu') ||
          st.contains('unpaid') ||
          st.contains('proses');
    }).length;
    final double totalSpent = list.fold(0.0, (sum, t) {
      final st = (t['status'] ?? '').toString().toLowerCase();
      if (st == 'selesai' ||
          st == 'success' ||
          st == 'settlement' ||
          st == 'capture' ||
          st == 'berhasil') {
        return sum + ((t['total_harga'] as num?)?.toDouble() ?? 0.0);
      }
      return sum;
    });

    _stats = {
      'total': total,
      'selesai': selesai,
      'pending': pending,
      'diproses': 0,
      'dibatalkan': list
          .where((t) =>
              (t['status'] ?? '').toString().toLowerCase().contains('batal'))
          .length,
      'totalSpent': totalSpent,
    };
  }

  void _fetchCloudOrdersInBackground(List<Map<String, dynamic>> localTx) async {
    if (_isFetchingCloud) return;
    _isFetchingCloud = true;
    try {
      await Future.wait([
        FirebaseTransactionService.instance.syncTransactionsFromFirebase(),
        FirebaseTransactionService.instance.syncServicesFromFirebase(),
      ]).timeout(const Duration(seconds: 5), onTimeout: () => []);
      final freshTx = await DatabaseHelper.instance.getAllTransactions();
      if (!mounted) return;

      List<Map<String, dynamic>> finalResult;
      if (_selectedMemberFilter != 'ALL') {
        finalResult = freshTx.where((t) {
          final email = (t['user_email'] ?? '').toString().toLowerCase();
          return email == _selectedMemberFilter.toLowerCase();
        }).toList();
      } else {
        finalResult = freshTx;
      }

      setState(() {
        _recalculateStats(finalResult);
        _allTransactions = finalResult;
      });
      _applyFilterAndSearch();
    } catch (e) {
      debugPrint('Background cloud orders note: $e');
    } finally {
      _isFetchingCloud = false;
    }
  }

  void _fetchUserCloudOrdersInBackground(
      List<Map<String, dynamic>> localTx) async {
    if (_isFetchingCloud) return;
    _isFetchingCloud = true;
    try {
      await Future.wait([
        FirebaseTransactionService.instance
            .syncTransactionsFromFirebase(userEmail: _activeEmail),
        FirebaseTransactionService.instance
            .syncServicesFromFirebase(userEmail: _activeEmail),
      ]).timeout(const Duration(seconds: 5), onTimeout: () => []);
      final freshTx =
          await DatabaseHelper.instance.getTransactionsByUser(_activeEmail);
      if (!mounted) return;

      setState(() {
        _recalculateStats(freshTx);
        _allTransactions = freshTx;
      });
      _applyFilterAndSearch();
    } catch (e) {
      debugPrint('Background user cloud orders note: $e');
    } finally {
      _isFetchingCloud = false;
    }
  }

  Future<void> _syncWithFirebase() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                LanguageService.text(
                  'Menyinkronkan seluruh pesanan ke Firebase RTDB...',
                  'Syncing all orders to Firebase RTDB...',
                ),
                style: GoogleFonts.poppins(fontSize: 12.5),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      // 1. Sinkronisasi dari Cloud ke lokal (termasuk deteksi penghapusan di RTDB)
      await FirebaseTransactionService.instance.syncTransactionsFromFirebase();
      // 2. Sinkronisasi dari lokal ke Cloud
      await CloudSyncService.instance.syncAllFromCloud();
      final txCount = await FirebaseTransactionService.instance
          .syncAllLocalTransactionsToFirestore();
      await _loadOrdersData();

      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LanguageService.text(
                'Sukses! $txCount pesanan pengguna & admin tersinkronisasi ke Firebase RTDB.',
                'Success! $txCount user & admin orders synced to Firebase RTDB.',
              ),
              style: GoogleFonts.poppins(fontSize: 12.5),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal sinkronisasi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _applyFilterAndSearch() {
    List<Map<String, dynamic>> list = List.from(_allTransactions);

    // 1. Status Filter
    if (_selectedFilter != 'Semua') {
      list = list.where((item) {
        final status = (item['status'] ?? '').toString().toLowerCase();
        switch (_selectedFilter) {
          case 'Selesai':
            return status.contains('selesai') ||
                status.contains('success') ||
                status.contains('settlement') ||
                status.contains('berhasil');
          case 'Pending':
            return status.contains('pending') ||
                status.contains('menunggu') ||
                status.contains('unpaid');
          case 'Diproses':
            return status.contains('proses') ||
                status.contains('diproses') ||
                status.contains('active');
          case 'Dibatalkan':
            return status.contains('batal') ||
                status.contains('cancel') ||
                status.contains('expire') ||
                status.contains('deny');
          default:
            return true;
        }
      }).toList();
    }

    // 2. Search Query Filter
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      list = list.where((item) {
        final nama = (item['nama_produk'] ?? '').toString().toLowerCase();
        final email = (item['user_email'] ?? '').toString().toLowerCase();
        final id = (item['id'] ?? '').toString();
        final invoice = (item['invoice_no'] ?? '').toString().toLowerCase();
        return nama.contains(query) ||
            email.contains(query) ||
            id.contains(query) ||
            invoice.contains(query);
      }).toList();
    }

    setState(() {
      _filteredTransactions = list;
    });
  }

  // ================= ADMIN ACTIONS: EDIT, TAMBAH, HAPUS =================

  void _showAdminEditOrderDialog(Map<String, dynamic> item) {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.text(
            'Akses Ditolak! Hanya Administrator yang dapat mengubah pesanan.',
            'Access Denied! Only Administrators can edit orders.',
          )),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    // PERBAIKAN: Cast aman dari num ke int
    final int orderId = (item['id'] as num?)?.toInt() ?? 0;

    final nameCtrl =
        TextEditingController(text: item['nama_produk']?.toString() ?? '');

    // PERBAIKAN: Cast aman dari num ke int
    final int qty = (item['jumlah'] as num?)?.toInt() ?? 1;
    final qtyCtrl = TextEditingController(text: qty.toString());

    // PERBAIKAN: Cast aman dari num ke double
    final double price = (item['total_harga'] as num?)?.toDouble() ?? 0.0;
    final priceCtrl = TextEditingController(text: price.toString());

    final emailCtrl =
        TextEditingController(text: item['user_email']?.toString() ?? '');
    final invoiceCtrl = TextEditingController(
        text: item['invoice_no']?.toString() ??
            'INV-${orderId.toString().padLeft(5, '0')}');
    final notesCtrl =
        TextEditingController(text: item['notes']?.toString() ?? '');

    String currentStatus = (item['status'] ?? 'Selesai').toString();
    final List<String> availableStatuses = [
      'Selesai',
      'Pending',
      'Diproses',
      'Dibatalkan',
    ];

    if (!availableStatuses.contains(currentStatus)) {
      if (currentStatus.toLowerCase().contains('selesai')) {
        currentStatus = 'Selesai';
      } else if (currentStatus.toLowerCase().contains('pending')) {
        currentStatus = 'Pending';
      } else if (currentStatus.toLowerCase().contains('batal')) {
        currentStatus = 'Dibatalkan';
      } else {
        currentStatus = 'Diproses';
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_note_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LanguageService.text(
                            'Edit Pesanan Member', 'Edit Member Order'),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _textPrimary,
                        ),
                      ),
                      Text(
                        'ID Transaksi: #$orderId',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogTextField(
                      controller: emailCtrl,
                      label:
                          LanguageService.text('Email Member', 'Member Email'),
                      icon: Icons.person_outline_rounded,
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Email wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogTextField(
                      controller: nameCtrl,
                      label: LanguageService.text(
                          'Nama Layanan / Produk', 'Product Name'),
                      icon: Icons.shopping_bag_outlined,
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Nama produk wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildDialogTextField(
                            controller: qtyCtrl,
                            label: LanguageService.text('Jumlah Qty', 'Qty'),
                            icon: Icons.numbers_rounded,
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || int.tryParse(val) == null) {
                                return 'Qty tidak valid';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: _buildDialogTextField(
                            controller: priceCtrl,
                            label: LanguageService.text(
                                'Total Harga (Rp)', 'Total Price'),
                            icon: Icons.payments_outlined,
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || double.tryParse(val) == null) {
                                return 'Harga tidak valid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      LanguageService.text('Status Pesanan', 'Order Status'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: _bgColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: currentStatus,
                          isExpanded: true,
                          dropdownColor: _cardElevated,
                          icon: const Icon(Icons.arrow_drop_down_rounded,
                              color: AppColors.primary),
                          items: availableStatuses.map((st) {
                            return DropdownMenuItem<String>(
                              value: st,
                              child: Row(
                                children: [
                                  _buildStatusBadge(st, isCompact: true),
                                  const SizedBox(width: 8),
                                  Text(st,
                                      style: GoogleFonts.poppins(
                                          color: _textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => currentStatus = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDialogTextField(
                      controller: invoiceCtrl,
                      label: LanguageService.text('No. Invoice', 'Invoice No.'),
                      icon: Icons.receipt_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogTextField(
                      controller: notesCtrl,
                      label: LanguageService.text(
                          'Catatan Admin (Opsional)', 'Admin Notes'),
                      icon: Icons.notes_rounded,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                    HapticFeedback.mediumImpact();
                    final String oldInvoice =
                        (item['invoice_no'] ?? item['id_ref'] ?? '').toString();
                    final String newInvoice = invoiceCtrl.text.trim();

                    final updatedData = {
                      'id': orderId > 0 ? orderId : null,
                      'user_email': emailCtrl.text.trim(),
                      'nama_produk': nameCtrl.text.trim(),
                      'jumlah': int.tryParse(qtyCtrl.text.trim()) ?? 1,
                      'total_harga':
                          double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                      'status': currentStatus,
                      'invoice_no': newInvoice,
                      'notes': notesCtrl.text.trim(),
                      'tanggal':
                          item['tanggal'] ?? DateTime.now().toIso8601String(),
                      'payment_method':
                          item['payment_method'] ?? 'Saldo VibeWallet',
                    };

                    // 1. Update UI secara instan (0ms optimistic)
                    setState(() {
                      final idx = _allTransactions.indexWhere((t) =>
                          (orderId > 0 && t['id'] == orderId) ||
                          (oldInvoice.isNotEmpty &&
                              (t['invoice_no'] == oldInvoice ||
                                  t['id_ref'] == oldInvoice)));
                      if (idx != -1) {
                        _allTransactions[idx] = {
                          ..._allTransactions[idx],
                          ...updatedData
                        };
                      }
                      _recalculateStats(_allTransactions);
                    });
                    _applyFilterAndSearch();

                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          LanguageService.text(
                            'Pesanan $newInvoice berhasil diperbarui di SQLite & Firebase!',
                            'Order $newInvoice updated in SQLite & Firebase!',
                          ),
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ),
                    );

                    // 2. Simpan ke SQLite & Firebase RTDB
                    try {
                      final db = await DatabaseHelper.instance.database;
                      if (orderId > 0) {
                        await DatabaseHelper.instance
                            .updateTransaction(orderId, updatedData);
                      } else if (oldInvoice.isNotEmpty) {
                        await db.update('transactions', updatedData,
                            where: 'invoice_no = ?', whereArgs: [oldInvoice]);
                      }

                      await FirebaseTransactionService.instance
                          .updateTransactionInFirebase(
                        invoiceNo:
                            oldInvoice.isNotEmpty ? oldInvoice : newInvoice,
                        localId: orderId > 0 ? orderId : null,
                        namaProduk: nameCtrl.text.trim(),
                        userEmail: emailCtrl.text.trim(),
                        updatedData: updatedData,
                      );

                      // Jika status selesai/lunas, otomatis sinkronkan juga ke purchased_services di SQLite & Firebase RTDB
                      final statusLower = currentStatus.toLowerCase();
                      if (statusLower.contains('selesai') ||
                          statusLower.contains('lunas') ||
                          statusLower.contains('success')) {
                        final prodName = nameCtrl.text.trim();
                        String kategori = 'VPS';
                        final lower = prodName.toLowerCase();
                        if (lower.contains('panel') || lower.contains('hosting')) {
                          kategori = 'Panel Hosting';
                        } else if (lower.contains('bot') || lower.contains('wa')) {
                          kategori = 'Bot WhatsApp';
                        }
                        final srvData = {
                          'user_email': emailCtrl.text.trim(),
                          'nama_produk': prodName,
                          'kategori': kategori,
                          'harga': double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                          'tanggal_beli': item['tanggal']?.toString() ??
                              DateTime.now().toIso8601String(),
                          'tanggal_kadaluarsa': DateTime.now()
                              .add(const Duration(days: 30))
                              .toIso8601String(),
                          'status': 'Aktif',
                          'spesifikasi': 'Layanan Cloud Aktif VibeTech',
                        };
                        await DatabaseHelper.instance.createService(srvData);
                      }
                    } catch (e) {
                      debugPrint('Error updating transaction: $e');
                    }
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

  void _showAdminCreateOrderDialog() {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.text(
            'Akses Ditolak! Hanya Administrator yang dapat membuat pesanan manual.',
            'Access Denied! Only Administrators can create manual orders.',
          )),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    String targetEmail = _allUsers.isNotEmpty
        ? (_allUsers.first['email']?.toString() ?? 'user@vibetech.com')
        : 'user@vibetech.com';
    final nameCtrl = TextEditingController(text: 'VPS Starter Cloud 2GB');
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: '50000');
    final invoiceCtrl = TextEditingController(
        text:
            'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}');
    String status = 'Selesai';
    String paymentMethod = 'Saldo VibeTech';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                        colors: [AppColors.primary, AppColors.accent]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_shopping_cart_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    LanguageService.text(
                        'Tambah Pesanan Member', 'Add Member Order'),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LanguageService.text(
                          'Pilih Akun Member', 'Select Member'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: _bgColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: targetEmail,
                          isExpanded: true,
                          dropdownColor: _cardElevated,
                          icon: const Icon(Icons.arrow_drop_down_rounded,
                              color: AppColors.primary),
                          items: _allUsers.isNotEmpty
                              ? _allUsers.map((u) {
                                  final em = u['email']?.toString() ?? '';
                                  final nm = u['nama']?.toString() ??
                                      u['username']?.toString() ??
                                      '';
                                  return DropdownMenuItem<String>(
                                    value: em,
                                    child: Text(
                                      '$nm ($em)',
                                      style: GoogleFonts.poppins(
                                        color: _textPrimary,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList()
                              : [
                                  DropdownMenuItem<String>(
                                    value: 'user@vibetech.com',
                                    child: Text(
                                        'Demo Member (user@vibetech.com)',
                                        style: GoogleFonts.poppins(
                                            color: _textPrimary)),
                                  )
                                ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => targetEmail = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDialogTextField(
                      controller: nameCtrl,
                      label: LanguageService.text(
                          'Nama Layanan / Produk', 'Product Name'),
                      icon: Icons.dns_rounded,
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Nama produk wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildDialogTextField(
                            controller: qtyCtrl,
                            label: LanguageService.text('Qty', 'Qty'),
                            icon: Icons.numbers_rounded,
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || int.tryParse(val) == null) {
                                return 'Qty tidak valid';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: _buildDialogTextField(
                            controller: priceCtrl,
                            label: LanguageService.text(
                                'Total Harga (Rp)', 'Total Price'),
                            icon: Icons.payments_outlined,
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || double.tryParse(val) == null) {
                                return 'Harga tidak valid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      LanguageService.text(
                          'Status Awal Pesanan', 'Initial Status'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: _bgColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: status,
                          isExpanded: true,
                          dropdownColor: _cardElevated,
                          items: [
                            'Selesai',
                            'Pending',
                            'Diproses',
                            'Dibatalkan'
                          ].map((st) {
                            return DropdownMenuItem<String>(
                              value: st,
                              child: Text(st,
                                  style: GoogleFonts.poppins(
                                      color: _textPrimary, fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => status = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDialogTextField(
                      controller: invoiceCtrl,
                      label: LanguageService.text('No. Invoice', 'Invoice No.'),
                      icon: Icons.receipt_rounded,
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                    HapticFeedback.mediumImpact();
                    final newOrder = {
                      'user_email': targetEmail,
                      'nama_produk': nameCtrl.text.trim(),
                      'jumlah': int.tryParse(qtyCtrl.text.trim()) ?? 1,
                      'total_harga':
                          double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                      'tanggal': DateTime.now().toIso8601String(),
                      'status': status,
                      'payment_method': paymentMethod,
                      'invoice_no': invoiceCtrl.text.trim(),
                    };

                    final createdId = await DatabaseHelper.instance
                        .createTransaction(newOrder);
                    try {
                      await FirebaseTransactionService.instance
                          .saveTransactionToFirebase({
                        'id': createdId,
                        ...newOrder,
                      });
                    } catch (_) {}
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                    await _loadOrdersData();

                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          LanguageService.text(
                            'Pesanan baru berhasil dibuat dan disimpan ke database!',
                            'New order created and saved to database!',
                          ),
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.save_rounded,
                    color: Colors.white, size: 18),
                label: Text(
                  LanguageService.text('Simpan Pesanan', 'Save Order'),
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

  void _showDeleteOrderConfirmation(Map<String, dynamic> order) {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.text(
            'Akses Ditolak! Hanya Administrator yang dapat menghapus pesanan.',
            'Access Denied! Only Administrators can delete orders.',
          )),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final int orderId = (order['id'] as num?)?.toInt() ?? 0;
    final String productName =
        order['nama_produk']?.toString() ?? 'Layanan VibeTech';
    final String invoiceNo =
        (order['invoice_no'] ?? order['id_ref'] ?? '').toString();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: _cardColor,
        surfaceTintColor: Colors.transparent,
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
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                LanguageService.text('Hapus Pesanan?', 'Delete Order?'),
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
            'Apakah Anda yakin ingin menghapus pesanan ${invoiceNo.isNotEmpty ? invoiceNo : "#$orderId"} ($productName) secara permanen dari database lokal dan Firebase cloud? Tindakan ini tidak dapat dibatalkan.',
            'Are you sure you want to permanently delete order ${invoiceNo.isNotEmpty ? invoiceNo : "#$orderId"} ($productName) from local database and Firebase cloud? This action cannot be undone.',
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

              // 1. Langsung tutup dialog secara instan agar tidak macet
              Navigator.of(dialogCtx, rootNavigator: true).pop();

              // 2. Langsung hapus dari state UI (optimistic UI update)
              setState(() {
                _allTransactions.removeWhere((t) {
                  final tInv =
                      (t['invoice_no'] ?? t['id_ref'] ?? '').toString().trim();
                  final tId = (t['id'] as num?)?.toInt();
                  if (invoiceNo.isNotEmpty &&
                      (tInv == invoiceNo ||
                          tInv == invoiceNo.replaceAll('INV-', ''))) {
                    return true;
                  }
                  if (orderId > 0 && tId == orderId) return true;
                  return false;
                });
                _recalculateStats(_allTransactions);
              });
              _applyFilterAndSearch();

              // 3. Eksekusi penghapusan SQLite & Firebase RTDB
              try {
                if (orderId > 0) {
                  await DatabaseHelper.instance
                      .deleteTransaction(orderId, invoiceNo: invoiceNo);
                } else if (invoiceNo.isNotEmpty) {
                  await DatabaseHelper.instance
                      .deleteTransactionByInvoice(invoiceNo);
                }
              } catch (e) {
                debugPrint('Error deleting order: $e');
              }

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    LanguageService.text(
                      'Pesanan ${invoiceNo.isNotEmpty ? invoiceNo : "#$orderId"} berhasil dihapus permanen.',
                      'Order ${invoiceNo.isNotEmpty ? invoiceNo : "#$orderId"} permanently deleted.',
                    ),
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              LanguageService.text('Hapus', 'Delete'),
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPayment(Map<String, dynamic> item) {
    HapticFeedback.mediumImpact();
    final String prodName = item['nama_produk'] ?? 'Layanan VibeTech';
    final int qty = (item['jumlah'] as num?)?.toInt() ?? 1;
    final double totalPrice = (item['total_harga'] as num?)?.toDouble() ?? 0.0;
    final double unitPrice = qty > 0 ? (totalPrice / qty) : totalPrice;
    final String email = item['user_email'] ?? _activeEmail;
    final String? invoiceNo = item['invoice_no']?.toString();

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
          isDarkMode: widget.isDarkMode,
          userEmail: email,
          invoiceNumber: invoiceNo,
        ),
      ),
    ).then((_) => _loadOrdersData());
  }

  void _showOrderDetailBottomSheet(Map<String, dynamic> item) {
    // PERBAIKAN: Cast aman dari num ke int
    final int id = (item['id'] as num?)?.toInt() ?? 0;
    final String name = item['nama_produk'] ?? 'Layanan VibeTech';

    // PERBAIKAN: Cast aman dari num ke int
    final int qty = (item['jumlah'] as num?)?.toInt() ?? 1;

    // PERBAIKAN: Cast aman dari num ke double
    final double totalPrice = (item['total_harga'] as num?)?.toDouble() ?? 0.0;

    final String status = (item['status'] ?? 'Selesai').toString();
    final bool isLunas = status.toLowerCase().contains('selesai') ||
        status.toLowerCase().contains('lunas') ||
        status.toLowerCase().contains('success') ||
        status.toLowerCase().contains('settlement') ||
        status.toLowerCase().contains('berhasil');
    final String email = item['user_email'] ?? '';
    final String dateStr = item['tanggal'] ?? '';
    final String invoice =
        item['invoice_no'] ?? 'INV-${id.toString().padLeft(5, '0')}';
    final String paymentMethod = item['payment_method'] ?? 'Saldo VibeTech';
    final String notes = item['notes'] ?? '';

    DateTime parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    final formattedDate =
        DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(parsedDate);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: _cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 30,
                offset: const Offset(0, -10),
              )
            ],
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
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LanguageService.text(
                              'Rincian Pesanan', 'Order Details'),
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          invoice,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
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
              Divider(color: _cardBorder, height: 1),
              const SizedBox(height: 16),

              // Detail Grid Item
              _buildDetailRow(
                  LanguageService.text('Produk / Layanan', 'Product / Service'),
                  name),
              _buildDetailRow(
                  LanguageService.text('Kuantitas', 'Quantity'), '$qty item'),
              _buildDetailRow(LanguageService.text('Tanggal Transaksi', 'Date'),
                  formattedDate),
              _buildDetailRow(
                  LanguageService.text('Metode Pembayaran', 'Payment Method'),
                  paymentMethod),
              _buildDetailRow(
                  LanguageService.text('Akun Pemesan', 'Customer Account'),
                  email),
              if (notes.isNotEmpty)
                _buildDetailRow(
                    LanguageService.text('Catatan', 'Notes'), notes),

              const SizedBox(height: 12),
              Divider(color: _cardBorder, height: 1),
              const SizedBox(height: 14),

              // Total Harga
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    LanguageService.text('Total Pembayaran', 'Total Amount'),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  Text(
                    _currencyFormatter.format(totalPrice),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Buttons
              if (!isLunas) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _navigateToPayment(item);
                    },
                    icon: const Icon(Icons.payment_rounded,
                        color: Colors.white, size: 18),
                    label: Text(
                      LanguageService.text(
                          'Lanjutkan Pembayaran', 'Continue Payment'),
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: invoice));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              LanguageService.text(
                                'No. Invoice disalin ke clipboard!',
                                'Invoice No. copied to clipboard!',
                              ),
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: Text(
                        LanguageService.text('Salin', 'Copy'),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textPrimary,
                        side: BorderSide(color: _cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  if (_isAdmin) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAdminEditOrderDialog(item);
                        },
                        icon: const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 16),
                        label: Text(
                          LanguageService.text('Edit', 'Edit'),
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showDeleteOrderConfirmation(item);
                        },
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.white, size: 16),
                        label: Text(
                          LanguageService.text('Hapus', 'Delete'),
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: _bgColor,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
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
                gradient: widget.isDarkMode
                    ? AppColors.darkBackgroundGradient
                    : AppColors.lightBackgroundGradient,
              ),
            ),
          ),

          // 2. Ambient Glowing Orbs in Dark Mode
          if (widget.isDarkMode) AppNeonOrbs(pulseAnimation: _pulseController),

          // 3. Floating Cyber Particles in Dark Mode
          if (widget.isDarkMode)
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
                Expanded(
                  child: RefreshIndicator(
                          onRefresh: _loadOrdersData,
                          color: AppColors.primary,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Mode Khusus Admin Banner
                                if (_isAdmin) _buildAdminControlBanner(),

                                // Hero Stats Cards
                                _buildStatsGrid(),
                                const SizedBox(height: 20),

                                // Member Filter Dropdown (Khusus Admin)
                                if (_isAdmin) ...[
                                  _buildAdminMemberFilter(),
                                  const SizedBox(height: 16),
                                ],

                                // Search Bar & Filter Chips
                                _buildSearchAndFilterSection(),
                                const SizedBox(height: 18),

                                // Header List Rincian Pesanan
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      LanguageService.text(
                                          'Rincian Pesanan', 'Order Breakdown'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _textPrimary,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_filteredTransactions.length} ${LanguageService.text('Pesanan', 'Orders')}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Order Cards List or Empty State
                                if (_filteredTransactions.isEmpty)
                                  _buildEmptyState()
                                else
                                  ..._filteredTransactions.map(
                                    (item) => _buildOrderCard(item),
                                  ),

                                const SizedBox(height: 40),
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
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showAdminCreateOrderDialog,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                LanguageService.text('Tambah Pesanan', 'Add Order'),
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary),
            tooltip: LanguageService.text('Kembali', 'Back'),
          ),
          Flexible(
            child: Text(
              LanguageService.text(
                  'Total Pesanan & Rincian', 'Total Orders & Details'),
              style: GoogleFonts.poppins(
                color: _textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isAdmin)
                IconButton(
                  onPressed: _syncWithFirebase,
                  icon: const Icon(Icons.cloud_sync_rounded,
                      color: AppColors.cyan),
                  tooltip: LanguageService.text('Sinkron RTDB', 'Sync RTDB'),
                ),
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _loadOrdersData();
                },
                icon: const Icon(Icons.refresh_rounded, color: AppColors.cyan),
                tooltip: LanguageService.text('Muat Ulang', 'Refresh'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminControlBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.25),
            AppColors.accent.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LanguageService.text(
                    '👑 Mode Khusus Administrator',
                    '👑 Administrator Control Mode',
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  LanguageService.text(
                    'Anda dapat mengedit, menambah, dan menghapus pesanan member.',
                    'You can edit, add, and manage member orders.',
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    // PERBAIKAN PENTING: Menggunakan as num? lalu toInt() pada data statistik
    final int total = (_stats['total'] as num?)?.toInt() ?? 0;
    final int selesai = (_stats['selesai'] as num?)?.toInt() ?? 0;
    final int pending = ((_stats['pending'] as num?)?.toInt() ?? 0) +
        ((_stats['diproses'] as num?)?.toInt() ?? 0);
    final double totalSpent = (_stats['totalSpent'] as num?)?.toDouble() ?? 0.0;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: [
        _buildStatTile(
          title: LanguageService.text('Total Pesanan', 'Total Orders'),
          value: total.toString(),
          subtitle: LanguageService.text('Semua Pesanan', 'All Transactions'),
          icon: Icons.shopping_bag_outlined,
          gradient: const LinearGradient(
            colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        _buildStatTile(
          title: LanguageService.text('Pesanan Selesai', 'Completed'),
          value: selesai.toString(),
          subtitle: LanguageService.text('Layanan Aktif', 'Active Services'),
          icon: Icons.check_circle_outline_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF34D399), Color(0xFF10B981)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        _buildStatTile(
          title: LanguageService.text('Menunggu / Proses', 'Pending / Process'),
          value: pending.toString(),
          subtitle: LanguageService.text('Perlu Tindakan', 'Needs Action'),
          icon: Icons.schedule_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        _buildStatTile(
          title: LanguageService.text('Total Belanja', 'Total Spent'),
          value: _currencyFormatter.format(totalSpent),
          subtitle: LanguageService.text('Akumulasi Nilai', 'Total Value'),
          icon: Icons.account_balance_wallet_outlined,
          gradient: const LinearGradient(
            colors: [Color(0xFFF472B6), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          isCompactText: true,
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    bool isCompactText = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Icon(icon, color: Colors.white, size: 20),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: isCompactText ? 16 : 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminMemberFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Text(
            LanguageService.text('Filter Akun:', 'Account Filter:'),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedMemberFilter,
                isExpanded: true,
                dropdownColor: _cardElevated,
                items: [
                  DropdownMenuItem<String>(
                    value: 'ALL',
                    child: Text(
                      LanguageService.text('Semua Pengguna & Admin',
                          'All Users & Admins (All Orders)'),
                      style: GoogleFonts.poppins(
                          color: _textPrimary, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ..._allUsers.map((u) {
                    final email = u['email']?.toString() ?? '';
                    final nama = u['nama']?.toString() ??
                        u['username']?.toString() ??
                        '';
                    final role = (u['role'] ?? 'user').toString().toLowerCase();
                    final isAdm = role == 'admin' || role == 'administrator';
                    return DropdownMenuItem<String>(
                      value: email,
                      child: Text(
                        '${isAdm ? "👑 " : ""}$nama ($email)',
                        style: GoogleFonts.poppins(
                            color: _textPrimary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedMemberFilter = val;
                    });
                    _loadOrdersData();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    final List<String> filters = [
      'Semua',
      'Selesai',
      'Pending',
      'Diproses',
      'Dibatalkan'
    ];

    return Column(
      children: [
        // Search Input
        TextField(
          controller: _searchController,
          onChanged: (val) {
            _searchQuery = val;
            _applyFilterAndSearch();
          },
          style: GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: LanguageService.text(
              'Cari nama produk, no. invoice, email...',
              'Search product, invoice no., email...',
            ),
            hintStyle: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
            prefixIcon:
                const Icon(Icons.search_rounded, color: AppColors.primary),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: _textSecondary),
                    onPressed: () {
                      _searchController.clear();
                      _searchQuery = '';
                      _applyFilterAndSearch();
                    },
                  )
                : null,
            filled: true,
            fillColor: _cardColor,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: filters.map((f) {
              final isSelected = _selectedFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    f,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : _textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFilter = f);
                      _applyFilterAndSearch();
                    }
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: _cardColor,
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : _cardBorder,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> item) {
    // PERBAIKAN: Cast aman dari num ke int/double
    final int id = (item['id'] as num?)?.toInt() ?? 0;
    final String name = item['nama_produk'] ?? 'Layanan VibeTech';
    final int qty = (item['jumlah'] as num?)?.toInt() ?? 1;
    final double totalPrice = (item['total_harga'] as num?)?.toDouble() ?? 0.0;

    final String status = (item['status'] ?? 'Selesai').toString();
    final bool isLunas = status.toLowerCase().contains('selesai') ||
        status.toLowerCase().contains('lunas') ||
        status.toLowerCase().contains('success') ||
        status.toLowerCase().contains('settlement') ||
        status.toLowerCase().contains('berhasil');
    final String dateStr = item['tanggal'] ?? '';
    final String invoice =
        item['invoice_no'] ?? 'INV-${id.toString().padLeft(5, '0')}';
    final String userEmail = item['user_email'] ?? '';

    DateTime parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    final formattedDate =
        DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(parsedDate);

    // Icon kategori
    IconData iconData = Icons.dns_rounded;
    if (name.toLowerCase().contains('panel') ||
        name.toLowerCase().contains('hosting')) {
      iconData = Icons.cloud_rounded;
    } else if (name.toLowerCase().contains('bot') ||
        name.toLowerCase().contains('wa')) {
      iconData = Icons.chat_bubble_outline_rounded;
    } else if (name.toLowerCase().contains('domain')) {
      iconData = Icons.language_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showOrderDetailBottomSheet(item),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Invoice & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child:
                              Icon(iconData, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invoice,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                formattedDate,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: _textSecondary,
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
                  const SizedBox(width: 8),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 12),

              // Middle: Product Name & Email if Admin
              Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              if (_isAdmin && userEmail.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Member: $userEmail',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: _textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 10),

              // Bottom Row: Qty & Total Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$qty x ${_currencyFormatter.format(qty > 0 ? totalPrice / qty : totalPrice)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                  ),
                  Text(
                    _currencyFormatter.format(totalPrice),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cyan,
                    ),
                  ),
                ],
              ),
              // Action Buttons Row (Lanjutkan Pembayaran & Edit / Hapus Actions)
              const SizedBox(height: 12),
              Divider(color: _cardBorder.withValues(alpha: 0.5), height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (!isLunas)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => _navigateToPayment(item),
                          icon: const Icon(Icons.payment_rounded,
                              color: Colors.white, size: 16),
                          label: Text(
                            LanguageService.text(
                                'Lanjutkan Pembayaran', 'Continue Payment'),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showOrderDetailBottomSheet(item),
                        icon: const Icon(Icons.receipt_long_rounded, size: 16),
                        label: Text(
                          LanguageService.text('Lihat Rincian', 'View Details'),
                          style: GoogleFonts.poppins(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textPrimary,
                          side: BorderSide(color: _cardBorder),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (_isAdmin) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 19),
                      color: AppColors.primary,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      tooltip: 'Edit Pesanan',
                      onPressed: () => _showAdminEditOrderDialog(item),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon:
                          const Icon(Icons.delete_outline_rounded, size: 19),
                      color: AppColors.error,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            AppColors.error.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      tooltip: 'Hapus Pesanan',
                      onPressed: () => _showDeleteOrderConfirmation(item),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, {bool isCompact = false}) {
    Color badgeColor = AppColors.success;
    IconData icon = Icons.check_circle_rounded;
    String label = status;

    final lower = status.toLowerCase();
    if (lower.contains('selesai') ||
        lower.contains('success') ||
        lower.contains('settlement') ||
        lower.contains('berhasil')) {
      badgeColor = AppColors.success;
      icon = Icons.check_circle_rounded;
      label = LanguageService.text('Selesai', 'Completed');
    } else if (lower.contains('pending') ||
        lower.contains('menunggu') ||
        lower.contains('unpaid')) {
      badgeColor = AppColors.warning;
      icon = Icons.schedule_rounded;
      label = LanguageService.text('Pending', 'Pending');
    } else if (lower.contains('proses') ||
        lower.contains('diproses') ||
        lower.contains('active')) {
      badgeColor = AppColors.cyan;
      icon = Icons.sync_rounded;
      label = LanguageService.text('Diproses', 'Processing');
    } else if (lower.contains('batal') ||
        lower.contains('cancel') ||
        lower.contains('expire') ||
        lower.contains('deny')) {
      badgeColor = AppColors.error;
      icon = Icons.cancel_rounded;
      label = LanguageService.text('Dibatalkan', 'Cancelled');
    }

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: badgeColor),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            LanguageService.text('Belum Ada Pesanan', 'No Orders Found'),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            LanguageService.text(
              'Pesanan Anda akan tercatat secara otomatis di sini setelah melakukan pembelian layanan.',
              'Your orders will be listed here after you purchase services.',
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProdukPage(isDarkMode: widget.isDarkMode),
                ),
              );
            },
            icon: const Icon(Icons.storefront_rounded, color: Colors.white),
            label: Text(
              LanguageService.text('Mulai Belanja Sekarang', 'Shop Now'),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}
