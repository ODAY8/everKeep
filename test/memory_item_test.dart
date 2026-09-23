import 'package:everkeep/models/memory_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [MemoryItem]'s own logic: row parsing, what a client is allowed to send,
/// and the small getters the UI relies on — independent of any backend.
void main() {
  group('MemoryItem.fromRow', () {
    test('parses a memory row', () {
      final item = MemoryItem.fromRow({
        'id': 'm1',
        'title': 'Summer at the lake',
        'content': 'We spent the whole week there.',
        'type': 'memory',
        'date': '2020-07-04',
        'file_path': 'user-1/memories/a.jpg',
        'file_size': 2048,
        'mime_type': 'image/jpeg',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-02T00:00:00Z',
      });

      expect(item.id, 'm1');
      expect(item.title, 'Summer at the lake');
      expect(item.content, 'We spent the whole week there.');
      expect(item.type, 'memory');
      expect(item.isMemory, isTrue);
      expect(item.isWish, isFalse);
      expect(item.date, DateTime.parse('2020-07-04'));
      expect(item.filePath, 'user-1/memories/a.jpg');
      expect(item.fileSize, 2048);
      expect(item.mimeType, 'image/jpeg');
      expect(item.hasAttachment, isTrue);
      expect(item.createdAt, isNotNull);
      expect(item.updatedAt, isNotNull);
    });

    test('parses a wish row with no optional fields', () {
      final item = MemoryItem.fromRow({
        'id': 'w1',
        'title': 'For my daughter',
        'content': '',
        'type': 'wish',
        'date': null,
        'file_path': null,
        'file_size': null,
        'mime_type': null,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });

      expect(item.isWish, isTrue);
      expect(item.isMemory, isFalse);
      expect(item.date, isNull);
      expect(item.hasAttachment, isFalse);
      expect(item.filePath, isNull);
    });

    test('is lenient about a row missing type/title/content', () {
      final item = MemoryItem.fromRow({
        'id': 'x',
        'title': null,
        'content': null,
        'created_at': null,
        'updated_at': null,
      });

      expect(item.type, 'memory'); // the same default the column itself has
      expect(item.title, '');
      expect(item.content, '');
      expect(item.createdAt, isNull);
    });

    test('type comparison ignores case, matching the fromRow value as-is', () {
      final item = MemoryItem.fromRow({
        'id': 'x',
        'title': 't',
        'content': '',
        'type': 'WISH',
        'created_at': null,
        'updated_at': null,
      });
      expect(item.isWish, isTrue);
      expect(item.typeLabel, 'Wish');
    });
  });

  group('subtitle', () {
    test('names the type and, once saved, how long ago', () {
      final item = MemoryItem(
        id: 'm1',
        title: 't',
        content: '',
        type: 'memory',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(item.subtitle, 'Memory · Added 2 days ago');
    });

    test('a wish not yet saved has no "Added ..." yet', () {
      const item = MemoryItem(id: '', title: 't', content: '', type: 'wish');
      expect(item.subtitle, 'Wish');
    });
  });

  group('icon', () {
    test('an attachment always shows the paperclip, whatever the type', () {
      const memory = MemoryItem(
        id: 'm',
        title: 't',
        content: '',
        type: 'memory',
        filePath: 'u/memories/a.jpg',
      );
      const wish = MemoryItem(
        id: 'w',
        title: 't',
        content: '',
        type: 'wish',
        filePath: 'u/memories/a.jpg',
      );
      expect(memory.icon, Icons.attach_file_rounded);
      expect(wish.icon, Icons.attach_file_rounded);
    });

    test('without one, memory and wish get their own icon', () {
      const memory = MemoryItem(id: 'm', title: 't', content: '', type: 'memory');
      const wish = MemoryItem(id: 'w', title: 't', content: '', type: 'wish');
      expect(memory.icon, Icons.favorite_rounded);
      expect(wish.icon, Icons.auto_awesome_rounded);
    });
  });

  group('toInsertRow', () {
    test('trims text and lowercases the type; leaves out what is unset', () {
      const item = MemoryItem(
        id: '',
        title: '  A quiet morning  ',
        content: '  Nothing much happened.  ',
        type: 'MEMORY',
      );
      final row = item.toInsertRow();

      expect(row['title'], 'A quiet morning');
      expect(row['content'], 'Nothing much happened.');
      expect(row['type'], 'memory');
      expect(row.containsKey('date'), isFalse);
      expect(row.containsKey('file_path'), isFalse);
      expect(row.containsKey('id'), isFalse);
      expect(row.containsKey('user_id'), isFalse, reason: 'the server fills this in');
    });

    test('includes the date and file columns only when they are set', () {
      final item = MemoryItem(
        id: '',
        title: 't',
        content: '',
        type: 'wish',
        date: DateTime(2026, 3, 7),
        filePath: 'u/memories/a.jpg',
        fileSize: 10,
        mimeType: 'image/jpeg',
      );
      final row = item.toInsertRow();

      expect(row['date'], '2026-03-07');
      expect(row['file_path'], 'u/memories/a.jpg');
      expect(row['file_size'], 10);
      expect(row['mime_type'], 'image/jpeg');
    });
  });

  group('toUpdateRow', () {
    test('carries the file columns forward so editing text never clears an attachment', () {
      final item = MemoryItem(
        id: 'm1',
        title: 'New title',
        content: 'New content',
        type: 'memory',
        filePath: 'u/memories/a.jpg',
        fileSize: 10,
        mimeType: 'image/jpeg',
      );
      final row = item.toUpdateRow();

      expect(row['title'], 'New title');
      expect(row['file_path'], 'u/memories/a.jpg');
      expect(row['file_size'], 10);
      expect(row['mime_type'], 'image/jpeg');
    });

    test('a cleared date is sent as null, not left out', () {
      const item = MemoryItem(id: 'm1', title: 't', content: '', type: 'memory');
      expect(item.toUpdateRow()['date'], isNull);
      expect(item.toUpdateRow().containsKey('date'), isTrue);
    });
  });

  group('copyWith', () {
    test('changes only what is given', () {
      const original = MemoryItem(
        id: 'm1',
        title: 'Original',
        content: 'Content',
        type: 'memory',
        filePath: 'u/memories/a.jpg',
      );
      final edited = original.copyWith(title: 'Edited');

      expect(edited.title, 'Edited');
      expect(edited.content, 'Content');
      expect(edited.filePath, 'u/memories/a.jpg');
      expect(edited.id, 'm1');
    });
  });
}
