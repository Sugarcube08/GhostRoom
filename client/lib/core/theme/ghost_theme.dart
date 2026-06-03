import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../design_system/animations.dart';

class GhostColorsExtension extends ThemeExtension<GhostColorsExtension> {
  final Color primaryBackground;
  final Color secondaryBackground;
  final Color elevatedSurface;
  final Color hairline;
  final Color primaryText;
  final Color secondaryText;
  final Color ghostAccent;
  final Color success;
  final Color warning;
  final Color error;

  const GhostColorsExtension({
    required this.primaryBackground,
    required this.secondaryBackground,
    required this.elevatedSurface,
    required this.hairline,
    required this.primaryText,
    required this.secondaryText,
    required this.ghostAccent,
    required this.success,
    required this.warning,
    required this.error,
  });

  @override
  ThemeExtension<GhostColorsExtension> copyWith({
    Color? primaryBackground,
    Color? secondaryBackground,
    Color? elevatedSurface,
    Color? hairline,
    Color? primaryText,
    Color? secondaryText,
    Color? ghostAccent,
    Color? success,
    Color? warning,
    Color? error,
  }) {
    return GhostColorsExtension(
      primaryBackground: primaryBackground ?? this.primaryBackground,
      secondaryBackground: secondaryBackground ?? this.secondaryBackground,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      hairline: hairline ?? this.hairline,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      ghostAccent: ghostAccent ?? this.ghostAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
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
      primaryBackground: Color.lerp(primaryBackground, other.primaryBackground, t)!,
      secondaryBackground: Color.lerp(secondaryBackground, other.secondaryBackground, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      ghostAccent: Color.lerp(ghostAccent, other.ghostAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

class GhostTheme {
  static const darkColors = GhostColorsExtension(
    primaryBackground: Color(0xFF080808),
    secondaryBackground: Color(0xFF101010),
    elevatedSurface: Color(0xFF181818),
    hairline: Color(0x14FFFFFF),
    primaryText: Color(0xFFFFFFFF),
    secondaryText: Color(0xB8FFFFFF),
    ghostAccent: Color(0xFF7F7FFF),
    success: Color(0xFF3DDC97),
    warning: Color(0xFFFFB74D),
    error: Color(0xFFFF6B6B),
  );

  static const lightColors = GhostColorsExtension(
    primaryBackground: Color(0xFFF5F5F7),
    secondaryBackground: Color(0xFFFFFFFF),
    elevatedSurface: Color(0xFFEFEFF4),
    hairline: Color(0x14000000),
    primaryText: Color(0xFF000000),
    secondaryText: Color(0x99000000),
    ghostAccent: Color(0xFF5C5CFF),
    success: Color(0xFF2EAF7D),
    warning: Color(0xFFE69C24),
    error: Color(0xFFE53935),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkColors.primaryBackground,
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
      backgroundColor: darkColors.primaryBackground,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: darkColors.primaryText,
        fontSize: 18,
        fontWeight: FontWeight.w400,
        letterSpacing: 1.2,
      ),
      iconTheme: IconThemeData(color: darkColors.primaryText),
    ),
    colorScheme: ColorScheme.dark(
      surface: darkColors.secondaryBackground,
      primary: darkColors.primaryText,
      secondary: darkColors.ghostAccent,
      error: darkColors.error,
    ),
    extensions: const [darkColors],
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightColors.primaryBackground,
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
      backgroundColor: lightColors.primaryBackground,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: lightColors.primaryText,
        fontSize: 18,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
      ),
      iconTheme: IconThemeData(color: lightColors.primaryText),
    ),
    colorScheme: ColorScheme.light(
      surface: lightColors.secondaryBackground,
      primary: lightColors.primaryText,
      secondary: lightColors.ghostAccent,
      error: lightColors.error,
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
