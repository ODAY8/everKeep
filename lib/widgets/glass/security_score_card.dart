import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import 'glass_card.dart';

/// The dashboard callout summarizing the account's security/vault score —
/// a shield-in-success-green icon, matching Figma's Security screen hero.
/// Tappable to drill into the full [SecurityScreen].
class SecurityScoreCard extends StatelessWidget {
  final String label;
  final String scoreText;
  final double progress;
  final VoidCallback? onTap;

  const SecurityScoreCard({
    Key? key,
    required this.label,
    required this.scoreText,
    required this.progress,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.glassSuccessBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppColors.glassAccentGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.glassOnSurfaceMuted,
                  ),
                ),
                Text(
                  scoreText,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.glassAccentGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: AppRadius.radiusPill,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: AppColors.glassBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.glassAccentGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.glassOnSurfaceFaint),
          ],
        ],
      ),
    );
  }
}
