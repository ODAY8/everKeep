import 'dart:typed_data';

import 'package:everkeep/core/config/auth_redirect.dart';
import 'package:everkeep/core/supabase/supabase_errors.dart';
import 'package:everkeep/models/document_upload.dart';
import 'package:everkeep/models/user.dart';
import 'package:everkeep/services/auth_service.dart';
import 'package:everkeep/services/user_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/fake_supabase.dart';

/// The account-management features, run through the real services against a
/// real SupabaseClient whose HTTP layer is faked: what is sent, and what
/// happens when the server says no.
void main() {
  late FakeSupabase supabase;

  setUp(() => supabase = FakeSupabase());

  Future<Object?> failureOf(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (error) {
      return error;
    }
    fail('expected the call to fail');
  }

  group('email links open the app', () {
    late AuthServiceImpl auth;
    setUp(() => auth = AuthServiceImpl(client: supabase.client));

    test(
      'the confirmation email sent at sign-up links back into the app',
      () async {
        supabase.authRoute = (_) => sessionResponse();

        await auth.signUp(
          name: 'Alex',
          email: 'alex@example.com',
          password: 'secret1',
        );

        final request = supabase.single('POST', '/auth/v1/signup');
        expect(request.query['redirect_to'], AuthRedirect.url);
      },
    );

    test('the password-reset email links back into the app', () async {
      await auth.sendPasswordReset(email: 'alex@example.com');

      final request = supabase.single('POST', '/auth/v1/recover');
      expect(request.query['redirect_to'], AuthRedirect.url);
    });

    test('the redirect uses the app\'s own scheme, matching the manifests', () {
      expect(
        AuthRedirect.url,
        startsWith('${AuthRedirect.scheme}://${AuthRedirect.host}'),
      );
    });
  });

  group('changing password and email', () {
    late AuthServiceImpl auth;

    setUp(() async {
      await supabase.signIn();
      auth = AuthServiceImpl(client: supabase.client);
      supabase.authRoute = (request) => request.path.endsWith('/user')
          ? jsonResponse(authUserJson())
          : jsonResponse({});
    });

    test('a new password is sent for the signed-in user only', () async {
      await auth.updatePassword('brand-new-1');

      final request = supabase.single('PUT', '/auth/v1/user');
      expect((request.json as Map)['password'], 'brand-new-1');
      expect(request.headers['Authorization'], startsWith('Bearer '));
    });

    test('reusing the old password is explained', () async {
      supabase.authRoute = (_) =>
          authError(422, 'same_password', 'New password should be different');

      final error = await failureOf(() => auth.updatePassword('secret1'));
      expect(error.toString(), contains('haven\'t used before'));
    });

    test('a too-weak password shows the server\'s rule', () async {
      supabase.authRoute = (_) => authError(
        422,
        'weak_password',
        'Password should be at least 6 characters.',
      );

      final error = await failureOf(() => auth.updatePassword('123'));
      expect(error.toString(), 'Password should be at least 6 characters.');
    });

    test('a new email is requested with a link back into the app', () async {
      await auth.updateEmail('  new@example.com ');

      final request = supabase.single('PUT', '/auth/v1/user');
      expect((request.json as Map)['email'], 'new@example.com');
      expect(request.query['redirect_to'], AuthRedirect.url);
    });
  });

  group('sign out everywhere', () {
    late AuthServiceImpl auth;

    setUp(() async {
      await supabase.signIn();
      auth = AuthServiceImpl(client: supabase.client);
    });

    test('asks the server to end every session, not just this one', () async {
      await auth.signOutEverywhere();

      final request = supabase.single('POST', '/auth/v1/logout');
      expect(request.query['scope'], 'global');
      expect(supabase.client.auth.currentSession, isNull);
    });

    test(
      'if the server can\'t be reached it says so — the other devices are the point',
      () async {
        supabase.authRoute = (request) {
          if (request.path.endsWith('/logout')) {
            throw http.ClientException('offline');
          }
          return jsonResponse({});
        };

        final error = await failureOf(() => auth.signOutEverywhere());

        expect(error, isA<BackendException>());
        expect(error.toString(), contains('other devices'));
        // This device is signed out regardless.
        expect(supabase.client.auth.currentSession, isNull);
      },
    );
  });

  group('session events', () {
    test(
      'signing in is announced, so an email-link sign-in can be adopted',
      () async {
        final auth = AuthServiceImpl(client: supabase.client);
        final signedIn = auth.events.firstWhere(
          (event) => event == AuthSessionEvent.signedIn,
        );

        await supabase.client.auth.signInWithPassword(
          email: 'alex@example.com',
          password: 'secret1',
        );

        await expectLater(
          signedIn.timeout(const Duration(seconds: 2)),
          completes,
        );
      },
    );

    test('token refreshes are not treated as new sign-ins', () async {
      final auth = AuthServiceImpl(client: supabase.client);
      final seen = <AuthSessionEvent>[];
      final sub = auth.events.listen(seen.add);

      await supabase.signIn();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(seen.where((e) => e == AuthSessionEvent.signedOut), isEmpty);
      expect(
        seen.where((e) => e == AuthSessionEvent.passwordRecovery),
        isEmpty,
      );
    });
  });

  group('profile photo', () {
    late UserServiceImpl service;
    const user = User(id: testUserId, name: 'Alex', email: 'alex@example.com');

    setUp(() async {
      await supabase.signIn();
      service = UserServiceImpl(client: supabase.client);
    });

    Map<String, Object?> profileRow({String? avatar}) => {
      'id': testUserId,
      'full_name': 'Alex Rivera',
      'phone': null,
      'avatar_url': avatar,
    };

    test(
      'a photo is stored in the user\'s own folder and the profile points at it',
      () async {
        supabase.route = (request) => request.path.startsWith('/storage/')
            ? jsonResponse({'Key': 'avatars/x'})
            : jsonResponse(profileRow(avatar: 'set'));

        final saved = await service.uploadAvatar(
          user,
          DocumentUpload(
            fileName: 'avatar.png',
            bytes: Uint8List.fromList([1, 2, 3]),
            mimeType: 'image/png',
          ),
        );

        final upload = supabase.single('POST', '/storage/v1/object/avatars/');
        expect(upload.path, endsWith('/$testUserId/avatar.png'));
        expect(
          upload.headers['x-upsert'],
          'true',
        ); // replaces the old photo in place

        final update = supabase.single('PATCH', '/rest/v1/profiles');
        expect(update.query['id'], 'eq.$testUserId');
        final url = (update.json as Map)['avatar_url'] as String;
        expect(
          url,
          contains('/storage/v1/object/public/avatars/$testUserId/avatar.png'),
        );
        expect(
          url,
          contains('?v='),
          reason: 'a version so the new picture shows',
        );
        expect(saved.avatarUrl, 'set');
      },
    );

    test('only images are accepted as a profile photo', () async {
      final error = await failureOf(
        () => service.uploadAvatar(
          user,
          DocumentUpload(
            fileName: 'x.pdf',
            bytes: Uint8List(3),
            mimeType: 'application/pdf',
          ),
        ),
      );

      expect(error.toString(), contains('choose a photo'));
      expect(supabase.requests, isEmpty, reason: 'nothing was uploaded');
    });

    test('a failed upload leaves the profile untouched', () async {
      supabase.route = (request) => request.path.startsWith('/storage/')
          ? errorResponse(413, {
              'message': 'too big',
              'statusCode': '413',
              'error': 'x',
            })
          : jsonResponse(profileRow());

      final error = await failureOf(
        () => service.uploadAvatar(
          user,
          DocumentUpload(
            fileName: 'a.png',
            bytes: Uint8List(3),
            mimeType: 'image/png',
          ),
        ),
      );

      expect(error.toString(), 'That file is too large.');
      expect(supabase.where('PATCH', '/rest/v1/profiles'), isEmpty);
    });

    test(
      'removing the photo deletes the file and clears the profile',
      () async {
        supabase.route = (request) => request.path.startsWith('/storage/')
            ? jsonResponse([])
            : jsonResponse(profileRow());

        await service.removeAvatar(user);

        expect(
          supabase.where('DELETE', '/storage/v1/object/avatars'),
          hasLength(1),
        );
        final update = supabase.single('PATCH', '/rest/v1/profiles');
        expect((update.json as Map)['avatar_url'], isNull);
      },
    );
  });

  group('download my data', () {
    test(
      'gathers only the signed-in user\'s rows, and lists files without their contents',
      () async {
        await supabase.signIn();
        supabase.route = (request) {
          final table = request.path.split('/').last;
          if (table == 'documents') {
            return jsonResponse([
              {
                'id': 'd1',
                'title': 'Will.pdf',
                'file_path': '$testUserId/documents/w.pdf',
              },
            ]);
          }
          if (table == 'profiles' || table == 'security_settings') {
            return jsonResponse([
              {'id': testUserId, 'full_name': 'Alex'},
            ]);
          }
          return jsonResponse([]);
        };

        final data = await UserServiceImpl(
          client: supabase.client,
        ).exportMyData();

        expect(data['account'], {
          'id': testUserId,
          'email': 'alex@example.com',
        });
        expect(data['documents'], hasLength(1));
        expect((data['documents'] as List).single['file_path'], isNotNull);
        expect(data['accounts'], isEmpty);
        expect(data['exportedAt'], isA<String>());
        // Everything was read through the API as the user (so RLS applies).
        expect(
          supabase.requests.every((r) => r.headers['Authorization'] != null),
          isTrue,
        );
        expect(supabase.requests.map((r) => r.method).toSet(), {'GET'});
      },
    );
  });

  group('delete my account', () {
    late UserServiceImpl service;

    setUp(() async {
      await supabase.signIn();
      service = UserServiceImpl(client: supabase.client);
    });

    /// A route that behaves like Storage: it remembers which files exist, lists
    /// a folder's files and sub-folders, and forgets files once they are removed.
    /// [refuseRemoval] makes deletes "succeed" without removing anything, which
    /// is how Storage answers a delete the caller isn't allowed to do.
    Route storage(
      Map<String, Set<String>> buckets, {
      bool refuseRemoval = false,
      Route? fallback,
    }) {
      return (request) {
        final segments = request.path.split('/');
        final isStorage = request.path.startsWith('/storage/v1/object/');
        if (!isStorage) {
          return fallback?.call(request) ?? http.Response('', 204);
        }

        if (request.method == 'POST' &&
            request.path.contains('/object/list/')) {
          final bucket = segments.last;
          final prefix = (request.json as Map)['prefix'] as String;
          final entries = <Map<String, Object?>>[];
          final folders = <String>{};
          for (final path in buckets[bucket] ?? <String>{}) {
            if (!path.startsWith('$prefix/')) continue;
            final rest = path.substring(prefix.length + 1);
            if (rest.contains('/')) {
              folders.add(rest.split('/').first);
            } else {
              entries.add({'name': rest, 'id': path});
            }
          }
          for (final folder in folders) {
            entries.add({'name': folder, 'id': null}); // folders have no id
          }
          return jsonResponse(entries);
        }

        if (request.method == 'DELETE') {
          final bucket = segments[segments.indexOf('object') + 1];
          final prefixes = ((request.json as Map)['prefixes'] as List)
              .cast<String>();
          if (refuseRemoval) return jsonResponse([]);
          final files = buckets[bucket] ?? <String>{};
          final removed = prefixes.where(files.remove).toList();
          return jsonResponse([
            for (final path in removed) {'name': path},
          ]);
        }
        return jsonResponse({});
      };
    }

    test(
      'files are deleted first, then the account, then this device is signed out',
      () async {
        final buckets = {
          'documents': {
            '$testUserId/documents/a.pdf',
            '$testUserId/documents/b.pdf',
          },
          'avatars': {'$testUserId/avatar.png'},
        };
        supabase.route = storage(buckets);

        await service.deleteAccount();

        expect(buckets['documents'], isEmpty);
        expect(buckets['avatars'], isEmpty);

        final order = supabase.requests
            .map((r) => '${r.method} ${r.path}')
            .toList();
        final lastFileRemoval = order.lastIndexWhere(
          (r) => r.startsWith('DELETE /storage/'),
        );
        final rpc = order.indexWhere(
          (r) => r.contains('/rest/v1/rpc/delete_my_account'),
        );
        final logout = order.indexWhere((r) => r.contains('/auth/v1/logout'));

        expect(
          rpc,
          isNonNegative,
          reason: 'the account-deleting function was called',
        );
        expect(
          lastFileRemoval,
          lessThan(rpc),
          reason: 'files must go before the account',
        );
        expect(
          logout,
          greaterThan(rpc),
          reason: 'sign out after the account is gone',
        );
        expect(supabase.client.auth.currentSession, isNull);
      },
    );

    test('only this user\'s folders are ever touched', () async {
      final buckets = {
        'documents': {
          '$testUserId/documents/a.pdf',
          'someone-else/documents/x.pdf',
        },
        'avatars': <String>{},
      };
      supabase.route = storage(buckets);

      await service.deleteAccount();

      expect(buckets['documents'], {'someone-else/documents/x.pdf'});
      for (final request in supabase.where('POST', '/object/list/')) {
        expect((request.json as Map)['prefix'], startsWith(testUserId));
      }
    });

    test(
      'the delete function is called with no arguments, so it can only act on the caller',
      () async {
        supabase.route = storage({
          'documents': <String>{},
          'avatars': <String>{},
        });

        await service.deleteAccount();

        final rpc = supabase.single('POST', '/rest/v1/rpc/delete_my_account');
        expect(rpc.json, anyOf(isNull, isEmpty));
      },
    );

    test('if a file can\'t be removed, the account is NOT deleted', () async {
      supabase.route = (request) {
        if (request.path.contains('/object/list/documents')) {
          return jsonResponse([
            {'name': 'a.pdf', 'id': 'f1'},
          ]);
        }
        if (request.method == 'DELETE' &&
            request.path.startsWith('/storage/')) {
          return errorResponse(500, {
            'message': 'boom',
            'statusCode': '500',
            'error': 'x',
          });
        }
        return jsonResponse([]);
      };

      final error = await failureOf(() => service.deleteAccount());

      expect(error, isA<BackendException>());
      expect(supabase.where('POST', '/rest/v1/rpc/delete_my_account'), isEmpty);
      expect(
        supabase.client.auth.currentSession,
        isNotNull,
        reason: 'still signed in',
      );
    });

    test(
      'if Storage silently refuses a delete, it stops and the account is kept',
      () async {
        // The listing keeps returning the file because it never went away. This
        // must end with an error, not loop forever or delete the account anyway.
        final buckets = {
          'documents': {'$testUserId/documents/stuck.pdf'},
          'avatars': <String>{},
        };
        supabase.route = storage(buckets, refuseRemoval: true);

        final error = await failureOf(() => service.deleteAccount());

        expect(error, isA<BackendException>());
        expect(error.toString(), contains('couldn\'t be removed'));
        expect(
          supabase.where('POST', '/rest/v1/rpc/delete_my_account'),
          isEmpty,
        );
        expect(supabase.client.auth.currentSession, isNotNull);
      },
    );

    test(
      'if the server isn\'t set up for it, the message says how to fix that',
      () async {
        supabase.route = storage(
          {'documents': <String>{}, 'avatars': <String>{}},
          fallback: (request) => errorResponse(404, {
            'code': 'PGRST202',
            'message': 'Could not find the function public.delete_my_account',
            'details': null,
            'hint': null,
          }),
        );

        final error = await failureOf(() => service.deleteAccount());

        expect(error.toString(), contains('migration'));
        expect(supabase.client.auth.currentSession, isNotNull);
      },
    );
  });
}
