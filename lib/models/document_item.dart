import 'package:flutter/material.dart';

import '../core/utils/relative_time.dart';

class DocumentItem {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final bool isVerified;
  final DateTime? dateAdded;

  /// Where the file lives in Storage (`<user id>/documents/...`), or null for
  /// a document that only has metadata.
  final String? filePath;

  const DocumentItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    this.icon = Icons.description_outlined,
    this.isVerified = false,
    this.dateAdded,
    this.filePath,
  });

  /// Builds a document from a `documents` row. The subtitle ("Legal · Added 2
  /// days ago") is derived from the creation time, so it never goes stale.
  factory DocumentItem.fromRow(Map<String, dynamic> row) {
    final category = row['category'] as String;
    final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
    return DocumentItem(
      id: row['id'] as String,
      title: row['title'] as String,
      subtitle: '$category · Added ${relativeTime(createdAt)}',
      category: category,
      isVerified: row['is_verified'] as bool? ?? false,
      dateAdded: createdAt,
      filePath: row['file_path'] as String?,
    );
  }

  /// The columns a client may write when creating a document. The id, owner,
  /// timestamps and `is_verified` are assigned by the database, never sent.
  Map<String, dynamic> toInsertRow() => {
    'title': title.trim(),
    'category': category,
  };

  DocumentItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? category,
    IconData? icon,
    bool? isVerified,
    DateTime? dateAdded,
    String? filePath,
  }) {
    return DocumentItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      isVerified: isVerified ?? this.isVerified,
      dateAdded: dateAdded ?? this.dateAdded,
      filePath: filePath ?? this.filePath,
    );
  }
}
