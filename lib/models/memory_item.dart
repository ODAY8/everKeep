import 'package:flutter/material.dart';

import '../core/utils/relative_time.dart';

/// A memory or wish saved in Everkeep.
class MemoryItem {
  final String id;
  final String title;
  final String content;
  final String type; // 'memory' or 'wish'
  final DateTime? date;
  final String? location;
  final String? tags;
  final String? filePath;
  final int? fileSize;
  final String? mimeType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MemoryItem({
    required this.id,
    required this.title,
    required this.content,
    this.type = 'memory',
    this.date,
    this.location,
    this.tags,
    this.filePath,
    this.fileSize,
    this.mimeType,
    this.createdAt,
    this.updatedAt,
  });

  bool get isMemory => type.toLowerCase() == 'memory';
  bool get isWish => type.toLowerCase() == 'wish';
  bool get hasAttachment => filePath != null && filePath!.trim().isNotEmpty;

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

  /// Builds a [MemoryItem] from a `memories_wishes` table row.
  factory MemoryItem.fromRow(Map<String, dynamic> row) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    return MemoryItem(
      id: row['id'] as String,
      title: (row['title'] as String?) ?? '',
      content: (row['content'] as String?) ?? '',
      type: (row['type'] as String?) ?? 'memory',
      date: parseDate(row['date']),
      location: row['location'] as String?,
      tags: row['tags'] as String?,
      filePath: row['file_path'] as String?,
      fileSize: (row['file_size'] as num?)?.toInt(),
      mimeType: row['mime_type'] as String?,
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
    String? title,
    String? content,
    String? type,
    DateTime? date,
    String? location,
    String? tags,
    String? filePath,
    int? fileSize,
    String? mimeType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MemoryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      date: date ?? this.date,
      location: location ?? this.location,
      tags: tags ?? this.tags,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
