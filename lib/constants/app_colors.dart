import 'package:flutter/material.dart';

/// Central Color Palette for VibeTech XYZ
/// Supports Dark Mode (Cyber Neon Aesthetic) and Light Mode (Modern Glassmorphism)
class AppColors {
  // --- Brand & Primary Colors ---
  static const Color primary = Color(0xFF7C4DFF); // Deep Cyber Purple
  static const Color primaryLight = Color(0xFF9E7BFF);
  static const Color primaryDark = Color(0xFF5E35B1);
  static const Color accent = Color(0xFFE040FB); // Neon Magenta
  static const Color cyan = Color(0xFF00E5FF); // Electric Cyan
  static const Color indigo = Color(0xFF6366F1); // Modern Indigo
  static const Color emerald = Color(0xFF10B981); // Emerald / Mint Green

  // --- Dark Mode Palette ---
  static const Color darkBg =
      Color(0xFF060814); // Pitch Dark Void / Midnight Base
  static const Color darkBgSecondary = Color(0xFF0A0E17); // Dark Slate Blue
  static const Color darkCard = Color(0xFF0F1426); // Midnight Navy Card
  static const Color darkCardElevated =
      Color(0xFF161C36); // Elevated Card Surface
  static const Color darkCardSecondary = Color(0xFF181F2E);
  static const Color darkSurface = Color(0xFF141A29);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Muted Steel

  // --- Light Mode Palette ---
  static const Color lightBg = Color(0xFFF8FAFC); // Clean Ghost White
  static const Color lightBgSecondary = Color(0xFFF1F5F9);
  static const Color lightCard = Colors.white;
  static const Color lightCardElevated = Color(0xFFF1F5F9);
  static const Color lightSurface = Color(0xFFF8FAFC);
  static const Color lightTextPrimary = Color(0xFF1E293B); // Charcoal Slate
  static const Color lightTextSecondary = Color(0xFF64748B); // Slate Muted

  // --- Functional Status Colors ---
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color warning = Color(0xFFFFB74D); // Soft Amber
  static const Color warningAlt = Color(0xFFF59E0B); // Vivid Amber
  static const Color error = Color(0xFFEF4444); // Crimson Red
  static const Color info = Color(0xFF3B82F6); // Blue

  // --- Border & Divider Colors ---
  static const Color borderLight = Color(0xFFE2E8F0);
  static Color borderDark = const Color(0xFF7C4DFF).withValues(alpha: 0.18);
  static Color borderDarkSubtle =
      const Color(0xFF94A3B8).withValues(alpha: 0.12);

  // --- Common Gradients ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient indigoGradient = LinearGradient(
    colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pinkGradient = LinearGradient(
    colors: [Color(0xFFF472B6), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient darkBackgroundGradient = RadialGradient(
    center: Alignment(0.0, -0.4),
    radius: 1.3,
    colors: [
      Color(0xFF16103A), // Deep Cyber Purple
      Color(0xFF0B0D21), // Midnight Navy
      Color(0xFF05060F), // Pitch Dark Void
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF8FAFC),
      Color(0xFFF1F5F9),
      Color(0xFFE2E8F0),
    ],
  );
}
