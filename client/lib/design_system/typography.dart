import 'package:flutter/material.dart';
import 'colors.dart';

class AppTypography {
  static const String fontFamily = 'SF Pro Display';
  static const String fallbackFontFamily = 'Inter';

  static TextStyle hero(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.of(context).primaryText,
    fontFamilyFallback: const [fallbackFontFamily],
  );

  static TextStyle title(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.of(context).primaryText,
    fontFamilyFallback: const [fallbackFontFamily],
  );

  static TextStyle header(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: AppColors.of(context).primaryText,
    fontFamilyFallback: const [fallbackFontFamily],
  );

  static TextStyle section(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.of(context).primaryText,
    fontFamilyFallback: const [fallbackFontFamily],
  );

  static TextStyle body(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.of(context).primaryText,
    fontFamilyFallback: const [fallbackFontFamily],
  );

  static TextStyle secondary(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.of(context).secondaryText,
    fontFamilyFallback: const [fallbackFontFamily],
  );

  static TextStyle caption(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.of(context).secondaryText.withAlpha(150),
    fontFamilyFallback: const [fallbackFontFamily],
  );
}
