import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibetech_xyz/constants/app_colors.dart';
import 'package:vibetech_xyz/constants/app_dimensions.dart';

/// Centralized BoxDecorations, InputDecorations & Visual Styling Constants
class AppDecorations {
  AppDecorations._();

  /// Standard Card Decoration with optional border, gradient, and glow
  static BoxDecoration card({
    required bool isDarkMode,
    Color? color,
    BorderRadius? borderRadius,
    Border? border,
    List<BoxShadow>? boxShadow,
    Gradient? gradient,
  }) {
    final defaultBg = isDarkMode ? AppColors.darkCard : AppColors.lightCard;
    final defaultBorder = Border.all(
      color: isDarkMode
          ? AppColors.primary.withValues(alpha: 0.18)
          : AppColors.borderLight,
      width: 1,
    );

    return BoxDecoration(
      color: gradient == null ? (color ?? defaultBg) : null,
      gradient: gradient,
      borderRadius: borderRadius ?? AppDimensions.roundedLarge,
      border: border ?? defaultBorder,
      boxShadow: boxShadow ??
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.28 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
    );
  }

  /// Elevated Card with stronger shadow and subtle neon border
  static BoxDecoration elevatedCard({
    required bool isDarkMode,
    Color? color,
    BorderRadius? borderRadius,
    Color? glowColor,
  }) {
    final effectiveGlow = glowColor ?? AppColors.primary;
    return BoxDecoration(
      color: color ??
          (isDarkMode
              ? AppColors.darkCardElevated
              : AppColors.lightCardElevated),
      borderRadius: borderRadius ?? AppDimensions.roundedLarge,
      border: Border.all(
        color: isDarkMode
            ? effectiveGlow.withValues(alpha: 0.25)
            : AppColors.borderLight,
      ),
      boxShadow: [
        BoxShadow(
          color: isDarkMode
              ? effectiveGlow.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// Modal BottomSheet Decoration
  static BoxDecoration modalSheet({
    required bool isDarkMode,
    Color? color,
  }) {
    return BoxDecoration(
      color: color ?? (isDarkMode ? AppColors.darkCard : AppColors.lightCard),
      borderRadius: AppDimensions.roundedBottomSheet,
      border: Border.all(
        color: isDarkMode
            ? AppColors.primary.withValues(alpha: 0.25)
            : Colors.grey.shade200,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDarkMode ? 0.45 : 0.1),
          blurRadius: 30,
          offset: const Offset(0, -10),
        ),
      ],
    );
  }

  /// Dialog Box Decoration
  static BoxDecoration dialog({
    required bool isDarkMode,
    Color? color,
  }) {
    return BoxDecoration(
      color: color ?? (isDarkMode ? AppColors.darkCard : AppColors.lightCard),
      borderRadius: AppDimensions.roundedModal,
      border: Border.all(
        color: isDarkMode
            ? AppColors.primary.withValues(alpha: 0.28)
            : AppColors.borderLight,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  /// Status Badge Decoration
  static BoxDecoration badge({
    required Color color,
    double radius = AppDimensions.radiusSmall,
    double bgAlpha = 0.15,
    double borderAlpha = 0.35,
  }) {
    return BoxDecoration(
      color: color.withValues(alpha: bgAlpha),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: color.withValues(alpha: borderAlpha),
        width: 1,
      ),
    );
  }

  /// Icon Container Decoration with gradient & glow
  static BoxDecoration iconGradient({
    required Gradient gradient,
    Color? shadowColor,
    BorderRadius? borderRadius,
    double shadowAlpha = 0.3,
  }) {
    final effectiveShadow =
        shadowColor ?? AppColors.primary.withValues(alpha: shadowAlpha);
    return BoxDecoration(
      gradient: gradient,
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: effectiveShadow,
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Input Field Decoration for TextFields across pages
  static InputDecoration input({
    required bool isDarkMode,
    required String hint,
    String? label,
    Widget? prefixIcon,
    Widget? suffixIcon,
    EdgeInsetsGeometry? contentPadding,
    bool isDense = false,
  }) {
    final hintColor =
        isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDarkMode
        ? AppColors.primary.withValues(alpha: 0.2)
        : AppColors.borderLight;

    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: hintColor, fontSize: 13),
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
          color: hintColor.withValues(alpha: 0.6), fontSize: 13),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      isDense: isDense,
      filled: true,
      fillColor: isDarkMode
          ? Colors.black.withValues(alpha: 0.25)
          : AppColors.lightBgSecondary,
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: AppDimensions.roundedMedium,
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppDimensions.roundedMedium,
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppDimensions.roundedMedium,
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppDimensions.roundedMedium,
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }

  /// Search Bar Input Decoration
  static InputDecoration searchInput({
    required bool isDarkMode,
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final hintColor =
        isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        color: hintColor.withValues(alpha: 0.6),
        fontSize: 13,
      ),
      prefixIcon: prefixIcon ??
          Icon(Icons.search_rounded,
              color: hintColor, size: AppDimensions.iconMedium),
      suffixIcon: suffixIcon,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
