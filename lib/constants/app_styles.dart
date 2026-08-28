import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Text Styles and Typography for VibeTech XYZ
class AppStyles {
  AppStyles._();

  /// Generic Poppins wrapper with default font family
  static TextStyle poppins({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.poppins(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
      shadows: shadows,
    );
  }

  // --- Headings ---
  static TextStyle h1(Color color, {FontWeight fontWeight = FontWeight.w800}) =>
      poppins(color: color, fontSize: 26, fontWeight: fontWeight, height: 1.2);

  static TextStyle h2(Color color, {FontWeight fontWeight = FontWeight.w700}) =>
      poppins(color: color, fontSize: 20, fontWeight: fontWeight, height: 1.25);

  static TextStyle h3(Color color, {FontWeight fontWeight = FontWeight.w700}) =>
      poppins(color: color, fontSize: 16, fontWeight: fontWeight, height: 1.3);

  static TextStyle title(Color color,
          {FontWeight fontWeight = FontWeight.w600, double fontSize = 15}) =>
      poppins(color: color, fontSize: fontSize, fontWeight: fontWeight);

  static TextStyle subtitle(Color color,
          {FontWeight fontWeight = FontWeight.w500, double fontSize = 13}) =>
      poppins(color: color, fontSize: fontSize, fontWeight: fontWeight);

  // --- Body Texts ---
  static TextStyle body(Color color,
          {FontWeight fontWeight = FontWeight.w400,
          double fontSize = 13,
          double? height}) =>
      poppins(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height);

  static TextStyle bodySmall(Color color,
          {FontWeight fontWeight = FontWeight.w400, double fontSize = 12}) =>
      poppins(color: color, fontSize: fontSize, fontWeight: fontWeight);

  static TextStyle bodyMedium(Color color,
          {FontWeight fontWeight = FontWeight.w500, double fontSize = 14}) =>
      poppins(color: color, fontSize: fontSize, fontWeight: fontWeight);

  static TextStyle bodyBold(Color color,
          {FontWeight fontWeight = FontWeight.w700, double fontSize = 14}) =>
      poppins(color: color, fontSize: fontSize, fontWeight: fontWeight);

  // --- Captions & Microcopy ---
  static TextStyle caption(Color color,
          {FontWeight fontWeight = FontWeight.w400, double fontSize = 11}) =>
      poppins(color: color, fontSize: fontSize, fontWeight: fontWeight);

  static TextStyle captionBold(Color color,
          {FontWeight fontWeight = FontWeight.w600, double fontSize = 11}) =>
      poppins(color: color, fontSize: fontSize, fontWeight: fontWeight);

  static TextStyle badge(Color color,
          {FontWeight fontWeight = FontWeight.w700, double fontSize = 10.5}) =>
      poppins(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: 0.3);

  // --- Button Texts ---
  static TextStyle button({Color color = Colors.white, double fontSize = 14}) =>
      poppins(color: color, fontSize: fontSize, fontWeight: FontWeight.w600);

  // --- Price / Numeric Styles ---
  static TextStyle price(Color color,
          {double fontSize = 18, FontWeight fontWeight = FontWeight.w800}) =>
      poppins(color: color, fontSize: fontSize, fontWeight: fontWeight);
}
