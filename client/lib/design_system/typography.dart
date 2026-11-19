import 'package:flutter/material.dart';
import 'colors.dart';

class AppTypography {
  static const String fontFamily = 'SF Pro Display';
  static const String fallbackFontFamily = 'Inter';
  static const List<String> monoFallbacks = ['Roboto Mono', 'JetBrains Mono', 'Courier New', 'monospace'];

  static TextStyle hero(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.of(context).primaryText,
    fontFamilyFallback: const [fallbackFontFamily],
  );

  static TextStyle title(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.of(context).primaryText,
    fontFamilyFallback: const [fallbackFontFamily],
  );

  static TextStyle header(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.of(context).primaryText,
    fontFamilyFallback: const [fallbackFontFamily],
  );

  static TextStyle section(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppColors.of(context).primaryText,
    fontFamilyFallback: const [fallbackFontFamily],
  );

  static TextStyle body(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.of(context).primaryText,
    fontFamilyFallback: const [fallbackFontFamily],
  );

  static TextStyle secondary(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.of(context).secondaryText,
    fontFamilyFallback: const [fallbackFontFamily],
  );

  static TextStyle caption(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    color: AppColors.of(context).textMuted,
    fontFamilyFallback: const [fallbackFontFamily],
  );

  // Strict Monospace Typography for Cryptographic Identifiers
  static TextStyle mono(
    BuildContext context, {
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double letterSpacing = 0.5,
  }) =>
      TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: monoFallbacks,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        color: color ?? AppColors.of(context).textPrimary,
      );

  static TextStyle publicId(BuildContext context, {double fontSize = 14, Color? color}) => TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: monoFallbacks,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: color ?? AppColors.of(context).accent,
      );

  static TextStyle fingerprint(BuildContext context, {double fontSize = 12, Color? color}) => TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: monoFallbacks,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
        color: color ?? AppColors.of(context).textSecondary,
      );
}
