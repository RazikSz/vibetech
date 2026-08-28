import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../database/db_helper.dart';
import '../../services/balance_service.dart';
import '../../services/cart_service.dart';
import '../../services/language_service.dart';
import '../../services/notification_service.dart';
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

  // Status proses transaksi (loading indicator)
  bool _isProcessing = false;

  // Email pengguna aktif untuk pencatatan di database
  String _currentUserEmail = "user@vibetech.com";

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // Instansiasi LocalAuthentication untuk Keamanan Fingerprint / Biometrik
  final LocalAuthentication _auth = LocalAuthentication();

  // URL Backend Node.js & Direct Midtrans Snap API Configuration
  static const String _baseUrl = 'http://10.0.2.2:3000';
  static const String _midtransServerKey = 'Mid-server-dtHCBAI47kvZYV98pjt68ut8';
  static const String _midtransSnapUrl = 'https://app.sandbox.midtrans.com/snap/v1/transactions';
  static const String _midtransStatusUrl = 'https://api.sandbox.midtrans.com/v2';

  // --- STATE KONTROL ALUR PEMBAYARAN & TIMER ---
  bool _hasStartedPayment = false;
  bool _isPaymentCompleted = false;
  Timer? _timer;
  int _remainingSeconds = 1020; // 15 menit
  late String _generatedInvoiceNo;
  int? _currentTransactionDbId;

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
      'name': 'QRIS',
      'icon': Icons.qr_code,
      'color': const Color(0xFF00BCD4),
      'description': 'Scan QR dengan GoPay / e-wallet / mobile banking',
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
  }

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
    await BalanceService.loadUserBalance(_currentUserEmail);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- MODAL DIALOG AUTHENTICATION (FINGERPRINT & PIN) ---
  Future<void> _startSecurityAuthAndPay(
      Color cardBg, Color textPrimary, Color textSecondary) async {
    bool isAuthenticated = false;

    // 1. Coba Otentikasi Biometrik (Fingerprint / Face ID)
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      final List<BiometricType> availableBiometrics =
          await _auth.getAvailableBiometrics();

      debugPrint(
          "LocalAuth: canCheck=$canAuthenticateWithBiometrics, isSupported=$isDeviceSupported, biometrics=$availableBiometrics");

      if (canAuthenticateWithBiometrics ||
          isDeviceSupported ||
          availableBiometrics.isNotEmpty) {
        isAuthenticated = await _auth.authenticate(
          localizedReason: LanguageService.text(
            'Konfirmasi Sidik Jari / Biometrik untuk melanjutkan pembayaran',
            'Confirm Fingerprint / Biometrics to proceed with payment',
          ),
          biometricOnly: true,
        );
      }
    } catch (e) {
      debugPrint("Otentikasi biometrik tidak tersedia/batal: $e");
    }

    // 2. Jika Fingerprint berhasil, langsung jalankan pembayaran
    if (isAuthenticated) {
      _processPayment(cardBg, textPrimary, textSecondary);
      return;
    }

    // 3. Jika Biometrik Gagal / Dibatalkan / Tidak ada, Tampilkan Dialog PIN 6-Digit sebagai Fallback
    if (mounted) {
      _showPinAuthDialog(cardBg, textPrimary, textSecondary);
    }
  }

  // --- DIALOG INPUT PIN SECURITY 6 DIGIT ---
  void _showPinAuthDialog(
      Color cardBg, Color textPrimary, Color textSecondary) {
    final List<TextEditingController> pinControllers =
        List.generate(6, (index) => TextEditingController());
    final List<FocusNode> focusNodes = List.generate(6, (index) => FocusNode());

    final Color pinBoxBg =
        widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.security, color: Color(0xFF00AA13)),
              const SizedBox(width: 8),
              Text(
                LanguageService.text(
                    'Verifikasi PIN Transaksi', 'Transaction PIN Verification'),
                style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                LanguageService.text(
                    'Masukkan 6-digit PIN keamanan Anda untuk mengonfirmasi pembayaran.',
                    'Enter your 6-digit security PIN to confirm payment.'),
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 38,
                    height: 48,
                    child: TextField(
                      controller: pinControllers[index],
                      focusNode: focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      obscureText: true,
                      maxLength: 1,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textPrimary),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: pinBoxBg,
                        counterText: '',
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: widget.isDarkMode
                                  ? textSecondary.withValues(alpha: 0.4)
                                  : const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Color(0xFF00AA13), width: 2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          focusNodes[index - 1].requestFocus();
                        }
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(LanguageService.tr('batal'),
                  style: TextStyle(color: textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00AA13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final pin = pinControllers.map((c) => c.text).join();
                if (pin.length == 6) {
                  // Memverifikasi PIN Transaksi Pengguna langsung ke Database SQLite
                  final isPinValid = await DatabaseHelper.instance
                      .verifyUserPin(_currentUserEmail, pin);
                  if (!isPinValid) {
                    _showErrorSnackBar(LanguageService.text(
                        'PIN Transaksi salah! Silakan coba lagi.',
                        'Incorrect Transaction PIN! Please try again.'));
                    return;
                  }
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  _processPayment(cardBg, textPrimary, textSecondary);
                } else {
                  _showErrorSnackBar(LanguageService.text(
                      'PIN harus terdiri dari 6 digit angka',
                      'PIN must be 6 digits'));
                }
              },
              child: Text(LanguageService.tr('verifikasi'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
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

  void _completePaymentAndShowModal() async {
    _timer?.cancel();
    setState(() {
      _isPaymentCompleted = true;
    });

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

    if (mounted) {
      _showGoPayStyleSuccessModal();
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

  // --- PROSES PEMBAYARAN VIA MIDTRANS / SERVER ---
  Future<void> _processPayment(
      Color cardBg, Color textPrimary, Color textSecondary) async {
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

    setState(() => _isProcessing = true);

    String? redirectUrl;

    // 1. Coba jalur Backend Local API terlebih dahulu (timeout 3 detik)
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/charge'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'order_id': _generatedInvoiceNo,
              'gross_amount': widget.totalAmount,
              'payment_method': _selectedPayment,
              'customer_details': {
                'email': _currentUserEmail,
                'first_name': 'Pelanggan',
              }
            }),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        redirectUrl = data['redirect_url'];
      }
    } catch (_) {}

    // 2. Fallback Otomatis ke Direct Midtrans Snap API (Anti Muter-Muter di HP/Desktop)
    if (redirectUrl == null || redirectUrl.isEmpty) {
      try {
        final authHeader =
            'Basic ${base64Encode(utf8.encode('$_midtransServerKey:'))}';
        final response = await http
            .post(
              Uri.parse(_midtransSnapUrl),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Authorization': authHeader,
              },
              body: jsonEncode({
                'transaction_details': {
                  'order_id': _generatedInvoiceNo,
                  'gross_amount': widget.totalAmount.toInt(),
                },
                'customer_details': {
                  'email': _currentUserEmail.isNotEmpty
                      ? _currentUserEmail
                      : 'customer@vibetech.xyz',
                  'first_name': 'Pelanggan',
                },
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          redirectUrl = data['redirect_url'];
        } else {
          debugPrint(
              '[Midtrans Gateway] Direct Snap response: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        debugPrint('[Midtrans Gateway] Direct Snap error: $e');
      }
    }

    setState(() => _isProcessing = false);

    if (redirectUrl != null && redirectUrl.isNotEmpty) {
      if (!mounted) return;

      // 1. Simpan pesanan otomatis sebagai Pending di Database SQLite & Cloud RTDB
      await _savePendingTransactionInDB();

      if (!_hasStartedPayment) {
        _startTimer();
      }

      if (!mounted) return;

      final isSuccess = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentWebViewPage(paymentUrl: redirectUrl!),
        ),
      );

      if (isSuccess == true) {
        _completePaymentAndShowModal();
      }
    } else {
      _showErrorSnackBar(
          'Gagal membuka halaman pembayaran Midtrans. Pastikan koneksi internet aktif.');
    }
  }

  // --- FUNGSI CEK STATUS PEMBAYARAN REAL-TIME DARI SERVER & MIDTRANS ---
  Future<void> _checkPaymentStatusFromApi() async {
    setState(() => _isProcessing = true);

    String transactionStatus = '';
    String statusCode = '';

    // 1. Coba jalur Backend Local API (timeout 3 detik)
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/status/$_generatedInvoiceNo'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        transactionStatus =
            data['transaction_status']?.toString().toLowerCase() ?? '';
        statusCode = data['status_code']?.toString() ?? '';
      }
    } catch (_) {}

    // 2. Fallback Otomatis ke Direct Midtrans Status API
    if (transactionStatus.isEmpty) {
      try {
        final authHeader =
            'Basic ${base64Encode(utf8.encode('$_midtransServerKey:'))}';
        final response = await http
            .get(
              Uri.parse('$_midtransStatusUrl/$_generatedInvoiceNo/status'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Authorization': authHeader,
              },
            )
            .timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          transactionStatus =
              data['transaction_status']?.toString().toLowerCase() ?? '';
          statusCode = data['status_code']?.toString() ?? '';
        }
      } catch (_) {}
    }

    setState(() => _isProcessing = false);

    if (transactionStatus == 'settlement' ||
        transactionStatus == 'capture' ||
        statusCode == '200') {
      _completePaymentAndShowModal();
    } else if (transactionStatus == 'pending') {
      _showErrorSnackBar(
          'Pembayaran belum diterima. Silakan selesaikan pembayaran terlebih dahulu.');
    } else if (transactionStatus == 'expire' ||
        transactionStatus == 'cancel' ||
        transactionStatus == 'deny') {
      _showErrorSnackBar('Transaksi telah kadaluarsa atau dibatalkan.');
    } else {
      _showErrorSnackBar(
          'Status pembayaran saat ini: ${transactionStatus.isEmpty ? 'Pending (Menunggu Pembayaran)' : transactionStatus}');
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
                      Lottie.network(
                        'https://assets2.lottiefiles.com/packages/lf20_s2lryxtd.json',
                        width: 140,
                        height: 140,
                        repeat: false,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF00AA13),
                            size: 100,
                          );
                        },
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

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC);
    final cardBgColor = isDark ? const Color(0xFF141A29) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final appBarBg = isDark ? const Color(0xFF141A29) : Colors.white;

    return Scaffold(
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
                        OutlinedButton.icon(
                          onPressed:
                              _isProcessing ? null : _checkPaymentStatusFromApi,
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Color(0xFF00AA13)),
                                )
                              : const Icon(Icons.refresh,
                                  color: Color(0xFF00AA13)),
                          label: Text(
                            LanguageService.text('Cek Status Pembayaran',
                                'Check Payment Status'),
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

            // Tombol Utama Keamanan
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () {
                        if (!_hasStartedPayment || !_isPaymentCompleted) {
                          _startSecurityAuthAndPay(
                              cardBgColor, textPrimary, textSecondary);
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
                                : Icons.fingerprint),
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
              future: DatabaseHelper.instance
                  .getTransactionsByUser(_currentUserEmail),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final history = snapshot.data ?? [];
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
                            if (!isSelesai)
                              IconButton(
                                icon: const Icon(Icons.check,
                                    color: Colors.green),
                                tooltip: LanguageService.text(
                                    'Tandai Selesai', 'Mark as Done'),
                                onPressed: () async {
                                  final orderId =
                                      (item['id'] as num?)?.toInt() ?? 0;
                                  if (orderId > 0) {
                                    await DatabaseHelper.instance
                                        .updateTransaction(
                                            orderId, {'status': 'Selesai'});
                                    if (!mounted) return;
                                    setState(() {});
                                  }
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: LanguageService.text(
                                  'Hapus Transaksi', 'Delete Transaction'),
                              onPressed: () async {
                                final orderId =
                                    (item['id'] as num?)?.toInt() ?? 0;
                                if (orderId > 0) {
                                  await DatabaseHelper.instance
                                      .deleteTransaction(orderId);
                                  if (!mounted) return;
                                  setState(() {});
                                }
                              },
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

// --- CLASS WEBVIEW MIDTRANS DETEKSI KETAT ---
class PaymentWebViewPage extends StatefulWidget {
  final String paymentUrl;

  const PaymentWebViewPage({super.key, required this.paymentUrl});

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
            _checkPaymentStatus(url);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
            _checkPaymentStatus(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            _checkPaymentStatus(request.url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _checkPaymentStatus(String url) {
    if (url.contains('status_code=200') ||
        url.contains('transaction_status=settlement') ||
        url.contains('transaction_status=capture') ||
        url.contains('success')) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proses Pembayaran'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
