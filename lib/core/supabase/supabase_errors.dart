import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// A backend failure already translated into a message that is safe to show
/// the user. Its `toString()` is the message, which is what the providers
/// display. Raw Supabase errors can carry table names, SQL details or hints
/// about the schema, so those never reach the UI.
class BackendException implements Exception {
  final String message;

  const BackendException(this.message);

  @override
  String toString() => message;
}

const String _offlineMessage =
    'Can\'t reach the server. Check your connection and try again.';
const String _sessionExpiredMessage =
    'Your session has expired. Please sign in again.';
const String _genericMessage = 'Something went wrong. Please try again.';

/// Runs [action], converting any failure into a [BackendException].
///
/// Only `Exception`s are converted; programming errors (`Error`s) still
/// surface as bugs instead of being disguised as a user-facing message.
Future<T> guardBackend<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on Exception catch (error) {
    throw translateSupabaseError(error);
  }
}

/// Throws if an update/select matched no rows. Row Level Security makes rows
/// that belong to someone else invisible, so "no rows" covers both "deleted
/// elsewhere" and "not yours" — either way the change did not happen, and the
/// caller must not report success.
void requireAffected(List<dynamic> rows) {
  if (rows.isEmpty) {
    throw const BackendException(
      'That item couldn\'t be found. It may have been deleted.',
    );
  }
}

/// Maps any exception thrown by Supabase (Auth, PostgREST, Storage) or the
/// network stack to a [BackendException] with a user-safe message.
BackendException translateSupabaseError(Object error) {
  if (error is BackendException) return error;

  if (kDebugMode) debugPrint('Supabase error: $error');

  if (isNetworkFailure(error)) return const BackendException(_offlineMessage);
  if (error is AuthException) return BackendException(_authMessage(error));
  if (error is PostgrestException) {
    return BackendException(_databaseMessage(error));
  }
  if (error is StorageException) return BackendException(_storageMessage(error));
  return const BackendException(_genericMessage);
}

/// True when [error] means the server couldn't be reached (offline, DNS,
/// timeout, TLS) as opposed to the server rejecting the request.
bool isNetworkFailure(Object error) {
  if (error is AuthRetryableFetchException) return true;
  if (error is http.ClientException || error is TimeoutException) return true;
  // dart:io's SocketException/HandshakeException are matched by name so this
  // file stays importable on web, where dart:io does not exist.
  const networkTypes = {'SocketException', 'HandshakeException', 'TlsException'};
  return networkTypes.contains(error.runtimeType.toString());
}

String _authMessage(AuthException e) {
  switch (e.code) {
    case 'invalid_credentials':
      return 'Incorrect email or password.';
    case 'email_not_confirmed':
      return 'Please confirm your email address, then sign in.';
    case 'user_already_exists':
    case 'email_exists':
      return 'An account with this email already exists.';
    case 'weak_password':
      // The server's message names the rule that failed ("at least 6
      // characters"), which is exactly what the user needs to see.
      return e.message;
    case 'email_address_invalid':
    case 'validation_failed':
      return 'Enter a valid email address.';
    case 'signup_disabled':
      return 'Sign-ups are currently disabled.';
    case 'user_banned':
      return 'This account has been disabled.';
    case 'over_request_rate_limit':
    case 'over_email_send_rate_limit':
    case 'over_sms_send_rate_limit':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'session_expired':
    case 'session_not_found':
    case 'refresh_token_not_found':
    case 'refresh_token_already_used':
    case 'bad_jwt':
      return _sessionExpiredMessage;
  }

  if (e is AuthSessionMissingException || e is AuthInvalidJwtException) {
    return _sessionExpiredMessage;
  }
  if (e.statusCode == '429') {
    return 'Too many attempts. Please wait a moment and try again.';
  }
  // Older servers omit `code`; their wording for bad credentials is stable.
  if (e.message.toLowerCase().contains('invalid login credentials')) {
    return 'Incorrect email or password.';
  }
  return 'Authentication failed. Please try again.';
}

String _databaseMessage(PostgrestException e) {
  switch (e.code) {
    case '42501': // insufficient_privilege / row-level security violation
      return 'You don\'t have permission to do that.';
    case '23505': // unique_violation
      return 'That already exists.';
    case '23503': // foreign_key_violation
      return 'That refers to something that no longer exists.';
    case '23502': // not_null_violation
    case '23514': // check_violation
    case '22001': // string_data_right_truncation
    case '22P02': // invalid_text_representation
      return 'Some of the information isn\'t valid. Please check it and try again.';
    case 'PGRST116': // expected one row, got none (or several)
      return 'That item couldn\'t be found. It may have been deleted.';
    case 'PGRST301': // JWT expired / invalid
    case 'PGRST303':
      return _sessionExpiredMessage;
  }
  if (e.code == '401' || e.message.contains('JWT')) {
    return _sessionExpiredMessage;
  }
  return 'Something went wrong while talking to the server. Please try again.';
}

String _storageMessage(StorageException e) {
  switch (e.statusCode) {
    case '413':
      return 'That file is too large.';
    case '401':
    case '403':
      return 'You don\'t have permission to access that file.';
    case '404':
      return 'That file couldn\'t be found.';
    case '409':
      return 'A file with that name already exists.';
  }
  return 'Something went wrong with the file. Please try again.';
}
