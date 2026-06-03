import 'package:flutter/material.dart';
import '../../../design_system/components/components.dart';
import '../../../design_system/typography.dart';
import '../../../design_system/spacing.dart';
import '../../../design_system/colors.dart';

class RequestsCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const RequestsCard({
    super.key,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    return GhostCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.m,
      ),
      padding: const EdgeInsets.all(AppSpacing.m),
      type: GhostSurfaceType.elevated,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.warning.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mail_lock_outlined, color: colors.warning, size: 24),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message Requests',
                  style: AppTypography.section(context).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Pending identity links',
                  style: AppTypography.caption(context).copyWith(
                    color: colors.secondaryText.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
          GhostBadge(
            label: count.toString(),
            color: colors.warning,
            textColor: Colors.black,
          ),
          const SizedBox(width: AppSpacing.s),
          Icon(Icons.chevron_right, color: colors.secondaryText.withAlpha(100)),
        ],
      ),
    );
  }
}
