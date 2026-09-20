import '../models/user.dart';

/// Abstract service contract for external authentication backend.
abstract class AuthService {
  Future<User?> signIn({required String email, required String password});
  Future<User?> signUp({
    required String name,
    required String email,
    required String password,
  });
  Future<void> signOut();
  Future<bool> sendPasswordReset({required String email});
}

/// Default implementation providing backend-ready interface.
class AuthServiceImpl implements AuthService {
  // TODO: Connect to backend API (e.g. Firebase Auth, Supabase, or custom REST auth)

  @override
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    // Simulated network delay for realistic UI transition
    await Future.delayed(const Duration(milliseconds: 600));

    // Basic validation check before connecting to backend
    if (email.isEmpty || password.length < 6) {
      throw Exception('Invalid credentials provided.');
    }

    // TODO: Replace with real response token & user record from backend
    return User.defaultUser.copyWith(email: email);
  }

  @override
  Future<User?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));

    if (name.isEmpty || email.isEmpty || password.length < 6) {
      throw Exception('Invalid registration details provided.');
    }

    // TODO: Replace with real user record creation from backend
    return User.defaultUser.copyWith(name: name, email: email);
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // TODO: Clear backend session, JWT tokens, and secure storage
  }

  @override
  Future<bool> sendPasswordReset({required String email}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (email.isEmpty) {
      throw Exception('Email address is required.');
    }
    // TODO: Trigger real password reset email via backend
    return true;
  }
}
