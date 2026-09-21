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

  /// The login name or email saved with the account. There is deliberately no
  /// password field: vault secrets must not be stored until client-side
  /// encryption and key management exist.
  final String? username;

  const AccountItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.category = 'Other',
    required this.icon,
    required this.color,
    this.isFavorite = false,
    this.lastUpdated,
    this.username,
  });

  /// The icon and tint shown for an account of the given category. Derived,
  /// not stored, so changing the look never needs a data migration.
  static (IconData, Color) styleFor(String category) => switch (category) {
    'Banking' => (Icons.account_balance_rounded, AppColors.glassAccentGreen),
    'Social' => (Icons.public_rounded, AppColors.glassAccentPink),
    'Work' => (Icons.work_outline_rounded, AppColors.glassOnSurfaceMuted),
    _ => (Icons.key_rounded, AppColors.glassAccentBlue),
  };

  /// Builds an account from an `accounts` row. The subtitle is derived from
  /// the creation time and username so it never goes stale.
  factory AccountItem.fromRow(Map<String, dynamic> row) {
    final category = row['category'] as String;
    final username = (row['username'] as String?)?.trim();
    final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
    final (icon, color) = styleFor(category);
    final added = 'Added ${relativeTime(createdAt)}';
    return AccountItem(
      id: row['id'] as String,
      title: row['name'] as String,
      subtitle: (username == null || username.isEmpty)
          ? added
          : '$added · $username',
      category: category,
      icon: icon,
      color: color,
      isFavorite: row['is_favorite'] as bool? ?? false,
      lastUpdated: DateTime.tryParse(row['updated_at'] as String? ?? '')?.toLocal(),
      username: (username == null || username.isEmpty) ? null : username,
    );
  }

  /// The columns written when creating an account. The id, owner and
  /// timestamps are assigned by the database.
  Map<String, dynamic> toInsertRow() => {
    'name': title.trim(),
    'username': _cleanUsername,
    'category': category,
    'is_favorite': isFavorite,
  };

  /// The columns written when editing an account (favorite has its own call).
  Map<String, dynamic> toUpdateRow() => {
    'name': title.trim(),
    'username': _cleanUsername,
    'category': category,
  };

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
    String? username,
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
      username: username ?? this.username,
    );
  }
}
