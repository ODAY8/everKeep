import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../services/auth_service.dart' show AuthSessionEvent;
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
  StreamSubscription<AuthSessionEvent>? _eventsSubscription;

  AuthStatus _status = AuthStatus.initial;
  bool _isLoading = false;
  String? _error;
  String? _notice;
  User? _currentUser;
  bool _recoveryPending = false;

  AuthProvider({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepositoryImpl() {
    // The backend can change the session on its own: it expires, is revoked, or
    // starts from a link in an email. Follow it, so the guard and the session
    // coordinator react instead of the UI showing a stale state.
    _eventsSubscription = _authRepository.events.listen(_handleEvent);
  }

  AuthStatus get status => _status;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get error => _error;

  /// A non-error message the UI should show once, e.g. "check your email" after
  /// signing up when the address still has to be confirmed.
  String? get notice => _notice;
  User? get currentUser => _currentUser;

  /// True after the user opened a password-reset link: they must now choose a
  /// new password. Cleared once they have.
  bool get recoveryPending => _recoveryPending;

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    super.dispose();
  }

  void _handleEvent(AuthSessionEvent event) {
    switch (event) {
      case AuthSessionEvent.signedOut:
        _handleSessionEnded();
      case AuthSessionEvent.passwordRecovery:
        _recoveryPending = true;
        notifyListeners();
      case AuthSessionEvent.signedIn:
        // A session began without us asking for one (the confirmation link in
        // an email opened the app). Adopt it. Our own sign-in/sign-up calls set
        // `_isLoading`, so they don't trigger this.
        if (!isAuthenticated && !_isLoading) unawaited(checkSession());
    }
  }

  void _handleSessionEnded() {
    _recoveryPending = false;
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
      _recoveryPending = false;
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

  /// Signs out this device and every other one. Returns false with [error] set
  /// if the other devices couldn't be reached (this device is signed out either
  /// way, which the resulting session-ended event takes care of).
  Future<bool> signOutEverywhere() async {
    _setLoading(true);
    _error = null;
    try {
      await _authRepository.signOutEverywhere();
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

  /// Sets a new password for the signed-in user (also used to finish a
  /// password-reset link). Returns whether it was saved.
  Future<bool> updatePassword(String newPassword) async {
    _setLoading(true);
    _error = null;
    try {
      await _authRepository.updatePassword(newPassword);
      _recoveryPending = false;
      return true;
    } catch (e) {
      _error = errorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Starts changing the account's email. It only takes effect once the user
  /// follows the link Supabase sends to the new address, which [notice] says.
  Future<bool> updateEmail(String newEmail) async {
    _setLoading(true);
    _error = null;
    _notice = null;
    try {
      await _authRepository.updateEmail(newEmail);
      _notice = 'We sent a confirmation link to $newEmail. Your email changes '
          'once you open it.';
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

  /// Ends a password-reset flow that was started but abandoned.
  void dismissRecovery() {
    if (!_recoveryPending) return;
    _recoveryPending = false;
    notifyListeners();
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
