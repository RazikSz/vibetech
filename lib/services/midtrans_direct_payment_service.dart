import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibetech_xyz/services/language_service.dart';
import 'package:vibetech_xyz/utils/security_helper.dart';

/// Hasil transaksi pembayaran langsung (Direct Payment Result)
class MidtransDirectPaymentResult {
  final bool success;
  final String orderId;
  final int grossAmount;
  final String paymentMethod;
  final String? token;
  final String? redirectUrl;
  final String? deeplinkUrl;
  final String? qrCodeUrl;
  final String? qrString;
  final String? vaNumber;
  final String? bank;
  final String? expiryTime;
  final String? errorMessage;
  final Map<String, dynamic>? rawData;

  const MidtransDirectPaymentResult({
    required this.success,
    required this.orderId,
    required this.grossAmount,
    required this.paymentMethod,
    this.token,
    this.redirectUrl,
    this.deeplinkUrl,
    this.qrCodeUrl,
    this.qrString,
    this.vaNumber,
    this.bank,
    this.expiryTime,
    this.errorMessage,
    this.rawData,
  });

  factory MidtransDirectPaymentResult.failed({
    required String orderId,
    required int grossAmount,
    required String paymentMethod,
    required String errorMessage,
  }) {
    return MidtransDirectPaymentResult(
      success: false,
      orderId: orderId,
      grossAmount: grossAmount,
      paymentMethod: paymentMethod,
      errorMessage: errorMessage,
    );
  }
}

/// Service untuk menangani direct deep linking pembayaran Midtrans ke aplikasi target
/// (GoPay, ShopeePay, DANA, BCA, Mandiri, BRI, BNI) tanpa membuka WebView Midtrans.
class MidtransDirectPaymentService {
  static const String _localBaseUrl = 'http://10.0.2.2:3000';
  static final String _serverKey = SecurityHelper.deobfuscate(
      'FzM+dyk/KCw/KHc+LhIZGBsTbm0xLAADDGNiKjAubGIvLmI=');

  static const String _snapUrl =
      'https://app.sandbox.midtrans.com/snap/v1/transactions';
  static const String _statusBaseUrl =
      'https://api.sandbox.midtrans.com/v2';

  /// Memetakan ID metode pembayaran UI ke channel Midtrans resmi
  static String mapPaymentChannel(String methodId) {
    final lower = methodId.toLowerCase().trim();
    if (lower.contains('gopay')) return 'gopay';
    if (lower.contains('shopee')) return 'shopeepay';
    if (lower.contains('dana')) return 'dana';
    if (lower.contains('ovo')) return 'ovo';
    if (lower.contains('bca')) return 'bca_va';
    if (lower.contains('bri')) return 'bri_va';
    if (lower.contains('bni')) return 'bni_va';
    if (lower.contains('mandiri') || lower.contains('echannel')) return 'echannel';
    if (lower.contains('transfer') || lower.contains('va') || lower.contains('bank')) {
      return 'bca_va';
    }
    return 'gopay';
  }

  /// Membuat transaksi pembayaran langsung (Direct Payment Charge)
  /// Mengutamakan endpoint backend lokal; jika offline, otomatis beralih ke Direct Midtrans API
  static Future<MidtransDirectPaymentResult> createDirectPayment({
    required String orderId,
    required int grossAmount,
    required String paymentMethod,
    String? customerEmail,
    String? customerPhone,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final channel = mapPaymentChannel(paymentMethod);

    // Sanitasi email agar memenuhi format RFC/Midtrans dan mencegah error 400
    final String email;
    if (customerEmail != null &&
        customerEmail.isNotEmpty &&
        customerEmail.contains('@') &&
        customerEmail.contains('.')) {
      email = customerEmail.trim();
    } else {
      email = 'customer@vibetech.xyz';
    }

    // 1. Coba lewat backend lokal Node.js terlebih dahulu (timeout 3.5s)
    try {
      final backendRes = await httpClient
          .post(
            Uri.parse('$_localBaseUrl/api/charge'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'order_id': orderId,
              'gross_amount': grossAmount,
              'payment_method': channel,
              'customer_details': {
                'email': email,
                'first_name': email.split('@').first,
                if (customerPhone != null && customerPhone.isNotEmpty)
                  'phone': customerPhone,
              }
            }),
          )
          .timeout(const Duration(milliseconds: 3500));

      if (backendRes.statusCode == 200) {
        final data = jsonDecode(backendRes.body) as Map<String, dynamic>;
        final String effectiveOrderId =
            data['order_id']?.toString() ?? orderId;
        return MidtransDirectPaymentResult(
          success: true,
          orderId: effectiveOrderId,
          grossAmount: grossAmount,
          paymentMethod: paymentMethod,
          token: data['token']?.toString(),
          redirectUrl: data['redirect_url']?.toString(),
          deeplinkUrl: data['deeplink_url']?.toString(),
          qrCodeUrl: data['qr_code_url']?.toString(),
          qrString: data['qr_string']?.toString(),
          vaNumber: data['va_number']?.toString(),
          bank: data['bank']?.toString() ?? channel,
          expiryTime: data['expiry_time']?.toString(),
          rawData: data,
        );
      }
    } catch (e) {
      debugPrint('[MidtransDirectPayment] Backend charge info/fallback: $e');
    }

    // 2. Direct Fallback: Panggil langsung Midtrans Snap API + Snap Pay API
    try {
      final authHeader =
          'Basic ${base64Encode(utf8.encode('$_serverKey:'))}';

      String activeOrderId = orderId;

      // Langkah 2a: Generate Snap Token
      http.Response snapRes = await httpClient
          .post(
            Uri.parse(_snapUrl),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': authHeader,
            },
            body: jsonEncode({
              'transaction_details': {
                'order_id': activeOrderId,
                'gross_amount': grossAmount,
              },
              'customer_details': {
                'email': email,
                'first_name': email.split('@').first,
                if (customerPhone != null && customerPhone.isNotEmpty)
                  'phone': customerPhone,
              },
              'enabled_payments': [channel],
            }),
          )
          .timeout(const Duration(seconds: 8));

      // AUTO-RECOVERY RETRY JIKA MIDTRANS MENGEMBALIKAN 400 (DUPLICATE ORDER ID / CHANNEL FILTER)
      if (snapRes.statusCode == 400) {
        final bodyLower = snapRes.body.toLowerCase();
        debugPrint('[MidtransDirectPayment] 400 Error from Midtrans: ${snapRes.body}');

        // Kasus 1: Duplicate order_id (already taken / sudah digunakan)
        if (bodyLower.contains('order_id') ||
            bodyLower.contains('already been taken') ||
            bodyLower.contains('sudah digunakan')) {
          activeOrderId =
              '$orderId-${DateTime.now().millisecondsSinceEpoch % 100000}';
          debugPrint(
              '[MidtransDirectPayment] Duplicate order ID detected. Auto-recovering with: $activeOrderId');

          snapRes = await httpClient
              .post(
                Uri.parse(_snapUrl),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                  'Authorization': authHeader,
                },
                body: jsonEncode({
                  'transaction_details': {
                    'order_id': activeOrderId,
                    'gross_amount': grossAmount,
                  },
                  'customer_details': {
                    'email': email,
                    'first_name': email.split('@').first,
                    if (customerPhone != null && customerPhone.isNotEmpty)
                      'phone': customerPhone,
                  },
                  'enabled_payments': [channel],
                }),
              )
              .timeout(const Duration(seconds: 8));
        }

        // Kasus 2: Penolakan channel atau enabled_payments
        if (snapRes.statusCode == 400 &&
            (snapRes.body.toLowerCase().contains('enabled_payments') ||
                snapRes.body.toLowerCase().contains('channel'))) {
          activeOrderId =
              '$orderId-${DateTime.now().millisecondsSinceEpoch % 100000}';
          snapRes = await httpClient
              .post(
                Uri.parse(_snapUrl),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                  'Authorization': authHeader,
                },
                body: jsonEncode({
                  'transaction_details': {
                    'order_id': activeOrderId,
                    'gross_amount': grossAmount,
                  },
                  'customer_details': {
                    'email': 'customer@vibetech.xyz',
                    'first_name': 'customer',
                  },
                }),
              )
              .timeout(const Duration(seconds: 8));
        }
      }

      if (snapRes.statusCode != 200 && snapRes.statusCode != 201) {
        String msg =
            'Gagal membuat transaksi di gateway Midtrans (${snapRes.statusCode})';
        try {
          final errJson = jsonDecode(snapRes.body);
          if (errJson is Map &&
              errJson['error_messages'] is List &&
              (errJson['error_messages'] as List).isNotEmpty) {
            msg = 'Gateway: ${(errJson['error_messages'] as List).first}';
          }
        } catch (_) {}

        return MidtransDirectPaymentResult.failed(
          orderId: activeOrderId,
          grossAmount: grossAmount,
          paymentMethod: paymentMethod,
          errorMessage: msg,
        );
      }

      final snapData = jsonDecode(snapRes.body) as Map<String, dynamic>;
      final token = snapData['token']?.toString();
      final redirectUrl = snapData['redirect_url']?.toString();

      if (token == null || token.isEmpty) {
        return MidtransDirectPaymentResult(
          success: true,
          orderId: activeOrderId,
          grossAmount: grossAmount,
          paymentMethod: paymentMethod,
          redirectUrl: redirectUrl,
        );
      }

      // Langkah 2b: Panggil Snap Pay API untuk mendapatkan Deep Link asli atau VA
      String? deeplinkUrl;
      String? qrCodeUrl;
      String? qrString;
      String? vaNumber;
      String? expiryTime;
      Map<String, dynamic>? payData;

      try {
        final payPayload = <String, dynamic>{'payment_type': channel};
        if (channel == 'ovo' && customerPhone != null && customerPhone.isNotEmpty) {
          payPayload['customer_details'] = {'phone': customerPhone};
        }

        final payRes = await httpClient
            .post(
              Uri.parse('$_snapUrl/$token/pay'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payPayload),
            )
            .timeout(const Duration(seconds: 6));

        if (payRes.statusCode == 200 || payRes.statusCode == 201) {
          payData = jsonDecode(payRes.body) as Map<String, dynamic>;
          deeplinkUrl = payData['deeplink_url']?.toString();
          qrCodeUrl = payData['qr_code_url']?.toString();
          qrString = payData['qr_string']?.toString();
          expiryTime = payData['expiry_time']?.toString();

          // Ekstrak nomor Virtual Account jika metode transfer bank
          vaNumber = payData['bca_va_number']?.toString() ??
              payData['bri_va_number']?.toString() ??
              payData['bni_va_number']?.toString();

          if (vaNumber == null && payData['va_numbers'] is List) {
            final list = payData['va_numbers'] as List;
            if (list.isNotEmpty && list[0] is Map) {
              vaNumber = list[0]['va_number']?.toString();
            }
          }
        }
      } catch (payErr) {
        debugPrint('[MidtransDirectPayment] Snap /pay direct error: $payErr');
      }

      return MidtransDirectPaymentResult(
        success: true,
        orderId: activeOrderId,
        grossAmount: grossAmount,
        paymentMethod: paymentMethod,
        token: token,
        redirectUrl: redirectUrl,
        deeplinkUrl: deeplinkUrl,
        qrCodeUrl: qrCodeUrl,
        qrString: qrString,
        vaNumber: vaNumber,
        bank: channel,
        expiryTime: expiryTime,
        rawData: payData,
      );
    } catch (e) {
      return MidtransDirectPaymentResult.failed(
        orderId: orderId,
        grossAmount: grossAmount,
        paymentMethod: paymentMethod,
        errorMessage: 'Gagal menghubungi gateway pembayaran: $e',
      );
    }
  }

  /// Meluncurkan aplikasi target (GoPay, ShopeePay, DANA, m-Banking) menggunakan deep link
  /// Membuka aplikasi secara langsung tanpa membuka WebView Midtrans.
  static Future<bool> launchTargetApp({
    required String paymentMethod,
    String? deeplinkUrl,
    String? fallbackWebUrl,
  }) async {
    final method = paymentMethod.toLowerCase();

    // 1. Jika ada deeplink resmi dari Midtrans, utamakan peluncurannya
    if (deeplinkUrl != null && deeplinkUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(deeplinkUrl);
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) return true;
      } catch (e) {
        debugPrint('[MidtransDirectPayment] Error launching deeplink: $e');
      }
    }

    // 2. Fallback skema URI aplikasi spesifik di Indonesia
    final List<String> candidateUris = [];

    if (method.contains('gopay')) {
      candidateUris.addAll([
        if (deeplinkUrl != null) deeplinkUrl,
        'gojek://',
        'https://gopay.co.id',
      ]);
    } else if (method.contains('shopee')) {
      candidateUris.addAll([
        if (deeplinkUrl != null) deeplinkUrl,
        'shopeeid://',
        'https://shopeepay.co.id',
      ]);
    } else if (method.contains('dana')) {
      candidateUris.addAll([
        if (deeplinkUrl != null) deeplinkUrl,
        'dana://',
        'https://link.dana.id',
      ]);
    } else if (method.contains('ovo')) {
      candidateUris.addAll([
        if (deeplinkUrl != null) deeplinkUrl,
        'ovo://',
      ]);
    } else if (method.contains('bca')) {
      candidateUris.addAll(['bca://', 'market://details?id=com.bca']);
    } else if (method.contains('mandiri') || method.contains('echannel')) {
      candidateUris.addAll([
        'livin://',
        'bankmandiri.livin://',
        'market://details?id=id.co.bankmandiri.livin'
      ]);
    } else if (method.contains('bri')) {
      candidateUris.addAll(['brimo://', 'market://details?id=id.co.bri.brimo']);
    } else if (method.contains('bni')) {
      candidateUris.addAll(['bnimobile://', 'market://details?id=src.com.bni']);
    }

    for (final candidate in candidateUris) {
      try {
        final uri = Uri.parse(candidate);
        if (await canLaunchUrl(uri)) {
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (ok) return true;
        }
      } catch (_) {}
    }

    // 3. Jika deeplink simulator atau web fallback tersedia
    if (fallbackWebUrl != null && fallbackWebUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(fallbackWebUrl);
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    return false;
  }

  /// Memverifikasi status sah pembayaran langsung ke Midtrans API
  static Future<bool> verifyPaymentStatus(String orderId, {http.Client? client}) async {
    final httpClient = client ?? http.Client();
    try {
      final authHeader =
          'Basic ${base64Encode(utf8.encode('$_serverKey:'))}';
      final response = await httpClient.get(
        Uri.parse('$_statusBaseUrl/$orderId/status'),
        headers: {
          'Accept': 'application/json',
          'Authorization': authHeader,
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['transaction_status']?.toString().toLowerCase();
        final fraud = data['fraud_status']?.toString().toLowerCase();

        if (status == 'settlement') return true;
        if (status == 'capture' && (fraud == 'accept' || fraud == null || fraud.isEmpty)) {
          return true;
        }
      }
    } catch (e) {
      debugPrint('[MidtransDirectPayment] Verify error: $e');
    }
    return false;
  }

  /// Menampilkan modal in-app pembayaran langsung (Direct Payment Sheet)
  /// TANPA MEMBUKA WEBVIEW MIDTRANS.
  /// Langsung mengarahkan ke aplikasi GoPay / Shopee / DANA / m-Banking dan memantau status pembayaran.
  static Future<bool> showDirectPaymentModal({
    required BuildContext context,
    required MidtransDirectPaymentResult paymentResult,
    required String displayName,
    bool isDarkMode = true,
  }) async {
    // 1. Berikan jeda 250ms agar Bottom Sheet selesai dibuka sebelum OS meluncurkan intent aplikasi eksternal
    final targetUrl = paymentResult.deeplinkUrl ?? paymentResult.redirectUrl;
    if (targetUrl != null && targetUrl.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 250), () {
        launchTargetApp(
          paymentMethod: paymentResult.paymentMethod,
          deeplinkUrl: paymentResult.deeplinkUrl,
          fallbackWebUrl: targetUrl,
        );
      });
    }

    // 2. Tampilkan Bottom Sheet status & kontrol in-app yang elegan
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DirectPaymentSheetContent(
        paymentResult: paymentResult,
        displayName: displayName,
        isDarkMode: isDarkMode,
      ),
    );

    return confirmed == true;
  }
}

/// Konten UI Modal Pembayaran Langsung (Direct In-App Cyber Modal)
class _DirectPaymentSheetContent extends StatefulWidget {
  final MidtransDirectPaymentResult paymentResult;
  final String displayName;
  final bool isDarkMode;

  const _DirectPaymentSheetContent({
    required this.paymentResult,
    required this.displayName,
    required this.isDarkMode,
  });

  @override
  State<_DirectPaymentSheetContent> createState() =>
      _DirectPaymentSheetContentState();
}

class _DirectPaymentSheetContentState extends State<_DirectPaymentSheetContent> {
  Timer? _pollingTimer;
  bool _isChecking = false;
  bool _isSuccess = false;
  bool _isPopped = false;
  int _secondsLeft = 900; // 15 menit
  Timer? _countdownTimer;

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    // Hitung mundur waktu kadaluwarsa
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _isPopped) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });

    // Auto-polling status pembayaran setiap 3 detik
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkPaymentStatusAuto();
    });
  }

  @override
  void dispose() {
    _isPopped = true;
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _safePop([bool? result]) {
    if (!mounted || _isPopped) return;
    _isPopped = true;
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _checkPaymentStatusAuto() async {
    if (_isChecking || _isSuccess || _isPopped || !mounted) return;
    _isChecking = true;
    final verified = await MidtransDirectPaymentService.verifyPaymentStatus(
        widget.paymentResult.orderId);
    _isChecking = false;

    if (verified && mounted && !_isPopped) {
      setState(() => _isSuccess = true);
      _pollingTimer?.cancel();
      _countdownTimer?.cancel();
      await Future.delayed(const Duration(milliseconds: 900));
      _safePop(true);
    }
  }

  Future<void> _manualCheck() async {
    if (_isPopped || !mounted) return;
    setState(() => _isChecking = true);
    final verified = await MidtransDirectPaymentService.verifyPaymentStatus(
        widget.paymentResult.orderId);
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (verified && mounted && !_isPopped) {
      setState(() => _isSuccess = true);
      _pollingTimer?.cancel();
      _countdownTimer?.cancel();
      await Future.delayed(const Duration(milliseconds: 800));
      _safePop(true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LanguageService.text(
              'Pembayaran belum terdeteksi. Silakan selesaikan pembayaran di aplikasi.',
              'Payment not yet detected. Please complete payment in the app.',
            ),
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFF1E293B),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _reopenApp() {
    MidtransDirectPaymentService.launchTargetApp(
      paymentMethod: widget.paymentResult.paymentMethod,
      deeplinkUrl: widget.paymentResult.deeplinkUrl,
      fallbackWebUrl: widget.paymentResult.deeplinkUrl ??
          widget.paymentResult.redirectUrl,
    );
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final methodName = widget.displayName;
    final isVa = widget.paymentResult.vaNumber != null &&
        widget.paymentResult.vaNumber!.isNotEmpty;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _isPopped = true;
        _pollingTimer?.cancel();
        _countdownTimer?.cancel();
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, -5),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header: Judul & Badge Direct App
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Color(0xFF00E5FF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pembayaran $methodName',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00E676),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Direct App Redirection Aktif',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF00E676),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: Icon(Icons.close_rounded, color: textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Banner Nominal Transaksi & Invoice
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Pembayaran',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined,
                              size: 14, color: Color(0xFFFFB300)),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(_secondsLeft),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFFB300),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _currencyFormatter.format(widget.paymentResult.grossAmount),
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF00E5FF),
                          letterSpacing: -0.5,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(
                              text: widget.paymentResult.grossAmount.toString()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Nominal pembayaran berhasil disalin!',
                                style: GoogleFonts.poppins(),
                              ),
                              duration: const Duration(seconds: 1),
                              backgroundColor: const Color(0xFF00E5FF),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.copy_rounded,
                                  size: 14, color: Color(0xFF00E5FF)),
                              const SizedBox(width: 4),
                              Text(
                                'Salin',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF00E5FF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nomor Pesanan',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                      Text(
                        widget.paymentResult.orderId,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tampilan Khusus Virtual Account (Jika Bank Transfer)
            if (isVa) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                        : [const Color(0xFFEEF2FF), Colors.white],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'NOMOR VIRTUAL ACCOUNT',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: const Color(0xFF818CF8),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.paymentResult.bank?.toUpperCase() ?? 'VA',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF818CF8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: SelectableText(
                            widget.paymentResult.vaNumber!,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                                text: widget.paymentResult.vaNumber!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Nomor Virtual Account disalin!',
                                  style: GoogleFonts.poppins(),
                                ),
                                duration: const Duration(seconds: 1),
                                backgroundColor: const Color(0xFF6366F1),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text('Salin'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Indikator Status & Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isSuccess
                    ? const Color(0xFF00E676).withValues(alpha: 0.12)
                    : const Color(0xFF00E5FF).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isSuccess
                      ? const Color(0xFF00E676)
                      : const Color(0xFF00E5FF).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  if (_isSuccess)
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF00E676), size: 22)
                  else
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isSuccess
                          ? 'Pembayaran berhasil dikonfirmasi! Memproses pesanan...'
                          : isVa
                              ? 'Menunggu transfer ke Virtual Account. Sistem otomatis memverifikasi setiap 3 detik.'
                              : 'Nominal telah disiapkan di aplikasi $methodName. Selesaikan pembayaran di aplikasi.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _isSuccess
                            ? const Color(0xFF00E676)
                            : textPrimary,
                        fontWeight:
                            _isSuccess ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tombol Utama: Buka Aplikasi Lagi
            ElevatedButton.icon(
              onPressed: _reopenApp,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(
                isVa
                    ? 'Buka Aplikasi m-Banking'
                    : 'Buka Aplikasi $methodName Sekarang',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
                shadowColor: const Color(0xFF00E5FF).withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 10),

            // Tombol Sekunder: Cek Status Sekarang & Batalkan
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isChecking ? null : _manualCheck,
                    icon: _isChecking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00E5FF),
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      'Cek Status',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: BorderSide(
                        color: textSecondary.withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    onPressed: () => _safePop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Batalkan',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}
