import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vibetech_xyz/constants/app_colors.dart';

/// Cyber Particle Data Model for background animations
class AppParticle {
  double x;
  double y;
  double radius;
  double speedX;
  double speedY;
  double opacity;
  bool isCyan;
  final Paint paint;

  AppParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speedX,
    required this.speedY,
    required this.opacity,
    required this.isCyan,
  }) : paint = Paint()
          ..color = (isCyan ? const Color(0xFF00E5FF) : const Color(0xFFE040FB))
              .withValues(alpha: opacity)
          ..style = PaintingStyle.fill;

  /// Factory helper to generate initial particle batch
  static List<AppParticle> generateList(math.Random random, {int count = 20}) {
    final List<AppParticle> list = [];
    for (int i = 0; i < count; i++) {
      list.add(
        AppParticle(
          x: random.nextDouble(),
          y: random.nextDouble(),
          radius: random.nextDouble() * 2.2 + 0.8,
          speedX: (random.nextDouble() - 0.5) * 0.0012,
          speedY: (random.nextDouble() - 0.5) * 0.0012,
          opacity: random.nextDouble() * 0.45 + 0.15,
          isCyan: random.nextBool(),
        ),
      );
    }
    return list;
  }

  /// Update particle positions inside an animation controller listener
  static void updatePositions(List<AppParticle> particles) {
    for (final p in particles) {
      p.x += p.speedX;
      p.y += p.speedY;
      if (p.x < 0) p.x = 1.0;
      if (p.x > 1) p.x = 0.0;
      if (p.y < 0) p.y = 1.0;
      if (p.y > 1) p.y = 0.0;
    }
  }
}

/// CustomPainter to render floating neon particles with zero per-frame allocation
class AppParticlePainter extends CustomPainter {
  final List<AppParticle> particles;

  AppParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.radius,
        p.paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant AppParticlePainter oldDelegate) => true;
}

/// Ultra-smooth, GPU-isolated animated floating cyber particles layer.
/// Uses RepaintBoundary so animating particles never force parent widgets to repaint.
class CyberParticlesLayer extends StatefulWidget {
  final int count;
  const CyberParticlesLayer({super.key, this.count = 20});

  @override
  State<CyberParticlesLayer> createState() => _CyberParticlesLayerState();
}

class _CyberParticlesLayerState extends State<CyberParticlesLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<AppParticle> _particles;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _particles = AppParticle.generateList(_random, count: widget.count);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              AppParticle.updatePositions(_particles);
              return CustomPaint(
                painter: AppParticlePainter(_particles),
                size: Size.infinite,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Ambient Neon Glow Orbs for Dark Mode pages
class AppNeonOrbs extends StatelessWidget {
  final Animation<double> pulseAnimation;

  const AppNeonOrbs({super.key, required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        final val = pulseAnimation.value;
        return Stack(
          children: [
            Positioned(
              top: -50 + (val * 15),
              left: -50 + (val * 10),
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C4DFF)
                          .withValues(alpha: 0.18 + (val * 0.10)),
                      blurRadius: 90,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 80 - (val * 15),
              right: -60 - (val * 10),
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE040FB)
                          .withValues(alpha: 0.14 + (val * 0.08)),
                      blurRadius: 100,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Dashed Divider Line used in receipts, modals, and invoices
class AppDashedDivider extends StatelessWidget {
  final double dashWidth;
  final double dashHeight;
  final Color? color;

  const AppDashedDivider({
    super.key,
    this.dashWidth = 6.0,
    this.dashHeight = 1.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? AppColors.darkTextSecondary.withValues(alpha: 0.25);
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        if (dashCount <= 0) return const SizedBox.shrink();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: effectiveColor),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Bounce animation on tap
class AppBounceTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const AppBounceTap({super.key, required this.child, required this.onTap});

  @override
  State<AppBounceTap> createState() => _AppBounceTapState();
}

class _AppBounceTapState extends State<AppBounceTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTap: () {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Alias for BounceTap to support legacy usages
typedef BounceTap = AppBounceTap;
