import 'package:flutter/material.dart';
import '../colors.dart';
import '../typography.dart';

class GhostAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? alias;
  final double size;
  final Color? backgroundColor;

  const GhostAvatar({
    super.key,
    this.imageUrl,
    this.alias,
    this.size = 40,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.elevatedSurface,
        shape: BoxShape.circle,
        border: Border.all(color: colors.hairline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(context),
      );
    }
    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    final colors = AppColors.of(context);
    if (alias != null && alias!.isNotEmpty) {
      final initial = alias![0].toUpperCase();
      return Center(
        child: Text(
          initial,
          style: AppTypography.body(context).copyWith(
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      );
    }
    return Icon(Icons.person, color: colors.textMuted);
  }
}
