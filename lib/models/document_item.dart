import 'package:flutter/material.dart';

class DocumentItem {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final bool isVerified;
  final DateTime? dateAdded;

  const DocumentItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    this.icon = Icons.description_outlined,
    this.isVerified = false,
    this.dateAdded,
  });

  DocumentItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? category,
    IconData? icon,
    bool? isVerified,
    DateTime? dateAdded,
  }) {
    return DocumentItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      isVerified: isVerified ?? this.isVerified,
      dateAdded: dateAdded ?? this.dateAdded,
    );
  }
}
