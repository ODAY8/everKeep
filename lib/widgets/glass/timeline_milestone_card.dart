import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import 'glass_card.dart';

/// One entry in a vertical milestone timeline (Future Messages): a small
/// accent-ringed node with a connector line, and a card with an avatar,
/// name/meta, an optional trigger banner, and an optional italic preview.
/// [isLast] omits the connector line below the node.
class TimelineMilestoneCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String meta;
  final String? triggerLabel;
  final String? preview;
  final bool isLast;
  final VoidCallback? onTap;

  const TimelineMilestoneCard({
    super.key,
    required this.leading,
    required this.title,
    required this.meta,
    this.triggerLabel,
    this.preview,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.glassIconChipBg,
                    borderRadius: AppRadius.radiusSM,
                    border: Border.all(color: AppColors.glassAccentPink, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.glassBorder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GlassCard(
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        leading,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: AppTextStyles.titleSmall.copyWith(
                                  color: AppColors.glassOnSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                        ),
                      ],
                    ),
                    if (triggerLabel != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.glassIconChipBg,
                          borderRadius: AppRadius.radiusSM,
                        ),
                        child: Text(
                          triggerLabel!,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.glassAccentPink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (preview != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        preview!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.glassOnSurfaceMuted,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
