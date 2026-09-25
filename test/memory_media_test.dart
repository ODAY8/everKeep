import 'package:flutter_test/flutter_test.dart';
import 'package:everkeep/models/memory_item.dart';
import 'package:everkeep/models/memory_media_item.dart';

void main() {
  group('MemoryMediaType', () {
    test('parses from direct string names', () {
      expect(MemoryMediaType.fromString('photo'), MemoryMediaType.photo);
      expect(MemoryMediaType.fromString('image'), MemoryMediaType.photo);
      expect(MemoryMediaType.fromString('video'), MemoryMediaType.video);
      expect(MemoryMediaType.fromString('audio'), MemoryMediaType.audio);
      expect(MemoryMediaType.fromString('PHOTO'), MemoryMediaType.photo);
      expect(MemoryMediaType.fromString('  video  '), MemoryMediaType.video);
    });

    test('deduces media type from mime-type when string is unspecific', () {
      expect(
        MemoryMediaType.fromString(null, mimeType: 'image/jpeg'),
        MemoryMediaType.photo,
      );
      expect(
        MemoryMediaType.fromString('', mimeType: 'video/mp4'),
        MemoryMediaType.video,
      );
      expect(
        MemoryMediaType.fromString('unknown', mimeType: 'audio/m4a'),
        MemoryMediaType.audio,
      );
      expect(
        MemoryMediaType.fromString(null, mimeType: 'application/pdf'),
        MemoryMediaType.photo, // default fallback
      );
    });

    test('dbValue matches enum name', () {
      expect(MemoryMediaType.photo.dbValue, 'photo');
      expect(MemoryMediaType.video.dbValue, 'video');
      expect(MemoryMediaType.audio.dbValue, 'audio');
    });
  });

  group('MemoryMediaItem', () {
    test('JSON parsing from Supabase row', () {
      final row = {
        'id': 'med-101',
        'memory_id': 'mem-001',
        'user_id': 'user-123',
        'file_path': 'user-123/memories/photo1.jpg',
        'media_type': 'photo',
        'mime_type': 'image/jpeg',
        'file_size': 2097152, // 2 MB
        'display_order': 1,
        'caption': 'Sunset over the bay',
        'duration_seconds': null,
        'thumbnail_path': null,
        'created_at': '2025-06-15T18:30:00Z',
      };

      final item = MemoryMediaItem.fromRow(row);

      expect(item.id, 'med-101');
      expect(item.memoryId, 'mem-001');
      expect(item.userId, 'user-123');
      expect(item.filePath, 'user-123/memories/photo1.jpg');
      expect(item.mediaType, MemoryMediaType.photo);
      expect(item.isPhoto, isTrue);
      expect(item.isVideo, isFalse);
      expect(item.isAudio, isFalse);
      expect(item.mimeType, 'image/jpeg');
      expect(item.fileSize, 2097152);
      expect(item.displayOrder, 1);
      expect(item.caption, 'Sunset over the bay');
      expect(item.durationSeconds, isNull);
      expect(item.createdAt, isNotNull);
    });

    test('JSON serialization to insert row', () {
      const item = MemoryMediaItem(
        id: 'med-new',
        memoryId: 'mem-99',
        userId: 'user-45',
        filePath: 'user-45/memories/clip.mp4',
        mediaType: MemoryMediaType.video,
        mimeType: 'video/mp4',
        fileSize: 10485760, // 10 MB
        displayOrder: 2,
        caption: '  First concert performance  ',
        durationSeconds: 125,
        thumbnailPath: 'user-45/memories/thumb.jpg',
      );

      final row = item.toInsertRow();

      expect(row['memory_id'], 'mem-99');
      expect(row['user_id'], 'user-45');
      expect(row['file_path'], 'user-45/memories/clip.mp4');
      expect(row['media_type'], 'video');
      expect(row['mime_type'], 'video/mp4');
      expect(row['file_size'], 10485760);
      expect(row['display_order'], 2);
      expect(row['caption'], 'First concert performance');
      expect(row['duration_seconds'], 125);
      expect(row['thumbnail_path'], 'user-45/memories/thumb.jpg');
    });

    test('JSON serialization to update row', () {
      const item = MemoryMediaItem(
        id: 'med-edit',
        memoryId: 'mem-99',
        filePath: 'path.mp3',
        mediaType: MemoryMediaType.audio,
        mimeType: 'audio/mp3',
        fileSize: 5000,
        displayOrder: 4,
        caption: 'New caption',
        durationSeconds: 45,
      );

      final updateRow = item.toUpdateRow();

      expect(updateRow['display_order'], 4);
      expect(updateRow['caption'], 'New caption');
      expect(updateRow['duration_seconds'], 45);
    });

    test('formattedFileSize handles bytes, KB, and MB', () {
      const zero = MemoryMediaItem(
        id: '', memoryId: '', filePath: '', mediaType: MemoryMediaType.photo, mimeType: '', fileSize: 0,
      );
      expect(zero.formattedFileSize, '0 B');

      const bytes = MemoryMediaItem(
        id: '', memoryId: '', filePath: '', mediaType: MemoryMediaType.photo, mimeType: '', fileSize: 512,
      );
      expect(bytes.formattedFileSize, '512 B');

      const kb = MemoryMediaItem(
        id: '', memoryId: '', filePath: '', mediaType: MemoryMediaType.photo, mimeType: '', fileSize: 1536, // 1.5 KB
      );
      expect(kb.formattedFileSize, '1.5 KB');

      const mb = MemoryMediaItem(
        id: '', memoryId: '', filePath: '', mediaType: MemoryMediaType.photo, mimeType: '', fileSize: 5242880, // 5.0 MB
      );
      expect(mb.formattedFileSize, '5.0 MB');
    });

    test('formattedDuration formats minutes and padded seconds', () {
      const noDur = MemoryMediaItem(
        id: '', memoryId: '', filePath: '', mediaType: MemoryMediaType.audio, mimeType: '', fileSize: 0,
      );
      expect(noDur.formattedDuration, isNull);

      const sec = MemoryMediaItem(
        id: '', memoryId: '', filePath: '', mediaType: MemoryMediaType.audio, mimeType: '', fileSize: 0, durationSeconds: 7,
      );
      expect(sec.formattedDuration, '0:07');

      const minSec = MemoryMediaItem(
        id: '', memoryId: '', filePath: '', mediaType: MemoryMediaType.audio, mimeType: '', fileSize: 0, durationSeconds: 125,
      );
      expect(minSec.formattedDuration, '2:05');
    });
  });

  group('MemoryItem Rich Media & Backward Compatibility', () {
    test('legacy attachment fallback when media list is empty', () {
      final legacy = MemoryItem(
        id: 'legacy-mem-1',
        title: 'Old Graduation Photo',
        content: 'Commencement ceremony.',
        filePath: 'user-1/memories/grad.jpg',
        fileSize: 3145728,
        mimeType: 'image/jpeg',
      );

      expect(legacy.media.isEmpty, isTrue);
      expect(legacy.hasAttachment, isTrue);
      expect(legacy.allMedia.length, 1);

      final synthesized = legacy.allMedia.first;
      expect(synthesized.filePath, 'user-1/memories/grad.jpg');
      expect(synthesized.fileSize, 3145728);
      expect(synthesized.mimeType, 'image/jpeg');
      expect(synthesized.isPhoto, isTrue);
      expect(legacy.totalMediaCount, 1);
      expect(legacy.photos.length, 1);
      expect(legacy.videos.isEmpty, isTrue);
      expect(legacy.audioNotes.isEmpty, isTrue);
      expect(legacy.primaryCoverPhoto?.filePath, 'user-1/memories/grad.jpg');
    });

    test('rich multi-media memory with photos, video, and audio', () {
      const photo1 = MemoryMediaItem(
        id: 'm1',
        memoryId: 'mem-100',
        filePath: 'u1/memories/p1.jpg',
        mediaType: MemoryMediaType.photo,
        mimeType: 'image/jpeg',
        fileSize: 1000,
        displayOrder: 0,
      );
      const photo2 = MemoryMediaItem(
        id: 'm2',
        memoryId: 'mem-100',
        filePath: 'u1/memories/p2.png',
        mediaType: MemoryMediaType.photo,
        mimeType: 'image/png',
        fileSize: 2000,
        displayOrder: 1,
      );
      const video1 = MemoryMediaItem(
        id: 'm3',
        memoryId: 'mem-100',
        filePath: 'u1/memories/v1.mp4',
        mediaType: MemoryMediaType.video,
        mimeType: 'video/mp4',
        fileSize: 5000000,
        displayOrder: 2,
        durationSeconds: 45,
      );
      const audio1 = MemoryMediaItem(
        id: 'm4',
        memoryId: 'mem-100',
        filePath: 'u1/memories/a1.m4a',
        mediaType: MemoryMediaType.audio,
        mimeType: 'audio/m4a',
        fileSize: 800000,
        displayOrder: 3,
        durationSeconds: 90,
      );

      final memory = MemoryItem(
        id: 'mem-100',
        title: 'Trip to Rome',
        content: 'Visiting the Colosseum and Pantheon.',
        media: const [photo1, photo2, video1, audio1],
      );

      expect(memory.totalMediaCount, 4);
      expect(memory.photos.length, 2);
      expect(memory.videos.length, 1);
      expect(memory.audioNotes.length, 1);
      expect(memory.primaryCoverPhoto?.id, 'm1');
    });

    test('primaryCoverPhoto returns null when memory contains no photos', () {
      const audioOnly = MemoryMediaItem(
        id: 'aud-1',
        memoryId: 'mem-voice',
        filePath: 'u/voice.m4a',
        mediaType: MemoryMediaType.audio,
        mimeType: 'audio/m4a',
        fileSize: 2048,
      );

      final memory = MemoryItem(
        id: 'mem-voice',
        title: 'Thoughts on Architecture',
        content: 'Audio log.',
        media: const [audioOnly],
      );

      expect(memory.totalMediaCount, 1);
      expect(memory.audioNotes.length, 1);
      expect(memory.photos.isEmpty, isTrue);
      expect(memory.primaryCoverPhoto, isNull);
    });

    test('fromRow parses nested memory_media rows and sorts by displayOrder', () {
      final row = {
        'id': 'mem-db-1',
        'title': 'Birthday Party',
        'content': 'Cutting the cake with family',
        'type': 'memory',
        'date': '2024-05-10',
        'memory_media': [
          {
            'id': 'med-b',
            'memory_id': 'mem-db-1',
            'file_path': 'b.jpg',
            'media_type': 'photo',
            'mime_type': 'image/jpeg',
            'file_size': 1200,
            'display_order': 2,
          },
          {
            'id': 'med-a',
            'memory_id': 'mem-db-1',
            'file_path': 'a.jpg',
            'media_type': 'photo',
            'mime_type': 'image/jpeg',
            'file_size': 1100,
            'display_order': 1,
          },
        ],
      };

      final memory = MemoryItem.fromRow(row);

      expect(memory.id, 'mem-db-1');
      expect(memory.media.length, 2);
      expect(memory.media[0].id, 'med-a'); // sorted by display_order
      expect(memory.media[1].id, 'med-b');
      expect(memory.primaryCoverPhoto?.id, 'med-a');
    });
  });
}
