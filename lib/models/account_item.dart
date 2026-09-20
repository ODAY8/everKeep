import 'package:flutter/material.dart';

class AccountItem {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final Color color;
  final bool isFavorite;
  final DateTime? lastUpdated;

  const AccountItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.category = 'Other',
    required this.icon,
    required this.color,
    this.isFavorite = false,
    this.lastUpdated,
  });

  AccountItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? category,
    IconData? icon,
    Color? color,
    bool? isFavorite,
    DateTime? lastUpdated,
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
    );
  }
}
