import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/app_supabase.dart';
import '../core/supabase/client_extensions.dart';
import '../core/supabase/supabase_errors.dart';
import '../models/document_upload.dart';
import '../models/memory_item.dart';
import '../models/memory_media_item.dart';

abstract class MemoryService {
  Future<List<MemoryItem>> fetchMemories();
  Future<MemoryItem> fetchMemory(String id);

  /// Saves the item's metadata. If [upload] is given, its bytes are stored in
  /// private Storage first and the item points at them (legacy single-attachment).
  Future<MemoryItem> createMemory(MemoryItem item, {DocumentUpload? upload});

  /// Creates a parent memory and uploads multiple media items in a safe sequence.
  /// If any upload or DB insert fails, newly uploaded files are cleaned up and the error is rethrown.
  Future<MemoryItem> createMemoryWithMedia(
    MemoryItem item,
    List<DocumentUpload> uploads, {
    List<String>? captions,
    List<int?>? durations,
  });

  /// Adds a single media item (photo, video, or voice recording) to an existing memory.
  Future<MemoryMediaItem> addMedia(
    String memoryId,
    DocumentUpload upload, {
    String? caption,
    int? displayOrder,
    int? durationSeconds,
  });

  /// Deletes an individual media item, removing its storage object and database row.
  Future<void> deleteMedia(String mediaId);

  /// Updates display order for media items belonging to a memory.
  Future<void> reorderMedia(
    String memoryId,
    List<String> orderedMediaIds,
  );

  /// Saves edits to title, content, type or date. Does not touch existing
  /// attachments — use [uploadAttachment] / [deleteAttachment] for that.
  Future<MemoryItem> updateMemory(MemoryItem item);

  /// Deletes the item and all its stored files (both legacy and rich media).
  Future<void> deleteMemory(String id);

  /// Adds or replaces [id]'s legacy single attachment.
  Future<MemoryItem> uploadAttachment(String id, DocumentUpload upload);

  /// Removes [id]'s legacy single attachment, keeping the memory or wish itself.
  Future<MemoryItem> deleteAttachment(String id);

  /// A short-lived link to view a stored file. Attachments are private, so
  /// this is the only way to reach one outside the app.
  Future<String> createDownloadUrl(String filePath);

  /// Generates a signed URL to view or play a private media file (alias for [createDownloadUrl]).
  Future<String> createSignedUrl(String filePath);
}

/// [MemoryService] backed by the `memories_wishes` table, `memory_media` table,
/// and the private `memories` Storage bucket.
class MemoryServiceImpl implements MemoryService {
  static const String _bucket = 'memories';
  static const int _downloadUrlSeconds = 300;

  final SupabaseClient _client;

  MemoryServiceImpl({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  @override
  Future<List<MemoryItem>> fetchMemories() {
    return guardBackend(() async {
      try {
        final rows = await _client
            .from('memories_wishes')
            .select('*, memory_media(*)')
            .order('created_at', ascending: false);
        return rows.map(MemoryItem.fromRow).toList();
      } catch (_) {
        // Fallback for when memory_media migration has not been applied remotely yet
        final rows = await _client
            .from('memories_wishes')
            .select()
            .order('created_at', ascending: false);
        return rows.map(MemoryItem.fromRow).toList();
      }
    });
  }

  @override
  Future<MemoryItem> fetchMemory(String id) {
    return guardBackend(() async {
      try {
        final rows = await _client
            .from('memories_wishes')
            .select('*, memory_media(*)')
            .eq('id', id);
        requireAffected(rows);
        return MemoryItem.fromRow(rows.first);
      } catch (_) {
        // Fallback if memory_media table doesn't exist remotely yet
        final rows =
            await _client.from('memories_wishes').select().eq('id', id);
        requireAffected(rows);
        return MemoryItem.fromRow(rows.first);
      }
    });
  }

  @override
  Future<MemoryItem> createMemory(MemoryItem item, {DocumentUpload? upload}) {
    return guardBackend(() async {
      final row = item.toInsertRow();
      String? uploadedPath;

      if (upload != null) {
        uploadedPath = _newObjectPath(upload.fileName);
        await _client.storage
            .from(_bucket)
            .uploadBinary(
              uploadedPath,
              upload.bytes,
              fileOptions: FileOptions(
                contentType: upload.mimeType,
                upsert: false,
              ),
            );
        row['file_path'] = uploadedPath;
        row['file_size'] = upload.bytes.length;
        row['mime_type'] = upload.mimeType;
      }

      try {
        final inserted = await _client
            .from('memories_wishes')
            .insert(row)
            .select()
            .single();
        return MemoryItem.fromRow(inserted);
      } catch (_) {
        if (uploadedPath != null) {
          try {
            await _client.storage.from(_bucket).remove([uploadedPath]);
          } catch (_) {
            // Best effort cleanup
          }
        }
        rethrow;
      }
    });
  }

  @override
  Future<MemoryItem> createMemoryWithMedia(
    MemoryItem item,
    List<DocumentUpload> uploads, {
    List<String>? captions,
    List<int?>? durations,
  }) {
    return guardBackend(() async {
      final user = _client.requireUser;
      final row = item.toInsertRow();
      row['user_id'] = user.id;

      // 1. Insert parent memory row first
      final insertedMemory = await _client
          .from('memories_wishes')
          .insert(row)
          .select()
          .single();

      final memoryId = insertedMemory['id'] as String;
      final uploadedPaths = <String>[];
      final createdMedia = <MemoryMediaItem>[];

      if (uploads.isEmpty) {
        return MemoryItem.fromRow(insertedMemory);
      }

      try {
        for (var i = 0; i < uploads.length; i++) {
          final upload = uploads[i];
          final caption =
              (captions != null && i < captions.length) ? captions[i] : null;
          final duration =
              (durations != null && i < durations.length) ? durations[i] : null;

          final mediaType = detectMediaType(upload.mimeType, upload.fileName);
          final storagePath = mediaObjectPath(
            user.id,
            memoryId,
            mediaType,
            upload.fileName,
          );

          // Upload binary to private memories bucket
          await _client.storage
              .from(_bucket)
              .uploadBinary(
                storagePath,
                upload.bytes,
                fileOptions: FileOptions(
                  contentType: upload.mimeType,
                  upsert: false,
                ),
              );
          uploadedPaths.add(storagePath);

          // Insert row into memory_media
          final mediaRow = await _client
              .from('memory_media')
              .insert({
                'memory_id': memoryId,
                'user_id': user.id,
                'file_path': storagePath,
                'media_type': mediaType.dbValue,
                'mime_type': upload.mimeType,
                'file_size': upload.bytes.length,
                'display_order': i,
                if (caption != null && caption.trim().isNotEmpty)
                  'caption': caption.trim(),
                if (duration != null && duration >= 0)
                  'duration_seconds': duration,
              })
              .select()
              .single();

          createdMedia.add(MemoryMediaItem.fromRow(mediaRow));
        }

        return MemoryItem.fromRow(insertedMemory).copyWith(media: createdMedia);
      } catch (e) {
        // Rollback: delete newly uploaded storage objects and inserted parent memory
        if (uploadedPaths.isNotEmpty) {
          try {
            await _client.storage.from(_bucket).remove(uploadedPaths);
          } catch (_) {
            // Best effort cleanup
          }
        }
        try {
          await _client.from('memories_wishes').delete().eq('id', memoryId);
        } catch (_) {
          // Best effort cleanup
        }
        rethrow;
      }
    });
  }

  @override
  Future<MemoryMediaItem> addMedia(
    String memoryId,
    DocumentUpload upload, {
    String? caption,
    int? displayOrder,
    int? durationSeconds,
  }) {
    return guardBackend(() async {
      final user = _client.requireUser;

      // Verify the memory exists and belongs to the current user
      final memoryCheck = await _client
          .from('memories_wishes')
          .select('id, user_id')
          .eq('id', memoryId);
      requireAffected(memoryCheck);

      final memoryOwner = memoryCheck.first['user_id'] as String?;
      if (memoryOwner != null && memoryOwner != user.id) {
        throw const BackendException(
          'You do not have permission to add media to this memory.',
        );
      }

      final mediaType = detectMediaType(upload.mimeType, upload.fileName);
      final storagePath = mediaObjectPath(
        user.id,
        memoryId,
        mediaType,
        upload.fileName,
      );

      // Upload binary to storage
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            storagePath,
            upload.bytes,
            fileOptions: FileOptions(
              contentType: upload.mimeType,
              upsert: false,
            ),
          );

      try {
        final inserted = await _client
            .from('memory_media')
            .insert({
              'memory_id': memoryId,
              'user_id': user.id,
              'file_path': storagePath,
              'media_type': mediaType.dbValue,
              'mime_type': upload.mimeType,
              'file_size': upload.bytes.length,
              'display_order': displayOrder ?? 0,
              if (caption != null && caption.trim().isNotEmpty)
                'caption': caption.trim(),
              if (durationSeconds != null && durationSeconds >= 0)
                'duration_seconds': durationSeconds,
            })
            .select()
            .single();

        return MemoryMediaItem.fromRow(inserted);
      } catch (_) {
        // If DB insertion fails, remove the newly uploaded storage object
        try {
          await _client.storage.from(_bucket).remove([storagePath]);
        } catch (_) {
          // Best effort cleanup
        }
        rethrow;
      }
    });
  }

  @override
  Future<void> deleteMedia(String mediaId) {
    return guardBackend(() async {
      final user = _client.requireUser;

      final existing = await _client
          .from('memory_media')
          .select('id, user_id, file_path')
          .eq('id', mediaId);
      requireAffected(existing);

      final row = existing.first;
      if (row['user_id'] != null && row['user_id'] != user.id) {
        throw const BackendException(
          'You do not have permission to delete this media.',
        );
      }

      final filePath = row['file_path'] as String?;
      if (filePath != null && filePath.isNotEmpty) {
        try {
          await _client.storage.from(_bucket).remove([filePath]);
        } catch (_) {
          // Best effort cleanup
        }
      }

      await _client.from('memory_media').delete().eq('id', mediaId);
    });
  }

  @override
  Future<void> reorderMedia(
    String memoryId,
    List<String> orderedMediaIds,
  ) {
    return guardBackend(() async {
      final user = _client.requireUser;

      final memoryCheck = await _client
          .from('memories_wishes')
          .select('id, user_id')
          .eq('id', memoryId);
      requireAffected(memoryCheck);

      if (memoryCheck.first['user_id'] != null &&
          memoryCheck.first['user_id'] != user.id) {
        throw const BackendException(
          'You do not have permission to reorder media for this memory.',
        );
      }

      if (orderedMediaIds.isEmpty) return;

      final existingMedia = await _client
          .from('memory_media')
          .select('id, memory_id')
          .eq('memory_id', memoryId);

      final existingIds = existingMedia.map((m) => m['id'] as String).toSet();
      for (final id in orderedMediaIds) {
        if (!existingIds.contains(id)) {
          throw const BackendException(
            'Cannot reorder media that does not belong to this memory.',
          );
        }
      }

      for (var i = 0; i < orderedMediaIds.length; i++) {
        await _client
            .from('memory_media')
            .update({'display_order': i})
            .eq('id', orderedMediaIds[i])
            .eq('memory_id', memoryId);
      }
    });
  }

  @override
  Future<MemoryItem> updateMemory(MemoryItem item) {
    return guardBackend(() async {
      final rows = await _client
          .from('memories_wishes')
          .update(item.toUpdateRow())
          .eq('id', item.id)
          .select();
      requireAffected(rows);
      return MemoryItem.fromRow(rows.first);
    });
  }

  @override
  Future<void> deleteMemory(String id) {
    return guardBackend(() async {
      final row = await _client
          .from('memories_wishes')
          .select('file_path')
          .eq('id', id)
          .maybeSingle();

      // Remove the file first. If that fails the row is kept and the delete
      // can be retried; the reverse order could leave a "deleted" item's file
      // behind in Storage.
      final filePath = row?['file_path'] as String?;
      if (filePath != null) {
        await _client.storage.from(_bucket).remove([filePath]);
      }

      await _client.from('memories_wishes').delete().eq('id', id);
    });
  }

  @override
  Future<MemoryItem> uploadAttachment(String id, DocumentUpload upload) {
    return guardBackend(() async {
      final existing = await _client
          .from('memories_wishes')
          .select('file_path')
          .eq('id', id);
      requireAffected(existing);
      final oldPath = existing.first['file_path'] as String?;

      final newPath = _newObjectPath(upload.fileName);
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            newPath,
            upload.bytes,
            fileOptions: FileOptions(
              contentType: upload.mimeType,
              upsert: false,
            ),
          );

      try {
        final rows = await _client
            .from('memories_wishes')
            .update({
              'file_path': newPath,
              'file_size': upload.bytes.length,
              'mime_type': upload.mimeType,
            })
            .eq('id', id)
            .select();
        requireAffected(rows);

        if (oldPath != null && oldPath != newPath) {
          try {
            await _client.storage.from(_bucket).remove([oldPath]);
          } catch (_) {
            // Best effort cleanup
          }
        }
        return MemoryItem.fromRow(rows.first);
      } catch (_) {
        try {
          await _client.storage.from(_bucket).remove([newPath]);
        } catch (_) {
          // Best effort cleanup
        }
        rethrow;
      }
    });
  }

  @override
  Future<MemoryItem> deleteAttachment(String id) {
    return guardBackend(() async {
      final existing = await _client
          .from('memories_wishes')
          .select('file_path')
          .eq('id', id);
      requireAffected(existing);
      final oldPath = existing.first['file_path'] as String?;

      final rows = await _client
          .from('memories_wishes')
          .update({'file_path': null, 'file_size': null, 'mime_type': null})
          .eq('id', id)
          .select();
      requireAffected(rows);

      if (oldPath != null) {
        try {
          await _client.storage.from(_bucket).remove([oldPath]);
        } catch (_) {
          // Best effort cleanup
        }
      }
      return MemoryItem.fromRow(rows.first);
    });
  }

  @override
  Future<String> createDownloadUrl(String filePath) {
    return guardBackend(() {
      return _client.storage
          .from(_bucket)
          .createSignedUrl(filePath, _downloadUrlSeconds);
    });
  }

  @override
  Future<String> createSignedUrl(String filePath) =>
      createDownloadUrl(filePath);

  /// Path generator for rich media conforming to:
  /// `<user_id>/memories/<memory_id>/<media_type>_<timestamp>_<sanitized_filename>`
  static String mediaObjectPath(
    String userId,
    String memoryId,
    MemoryMediaType type,
    String fileName,
  ) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final safeName = _safeFileName(fileName);
    return '$userId/memories/$memoryId/${type.name}_${timestamp}_$safeName';
  }

  /// Detects whether an upload is photo, video, or audio based on MIME type and file extension.
  static MemoryMediaType detectMediaType(String? mimeType, String fileName) {
    final m = (mimeType ?? '').trim().toLowerCase();
    if (m.startsWith('image/')) return MemoryMediaType.photo;
    if (m.startsWith('video/')) return MemoryMediaType.video;
    if (m.startsWith('audio/')) return MemoryMediaType.audio;

    final name = fileName.trim().toLowerCase();
    if (name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp') ||
        name.endsWith('.heic') ||
        name.endsWith('.gif')) {
      return MemoryMediaType.photo;
    }
    if (name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.mkv') ||
        name.endsWith('.webm') ||
        name.endsWith('.avi')) {
      return MemoryMediaType.video;
    }
    if (name.endsWith('.m4a') ||
        name.endsWith('.mp3') ||
        name.endsWith('.wav') ||
        name.endsWith('.aac') ||
        name.endsWith('.ogg')) {
      return MemoryMediaType.audio;
    }
    return MemoryMediaType.photo;
  }

  /// Legacy single-attachment object path generator.
  String _newObjectPath(String fileName) =>
      '${_client.requireUser.id}/memories/'
      '${DateTime.now().microsecondsSinceEpoch}-${_safeFileName(fileName)}';

  /// Sanitizes a file name for storage.
  static String _safeFileName(String name) {
    final base = name.split(RegExp(r'[\\/]')).last.trim();
    final cleaned = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (cleaned.isEmpty ||
        cleaned.replaceAll('_', '').replaceAll('.', '').isEmpty) {
      return 'file';
    }
    return cleaned.length > 120
        ? cleaned.substring(cleaned.length - 120)
        : cleaned;
  }
}
