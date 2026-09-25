import 'package:flutter/foundation.dart';

/// The supported media kinds within a rich Memory.
enum MemoryMediaType {
  photo,
  video,
  audio;

  String get dbValue => name;

  static MemoryMediaType fromString(String? value, {String? mimeType}) {
    final v = value?.trim().toLowerCase();
    if (v == 'photo' || v == 'image') return MemoryMediaType.photo;
    if (v == 'video') return MemoryMediaType.video;
    if (v == 'audio') return MemoryMediaType.audio;

    if (mimeType != null && mimeType.isNotEmpty) {
      final m = mimeType.toLowerCase();
      if (m.startsWith('image/')) return MemoryMediaType.photo;
      if (m.startsWith('video/')) return MemoryMediaType.video;
      if (m.startsWith('audio/')) return MemoryMediaType.audio;
    }
    return MemoryMediaType.photo;
  }
}

/// Represents an individual rich media asset (photo, video, or voice recording)
/// associated with a [MemoryItem].
@immutable
class MemoryMediaItem {
  final String id;
  final String memoryId;
  final String? userId;
  final String filePath;
  final MemoryMediaType mediaType;
  final String mimeType;
  final int fileSize;
  final int displayOrder;
  final String? caption;
  final int? durationSeconds;
  final String? thumbnailPath;
  final DateTime? createdAt;

  const MemoryMediaItem({
    required this.id,
    required this.memoryId,
    this.userId,
    required this.filePath,
    required this.mediaType,
    required this.mimeType,
    required this.fileSize,
    this.displayOrder = 0,
    this.caption,
    this.durationSeconds,
    this.thumbnailPath,
    this.createdAt,
  });

  bool get isPhoto => mediaType == MemoryMediaType.photo;
  bool get isVideo => mediaType == MemoryMediaType.video;
  bool get isAudio => mediaType == MemoryMediaType.audio;

  /// Formatted duration string (e.g. "1:24"), or null if duration is unset.
  String? get formattedDuration {
    if (durationSeconds == null || durationSeconds! < 0) return null;
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Human-friendly display of file size (e.g. "2.4 MB").
  String get formattedFileSize {
    if (fileSize <= 0) return '0 B';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      final kb = fileSize / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = fileSize / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Builds a [MemoryMediaItem] from a `public.memory_media` row.
  factory MemoryMediaItem.fromRow(Map<String, dynamic> row) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    final rawMime = (row['mime_type'] as String?) ?? 'application/octet-stream';
    final rawType = row['media_type'] as String?;

    return MemoryMediaItem(
      id: (row['id'] as String?) ?? '',
      memoryId: (row['memory_id'] as String?) ?? '',
      userId: row['user_id'] as String?,
      filePath: (row['file_path'] as String?) ?? '',
      mediaType: MemoryMediaType.fromString(rawType, mimeType: rawMime),
      mimeType: rawMime,
      fileSize: (row['file_size'] as num?)?.toInt() ?? 0,
      displayOrder: (row['display_order'] as num?)?.toInt() ?? 0,
      caption: row['caption'] as String?,
      durationSeconds: (row['duration_seconds'] as num?)?.toInt(),
      thumbnailPath: row['thumbnail_path'] as String?,
      createdAt: parseDate(row['created_at']),
    );
  }

  /// Synthesizes a [MemoryMediaItem] from a legacy attachment on `memories_wishes`.
  factory MemoryMediaItem.fromLegacy({
    required String filePath,
    int? fileSize,
    String? mimeType,
    String memoryId = '',
    String? userId,
  }) {
    final effectiveMime = mimeType ?? 'application/octet-stream';
    final mediaType = MemoryMediaType.fromString(null, mimeType: effectiveMime);

    return MemoryMediaItem(
      id: 'legacy_$filePath',
      memoryId: memoryId,
      userId: userId,
      filePath: filePath,
      mediaType: mediaType,
      mimeType: effectiveMime,
      fileSize: fileSize ?? 0,
      displayOrder: 0,
    );
  }

  /// Serializes into a map suitable for Supabase insertion.
  Map<String, dynamic> toInsertRow() {
    return {
      'memory_id': memoryId,
      if (userId != null && userId!.isNotEmpty) 'user_id': userId,
      'file_path': filePath,
      'media_type': mediaType.dbValue,
      'mime_type': mimeType,
      'file_size': fileSize,
      'display_order': displayOrder,
      if (caption != null && caption!.trim().isNotEmpty)
        'caption': caption!.trim(),
      if (durationSeconds != null && durationSeconds! >= 0)
        'duration_seconds': durationSeconds,
      if (thumbnailPath != null && thumbnailPath!.isNotEmpty)
        'thumbnail_path': thumbnailPath,
    };
  }

  /// Serializes into a map suitable for updating caption or display order.
  Map<String, dynamic> toUpdateRow() {
    return {
      'display_order': displayOrder,
      'caption': caption?.trim().isEmpty == true ? null : caption?.trim(),
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
    };
  }

  MemoryMediaItem copyWith({
    String? id,
    String? memoryId,
    String? userId,
    String? filePath,
    MemoryMediaType? mediaType,
    String? mimeType,
    int? fileSize,
    int? displayOrder,
    String? caption,
    int? durationSeconds,
    String? thumbnailPath,
    DateTime? createdAt,
  }) {
    return MemoryMediaItem(
      id: id ?? this.id,
      memoryId: memoryId ?? this.memoryId,
      userId: userId ?? this.userId,
      filePath: filePath ?? this.filePath,
      mediaType: mediaType ?? this.mediaType,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      displayOrder: displayOrder ?? this.displayOrder,
      caption: caption ?? this.caption,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemoryMediaItem &&
        other.id == id &&
        other.memoryId == memoryId &&
        other.filePath == filePath &&
        other.mediaType == mediaType &&
        other.displayOrder == displayOrder &&
        other.caption == caption;
  }

  @override
  int get hashCode => Object.hash(id, memoryId, filePath, mediaType, displayOrder, caption);

  @override
  String toString() =>
      'MemoryMediaItem(id: $id, type: ${mediaType.name}, file: $filePath, order: $displayOrder)';
}
