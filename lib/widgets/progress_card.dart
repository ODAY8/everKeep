import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_text_styles.dart';
import 'app_network_image.dart';
import 'circular_progress_ring.dart';

/// The Home dashboard's hero card: a background photo with a directional
/// gradient scrim, legacy-completion copy on the left, and a progress ring
/// on the right — matches the Figma Home hero card.
class ProgressCard extends StatelessWidget {
  final double progress;
  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ProgressCard({
    super.key,
    required this.progress,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(borderRadius: AppRadius.radiusXXL),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppNetworkImage(url: imageUrl, borderRadius: AppRadius.radiusXXL),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.serifTitleSmall.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircularProgressRing(
                    progress: progress,
                    size: 70,
                    strokeWidth: 6,
                    trackColor: Colors.white.withValues(alpha: 0.2),
                    progressGradient: AppColors.glassAccentGradient,
                    child: Text(
                      '$percent%',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
