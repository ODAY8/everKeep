import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:everkeep/core/utils/data_export_helper.dart';
import 'package:everkeep/features/settings/presentation/screens/settings_screen.dart';
import 'package:everkeep/providers/auth_provider.dart';
import 'package:everkeep/providers/user_provider.dart';

import 'fakes.dart';

class _MockFileSaveAdapter implements FileSaveAdapter {
  String? returnPath = '/storage/emulated/0/Download/everkeep_export.json';
  bool throwException = false;
  bool userCancelled = false;
  Uint8List? savedBytes;
  String? savedFileName;

  @override
  Future<String?> saveFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (throwException) {
      throw Exception('Simulated filesystem error');
    }
    if (userCancelled) {
      return null;
    }
    savedFileName = fileName;
    savedBytes = bytes;
    return returnPath;
  }
}

class _SlowUserRepository extends FakeUserRepository {
  int exportCallCount = 0;
  Future<Map<String, dynamic>> Function()? onExport;

  @override
  Future<Map<String, dynamic>> exportMyData() async {
    exportCallCount++;
    throwIfFailing();
    if (onExport != null) {
      return await onExport!();
    }
    return exportPayload;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DataExportHelper — Payload Structure & Sanitization', () {
    test('1. Export with a normal populated account includes all expected sections', () {
      final payload = DataExportHelper.buildExportPayload(
        userId: 'user-123',
        userEmail: 'alex@example.com',
        profile: {
          'full_name': 'Alex Morgan',
          'phone': '+15551234567',
          'avatar_url': 'https://storage.supabase.co/avatars/user-123/avatar.png',
        },
        documents: [
          {
            'id': 'doc-1',
            'title': 'Passport',
            'category': 'Identity',
            'file_path': 'user-123/documents/passport.pdf',
            'file_size': 1024500,
            'mime_type': 'application/pdf',
          },
        ],
        accounts: [
          {
            'id': 'acc-1',
            'name': 'Main Checking',
            'category': 'Banking',
            'username': 'alex.morgan',
          },
        ],
        trustedContacts: [
          {
            'id': 'tc-1',
            'name': 'Jordan Morgan',
            'relationship': 'Spouse',
            'access_level': 'Full Access',
          },
        ],
        memories: [
          {
            'id': 'mem-1',
            'type': 'memory',
            'title': 'Family Vacation in Japan',
            'content': 'We visited Kyoto in the spring.',
            'date': '2024-04-12',
            'location': 'Kyoto, Japan',
            'tags': 'japan, vacation, spring',
            'memory_media': [
              {
                'id': 'media-1',
                'file_path': 'user-123/memories/mem-1/photo_123.jpg',
                'media_type': 'photo',
                'mime_type': 'image/jpeg',
                'file_size': 3500200,
              },
            ],
          },
        ],
        securitySettings: {
          'two_factor_enabled': true,
          'biometric_enabled': false,
          'login_alerts_enabled': true,
        },
      );

      expect(payload['account'], {'id': 'user-123', 'email': 'alex@example.com'});
      expect(payload['profile']['full_name'], 'Alex Morgan');
      expect((payload['documents'] as List).length, 1);
      expect((payload['accounts'] as List).length, 1);
      expect((payload['importantInformation'] as List).length, 1);
      expect((payload['trustedContacts'] as List).length, 1);
      expect((payload['memories'] as List).length, 1);
      expect(payload['securitySettings']['two_factor_enabled'], isTrue);
    });

    test('2. Export with no documents produces empty list without error', () {
      final payload = DataExportHelper.buildExportPayload(
        userId: 'user-nodocs',
        userEmail: 'user@example.com',
        documents: [],
      );

      expect(payload['documents'], isEmpty);
      expect(payload['documents'], isA<List>());
    });

    test('3. Export with no memories produces empty list without error', () {
      final payload = DataExportHelper.buildExportPayload(
        userId: 'user-nomem',
        userEmail: 'user@example.com',
        memories: [],
      );

      expect(payload['memories'], isEmpty);
      expect(payload['memories'], isA<List>());
    });

    test('4. Export with multiple entity types includes all distinct datasets', () {
      final payload = DataExportHelper.buildExportPayload(
        userId: 'user-multi',
        userEmail: 'multi@example.com',
        documents: [
          {'id': 'd1', 'title': 'Doc 1'},
          {'id': 'd2', 'title': 'Doc 2'},
        ],
        accounts: [
          {'id': 'a1', 'name': 'Acc 1'},
        ],
        trustedContacts: [
          {'id': 'c1', 'name': 'Contact 1'},
        ],
        memories: [
          {'id': 'm1', 'title': 'Mem 1'},
          {'id': 'w1', 'type': 'wish', 'title': 'Wish 1'},
        ],
      );

      expect((payload['documents'] as List).length, 2);
      expect((payload['accounts'] as List).length, 1);
      expect((payload['trustedContacts'] as List).length, 1);
      expect((payload['memories'] as List).length, 2);
    });

    test('5. Correct export version is present and matches current standard', () {
      final payload = DataExportHelper.buildExportPayload(
        userId: 'u1',
        userEmail: 'u1@example.com',
      );

      expect(payload['exportVersion'], '1.0.0');
      expect(payload['exportVersion'], DataExportHelper.currentExportVersion);
    });

    test('6. Correct timestamp presence and ISO-8601 UTC format', () {
      final fixedDate = DateTime.utc(2026, 9, 27, 2, 30, 0);
      final payload = DataExportHelper.buildExportPayload(
        userId: 'u1',
        userEmail: 'u1@example.com',
        exportedAt: fixedDate,
      );

      expect(payload['exportedAt'], '2026-09-27T02:30:00.000Z');
      expect(DateTime.tryParse(payload['exportedAt'] as String), isNotNull);
    });

    test('7. Documents included correctly with structured metadata preserved', () {
      final docRow = {
        'id': 'doc-42',
        'title': 'Will & Testament',
        'document_type': 'Legal',
        'file_path': 'user-1/documents/will.pdf',
        'file_name': 'will.pdf',
        'mime_type': 'application/pdf',
        'file_size': 2048576,
        'category': 'Legal',
        'notes': 'Original stored at attorney office.',
        'issue_date': '2023-01-15',
        'expiry_date': null,
      };

      final payload = DataExportHelper.buildExportPayload(
        userId: 'user-1',
        userEmail: 'user@example.com',
        documents: [docRow],
      );

      final exportedDoc = (payload['documents'] as List).single as Map<String, dynamic>;
      expect(exportedDoc['id'], 'doc-42');
      expect(exportedDoc['title'], 'Will & Testament');
      expect(exportedDoc['file_path'], 'user-1/documents/will.pdf');
      expect(exportedDoc['file_size'], 2048576);
      expect(exportedDoc['mime_type'], 'application/pdf');
      expect(exportedDoc['notes'], 'Original stored at attorney office.');
    });

    test('8. Memories included correctly with tags, location, dates, and media metadata', () {
      final memoryRow = {
        'id': 'mem-10',
        'type': 'memory',
        'title': 'First marathon',
        'content': 'Completed in 3 hours 45 minutes.',
        'date': '2025-10-14',
        'location': 'Chicago, IL',
        'tags': 'running, marathon, personal',
        'memory_media': [
          {
            'id': 'med-1',
            'media_type': 'photo',
            'file_path': 'user/mem/finish_line.jpg',
            'file_size': 1204000,
            'caption': 'At the finish line',
            'display_order': 0,
          },
          {
            'id': 'med-2',
            'media_type': 'audio',
            'file_path': 'user/mem/post_race_voice.m4a',
            'file_size': 512000,
            'duration_seconds': 48,
            'caption': 'Post race thoughts',
            'display_order': 1,
          },
        ],
      };

      final payload = DataExportHelper.buildExportPayload(
        userId: 'user-1',
        userEmail: 'user@example.com',
        memories: [memoryRow],
      );

      final exportedMem = (payload['memories'] as List).single as Map<String, dynamic>;
      expect(exportedMem['id'], 'mem-10');
      expect(exportedMem['tags'], 'running, marathon, personal');
      expect(exportedMem['location'], 'Chicago, IL');
      expect(exportedMem['date'], '2025-10-14');
      final mediaList = exportedMem['memory_media'] as List;
      expect(mediaList.length, 2);
      expect(mediaList[0]['media_type'], 'photo');
      expect(mediaList[1]['duration_seconds'], 48);
    });

    test('9. Accounts included correctly with category and username', () {
      final accountRow = {
        'id': 'acc-99',
        'name': 'Retirement 401(k)',
        'category': 'Banking',
        'username': 'alex_investor',
        'website_url': 'https://fidelity.com',
        'notes': 'Company match 6%',
      };

      final payload = DataExportHelper.buildExportPayload(
        userId: 'user-1',
        userEmail: 'user@example.com',
        accounts: [accountRow],
      );

      final exportedAcc = (payload['accounts'] as List).single as Map<String, dynamic>;
      expect(exportedAcc['name'], 'Retirement 401(k)');
      expect(exportedAcc['category'], 'Banking');
      expect(exportedAcc['username'], 'alex_investor');
      expect(exportedAcc['website_url'], 'https://fidelity.com');
    });

    test('10. Trusted Contacts included correctly with relationship and access level', () {
      final contactRow = {
        'id': 'tc-55',
        'name': 'Taylor Swift',
        'relationship': 'Sister',
        'access_level': 'Emergency Contact',
        'avatar_url': '',
      };

      final payload = DataExportHelper.buildExportPayload(
        userId: 'user-1',
        userEmail: 'user@example.com',
        trustedContacts: [contactRow],
      );

      final exportedContact =
          (payload['trustedContacts'] as List).single as Map<String, dynamic>;
      expect(exportedContact['name'], 'Taylor Swift');
      expect(exportedContact['relationship'], 'Sister');
      expect(exportedContact['access_level'], 'Emergency Contact');
    });

    test('11. Important Information is included and mirrors accounts', () {
      final accountRow = {
        'id': 'acc-1',
        'name': 'Home Wi-Fi & Utilities',
        'category': 'Work',
        'username': 'admin',
      };

      final payload = DataExportHelper.buildExportPayload(
        userId: 'user-1',
        userEmail: 'user@example.com',
        accounts: [accountRow],
      );

      expect(payload['importantInformation'], equals(payload['accounts']));
      expect((payload['importantInformation'] as List).single['name'],
          'Home Wi-Fi & Utilities');
    });

    test('12. Empty/null optional fields handled safely', () {
      final payload = DataExportHelper.buildExportPayload(
        userId: 'user-minimal',
        userEmail: null,
        profile: null,
        documents: [],
        accounts: [],
        trustedContacts: [],
        memories: [],
        securitySettings: null,
      );

      expect(payload['account']['id'], 'user-minimal');
      expect(payload['account']['email'], '');
      expect(payload['profile'], isNull);
      expect(payload['securitySettings'], isNull);
      expect(payload['documents'], isEmpty);
      expect(payload['accounts'], isEmpty);
      expect(payload['trustedContacts'], isEmpty);
      expect(payload['memories'], isEmpty);

      // Verify that this minimal payload serializes cleanly to valid JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
      expect(jsonString, isA<String>());
      expect(jsonDecode(jsonString), isA<Map<String, dynamic>>());
    });

    test('13. Sensitive authentication/session credentials are NOT exported', () {
      final payload = DataExportHelper.buildExportPayload(
        userId: 'user-sensitive',
        userEmail: 'user@example.com',
        profile: {
          'full_name': 'Safe User',
          'password': 'SUPER_SECRET_PASSWORD',
          'access_token': 'eyJhbGciOi...',
          'refresh_token': 'def456...',
          'token': 'secret-token',
          'jwt': 'jwt-string',
          'service_role': 'service-key',
          'api_key': 'secret-api-key',
          'secret': 'super-secret',
          'session': 'session-cookie',
        },
        documents: [
          {
            'id': 'doc-1',
            'title': 'Test Doc',
            'password': 'file-password',
            'access_token': 'stolen-token',
          }
        ],
      );

      final cleanProfile = payload['profile'] as Map<String, dynamic>;
      expect(cleanProfile['full_name'], 'Safe User');
      expect(cleanProfile.containsKey('password'), isFalse);
      expect(cleanProfile.containsKey('access_token'), isFalse);
      expect(cleanProfile.containsKey('refresh_token'), isFalse);
      expect(cleanProfile.containsKey('token'), isFalse);
      expect(cleanProfile.containsKey('jwt'), isFalse);
      expect(cleanProfile.containsKey('service_role'), isFalse);
      expect(cleanProfile.containsKey('api_key'), isFalse);
      expect(cleanProfile.containsKey('secret'), isFalse);
      expect(cleanProfile.containsKey('session'), isFalse);

      final cleanDoc = (payload['documents'] as List).single as Map<String, dynamic>;
      expect(cleanDoc['title'], 'Test Doc');
      expect(cleanDoc.containsKey('password'), isFalse);
      expect(cleanDoc.containsKey('access_token'), isFalse);
    });
  });

  group('DataExportHelper — File Save & Naming', () {
    test('Filename generator creates standardized timestamps', () {
      final date = DateTime.utc(2026, 9, 27, 14, 5, 9);
      final filename = DataExportHelper.exportFileName(date);
      expect(filename, 'everkeep_export_20260927_140509.json');
    });

    test('16. Export output can be saved to file successfully via adapter', () async {
      final mockAdapter = _MockFileSaveAdapter();
      const testJson = '{\n  "exportVersion": "1.0.0"\n}';

      final result = await DataExportHelper.saveExportJson(
        testJson,
        adapter: mockAdapter,
        customFileName: 'custom_export.json',
      );

      expect(result.isSuccess, isTrue);
      expect(result.filePath, '/storage/emulated/0/Download/everkeep_export.json');
      expect(mockAdapter.savedFileName, 'custom_export.json');
      expect(utf8.decode(mockAdapter.savedBytes!), testJson);
    });

    test('Export save returns cancelled when user dismisses file picker', () async {
      final mockAdapter = _MockFileSaveAdapter()..userCancelled = true;

      final result = await DataExportHelper.saveExportJson(
        '{}',
        adapter: mockAdapter,
      );

      expect(result.isCancelled, isTrue);
      expect(result.filePath, isNull);
      expect(result.message, 'Export save cancelled.');
    });

    test('Export save handles file system exceptions gracefully', () async {
      final mockAdapter = _MockFileSaveAdapter()..throwException = true;

      final result = await DataExportHelper.saveExportJson(
        '{}',
        adapter: mockAdapter,
      );

      expect(result.isFailed, isTrue);
      expect(result.message, contains('Simulated filesystem error'));
    });
  });

  group('UserProvider — Export State Management', () {
    test('14. Duplicate export operation is prevented while export is running', () async {
      final repo = _SlowUserRepository();
      final provider = UserProvider(userRepository: repo);

      // Simulate asynchronous export delay
      repo.onExport = () async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return repo.exportPayload;
      };

      // Launch first export
      final firstFuture = provider.exportData();
      expect(provider.isExporting, isTrue);

      // Launch duplicate export while first is still pending
      final secondFuture = provider.exportData();

      // Second call should return immediately with null
      final secondResult = await secondFuture;
      expect(secondResult, isNull);
      expect(repo.exportCallCount, 1, reason: 'Duplicate export must not call repository twice');

      // First export completes successfully
      final firstResult = await firstFuture;
      expect(firstResult, isNotNull);
      expect(provider.isExporting, isFalse);
    });

    test('15. Export failure is handled cleanly and resets isExporting', () async {
      final repo = FakeUserRepository();
      repo.failWith = 'Connection timeout while fetching data.';
      final provider = UserProvider(userRepository: repo);

      expect(provider.isExporting, isFalse);
      final result = await provider.exportData();

      expect(result, isNull);
      expect(provider.error, 'Connection timeout while fetching data.');
      expect(provider.isExporting, isFalse, reason: 'isExporting must be cleared after failure');
    });

    test('reset clears isExporting and lastExportData', () async {
      final repo = FakeUserRepository();
      final provider = UserProvider(userRepository: repo);

      await provider.exportData();
      expect(provider.lastExportData, isNotNull);

      provider.reset();
      expect(provider.isExporting, isFalse);
      expect(provider.lastExportData, isNull);
      expect(provider.error, isNull);
    });
  });

  group('SettingsScreen — UI & Regression Workflow', () {
    String? copied;
    late _MockFileSaveAdapter mockFileSave;

    setUp(() {
      copied = null;
      mockFileSave = _MockFileSaveAdapter();
      DataExportHelper.fileSaveAdapter = mockFileSave;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      DataExportHelper.fileSaveAdapter = const PlatformFileSaveAdapter();
    });

    testWidgets('17. Existing export behavior: copies to clipboard and shows snackbar', (
      tester,
    ) async {
      final repo = FakeUserRepository();
      final auth = FakeAuthRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider(authRepository: auth)),
            ChangeNotifierProvider(create: (_) => UserProvider(userRepository: repo)),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      expect(find.text('Download My Data'), findsOneWidget);
      await tester.tap(find.text('Download My Data'));
      await tester.pumpAndSettle();

      expect(copied, isNotNull);
      expect(copied, contains('sarah.mitchell@example.com'));
      expect(find.textContaining('Copied to your clipboard'), findsOneWidget);
      expect(find.text('Save File'), findsOneWidget);
    });

    testWidgets('Tapping Save File action invokes file saver with feedback', (
      tester,
    ) async {
      final repo = FakeUserRepository();
      final auth = FakeAuthRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider(authRepository: auth)),
            ChangeNotifierProvider(create: (_) => UserProvider(userRepository: repo)),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.tap(find.text('Download My Data'));
      await tester.pumpAndSettle();

      expect(find.text('Save File'), findsOneWidget);
      await tester.tap(find.text('Save File'));
      await tester.pumpAndSettle();

      expect(find.text('Export saved successfully.'), findsOneWidget);
      expect(mockFileSave.savedBytes, isNotNull);
    });

    testWidgets('Export failure offers Retry action button in SnackBar', (
      tester,
    ) async {
      final repo = FakeUserRepository();
      repo.failWith = 'Database unreachable.';
      final auth = FakeAuthRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider(authRepository: auth)),
            ChangeNotifierProvider(create: (_) => UserProvider(userRepository: repo)),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.tap(find.text('Download My Data'));
      await tester.pumpAndSettle();

      expect(find.text('Database unreachable.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Now fix failure and verify retry recovers
      repo.failWith = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(copied, isNotNull);
      expect(find.textContaining('Copied to your clipboard'), findsOneWidget);
    });
  });
}
