import 'package:flutter/material.dart';
import '../colors.dart';
import '../spacing.dart';
import '../typography.dart';
import '../haptics.dart';

enum GhostButtonType {
  primary,
  secondary,
  ghost,
  danger,
}

class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final GhostButtonType type;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.type = GhostButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    Color backgroundColor;
    Color foregroundColor;
    Border? border;

    switch (type) {
      case GhostButtonType.primary:
        backgroundColor = colors.primaryText;
        foregroundColor = colors.primaryBackground;
        break;
      case GhostButtonType.secondary:
        backgroundColor = colors.secondaryBackground;
        foregroundColor = colors.primaryText;
        border = Border.all(color: colors.hairline, width: 1);
        break;
      case GhostButtonType.ghost:
        backgroundColor = Colors.transparent;
        foregroundColor = colors.primaryText;
        break;
      case GhostButtonType.danger:
        backgroundColor = colors.error.withAlpha(40);
        foregroundColor = colors.error;
        border = Border.all(color: colors.error.withAlpha(80), width: 1);
        break;
    }

    final bool isDisabled = onPressed == null || isLoading;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: isDisabled ? null : () {
          AppHaptics.light();
          onPressed!();
        },
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.m,
            horizontal: AppSpacing.l,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusM),
            border: border,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                    ),
                  ),
                )
              else if (icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s),
                  child: Icon(icon, color: foregroundColor, size: 18),
                ),
              Text(
                label,
                style: AppTypography.body(context).copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
