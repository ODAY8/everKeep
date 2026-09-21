import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../core/supabase/app_supabase.dart';
import '../core/supabase/supabase_errors.dart';
import '../models/user.dart';

/// Contract for the authentication backend.
abstract class AuthService {
  Future<User?> signIn({required String email, required String password});

  /// Registers a new account. Returns the signed-in user, or null when the
  /// account was created but must confirm its email address before it has a
  /// session (Supabase's default for email/password sign-up).
  Future<User?> signUp({
    required String name,
    required String email,
    required String password,
  });
  Future<void> signOut();
  Future<bool> sendPasswordReset({required String email});

  /// The user of an existing, still-valid session, or null if there isn't one.
  Future<User?> restoreSession();

  /// Fires when the session ends for any reason: the user signed out, the
  /// session expired, or it was revoked (for example after a password change
  /// elsewhere).
  Stream<void> get sessionEnded;
}

/// [AuthService] backed by Supabase Auth (email + password).
class AuthServiceImpl implements AuthService {
  final supa.SupabaseClient _client;

  AuthServiceImpl({supa.SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  @override
  Future<User?> signIn({
    required String email,
    required String password,
  }) {
    return guardBackend(() async {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null || response.session == null) {
        throw const BackendException('Sign in failed. Please try again.');
      }
      return _toAppUser(user);
    });
  }

  @override
  Future<User?> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return guardBackend(() async {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        // Read by the database trigger that creates the `profiles` row.
        data: {'full_name': name.trim()},
      );
      final user = response.user;
      if (user == null) {
        throw const BackendException('Sign up failed. Please try again.');
      }

      // With email confirmation on, signing up an address that is already
      // registered doesn't error (that would reveal which emails have
      // accounts); it returns a user with no identities instead.
      if (user.identities != null && user.identities!.isEmpty) {
        throw const BackendException(
          'An account with this email already exists.',
        );
      }

      // No session means the email still has to be confirmed.
      if (response.session == null) return null;
      return _toAppUser(user);
    });
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on Exception catch (error) {
      // The SDK clears the local session (and announces the sign-out) before
      // it asks the server to revoke it. So if the session is gone, this
      // device really is signed out and only the server-side revoke failed.
      if (_client.auth.currentSession != null) {
        throw translateSupabaseError(error);
      }
      if (kDebugMode) debugPrint('Signed out locally; server revoke failed: $error');
    }
  }

  @override
  Future<bool> sendPasswordReset({required String email}) {
    return guardBackend(() async {
      await _client.auth.resetPasswordForEmail(email.trim());
      // Supabase answers the same whether or not the address has an account.
      return true;
    });
  }

  @override
  Future<User?> restoreSession() async {
    // supabase_flutter has already reloaded any persisted session during
    // initialisation; here it is checked against the server.
    final session = _client.auth.currentSession;
    if (session == null) return null;

    try {
      final response = await _client.auth
          .getUser()
          .timeout(const Duration(seconds: 8));
      final user = response.user;
      if (user == null) return null;
      return _toAppUser(user);
    } on Exception catch (error) {
      // Offline (or the server is slow): trust the stored session for now.
      // Data requests will show their own retry until the network is back.
      if (isNetworkFailure(error)) return _toAppUser(session.user);

      // The server rejected the session (revoked, deleted user, bad token).
      try {
        await _client.auth.signOut();
      } on Exception catch (_) {
        // The local session is cleared regardless.
      }
      return null;
    }
  }

  @override
  Stream<void> get sessionEnded => _client.auth.onAuthStateChange
      .where((state) => state.event == supa.AuthChangeEvent.signedOut)
      .map((_) {});

  User _toAppUser(supa.User user) {
    return User.fromAuth(
      id: user.id,
      email: user.email,
      metadataName: (user.userMetadata?['full_name'] as String?)?.trim() ?? '',
      lastLogin: DateTime.tryParse(user.lastSignInAt ?? '')?.toLocal(),
    );
  }
}
