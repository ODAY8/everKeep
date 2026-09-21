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

  /// The user of an existing session, or null if there isn't one.
  Future<User?> restoreSession();
}

/// Default implementation providing backend-ready interface.
class AuthServiceImpl implements AuthService {
  // TODO: Connect to backend API (e.g. Firebase Auth, Supabase, or custom REST auth)

  // TODO: Persist the session token in secure storage. Until then the session
  // lives only in memory, so restoreSession() finds nothing on a cold start.
  User? _sessionUser;

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
    return _sessionUser = User.defaultUser.copyWith(email: email);
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
    return _sessionUser = User.defaultUser.copyWith(name: name, email: email);
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // TODO: Clear backend session, JWT tokens, and secure storage
    _sessionUser = null;
  }

  @override
  Future<User?> restoreSession() async {
    await Future.delayed(const Duration(milliseconds: 150));
    // TODO: Verify the stored session token with the backend.
    return _sessionUser;
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
