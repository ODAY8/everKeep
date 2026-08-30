import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import 'glass_card.dart';

/// One card in the Home dashboard's 2×2 "Vault Chapters" grid: a tinted
/// icon chip, a title, and a meta line — e.g. "Memories · 142 items saved".
class DashboardGridCard extends StatelessWidget {
  final IconData icon;
  final Color tintColor;
  final String title;
  final String meta;
  final VoidCallback onTap;

  const DashboardGridCard({
    super.key,
    required this.icon,
    required this.tintColor,
    required this.title,
    required this.meta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tintColor.withValues(alpha: 0.14),
              borderRadius: AppRadius.radiusLG,
            ),
            child: Icon(icon, color: tintColor, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.glassOnSurface,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            meta,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.glassOnSurfaceMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// A simple 2-column, fixed-height grid for [DashboardGridCard]s.
class DashboardGrid extends StatelessWidget {
  final List<Widget> cards;

  const DashboardGrid({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) => cards[index],
    );
  }
}
