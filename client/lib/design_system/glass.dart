import 'package:flutter/material.dart';
import 'colors.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double borderWidth;
  final Color? color;
  final bool enableBlur;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.borderWidth = 1.0,
    this.color,
    this.enableBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final boxDecoration = BoxDecoration(
      color: color ?? colors.backgroundSecondary.withAlpha(102), // 0.4 opacity
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: colors.borderPrimary,
        width: borderWidth,
      ),
    );

    if (!enableBlur) {
      return Container(
        decoration: boxDecoration,
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        decoration: boxDecoration,
        child: child,
      ),
    );
  }
}

class GlassCapsule extends StatelessWidget {
  final Widget child;
  final double paddingHorizontal;
  final double paddingVertical;

  const GlassCapsule({
    super.key,
    required this.child,
    this.paddingHorizontal = 24.0,
    this.paddingVertical = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GlassContainer(
      borderRadius: 99.0,
      color: colors.surfacePrimary.withAlpha(153), // 0.6 opacity
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: paddingHorizontal,
          vertical: paddingVertical,
        ),
        child: child,
      ),
    );
  }
}
