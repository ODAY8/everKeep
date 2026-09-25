import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/document_upload.dart';
import '../../../../models/memory_media_item.dart';

/// Form model representing an item in the Create/Edit memory media tray.
class FormMediaItem {
  final String localKey;
  final MemoryMediaItem? existingItem;
  final DocumentUpload? pendingUpload;
  final MemoryMediaType mediaType;
  final String fileName;
  final int fileSize;
  String? caption;
  int? durationSeconds;
  final Uint8List? previewBytes;

  FormMediaItem.existing(MemoryMediaItem item)
      : localKey = 'existing_${item.id}',
        existingItem = item,
        pendingUpload = null,
        mediaType = item.mediaType,
        fileName = item.filePath.split('/').last,
        fileSize = item.fileSize,
        caption = item.caption,
        durationSeconds = item.durationSeconds,
        previewBytes = null;

  FormMediaItem.pending({
    required this.pendingUpload,
    required this.mediaType,
    this.caption,
    this.durationSeconds,
    this.previewBytes,
  })  : localKey =
            'pending_${DateTime.now().microsecondsSinceEpoch}_${pendingUpload!.fileName}',
        existingItem = null,
        fileName = pendingUpload.fileName,
        fileSize = pendingUpload.bytes.length;

  bool get isExisting => existingItem != null;
  bool get isPending => pendingUpload != null;
  bool get isPhoto => mediaType == MemoryMediaType.photo;
  bool get isVideo => mediaType == MemoryMediaType.video;
  bool get isAudio => mediaType == MemoryMediaType.audio;
}

String formatMediaFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String formatMediaDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// A preview tray displaying selected and existing media items before saving.
/// Supports reordering, captions, remove actions, and indicates the cover photo.
class MemoryMediaTray extends StatelessWidget {
  final List<FormMediaItem> items;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final void Function(int index)? onMoveUp;
  final void Function(int index)? onMoveDown;
  final void Function(int index) onRemove;
  final void Function(int index, String? caption) onCaptionChanged;
  final bool enabled;

  const MemoryMediaTray({
    super.key,
    required this.items,
    this.onReorder,
    this.onMoveUp,
    this.onMoveDown,
    required this.onRemove,
    required this.onCaptionChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    // Find the first photo index to mark as primary/cover
    final firstPhotoIndex = items.indexWhere((item) => item.isPhoto);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _MediaItemCard(
            key: ValueKey(items[i].localKey),
            item: items[i],
            index: i,
            totalItems: items.length,
            isPrimaryCover: i == firstPhotoIndex,
            enabled: enabled,
            onMoveUp: onMoveUp != null && i > 0 ? () => onMoveUp!(i) : null,
            onMoveDown: onMoveDown != null && i < items.length - 1
                ? () => onMoveDown!(i)
                : null,
            onRemove: () => onRemove(i),
            onCaptionChanged: (caption) => onCaptionChanged(i, caption),
          ),
          if (i < items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MediaItemCard extends StatefulWidget {
  final FormMediaItem item;
  final int index;
  final int totalItems;
  final bool isPrimaryCover;
  final bool enabled;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onRemove;
  final ValueChanged<String?> onCaptionChanged;

  const _MediaItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.totalItems,
    required this.isPrimaryCover,
    required this.enabled,
    this.onMoveUp,
    this.onMoveDown,
    required this.onRemove,
    required this.onCaptionChanged,
  });

  @override
  State<_MediaItemCard> createState() => _MediaItemCardState();
}

class _MediaItemCardState extends State<_MediaItemCard> {
  late final TextEditingController _captionController;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.item.caption ?? '');
  }

  @override
  void didUpdateWidget(covariant _MediaItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.caption != widget.item.caption &&
        _captionController.text != (widget.item.caption ?? '')) {
      _captionController.text = widget.item.caption ?? '';
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassSurfaceRaised,
        borderRadius: AppRadius.radiusMD,
        border: Border.all(
          color: widget.isPrimaryCover
              ? AppColors.glassAccentPink.withValues(alpha: 0.6)
              : AppColors.glassBorder,
          width: widget.isPrimaryCover ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary/Cover Photo Badge
          if (widget.isPrimaryCover) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.glassAccentPink.withValues(alpha: 0.2),
                borderRadius: AppRadius.radiusSM,
                border: Border.all(
                  color: AppColors.glassAccentPink.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: AppColors.glassAccentPink,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Primary Cover Photo',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.glassAccentPink,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Main Header Row: Thumbnail + Info + Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Media Thumbnail / Icon
              _buildThumbnail(item),
              const SizedBox(width: 10),

              // Info: Type Pill, File Name, Meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildMediaTypePill(item.mediaType),
                        const SizedBox(width: 6),
                        if (item.isExisting)
                          Text(
                            'Saved',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.glassOnSurfaceMuted,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.fileName,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.glassOnSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatMediaFileSize(item.fileSize)}${item.durationSeconds != null ? ' • ${formatMediaDuration(item.durationSeconds!)}' : ''}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.glassOnSurfaceMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Reorder Buttons
              if (widget.totalItems > 1) ...[
                IconButton(
                  tooltip: 'Move up',
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  color: widget.onMoveUp != null && widget.enabled
                      ? AppColors.glassOnSurface
                      : AppColors.glassOnSurfaceFaint,
                  onPressed: widget.enabled ? widget.onMoveUp : null,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  tooltip: 'Move down',
                  icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                  color: widget.onMoveDown != null && widget.enabled
                      ? AppColors.glassOnSurface
                      : AppColors.glassOnSurfaceFaint,
                  onPressed: widget.enabled ? widget.onMoveDown : null,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],

              // Remove Button
              IconButton(
                tooltip: 'Remove media',
                icon: const Icon(Icons.close_rounded, size: 18),
                color: widget.enabled
                    ? AppColors.glassDestructive
                    : AppColors.glassOnSurfaceFaint,
                onPressed: widget.enabled ? widget.onRemove : null,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Caption Field
          TextField(
            controller: _captionController,
            enabled: widget.enabled,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.glassOnSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Add a caption (optional)...',
              hintStyle: AppTextStyles.bodySmall.copyWith(
                color: AppColors.glassOnSurfaceFaint,
              ),
              isDense: true,
              filled: true,
              fillColor: AppColors.glassSurface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: AppRadius.radiusSM,
                borderSide: const BorderSide(color: AppColors.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.radiusSM,
                borderSide: const BorderSide(color: AppColors.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.radiusSM,
                borderSide: const BorderSide(color: AppColors.glassAccentPink),
              ),
            ),
            onChanged: (val) {
              final trimmed = val.trim();
              widget.item.caption = trimmed.isEmpty ? null : trimmed;
              widget.onCaptionChanged(trimmed.isEmpty ? null : trimmed);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(FormMediaItem item) {
    if (item.isPhoto && item.previewBytes != null) {
      return ClipRRect(
        borderRadius: AppRadius.radiusSM,
        child: Image.memory(
          item.previewBytes!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildPlaceholderIcon(Icons.photo),
        ),
      );
    }

    if (item.isPhoto) {
      return _buildPlaceholderIcon(Icons.photo_outlined);
    } else if (item.isVideo) {
      return _buildPlaceholderIcon(Icons.videocam_rounded);
    } else {
      return _buildPlaceholderIcon(Icons.mic_rounded);
    }
  }

  Widget _buildPlaceholderIcon(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: AppRadius.radiusSM,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Center(
        child: Icon(
          icon,
          color: AppColors.glassAccentPink,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildMediaTypePill(MemoryMediaType type) {
    final label = type.name.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.glassOnSurfaceMuted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Panel providing inline voice recording controls with live duration timer.
class VoiceRecordingPanel extends StatelessWidget {
  final int durationSeconds;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  const VoiceRecordingPanel({
    super.key,
    required this.durationSeconds,
    required this.onStop,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.glassSurfaceRaised,
        borderRadius: AppRadius.radiusMD,
        border: Border.all(
          color: AppColors.glassDestructive.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Pulsing red indicator
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.glassDestructive,
            ),
          ),
          const SizedBox(width: 12),

          // Duration and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recording Audio...',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.glassDestructive,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatMediaDuration(durationSeconds),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.glassOnSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),

          // Stop Button
          ElevatedButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop_rounded, size: 18),
            label: const Text('Stop'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.glassDestructive,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSM),
            ),
          ),
          const SizedBox(width: 8),

          // Cancel Button
          IconButton(
            tooltip: 'Cancel recording',
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.glassOnSurfaceMuted,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
