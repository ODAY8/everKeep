import 'package:flutter/material.dart';

import '../core/utils/document_expiration.dart';
import '../core/utils/relative_time.dart';

class DocumentItem {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final String? description;
  final DateTime? issueDate;
  final DateTime? expiryDate;
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
    this.description,
    this.issueDate,
    this.expiryDate,
    this.icon = Icons.description_outlined,
    this.isVerified = false,
    this.dateAdded,
    this.filePath,
  });

  /// Alias for description.
  String? get notes => description;

  /// Expiration status computed by the attention system.
  DocumentExpirationStatus get expirationStatus =>
      DocumentExpirationHelper.statusFor(expiryDate);

  /// True if the document expires soon (within 90 days) and is not yet expired.
  bool get isExpiringSoon =>
      expirationStatus == DocumentExpirationStatus.expiringSoon;

  /// True if the document has passed its expiration date.
  bool get isExpired => expirationStatus == DocumentExpirationStatus.expired;

  /// Human-friendly expiration notice, e.g. "Expires in 87 days".
  String get expirationNotice =>
      DocumentExpirationHelper.descriptiveNotice(expiryDate);

  /// Builds a document from a `documents` row. The subtitle ("Legal · Added 2
  /// days ago") is derived from the creation time, so it never goes stale.
  factory DocumentItem.fromRow(Map<String, dynamic> row) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    final category = (row['category'] as String?) ?? 'Other';
    final rawCreatedAt = row['created_at'] as String?;
    final createdAt = rawCreatedAt != null
        ? DateTime.tryParse(rawCreatedAt)?.toLocal()
        : null;

    final subtitle = createdAt != null
        ? '$category · Added ${relativeTime(createdAt)}'
        : category;

    return DocumentItem(
      id: (row['id'] as String?) ?? '',
      title: (row['title'] as String?) ?? '',
      subtitle: subtitle,
      category: category,
      description: row['description'] as String?,
      issueDate: parseDate(row['issue_date']),
      expiryDate: parseDate(row['expiry_date']),
      icon: row['file_path'] == null
          ? Icons.description_outlined
          : Icons.attach_file_rounded,
      isVerified: row['is_verified'] as bool? ?? false,
      dateAdded: createdAt,
      filePath: row['file_path'] as String?,
    );
  }

  /// The columns a client may write when creating a document.
  Map<String, dynamic> toInsertRow() {
    final row = <String, dynamic>{
      'title': title.trim(),
      'category': category,
    };
    if (description != null && description!.trim().isNotEmpty) {
      row['description'] = description!.trim();
    }
    if (issueDate != null) {
      row['issue_date'] = _formatIsoDate(issueDate!);
    }
    if (expiryDate != null) {
      row['expiry_date'] = _formatIsoDate(expiryDate!);
    }
    return row;
  }

  /// The columns written when updating a document.
  Map<String, dynamic> toUpdateRow() {
    return {
      'title': title.trim(),
      'category': category,
      'description': description?.trim(),
      'issue_date': issueDate != null ? _formatIsoDate(issueDate!) : null,
      'expiry_date': expiryDate != null ? _formatIsoDate(expiryDate!) : null,
    };
  }

  static String _formatIsoDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  DocumentItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? category,
    String? description,
    DateTime? issueDate,
    DateTime? expiryDate,
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
      description: description ?? this.description,
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
      icon: icon ?? this.icon,
      isVerified: isVerified ?? this.isVerified,
      dateAdded: dateAdded ?? this.dateAdded,
      filePath: filePath ?? this.filePath,
    );
  }
}
