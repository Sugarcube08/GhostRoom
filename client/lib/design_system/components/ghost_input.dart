import 'package:flutter/material.dart';
import '../colors.dart';
import '../spacing.dart';
import '../typography.dart';

class GhostInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final bool autofocus;
  final bool isMonospace;

  const GhostInput({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.autofocus = false,
    this.isMonospace = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelText != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              labelText!.toUpperCase(),
              style: AppTypography.caption(context).copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          onEditingComplete: onEditingComplete,
          onSubmitted: onSubmitted,
          maxLines: maxLines,
          autofocus: autofocus,
          style: isMonospace
              ? AppTypography.mono(context, fontSize: 14)
              : AppTypography.body(context),
          cursorColor: colors.ghostAccent,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: (isMonospace
                    ? AppTypography.mono(context, fontSize: 14)
                    : AppTypography.body(context))
                .copyWith(
              color: colors.textMuted,
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: colors.secondaryBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
              borderSide: BorderSide(color: colors.hairline, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
              borderSide: BorderSide(color: colors.hairline, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
              borderSide: BorderSide(color: colors.ghostAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
