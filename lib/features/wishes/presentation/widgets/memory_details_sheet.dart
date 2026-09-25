import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/memory_item.dart';
import '../../../../models/memory_media_item.dart';
import '../../../../providers/memory_provider.dart';
import '../../../../widgets/glass/glass_primary_button.dart';
import 'full_screen_photo_viewer.dart';

/// Full-view modal sheet for a Memory or Wish.
/// Displays:
/// - Full title
/// - Full story/content
/// - Date & location
/// - Tags
/// - Rich Media Gallery (Photos, Videos, Audio) and legacy attachments
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
  final Map<String, String> _signedUrls = {};
  bool _loadingMedia = false;

  @override
  void initState() {
    super.initState();
    _loadMediaUrls();
  }

  Future<void> _loadMediaUrls() async {
    final photos = widget.item.photos;
    if (photos.isEmpty) return;

    setState(() => _loadingMedia = true);
    final provider = context.read<MemoryProvider>();

    for (final photo in photos) {
      try {
        final url = await provider.createSignedUrl(photo.filePath);
        if (url != null && mounted) {
          setState(() {
            _signedUrls[photo.filePath] = url;
          });
        }
      } catch (_) {
        // Handled via per-item error fallbacks in UI
      }
    }

    if (mounted) {
      setState(() => _loadingMedia = false);
    }
  }

  void _openPhotoViewer(int initialIndex) {
    FullScreenPhotoViewer.show(
      context,
      photos: widget.item.photos,
      initialIndex: initialIndex,
      signedUrls: _signedUrls,
    );
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

        // Rich Media Gallery & Attachments Section
        if (item.allMedia.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildMediaSection(accentColor),
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

  /// Builds the complete rich media section: photo previews, carousel strip,
  /// video tiles, voice notes, or legacy document fallbacks.
  Widget _buildMediaSection(Color accentColor) {
    final item = widget.item;
    final photos = item.photos;
    final videos = item.videos;
    final audioNotes = item.audioNotes;
    final totalCount = item.totalMediaCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with Media Counter badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'MEDIA ARCHIVE',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.glassOnSurfaceFaint,
                letterSpacing: 1.1,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (totalCount > 1)
              Semantics(
                label: 'Total media: $totalCount items',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: AppRadius.radiusSM,
                    border:
                        Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$totalCount media',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // 1. Primary Photo Display
        if (photos.isNotEmpty) ...[
          _buildPrimaryPhotoCard(photos.first),
          // Additional Photos Horizontal Strip
          if (photos.length > 1) ...[
            const SizedBox(height: 10),
            _buildPhotosThumbnailStrip(photos),
          ],
        ],

        // 2. Video Placeholders
        if (videos.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final video in videos) _buildVideoPlaceholderCard(video),
        ],

        // 3. Audio / Voice Note Placeholders
        if (audioNotes.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final audio in audioNotes) _buildAudioPlaceholderCard(audio),
        ],

        // 4. Non-Media Documents (Legacy fallbacks)
        if (photos.isEmpty &&
            videos.isEmpty &&
            audioNotes.isEmpty &&
            item.hasAttachment) ...[
          _buildAttachmentFallback(item),
        ],
      ],
    );
  }

  /// Prominent primary cover photo with tap-to-expand full screen viewer.
  Widget _buildPrimaryPhotoCard(MemoryMediaItem primaryPhoto) {
    final url = _signedUrls[primaryPhoto.filePath];

    return Semantics(
      label:
          'Primary photo: ${primaryPhoto.caption ?? "Memory photo"}, tap to view full screen',
      button: true,
      child: GestureDetector(
        onTap: () => _openPhotoViewer(0),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            color: AppColors.glassSurfaceRaised,
            borderRadius: AppRadius.radiusMD,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.radiusMD,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                if (url != null)
                  Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return _buildMediaLoadingContainer();
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPhotoErrorFallback(primaryPhoto),
                  )
                else if (_loadingMedia)
                  _buildMediaLoadingContainer()
                else
                  _buildPhotoErrorFallback(primaryPhoto),

                // Expand Icon Badge in top-right
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),

                // Optional Caption Overlay
                if (primaryPhoto.caption != null &&
                    primaryPhoto.caption!.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Text(
                        primaryPhoto.caption!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Horizontal scrolling strip showing thumbnail previews of all photos.
  Widget _buildPhotosThumbnailStrip(List<MemoryMediaItem> photos) {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final photo = photos[index];
          final url = _signedUrls[photo.filePath];

          return Semantics(
            label:
                'Photo ${index + 1} of ${photos.length}, tap to view full screen',
            button: true,
            child: GestureDetector(
              onTap: () => _openPhotoViewer(index),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.glassSurfaceRaised,
                  borderRadius: AppRadius.radiusSM,
                  border: Border.all(
                    color: index == 0
                        ? AppColors.glassAccentPink
                        : AppColors.glassBorder,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: AppRadius.radiusSM,
                  child: url != null
                      ? Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stack) => const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 20,
                              color: AppColors.glassOnSurfaceMuted,
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.photo_outlined,
                            size: 20,
                            color: AppColors.glassOnSurfaceMuted,
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Clean video placeholder indicating attached video asset.
  Widget _buildVideoPlaceholderCard(MemoryMediaItem video) {
    final metaText = [
      if (video.formattedDuration != null) video.formattedDuration!,
      video.formattedFileSize,
    ].join(' · ');

    return Semantics(
      label:
          'Video attachment: ${video.caption ?? "Video clip"}, size: ${video.formattedFileSize}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.glassSurfaceRaised,
          borderRadius: AppRadius.radiusMD,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.glassAccentBlue.withValues(alpha: 0.15),
                borderRadius: AppRadius.radiusSM,
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: AppColors.glassAccentBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.caption?.isNotEmpty == true
                        ? video.caption!
                        : 'Video Clip',
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
                    metaText,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.glassOnSurfaceMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.glassSurface,
                borderRadius: AppRadius.radiusSM,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Text(
                'VIDEO',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.glassAccentBlue,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Clean audio/voice recording placeholder indicating attached audio asset.
  Widget _buildAudioPlaceholderCard(MemoryMediaItem audio) {
    final metaText = [
      if (audio.formattedDuration != null) audio.formattedDuration!,
      audio.formattedFileSize,
    ].join(' · ');

    return Semantics(
      label:
          'Voice recording attachment: ${audio.caption ?? "Audio clip"}, size: ${audio.formattedFileSize}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.glassSurfaceRaised,
          borderRadius: AppRadius.radiusMD,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.glassAccentPink.withValues(alpha: 0.15),
                borderRadius: AppRadius.radiusSM,
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: AppColors.glassAccentPink,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audio.caption?.isNotEmpty == true
                        ? audio.caption!
                        : 'Voice Recording',
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
                    metaText,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.glassOnSurfaceMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.glassSurface,
                borderRadius: AppRadius.radiusSM,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Text(
                'AUDIO',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.glassAccentPink,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaLoadingContainer() {
    return Container(
      height: 120,
      alignment: Alignment.center,
      color: AppColors.glassSurfaceRaised,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildPhotoErrorFallback(MemoryMediaItem photo) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            color: AppColors.glassOnSurfaceMuted,
            size: 28,
          ),
          const SizedBox(height: 6),
          Text(
            'Photo unavailable',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.glassOnSurfaceMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
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
