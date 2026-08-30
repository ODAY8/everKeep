class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final bool isAuthenticated;
  final DateTime? lastLogin;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.isAuthenticated = false,
    this.lastLogin,
  });

  // Mock user for development
  static User mockUser = User(
    id: '1',
    name: 'Alex Johnson',
    email: 'alex.johnson@example.com',
    phone: '+1 (555) 123-4567',
    avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
    isAuthenticated: true,
    lastLogin: DateTime.now().subtract(const Duration(hours: 2)),
  );
}