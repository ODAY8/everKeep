import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import 'session_scoped.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  StreamSubscription<void>? _sessionEndedSubscription;

  AuthStatus _status = AuthStatus.initial;
  bool _isLoading = false;
  String? _error;
  String? _notice;
  User? _currentUser;

  AuthProvider({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepositoryImpl() {
    // The backend can end the session on its own (expiry, revocation, sign-out
    // from another device). Follow it, so the guard and the session
    // coordinator react instead of the UI showing a stale signed-in state.
    _sessionEndedSubscription = _authRepository.sessionEnded.listen(
      (_) => _handleSessionEnded(),
    );
  }

  AuthStatus get status => _status;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get error => _error;

  /// A non-error message the UI should show once, e.g. "check your email" after
  /// signing up when the address still has to be confirmed.
  String? get notice => _notice;
  User? get currentUser => _currentUser;

  @override
  void dispose() {
    _sessionEndedSubscription?.cancel();
    super.dispose();
  }

  void _handleSessionEnded() {
    if (_status != AuthStatus.authenticated) return;
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _error = null;
    notifyListeners();
  }

  /// Restores an existing session on app launch. A failure to restore is not
  /// the user's error to see — it simply means they need to sign in.
  Future<void> checkSession() async {
    _setLoading(true);
    try {
      final user = await _authRepository.restoreSession();
      _currentUser = user;
      _status =
          user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    } catch (_) {
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
    } finally {
      _error = null;
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
    _notice = null;
    try {
      final user = await _authRepository.signIn(
        email: email,
        password: password,
      );
      if (user == null) {
        // Never report "signed in" without a user to show.
        _status = AuthStatus.error;
        _error = 'Sign in failed. Please try again.';
        notifyListeners();
        return false;
      }
      _currentUser = user;
      _status = AuthStatus.authenticated;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _error = errorMessage(e);
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
    _notice = null;
    try {
      final user = await _authRepository.signUp(
        name: name,
        email: email,
        password: password,
      );
      if (user == null) {
        // The account exists but has no session until the email address is
        // confirmed, so the user is not signed in — don't pretend they are.
        _status = AuthStatus.unauthenticated;
        _notice = 'Account created. Check your email to confirm your address, '
            'then sign in.';
        notifyListeners();
        return false;
      }
      _currentUser = user;
      _status = AuthStatus.authenticated;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _error = errorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Terminates the current session. Returns false (and stays signed in,
  /// with [error] set) if the backend couldn't end it, so callers don't
  /// navigate away from a session that is still live.
  Future<bool> signOut() async {
    _setLoading(true);
    try {
      await _authRepository.signOut();
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = errorMessage(e);
      notifyListeners();
      return false;
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
      _error = errorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Clears a stale error (and the error status it left behind). Auth
  /// screens call this when they open so one screen's failure isn't shown
  /// on the next.
  void clearError() {
    if (_error == null && _notice == null && _status != AuthStatus.error) return;
    _error = null;
    _notice = null;
    if (_status == AuthStatus.error) {
      _status = _currentUser != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }
}
