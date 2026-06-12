import 'package:flutter/material.dart';
import '../core/theme/ghost_theme.dart';

class AppColors {
  static GhostColorsExtension of(BuildContext context) {
    return Theme.of(context).extension<GhostColorsExtension>()!;
  }

  // Semantic tokens (defaults serving as fallback dark values)
  static const Color backgroundPrimary = Color(0xFF080808);
  static const Color backgroundSecondary = Color(0xFF101010);
  static const Color surfacePrimary = Color(0xFF181818);
  static const Color surfaceSecondary = Color(0xFF202020);
  static const Color borderPrimary = Color(0x14FFFFFF);
  static const Color borderMuted = Color(0x0AFFFFFF);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB8FFFFFF);
  static const Color textMuted = Color(0x66FFFFFF);
  static const Color success = Color(0xFF3DDC97);
  static const Color warning = Color(0xFFFFB74D);
  static const Color error = Color(0xFFFF6B6B);
  static const Color info = Color(0xFF7F7FFF);
  static const Color accent = Color(0xFF7F7FFF);

  // Legacy constants for backward compatibility
  static const Color primaryBackground = backgroundPrimary;
  static const Color secondaryBackground = backgroundSecondary;
  static const Color elevatedSurface = surfacePrimary;
  static const Color hairline = borderPrimary;
  static const Color primaryText = textPrimary;
  static const Color secondaryText = textSecondary;
  static const Color ghostAccent = accent;
}
