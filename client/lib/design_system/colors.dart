import 'package:flutter/material.dart';
import '../core/theme/ghost_theme.dart';

class AppColors {
  static GhostColorsExtension of(BuildContext context) {
    return Theme.of(context).extension<GhostColorsExtension>()!;
  }

  // Legacy constants for backward compatibility where context is unavailable
  // and to serve as default "dark" values.
  static const Color primaryBackground = Color(0xFF080808);
  static const Color secondaryBackground = Color(0xFF101010);
  static const Color elevatedSurface = Color(0xFF181818);
  static const Color hairline = Color(0x14FFFFFF);
  
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xB8FFFFFF);
  static const Color ghostAccent = Color(0xFF7F7FFF);
  
  static const Color success = Color(0xFF3DDC97);
  static const Color warning = Color(0xFFFFB74D);
  static const Color error = Color(0xFFFF6B6B);
}
