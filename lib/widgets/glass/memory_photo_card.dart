import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../app_network_image.dart';

/// One photo tile in the Memories masonry grid: a cover photo with a
/// bottom scrim carrying the caption and an "Expand" affordance, given a
/// slight scattered-polaroid tilt per the Figma reference.
class MemoryPhotoCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String date;
  final double height;
  final double rotationDegrees;
  final VoidCallback? onTap;

  const MemoryPhotoCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.height,
    this.rotationDegrees = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotationDegrees * math.pi / 180,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusXL,
            boxShadow: AppShadows.photoCardShadow,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.radiusXL,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppNetworkImage(url: imageUrl),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.55, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              subtitle,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.open_in_full_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Expand',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A simple two-column masonry: items alternate columns and each carries
/// its own height, avoiding a dependency on a staggered-grid package.
class MemoryMasonryGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const MemoryMasonryGrid({
    super.key,
    required this.children,
    this.spacing = 14,
  });

  @override
  Widget build(BuildContext context) {
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      final target = i.isEven ? left : right;
      if (target.isNotEmpty) target.add(SizedBox(height: spacing));
      target.add(children[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: left)),
        SizedBox(width: spacing),
        Expanded(child: Column(children: right)),
      ],
    );
  }
}
