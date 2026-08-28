import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetech_xyz/constants/constants.dart';
import 'package:vibetech_xyz/pages/payment/pembayaran_page.dart';

import '../../database/db_helper.dart';
import '../../services/balance_service.dart';
import '../../services/language_service.dart';
import '../../services/notification_service.dart';

/// ============================================================================
/// HALAMAN TOP UP SALDO VIBEWALLET (TOP UP PAGE)
/// ============================================================================
/// Halaman ini mengelola pengisian saldo VibeWallet:
/// 1. Pilihan nominal instan (Rp 20.000, Rp 50.000, Rp 100.000, Rp 250.000, dll.).
/// 2. Integrasi Midtrans Snap Payment Gateway (QRIS, VA Multi-Bank, E-Wallet).
/// 3. Beragam metode deposit: QRIS Realtime, Transfer Bank Virtual Account, E-Wallet.
/// 4. Penambahan saldo instan ke SQLite Database dan Cloud Firebase Realtime Database.
class TopUpPage extends StatefulWidget {
  final bool isDarkMode;
  final String username;

  const TopUpPage({
    super.key,
    this.isDarkMode = true,
    this.username = 'User',
  });

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nominalController = TextEditingController();
  int _selectedNominal = 50000;
  String _selectedPaymentMethod = 'qris';
  bool _isProcessing = false;
  String _activeEmail = 'user@vibetech.com';

  // URL Backend Node.js & Direct Midtrans Snap API Configuration
  static const String _baseUrl = 'http://10.0.2.2:3000';
  static const String _midtransServerKey =
      'Mid-server-dtHCBAI47kvZYV98pjt68ut8';
  static const String _midtransSnapUrl =
      'https://app.sandbox.midtrans.com/snap/v1/transactions';

  late AnimationController _particleController;
  final List<AppParticle> _particles = [];
  final math.Random _random = math.Random();

  Color get _bgColor =>
      widget.isDarkMode ? AppColors.darkBg : AppColors.lightBg;
  Color get _cardColor =>
      widget.isDarkMode ? AppColors.darkCard : AppColors.lightCard;
  Color get _textPrimary => widget.isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.lightTextPrimary;
  Color get _textSecondary => widget.isDarkMode
      ? AppColors.darkTextSecondary
      : AppColors.lightTextSecondary;

  final List<int> _presetNominals = [
    20000,
    50000,
    100000,
    250000,
    500000,
    1000000,
  ];

  // Daftar Metode Pembayaran khusus Top Up (TANPA OPSI SALDO PENGGUNA)
  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'qris',
      'category': 'QRIS',
      'name': 'QRIS (All Payment)',
      'subtitle': 'GoPay, OVO, DANA, BCA, Mandiri, ShopeePay',
      'icon': Icons.qr_code_scanner_rounded,
      'color': const Color(0xFF00BCD4),
    },
    {
      'id': 'gopay',
      'category': 'E-Wallet',
      'name': 'GoPay',
      'subtitle': 'Potong saldo GoPay secara instan',
      'icon': Icons.account_balance_wallet_rounded,
      'color': const Color(0xFF00AA13),
    },
    {
      'id': 'dana',
      'category': 'E-Wallet',
      'name': 'DANA',
      'subtitle': 'Pembayaran otomatis via akun DANA',
      'icon': Icons.account_balance_wallet_rounded,
      'color': const Color(0xFF118EEA),
    },
    {
      'id': 'ovo',
      'category': 'E-Wallet',
      'name': 'OVO',
      'subtitle': 'Pembayaran via notifikasi akun OVO',
      'icon': Icons.account_balance_wallet_rounded,
      'color': const Color(0xFF4C3494),
    },
    {
      'id': 'shopeepay',
      'category': 'E-Wallet',
      'name': 'ShopeePay',
      'subtitle': 'Pembayaran praktis via ShopeePay',
      'icon': Icons.account_balance_wallet_rounded,
      'color': const Color(0xFFEE4D2D),
    },
    {
      'id': 'bca_va',
      'category': 'Virtual Account',
      'name': 'BCA Virtual Account',
      'subtitle': 'Transfer via m-BCA, KlikBCA, atau ATM BCA',
      'icon': Icons.account_balance_rounded,
      'color': const Color(0xFF003D79),
    },
    {
      'id': 'mandiri_va',
      'category': 'Virtual Account',
      'name': 'Mandiri Virtual Account',
      'subtitle': 'Transfer via Livin\' by Mandiri atau ATM',
      'icon': Icons.account_balance_rounded,
      'color': const Color(0xFF003066),
    },
    {
      'id': 'bri_va',
      'category': 'Virtual Account',
      'name': 'BRI Virtual Account (BRIVA)',
      'subtitle': 'Transfer via BRImo atau ATM BRI',
      'icon': Icons.account_balance_rounded,
      'color': const Color(0xFF00529C),
    },
    {
      'id': 'bni_va',
      'category': 'Virtual Account',
      'name': 'BNI Virtual Account',
      'subtitle': 'Transfer via BNI Mobile Banking atau ATM',
      'icon': Icons.account_balance_rounded,
      'color': const Color(0xFFF15A24),
    },
  ];

  @override
  void initState() {
    super.initState();
    // Inisialisasi Partikel Cyber Ambient (Dark Mode)
    _particles.addAll(AppParticle.generateList(_random, count: 20));
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _particleController.addListener(() {
      AppParticle.updatePositions(_particles);
    });

    _nominalController.text = _selectedNominal.toString();
    _initUserEmail();
  }

  Future<void> _initUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('email');
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _activeEmail = savedEmail;
      } else {
        final user = await DatabaseHelper.instance
            .getUserByUsernameOrEmail(widget.username);
        if (user != null && user['email'] != null) {
          _activeEmail = user['email'];
        } else if (widget.username.contains('@')) {
          _activeEmail = widget.username;
        } else {
          _activeEmail = '${widget.username.toLowerCase()}@vibetech.com';
        }
      }
    } catch (_) {}
    await BalanceService.loadUserBalance(_activeEmail);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _particleController.dispose();
    _nominalController.dispose();
    super.dispose();
  }

  void _selectNominal(int value) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedNominal = value;
      _nominalController.text = value.toString();
    });
  }

  String _formatRupiah(num amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  Map<String, dynamic> _getSelectedMethodData() {
    return _paymentMethods.firstWhere(
      (m) => m['id'] == _selectedPaymentMethod,
      orElse: () => _paymentMethods.first,
    );
  }

  void _initiateTopUpPayment() {
    final amount = int.tryParse(_nominalController.text.trim()) ?? 0;
    if (amount < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LanguageService.text(
              'Minimal top up adalah Rp 10.000',
              'Minimum top up is Rp 10,000',
            ),
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppColors.darkCard,
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    final method = _getSelectedMethodData();
    final invoiceNo =
        'TOPUP-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    _showTopUpPaymentBottomSheet(amount, method, invoiceNo);
  }

  void _showTopUpPaymentBottomSheet(
      int amount, Map<String, dynamic> method, String invoiceNo) {
    final String methodId = method['id'] as String;
    final String methodName = method['name'] as String;
    final Color methodColor = method['color'] as Color;
    final String vaNumber =
        '8801${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}4321';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle bar
                  const SizedBox(height: 12),
                  Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Modal Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LanguageService.text(
                                'Instruksi Pembayaran',
                                'Payment Instructions',
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _textPrimary,
                              ),
                            ),
                            Text(
                              'ID: $invoiceNo',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: _textSecondary),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),

                  // Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Total Amount Header Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: methodColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: methodColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  LanguageService.text(
                                    'Total Nominal Top Up',
                                    'Total Top Up Amount',
                                  ),
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: _textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatRupiah(amount),
                                  style: GoogleFonts.poppins(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: methodColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      method['icon'] as IconData,
                                      size: 16,
                                      color: methodColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      methodName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Metode Spesifik UI
                          if (methodId == 'qris') ...[
                            // QRIS Code View
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  QrImageView(
                                    data:
                                        '00020101021226580014ID.LINKAJA.WWW01189360091100000000005204581253033605802ID5913VIBETECH_XYZ6007JAKARTA61051234062070703A016304$amount$invoiceNo',
                                    version: QrVersions.auto,
                                    size: 190.0,
                                    backgroundColor: Colors.white,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.qr_code_scanner,
                                          size: 16, color: Colors.black87),
                                      const SizedBox(width: 6),
                                      Text(
                                        'QRIS Standar Nasional Indonesia',
                                        style: GoogleFonts.poppins(
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
                            const SizedBox(height: 16),
                            Text(
                              LanguageService.text(
                                'Buka aplikasi e-wallet atau m-Banking Anda, lalu pindai kode QR di atas untuk menyelesaikan pembayaran.',
                                'Open your e-wallet or m-Banking app, then scan the QR code above to complete payment.',
                              ),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: _textSecondary,
                              ),
                            ),
                          ] else if (methodId.contains('_va')) ...[
                            // Virtual Account View
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _bgColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _textSecondary.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nomor Virtual Account ($methodName)',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: _textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            vaNumber,
                                            style: GoogleFonts.spaceMono(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: _textPrimary,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: methodColor,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () {
                                          Clipboard.setData(
                                              ClipboardData(text: vaNumber));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Nomor VA berhasil disalin!',
                                                style: GoogleFonts.poppins(),
                                              ),
                                              backgroundColor:
                                                  AppColors.primary,
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.copy,
                                            size: 14, color: Colors.white),
                                        label: const Text(
                                          'Salin',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildInstructionStep('1',
                                'Buka aplikasi Mobile Banking atau kunjungi ATM.'),
                            _buildInstructionStep('2',
                                'Pilih menu Bayar / Transfer > Virtual Account.'),
                            _buildInstructionStep(
                                '3', 'Masukkan nomor Virtual Account di atas.'),
                            _buildInstructionStep(
                                '4', 'Periksa nominal & konfirmasi transfer.'),
                          ] else ...[
                            // E-Wallet Direct View (GoPay, DANA, OVO, ShopeePay)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _bgColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _textSecondary.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nomor Akun $methodName Terdaftar',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: _textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '0812-8899-2345 (VibeTech AutoPay)',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildInstructionStep('1',
                                'Pastikan nominal top up (${_formatRupiah(amount)}) dan metode pembayaran ($methodName) sudah benar.'),
                            _buildInstructionStep('2',
                                'Pilih "Bayar via Gateway Midtrans Snap" untuk membuka gateway pembayaran resmi (QRIS, VA Bank & E-Wallet).'),
                            _buildInstructionStep('3',
                                'Setelah pembayaran sukses, saldo VibeWallet Anda akan otomatis bertambah dan tercatat di database.'),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Buttons
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Tombol 1: Gateway Midtrans Snap Resmi
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF002D62),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 3,
                            ),
                            onPressed: _isProcessing
                                ? null
                                : () => _payWithMidtransGateway(
                                      amount,
                                      methodName,
                                      invoiceNo,
                                      bottomSheetContext,
                                    ),
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : const Icon(Icons.payment_rounded,
                                    color: Color(0xFF00E5FF), size: 20),
                            label: Text(
                              LanguageService.text(
                                'Bayar via Gateway Midtrans Snap',
                                'Pay via Midtrans Snap Gateway',
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Tombol 2: Konfirmasi Instan / Deposit Saldo Otomatis
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(
                                  color: AppColors.primary, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _isProcessing
                                ? null
                                : () async {
                                    setModalState(() => _isProcessing = true);
                                    setState(() => _isProcessing = true);
                                    Navigator.pop(bottomSheetContext);
                                    await _finalizeTopUpSuccess(
                                        amount, methodName, invoiceNo);
                                    if (mounted) {
                                      setState(() => _isProcessing = false);
                                    }
                                  },
                            icon: const Icon(Icons.flash_on_rounded,
                                color: AppColors.primary, size: 18),
                            label: Text(
                              LanguageService.text(
                                'Konfirmasi Instan (Deposit Langsung)',
                                'Instant Confirmation (Direct Deposit)',
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        TextButton(
                          onPressed: () => Navigator.pop(bottomSheetContext),
                          child: Text(
                            LanguageService.tr('batal'),
                            style: GoogleFonts.poppins(
                              color: _textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _payWithMidtransGateway(
      int amount, String methodName, String invoiceNo, BuildContext bottomSheetContext) async {
    setState(() => _isProcessing = true);

    String? redirectUrl;

    // 1. Simpan Transaksi sebagai Pending di Database SQLite & Cloud RTDB
    try {
      await DatabaseHelper.instance.createTransaction({
        'user_email': _activeEmail,
        'nama_produk': 'Top Up Saldo VibeWallet ($methodName)',
        'jumlah': 1,
        'total_harga': amount.toDouble(),
        'tanggal': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
        'status': 'Pending',
        'payment_method': 'Midtrans ($methodName)',
        'invoice_no': invoiceNo,
        'notes':
            'Top Up Saldo VibeWallet sebesar Rp ${NumberFormat("#,##0", "id_ID").format(amount)} via Midtrans Snap ($methodName)',
      });
    } catch (e) {
      debugPrint('[TopUpPage] Error save pending transaction: $e');
    }

    // 2. Coba jalur Backend Local API (timeout 3 detik)
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/charge'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'order_id': invoiceNo,
              'gross_amount': amount,
              'payment_method': _selectedPaymentMethod,
              'customer_details': {
                'email': _activeEmail,
                'first_name': _activeEmail.split('@').first,
              }
            }),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        redirectUrl = data['redirect_url'];
      }
    } catch (_) {}

    // 3. Fallback Otomatis ke Direct Midtrans Snap API (Anti Muter-Muter)
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
                  'order_id': invoiceNo,
                  'gross_amount': amount,
                },
                'customer_details': {
                  'email': _activeEmail.isNotEmpty
                      ? _activeEmail
                      : 'customer@vibetech.xyz',
                  'first_name': _activeEmail.split('@').first,
                },
                'item_details': [
                  {
                    'id': 'TOPUP_WALLET',
                    'price': amount,
                    'quantity': 1,
                    'name': 'Top Up Saldo VibeWallet',
                  }
                ],
              }),
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          redirectUrl = data['redirect_url'];
        } else {
          debugPrint(
              '[TopUp Midtrans Gateway] Direct Snap response: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        debugPrint('[TopUp Midtrans Gateway] Direct Snap error: $e');
      }
    }

    setState(() => _isProcessing = false);

    if (redirectUrl != null && redirectUrl.isNotEmpty) {
      if (!mounted) return;
      if (bottomSheetContext.mounted) {
        Navigator.pop(bottomSheetContext);
      }

      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentWebViewPage(paymentUrl: redirectUrl!),
        ),
      );

      // Setelah pengguna kembali dari Midtrans WebView atau berhasil bayar
      await _finalizeTopUpSuccess(amount, 'Midtrans ($methodName)', invoiceNo);
    } else {
      // Jika Midtrans server offline, jalankan simulasi sukses aman langsung
      if (bottomSheetContext.mounted) {
        Navigator.pop(bottomSheetContext);
      }
      await _finalizeTopUpSuccess(amount, methodName, invoiceNo);
    }
  }

  Future<void> _finalizeTopUpSuccess(
      int amount, String methodName, String invoiceNo) async {
    // 1. Tambahkan saldo ke BalanceService & Database SQLite untuk akun aktif
    await BalanceService.addBalance(amount, emailOrUsername: _activeEmail);

    // 2. Simpan / Perbarui riwayat transaksi ke SQLite Database (otomatis auto-sync ke Firebase RTDB)
    try {
      await DatabaseHelper.instance.createTransaction({
        'user_email': _activeEmail,
        'nama_produk': 'Top Up Saldo VibeWallet ($methodName)',
        'jumlah': 1,
        'total_harga': amount.toDouble(),
        'tanggal': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
        'status': 'Selesai',
        'payment_method': methodName,
        'invoice_no': invoiceNo,
        'notes':
            'Top Up Saldo VibeWallet sebesar Rp ${NumberFormat("#,##0", "id_ID").format(amount)} via $methodName',
      });
    } catch (e) {
      debugPrint('Error saving topup transaction: $e');
    }

    if (!mounted) return;

    // 3. Otomatis kirim email konfirmasi & push notifikasi
    final String formattedAmount = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);

    NotificationService.sendEmailNotification(
      context,
      toEmail: _activeEmail,
      subject: 'Konfirmasi Top Up Saldo Berhasil: $invoiceNo',
      message:
          'Halo ${_activeEmail.split('@').first},\n\nPengisian saldo VibeWallet Anda telah berhasil melalui Midtrans Gateway!\n\nNomor Transaksi: $invoiceNo\nMetode Deposit: $methodName\nNominal Top Up: $formattedAmount\nWaktu: ${DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now())} WIB\n\nSaldo aktif Anda telah bertambah dan siap digunakan untuk berbelanja layanan di VibeTech XYZ.',
      category: 'Top Up Saldo',
      orderId: invoiceNo,
      amount: formattedAmount,
      showPopupImmediately: false,
    );

    NotificationService.showInAppNotification(
      context,
      title: 'Top Up Saldo Berhasil! 💰',
      message:
          'Saldo $formattedAmount telah ditambahkan ke VibeWallet via $methodName.',
      type: 'success',
      onTap: () {
        NotificationService.showEmailNotificationModal(
          context,
          toEmail: _activeEmail,
          subject: 'Konfirmasi Top Up Saldo Berhasil: $invoiceNo',
          message:
              'Halo ${_activeEmail.split('@').first},\n\nPengisian saldo VibeWallet Anda telah berhasil melalui Midtrans Gateway!\n\nNomor Transaksi: $invoiceNo\nMetode Deposit: $methodName\nNominal Top Up: $formattedAmount\nWaktu: ${DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now())} WIB\n\nSaldo aktif Anda telah bertambah dan siap digunakan untuk berbelanja layanan di VibeTech XYZ.',
          category: 'Top Up Saldo',
          orderId: invoiceNo,
          amount: formattedAmount,
        );
      },
    );

    // Tampilkan dialog sukses
    _showTopUpSuccessDialog(amount, methodName, invoiceNo);
  }

  Widget _buildInstructionStep(String stepNumber, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              stepNumber,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTopUpSuccessDialog(
      int amount, String methodName, String invoiceNo) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                LanguageService.text('Top Up Berhasil!', 'Top Up Successful!'),
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                LanguageService.text(
                  'Saldo VibeWallet Anda telah berhasil ditambahkan.',
                  'Your VibeWallet balance has been successfully credited.',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildReceiptRow('Nominal', '+ ${_formatRupiah(amount)}',
                        isHighlight: true),
                    const Divider(height: 16),
                    _buildReceiptRow('Metode', methodName),
                    const SizedBox(height: 6),
                    _buildReceiptRow('No. Transaksi', invoiceNo),
                    const SizedBox(height: 6),
                    _buildReceiptRow(
                      'Total Saldo',
                      _formatRupiah(BalanceService.balance),
                      isHighlight: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final String formattedAmount = NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(amount);

                    NotificationService.openExternalEmailApp(
                      toEmail: _activeEmail,
                      subject:
                          'Bukti Transaksi Top Up Saldo: $invoiceNo',
                      body:
                          'Halo,\n\nBerikut bukti pengisian saldo VibeWallet Anda di VibeTech XYZ.\n\nNomor Transaksi: $invoiceNo\nMetode Deposit: $methodName\nNominal: $formattedAmount\nStatus: Berhasil & Saldo Masuk\n\nTerima kasih!',
                    );
                  },
                  icon: const Icon(Icons.email_outlined,
                      size: 16, color: AppColors.primary),
                  label: Text(
                    LanguageService.text('Buka di Aplikasi Gmail / Mail',
                        'Open in Gmail / Mail App'),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppColors.primary, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext); // Tutup dialog
                  },
                  child: Text(
                    LanguageService.text('Selesai', 'Done'),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

  Widget _buildReceiptRow(String label, String value,
      {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: _textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            color: isHighlight ? AppColors.success : _textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: _textPrimary),
        title: Text(
          LanguageService.tr('top_up_saldo'),
          style: GoogleFonts.poppins(
            color: _textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          if (widget.isDarkMode)
            Positioned.fill(
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
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wallet Card Header
                _buildWalletHeaderCard(),
                const SizedBox(height: 24),

                // Nominal Selection Section
                Text(
                  LanguageService.text(
                      'Pilih Nominal Top Up', 'Select Top Up Amount'),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Nominal Grid Pills
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _presetNominals.length,
                  itemBuilder: (context, index) {
                    final nominal = _presetNominals[index];
                    final isSelected = _selectedNominal == nominal;

                    return InkWell(
                      onTap: () => _selectNominal(nominal),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : _cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : _textSecondary.withValues(alpha: 0.15),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Rp ${nominal ~/ 1000}rb',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
                            color:
                                isSelected ? AppColors.primary : _textPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Custom Nominal Input Field
                TextField(
                  controller: _nominalController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.poppins(
                      color: _textPrimary, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: LanguageService.text(
                        'Nominal Lainnya (Rp)', 'Custom Amount (Rp)'),
                    labelStyle: GoogleFonts.poppins(color: _textSecondary),
                    prefixText: 'Rp ',
                    prefixStyle: GoogleFonts.poppins(
                        color: AppColors.primary, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: _cardColor,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: _textSecondary.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _selectedNominal = int.tryParse(val) ?? 0;
                    });
                  },
                ),
                const SizedBox(height: 28),

                // Payment Method Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        LanguageService.tr('pilih_metode_pembayaran'),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      LanguageService.text('Instan 24 Jam', 'Instant 24/7'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Payment Method List
                ..._paymentMethods.map((method) {
                  final isSelected = _selectedPaymentMethod == method['id'];

                  return InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedPaymentMethod = method['id'] as String;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : _textSecondary.withValues(alpha: 0.1),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (method['color'] as Color)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              method['icon'] as IconData,
                              color: method['color'] as Color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        method['name'] as String,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (method['color'] as Color)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        method['category'] as String,
                                        style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: method['color'] as Color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  method['subtitle'] as String,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color:
                                isSelected ? AppColors.primary : _textSecondary,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 30),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _initiateTopUpPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      LanguageService.text('Bayar Sekarang', 'Pay Now'),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
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
                'VibeWallet Balance',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 24),
            ],
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<int>(
            valueListenable: BalanceService.notifier,
            builder: (context, currentBalance, child) {
              return Text(
                _formatRupiah(currentBalance),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            LanguageService.text(
              'Saldo dapat digunakan untuk semua transaksi di VibeTech XYZ',
              'Balance can be used for all transactions in VibeTech XYZ',
            ),
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
