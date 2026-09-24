import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/memory_item.dart';
import '../../../../providers/memory_provider.dart';
import '../../../../widgets/glass/glass_primary_button.dart';

/// Full-view modal sheet for a Memory or Wish.
/// Displays:
/// - Full title
/// - Full story/content
/// - Date & location
/// - Tags
/// - Media attachment (photo preview or file download card)
/// - Edit action
/// - Delete action
/// - Close button
class MemoryDetailsSheet extends StatefulWidget {
  final MemoryItem item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onOpenAttachment;

  const MemoryDetailsSheet({
    super.key,
    required this.item,
    this.onEdit,
    this.onDelete,
    this.onOpenAttachment,
  });

  @override
  State<MemoryDetailsSheet> createState() => _MemoryDetailsSheetState();
}

class _MemoryDetailsSheetState extends State<MemoryDetailsSheet> {
  String? _previewUrl;
  bool _loadingPreview = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.isPhotoAttachment) {
      _loadPhotoPreview();
    }
  }

  Future<void> _loadPhotoPreview() async {
    setState(() => _loadingPreview = true);
    final provider = context.read<MemoryProvider>();
    final url = await provider.downloadUrlFor(widget.item);
    if (mounted) {
      setState(() {
        _previewUrl = url;
        _loadingPreview = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final accentColor =
        item.isWish ? AppColors.glassWarningColor : AppColors.glassAccentPink;

    final dateDisplay = item.formattedDate ??
        (item.date != null
            ? '${item.date!.year}-${item.date!.month.toString().padLeft(2, '0')}-${item.date!.day.toString().padLeft(2, '0')}'
            : null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with icon, title, and quick action icons
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.16),
                borderRadius: AppRadius.radiusLG,
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Icon(item.icon, color: accentColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTextStyles.serifTitleSmall.copyWith(
                      color: AppColors.glassOnSurface,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.glassOnSurfaceMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onEdit != null)
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.glassOnSurfaceMuted,
                  size: 20,
                ),
                tooltip: 'Edit',
                onPressed: widget.onEdit,
              ),
            if (widget.onDelete != null)
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.glassDestructive,
                  size: 20,
                ),
                tooltip: 'Delete',
                onPressed: widget.onDelete,
              ),
          ],
        ),

        // Date and Location
        if (dateDisplay != null ||
            (item.location != null && item.location!.isNotEmpty)) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              if (dateDisplay != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: AppColors.glassOnSurfaceMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      dateDisplay,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.glassOnSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              if (item.location != null && item.location!.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: AppColors.glassAccentPink,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.location!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.glassOnSurfaceMuted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],

        // Tags
        if (item.tagList.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in item.tagList)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.glassSurfaceRaised,
                    borderRadius: AppRadius.radiusSM,
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    '#$tag',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],

        // Media / Attachment Section
        if (item.hasAttachment) ...[
          const SizedBox(height: 16),
          if (item.isPhotoAttachment && _previewUrl != null)
            ClipRRect(
              borderRadius: AppRadius.radiusMD,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 220),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.glassSurfaceRaised,
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Image.network(
                  _previewUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildAttachmentFallback(item),
                ),
              ),
            )
          else if (_loadingPreview)
            Container(
              height: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.glassSurfaceRaised,
                borderRadius: AppRadius.radiusMD,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            _buildAttachmentFallback(item),
        ],

        // Story / Content
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.glassSurface,
            borderRadius: AppRadius.radiusMD,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.isMemory ? 'STORY' : 'WISH MESSAGE',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.glassOnSurfaceFaint,
                  letterSpacing: 1.1,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (item.content.trim().isNotEmpty)
                Text(
                  item.content,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.glassOnSurface,
                    height: 1.5,
                  ),
                )
              else
                Text(
                  'No details written.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.glassOnSurfaceFaint,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),

        // Action Buttons Row (Edit & Delete secondary options)
        const SizedBox(height: 20),
        Row(
          children: [
            if (widget.onEdit != null) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.glassOnSurface,
                    side: const BorderSide(color: AppColors.glassBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusMD,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: GlassPrimaryButton(
                text: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttachmentFallback(MemoryItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.glassSurfaceRaised,
        borderRadius: AppRadius.radiusMD,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(
            item.isPhotoAttachment
                ? Icons.photo_outlined
                : Icons.attach_file_rounded,
            color: AppColors.glassAccentPink,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.isPhotoAttachment ? 'Attached Photo' : 'Attached File',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.glassOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item.filePath?.split('/').last ?? 'Document attachment',
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
          if (widget.onOpenAttachment != null)
            TextButton(
              onPressed: widget.onOpenAttachment,
              child: const Text('Open'),
            ),
        ],
      ),
    );
  }
}
