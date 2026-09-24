import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../models/memory_item.dart';
import '../../../../widgets/glass/glass_card.dart';

/// A rich, polished card representing a memory or wish in the list.
/// Displays:
/// - Title
/// - Short story preview
/// - Memory date (and location if set)
/// - Tags
/// - Media indicator where applicable
class MemoryCard extends StatelessWidget {
  final MemoryItem item;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  const MemoryCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor =
        item.isWish ? AppColors.glassWarningColor : AppColors.glassAccentPink;

    final dateDisplay = item.formattedDate ??
        (item.createdAt != null ? relativeTime(item.createdAt!) : null);

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: AppRadius.radiusMD,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  item.hasAttachment
                      ? (item.isPhotoAttachment
                          ? Icons.photo_camera_back_outlined
                          : Icons.attach_file_rounded)
                      : (item.isWish
                          ? Icons.auto_awesome_rounded
                          : Icons.favorite_rounded),
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.glassOnSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dateDisplay != null ||
                        (item.location != null &&
                            item.location!.trim().isNotEmpty)) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (dateDisplay != null) ...[
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 12,
                              color: AppColors.glassOnSurfaceMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateDisplay,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.glassOnSurfaceMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          if (item.location != null &&
                              item.location!.trim().isNotEmpty) ...[
                            if (dateDisplay != null) ...[
                              const SizedBox(width: 8),
                              const Text(
                                '•',
                                style: TextStyle(
                                  color: AppColors.glassOnSurfaceFaint,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            const Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: AppColors.glassAccentPink,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                item.location!,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.glassOnSurfaceMuted,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (item.hasAttachment)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.glassSurfaceRaised,
                    borderRadius: AppRadius.radiusSM,
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.isPhotoAttachment
                            ? Icons.image_outlined
                            : Icons.attach_file_rounded,
                        size: 11,
                        color: accentColor,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        item.isPhotoAttachment ? 'Photo' : 'File',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (onMore != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onMore,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.glassOnSurfaceFaint,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (item.content.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '“${item.shortStoryPreview}”',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.glassOnSurfaceMuted,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (item.tagList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tag in item.tagList.take(3))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.glassSurfaceRaised,
                      borderRadius: AppRadius.radiusSM,
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Text(
                      '#$tag',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.glassOnSurfaceMuted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                if (item.tagList.length > 3)
                  Text(
                    '+${item.tagList.length - 3}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.glassOnSurfaceFaint,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
