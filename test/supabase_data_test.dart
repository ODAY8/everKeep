import 'dart:typed_data';

import 'package:everkeep/core/supabase/supabase_errors.dart';
import 'package:everkeep/models/account_item.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/models/document_upload.dart';
import 'package:everkeep/models/memory_item.dart';
import 'package:everkeep/models/security_settings.dart';
import 'package:everkeep/models/trusted_contact_item.dart';
import 'package:everkeep/models/user.dart';
import 'package:everkeep/services/account_service.dart';
import 'package:everkeep/services/document_service.dart';
import 'package:everkeep/services/memory_service.dart';
import 'package:everkeep/services/settings_service.dart';
import 'package:everkeep/services/trusted_contact_service.dart';
import 'package:everkeep/services/user_service.dart';
import 'package:everkeep/services/vault_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/fake_supabase.dart';

/// The real service classes, run against a real SupabaseClient whose HTTP layer
/// is faked. Each test checks what was sent (the right table, filters and body
/// — never a client-chosen owner) and that failures surface as failures.
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

  String daysAgo(int days) =>
      DateTime.now().subtract(Duration(days: days)).toUtc().toIso8601String();

  Map<String, Object?> docRow({
    String id = 'doc-1',
    String title = 'Will.pdf',
    String category = 'Legal',
    String? filePath,
    bool verified = false,
    int age = 2,
  }) => {
    'id': id,
    'user_id': testUserId,
    'title': title,
    'category': category,
    'file_path': filePath,
    'is_verified': verified,
    'created_at': daysAgo(age),
    'updated_at': daysAgo(age),
  };

  Map<String, Object?> memoryRow({
    String id = 'mem-1',
    String title = 'Summer at the lake',
    String content = 'We spent the whole week there.',
    String type = 'memory',
    String? date,
    String? filePath,
    int age = 2,
  }) => {
    'id': id,
    'user_id': testUserId,
    'title': title,
    'content': content,
    'type': type,
    'date': date,
    'file_path': filePath,
    'file_size': filePath == null ? null : 2048,
    'mime_type': filePath == null ? null : 'image/jpeg',
    'created_at': daysAgo(age),
    'updated_at': daysAgo(age),
  };

  Map<String, Object?> accountRow({
    String id = 'acc-1',
    String name = 'GitHub',
    String? username = 'alex@dev.io',
    String category = 'Work',
    bool favorite = false,
  }) => {
    'id': id,
    'user_id': testUserId,
    'name': name,
    'username': username,
    'category': category,
    'is_favorite': favorite,
    'created_at': daysAgo(3),
    'updated_at': daysAgo(1),
  };

  http.Response rlsViolation() => errorResponse(403, {
    'code': '42501',
    'message':
        'new row violates row-level security policy for table "documents"',
    'details': null,
    'hint': null,
  });

  group('DocumentService', () {
    late DocumentServiceImpl service;

    setUp(() async {
      await supabase.signIn();
      service = DocumentServiceImpl(client: supabase.client);
    });

    test(
      'fetch reads the documents table newest first and maps rows',
      () async {
        supabase.route = (_) => jsonResponse([
          docRow(
            id: 'a',
            verified: true,
            filePath: '$testUserId/documents/a.pdf',
          ),
          docRow(id: 'b', title: 'Deed.pdf', category: 'Legal', age: 30),
        ]);

        final documents = await service.fetchDocuments();

        final request = supabase.single('GET', '/rest/v1/documents');
        expect(request.query['order'], startsWith('created_at.desc'));
        expect(documents.map((d) => d.id), ['a', 'b']);
        expect(documents.first.isVerified, isTrue);
        expect(documents.first.filePath, '$testUserId/documents/a.pdf');
        // Derived from created_at, so it can't go stale.
        expect(documents.first.subtitle, 'Legal · Added 2 days ago');
        expect(documents.last.subtitle, 'Legal · Added 1 month ago');
      },
    );

    test(
      'add sends only the writable columns — never an owner or a verified flag',
      () async {
        supabase.route = (_) =>
            jsonResponse(docRow(id: 'new', title: 'Passport.pdf', age: 0));

        final saved = await service.addDocument(
          const DocumentItem(
            id: '',
            title: '  Passport.pdf ',
            subtitle: '',
            category: 'Legal',
          ),
        );

        final request = supabase.single('POST', '/rest/v1/documents');
        expect(request.json, {'title': 'Passport.pdf', 'category': 'Legal'});
        expect(request.headers['Prefer'], contains('return=representation'));
        // The id and subtitle are the server's, not the client's.
        expect(saved.id, 'new');
        expect(saved.subtitle, 'Legal · Added just now');
      },
    );

    test(
      'add with a file uploads to the user\'s own private folder first',
      () async {
        supabase.route = (request) => request.path.startsWith('/storage/')
            ? jsonResponse({'Key': 'documents/x'})
            : jsonResponse(docRow(id: 'new', filePath: 'ignored'));

        await service.addDocument(
          const DocumentItem(
            id: '',
            title: 'Scan',
            subtitle: '',
            category: 'Legal',
          ),
          upload: DocumentUpload(
            fileName: '../../my evil file?.pdf',
            bytes: Uint8List.fromList([1, 2, 3, 4]),
            mimeType: 'application/pdf',
          ),
        );

        // Storage first, then the row that points at it.
        expect(supabase.requests.map((r) => r.method), ['POST', 'POST']);
        final upload = supabase.requests[0];
        final insert = supabase.requests[1];

        expect(
          upload.path,
          startsWith('/storage/v1/object/documents/$testUserId/documents/'),
        );
        final storedName = upload.path.split('/').last;
        expect(storedName, isNot(contains('..')));
        expect(storedName, isNot(contains(' ')));
        expect(storedName, isNot(contains('?')));
        expect(storedName, endsWith('.pdf'));

        final row = insert.json as Map<String, dynamic>;
        expect(row['file_path'], startsWith('$testUserId/documents/'));
        expect(row['file_path'], endsWith(storedName));
        expect(row['file_size'], 4);
        expect(row['mime_type'], 'application/pdf');
        expect(row.containsKey('user_id'), isFalse);
        expect(row.containsKey('is_verified'), isFalse);
      },
    );

    test(
      'if saving the row fails, the uploaded file is removed again',
      () async {
        supabase.route = (request) {
          if (request.method == 'POST' &&
              request.path.startsWith('/storage/')) {
            return jsonResponse({'Key': 'documents/x'});
          }
          if (request.method == 'DELETE' &&
              request.path.startsWith('/storage/')) {
            return jsonResponse([]);
          }
          return rlsViolation();
        };

        final error = await failureOf(
          () => service.addDocument(
            const DocumentItem(
              id: '',
              title: 'Scan',
              subtitle: '',
              category: 'Legal',
            ),
            upload: DocumentUpload(fileName: 'scan.pdf', bytes: Uint8List(2)),
          ),
        );

        expect(error, isA<BackendException>());
        expect(
          supabase.where('DELETE', '/storage/v1/object/documents'),
          hasLength(1),
        );
      },
    );

    test('delete removes the stored file before the row', () async {
      supabase.route = (request) {
        if (request.method == 'GET') {
          return jsonResponse([
            {'file_path': '$testUserId/documents/a.pdf'},
          ]);
        }
        return jsonResponse([]);
      };

      await service.deleteDocument('doc-1');

      expect(
        supabase.requests.map((r) => '${r.method} ${r.path.split('/')[1]}'),
        ['GET rest', 'DELETE storage', 'DELETE rest'],
      );
      expect(supabase.requests[0].query['id'], 'eq.doc-1');
      expect(supabase.requests[2].query['id'], 'eq.doc-1');
    });

    test(
      'if the file can\'t be removed, the row is kept so delete can be retried',
      () async {
        supabase.route = (request) {
          if (request.method == 'GET') {
            return jsonResponse([
              {'file_path': '$testUserId/documents/a.pdf'},
            ]);
          }
          if (request.path.startsWith('/storage/')) {
            return errorResponse(500, {
              'message': 'boom',
              'statusCode': '500',
              'error': 'x',
            });
          }
          return jsonResponse([]);
        };

        final error = await failureOf(() => service.deleteDocument('doc-1'));

        expect(error, isA<BackendException>());
        expect(supabase.where('DELETE', '/rest/v1/documents'), isEmpty);
      },
    );

    test('deleting a document without a file never touches Storage', () async {
      supabase.route = (request) => request.method == 'GET'
          ? jsonResponse([
              {'file_path': null},
            ])
          : jsonResponse([]);

      await service.deleteDocument('doc-1');

      expect(
        supabase.requests.where((r) => r.path.startsWith('/storage/')),
        isEmpty,
      );
      expect(supabase.where('DELETE', '/rest/v1/documents'), hasLength(1));
    });

    test(
      'download links are short-lived signed URLs, not public URLs',
      () async {
        supabase.route = (_) => jsonResponse({
          'signedURL': '/object/sign/documents/a.pdf?token=abc',
        });

        final url = await service.createDownloadUrl(
          '$testUserId/documents/a.pdf',
        );

        final request = supabase.single(
          'POST',
          '/storage/v1/object/sign/documents/',
        );
        expect((request.json as Map)['expiresIn'], 300);
        expect(url, contains('token=abc'));
      },
    );

    test(
      'a database rejection becomes a safe message that leaks nothing',
      () async {
        supabase.route = (_) => rlsViolation();

        final error = await failureOf(
          () => service.addDocument(
            const DocumentItem(
              id: '',
              title: 'x',
              subtitle: '',
              category: 'Legal',
            ),
          ),
        );

        expect(error.toString(), 'You don\'t have permission to do that.');
        expect(error.toString(), isNot(contains('row-level security')));
        expect(error.toString(), isNot(contains('documents')));
      },
    );
  });

  group('MemoryService', () {
    late MemoryServiceImpl service;

    setUp(() async {
      await supabase.signIn();
      service = MemoryServiceImpl(client: supabase.client);
    });

    test(
      'fetch reads the memories_wishes table newest first and maps rows',
      () async {
        supabase.route = (_) => jsonResponse([
          memoryRow(id: 'a', filePath: '$testUserId/memories/a.jpg'),
          memoryRow(id: 'b', title: 'For my daughter', type: 'wish', age: 30),
        ]);

        final items = await service.fetchMemories();

        final request = supabase.single('GET', '/rest/v1/memories_wishes');
        expect(request.query['order'], startsWith('created_at.desc'));
        expect(items.map((m) => m.id), ['a', 'b']);
        expect(items.first.hasAttachment, isTrue);
        expect(items.first.filePath, '$testUserId/memories/a.jpg');
        expect(items.last.isWish, isTrue);
        expect(items.last.subtitle, 'Wish · Added 1 month ago');
      },
    );

    test('fetchMemory reads a single row by id', () async {
      supabase.route = (_) => jsonResponse([memoryRow(id: 'mem-9')]);

      final item = await service.fetchMemory('mem-9');

      expect(supabase.single('GET', '/rest/v1/memories_wishes').query['id'], 'eq.mem-9');
      expect(item.id, 'mem-9');
    });

    test('fetching an item that isn\'t there fails instead of pretending', () async {
      supabase.route = (_) => jsonResponse([]); // RLS hides it, or it's gone

      final error = await failureOf(() => service.fetchMemory('gone'));
      expect(error.toString(), contains('couldn\'t be found'));
    });

    test(
      'add sends only the writable columns — never an owner or the id',
      () async {
        supabase.route = (_) => jsonResponse(memoryRow(id: 'new', age: 0));

        final saved = await service.createMemory(
          const MemoryItem(
            id: '',
            title: '  Summer at the lake ',
            content: ' We spent the whole week there. ',
            type: 'memory',
          ),
        );

        final request = supabase.single('POST', '/rest/v1/memories_wishes');
        expect(request.json, {
          'title': 'Summer at the lake',
          'content': 'We spent the whole week there.',
          'type': 'memory',
        });
        expect(request.headers['Prefer'], contains('return=representation'));
        expect(saved.id, 'new');
      },
    );

    test(
      'add with a file uploads to the user\'s own private folder first',
      () async {
        supabase.route = (request) => request.path.startsWith('/storage/')
            ? jsonResponse({'Key': 'memories/x'})
            : jsonResponse(memoryRow(id: 'new', filePath: 'ignored'));

        await service.createMemory(
          const MemoryItem(id: '', title: 'A photo', content: '', type: 'memory'),
          upload: DocumentUpload(
            fileName: '../../evil?.jpg',
            bytes: Uint8List.fromList([1, 2, 3, 4]),
            mimeType: 'image/jpeg',
          ),
        );

        expect(supabase.requests.map((r) => r.method), ['POST', 'POST']);
        final upload = supabase.requests[0];
        final insert = supabase.requests[1];

        expect(
          upload.path,
          startsWith('/storage/v1/object/memories/$testUserId/memories/'),
        );
        final storedName = upload.path.split('/').last;
        expect(storedName, isNot(contains('..')));
        expect(storedName, isNot(contains('?')));
        expect(storedName, endsWith('.jpg'));

        final row = insert.json as Map<String, dynamic>;
        expect(row['file_path'], startsWith('$testUserId/memories/'));
        expect(row['file_size'], 4);
        expect(row['mime_type'], 'image/jpeg');
        expect(row.containsKey('user_id'), isFalse);
      },
    );

    test(
      'if saving the row fails, the uploaded file is removed again',
      () async {
        supabase.route = (request) {
          if (request.method == 'POST' && request.path.startsWith('/storage/')) {
            return jsonResponse({'Key': 'memories/x'});
          }
          if (request.method == 'DELETE' && request.path.startsWith('/storage/')) {
            return jsonResponse([]);
          }
          return rlsViolation();
        };

        final error = await failureOf(
          () => service.createMemory(
            const MemoryItem(id: '', title: 'A photo', content: '', type: 'memory'),
            upload: DocumentUpload(fileName: 'a.jpg', bytes: Uint8List(2)),
          ),
        );

        expect(error, isA<BackendException>());
        expect(supabase.where('DELETE', '/storage/v1/object/memories'), hasLength(1));
      },
    );

    test('update targets the row by id and keeps the existing attachment', () async {
      supabase.route = (_) =>
          jsonResponse([memoryRow(title: 'Summer at the cabin', filePath: '$testUserId/memories/a.jpg')]);

      final saved = await service.updateMemory(
        MemoryItem(
          id: 'mem-1',
          title: 'Summer at the cabin',
          content: 'Updated.',
          type: 'memory',
          filePath: '$testUserId/memories/a.jpg',
        ),
      );

      final request = supabase.single('PATCH', '/rest/v1/memories_wishes');
      expect(request.query['id'], 'eq.mem-1');
      expect(request.json, {
        'title': 'Summer at the cabin',
        'content': 'Updated.',
        'type': 'memory',
        'date': null,
        'file_path': '$testUserId/memories/a.jpg',
        'file_size': null,
        'mime_type': null,
      });
      expect(saved.title, 'Summer at the cabin');
    });

    test('updating an item that isn\'t there fails instead of pretending', () async {
      supabase.route = (_) => jsonResponse([]);

      final error = await failureOf(
        () => service.updateMemory(
          const MemoryItem(id: 'gone', title: 'x', content: '', type: 'memory'),
        ),
      );

      expect(error.toString(), contains('couldn\'t be found'));
    });

    test('delete removes the stored file before the row', () async {
      supabase.route = (request) {
        if (request.method == 'GET') {
          return jsonResponse([
            {'file_path': '$testUserId/memories/a.jpg'},
          ]);
        }
        return jsonResponse([]);
      };

      await service.deleteMemory('mem-1');

      expect(
        supabase.requests.map((r) => '${r.method} ${r.path.split('/')[1]}'),
        ['GET rest', 'DELETE storage', 'DELETE rest'],
      );
    });

    test(
      'if the file can\'t be removed, the row is kept so delete can be retried',
      () async {
        supabase.route = (request) {
          if (request.method == 'GET') {
            return jsonResponse([
              {'file_path': '$testUserId/memories/a.jpg'},
            ]);
          }
          if (request.path.startsWith('/storage/')) {
            return errorResponse(500, {'message': 'boom', 'statusCode': '500', 'error': 'x'});
          }
          return jsonResponse([]);
        };

        final error = await failureOf(() => service.deleteMemory('mem-1'));

        expect(error, isA<BackendException>());
        expect(supabase.where('DELETE', '/rest/v1/memories_wishes'), isEmpty);
      },
    );

    test('deleting an item without a file never touches Storage', () async {
      supabase.route = (request) => request.method == 'GET'
          ? jsonResponse([
              {'file_path': null},
            ])
          : jsonResponse([]);

      await service.deleteMemory('mem-1');

      expect(supabase.requests.where((r) => r.path.startsWith('/storage/')), isEmpty);
      expect(supabase.where('DELETE', '/rest/v1/memories_wishes'), hasLength(1));
    });

    test(
      'uploadAttachment replaces the file and only then removes the old one',
      () async {
        var getCount = 0;
        supabase.route = (request) {
          if (request.method == 'GET') {
            getCount++;
            return jsonResponse([
              {'file_path': '$testUserId/memories/old.jpg'},
            ]);
          }
          if (request.method == 'POST' && request.path.startsWith('/storage/')) {
            return jsonResponse({'Key': 'memories/new'});
          }
          if (request.method == 'PATCH') {
            return jsonResponse([memoryRow(filePath: '$testUserId/memories/new.jpg')]);
          }
          return jsonResponse([]); // the DELETE of the old file
        };

        final saved = await service.uploadAttachment(
          'mem-1',
          DocumentUpload(fileName: 'new.jpg', bytes: Uint8List.fromList([1, 2])),
        );

        expect(getCount, 1);
        final methods = supabase.requests.map((r) => r.method).toList();
        expect(methods, ['GET', 'POST', 'PATCH', 'DELETE']);
        expect(supabase.requests[3].path, '/storage/v1/object/memories');
        expect(
          (supabase.requests[3].json as Map)['prefixes'],
          contains('$testUserId/memories/old.jpg'),
        );
        expect(saved.filePath, '$testUserId/memories/new.jpg');
      },
    );

    test(
      'uploadAttachment on an item that isn\'t there fails before uploading anything',
      () async {
        supabase.route = (_) => jsonResponse([]);

        final error = await failureOf(
          () => service.uploadAttachment(
            'gone',
            DocumentUpload(fileName: 'a.jpg', bytes: Uint8List(2)),
          ),
        );

        expect(error.toString(), contains('couldn\'t be found'));
        expect(supabase.requests.where((r) => r.path.startsWith('/storage/')), isEmpty);
      },
    );

    test(
      'if saving the new attachment fails, the newly uploaded file is removed',
      () async {
        supabase.route = (request) {
          if (request.method == 'GET') {
            return jsonResponse([
              {'file_path': null},
            ]);
          }
          if (request.method == 'POST' && request.path.startsWith('/storage/')) {
            return jsonResponse({'Key': 'memories/new'});
          }
          if (request.method == 'DELETE' && request.path.startsWith('/storage/')) {
            return jsonResponse([]);
          }
          return rlsViolation(); // the PATCH
        };

        final error = await failureOf(
          () => service.uploadAttachment(
            'mem-1',
            DocumentUpload(fileName: 'new.jpg', bytes: Uint8List(2)),
          ),
        );

        expect(error, isA<BackendException>());
        expect(supabase.where('DELETE', '/storage/v1/object/memories'), hasLength(1));
      },
    );

    test('deleteAttachment clears the row and removes the stored file', () async {
      supabase.route = (request) {
        if (request.method == 'GET') {
          return jsonResponse([
            {'file_path': '$testUserId/memories/a.jpg'},
          ]);
        }
        if (request.method == 'PATCH') {
          return jsonResponse([memoryRow()]); // file_path back to null
        }
        return jsonResponse([]); // the DELETE
      };

      final saved = await service.deleteAttachment('mem-1');

      final patch = supabase.single('PATCH', '/rest/v1/memories_wishes');
      expect(patch.json, {'file_path': null, 'file_size': null, 'mime_type': null});
      expect(
        supabase.where('DELETE', '/storage/v1/object/memories'),
        hasLength(1),
      );
      expect(saved.hasAttachment, isFalse);
    });

    test('deleteAttachment on an item with no file just leaves it as is', () async {
      supabase.route = (request) {
        if (request.method == 'GET') {
          return jsonResponse([
            {'file_path': null},
          ]);
        }
        return jsonResponse([memoryRow()]);
      };

      await service.deleteAttachment('mem-1');

      expect(supabase.requests.where((r) => r.path.startsWith('/storage/')), isEmpty);
    });

    test(
      'download links are short-lived signed URLs, not public URLs',
      () async {
        supabase.route = (_) => jsonResponse({
          'signedURL': '/object/sign/memories/a.jpg?token=abc',
        });

        final url = await service.createDownloadUrl('$testUserId/memories/a.jpg');

        final request = supabase.single('POST', '/storage/v1/object/sign/memories/');
        expect((request.json as Map)['expiresIn'], 300);
        expect(url, contains('token=abc'));
      },
    );

    test(
      'a database rejection becomes a safe message that leaks nothing',
      () async {
        supabase.route = (_) => rlsViolation();

        final error = await failureOf(
          () => service.createMemory(
            const MemoryItem(id: '', title: 'x', content: '', type: 'memory'),
          ),
        );

        expect(error.toString(), 'You don\'t have permission to do that.');
        expect(error.toString(), isNot(contains('row-level security')));
        expect(error.toString(), isNot(contains('memories_wishes')));
      },
    );
  });

  group('AccountService', () {
    late AccountServiceImpl service;

    setUp(() async {
      await supabase.signIn();
      service = AccountServiceImpl(client: supabase.client);
    });

    test('fetch maps rows, deriving icon, color and subtitle', () async {
      supabase.route = (_) => jsonResponse([
        accountRow(favorite: true),
        accountRow(
          id: 'acc-2',
          name: 'Bank',
          username: null,
          category: 'Banking',
        ),
      ]);

      final accounts = await service.fetchAccounts();

      expect(
        supabase.single('GET', '/rest/v1/accounts').query['order'],
        startsWith('created_at.desc'),
      );
      expect(accounts.first.title, 'GitHub');
      expect(accounts.first.isFavorite, isTrue);
      expect(accounts.first.username, 'alex@dev.io');
      expect(accounts.first.subtitle, 'Added 3 days ago · alex@dev.io');
      expect(accounts.first.icon, Icons.work_outline_rounded);
      expect(accounts.last.subtitle, 'Added 3 days ago');
      expect(accounts.last.username, isNull);
      expect(accounts.last.icon, Icons.account_balance_rounded);
    });

    test(
      'add sends the descriptive fields only — there is no secret to send',
      () async {
        supabase.route = (_) => jsonResponse(accountRow(id: 'new'));

        await service.addAccount(
          AccountItem(
            id: '',
            title: ' GitHub ',
            subtitle: '',
            category: 'Work',
            icon: Icons.key_rounded,
            color: Colors.blue,
            username: ' alex@dev.io ',
          ),
        );

        final body =
            supabase.single('POST', '/rest/v1/accounts').json
                as Map<String, dynamic>;
        expect(body, {
          'name': 'GitHub',
          'username': 'alex@dev.io',
          'category': 'Work',
          'is_favorite': false,
        });
      },
    );

    test('update targets the row by id and returns the saved values', () async {
      supabase.route = (_) => jsonResponse([accountRow(name: 'GitHub Pro')]);

      final saved = await service.updateAccount(
        AccountItem(
          id: 'acc-1',
          title: 'GitHub Pro',
          subtitle: '',
          category: 'Work',
          icon: Icons.key_rounded,
          color: Colors.blue,
        ),
      );

      final request = supabase.single('PATCH', '/rest/v1/accounts');
      expect(request.query['id'], 'eq.acc-1');
      expect(request.json, {
        'name': 'GitHub Pro',
        'username': null,
        'category': 'Work',
      });
      expect(saved.title, 'GitHub Pro');
    });

    test(
      'updating an account that isn\'t there fails instead of pretending',
      () async {
        supabase.route = (_) =>
            jsonResponse([]); // RLS hides it, or it was deleted

        final error = await failureOf(
          () => service.updateAccount(
            AccountItem(
              id: 'gone',
              title: 'x',
              subtitle: '',
              icon: Icons.key_rounded,
              color: Colors.blue,
            ),
          ),
        );

        expect(error.toString(), contains('couldn\'t be found'));
      },
    );

    test('setFavorite sends the explicit value for that one row', () async {
      supabase.route = (_) => jsonResponse([
        {'id': 'acc-1'},
      ]);

      await service.setFavorite('acc-1', true);

      final request = supabase.single('PATCH', '/rest/v1/accounts');
      expect(request.query['id'], 'eq.acc-1');
      expect(request.json, {'is_favorite': true});
    });

    test(
      'a favorite that matched no row is a failure (so the UI rolls back)',
      () async {
        supabase.route = (_) => jsonResponse([]);

        final error = await failureOf(() => service.setFavorite('gone', true));

        expect(error, isA<BackendException>());
      },
    );

    test('delete targets the row by id', () async {
      supabase.route = (_) => jsonResponse([]);

      await service.deleteAccount('acc-1');

      expect(
        supabase.single('DELETE', '/rest/v1/accounts').query['id'],
        'eq.acc-1',
      );
    });
  });

  group('TrustedContactService', () {
    late TrustedContactServiceImpl service;

    setUp(() async {
      await supabase.signIn();
      service = TrustedContactServiceImpl(client: supabase.client);
    });

    Map<String, Object?> contactRow({String id = 'tc-1', String? avatar}) => {
      'id': id,
      'user_id': testUserId,
      'name': 'Sarah Johnson',
      'relationship': 'Spouse',
      'access_level': 'Full Access',
      'avatar_url': avatar,
      'created_at': daysAgo(1),
      'updated_at': daysAgo(1),
    };

    test('fetch reads oldest first; a missing avatar becomes empty', () async {
      supabase.route = (_) =>
          jsonResponse([contactRow(), contactRow(id: 'tc-2', avatar: 'a.png')]);

      final contacts = await service.fetchContacts();

      expect(
        supabase.single('GET', '/rest/v1/trusted_contacts').query['order'],
        startsWith('created_at.asc'),
      );
      expect(contacts.first.avatarUrl, '');
      expect(contacts.last.avatarUrl, 'a.png');
      expect(contacts.first.accessLevel, 'Full Access');
    });

    test(
      'add sends the fields, not an owner, and returns the saved row',
      () async {
        supabase.route = (_) => jsonResponse(contactRow(id: 'server-id'));

        final saved = await service.addContact(
          const TrustedContactItem(
            id: '',
            name: ' Sarah Johnson ',
            relationship: 'Spouse',
            accessLevel: 'Full Access',
            avatarUrl: '',
          ),
        );

        final body =
            supabase.single('POST', '/rest/v1/trusted_contacts').json as Map;
        expect(body, {
          'name': 'Sarah Johnson',
          'relationship': 'Spouse',
          'access_level': 'Full Access',
          'avatar_url': null,
        });
        expect(saved.id, 'server-id');
      },
    );

    test('remove deletes by id', () async {
      supabase.route = (_) => jsonResponse([]);

      await service.removeContact('tc-1');

      expect(
        supabase.single('DELETE', '/rest/v1/trusted_contacts').query['id'],
        'eq.tc-1',
      );
    });

    test('update sends the fields and returns the updated row', () async {
      supabase.route = (_) => jsonResponse([
            contactRow(id: 'tc-1')
              ..['name'] = 'Sarah Updated'
              ..['relationship'] = 'Sister',
          ]);

      final updated = await service.updateContact(
        const TrustedContactItem(
          id: 'tc-1',
          name: 'Sarah Updated',
          relationship: 'Sister',
          accessLevel: 'Full Access',
          avatarUrl: '',
        ),
      );

      final req = supabase.single('PATCH', '/rest/v1/trusted_contacts');
      expect(req.query['id'], 'eq.tc-1');
      expect(req.json, {
        'name': 'Sarah Updated',
        'relationship': 'Sister',
        'access_level': 'Full Access',
        'avatar_url': null,
      });
      expect(updated.name, 'Sarah Updated');
      expect(updated.relationship, 'Sister');
    });

    test('update throws if no row matched', () async {
      supabase.route = (_) => jsonResponse([]);

      final error = await failureOf(
        () => service.updateContact(
          const TrustedContactItem(
            id: 'tc-missing',
            name: 'Ghost',
            relationship: 'None',
            accessLevel: 'View Only',
            avatarUrl: '',
          ),
        ),
      );

      expect(error.toString(), contains('couldn\'t be found'));
    });

    test('an offline failure is reported as such', () async {
      supabase.route = (_) => throw http.ClientException('offline');

      final error = await failureOf(() => service.fetchContacts());

      expect(error.toString(), contains('Can\'t reach the server'));
    });
  });

  group('SettingsService', () {
    late SettingsServiceImpl service;

    setUp(() async {
      await supabase.signIn();
      service = SettingsServiceImpl(client: supabase.client);
    });

    test('fetch reads only the signed-in user\'s row', () async {
      supabase.route = (_) => jsonResponse([
        {
          'user_id': testUserId,
          'two_factor_enabled': true,
          'biometric_enabled': false,
          'login_alerts_enabled': true,
        },
      ]);

      final settings = await service.fetchSecuritySettings();

      expect(
        supabase.single('GET', '/rest/v1/security_settings').query['user_id'],
        'eq.$testUserId',
      );
      expect(settings.twoFactorEnabled, isTrue);
      expect(settings.biometricEnabled, isFalse);
      expect(settings.loginAlertsEnabled, isTrue);
    });

    test('no row yet means everything is off', () async {
      supabase.route = (_) => jsonResponse([]);

      final settings = await service.fetchSecuritySettings();

      expect(settings.enabledCount, 0);
    });

    test('update upserts the user\'s single row', () async {
      supabase.route = (_) => http.Response('', 201);

      await service.updateSecuritySettings(
        const SecuritySettings(
          twoFactorEnabled: true,
          loginAlertsEnabled: true,
        ),
      );

      final request = supabase.single('POST', '/rest/v1/security_settings');
      expect(request.query['on_conflict'], 'user_id');
      expect(
        request.headers['Prefer'],
        contains('resolution=merge-duplicates'),
      );
      expect(request.json, {
        'user_id': testUserId,
        'two_factor_enabled': true,
        'biometric_enabled': false,
        'login_alerts_enabled': true,
      });
    });

    test('a failed save is a failure', () async {
      supabase.route = (_) => rlsViolation();

      final error = await failureOf(
        () => service.updateSecuritySettings(const SecuritySettings()),
      );

      expect(error, isA<BackendException>());
    });
  });

  group('VaultService', () {
    test('builds the summary from the user\'s real data', () async {
      await supabase.signIn();
      supabase.route = (request) {
        switch (request.path.split('/').last) {
          case 'documents':
            return jsonResponse([
              {'file_size': 1048576},
              {'file_size': null},
              {'file_size': 2097152},
            ]);
          case 'accounts':
            return jsonResponse([
              {'category': 'Banking'},
              {'category': 'Work'},
            ]);
          case 'trusted_contacts':
            return jsonResponse([
              {'id': 'c'},
            ]);
          default:
            return jsonResponse([
              {
                'user_id': testUserId,
                'two_factor_enabled': true,
                'biometric_enabled': true,
                'login_alerts_enabled': false,
              },
            ]);
        }
      };

      final summary = await VaultServiceImpl(
        client: supabase.client,
      ).fetchVaultSummary();

      expect(summary.documentsCount, 3);
      expect(
        summary.financialsCount,
        1,
      ); // Banking accounts are the "Financials"
      expect(summary.passwordsCount, 1); // the rest are "Passwords"
      expect(summary.totalItems, 5);
      expect(summary.trustedContactsCount, 1);
      expect(summary.storageUsedMb, closeTo(3.0, 0.001));
      // Confirmed email + a trusted person + a protection switched on.
      expect(summary.securityScore, 100);
      expect(summary.securityScoreLabel, 'Excellent — 100/100');
      expect(summary.legacyProgress, 1.0); // document, account, contact, email
      // Features that don't exist yet report zero rather than invented numbers.
      expect(summary.memoriesCount, 0);
      expect(summary.messagesCount, 0);
    });

    test(
      'a brand-new account with an unconfirmed email is honestly weak',
      () async {
        supabase.authRoute = (_) => sessionResponse(emailConfirmed: false);
        await supabase.signIn();
        supabase.route = (_) => jsonResponse([]);

        final summary = await VaultServiceImpl(
          client: supabase.client,
        ).fetchVaultSummary();

        expect(summary.totalItems, 0);
        expect(summary.emailVerified, isFalse);
        expect(summary.securityScore, 0);
        expect(summary.securityScoreLabel, 'Weak — 0/100');
        expect(summary.legacyProgress, 0.0);
      },
    );
  });

  group('UserService', () {
    late UserServiceImpl service;

    setUp(() async {
      await supabase.signIn(email: 'alex@example.com', name: 'Alex Rivera');
      service = UserServiceImpl(client: supabase.client);
    });

    test('fetch combines the profile row with the Auth identity', () async {
      supabase.route = (_) => jsonResponse([
        {
          'id': testUserId,
          'full_name': 'Alexandra Rivera',
          'phone': '555-0100',
          'avatar_url': null,
        },
      ]);

      final user = await service.fetchUserProfile();

      expect(
        supabase.single('GET', '/rest/v1/profiles').query['id'],
        'eq.$testUserId',
      );
      expect(
        user.name,
        'Alexandra Rivera',
      ); // profile wins over sign-up metadata
      expect(user.phone, '555-0100');
      expect(user.email, 'alex@example.com'); // identity comes from Auth
      expect(user.id, testUserId);
    });

    test(
      'a missing profile row is created rather than leaving the account without one',
      () async {
        supabase.route = (request) => request.method == 'GET'
            ? jsonResponse([])
            : jsonResponse({
                'id': testUserId,
                'full_name': 'Alex Rivera',
                'phone': null,
                'avatar_url': null,
              });

        final user = await service.fetchUserProfile();

        final create = supabase.single('POST', '/rest/v1/profiles');
        expect(create.json, {'id': testUserId, 'full_name': 'Alex Rivera'});
        expect(user.name, 'Alex Rivera');
      },
    );

    test('update writes the editable fields and never the email', () async {
      supabase.route = (_) => jsonResponse({
        'id': testUserId,
        'full_name': 'Jane Doe',
        'phone': null,
        'avatar_url': null,
      });

      final saved = await service.updateUserProfile(
        const User(
          id: testUserId,
          name: ' Jane Doe ',
          email: 'someone@else.com',
          phone: '  ',
        ),
      );

      final request = supabase.single('PATCH', '/rest/v1/profiles');
      expect(request.query['id'], 'eq.$testUserId');
      expect(request.json, {
        'full_name': 'Jane Doe',
        'phone': null,
        'avatar_url': null,
      });
      expect(saved.name, 'Jane Doe');
      expect(saved.email, 'alex@example.com'); // still the Auth email
    });
  });

  group('without a session', () {
    test('services refuse to run and make no request', () async {
      final signedOut = FakeSupabase(); // never signed in
      signedOut.route = (_) => jsonResponse([]);

      final error = await failureOf(
        () => SettingsServiceImpl(
          client: signedOut.client,
        ).fetchSecuritySettings(),
      );

      expect(
        error.toString(),
        'Your session has expired. Please sign in again.',
      );
      expect(signedOut.requests, isEmpty);
    });
  });
}
