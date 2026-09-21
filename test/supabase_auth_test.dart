import 'package:everkeep/core/supabase/supabase_errors.dart';
import 'package:everkeep/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/fake_supabase.dart';

/// Runs the real AuthServiceImpl against a real SupabaseClient whose HTTP layer
/// is faked, so what is asserted is the exact traffic and error handling.
void main() {
  late FakeSupabase supabase;
  late AuthServiceImpl auth;

  setUp(() {
    supabase = FakeSupabase();
    auth = AuthServiceImpl(client: supabase.client);
  });

  Future<Object?> failureOf(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (error) {
      return error;
    }
    fail('expected the call to fail');
  }

  group('signIn', () {
    test('signs in with email and password and maps the user', () async {
      final user = await auth.signIn(email: '  alex@example.com ', password: 'secret1');

      final request = supabase.single('POST', '/auth/v1/token');
      expect(request.query['grant_type'], 'password');
      final body = request.json as Map<String, dynamic>;
      expect(body['email'], 'alex@example.com'); // trimmed
      expect(body['password'], 'secret1');

      expect(user, isNotNull);
      expect(user!.id, testUserId);
      expect(user.email, 'alex@example.com');
      expect(user.name, 'Alex Rivera'); // from sign-up metadata
      expect(user.isAuthenticated, isTrue);
      expect(user.lastLogin, isNotNull);
      expect(supabase.client.auth.currentSession, isNotNull);
    });

    test('wrong credentials give a plain message and no session', () async {
      supabase.authRoute = (_) =>
          authError(400, 'invalid_credentials', 'Invalid login credentials');

      final error = await failureOf(
        () => auth.signIn(email: 'alex@example.com', password: 'nope'),
      );

      expect(error, isA<BackendException>());
      expect(error.toString(), 'Incorrect email or password.');
      expect(supabase.client.auth.currentSession, isNull);
    });

    test('an unconfirmed email is explained', () async {
      supabase.authRoute = (_) =>
          authError(400, 'email_not_confirmed', 'Email not confirmed');

      final error = await failureOf(
        () => auth.signIn(email: 'alex@example.com', password: 'secret1'),
      );
      expect(error.toString(), contains('confirm your email'));
    });

    test('being offline is reported as such, not as bad credentials', () async {
      supabase.authRoute = (_) => throw http.ClientException('no route to host');

      final error = await failureOf(
        () => auth.signIn(email: 'alex@example.com', password: 'secret1'),
      );
      expect(error.toString(), contains('Can\'t reach the server'));
    });
  });

  group('signUp', () {
    test('creates the account with the name as profile metadata', () async {
      supabase.authRoute = (request) => sessionResponse(name: 'Alex Rivera');

      final user = await auth.signUp(
        name: ' Alex Rivera ',
        email: 'alex@example.com',
        password: 'secret1',
      );

      final request = supabase.single('POST', '/auth/v1/signup');
      final body = request.json as Map<String, dynamic>;
      expect(body['email'], 'alex@example.com');
      expect(body['password'], 'secret1');
      // Read by the database trigger that creates the profiles row.
      expect(body['data'], {'full_name': 'Alex Rivera'});
      expect(user!.name, 'Alex Rivera');
    });

    test('with email confirmation on there is no session, so no user', () async {
      // Supabase's default: the account exists but nobody is signed in yet.
      supabase.authRoute = (_) => jsonResponse(authUserJson());

      final user = await auth.signUp(
        name: 'Alex',
        email: 'alex@example.com',
        password: 'secret1',
      );

      expect(user, isNull);
      expect(supabase.client.auth.currentSession, isNull);
    });

    test('an already-registered email is reported, not silently accepted',
        () async {
      // With confirmation on, Supabase answers with a user that has no
      // identities instead of an error (to avoid revealing which emails exist).
      supabase.authRoute = (_) => jsonResponse(authUserJson(identities: false));

      final error = await failureOf(
        () => auth.signUp(name: 'Alex', email: 'alex@example.com', password: 'secret1'),
      );
      expect(error.toString(), 'An account with this email already exists.');
    });

    test('a weak password shows the server\'s rule', () async {
      supabase.authRoute = (_) => authError(
        422,
        'weak_password',
        'Password should be at least 6 characters.',
      );

      final error = await failureOf(
        () => auth.signUp(name: 'Alex', email: 'alex@example.com', password: '123'),
      );
      expect(error.toString(), 'Password should be at least 6 characters.');
    });

    test('rate limiting is explained', () async {
      supabase.authRoute = (_) => authError(
        429,
        'over_email_send_rate_limit',
        'email rate limit exceeded',
      );

      final error = await failureOf(
        () => auth.signUp(name: 'Alex', email: 'alex@example.com', password: 'secret1'),
      );
      expect(error.toString(), contains('Too many attempts'));
    });
  });

  group('signOut', () {
    test('ends the session and tells the server to revoke it', () async {
      await supabase.signIn();

      await auth.signOut();

      expect(supabase.client.auth.currentSession, isNull);
      expect(supabase.where('POST', '/auth/v1/logout'), hasLength(1));
    });

    test('if only the server-side revoke fails, the device is still signed out',
        () async {
      await supabase.signIn();
      supabase.authRoute = (request) {
        if (request.path.endsWith('/logout')) {
          throw http.ClientException('network down');
        }
        return jsonResponse({});
      };

      // No error: this device's session is gone, which is what the user asked.
      await auth.signOut();

      expect(supabase.client.auth.currentSession, isNull);
    });

    test('announces the end of the session', () async {
      await supabase.signIn();
      final ended = auth.sessionEnded.first;

      await auth.signOut();

      await expectLater(ended.timeout(const Duration(seconds: 2)), completes);
    });
  });

  group('restoreSession', () {
    test('with no stored session there is nothing to restore', () async {
      expect(await auth.restoreSession(), isNull);
      expect(supabase.requests, isEmpty); // no pointless network call
    });

    test('a stored session is verified with the server before it is trusted',
        () async {
      await supabase.signIn();
      supabase.authRoute = (request) => request.path.endsWith('/user')
          ? jsonResponse(authUserJson(name: 'Alex Rivera'))
          : jsonResponse({});

      final user = await auth.restoreSession();

      expect(supabase.where('GET', '/auth/v1/user'), hasLength(1));
      expect(user?.id, testUserId);
    });

    test('a session the server rejects is dropped', () async {
      await supabase.signIn();
      supabase.authRoute = (request) => request.path.endsWith('/user')
          ? authError(401, 'bad_jwt', 'invalid JWT')
          : jsonResponse({});

      expect(await auth.restoreSession(), isNull);
      expect(supabase.client.auth.currentSession, isNull);
    });

    test('offline at startup keeps the stored session instead of signing out',
        () async {
      await supabase.signIn();
      supabase.authRoute = (request) {
        if (request.path.endsWith('/user')) {
          throw http.ClientException('offline');
        }
        return jsonResponse({});
      };

      final user = await auth.restoreSession();

      expect(user?.id, testUserId);
      expect(supabase.client.auth.currentSession, isNotNull);
    });
  });

  test('password reset asks Supabase to email a recovery link', () async {
    final sent = await auth.sendPasswordReset(email: ' alex@example.com ');

    expect(sent, isTrue);
    final request = supabase.single('POST', '/auth/v1/recover');
    expect((request.json as Map)['email'], 'alex@example.com');
  });
}
