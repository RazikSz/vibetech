import 'package:flutter/material.dart';

/// Central Design System Dimensions, Radiuses, Spacings & Durations
class AppDimensions {
  // --- Corner Radiuses ---
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  static const double radiusModal = 24.0;
  static const double radiusBottomSheet = 28.0;
  static const double radiusPill = 999.0;

  static BorderRadius get roundedSmall => BorderRadius.circular(radiusSmall);
  static BorderRadius get roundedMedium => BorderRadius.circular(radiusMedium);
  static BorderRadius get roundedLarge => BorderRadius.circular(radiusLarge);
  static BorderRadius get roundedXLarge => BorderRadius.circular(radiusXLarge);
  static BorderRadius get roundedModal => BorderRadius.circular(radiusModal);
  static BorderRadius get roundedBottomSheet =>
      const BorderRadius.vertical(top: Radius.circular(radiusBottomSheet));

  // --- Spacings & Insets ---
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 20.0;
  static const double spacingXXL = 24.0;
  static const double spacingHero = 32.0;

  static const EdgeInsets paddingScreen =
      EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
  static const EdgeInsets paddingCard = EdgeInsets.all(16.0);
  static const EdgeInsets paddingModal = EdgeInsets.all(24.0);

  // --- Icon Sizes ---
  static const double iconXS = 14.0;
  static const double iconSmall = 18.0;
  static const double iconMedium = 20.0;
  static const double iconLarge = 24.0;
  static const double iconXLarge = 32.0;
  static const double iconHero = 60.0;

  // --- Standard Animation Durations ---
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animMedium = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 600);
  static const Duration animStagger = Duration(milliseconds: 900);
  static const Duration animLong = Duration(milliseconds: 1200);
  static const Duration animPulse = Duration(seconds: 2);
  static const Duration animParticle = Duration(seconds: 10);
}
