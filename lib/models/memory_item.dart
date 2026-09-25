import 'package:flutter/material.dart';

import '../core/utils/relative_time.dart';
import 'memory_media_item.dart';

/// A memory or wish saved in Everkeep.
class MemoryItem {
  final String id;
  final String? userId;
  final String title;
  final String content;
  final String type; // 'memory' or 'wish'
  final DateTime? date;
  final String? location;
  final String? tags;
  final String? filePath;
  final int? fileSize;
  final String? mimeType;
  final List<MemoryMediaItem> media;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MemoryItem({
    required this.id,
    this.userId,
    required this.title,
    required this.content,
    this.type = 'memory',
    this.date,
    this.location,
    this.tags,
    this.filePath,
    this.fileSize,
    this.mimeType,
    this.media = const [],
    this.createdAt,
    this.updatedAt,
  });

  bool get isMemory => type.toLowerCase() == 'memory';
  bool get isWish => type.toLowerCase() == 'wish';
  bool get hasAttachment => filePath != null && filePath!.trim().isNotEmpty;

  /// All media items associated with this memory. If [media] is empty but the
  /// legacy [filePath] is present, synthesizes a single [MemoryMediaItem] for backward compatibility.
  List<MemoryMediaItem> get allMedia {
    if (media.isNotEmpty) return media;
    if (hasAttachment) {
      return [
        MemoryMediaItem.fromLegacy(
          filePath: filePath!,
          fileSize: fileSize,
          mimeType: mimeType,
          memoryId: id,
          userId: userId,
        ),
      ];
    }
    return const [];
  }

  /// All photo items associated with this memory.
  List<MemoryMediaItem> get photos => allMedia.where((m) => m.isPhoto).toList();

  /// All video items associated with this memory.
  List<MemoryMediaItem> get videos => allMedia.where((m) => m.isVideo).toList();

  /// All voice / audio recordings associated with this memory.
  List<MemoryMediaItem> get audioNotes =>
      allMedia.where((m) => m.isAudio).toList();

  /// Primary photo to feature for this memory (first in order), or null if none.
  MemoryMediaItem? get primaryCoverPhoto {
    final photoList = photos;
    return photoList.isNotEmpty ? photoList.first : null;
  }

  /// Total count of media items, including legacy attachment fallback.
  int get totalMediaCount => allMedia.length;

  /// Alias for content representing the story behind the memory.
  String get story => content;

  /// Parsed list of tags.
  List<String> get tagList => (tags ?? '')
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  /// True if attachment is likely an image.
  bool get isPhotoAttachment {
    if (!hasAttachment) return false;
    final mime = mimeType?.toLowerCase() ?? '';
    final path = filePath?.toLowerCase() ?? '';
    return mime.startsWith('image/') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp');
  }

  /// Human-readable type label.
  String get typeLabel => isMemory ? 'Memory' : 'Wish';

  /// Icon representing this item.
  IconData get icon {
    if (hasAttachment) return Icons.attach_file_rounded;
    return isMemory ? Icons.favorite_rounded : Icons.auto_awesome_rounded;
  }

  /// Subtitle shown in list rows.
  String get subtitle {
    final typeName = isMemory ? 'Memory' : 'Wish';
    if (createdAt != null) {
      return '$typeName · Added ${relativeTime(createdAt!)}';
    }
    return typeName;
  }

  /// Compact preview of the story for cards and list views.
  String get shortStoryPreview {
    final clean = content.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length <= 110) return clean;
    return '${clean.substring(0, 107)}...';
  }

  /// Human-formatted date for the memory (e.g. 'Oct 14, 2024').
  String? get formattedDate {
    if (date == null) return null;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date!.month - 1]} ${date!.day}, ${date!.year}';
  }

  /// Date used for Life Timeline positioning: user-entered memory date first,
  /// falling back to createdAt or epoch.
  DateTime get timelineDate => date ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Checks if this item matches a search query across title, content, tags, location, or date.
  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (title.toLowerCase().contains(q)) return true;
    if (content.toLowerCase().contains(q)) return true;
    if (location != null && location!.toLowerCase().contains(q)) return true;
    if (tags != null && tags!.toLowerCase().contains(q)) return true;
    if (formattedDate != null && formattedDate!.toLowerCase().contains(q)) return true;
    if (date != null) {
      if (date!.year.toString().contains(q)) return true;
      const fullMonths = [
        'january', 'february', 'march', 'april', 'may', 'june',
        'july', 'august', 'september', 'october', 'november', 'december'
      ];
      if (fullMonths[date!.month - 1].contains(q)) return true;
    }
    return false;
  }

  /// Checks whether this memory has a specific tag.
  bool hasTag(String tag) {
    final target = tag.trim().toLowerCase().replaceAll('#', '');
    return tagList.any((t) => t.toLowerCase() == target);
  }

  /// Builds a [MemoryItem] from a `memories_wishes` table row (optionally joined with `memory_media`).
  factory MemoryItem.fromRow(Map<String, dynamic> row) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    List<MemoryMediaItem> parsedMedia = const [];
    if (row['memory_media'] is List) {
      final rawList = row['memory_media'] as List;
      parsedMedia = rawList
          .whereType<Map<String, dynamic>>()
          .map(MemoryMediaItem.fromRow)
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    }

    return MemoryItem(
      id: row['id'] as String,
      userId: row['user_id'] as String?,
      title: (row['title'] as String?) ?? '',
      content: (row['content'] as String?) ?? '',
      type: (row['type'] as String?) ?? 'memory',
      date: parseDate(row['date']),
      location: row['location'] as String?,
      tags: row['tags'] as String?,
      filePath: row['file_path'] as String?,
      fileSize: (row['file_size'] as num?)?.toInt(),
      mimeType: row['mime_type'] as String?,
      media: parsedMedia,
      createdAt: parseDate(row['created_at']),
      updatedAt: parseDate(row['updated_at']),
    );
  }

  /// Columns written when inserting a new memory or wish.
  Map<String, dynamic> toInsertRow() {
    final row = <String, dynamic>{
      'title': title.trim(),
      'content': content.trim(),
      'type': type.toLowerCase(),
    };
    if (userId != null && userId!.trim().isNotEmpty) {
      row['user_id'] = userId!.trim();
    }
    if (date != null) {
      row['date'] =
          '${date!.year.toString().padLeft(4, '0')}-'
          '${date!.month.toString().padLeft(2, '0')}-'
          '${date!.day.toString().padLeft(2, '0')}';
    }
    if (location != null && location!.trim().isNotEmpty) {
      row['location'] = location!.trim();
    }
    if (tags != null && tags!.trim().isNotEmpty) {
      row['tags'] = tags!.trim();
    }
    if (filePath != null) row['file_path'] = filePath;
    if (fileSize != null) row['file_size'] = fileSize;
    if (mimeType != null) row['mime_type'] = mimeType;
    return row;
  }

  /// Columns written when updating an existing memory or wish.
  Map<String, dynamic> toUpdateRow() {
    final row = <String, dynamic>{
      'title': title.trim(),
      'content': content.trim(),
      'type': type.toLowerCase(),
      'date': date != null
          ? '${date!.year.toString().padLeft(4, '0')}-'
            '${date!.month.toString().padLeft(2, '0')}-'
            '${date!.day.toString().padLeft(2, '0')}'
          : null,
      'file_path': filePath,
      'file_size': fileSize,
      'mime_type': mimeType,
    };
    if (location != null) {
      row['location'] = location!.trim();
    }
    if (tags != null) {
      row['tags'] = tags!.trim();
    }
    return row;
  }

  MemoryItem copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    String? type,
    DateTime? date,
    String? location,
    String? tags,
    String? filePath,
    int? fileSize,
    String? mimeType,
    List<MemoryMediaItem>? media,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MemoryItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      date: date ?? this.date,
      location: location ?? this.location,
      tags: tags ?? this.tags,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      media: media ?? this.media,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
