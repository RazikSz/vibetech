import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:vibetech_xyz/services/language_service.dart';
import 'package:vibetech_xyz/services/midtrans_direct_payment_service.dart';

/// ============================================================================
/// IN-APP PAYMENT WEBVIEW - VIBETECH XYZ
/// ============================================================================
/// Menjalankan checkout / simulator pembayaran Midtrans langsung di dalam aplikasi.
/// Mencegah sistem Android mematikan (kill) aplikasi karena low memory
/// saat membuka browser Google Chrome eksternal.
/// 
/// Fitur Utama:
/// 1. Tampilan WebView 100% bebas hambatan (tanpa blocking modal) agar pengguna
///    dapat leluasa menekan tombol 'Pay' pada simulator/checkout.
/// 2. Deteksi otomatis di background tanpa membekukan layar (silent polling).
/// 3. Tombol 'Selesai' untuk verifikasi instan dengan indikator status non-blocking.
/// 4. Konfirmasi dialog elegan saat pengguna menekan tombol tutup / back.
class PaymentWebViewPage extends StatefulWidget {
  final String paymentUrl;
  final String? title;
  final String? orderId;
  final bool isDarkMode;

  const PaymentWebViewPage({
    super.key,
    required this.paymentUrl,
    this.title,
    this.orderId,
    this.isDarkMode = true,
  });

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isCheckingStatus = false;
  bool _isBackgroundPolling = false;
  bool _isPopped = false;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();

    // Fallback loading indicator progress bar mati maksimal setelah 4 detik
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(
          widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
            _checkUrlForSuccess(url);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
            _checkUrlForSuccess(url);

            // Cek seketika saat halaman selesai dimuat (misal reload status PAID di simulator)
            if (widget.orderId != null &&
                widget.orderId!.isNotEmpty &&
                !_isPopped) {
              MidtransDirectPaymentService.verifyPaymentStatus(widget.orderId!)
                  .then((isPaid) {
                if (isPaid && mounted && !_isPopped) {
                  _safePop(true);
                }
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) setState(() => _isLoading = false);
            // Hanya periksa error utama frame (bukan kegagalan aset/tracking subresource)
            if (error.isForMainFrame ?? false) {
              final failedUrl = (error.url ?? '').toLowerCase();
              if (failedUrl.contains('close') ||
                  failedUrl.contains('localhost') ||
                  failedUrl.contains('10.0.2.2') ||
                  failedUrl.contains('finish')) {
                _verifyAndExitIfPaid();
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            final lower = url.toLowerCase();

            // Cek apakah url menandakan sukses pembayaran
            if (lower.contains('status_code=200') ||
                lower.contains('transaction_status=settlement') ||
                lower.contains('transaction_status=capture') ||
                lower.contains('/close') ||
                lower.contains('finish') ||
                lower.contains('success')) {
              _safePop(true);
              return NavigationDecision.prevent;
            }

            if (lower.contains('localhost') || lower.contains('10.0.2.2')) {
              _verifyAndExitIfPaid();
              return NavigationDecision.prevent;
            }

            // Skema aplikasi e-wallet asli di perangkat jika tersedia
            if (url.startsWith('gojek://') ||
                url.startsWith('shopeeid://') ||
                url.startsWith('dana://') ||
                url.startsWith('ovo://') ||
                url.startsWith('bca://') ||
                url.startsWith('livin://') ||
                url.startsWith('intent://') ||
                (!url.startsWith('http://') && !url.startsWith('https://'))) {
              try {
                launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalNonBrowserApplication);
              } catch (_) {}
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));

    // Polling berkala secara diam-diam (silent polling) tanpa membekukan antarmuka
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      _autoCheckTimer =
          Timer.periodic(const Duration(milliseconds: 2500), (_) async {
        if (_isPopped || !mounted || _isBackgroundPolling) return;
        _isBackgroundPolling = true;
        try {
          final isPaid = await MidtransDirectPaymentService.verifyPaymentStatus(
              widget.orderId!);
          if (isPaid && mounted && !_isPopped) {
            _autoCheckTimer?.cancel();
            _safePop(true);
          }
        } finally {
          _isBackgroundPolling = false;
        }
      });
    }
  }

  @override
  void dispose() {
    _isPopped = true;
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  void _safePop(bool result) {
    if (_isPopped || !mounted) return;
    _isPopped = true;
    _autoCheckTimer?.cancel();
    Navigator.of(context).pop(result);
  }

  void _checkUrlForSuccess(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('status_code=200') ||
        lower.contains('transaction_status=settlement') ||
        lower.contains('transaction_status=capture') ||
        lower.contains('/close') ||
        lower.contains('finish') ||
        lower.contains('success')) {
      _safePop(true);
    }
  }

  Future<void> _verifyAndExitIfPaid() async {
    if (_isPopped || !mounted) return;
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      final isPaid = await MidtransDirectPaymentService.verifyPaymentStatus(
          widget.orderId!);
      if (isPaid && mounted && !_isPopped) {
        _safePop(true);
        return;
      }
    }
    _safePop(false);
  }

  /// Dipanggil saat tombol 'Selesai' ditekan oleh pengguna
  Future<void> _onDonePressed() async {
    if (_isPopped || !mounted || _isCheckingStatus) return;
    setState(() => _isCheckingStatus = true);

    try {
      final isPaid = await MidtransDirectPaymentService.verifyPaymentStatus(
          widget.orderId ?? '');

      if (!mounted) return;

      if (isPaid) {
        _safePop(true);
        return;
      }

      // Beri informasi ramah jika transaksi belum diselesaikan di simulator / gateway
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  LanguageService.text(
                    'Pembayaran belum selesai. Silakan tekan tombol "Pay" di halaman.',
                    'Payment not completed yet. Please tap "Pay" button on the page.',
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  /// Dipanggil saat tombol 'X' ditekan atau tombol back Android dipicu
  Future<void> _onClosePressed() async {
    if (_isPopped || !mounted) return;

    // Cek cepat apakah pengguna sebenarnya sudah membayar sebelum menutup
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      final isPaid = await MidtransDirectPaymentService.verifyPaymentStatus(
          widget.orderId!);
      if (isPaid && mounted && !_isPopped) {
        _safePop(true);
        return;
      }
    }

    if (!mounted) return;

    // Dialog konfirmasi pembatalan agar tidak menutup pembayaran secara tidak sengaja
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B), size: 22),
            const SizedBox(width: 8),
            Text(
              LanguageService.text('Keluar Halaman?', 'Exit Page?'),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color:
                    widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          LanguageService.text(
            'Transaksi belum selesai. Anda yakin ingin kembali?',
            'Transaction is not yet finished. Are you sure you want to exit?',
          ),
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: widget.isDarkMode
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              LanguageService.text('Lanjut Bayar', 'Continue Payment'),
              style: GoogleFonts.poppins(
                color: const Color(0xFF00E5FF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              LanguageService.text('Keluar', 'Exit'),
              style: GoogleFonts.poppins(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted && !_isPopped) {
      _safePop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onClosePressed();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: surfaceColor,
          elevation: 2,
          leading: IconButton(
            icon: Icon(Icons.close_rounded, color: textPrimary, size: 24),
            tooltip: LanguageService.text('Tutup', 'Close'),
            onPressed: _onClosePressed,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title ??
                    LanguageService.text(
                        'Proses Pembayaran', 'Payment Processing'),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              if (widget.orderId != null)
                Text(
                  widget.orderId!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          actions: [
            // Tombol Refresh
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: textSecondary, size: 20),
              tooltip: LanguageService.text('Muat Ulang', 'Reload'),
              onPressed: () => _controller.reload(),
            ),
            // Tombol Cek / Selesai Bayar
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TextButton.icon(
                onPressed: _isCheckingStatus ? null : _onDonePressed,
                icon: _isCheckingStatus
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00E676),
                        ),
                      )
                    : const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF00E676),
                        size: 18,
                      ),
                label: Text(
                  LanguageService.text('Selesai', 'Done'),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF00E676),
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF00E676).withValues(alpha: 0.12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
          bottom: _isLoading
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                    backgroundColor: Colors.transparent,
                  ),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
