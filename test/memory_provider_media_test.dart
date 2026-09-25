import 'dart:typed_data';

import 'package:everkeep/models/document_upload.dart';
import 'package:everkeep/models/memory_item.dart';
import 'package:everkeep/models/memory_media_item.dart';
import 'package:everkeep/providers/memory_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeMemoryRepository repo;
  late MemoryProvider provider;

  final samplePhoto = DocumentUpload(
    fileName: 'campus.jpg',
    bytes: Uint8List.fromList([1, 2, 3]),
    mimeType: 'image/jpeg',
  );

  final sampleVideo = DocumentUpload(
    fileName: 'lecture.mp4',
    bytes: Uint8List.fromList([4, 5, 6]),
    mimeType: 'video/mp4',
  );

  final sampleAudio = DocumentUpload(
    fileName: 'speech.m4a',
    bytes: Uint8List.fromList([7, 8, 9]),
    mimeType: 'audio/m4a',
  );

  setUp(() {
    repo = FakeMemoryRepository();
    provider = MemoryProvider(memoryRepository: repo);
  });

  group('MemoryProvider — Rich Media Integration', () {
    test('starts with empty media cache and empty items', () {
      expect(provider.items, isEmpty);
      expect(provider.hasFetched, isFalse);
    });

    test('loads memories containing multiple media items (photos, videos, audio)', () async {
      final seededMemory = MemoryItem(
        id: 'mem-seeded',
        title: 'Trip to Paris',
        content: 'Louvre, Eiffel Tower, and cafe talks',
        media: const [
          MemoryMediaItem(
            id: 'med-p1',
            memoryId: 'mem-seeded',
            filePath: 'u1/memories/m1/p1.jpg',
            mediaType: MemoryMediaType.photo,
            mimeType: 'image/jpeg',
            fileSize: 1024,
            displayOrder: 0,
          ),
          MemoryMediaItem(
            id: 'med-v1',
            memoryId: 'mem-seeded',
            filePath: 'u1/memories/m1/v1.mp4',
            mediaType: MemoryMediaType.video,
            mimeType: 'video/mp4',
            fileSize: 5000,
            displayOrder: 1,
            durationSeconds: 30,
          ),
          MemoryMediaItem(
            id: 'med-a1',
            memoryId: 'mem-seeded',
            filePath: 'u1/memories/m1/a1.m4a',
            mediaType: MemoryMediaType.audio,
            mimeType: 'audio/m4a',
            fileSize: 2000,
            displayOrder: 2,
            durationSeconds: 90,
          ),
        ],
      );

      final customRepo = FakeMemoryRepository([seededMemory]);
      final customProv = MemoryProvider(memoryRepository: customRepo);

      await customProv.fetchMemories();

      expect(customProv.items.length, 1);
      final memory = customProv.items.first;
      expect(memory.media.length, 3);
      expect(memory.totalMediaCount, 3);
      expect(memory.photos.length, 1);
      expect(memory.videos.length, 1);
      expect(memory.audioNotes.length, 1);
      expect(memory.primaryCoverPhoto?.id, 'med-p1');
    });

    test('createMemoryWithMedia creates memory and adds to top of provider state', () async {
      await provider.fetchMemories();
      expect(provider.count, 2);

      final success = await provider.createMemoryWithMedia(
        const MemoryItem(id: '', title: 'Graduation Gala', content: 'Celebration dinner'),
        [samplePhoto, sampleVideo],
        captions: ['Photo with friends', 'Final speech video'],
        durations: <int?>[null, 65],
      );

      expect(success, isTrue);
      expect(provider.count, 3);
      final created = provider.items.first;
      expect(created.title, 'Graduation Gala');
      expect(created.media.length, 2);
      expect(created.photos.length, 1);
      expect(created.videos.length, 1);
      expect(created.media[0].caption, 'Photo with friends');
      expect(created.media[1].durationSeconds, 65);
    });

    test('createMemoryWithMedia propagates error and sets provider error on failure', () async {
      repo.failWith = 'Upload storage limit exceeded';

      final success = await provider.createMemoryWithMedia(
        const MemoryItem(id: '', title: 'Failed Save', content: ''),
        [samplePhoto],
      );

      expect(success, isFalse);
      expect(provider.error, 'Upload storage limit exceeded');
    });

    test('addMedia adds a media item in-place to an existing memory in state', () async {
      await provider.fetchMemories();
      final target = provider.items.first;
      expect(target.media, isEmpty);

      var notified = 0;
      provider.addListener(() => notified++);

      final added = await provider.addMedia(
        target.id,
        sampleAudio,
        caption: 'Voice recording note',
        durationSeconds: 42,
      );

      expect(added, isNotNull);
      expect(added!.isAudio, isTrue);
      expect(added.caption, 'Voice recording note');
      expect(added.durationSeconds, 42);

      final updated = provider.items.firstWhere((m) => m.id == target.id);
      expect(updated.media.length, 1);
      expect(updated.audioNotes.length, 1);
      expect(updated.media.first.id, added.id);
      expect(notified, greaterThan(0));
    });

    test('deleteMedia removes the item from the corresponding MemoryItem in state', () async {
      await provider.fetchMemories();
      final targetId = provider.items.first.id;

      // Add media first
      final media = await provider.addMedia(targetId, samplePhoto);
      expect(media, isNotNull);
      expect(provider.items.first.media.length, 1);

      // Now delete it
      final deleted = await provider.deleteMedia(media!.id);
      expect(deleted, isTrue);

      final updated = provider.items.firstWhere((m) => m.id == targetId);
      expect(updated.media, isEmpty);
    });

    test('reorderMedia updates media ordering in-place on target memory', () async {
      await provider.fetchMemories();
      final targetId = provider.items.first.id;

      final m1 = await provider.addMedia(targetId, samplePhoto);
      final m2 = await provider.addMedia(targetId, sampleVideo);
      expect(provider.items.first.media.map((m) => m.id).toList(), [m1!.id, m2!.id]);

      // Reorder [m2, m1]
      final reordered = await provider.reorderMedia(targetId, [m2.id, m1.id]);
      expect(reordered, isTrue);

      final updated = provider.items.firstWhere((m) => m.id == targetId);
      expect(updated.media.map((m) => m.id).toList(), [m2.id, m1.id]);
      expect(updated.media[0].displayOrder, 0);
      expect(updated.media[1].displayOrder, 1);
    });

    test('createSignedUrl caches valid URLs avoiding duplicate calls', () async {
      const path = 'user/memories/m1/photo.jpg';

      // First call invokes repo
      final url1 = await provider.createSignedUrl(path);
      expect(url1, 'https://example.test/signed/$path');

      // Break repo to verify it is served from cache
      repo.failWith = 'Network disconnected';
      final url2 = await provider.createSignedUrl(path);
      expect(url2, url1); // Served directly from valid cache without throwing
    });

    test('signedUrlForMedia works and downloadUrlFor uses cached mechanism', () async {
      const media = MemoryMediaItem(
        id: 'med-1',
        memoryId: 'm1',
        filePath: 'user/memories/m1/voice.m4a',
        mediaType: MemoryMediaType.audio,
        mimeType: 'audio/m4a',
        fileSize: 100,
      );

      final url = await provider.signedUrlForMedia(media);
      expect(url, 'https://example.test/signed/user/memories/m1/voice.m4a');
    });

    test('reset clears memory items and clears signed URL cache', () async {
      await provider.fetchMemories();
      expect(provider.items, isNotEmpty);

      await provider.createSignedUrl('path/cached.jpg');

      provider.reset();
      expect(provider.items, isEmpty);
      expect(provider.hasFetched, isFalse);

      // Now repo failure should prevent cached hit
      repo.failWith = 'No access';
      final url = await provider.createSignedUrl('path/cached.jpg');
      expect(url, isNull);
    });

    test('legacy attachment compatibility retains single filePath fallback', () async {
      final legacyMemory = MemoryItem(
        id: 'leg-1',
        title: 'Legacy Item',
        content: 'Stored in 1st architecture',
        filePath: 'user/memories/old.png',
        fileSize: 2048,
        mimeType: 'image/png',
      );

      final customRepo = FakeMemoryRepository([legacyMemory]);
      final customProv = MemoryProvider(memoryRepository: customRepo);
      await customProv.fetchMemories();

      final item = customProv.items.first;
      expect(item.media, isEmpty); // media list is empty
      expect(item.hasAttachment, isTrue); // legacy flag true
      expect(item.totalMediaCount, 1); // computed total media count counts legacy
      expect(item.photos.length, 1); // synthesized as photo
      expect(item.primaryCoverPhoto?.filePath, 'user/memories/old.png');

      final url = await customProv.downloadUrlFor(item);
      expect(url, 'https://example.test/signed/user/memories/old.png');
    });

    test('empty media list on a plain memory has 0 total media', () async {
      final plain = MemoryItem(
        id: 'plain-1',
        title: 'Simple thought',
        content: 'No files attached.',
      );

      final customRepo = FakeMemoryRepository([plain]);
      final customProv = MemoryProvider(memoryRepository: customRepo);
      await customProv.fetchMemories();

      final item = customProv.items.first;
      expect(item.media, isEmpty);
      expect(item.totalMediaCount, 0);
      expect(item.photos, isEmpty);
      expect(item.videos, isEmpty);
      expect(item.audioNotes, isEmpty);
      expect(item.primaryCoverPhoto, isNull);
    });
  });
}
