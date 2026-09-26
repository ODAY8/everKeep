class TrustedContactItem {
  final String id;
  final String name;
  final String relationship;
  final String accessLevel;
  final String avatarUrl;

  /// When the person was added.
  final DateTime? createdAt;

  const TrustedContactItem({
    required this.id,
    required this.name,
    required this.relationship,
    required this.accessLevel,
    required this.avatarUrl,
    this.createdAt,
  });

  /// Builds a contact from a `trusted_contacts` row. A missing avatar is an
  /// empty string, which the avatar widget renders as a person icon.
  factory TrustedContactItem.fromRow(Map<String, dynamic> row) {
    return TrustedContactItem(
      id: row['id'] as String,
      name: row['name'] as String,
      relationship: row['relationship'] as String,
      accessLevel: row['access_level'] as String,
      avatarUrl: row['avatar_url'] as String? ?? '',
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal(),
    );
  }

  /// The columns written when adding a contact. The id, owner and timestamps
  /// are assigned by the database.
  Map<String, dynamic> toInsertRow() => {
    'name': name.trim(),
    'relationship': relationship.trim(),
    'access_level': accessLevel,
    'avatar_url': avatarUrl.isEmpty ? null : avatarUrl,
  };

  /// The columns written when updating a contact.
  Map<String, dynamic> toUpdateRow() => {
    'name': name.trim(),
    'relationship': relationship.trim(),
    'access_level': accessLevel,
    'avatar_url': avatarUrl.isEmpty ? null : avatarUrl,
  };

  TrustedContactItem copyWith({
    String? id,
    String? name,
    String? relationship,
    String? accessLevel,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return TrustedContactItem(
      id: id ?? this.id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      accessLevel: accessLevel ?? this.accessLevel,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
