import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/app_supabase.dart';
import '../core/supabase/client_extensions.dart';
import '../core/supabase/supabase_errors.dart';
import '../models/document_item.dart';
import '../models/document_upload.dart';

abstract class DocumentService {
  Future<List<DocumentItem>> fetchDocuments();

  /// Saves the document's metadata. If [upload] is given, its bytes are stored
  /// in private Storage first and the document points at them.
  Future<DocumentItem> addDocument(
    DocumentItem document, {
    DocumentUpload? upload,
  });

  /// Updates an existing document's metadata (title, category, description,
  /// issue_date, expiry_date).
  Future<DocumentItem> updateDocument(DocumentItem document);

  /// Deletes the document and, if it has one, its stored file.
  Future<void> deleteDocument(String id);

  /// A short-lived link to view a stored file. Documents are private, so this
  /// is the only way to reach one outside the app.
  Future<String> createDownloadUrl(String filePath);
}

/// [DocumentService] backed by the `documents` table and the private
/// `documents` Storage bucket. Row Level Security and Storage policies limit
/// every query and every file to the signed-in user's own.
class DocumentServiceImpl implements DocumentService {
  static const String _bucket = 'documents';
  static const int _downloadUrlSeconds = 300;

  final SupabaseClient _client;

  DocumentServiceImpl({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  @override
  Future<List<DocumentItem>> fetchDocuments() {
    return guardBackend(() async {
      final rows = await _client
          .from('documents')
          .select()
          .order('created_at', ascending: false);
      return rows.map(DocumentItem.fromRow).toList();
    });
  }

  @override
  Future<DocumentItem> addDocument(
    DocumentItem document, {
    DocumentUpload? upload,
  }) {
    return guardBackend(() async {
      final row = document.toInsertRow();
      String? uploadedPath;

      if (upload != null) {
        // <user id>/documents/... — the folder Storage policies key on.
        uploadedPath =
            '${_client.requireUser.id}/documents/'
            '${DateTime.now().microsecondsSinceEpoch}-${_safeFileName(upload.fileName)}';
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
        final inserted =
            await _client.from('documents').insert(row).select().single();
        return DocumentItem.fromRow(inserted);
      } catch (_) {
        // Don't leave a file behind that no document points at.
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
  Future<DocumentItem> updateDocument(DocumentItem document) {
    return guardBackend(() async {
      final row = document.toUpdateRow();
      final updated = await _client
          .from('documents')
          .update(row)
          .eq('id', document.id)
          .select()
          .single();
      return DocumentItem.fromRow(updated);
    });
  }

  @override
  Future<void> deleteDocument(String id) {
    return guardBackend(() async {
      final row = await _client
          .from('documents')
          .select('file_path')
          .eq('id', id)
          .maybeSingle();

      // Remove the file first. If that fails the row is kept and the delete
      // can be retried; the reverse order could leave a "deleted" document's
      // file behind in Storage.
      final filePath = row?['file_path'] as String?;
      if (filePath != null) {
        await _client.storage.from(_bucket).remove([filePath]);
      }

      // Already gone (or not the caller's) means the end state is the one
      // asked for, so this is not treated as a failure.
      await _client.from('documents').delete().eq('id', id);
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

  /// A file name that is safe inside a Storage object key: no folders, and
  /// only letters, digits, dot, dash and underscore.
  static String _safeFileName(String name) {
    final base = name.split(RegExp(r'[\\/]')).last.trim();
    final cleaned = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (cleaned.isEmpty || cleaned.replaceAll('_', '').replaceAll('.', '').isEmpty) {
      return 'file';
    }
    return cleaned.length > 120 ? cleaned.substring(cleaned.length - 120) : cleaned;
  }
}
