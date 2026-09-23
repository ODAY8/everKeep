import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/app_supabase.dart';
import '../core/supabase/client_extensions.dart';
import '../core/supabase/supabase_errors.dart';
import '../models/document_upload.dart';
import '../models/memory_item.dart';

abstract class MemoryService {
  Future<List<MemoryItem>> fetchMemories();
  Future<MemoryItem> fetchMemory(String id);

  /// Saves the item's metadata. If [upload] is given, its bytes are stored in
  /// private Storage first and the item points at them.
  Future<MemoryItem> createMemory(MemoryItem item, {DocumentUpload? upload});

  /// Saves edits to title, content, type or date. Does not touch an existing
  /// attachment — use [uploadAttachment] / [deleteAttachment] for that.
  Future<MemoryItem> updateMemory(MemoryItem item);

  /// Deletes the item and, if it has one, its stored file.
  Future<void> deleteMemory(String id);

  /// Adds or replaces [id]'s attachment.
  Future<MemoryItem> uploadAttachment(String id, DocumentUpload upload);

  /// Removes [id]'s attachment, keeping the memory or wish itself.
  Future<MemoryItem> deleteAttachment(String id);

  /// A short-lived link to view a stored file. Attachments are private, so
  /// this is the only way to reach one outside the app.
  Future<String> createDownloadUrl(String filePath);
}

/// [MemoryService] backed by the `memories_wishes` table and the private
/// `memories` Storage bucket. Row Level Security and Storage policies limit
/// every query and every file to the signed-in user's own — the same shape as
/// [DocumentService].
class MemoryServiceImpl implements MemoryService {
  static const String _bucket = 'memories';
  static const int _downloadUrlSeconds = 300;

  final SupabaseClient _client;

  MemoryServiceImpl({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  @override
  Future<List<MemoryItem>> fetchMemories() {
    return guardBackend(() async {
      final rows = await _client
          .from('memories_wishes')
          .select()
          .order('created_at', ascending: false);
      return rows.map(MemoryItem.fromRow).toList();
    });
  }

  @override
  Future<MemoryItem> fetchMemory(String id) {
    return guardBackend(() async {
      final rows = await _client.from('memories_wishes').select().eq('id', id);
      requireAffected(rows);
      return MemoryItem.fromRow(rows.first);
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
        // Don't leave a file behind that no memory or wish points at.
        if (uploadedPath != null) {
          try {
            await _client.storage.from(_bucket).remove([uploadedPath]);
          } catch (_) {
            // Best effort; the original failure is what the caller needs.
          }
        }
        rethrow;
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

        // Only remove the old file once the row safely points at the new
        // one, so a failure never leaves the row pointing at nothing.
        if (oldPath != null && oldPath != newPath) {
          try {
            await _client.storage.from(_bucket).remove([oldPath]);
          } catch (_) {
            // Best effort; an orphaned old file is not a data-loss risk.
          }
        }
        return MemoryItem.fromRow(rows.first);
      } catch (_) {
        // The row was not updated to point at it, so don't leave it behind.
        try {
          await _client.storage.from(_bucket).remove([newPath]);
        } catch (_) {
          // Best effort; the original failure is what the caller needs.
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
          // The row no longer points at it either way; best effort cleanup.
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

  /// `<user id>/memories/<timestamp>-<safe file name>` — the folder Storage
  /// policies key on.
  String _newObjectPath(String fileName) =>
      '${_client.requireUser.id}/memories/'
      '${DateTime.now().microsecondsSinceEpoch}-${_safeFileName(fileName)}';

  /// A file name that is safe inside a Storage object key: no folders, and
  /// only letters, digits, dot, dash and underscore.
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
