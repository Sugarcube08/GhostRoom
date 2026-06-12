import 'package:flutter/material.dart';
import '../colors.dart';
import '../typography.dart';
import '../animations.dart';
import '../haptics.dart';
import '../glass.dart';

class GhostNavItem {
  final IconData outlineIcon;
  final IconData solidIcon;
  final String label;
  final int badgeCount;

  const GhostNavItem({
    required this.outlineIcon,
    required this.solidIcon,
    required this.label,
    this.badgeCount = 0,
  });
}

class GhostNavigationBar extends StatelessWidget {
  final List<GhostNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GhostNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    return GlassContainer(
      borderRadius: 24.0,
      color: colors.elevatedSurface.withAlpha(180),
      borderWidth: 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            return _buildItem(context, index, items[index]);
          }),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, GhostNavItem item) {
    final isSelected = currentIndex == index;
    final colors = AppColors.of(context);
    final activeColor = colors.ghostAccent;
    final inactiveColor = colors.secondaryText.withAlpha(120);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!isSelected) {
          AppHaptics.selection();
          onTap(index);
        }
      },
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.springCurve,
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          color: isSelected 
              ? colors.primaryText.withAlpha(15) 
              : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? item.solidIcon : item.outlineIcon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 24,
                ),
                if (item.badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        item.badgeCount > 9 ? '9+' : item.badgeCount.toString(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onError,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: AppTypography.caption(context).copyWith(
                color: isSelected ? colors.primaryText : inactiveColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 10,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GhostNavigationRail extends StatelessWidget {
  final List<GhostNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GhostNavigationRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: colors.secondaryBackground,
        border: Border(right: BorderSide(color: colors.hairline, width: 1)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Logo placeholder
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.ghostAccent.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(Icons.shield_rounded, color: colors.ghostAccent, size: 24),
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: Column(
                children: List.generate(items.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _buildRailItem(context, index, items[index]),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRailItem(BuildContext context, int index, GhostNavItem item) {
    final isSelected = currentIndex == index;
    final colors = AppColors.of(context);
    final activeColor = colors.ghostAccent;
    final inactiveColor = colors.secondaryText.withAlpha(120);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!isSelected) {
          AppHaptics.selection();
          onTap(index);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: AppAnimations.fast,
                curve: AppAnimations.springCurve,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isSelected 
                      ? colors.ghostAccent.withAlpha(20) 
                      : Colors.transparent,
                ),
                child: Icon(
                  isSelected ? item.solidIcon : item.outlineIcon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 24,
                ),
              ),
              if (item.badgeCount > 0)
                Positioned(
                  top: 0,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      item.badgeCount > 9 ? '9+' : item.badgeCount.toString(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onError,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: AppTypography.caption(context).copyWith(
              color: isSelected ? colors.primaryText : inactiveColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
