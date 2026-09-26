import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/relative_time.dart';

class AccountItem {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final Color color;
  final bool isFavorite;
  final DateTime? lastUpdated;

  /// When the account was saved.
  final DateTime? createdAt;

  /// The login name or email saved with the account.
  final String? username;

  /// The website URL (e.g. "https://github.com").
  final String? website;

  /// Optional private notes about this account or credential.
  final String? notes;

  /// The encrypted password payload (ciphertext + IV + MAC).
  /// Plaintext password is NEVER stored in Supabase or persisted unencrypted.
  final String? encryptedPassword;

  const AccountItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.category = 'Other',
    required this.icon,
    required this.color,
    this.isFavorite = false,
    this.lastUpdated,
    this.createdAt,
    this.username,
    this.website,
    this.notes,
    this.encryptedPassword,
  });

  /// True if this account has an encrypted password saved in the vault.
  bool get hasPassword =>
      encryptedPassword != null && encryptedPassword!.trim().isNotEmpty;

  /// The icon and tint shown for an account of the given category. Derived,
  /// not stored, so changing the look never needs a data migration.
  static (IconData, Color) styleFor(String category) => switch (category) {
    'Banking' => (Icons.account_balance_rounded, AppColors.glassAccentGreen),
    'Social' => (Icons.public_rounded, AppColors.glassAccentPink),
    'Work' => (Icons.work_outline_rounded, AppColors.glassOnSurfaceMuted),
    'Personal' => (Icons.person_outline_rounded, AppColors.glassWarningColor),
    _ => (Icons.key_rounded, AppColors.glassAccentBlue),
  };

  /// Builds an account from an `accounts` row. The subtitle is derived from
  /// the creation time and username so it never goes stale.
  factory AccountItem.fromRow(Map<String, dynamic> row) {
    final category = (row['category'] as String?) ?? 'Other';
    final username = (row['username'] as String?)?.trim();
    final website = (row['website'] as String?)?.trim();
    final notes = (row['notes'] as String?)?.trim();
    final encryptedPassword = row['encrypted_password'] as String?;
    final createdAt = row['created_at'] != null
        ? DateTime.parse(row['created_at'] as String).toLocal()
        : DateTime.now();
    final (icon, color) = styleFor(category);
    final added = 'Added ${relativeTime(createdAt)}';
    return AccountItem(
      id: (row['id'] as String?) ?? '',
      title: (row['name'] as String?) ?? '',
      subtitle: (username == null || username.isEmpty)
          ? added
          : '$added · $username',
      category: category,
      icon: icon,
      color: color,
      isFavorite: row['is_favorite'] as bool? ?? false,
      lastUpdated: DateTime.tryParse(row['updated_at'] as String? ?? '')?.toLocal(),
      createdAt: createdAt,
      username: (username == null || username.isEmpty) ? null : username,
      website: (website == null || website.isEmpty) ? null : website,
      notes: (notes == null || notes.isEmpty) ? null : notes,
      encryptedPassword: (encryptedPassword == null || encryptedPassword.isEmpty)
          ? null
          : encryptedPassword,
    );
  }

  /// The columns written when creating an account. The id, owner and
  /// timestamps are assigned by the database.
  Map<String, dynamic> toInsertRow() {
    final map = <String, dynamic>{
      'name': title.trim(),
      'username': _cleanUsername,
      'category': category,
      'is_favorite': isFavorite,
    };
    if (website != null && website!.trim().isNotEmpty) {
      map['website'] = website!.trim();
    }
    if (notes != null && notes!.trim().isNotEmpty) {
      map['notes'] = notes!.trim();
    }
    if (encryptedPassword != null && encryptedPassword!.trim().isNotEmpty) {
      map['encrypted_password'] = encryptedPassword!.trim();
    }
    return map;
  }

  /// The columns written when editing an account (favorite has its own call).
  Map<String, dynamic> toUpdateRow() {
    final map = <String, dynamic>{
      'name': title.trim(),
      'username': _cleanUsername,
      'category': category,
    };
    if (website != null) {
      map['website'] = website!.trim().isEmpty ? null : website!.trim();
    }
    if (notes != null) {
      map['notes'] = notes!.trim().isEmpty ? null : notes!.trim();
    }
    if (encryptedPassword != null) {
      map['encrypted_password'] =
          encryptedPassword!.trim().isEmpty ? null : encryptedPassword!.trim();
    }
    return map;
  }

  String? get _cleanUsername {
    final trimmed = username?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  AccountItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? category,
    IconData? icon,
    Color? color,
    bool? isFavorite,
    DateTime? lastUpdated,
    DateTime? createdAt,
    String? username,
    String? website,
    String? notes,
    String? encryptedPassword,
    bool clearWebsite = false,
    bool clearNotes = false,
    bool clearPassword = false,
  }) {
    return AccountItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isFavorite: isFavorite ?? this.isFavorite,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdAt: createdAt ?? this.createdAt,
      username: username ?? this.username,
      website: clearWebsite ? null : (website ?? this.website),
      notes: clearNotes ? null : (notes ?? this.notes),
      encryptedPassword:
          clearPassword ? null : (encryptedPassword ?? this.encryptedPassword),
    );
  }
}
