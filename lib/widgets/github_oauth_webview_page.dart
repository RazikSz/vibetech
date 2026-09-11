import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibetech_xyz/services/github_auth_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Halaman In-App WebView Otorisasi Akun GitHub Resmi
class GithubOAuthWebViewPage extends StatefulWidget {
  final bool isDarkMode;
  final bool isRegisterMode;

  const GithubOAuthWebViewPage({
    super.key,
    required this.isDarkMode,
    this.isRegisterMode = false,
  });

  @override
  State<GithubOAuthWebViewPage> createState() => _GithubOAuthWebViewPageState();
}

class _GithubOAuthWebViewPageState extends State<GithubOAuthWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _hasHandledCode = false;
  bool _hasPopped = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _initWebViewController();
  }

  void _initWebViewController() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(
          widget.isDarkMode ? const Color(0xFF0D1117) : Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (!_hasPopped && mounted) {
              setState(() => _progress = progress / 100);
            }
          },
          onPageStarted: (String url) {
            _checkInterceptUrl(url);
            if (!_hasPopped && mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (String url) {
            _checkInterceptUrl(url);
            if (!_hasPopped && mounted) {
              setState(() => _isLoading = false);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_checkInterceptUrl(request.url)) {
              return NavigationDecision
                  .prevent; // Mencegah load halaman web error
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('[GithubOAuthWebView] Web error: ${error.description}');
          },
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(false);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    final String authUrl = GithubAuthService.authorizationUrl;
    controller.loadRequest(Uri.parse(authUrl));
    _controller = controller;
  }

  /// Memeriksa dan mengekstrak authorization code seketika dari URL redirect
  bool _checkInterceptUrl(String url) {
    if (_hasHandledCode || _hasPopped) return true;

    final uri = Uri.parse(url);
    if (url.contains('vibetech-xyz.firebaseapp.com/__/auth/handler') ||
        url.contains('code=') ||
        url.contains('error=')) {
      final error = uri.queryParameters['error'];
      if (error != null && error.isNotEmpty) {
        if (!_hasPopped && mounted) {
          _hasPopped = true;
          Navigator.of(context).pop(null);
        }
        return true;
      }
      final code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        _hasHandledCode = true;
        _processOAuthCode(code);
        return true;
      }
    }
    return false;
  }

  /// Menukarkan kode dengan token, menghubungkan ke Firebase Auth, dan kembali ke aplikasi
  Future<void> _processOAuthCode(String code) async {
    if (_hasPopped) return;
    HapticFeedback.mediumImpact();

    if (mounted) {
      setState(() {
        _isProcessing = true;
        _isLoading = false;
      });
    }

    final GithubAccountUser? user =
        await GithubAuthService.signInWithFirebaseGithubCode(code);

    if (!_hasPopped && mounted) {
      _hasPopped = true;
      Navigator.of(context).pop(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF0D1117) : Colors.white;
    final textPri = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSec = isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B);

    return PopScope(
      canPop: !_isProcessing,
      onPopInvokedWithResult: (didPop, result) {
        _hasPopped = true;
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close_rounded, color: textPri),
            onPressed: () {
              if (!_hasPopped && mounted) {
                _hasPopped = true;
                Navigator.of(context).pop(null);
              }
            },
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF24292F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.code_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isRegisterMode
                          ? 'Daftar Akun GitHub'
                          : 'Masuk dengan GitHub',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textPri,
                      ),
                    ),
                    Text(
                      'github.com / OAuth Firebase',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: textSec,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: (_isLoading || _isProcessing)
                ? LinearProgressIndicator(
                    value: _isProcessing ? null : _progress,
                    backgroundColor: Colors.transparent,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF8250DF)),
                    minHeight: 2.5,
                  )
                : const SizedBox(height: 2),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isProcessing)
              Container(
                color: bg.withValues(alpha: 0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF8250DF).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const CircularProgressIndicator(
                          color: Color(0xFF8250DF),
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Menghubungkan ke Firebase Authentication...',
                        style: GoogleFonts.poppins(
                          color: textPri,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mohon tunggu sebentar',
                        style: GoogleFonts.poppins(
                          color: textSec,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
