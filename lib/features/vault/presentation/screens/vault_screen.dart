import 'package:flutter/material.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/widgets/fade_slide_in.dart';
import 'package:everkeep/widgets/glass/glass_add_tile.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/glass_search_bar.dart';
import 'package:everkeep/widgets/vault_category_card.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = <_VaultCategory>[
      const _VaultCategory(
        icon: Icons.lock_rounded,
        iconColor: AppColors.glassAccentBlue,
        label: 'Passwords',
        count: 24,
      ),
      const _VaultCategory(
        icon: Icons.description_rounded,
        iconColor: AppColors.glassOnSurfaceMuted,
        label: 'Documents',
        count: 11,
      ),
      const _VaultCategory(
        icon: Icons.account_balance_wallet_rounded,
        iconColor: AppColors.glassAccentGreen,
        label: 'Financials',
        count: 6,
      ),
      const _VaultCategory(
        icon: Icons.mail_rounded,
        iconColor: AppColors.glassAccentCrimson,
        label: 'Messages',
        count: 8,
      ),
      const _VaultCategory(
        icon: Icons.photo_library_rounded,
        iconColor: AppColors.glassAccentPink,
        label: 'Memories',
        count: 43,
      ),
    ];

    return GlassScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Vault',
            style: AppTextStyles.serifHeadline.copyWith(
              color: AppColors.glassOnSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '92 items · All encrypted',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.glassOnSurfaceMuted,
            ),
          ),
          const SizedBox(height: 18),
          GlassSearchBar(hintText: 'Search your vault...', onChanged: (_) {}),
          const SizedBox(height: 20),
          VaultGrid(
            cards: [
              for (final entry in categories.asMap().entries)
                FadeSlideIn(
                  index: entry.key,
                  child: VaultCategoryCard(
                    icon: entry.value.icon,
                    iconColor: entry.value.iconColor,
                    label: entry.value.label,
                    count: entry.value.count,
                    onTap: () {
                      final label = entry.value.label;
                      if (label == 'Passwords' || label == 'Financials') {
                        Navigator.of(context).pushNamed(AppRouter.accounts);
                      } else if (label == 'Messages' || label == 'Memories') {
                        Navigator.of(context).pushNamed(AppRouter.wishes);
                      } else {
                        Navigator.of(context).pushNamed(AppRouter.documents);
                      }
                    },
                  ),
                ),
              FadeSlideIn(
                index: categories.length,
                child: GlassAddTile(
                  label: 'Add to Vault',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRouter.documents),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VaultCategory {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int count;

  const _VaultCategory({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.count,
  });
}
