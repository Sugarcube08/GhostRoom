import 'package:flutter/material.dart';
import '../core/theme/ghost_theme.dart';

class AppColors {
  static GhostColorsExtension of(BuildContext context) {
    return Theme.of(context).extension<GhostColorsExtension>() ?? GhostTheme.darkColors;
  }

  // Obsidian Void & Elevated Slate Architectural Palette
  static const Color backgroundPrimary = Color(0xFF090A0F); // Obsidian Void
  static const Color backgroundSecondary = Color(0xFF12141D); // Elevated Slate
  static const Color surfacePrimary = Color(0xFF12141D); // Elevated Slate
  static const Color surfaceSecondary = Color(0xFF1A1D2B); // Secondary Slate Container
  static const Color borderPrimary = Color(0xFF1F2333); // Crisp 1px Structural Border
  static const Color borderMuted = Color(0xFF151824); // Subtle Border
  static const Color textPrimary = Color(0xFFF4F6FA); // High-Contrast Mist
  static const Color textSecondary = Color(0xFF9BA3B8); // Secondary Mist
  static const Color textMuted = Color(0xFF525A70); // Muted Slate
  static const Color success = Color(0xFF3DDC97);
  static const Color warning = Color(0xFFFFB74D);
  static const Color error = Color(0xFFFF6B6B);
  static const Color info = Color(0xFF7C5CFF);
  static const Color accent = Color(0xFF7C5CFF); // Cyber Iris / Phantom Violet

  // Legacy constants for backward compatibility
  static const Color primaryBackground = backgroundPrimary;
  static const Color secondaryBackground = backgroundSecondary;
  static const Color elevatedSurface = surfacePrimary;
  static const Color hairline = borderPrimary;
  static const Color primaryText = textPrimary;
  static const Color secondaryText = textSecondary;
  static const Color ghostAccent = accent;
}
