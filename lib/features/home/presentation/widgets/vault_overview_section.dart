import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/greeting.dart';
import '../../../../models/vault_summary.dart';
import '../../../../providers/vault_provider.dart';
import '../../../../widgets/fade_slide_in.dart';
import '../../../../widgets/glass/glass_card.dart';

/// The "Your Vault" overview on the Dashboard.
/// Displays live counters for Documents, Memories, Trusted Contacts, and Important Info.
class VaultOverviewSection extends StatelessWidget {
  const VaultOverviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Vault',
              style: AppTextStyles.serifLabel.copyWith(
                color: AppColors.glassOnSurface,
                fontSize: 18,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pushNamed(AppRouter.vault),
              behavior: HitTestBehavior.opaque,
              child: Text(
                'Explore all',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.glassAccentPink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Selector<VaultProvider, VaultSummary>(
          selector: (_, vault) => vault.vaultSummary,
          builder: (context, summary, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 12) / 2;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FadeSlideIn(
                      index: 0,
                      child: _VaultMetricCard(
                        width: cardWidth,
                        icon: Icons.description_outlined,
                        tintColor: AppColors.glassAccentSecondary,
                        title: 'Documents',
                        count: summary.documentsCount,
                        meta:
                            '${countLabel(summary.documentsCount, 'file', 'files')} stored',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRouter.documents),
                      ),
                    ),
                    FadeSlideIn(
                      index: 1,
                      child: _VaultMetricCard(
                        width: cardWidth,
                        icon: Icons.favorite_rounded,
                        tintColor: AppColors.glassAccentPink,
                        title: 'Memories',
                        count: summary.memoriesCount,
                        meta: countLabel(
                          summary.memoriesCount,
                          'memory',
                          'memories',
                        ),
                        onTap: () =>
                            Navigator.of(context).pushNamed(AppRouter.wishes),
                      ),
                    ),
                    FadeSlideIn(
                      index: 2,
                      child: _VaultMetricCard(
                        width: cardWidth,
                        icon: Icons.people_outline_rounded,
                        tintColor: AppColors.glassAccentGreen,
                        title: 'Trusted Contacts',
                        count: summary.trustedContactsCount,
                        meta: countLabel(
                          summary.trustedContactsCount,
                          'trustee',
                          'trustees',
                        ),
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRouter.trustedContacts),
                      ),
                    ),
                    FadeSlideIn(
                      index: 3,
                      child: _VaultMetricCard(
                        width: cardWidth,
                        icon: Icons.lock_outline_rounded,
                        tintColor: AppColors.glassAccentBlue,
                        title: 'Important Info',
                        count: summary.accountsCount,
                        meta:
                            '${countLabel(summary.accountsCount, 'login', 'logins')} saved',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRouter.accounts),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _VaultMetricCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final Color tintColor;
  final String title;
  final int count;
  final String meta;
  final VoidCallback onTap;

  const _VaultMetricCard({
    required this.width,
    required this.icon,
    required this.tintColor,
    required this.title,
    required this.count,
    required this.meta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tintColor.withValues(alpha: 0.14),
                    borderRadius: AppRadius.radiusSM,
                  ),
                  child: Icon(icon, color: tintColor, size: 18),
                ),
                Text(
                  count.toString(),
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.glassOnSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.glassOnSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              meta,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.glassOnSurfaceMuted,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
