class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final bool isAuthenticated;
  final DateTime? lastLogin;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.isAuthenticated = false,
    this.lastLogin,
  });

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    bool? isAuthenticated,
    DateTime? lastLogin,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  // Default user representing the active profile
  static final User defaultUser = User(
    id: 'user-001',
    name: 'Sarah Mitchell',
    email: 'sarah.mitchell@editorial.com',
    phone: '+1 (555) 123-4567',
    avatarUrl: null,
    isAuthenticated: true,
    lastLogin: DateTime.now().subtract(const Duration(hours: 2)),
  );

  // Mock user for development
  static User mockUser = defaultUser;
}
