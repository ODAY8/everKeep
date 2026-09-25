import 'dart:typed_data';

import 'package:everkeep/core/supabase/supabase_errors.dart';
import 'package:everkeep/models/document_upload.dart';
import 'package:everkeep/models/memory_item.dart';
import 'package:everkeep/models/memory_media_item.dart';
import 'package:everkeep/repositories/memory_repository.dart';
import 'package:everkeep/services/memory_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_supabase.dart';

void main() {
  late FakeSupabase supabase;
  late MemoryServiceImpl service;
  late MemoryRepository repository;

  setUp(() async {
    supabase = FakeSupabase();
    await supabase.signIn();
    service = MemoryServiceImpl(client: supabase.client);
    repository = MemoryRepositoryImpl(memoryService: service);
  });

  Future<Object?> failureOf(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (error) {
      return error;
    }
    fail('expected the call to fail');
  }

  group('MemoryService — Rich Media Operations', () {
    // 1. Media type detection
    test('detectMediaType detects photo, video, and audio safely', () {
      expect(
        MemoryServiceImpl.detectMediaType('image/jpeg', 'photo.jpg'),
        MemoryMediaType.photo,
      );
      expect(
        MemoryServiceImpl.detectMediaType('video/mp4', 'clip.mp4'),
        MemoryMediaType.video,
      );
      expect(
        MemoryServiceImpl.detectMediaType('audio/m4a', 'voice.m4a'),
        MemoryMediaType.audio,
      );
      // Fallback by extension when mimeType is generic or null
      expect(
        MemoryServiceImpl.detectMediaType(null, 'scenery.png'),
        MemoryMediaType.photo,
      );
      expect(
        MemoryServiceImpl.detectMediaType('application/octet-stream', 'family.mov'),
        MemoryMediaType.video,
      );
      expect(
        MemoryServiceImpl.detectMediaType('application/octet-stream', 'speech.mp3'),
        MemoryMediaType.audio,
      );
    });

    // 2. Storage path generation
    test('mediaObjectPath generates approved hierarchical path structure', () {
      final path = MemoryServiceImpl.mediaObjectPath(
        'usr-1',
        'mem-99',
        MemoryMediaType.photo,
        '../unsafe / my sunset.jpg',
      );

      expect(path, startsWith('usr-1/memories/mem-99/photo_'));
      expect(path, endsWith('_my_sunset.jpg'));
      expect(path, isNot(contains('..')));
      expect(path, isNot(contains(' ')));
    });

    // 3. Add media
    test('addMedia uploads file and inserts row into memory_media', () async {
      supabase.route = (request) {
        if (request.method == 'GET' && request.path.endsWith('/memories_wishes')) {
          return jsonResponse([
            {'id': 'mem-10', 'user_id': testUserId},
          ]);
        }
        if (request.method == 'POST' && request.path.startsWith('/storage/')) {
          return jsonResponse({'Key': 'memories/object'});
        }
        if (request.method == 'POST' && request.path.endsWith('/memory_media')) {
          return jsonResponse({
            'id': 'med-1',
            'memory_id': 'mem-10',
            'user_id': testUserId,
            'file_path': '$testUserId/memories/mem-10/photo_123_gate.jpg',
            'media_type': 'photo',
            'mime_type': 'image/jpeg',
            'file_size': 2048,
            'display_order': 0,
            'caption': 'Campus entrance',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        return jsonResponse([]);
      };

      final media = await repository.addMedia(
        'mem-10',
        DocumentUpload(
          fileName: 'gate.jpg',
          bytes: Uint8List.fromList([1, 2, 3, 4]),
          mimeType: 'image/jpeg',
        ),
        caption: 'Campus entrance',
        displayOrder: 0,
      );

      expect(media.id, 'med-1');
      expect(media.memoryId, 'mem-10');
      expect(media.isPhoto, isTrue);
      expect(media.caption, 'Campus entrance');
      expect(supabase.where('POST', '/storage/v1/object/memories'), hasLength(1));
      expect(supabase.where('POST', '/rest/v1/memory_media'), hasLength(1));
    });

    // 4. Delete media
    test('deleteMedia deletes storage object and database row', () async {
      supabase.route = (request) {
        if (request.method == 'GET' && request.path.endsWith('/memory_media')) {
          return jsonResponse([
            {
              'id': 'med-5',
              'user_id': testUserId,
              'file_path': '$testUserId/memories/mem-1/photo_1.jpg',
            }
          ]);
        }
        if (request.method == 'DELETE') {
          return jsonResponse([]);
        }
        return jsonResponse([]);
      };

      await repository.deleteMedia('med-5');

      expect(supabase.where('DELETE', '/storage/v1/object/memories'), hasLength(1));
      expect(supabase.where('DELETE', '/rest/v1/memory_media'), hasLength(1));
    });

    // 5. Reorder media
    test('reorderMedia updates display_order for all supplied media items', () async {
      supabase.route = (request) {
        if (request.method == 'GET' && request.path.endsWith('/memories_wishes')) {
          return jsonResponse([
            {'id': 'mem-1', 'user_id': testUserId}
          ]);
        }
        if (request.method == 'GET' && request.path.endsWith('/memory_media')) {
          return jsonResponse([
            {'id': 'm1', 'memory_id': 'mem-1'},
            {'id': 'm2', 'memory_id': 'mem-1'},
          ]);
        }
        if (request.method == 'PATCH' && request.path.endsWith('/memory_media')) {
          return jsonResponse([]);
        }
        return jsonResponse([]);
      };

      await repository.reorderMedia('mem-1', ['m2', 'm1']);

      final patchRequests =
          supabase.where('PATCH', '/rest/v1/memory_media').toList();
      expect(patchRequests, hasLength(2));
      expect(patchRequests[0].json['display_order'], 0);
      expect(patchRequests[1].json['display_order'], 1);
    });

    // 6. Ownership validation
    test('addMedia throws if memory belongs to another user', () async {
      supabase.route = (request) {
        if (request.method == 'GET' && request.path.endsWith('/memories_wishes')) {
          return jsonResponse([
            {'id': 'mem-other', 'user_id': 'intruder-id'}
          ]);
        }
        return jsonResponse([]);
      };

      final error = await failureOf(() => repository.addMedia(
        'mem-other',
        DocumentUpload(fileName: 'f.jpg', bytes: Uint8List(2)),
      ));

      expect(error.toString(), contains('permission'));
      expect(supabase.where('POST', '/storage/v1/object/memories'), isEmpty);
    });

    test('deleteMedia throws if media belongs to another user', () async {
      supabase.route = (request) {
        if (request.method == 'GET' && request.path.endsWith('/memory_media')) {
          return jsonResponse([
            {'id': 'med-alien', 'user_id': 'other-user', 'file_path': 'other/path'}
          ]);
        }
        return jsonResponse([]);
      };

      final error = await failureOf(() => repository.deleteMedia('med-alien'));

      expect(error.toString(), contains('permission'));
      expect(supabase.where('DELETE', '/storage/v1/object/memories'), isEmpty);
    });

    // 7. Multiple media in createMemoryWithMedia
    test('createMemoryWithMedia creates parent memory and uploads all files', () async {
      supabase.route = (request) {
        if (request.method == 'POST' && request.path.endsWith('/memories_wishes')) {
          return jsonResponse({
            'id': 'mem-multi-1',
            'user_id': testUserId,
            'title': 'Trip to Kyoto',
            'content': 'Temples and gardens',
            'type': 'memory',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        if (request.method == 'POST' && request.path.startsWith('/storage/')) {
          return jsonResponse({'Key': 'ok'});
        }
        if (request.method == 'POST' && request.path.endsWith('/memory_media')) {
          final body = request.json as Map<String, dynamic>;
          return jsonResponse({
            'id': 'med-${body['display_order']}',
            'memory_id': 'mem-multi-1',
            'user_id': testUserId,
            'file_path': body['file_path'],
            'media_type': body['media_type'],
            'mime_type': body['mime_type'],
            'file_size': body['file_size'],
            'display_order': body['display_order'],
            'caption': body['caption'],
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        return jsonResponse([]);
      };

      final uploads = [
        DocumentUpload(fileName: 'photo.jpg', bytes: Uint8List(10), mimeType: 'image/jpeg'),
        DocumentUpload(fileName: 'clip.mp4', bytes: Uint8List(20), mimeType: 'video/mp4'),
      ];

      final created = await repository.createMemoryWithMedia(
        const MemoryItem(id: '', title: 'Trip to Kyoto', content: 'Temples and gardens'),
        uploads,
        captions: ['Arashiyama', 'Gion walk'],
      );

      expect(created.id, 'mem-multi-1');
      expect(created.media.length, 2);
      expect(created.photos.length, 1);
      expect(created.videos.length, 1);
      expect(supabase.where('POST', '/storage/v1/object/memories'), hasLength(2));
      expect(supabase.where('POST', '/rest/v1/memory_media'), hasLength(2));
    });

    // 8. Partial upload failure cleanup
    test('createMemoryWithMedia rolls back uploads and parent row if an upload fails', () async {
      var uploadCount = 0;
      supabase.route = (request) {
        if (request.method == 'POST' && request.path.endsWith('/memories_wishes')) {
          return jsonResponse({
            'id': 'mem-fail-1',
            'user_id': testUserId,
            'title': 'Broken save',
            'content': '',
            'type': 'memory',
          });
        }
        if (request.method == 'POST' && request.path.startsWith('/storage/')) {
          uploadCount++;
          if (uploadCount == 2) {
            return errorResponse(500, {'message': 'Network timeout on 2nd upload'});
          }
          return jsonResponse({'Key': 'ok'});
        }
        if (request.method == 'POST' && request.path.endsWith('/memory_media')) {
          return jsonResponse({
            'id': 'med-1',
            'memory_id': 'mem-fail-1',
            'file_path': 'path1',
            'media_type': 'photo',
            'mime_type': 'image/jpeg',
            'file_size': 10,
            'display_order': 0,
          });
        }
        if (request.method == 'DELETE') {
          return jsonResponse([]);
        }
        return jsonResponse([]);
      };

      final uploads = [
        DocumentUpload(fileName: 'p1.jpg', bytes: Uint8List(10), mimeType: 'image/jpeg'),
        DocumentUpload(fileName: 'p2.jpg', bytes: Uint8List(10), mimeType: 'image/jpeg'),
      ];

      final error = await failureOf(() => repository.createMemoryWithMedia(
        const MemoryItem(id: '', title: 'Broken save', content: ''),
        uploads,
      ));

      expect(error, isA<BackendException>());
      // Uploaded first file was deleted
      expect(supabase.where('DELETE', '/storage/v1/object/memories'), hasLength(1));
      // Parent memory row was deleted
      expect(supabase.where('DELETE', '/rest/v1/memories_wishes'), hasLength(1));
    });

    // 9. Signed URL handling
    test('createSignedUrl requests signed URL from private bucket', () async {
      supabase.route = (_) => jsonResponse({
            'signedURL': '/object/sign/memories/clip.mp4?token=secret123',
          });

      final url =
          await repository.createSignedUrl('$testUserId/memories/m1/clip.mp4');
      final request =
          supabase.single('POST', '/storage/v1/object/sign/memories/');
      expect((request.json as Map)['expiresIn'], 300);
      expect(url, contains('token=secret123'));
    });

    // 10. Legacy attachment compatibility
    test('legacy createMemory writes to memories_wishes directly', () async {
      supabase.route = (request) {
        if (request.method == 'POST' && request.path.startsWith('/storage/')) {
          return jsonResponse({'Key': 'ok'});
        }
        if (request.method == 'POST' && request.path.endsWith('/memories_wishes')) {
          return jsonResponse({
            'id': 'legacy-1',
            'title': 'Old Style',
            'content': '',
            'type': 'memory',
            'file_path': '$testUserId/memories/legacy.jpg',
            'file_size': 1024,
            'mime_type': 'image/jpeg',
          });
        }
        return jsonResponse([]);
      };

      final created = await repository.createMemory(
        const MemoryItem(id: '', title: 'Old Style', content: ''),
        upload: DocumentUpload(fileName: 'legacy.jpg', bytes: Uint8List(1024), mimeType: 'image/jpeg'),
      );

      expect(created.id, 'legacy-1');
      expect(created.hasAttachment, isTrue);
      expect(created.totalMediaCount, 1);
      expect(created.primaryCoverPhoto?.filePath, '$testUserId/memories/legacy.jpg');
    });

    test('fetchMemories falls back to standard select if memory_media table query fails', () async {
      var callCount = 0;
      supabase.route = (request) {
        callCount++;
        if (callCount == 1) {
          // First call attempts select('*, memory_media(*)') which fails if table does not exist
          return errorResponse(400, {
            'code': 'PGRST200',
            'message': 'Could not find a relationship between memories_wishes and memory_media',
          });
        }
        // Fallback call to select() without join succeeds
        return jsonResponse([
          {
            'id': 'mem-fallback-1',
            'title': 'Graceful Fallback',
            'content': 'Works before remote migration is applied',
            'type': 'memory',
          }
        ]);
      };

      final items = await repository.fetchMemories();
      expect(items.length, 1);
      expect(items.first.title, 'Graceful Fallback');
    });
  });
}
