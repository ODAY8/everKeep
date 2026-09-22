import 'package:flutter/material.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/widgets/glass/glass_card.dart';
import 'package:everkeep/widgets/glass/glass_primary_button.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/status_badge.dart';

/// The Memories tab (routed as AppRouter.wishes).
///
/// Memories and Future Messages aren't built yet. Rather than fill the screen
/// with sample photos and letters that belong to no one, it says so and points
/// at what does work today.
class WishesScreen extends StatelessWidget {
  const WishesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Memories',
            style: AppTextStyles.serifHeadline.copyWith(
              color: AppColors.glassOnSurface,
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.glassAccentPink.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.glassAccentPink,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                const StatusBadge.neutral('Coming soon'),
                const SizedBox(height: 14),
                Text(
                  'Photos, voice notes and letters for the people you love',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.serifTitleSmall.copyWith(
                    color: AppColors.glassOnSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Memories and Future Messages are on the way. Until then, you '
                  'can keep what matters in Documents, and choose who should '
                  'receive it under Trusted People.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.glassOnSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GlassPrimaryButton(
            text: 'Go to Documents',
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRouter.documents),
          ),
          const SizedBox(height: 12),
          GlassOutlineButton(
            text: 'Trusted People',
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRouter.trustedContacts),
          ),
        ],
      ),
    );
  }
}
