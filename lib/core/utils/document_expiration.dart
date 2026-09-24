import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Expiration category for documents.
enum DocumentExpirationStatus {
  expired,
  expiringSoon,
  valid,
  noExpiryDate;

  bool get isActive => this == DocumentExpirationStatus.valid;
  bool get isExpiringSoon => this == DocumentExpirationStatus.expiringSoon;
  bool get isExpired => this == DocumentExpirationStatus.expired;
  bool get isNone => this == DocumentExpirationStatus.noExpiryDate;
}

/// Reusable utility for calculating and displaying document expiration states.
class DocumentExpirationHelper {
  DocumentExpirationHelper._();

  /// Default threshold for warning about an impending expiration (30 days).
  static const int defaultExpiringSoonDays = 30;

  /// Calculates the difference in full calendar days between [date] and [now].
  /// Compares dates by day (ignoring time components).
  static int daysUntil(DateTime date, [DateTime? now]) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  /// Determines the status of [expiryDate].
  static DocumentExpirationStatus statusFor(
    DateTime? expiryDate, {
    DateTime? now,
    int thresholdDays = defaultExpiringSoonDays,
  }) {
    if (expiryDate == null) return DocumentExpirationStatus.noExpiryDate;
    final days = daysUntil(expiryDate, now);
    if (days < 0) return DocumentExpirationStatus.expired;
    if (days <= thresholdDays) return DocumentExpirationStatus.expiringSoon;
    return DocumentExpirationStatus.valid;
  }

  /// Short relative text for badges and chips, e.g. "87 days", "Expired", "Today".
  static String shortLabel(DateTime? expiryDate, [DateTime? now]) {
    if (expiryDate == null) return 'No expiry';
    final days = daysUntil(expiryDate, now);
    if (days < 0) return 'Expired';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return '$days days';
  }

  /// Human-friendly descriptive sentence, e.g.:
  /// "Expires in 87 days", "Expires in 21 days", "Expired 5 days ago", "No expiration date".
  static String descriptiveNotice(DateTime? expiryDate, [DateTime? now]) {
    if (expiryDate == null) return 'No expiration date';
    final days = daysUntil(expiryDate, now);
    if (days < 0) {
      if (days == -1) return 'Expired yesterday';
      return 'Expired ${-days} days ago';
    }
    if (days == 0) return 'Expires today';
    if (days == 1) return 'Expires tomorrow';
    return 'Expires in $days days';
  }

  /// Text color associated with the expiration status.
  static Color colorFor(DocumentExpirationStatus status) => switch (status) {
    DocumentExpirationStatus.expired => AppColors.glassDestructive,
    DocumentExpirationStatus.expiringSoon => AppColors.glassWarningColor,
    DocumentExpirationStatus.valid => AppColors.glassAccentGreen,
    DocumentExpirationStatus.noExpiryDate => AppColors.glassOnSurfaceFaint,
  };

  /// Background fill color associated with the expiration status.
  static Color backgroundColorFor(DocumentExpirationStatus status) => switch (status) {
    DocumentExpirationStatus.expired =>
      AppColors.glassDestructive.withValues(alpha: 0.16),
    DocumentExpirationStatus.expiringSoon => AppColors.glassWarningBg,
    DocumentExpirationStatus.valid => AppColors.glassSuccessBg,
    DocumentExpirationStatus.noExpiryDate =>
      AppColors.glassBorder.withValues(alpha: 0.5),
  };
}
