import 'package:flutter/material.dart';
import '../colors.dart';
import '../spacing.dart';

enum GhostSurfaceType {
  primary,
  secondary,
  elevated,
}

class GhostSurface extends StatelessWidget {
  final Widget child;
  final GhostSurfaceType type;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  const GhostSurface({
    super.key,
    required this.child,
    this.type = GhostSurfaceType.primary,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    Color backgroundColor;
    switch (type) {
      case GhostSurfaceType.primary:
        backgroundColor = colors.primaryBackground;
        break;
      case GhostSurfaceType.secondary:
        backgroundColor = colors.secondaryBackground;
        break;
      case GhostSurfaceType.elevated:
        backgroundColor = colors.elevatedSurface;
        break;
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(AppSpacing.radiusM),
        border: border ?? Border.all(color: colors.hairline, width: 1),
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }
}
