import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:everkeep/core/config/supabase_config.dart';
import 'package:everkeep/core/supabase/supabase_errors.dart';
import 'package:everkeep/core/utils/relative_time.dart';
import 'package:everkeep/models/account_item.dart';
import 'package:everkeep/models/security_settings.dart';
import 'package:everkeep/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

String _jwtWithRole(String role) {
  String part(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'role': role, 'iss': 'supabase'})}.sig';
}

void main() {
  group('SupabaseConfig.validate', () {
    String? check(String url, String key) =>
        SupabaseConfig.validate(url: url, publishableKey: key);

    test('accepts a project URL with a publishable key', () {
      expect(
        check('https://abcdefgh.supabase.co', 'sb_publishable_AbC123'),
        isNull,
      );
    });

    test('accepts a legacy anon (JWT) key', () {
      expect(
        check('https://abcdefgh.supabase.co', _jwtWithRole('anon')),
        isNull,
      );
    });

    test('accepts a local-development URL', () {
      expect(check('http://127.0.0.1:54321', 'sb_publishable_local'), isNull);
    });

    test('rejects missing values', () {
      expect(check('', ''), contains('not set'));
      expect(check('https://abcdefgh.supabase.co', ''), contains('not set'));
      expect(check('', 'sb_publishable_x'), contains('not set'));
    });

    test('rejects the placeholders from .env.example', () {
      expect(
        check('https://xxxxx.supabase.co', 'xxxxx'),
        contains('placeholder'),
      );
    });

    test('rejects something that is not a URL', () {
      expect(
        check('abcdefgh.supabase.co', 'sb_publishable_x'),
        contains('full URL'),
      );
      expect(
        check('ftp://abcdefgh.supabase.co', 'sb_publishable_x'),
        contains('full URL'),
      );
    });

    test('refuses a service-role key (legacy JWT form)', () {
      expect(
        check('https://abcdefgh.supabase.co', _jwtWithRole('service_role')),
        contains('secret'),
      );
    });

    test('refuses a secret key (new form)', () {
      expect(
        check('https://abcdefgh.supabase.co', 'sb_secret_AbC123'),
        contains('secret'),
      );
    });

    test(
      'nothing supplied means not configured, so the app refuses to start',
      () {
        // Plain `flutter test` passes no --dart-define, so the values are empty.
        // (If they are supplied, the check above already covers them.)
        if (SupabaseConfig.url.isEmpty &&
            SupabaseConfig.publishableKey.isEmpty) {
          expect(SupabaseConfig.isConfigured, isFalse);
          expect(SupabaseConfig.problem, isNotNull);
        }
      },
    );
  });

  group('error translation', () {
    String message(Object error) => translateSupabaseError(error).message;

    test(
      'row-level-security violations are "no permission", not a schema leak',
      () {
        final text = message(
          const PostgrestException(
            message:
                'new row violates row-level security policy for table "documents"',
            code: '42501',
          ),
        );
        expect(text, 'You don\'t have permission to do that.');
        expect(text, isNot(contains('documents')));
      },
    );

    test('constraint problems ask the user to check their input', () {
      for (final code in ['23514', '23502', '22001', '22P02']) {
        expect(
          message(
            PostgrestException(message: 'check constraint "x"', code: code),
          ),
          contains('isn\'t valid'),
          reason: code,
        );
      }
    });

    test('an expired token asks the user to sign in again', () {
      expect(
        message(
          const PostgrestException(message: 'JWT expired', code: 'PGRST301'),
        ),
        'Your session has expired. Please sign in again.',
      );
      expect(
        message(const AuthException('bad', code: 'refresh_token_not_found')),
        'Your session has expired. Please sign in again.',
      );
    });

    test('a single-row lookup that found nothing reads as "not found"', () {
      expect(
        message(
          const PostgrestException(message: 'Cannot coerce', code: 'PGRST116'),
        ),
        contains('couldn\'t be found'),
      );
    });

    test('unknown database errors never expose their details', () {
      final text = message(
        const PostgrestException(
          message: 'relation "public.secret_table" does not exist',
          code: '42P01',
          details: 'select * from secret_table',
          hint: 'Perhaps you meant public.accounts',
        ),
      );
      expect(text, isNot(contains('secret_table')));
      expect(text, isNot(contains('accounts')));
    });

    test('offline and timeouts all read as a connection problem', () {
      final offline = [
        http.ClientException('x'),
        TimeoutException('x'),
        const SocketException('x'),
        AuthRetryableFetchException(message: 'x'),
      ];
      for (final error in offline) {
        expect(
          message(error),
          contains('Can\'t reach the server'),
          reason: '$error',
        );
      }
    });

    test('storage errors are explained', () {
      expect(
        message(const StorageException('big', statusCode: '413')),
        'That file is too large.',
      );
      expect(
        message(const StorageException('no', statusCode: '403')),
        contains('permission'),
      );
    });

    test(
      'guardBackend converts exceptions but does not hide programming errors',
      () async {
        await expectLater(
          guardBackend<void>(
            () async =>
                throw const PostgrestException(message: 'x', code: '42501'),
          ),
          throwsA(isA<BackendException>()),
        );
        await expectLater(
          guardBackend<void>(() async => throw StateError('a real bug')),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('an already-translated error passes through untouched', () {
      const original = BackendException('Already friendly.');
      expect(translateSupabaseError(original), same(original));
    });
  });

  group('relativeTime', () {
    final now = DateTime(2026, 9, 21, 12);
    String at(Duration ago) => relativeTime(now.subtract(ago), now: now);

    test('reads naturally at each scale', () {
      expect(at(const Duration(seconds: 20)), 'just now');
      expect(at(const Duration(minutes: 1)), '1 minute ago');
      expect(at(const Duration(minutes: 45)), '45 minutes ago');
      expect(at(const Duration(hours: 1)), '1 hour ago');
      expect(at(const Duration(hours: 23)), '23 hours ago');
      expect(at(const Duration(days: 1)), 'yesterday');
      expect(at(const Duration(days: 3)), '3 days ago');
      expect(at(const Duration(days: 7)), '1 week ago');
      expect(at(const Duration(days: 20)), '2 weeks ago');
      expect(at(const Duration(days: 45)), '1 month ago');
      expect(at(const Duration(days: 400)), '1 year ago');
    });

    test('a timestamp slightly in the future (clock skew) is "just now"', () {
      expect(
        relativeTime(now.add(const Duration(seconds: 30)), now: now),
        'just now',
      );
    });
  });

  group('User', () {
    test('identity comes from Auth; the profile row supplies the rest', () {
      final user = User.fromAuth(
        id: 'u1',
        email: 'a@b.co',
        profile: {
          'full_name': 'Alexandra',
          'phone': '555',
          'avatar_url': 'p.png',
        },
        metadataName: 'Alex',
      );
      expect(user.id, 'u1');
      expect(user.email, 'a@b.co');
      expect(user.name, 'Alexandra');
      expect(user.phone, '555');
      expect(user.avatarUrl, 'p.png');
      expect(user.isAuthenticated, isTrue);
    });

    test('before the profile loads, the sign-up name is used', () {
      final user = User.fromAuth(
        id: 'u1',
        email: 'a@b.co',
        metadataName: 'Alex',
      );
      expect(user.name, 'Alex');
    });

    test('a blank profile name falls back to the sign-up name', () {
      final user = User.fromAuth(
        id: 'u1',
        email: 'a@b.co',
        profile: {'full_name': '  '},
        metadataName: 'Alex',
      );
      expect(user.name, 'Alex');
    });

    test(
      'a user with no email (phone-only auth) has an empty one, not null',
      () {
        expect(User.fromAuth(id: 'u1', email: null).email, '');
      },
    );

    test(
      'profile updates never include the email, and blank phone clears it',
      () {
        const user = User(
          id: 'u1',
          name: ' Jane ',
          email: 'x@y.z',
          phone: '   ',
        );
        expect(user.toProfileRow(), {
          'full_name': 'Jane',
          'phone': null,
          'avatar_url': null,
        });
      },
    );
  });

  group('AccountItem.styleFor', () {
    test('maps the known categories and defaults everything else', () {
      expect(AccountItem.styleFor('Banking').$1, Icons.account_balance_rounded);
      expect(AccountItem.styleFor('Social').$1, Icons.public_rounded);
      expect(AccountItem.styleFor('Work').$1, Icons.work_outline_rounded);
      expect(AccountItem.styleFor('Other').$1, Icons.key_rounded);
      expect(AccountItem.styleFor('Anything else').$1, Icons.key_rounded);
    });
  });

  group('SecuritySettings', () {
    test(
      'everything is off by default — a new account claims no protection',
      () {
        const settings = SecuritySettings();
        expect(settings.enabledCount, 0);
      },
    );

    test('rows round-trip', () {
      const original = SecuritySettings(
        twoFactorEnabled: true,
        loginAlertsEnabled: true,
      );
      final copy = SecuritySettings.fromRow(original.toRow());
      expect(copy.twoFactorEnabled, isTrue);
      expect(copy.biometricEnabled, isFalse);
      expect(copy.loginAlertsEnabled, isTrue);
    });
  });
}
