import 'dart:typed_data';

/// A file the user has picked to attach to a document. It is uploaded to
/// private Storage; only its path and size are kept in the database.
class DocumentUpload {
  final String fileName;
  final Uint8List bytes;
  final String? mimeType;

  const DocumentUpload({
    required this.fileName,
    required this.bytes,
    this.mimeType,
  });
}
