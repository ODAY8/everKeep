class TrustedContactItem {
  final String id;
  final String name;
  final String relationship;
  final String accessLevel;
  final String avatarUrl;

  const TrustedContactItem({
    required this.id,
    required this.name,
    required this.relationship,
    required this.accessLevel,
    required this.avatarUrl,
  });

  TrustedContactItem copyWith({
    String? id,
    String? name,
    String? relationship,
    String? accessLevel,
    String? avatarUrl,
  }) {
    return TrustedContactItem(
      id: id ?? this.id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      accessLevel: accessLevel ?? this.accessLevel,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
