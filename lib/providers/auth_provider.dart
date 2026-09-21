import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthStatus _status = AuthStatus.initial;
  bool _isLoading = false;
  String? _error;
  User? _currentUser;

  AuthProvider({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepositoryImpl();

  AuthStatus get status => _status;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get error => _error;
  User? get currentUser => _currentUser;

  /// Validates existing session state on app launch.
  Future<void> checkSession() async {
    _setLoading(true);
    try {
      // TODO: Connect to secure storage/backend session token verification
      _status = AuthStatus.unauthenticated;
      _error = null;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Authenticates user with email and password credentials.
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final user = await _authRepository.signIn(
        email: email,
        password: password,
      );
      _currentUser = user;
      _status = AuthStatus.authenticated;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Registers a new user account.
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final user = await _authRepository.signUp(
        name: name,
        email: email,
        password: password,
      );
      _currentUser = user;
      _status = AuthStatus.authenticated;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Terminates current user session.
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authRepository.signOut();
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Sends password recovery link.
  Future<bool> sendPasswordReset({required String email}) async {
    _setLoading(true);
    _error = null;
    try {
      final result = await _authRepository.sendPasswordReset(email: email);
      return result;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }
}
