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
    final bool isEmpty = count == 0;
    
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
              color: isEmpty ? colors.secondaryText.withAlpha(20) : colors.warning.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEmpty ? Icons.mail_outline : Icons.mail_lock_outlined, 
              color: isEmpty ? colors.secondaryText.withAlpha(100) : colors.warning, 
              size: 24
            ),
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
                    color: isEmpty ? colors.primaryText.withAlpha(150) : colors.primaryText,
                  ),
                ),
                Text(
                  isEmpty ? 'No pending requests' : 'Pending identity links',
                  style: AppTypography.caption(context).copyWith(
                    color: colors.secondaryText.withAlpha(100),
                  ),
                ),
              ],
            ),
          ),
          if (!isEmpty)
            GhostBadge(
              label: count.toString(),
              color: colors.warning,
              textColor: Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.black : Colors.white,
            ),
          const SizedBox(width: AppSpacing.s),
          Icon(Icons.chevron_right, color: colors.secondaryText.withAlpha(50)),
        ],
      ),
    );
  }
}
