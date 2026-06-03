import 'package:flutter/material.dart';
import '../colors.dart';
import '../spacing.dart';
import '../typography.dart';

class GhostBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;

  const GhostBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
        horizontal: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: color ?? colors.ghostAccent.withAlpha(40),
        borderRadius: BorderRadius.circular(AppSpacing.radiusS),
        border: Border.all(
          color: color?.withAlpha(80) ?? colors.ghostAccent.withAlpha(80),
          width: 0.5,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.caption(context).copyWith(
          color: textColor ?? color ?? colors.ghostAccent,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          fontSize: 10,
        ),
      ),
    );
  }
}
