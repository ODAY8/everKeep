import 'dart:typed_data';

import 'package:everkeep/models/document_upload.dart';
import 'package:everkeep/models/memory_item.dart';
import 'package:everkeep/providers/memory_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// MemoryProvider: loading/empty/error state, the memory/wish split, and
/// every CRUD + attachment operation, including failure paths.
void main() {
  late FakeMemoryRepository repo;
  late MemoryProvider provider;

  final photo = DocumentUpload(
    fileName: 'photo.jpg',
    bytes: Uint8List.fromList([1, 2, 3]),
    mimeType: 'image/jpeg',
  );

  setUp(() {
    repo = FakeMemoryRepository();
    provider = MemoryProvider(memoryRepository: repo);
  });

  test('starts empty, not with invented content', () {
    expect(provider.items, isEmpty);
    expect(provider.hasFetched, isFalse);
    expect(provider.isLoading, isFalse);
    expect(provider.error, isNull);
  });

  group('fetchMemories', () {
    test('loads the list and splits it into memories and wishes', () async {
      await provider.fetchMemories();

      expect(provider.hasFetched, isTrue);
      expect(provider.count, 2);
      expect(provider.memoriesCount, 1);
      expect(provider.wishesCount, 1);
      expect(provider.memories.single.title, 'Summer at the lake');
      expect(provider.wishes.single.title, 'For my daughter');
    });

    test('a failed first load can be retried', () async {
      repo.failWith = 'No connection';
      await provider.fetchMemories();

      expect(provider.hasFetched, isFalse);
      expect(provider.error, 'No connection');

      repo.failWith = null;
      await provider.fetchMemories();

      expect(provider.hasFetched, isTrue);
      expect(provider.error, isNull);
      expect(provider.count, 2);
    });
  });

  group('filterByType', () {
    test('matches the type and, when given, the title or content', () async {
      await provider.fetchMemories();

      expect(provider.filterByType('memory'), hasLength(1));
      expect(provider.filterByType('wish'), hasLength(1));
      expect(provider.filterByType('memory', query: 'lake'), hasLength(1));
      expect(provider.filterByType('memory', query: 'zzz'), isEmpty);
      expect(provider.filterByType('wish', query: 'lake'), isEmpty);
    });
  });

  group('createMemory', () {
    test('adds the saved item to the top of the list', () async {
      await provider.fetchMemories();

      final ok = await provider.createMemory(
        const MemoryItem(id: '', title: 'A quiet morning', content: '', type: 'memory'),
      );

      expect(ok, isTrue);
      expect(provider.count, 3);
      expect(provider.items.first.title, 'A quiet morning');
    });

    test('passes the upload through to the repository', () async {
      await provider.createMemory(
        const MemoryItem(id: '', title: 'A photo', content: '', type: 'memory'),
        upload: photo,
      );

      expect(repo.lastUpload?.fileName, 'photo.jpg');
      expect(provider.items.first.hasAttachment, isTrue);
    });

    test('a failed create keeps the list and reports why', () async {
      await provider.fetchMemories();
      repo.failWith = 'Storage is full';

      final ok = await provider.createMemory(
        const MemoryItem(id: '', title: 'x', content: '', type: 'memory'),
      );

      expect(ok, isFalse);
      expect(provider.count, 2);
      expect(provider.error, 'Storage is full');
      expect(provider.isLoading, isFalse);
    });
  });

  group('updateMemory', () {
    test('replaces the item in place', () async {
      await provider.fetchMemories();
      final original = provider.memories.single;

      final ok = await provider.updateMemory(original.copyWith(title: 'Summer at the cabin'));

      expect(ok, isTrue);
      expect(provider.count, 2); // not duplicated
      expect(
        provider.items.firstWhere((m) => m.id == original.id).title,
        'Summer at the cabin',
      );
    });

    test('a failed update keeps the original', () async {
      await provider.fetchMemories();
      final original = provider.memories.single;
      repo.failWith = 'Offline';

      final ok = await provider.updateMemory(original.copyWith(title: 'Changed'));

      expect(ok, isFalse);
      expect(provider.error, 'Offline');
      expect(
        provider.items.firstWhere((m) => m.id == original.id).title,
        original.title,
      );
    });
  });

  group('deleteMemory', () {
    test('removes the item from the list', () async {
      await provider.fetchMemories();
      final id = provider.memories.single.id;

      final ok = await provider.deleteMemory(id);

      expect(ok, isTrue);
      expect(provider.count, 1);
      expect(provider.items.any((m) => m.id == id), isFalse);
    });

    test('a failed delete keeps the item and reports why', () async {
      await provider.fetchMemories();
      repo.failWith = 'Locked by another device';

      final ok = await provider.deleteMemory(provider.memories.single.id);

      expect(ok, isFalse);
      expect(provider.count, 2);
      expect(provider.error, 'Locked by another device');
    });
  });

  group('attachments', () {
    test('uploadAttachment replaces the item in the list', () async {
      await provider.fetchMemories();
      final id = provider.memories.single.id;

      final ok = await provider.uploadAttachment(id, photo);

      expect(ok, isTrue);
      expect(provider.items.firstWhere((m) => m.id == id).hasAttachment, isTrue);
      expect(repo.lastUpload?.fileName, 'photo.jpg');
    });

    test('a failed upload leaves the item without a file', () async {
      await provider.fetchMemories();
      final id = provider.memories.single.id;
      repo.failWith = 'Too large';

      final ok = await provider.uploadAttachment(id, photo);

      expect(ok, isFalse);
      expect(provider.error, 'Too large');
      expect(provider.items.firstWhere((m) => m.id == id).hasAttachment, isFalse);
    });

    test('removeAttachment clears it but keeps the item', () async {
      await provider.fetchMemories();
      final id = provider.memories.single.id;
      await provider.uploadAttachment(id, photo);

      final ok = await provider.removeAttachment(id);

      expect(ok, isTrue);
      expect(provider.count, 2); // the memory itself is still there
      expect(provider.items.firstWhere((m) => m.id == id).hasAttachment, isFalse);
    });

    test('a failed removal keeps the attachment and reports why', () async {
      await provider.fetchMemories();
      final id = provider.memories.single.id;
      await provider.uploadAttachment(id, photo);
      repo.failWith = 'Could not reach the server';

      final ok = await provider.removeAttachment(id);

      expect(ok, isFalse);
      expect(provider.error, 'Could not reach the server');
      expect(provider.items.firstWhere((m) => m.id == id).hasAttachment, isTrue);
    });
  });

  group('downloadUrlFor', () {
    test('returns a link for an item with a file', () async {
      await provider.fetchMemories();
      final id = provider.memories.single.id;
      await provider.uploadAttachment(id, photo);
      final item = provider.items.firstWhere((m) => m.id == id);

      final url = await provider.downloadUrlFor(item);

      expect(url, isNotNull);
      expect(url, startsWith('https://'));
    });

    test('an item with no file has nothing to link to', () async {
      await provider.fetchMemories();
      final url = await provider.downloadUrlFor(provider.wishes.single);
      expect(url, isNull);
      expect(provider.error, isNull); // not an error — there's just no file
    });
  });

  test('reset drops everything held for the previous user', () async {
    await provider.fetchMemories();
    expect(provider.count, 2);

    provider.reset();

    expect(provider.items, isEmpty);
    expect(provider.hasFetched, isFalse);
    expect(provider.isLoading, isFalse);
    expect(provider.error, isNull);
  });
}
