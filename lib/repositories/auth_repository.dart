import '../models/user.dart';
import '../services/auth_service.dart';

abstract class AuthRepository {
  Future<User?> signIn({required String email, required String password});
  Future<User?> signUp({
    required String name,
    required String email,
    required String password,
  });
  Future<void> signOut();
  Future<void> signOutEverywhere();
  Future<bool> sendPasswordReset({required String email});
  Future<void> updatePassword(String newPassword);
  Future<void> updateEmail(String newEmail);
  Future<User?> restoreSession();
  Stream<AuthSessionEvent> get events;
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService;

  AuthRepositoryImpl({AuthService? authService})
    : _authService = authService ?? AuthServiceImpl();

  @override
  Future<User?> signIn({required String email, required String password}) {
    return _authService.signIn(email: email, password: password);
  }

  @override
  Future<User?> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return _authService.signUp(name: name, email: email, password: password);
  }

  @override
  Future<void> signOut() {
    return _authService.signOut();
  }

  @override
  Future<bool> sendPasswordReset({required String email}) {
    return _authService.sendPasswordReset(email: email);
  }

  @override
  Future<User?> restoreSession() {
    return _authService.restoreSession();
  }

  @override
  Future<void> signOutEverywhere() => _authService.signOutEverywhere();

  @override
  Future<void> updatePassword(String newPassword) =>
      _authService.updatePassword(newPassword);

  @override
  Future<void> updateEmail(String newEmail) =>
      _authService.updateEmail(newEmail);

  @override
  Stream<AuthSessionEvent> get events => _authService.events;
}
