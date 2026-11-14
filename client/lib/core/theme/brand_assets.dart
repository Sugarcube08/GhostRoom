import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Centralized, strongly-typed brand asset definitions and theme-aware brand widgets
/// for GhostRoom.
class BrandAssets {
  BrandAssets._();

  // Canonical Brand Colors
  static const Color obsidianVoid = Color(0xFF090A0F);
  static const Color spectralMist = Color(0xFFF4F6FA);
  static const Color phantomViolet = Color(0xFF7C5CFF);
  static const Color pureWhite = Color(0xFFFFFFFF);

  // Canonical Vector Assets (assets/brand/)
  static const String mark = 'assets/brand/ghostroom_mark.svg';
  static const String markMonoLight = 'assets/brand/ghostroom_mark_mono_light.svg';
  static const String markMonoDark = 'assets/brand/ghostroom_mark_mono_dark.svg';
  static const String wordmark = 'assets/brand/ghostroom_wordmark.svg';
  static const String lockupHorizontal = 'assets/brand/ghostroom_lockup_horizontal.svg';
  static const String appIconMaster = 'assets/brand/ghostroom_app_icon_master.svg';
  static const String adaptiveForeground = 'assets/brand/ghostroom_adaptive_foreground.svg';
}

/// Standalone geometric mark widget with theme and color adaptation.
class GhostRoomMark extends StatelessWidget {
  final double? size;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit fit;

  const GhostRoomMark({
    super.key,
    this.size,
    this.width,
    this.height,
    this.color,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = size ?? width;
    final effectiveHeight = size ?? height;

    if (color != null) {
      return SvgPicture.asset(
        BrandAssets.mark,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        colorFilter: ColorFilter.mode(color!, BlendMode.srcIn),
      );
    }

    return SvgPicture.asset(
      BrandAssets.mark,
      width: effectiveWidth,
      height: effectiveHeight,
      fit: fit,
    );
  }
}

/// Standalone geometric wordmark widget (GHOSTROOM).
class GhostRoomWordmark extends StatelessWidget {
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit fit;

  const GhostRoomWordmark({
    super.key,
    this.width,
    this.height,
    this.color,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (color != null) {
      return SvgPicture.asset(
        BrandAssets.wordmark,
        width: width,
        height: height,
        fit: fit,
        colorFilter: ColorFilter.mode(color!, BlendMode.srcIn),
      );
    }

    if (!isDark) {
      // In light mode, tint the Spectral Mist part to obsidian dark
      return SvgPicture.asset(
        BrandAssets.wordmark,
        width: width,
        height: height,
        fit: fit,
        colorFilter: const ColorFilter.mode(BrandAssets.obsidianVoid, BlendMode.srcIn),
      );
    }

    return SvgPicture.asset(
      BrandAssets.wordmark,
      width: width,
      height: height,
      fit: fit,
    );
  }
}

/// Full brand lockup (Mark + Wordmark) aligned on strict geometric baseline.
class GhostRoomLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit fit;

  const GhostRoomLogo({
    super.key,
    this.width,
    this.height,
    this.color,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (color != null) {
      return SvgPicture.asset(
        BrandAssets.lockupHorizontal,
        width: width,
        height: height,
        fit: fit,
        colorFilter: ColorFilter.mode(color!, BlendMode.srcIn),
      );
    }

    if (!isDark) {
      return SvgPicture.asset(
        BrandAssets.lockupHorizontal,
        width: width,
        height: height,
        fit: fit,
        colorFilter: const ColorFilter.mode(BrandAssets.obsidianVoid, BlendMode.srcIn),
      );
    }

    return SvgPicture.asset(
      BrandAssets.lockupHorizontal,
      width: width,
      height: height,
      fit: fit,
    );
  }
}
