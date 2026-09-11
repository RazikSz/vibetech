import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetech_xyz/constants/constants.dart';

import '../../database/db_helper.dart';
import '../../services/balance_service.dart';
import '../../services/language_service.dart';
import '../../services/midtrans_direct_payment_service.dart';
import '../../services/notification_service.dart';
import '../../services/qris_service.dart';

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
  String _selectedAuthMethod = 'fingerprint';
  bool _isProcessing = false;
  String _activeEmail = 'user@vibetech.com';

  final Set<String> _finalizedInvoices = {};

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
    if (amount > 20000000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LanguageService.text(
              'Maksimal top up per transaksi adalah Rp 20.000.000',
              'Maximum top up per transaction is Rp 20,000,000',
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

    // Buka Verifikasi Keamanan (Fingerprint & PIN) Sebelum Lanjut Bayar
    _startSecurityAuthAndTopUp(amount, method, invoiceNo);
  }

  void _startSecurityAuthAndTopUp(
      int amount, Map<String, dynamic> method, String invoiceNo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return _TopUpSecurityAuthSheet(
          isDarkMode: widget.isDarkMode,
          totalAmount: amount,
          initialMethod: _selectedAuthMethod,
          userEmail: _activeEmail,
          onVerified: () {
            _showTopUpPaymentBottomSheet(amount, method, invoiceNo);
          },
          onMethodChanged: (newMethod) {
            if (mounted) {
              setState(() => _selectedAuthMethod = newMethod);
            }
          },
        );
      },
    );
  }

  Widget _buildTopUpAuthMethodCard({
    required String id,
    required String name,
    required String desc,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : _textSecondary.withValues(alpha: 0.15),
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
                  color: isSelected
                      ? color
                      : _textSecondary.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
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
                            // QRIS Code View Dinamis
                            Builder(
                              builder: (context) {
                                final dynamicQrisString =
                                    QrisService.createLocalDynamicQris(
                                        nominal: amount);
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.08),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      QrImageView(
                                        data: dynamicQrisString,
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
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(
                                              text: dynamicQrisString));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                LanguageService.text(
                                                  'Kode QRIS berhasil disalin ke clipboard.',
                                                  'QRIS string copied to clipboard.',
                                                ),
                                              ),
                                              backgroundColor:
                                                  const Color(0xFF00AA13),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4, horizontal: 8),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.copy_rounded,
                                                  size: 14,
                                                  color: Color(0xFF00AA13)),
                                              const SizedBox(width: 4),
                                              Text(
                                                LanguageService.text(
                                                    'Salin Kode QRIS',
                                                    'Copy QRIS String'),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      const Color(0xFF00AA13),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(
                              LanguageService.text(
                                'Buka aplikasi e-wallet atau m-Banking Anda, lalu pindai kode QR di atas untuk menyelesaikan deposit. Nominal terisi otomatis.',
                                'Open your e-wallet or m-Banking app, then scan the QR code above to complete deposit. Amount is filled automatically.',
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
                        // Tombol 1: Gateway Midtrans Snap Resmi ATAU Konfirmasi QRIS Dinamis
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: methodId == 'qris'
                                  ? const Color(0xFF00AA13)
                                  : const Color(0xFF002D62),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 3,
                            ),
                            onPressed: _isProcessing
                                ? null
                                : () async {
                                    if (methodId == 'qris') {
                                      Navigator.pop(bottomSheetContext);
                                      await _finalizeTopUpSuccess(
                                        amount,
                                        'QRIS Dinamis',
                                        invoiceNo,
                                      );
                                    } else {
                                      _payWithMidtransGateway(
                                        amount,
                                        methodName,
                                        invoiceNo,
                                        bottomSheetContext,
                                      );
                                    }
                                  },
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : Icon(
                                    methodId == 'qris'
                                        ? Icons.check_circle_rounded
                                        : Icons.payment_rounded,
                                    color: methodId == 'qris'
                                        ? Colors.white
                                        : const Color(0xFF00E5FF),
                                    size: 20),
                            label: Text(
                              methodId == 'qris'
                                  ? LanguageService.text(
                                      'Saya Sudah Transfer via QRIS',
                                      'I Have Paid via QRIS',
                                    )
                                  : LanguageService.text(
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

  Future<void> _payWithMidtransGateway(int amount, String methodName,
      String invoiceNo, BuildContext bottomSheetContext) async {
    setState(() => _isProcessing = true);

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
            'Top Up Saldo VibeWallet sebesar Rp ${NumberFormat("#,##0", "id_ID").format(amount)} via Midtrans ($methodName)',
      });
    } catch (e) {
      debugPrint('[TopUpPage] Error save pending transaction: $e');
    }

    // 2. Inisialisasi Transaksi Direct Payment Midtrans (langsung ke aplikasi target)
    final directResult = await MidtransDirectPaymentService.createDirectPayment(
      orderId: invoiceNo,
      grossAmount: amount,
      paymentMethod: _selectedPaymentMethod,
      customerEmail: _activeEmail,
    );

    setState(() => _isProcessing = false);

    if (directResult.success) {
      if (!mounted) return;
      if (bottomSheetContext.mounted) {
        Navigator.pop(bottomSheetContext);
      }

      // 3. Buka langsung aplikasi target & tampilkan modal status auto-check (TANPA WEBVIEW MIDTRANS)
      final isSuccess = await MidtransDirectPaymentService.showDirectPaymentModal(
        context: context,
        paymentResult: directResult,
        displayName: methodName,
        isDarkMode: widget.isDarkMode,
      );

      if (!mounted) return;

      bool verified = false;
      if (isSuccess == true) {
        verified = true;
      } else {
        verified = await MidtransDirectPaymentService.verifyPaymentStatus(invoiceNo);
      }

      if (verified) {
        await _finalizeTopUpSuccess(amount, 'Midtrans ($methodName)', invoiceNo);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LanguageService.text(
                'Pembayaran belum diverifikasi. Jika Anda sudah mentransfer, saldo akan otomatis masuk saat pembayaran terkonfirmasi.',
                'Payment not yet verified. If you have already transferred, your balance will be credited once confirmed.',
              ),
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppColors.darkCard,
            action: SnackBarAction(
              label: LanguageService.text('Cek Ulang', 'Retry'),
              textColor: AppColors.accent,
              onPressed: () async {
                final recheck = await MidtransDirectPaymentService.verifyPaymentStatus(invoiceNo);
                if (!mounted) return;
                if (recheck) {
                  await _finalizeTopUpSuccess(
                      amount, 'Midtrans ($methodName)', invoiceNo);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        LanguageService.text(
                          'Pembayaran masih berstatus Pending atau belum diterima.',
                          'Payment is still Pending or not received.',
                        ),
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    } else {
      if (bottomSheetContext.mounted) {
        Navigator.pop(bottomSheetContext);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            directResult.errorMessage ??
                LanguageService.text(
                  'Gagal membuka pembayaran langsung ke aplikasi. Pastikan koneksi internet aktif.',
                  'Failed to open direct app payment. Please check internet connection.',
                ),
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _finalizeTopUpSuccess(
      int amount, String methodName, String invoiceNo) async {
    if (_finalizedInvoices.contains(invoiceNo)) {
      debugPrint('[TopUpPage] Invoice $invoiceNo sudah diproses sebelumnya.');
      return;
    }
    _finalizedInvoices.add(invoiceNo);

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
                      subject: 'Bukti Transaksi Top Up Saldo: $invoiceNo',
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
                    side:
                        const BorderSide(color: AppColors.primary, width: 1.2),
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
              child: IgnorePointer(
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

                const SizedBox(height: 24),

                // Metode Verifikasi Keamanan (Dual Mode: Fingerprint & PIN)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      LanguageService.text('Metode Verifikasi Keamanan',
                          'Security Verification Method'),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_user_rounded,
                              size: 13, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            LanguageService.text(
                                '2 Opsi Aktif', '2 Options Active'),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
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
                      child: _buildTopUpAuthMethodCard(
                        id: 'fingerprint',
                        name: LanguageService.text('Sidik Jari', 'Fingerprint'),
                        desc: LanguageService.text(
                            'Biometrik Instan', 'Instant Biometric'),
                        icon: Icons.fingerprint_rounded,
                        color: AppColors.primary,
                        isSelected: _selectedAuthMethod == 'fingerprint',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedAuthMethod = 'fingerprint');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Opsi 2: PIN Transaksi (6 Digit)
                    Expanded(
                      child: _buildTopUpAuthMethodCard(
                        id: 'pin',
                        name: LanguageService.text(
                            'PIN Transaksi', 'Security PIN'),
                        desc: LanguageService.text(
                            '6 Digit Keamanan', '6-Digit Security'),
                        icon: Icons.lock_outline_rounded,
                        color: const Color(0xFF7C4DFF),
                        isSelected: _selectedAuthMethod == 'pin',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedAuthMethod = 'pin');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _initiateTopUpPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    icon: Icon(
                      _selectedAuthMethod == 'fingerprint'
                          ? Icons.fingerprint_rounded
                          : Icons.lock_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: Text(
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

/// ============================================================================
/// BOTTOM SHEET VERIFIKASI KEAMANAN TOP UP (DUAL MODE: FINGERPRINT & PIN)
/// ============================================================================
class _TopUpSecurityAuthSheet extends StatefulWidget {
  final bool isDarkMode;
  final int totalAmount;
  final String initialMethod; // 'fingerprint' atau 'pin'
  final String userEmail;
  final VoidCallback onVerified;
  final ValueChanged<String>? onMethodChanged;

  const _TopUpSecurityAuthSheet({
    required this.isDarkMode,
    required this.totalAmount,
    required this.initialMethod,
    required this.userEmail,
    required this.onVerified,
    this.onMethodChanged,
  });

  @override
  State<_TopUpSecurityAuthSheet> createState() =>
      _TopUpSecurityAuthSheetState();
}

class _TopUpSecurityAuthSheetState extends State<_TopUpSecurityAuthSheet> {
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
          "LocalAuth TopUp: canCheck=$canCheck, isSupported=$isDeviceSupported, biometrics=$biometrics");

      if (canCheck || isDeviceSupported || biometrics.isNotEmpty) {
        isAuthenticated = await _auth.authenticate(
          localizedReason: LanguageService.text(
            'Konfirmasi Sidik Jari untuk Top Up Saldo ${_currencyFormatter.format(widget.totalAmount)}',
            'Confirm Fingerprint for Top Up ${_currencyFormatter.format(widget.totalAmount)}',
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
      debugPrint("LocalAuth TopUp error: $e");
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
    final sheetBg = isDark ? AppColors.darkCard : Colors.white;
    final cardInnerBg =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
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
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.security_rounded,
                          color: AppColors.primary,
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
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            '${LanguageService.text('Nominal Top Up', 'Top Up Amount')}: ${_currencyFormatter.format(widget.totalAmount)}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
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
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _currentMethod == 'fingerprint'
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary
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
                                style: GoogleFonts.poppins(
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
                                style: GoogleFonts.poppins(
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
                GestureDetector(
                  onTap: _triggerBiometricAuth,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.12),
                      border: Border.all(
                        color: _isBiometricScanning
                            ? AppColors.primary
                            : (_isBiometricError
                                ? Colors.orange
                                : AppColors.primary.withValues(alpha: 0.5)),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
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
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(
                              Icons.fingerprint_rounded,
                              size: 64,
                              color: AppColors.primary,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  LanguageService.text(
                      'Pindai Sidik Jari Anda', 'Scan Your Fingerprint'),
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  LanguageService.text(
                    'Letakkan sidik jari pada sensor biometrik untuk memverifikasi top up saldo VibeWallet Anda.',
                    'Place your fingerprint on the biometric sensor to verify your VibeWallet top up.',
                  ),
                  textAlign: TextAlign.center,
                  style:
                      GoogleFonts.poppins(fontSize: 13, color: textSecondary),
                ),
                if (_biometricStatusMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isBiometricError
                          ? Colors.orange.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isBiometricError
                            ? Colors.orange.withValues(alpha: 0.4)
                            : AppColors.primary.withValues(alpha: 0.4),
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
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _biometricStatusMessage!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isBiometricError
                                  ? Colors.orangeAccent
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Tombol Pindai Ulang
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
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7C4DFF),
                    ),
                  ),
                ),
              ],

              // ==================== VIEW METODE PIN 6 DIGIT ====================
              if (_currentMethod == 'pin') ...[
                Text(
                  LanguageService.text('Masukkan PIN Transaksi 6-Digit',
                      'Enter 6-Digit Transaction PIN'),
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  LanguageService.text(
                    'Ketikkan 6-digit kode PIN keamanan akun Anda untuk konfirmasi top up saldo.',
                    'Enter your 6-digit security PIN to confirm balance top up.',
                  ),
                  textAlign: TextAlign.center,
                  style:
                      GoogleFonts.poppins(fontSize: 13, color: textSecondary),
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
                        style: GoogleFonts.spaceMono(
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
                        style: GoogleFonts.poppins(
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
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: textSecondary),
                      ),
                    ),
                    Text(
                      LanguageService.text(
                          'PIN Bawaan: 123456', 'Default PIN: 123456'),
                      style: GoogleFonts.poppins(
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
                      LanguageService.text('Verifikasi PIN & Lanjut Bayar',
                          'Verify PIN & Proceed to Pay'),
                      style: GoogleFonts.poppins(
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
                      size: 16, color: AppColors.primary),
                  label: Text(
                    LanguageService.text('Gunakan Sidik Jari (Fingerprint)',
                        'Use Fingerprint (Biometric)'),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
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
}
