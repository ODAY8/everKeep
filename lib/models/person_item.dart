/// Represents a person in the user's life vault that can be tagged in memories and wishes.
class PersonItem {
  final String id;
  final String? userId;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PersonItem({
    required this.id,
    this.userId,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  /// Maximum allowed character length for a person's name.
  static const int maxNameLength = 100;

  /// Validates a potential person name. Returns an error message or null if valid.
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Person name cannot be empty.';
    }
    final clean = value.trim();
    if (clean.length > maxNameLength) {
      return 'Name cannot exceed $maxNameLength characters.';
    }
    return null;
  }

  /// Cleans and normalizes a person's name by trimming and collapsing internal spaces.
  static String sanitizeName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Deserializes a [PersonItem] from a Supabase database row.
  factory PersonItem.fromRow(Map<String, dynamic> row) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    return PersonItem(
      id: row['id'] as String,
      userId: row['user_id'] as String?,
      name: (row['name'] as String?)?.trim() ?? '',
      createdAt: parseDate(row['created_at']),
      updatedAt: parseDate(row['updated_at']),
    );
  }

  /// Columns written when inserting a new person into the `people` table.
  Map<String, dynamic> toInsertRow() {
    final row = <String, dynamic>{
      'name': sanitizeName(name),
    };
    if (userId != null && userId!.trim().isNotEmpty) {
      row['user_id'] = userId!.trim();
    }
    return row;
  }

  /// Columns written when updating an existing person in the `people` table.
  Map<String, dynamic> toUpdateRow() {
    return <String, dynamic>{
      'name': sanitizeName(name),
    };
  }

  /// JSON serialization for backups, exports, and offline caches.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'name': sanitizeName(name),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Deserializes a [PersonItem] from JSON.
  factory PersonItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    return PersonItem(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      name: (json['name'] as String?)?.trim() ?? '',
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  PersonItem copyWith({
    String? id,
    String? userId,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PersonItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name.toLowerCase() == other.name.toLowerCase();

  @override
  int get hashCode => id.hashCode ^ name.toLowerCase().hashCode;

  @override
  String toString() => 'PersonItem(id: $id, name: $name)';
}
