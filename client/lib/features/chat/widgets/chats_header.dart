import 'package:flutter/material.dart';
import '../../../design_system/typography.dart';
import '../../../design_system/spacing.dart';
import '../../../design_system/colors.dart';

class ChatsHeader extends StatelessWidget {
  final String alias;

  const ChatsHeader({
    super.key,
    this.alias = 'Ghost',
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getGreeting(),
            style: AppTypography.section(context).copyWith(
              color: AppColors.of(context).secondaryText.withAlpha(150),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            alias,
            style: AppTypography.hero(context),
          ),
        ],
      ),
    );
  }
}
