import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibetech_xyz/constants/constants.dart';
import 'package:vibetech_xyz/pages/auth/login_page.dart';
import 'package:vibetech_xyz/services/cloud_sync_service.dart';

/// ============================================================================
/// HALAMAN PEMBUKA / SPLASH SCREEN (SPLASH PAGE)
/// ============================================================================
/// Tampilan pembuka animasi saat aplikasi pertama kali dimuat:
/// 1. Efek partikel cyber futuristik & logo glow bercahaya.
/// 2. Animasi progress bar inisialisasi modul.
/// 3. Navigasi otomatis ke Halaman Login (LoginPage) setelah durasi pembuka selesai.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _introController;
  late AnimationController _pulseController;
  late AnimationController _ringController;
  late AnimationController _progressController;
  late AnimationController _shimmerController;
  late AnimationController _particleController;

  // Animations
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _badgeFade;
  late Animation<double> _progressFade;
  late Animation<double> _footerFade;

  // State
  bool _navigated = false;
  final List<AppParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    // Set Status Bar Transparan
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF060814),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    // Inisialisasi Partikel Latar Belakang
    _particles.addAll(AppParticle.generateList(_random, count: 28));

    // 1. Particle Controller
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _particleController.addListener(() {
      AppParticle.updatePositions(_particles);
    });

    // 2. Main Intro Staggered Controller
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.25, 0.60, curve: Curves.easeIn),
      ),
    );

    _titleSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.25, 0.60, curve: Curves.easeOutCubic),
      ),
    );

    _badgeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.45, 0.75, curve: Curves.easeIn),
      ),
    );

    _progressFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.55, 0.85, curve: Curves.easeIn),
      ),
    );

    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.70, 1.0, curve: Curves.easeIn),
      ),
    );

    // 3. Continuous Ring Rotation (Cyber Rings)
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // 4. Pulse Breathing Glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // 5. Shimmer Light Sweep on Progress Bar
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // 6. Loading Progress (0.0 to 1.0 over 4.2 seconds)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );

    // Jalankan Animasi
    _introController.forward();
    _progressController.forward();

    // Jalankan Sinkronisasi Cloud Firebase Lintas Perangkat (Multi-Device Sync)
    _initCloudDataInBackground();

    // Listener saat progress selesai -> Navigasi ke Login
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToLogin();
      }
    });
  }

  void _initCloudDataInBackground() async {
    // Jalankan sinkronisasi cloud Firebase di runtime aplikasi nyata (bukan saat widget test)
    if (WidgetsBinding.instance is! WidgetsFlutterBinding) return;
    try {
      CloudSyncService.instance.syncAllFromCloud();
    } catch (e) {
      debugPrint('[SplashPage] Cloud startup sync info: $e');
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _pulseController.dispose();
    _ringController.dispose();
    _progressController.dispose();
    _shimmerController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    if (_navigated || !mounted) return;
    _navigated = true;
    HapticFeedback.mediumImpact();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  String _getLoadingPhaseText(double progress) {
    if (progress < 0.25) {
      return '[SYS_INIT] Loading cloud kernel core...';
    } else if (progress < 0.55) {
      return '[NET_SYNC] Connecting to VibeTech edge nodes...';
    } else if (progress < 0.85) {
      return '[SEC_AUTH] Verifying neural encryption keys...';
    } else {
      return '[SYSTEM_READY] Launching workspace...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF060814),
      body: Stack(
        children: [
          // 1. Futuristic Dark Gradient Layer
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.2),
                radius: 1.2,
                colors: [
                  Color(0xFF16103A), // Deep Cyber Purple core
                  Color(0xFF0B0D21), // Midnight Navy
                  Color(0xFF05060F), // Pitch Void
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // 2. Animated Ambient Neon Glow Orbs
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final pulseVal = _pulseController.value;
              return Stack(
                children: [
                  // Top Left Glow (Purple/Magenta)
                  Positioned(
                    top: -60 + (pulseVal * 15),
                    left: -60 + (pulseVal * 10),
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C4DFF)
                                .withValues(alpha: 0.25 + (pulseVal * 0.15)),
                            blurRadius: 100,
                            spreadRadius: 30,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Right Glow (Cyan/Teal)
                  Positioned(
                    bottom: -80 - (pulseVal * 15),
                    right: -70 - (pulseVal * 10),
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF)
                                .withValues(alpha: 0.20 + (pulseVal * 0.12)),
                            blurRadius: 110,
                            spreadRadius: 25,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Center Aura behind Logo
                  Positioned(
                    top: size.height * 0.22,
                    left: (size.width - 240) / 2,
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE040FB)
                                .withValues(alpha: 0.18 + (pulseVal * 0.12)),
                            blurRadius: 90,
                            spreadRadius: 15,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // 3. Cyber Matrix Floating Particles Canvas
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                size: Size(size.width, size.height),
                painter: AppParticlePainter(_particles),
              );
            },
          ),

          // 4. Main Foreground UI
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                children: [
                  // Top Skip / Direct Access Bar
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Status Indicator
                        FadeTransition(
                          opacity: _footerFade,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141A29)
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF00E5FF)
                                    .withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xFF10B981),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'RZIEK.V2_ONLINE',
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF10B981),
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Skip Button
                        FadeTransition(
                          opacity: _footerFade,
                          child: InkWell(
                            onTap: _navigateToLogin,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Lewati',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 10,
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Centerpiece: Holographic Logo & Rings
                  _buildAnimatedLogoSection(),

                  const SizedBox(height: 32),

                  // Brand Identity & Title
                  _buildBrandTitleSection(),

                  const SizedBox(height: 16),

                  // Feature Pills (VPS • WA Bot • Hosting)
                  _buildFeaturePillsSection(),

                  const Spacer(flex: 3),

                  // Futuristic Terminal & Progress Bar
                  _buildCyberProgressBarSection(),

                  const SizedBox(height: 24),

                  // Footer Copyright & Version
                  _buildFooterSection(),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET KOMPONEN SPLASH PAGE ---

  Widget _buildAnimatedLogoSection() {
    return FadeTransition(
      opacity: _logoFade,
      child: ScaleTransition(
        scale: _logoScale,
        child: SizedBox(
          width: 175,
          height: 175,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Radar Pulse Wave (Expanding Circle)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final val = _pulseController.value;
                  return Container(
                    width: 155 + (val * 20),
                    height: 155 + (val * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF7C4DFF)
                            .withValues(alpha: (1.0 - val) * 0.45),
                        width: 1.5,
                      ),
                    ),
                  );
                },
              ),

              // 2. Outer Rotating Cyber Ring (Clockwise)
              RotationTransition(
                turns: _ringController,
                child: CustomPaint(
                  size: const Size(165, 165),
                  painter: _CyberRingPainter(
                    color: const Color(0xFF00E5FF),
                    secondaryColor: const Color(0xFF7C4DFF),
                  ),
                ),
              ),

              // 3. Middle Counter-Rotating Neon Ring (Counter-Clockwise)
              AnimatedBuilder(
                animation: _ringController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: -_ringController.value * 2 * math.pi,
                    child: Container(
                      width: 138,
                      height: 138,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            const Color(0xFFE040FB).withValues(alpha: 0.8),
                            const Color(0xFF00E5FF).withValues(alpha: 0.1),
                            const Color(0xFF7C4DFF).withValues(alpha: 0.9),
                            const Color(0xFFE040FB).withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // 4. Glassmorphism Core Disc
              Container(
                width: 122,
                height: 122,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0E1326),
                  border: Border.all(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.6),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background Mesh Pattern
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1E1442),
                              Color(0xFF0B1024),
                            ],
                          ),
                        ),
                      ),

                      // Logo Image / Asset with Network + Icon Fallback
                      Image.network(
                        'https://cdn.nekohime.site/file/5232n74c.jpeg',
                        width: 122,
                        height: 122,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Coba tampilkan logo asset jika ada, atau icon tech fallback
                          return Image.asset(
                            'assets/icon/logo.png',
                            width: 122,
                            height: 122,
                            fit: BoxFit.cover,
                            errorBuilder: (context, err, stack) {
                              return const Center(
                                child: Icon(
                                  Icons.cloud_queue_rounded,
                                  color: Color(0xFF00E5FF),
                                  size: 50,
                                ),
                              );
                            },
                          );
                        },
                      ),

                      // Cyber Highlight Sheen
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 45,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.25),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Tech Accent Nodes on perimeter
              Positioned(
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E5FF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF00E5FF),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE040FB),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFE040FB),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandTitleSection() {
    return FadeTransition(
      opacity: _titleFade,
      child: SlideTransition(
        position: _titleSlide,
        child: Column(
          children: [
            // "VIBETECH XYZ" Main Glowing Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'VIBE',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.white.withValues(alpha: 0.6),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                ),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFF7C4DFF),
                      Color(0xFFE040FB),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'TECH',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'XYZ',
                    style: GoogleFonts.spaceMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Tagline
            Text(
              'NEXT-GEN DIGITAL & CLOUD INFRASTRUCTURE',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePillsSection() {
    return FadeTransition(
      opacity: _badgeFade,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildMiniFeaturePill(
              Icons.dns_rounded, 'Cloud VPS', const Color(0xFF818CF8)),
          _buildMiniFeaturePill(Icons.chat_bubble_rounded, 'Bot WhatsApp',
              const Color(0xFF34D399)),
          _buildMiniFeaturePill(Icons.cloud_queue_rounded, 'Panel Hosting',
              const Color(0xFFF472B6)),
        ],
      ),
    );
  }

  Widget _buildMiniFeaturePill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCyberProgressBarSection() {
    return FadeTransition(
      opacity: _progressFade,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: AnimatedBuilder(
          animation:
              Listenable.merge([_progressController, _shimmerController]),
          builder: (context, child) {
            final progress = _progressController.value;
            final percentage = (progress * 100).toInt();
            final shimmerPos = _shimmerController.value;

            return Column(
              children: [
                // Terminal Status Text & Digital Percent Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        _getLoadingPhaseText(progress),
                        style: GoogleFonts.spaceMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00E5FF),
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '$percentage%',
                        style: GoogleFonts.spaceMono(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // High-Tech Glowing Progress Bar
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141A29),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        // Progress Fill
                        FractionallySizedBox(
                          widthFactor: progress.clamp(0.01, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF00E5FF),
                                  Color(0xFF7C4DFF),
                                  Color(0xFFE040FB),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF)
                                      .withValues(alpha: 0.8),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Animated Shimmer Light Beam
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Transform.translate(
                                offset: Offset(
                                  (shimmerPos * 2 - 1) * constraints.maxWidth,
                                  0,
                                ),
                                child: Container(
                                  width: constraints.maxWidth * 0.4,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.0),
                                        Colors.white.withValues(alpha: 0.6),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFooterSection() {
    return FadeTransition(
      opacity: _footerFade,
      child: Column(
        children: [
          // Creator Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF141A29).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.terminal_rounded,
                  size: 13,
                  color: Color(0xFF00E5FF),
                ),
                const SizedBox(width: 6),
                Text(
                  'Created by Raziek',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE2E8F0),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '© 2026 VibeTech XYZ • All Rights Reserved',
            style: GoogleFonts.poppins(
              color: Colors.white38,
              fontSize: 10.5,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// --- CYBER RING PAINTER ---

class _CyberRingPainter extends CustomPainter {
  final Color color;
  final Color secondaryColor;

  _CyberRingPainter({required this.color, required this.secondaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final dashPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw 4 curved segments (cyber HUD style)
    const int segments = 4;
    const double sweepAngle = (math.pi * 2) / segments * 0.65;
    const double gapAngle = (math.pi * 2) / segments * 0.35;

    for (int i = 0; i < segments; i++) {
      final startAngle = i * (sweepAngle + gapAngle);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        dashPaint,
      );
    }

    // Draw 4 corner tick dots
    final dotPaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final angle = i * (math.pi / 2);
      final dotX = center.dx + (radius - 2) * math.cos(angle);
      final dotY = center.dy + (radius - 2) * math.sin(angle);
      canvas.drawCircle(Offset(dotX, dotY), 3.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberRingPainter oldDelegate) => false;
}
