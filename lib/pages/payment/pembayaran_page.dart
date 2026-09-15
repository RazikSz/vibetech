import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/db_helper.dart';
import '../../services/balance_service.dart';
import '../../services/cart_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/firebase_transaction_service.dart';
import '../../services/language_service.dart';
import '../../services/midtrans_direct_payment_service.dart';
import '../../services/notification_service.dart';
import '../../services/qris_service.dart';
import '../common/data_layanan_page.dart';
import 'billing_page.dart';

/// ============================================================================
/// HALAMAN PEMBAYARAN (CHECKOUT & PAYMENT GATEWAY)
/// ============================================================================
/// Halaman ini menangani seluruh proses transaksi pembelian layanan:
/// 1. Verifikasi Biometrik (Fingerprint / Face ID) dan Fallback PIN 6 Digit.
/// 2. Pembayaran via Saldo VibeWallet (potong saldo instan & otomatis).
/// 3. Pembayaran via Payment Gateway Midtrans (QRIS, GoPay, DANA, Virtual Account).
/// 4. Otomatisasi generate data kredensial layanan (VPS, Panel Hosting, Bot WhatsApp).
/// 5. Pencatatan riwayat transaksi ke SQLite Database dan modal struk ala GoPay.
class PembayaranPage extends StatefulWidget {
  /// Total nominal yang harus dibayar (Rupiah)
  final int totalAmount;

  /// Daftar item produk yang dibeli beserta kuantitas dan spesifikasinya
  final List<Map<String, dynamic>> items;

  /// Mode tema tampilan (Dark Mode / Light Mode)
  final bool isDarkMode;

  /// Email akun pemesan yang sedang aktif
  final String? userEmail;

  /// Nomor Invoice jika melanjutkan pesanan yang sudah ada (Pending)
  final String? invoiceNumber;

  const PembayaranPage({
    super.key,
    required this.totalAmount,
    required this.items,
    this.isDarkMode = true,
    this.userEmail,
    this.invoiceNumber,
  });

  @override
  State<PembayaranPage> createState() => _PembayaranPageState();
}

class _PembayaranPageState extends State<PembayaranPage> {
  // Metode pembayaran terpilih ('saldo', 'qris', 'gopay', 'dana', dll.)
  String _selectedPayment = 'saldo';

  // Metode verifikasi keamanan terpilih ('fingerprint' atau 'pin')
  String _selectedAuthMethod = 'fingerprint';

  // Status proses transaksi (loading indicator)
  bool _isProcessing = false;

  // Email pengguna aktif untuk pencatatan di database
  String _currentUserEmail = "user@vibetech.com";

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // --- STATE KONTROL ALUR PEMBAYARAN & TIMER ---
  bool _hasStartedPayment = false;
  bool _isPaymentCompleted = false;
  Timer? _timer;
  int _remainingSeconds = 1020; // 15 menit
  late String _generatedInvoiceNo;
  int? _currentTransactionDbId;
  QrisDynamicResult? _currentQrisResult;
  MidtransDirectPaymentResult? _lastDirectPaymentResult;

  // Set ID & Invoice transaksi yang telah dihapus untuk optimistic update instan di UI
  final Set<String> _deletedTxKeys = {};
  int _historyReloadKey = 0;

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'saldo',
      'name': 'Saldo VibeWallet',
      'icon': Icons.account_balance_wallet_rounded,
      'color': const Color(0xFF7C4DFF),
      'description': 'Potong saldo VibeWallet otomatis (Instan)',
    },
    {
      'id': 'qris',
      'name': 'QRIS Dinamis',
      'icon': Icons.qr_code_2_rounded,
      'color': const Color(0xFF00BCD4),
      'description': 'Scan QR otomatis sesuai nominal produk (GoPay / DANA / m-Banking)',
    },
    {
      'id': 'gopay',
      'name': 'GoPay',
      'icon': Icons.account_balance_wallet,
      'color': const Color(0xFF00AA13),
      'description': 'Pembayaran menggunakan saldo GoPay',
    },
    {
      'id': 'dana',
      'name': 'DANA',
      'icon': Icons.account_balance_wallet,
      'color': const Color(0xFF007BFF),
      'description': 'Pembayaran menggunakan saldo DANA',
    },
    {
      'id': 'ovo',
      'name': 'OVO',
      'icon': Icons.account_balance_wallet,
      'color': const Color(0xFF5A2D82),
      'description': 'Pembayaran menggunakan saldo OVO',
    },
    {
      'id': 'shopeepay',
      'name': 'ShopeePay',
      'icon': Icons.account_balance_wallet,
      'color': const Color(0xFFEE4D2D),
      'description': 'Pembayaran menggunakan ShopeePay',
    },
    {
      'id': 'transfer',
      'name': 'Transfer Bank',
      'icon': Icons.account_balance,
      'color': const Color(0xFF4CAF50),
      'description': 'Transfer ke rekening BCA/Mandiri/BNI/BRI',
    },
  ];

  @override
  void initState() {
    super.initState();
    _generatedInvoiceNo = (widget.invoiceNumber != null &&
            widget.invoiceNumber!.isNotEmpty)
        ? widget.invoiceNumber!
        : 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(3, 10)}';
    _initUserEmail();

    // Hubungkan streaming listener real-time Firebase RTDB untuk verifikasi pembayaran otomatis
    _txRealtimeListener = () async {
      if (!mounted || _isPaymentCompleted) return;
      try {
        final tx = await DatabaseHelper.instance
            .getTransactionByInvoice(_generatedInvoiceNo);
        if (tx != null) {
          final status = (tx['status'] ?? '').toString().toLowerCase();
          if (status == 'selesai' || status == 'lunas') {
            _completePaymentAndShowModal();
          }
        }
      } catch (_) {}
    };
    CloudSyncService.instance.transactionsNotifier
        .addListener(_txRealtimeListener!);
  }

  VoidCallback? _txRealtimeListener;

  String _currentUserRole = 'user';

  bool get _isAdmin =>
      _currentUserRole == 'admin' ||
      _currentUserRole == 'administrator' ||
      _currentUserEmail.toLowerCase() == 'admin@vibetech.com';

  Future<void> _initUserEmail() async {
    if (widget.userEmail != null && widget.userEmail!.isNotEmpty) {
      if (mounted) setState(() => _currentUserEmail = widget.userEmail!);
    } else {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('email');
      if (savedEmail != null && savedEmail.isNotEmpty) {
        if (mounted) setState(() => _currentUserEmail = savedEmail);
      }
    }
    try {
      final user =
          await DatabaseHelper.instance.getUserByEmail(_currentUserEmail);
      if (user != null && user['role'] != null) {
        _currentUserRole = user['role'].toString().toLowerCase();
      }
    } catch (_) {}
    await BalanceService.loadUserBalance(_currentUserEmail);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_txRealtimeListener != null) {
      CloudSyncService.instance.transactionsNotifier
          .removeListener(_txRealtimeListener!);
    }
    _timer?.cancel();
    super.dispose();
  }

  // --- METODE VERIFIKASI KEAMANAN (FINGERPRINT & PIN DUAL MODE) ---
  void _startSecurityAuthAndPay(
      Color cardBg, Color textPrimary, Color textSecondary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return _PaymentSecurityAuthSheet(
          isDarkMode: widget.isDarkMode,
          totalAmount: widget.totalAmount,
          initialMethod: _selectedAuthMethod,
          userEmail: _currentUserEmail,
          onVerified: () {
            _processPayment(cardBg, textPrimary, textSecondary);
          },
          onMethodChanged: (method) {
            if (mounted) {
              setState(() => _selectedAuthMethod = method);
            }
          },
        );
      },
    );
  }

  Widget _buildAuthMethodCard({
    required String id,
    required String name,
    required String desc,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required Color cardBgColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color:
                      isSelected ? color : textSecondary.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: TextStyle(
                fontSize: 11,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = 1020;
      _hasStartedPayment = true;
      _isPaymentCompleted = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        if (mounted) setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        _checkPaymentStatusFromApi();
      }
    });
  }

  Future<void> _savePendingTransactionInDB() async {
    final String namaProduk = widget.items.isNotEmpty
        ? widget.items
            .map((e) =>
                (e['name'] ?? e['title'] ?? 'Layanan VibeTech').toString())
            .join(', ')
        : 'Pembelian Layanan';
    final int totalQty = widget.items.fold<int>(
        0, (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 1));
    final String notes = widget.items
        .map((e) =>
            '${(e['name'] ?? e['title'] ?? 'Layanan')} x${((e['quantity'] as num?)?.toInt() ?? 1)}')
        .join(', ');
    final String dateFormatted =
        DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    if (_currentTransactionDbId != null && _currentTransactionDbId! > 0) {
      await DatabaseHelper.instance.updateTransaction(_currentTransactionDbId!, {
        'status': 'Pending',
        'payment_method': _getPaymentName(),
        'invoice_no': _generatedInvoiceNo,
      });
      return;
    }

    _currentTransactionDbId = await DatabaseHelper.instance.createTransaction({
      'user_email': _currentUserEmail,
      'nama_produk': namaProduk,
      'jumlah': totalQty,
      'total_harga': widget.totalAmount.toDouble(),
      'tanggal': dateFormatted,
      'status': 'Pending',
      'payment_method': _getPaymentName(),
      'invoice_no': _generatedInvoiceNo,
      'notes': notes,
    });
  }

  void _completePaymentAndShowModal() {
    if (_isPaymentCompleted) return;
    _timer?.cancel();
    setState(() {
      _isPaymentCompleted = true;
    });

    // 🚀 1. LANGSUNG TAMPILKAN POPUP STRUK BERHASIL DENGAN INSTAN (ZERO DELAY)
    if (mounted) {
      _showGoPayStyleSuccessModal();
    }

    // 🚀 2. PROSES PERSISTENSI DATABASE, LAYANAN & NOTIFIKASI DI LATAR BELAKANG
    _persistTransactionAndServices();
  }

  Future<void> _persistTransactionAndServices() async {
    final String namaProduk = widget.items.isNotEmpty
        ? widget.items
            .map((e) =>
                (e['name'] ?? e['title'] ?? 'Layanan VibeTech').toString())
            .join(', ')
        : 'Pembelian Layanan';
    final int totalQty = widget.items.fold<int>(
        0, (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 1));
    final String notes = widget.items
        .map((e) =>
            '${(e['name'] ?? e['title'] ?? 'Layanan')} x${((e['quantity'] as num?)?.toInt() ?? 1)}')
        .join(', ');
    final String dateFormatted =
        DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    try {
      if (_currentTransactionDbId != null) {
        await DatabaseHelper.instance.updateTransaction(
          _currentTransactionDbId!,
          {
            'status': 'Selesai',
            'tanggal': dateFormatted,
            'payment_method': _getPaymentName(),
            'invoice_no': _generatedInvoiceNo,
            'notes': notes,
          },
        );
      } else {
        _currentTransactionDbId =
            await DatabaseHelper.instance.createTransaction({
          'user_email': _currentUserEmail,
          'nama_produk': namaProduk,
          'jumlah': totalQty,
          'total_harga': widget.totalAmount.toDouble(),
          'tanggal': dateFormatted,
          'status': 'Selesai',
          'payment_method': _getPaymentName(),
          'invoice_no': _generatedInvoiceNo,
          'notes': notes,
        });
      }

      // --- OTOMATISASI GENERATE DATA LAYANAN (VPS / PANEL HOSTING / BOT WA) ---
      final now = DateTime.now();
      for (var item in widget.items) {
        final String name =
            (item['name'] ?? item['title'] ?? 'Layanan VibeTech').toString();
        final String type = item['type']?.toString().toLowerCase() ?? '';
        final String nameLower = name.toLowerCase();
        final String specs =
            item['specs']?.toString() ?? 'Standard Specification';
        final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final int qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final String expDate =
            now.add(Duration(days: 30 * (qty > 0 ? qty : 1))).toIso8601String();
        final String todayStr = now.toIso8601String();

        String category = 'VPS';
        String? ipAddress;
        String? port;
        String? username;
        String? password;
        String? serverUrl;
        String? sessionId;
        String? extraData;

        if (nameLower.contains('vps') || type.contains('vps')) {
          category = 'VPS';
          final octet3 = 100 + (now.millisecond % 150);
          final octet4 = 10 + (now.microsecond % 240);
          ipAddress = '103.187.$octet3.$octet4';
          port = '22';
          username = 'root';
          password =
              'VibeVPS#${now.millisecondsSinceEpoch.toString().substring(7)}!';
          extraData = 'OS: Ubuntu 22.04 LTS (SG-01 Node)';
        } else if (nameLower.contains('panel') ||
            nameLower.contains('hosting') ||
            type.contains('panel')) {
          category = 'Panel Hosting';
          port = '8080';
          serverUrl = 'https://panel.vibetech.xyz:8080';
          username = 'vibe_${now.millisecondsSinceEpoch.toString().substring(8)}';
          password =
              'Panel@${now.millisecondsSinceEpoch.toString().substring(7)}';
          extraData = 'Node: Singapore High-Speed (Pterodactyl)';
        } else {
          category = 'Bot WhatsApp';
          sessionId =
              'WA-SESSION-${now.millisecondsSinceEpoch.toString().substring(6)}';
          final pairCode = 1000 + (now.millisecond % 9000);
          extraData = 'PAIR-CODE: VBWA-$pairCode';
          username = _currentUserEmail;
        }

        await DatabaseHelper.instance.createService({
          'user_email': _currentUserEmail,
          'nama_produk':
              '$name #${now.millisecondsSinceEpoch.toString().substring(8)}',
          'kategori': category,
          'harga': price * qty,
          'tanggal_beli': todayStr,
          'tanggal_kadaluarsa': expDate,
          'status': 'Aktif',
          'ip_address': ipAddress,
          'port': port,
          'username': username,
          'password': password,
          'server_url': serverUrl,
          'session_id': sessionId,
          'spesifikasi': specs,
          'extra_data': extraData,
        });
      }

      // Sinkronisasi saldo aktif dari SQLite Database
      await BalanceService.loadUserBalance(_currentUserEmail);

      // --- OTOMATISASI PENGIRIMAN NOTIFIKASI EMAIL & PUSH NOTIFIKASI PEMBELIAN ---
      if (!mounted) return;

      final String userEmailTarget = _currentUserEmail.isNotEmpty
          ? _currentUserEmail
          : 'customer@vibetech.xyz';
      final String formattedPrice = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(widget.totalAmount);

      NotificationService.sendEmailNotification(
        context,
        toEmail: userEmailTarget,
        subject: 'Bukti Pembayaran & Aktivasi Layanan: $_generatedInvoiceNo',
        message:
            'Halo ${userEmailTarget.split('@').first},\n\nTerima kasih telah berbelanja di VibeTech XYZ! Pembayaran pesanan Anda telah berhasil diverifikasi secara instan.\n\nDetail Produk: $namaProduk\nMetode Pembayaran: ${_getPaymentName()}\nNomor Invoice: $_generatedInvoiceNo\nTotal Pembayaran: $formattedPrice\nTanggal: ${DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now())} WIB\n\nLayanan Anda telah otomatis diaktifkan dan dapat dikelola langsung melalui menu Data Layanan di aplikasi.',
        category: 'Invoice & Pembelian',
        orderId: _generatedInvoiceNo,
        amount: formattedPrice,
        showPopupImmediately: false,
      );

      NotificationService.showInAppNotification(
        context,
        title: 'Pembayaran Sukses! 🎉',
        message:
            'Layanan $namaProduk aktif. Ketuk untuk melihat bukti surat invoice $userEmailTarget.',
        type: 'payment',
        onTap: () {
          NotificationService.showEmailNotificationModal(
            context,
            toEmail: userEmailTarget,
            subject: 'Bukti Pembayaran & Aktivasi Layanan: $_generatedInvoiceNo',
            message:
                'Halo ${userEmailTarget.split('@').first},\n\nTerima kasih telah berbelanja di VibeTech XYZ! Pembayaran pesanan Anda telah berhasil diverifikasi secara instan.\n\nDetail Produk: $namaProduk\nMetode Pembayaran: ${_getPaymentName()}\nNomor Invoice: $_generatedInvoiceNo\nTotal Pembayaran: $formattedPrice\nTanggal: ${DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now())} WIB\n\nLayanan Anda telah otomatis diaktifkan dan dapat dikelola langsung melalui menu Data Layanan di aplikasi.',
            category: 'Invoice & Pembelian',
            orderId: _generatedInvoiceNo,
            amount: formattedPrice,
          );
        },
      );
    } catch (e) {
      debugPrint('[PembayaranPage] Error async persisting transaction: $e');
    }
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSecs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSecs';
  }

  void _navigateToBilling() {
    CartService.clear();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => BillingPage(
          invoiceNumber: _generatedInvoiceNo,
          transactionDate: DateTime.now(),
          paymentMethod: _getPaymentName(),
          totalAmount: widget.totalAmount,
          items: widget.items,
          status: _isPaymentCompleted ? 'SUDAH DIBAYAR' : 'MENUNGGU PEMBAYARAN',
          isDarkMode: widget.isDarkMode,
          userEmail: _currentUserEmail,
        ),
      ),
    );
  }

  // --- PROSES PEMBAYARAN (QRIS DINAMIS / SALDO / MIDTRANS FALLBACK) ---
  Future<void> _processPayment(
      Color cardBg, Color textPrimary, Color textSecondary) async {
    if (widget.totalAmount <= 0) {
      _showErrorSnackBar(LanguageService.text(
        'Nominal pembayaran tidak valid.',
        'Invalid payment amount.',
      ));
      return;
    }
    if (_selectedPayment == 'saldo') {
      if (BalanceService.balance < widget.totalAmount) {
        _showErrorSnackBar(LanguageService.text(
          'Saldo VibeWallet Anda tidak mencukupi (${_currencyFormatter.format(BalanceService.balance)}). Silakan Top Up terlebih dahulu.',
          'Insufficient VibeWallet balance (${_currencyFormatter.format(BalanceService.balance)}). Please Top Up first.',
        ));
        return;
      }
      final success = await BalanceService.deductBalance(
          widget.totalAmount.toInt(),
          emailOrUsername: _currentUserEmail);
      if (!success) {
        _showErrorSnackBar(LanguageService.text(
          'Saldo VibeWallet Anda tidak mencukupi. Silakan Top Up terlebih dahulu.',
          'Insufficient VibeWallet balance. Please Top Up first.',
        ));
        return;
      }
      _completePaymentAndShowModal();
      return;
    }

    // --- ALUR QRIS DINAMIS (NEXRAY API - TANPA MIDTRANS) ---
    if (_selectedPayment == 'qris') {
      await _processQrisPayment(cardBg, textPrimary, textSecondary);
      return;
    }

    // Jika pembayaran sudah dimulai dan hasil pembayaran sebelumnya masih aktif untuk metode yang sama,
    // langsung buka kembali modal pembayaran tanpa request ulang ke gateway Midtrans
    if (_hasStartedPayment &&
        _lastDirectPaymentResult != null &&
        _lastDirectPaymentResult!.success &&
        _lastDirectPaymentResult!.paymentMethod == _selectedPayment) {
      final selectedMethodData = _paymentMethods.firstWhere(
        (m) => m['id'] == _selectedPayment,
        orElse: () => {'name': _selectedPayment.toUpperCase()},
      );
      final displayName = selectedMethodData['name']?.toString() ?? 'Pembayaran';

      final isSuccess = await MidtransDirectPaymentService.showDirectPaymentModal(
        context: context,
        paymentResult: _lastDirectPaymentResult!,
        displayName: displayName,
        isDarkMode: widget.isDarkMode,
      );

      bool isPaid = (isSuccess == true);
      if (!isPaid) {
        isPaid = await MidtransDirectPaymentService.verifyPaymentStatus(_lastDirectPaymentResult!.orderId);
      }

      if (isPaid) {
        _completePaymentAndShowModal();
      }
      return;
    }

    setState(() => _isProcessing = true);

    // 1. Inisialisasi transaksi direct payment Midtrans (langsung ke aplikasi target)
    final directResult = await MidtransDirectPaymentService.createDirectPayment(
      orderId: _generatedInvoiceNo,
      grossAmount: widget.totalAmount.toInt(),
      paymentMethod: _selectedPayment,
      customerEmail: _currentUserEmail,
    );

    setState(() => _isProcessing = false);

    if (directResult.success) {
      if (!mounted) return;

      _lastDirectPaymentResult = directResult;
      // Jika order ID disesuaikan oleh auto-recovery gateway (retry suffix), sinkronkan invoice lokal
      if (directResult.orderId != _generatedInvoiceNo) {
        _generatedInvoiceNo = directResult.orderId;
      }

      // 2. Simpan pesanan otomatis sebagai Pending di Database SQLite & Cloud RTDB
      await _savePendingTransactionInDB();

      if (!_hasStartedPayment) {
        _startTimer();
      }

      if (!mounted) return;

      final selectedMethodData = _paymentMethods.firstWhere(
        (m) => m['id'] == _selectedPayment,
        orElse: () => {'name': _selectedPayment.toUpperCase()},
      );
      final displayName = selectedMethodData['name']?.toString() ?? 'Pembayaran';

      // 3. Buka langsung aplikasi target & tampilkan modal status auto-check (TANPA WEBVIEW MIDTRANS)
      final isSuccess = await MidtransDirectPaymentService.showDirectPaymentModal(
        context: context,
        paymentResult: directResult,
        displayName: displayName,
        isDarkMode: widget.isDarkMode,
      );

      bool isPaid = (isSuccess == true);
      if (!isPaid) {
        isPaid = await MidtransDirectPaymentService.verifyPaymentStatus(directResult.orderId);
      }

      if (isPaid) {
        _completePaymentAndShowModal();
      }
    } else {
      _showErrorSnackBar(
        directResult.errorMessage ??
            'Gagal membuka gateway pembayaran langsung. Pastikan koneksi internet aktif.',
      );
    }
  }

  // --- PROSES GENERASI & TAMPILAN QRIS DINAMIS (NEXRAY API) ---
  Future<void> _processQrisPayment(
      Color cardBg, Color textPrimary, Color textSecondary) async {
    setState(() => _isProcessing = true);

    // 1. Simpan pesanan awal sebagai Pending di Database SQLite & Cloud RTDB
    await _savePendingTransactionInDB();

    if (!_hasStartedPayment) {
      _startTimer();
    }

    try {
      final qrisResult = await QrisService.generateDynamicQris(
        nominal: widget.totalAmount.toInt(),
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _currentQrisResult = qrisResult;
        });
        _showDynamicQrisModal(qrisResult, cardBg, textPrimary, textSecondary);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorSnackBar(LanguageService.text(
          'Gagal menghasilkan QRIS Dinamis: $e',
          'Failed to generate Dynamic QRIS: $e',
        ));
      }
    }
  }

  // --- MODAL TAMPILAN QRIS DINAMIS OTOMATIS ---
  void _showDynamicQrisModal(QrisDynamicResult qris, Color cardBg,
      Color textPrimary, Color textSecondary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        final isDark = widget.isDarkMode;
        final sheetBg = isDark ? const Color(0xFF141A29) : Colors.white;
        final surfaceBg =
            isDark ? const Color(0xFF1E283D) : const Color(0xFFF1F5F9);

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
                color: sheetBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header Info
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF00AA13).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.qr_code_2_rounded,
                              color: Color(0xFF00AA13), size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LanguageService.text('QRIS Dinamis Otomatis',
                                    'Official Dynamic QRIS'),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${qris.merchantName} (${qris.merchantCity})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: textSecondary),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Kotak QR Code
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // QR Image
                          QrImageView(
                            data: qris.qrisString,
                            version: QrVersions.auto,
                            size: 200,
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.all(8),
                          ),
                          const SizedBox(height: 8),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified_rounded,
                                  size: 16, color: Color(0xFF00AA13)),
                              SizedBox(width: 6),
                              Text(
                                'QRIS Standar Nasional Indonesia (ASPI / BI)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Detail Tagihan Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              const Color(0xFF00AA13).withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                LanguageService.text(
                                    'Total Nominal:', 'Total Amount:'),
                                style: TextStyle(
                                    color: textSecondary, fontSize: 13),
                              ),
                              Text(
                                _currencyFormatter.format(widget.totalAmount),
                                style: const TextStyle(
                                  color: Color(0xFF00AA13),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'No. Invoice:',
                                style: TextStyle(
                                    color: textSecondary, fontSize: 12),
                              ),
                              Text(
                                _generatedInvoiceNo,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                LanguageService.text(
                                    'Sisa Waktu Bayar:', 'Time Remaining:'),
                                style: TextStyle(
                                    color: textSecondary, fontSize: 12),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.timer_outlined,
                                      size: 14, color: Color(0xFFFFB300)),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatTime(_remainingSeconds),
                                    style: const TextStyle(
                                      color: Color(0xFFFFB300),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00AA13)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    size: 14, color: Color(0xFF00AA13)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    LanguageService.text(
                                      'Nominal otomatis sesuai harga produk. Langsung scan tanpa ketik!',
                                      'Amount is set automatically according to product price. Just scan!',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF00AA13),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tombol Salin Kode QRIS
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: qris.qrisString));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(LanguageService.text(
                                'Kode payload QRIS berhasil disalin ke clipboard.',
                                'QRIS payload copied to clipboard.',
                              )),
                              backgroundColor: const Color(0xFF00AA13),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded,
                            size: 18, color: Color(0xFF00BCD4)),
                        label: Text(
                          LanguageService.text(
                              'Salin Kode QRIS (NMID / String)',
                              'Copy QRIS Payload String'),
                          style: const TextStyle(
                            color: Color(0xFF00BCD4),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF00BCD4), width: 1.2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tombol Saya Sudah Membayar
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(modalContext);
                          _completePaymentAndShowModal();
                        },
                        icon: const Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 20),
                        label: Text(
                          LanguageService.text(
                              'Saya Sudah Membayar', 'I Have Paid'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00AA13),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
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

  // --- FUNGSI CEK STATUS PEMBAYARAN REAL-TIME DARI SERVER & MIDTRANS ---
  Future<void> _checkPaymentStatusFromApi() async {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF141A29) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (_selectedPayment == 'qris') {
      if (_currentQrisResult != null) {
        _showDynamicQrisModal(
            _currentQrisResult!, cardBg, textPrimary, textSecondary);
      } else {
        await _processQrisPayment(cardBg, textPrimary, textSecondary);
      }
      return;
    }

    setState(() => _isProcessing = true);

    final isPaid = await MidtransDirectPaymentService.verifyPaymentStatus(_generatedInvoiceNo);

    setState(() => _isProcessing = false);

    if (isPaid) {
      _completePaymentAndShowModal();
    } else {
      _showErrorSnackBar(
          'Pembayaran belum diterima. Silakan selesaikan pembayaran terlebih dahulu.');
    }
  }

  // --- MODAL STRUK BERHASIL (GOPAY STYLE) ---
  void _showGoPayStyleSuccessModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = widget.isDarkMode;
        final sheetBg = isDark ? const Color(0xFF141A29) : Colors.white;
        final textCol = isDark ? Colors.white : const Color(0xFF1E293B);
        final subTextCol =
            isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00E676).withValues(alpha: 0.15),
                          border: Border.all(
                            color: const Color(0xFF00E676),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E676).withValues(alpha: 0.35),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_rounded,
                            color: Color(0xFF00E676),
                            size: 58,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        LanguageService.text(
                            'Pembayaran Berhasil!', 'Payment Successful!'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textCol,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        LanguageService.text(
                            'Transaksi kamu menggunakan ${_getPaymentName()} telah terverifikasi',
                            'Your transaction using ${_getPaymentName()} has been verified'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: subTextCol, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E2E)
                              : const Color(0xFFF4F5F7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(LanguageService.tr('total_pembayaran'),
                                    style: TextStyle(
                                        color: subTextCol, fontSize: 14)),
                                Text(
                                  _currencyFormatter.format(widget.totalAmount),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00AA13),
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(thickness: 1),
                            ),
                            _buildGoPayReceiptRow(
                                LanguageService.text(
                                    'No. Invoice', 'Invoice No.'),
                                _generatedInvoiceNo,
                                textCol,
                                subTextCol),
                            const SizedBox(height: 10),
                            _buildGoPayReceiptRow(
                                LanguageService.text(
                                    'Metode Bayar', 'Payment Method'),
                                _getPaymentName(),
                                textCol,
                                subTextCol),
                            const SizedBox(height: 10),
                            _buildGoPayReceiptRow(
                                LanguageService.text(
                                    'Waktu Transaksi', 'Transaction Time'),
                                "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} WIB",
                                textCol,
                                subTextCol),
                            const SizedBox(height: 10),
                            _buildGoPayReceiptRow(
                                LanguageService.text('Status', 'Status'),
                                LanguageService.tr('berhasil'),
                                const Color(0xFF00AA13),
                                subTextCol,
                                isBold: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          LanguageService.text(
                              'Rincian Produk', 'Product Details'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textCol,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...widget.items.map(
                        (item) {
                          final String itemName = (item['name'] ??
                                  item['title'] ??
                                  'Layanan VibeTech')
                              .toString();
                          final int itemQty =
                              (item['quantity'] as num?)?.toInt() ?? 1;
                          final double itemPrice =
                              (item['price'] as num?)?.toDouble() ?? 0.0;
                          final int lineTotal = (itemPrice * itemQty).toInt();

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '$itemName (x$itemQty)',
                                    style: TextStyle(
                                        color: subTextCol, fontSize: 13),
                                  ),
                                ),
                                Text(
                                  _currencyFormatter.format(lineTotal),
                                  style: TextStyle(
                                      color: textCol,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              // Tombol Buka Data & Panduan Layanan (Primary)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    CartService.clear();
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DataLayananPage(
                          isDarkMode: widget.isDarkMode,
                          userEmail: _currentUserEmail,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu_book_rounded,
                      color: Colors.white, size: 20),
                  label: Text(
                    LanguageService.text('Buka Data & Panduan Layanan',
                        'Open Services & Guides'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Tombol Lihat Invoice (Secondary)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToBilling();
                  },
                  style: OutlinedButton.styleFrom(
                    side:
                        const BorderSide(color: Color(0xFF00AA13), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    LanguageService.text(
                        'Lihat Invoice & Tagihan', 'View Invoice & Billing'),
                    style: const TextStyle(
                      color: Color(0xFF00AA13),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Tombol Buka di Gmail / Mail
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final String userEmailTarget = _currentUserEmail.isNotEmpty
                        ? _currentUserEmail
                        : 'customer@vibetech.xyz';
                    final String formattedPrice = NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(widget.totalAmount);

                    final String productSummary = widget.items.isNotEmpty
                        ? widget.items
                            .map((e) => (e['name'] ?? e['title'] ?? 'Layanan')
                                .toString())
                            .join(', ')
                        : 'Layanan VibeTech XYZ';

                    NotificationService.openExternalEmailApp(
                      toEmail: userEmailTarget,
                      subject:
                          'Bukti Pembayaran & Aktivasi: $_generatedInvoiceNo',
                      body:
                          'Halo,\n\nBerikut bukti pembayaran pesanan $productSummary di VibeTech XYZ.\n\nNomor Invoice: $_generatedInvoiceNo\nTotal Pembayaran: $formattedPrice\nMetode Bayar: ${_getPaymentName()}\nStatus: Lunas & Aktif\n\nTerima kasih!',
                    );
                  },
                  icon: const Icon(Icons.email_outlined,
                      size: 18, color: Color(0xFF7C4DFF)),
                  label: Text(
                    LanguageService.text('Buka di Aplikasi Gmail / Mail',
                        'Open in Gmail / Mail App'),
                    style: const TextStyle(
                      color: Color(0xFF7C4DFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side:
                        const BorderSide(color: Color(0xFF7C4DFF), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGoPayReceiptRow(
      String label, String value, Color textCol, Color subTextCol,
      {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: subTextCol, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: textCol,
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showDeleteTransactionDialog(Map<String, dynamic> item) {
    final int orderId = int.tryParse(item['id']?.toString() ?? '') ??
        ((item['id'] as num?)?.toInt() ?? 0);
    final String invNo =
        (item['invoice_no'] ?? item['id_ref'] ?? '').toString().trim();
    final String prodName =
        item['nama_produk']?.toString() ?? 'Layanan VibeTech';
    final String userEmail =
        item['user_email']?.toString() ?? _currentUserEmail;
    final isDark = widget.isDarkMode;
    final cardBgColor = isDark ? const Color(0xFF141A29) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: cardBgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                LanguageService.text('Hapus Transaksi?', 'Delete Transaction?'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          LanguageService.text(
            'Apakah Anda yakin ingin menghapus transaksi "${invNo.isNotEmpty ? invNo : (orderId > 0 ? "#$orderId" : prodName)}" ($prodName) secara permanen dari database lokal dan Firebase cloud?',
            'Are you sure you want to permanently delete transaction "${invNo.isNotEmpty ? invNo : (orderId > 0 ? "#$orderId" : prodName)}" ($prodName) from local database and Firebase cloud?',
          ),
          style: TextStyle(color: textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              LanguageService.text('Batal', 'Cancel'),
              style: TextStyle(color: textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              HapticFeedback.heavyImpact();
              Navigator.of(dialogCtx).pop();

              // 1. Optimistic UI update: langsung hilangkan item dari tampilan
              setState(() {
                if (orderId > 0) {
                  _deletedTxKeys.add(orderId.toString());
                  _deletedTxKeys.add('loc_$orderId');
                  _deletedTxKeys.add('TX_$orderId');
                }
                if (invNo.isNotEmpty) {
                  _deletedTxKeys.add(invNo);
                  _deletedTxKeys.add(invNo.replaceAll('INV-', ''));
                  _deletedTxKeys.add('INV-$invNo');
                }
                _historyReloadKey++;
              });

              // 2. Notifikasi snackbar bahwa transaksi sedang/berhasil dihapus
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      LanguageService.text(
                        'Transaksi ${invNo.isNotEmpty ? invNo : (orderId > 0 ? "#$orderId" : prodName)} berhasil dihapus permanen.',
                        'Transaction ${invNo.isNotEmpty ? invNo : (orderId > 0 ? "#$orderId" : prodName)} deleted permanently.',
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }

              // 3. Eksekusi penghapusan di SQLite
              try {
                if (orderId > 0) {
                  await DatabaseHelper.instance
                      .deleteTransaction(orderId, invoiceNo: invNo);
                }
                if (invNo.isNotEmpty) {
                  await DatabaseHelper.instance
                      .deleteTransactionByInvoice(invNo);
                }
              } catch (e) {
                debugPrint(
                    '[PembayaranPage] Error deleting transaction from SQLite: $e');
              }

              // 4. Sinkronkan penghapusan ke Firebase Cloud RTDB & Firestore
              try {
                await FirebaseTransactionService.instance
                    .deleteTransactionFromFirebase(
                  localId: orderId > 0 ? orderId : null,
                  invoiceNo: invNo.isNotEmpty ? invNo : null,
                  namaProduk: prodName,
                  userEmail: userEmail,
                );
              } catch (e) {
                debugPrint(
                    '[PembayaranPage] Firebase delete transaction error: $e');
              }

              // 5. Muat ulang data terbaru
              if (mounted) {
                setState(() {
                  _historyReloadKey++;
                });
              }
            },
            child: Text(
              LanguageService.text('Hapus', 'Delete'),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC);
    final cardBgColor = isDark ? const Color(0xFF141A29) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final appBarBg = isDark ? const Color(0xFF141A29) : Colors.white;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _timer?.cancel();
      },
      child: Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(LanguageService.tr('pembayaran'),
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: appBarBg,
        iconTheme: IconThemeData(color: textPrimary),
        elevation: isDark ? 0 : 0.5,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hasStartedPayment) ...[
              Card(
                color: cardBgColor,
                elevation: isDark ? 4 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(
                    color: _isPaymentCompleted
                        ? const Color(0xFF00AA13)
                        : const Color(0xFFFFB300),
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isPaymentCompleted
                                ? Icons.check_circle
                                : Icons.access_time_filled,
                            color: _isPaymentCompleted
                                ? const Color(0xFF00AA13)
                                : const Color(0xFFFFB300),
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isPaymentCompleted
                                ? LanguageService.text(
                                    'Pembayaran Selesai', 'Payment Complete')
                                : LanguageService.text(
                                    'Menunggu Pembayaran', 'Awaiting Payment'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _isPaymentCompleted
                                  ? const Color(0xFF00AA13)
                                  : const Color(0xFFFFB300),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!_isPaymentCompleted) ...[
                        Text(
                          LanguageService.text(
                              'Selesaikan pembayaran sebelum waktu habis:',
                              'Complete payment before time runs out:'),
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatTime(_remainingSeconds),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_selectedPayment == 'qris') ...[
                              ElevatedButton.icon(
                                onPressed: () {
                                  if (_currentQrisResult != null) {
                                    _showDynamicQrisModal(_currentQrisResult!,
                                        cardBgColor, textPrimary, textSecondary);
                                  } else {
                                    _processQrisPayment(
                                        cardBgColor, textPrimary, textSecondary);
                                  }
                                },
                                icon: const Icon(Icons.qr_code_rounded,
                                    size: 16, color: Colors.white),
                                label: Text(
                                  LanguageService.text(
                                      'Buka QRIS Dinamis', 'Open Dynamic QRIS'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00BCD4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            OutlinedButton.icon(
                              onPressed: _isProcessing
                                  ? null
                                  : _checkPaymentStatusFromApi,
                              icon: _isProcessing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF00AA13)),
                                    )
                                  : const Icon(Icons.refresh,
                                      color: Color(0xFF00AA13)),
                              label: Text(
                                LanguageService.text('Cek Status', 'Check Status'),
                                style: const TextStyle(
                                    color: Color(0xFF00AA13),
                                    fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF00AA13)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          LanguageService.text(
                              'Transaksi Anda telah berhasil diproses!',
                              'Your transaction has been successfully processed!'),
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Ringkasan Pesanan
            Card(
              color: cardBgColor,
              elevation: isDark ? 4 : 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        LanguageService.text(
                            'Ringkasan Pesanan', 'Order Summary'),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary)),
                    const SizedBox(height: 12),
                    ...widget.items.map(
                      (item) {
                        final String itemName = (item['name'] ??
                                item['title'] ??
                                'Layanan VibeTech')
                            .toString();
                        final int itemQty =
                            (item['quantity'] as num?)?.toInt() ?? 1;
                        final double itemPrice =
                            (item['price'] as num?)?.toDouble() ?? 0.0;
                        final int lineTotal = (itemPrice * itemQty).toInt();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '$itemName x$itemQty',
                                  style: TextStyle(
                                      color: textSecondary, fontSize: 13),
                                ),
                              ),
                              Text(
                                _currencyFormatter.format(lineTotal),
                                style:
                                    TextStyle(color: textPrimary, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Divider(
                        color: isDark ? Colors.white24 : Colors.black12,
                        thickness: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(LanguageService.tr('total_pembayaran'),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                                fontSize: 15)),
                        Text(_currencyFormatter.format(widget.totalAmount),
                            style: const TextStyle(
                                color: Color(0xFF00AA13),
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Metode Pembayaran
            Text(LanguageService.tr('pilih_metode_pembayaran'),
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textPrimary)),
            const SizedBox(height: 12),
            ..._paymentMethods.map((method) {
              final isSelected = _selectedPayment == method['id'];
              return GestureDetector(
                onTap: _hasStartedPayment
                    ? null
                    : () => setState(
                        () => _selectedPayment = method['id'] as String),
                child: Card(
                  color: cardBgColor,
                  elevation: isSelected ? (isDark ? 8 : 4) : (isDark ? 2 : 1),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF00AA13)
                              : Colors.transparent,
                          width: 2.5)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: (method['color'] as Color)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(method['icon'] as IconData,
                              color: method['color'] as Color, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(method['name'] as String,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: textPrimary)),
                              const SizedBox(height: 2),
                              Text(method['description'] as String,
                                  style: TextStyle(
                                      color: textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _hasStartedPayment
                              ? null
                              : () => setState(() =>
                                  _selectedPayment = method['id'] as String),
                          child: Icon(
                            _selectedPayment == (method['id'] as String)
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: _selectedPayment == (method['id'] as String)
                                ? const Color(0xFF00AA13)
                                : textSecondary,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),

            // Pilihan Metode Verifikasi Keamanan (Dual Mode: Fingerprint & PIN)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  LanguageService.text('Metode Verifikasi Keamanan',
                      'Security Verification Method'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00AA13).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_rounded,
                          size: 13, color: Color(0xFF00AA13)),
                      const SizedBox(width: 4),
                      Text(
                        LanguageService.text(
                            '2 Opsi Aktif', '2 Options Active'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00AA13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Opsi 1: Sidik Jari (Fingerprint)
                Expanded(
                  child: _buildAuthMethodCard(
                    id: 'fingerprint',
                    name: LanguageService.text('Sidik Jari', 'Fingerprint'),
                    desc: LanguageService.text(
                        'Biometrik Instan', 'Instant Biometric'),
                    icon: Icons.fingerprint_rounded,
                    color: const Color(0xFF00AA13),
                    isSelected: _selectedAuthMethod == 'fingerprint',
                    cardBgColor: cardBgColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    isDark: isDark,
                    onTap: () {
                      if (!_hasStartedPayment) {
                        setState(() => _selectedAuthMethod = 'fingerprint');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Opsi 2: PIN Transaksi (6 Digit)
                Expanded(
                  child: _buildAuthMethodCard(
                    id: 'pin',
                    name: LanguageService.text('PIN Transaksi', 'Security PIN'),
                    desc: LanguageService.text(
                        '6 Digit Keamanan', '6-Digit Security'),
                    icon: Icons.lock_outline_rounded,
                    color: const Color(0xFF7C4DFF),
                    isSelected: _selectedAuthMethod == 'pin',
                    cardBgColor: cardBgColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    isDark: isDark,
                    onTap: () {
                      if (!_hasStartedPayment) {
                        setState(() => _selectedAuthMethod = 'pin');
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tombol Utama Keamanan
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () {
                        if (!_hasStartedPayment || !_isPaymentCompleted) {
                          if (_hasStartedPayment && !_isPaymentCompleted) {
                            _processPayment(
                                cardBgColor, textPrimary, textSecondary);
                          } else {
                            _startSecurityAuthAndPay(
                                cardBgColor, textPrimary, textSecondary);
                          }
                        } else {
                          _navigateToBilling();
                        }
                      },
                icon: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Icon(
                        _isPaymentCompleted
                            ? Icons.receipt_long
                            : (_hasStartedPayment
                                ? Icons.payment
                                : (_selectedAuthMethod == 'fingerprint'
                                    ? Icons.fingerprint
                                    : Icons.lock_outline_rounded)),
                        color: Colors.white,
                      ),
                label: Text(
                  _isProcessing
                      ? LanguageService.text(
                          'Memproses Pembayaran...', 'Processing Payment...')
                      : (!_hasStartedPayment
                          ? '${LanguageService.text('Bayar', 'Pay')} ${_currencyFormatter.format(widget.totalAmount)}'
                          : (!_isPaymentCompleted
                              ? LanguageService.text(
                                  'Lanjutkan Pembayaran', 'Continue Payment')
                              : LanguageService.text(
                                  'Lihat Invoice', 'View Invoice'))),
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00AA13),
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15))),
              ),
            ),
            const SizedBox(height: 30),

            // Riwayat Transaksi
            Text(
                LanguageService.text(
                    'Riwayat Transaksi', 'Transaction History'),
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textPrimary)),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(_historyReloadKey),
              future: DatabaseHelper.instance
                  .getTransactionsByUser(_currentUserEmail),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                final rawHistory = snapshot.data ?? [];
                final history = rawHistory.where((item) {
                  final idStr = item['id']?.toString() ?? '';
                  final inv = (item['invoice_no'] ?? item['id_ref'] ?? '')
                      .toString()
                      .trim();
                  if (_deletedTxKeys.contains(idStr) ||
                      _deletedTxKeys.contains('loc_$idStr') ||
                      _deletedTxKeys.contains('TX_$idStr') ||
                      _deletedTxKeys.contains(inv) ||
                      _deletedTxKeys.contains(inv.replaceAll('INV-', '')) ||
                      _deletedTxKeys.contains('INV-$inv')) {
                    return false;
                  }
                  return true;
                }).toList();

                if (history.isEmpty) {
                  return Text(
                      LanguageService.text('Belum ada riwayat transaksi.',
                          'No transaction history yet.'),
                      style: TextStyle(color: textSecondary));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final isSelesai = item['status'] == 'Selesai';

                    return Card(
                      color: cardBgColor,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(item['nama_produk']?.toString() ?? '',
                            style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            "Total: ${_currencyFormatter.format((item['total_harga'] as num?)?.toInt() ?? 0)} | Status: ${item['status'] ?? 'Selesai'}",
                            style: TextStyle(color: textSecondary)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isSelesai && _isAdmin)
                              IconButton(
                                icon: const Icon(Icons.check,
                                    color: Colors.green),
                                tooltip: LanguageService.text(
                                    'Tandai Selesai (Admin)',
                                    'Mark as Done (Admin)'),
                                onPressed: () async {
                                  final orderId = int.tryParse(
                                          item['id']?.toString() ?? '') ??
                                      ((item['id'] as num?)?.toInt() ?? 0);
                                  final invNo = (item['invoice_no'] ??
                                          item['id_ref'] ??
                                          '')
                                      .toString()
                                      .trim();
                                  if (orderId > 0) {
                                    await DatabaseHelper.instance
                                        .updateTransaction(
                                            orderId, {'status': 'Selesai'});
                                  }
                                  if (invNo.isNotEmpty) {
                                    try {
                                      final db = await DatabaseHelper
                                          .instance.database;
                                      await db.update(
                                        'transactions',
                                        {'status': 'Selesai'},
                                        where:
                                            'invoice_no = ? OR invoice_no = ?',
                                        whereArgs: [
                                          invNo,
                                          invNo.replaceAll('INV-', '')
                                        ],
                                      );
                                    } catch (_) {}
                                  }
                                  try {
                                    await FirebaseTransactionService.instance
                                        .updateTransactionInFirebase(
                                      localId:
                                          orderId > 0 ? orderId : null,
                                      invoiceNo: invNo,
                                      updatedData: {'status': 'Selesai'},
                                    );
                                  } catch (_) {}
                                  if (!mounted) return;
                                  setState(() {
                                    _historyReloadKey++;
                                  });
                                },
                              ),
                            if (_isAdmin)
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red),
                                tooltip: LanguageService.text(
                                    'Hapus Transaksi',
                                    'Delete Transaction'),
                                onPressed: () =>
                                    _showDeleteTransactionDialog(item),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  );
}

  String _getPaymentName() {
    switch (_selectedPayment) {
      case 'saldo':
        return 'Saldo VibeWallet';
      case 'gopay':
        return 'GoPay';
      case 'dana':
        return 'DANA';
      case 'ovo':
        return 'OVO';
      case 'shopeepay':
        return 'ShopeePay';
      case 'qris':
        return 'QRIS';
      case 'transfer':
        return 'Transfer Bank';
      default:
        return 'Metode Pembayaran';
    }
  }
}

/// ============================================================================
/// BOTTOM SHEET VERIFIKASI KEAMANAN (DUAL MODE: FINGERPRINT & PIN 6 DIGIT)
/// ============================================================================
class _PaymentSecurityAuthSheet extends StatefulWidget {
  final bool isDarkMode;
  final int totalAmount;
  final String initialMethod; // 'fingerprint' atau 'pin'
  final String userEmail;
  final VoidCallback onVerified;
  final ValueChanged<String>? onMethodChanged;

  const _PaymentSecurityAuthSheet({
    required this.isDarkMode,
    required this.totalAmount,
    required this.initialMethod,
    required this.userEmail,
    required this.onVerified,
    this.onMethodChanged,
  });

  @override
  State<_PaymentSecurityAuthSheet> createState() =>
      _PaymentSecurityAuthSheetState();
}

class _PaymentSecurityAuthSheetState extends State<_PaymentSecurityAuthSheet> {
  late String _currentMethod;
  final LocalAuthentication _auth = LocalAuthentication();

  // State Biometrik
  bool _isBiometricScanning = false;
  String? _biometricStatusMessage;
  bool _isBiometricError = false;

  // State PIN
  final List<TextEditingController> _pinControllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _pinFocusNodes =
      List.generate(6, (index) => FocusNode());
  String? _pinErrorMessage;
  bool _isVerifyingPin = false;
  bool _obscurePin = true;

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _currentMethod = widget.initialMethod;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentMethod == 'fingerprint') {
        _triggerBiometricAuth();
      } else {
        if (_pinFocusNodes.isNotEmpty) {
          _pinFocusNodes[0].requestFocus();
        }
      }
    });
  }

  @override
  void dispose() {
    for (var c in _pinControllers) {
      c.dispose();
    }
    for (var f in _pinFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _switchMethod(String method) {
    if (_currentMethod == method) return;
    setState(() {
      _currentMethod = method;
      _pinErrorMessage = null;
      _biometricStatusMessage = null;
      _isBiometricError = false;
    });
    widget.onMethodChanged?.call(method);

    if (method == 'fingerprint') {
      _triggerBiometricAuth();
    } else {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && _pinFocusNodes.isNotEmpty) {
          _pinFocusNodes[0].requestFocus();
        }
      });
    }
  }

  Future<void> _triggerBiometricAuth() async {
    if (_isBiometricScanning) return;

    setState(() {
      _isBiometricScanning = true;
      _isBiometricError = false;
      _biometricStatusMessage = LanguageService.text(
        'Tempelkan sidik jari pada sensor perangkat...',
        'Place your finger on the device sensor...',
      );
    });

    bool isAuthenticated = false;

    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      final List<BiometricType> biometrics =
          await _auth.getAvailableBiometrics();

      debugPrint(
          "LocalAuth Sheet: canCheck=$canCheck, isSupported=$isDeviceSupported, biometrics=$biometrics");

      if (canCheck || isDeviceSupported || biometrics.isNotEmpty) {
        isAuthenticated = await _auth.authenticate(
          localizedReason: LanguageService.text(
            'Konfirmasi Sidik Jari untuk pembayaran ${_currencyFormatter.format(widget.totalAmount)}',
            'Confirm Fingerprint for payment of ${_currencyFormatter.format(widget.totalAmount)}',
          ),
          biometricOnly: true,
        );
      } else {
        setState(() {
          _isBiometricError = true;
          _biometricStatusMessage = LanguageService.text(
            'Sensor biometrik tidak terdeteksi pada perangkat ini. Silakan gunakan PIN.',
            'Biometric sensor not available on this device. Please use PIN.',
          );
        });
      }
    } catch (e) {
      debugPrint("LocalAuth sheet error: $e");
      setState(() {
        _isBiometricError = true;
        _biometricStatusMessage = LanguageService.text(
          'Autentikasi sidik jari dibatalkan atau tidak tersedia.',
          'Fingerprint authentication cancelled or unavailable.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isBiometricScanning = false);
      }
    }

    if (isAuthenticated && mounted) {
      Navigator.pop(context);
      widget.onVerified();
    }
  }

  Future<void> _verifyPin() async {
    final pin = _pinControllers.map((c) => c.text.trim()).join();

    if (pin.length < 6) {
      setState(() {
        _pinErrorMessage = LanguageService.text(
          'PIN harus terdiri dari 6 digit angka',
          'PIN must be 6 digits',
        );
      });
      return;
    }

    setState(() {
      _isVerifyingPin = true;
      _pinErrorMessage = null;
    });

    try {
      final isPinValid =
          await DatabaseHelper.instance.verifyUserPin(widget.userEmail, pin);

      if (!mounted) return;

      if (isPinValid) {
        Navigator.pop(context);
        widget.onVerified();
      } else {
        setState(() {
          _isVerifyingPin = false;
          _pinErrorMessage = LanguageService.text(
            'PIN Transaksi salah! Silakan coba lagi.',
            'Incorrect Transaction PIN! Please try again.',
          );
        });
        // Reset input pin
        for (var c in _pinControllers) {
          c.clear();
        }
        if (_pinFocusNodes.isNotEmpty) {
          _pinFocusNodes[0].requestFocus();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingPin = false;
          _pinErrorMessage = 'Terjadi kesalahan validasi PIN: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final sheetBg = isDark ? const Color(0xFF141A29) : Colors.white;
    final cardInnerBg =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final pinBoxBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 150),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 25,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle Bar
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF00AA13).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.security_rounded,
                          color: Color(0xFF00AA13),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LanguageService.text(
                                'Verifikasi Keamanan', 'Security Verification'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            '${LanguageService.text('Total', 'Total')}: ${_currencyFormatter.format(widget.totalAmount)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00AA13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Selector Tab: Sidik Jari vs PIN
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cardInnerBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    // Tab Sidik Jari
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchMethod('fingerprint'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _currentMethod == 'fingerprint'
                                ? const Color(0xFF00AA13)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _currentMethod == 'fingerprint'
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF00AA13)
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.fingerprint_rounded,
                                size: 18,
                                color: _currentMethod == 'fingerprint'
                                    ? Colors.white
                                    : textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                LanguageService.text(
                                    'Sidik Jari', 'Fingerprint'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _currentMethod == 'fingerprint'
                                      ? Colors.white
                                      : textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Tab PIN 6 Digit
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchMethod('pin'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _currentMethod == 'pin'
                                ? const Color(0xFF7C4DFF)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _currentMethod == 'pin'
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF7C4DFF)
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                                color: _currentMethod == 'pin'
                                    ? Colors.white
                                    : textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                LanguageService.text(
                                    'PIN 6-Digit', '6-Digit PIN'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _currentMethod == 'pin'
                                      ? Colors.white
                                      : textSecondary,
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
              const SizedBox(height: 24),

              // ==================== VIEW METODE FINGERPRINT ====================
              if (_currentMethod == 'fingerprint') ...[
                // Lingkaran Scanner Sidik Jari
                GestureDetector(
                  onTap: _triggerBiometricAuth,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00AA13).withValues(alpha: 0.12),
                      border: Border.all(
                        color: _isBiometricScanning
                            ? const Color(0xFF00AA13)
                            : (_isBiometricError
                                ? Colors.orange
                                : const Color(0xFF00AA13)
                                    .withValues(alpha: 0.5)),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00AA13).withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isBiometricScanning
                          ? const SizedBox(
                              width: 50,
                              height: 50,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Color(0xFF00AA13),
                              ),
                            )
                          : const Icon(
                              Icons.fingerprint_rounded,
                              size: 64,
                              color: Color(0xFF00AA13),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  LanguageService.text(
                      'Pindai Sidik Jari Anda', 'Scan Your Fingerprint'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  LanguageService.text(
                    'Letakkan jari Anda pada sensor biometrik untuk mengonfirmasi pembayaran dengan cepat dan aman.',
                    'Place your finger on the biometric sensor to confirm payment quickly and securely.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
                if (_biometricStatusMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isBiometricError
                          ? Colors.orange.withValues(alpha: 0.15)
                          : const Color(0xFF00AA13).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isBiometricError
                            ? Colors.orange.withValues(alpha: 0.4)
                            : const Color(0xFF00AA13).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isBiometricError
                              ? Icons.info_outline_rounded
                              : Icons.fingerprint_rounded,
                          size: 16,
                          color: _isBiometricError
                              ? Colors.orange
                              : const Color(0xFF00AA13),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _biometricStatusMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isBiometricError
                                  ? (_isDarkColor(sheetBg)
                                      ? Colors.orangeAccent
                                      : Colors.orange.shade800)
                                  : const Color(0xFF00AA13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Tombol Pindai Ulang / Konfirmasi Biometrik
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isBiometricScanning ? null : _triggerBiometricAuth,
                    icon: _isBiometricScanning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.fingerprint_rounded,
                            color: Colors.white),
                    label: Text(
                      LanguageService.text(
                          'Pindai Sidik Jari Sekarang', 'Scan Fingerprint Now'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00AA13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Tombol Beralih ke PIN
                TextButton.icon(
                  onPressed: () => _switchMethod('pin'),
                  icon: const Icon(Icons.pin_outlined,
                      size: 16, color: Color(0xFF7C4DFF)),
                  label: Text(
                    LanguageService.text(
                        'Gunakan PIN Transaksi Sebagai Alternatif',
                        'Use Transaction PIN as Alternative'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7C4DFF),
                    ),
                  ),
                ),
              ],

              // ==================== VIEW METODE PIN 6 DIGIT ====================
              if (_currentMethod == 'pin') ...[
                Text(
                  LanguageService.text('Masukkan PIN Transaksi 6-Digit',
                      'Enter 6-Digit Transaction PIN'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  LanguageService.text(
                    'Ketikkan 6-digit kode PIN keamanan akun Anda untuk mengonfirmasi pembayaran.',
                    'Enter your 6-digit security PIN to confirm payment.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
                const SizedBox(height: 20),

                // 6 Kotak Digit PIN
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 44,
                      height: 52,
                      child: TextField(
                        controller: _pinControllers[index],
                        focusNode: _pinFocusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        obscureText: _obscurePin,
                        maxLength: 1,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: pinBoxBg,
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _pinErrorMessage != null
                                  ? Colors.red
                                  : (isDark
                                      ? Colors.white24
                                      : const Color(0xFFCBD5E1)),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _pinErrorMessage != null
                                  ? Colors.red
                                  : const Color(0xFF7C4DFF),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() => _pinErrorMessage = null);
                          if (value.isNotEmpty && index < 5) {
                            _pinFocusNodes[index + 1].requestFocus();
                          } else if (value.isEmpty && index > 0) {
                            _pinFocusNodes[index - 1].requestFocus();
                          } else if (value.isNotEmpty && index == 5) {
                            _verifyPin();
                          }
                        },
                      ),
                    );
                  }),
                ),

                if (_pinErrorMessage != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 16, color: Colors.red),
                      const SizedBox(width: 6),
                      Text(
                        _pinErrorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _obscurePin = !_obscurePin),
                      icon: Icon(
                        _obscurePin
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 16,
                        color: textSecondary,
                      ),
                      label: Text(
                        _obscurePin
                            ? LanguageService.text('Lihat PIN', 'Show PIN')
                            : LanguageService.text(
                                'Sembunyikan PIN', 'Hide PIN'),
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ),
                    Text(
                      LanguageService.text(
                          'PIN Bawaan: 123456', 'Default PIN: 123456'),
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tombol Verifikasi PIN & Bayar
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isVerifyingPin ? null : _verifyPin,
                    icon: _isVerifyingPin
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.lock_open_rounded,
                            color: Colors.white),
                    label: Text(
                      LanguageService.text(
                          'Verifikasi PIN & Bayar', 'Verify PIN & Pay'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Tombol Beralih ke Fingerprint
                TextButton.icon(
                  onPressed: () => _switchMethod('fingerprint'),
                  icon: const Icon(Icons.fingerprint_rounded,
                      size: 16, color: Color(0xFF00AA13)),
                  label: Text(
                    LanguageService.text('Gunakan Sidik Jari (Fingerprint)',
                        'Use Fingerprint (Biometric)'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00AA13),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _isDarkColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
  }
}
