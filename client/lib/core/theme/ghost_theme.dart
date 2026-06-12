import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../design_system/animations.dart';

class GhostColorsExtension extends ThemeExtension<GhostColorsExtension> {
  final Color backgroundPrimary;
  final Color backgroundSecondary;
  final Color surfacePrimary;
  final Color surfaceSecondary;
  final Color borderPrimary;
  final Color borderMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color accent;

  const GhostColorsExtension({
    required this.backgroundPrimary,
    required this.backgroundSecondary,
    required this.surfacePrimary,
    required this.surfaceSecondary,
    required this.borderPrimary,
    required this.borderMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.accent,
  });

  // Legacy compatibility getters mapping to semantic tokens
  Color get primaryBackground => backgroundPrimary;
  Color get secondaryBackground => backgroundSecondary;
  Color get elevatedSurface => surfacePrimary;
  Color get hairline => borderPrimary;
  Color get primaryText => textPrimary;
  Color get secondaryText => textSecondary;
  Color get ghostAccent => accent;

  @override
  ThemeExtension<GhostColorsExtension> copyWith({
    Color? backgroundPrimary,
    Color? backgroundSecondary,
    Color? surfacePrimary,
    Color? surfaceSecondary,
    Color? borderPrimary,
    Color? borderMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? accent,
  }) {
    return GhostColorsExtension(
      backgroundPrimary: backgroundPrimary ?? this.backgroundPrimary,
      backgroundSecondary: backgroundSecondary ?? this.backgroundSecondary,
      surfacePrimary: surfacePrimary ?? this.surfacePrimary,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      borderPrimary: borderPrimary ?? this.borderPrimary,
      borderMuted: borderMuted ?? this.borderMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      accent: accent ?? this.accent,
    );
  }

  @override
  ThemeExtension<GhostColorsExtension> lerp(
    ThemeExtension<GhostColorsExtension>? other,
    double t,
  ) {
    if (other is! GhostColorsExtension) {
      return this;
    }
    return GhostColorsExtension(
      backgroundPrimary: Color.lerp(backgroundPrimary, other.backgroundPrimary, t)!,
      backgroundSecondary: Color.lerp(backgroundSecondary, other.backgroundSecondary, t)!,
      surfacePrimary: Color.lerp(surfacePrimary, other.surfacePrimary, t)!,
      surfaceSecondary: Color.lerp(surfaceSecondary, other.surfaceSecondary, t)!,
      borderPrimary: Color.lerp(borderPrimary, other.borderPrimary, t)!,
      borderMuted: Color.lerp(borderMuted, other.borderMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

class GhostTheme {
  static const darkColors = GhostColorsExtension(
    backgroundPrimary: Color(0xFF080808),
    backgroundSecondary: Color(0xFF101010),
    surfacePrimary: Color(0xFF181818),
    surfaceSecondary: Color(0xFF202020),
    borderPrimary: Color(0x14FFFFFF),
    borderMuted: Color(0x0AFFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xB8FFFFFF),
    textMuted: Color(0x66FFFFFF),
    success: Color(0xFF3DDC97),
    warning: Color(0xFFFFB74D),
    error: Color(0xFFFF6B6B),
    info: Color(0xFF7F7FFF),
    accent: Color(0xFF7F7FFF),
  );

  static const lightColors = GhostColorsExtension(
    backgroundPrimary: Color(0xFFF5F5F7),
    backgroundSecondary: Color(0xFFFFFFFF),
    surfacePrimary: Color(0xFFEFEFF4),
    surfaceSecondary: Color(0xFFE5E5EA),
    borderPrimary: Color(0x14000000),
    borderMuted: Color(0x0A000000),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0x99000000),
    textMuted: Color(0x4D000000),
    success: Color(0xFF2EAF7D),
    warning: Color(0xFFE69C24),
    error: Color(0xFFE53935),
    info: Color(0xFF5C5CFF),
    accent: Color(0xFF5C5CFF),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkColors.backgroundPrimary,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: GhostPageTransitionsBuilder(),
        TargetPlatform.iOS: GhostPageTransitionsBuilder(),
        TargetPlatform.linux: GhostPageTransitionsBuilder(),
        TargetPlatform.macOS: GhostPageTransitionsBuilder(),
        TargetPlatform.windows: GhostPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: darkColors.backgroundPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: darkColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w400,
        letterSpacing: 1.2,
      ),
      iconTheme: IconThemeData(color: darkColors.textPrimary),
    ),
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: darkColors.accent,
      onPrimary: const Color(0xFF000000),
      secondary: darkColors.surfaceSecondary,
      onSecondary: darkColors.textPrimary,
      error: darkColors.error,
      onError: const Color(0xFF000000),
      surface: darkColors.backgroundSecondary,
      onSurface: darkColors.textPrimary,
    ),
    extensions: const [darkColors],
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightColors.backgroundPrimary,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: GhostPageTransitionsBuilder(),
        TargetPlatform.iOS: GhostPageTransitionsBuilder(),
        TargetPlatform.linux: GhostPageTransitionsBuilder(),
        TargetPlatform.macOS: GhostPageTransitionsBuilder(),
        TargetPlatform.windows: GhostPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: lightColors.backgroundPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: lightColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
      ),
      iconTheme: IconThemeData(color: lightColors.textPrimary),
    ),
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: lightColors.accent,
      onPrimary: const Color(0xFFFFFFFF),
      secondary: lightColors.surfaceSecondary,
      onSecondary: lightColors.textPrimary,
      error: lightColors.error,
      onError: const Color(0xFFFFFFFF),
      surface: lightColors.backgroundSecondary,
      onSurface: lightColors.textPrimary,
    ),
    extensions: const [lightColors],
  );
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String _boxName = 'theme_settings';
  static const String _key = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final box = await Hive.openBox(_boxName);
      final stored = box.get(_key, defaultValue: 'system') as String;
      switch (stored) {
        case 'light':
          state = ThemeMode.light;
          break;
        case 'dark':
          state = ThemeMode.dark;
          break;
        default:
          state = ThemeMode.system;
      }
    } catch (_) {
      state = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_key, mode.name);
    } catch (_) {}
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
