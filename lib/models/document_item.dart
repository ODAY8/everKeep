import 'package:flutter/material.dart';

import '../core/utils/document_expiration.dart';
import '../core/utils/relative_time.dart';
import 'document_type.dart';

class DocumentItem {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final String? documentType;
  final String? documentNumber;
  final String? country;
  final String? institution;
  final String? notes;
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
    this.documentType,
    this.documentNumber,
    this.country,
    this.institution,
    this.notes,
    this.issueDate,
    this.expiryDate,
    this.icon = Icons.description_outlined,
    this.isVerified = false,
    this.dateAdded,
    this.filePath,
  });

  /// Alias for notes to preserve existing call sites.
  String? get description => notes;

  /// Structured type information derived from [documentType] or [category].
  DocumentType get typeInfo => DocumentType.fromCode(documentType ?? category);

  /// Human-friendly document type label, e.g. "Passport", "Insurance".
  String get displayType => typeInfo.label;

  /// Emoji representing the document type, e.g. 🛂, 🪪, 🎓.
  String get emoji => typeInfo.emoji;

  /// True if the document has a stored file attachment.
  bool get hasFile => filePath != null && filePath!.isNotEmpty;

  /// True if an expiry date is set.
  bool get hasExpiryDate => expiryDate != null;

  /// Expiration status computed by the attention system.
  DocumentExpirationStatus get expirationStatus =>
      DocumentExpirationHelper.statusFor(expiryDate);

  /// True if the document expires soon (within 30 days) and is not yet expired.
  bool get isExpiringSoon =>
      expirationStatus == DocumentExpirationStatus.expiringSoon;

  /// True if the document has passed its expiration date.
  bool get isExpired => expirationStatus == DocumentExpirationStatus.expired;

  /// Human-friendly expiration notice, e.g. "Expires in 21 days".
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
    final docType = row['document_type'] as String?;
    final rawCreatedAt = row['created_at'] as String?;
    final createdAt = rawCreatedAt != null
        ? DateTime.tryParse(rawCreatedAt)?.toLocal()
        : null;

    final typeResolved = DocumentType.fromCode(docType ?? category);
    final displayLabel = typeResolved != DocumentType.other
        ? typeResolved.label
        : category;

    final subtitle = createdAt != null
        ? '$displayLabel · Added ${relativeTime(createdAt)}'
        : displayLabel;

    final resolvedNotes = (row['notes'] as String?) ?? (row['description'] as String?);

    return DocumentItem(
      id: (row['id'] as String?) ?? '',
      title: (row['title'] as String?) ?? '',
      subtitle: subtitle,
      category: category,
      documentType: docType ?? typeResolved.code,
      documentNumber: row['document_number'] as String?,
      country: row['country'] as String?,
      institution: row['institution'] as String?,
      notes: resolvedNotes,
      issueDate: parseDate(row['issue_date']),
      expiryDate: parseDate(row['expiry_date']),
      icon: row['file_path'] == null
          ? typeResolved.icon
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
    if (documentType != null && documentType!.trim().isNotEmpty) {
      row['document_type'] = documentType!.trim();
    }
    if (documentNumber != null && documentNumber!.trim().isNotEmpty) {
      row['document_number'] = documentNumber!.trim();
    }
    if (country != null && country!.trim().isNotEmpty) {
      row['country'] = country!.trim();
    }
    if (institution != null && institution!.trim().isNotEmpty) {
      row['institution'] = institution!.trim();
    }
    if (notes != null && notes!.trim().isNotEmpty) {
      row['notes'] = notes!.trim();
      row['description'] = notes!.trim();
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
    final row = <String, dynamic>{
      'title': title.trim(),
      'category': category,
      'description': (notes ?? description)?.trim(),
      'notes': (notes ?? description)?.trim(),
      'issue_date': issueDate != null ? _formatIsoDate(issueDate!) : null,
      'expiry_date': expiryDate != null ? _formatIsoDate(expiryDate!) : null,
    };
    if (documentType != null) {
      row['document_type'] =
          documentType!.trim().isEmpty ? null : documentType!.trim();
    }
    if (documentNumber != null) {
      row['document_number'] =
          documentNumber!.trim().isEmpty ? null : documentNumber!.trim();
    }
    if (country != null) {
      row['country'] = country!.trim().isEmpty ? null : country!.trim();
    }
    if (institution != null) {
      row['institution'] =
          institution!.trim().isEmpty ? null : institution!.trim();
    }
    return row;
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
    String? documentType,
    String? documentNumber,
    String? country,
    String? institution,
    String? notes,
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
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      country: country ?? this.country,
      institution: institution ?? this.institution,
      notes: notes ?? description ?? this.notes,
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
      icon: icon ?? this.icon,
      isVerified: isVerified ?? this.isVerified,
      dateAdded: dateAdded ?? this.dateAdded,
      filePath: filePath ?? this.filePath,
    );
  }
}
