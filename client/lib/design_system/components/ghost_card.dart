import 'package:flutter/material.dart';
import '../spacing.dart';
import 'ghost_surface.dart';

class GhostCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final GhostSurfaceType type;
  final BorderRadius? borderRadius;

  const GhostCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.type = GhostSurfaceType.secondary,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget current = GhostSurface(
      type: type,
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(AppSpacing.m),
      borderRadius: borderRadius,
      child: child,
    );

    if (onTap != null) {
      current = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: current,
      );
    }

    if (margin != null) {
      current = Padding(
        padding: margin!,
        child: current,
      );
    }

    return current;
  }
}
