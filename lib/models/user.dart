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

  /// Builds the app's user from a signed-in Supabase Auth user and (when it
  /// has been loaded) their `profiles` row.
  ///
  /// Identity (id, email, last sign-in) always comes from Auth. Profile data
  /// (name, phone, avatar) comes from [profile]; until that row is loaded the
  /// name falls back to [metadataName], the name given at sign-up.
  factory User.fromAuth({
    required String id,
    required String? email,
    Map<String, dynamic>? profile,
    String metadataName = '',
    DateTime? lastLogin,
  }) {
    final profileName = (profile?['full_name'] as String?)?.trim() ?? '';
    return User(
      id: id,
      name: profileName.isNotEmpty ? profileName : metadataName,
      email: email ?? '',
      phone: profile?['phone'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      isAuthenticated: true,
      lastLogin: lastLogin,
    );
  }

  /// The editable profile fields, as a `profiles` row update. Email is owned
  /// by Supabase Auth and is deliberately not part of it.
  Map<String, dynamic> toProfileRow() {
    final trimmedPhone = phone?.trim();
    return {
      'full_name': name.trim(),
      'phone': (trimmedPhone == null || trimmedPhone.isEmpty) ? null : trimmedPhone,
      'avatar_url': avatarUrl,
    };
  }

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
}
