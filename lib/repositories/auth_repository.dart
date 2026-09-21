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
  Future<bool> sendPasswordReset({required String email});
  Future<User?> restoreSession();
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
}
