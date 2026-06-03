import 'package:flutter/material.dart';
import '../../../design_system/components/components.dart';
import '../../../design_system/typography.dart';
import '../../../design_system/spacing.dart';
import '../../../design_system/colors.dart';
import '../contact.dart';

class ContactListItem extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;

  const ContactListItem({
    super.key,
    required this.contact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    return GhostCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      type: GhostSurfaceType.secondary,
      child: Row(
        children: [
          GhostAvatar(
            alias: contact.alias,
            size: 44,
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.alias,
                  style: AppTypography.section(context).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  contact.publicId,
                  style: AppTypography.caption(context).copyWith(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: colors.secondaryText.withAlpha(80),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: colors.secondaryText.withAlpha(50)),
        ],
      ),
    );
  }
}
